import SwiftUI

public struct PPLayoutContainer<Item: Identifiable, Card: View>: View {
    private let items: [Item]
    private let mode: PPLayoutMode
    private let state: PPCollectionState
    private let configuration: PPLayoutConfiguration
    private let descriptor: (Item) -> PPLayoutItemDescriptor
    private let retry: (() -> Void)?
    private let card: (Item) -> Card

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        items: [Item],
        mode: PPLayoutMode,
        state: PPCollectionState = .content,
        configuration: PPLayoutConfiguration = .premium,
        descriptor: @escaping (Item) -> PPLayoutItemDescriptor,
        retry: (() -> Void)? = nil,
        @ViewBuilder card: @escaping (Item) -> Card
    ) {
        self.items = items
        self.mode = mode
        self.state = state
        self.configuration = configuration
        self.descriptor = descriptor
        self.retry = retry
        self.card = card
    }

    public var body: some View {
        Group {
            if state == .content {
                content
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.995)))
            } else {
                PPCollectionStateView(state: state, retry: retry)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.88), value: mode.rawValue)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: state)
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .carousel:
            carousel
        case .pinterest:
            masonry
        case .vertical, .market, .mainKinds, .allKinds:
            grid
        case .none, .fullWidth, .horizontalRow, .dataViewFullDetails:
            list
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: configuration.verticalSpacing) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    card(item)
                        .accessibilitySortPriority(Double(items.count - index))
                }
            }
            .padding(.horizontal, configuration.horizontalPadding)
            .padding(.vertical, configuration.verticalPadding)
        }
        .ppKeyboardDismissBehavior()
    }

    private var grid: some View {
        let columns = [
            GridItem(
                .adaptive(
                    minimum: scaledMinimumColumnWidth,
                    maximum: scaledMinimumColumnWidth * 1.45
                ),
                spacing: configuration.horizontalSpacing,
                alignment: .top
            )
        ]

        return ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: configuration.verticalSpacing) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    card(item)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .accessibilitySortPriority(Double(items.count - index))
                }
            }
            .padding(.horizontal, configuration.horizontalPadding)
            .padding(.vertical, configuration.verticalPadding)
        }
        .ppKeyboardDismissBehavior()
    }

    private var carousel: some View {
        GeometryReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: configuration.horizontalSpacing) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        card(item)
                            .frame(
                                width: max(1, proxy.size.width * configuration.carouselWidthFraction),
                                height: configuration.carouselHeight
                            )
                            .accessibilitySortPriority(Double(items.count - index))
                    }
                }
                .padding(.horizontal, configuration.horizontalPadding)
                .padding(.vertical, configuration.verticalPadding)
            }
        }
    }

    private var masonry: some View {
        GeometryReader { proxy in
            let count = masonryColumnCount(for: proxy.size.width)
            let usableWidth = max(
                1,
                proxy.size.width
                    - configuration.horizontalPadding * 2
                    - CGFloat(count - 1) * configuration.horizontalSpacing
            )
            let itemWidth = floor(usableWidth / CGFloat(count))
            let descriptors = items.map(descriptor)
            let partition = PPMasonryPartitioner.partition(
                descriptors: descriptors,
                columnCount: count,
                itemWidth: itemWidth,
                spacing: configuration.verticalSpacing
            )

            ScrollView {
                HStack(alignment: .top, spacing: configuration.horizontalSpacing) {
                    ForEach(0..<partition.columns.count, id: \.self) { columnIndex in
                        LazyVStack(spacing: configuration.verticalSpacing) {
                            ForEach(partition.columns[columnIndex], id: \.self) { itemIndex in
                                let item = items[itemIndex]
                                card(item)
                                    .frame(width: itemWidth, alignment: .top)
                                    .accessibilitySortPriority(Double(items.count - itemIndex))
                            }
                        }
                        .frame(width: itemWidth, alignment: .top)
                    }
                }
                .padding(.horizontal, configuration.horizontalPadding)
                .padding(.vertical, configuration.verticalPadding)
            }
            .ppKeyboardDismissBehavior()
        }
    }

    private var scaledMinimumColumnWidth: CGFloat {
        switch dynamicTypeSize {
        case .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5:
            return configuration.minimumGridColumnWidth * 1.34
        case .xxLarge, .xxxLarge:
            return configuration.minimumGridColumnWidth * 1.15
        default:
            return configuration.minimumGridColumnWidth
        }
    }

    private func masonryColumnCount(for width: CGFloat) -> Int {
        let preferred = horizontalSizeClass == .regular
            ? configuration.padMasonryColumns
            : configuration.phoneMasonryColumns
        let widthLimited = max(
            1,
            Int(floor((width - configuration.horizontalPadding * 2 + configuration.horizontalSpacing) /
                      (scaledMinimumColumnWidth + configuration.horizontalSpacing)))
        )
        return max(1, min(preferred, widthLimited))
    }
}
