//
//  PPPickerBridge.swift
//  PurePets
//
//  Created by ChatGPT.
//

import Foundation
import UIKit
import Photos

#if canImport(HXPHPicker)
import HXPHPicker
#elseif canImport(HXPhotoPicker)
import HXPhotoPicker
#endif

#if canImport(HXPHPicker) || canImport(HXPhotoPicker)

public extension Notification.Name {
    /// Notification posted when picker finishes. userInfo keys:
    /// - "selectedAssets": [PHAsset] array (for Objective-C)
    /// - "selectedImages": [UIImage] array (for images)
    static let PPPickerBridgeDidFinish = Notification.Name("PPPickerBridgeDidFinish")
    static let PPPickerBridgeDidCancel = Notification.Name("PPPickerBridgeDidCancel")
}

@objc public class PPPickerBridge: NSObject {
    
    // MARK: - Configuration Properties
    @objc public var useArabic: Bool = false
    @objc public var maxSelectionCount: Int = 9
    @objc public var allowVideo: Bool = false
    @objc public var allowPhoto: Bool = true
    @objc public var allowSelectedOrder: Bool = true
    @objc public var buttonFont: UIFont?
    @objc public var bottomLabelFont: UIFont?
    
    // For preselection
    @objc public var preselectedAssetIdentifiers: [String] = []
    
    // Internal properties
    private var pickerViewController: PhotoPickerViewController?
    private var pickerController: PhotoPickerController?
    
    private var previousSemantic: UISemanticContentAttribute = .unspecified
    @objc public var navigationTitleFont: UIFont?
    @objc public var navigationButtonFont: UIFont?
    
    @objc public override init() {
        super.init()
    }
    
    
    @objc(configureForSinglePhoto)
    func configureForSinglePhoto() {
        self.maxSelectionCount = 1
        self.allowPhoto = true
        self.allowVideo = false
    }

    @objc(configureForSingleVideo)
    func configureForSingleVideo() {
        self.maxSelectionCount = 1
        self.allowPhoto = false
        self.allowVideo = true
    }

    
    
    // MARK: - Present Picker
    @objc(presentPickerFromViewController:)
    public func presentPicker(from viewController: UIViewController) {
        // Create configuration
        let config = createPickerConfiguration()
        
        // Create picker controller
        let pickerController = PhotoPickerController(picker: config)
        pickerController.pickerDelegate = self
        self.pickerController = pickerController
        
        // Present
        pickerController.modalPresentationStyle = .fullScreen
        pickerController.navigationBar.backIndicatorImage =
            UIImage(systemName: "chevron.backward")
        pickerController.navigationBar.backIndicatorTransitionMaskImage =
            UIImage(systemName: "chevron.backward")
        
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.backgroundColor = UIColor.systemBackground

            if let titleFont = self.navigationTitleFont {
                appearance.titleTextAttributes = [
                    .font: titleFont,
                    .foregroundColor: UIColor.label
                ]
            }

            if let buttonFont = self.navigationButtonFont {
                let itemAppearance = UIBarButtonItemAppearance()
                itemAppearance.normal.titleTextAttributes = [
                    .font: buttonFont,
                    .foregroundColor: UIColor.label
                ]
                appearance.buttonAppearance = itemAppearance
                appearance.backButtonAppearance = itemAppearance
            }

            pickerController.navigationBar.standardAppearance = appearance
            pickerController.navigationBar.scrollEdgeAppearance = appearance
            pickerController.navigationBar.compactAppearance = appearance
        }
        
        self.previousSemantic = viewController.view.semanticContentAttribute
        pickerController.view.semanticContentAttribute = useArabic ? .forceRightToLeft : .forceLeftToRight
        
