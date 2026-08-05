#if canImport(SwiftUI) && canImport(UIKit)
import Foundation
import SwiftUI
import UIKit
import PPChatCellCore

extension PPExpandableChatCell {
    // MARK: - Surface

    var surfaceShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
    }

    @ViewBuilder
    var surfaceBackground: some View {
        if isExpanded && !reduceTransparency {
            surfaceShape
                .fill(.thinMaterial)
                .background {
                    surfaceShape
                        .fill(style.opaqueSurface.opacity(colorScheme == .dark ? 0.80 : 0.88))
                }
        } else {
            surfaceShape.fill(style.opaqueSurface)
        }
    }

    var surfaceBorder: some View {
        surfaceShape.stroke(
            isExpanded || effectiveUnreadCount > 0
            ? style.brand.opacity(colorSchemeContrast == .increased ? 0.52 : 0.23)
            : style.separator.opacity(borderOpacity),
            lineWidth: borderWidth
        )
    }

}
#endif
