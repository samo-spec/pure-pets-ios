import Foundation
import SwiftUI

struct PPPetAdContactCard: View {
    @ObservedObject var store: PPPetAdViewerStore
    let showsActions: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        store: PPPetAdViewerStore,
        showsActions: Bool = true
    ) {
        self.store = store
        self.showsActions = showsActions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.base) {
            PPPetAdDetailSectionHeading(
                title: PPPetAdLocalization.text(
                    "Contact Advertiser",
                    fallback: "Contact advertiser"
                )
            )

            Group {
                if !store.isSignedIn {
                    signedOutContent
                } else if store.isViewingOwnAdvertisement {
                    ownAdvertisementContent
                } else {
                    ownerContent
                }
            }
            .id(contactStateIdentity)
            .transition(
                reduceMotion
                    ? .opacity
                    : .opacity.combined(with: .scale(scale: 0.994))
            )
        }
        .padding(.top, PPSpace.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(uiColor: .separator).opacity(0.24))
                .frame(height: 1)
                .accessibilityHidden(true)
        }
        .animation(
            reduceMotion ? nil : PPPetAdViewerMotion.state,
            value: contactStateIdentity
        )
    }

    private var signedOutContent: some View {
        VStack(alignment: .leading, spacing: PPSpace.lg) {
            HStack(alignment: .top, spacing: PPSpace.md) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.ppPrimary)
                    .frame(width: 42, height: 42)
                    .background(
                        Color.ppPrimary.opacity(0.09),
                        in: RoundedRectangle(
                            cornerRadius: 14,
                            style: .continuous
                        )
                    )
                    .accessibilityHidden(true)

                Text(
                    PPPetAdLocalization.text(
                        "contact_gate_subtitle",
                        fallback:
                            "Sign in to see verified contact options and message the advertiser."
                    )
                )
                .font(PPPetAdTypography.subheadline)
                .foregroundStyle(Color.ppTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, PPSpace.xs)
            }

            if showsActions {
                contactButton(
                    title: PPPetAdLocalization.text(
                        "Login",
                        fallback: "Sign in"
                    ),
                    symbol: "person.crop.circle.badge.checkmark",
                    tint: .ppPrimary,
                    accessibilityLabel: PPPetAdLocalization.text(
                        "Login",
                        fallback: "Sign in"
                    ),
                    emphasis: .primary,
                    action: store.requireSignInForContact
                )
            }
        }
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
        VStack(spacing: PPSpace.lg) {
            HStack(spacing: PPSpace.md) {
                Circle()
                    .fill(Color.ppTextTertiary.opacity(0.10))
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: PPSpace.sm) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.ppTextTertiary.opacity(0.15))
                        .frame(maxWidth: 164)
                        .frame(height: 16)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.ppTextTertiary.opacity(0.09))
                        .frame(maxWidth: 116)
                        .frame(height: 12)
                }

                Spacer(minLength: 0)
            }

            if showsActions {
                RoundedRectangle(
                    cornerRadius: PPPetAdViewerStyle.insetRadius,
                    style: .continuous
                )
                .fill(Color.ppTextTertiary.opacity(0.09))
                .frame(height: 52)

                HStack(spacing: PPSpace.sm) {
                    loadingActionPlaceholder
                    loadingActionPlaceholder
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            PPPetAdLocalization.text(
                "pet_ad_viewer_owner_loading",
                fallback: "Loading advertiser details"
            )
        )
    }

    private var loadingActionPlaceholder: some View {
        RoundedRectangle(
            cornerRadius: PPPetAdViewerStyle.insetRadius,
            style: .continuous
        )
        .fill(Color.ppTextTertiary.opacity(0.065))
        .frame(maxWidth: .infinity)
        .frame(height: 48)
    }

    private func loadedOwner(_ owner: PPPetAdOwner) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.lg) {
            HStack(spacing: PPSpace.md) {
                PPPetAdRemoteImageView(
                    urlString: owner.avatarURL,
                    blurHash: nil,
                    contentMode: .fill,
                    accessibilityLabel: owner.displayName
                )
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .strokeBorder(
                            Color(uiColor: .separator).opacity(0.24),
                            lineWidth: PPPetAdViewerStyle.hairlineWidth
                        )
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(owner.displayName)
                        .font(PPPetAdTypography.headline)
                        .foregroundStyle(Color.ppTextPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: PPSpace.xs) {
                        if owner.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.ppInfo)
                                .accessibilityHidden(true)
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
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)

            if showsActions {
                contactActions(for: owner)
            } else if !store.canMessageOwner && !store.canCallOwner {
                noContactChannelsMessage
            }
        }
    }

    @ViewBuilder
    private func contactActions(
        for owner: PPPetAdOwner
    ) -> some View {
        if store.canMessageOwner {
            VStack(spacing: PPSpace.sm) {
                contactButton(
                    title: PPPetAdLocalization.text(
                        "Chat",
                        fallback: "Chat"
                    ),
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
                    emphasis: .primary,
                    action: store.openChat
                )

                if store.canCallOwner {
                    secondaryCallActions(for: owner)
                }
            }
        } else if store.canCallOwner {
            VStack(spacing: PPSpace.sm) {
                contactButton(
                    title: PPPetAdLocalization.text(
                        "Call",
                        fallback: "Call"
                    ),
                    symbol: "phone.fill",
                    tint: .ppPrimary,
                    accessibilityLabel: String(
                        format: PPPetAdLocalization.text(
                            "a11y_btn_call_user_format",
                            fallback: "Call %@"
                        ),
                        owner.displayName
                    ),
                    emphasis: .primary,
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
                    emphasis: .secondary,
                    action: store.openWhatsApp
                )
            }
        } else {
            noContactChannelsMessage
        }
    }

    private var noContactChannelsMessage: some View {
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
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func secondaryCallActions(
        for owner: PPPetAdOwner
    ) -> some View {
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

    private func callButton(
        for owner: PPPetAdOwner
    ) -> some View {
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
            emphasis: .secondary,
            action: store.callOwner
        )
    }

    private func whatsAppButton(
        for owner: PPPetAdOwner
    ) -> some View {
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
            emphasis: .secondary,
            action: store.openWhatsApp
        )
    }

    private func contactButton(
        title: String,
        symbol: String,
        tint: Color,
        accessibilityLabel: String,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        emphasis: PPPetAdContactButtonEmphasis,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: PPSpace.sm) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .accessibilityHidden(true)

                Text(title)
                    .font(PPPetAdTypography.calloutBold)
                    .fixedSize(horizontal: false, vertical: true)

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(
                            emphasis == .primary
                                ? Color.white
                                : tint
                        )
                        .transition(.opacity.combined(with: .scale))
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(
                emphasis == .primary
                    ? Color.white
                    : tint
            )
            .frame(
                maxWidth: .infinity,
                minHeight: emphasis == .primary ? 52 : 48
            )
            .padding(.horizontal, PPSpace.md)
            .background {
                contactButtonBackground(
                    tint: tint,
                    emphasis: emphasis
                )
            }
            .contentShape(
                RoundedRectangle(
                    cornerRadius: PPPetAdViewerStyle.insetRadius,
                    style: .continuous
                )
            )
        }
        .buttonStyle(
            PPPetAdPressButtonStyle(
                pressedScale: emphasis == .primary ? 0.982 : 0.97
            )
        )
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.58)
        .animation(
            reduceMotion ? nil : PPPetAdViewerMotion.state,
            value: isLoading
        )
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

    @ViewBuilder
    private func contactButtonBackground(
        tint: Color,
        emphasis: PPPetAdContactButtonEmphasis
    ) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: PPPetAdViewerStyle.insetRadius,
            style: .continuous
        )

        if emphasis == .primary {
            shape
                .fill(tint)
                .shadow(
                    color: tint.opacity(0.17),
                    radius: 12,
                    y: 5
                )
        } else {
            shape
                .fill(tint.opacity(0.075))
                .overlay {
                    shape.strokeBorder(
                        tint.opacity(0.18),
                        lineWidth: PPPetAdViewerStyle.hairlineWidth
                    )
                }
        }
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

    private var contactStateIdentity: Int {
        if !store.isSignedIn {
            return 0
        }
        if store.isViewingOwnAdvertisement {
            return 1
        }
        switch store.ownerState {
        case .idle:
            return 2
        case .loading:
            return 3
        case .loaded:
            return 4
        case .empty:
            return 5
        case .offline:
            return 6
        case .failed:
            return 7
        }
    }
}

