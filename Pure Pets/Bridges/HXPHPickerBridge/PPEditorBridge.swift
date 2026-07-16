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
        "chevron.left"
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

    private enum AppFontWeight {
        case medium
        case bold
    }

    private func appFont(_ weight: AppFontWeight, size: CGFloat) -> UIFont {
        let adjustedSize = size + 1.0
        let fontName: String
        let fallbackWeight: UIFont.Weight
        switch weight {
        case .medium:
            fontName = "Beiruti-Medium"
            fallbackWeight = .medium
        case .bold:
            fontName = "Beiruti-Bold"
            fallbackWeight = .bold
        }

        return UIFont(name: fontName, size: adjustedSize) ??
            UIFont.systemFont(ofSize: adjustedSize, weight: fallbackWeight)
    }

    private func appFont(matching font: UIFont?) -> UIFont {
        let size = max(font?.pointSize ?? 15.0, 10.0)
        let traits = font?.fontDescriptor.symbolicTraits ?? []
        if traits.contains(.traitBold) {
            return appFont(.bold, size: size)
        }
        return appFont(.medium, size: size)
    }

    private func attributedButtonTitle(_ title: String, color: UIColor, font: UIFont) -> NSAttributedString {
        NSAttributedString(
            string: title,
            attributes: [
                .font: font,
                .foregroundColor: color
            ]
        )
    }

    private func buttonTitleAttributes(color: UIColor, font: UIFont) -> [NSAttributedString.Key: Any] {
        [
            .font: font,
            .foregroundColor: color
        ]
    }

    private func applyAppTypography(to item: UIBarButtonItem?) {
        guard let item else { return }
        let font = appFont(.bold, size: 15.0)
        item.setTitleTextAttributes(buttonTitleAttributes(color: .label, font: font), for: .normal)
        item.setTitleTextAttributes(buttonTitleAttributes(color: .secondaryLabel, font: font), for: .disabled)
        item.setTitleTextAttributes(buttonTitleAttributes(color: .label.withAlphaComponent(0.72), font: font), for: .highlighted)
    }

    private func applyAppTypography(to view: UIView) {
        if let label = view as? UILabel {
            label.font = appFont(matching: label.font)
            label.adjustsFontForContentSizeCategory = true
        }

        if let button = view as? UIButton {
            let font = appFont(matching: button.titleLabel?.font)
            button.titleLabel?.font = font
            button.titleLabel?.adjustsFontForContentSizeCategory = true

            let states: [UIControl.State] = [.normal, .highlighted, .selected, .disabled]
            for state in states {
                guard let title = button.title(for: state), !title.isEmpty else { continue }
                let color = button.titleColor(for: state) ?? .label
                button.setAttributedTitle(attributedButtonTitle(title, color: color, font: font), for: state)
            }
        }

        for subview in view.subviews {
            applyAppTypography(to: subview)
        }
    }

    private func applyAppTypography(to navigationBar: UINavigationBar) {
        let titleFont = appFont(.bold, size: 17.0)
        let buttonFont = appFont(.bold, size: 15.0)
        navigationBar.titleTextAttributes = buttonTitleAttributes(color: .label, font: titleFont)
        navigationBar.largeTitleTextAttributes = buttonTitleAttributes(color: .label, font: appFont(.bold, size: 24.0))

        if #available(iOS 15.0, *) {
            func styledAppearance(_ source: UINavigationBarAppearance?) -> UINavigationBarAppearance {
                let appearance = (source?.copy() as? UINavigationBarAppearance) ?? UINavigationBarAppearance()
                appearance.titleTextAttributes = buttonTitleAttributes(color: .label, font: titleFont)
                appearance.largeTitleTextAttributes = buttonTitleAttributes(color: .label, font: appFont(.bold, size: 24.0))

                let item = UIBarButtonItemAppearance(style: .plain)
                item.normal.titleTextAttributes = buttonTitleAttributes(color: .label, font: buttonFont)
                item.highlighted.titleTextAttributes = buttonTitleAttributes(color: .label.withAlphaComponent(0.72), font: buttonFont)
                item.disabled.titleTextAttributes = buttonTitleAttributes(color: .secondaryLabel, font: buttonFont)
                appearance.buttonAppearance = item
                appearance.doneButtonAppearance = item
                appearance.backButtonAppearance = item

                return appearance
            }

            navigationBar.standardAppearance = styledAppearance(navigationBar.standardAppearance)
            navigationBar.scrollEdgeAppearance = styledAppearance(navigationBar.scrollEdgeAppearance)
            navigationBar.compactAppearance = styledAppearance(navigationBar.compactAppearance)
            navigationBar.compactScrollEdgeAppearance = styledAppearance(navigationBar.compactScrollEdgeAppearance)
        }
    }

    private func applyEditorTypography(to navigationController: UINavigationController) {
        applyAppTypography(to: navigationController.navigationBar)
        applyDirectionalBackIndicator(to: navigationController.navigationBar)

        let visibleItems = navigationController.viewControllers.flatMap { controller -> [UIBarButtonItem] in
            var items: [UIBarButtonItem] = []
            if let leftItems = controller.navigationItem.leftBarButtonItems { items.append(contentsOf: leftItems) }
            if let rightItems = controller.navigationItem.rightBarButtonItems { items.append(contentsOf: rightItems) }
            if let backItem = controller.navigationItem.backBarButtonItem { items.append(backItem) }
            return items
        }
        visibleItems.forEach(applyAppTypography(to:))
        applyAppTypography(to: navigationController.view)
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
        config.modalPresentationStyle = .fullScreen
        config.toolsView.toolOptions = editorToolOptionsWithoutEmoji()

        let asset = EditorAsset(type: .image(image))
        let editorVC = EditorViewController(asset, config: config)
        editorVC.delegate = self

        let nav = UINavigationController(rootViewController: editorVC)
        nav.modalPresentationStyle = .fullScreen
        let direction: UISemanticContentAttribute = useArabic ? .forceRightToLeft : .forceLeftToRight
        nav.view.semanticContentAttribute = direction
        nav.navigationBar.semanticContentAttribute = direction

        applyEditorTypography(to: nav)

        viewController.present(nav, animated: true) { [weak self, weak nav] in
            guard let self = self, let nav = nav else { return }
            self.applyEditorTypography(to: nav)
            DispatchQueue.main.async { [weak self, weak nav] in
                guard let self, let nav else { return }
                self.applyEditorTypography(to: nav)
            }
        }
    }

    @objc(presentEditorFromViewController:withVideoURL:useArabic:)
    public func presentEditor(
        from viewController: UIViewController,
        withVideoURL videoURL: URL,
        useArabic: Bool
    ) {
        self.useArabic = useArabic
        PhotoManager.shared.createLanguageBundle(languageType: useArabic ? .arabic : .english)

        var config = EditorConfiguration()
        config.languageType = useArabic ? .arabic : .english
        config.indicatorType = .circle
        config.modalPresentationStyle = .fullScreen
        config.toolsView.toolOptions = editorToolOptionsWithoutEmoji()

        let editorVC = EditorViewController(EditorAsset(type: .video(videoURL)), config: config)
        editorVC.delegate = self
        let nav = UINavigationController(rootViewController: editorVC)
        nav.modalPresentationStyle = .fullScreen
        let direction: UISemanticContentAttribute = useArabic ? .forceRightToLeft : .forceLeftToRight
        nav.view.semanticContentAttribute = direction
        nav.navigationBar.semanticContentAttribute = direction
        applyEditorTypography(to: nav)
        viewController.present(nav, animated: true) { [weak self, weak nav] in
            guard let self, let nav else { return }
            self.applyEditorTypography(to: nav)
            DispatchQueue.main.async { [weak self, weak nav] in
                guard let self, let nav else { return }
                self.applyEditorTypography(to: nav)
            }
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
        var info: [AnyHashable: Any] = [:]

        switch asset.result {
        case .image(let result, _):
            finalImage = result.image
            finalURL = result.urlConfig.url
            info["mediaType"] = "image"
        case .video(let result, _):
            finalImage = result.coverImage
            finalURL = result.urlConfig.url
            info["mediaType"] = "video"
        case .none:
            break
        }

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
