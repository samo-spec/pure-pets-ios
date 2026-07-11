//
//  ChatBarView.swift
//  Pure Pets
//
//  Created by Shubham Singh on 08/08/20.
//  Copyright © 2020 Shubham Singh. All rights reserved.
//
//  Visual thesis: a single calm material composer whose microphone becomes
//  the recording instrument without adding another card or floating panel.
//  Structure thesis: intent first, progressive cancel and lock guidance
//  second, deliberate preview and send resolution last.
//  Motion thesis: immediate press compression, direct gesture-following
//  guidance, and controlled state morphs with no celebratory bounce.
//  Risk thesis: permission latency, gesture cancellation, interruptions, and
//  duplicate handoff must never leave a recorder running or misstate success.
//

import SwiftUI
import AVFoundation
import UIKit

/// Premium chat composer shared by user messaging and Nova hosts.
struct ChatBarView: View {

    // MARK: - Dependencies

    @ObservedObject var state: PPNovaChatBarState
    @StateObject private var recorder = PPVoiceRecorderController()
    @StateObject private var player = PPVoicePreviewPlayer()

    @FocusState private var isTextFieldFocused: Bool

    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    var chatBarHeight: CGFloat = 54.0

    var onSendText: (String) -> Void
    var onCameraTap: () -> Void
    var onVideoTap: () -> Void
    var onContactTap: () -> Void
    var onSendAudio: (URL, Double) -> Void

    // MARK: - Composer State

    @State private var attachmentsExpanded = false

    // MARK: - Recording Gesture State

    @State private var dragOffset: CGSize = .zero
    @State private var recordingGestureActive = false
    @State private var recordingPressBeganAt: Date?
    @State private var pendingLockAfterPreparation = false
    @State private var cancelArmed = false
    @State private var cancelThresholdFeedbackSent = false
    @State private var didLockDuringGesture = false

    private enum VoiceMetrics {
        static let controlSize: CGFloat = 38.0
        static let cancelDistance: CGFloat = 84.0
        static let lockDistance: CGFloat = 66.0
        static let cancelDisarmFraction: CGFloat = 0.72
        static let quickTapDuration: TimeInterval = 0.28
        static let compactWaveformCount = 32
        static let lockedWaveformCount = 44
    }

    /// The recorder has a distinct microphone-language at every real state.
    /// iOS 18+ gets the selected SF Symbol family from the supplied reference;
    /// older supported systems keep the same meaning with a safe native fallback.
    private enum VoiceSymbol {
        case idle
        case preparing
        case recordingMeter
        case cancel
        case discard
        case paused
        case pause
        case resume
        case finishRecording
        case preview
        case failure
    }

    // MARK: - Derived State

