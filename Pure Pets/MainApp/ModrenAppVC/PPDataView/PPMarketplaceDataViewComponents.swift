import SwiftUI
import UIKit

@available(iOS 15.0, *)
extension Color {
    static var ppMarketplaceTextPrimary: Color {
        Color(uiColor: UIColor(named: "PrimaryTextColor") ?? .label)
    }

    static var ppMarketplaceTextSecondary: Color {
        Color(uiColor: UIColor(named: "SecondaryTextColor") ?? .secondaryLabel)
    }

    static var ppMarketplaceSurface: Color {
        Color(uiColor: UIColor(named: "AppForegroundColor") ?? .secondarySystemBackground)
    }

    static var ppMarketplaceCanvas: Color {
        Color(uiColor: .systemBackground)
    }

    static var ppMarketplaceSeparator: Color {
        Color(uiColor: .separator)
    }
}

@available(iOS 15.0, *)
struct PPMarketplaceAtmosphere: View {
    let accent: UIColor
    let usesBrandAccent: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        WorldGlassBackground(
            tint: usesBrandAccent ? .worldGlassBerry : Color(accent),
            isFaded: true
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Top Deck Metrics & Organic Wave Geometry

@available(iOS 15.0, *)
enum PPMarketplaceTopDeckMetrics {
    /// Radius of the center X half-circle container for the current category icon (0 = clean straight separator).
    static let halfCircleRadius: CGFloat = 0.0
    /// Vertical amplitude of the organic wave bottom contour (retained for backward compatibility).
    static let waveDepth: CGFloat = 10.0
    /// Stroke width for the delicate rose/primary wave separator line.
    static let separatorStrokeWidth: CGFloat = 1.5
    /// High-contrast accessible stroke width.
    static let separatorStrokeIncreasedContrastWidth: CGFloat = 2.0
    /// Bottom padding inside the dock to give controls vertical breathing room comfortably above the separator.
    static let dockBottomPadding: CGFloat = 10.0
}

@available(iOS 15.0, *)
struct PPMarketplaceTopDeckWaveShape: Shape {
    var isRightToLeft: Bool = true
    var waveDepth: CGFloat = PPMarketplaceTopDeckMetrics.waveDepth

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let baseY = max(0, height - waveDepth)

        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: width, y: 0))

        if isRightToLeft {
            // Line down right edge to wave end
            path.addLine(to: CGPoint(x: width, y: baseY + (waveDepth * 0.25)))

            // Right curve to central crest
            path.addCurve(
                to: CGPoint(x: width * 0.60, y: baseY + (waveDepth * 0.30)),
                control1: CGPoint(x: width * 0.88, y: baseY + (waveDepth * 0.95)),
                control2: CGPoint(x: width * 0.76, y: baseY + (waveDepth * 0.65))
            )

            // Crest curve to left edge
            path.addCurve(
                to: CGPoint(x: 0, y: baseY),
                control1: CGPoint(x: width * 0.35, y: baseY + (waveDepth * 0.90)),
                control2: CGPoint(x: width * 0.18, y: baseY + (waveDepth * 0.95))
            )

            // Up left edge to top
            path.addLine(to: CGPoint(x: 0, y: 0))
        } else {
            // LTR mirrored
            path.addLine(to: CGPoint(x: width, y: baseY))

            path.addCurve(
                to: CGPoint(x: width * 0.40, y: baseY + (waveDepth * 0.30)),
                control1: CGPoint(x: width * 0.82, y: baseY + (waveDepth * 0.95)),
                control2: CGPoint(x: width * 0.65, y: baseY + (waveDepth * 0.90))
            )

            path.addCurve(
                to: CGPoint(x: 0, y: baseY + (waveDepth * 0.25)),
                control1: CGPoint(x: width * 0.24, y: baseY + (waveDepth * 0.65)),
                control2: CGPoint(x: width * 0.12, y: baseY + (waveDepth * 0.95))
            )

            path.addLine(to: CGPoint(x: 0, y: 0))
        }

        path.closeSubpath()
        return path
    }
}

@available(iOS 15.0, *)
struct PPMarketplaceWaveSeparatorLine: Shape {
    var isRightToLeft: Bool = true
    var waveDepth: CGFloat = PPMarketplaceTopDeckMetrics.waveDepth
    var time: TimeInterval = 0.0

    var animatableData: Double {
        get { time }
        set { time = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        guard width > 0, height > 0 else { return path }

        let baseY = max(0, height - waveDepth)
        let segments = 48
        let dx = width / CGFloat(segments)

        var points: [CGPoint] = []
        points.reserveCapacity(segments + 1)

        let direction: CGFloat = isRightToLeft ? 1.0 : -1.0

        for i in 0...segments {
            let x = CGFloat(i) * dx
            let rawU = x / width
            let u = isRightToLeft ? rawU : (1.0 - rawU)

            // Progressive traveling wave harmonics (authentic liquid wave physics)
            let phase1 = (u * 1.35 * .pi * 2.0) + (direction * CGFloat(time) * 1.40)
            let phase2 = (u * 2.70 * .pi * 2.0) - (direction * CGFloat(time) * 0.90) + 1.2
            let phase3 = (u * 0.85 * .pi * 2.0) + (direction * CGFloat(time) * 0.55) + 2.4

            // Boundary envelope anchoring edges cleanly while permitting natural fluid motion across dock
            let envelope = 0.35 + (0.65 * sin(rawU * .pi))

            let baseDip = sin(rawU * .pi) * (waveDepth * 0.58)
            let wave1 = sin(phase1) * (waveDepth * 0.18)
            let wave2 = cos(phase2) * (waveDepth * 0.08)
            let wave3 = sin(phase3) * (waveDepth * 0.05)

            let totalWaveMotion = (wave1 + wave2 + wave3) * envelope
            let y = baseY + baseDip + totalWaveMotion
            points.append(CGPoint(x: x, y: y))
        }

        guard let first = points.first else { return path }
        path.move(to: first)

        for i in 1..<points.count {
            let p0 = points[i - 1]
            let p1 = points[i]
            let mid = CGPoint(x: (p0.x + p1.x) / 2.0, y: (p0.y + p1.y) / 2.0)
            path.addQuadCurve(to: mid, control: p0)
        }

        if let last = points.last {
            path.addLine(to: last)
        }

        return path
    }
}

@available(iOS 15.0, *)
struct PPMarketplaceTopDeckStraightShape: Shape {
    var halfCircleRadius: CGFloat = PPMarketplaceTopDeckMetrics.halfCircleRadius

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        guard width > 0, height > 0 else { return path }

