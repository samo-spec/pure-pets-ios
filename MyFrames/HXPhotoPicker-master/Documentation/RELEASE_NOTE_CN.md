# Update log
    
## 5.0.5

- Optimized and adapted to `iOS 26`

### Fix

- [[847]](https://github.com/SilenceLove/HXPhotoPicker/issues/847)
- [[840]](https://github.com/SilenceLove/HXPhotoPicker/issues/840)
- and some bugs...
    
## 5.0.4

- Compatible with `iOS 26`

### Fix

- [[820]](https://github.com/SilenceLove/HXPhotoPicker/issues/820)
- [[819]](https://github.com/SilenceLove/HXPhotoPicker/issues/819)
- and some bugs...
    
## 5.0.3

### New

- Picker
  - Added ability to control `LivePhoto` play/mute

### Fix

- [[809]](https://github.com/SilenceLove/HXPhotoPicker/issues/809)
- [[805]](https://github.com/SilenceLove/HXPhotoPicker/issues/805)
- [[803]](https://github.com/SilenceLove/HXPhotoPicker/issues/803)
- and some bugs...
    
## 5.0.2

### Fix

- [[797]](https://github.com/SilenceLove/HXPhotoPicker/issues/797)
- [[792]](https://github.com/SilenceLove/HXPhotoPicker/issues/792)

## 5.0.1

### New

- Spanish, Portuguese languages

### Fix

- [[787]](https://github.com/SilenceLove/HXPhotoPicker/issues/787) 
- [[784]](https://github.com/SilenceLove/HXPhotoPicker/issues/784)  
- [[782]](https://github.com/SilenceLove/HXPhotoPicker/issues/782) 
- [[777]](https://github.com/SilenceLove/HXPhotoPicker/issues/777)
- [[776]](https://github.com/SilenceLove/HXPhotoPicker/issues/776)
- [[775]](https://github.com/SilenceLove/HXPhotoPicker/issues/775)

## 5.0.0

- The minimum system version is changed to `iOS 10`
- GIF images are not supported by default, and network image loading supports customization [HXImageViewProtocol](https://github.com/SilenceLove/HXPhotoPicker/blob/master/Sources/HXPhotoPicker/Core/Config/HXImageViewProtocol.swift)
  - [GIF](https://github.com/SilenceLove/HXPhotoPicker/tree/master/Sources/ImageView/GIFImageView.swift)
  - [Kingfisher](https://github.com/SilenceLove/HXPhotoPicker/tree/master/Sources/ImageView/KFImageView.swift)
  - [SDWebImage](https://github.com/SilenceLove/HXPhotoPicker/tree/master/Sources/ImageView/SDImageView.swift)
- Optimize RLT layout
  
## 4.2.5

### Fix

- [[766]](https://github.com/SilenceLove/HXPhotoPicker/issues/766)
- [[754]](https://github.com/SilenceLove/HXPhotoPicker/issues/754)
- [[751]](https://github.com/SilenceLove/HXPhotoPicker/issues/751)

## 4.2.4

### New

- The minimum system version is upgraded to `iOS 13`
- `Kingfisher` upgraded to `8.0`

## 4.2.3.2

### Fix

- [[727]](https://github.com/SilenceLove/HXPhotoPicker/issues/727)
- [[730]](https://github.com/SilenceLove/HXPhotoPicker/issues/730)
- [[731]](https://github.com/SilenceLove/HXPhotoPicker/issues/731)
- [[732]](https://github.com/SilenceLove/HXPhotoPicker/issues/732)

## 4.2.3.1

### Fix

- picker
  - When permissions are restricted, the system album is not synchronized after updating

## 4.2.3

### New

- Camera
  - The camera interface supports custom `CameraViewControllerProtocol`

### Fix

- picker
  - System album may not be synchronized after deleting photos

- Editor
  - Rotation and mirroring may not work

## 4.2.2

### Fix

- [[705]](https://github.com/SilenceLove/HXPhotoPicker/issues/705)

## 4.2.1

### Fix

- [[691]](https://github.com/SilenceLove/HXPhotoPicker/issues/691)
- [[690]](https://github.com/SilenceLove/HXPhotoPicker/issues/690)
- [[686]](https://github.com/SilenceLove/HXPhotoPicker/issues/686)
- [[681]](https://github.com/SilenceLove/HXPhotoPicker/issues/681)

## 4.2.0

### New

- Privacy api adds .xcprivacy file

### Fix

- [[663]](https://github.com/SilenceLove/HXPhotoPicker/issues/663)
- [[660]](https://github.com/SilenceLove/HXPhotoPicker/issues/660)
- [[659]](https://github.com/SilenceLove/HXPhotoPicker/issues/659)

## 4.1.9

### Fix

- [[654]](https://github.com/SilenceLove/HXPhotoPicker/issues/654)
- [[653]](https://github.com/SilenceLove/HXPhotoPicker/issues/653)
- [[649]](https://github.com/SilenceLove/HXPhotoPicker/issues/649)
- [[647]](https://github.com/SilenceLove/HXPhotoPicker/issues/647)
- [[646]](https://github.com/SilenceLove/HXPhotoPicker/issues/646)
- [[644]](https://github.com/SilenceLove/HXPhotoPicker/issues/644)

## 4.1.8

### Fix

- [[642]](https://github.com/SilenceLove/HXPhotoPicker/issues/642)
- [[641]](https://github.com/SilenceLove/HXPhotoPicker/issues/641)
- [[640]](https://github.com/SilenceLove/HXPhotoPicker/issues/640)
- [[635]](https://github.com/SilenceLove/HXPhotoPicker/issues/635)
- [[634]](https://github.com/SilenceLove/HXPhotoPicker/issues/634)
- [[633]](https://github.com/SilenceLove/HXPhotoPicker/issues/633)

## 4.1.7

### Fix

- [[632]](https://github.com/SilenceLove/HXPhotoPicker/issues/632)
- [[598]](https://github.com/SilenceLove/HXPhotoPicker/issues/598)

## 4.1.6

### New

- All icons can be customized with `HX.ImageResource`
- All text content can be customized with `HX.TextManager`

- Picker
  - Set the theme color with one click `config.themeColor = .systemBlue`[[620]](https://github.com/SilenceLove/HXPhotoPicker/issues/620)
  - `PhotoAsset` adds `size` that can specify `UIImage` [[624]](https://github.com/SilenceLove/HXPhotoPicker/issues/624)
  ```
    /// targetSize: 指定imageSize
    /// targetMode: crop mode
    let image = try await photoAsset.image(targetSize: .init(width: 200, height: 200), targetMode: .fill)
  ```
  - `PhotoAsset` added to obtain content for display
  ```
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

- Camera
  - The camera screen size can be customized `config.aspectRatio = ._9x16`
  
### Fix

- Editor
  - After using the circular cropping frame and rotating the crop, the content is offset when entering the editing interface again.
  
### optimization

- Picker
  - Quick slide to display effects

## 4.1.5

### Fix

- [[618]](https://github.com/SilenceLove/HXPhotoPicker/issues/618)
- [[616]](https://github.com/SilenceLove/HXPhotoPicker/issues/616)
- [[614]](https://github.com/SilenceLove/HXPhotoPicker/issues/614)

## 4.1.4

### Fix

- [[613]](https://github.com/SilenceLove/HXPhotoPicker/issues/613)
- [[612]](https://github.com/SilenceLove/HXPhotoPicker/issues/612)
- [[610]](https://github.com/SilenceLove/HXPhotoPicker/issues/610)
- [[591]](https://github.com/SilenceLove/HXPhotoPicker/issues/591)

## 4.1.3

### Fix

- Picker
  - The list at the bottom of the preview interface may be messed up
- [[605]](https://github.com/SilenceLove/HXPhotoPicker/issues/605)
- [[599]](https://github.com/SilenceLove/HXPhotoPicker/issues/599)

## 4.1.2

### New

- Picker
  - `PhotoToolbar` of photo list supports displaying selected list view
  - Added list view of preview data in `PhotoToolbar` in preview interface

### Fix

- Picker
  - When the original image is selected, quickly selecting/deselecting photos may cause a crash.
  - When the album permissions restrict some photos, switching the album after selecting the photos causes the number displayed in the `PhotoToolbar` to be incorrect.
  - The album list may be blank
  - When the gif is displayed as a static image, the address suffix name is incorrectly obtained.
  - Modification of the judgment logic of the maximum number of choices
  
### optimization

- Picker
  - Alignment of safe area distance when `PhotoToolbar` is horizontally screened
  - The logic of loading images in the preview interface is optimized, and the images are clearer during initial loading.

## 4.1.1

### New

- Editor
  - Added `Highlight`, `Shadow`, `Color Temperature` effects to the picture adjustment
  
### Fix
    
- [[593]](https://github.com/SilenceLove/HXPhotoPicker/issues/593)
- [[589]](https://github.com/SilenceLove/HXPhotoPicker/issues/589)
- and some known issues

## 4.1.0

### New

- Editor
  - The sticker list supports customization and implements the protocol `EditorChartletListProtocol`

### Fix

- Picker
  - Multiple quick gestures to return may cause the interface to become unresponsive
  
- [[593]](https://github.com/SilenceLove/HXPhotoPicker/issues/593)
- [[592]](https://github.com/SilenceLove/HXPhotoPicker/issues/592)

## 4.0.9

### New

- Picker
  - Added new album list display method `present(UIModalPresentationStyle)`
  - Album list UI modification, supports customization, and implements the protocol `PhotoAlbumController`
  - The album list and photo list navigation bar buttons support customization and implement the protocol `PhotoNavigationItem`
  - `PhotoBrowser` adds new language configuration [[584]](https://github.com/SilenceLove/HXPhotoPicker/issues/584)
  - Add highlight state to button
  
### Fix

- Picker
  - There is no response when clicking `PhotoToolbar` on low version systems [[587]](https://github.com/SilenceLove/HXPhotoPicker/issues/587)
- Editor
    - Editing video crashes [[580]](https://github.com/SilenceLove/HXPhotoPicker/issues/580)
    - Rotation may crash while painting
- and fixed some minor issues

### optimization

- Optimized some codes

## 4.0.8

### New

- Picker
  - Support `UISplitViewController`, used by `iPad` by default
  - The photo album list supports customization and implements the protocol `PhotoAlbumList`
  - The photo list title bar supports customization and implements the protocol `PhotoPickerTitle`
  - The photo list view supports customization and implements the protocol `PhotoPickerList`

### Fix

- Fixed some minor issues

## 4.0.7

### New

- Picker
  - The bottom view of the photo list and preview interface supports customization. You only need to implement the methods in the `PhotoToolBar` protocol and assign it to the `photoToolbar` of the configuration class.
- Editor
  - The drawing function `iOS 13.0` and above is replaced by `PencilKit`

## 4.0.6

### New

- Editor
  - When the original ratio is selected, you can switch between horizontal and vertical states

### Fix

- Picker
  - When the album permission is not authorized, the cancellation callback is not triggered.
- Some issues on Mac Catalyst

### optimization

- The problem of long compilation time under Release [[564]](https://github.com/SilenceLove/HXPhotoPicker/issues/564)

## 4.0.5.1

### Fix

- Compilation error in lower versions of Xcode [[571]](https://github.com/SilenceLove/HXPhotoPicker/issues/571)

## 4.0.5

### New

- Picker
  - `NetworkImageAsset` adds `CacheKey` attribute
  - Obtaining URL supports specifying path

### optimization

- Picker
  - Gesture sliding selection is enabled by default, and the sliding selection function is optimized
- Editor
  - iPad interface layout adjustment

## 4.0.4

### New
  
- Editor
  - `config.buttonPostion` adds configuration: the position of the cancel/finish button when the screen is vertical
- Camera
  - `config.isSaveSystemAlbum` adds configuration: save to the system album after taking pictures

### optimization

- Picker
  - Preview interface gesture return optimization
- Editor 
  - Layout optimization

### Fix

- [[553]](https://github.com/SilenceLove/HXPhotoPicker/issues/553)
- [[558]](https://github.com/SilenceLove/HXPhotoPicker/issues/558)
- [[562]](https://github.com/SilenceLove/HXPhotoPicker/issues/562)
- [[567]](https://github.com/SilenceLove/HXPhotoPicker/issues/567)
- [[568]](https://github.com/SilenceLove/HXPhotoPicker/issues/568)

## 4.0.3

### New

- Picker
  - `PhotoManager.shared.isConverHEICToPNG = true` internally automatically converts HEIC format to PNG format
  - `config.isSelectedOriginal` controls whether the original image button is selected
  - `config.isDeselectVideoRemoveEdited` determines whether to clear the edited content when deselecting a video
  - When adding network resources, images support configuring `Kingfisher.ImageDownloader`:`PhotoManager.shared.imageDownloader`, and videos use `AVURLAsset` to set `options`

### optimization

- Picker
  - Internal logic optimization during `async/await` acquisition
  - Optimized sliding selection effect
- Editor
  - Angle ruler continuous sliding logic optimization

## 4.0.2

### New

- Picker
  - Add filtering function to photo list, `config.photoList.isShowFilterItem` controls whether to display filter button
  - The selected view at the bottom of the preview interface supports dragging to change its position.

### optimization

- Picker
  - When the photo format is `HEIC`, the suffix of the address for obtaining the original image remains the same.

### Fix

- Picker
  - The prompt when the photo list is empty does not wrap.
- Editor
  - The left and right 90° rotation completion callback is not triggered
  - When dragging the angle scale and scrolling has not stopped, clicking restore may not work.

## 4.0.1

### Fix

- Picker
  - When `disableFinishButtonWhenNotSelected` is set to `true` and the maximum number of videos is 1, the video cannot be selected in the preview interface
  - When selecting a video that exceeds the maximum duration in the preview interface, the maximum duration is not set when jumping to the editor, resulting in a looping editing logic.
- Editor
  - The video direction is not corrected when editing videos recorded by the system's original camera

## 4.0.0

- Written in pure Swift
- Fixed some issues
- Editor optimization and reconstruction

## 3.0

- [Object-C version](https://github.com/SilenceLove/HXPhotoPickerObjC)
