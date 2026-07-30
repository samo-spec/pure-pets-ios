import SwiftUI

struct PPPetAdZoomableImageView: View {
    let item: PPPetAdMediaItem
    let accessibilityLabel: String
    let onSingleTap: () -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            PPPetAdRemoteImageView(
                urlString: item.imageURL,
                blurHash: item.blurHash,
                contentMode: .fit,
                accessibilityLabel: accessibilityLabel,
                cacheKey: item.id
            )
            .scaleEffect(scale)
            .offset(offset)
            .contentShape(Rectangle())
            .gesture(magnificationGesture(in: proxy.size))
            .simultaneousGesture(dragGesture(in: proxy.size))
            .highPriorityGesture(
                TapGesture(count: 2).onEnded {
                    toggleZoom()
                }
            )
            .onTapGesture {
                onSingleTap()
            }
            .accessibilityValue(
                "\(Int((scale * 100).rounded()))%"
            )
            .accessibilityAction(
                named: Text(
                    scale > 1.01
                        ? PPPetAdLocalization.text(
                            "pet_ad_viewer_reset_zoom",
                            fallback: "Reset zoom"
                        )
                        : PPPetAdLocalization.text(
                            "pet_ad_viewer_zoom",
                            fallback: "Zoom in"
                        )
                )
            ) {
                toggleZoom()
            }
        }
    }

    private func magnificationGesture(
        in size: CGSize
    ) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, 1), 5)
                offset = clamped(offset, in: size, at: scale)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1.01 {
                    reset()
                } else {
                    offset = clamped(offset, in: size, at: scale)
                    lastOffset = offset
                }
            }
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard scale > 1 else { return }
                offset = clamped(
                    CGSize(
                        width:
                            lastOffset.width + value.translation.width,
                        height:
                            lastOffset.height + value.translation.height
                    ),
                    in: size,
                    at: scale
                )
            }
            .onEnded { _ in
                lastOffset = offset
                if scale <= 1.01 {
                    reset()
                }
            }
    }

    private func toggleZoom() {
        if scale > 1.01 {
            reset()
        } else {
            withAnimation(
                reduceMotion ? nil : PPPetAdViewerMotion.expansion
            ) {
                scale = 2.35
                lastScale = 2.35
            }
        }
    }

    private func clamped(
        _ value: CGSize,
        in size: CGSize,
        at scale: CGFloat
    ) -> CGSize {
        let horizontalLimit = max(0, size.width * (scale - 1) / 2)
        let verticalLimit = max(0, size.height * (scale - 1) / 2)
        return CGSize(
            width: min(max(value.width, -horizontalLimit), horizontalLimit),
            height: min(max(value.height, -verticalLimit), verticalLimit)
        )
    }

    private func reset() {
        withAnimation(
            reduceMotion ? nil : PPPetAdViewerMotion.expansion
        ) {
            scale = 1
            lastScale = 1
            offset = .zero
            lastOffset = .zero
        }
    }
}
