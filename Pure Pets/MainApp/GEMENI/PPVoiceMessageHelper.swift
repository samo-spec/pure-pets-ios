//
//  PPVoiceMessageHelper.swift
//  Pure Pets
//
//  Production voice recording and local preview lifecycle.
//

import Foundation
import AVFoundation
import SwiftUI
import Combine
import UIKit

/// Stable Objective-C-visible states for the voice recording lifecycle.
@objc(PPSwiftVoiceRecordingState)
public enum PPVoiceRecordingState: Int {
    case idle = 0
    case recording = 1
    case locked = 2
    case paused = 3
    case previewing = 4
    case failed = 5
    case preparing = 6
}

/// Recoverable failures surfaced by the recorder without embedding UI copy.
public enum PPVoiceRecorderFailure: Equatable {
    case permissionDenied
    case audioSessionUnavailable
    case recorderUnavailable
    case tooShort
    case interrupted
}

/// Lightweight, truth-bound iOS haptic feedback.
public enum PPHapticManager {
    public static func triggerImpact(
        style: UIImpactFeedbackGenerator.FeedbackStyle,
        intensity: CGFloat = 1.0
    ) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: min(max(intensity, 0.0), 1.0))
    }

    public static func triggerSelection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    public static func triggerNotification(
        type: UINotificationFeedbackGenerator.FeedbackType
    ) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}

