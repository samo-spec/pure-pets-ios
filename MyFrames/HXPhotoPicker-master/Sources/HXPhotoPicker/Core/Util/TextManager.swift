//
//  TextManager.swift
//  HXPhotoPicker
//
//  Created by Silence on 2024/2/4.
//  Copyright © 2024 Silence. All rights reserved.
//

import UIKit

public extension HX {
    
    static var textManager: TextManager { .shared }
    
    class TextManager {
        public static let shared = TextManager()
        
        #if HXPICKER_ENABLE_PICKER || HXPICKER_ENABLE_CAMERA
        /// selector
        public var picker: Picker = .init()
        /// camera
        public var camera: Camera = .init()
        
        public var cameraNotAuthorized: CameraNotAuthorized = .init()
        #endif
        
        #if HXPICKER_ENABLE_EDITOR || HXPICKER_ENABLE_EDITOR_VIEW
        /// Editor
        public var editor: Editor = .init()
        #endif
    }
}

public extension HX.TextManager {
    
    enum TextType {
        /// Internal localization
        case localized(String)
        /// Display directly, not localized
        case custom(String)
        
        var text: String {
            switch self {
            case .localized(let text):
                return text.localized
            case .custom(let text):
                return text
            }
        }
    }
    
    #if HXPICKER_ENABLE_PICKER || HXPICKER_ENABLE_CAMERA
    struct Picker {
        /// The album is not authorized
        public var notAuthorized: NotAuthorized = .init()
        
        /// Cancel button in the navigation bar of album list and photo list interface
        public var navigationCancelTitle: TextType = .localized("取消")
        public var navigationCancelTitleFont: UIFont = HXPickerWrapper<UIFont>.mediumPingFang(ofSize: 17)
        
        /// All albums
        public var albumCameraRollTitle: TextType = .localized("HXAlbumCameraRoll")
        /// Panoramic photo
        public var albumPanoramasTitle: TextType = .localized("HXAlbumPanoramas")
        /// video
        public var albumVideosTitle: TextType = .localized("HXAlbumVideos")
        /// Personal collection
        public var albumFavoritesTitle: TextType = .localized("HXAlbumFavorites")
        /// Time-lapse photography
        public var albumTimelapsesTitle: TextType = .localized("HXAlbumTimelapses")
        /// Recent projects
        public var albumRecentsTitle: TextType = .localized("HXAlbumRecents")
        /// Recently added
        public var albumRecentlyAddedTitle: TextType = .localized("HXAlbumRecentlyAdded")
        /// Continuous snapshots
        public var albumBurstsTitle: TextType = .localized("HXAlbumBursts")
        /// slow motion
        public var albumSlomoVideosTitle: TextType = .localized("HXAlbumSlomoVideos")
        /// Selfie
        public var albumSelfPortraitsTitle: TextType = .localized("HXAlbumSelfPortraits")
        /// Screenshot
        public var albumScreenshotsTitle: TextType = .localized("HXAlbumScreenshots")
        /// Portrait
        public var albumDepthEffectTitle: TextType = .localized("HXAlbumDepthEffect")
        /// Live photos
        public var albumLivePhotosTitle: TextType = .localized("HXAlbumLivePhotos")
        /// GIF
        public var albumAnimatedTitle: TextType = .localized("HXAlbumAnimated")
        
        public var photoTogetherSelectHudTitle: TextType = .localized("Photos and videos cannot be selected at the same time")
        public var videoTogetherSelectHudTitle: TextType = .localized("Videos and photos cannot be selected at the same time")
        public var maximumSelectedPhotoHudTitle: TextType = .localized("Only %d photos can be selected at most")
        public var maximumSelectedVideoHudTitle: TextType = .localized("Only %d videos can be selected at most")
        public var maximumSelectedHudTitle: TextType = .localized("The maximum number of selections has been reached")
        public var maximumSelectedVideoDurationHudTitle: TextType = .localized("The maximum video duration is %d seconds and cannot be selected")
        public var minimumSelectedVideoDurationHudTitle: TextType = .localized("The minimum video duration is %d seconds and cannot be selected")
        public var maximumVideoEditDurationHudTitle: TextType = .localized("The maximum editable duration of the video is %d seconds and cannot be edited")
        public var maximumSelectedPhotoFileSizeHudTitle: TextType = .localized("Photo size exceeds the maximum limit")
        public var maximumSelectedVideoFileSizeHudTitle: TextType = .localized("Video size exceeds the maximum limit")
        
