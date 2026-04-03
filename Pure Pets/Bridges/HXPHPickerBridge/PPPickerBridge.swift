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
        let config = createPickerConfiguration()

        let picker = PhotoPickerController(picker: config)
        picker.pickerDelegate = self
        self.pickerController = picker

        picker.modalPresentationStyle = .fullScreen
        picker.navigationBar.backIndicatorImage = UIImage(systemName: "chevron.backward")
        picker.navigationBar.backIndicatorTransitionMaskImage = UIImage(systemName: "chevron.backward")

        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.backgroundColor = .systemBackground

            if let titleFont = navigationTitleFont {
                appearance.titleTextAttributes = [.font: titleFont, .foregroundColor: UIColor.label]
            }
            if let btnFont = navigationButtonFont {
                let item = UIBarButtonItemAppearance()
                item.normal.titleTextAttributes = [.font: btnFont, .foregroundColor: UIColor.label]
                appearance.buttonAppearance = item
                appearance.backButtonAppearance = item
            }

            picker.navigationBar.standardAppearance = appearance
            picker.navigationBar.scrollEdgeAppearance = appearance
            picker.navigationBar.compactAppearance = appearance
        }

        previousSemantic = viewController.view.semanticContentAttribute
        picker.view.semanticContentAttribute = useArabic ? .forceRightToLeft : .forceLeftToRight

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