        let r = min(halfCircleRadius, min(width / 4.0, height))
        guard r > 0 else {
            path.addRect(rect)
            return path
        }
        let baseY = max(0, height - r)
        let midX = width / 2.0

        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: width, y: 0))
        path.addLine(to: CGPoint(x: width, y: baseY))
        path.addLine(to: CGPoint(x: midX + r, y: baseY))

        // Center X downward half circle (right to left through bottom)
        path.addArc(
            center: CGPoint(x: midX, y: baseY),
            radius: r,
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: false
        )

        path.addLine(to: CGPoint(x: 0, y: baseY))
        path.closeSubpath()
        return path
    }
}

@available(iOS 15.0, *)
struct PPMarketplaceDeckSeparatorShape: Shape {
    var halfCircleRadius: CGFloat = PPMarketplaceTopDeckMetrics.halfCircleRadius

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        guard width > 0, height > 0 else { return path }

        let r = min(halfCircleRadius, min(width / 4.0, height))
        guard r > 0 else {
            path.move(to: CGPoint(x: 0, y: height))
            path.addLine(to: CGPoint(x: width, y: height))
            return path
        }
        let baseY = max(0, height - r)
        let midX = width / 2.0

        path.move(to: CGPoint(x: 0, y: baseY))
        path.addLine(to: CGPoint(x: midX - r, y: baseY))

        // Center X downward half circle (left to right through bottom)
        path.addArc(
            center: CGPoint(x: midX, y: baseY),
            radius: r,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: true
        )

        path.addLine(to: CGPoint(x: width, y: baseY))
        return path
    }
}

// MARK: - Top Deck Background Views

