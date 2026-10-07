import SwiftUI
import UIKit

// MARK: - Home Hero V2
//
// V1 remains preserved behind `PPHomeHeroFlags.UseHeroV2`. V2 re-composes the
// same page, artwork, and action contracts as a quiet companion introduction.
// Copy and animals share the first reading line; category browsing is separate.

/// Mirrors `homeHeroShowsSelectedMainKindArtwork` in V1: the marketplace hero
/// presents the selected main-kind portrait instead of the generic shop scene.
private let homeHeroV2ShowsSelectedMainKindArtwork = true

private enum HomeHeroV2Metrics {
    /// The reference hero is edge-to-edge; the living plate supplies the visual
    /// boundary instead of an additional horizontal card inset.
    static let outerInset: CGFloat = 0
    static let referenceStageHeight: CGFloat = 246
    static let stageHeight: CGFloat = 216
    static let dockHeight: CGFloat = 78
    static let height: CGFloat = 294
    static let maximumHeight: CGFloat = 326
    static let accessibilityPlateHeight: CGFloat = 184

    static let cardRadius: CGFloat = 0
    static let cardContentInset: CGFloat = PPSpace.base
    static let copyLeadingInset: CGFloat = PPSpace.xl
    /// Top anchor inset for the leading strings group, anchoring the eyebrow
    /// safely and cleanly below the hero card's top rounded border.
    static let copyTopInset: CGFloat = 18
    /// Vertical spacing rhythm within the leading strings group.
    static let copyEyebrowToTitleSpacing: CGFloat = 6
    static let copyTitleToSubtitleSpacing: CGFloat = 4
    static let copySubtitleToPrimarySpacing: CGFloat = 10
    static let copyPrimaryToSecondarySpacing: CGFloat = 6
    static let contentGap: CGFloat = PPSpace.sm
    static let copyWidthRatio: CGFloat = 0.45
    static let minimumCopyWidth: CGFloat = 150

    /// `PPHomeHeroLivingBlobShape` draws at 0.94 of its frame. The reference
    /// composition intentionally lets the plate travel beyond the physical
    /// leading/trailing edge while keeping the artwork fully inside the arc.
    static let blobInkRatio: CGFloat = 0.94
    static let plateInk: CGFloat = 226
    /// The living plate reads as a lens rather than a ball: its height is 15%
    /// shorter than its width. Only the membrane, halo, and their shared centre
    /// change — `plateInk` and `artworkSide` stay exactly as they were, so the
    /// category portrait keeps its established size and position.
    static let plateHeightRatio: CGFloat = 0.85
    static let artworkSide: CGFloat = 180
    static let artworkVerticalShift: CGFloat = 3
    /// Hero-specific category artwork grows downward while its established top
    /// edge, plate frame, and living-blob geometry remain unchanged.
    static let heroImageScale: CGFloat = 1.18
    /// Visual plate touches and sticks to the screen edge.
    static let plateHorizontalOverflow: CGFloat = 24
    static let maximumPlateOverflowRatio: CGFloat = 0.10
    static let skeletonPlateInk: CGFloat = 156
    /// Keeps the V2 liquid form branded without letting the primary hue compete
    /// with the category portrait or the full-strength primary CTA.
    static let blobAccentOpacity: Double = 0.72
    /// Vertical offset to position the living plate and category artwork stage
    /// as one unified group comfortably down inside the hero card.
    static let plateArtworkGroupVerticalOffset: CGFloat = 18

    /// Quiet edge affordance for horizontal paging.
    static let gripWidth: CGFloat = 14
    static let gripHeight: CGFloat = 42
    static let gripEdgeInset: CGFloat = PPSpace.sm
    static let gripBarWidth: CGFloat = 1.5
    static let gripBarHeight: CGFloat = 11
    static let gripBarSpacing: CGFloat = 2

    static let primaryHeight: CGFloat = 44
    static let primaryRadius: CGFloat = 14
    static let primaryHorizontalPadding: CGFloat = PPSpace.base
    static let primaryContentSpacing: CGFloat = PPSpace.sm

    static let secondaryHorizontalPadding: CGFloat = PPSpace.sm
    static let secondaryVerticalPadding: CGFloat = PPSpace.sm

    static let eyebrowSize: CGFloat = 10.5
    static let titleSize: CGFloat = 23
    static let primaryLabelSize: CGFloat = 14
    static let secondaryLabelSize: CGFloat = 12.5
}

@available(iOS 15.0, *)
private enum HomeHeroSpeciesDockMetrics {
    static func height(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        if dynamicTypeSize >= .accessibility3 { return 216 }
        if dynamicTypeSize.isAccessibilitySize { return 160 }
        if dynamicTypeSize >= .xxLarge { return 96 }
        return HomeHeroV2Metrics.dockHeight
    }


}

@available(iOS 15.0, *)
private struct HeroCopyHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 { value = next }
    }
}

