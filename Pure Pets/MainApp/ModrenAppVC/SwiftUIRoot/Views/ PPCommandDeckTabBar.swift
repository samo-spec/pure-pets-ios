//
//  PPCommandDeckTabBar.swift
//  Pure Pets
//
//  PurePets Navigation OS — Command Deck
//  Four destinations + one Create command on one quiet navigation surface.
//
//  Deployment: iOS 17+
//
//  Design contract
//  ---------------
//  • The current destination alone uses brand ink and a filled symbol.
//    Create is a neutral plus action and never looks selected.
//  • One opaque surface and fine border keep the content visually primary.
//  • Geometry is authored once so hosted UIKit content clearance stays exact.
//

import Foundation
import SwiftUI

// MARK: - Tab Model

@available(iOS 17.0, *)
public enum PPCommandDeckTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case home
    case myAds
    case chats
    case menu

    public var id: Self { self }

    /// Reuses the existing root-route copy rather than introducing a second
    /// vocabulary for the same UIKit destinations.
    public var title: String {
        switch self {
        case .home:
            Language.get("MainPage", alter: "MainPage") ?? "MainPage"
        case .myAds:
            Language.get("menu_action_orders", alter: "menu_action_orders") ?? "menu_action_orders"
        case .chats:
            Language.get("chatsTitle", alter: "chatsTitle") ?? "chatsTitle"
        case .menu:
            Language.get("user_menu_tab_title", alter: "user_menu_tab_title") ?? "user_menu_tab_title"
        }
    }

    /// Non-directional symbols only: each one mirrors safely between Arabic
    /// RTL and English LTR, and each has a filled counterpart so the selected
    /// state is legible without relying on color alone.
    public var systemImage: String {
        switch self {
        case .home:
            "house"
        case .myAds:
            "bag"
        case .chats:
            "message"
        case .menu:
            "square.grid.2x2"
        }
    }

    public var selectedSystemImage: String {
        switch self {
        case .home:
            "house.fill"
        case .myAds:
            "bag.fill"
        case .chats:
            "message.fill"
        case .menu:
            "square.grid.2x2.fill"
        }
    }

    fileprivate var accessibilityIdentifier: String {
        "pp.commandDeck.\(rawValue)"
    }
}

// MARK: - Theme

@available(iOS 17.0, *)
public struct PPCommandDeckTheme {
    /// Source-bound Pure Pets roles. The deck uses the product surface and ink
    /// system rather than inheriting an arbitrary AccentColor.
    public var accent: Color
    /// Retained for source compatibility; Create now uses neutral action ink.
    public var createTint: Color
    public var surface: Color
    /// Retained in the public initializer for source compatibility with
    /// existing callers. The reference-faithful selected state now uses ink
    /// and symbol fill instead of a separate tile surface.
    public var selectedSurface: Color
    public var inactiveInk: Color
    public var border: Color

    public init(
        accent: Color = .ppPrimary,
        createTint: Color = .ppPrimary,
        surface: Color = .ppSurfaceElevated,
        selectedSurface: Color = .ppSoftRose,
        inactiveInk: Color = .ppTextSecondary,
        border: Color = .ppSurfaceBorder
    ) {
        self.accent = accent
        self.createTint = createTint
        self.surface = surface
        self.selectedSurface = selectedSurface
        self.inactiveInk = inactiveInk
        self.border = border
    }

    public static let `default` = PPCommandDeckTheme()
}

// MARK: - Localized Copy

@available(iOS 17.0, *)
public struct PPCommandDeckCopy {
    public var navigationLabel: LocalizedStringKey
    public var createLabel: LocalizedStringKey
    public var createHint: LocalizedStringKey

    public init(
        navigationLabel: LocalizedStringKey = "a11y_command_deck_navigation",
        createLabel: LocalizedStringKey = "a11y_tab_add",
        createHint: LocalizedStringKey = "a11y_btn_add_new_hint"
    ) {
        self.navigationLabel = navigationLabel
        self.createLabel = createLabel
        self.createHint = createHint
    }

    public static let `default` = PPCommandDeckCopy()
}

// MARK: - Metrics

@available(iOS 17.0, *)
private enum PPCommandDeckMetrics {
    /// Capsule height drives the hosted content clearance, so it is the single
    /// source of vertical truth for the whole bottom system.
    static let deckHeight: CGFloat = 56
    static let deckHorizontalPadding: CGFloat = 4
    static let tileCornerRadius: CGFloat = 20
    static var deckCornerRadius: CGFloat { deckHeight * 0.5 }
    static let iconPointSize: CGFloat = 20
    static let labelPointSize: CGFloat = 11
    static let labelSpacing: CGFloat = 2
    static let minimumTouchWidth: CGFloat = 44
    static var tileHeight: CGFloat { deckHeight - 8 }
}

