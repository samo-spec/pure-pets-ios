import Combine
import PurePetsMessagingCore
import PurePetsMessagingUI
import SwiftUI
import UIKit

// The existing host owns transport and navigation; this view owns presentation only.
struct MessagingScreenVC: View {
    @ObservedObject var state: PPMessagingScreenState
    let relay: PPMessagingActionRelay

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
    @State private var replyThresholdReached = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var headerLayoutRevision = 0
    @State private var preservesLatestDuringHeaderLayout = false
    @State private var measuredHeaderHeight: CGFloat = 0
    @StateObject private var packageAudioCoordinator = ConversationAudioCoordinator()
    @State private var unsendEligibilityNow = Date()

    private var contentDirection: LayoutDirection {
        languageCode.hasPrefix("ar") ? .rightToLeft : .leftToRight
    }

    var body: some View {
        VStack(spacing: 0) {
            conversationHeaderInset
                .fixedSize(horizontal: false, vertical: true)
                .background {
                    GeometryReader { headerProxy in
                        Color.clear.preference(
                            key: PPMessagingHeaderHeightPreferenceKey.self,
                            value: headerProxy.size.height
                        )
                    }
                }
                .onPreferenceChange(
                    PPMessagingHeaderHeightPreferenceKey.self,
                    perform: handleMeasuredHeaderHeightChange
                )

            // Measure only the reading area between the intrinsic header and
            // composer, so short transcripts can rest against the writing edge.
            GeometryReader { viewport in
                conversationContent(
                    availableWidth: viewport.size.width,
                    minimumHeight: viewport.size.height
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            composerRegion
        }
        .background {
            MessagingPageBackground(backgroundImage: state.backgroundImage)
                .ignoresSafeArea()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if state.keyboardIsPresented {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
        .accessibilityAction(named: Text(localized("chat_keyboard_dismiss"))) {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .accessibilityIdentifier("pp.messaging.screen")
        .environment(
            \.layoutDirection,
            contentDirection
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
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            unsendEligibilityNow = Date()
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 30_000_000_000) }
                catch { return }
                guard !Task.isCancelled, scenePhase == .active else { return }
                unsendEligibilityNow = Date()
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                cancelReplyGesture()
                packageAudioCoordinator.stopAll()
            }
        }
        .onDisappear { packageAudioCoordinator.stopAll() }
        .fullScreenCover(item: $presentedMedia) { message in
            PPMessagingMediaViewer(message: message) {
                presentedMedia = nil
            } onSave: {
                relay.request(.saveMedia, messageID: message.id)
            }
        }
    }

    @ViewBuilder
    private var composerRegion: some View {
        if state.isConversationBlocked {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(PPMessagingPalette.failure)
                    .accessibilityHidden(true)

                Text(localized("chat.blocked.message"))
                    .font(Font.ppBeirutiSemiBold(size: 15, relativeTo: .body))
                    .foregroundStyle(PPMessagingPalette.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(Color.ppBackground)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("pp.messaging.composer.blocked")
        } else {
            ChatBarView(
                state: state.composerState,
                presentation: .messaging,
                chatBarHeight: 54,
                onSendText: { relay.sendText($0) },
                onCameraTap: { relay.tapCamera() },
                onVideoTap: { relay.tapVideo() },
                onContactTap: { relay.tapContact() },
                contactEnabled: relay.delegate != nil || relay.onContactTap != nil,
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
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background {
                Color.ppBackground
            }
        }
    }

    @ViewBuilder
    private var conversationHeaderInset: some View {
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
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
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

    private func handleMeasuredHeaderHeightChange(_ height: CGFloat) {
        guard height > 0 else { return }
        if measuredHeaderHeight == 0 {
            measuredHeaderHeight = height
            return
        }

        // Expansion already publishes before its state mutation. This path
        // covers other real inset changes such as language, Dynamic Type,
        // context reflow, and the connection ribbon. Once preservation begins,
        // intermediate animation frames are ignored until the existing settle.
        guard abs(height - measuredHeaderHeight) > 0.5,
              hasPositionedInitially,
              isAtLatest,
              !preservesLatestDuringHeaderLayout else { return }
        measuredHeaderHeight = height
        preservesLatestDuringHeaderLayout = true
        headerLayoutRevision &+= 1
    }

    @ViewBuilder
    private func conversationContent(availableWidth: CGFloat, minimumHeight: CGFloat) -> some View {
        if state.isLoading && state.messages.isEmpty {
            MessagingPageState(kind: .loading, action: {})
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if state.connectionInterrupted && state.messages.isEmpty {
            MessagingPageState(kind: .offline) {
                relay.request(.retryConnection)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if state.initialLoadCompleted && state.messages.isEmpty {
            MessagingPageState(kind: .empty) {
                state.composerState.isFocusedTrigger = true
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            messageScroller(availableWidth: availableWidth, minimumHeight: minimumHeight)
        }
    }

    private func messageScroller(availableWidth: CGFloat, minimumHeight: CGFloat) -> some View {
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
                                MessagingDayHeading(date: message.timestamp)
                                    .padding(.vertical, index == 0 ? 8 : 10)
                            }

                            if state.unreadBoundaryMessageID == message.id {
                                MessagingUnreadHeading()
                                    .id(PPMessagingScrollID.unreadBoundary)
                                    .padding(.vertical, 8)
                            }

                            ConversationPassageRow(
                                message: PPMessagingAdapter.chatMessage(
                                    from: message,
                                    groupPosition: packageGroupPosition(at: index),
                                    replySource: replySource(for: message),
                                    audioState: audioState(for: message),
                                    conversationName: state.conversationName
                                ),
                                startsPassage: grouping(at: index) == .single || grouping(at: index) == .first,
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
                                maximumWidth: maximumBubbleWidth(
                                    for: message,
                                    availableWidth: availableWidth
                                ),
                                contentLayoutDirection: contentDirection
                            )
                            // Sender lanes are physical, not semantic: outgoing
                            // remains on the screen's right edge in both Arabic
                            // and English. Payload text receives the captured
                            // locale direction through ConversationPassageRow.
                            .environment(\.layoutDirection, .leftToRight)
                            .id(message.id)
                            .accessibilityIdentifier("pp.messaging.message.\(message.id)")
                            .padding(.bottom, rowSpacing(after: index))
                        }

                        if state.isTyping {
                            MessagingWritingLine(name: state.conversationName)
                                .id(PPMessagingScrollID.typing)
                                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
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
                    .frame(minHeight: minimumHeight, alignment: .bottom)
                }
                .background(Color.clear)
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
                    guard presented, isAtLatest else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        scrollToLatest(using: proxy, animated: !reduceMotion)
                    }
                }
                .onChange(of: state.keyboardExpansionRevision) { _ in
                    // The host publishes keyboard frame expansion. Scroll message list to bottom
                    // so the user's focus and latest messages follow the keyboard expansion.
                    guard hasPositionedInitially, isAtLatest else { return }
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
                    MessagingReturnToPresent(count: unseenMessageCount) {
                        scrollToLatest(using: proxy, animated: true)
                    }
                    // Overlay-only placement keeps the button above the date
                    // and composer without changing message scroll insets.
                    .padding(.bottom, 18)
                    .zIndex(2)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.94).combined(with: .opacity))
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

        let reached = horizontalDistance >= PPMessagingReplyGestureMetrics.commitThreshold
        if reached && !replyThresholdReached {
            UISelectionFeedbackGenerator().selectionChanged()
        }
        replyThresholdReached = reached
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
        replyThresholdReached = false
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
        guard index < state.messages.count - 1 else { return 0 }
        // A sender change opens a new passage; consecutive thoughts share the
        // same reading rhythm without another enclosing surface.
        return grouping(at: index) == .last || grouping(at: index) == .single ? 20 : 0
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
            return max(120, min(transcriptWidth - 16, 560))
        }

        switch message.kind {
        case "audio":
            return min(max(transcriptWidth * 0.70, 244), 272)
        case "image", "video":
            return min(max(transcriptWidth * 0.74, 238), 288)
        case "sticker":
            return min(max(transcriptWidth * 0.54, 194), 224)
        default:
            return max(120, min(transcriptWidth - 32, 480))
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
        Language.get(key, alter: key) ?? NSLocalizedString(key, comment: "")
    }
}

private struct MessagingPageBackground: View {
    let backgroundImage: UIImage?

    var body: some View {
        ZStack {
            Color.ppBackground
            if let backgroundImage {
                Image(uiImage: backgroundImage)
                    .resizable()
                    .scaledToFill()
                    .opacity(0.06)
                    .clipped()
            }
        }
        .accessibilityHidden(true)
    }
}

/// Actual remote typing, expressed as an unfinished line on the same page.
/// The schedule is suspended with the surface, Reduce Motion and Low Power Mode.
private struct MessagingWritingLine: View {
    let name: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    var body: some View {
        HStack(spacing: 12) {
            TimelineView(.animation(minimumInterval: 1.0 / 12, paused: reduceMotion || lowPower || scenePhase != .active)) { timeline in
                let phase = reduceMotion || lowPower || scenePhase != .active
                    ? 0.5 : (sin(timeline.date.timeIntervalSinceReferenceDate * 4) + 1) / 2
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(Color.ppPrimary.opacity(index == 2 ? 0.45 : 1))
                            .frame(width: CGFloat(8 + index * 4), height: 2)
                            .scaleEffect(x: index == 2 ? 0.55 + phase * 0.45 : 1, anchor: .leading)
                    }
                }
            }
            .frame(width: 48, height: 16)
            .accessibilityHidden(true)
            Text(String(format: messagingCopy("chat_typing_format"), "\u{2068}\(name)\u{2069}"))
                .font(.ppBeirutiMedium(size: 14, relativeTo: .subheadline))
                .foregroundStyle(Color.ppTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }
}

private struct MessagingReturnToPresent: View {
    let count: Int
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if count > 0 {
                    Text(count, format: .number)
                        .monospacedDigit()
                        .foregroundStyle(Color.ppPrimary)
                }
                Text(messagingCopy("chat_return_to_present"))
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "arrow.down")
                    .accessibilityHidden(true)
            }
            .font(.ppBeirutiSemiBold(size: 15, relativeTo: .subheadline))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .foregroundStyle(Color.ppTextPrimary)
            .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12).strokeBorder(Color.ppSurfaceBorder, lineWidth: 1)
            }
        }
        .buttonStyle(PurePetsMessagingPressButtonStyle())
        .accessibilityIdentifier("pp.messaging.return-to-present")
    }
}