@available(iOS 15.0, *)
struct HomeHeroV2View: View {
    let pages: [HomeHeroPage]
    let selectedIndex: Int
    var categories: [HomeCategoryModel] = []
    var selectedCategoryID: Int? = nil
    let onSelect: (Int) -> Void
    let onPrimaryAction: () -> Void
    let onSecondaryAction: () -> Void
    let onInteractionChanged: (Bool) -> Void
    var onSelectCategory: ((HomeCategoryModel?) -> Void)? = nil
    var embeddedInCompanionSurface = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.layoutDirection) private var layoutDirection

    private var selectedPage: HomeHeroPage? {
        guard pages.indices.contains(selectedIndex) else { return nil }
        return pages[selectedIndex]
    }

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRightToLeft: Bool { layoutDirection == .rightToLeft }
    private var allowsPaging: Bool { pages.count > 1 }
    @State private var availableWidth: CGFloat = 0

    private var usesStackedLayout: Bool {
        dynamicTypeSize.isAccessibilitySize || (availableWidth > 0 && availableWidth < 280)
    }

    private var artworkSide: CGFloat {
        let contentWidth = max(280, availableWidth) - PPSpace.base * 2
        return min(horizontalSizeClass == .regular ? 164 : 128, max(100, contentWidth * 0.34))
    }

    private var paletteTraits: UITraitCollection {
        UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light)
    }

    private func sourceAccent(_ page: HomeHeroPage) -> UIColor {
        // The hero owns its category identity independently of the optional
        // whole-app accent preference. Campaigns retain their authored color.
        let category = (page.kind == .marketplace || page.kind == .pet)
            ? categories.first { HomeModelAdapter.mainKindID($0.raw) == selectedCategoryID }
            : nil
        return HomeHeroV2Palette.sourceAccent(
            category?.accent ?? UIColor(Color(hex: page.accentHex)),
            traits: paletteTraits
        )
    }

    var body: some View {
        Group {
            if let page = selectedPage {
                hero(page)
            } else {
                HomeHeroV2Skeleton(height: 160)
                    .redacted(reason: .placeholder)
                    .accessibilityHidden(true)
            }
        }
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear { availableWidth = geometry.size.width }
                    .onChange(of: geometry.size.width) { width in availableWidth = width }
            }
        }
        .padding(.horizontal, embeddedInCompanionSurface ? 0 : HomeVisualTokens.contentHorizontalMargin)
        .accessibilityElement(children: .contain)
        .onDisappear { onInteractionChanged(false) }
    }

    /// Copy and its action share one column beside the animal. No independent
    /// footer or fixed card height can introduce an empty band below the copy.
    private func hero(_ page: HomeHeroPage) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            Group {
                if usesStackedLayout {
                    // Decorative artwork yields its space to readable content
                    // at accessibility sizes; no text is clipped or scaled down.
                    VStack(alignment: .leading, spacing: PPSpace.sm) {
                        heroCopy(page)
                        heroActions(page)
                    }
                } else {
                    HStack(alignment: .center, spacing: PPSpace.md) {
                        VStack(alignment: .leading, spacing: PPSpace.sm) {
                            heroCopy(page)
                            heroActions(page)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)
                        artwork(page)
                    }
                }
            }
            .id(page.id)
            .transition(.opacity)

            if allowsPaging {
                PPHomePageControl(count: pages.count, selectedIndex: selectedIndex)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, PPSpace.base)
        .padding(.vertical, PPSpace.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if !embeddedInCompanionSurface {
                heroShape.fill(Color.homeSurface)
            }
        }
        .overlay {
            if !embeddedInCompanionSurface {
                heroShape.strokeBorder(
                    HomeVisualTokens.cardBorder(colorScheme: colorScheme, contrast: contrast),
                    lineWidth: HomeVisualTokens.cardBorderWidth(contrast: contrast)
                )
                .allowsHitTesting(false)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: page.id)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: selectedCategoryID)
        .modifier(HomeHeroV2PagingGestureModifier(
            isEnabled: allowsPaging,
            selectedIndex: selectedIndex,
            pageCount: pages.count,
            layoutDirection: layoutDirection,
            onSelect: onSelect,
            onInteractionChanged: onInteractionChanged
        ))
        .modifier(HomeHeroV2PagingAccessibilityModifier(
            isEnabled: allowsPaging,
            selectedIndex: selectedIndex,
            pageCount: pages.count,
            onSelect: onSelect
        ))
    }

    private var heroShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: HomeVisualTokens.cardCorner, style: .continuous)
    }

    private func artwork(_ page: HomeHeroPage) -> some View {
        HomeHeroV2Artwork(
            asset: heroArtworkAsset(for: page),
            accent: Color(uiColor: sourceAccent(page)),
            side: artworkSide
        )
        .frame(width: artworkSide, height: artworkSide)
        .background(HomeHeroV2LivingPlate(accent: sourceAccent(page)))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func heroCopy(_ page: HomeHeroPage) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.xs + PPSpace.xxs) {
            Text(page.title)
                .font(HomeFont.bold(horizontalSizeClass == .regular ? 30 : 24))
                .foregroundStyle(Color.homeTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if !page.subtitle.isEmpty {
                Text(page.subtitle)
                    .font(HomeFont.regular(14))
                    .foregroundStyle(Color.homeTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

        }
        .multilineTextAlignment(.leading)
    }

    private func heroActions(_ page: HomeHeroPage) -> some View {
        HStack(alignment: .center, spacing: PPSpace.xs) {
            Button(action: onPrimaryAction) {
                HStack(spacing: PPSpace.xs) {
                    Text(page.primaryTitle)
                        .font(HomeFont.medium(14))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Image(systemName: "chevron.forward")
                        .font(.system(size: 11, weight: .semibold))
                        .accessibilityHidden(true)
                }
                .foregroundStyle(Color(uiColor: HomeHeroV2Palette.actionForeground(on: sourceAccent(page))))
                .padding(.horizontal, PPSpace.md)
                .frame(minHeight: HomeVisualTokens.minimumTouchTarget)
                .background(Color(uiColor: sourceAccent(page)), in: RoundedRectangle(
                    cornerRadius: HomeVisualTokens.primaryActionCorner,
                    style: .continuous
                ))
            }
            .buttonStyle(HomeHeroV2PressStyle(reduceMotion: reduceMotion))
            .accessibilityHint(HomeModelAdapter.localized(
                "home_pulse_opens_destination_a11y",
                fallback: "Opens this destination"
            ))

            // Preserve every secondary route without a competing CTA.
            if let secondaryTitle = page.secondaryTitle,
               !secondaryTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Menu {
                    Button(secondaryTitle, action: onSecondaryAction)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.homeTextPrimary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(secondaryTitle)
            }
        }
    }

    // MARK: Artwork resolution (unchanged contract from V1)

    private func heroArtworkAsset(
        for page: HomeHeroPage
    ) -> HomeHeroV2ArtworkAsset {
        switch page.kind {
        case .pet:
            if let imageURL = normalizedHeroImageURL(page.imageURL) {
                return HomeHeroV2ArtworkAsset(
                    remoteImageURL: imageURL
                )
            }
            return HomeHeroV2ArtworkAsset(
                animationName: "Profile.lottie",
                loadsFromFirebase: true
            )
        case .reminder:
            return HomeHeroV2ArtworkAsset(
                animationName: "Caretiming",
                loadsFromFirebase: true
            )
        case .promotion:
            let remoteURL = normalizedHeroImageURL(page.imageURL)
            return HomeHeroV2ArtworkAsset(
                animationName: remoteURL == nil ? "HomePromotionSpark" : nil,
                remoteImageURL: remoteURL
            )
        case .marketplace:
            let allKindsHeroImageURL = "https://firebasestorage.googleapis.com/v0/b/pure-pets-49199.firebasestorage.app/o/AppData%2FMainCategories%2FallkindsHeroImage.png?alt=media&token=91308ed0-acbb-465e-b53a-14432f5073e0"
            let selectedCategoryID: Int?
            if case let .openMarketplace(mainKind) = page.action,
               let mainKind {
                selectedCategoryID = HomeModelAdapter.mainKindID(mainKind)
            } else {
                selectedCategoryID = nil
            }
            let resolvedImageURL = normalizedHeroImageURL(page.imageURL)
                ?? (selectedCategoryID == nil ? allKindsHeroImageURL : nil)
            let hasSelectedCategory = selectedCategoryID != nil
            let hasPageArtwork = page.localImage != nil
                || resolvedImageURL != nil
            if homeHeroV2ShowsSelectedMainKindArtwork
                && (hasSelectedCategory || hasPageArtwork) {
                let categoryImage = page.localImage
                let fallbackImage = categoryImage
                return HomeHeroV2ArtworkAsset(
                    imageName: nil,
                    localImage: fallbackImage,
                    // Match `PPMainKindsCell`: show the resolved local artwork
                    // first, then let the shared image loader replace it with
                    // the category's current remote image when available.
                    remoteImageURL: resolvedImageURL,
                    usesCategoryArtworkTreatment: true,
                    extendsFromTopAnchor: page.usesHeroImageURL || selectedCategoryID == nil,
                    categoryID: selectedCategoryID
                )
            }
            // Preserve the Lottie file reference (`Shop2.json`) and temporarily hide it for "All Categories".
            return HomeHeroV2ArtworkAsset(
                animationName: "Shop2.json",
                isHidden: true
            )
        case .petOnboarding:
            return HomeHeroV2ArtworkAsset(
                animationName:
                    "LottieAnimations/Boy Giving Food To Rabbit New.json",
                loadsFromFirebase: true
            )
        case .pharmacy:
            return HomeHeroV2ArtworkAsset(animationName: "PetMedicine")
        }
    }

    private func normalizedHeroImageURL(_ imageURL: String?) -> String? {
        guard let imageURL else { return nil }
        let trimmed = imageURL.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// The artwork stays still while its plate softly changes contour. Core
/// Animation owns the loop, so the image, copy and Home feed do not redraw on
/// every frame. The same existing membrane geometry supplies the static state.
@available(iOS 15.0, *)
private struct HomeHeroV2LivingPlate: View {
    let accent: UIColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @State private var mounted = false

    var body: some View {
        HomeHeroV2PlateRenderer(
            accent: accent,
            motionEnabled: mounted && !reduceMotion,
            usesStaticShape: reduceMotion,
            isDark: colorScheme == .dark,
            isOpaque: reduceTransparency
        )
        .onAppear { mounted = true }
        .onDisappear { mounted = false }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

@available(iOS 15.0, *)
private struct HomeHeroV2PlateRenderer: UIViewRepresentable {
    let accent: UIColor
    let motionEnabled: Bool
    let usesStaticShape: Bool
    let isDark: Bool
    let isOpaque: Bool

    func makeUIView(context: Context) -> PlateView { PlateView() }

    func updateUIView(_ view: PlateView, context: Context) {
        view.configure(accent: accent, motionEnabled: motionEnabled, usesStaticShape: usesStaticShape,
                       isDark: isDark, isOpaque: isOpaque)
    }

    static func dismantleUIView(_ view: PlateView, coordinator: ()) {
        view.stop()
    }

    final class PlateView: UIView {
        private let wash = CAGradientLayer()
        private var hasPlayedContour = false
        private let membrane = CAShapeLayer()
        private var scrollObservations: [NSKeyValueObservation] = []
        private var lifecycleObservers: [NSObjectProtocol] = []
        private weak var observedScrollView: UIScrollView?
        private var motionEnabled = false
        private var usesStaticShape = false
        private var lastSize: CGSize = .zero
        private var applicationActive = false

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            isAccessibilityElement = false
            backgroundColor = .clear
            wash.startPoint = CGPoint(x: 0.25, y: 0)
            wash.endPoint = CGPoint(x: 0.85, y: 1)
            wash.locations = [0, 0.55, 1]
            wash.mask = membrane
            layer.addSublayer(wash)
            applicationActive = UIApplication.shared.applicationState == .active
            // UIKit owns this hosting controller's lifecycle. Do not rely on a
            // SwiftUI Scene value that is not supplied by a SwiftUI App root.
            for (name, active) in [
                (UIApplication.didBecomeActiveNotification, true),
                (UIApplication.willResignActiveNotification, false)
            ] {
                lifecycleObservers.append(NotificationCenter.default.addObserver(
                    forName: name, object: nil, queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.applicationActive = active
                        self?.updateMotion()
                    }
                })
            }
        }

        required init?(coder: NSCoder) { nil }

        func configure(accent: UIColor, motionEnabled: Bool, usesStaticShape: Bool, isDark: Bool, isOpaque: Bool) {
            self.motionEnabled = motionEnabled
            self.usesStaticShape = usesStaticShape
            let traits = UITraitCollection(userInterfaceStyle: isDark ? .dark : .light)
            let base = UIColor(Color.homeSurface).resolvedColor(with: traits)
            let tint = HomeHeroV2Palette.sourceAccent(accent, traits: traits)
            // Composite opaque colors over the actual surface. Reduce
            // Transparency keeps the same category identity without a wash.
            let near = HomeHeroV2Palette.blend(tint, with: base, ratio: isDark ? 0.42 : 0.23)
            let middle = HomeHeroV2Palette.blend(tint, with: base, ratio: isDark ? 0.28 : 0.14)
            let far = HomeHeroV2Palette.blend(tint, with: base, ratio: isDark ? 0.18 : 0.08)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            wash.backgroundColor = base.cgColor
            wash.colors = isOpaque
                ? [middle.cgColor, middle.cgColor, middle.cgColor]
                : [near.cgColor, middle.cgColor, far.cgColor]
            CATransaction.commit()
            updateMotion()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            if bounds.size != lastSize {
                lastSize = bounds.size
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                wash.frame = bounds
                membrane.frame = wash.bounds
                membrane.path = platePath(phase: 0)
                membrane.removeAnimation(forKey: "home.plate.contour")
                CATransaction.commit()
            }
            observeScrollViewIfNeeded()
            updateMotion()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil { scrollObservations.removeAll(); observedScrollView = nil }
            else { observeScrollViewIfNeeded() }
            updateMotion()
        }

        private func platePath(phase: CGFloat) -> CGPath {
            PPHomeHeroLivingBlobShape(phase: phase)
                .path(in: CGRect(origin: .zero, size: bounds.size).insetBy(dx: 4, dy: 4)).cgPath
        }

        private func observeScrollViewIfNeeded() {
            var ancestor = superview
            while let view = ancestor {
                if let scroll = view as? UIScrollView {
                    guard observedScrollView !== scroll else { return }
                    observedScrollView = scroll
                    scrollObservations = [
                        scroll.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
                            Task { @MainActor [weak self] in self?.updateMotion() }
                        },
                        scroll.observe(\.bounds, options: [.new]) { [weak self] _, _ in
                            Task { @MainActor [weak self] in self?.updateMotion() }
                        }
                    ]
                    return
                }
                ancestor = view.superview
            }
        }

        private var isInViewport: Bool {
            guard let window, bounds.width > 8, bounds.height > 8 else { return false }
            var visibleRect = convert(bounds, to: window).intersection(window.bounds)
            var ancestor: UIView? = self
            while let view = ancestor {
                if view.isHidden || view.alpha < 0.01 { return false }
                if view.clipsToBounds {
                    visibleRect = visibleRect.intersection(view.convert(view.bounds, to: window))
                }
                ancestor = view.superview
            }
            return !visibleRect.isNull && visibleRect.width > 1 && visibleRect.height > 1
        }

        private func updateMotion() {
            if usesStaticShape {
                membrane.removeAnimation(forKey: "home.plate.contour")
                return
            }
            let shouldRun = motionEnabled && applicationActive && isInViewport
            if shouldRun, !hasPlayedContour, membrane.animation(forKey: "home.plate.contour") == nil {
                hasPlayedContour = true
                // Integer harmonics close exactly after one revolution. Sampling
                // once leaves interpolation with Core Animation, off the feed.
                let contour = CAKeyframeAnimation(keyPath: "path")
                contour.values = (0...60).map { platePath(phase: CGFloat($0) / 60 * .pi * 2) }
                contour.duration = 3.6
                contour.repeatCount = 1
                contour.calculationMode = .linear
                membrane.add(contour, forKey: "home.plate.contour")
            }
            if shouldRun && wash.speed == 0 {
                let pausedTime = wash.timeOffset
                wash.speed = 1
                wash.timeOffset = 0
                wash.beginTime = 0
                wash.beginTime = wash.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
            } else if !shouldRun && wash.speed != 0 {
                let pausedTime = wash.convertTime(CACurrentMediaTime(), from: nil)
                wash.speed = 0
                wash.timeOffset = pausedTime
            }
        }

        func stop() {
            scrollObservations.removeAll()
            lifecycleObservers.forEach(NotificationCenter.default.removeObserver)
            lifecycleObservers.removeAll()
            observedScrollView = nil
            membrane.removeAllAnimations()
            motionEnabled = false
        }
    }
}

// MARK: - Artwork

struct HomeHeroV2ArtworkAsset {
    var animationName: String?
    var imageName: String?
    var localImage: UIImage?
    var remoteImageURL: String?
    var usesCategoryArtworkTreatment: Bool
    var extendsFromTopAnchor: Bool
    var categoryID: Int?
    var loadsFromFirebase: Bool
    var isHidden: Bool

    /// True only for the marketplace All-categories scope: category artwork is
    /// resolved but no single `categoryID` is selected. That artwork is a
    /// composite illustration, so the hero presents it unmasked.
    var presentsAllCategoriesScope: Bool {
        usesCategoryArtworkTreatment && categoryID == nil
    }

    init(
        animationName: String? = nil,
        imageName: String? = nil,
        localImage: UIImage? = nil,
        remoteImageURL: String? = nil,
        usesCategoryArtworkTreatment: Bool = false,
        extendsFromTopAnchor: Bool = false,
        categoryID: Int? = nil,
        loadsFromFirebase: Bool = false,
        isHidden: Bool = false
    ) {
        self.animationName = animationName
        self.imageName = imageName
        self.localImage = localImage
        self.remoteImageURL = remoteImageURL
        self.usesCategoryArtworkTreatment = usesCategoryArtworkTreatment
        self.extendsFromTopAnchor = extendsFromTopAnchor
        self.categoryID = categoryID
        self.loadsFromFirebase = loadsFromFirebase
        self.isHidden = isHidden
    }
}

/// SwiftUI bridge for the exact category-artwork pipeline owned by
/// `PPMainKindsCell`. It reuses `PPImageLoaderManager`'s SDWebImage cache,
/// retry/scale-down policy, request cancellation, and no-transition behavior.
@available(iOS 15.0, *)
private struct HomeHeroV2MainKindArtwork: UIViewRepresentable {
    let urlString: String
    let placeholder: UIImage?

    final class Coordinator {
        weak var imageView: UIImageView?
        var boundURL: String?
        var generation: UInt = 0
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        container.clipsToBounds = true
        container.isUserInteractionEnabled = false

        let imageView = UIImageView()
        imageView.backgroundColor = .clear
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.isAccessibilityElement = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        context.coordinator.imageView = imageView
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        guard let imageView = context.coordinator.imageView else { return }
        container.clipsToBounds = true
        imageView.contentMode = .scaleAspectFit

        let resolvedPlaceholder = placeholder?.withRenderingMode(.alwaysOriginal)
        guard context.coordinator.boundURL != urlString else {
            if imageView.image == nil {
                imageView.image = resolvedPlaceholder
            }
            return
        }

        context.coordinator.generation &+= 1
        let expectedGeneration = context.coordinator.generation
        context.coordinator.boundURL = urlString

        PPImageLoaderManager.shared().setImage(
            on: imageView,
            url: urlString,
            placeholder: resolvedPlaceholder,
            transitionStyle: .none
        ) { [weak imageView, weak coordinator = context.coordinator] image, _ in
            guard let imageView,
                  let coordinator,
                  coordinator.generation == expectedGeneration,
                  coordinator.boundURL == urlString,
                  let image else {
                return
            }
            imageView.image = image.withRenderingMode(.alwaysOriginal)
        }
    }

    static func dismantleUIView(
        _ container: UIView,
        coordinator: Coordinator
    ) {
        coordinator.generation &+= 1
        coordinator.boundURL = nil
        if let imageView = coordinator.imageView {
            PPImageLoaderManager.shared().cancelImageLoad(for: imageView)
            imageView.image = nil
        }
        coordinator.imageView = nil
    }
}

@available(iOS 15.0, *)
private struct HomeHeroV2Artwork: View {
    let asset: HomeHeroV2ArtworkAsset
    let accent: Color
    let side: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        content
            .frame(width: side, height: side)
            .scaleEffect(speciesScale)
            .offset(
                x: layoutDirection == .leftToRight ? -speciesOffset.width : speciesOffset.width,
                y: speciesOffset.height
            )
            .scaleEffect(
                x: layoutDirection == .leftToRight ? -1 : 1,
                y: 1
            )
            .accessibilityHidden(true)
    }

    private var speciesScale: CGFloat {
        guard asset.usesCategoryArtworkTreatment else { return 1 }
        return HomeSpeciesArtworkTreatment.resolved(
            for: asset.categoryID ?? 0
        ).scale
    }

    private var speciesOffset: CGSize {
        guard asset.usesCategoryArtworkTreatment else { return .zero }
        return HomeSpeciesArtworkTreatment.resolved(
            for: asset.categoryID ?? 0
        ).offset(for: side)
    }

    @ViewBuilder
    private var content: some View {
        if asset.isHidden {
            Color.clear
        } else if let remoteImageURL = asset.remoteImageURL,
           asset.usesCategoryArtworkTreatment {
            HomeHeroV2MainKindArtwork(
                urlString: remoteImageURL,
                placeholder: asset.localImage
            )
            .frame(width: side, height: side)
            .clipped()
        } else if let remoteImageURL = asset.remoteImageURL {
            HomeRemoteImage(
                urlString: remoteImageURL,
                placeholder: asset.localImage,
                contentMode: .scaleAspectFit
            )
            .clipShape(Circle())
            .overlay {
                Circle()
                    .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.85)
            }
        } else if let localImage = asset.localImage {
            Image(uiImage: localImage)
                .resizable()
                .scaledToFit()
        } else if let imageName = asset.imageName {
            Image(imageName)
                .resizable()
                .scaledToFit()
        } else if let animationName = asset.animationName {
            HomeHeroLottieRepresentable(
                animationName: animationName,
                loadsFromFirebase: asset.loadsFromFirebase,
                playbackEnabled: false,
                tintColor: lottieTintColor(for: animationName)
            )
            .scaleEffect(lottieScale(for: animationName))
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        if let localImage = asset.localImage {
            Image(uiImage: localImage)
                .resizable()
                .scaledToFit()
        } else {
            Color.clear
        }
    }

    private func lottieScale(for animationName: String) -> CGFloat {
        if animationName == "Shop2.json" { return 0.78 }
        return animationName == "petstore" ? 0.68 : 0.82
    }

    /// Marketplace artwork is a commerce identity mark, not body content, so
    /// its baked Lottie fills and strokes follow the canonical marketplace
    /// commerce accent (`ppQuickActionShopping`) instead of primary text ink.
    /// This matches the marketplace destination tint used across Home and the
    /// V1 hero, keeps the mark inside the brand rose family rather than reading
    /// as flat black, and adapts automatically in dark mode. Other hero
    /// animations retain the stable V2 primary accent.
    private func lottieTintColor(for animationName: String) -> UIColor {
        let assetName = animationName
            .split(separator: "/")
            .last
            .map(String.init)?
            .lowercased()
        if assetName == "shop2.json" || assetName == "bag2.json" {
            return .ppQuickActionShopping
        }
        return UIColor(accent)
    }
}

// MARK: - Swipe grip

/// Quiet paging affordance attached to the card edge. It remains decorative;
/// the entire card owns the swipe gesture and adjustable accessibility action.
@available(iOS 15.0, *)
private struct HomeHeroV2SwipeGrip: View {
    let accent: Color
    let reduceTransparency: Bool

    var body: some View {
        HStack(spacing: HomeHeroV2Metrics.gripBarSpacing) {
            ForEach(0..<3, id: \.self) { _ in
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.52))
                    .frame(
                        width: HomeHeroV2Metrics.gripBarWidth,
                        height: HomeHeroV2Metrics.gripBarHeight
                    )
            }
        }
        .frame(
            width: HomeHeroV2Metrics.gripWidth,
            height: HomeHeroV2Metrics.gripHeight
        )
        .background {
            Capsule(style: .continuous)
                .fill(
                    reduceTransparency
                        ? Color.ppSurfaceRaised
                        : accent.opacity(0.08)
                )
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(accent.opacity(0.20), lineWidth: 0.7)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Skeleton

@available(iOS 15.0, *)
private struct HomeHeroV2Skeleton: View {
    let height: CGFloat

    var body: some View {
        HStack(spacing: PPSpace.lg) {
                VStack(alignment: .leading, spacing: PPSpace.md) {
                    Capsule().fill(Color.ppSeparator).frame(width: 78, height: 10)
                    Capsule().fill(Color.ppSeparator).frame(width: 150, height: 22)
                    Capsule().fill(Color.ppSeparator).frame(width: 164, height: 13)
                    Capsule().fill(Color.ppSeparator).frame(width: 126, height: 13)
                    Capsule()
                        .fill(Color.ppPrimary.opacity(0.16))
                        .frame(width: 140, height: HomeHeroV2Metrics.primaryHeight)
                }

                Spacer(minLength: 0)

                // Matches the live plate's lens proportion so the loading state
                // does not settle into a shorter shape once content arrives.
                Ellipse()
                    .fill(Color.ppSecondarySurface)
                    .frame(
                        width: HomeHeroV2Metrics.skeletonPlateInk,
                        height: HomeHeroV2Metrics.skeletonPlateInk
                            * HomeHeroV2Metrics.plateHeightRatio
                    )
        }
        .padding(HomeHeroV2Metrics.cardContentInset)
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            HomeModelAdapter.localized(
                "home_pulse_loading",
                fallback: "Loading Home"
            )
        )
    }
}

// MARK: - Motion + interaction modifiers

private struct HomeHeroV2PressStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.985)
            .brightness(configuration.isPressed ? -0.035 : 0)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.14),
                value: configuration.isPressed
            )
    }
}

