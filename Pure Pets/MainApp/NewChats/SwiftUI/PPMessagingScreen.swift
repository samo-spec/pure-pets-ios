//
//  PPMessagingScreen.swift
//  Pure Pets
//
//  SwiftUI presentation owner for the consumer messaging experience.
//  Objective-C remains the behavior bridge; this file does not own Firebase,
//  notification routing, thread creation, uploads, or business policy.
//

import AVKit
import Combine
import SwiftUI
import UIKit

// MARK: - Objective-C Host Contract

@objc(PPMessagingSwiftUIHostControllerDelegate)
public protocol PPMessagingSwiftUIHostControllerDelegate: AnyObject {
    @objc(messagingHostDidSendText:)
    func messagingHostDidSendText(_ text: String)

    @objc func messagingHostDidTapPhoto()
    @objc func messagingHostDidTapVideo()
    @objc func messagingHostDidTapContact()

    @objc(messagingHostDidSelectSticker:)
    func messagingHostDidSelectSticker(_ sticker: PPChatSticker)

    @objc(messagingHostDidChangeText:)
    func messagingHostDidChangeText(_ text: String)

    @objc(messagingHostDidSendAudio:duration:)
    func messagingHostDidSendAudio(_ audioURL: URL, duration: Double)

    @objc(messagingHostDidRequestAction:messageID:)
    func messagingHostDidRequestAction(_ action: String, messageID: String?)

    @objc(messagingHostDidSeekAudioMessageID:progress:)
    func messagingHostDidSeekAudioMessageID(_ messageID: String, progress: Double)
}

@objc(PPMessagingSwiftUIHostController)
public final class PPMessagingSwiftUIHostController: UIViewController {
    @objc public weak var delegate: PPMessagingSwiftUIHostControllerDelegate?

    private let screenState = PPMessagingScreenState()
    private var hostingController: UIHostingController<PPMessagingScreen>?

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        let relay = PPMessagingActionRelay()
        relay.delegate = delegate

        let screen = PPMessagingScreen(state: screenState, relay: relay)
        let host = UIHostingController(rootView: screen)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(host)
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        hostingController = host
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let root = hostingController?.rootView {
            root.relay.delegate = delegate
        }
    }

    @objc(applyMessagePayloads:currentUserID:initialLoadCompleted:canLoadOlder:animated:)
    public func applyMessagePayloads(
        _ payloads: [[String: Any]],
        currentUserID: String,
        initialLoadCompleted: Bool,
        canLoadOlder: Bool,
        animated: Bool
    ) {
        onMain { [weak self] in
            self?.screenState.apply(
                payloads: payloads,
                currentUserID: currentUserID,
                initialLoadCompleted: initialLoadCompleted,
                canLoadOlder: canLoadOlder,
                animated: animated
            )
        }
    }

    @objc(configureConversationWithName:status:avatarURLString:isOnline:usesSupportLogo:isModal:unreadCount:isPinned:isMuted:isBinned:isReported:)
    public func configureConversation(
        name: String,
        status: String,
        avatarURLString: String,
        isOnline: Bool,
        usesSupportLogo: Bool,
        isModal: Bool,
        unreadCount: Int,
        isPinned: Bool,
        isMuted: Bool,
        isBinned: Bool,
        isReported: Bool
    ) {
        onMain { [weak self] in
            self?.screenState.configureConversation(
                name: name,
                status: status,
                avatarURLString: avatarURLString,
                isOnline: isOnline,
                usesSupportLogo: usesSupportLogo,
                isModal: isModal,
                unreadCount: unreadCount,
                isPinned: isPinned,
                isMuted: isMuted,
                isBinned: isBinned,
                isReported: isReported
            )
        }
    }

    @objc(setTypingVisible:)
    public func setTypingVisible(_ visible: Bool) {
        onMain { [weak self] in
            self?.screenState.isTyping = visible
        }
    }

    @objc(setInitialLoadingVisible:)
    public func setInitialLoadingVisible(_ visible: Bool) {
        onMain { [weak self] in
            self?.screenState.isLoading = visible
        }
    }

    @objc(setConnectionInterrupted:)
    public func setConnectionInterrupted(_ interrupted: Bool) {
        onMain { [weak self] in
            self?.screenState.connectionInterrupted = interrupted
        }
    }

    @objc(setPaginationLoading:)
    public func setPaginationLoading(_ loading: Bool) {
        onMain { [weak self] in
            self?.screenState.isLoadingOlder = loading
        }
    }

    @objc(setFailedMessageID:message:)
    public func setFailedMessageID(_ messageID: String, message: String) {
        onMain { [weak self] in
            self?.screenState.setFailure(messageID: messageID, message: message)
        }
    }

    @objc(clearFailedMessageID:)
    public func clearFailedMessageID(_ messageID: String) {
        onMain { [weak self] in
            self?.screenState.clearFailure(messageID: messageID)
        }
    }

    @objc(updateAudioMessageID:progress:duration:isPlaying:isLoading:)
    public func updateAudioMessageID(
        _ messageID: String?,
        progress: Double,
        duration: Double,
        isPlaying: Bool,
        isLoading: Bool
    ) {
        onMain { [weak self] in
            self?.screenState.updateAudio(
                messageID: messageID,
                progress: progress,
                duration: duration,
                isPlaying: isPlaying,
                isLoading: isLoading
            )
        }
    }

    @objc(setBottomNavigationClearance:)
    public func setBottomNavigationClearance(_ clearance: CGFloat) {
        onMain { [weak self] in
            self?.screenState.bottomNavigationClearance = max(0, clearance)
        }
    }

    @objc(setReplyPreviewTitle:subtitle:)
    public func setReplyPreviewTitle(_ title: String, subtitle: String) {
        onMain { [weak self] in
            self?.screenState.composerState.replyTitle = title
            self?.screenState.composerState.replySubtitle = subtitle
        }
    }

    @objc public func clearReplyPreview() {
        onMain { [weak self] in
            self?.screenState.composerState.replyTitle = ""
            self?.screenState.composerState.replySubtitle = ""
        }
    }

    @objc public func focusComposer() {
        onMain { [weak self] in
            self?.screenState.composerState.isFocusedTrigger = true
        }
    }

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}

// MARK: - Presentation State

private final class PPMessagingScreenState: ObservableObject {
    @Published private(set) var messages: [PPMessagingMessageSnapshot] = []
    @Published var isLoading = true
    @Published var initialLoadCompleted = false
    @Published var connectionInterrupted = false
    @Published var isLoadingOlder = false
    @Published var canLoadOlder = false
    @Published var isTyping = false
    @Published var conversationName = ""
    @Published var presenceText = ""
    @Published var avatarURLString = ""
    @Published var isOnline = false
    @Published var usesSupportLogo = false
    @Published var isModal = false
    @Published var isPinned = false
    @Published var isMuted = false
    @Published var isBinned = false
    @Published var isReported = false
    @Published var bottomNavigationClearance: CGFloat = 0
    @Published private(set) var messageRevision = 0
    @Published private(set) var latestAppendedCount = 0
    @Published private(set) var latestAppendContainsOutgoing = false
    @Published private(set) var unreadBoundaryMessageID: String?
    @Published private(set) var audioMessageID: String?
    @Published private(set) var audioProgress = 0.0
    @Published private(set) var audioDuration = 0.0
    @Published private(set) var audioPlaying = false
    @Published private(set) var audioLoading = false

    let composerState = PPNovaChatBarState()

    private var failedMessages: [String: String] = [:]
    private var knownMessageIDs = Set<String>()
    private var requestedInitialUnreadCount = 0
    private var didResolveUnreadBoundary = false