        public var albumList: AlbumList = .init()
        public var photoList: PhotoList = .init()
        public var preview: Preview = .init()
        
        public var browserDeleteTitle: TextType = .localized("删除")
        
        public struct NotAuthorized {
            public var title: TextType = .localized("Unable to access photos in the album")
            public var titleFont: UIFont = HXPickerWrapper<UIFont>.semiboldPingFang(ofSize: 20)
            public var subTitle: TextType = .localized("Currently there is no photo access permission. It is recommended to go to the system settings and allow access to \"All Photos\" in \"Photos\".")
            public var subTitleFont: UIFont = HXPickerWrapper<UIFont>.regularPingFang(ofSize: 17)
            public var buttonTitle: TextType = .localized("Go to system settings")
            public var buttonTitleFont: UIFont = HXPickerWrapper<UIFont>.mediumPingFang(ofSize: 16)
            
            /// The content of Alert that pops up when the album is not authorized
            public var alertTitle: TextType = .localized("Unable to access photos in the album")
            public var alertMessage: TextType = .localized("Currently there is no photo access permission. It is recommended to go to the system settings and allow access to \"All Photos\" in \"Photos\".")
            public var alertLeftTitle: TextType = .localized("取消")
            public var alertRightTitle: TextType = .localized("Go to system settings")
        }
        
        public struct AlbumList {
            public var backTitle: TextType = .localized("返回")
            public var navigationTitle: TextType = .localized("相册")
            public var selectNavigationTitle: TextType = .localized("Select Album")
            public var permissionsTitle: TextType = .localized("Only photos and related albums that allow access can be viewed")
            public var permissionsTitleFont: UIFont = .systemFont(ofSize: 14)
            public var myAlbumSectionTitle: TextType = .localized("My Album")
            public var mediaSectionTitle: TextType = .localized("Media Type")
            public var lookAllSectionTitle: TextType = .localized("View All")
            public var emptyAlbumName: TextType = .localized("All photos")
            
            public var myAlbumNavigationTitle: TextType = .localized("My Album")
        }
        
        public struct PhotoList {
            
            public var emptyNavigationTitle: TextType = .localized("照片")
            
            public var cell: Cell = .init()
            public var filter: Filter = .init()
            public var bottomView: BottomView = .init()
            
            public var filterBottomTitle: TextType = .localized("Filter Condition")
            public var filterBottomEmptyItemTitle: TextType = .localized("No item")
            
            public var hapticTouchSelectedTitle: TextType = .localized("选择")
            public var hapticTouchDeselectedTitle: TextType = .localized("Deselected")
            public var hapticTouchEditTitle: TextType = .localized("编辑")
            public var hapticTouchRemoveEditTitle: TextType = .localized("Clear edited content")
            
            public var emptyTitle: TextType = .localized("No photos")
            public var emptyTitleFont: UIFont = HXPickerWrapper<UIFont>.semiboldPingFang(ofSize: 20)
            public var emptySubTitle: TextType = .localized("You can use the camera to take some photos")
            public var emptySubTitleFont: UIFont = HXPickerWrapper<UIFont>.mediumPingFang(ofSize: 16)
            
            public var videoExportFailedHudTitle: TextType = .localized("Video export failed")
            public var saveSystemAlbumFailedHudTitle: TextType = .localized("Save failed")
            public var cameraUnavailableHudTitle: TextType = .localized("Camera Unavailable!")
            
