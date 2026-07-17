import SwiftUI

public struct PPLayoutConfiguration: Equatable, Sendable {
    public var horizontalPadding: CGFloat
    public var verticalPadding: CGFloat
    public var horizontalSpacing: CGFloat
    public var verticalSpacing: CGFloat
    public var minimumGridColumnWidth: CGFloat
    public var maximumGridColumns: Int
    public var phoneMasonryColumns: Int
    public var padMasonryColumns: Int
    public var carouselWidthFraction: CGFloat
    public var carouselHeight: CGFloat
    public var cardCornerRadius: CGFloat
    public var respectsSafeArea: Bool

    public init(
        horizontalPadding: CGFloat = 16,
        verticalPadding: CGFloat = 16,
        horizontalSpacing: CGFloat = 14,
        verticalSpacing: CGFloat = 14,
        minimumGridColumnWidth: CGFloat = 166,
        maximumGridColumns: Int = 4,
        phoneMasonryColumns: Int = 2,
        padMasonryColumns: Int = 3,
        carouselWidthFraction: CGFloat = 0.88,
        carouselHeight: CGFloat = 220,
        cardCornerRadius: CGFloat = 22,
        respectsSafeArea: Bool = true
    ) {
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.minimumGridColumnWidth = minimumGridColumnWidth
        self.maximumGridColumns = max(1, maximumGridColumns)
        self.phoneMasonryColumns = max(1, phoneMasonryColumns)
        self.padMasonryColumns = max(1, padMasonryColumns)
        self.carouselWidthFraction = min(max(carouselWidthFraction, 0.5), 1)
        self.carouselHeight = max(1, carouselHeight)
        self.cardCornerRadius = max(0, cardCornerRadius)
        self.respectsSafeArea = respectsSafeArea
    }

    public static let premium = PPLayoutConfiguration()
}
