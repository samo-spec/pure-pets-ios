//
//  PPWaveCardBG.swift
//  Pure Pets
//
//  Reusable background-only card material shared by premium UIKit surfaces.
//

import SwiftUI
import UIKit

@objc public enum PPWaveCardBGShape: Int {
    case rounded = 0
    case capsule = 1
    case circle = 2
}

@available(iOS 15.0, *)
public struct PPWaveCardBG: View {
    public var animationEnabled: Bool
    public var shape: PPWaveCardBGShape
    public var cornerRadius: CGFloat
    public var accentColorOverride: UIColor?
    public var borderWidth: CGFloat

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    public init(
        animationEnabled: Bool = true,
        shape: PPWaveCardBGShape = .rounded,
        cornerRadius: CGFloat = 28.0,
        accentColorOverride: UIColor? = nil,
        borderWidth: CGFloat = 0.125
    ) {
        self.animationEnabled = animationEnabled
        self.shape = shape
        self.cornerRadius = cornerRadius
        self.accentColorOverride = accentColorOverride
        self.borderWidth = borderWidth
    }

    public var body: some View {
        switch shape {
        case .capsule:
            renderedSurface(in: Capsule())
        case .circle:
            renderedSurface(in: Circle())
        case .rounded:
            renderedSurface(
                in: RoundedRectangle(
                    cornerRadius: max(0.0, cornerRadius),
                    style: .continuous
                )
            )
        }
    }

    @ViewBuilder
    private func renderedSurface<S: InsettableShape>(in cardShape: S) -> some View {
        ZStack {
            cardShape.fill(surfaceStyle)
            ambientFields

            PPWaveCardPawPressureField(
                accent: resolvedAccent,
                isAnimated: allowsAmbientMotion,
                isRightToLeft: layoutDirection == .rightToLeft,
                isDark: colorScheme == .dark,
                increasedContrast: contrast == .increased
            )

            surfaceVeil
        }
        .clipShape(cardShape)
        .overlay {
            cardShape.strokeBorder(
                borderStyle,
                lineWidth: contrast == .increased
                    ? max(1.5, resolvedBorderWidth)
                    : resolvedBorderWidth
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var allowsAmbientMotion: Bool {
        animationEnabled
            && !reduceMotion
            && contrast != .increased
            && scenePhase == .active
    }

    private var resolvedAccent: Color {
        guard let accentColorOverride else {
            return .ppPrimaryDarker
        }
        return Color(uiColor: accentColorOverride)
    }

    private var resolvedBorderWidth: CGFloat {
        guard borderWidth.isFinite else {
            return 0.125
        }
        return max(0.0, borderWidth)
    }

    private var borderStyle: AnyShapeStyle {
        if contrast == .increased {
            return AnyShapeStyle(Color.ppTextPrimary.opacity(0.54))
        }

        let darkMode = colorScheme == .dark
        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color.white.opacity(darkMode ? 0.22 : 0.96),
                    Color.ppSurfaceBorder.opacity(darkMode ? 0.76 : 0.48),
                    Color.ppSurfaceBorder.opacity(darkMode ? 0.62 : 0.36),
                    Color.white.opacity(darkMode ? 0.13 : 0.90),
                ],
                startPoint: layoutDirection == .rightToLeft
                    ? .topTrailing
                    : .topLeading,
                endPoint: layoutDirection == .rightToLeft
                    ? .bottomLeading
                    : .bottomTrailing
            )
        )
    }

