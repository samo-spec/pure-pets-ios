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

    public init(
        animationEnabled: Bool = true,
        shape: PPWaveCardBGShape = .capsule,
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
            HomeHeroField(
                accent: resolvedAccent,
                increasedContrast: contrast == .increased,
                cornerGlowOpacityScale: 0.72,
                isAnimated: animationEnabled
            )

            Color.ppElevatedSurface.opacity(
                colorScheme == .dark ? 0.18 : 0.42
            )

            cornerSurfaceSpills
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

    private var resolvedAccent: Color {
        guard let accentColorOverride else {
            return .homeBrand
        }
        return Color(uiColor: accentColorOverride)
    }

    private var resolvedBorderWidth: CGFloat {
        guard borderWidth.isFinite else {
            return 0.75
        }
        return max(0.0, borderWidth)
    }

    private var borderStyle: AnyShapeStyle {
        if contrast == .increased {
            return AnyShapeStyle(Color.homeTextPrimary.opacity(0.76))
        }

        let darkMode = colorScheme == .dark
        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    darkMode ? Color.white.opacity(0.16) : Color.white.opacity(0.98),
                    darkMode ? Color.white.opacity(0.12) : Color.white.opacity(0.90),
                    resolvedAccent.opacity(darkMode ? 0.18 : 0.07),
                    darkMode ? Color.white.opacity(0.10) : Color.white.opacity(0.84),
                    darkMode ? Color.white.opacity(0.14) : Color.white.opacity(0.96),
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

    private var cornerSurfaceSpills: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let ovalWidth = min(148.0, max(96.0, width * 0.34))
            let ovalHeight = min(84.0, max(52.0, height * 0.42))
            let spillColor = Color.ppElevatedSurface.opacity(
                colorScheme == .dark ? 0.09 : 0.14
            )

            ZStack(alignment: .topLeading) {
                spill(
                    color: spillColor,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: ovalWidth, height: ovalHeight)
                .offset(
                    x: -(ovalWidth * 0.46),
                    y: -(ovalHeight * 0.48)
                )

                spill(
                    color: spillColor,
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
                .frame(width: ovalWidth, height: ovalHeight)
                .offset(
                    x: width - (ovalWidth * 0.54),
                    y: -(ovalHeight * 0.48)
                )

                spill(
                    color: spillColor,
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                )
                .frame(width: ovalWidth, height: ovalHeight)
                .offset(
                    x: -(ovalWidth * 0.46),
                    y: height - (ovalHeight * 0.52)
                )

                spill(
                    color: spillColor,
                    startPoint: .bottomTrailing,
                    endPoint: .topLeading
                )
                .frame(width: ovalWidth, height: ovalHeight)
                .offset(
                    x: width - (ovalWidth * 0.54),
                    y: height - (ovalHeight * 0.52)
                )
            }
            .opacity(colorScheme == .dark ? 0.58 : 0.64)
        }
        .allowsHitTesting(false)
    }

    private func spill(
        color: Color,
        startPoint: UnitPoint,
        endPoint: UnitPoint
    ) -> some View {
        LinearGradient(
            colors: [color, .clear],
            startPoint: startPoint,
            endPoint: endPoint
        )
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

    @objc public var animationEnabled: Bool {
        didSet {
            updateRootView()
        }
    }

    @objc public var shape: PPWaveCardBGShape {
        didSet {
            updateRootView()
        }
    }

    @objc public var cornerRadius: CGFloat {
        didSet {
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
                animationEnabled: animationEnabled,
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

    private func updateRootView() {
        guard hostingController != nil else {
            return
        }
        hostingController.rootView = PPWaveCardBGRootView(
            animationEnabled: animationEnabled,
            shape: shape,
            cornerRadius: cornerRadius,
            accentColorOverride: accentColorOverride,
            borderWidth: borderWidth
        )
    }
}