// MARK: - Public Command Deck

/// PurePets bottom navigation:
/// - Home / Orders / Chats / Menu are destinations.
/// - Create is an independent command and never becomes selected.
/// - SwiftUI owns RTL mirroring; this component never reverses content manually.
/// - The opaque surface remains legible with Reduce Transparency enabled.
@available(iOS 17.0, *)
public struct PPCommandDeckTabBar: View {

    /// Insets used by the UIKit-hosted root overlay. Keeping them here ensures
    /// its content-clearance calculation stays aligned with the rendered deck.
    ///
    /// The host uses the larger of this minimum and the physical safe-area
    /// inset. Its measured height remains the content-clearance authority.
    public static let hostHorizontalInset: CGFloat = 18
    public static let hostTopInset: CGFloat = 8
    public static let hostBottomInset: CGFloat = 16
    public static let minimumBottomContentClearance: CGFloat =
        PPCommandDeckMetrics.deckHeight + hostTopInset + hostBottomInset

    @Binding private var selection: PPCommandDeckTab

    private let unreadChats: Int
    private let sessionState: PPRootSessionState
    private let theme: PPCommandDeckTheme
    private let copy: PPCommandDeckCopy
    private let onCreate: () -> Void

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize

    @Environment(\.colorSchemeContrast)
    private var contrast

    @Environment(\.colorScheme)
    private var colorScheme

    public init(
        selection: Binding<PPCommandDeckTab>,
        unreadChats: Int = 0,
        sessionState: PPRootSessionState = .init(),
        theme: PPCommandDeckTheme = .default,
        copy: PPCommandDeckCopy = .default,
        onCreate: @escaping () -> Void
    ) {
        self._selection = selection
        self.unreadChats = max(0, unreadChats)
        self.sessionState = sessionState
        self.theme = theme
        self.copy = copy
        self.onCreate = onCreate
    }

    public var body: some View {
        deckSurface
            .disabled(sessionState.isAnyBlocked)
            .accessibilityHidden(sessionState.isAnyBlocked)
    }

    private var deckContent: some View {
        // Semantic order:
        // Index 0: Home, Index 1: MyAds, Index 2: Create (+), Index 3: Chats, Index 4: Menu.
        // SwiftUI handles RTL mirroring natively.
        HStack(alignment: .center, spacing: 0) {
            PPCommandDeckTile(
                tab: .home,
                isSelected: selection == .home,
                unreadChats: unreadChats,
                theme: theme,
                onTap: { handleTap(on: .home) }
            )

            PPCommandDeckTile(
                tab: .myAds,
                isSelected: selection == .myAds,
                unreadChats: unreadChats,
                theme: theme,
                onTap: { handleTap(on: .myAds) }
            )

            createButton
                .frame(maxWidth: .infinity)

            PPCommandDeckTile(
                tab: .chats,
                isSelected: selection == .chats,
                unreadChats: unreadChats,
                theme: theme,
                onTap: { handleTap(on: .chats) }
            )

            PPCommandDeckTile(
                tab: .menu,
                isSelected: selection == .menu,
                unreadChats: unreadChats,
                theme: theme,
                onTap: { handleTap(on: .menu) }
            )
        }
        .padding(.horizontal, PPCommandDeckMetrics.deckHorizontalPadding)
        .frame(maxWidth: .infinity)
        .frame(height: PPCommandDeckMetrics.deckHeight)
        .contentShape(deckShape)
    }

