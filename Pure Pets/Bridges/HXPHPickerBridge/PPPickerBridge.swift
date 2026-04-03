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
        allowPhoto = true
        allowVideo = false
    }

    @objc(configureForSingleVideo)
    func configureForSingleVideo() {
        maxSelectionCount = 1
        allowPhoto = false
        allowVideo = true
    }

    @objc(configureForPhotosWithMaxCount:useArabic:)
    func configureForPhotos(maxCount: Int, useArabic: Bool) {
        maxSelectionCount = maxCount
        self.useArabic = useArabic
        allowPhoto = true
        allowVideo = false
    }

    @objc(configureForMixedMediaWithMaxCount:useArabic:)
    func configureForMixedMedia(maxCount: Int, useArabic: Bool) {
        maxSelectionCount = maxCount
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

    // MARK: - Present Picker

    @objc(presentPickerFromViewController:)
    public func presentPicker(from viewController: UIViewController) {
        applyCustomTextManager()

        let config = createPickerConfiguration()

        let picker = PhotoPickerController(picker: config)
        picker.pickerDelegate = self
        self.pickerController = picker

        // Present as sheet
        picker.modalPresentationStyle = .pageSheet

        // Back indicator: use chevron.left always — UIKit auto-mirrors it for RTL
        let chevron = UIImage(systemName: "chevron.left")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold))
        picker.navigationBar.backIndicatorImage = chevron
        picker.navigationBar.backIndicatorTransitionMaskImage = chevron

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
        }

        previousSemantic = viewController.view.semanticContentAttribute
        let direction: UISemanticContentAttribute = useArabic ? .forceRightToLeft : .forceLeftToRight
        picker.view.semanticContentAttribute = direction
        picker.navigationBar.semanticContentAttribute = direction

        viewController.present(picker, animated: true)
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
        self.allowVideo = allowVideo
        self.useArabic = useArabic
        presentPicker(from: viewController, completion: completion)
    }

    // MARK: - Configuration Builder

    /// Apply custom fonts and localized text to HXPhotoPicker's TextManager.
    private func applyCustomTextManager() {
        // Bottom toolbar fonts
        if let btnFont = buttonFont ?? navigationButtonFont {
            let regular = UIFontMetrics.default.scaledFont(for: btnFont)
            HX.textManager.picker.photoList.bottomView.previewTitleFont = regular
            HX.textManager.picker.photoList.bottomView.originalTitleFont = regular
            HX.textManager.picker.photoList.bottomView.finishTitleFont = regular
            HX.textManager.picker.photoList.bottomView.permissionsTitleFont = UIFontMetrics.default.scaledFont(
                for: btnFont.withSize(btnFont.pointSize - 2)
            )
            HX.textManager.picker.preview.bottomView.previewTitleFont = regular
            HX.textManager.picker.preview.bottomView.originalTitleFont = regular
            HX.textManager.picker.preview.bottomView.finishTitleFont = regular
            HX.textManager.picker.preview.bottomView.editTitleFont = regular
        }

        // Back button text (album list → photo list)
        let backText = useArabic ? "رجوع" : "Back"
        HX.textManager.picker.albumList.backTitle = .custom(backText)

        // Cancel button text
        let cancelText = useArabic ? "الغاء" : "Cancel"
        HX.textManager.picker.preview.cancelTitle = .custom(cancelText)

        // Bottom toolbar button titles
        let finishText = useArabic ? "انهاء" : "Done"
        let previewText = useArabic ? "عرض" : "Preview"
        let originalText = useArabic ? "الاصليه" : "Original"

        HX.textManager.picker.photoList.bottomView.finishTitle = .custom(finishText)
        HX.textManager.picker.photoList.bottomView.previewTitle = .custom(previewText)
        HX.textManager.picker.photoList.bottomView.originalTitle = .custom(originalText)
        HX.textManager.picker.preview.bottomView.finishTitle = .custom(finishText)
        HX.textManager.picker.preview.bottomView.editTitle = .custom(useArabic ? "تعديل" : "Edit")
        HX.textManager.picker.preview.bottomView.originalTitle = .custom(originalText)
    }

    private func createPickerConfiguration() -> PickerConfiguration {
        var config = PickerConfiguration()

        config.languageType = useArabic ? .arabic : .system
        config.appearanceStyle = .normal
        config.maximumSelectedCount = maxSelectionCount
        config.maximumSelectedVideoCount = allowVideo ? maxSelectionCount : 0

        config.selectOptions = []
        if allowPhoto { config.selectOptions.insert(.photo) }
        if allowVideo { config.selectOptions.insert(.video) }

        config.navigationTintColor = .label
        config.navigationDarkTintColor = .label
        config.navigationTitleColor = .label
        config.navigationTitleDarkColor = .label

        return config
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
            object: nil,
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

        NotificationCenter.default.post(name: .PPPickerBridgeDidCancel, object: nil)

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
