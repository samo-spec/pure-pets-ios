#if canImport(UIKit)
import PureLensCore
import SwiftUI

struct LensCameraScene: View {
    @ObservedObject var store: PureLensStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var footerHeight: CGFloat = 0
    let reduceMotion: Bool
    let reduceTransparency: Bool
    let differentiateWithoutColor: Bool

    var body: some View {
        GeometryReader { proxy in
            let showsFooter = proxy.size.height > 180 && !dynamicTypeSize.isAccessibilitySize
            let reticleRect = mappedAnimalRect(
                in: proxy.size,
                footerInset: showsFooter ? max(footerHeight + 24, 72) : 16
            )

            ZStack(alignment: .bottomLeading) {
                cameraContent
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                // Only the lower scrim carries text; the subject stays unobscured.
                LinearGradient(
                    colors: [.clear, .clear, store.theme.cameraChrome.opacity(0.82)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                LensDetectionReticle(
                    rect: reticleRect,
                    phase: store.scanPhase,
                    progress: store.detectorProgress,
                    isInterrupted: store.isCameraInterrupted
                        || store.didDeclineRemoteProcessingForCurrentDetection,
                    theme: store.theme,
                    reduceMotion: reduceMotion,
                    differentiateWithoutColor: differentiateWithoutColor
                )
                // Focus taps must reach the existing AVCapture preview.
                .allowsHitTesting(false)

                if showsFooter {
                    cameraCaption
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            GeometryReader { caption in
                                Color.clear.preference(
                                    key: LensCameraCaptionHeightKey.self,
                                    value: caption.size.height
                                )
                            }
                        }
                        .allowsHitTesting(false)
                }
            }
            .onPreferenceChange(LensCameraCaptionHeightKey.self) { footerHeight = $0 }
            .clipped()
            .accessibilityElement(children: .contain)
        }
        .background(store.theme.cameraChrome)
    }

    @ViewBuilder
    private var cameraCaption: some View {
        if let animal = store.animalContext {
            LensAnimalIdentityBadge(
                animal: animal,
                species: store.localizedIdentityName(fallback: animal.species),
                confirmedText: store.localized("lens.detector.detected"),
                theme: store.theme,
                reduceTransparency: reduceTransparency
            )
        } else if let animal = store.unsupportedAnimalContext, store.scanPhase == .unsupported {
            LensAnimalIdentityBadge(
                animal: animal,
                species: store.localizedIdentityName(fallback: animal.species),
                confirmedText: store.localized("lens.prompt.unsupported.badge"),
                theme: store.theme,
                reduceTransparency: reduceTransparency
            )
        } else if store.scanPhase == .searching {
            Label(store.localized("lens.camera.guide"), systemImage: "viewfinder")
                .font(store.theme.typography.subheadlineEmphasized)
                .foregroundStyle(store.theme.textOnCamera)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var cameraContent: some View {
        if store.configuration.isDemoMode {
            Image("lens-demo", bundle: .module)
                .resizable()
                .scaledToFill()
                .accessibilityHidden(true)
        } else {
            PureLensCameraPreview(camera: store.camera)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(store.localized("lens.camera.accessibility"))
        }
    }

    private func mappedAnimalRect(in size: CGSize, footerInset: CGFloat) -> CGRect {
        // Bounds are viewport-relative, so portrait, landscape and split windows
        // share one geometry contract with no phone-specific top/bottom offsets.
        let inset = min(24, min(size.width, size.height) * 0.10)
        let available = CGRect(
            x: inset,
            y: inset,
            width: max(0, size.width - inset * 2),
            height: max(0, size.height - inset - min(footerInset, size.height * 0.32))
        )
        // Only the stabilizer can nominate a tracking target. Raw Vision boxes
        // below the acquisition confidence floor provide aiming feedback during searching.
        guard let normalized = store.liveRecognition?.boundingBox
            ?? store.detections.first(where: { $0.kind == .animal })?.boundingBox
        else {
            let width = min(available.width * 0.86, 480)
            let height = min(available.height * 0.82, width * 1.12)
            return CGRect(
                x: available.midX - width / 2,
                y: available.midY - height / 2,
                width: width,
                height: height
            )
        }

        let mapped = map(normalized, into: size).insetBy(dx: -16, dy: -16)
        let width = min(max(mapped.width, available.width * 0.48), available.width)
        let height = min(max(mapped.height, available.height * 0.40), available.height)
        return CGRect(
            x: min(max(mapped.midX - width / 2, available.minX), available.maxX - width),
            y: min(max(mapped.midY - height / 2, available.minY), available.maxY - height),
            width: width,
            height: height
        )
    }

    private func map(_ rect: LensNormalizedRect, into viewSize: CGSize) -> CGRect {
        let imageWidth = max(store.framePixelSize.width, 1)
        let imageHeight = max(store.framePixelSize.height, 1)
        let scale = max(viewSize.width / imageWidth, viewSize.height / imageHeight)
        let rendered = CGSize(width: imageWidth * scale, height: imageHeight * scale)
        let offsetX = (viewSize.width - rendered.width) / 2
        let offsetY = (viewSize.height - rendered.height) / 2

        return CGRect(
            x: offsetX + CGFloat(rect.x) * rendered.width,
            y: offsetY + CGFloat(1 - rect.y - rect.height) * rendered.height,
            width: CGFloat(rect.width) * rendered.width,
            height: CGFloat(rect.height) * rendered.height
        )
    }
}

private struct LensCameraCaptionHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct LensDetectionReticle: View {
    let rect: CGRect
    let phase: PureLensScanPhase
    let progress: Double
    let isInterrupted: Bool
    let theme: PureLensTheme
    let reduceMotion: Bool
    let differentiateWithoutColor: Bool

    var body: some View {
        ZStack {
            LensCornerBrackets(cornerLength: min(36, rect.width * 0.16), cornerRadius: 20)
                .stroke(
                    accent,
                    style: StrokeStyle(
                        lineWidth: differentiateWithoutColor ? 4 : 2.5,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: differentiateWithoutColor && phase == .searching ? [7, 5] : []
                    )
                )


            if phase == .candidateFound || phase == .confirming {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .trim(from: 0, to: max(0.08, min(progress, 1)))
                    .stroke(
                        theme.recognition,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.20), value: progress)
            }

            if phase == .validating, !isInterrupted {
                if reduceMotion {
                    Image(systemName: "hourglass")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(theme.textOnCamera)
                } else {
                    ProgressView()
                        .tint(theme.recognition)
                        .controlSize(.large)
                }
            }

            if !isInterrupted, phase == .confirmed || phase == .discovering || phase == .results {
                Image(systemName: "checkmark")
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(theme.cameraChrome)
                    .frame(width: 42, height: 42)
                    .background(theme.recognition, in: Circle())
                    .overlay { Circle().stroke(Color.white.opacity(0.52), lineWidth: 1) }
                    .transition(.scale.combined(with: .opacity))
            }

            if !isInterrupted, phase == .unsupported || phase == .uncertain
                || phase == .notAnimal || phase == .taxonomyUnavailable || phase == .validationFailed {
                Image(systemName: terminalSymbol)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(theme.cameraChrome)
                    .frame(width: 42, height: 42)
                    .background(accent, in: Circle())
                    .overlay { Circle().stroke(Color.white.opacity(0.52), lineWidth: 1) }
                    .transition(.scale.combined(with: .opacity))
            }

            if isInterrupted {
                Image(systemName: "pause.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(theme.warningOnCamera)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: phase)
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .opacity(isInterrupted ? 0.54 : settledOpacity)
        // Interpolate only the overlay. Animating the preview or its viewport
        // would resize the live image and make acquisition feel like zooming.
        .animation(
            reduceMotion || isInterrupted
                ? nil
                : .spring(response: 0.28, dampingFraction: 1, blendDuration: 0.08),
            value: rect
        )
        .accessibilityHidden(true)
    }

    private var terminalSymbol: String {
        switch phase {
        case .taxonomyUnavailable: return "wifi.exclamationmark"
        case .uncertain, .notAnimal: return "questionmark"
        default: return "exclamationmark"
        }
    }

    private var accent: Color {
        switch phase {
        case .searching, .notAnimal:
            return theme.textOnCamera.opacity(0.84)
        case .candidateFound, .confirming, .validating, .confirmed, .discovering, .results:
            return theme.recognition
        case .unsupported, .uncertain, .taxonomyUnavailable:
            return theme.warningOnCamera
        case .validationFailed:
            return theme.danger
        }
    }

    private var settledOpacity: Double {
        switch phase {
        case .discovering, .results: return 0.74
        default: return 1
        }
    }
}

private struct LensCornerBrackets: Shape {
    let cornerLength: CGFloat
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let length = min(cornerLength, min(rect.width, rect.height) / 2)
        let radius = min(cornerRadius, length)
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))

        path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))

        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - length, y: rect.maxY))

        path.move(to: CGPoint(x: rect.minX + length, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - length))
        return path
    }
}

private struct LensAnimalIdentityBadge: View {
    let animal: DetectedAnimalContext
    let species: String
    let confirmedText: String
    let theme: PureLensTheme
    let reduceTransparency: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title3)
                .foregroundStyle(theme.recognition)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(confirmedText)
                    .font(theme.typography.captionEmphasized)
                    .foregroundStyle(theme.textOnCamera.opacity(0.86))
                Text(displayName)
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.textOnCamera)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(animal.confidence, format: .percent.precision(.fractionLength(0)))
                .font(theme.typography.captionEmphasized.monospacedDigit())
                .foregroundStyle(theme.textOnCamera)
                .fixedSize()
        }
        .accessibilityElement(children: .combine)
    }

    private var displayName: String {
        guard let breed = animal.breed, !breed.isEmpty else { return species }
        return "\(species) · \(breed)"
    }
}

#endif
