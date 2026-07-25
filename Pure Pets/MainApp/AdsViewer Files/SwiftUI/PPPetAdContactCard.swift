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
        VStack(alignment: .leading, spacing: PPSpace.lg) {
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
        .padding(PPPetAdViewerStyle.surfacePadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ppPetAdSurface()
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
            // The screen pins this dock to the bottom of a full-height overlay.
            // Keep the dock on its intrinsic vertical axis so flexible controls
            // cannot consume the overlay's entire proposed height.
            .fixedSize(horizontal: false, vertical: true)
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
                action: store.requireSignInForContact
            )
        } else {
            switch store.ownerState {
            case .idle, .loading:
                loadingDock
            case .loaded:
                if let owner = store.owner {
                    VStack(alignment: .leading, spacing: 6) {
                        dockHeaderTitleView

                        actionRow(for: owner)
                            .padding(.top, 2)
                    }
                }
            case .empty, .offline, .failed:
                EmptyView()
            }
        }
    }

    private var dockHeaderTitleView: some View {
        HStack(spacing: 5) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.ppPrimary)

            Text(
                PPPetAdLocalization.text(
                    "pet_ad_viewer_contact_dock_title",
                    fallback: "التواصل المباشر مع المعلن"
                )
            )
            .font(PPPetAdTypography.footnoteBold)
            .foregroundStyle(Color.ppTextSecondary.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader)
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
        HStack(spacing: 16) {
            PPPetAdOwnerProfilePill(owner: owner)

            HStack(spacing: 10) {
                if store.canCallOwner {
                    callIconButton(for: owner)
                }

                if store.canMessageOwner {
                    chatIconButton(for: owner)
                }
            }
        }
    }

    private func verticalActionRow(
        for owner: PPPetAdOwner
    ) -> some View {
        VStack(spacing: PPSpace.md) {
            PPPetAdOwnerProfilePill(owner: owner)

            HStack(spacing: 10) {
                if store.canCallOwner {
                    callIconButton(for: owner)
                }

                if store.canMessageOwner {
                    chatIconButton(for: owner)
                }
            }
        }
    }

    @ViewBuilder
    private func callOnlyActions(
        for owner: PPPetAdOwner
    ) -> some View {
        if store.canCallOwner {
            HStack(spacing: 16) {
                PPPetAdOwnerProfilePill(owner: owner)
                    .frame(maxWidth: .infinity, alignment: .leading)

                callIconButton(for: owner)
            }
        }
    }

    private func chatIconButton(
        for owner: PPPetAdOwner
    ) -> some View {
        Button(action: store.openChat) {
            ZStack {
                if store.chatState == .working {
                    ProgressView()
                        .controlSize(.small)
                        .tint(PPPetAdViewerStyle.actionForeground)
                } else {
                    Image(systemName: "message.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(PPPetAdViewerStyle.actionForeground)
                }
            }
            .frame(width: 50, height: 50)
            .background(
                PPPetAdViewerStyle.actionAccent,
                in: Circle()
            )
            .overlay {
                Circle()
                    .strokeBorder(
                        Color.white.opacity(0.30),
                        lineWidth: PPPetAdViewerStyle.hairlineWidth
                    )
            }
            .shadow(
                color: PPPetAdViewerStyle.actionAccent.opacity(0.24),
                radius: 8,
                x: 0,
                y: 3
            )
            .contentShape(Circle())
        }
        .buttonStyle(PPPetAdPressButtonStyle(pressedScale: 0.92))
        .disabled(store.chatState == .working)
        .accessibilityLabel(chatAccessibilityLabel(for: owner))
    }

    private func callIconButton(
        for owner: PPPetAdOwner
    ) -> some View {
        Button(action: store.callOwner) {
            Image(systemName: "phone.fill")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(PPPetAdViewerStyle.darkActionForeground)
                .frame(width: 50, height: 50)
                .background(
                    PPPetAdViewerStyle.darkActionFill,
                    in: Circle()
                )
                .overlay {
                    Circle()
                        .strokeBorder(
                            Color(uiColor: .separator).opacity(0.24),
                            lineWidth: PPPetAdViewerStyle.hairlineWidth
                        )
                }
                .shadow(
                    color: Color.black.opacity(0.08),
                    radius: 6,
                    x: 0,
                    y: 2
                )
                .contentShape(Circle())
        }
        .buttonStyle(PPPetAdPressButtonStyle(pressedScale: 0.92))
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




    private func primaryButton(
        title: String,
        symbol: String,
        accessibilityLabel: String,
        isLoading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(PPPetAdViewerStyle.darkActionFill)

                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(
                                PPPetAdViewerStyle.darkActionForeground
                            )
                    } else {
                        Image(systemName: symbol)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(
                                PPPetAdViewerStyle.darkActionForeground
                            )
                    }
                }
                .frame(
                    width: PPPetAdViewerStyle.dockControlSize - 4,
                    height: PPPetAdViewerStyle.dockControlSize - 4
                )
                .accessibilityHidden(true)

                Text(title)
                    .font(PPPetAdTypography.calloutBold)
                    .foregroundStyle(
                        PPPetAdViewerStyle.actionForeground
                    )
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)

                Color.clear
                    .frame(width: PPSpace.sm)
                    .accessibilityHidden(true)
            }
            .padding(2)
            .frame(maxWidth: .infinity)
            .frame(height: primaryButtonHeight)
            .background(
                PPPetAdViewerStyle.actionAccent,
                in: Capsule()
            )
            .overlay(alignment: .topTrailing) {
                Image(systemName: "sparkle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.42))
                    .padding(.trailing, PPSpace.lg)
                    .padding(.top, PPSpace.sm)
                    .accessibilityHidden(true)
            }
            .shadow(
                color: PPPetAdViewerStyle.actionAccent.opacity(0.18),
                radius: 12,
                x: 0,
                y: 5
            )
            .contentShape(Capsule())
        }
        .buttonStyle(PPPetAdPressButtonStyle(pressedScale: 0.982))
        .disabled(isLoading)
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

    private func iconButton(
        symbol: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(
                    PPPetAdViewerStyle.darkActionForeground
                )
                .frame(
                    width: PPPetAdViewerStyle.dockControlSize,
                    height: PPPetAdViewerStyle.dockControlSize
                )
                .background(
                    PPPetAdViewerStyle.darkActionFill,
                    in: Circle()
                )
        }
        .buttonStyle(PPPetAdPressButtonStyle(pressedScale: 0.92))
        .accessibilityLabel(accessibilityLabel)
    }

    private var loadingDock: some View {
        HStack(spacing: PPSpace.md) {
            ForEach(0..<2, id: \.self) { _ in
                Circle()
                    .fill(Color.ppTextTertiary.opacity(0.12))
                    .frame(
                        width: PPPetAdViewerStyle.dockControlSize,
                        height: PPPetAdViewerStyle.dockControlSize
                    )
            }

            Capsule()
                .fill(Color.ppTextTertiary.opacity(0.12))
                .frame(maxWidth: .infinity)
                .frame(height: PPPetAdViewerStyle.dockControlSize)
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

    private var primaryButtonHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? 72
            : PPPetAdViewerStyle.dockControlSize
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

    private func whatsAppAccessibilityLabel(
        for owner: PPPetAdOwner
    ) -> String {
        String(
            format: PPPetAdLocalization.text(
                "a11y_btn_whatsapp_user_format",
                fallback: "WhatsApp %@"
            ),
            owner.displayName
        )
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

        if !isSignedIn {
            return true
        }

        switch ownerState {
        case .idle, .loading:
            return true
        case .loaded:
            return owner != nil && (canMessageOwner || canCallOwner)
        case .empty, .offline, .failed:
            return false
        }
    }
}

/// A pure profile info pill UI (non-CTA) displaying advertiser identity and verified badge.
struct PPPetAdOwnerProfilePill: View {
    let owner: PPPetAdOwner

    var body: some View {
        HStack(spacing: PPSpace.sm) {
            // Seller Avatar + Verified Checkmark Badge
            ZStack(alignment: .bottomTrailing) {
                if let avatarURL = owner.avatarURL, !avatarURL.isEmpty {
                    PPPetAdRemoteImageView(
                        urlString: avatarURL,
                        blurHash: nil,
                        contentMode: .fill,
                        accessibilityLabel: owner.displayName
                    )
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.ppPrimary.opacity(0.12))

                        Text(String(owner.displayName.prefix(1)))
                            .font(PPPetAdTypography.subheadlineBold)
                            .foregroundStyle(Color.ppPrimary)
                    }
                    .frame(width: 36, height: 36)
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

            // Seller Name & Role Tag
            VStack(alignment: .leading, spacing: 1) {
                Text(owner.displayName)
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
        .padding(.horizontal, PPSpace.sm + 4)
        .frame(height: 50)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.ppCard.opacity(0.88),
            in: Capsule()
        )
        .overlay {
            Capsule()
                .strokeBorder(
                    Color(uiColor: .separator).opacity(0.24),
                    lineWidth: PPPetAdViewerStyle.hairlineWidth
                )
        }
        .shadow(
            color: Color.black.opacity(0.06),
            radius: 6,
            x: 0,
            y: 2
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(owner.displayName), Advertiser")
    }
}


