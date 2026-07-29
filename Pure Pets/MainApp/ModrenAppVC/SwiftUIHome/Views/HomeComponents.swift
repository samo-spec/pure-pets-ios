import SwiftUI
import UIKit

/// Home-scoped Beiruti typography that participates in Dynamic Type without
/// changing typography behavior on unrelated legacy surfaces.
enum HomeFont {
    static func title1() -> Font {
        .custom("Beiruti-Bold", size: 28, relativeTo: .title)
    }

    static func title2() -> Font {
        .custom("Beiruti-Bold", size: 22, relativeTo: .title2)
    }

    static func headline() -> Font {
        .custom("Beiruti-Bold", size: 17, relativeTo: .headline)
    }

    static func callout() -> Font {
        .custom("Beiruti-Regular", size: 16, relativeTo: .callout)
    }

    static func subheadline() -> Font {
        .custom("Beiruti-Regular", size: 15, relativeTo: .subheadline)
    }

    static func footnote() -> Font {
        .custom("Beiruti-Regular", size: 13, relativeTo: .footnote)
    }

    static func caption1() -> Font {
        .custom("Beiruti-Regular", size: 12, relativeTo: .caption)
    }

    static func caption2() -> Font {
        .custom("Beiruti-Regular", size: 11, relativeTo: .caption2)
    }

    static func bold(_ size: CGFloat) -> Font {
        .custom(
            "Beiruti-Bold",
            size: size,
            relativeTo: relativeStyle(for: size)
        )
    }

    static func medium(_ size: CGFloat) -> Font {
        .custom(
            "Beiruti-Medium",
            size: size,
            relativeTo: relativeStyle(for: size)
        )
    }

    private static func relativeStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case ...11: return .caption2
        case ...12: return .caption
        case ...13: return .footnote
        case ...15: return .subheadline
        case ...17: return .body
        case ...20: return .title3
        default: return .title2
        }
    }
}

struct HomeCommandBar: View {
    let state: HomeViewState
    let searchAction: () -> Void
    let cartAction: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: PPSpace.sm) {
            searchButton
            cartButton
        }
        .padding(.horizontal, PPSpace.screenMargin)
        .padding(.vertical, PPSpace.sm)
        .background(alignment: .bottom) {
            HomeTopFadeBackdrop(contrast: contrast)
                .frame(height: 168)
                .ignoresSafeArea(edges: .top)
        }
        .environment(
            \.layoutDirection,
            state.isRightToLeft ? .rightToLeft : .leftToRight
        )
    }

    private var searchButton: some View {
        Button(action: searchAction) {
            HStack(spacing: PPSpace.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.ppPrimary)
                Text(
                    HomeModelAdapter.localized(
                        "home_pulse_search_prompt",
                        fallback: "Search products, pets, and services"
                    )
                )
                .font(HomeFont.callout())
                .foregroundStyle(Color.ppTextSecondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, PPSpace.md)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
                Color.ppSurface.opacity(contrast == .increased ? 1 : 0.86),
                in: Capsule()
            )
            .overlay {
                Capsule().stroke(
                    contrast == .increased
                        ? Color.ppTextPrimary.opacity(0.62)
                        : Color.ppBorder,
                    lineWidth: contrast == .increased ? 1.4 : 0.7
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            HomeModelAdapter.localized(
                "home_pulse_search_a11y",
                fallback: "Search Pure Pets"
            )
        )
    }

    private var cartButton: some View {
        Button(action: cartAction) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "cart.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.ppTextPrimary)
                    .frame(width: 48, height: 48)
                    .background(Color.ppSurface.opacity(0.9), in: Circle())
                    .overlay(Circle().stroke(Color.ppBorder, lineWidth: 0.7))

                if state.cartCount > 0 {
                    Text(state.cartCount > 99 ? "99+" : "\(state.cartCount)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, state.cartCount > 9 ? 5 : 0)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(Color.ppPrimary, in: Capsule())
                        .overlay(Capsule().stroke(Color.ppSurface, lineWidth: 2))
                        .offset(x: 3, y: -3)
                }
            }
            .frame(width: 52, height: 52)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            HomeModelAdapter.localized(
                "home_pulse_cart_a11y",
                fallback: "Cart"
            )
        )
        .accessibilityValue(
            String(
                format: HomeModelAdapter.localized(
                    "home_pulse_cart_count_a11y",
                    fallback: "%d items"
                ),
                state.cartCount
            )
        )
    }
}

