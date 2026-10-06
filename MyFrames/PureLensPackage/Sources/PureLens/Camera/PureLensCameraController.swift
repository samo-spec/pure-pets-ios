#if canImport(UIKit)
import AVFoundation
import CoreImage
import CoreVideo
import ImageIO
import PureLensCore
import UIKit

struct PureLensCameraFrameEvent {
    let detections: [LensLocalDetection]
    let boundFrame: LensBoundFrame?
    let pixelSize: CGSize
    let detectorHealth: PureLensDetectorHealth
    let allowsRawBarcodePayloads: Bool
}

final class PureLensCameraController: NSObject, @unchecked Sendable {
    let session = AVCaptureSession()

    var onFrame: ((PureLensCameraFrameEvent) -> Void)?
    var onInterruption: ((Bool) -> Void)?
    var onRecoveryRequested: (() -> Void)?
    var onRuntimeFailure: ((String) -> Void)?

    private let sessionQueue = DispatchQueue(label: "com.purepets.purelens.camera-session")
    private let frameQueue = DispatchQueue(label: "com.purepets.purelens.camera-frames", qos: .userInitiated)
    private let output = AVCaptureVideoDataOutput()
    private let processor: PureLensFrameProcessor
    private var captureDevice: AVCaptureDevice?
    private var isConfigured = false
    private var notificationTokens: [NSObjectProtocol] = []

    init(
        analysisInterval: TimeInterval,
        maximumFrameDimension: Int,
        capturesFrameData: Bool,
        minimumFrameCaptureConfidence: Double,
        spatialAssociation: LensSpatialAssociationConfiguration,
        detectorFailureReportCooldown: TimeInterval,
        barcodeHandling: PureLensBarcodeHandling,
        capturesBarcodePayloads: Bool,
        coreMLDetector: PureLensCoreMLDetector?
    ) {
        processor = PureLensFrameProcessor(
            analysisInterval: analysisInterval,
            maximumFrameDimension: maximumFrameDimension,
            capturesFrameData: capturesFrameData,
            minimumFrameCaptureConfidence: minimumFrameCaptureConfidence,
            spatialAssociation: spatialAssociation,
            detectorFailureReportCooldown: detectorFailureReportCooldown,
            barcodeHandling: barcodeHandling,
            capturesBarcodePayloads: capturesBarcodePayloads,
            coreMLDetector: coreMLDetector
        )
        super.init()

        processor.onFrame = { [weak self] event in
            self?.onFrame?(event)
        }
        observeSessionNotifications()
    }

    deinit {
        notificationTokens.forEach(NotificationCenter.default.removeObserver)
    }

    func authorization() async -> LensCameraAuthorization {
        guard AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) != nil else {
            return .unavailable
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { value in
                    continuation.resume(returning: value)
                }
            }
            return granted ? .authorized : .denied
        @unknown default:
            return .unavailable
        }
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                if !self.isConfigured {
                    try self.configure()
                    self.isConfigured = true
                }
                if !self.session.isRunning {
                    self.session.startRunning()
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.onRuntimeFailure?(error.localizedDescription)
                }
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    /// Requests one fresh JPEG on the next analyzed frame that is compatible
    /// with the already-stabilized recognition.
    func requestFrameCapture(for recognition: LensPetRecognition) {
        frameQueue.async { [weak self] in
            self?.processor.requestFrameCapture(for: recognition)
        }
    }

    func cancelPendingFrameCapture() {
        frameQueue.async { [weak self] in
            self?.processor.cancelPendingFrameCapture()
        }
    }

    func updateImageOrientation(_ orientation: CGImagePropertyOrientation) {
        frameQueue.async { [weak self] in
            self?.processor.imageOrientation = orientation
        }
    }

    func setAnalysisEnabled(_ enabled: Bool) {
        frameQueue.async { [weak self] in
            self?.processor.setAnalysisEnabled(enabled)
        }
    }

    func setBarcodePayloadCaptureEnabled(_ enabled: Bool) {
        frameQueue.async { [weak self] in
            self?.processor.setBarcodePayloadCaptureEnabled(enabled)
        }
    }

    func focus(at devicePoint: CGPoint) {
        let point = CGPoint(
            x: min(max(devicePoint.x, 0), 1),
            y: min(max(devicePoint.y, 0), 1)
        )
        sessionQueue.async { [weak self] in
            guard let device = self?.captureDevice else { return }
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                if device.isFocusPointOfInterestSupported,
                   device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusPointOfInterest = point
                    device.focusMode = .continuousAutoFocus
                }
                if device.isExposurePointOfInterestSupported,
                   device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .continuousAutoExposure
                }
            } catch {
                // Focus is an enhancement; the active capture session remains usable.
            }
        }
    }

    private func configure() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if session.canSetSessionPreset(.hd1280x720) {
            session.sessionPreset = .hd1280x720
        } else {
            session.sessionPreset = .high
        }

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else {
            throw LensCameraError.unavailable
        }
        try configureCaptureDevice(device)
        captureDevice = device

        let input = try AVCaptureDeviceInput(device: device)
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String:
                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        output.setSampleBufferDelegate(processor, queue: frameQueue)

        // Validate the complete graph before mutating the session so a failed
        // configuration can be retried without inheriting a partial input.
        guard session.canAddInput(input) else {
            throw LensCameraError.cannotAddInput
        }
        guard session.canAddOutput(output) else {
            throw LensCameraError.cannotAddOutput
        }
        session.addInput(input)
        session.addOutput(output)
    }

    private func configureCaptureDevice(_ device: AVCaptureDevice) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }
        if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
            device.whiteBalanceMode = .continuousAutoWhiteBalance
        }
        if device.isSmoothAutoFocusSupported {
            device.isSmoothAutoFocusEnabled = true
        }
        device.isSubjectAreaChangeMonitoringEnabled = true
    }

    private func observeSessionNotifications() {
        let center = NotificationCenter.default
        notificationTokens.append(
            center.addObserver(
                forName: AVCaptureSession.wasInterruptedNotification,
                object: session,
                queue: .main
            ) { [weak self] _ in
                self?.onInterruption?(true)
            }
        )
        notificationTokens.append(
            center.addObserver(
                forName: AVCaptureSession.interruptionEndedNotification,
                object: session,
                queue: .main
            ) { [weak self] _ in
                self?.onInterruption?(false)
                self?.onRecoveryRequested?()
            }
        )
        notificationTokens.append(
            center.addObserver(
                forName: AVCaptureSession.runtimeErrorNotification,
                object: session,
                queue: .main
            ) { [weak self] notification in
                self?.handleRuntimeError(notification)
            }
        )
    }

    private func handleRuntimeError(_ notification: Notification) {
        let error = notification.userInfo?[AVCaptureSessionErrorKey] as? Error
        if let avError = error as? AVError,
           avError.code == .mediaServicesWereReset {
            onRecoveryRequested?()
            return
        }
        onRuntimeFailure?(
            error?.localizedDescription ?? LensL10n.string("lens.error.camera")
        )
    }
}

