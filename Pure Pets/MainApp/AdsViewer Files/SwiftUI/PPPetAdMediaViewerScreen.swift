import SwiftUI
import UIKit

struct PPPetAdMediaViewerScreen: View {
    let items: [PPPetAdMediaItem]
    @Binding var selection: Int
    let onDismiss: () -> Void
    let onShare: () -> Void

    @State private var chromeVisible = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $selection) {
                ForEach(Array(items.enumerated()), id: \.element.id) {
                    index,
                    item in
                    media(item, index: index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            if chromeVisible {
                chrome
                    .transition(.opacity)
            }
        }
        .statusBar(hidden: true)
        .onAppear {
            selection = min(max(selection, 0), max(items.count - 1, 0))
        }
        .onChange(of: selection) { _ in
            UISelectionFeedbackGenerator().selectionChanged()
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func media(
        _ item: PPPetAdMediaItem,
        index: Int
    ) -> some View {
        if item.isVideo,
            let value = item.videoURL,
            let videoURL = URL(string: value)
        {
            PPPetAdVideoView(
                url: videoURL,
                isActive: index == selection,
                onSingleTap: toggleChrome
            )
        } else {
            PPPetAdZoomableImageView(
                item: item,
                accessibilityLabel: mediaLabel(index: index),
                onSingleTap: toggleChrome
            )
        }
    }

    private var chrome: some View {
        VStack {
            HStack(spacing: PPSpace.md) {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .bold))
                        .frame(width: 48, height: 48)
                        .foregroundStyle(.white)
                        .ppGlassSurface(
                            in: Circle(),
                            tint: Color.black.opacity(0.14),
                            fallback: Color.black.opacity(0.84)
                        )
                }
                .buttonStyle(PPPetAdPressButtonStyle(pressedScale: 0.90))
                .accessibilityLabel(
                    PPPetAdLocalization.text("Close", fallback: "Close")
                )

                Spacer()

                Text("\(selection + 1) / \(items.count)")
                    .font(
                        .custom(
                            "Beiruti-Bold",
                            size: 14,
                            relativeTo: .caption
                        )
                    )
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, PPSpace.md)
                    .frame(minHeight: 40)
                    .ppGlassSurface(
                        in: Capsule(),
                        tint: Color.black.opacity(0.14),
                        fallback: Color.black.opacity(0.84)
                    )

                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .bold))
                        .frame(width: 48, height: 48)
                        .foregroundStyle(.white)
                        .ppGlassSurface(
                            in: Circle(),
                            tint: Color.black.opacity(0.14),
                            fallback: Color.black.opacity(0.84)
                        )
                }
                .buttonStyle(PPPetAdPressButtonStyle(pressedScale: 0.90))
                .accessibilityLabel(
                    PPPetAdLocalization.text("Share", fallback: "Share")
                )
            }
            .padding(.horizontal, PPSpace.lg)
            .padding(.top, PPSpace.sm)

            Spacer()
        }
    }

    private func toggleChrome() {
        withAnimation(
            reduceMotion ? nil : .easeInOut(duration: 0.18)
        ) {
            chromeVisible.toggle()
        }
    }

    private func mediaLabel(index: Int) -> String {
        "\(PPPetAdLocalization.text("Photo", fallback: "Photo")) \(index + 1) \(PPPetAdLocalization.text("of", fallback: "of")) \(items.count)"
    }
}