        viewController.present(pickerController, animated: true, completion: nil)
    }
    
    // MARK: - Swift-only API with completion
    public func presentPicker(
        from viewController: UIViewController,
        completion: @escaping ([PHAsset], [UIImage]) -> Void
    ) {
        self.swiftCompletion = completion
        presentPicker(from: viewController)
    }
    
    // MARK: - Private Methods
    private func createPickerConfiguration() -> PickerConfiguration {
        var config = PickerConfiguration()
        
        // Language
        config.languageType = useArabic ? .arabic : .system
        config.appearanceStyle = .normal
        // Removed: UIView.appearance().semanticContentAttribute = .forceLeftToRight
        
        // Selection limits
        config.maximumSelectedCount = maxSelectionCount
        config.maximumSelectedVideoCount = allowVideo ? maxSelectionCount : 0
        
        // Media types
        config.selectOptions = []
        if allowPhoto {
            config.selectOptions.insert(.photo)
        }
        if allowVideo {
            config.selectOptions.insert(.video)
        }
        config.navigationTintColor = UIColor.label
        config.navigationDarkTintColor = UIColor.label
        config.navigationTitleColor = UIColor.label
        config.navigationTitleDarkColor = UIColor.label
        
        // Selection order
        
        // Appearance customization
        if buttonFont != nil {
            // (removed commented lines)
        }
        
        // Bottom view configuration
        if bottomLabelFont != nil {
            // (removed commented lines)
        }
        
        // Preselection (if supported by this version)
        if !preselectedAssetIdentifiers.isEmpty {
            // Note: This depends on the specific HXPHPicker version
            // Some versions use preselectedAssets, others don't
             
        }
        
        return config
    }
    
    // MARK: - Swift Completion Handler
    private var swiftCompletion: (([PHAsset], [UIImage]) -> Void)?
    
    // MARK: - Handle Selection Result
    private func handleSelectionResult(_ photoAssets: [PhotoAsset]) {
        // Convert PhotoAssets to PHAssets and UIImages
        let phAssets = photoAssets.compactMap { $0.phAsset }
        let images = photoAssets.compactMap { $0.originalImage }
        
        // Call Swift completion if set
        if let swiftCompletion = swiftCompletion {
            swiftCompletion(phAssets, images)
            self.swiftCompletion = nil
        }
        
        // Post notification for Objective-C
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
    public func pickerController(_ pickerController: PhotoPickerController, didFinishSelection result: PickerResult) {
        // Get selected photo assets
        let selectedAssets = result.photoAssets
        
        // Handle the result
        handleSelectionResult(selectedAssets)
        
        // Dismiss
        DispatchQueue.main.async {
            pickerController.dismiss(animated: true) {
                self.pickerController?.view.semanticContentAttribute = self.previousSemantic
                self.pickerController = nil
            }
        }
    }
    
    public func pickerController(didCancel pickerController: PhotoPickerController) {
        // Clear Swift completion
        swiftCompletion = nil
        
        // Post cancellation notification
        NotificationCenter.default.post(
            name: .PPPickerBridgeDidCancel,
            object: nil
        )
        
        // Dismiss
        DispatchQueue.main.async {
            pickerController.dismiss(animated: true) {
                self.pickerController?.view.semanticContentAttribute = self.previousSemantic
                self.pickerController = nil
            }
        }
    }
    
    // Optional delegate methods
    public func pickerController(
        _ pickerController: PhotoPickerController,
        didSelectAsset photoAsset: PhotoAsset,
        atIndex: Int
    ) {
        _ = pickerController
        _ = photoAsset
        _ = atIndex
    }
    
    public func pickerController(
        _ pickerController: PhotoPickerController,
        didUnselectAsset photoAsset: PhotoAsset,
        atIndex: Int
    ) {
        _ = pickerController
        _ = photoAsset
        _ = atIndex
    }
}