private enum LensCameraError: Error {
    case unavailable
    case cannotAddInput
    case cannotAddOutput
}

private final class PureLensFrameProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    var onFrame: ((PureLensCameraFrameEvent) -> Void)?

    private let detector: VisionLensDetector
    private let context = CIContext(options: [.cacheIntermediates: false])
    private let maximumFrameDimension: Int
    private let capturesFrameData: Bool
    private let minimumFrameCaptureConfidence: Double
    private let spatialAssociation: LensSpatialAssociationConfiguration
    private var analysisGate: LensFrameAnalysisGate
    private var frameCaptureGate = LensFrameCaptureGate(minimumInterval: 0.25)
    private var detectorFailureGate: LensDetectorFailureGate
    private var pendingCaptureRecognition: LensPetRecognition?
    private var bestRepresentativeFrame: LensBoundFrame?
    private var bestRepresentativeScore = -Double.infinity
    private var representativeSampleCount = 0
    private var representativeWindowStartedAt: TimeInterval?
    private var analysisEnabled = true
    var imageOrientation: CGImagePropertyOrientation = .right

    init(
        analysisInterval: TimeInterval,
        maximumFrameDimension: Int,
        capturesFrameData: Bool,
        minimumFrameCaptureConfidence: Double,
        spatialAssociation: LensSpatialAssociationConfiguration,
        detectorFailureReportCooldown: TimeInterval,
        barcodeHandling: PureLensBarcodeHandling,
        capturesBarcodePayloads: Bool,
        coreMLDetector: PureLensCoreMLDetector?
    ) {
        self.maximumFrameDimension = maximumFrameDimension
        self.capturesFrameData = capturesFrameData
        self.minimumFrameCaptureConfidence = min(
            max(minimumFrameCaptureConfidence, 0),
            1
        )
        self.spatialAssociation = spatialAssociation
        analysisGate = LensFrameAnalysisGate(minimumInterval: analysisInterval)
        detectorFailureGate = LensDetectorFailureGate(cooldown: detectorFailureReportCooldown)
        detector = VisionLensDetector(
            coreMLDetector: coreMLDetector,
            minimumAnimalConfidence: minimumFrameCaptureConfidence,
            barcodeHandling: barcodeHandling,
            capturesBarcodePayloads: capturesBarcodePayloads
        )
    }

    func requestFrameCapture(for recognition: LensPetRecognition) {
        guard capturesFrameData else { return }
        pendingCaptureRecognition = recognition
        bestRepresentativeFrame = nil
        bestRepresentativeScore = -Double.infinity
        representativeSampleCount = 0
        representativeWindowStartedAt = nil
        frameCaptureGate.reset()
    }

    func cancelPendingFrameCapture() {
        resetRepresentativeCapture()
    }

    func setAnalysisEnabled(_ enabled: Bool) {
        analysisEnabled = enabled
        analysisGate.reset()
        if !enabled {
            resetRepresentativeCapture()
        }
    }

    func setBarcodePayloadCaptureEnabled(_ enabled: Bool) {
        detector.setBarcodePayloadCaptureEnabled(enabled)
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard analysisEnabled else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let timestampSeconds = timestamp.isValid
            ? CMTimeGetSeconds(timestamp)
            : ProcessInfo.processInfo.systemUptime
        guard analysisGate.shouldAnalyze(timestamp: timestampSeconds) else { return }
        let capturedAt = sampleDate(for: timestampSeconds)
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let orientation = imageOrientation
        let analysis = detector.analyze(pixelBuffer, orientation: orientation)
        let pixelSize = orientedPixelSize(for: pixelBuffer, orientation: orientation)
        let boundFrame = materializeRequestedFrame(
            from: pixelBuffer,
            detections: analysis.detections,
            orientation: orientation,
            timestamp: timestampSeconds,
            capturedAt: capturedAt
        )
        let health = reportableHealth(analysis.health, timestamp: timestampSeconds)
        let event = PureLensCameraFrameEvent(
            detections: analysis.detections,
            boundFrame: boundFrame,
            pixelSize: pixelSize,
            detectorHealth: health,
            allowsRawBarcodePayloads: detector.isBarcodePayloadCaptureEnabled
        )

        DispatchQueue.main.async { [weak self] in
            self?.onFrame?(event)
        }
    }

    private func materializeRequestedFrame(
        from pixelBuffer: CVPixelBuffer,
        detections: [LensLocalDetection],
        orientation: CGImagePropertyOrientation,
        timestamp: TimeInterval,
        capturedAt: Date
    ) -> LensBoundFrame? {
        guard capturesFrameData,
              let requested = pendingCaptureRecognition,
              let matched = LensPetRecognition.bestSpatialMatch(
                in: detections,
                for: requested,
                minimumConfidence: minimumFrameCaptureConfidence,
                spatialConfiguration: spatialAssociation
              ),
              frameCaptureGate.shouldCapture(
                identity: requested.instanceIdentity,
                timestamp: timestamp
              ),
              let frame = makeFrame(from: pixelBuffer, orientation: orientation)
        else {
            return nil
        }

        let candidate = LensBoundFrame(
            frame: frame,
            recognition: matched.withTrackID(requested.trackID),
            capturedAt: capturedAt
        )
        let score = representativeScore(for: matched)
        if score > bestRepresentativeScore {
            bestRepresentativeScore = score
            bestRepresentativeFrame = candidate
        }
        representativeSampleCount += 1
        if representativeWindowStartedAt == nil {
            representativeWindowStartedAt = timestamp
        }

        guard representativeSampleCount >= 1, let selected = bestRepresentativeFrame else {
            return nil
        }
        resetRepresentativeCapture()
        return selected
    }

    private func representativeScore(for recognition: LensPetRecognition) -> Double {
        let rect = recognition.boundingBox
        let area = min(max((rect.width * rect.height) / 0.45, 0), 1)
        let centerX = rect.x + rect.width / 2
        let centerY = rect.y + rect.height / 2
        let distance = hypot(centerX - 0.5, centerY - 0.5)
        let centered = min(max(1 - (distance / 0.71), 0), 1)
        return recognition.confidence * 0.68 + area * 0.20 + centered * 0.12
    }

    private func resetRepresentativeCapture() {
        pendingCaptureRecognition = nil
        bestRepresentativeFrame = nil
        bestRepresentativeScore = -Double.infinity
        representativeSampleCount = 0
        representativeWindowStartedAt = nil
        frameCaptureGate.reset()
    }

    private func sampleDate(for timestamp: TimeInterval) -> Date {
        guard timestamp.isFinite else { return Date() }
        let uptimeNow = ProcessInfo.processInfo.systemUptime
        guard uptimeNow.isFinite else { return Date() }
        return Date(timeIntervalSinceNow: timestamp - uptimeNow)
    }

    private func reportableHealth(
        _ health: PureLensDetectorHealth,
        timestamp: TimeInterval
    ) -> PureLensDetectorHealth {
        switch health {
        case .operational:
            detectorFailureGate.markHealthy()
            return .operational
        case .degraded, .failed:
            return detectorFailureGate.shouldReport(at: timestamp) ? health : .operational
        }
    }

    private func orientedPixelSize(
        for pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation
    ) -> CGSize {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        switch orientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            return CGSize(width: height, height: width)
        default:
            return CGSize(width: width, height: height)
        }
    }

    private func makeFrame(
        from pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation
    ) -> LensFrame? {
        autoreleasepool {
            let oriented = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
            let longestSide = max(oriented.extent.width, oriented.extent.height)
            let scale = min(1, CGFloat(maximumFrameDimension) / longestSide)
            let resized = oriented.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

            guard let cgImage = context.createCGImage(resized, from: resized.extent),
                  let data = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.72)
            else {
                return nil
            }

            return LensFrame(
                data: data,
                pixelWidth: cgImage.width,
                pixelHeight: cgImage.height
            )
        }
    }
}


#endif
