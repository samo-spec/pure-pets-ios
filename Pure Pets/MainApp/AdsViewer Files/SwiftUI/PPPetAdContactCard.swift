import SwiftUI

struct PPPetAdTrustSellerSection: View {
    let model: PPPetAdTrustJourneyModel
    let ownerState: PPPetAdViewerSectionState
    let isSignedIn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HStack(alignment: .center, spacing: PPSpace.md) {
                sellerAvatar

                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: "\u{2068}\(model.sellerDisplayName)\u{2069}")
                        .font(PPPetAdTypography.title3)
                        .foregroundStyle(Color.ppTextPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: PPSpace.xs) {
                        if model.isSellerVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Color.ppSuccess)
                                .accessibilityHidden(true)
                        }

                        Text(sellerRole)
                            .font(PPPetAdTypography.subheadline)
                            .foregroundStyle(Color.ppTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: PPSpace.sm)

                if case .loading = ownerState {
                    ProgressView()
                        .tint(Color.ppPrimary)
                        .accessibilityLabel(
                            PPPetAdLocalization.text(
                                "pet_ad_viewer_owner_loading",
                                fallback: "Loading advertiser details"
                            )
                        )
                }
            }
            .accessibilityElement(children: .combine)

            Text(statusMessage)
                .font(PPPetAdTypography.footnote)
                .foregroundStyle(statusColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var sellerAvatar: some View {
        ZStack(alignment: .bottomTrailing) {
            if let url = model.sellerAvatarURL, !url.isEmpty {
                PPPetAdRemoteImageView(
                    urlString: url,
                    blurHash: nil,
                    contentMode: .fill,
                    accessibilityLabel: model.sellerDisplayName,
                    showsRetryOnFailure: false,
                    displaySize: CGSize(width: 72, height: 72)
                )
                .frame(width: 72, height: 72)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.ppSoftRose)
                    .overlay {
                        Text(String(model.sellerDisplayName.prefix(1)))
                            .font(PPPetAdTypography.title)
                            .foregroundStyle(Color.ppAccentText)
                    }
                    .frame(width: 72, height: 72)
            }

            if model.isSellerVerified {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Color.white)
                    .frame(width: 22, height: 22)
                    .background(Color.ppSuccess, in: Circle())
                    .overlay {
                        Circle().stroke(Color.ppBackground, lineWidth: 2)
                    }
                    .accessibilityHidden(true)
            }
        }
        .accessibilityHidden(true)
    }

    private var sellerRole: String {
        if model.isSellerVerified {
            return PPPetAdLocalization.text(
                "pet_ad_viewer_verified_seller_role",
                fallback: "Verified advertiser"
            )
        }
        return PPPetAdLocalization.text(
            "pet_ad_viewer_seller_role",
            fallback: "Advertiser"
        )
    }

    private var statusMessage: String {
        guard isSignedIn else {
            return PPPetAdLocalization.text(
                "pet_ad_trust_sign_in_for_contact",
                fallback:
                    "Sign in before contacting the advertiser or sharing personal details."
            )
        }

        switch ownerState {
        case .idle, .loading, .loaded:
            return PPPetAdLocalization.text(
                "pet_ad_trust_seller_safety",
                fallback:
                    "Keep agreements and important details inside Pure Pets chat."
            )
        case .empty:
            return PPPetAdLocalization.text(
                "pet_ad_viewer_owner_unavailable_detail",
                fallback:
                    "The advertiser profile could not be found for this listing."
            )
        case let .offline(message), let .failed(message):
            return message
        }
    }

    private var statusColor: Color {
        switch ownerState {
        case .offline:
            return .ppWarning
        case .failed, .empty:
            return .ppError
        case .idle, .loading, .loaded:
            return .ppTextSecondary
        }
    }
}

