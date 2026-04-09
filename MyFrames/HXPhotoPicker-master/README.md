<h4 align="right">中文 | <strong><a href="https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/README_EN.md">English</a></strong></h4>
      
<p align="center">
    <a><img src="https://github.com/SilenceLove/PictureMaterial/blob/main/HXPhotoPicker/README/sample_graph.png?raw=true"  width = "384" height = "292.65" ></a>
</p>
<p align="center">
    <a href="https://github.com/SilenceLove/HXPhotoPicker"><img src="https://travis-ci.org/SilenceLove/HXPhotoPicker.svg?branch=master"></a>
    <a href="https://github.com/SilenceLove/HXPhotoPicker"><img src="https://badgen.net/badge/icon/iOS%2010.0%2B?color=cyan&icon=apple&label"></a>
    <a href="https://github.com/SilenceLove/HXPhotoPicker"><img src="http://img.shields.io/cocoapods/v/HXPhotoPicker.svg?logo=cocoapods&logoColor=ffffff"></a>
    <a href="https://developer.apple.com/Swift"><img src="http://img.shields.io/badge/language-Swift-orange.svg?logo=common-workflow-language"></a>
    <a href="http://mit-license.org"><img src="http://img.shields.io/badge/license-MIT-333333.svg?logo=letterboxd&logoColor=ffffff"></a>
    <div align="center">A picture/video selector - supports LivePhoto, GIF selection, iCloud/network resource online download, picture/video editing</div>
</p>

