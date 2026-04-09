//
//  ImageResource.swift
//  HXPhotoPicker
//
//  Created by Silence on 2024/1/30.
//  Copyright © 2024 Silence. All rights reserved.
//

import UIKit

public extension HX {
    
    static var imageResource: ImageResource { .shared }
    
    class ImageResource {
        public static let shared = ImageResource()
        
        #if HXPICKER_ENABLE_PICKER
        /// selector
        public var picker: Picker = .init()
        #endif
        
        #if HXPICKER_ENABLE_EDITOR || HXPICKER_ENABLE_EDITOR_VIEW
        /// Editor
        public var editor: Editor = .init()
        #endif
        
        #if HXPICKER_ENABLE_CAMERA
        /// camera
        public var camera: Camera = .init()
        #endif
    }
}

public extension HX.ImageResource {
    
    enum ImageType {
        case local(String)
        /// iOS 13.0+
        case system(String)
        
        var image: UIImage? {
            switch self {
            case .local(let name):
                return name.image
            case .system(let name):
                if #available(iOS 13.0, *) {
                    return .init(systemName: name)
                } else {
                    return name.image
                }
            }
        }
        
        var name: String {
            switch self {
            case .local(let name):
                return name
            case .system(let name):
                return name
            }
        }
        
        static var imageResource: HX.ImageResource {
            HX.ImageResource.shared
        }
    }
    
    #if HXPICKER_ENABLE_PICKER
    struct Picker {
        /// Album list
        public var albumList: AlbumList = .init()
        /// Photo list
        public var photoList: PhotoList = .init()
        /// Preview interface
        public var preview: Preview = .init()
        /// Unauthorized interface
        public var notAuthorized: NotAuthorized = .init()
        
        public struct NotAuthorized {
            /// Close button of unauthorized interface
            public var close: ImageType = .local("hx_picker_notAuthorized_close")
            /// Close button in dark mode of unauthorized interface
            public var closeDark: ImageType = .local("hx_picker_notAuthorized_close_dark")
        }
        
        public struct AlbumList {
            /// Cover image when the album is empty
            var emptyCover: ImageType = .local("hx_picker_album_empty")
            
            var cell: Cell = .init()
            
            struct Cell {
                /// cell arrow
                var arrow: ImageType = {
                    if #available(iOS 13.0, *) {
                        return .system("chevron.right")
                    }
                    return .local("hx_picker_photolist_bottom_prompt_arrow")
                }()
            }
        }
        
        public struct PhotoList {
            /// Cancel button
            public var cancel: ImageType = .local("hx_picker_photolist_cancel")
            ///Cancel button in dark mode
            public var cancelDark: ImageType = .local("hx_picker_photolist_cancel")
            
            /// Filter button normal state
            public var filterNormal: ImageType = .local("hx_picker_photolist_nav_filter_normal")
            /// Filter button selected state
            public var filterSelected: ImageType = .local("hx_picker_photolist_nav_filter_selected")
            /// Filter interface
            public var filter: Filter = .init()
            
            public var cell: Cell = .init()
            
            public var bottomView: BottomView = .init()
            
            public struct Cell {
                /// Video icon
                public var video: ImageType = .local("hx_picker_cell_video_icon")
                /// Live icon
                public var livePhoto: ImageType = .local("hx_picker_cell_livephoto_icon")
                /// Edited photo icon
                public var photoEdited: ImageType = .local("hx_picker_cell_photo_edit_icon")
                /// Edited video icon
                public var videoEdited: ImageType = .local("hx_picker_cell_video_edit_icon")
                /// iCloud icon
                public var iCloud: ImageType = .local("hx_picker_photo_icloud_mark")
                
                /// Camera icon
                public var camera: ImageType = .local("hx_picker_photoList_photograph")
                /// Camera icon in dark mode
                public var cameraDark: ImageType = .local("hx_picker_photoList_photograph_white")
            }
            
            public struct Filter {
                /// All project icons
                public var any: ImageType = {
                    if #available(iOS 26.0, *) {
                        return .system("square.grid.3x3")
                    }
                    return .local("hx_photo_list_filter_any")
                }()
                /// Edited icon
                public var edited: ImageType = .local("hx_photo_list_filter_edited")
                /// Photo icon
                public var photo: ImageType = .local("hx_photo_list_filter_photo")
                /// animated icon
                public var gif: ImageType = .local("hx_photo_list_filter_gif")
                /// Live icon
                public var livePhoto: ImageType = .local("hx_photo_list_filter_livePhoto")
                /// Video icon
                public var video: ImageType = .local("hx_photo_list_filter_video")
            }
            
            public struct BottomView {
                ///Album permission prompt icon
                public var permissionsPrompt: ImageType = .local("hx_picker_photolist_bottom_prompt")
                /// Album permission jump arrow icon
                public var permissionsArrow: ImageType = {
                    if #available(iOS 13.0, *) {
                        return .system("chevron.right")
                    }
                    return .local("hx_picker_photolist_bottom_prompt_arrow")
                }()
                
                /// Selected list delete icon
                public var delete: ImageType = .local("hx_picker_toolbar_select_cell_delete")
            }
        }
        
        public struct Preview {
            /// Return icon
            public var back: ImageType = .local("hx_picker_photolist_back")
            /// Cancel icon
            public var cancel: ImageType = .local("hx_picker_photolist_cancel")
            ///Cancel button in dark mode
            public var cancelDark: ImageType = .local("hx_picker_photolist_cancel")
            /// Play video icon
            public var videoPlay: ImageType = .local("hx_picker_cell_video_play")
            /// Live picture label icon
            public var livePhoto: ImageType = .local("hx_picker_livePhoto")
            public var livePhotoDisable: ImageType = .local("hx_picker_livePhoto_disable")
            /// Live picture mute icon
            public var livePhotoMuted: ImageType = .local("hx_picker_livePhoto_muted")
            public var livePhotoMutedDisable: ImageType = .local("hx_picker_livePhoto_muted_disable")
            /// HDR label icon
            public var HDR: ImageType = .local("hx_picker_HDR")
            public var HDRDisable: ImageType = .local("hx_picker_HDR_disable")
        }
    }
    #endif

    #if HXPICKER_ENABLE_EDITOR || HXPICKER_ENABLE_EDITOR_VIEW
    struct Editor {
        /// Toolbar
        public var tools: Tools = .init()
        /// Video cropping
        public var video: Video = .init()
        /// Brush
        public var brush: Brush = .init()
        /// Size cropping
        public var crop: Crop = .init()
        /// text
        public var text: Text = .init()
        /// sticker
        public var sticker: Sticker = .init()
        /// Soundtrack
        public var music: Music = .init()
        /// Mosaic/smear
        public var mosaic: Mosaic = .init()
        ///Screen adjustment
        public var adjustment: Adjustment = .init()
        /// Filter
        public var filter: Filter = .init()
        
        public struct Tools {
            /// video
            public var video: ImageType = .local("hx_editor_tools_play")
            /// Brush drawing
            public var graffiti: ImageType = .local("hx_editor_tools_graffiti")
            /// Rotate, crop
            public var cropSize: ImageType = .local("hx_editor_photo_crop")
            /// text
            public var text: ImageType = .local("hx_editor_photo_tools_text")
            /// Texture
            public var chartlet: ImageType = .local("hx_editor_photo_tools_emoji")
            /// Mosaic-smear
            public var mosaic: ImageType = .local("hx_editor_tools_mosaic")
            ///Screen adjustment
            public var adjustment: ImageType = .local("hx_editor_tools_filter_change")
            /// Filter
            public var filter: ImageType = .local("hx_editor_tools_filter")
            /// Soundtrack
            public var music: ImageType = .local("hx_editor_tools_music")
        }
        
        public struct Brush {
            /// Brush custom color
            public var customColor: ImageType = .local("hx_editor_brush_color_custom")
            /// Undo
            public var undo: ImageType = .local("hx_editor_brush_repeal")
            /// Canvas-Undo
            public var canvasUndo: ImageType = .local("hx_editor_canvas_draw_undo")
            /// Canvas-Undo
            public var canvasRedo: ImageType = .local("hx_editor_canvas_draw_redo")
            /// Canvas-clear
            public var canvasUndoAll: ImageType = .local("hx_editor_canvas_draw_undo_all")
        }
        
        public struct Crop {
            /// When the original ratio is selected, vertical ratio-normal state
            public var ratioVerticalNormal: ImageType = .local("hx_editor_crop_scale_switch_left")
            /// When the original ratio is selected, the vertical ratio-selected state
            public var ratioVerticalSelected: ImageType = .local("hx_editor_crop_scale_switch_left_selected")
            /// When the original ratio is selected, horizontal ratio-normal state
            public var ratioHorizontalNormal: ImageType = .local("hx_editor_crop_scale_switch_right")
            /// When the original ratio is selected, the horizontal ratio-selected state
            public var ratioHorizontalSelected: ImageType = .local("hx_editor_crop_scale_switch_right_selected")
            /// Horizontal mirroring
            public var mirrorHorizontally: ImageType = .local("hx_editor_photo_mirror_horizontally")
            /// Vertical mirror
            public var mirrorVertically: ImageType = .local("hx_editor_photo_mirror_vertically")
            /// Rotate left
            public var rotateLeft: ImageType = .local("hx_editor_photo_rotate_left")
            /// Rotate right
            public var rotateRight: ImageType = .local("hx_editor_photo_rotate_right")
            
            /// Custom mask
            public var maskList: ImageType = .local("hx_editor_crop_mask_list")
        }
        
        public struct Text {
            /// Text background-normal state
            public var backgroundNormal: ImageType = .local("hx_editor_photo_text_normal")
            /// Text background-selected state
            public var backgroundSelected: ImageType = .local("hx_editor_photo_text_selected")
            /// Text custom color
            public var customColor: ImageType = .local("hx_editor_brush_color_custom")
        }
        
        public struct Sticker {
            /// Back button
            public var back: ImageType = .local("hx_photo_edit_pull_down")
            /// Jump to album button
            public var album: ImageType = .local("hx_editor_tools_chartle_album")
            /// Cover image when the album is empty
            public var albumEmptyCover: ImageType = .local("hx_picker_album_empty")
            /// Sticker delete button
            public var delete: ImageType = .local("hx_editor_view_sticker_item_delete")
            /// Sticker rotation button
            public var rotate: ImageType = .local("hx_editor_view_sticker_item_rotate")
            /// Sticker zoom button
            public var scale: ImageType = .local("hx_editor_view_sticker_item_scale")
            /// Drag the bottom to delete the open status of the trash can
            public var trashOpen: ImageType = .local("hx_editor_photo_trash_open")
            /// Drag the bottom to delete the closed status of the trash can
            public var trashClose: ImageType = .local("hx_editor_photo_trash_close")
        }
        
        public struct Adjustment {
            /// brightness
            public var brightness: ImageType = .local("hx_editor_filter_edit_brightness")
            /// Contrast
            public var contrast: ImageType = .local("hx_editor_filter_edit_contrast")
            /// Exposure
            public var exposure: ImageType = .local("hx_editor_filter_edit_exposure")
            /// Highlights
            public var highlights: ImageType = .local("hx_editor_filter_edit_highlights")
            /// Saturation
            public var saturation: ImageType = .local("hx_editor_filter_edit_saturation")
            /// shadow
            public var shadows: ImageType = .local("hx_editor_filter_edit_shadows")
            /// sharpen
            public var sharpen: ImageType = .local("hx_editor_filter_edit_sharpen")
            ///Vignetting
            public var vignette: ImageType = .local("hx_editor_filter_edit_vignette")
            /// Color temperature
            public var warmth: ImageType = .local("hx_editor_filter_edit_warmth")
        }
        
        public struct Filter {
            /// edit
            public var edit: ImageType = .local("hx_editor_tools_filter_edit")
            /// Reset
            public var reset: ImageType = .local("hx_editor_tools_filter_reset")
        }
        
        public struct Mosaic {
            /// Undo
            public var undo: ImageType = .local("hx_editor_brush_repeal")
            /// Mosaic
            public var mosaic: ImageType = .local("hx_editor_tool_mosaic_normal")
            /// daub
            public var smear: ImageType = .local("hx_editor_tool_mosaic_color")
            /// Pictures painted each time
            public var smearMask: ImageType = .local("hx_editor_mosaic_brush_image")
        }
        
        public struct Music {
            /// Search icon
            public var search: ImageType = .local("hx_editor_video_music_search")
            /// The music icon on the cell
            public var music: ImageType = .local("hx_editor_tools_music")
            /// Volume icon
            public var volum: ImageType = .local("hx_editor_video_music_volume")
            /// Selection box-unchecked
            public var selectionBoxNormal: ImageType = .local("hx_editor_box_normal")
            /// Selection box-selected
            public var selectionBoxSelected: ImageType = .local("hx_editor_box_selected")
        }
        
        public struct Video {
            /// Play
            public var play: ImageType = .local("hx_editor_video_control_play")
            /// pause
            public var pause: ImageType = .local("hx_editor_video_control_pause")
            /// Left arrow
            public var leftArrow: ImageType = .local("hx_editor_video_control_arrow_left")
            /// Right arrow
            public var rightArrow: ImageType = .local("hx_editor_video_control_arrow_right")
        }
    }
    #endif

    #if HXPICKER_ENABLE_CAMERA
    struct Camera {
        /// Return to the bottom
        public var back: ImageType = .local("hx_camera_down_back")
        
        /// Camera switching
        public var switchCamera: ImageType = .local("hx_camera_overturn")
    }
    #endif
}