@available(iOS 16.0, *)
struct PPPetAdContactDock: View {
    @ObservedObject var store: PPPetAdViewerStore

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        dockContent
            .id(stateIdentity)
            .transition(
                reduceMotion
                    ? .opacity
                    : .opacity.combined(with: .move(edge: .bottom))
            )
            .animation(reduceMotion ? nil : PPPetAdViewerMotion.state, value: stateIdentity)
            .padding(PPSpace.md)
            .background(contactSurface)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var dockContent: some View {
        if !store.isSignedIn {
            primaryButton(
                title: PPPetAdLocalization.text(
                    "pet_ad_trust_sign_in_action",
                    fallback: "Sign in to contact the advertiser"
                ),
                symbol: "person.crop.circle.badge.checkmark",
                isLoading: store.contactSignInState == .working,
                isSuccess: isSignInSucceeded,
                action: store.requireSignInForContact
            )
        } else {
            switch store.ownerState {
            case .idle, .loading:
                loadingDock
            case .loaded:
                if store.canMessageOwner || store.canCallOwner {
                    availableActions
                } else {
                    recoveryDock(
                        title: PPPetAdLocalization.text(
                            "pet_ad_viewer_no_contact_channels",
                            fallback:
                                "This advertiser has no contact channel available right now."
                        ),
                        symbol: "person.crop.circle.badge.questionmark",
                        retry: store.retryOwner
                    )
                }
            case .empty:
                recoveryDock(
                    title: PPPetAdLocalization.text(
                        "pet_ad_viewer_owner_unavailable",
                        fallback: "Contact details are unavailable"
                    ),
                    symbol: "person.crop.circle.badge.questionmark",
                    retry: store.retryOwner
                )
            case let .offline(message), let .failed(message):
                recoveryDock(
                    title: message,
                    symbol:
                        store.ownerState.isOffline
                        ? "wifi.slash"
                        : "exclamationmark.triangle.fill",
                    retry: store.retryOwner
                )
            }
        }
    }

