import Foundation
import SwiftUI

/// Trust surface of the viewer: who is selling, and how to reach them.
///
/// Exactly one action is ever the visual primary — chat when available,
/// otherwise the phone call — so the next step is never ambiguous.
/// All gating (signed-out, own listing, offline, unavailable) resolves
/// into calm, fully designed states rather than hidden buttons.
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

    // MARK: - Signed out

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
                    PPPetAdLocalization.text(
                        "Login",
                        fallback: "Sign in"
                    ),
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

    // MARK: - Own advertisement

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
}

// MARK: - Owner states

private extension PPPetAdContactCard {
    @ViewBuilder
    var ownerContent: some View {
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

    var loadingOwner: some View {
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

    func loadedOwner(_ owner: PPPetAdOwner) -> some View {
        VStack(spacing: PPSpace.base) {
            ownerRow(owner)
            contactActions(for: owner)
        }
    }

    func ownerRow(_ owner: PPPetAdOwner) -> some View {
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
    }
}


// MARK: - Contact actions

private extension PPPetAdContactCard {
    /// One dominant action, everything else secondary.
    @ViewBuilder
    func contactActions(for owner: PPPetAdOwner) -> some View {
        if store.canMessageOwner {
            VStack(spacing: PPSpace.sm) {
                primaryChatButton

                if store.canCallOwner {
                    secondaryRow(for: owner)
                }
            }
        } else if store.canCallOwner {
            VStack(spacing: PPSpace.sm) {
                primaryCallButton(for: owner)
                whatsAppButton(for: owner)
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

    var primaryChatButton: some View {
        Button(action: store.openChat) {
            ZStack {
                if store.chatState == .working {
                    ProgressView()
                        .tint(.white)
                } else {
                    Label(
                        PPPetAdLocalization.text(
                            "Chat",
                            fallback: "Chat"
                        ),
                        systemImage: "message.fill"
                    )
                }
            }
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
        .disabled(store.chatState == .working)
        .accessibilityLabel(ownerChatAccessibilityLabel)
        .accessibilityValue(
            store.chatState == .working
                ? PPPetAdLocalization.text(
                    "Loading",
                    fallback: "Loading"
                )
                : ""
        )
    }

    var ownerChatAccessibilityLabel: String {
        String(
            format: PPPetAdLocalization.text(
                "a11y_btn_chat_user_format",
                fallback: "Chat with %@"
            ),
            store.owner?.displayName ?? ""
        )
    }

    func secondaryRow(for owner: PPPetAdOwner) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: PPSpace.sm) {
                    callButton(for: owner)
                    whatsAppButton(for: owner)
                }
            } else {
                HStack(spacing: PPSpace.sm) {
                    callButton(for: owner)
                    whatsAppButton(for: owner)
                }
            }
        }
    }
}


// MARK: - Buttons

private extension PPPetAdContactCard {
    func primaryCallButton(
        for owner: PPPetAdOwner
    ) -> some View {
        Button(action: store.callOwner) {
            Label(
                PPPetAdLocalization.text("Call", fallback: "Call"),
                systemImage: "phone.fill"
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
        .accessibilityLabel(
            String(
                format: PPPetAdLocalization.text(
                    "a11y_btn_call_user_format",
                    fallback: "Call %@"
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
            action: store.callOwner
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
            action: store.openWhatsApp
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
            action: store.retryOwner
        )
    }
}