/// Owns one local voice recording from permission request through handoff.
///
/// The controller deliberately keeps transport and upload concerns outside
/// this type. finishAndGetURL() atomically transfers the temporary file to the
/// caller; all other terminal paths delete it.
public final class PPVoiceRecorderController: NSObject,
                                               ObservableObject,
                                               AVAudioRecorderDelegate {

    @Published public private(set) var state: PPVoiceRecordingState = .idle
    @Published public private(set) var duration: TimeInterval = 0.0
    @Published public private(set) var levels: [Float] =
        Array(repeating: 0.06, count: 24)
    @Published public private(set) var recordingURL: URL?
    @Published public private(set) var failure: PPVoiceRecorderFailure?

    public let minimumDuration: TimeInterval = 0.70
    public let maximumDuration: TimeInterval = 300.0

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var pendingStartRequestID: UUID?
    private var ownsRecordingFile = false

    public override init() {
        super.init()
        registerForAudioLifecycleNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        meterTimer?.invalidate()
        recorder?.delegate = nil
        recorder?.stop()
        if ownsRecordingFile, let recordingURL = recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
    }

    public var canCommitRecording: Bool {
        recordingURL != nil && duration >= minimumDuration
    }

    // MARK: - Start / Permission

    /// Begins one permission-safe recording transaction.
    ///
    /// The preparing state is published synchronously so repeated drag
    /// callbacks cannot launch duplicate permission requests or recorders.
    public func startRecording(completion: ((Bool) -> Void)? = nil) {
        guard state == .idle || state == .failed else {
            completion?(false)
            return
        }

        if state == .failed {
            resetFailure()
        }

        let requestID = UUID()
        pendingStartRequestID = requestID
        failure = nil
        state = .preparing

        requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self = self,
                      self.pendingStartRequestID == requestID,
                      self.state == .preparing else {
                    return
                }

                self.pendingStartRequestID = nil
                guard granted else {
                    self.fail(.permissionDenied)
                    completion?(false)
                    return
                }

                do {
                    try self.beginRecorderTransaction()
                    completion?(true)
                } catch {
                    self.fail(.audioSessionUnavailable)
                    completion?(false)
                }
            }
        }
    }

    /// Invalidates an asynchronous permission request before it can create a
    /// recorder after the user's gesture has already been cancelled.
    public func cancelPendingStart() {
        guard state == .preparing else { return }
        pendingStartRequestID = nil
        failure = nil
        state = .idle
        deactivateAudioSession()
    }

    private func requestRecordPermission(
        completion: @escaping (Bool) -> Void
    ) {
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            completion(true)
        case .denied:
            completion(false)
        case .undetermined:
            session.requestRecordPermission { granted in
                completion(granted)
            }
        @unknown default:
            completion(false)
        }
    }

    private func beginRecorderTransaction() throws {
        try activateRecordingAudioSession()

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice_\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 96_000,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder.delegate = self
        audioRecorder.isMeteringEnabled = true

        guard audioRecorder.prepareToRecord(), audioRecorder.record() else {
            audioRecorder.deleteRecording()
            throw NSError(
                domain: "PPVoiceRecorder",
                code: 1,
                userInfo: nil
            )
        }

        recorder = audioRecorder
        recordingURL = url
        ownsRecordingFile = true
        duration = 0.0
        levels = Array(repeating: 0.06, count: 24)
        state = .recording

        startMeterTimer()
        PPHapticManager.triggerImpact(style: .medium, intensity: 0.72)
    }

    // MARK: - Recording State

    @discardableResult
    public func lockRecording() -> Bool {
        guard state == .recording, recorder != nil else { return false }
        state = .locked
        PPHapticManager.triggerImpact(style: .rigid, intensity: 0.68)
        return true
    }

    public func pauseRecording() {
        guard state == .locked, let recorder = recorder else { return }
        recorder.pause()
        updateDurationFromRecorder(recorder)
        stopMeterTimer()
        state = .paused
        PPHapticManager.triggerImpact(style: .light, intensity: 0.62)
    }

    public func resumeRecording() {
        guard state == .paused, let recorder = recorder else { return }

        do {
            try activateRecordingAudioSession()
            guard recorder.record() else {
                throw NSError(
                    domain: "PPVoiceRecorder",
                    code: 2,
                    userInfo: nil
                )
            }
        } catch {
            fail(.audioSessionUnavailable)
            return
        }

        state = .locked
        startMeterTimer()
        PPHapticManager.triggerImpact(style: .light, intensity: 0.62)
    }

    /// Stops capture while retaining the file for local playback and send.
    @discardableResult
    public func stopAndPreview() -> Bool {
        guard [.recording, .locked, .paused].contains(state),
              let recorder = recorder else {
            return false
        }

        updateDurationFromRecorder(recorder)
        guard duration >= minimumDuration else {
            fail(.tooShort)
            return false
        }

        stopMeterTimer()
        recorder.delegate = nil
        recorder.stop()
        self.recorder = nil
        state = .previewing
        deactivateAudioSession()
        PPHapticManager.triggerImpact(style: .medium, intensity: 0.64)
        return true
    }

    /// Atomically transfers a valid recording to the message transport owner.
    ///
    /// The returned URL remains on disk. The receiving upload or send flow
    /// owns deletion from this point forward.
    public func finishAndGetURL() -> (URL, TimeInterval)? {
        guard [.recording, .locked, .paused, .previewing].contains(state) else {
            return nil
        }

        if let recorder = recorder {
            updateDurationFromRecorder(recorder)
        }

        guard let url = recordingURL, duration >= minimumDuration else {
            fail(.tooShort)
            return nil
        }

        let committedDuration = duration
        stopMeterTimer()
        recorder?.delegate = nil
        recorder?.stop()
        recorder = nil

        recordingURL = nil
        ownsRecordingFile = false
        failure = nil
        duration = 0.0
        levels = Array(repeating: 0.06, count: 24)
        state = .idle
        deactivateAudioSession()

        // Handoff confirmation, not transport success.
        PPHapticManager.triggerImpact(style: .medium, intensity: 0.78)
        return (url, committedDuration)
    }

    public func cancelAndDiscard() {
        cancelAndDiscard(feedback: true)
    }

    public func resetFailure() {
        guard state == .failed else { return }
        failure = nil
        state = .idle
    }

    /// View lifecycle cleanup. Any recording not handed off is discarded.
    public func cleanup() {
        cancelAndDiscard(feedback: false)
    }

    public func handleAppBecameInactive() {
        if state == .preparing {
            cancelPendingStart()
            return
        }
        pauseForInterruptionIfNeeded()
    }

    private func cancelAndDiscard(feedback: Bool) {
        let hadActiveTransaction =
            state != .idle || recordingURL != nil || recorder != nil

        pendingStartRequestID = nil
        stopMeterTimer()

        if let recorder = recorder {
            recorder.delegate = nil
            recorder.stop()
            recorder.deleteRecording()
        } else if ownsRecordingFile, let recordingURL = recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }

        recorder = nil
        recordingURL = nil
        ownsRecordingFile = false
        duration = 0.0
        levels = Array(repeating: 0.06, count: 24)
        failure = nil
        state = .idle
        deactivateAudioSession()

        if feedback && hadActiveTransaction {
            PPHapticManager.triggerNotification(type: .warning)
        }
    }

    // MARK: - Metering / Timing

    private func startMeterTimer() {
        stopMeterTimer()

        let timer = Timer(timeInterval: 0.08, repeats: true) {
            [weak self] _ in
            self?.sampleRecorder()
        }
        meterTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopMeterTimer() {
        meterTimer?.invalidate()
        meterTimer = nil
    }

    private func sampleRecorder() {
        guard let recorder = recorder,
              state == .recording || state == .locked else {
            return
        }

        updateDurationFromRecorder(recorder)
        if duration >= maximumDuration {
            _ = stopAndPreview()
            return
        }

        recorder.updateMeters()
        let power = recorder.averagePower(forChannel: 0)
        let normalized = max(0.04, min(1.0, (power + 50.0) / 50.0))
        let previous = levels.last ?? 0.06
        let smoothed = (previous * 0.68) + (normalized * 0.32)

        if !levels.isEmpty {
            levels.removeFirst()
        }
        levels.append(smoothed)
    }

    private func updateDurationFromRecorder(_ recorder: AVAudioRecorder) {
        duration = min(max(recorder.currentTime, 0.0), maximumDuration)
    }

    // MARK: - Audio Lifecycle

    private func registerForAudioLifecycleNotifications() {
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(handleAudioInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleAudioRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleMediaServicesReset(_:)),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: nil
        )
    }

    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard let rawValue =
                notification.userInfo?[AVAudioSessionInterruptionTypeKey]
                as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawValue)
        else {
            return
        }

        if type == .began {
            DispatchQueue.main.async { [weak self] in
                self?.pauseForInterruptionIfNeeded()
            }
        }
    }

    @objc private func handleAudioRouteChange(_ notification: Notification) {
        guard let rawValue =
                notification.userInfo?[AVAudioSessionRouteChangeReasonKey]
                as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: rawValue),
              reason == .oldDeviceUnavailable else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.pauseForInterruptionIfNeeded()
        }
    }

    @objc private func handleMediaServicesReset(_ notification: Notification) {
        _ = notification
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.state != .idle else { return }
            self.fail(.interrupted)
        }
    }

    private func pauseForInterruptionIfNeeded() {
        guard state == .recording || state == .locked,
              let recorder = recorder else {
            return
        }

        recorder.pause()
        updateDurationFromRecorder(recorder)
        stopMeterTimer()
        state = .paused
    }

    private func fail(_ reason: PPVoiceRecorderFailure) {
        pendingStartRequestID = nil
        stopMeterTimer()

        if let recorder = recorder {
            recorder.delegate = nil
            recorder.stop()
            recorder.deleteRecording()
        } else if ownsRecordingFile, let recordingURL = recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }

        recorder = nil
        recordingURL = nil
        ownsRecordingFile = false
        duration = 0.0
        levels = Array(repeating: 0.06, count: 24)
        failure = reason
        state = .failed
        deactivateAudioSession()
        PPHapticManager.triggerNotification(type: .error)
    }

    private func activateRecordingAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.defaultToSpeaker, .allowBluetoothHFP]
        )
        try session.setActive(true)
    }

    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        } catch {
            // Session teardown is best-effort and must not corrupt UI state.
        }
    }

    // MARK: - AVAudioRecorderDelegate

    public func audioRecorderDidFinishRecording(
        _ finishedRecorder: AVAudioRecorder,
        successfully flag: Bool
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  self.state != .idle,
                  self.state != .previewing,
                  self.state != .failed else {
                return
            }

            self.updateDurationFromRecorder(finishedRecorder)
            guard flag, self.recordingURL != nil else {
                self.fail(.recorderUnavailable)
                return
            }
            guard self.duration >= self.minimumDuration else {
                self.fail(.tooShort)
                return
            }

            self.stopMeterTimer()
            finishedRecorder.delegate = nil
            self.recorder = nil
            self.state = .previewing
            self.deactivateAudioSession()
        }
    }

    public func audioRecorderEncodeErrorDidOccur(
        _ recorder: AVAudioRecorder,
        error: Error?
    ) {
        _ = recorder
        _ = error
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.state != .idle else { return }
            self.fail(.recorderUnavailable)
        }
    }
}