@available(iOS 15.0, *)
struct PPMarketplaceHeroBackground: View {
    let statusBarHeight: CGFloat

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        GeometryReader { proxy in
            let topBleed = max(0, statusBarHeight) + 400
            ZStack {
                // Solid surface background ensures no scroll content bleeds through
                Color.ppSurface

                if !reduceTransparency && contrast != .increased {
                    LinearGradient(
                        colors: [
                            Color.ppSurface,
                            Color.ppSurface,
                            colorScheme == .dark
                                ? Color.ppSurfaceOverlay.opacity(0.85)
                                : Color.ppSurfaceOverlay.opacity(0.70)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height + topBleed)
            .offset(y: -topBleed)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

@available(iOS 15.0, *)
struct PPMarketplaceCurrentDockBackground: View {
    let isPinned: Bool
    let statusBarHeight: CGFloat
    let isRightToLeft: Bool
    var categoryIconName: String = "sparkles.rectangle.stack"

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let topExtension = isPinned ? max(0, statusBarHeight) + PPCorner.hero : 0
            let totalHeight = proxy.size.height + topExtension
            let isIncreasedContrast = contrast == .increased
            let r = PPMarketplaceTopDeckMetrics.halfCircleRadius
            let width = proxy.size.width
            let midX = width / 2.0
            let baseY = max(0, totalHeight - r)

            ZStack(alignment: .bottom) {
                // 1. Static floating vector elevation shadow following the straight line + center half circle
                if !isIncreasedContrast {
                    PPMarketplaceTopDeckStraightShape(halfCircleRadius: r)
                        .fill(Color.ppSurface)
                        .shadow(
                            color: Color.black.opacity(colorScheme == .dark ? 0.32 : 0.07),
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                        .shadow(
                            color: Color.ppPrimary.opacity(colorScheme == .dark ? 0.18 : 0.06),
                            radius: 3,
                            x: 0,
                            y: 1
                        )
                }

                // 2. Static deck surface fill strictly clipped to straight shape + half circle (100% opaque base guarantees separation)
                surfaceFill(isIncreasedContrast: isIncreasedContrast)
                    .clipShape(
                        PPMarketplaceTopDeckStraightShape(halfCircleRadius: r)
                    )

                // 3. Delicate ambient glow along the straight line and center half circle
                if !isIncreasedContrast {
                    PPMarketplaceDeckSeparatorShape(halfCircleRadius: r)
                        .stroke(
                            Color.ppPrimary.opacity(colorScheme == .dark ? 0.24 : 0.14),
                            style: StrokeStyle(lineWidth: 3.0, lineCap: .round, lineJoin: .round)
                        )
                        .blur(radius: 1.5)
                }

                // 4. Primary straight separator line with faded sides and center half circle
                PPMarketplaceDeckSeparatorShape(halfCircleRadius: r)
                    .stroke(
                        straightSeparatorGradient(isIncreasedContrast: isIncreasedContrast),
                        style: StrokeStyle(
                            lineWidth: isIncreasedContrast
                                ? PPMarketplaceTopDeckMetrics.separatorStrokeIncreasedContrastWidth
                                : PPMarketplaceTopDeckMetrics.separatorStrokeWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .shadow(
                        color: isIncreasedContrast
                            ? .clear
                            : Color.ppPrimary.opacity(colorScheme == .dark ? 0.35 : 0.18),
                        radius: 2.0,
                        x: 0,
                        y: 1
                    )

                // 5. Center X half-circle category container with current category icon (only if r > 0)
                if r > 0 {
                    ZStack {
                        // Subtle luminous inner radial tint inside the half-circle dome
                        if !isIncreasedContrast {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color.ppPrimary.opacity(colorScheme == .dark ? 0.18 : 0.09),
                                            Color.ppPrimary.opacity(colorScheme == .dark ? 0.04 : 0.02),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 1,
                                        endRadius: r * 0.95
                                    )
                                )
                                .frame(width: r * 2.0, height: r * 2.0)
                                .position(x: midX, y: baseY)
                                .clipShape(
                                    PPMarketplaceTopDeckStraightShape(halfCircleRadius: r)
                                )
                        }

                        // Current category icon
                        Image(systemName: categoryIconName)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(
                                isIncreasedContrast
                                    ? Color.ppTextPrimary
                                    : (colorScheme == .dark ? Color.ppPrimaryShiner : Color.ppPrimary)
                            )
                            .shadow(
                                color: isIncreasedContrast
                                    ? .clear
                                    : Color.ppPrimary.opacity(colorScheme == .dark ? 0.40 : 0.22),
                                radius: 2,
                                x: 0,
                                y: 1
                            )
                            .id(categoryIconName)
                            .transition(
                                reduceMotion
                                    ? .opacity
                                    : .scale(scale: 0.82).combined(with: .opacity)
                            )
                            .position(x: midX, y: baseY + (r * 0.46))
                    }
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82),
                        value: categoryIconName
                    )
                }
            }
            .frame(width: proxy.size.width, height: totalHeight)
            .offset(y: -topExtension)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func surfaceFill(isIncreasedContrast: Bool) -> some View {
        ZStack {
            // Uncompromising solid base: guarantees zero bleed-through of underlying scrolling cards
            Color.ppSurface

            if !reduceTransparency && !isIncreasedContrast {
                if isPinned {
                    Rectangle().fill(.ultraThickMaterial)
                    LinearGradient(
                        colors: [
                            Color.ppSurface.opacity(0.92),
                            colorScheme == .dark
                                ? Color.ppSurfaceOverlay.opacity(0.96)
                                : Color.ppSurfaceOverlay
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    LinearGradient(
                        colors: [
                            colorScheme == .dark
                                ? Color.ppSurfaceOverlay.opacity(0.88)
                                : Color.ppSurfaceOverlay.opacity(0.78),
                            Color.ppSurfaceOverlay
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
        }
    }

    private func straightSeparatorGradient(isIncreasedContrast: Bool) -> LinearGradient {
        if isIncreasedContrast {
            return LinearGradient(
                colors: [Color.ppTextPrimary, Color.ppTextPrimary],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        let leadColor = Color.ppPrimary.opacity(colorScheme == .dark ? 0.35 : 0.20)
        let crestColor = Color.ppPrimary.opacity(colorScheme == .dark ? 0.95 : 0.85)
        let centerColor = Color.ppPrimaryShiner.opacity(colorScheme == .dark ? 0.98 : 0.95)

        return LinearGradient(
            stops: [
                .init(color: Color.clear, location: 0.0),
                .init(color: leadColor, location: 0.14),
                .init(color: crestColor, location: 0.35),
                .init(color: centerColor, location: 0.50),
                .init(color: crestColor, location: 0.65),
                .init(color: leadColor, location: 0.86),
                .init(color: Color.clear, location: 1.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

@available(iOS 15.0, *)
struct PPMarketplaceHeroControlLayoutMetrics: Equatable {
    let spacing: CGFloat
    let searchButtonSize: CGFloat
    let categoryMinimumHeight: CGFloat
    let usesCompactHeader: Bool
}

@available(iOS 15.0, *)
enum PPMarketplaceHeroControlLayoutPolicy {
    static func metrics(
        availableWidth: CGFloat,
        isAccessibilitySize: Bool,
        layoutDirection: LayoutDirection
    ) -> PPMarketplaceHeroControlLayoutMetrics {
        // HStack keeps Category on the semantic leading edge and Search on
        // the semantic trailing edge. RTL therefore mirrors placement while
        // preserving the same independent tap targets and stable geometry.
        _ = layoutDirection
        return PPMarketplaceHeroControlLayoutMetrics(
            spacing: PPSpace.md,
            searchButtonSize: 50,
            categoryMinimumHeight: isAccessibilitySize ? 76 : 58,
            usesCompactHeader: isAccessibilitySize || availableWidth < 360
        )
    }
}

@available(iOS 15.0, *)
enum PPMarketplaceContentGeometry {
    static func mosaicColumnCount(
        availableWidth: CGFloat,
        horizontalSizeClass: UserInterfaceSizeClass?,
        isAccessibilitySize: Bool
    ) -> Int {
        let perSideInset = horizontalSizeClass == .regular
            ? PPSpace.xxl
            : PPSpace.screenMargin
        let usableWidth = max(0, availableWidth - (perSideInset * 2))
        let minimumCardWidth = isAccessibilitySize ? usableWidth : 168
        let proposedCount = Int(
            (usableWidth + PPSpace.base) /
                (max(1, minimumCardWidth) + PPSpace.base)
        )
        let maximumCount = horizontalSizeClass == .regular ? 4 : 2
        return max(1, min(maximumCount, proposedCount))
    }

    static func focusHeight(isAccessibilitySize: Bool) -> CGFloat {
        isAccessibilitySize ? 820 : 536
    }

    static func listSpacing(for layout: PPMarketplaceLayout) -> CGFloat {
        layout == .showcase ? PPSpace.lg : PPSpace.md
    }
}

@available(iOS 15.0, *)
struct PPMarketplaceHero: View {
    @ObservedObject var store: PPMarketplaceDataViewStore
    let availableWidth: CGFloat
    let showsBackControl: Bool
    var statusBarHeight: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControlEnabled
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        // A field guide: orientation first, then the animal and its breed.
        // The taxonomy is the heading itself, with no second selection owner.
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            topContextRail
            browseCommands
        }
        .padding(.horizontal, horizontalInset)
        .padding(.top, PPSpace.xs)
        .padding(.bottom, PPSpace.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            PPMarketplaceHeroBackground(
                statusBarHeight: statusBarHeight
            )
        }
        .accessibilityElement(children: .contain)
    }

    private var topContextRail: some View {
        HStack(alignment: .center, spacing: PPSpace.sm) {
            backControl
            PPMarketplaceSmartContextPill(
                store: store,
                action: store.beginFilterEditing
            )
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }

    private var backControl: some View {
        PPMarketplaceBackControl(
            accent: .ppTextPrimary,
            isRightToLeft: store.isRightToLeft,
            isEmbedded: false,
            action: store.goBack
        )
        .opacity(showsBackControl ? 1 : 0)
        .allowsHitTesting(showsBackControl)
        .accessibilityHidden(!showsBackControl)
    }

    @ViewBuilder
    private var browseCommands: some View {
        if heroControlMetrics.usesCompactHeader || dynamicTypeSize >= .xxLarge {
            VStack(alignment: .leading, spacing: PPSpace.sm) {
                categoryCommand
                searchCommand(expanded: true)
            }
        } else {
            HStack(alignment: .center, spacing: PPSpace.md) {
                categoryCommand
                    .layoutPriority(1)
                searchCommand(expanded: false)
            }
        }
    }

    private var categoryCommand: some View {
        VStack(alignment: .leading, spacing: 2) {
            mainKindMenu
            HStack(alignment: .center, spacing: PPSpace.xs) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.ppPrimary.opacity(0.8))
                    .scaleEffect(x: store.isRightToLeft ? -1 : 1, y: 1)
                    .frame(width: PPSpace.md)
                    .accessibilityHidden(true)
                subKindMenu
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("pp.marketplace.category")
        .disabled(store.isReplacingContext)
        .opacity(store.isReplacingContext ? 0.55 : 1)
    }

    private var mainKindMenu: some View {
        Menu {
            ForEach(store.mainKindChoices) { choice in
                Button {
                    store.applyMainKindShortcut(choice)
                } label: {
                    if choice.id == store.currentMainKindID {
                        Label(choice.title, systemImage: "checkmark")
                    } else {
                        Text(choice.title)
                    }
                }
            }
        } label: {
            categoryMenuLabel(
                text: store.currentMainKindTitle,
                primary: true
            )
        }
        .accessibilityLabel(PPMarketplaceText.formatted(
            "marketplace_category_main_kind_format",
            store.currentMainKindTitle
        ))
        .accessibilityAddTraits(.isHeader)
        .accessibilityHint(
            PPMarketplaceText.localized("marketplace_category_main_kind_hint")
        )
        .accessibilityIdentifier("pp.marketplace.category.main-kind")
    }

    private var subKindMenu: some View {
        Menu {
            ForEach(store.subKindChoices) { choice in
                Button {
                    store.applySubKindShortcut(choice)
                } label: {
                    if choice.id == store.currentSubKindID {
                        Label(choice.title, systemImage: "checkmark")
                    } else {
                        Text(choice.title)
                    }
                }
            }
        } label: {
            categoryMenuLabel(
                text: store.currentSubKindTitle,
                primary: false
            )
        }
        .accessibilityLabel(PPMarketplaceText.formatted(
            "marketplace_category_subkind_format",
            store.currentSubKindTitle
        ))
        .accessibilityHint(
            PPMarketplaceText.localized("marketplace_category_subkind_hint")
        )
        .accessibilityIdentifier("pp.marketplace.category.subkind")
    }

    private func categoryMenuLabel(
        text: String,
        primary: Bool
    ) -> some View {
        HStack(spacing: PPSpace.xs) {
            Text(text)
                .font(primary ? HomeFont.bold(26) : HomeFont.medium(15))
                .foregroundStyle(
                    primary
                        ? Color.ppTextPrimary
                        : Color.ppTextSecondary
                )
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : (primary ? 2 : 1))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Image(systemName: "chevron.down")
                .font(.system(size: primary ? 11 : 9, weight: .bold))
                .foregroundStyle(primary ? Color.ppTextPrimary.opacity(0.7) : Color.ppTextSecondary.opacity(0.8))
                .accessibilityHidden(true)

            Spacer(minLength: 0)
        }
        .padding(.vertical, primary ? 2 : 1)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    private func searchCommand(expanded: Bool) -> some View {
        Button(action: store.openSearch) {
            HStack(spacing: PPSpace.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(
                        width: heroControlMetrics.searchButtonSize,
                        height: heroControlMetrics.searchButtonSize
                    )
                    .accessibilityHidden(true)
                if expanded {
                    Text(PPMarketplaceText.localized("marketplace_search_title"))
                        .font(HomeFont.bold(15))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, PPSpace.base)
                        .padding(.vertical, PPSpace.sm)
                }
            }
            .foregroundStyle(Color.white)
            .background(
                Color.ppPrimary,
                in: RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
            }
            .shadow(color: Color.ppPrimary.opacity(0.16), radius: 4, x: 0, y: 2)
            .contentShape(RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous))
        }
        .buttonStyle(PPMarketplacePressStyle(
            reduceMotion: reduceMotion || switchControlEnabled || voiceOverEnabled
        ))
        .accessibilityLabel(PPMarketplaceText.localized("marketplace_search_title"))
        .accessibilityHint(PPMarketplaceText.localized("marketplace_search_hint"))
        .accessibilityIdentifier("pp.marketplace.search")
    }

    private var heroControlMetrics: PPMarketplaceHeroControlLayoutMetrics {
        PPMarketplaceHeroControlLayoutPolicy.metrics(
            availableWidth: availableWidth,
            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize,
            layoutDirection: store.isRightToLeft ? .rightToLeft : .leftToRight
        )
    }

    private var horizontalInset: CGFloat {
        horizontalSizeClass == .regular ? PPSpace.xxl : PPSpace.screenMargin
    }
}

@available(iOS 15.0, *)
struct PPMarketplaceBackControl: View {
    let accent: UIColor
    let isRightToLeft: Bool
    var isEmbedded = false
    let action: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Button(action: action) {
            Image(systemName: isRightToLeft ? "chevron.right" : "chevron.left")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(uiColor: accent))
                .frame(width: 36, height: 36)
                .background(
                    Color.ppSurface,
                    in: Circle()
                )
                .overlay {
                    Circle()
                        .strokeBorder(
                            contrast == .increased ? Color.ppTextPrimary : Color.ppSeparator.opacity(0.5),
                            lineWidth: contrast == .increased ? 1 : 0.5
                        )
                }
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(PPMarketplaceText.localized("Back"))
        .accessibilityIdentifier("pp.marketplace.back")
    }
}

// MARK: - Context and field-guide controls

/// The historical identifier and filter action remain stable. Context is a
/// bridge-owned snapshot; changing its words never schedules animation work.
@available(iOS 15.0, *)
private struct PPMarketplaceSmartContextPill: View {
    @ObservedObject var store: PPMarketplaceDataViewStore
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    private var context: PPMarketplaceNavigationContext {
        store.navigationContext
    }

    var body: some View {
        Button {
            guard !store.isReplacingContext else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: PPSpace.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.title)
                        .font(HomeFont.bold(14))
                        .foregroundStyle(Color.ppTextPrimary)
                    if !context.subtitle.isEmpty {
                        Text(context.subtitle)
                            .font(HomeFont.medium(12))
                            .foregroundStyle(Color.ppTextSecondary)
                    }
                }
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: PPSpace.xs)

                Image(systemName: context.systemImageName.isEmpty
                      ? store.currentSectionDescriptor.iconName
                      : context.systemImageName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.ppPrimary)
                    .accessibilityHidden(true)

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.ppTextSecondary.opacity(0.8))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, PPSpace.md)
            .padding(.vertical, PPSpace.sm)
            .frame(minHeight: 44)
            .background(
                Color.ppSurface,
                in: RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                    .strokeBorder(
                        contrast == .increased ? Color.ppTextPrimary : Color.ppSeparator.opacity(0.5),
                        lineWidth: contrast == .increased ? 1 : 0.5
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous))
        }
        .buttonStyle(PPMarketplacePressStyle(reduceMotion: reduceMotion))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            context.accessibilityLabel.isEmpty ? context.title : context.accessibilityLabel
        )
        .accessibilityHint(PPMarketplaceText.localized("marketplace_filters_open_hint"))
        .accessibilityIdentifier("pp.data.filters.smartDockedPill")
        .disabled(store.isReplacingContext)
        .opacity(store.isReplacingContext ? 0.55 : 1)
    }
}

@available(iOS 15.0, *)
struct PPMarketplaceCurrentDock: View {
    @ObservedObject var store: PPMarketplaceDataViewStore
    let showsPinnedBackControl: Bool
    let statusBarHeight: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControlEnabled
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @Namespace private var sectionSelection

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            sectionRail
            actionRail
        }
        .padding(.bottom, PPMarketplaceTopDeckMetrics.dockBottomPadding)
        .background {
            PPMarketplaceCurrentDockBackground(
                isPinned: showsPinnedBackControl,
                statusBarHeight: statusBarHeight,
                isRightToLeft: store.isRightToLeft,
                categoryIconName: store.currentSectionDescriptor.iconName
            )
        }
        .zIndex(4)
    }

    private var sectionRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PPSpace.base) {
                ForEach(store.sections) { descriptor in
                    let selected = descriptor.rawValue == store.currentSection.rawValue
                    Button {
                        store.selectSection(descriptor)
                    } label: {
                        HStack(spacing: PPSpace.xs) {
                            Image(systemName: descriptor.iconName)
                                .font(.system(size: 14, weight: .semibold))
                                .accessibilityHidden(true)
                            Text(PPMarketplaceText.localized(descriptor.titleKey))
                                .font(selected ? HomeFont.bold(15) : HomeFont.medium(15))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .foregroundStyle(selected ? Color.ppPrimary : Color.ppTextSecondary)
                        .padding(.horizontal, PPSpace.xs)
                        .padding(.vertical, PPSpace.sm)
                        .frame(minHeight: 44)
                        .overlay(alignment: .bottom) {
                            if selected {
                                Capsule(style: .continuous)
                                    .fill(contrast == .increased
                                          ? Color.ppTextPrimary
                                          : Color.ppPrimary)
                                    .frame(height: contrast == .increased ? 3 : 2)
                                    .matchedGeometryEffect(
                                        id: "marketplace.section.selection",
                                        in: sectionSelection
                                    )
                                    .accessibilityHidden(true)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isReplacingContext)
                    .accessibilityLabel(PPMarketplaceText.localized(descriptor.titleKey))
                    .accessibilityHint(PPMarketplaceText.localized("marketplace_section_select_hint"))
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .accessibilityIdentifier("pp.marketplace.section.\(descriptor.rawValue)")
                }
            }
            .padding(.horizontal, horizontalInset)
            // Keep the committed selection response local and gently damped.
            .animation(
                interactionMotionIsDisabled ? nil : .spring(response: 0.28, dampingFraction: 0.90),
                value: store.currentSection.rawValue
            )
            .transaction { transaction in
                if interactionMotionIsDisabled {
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
            }
        }
    }

    private var actionRail: some View {
        HStack(spacing: PPSpace.sm) {
            if showsPinnedBackControl {
                PPMarketplaceBackControl(
                    accent: .ppTextPrimary,
                    isRightToLeft: store.isRightToLeft,
                    isEmbedded: false,
                    action: store.goBack
                )
            }

            // Full filters stay reachable while the contextual commands scroll.
            filtersControl

            Rectangle()
                .fill(contrast == .increased ? Color.ppTextSecondary : Color.ppSeparator.opacity(0.8))
                .frame(width: 1, height: 20)
                .accessibilityHidden(true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PPSpace.xs) {
                    ForEach(store.currentFilterState.groups, id: \.filterID) { group in
                        Menu {
                            ForEach(group.options, id: \.value) { option in
                                Button {
                                    store.applyQuickFilter(groupID: group.filterID, value: option.value)
                                } label: {
                                    if option.value == group.selectedValue {
                                        Label(option.title, systemImage: "checkmark")
                                    } else {
                                        Text(option.title)
                                    }
                                }
                            }
                        } label: {
                            PPMarketplaceRefinementLabel(
                                icon: group.chipIconName ?? "slider.horizontal.3",
                                title: filterChipTitle(group),
                                selected: group.isActive()
                            )
                        }
                        .disabled(store.isReplacingContext)
                        .accessibilityLabel(group.title)
                        .accessibilityValue(filterChipTitle(group))
                        .accessibilityIdentifier("pp.marketplace.filter.\(group.filterID)")
                    }

                    if store.bridge.sectionSupportsProviderFilter(store.currentSection),
                       !store.providerOptions.isEmpty {
                        Button(action: store.presentProviderFilter) {
                            PPMarketplaceRefinementLabel(
                                icon: "storefront.fill",
                                title: selectedProviderTitle,
                                selected: store.selectedProviderID != nil
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(store.isReplacingContext)
                        .accessibilityLabel(PPMarketplaceText.localized("dataview_filter_by_provider"))
                        .accessibilityValue(selectedProviderTitle)
                        .accessibilityIdentifier("pp.marketplace.provider")
                    }

                    Menu {
                        ForEach(PPMarketplaceLayout.allCases) { layout in
                            Button {
                                store.selectLayout(layout)
                            } label: {
                                Label(
                                    PPMarketplaceText.localized(layout.titleKey),
                                    systemImage: layout == store.layout ? "checkmark" : layout.iconName
                                )
                            }
                        }
                    } label: {
                        PPMarketplaceRefinementLabel(
                            icon: store.layout.iconName,
                            title: PPMarketplaceText.localized(store.layout.titleKey),
                            selected: false
                        )
                    }
                    .disabled(store.isReplacingContext)
                    .accessibilityIdentifier("pp.marketplace.layout")

                    Text(store.resultCountText)
                        .font(HomeFont.medium(12))
                        .foregroundStyle(Color.ppTextSecondary)
                        .lineLimit(1)
                        .padding(.horizontal, PPSpace.md)
                        .frame(minHeight: 40)
                        .accessibilityLabel(store.resultCountText)

                    if store.isRefreshing {
                        ProgressView()
                            .tint(Color.ppPrimary)
                            .frame(width: 40, height: 40)
                            .accessibilityLabel(PPMarketplaceText.localized("marketplace_refreshing"))
                    }
                }
                .padding(.trailing, horizontalInset)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.leading, horizontalInset)
        .frame(minHeight: 44)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(PPMarketplaceText.localized("marketplace_browse_controls"))
    }

    private var filterButtonVisualSize: CGFloat {
        showsPinnedBackControl ? 36 : 40
    }

    private var filterButtonIconSize: CGFloat {
        showsPinnedBackControl ? 15 : 17
    }

    private var filterButtonCornerRadius: CGFloat {
        showsPinnedBackControl ? 12 : PPCorner.medium
    }

    private var filtersControl: some View {
        Button(action: store.beginFilterEditing) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: filterButtonIconSize, weight: .bold))
                .foregroundStyle(store.activeFilterCount > 0 ? Color.white : Color.ppTextPrimary)
                .frame(width: filterButtonVisualSize, height: filterButtonVisualSize)
                .background(
                    store.activeFilterCount > 0 ? Color.ppPrimary : Color.ppSurface,
                    in: RoundedRectangle(cornerRadius: filterButtonCornerRadius, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: filterButtonCornerRadius, style: .continuous)
                        .strokeBorder(
                            store.activeFilterCount > 0
                                ? Color.clear
                                : (contrast == .increased ? Color.ppTextPrimary : Color.ppSeparator.opacity(0.5)),
                            lineWidth: contrast == .increased ? 1 : 0.5
                        )
                }
                .overlay(alignment: .topTrailing) {
                    if store.activeFilterCount > 0 {
                        Text("\(store.activeFilterCount)")
                            .font(HomeFont.bold(10))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 4)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Color.ppPrimaryDarker, in: Capsule())
                            .offset(x: store.isRightToLeft ? -2 : 2, y: -2)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(RoundedRectangle(cornerRadius: filterButtonCornerRadius, style: .continuous))
        }
        .buttonStyle(PPMarketplacePressStyle(reduceMotion: interactionMotionIsDisabled))
        .disabled(store.isReplacingContext)
        .opacity(store.isReplacingContext ? 0.55 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PPMarketplaceText.localized("filterPPAction"))
        .accessibilityValue(PPMarketplaceText.formatted(
            "dataview_filters_active_count_accessibility_format",
            store.activeFilterCount
        ))
        .accessibilityHint(PPMarketplaceText.localized("marketplace_filters_open_hint"))
        .accessibilityIdentifier("pp.marketplace.filters")
    }

    private func filterChipTitle(_ group: PPFilterGroup) -> String {
        guard group.isActive(),
              let selected = group.options.first(where: { $0.value == group.selectedValue }) else {
            return group.title
        }
        return selected.title
    }

    private var selectedProviderTitle: String {
        guard let providerID = store.selectedProviderID,
              let provider = store.providerOptions.first(where: { $0.providerID == providerID }) else {
            return PPMarketplaceText.localized("dataview_filter_by_provider")
        }
        return provider.title
    }

    private var horizontalInset: CGFloat {
        horizontalSizeClass == .regular ? PPSpace.xxl : PPSpace.screenMargin
    }

    private var interactionMotionIsDisabled: Bool {
        reduceMotion || switchControlEnabled || voiceOverEnabled || scenePhase != .active
    }
}

@available(iOS 15.0, *)
private struct PPMarketplaceRefinementLabel: View {
    let icon: String
    let title: String
    let selected: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: PPSpace.xs) {
            Image(systemName: selected ? "checkmark" : icon)
                .font(.system(size: 11, weight: .semibold))
                .accessibilityHidden(true)
            Text(title)
                .font(selected ? HomeFont.bold(13) : HomeFont.medium(13))
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .opacity(0.7)
                .accessibilityHidden(true)
        }
        .foregroundStyle(selected ? Color.ppPrimary : Color.ppTextPrimary)
        .padding(.horizontal, PPSpace.md)
        .padding(.vertical, 8)
        .frame(minHeight: 44)
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? 240 : nil)
        .background(
            selected ? Color.ppPrimary.opacity(0.08) : Color.clear,
            in: Capsule(style: .continuous)
        )
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(
                    contrast == .increased
                        ? Color.ppTextPrimary
                        : (selected ? Color.ppPrimary.opacity(0.24) : Color.clear),
                    lineWidth: contrast == .increased ? 1 : 0.5
                )
        }
        .contentShape(Capsule(style: .continuous))
    }
}

@available(iOS 15.0, *)
struct PPMarketplaceUniversalCard: View {
    let record: PPMarketplaceItemRecord
    let section: PPDataSection
    let layout: PPMarketplaceLayout
    let bridge: PPMarketplaceDataViewBridge

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                PPUniversalCardView(
                    viewModel: record.viewModel,
                    delegate: bridge,
                    context: cellContext,
                    layoutMode: universalLayoutMode,
                    discountMode: .badge,
                    imageLoader: nil,
                    hideTopBadge: false,
                    showsSubtitle: true,
                    forceShowsOwnerMenuButton: true,
                    dataViewPresentation: true,
                    isHomePresentation: false,
                    borderMode: .pordersForHomeView,
                    palette: marketplaceCardPalette,
                    onTap: nil,
                    onQuantityChange: nil
                )
            } else {
                PPMarketplaceCompatibilityCard(
                    viewModel: record.viewModel,
                    context: cellContext,
                    layout: layout,
                    bridge: bridge
                )
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("pp.marketplace.item.\(record.id)")
    }