    private var trimmedMessage: String {
        state.message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isRecorderCapturing: Bool {
        recorder.state == .recording || recorder.state == .locked
    }

    private var showsRecordControl: Bool {
        guard state.voiceEnabled else { return false }

        switch recorder.state {
        case .preparing, .recording:
            return true
        case .idle:
            return !state.thinking && trimmedMessage.isEmpty
        case .locked, .paused, .previewing, .failed:
            return false
        }
    }

    private var logicalCancelDistance: CGFloat {
        if layoutDirection == .rightToLeft {
            return max(0.0, dragOffset.width)
        }
        return max(0.0, -dragOffset.width)
    }

    private var cancelProgress: CGFloat {
        min(max(logicalCancelDistance / VoiceMetrics.cancelDistance, 0.0), 1.0)
    }

    private var lockProgress: CGFloat {
        min(max(-dragOffset.height / VoiceMetrics.lockDistance, 0.0), 1.0)
    }

    private var microphoneLevel: CGFloat {
        CGFloat(recorder.levels.last ?? 0.06)
    }

    private var stateAnimation: Animation? {
        reduceMotion
            ? .easeOut(duration: 0.12)
            : .timingCurve(0.2, 0.0, 0.0, 1.0, duration: 0.30)
    }

    private var quickAnimation: Animation? {
        reduceMotion
            ? .easeOut(duration: 0.08)
            : .timingCurve(0.2, 0.0, 0.0, 1.0, duration: 0.16)
    }

    private var contentTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.985)),
                removal: .opacity.combined(with: .scale(scale: 0.992))
            )
    }

    private var composerSurfaceColor: Color {
        Color(
            uiColor: UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor.secondarySystemBackground.withAlphaComponent(0.92)
                }
                return UIColor.white.withAlphaComponent(0.94)
            }
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .trailing) {
            stateContent
                .transition(contentTransition)

            if showsRecordControl {
                recordControl
                    .padding(.trailing, PPSpace.sm)
                    .zIndex(4)
            }
        }
        .frame(height: chatBarHeight)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .fill(composerSurfaceColor)
                }
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.50),
                            .white.opacity(0.14),
                            Color(uiColor: .separator).opacity(0.24)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
        }
        .shadow(
            color: .black.opacity(0.075),
            radius: 12.0,
            x: 0.0,
            y: 5.0
        )
        .animation(stateAnimation, value: recorder.state)
        .animation(stateAnimation, value: attachmentsExpanded)
        .onChange(of: recorder.state) { newState in
            handleRecorderStateChange(newState)
        }
        .onChange(of: state.voiceEnabled) { enabled in
            guard !enabled else { return }
            discardRecording(announce: false)
        }
        .onChange(of: state.thinking) { thinking in
            if thinking {
                withAnimation(stateAnimation) {
                    attachmentsExpanded = false
                }
            }
        }
        .onChange(of: scenePhase) { phase in
            guard phase != .active else { return }
            resetGestureTracking()
            recorder.handleAppBecameInactive()
            player.pauseForInterruption()
        }
        .onDisappear {
            resetGestureTracking()
            recorder.cleanup()
            player.cleanup()
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        switch recorder.state {
        case .idle:
            idleComposer
        case .preparing, .recording:
            activeRecordingComposer
        case .locked, .paused:
            lockedRecordingComposer
        case .previewing:
            previewComposer
        case .failed:
            recordingFailureComposer
        }
    }

    // MARK: - Idle Composer

    private var idleComposer: some View {
        HStack(spacing: PPSpace.xs) {
            AttachmentButton(
                needsRotation: $attachmentsExpanded,
                iconName: "plus",
                iconSize: 18
            ) {
                guard !state.thinking else { return }
                isTextFieldFocused = false
                withAnimation(stateAnimation) {
                    attachmentsExpanded.toggle()
                }
            }
            .disabled(state.thinking)
            .opacity(state.thinking ? 0.46 : 1.0)

            Group {
                if attachmentsExpanded {
                    attachmentActions
                } else {
                    textComposer
                }
            }
            .transition(contentTransition)
        }
        .padding(.leading, PPSpace.xs)
        .padding(
            .trailing,
            showsRecordControl ? VoiceMetrics.controlSize + PPSpace.md : PPSpace.sm
        )
    }

    private var attachmentActions: some View {
        HStack(spacing: 0.0) {
            AttachmentButton(
                needsRotation: .constant(false),
                iconName: "camera",
                iconSize: 17
            ) {
                closeAttachments()
                onCameraTap()
            }

            AttachmentButton(
                needsRotation: .constant(false),
                iconName: "rectangle.stack.person.crop",
                iconSize: 17
            ) {
                closeAttachments()
                onContactTap()
            }

            AttachmentButton(
                needsRotation: .constant(false),
                iconName: "video.fill",
                iconSize: 17
            ) {
                closeAttachments()
                onVideoTap()
            }

            Spacer(minLength: 0.0)
        }
    }

    private var textComposer: some View {
        HStack(spacing: PPSpace.xs) {
            TextField(
                localized("chat_input_placeholder"),
                text: $state.message
            )
            .font(
                .custom(
                    "Beiruti-Medium",
                    size: 16.0,
                    relativeTo: .body
                )
            )
            .focused($isTextFieldFocused)
            .foregroundStyle(Color.ppTextPrimary)
            .tint(Color.ppPrimary)
            .submitLabel(.send)
            .disabled(state.thinking)
            .onSubmit {
                submitMessage()
            }
            .onChange(of: state.isFocusedTrigger) { shouldFocus in
                guard shouldFocus else { return }
                isTextFieldFocused = true
                state.isFocusedTrigger = false
            }

            if state.thinking {
                ProgressView()
                    .tint(Color.ppPrimary)
                    .frame(width: 36.0, height: 36.0)
                    .accessibilityLabel(localized("nova_thinking"))
            } else if !trimmedMessage.isEmpty {
                voiceActionButton(
                    systemName: "arrow.up",
                    foreground: .white,
                    background: Color.ppPrimary,
                    accessibilityLabel: localized("chat_send_message")
                ) {
                    submitMessage()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.88)))
            }
        }
        .padding(.leading, PPSpace.md)
        .padding(.trailing, PPSpace.xs)
        .frame(height: 44.0)
        .background {
            Capsule(style: .continuous)
                .fill(Color.ppPrimary.opacity(0.075))
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(
                            Color.ppPrimary.opacity(0.03),
                            lineWidth: 1.0 / UIScreen.main.scale
                        )
                }
        }
    }

    // MARK: - Active Hold Recording

    private var activeRecordingComposer: some View {
        HStack(spacing: PPSpace.sm) {
            if recorder.state == .preparing {
                Text(localized("voice_preparing"))
                    .font(
                        .custom(
                            "Beiruti-Medium",
                            size: 15.0,
                            relativeTo: .subheadline
                        )
                    )
                    .foregroundStyle(Color.ppTextSecondary)

                Spacer(minLength: 0.0)
            } else {
                recordingStatusDot

                Text(formatDuration(recorder.duration))
                    .font(
                        .custom(
                            "Beiruti-Medium",
                            size: 14.0,
                            relativeTo: .caption
                        )
                    )
                    .monospacedDigit()
                    .foregroundStyle(Color.ppError)
                    .frame(minWidth: 38.0, alignment: .leading)

                if !dynamicTypeSize.isAccessibilitySize {
                    PPVoiceWaveformView(
                        levels: Array(
                            recorder.levels.suffix(
                                VoiceMetrics.compactWaveformCount
                            )
                        ),
                        tint: .ppPrimary
                    )
                    .frame(width: 100.0)
                }

                Spacer(minLength: PPSpace.xs)
                recordingGuidance
            }
        }
        .padding(.leading, PPSpace.md)
        .padding(
            .trailing,
            VoiceMetrics.controlSize + PPSpace.lg
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var recordingGuidance: some View {
        let isLockGuidance = lockProgress > 0.08 && !cancelArmed
        let textKey = isLockGuidance
            ? "voice_slide_up_to_lock"
            : (cancelArmed
               ? "voice_release_to_cancel"
               : "voice_slide_to_cancel")
        let color: Color =
            cancelArmed
            ? .ppError
            : (isLockGuidance && lockProgress > 0.72
               ? .ppPrimary
               : .ppTextSecondary)

        return HStack(spacing: PPSpace.xs) {
            Image(
                systemName: isLockGuidance
                ? (lockProgress > 0.72 ? "lock.fill" : "lock.open.fill")
                : (layoutDirection == .rightToLeft
                   ? "chevron.right"
                   : "chevron.left")
            )
            .font(.system(size: 12.0, weight: .semibold))

            Text(localized(textKey))
                .font(
                    .custom(
                        "Beiruti-Medium",
                        size: 13.0,
                        relativeTo: .caption
                    )
                )
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 1 : 2)
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(color)
        .frame(maxWidth: 118.0, alignment: .trailing)
        .offset(
            x: cancelVisualDirection * min(cancelProgress, 1.0) * 5.0,
            y: -min(lockProgress, 1.0) * 3.0
        )
    }

    // MARK: - Locked Recording

    private var lockedRecordingComposer: some View {
        HStack(spacing: PPSpace.xs) {
            voiceActionButton(
                systemName: voiceSymbol(.discard),
                foreground: .ppError,
                background: Color.ppError.opacity(0.10),
                accessibilityLabel: localized("voice_discard")
            ) {
                discardRecording(announce: true)
            }

            HStack(spacing: PPSpace.sm) {
                if recorder.state == .paused {
                    Image(systemName: voiceSymbol(.paused))
                        .font(.system(size: 15.0, weight: .semibold))
                        .foregroundStyle(Color.ppWarning)
                } else {
                    recordingStatusDot
                }

                Text(formatDuration(recorder.duration))
                    .font(
                        .custom(
                            "Beiruti-Medium",
                            size: 14.0,
                            relativeTo: .caption
                        )
                    )
                    .monospacedDigit()
                    .foregroundStyle(
                        recorder.state == .paused
                            ? Color.ppWarning
                            : Color.ppError
                    )

                if !dynamicTypeSize.isAccessibilitySize {
                    PPVoiceWaveformView(
                        levels: Array(
                            recorder.levels.suffix(
                                VoiceMetrics.lockedWaveformCount
                            )
                        ),
                        tint: .ppPrimary,
                        isActive: recorder.state == .locked
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    Spacer(minLength: 0.0)
                }
            }
            .frame(maxWidth: .infinity)

            voiceActionButton(
                systemName: recorder.state == .paused
                    ? voiceSymbol(.resume)
                    : voiceSymbol(.pause),
                foreground: .ppTextPrimary,
                background: Color.ppPrimary.opacity(0.10),
                accessibilityLabel: localized(
                    recorder.state == .paused
                        ? "voice_resume"
                        : "voice_pause"
                )
            ) {
                if recorder.state == .paused {
                    recorder.resumeRecording()
                } else {
                    recorder.pauseRecording()
                }
            }

            voiceActionButton(
                systemName: voiceSymbol(.finishRecording),
                foreground: .ppWarning,
                background: Color.ppWarning.opacity(0.11),
                accessibilityLabel: localized("voice_preview")
            ) {
                player.cleanup()
                _ = recorder.stopAndPreview()
            }
        }
        .padding(.horizontal, PPSpace.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Preview

    private var previewComposer: some View {
        HStack(spacing: PPSpace.xs) {
            voiceActionButton(
                systemName: voiceSymbol(.discard),
                foreground: .ppError,
                background: Color.ppError.opacity(0.10),
                accessibilityLabel: localized("voice_discard")
            ) {
                discardRecording(announce: true)
            }

            voiceActionButton(
                systemName: player.isPlaying
                    ? voiceSymbol(.pause)
                    : voiceSymbol(.preview),
                foreground: player.playbackFailed ? .ppError : .ppPrimary,
                background: (
                    player.playbackFailed
                    ? Color.ppError
                    : Color.ppPrimary
                ).opacity(0.10),
                accessibilityLabel: localized(
                    player.isPlaying
                        ? "voice_pause"
                        : "voice_play"
                )
            ) {
                guard let url = recorder.recordingURL else { return }
                if player.isPlaying {
                    player.pausePlayback()
                } else {
                    player.startPlayback(url: url)
                }
            }

            VStack(spacing: 1.0) {
                previewProgressTrack
                    .padding(.horizontal, 14.0)

                Text(
                    String(
                        format: "%@ / %@",
                        formatDuration(player.currentTime),
                        formatDuration(
                            max(player.duration, recorder.duration)
                        )
                    )
                )
                .font(
                    .custom(
                        "Beiruti-Medium",
                        size: 11.5,
                        relativeTo: .caption2
                    )
                )
                .monospacedDigit()
                .foregroundStyle(Color.ppTextTertiary)
            }
            .frame(maxWidth: .infinity)

            voiceActionButton(
                systemName: "arrow.up",
                foreground: .white,
                background: Color.ppPrimary,
                accessibilityLabel: localized("voice_send")
            ) {
                commitRecordingForSend()
            }
        }
        .padding(.horizontal, PPSpace.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var previewProgressTrack: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1.0)
            let progress = min(max(player.progress, 0.0), 1.0)
            let knobX = layoutDirection == .rightToLeft
                ? width - (width * progress)
                : width * progress

            ZStack(alignment: layoutDirection == .rightToLeft ? .trailing : .leading) {
                Capsule(style: .continuous)
                    .fill(Color(uiColor: .tertiarySystemFill))
                    .frame(height: 4.0)

                Capsule(style: .continuous)
                    .fill(Color.ppPrimary)
                    .frame(width: max(width * progress, progress > 0 ? 4.0 : 0.0), height: 4.0)

                Circle()
                    .fill(Color.ppPrimary)
                    .frame(width: 12.0, height: 12.0)
                    .shadow(
                        color: Color.ppPrimary.opacity(0.22),
                        radius: 3.0,
                        x: 0.0,
                        y: 1.0
                    )
                    .position(x: knobX, y: proxy.size.height * 0.5)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0.0)
                    .onChanged { gesture in
                        let rawProgress =
                            min(max(gesture.location.x / width, 0.0), 1.0)
                        let logicalProgress =
                            layoutDirection == .rightToLeft
                            ? 1.0 - rawProgress
                            : rawProgress
                        player.seek(to: logicalProgress)
                    }
            )
        }
        .frame(height: 30.0)
        .accessibilityElement()
        .accessibilityLabel(localized("voice_preview_progress"))
        .accessibilityValue(
            String(
                format: "%@ / %@",
                formatDuration(player.currentTime),
                formatDuration(max(player.duration, recorder.duration))
            )
        )
        .accessibilityAdjustableAction { direction in
            let total = max(player.duration, recorder.duration)
            guard total > 0.0 else { return }
            let step = min(5.0 / total, 0.20)
            switch direction {
            case .increment:
                player.seek(to: min(player.progress + step, 1.0))
            case .decrement:
                player.seek(to: max(player.progress - step, 0.0))
            @unknown default:
                break
            }
        }
    }

    // MARK: - Failure

    private var recordingFailureComposer: some View {
        HStack(spacing: PPSpace.sm) {
            Image(systemName: voiceSymbol(.failure))
                .font(.system(size: 18.0, weight: .semibold))
                .foregroundStyle(Color.ppError)
                .accessibilityHidden(true)

            Text(localized(failureLocalizationKey))
                .font(
                    .custom(
                        "Beiruti-Medium",
                        size: 13.0,
                        relativeTo: .subheadline
                    )
                )
                .foregroundStyle(Color.ppTextPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if recorder.failure == .permissionDenied {
                voiceActionButton(
                    systemName: "gearshape.fill",
                    foreground: .ppPrimary,
                    background: Color.ppPrimary.opacity(0.10),
                    accessibilityLabel: localized("voice_open_settings")
                ) {
                    guard let url = URL(
                        string: UIApplication.openSettingsURLString
                    ) else {
                        return
                    }
                    openURL(url)
                }
            } else {
                voiceActionButton(
                    systemName: "arrow.clockwise",
                    foreground: .ppPrimary,
                    background: Color.ppPrimary.opacity(0.10),
                    accessibilityLabel: localized("voice_retry")
                ) {
                    recorder.resetFailure()
                }
            }

            voiceActionButton(
                systemName: voiceSymbol(.cancel),
                foreground: .ppTextSecondary,
                background: Color(uiColor: .tertiarySystemFill),
                accessibilityLabel: localized("voice_dismiss")
            ) {
                recorder.resetFailure()
            }
        }
        .padding(.horizontal, PPSpace.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Record Control

    private var recordControl: some View {
        let active =
            recorder.state == .recording || recorder.state == .preparing
        let controlColor: Color = cancelArmed ? .ppError : .ppPrimary
        let audioScale =
            recorder.state == .recording && !reduceMotion
            ? 1.0 + min(microphoneLevel, 1.0) * 0.10
            : 1.0
        let pressedScale = recordingGestureActive ? 0.94 : 1.0

        return ZStack {
            if active {
                Circle()
                    .stroke(
                        controlColor.opacity(0.18),
                        lineWidth: 2.0
                    )
                    .scaleEffect(
                        1.10 + (
                            reduceMotion
                            ? 0.0
                            : min(microphoneLevel, 1.0) * 0.08
                        )
                    )
                    .opacity(recorder.state == .preparing ? 0.52 : 1.0)
            }

            Circle()
                .fill(
                    active
                    ? controlColor
                    : controlColor.opacity(0.11)
                )
                .overlay {
                    Circle()
                        .strokeBorder(
                            controlColor.opacity(active ? 0.36 : 0.15),
                            lineWidth: 0.0
                        )
                }

            if recorder.state == .preparing {
                Image(systemName: voiceSymbol(.preparing))
                    .font(.system(size: 18.0, weight: .semibold))
                    .foregroundStyle(Color.ppPrimary)
                    .opacity(reduceMotion ? 1.0 : 0.82)
            } else {
                Image(
                    systemName: cancelArmed
                    ? voiceSymbol(.cancel)
                    : (recorder.state == .recording
                       ? voiceSymbol(.recordingMeter)
                       : voiceSymbol(.idle))
                )
                    .font(.system(size: 18.0, weight: .semibold))
                    .foregroundStyle(active ? Color.white : controlColor)
            }

            if recorder.state == .recording {
                Circle()
                    .trim(from: 0.0, to: max(cancelProgress, lockProgress))
                    .stroke(
                        cancelProgress >= lockProgress
                            ? Color.ppError
                            : Color.ppPrimary,
                        style: StrokeStyle(
                            lineWidth: 2.0,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90.0))
                    .padding(2.0)
            }
        }
        .frame(
            width: VoiceMetrics.controlSize,
            height: VoiceMetrics.controlSize
        )
        .scaleEffect(pressedScale * audioScale)
        .offset(
            x: cancelVisualDirection * min(cancelProgress, 1.0) * 9.0,
            y: -min(lockProgress, 1.0) * 8.0
        )
        .contentShape(Circle())
        .gesture(recordingGesture)
        .animation(quickAnimation, value: recordingGestureActive)
        .animation(quickAnimation, value: recorder.state)
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.10),
            value: microphoneLevel
        )
        .accessibilityElement()
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(localized("voice_record_action"))
        .accessibilityValue(localized(recordControlStatusKey))
        .accessibilityHint(localized("voice_record_hint"))
        .accessibilityAction {
            beginAccessibleLockedRecording()
        }
    }

    private var recordingStatusDot: some View {
        PPVoiceRecordingDot(active: recorder.state != .paused)
    }

    private var cancelVisualDirection: CGFloat {
        layoutDirection == .rightToLeft ? 1.0 : -1.0
    }

    private var recordControlStatusKey: String {
        switch recorder.state {
        case .preparing:
            return "voice_preparing"
        case .recording:
            return "voice_recording"
        case .locked:
            return "voice_locked_status"
        case .paused:
            return "voice_paused_status"
        case .previewing:
            return "voice_preview_ready"
        case .failed:
            return failureLocalizationKey
        case .idle:
            return "voice_record_action"
        }
    }

    // MARK: - Gesture State Machine

    private var recordingGesture: some Gesture {
        DragGesture(minimumDistance: 0.0, coordinateSpace: .local)
            .onChanged { value in
                handleRecordDragChanged(value)
            }
            .onEnded { value in
                handleRecordDragEnded(value)
            }
    }

    private func handleRecordDragChanged(
        _ value: DragGesture.Value
    ) {
        if didLockDuringGesture {
            return
        }

        if !recordingGestureActive {
            beginRecordGesture()
        }

        guard recordingGestureActive,
              recorder.state == .preparing ||
                recorder.state == .recording else {
            return
        }

        dragOffset = value.translation
        updateCancelArming()

        guard !cancelArmed,
              lockProgress >= 1.0,
              lockProgress >= cancelProgress else {
            return
        }

        if recorder.state == .preparing {
            pendingLockAfterPreparation = true
            return
        }

        if recorder.lockRecording() {
            didLockDuringGesture = true
            recordingGestureActive = false
            dragOffset = .zero
            cancelArmed = false
        }
    }

    private func handleRecordDragEnded(
        _ value: DragGesture.Value
    ) {
        dragOffset = value.translation
        updateCancelArming()

        if didLockDuringGesture {
            resetGestureTracking()
            return
        }

        if cancelArmed {
            if recorder.state == .preparing {
                recorder.cancelPendingStart()
            } else {
                recorder.cancelAndDiscard()
            }
            announce("voice_recording_cancelled")
            resetGestureTracking()
            return
        }

        if recorder.state == .preparing {
            // A released permission gesture becomes a safe hands-free record,
            // never a delayed runaway recorder and never an accidental send.
            pendingLockAfterPreparation = true
            recordingGestureActive = false
            dragOffset = .zero
            cancelArmed = false
            return
        }

        guard recorder.state == .recording else {
            resetGestureTracking()
            return
        }

        let elapsed =
            recordingPressBeganAt.map {
                Date().timeIntervalSince($0)
            } ?? 0.0

        if elapsed <= VoiceMetrics.quickTapDuration ||
            recorder.duration < recorder.minimumDuration {
            _ = recorder.lockRecording()
        } else {
            commitRecordingForSend()
        }

        resetGestureTracking()
    }

    private func beginRecordGesture() {
        guard state.voiceEnabled,
              !state.thinking,
              recorder.state == .idle || recorder.state == .failed else {
            return
        }

        if recorder.state == .failed {
            recorder.resetFailure()
        }

        player.cleanup()
        isTextFieldFocused = false
        withAnimation(stateAnimation) {
            attachmentsExpanded = false
        }

        recordingGestureActive = true
        recordingPressBeganAt = Date()
        pendingLockAfterPreparation = false
        cancelArmed = false
        cancelThresholdFeedbackSent = false
        didLockDuringGesture = false
        dragOffset = .zero

        recorder.startRecording { started in
            guard started else {
                resetGestureTracking()
                return
            }

            guard pendingLockAfterPreparation else { return }
            pendingLockAfterPreparation = false
            _ = recorder.lockRecording()
            resetGestureTracking()
        }
    }

    private func beginAccessibleLockedRecording() {
        guard recorder.state == .idle || recorder.state == .failed else {
            return
        }

        if recorder.state == .failed {
            recorder.resetFailure()
        }

        isTextFieldFocused = false
        withAnimation(stateAnimation) {
            attachmentsExpanded = false
        }
        pendingLockAfterPreparation = true

        recorder.startRecording { started in
            guard started else {
                pendingLockAfterPreparation = false
                return
            }
            pendingLockAfterPreparation = false
            _ = recorder.lockRecording()
        }
    }

    private func updateCancelArming() {
        let shouldArm: Bool
        if cancelArmed {
            shouldArm =
                cancelProgress >= VoiceMetrics.cancelDisarmFraction
        } else {
            shouldArm = cancelProgress >= 1.0
        }

        if shouldArm && !cancelArmed && !cancelThresholdFeedbackSent {
            PPHapticManager.triggerSelection()
            cancelThresholdFeedbackSent = true
        } else if !shouldArm && cancelProgress < 0.40 {
            cancelThresholdFeedbackSent = false
        }
        cancelArmed = shouldArm
    }

    private func resetGestureTracking() {
        dragOffset = .zero
        recordingGestureActive = false
        recordingPressBeganAt = nil
        pendingLockAfterPreparation = false
        cancelArmed = false
        cancelThresholdFeedbackSent = false
        didLockDuringGesture = false
    }

    // MARK: - Voice Actions

    private func commitRecordingForSend() {
        player.cleanup()
        guard let (url, duration) = recorder.finishAndGetURL() else {
            return
        }
        onSendAudio(url, duration)
    }

    private func discardRecording(announce shouldAnnounce: Bool) {
        player.cleanup()
        if recorder.state == .preparing {
            recorder.cancelPendingStart()
        } else if recorder.state == .failed {
            recorder.resetFailure()
        } else {
            recorder.cancelAndDiscard()
        }
        resetGestureTracking()
        if shouldAnnounce {
            announce("voice_recording_cancelled")
        }
    }

    private func handleRecorderStateChange(
        _ newState: PPVoiceRecordingState
    ) {
        switch newState {
        case .idle:
            break
        case .preparing:
            break
        case .recording:
            announce("voice_recording")
        case .locked:
            resetGestureTracking()
            announce("voice_locked_status")
        case .paused:
            resetGestureTracking()
            announce("voice_paused_status")
        case .previewing:
            resetGestureTracking()
            if let url = recorder.recordingURL {
                player.preparePlayback(url: url)
            }
            announce("voice_preview_ready")
        case .failed:
            resetGestureTracking()
            player.cleanup()
            announce(failureLocalizationKey)
        }
    }

    private var failureLocalizationKey: String {
        switch recorder.failure {
        case .some(.permissionDenied):
            return "voice_microphone_permission"
        case .some(.tooShort):
            return "voice_recording_too_short"
        case .some(.interrupted):
            return "voice_recording_interrupted"
        case .some(.audioSessionUnavailable),
             .some(.recorderUnavailable),
             .none:
            return "voice_recording_failed"
        }
    }

    private func voiceSymbol(_ symbol: VoiceSymbol) -> String {
        switch symbol {
        case .idle:
            return selectedVoiceSymbol("microphone.fill", fallback: "mic.fill")
        case .preparing:
            return selectedVoiceSymbol("microphone.badge.plus.fill", fallback: "mic.fill")
        case .recordingMeter:
            return selectedVoiceSymbol("microphone.and.signal.meter.fill", fallback: "mic.fill")
        case .cancel, .discard, .failure:
            return selectedVoiceSymbol("microphone.badge.xmark.fill", fallback: "xmark")
        case .paused, .pause:
            return "mic.slash.fill"
        case .resume:
            return selectedVoiceSymbol("microphone.badge.plus", fallback: "mic.fill")
        case .finishRecording:
            return selectedVoiceSymbol("stop.fill", fallback: "stop.fill")
        case .preview:
            return selectedVoiceSymbol("play.fill", fallback: "play.fill")
        }
    }

    private func selectedVoiceSymbol(
        _ preferredName: String,
        fallback: String
    ) -> String {
        if #available(iOS 18.0, *), UIImage(systemName: preferredName) != nil {
            return preferredName
        }
        return fallback
    }

    // MARK: - Shared Controls

    private func voiceActionButton(
        systemName: String,
        foreground: Color,
        background: Color,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14.0, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: 36.0, height: 36.0)
                .background(background, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(
            PPVoiceActionButtonStyle(reduceMotion: reduceMotion)
        )
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Text / Attachment Actions

    private func closeAttachments() {
        withAnimation(stateAnimation) {
            attachmentsExpanded = false
        }
    }

    private func submitMessage() {
        guard !state.thinking, !trimmedMessage.isEmpty else { return }
        onSendText(trimmedMessage)
        state.message = ""
    }

    // MARK: - Formatting / Accessibility

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let safeDuration = max(duration, 0.0)
        let minutes = Int(safeDuration) / 60
        let seconds = Int(safeDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func announce(_ key: String) {
        UIAccessibility.post(
            notification: .announcement,
            argument: localized(key)
        )
    }
}

// MARK: - Supporting Motion Components

private struct PPVoiceActionButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                reduceMotion
                    ? 1.0
                    : (configuration.isPressed ? 0.94 : 1.0)
            )
            .opacity(configuration.isPressed ? 0.78 : 1.0)
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.08)
                    : .timingCurve(
                        0.2,
                        0.0,
                        0.0,
                        1.0,
                        duration: configuration.isPressed ? 0.09 : 0.18
                    ),
                value: configuration.isPressed
            )
    }
}

