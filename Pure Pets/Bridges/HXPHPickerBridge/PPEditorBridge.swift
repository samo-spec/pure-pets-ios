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

    private var directionalBackSymbolName: String {
        useArabic ? "chevron.right" : "chevron.left"
    }

    private func directionalBackImage() -> UIImage? {
        UIImage(systemName: directionalBackSymbolName)?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold))
            .withRenderingMode(.alwaysTemplate)
    }

    private func editorToolOptionsWithoutEmoji() -> [EditorConfiguration.ToolsView.Options] {
        EditorConfiguration.ToolsView.default.toolOptions.filter { option in
            switch option.type {
            case .chartlet:
                return false
            default:
                return true
            }
        }
    }

    private func applyDirectionalBackIndicator(to navigationBar: UINavigationBar) {
        let chevron = directionalBackImage()
        navigationBar.backIndicatorImage = chevron
        navigationBar.backIndicatorTransitionMaskImage = chevron

        if #available(iOS 15.0, *) {
            func appearanceWithBackIndicator(_ source: UINavigationBarAppearance?) -> UINavigationBarAppearance {
                let appearance =
                    (source?.copy() as? UINavigationBarAppearance) ??
                    (navigationBar.standardAppearance.copy() as! UINavigationBarAppearance)
                appearance.setBackIndicatorImage(chevron, transitionMaskImage: chevron)
                return appearance
            }

            navigationBar.standardAppearance = appearanceWithBackIndicator(navigationBar.standardAppearance)
            navigationBar.scrollEdgeAppearance = appearanceWithBackIndicator(navigationBar.scrollEdgeAppearance)
            navigationBar.compactAppearance = appearanceWithBackIndicator(navigationBar.compactAppearance)
            navigationBar.compactScrollEdgeAppearance = appearanceWithBackIndicator(navigationBar.compactScrollEdgeAppearance)
        }
    }

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
        config.toolsView.toolOptions = editorToolOptionsWithoutEmoji()

        let asset = EditorAsset(type: .image(image))
        let editorVC = EditorViewController(asset, config: config)
        editorVC.delegate = self

        let nav = UINavigationController(rootViewController: editorVC)
        nav.modalPresentationStyle = .pageSheet
        let direction: UISemanticContentAttribute = useArabic ? .forceRightToLeft : .forceLeftToRight
        nav.view.semanticContentAttribute = direction
        nav.navigationBar.semanticContentAttribute = direction

        // RTL-aware back arrow
        applyDirectionalBackIndicator(to: nav.navigationBar)

        viewController.present(nav, animated: true) { [weak self, weak nav] in
            guard let self = self, let nav = nav else { return }
            self.applyDirectionalBackIndicator(to: nav.navigationBar)
        }
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
