import SwiftUI

struct TransitionView: View {
    @ObservedObject var state: MatchedGeometryState

    var body: some View {
        ZStack {
            ForEach(state.sourcesArray, id: \.id) { (id, source, _) in
                let frame = state.currentFrames[id]!
                let destination = state.destinations[id]!.0
                let sourceFrame = state.sources[id]!.1
                let scaleX = frame.width / max(sourceFrame.width, 1)
                let scaleY = frame.height / max(sourceFrame.height, 1)
                
                ZStack {
                    source
                    destination
                }
                .frame(width: sourceFrame.width, height: sourceFrame.height)
                .scaleEffect(x: scaleX, y: scaleY)
                .position(x: frame.midX, y: frame.midY)
                .ignoresSafeArea()
                .animation(.easeOut(duration: state.currentDuration), value: frame)
            }
        }
    }
}