// MARK: - Objective-C Convenience Methods
@objc public extension PPPickerBridge {
    /// Quick configuration for photos only
    /// - Parameters:
    ///   - maxCount: Maximum number of photos to select
    ///   - useArabic: Whether to use Arabic interface
    @objc(configureForPhotosWithMaxCount:useArabic:)
    func configureForPhotos(maxCount: Int, useArabic: Bool) {
        self.maxSelectionCount = maxCount
        self.useArabic = useArabic
        self.allowPhoto = true
        self.allowVideo = false
    }
    
    /// Quick configuration for mixed media (photos + videos)
    /// - Parameters:
    ///   - maxCount: Maximum number of items to select
    ///   - useArabic: Whether to use Arabic interface
    @objc(configureForMixedMediaWithMaxCount:useArabic:)
    func configureForMixedMedia(maxCount: Int, useArabic: Bool) {
        self.maxSelectionCount = maxCount
        self.useArabic = useArabic
        self.allowPhoto = true
        self.allowVideo = true
    }
    
    /// Preselect assets by their local identifiers
    /// - Parameter identifiers: Array of PHAsset local identifiers
    @objc(preselectAssetsWithIdentifiers:)
    func preselectAssets(identifiers: [String]) {
        self.preselectedAssetIdentifiers = identifiers
    }
    
    /// Clear all preselected assets
    @objc func clearPreselectedAssets() {
        self.preselectedAssetIdentifiers.removeAll()
    }
}

// MARK: - Notification Helpers (Objective-C)
@objc public extension PPPickerBridge {
    /// Get UIImage array from notification userInfo
    /// - Parameter notification: Notification object
    /// - Returns: Array of UIImages
    @objc static func imagesFromNotification(_ notification: Notification) -> [UIImage] {
        guard let userInfo = notification.userInfo,
              let images = userInfo["selectedImages"] as? [UIImage] else {
            return []
        }
        return images
    }
    
    /// Get PHAsset array from notification userInfo
    /// - Parameter notification: Notification object
    /// - Returns: Array of PHAssets
    @objc static func assetsFromNotification(_ notification: Notification) -> [PHAsset] {
        guard let userInfo = notification.userInfo,
              let assets = userInfo["selectedAssets"] as? [PHAsset] else {
            return []
        }
        return assets
    }
    
    /// Get asset identifiers from notification userInfo
    /// - Parameter notification: Notification object
    /// - Returns: Array of asset identifiers
    @objc static func assetIdentifiersFromNotification(_ notification: Notification) -> [String] {
        guard let userInfo = notification.userInfo,
              let identifiers = userInfo["selectedAssetIdentifiers"] as? [String] else {
            return []
        }
        return identifiers
    }
}

// MARK: - Swift Convenience Extension
public extension PPPickerBridge {
    /// Present picker with detailed configuration
    /// - Parameters:
    ///   - viewController: Presenting view controller
    ///   - maxCount: Maximum selection count
    ///   - allowVideo: Whether to allow video selection
    ///   - useArabic: Language setting
    ///   - completion: Completion handler with selected assets and images
    func presentPicker(
        from viewController: UIViewController,
        maxCount: Int,
        allowVideo: Bool = false,
        useArabic: Bool = false,
        completion: @escaping ([PHAsset], [UIImage]) -> Void
    ) {
        self.maxSelectionCount = maxCount
        self.allowVideo = allowVideo
        self.useArabic = useArabic
        self.presentPicker(from: viewController, completion: completion)
    }
}

// MARK: - PHAsset to UIImage Helper
@objc public extension PPPickerBridge {
    /// Convert PHAsset to UIImage synchronously
    /// - Parameters:
    ///   - asset: PHAsset to convert
    ///   - targetSize: Target size for the image
    /// - Returns: UIImage or nil
    @objc static func imageFromAsset(_ asset: PHAsset, targetSize: CGSize) -> UIImage? {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        
        var resultImage: UIImage?
        
        manager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            resultImage = image
        }
        
