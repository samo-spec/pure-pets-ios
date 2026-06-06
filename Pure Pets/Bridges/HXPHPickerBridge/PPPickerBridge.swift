//
//  PPPickerBridge.swift
//  PurePets
//
//  Swift bridge for HXPhotoPicker photo selection.
//  Supports Arabic/English, RTL/LTR, single & multi-selection.
//

import Foundation
import UIKit
import Photos
import HXPhotoPicker

// MARK: - Notifications

public extension Notification.Name {
    /// userInfo: ["selectedAssets": [PHAsset], "selectedImages": [UIImage], "selectedAssetIdentifiers": [String]]
    static let PPPickerBridgeDidFinish = Notification.Name("PPPickerBridgeDidFinish")
    static let PPPickerBridgeDidCancel = Notification.Name("PPPickerBridgeDidCancel")
}

// MARK: - PPPickerBridge

@objc public class PPPickerBridge: NSObject {

    // MARK: - Configuration
    @objc public var useArabic: Bool = false
    @objc public var maxSelectionCount: Int = 9
    @objc public var maxVideoSelectionCount: Int = 1
    @objc public var maxVideoDuration: Int = 30
    @objc public var allowVideo: Bool = false
    @objc public var allowPhoto: Bool = true
    @objc public var allowSelectedOrder: Bool = true
    @objc public var buttonFont: UIFont?
    @objc public var bottomLabelFont: UIFont?
    @objc public var navigationTitleFont: UIFont?
    @objc public var navigationButtonFont: UIFont?
    @objc public var preselectedAssetIdentifiers: [String] = []

    // MARK: - Private State
    private var pickerController: PhotoPickerController?
    private var previousSemantic: UISemanticContentAttribute = .unspecified
    private var swiftCompletion: (([PHAsset], [UIImage]) -> Void)?

    @objc public override init() {
        super.init()
    }

    // MARK: - Quick Configurations

    @objc(configureForSinglePhoto)
    func configureForSinglePhoto() {
        maxSelectionCount = 1
        maxVideoSelectionCount = 0
        allowPhoto = true
        allowVideo = false
    }

    @objc(configureForSingleVideo)
    func configureForSingleVideo() {
        maxSelectionCount = 1
        maxVideoSelectionCount = 1
        allowPhoto = false
        allowVideo = true
    }

    @objc(configureForPhotosWithMaxCount:useArabic:)
    func configureForPhotos(maxCount: Int, useArabic: Bool) {
        maxSelectionCount = maxCount
        maxVideoSelectionCount = 0
        self.useArabic = useArabic
        allowPhoto = true
        allowVideo = false
    }

    @objc(configureForMixedMediaWithMaxCount:useArabic:)
    func configureForMixedMedia(maxCount: Int, useArabic: Bool) {
        maxSelectionCount = maxCount
        maxVideoSelectionCount = 1
        self.useArabic = useArabic
        allowPhoto = true
        allowVideo = true
    }

    // MARK: - Preselection

    @objc(preselectAssetsWithIdentifiers:)
    func preselectAssets(identifiers: [String]) {
        preselectedAssetIdentifiers = identifiers
    }

    @objc func clearPreselectedAssets() {
        preselectedAssetIdentifiers.removeAll()
    }

    private func localizedText(
        key: String,
        englishFallback: String,
        arabicFallback: String? = nil
    ) -> String {
        let localized = NSLocalizedString(key, comment: englishFallback)
        if localized != key {
            return localized
        }
        if useArabic {
            return arabicFallback ?? englishFallback
        }
        return englishFallback
    }

    private var directionalBackSymbolName: String {
        useArabic ? "chevron.right" : "chevron.left"
    }

