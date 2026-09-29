import Foundation

public struct LensPolicyConfiguration: Equatable, Sendable {
    public var minimumConfidence: Double
    public var allowedActions: Set<LensActionKind>
    public var requireVerifiedMedicineSource: Bool

    public init(
        minimumConfidence: Double = 0.58,
        allowedActions: Set<LensActionKind> = Set(LensActionKind.allCases.filter { $0 != .none }),
        requireVerifiedMedicineSource: Bool = true
    ) {
        self.minimumConfidence = min(max(minimumConfidence, 0), 1)
        self.allowedActions = allowedActions
        self.requireVerifiedMedicineSource = requireVerifiedMedicineSource
    }
}

public enum LensPolicyRejection: Error, Equatable, LocalizedError, Sendable {
    case lowConfidence
    case expired
    case unsupportedAction
    case missingPayload(String)
    case writeWithoutConfirmation
    case medicalDiagnosis
    case medicalDosage
    case unverifiedMedicine
    case requiresHumanReview

    public var errorDescription: String? {
        switch self {
        case .lowConfidence:
            return "The result is not confident enough to show."
        case .expired:
            return "The result is no longer current."
        case .unsupportedAction:
            return "This action is not enabled."
        case .missingPayload(let key):
            return "The action is missing its required \(key) value."
        case .writeWithoutConfirmation:
            return "A write action must require user confirmation."
        case .medicalDiagnosis:
            return "Pure Lens cannot provide a diagnosis."
        case .medicalDosage:
            return "Pure Lens cannot provide medicine dosage."
        case .unverifiedMedicine:
            return "Medicine information must come from a verified source."
        case .requiresHumanReview:
            return "This result needs a qualified human review."
        }
    }
}

public struct LensPolicyEngine: Sendable {
    public var configuration: LensPolicyConfiguration

    public init(configuration: LensPolicyConfiguration = .init()) {
        self.configuration = configuration
    }

    public func validate(_ insight: LensInsight, now: Date = Date()) throws -> LensInsight {
        guard insight.confidence.isFinite,
              (0...1).contains(insight.confidence),
              insight.confidence >= configuration.minimumConfidence
        else {
            throw LensPolicyRejection.lowConfidence
        }
        if let expiresAt = insight.expiresAt, expiresAt <= now {
            throw LensPolicyRejection.expired
        }
        guard configuration.allowedActions.contains(insight.action.kind) else {
            throw LensPolicyRejection.unsupportedAction
        }
        try validatePayload(for: insight.action)
        if insight.action.kind.isWriteAction && !insight.action.requiresConfirmation {
            throw LensPolicyRejection.writeWithoutConfirmation
        }
        switch insight.safety.medicalContent {
        case .diagnosis:
            throw LensPolicyRejection.medicalDiagnosis
        case .dosage:
            throw LensPolicyRejection.medicalDosage
        case .verifiedPackageInformation:
            if configuration.requireVerifiedMedicineSource && !insight.safety.hasVerifiedSource {
                throw LensPolicyRejection.unverifiedMedicine
            }
        case .symptomTriage:
            if insight.safety.requiresHumanReview,
               insight.action.kind != .bookVet,
               insight.action.kind != .contactSupport {
                throw LensPolicyRejection.requiresHumanReview
            }
        case .none:
            break
        }
        if insight.action.kind == .openVerifiedMedicine,
           (insight.safety.medicalContent != .verifiedPackageInformation || !insight.safety.hasVerifiedSource) {
            throw LensPolicyRejection.unverifiedMedicine
        }
        return insight
    }

    private func validatePayload(for action: LensAction) throws {
        let requiredKey: String?
        switch action.kind {
        case .prepareCart, .openProduct:
            requiredKey = "productID"
        case .openVerifiedMedicine:
            requiredKey = "medicineID"
        case .bookVet, .createListingDraft, .openAdoption, .contactSupport, .none:
            requiredKey = nil
        }

        if let requiredKey,
           action.payload[requiredKey]?.isEmpty != false {
            throw LensPolicyRejection.missingPayload(requiredKey)
        }
    }
}
