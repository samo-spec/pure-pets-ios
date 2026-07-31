import SwiftUI

/// A calm, premium ambient background for the PP home screen.
///
/// The animated light is intentionally confined to the upper portion of the
/// screen. The lower region stays still and visually quiet so a system tab bar
/// or bottom navigation surface never looks like liquid or water.
///
/// Requires iOS 15 or later.
public struct WorldGlassBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    private let tint: Color
    private let intensity: Double
    private let animatedHeightRatio: CGFloat

    /// - Parameters:
    ///   - tint: Main ambient tint. The PP design uses `#5E8F87`.
    ///   - intensity: Recommended range is `0.7 ... 1.15`.
    ///   - animatedHeightRatio: Portion of the screen allowed to animate.
    ///     It is clamped so the lower region always remains calm.
    public init(
        tint: Color = .worldGlassTeal,
        intensity: Double = 0.95,
        animatedHeightRatio: CGFloat = 0.54
    ) {
        self.tint = tint
        self.intensity = intensity.clamped(to: 0 ... 1.35)
        self.animatedHeightRatio = animatedHeightRatio.clamped(to: 0.38 ... 0.62)
    }

    public var body: some View {
        GeometryReader { proxy in
            let topHeight = min(
                max(proxy.size.height * animatedHeightRatio, 330),
                560
            )
            let animationIsPaused = reduceMotion || scenePhase != .active

            ZStack(alignment: .top) {
                baseColor

                TimelineView(
                    .animation(
                        minimumInterval: 1.0 / 30.0,
                        paused: animationIsPaused
                    )
                ) { timeline in
                    TopAmbientLightField(
                        time: animationIsPaused
                            ? 0
                            : timeline.date.timeIntervalSinceReferenceDate,
                        tint: tint,
                        intensity: intensity,
                        reduceTransparency: reduceTransparency
                    )
                    .frame(width: proxy.size.width, height: topHeight)
                    .mask(topFadeMask)
                }

                topSpecularHighlight
                    .frame(height: topHeight * 0.58)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var baseColor: Color {
        if colorScheme == .dark {
            return Color(red: 0.050, green: 0.066, blue: 0.064)
        }

        return Color(red: 0.975, green: 0.970, blue: 0.958)
    }

    private var topFadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .black, location: 0.00),
                .init(color: .black, location: 0.58),
                .init(color: .black.opacity(0.62), location: 0.78),
                .init(color: .clear, location: 1.00)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var topSpecularHighlight: some View {
        LinearGradient(
            stops: [
                .init(
                    color: .white.opacity(
                        colorScheme == .dark ? 0.035 : 0.28
                    ),
                    location: 0.00
                ),
                .init(color: .white.opacity(0.08), location: 0.18),
                .init(color: .clear, location: 1.00)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// A convenient root container when the background should sit behind a screen.
public struct WorldGlassScene<Content: View>: View {
    private let tint: Color
    private let intensity: Double
    private let content: Content

    public init(
        tint: Color = .worldGlassTeal,
        intensity: Double = 0.95,
        @ViewBuilder content: () -> Content
    ) {
        self.tint = tint
        self.intensity = intensity
        self.content = content()
    }

    public var body: some View {
        ZStack {
            WorldGlassBackground(tint: tint, intensity: intensity)
            content
        }
    }
}

private struct TopAmbientLightField: View {
    let time: TimeInterval
    let tint: Color
    let intensity: Double
    let reduceTransparency: Bool

    @ViewBuilder
    var body: some View {
        if #available(iOS 18.0, *) {
            TopMeshLightField(
                time: time,
                tint: tint,
                intensity: intensity,
                reduceTransparency: reduceTransparency
            )
        } else {
            TopCanvasLightField(
                time: time,
                tint: tint,
                intensity: intensity,
                reduceTransparency: reduceTransparency
            )
        }
    }
}

@available(iOS 18.0, *)
private struct TopMeshLightField: View {
    let time: TimeInterval
    let tint: Color
    let intensity: Double
    let reduceTransparency: Bool

    var body: some View {
        let phaseA = Float(time / 21.0) * .pi * 2
        let phaseB = Float(time / 29.0) * .pi * 2
        let transparencyScale = reduceTransparency ? 0.62 : 1.0
        let strength = intensity * transparencyScale

        MeshGradient(
            width: 3,
            height: 3,
            points: [
                .init(0.00, 0.00),
                .init(0.50 + 0.035 * sin(phaseA), 0.00),
                .init(1.00, 0.00),

                .init(0.00, 0.50 + 0.025 * cos(phaseB)),
                .init(
                    0.50 + 0.060 * sin(phaseB),
                    0.46 + 0.040 * cos(phaseA)
                ),
                .init(1.00, 0.50 + 0.030 * sin(phaseA)),

                .init(0.00, 1.00),
                .init(0.50 + 0.025 * cos(phaseB), 1.00),
                .init(1.00, 1.00)
            ],
            colors: [
                Color.worldGlassChampagne.opacity(0.38 * strength),
                Color.white.opacity(0.52 * strength),
                tint.opacity(0.38 * strength),

                Color.white.opacity(0.16 * strength),
                tint.opacity(0.29 * strength),
                Color.worldGlassMist.opacity(0.36 * strength),

                Color.clear,
                Color.white.opacity(0.07 * strength),
                Color.clear
            ]
        )
    }
}

private struct TopCanvasLightField: View {
    let time: TimeInterval
    let tint: Color
    let intensity: Double
    let reduceTransparency: Bool

    var body: some View {
        Canvas(
            opaque: false,
            colorMode: .linear,
            rendersAsynchronously: true
        ) { context, size in
            let slowPhase = CGFloat(time / 21.0) * .pi * 2
            let slowerPhase = CGFloat(time / 29.0) * .pi * 2
            let transparencyScale = reduceTransparency ? 0.62 : 1.0
            let strength = intensity * transparencyScale

            drawGlow(
                in: &context,
                center: CGPoint(
                    x: size.width * (0.73 + 0.07 * sin(slowPhase)),
                    y: size.height * (0.13 + 0.035 * cos(slowerPhase))
                ),
                radius: size.width * (0.58 + 0.025 * sin(slowerPhase)),
                color: tint.opacity(0.28 * strength)
            )

            drawGlow(
                in: &context,
                center: CGPoint(
                    x: size.width * (0.18 + 0.055 * cos(slowerPhase)),
                    y: size.height * (0.28 + 0.040 * sin(slowPhase))
                ),
                radius: size.width * (0.52 + 0.020 * cos(slowPhase)),
                color: Color.worldGlassChampagne.opacity(0.25 * strength)
            )

            drawGlow(
                in: &context,
                center: CGPoint(
                    x: size.width * (0.48 + 0.045 * sin(slowerPhase)),
                    y: size.height * (0.02 + 0.025 * cos(slowPhase))
                ),
                radius: size.width * 0.46,
                color: Color.white.opacity(0.34 * strength)
            )

            drawGlow(
                in: &context,
                center: CGPoint(
                    x: size.width * (0.88 + 0.025 * cos(slowPhase)),
                    y: size.height * (0.48 + 0.025 * sin(slowerPhase))
                ),
                radius: size.width * 0.44,
                color: Color.worldGlassMist.opacity(0.22 * strength)
            )
        }
    }

    private func drawGlow(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        color: Color
    ) {
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )

        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: color, location: 0.00),
                    .init(color: color.opacity(0.56), location: 0.34),
                    .init(color: color.opacity(0.16), location: 0.69),
                    .init(color: .clear, location: 1.00)
                ]),
                center: center,
                startRadius: 0,
                endRadius: radius
            )
        )
    }
}

public extension Color {
    /// PP brand teal: `#5E8F87`.
    static let worldGlassTeal = Color(
        red: 94.0 / 255.0,
        green: 143.0 / 255.0,
        blue: 135.0 / 255.0
    )

    static let worldGlassMist = Color(
        red: 220.0 / 255.0,
        green: 236.0 / 255.0,
        blue: 231.0 / 255.0
    )

    static let worldGlassChampagne = Color(
        red: 244.0 / 255.0,
        green: 235.0 / 255.0,
        blue: 217.0 / 255.0
    )
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

#Preview("World Glass Background") {
    WorldGlassScene {
        VStack(spacing: 16) {
            Text("PP")
                .font(.largeTitle.weight(.bold))

            Text("Your home-screen content goes here")
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
    }
}
