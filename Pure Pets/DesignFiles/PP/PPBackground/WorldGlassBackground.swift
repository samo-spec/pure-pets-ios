import Combine
import Foundation
import SwiftUI
import UIKit

/// Selects which world-glass atmosphere `WorldGlassBackground` renders.
public enum WorldGlassStyle: Equatable {
    /// The original quiet care orbit. Berry-led, top-weighted, unchanged.
    case `default`
    /// A living, non-brand "aurora weave" tuned for the messaging canvas:
    /// cool twilight fields drift the full screen while opaque chat bubbles
    /// keep the transcript legible.
    case messaging
}

/// Pure Pets' quiet, living world canvas.
///
/// The `.default` style keeps a berry-led care orbit moving through the upper
/// field while a still lower anchor preserves visual calm around persistent
/// navigation. The `.messaging` style replaces it with a full-field aurora
/// weave of non-brand cool hues for the conversation surface. Motion pauses for
/// Reduce Motion, Low Power Mode, inactive scenes, and server-requested fading.
/// Both styles render through the same Canvas path on iOS 15 and later.
public struct WorldGlassBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.scenePhase) private var scenePhase
    @State private var isLowPowerModeEnabled =
        ProcessInfo.processInfo.isLowPowerModeEnabled

    private let style: WorldGlassStyle
    private let tint: Color
    private let intensity: Double
    private let animatedHeightRatio: CGFloat
    private let isFaded: Bool

    /// - Parameters:
    ///   - style: Selects the atmosphere. `.default` preserves the original
    ///     berry-led care orbit; `.messaging` renders the non-brand living
    ///     "aurora weave" designed for the conversation canvas.
    ///   - tint: Dominant atmospheric tint for the `.default` style. Pure Pets
    ///     defaults to brand berry. Ignored by `.messaging`, which never paints
    ///     the brand color into the conversation background.
    ///   - intensity: Recommended range is `0.65 ... 1.05`.
    ///   - animatedHeightRatio: Portion of the screen allowed to animate in the
    ///     `.default` style. The `.messaging` style animates the full field.
    ///   - isFaded: Removes ambient fields while retaining the semantic canvas.
    public init(
        style: WorldGlassStyle = .default,
        tint: Color = .worldGlassBerry,
        intensity: Double = 0.88,
        animatedHeightRatio: CGFloat = 0.64,
        isFaded: Bool = true
    ) {
        self.style = style
        self.tint = tint
        self.intensity = intensity.clamped(to: 0 ... 1.20)
        self.animatedHeightRatio =
            animatedHeightRatio.clamped(to: 0.44 ... 0.72)
        self.isFaded = isFaded
    }

    public var body: some View {
        GeometryReader { proxy in
            let animationIsPaused =
                reduceMotion
                || isLowPowerModeEnabled
                || scenePhase != .active
                || isFaded
            let usesCanonicalPhase =
                reduceMotion || isLowPowerModeEnabled

            ZStack(alignment: .top) {
                Color.ppBackground

                Group {
                    switch style {
                    case .default:
                        defaultField(
                            proxy: proxy,
                            animationIsPaused: animationIsPaused,
                            usesCanonicalPhase: usesCanonicalPhase
                        )
                    case .messaging:
                        messagingField(
                            proxy: proxy,
                            animationIsPaused: animationIsPaused,
                            usesCanonicalPhase: usesCanonicalPhase
                        )
                    }
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

    // MARK: - Default care-orbit field (unchanged behavior)

    @ViewBuilder
    private func defaultField(
        proxy: GeometryProxy,
        animationIsPaused: Bool,
        usesCanonicalPhase: Bool
    ) -> some View {
        let topHeight = min(
            max(proxy.size.height * animatedHeightRatio, 360),
            660
        )

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
    }

    // MARK: - Messaging aurora field (non-brand, full-screen, living)

    @ViewBuilder
    private func messagingField(
        proxy: GeometryProxy,
        animationIsPaused: Bool,
        usesCanonicalPhase: Bool
    ) -> some View {
        let isRightToLeft = layoutDirection == .rightToLeft

        ZStack {
            messagingTemperature

            WorldGlassAuroraStaticField(
                strength: resolvedStrength,
                isRightToLeft: isRightToLeft
            )

            TimelineView(
                .animation(
                    minimumInterval: 1.0 / 24.0,
                    paused: animationIsPaused
                )
            ) { timeline in
                WorldGlassAuroraLivingField(
                    time: usesCanonicalPhase
                        ? 0
                        : timeline.date
                            .timeIntervalSinceReferenceDate,
                    strength: resolvedStrength,
                    isRightToLeft: isRightToLeft
                )
                .frame(
                    width: proxy.size.width,
                    height: proxy.size.height
                )
                .mask(auroraCalmMask)
            }

            messagingSpecularHighlight
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

    // MARK: Messaging atmosphere helpers

    /// A depth wash for the messaging canvas using app foreground color.
    private var messagingTemperature: some View {
        LinearGradient(
            colors:
                colorScheme == .dark
                ? [
                    Color.ppForeground.opacity(0.14),
                    Color.clear,
                    Color.ppForeground.opacity(0.08)
                ]
                : [
                    Color.ppForeground.opacity(0.16),
                    Color.clear,
                    Color.ppForeground.opacity(0.11)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Keeps the vertical center of the reading zone a touch calmer than the
    /// top and bottom so drifting light never competes with the transcript.
    private var auroraCalmMask: some View {
        LinearGradient(
            stops: [
                .init(color: .black, location: 0.00),
                .init(color: .black.opacity(0.86), location: 0.40),
                .init(color: .black.opacity(0.74), location: 0.50),
                .init(color: .black.opacity(0.86), location: 0.60),
                .init(color: .black, location: 1.00)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var messagingSpecularHighlight: some View {
        LinearGradient(
            stops: [
                .init(
                    color: .white.opacity(
                        (colorScheme == .dark ? 0.030 : 0.16)
                            * resolvedStrength
                    ),
                    location: 0.00
                ),
                .init(
                    color: .white.opacity(
                        (colorScheme == .dark ? 0.012 : 0.040)
                            * resolvedStrength
                    ),
                    location: 0.18
                ),
                .init(color: .clear, location: 0.52)
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
    private let style: WorldGlassStyle
    private let tint: Color
    private let intensity: Double
    private let isFaded: Bool
    private let content: Content

    public init(
        style: WorldGlassStyle = .default,
        tint: Color = .worldGlassBerry,
        intensity: Double = 0.88,
        isFaded: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.tint = tint
        self.intensity = intensity
        self.isFaded = isFaded
        self.content = content()
    }

    public var body: some View {
        ZStack {
            WorldGlassBackground(
                style: style,
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

/// Persistent, motionless base for the messaging aurora. Two soft cool anchors
/// give the field depth even when animation is paused (inactive scene, Low
/// Persistent, motionless base for the messaging aurora using app foreground color.
private struct WorldGlassAuroraStaticField: View {
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
                    x: 0.20,
                    y: 0.12,
                    in: size,
                    isRightToLeft: isRightToLeft
                ),
                radius: max(size.width * 0.72, 260),
                color: Color.ppForeground.opacity(
                    0.085 * strength
                )
            )

            WorldGlassDrawing.drawGlow(
                in: &context,
                center: WorldGlassDrawing.point(
                    x: 0.82,
                    y: 0.90,
                    in: size,
                    isRightToLeft: isRightToLeft
                ),
                radius: max(size.width * 0.66, 240),
                color: Color.ppForeground.opacity(
                    0.070 * strength
                )
            )
        }
    }
}

/// The living "aurora weave": fields drift on slow Lissajous
/// orbits using app foreground color for background glows.
private struct WorldGlassAuroraLivingField: View {
    let time: TimeInterval
    let strength: Double
    let isRightToLeft: Bool

    var body: some View {
        Canvas(
            opaque: false,
            colorMode: .linear,
            rendersAsynchronously: true
        ) { context, size in
            let driftA = WorldGlassDrawing.phase(time: time, duration: 34)
            let driftB = WorldGlassDrawing.phase(time: time, duration: 41)
            let driftC = WorldGlassDrawing.phase(time: time, duration: 52)
            let driftD = WorldGlassDrawing.phase(time: time, duration: 63)
            let breath = WorldGlassDrawing.phase(time: time, duration: 19)
            let sweep = WorldGlassDrawing.phase(time: time, duration: 47)

            // Signature moment 1 — the whole field breathes gently.
            let breathScale = 1.0 + (0.045 * sin(breath))

            // Upper leading glow
            WorldGlassDrawing.drawGlow(
                in: &context,
                center: WorldGlassDrawing.point(
                    x: 0.18 + (0.060 * sin(driftA)),
                    y: 0.16 + (0.048 * cos(driftB)),
                    in: size,
                    isRightToLeft: isRightToLeft
                ),
                radius: size.width * 0.62 * breathScale,
                color: Color.ppForeground.opacity(0.20 * strength)
            )

            // Upper trailing glow
            WorldGlassDrawing.drawGlow(
                in: &context,
                center: WorldGlassDrawing.point(
                    x: 0.86 + (0.050 * cos(driftB)),
                    y: 0.24 + (0.044 * sin(driftC)),
                    in: size,
                    isRightToLeft: isRightToLeft
                ),
                radius: size.width * 0.58 * breathScale,
                color: Color.ppForeground.opacity(0.17 * strength)
            )

            // Mid field glow
            WorldGlassDrawing.drawGlow(
                in: &context,
                center: WorldGlassDrawing.point(
                    x: 0.50 + (0.100 * sin(driftC)),
                    y: 0.50 + (0.060 * cos(driftA)),
                    in: size,
                    isRightToLeft: isRightToLeft
                ),
                radius: size.width * 0.55 * breathScale,
                color: Color.ppForeground.opacity(0.13 * strength)
            )

            // Lower leading glow
            WorldGlassDrawing.drawGlow(
                in: &context,
                center: WorldGlassDrawing.point(
                    x: 0.16 + (0.050 * cos(driftA)),
                    y: 0.84 + (0.040 * sin(driftB)),
                    in: size,
                    isRightToLeft: isRightToLeft
                ),
                radius: size.width * 0.60 * breathScale,
                color: Color.ppForeground.opacity(0.15 * strength)
            )

            // Lower trailing glow
            WorldGlassDrawing.drawGlow(
                in: &context,
                center: WorldGlassDrawing.point(
                    x: 0.82 + (0.044 * sin(driftB)),
                    y: 0.90 + (0.030 * cos(driftD)),
                    in: size,
                    isRightToLeft: isRightToLeft
                ),
                radius: size.width * 0.50 * breathScale,
                color: Color.ppForeground.opacity(0.10 * strength)
            )

            // Luminous core — a soft near-white lift at the crown.
            WorldGlassDrawing.drawGlow(
                in: &context,
                center: WorldGlassDrawing.point(
                    x: 0.50 + (0.050 * sin(driftB)),
                    y: 0.04 + (0.020 * cos(driftC)),
                    in: size,
                    isRightToLeft: isRightToLeft
                ),
                radius: size.width * 0.50,
                color: Color.white.opacity(0.14 * strength)
            )

            // Signature moment 2 — a silk light-sweep travels across the field.
            WorldGlassDrawing.drawAuroraSweep(
                in: &context,
                size: size,
                phase: sweep,
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

    /// A slow silk of light that travels diagonally across the messaging field.
    /// A wide soft body carries a thin bright core; both stay low-opacity so the
    /// transcript keeps priority. `phase` drives both the vertical undulation and
    /// the position of the bright band along the sweep.
    static func drawAuroraSweep(
        in context: inout GraphicsContext,
        size: CGSize,
        phase: CGFloat,
        strength: Double,
        isRightToLeft: Bool
    ) {
        let yBase: CGFloat = 0.40
        var path = Path()
        path.move(
            to: point(
                x: -0.16,
                y: yBase + (0.12 * sin(phase)),
                in: size,
                isRightToLeft: isRightToLeft
            )
        )
        path.addCurve(
            to: point(
                x: 1.16,
                y: yBase + 0.16 + (0.10 * cos(phase)),
                in: size,
                isRightToLeft: isRightToLeft
            ),
            control1: point(
                x: 0.30,
                y: yBase - 0.16 + (0.12 * cos(phase)),
                in: size,
                isRightToLeft: isRightToLeft
            ),
            control2: point(
                x: 0.72,
                y: yBase + 0.30 + (0.12 * sin(phase)),
                in: size,
                isRightToLeft: isRightToLeft
            )
        )

        let widthScale = min(max(size.width / 390, 0.86), 1.45)

        // Bright band position travels along the sweep with the phase.
        // Keep the moving stops inside fixed margins so every location is
        // finite and strictly ordered on every TimelineView frame:
        // wide body: 0.00 < lead < center < trail < 1.00
        // bright core: 0.02 < lead < trail < 0.98
        let safePhase = phase.isFinite ? phase : 0
        let bandProgress = min(
            max((sin(safePhase) + 1) * 0.5, 0),
            1
        )
        let bandCenter = 0.18 + (0.64 * bandProgress)
        let bandLead = bandCenter - 0.12
        let bandTrail = bandCenter + 0.12
        let coreLead = bandCenter - 0.06
        let coreTrail = bandCenter + 0.06

        let start = point(
            x: -0.10,
            y: 0,
            in: size,
            isRightToLeft: isRightToLeft
        )
        let end = point(
            x: 1.10,
            y: 0,
            in: size,
            isRightToLeft: isRightToLeft
        )

        // Wide soft body.
        context.stroke(
            path,
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: .clear, location: 0.00),
                    .init(
                        color: Color.ppForeground.opacity(
                            0.045 * strength
                        ),
                        location: bandLead
                    ),
                    .init(
                        color: Color.white.opacity(0.060 * strength),
                        location: bandCenter
                    ),
                    .init(
                        color: Color.ppForeground.opacity(
                            0.040 * strength
                        ),
                        location: bandTrail
                    ),
                    .init(color: .clear, location: 1.00)
                ]),
                startPoint: start,
                endPoint: end
            ),
            style: StrokeStyle(
                lineWidth: 22 * widthScale,
                lineCap: .round,
                lineJoin: .round
            )
        )

        // Thin bright core.
        context.stroke(
            path,
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: .clear, location: 0.02),
                    .init(
                        color: Color.white.opacity(0.16 * strength),
                        location: coreLead
                    ),
                    .init(
                        color: Color.ppForeground.opacity(
                            0.090 * strength
                        ),
                        location: coreTrail
                    ),
                    .init(color: .clear, location: 0.98)
                ]),
                startPoint: start,
                endPoint: end
            ),
            style: StrokeStyle(
                lineWidth: 1.3 * widthScale,
                lineCap: .round,
                lineJoin: .round
            )
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

    // MARK: Messaging aurora palette (deliberately non-brand premium light hues)
    //
    // The messaging background must never paint the brand berry (#CB2654) or its
    // rose family. These luminous premium light hues plus one warm cashmere pearl carry the
    // living conversation canvas instead.

    /// Luminous ice periwinkle `#B8C6F5`.
    static let worldGlassAuroraIndigo = Color(
        red: 184.0 / 255.0,
        green: 198.0 / 255.0,
        blue: 245.0 / 255.0
    )

    /// Crystal sky mint `#ACE2EE`.
    static let worldGlassAuroraAqua = Color(
        red: 172.0 / 255.0,
        green: 226.0 / 255.0,
        blue: 238.0 / 255.0
    )

    /// Soft lilac frost `#D8D2FC`.
    static let worldGlassAuroraLilac = Color(
        red: 216.0 / 255.0,
        green: 210.0 / 255.0,
        blue: 252.0 / 255.0
    )

    /// Cashmere pearl sand `#F7F1E8` — a quiet warm light counterweight.
    static let worldGlassAuroraSand = Color(
        red: 247.0 / 255.0,
        green: 241.0 / 255.0,
        blue: 232.0 / 255.0
    )
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

@available(iOS 15.0, *)
private struct PPWorldGlassBackgroundRootView: View {
    let isFaded: Bool

    @State private var isRightToLeft = Language.isRTL()

    var body: some View {
        WorldGlassBackground(
            style: .default,
            isFaded: isFaded
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
@objc(PPWorldGlassBackgroundHostingController)
public final class PPWorldGlassBackgroundHostingController: UIViewController {
    private var hostingController: UIHostingController<PPWorldGlassBackgroundRootView>!

    @objc public var isFaded: Bool {
        didSet {
            updateRootView()
        }
    }

    @objc public init(isFaded: Bool) {
        self.isFaded = isFaded
        super.init(nibName: nil, bundle: nil)
        hostingController = UIHostingController(
            rootView: PPWorldGlassBackgroundRootView(isFaded: isFaded)
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError(
            "PPWorldGlassBackgroundHostingController must be created programmatically."
        )
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isUserInteractionEnabled = false
        view.accessibilityElementsHidden = true

        addChild(hostingController)
        let hostedView = hostingController.view!
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        hostedView.backgroundColor = .clear
        hostedView.isOpaque = false
        hostedView.isUserInteractionEnabled = false
        hostedView.accessibilityElementsHidden = true
        view.addSubview(hostedView)
        NSLayoutConstraint.activate([
            hostedView.topAnchor.constraint(equalTo: view.topAnchor),
            hostedView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostedView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hostingController.didMove(toParent: self)
    }

    @objc public func attach(to parent: UIViewController) {
        guard self.parent == nil,
              let backgroundView = view,
              let parentView = parent.view else {
            return
        }

        parent.addChild(self)
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        parentView.insertSubview(backgroundView, at: 0)
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: parentView.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: parentView.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: parentView.bottomAnchor),
        ])
        didMove(toParent: parent)
    }

    private func updateRootView() {
        guard hostingController != nil else {
            return
        }
        hostingController.rootView = PPWorldGlassBackgroundRootView(
            isFaded: isFaded
        )
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

#Preview("World Glass — Messaging") {
    WorldGlassScene(style: .messaging) {
        VStack(spacing: 12) {
            Spacer()
            ForEach(0 ..< 4) { index in
                HStack {
                    if index.isMultiple(of: 2) { Spacer() }
                    Text(
                        index.isMultiple(of: 2)
                            ? "Message from me"
                            : "Reply from the other side"
                    )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    if !index.isMultiple(of: 2) { Spacer() }
                }
            }
            Spacer()
        }
        .padding()
    }
}
