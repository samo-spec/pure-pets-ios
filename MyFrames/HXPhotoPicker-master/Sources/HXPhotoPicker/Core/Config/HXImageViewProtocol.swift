//
//  HXImageViewProtocol.swift
//  HXPhotoPickerExample
//
//  Created by Silence on 2025/2/21.
//  Copyright © 2025 Silence. All rights reserved.
//

import UIKit
import AVFoundation
#if canImport(SDWebImage)
import SDWebImage
#endif

/// GIF reference https://github.com/SilenceLove/HXPhotoPicker/tree/master/Sources/ImageView/GIFImageView.swift
/// Use `Kingfisher`
/// Reference https://github.com/SilenceLove/HXPhotoPicker/tree/master/Sources/ImageView/KFImageView.swift
/// PickerConfiguration.imageViewProtocol  = KFImageView.self
/// Use `SDWebImage`
/// Reference https://github.com/SilenceLove/HXPhotoPicker/tree/master/Sources/ImageView/SDImageView.swift
/// PickerConfiguration.imageViewProtocol  = SDImageView.self
public protocol HXImageViewProtocol: UIImageView {
    func setImageData(_ imageData: Data?)
    @discardableResult
    func setImage(with resource: ImageDownloadResource, placeholder: UIImage?, options: ImageDownloadOptionsInfo?, progressHandler: ((CGFloat) -> Void)?, completionHandler: ((Result<UIImage, ImageDownloadError>) -> Void)?) -> ImageDownloadTask?
    
    @discardableResult
    func setVideoCover(with url: URL, placeholder: UIImage?, completionHandler: ((Result<UIImage, ImageDownloadError>) -> Void)?) -> ImageDownloadTask?
    
    func _startAnimating()
    func _stopAnimating()
    
    @discardableResult
    static func download(with resource: ImageDownloadResource, options: ImageDownloadOptionsInfo?, progressHandler: ((CGFloat) -> Void)?, completionHandler: ((Result<ImageDownloadResult, ImageDownloadError>) -> Void)?) -> ImageDownloadTask?
    
    static func getCacheKey(forURL url: URL) -> String
    static func getCachePath(forKey key: String) -> String
    static func isCached(forKey key: String) -> Bool
    static func getInMemoryCacheImage(forKey key: String) -> UIImage?
    static func getCacheImage(forKey key: String, completionHandler: ((UIImage?) -> Void)?)
}

public extension HXImageViewProtocol {
    func setVideoCover(with url: URL, placeholder: UIImage?, completionHandler: ((Result<UIImage, ImageDownloadError>) -> Void)?) -> ImageDownloadTask? {
        weak var imageGenerator: AVAssetImageGenerator?
        let avAsset = PhotoTools.getVideoThumbnailImage(url: url, atTime: 0.1) {
            imageGenerator = $0
        } completion: { _, image, _ in
            guard let image else {
                completionHandler?(.failure(.error(nil)))
                return
            }
            completionHandler?(.success(image))
        }
        let task = ImageDownloadTask {
            avAsset.cancelLoading()
            imageGenerator?.cancelAllCGImageGeneration()
        }
        return task
    }
    
    func setImage(with resource: ImageDownloadResource, placeholder: UIImage?, options: ImageDownloadOptionsInfo?, progressHandler: ((CGFloat) -> Void)?, completionHandler: ((Result<UIImage, ImageDownloadError>) -> Void)?) -> ImageDownloadTask? {
        assertionFailure("Please implement this method to load network images")
        return nil
    }
    
    static func download(with resource: ImageDownloadResource, options: ImageDownloadOptionsInfo?, progressHandler: ((CGFloat) -> Void)?, completionHandler: ((Result<ImageDownloadResult, ImageDownloadError>) -> Void)?) -> ImageDownloadTask? {
        assertionFailure("Please implement this method to load network images")
        return nil
    }
    
    static func getCacheKey(forURL url: URL) -> String {
        assertionFailure("Please implement this method to load network images")
        return ""
    }
    
    static func getCachePath(forKey key: String) -> String {
        assertionFailure("Please implement this method to load network images")
        return ""
    }
    
