//
//  PPCartFloatingBarView.swift
//  PurePetsSwiftUIRefactor
//
//  Created for PurePets Platform SwiftUI Root Architecture.
//

import SwiftUI

/// Presentation-only floating cart control. `PPRootStore` remains responsible
/// for cart state, collapse timing (6s), haptics, and the cart route.
public struct PPCartFloatingBarView: View {
    private enum Metrics {
        static let collapsedSize = PPBottomDecisionBarGeometry.utilityControlSize
        static let expandedMinHeight = PPSpace.xxxxl + PPSpace.lg
        static let emblemSize = PPBottomDecisionBarGeometry.controlHeight - PPSpace.md
        static let actionMinHeight = PPBottomDecisionBarGeometry.controlHeight - PPSpace.base
        static let badgeDiameter = PPSpace.lg
        static let collapsedRadius = PPCorner.medium
        static let surfaceRadius = PPCorner.card
        static let tileRadius = PPCorner.small
        static let actionRadius = PPBottomDecisionBarGeometry.controlRadius
    }

    public let state: PPCartFloatingBarState
    public let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.layoutDirection) private var layoutDirection

    private var isRightToLeft: Bool { layoutDirection == .rightToLeft }

    private var usesAccessibilityLayout: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var surfaceShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: state.isCollapsed
                ? Metrics.collapsedRadius
                : Metrics.surfaceRadius,
            style: .continuous
        )
    }

    private var stateAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.16)
            : .spring(response: 0.34, dampingFraction: 0.86)
    }

    private var countAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.16)
            : .spring(response: 0.26, dampingFraction: 0.84)
    }

    private var expandedMinHeight: CGFloat {
        usesAccessibilityLayout
            ? (PPSpace.xxxxl * 2) + PPSpace.xxl
            : Metrics.expandedMinHeight
    }

    public init(
        state: PPCartFloatingBarState,
        onTap: @escaping () -> Void
    ) {
        self.state = state
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            Group {
                if state.isCollapsed {
                    collapsedContent
                } else if usesAccessibilityLayout {
                    expandedAccessibilityContent
                } else {
                    expandedContent
                }
            }
            .background { surface }
            .contentShape(surfaceShape)
        }
        .buttonStyle(PPCartFloatingBarPressStyle())
        .animation(stateAnimation, value: state.isCollapsed)
        .animation(countAnimation, value: state.itemCount)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            NSLocalizedString(
                "a11y_btn_cart",
                value: "Shopping cart",
                comment: "Floating cart button label"
            )
        )
        .accessibilityValue(state.subtitleText)
        .accessibilityHint(
            state.isCollapsed
                ? NSLocalizedString(
                    "cart_summary_expand",
                    value: "Expand order summary",
                    comment: "Collapsed floating cart button hint"
                )
                : NSLocalizedString(
                    "a11y_btn_cart_hint",
                    value: "Double-tap to open your cart",
                    comment: "Expanded floating cart button hint"
                )
        )
    }

    // MARK: - Layout

    /// The rail keeps the cart emblem stable while the summary and action
    /// appear around it, preserving spatial continuity on collapse and expand.
    private var collapsedContent: some View {
        cartEmblem
            .frame(width: Metrics.collapsedSize, height: Metrics.collapsedSize)
    }

    private var expandedContent: some View {
        HStack(spacing: PPSpace.md) {
            cartEmblem

            cartSummary
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
                .transition(summaryTransition)

            reviewAction
                .layoutPriority(2)
                .transition(actionTransition)
        }
        .padding(PPSpace.sm)
        .frame(maxWidth: .infinity, minHeight: Metrics.expandedMinHeight)
    }

    private var expandedAccessibilityContent: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            HStack(spacing: PPSpace.md) {
                cartEmblem
                cartSummary
            }

            reviewAction
                .frame(maxWidth: .infinity)
        }
        .padding(PPSpace.sm)
        .frame(maxWidth: .infinity, minHeight: expandedMinHeight)
    }

    /// The emblem is a true cart anchor rather than a detached decorative
    /// badge. The parent button owns all interaction and accessibility.
    private var cartEmblem: some View {
        ZStack {
            if !state.isCollapsed {
                RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous)
                    .fill(Color.ppPrimary)
            }

            Image(systemName: "cart.fill")
                .font(
                    .system(
                        size: state.isCollapsed ? 21 : 19,
                        weight: .bold
                    )
                )
                .foregroundStyle(.white)
        }
        .frame(width: Metrics.emblemSize, height: Metrics.emblemSize)
        .overlay(alignment: isRightToLeft ? .topLeading : .topTrailing) {
            if !state.badgeText.isEmpty {
                cartCountBadge
            }
        }
        .accessibilityHidden(true)
    }

    private var cartCountBadge: some View {
        Text(state.badgeText)
            .id(state.itemCount)
            .font(.ppBeirutiBold(size: 11, relativeTo: .caption2))
            .monospacedDigit()
            .foregroundStyle(Color.ppPrimary)
            .padding(.horizontal, PPSpace.xs)
            .frame(
                minWidth: Metrics.badgeDiameter,
                minHeight: Metrics.badgeDiameter
            )
            .background(Color.ppSurfaceElevated, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(
                        Color.ppPrimary.opacity(
                            colorSchemeContrast == .increased ? 0.64 : 0.28
                        ),
                        lineWidth: borderWidth
                    )
            }
            .offset(
                x: isRightToLeft ? -(PPSpace.md / 2) : PPSpace.md / 2,
                y: -(PPSpace.md / 2)
            )
            .transition(
                reduceMotion
                    ? .opacity
                    : .scale(scale: 0.72, anchor: .center).combined(with: .opacity)
            )
    }

    private var cartSummary: some View {
        VStack(alignment: .leading, spacing: PPSpace.xxs) {
            Text(
                NSLocalizedString(
                    "Cart",
                    value: "Cart",
                    comment: "Floating cart title"
                )
            )
            .font(.ppBeirutiBold(size: 16, relativeTo: .headline))
            .foregroundStyle(Color.ppTextPrimary)
            .lineLimit(1)

            Text(state.subtitleText)
                .font(.ppBeirutiMedium(size: 13, relativeTo: .subheadline))
                .foregroundStyle(Color.ppTextSecondary)
                .monospacedDigit()
                .lineLimit(usesAccessibilityLayout ? 2 : 1)
                .minimumScaleFactor(0.84)
        }
        .multilineTextAlignment(.leading)
        .accessibilityHidden(true)
    }

    private var reviewAction: some View {
        HStack(spacing: PPSpace.xs) {
            Text(
                NSLocalizedString(
                    "checkout_review_cart_action",
                    value: "Review Cart",
                    comment: "Floating cart action"
                )
            )
            .font(.ppBeirutiBold(size: 14, relativeTo: .callout))
            .lineLimit(1)
            .minimumScaleFactor(0.82)

            Image(systemName: isRightToLeft ? "arrow.left" : "arrow.right")
                .font(.system(size: 13, weight: .bold))
                .accessibilityHidden(true)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, PPSpace.md)
        .frame(minHeight: Metrics.actionMinHeight)
        .background(
            Color.ppPrimary,
            in: RoundedRectangle(
                cornerRadius: Metrics.actionRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: Metrics.actionRadius,
                style: .continuous
            )
            .strokeBorder(
                Color.white.opacity(
                    colorSchemeContrast == .increased ? 0.46 : 0.22
                ),
                lineWidth: borderWidth
            )
        }
        .accessibilityHidden(true)
    }

    // MARK: - Surface

    private var surface: some View {
        surfaceShape
            .fill(state.isCollapsed ? Color.ppPrimary : surfaceColor)
            .overlay {
                surfaceShape.strokeBorder(
                    surfaceBorderColor,
                    lineWidth: borderWidth
                )
            }
            .shadow(
                color: surfaceShadowColor,
                radius: state.isCollapsed ? PPShadow.button.radius : PPShadow.card.radius,
                x: 0,
                y: state.isCollapsed ? PPShadow.button.y : PPShadow.card.y
            )
    }

    private var surfaceColor: Color {
        reduceTransparency
            ? Color.ppSurfaceElevated
            : Color.ppSurfaceElevated.opacity(0.98)
    }

    private var surfaceBorderColor: Color {
        if state.isCollapsed {
            return Color.white.opacity(
                colorSchemeContrast == .increased ? 0.54 : 0.28
            )
        }
        return Color.ppSurfaceBorder.opacity(
            colorSchemeContrast == .increased ? 1 : 0.86
        )
    }

    private var surfaceShadowColor: Color {
        if state.isCollapsed {
            return colorScheme == .dark
                ? Color.black.opacity(0.34)
                : Color.ppPrimary.opacity(0.24)
        }
        return colorScheme == .dark ? Color.black.opacity(0.30) : PPShadow.card.color
    }

    private var borderWidth: CGFloat {
        colorSchemeContrast == .increased ? 1.5 : 1
    }

    // MARK: - Transitions

    private var summaryTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .opacity.combined(with: .move(edge: isRightToLeft ? .trailing : .leading))
    }

    private var actionTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .scale(scale: 0.88, anchor: isRightToLeft ? .leading : .trailing)
                .combined(with: .opacity)
    }
}

private struct PPCartFloatingBarPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                reduceMotion || !configuration.isPressed || !isEnabled ? 1 : 0.98
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.90 : 1) : 0.46)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}
