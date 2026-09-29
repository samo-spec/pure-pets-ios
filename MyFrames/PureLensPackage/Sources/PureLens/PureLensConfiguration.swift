#if canImport(UIKit)
import Foundation
import PureLensCore

public enum PureLensFrameUploadPolicy: Sendable {
    /// A single compressed keyframe is sent only after a stable pet detection
    /// and explicit consent when consent is required.
    case selectedFrame
    /// Only on-device detections and authenticated account context are sent.
    case metadataOnly
}

public enum PureLensBarcodeHandling: Sendable, Equatable {
    /// Barcode Vision requests are not executed. This is the production default
    /// for the pet detector and prevents unrelated QR data from entering memory.
    case disabled
    /// Barcode presence and geometry remain local/remote metadata, but payloads
    /// are discarded before a camera event or resolver request is created.
    case presenceOnly
    /// Payloads may be included only after the same explicit remote-processing
    /// consent used by the selected-frame flow.
    case remotePayloadWithConsent
}

public struct PureLensConfiguration: Sendable {
    public var frameUploadPolicy: PureLensFrameUploadPolicy
    public var analysisInterval: TimeInterval
    public var maximumFrameDimension: Int
    public var maximumSelectedFrameAge: TimeInterval
    public var requestTimeout: TimeInterval
    public var automaticallyResolvesDetections: Bool
    public var minimumDetectionConfidence: Double
    public var minimumBreedConfidence: Double
    public var stableDetectionFrameCount: Int
    public var replacementStableFrameCount: Int
    public var lostDetectionFrameTolerance: Int
    public var spatialAssociation: LensSpatialAssociationConfiguration
    public var hapticsEnabled: Bool
    public var detectionSoundEnabled: Bool
    public var detectionFeedbackCooldown: TimeInterval
    public var detectorFailureReportCooldown: TimeInterval
    public var representativeFrameTimeout: TimeInterval
    public var discoveryItemLimit: Int
    public var pausesAnalysisDuringResolution: Bool
    public var barcodeHandling: PureLensBarcodeHandling
    public var showsPrivacyNotice: Bool
    public var requiresRemoteProcessingConsent: Bool
    public var hasPriorRemoteProcessingConsent: Bool
    public var remoteProcessingConsentVersion: String
    public var remoteProcessingDisclosure: String?
    public var localeIdentifier: String?
    public var isDemoMode: Bool
    public var policy: LensPolicyConfiguration

    public init(
        frameUploadPolicy: PureLensFrameUploadPolicy = .selectedFrame,
        analysisInterval: TimeInterval = 0.38,
        maximumFrameDimension: Int = 1_024,
        maximumSelectedFrameAge: TimeInterval = 4,
        requestTimeout: TimeInterval = 15,
        automaticallyResolvesDetections: Bool = true,
        minimumDetectionConfidence: Double = 0.58,
        minimumBreedConfidence: Double = 0.74,
        stableDetectionFrameCount: Int = 3,
        replacementStableFrameCount: Int = 4,
        lostDetectionFrameTolerance: Int = 2,
        spatialAssociation: LensSpatialAssociationConfiguration = .default,
        hapticsEnabled: Bool = true,
        detectionSoundEnabled: Bool = true,
        detectionFeedbackCooldown: TimeInterval = 3,
        detectorFailureReportCooldown: TimeInterval = 5,
        representativeFrameTimeout: TimeInterval = 2.8,
        discoveryItemLimit: Int = 12,
        pausesAnalysisDuringResolution: Bool = true,
        barcodeHandling: PureLensBarcodeHandling = .disabled,
        showsPrivacyNotice: Bool = true,
        requiresRemoteProcessingConsent: Bool = true,
        hasPriorRemoteProcessingConsent: Bool = false,
        remoteProcessingConsentVersion: String = "",
        remoteProcessingDisclosure: String? = nil,
        localeIdentifier: String? = nil,
        isDemoMode: Bool = false,
        policy: LensPolicyConfiguration = .init()
    ) {
        self.frameUploadPolicy = frameUploadPolicy
        self.analysisInterval = min(max(0.20, analysisInterval), 1)
        self.maximumFrameDimension = min(max(512, maximumFrameDimension), 2_048)
        self.maximumSelectedFrameAge = min(max(1, maximumSelectedFrameAge), 8)
        self.requestTimeout = min(max(5, requestTimeout), 30)
        self.automaticallyResolvesDetections = automaticallyResolvesDetections
        self.minimumDetectionConfidence = min(max(minimumDetectionConfidence, 0), 1)
        self.minimumBreedConfidence = min(max(minimumBreedConfidence, 0), 1)
        self.stableDetectionFrameCount = max(1, stableDetectionFrameCount)
        self.replacementStableFrameCount = max(1, replacementStableFrameCount)
        self.lostDetectionFrameTolerance = max(0, lostDetectionFrameTolerance)
        self.spatialAssociation = spatialAssociation
        self.hapticsEnabled = hapticsEnabled
        self.detectionSoundEnabled = detectionSoundEnabled
        self.detectionFeedbackCooldown = max(0, detectionFeedbackCooldown)
        self.detectorFailureReportCooldown = max(0, detectorFailureReportCooldown)
        self.representativeFrameTimeout = min(max(1, representativeFrameTimeout), 6)
        self.discoveryItemLimit = min(max(1, discoveryItemLimit), 24)
        self.pausesAnalysisDuringResolution = pausesAnalysisDuringResolution
        self.barcodeHandling = barcodeHandling
        self.showsPrivacyNotice = showsPrivacyNotice
        self.requiresRemoteProcessingConsent = requiresRemoteProcessingConsent
        self.hasPriorRemoteProcessingConsent = hasPriorRemoteProcessingConsent
        self.remoteProcessingConsentVersion = remoteProcessingConsentVersion
        self.remoteProcessingDisclosure = remoteProcessingDisclosure
        self.localeIdentifier = localeIdentifier
        self.isDemoMode = isDemoMode
        self.policy = policy
    }

    public static let production = Self()

    public static let demo = Self(
        frameUploadPolicy: .metadataOnly,
        barcodeHandling: .disabled,
        showsPrivacyNotice: false,
        requiresRemoteProcessingConsent: false,
        isDemoMode: true
    )
}


#endif