private struct HomeHeroV2PageMotionModifier: ViewModifier {
    let pageID: AnyHashable
    let reduceMotion: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceMotion {
            content.animation(nil, value: pageID)
        } else {
            content.animation(
                .easeInOut(duration: 0.28),
                value: pageID
            )
        }
    }
}

private struct HomeHeroV2PagingGestureModifier: ViewModifier {
    let isEnabled: Bool
    let selectedIndex: Int
    let pageCount: Int
    let layoutDirection: LayoutDirection
    let onSelect: (Int) -> Void
    let onInteractionChanged: (Bool) -> Void
    @GestureState private var hasHorizontalIntent = false

    func body(content: Content) -> some View {
        Group {
            if isEnabled && pageCount > 1 {
                content.simultaneousGesture(
                    DragGesture(minimumDistance: 24)
                        .updating($hasHorizontalIntent) { value, active, _ in
                            let dx = abs(value.translation.width)
                            let dy = abs(value.translation.height)
                            active = dx > 24 && dx > dy * 1.5
                        }
                        .onEnded { value in
                            let dx = abs(value.translation.width)
                            let dy = abs(value.translation.height)
                            guard dx > 44, dx > dy * 1.5 else { return }
                            let physicalDirection = value.translation.width < 0 ? 1 : -1
                            let logicalDirection = layoutDirection == .rightToLeft ? -physicalDirection : physicalDirection
                            onSelect((selectedIndex + logicalDirection + pageCount) % pageCount)
                        }
                )
            } else {
                content
            }
        }
        // GestureState resets on cancellation as well as completion. A vertical
        // scroll can now cancel paging without leaving hero rotation paused.
        .onChange(of: hasHorizontalIntent) { onInteractionChanged($0) }
        .onChange(of: isEnabled) { if !$0 { onInteractionChanged(false) } }
        .onDisappear { onInteractionChanged(false) }
    }
}