private struct HomeTopFadeBackdrop: View {
    let contrast: ColorSchemeContrast

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            LinearGradient(
                stops: [
                    .init(
                        color: Color.ppBackground.opacity(
                            contrast == .increased ? 0.96 : 0.78
                        ),
                        location: 0
                    ),
                    .init(
                        color: Color.ppBackground.opacity(
                            contrast == .increased ? 0.82 : 0.42
                        ),
                        location: 0.70
                    ),
                    .init(color: Color.clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.82),
                    .init(color: .black.opacity(0.76), location: 0.92),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct HomeLocationContextButton: View {
    let state: HomeViewState
    let action: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Button(action: action) {
            HStack(spacing: PPSpace.sm) {
                Image(systemName: locationSymbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.ppPrimary)
                    .frame(width: 32, height: 32)
                    .background(Color.ppPrimary.opacity(0.10), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(
                        HomeModelAdapter.localized(
                            "home_pulse_location_label",
                            fallback: "Area"
                        )
                    )
                    .font(HomeFont.caption2())
                    .foregroundStyle(Color.ppTextSecondary)

                    Text(locationTitle)
                        .font(HomeFont.medium(14))
                        .foregroundStyle(Color.ppTextPrimary)
                        .lineLimit(2)
                }

                Image(systemName: "chevron.forward")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.ppTextSecondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, PPSpace.sm)
            .padding(.vertical, PPSpace.xs)
            .frame(minHeight: 48)
            .background(
                Color.ppSurface.opacity(contrast == .increased ? 1 : 0.82),
                in: Capsule()
            )
            .overlay {
                Capsule().stroke(
                    contrast == .increased
                        ? Color.ppTextPrimary.opacity(0.62)
                        : Color.ppBorder,
                    lineWidth: contrast == .increased ? 1.4 : 0.7
                )
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            [
                HomeModelAdapter.localized(
                    "home_pulse_location_label",
                    fallback: "Area"
                ),
                locationTitle,
            ].joined(separator: ", ")
        )
        .environment(
            \.layoutDirection,
            state.isRightToLeft ? .rightToLeft : .leftToRight
        )
    }

    private var locationTitle: String {
        if !state.location.areaName.isEmpty {
            return state.location.areaName
        }
        switch state.location.presentation {
        case .loading:
            return HomeModelAdapter.localized(
                "home_pulse_location_loading",
                fallback: "Locating…"
            )
        case .denied, .restricted:
            return HomeModelAdapter.localized(
                "home_pulse_location_denied",
                fallback: "Choose manually"
            )
        case .failed:
            return HomeModelAdapter.localized(
                "home_pulse_location_failed",
                fallback: "Location unavailable"
            )
        case .notDetermined, .ready:
            return HomeModelAdapter.localized(
                "home_pulse_choose_area",
                fallback: "Choose area"
            )
        }
    }

    private var locationSymbol: String {
        switch state.location.presentation {
        case .loading: return "location.circle"
        case .denied, .restricted: return "location.slash.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .notDetermined, .ready:
            return state.location.isManual ? "mappin.circle.fill" : "location.fill"
        }
    }
}

struct HomePetSwitcher: View {
    let pets: [HomePetModel]
    let selectedID: String?
    let onSelect: (HomePetModel) -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            HomeSectionHeader(
                title: HomeModelAdapter.localized(
                    "home_pulse_pet_context_title",
                    fallback: "Your pet context"
                ),
                subtitle: HomeModelAdapter.localized(
                    "home_pulse_pet_context_subtitle",
                    fallback: "Home priorities follow the selected pet"
                ),
                actionTitle: HomeModelAdapter.localized(
                    "Edit",
                    fallback: "Edit"
                ),
                action: onEdit
            )
            .padding(.horizontal, PPSpace.screenMargin)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: PPSpace.sm) {
                    ForEach(pets) { pet in
                        HomePetIdentityPill(
                            pet: pet,
                            selected: pet.id == selectedID,
                            onSelect: {
                                onSelect(pet)
                            }
                        )
                    }
                }
                .padding(.horizontal, PPSpace.screenMargin)
            }
            .contentMarginsCompat()
        }
    }
}