private func messagingCopy(_ key: String) -> String {
    Language.get(key, alter: key) ?? NSLocalizedString(key, comment: "")
}

private struct MessagingPageState: View {
    enum Kind { case loading, empty, offline }
    let kind: Kind
    let action: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if kind == .loading {
                    ProgressView().tint(Color.ppPrimary)
                } else {
                    Image(systemName: kind == .offline ? "wifi.slash" : "pencil.line")
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundStyle(Color.ppPrimary)
                        .accessibilityHidden(true)
                }
                Text(messagingCopy(titleKey))
                    .font(.ppBeirutiBold(size: 34, relativeTo: .largeTitle))
                    .foregroundStyle(Color.ppTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(messagingCopy(detailKey))
                    .font(.ppBeirutiRegular(size: 18, relativeTo: .body))
                    .foregroundStyle(Color.ppTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if kind != .loading {
                    Button(action: action) {
                        HStack(spacing: 16) {
                            Text(messagingCopy(kind == .offline ? "KLang_Retry" : "chat_empty_thread_action"))
                                .font(.ppBeirutiSemiBold(size: 18, relativeTo: .headline))
                                .fixedSize(horizontal: false, vertical: true)
                            Image(systemName: kind == .offline ? "arrow.clockwise" : "arrow.down")
                                .accessibilityHidden(true)
                        }
                        .frame(minHeight: 48)
                        .contentShape(Rectangle())
                    }
                    .foregroundStyle(Color.ppPrimary)
                    .buttonStyle(PurePetsMessagingPressButtonStyle())
                }
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: 460, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(32)
            .padding(.top, 32)
        }
    }