private enum PPPetAdContactButtonEmphasis {
    case primary
    case secondary
}

@available(iOS 16.0, *)
struct PPPetAdContactDock: View {
    @ObservedObject var store: PPPetAdViewerStore

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        dockContent
            .id(stateIdentity)
            .transition(
                reduceMotion
                    ? .opacity
                    : .opacity.combined(with: .scale(scale: 0.99))
            )
            .animation(
                reduceMotion ? nil : PPPetAdViewerMotion.state,
                value: stateIdentity
            )
            .padding(PPBottomDecisionBarGeometry.contentPadding)
            .ppBottomDecisionBarSurface()
            .fixedSize(horizontal: false, vertical: true)
            .transaction { transaction in
                if reduceMotion {
                    transaction.disablesAnimations = true
                    transaction.animation = nil
                }
            }
    }

    @ViewBuilder
    private var dockContent: some View {
        if !store.isSignedIn {
            primaryButton(
                title: PPPetAdLocalization.text(
                    "Login",
                    fallback: "Sign in"
                ),
                symbol: "person.crop.circle.badge.checkmark",
                accessibilityLabel: PPPetAdLocalization.text(
                    "Login",
                    fallback: "Sign in"
                ),
                isLoading: false,
                isSuccess: false,
                action: store.requireSignInForContact
            )
        } else {
            switch store.ownerState {
            case .idle, .loading:
                loadingDock
            case .loaded:
                if let owner = store.owner {
                    if store.canMessageOwner || store.canCallOwner {
                        actionRow(for: owner)
                    } else {
                        recoveryDock(
                            symbol: "phone.down.fill",
                            title: PPPetAdLocalization.text(
                                "pet_ad_viewer_owner_unavailable",
                                fallback: "Contact details are unavailable"
                            ),
                            message: owner.displayName,
                            tint: .ppWarning,
                            retry: store.retryOwner
                        )
                    }
                } else {
                    unavailableDock
                }
            case .empty:
                unavailableDock
            case let .offline(message):
                recoveryDock(
                    symbol: "wifi.slash",
                    title: PPPetAdLocalization.text(
                        "pet_ad_viewer_owner_offline",
                        fallback: "Contact details are offline"
                    ),
                    message: message,
                    tint: .ppWarning,
                    retry: store.retryOwner
                )
            case let .failed(message):
                recoveryDock(
                    symbol: "person.crop.circle.badge.exclamationmark",
                    title: PPPetAdLocalization.text(
                        "pet_ad_viewer_owner_unavailable",
                        fallback: "Contact details are unavailable"
                    ),
                    message: message,
                    tint: .ppError,
                    retry: store.retryOwner
                )
            }
        }
    }

    @ViewBuilder
    private func actionRow(for owner: PPPetAdOwner) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            verticalActionRow(for: owner)
        } else {
            ViewThatFits(in: .horizontal) {
                horizontalActionRow(for: owner)
                verticalActionRow(for: owner)
            }
        }
    }

    private func horizontalActionRow(
        for owner: PPPetAdOwner
    ) -> some View {
        HStack(spacing: PPSpace.sm) {
            PPPetAdOwnerProfilePill(owner: owner)
                .layoutPriority(1)

            if store.canMessageOwner {
                if store.canCallOwner {
                    callIconButton(for: owner)
                }

                chatPrimaryButton(for: owner)
                    .frame(minWidth: 132, maxWidth: 164)
            } else if store.canCallOwner {
                callPrimaryButton(for: owner)
                    .frame(minWidth: 116, maxWidth: 150)
            }
        }
    }

    private func verticalActionRow(
        for owner: PPPetAdOwner
    ) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            PPPetAdOwnerProfilePill(owner: owner)

            HStack(spacing: PPSpace.sm) {
                if store.canCallOwner {
                    callIconButton(for: owner)
                }

                if store.canMessageOwner {
                    chatPrimaryButton(for: owner)
                } else if store.canCallOwner {
                    callPrimaryButton(for: owner)
                }
            }
        }
    }

    private func chatPrimaryButton(
        for owner: PPPetAdOwner
    ) -> some View {
        primaryButton(
            title: interestTitle,
            symbol: "message.fill",
            accessibilityLabel: chatAccessibilityLabel(for: owner),
            isLoading: isChatWorking,
            isSuccess: isChatSucceeded,
            action: store.openChat
        )
        .accessibilityHint(
            PPPetAdLocalization.text(
                "a11y_btn_chat_advertiser_hint",
                fallback: "Double-tap to start a chat with this person"
            )
        )
    }

    private func callPrimaryButton(
        for owner: PPPetAdOwner
    ) -> some View {
        primaryButton(
            title: PPPetAdLocalization.text("Call", fallback: "Call"),
            symbol: "phone.fill",
            accessibilityLabel: String(
                format: PPPetAdLocalization.text(
                    "a11y_btn_call_user_format",
                    fallback: "Call %@"
                ),
                owner.displayName
            ),
            isLoading: false,
            isSuccess: false,
            action: store.callOwner
        )
        .accessibilityHint(
            PPPetAdLocalization.text(
                "a11y_btn_call_advertiser_hint",
                fallback: "Double-tap to call this person"
            )
        )
    }

    private func callIconButton(
        for owner: PPPetAdOwner
    ) -> some View {
        Button(action: store.callOwner) {
            Image(systemName: "phone.fill")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(PPPetAdViewerStyle.darkActionForeground)
                .frame(
                    width: PPBottomDecisionBarGeometry.utilityControlSize,
                    height: PPBottomDecisionBarGeometry.utilityControlSize
                )
                .background(
                    PPPetAdViewerStyle.darkActionFill,
                    in: RoundedRectangle(
                        cornerRadius:
                            PPBottomDecisionBarGeometry.controlRadius,
                        style: .continuous
                    )
                )
                .contentShape(
                    RoundedRectangle(
                        cornerRadius:
                            PPBottomDecisionBarGeometry.controlRadius,
                        style: .continuous
                    )
                )
        }
        .buttonStyle(PPBottomDecisionPressStyle(pressedScale: 0.94))
        .accessibilityLabel(
            String(
                format: PPPetAdLocalization.text(
                    "a11y_btn_call_user_format",
                    fallback: "Call %@"
                ),
                owner.displayName
            )
        )
        .accessibilityHint(
            PPPetAdLocalization.text(
                "a11y_btn_call_advertiser_hint",
                fallback: "Double-tap to call this person"
            )
        )
    }




    private func primaryButton(
        title: String,
        symbol: String,
        accessibilityLabel: String,
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
                            .tint(PPPetAdViewerStyle.actionForeground)
                    } else {
                        Image(
                            systemName:
                                isSuccess
                                ? "checkmark"
                                : symbol
                        )
                        .font(.system(size: 17, weight: .bold))
                    }
                }
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)

                Text(title)
                    .font(PPPetAdTypography.calloutBold)
                    .foregroundStyle(
                        PPPetAdViewerStyle.actionForeground
                    )
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, PPSpace.base)
            .frame(maxWidth: .infinity)
            .frame(minHeight: primaryButtonHeight)
            .background(
                PPPetAdViewerStyle.actionAccent,
                in: RoundedRectangle(
                    cornerRadius:
                        PPBottomDecisionBarGeometry.controlRadius,
                    style: .continuous
                )
            )
            .contentShape(
                RoundedRectangle(
                    cornerRadius:
                        PPBottomDecisionBarGeometry.controlRadius,
                    style: .continuous
                )
            )
        }
        .buttonStyle(PPBottomDecisionPressStyle())
        .disabled(isLoading)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(
            isLoading
                ? PPPetAdLocalization.text(
                    "Loading",
                    fallback: "Loading"
                )
                : (
                    isSuccess
                    ? PPPetAdLocalization.text(
                        "Success",
                        fallback: "Completed"
                    )
                    : ""
                )
        )
    }

    private var unavailableDock: some View {
        recoveryDock(
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
            tint: .ppWarning,
            retry: store.retryOwner
        )
    }

    private func recoveryDock(
        symbol: String,
        title: String,
        message: String,
        tint: Color,
        retry: @escaping () -> Void
    ) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: PPSpace.md) {
                    recoveryLabel(
                        symbol: symbol,
                        title: title,
                        message: message,
                        tint: tint
                    )
                    retryButton(action: retry)
                }
            } else {
                HStack(spacing: PPSpace.md) {
                    recoveryLabel(
                        symbol: symbol,
                        title: title,
                        message: message,
                        tint: tint
                    )
                    retryButton(action: retry)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
    }

    private func recoveryLabel(
        symbol: String,
        title: String,
        message: String,
        tint: Color
    ) -> some View {
        HStack(spacing: PPSpace.sm) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(
                    tint.opacity(0.10),
                    in: RoundedRectangle(
                        cornerRadius: PPCorner.small,
                        style: .continuous
                    )
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: PPSpace.xs) {
                Text(title)
                    .font(PPPetAdTypography.subheadlineBold)
                    .foregroundStyle(Color.ppTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if !message.isEmpty {
                    Text(message)
                        .font(PPPetAdTypography.caption)
                        .foregroundStyle(Color.ppTextSecondary)
                        .lineLimit(
                            dynamicTypeSize.isAccessibilitySize ? nil : 2
                        )
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func retryButton(
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: PPSpace.sm) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .bold))
                    .accessibilityHidden(true)
                Text(
                    PPPetAdLocalization.text(
                        "Retry",
                        fallback: "Retry"
                    )
                )
                .font(PPPetAdTypography.calloutBold)
            }
            .foregroundStyle(PPPetAdViewerStyle.actionForeground)
            .padding(.horizontal, PPSpace.base)
            .frame(
                maxWidth:
                    dynamicTypeSize.isAccessibilitySize
                    ? .infinity
                    : nil,
                minHeight: PPBottomDecisionBarGeometry.utilityControlSize
            )
            .background(
                PPPetAdViewerStyle.actionAccent,
                in: RoundedRectangle(
                    cornerRadius:
                        PPBottomDecisionBarGeometry.controlRadius,
                    style: .continuous
                )
            )
        }
        .buttonStyle(PPBottomDecisionPressStyle())
        .accessibilityLabel(
            PPPetAdLocalization.text(
                "Retry",
                fallback: "Retry"
            )
        )
    }

    private var loadingDock: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: PPSpace.md) {
                    loadingOwnerIdentity
                    loadingPrimaryAction
                }
            } else {
                HStack(spacing: PPSpace.md) {
                    loadingOwnerIdentity
                    loadingPrimaryAction
                        .frame(maxWidth: 164)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            PPPetAdLocalization.text(
                "pet_ad_viewer_owner_loading",
                fallback: "Loading advertiser details"
            )
        )
    }

    private var loadingOwnerIdentity: some View {
        HStack(spacing: PPSpace.sm) {
            Circle()
                .fill(Color.ppTextTertiary.opacity(0.12))
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: PPSpace.xs) {
                RoundedRectangle(cornerRadius: PPSpace.xs)
                    .fill(Color.ppTextTertiary.opacity(0.15))
                    .frame(maxWidth: 112)
                    .frame(height: 12)

                RoundedRectangle(cornerRadius: PPSpace.xs)
                    .fill(Color.ppTextTertiary.opacity(0.10))
                    .frame(maxWidth: 76)
                    .frame(height: 9)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loadingPrimaryAction: some View {
        RoundedRectangle(
            cornerRadius: PPBottomDecisionBarGeometry.controlRadius,
            style: .continuous
        )
        .fill(Color.ppTextTertiary.opacity(0.12))
        .frame(maxWidth: .infinity)
        .frame(height: primaryButtonHeight)
    }

    private var primaryButtonHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? 64
            : PPBottomDecisionBarGeometry.controlHeight
    }

    private var interestTitle: String {
        let normalizedGender =
            store.snapshot.ad.gender?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            ?? ""

        switch normalizedGender {
        case "female":
            return PPPetAdLocalization.text(
                "pet_ad_viewer_interest_female",
                fallback: "I Want Her"
            )
        case "male":
            return PPPetAdLocalization.text(
                "pet_ad_viewer_interest_male",
                fallback: "I Want Him"
            )
        case "undefined":
            return PPPetAdLocalization.text(
                "pet_ad_viewer_interest_neutral",
                fallback: "I’m Interested"
            )
        default:
            return store.snapshot.ad.isFemale
                ? PPPetAdLocalization.text(
                    "pet_ad_viewer_interest_female",
                    fallback: "I Want Her"
                )
                : PPPetAdLocalization.text(
                    "pet_ad_viewer_interest_male",
                    fallback: "I Want Him"
                )
        }
    }

    private func chatAccessibilityLabel(
        for owner: PPPetAdOwner
    ) -> String {
        String(
            format: PPPetAdLocalization.text(
                "a11y_btn_chat_user_format",
                fallback: "Chat with %@"
            ),
            owner.displayName
        )
    }

    private var isChatWorking: Bool {
        store.chatState == .working
    }

    private var isChatSucceeded: Bool {
        if case .succeeded = store.chatState {
            return true
        }
        return false
    }

    private var stateIdentity: Int {
        if !store.isSignedIn {
            return 0
        }
        switch store.ownerState {
        case .idle:
            return 1
        case .loading:
            return 2
        case .loaded:
            return store.canMessageOwner ? 3 : 4
        case .empty:
            return 5
        case .offline:
            return 6
        case .failed:
            return 7
        }
    }
}

