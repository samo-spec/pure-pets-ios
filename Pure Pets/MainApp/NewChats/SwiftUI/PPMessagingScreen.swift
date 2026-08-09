//
//  PPMessagingScreen.swift
//  Pure Pets
//
//  The Objective-C delegate remains the primary behavior bridge. When a current
//  presenter has not supplied one, this host reuses existing app services for
//  safe local header actions without changing the message transport contract.
//

import AVKit
import Combine
import FirebaseStorage
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
public final class PPMessagingSwiftUIHostController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    @objc public weak var delegate: PPMessagingSwiftUIHostControllerDelegate? {
        didSet {
            actionRelay?.delegate = delegate
        }
    }

    private static var messagingToolbarSuppressionCount = 0
    private static var previousMessagingKeyboardManagerEnabled: Bool?
    private static var previousMessagingToolbarEnabled: Bool?

    private let screenState = PPMessagingScreenState()
    private var actionRelay: PPMessagingActionRelay?
    private var hostingController: UIHostingController<PPMessagingScreen>?
    private var chatThread: ChatThreadModel?
    private var launchPetAdContext: PetAd?
    private var messagePageLimit = 50
    private var messageObservationGeneration = 0
    private var conversationActivityGeneration = 0
    private var presenceObserverToken: Any?
    private var observedPresenceUserID = ""
    private var observedTypingThreadID = ""
    private var observedTypingUserID = ""
    private var isSuppressingMessagingToolbar = false
    private var isOpeningParticipantStories = false
    private var unsendingMessageIDs = Set<String>()
    private weak var containingNavigationController: UINavigationController?
    private var previousNavigationBarHidden: Bool?
    private var keyboardFrameObserver: NSObjectProtocol?
    private var lastObservedKeyboardOverlap: CGFloat = 0
    private var keyboardExpansionWorkItem: DispatchWorkItem?

    @objc(configureWithChatThread:)
    public func configure(with thread: ChatThreadModel) {
        configure(with: thread, petAdContext: nil)
    }

    @objc(configureWithChatThread:petAdContext:)
    public func configure(with thread: ChatThreadModel, petAdContext: PetAd?) {
        onMain { [weak self] in
            guard let self = self else { return }
            self.stopConversationActivityObservation()
            self.chatThread = thread
            self.launchPetAdContext = petAdContext
            self.screenState.configure(
                thread: thread,
                isModal: false,
                petAdContext: petAdContext
            )
            if self.viewIfLoaded?.window != nil {
                self.startConversationActivityObservationIfNeeded()
            }
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
        relay.onSendAudio = { [weak self] url, duration in
            self?.sendAudioThroughExistingPipeline(url: url, duration: duration)
        }
        relay.onCameraTap = { [weak self] in
            self?.presentImagePicker()
        }
        relay.onVideoTap = { [weak self] in
            self?.presentVideoPicker()
        }
        relay.onStickerSelected = { [weak self] sticker in
            self?.sendStickerThroughExistingPipeline(sticker)
        }
        relay.onContextRequested = { [weak self] contextID in
            self?.presentConversationContext(contextID: contextID)
        }
        relay.onActionRequested = { [weak self] action, messageID in
            self?.handleMessageAction(action, messageID: messageID)
        }
        actionRelay = relay

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

    private func presentConversationContext(contextID: String?) {
        guard let contextID, !contextID.isEmpty else {
            return
        }

        let contextType = screenState.contextType
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let isEntityContext = ["listing", "pet_listing", "pet_ad", "order"]
            .contains(contextType)

        if isEntityContext {
            if contextType == "pet_ad",
               let petAd = launchPetAdContext,
               petAd.adID == contextID {
                PPPetAdViewerLegacyBridge.openPetAd(petAd, from: self)
                return
            }

            if let delegate {
                delegate.messagingHostDidRequestAction(
                    PPMessagingAction.context.rawValue,
                    messageID: contextID
                )
            } else {
                presentConversationContextDetails(contextID: contextID)
            }
            return
        }

        guard screenState.isSupportThread else {
            if let delegate {
                delegate.messagingHostDidRequestAction(
                    PPMessagingAction.context.rawValue,
                    messageID: contextID
                )
            } else {
                presentConversationContextDetails(contextID: contextID)
            }
            return
        }

        guard let thread = chatThread,
              contextID == thread.id,
              viewIfLoaded?.window != nil else { return }

        let title = thread.supportDisplayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        PPAlertHelper.showInfo(
            in: self,
            title: title.isEmpty ? ppLocalized("Support") : title,
            subtitle: PPMessagingSupportContextFormatter.detailsMessage(
                status: thread.supportStatus
            )
        )
    }

    private func presentConversationContextDetails(contextID _: String) {
        guard viewIfLoaded?.window != nil else { return }

        let snapshot = screenState.contextSnapshot
        let title = [
            snapshot["title"] as? String,
            snapshot["displayTitle"] as? String,
            snapshot["orderNumber"] as? String
        ]
        .compactMap { value in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }
        .first ?? ppLocalized("details")

        let detail = [
            snapshot["detail"] as? String,
            snapshot["subtitle"] as? String,
            snapshot["statusText"] as? String
        ]
        .compactMap { value in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }
        .joined(separator: " · ")

        PPAlertHelper.showInfo(
            in: self,
            title: title,
            subtitle: detail.isEmpty ? nil : detail
        )
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        containingNavigationController = navigationController
        if previousNavigationBarHidden == nil {
            previousNavigationBarHidden = navigationController?.isNavigationBarHidden
        }
        navigationController?.setNavigationBarHidden(true, animated: animated)
        updateNavigationPresentationStyle()
        beginMessagingKeyboardToolbarSuppression()
        beginKeyboardFrameObservation()
        actionRelay?.delegate = delegate
        if let root = hostingController?.rootView {
            root.relay.delegate = delegate
        }
        startMessageObservationIfNeeded()
        startConversationActivityObservationIfNeeded()
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        endMessagingKeyboardToolbarSuppression()
        endKeyboardFrameObservation()

        let isLeavingScreen =
            isMovingFromParent ||
            isBeingDismissed ||
            navigationController?.isBeingDismissed == true
        if isLeavingScreen {
            if let previousNavigationBarHidden {
                containingNavigationController?.setNavigationBarHidden(
                    previousNavigationBarHidden,
                    animated: animated
                )
            }
            stopMessageObservation()
            stopConversationActivityObservation()
        }
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateBottomNavigationClearance()
    }

    public override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateBottomNavigationClearance()
    }

    deinit {
        endMessagingKeyboardToolbarSuppression()
        endKeyboardFrameObservation()
        stopMessageObservation()
        stopConversationActivityObservation()
    }

    private func updateBottomNavigationClearance() {
        let clearance = PPPetAdViewerLegacyBridge.bottomNavigationClearance(
            from: self
        )
        screenState.bottomNavigationClearance = max(0, clearance)
    }

    private func updateNavigationPresentationStyle() {
        guard let navigationController else {
            screenState.isModal = presentingViewController != nil
            return
        }
        screenState.isModal =
            navigationController.viewControllers.first === self &&
            navigationController.presentingViewController != nil
    }

    private func beginKeyboardFrameObservation() {
        guard keyboardFrameObserver == nil else { return }
        keyboardFrameObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleKeyboardFrameChange(notification)
        }
    }

    private func endKeyboardFrameObservation() {
        if let keyboardFrameObserver {
            NotificationCenter.default.removeObserver(keyboardFrameObserver)
            self.keyboardFrameObserver = nil
        }
        keyboardExpansionWorkItem?.cancel()
        keyboardExpansionWorkItem = nil
        lastObservedKeyboardOverlap = 0
        screenState.setKeyboardPresented(false)
    }

    private func handleKeyboardFrameChange(_ notification: Notification) {
        guard let window = viewIfLoaded?.window,
              let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey]
                as? CGRect else { return }

        let keyboardFrameInWindow = window.convert(endFrame, from: nil)
        let hostFrameInWindow = view.convert(view.bounds, to: window)
        let overlap = max(
            0,
            hostFrameInWindow.intersection(keyboardFrameInWindow).height
        )

        let previousOverlap = lastObservedKeyboardOverlap
        lastObservedKeyboardOverlap = overlap
        screenState.setKeyboardPresented(overlap > 1)

        if overlap <= 1 {
            keyboardExpansionWorkItem?.cancel()
            keyboardExpansionWorkItem = nil
            return
        }

        guard previousOverlap <= 1 || overlap > previousOverlap + 1 else {
            return
        }

        // Coalesce the keyboard's interactive frame stream. Height decreases
        // never publish, while a cancelled dismissal or a taller input mode
        // produces one correction only after its frames settle.
        keyboardExpansionWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.screenState.noteKeyboardExpansion()
            self?.keyboardExpansionWorkItem = nil
        }
        keyboardExpansionWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: workItem)
    }

    private func beginMessagingKeyboardToolbarSuppression() {
        guard !isSuppressingMessagingToolbar else { return }

        let manager = IQKeyboardManager.shared
        if Self.messagingToolbarSuppressionCount == 0 {
            Self.previousMessagingKeyboardManagerEnabled = manager().isEnabled
            Self.previousMessagingToolbarEnabled = manager().isEnableAutoToolbar
        }
        Self.messagingToolbarSuppressionCount += 1
        isSuppressingMessagingToolbar = true
        manager().isEnabled = false
        manager().isEnableAutoToolbar = false
        manager().reloadInputViews()
    }

    private func endMessagingKeyboardToolbarSuppression() {
        guard isSuppressingMessagingToolbar else { return }

        let manager = IQKeyboardManager.shared
        Self.messagingToolbarSuppressionCount = max(
            0,
            Self.messagingToolbarSuppressionCount - 1
        )
        isSuppressingMessagingToolbar = false

        guard Self.messagingToolbarSuppressionCount == 0 else { return }
        if let previousValue = Self.previousMessagingKeyboardManagerEnabled {
            manager().isEnabled = previousValue
        }
        if let previousValue = Self.previousMessagingToolbarEnabled {
            manager().isEnableAutoToolbar = previousValue
        }
        Self.previousMessagingKeyboardManagerEnabled = nil
        Self.previousMessagingToolbarEnabled = nil
        manager().reloadInputViews()
    }

    private func startMessageObservationIfNeeded() {
        guard let thread = chatThread, !thread.id.isEmpty else {
            screenState.setConnectionInterrupted(true)
            return
        }

        let threadID = thread.id
        messageObservationGeneration &+= 1
        let generation = messageObservationGeneration
        let limit = max(1, messagePageLimit)
        ChManager.shared().activeThreadID = threadID

        ChManager.shared().startObservingMessages(
            inThreadID: threadID,
            limit: limit
        ) { [weak self] messages, initialLoadCompleted, canLoadOlder, error in
            guard let self, generation == self.messageObservationGeneration else {
                return
            }

            if let error {
                NSLog(
                    "[ChatMessages] Failed to load thread %@: %@",
                    threadID,
                    error.localizedDescription
                )
                self.screenState.setConnectionInterrupted(true)
                self.screenState.isLoadingOlder = false
                return
            }

            let currentUserID = UserManager.shared().currentUser?.id ?? ""
            self.resolveStickerDownloadURLs(
                in: messages,
                currentUserID: currentUserID
            ) { [weak self] payloads in
                guard let self, generation == self.messageObservationGeneration else {
                    return
                }
                self.screenState.apply(
                    payloads: payloads,
                    currentUserID: currentUserID,
                    initialLoadCompleted: initialLoadCompleted,
                    canLoadOlder: canLoadOlder,
                    animated: initialLoadCompleted
                )
            }
        }

    }

    private func resolveStickerDownloadURLs(
        in messages: [ChatMessageModel],
        currentUserID: String,
        completion: @escaping ([[String: Any]]) -> Void
    ) {
        var payloads = messages.map {
            self.messagePayload(from: $0, currentUserID: currentUserID)
        }
        let unresolvedIndices = messages.indices.filter { index in
            let message = messages[index]
            guard message.isStickerMessage else { return false }

            let fileURL = message.fileURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let hasHTTPURL: Bool = {
                guard let url = URL(string: fileURL),
                      let scheme = url.scheme?.lowercased(),
                      (scheme == "http" || scheme == "https"),
                      url.host != nil else {
                    return false
                }
                return true
            }()
            return !hasHTTPURL && !(message.stickerStoragePath?.isEmpty ?? true)
        }

        guard !unresolvedIndices.isEmpty else {
            completion(payloads)
            return
        }

        let group = DispatchGroup()
        let lock = NSLock()

        for index in unresolvedIndices {
            let message = messages[index]
            let path = message.stickerStoragePath!.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else { continue }

            group.enter()
            let reference: StorageReference
            if path.hasPrefix("gs://") {
                reference = Storage.storage().reference(forURL: path)
            } else {
                reference = Storage.storage().reference(withPath: path)
            }
            reference.downloadURL { [weak self] url, error in
                defer { group.leave() }
                guard let url else {
                    NSLog(
                        "[ChatStickers] Failed to resolve Storage path %@ for message %@: %@",
                        path,
                        message.id,
                        error?.localizedDescription ?? "unknown error"
                    )
                    return
                }
                lock.lock()
                payloads[index]["fileURL"] = url.absoluteString
                lock.unlock()
                self?.logStickerResolution(messageID: message.id, path: path)
            }
        }

        group.notify(queue: .main) {
            completion(payloads)
        }
    }

    private func logStickerResolution(messageID: String, path: String) {
        NSLog("[ChatStickers] Resolved Storage path %@ for message %@", path, messageID)
    }

    private func stopMessageObservation() {
        guard let threadID = chatThread?.id, !threadID.isEmpty else {
            return
        }
        messageObservationGeneration &+= 1
        ChManager.shared().stopObservingMessages(inThreadID: threadID)
        if ChManager.shared().activeThreadID == threadID {
            ChManager.shared().activeThreadID = nil
        }
    }

    private func startConversationActivityObservationIfNeeded() {
        let participantID = screenState.participantID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let threadID = chatThread?.id
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !participantID.isEmpty, !threadID.isEmpty else {
            stopConversationActivityObservation()
            return
        }

        guard participantID != observedPresenceUserID
                || participantID != observedTypingUserID
                || threadID != observedTypingThreadID else {
            refreshConversationPresence(participantID: participantID)
            return
        }

        stopConversationActivityObservation()
        conversationActivityGeneration &+= 1
        let generation = conversationActivityGeneration
        observedPresenceUserID = participantID
        observedTypingUserID = participantID
        observedTypingThreadID = threadID

        let presenceManager = ChatPresenceManager.shared()
        presenceObserverToken = presenceManager.addPresenceObserver {
            [weak self] updatedUserID in
            guard updatedUserID == participantID else { return }
            self?.onMain { [weak self] in
                guard let self,
                      generation == self.conversationActivityGeneration,
                      self.observedPresenceUserID == participantID else { return }
                self.refreshConversationPresence(participantID: participantID)
            }
        }
        presenceManager.startObservingUsers([participantID])
        refreshConversationPresence(participantID: participantID)

        ChManager.shared().startListeningForOtherUserTyping(
            inThread: threadID,
            otherUser: participantID
        ) { [weak self] isTyping in
            self?.onMain { [weak self] in
                guard let self,
                      generation == self.conversationActivityGeneration,
                      self.observedTypingThreadID == threadID,
                      self.observedTypingUserID == participantID else { return }
                self.screenState.isTyping = isTyping
            }
        }
    }

    private func refreshConversationPresence(participantID: String) {
        let manager = ChatPresenceManager.shared()
        screenState.isOnline = manager.isUserOnline(participantID)
        screenState.lastActiveAt = manager.lastSeen(forUser: participantID)
    }

    private func stopConversationActivityObservation() {
        conversationActivityGeneration &+= 1

        if let presenceObserverToken {
            ChatPresenceManager.shared().removePresenceObserver(
                presenceObserverToken
            )
            self.presenceObserverToken = nil
        }

        if !observedTypingThreadID.isEmpty,
           !observedTypingUserID.isEmpty {
            ChManager.shared().stopListeningForOtherUserTyping(
                inThread: observedTypingThreadID,
                otherUser: observedTypingUserID
            )
        }

        observedPresenceUserID = ""
        observedTypingThreadID = ""
        observedTypingUserID = ""
        screenState.isTyping = false
    }

    private func loadOlderMessages() {
        guard !screenState.isLoadingOlder, screenState.canLoadOlder else {
            return
        }
        screenState.isLoadingOlder = true
        messagePageLimit += 50
        startMessageObservationIfNeeded()
    }

    private func handleMessageAction(
        _ action: PPMessagingAction,
        messageID: String? = nil
    ) {
        switch action {
        case .loadOlder:
            loadOlderMessages()
        case .retryConnection:
            screenState.setConnectionInterrupted(false)
            startMessageObservationIfNeeded()
        case .close:
            closeMessagingHost()
        case .more:
            presentConversationActions()
        case .profile:
            presentParticipantStories()
        case .report:
            presentReportConfirmation()
        case .context:
            presentConversationContext(contextID: messageID)
        case .reply:
            beginReply(messageID: messageID)
        case .copy:
            PPHUD.showSuccess(ppLocalized("chat_copied"))
        case .unsend:
            confirmUnsend(messageID: messageID)
        case .replyUnavailable:
            PPHUD.showInfo(ppLocalized("chat_reply_unavailable"))
        case .composerCancelledReply:
            screenState.clearReplyComposer()
        default:
            break
        }
    }

    private func beginReply(messageID: String?) {
        guard let messageID,
              let message = screenState.message(withID: messageID) else {
            PPHUD.showInfo(ppLocalized("chat_reply_unavailable"))
            return
        }

        screenState.beginReply(to: message)
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func confirmUnsend(messageID: String?) {
        guard let messageID,
              let message = screenState.message(withID: messageID),
              message.isUnsendEligible(at: Date()),
              let thread = chatThread,
              !thread.id.isEmpty,
              !unsendingMessageIDs.contains(messageID),
              viewIfLoaded?.window != nil else {
            PPHUD.showInfo(ppLocalized("chat_unsend_failed"))
            return
        }

        PPAlertHelper.showConfirmation(
            in: self,
            title: ppLocalized("chat_unsend_title"),
            subtitle: ppLocalized("chat_unsend_confirmation"),
            confirmButton: ppLocalized("chat_unsend"),
            cancelButton: ppLocalized("chat.cancel"),
            icon: UIImage(systemName: "trash"),
            confirmBlock: { [weak self] _, didConfirm in
                guard didConfirm else { return }
                self?.unsendMessage(
                    messageID: messageID,
                    threadID: thread.id
                )
            },
            cancelBlock: nil
        )
    }

    private func unsendMessage(messageID: String, threadID: String) {
        guard !unsendingMessageIDs.contains(messageID) else { return }
        unsendingMessageIDs.insert(messageID)
        PPHUD.showLoading()

        ChManager.shared().unsendMessage(
            withID: messageID,
            threadID: threadID
        ) { [weak self] error in
            self?.onMain {
                guard let self else { return }
                self.unsendingMessageIDs.remove(messageID)
                PPHUD.dismiss()

                if error != nil {
                    PPHUD.showError(self.ppLocalized("chat_unsend_failed"))
                    return
                }

                self.screenState.markMessageUnsent(messageID: messageID)
                PPHUD.showSuccess(self.ppLocalized("chat_unsend_success"))
            }
        }
    }

    private func closeMessagingHost() {
        if let navigationController {
            if navigationController.viewControllers.first === self,
               navigationController.presentingViewController != nil {
                navigationController.dismiss(animated: true)
            } else if navigationController.topViewController === self {
                navigationController.popViewController(animated: true)
            } else {
                dismiss(animated: true)
            }
            return
        }
        dismiss(animated: true)
    }

    private func presentConversationActions() {
        guard let thread = chatThread,
              viewIfLoaded?.window != nil else { return }

        let rootView = PPMessagingConversationActionsSheet(
            title: ppLocalized("chat.actions.title"),
            conversationName: screenState.conversationName,
            isPinned: thread.isPinned != 0,
            isMuted: thread.isMuted,
            isBinned: thread.isBinned,
            isReported: thread.isReportedByMe,
            onPin: delegate == nil ? nil : { [weak self] in
                self?.delegate?.messagingHostDidRequestAction(
                    PPMessagingAction.pin.rawValue,
                    messageID: nil
                )
            },
            onMute: { [weak self] in
                self?.toggleMuteThread()
            },
            onBackground: delegate == nil ? nil : { [weak self] in
                self?.delegate?.messagingHostDidRequestAction(
                    PPMessagingAction.background.rawValue,
                    messageID: nil
                )
            },
            onReport: thread.isReportedByMe ? nil : { [weak self] in
                self?.presentReportConfirmation()
            },
            onBin: { [weak self] in
                self?.confirmBinThread()
            }
        )
        .environment(
            \.layoutDirection,
            Language.isRTL() ? .rightToLeft : .leftToRight
        )
        .environment(
            \.locale,
            Locale(identifier: Language.isRTL() ? "ar_QA" : "en_QA")
        )

        let controller = UIHostingController(rootView: rootView)
        controller.view.backgroundColor = .clear
        controller.modalPresentationStyle = .pageSheet

        if let sheet = controller.sheetPresentationController {
            let actionDetent = UISheetPresentationController.Detent.custom {
                context in
                min(
                    context.maximumDetentValue,
                    max(390, context.maximumDetentValue * 0.62)
                )
            }
            sheet.detents = [actionDetent]
            sheet.prefersGrabberVisible = false
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            sheet.preferredCornerRadius = 32
        }

        present(controller, animated: true)
    }

    private func toggleMuteThread() {
        guard let thread = chatThread,
              !thread.id.isEmpty else { return }

        let nextMuted = !thread.isMuted
        PPHUD.showLoading()
        ChManager.shared().muteThread(
            withID: thread.id,
            muted: nextMuted
        ) { [weak self] error in
            self?.onMain {
                guard let self else { return }
                PPHUD.dismiss()
                if error != nil {
                    PPHUD.showError(self.ppLocalized("SomethingWentWrong"))
                    return
                }

                thread.isMuted = nextMuted
                let currentUserID = UserManager.shared().currentUser?.id ?? ""
                if !currentUserID.isEmpty {
                    var mutedBy = thread.mutedBy
                    if nextMuted {
                        if !mutedBy.contains(currentUserID) {
                            mutedBy.append(currentUserID)
                        }
                    } else {
                        mutedBy.removeAll { $0 == currentUserID }
                    }
                    thread.mutedBy = mutedBy
                }
                self.screenState.isMuted = nextMuted
                PPHUD.showSuccess(
                    self.ppLocalized(nextMuted ? "chat.muted" : "chat.unmuted")
                )
            }
        }
    }

    private func confirmBinThread() {
        guard let thread = chatThread,
              !thread.id.isEmpty else { return }

        let nextBinned = !thread.isBinned
        PPAlertHelper.showConfirmation(
            in: self,
            title: ppLocalized(
                nextBinned
                    ? "chat.bin.confirm.title"
                    : "chat.unbin.confirm.title"
            ),
            subtitle: ppLocalized(
                nextBinned
                    ? "chat.bin.confirm.message"
                    : "chat.unbin.confirm.message"
            ),
            confirmButton: ppLocalized(
                nextBinned ? "chat.bin.confirm.action" : "chat.unbin"
            ),
            cancelButton: ppLocalized("chat.cancel"),
            icon: UIImage(
                systemName: nextBinned
                    ? "archivebox.fill"
                    : "tray.and.arrow.up.fill"
            ),
            confirmBlock: { [weak self] _, didConfirm in
                guard didConfirm else { return }
                self?.updateBinState(thread: thread, binned: nextBinned)
            },
            cancelBlock: nil
        )
    }

    private func updateBinState(thread: ChatThreadModel, binned: Bool) {
        PPHUD.showLoading()
        ChManager.shared().binThread(
            withID: thread.id,
            binned: binned
        ) { [weak self] error in
            self?.onMain {
                guard let self else { return }
                PPHUD.dismiss()
                if error != nil {
                    PPHUD.showError(self.ppLocalized("SomethingWentWrong"))
                    return
                }

                thread.isBinned = binned
                let currentUserID = UserManager.shared().currentUser?.id ?? ""
                if !currentUserID.isEmpty {
                    var binnedBy = thread.binnedBy
                    if binned {
                        if !binnedBy.contains(currentUserID) {
                            binnedBy.append(currentUserID)
                        }
                    } else {
                        binnedBy.removeAll { $0 == currentUserID }
                    }
                    thread.binnedBy = binnedBy
                }
                self.screenState.isBinned = binned
                PPHUD.showSuccess(
                    self.ppLocalized(binned ? "chat.binned" : "chat.unbinned")
                )

                if binned {
                    NotificationCenter.default.post(
                        name: Notification.Name("forceReloadThreads"),
                        object: nil
                    )
                    self.closeMessagingHost()
                }
            }
        }
    }

    private func presentReportConfirmation() {
        guard let thread = chatThread else { return }
        if thread.isReportedByMe {
            PPHUD.showInfo(ppLocalized("chat.report.already"))
            return
        }

        PPAlertHelper.showDestructiveTextField(
            in: self,
            title: ppLocalized("chat.report.title"),
            subtitle: ppLocalized("chat.report.message"),
            placeholder: ppLocalized("chat.report.reason.placeholder"),
            initialText: nil,
            confirmText: ppLocalized("chat.report.confirm"),
            cancelText: ppLocalized("chat.cancel"),
            icon: UIImage(systemName: "exclamationmark.bubble.fill")
        ) { [weak self] reason, didConfirm in
            guard didConfirm else { return }
            self?.submitReport(thread: thread, reason: reason ?? "")
        }
    }

    private func submitReport(thread: ChatThreadModel, reason: String) {
        guard !thread.isReportedByMe else {
            PPHUD.showInfo(ppLocalized("chat.report.already"))
            return
        }

        PPHUD.showLoading()
        ChManager.shared().reportThread(
            thread,
            reason: reason
        ) { [weak self] error in
            self?.onMain {
                guard let self else { return }
                PPHUD.dismiss()
                if error != nil {
                    PPHUD.showError(self.ppLocalized("SomethingWentWrong"))
                    return
                }

                thread.isReportedByMe = true
                let currentUserID = UserManager.shared().currentUser?.id ?? ""
                if !currentUserID.isEmpty {
                    var reportedBy = thread.reportedBy
                    if !reportedBy.contains(currentUserID) {
                        reportedBy.append(currentUserID)
                    }
                    thread.reportedBy = reportedBy
                }
                self.screenState.isReported = true
                PPHUD.showSuccess(self.ppLocalized("chat.report.success"))
            }
        }
    }

    private func presentParticipantStories() {
        guard !isOpeningParticipantStories,
              presentedViewController == nil,
              viewIfLoaded?.window != nil,
              let thread = chatThread else { return }

        let user = ChatThreadModel.resolveOtherUser(fromThread: thread) ?? thread.otherUser
        let targetUserID = user?.id ?? ""
        guard !targetUserID.isEmpty else {
            PPHUD.showInfo(ppLocalized("story_unavailable"))
            return
        }

        isOpeningParticipantStories = true
        PPHUD.showLoading(ppLocalized("story_loading"))
        PPStoriesManager.shared().fetchStories(forUserID: targetUserID) { [weak self] stories, error in
            self?.onMain {
                guard let self else { return }
                self.isOpeningParticipantStories = false
                PPHUD.dismiss()

                if error != nil {
                    PPHUD.showInfo(self.ppLocalized("story_load_failed"))
                    return
                }
                guard !stories.isEmpty,
                      let firstStory = stories.first,
                      !firstStory.items.isEmpty else {
                    PPHUD.showInfo(self.ppLocalized("story_no_items"))
                    return
                }

                guard let player = PPStoryPlayerViewController(
                    stories: stories,
                    start: 0
                ) else {
                    PPHUD.showInfo(self.ppLocalized("story_unavailable"))
                    return
                }
                player.modalPresentationStyle = .fullScreen
                self.present(player, animated: true)
            }
        }
    }

    private func ppLocalized(_ key: String) -> String {
        Language.get(key, alter: key) ?? NSLocalizedString(key, comment: "")
    }

    private func messagePayload(
        from message: ChatMessageModel,
        currentUserID: String
    ) -> [String: Any] {
        let kind: String
        if message.isImageMessage {
            kind = "image"
        } else if message.isVideoMessage {
            kind = "video"
        } else if message.isAudioMessage {
            kind = "audio"
        } else if message.isFileMessage {
            kind = "file"
        } else if message.isStickerMessage {
            kind = "sticker"
        } else {
            kind = "text"
        }

        var fileURL = message.fileURL ?? ""
        if fileURL.isEmpty, let localVideoURL = message.localVideoURL {
            fileURL = localVideoURL.absoluteString
        }

        var payload: [String: Any] = [
            "id": message.id,
            "text": message.text,
            "senderID": message.senderID,
            "timestamp": message.timestamp,
            "kind": kind,
            "status": Int(message.status.rawValue),
            "fileURL": fileURL,
            "stickerStoragePath": message.stickerStoragePath ?? "",
            "thumbnailURL": message.thumbnailURL ?? "",
            "duration": message.mediaDuration,
            "mediaWidth": message.mediaWidth,
            "mediaHeight": message.mediaHeight,
            "waveformSamples": message.waveformSamples,
            "isUploading": message.isUploading,
            "isLocalPending": message.isLocalPending,
            "transferProgress": message.transferProgress,
            "isDeleted": message.isDeleted,
            "isOutgoing": message.senderID == currentUserID,
            "canUnsend": PPMessagingSwiftUIHostController.canUnsend(
                message: message,
                currentUserID: currentUserID,
                now: Date()
            )
        ]

        if let replyToMessageID = message.replyToMessageID {
            payload["replyToMessageID"] = replyToMessageID
        }
        let localImage: UIImage? = message.localImage
        if let localImage {
            payload["localImage"] = localImage
        }
        let thumbnailImage: UIImage? = message.thumbnailImage
        if let thumbnailImage {
            payload["thumbnailImage"] = thumbnailImage
        }
        return payload
    }

    private static func canUnsend(
        message: ChatMessageModel,
        currentUserID: String,
        now: Date
    ) -> Bool {
        guard !message.isDeleted,
              !currentUserID.isEmpty,
              message.senderID == currentUserID else {
            return false
        }

        let age = now.timeIntervalSince(message.timestamp)
        return age <= PPMessagingUnsendPolicy.window &&
            age >= -PPMessagingUnsendPolicy.clockSkewTolerance
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
        let replyToMessageID = screenState.composerReplyMessageID
        message.replyToMessageID = replyToMessageID

        screenState.appendOptimisticText(
            messageID: message.id,
            text: text,
            senderID: senderID,
            replyToMessageID: replyToMessageID
        )
        screenState.clearReplyComposer()

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

    private func sendStickerThroughExistingPipeline(_ sticker: PPChatSticker) {
        guard let thread = chatThread,
              !thread.id.isEmpty else {
            return
        }

        let downloadURLString = sticker.downloadURLString
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !downloadURLString.isEmpty,
              URL(string: downloadURLString) != nil else {
            NSLog("[Chat] Refusing sticker without a valid download URL")
            return
        }

        let threadID = thread.id
        let senderID = UserManager.shared().currentUser?.id ?? ""
        let receiverID = Self.outgoingReceiverID(for: thread, senderID: senderID)
        guard !senderID.isEmpty,
              !receiverID.isEmpty,
              senderID != receiverID else {
            NSLog("[Chat] Refusing sticker without a valid sender/receiver identity")
            return
        }

        let message = ChatMessageModel()
        message.id = UUID().uuidString
        message.text = ""
        message.senderID = senderID
        message.receiverID = receiverID
        message.timestamp = Date()
        message.messageType = .sticker
        message.fileURL = downloadURLString
        message.stickerStoragePath = sticker.storagePath
        message.mimeType = "image/png"
        message.mediaWidth = 1.0
        let replyToMessageID = screenState.composerReplyMessageID
        message.replyToMessageID = replyToMessageID

        screenState.appendOptimisticSticker(
            messageID: message.id,
            sticker: sticker,
            senderID: senderID,
            replyToMessageID: replyToMessageID
        )
        screenState.clearReplyComposer()

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

    private func sendAudioThroughExistingPipeline(url: URL, duration: Double) {
        guard let thread = chatThread, !thread.id.isEmpty else { return }
        let threadID = thread.id
        let senderID = UserManager.shared().currentUser?.id ?? ""
        let receiverID = Self.outgoingReceiverID(for: thread, senderID: senderID)
        guard !senderID.isEmpty, !receiverID.isEmpty, senderID != receiverID else {
            NSLog("[Chat] Refusing outgoing audio message without a valid sender/receiver identity")
            return
        }

        guard let audioData = try? Data(contentsOf: url) else {
            NSLog("[Chat] Failed to read audio data from URL: \(url)")
            return
        }

        let messageID = UUID().uuidString
        let replyToMessageID = screenState.composerReplyMessageID

        screenState.appendOptimisticAudio(
            messageID: messageID,
            duration: duration,
            senderID: senderID,
            replyToMessageID: replyToMessageID
        )
        screenState.clearReplyComposer()

        AppManager.sharedInstance().uploadAudioData(audioData) { [weak self] (downloadURL: String?, error: Error?) in
            guard let self = self else { return }
            self.onMain {
                if error != nil || downloadURL == nil {
                    self.screenState.setFailure(
                        messageID: messageID,
                        message: self.ppLocalized("chat_message_failed_title")
                    )
                    return
                }

                let message = ChatMessageModel()
                message.id = messageID
                message.text = ""
                message.senderID = senderID
                message.receiverID = receiverID
                message.timestamp = Date()
                message.messageType = .audio
                message.fileURL = downloadURL
                message.mediaDuration = duration
                message.mimeType = "audio/m4a"
                message.replyToMessageID = replyToMessageID

                ChManager.shared().sendMessage(
                    message,
                    inThread: threadID,
                    senderID: senderID
                ) { [weak self] sendError in
                    guard let self = self else { return }
                    self.onMain {
                        if sendError != nil {
                            self.screenState.setFailure(
                                messageID: messageID,
                                message: self.ppLocalized("chat_message_failed_title")
                            )
                        } else {
                            self.screenState.markMessageSent(messageID: messageID)
                        }
                    }
                }
            }
        }
    }

    private func sendImageThroughExistingPipeline(_ image: UIImage) {
        guard let thread = chatThread, !thread.id.isEmpty else { return }
        let threadID = thread.id
        let senderID = UserManager.shared().currentUser?.id ?? ""
        let receiverID = Self.outgoingReceiverID(for: thread, senderID: senderID)
        guard !senderID.isEmpty, !receiverID.isEmpty, senderID != receiverID else {
            NSLog("[Chat] Refusing outgoing image message without a valid sender/receiver identity")
            return
        }

        let message = ChatMessageModel()
        message.id = UUID().uuidString
        message.text = ""
        message.senderID = senderID
        message.receiverID = receiverID
        message.timestamp = Date()
        message.messageType = .image
        message.localImage = image
        message.mediaWidth = image.size.width
        message.mediaHeight = image.size.height
        let replyToMessageID = screenState.composerReplyMessageID
        message.replyToMessageID = replyToMessageID

        screenState.appendOptimisticImage(
            messageID: message.id,
            image: image,
            senderID: senderID,
            replyToMessageID: replyToMessageID
        )
        screenState.clearReplyComposer()

        ChManager.shared().sendImageMessage(
            image,
            message: message,
            inThread: threadID,
            progress: { _ in }
        ) { [weak self] error in
            guard let self = self else { return }
            self.onMain {
                if error != nil {
                    self.screenState.setFailure(
                        messageID: message.id,
                        message: self.ppLocalized("chat_message_failed_title")
                    )
                } else {
                    self.screenState.markMessageSent(messageID: message.id)
                }
            }
        }
    }

    private func sendVideoThroughExistingPipeline(_ videoURL: URL) {
        guard let thread = chatThread, !thread.id.isEmpty else { return }
        let threadID = thread.id
        let senderID = UserManager.shared().currentUser?.id ?? ""
        let receiverID = Self.outgoingReceiverID(for: thread, senderID: senderID)
        guard !senderID.isEmpty, !receiverID.isEmpty, senderID != receiverID else {
            NSLog("[Chat] Refusing outgoing video message without a valid sender/receiver identity")
            return
        }

        let message = ChatMessageModel()
        message.id = UUID().uuidString
        message.text = ""
        message.senderID = senderID
        message.receiverID = receiverID
        message.timestamp = Date()
        message.messageType = .video
        message.localVideoURL = videoURL
        let replyToMessageID = screenState.composerReplyMessageID
        message.replyToMessageID = replyToMessageID

        screenState.appendOptimisticVideo(
            messageID: message.id,
            videoURL: videoURL,
            senderID: senderID,
            replyToMessageID: replyToMessageID
        )
        screenState.clearReplyComposer()

        ChManager.shared().sendVideoMessage(
            videoURL,
            message: message,
            inThread: threadID
        ) { [weak self] error in
            guard let self = self else { return }
            self.onMain {
                if error != nil {
                    self.screenState.setFailure(
                        messageID: message.id,
                        message: self.ppLocalized("chat_message_failed_title")
                    )
                } else {
                    self.screenState.markMessageSent(messageID: message.id)
                }
            }
        }
    }

    private func presentImagePicker() {
        onMain { [weak self] in
            guard let self = self else { return }
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.sourceType = .photoLibrary
            picker.mediaTypes = ["public.image"]
            self.present(picker, animated: true)
        }
    }

    private func presentVideoPicker() {
        onMain { [weak self] in
            guard let self = self else { return }
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.sourceType = .photoLibrary
            picker.mediaTypes = ["public.movie"]
            self.present(picker, animated: true)
        }
    }

    public func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true)
        if let image = info[.originalImage] as? UIImage {
            sendImageThroughExistingPipeline(image)
        } else if let videoURL = info[.mediaURL] as? URL {
            sendVideoThroughExistingPipeline(videoURL)
        }
    }

    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
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
            self?.screenState.setReplyPreview(title: title, subtitle: subtitle)
        }
    }

    @objc public func clearReplyPreview() {
        onMain { [weak self] in
            self?.screenState.clearReplyComposer()
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
    @Published var participantID = ""
    @Published var participantVerified = false
    @Published var participantRestricted = false
    @Published var participantPlan = ""
    @Published var providerRatingValue = 0.0
    @Published var providerReviewCount = 0
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
    @Published var contextType = ""
    @Published var contextID = ""
    @Published var contextSnapshot: NSDictionary = [:]
    @Published var bottomNavigationClearance: CGFloat = 0
    @Published var backgroundImage: UIImage?
    @Published private(set) var keyboardIsPresented = false
    @Published private(set) var keyboardExpansionRevision = 0
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
    private(set) var composerReplyMessageID: String?

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

    func markMessageUnsent(messageID: String) {
        failedMessages.removeValue(forKey: messageID)
        messages = messages.map {
            guard $0.id == messageID else { return $0 }
            return $0.withUnsent()
        }
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
        participantID = ""
        participantVerified = false
        participantRestricted = false
        participantPlan = ""
        providerRatingValue = 0
        providerReviewCount = 0
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
        contextType = ""
        contextID = ""
        contextSnapshot = [:]
        if !didResolveUnreadBoundary {
            requestedInitialUnreadCount = max(0, unreadCount)
            resolveUnreadBoundaryIfNeeded()
        }
    }

    func configure(
        thread: ChatThreadModel,
        isModal: Bool,
        petAdContext: PetAd? = nil
    ) {
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
        participantID = user?.id ?? ""
        participantVerified = user?.isVerified ?? false
        participantRestricted =
            (user?.isEffectivelyBlocked ?? false) ||
            (user?.isChatEffectivelyBlocked ?? false)
        participantPlan = user?.subscriptionPlan ?? ""
        providerRatingValue = user?.providerRatingValue ?? 0
        providerReviewCount = max(0, user?.providerReviewCount ?? 0)
        if let petAdContext,
           !petAdContext.adID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            contextType = "pet_ad"
            contextID = petAdContext.adID
            contextSnapshot = Self.presentationSnapshot(for: petAdContext)
        } else {
            contextType = thread.contextType
            contextID = thread.contextId
            contextSnapshot = (thread.contextSnapshot as? NSDictionary) ?? [:]
        }
    }

    private static func presentationSnapshot(for ad: PetAd) -> NSDictionary {
        let trimmedTitle = ad.adTitle?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let title = trimmedTitle.isEmpty
            ? NSLocalizedString("pet_ad_viewer_title_fallback", comment: "")
            : trimmedTitle
        let price = PPPetAdViewerLegacyBridge.formattedPrice(for: ad)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let location = PPPetAdViewerLegacyBridge.locationName(for: ad)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let availability = NSLocalizedString(
            ad.isSold ? "Sold" : "Available",
            comment: ""
        )
        let detail = [price, availability, location]
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { values, value in
                if !values.contains(value) { values.append(value) }
            }
            .joined(separator: " · ")
        let thumbnailURLString = PPPetAdMediaItem.items(from: ad)
            .compactMap(\.imageURL)
            .first ?? ""

        return [
            "title": title,
            "detail": detail,
            "priceText": price,
            "availabilityText": availability,
            "thumbnailURLString": thumbnailURLString
        ]
    }

    func message(withID messageID: String) -> PPMessagingMessageSnapshot? {
        messages.first { $0.id == messageID }
    }

    func beginReply(to message: PPMessagingMessageSnapshot) {
        composerReplyMessageID = message.id

        let senderName = message.isOutgoing
            ? NSLocalizedString("chat_reply_sender_you", comment: "")
            : (conversationName.isEmpty
                ? NSLocalizedString("Chat", comment: "")
                : conversationName)
        composerState.replyTitle = String(
            format: NSLocalizedString("chat_replying_to_format", comment: ""),
            senderName
        )
        composerState.replySubtitle = replyPreviewText(for: message)
        composerState.isFocusedTrigger = true
    }

    func setReplyPreview(title: String, subtitle: String) {
        composerReplyMessageID = nil
        composerState.replyTitle = title
        composerState.replySubtitle = subtitle
    }

    func clearReplyComposer() {
        composerReplyMessageID = nil
        composerState.replyTitle = ""
        composerState.replySubtitle = ""
        composerState.isFocusedTrigger = false
    }

    func appendOptimisticText(
        messageID: String,
        text: String,
        senderID: String,
        replyToMessageID: String?
    ) {
        guard !messages.contains(where: { $0.id == messageID }) else { return }

        var payload: [String: Any] = [
            "id": messageID,
            "text": text,
            "senderID": senderID,
            "timestamp": Date(),
            "kind": "text",
            "status": 0,
            "isLocalPending": true,
            "isOutgoing": true
        ]
        if let replyToMessageID {
            payload["replyToMessageID"] = replyToMessageID
        }

        let snapshot = PPMessagingMessageSnapshot(
            payload: payload,
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

    func appendOptimisticSticker(
        messageID: String,
        sticker: PPChatSticker,
        senderID: String,
        replyToMessageID: String?
    ) {
        guard !messages.contains(where: { $0.id == messageID }) else { return }

        var payload: [String: Any] = [
            "id": messageID,
            "text": "",
            "senderID": senderID,
            "timestamp": Date(),
            "kind": "sticker",
            "status": 0,
            "fileURL": sticker.downloadURLString,
            "isLocalPending": true,
            "isOutgoing": true
        ]
        if let replyToMessageID {
            payload["replyToMessageID"] = replyToMessageID
        }

        let snapshot = PPMessagingMessageSnapshot(
            payload: payload,
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

    func appendOptimisticImage(
        messageID: String,
        image: UIImage,
        senderID: String,
        replyToMessageID: String?
    ) {
        guard !messages.contains(where: { $0.id == messageID }) else { return }

        var payload: [String: Any] = [
            "id": messageID,
            "text": "",
            "senderID": senderID,
            "timestamp": Date(),
            "kind": "image",
            "status": 0,
            "localImage": image,
            "mediaWidth": Double(image.size.width),
            "mediaHeight": Double(image.size.height),
            "isLocalPending": true,
            "isOutgoing": true
        ]
        if let replyToMessageID {
            payload["replyToMessageID"] = replyToMessageID
        }

        let snapshot = PPMessagingMessageSnapshot(
            payload: payload,
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

    func appendOptimisticVideo(
        messageID: String,
        videoURL: URL,
        senderID: String,
        replyToMessageID: String?
    ) {
        guard !messages.contains(where: { $0.id == messageID }) else { return }

        var payload: [String: Any] = [
            "id": messageID,
            "text": "",
            "senderID": senderID,
            "timestamp": Date(),
            "kind": "video",
            "status": 0,
            "localVideoURL": videoURL,
            "isLocalPending": true,
            "isOutgoing": true
        ]
        if let replyToMessageID {
            payload["replyToMessageID"] = replyToMessageID
        }

        let snapshot = PPMessagingMessageSnapshot(
            payload: payload,
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

    func appendOptimisticAudio(
        messageID: String,
        duration: Double,
        senderID: String,
        replyToMessageID: String?
    ) {
        guard !messages.contains(where: { $0.id == messageID }) else { return }

        var payload: [String: Any] = [
            "id": messageID,
            "text": "",
            "senderID": senderID,
            "timestamp": Date(),
            "kind": "audio",
            "status": 0,
            "duration": duration,
            "mediaDuration": duration,
            "isLocalPending": true,
            "isOutgoing": true
        ]
        if let replyToMessageID {
            payload["replyToMessageID"] = replyToMessageID
        }

        let snapshot = PPMessagingMessageSnapshot(
            payload: payload,
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

    func noteKeyboardExpansion() {
        keyboardExpansionRevision &+= 1
    }

    func setKeyboardPresented(_ presented: Bool) {
        guard keyboardIsPresented != presented else { return }
        keyboardIsPresented = presented
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

    private func replyPreviewText(for message: PPMessagingMessageSnapshot) -> String {
        if message.isDeleted {
            return NSLocalizedString("chat_message_unsent", comment: "")
        }

        switch message.kind {
        case "image":
            return NSLocalizedString("chat_reply_image", comment: "")
        case "video":
            return NSLocalizedString("chat_reply_video", comment: "")
        case "audio":
            return NSLocalizedString("chat_reply_audio", comment: "")
        case "sticker":
            return NSLocalizedString("chat_reply_sticker", comment: "")
        case "text":
            let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty
                ? NSLocalizedString("chat_reply_unavailable", comment: "")
                : String(text.prefix(240))
        default:
            return NSLocalizedString("chat_reply_unavailable", comment: "")
        }
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
        isLocalPending: Bool? = nil,
        unsent: Bool = false
    ) {
        id = source.id
        text = unsent ? "" : source.text
        senderID = source.senderID
        timestamp = source.timestamp
        kind = unsent ? "text" : source.kind
        self.status = status ?? source.status
        fileURLString = unsent ? "" : source.fileURLString
        thumbnailURLString = unsent ? "" : source.thumbnailURLString
        localImage = unsent ? nil : source.localImage
        thumbnailImage = unsent ? nil : source.thumbnailImage
        duration = unsent ? 0 : source.duration
        mediaWidth = unsent ? 0 : source.mediaWidth
        mediaHeight = unsent ? 0 : source.mediaHeight
        waveformSamples = unsent ? [] : source.waveformSamples
        isUploading = unsent ? false : source.isUploading
        self.isLocalPending = unsent ? false : (isLocalPending ?? source.isLocalPending)
        transferProgress = unsent ? 0 : source.transferProgress
        isDeleted = unsent || source.isDeleted
        replyToMessageID = unsent ? nil : source.replyToMessageID
        isOutgoing = source.isOutgoing
        canUnsend = unsent ? false : source.canUnsend
        self.failureText = unsent ? nil : failureText
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

    func withUnsent() -> Self {
        Self(
            copying: self,
            failureText: nil,
            unsent: true
        )
    }

    func isUnsendEligible(at now: Date) -> Bool {
        guard canUnsend, isOutgoing, !isDeleted else { return false }
        let age = now.timeIntervalSince(timestamp)
        return age <= PPMessagingUnsendPolicy.window &&
            age >= -PPMessagingUnsendPolicy.clockSkewTolerance
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
    var onSendAudio: ((URL, Double) -> Void)?
    var onCameraTap: (() -> Void)?
    var onVideoTap: (() -> Void)?
    var onContactTap: (() -> Void)?
    var onStickerSelected: ((PPChatSticker) -> Void)?
    var onContextRequested: ((String?) -> Void)?
    var onActionRequested: ((PPMessagingAction, String?) -> Void)?

    func sendText(_ text: String) {
        if let delegate {
            delegate.messagingHostDidSendText(text)
        } else {
            onSendText?(text)
        }
    }

    func sendAudio(url: URL, duration: Double) {
        if let delegate {
            delegate.messagingHostDidSendAudio(url, duration: duration)
        } else {
            onSendAudio?(url, duration)
        }
    }

    func tapCamera() {
        if let delegate {
            delegate.messagingHostDidTapPhoto()
        } else {
            onCameraTap?()
        }
    }

    func tapVideo() {
        if let delegate {
            delegate.messagingHostDidTapVideo()
        } else {
            onVideoTap?()
        }
    }

    func tapContact() {
        if let delegate {
            delegate.messagingHostDidTapContact()
        } else {
            onContactTap?()
        }
    }

    func selectSticker(_ sticker: PPChatSticker) {
        if let delegate {
            delegate.messagingHostDidSelectSticker(sticker)
        } else {
            onStickerSelected?(sticker)
        }
    }

    func request(_ action: PPMessagingAction, messageID: String? = nil) {
        if action == .context {
            onContextRequested?(messageID)
            return
        }
        if let delegate {
            delegate.messagingHostDidRequestAction(action.rawValue, messageID: messageID)
        } else {
            onActionRequested?(action, messageID)
        }
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

private enum PPMessagingUnsendPolicy {
    static let window: TimeInterval = 15 * 60
    static let clockSkewTolerance: TimeInterval = 5 * 60
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

// MARK: - Conversation Actions Sheet

private struct PPMessagingConversationActionsSheet: View {
    let title: String
    let conversationName: String
    let isPinned: Bool
    let isMuted: Bool
    let isBinned: Bool
    let isReported: Bool
    let onPin: (() -> Void)?
    let onMute: () -> Void
    let onBackground: (() -> Void)?
    let onReport: (() -> Void)?
    let onBin: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            PPMessagingPalette.canvas

            if allowsAmbientDetail {
                RadialGradient(
                    colors: [PPMessagingPalette.canvasWarmField, .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 310
                )

                RadialGradient(
                    colors: [PPMessagingPalette.canvasSignalField, .clear],
                    center: .bottomLeading,
                    startRadius: 20,
                    endRadius: 360
                )
            }

            VStack(spacing: 0) {
                Capsule(style: .continuous)
                    .fill(PPMessagingPalette.secondaryText.opacity(0.24))
                    .frame(width: 36, height: 5)
                    .padding(.top, 9)
                    .padding(.bottom, 12)
                    .accessibilityHidden(true)

                sheetHeader

                ScrollView {
                    VStack(spacing: 16) {
                        settingsGroup
                        safetyGroup
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
            }
        }
        .presentationBackground(.clear)
        .accessibilityIdentifier("pp.messaging.conversation-actions")
    }

    private var allowsAmbientDetail: Bool {
        !reduceTransparency && colorSchemeContrast == .standard
    }

    private var sheetHeader: some View {
        HStack(spacing: 14) {
            identityMark

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Font.ppBeirutiBold(size: 23, relativeTo: .title2))
                    .foregroundStyle(PPMessagingPalette.primaryText)

                if !conversationName.isEmpty {
                    Text(conversationName)
                        .font(Font.ppBeirutiRegular(size: 13.5, relativeTo: .subheadline))
                        .foregroundStyle(PPMessagingPalette.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 10)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(PPMessagingPalette.primaryText)
                    .frame(width: 44, height: 44)
                    .background(PPMessagingPalette.controlSurface, in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(PPMessagingPalette.controlStroke, lineWidth: 0.8)
                    }
            }
            .buttonStyle(PPMessagingPressButtonStyle())
            .accessibilityLabel(localized("Close"))
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 5)
    }

    private var identityMark: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            PPMessagingPalette.highlight.opacity(0.20),
                            PPMessagingPalette.controlSurface
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .strokeBorder(PPMessagingPalette.highlight.opacity(0.24), lineWidth: 0.8)

            Text(conversationInitials)
                .font(Font.ppBeirutiBold(size: 16, relativeTo: .headline))
                .foregroundStyle(PPMessagingPalette.primaryText)
        }
        .frame(width: 48, height: 48)
        .shadow(
            color: PPMessagingPalette.shadow.opacity(colorScheme == .dark ? 0.34 : 0.14),
            radius: 7,
            y: 3
        )
        .accessibilityHidden(true)
    }

    private var settingsGroup: some View {
        actionGroup {
            actionRow(
                title: localized("chat.pin"),
                systemName: "pin.fill",
                disabledSystemName: isPinned ? "checkmark" : "lock.fill",
                showsUnavailableReason: !isPinned,
                accessibilityValue: isPinned
                    ? localized("chat.action.completed")
                    : nil,
                action: isPinned ? nil : onPin
            )

            groupDivider

            actionRow(
                title: localized(isMuted ? "chat.unmute" : "chat.mute"),
                systemName: isMuted ? "bell.fill" : "bell.slash.fill",
                action: onMute
            )

            groupDivider

            actionRow(
                title: localized("chat.background"),
                systemName: "photo.on.rectangle.angled",
                action: onBackground
            )
        }
    }

    private var safetyGroup: some View {
        actionGroup {
            actionRow(
                title: localized(isReported ? "chat.reported" : "chat.report"),
                systemName: isReported ? "checkmark.shield.fill" : "exclamationmark.bubble.fill",
                disabledSystemName: isReported ? "checkmark" : "lock.fill",
                showsUnavailableReason: !isReported,
                accessibilityValue: isReported
                    ? localized("chat.action.completed")
                    : nil,
                action: onReport
            )

            groupDivider

            actionRow(
                title: localized(isBinned ? "chat.unbin" : "chat.bin"),
                systemName: isBinned ? "tray.and.arrow.up.fill" : "archivebox.fill",
                role: .destructive,
                action: onBin
            )
        }
    }

    private func actionGroup<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0, content: content)
            .padding(4)
            .background(
                PPMessagingPalette.sheetSurface,
                in: RoundedRectangle(cornerRadius: 25, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .strokeBorder(PPMessagingPalette.controlStroke, lineWidth: 0.8)
            }
            .shadow(
                color: PPMessagingPalette.shadow.opacity(colorScheme == .dark ? 0.30 : 0.11),
                radius: 14,
                y: 7
            )
    }

    private var groupDivider: some View {
        Rectangle()
            .fill(PPMessagingPalette.hairline)
            .frame(height: 0.5)
            .padding(.leading, 66)
            .accessibilityHidden(true)
    }

    private func actionRow(
        title: String,
        systemName: String,
        role: ButtonRole? = nil,
        disabledSystemName: String = "lock.fill",
        showsUnavailableReason: Bool = true,
        accessibilityValue: String? = nil,
        action: (() -> Void)?
    ) -> some View {
        let isEnabled = action != nil
        let tint = role == .destructive
            ? PPMessagingPalette.failure
            : PPMessagingPalette.highlight

        return Button(role: role) {
            guard let action else { return }
            dismiss()
            DispatchQueue.main.asyncAfter(
                deadline: .now() + (reduceMotion ? 0.05 : 0.22),
                execute: action
            )
        } label: {
            HStack(spacing: 13) {
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isEnabled ? tint : PPMessagingPalette.secondaryText)
                    .frame(width: 42, height: 42)
                    .background(
                        tint.opacity(isEnabled ? 0.10 : 0.035),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(tint.opacity(isEnabled ? 0.14 : 0.05), lineWidth: 0.7)
                    }
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(Font.ppBeirutiSemiBold(size: 16, relativeTo: .body))
                        .foregroundStyle(
                            role == .destructive && isEnabled
                                ? PPMessagingPalette.failure
                                : PPMessagingPalette.primaryText
                        )

                    if !isEnabled && showsUnavailableReason {
                        Text(localized("chat.action.unavailable"))
                            .font(Font.ppBeirutiRegular(size: 11.5, relativeTo: .caption))
                            .foregroundStyle(PPMessagingPalette.secondaryText)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isEnabled ? "chevron.forward" : disabledSystemName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(PPMessagingPalette.secondaryText)
                    .frame(width: 28, height: 28)
                    .background(PPMessagingPalette.controlSurface, in: Circle())
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(PPMessagingPressButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.62)
        .accessibilityHint(
            !isEnabled && showsUnavailableReason
                ? localized("chat.action.unavailable")
                : ""
        )
        .accessibilityValue(Text(accessibilityValue ?? ""))
    }

    private var conversationInitials: String {
        let value = conversationName
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
        return value.isEmpty ? "P" : value.uppercased()
    }

    private func localized(_ key: String) -> String {
        Language.get(key, alter: key) ?? NSLocalizedString(key, comment: "")
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
    @State private var activeReplyGestureMessageID: String?
    @State private var replyGestureOffset: CGFloat = 0
    @State private var replyGestureActivityToken = 0
    @State private var headerLayoutRevision = 0
    @State private var preservesLatestDuringHeaderLayout = false
    @State private var packageAudioCoordinator = ConversationAudioCoordinator()
    @State private var unsendEligibilityNow = Date()

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                PPMessagingHeader(
                    state: state,
                    relay: relay,
                    onExpansionChanged: handleHeaderExpansionChange
                )

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
                    onCameraTap: { relay.tapCamera() },
                    onVideoTap: { relay.tapVideo() },
                    onContactTap: { relay.tapContact() },
                    onStickerTap: { relay.selectSticker($0) },
                    onSendAudio: { url, duration in
                        relay.sendAudio(url: url, duration: duration)
                    },
                    onCancelReply: {
                        relay.request(.composerCancelledReply)
                    }
                )
                .accessibilityIdentifier("pp.messaging.composer")
                .onReceive(state.composerState.$message.dropFirst()) { text in
                    relay.delegate?.messagingHostDidChangeText(text)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(
                    .bottom,
                    state.keyboardIsPresented
                        ? 10
                        : max(18, state.bottomNavigationClearance)
                )
                .animation(reduceMotion ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: 0.22), value: state.keyboardIsPresented)
                .background {
                    PPMessagingComposerBackdrop()
                }
            }
            // Native SwiftUI safe-area layout owns the status bar. Only the
            // composer reaches the physical bottom; the keyboard safe area
            // remains authoritative when editing begins.
            .ignoresSafeArea(.container, edges: .bottom)
            .background {
                PPMessagingCanvas(backgroundImage: state.backgroundImage)
                    .ignoresSafeArea()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if state.keyboardIsPresented {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
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
        .onReceive(
            Timer.publish(every: 30, on: .main, in: .common).autoconnect()
        ) { now in
            unsendEligibilityNow = now
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

    private func handleHeaderExpansionChange(_: Bool) {
        guard hasPositionedInitially else { return }
        preservesLatestDuringHeaderLayout = isAtLatest
        guard preservesLatestDuringHeaderLayout else { return }
        headerLayoutRevision &+= 1
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
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(PPMessagingPalette.highlight)

                                Text(localized("chat_loading_older"))
                                    .font(Font.ppBeirutiMedium(size: 12, relativeTo: .caption))
                                    .foregroundStyle(PPMessagingPalette.secondaryText)
                            }
                            .padding(.horizontal, 12)
                            .frame(minHeight: 32)
                            .background(PPMessagingPalette.separatorSurface, in: Capsule())
                            .overlay {
                                Capsule()
                                    .strokeBorder(PPMessagingPalette.controlStroke, lineWidth: 0.6)
                            }
                            .padding(.vertical, 10)
                            .accessibilityElement(children: .combine)
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
                                    audioState: audioState(for: message),
                                    conversationName: state.conversationName
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
                                    onUpdateApp: openAppStore,
                                    canDelete: message.isUnsendEligible(at: unsendEligibilityNow),
                                    canForward: false
                                ),
                                animatesEntrance: message.animatesEntrance,
                                isHighlighted: highlightedMessageID == message.id,
                                replyOffset: activeReplyGestureMessageID == message.id
                                    ? replyGestureOffset
                                    : 0,
                                maximumBubbleWidth: maximumBubbleWidth(
                                    for: message,
                                    availableWidth: availableWidth
                                ),
                                contentLayoutDirection: layoutDirection
                            )
                            // Sender lanes are physical, not semantic: outgoing
                            // remains on the screen's right edge in both Arabic
                            // and English. Payload text receives the captured
                            // locale direction through SmartMessageCell.
                            .environment(\.layoutDirection, .leftToRight)
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
                                if hasPositionedInitially,
                                   !preservesLatestDuringHeaderLayout {
                                    isAtLatest = false
                                }
                            }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 16)
                }
                .accessibilityIdentifier("pp.messaging.messages")
                .ppInteractiveKeyboardDismissal()
                .simultaneousGesture(
                    DragGesture(minimumDistance: 6, coordinateSpace: .local)
                        .onChanged { value in
                            guard preservesLatestDuringHeaderLayout,
                                  abs(value.translation.height) >
                                    abs(value.translation.width) else { return }
                            preservesLatestDuringHeaderLayout = false
                            isAtLatest = false
                        }
                )
                .overlayPreferenceValue(
                    SmartMessageReplyRegionPreferenceKey.self
                ) { regions in
                    GeometryReader { geometry in
                        PPMessagingTranscriptReplyPanGesture(
                            targets: state.messages.compactMap { message in
                                let packageID = PPMessagingAdapter.messageID(
                                    from: message.id
                                )
                                guard let anchor = regions[packageID] else {
                                    return nil
                                }
                                return PPMessagingReplyPanTarget(
                                    messageID: message.id,
                                    isOutgoing: message.isOutgoing,
                                    frame: geometry[anchor]
                                )
                            },
                            axisBias: PPMessagingReplyGestureMetrics.axisBias,
                            onChanged: updateReplyGesture,
                            onEnded: { target, horizontal, vertical in
                                finishReplyGesture(
                                    target: target,
                                    horizontalDistance: horizontal,
                                    verticalDistance: vertical,
                                    proxy: proxy
                                )
                            },
                            onCancelled: cancelReplyGesture
                        )
                    }
                }
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
                .onChange(of: state.keyboardIsPresented) { presented in
                    guard presented else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        scrollToLatest(using: proxy, animated: !reduceMotion)
                    }
                }
                .onChange(of: state.keyboardExpansionRevision) { _ in
                    // The host publishes keyboard frame expansion. Scroll message list to bottom
                    // so the user's focus and latest messages follow the keyboard expansion.
                    guard hasPositionedInitially else { return }
                    DispatchQueue.main.async {
                        scrollToLatest(using: proxy, animated: !reduceMotion)
                    }
                }
                .onChange(of: headerLayoutRevision) { revision in
                    guard hasPositionedInitially,
                          preservesLatestDuringHeaderLayout else { return }

                    DispatchQueue.main.async {
                        guard headerLayoutRevision == revision,
                              preservesLatestDuringHeaderLayout else { return }
                        scrollToLatest(using: proxy, animated: false)
                    }
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + (reduceMotion ? 0.02 : 0.42)
                    ) {
                        guard headerLayoutRevision == revision,
                              preservesLatestDuringHeaderLayout else { return }
                        scrollToLatest(using: proxy, animated: false)
                        preservesLatestDuringHeaderLayout = false
                    }
                }
                .onAppear {
                    if state.initialLoadCompleted {
                        positionInitially(using: proxy)
                    }
                }
                .onDisappear {
                    cancelReplyGesture()
                }

                if !isAtLatest || unseenMessageCount > 0 {
                    PPMessagingLatestButton(count: unseenMessageCount) {
                        scrollToLatest(using: proxy, animated: true)
                    }
                    // Overlay-only placement keeps the button above the date
                    // and composer without changing message scroll insets.
                    .padding(.bottom, 18)
                    .zIndex(2)
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
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
            withAnimation(.timingCurve(0.23, 1, 0.32, 1, duration: 0.28), operation)
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
                withAnimation(.timingCurve(0.23, 1, 0.32, 1, duration: 0.28)) {
                    proxy.scrollTo(sourceID, anchor: .center)
                }
            }
            highlightedMessageID = sourceID
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                if highlightedMessageID == sourceID {
                    highlightedMessageID = nil
                }
            }
        }
    }

    private func openAppStore() {
        guard let appStoreURL = URL(
            string: "itms-apps://itunes.apple.com/app/id1594016239"
        ) else { return }
        UIApplication.shared.open(appStoreURL)
    }

    private func updateReplyGesture(
        _ target: PPMessagingReplyPanTarget,
        horizontalDistance: CGFloat,
        verticalDistance: CGFloat
    ) {
        replyGestureActivityToken &+= 1
        activeReplyGestureMessageID = target.messageID
        guard horizontalDistance >
                verticalDistance * PPMessagingReplyGestureMetrics.axisBias else {
            replyGestureOffset = 0
            return
        }

        replyGestureOffset = min(
            max(horizontalDistance, 0),
            PPMessagingReplyGestureMetrics.maximumOffset
        )
    }

    private func finishReplyGesture(
        target: PPMessagingReplyPanTarget,
        horizontalDistance: CGFloat,
        verticalDistance: CGFloat,
        proxy: ScrollViewProxy
    ) {
        let commitsReply =
            activeReplyGestureMessageID == target.messageID &&
            horizontalDistance >= PPMessagingReplyGestureMetrics.commitThreshold &&
            horizontalDistance >
                verticalDistance * PPMessagingReplyGestureMetrics.axisBias

        if commitsReply,
           let message = state.messages.first(where: { $0.id == target.messageID }) {
            handleMessageAction(.reply, message: message, proxy: proxy)
        }
        settleReplyGesture()
    }

    private func cancelReplyGesture() {
        settleReplyGesture()
    }

    private func settleReplyGesture() {
        replyGestureActivityToken &+= 1
        let settlementToken = replyGestureActivityToken
        let messageID = activeReplyGestureMessageID

        guard !reduceMotion else {
            replyGestureOffset = 0
            activeReplyGestureMessageID = nil
            return
        }

        withAnimation(
            .interactiveSpring(
                response: 0.25,
                dampingFraction: 0.88,
                blendDuration: 0.08
            )
        ) {
            replyGestureOffset = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            guard replyGestureActivityToken == settlementToken,
                  activeReplyGestureMessageID == messageID else { return }
            activeReplyGestureMessageID = nil
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
              groupingFamily(for: message) == groupingFamily(for: other),
              Calendar.current.isDate(message.timestamp, inSameDayAs: other.timestamp) else {
            return false
        }
        return abs(message.timestamp.timeIntervalSince(other.timestamp)) <= 5 * 60
    }

    private func rowSpacing(after index: Int) -> CGFloat {
        // Internal bubble padding carries readability; external spacing stays
        // compact so short conversational runs feel connected. Exposed group
        // edges retain enough separation to preserve sender and time changes.
        grouping(at: index) == .last || grouping(at: index) == .single ? 7 : 3
    }

    private func groupingFamily(
        for message: PPMessagingMessageSnapshot
    ) -> String {
        // A quote is a complete conversational thought, not a continuation of
        // the preceding short text run. Keeping it isolated also gives the
        // reply source and terminal delivery metadata a stable layout contract.
        if message.replyToMessageID != nil {
            return "reply:\(message.id)"
        }
        if message.isDeleted { return "text" }
        switch message.kind {
        case "image", "video":
            return "media"
        case "audio":
            return "voice"
        case "sticker":
            return "sticker"
        default:
            return "text"
        }
    }

    private func maximumBubbleWidth(
        for message: PPMessagingMessageSnapshot,
        availableWidth: CGFloat
    ) -> CGFloat {
        let transcriptWidth = max(availableWidth - 24, 220)
        if dynamicTypeSize.isAccessibilitySize {
            return min(max(transcriptWidth - 40, 232), 440)
        }

        switch message.kind {
        case "audio":
            return min(max(transcriptWidth * 0.70, 244), 272)
        case "image", "video":
            return min(max(transcriptWidth * 0.74, 238), 288)
        case "sticker":
            return min(max(transcriptWidth * 0.54, 194), 224)
        default:
            return min(max(transcriptWidth * 0.76, 214), 330)
        }
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

private enum PPMessagingReplyGestureMetrics {
    static let axisBias: CGFloat = 1.15
    static let commitThreshold: CGFloat = 56
    static let maximumOffset: CGFloat = 72
}

private struct PPMessagingReplyPanTarget {
    let messageID: String
    let isOutgoing: Bool
    let frame: CGRect
}

private struct PPMessagingTranscriptReplyPanGesture: UIViewRepresentable {
    let targets: [PPMessagingReplyPanTarget]
    let axisBias: CGFloat
    let onChanged: (PPMessagingReplyPanTarget, CGFloat, CGFloat) -> Void
    let onEnded: (PPMessagingReplyPanTarget, CGFloat, CGFloat) -> Void
    let onCancelled: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> AnchorView {
        let view = AnchorView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.coordinator = context.coordinator
        context.coordinator.anchorView = view
        return view
    }

    func updateUIView(_ uiView: AnchorView, context: Context) {
        context.coordinator.update(
            targets: targets,
            axisBias: axisBias,
            onChanged: onChanged,
            onEnded: onEnded,
            onCancelled: onCancelled
        )
        context.coordinator.attachIfNeeded(to: uiView.window)
    }

    static func dismantleUIView(_ uiView: AnchorView, coordinator: Coordinator) {
        uiView.coordinator = nil
        coordinator.detach()
    }

    final class AnchorView: UIView {
        weak var coordinator: Coordinator?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            coordinator?.attachIfNeeded(to: window)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var anchorView: AnchorView?
        private var targets: [PPMessagingReplyPanTarget] = []
        private var axisBias: CGFloat = PPMessagingReplyGestureMetrics.axisBias
        private var activeTarget: PPMessagingReplyPanTarget?
        private var onChanged: (
            (PPMessagingReplyPanTarget, CGFloat, CGFloat) -> Void
        )?
        private var onEnded: (
            (PPMessagingReplyPanTarget, CGFloat, CGFloat) -> Void
        )?
        private var onCancelled: (() -> Void)?

        private lazy var panGesture: UIPanGestureRecognizer = {
            let gesture = UIPanGestureRecognizer(
                target: self,
                action: #selector(handlePan(_:))
            )
            gesture.delegate = self
            gesture.maximumNumberOfTouches = 1
            gesture.cancelsTouchesInView = false
            return gesture
        }()

        func update(
            targets: [PPMessagingReplyPanTarget],
            axisBias: CGFloat,
            onChanged: @escaping (
                PPMessagingReplyPanTarget,
                CGFloat,
                CGFloat
            ) -> Void,
            onEnded: @escaping (
                PPMessagingReplyPanTarget,
                CGFloat,
                CGFloat
            ) -> Void,
            onCancelled: @escaping () -> Void
        ) {
            self.targets = targets
            self.axisBias = max(axisBias, 1)
            self.onChanged = onChanged
            self.onEnded = onEnded
            self.onCancelled = onCancelled

            if let activeTarget,
               !targets.contains(where: { $0.messageID == activeTarget.messageID }) {
                cancelActiveGesture()
            }
        }

        func attachIfNeeded(to window: UIWindow?) {
            guard panGesture.view !== window else { return }
            detach()
            guard let window else { return }
            window.addGestureRecognizer(panGesture)
        }

        func detach() {
            if activeTarget != nil {
                cancelActiveGesture()
            }
            panGesture.view?.removeGestureRecognizer(panGesture)
        }

        func gestureRecognizerShouldBegin(
            _ gestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            guard gestureRecognizer === panGesture,
                  let anchorView else { return false }
            let location = panGesture.location(in: anchorView)
            guard let target = targets.last(where: { $0.frame.contains(location) }) else {
                return false
            }

            let velocity = panGesture.velocity(in: anchorView)
            let directionalVelocity = target.isOutgoing ? -velocity.x : velocity.x
            guard directionalVelocity > 0,
                  abs(velocity.x) > abs(velocity.y) * axisBias else {
                return false
            }
            activeTarget = target
            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            guard gestureRecognizer === panGesture else { return false }
            return otherGestureRecognizer.view is UIScrollView
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let anchorView, let activeTarget else { return }
            let translation = gesture.translation(in: anchorView)
            let horizontalDistance = max(
                activeTarget.isOutgoing ? -translation.x : translation.x,
                0
            )
            let verticalDistance = abs(translation.y)

            switch gesture.state {
            case .began, .changed:
                guard horizontalDistance > verticalDistance * axisBias else {
                    cancelActiveGesture()
                    return
                }
                onChanged?(activeTarget, horizontalDistance, verticalDistance)
            case .ended:
                self.activeTarget = nil
                onEnded?(activeTarget, horizontalDistance, verticalDistance)
            case .cancelled, .failed:
                cancelActiveGesture()
            default:
                break
            }
        }

        private func cancelActiveGesture() {
            activeTarget = nil
            onCancelled?()
        }
    }
}

// MARK: - Header and Screen States

private struct PPMessagingHeader: View {
    @ObservedObject var state: PPMessagingScreenState
    let relay: PPMessagingActionRelay
    let onExpansionChanged: (Bool) -> Void

    var body: some View {
        SpearChatHeader(
            state: spearHeaderState,
            style: SpearChatHeaderStyle(
                brandColor: PPMessagingPalette.highlight,
                mainBackgroundColor: .ppBackground,
                cornerRadius: 22,
                horizontalPadding: 12
            ),
            copy: headerCopy,
            actions: spearActions,
            onExpansionChanged: onExpansionChanged,
            contextThumbnail: { url in
                AnyView(
                    PPMessagingRemoteImage(
                        localImage: nil,
                        url: url,
                        contentMode: .fill
                    )
                )
            }
        ) { _ in
            PPMessagingAvatar(
                name: state.conversationName,
                urlString: state.avatarURLString,
                isOnline: false,
                usesSupportLogo: state.usesSupportLogo
            )
        }
        .frame(minHeight: 62)
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
        } else if let lastActiveAt = state.lastActiveAt {
            presence = .offline(lastActiveAt: lastActiveAt)
        } else {
            presence = .unavailable
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
            id: state.participantID.isEmpty ? "legacy:\(name)" : state.participantID,
            name: name,
            avatarFallback: fallback,
            trust: trustState,
            presence: presence,
            metrics: reputationMetrics,
            context: headerContext,
            isModal: state.isModal
        )
        return .ready(model)
    }

    private var headerCopy: SpearChatHeaderCopy {
        SpearChatHeaderCopy(
            localeIdentifier: Language.isRTL() ? "ar_QA" : "en_QA",
            backAccessibilityLabel: localized("Back"),
            callButtonTitle: localized("Call"),
            startCallAccessibilityLabel: localized("chat_header_start_call_accessibility"),
            endCallAccessibilityLabel: localized("chat_header_end_call_accessibility"),
            moreButtonTitle: localized("more"),
            moreAccessibilityLabel: localized("chat_header_more_accessibility"),
            verifiedSellerAccessibilityLabel: localized("chat_header_verified_seller"),
            verifiedBusinessAccessibilityLabel: localized("chat_header_verified_business"),
            restrictedAccessibilityLabel: localized("chat_header_restricted_account"),
            profileButtonTitle: localized("chat_stories_title"),
            safetyButtonTitle: localized("chat.report"),
            loadingAccessibilityLabel: localized("chat_header_loading_identity"),
            conversationAccessibilityPrefix: localized("chat_header_conversation_with"),
            onlineNowText: localized("chat_header_online_now"),
            repliesFastText: localized("chat_header_replies_fast"),
            repliesTypicallyText: localized("chat_header_replies_typically"),
            typingText: localized("chat_header_typing"),
            viewingOfferText: localized("chat_header_viewing_offer"),
            lastSeenPrefix: localized("chat.last_seen"),
            secureCallText: localized("chat_header_secure_call"),
            expandAccessibilityHint: localized("chat_header_expand_hint"),
            collapseAccessibilityHint: localized("chat_header_collapse_hint"),
            expandedAccessibilityValue: localized("chat_header_expanded"),
            collapsedAccessibilityValue: localized("chat_header_collapsed"),
            unavailableText: localized("chat_header_activity_unavailable"),
            closeAccessibilityLabel: localized("Close")
        )
    }

    private var trustState: SpearTrustState {
        if state.participantRestricted {
            return .restricted(reason: headerCopy.restrictedAccessibilityLabel)
        }
        if state.usesSupportLogo {
            let name = state.supportDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
            return .verifiedBusiness(displayName: name.isEmpty ? localized("Support") : name)
        }
        let providerPlans = Set(["business", "production", "service_provider", "pro"])
        let isProvider = providerPlans.contains(state.participantPlan.lowercased())
            || state.providerReviewCount > 0
        if state.participantVerified && isProvider {
            return .verifiedSeller(
                role: headerCopy.verifiedSellerAccessibilityLabel,
                location: nil
            )
        }
        return .standard(role: nil)
    }

    private var reputationMetrics: [SpearIdentityMetric] {
        guard state.providerReviewCount > 0,
              state.providerRatingValue.isFinite,
              state.providerRatingValue > 0 else { return [] }
        let rating = min(max(state.providerRatingValue, 0), 5)
        return [
            .init(
                id: "rating",
                value: rating.formatted(.number.precision(.fractionLength(1))),
                label: localized("chat_header_rating")
            ),
            .init(
                id: "reviews",
                value: state.providerReviewCount.formatted(),
                label: localized("chat_header_reviews")
            )
        ]
    }

    private var headerContext: SpearConversationContext? {
        let contextID = state.contextID.trimmingCharacters(in: .whitespacesAndNewlines)
        let contextType = state.contextType
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if !contextID.isEmpty,
           ["listing", "pet_listing", "pet_ad"].contains(contextType) {
            let title = snapshotText("title", "displayTitle")
                ?? localized("pet_ad_viewer_title_fallback")
            let detail = snapshotText("detail", "subtitle")
                ?? [snapshotText("priceText"), snapshotText("availabilityText")]
                    .compactMap { $0 }
                    .joined(separator: " · ")
            return .listing(
                .init(
                    id: contextID,
                    eyebrow: localized("chat_header_listing_eyebrow"),
                    title: title,
                    detail: detail,
                    actionTitle: localized("chat_header_listing_action"),
                    thumbnailURL: snapshotText(
                        "thumbnailURLString",
                        "imageURLString",
                        "imageURL"
                    ).flatMap(URL.init(string:))
                )
            )
        }

        if !contextID.isEmpty, contextType == "order" {
            let number = snapshotText("orderNumber")
            let title = snapshotText("title")
                ?? number.map {
                    String(format: localized("chat_header_order_title_format"), $0)
                }
            guard let title else { return nil }
            return .order(
                .init(
                    id: contextID,
                    eyebrow: localized("chat_header_order_eyebrow"),
                    title: title,
                    detail: snapshotText("detail", "statusText") ?? "",
                    actionTitle: localized("chat_header_order_action"),
                    progress: snapshotDouble("progress")
                )
            )
        }

        return supportContext
    }

    private func snapshotText(_ keys: String...) -> String? {
        for key in keys {
            guard let raw = state.contextSnapshot[key] as? String else { continue }
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { return value }
        }
        return nil
    }

    private func snapshotDouble(_ key: String) -> Double? {
        guard let value = state.contextSnapshot[key] as? NSNumber else { return nil }
        let result = value.doubleValue
        return result.isFinite ? result : nil
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
        let contextAction: SpearContextHeaderAction = headerContext == nil
            ? .hidden
            : .enabled { context in
                relay.request(.context, messageID: context.backendID)
            }

        return SpearChatHeaderActions(
            onBack: { relay.request(.close) },
            more: .enabled { relay.request(.more) },
            profile: .enabled { relay.request(.profile) },
            safety: .enabled { relay.request(.report) },
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
            .frame(width: 46, height: 46)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                PPMessagingPalette.highlight.opacity(0.30),
                                PPMessagingPalette.avatarStroke,
                                Color.white.opacity(0.22)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: PPMessagingPalette.shadow.opacity(0.18),
                radius: 6,
                y: 3
            )

            if isOnline {
                Circle()
                    .fill(PPMessagingPalette.online)
                    .frame(width: 12, height: 12)
                    .overlay {
                        Circle()
                            .stroke(Color(PPMessagingPalette.canvasUIColor), lineWidth: 2.5)
                    }
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
            HStack(spacing: 10) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 12.5, weight: .bold))
                    .frame(width: 32, height: 32)
                    .background(PPMessagingPalette.warningSurface, in: Circle())
                    .accessibilityHidden(true)

                Text(localized("chat_connection_interrupted"))
                    .font(.custom("Beiruti-Medium", size: 13, relativeTo: .footnote))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(localized("KLang_Retry"))
                    .font(.custom("Beiruti-Bold", size: 12.5, relativeTo: .footnote))
                    .padding(.horizontal, 11)
                    .frame(minHeight: 32)
                    .background(PPMessagingPalette.warningSurface, in: Capsule())
            }
            .foregroundStyle(PPMessagingPalette.warningText)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(PPMessagingPalette.canvas.opacity(0.94))
            .contentShape(Rectangle())
        }
        .buttonStyle(PPMessagingPressButtonStyle())
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PPMessagingPalette.warningText.opacity(0.12))
                .frame(height: 0.5)
        }
        .accessibilityHint(localized("offline_action_message"))
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private struct PPMessagingStateMark: View {
    let systemName: String
    let accent: Color

    @ScaledMetric(relativeTo: .title) private var markSize = 112

    var body: some View {
        let size = min(markSize, 138)

        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [accent.opacity(0.18), accent.opacity(0.035), .clear],
                        center: .center,
                        startRadius: 4,
                        endRadius: size * 0.58
                    )
                )

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(PPMessagingPalette.sheetSurface)
                .frame(width: size * 0.48, height: size * 0.34)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(PPMessagingPalette.controlStroke, lineWidth: 0.7)
                }
                .offset(x: -size * 0.16, y: -size * 0.10)

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.88), accent.opacity(0.60)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.42, height: size * 0.30)
                .offset(x: size * 0.17, y: size * 0.14)

            Image(systemName: systemName)
                .font(.system(size: size * 0.23, weight: .semibold))
                .foregroundStyle(PPMessagingPalette.primaryText)
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: size, height: size)
        .shadow(
            color: PPMessagingPalette.shadow.opacity(0.12),
            radius: 10,
            y: 5
        )
        .accessibilityHidden(true)
    }
}

