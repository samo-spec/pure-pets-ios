//
//  PPCommandDeckTabBar.swift
//  Pure Pets
//
//  PurePets Navigation OS — Command Deck
//  Four destinations on one quiet rail + one compact Create command.
//
//  Deployment: iOS 17+
//  Native Liquid Glass: iOS 26+
//
//  Design contract
//  ---------------
//  • The rail is the surface; Create is the single consequential action.
//    Create is deliberately SMALLER than the rail so it reads as an action
//    inside the bottom system, never as a competing second navigation blob.
//  • Selection is carried by a warm product tile + filled symbol + brand ink,
//    so state survives grayscale, increased contrast, and small sizes.
//  • Geometry is authored once and shared by the glass and non-glass paths,
//    which keeps the hosted UIKit content-clearance calculation truthful.
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
    public var createTint: Color
    public var surface: Color
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
    /// Rail height drives the hosted content clearance, so it is the single
    /// source of vertical truth for the whole bottom system.
    static let railHeight: CGFloat = 62
    static let railPadding: CGFloat = 5
    static let tileCornerRadius: CGFloat = 20
    /// The rail concentrically wraps the selected tile: tile radius + 3.
    static var railCornerRadius: CGFloat { tileCornerRadius + 3 }
    static let tileSpacing: CGFloat = 2
    static let iconPointSize: CGFloat = 19
    static let labelPointSize: CGFloat = 11

    /// Create stays smaller than the rail: an action inside the system,
    /// not a second navigation surface.
    static let createDiameter: CGFloat = 52
    static let createIconPointSize: CGFloat = 21
    static let gap: CGFloat = 10

    static var tileHeight: CGFloat { railHeight - (railPadding * 2) }
}

// MARK: - Public Command Deck

/// PurePets bottom navigation:
/// - Home / Orders / Chats / Menu are destinations.
/// - Create is an independent command and never becomes selected.
/// - SwiftUI owns RTL mirroring; this component never reverses content manually.
/// - iOS 26+ renders the rail as Liquid Glass over a product surface tint.
///   iOS 17–25 renders the same geometry on the opaque product surface.
@available(iOS 17.0, *)
public struct PPCommandDeckTabBar: View {

    /// Insets used by the UIKit-hosted root overlay. Keeping them here ensures
    /// its content-clearance calculation stays aligned with the rendered deck.
    ///
    /// `hostBottomInset` is measured from the physical screen edge, not from the
    /// bottom safe area, so the deck keeps one predictable resting position
    /// across devices while staying clear of the home indicator.
    public static let hostHorizontalInset: CGFloat = 14
    public static let hostTopInset: CGFloat = 8
    public static let hostBottomInset: CGFloat = 16
    public static let minimumBottomContentClearance: CGFloat =
        PPCommandDeckMetrics.railHeight + hostTopInset + hostBottomInset

    @Binding private var selection: PPCommandDeckTab

    private let unreadChats: Int
    private let theme: PPCommandDeckTheme
    private let copy: PPCommandDeckCopy
    private let onCreate: () -> Void

    @Namespace private var selectionNamespace

    @State private var navigationFeedbackToken = 0
    @State private var createFeedbackToken = 0

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency

    @Environment(\.colorSchemeContrast)
    private var contrast

    @Environment(\.colorScheme)
    private var colorScheme

    public init(
        selection: Binding<PPCommandDeckTab>,
        unreadChats: Int = 0,
        theme: PPCommandDeckTheme = .default,
        copy: PPCommandDeckCopy = .default,
        onCreate: @escaping () -> Void
    ) {
        self._selection = selection
        self.unreadChats = max(0, unreadChats)
        self.theme = theme
        self.copy = copy
        self.onCreate = onCreate
    }

    public var body: some View {
        deckLayout
            // Feedback fires only for direct interaction handled by this control.
            // Programmatic tab changes (deep links / restoration) stay silent.
            .sensoryFeedback(.selection, trigger: navigationFeedbackToken)
            .sensoryFeedback(
                .impact(weight: .medium, intensity: 0.7),
                trigger: createFeedbackToken
            )
    }