    private var surfaceStyle: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    .ppSurfaceRaised,
                    .ppElevatedSurface,
                    .ppSecondarySurface,
                ]
                : [
                    .ppElevatedSurface,
                    .ppSurfaceRaised,
                    .ppWarmPorcelain,
                ],
            startPoint: layoutDirection == .rightToLeft
                ? .topTrailing
                : .topLeading,
            endPoint: layoutDirection == .rightToLeft
                ? .bottomLeading
                : .bottomTrailing
        )
    }

    private var ambientFields: some View {
        ZStack {
            RadialGradient(
                colors: [
                    resolvedAccent.opacity(colorScheme == .dark ? 0.10 : 0.060),
                    resolvedAccent.opacity(colorScheme == .dark ? 0.025 : 0.012),
                    .clear,
                ],
                center: layoutDirection == .rightToLeft
                    ? UnitPoint(x: 0.17, y: 0.48)
                    : UnitPoint(x: 0.83, y: 0.48),
                startRadius: 0,
                endRadius: 150
            )

            RadialGradient(
                colors: [
                    Color.ppWarmPorcelain.opacity(colorScheme == .dark ? 0.10 : 0.34),
                    .clear,
                ],
                center: layoutDirection == .rightToLeft
                    ? UnitPoint(x: 0.88, y: 0.16)
                    : UnitPoint(x: 0.12, y: 0.16),
                startRadius: 0,
                endRadius: 150
            )
        }
    }

    private var surfaceVeil: some View {
        LinearGradient(
            colors: [
                Color.ppElevatedSurface.opacity(colorScheme == .dark ? 0.02 : 0.18),
                .clear,
                Color.ppSurfaceRaised.opacity(colorScheme == .dark ? 0.08 : 0.16),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

@available(iOS 15.0, *)
private struct PPWaveCardPawPressureField: View {
    let accent: Color
    let isAnimated: Bool
    let isRightToLeft: Bool
    let isDark: Bool
    let increasedContrast: Bool

    @State private var isSettled = true
    @State private var settledToeCount = 4
    @State private var isBreathing = false

    var body: some View {
        GeometryReader { proxy in
            let wideCard = proxy.size.width > (proxy.size.height * 1.35)
            let scaleBasis = min(
                proxy.size.height,
                proxy.size.width * (wideCard ? 0.42 : 0.72)
            )
            let imprintSize = min(108.0, max(42.0, scaleBasis * 0.60))
            let unmirroredX = proxy.size.width * (wideCard ? 0.17 : 0.50)
            let centerX = isRightToLeft
                ? unmirroredX
                : proxy.size.width - unmirroredX

            ZStack {
                ZStack {
                    pressureHalo(imprintSize: imprintSize)

                    PPWaveCardPawImprint(
                        accent: accent,
                        size: imprintSize,
                        isDark: isDark,
                        isSettled: isSettled,
                        settledToeCount: settledToeCount
                    )
                }
                .frame(width: imprintSize * 1.34, height: imprintSize * 1.22)
                .scaleEffect(isBreathing ? 1.006 : 1.0)
                .opacity(isBreathing ? 1.0 : 0.94)
                .position(x: centerX, y: proxy.size.height * 0.48)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .mask(contentFadeMask(wideCard: wideCard))
        }
        .opacity(increasedContrast ? 0.64 : 1.0)
        .task(id: isAnimated) {
            await runMotion()
        }
    }

    private func pressureHalo(imprintSize: CGFloat) -> some View {
        RadialGradient(
            colors: [
                accent.opacity(isDark ? 0.075 : 0.038),
                accent.opacity(isDark ? 0.020 : 0.009),
                .clear,
            ],
            center: .center,
            startRadius: 0,
            endRadius: imprintSize * 0.70
        )
        .frame(width: imprintSize * 1.34, height: imprintSize * 1.18)
        .scaleEffect(isSettled ? 1.0 : 0.94)
        .opacity(isSettled ? (isBreathing ? 1.0 : 0.82) : 0.30)
    }

    private func contentFadeMask(wideCard: Bool) -> LinearGradient {
        guard wideCard else {
            return LinearGradient(
                colors: [.white, .white],
                startPoint: UnitPoint(x: 0.0, y: 0.5),
                endPoint: UnitPoint(x: 1.0, y: 0.5)
            )
        }

        let stops: [Gradient.Stop]
        if isRightToLeft {
            stops = [
                .init(color: .white, location: 0.00),
                .init(color: .white, location: 0.28),
                .init(color: .clear, location: 0.50),
                .init(color: .clear, location: 1.00),
            ]
        } else {
            stops = [
                .init(color: .clear, location: 0.00),
                .init(color: .clear, location: 0.50),
                .init(color: .white, location: 0.72),
                .init(color: .white, location: 1.00),
            ]
        }
        return LinearGradient(
            stops: stops,
            startPoint: UnitPoint(x: 0.0, y: 0.5),
            endPoint: UnitPoint(x: 1.0, y: 0.5)
        )
    }

    @MainActor
    private func runMotion() async {
        guard isAnimated else {
            setFullySettledWithoutAnimation()
            return
        }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isSettled = false
            settledToeCount = 0
            isBreathing = false
        }

        guard await wait(seconds: 0.05) else { return }
        withAnimation(.easeOut(duration: 0.48)) {
            isSettled = true
        }

        guard await wait(seconds: 0.07) else { return }
        for toeCount in 1...4 {
            withAnimation(.easeOut(duration: 0.30)) {
                settledToeCount = toeCount
            }
            if toeCount < 4 {
                guard await wait(seconds: 0.045) else { return }
            }
        }

        guard await wait(seconds: 6.50) else { return }
        while !Task.isCancelled {
            withAnimation(.easeInOut(duration: 0.85)) {
                isBreathing = true
            }
            guard await wait(seconds: 0.85) else { return }

            withAnimation(.easeInOut(duration: 1.15)) {
                isBreathing = false
            }
            guard await wait(seconds: 7.65) else { return }
        }
    }

    @MainActor
    private func setFullySettledWithoutAnimation() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isSettled = true
            settledToeCount = 4
            isBreathing = false
        }
    }

    private func wait(seconds: TimeInterval) async -> Bool {
        do {
            try await Task.sleep(
                nanoseconds: UInt64(seconds * 1_000_000_000.0)
            )
            return !Task.isCancelled
        } catch {
            return false
        }
    }
}

@available(iOS 15.0, *)
private struct PPWaveCardPawImprint: View {
    let accent: Color
    let size: CGFloat
    let isDark: Bool
    let isSettled: Bool
    let settledToeCount: Int

    private let toes = [
        PPWaveCardToe(offsetX: -0.25, offsetY: -0.17, width: 0.12, height: 0.18, rotation: -0.32, depth: 0.82),
        PPWaveCardToe(offsetX: -0.09, offsetY: -0.28, width: 0.15, height: 0.21, rotation: -0.12, depth: 0.94),
        PPWaveCardToe(offsetX: 0.08, offsetY: -0.30, width: 0.14, height: 0.22, rotation: 0.08, depth: 0.98),
        PPWaveCardToe(offsetX: 0.24, offsetY: -0.19, width: 0.12, height: 0.18, rotation: 0.28, depth: 0.84),
    ]

    var body: some View {
        ZStack {
            PPWaveCardEmbossedPad(
                shape: PPWaveCardPalmReliefShape(),
                accent: accent,
                isDark: isDark,
                depth: 1.0
            )
            .frame(width: size * 0.46, height: size * 0.34)
            .rotationEffect(.degrees(-7.0))
            .offset(x: -size * 0.01, y: size * 0.14)
            .scaleEffect(isSettled ? 1.0 : 0.985)
            .opacity(isSettled ? 1.0 : 0.46)

            ForEach(Array(toes.enumerated()), id: \.offset) { index, toe in
                let toeIsSettled = index < settledToeCount
                PPWaveCardEmbossedPad(
                    shape: Ellipse(),
                    accent: accent,
                    isDark: isDark,
                    depth: toe.depth
                )
                .frame(width: size * toe.width, height: size * toe.height)
                .rotationEffect(.radians(toe.rotation))
                .offset(x: size * toe.offsetX, y: size * toe.offsetY)
                .scaleEffect(toeIsSettled ? 1.0 : 0.975)
                .opacity(toeIsSettled ? 1.0 : 0.38)
            }
        }
        .frame(width: size, height: size)
    }
}

@available(iOS 15.0, *)
private struct PPWaveCardEmbossedPad<PadShape: Shape>: View {
    let shape: PadShape
    let accent: Color
    let isDark: Bool
    let depth: Double

    var body: some View {
        shape
            .fill(
                RadialGradient(
                    colors: [
                        Color.ppElevatedSurface.opacity(isDark ? 0.16 : 0.70),
                        accent.opacity((isDark ? 0.085 : 0.045) * depth),
                        Color.ppWarmPorcelain.opacity(isDark ? 0.08 : 0.30),
                    ],
                    center: UnitPoint(x: 0.0, y: 0.0),
                    startRadius: 0,
                    endRadius: 42
                )
            )
            .overlay {
                shape.stroke(
                    accent.opacity((isDark ? 0.065 : 0.026) * depth),
                    lineWidth: 0.45
                )
            }
            .shadow(
                color: Color.white.opacity((isDark ? 0.07 : 0.54) * depth),
                radius: 1.5,
                x: -0.8,
                y: -0.8
            )
            .shadow(
                color: Color.black.opacity((isDark ? 0.31 : 0.055) * depth),
                radius: isDark ? 2.4 : 1.9,
                x: 1.2,
                y: 1.4
            )
    }
}

private struct PPWaveCardToe {
    let offsetX: CGFloat
    let offsetY: CGFloat
    let width: CGFloat
    let height: CGFloat
    let rotation: Double
    let depth: Double
}

@available(iOS 15.0, *)
private struct PPWaveCardPalmReliefShape: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(
                x: rect.minX + (rect.width * x),
                y: rect.minY + (rect.height * y)
            )
        }

        var path = Path()
        path.move(to: point(0.50, 0.16))
        path.addCurve(
            to: point(0.82, 0.35),
            control1: point(0.64, -0.02),
            control2: point(0.87, 0.08)
        )
        path.addCurve(
            to: point(0.72, 0.73),
            control1: point(0.98, 0.49),
            control2: point(0.91, 0.71)
        )
        path.addCurve(
            to: point(0.61, 0.83),
            control1: point(0.68, 0.82),
            control2: point(0.65, 0.85)
        )
        path.addCurve(
            to: point(0.50, 0.74),
            control1: point(0.57, 0.84),
            control2: point(0.54, 0.75)
        )
        path.addCurve(
            to: point(0.39, 0.83),
            control1: point(0.46, 0.75),
            control2: point(0.43, 0.84)
        )
        path.addCurve(
            to: point(0.28, 0.73),
            control1: point(0.35, 0.85),
            control2: point(0.32, 0.82)
        )
        path.addCurve(
            to: point(0.18, 0.35),
            control1: point(0.09, 0.71),
            control2: point(0.02, 0.49)
        )
        path.addCurve(
            to: point(0.50, 0.16),
            control1: point(0.13, 0.08),
            control2: point(0.36, -0.02)
        )
        path.closeSubpath()
        return path
    }
}

