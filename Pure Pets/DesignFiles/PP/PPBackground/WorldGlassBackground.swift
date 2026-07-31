import Combine
import Foundation
import SwiftUI

/// Pure Pets' quiet, living world canvas.
///
/// A berry-led care orbit moves through the upper field while a still lower
/// anchor preserves visual calm around persistent navigation. Motion pauses for
/// Reduce Motion, Low Power Mode, inactive scenes, and server-requested fading.
/// Rendering uses the same Canvas path on iOS 15 and later.
public struct WorldGlassBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.scenePhase) private var scenePhase
    @State private var isLowPowerModeEnabled =
        ProcessInfo.processInfo.isLowPowerModeEnabled

    private let tint: Color
    private let intensity: Double
    private let animatedHeightRatio: CGFloat
    private let isFaded: Bool

    /// - Parameters:
    ///   - tint: Dominant atmospheric tint. Pure Pets defaults to brand berry.
    ///   - intensity: Recommended range is `0.65 ... 1.05`.
    ///   - animatedHeightRatio: Portion of the screen allowed to animate.
    ///   - isFaded: Removes ambient fields while retaining the semantic canvas.
    public init(
        tint: Color = .worldGlassBerry,
        intensity: Double = 0.88,
        animatedHeightRatio: CGFloat = 0.64,
        isFaded: Bool = false
    ) {
        self.tint = tint
        self.intensity = intensity.clamped(to: 0 ... 1.20)
        self.animatedHeightRatio =
            animatedHeightRatio.clamped(to: 0.44 ... 0.72)
        self.isFaded = isFaded
    }

    public var body: some View {
        GeometryReader { proxy in
            let topHeight = min(
                max(proxy.size.height * animatedHeightRatio, 360),
                660
            )
            let animationIsPaused =
                reduceMotion
                || isLowPowerModeEnabled
                || scenePhase != .active
                || isFaded
            let usesCanonicalPhase =
                reduceMotion || isLowPowerModeEnabled

            ZStack(alignment: .top) {
                Color.ppBackground

                ZStack(alignment: .top) {
                    canvasTemperature

                    WorldGlassStaticField(
                        tint: tint,
                        strength: resolvedStrength,
                        isRightToLeft: layoutDirection == .rightToLeft
                    )

                    TimelineView(
                        .animation(
                            minimumInterval: 1.0 / 24.0,
                            paused: animationIsPaused
                        )
                    ) { timeline in
                        WorldGlassLivingField(
                            time: usesCanonicalPhase
                                ? 0
                                : timeline.date
                                    .timeIntervalSinceReferenceDate,
                            tint: tint,
                            strength: resolvedStrength,
                            isRightToLeft:
                                layoutDirection == .rightToLeft
                        )
                        .frame(
                            width: proxy.size.width,
                            height: topHeight
                        )
                        .mask(upperFieldMask)
                    }

                    topSpecularHighlight
                        .frame(height: topHeight * 0.62)
                }
                .opacity(isFaded ? 0 : 1)
                .animation(
                    reduceMotion
                        ? nil
                        : WorldGlassMotion.visibility,
                    value: isFaded
                )
            }
            .frame(
                width: proxy.size.width,
                height: proxy.size.height
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onReceive(
            NotificationCenter.default.publisher(
                for: .NSProcessInfoPowerStateDidChange
            )
        ) { _ in
            isLowPowerModeEnabled =
                ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }

    private var resolvedStrength: Double {
        let transparencyScale = reduceTransparency ? 0.48 : 1.0
        let contrastScale =
            colorSchemeContrast == .increased ? 0.70 : 1.0
        let modeScale = colorScheme == .dark ? 0.76 : 1.0
        return intensity
            * transparencyScale
            * contrastScale
            * modeScale
    }

    private var canvasTemperature: some View {
        LinearGradient(
            colors:
                colorScheme == .dark
                ? [
                    Color.ppElevatedSurface.opacity(0.22),
                    Color.clear,
                    Color.ppSoftRose.opacity(0.10)
                ]
                : [
                    Color.white.opacity(0.34),
                    Color.clear,
                    Color.worldGlassRoseMist.opacity(0.16)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var upperFieldMask: some View {
        LinearGradient(
            stops: [
                .init(color: .black, location: 0.00),
                .init(color: .black, location: 0.50),
                .init(color: .black.opacity(0.90), location: 0.66),
                .init(color: .black.opacity(0.42), location: 0.84),
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
                        (colorScheme == .dark ? 0.025 : 0.20)
                            * resolvedStrength
                    ),
                    location: 0.00
                ),
                .init(
                    color: .white.opacity(
                        (colorScheme == .dark ? 0.012 : 0.055)
                            * resolvedStrength
                    ),
                    location: 0.24
                ),
                .init(color: .clear, location: 1.00)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private enum WorldGlassMotion {
    static let visibility = Animation.timingCurve(
        0.20,
        0,
        0,
        1,
        duration: 0.46
    )
}

/// A convenient root container when the background should sit behind a screen.
public struct WorldGlassScene<Content: View>: View {
    private let tint: Color
    private let intensity: Double
    private let isFaded: Bool
    private let content: Content

    public init(
        tint: Color = .worldGlassBerry,
        intensity: Double = 0.88,
        isFaded: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.tint = tint
        self.intensity = intensity
        self.isFaded = isFaded
        self.content = content()
    }

    public var body: some View {
        ZStack {
            WorldGlassBackground(
                tint: tint,
                intensity: intensity,
                isFaded: isFaded
            )
            content
        }
    }
}

private struct WorldGlassStaticField: View {
    let tint: Color
    let strength: Double
    let isRightToLeft: Bool

    var body: some View {
        Canvas(
            opaque: false,
            colorMode: .linear,
            rendersAsynchronously: true
        ) { context, size in
            WorldGlassDrawing.drawGlow(
                in: &context,
                center: WorldGlassDrawing.point(
                    x: 0.88,
                    y: 0.77,
                    in: size,
                    isRightToLeft: isRightToLeft
                ),
                radius: max(size.width * 0.68, 250),
                color: tint.opacity(0.105 * strength)
            )

            WorldGlassDrawing.drawGlow(
                in: &context,
                center: WorldGlassDrawing.point(
                    x: 0.10,
                    y: 0.64,
                    in: size,
                    isRightToLeft: isRightToLeft
                ),
                radius: max(size.width * 0.54, 220),
                color: Color.worldGlassChampagne.opacity(
                    0.075 * strength
                )
            )
        }
    }
}

private struct WorldGlassLivingField: View {
    let time: TimeInterval
    let tint: Color
    let strength: Double
    let isRightToLeft: Bool

    var body: some View {
        Canvas(
            opaque: false,
            colorMode: .linear,
            rendersAsynchronously: true
        ) { context, size in
            let berryPhase = WorldGlassDrawing.phase(
                time: time,
                duration: 26
            )
            let tealPhase = WorldGlassDrawing.phase(
                time: time,
                duration: 37
            )
            let orbitPhase = WorldGlassDrawing.phase(
                time: time,
                duration: 44
            )

            WorldGlassDrawing.drawGlow(
                in: &context,
                center: WorldGlassDrawing.point(
                    x: 0.16 + (0.045 * sin(berryPhase)),
                    y: 0.13 + (0.026 * cos(tealPhase)),
                    in: size,
                    isRightToLeft: isRightToLeft
                ),
                radius:
                    size.width
                    * (0.54 + (0.018 * sin(tealPhase))),
                color: tint.opacity(0.23 * strength)
            )

            WorldGlassDrawing.drawGlow(
                in: &context,
                center: WorldGlassDrawing.point(
                    x: 0.84 + (0.036 * cos(tealPhase)),
                    y: 0.22 + (0.024 * sin(berryPhase)),
                    in: size,
                    isRightToLeft: isRightToLeft
                ),
                radius:
                    size.width
                    * (0.58 + (0.016 * cos(berryPhase))),
                color: Color.worldGlassTeal.opacity(0.18 * strength)
            )

            WorldGlassDrawing.drawGlow(
                in: &context,
                center: WorldGlassDrawing.point(
                    x: 0.52 + (0.024 * sin(tealPhase)),
                    y: -0.02 + (0.018 * cos(berryPhase)),
                    in: size,
                    isRightToLeft: isRightToLeft
                ),
                radius: size.width * 0.48,
                color: Color.white.opacity(0.24 * strength)
            )

            // The middle field stays deliberately quieter than the lower
            // anchor so content hierarchy remains stable.
            WorldGlassDrawing.drawGlow(
                in: &context,
                center: WorldGlassDrawing.point(
                    x: 0.56 + (0.020 * cos(berryPhase)),
                    y: 0.58 + (0.018 * sin(tealPhase)),
                    in: size,
                    isRightToLeft: isRightToLeft
                ),
                radius: size.width * 0.46,
                color: Color.worldGlassChampagne.opacity(
                    0.070 * strength
                )
            )

            WorldGlassDrawing.drawCareOrbit(
                in: &context,
                size: size,
                phase: orbitPhase,
                tint: tint,
                strength: strength,
                isRightToLeft: isRightToLeft
            )
        }
    }
}

private enum WorldGlassDrawing {
    static func phase(
        time: TimeInterval,
        duration: TimeInterval
    ) -> CGFloat {
        guard duration > 0 else { return 0 }
        let normalized =
            time.truncatingRemainder(dividingBy: duration) / duration
        return CGFloat(normalized) * .pi * 2
    }

    static func drawGlow(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        color: Color
    ) {
        let resolvedRadius = max(radius, 1)
        let rect = CGRect(
            x: center.x - resolvedRadius,
            y: center.y - resolvedRadius,
            width: resolvedRadius * 2,
            height: resolvedRadius * 2
        )

        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: color, location: 0.00),
                    .init(
                        color: color.opacity(0.52),
                        location: 0.34
                    ),
                    .init(
                        color: color.opacity(0.14),
                        location: 0.70
                    ),
                    .init(color: .clear, location: 1.00)
                ]),
                center: center,
                startRadius: 0,
                endRadius: resolvedRadius
            )
        )
    }

    static func drawCareOrbit(
        in context: inout GraphicsContext,
        size: CGSize,
        phase: CGFloat,
        tint: Color,
        strength: Double,
        isRightToLeft: Bool
    ) {
        var path = Path()
        path.move(
            to: point(
                x: -0.12,
                y: 0.18 + (0.012 * sin(phase)),
                in: size,
                isRightToLeft: isRightToLeft
            )
        )
        path.addCurve(
            to: point(
                x: 1.12,
                y: 0.47 + (0.010 * cos(phase)),
                in: size,
                isRightToLeft: isRightToLeft
            ),
            control1: point(
                x: 0.23,
                y: 0.44 + (0.022 * cos(phase)),
                in: size,
                isRightToLeft: isRightToLeft
            ),
            control2: point(
                x: 0.72,
                y: 0.035 + (0.020 * sin(phase)),
                in: size,
                isRightToLeft: isRightToLeft
            )
        )

        let widthScale = min(max(size.width / 390, 0.86), 1.45)
        let start = point(
            x: -0.08,
            y: 0,
            in: size,
            isRightToLeft: isRightToLeft
        )
        let end = point(
            x: 1.08,
            y: 0,
            in: size,
            isRightToLeft: isRightToLeft
        )

        context.stroke(
            path,
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: .clear, location: 0.00),
                    .init(
                        color: tint.opacity(0.028 * strength),
                        location: 0.22
                    ),
                    .init(
                        color: Color.white.opacity(
                            0.075 * strength
                        ),
                        location: 0.49
                    ),
                    .init(
                        color: Color.worldGlassTeal.opacity(
                            0.035 * strength
                        ),
                        location: 0.75
                    ),
                    .init(color: .clear, location: 1.00)
                ]),
                startPoint: start,
                endPoint: end
            ),
            style: StrokeStyle(
                lineWidth: 18 * widthScale,
                lineCap: .round,
                lineJoin: .round
            )
        )

        context.stroke(
            path,
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: .clear, location: 0.02),
                    .init(
                        color: Color.white.opacity(
                            0.18 * strength
                        ),
                        location: 0.38
                    ),
                    .init(
                        color: tint.opacity(0.11 * strength),
                        location: 0.60
                    ),
                    .init(color: .clear, location: 0.98)
                ]),
                startPoint: start,
                endPoint: end
            ),
            style: StrokeStyle(
                lineWidth: 1.15 * widthScale,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }

    static func point(
        x: CGFloat,
        y: CGFloat,
        in size: CGSize,
        isRightToLeft: Bool
    ) -> CGPoint {
        CGPoint(
            x: size.width * (isRightToLeft ? 1 - x : x),
            y: size.height * y
        )
    }
}

public extension Color {
    /// Pure Pets brand berry: `#CB2654`.
    static let worldGlassBerry = Color(
        red: 203.0 / 255.0,
        green: 38.0 / 255.0,
        blue: 84.0 / 255.0
    )

    static let worldGlassRoseMist = Color(
        red: 246.0 / 255.0,
        green: 226.0 / 255.0,
        blue: 232.0 / 255.0
    )

    /// Quiet care teal retained as a supporting environmental role.
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