    private var titleKey: String {
        switch kind {
        case .loading: return "chat_loading_messages_title"
        case .empty: return "chat_page_empty_title"
        case .offline: return "chat_offline_title"
        }
    }
    private var detailKey: String {
        switch kind {
        case .loading: return "chat_loading_messages_subtitle"
        case .empty: return "chat_page_empty_detail"
        case .offline: return "chat_offline_subtitle"
        }
    }
}

private struct MessagingDayHeading: View {
    let date: Date

    var body: some View {
        HStack(spacing: 16) {
            Group {
                if Calendar.current.isDateInToday(date) { Text(messagingCopy("chat_date_today")) }
                else if Calendar.current.isDateInYesterday(date) { Text(messagingCopy("chat_date_yesterday")) }
                else { Text(date, style: .date) }
            }
            .font(.ppBeirutiSemiBold(size: 13, relativeTo: .caption))
            .fixedSize(horizontal: false, vertical: true)
            Rectangle().fill(Color.ppSurfaceBorder).frame(height: 1)
                .accessibilityHidden(true)
        }
        .foregroundStyle(Color.ppTextSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct MessagingUnreadHeading: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bookmark.fill").accessibilityHidden(true)
            Text(messagingCopy("chat_unread"))
                .font(.ppBeirutiSemiBold(size: 14, relativeTo: .subheadline))
                .fixedSize(horizontal: false, vertical: true)
            Rectangle().fill(Color.ppPrimary.opacity(0.3)).frame(height: 1)
                .accessibilityHidden(true)
        }
        .foregroundStyle(Color.ppPrimary)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}