@available(iOS 15.0, *)
private struct PPWaveCardBGRootView: View {
    let animationEnabled: Bool
    let shape: PPWaveCardBGShape
    let cornerRadius: CGFloat
    let accentColorOverride: UIColor?
    let borderWidth: CGFloat

    @State private var isRightToLeft = Language.isRTL()

    var body: some View {
        PPWaveCardBG(
            animationEnabled: animationEnabled,
            shape: shape,
            cornerRadius: cornerRadius,
            accentColorOverride: accentColorOverride,
            borderWidth: borderWidth
        )
        .environment(
            \.layoutDirection,
            isRightToLeft ? .rightToLeft : .leftToRight
        )
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("LanguageDidChangeNotification")
            )
        ) { _ in
            isRightToLeft = Language.isRTL()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("PPLanguageDidChangeNotification")
            )
        ) { _ in
            isRightToLeft = Language.isRTL()
        }
    }
}

@available(iOS 15.0, *)
@MainActor
@objc(PPWaveCardBGHostingController)
public final class PPWaveCardBGHostingController: UIViewController {
    private var hostingController: UIHostingController<PPWaveCardBGRootView>!
    private var isVisible = false

    @objc public var animationEnabled: Bool {
        didSet {
            guard animationEnabled != oldValue else { return }
            updateRootView()
        }
    }

