import SwiftUI
import UIKit

/// Fullscreen media viewer: paged zoomable photos and inline video under a
/// fading chrome. Supports a physics-driven vertical drag to dismiss —
/// content shrinks and the room darkens under the user's finger.
struct PPPetAdMediaViewerScreen: View {
    let items: [PPPetAdMediaItem]
    @Binding var selection: Int
    let onDismiss: () -> Void
    let onShare: () -> Void

    @State private var chromeVisible = true
    @State private var dragOffset: CGFloat = 0
    @State private var isZoomed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 0→1 dismissal progress used for scale and background dimming.
    private var dismissProgress: CGFloat {
        min(1, abs(dragOffset) / 260)
    }

    var body: some View {
        ZStack {
            Color.black
                .opacity(1 - dismissProgress * 0.55)
                .ignoresSafeArea()

            TabView(selection: $selection) {
                ForEach(Array(items.enumerated()), id: \.element.id) {
                    index,
                    item in
                    media(item, index: index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .offset(y: dragOffset)
            .scaleEffect(reduceMotion ? 1 : 1 - dismissProgress * 0.10)

            if chromeVisible {
                chrome
                    .opacity(1 - dismissProgress * 2)
                    .transition(.opacity)
            }
        }
        .simultaneousGesture(verticalDismissGesture)
        .statusBar(hidden: true)
        .onAppear {
            selection = min(max(selection, 0), max(items.count - 1, 0))
        }
        .adOnChange(of: selection) { _ in
            isZoomed = false
            if dragOffset != 0 {
                dragOffset = 0
            }
            UISelectionFeedbackGenerator().selectionChanged()
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(.escape) {
            onDismiss()
        }
    }

    // MARK: - Drag to dismiss

    /// Engages only on mostly-vertical drags while no page is zoomed, so
    /// horizontal paging and pan-zoom always win the gesture.
    private var verticalDismissGesture: some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { value in
                guard !isZoomed else { return }
                guard
                    abs(value.translation.height)
                        > abs(value.translation.width)
                else { return }
                dragOffset = value.translation.height
            }
            .onEnded { value in
                guard !isZoomed else {
                    dragOffset = 0
                    return
                }
                let travelled = abs(value.translation.height)
                let predicted = abs(value.predictedEndTranslation.height)
                if travelled > 130 || predicted > 280 {
                    onDismiss()
                } else {
                    withAnimation(
                        reduceMotion
                            ? nil
                            : PPPetAdViewerMotion.dismissSpring
                    ) {
                        dragOffset = 0
                    }
                }
            }
    }

    @ViewBuilder
    private func media(
        _ item: PPPetAdMediaItem,
        index: Int
    ) -> some View {
        if item.isVideo,
           let value = item.videoURL,
           let videoURL = URL(string: value) {
            PPPetAdVideoView(
                url: videoURL,
                isActive: index == selection,
                onSingleTap: toggleChrome
            )
        } else {
            PPPetAdZoomableImageView(
                item: item,
                accessibilityLabel: mediaLabel(index: index),
                onSingleTap: toggleChrome,
                onZoomChange: { zoomed in
                    isZoomed = zoomed
                }
            )
        }
    }
}

// MARK: - Chrome

private extension PPPetAdMediaViewerScreen {
    var chrome: some View {
        VStack {
            HStack(spacing: PPSpace.md) {
                chromeButton(
                    symbol: "xmark",
                    label: PPPetAdLocalization.text(
                        "Close",
                        fallback: "Close"
                    ),
                    action: onDismiss
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
                    .background(.ultraThinMaterial, in: Capsule())
                    .accessibilityLabel(
                        "\(selection + 1) \(PPPetAdLocalization.text("of", fallback: "of")) \(items.count)"
                    )

                chromeButton(
                    symbol: "square.and.arrow.up",
                    label: PPPetAdLocalization.text(
                        "Share",
                        fallback: "Share"
                    ),
                    action: onShare
                )
            }
            .padding(.horizontal, PPSpace.lg)
            .padding(.top, PPSpace.sm)

            Spacer()
        }
    }

    func chromeButton(
        symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .frame(width: 48, height: 48)
                .foregroundStyle(.white)
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle()
                        .stroke(
                            .white.opacity(0.22),
                            lineWidth: 0.75
                        )
                }
        }
        .buttonStyle(PPPetAdPressButtonStyle(pressedScale: 0.90))
        .accessibilityLabel(label)
    }

    func toggleChrome() {
        withAnimation(
            reduceMotion ? nil : .easeInOut(duration: 0.18)
        ) {
            chromeVisible.toggle()
        }
    }

    func mediaLabel(index: Int) -> String {
        "\(PPPetAdLocalization.text("Photo", fallback: "Photo")) \(index + 1) \(PPPetAdLocalization.text("of", fallback: "of")) \(items.count)"
    }
}