            public var iCloudSyncHudTitle: TextType = .localized("Syncing iCloud")
            public var iCloudSyncFailedHudTitle: TextType = .localized("iCloud synchronization failed")
            
            public var pageAllTitle: TextType = .localized("全部")
            public var pagePhotoTitle: TextType = .localized("照片")
            public var pageVideoTitle: TextType = .localized("视频")
            public var pageGifTitle: TextType = .custom("GIF")
            public var pageLivePhotoTitle: TextType = .custom("LivePhoto")
            
            public struct Filter {
                public var title: TextType = .localized("筛选")
                public var finishTitle: TextType = .localized("完成")
                
                public var sectionTitle: TextType = .localized("Display only")
                public var anyTitle: TextType = .localized("all items")
                public var editedTitle: TextType = .localized("edited")
                public var photoTitle: TextType = .localized("Filter photos")
                public var gifTitle: TextType = .custom("GIF")
                public var livePhotoTitle: TextType = .custom("LivePhoto")
                public var videoTitle: TextType = .localized("Filter videos")
                
                public var bottomTitle: TextType = .localized("Filter results")
                public var bottomEmptyTitle: TextType = .localized("No filter conditions")
                public var bottomTitleFont: UIFont = .systemFont(ofSize: 12)
            }
            
            public struct Cell {
                public var gifTitle: TextType = .custom("GIF")
                public var LivePhotoTitle: TextType = .custom("Live")
                public var HDRPhotoTitle: TextType = .custom("HDR")
            }
        }
        
        public struct Preview {
            public var cancelTitle: TextType = .localized("取消")
            public var emptyAssetHudTitle: TextType = .localized("No optional resources")
            public var downloadFailedHudTitle: TextType = .localized("Download failed")
            public var iCloudSyncHudTitle: TextType = .localized("Syncing iCloud")
            public var iCloudSyncFailedHudTitle: TextType = .localized("iCloud synchronization failed")
            public var videoLoadFailedHudTitle: TextType = .localized("Video loading failed!")
            public var bottomView: BottomView = .init()
            public var livePhotoTitle: TextType = .custom("Live")
        }
        
        public struct BottomView {
            public var permissionsTitle: TextType = .localized("Unable to access all photos in the album,\nPlease allow access to \"All Photos\" in \"Photos\"")
            public var permissionsTitleFont: UIFont = .systemFont(ofSize: 15)
            public var finishTitle: TextType = .localized("完成")
            public var finishTitleFont: UIFont = HXPickerWrapper<UIFont>.mediumPingFang(ofSize: 16)
            public var previewTitle: TextType = .localized("预览")
            public var previewTitleFont: UIFont = .systemFont(ofSize: 17)
            public var editTitle: TextType = .localized("编辑")
            public var editTitleFont: UIFont = .systemFont(ofSize: 17)
            public var originalTitle: TextType = .localized("原图")
            public var originalTitleFont: UIFont = .systemFont(ofSize: 17)
        }
    }
    #endif
    
    #if HXPICKER_ENABLE_EDITOR || HXPICKER_ENABLE_EDITOR_VIEW
    struct Editor {
        public var tools: Tools = .init()
        public var brush: Tools = .init()
        public var text: Text = .init()
        public var sticker: Sticker = .init()
        public var crop: Crop = .init()
        public var music: Music = .init()
        public var adjustment: Adjustment = .init()
        public var filter: Filter = .init()
        
        public var photoLoadTitle: TextType = .localized("Picture downloading")
        public var videoLoadTitle: TextType = .localized("Video downloading")
        public var iCloudSyncHudTitle: TextType = .localized("Syncing iCloud")
        public var loadFailedAlertTitle: TextType = .localized("提示")
        public var photoLoadFailedAlertMessage: TextType = .localized("Picture acquisition failed!")
        public var videoLoadFailedAlertMessage: TextType = .localized("Video acquisition failed!")
        public var iCloudSyncFailedAlertMessage: TextType = .localized("iCloud synchronization failed")
        public var loadFailedAlertDoneTitle: TextType = .localized("确定")
        public var processingHUDTitle: TextType = .localized("Processing...")
        public var processingFailedHUDTitle: TextType = .localized("Processing failed")
        