    func apply(
        payloads: [[String: Any]],
        currentUserID: String,
        initialLoadCompleted: Bool,
        canLoadOlder: Bool,
        animated: Bool
    ) {
        let previousIDs = messages.map(\.id)
        let previousLastID = previousIDs.last
        let incomingIDs = payloads.compactMap { $0.ppString("id") }
        let incomingLastID = incomingIDs.last
        let isInitialApplication = knownMessageIDs.isEmpty && messages.isEmpty
        let isTailUpdate = previousLastID == nil || previousLastID != incomingLastID

        var appendedIDs = Set<String>()
        if let previousLastID,
           let previousIndex = incomingIDs.firstIndex(of: previousLastID),
           previousIndex + 1 < incomingIDs.count {
            appendedIDs = Set(incomingIDs[(previousIndex + 1)...])
        } else if previousLastID == nil && !isInitialApplication {
            appendedIDs = Set(incomingIDs)
        }

        let snapshots = payloads.map { payload -> PPMessagingMessageSnapshot in
            let messageID = payload.ppString("id") ?? UUID().uuidString
            return PPMessagingMessageSnapshot(
                payload: payload,
                currentUserID: currentUserID,
                failureText: failedMessages[messageID],
                animatesEntrance: animated && isTailUpdate && appendedIDs.contains(messageID)
            )
        }

        messages = snapshots
        self.initialLoadCompleted = initialLoadCompleted
        self.isLoading = !initialLoadCompleted && snapshots.isEmpty
        self.canLoadOlder = canLoadOlder
        if initialLoadCompleted {
            isLoadingOlder = false
        }

        latestAppendedCount = appendedIDs.count
        latestAppendContainsOutgoing = snapshots.contains {
            appendedIDs.contains($0.id) && $0.isOutgoing
        }
        knownMessageIDs.formUnion(incomingIDs)
        resolveUnreadBoundaryIfNeeded()
        messageRevision &+= 1
    }

    func configureConversation(
        name: String,
        status: String,
        avatarURLString: String,
        isOnline: Bool,
        usesSupportLogo: Bool,
        isModal: Bool,
        unreadCount: Int,
        isPinned: Bool,
        isMuted: Bool,
        isBinned: Bool,
        isReported: Bool
    ) {
        conversationName = name
        presenceText = status
        self.avatarURLString = avatarURLString
        self.isOnline = isOnline
        self.usesSupportLogo = usesSupportLogo
        self.isModal = isModal
        self.isPinned = isPinned
        self.isMuted = isMuted
        self.isBinned = isBinned
        self.isReported = isReported
        if !didResolveUnreadBoundary {
            requestedInitialUnreadCount = max(0, unreadCount)
            resolveUnreadBoundaryIfNeeded()
        }
    }

    func setFailure(messageID: String, message: String) {
        failedMessages[messageID] = message
        messages = messages.map {
            guard $0.id == messageID else { return $0 }
            return $0.withFailure(message)
        }
        messageRevision &+= 1
    }

    func clearFailure(messageID: String) {
        failedMessages.removeValue(forKey: messageID)
        messages = messages.map {
            guard $0.id == messageID else { return $0 }
            return $0.withFailure(nil)
        }
        messageRevision &+= 1
    }

    func updateAudio(
        messageID: String?,
        progress: Double,
        duration: Double,
        isPlaying: Bool,
        isLoading: Bool
    ) {
        audioMessageID = messageID
        audioProgress = min(max(progress, 0), 1)
        audioDuration = max(duration, 0)
        audioPlaying = isPlaying
        audioLoading = isLoading
    }

    private func resolveUnreadBoundaryIfNeeded() {
        guard !didResolveUnreadBoundary,
              requestedInitialUnreadCount > 0,
              !messages.isEmpty else {
            return
        }
        let incoming = messages.filter { !$0.isOutgoing }
        guard !incoming.isEmpty else {
            didResolveUnreadBoundary = true
            return
        }
        let offset = min(requestedInitialUnreadCount, incoming.count)
        unreadBoundaryMessageID = incoming[incoming.count - offset].id
        didResolveUnreadBoundary = true
    }
}

private struct PPMessagingMessageSnapshot: Identifiable {
    let id: String
    let text: String
    let senderID: String
    let timestamp: Date
    let kind: String
    let status: Int
    let fileURLString: String
    let thumbnailURLString: String
    let localImage: UIImage?
    let thumbnailImage: UIImage?
    let duration: Double
    let mediaWidth: Double
    let mediaHeight: Double
    let waveformSamples: [Double]
    let isUploading: Bool
    let isLocalPending: Bool
    let transferProgress: Double
    let isDeleted: Bool
    let replyToMessageID: String?
    let isOutgoing: Bool
    let canUnsend: Bool
    let failureText: String?
    let animatesEntrance: Bool

    init(
        payload: [String: Any],
        currentUserID: String,
        failureText: String?,
        animatesEntrance: Bool
    ) {
        id = payload.ppString("id") ?? UUID().uuidString
        text = payload.ppString("text") ?? ""
        senderID = payload.ppString("senderID") ?? ""
        timestamp = payload["timestamp"] as? Date ?? Date()
        kind = payload.ppString("kind") ?? "text"
        status = payload.ppInt("status")
        fileURLString = payload.ppString("fileURL") ?? ""
        thumbnailURLString = payload.ppString("thumbnailURL") ?? ""
        localImage = payload["localImage"] as? UIImage
        thumbnailImage = payload["thumbnailImage"] as? UIImage
        duration = payload.ppDouble("duration")
        mediaWidth = payload.ppDouble("mediaWidth")
        mediaHeight = payload.ppDouble("mediaHeight")
        waveformSamples = (payload["waveformSamples"] as? [NSNumber])?.map(\.doubleValue) ?? []
        isUploading = payload.ppBool("isUploading")
        isLocalPending = payload.ppBool("isLocalPending")
        transferProgress = min(max(payload.ppDouble("transferProgress"), 0), 1)
        isDeleted = payload.ppBool("isDeleted")
        replyToMessageID = payload.ppString("replyToMessageID")
        isOutgoing = payload.ppBool("isOutgoing") || senderID == currentUserID
        canUnsend = payload.ppBool("canUnsend")
        self.failureText = failureText
        self.animatesEntrance = animatesEntrance
    }

    private init(copying source: Self, failureText: String?) {
        id = source.id
        text = source.text
        senderID = source.senderID
        timestamp = source.timestamp
        kind = source.kind
        status = source.status
        fileURLString = source.fileURLString
        thumbnailURLString = source.thumbnailURLString
        localImage = source.localImage
        thumbnailImage = source.thumbnailImage
        duration = source.duration
        mediaWidth = source.mediaWidth
        mediaHeight = source.mediaHeight
        waveformSamples = source.waveformSamples
        isUploading = source.isUploading
        isLocalPending = source.isLocalPending
        transferProgress = source.transferProgress
        isDeleted = source.isDeleted
        replyToMessageID = source.replyToMessageID
        isOutgoing = source.isOutgoing
        canUnsend = source.canUnsend
        self.failureText = failureText
        animatesEntrance = false
    }

    func withFailure(_ failureText: String?) -> Self {
        Self(copying: self, failureText: failureText)
    }

    var mediaURL: URL? {
        guard !fileURLString.isEmpty else { return nil }
        return URL(string: fileURLString)
    }

    var thumbnailURL: URL? {
        guard !thumbnailURLString.isEmpty else { return nil }
        return URL(string: thumbnailURLString)
    }

    var isMedia: Bool {
        kind == "image" || kind == "video" || kind == "sticker"
    }
}

private extension Dictionary where Key == String, Value == Any {
    func ppString(_ key: String) -> String? {
        let value = self[key]
        guard !(value is NSNull) else { return nil }
        return value as? String
    }

    func ppBool(_ key: String) -> Bool {
        if let value = self[key] as? Bool { return value }
        return (self[key] as? NSNumber)?.boolValue ?? false
    }

    func ppInt(_ key: String) -> Int {
        if let value = self[key] as? Int { return value }
        return (self[key] as? NSNumber)?.intValue ?? 0
    }

    func ppDouble(_ key: String) -> Double {
        if let value = self[key] as? Double { return value }
        return (self[key] as? NSNumber)?.doubleValue ?? 0
    }
}

