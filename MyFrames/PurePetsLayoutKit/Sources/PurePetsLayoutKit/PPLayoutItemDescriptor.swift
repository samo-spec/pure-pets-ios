import CoreGraphics
import Foundation

/// Layout-only metadata. Business models remain outside this package.
/// `imageAspectRatio` is height / width, matching the existing Objective-C model convention.
public struct PPLayoutItemDescriptor: Identifiable, Hashable, Sendable {
    public let id: String
    public var imageAspectRatio: CGFloat?
    public var preferredAspectRatio: CGFloat?
    public var estimatedBodyHeight: CGFloat
    public var minimumCardHeight: CGFloat
    public var maximumCardHeight: CGFloat?
    public var titleLineCount: Int
    public var hasSubtitle: Bool
    public var hasBadge: Bool

    public init(
        id: String,
        imageAspectRatio: CGFloat? = nil,
        preferredAspectRatio: CGFloat? = nil,
        estimatedBodyHeight: CGFloat = 128,
        minimumCardHeight: CGFloat = 130,
        maximumCardHeight: CGFloat? = nil,
        titleLineCount: Int = 1,
        hasSubtitle: Bool = false,
        hasBadge: Bool = false
    ) {
        self.id = id
        self.imageAspectRatio = imageAspectRatio
        self.preferredAspectRatio = preferredAspectRatio
        self.estimatedBodyHeight = estimatedBodyHeight
        self.minimumCardHeight = minimumCardHeight
        self.maximumCardHeight = maximumCardHeight
        self.titleLineCount = titleLineCount
        self.hasSubtitle = hasSubtitle
        self.hasBadge = hasBadge
    }

    /// Returns a finite positive ratio without forcing unrelated images into a narrow crop range.
    public var resolvedImageAspectRatio: CGFloat {
        for candidate in [imageAspectRatio, preferredAspectRatio] {
            if let candidate, candidate.isFinite, candidate > 0.02, candidate < 50 {
                return candidate
            }
        }
        return 1
    }

    public func estimatedHeight(for width: CGFloat, mode: PPLayoutMode) -> CGFloat {
        let safeWidth = max(width, 1)
        let imageHeight = safeWidth * resolvedImageAspectRatio
        let textExpansion = CGFloat(max(titleLineCount - 1, 0)) * 18
        let subtitleExpansion: CGFloat = hasSubtitle ? 18 : 0
        let badgeExpansion: CGFloat = hasBadge ? 34 : 0

        let proposed: CGFloat
        switch mode {
        case .horizontalRow:
            proposed = max(184, min(232, estimatedBodyHeight + 72))
        case .carousel:
            proposed = max(190, min(320, imageHeight + 72))
        case .mainKinds, .allKinds:
            proposed = max(118, min(220, imageHeight + 44))
        case .dataViewFullDetails:
            proposed = imageHeight + estimatedBodyHeight + textExpansion + subtitleExpansion + badgeExpansion + 32
        default:
            proposed = imageHeight + estimatedBodyHeight + textExpansion + subtitleExpansion + badgeExpansion
        }

        let minimumApplied = max(minimumCardHeight, proposed)
        if let maximumCardHeight, maximumCardHeight.isFinite, maximumCardHeight > 0 {
            return min(minimumApplied, maximumCardHeight)
        }
        return minimumApplied
    }
}
