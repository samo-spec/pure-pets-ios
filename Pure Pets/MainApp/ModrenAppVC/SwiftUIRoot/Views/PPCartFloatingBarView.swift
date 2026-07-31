//
//  PPCartFloatingBarView.swift
//  PurePetsSwiftUIRefactor
//
//  Created for PurePets Platform SwiftUI Root Architecture.
//  Redesigned (SwiftyMax Studio): single morphing capsule anchored on a
//  persistent cart well, a count-driven badge numeral moment, and a
//  brand-washed elevated surface in place of decorative glass.
//

import SwiftUI
import UIKit

/// Presentation-only floating cart control. `PPRootStore` remains responsible
/// for cart state, collapse timing (6s), haptics, and the cart route.
public struct PPCartFloatingBarView: View {
    public let state: PPCartFloatingBarState
    public let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.layoutDirection) private var layoutDirection

    private var primaryColor: Color {
        Color(
            uiColor: UIColor(named: "AppPrimaryColor") ?? UIColor(
                red: 227 / 255,
                green: 6 / 255,
                blue: 83 / 255,
                alpha: 1
            )
        )
    }

    private var surfaceShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: state.isCollapsed ? 14 : 22,
            style: .continuous
        )
    }

    private var stateAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.16)
            : .spring(response: 0.4, dampingFraction: 0.82)
    }

    private var isRightToLeft: Bool { layoutDirection == .rightToLeft }

    private var expandedMinHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 128 : 68
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
                if dynamicTypeSize.isAccessibilitySize && !state.isCollapsed {
                    expandedAccessibilityContent
                } else {
                    adaptiveContent
                }
            }
            .background { surface }
            .contentShape(surfaceShape)
        }
        .buttonStyle(PPCartFloatingBarPressStyle())
        .animation(stateAnimation, value: state.isCollapsed)
        .animation(
            reduceMotion ? .easeOut(duration: 0.16) : .easeOut(duration: 0.24),
            value: state.itemCount
        )
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

    /// Single adaptive layout: the cart well persists across collapse/expand so
    /// the summary and CTA morph around a stable anchor (signature moment #1).
    private var adaptiveContent: some View {
        HStack(spacing: state.isCollapsed ? 0 : 12) {
            cartWell

            if !state.isCollapsed {
                cartSummary
                    .transition(summaryTransition)
            }

            if !state.isCollapsed {
                Spacer(minLength: 8)
            }

            if !state.isCollapsed {
                checkoutAffordance
                    .transition(ctaTransition)
            }
        }
        .padding(.horizontal, state.isCollapsed ? 0 : 10)
        .frame(
            minWidth: state.isCollapsed ? 44 : nil,
            maxWidth: state.isCollapsed ? 44 : .infinity,
            minHeight: state.isCollapsed ? 44 : expandedMinHeight
        )
    }

    private var expandedAccessibilityContent: some View {
        VStack(
            alignment: isRightToLeft ? .trailing : .leading,
            spacing: 10
        ) {
            HStack(spacing: 12) {
                cartWell
                cartSummary
                Spacer(minLength: 0)
            }

            checkoutAffordance
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: expandedMinHeight)
    }

    private var cartGlyph: some View {
        Image(systemName: "cart.fill")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(primaryColor)
    }

    /// Brand-tinted cart well — the structural anchor that persists between the
    /// collapsed pill and the expanded bar. Carries the count badge. The well
    /// border is shown only when expanded, so the collapsed container's hairline
    /// frames the icon alone — matching the cart icon's size and corners.
    private var cartWell: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(primaryColor.opacity(colorScheme == .dark ? 0.20 : 0.10))
            if !state.isCollapsed {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        primaryColor.opacity(colorSchemeContrast == .increased ? 0.60 : 0.18),
                        lineWidth: colorSchemeContrast == .increased ? 1.5 : 1
                    )
            }
            cartGlyph
        }
        .frame(width: 44, height: 44)
        .overlay(alignment: isRightToLeft ? .topLeading : .topTrailing) {
            if !state.badgeText.isEmpty {
                countBadge
            }
        }
        .accessibilityHidden(true)
    }

    /// Count badge — signature moment #2: the numeral swaps on itemCount change.
    private var countBadge: some View {
        Text(state.badgeText)
            .id(state.itemCount)
            .font(.custom("Beiruti-Bold", size: 11, relativeTo: .caption2))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .frame(minWidth: 20, minHeight: 20)
            .background(primaryColor, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(
                        colorScheme == .dark ? Color(white: 0.12) : Color.white,
                        lineWidth: 2
                    )
            }
            .offset(x: isRightToLeft ? -6 : 6, y: -6)
            .transition(
                reduceMotion
                    ? .opacity
                    : .scale(scale: 0.6, anchor: .center).combined(with: .opacity)
            )
    }

    private var cartSummary: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(
                NSLocalizedString(
                    "Cart",
                    value: "Cart",
                    comment: "Floating cart title"
                )
            )
            .font(.custom("Beiruti-Bold", size: 16, relativeTo: .headline))
            .foregroundStyle(primaryTextColor)
            .lineLimit(1)

            Text(state.subtitleText)
                .font(.custom("Beiruti-Medium", size: 13, relativeTo: .subheadline))
                .foregroundStyle(secondaryTextColor)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(0.84)
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
        .accessibilityHidden(true)
    }

    private var checkoutAffordance: some View {
        HStack(spacing: 7) {
            Text(
                NSLocalizedString(
                    "checkout_review_cart_action",
                    value: "Review Cart",
                    comment: "Floating cart action"
                )
            )
            .font(.custom("Beiruti-Bold", size: 14, relativeTo: .callout))
            .lineLimit(1)
            .minimumScaleFactor(0.82)

            Image(
                systemName: isRightToLeft ? "chevron.forward" : "chevron.backward"
            )
            .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 13)
        .frame(minHeight: 42)
        .background(primaryColor, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Surface

    /// Controlled elevated surface — a brand-washed, near-opaque card with a
    /// hairline edge and elevated shadow. Replaces decorative glass for
    /// stronger RTL Arabic legibility and AX contrast.
    private var surface: some View {
        surfaceShape
            .fill(surfaceBaseGradient)
            .overlay {
                surfaceShape.fill(
                    primaryColor.opacity(
                        colorScheme == .dark
                            ? (state.isCollapsed ? 0.10 : 0.14)
                            : (state.isCollapsed ? 0.04 : 0.06)
                    )
                )
            }
            .overlay {
                surfaceShape.strokeBorder(
                    Color.white.opacity(
                        colorScheme == .dark
                            ? (state.isCollapsed ? 0.20 : 0.24)
                            : (state.isCollapsed ? 0.60 : 0.72)
                    ),
                    lineWidth: colorSchemeContrast == .increased ? 1.5 : 1
                )
            }
            .shadow(
                color: Color.black.opacity(
                    colorScheme == .dark
                        ? (state.isCollapsed ? 0.24 : 0.32)
                        : (state.isCollapsed ? 0.10 : 0.13)
                ),
                radius: state.isCollapsed ? 9 : 18,
                x: 0,
                y: state.isCollapsed ? 4 : 9
            )
    }

    private var surfaceBaseGradient: LinearGradient {
        let isDark = colorScheme == .dark
        return LinearGradient(
            colors: [
                isDark
                    ? Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255).opacity(0.94)
                    : Color.white.opacity(0.94),
                isDark
                    ? Color(red: 42 / 255, green: 20 / 255, blue: 23 / 255).opacity(0.94)
                    : Color(red: 1, green: 245 / 255, blue: 247 / 255).opacity(0.94)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color(white: 0.06)
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color(white: 0.80) : Color(white: 0.36)
    }

    // MARK: - Transitions

    private var summaryTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .opacity.combined(with: .move(edge: isRightToLeft ? .trailing : .leading))
    }

    private var ctaTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .scale(scale: 0.85, anchor: isRightToLeft ? .leading : .trailing)
                .combined(with: .opacity)
    }
}

private struct PPCartFloatingBarPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                reduceMotion || !configuration.isPressed || !isEnabled ? 1 : 0.975
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.88 : 1) : 0.46)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}