private struct PPMessagingLoadingState: View {
    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    PPMessagingStateMark(
                        systemName: "ellipsis.message.fill",
                        accent: PPMessagingPalette.highlight
                    )

                    VStack(spacing: 7) {
                        Text(localized("chat_loading_messages_title"))
                            .font(.custom("Beiruti-Bold", size: 21, relativeTo: .title3))
                            .foregroundStyle(PPMessagingPalette.primaryText)

                        Text(localized("chat_loading_messages_subtitle"))
                            .font(.custom("Beiruti-Regular", size: 14.5, relativeTo: .subheadline))
                            .foregroundStyle(PPMessagingPalette.secondaryText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ProgressView()
                        .tint(PPMessagingPalette.highlight)
                        .controlSize(.small)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 30)
                .frame(maxWidth: 430)
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height)
                .accessibilityElement(children: .combine)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private struct PPMessagingEmptyState: View {
    let focusComposer: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var content: some View {
        VStack(spacing: 24) {
            PPMessagingStateMark(
                systemName: "pawprint.fill",
                accent: PPMessagingPalette.highlight
            )

            VStack(spacing: 8) {
                Text(localized("chat_empty_thread_title"))
                    .font(.custom("Beiruti-Bold", size: 24, relativeTo: .title2))
                    .foregroundStyle(PPMessagingPalette.primaryText)
                    .multilineTextAlignment(.center)

                Text(localized("chat_empty_thread_subtitle"))
                    .font(.custom("Beiruti-Regular", size: 15.5, relativeTo: .body))
                    .foregroundStyle(PPMessagingPalette.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: focusComposer) {
                Label(
                    localized("chat_empty_thread_action"),
                    systemImage: "square.and.pencil"
                )
                .font(.custom("Beiruti-Bold", size: 15, relativeTo: .body))
                .padding(.horizontal, 20)
                .frame(minHeight: 50)
                .background(
                    LinearGradient(
                        colors: [
                            PPMessagingPalette.highlight,
                            PurePetsMessagingTheme.brandDeep
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Capsule(style: .continuous)
                )
                .foregroundStyle(PurePetsMessagingTheme.signalForeground)
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
                }
                .shadow(
                    color: PPMessagingPalette.highlight.opacity(0.20),
                    radius: 10,
                    y: 5
                )
            }
            .buttonStyle(PPMessagingPressButtonStyle())
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 30)
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
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 22) {
                    PPMessagingStateMark(
                        systemName: "wifi.slash",
                        accent: PPMessagingPalette.warningText
                    )

                    VStack(spacing: 8) {
                        Text(localized("chat_offline_title"))
                            .font(.custom("Beiruti-Bold", size: 23, relativeTo: .title2))
                            .foregroundStyle(PPMessagingPalette.primaryText)

                        Text(localized("chat_offline_subtitle"))
                            .font(.custom("Beiruti-Regular", size: 15.5, relativeTo: .body))
                            .foregroundStyle(PPMessagingPalette.secondaryText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button(action: retry) {
                        Label(localized("KLang_Retry"), systemImage: "arrow.clockwise")
                            .font(.custom("Beiruti-Bold", size: 15, relativeTo: .body))
                            .padding(.horizontal, 20)
                            .frame(minHeight: 50)
                            .background(PPMessagingPalette.primaryText, in: Capsule())
                            .foregroundStyle(PPMessagingPalette.inverseText)
                    }
                    .buttonStyle(PPMessagingPressButtonStyle())
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 30)
                .frame(maxWidth: 430)
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height)
                .accessibilityElement(children: .contain)
            }
            .scrollIndicators(.hidden)
        }
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

    static func messageID(from rawID: String) -> MessageID {
        MessageID(deterministicUUID(from: rawID))
    }

    static func chatMessage(
        from snapshot: PPMessagingMessageSnapshot,
        groupPosition: MessageGroupPosition,
        replySource: PPMessagingMessageSnapshot?,
        audioState: PPMessagingAudioState,
        conversationName: String
    ) -> ChatMessage {
        let senderUUID = deterministicUUID(from: snapshot.senderID)
        let trimmedConversationName = conversationName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let displayName = snapshot.isOutgoing
            ? NSLocalizedString("chat_reply_sender_you", comment: "")
            : (trimmedConversationName.isEmpty
                ? NSLocalizedString("Chat", comment: "")
                : trimmedConversationName)
        let initials: String = {
            let parts = displayName.split(separator: " ").prefix(2)
            if parts.count >= 2 {
                return parts.compactMap(\.first).map(String.init).joined().uppercased()
            }
            return String(displayName.prefix(2)).uppercased()
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
                    case "sticker":
                        preview = .sticker(
                            description: NSLocalizedString("chat_reply_sticker", comment: "")
                        )
                    default: preview = .text(src.text)
                    }
                }
            } else {
                preview = .unsupported
            }
            return ReplyReference(
                messageID: MessageID(deterministicUUID(from: replyID)),
                senderDisplayName: replySource.map { source in
                    source.isOutgoing
                        ? NSLocalizedString("chat_reply_sender_you", comment: "")
                        : displayNameForIncomingReply(conversationName: conversationName)
                } ?? displayNameForIncomingReply(conversationName: conversationName),
                preview: preview
            )
        }()