private struct HomeHeroV2PagingAccessibilityModifier: ViewModifier {
    let isEnabled: Bool
    let selectedIndex: Int
    let pageCount: Int
    let onSelect: (Int) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content
                .accessibilityValue(
                    String(
                        format: HomeModelAdapter.localized(
                            "home_pulse_page_position_a11y",
                            fallback: "%1$d of %2$d"
                        ),
                        selectedIndex + 1,
                        pageCount
                    )
                )
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment:
                        onSelect((selectedIndex + 1) % max(pageCount, 1))
                    case .decrement:
                        onSelect(
                            (selectedIndex - 1 + max(pageCount, 1))
                                % max(pageCount, 1)
                        )
                    @unknown default:
                        break
                    }
                }
        } else {
            content
        }
    }
}


// MARK: - Identity accent safety

/// Contrast ladder for the hero's live category accent.
///
/// Ported from the same policy the species rail already applies to a MainKind
/// color: keep the authored identity color when it is legible, otherwise walk
/// toward primary text and the brand until it is. Firebase owns the category
/// palette, so the hero cannot assume a usable value.
enum HomeHeroV2Palette {
    static func sourceAccent(_ candidate: UIColor, traits: UITraitCollection) -> UIColor {
        opaque(candidate.resolvedColor(with: traits)) ?? UIColor.ppPrimary.resolvedColor(with: traits)
    }