private struct HomePetIdentityPill: View {
    let pet: HomePetModel
    let selected: Bool
    let onSelect: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: PPSpace.md) {
                portrait

                VStack(alignment: .leading, spacing: PPSpace.xxs) {
                    Text(displayName)
                        .font(HomeFont.headline())
                        .foregroundStyle(Color.ppTextPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(
                            dynamicTypeSize.isAccessibilitySize ? 3 : 1
                        )

                    if let petContext {
                        Text(petContext)
                            .font(HomeFont.footnote())
                            .foregroundStyle(Color.ppTextSecondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(
                                dynamicTypeSize.isAccessibilitySize ? 2 : 1
                            )
                    }
                }
                .layoutPriority(1)
            }
            .padding(.leading, PPSpace.sm)
            .padding(.trailing, PPSpace.base)
            .padding(.vertical, PPSpace.sm)
            .frame(
                minWidth: minimumWidth,
                maxWidth: maximumWidth,
                minHeight: minimumHeight,
                alignment: .leading
            )
            .background(surfaceShape.fill(surfaceColor))
            .overlay {
                surfaceShape.stroke(borderColor, lineWidth: borderWidth)
            }
            .overlay {
                if isFocused {
                    surfaceShape
                        .stroke(
                            Color.ppPrimary,
                            lineWidth: contrast == .increased ? 3 : 2.5
                        )
                }
            }
            .contentShape(surfaceShape)
        }
        .buttonStyle(HomePetIdentityPressStyle())
        .focused($isFocused)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .animation(selectionAnimation, value: selected)
    }

    private var portrait: some View {
        HomePetPortraitImage(
            petID: pet.id,
            imageURL: pet.imageURL
        )
        .equatable()
        .frame(width: portraitDiameter, height: portraitDiameter)
        .clipShape(Circle())
        .overlay {
            Circle().stroke(Color.ppSurface, lineWidth: 2)
        }
        .padding(PPSpace.xs)
        .background(
            selected ? Color.ppSurface : Color.ppSecondarySurface,
            in: Circle()
        )
        .overlay {
            Circle().stroke(
                selected ? Color.ppPrimary : Color.ppBorder,
                lineWidth: selected
                    ? (contrast == .increased ? 3 : 2)
                    : (contrast == .increased ? 2 : 1)
            )
        }
        .overlay(alignment: .bottomTrailing) {
            if selected {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 22, height: 22)
                    .background(Color.ppPrimary, in: Circle())
                    .overlay {
                        Circle().stroke(Color.ppSurface, lineWidth: 2)
                    }
                    .transition(selectionSealTransition)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityHidden(true)
    }

    private var displayName: String {
        let name = pet.name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !name.isEmpty else {
            return HomeModelAdapter.localized(
                "pet_name_placeholder",
                fallback: "Pet name"
            )
        }
        return name
    }

    private var petContext: String? {
        let context = pet.breedOrCategory.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return context.isEmpty ? nil : context
    }

    private var accessibilityLabel: String {
        [displayName, petContext]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    private var portraitDiameter: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 60 : 56
    }

    private var minimumWidth: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 204 : 164
    }

    private var maximumWidth: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 320 : 276
    }

    private var minimumHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 84 : 76
    }

    private var surfaceShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: PPCorner.large,
            style: .continuous
        )
    }

    private var surfaceColor: Color {
        selected ? Color.ppSoftRose : Color.ppSurface
    }

    private var borderColor: Color {
        if selected {
            return Color.ppPrimary
        }
        return contrast == .increased
            ? Color.ppTextPrimary.opacity(0.72)
            : Color.ppBorder
    }

    private var borderWidth: CGFloat {
        if selected {
            return contrast == .increased ? 2 : 1.4
        }
        return contrast == .increased ? 1.4 : 0.7
    }

    private var selectionAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.16)
            : .spring(
                response: 0.38,
                dampingFraction: 0.88,
                blendDuration: 0.08
            )
    }

    private var selectionSealTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .scale(scale: 0.86).combined(with: .opacity)
    }
}

private struct HomePetPortraitImage: View, Equatable {
    let petID: String
    let imageURL: String?

    private static let placeholder = UIImage(named: "petcare_placeholder")

    static func == (
        lhs: HomePetPortraitImage,
        rhs: HomePetPortraitImage
    ) -> Bool {
        lhs.petID == rhs.petID && lhs.imageURL == rhs.imageURL
    }

    var body: some View {
        HomeRemoteImage(
            urlString: imageURL,
            placeholder: Self.placeholder,
            contentMode: .scaleAspectFill
        )
    }
}

private struct HomePetIdentityPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(
                isEnabled
                    ? (configuration.isPressed ? 0.82 : 1)
                    : 0.48
            )
            .scaleEffect(
                reduceMotion || !isEnabled
                    ? 1
                    : (configuration.isPressed ? 0.975 : 1)
            )
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.08)
                    : .easeOut(
                        duration: configuration.isPressed ? 0.08 : 0.16
                    ),
                value: configuration.isPressed
            )
    }
}