/// Local playback owner for a recording preview.
public final class PPVoicePreviewPlayer: NSObject,
                                         ObservableObject,
                                         AVAudioPlayerDelegate {

    @Published public private(set) var isPlaying = false
    @Published public private(set) var progress: Double = 0.0
    @Published public private(set) var duration: TimeInterval = 0.0
    @Published public private(set) var currentTime: TimeInterval = 0.0
    @Published public private(set) var playbackFailed = false

    private var player: AVAudioPlayer?
    private var progressTimer: Timer?
    private var currentURL: URL?

    public override init() {
        super.init()
        registerForAudioLifecycleNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        progressTimer?.invalidate()
        player?.stop()
    }

    /// Prepares a local preview without starting playback.
    public func preparePlayback(url: URL) {
        if currentURL == url, player != nil {
            return
        }

        stopPlayback(deactivateSession: false, resetProgress: true)

        do {
            let previewPlayer = try AVAudioPlayer(contentsOf: url)
            previewPlayer.delegate = self
            guard previewPlayer.prepareToPlay() else {
                throw NSError(
                    domain: "PPVoicePreviewPlayer",
                    code: 1,
                    userInfo: nil
                )
            }

            player = previewPlayer
            currentURL = url
            duration = previewPlayer.duration
            currentTime = 0.0
            progress = 0.0
            isPlaying = false
            playbackFailed = false
        } catch {
            playbackFailed = true
            isPlaying = false
            PPHapticManager.triggerNotification(type: .error)
        }
    }

    /// Starts a new preview or resumes the same paused preview.
    public func startPlayback(url: URL) {
        if currentURL != url || player == nil {
            preparePlayback(url: url)
        }

        guard let player = player else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true)

            if player.currentTime >= max(player.duration - 0.05, 0.0) {
                player.currentTime = 0.0
            }
            guard player.play() else {
                throw NSError(
                    domain: "PPVoicePreviewPlayer",
                    code: 2,
                    userInfo: nil
                )
            }

            currentTime = player.currentTime
            progress = player.duration > 0
                ? player.currentTime / player.duration
                : 0.0
            isPlaying = true
            playbackFailed = false
            startProgressTimer()
            PPHapticManager.triggerImpact(style: .light, intensity: 0.58)
        } catch {
            playbackFailed = true
            isPlaying = false
            PPHapticManager.triggerNotification(type: .error)
            deactivateAudioSession()
        }
    }

    public func pausePlayback() {
        guard let player = player, isPlaying else { return }
        player.pause()
        currentTime = player.currentTime
        isPlaying = false
        stopProgressTimer()
        deactivateAudioSession()
        PPHapticManager.triggerImpact(style: .light, intensity: 0.52)
    }

    public func resumePlayback() {
        guard let currentURL = currentURL else { return }
        startPlayback(url: currentURL)
    }

    public func stopPlayback() {
        stopPlayback(deactivateSession: true, resetProgress: true)
    }

    public func pauseForInterruption() {
        guard isPlaying else { return }
        player?.pause()
        isPlaying = false
        stopProgressTimer()
        deactivateAudioSession()
    }

    public func seek(to progress: Double) {
        guard let player = player, player.duration > 0 else { return }
        let clampedProgress = min(max(progress, 0.0), 1.0)
        player.currentTime = clampedProgress * player.duration
        currentTime = player.currentTime
        self.progress = clampedProgress
    }

    public func cleanup() {
        stopPlayback()
    }

    public func audioPlayerDidFinishPlaying(
        _ player: AVAudioPlayer,
        successfully flag: Bool
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isPlaying = false
            self.progress = flag ? 1.0 : 0.0
            self.currentTime = flag ? self.duration : 0.0
            self.playbackFailed = !flag
            self.stopProgressTimer()
            self.deactivateAudioSession()
        }
    }

    public func audioPlayerDecodeErrorDidOccur(
        _ player: AVAudioPlayer,
        error: Error?
    ) {
        _ = player
        _ = error
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.stopPlayback(
                deactivateSession: true,
                resetProgress: false
            )
            self.playbackFailed = true
            PPHapticManager.triggerNotification(type: .error)
        }
    }

    private func startProgressTimer() {
        stopProgressTimer()
        let timer = Timer(timeInterval: 0.05, repeats: true) {
            [weak self] _ in
            guard let self = self, let player = self.player else { return }
            self.currentTime = player.currentTime
            self.duration = player.duration
            self.progress =
                player.duration > 0
                ? min(max(player.currentTime / player.duration, 0.0), 1.0)
                : 0.0
        }
        progressTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func stopPlayback(
        deactivateSession: Bool,
        resetProgress: Bool
    ) {
        player?.stop()
        player = nil
        currentURL = nil
        isPlaying = false
        stopProgressTimer()

        if resetProgress {
            progress = 0.0
            currentTime = 0.0
            duration = 0.0
            playbackFailed = false
        }
        if deactivateSession {
            deactivateAudioSession()
        }
    }

    private func registerForAudioLifecycleNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard let rawValue =
                notification.userInfo?[AVAudioSessionInterruptionTypeKey]
                as? UInt,
              AVAudioSession.InterruptionType(rawValue: rawValue) == .began
        else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.pauseForInterruption()
        }
    }

    @objc private func handleAudioRouteChange(_ notification: Notification) {
        guard let rawValue =
                notification.userInfo?[AVAudioSessionRouteChangeReasonKey]
                as? UInt,
              AVAudioSession.RouteChangeReason(rawValue: rawValue) ==
                .oldDeviceUnavailable
        else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.pauseForInterruption()
        }
    }

    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        } catch {
            // Preview teardown is best-effort.
        }
    }
}

/// Lightweight live waveform optimized for the fixed-height composer.
public struct PPVoiceWaveformView: View {
    public let levels: [Float]
    public let tint: Color
    public let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        levels: [Float],
        tint: Color = Color("AppPrimaryColor"),
        isActive: Bool = true
    ) {
        self.levels = levels
        self.tint = tint
        self.isActive = isActive
    }

    public var body: some View {
        HStack(spacing: 2.5) {
            ForEach(levels.indices, id: \.self) { index in
                let level = min(max(CGFloat(levels[index]), 0.04), 1.0)
                Capsule(style: .continuous)
                    .fill(tint.opacity(isActive ? 0.92 : 0.42))
                    .frame(width: 3.0, height: max(4.0, level * 36.0))
                    .animation(
                        reduceMotion || !isActive
                        ? nil
                        : .easeOut(duration: 0.12),
                        value: levels[index]
                    )
            }
        }
        .frame(maxHeight: 38.0)
        .accessibilityHidden(true)
    }
}