        return resultImage
    }
    
    /// Convert PHAsset to UIImage asynchronously
    /// - Parameters:
    ///   - asset: PHAsset to convert
    ///   - targetSize: Target size for the image
    ///   - completion: Completion handler with UIImage
    @objc static func imageFromAssetAsync(
        _ asset: PHAsset,
        targetSize: CGSize,
        completion: @escaping (UIImage?) -> Void
    ) {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        
        manager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            completion(image)
        }
    }
}

#else

public extension Notification.Name {
    static let PPPickerBridgeDidFinish = Notification.Name("PPPickerBridgeDidFinish")
    static let PPPickerBridgeDidCancel = Notification.Name("PPPickerBridgeDidCancel")
}

@objc public class PPPickerBridge: NSObject {
    @objc public var useArabic: Bool = false
    @objc public var maxSelectionCount: Int = 9
    @objc public var allowVideo: Bool = false
    @objc public var allowPhoto: Bool = true
    @objc public var allowSelectedOrder: Bool = true
    @objc public var buttonFont: UIFont?
    @objc public var bottomLabelFont: UIFont?
    @objc public var preselectedAssetIdentifiers: [String] = []
    @objc public var navigationTitleFont: UIFont?
    @objc public var navigationButtonFont: UIFont?

    @objc public override init() {
        super.init()
    }

    @objc(configureForSinglePhoto)
    func configureForSinglePhoto() {
        self.maxSelectionCount = 1
        self.allowPhoto = true
        self.allowVideo = false
    }

    @objc(configureForSingleVideo)
    func configureForSingleVideo() {
        self.maxSelectionCount = 1
        self.allowPhoto = false
        self.allowVideo = true
    }

    @objc(presentPickerFromViewController:)
    public func presentPicker(from viewController: UIViewController) {
        _ = viewController
        NotificationCenter.default.post(name: .PPPickerBridgeDidCancel, object: nil)
    }

    public func presentPicker(
        from viewController: UIViewController,
        completion: @escaping ([PHAsset], [UIImage]) -> Void
    ) {
        _ = viewController
        completion([], [])
        NotificationCenter.default.post(name: .PPPickerBridgeDidCancel, object: nil)
    }

    @objc(setPreselectedAssetsFromIdentifiers:)
    func setPreselectedAssets(identifiers: [String]) {
        self.preselectedAssetIdentifiers = identifiers
    }

    @objc(clearPreselectedAssets)
    func clearPreselectedAssets() {
        self.preselectedAssetIdentifiers.removeAll()
    }
}

@objc public extension PPPickerBridge {
    @objc static func imagesFromNotification(_ notification: Notification) -> [UIImage] {
        guard let userInfo = notification.userInfo,
              let images = userInfo["selectedImages"] as? [UIImage] else {
            return []
        }
        return images
    }

    @objc static func assetsFromNotification(_ notification: Notification) -> [PHAsset] {
        guard let userInfo = notification.userInfo,
              let assets = userInfo["selectedAssets"] as? [PHAsset] else {
            return []
        }
        return assets
    }

    @objc static func assetIdentifiersFromNotification(_ notification: Notification) -> [String] {
        guard let userInfo = notification.userInfo,
              let identifiers = userInfo["selectedAssetIdentifiers"] as? [String] else {
            return []
        }
        return identifiers
    }
}

public extension PPPickerBridge {
    func presentPicker(
        from viewController: UIViewController,
        maxCount: Int,
        allowVideo: Bool = false,
        useArabic: Bool = false,
        completion: @escaping ([PHAsset], [UIImage]) -> Void
    ) {
        self.maxSelectionCount = maxCount
        self.allowVideo = allowVideo
        self.useArabic = useArabic
        self.presentPicker(from: viewController, completion: completion)
    }
}

@objc public extension PPPickerBridge {
    @objc static func imageFromAsset(_ asset: PHAsset, targetSize: CGSize) -> UIImage? {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact

        var resultImage: UIImage?
        manager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            resultImage = image
        }
        return resultImage
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

        manager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            completion(image)
        }
    }
}

#endif

   
