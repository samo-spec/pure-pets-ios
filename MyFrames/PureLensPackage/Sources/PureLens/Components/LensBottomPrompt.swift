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
    var isSidePanel: Bool = false
    var fillsAvailableHeight: Bool = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            promptContent
                .fixedSize(horizontal: false, vertical: true)
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(key: LensPromptHeightKey.self, value: proxy.size.height)
                    }
                }
        }
        // Compact camera layouts reserve this space so status/copy changes do
        // not resize the preview and jump its aspect-fill crop while scanning.
        .frame(height: fillsAvailableHeight
            ? max(0, maximumHeight)
            : min(contentHeight, max(0, maximumHeight)))
        .onPreferenceChange(LensPromptHeightKey.self) { contentHeight = $0 }
        .background {
            RoundedRectangle(cornerRadius: surfaceRadius, style: .continuous)
                .fill(store.theme.cameraChrome)
                .overlay {
                    RoundedRectangle(cornerRadius: surfaceRadius, style: .continuous)
                        .fill(store.theme.textOnCamera.opacity(increasedContrast ? 0.085 : 0.055))
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: surfaceRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: surfaceRadius, style: .continuous)
                .strokeBorder(
                    store.theme.textOnCamera.opacity(increasedContrast ? 0.42 : 0.16),
                    lineWidth: increasedContrast ? 1.5 : 1
                )
                .allowsHitTesting(false)
        }
    }

    private var surfaceRadius: CGFloat { isSidePanel ? 28 : 30 }
    private var contentInset: CGFloat { isSidePanel ? 24 : 22 }

    private var promptContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: statusSymbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(indicatorTint)
                        .accessibilityHidden(true)
                    Text(statusCaption)
                        .font(store.theme.typography.footnoteEmphasized)
                        .foregroundStyle(store.theme.textOnCamera.opacity(increasedContrast ? 0.94 : 0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(promptTitle)
                    .font(store.theme.typography.title2)
                    .foregroundStyle(store.theme.textOnCamera)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text(promptDetail)
                    .font(store.theme.typography.subheadline)
                    .foregroundStyle(store.theme.textOnCamera.opacity(increasedContrast ? 0.94 : 0.80))
                    .fixedSize(horizontal: false, vertical: true)

                recognitionProgress
            }
            .accessibilityElement(children: .combine)
            .accessibilitySortPriority(3)

            if store.isCameraInterrupted {
                Label(store.localized("lens.camera.interrupted"), systemImage: "video.slash.fill")
                    .font(store.theme.typography.footnoteEmphasized)
                    .foregroundStyle(store.theme.warningOnCamera)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            terminalIdentitySummary

            if !store.identityCandidates.isEmpty {
                candidateChoices
            }

            recoveryActions

            if store.configuration.showsPrivacyNotice {
                VStack(alignment: .leading, spacing: 12) {
                    Rectangle()
                        .fill(store.theme.textOnCamera.opacity(increasedContrast ? 0.32 : 0.12))
                        .frame(height: 1)
                        .accessibilityHidden(true)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 12, weight: .medium))
                            .accessibilityHidden(true)
                        Text(privacyMessage)
                            .font(store.theme.typography.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(store.theme.textOnCamera.opacity(increasedContrast ? 0.90 : 0.72))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .combine)
                .accessibilitySortPriority(1)
            }
        }
        .multilineTextAlignment(.leading)
        .padding(contentInset)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var recognitionProgress: some View {
        if !store.didDeclineRemoteProcessingForCurrentDetection && !store.isCameraInterrupted {
            if store.scanPhase == .candidateFound || store.scanPhase == .confirming {
                ProgressView(value: min(1, max(0, store.detectorProgress)))
                    .progressViewStyle(.linear)
                    .tint(differentiateWithoutColor ? store.theme.textOnCamera : indicatorTint)
                    .animation(motionDisabled ? nil : .easeOut(duration: 0.20), value: store.detectorProgress)
                    .accessibilityLabel(store.localized("lens.detector.stabilizing"))
            } else if (store.scanPhase == .validating || store.scanPhase == .discovering) && !motionDisabled {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(differentiateWithoutColor ? store.theme.textOnCamera : indicatorTint)
                    .accessibilityLabel(promptTitle)
            }
        }
    }

    @ViewBuilder
    private var recoveryActions: some View {
        if store.didDeclineRemoteProcessingForCurrentDetection || isTerminalState {
            VStack(spacing: 8) {
                if canResumeConsentedFrame {
                    Button(action: store.requestRemoteProcessingConsentAgain) {
                        Label(store.localized("lens.privacy.consent.resume"), systemImage: "arrow.forward.circle")
                            .font(store.theme.typography.headline)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(LensPrimaryButtonStyle(theme: store.theme, reduceMotion: motionDisabled))
                    .accessibilityHint(store.localized("lens.privacy.consent.resume.hint"))
                }

                Button(action: store.scanAgain) {
                    Label(store.localized("lens.scan_again"), systemImage: "viewfinder")
                        .font(store.theme.typography.headline)
                        .foregroundStyle(store.theme.textOnCamera)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(
                            store.theme.textOnCamera.opacity(canResumeConsentedFrame ? 0.04 : 0.10),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(store.theme.textOnCamera.opacity(increasedContrast ? 0.48 : 0.18))
                        }
                }
                .buttonStyle(.plain)
                .accessibilityHint(store.localized("lens.scan_again.hint"))
            }
            .accessibilitySortPriority(2)
        }
    }

    private var canResumeConsentedFrame: Bool {
        // Declining initial identity consent releases the frame. Only the later
        // image-discovery path retains a frame the existing retry can consume.
        store.didDeclineRemoteProcessingForCurrentDetection && store.animalContext != nil
    }

    private var isTerminalState: Bool {
        switch store.scanPhase {
        case .unsupported, .uncertain, .notAnimal, .taxonomyUnavailable, .validationFailed:
            return true
        default:
            return false
        }
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
                    Text(store.localizedFormat("lens.identity.scientific_name", isolatedScientificName(scientific)))
                        .font(store.theme.typography.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let group = identity?.animalGroup, !group.isEmpty {
                    Text(store.localizedFormat("lens.identity.group", store.localizedAnimalGroup(group)))
                        .font(store.theme.typography.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let breed = identity?.breed, !breed.isEmpty {
                    Text(store.localizedFormat("lens.identity.breed", breed))
                        .font(store.theme.typography.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let confidence = identity?.speciesConfidence {
                    Text(store.localizedFormat("lens.identity.confidence", Int((confidence * 100).rounded())))
                        .font(store.theme.typography.caption2Medium.monospacedDigit())
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .foregroundStyle(store.theme.textOnCamera.opacity(increasedContrast ? 0.94 : 0.80))
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilitySortPriority(2.5)
        }
    }

    private var candidateChoices: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.localized("lens.identity.possibilities"))
                .font(store.theme.typography.subheadlineEmphasized)
                .foregroundStyle(store.theme.textOnCamera)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            ForEach(store.identityCandidates, id: \.canonicalSpecies) { candidate in
                Button {
                    store.selectIdentityCandidate(candidate)
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(store.localizedCandidateName(candidate))
                                .font(store.theme.typography.subheadlineEmphasized)
                                .foregroundStyle(store.theme.textOnCamera)
                                .fixedSize(horizontal: false, vertical: true)
                            if let scientific = candidate.scientificName, !scientific.isEmpty {
                                Text(isolatedScientificName(scientific))
                                    .font(store.theme.typography.caption)
                                    .foregroundStyle(store.theme.textOnCamera.opacity(increasedContrast ? 0.94 : 0.80))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(store.theme.textOnCamera.opacity(0.72))
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .background(
                        store.theme.textOnCamera.opacity(0.07),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(store.theme.textOnCamera.opacity(increasedContrast ? 0.45 : 0.13))
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityHint(store.localized("lens.identity.candidate.hint"))
            }

            Button(action: store.rejectIdentityCandidates) {
                Text(store.localized("lens.identity.none"))
                    .font(store.theme.typography.subheadlineEmphasized)
                    .foregroundStyle(store.theme.textOnCamera)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(store.localized("lens.identity.none.hint"))
        }
        .accessibilityElement(children: .contain)
        .accessibilitySortPriority(2.5)
    }

    private func isolatedScientificName(_ value: String) -> String {
        "\u{2066}\(value)\u{2069}"
    }

    private var motionDisabled: Bool { reduceMotion || systemReduceMotion }
    private var increasedContrast: Bool { colorSchemeContrast == .increased }

    private var statusCaption: String {
        if store.didDeclineRemoteProcessingForCurrentDetection || store.isCameraInterrupted {
            return store.localized("lens.stage.paused")
        }
        switch store.scanPhase {
        case .searching:
            return store.localized("lens.detector.searching")
        case .candidateFound, .confirming:
            return store.localized("lens.stage.recognition")
        case .confirmed, .discovering, .results:
            return store.localized("lens.stage.discovery")
        default:
            return store.localized("lens.stage.recognition")
        }
    }

    private var statusSymbol: String {
        if store.didDeclineRemoteProcessingForCurrentDetection || store.isCameraInterrupted {
            return "pause.circle"
        }
        switch store.scanPhase {
        case .searching: return "viewfinder"
        case .candidateFound, .confirming: return "scope"
        case .validating: return "hourglass"
        case .confirmed, .discovering, .results: return "checkmark.seal"
        case .unsupported: return "pawprint"
        case .uncertain, .notAnimal: return "questionmark.circle"
        case .taxonomyUnavailable: return "wifi.exclamationmark"
        case .validationFailed: return "exclamationmark.octagon"
        }
    }

    private var indicatorTint: Color {
        if store.didDeclineRemoteProcessingForCurrentDetection || store.isCameraInterrupted {
            return store.theme.textOnCamera
        }
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
        if store.didDeclineRemoteProcessingForCurrentDetection {
            return store.localized(
                canResumeConsentedFrame
                    ? "lens.prompt.consent_paused.detail"
                    : "lens.prompt.consent_paused.scan_again"
            )
        }
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

private struct LensPromptHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#endif
