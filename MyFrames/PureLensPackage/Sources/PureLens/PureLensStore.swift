#if canImport(UIKit)
import AVFoundation
import Foundation
import PureLensCore
import UIKit

struct LensPresentation: Identifiable, Equatable {
    let id: UUID

    init(id: UUID = UUID()) {
        self.id = id
    }
}

enum PureLensScanPhase: Equatable {
    case searching
    case candidateFound
    case confirming
    case validating
    case confirmed
    case discovering
    case results
    case unsupported
    case uncertain
    case notAnimal
    case taxonomyUnavailable
    case validationFailed
}

private enum LensDiscoveryPipeline: Hashable {
    case taxonomy
    case imageSearch
}

@MainActor
final class PureLensStore: ObservableObject {
    @Published private(set) var cameraAuthorization: LensCameraAuthorization = .notDetermined
    @Published private(set) var detections: [LensLocalDetection] = []
    @Published private(set) var detectorState: LensDetectorState = .searching
    @Published private(set) var scanPhase: PureLensScanPhase = .searching
    @Published private(set) var framePixelSize = CGSize(width: 9, height: 16)
    @Published private(set) var isCameraInterrupted = false
    @Published private(set) var animalContext: DetectedAnimalContext?
    @Published private(set) var unsupportedAnimalContext: DetectedAnimalContext?
    @Published private(set) var animalIdentification: LensAnimalIdentificationResult?
    @Published private(set) var hasDismissedIdentityCandidates = false
    @Published private(set) var didChooseIdentityCandidate = false
    @Published private(set) var didShareSelectedFrameForAnimalIdentity = false
    @Published private(set) var discoverySections: [LensDiscoverySection]
    @Published private(set) var openingItemID: String?
    @Published var presentation: LensPresentation?
    @Published var showsRemoteProcessingConsent = false
    @Published var showsItemOpenError = false
    @Published private(set) var didDeclineRemoteProcessingForCurrentDetection = false
    @Published private(set) var isOpeningGuidance = false

    let camera: PureLensCameraController
    let theme: PureLensTheme
    let configuration: PureLensConfiguration

    private let discoveryClient: LensDiscoveryClient
    private let discoveryActions: LensDiscoveryActionClient
    private let guidanceActions: LensGuidanceActionClient?
    private let analytics: LensAnalyticsClient
    private let detectionFeedback: PureLensDetectionFeedback

    private var detectionStabilizer: LensDetectionStabilizer
    private var currentRecognition: LensPetRecognition?
    private var pendingLocalAnimal: DetectedAnimalContext?
    private var representativeFrame: LensFrame?
    private var pendingConsentFrame: LensFrame?
    private var taxonomyItems: [LensDiscoveryCategory: [LensDiscoveryItem]] = [:]
    private var imageItems: [LensDiscoveryCategory: [LensDiscoveryItem]] = [:]
    private var pendingPipelines: [LensDiscoveryCategory: Set<LensDiscoveryPipeline>] = [:]
    private var failedPipelines: [LensDiscoveryCategory: Set<LensDiscoveryPipeline>] = [:]
    private var discoveryTasks: [Task<Void, Never>] = []
    private var frameTimeoutTask: Task<Void, Never>?
    private var demoTask: Task<Void, Never>?
    private var openItemTask: Task<Void, Never>?
    private var supportValidationTask: Task<Void, Never>?
    private var cameraAuthorizationTask: Task<Void, Never>?
    private var cameraAuthorizationRequestID: UUID?
    private var sessionGeneration = UUID()
    private var imageSearchGeneration: UUID?
    private var hasStarted = false
    private var isAppActive = true
    private var hasRemoteProcessingConsent: Bool