        public struct Tools {
            public var cancelTitle: TextType = .localized("取消")
            public var cancelTitleFont: UIFont = HXPickerWrapper<UIFont>.regularPingFang(ofSize: 17)
            public var finishTitle: TextType = .localized("完成")
            public var finishTitleFont: UIFont = HXPickerWrapper<UIFont>.regularPingFang(ofSize: 17)
            public var resetTitle: TextType = .localized("还原")
            public var resetTitleFont: UIFont = HXPickerWrapper<UIFont>.regularPingFang(ofSize: 17)
        }
        
        public struct Brush {
            public var cancelTitle: TextType = .localized("取消")
            public var cancelTitleFont: UIFont = HXPickerWrapper<UIFont>.regularPingFang(ofSize: 17)
            public var finishTitle: TextType = .localized("完成")
            public var finishTitleFont: UIFont = HXPickerWrapper<UIFont>.regularPingFang(ofSize: 17)
        }
        
        public struct Text {
            public var cancelTitle: TextType = .localized("取消")
            public var cancelTitleFont: UIFont = .systemFont(ofSize: 17)
            public var finishTitle: TextType = .localized("完成")
            public var finishTitleFont: UIFont = .systemFont(ofSize: 17)
        }
        
        public struct Sticker {
            public var trashCloseTitle: TextType = .localized("Drag here to delete")
            public var trashOpenTitle: TextType = .localized("Let go to delete")
        }
        
        public struct Crop {
            public var maskListTitle: TextType = .localized("mask material")
            public var maskListFinishTitle: TextType = .localized("完成")
            public var maskListFinishTitleFont: UIFont = .systemFont(ofSize: 17)
            
        }
        
        public struct Music {
            public var emptyHudTitle: TextType = .localized("No soundtrack yet")
            public var lyricEmptyTitle: TextType = .localized("This song has no lyrics yet, please enjoy")
            
            public var searchButtonTitle: TextType = .localized("搜索")
            public var searchButtonTitleFont: UIFont = HXPickerWrapper<UIFont>.mediumPingFang(ofSize: 14) 
            public var volumeButtonTitle: TextType = .localized("音量")
            public var volumeButtonTitleFont: UIFont = HXPickerWrapper<UIFont>.mediumPingFang(ofSize: 14)
            public var volumeMusicButtonTitle: TextType = .localized("配乐")
            public var volumeMusicButtonTitleFont: UIFont = .systemFont(ofSize: 15)
            public var volumeOriginalButtonTitle: TextType = .localized("Video original sound")
            public var volumeOriginalButtonTitleFont: UIFont = .systemFont(ofSize: 15)
            
            public var musicButtonTitle: TextType = .localized("配乐")
            public var musicButtonTitleFont: UIFont = HXPickerWrapper<UIFont>.mediumPingFang(ofSize: 16)
            public var originalButtonTitle: TextType = .localized("Video original sound")
            public var originalButtonTitleFont: UIFont = HXPickerWrapper<UIFont>.mediumPingFang(ofSize: 16)
            public var lyricButtonTitle: TextType = .localized("歌词")
            public var lyricButtonTitleFont: UIFont = HXPickerWrapper<UIFont>.mediumPingFang(ofSize: 16)
            
            public var listTitle: TextType = .localized("Background Music")
            public var finishTitle: TextType = .localized("完成")
            public var finishTitleFont: UIFont = .systemFont(ofSize: 17)
            public var searchPlaceholder: TextType = .localized("Search song title")
            public var searchPlaceholderFont: UIFont = .systemFont(ofSize: 17)
        }
        
