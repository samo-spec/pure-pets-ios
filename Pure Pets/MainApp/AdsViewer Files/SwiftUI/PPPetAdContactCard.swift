import Foundation
import SwiftUI

struct PPPetAdContactCard: View {
    @ObservedObject var store: PPPetAdViewerStore

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.base) {
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
        .padding(PPSpace.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ppCard()
    }

    private var signedOutContent: some View {
        VStack(spacing: PPSpace.base) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color.ppPrimary)
                .frame(width: 54, height: 54)
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

            Button(action: store.requireSignInForContact) {
                Label(
                    PPPetAdLocalization.text("Login", fallback: "Sign in"),
                    systemImage: "person.crop.circle.badge.checkmark"
                )
                .font(PPPetAdTypography.calloutBold)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity, minHeight: 52)
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

    private var ownAdvertisementContent: some View {
        PPPetAdInlineStateView(
            symbol: "checkmark.seal.fill",
            title: PPPetAdLocalization.text(
                "pet_ad_viewer_your_listing",
                fallback: "This is your advertisement"
            ),
            message: PPPetAdLocalization.text(
                "pet_ad_viewer_your_listing_detail",
                fallback:
                    "Contact actions are hidden when you view your own listing."
            ),
            actionTitle: nil,
            tint: .ppSuccess,
            action: nil
        )
    }

    @ViewBuilder
    private var ownerContent: some View {
        switch store.ownerState {
        case .idle, .loading:
            loadingOwner
        case .loaded:
            if let owner = store.owner {
                loadedOwner(owner)
            } else {
                unavailableOwner
            }
        case .empty:
            unavailableOwner
        case let .offline(message):
            PPPetAdInlineStateView(
                symbol: "wifi.slash",
                title: PPPetAdLocalization.text(
                    "pet_ad_viewer_owner_offline",
                    fallback: "Contact details are offline"
                ),
                message: message,
                actionTitle: PPPetAdLocalization.text(
                    "Retry",
                    fallback: "Retry"
                ),
                tint: .ppWarning,
                action: store.retryOwner
            )
        case let .failed(message):
            PPPetAdInlineStateView(
                symbol: "person.crop.circle.badge.exclamationmark",
                title: PPPetAdLocalization.text(
                    "pet_ad_viewer_owner_unavailable",
                    fallback: "Contact details are unavailable"
                ),
                message: message,
                actionTitle: PPPetAdLocalization.text(
                    "Retry",
                    fallback: "Retry"
                ),
                tint: .ppError,
                action: store.retryOwner
            )
        }
    }

    private var loadingOwner: some View {
        HStack(spacing: PPSpace.md) {
            ProgressView()
                .tint(Color.ppPrimary)
                .frame(width: 52, height: 52)
                .background(
                    Color.ppPrimary.opacity(0.08),
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: PPSpace.sm) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.ppTextTertiary.opacity(0.16))
                    .frame(width: 150, height: 15)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.ppTextTertiary.opacity(0.11))
                    .frame(width: 105, height: 12)
            }

            Spacer()
        }
        .padding(.vertical, PPSpace.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            PPPetAdLocalization.text(
                "pet_ad_viewer_owner_loading",
                fallback: "Loading advertiser details"
            )
        )
    }

    private func loadedOwner(_ owner: PPPetAdOwner) -> some View {
        VStack(spacing: PPSpace.base) {
            HStack(spacing: PPSpace.md) {
                PPPetAdRemoteImageView(
                    urlString: owner.avatarURL,
                    blurHash: nil,
                    contentMode: .fill,
                    accessibilityLabel: owner.displayName
                )
                .frame(width: 58, height: 58)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(
                            Color.ppPrimary.opacity(0.16),
                            lineWidth: 1
                        )
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: PPSpace.xs) {
                    HStack(spacing: PPSpace.xs) {
                        Text(owner.displayName)
                            .font(PPPetAdTypography.headline)
                            .foregroundStyle(Color.ppTextPrimary)
                            .lineLimit(2)

                        if owner.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Color.ppInfo)
                                .accessibilityLabel(
                                    PPPetAdLocalization.text(
                                        "Verified",
                                        fallback: "Verified"
                                    )
                                )
                        }
                    }

                    Text(
                        owner.isVerified
                            ? PPPetAdLocalization.text(
                                "pet_ad_viewer_verified_owner",
                                fallback: "Verified Pure Pets member"
                            )
                            : PPPetAdLocalization.text(
                                "pet_ad_viewer_owner",
                                fallback: "Pure Pets member"
                            )
                    )
                    .font(PPPetAdTypography.footnote)
                    .foregroundStyle(Color.ppTextSecondary)
                }

                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)

            contactActions(for: owner)
        }
    }

    @ViewBuilder
    private func contactActions(
        for owner: PPPetAdOwner
    ) -> some View {
        if store.canCallOwner || store.canMessageOwner {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: PPSpace.sm) {
                    contactButtons(for: owner)
                }
            } else {
                HStack(spacing: PPSpace.sm) {
                    contactButtons(for: owner)
                }
            }
        } else {
            Text(
                PPPetAdLocalization.text(
                    "pet_ad_viewer_no_contact_channels",
                    fallback:
                        "This advertiser has no contact channel available right now."
                )
            )
            .font(PPPetAdTypography.subheadline)
            .foregroundStyle(Color.ppTextSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func contactButtons(
        for owner: PPPetAdOwner
    ) -> some View {
        if store.canMessageOwner {
            contactButton(
                title: PPPetAdLocalization.text("Chat", fallback: "Chat"),
                symbol: "message.fill",
                tint: .ppPrimary,
                accessibilityLabel: String(
                    format: PPPetAdLocalization.text(
                        "a11y_btn_chat_user_format",
                        fallback: "Chat with %@"
                    ),
                    owner.displayName
                ),
                isEnabled: store.chatState != .working,
                isLoading: store.chatState == .working,
                action: store.openChat
            )
        }

        if store.canCallOwner {
            contactButton(
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
                action: store.callOwner
            )

            contactButton(
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
                action: store.openWhatsApp
            )
        }
    }

    private func contactButton(
        title: String,
        symbol: String,
        tint: Color,
        accessibilityLabel: String,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(tint)
                } else {
                    Label(title, systemImage: symbol)
                }
            }
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
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.58)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(
            isLoading
                ? PPPetAdLocalization.text(
                    "Loading",
                    fallback: "Loading"
                )
                : ""
        )
    }

    private var unavailableOwner: some View {
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
            action: store.retryOwner
        )
    }
}