    private func directionalBackImage() -> UIImage? {
        UIImage(systemName: directionalBackSymbolName)?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold))
            .withRenderingMode(.alwaysTemplate)
    }

    private func applyDirectionalHXImageResources() {
        HX.imageResource.picker.preview.back = .system(directionalBackSymbolName)
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

    // MARK: - Present Picker

    @objc(presentPickerFromViewController:)
    public func presentPicker(from viewController: UIViewController) {
        PhotoManager.shared.createLanguageBundle(languageType: useArabic ? .arabic : .english)
        applyCustomTextManager()
        applyDirectionalHXImageResources()

        let config = createPickerConfiguration()

        let picker = PhotoPickerController(picker: config)
        picker.pickerDelegate = self
        self.pickerController = picker

        // Present as sheet
        picker.modalPresentationStyle = .pageSheet

        // Force the back indicator to match the active language direction.
        let chevron = directionalBackImage()
        applyDirectionalBackIndicator(to: picker.navigationBar)

        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.backgroundColor = .systemBackground

            // Back indicator inherits from the appearance too
            appearance.setBackIndicatorImage(chevron, transitionMaskImage: chevron)

            if let titleFont = navigationTitleFont {
                appearance.titleTextAttributes = [.font: titleFont, .foregroundColor: UIColor.label]
            }
            if let btnFont = navigationButtonFont {
                let item = UIBarButtonItemAppearance()
                item.normal.titleTextAttributes = [.font: btnFont, .foregroundColor: UIColor.label]
                appearance.buttonAppearance = item

                let backItem = UIBarButtonItemAppearance()
                backItem.normal.titleTextAttributes = [.font: btnFont, .foregroundColor: UIColor.label]
                appearance.backButtonAppearance = backItem
            }

            picker.navigationBar.standardAppearance = appearance
            picker.navigationBar.scrollEdgeAppearance = appearance
            picker.navigationBar.compactAppearance = appearance
            picker.navigationBar.compactScrollEdgeAppearance = appearance
        }
        applyDirectionalBackIndicator(to: picker.navigationBar)

        previousSemantic = viewController.view.semanticContentAttribute
        let direction: UISemanticContentAttribute = useArabic ? .forceRightToLeft : .forceLeftToRight
        picker.view.semanticContentAttribute = direction
        picker.navigationBar.semanticContentAttribute = direction

        viewController.present(picker, animated: true) { [weak self, weak picker] in
            guard let self = self, let picker = picker else { return }
            self.applyDirectionalBackIndicator(to: picker.navigationBar)
        }
    }

    /// Swift-only convenience with completion handler.
    public func presentPicker(
        from viewController: UIViewController,
        completion: @escaping ([PHAsset], [UIImage]) -> Void
    ) {
        swiftCompletion = completion
        presentPicker(from: viewController)
    }

    /// Detailed Swift convenience.
    public func presentPicker(
        from viewController: UIViewController,
        maxCount: Int,
        allowVideo: Bool = false,
        useArabic: Bool = false,
        completion: @escaping ([PHAsset], [UIImage]) -> Void
    ) {
        maxSelectionCount = maxCount
        maxVideoSelectionCount = allowVideo ? 1 : 0
        self.allowVideo = allowVideo
        self.useArabic = useArabic
        presentPicker(from: viewController, completion: completion)
    }

    // MARK: - Configuration Builder

    /// Apply custom fonts and localized text to HXPhotoPicker's TextManager.
    private func applyCustomTextManager() {
        // Bottom toolbar fonts
        // Fonts arrive already scaled via UIFontMetrics from the caller — do NOT scale again.
        if let btnFont = buttonFont ?? navigationButtonFont {
            HX.textManager.picker.photoList.bottomView.previewTitleFont = btnFont
            HX.textManager.picker.photoList.bottomView.originalTitleFont = btnFont
            HX.textManager.picker.photoList.bottomView.finishTitleFont = btnFont
            HX.textManager.picker.photoList.bottomView.permissionsTitleFont = btnFont.withSize(btnFont.pointSize - 2)
            HX.textManager.picker.preview.bottomView.previewTitleFont = btnFont
            HX.textManager.picker.preview.bottomView.originalTitleFont = btnFont
            HX.textManager.picker.preview.bottomView.finishTitleFont = btnFont
            HX.textManager.picker.preview.bottomView.editTitleFont = btnFont
        }

        // Back button text (album list → photo list)
        let backText = localizedText(key: "Back", englishFallback: "Back", arabicFallback: "رجوع")
        HX.textManager.picker.albumList.backTitle = .custom(backText)

        // Cancel button text
        let cancelText = localizedText(key: "Cancel", englishFallback: "Cancel", arabicFallback: "إلغاء")
        HX.textManager.picker.preview.cancelTitle = .custom(cancelText)

        // Bottom toolbar button titles
        let finishText = localizedText(key: "Done", englishFallback: "Done", arabicFallback: "تم")
        let previewText = localizedText(key: "Preview", englishFallback: "Preview", arabicFallback: "عرض")
        let originalText = localizedText(key: "Original", englishFallback: "Original", arabicFallback: "أصلي")
        let editText = localizedText(key: "Edit", englishFallback: "Edit", arabicFallback: "تعديل")
        let videoDurationLimitText = localizedText(
            key: "media_video_duration_limit_message",
            englishFallback: "Videos must be 30 seconds or shorter.",
            arabicFallback: "يجب ألا تتجاوز مدة الفيديو ٣٠ ثانية."
        )

        HX.textManager.picker.photoList.bottomView.finishTitle = .custom(finishText)
        HX.textManager.picker.photoList.bottomView.previewTitle = .custom(previewText)
        HX.textManager.picker.photoList.bottomView.originalTitle = .custom(originalText)
        HX.textManager.picker.preview.bottomView.finishTitle = .custom(finishText)
        HX.textManager.picker.preview.bottomView.editTitle = .custom(editText)
        HX.textManager.picker.preview.bottomView.originalTitle = .custom(originalText)
        HX.textManager.picker.maximumSelectedVideoDurationHudTitle = .custom(videoDurationLimitText)
        HX.textManager.picker.maximumVideoEditDurationHudTitle = .custom(videoDurationLimitText)
    }

    private func createPickerConfiguration() -> PickerConfiguration {
        var config = PickerConfiguration()

        config.languageType = useArabic ? .arabic : .system
        config.appearanceStyle = .normal
        config.maximumSelectedCount = maxSelectionCount
        config.maximumSelectedVideoCount = allowVideo ? max(0, maxVideoSelectionCount) : 0
        config.maximumSelectedVideoDuration = allowVideo ? max(0, maxVideoDuration) : 0
        config.maximumVideoEditDuration = allowVideo ? max(0, maxVideoDuration) : 0

        config.selectOptions = []
        if allowPhoto { config.selectOptions.insert(.photo) }
        if allowVideo { config.selectOptions.insert(.video) }

        config.navigationTintColor = .label
        config.navigationDarkTintColor = .label
        config.navigationTitleColor = .label
        config.navigationTitleDarkColor = .label

        // Hide the "Original" button on the bottom toolbar
        config.photoList.bottomView.isHiddenOriginalButton = true
        config.previewView.bottomView.isHiddenOriginalButton = true
        config.editor.toolsView.toolOptions = pp_editorToolOptionsForCurrentMode()

        return config
    }

    private func pp_editorToolOptionsForCurrentMode() -> [EditorConfiguration.ToolsView.Options] {
        let options = EditorConfiguration.ToolsView.default.toolOptions
        return options.filter { option in
            switch option.type {
            case .chartlet:
                return false
            case .music:
                return !allowVideo
            default:
                return true
            }
        }
    }

    // MARK: - Result Handling

    private func handleSelectionResult(_ photoAssets: [PhotoAsset]) {
        let phAssets = photoAssets.compactMap { $0.phAsset }
        let images = photoAssets.compactMap { $0.originalImage }

        if let completion = swiftCompletion {
            completion(phAssets, images)
            swiftCompletion = nil
        }

        var userInfo: [AnyHashable: Any] = [:]
        userInfo["selectedAssets"] = phAssets
        userInfo["selectedImages"] = images
        userInfo["selectedAssetIdentifiers"] = phAssets.map { $0.localIdentifier }

        NotificationCenter.default.post(
            name: .PPPickerBridgeDidFinish,
            object: self,
            userInfo: userInfo
        )
    }
}