## Table of contents
*[function](#function)
* [request](#requirement)
* [Install](#install)
* [Example](#example)
    * [Quick use](#example)
    * [How to support GIF/Internet pictures](#How to support GIF/Internet pictures)
    * [How to get](#How to get)
* [Update record](#Update record)
* [Demo effect](# Demonstration effect)
* [Interface display](#Interface display)
* [Support❤️](#support❤️)

## <a id="function"></a> function

- [x] UI appearance supports light/dark/auto/custom
- [x] Support multiple selection/mixed content selection
- [x] Supported media types:
    - [x] Photo
    - [x] GIF
    - [x] Live Photo
    - [x] Video
- [x] Supported local resource types:
    - [x] Photo
    - [x] Video
    - [x] GIF
    - [x] Live Photo
- [x] Supported network resource types:
    - [x] Photo
    - [x] Video
- [x] Support downloading resources on iCloud
- [x] Support gesture return
- [x] Support sliding selection
- [x] Edit pictures (support animated pictures and network resources)
    - [x] Graffiti
    - [x] Stickers
    - [x] text
    - [x] Crop
    - [x] rotate to any angle
    - [x] Custom masks
    - [x] Mosaic
    - [x] Screen adjustment
    - [x] filters
- [x] Edit video (support network resources)
    - [x] Graffiti
    - [x] Stickers (GIF supported)
    - [x] text
    - [x] Soundtrack (supports lyrics and subtitles)
    - [x] Cropping duration
    - [x] crop size
    - [x] rotate to any angle
    - [x] Custom masks
    - [x] Screen adjustment
    - [x] filters
- [x] Album display method
    - [x] separate list
    - [x] Pop-up window
- [x] Multi-platform support
    - [x] iOS
    - [x] iPadOS
    - [x] Mac Catalyst
- [x] Internationalization support
    - [x] 🇨🇳 Simplified Chinese (zh-Hans)
    - [x] 🇨🇳 Traditional Chinese (zh-Hant)
    - [x] 🇬🇧 English (en)
    - [x] 🇯🇵 Japanese (ja)
    - [x] 🇰🇷 Korean (ko)
    - [x] 🇹🇭 Thai (th)
    - [x] 🇮🇳 Indonesian (id)
    - [x] 🇻🇳 Vietnamese (vi)
    - [x] 🇷🇺 Russia (ru)
    - [x] 🇩🇪 Germany (de)
    - [x] 🇫🇷 France (fr)
    - [x] 🇸🇦 Arabic (ar)
    - [x] ✍️ Custom language (custom)
    - [ ] 🤝 More support... (PR welcome)

## <a id="requirement"></a> requirement

- iOS 10.0+
- Xcode 12.5+
- Swift 5.4+

## <a id="install"></a> Install

### [Swift Package Manager](https://swift.org/package-manager/)

⚠️ Requires Xcode 13.0 and above to support the addition of resource files/localization files.

```swift
dependencies: [
    .package(url: "https://github.com/SilenceLove/HXPhotoPicker.git", .upToNextMajor(from: "5.0.5"))
]
```

### [CocoaPods](https://guides.cocoapods.org/using/using-cocoapods.html)

Add the following content to `Podfile` and perform dependency updates.

```swift

/// iOS 10.0+ does not support GIF and network images by default
pod 'HXPhotoPicker'

/// Use `SwiftyGif` to load GIF images
pod 'HXPhotoPicker/SwiftyGif'

/// Use `SDWebImage` to load GIF/network images
pod 'HXPhotoPicker/SDWebImage'

/// Use `Kingfisher v6.0.0` to load GIF/network images
pod 'HXPhotoPicker/Kingfisher'

/// The camera does not contain positioning function
pod `HXPhotoPicker/NoLocation`

/// Only selector
pod `HXPhotoPicker/Picker`

/// Editor only
pod `HXPhotoPicker/Editor`

/// Only camera
pod `HXPhotoPicker/Camera`
/// Does not include positioning function
pod `HXPhotoPicker/Camera/Lite`

ObjC versions below v4.0
pod 'HXPhotoPickerObjC'
```

### Preparation

Add the following keys to your Info.plist as needed:

| Key | Module | Remarks |
| ----- | ----  | ---- |
| NSPhotoLibraryUsageDescription | Picker | Allow access to photo album |
| NSPhotoLibraryAddUsageDescription | Picker | Allow saving pictures to album |
| PHPhotoLibraryPreventAutomaticLimitedAccessAlert | Picker | Set to `YES` iOS 14+ to disable the automatic pop-up of the pop-up box for adding more photos (Picker has been adapted to the Limited function, which can be actively triggered by the user to improve the user experience) |
| NSCameraUsageDescription | Camera | Allow camera use |
| NSMicrophoneUsageDescription | Camera | Allow microphone use |

### <a id="example"></a> Get started quickly
```swift
import HXPhotoPicker

class ViewController: UIViewController {

    func presentPickerController() {
        //Set configuration consistent with WeChat theme
        let config = PickerConfiguration.default
        
        //Method 1: async/await
        // Use `Photo`
        let images: [UIImage] = try await Photo.picker(config)
        let urls: [URL] = try await Photo.picker(config)
        let urlResult: [AssetURLResult] = try await Photo.picker(config)
        let assetResult: [AssetResult] = try await Photo.picker(config)
        // Use `PhotoPickerController`
        let images: [UIImage] = try await PhotoPickerController.picker(config)
        let urls: [URL] = try await PhotoPickerController.picker(config)
        let urlResult: [AssetURLResult] = try await PhotoPickerController.picker(config)
        let assetResult: [AssetResult] = try await PhotoPickerController.picker(config)
        
        let pickerResult = try await Photo.picker(config)
        let images: [UIImage] = try await pickerResult.objects()
        let urls: [URL] = try await pickerResult.objects()
        let urlResults: [AssetURLResult] = try await pickerResult.objects()
        let assetResults: [AssetResult] = try await pickerResult.objects()
        
        //Method 2:
        let pickerController = PhotoPickerController(picker: config)
        pickerController.pickerDelegate = self
        // Array of PhotoAsset objects corresponding to the currently selected resource
        pickerController.selectedAssetArray = selectedAssets 
        // Whether to select the original image
        pickerController.isOriginal = isOriginal
        present(pickerController, animated: true, completion: nil)
        
        //Method 3:
        Photo.picker(
            config
        ) { result, pickerController in
            //Select completed callback
            // result select result
            // .photoAssets currently selected data
            // .isOriginal determines whether the original image is selected
            //PhotoPickerController corresponding photo selection controller
        } cancel: { pickerController in
            // Cancel callback
            //PhotoPickerController corresponding photo selection controller
        }
    }
}

extension ViewController: PhotoPickerControllerDelegate {
    
    /// Called after selection is completed
    /// - Parameters:
    /// - pickerController: corresponding PhotoPickerController
    /// - result: selected result
    /// result.photoAssets selected resource array
    /// result.isOriginal determines whether the original image is selected
    func pickerController(
        _ pickerController: PhotoPickerController, 
        didFinishSelection result: PickerResult
    ) {
        // async/await
        let images: [UIImage] = try await result.objects()
        let urls: [URL] = try await result.objects()
        let urlResults: [AssetURLResult] = try await result.objects()
        let assetResults: [AssetResult] = try await result.objects()
        
        result.getImage { (image, photoAsset, index) in
            if let image = image {
                print("success", image)
            }else {
                print("failed")
            }
        } completionHandler: { (images) in
            print(images)
        }
    }
    
    /// Called when cancel is clicked
    /// - Parameter pickerController: corresponding PhotoPickerController
    func pickerController(didCancel pickerController: PhotoPickerController) {
        
    }
}
```

### <a id="How to support GIF/network pictures"></a> How to support GIF/network pictures [HXImageViewProtocol](https://github.com/SilenceLove/HXPhotoPicker/tree/master/Sources/HXPhotoPicker/Core/Config/HXImageViewProtocol.swift)

<details>
  <summary><strong><a href="https://github.com/SilenceLove/HXPhotoPicker/tree/master/Sources/ImageView/GIFImageView.swift">SwiftyGif</a> </strong></summary>
  
```swift
PickerConfiguration.imageViewProtocol = GIFImageView.self

public class GIFImageView: UIImageView, HXImageViewProtocol {
    public func setImageData(_ imageData: Data?) {
        guard let imageData else {
            clear()
            SwiftyGifManager.defaultManager.deleteImageView(self)
            image = nil
            return
        }
        if let image = try? UIImage(gifData: imageData) {
            setGifImage(image)
        }else {
            image = .init(data: imageData)
        }
    }
    
    public func _startAnimating() {
        startAnimatingGif()
    }
    
    public func _stopAnimating() {
        stopAnimatingGif()
    }
}
```

</details>

<details>
  <summary><strong><a href="https://github.com/SilenceLove/HXPhotoPicker/tree/master/Sources/ImageView/SDImageView.swift">SDWebImage</a></strong></summary>
  
```swift
PickerConfiguration.imageViewProtocol = SDImageView.self

public class SDImageView: SDAnimatedImageView, HXImageViewProtocol {
    public func setImageData(_ imageData: Data?) {
        guard let imageData else { return }
        let image = SDAnimatedImage(data: imageData)
        self.image = image
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
            let progress = CGFloat(receivedSize) / CGFloat(totalSize)
            DispatchQueue.main.async {
                progressHandler?(progress)
            }
        } completed: { image, error, cacheType, sourceURL in
            if let image {
                completionHandler?(.success(image))
            }else {
                if let error = error as? NSError, error.code == NSURLErrorCancelled {
                    completionHandler?(.failure(.cancel))
                    return
                }
                completionHandler?(.failure(.error(error)))
            }
        }
        let downloadTask = ImageDownloadTask { [weak self] in
            self?.sd_cancelCurrentImageLoad()
        }
        return downloadTask
    }
    
    @discardableResult
    public func setVideoCover(with url: URL, placeholder: UIImage?, completionHandler: ((Result<UIImage, ImageDownloadError>) -> Void)?) -> ImageDownloadTask? {
        let cacheKey = url.absoluteString
        if SDImageView.isCached(forKey: cacheKey) {
            SDImageCache.shared.queryImage(forKey: cacheKey, options: [], context: nil) { (image, data, _) in
                if let image {
                    completionHandler?(.success(image))
                }else {
                    completionHandler?(.failure(.error(nil)))
                }
            }
            return nil
        }
        var imageGenerator: AVAssetImageGenerator?
        let avAsset = PhotoTools.getVideoThumbnailImage(url: url, atTime: 0.1) {
            imageGenerator = $0
        } completion: { _, image, _ in
            guard let image else {
                completionHandler?(.failure(.error(nil)))
                return
            }
            SDImageCache.shared.store(image, imageData: nil, forKey: cacheKey, cacheType: .all) {
                DispatchQueue.main.async {
                    completionHandler?(.success(image))
                }
            }
        }
        let task = ImageDownloadTask {
            avAsset.cancelLoading()
            imageGenerator?.cancelAllCGImageGeneration()
        }
        return task
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
        if SDImageView.isCached(forKey: key) {
            SDImageCache.shared.queryImage(forKey: key, options: [], context: nil) { (image, data, _) in
                if let data = data  {
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
                let progress = CGFloat(receivedSize) / CGFloat(totalSize)
                DispatchQueue.main.async {
                    progressHandler?(progress)
                }
            },
            completed: { image, data, error, finished in
                guard let data = data, finished, error == nil else {
                    completionHandler?(.failure(.error(error)))
                    return
                }
                DispatchQueue.global().async {
                    let format = NSData.sd_imageFormat(forImageData: data)
                    if format == SDImageFormat.GIF, let gifImage = SDAnimatedImage(data: data) {
                        SDImageCache.shared.store(gifImage, imageData: data, forKey: key, options: [], context: nil, cacheType: .all) {
                            DispatchQueue.main.async {
                                completionHandler?(.success(.init(imageData: data)))
                            }
                        }
                        return
                    }
                    if let image = image {
                        SDImageCache.shared.store(image, imageData: data, forKey: key, options: [], context: nil, cacheType: .all) {
                            DispatchQueue.main.async {
                                completionHandler?(.success(.init(image: image)))
                            }
                        }
                    }
                }
            }
        )
        let downloadTask = ImageDownloadTask {
            operation?.cancel()
        }
        return downloadTask
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
            }else if let image {
                completionHandler?(image)
            }else {
                completionHandler?(nil)
            }
        }
    }
}
```

</details>

<details>
  <summary><strong><a href="https://github.com/SilenceLove/HXPhotoPicker/tree/master/Sources/ImageView/KFImageView.swift">Kingfisher(v6.0.0)</a></strong></summary>
  
```swift
PickerConfiguration.imageViewProtocol = KFImageView.self

public class KFImageView: AnimatedImageView, HXImageViewProtocol {
    public func setImageData(_ imageData: Data?) {
        guard let imageData else { return }
        let image: KFCrossPlatformImage? = DefaultImageProcessor.default.process(item: .data(imageData), options: .init([]))
        self.image = image
    }
    
    @discardableResult
    public func setImage(with resource: ImageDownloadResource, placeholder: UIImage?, options: ImageDownloadOptionsInfo?, progressHandler: ((CGFloat) -> Void)?, completionHandler: ((Result<UIImage, ImageDownloadError>) -> Void)?) -> ImageDownloadTask? {
        var kfOptions: KingfisherOptionsInfo = []
        if let options {
            for option in options {
                switch option {
                case .fade(let duration):
                    kfOptions += [.transition(.fade(duration))]
                case .imageProcessor(let size):
                    let imageProcessor = DownsamplingImageProcessor(size: size)
                    kfOptions += [.processor(imageProcessor)]
                case .onlyLoadFirstFrame:
                    kfOptions += [.onlyLoadFirstFrame]
                case .cacheOriginalImage:
                    kfOptions += [.cacheOriginalImage]
                case .memoryCacheExpirationExpired:
                    kfOptions += [.memoryCacheExpiration(.expired)]
                case .scaleFactor(let scale):
                    kfOptions += [.scaleFactor(scale)]
                }
            }
        }
        let imageResource = Kingfisher.ImageResource(downloadURL: resource.downloadURL, cacheKey: resource.cacheKey)
        if let indicatorColor = resource.indicatorColor {
            kf.indicatorType = .activity
            (kf.indicator?.view as? UIActivityIndicatorView)?.color = indicatorColor
        }
        let task = kf.setImage(with: imageResource, placeholder: placeholder, options: kfOptions) { receivedSize, totalSize in
            progressHandler?(CGFloat(receivedSize) / CGFloat(totalSize))
        } completionHandler: {
            switch $0 {
            case .success(let result):
                completionHandler?(.success(result.image))
            case .failure(let error):
                completionHandler?(.failure(error.isTaskCancelled ? .cancel : .error(error)))
            }
        }
        let downloadTask = ImageDownloadTask {
            task?.cancel()
        }
        return downloadTask
    }
    
    public func setVideoCover(with url: URL, placeholder: UIImage?, completionHandler: ((Result<UIImage, ImageDownloadError>) -> Void)?) -> ImageDownloadTask? {
        let provider = AVAssetImageDataProvider(assetURL: url, seconds: 0.1)
        provider.assetImageGenerator.appliesPreferredTrackTransform = true
        let task = KF.dataProvider(provider)
            .placeholder(placeholder)
            .onSuccess { result in
                completionHandler?(.success(result.image))
            }
            .onFailure { error in
                completionHandler?(.failure(error.isTaskCancelled ? .cancel : .error(error)))
            }
            .set(to: self)
        let downloadTask = ImageDownloadTask {
            task?.cancel()
        }
        return downloadTask
    }
    
    @discardableResult
    public static func download(with resource: ImageDownloadResource, options: ImageDownloadOptionsInfo?, progressHandler: ((CGFloat) -> Void)?, completionHandler: ((Result<ImageDownloadResult, ImageDownloadError>) -> Void)?) -> ImageDownloadTask? {
        let key = resource.cacheKey
        var kfOptions: KingfisherOptionsInfo = []
        if let options {
            for option in options {
                switch option {
                case .fade(let duration):
                    kfOptions += [.transition(.fade(duration))]
                case .imageProcessor(let size):
                    let imageProcessor = DownsamplingImageProcessor(size: size)
                    kfOptions += [.processor(imageProcessor)]
                case .onlyLoadFirstFrame:
                    kfOptions += [.onlyLoadFirstFrame]
                case .cacheOriginalImage:
                    kfOptions += [.cacheOriginalImage]
                case .memoryCacheExpirationExpired:
                    kfOptions += [.memoryCacheExpiration(.expired)]
                case .scaleFactor(let scale):
                    kfOptions += [.scaleFactor(scale)]
                }
            }
        }
        if ImageCache.default.isCached(forKey: key) {
            ImageCache.default.retrieveImage(
                forKey: key,
                options: kfOptions
            ) { (result) in
                switch result {
                case .success(let value):
                    if let data = value.image?.kf.gifRepresentation() {
                        completionHandler?(.success(.init(imageData: data)))
                    }else if let image = value.image {
                        completionHandler?(.success(.init(image: image)))
                    }else {
                        completionHandler?(.failure(.error(nil)))
                    }
                case .failure(let error):
                    completionHandler?(.failure(.error(error)))
                }
            }
            return nil
        }
        let task =  ImageDownloader.default.downloadImage(with: resource.downloadURL, options: kfOptions) { receivedSize, totalSize in
            let progress = CGFloat(receivedSize) / CGFloat(totalSize)
            progressHandler?(progress)
        } completionHandler: {
            switch $0 {
            case .success(let value):
                DispatchQueue.global().async {
                    if let gifImage = DefaultImageProcessor.default.process(
                        item: .data(value.originalData),
                        options: .init([])
                    ) {
                        ImageCache.default.store(
                            gifImage,
                            original: value.originalData,
                            forKey: key
                        )
                        DispatchQueue.main.async {
                            completionHandler?(.success(.init( imageData: value.originalData)))
                        }
                        return
                    }
                    ImageCache.default.store(
                        value.image,
                        original: value.originalData,
                        forKey: key
                    )
                    DispatchQueue.main.async {
                        completionHandler?(.success(.init(image: value.image)))
                    }
                }
            case .failure(let error):
                completionHandler?(.failure(.error(error)))
            }
        }
        let downloadTask = ImageDownloadTask {
            task?.cancel()
        }
        return downloadTask
    }
    
    public func _startAnimating() {
        startAnimating()
    }
    
    public func _stopAnimating() {
        stopAnimating()
    }
    
    public static func getCacheKey(forURL url: URL) -> String {
        url.cacheKey
    }
    
    public static func getCachePath(forKey key: String) -> String {
        ImageCache.default.cachePath(forKey: key)
    }
    
    public static func isCached(forKey key: String) -> Bool {
        ImageCache.default.isCached(forKey: key)
    }
    
    public static func getInMemoryCacheImage(forKey key: String) -> UIImage? {
        ImageCache.default.retrieveImageInMemoryCache(forKey: key)
    }
    
    public static func getCacheImage(forKey key: String, completionHandler: ((UIImage?) -> Void)?) {
        ImageCache.default.retrieveImage(forKey: key, options: []) {
            switch $0 {
            case .success(let result):
                completionHandler?(result.image)
            case .failure:
                completionHandler?(nil)
            }
        }
    }
}
```

</details>


### <a id="How to get"></a> How to get

#### Get UIImage

```swift
/// If it is a video, the video cover is obtained.
// async/await
// compression: compression parameter, if not passed, no compression will occur
let image: UIImage = try await photoAsset.object(compression)

/// Get the `UIImage` of the specified `Size`
/// targetSize: 指定imageSize
/// targetMode: crop mode
let image = try await photoAsset.image(targetSize: .init(width: 200, height: 200), targetMode: .fill)

// compressionQuality: compression parameter, if not passed, no compression will occur
photoAsset.getImage(compressionQuality: compressionQuality) { image in
    print(image)
}
```

#### Get URL

```swift
// async/await 
// compression: compression parameter, if not passed, no compression will occur
let url: URL = try await photoAsset.object(compression)
let urlResult: AssetURLResult = try await photoAsset.object(compression)

// compression: compression parameter, if not passed, no compression will occur
photoAsset.getURL(compression: compression) { result in
    switch result {
    case .success(let urlResult):
        // media type
        switch urlResult.mediaType {
        case .photo:
            // picture
        case .video:
            // video
        }
        
        // url type
        switch urlResult.urlType {
        case .local:
            // local URL
        case .network:
            // Network URL
        }
        
        //Get the address
        print(urlResult.url)
        
        // Picture and video urls contained in LivePhoto
        print(urlResult.livePhoto) 
        
    case .failure(let error):
        print(error)
    }
}
```

#### Get other

```swift
/// Get thumbnail
let thumImage = try await photoAsset.requesThumbnailImage()

/// Get preview image
let previewImage = try await photoAsset.requestPreviewImage()

/// Get AVAsset
let avAsset = try await photoAsset.requestAVAsset()

/// Get AVPlayerItem
let playerItem = try await photoAsset.requestPlayerItem()

/// Get PHLivePhoto
let livePhoto = try await photoAsset.requestLivePhoto()
```

## <a id="Update record"></a> Update log

<details open id="Latest Update">
  <summary><strong>Latest updates</strong></summary>
  
| Version | Release Date | Xcode | Swift | iOS |
| ---- | ----  | ---- | ---- | ---- |
| [v5.0.5](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/RELEASE_NOTE_CN.md#505) | 2025-12-01 | 26.0.0 | 6.0.0 | 10.0+ | 

</details>

<details id="history">
  <summary><strong>History</strong></summary>
  
| Version | Release Date | Xcode | Swift | iOS |
| ---- | ----  | ---- | ---- | ---- |
| [v5.0.4](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/RELEASE_NOTE_CN.md#504) | 2025-09-19 | 26.0.0 | 6.0.0 | 10.0+ | 
| [v5.0.3](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/RELEASE_NOTE_CN.md#503) | 2025-07-03 | 16.2.0 | 6.0.0 | 10.0+ | 
| [v5.0.2](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/RELEASE_NOTE_CN.md#502) | 2025-05-21 | 16.2.0 | 6.0.0 | 10.0+ | 
| [v5.0.1](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/RELEASE_NOTE_CN.md#501) | 2025-03-31 | 16.0.0 | 6.0.0 | 10.0+ | 
| [v5.0.0](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/RELEASE_NOTE_CN.md#500) | 2025-03-03 | 16.0.0 | 6.0.0 | 10.0+ | 
| [v4.2.5](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/RELEASE_NOTE_CN.md#425) | 2025-02-12 | 16.0.0 | 6.0.0 | 13.0+ | 
| [v4.2.4](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/RELEASE_NOTE_CN.md#424) | 2024-12-14 | 16.0.0 | 6.0.0 | 13.0+ | 
| [v4.2.3](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/RELEASE_NOTE_CN.md#423) | 2024-08-05 | 16.0.0 | 6.0.0 | 12.0+ | 
| [v4.2.2](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/RELEASE_NOTE_CN.md#422) | 2024-07-08 | 15.0.0 | 5.9.0 | 12.0+ | 
| [v4.2.1](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/RELEASE_NOTE_CN.md#421) | 2024-05-18 | 15.0.0 | 5.9.0 | 12.0+ | 
| [v4.2.0](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/RELEASE_NOTE_CN.md#420) | 2024-04-23 | 15.0.0 | 5.9.0 | 12.0+ | 
| [v4.1.9](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/RELEASE_NOTE_CN.md#419) | 2024-04-09 | 15.0.0 | 5.9.0 | 12.0+ | 
| [v4.1.8](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/RELEASE_NOTE_CN.md#418) | 2024-03-24 | 15.0.0 | 5.9.0 | 12.0+ | 
| [v4.1.7](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/RELEASE_NOTE_CN.md#417) | 2024-03-09 | 15.0.0 | 5.9.0 | 12.0+ | 
| [v4.1.6](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/RELEASE_NOTE_CN.md#416) | 2024-02-16 | 15.0.0 | 5.9.0 | 12.0+ | 
| [v4.1.5](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/RELEASE_NOTE_CN.md#415) | 2024-01-10 | 15.0.0 | 5.9.0 | 12.0+ | 
| [v4.1.4](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/RELEASE_NOTE_CN.md#414) | 2023-12-24 | 15.0.0 | 5.9.0 | 12.0+ | 
| [v4.1.3](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/RELEASE_NOTE_CN.md#413) | 2023-12-16 | 15.0.0 | 5.9.0 | 12.0+ | 
| [v4.1.2](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/RELEASE_NOTE_CN.md#412) | 2023-12-02 | 15.0.0 | 5.9.0 | 12.0+ | 
| [v4.1.1](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/RELEASE_NOTE_CN.md#411) | 2023-11-14 | 15.0.0 | 5.9.0 | 12.0+ | 
| [v4.1.0](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/RELEASE_NOTE_CN.md#410) | 2023-11-07 | 15.0.0 | 5.9.0 | 12.0+ | 
| [v4.0.9](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/RELEASE_NOTE_CN.md#409) | 2023-10-22 | 15.0.0 | 5.9.0 | 12.0+ |
| [v4.0.8](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/RELEASE_NOTE_CN.md#408) | 2023-10-13 | 15.0.0 | 5.9.0 | 12.0+ |
| [v4.0.7](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/RELEASE_NOTE_CN.md#407) | 2023-09-23 | 14.3.0 | 5.7.0 | 12.0+ |
| [v4.0.6](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/RELEASE_NOTE_CN.md#406) | 2023-09-09 | 14.3.0 | 5.7.0 | 12.0+ |
| [v4.0.5](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/RELEASE_NOTE_CN.md#405) | 2023-08-12 | 14.3.0 | 5.7.0 | 12.0+ |
| [v4.0.4](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/RELEASE_NOTE_CN.md#404) | 2023-07-30 | 14.3.0 | 5.7.0 | 12.0+ |
| [v4.0.3](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/RELEASE_NOTE_CN.md#403) | 2023-07-06 | 14.3.0 | 5.7.0 | 12.0+ |
| [v4.0.2](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/RELEASE_NOTE_CN.md#402) | 2023-06-24 | 14.3.0 | 5.7.0 | 12.0+ |
| [v4.0.1](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/RELEASE_NOTE_CN.md#401) | 2023-06-17 | 14.3.0 | 5.7.0 | 12.0+ |
| [v4.0.0](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Documentation/RELEASE_NOTE_CN.md#400) | 2023-06-15 | 14.3.0 | 5.7.0 | 12.0+ |
| [v3.0.0](https://github.com/SilenceLove/HXPhotoPickerObjC#-%E6%9B%B4%E6%96%B0%E8%AE%B0%E5%BD%95---update-history) | 2022-09-18 | 14.0.0 | ----- | 8.0+ | 

</details>

## <a id="Demo effect"></a> Demo effect

| Select photo | Picture editing | Video editing |
| ---- | ----  | ---- |
| [![IMAGE ALT TEXT](https://github.com/SilenceLove/PictureMaterial/blob/main/HXPhotoPicker/README/Videos/photo_list_picker_cover.png?raw=true)](http://oss-cn-hangzhou.aliyuncs.com/tsnrhapp/shop/videos/83862ab94facfd8979eb6148094908b2.mp4) | [![IMAGE ALT TEXT](https://github.com/SilenceLove/PictureMaterial/blob/main/HXPhotoPicker/README/Videos/photo_editor_cover.png?raw=true)](http://oss-cn-hangzhou.aliyuncs.com/tsnrhapp/shop/videos/3c81199474e33006e2cebd5f6241ead5.mp4) | [![IMAGE ALT TEXT](https://github.com/SilenceLove/PictureMaterial/blob/main/HXPhotoPicker/README/Videos/video_editor_cover.png?raw=true)](http://oss-cn-hangzhou.aliyuncs.com/tsnrhapp/shop/videos/8c1cf86f32329e6464d327781f15041a.mp4) | 

## <a id="Interface display"></a> Interface display

| <img src="https://github.com/SilenceLove/PictureMaterial/blob/main/HXPhotoPicker/README/Photos/sample_graph_photo_picker_list.png?raw=true"> | <img src="https://github.com/SilenceLove/PictureMaterial/blob/main/HXPhotoPicker/README/Photos/sample_graph_photo_preview.png?raw=true"> | <img src="https://github.com/SilenceLove/PictureMaterial/blob/main/HXPhotoPicker/README/Photos/sample_graph_photo_editor_filter.png?raw=true"> | 
| ---- | ----  | ---- |
| <img src="https://github.com/SilenceLove/PictureMaterial/blob/main/HXPhotoPicker/README/Photos/sample_graph_video_editor_time.png?raw=true"> | <img src="https://github.com/SilenceLove/PictureMaterial/blob/main/HXPhotoPicker/README/Photos/sample_graph_video_editor_edit.png?raw=true"> | <img src="https://github.com/SilenceLove/PictureMaterial/blob/main/HXPhotoPicker/README/Photos/sample_graph_video_editor_crop_size.png?raw=true"> |

| <img src="https://github.com/SilenceLove/PictureMaterial/blob/main/HXPhotoPicker/README/Photos/sample_graph_photo_editor_crop_size_horizontal_screen.png?raw=true"> | <img src="https://github.com/SilenceLove/PictureMaterial/blob/main/HXPhotoPicker/README/Photos/sample_graph_video_editor_crop_size_horizontal_screen.png?raw=true"> |
| ---- | ----  |

## Copyright Agreement
HXPhotoPicker is distributed and used under the MIT license, see [license file](./LICENSE) for more information.

## <a id="Support❤️"></a> Support❤️
* [**★ Star**](#)
*Support the author☕️
    
<div align="left"><a href="https://www.buymeacoffee.com/fengye" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" ></a></div> 

| <img src="https://github.com/SilenceLove/PictureMaterial/blob/main/HXPhotoPicker/Support/bmc_qr.png?raw=true" width = "135" height = "135" /> | <img src="https://github.com/SilenceLove/PictureMaterial/blob/main/HXPhotoPicker/Support/ap.jpeg?raw=true" width = "100" height = "135.75" />   | <img src="https://github.com/SilenceLove/PictureMaterial/blob/main/HXPhotoPicker/Support/wp.jpeg?raw=true" width = "100" height = "135.75" /> |
| ------ | ------ | ------ | 

[![Stargazers over time](https://starchart.cc/SilenceLove/HXPhotoPicker.svg)](https://starchart.cc/SilenceLove/HXPhotoPicker)


[🔝Back to top](#readme)
