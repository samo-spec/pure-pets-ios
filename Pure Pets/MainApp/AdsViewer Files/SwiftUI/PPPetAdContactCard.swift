import Foundation
import SwiftUI

/// Trust & Action surface of the viewer: who is selling, and how to reach them.
///
/// Features a sleek horizontal action bar with Chat as primary CTA and WhatsApp/Call
/// as compact side-by-side secondary actions, reducing card height by 50%.
struct PPPetAdContactCard: View {
    @ObservedObject var store: PPPetAdViewerStore

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: PPSpace.sm + 2) {
            if !store.isSignedIn {
                signedOutContent
            } else if store.isViewingOwnAdvertisement {
                ownAdvertisementContent
            } else if let owner = store.owner {
                ownerHeaderRow(owner: owner)
                horizontalActionBar(owner: owner)
            } else {
                unavailableOwner
            }
        }
        .padding(PPSpace.base)
        .frame(maxWidth: .infinity)
        .ppCard()
    }

    // MARK: - Owner Header Row

    private var ownerAvatarSessionState: PPRootSessionState {
        PPRootSessionState(
            isLoggedIn: true,
            displayName: store.owner?.displayName ?? "",
            userImageUrl: store.owner.flatMap {
                URL(string: $0.avatarURL ?? "")
            }
        )
    }

    private func ownerHeaderRow(owner: PPPetAdOwner) -> some View {
        HStack(spacing: PPSpace.sm) {
            PPRootAvatarView(
                sessionState: ownerAvatarSessionState,
                isSelected: false
            )
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(owner.displayName)
                    .font(PPPetAdTypography.subheadlineBold)
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineLimit(1)

                HStack(spacing: PPSpace.xs) {
                    if owner.isVerified {
                        Label {
                            Text(PPPetAdLocalization.text("Verified", fallback: "Verified"))
                        } icon: {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Color.ppPrimary)
                        }
                        .font(PPPetAdTypography.caption)
                        .foregroundStyle(Color.ppPrimary)
                    } else {
                        Text(PPPetAdLocalization.text("Advertiser", fallback: "Advertiser"))
                            .font(PPPetAdTypography.caption)
                            .foregroundStyle(Color.ppTextSecondary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(owner.displayName), \(PPPetAdLocalization.text("Contact", fallback: "contact"))")
    }

    // MARK: - Horizontal Action Bar (Chat + WhatsApp + Call)

    private func horizontalActionBar(owner: PPPetAdOwner) -> some View {
        HStack(spacing: PPSpace.xs + 2) {
            // Primary Chat Button (takes ~50% width)
            chatActionButton(for: owner)

            // Secondary WhatsApp Button
            if owner.phoneNumber?.isEmpty == false {
                whatsAppActionButton(for: owner)
            }

            // Secondary Call Button
            if store.canCallOwner, owner.phoneNumber?.isEmpty == false {
                callActionButton(for: owner)
            }
        }
    }

    private func chatActionButton(for owner: PPPetAdOwner) -> some View {
        Button(action: { store.openChat() }) {
            HStack(spacing: PPSpace.xs) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 15, weight: .bold))
                Text(PPPetAdLocalization.text("Chat", fallback: "Chat"))
                    .font(PPPetAdTypography.calloutBold)
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(PPGradient.hero)
            .clipShape(Capsule())
            .shadow(color: Color.ppPrimary.opacity(0.24), radius: 8, y: 4)
        }
        .buttonStyle(PPPetAdPressButtonStyle())
        .accessibilityLabel("\(PPPetAdLocalization.text("Chat", fallback: "Chat")) \(owner.displayName)")
    }

    private func whatsAppActionButton(for owner: PPPetAdOwner) -> some View {
        Button(action: { store.openWhatsApp() }) {
            HStack(spacing: PPSpace.xs) {
                Image(systemName: "message.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text(PPPetAdLocalization.text("WhatsApp", fallback: "WhatsApp"))
                    .font(PPPetAdTypography.footnoteBold)
                    .lineLimit(1)
            }
            .foregroundStyle(Color(red: 0.15, green: 0.78, blue: 0.38))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color(red: 0.15, green: 0.78, blue: 0.38).opacity(0.12))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(Color(red: 0.15, green: 0.78, blue: 0.38).opacity(0.25), lineWidth: 0.75)
            }
        }
        .buttonStyle(PPPetAdPressButtonStyle())
        .accessibilityLabel("\(PPPetAdLocalization.text("WhatsApp", fallback: "WhatsApp")) \(owner.displayName)")
    }

    private func callActionButton(for owner: PPPetAdOwner) -> some View {
        Button(action: { store.callOwner() }) {
            HStack(spacing: PPSpace.xs) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text(PPPetAdLocalization.text("Call", fallback: "Call"))
                    .font(PPPetAdTypography.footnoteBold)
                    .lineLimit(1)
            }
            .foregroundStyle(Color.ppPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.ppPrimary.opacity(0.12))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.ppPrimary.opacity(0.25), lineWidth: 0.75)
            }
        }
        .buttonStyle(PPPetAdPressButtonStyle())
        .accessibilityLabel("\(PPPetAdLocalization.text("Call", fallback: "Call")) \(owner.displayName)")
    }

    // MARK: - Signed out content

    private var signedOutContent: some View {
        VStack(spacing: PPSpace.sm) {
            Text(
                PPPetAdLocalization.text(
                    "contact_gate_subtitle",
                    fallback: "Sign in to see verified contact options and message the advertiser."
                )
            )
            .font(PPPetAdTypography.subheadline)
            .foregroundStyle(Color.ppTextSecondary)
            .multilineTextAlignment(.center)

            Button(action: { store.requireSignInForContact() }) {
                Label(
                    PPPetAdLocalization.text("Login", fallback: "Sign in"),
                    systemImage: "person.crop.circle.badge.checkmark"
                )
                .font(PPPetAdTypography.calloutBold)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(PPGradient.hero)
                .clipShape(Capsule())
            }
            .buttonStyle(PPPetAdPressButtonStyle())
        }
    }

    private var ownAdvertisementContent: some View {
        PPPetAdInlineStateView(
            symbol: "checkmark.seal.fill",
            title: PPPetAdLocalization.text("contact_own_ad", fallback: "This is your advertisement"),
            message: PPPetAdLocalization.text("contact_own_ad_detail", fallback: "You are listed as the advertiser for this pet."),
            actionTitle: PPPetAdLocalization.text("Edit", fallback: "Edit"),
            tint: Color.ppInfo,
            action: { store.close() }
        )
    }

    private var unavailableOwner: some View {
        PPPetAdInlineStateView(
            symbol: "exclamationmark.triangle.fill",
            title: PPPetAdLocalization.text("contact_unavailable_title", fallback: "Contact Information Unavailable"),
            message: PPPetAdLocalization.text("contact_unavailable_message", fallback: "The advertiser's contact details could not be loaded."),
            actionTitle: PPPetAdLocalization.text("Retry", fallback: "Retry"),
            tint: Color.ppWarning,
            action: { store.refresh() }
        )
    }
}