extension PPPetAdViewerStore {
    var ppShowsContactDock: Bool {
        guard case .content = screenState else { return false }
        guard !isViewingOwnAdvertisement else { return false }
        return true
    }

    var ppShowsInlineContactStatus: Bool {
        guard case .content = screenState else { return false }
        guard !ppShowsContactDock else { return false }

        if isViewingOwnAdvertisement {
            return true
        }
        guard isSignedIn else { return false }

        switch ownerState {
        case .idle, .loading:
            return false
        case .loaded, .empty, .offline, .failed:
            return true
        }
    }
}

struct PPPetAdOwnerProfilePill: View {
    let owner: PPPetAdOwner

    var body: some View {
        HStack(spacing: PPSpace.sm) {
            ZStack(alignment: .bottomTrailing) {
                if let avatarURL = owner.avatarURL, !avatarURL.isEmpty {
                    PPPetAdRemoteImageView(
                        urlString: avatarURL,
                        blurHash: nil,
                        contentMode: .fill,
                        accessibilityLabel: owner.displayName
                    )
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.ppPrimary.opacity(0.12))

                        Text(String(owner.displayName.prefix(1)))
                            .font(PPPetAdTypography.subheadlineBold)
                            .foregroundStyle(Color.ppPrimary)
                    }
                    .frame(width: 40, height: 40)
                }

                if owner.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.ppSuccess)
                        .background(Color.white, in: Circle())
                        .offset(x: 2, y: 2)
                }
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: "\u{2068}\(owner.displayName)\u{2069}")
                    .font(PPPetAdTypography.subheadlineBold)
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineLimit(1)

                Text(
                    PPPetAdLocalization.text(
                        "pet_ad_viewer_seller_role",
                        fallback: "Advertiser"
                    )
                )
                .font(PPPetAdTypography.caption)
                .foregroundStyle(Color.ppTextSecondary.opacity(0.85))
                .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(owner.displayName), \(PPPetAdLocalization.text("pet_ad_viewer_seller_role", fallback: "Advertiser"))"
        )
    }
}
