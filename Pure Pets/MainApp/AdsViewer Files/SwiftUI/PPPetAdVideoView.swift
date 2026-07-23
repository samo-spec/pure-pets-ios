import AVKit
import SwiftUI

struct PPPetAdVideoView: View {
    let url: URL
    let isActive: Bool
    let onSingleTap: () -> Void

    @StateObject private var model: PPPetAdVideoPlayerModel

    init(url: URL, isActive: Bool, onSingleTap: @escaping () -> Void) {
        self.url = url
        self.isActive = isActive
        self.onSingleTap = onSingleTap
        _model = StateObject(
            wrappedValue: PPPetAdVideoPlayerModel(url: url)
        )
    }

    var body: some View {
        ZStack {
            Color.black
            VideoPlayer(player: model.player)
                .onTapGesture {
                    onSingleTap()
                }

            switch model.state {
            case .loading:
                ProgressView()
                    .tint(.white)
                    .accessibilityLabel(
                        PPPetAdLocalization.text(
                            "Loading",
                            fallback: "Loading"
                        )
                    )
            case .failed:
                Button {
                    model.retry()
                } label: {
                    Label(
                        PPPetAdLocalization.text("Retry", fallback: "Retry"),
                        systemImage: "arrow.clockwise"
                    )
                    .font(
                        .custom(
                            "Beiruti-Bold",
                            size: 16,
                            relativeTo: .headline
                        )
                    )
                    .foregroundStyle(.white)
                    .padding(.horizontal, PPSpace.lg)
                    .frame(minHeight: 48)
                    .background(.ultraThinMaterial, in: Capsule())
                }
                .buttonStyle(PPPetAdPressButtonStyle())
            case .ready:
                if !model.isPlaying {
                    Button {
                        model.play()
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 25, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 68, height: 68)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(PPPetAdPressButtonStyle())
                    .accessibilityLabel(
                        PPPetAdLocalization.text(
                            "media_preview_play",
                            fallback: "Play"
                        )
                    )
                }
            }
        }
        .onAppear {
            if isActive {
                model.play()
            }
        }
        .onChange(of: isActive) { active in
            if active {
                model.play()
            } else {
                model.pause()
            }
        }
        .onDisappear {
            model.pause()
        }
    }
}
