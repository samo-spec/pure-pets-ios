import Foundation
import SwiftUI

/// Trust surface of the viewer: who is selling, and how to reach them.
///
/// The primary chat action spans full width with 56pt minimum height.
/// All gating resolves into calm, fully designed states.
struct PPPetAdContactCard: View {
    @ObservedObject var store: PPPetAdViewerStore

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            Label {
                Text(
                    PPPetAdLocalization.text(
                        "Contact Advertiser",
                        fallback: "Contact advertiser"
                    )
                )
                .font(PPPetAdTypography.title3)
                .foregroundStyle(Color.ppTextPrimary)
            } icon: {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .foregroundStyle(Color.ppPrimary)
            }
            .accessibilityAddTraits(.isHeader)

            if !store.isSignedIn {
                signedOutContent
            } else if store.isViewingOwnAdvertisement {
                ownAdvertisementContent
            } else {
                ownerContent
            }
        }
        .padding(PPSpace.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ppCard()
    }

    // MARK: - Signed out

    private var signedOutContent: some View {
        VStack(spacing: PPSpace.md) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.ppPrimary)
                .frame(width: 44, height: 44)
                .background(Color.ppPrimary.opacity(0.11), in: Circle())

            Text(
                PPPetAdLocalization.text(
                    "contact_gate_subtitle",
                    fallback:
                        "Sign in to see verified contact options and message the advertiser."
                )
            )
            .font(PPPetAdTypography.subheadline)
            .foregroundStyle(Color.ppTextSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            Button(action: { store.requireSignInForContact() }) {
                Label(
                    PPPetAdLocalization.text(
                        "Login",
                        fallback: "Sign in"
                    ),
                    systemImage: "person.crop.circle.badge.checkmark"
                )
                .font(PPPetAdTypography.calloutBold)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(PPGradient.hero)
                .clipShape(Capsule())
                .shadow(
                    color: Color.ppPrimary.opacity(0.22),
                    radius: 14,
                    y: 8
                )
            }
            .buttonStyle(PPPetAdPressButtonStyle())
        }
        .padding(.top, PPSpace.xs)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Own advertisement

    private var ownAdvertisementContent: some View {
        PPPetAdInlineStateView(
            symbol: "checkmark.seal.fill",
            title: PPPetAdLocalization.text(
                "contact_own_ad",
                fallback: "This is your advertisement"
            ),
            message: PPPetAdLocalization.text(
                "contact_own_ad_detail",
                fallback:
                    "You are listed as the advertiser for this pet. If you want to update the details, edit the advertisement."
            ),
            actionTitle: PPPetAdLocalization.text(
                "Edit",
                fallback: "Edit"
            ),
            tint: Color.ppInfo,
            action: { store.close() }
        )
    }

    // MARK: - Owner content

    private var ownerContent: some View {
        VStack(spacing: PPSpace.md) {
            if let owner = store.owner {
                ownerRow(owner: owner)
                primaryActions(owner: owner)
                secondaryActions(owner: owner)
            } else {
                unavailableOwner
            }
        }
    }

    // MARK: - Owner Row

    private var ownerAvatarSessionState: PPRootSessionState {
        PPRootSessionState(
            isLoggedIn: true,
            displayName: store.owner?.displayName ?? "",
            userImageUrl: store.owner.flatMap {
                URL(string: $0.avatarURL ?? "")
            }
        )
    }

    func ownerRow(owner: PPPetAdOwner) -> some View {
        HStack(spacing: PPSpace.sm) {
            PPRootAvatarView(
                sessionState: ownerAvatarSessionState,
                isSelected: false
            )
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(owner.displayName)
                    .font(PPPetAdTypography.subheadlineBold)
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineLimit(1)

                if owner.isVerified {
                    Label {
                        Text(
                            PPPetAdLocalization.text(
                                "Verified",
                                fallback: "Verified"
                            )
                        )
                    } icon: {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color.ppPrimary)
                    }
                    .font(PPPetAdTypography.caption)
                    .foregroundStyle(Color.ppTextSecondary)
                }
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(owner.displayName), \(PPPetAdLocalization.text("Contact", fallback: "contact"))"
        )
    }

    // MARK: - Primary Action

    func primaryActions(owner: PPPetAdOwner) -> some View {
        VStack(spacing: PPSpace.sm) {
            // Chat button — full width, 56pt min height, primary emphasis
            chatButton(for: owner)

            if store.canCallOwner, owner.phoneNumber?.isEmpty == false {
                HStack(spacing: PPSpace.sm) {
                    callButton(for: owner)
                    if owner.phoneNumber?.isEmpty == false {
                        whatsAppButton(for: owner)
                    }
                }
            }
        }
    }

    func secondaryActions(owner: PPPetAdOwner) -> some View {
        EmptyView()
    }

    // MARK: - Chat Button (Primary CTA)

    func chatButton(for owner: PPPetAdOwner) -> some View {
        Button(action: store.openChat) {
            HStack(spacing: PPSpace.sm) {
                Image(systemName: "message.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text(
                    PPPetAdLocalization.text(
                        "Chat",
                        fallback: "Message"
                    )
                )
                .font(PPPetAdTypography.calloutBold)
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(PPGradient.hero)
            .clipShape(Capsule())
            .shadow(
                color: Color.ppPrimary.opacity(0.22),
                radius: 14,
                y: 8
            )
        }
        .buttonStyle(PPPetAdPressButtonStyle())
        .accessibilityLabel(
            String(
                format: PPPetAdLocalization.text(
                    "a11y_btn_chat_user_format",
                    fallback: "Message %@"
                ),
                owner.displayName
            )
        )
    }

    func callButton(for owner: PPPetAdOwner) -> some View {
        secondaryButton(
            title: PPPetAdLocalization.text("Call", fallback: "Call"),
            symbol: "phone.fill",
            tint: .ppSuccess,
            accessibilityLabel: String(
                format: PPPetAdLocalization.text(
                    "a11y_btn_call_user_format",
                    fallback: "Call %@"
                ),
                owner.displayName
            ),
            action: { store.callOwner() }
        )
    }

    func whatsAppButton(for owner: PPPetAdOwner) -> some View {
        secondaryButton(
            title: PPPetAdLocalization.text(
                "WhatsApp",
                fallback: "WhatsApp"
            ),
            symbol: "bubble.left.and.bubble.right.fill",
            tint: .ppSuccess,
            accessibilityLabel: String(
                format: PPPetAdLocalization.text(
                    "a11y_btn_whatsapp_user_format",
                    fallback: "WhatsApp %@"
                ),
                owner.displayName
            ),
            action: { store.openWhatsApp() }
        )
    }

    func secondaryButton(
        title: String,
        symbol: String,
        tint: Color,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(PPPetAdTypography.subheadlineBold)
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(tint.opacity(0.10))
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: PPCorner.medium,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: PPCorner.medium,
                        style: .continuous
                    )
                    .stroke(tint.opacity(0.14), lineWidth: 0.75)
                }
        }
        .buttonStyle(PPPetAdPressButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }

    var unavailableOwner: some View {
        PPPetAdInlineStateView(
            symbol: "person.crop.circle.badge.questionmark",
            title: PPPetAdLocalization.text(
                "pet_ad_viewer_owner_unavailable",
                fallback: "Contact details are unavailable"
            ),
            message: PPPetAdLocalization.text(
                "pet_ad_viewer_owner_unavailable_detail",
                fallback:
                    "The advertiser profile could not be found for this listing."
            ),
            actionTitle: PPPetAdLocalization.text(
                "Retry",
                fallback: "Retry"
            ),
            tint: .ppWarning,
            action: { store.retryOwner() }
        )
    }
}
