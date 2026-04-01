//
//  PPCoreBridge.swift
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

/// Lightweight Swift core utilities. Only ObjC-safe APIs are marked @objc.
/// Swift-only helpers remain internal (not exposed to Objective-C).
@objc public class PPCoreBridge: NSObject {

    /// control Arabic or English usage for HXPHPicker
    @objc public var useArabic: Bool = false

    public override init() {
        super.init()
    }

    // ObjC-safe: ask the bridge to ensure HXPhotoPicker language bundle is prepared.
    // This returns void (ObjC safe) and internally calls the Swift enums.
    @objc public func preparePickerLanguageBundle() {
        let lang: LanguageType = useArabic ? .arabic : .english
        PhotoManager.shared.createLanguageBundle(languageType: lang)
    }

    // ObjC-safe convenience: convert UIImages to PhotoAsset array for use inside Swift-only code.
    // This method is NOT marked @objc because PhotoAsset is a Swift type (not ObjC representable).
    // Use the Swift-only helper below from Swift callers.
    internal func convertImagesToAssets(_ images: [UIImage]) -> [PhotoAsset] {
        return images.map { PhotoAsset(localImageAsset: .init(image: $0)) }
    }

    // Swift-only helper to expose a language enum for internal Swift usage.
    internal func browserLanguage() -> LanguageType {
        return useArabic ? .arabic : .system
    }
}

#else

@objc public class PPCoreBridge: NSObject {
    @objc public var useArabic: Bool = false

    public override init() {
        super.init()
    }

    @objc public func preparePickerLanguageBundle() {
        // HX picker module unavailable in this build context.
    }
}

#endif
