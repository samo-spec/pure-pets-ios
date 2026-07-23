import Foundation

struct PPPetAdOwner {
    let user: UserModel
    let displayName: String
    let avatarURL: String?
    let phoneNumber: String?
    let isVerified: Bool
    let isChatAllowed: Bool

    init(user: UserModel) {
        self.user = user
        displayName = PPPetAdViewerLegacyBridge.displayName(for: user)
        avatarURL = PPPetAdViewerLegacyBridge.avatarURL(for: user)
        phoneNumber = PPPetAdViewerLegacyBridge.phoneNumber(for: user)
        isVerified = PPPetAdViewerLegacyBridge.isVerified(user: user)
        isChatAllowed =
            PPPetAdViewerLegacyBridge.isChatAllowed(for: user)
    }
}
