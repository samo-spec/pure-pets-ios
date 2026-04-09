//
//  PhotoManager.swift
// Photo picker-Swift
//
//  Created by Silence on 2019/6/29.
//  Copyright © 2019年 Silence. All rights reserved.
//

import UIKit
import Photos
import PhotosUI

public final class PhotoManager: NSObject {
    
    public static let shared = PhotoManager()
    
    /// Custom language
    public var customLanguages: [CustomLanguage] = []
    
    /// Whether it is currently in dark mode
    public static var isDark: Bool {
        if shared.appearanceStyle == .normal {
            return false
        }
        if shared.appearanceStyle == .dark {
            return true
        }
        if #available(iOS 13.0, *) {
            if UITraitCollection.current.userInterfaceStyle == .dark {
                return true
            }
        }
        return false
    }
    public static var HUDView: PhotoHUDProtocol.Type = ProgressHUD.self
    
    #if canImport(Kingfisher) && HXPICKER_ENABLE_CORE_IMAGEVIEW_KF
    public static var ImageView: HXImageViewProtocol.Type = KFImageView.self
    #elseif canImport(SDWebImage) && HXPICKER_ENABLE_CORE_IMAGEVIEW_SD
    public static var ImageView: HXImageViewProtocol.Type = SDImageView.self
    #elseif canImport(SwiftyGif) && HXPICKER_ENABLE_CORE_IMAGEVIEW_GIF
    public static var ImageView: HXImageViewProtocol.Type = GIFImageView.self
    #else
    public static var ImageView: HXImageViewProtocol.Type = HXImageView.self
    #endif
    
    #if DEBUG
    public var isDebugLogsEnabled: Bool = true
    #else
    public var isDebugLogsEnabled: Bool = false
    #endif
    
    /// Whether Arabic RTL layout
    public static var isRTL: Bool {
        guard let languageType = PhotoManager.shared.languageType else {
            return false
        }
        if languageType == .system {
            return PhotoManager.shared.languageStr == "ar"
        } else {
            return languageType == .arabic
        }
    }
    
    static let isIos26Compatibility: Bool = {
        guard #available(iOS 26, *) else {
            return true
        }
        guard let isCompatibility = Bundle.main.object(forInfoDictionaryKey: "UIDesignRequiresCompatibility") as? Bool else {
#if canImport(UIKit.UIGlassEffect)
            return false
#else
            return true
#endif
        }
        return isCompatibility
    }()
    
    /// Current language file, each time PhotoPickerController is created to determine whether it needs to be re-created
    var languageBundle: Bundle?
    /// Current language type, assigned each time PhotoPickerController is created
    var languageType: LanguageType?
    /// Current appearance style, assigned each time PhotoPickerController is created
    var appearanceStyle: AppearanceStyle = .varied
    
    /// Comes with bundle file
    var bundle: Bundle?
    /// Loading indicator type
    var indicatorType: IndicatorType = .system
    
    #if HXPICKER_ENABLE_PICKER
    public var pickerResultCompression: PhotoAsset.Compression? = nil
    
    /// How to load online video
    public var loadNetworkVideoMode: PhotoAsset.LoadNetworkVideoMode = .download
    
    var isCacheCameraAlbum: Bool = false {
        didSet {
            if isCacheCameraAlbum == oldValue {
                return
            }
            registerPhotoChangeObserver()
        }
    }
    var didRegisterObserver: Bool = false
    var firstLoadAssets: Bool = true
    var cameraAlbumResult: PHFetchResult<PHAsset>?
    var cameraAlbumResultOptions: PickerAssetOptions?
    var thumbnailLoadMode: ThumbnailLoadMode = .complete
    var pickerCaptureTime: TimeInterval = 0
    #endif
    
    #if HXPICKER_ENABLE_PICKER || HXPICKER_ENABLE_EDITOR
    var downloadSession: URLSession!
    var downloadTasks: [String: URLSessionDownloadTask] = [:]
    var downloadCompletions: [String: (URL?, Error?, Any?) -> Void] = [:]
    var downloadProgresss: [String: (Double, URLSessionDownloadTask) -> Void] = [:]
    var downloadFileURLs: [String: URL] = [:]
    var downloadExts: [String: Any] = [:]
    #endif
    
    #if HXPICKER_ENABLE_PICKER || HXPICKER_ENABLE_CAMERA
    var cameraPreviewImage: UIImage? = PhotoTools.getCameraPreviewImage()
    var sampleBuffer: CMSampleBuffer?
    func saveCameraPreview() {
        if let image = cameraPreviewImage {
            DispatchQueue.global().async {
                PhotoTools.saveCameraPreviewImage(image)
            }
        }
    }
    #endif
    
    let uuid: String = UUID().uuidString
    
    private override init() {
        super.init()
        
        #if HXPICKER_ENABLE_PICKER || HXPICKER_ENABLE_EDITOR
        downloadSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        #endif
        createBundle()
    }
    
    @discardableResult
    func createBundle() -> Bundle? {
        if self.bundle == nil {
            #if HXPICKER_ENABLE_SPM
            if let path = Bundle.module.path(forResource: "HXPhotoPicker", ofType: "bundle") {
                self.bundle = Bundle(path: path)
            }else {
                self.bundle = Bundle.main
            }
            #else
            let bundle = Bundle(for: HXPhotoPicker.self)
            var path = bundle.path(forResource: "HXPhotoPicker", ofType: "bundle")
            if path == nil {
                let associateBundleURL = Bundle.main.url(forResource: "Frameworks", withExtension: nil)
                if let url = associateBundleURL?
                    .appendingPathComponent("HXPhotoPicker")
                    .appendingPathExtension("framework") {
                    let associateBunle = Bundle(url: url)
                    path = associateBunle?.path(forResource: "HXPhotoPicker", ofType: "bundle")
                }
            }
            if let path = path {
                self.bundle = Bundle(path: path)
            }else {
                self.bundle = Bundle.main
            }
            #endif
        }
        return self.bundle
    }
}

#if HXPICKER_ENABLE_PICKER
extension NSNotification.Name {
    static let ThumbnailLoadModeDidChange: NSNotification.Name = .init("ThumbnailLoadModeDidChange")
}
public extension PhotoManager {
    enum ThumbnailLoadMode {
        case simplify
        case complete
    }
    func thumbnailLoadModeDidChange(
        _ mode: ThumbnailLoadMode
    ) {
        if thumbnailLoadMode == mode {
            return
        }
        thumbnailLoadMode = mode
    }
}
#endif
