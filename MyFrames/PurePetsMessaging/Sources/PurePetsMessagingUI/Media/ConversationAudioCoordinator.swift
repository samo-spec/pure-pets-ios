import AVFoundation
import Combine
import SwiftUI

@MainActor
public final class ConversationAudioCoordinator: ObservableObject {
  public enum PlaybackState: Equatable {
    case idle
    case loading(MessageID)
    case playing(MessageID)
    case paused(MessageID)
    case failed(MessageID)
  }

  @Published public private(set) var state: PlaybackState = .idle
  @Published public private(set) var progressByMessageID: [MessageID: Double] = [:]
  @Published public private(set) var playbackRate: Float = 1.0

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

  public func setPlaybackRate(_ rate: Float) {
    playbackRate = rate
    if case .playing = state {
      player?.rate = rate
    }
  }

  public func cyclePlaybackRate() {
    let nextRate: Float
    if playbackRate < 1.25 {
      nextRate = 1.5
    } else if playbackRate < 1.75 {
      nextRate = 2.0
    } else {
      nextRate = 1.0
    }
    setPlaybackRate(nextRate)
  }

  public func seek(to progress: Double, messageID: MessageID) {
    let clamped = min(max(progress, 0), 1)
    progressByMessageID[messageID] = clamped
    guard activeMessageID == messageID, let player = player, duration > 0 else { return }
    let targetSeconds = duration * clamped
    let targetTime = CMTime(seconds: targetSeconds, preferredTimescale: 600)
    player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
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

  public var activeMessageID: MessageID? {
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
    if playbackRate != 1.0 {
      newPlayer.rate = playbackRate
    }
    state = .playing(messageID)
  }

  private func pause(messageID: MessageID) {
    player?.pause()
    state = .paused(messageID)
  }

  private func resume(messageID: MessageID) {
    player?.play()
    if playbackRate != 1.0 {
      player?.rate = playbackRate
    }
    state = .playing(messageID)
  }

  private func addTimeObserver(messageID: MessageID) {
    removeTimeObserver()
    let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
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