    private var deckShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: PPCommandDeckMetrics.deckCornerRadius,
            style: .continuous
        )
    }

    private var deckSurface: some View {
        deckContent
            .background(deckShape.fill(theme.surface))
            .overlay {
                deckShape.strokeBorder(deckBorderColor, lineWidth: deckBorderWidth)
                    .allowsHitTesting(false)
            }
            .shadow(color: deckShadowColor, radius: 6, y: 2)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(copy.navigationLabel)
    }

    private var deckBorderColor: Color {
        if contrast == .increased {
            return colorScheme == .dark
                ? Color.white.opacity(0.50)
                : Color.ppTextPrimary.opacity(0.75)
        }
        return theme.border.opacity(0.72)
    }

    private var deckBorderWidth: CGFloat {
        contrast == .increased ? 1 : 0.5
    }

    private var deckShadowColor: Color {
        Color.black.opacity(
            contrast == .increased
                ? 0.0
                : (colorScheme == .dark ? 0.16 : 0.04)
        )
    }

    // MARK: Create command

    private var createButton: some View {
        Button {
            // The root store owns the single haptic and presentation decision.
            onCreate()
        } label: {
            createLabel
                .foregroundStyle(inactiveInk)
                .frame(minWidth: PPCommandDeckMetrics.minimumTouchWidth, maxWidth: .infinity)
                .frame(height: PPCommandDeckMetrics.tileHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(PPCommandDeckPressStyle(pressedScale: 0.96))
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(copy.createLabel)
        .accessibilityHint(copy.createHint)
        .accessibilityIdentifier("pp.commandDeck.create")
        .accessibilityShowsLargeContentViewer {
            Label(copy.createLabel, systemImage: "plus")
        }
    }

    @ViewBuilder
    private var createLabel: some View {
        if dynamicTypeSize < .xxxLarge {
            ViewThatFits(in: .horizontal) {
                VStack(spacing: PPCommandDeckMetrics.labelSpacing) {
                    createIcon
                    Text(Language.get("Add", alter: "Add") ?? "Add")
                        .font(PPFont.medium(PPCommandDeckMetrics.labelPointSize))
                        .lineLimit(1)
                }
                .fixedSize(horizontal: true, vertical: false)

                createIcon
            }
        } else {
            createIcon
        }
    }

    private var createIcon: some View {
        Image(systemName: "plus")
            .font(.system(
                size: dynamicTypeSize.isAccessibilitySize ? 24 : PPCommandDeckMetrics.iconPointSize,
                weight: .medium
            ))
            .frame(width: 28, height: 24)
    }

    private var inactiveInk: Color {
        if contrast == .increased {
            return colorScheme == .dark ? Color.white : Color.ppTextPrimary
        }
        return theme.inactiveInk
    }

    // MARK: Interaction

    private func handleTap(on tab: PPCommandDeckTab) {
        // The root binding intentionally receives reselection so the existing
        // coordinator can pop the active navigation stack.
        guard selection != tab else {
            selection = tab
            return
        }

        if reduceMotion {
            selection = tab
            return
        }

        withAnimation(.snappy(duration: 0.20, extraBounce: 0.02)) {
            selection = tab
        }
    }
}

// MARK: - Destination Tile

@available(iOS 17.0, *)
private struct PPCommandDeckTile: View {

    let tab: PPCommandDeckTab
    let isSelected: Bool
    let unreadChats: Int
    let theme: PPCommandDeckTheme
    let onTap: () -> Void

    @Environment(\.colorScheme)
    private var colorScheme

    @Environment(\.colorSchemeContrast)
    private var contrast

    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            labelContent
                .frame(minWidth: PPCommandDeckMetrics.minimumTouchWidth, maxWidth: .infinity)
                .frame(height: PPCommandDeckMetrics.tileHeight)
                .contentShape(tileShape)
        }
        .buttonStyle(PPCommandDeckPressStyle(pressedScale: 0.96))
        .frame(maxWidth: .infinity)
        .accessibilityLabel(tab.title)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(tab.accessibilityIdentifier)
        .accessibilityShowsLargeContentViewer {
            Label(tab.title, systemImage: tab.selectedSystemImage)
        }
    }

    private var tileShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: PPCommandDeckMetrics.tileCornerRadius,
            style: .continuous
        )
    }

    /// The system large-content viewer supplies full labels when a destination
    /// cannot fit its navigation slot. The accessibility environment remains
    /// uncapped so the viewer can present the user's full preferred text size.
    private var showsLabel: Bool {
        dynamicTypeSize < .xxxLarge
    }

    @ViewBuilder
    private var labelContent: some View {
        if showsLabel {
            ViewThatFits(in: .horizontal) {
                fullLabel
                icon
            }
            .foregroundStyle(ink)
        } else {
            icon
                .foregroundStyle(ink)
        }
    }

    private var fullLabel: some View {
        VStack(spacing: PPCommandDeckMetrics.labelSpacing) {
            icon
            Text(tab.title)
                .font(
                    isSelected
                        ? PPFont.bold(PPCommandDeckMetrics.labelPointSize)
                        : PPFont.medium(PPCommandDeckMetrics.labelPointSize)
                )
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private var iconBase: some View {
        Image(
            systemName: isSelected
                ? tab.selectedSystemImage
                : tab.systemImage
        )
        .font(
            .system(
                size: dynamicTypeSize.isAccessibilitySize ? 24 : PPCommandDeckMetrics.iconPointSize,
                weight: isSelected ? .semibold : .regular
            )
        )
    }

    private var icon: some View {
        iconBase
            .contentTransition(.opacity)
            .frame(width: 28, height: 24)
            .overlay(alignment: .topTrailing) {
                if tab == .chats, unreadChats > 0 {
                    PPCommandDeckUnreadBadge(
                        count: unreadChats,
                        tint: .ppTextPrimary
                    )
                    .alignmentGuide(.top) { $0[.top] + 4 }
                    .alignmentGuide(.trailing) { $0[.trailing] - 5 }
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .scale(scale: 0.6).combined(with: .opacity)
                    )
                    .accessibilityHidden(true)
                }
            }
            .animation(
                reduceMotion ? nil : .snappy(duration: 0.24),
                value: unreadChats
            )
    }

    private var ink: Color {
        if isSelected {
            return theme.accent
        }
        if contrast == .increased {
            return colorScheme == .dark ? Color.white : Color.ppTextPrimary
        }
        return theme.inactiveInk
    }

    private var accessibilityValue: Text {
        let selectedTitle = Language.get("a11y_command_deck_selected", alter: "selected") ?? "selected"
        if tab == .chats, unreadChats > 0 {
            let unreadFormat = Language.get(
                "a11y_command_deck_unread_count",
                alter: "%d unread chats"
            ) ?? "%d unread chats"
            let unread = Text(verbatim: String.localizedStringWithFormat(
                unreadFormat,
                unreadChats
            ))

            if isSelected {
                return Text(verbatim: selectedTitle)
                    + Text(verbatim: ", ")
                    + unread
            }

            return unread
        }

        if isSelected {
            return Text(verbatim: selectedTitle)
        }

        return Text(verbatim: "")
    }
}