    static func isCached(forKey key: String) -> Bool {
        assertionFailure("Please implement this method to load network images")
        return false
    }
    
    static func getInMemoryCacheImage(forKey key: String) -> UIImage? {
        assertionFailure("Please implement this method to load network images")
        return nil
    }
    
    static func getCacheImage(forKey key: String, completionHandler: ((UIImage?) -> Void)?) {
        assertionFailure("Please implement this method to load network images")
    }
}

public typealias ImageDownloadOptionsInfo = [ImageDownloadOptionsInfoItem]

public enum ImageDownloadOptionsInfoItem: Sendable {
    case onlyLoadFirstFrame
    case cacheOriginalImage
    case fade(TimeInterval)
    case imageProcessor(CGSize)
    case memoryCacheExpirationExpired
    case scaleFactor(CGFloat)
}

public struct ImageDownloadResource {
    public init(downloadURL: URL, cacheKey: String? = nil, indicatorColor: UIColor? = nil) {
        self.downloadURL = downloadURL
        self.cacheKey = cacheKey ?? PhotoManager.ImageView.getCacheKey(forURL: downloadURL)
        self.indicatorColor = indicatorColor
    }
    
    public let cacheKey: String
    public let downloadURL: URL
    public let indicatorColor: UIColor?
}

public enum ImageDownloadError: Error {
    case error(Error?)
    case cancel
}

public struct ImageDownloadTask {
    public let cancelHandler: () -> Void
    public init(cancelHandler: @escaping () -> Void) {
        self.cancelHandler = cancelHandler
    }
}

public struct ImageDownloadResult {
    public let image: UIImage?
    public let imageData: Data?
    
    public init(image: UIImage) {
        self.image = image
        self.imageData = nil
    }
    
    public init(imageData: Data) {
        self.image = nil
        self.imageData = imageData
    }
}

#if canImport(SDWebImage)
public class HXImageView: SDAnimatedImageView, HXImageViewProtocol {

    /// GIF reference https://github.com/SilenceLove/HXPhotoPicker/tree/master/Sources/ImageView/GIFImageView.swift
    public func setImageData(_ imageData: Data?) {
        guard let imageData else {
            image = nil
            return
        }
        if let animatedImage = SDAnimatedImage(data: imageData) {
            self.image = animatedImage
        } else {
            self.image = UIImage(data: imageData)
        }
    }

    @discardableResult
    public func setImage(with resource: ImageDownloadResource, placeholder: UIImage?, options: ImageDownloadOptionsInfo?, progressHandler: ((CGFloat) -> Void)?, completionHandler: ((Result<UIImage, ImageDownloadError>) -> Void)?) -> ImageDownloadTask? {
        var sdOptions: SDWebImageOptions = []
        var context: [SDWebImageContextOption: Any] = [:]
        if let options {
            for option in options {
                switch option {
                case .imageProcessor(let size):
                    let imageProcessor = SDImageResizingTransformer(size: size, scaleMode: .aspectFill)
                    context[.imageTransformer] = imageProcessor
                case .onlyLoadFirstFrame:
                    sdOptions.insert(.decodeFirstFrameOnly)
                case .memoryCacheExpirationExpired:
                    sdOptions.insert(.refreshCached)
                case .cacheOriginalImage, .fade, .scaleFactor:
                    break
                }
            }
        }
        sd_setImage(with: resource.downloadURL, placeholderImage: placeholder, options: sdOptions, context: context) { receivedSize, totalSize, _ in
            guard totalSize > 0 else { return }
            let progress = CGFloat(receivedSize) / CGFloat(totalSize)
            DispatchQueue.main.async {
                progressHandler?(progress)
            }
        } completed: { image, error, _, _ in
            if let image {
                completionHandler?(.success(image))
                return
            }
            if let error = error as NSError?, error.code == NSURLErrorCancelled {
                completionHandler?(.failure(.cancel))
                return
            }
            completionHandler?(.failure(.error(error)))
        }
        return ImageDownloadTask { [weak self] in
            self?.sd_cancelCurrentImageLoad()
        }
    }

