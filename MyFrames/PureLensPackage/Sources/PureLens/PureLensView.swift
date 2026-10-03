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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
        // The live camera is intentionally dark in either app appearance. Let
        // permission and result surfaces retain their normal adaptive theme.
        .preferredColorScheme(
            store.cameraAuthorization == .authorized && store.presentation == nil ? .dark : nil
        )
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
        VStack(spacing: 16) {
            LensTopNavigation(
                theme: store.theme,
                title: store.localized("lens.camera.title"),
                subtitle: store.localized("lens.camera.subtitle"),
                closeLabel: store.localized("lens.close"),
                reduceMotion: reduceMotion,
                increasedContrast: colorSchemeContrast == .increased,
                dismiss: dismissFeature
            )

            GeometryReader { proxy in
                // Use the available window, not the device idiom: iPad Split View
                // and a landscape iPhone can each need the opposite composition.
                let usesSidePanel = proxy.size.width >= 700
                    && !dynamicTypeSize.isAccessibilitySize
                if usesSidePanel {
                    HStack(alignment: .top, spacing: 20) {
                        cameraViewport
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        instructionPanel(maximumHeight: proxy.size.height, isSidePanel: true)
                            .frame(width: min(380, proxy.size.width * 0.40))
                    }
                } else {
                    VStack(spacing: 12) {
                        cameraViewport
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        instructionPanel(
                            maximumHeight: min(
                                proxy.size.height * (dynamicTypeSize.isAccessibilitySize ? 0.68 : 0.48),
                                dynamicTypeSize.isAccessibilitySize ? proxy.size.height : 280
                            ),
                            fillsAvailableHeight: true
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(store.theme.cameraChrome.ignoresSafeArea())
    }

    private var cameraViewport: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                // The semantic rail lives outside the physical camera coordinate
                // space. Labels mirror in Arabic; the camera image never does.
                if proxy.size.height >= 200, !dynamicTypeSize.isAccessibilitySize {
                    LensPhaseRail(
                        phase: store.scanPhase,
                        isPaused: store.isCameraInterrupted
                            || store.didDeclineRemoteProcessingForCurrentDetection,
                        theme: store.theme,
                        labels: [
                            store.localized("lens.stage.camera"),
                            store.localized("lens.stage.recognition"),
                            store.localized("lens.stage.discovery")
                        ],
                        accessibilityLabel: store.localized("lens.phase.accessibility"),
                        pausedLabel: store.localized("lens.stage.paused"),
                        increasedContrast: colorSchemeContrast == .increased
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(store.theme.cameraChrome)
                }

                LensCameraScene(
                    store: store,
                    reduceMotion: reduceMotion,
                    reduceTransparency: reduceTransparency,
                    differentiateWithoutColor: differentiateWithoutColor
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    store.theme.textOnCamera.opacity(colorSchemeContrast == .increased ? 0.42 : 0.16),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
        }
    }

    private func instructionPanel(
        maximumHeight: CGFloat,
        isSidePanel: Bool = false,
        fillsAvailableHeight: Bool = false
    ) -> some View {
        LensBottomPrompt(
            store: store,
            reduceMotion: reduceMotion,
            reduceTransparency: reduceTransparency,
            differentiateWithoutColor: differentiateWithoutColor,
            maximumHeight: max(0, maximumHeight),
            isSidePanel: isSidePanel,
            fillsAvailableHeight: fillsAvailableHeight
        )
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

private struct LensTopNavigation: View {
    let theme: PureLensTheme
    let title: String
    let subtitle: String
    let closeLabel: String
    let reduceMotion: Bool
    let increasedContrast: Bool
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(theme.typography.title2)
                    .foregroundStyle(theme.textOnCamera)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.textOnCamera.opacity(0.78))
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.textOnCamera)
                    .frame(width: 48, height: 48)
                    .background(theme.textOnCamera.opacity(0.10), in: Circle())
                    .overlay {
                        Circle().stroke(
                            theme.textOnCamera.opacity(increasedContrast ? 0.50 : 0.18),
                            lineWidth: 1
                        )
                    }
                    .contentShape(Circle())
            }
            .buttonStyle(LensChromeButtonStyle(reduceMotion: reduceMotion))
            .accessibilityLabel(closeLabel)
            .keyboardShortcut(.cancelAction)
        }
    }
}

private struct LensPhaseRail: View {
    let phase: PureLensScanPhase
    let isPaused: Bool
    let theme: PureLensTheme
    let labels: [String]
    let accessibilityLabel: String
    let pausedLabel: String
    let increasedContrast: Bool

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<3) { index in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: symbol(for: index))
                            .font(.system(size: 11, weight: .semibold))
                        Text(labels[index])
                            .font(theme.typography.captionEmphasized)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(
                        index == currentStage ? theme.textOnCamera
                            : theme.textOnCamera.opacity(increasedContrast ? 0.82 : 0.68)
                    )
                    Capsule()
                        .fill(index <= currentStage ? accent : theme.textOnCamera.opacity(0.16))
                        .frame(height: index == currentStage ? 3 : 1)
                        .frame(height: 3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isPaused ? pausedLabel : labels[currentStage])
    }

    private func symbol(for index: Int) -> String {
        if isPaused, index == currentStage { return "pause.fill" }
        if index < currentStage { return "checkmark" }
        switch index {
        case 0: return "camera"
        case 1: return "viewfinder"
        default: return "square.grid.2x2"
        }
    }

    private var currentStage: Int {
        switch phase {
        case .searching: return 0
        case .discovering, .results: return 2
        default: return 1
        }
    }

    private var accent: Color {
        if isPaused { return theme.warningOnCamera }
        switch phase {
        case .unsupported, .uncertain, .taxonomyUnavailable: return theme.warningOnCamera
        case .validationFailed: return theme.danger
        default: return theme.recognition
        }
    }
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
#endif
