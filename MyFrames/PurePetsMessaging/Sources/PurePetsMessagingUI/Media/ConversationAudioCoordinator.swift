import AVFoundation
import Observation

@MainActor
@Observable
public final class ConversationAudioCoordinator {
  public enum PlaybackState: Equatable {
    case idle
    case loading(MessageID)
    case playing(MessageID)
    case paused(MessageID)
    case failed(MessageID)
  }

  public private(set) var state: PlaybackState = .idle
  public private(set) var progressByMessageID: [MessageID: Double] = [:]

  private var player: AVPlayer?
  private var timeObserver: Any?
  private var duration: TimeInterval = 0

  public init() {}

  public func toggle(messageID: MessageID, payload: VoicePayload) {
    switch state {
    case .playing(messageID):
      pause(messageID: messageID)
    case .paused(messageID):
      resume(messageID: messageID)
    default:
      play(messageID: messageID, payload: payload)
    }
  }

  public func stop(messageID: MessageID) {
    guard activeMessageID == messageID else {
      return
    }
    removeTimeObserver()
    player?.pause()
    player = nil
    state = .idle
  }

  public func stopAll() {
    removeTimeObserver()
    player?.pause()
    player = nil
    state = .idle
  }

  public func progress(for messageID: MessageID) -> Double {
    progressByMessageID[messageID] ?? 0
  }

  public func isPlaying(_ messageID: MessageID) -> Bool {
    state == .playing(messageID)
  }

  private var activeMessageID: MessageID? {
    switch state {
    case .loading(let id), .playing(let id), .paused(let id), .failed(let id): id
    case .idle: nil
    }
  }

  private func play(messageID: MessageID, payload: VoicePayload) {
    guard let url = payload.audioURL else {
      state = .failed(messageID)
      return
    }

    stopAll()
    state = .loading(messageID)
    duration = max(payload.duration, 0.1)

    let newPlayer = AVPlayer(url: url)
    player = newPlayer
    addTimeObserver(messageID: messageID)
    newPlayer.play()
    state = .playing(messageID)
  }

  private func pause(messageID: MessageID) {
    player?.pause()
    state = .paused(messageID)
  }

  private func resume(messageID: MessageID) {
    player?.play()
    state = .playing(messageID)
  }

  private func addTimeObserver(messageID: MessageID) {
    removeTimeObserver()
    let interval = CMTime(seconds: 0.2, preferredTimescale: 600)
    timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
      [weak self] time in
      guard let self else {
        return
      }
      let progress = min(max(time.seconds / self.duration, 0), 1)
      self.progressByMessageID[messageID] = progress
      if progress >= 0.999 {
        self.stop(messageID: messageID)
        self.progressByMessageID[messageID] = 0
      }
    }
  }

  private func removeTimeObserver() {
    if let timeObserver {
      player?.removeTimeObserver(timeObserver)
      self.timeObserver = nil
    }
  }
}
