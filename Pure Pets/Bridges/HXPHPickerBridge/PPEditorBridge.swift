//
//  PPEditorBridge.swift
//  PurePets
//
//  Swift bridge for HXPhotoPicker image editor.
//  Posts notifications so Objective-C callers receive edited images.
//

import Foundation
import UIKit
import HXPhotoPicker

// MARK: - Notifications

public extension Notification.Name {
    /// userInfo: ["image": UIImage, "url": NSURL (optional)]
    static let PPEditorBridgeDidFinish = Notification.Name("PPEditorBridgeDidFinish")
    static let PPEditorBridgeDidCancel = Notification.Name("PPEditorBridgeDidCancel")
}

// MARK: - PPEditorBridge

@objc public class PPEditorBridge: NSObject {

    @objc public var useArabic: Bool = false

    /// Present the HXPhotoPicker editor for a given image.
    @objc(presentEditorFromViewController:withImage:useArabic:)
    public func presentEditor(
        from viewController: UIViewController,
        with image: UIImage,
        useArabic: Bool
    ) {
        self.useArabic = useArabic

        PhotoManager.shared.createLanguageBundle(
            languageType: useArabic ? .arabic : .english
        )

        var config = EditorConfiguration()
        config.languageType = useArabic ? .arabic : .english
        config.indicatorType = .circle
        config.modalPresentationStyle = .pageSheet

        let asset = EditorAsset(type: .image(image))
        let editorVC = EditorViewController(asset, config: config)
        editorVC.delegate = self

        let nav = UINavigationController(rootViewController: editorVC)
        nav.modalPresentationStyle = .pageSheet
        let direction: UISemanticContentAttribute = useArabic ? .forceRightToLeft : .forceLeftToRight
        nav.view.semanticContentAttribute = direction
        nav.navigationBar.semanticContentAttribute = direction

        // RTL-aware back arrow
        let chevron = UIImage(systemName: useArabic ? "chevron.right" : "chevron.left")
        nav.navigationBar.backIndicatorImage = chevron
        nav.navigationBar.backIndicatorTransitionMaskImage = chevron

        viewController.present(nav, animated: true)
    }
}

// MARK: - EditorViewControllerDelegate

extension PPEditorBridge: EditorViewControllerDelegate {

    public func editorViewController(
        _ editorViewController: EditorViewController,
        didFinish asset: EditorAsset
    ) {
        var finalImage: UIImage?
        var finalURL: URL?

        switch asset.result {
        case .image(let result, _):
            finalImage = result.image
            finalURL = result.urlConfig.url
        case .video(let result, _):
            finalImage = result.coverImage
            finalURL = result.urlConfig.url
        case .none:
            break
        }

        var info: [AnyHashable: Any] = [:]
        if let img = finalImage { info["image"] = img }
        if let u = finalURL { info["url"] = u as NSURL }

        NotificationCenter.default.post(
            name: .PPEditorBridgeDidFinish,
            object: nil,
            userInfo: info
        )

        editorViewController.dismiss(animated: true)
    }

    public func editorViewController(
        didCancel editorViewController: EditorViewController
    ) {
        NotificationCenter.default.post(
            name: .PPEditorBridgeDidCancel,
            object: nil
        )
        editorViewController.dismiss(animated: true)
    }
}
