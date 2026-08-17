import Combine
import Foundation
import SwiftUI

/// The two intentional motion behaviors supported by the Pure Pets brand mark.
public enum PurePetsBrandMotionMode: Hashable, Sendable {
    /// A single, restrained reveal used after the system launch screen disappears.
    case launch

    /// A low-energy loop used only while the app is actively waiting for work.
    case loading
}

/// A reusable, app-native Pure Pets brand animation.
///
/// Add an image set named `PurePetsMark` to the asset catalog. Prefer the supplied
/// SVG with “Preserve Vector Data” enabled; the transparent PNG is a fallback.
/// The component requires iOS 17 or newer because it uses sensory feedback.
public struct PurePetsBrandMotion: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private let mode: PurePetsBrandMotionMode
    private let size: CGFloat
    private let assetName: String
    private let bundle: Bundle
    private let animationTrigger: Int
    private let accessibilityLabel: LocalizedStringKey
    private let onLaunchCompleted: () -> Void

    @State private var opacity = 1.0
    @State private var scale = 1.0
    @State private var blurRadius = 0.0
    @State private var tilt = Angle.zero
    @State private var sheenProgress = -1.0
    @State private var lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var hapticTrigger = 0
    @State private var completedLaunchTrigger: Int?

    public init(
        mode: PurePetsBrandMotionMode,
        size: CGFloat = 144,
        assetName: String = "PurePetsMark",
        bundle: Bundle = .main,
        animationTrigger: Int = 0,
        accessibilityLabel: LocalizedStringKey = "Pure Pets",
        onLaunchCompleted: @escaping () -> Void = {}
    ) {
        self.mode = mode
        self.size = size
        self.assetName = assetName
        self.bundle = bundle
        self.animationTrigger = animationTrigger
        self.accessibilityLabel = accessibilityLabel
        self.onLaunchCompleted = onLaunchCompleted
    }

    public var body: some View {
        ZStack {
            mark

            if mode == .loading && motionIsAllowed {
                sheen
            }
        }
        .frame(width: size, height: size)
        .opacity(opacity)
        .scaleEffect(scale)
        .blur(radius: blurRadius)
        .rotation3DEffect(
            tilt,
            axis: (x: 0.12, y: 1, z: 0),
            perspective: 0.42
        )
        .compositingGroup()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityValue(mode == .loading ? Text("Loading") : Text("Ready"))
        .accessibilityAddTraits(.isImage)
        .sensoryFeedback(
            .impact(weight: .light, intensity: 0.58),
            trigger: hapticTrigger
        )
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name.NSProcessInfoPowerStateDidChange
            )
        ) { _ in
            lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .task(id: animationKey) {
            await runMotion()
        }
    }

    private var mark: some View {
        Image(assetName, bundle: bundle)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
    }

    private var sheen: some View {
        LinearGradient(
            colors: [
                .clear,
                .white.opacity(0.24),
                .clear,
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: size * 0.28, height: size * 1.35)
        .rotationEffect(.degrees(18))
        .offset(x: size * sheenProgress)
        .mask(mark)
        .blendMode(.screen)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var motionIsAllowed: Bool {
        !reduceMotion && !lowPowerModeEnabled && (scenePhase == .active || UIApplication.shared.applicationState != .background)
    }

    private var animationKey: AnimationKey {
        AnimationKey(
            mode: mode,
            trigger: animationTrigger,
            reduceMotion: reduceMotion,
            lowPowerMode: lowPowerModeEnabled,
            sceneIsActive: scenePhase == .active || UIApplication.shared.applicationState != .background
        )
    }

    @MainActor
    private func runMotion() async {
        setRestingState()

        guard scenePhase == .active || UIApplication.shared.applicationState != .background else { return }

        if mode == .launch,
           completedLaunchTrigger == animationTrigger {
            return
        }

        guard motionIsAllowed else {
            await finishReducedMotionLaunchIfNeeded()
            return
        }

        switch mode {
        case .launch:
            await playLaunch()
        case .loading:
            await playLoadingLoop()
        }
    }

    @MainActor
    private func playLaunch() async {
        setWithoutAnimation {
            opacity = 0
            scale = 0.86
            blurRadius = 8
            tilt = .degrees(-7)
            sheenProgress = -1
        }

        do {
            try await Task.sleep(for: .milliseconds(70))

            withAnimation(.spring(duration: 0.66, bounce: 0.14)) {
                opacity = 1
                scale = 1
                blurRadius = 0
                tilt = .zero
            }

            try await Task.sleep(for: .milliseconds(500))
            hapticTrigger += 1

            try await Task.sleep(for: .milliseconds(260))
            completeLaunch()
        } catch {
            // `.task(id:)` cancellation is expected when the view leaves screen.
        }
    }

    @MainActor
    private func playLoadingLoop() async {
        do {
            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.82)) {
                    scale = 1.024
                    sheenProgress = 1.05
                }
                try await Task.sleep(for: .milliseconds(820))

                withAnimation(.easeInOut(duration: 0.82)) {
                    scale = 1
                    sheenProgress = -1.05
                }
                try await Task.sleep(for: .milliseconds(820))
            }
        } catch {
            // Cancellation stops the loop immediately when loading ends.
        }
    }

    @MainActor
    private func finishReducedMotionLaunchIfNeeded() async {
        guard mode == .launch,
              completedLaunchTrigger != animationTrigger else { return }

        do {
            // Keeps the brand readable without introducing transform motion.
            try await Task.sleep(for: .milliseconds(360))
            completeLaunch()
        } catch {
            // The view disappeared before the handoff.
        }
    }

    @MainActor
    private func completeLaunch() {
        guard completedLaunchTrigger != animationTrigger else { return }
        completedLaunchTrigger = animationTrigger
        onLaunchCompleted()
    }

    @MainActor
    private func setRestingState() {
        setWithoutAnimation {
            opacity = 1
            scale = 1
            blurRadius = 0
            tilt = .zero
            sheenProgress = -1.05
        }
    }

    @MainActor
    private func setWithoutAnimation(_ updates: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, updates)
    }
}

/// Places the animated brand reveal immediately after the static system launch
/// screen, then hands off to the real application root.
public struct PurePetsLaunchGate<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let background: Color
    private let markSize: CGFloat
    private let content: () -> Content

    @State private var showsContent = false

    public init(
        background: Color = Color(red: 0.973, green: 0.973, blue: 0.976),
        markSize: CGFloat = 152,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.background = background
        self.markSize = markSize
        self.content = content
    }

    public var body: some View {
        ZStack {
            if showsContent {
                content()
                    .transition(.opacity)
            } else {
                background
                    .ignoresSafeArea()

                PurePetsBrandMotion(
                    mode: .launch,
                    size: markSize
                ) {
                    if reduceMotion {
                        showsContent = true
                    } else {
                        withAnimation(.easeOut(duration: 0.24)) {
                            showsContent = true
                        }
                    }
                }
            }
        }
    }
}

private struct AnimationKey: Hashable {
    let mode: PurePetsBrandMotionMode
    let trigger: Int
    let reduceMotion: Bool
    let lowPowerMode: Bool
    let sceneIsActive: Bool
}

#Preview("Launch") {
    PurePetsLaunchGate {
        Text("Home")
            .font(.title.bold())
    }
}

#Preview("Loading") {
    ZStack {
        Color(red: 0.973, green: 0.973, blue: 0.976)
            .ignoresSafeArea()

        PurePetsBrandMotion(
            mode: .loading,
            size: 88,
            accessibilityLabel: "Loading Pure Pets"
        )
    }
}
