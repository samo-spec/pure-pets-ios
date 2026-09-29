#if canImport(UIKit)
import PureLensCore
import SwiftUI
import UIKit

public struct PureLensView: View {
    @StateObject private var store: PureLensStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    @MainActor
    public init(module: PureLensModule) {
        _store = StateObject(wrappedValue: PureLensStore(module: module))
    }

    public var body: some View {
        Group {
            if store.cameraAuthorization == .authorized {
                lensExperience
            } else {
                LensPermissionView(
                    authorization: store.cameraAuthorization,
                    theme: store.theme,
                    localeIdentifier: store.localeIdentifier,
                    openSettings: openSettings,
                    dismiss: dismissFeature
                )
            }
        }
        .environment(\.locale, Locale(identifier: store.localeIdentifier))
        .environment(\.layoutDirection, store.isRightToLeft ? .rightToLeft : .leftToRight)
        .task {
            await store.start()
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                store.appBecameActive()
            case .inactive, .background:
                store.suspendForBackground()
            @unknown default:
                break
            }
        }
        .sheet(item: $store.presentation, onDismiss: store.dismissPresentation) { _ in
            LensResultSheet(store: store)
        }
        .alert(
            store.localized("lens.privacy.consent.title"),
            isPresented: $store.showsRemoteProcessingConsent
        ) {
            Button(store.localized("lens.cancel"), role: .cancel) {
                store.cancelRemoteProcessing()
            }
            Button(store.localized("lens.privacy.consent.continue")) {
                store.confirmRemoteProcessing()
            }
        } message: {
            Text(store.remoteProcessingDisclosure)
        }
    }

    private var lensExperience: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                LensCameraScene(
                    store: store,
                    reduceMotion: reduceMotion,
                    reduceTransparency: reduceTransparency,
                    differentiateWithoutColor: differentiateWithoutColor
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    LensTopNavigation(
                        phase: store.scanPhase,
                        theme: store.theme,
                        reduceMotion: reduceMotion,
                        reduceTransparency: reduceTransparency,
                        differentiateWithoutColor: differentiateWithoutColor,
                        increasedContrast: colorSchemeContrast == .increased,
                        phaseAccessibilityLabel: store.localized("lens.phase.accessibility"),
                        closeAccessibilityLabel: store.localized("lens.close"),
                        dismiss: dismissFeature
                    )
                    .padding(.horizontal, LensTopChromeMetrics.screenInset)
                    .padding(.top, LensTopChromeMetrics.edgeSpacing)

                    Spacer()
                }

                LensBottomPrompt(
                    store: store,
                    reduceMotion: reduceMotion,
                    reduceTransparency: reduceTransparency,
                    differentiateWithoutColor: differentiateWithoutColor,
                    maximumHeight: max(0, proxy.size.height
                        - LensTopChromeMetrics.controlSize
                        - 2 * LensTopChromeMetrics.outerPadding
                        - 2 * LensTopChromeMetrics.edgeSpacing
                        - 16)
                )
            }
        }
        .background(store.theme.canvas)
    }

    private func dismissFeature() {
        store.cancelActiveWork()
        store.pauseCamera()
        dismiss()
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

private enum LensTopChromeMetrics {
    static let screenInset: CGFloat = 20
    static let edgeSpacing: CGFloat = 6
    static let maximumWidth: CGFloat = 352
    static let outerPadding: CGFloat = 6
    static let controlSize: CGFloat = 48
    static let controlIconSize: CGFloat = 16
    static let surfaceRadius: CGFloat = 30
    static let elementSpacing: CGFloat = 10
    static let dividerHeight: CGFloat = 24
    static let stageSize: CGFloat = 34
    static let activeStageDisc: CGFloat = 30
    static let reachedStageDisc: CGFloat = 24
    static let connectorWidth: CGFloat = 22
}

private struct LensTopNavigation: View {
    let phase: PureLensScanPhase
    let theme: PureLensTheme
    let reduceMotion: Bool
    let reduceTransparency: Bool
    let differentiateWithoutColor: Bool
    let increasedContrast: Bool
    let phaseAccessibilityLabel: String
    let closeAccessibilityLabel: String
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: LensTopChromeMetrics.elementSpacing) {
            Button(action: dismiss) {
                ZStack {
                    Circle()
                        .fill(theme.textOnCamera.opacity(increasedContrast ? 0.16 : 0.10))

                    Circle()
                        .stroke(
                            theme.textOnCamera.opacity(increasedContrast ? 0.42 : 0.18),
                            lineWidth: increasedContrast ? 1.5 : 1
                        )

                    Image(systemName: "xmark")
                        .font(.system(size: LensTopChromeMetrics.controlIconSize, weight: .bold))
                }
                .frame(
                    width: LensTopChromeMetrics.controlSize,
                    height: LensTopChromeMetrics.controlSize
                )
                .contentShape(Circle())
            }
            .buttonStyle(LensChromeButtonStyle(reduceMotion: reduceMotion))
            .foregroundStyle(theme.textOnCamera)
            .accessibilityLabel(closeAccessibilityLabel)
            .accessibilitySortPriority(2)

            Capsule()
                .fill(theme.textOnCamera.opacity(increasedContrast ? 0.34 : 0.16))
                .frame(width: increasedContrast ? 1.5 : 1, height: LensTopChromeMetrics.dividerHeight)
                .accessibilityHidden(true)

            LensPhaseRail(
                phase: phase,
                tint: theme.recognition,
                warningTint: theme.warningOnCamera,
                dangerTint: theme.danger,
                foreground: theme.textOnCamera,
                differentiateWithoutColor: differentiateWithoutColor,
                increasedContrast: increasedContrast,
                accessibilityLabel: phaseAccessibilityLabel
            )
            .frame(maxWidth: .infinity)
            .accessibilitySortPriority(1)
        }
        .padding(LensTopChromeMetrics.outerPadding)
        .frame(maxWidth: LensTopChromeMetrics.maximumWidth)
        .lensNavigationSurface(
            fallback: theme.cameraChrome,
            accent: activeTint,
            reduceTransparency: reduceTransparency,
            increasedContrast: increasedContrast
        )
        .frame(maxWidth: .infinity)
    }

    private var activeTint: Color {
        switch phase {
        case .unsupported, .uncertain, .taxonomyUnavailable:
            return theme.warningOnCamera
        case .validationFailed:
            return theme.danger
        default:
            return theme.recognition
        }
    }
}