struct HomePriorityGrid: View {
    let actions: [HomePriorityAction]
    let onSelect: (HomePriorityAction) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible(), spacing: PPSpace.sm)]
        }
        return [
            GridItem(.flexible(), spacing: PPSpace.sm),
            GridItem(.flexible(), spacing: PPSpace.sm),
            GridItem(.flexible(), spacing: PPSpace.sm),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            Text(
                HomeModelAdapter.localized(
                    "home_pulse_priority_title",
                    fallback: "Your next step"
                )
            )
            .font(HomeFont.title2())
            .foregroundStyle(Color.ppTextPrimary)
            .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: columns, spacing: PPSpace.sm) {
                ForEach(actions) { action in
                    Button {
                        onSelect(action)
                    } label: {
                        if dynamicTypeSize.isAccessibilitySize {
                            HStack(spacing: PPSpace.md) {
                                actionIcon(action)
                                actionCopy(action)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.forward")
                                    .foregroundStyle(Color.ppTextTertiary)
                                    .flipsForRightToLeftLayoutDirection(true)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: PPSpace.sm) {
                                actionIcon(action)
                                actionCopy(action)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .buttonStyle(HomePriorityPressStyle())
                }
            }
        }
    }

    private func actionIcon(_ action: HomePriorityAction) -> some View {
        Image(systemName: action.systemImage)
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(Color(uiColor: action.accent))
            .frame(width: 42, height: 42)
            .background(
                Color(uiColor: action.accent).opacity(0.12),
                in: RoundedRectangle(
                    cornerRadius: PPCorner.small,
                    style: .continuous
                )
            )
            .accessibilityHidden(true)
    }

    private func actionCopy(_ action: HomePriorityAction) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            Text(action.title)
                .font(HomeFont.bold(15))
                .foregroundStyle(Color.ppTextPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
            Text(action.subtitle)
                .font(HomeFont.caption1())
                .foregroundStyle(Color.ppTextSecondary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HomePriorityPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(PPSpace.md)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .background(
                configuration.isPressed
                    ? Color.ppSecondarySurface
                    : Color.ppSurface,
                in: RoundedRectangle(
                    cornerRadius: PPCorner.medium,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: PPCorner.medium,
                    style: .continuous
                )
                .stroke(Color.ppBorder, lineWidth: 0.6)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct HomeCategoryRail: View {
    let categories: [HomeCategoryModel]
    let selectedID: Int?
    let onSelect: (HomeCategoryModel?) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HomeSectionHeader(
                title: HomeModelAdapter.localized(
                    "home_pulse_categories_title",
                    fallback: "Explore by pet"
                ),
                subtitle: HomeModelAdapter.localized(
                    "home_pulse_categories_subtitle",
                    fallback: "The selected species shapes relevant results"
                ),
                actionTitle: nil,
                action: nil
            )
            .padding(.horizontal, PPSpace.screenMargin)

            HomeMainKindsCollectionRepresentable(
                categories: categories,
                selectedID: selectedID,
                itemSize: itemSize,
                onSelect: onSelect
            )
            .frame(height: itemSize.height + PPSpace.sm)
        }
    }

    private var itemSize: CGSize {
        let width = UIScreen.main.bounds.width
        let accessibility = dynamicTypeSize.isAccessibilitySize
        if width >= 700 {
            return CGSize(
                width: accessibility ? 152 : 132,
                height: accessibility ? 174 : 146
            )
        }
        if width >= 430 {
            return CGSize(
                width: accessibility ? 126 : 108,
                height: accessibility ? 154 : 132
            )
        }
        if width < 375 {
            return CGSize(
                width: accessibility ? 120 : 104,
                height: accessibility ? 150 : 128
            )
        }
        return CGSize(
            width: accessibility ? 124 : 108,
            height: accessibility ? 152 : 132
        )
    }
}

private struct HomeMainKindsCollectionRepresentable: UIViewRepresentable {
    let categories: [HomeCategoryModel]
    let selectedID: Int?
    let itemSize: CGSize
    let onSelect: (HomeCategoryModel?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = PPSpace.md
        layout.minimumInteritemSpacing = PPSpace.md
        layout.sectionInset = UIEdgeInsets(
            top: PPSpace.xs,
            left: PPSpace.screenMargin,
            bottom: PPSpace.xs,
            right: PPSpace.screenMargin
        )

        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.decelerationRate = .fast
        collectionView.semanticContentAttribute =
            Language.semanticAttributeForCurrentLanguage()
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        collectionView.register(
            PPMainKindsCell.self,
            forCellWithReuseIdentifier: PPMainKindsCell.reuseIdentifier
        )
        return collectionView
    }

    func updateUIView(
        _ collectionView: UICollectionView,
        context: Context
    ) {
        context.coordinator.update(
            categories: categories,
            selectedID: selectedID,
            itemSize: itemSize,
            onSelect: onSelect,
            collectionView: collectionView
        )
    }

    final class Coordinator: NSObject, UICollectionViewDataSource,
        UICollectionViewDelegate
    {
        private static let loopCycleCount = 101

        private var categories: [HomeCategoryModel] = []
        private var selectedID: Int?
        private var onSelect: ((HomeCategoryModel?) -> Void)?
        private var itemSize: CGSize = .zero
        private var contentSignature = ""
        private var selectionSignature = Int.min
        private var positioningGeneration = 0
        private var hasEstablishedLoopPosition = false
        private weak var collectionView: UICollectionView?

        override init() {
            super.init()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(voiceOverStatusDidChange),
                name: UIAccessibility.voiceOverStatusDidChangeNotification,
                object: nil
            )
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        private var logicalItemCount: Int {
            categories.count + 1
        }

        private var usesInfiniteLoop: Bool {
            logicalItemCount > 1 && !UIAccessibility.isVoiceOverRunning
        }

        private var presentedItemCount: Int {
            guard usesInfiniteLoop else { return logicalItemCount }
            return logicalItemCount * Self.loopCycleCount
        }

        func update(
            categories: [HomeCategoryModel],
            selectedID: Int?,
            itemSize: CGSize,
            onSelect: @escaping (HomeCategoryModel?) -> Void,
            collectionView: UICollectionView
        ) {
            self.categories = categories
            self.selectedID = selectedID
            self.itemSize = itemSize
            self.onSelect = onSelect
            self.collectionView = collectionView

            if let layout =
                collectionView.collectionViewLayout
                    as? UICollectionViewFlowLayout,
               layout.itemSize != itemSize {
                layout.itemSize = itemSize
                layout.invalidateLayout()
            }
            updateEdgeInsets(in: collectionView)

            let nextContentSignature = [
                categories.map {
                    [
                        $0.id,
                        String(HomeModelAdapter.mainKindID($0.raw)),
                        $0.title,
                        $0.imageURL ?? "",
                    ].joined(separator: "|")
                }.joined(separator: ";"),
                "\(itemSize.width)x\(itemSize.height)",
                UIAccessibility.isVoiceOverRunning ? "voice-over" : "visual",
            ].joined(separator: "#")
            let nextSelectionSignature = selectedID ?? -1
            let contentChanged = nextContentSignature != contentSignature
            let selectionChanged =
                nextSelectionSignature != selectionSignature

            guard contentChanged || selectionChanged else { return }
            if contentChanged {
                hasEstablishedLoopPosition = false
            }
            contentSignature = nextContentSignature
            selectionSignature = nextSelectionSignature
            collectionView.reloadData()
            positionSelectedItem(in: collectionView)
        }

        func collectionView(
            _ collectionView: UICollectionView,
            numberOfItemsInSection section: Int
        ) -> Int {
            presentedItemCount
        }

        func collectionView(
            _ collectionView: UICollectionView,
            cellForItemAt indexPath: IndexPath
        ) -> UICollectionViewCell {
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: PPMainKindsCell.reuseIdentifier,
                for: indexPath
            ) as? PPMainKindsCell else {
                return UICollectionViewCell()
            }

            let logicalIndex = logicalIndex(for: indexPath.item)
            let isAll = logicalIndex == 0
            let category = isAll ? nil : categories[logicalIndex - 1]
            let categoryID = category.map {
                HomeModelAdapter.mainKindID($0.raw)
            }
            let selected = isAll
                ? selectedID == nil
                : categoryID == selectedID

            cell.configure(
                withMainKind: category?.raw,
                isAll: isAll,
                selected: selected,
                restoredSelectionAppearance: false
            )
            applySelectionScale(
                to: cell,
                selected: selected,
                animated: cell.window != nil
            )
            cell.onSelect = { [weak self, weak collectionView] _, selectedAll in
                guard let self, let collectionView else { return }
                self.centerItem(
                    at: indexPath,
                    in: collectionView,
                    animated: !UIAccessibility.isReduceMotionEnabled
                )
                self.onSelect?(selectedAll ? nil : category)
            }
            return cell
        }

        private func applySelectionScale(
            to cell: UICollectionViewCell,
            selected: Bool,
            animated: Bool
        ) {
            let targetTransform = selected
                ? CGAffineTransform(scaleX: 1.035, y: 1.035)
                : .identity
            cell.layer.zPosition = selected ? 1 : 0

            guard cell.transform != targetTransform else { return }
            guard animated, !UIAccessibility.isReduceMotionEnabled else {
                cell.transform = targetTransform
                return
            }

            UIView.animate(
                withDuration: 0.26,
                delay: 0,
                usingSpringWithDamping: 0.88,
                initialSpringVelocity: 0.12,
                options: [.allowUserInteraction, .beginFromCurrentState],
                animations: {
                    cell.transform = targetTransform
                }
            )
        }

        private func positionSelectedItem(
            in collectionView: UICollectionView
        ) {
            positioningGeneration += 1
            let generation = positioningGeneration
            let selectedLogicalIndex: Int
            if let selectedID,
               let categoryIndex = categories.firstIndex(where: {
                   HomeModelAdapter.mainKindID($0.raw) == selectedID
               }) {
                selectedLogicalIndex = categoryIndex + 1
            } else {
                selectedLogicalIndex = 0
            }

            DispatchQueue.main.async { [weak self, weak collectionView] in
                guard let self,
                      let collectionView,
                      generation == self.positioningGeneration
                else {
                    return
                }
                collectionView.layoutIfNeeded()
                let targetIndex = self.virtualIndex(
                    for: selectedLogicalIndex,
                    nearestToCurrentPositionIn: collectionView
                )
                guard collectionView.numberOfItems(inSection: 0)
                    > targetIndex else {
                    return
                }
                self.centerItem(
                    at: IndexPath(item: targetIndex, section: 0),
                    in: collectionView,
                    animated: false
                )
            }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            guard let collectionView = scrollView as? UICollectionView else {
                return
            }
            recenterLoopIfNeeded(in: collectionView)
        }

        func scrollViewDidEndDragging(
            _ scrollView: UIScrollView,
            willDecelerate decelerate: Bool
        ) {
            guard !decelerate,
                  let collectionView = scrollView as? UICollectionView else {
                return
            }
            recenterLoopIfNeeded(in: collectionView)
        }

        func scrollViewDidEndScrollingAnimation(
            _ scrollView: UIScrollView
        ) {
            guard let collectionView = scrollView as? UICollectionView else {
                return
            }
            recenterLoopIfNeeded(in: collectionView)
        }

        private func logicalIndex(for virtualIndex: Int) -> Int {
            guard logicalItemCount > 0 else { return 0 }
            return virtualIndex % logicalItemCount
        }

        private func virtualIndex(
            for logicalIndex: Int,
            nearestToCurrentPositionIn collectionView: UICollectionView
        ) -> Int {
            guard usesInfiniteLoop else { return logicalIndex }

            let middleCycleStart =
                (Self.loopCycleCount / 2) * logicalItemCount
            guard hasEstablishedLoopPosition,
                  let centeredIndex = centeredVirtualIndex(
                    in: collectionView
                  ) else {
                return middleCycleStart + logicalIndex
            }

            let centeredLogicalIndex = self.logicalIndex(
                for: centeredIndex
            )
            let forwardDistance =
                (logicalIndex - centeredLogicalIndex + logicalItemCount)
                % logicalItemCount
            let backwardDistance = forwardDistance - logicalItemCount
            let shortestDistance =
                abs(forwardDistance) <= abs(backwardDistance)
                ? forwardDistance
                : backwardDistance
            let nearestIndex = centeredIndex + shortestDistance

            guard nearestIndex >= 0,
                  nearestIndex < presentedItemCount else {
                return middleCycleStart + logicalIndex
            }
            return nearestIndex
        }

        private func centeredVirtualIndex(
            in collectionView: UICollectionView
        ) -> Int? {
            let visibleCenter = CGPoint(
                x: collectionView.contentOffset.x
                    + collectionView.bounds.width / 2,
                y: collectionView.contentOffset.y
                    + collectionView.bounds.height / 2
            )
            if let exact = collectionView.indexPathForItem(
                at: visibleCenter
            ) {
                return exact.item
            }

            return collectionView.indexPathsForVisibleItems.min {
                let lhsCenter = collectionView.layoutAttributesForItem(
                    at: $0
                )?.center.x ?? .greatestFiniteMagnitude
                let rhsCenter = collectionView.layoutAttributesForItem(
                    at: $1
                )?.center.x ?? .greatestFiniteMagnitude
                return abs(lhsCenter - visibleCenter.x)
                    < abs(rhsCenter - visibleCenter.x)
            }?.item
        }

        private func centerItem(
            at indexPath: IndexPath,
            in collectionView: UICollectionView,
            animated: Bool
        ) {
            guard indexPath.item >= 0,
                  indexPath.item
                    < collectionView.numberOfItems(inSection: 0) else {
                return
            }
            hasEstablishedLoopPosition = true
            collectionView.scrollToItem(
                at: indexPath,
                at: .centeredHorizontally,
                animated: animated
            )
        }

        private func recenterLoopIfNeeded(
            in collectionView: UICollectionView
        ) {
            guard usesInfiniteLoop,
                  let centeredIndex = centeredVirtualIndex(
                    in: collectionView
                  ) else {
                return
            }

            let edgeBuffer = logicalItemCount * 10
            guard centeredIndex < edgeBuffer
                    || centeredIndex
                        >= presentedItemCount - edgeBuffer else {
                return
            }

            let middleIndex =
                (Self.loopCycleCount / 2) * logicalItemCount
                + logicalIndex(for: centeredIndex)
            let sourceIndexPath = IndexPath(
                item: centeredIndex,
                section: 0
            )
            let targetIndexPath = IndexPath(
                item: middleIndex,
                section: 0
            )
            collectionView.layoutIfNeeded()
            guard let sourceAttributes =
                    collectionView.layoutAttributesForItem(
                        at: sourceIndexPath
                    ),
                  let targetAttributes =
                    collectionView.layoutAttributesForItem(
                        at: targetIndexPath
                    ) else {
                centerItem(
                    at: targetIndexPath,
                    in: collectionView,
                    animated: false
                )
                return
            }

            var offset = collectionView.contentOffset
            offset.x +=
                targetAttributes.center.x - sourceAttributes.center.x
            collectionView.setContentOffset(offset, animated: false)
            hasEstablishedLoopPosition = true
        }

        private func updateEdgeInsets(
            in collectionView: UICollectionView
        ) {
            guard let layout =
                    collectionView.collectionViewLayout
                        as? UICollectionViewFlowLayout else {
                return
            }
            let finiteCenterInset = max(
                PPSpace.screenMargin,
                (collectionView.bounds.width - itemSize.width) / 2
            )
            let horizontalInset = usesInfiniteLoop
                ? PPSpace.screenMargin
                : finiteCenterInset
            let nextInsets = UIEdgeInsets(
                top: PPSpace.xs,
                left: horizontalInset,
                bottom: PPSpace.xs,
                right: horizontalInset
            )
            guard layout.sectionInset != nextInsets else { return }
            layout.sectionInset = nextInsets
            layout.invalidateLayout()
        }

        @objc
        private func voiceOverStatusDidChange() {
            guard let collectionView else { return }
            hasEstablishedLoopPosition = false
            contentSignature = ""
            updateEdgeInsets(in: collectionView)
            collectionView.reloadData()
            positionSelectedItem(in: collectionView)
        }
    }
}

struct HomeOrderCard: View {
    let order: HomeOrderModel
    let onTap: () -> Void
    let onSeeAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HomeSectionHeader(
                title: HomeModelAdapter.localized(
                    "home_pulse_current_order_title",
                    fallback: "Current order"
                ),
                subtitle: order.reference,
                actionTitle: HomeModelAdapter.localized(
                    "home_pulse_orders",
                    fallback: "Orders"
                ),
                action: onSeeAll
            )

            Button(action: onTap) {
                HStack(spacing: PPSpace.md) {
                    ZStack {
                        RoundedRectangle(
                            cornerRadius: PPCorner.medium,
                            style: .continuous
                        )
                        .fill(Color.ppSoftRose)
                        Image(systemName: order.symbol)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color.ppPrimary)
                    }
                    .frame(width: 58, height: 58)

                    VStack(alignment: .leading, spacing: PPSpace.xs) {
                        Text(order.statusTitle)
                            .font(HomeFont.headline())
                            .foregroundStyle(Color.ppTextPrimary)
                        Text(order.statusHint)
                            .font(HomeFont.footnote())
                            .foregroundStyle(Color.ppTextSecondary)
                            .lineLimit(2)
                        ProgressView(value: order.progress)
                            .tint(Color.ppPrimary)
                            .accessibilityLabel(order.statusTitle)
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: PPSpace.xs) {
                        if !order.amount.isEmpty {
                            Text(order.amount)
                                .font(HomeFont.bold(15))
                                .foregroundStyle(Color.ppTextPrimary)
                        }
                        Text(
                            String(
                                format: HomeModelAdapter.localized(
                                    "home_pulse_order_items",
                                    fallback: "%d items"
                                ),
                                order.itemCount
                            )
                        )
                        .font(HomeFont.caption1())
                        .foregroundStyle(Color.ppTextSecondary)
                        Image(systemName: "chevron.forward")
                            .foregroundStyle(Color.ppPrimary)
                            .flipsForRightToLeftLayoutDirection(true)
                    }
                }
                .padding(PPSpace.base)
                .background(Color.ppSurface)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: PPCorner.card,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: PPCorner.card,
                        style: .continuous
                    )
                    .stroke(Color.ppBorder, lineWidth: 0.7)
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint(
                HomeModelAdapter.localized(
                    "home_pulse_order_details_a11y",
                    fallback: "Opens order details"
                )
            )
        }
    }
}