    /// Black or white guarantees at least 4.5:1 against any opaque category
    /// fill, including very light server-authored yellows and dark blues.
    static func actionForeground(on background: UIColor) -> UIColor {
        contrastRatio(.white, background) >= contrastRatio(.black, background) ? .white : .black
    }

    static func identityAccent(
        _ candidate: UIColor,
        traits: UITraitCollection,
        on background: UIColor? = nil,
        increasedContrast: Bool = false
    ) -> UIColor {
        let surface = (background ?? UIColor.ppSurfaceRaised).resolvedColor(with: traits)
        let text = UIColor.ppTextPrimary.resolvedColor(with: traits)
        let brand = UIColor.ppPrimary.resolvedColor(with: traits)
        // Use this ladder for colored text on a surface. Filled actions use
        // their unmodified category color with a separately matched label.
        let required: CGFloat = increasedContrast ? 7 : 4.5

        let base = opaque(candidate.resolvedColor(with: traits)) ?? brand
        let ladder: [UIColor] = [
            base,
            blend(base, with: text, ratio: 0.72),
            blend(base, with: text, ratio: 0.52),
            brand,
            blend(brand, with: text, ratio: 0.58),
        ]
        for color in ladder where contrastRatio(color, surface) >= required {
            return color
        }
        return text
    }