    @ViewBuilder
    private var deckLayout: some View {
        if #available(iOS 26.0, *) {
            // Zero interaction spacing keeps a deliberate seam between the
            // destination rail and the separate Create command.
            GlassEffectContainer(spacing: 0) {
                deckContent
            }
        } else {
            deckContent
        }
    }

    private var deckContent: some View {
        // Semantic order only. SwiftUI flips horizontal positions in RTL.
        HStack(alignment: .center, spacing: PPCommandDeckMetrics.gap) {
            rail
            createButton
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Destination rail

    private var railShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: PPCommandDeckMetrics.railCornerRadius,
            style: .continuous
        )
    }

    private var railContent: some View {
        HStack(spacing: PPCommandDeckMetrics.tileSpacing) {
            ForEach(PPCommandDeckTab.allCases) { tab in
                PPCommandDeckTile(
                    tab: tab,
                    isSelected: selection == tab,
                    unreadChats: unreadChats,
                    theme: theme,
                    selectionNamespace: selectionNamespace,
                    onTap: { handleTap(on: tab) }
                )
            }
        }
        .padding(PPCommandDeckMetrics.railPadding)
        .frame(maxWidth: .infinity)
        .frame(height: PPCommandDeckMetrics.railHeight)
    }

    private var rail: some View {
        railVariant
            .accessibilityElement(children: .contain)
            .accessibilityLabel(copy.navigationLabel)
    }

    @ViewBuilder
    private var railVariant: some View {
        if #available(iOS 26.0, *) {
            if reduceTransparency {
                opaqueRail
            } else {
                glassRail
            }
        } else {
            opaqueRail
        }
    }

    @available(iOS 26.0, *)
    private var glassRail: some View {
        railContent
            .background(railShape.fill(theme.surface.opacity(0.55)))
            .glassEffect(.regular, in: railShape)
            .overlay {
                railShape.strokeBorder(railBorderColor, lineWidth: railBorderWidth)
            }
            .shadow(color: railShadowColor, radius: 10, y: 4)
    }

    private var opaqueRail: some View {
        railContent
            .background(railShape.fill(theme.surface))
            .overlay {
                railShape.strokeBorder(railBorderColor, lineWidth: railBorderWidth)
            }
            .shadow(
                color: railShadowColor,
                radius: reduceTransparency ? 6 : 14,
                y: reduceTransparency ? 2 : 6
            )
    }

    private var railBorderColor: Color {
        contrast == .increased
            ? Color.ppTextPrimary.opacity(0.45)
            : theme.border.opacity(colorScheme == .dark ? 0.85 : 0.70)
    }

    private var railBorderWidth: CGFloat {
        contrast == .increased ? 1.4 : 0.8
    }

    private var railShadowColor: Color {
        Color.black.opacity(
            contrast == .increased
                ? 0.0
                : (colorScheme == .dark ? 0.24 : 0.07)
        )
    }

    // MARK: Create command

    private var createButton: some View {
        Button {
            createFeedbackToken &+= 1
            onCreate()
        } label: {
            Image(systemName: "plus")
                .font(
                    .system(
                        size: PPCommandDeckMetrics.createIconPointSize,
                        weight: .semibold
                    )
                )
                .foregroundStyle(Color.white)
                // An explicit frame is required: a bordered/prominent button
                // style would inflate its own geometry and break the deliberate
                // size relationship with the rail.
                .frame(
                    width: PPCommandDeckMetrics.createDiameter,
                    height: PPCommandDeckMetrics.createDiameter
                )
                .background(Circle().fill(theme.createTint))
                .overlay {
                    Circle().strokeBorder(
                        contrast == .increased
                            ? Color.white.opacity(0.85)
                            : Color.white.opacity(0.18),
                        lineWidth: contrast == .increased ? 1.4 : 0.8
                    )
                }
                .contentShape(Circle())
        }
        .buttonStyle(PPCommandDeckPressStyle(pressedScale: 0.93))
        .shadow(
            color: theme.createTint.opacity(
                contrast == .increased ? 0.0 : (colorScheme == .dark ? 0.34 : 0.26)
            ),
            radius: 14,
            y: 6
        )
        .accessibilityLabel(copy.createLabel)
        .accessibilityHint(copy.createHint)
        .accessibilityIdentifier("pp.commandDeck.create")
    }

    // MARK: Interaction

    private func handleTap(on tab: PPCommandDeckTab) {
        // The root binding intentionally receives reselection so the existing
        // coordinator can pop the active navigation stack.
        guard selection != tab else {
            selection = tab
            return
        }

        navigationFeedbackToken &+= 1

        if reduceMotion {
            selection = tab
            return
        }

        withAnimation(.snappy(duration: 0.26, extraBounce: 0.02)) {
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
    let selectionNamespace: Namespace.ID
    let onTap: () -> Void

    @Environment(\.colorSchemeContrast)
    private var contrast

    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            labelContent
                .frame(maxWidth: .infinity)
                .frame(height: PPCommandDeckMetrics.tileHeight)
                .contentShape(tileShape)
                .background {
                    if isSelected {
                        selectionSurface
                    }
                }
        }
        .buttonStyle(PPCommandDeckPressStyle(pressedScale: 0.96))
        .accessibilityLabel(tab.title)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(tab.accessibilityIdentifier)
    }

    private var tileShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: PPCommandDeckMetrics.tileCornerRadius,
            style: .continuous
        )
    }

    /// The selected route carries a warm, product-owned decision surface —
    /// never a second glass layer over the rail.
    private var selectionSurface: some View {
        tileShape
            .fill(theme.selectedSurface)
            .overlay {
                tileShape.strokeBorder(
                    contrast == .increased
                        ? theme.accent.opacity(0.85)
                        : theme.border.opacity(0.75),
                    lineWidth: contrast == .increased ? 1.4 : 0.8
                )
            }
            .matchedGeometryEffect(
                id: "pp-command-deck-selection",
                in: selectionNamespace
            )
    }

    /// Labels are dropped at accessibility sizes instead of being crushed,
    /// which keeps the rail height stable and the icons legible.
    private var showsLabel: Bool {
        dynamicTypeSize < .accessibility1
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
        VStack(spacing: 2) {
            icon
            Text(tab.title)
                .font(
                    isSelected
                        ? PPFont.bold(PPCommandDeckMetrics.labelPointSize)
                        : PPFont.medium(PPCommandDeckMetrics.labelPointSize)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var icon: some View {
        Image(
            systemName: isSelected
                ? tab.selectedSystemImage
                : tab.systemImage
        )
        .font(
            .system(
                size: PPCommandDeckMetrics.iconPointSize,
                weight: isSelected ? .semibold : .regular
            )
        )
        // Outline → filled is the primary, non-color state signal.
        .contentTransition(.symbolEffect(.replace))
        .frame(height: 24)
        .overlay(alignment: .topTrailing) {
            if tab == .chats, unreadChats > 0 {
                PPCommandDeckUnreadBadge(
                    count: unreadChats,
                    tint: theme.accent
                )
                .alignmentGuide(.top) { $0[.top] + 6 }
                .alignmentGuide(.trailing) { $0[.trailing] - 7 }
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
        return contrast == .increased
            ? Color.ppTextPrimary
            : theme.inactiveInk
    }

    private var accessibilityValue: Text {
        if tab == .chats, unreadChats > 0 {
            let unreadFormat = NSLocalizedString(
                "a11y_command_deck_unread_count",
                comment: "Unread chat count in the Command Deck"
            )
            let unread = Text(verbatim: String.localizedStringWithFormat(
                unreadFormat,
                unreadChats
            ))

            if isSelected {
                return Text("a11y_command_deck_selected")
                    + Text(verbatim: ", ")
                    + unread
            }

            return unread
        }

        if isSelected {
            return Text("a11y_command_deck_selected")
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
            .contentTransition(.numericText())
            .foregroundStyle(Color.white)
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