struct HomeFeedSection: View {
    let section: HomeSectionModel
    let store: HomeStore

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let thirdCardPeekFraction: CGFloat = 0.12

    private var cardRailHeight: CGFloat {
        328 + (PPSpace.xs * 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HomeSectionHeader(
                title: section.title,
                subtitle: section.subtitle,
                actionTitle: section.seeAllTitle,
                action: section.seeAllTitle == nil
                    ? nil
                    : { store.seeAll(section.id) }
            )
            .padding(.horizontal, PPSpace.screenMargin)

            switch section.state {
            case .loading:
                GeometryReader { geometry in
                    HomeCardSkeletonRail(
                        cardWidth: cardWidth(
                            in: geometry.size.width,
                            itemCount: 4
                        )
                    )
                }
                .frame(height: cardRailHeight)
            case let .content(cards):
                GeometryReader { geometry in
                    let resolvedCardWidth = cardWidth(
                        in: geometry.size.width,
                        itemCount: cards.count
                    )
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: PPSpace.md) {
                            ForEach(cards) { card in
                                HomeUniversalCard(
                                    card: card,
                                    delegate: store.router.universalCardDelegate,
                                    onTap: { store.tapCard(card) },
                                    onQuantityChange: {
                                        store.setQuantity($0, for: card)
                                    }
                                )
                                .frame(width: resolvedCardWidth)
                            }
                        }
                        .padding(.leading, PPSpace.screenMargin)
                        .padding(.vertical, PPSpace.xs)
                    }
                    .contentMarginsCompat()
                }
                .frame(height: cardRailHeight)
            case let .empty(title, message, actionTitle):
                HomeInlineState(
                    symbol: "tray",
                    title: title,
                    message: message,
                    actionTitle: actionTitle,
                    action: actionTitle == nil
                        ? nil
                        : { store.seeAll(section.id) }
                )
                .padding(.horizontal, PPSpace.screenMargin)
            case let .failed(title, message, retryTitle):
                HomeInlineState(
                    symbol: "arrow.clockwise.circle",
                    title: title,
                    message: message,
                    actionTitle: retryTitle,
                    action: { store.retry(section: section.id) }
                )
                .padding(.horizontal, PPSpace.screenMargin)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func cardWidth(
        in viewportWidth: CGFloat,
        itemCount: Int
    ) -> CGFloat {
        // Reserve the semantic leading margin inside the scroll content so
        // every universal-card section starts aligned with its section title.
        // The opposite edge intentionally stays at zero inset.
        let availableWidth = max(
            0,
            viewportWidth - PPSpace.screenMargin
        )
        guard itemCount > 1 else { return availableWidth }

        let spacing = PPSpace.md
        let usesReadableSingleCard =
            dynamicTypeSize.isAccessibilitySize || viewportWidth < 350
        if usesReadableSingleCard {
            return max(
                0,
                (availableWidth - spacing)
                    / (1 + thirdCardPeekFraction)
            )
        }

        guard itemCount > 2 else {
            return max(0, (availableWidth - spacing) / 2)
        }

        // Leading margin + two complete cards + two gaps + 12% of the third.
        return max(
            0,
            (availableWidth - (spacing * 2))
                / (2 + thirdCardPeekFraction)
        )
    }
}

struct HomeSectionHeader: View {
    let title: String
    let subtitle: String?
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: PPSpace.md) {
            VStack(alignment: .leading, spacing: PPSpace.xs) {
                Text(title)
                    .font(HomeFont.title2())
                    .foregroundStyle(Color.ppTextPrimary)
                    .multilineTextAlignment(.leading)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(HomeFont.subheadline())
                        .foregroundStyle(Color.ppTextSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(HomeFont.bold(14))
                    .foregroundStyle(Color.ppPrimary)
                    .frame(minHeight: 44)
            }
        }
    }
}