        return ChatMessage(
            id: messageID(from: snapshot.id),
            sender: sender,
            direction: direction,
            payload: payload,
            replyReference: replyRef,
            reactions: [],
            sentAt: snapshot.timestamp,
            groupPosition: groupPosition
        )
    }

    private static func displayNameForIncomingReply(
        conversationName: String
    ) -> String {
        let trimmed = conversationName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? NSLocalizedString("Chat", comment: "") : trimmed
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
        HStack(spacing: 0) {
            HStack(spacing: 10) {
                PPMessagingTypingDots()

                Text(String(format: localized("chat_typing_format"), name))
                    .font(.custom("Beiruti-Medium", size: 12.5, relativeTo: .footnote))
                    .foregroundStyle(PPMessagingPalette.secondaryText)
                    .lineLimit(1)
            }
            .environment(\.layoutDirection, layoutDirection)
            .padding(.horizontal, 14)
            .frame(minHeight: 42)
            .background(
                LinearGradient(
                    colors: [
                        PPMessagingPalette.incomingBubble,
                        PPMessagingPalette.sheetSurface
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 17, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .strokeBorder(PPMessagingPalette.incomingStroke, lineWidth: 0.7)
            }
            .shadow(
                color: PPMessagingPalette.shadow.opacity(0.10),
                radius: 5,
                y: 2
            )

            Spacer()
        }
        .environment(\.layoutDirection, .leftToRight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private struct PPMessagingTypingDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var activeIndex = 0
    private let timer = Timer.publish(every: 0.32, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 3.5) {
            ForEach([0, 1, 2], id: \.self) { index in
                let isActive = activeIndex == index
                Circle()
                    .fill(
                        isActive && !reduceMotion
                            ? PPMessagingPalette.highlight
                            : PPMessagingPalette.secondaryText.opacity(0.56)
                    )
                    .frame(width: 5, height: 5)
                    .scaleEffect(reduceMotion ? 1 : (isActive ? 1.10 : 0.94))
                    .opacity(reduceMotion ? 0.70 : (isActive ? 1 : 0.48))
            }
        }
        .onReceive(timer) { _ in
            guard !reduceMotion else { return }
            withAnimation(.timingCurve(0.23, 1, 0.32, 1, duration: 0.16)) {
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
        HStack(spacing: 10) {
            if !dynamicTypeSize.isAccessibilitySize {
                line
            }

            Text(label)
                .font(.custom("Beiruti-Bold", size: 11.5, relativeTo: .caption))
                .foregroundStyle(PPMessagingPalette.secondaryText)
                .padding(.horizontal, 11)
                .frame(minHeight: 28)
                .background(PPMessagingPalette.separatorSurface, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(PPMessagingPalette.controlStroke, lineWidth: 0.6)
                }

            if !dynamicTypeSize.isAccessibilitySize {
                line
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(PPMessagingFormatters.accessibleDate(date))
    }

    private var line: some View {
        LinearGradient(
            colors: [.clear, PPMessagingPalette.hairline, .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
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
                .foregroundStyle(PPMessagingPalette.highlight)
                .padding(.horizontal, 11)
                .frame(minHeight: 28)
                .background(PurePetsMessagingTheme.brandSoft, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(PPMessagingPalette.highlight.opacity(0.20), lineWidth: 0.7)
                }

            line
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(localized("chat_unread"))
    }

    private var line: some View {
        LinearGradient(
            colors: [.clear, PPMessagingPalette.highlight.opacity(0.42), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private struct PPMessagingLatestButton: View {
    let count: Int
    let action: () -> Void

    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(PPMessagingPalette.highlight)
                    .frame(width: 30, height: 30)
                    .background(PurePetsMessagingTheme.brandSoft, in: Circle())

                if count > 0 {
                    Text(localizedCount)
                        .font(
                            Font.ppBeirutiBold(size: 11.5, relativeTo: .caption)
                                .monospacedDigit()
                        )
                        .foregroundStyle(PPMessagingPalette.primaryText)
                        .padding(.trailing, 4)
                }
            }
            .frame(minWidth: 46, minHeight: 46)
            .padding(.horizontal, count > 0 ? 7 : 0)
            .background {
                if count > 0 {
                    Capsule(style: .continuous)
                        .fill(PPMessagingPalette.sheetSurface)
                } else {
                    Circle()
                        .fill(PPMessagingPalette.sheetSurface)
                }
            }
            .overlay {
                if count > 0 {
                    Capsule(style: .continuous)
                        .strokeBorder(PPMessagingPalette.controlStroke, lineWidth: 0.8)
                } else {
                    Circle()
                        .strokeBorder(PPMessagingPalette.controlStroke, lineWidth: 0.8)
                }
            }
            .shadow(
                color: PPMessagingPalette.shadow.opacity(colorScheme == .dark ? 0.32 : 0.15),
                radius: 11,
                y: 5
            )
        }
        .buttonStyle(PPMessagingPressButtonStyle())
        .accessibilityLabel(
            count > 0
                ? String(
                    format: localized("chat_unread_count_accessibility_format"),
                    localizedCount
                )
                : localized("chat_scroll_latest")
        )
    }

    private var localizedCount: String {
        count.formatted(.number.locale(locale))
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

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RadialGradient(
                colors: [Color.white.opacity(0.06), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 420
            )
            .ignoresSafeArea()

            if message.kind == "video", let url = message.mediaURL {
                PPMessagingVideoPlayer(url: url)
                    .ignoresSafeArea(edges: .horizontal)
            } else {
                PPMessagingRemoteImage(
                    localImage: message.localImage,
                    url: message.mediaURL,
                    contentMode: .fit
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 54)
            }

            LinearGradient(
                colors: [Color.black.opacity(0.48), .clear, Color.black.opacity(0.30)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack {
                HStack(spacing: 12) {
                    viewerButton(
                        systemName: "xmark",
                        accessibilityLabel: localized("Close"),
                        action: close
                    )

                    Spacer()

                    viewerButton(
                        systemName: "square.and.arrow.down",
                        accessibilityLabel: localized("chat_media_download"),
                        action: onSave
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer()
            }
        }
        .statusBar(hidden: true)
    }

    private func viewerButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background {
                    ZStack {
                        if !reduceTransparency {
                            Circle().fill(.ultraThinMaterial)
                        }
                        Circle()
                            .fill(Color.black.opacity(reduceTransparency ? 0.78 : 0.30))
                    }
                }
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.20), lineWidth: 0.8)
                }
                .shadow(color: Color.black.opacity(0.28), radius: 9, y: 4)
        }
        .buttonStyle(PPMessagingPressButtonStyle())
        .accessibilityLabel(accessibilityLabel)
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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        ZStack {
            PPMessagingPalette.canvas

            WorldGlassBackground(
                style: .messaging,
                intensity: allowsAmbientDetail
                    ? (colorScheme == .dark ? 0.52 : 0.68)
                    : 0.34,
                isFaded: backgroundImage != nil
            )

            if allowsAmbientDetail {

                RadialGradient(
                    colors: [PPMessagingPalette.canvasWarmField, .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 380
                )

                RadialGradient(
                    colors: [PPMessagingPalette.canvasSignalField, .clear],
                    center: .bottomLeading,
                    startRadius: 10,
                    endRadius: 460
                )

                PPMessagingThreadField()
                    .opacity(backgroundImage == nil ? 1 : 0.28)
            }

            if let backgroundImage {
                GeometryReader { proxy in
                    Image(uiImage: backgroundImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .saturation(0.38)
                        .contrast(0.94)
                        .opacity(colorScheme == .dark ? 0.18 : 0.25)
                        .id(ObjectIdentifier(backgroundImage))
                        .transition(.opacity)
                }

                PPMessagingPalette.canvas
                    .opacity(colorScheme == .dark ? 0.30 : 0.34)
            }
        }
        .animation(reduceMotion ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: 0.24), value: backgroundImage.map(ObjectIdentifier.init))
        .accessibilityHidden(true)
    }

    private var allowsAmbientDetail: Bool {
        !reduceTransparency && colorSchemeContrast == .standard
    }
}

private struct PPMessagingThreadField: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: size.width * 0.02, y: size.height * 0.26))
                    path.addCurve(
                        to: CGPoint(x: size.width * 0.98, y: size.height * 0.48),
                        control1: CGPoint(x: size.width * 0.30, y: size.height * 0.08),
                        control2: CGPoint(x: size.width * 0.65, y: size.height * 0.68)
                    )
                }
                .stroke(
                    LinearGradient(
                        colors: [
                            .clear,
                            PPMessagingPalette.threadLine,
                            PPMessagingPalette.highlight.opacity(0.08),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 0.8, lineCap: .round)
                )

                Path { path in
                    path.move(to: CGPoint(x: size.width * 0.12, y: size.height * 0.78))
                    path.addCurve(
                        to: CGPoint(x: size.width * 0.88, y: size.height * 0.14),
                        control1: CGPoint(x: size.width * 0.34, y: size.height * 0.94),
                        control2: CGPoint(x: size.width * 0.62, y: size.height * 0.02)
                    )
                }
                .stroke(
                    PPMessagingPalette.threadLine.opacity(0.62),
                    style: StrokeStyle(lineWidth: 0.6, lineCap: .round)
                )

                Circle()
                    .fill(PPMessagingPalette.highlight.opacity(0.09))
                    .frame(width: 7, height: 7)
                    .position(x: size.width * 0.22, y: size.height * 0.20)

                Circle()
                    .fill(PPMessagingPalette.threadLine.opacity(0.86))
                    .frame(width: 5, height: 5)
                    .position(x: size.width * 0.80, y: size.height * 0.60)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct PPMessagingComposerBackdrop: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    .clear,
                    PPMessagingPalette.composerBackdrop.opacity(0.78),
                    PPMessagingPalette.composerBackdrop
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            if allowsAmbientDetail {
                RadialGradient(
                    colors: [PPMessagingPalette.canvasSignalField.opacity(0.72), .clear],
                    center: .bottom,
                    startRadius: 0,
                    endRadius: 240
                )
            }

            LinearGradient(
                colors: [.clear, PPMessagingPalette.hairline, .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 0.5)
        }
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var allowsAmbientDetail: Bool {
        !reduceTransparency && colorSchemeContrast == .standard
    }
}

private typealias PPMessagingPressButtonStyle = PurePetsMessagingPressButtonStyle

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
            formatter.timeStyle = .none
            return formatter
        }
    }

}

private enum PPMessagingPalette {
    static let canvasUIColor = UIColor { traits in
        let increasedContrast = traits.accessibilityContrast == .high
        if traits.userInterfaceStyle == .dark {
            return UIColor(
                red: increasedContrast ? 0.018 : 0.041,
                green: increasedContrast ? 0.020 : 0.045,
                blue: increasedContrast ? 0.021 : 0.047,
                alpha: 1
            )
        }
        return UIColor(
            red: increasedContrast ? 0.930 : 0.956,
            green: increasedContrast ? 0.918 : 0.946,
            blue: increasedContrast ? 0.895 : 0.928,
            alpha: 1
        )
    }

    static let canvas = PurePetsMessagingTheme.canvas
    static let composerBackdrop = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.041, green: 0.045, blue: 0.047, alpha: 0.975)
            : UIColor(red: 0.956, green: 0.946, blue: 0.928, alpha: 0.975)
    })
    static let primaryText = Color.ppTextPrimary
    static let secondaryText = Color.ppTextSecondary
    static let inverseText = Color(UIColor.systemBackground)
    static let outgoingText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .white : UIColor(white: 0.98, alpha: 1)
    })
    static let outgoingSecondary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.74)
            : UIColor(white: 1.0, alpha: 0.78)
    })
    static let incomingBubble = PurePetsMessagingTheme.incomingSurface
    static let outgoingBubble = PurePetsMessagingTheme.outgoingBubbleSurface
    static let incomingStroke = PurePetsMessagingTheme.incomingBubbleStroke
    static let outgoingStroke = PurePetsMessagingTheme.outgoingBubbleStroke
    static let controlSurface = PurePetsMessagingTheme.surfaceRaised.opacity(0.82)
    static let controlStroke = PurePetsMessagingTheme.surfaceStroke
    static let sheetSurface = PurePetsMessagingTheme.surface
    static let shadow = PurePetsMessagingTheme.messageShadow
    static let hairline = Color.ppSeparator.opacity(0.72)
    static let separatorSurface = PurePetsMessagingTheme.surfaceRaised.opacity(0.88)
    static let mediaPlaceholder = Color.ppSecondarySurface
    static let online = Color.ppSuccess
    static let failure = Color.ppError
    static let highlight = PurePetsMessagingTheme.signal
    static let incomingReplySurface = PurePetsMessagingTheme.replySurface
    static let outgoingReplySurface = Color.white.opacity(0.09)
    static let warningSurface = Color(UIColor.systemOrange).opacity(0.11)
    static let warningText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.systemOrange
            : UIColor.systemOrange.darker(by: 0.22)
    })
    static let avatarStroke = PurePetsMessagingTheme.surfaceStroke
    static let avatarTop = PurePetsMessagingTheme.avatarSurface
    static let avatarBottom = PurePetsMessagingTheme.avatarDepth
    static let avatarLogoSurface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.92, alpha: 1)
            : UIColor.white
    })
    static let canvasWarmField = PurePetsMessagingTheme.ambientWarm
    static let canvasSignalField = PurePetsMessagingTheme.ambientSignal
    static let threadLine = Color(UIColor { traits in
        let increasedContrast = traits.accessibilityContrast == .high
        return traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: increasedContrast ? 0.10 : 0.045)
            : UIColor(white: 0, alpha: increasedContrast ? 0.11 : 0.042)
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
