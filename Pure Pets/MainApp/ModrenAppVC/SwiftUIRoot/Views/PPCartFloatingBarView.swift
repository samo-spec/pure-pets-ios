//
//  PPCartFloatingBarView.swift
//  PurePetsSwiftUIRefactor
//
//  Created for PurePets Platform SwiftUI Root Architecture.
//

import SwiftUI
import UIKit

/// Presentation-only floating cart control. `PPRootStore` remains responsible
/// for cart state, collapse timing, haptics, and the cart route.
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
            cornerRadius: state.isCollapsed ? 24 : 22,
            style: .continuous
        )
    }

    private var stateAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.16)
            : .spring(response: 0.38, dampingFraction: 0.86)
    }

    private var isRightToLeft: Bool {
        layoutDirection == .rightToLeft
    }

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
                if state.isCollapsed {
                    collapsedContent
                } else if dynamicTypeSize.isAccessibilitySize {
                    expandedAccessibilityContent
                } else {
                    expandedContent
                }
            }
            .background {
                surface
            }
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

    private var expandedContent: some View {
        HStack(spacing: 12) {
            cartMark

            cartSummary

            Spacer(minLength: 8)

            checkoutAffordance
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: expandedMinHeight)
    }

    private var expandedAccessibilityContent: some View {
        VStack(
            alignment: isRightToLeft ? .trailing : .leading,
            spacing: 10
        ) {
            HStack(spacing: 12) {
                cartMark
                cartSummary
                Spacer(minLength: 0)
            }

            checkoutAffordance
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: expandedMinHeight)
    }

    private var collapsedContent: some View {
        HStack(spacing: 0) {
            cartMark
        }
        .padding(6)
        .frame(width: 56, height: 56)
    }

    private var cartMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(primaryColor.opacity(colorScheme == .dark ? 0.22 : 0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            primaryColor.opacity(
                                colorSchemeContrast == .increased ? 0.68 : 0.22
                            ),
                            lineWidth: colorSchemeContrast == .increased ? 1.5 : 1
                        )
                }

            Image(systemName: "cart.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(primaryColor)
        }
        .frame(width: 44, height: 44)
        .overlay(alignment: isRightToLeft ? .topLeading : .topTrailing) {
            if !state.badgeText.isEmpty {
                Text(state.badgeText)
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
            }
        }
        .accessibilityHidden(true)
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
        .multilineTextAlignment(isRightToLeft ? .trailing : .leading)
        .frame(maxWidth: .infinity, alignment: isRightToLeft ? .trailing : .leading)
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
                systemName: isRightToLeft ? "chevron.backward" : "chevron.forward"
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

    private var surface: some View {
        surfaceShape
            .fill(.ultraThinMaterial)
            .overlay {
                surfaceShape.fill(primaryColor.opacity(colorScheme == .dark ? 0.13 : 0.055))
            }
            .overlay {
                surfaceShape.strokeBorder(
                    Color.white.opacity(colorScheme == .dark ? 0.24 : 0.70),
                    lineWidth: colorSchemeContrast == .increased ? 1.5 : 1
                )
            }
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.32 : 0.13),
                radius: state.isCollapsed ? 12 : 18,
                x: 0,
                y: state.isCollapsed ? 6 : 9
            )
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color(white: 0.08)
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color(white: 0.80) : Color(white: 0.39)
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
                reduceMotion
                    ? nil
                    : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}
