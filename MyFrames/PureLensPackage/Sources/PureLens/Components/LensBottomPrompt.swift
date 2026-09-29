#if canImport(UIKit)
import PureLensCore
import SwiftUI

struct LensBottomPrompt: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @State private var contentHeight: CGFloat = 0

    @ObservedObject var store: PureLensStore
    let reduceMotion: Bool
    let reduceTransparency: Bool
    let differentiateWithoutColor: Bool
    let maximumHeight: CGFloat

    var body: some View {
        let availableHeight = max(0, maximumHeight - LensPromptMetrics.edgeSpacing)
        ScrollView(.vertical) {
            promptContent
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(key: LensPromptHeightKey.self, value: proxy.size.height)
                    }
                }
        }
        .frame(height: contentHeight > 0 ? min(contentHeight, availableHeight) : availableHeight)
        .onPreferenceChange(LensPromptHeightKey.self) { contentHeight = $0 }
        .lensPromptSurface(
            fallback: store.theme.cameraChrome,
            accent: indicatorTint,
            reduceTransparency: reduceTransparency,
            increasedContrast: increasedContrast
        )
        .frame(maxWidth: LensPromptMetrics.maximumWidth)
        .padding(.horizontal, LensPromptMetrics.screenInset)
        .padding(.bottom, LensPromptMetrics.edgeSpacing)
    }

    private var promptContent: some View {
        VStack(spacing: 0) {
            phaseAccent

            if store.isCameraInterrupted {
                Label(store.localized("lens.camera.interrupted"), systemImage: "video.slash.fill")
                    .font(store.theme.typography.footnoteEmphasized)
                    .foregroundStyle(store.theme.warningOnCamera)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, LensPromptMetrics.compactInset)
                    .padding(.vertical, LensPromptMetrics.interruptionVerticalInset)
                    .background(
                        store.theme.warningOnCamera.opacity(0.12),
                        in: RoundedRectangle(
                            cornerRadius: LensPromptMetrics.inlineRadius,
                            style: .continuous
                        )
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: LensPromptMetrics.inlineRadius,
                            style: .continuous
                        )
                        .stroke(store.theme.warningOnCamera.opacity(0.20), lineWidth: 1)
                    }
                    .padding(.horizontal, LensPromptMetrics.contentInset)
                    .padding(.top, LensPromptMetrics.elementSpacing)
            }

            HStack(alignment: .center, spacing: LensPromptMetrics.headerSpacing) {
                statusIndicator

                VStack(alignment: .leading, spacing: 4) {
                    Text(promptTitle)
                        .font(store.theme.typography.headline)
                        .foregroundStyle(store.theme.textOnCamera)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)

                    Text(promptDetail)
                        .font(store.theme.typography.caption)
                        .foregroundStyle(
                            store.theme.textOnCamera.opacity(increasedContrast ? 0.86 : 0.70)
                        )
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, LensPromptMetrics.contentInset)
            .padding(.top, LensPromptMetrics.headerTopInset)
            .padding(.bottom, LensPromptMetrics.headerBottomInset)
            .accessibilityElement(children: .combine)
            .accessibilitySortPriority(3)

            terminalIdentitySummary

            if !store.identityCandidates.isEmpty {
                candidateChoices
            }

            if store.scanPhase == .unsupported
                || store.scanPhase == .uncertain
                || store.scanPhase == .notAnimal
                || store.scanPhase == .taxonomyUnavailable
                || store.scanPhase == .validationFailed {
                Button(action: store.scanAgain) {
                    Label(store.localized("lens.scan_again"), systemImage: "viewfinder")
                        .font(store.theme.typography.headline)
                        .frame(maxWidth: .infinity, minHeight: LensPromptMetrics.actionHeight)
                }
                .buttonStyle(LensPrimaryButtonStyle(theme: store.theme, reduceMotion: motionDisabled))
                .accessibilityHint(store.localized("lens.scan_again.hint"))
                .accessibilitySortPriority(2)
                .padding(.horizontal, LensPromptMetrics.contentInset)
                .padding(.bottom, LensPromptMetrics.elementSpacing)
            }

            if store.configuration.showsPrivacyNotice {
                HStack(alignment: .center, spacing: LensPromptMetrics.privacySpacing) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(
                            store.theme.textOnCamera.opacity(increasedContrast ? 0.90 : 0.72)
                        )
                        .frame(
                            width: LensPromptMetrics.privacyIconSize,
                            height: LensPromptMetrics.privacyIconSize
                        )
                        .background(
                            store.theme.textOnCamera.opacity(0.08),
                            in: RoundedRectangle(
                                cornerRadius: LensPromptMetrics.privacyIconRadius,
                                style: .continuous
                            )
                        )

                    Text(privacyMessage)
                        .font(store.theme.typography.caption2Medium)
                        .foregroundStyle(
                            store.theme.textOnCamera.opacity(increasedContrast ? 0.82 : 0.64)
                        )
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, LensPromptMetrics.compactInset)
                .padding(.vertical, LensPromptMetrics.privacyVerticalInset)
                .background(
                    store.theme.textOnCamera.opacity(0.055),
                    in: RoundedRectangle(
                        cornerRadius: LensPromptMetrics.inlineRadius,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: LensPromptMetrics.inlineRadius,
                        style: .continuous
                    )
                    .stroke(
                        store.theme.textOnCamera.opacity(increasedContrast ? 0.22 : 0.08),
                        lineWidth: increasedContrast ? 1.5 : 1
                    )
                }
                .padding(.horizontal, LensPromptMetrics.contentInset)
                .padding(.bottom, LensPromptMetrics.contentInset)
                .accessibilityElement(children: .combine)
                .accessibilitySortPriority(1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var terminalIdentitySummary: some View {
        if store.scanPhase == .unsupported {
            let identity = store.animalIdentification
            let fallback = store.unsupportedAnimalContext?.species
                ?? store.localized("lens.results.animal")
            let commonName = store.localizedIdentityName(fallback: fallback)

            VStack(alignment: .leading, spacing: 6) {
                Text(commonName)
                    .font(store.theme.typography.headline)
                    .foregroundStyle(store.theme.textOnCamera)
                    .fixedSize(horizontal: false, vertical: true)

                if let scientific = identity?.scientificName, !scientific.isEmpty {
                    Text(store.localizedFormat("lens.identity.scientific_name", scientific))
                        .font(store.theme.typography.caption)
                        .foregroundStyle(store.theme.textOnCamera.opacity(increasedContrast ? 0.90 : 0.74))
                }

                if let group = identity?.animalGroup, !group.isEmpty {
                    Text(
                        store.localizedFormat(
                            "lens.identity.group",
                            store.localizedAnimalGroup(group)
                        )
                    )
                    .font(store.theme.typography.caption)
                    .foregroundStyle(store.theme.textOnCamera.opacity(increasedContrast ? 0.90 : 0.74))
                }

                if let breed = identity?.breed, !breed.isEmpty {
                    Text(store.localizedFormat("lens.identity.breed", breed))
                        .font(store.theme.typography.caption)
                        .foregroundStyle(store.theme.textOnCamera.opacity(increasedContrast ? 0.90 : 0.74))
                }

                if let confidence = identity?.speciesConfidence {
                    Text(
                        store.localizedFormat(
                            "lens.identity.confidence",
                            Int((confidence * 100).rounded())
                        )
                    )
                    .font(store.theme.typography.caption2Medium.monospacedDigit())
                    .foregroundStyle(store.theme.textOnCamera.opacity(increasedContrast ? 0.84 : 0.64))
                }
            }
            .padding(.horizontal, LensPromptMetrics.compactInset)
            .padding(.vertical, LensPromptMetrics.privacyVerticalInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                store.theme.textOnCamera.opacity(0.055),
                in: RoundedRectangle(
                    cornerRadius: LensPromptMetrics.inlineRadius,
                    style: .continuous
                )
            )
            .padding(.horizontal, LensPromptMetrics.contentInset)
            .padding(.bottom, LensPromptMetrics.elementSpacing)
            .accessibilityElement(children: .combine)
            .accessibilitySortPriority(2.5)
        }
    }

    private var candidateChoices: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.localized("lens.identity.possibilities"))
                .font(store.theme.typography.subheadlineEmphasized)
                .foregroundStyle(store.theme.textOnCamera)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 8) {
                ForEach(store.identityCandidates, id: \.canonicalSpecies) { candidate in
                    Button {
                        store.selectIdentityCandidate(candidate)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.localizedCandidateName(candidate))
                                .font(store.theme.typography.subheadlineEmphasized)
                                .foregroundStyle(store.theme.textOnCamera)
                                .fixedSize(horizontal: false, vertical: true)
                            if let scientific = candidate.scientificName, !scientific.isEmpty {
                                Text(scientific)
                                    .font(store.theme.typography.caption)
                                    .foregroundStyle(store.theme.textOnCamera.opacity(0.75))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            store.theme.textOnCamera.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: LensPromptMetrics.inlineRadius, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(store.localized("lens.identity.candidate.hint"))
                }
            }

            Button(store.localized("lens.identity.none"), action: store.rejectIdentityCandidates)
                .font(store.theme.typography.subheadlineEmphasized)
                .foregroundStyle(store.theme.textOnCamera)
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityHint(store.localized("lens.identity.none.hint"))
        }
        .padding(.horizontal, LensPromptMetrics.contentInset)
        .padding(.bottom, LensPromptMetrics.elementSpacing)
        .accessibilityElement(children: .contain)
        .accessibilitySortPriority(2.5)
    }

    private var phaseAccent: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [indicatorTint, indicatorTint.opacity(0.42)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: LensPromptMetrics.accentWidth, height: LensPromptMetrics.accentHeight)
            .padding(.top, LensPromptMetrics.accentTopInset)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        ZStack {
            Circle()
                .fill(store.theme.textOnCamera.opacity(0.08))

            Circle()
                .stroke(
                    differentiateWithoutColor
                        ? store.theme.textOnCamera.opacity(0.78)
                        : store.theme.textOnCamera.opacity(increasedContrast ? 0.30 : 0.13),
                    style: StrokeStyle(
                        lineWidth: differentiateWithoutColor ? 2 : 1,
                        dash: differentiateWithoutColor ? [4, 3] : []
                    )
                )

            if store.scanPhase == .validating || store.scanPhase == .discovering {
                ProgressView()
                    .tint(indicatorTint)
            } else if store.scanPhase == .candidateFound || store.scanPhase == .confirming {
                Circle()
                    .trim(from: 0, to: max(0.08, store.detectorProgress))
                    .stroke(
                        store.theme.recognition,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(
                        (reduceMotion || systemReduceMotion) ? nil : .easeOut(duration: 0.22),
                        value: store.detectorProgress
                    )
                    .frame(
                        width: LensPromptMetrics.progressRingSize,
                        height: LensPromptMetrics.progressRingSize
                    )

                Image(systemName: statusSymbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(store.theme.textOnCamera)
            } else {
                Image(systemName: statusSymbol)
                    .font(.body.weight(.bold))
                    .foregroundStyle(indicatorTint)
            }
        }
        .frame(width: LensPromptMetrics.statusSize, height: LensPromptMetrics.statusSize)
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(indicatorTint)
                .frame(width: LensPromptMetrics.signalDotSize, height: LensPromptMetrics.signalDotSize)
                .overlay {
                    Circle().stroke(store.theme.cameraChrome.opacity(0.88), lineWidth: 2)
                }
                .accessibilityHidden(true)
        }
        .accessibilityHidden(true)
    }

    private var motionDisabled: Bool {
        reduceMotion || systemReduceMotion
    }

    private var increasedContrast: Bool {
        colorSchemeContrast == .increased
    }

    private var statusSymbol: String {
        switch store.scanPhase {
        case .searching:
            return "viewfinder"
        case .candidateFound, .confirming:
            return "circle.dashed"
        case .validating:
            return "checkmark.circle"
        case .confirmed, .discovering, .results:
            return "checkmark.seal.fill"
        case .unsupported:
            return "exclamationmark.triangle.fill"
        case .uncertain:
            return "questionmark.circle.fill"
        case .notAnimal:
            return "questionmark.circle.fill"
        case .taxonomyUnavailable:
            return "wifi.exclamationmark"
        case .validationFailed:
            return "exclamationmark.octagon.fill"
        }
    }

    private var indicatorTint: Color {
        switch store.scanPhase {
        case .unsupported, .uncertain, .taxonomyUnavailable:
            return store.theme.warningOnCamera
        case .notAnimal:
            return store.theme.textOnCamera
        case .validationFailed:
            return store.theme.danger
        default:
            return store.theme.recognition
        }
    }

    private var promptTitle: String {
        if store.didDeclineRemoteProcessingForCurrentDetection {
            return store.localized("lens.prompt.consent_paused")
        }
        switch store.scanPhase {
        case .searching:
            return store.localized("lens.prompt.ready")
        case .candidateFound:
            return store.localized("lens.prompt.candidate")
        case .confirming:
            return store.localized("lens.prompt.stabilizing")
        case .validating:
            return store.localized("lens.prompt.validating")
        case .confirmed:
            return store.localized("lens.prompt.detected")
        case .discovering:
            return store.localized("lens.prompt.resolving")
        case .results:
            return store.localized("lens.prompt.results")
        case .unsupported:
            return store.localized("lens.prompt.unsupported")
        case .uncertain:
            return store.localized(
                store.hasDismissedIdentityCandidates
                    ? (store.didChooseIdentityCandidate
                        ? "lens.prompt.choice_unconfirmed"
                        : "lens.prompt.none")
                    : "lens.prompt.uncertain"
            )
        case .notAnimal:
            return store.localized("lens.prompt.not_animal")
        case .taxonomyUnavailable:
            return store.localized("lens.prompt.taxonomy_unavailable")
        case .validationFailed:
            return store.localized("lens.prompt.validation_failed")
        }
    }

    private var promptDetail: String {
        switch store.scanPhase {
        case .searching:
            return store.localized("lens.prompt.ready.detail")
        case .candidateFound, .confirming:
            return store.localized("lens.prompt.stabilizing.detail")
        case .validating:
            return store.localized("lens.prompt.validating.detail")
        case .confirmed, .discovering:
            return store.localized("lens.prompt.resolving.detail")
        case .results:
            return store.localized("lens.prompt.results.detail")
        case .unsupported:
            guard let animal = store.unsupportedAnimalContext else {
                return store.localized("lens.prompt.unsupported.detail_fallback")
            }
            return store.localizedFormat(
                "lens.prompt.unsupported.detail",
                store.localizedIdentityName(fallback: animal.species)
            )
        case .uncertain:
            return store.localized(
                store.hasDismissedIdentityCandidates
                    ? (store.didChooseIdentityCandidate
                        ? "lens.prompt.choice_unconfirmed.detail"
                        : "lens.prompt.none.detail")
                    : (store.identityCandidates.isEmpty
                        ? "lens.prompt.uncertain.no_candidates"
                        : "lens.prompt.uncertain.detail")
            )
        case .notAnimal:
            return store.localized("lens.prompt.not_animal.detail")
        case .taxonomyUnavailable:
            return store.localized("lens.prompt.taxonomy_unavailable.detail")
        case .validationFailed:
            return store.localized("lens.prompt.validation_failed.detail")
        }
    }

    private var privacyMessage: String {
        if store.scanPhase == .unsupported
            || store.scanPhase == .uncertain
            || store.scanPhase == .notAnimal {
            return store.didShareSelectedFrameForAnimalIdentity
                ? store.localized("lens.prompt.identity_only")
                : store.localized("lens.prompt.unsupported.no_upload")
        }
        if store.scanPhase == .taxonomyUnavailable || store.scanPhase == .validationFailed {
            return store.didShareSelectedFrameForAnimalIdentity
                ? store.localized("lens.prompt.identity_only")
                : store.localized("lens.prompt.validation_failed.no_upload")
        }
        switch store.configuration.frameUploadPolicy {
        case .selectedFrame:
            return store.localized("lens.privacy.selected_frame")
        case .metadataOnly:
            return store.localized("lens.privacy.metadata_only")
        }
    }
}

