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
import PurePetsMessagingCore
import PurePetsMessagingUI
import SpearLivingChatHeader
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
    private var chatThread: ChatThreadModel?

    @objc(configureWithChatThread:)
    public func configure(with thread: ChatThreadModel) {
        onMain { [weak self] in
            guard let self = self else { return }
            self.chatThread = thread
            self.screenState.configure(thread: thread, isModal: true)
        }
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        let relay = PPMessagingActionRelay()
        relay.delegate = delegate
        relay.onSendText = { [weak self] text in
            self?.sendTextThroughExistingPipeline(text)
        }
        relay.onContextRequested = { [weak self] contextID in
            self?.presentSupportContextDetails(contextID: contextID)
        }

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

    private func presentSupportContextDetails(contextID: String?) {
        guard let thread = chatThread,
              screenState.isSupportThread,
              let contextID = contextID,
              contextID == thread.id,
              viewIfLoaded?.window != nil else {
            return
        }

        let title = thread.supportDisplayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let alert = UIAlertController(
            title: title.isEmpty ? NSLocalizedString("Support", comment: "") : title,
            message: PPMessagingSupportContextFormatter.detailsMessage(
                status: thread.supportStatus
            ),
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(
                title: NSLocalizedString("OK", comment: ""),
                style: .default
            )
        )
        present(alert, animated: true)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let root = hostingController?.rootView {
            root.relay.delegate = delegate
        }
    }

    private func sendTextThroughExistingPipeline(_ rawText: String) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty,
              let thread = chatThread else {
            return
        }
        let threadID = thread.id
        guard !threadID.isEmpty else { return }

        let senderID = UserManager.shared().currentUser?.id ?? ""
        let receiverID = Self.outgoingReceiverID(for: thread, senderID: senderID)
        guard !senderID.isEmpty,
              !receiverID.isEmpty,
              senderID != receiverID else {
            NSLog("[Chat] Refusing outgoing message without a valid sender/receiver identity")
            return
        }

        let message = ChatMessageModel()
        message.id = UUID().uuidString
        message.text = text
        message.senderID = senderID
        message.receiverID = receiverID
        message.timestamp = Date()
        message.messageType = .text

        screenState.appendOptimisticText(
            messageID: message.id,
            text: text,
            senderID: senderID
        )

        ChManager.shared().sendMessage(
            message,
            inThread: threadID,
            senderID: senderID
        ) { [weak self] error in
            guard let self else { return }
            self.onMain {
                if let error {
                    self.screenState.setFailure(
                        messageID: message.id,
                        message: NSLocalizedString(
                            "chat_message_failed_title",
                            comment: "Public message-send failure label"
                        )
                    )
                } else {
                    self.screenState.markMessageSent(messageID: message.id)
                }
            }
        }
    }

    private static func outgoingReceiverID(
        for thread: ChatThreadModel,
        senderID: String
    ) -> String {
        let resolvedOtherUserID =
            ChatThreadModel.resolveOtherUser(fromThread: thread)?.id ?? ""
        if !resolvedOtherUserID.isEmpty, resolvedOtherUserID != senderID {
            return resolvedOtherUserID
        }

        let supportUserID = thread.supportUserID
        if !supportUserID.isEmpty, supportUserID != senderID {
            return supportUserID
        }

        return thread.memberIDs.first {
            !$0.isEmpty && $0 != senderID
        } ?? ""
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

    @objc(configureConversationWithName:status:avatarURLString:isOnline:usesSupportLogo:isModal:unreadCount:isPinned:isMuted:isBinned:isReported:supportThread:supportThreadID:supportDisplayName:supportStatus:)
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
        isReported: Bool,
        supportThread: Bool,
        supportThreadID: String,
        supportDisplayName: String,
        supportStatus: String
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
                isReported: isReported,
                supportThread: supportThread,
                supportThreadID: supportThreadID,
                supportDisplayName: supportDisplayName,
                supportStatus: supportStatus
            )
        }
    }

    @objc(setConversationLastActiveAt:)
    public func setConversationLastActiveAt(_ date: Date?) {
        onMain { [weak self] in
            self?.screenState.lastActiveAt = date
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
            self?.screenState.setConnectionInterrupted(interrupted)
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

    @objc(setConversationBackgroundImage:)
    public func setConversationBackgroundImage(_ image: UIImage?) {
        onMain { [weak self] in
            self?.screenState.backgroundImage = image
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
    @Published var lastActiveAt: Date?
    @Published var usesSupportLogo = false
    @Published var isModal = false
    @Published var isPinned = false
    @Published var isMuted = false
    @Published var isBinned = false
    @Published var isReported = false
    @Published var isSupportThread = false
    @Published var supportThreadID = ""
    @Published var supportDisplayName = ""
    @Published var supportStatus = ""
    @Published var bottomNavigationClearance: CGFloat = 0
    @Published var backgroundImage: UIImage?
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
            let messageID = payload.ppString("id") ?? "unknown-\(payload.count)"
            return PPMessagingMessageSnapshot(
                payload: payload,
                currentUserID: currentUserID,
                failureText: failedMessages[messageID],
                animatesEntrance: animated && isTailUpdate && appendedIDs.contains(messageID)
            )
        }

        messages = snapshots
        self.initialLoadCompleted = initialLoadCompleted
        self.isLoading = !connectionInterrupted && !initialLoadCompleted && snapshots.isEmpty
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

    func setConnectionInterrupted(_ interrupted: Bool) {
        connectionInterrupted = interrupted
        if interrupted {
            isLoading = false
        } else if !initialLoadCompleted && messages.isEmpty {
            isLoading = true
        }
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
        isReported: Bool,
        supportThread: Bool,
        supportThreadID: String,
        supportDisplayName: String,
        supportStatus: String
    ) {
        conversationName = name
        presenceText = status
        self.avatarURLString = avatarURLString
        self.isOnline = isOnline
        self.lastActiveAt = nil
        self.usesSupportLogo = usesSupportLogo
        self.isModal = isModal
        self.isPinned = isPinned
        self.isMuted = isMuted
        self.isBinned = isBinned
        self.isReported = isReported
        self.isSupportThread = supportThread
        self.supportThreadID = supportThreadID
        self.supportDisplayName = supportDisplayName
        self.supportStatus = supportStatus
        if !didResolveUnreadBoundary {
            requestedInitialUnreadCount = max(0, unreadCount)
            resolveUnreadBoundaryIfNeeded()
        }
    }

    func configure(thread: ChatThreadModel, isModal: Bool) {
        let user = ChatThreadModel.resolveOtherUser(fromThread: thread) ?? thread.otherUser
        let isSupportThread = ChatThreadModel.isSupportThread(thread)
        let displayName: String = {
            if let bestName = user?.ppBestDisplayName(), !bestName.isEmpty {
                return bestName
            }
            if let userName = user?.userName, !userName.isEmpty {
                return userName
            }
            return NSLocalizedString(isSupportThread ? "Support" : "Chat", comment: "")
        }()
        let isOnline = user?.isOnline ?? false

        configureConversation(
            name: displayName,
            status: NSLocalizedString(isOnline ? "chat.online" : "chat.offline", comment: ""),
            avatarURLString: user?.userImageUrl?.absoluteString ?? "",
            isOnline: isOnline,
            usesSupportLogo: isSupportThread,
            isModal: isModal,
            unreadCount: max(0, thread.unreadCount),
            isPinned: thread.isPinned != 0,
            isMuted: thread.isMuted,
            isBinned: thread.isBinned,
            isReported: thread.isReportedByMe,
            supportThread: isSupportThread,
            supportThreadID: thread.id,
            supportDisplayName: thread.supportDisplayName,
            supportStatus: thread.supportStatus
        )
        lastActiveAt = user?.lastSeen
    }

    func appendOptimisticText(
        messageID: String,
        text: String,
        senderID: String
    ) {
        guard !messages.contains(where: { $0.id == messageID }) else { return }

        let snapshot = PPMessagingMessageSnapshot(
            payload: [
                "id": messageID,
                "text": text,
                "senderID": senderID,
                "timestamp": Date(),
                "kind": "text",
                "status": 0,
                "isLocalPending": true,
                "isOutgoing": true
            ],
            currentUserID: senderID,
            failureText: nil,
            animatesEntrance: true
        )
        messages.append(snapshot)
        knownMessageIDs.insert(messageID)
        latestAppendedCount = 1
        latestAppendContainsOutgoing = true
        messageRevision &+= 1
    }

    func markMessageSent(messageID: String) {
        messages = messages.map {
            guard $0.id == messageID else { return $0 }
            return $0.withDelivery(status: 1, isLocalPending: false)
        }
        messageRevision &+= 1
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
        let fallbackID = [
            payload.ppString("senderID") ?? "",
            payload.ppString("kind") ?? "text",
            payload.ppString("text") ?? "",
            String(payload.ppDouble("duration")),
            String(payload.ppDouble("mediaWidth")),
            String(payload.ppDouble("mediaHeight"))
        ].joined(separator: "|")
        id = payload.ppString("id") ?? "unknown-\(fallbackID)"
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

    private init(
        copying source: Self,
        failureText: String?,
        status: Int? = nil,
        isLocalPending: Bool? = nil
    ) {
        id = source.id
        text = source.text
        senderID = source.senderID
        timestamp = source.timestamp
        kind = source.kind
        self.status = status ?? source.status
        fileURLString = source.fileURLString
        thumbnailURLString = source.thumbnailURLString
        localImage = source.localImage
        thumbnailImage = source.thumbnailImage
        duration = source.duration
        mediaWidth = source.mediaWidth
        mediaHeight = source.mediaHeight
        waveformSamples = source.waveformSamples
        isUploading = source.isUploading
        self.isLocalPending = isLocalPending ?? source.isLocalPending
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

    func withDelivery(status: Int, isLocalPending: Bool) -> Self {
        Self(
            copying: self,
            failureText: failureText,
            status: status,
            isLocalPending: isLocalPending
        )
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
    var onSendText: ((String) -> Void)?
    var onContextRequested: ((String?) -> Void)?

    func sendText(_ text: String) {
        if let delegate {
            delegate.messagingHostDidSendText(text)
        } else {
            onSendText?(text)
        }
    }

    func request(_ action: PPMessagingAction, messageID: String? = nil) {
        if action == .context {
            onContextRequested?(messageID)
            return
        }
        delegate?.messagingHostDidRequestAction(action.rawValue, messageID: messageID)
    }
}

private enum PPMessagingAction: String {
    case close
    case more
    case profile
    case context
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

private enum PPMessagingSupportContextFormatter {
    static func statusText(_ rawStatus: String) -> String {
        let key: String
        switch rawStatus.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "waiting_for_agent":
            key = "chat_support_context_status_waiting_for_agent"
        case "waiting_for_provider":
            key = "chat_support_context_status_waiting_for_provider"
        case "active":
            key = "chat_support_context_status_active"
        case "resolved":
            key = "chat_support_context_status_resolved"
        case "closed":
            key = "chat_support_context_status_closed"
        default:
            key = "chat_support_context_status_unavailable"
        }
        return NSLocalizedString(key, comment: "")
    }

    static func detailsMessage(status: String) -> String {
        String(
            format: NSLocalizedString("chat_support_context_detail_format", comment: ""),
            statusText(status)
        )
    }
}

// MARK: - Screen

private struct PPMessagingScreen: View {
    @ObservedObject var state: PPMessagingScreenState
    let relay: PPMessagingActionRelay

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var languageCode = Language.currentLanguageCode() ?? "en"
    @State private var presentedMedia: PPMessagingMessageSnapshot?
    @State private var hasPositionedInitially = false
    @State private var isAtLatest = true
    @State private var unseenMessageCount = 0
    @State private var paginationAnchorID: String?
    @State private var highlightedMessageID: String?
    @State private var packageAudioCoordinator = ConversationAudioCoordinator()

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
                    presentation: .messaging,
                    chatBarHeight: 54,
                    onSendText: { relay.sendText($0) },
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
                .accessibilityIdentifier("pp.messaging.composer")
                .onReceive(state.composerState.$message.dropFirst()) { text in
                    relay.delegate?.messagingHostDidChangeText(text)
                }
                .padding(.horizontal, 22)
                .padding(.top, 9)
                .padding(
                    .bottom,
                    max(22, state.bottomNavigationClearance)
                )
                .background {
                    PPMessagingComposerBackdrop()
                }
            }
            // SpearChatHeader owns the status-bar inset internally. Let the
            // host stack reach the physical edges so that inset is applied
            // once and the composer can rest 22pt above the real bottom.
            .ignoresSafeArea(.container, edges: [.top, .bottom])
            .background {
                PPMessagingCanvas(backgroundImage: state.backgroundImage)
                    .ignoresSafeArea()
            }
            .accessibilityIdentifier("pp.messaging.screen")
        }
        .environment(
            \.layoutDirection,
            languageCode == "ar" ? .rightToLeft : .leftToRight
        )
        .environment(\.locale, Locale(identifier: languageCode))
        .onAppear {
            refreshLanguage()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("LanguageDidChangeNotification")
            )
        ) { _ in
            refreshLanguage()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("PPLanguageDidChangeNotification")
            )
        ) { _ in
            refreshLanguage()
        }
        .fullScreenCover(item: $presentedMedia) { message in
            PPMessagingMediaViewer(message: message) {
                presentedMedia = nil
            } onSave: {
                relay.request(.saveMedia, messageID: message.id)
            }
        }
    }

    private func refreshLanguage() {
        let nextLanguageCode = Language.currentLanguageCode() ?? "en"
        guard nextLanguageCode != languageCode else { return }
        languageCode = nextLanguageCode
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
        ScrollViewReader { proxy in
            ZStack(alignment: .bottom) {
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
                                    .padding(.vertical, index == 0 ? 8 : 10)
                            }

                            if state.unreadBoundaryMessageID == message.id {
                                PPMessagingUnreadSeparator()
                                    .id(PPMessagingScrollID.unreadBoundary)
                                    .padding(.vertical, 8)
                            }

                            SmartMessageCell(
                                message: PPMessagingAdapter.chatMessage(
                                    from: message,
                                    groupPosition: packageGroupPosition(at: index),
                                    replySource: replySource(for: message),
                                    audioState: audioState(for: message)
                                ),
                                showsAvatar: grouping(at: index) == .single || grouping(at: index) == .last,
                                audioCoordinator: packageAudioCoordinator,
                                actions: SmartMessageCell.Actions(
                                    onReply: { handleMessageAction(.reply, message: message, proxy: proxy) },
                                    onCopy: { handleMessageAction(.copy, message: message, proxy: proxy) },
                                    onForward: {},
                                    onDelete: { handleMessageAction(.unsend, message: message, proxy: proxy) },
                                    onRetry: { handleMessageAction(.retry, message: message, proxy: proxy) },
                                    onOpenReply: { _ in handleMessageAction(.openReplySource, message: message, proxy: proxy) },
                                    onOpenImage: { _ in handleMessageAction(.openMedia, message: message, proxy: proxy) },
                                    onOpenVideo: { _ in handleMessageAction(.openMedia, message: message, proxy: proxy) },
                                    onReactionTap: { _ in },
                                    onUpdateApp: {}
                                )
                            )
                            .id(message.id)
                            .accessibilityIdentifier("pp.messaging.message.\(message.id)")
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
                .accessibilityIdentifier("pp.messaging.messages")
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
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: UIResponder.keyboardWillChangeFrameNotification
                    )
                ) { _ in
                    // The composer is edge-to-edge and changes the available
                    // viewport when the keyboard moves. Preserve the user's
                    // position when they are reading older content, but keep
                    // the latest row visible for the normal send flow.
                    guard hasPositionedInitially, isAtLatest else { return }
                    DispatchQueue.main.async {
                        scrollToLatest(using: proxy, animated: !reduceMotion)
                    }
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
                    // Overlay-only placement keeps the button above the date
                    // and composer without changing message scroll insets.
                    .padding(.bottom, 18)
                    .zIndex(2)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
            }
        }
    }

    private func positionInitially(using proxy: ScrollViewProxy) {
        guard !hasPositionedInitially else { return }
        DispatchQueue.main.async {
            if state.unreadBoundaryMessageID != nil {
                proxy.scrollTo(PPMessagingScrollID.unreadBoundary, anchor: .top)
                isAtLatest = false
            } else {
                proxy.scrollTo(PPMessagingScrollID.bottom, anchor: .bottom)
                isAtLatest = true
            }
            hasPositionedInitially = true
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
        let joinsPrevious =
            state.unreadBoundaryMessageID != message.id &&
            (previous.map { canGroup(message, with: $0) } ?? false)
        let joinsNext =
            next?.id != state.unreadBoundaryMessageID &&
            (next.map { canGroup(message, with: $0) } ?? false)

        switch (joinsPrevious, joinsNext) {
        case (false, false): return .single
        case (false, true): return .first
        case (true, true): return .middle
        case (true, false): return .last
        }
    }

    private func packageGroupPosition(at index: Int) -> MessageGroupPosition {
        switch grouping(at: index) {
        case .single: return .isolated
        case .first: return .first
        case .middle: return .middle
        case .last: return .last
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
        grouping(at: index) == .last || grouping(at: index) == .single ? 11 : 2.5
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
    case unreadBoundary
}

// MARK: - Header and Screen States

private struct PPMessagingHeader: View {
    @ObservedObject var state: PPMessagingScreenState
    let relay: PPMessagingActionRelay

    var body: some View {
        SpearChatHeader(
            state: spearHeaderState,
            style: .spear,
            copy: Language.isRTL() ? .arabic : .english,
            actions: spearActions
        ) { _ in
            // Reuse the app's existing avatar presentation; Spear owns the
            // frame, trust ring, presence badge, and accessibility semantics.
            PPMessagingAvatar(
                name: state.conversationName,
                urlString: state.avatarURLString,
                isOnline: false,
                usesSupportLogo: state.usesSupportLogo
            )
        }
        .frame(minHeight: 72)
    }

    private var spearHeaderState: SpearChatHeaderLoadState {
        let name = state.conversationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return state.isLoading
                ? .loading
                : .unavailable(title: localized("Chat"), retryTitle: nil)
        }

        let presence: SpearPresence
        if state.isTyping {
            presence = .typing
        } else if state.isOnline {
            presence = .online(responseSpeed: nil)
        } else {
            // The Objective-C bridge supplies the real last-seen timestamp
            // when available. Date() is only a defensive fallback for legacy
            // profiles that have no lastSeen field.
            presence = .offline(lastActiveAt: state.lastActiveAt ?? Date())
        }

        let initials = name
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
        let fallback = initials.isEmpty
            ? SpearAvatarFallback.systemImage("person.crop.circle.fill")
            : SpearAvatarFallback.initials(initials.uppercased())

        let model = SpearChatHeaderModel(
            id: state.avatarURLString.isEmpty ? name : state.avatarURLString,
            name: name,
            avatarFallback: fallback,
            trust: .standard(role: nil),
            presence: presence,
            metrics: [],
            context: supportContext,
            isModal: state.isModal
        )
        return .ready(model)
    }

    private var supportContext: SpearConversationContext? {
        guard state.isSupportThread else { return nil }

        let threadID = state.supportThreadID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !threadID.isEmpty else { return nil }

        let displayName = state.supportDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return .support(
            SpearSupportContext(
                id: threadID,
                eyebrow: localized("Support"),
                title: displayName.isEmpty ? localized("Support") : displayName,
                detail: localizedSupportStatus(state.supportStatus),
                actionTitle: localized("details")
            )
        )
    }

    private func localizedSupportStatus(_ rawStatus: String) -> String {
        PPMessagingSupportContextFormatter.statusText(rawStatus)
    }

    private var spearActions: SpearChatHeaderActions {
        let contextAction: SpearContextHeaderAction = supportContext == nil
            ? .hidden
            : .enabled { context in
                relay.request(.context, messageID: context.id)
            }

        return SpearChatHeaderActions(
            onBack: { relay.request(.close) },
            more: .enabled { relay.request(.more) },
            profile: .enabled { relay.request(.profile) },
            context: contextAction
        )
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
                        .background(PPMessagingPalette.avatarLogoSurface)
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
            .frame(width: 44, height: 44)
            .clipShape(Circle())
            .overlay(Circle().stroke(PPMessagingPalette.avatarStroke, lineWidth: 0.8))

            if isOnline {
                Circle()
                    .fill(PPMessagingPalette.online)
                    .frame(width: 11, height: 11)
                    .overlay(Circle().stroke(Color(PPMessagingPalette.canvasUIColor), lineWidth: 2))
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

// MARK: - Snapshot → Package ChatMessage Adapter

private enum PPMessagingAdapter {
    /// Create a deterministic UUID from any string (Firestore doc IDs are not UUIDs).
    /// Uses XOR-folded hashing to produce stable identity across renders.

    private static func deterministicUUID(from string: String) -> UUID {
        guard !string.isEmpty else { return UUID() }
        // Try parsing as UUID first (handles already-valid UUIDs)
        if let parsed = UUID(uuidString: string) { return parsed }
        // Produce a stable UUID from the string via XOR-folded hash
        let sourceBytes = [UInt8](Data(string.utf8))
        var hash = [UInt8](repeating: 0, count: 16)
        for (i, byte) in sourceBytes.enumerated() {
            hash[i % 16] ^= byte
        }
        // Set version 5 and variant bits
        hash[6] = (hash[6] & 0x0F) | 0x50 // version 5
        hash[8] = (hash[8] & 0x3F) | 0x80 // variant
        return UUID(uuid: (hash[0], hash[1], hash[2], hash[3],
                           hash[4], hash[5], hash[6], hash[7],
                           hash[8], hash[9], hash[10], hash[11],
                           hash[12], hash[13], hash[14], hash[15]))
    }

    static func chatMessage(
        from snapshot: PPMessagingMessageSnapshot,
        groupPosition: MessageGroupPosition,
        replySource: PPMessagingMessageSnapshot?,
        audioState: PPMessagingAudioState
    ) -> ChatMessage {
        let senderUUID = deterministicUUID(from: snapshot.senderID)
        let displayName = snapshot.senderID.isEmpty ? "?" : snapshot.senderID
        let initials: String = {
            let id = snapshot.senderID
            if id.isEmpty { return "?" }
            // If it looks like a name (contains spaces), use name initials
            let parts = id.split(separator: " ").prefix(2)
            if parts.count >= 2 {
                return parts.compactMap(\.first).map(String.init).joined().uppercased()
            }
            // Otherwise use first two characters
            return String(id.prefix(2)).uppercased()
        }()

        let sender = MessageSender(
            id: senderUUID,
            displayName: displayName,
            avatarURL: nil,
            initials: initials
        )

        let direction: MessageDirection = {
            if snapshot.isOutgoing {
                return .outgoing(outgoingState(from: snapshot))
            } else {
                return .incoming(receivedAt: snapshot.timestamp)
            }
        }()

        let payload = messagePayload(from: snapshot, audioState: audioState)

        let replyRef: ReplyReference? = {
            guard let replyID = snapshot.replyToMessageID else { return nil }
            let preview: ReplyPreview
            if let src = replySource {
                if src.isDeleted {
                    preview = .deleted
                } else {
                    switch src.kind {
                    case "image": preview = .image
                    case "video": preview = .video
                    case "audio": preview = .voice
                    case "sticker": preview = .sticker(description: "Sticker")
                    default: preview = .text(src.text)
                    }
                }
            } else {
                preview = .unsupported
            }
            return ReplyReference(
                messageID: MessageID(deterministicUUID(from: replyID)),
                senderDisplayName: replySource?.senderID ?? "",
                preview: preview
            )
        }()

        return ChatMessage(
            id: MessageID(deterministicUUID(from: snapshot.id)),
            sender: sender,
            direction: direction,
            payload: payload,
            replyReference: replyRef,
            reactions: [],
            sentAt: snapshot.timestamp,
            groupPosition: groupPosition
        )
    }

    private static func outgoingState(from snapshot: PPMessagingMessageSnapshot) -> OutgoingDeliveryState {
        if snapshot.failureText != nil {
            return .failed(.unknown(code: nil))
        }
        if snapshot.isUploading {
            return .uploading(progress: snapshot.transferProgress)
        }
        if snapshot.isLocalPending {
            return .queued
        }
        switch snapshot.status {
        case 3: return .read(at: nil)
        case 2: return .delivered
        case 1: return .sent
        default: return .queued
        }
    }

    private static func messagePayload(
        from snapshot: PPMessagingMessageSnapshot,
        audioState: PPMessagingAudioState
    ) -> MessagePayload {
        if snapshot.isDeleted {
            return .deleted(DeletedPayload(deletedBy: .sender))
        }

        switch snapshot.kind {
        case "text":
            return .text(TextPayload(text: snapshot.text))

        case "image":
            return .image(ImagePayload(
                imageURL: snapshot.mediaURL,
                thumbnailURL: snapshot.thumbnailURL,
                dimensions: MediaDimensions(
                    width: max(snapshot.mediaWidth, 200),
                    height: max(snapshot.mediaHeight, 200)
                ),
                accessibilityDescription: NSLocalizedString("chat_reply_image", comment: "")
            ))

        case "video":
            return .video(VideoPayload(
                videoURL: snapshot.mediaURL,
                thumbnailURL: snapshot.thumbnailURL,
                duration: snapshot.duration,
                dimensions: MediaDimensions(
                    width: max(snapshot.mediaWidth, 200),
                    height: max(snapshot.mediaHeight, 200)
                ),
                accessibilityDescription: NSLocalizedString("chat_reply_video", comment: "")
            ))

        case "audio":
            return .voice(VoicePayload(
                audioURL: snapshot.mediaURL,
                duration: audioState.duration > 0 ? audioState.duration : snapshot.duration,
                waveform: snapshot.waveformSamples.isEmpty
                    ? Array(repeating: 0.4, count: 24)
                    : snapshot.waveformSamples,
                transcript: nil
            ))

        case "sticker":
            // swiftlint:disable:next force_try
            let desc = try! NonEmptyText(NSLocalizedString("chat_reply_sticker", comment: ""))
            return .sticker(StickerPayload(
                assetURL: snapshot.mediaURL,
                fallbackEmoji: "🐾",
                accessibilityDescription: desc,
                isAnimated: false
            ))

        case "file":
            return .unsupported(UnsupportedPayload(
                typeIdentifier: "file",
                schemaVersion: nil
            ))

        default:
            return .text(TextPayload(text: snapshot.text))
        }
    }
}

private struct PPMessagingReplyPreview: View {
    let source: PPMessagingMessageSnapshot?
    let sourceID: String
    let isOutgoing: Bool
    @Environment(\.layoutDirection) private var layoutDirection

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
                    .multilineTextAlignment(.leading)
                    .environment(
                        \.layoutDirection,
                        PPMessagingTextDirection.resolve(
                            previewText,
                            fallback: layoutDirection
                        )
                    )
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
            Text(PPMessagingFormatters.time(message.timestamp))
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

private struct PPMessagingTypingRow: View {
    let name: String
    @Environment(\.layoutDirection) private var layoutDirection

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
        .frame(maxWidth: .infinity, alignment: incomingAlignment)
        .padding(.top, 5)
        .accessibilityElement(children: .combine)
    }

    private var incomingAlignment: Alignment {
        layoutDirection == .rightToLeft ? .trailing : .leading
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
            ForEach([0, 1, 2], id: \.self) { index in
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 8) {
            if !dynamicTypeSize.isAccessibilitySize {
                line
            }
            Text(label)
                .font(.custom("Beiruti-Bold", size: 12, relativeTo: .caption))
                .foregroundColor(PPMessagingPalette.secondaryText)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(PPMessagingPalette.separatorSurface, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(PPMessagingPalette.controlStroke, lineWidth: 0.6)
                )
            if !dynamicTypeSize.isAccessibilitySize {
                line
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(PPMessagingFormatters.accessibleDate(date))
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
        return PPMessagingFormatters.dateSeparator(date)
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
                        .font(Font.ppBeirutiBold(size: 11, relativeTo: .caption).monospacedDigit())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(PPMessagingPalette.highlight, in: Capsule())
                        .foregroundColor(.white)
                }
            }
            .foregroundColor(PPMessagingPalette.primaryText)
            .frame(minWidth: 44, minHeight: 44)
            .padding(.horizontal, count > 0 ? 8 : 0)
            .background {
                if count > 0 {
                    Capsule(style: .continuous)
                        .fill(PPMessagingPalette.headerSurface)
                } else {
                    Circle()
                        .fill(PPMessagingPalette.headerSurface)
                }
            }
            .overlay {
                if count > 0 {
                    Capsule(style: .continuous)
                        .stroke(PPMessagingPalette.controlStroke, lineWidth: 0.8)
                } else {
                    Circle()
                        .stroke(PPMessagingPalette.controlStroke, lineWidth: 0.8)
                }
            }
            .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
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

    func path(in rect: CGRect) -> Path {
        let speakerOnPhysicalRight = isOutgoing
        let large: CGFloat = 20
        let joined: CGFloat = 6

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
    let backgroundImage: UIImage?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            WorldGlassBackground(
                intensity: colorScheme == .dark ? 0.72 : 0.88
            )

            if let backgroundImage {
                GeometryReader { proxy in
                    Image(uiImage: backgroundImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .saturation(0.28)
                        .contrast(0.92)
                        .opacity(colorScheme == .dark ? 0.16 : 0.22)
                        .id(ObjectIdentifier(backgroundImage))
                        .transition(.opacity)
                }

                PPMessagingPalette.canvas
                    .opacity(colorScheme == .dark ? 0.34 : 0.42)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: backgroundImage.map(ObjectIdentifier.init))
        .accessibilityHidden(true)
    }
}

private struct PPMessagingComposerBackdrop: View {
    var body: some View {
        LinearGradient(
            colors: [
                .clear,
                PPMessagingPalette.composerBackdrop.opacity(0.84),
                PPMessagingPalette.composerBackdrop
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct PPMessagingPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressAnimation = reduceMotion
            ? Animation.easeOut(duration: 0.08)
            : Animation.timingCurve(
                0.2,
                0,
                0,
                1,
                duration: configuration.isPressed ? 0.09 : 0.18
            )

        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.96 : 1))
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(pressAnimation, value: configuration.isPressed)
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

    @ViewBuilder
    func ppMessagingAccessibilityAction(
        enabled: Bool,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        if enabled {
            accessibilityAction(named: Text(label), action)
        } else {
            self
        }
    }
}

private enum PPMessagingTextDirection {
    static func resolve(
        _ text: String,
        fallback: LayoutDirection
    ) -> LayoutDirection {
        for scalar in text.unicodeScalars {
            if isRightToLeft(scalar.value) {
                return .rightToLeft
            }
            if CharacterSet.letters.contains(scalar) {
                return .leftToRight
            }
        }
        return fallback
    }

    private static func isRightToLeft(_ value: UInt32) -> Bool {
        switch value {
        case 0x0590...0x08FF,
             0xFB1D...0xFDFF,
             0xFE70...0xFEFF,
             0x10800...0x10FFF:
            return true
        default:
            return false
        }
    }
}

private enum PPMessagingFormatters {
    static func time(_ date: Date) -> String {
        active.time.string(from: date)
    }

    static func dateSeparator(_ date: Date) -> String {
        active.dateSeparator.string(from: date)
    }

    static func accessibleDate(_ date: Date) -> String {
        active.accessibleDate.string(from: date)
    }

    private static var active: FormatterSet {
        Language.isRTL() ? arabic : english
    }

    private static let arabic = FormatterSet(locale: Locale(identifier: "ar_QA"))
    private static let english = FormatterSet(locale: Locale(identifier: "en_QA"))

    private struct FormatterSet {
        let time: DateFormatter
        let dateSeparator: DateFormatter
        let accessibleDate: DateFormatter

        init(locale: Locale) {
            time = Self.makeTime(locale: locale)
            dateSeparator = Self.makeDateSeparator(locale: locale)
            accessibleDate = Self.makeAccessibleDate(locale: locale)
        }

        private static func makeTime(locale: Locale) -> DateFormatter {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            return formatter
        }

        private static func makeDateSeparator(locale: Locale) -> DateFormatter {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.setLocalizedDateFormatFromTemplate("EEE d MMM")
            return formatter
        }

        private static func makeAccessibleDate(locale: Locale) -> DateFormatter {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.dateStyle = .full
            formatter.timeStyle = .short
            return formatter
        }
    }

}

private enum PPMessagingPalette {
    static let canvasUIColor = UIColor { traits in
        let increasedContrast = traits.accessibilityContrast == .high
        if traits.userInterfaceStyle == .dark {
            return UIColor(
                red: increasedContrast ? 0.025 : 0.043,
                green: increasedContrast ? 0.028 : 0.048,
                blue: increasedContrast ? 0.030 : 0.050,
                alpha: 1
            )
        }
        return UIColor(
            red: increasedContrast ? 0.935 : 0.953,
            green: increasedContrast ? 0.925 : 0.945,
            blue: increasedContrast ? 0.905 : 0.929,
            alpha: 1
        )
    }
    static let canvas = Color(canvasUIColor)
    static let composerBackdrop = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.043, green: 0.048, blue: 0.050, alpha: 0.97)
            : UIColor(red: 0.953, green: 0.945, blue: 0.929, alpha: 0.97)
    })
    static let primaryText = Color.ppTextPrimary
    static let secondaryText = Color.ppTextSecondary
    static let inverseText = Color(UIColor.systemBackground)
    static let outgoingText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .white : UIColor(white: 0.98, alpha: 1)
    })
    static let outgoingSecondary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.72)
            : UIColor(white: 1.0, alpha: 0.76)
    })
    static let incomingBubble = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.095, green: 0.103, blue: 0.108, alpha: 0.98)
            : UIColor(red: 0.997, green: 0.991, blue: 0.976, alpha: 0.98)
    })
    static let outgoingBubble = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.200, green: 0.212, blue: 0.218, alpha: 1)
            : UIColor(red: 0.145, green: 0.153, blue: 0.158, alpha: 1)
    })
    static let incomingStroke = Color(UIColor { traits in
        let increasedContrast = traits.accessibilityContrast == .high
        if traits.userInterfaceStyle == .dark {
            return UIColor(white: 1.0, alpha: increasedContrast ? 0.24 : 0.10)
        }
        return UIColor(white: 0.05, alpha: increasedContrast ? 0.20 : 0.085)
    })
    static let outgoingStroke = Color.white.opacity(0.08)
    static let controlSurface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.075)
            : UIColor(white: 0, alpha: 0.038)
    })
    static let controlStroke = Color(UIColor { traits in
        let increasedContrast = traits.accessibilityContrast == .high
        return traits.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: increasedContrast ? 0.30 : 0.13)
            : UIColor(white: 0.0, alpha: increasedContrast ? 0.22 : 0.075)
    })
    static let hairline = Color.ppSeparator.opacity(0.72)
    static let separatorSurface = Color.ppElevatedSurface.opacity(0.90)
    static let mediaPlaceholder = Color.ppSecondarySurface
    static let online = Color.ppSuccess
    static let failure = Color.ppError
    static let highlight = PPChatComposerPalette.messagingAccent
    static let incomingReplySurface = Color(UIColor.tertiarySystemFill)
    static let outgoingReplySurface = Color.white.opacity(0.09)
    static let warningSurface = Color(UIColor.systemOrange).opacity(0.11)
    static let warningText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor.systemOrange : UIColor.systemOrange.darker(by: 0.22)
    })
    static let avatarStroke = Color.ppSeparator.opacity(0.78)
    static let avatarTop = Color.ppElevatedSurface
    static let avatarBottom = Color.ppSecondarySurface
    static let avatarLogoSurface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.92, alpha: 1)
            : UIColor.white
    })
    static let headerSurface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.055, green: 0.061, blue: 0.063, alpha: 0.94)
            : UIColor(red: 0.975, green: 0.965, blue: 0.946, alpha: 0.94)
    })
    static let headerHighlight = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.025)
            : UIColor(white: 1.0, alpha: 0.36)
    })
    static let canvasWarmField = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.22, green: 0.17, blue: 0.13, alpha: 0.16)
            : UIColor(red: 0.82, green: 0.73, blue: 0.62, alpha: 0.20)
    })
    static let canvasCoolField = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.16, blue: 0.17, alpha: 0.14)
            : UIColor(red: 0.62, green: 0.67, blue: 0.68, alpha: 0.12)
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
