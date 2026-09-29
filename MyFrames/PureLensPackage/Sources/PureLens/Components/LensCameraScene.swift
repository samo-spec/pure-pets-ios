#if canImport(UIKit)
import PureLensCore
import SwiftUI

struct LensCameraScene: View {
    @ObservedObject var store: PureLensStore
    let reduceMotion: Bool
    let reduceTransparency: Bool
    let differentiateWithoutColor: Bool

    var body: some View {
        GeometryReader { proxy in
            let reticleRect = mappedAnimalRect(in: proxy.size)

            ZStack {
                cameraContent
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.34),
                        Color.clear,
                        Color.black.opacity(0.08),
                        Color.black.opacity(0.46)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                LensDetectionReticle(
                    rect: reticleRect,
                    phase: store.scanPhase,
                    progress: store.detectorProgress,
                    isInterrupted: store.isCameraInterrupted,
                    theme: store.theme,
                    reduceMotion: reduceMotion,
                    differentiateWithoutColor: differentiateWithoutColor
                )

                if let animal = store.animalContext {
                    LensAnimalIdentityBadge(
                        animal: animal,
                        species: store.localizedIdentityName(fallback: animal.species),
                        confirmedText: store.localized("lens.detector.detected"),
                        theme: store.theme,
                        reduceTransparency: reduceTransparency
                    )
                    .frame(maxWidth: min(proxy.size.width - 40, 320))
                    .position(identityPosition(for: reticleRect, in: proxy.size))
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityElement()
                        .accessibilityLabel(store.localized("lens.camera.accessibility"))
                        .allowsHitTesting(false)
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.44, dampingFraction: 0.84), value: store.scanPhase)
            .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.82), value: reticleRect)
            .accessibilityElement(children: .contain)
        }
        .background(store.theme.ambientField)
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
                .accessibilityHidden(true)
        }
    }

    private func mappedAnimalRect(in size: CGSize) -> CGRect {
        guard let normalized = store.liveRecognition?.boundingBox
            ?? store.detections.first(where: { $0.kind == .animal })?.boundingBox
        else {
            let width = min(size.width * 0.72, 330)
            let height = min(max(width * 0.72, 210), size.height * 0.38)
            return CGRect(
                x: (size.width - width) / 2,
                y: max(150, (size.height - height) * 0.43),
                width: width,
                height: height
            )
        }

        let mapped = map(normalized, into: size).insetBy(dx: -18, dy: -18)
        let minimum = CGSize(width: min(size.width * 0.52, 250), height: 190)
        let width = min(max(mapped.width, minimum.width), size.width - 32)
        let height = min(max(mapped.height, minimum.height), size.height * 0.48)
        let minY: CGFloat = 128
        let maxY = max(minY, size.height - height - 210)
        let x = min(max(mapped.midX - width / 2, 16), size.width - width - 16)
        let y = min(max(mapped.midY - height / 2, minY), maxY)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func identityPosition(for rect: CGRect, in size: CGSize) -> CGPoint {
        let halfWidth = min(160, max(120, (size.width - 40) / 2))
        let centerX = min(max(rect.midX, halfWidth + 20), size.width - halfWidth - 20)
        let preferredY = rect.maxY + 52
        return CGPoint(x: centerX, y: min(preferredY, size.height - 190))
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
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.black.opacity(phase == .searching ? 0.04 : 0.08))

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)

            LensCornerBrackets(cornerLength: min(42, rect.width * 0.16), cornerRadius: 30)
                .stroke(
                    accent,
                    style: StrokeStyle(
                        lineWidth: differentiateWithoutColor ? 4.5 : 3,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: differentiateWithoutColor && phase == .searching ? [7, 5] : []
                    )
                )
                .shadow(color: accent.opacity(0.34), radius: 7)

            if phase == .candidateFound || phase == .confirming {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .trim(from: 0, to: max(0.08, min(progress, 1)))
                    .stroke(
                        theme.recognition,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .shadow(color: theme.recognition.opacity(0.42), radius: 8)
            }

            if phase == .validating {
                ProgressView()
                    .tint(theme.recognition)
                    .controlSize(.large)
            }

            if phase == .confirmed || phase == .discovering || phase == .results {
                Image(systemName: "checkmark")
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(theme.cameraChrome)
                    .frame(width: 42, height: 42)
                    .background(theme.recognition, in: Circle())
                    .overlay { Circle().stroke(Color.white.opacity(0.52), lineWidth: 1) }
                    .transition(.scale.combined(with: .opacity))
            }

            if phase == .unsupported || phase == .validationFailed {
                Image(systemName: phase == .unsupported ? "exclamationmark" : "wifi.exclamationmark")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(theme.cameraChrome)
                    .frame(width: 42, height: 42)
                    .background(accent, in: Circle())
                    .overlay { Circle().stroke(Color.white.opacity(0.52), lineWidth: 1) }
                    .transition(.scale.combined(with: .opacity))
            }

            if isInterrupted {
                Image(systemName: "video.slash.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(theme.warningOnCamera)
            }
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .opacity(isInterrupted ? 0.54 : settledOpacity)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.24), value: progress)
        .accessibilityHidden(true)
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
        HStack(spacing: 11) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(theme.recognition)

            VStack(alignment: .leading, spacing: 2) {
                Text(confirmedText)
                    .font(theme.typography.captionEmphasized)
                    .foregroundStyle(theme.textOnCamera.opacity(0.72))
                Text(displayName)
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.textOnCamera)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 6)

            Text(animal.confidence, format: .percent.precision(.fractionLength(0)))
                .font(theme.typography.captionEmphasized.monospacedDigit())
                .foregroundStyle(theme.textOnCamera.opacity(0.76))
        }
        .padding(.horizontal, 15)
        .frame(minHeight: 62)
        .background {
            if reduceTransparency {
                theme.cameraChrome
            } else {
                ZStack {
                    Capsule().fill(.ultraThinMaterial)
                    Capsule().fill(theme.cameraChrome.opacity(0.56))
                }
            }
        }
        .overlay { Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(confirmedText), \(displayName)")
    }

    private var displayName: String {
        guard let breed = animal.breed, !breed.isEmpty else { return species }
        return "\(species) · \(breed)"
    }
}

#endif
