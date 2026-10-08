//
//  PPCoreBridge.swift
//  PurePets
//
//  Core utilities bridging HXPHPicker (Swift) to Objective-C.
//

import Foundation
import UIKit
import Photos
#if canImport(HXPHPicker)
import HXPHPicker
#elseif canImport(HXPhotoPicker)
import HXPhotoPicker
#endif

@objc public class PPCoreBridge: NSObject {

    @objc public var useArabic: Bool = false

    public override init() {
        super.init()
    }

    /// Prepare HXPHPicker language bundle for Arabic or English.
    @objc public func preparePickerLanguageBundle() {
        let lang: LanguageType = useArabic ? .arabic : .english
        PhotoManager.shared.createLanguageBundle(languageType: lang)
    }

    /// Convert UIImages to PhotoAsset array (Swift-only, not ObjC-representable).
    internal func convertImagesToAssets(_ images: [UIImage]) -> [PhotoAsset] {
        return images.map { PhotoAsset(localImageAsset: .init(image: $0)) }
    }

    /// Current language type based on useArabic flag.
    internal func currentLanguage() -> LanguageType {
        return useArabic ? .arabic : .english
    }

    /// Apply RTL/LTR semantic attribute to a view hierarchy.
    @objc public func applyLayoutDirection(to view: UIView) {
        view.semanticContentAttribute = useArabic ? .forceRightToLeft : .forceLeftToRight
    }
}
