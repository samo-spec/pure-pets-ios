//
//  ExportPreset.swift
//  HXPhotoPicker
//
//  Created by Slience on 2021/8/18.
//

import UIKit
import AVFoundation

public struct VideoExportParameter {
    /// Resolution of video export
    public let preset: ExportPreset
    /// Video quality [1 - 10]
    public let quality: Int
    
    ///Set video export parameters
    /// - Parameters:
    /// - exportPreset: resolution of video export
    /// - videoQuality: video quality [1 - 10]
    public init(
        preset: ExportPreset,
        quality: Int
    ) {
        self.preset = preset
        self.quality = quality
    }
}

public enum ExportPreset {
    case lowQuality
    case mediumQuality
    case highQuality
    case ratio_640x480
    case ratio_960x540
    case ratio_1280x720
    
    public var name: String {
        switch self {
        case .lowQuality:
            return AVAssetExportPresetLowQuality
        case .mediumQuality:
            return AVAssetExportPresetMediumQuality
        case .highQuality:
            return AVAssetExportPresetHighestQuality
        case .ratio_640x480:
            return AVAssetExportPreset640x480
        case .ratio_960x540:
            return AVAssetExportPreset960x540
        case .ratio_1280x720:
            return AVAssetExportPreset1280x720
        }
    }
}