struct HomeStatusBanner: View {
    let state: HomeViewState
    let retry: () -> Void

    var body: some View {
        if state.connectivity == .offline {
            banner(
                symbol: "wifi.slash",
                title: state.hasStaleContent
                    ? HomeModelAdapter.localized(
                        "home_pulse_offline_stale",
                        fallback: "Offline — showing saved content"
                    )
                    : HomeModelAdapter.localized(
                        "home_pulse_offline",
                        fallback: "You are offline"
                    ),
                tint: .ppWarning,
                actionTitle: HomeModelAdapter.localized(
                    "Retry",
                    fallback: "Retry"
                ),
                action: retry
            )
        } else if case .partial = state.phase {
            banner(
                symbol: "exclamationmark.circle",
                title: HomeModelAdapter.localized(
                    "home_pulse_partial",
                    fallback: "Some sections could not update"
                ),
                tint: .ppWarning,
                actionTitle: HomeModelAdapter.localized(
                    "Retry",
                    fallback: "Retry"
                ),
                action: retry
            )
        } else if case .refreshing = state.phase {
            banner(
                symbol: "arrow.clockwise",
                title: HomeModelAdapter.localized(
                    "home_pulse_refreshing",
                    fallback: "Refreshing Home"
                ),
                tint: .ppInfo,
                actionTitle: nil,
                action: nil
            )
        }
    }