// MARK: - Unread Badge

@available(iOS 17.0, *)
private struct PPCommandDeckUnreadBadge: View {

    let count: Int
    let tint: Color

    @Environment(\.locale)
    private var locale

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        Text(displayText)
            .font(
                .system(
                    size: 9,
                    weight: .bold,
                    design: .rounded
                )
            )
            .monospacedDigit()
            .contentTransition(reduceMotion ? .identity : .numericText())
            .foregroundStyle(Color.ppSurfaceElevated)
            .padding(.horizontal, 4)
            .frame(minWidth: 16, minHeight: 16)
            .background(tint, in: Capsule())
            .overlay {
                Capsule().strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
            }
    }

    private var displayText: String {
        let cappedCount = min(max(0, count), 99)
        let number = cappedCount.formatted(.number.locale(locale))

        return count > 99 ? "\(number)+" : number
    }
}

// MARK: - Press Feedback

@available(iOS 17.0, *)
private struct PPCommandDeckPressStyle: ButtonStyle {

    var pressedScale: CGFloat = 0.96

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                configuration.isPressed && !reduceMotion ? pressedScale : 1
            )
            .opacity(configuration.isPressed ? 0.94 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}

// MARK: - Previews

#if DEBUG
@available(iOS 17.0, *)
private struct PPCommandDeckPreviewHost: View {

    @State private var selection: PPCommandDeckTab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.ppBackground.ignoresSafeArea()

            PPCommandDeckTabBar(
                selection: $selection,
                unreadChats: 4,
                onCreate: {}
            )
            .padding(.horizontal, PPCommandDeckTabBar.hostHorizontalInset)
            .padding(.top, PPCommandDeckTabBar.hostTopInset)
            .padding(.bottom, PPCommandDeckTabBar.hostBottomInset)
        }
    }
}

@available(iOS 17.0, *)
#Preview("Command Deck — Arabic RTL") {
    PPCommandDeckPreviewHost()
        .environment(\.layoutDirection, .rightToLeft)
}

@available(iOS 17.0, *)
#Preview("Command Deck — English LTR") {
    PPCommandDeckPreviewHost()
        .environment(\.layoutDirection, .leftToRight)
}

@available(iOS 17.0, *)
#Preview("Command Deck — Dark") {
    PPCommandDeckPreviewHost()
        .environment(\.layoutDirection, .rightToLeft)
        .preferredColorScheme(.dark)
}

@available(iOS 17.0, *)
#Preview("Command Deck — Reduce Transparency") {
    PPCommandDeckPreviewHost()
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.accessibilityReduceTransparency, true)
}

@available(iOS 17.0, *)
#Preview("Command Deck — AX5") {
    PPCommandDeckPreviewHost()
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