private struct LensPhaseRail: View {
    @Environment(\.layoutDirection) private var layoutDirection

    let phase: PureLensScanPhase
    let tint: Color
    let warningTint: Color
    let dangerTint: Color
    let foreground: Color
    let differentiateWithoutColor: Bool
    let increasedContrast: Bool
    let accessibilityLabel: String

    var body: some View {
        HStack(spacing: 4) {
            phaseNode(symbol: "camera.fill", stage: .camera)
            connector(to: .recognition)
            phaseNode(symbol: "viewfinder", stage: .recognition)
            connector(to: .discovery)
            phaseNode(symbol: "square.grid.2x2.fill", stage: .discovery)
        }
        .frame(minHeight: LensTopChromeMetrics.controlSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private func phaseNode(symbol: String, stage: LensRailStage) -> some View {
        let isActive = currentStage == stage
        let isReached = stage.rawValue <= currentStage.rawValue

        return ZStack {
            if isActive {
                Circle()
                    .fill(activeTint.opacity(0.18))
                    .frame(
                        width: LensTopChromeMetrics.activeStageDisc,
                        height: LensTopChromeMetrics.activeStageDisc
                    )

                Circle()
                    .stroke(
                        differentiateWithoutColor ? foreground.opacity(0.92) : activeTint.opacity(0.48),
                        style: StrokeStyle(
                            lineWidth: differentiateWithoutColor ? 2 : 1,
                            dash: differentiateWithoutColor ? [3, 2] : []
                        )
                    )
                    .frame(
                        width: LensTopChromeMetrics.activeStageDisc,
                        height: LensTopChromeMetrics.activeStageDisc
                    )
            } else if isReached {
                Circle()
                    .fill(activeTint.opacity(increasedContrast ? 0.18 : 0.10))
                    .frame(
                        width: LensTopChromeMetrics.reachedStageDisc,
                        height: LensTopChromeMetrics.reachedStageDisc
                    )
            }

            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(
                    isReached
                        ? activeTint
                        : foreground.opacity(increasedContrast ? 0.64 : 0.42)
                )

            if differentiateWithoutColor, isReached, !isActive {
                Circle()
                    .fill(foreground.opacity(0.92))
                    .frame(width: 4, height: 4)
                    .offset(y: 13)
            }
        }
        .frame(
            width: LensTopChromeMetrics.stageSize,
            height: LensTopChromeMetrics.stageSize
        )
        .accessibilityHidden(true)
    }

    private func connector(to stage: LensRailStage) -> some View {
        let isReached = stage.rawValue <= currentStage.rawValue

        return ZStack(alignment: .leading) {
            Capsule()
                .fill(foreground.opacity(increasedContrast ? 0.28 : 0.14))

            Capsule()
                .fill(activeTint)
                .scaleEffect(
                    x: isReached ? 1 : 0,
                    y: 1,
                    anchor: layoutDirection == .rightToLeft ? .trailing : .leading
                )
        }
        .frame(width: LensTopChromeMetrics.connectorWidth, height: differentiateWithoutColor ? 3 : 2)
        .accessibilityHidden(true)
    }

    private var currentStage: LensRailStage {
        switch phase {
        case .searching:
            return .camera
        case .candidateFound, .confirming, .validating, .confirmed,
             .unsupported, .uncertain, .notAnimal, .taxonomyUnavailable, .validationFailed:
            return .recognition
        case .discovering, .results:
            return .discovery
        }
    }

    private var activeTint: Color {
        switch phase {
        case .unsupported, .uncertain, .taxonomyUnavailable:
            return warningTint
        case .validationFailed:
            return dangerTint
        default:
            return tint
        }
    }
}

private enum LensRailStage: Int {
    case camera
    case recognition
    case discovery
}

private struct LensChromeButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private extension View {
    @ViewBuilder
    func lensNavigationSurface(
        fallback: Color,
        accent: Color,
        reduceTransparency: Bool,
        increasedContrast: Bool
    ) -> some View {
        #if swift(>=6.2)
        if #available(iOS 26.0, *), !reduceTransparency {
            self
                .glassEffect(
                    .regular,
                    in: RoundedRectangle(
                        cornerRadius: LensTopChromeMetrics.surfaceRadius,
                        style: .continuous
                    )
                )
                .lensNavigationOutline(accent: accent, increasedContrast: increasedContrast)
        } else {
            self.lensFallbackNavigationSurface(
                fallback: fallback,
                accent: accent,
                reduceTransparency: reduceTransparency,
                increasedContrast: increasedContrast
            )
        }
        #else
        self.lensFallbackNavigationSurface(
            fallback: fallback,
            accent: accent,
            reduceTransparency: reduceTransparency,
            increasedContrast: increasedContrast
        )
        #endif
    }

    @ViewBuilder
    func lensFallbackNavigationSurface(
        fallback: Color,
        accent: Color,
        reduceTransparency: Bool,
        increasedContrast: Bool
    ) -> some View {
        self
            .background {
                if reduceTransparency {
                    RoundedRectangle(
                        cornerRadius: LensTopChromeMetrics.surfaceRadius,
                        style: .continuous
                    )
                    .fill(fallback)
                } else {
                    ZStack {
                        RoundedRectangle(
                            cornerRadius: LensTopChromeMetrics.surfaceRadius,
                            style: .continuous
                        )
                        .fill(.ultraThinMaterial)

                        RoundedRectangle(
                            cornerRadius: LensTopChromeMetrics.surfaceRadius,
                            style: .continuous
                        )
                        .fill(fallback.opacity(increasedContrast ? 0.62 : 0.48))
                    }
                }
            }
            .lensNavigationOutline(accent: accent, increasedContrast: increasedContrast)
            .shadow(color: Color.black.opacity(0.18), radius: 18, y: 8)
    }

    func lensNavigationOutline(accent: Color, increasedContrast: Bool) -> some View {
        self.overlay {
            RoundedRectangle(
                cornerRadius: LensTopChromeMetrics.surfaceRadius,
                style: .continuous
            )
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(increasedContrast ? 0.46 : 0.28),
                        accent.opacity(increasedContrast ? 0.34 : 0.20),
                        Color.white.opacity(increasedContrast ? 0.18 : 0.08),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: increasedContrast ? 1.5 : 1
            )
        }
    }
}

#if DEBUG
#Preview("Pure Lens - Arabic") {
    PureLensView(module: .demo(localeIdentifier: "ar-EG"))
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Pure Lens - English") {
    PureLensView(module: .demo(localeIdentifier: "en"))
        .environment(\.locale, Locale(identifier: "en"))
        .environment(\.layoutDirection, .leftToRight)
}
#endif

#endif