private enum LensPromptMetrics {
    static let screenInset: CGFloat = 20
    static let edgeSpacing: CGFloat = 8
    static let maximumWidth: CGFloat = 560
    static let surfaceRadius: CGFloat = 30
    static let inlineRadius: CGFloat = 16
    static let contentInset: CGFloat = 18
    static let compactInset: CGFloat = 12
    static let elementSpacing: CGFloat = 12
    static let headerSpacing: CGFloat = 14
    static let headerTopInset: CGFloat = 14
    static let headerBottomInset: CGFloat = 16
    static let statusSize: CGFloat = 52
    static let progressRingSize: CGFloat = 42
    static let signalDotSize: CGFloat = 10
    static let actionHeight: CGFloat = 50
    static let accentWidth: CGFloat = 52
    static let accentHeight: CGFloat = 4
    static let accentTopInset: CGFloat = 8
    static let interruptionVerticalInset: CGFloat = 9
    static let privacySpacing: CGFloat = 10
    static let privacyVerticalInset: CGFloat = 10
    static let privacyIconSize: CGFloat = 30
    static let privacyIconRadius: CGFloat = 10
}

struct LensPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    let theme: PureLensTheme
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.white)
            .background(
                (configuration.isPressed ? theme.brandPressed : theme.brandStrong)
                    .opacity(isEnabled ? 1 : 0.62),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(isEnabled ? (configuration.isPressed ? 0.96 : 1) : 0.78)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private extension View {
    @ViewBuilder
    func lensPromptSurface(
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
                        cornerRadius: LensPromptMetrics.surfaceRadius,
                        style: .continuous
                    )
                )
                .lensPromptOutline(accent: accent, increasedContrast: increasedContrast)
        } else {
            self.lensPromptFallback(
                fallback: fallback,
                accent: accent,
                reduceTransparency: reduceTransparency,
                increasedContrast: increasedContrast
            )
        }
        #else
        self.lensPromptFallback(
            fallback: fallback,
            accent: accent,
            reduceTransparency: reduceTransparency,
            increasedContrast: increasedContrast
        )
        #endif
    }

    @ViewBuilder
    func lensPromptFallback(
        fallback: Color,
        accent: Color,
        reduceTransparency: Bool,
        increasedContrast: Bool
    ) -> some View {
        self
            .background {
                if reduceTransparency {
                    RoundedRectangle(
                        cornerRadius: LensPromptMetrics.surfaceRadius,
                        style: .continuous
                    )
                    .fill(fallback)
                } else {
                    ZStack {
                        RoundedRectangle(
                            cornerRadius: LensPromptMetrics.surfaceRadius,
                            style: .continuous
                        )
                        .fill(.ultraThinMaterial)

                        RoundedRectangle(
                            cornerRadius: LensPromptMetrics.surfaceRadius,
                            style: .continuous
                        )
                        .fill(fallback.opacity(increasedContrast ? 0.86 : 0.74))
                    }
                }
            }
            .lensPromptOutline(accent: accent, increasedContrast: increasedContrast)
            .shadow(color: Color.black.opacity(0.22), radius: 24, y: 12)
    }

    func lensPromptOutline(accent: Color, increasedContrast: Bool) -> some View {
        self.overlay {
            RoundedRectangle(
                cornerRadius: LensPromptMetrics.surfaceRadius,
                style: .continuous
            )
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(increasedContrast ? 0.42 : 0.22),
                        accent.opacity(increasedContrast ? 0.32 : 0.18),
                        Color.white.opacity(increasedContrast ? 0.16 : 0.07),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: increasedContrast ? 1.5 : 1
            )
        }
    }
}

private struct LensPromptHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#endif