// MARK: - Action Relay

private final class PPMessagingActionRelay {
    weak var delegate: PPMessagingSwiftUIHostControllerDelegate?

    func request(_ action: PPMessagingAction, messageID: String? = nil) {
        delegate?.messagingHostDidRequestAction(action.rawValue, messageID: messageID)
    }
}

private enum PPMessagingAction: String {
    case close
    case profile
    case pin
    case mute
    case background
    case report
    case bin
    case loadOlder
    case retryConnection
    case reply
    case copy
    case unsend
    case retryMessage
    case saveMedia
    case audioToggle
    case replyUnavailable
    case composerCancelledReply
}

// MARK: - Screen

private struct PPMessagingScreen: View {
    @ObservedObject var state: PPMessagingScreenState
    let relay: PPMessagingActionRelay

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var presentedMedia: PPMessagingMessageSnapshot?
    @State private var hasPositionedInitially = false
    @State private var isAtLatest = true
    @State private var unseenMessageCount = 0
    @State private var paginationAnchorID: String?
    @State private var highlightedMessageID: String?

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                PPMessagingHeader(state: state, relay: relay)

                if state.connectionInterrupted {
                    PPMessagingConnectionRibbon {
                        relay.request(.retryConnection)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                conversationContent(availableWidth: proxy.size.width)

                ChatBarView(
                    state: state.composerState,
                    onSendText: { relay.delegate?.messagingHostDidSendText($0) },
                    onCameraTap: { relay.delegate?.messagingHostDidTapPhoto() },
                    onVideoTap: { relay.delegate?.messagingHostDidTapVideo() },
                    onContactTap: { relay.delegate?.messagingHostDidTapContact() },
                    onStickerTap: { relay.delegate?.messagingHostDidSelectSticker($0) },
                    onSendAudio: { url, duration in
                        relay.delegate?.messagingHostDidSendAudio(url, duration: duration)
                    },
                    onCancelReply: {
                        relay.request(.composerCancelledReply)
                    }
                )
                .onReceive(state.composerState.$message.dropFirst()) { text in
                    relay.delegate?.messagingHostDidChangeText(text)
                }
                .padding(.bottom, state.bottomNavigationClearance)
                .background(.ultraThinMaterial)
            }
            .background(PPMessagingCanvas().ignoresSafeArea())
        }
        .environment(
            \.layoutDirection,
            Language.isRTL() ? .rightToLeft : .leftToRight
        )
        .fullScreenCover(item: $presentedMedia) { message in
            PPMessagingMediaViewer(message: message) {
                presentedMedia = nil
            } onSave: {
                relay.request(.saveMedia, messageID: message.id)
            }
        }
    }

    @ViewBuilder
    private func conversationContent(availableWidth: CGFloat) -> some View {
        if state.isLoading && state.messages.isEmpty {
            PPMessagingLoadingState()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if state.connectionInterrupted && state.messages.isEmpty {
            PPMessagingOfflineState {
                relay.request(.retryConnection)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if state.initialLoadCompleted && state.messages.isEmpty {
            PPMessagingEmptyState {
                state.composerState.isFocusedTrigger = true
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            messageScroller(availableWidth: availableWidth)
        }
    }

    private func messageScroller(availableWidth: CGFloat) -> some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        Color.clear
                            .frame(height: 1)
                            .id(PPMessagingScrollID.top)
                            .onAppear {
                                guard hasPositionedInitially,
                                      state.canLoadOlder,
                                      !state.isLoadingOlder,
                                      !state.messages.isEmpty else { return }
                                paginationAnchorID = state.messages.first?.id
                                relay.request(.loadOlder)
                            }

                        if state.isLoadingOlder {
                            ProgressView()
                                .tint(PPMessagingPalette.secondaryText)
                                .padding(.vertical, 12)
                                .accessibilityLabel(localized("chat_loading_older"))
                        }

                        ForEach(Array(state.messages.enumerated()), id: \.element.id) { index, message in
                            if needsDateSeparator(at: index) {
                                PPMessagingDateSeparator(date: message.timestamp)
                                    .padding(.vertical, index == 0 ? 10 : 14)
                            }

                            if state.unreadBoundaryMessageID == message.id {
                                PPMessagingUnreadSeparator()
                                    .padding(.vertical, 8)
                            }

                            PPMessagingMessageRow(
                                message: message,
                                grouping: grouping(at: index),
                                replySource: replySource(for: message),
                                availableWidth: availableWidth,
                                highlighted: highlightedMessageID == message.id,
                                audioState: audioState(for: message),
                                onAction: { action in
                                    handleMessageAction(action, message: message, proxy: proxy)
                                },
                                onSeekAudio: { progress in
                                    relay.delegate?.messagingHostDidSeekAudioMessageID(
                                        message.id,
                                        progress: progress
                                    )
                                }
                            )
                            .id(message.id)
                            .padding(.bottom, rowSpacing(after: index))
                        }

                        if state.isTyping {
                            PPMessagingTypingRow(name: state.conversationName)
                                .id(PPMessagingScrollID.typing)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(PPMessagingScrollID.bottom)
                            .onAppear {
                                isAtLatest = true
                                unseenMessageCount = 0
                            }
                            .onDisappear {
                                if hasPositionedInitially {
                                    isAtLatest = false
                                }
                            }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                }
                .ppInteractiveKeyboardDismissal()
                .onChange(of: state.initialLoadCompleted) { completed in
                    guard completed else { return }
                    positionInitially(using: proxy)
                }
                .onChange(of: state.messageRevision) { _ in
                    handleMessageRevision(using: proxy)
                }
                .onChange(of: state.isTyping) { typing in
                    guard typing, isAtLatest else { return }
                    scrollToLatest(using: proxy, animated: true)
                }
                .onAppear {
                    if state.initialLoadCompleted {
                        positionInitially(using: proxy)
                    }
                }

                if !isAtLatest || unseenMessageCount > 0 {
                    PPMessagingLatestButton(count: unseenMessageCount) {
                        scrollToLatest(using: proxy, animated: true)
                    }
                    .padding(.trailing, 18)
                    .padding(.bottom, 14)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
            }
        }
    }

    private func positionInitially(using proxy: ScrollViewProxy) {
        guard !hasPositionedInitially else { return }
        DispatchQueue.main.async {
            proxy.scrollTo(PPMessagingScrollID.bottom, anchor: .bottom)
            hasPositionedInitially = true
            isAtLatest = true
        }
    }

    private func handleMessageRevision(using proxy: ScrollViewProxy) {
        guard state.initialLoadCompleted else { return }
        if !hasPositionedInitially {
            positionInitially(using: proxy)
            return
        }

        if let anchor = paginationAnchorID,
           state.messages.first?.id != anchor,
           !state.isLoadingOlder {
            DispatchQueue.main.async {
                proxy.scrollTo(anchor, anchor: .top)
                paginationAnchorID = nil
            }
            return
        }

        guard state.latestAppendedCount > 0 else { return }
        if isAtLatest || state.latestAppendContainsOutgoing {
            scrollToLatest(using: proxy, animated: true)
        } else {
            unseenMessageCount += state.latestAppendedCount
        }
    }

    private func scrollToLatest(using proxy: ScrollViewProxy, animated: Bool) {
        let operation = {
            proxy.scrollTo(PPMessagingScrollID.bottom, anchor: .bottom)
            isAtLatest = true
            unseenMessageCount = 0
        }
        if animated && !reduceMotion {
            withAnimation(.timingCurve(0.2, 0, 0, 1, duration: 0.34), operation)
        } else {
            operation()
        }
    }

    private func handleMessageAction(
        _ action: PPMessagingRowAction,
        message: PPMessagingMessageSnapshot,
        proxy: ScrollViewProxy
    ) {
        switch action {
        case .reply:
            relay.request(.reply, messageID: message.id)
        case .copy:
            UIPasteboard.general.string = message.text
            relay.request(.copy, messageID: message.id)
        case .unsend:
            relay.request(.unsend, messageID: message.id)
        case .retry:
            relay.request(.retryMessage, messageID: message.id)
        case .save:
            relay.request(.saveMedia, messageID: message.id)
        case .openMedia:
            presentedMedia = message
        case .toggleAudio:
            relay.request(.audioToggle, messageID: message.id)
        case .openReplySource:
            guard let sourceID = message.replyToMessageID,
                  state.messages.contains(where: { $0.id == sourceID }) else {
                relay.request(.replyUnavailable, messageID: message.id)
                return
            }
            if reduceMotion {
                proxy.scrollTo(sourceID, anchor: .center)
            } else {
                withAnimation(.timingCurve(0.2, 0, 0, 1, duration: 0.36)) {
                    proxy.scrollTo(sourceID, anchor: .center)
                }
            }
            highlightedMessageID = sourceID
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                if highlightedMessageID == sourceID {
                    highlightedMessageID = nil
                }
            }
        }
    }

    private func replySource(for message: PPMessagingMessageSnapshot) -> PPMessagingMessageSnapshot? {
        guard let replyID = message.replyToMessageID else { return nil }
        return state.messages.first(where: { $0.id == replyID })
    }

    private func grouping(at index: Int) -> PPMessagingGrouping {
        let message = state.messages[index]
        let previous = index > 0 ? state.messages[index - 1] : nil
        let next = index + 1 < state.messages.count ? state.messages[index + 1] : nil
        let joinsPrevious = previous.map { canGroup(message, with: $0) } ?? false
        let joinsNext = next.map { canGroup(message, with: $0) } ?? false

        switch (joinsPrevious, joinsNext) {
        case (false, false): return .single
        case (false, true): return .first
        case (true, true): return .middle
        case (true, false): return .last
        }
    }

    private func canGroup(
        _ message: PPMessagingMessageSnapshot,
        with other: PPMessagingMessageSnapshot
    ) -> Bool {
        guard message.senderID == other.senderID,
              Calendar.current.isDate(message.timestamp, inSameDayAs: other.timestamp) else {
            return false
        }
        return abs(message.timestamp.timeIntervalSince(other.timestamp)) <= 5 * 60
    }

    private func rowSpacing(after index: Int) -> CGFloat {
        grouping(at: index) == .last || grouping(at: index) == .single ? 10 : 3
    }

    private func needsDateSeparator(at index: Int) -> Bool {
        guard index > 0 else { return true }
        return !Calendar.current.isDate(
            state.messages[index].timestamp,
            inSameDayAs: state.messages[index - 1].timestamp
        )
    }

    private func audioState(for message: PPMessagingMessageSnapshot) -> PPMessagingAudioState {
        guard state.audioMessageID == message.id else {
            return .init(
                progress: 0,
                duration: message.duration,
                isPlaying: false,
                isLoading: false
            )
        }
        return .init(
            progress: state.audioProgress,
            duration: state.audioDuration > 0 ? state.audioDuration : message.duration,
            isPlaying: state.audioPlaying,
            isLoading: state.audioLoading
        )
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private enum PPMessagingScrollID: Hashable {
    case top
    case typing
    case bottom
}

// MARK: - Header and Screen States

private struct PPMessagingHeader: View {
    @ObservedObject var state: PPMessagingScreenState
    let relay: PPMessagingActionRelay
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        HStack(spacing: 11) {
            Button {
                relay.request(.close)
            } label: {
                Image(systemName: closeSymbol)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(PPMessagingPalette.controlSurface, in: Circle())
            }
            .buttonStyle(PPMessagingPressButtonStyle())
            .accessibilityLabel(localized("Close"))

            Button {
                relay.request(.profile)
            } label: {
                HStack(spacing: 11) {
                    PPMessagingAvatar(
                        name: state.conversationName,
                        urlString: state.avatarURLString,
                        isOnline: state.isOnline,
                        usesSupportLogo: state.usesSupportLogo
                    )

                    VStack(alignment: .leading, spacing: 1) {
                        Text(state.conversationName.isEmpty ? localized("Chat") : state.conversationName)
                            .font(.custom("Beiruti-Bold", size: 17, relativeTo: .headline))
                            .foregroundColor(PPMessagingPalette.primaryText)
                            .lineLimit(1)

                        HStack(spacing: 5) {
                            if state.isOnline {
                                Circle()
                                    .fill(PPMessagingPalette.online)
                                    .frame(width: 6, height: 6)
                                    .accessibilityHidden(true)
                            }
                            Text(state.presenceText)
                                .font(.custom("Beiruti-Medium", size: 12.5, relativeTo: .caption))
                                .foregroundColor(PPMessagingPalette.secondaryText)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                state.presenceText.isEmpty
                    ? state.conversationName
                    : "\(state.conversationName), \(state.presenceText)"
            )

            Menu {
                if !state.isPinned {
                    Button {
                        relay.request(.pin)
                    } label: {
                        Label(localized("chat.pin"), systemImage: "pin")
                    }
                }

                Button {
                    relay.request(.mute)
                } label: {
                    Label(
                        localized(state.isMuted ? "chat.unmute" : "chat.mute"),
                        systemImage: state.isMuted ? "speaker.wave.2.fill" : "speaker.slash.fill"
                    )
                }

                Button {
                    relay.request(.background)
                } label: {
                    Label(localized("chat.background"), systemImage: "photo.on.rectangle.angled")
                }

                Button {
                    relay.request(.report)
                } label: {
                    Label(
                        localized(state.isReported ? "chat.reported" : "chat.report"),
                        systemImage: "exclamationmark.bubble"
                    )
                }
                .disabled(state.isReported)

                Button(role: .destructive) {
                    relay.request(.bin)
                } label: {
                    Label(
                        localized(state.isBinned ? "chat.unbin" : "chat.bin"),
                        systemImage: state.isBinned ? "tray.and.arrow.up" : "trash"
                    )
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(PPMessagingPalette.controlSurface, in: Circle())
            }
            .buttonStyle(PPMessagingPressButtonStyle())
            .accessibilityLabel(localized("more"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PPMessagingPalette.hairline)
                .frame(height: 0.5)
        }
    }

    private var closeSymbol: String {
        if state.isModal { return "xmark" }
        return layoutDirection == .rightToLeft ? "chevron.right" : "chevron.left"
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private struct PPMessagingAvatar: View {
    let name: String
    let urlString: String
    let isOnline: Bool
    let usesSupportLogo: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if usesSupportLogo {
                    Image("PPLogo")
                        .resizable()
                        .scaledToFit()
                        .padding(7)
                        .background(Color.white)
                } else if let url = URL(string: urlString), !urlString.isEmpty {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            avatarFallback
                        }
                    }
                } else {
                    avatarFallback
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())
            .overlay(Circle().stroke(PPMessagingPalette.avatarStroke, lineWidth: 1))

            if isOnline {
                Circle()
                    .fill(PPMessagingPalette.online)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(PPMessagingPalette.canvasUIColor, lineWidth: 2))
                    .accessibilityHidden(true)
            }
        }
    }

    private var avatarFallback: some View {
        ZStack {
            LinearGradient(
                colors: [PPMessagingPalette.avatarTop, PPMessagingPalette.avatarBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(initials)
                .font(.custom("Beiruti-Bold", size: 17, relativeTo: .headline))
                .foregroundColor(PPMessagingPalette.primaryText)
        }
    }

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let value = parts.compactMap(\.first).map(String.init).joined()
        return value.isEmpty ? "P" : value.uppercased()
    }
}

private struct PPMessagingConnectionRibbon: View {
    let retry: () -> Void

    var body: some View {
        Button(action: retry) {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                Text(localized("chat_connection_interrupted"))
                    .font(.custom("Beiruti-Medium", size: 13, relativeTo: .footnote))
                    .lineLimit(2)
                Spacer(minLength: 4)
                Text(localized("KLang_Retry"))
                    .font(.custom("Beiruti-Bold", size: 13, relativeTo: .footnote))
            }
            .foregroundColor(PPMessagingPalette.warningText)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(PPMessagingPalette.warningSurface)
        }
        .buttonStyle(.plain)
        .accessibilityHint(localized("offline_action_message"))
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private struct PPMessagingLoadingState: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathes = false

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(PPMessagingPalette.controlSurface)
                    .frame(width: 72, height: 72)
                    .scaleEffect(reduceMotion ? 1 : (breathes ? 1.04 : 0.97))
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundColor(PPMessagingPalette.secondaryText)
            }

            VStack(spacing: 7) {
                Text(localized("chat_loading_messages_title"))
                    .font(.custom("Beiruti-Bold", size: 20, relativeTo: .title3))
                    .foregroundColor(PPMessagingPalette.primaryText)
                Text(localized("chat_loading_messages_subtitle"))
                    .font(.custom("Beiruti-Regular", size: 14, relativeTo: .subheadline))
                    .foregroundColor(PPMessagingPalette.secondaryText)
                    .multilineTextAlignment(.center)
            }

            ProgressView()
                .tint(PPMessagingPalette.secondaryText)
        }
        .padding(32)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                breathes = true
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private struct PPMessagingEmptyState: View {
    let focusComposer: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(PPMessagingPalette.controlSurface)
                    .frame(width: 94, height: 94)
                Circle()
                    .stroke(PPMessagingPalette.hairline, lineWidth: 1)
                    .frame(width: 118, height: 118)
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(PPMessagingPalette.secondaryText.opacity(0.45))
                    .offset(x: -27, y: -27)
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(PPMessagingPalette.primaryText)
            }

            VStack(spacing: 8) {
                Text(localized("chat_empty_thread_title"))
                    .font(.custom("Beiruti-Bold", size: 23, relativeTo: .title2))
                    .foregroundColor(PPMessagingPalette.primaryText)
                Text(localized("chat_empty_thread_subtitle"))
                    .font(.custom("Beiruti-Regular", size: 15, relativeTo: .body))
                    .foregroundColor(PPMessagingPalette.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: focusComposer) {
                Label(localized("chat_empty_thread_action"), systemImage: "square.and.pencil")
                    .font(.custom("Beiruti-Bold", size: 15, relativeTo: .body))
                    .padding(.horizontal, 18)
                    .frame(minHeight: 48)
                    .background(PPMessagingPalette.primaryText, in: Capsule())
                    .foregroundColor(PPMessagingPalette.inverseText)
            }
            .buttonStyle(PPMessagingPressButtonStyle())
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 28)
        .frame(maxWidth: 430)
        .accessibilityElement(children: .contain)
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private struct PPMessagingOfflineState: View {
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(PPMessagingPalette.secondaryText)
                .frame(width: 78, height: 78)
                .background(PPMessagingPalette.controlSurface, in: Circle())

            Text(localized("chat_offline_title"))
                .font(.custom("Beiruti-Bold", size: 22, relativeTo: .title2))
                .foregroundColor(PPMessagingPalette.primaryText)

            Text(localized("chat_offline_subtitle"))
                .font(.custom("Beiruti-Regular", size: 15, relativeTo: .body))
                .foregroundColor(PPMessagingPalette.secondaryText)
                .multilineTextAlignment(.center)

            Button(action: retry) {
                Text(localized("KLang_Retry"))
                    .font(.custom("Beiruti-Bold", size: 15, relativeTo: .body))
                    .padding(.horizontal, 22)
                    .frame(minHeight: 48)
                    .background(PPMessagingPalette.primaryText, in: Capsule())
                    .foregroundColor(PPMessagingPalette.inverseText)
            }
            .buttonStyle(PPMessagingPressButtonStyle())
        }
        .padding(32)
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

// MARK: - Message Rows

private enum PPMessagingGrouping {
    case single
    case first
    case middle
    case last
}

private enum PPMessagingRowAction {
    case reply
    case copy
    case unsend
    case retry
    case save
    case openMedia
    case toggleAudio
    case openReplySource
}

private struct PPMessagingAudioState {
    let progress: Double
    let duration: Double
    let isPlaying: Bool
    let isLoading: Bool
}

private struct PPMessagingMessageRow: View {
    let message: PPMessagingMessageSnapshot
    let grouping: PPMessagingGrouping
    let replySource: PPMessagingMessageSnapshot?
    let availableWidth: CGFloat
    let highlighted: Bool
    let audioState: PPMessagingAudioState
    let onAction: (PPMessagingRowAction) -> Void
    let onSeekAudio: (Double) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var appeared = false
    @State private var replyDragOffset: CGFloat = 0
    @State private var replyThresholdFeedbackSent = false

    var body: some View {
        bubble
            .frame(maxWidth: min(max(availableWidth * 0.79, 220), 430), alignment: message.isOutgoing ? .trailing : .leading)
            .frame(maxWidth: .infinity, alignment: message.isOutgoing ? .trailing : .leading)
            .offset(x: replyDragOffset)
            .opacity(appeared ? 1 : 0.01)
            .scaleEffect(appeared ? 1 : 0.985, anchor: message.isOutgoing ? .trailing : .leading)
            .overlay {
                if highlighted {
                    PPMessagingBubbleShape(
                        isOutgoing: message.isOutgoing,
                        grouping: grouping,
                        layoutDirection: layoutDirection
                    )
                    .stroke(PPMessagingPalette.highlight, lineWidth: 2)
                    .padding(-3)
                    .transition(.opacity)
                }
            }
            .contextMenu { contextMenu }
            .simultaneousGesture(replyGesture)
            .onAppear {
                guard !appeared else { return }
                if message.animatesEntrance && !reduceMotion {
                    withAnimation(.timingCurve(0.2, 0, 0, 1, duration: 0.32)) {
                        appeared = true
                    }
                } else {
                    appeared = true
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(message.isDeleted ? "" : localized("chat_message_actions_hint"))
            .accessibilityAction(named: Text(localized("reply"))) {
                onAction(.reply)
            }
            .accessibilityAction(named: Text(localized("copy"))) {
                if message.kind == "text", !message.text.isEmpty {
                    onAction(.copy)
                }
            }
    }

    private var bubble: some View {
        VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 7) {
            if let replyID = message.replyToMessageID {
                Button {
                    onAction(.openReplySource)
                } label: {
                    PPMessagingReplyPreview(
                        source: replySource,
                        sourceID: replyID,
                        isOutgoing: message.isOutgoing
                    )
                }
                .buttonStyle(.plain)
            }

            messageContent

            if let failureText = message.failureText {
                HStack(spacing: 7) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(failureText.isEmpty ? localized("chat_message_failed_title") : failureText)
                        .lineLimit(2)
                    Spacer(minLength: 3)
                    Button(localized("KLang_Retry")) {
                        onAction(.retry)
                    }
                    .font(.custom("Beiruti-Bold", size: 12, relativeTo: .caption))
                }
                .font(.custom("Beiruti-Medium", size: 11.5, relativeTo: .caption))
                .foregroundColor(PPMessagingPalette.failure)
            }

            PPMessagingMetadataRow(message: message)
        }
        .padding(.horizontal, message.kind == "sticker" ? 5 : 13)
        .padding(.vertical, message.kind == "sticker" ? 5 : 9)
        .background(
            PPMessagingBubbleShape(
                isOutgoing: message.isOutgoing,
                grouping: grouping,
                layoutDirection: layoutDirection
            )
            .fill(bubbleFill)
        )
        .overlay {
            PPMessagingBubbleShape(
                isOutgoing: message.isOutgoing,
                grouping: grouping,
                layoutDirection: layoutDirection
            )
            .stroke(message.failureText == nil ? bubbleStroke : PPMessagingPalette.failure.opacity(0.7), lineWidth: 0.8)
        }
        .shadow(
            color: message.isOutgoing ? .clear : PPMessagingPalette.incomingShadow,
            radius: grouping == .middle ? 0 : 9,
            y: 3
        )
    }

    @ViewBuilder
    private var messageContent: some View {
        if message.isDeleted {
            Label(localized("chat_message_unsent"), systemImage: "arrow.uturn.backward.circle")
                .font(.custom("Beiruti-Medium", size: 15, relativeTo: .body))
                .foregroundColor(contentSecondary)
        } else {
            switch message.kind {
            case "image":
                PPMessagingImageContent(message: message, isSticker: false) {
                    onAction(.openMedia)
                }
            case "video":
                PPMessagingVideoContent(message: message) {
                    onAction(.openMedia)
                }
            case "audio":
                PPMessagingAudioContent(
                    message: message,
                    state: audioState,
                    foreground: contentPrimary,
                    secondary: contentSecondary,
                    onToggle: { onAction(.toggleAudio) },
                    onSeek: onSeekAudio
                )
            case "sticker":
                PPMessagingImageContent(message: message, isSticker: true) {
                    onAction(.openMedia)
                }
            case "file":
                PPMessagingFileContent(message: message, foreground: contentPrimary)
            default:
                Text(message.text)
                    .font(.custom("Beiruti-Regular", size: 16.5, relativeTo: .body))
                    .foregroundColor(contentPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
    }

    @ViewBuilder
    private var contextMenu: some View {
        if !message.isDeleted {
            Button {
                onAction(.reply)
            } label: {
                Label(localized("reply"), systemImage: "arrowshape.turn.up.left")
            }

            if message.kind == "text", !message.text.isEmpty {
                Button {
                    onAction(.copy)
                } label: {
                    Label(localized("copy"), systemImage: "doc.on.doc")
                }
            }

            if message.isMedia {
                Button {
                    onAction(.save)
                } label: {
                    Label(localized("chat_media_download"), systemImage: "square.and.arrow.down")
                }
            }

            if message.canUnsend {
                Button(role: .destructive) {
                    onAction(.unsend)
                } label: {
                    Label(localized("chat_unsend"), systemImage: "arrow.uturn.backward")
                }
            }
        }
    }

    private var replyGesture: some Gesture {
        DragGesture(minimumDistance: 14, coordinateSpace: .local)
            .onChanged { value in
                guard !message.isDeleted,
                      abs(value.translation.width) > abs(value.translation.height) else { return }
                let direction = replyPhysicalDirection
                let directional = value.translation.width * direction
                let clamped = min(max(directional, 0), 82)
                replyDragOffset = clamped * direction
                if clamped >= 60, !replyThresholdFeedbackSent {
                    UISelectionFeedbackGenerator().selectionChanged()
                    replyThresholdFeedbackSent = true
                } else if clamped < 26 {
                    replyThresholdFeedbackSent = false
                }
            }
            .onEnded { _ in
                let shouldReply = abs(replyDragOffset) >= 60
                if shouldReply {
                    onAction(.reply)
                }
                let reset = { replyDragOffset = 0 }
                if reduceMotion {
                    reset()
                } else {
                    withAnimation(.timingCurve(0.2, 0, 0, 1, duration: 0.28), reset)
                }
                replyThresholdFeedbackSent = false
            }
    }

    private var replyPhysicalDirection: CGFloat {
        let rtl: CGFloat = layoutDirection == .rightToLeft ? -1 : 1
        return message.isOutgoing ? rtl : -rtl
    }

    private var bubbleFill: Color {
        message.isOutgoing ? PPMessagingPalette.outgoingBubble : PPMessagingPalette.incomingBubble
    }

    private var bubbleStroke: Color {
        message.isOutgoing ? PPMessagingPalette.outgoingStroke : PPMessagingPalette.incomingStroke
    }

    private var contentPrimary: Color {
        message.isOutgoing ? PPMessagingPalette.outgoingText : PPMessagingPalette.primaryText
    }

    private var contentSecondary: Color {
        message.isOutgoing ? PPMessagingPalette.outgoingSecondary : PPMessagingPalette.secondaryText
    }

    private var accessibilityLabel: String {
        let direction = localized(message.isOutgoing ? "chat_accessibility_outgoing" : "chat_accessibility_incoming")
        let content: String
        if message.isDeleted {
            content = localized("chat_message_unsent")
        } else {
            switch message.kind {
            case "image": content = localized("chat_reply_image")
            case "video": content = localized("chat_reply_video")
            case "audio": content = localized("chat_reply_audio")
            case "sticker": content = localized("chat_reply_sticker")
            default: content = message.text
            }
        }
        return "\(direction). \(content). \(PPMessagingFormatters.accessibleDate.string(from: message.timestamp))"
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private struct PPMessagingReplyPreview: View {
    let source: PPMessagingMessageSnapshot?
    let sourceID: String
    let isOutgoing: Bool

    var body: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(isOutgoing ? PPMessagingPalette.outgoingSecondary : PPMessagingPalette.secondaryText)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(localized("chat_replying"))
                    .font(.custom("Beiruti-Bold", size: 11.5, relativeTo: .caption))
                Text(previewText)
                    .font(.custom("Beiruti-Medium", size: 11.5, relativeTo: .caption))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundColor(isOutgoing ? PPMessagingPalette.outgoingSecondary : PPMessagingPalette.secondaryText)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            (isOutgoing ? PPMessagingPalette.outgoingReplySurface : PPMessagingPalette.incomingReplySurface),
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
        .accessibilityLabel(
            String(format: localized("chat_accessibility_reply_format"), previewText)
        )
    }

    private var previewText: String {
        guard let source else { return localized("chat_reply_unavailable") }
        if source.isDeleted { return localized("chat_message_unsent") }
        switch source.kind {
        case "image": return localized("chat_reply_image")
        case "video": return localized("chat_reply_video")
        case "audio": return localized("chat_reply_audio")
        case "sticker": return localized("chat_reply_sticker")
        default:
            return source.text.isEmpty ? sourceID : source.text
        }
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private struct PPMessagingMetadataRow: View {
    let message: PPMessagingMessageSnapshot

    var body: some View {
        HStack(spacing: 4) {
            Text(PPMessagingFormatters.time.string(from: message.timestamp))
                .font(.custom("Beiruti-Medium", size: 10.5, relativeTo: .caption2))
                .monospacedDigit()

            if message.isUploading && message.transferProgress > 0 && message.transferProgress < 1 {
                Text("\(Int(message.transferProgress * 100))%")
                    .monospacedDigit()
            }

            if message.isOutgoing {
                Image(systemName: statusSymbol)
                    .font(.system(size: 9.5, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
            }
        }
        .foregroundColor(
            message.isOutgoing
                ? PPMessagingPalette.outgoingSecondary
                : PPMessagingPalette.secondaryText
        )
        .accessibilityLabel(statusAccessibilityLabel)
    }

    private var statusSymbol: String {
        if message.failureText != nil { return "exclamationmark.circle.fill" }
        switch message.status {
        case 3: return "checkmark.circle.fill"
        case 2: return "checkmark.circle"
        case 1: return "checkmark"
        default: return "clock"
        }
    }

    private var statusAccessibilityLabel: String {
        let key: String
        if message.failureText != nil {
            key = "chat_message_failed_title"
        } else {
            switch message.status {
            case 3: key = "chat_status_read"
            case 2: key = "chat_status_delivered"
            case 1: key = "chat_status_sent"
            default: key = "chat_status_sending"
            }
        }
        return NSLocalizedString(key, comment: "")
    }
}

private struct PPMessagingImageContent: View {
    let message: PPMessagingMessageSnapshot
    let isSticker: Bool
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            ZStack {
                PPMessagingRemoteImage(
                    localImage: message.localImage,
                    url: message.mediaURL,
                    contentMode: isSticker ? .fit : .fill
                )
                .frame(height: mediaHeight)
                .clipShape(RoundedRectangle(cornerRadius: isSticker ? 14 : 16, style: .continuous))

                if message.isUploading {
                    PPMessagingTransferOverlay(progress: message.transferProgress)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localized(isSticker ? "chat_reply_sticker" : "chat_reply_image"))
        .accessibilityHint(localized("chat_media_view"))
    }

    private var mediaHeight: CGFloat {
        if isSticker { return 154 }
        guard message.mediaWidth > 0, message.mediaHeight > 0 else { return 210 }
        let ratio = message.mediaHeight / message.mediaWidth
        return min(max(250 * ratio, 150), 330)
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private struct PPMessagingVideoContent: View {
    let message: PPMessagingMessageSnapshot
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            ZStack {
                PPMessagingRemoteImage(
                    localImage: message.thumbnailImage,
                    url: message.thumbnailURL,
                    contentMode: .fill
                )
                .frame(height: mediaHeight)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 54, height: 54)
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundColor(.white)
                            .offset(x: 1)
                    }

                if message.isUploading {
                    PPMessagingTransferOverlay(progress: message.transferProgress)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localized("chat_reply_video"))
        .accessibilityHint(localized("chat_media_view"))
    }

    private var mediaHeight: CGFloat {
        guard message.mediaWidth > 0, message.mediaHeight > 0 else { return 210 }
        let ratio = message.mediaHeight / message.mediaWidth
        return min(max(250 * ratio, 150), 330)
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private struct PPMessagingRemoteImage: View {
    let localImage: UIImage?
    let url: URL?
    let contentMode: ContentMode

    var body: some View {
        Group {
            if let localImage {
                Image(uiImage: localImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: contentMode)
                    case .failure:
                        placeholder(systemName: "photo.badge.exclamationmark")
                    case .empty:
                        ZStack {
                            placeholder(systemName: "photo")
                            ProgressView().tint(PPMessagingPalette.secondaryText)
                        }
                    @unknown default:
                        placeholder(systemName: "photo")
                    }
                }
            } else {
                placeholder(systemName: "photo")
            }
        }
    }

    private func placeholder(systemName: String) -> some View {
        ZStack {
            PPMessagingPalette.mediaPlaceholder
            Image(systemName: systemName)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(PPMessagingPalette.secondaryText)
        }
    }
}

private struct PPMessagingTransferOverlay: View {
    let progress: Double

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
            VStack(spacing: 7) {
                ProgressView(value: progress)
                    .progressViewStyle(.circular)
                    .tint(.white)
                Text("\(Int(progress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.white)
            }
        }
        .accessibilityLabel(NSLocalizedString("Uploading…", comment: ""))
        .accessibilityValue("\(Int(progress * 100))%")
    }
}

private struct PPMessagingAudioContent: View {
    let message: PPMessagingMessageSnapshot
    let state: PPMessagingAudioState
    let foreground: Color
    let secondary: Color
    let onToggle: () -> Void
    let onSeek: (Double) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .fill(foreground.opacity(0.10))
                        .frame(width: 42, height: 42)
                    if state.isLoading {
                        ProgressView().tint(foreground)
                    } else {
                        Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(foreground)
                            .offset(x: state.isPlaying ? 0 : 1)
                    }
                }
            }
            .buttonStyle(PPMessagingPressButtonStyle())
            .accessibilityLabel(
                localized(state.isPlaying ? "voice_pause" : "voice_play")
            )

            VStack(alignment: .leading, spacing: 5) {
                PPMessagingWaveform(
                    samples: message.waveformSamples,
                    progress: state.progress,
                    active: foreground,
                    inactive: secondary.opacity(0.34)
                )
                .frame(height: 26)

                Slider(
                    value: Binding(
                        get: { state.progress },
                        set: { onSeek($0) }
                    ),
                    in: 0...1
                )
                .tint(foreground)
                .frame(height: 12)
                .accessibilityLabel(localized("voice_preview_progress"))

                HStack {
                    Text(formatDuration(state.progress * state.duration))
                    Spacer()
                    Text(formatDuration(state.duration))
                }
                .font(.custom("Beiruti-Medium", size: 10.5, relativeTo: .caption2))
                .monospacedDigit()
                .foregroundColor(secondary)
            }
            .frame(minWidth: 150)
        }
    }

    private func formatDuration(_ duration: Double) -> String {
        let safe = max(duration, 0)
        return String(format: "%d:%02d", Int(safe) / 60, Int(safe) % 60)
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private struct PPMessagingWaveform: View {
    let samples: [Double]
    let progress: Double
    let active: Color
    let inactive: Color

    var body: some View {
        GeometryReader { proxy in
            let normalized = samples.isEmpty ? fallbackSamples : samples
            let count = max(normalized.count, 1)
            let spacing: CGFloat = 2
            let width = max(1, (proxy.size.width - CGFloat(count - 1) * spacing) / CGFloat(count))
            HStack(alignment: .center, spacing: spacing) {
                ForEach(Array(normalized.enumerated()), id: \.offset) { index, value in
                    Capsule()
                        .fill(Double(index) / Double(count) <= progress ? active : inactive)
                        .frame(width: width, height: max(3, proxy.size.height * min(max(value, 0.12), 1)))
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .accessibilityHidden(true)
    }

    private var fallbackSamples: [Double] {
        [0.26, 0.48, 0.74, 0.38, 0.88, 0.55, 0.32, 0.68, 0.43, 0.82, 0.36, 0.58,
         0.29, 0.72, 0.46, 0.64, 0.34, 0.78, 0.52, 0.30, 0.62, 0.42, 0.70, 0.37]
    }
}

private struct PPMessagingFileContent: View {
    let message: PPMessagingMessageSnapshot
    let foreground: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.fill")
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 42, height: 42)
                .background(foreground.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(message.text.isEmpty ? localized("chat_notification_file") : message.text)
                .font(.custom("Beiruti-Medium", size: 15, relativeTo: .body))
                .lineLimit(3)
        }
        .foregroundColor(foreground)
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private struct PPMessagingTypingRow: View {
    let name: String

    var body: some View {
        HStack(spacing: 9) {
            PPMessagingTypingDots()
            Text(String(format: localized("chat_typing_format"), name))
                .font(.custom("Beiruti-Medium", size: 12.5, relativeTo: .footnote))
                .foregroundColor(PPMessagingPalette.secondaryText)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(PPMessagingPalette.incomingBubble, in: Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 5)
        .accessibilityElement(children: .combine)
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private struct PPMessagingTypingDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var activeIndex = 0
    private let timer = Timer.publish(every: 0.28, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(PPMessagingPalette.secondaryText)
                    .frame(width: 5, height: 5)
                    .scaleEffect(reduceMotion ? 1 : (activeIndex == index ? 1.22 : 0.82))
                    .opacity(reduceMotion ? 0.72 : (activeIndex == index ? 1 : 0.42))
            }
        }
        .onReceive(timer) { _ in
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                activeIndex = (activeIndex + 1) % 3
            }
        }
        .accessibilityHidden(true)
    }
}

private struct PPMessagingDateSeparator: View {
    let date: Date

    var body: some View {
        HStack(spacing: 9) {
            line
            Text(label)
                .font(.custom("Beiruti-Bold", size: 11.5, relativeTo: .caption))
                .foregroundColor(PPMessagingPalette.secondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(PPMessagingPalette.separatorSurface, in: Capsule())
            line
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(PPMessagingFormatters.accessibleDate.string(from: date))
    }

    private var line: some View {
        Rectangle()
            .fill(PPMessagingPalette.hairline)
            .frame(height: 0.5)
    }

    private var label: String {
        if Calendar.current.isDateInToday(date) {
            return localized("chat_date_today")
        }
        if Calendar.current.isDateInYesterday(date) {
            return localized("chat_date_yesterday")
        }
        return PPMessagingFormatters.dateSeparator.string(from: date)
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private struct PPMessagingUnreadSeparator: View {
    var body: some View {
        HStack(spacing: 9) {
            line
            Label(localized("chat_unread"), systemImage: "sparkle")
                .font(.custom("Beiruti-Bold", size: 11.5, relativeTo: .caption))
                .foregroundColor(PPMessagingPalette.highlight)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(PPMessagingPalette.highlight.opacity(0.10), in: Capsule())
            line
        }
        .accessibilityElement(children: .combine)
    }

    private var line: some View {
        Rectangle()
            .fill(PPMessagingPalette.highlight.opacity(0.28))
            .frame(height: 0.5)
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private struct PPMessagingLatestButton: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 13, weight: .bold))
                if count > 0 {
                    Text("\(count)")
                        .font(.caption.bold().monospacedDigit())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(PPMessagingPalette.highlight, in: Capsule())
                        .foregroundColor(.white)
                }
            }
            .foregroundColor(PPMessagingPalette.primaryText)
            .frame(minWidth: 44, minHeight: 44)
            .padding(.horizontal, count > 0 ? 8 : 0)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(PPMessagingPalette.hairline, lineWidth: 0.8))
        }
        .buttonStyle(PPMessagingPressButtonStyle())
        .accessibilityLabel(
            count > 0
                ? String(format: localized("chat_unread_count_format"), count)
                : localized("chat_scroll_latest")
        )
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

// MARK: - Media Viewer

private struct PPMessagingMediaViewer: View {
    let message: PPMessagingMessageSnapshot
    let close: () -> Void
    let onSave: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if message.kind == "video", let url = message.mediaURL {
                PPMessagingVideoPlayer(url: url)
                    .ignoresSafeArea(edges: .horizontal)
            } else {
                PPMessagingRemoteImage(
                    localImage: message.localImage,
                    url: message.mediaURL,
                    contentMode: .fit
                )
                .padding(.horizontal, 8)
            }

            VStack {
                HStack {
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel(localized("Close"))

                    Spacer()

                    Button(action: onSave) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel(localized("chat_media_download"))
                }
                .padding(16)
                Spacer()
            }
        }
        .statusBar(hidden: true)
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private final class PPMessagingVideoPlayerModel: ObservableObject {
    let player: AVPlayer

    init(url: URL) {
        player = AVPlayer(url: url)
    }

    deinit {
        player.pause()
    }
}

private struct PPMessagingVideoPlayer: View {
    @StateObject private var model: PPMessagingVideoPlayerModel

    init(url: URL) {
        _model = StateObject(wrappedValue: PPMessagingVideoPlayerModel(url: url))
    }

    var body: some View {
        VideoPlayer(player: model.player)
            .onAppear { model.player.play() }
            .onDisappear { model.player.pause() }
    }
}

// MARK: - Shape, Canvas, Motion, Formatting

private struct PPMessagingBubbleShape: Shape {
    let isOutgoing: Bool
    let grouping: PPMessagingGrouping
    let layoutDirection: LayoutDirection

    func path(in rect: CGRect) -> Path {
        let speakerOnPhysicalRight = isOutgoing != (layoutDirection == .rightToLeft)
        let large: CGFloat = 21
        let joined: CGFloat = 7

        var topLeft = large
        var topRight = large
        var bottomLeft = large
        var bottomRight = large

        let joinsPrevious = grouping == .middle || grouping == .last
        let joinsNext = grouping == .first || grouping == .middle

        if speakerOnPhysicalRight {
            if joinsPrevious { topRight = joined }
            if joinsNext { bottomRight = joined }
            if grouping == .single || grouping == .last { bottomRight = 9 }
        } else {
            if joinsPrevious { topLeft = joined }
            if joinsNext { bottomLeft = joined }
            if grouping == .single || grouping == .last { bottomLeft = 9 }
        }

        return Path(
            PPMessagingRoundedPath.path(
                rect: rect,
                topLeft: topLeft,
                topRight: topRight,
                bottomRight: bottomRight,
                bottomLeft: bottomLeft
            ).cgPath
        )
    }
}

private enum PPMessagingRoundedPath {
    static func path(
        rect: CGRect,
        topLeft: CGFloat,
        topRight: CGFloat,
        bottomRight: CGFloat,
        bottomLeft: CGFloat
    ) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + topRight),
            controlPoint: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY),
            controlPoint: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - bottomLeft),
            controlPoint: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topLeft, y: rect.minY),
            controlPoint: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.close()
        return path
    }
}

private struct PPMessagingCanvas: View {
    var body: some View {
        ZStack {
            PPMessagingPalette.canvas
            LinearGradient(
                colors: [
                    PPMessagingPalette.canvasGlowTop,
                    .clear,
                    PPMessagingPalette.canvasGlowBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct PPMessagingPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.96 : 1))
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.08)
                    : .timingCurve(0.2, 0, 0, 1, duration: configuration.isPressed ? 0.09 : 0.18),
                value: configuration.isPressed
            )
    }
}

private extension View {
    @ViewBuilder
    func ppInteractiveKeyboardDismissal() -> some View {
        if #available(iOS 16.0, *) {
            scrollDismissesKeyboard(.interactively)
        } else {
            self
        }
    }
}

private enum PPMessagingFormatters {
    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    static let dateSeparator: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("EEE d MMM")
        return formatter
    }()

    static let accessibleDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter
    }()
}

private enum PPMessagingPalette {
    static let canvasUIColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.045, green: 0.049, blue: 0.055, alpha: 1)
            : UIColor(red: 0.973, green: 0.969, blue: 0.963, alpha: 1)
    }
    static let canvas = Color(canvasUIColor)
    static let primaryText = Color(UIColor.label)
    static let secondaryText = Color(UIColor.secondaryLabel)
    static let inverseText = Color(UIColor.systemBackground)
    static let outgoingText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .white : UIColor(white: 0.98, alpha: 1)
    })
    static let outgoingSecondary = Color.white.opacity(0.68)
    static let incomingBubble = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.105, green: 0.113, blue: 0.125, alpha: 0.96)
            : UIColor(white: 1, alpha: 0.92)
    })
    static let outgoingBubble = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.24, green: 0.255, blue: 0.28, alpha: 1)
            : UIColor(red: 0.17, green: 0.18, blue: 0.20, alpha: 1)
    })
    static let incomingStroke = Color(UIColor.separator).opacity(0.28)
    static let outgoingStroke = Color.white.opacity(0.08)
    static let incomingShadow = Color.black.opacity(0.055)
    static let controlSurface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.085)
            : UIColor(white: 0, alpha: 0.045)
    })
    static let hairline = Color(UIColor.separator).opacity(0.42)
    static let separatorSurface = Color(UIColor.secondarySystemBackground).opacity(0.8)
    static let mediaPlaceholder = Color(UIColor.secondarySystemBackground)
    static let online = Color(red: 0.22, green: 0.70, blue: 0.45)
    static let failure = Color(red: 0.86, green: 0.25, blue: 0.27)
    static let highlight = Color(red: 0.37, green: 0.48, blue: 0.52)
    static let incomingReplySurface = Color(UIColor.tertiarySystemFill)
    static let outgoingReplySurface = Color.white.opacity(0.09)
    static let warningSurface = Color(UIColor.systemOrange).opacity(0.11)
    static let warningText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor.systemOrange : UIColor.systemOrange.darker(by: 0.22)
    })
    static let avatarStroke = Color(UIColor.separator).opacity(0.34)
    static let avatarTop = Color(UIColor.secondarySystemBackground)
    static let avatarBottom = Color(UIColor.tertiarySystemBackground)
    static let canvasGlowTop = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.22, green: 0.24, blue: 0.27, alpha: 0.16)
            : UIColor(red: 0.88, green: 0.85, blue: 0.80, alpha: 0.30)
    })
    static let canvasGlowBottom = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.14, blue: 0.16, alpha: 0.18)
            : UIColor(red: 0.93, green: 0.91, blue: 0.87, alpha: 0.24)
    })
}

private extension UIColor {
    func darker(by amount: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return self
        }
        return UIColor(
            hue: hue,
            saturation: saturation,
            brightness: max(brightness - amount, 0),
            alpha: alpha
        )
    }
}