private struct PPVoiceRecordingDot: View {
    let active: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathes = false

    var body: some View {
        Circle()
            .fill(active ? Color.ppError : Color.ppWarning)
            .frame(width: 8.0, height: 8.0)
            .scaleEffect(
                active && !reduceMotion
                    ? (breathes ? 1.16 : 0.88)
                    : 1.0
            )
            .opacity(
                active && !reduceMotion
                    ? (breathes ? 1.0 : 0.58)
                    : 1.0
            )
            .onAppear {
                startBreathingIfNeeded()
            }
            .onChange(of: reduceMotion) { _ in
                startBreathingIfNeeded()
            }
            .onChange(of: active) { _ in
                startBreathingIfNeeded()
            }
            .accessibilityHidden(true)
    }

    private func startBreathingIfNeeded() {
        guard active, !reduceMotion else {
            breathes = false
            return
        }
        breathes = false
        withAnimation(
            .easeInOut(duration: 0.82)
                .repeatForever(autoreverses: true)
        ) {
            breathes = true
        }
    }
}

#Preview {
    ChatBarView(
        state: PPNovaChatBarState(),
        onSendText: { _ in },
        onCameraTap: {},
        onVideoTap: {},
        onContactTap: {},
        onSendAudio: { _, _ in }
    )
    .padding()
}