// MARK: - PhotoPickerControllerDelegate

extension PPPickerBridge: PhotoPickerControllerDelegate {

    public func pickerController(
        _ pickerController: PhotoPickerController,
        didFinishSelection result: PickerResult
    ) {
        handleSelectionResult(result.photoAssets)

        DispatchQueue.main.async {
            pickerController.dismiss(animated: true) {
                self.pickerController?.view.semanticContentAttribute = self.previousSemantic
                self.pickerController = nil
            }
        }
    }

    public func pickerController(didCancel pickerController: PhotoPickerController) {
        swiftCompletion = nil

        NotificationCenter.default.post(name: .PPPickerBridgeDidCancel, object: self)

        DispatchQueue.main.async {
            pickerController.dismiss(animated: true) {
                self.pickerController?.view.semanticContentAttribute = self.previousSemantic
                self.pickerController = nil
            }
        }
    }

    public func pickerController(
        _ pickerController: PhotoPickerController,
        didSelectAsset photoAsset: PhotoAsset,
        atIndex: Int
    ) { }

    public func pickerController(
        _ pickerController: PhotoPickerController,
        didUnselectAsset photoAsset: PhotoAsset,
        atIndex: Int
    ) { }

    #if HXPICKER_ENABLE_EDITOR
    public func pickerController(
        _ pickerController: PhotoPickerController,
        shouldEditPhotoAsset photoAsset: PhotoAsset,
        editorConfig: EditorConfiguration,
        atIndex: Int
    ) -> EditorConfiguration? {
        var config = editorConfig
        config.toolsView.toolOptions = pp_editorToolOptionsForCurrentMode()
        return config
    }

    public func pickerController(
        _ pickerController: PhotoPickerController,
        shouldEditVideoAsset videoAsset: PhotoAsset,
        editorConfig: EditorConfiguration,
        atIndex: Int
    ) -> EditorConfiguration? {
        var config = editorConfig
        config.toolsView.toolOptions = pp_editorToolOptionsForCurrentMode()
        return config
    }
    #endif
}

// MARK: - Notification Helpers (Objective-C)

@objc public extension PPPickerBridge {

    @objc static func imagesFromNotification(_ notification: Notification) -> [UIImage] {
        (notification.userInfo?["selectedImages"] as? [UIImage]) ?? []
    }

    @objc static func assetsFromNotification(_ notification: Notification) -> [PHAsset] {
        (notification.userInfo?["selectedAssets"] as? [PHAsset]) ?? []
    }

    @objc static func assetIdentifiersFromNotification(_ notification: Notification) -> [String] {
        (notification.userInfo?["selectedAssetIdentifiers"] as? [String]) ?? []
    }
}

// MARK: - PHAsset ↔ UIImage Helpers

@objc public extension PPPickerBridge {

    @objc static func imageFromAsset(_ asset: PHAsset, targetSize: CGSize) -> UIImage? {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact

        var result: UIImage?
        manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { img, _ in
            result = img
        }
        return result
    }

    @objc static func imageFromAssetAsync(
        _ asset: PHAsset,
        targetSize: CGSize,
        completion: @escaping (UIImage?) -> Void
    ) {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact

        manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { img, _ in
            completion(img)
        }
    }
}