    init(module: PureLensModule) {
        configuration = module.configuration
        theme = module.theme
        discoveryClient = module.discovery
        discoveryActions = module.discoveryActions
        guidanceActions = module.guidanceActions
        analytics = module.analytics
        hasRemoteProcessingConsent = module.configuration.hasPriorRemoteProcessingConsent
        discoverySections = LensDiscoveryCategory.allCases.map {
            LensDiscoverySection(category: $0)
        }
        detectionFeedback = PureLensDetectionFeedback(
            soundEnabled: module.configuration.detectionSoundEnabled,
            hapticsEnabled: module.configuration.hapticsEnabled
        )
        detectionStabilizer = LensDetectionStabilizer(
            configuration: .init(
                minimumConfidence: module.configuration.minimumDetectionConfidence,
                requiredStableFrames: module.configuration.stableDetectionFrameCount,
                replacementStableFrames: module.configuration.replacementStableFrameCount,
                lostFrameTolerance: module.configuration.lostDetectionFrameTolerance,
                spatialAssociation: module.configuration.spatialAssociation
            )
        )

        let capturesFrameData: Bool
        switch module.configuration.frameUploadPolicy {
        case .selectedFrame:
            capturesFrameData = true
        case .metadataOnly:
            capturesFrameData = false
        }
        camera = PureLensCameraController(
            analysisInterval: module.configuration.analysisInterval,
            maximumFrameDimension: module.configuration.maximumFrameDimension,
            capturesFrameData: capturesFrameData,
            minimumFrameCaptureConfidence: module.configuration.minimumDetectionConfidence,
            spatialAssociation: module.configuration.spatialAssociation,
            detectorFailureReportCooldown: module.configuration.detectorFailureReportCooldown,
            barcodeHandling: module.configuration.barcodeHandling,
            capturesBarcodePayloads: false,
            coreMLDetector: module.coreMLDetector
        )

        camera.onFrame = { [weak self] event in
            self?.receive(event)
        }
        camera.onInterruption = { [weak self] interrupted in
            self?.handleCameraInterruption(interrupted)
        }
        camera.onRecoveryRequested = { [weak self] in
            self?.resumeCameraIfNeeded()
        }
        camera.onRuntimeFailure = { [weak self] message in
            guard let self else { return }
            self.camera.setAnalysisEnabled(false)
            self.cameraAuthorization = .unavailable
            self.analytics.track(
                "pure_lens_failed",
                ["kind": "camera", "errorType": String(message.prefix(120))]
            )
        }

        if module.configuration.isDemoMode {
            cameraAuthorization = .authorized
        } else if AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) == nil {
            cameraAuthorization = .unavailable
        } else {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                cameraAuthorization = .authorized
                camera.start()
            case .denied:
                cameraAuthorization = .denied
            case .restricted:
                cameraAuthorization = .restricted
            case .notDetermined:
                cameraAuthorization = .notDetermined
            @unknown default:
                cameraAuthorization = .unavailable
            }
        }
    }

    deinit {
        discoveryTasks.forEach { $0.cancel() }
        frameTimeoutTask?.cancel()
        demoTask?.cancel()
        openItemTask?.cancel()
        supportValidationTask?.cancel()
        cameraAuthorizationTask?.cancel()
        camera.stop()
    }

    var localeIdentifier: String {
        configuration.localeIdentifier
            ?? Locale.current.identifier
    }

    var isRightToLeft: Bool {
        Locale.characterDirection(forLanguage: localeIdentifier) == .rightToLeft
    }

    var detectorProgress: Double {
        if case .stabilizing(_, let progress) = detectorState {
            return progress
        }
        return detectorState.isDetected ? 1 : 0
    }

    var liveRecognition: LensPetRecognition? {
        currentRecognition ?? detectorState.recognition
    }

    var isDiscovering: Bool {
        scanPhase == .discovering
    }

    var hasAnyResults: Bool {
        discoverySections.contains { !$0.items.isEmpty }
    }

    var isDiscoveryComplete: Bool {
        pendingPipelines.values.allSatisfy(\.isEmpty)
    }

    var hasDiscoveryFailures: Bool {
        discoverySections.contains { section in
            section.didFail
        }
    }

    var identityCandidates: [LensAnimalIdentityCandidate] {
        guard scanPhase == .uncertain, !hasDismissedIdentityCandidates else { return [] }
        return animalIdentification?.candidates ?? []
    }

    var showsGuidanceAction: Bool {
        guidanceActions != nil && (animalContext != nil || unsupportedAnimalContext != nil)
    }

    var canOpenGuidance: Bool {
        showsGuidanceAction && !isOpeningGuidance
    }

    var localizedAnimalName: String {
        guard let animal = animalContext ?? unsupportedAnimalContext else {
            return localized("lens.results.animal")
        }
        let species = localizedIdentityName(fallback: animal.species)
        guard let breed = animal.breed, !breed.isEmpty else {
            return species
        }
        return "\(species) · \(breed)"
    }

    var remoteProcessingDisclosure: String {
        configuration.remoteProcessingDisclosure
            ?? localized("lens.privacy.consent.detail")
    }

    func localized(_ key: String) -> String {
        LensL10n.string(key, localeIdentifier: localeIdentifier)
    }

    func localizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
        LensL10n.format(
            key,
            arguments: arguments,
            localeIdentifier: localeIdentifier
        )
    }

    func localizedSpecies(_ species: String) -> String {
        let normalized = species
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
        let key = "lens.species.\(normalized)"
        let value = localized(key)
        return value == key ? species : value
    }

    func localizedIdentityName(fallback: String) -> String {
        if isRightToLeft,
           animalIdentification?.status == .identified,
           let arabicName = animalIdentification?.commonNameAr,
           !arabicName.isEmpty {
            return arabicName
        }
        if animalIdentification?.status == .identified,
           let commonName = animalIdentification?.commonName,
           !commonName.isEmpty {
            return localizedSpecies(commonName)
        }
        return localizedSpecies(fallback)
    }

    func localizedCandidateName(_ candidate: LensAnimalIdentityCandidate) -> String {
        if isRightToLeft, let arabicName = candidate.commonNameAr, !arabicName.isEmpty {
            return arabicName
        }
        return localizedSpecies(candidate.commonName)
    }

    func localizedAnimalGroup(_ group: String) -> String {
        let normalized = group
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
        let key = "lens.group.\(normalized)"
        let value = localized(key)
        return value == key ? group : value
    }

    func start() async {
        guard !Task.isCancelled else { return }
        guard !hasStarted else {
            if let task = requestCameraAuthorizationRefresh() {
                _ = await task.value
            } else {
                resumeCameraIfNeeded()
            }
            return
        }
        hasStarted = true
        analytics.track("pure_lens_opened", [:])
        detectionFeedback.prepare()

        if configuration.isDemoMode {
            cameraAuthorization = .authorized
            framePixelSize = CGSize(width: 852, height: 1_846)
            startDemoDetection()
            return
        }

        if let task = requestCameraAuthorizationRefresh() {
            _ = await task.value
        }
    }

    @discardableResult
    private func requestCameraAuthorizationRefresh() -> Task<Void, Never>? {
        guard hasStarted, isAppActive, !configuration.isDemoMode else { return nil }
        if let cameraAuthorizationTask { return cameraAuthorizationTask }

        // Activation can arrive while the initial system permission prompt is
        // resolving. Share that request instead of asking or starting twice.
        let requestID = UUID()
        cameraAuthorizationRequestID = requestID
        let task = Task { [weak self, camera] in
            defer {
                if let self, self.cameraAuthorizationRequestID == requestID {
                    self.cameraAuthorizationTask = nil
                    self.cameraAuthorizationRequestID = nil
                }
            }
            guard !Task.isCancelled else { return }
            let authorization = await camera.authorization()
            guard let self, self.cameraAuthorizationRequestID == requestID else { return }
            self.cameraAuthorizationTask = nil
            self.cameraAuthorizationRequestID = nil
            guard !Task.isCancelled, self.hasStarted, self.isAppActive else { return }
            self.cameraAuthorization = authorization
            if authorization == .authorized {
                self.resumeCameraIfNeeded()
            } else {
                self.camera.stop()
            }
        }
        cameraAuthorizationTask = task
        return task
    }

    func pauseCamera() {
        guard !configuration.isDemoMode else { return }
        camera.stop()
    }

    func resumeCameraIfNeeded() {
        guard hasStarted,
              isAppActive,
              !configuration.isDemoMode,
              !isOpeningGuidance,
              cameraAuthorizationTask == nil,
              cameraAuthorization == .authorized
        else { return }
        let canAnalyze = presentation == nil
            && animalContext == nil
            && unsupportedAnimalContext == nil
            && scanPhase != .validating
            && scanPhase != .unsupported
            && scanPhase != .uncertain
            && scanPhase != .notAnimal
            && scanPhase != .taxonomyUnavailable
            && scanPhase != .validationFailed
        camera.setAnalysisEnabled(canAnalyze)
        camera.start()
    }

    func appBecameActive() {
        isAppActive = true
        guard hasStarted else { return }
        if configuration.isDemoMode {
            if presentation == nil, detectorState == .searching {
                startDemoDetection()
            }
        } else {
            requestCameraAuthorizationRefresh()
        }
    }

    func suspendForBackground() {
        isAppActive = false
        pauseCamera()
    }

    func confirmRemoteProcessing() {
        showsRemoteProcessingConsent = false
        didDeclineRemoteProcessingForCurrentDetection = false
        hasRemoteProcessingConsent = true
        analytics.track(
            "pure_lens_remote_processing_consent_granted",
            ["version": configuration.remoteProcessingConsentVersion]
        )
        guard let frame = pendingConsentFrame else {
            if pendingLocalAnimal != nil,
               currentRecognition != nil {
                pendingLocalAnimal = nil
                markValidationFailed(
                    LensFailure(kind: .noResult, message: "No consented frame was available.")
                )
            } else {
                finishImagePipeline(didFail: true)
            }
            return
        }
        pendingConsentFrame = nil

        if let pendingLocalAnimal, animalContext == nil {
            startAnimalIdentification(frame: frame, animal: pendingLocalAnimal)
            return
        }

        guard let animalContext else {
            finishImagePipeline(didFail: true)
            return
        }
        startImageSearch(frame: frame, animal: animalContext)
    }


    func cancelRemoteProcessing() {
        showsRemoteProcessingConsent = false
        pendingConsentFrame = nil
        didDeclineRemoteProcessingForCurrentDetection = true
        analytics.track("pure_lens_remote_processing_declined", [:])

        if let pendingLocalAnimal,
           animalContext == nil {
            self.pendingLocalAnimal = nil
            representativeFrame = nil
            camera.cancelPendingFrameCapture()
            markUncertain(pendingLocalAnimal)
        } else {
            finishImagePipeline(didFail: false)
        }
    }

    func requestRemoteProcessingConsentAgain() {
        guard representativeFrame != nil else { return }
        pendingConsentFrame = representativeFrame
        showsRemoteProcessingConsent = true
    }

    func open(_ item: LensDiscoveryItem) {
        guard openingItemID == nil else { return }
        showsItemOpenError = false
        openingItemID = item.id
        let actions = discoveryActions
        openItemTask = Task { [weak self] in
            do {
                try await actions.open(item)
                guard let self else { return }
                self.analytics.track(
                    "pure_lens_discovery_item_opened",
                    ["category": item.category.rawValue, "kind": item.kind.rawValue]
                )
                self.openingItemID = nil
                self.openItemTask = nil
            } catch is CancellationError {
                self?.openingItemID = nil
                self?.openItemTask = nil
            } catch {
                guard let self else { return }
                self.openingItemID = nil
                self.openItemTask = nil
                self.showsItemOpenError = true
                self.analytics.track(
                    "pure_lens_discovery_item_open_failed",
                    ["category": item.category.rawValue, "errorType": String(reflecting: type(of: error))]
                )
            }
        }
    }

    func openGuidance() {
        guard !isOpeningGuidance,
              let animal = animalContext ?? unsupportedAnimalContext,
              let guidanceActions
        else { return }

        isOpeningGuidance = true
        let handoff = LensGuidanceHandoff(
            animal: animal,
            displayName: localizedAnimalName,
            isSupported: animalContext != nil
        )

        cancelDiscoveryWork()
        showsRemoteProcessingConsent = false
        representativeFrame = nil
        pendingConsentFrame = nil
        camera.cancelPendingFrameCapture()
        pauseCamera()
        analytics.track(
            "pure_lens_guidance_opened",
            [
                "species": handoff.species,
                "isSupported": handoff.isSupported ? "true" : "false"
            ]
        )
        guidanceActions.open(handoff)
    }

    func canRetryDiscovery(_ category: LensDiscoveryCategory) -> Bool {
        let failures = failedPipelines[category] ?? []
        if failures.contains(.taxonomy) { return true }
        return failures.contains(.imageSearch) && representativeFrame != nil
    }

    func retryDiscovery(_ category: LensDiscoveryCategory) {
        guard let animalContext else { return }
        let failures = failedPipelines[category] ?? []
        guard !failures.isEmpty else { return }

        if failures.contains(.taxonomy) {
            failedPipelines[category, default: []].remove(.taxonomy)
            pendingPipelines[category, default: []].insert(.taxonomy)
            startMarketplaceDiscovery(for: animalContext, categories: [category])
        }

        if failures.contains(.imageSearch) {
            retryImageSearch(for: animalContext)
        }
        rebuildSections()
    }

    func scanAgain() {
        cancelDiscoveryWork()
        isOpeningGuidance = false
        presentation = nil
        showsRemoteProcessingConsent = false
        showsItemOpenError = false
        didDeclineRemoteProcessingForCurrentDetection = false
        animalContext = nil
        unsupportedAnimalContext = nil
        animalIdentification = nil
        hasDismissedIdentityCandidates = false
        didChooseIdentityCandidate = false
        didShareSelectedFrameForAnimalIdentity = false
        pendingLocalAnimal = nil
        currentRecognition = nil
        representativeFrame = nil
        pendingConsentFrame = nil
        detections = []
        detectorState = .searching
        scanPhase = .searching
        detectionStabilizer.reset()
        detectionFeedback.reset()
        taxonomyItems.removeAll(keepingCapacity: true)
        imageItems.removeAll(keepingCapacity: true)
        pendingPipelines.removeAll(keepingCapacity: true)
        failedPipelines.removeAll(keepingCapacity: true)
        discoverySections = LensDiscoveryCategory.allCases.map {
            LensDiscoverySection(category: $0)
        }
        sessionGeneration = UUID()
        imageSearchGeneration = nil
        camera.cancelPendingFrameCapture()
        if configuration.isDemoMode {
            startDemoDetection()
        } else {
            camera.setAnalysisEnabled(true)
            resumeCameraIfNeeded()
        }
    }

    func rejectIdentityCandidates() {
        guard scanPhase == .uncertain, !identityCandidates.isEmpty else { return }
        hasDismissedIdentityCandidates = true
        didChooseIdentityCandidate = false
        animalIdentification = nil
        representativeFrame = nil
        pendingConsentFrame = nil
        pendingLocalAnimal = nil
        currentRecognition = nil
        camera.cancelPendingFrameCapture()
    }

    func selectIdentityCandidate(_ candidate: LensAnimalIdentityCandidate) {
        guard scanPhase == .uncertain,
              !hasDismissedIdentityCandidates,
              identityCandidates.contains(candidate),
              supportValidationTask == nil,
              let frame = representativeFrame,
              let animal = unsupportedAnimalContext,
              let recognition = currentRecognition,
              !needsRemoteProcessingConsent,
              let confirm = discoveryClient.confirmAnimalCandidate
        else { return }

        hasDismissedIdentityCandidates = true
        didChooseIdentityCandidate = true
        scanPhase = .validating
        let generation = sessionGeneration
        supportValidationTask = Task { [weak self] in
            do {
                let result = try await confirm(frame, animal, candidate.canonicalSpecies)
                try Task.checkCancellation()
                guard let self, self.sessionGeneration == generation else { return }
                self.supportValidationTask = nil
                if result.status == .identified,
                   Self.canonicalChoiceKey(result.canonicalSpecies)
                    != Self.canonicalChoiceKey(candidate.canonicalSpecies) {
                    self.animalIdentification = nil
                    self.markUncertain(animal)
                    return
                }
                self.animalIdentification = result
                self.applyAnimalIdentification(
                    result,
                    originalAnimal: animal,
                    recognition: recognition,
                    frame: frame
                )
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.sessionGeneration == generation else { return }
                self.supportValidationTask = nil
                self.markAnimalIdentificationFailure(error, animal: animal)
            }
        }
    }

    private static func canonicalChoiceKey(_ species: String) -> String {
        species.lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    func dismissPresentation() {
        guard !isOpeningGuidance else { return }
        let needsReset = animalContext != nil
            || representativeFrame != nil
            || scanPhase != .searching
        if needsReset {
            scanAgain()
        }
    }

    func cancelActiveWork() {
        hasStarted = false
        cameraAuthorizationRequestID = nil
        cameraAuthorizationTask?.cancel()
        cameraAuthorizationTask = nil
        cancelDiscoveryWork()
        sessionGeneration = UUID()
        representativeFrame = nil
        pendingConsentFrame = nil
        pendingLocalAnimal = nil
        animalIdentification = nil
        currentRecognition = nil
        demoTask?.cancel()
        demoTask = nil
        camera.cancelPendingFrameCapture()
        detectionFeedback.stop()
    }

    private func receive(_ event: PureLensCameraFrameEvent) {
        framePixelSize = event.pixelSize
        if case .degraded(let message) = event.detectorHealth {
            analytics.track(
                "pure_lens_detector_degraded",
                ["errorType": String(message.prefix(120))]
            )
        } else if case .failed(let message) = event.detectorHealth {
            analytics.track(
                "pure_lens_failed",
                ["kind": "detector", "errorType": String(message.prefix(120))]
            )
        }

        if animalContext != nil {
            if let boundFrame = event.boundFrame {
                receiveRepresentativeFrame(boundFrame)
            }
            return
        }

        if pendingLocalAnimal != nil, scanPhase == .validating {
            if let boundFrame = event.boundFrame {
                receiveIdentityFrame(boundFrame)
            }
            return
        }

        if scanPhase == .validating
            || scanPhase == .unsupported
            || scanPhase == .uncertain
            || scanPhase == .notAnimal
            || scanPhase == .taxonomyUnavailable
            || scanPhase == .validationFailed {
            return
        }

        detections = event.detections
        let previousState = detectorState
        detectorState = detectionStabilizer.ingest(event.detections)
        updateScanPhase()

        guard case .detected(let recognition) = detectorState,
              !previousState.isDetected
        else { return }
        validateAndBeginDiscovery(for: recognition)
    }

    private func updateScanPhase() {
        switch detectorState {
        case .searching:
            scanPhase = .searching
        case .stabilizing(_, let progress):
            scanPhase = progress <= (1.0 / Double(max(2, configuration.stableDetectionFrameCount)))
                ? .candidateFound
                : .confirming
        case .detected:
            scanPhase = .validating
        }
    }

    private func validateAndBeginDiscovery(for recognition: LensPetRecognition) {
        guard supportValidationTask == nil, animalContext == nil else { return }
        let animal = DetectedAnimalContext(
            recognition: recognition,
            minimumBreedConfidence: configuration.minimumBreedConfidence,
            detectionSource: detectionSource(for: recognition)
        )
        currentRecognition = recognition
        pendingLocalAnimal = animal
        camera.setAnalysisEnabled(false)
        scanPhase = .validating

        guard discoveryClient.identifyAnimal != nil,
              configuration.frameUploadPolicy == .selectedFrame
        else {
            pendingLocalAnimal = nil
            validateLocalSupport(animal, recognition: recognition)
            return
        }
        camera.setAnalysisEnabled(true)
        camera.requestFrameCapture(for: recognition)
        startRepresentativeFrameTimeout()
    }

    private func validateLocalSupport(
        _ animal: DetectedAnimalContext,
        recognition: LensPetRecognition
    ) {
        let isLocalCandidate = LensLocalIdentitySpecificity.isSufficientForSupport(
            species: animal.species,
            breed: animal.breed
        ) || LensLocalIdentitySpecificity.isSufficientForSupport(
            species: recognition.species,
            breed: recognition.breed
        ) || (discoveryClient.resolveAnimalSupport != nil &&
              LensLocalIdentitySpecificity.isCategoryResolvable(species: animal.species))

        guard isLocalCandidate else {
            markUncertain(animal)
            return
        }

        let generation = sessionGeneration
        let client = discoveryClient
        supportValidationTask = Task { [weak self] in
            do {
                if let resolveAnimalSupport = client.resolveAnimalSupport {
                    let support = try await resolveAnimalSupport(animal)
                    try Task.checkCancellation()
                    guard let self, self.sessionGeneration == generation else { return }
                    self.supportValidationTask = nil
                    guard let support,
                          let scope = LensCommerceScope(mainKindID: support.mainKindID)
                    else {
                        self.markUnsupported(animal)
                        return
                    }
                    var scopedAnimal = animal
                    scopedAnimal.businessMainKindID = scope.mainKindID
                    self.analytics.track(
                        "pure_lens_identity_supported",
                        [
                            "species": scopedAnimal.species,
                            "confidence": String(format: "%.3f", scopedAnimal.confidence)
                        ]
                    )
                    self.beginDiscovery(for: recognition, animal: scopedAnimal)
                    return
                }

                let legacySupported = try await client.isAnimalSupported(animal)
                try Task.checkCancellation()
                guard let self, self.sessionGeneration == generation else { return }
                self.supportValidationTask = nil
                if legacySupported {
                    self.analytics.track(
                        "pure_lens_commerce_scope_rejected",
                        ["species": animal.species]
                    )
                    self.markValidationFailed(
                        LensFailure(
                            kind: .safety,
                            message: "Canonical animal category scope is unavailable.",
                            canRetry: true
                        )
                    )
                } else {
                    self.markUnsupported(animal)
                }
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.sessionGeneration == generation else { return }
                self.supportValidationTask = nil
                self.markTaxonomyUnavailable(animal, error: error)
            }
        }
    }

    private func receiveIdentityFrame(_ boundFrame: LensBoundFrame) {
        guard let recognition = currentRecognition,
              let pendingLocalAnimal,
              boundFrame.isValid(
                for: recognition,
                maximumAge: configuration.maximumSelectedFrameAge,
                spatialConfiguration: configuration.spatialAssociation
              )
        else { return }

        frameTimeoutTask?.cancel()
        frameTimeoutTask = nil
        representativeFrame = boundFrame.frame
        camera.setAnalysisEnabled(false)

        if needsRemoteProcessingConsent {
            pendingConsentFrame = boundFrame.frame
            showsRemoteProcessingConsent = true
        } else {
            startAnimalIdentification(frame: boundFrame.frame, animal: pendingLocalAnimal)
        }
    }

    private func startAnimalIdentification(
        frame: LensFrame,
        animal: DetectedAnimalContext
    ) {
        guard supportValidationTask == nil,
              let identifyAnimal = discoveryClient.identifyAnimal,
              let recognition = currentRecognition
        else { return }
        didShareSelectedFrameForAnimalIdentity = true
        let generation = sessionGeneration
        supportValidationTask = Task { [weak self] in
            do {
                let result = try await identifyAnimal(frame, animal)
                try Task.checkCancellation()
                guard let self, self.sessionGeneration == generation else { return }
                self.supportValidationTask = nil
                self.animalIdentification = result
                self.pendingLocalAnimal = nil
                self.applyAnimalIdentification(
                    result,
                    originalAnimal: animal,
                    recognition: recognition,
                    frame: frame
                )
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.sessionGeneration == generation else { return }
                self.supportValidationTask = nil
                self.pendingLocalAnimal = nil
                self.analytics.track(
                    "pure_lens_animal_identity_failed",
                    ["errorType": String(reflecting: type(of: error))]
                )
                let canResolveLocally = self.discoveryClient.resolveAnimalSupport != nil
                    || LensLocalIdentitySpecificity.isSufficientForSupport(species: animal.species, breed: animal.breed)
                if canResolveLocally {
                    self.validateLocalSupport(animal, recognition: recognition)
                } else {
                    self.markAnimalIdentificationFailure(error, animal: animal)
                }
            }
        }
    }

    private func applyAnimalIdentification(
        _ result: LensAnimalIdentificationResult,
        originalAnimal: DetectedAnimalContext,
        recognition: LensPetRecognition,
        frame: LensFrame
    ) {
        let refined = result.refinedAnimal(
            from: originalAnimal,
            minimumBreedConfidence: configuration.minimumBreedConfidence
        )
        switch LensAnimalDiscoveryPolicy.decision(for: result) {
        case .discover(let scope):
            var scopedAnimal = refined
            scopedAnimal.businessMainKindID = scope.mainKindID
            analytics.track(
                "pure_lens_identity_supported",
                [
                    "species": scopedAnimal.species,
                    "confidence": String(format: "%.3f", scopedAnimal.confidence)
                ]
            )
            beginDiscovery(for: recognition, animal: scopedAnimal, validatedFrame: frame)
        case .unsupported:
            markUnsupported(refined)
        case .uncertain:
            markUncertain(refined)
        case .notAnimal:
            markNotAnimal(refined)
        }
    }

    private func markUnsupported(_ animal: DetectedAnimalContext) {
        representativeFrame = nil
        unsupportedAnimalContext = animal
        scanPhase = .unsupported
        let properties = [
            "species": animal.species,
            "confidence": String(format: "%.3f", animal.confidence)
        ]
        analytics.track("pure_lens_unsupported_subject", properties)
        analytics.track("pure_lens_identity_unsupported", properties)
    }

    private func markUncertain(_ animal: DetectedAnimalContext) {
        if hasDismissedIdentityCandidates || animalIdentification?.candidates.isEmpty != false {
            representativeFrame = nil
        }
        unsupportedAnimalContext = animal
        scanPhase = .uncertain
        analytics.track(
            "pure_lens_identity_uncertain",
            [
                "species": animal.species,
                "confidence": String(format: "%.3f", animal.confidence)
            ]
        )
    }

    private func markNotAnimal(_ animal: DetectedAnimalContext) {
        representativeFrame = nil
        unsupportedAnimalContext = animal
        scanPhase = .notAnimal
        analytics.track("pure_lens_identity_not_animal", [:])
    }

    private func markTaxonomyUnavailable(_ animal: DetectedAnimalContext, error: Error) {
        representativeFrame = nil
        unsupportedAnimalContext = animal
        scanPhase = .taxonomyUnavailable
        analytics.track(
            "pure_lens_taxonomy_unavailable",
            ["errorType": String(reflecting: type(of: error))]
        )
    }

    private func markAnimalIdentificationFailure(
        _ error: Error,
        animal: DetectedAnimalContext
    ) {
        analytics.track(
            "pure_lens_animal_identity_failed",
            ["errorType": String(reflecting: type(of: error))]
        )
        if let failure = error as? LensAnimalIdentityServiceError,
           failure == .taxonomyUnavailable {
            markTaxonomyUnavailable(animal, error: error)
        } else {
            markValidationFailed(error)
        }
    }

    private func markValidationFailed(_ error: Error) {
        representativeFrame = nil
        scanPhase = .validationFailed
        analytics.track(
            "pure_lens_taxonomy_validation_failed",
            ["errorType": String(reflecting: type(of: error))]
        )
    }

    private func detectionSource(
        for recognition: LensPetRecognition
    ) -> LensAnimalDetectionSource {
        let matchingKinds = detections.compactMap { detection -> LensDetectionKind? in
            guard let candidate = LensPetRecognition.parse(detection),
                  recognition.isSameInstance(
                    as: candidate,
                    configuration: configuration.spatialAssociation
                  )
            else { return nil }
            return detection.kind
        }
        let hasVision = matchingKinds.contains(.animal)
        let hasCoreML = matchingKinds.contains(.object)
        if hasVision && hasCoreML { return .fusedOnDevice }
        if hasCoreML { return .onDeviceCoreML }
        return .onDeviceVision
    }

    private func beginDiscovery(
        for recognition: LensPetRecognition,
        animal: DetectedAnimalContext,
        validatedFrame: LensFrame? = nil
    ) {
        guard let scope = LensCommerceScope(mainKindID: animal.businessMainKindID ?? 0) else {
            analytics.track(
                "pure_lens_commerce_scope_rejected",
                ["species": animal.species]
            )
            markValidationFailed(
                LensFailure(
                    kind: .safety,
                    message: "Canonical animal category scope is missing.",
                    canRetry: true
                )
            )
            return
        }
        var scopedAnimal = animal
        scopedAnimal.businessMainKindID = scope.mainKindID
        animalContext = scopedAnimal
        scanPhase = .confirmed
        let feedbackPlayed = detectionFeedback.playDetection(
            for: recognition,
            cooldown: configuration.detectionFeedbackCooldown
        )
        analytics.track(
            "pure_lens_pet_detected",
            [
                "species": scopedAnimal.species,
                "confidence": String(format: "%.3f", scopedAnimal.confidence),
                "feedbackPlayed": feedbackPlayed ? "true" : "false"
            ]
        )

        initializeDiscoverySections()
        presentation = LensPresentation()
        scanPhase = .discovering
        startMarketplaceDiscovery(for: scopedAnimal)

        switch configuration.frameUploadPolicy {
        case .metadataOnly:
            camera.setAnalysisEnabled(false)
        case .selectedFrame:
            if let validatedFrame {
                representativeFrame = validatedFrame
                camera.setAnalysisEnabled(false)
                startImageSearch(frame: validatedFrame, animal: scopedAnimal)
            } else {
                camera.setAnalysisEnabled(true)
                camera.requestFrameCapture(for: recognition)
                startRepresentativeFrameTimeout()
            }
        }
    }

    private func initializeDiscoverySections() {
        taxonomyItems.removeAll(keepingCapacity: true)
        imageItems.removeAll(keepingCapacity: true)
        failedPipelines.removeAll(keepingCapacity: true)
        pendingPipelines.removeAll(keepingCapacity: true)

        let needsImageSearch: Bool
        switch configuration.frameUploadPolicy {
        case .selectedFrame: needsImageSearch = true
        case .metadataOnly: needsImageSearch = false
        }
        for category in LensDiscoveryCategory.allCases {
            var pipelines: Set<LensDiscoveryPipeline> = [.taxonomy]
            if needsImageSearch, category != .services {
                pipelines.insert(.imageSearch)
            }
            pendingPipelines[category] = pipelines
        }
        rebuildSections()
    }

    private func startMarketplaceDiscovery(
        for animal: DetectedAnimalContext,
        categories: [LensDiscoveryCategory] = LensDiscoveryCategory.allCases
    ) {
        guard let scope = LensCommerceScope(mainKindID: animal.businessMainKindID ?? 0) else {
            analytics.track(
                "pure_lens_commerce_scope_rejected",
                ["species": animal.species]
            )
            return
        }
        let generation = sessionGeneration
        let client = discoveryClient
        for category in categories {
            let task = Task { [weak self] in
                do {
                    let items = try await client.searchMarketplace(category, animal)
                    try Task.checkCancellation()
                    guard let self, self.sessionGeneration == generation else { return }
                    let categoryItems = items.filter { $0.category == category }
                    self.taxonomyItems[category] = scope.filterCompatible(categoryItems)
                    self.complete(.taxonomy, for: category, didFail: false)
                } catch is CancellationError {
                    return
                } catch {
                    guard let self, self.sessionGeneration == generation else { return }
                    self.taxonomyItems[category] = []
                    self.complete(.taxonomy, for: category, didFail: true)
                    self.analytics.track(
                        "pure_lens_discovery_category_failed",
                        ["category": category.rawValue, "errorType": String(reflecting: type(of: error))]
                    )
                }
            }
            discoveryTasks.append(task)
        }
    }

    private func receiveRepresentativeFrame(_ boundFrame: LensBoundFrame) {
        guard let recognition = currentRecognition,
              boundFrame.isValid(
                for: recognition,
                maximumAge: configuration.maximumSelectedFrameAge,
                spatialConfiguration: configuration.spatialAssociation
              ),
              imageSearchGeneration == nil
        else { return }

        frameTimeoutTask?.cancel()
        frameTimeoutTask = nil
        representativeFrame = boundFrame.frame
        camera.setAnalysisEnabled(false)

        guard let animalContext else {
            finishImagePipeline(didFail: true)
            return
        }
        if needsRemoteProcessingConsent {
            pendingConsentFrame = boundFrame.frame
            showsRemoteProcessingConsent = true
        } else {
            startImageSearch(frame: boundFrame.frame, animal: animalContext)
        }
    }

    private var needsRemoteProcessingConsent: Bool {
        configuration.requiresRemoteProcessingConsent && !hasRemoteProcessingConsent
    }

    private func startRepresentativeFrameTimeout() {
        frameTimeoutTask?.cancel()
        let generation = sessionGeneration
        let timeout = configuration.representativeFrameTimeout
        frameTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            guard !Task.isCancelled,
                  let self,
                  self.sessionGeneration == generation,
                  self.representativeFrame == nil
            else { return }
            self.camera.cancelPendingFrameCapture()
            self.camera.setAnalysisEnabled(false)
            if let pendingLocalAnimal = self.pendingLocalAnimal,
               let recognition = self.currentRecognition,
               self.animalContext == nil {
                self.pendingLocalAnimal = nil
                let canResolveLocally = self.discoveryClient.resolveAnimalSupport != nil
                    || LensLocalIdentitySpecificity.isSufficientForSupport(
                        species: pendingLocalAnimal.species,
                        breed: pendingLocalAnimal.breed
                    )
                if canResolveLocally {
                    self.validateLocalSupport(pendingLocalAnimal, recognition: recognition)
                } else {
                    self.markUncertain(pendingLocalAnimal)
                }
                return
            }
            self.finishImagePipeline(didFail: true)
        }
    }

    private func startImageSearch(
        frame: LensFrame,
        animal: DetectedAnimalContext
    ) {
        guard let scope = LensCommerceScope(mainKindID: animal.businessMainKindID ?? 0) else {
            analytics.track(
                "pure_lens_commerce_scope_rejected",
                ["species": animal.species]
            )
            return
        }
        let generation = sessionGeneration
        guard imageSearchGeneration == nil else { return }
        imageSearchGeneration = generation
        let client = discoveryClient
        let task = Task { [weak self] in
            do {
                let result = try await client.searchByImage(frame, animal)
                try Task.checkCancellation()
                guard let self, self.sessionGeneration == generation else { return }
                let scopedItems = scope.filteredImageSearch(result)
                let grouped = Dictionary(grouping: scopedItems, by: \.category)
                for category in LensDiscoveryCategory.allCases where category != .services {
                    self.imageItems[category] = grouped[category] ?? []
                    self.complete(.imageSearch, for: category, didFail: false)
                }
                self.analytics.track(
                    "pure_lens_image_search_completed",
                    ["resultCount": String(scopedItems.count)]
                )
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.sessionGeneration == generation else { return }
                self.finishImagePipeline(didFail: true)
                self.analytics.track(
                    "pure_lens_image_search_failed",
                    ["errorType": String(reflecting: type(of: error))]
                )
            }
        }
        discoveryTasks.append(task)
    }

    private func retryImageSearch(for animal: DetectedAnimalContext) {
        guard let representativeFrame else { return }
        let categories = LensDiscoveryCategory.allCases.filter { category in
            category != .services
                && (failedPipelines[category] ?? []).contains(.imageSearch)
        }
        guard !categories.isEmpty else { return }

        for category in categories {
            failedPipelines[category, default: []].remove(.imageSearch)
            pendingPipelines[category, default: []].insert(.imageSearch)
        }
        imageSearchGeneration = nil
        startImageSearch(frame: representativeFrame, animal: animal)
    }

    private func finishImagePipeline(didFail: Bool) {
        for category in LensDiscoveryCategory.allCases where category != .services {
            complete(.imageSearch, for: category, didFail: didFail)
        }
    }

    private func complete(
        _ pipeline: LensDiscoveryPipeline,
        for category: LensDiscoveryCategory,
        didFail: Bool
    ) {
        pendingPipelines[category, default: []].remove(pipeline)
        if didFail {
            failedPipelines[category, default: []].insert(pipeline)
        }
        rebuildSections()
    }

    private func rebuildSections() {
        guard let animalContext else {
            discoverySections = LensDiscoveryCategory.allCases.map {
                LensDiscoverySection(category: $0)
            }
            return
        }
        discoverySections = LensDiscoveryCategory.allCases.map { category in
            LensDiscoverySection(
                category: category,
                items: LensDiscoveryRanking.merge(
                    taxonomyItems: taxonomyItems[category] ?? [],
                    imageItems: imageItems[category] ?? [],
                    for: animalContext,
                    category: category,
                    limit: configuration.discoveryItemLimit
                ),
                isLoading: !(pendingPipelines[category] ?? []).isEmpty,
                didFail: !(failedPipelines[category] ?? []).isEmpty
            )
        }

        if hasAnyResults || isDiscoveryComplete {
            scanPhase = .results
        } else {
            scanPhase = .discovering
        }
    }

    private func cancelDiscoveryWork() {
        supportValidationTask?.cancel()
        supportValidationTask = nil
        discoveryTasks.forEach { $0.cancel() }
        discoveryTasks.removeAll(keepingCapacity: true)
        frameTimeoutTask?.cancel()
        frameTimeoutTask = nil
        openItemTask?.cancel()
        openItemTask = nil
        openingItemID = nil
        imageSearchGeneration = nil
    }

    private func handleCameraInterruption(_ interrupted: Bool) {
        isCameraInterrupted = interrupted
        if !interrupted {
            resumeCameraIfNeeded()
        }
    }

    private func startDemoDetection() {
        demoTask?.cancel()
        let detection = LensLocalDetection(
            kind: .animal,
            label: "dog",
            confidence: 0.91,
            boundingBox: LensNormalizedRect(x: 0.20, y: 0.31, width: 0.60, height: 0.43)
        )
        demoTask = Task { [weak self] in
            guard let self else { return }
            for _ in 0..<self.configuration.stableDetectionFrameCount {
                try? await Task.sleep(nanoseconds: 360_000_000)
                guard !Task.isCancelled, self.animalContext == nil else { return }
                self.detections = [detection]
                let previous = self.detectorState
                self.detectorState = self.detectionStabilizer.ingest([detection])
                self.updateScanPhase()
                if case .detected(let recognition) = self.detectorState,
                   !previous.isDetected {
                    self.validateAndBeginDiscovery(for: recognition)
                    return
                }
            }
        }
    }
}

#endif
