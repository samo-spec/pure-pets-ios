//
//  PPNovaSwiftUIChatBarViewController.swift
//  Pure Pets
//
//  Created by Antigravity on 11/07/26.
//

import UIKit
import SwiftUI
import Combine

/// Shared state for bridging text, thinking, and focus triggers between UIKit (ObjC) and SwiftUI.
@objc(PPNovaChatBarState)
public final class PPNovaChatBarState: NSObject, ObservableObject {
    @Published @objc public var message: String = ""
    @Published @objc public var thinking: Bool = false
    @Published @objc public var isFocusedTrigger: Bool = false
    @Published @objc public var replyTitle: String = ""
    @Published @objc public var replySubtitle: String = ""
    /// Host capability. User-to-user messaging keeps this enabled; hosts that
    /// cannot transport audio can hide the recorder without forking ChatBarView.
    @Published @objc public var voiceEnabled: Bool = true

    @objc public var hasReply: Bool {
        !replyTitle.isEmpty || !replySubtitle.isEmpty
    }
}

/// Objective-C compatible delegate for the SwiftUI ChatBar actions.
@objc(PPNovaSwiftUIChatBarViewControllerDelegate)
public protocol PPNovaSwiftUIChatBarViewControllerDelegate: AnyObject {
    @objc func swiftUIChatBarDidSendText(_ text: String)
    @objc func swiftUIChatBarDidTapCamera()
    @objc func swiftUIChatBarDidTapVideo()
    @objc func swiftUIChatBarDidTapContact()
    @objc optional func swiftUIChatBarDidSelectSticker(_ sticker: PPChatSticker)
    @objc optional func swiftUIChatBarDidChangeText(_ text: String)
    @objc optional func swiftUIChatBarDidSendAudioWithURL(_ audioURL: URL, duration: Double)
    @objc optional func swiftUIChatBarDidCancelReply()
}

/// A UIViewController subclass that hosts the SwiftUI ChatBarView and bridges interaction back to UIKit.
@objc(PPNovaSwiftUIChatBarViewController)
public final class PPNovaSwiftUIChatBarViewController: UIViewController {

    @objc public weak var delegate: PPNovaSwiftUIChatBarViewControllerDelegate?
    @objc public let chatBarState = PPNovaChatBarState()

    @objc public var draftText: String {
        get { chatBarState.message }
        set { chatBarState.message = newValue }
    }

    @objc public var thinking: Bool {
        get { chatBarState.thinking }
        set { chatBarState.thinking = newValue }
    }

    @objc public var voiceEnabled: Bool {
        get { chatBarState.voiceEnabled }
        set { chatBarState.voiceEnabled = newValue }
    }

    @objc public func focusTextInput() {
        chatBarState.isFocusedTrigger = true
    }

    @objc public func setReplyPreviewTitle(_ title: String, subtitle: String, animated: Bool) {
        chatBarState.replyTitle = title
        chatBarState.replySubtitle = subtitle
    }

    @objc public func clearReplyPreviewAnimated(_ animated: Bool) {
        chatBarState.replyTitle = ""
        chatBarState.replySubtitle = ""
    }

    private var hostingController: UIHostingController<ChatBarView>?
    private var cancellables = Set<AnyCancellable>()

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        let chatBarView = ChatBarView(
            state: chatBarState,
            onSendText: { [weak self] text in
                self?.delegate?.swiftUIChatBarDidSendText(text)
            },
            onCameraTap: { [weak self] in
                self?.delegate?.swiftUIChatBarDidTapCamera()
            },
            onVideoTap: { [weak self] in
                self?.delegate?.swiftUIChatBarDidTapVideo()
            },
            onContactTap: { [weak self] in
                self?.delegate?.swiftUIChatBarDidTapContact()
            },
            onStickerTap: { [weak self] sticker in
                self?.delegate?.swiftUIChatBarDidSelectSticker?(sticker)
            },
            onSendAudio: { [weak self] url, duration in
                guard let sendAudio = self?.delegate?
                    .swiftUIChatBarDidSendAudioWithURL else {
                    try? FileManager.default.removeItem(at: url)
                    return
                }
                sendAudio(url, duration)
            },
            onCancelReply: { [weak self] in
                self?.delegate?.swiftUIChatBarDidCancelReply?()
            }
        )

        let hc = UIHostingController(rootView: chatBarView)
        hc.view.backgroundColor = .clear
        addChild(hc)
        view.addSubview(hc.view)
        hc.didMove(toParent: self)

        hc.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hc.view.topAnchor.constraint(equalTo: view.topAnchor),
            hc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        self.hostingController = hc

        // Monitor message changes and notify the delegate for typing indicators
        chatBarState.$message
            .dropFirst()
            .sink { [weak self] text in
                self?.delegate?.swiftUIChatBarDidChangeText?(text)
            }
            .store(in: &cancellables)
    }
}
