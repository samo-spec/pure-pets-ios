import Foundation

/// Machine-readable integration contract shared by every Pure Lens entry point.
/// A saved Pet Profile may provide a hint, but it is never an eligibility gate.
public enum PurePetsEyesIntegrationContract {
    public static let featureIdentifier = "pure_pets_eyes"
    public static let requiresSavedPetProfile = false
    public static let allowsAnonymousScanning = true
    public static let requiresUserConfirmationForWrites = true

    /// Kept for source compatibility with existing entry points. Pet Profile
    /// contents do not affect scanner eligibility.
    public static func isEligible(context _: LensContext) -> Bool {
        true
    }
}
