#if canImport(SwiftUI) && canImport(UIKit)
import Foundation
import SwiftUI
import UIKit
import PPChatCellCore

extension PPExpandableChatCell {
    // MARK: - Surface

    var surfaceShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: isExpanded ? style.cornerRadius : style.compactCornerRadius + 4,
            style: .continuous
        )
    }

    @ViewBuilder
    var surfaceBackground: some View {
        ZStack {
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
            }
        }
    }

    var surfaceBorder: some View {
        surfaceShape.stroke(
            isExpanded || effectiveUnreadCount > 0
            ? style.brand.opacity(colorSchemeContrast == .increased ? 0.72 : isExpanded ? 0.28 : 0.20)
            : style.separator.opacity(borderOpacity),
            lineWidth: borderWidth
        )
    }

    @ViewBuilder
    var conversationSignal: some View {
        if isExpanded || effectiveUnreadCount > 0 {
            Capsule()
                .fill(style.brand)
                .frame(width: differentiateWithoutColor ? 5 : 3.5)
                .padding(.vertical, isExpanded ? 18 : 27)
                .scaleEffect(y: isExpanded ? 1 : 0.58, anchor: .center)
                .opacity(isExpanded ? 0.92 : 0.78)
                .accessibilityHidden(true)
                .transition(.opacity.combined(with: .scale(scale: 0.72, anchor: .center)))
        }
    }

}
#endif