    private var universalLayoutMode: PPManagerCellLayoutMode {
        return layout.universalLayoutMode
    }

    private var marketplaceCardPalette: PPUniversalCardPalette {
        let category = PPMarketplaceAccentPalette(accent: bridge.accentColor)
        var palette = PPUniversalCardPalette.purePets
        palette.primary = category.fill
        palette.primaryDarker = category.darker
        palette.primaryShiner = category.brighter
        palette.onPrimary = .white
        palette.accent = category.fill
        return palette
    }

    private var cellContext: PPCellContext {
        record.viewModel.modelContext
    }
}

@available(iOS 15.0, *)
struct PPMarketplaceFocusCarousel: View {
    let records: [PPMarketplaceItemRecord]
    let bridge: PPMarketplaceDataViewBridge
    let loadMore: (PPMarketplaceItemRecord) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedID: String?
    @State private var previousIDs: [String] = []

    var body: some View {
        TabView(selection: $selectedID) {
            ForEach(records) { record in
                PPMarketplaceUniversalCard(
                    record: record,
                    section: record.section,
                    layout: .focus,
                    bridge: bridge
                )
                .padding(.horizontal, PPSpace.xs)
                .tag(Optional(record.id))
                .onAppear {
                    loadMore(record)
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(
            height: PPMarketplaceContentGeometry.focusHeight(
                isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
            )
        )
        .onAppear {
            previousIDs = records.map(\.id)
            if selectedID == nil {
                selectedID = records.first?.id
            }
        }
        .onChange(of: records.map(\.id)) { ids in
            defer { previousIDs = ids }
            if let selectedID, ids.contains(selectedID) {
                return
            }
            guard !ids.isEmpty else {
                self.selectedID = nil
                return
            }
            let previousIndex = selectedID.flatMap {
                previousIDs.firstIndex(of: $0)
            } ?? 0
            self.selectedID = ids[min(previousIndex, ids.count - 1)]
        }
        .accessibilityLabel(
            PPMarketplaceText.localized("marketplace_focus_layout_accessibility")
        )
    }
}

@available(iOS 15.0, *)
struct PPMarketplaceLoadingState: View {
    let layout: PPMarketplaceLayout
    let availableWidth: CGFloat

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.base) {
            HStack(spacing: PPSpace.sm) {
                ProgressView()
                    .tint(Color(uiColor: UIColor(named: "AppPrimaryColor") ?? .systemPink))
                Text(PPMarketplaceText.localized("marketplace_loading_title"))
                    .font(HomeFont.headline())
                    .foregroundStyle(Color.ppMarketplaceTextPrimary)
            }
            .accessibilityElement(children: .combine)

            if layout == .compact || layout == .showcase {
                LazyVStack(
                    spacing: PPMarketplaceContentGeometry.listSpacing(
                        for: layout
                    )
                ) {
                    ForEach(PPMarketplaceSkeletonSlot.allCases.prefix(4)) { _ in
                        PPMarketplaceSkeletonCard(
                            horizontal: layout == .compact
                                && !dynamicTypeSize.isAccessibilitySize,
                            minimumHeight: skeletonMinimumHeight
                        )
                    }
                }
            } else if layout == .mosaic {
                LazyVGrid(
                    columns: skeletonColumns,
                    spacing: PPSpace.base
                ) {
                    ForEach(PPMarketplaceSkeletonSlot.allCases) { _ in
                        PPMarketplaceSkeletonCard(
                            horizontal: false,
                            minimumHeight: skeletonMinimumHeight
                        )
                    }
                }
            } else {
                PPMarketplaceSkeletonCard(
                    horizontal: false,
                    minimumHeight: skeletonMinimumHeight
                )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PPMarketplaceText.localized("marketplace_loading_title"))
    }

    private var skeletonColumns: [GridItem] {
        let count = PPMarketplaceContentGeometry.mosaicColumnCount(
            availableWidth: availableWidth,
            horizontalSizeClass: horizontalSizeClass,
            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
        )
        return Array(
            repeating: GridItem(.flexible(), spacing: PPSpace.base),
            count: count
        )
    }

    private var skeletonMinimumHeight: CGFloat {
        switch layout {
        case .compact:
            return dynamicTypeSize.isAccessibilitySize ? 540 : 184
        case .showcase, .mosaic:
            return dynamicTypeSize.isAccessibilitySize ? 520 : 340
        case .focus:
            return PPMarketplaceContentGeometry.focusHeight(
                isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
            )
        }
    }
}

@available(iOS 15.0, *)
private enum PPMarketplaceSkeletonSlot: String, CaseIterable, Identifiable {
    case primary
    case secondary
    case tertiary
    case quaternary
    case quinary
    case senary

    var id: String { rawValue }
}

@available(iOS 15.0, *)
private struct PPMarketplaceSkeletonCard: View {
    let horizontal: Bool
    let minimumHeight: CGFloat

    var body: some View {
        Group {
            if horizontal {
                HStack(spacing: PPSpace.md) {
                    skeletonMedia
                        .frame(
                            width: 128,
                            height: max(1, minimumHeight - (PPSpace.sm * 2))
                        )
                    skeletonCopy
                }
                .padding(PPSpace.sm)
            } else {
                VStack(alignment: .leading, spacing: PPSpace.sm) {
                    skeletonMedia
                        .frame(height: max(190, minimumHeight * 0.68))
                    skeletonCopy
                        .padding(.horizontal, PPSpace.sm)
                        .padding(.bottom, PPSpace.sm)
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: minimumHeight,
            alignment: .topLeading
        )
        .background(
            Color.ppMarketplaceSurface,
            in: RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .strokeBorder(Color.ppMarketplaceSeparator.opacity(0.18), lineWidth: 1)
        }
        .redacted(reason: .placeholder)
    }

    private var skeletonMedia: some View {
        RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
            .fill(Color(uiColor: .tertiarySystemFill))
    }

    private var skeletonCopy: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            Text(PPMarketplaceText.localized("marketplace_skeleton_title"))
                .font(HomeFont.bold(16))
            Text(PPMarketplaceText.localized("marketplace_skeleton_subtitle"))
                .font(HomeFont.medium(14))
            Text(PPMarketplaceText.localized("marketplace_skeleton_price"))
                .font(HomeFont.bold(18))
        }
        .foregroundStyle(Color.ppMarketplaceTextSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@available(iOS 15.0, *)
struct PPMarketplaceEmptyState: View {
    let hasFilters: Bool
    let accent: UIColor
    let clearAction: () -> Void
    let retryAction: () -> Void

    var body: some View {
        PPMarketplaceStateSurface(
            icon: hasFilters ? "line.3.horizontal.decrease.circle" : "pawprint.circle",
            title: PPMarketplaceText.localized(
                hasFilters
                    ? "marketplace_filtered_empty_title"
                    : "marketplace_empty_title"
            ),
            message: PPMarketplaceText.localized(
                hasFilters
                    ? "marketplace_filtered_empty_message"
                    : "marketplace_empty_message"
            ),
            actionTitle: PPMarketplaceText.localized(
                hasFilters
                    ? "marketplace_clear_filters"
                    : "empty_retry_button"
            ),
            accent: accent,
            action: hasFilters ? clearAction : retryAction
        )
    }
}

@available(iOS 15.0, *)
enum PPMarketplaceRecoveryKind: Equatable {
    case offline
    case failed
}

@available(iOS 15.0, *)
struct PPMarketplaceRecoveryState: View {
    let kind: PPMarketplaceRecoveryKind
    let message: String
    let accent: UIColor
    let retryAction: () -> Void

    var body: some View {
        PPMarketplaceStateSurface(
            icon: kind == .offline ? "wifi.slash" : "exclamationmark.arrow.triangle.2.circlepath",
            title: PPMarketplaceText.localized(
                kind == .offline
                    ? "marketplace_offline_title"
                    : "marketplace_error_title"
            ),
            message: message.isEmpty
                ? PPMarketplaceText.localized(
                    kind == .offline
                        ? "marketplace_offline_message"
                        : "marketplace_error_message"
                )
                : message,
            actionTitle: PPMarketplaceText.localized("empty_retry_button"),
            accent: accent,
            action: retryAction
        )
    }
}

@available(iOS 15.0, *)
private struct PPMarketplaceStateSurface: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String
    let accent: UIColor
    let action: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    private var accentPalette: PPMarketplaceAccentPalette {
        PPMarketplaceAccentPalette(accent: accent)
    }

    var body: some View {
        VStack(spacing: PPSpace.lg) {
            ZStack {
                Circle()
                    .fill(Color(uiColor: accent).opacity(0.10))
                Image(systemName: icon)
                    .font(.system(size: 31, weight: .semibold))
                    .foregroundStyle(Color(uiColor: accent))
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(width: 82, height: 82)
            .accessibilityHidden(true)

            VStack(spacing: PPSpace.sm) {
                Text(title)
                    .font(HomeFont.bold(20))
                    .foregroundStyle(Color.ppMarketplaceTextPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(HomeFont.medium(15))
                    .foregroundStyle(Color.ppMarketplaceTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: action) {
                Label(actionTitle, systemImage: "arrow.clockwise")
                    .font(HomeFont.bold(16))
                    .foregroundStyle(accentPalette.onAccent)
                    .padding(.horizontal, PPSpace.xl)
                    .frame(minHeight: 50)
                    .background(
                        accentPalette.fill,
                        in: Capsule(style: .continuous)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, PPSpace.xl)
        .padding(.vertical, PPSpace.xxxl)
        .frame(maxWidth: .infinity)
        .background(
            Color.ppMarketplaceSurface,
            in: RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
                .strokeBorder(
                    contrast == .increased
                        ? Color.ppMarketplaceTextPrimary
                        : Color.ppMarketplaceSeparator.opacity(0.22),
                    lineWidth: contrast == .increased ? 2 : 1
                )
        }
    }
}

@available(iOS 15.0, *)
struct PPMarketplaceUpdateErrorBanner: View {
    let message: String
    let retry: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            HStack(alignment: .top, spacing: PPSpace.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.orange)
                    .padding(.top, PPSpace.xs)
                    .accessibilityHidden(true)

                Text(message)
                    .font(HomeFont.medium(14))
                    .foregroundStyle(Color.ppMarketplaceTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: PPSpace.xs)

                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    PPMarketplaceText.localized("marketplace_dismiss")
                )
            }

            Button(action: retry) {
                Label(
                    PPMarketplaceText.localized("empty_retry_button"),
                    systemImage: "arrow.clockwise"
                )
                .font(HomeFont.bold(14))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    Color.orange.opacity(0.10),
                    in: Capsule(style: .continuous)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(PPSpace.md)
        .background(.regularMaterial, in: RoundedRectangle(
            cornerRadius: PPCorner.medium,
            style: .continuous
        ))
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.28), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
        .accessibilityElement(children: .contain)
    }
}

@available(iOS 15.0, *)
private struct PPMarketplacePressStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