    @discardableResult
    public static func download(with resource: ImageDownloadResource, options: ImageDownloadOptionsInfo?, progressHandler: ((CGFloat) -> Void)?, completionHandler: ((Result<ImageDownloadResult, ImageDownloadError>) -> Void)?) -> ImageDownloadTask? {
        var sdOptions: SDWebImageDownloaderOptions = []
        var context: [SDWebImageContextOption: Any] = [:]
        if let options {
            for option in options {
                switch option {
                case .imageProcessor(let size):
                    let imageProcessor = SDImageResizingTransformer(size: size, scaleMode: .aspectFill)
                    context[.imageTransformer] = imageProcessor
                case .onlyLoadFirstFrame:
                    sdOptions.insert(.decodeFirstFrameOnly)
                default:
                    break
                }
            }
        }
        let key = resource.cacheKey
        if HXImageView.isCached(forKey: key) {
            SDImageCache.shared.queryImage(forKey: key, options: [], context: nil) { image, data, _ in
                if let data {
                    completionHandler?(.success(.init(imageData: data)))
                } else if let image = image as? SDAnimatedImage, let data = image.animatedImageData {
                    completionHandler?(.success(.init(imageData: data)))
                } else if let image {
                    completionHandler?(.success(.init(image: image)))
                } else {
                    completionHandler?(.failure(.error(nil)))
                }
            }
            return nil
        }
        let operation = SDWebImageDownloader.shared.downloadImage(
            with: resource.downloadURL,
            options: sdOptions,
            context: context,
            progress: { receivedSize, totalSize, _ in
                guard totalSize > 0 else { return }
                let progress = CGFloat(receivedSize) / CGFloat(totalSize)
                DispatchQueue.main.async {
                    progressHandler?(progress)
                }
            },
            completed: { image, data, error, finished in
                guard finished, error == nil, let data else {
                    completionHandler?(.failure(.error(error)))
                    return
                }
                DispatchQueue.global(qos: .userInitiated).async {
                    let format = NSData.sd_imageFormat(forImageData: data)
                    if format == SDImageFormat.GIF, let gifImage = SDAnimatedImage(data: data) {
                        SDImageCache.shared.store(gifImage, imageData: data, forKey: key, options: [], context: nil, cacheType: .all) {
                            DispatchQueue.main.async {
                                completionHandler?(.success(.init(imageData: data)))
                            }
                        }
                        return
                    }
                    if let image {
                        SDImageCache.shared.store(image, imageData: data, forKey: key, options: [], context: nil, cacheType: .all) {
                            DispatchQueue.main.async {
                                completionHandler?(.success(.init(image: image)))
                            }
                        }
                    } else {
                        completionHandler?(.failure(.error(nil)))
                    }
                }
            }
        )
        return ImageDownloadTask {
            operation?.cancel()
        }
    }

    public func _startAnimating() {
        startAnimating()
    }

    public func _stopAnimating() {
        stopAnimating()
    }

    public static func getCacheKey(forURL url: URL) -> String {
        SDWebImageManager.shared.cacheKey(for: url) ?? ""
    }

    public static func getCachePath(forKey key: String) -> String {
        SDImageCache.shared.cachePath(forKey: key) ?? ""
    }

    public static func isCached(forKey key: String) -> Bool {
        FileManager.default.fileExists(atPath: getCachePath(forKey: key))
    }

    public static func getInMemoryCacheImage(forKey key: String) -> UIImage? {
        SDImageCache.shared.imageFromMemoryCache(forKey: key)
    }

    public static func getCacheImage(forKey key: String, completionHandler: ((UIImage?) -> Void)?) {
        SDImageCache.shared.queryImage(forKey: key, context: nil, cacheType: .all) { image, data, _ in
            if let data, let image = SDAnimatedImage(data: data) {
                completionHandler?(image)
            } else if let image {
                completionHandler?(image)
            } else {
                completionHandler?(nil)
            }
        }
    }
}
#else
public class HXImageView: UIImageView, HXImageViewProtocol {

    public func setImageData(_ imageData: Data?) {
        guard let imageData else { return }
        image = .init(data: imageData)
    }

    public func _startAnimating() {
    }

    public func _stopAnimating() {
    }
}
#endif
