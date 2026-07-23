import SwiftUI

/// Central motion language for the pet-ad viewer.
///
/// Every animation in the feature resolves to one of these tokens so the
/// screen moves with a single, physically coherent voice. Durations and
/// springs are tuned for 120 Hz: fast enough to feel instant, soft enough
/// to feel expensive.
enum PPPetAdViewerMotion {
    /// Tactile press feedback — immediate, weighty.
    static let press = Animation.easeOut(duration: 0.14)

    /// Standard content appearance.
    static let content = Animation.easeOut(duration: 0.28)

    /// Gentle expansion for collapsible content.
    static let expansion = Animation.spring(
        response: 0.38,
        dampingFraction: 0.86,
        blendDuration: 0.08
    )

    /// Navigation chrome morphing — confident, no overshoot.
    static let navigation = Animation.spring(
        response: 0.44,
        dampingFraction: 0.88,
        blendDuration: 0.10
    )

    /// Toast entry/exit — snappy with a whisper of spring.
    static let toast = Animation.spring(
        response: 0.34,
        dampingFraction: 0.84,
        blendDuration: 0.06
    )

    /// Hero gallery page change — fluid, physically grounded.
    static let heroPage = Animation.spring(
        response: 0.40,
        dampingFraction: 0.90,
        blendDuration: 0.08
    )

    /// Favorite heart pop — playful overshoot, the one joyful moment.
    static let heartPop = Animation.spring(
        response: 0.32,
        dampingFraction: 0.52,
        blendDuration: 0.05
    )

    /// Sheet content cascade — soft rise, no bounce.
    static let cascade = Animation.spring(
        response: 0.50,
        dampingFraction: 0.92,
        blendDuration: 0.08
    )

    /// Media viewer dismiss drag — responsive spring-back.
    static let dismissSpring = Animation.spring(
        response: 0.36,
        dampingFraction: 0.86,
        blendDuration: 0.06
    )

    /// Skeleton shimmer sweep — steady, calming 1.5 s cycle.
    static let shimmer = Animation.linear(duration: 1.5)
        .repeatForever(autoreverses: false)

    /// State view entrance — gentle settle, no overshoot.
    static let stateEntrance = Animation.spring(
        response: 0.40,
        dampingFraction: 0.86,
        blendDuration: 0.08
    )

    /// Error state subtle shake — alerting but not alarming.
    static let errorShake = Animation.easeOut(duration: 0.30)

    /// Skeleton → content crossfade.
    static let skeletonFade = Animation.easeOut(duration: 0.35)

    /// Staggered cascade for a section at `index` (0-based).
    static func cascadeDelay(_ index: Int) -> Animation {
        cascade.delay(0.04 + Double(index) * 0.055)
    }
}

// MARK: - Equatable change observation (iOS 15+ compatibility)

extension View {
    /// Cross-version `onChange` that silences the iOS 17 deprecation of the
    /// single-parameter `onChange(of:perform:)` without dropping iOS 15
    /// support. On iOS 17+ it routes through the two-parameter closure; on
    /// earlier releases it uses the original `perform:` form. Behavior is
    /// identical on every OS — the action always receives the new value.
    @ViewBuilder
    func adOnChange<V: Equatable>(
        of value: V,
        perform action: @escaping (V) -> Void
    ) -> some View {
        if #available(iOS 17, *) {
            onChange(of: value) { _, newValue in
                action(newValue)
            }
        } else {
            onChange(of: value, perform: action)
        }
    }
}