    private func banner(
        symbol: String,
        title: String,
        tint: Color,
        actionTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        HStack(spacing: PPSpace.sm) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
            Text(title)
                .font(HomeFont.footnote())
                .foregroundStyle(Color.ppTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(HomeFont.bold(13))
                    .foregroundStyle(Color.ppPrimary)
                    .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, PPSpace.md)
        .background(tint.opacity(0.1), in: Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.28), lineWidth: 0.7))
    }
}

struct HomeInlineState: View {
    let symbol: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: PPSpace.sm) {
            Image(systemName: symbol)
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(Color.ppPrimary)
                .frame(width: 50, height: 50)
                .background(Color.ppSoftRose, in: Circle())
            Text(title)
                .font(HomeFont.headline())
                .foregroundStyle(Color.ppTextPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(HomeFont.subheadline())
                .foregroundStyle(Color.ppTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(HomeFont.bold(14))
                    .foregroundStyle(Color.white)
                    .frame(minHeight: 46)
                    .padding(.horizontal, PPSpace.base)
                    .background(Color.ppPrimary, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(PPSpace.lg)
        .background(Color.ppSurface)
        .clipShape(
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .stroke(Color.ppBorder, lineWidth: 0.7)
        }
    }
}

private struct HomeCardSkeletonRail: View {
    private static let skeletonIDs = [
        "home-card-skeleton-1",
        "home-card-skeleton-2",
        "home-card-skeleton-3",
        "home-card-skeleton-4",
    ]

    let cardWidth: CGFloat

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: PPSpace.md) {
                ForEach(Self.skeletonIDs, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: PPSpace.sm) {
                        RoundedRectangle(cornerRadius: PPCorner.medium)
                            .fill(Color.ppSeparator.opacity(0.7))
                            .frame(height: 166)
                        Capsule().fill(Color.ppSeparator).frame(height: 16)
                        Capsule()
                            .fill(Color.ppSeparator)
                            .frame(width: 100, height: 13)
                        Spacer()
                        Capsule().fill(Color.ppSoftRose).frame(height: 46)
                    }
                    .padding(PPSpace.sm)
                    .frame(width: cardWidth, height: 328)
                    .background(Color.ppSurface)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: PPCorner.card,
                            style: .continuous
                        )
                    )
                    .accessibilityHidden(true)
                }
            }
            .padding(.leading, PPSpace.screenMargin)
            .padding(.vertical, PPSpace.xs)
        }
        .contentMarginsCompat()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            HomeModelAdapter.localized(
                "home_pulse_section_loading",
                fallback: "Loading section"
            )
        )
    }
}

struct HomeRemoteImage: UIViewRepresentable {
    let urlString: String?
    let placeholder: UIImage?
    let contentMode: UIView.ContentMode

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.clipsToBounds = true
        imageView.backgroundColor = UIColor.ppSecondarySurface
        imageView.isAccessibilityElement = false
        return imageView
    }

    func updateUIView(_ imageView: UIImageView, context: Context) {
        imageView.contentMode = contentMode
        PPImageLoaderManager.shared().setImage(
            on: imageView,
            url: urlString,
            placeholder: placeholder,
            transitionStyle: .fade,
            completion: nil
        )
    }

    static func dismantleUIView(
        _ imageView: UIImageView,
        coordinator: Void
    ) {
        PPImageLoaderManager.shared().cancelImageLoad(for: imageView)
    }
}

private extension View {
    @ViewBuilder
    func contentMarginsCompat() -> some View {
        if #available(iOS 17.0, *) {
            self.contentMargins(.horizontal, 0, for: .scrollContent)
        } else {
            self
        }
    }
}