        public struct Adjustment {
            public var brightnessTitle: TextType = .localized("亮度")
            public var contrastTitle: TextType = .localized("Contrast")
            public var exposureTitle: TextType = .localized("exposure")
            public var saturationTitle: TextType = .localized("saturation")
            public var warmthTitle: TextType = .localized("色温")
            public var vignetteTitle: TextType = .localized("暗角")
            public var sharpenTitle: TextType = .localized("锐化")
            public var highlightsTitle: TextType = .localized("高光")
            public var shadowsTitle: TextType = .localized("阴影")
        }
        
        public struct Filter {
            public var originalPhotoTitle: TextType = .localized("原图")
            public var originalVideoTitle: TextType = .localized("原片")
            
            public var nameFont: UIFont = HXPickerWrapper<UIFont>.regularPingFang(ofSize: 13)
            public var parameterFont: UIFont = HXPickerWrapper<UIFont>.regularPingFang(ofSize: 11)
        }
    }
    #endif
    
    #if HXPICKER_ENABLE_PICKER || HXPICKER_ENABLE_CAMERA
    struct Camera {
        
        public var unavailableTitle: TextType = .localized("Camera unavailable!")
        public var unavailableDoneTitle: TextType = .localized("确定")
        
        public var failedTitle: TextType = .localized("Camera initialization failed!")
        public var failedDoneTitle: TextType = .localized("确定")
        
        public var switchCameraFailedTitle: TextType = .localized("Camera switching failed!")
        public var audioInputFailedTitle: TextType = .localized("Failed to add the microphone, there will be no sound when recording the video!")
        public var saveSystemAlbumFailedHudTitle: TextType = .localized("Save failed")
        
        public var capturePhotoTitle: TextType = .localized("照片")
        public var captureVideoTitle: TextType = .localized("视频")
        public var captureFailedHudTitle: TextType = .localized("Capture failed!")
        public var capturePhotoTipTitle: TextType = .localized("Touch to take a photo")
        public var captureVideoTipTitle: TextType = .localized("press and hold camera")
        public var captureVideoClickTipTitle: TextType = .localized("Click to record")
        public var captureTipTitle: TextType = .localized("Touch to take a photo, press and hold to take a video")
        
        public var resultFinishTitle: TextType = .localized("完成")
        public var resultFinishTitleFont: UIFont = HXPickerWrapper<UIFont>.mediumPingFang(ofSize: 16)
        
        public var notAuthorized: NotAuthorized = .init()
        
        public struct NotAuthorized {
            /// Content that Alert pops up when the microphone is not authorized
            public var audioTitle: TextType = .localized("Microphone cannot be used")
            public var audioMessage: TextType = .localized("Please allow access to the microphone in Settings-Privacy-Camera")
            public var audioLeftTitle: TextType = .localized("取消")
            public var audioRightTitle: TextType = .localized("Go to system settings")
        }
    }
    #endif
    
    #if HXPICKER_ENABLE_PICKER || HXPICKER_ENABLE_CAMERA
    struct CameraNotAuthorized {
        /// The content of the Alert that pops up when the camera is not authorized
        public var title: TextType = .localized("Camera function cannot be used")
        public var message: TextType = .localized("Please go to the system settings and allow access to \"Camera\".")
        public var leftTitle: TextType = .localized("取消")
        public var rightTitle: TextType = .localized("Go to system settings")
    }
    #endif
}

extension HX.TextManager.TextType: Codable {
    enum CodingKeys: CodingKey {
        case localized
        case custom
        case error
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let text = try? container.decode(String.self, forKey: .localized) {
            self = .localized(text)
            return
        }
        if let text = try? container.decode(String.self, forKey: .custom) {
            self = .custom(text)
            return
        }
        throw DecodingError.dataCorruptedError(
            forKey: CodingKeys.error,
            in: container,
            debugDescription: "Invalid type"
        )
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .localized(let text):
            try container.encode(text, forKey: .localized)
        case .custom(let text):
            try container.encode(text, forKey: .custom)
        }
    }
}