    @ViewBuilder
    private var availableActions: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: PPSpace.sm) {
                primaryContactAction
                utilityActions
            }
        } else {
            HStack(spacing: PPSpace.sm) {
                primaryContactAction
                utilityActions
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    @ViewBuilder
    private var primaryContactAction: some View {
        if store.canMessageOwner {
            primaryButton(
                title: chatTitle,
                symbol: chatSymbol,
                isLoading: store.chatState == .working,
                isSuccess: isChatSucceeded,
                action: store.openChat
            )
            .accessibilityLabel(
                PPPetAdLocalization.text(
                    "a11y_btn_chat_advertiser",
                    fallback: "Chat with advertiser"
                )
            )
            .accessibilityValue(chatTitle)
            .accessibilityHint(
                PPPetAdLocalization.text(
                    "a11y_btn_chat_advertiser_hint",
                    fallback:
                        "Double-tap to start a chat with this person"
                )
            )
        } else if store.canCallOwner {
            primaryButton(
                title: PPPetAdLocalization.text(
                    "Call",
                    fallback: "Call"
                ),
                symbol: "phone.fill",
                isLoading: false,
                isSuccess: false,
                action: store.callOwner
            )
            .accessibilityLabel(
                PPPetAdLocalization.text(
                    "a11y_btn_call_advertiser",
                    fallback: "Call advertiser"
                )
            )
        }
    }

    @ViewBuilder
    private var utilityActions: some View {
        HStack(spacing: PPSpace.sm) {
            if store.canCallOwner && store.canMessageOwner {
                utilityButton(
                    symbol: "phone.fill",
                    accessibilityLabel: PPPetAdLocalization.text(
                        "a11y_btn_call_advertiser",
                        fallback: "Call advertiser"
                    ),
                    action: store.callOwner
                )
            }

            if store.canCallOwner {
                utilityButton(
                    symbol: "ellipsis.message.fill",
                    accessibilityLabel: PPPetAdLocalization.text(
                        "a11y_btn_whatsapp_advertiser",
                        fallback: "WhatsApp advertiser"
                    ),
                    action: store.openWhatsApp
                )
            }
        }
    }

    private func primaryButton(
        title: String,
        symbol: String,
        isLoading: Bool,
        isSuccess: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: PPSpace.sm) {
                Group {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Color.white)
                    } else {
                        Image(
                            systemName:
                                isSuccess ? "checkmark" : symbol
                        )
                        .font(.system(size: 17, weight: .bold))
                    }
                }
                .frame(width: 23, height: 23)
                .accessibilityHidden(true)

                Text(title)
                    .font(PPPetAdTypography.calloutBold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, PPSpace.base)
            .frame(maxWidth: .infinity)
            .frame(
                minHeight:
                    dynamicTypeSize.isAccessibilitySize ? 64 : 58
            )
            .background(
                Color.ppPrimary,
                in: RoundedRectangle(
                    cornerRadius: PPCorner.medium,
                    style: .continuous
                )
            )
            .contentShape(
                RoundedRectangle(
                    cornerRadius: PPCorner.medium,
                    style: .continuous
                )
            )
        }
        .buttonStyle(PPBottomDecisionPressStyle())
        .disabled(isLoading)
        .accessibilityValue(
            isLoading
                ? PPPetAdLocalization.text(
                    "Loading",
                    fallback: "Loading"
                )
                : ""
        )
    }

    private func utilityButton(
        symbol: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.ppAccentText)
                .frame(width: 58, height: 58)
                .background(
                    Color.ppSoftRose.opacity(
                        colorScheme == .dark ? 0.42 : 0.72
                    ),
                    in: RoundedRectangle(
                        cornerRadius: PPCorner.medium,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: PPCorner.medium,
                        style: .continuous
                    )
                    .stroke(
                        Color.ppPrimary.opacity(
                            colorSchemeContrast == .increased ? 0.76 : 0.22
                        ),
                        lineWidth:
                            colorSchemeContrast == .increased ? 1.5 : 1
                    )
                }
                .contentShape(
                    RoundedRectangle(
                        cornerRadius: PPCorner.medium,
                        style: .continuous
                    )
                )
        }
        .buttonStyle(PPBottomDecisionPressStyle())
        .accessibilityLabel(accessibilityLabel)
    }

    private func recoveryDock(
        title: String,
        symbol: String,
        retry: @escaping () -> Void
    ) -> some View {
        HStack(spacing: PPSpace.md) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.ppWarning)
                .frame(width: 44, height: 44)
                .background(Color.ppWarning.opacity(0.10), in: Circle())
                .accessibilityHidden(true)

            Text(title)
                .font(PPPetAdTypography.subheadline)
                .foregroundStyle(Color.ppTextSecondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: retry) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 48, height: 48)
                    .background(Color.ppPrimary, in: Circle())
            }
            .buttonStyle(PPBottomDecisionPressStyle())
            .accessibilityLabel(
                PPPetAdLocalization.text("Retry", fallback: "Retry")
            )
        }
    }

    private var loadingDock: some View {
        HStack(spacing: PPSpace.sm) {
            RoundedRectangle(cornerRadius: PPCorner.medium)
                .fill(Color.ppTextTertiary.opacity(0.12))
                .frame(maxWidth: .infinity)
                .frame(height: 58)

            RoundedRectangle(cornerRadius: PPCorner.medium)
                .fill(Color.ppTextTertiary.opacity(0.10))
                .frame(width: 58, height: 58)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            PPPetAdLocalization.text(
                "pet_ad_viewer_owner_loading",
                fallback: "Loading advertiser details"
            )
        )
    }

    private var contactSurface: some View {
        let shape = RoundedRectangle(
            cornerRadius: PPCorner.medium,
            style: .continuous
        )
        return shape
            .fill(Color.ppElevatedSurface)
            .overlay {
                shape.stroke(
                    Color.ppBorder.opacity(
                        colorSchemeContrast == .increased ? 0.94 : 0.54
                    ),
                    lineWidth:
                        colorSchemeContrast == .increased ? 1.5 : 0.75
                )
            }
            .shadow(
                color: Color.black.opacity(
                    colorScheme == .dark ? 0.24 : 0.09
                ),
                radius: 24,
                x: 0,
                y: 12
            )
    }

    private var chatTitle: String {
        switch store.chatState {
        case .working:
            return PPPetAdLocalization.text(
                "pet_ad_viewer_chat_opening",
                fallback: "Opening chat"
            )
        case .succeeded:
            return PPPetAdLocalization.text(
                "pet_ad_viewer_chat_ready",
                fallback: "Chat ready"
            )
        case .failed:
            return PPPetAdLocalization.text(
                "pet_ad_viewer_chat_retry",
                fallback: "Try chat again"
            )
        case .idle:
            return PPPetAdLocalization.text(
                "pet_ad_trust_ask_seller",
                fallback: "Ask about this pet"
            )
        }
    }

    private var chatSymbol: String {
        if case .failed = store.chatState {
            return "arrow.clockwise"
        }
        return "message.fill"
    }

    private var isChatSucceeded: Bool {
        if case .succeeded = store.chatState { return true }
        return false
    }

    private var isSignInSucceeded: Bool {
        if case .succeeded = store.contactSignInState { return true }
        return false
    }

    private var stateIdentity: Int {
        if !store.isSignedIn { return 0 }
        switch store.ownerState {
        case .idle: return 1
        case .loading: return 2
        case .loaded:
            if store.canMessageOwner { return 3 }
            return store.canCallOwner ? 4 : 8
        case .empty: return 5
        case .offline: return 6
        case .failed: return 7
        }
    }
}

extension PPPetAdViewerStore {
    var ppShowsContactDock: Bool {
        guard case .content = screenState else { return false }
        return !isViewingOwnAdvertisement
    }
}

private extension PPPetAdViewerSectionState {
    var isOffline: Bool {
        if case .offline = self { return true }
        return false
    }
}
