#if canImport(SwiftUI) && canImport(UIKit)
import Foundation
import SwiftUI
import UIKit
import PPChatCellCore

extension PPExpandableChatCell {
    // MARK: - Surface

    var surfaceShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: isExpanded ? style.cornerRadius : style.collapsedCornerRadius,
            style: .continuous
        )
    }

    @ViewBuilder
    var surfaceBackground: some View {
        ZStack {
            // Always-opaque base — collapsed rows stay fully opaque per the
            // engineering guardrails, and this base guarantees the material
            // (when expanded) never lets the table background bleed through.
            surfaceShape.fill(style.opaqueSurface)

            if isExpanded {
                surfaceShape
                    .fill(
                        reduceTransparency
                        ? AnyShapeStyle(style.opaqueSurface)
                        : AnyShapeStyle(.thinMaterial)
                    )
                    .opacity(reduceTransparency ? 1 : colorScheme == .dark ? 0.82 : 0.92)
                    .transition(.opacity)

                // A faint brand wash from the leading edge gives the expanded
                // surface a sense of focus without tinting the whole card.
                if !reduceTransparency {
                    surfaceShape
                        .fill(
                            LinearGradient(
                                colors: [
                                    style.brand.opacity(colorScheme == .dark ? 0.10 : 0.06),
                                    style.brand.opacity(0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .center
                            )
                        )
                        .transition(.opacity)
                }
            }
        }
    }

    var surfaceBorder: some View {
        surfaceShape.stroke(
            isExpanded || effectiveUnreadCount > 0
            ? AnyShapeStyle(
                style.brand.opacity(colorSchemeContrast == .increased ? 0.72 : isExpanded ? 0.30 : 0.20)
              )
            : AnyShapeStyle(style.hairlineBorder(colorScheme, contrast: colorSchemeContrast)),
            lineWidth: borderWidth
        )
    }

    @ViewBuilder
    var conversationSignal: some View {
        if isExpanded || effectiveUnreadCount > 0 {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [style.brand, style.brand.opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: differentiateWithoutColor ? 5 : 3.5)
                .padding(.vertical, isExpanded ? 18 : 27)
                .scaleEffect(y: isExpanded ? 1 : 0.58, anchor: .center)
                .opacity(isExpanded ? 0.95 : 0.80)
                .accessibilityHidden(true)
                .transition(.opacity.combined(with: .scale(scale: 0.72, anchor: .center)))
        }
    }

}
#endif