    @objc public var shape: PPWaveCardBGShape {
        didSet {
            guard shape != oldValue else { return }
            updateRootView()
        }
    }

    @objc public var cornerRadius: CGFloat {
        didSet {
            guard cornerRadius != oldValue else { return }
            updateRootView()
        }
    }

    @objc public var accentColorOverride: UIColor? {
        didSet {
            updateRootView()
        }
    }

    @objc public var borderWidth: CGFloat {
        didSet {
            guard borderWidth != oldValue else { return }
            updateRootView()
        }
    }

    @objc public init(
        animationEnabled: Bool,
        shape: PPWaveCardBGShape,
        cornerRadius: CGFloat,
        accentColorOverride: UIColor?
    ) {
        self.animationEnabled = animationEnabled
        self.shape = shape
        self.cornerRadius = cornerRadius
        self.accentColorOverride = accentColorOverride
        self.borderWidth = 0.75
        super.init(nibName: nil, bundle: nil)
        hostingController = UIHostingController(
            rootView: PPWaveCardBGRootView(
                animationEnabled: false,
                shape: shape,
                cornerRadius: cornerRadius,
                accentColorOverride: accentColorOverride,
                borderWidth: borderWidth
            )
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("PPWaveCardBGHostingController must be created programmatically.")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        addChild(hostingController)
        let hostedView = hostingController.view!
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        hostedView.backgroundColor = .clear
        hostedView.isUserInteractionEnabled = false
        view.addSubview(hostedView)
        NSLayoutConstraint.activate([
            hostedView.topAnchor.constraint(equalTo: view.topAnchor),
            hostedView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostedView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hostingController.didMove(toParent: self)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isVisible = true
        updateRootView()
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isVisible = false
        updateRootView()
    }

    private func updateRootView() {
        guard hostingController != nil else {
            return
        }
        hostingController.rootView = PPWaveCardBGRootView(
            animationEnabled: animationEnabled && isVisible,
            shape: shape,
            cornerRadius: cornerRadius,
            accentColorOverride: accentColorOverride,
            borderWidth: borderWidth
        )
    }
}