    static func blend(
        _ first: UIColor,
        with second: UIColor,
        ratio: CGFloat
    ) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        guard first.getRed(&r1, green: &g1, blue: &b1, alpha: &a1),
              second.getRed(&r2, green: &g2, blue: &b2, alpha: &a2) else {
            return first
        }
        let amount = min(max(ratio, 0), 1)
        let inverse = 1 - amount
        return UIColor(
            red: (r1 * amount) + (r2 * inverse),
            green: (g1 * amount) + (g2 * inverse),
            blue: (b1 * amount) + (b2 * inverse),
            alpha: (a1 * amount) + (a2 * inverse)
        )
    }

    private static func opaque(_ color: UIColor) -> UIColor? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        var alpha: CGFloat = 0
        if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            guard alpha >= 0.12 else { return nil }
            return UIColor(red: red, green: green, blue: blue, alpha: 1)
        }
        var white: CGFloat = 0
        if color.getWhite(&white, alpha: &alpha) {
            guard alpha >= 0.12 else { return nil }
            return UIColor(white: white, alpha: 1)
        }
        return nil
    }

    private static func contrastRatio(
        _ first: UIColor,
        _ second: UIColor
    ) -> CGFloat {
        let lighter = max(luminance(first), luminance(second))
        let darker = min(luminance(first), luminance(second))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func luminance(_ color: UIColor) -> CGFloat {
        guard let opaqueColor = opaque(color) else { return 0 }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard opaqueColor.getRed(
            &red,
            green: &green,
            blue: &blue,
            alpha: &alpha
        ) else {
            return 0
        }
        func linear(_ component: CGFloat) -> CGFloat {
            component <= 0.03928
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }
        return (0.2126 * linear(red))
            + (0.7152 * linear(green))
            + (0.0722 * linear(blue))
    }
}

// MARK: - Living Species Dock

@available(iOS 15.0, *)
private struct HomeHeroSpeciesDock: View {
    let categories: [HomeCategoryModel]
    let selectedCategoryID: Int?
    let accent: Color
    let isRightToLeft: Bool
    let onSelect: (HomeCategoryModel?) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HomeCategoriesStripView(
            categories: categories,
            selectedCategoryID: selectedCategoryID,
            accent: accent,
            isRightToLeft: isRightToLeft,
            reduceMotion: reduceMotion,
            onSelect: onSelect,
            accessibilityPrefix: "home.hero.mainKind"
        )
    }
}
