//
//  Core+Dictionary.swift
//  HXPhotoPicker
//
//  Created by Slience on 2021/1/7.
//

import Photos

extension Dictionary {
    
    /// Whether the resource exists on iCloud
    var inICloud: Bool {
        if let isICloud = self[AnyHashable(PHImageResultIsInCloudKey) as! Key] as? Int {
            return isICloud == 1
        }
        return false
    }
    
    /// Whether the download of the resource has been canceled
    var isCancel: Bool {
        if let isCancel = self[AnyHashable(PHImageCancelledKey) as! Key] as? Int {
            return isCancel == 1
        }
        return false
    }
    var error: Error? {
        self[AnyHashable(PHImageErrorKey) as! Key] as? Error
    }
    /// Determine whether the resource is downloaded incorrectly
    var isError: Bool {
        self[AnyHashable(PHImageErrorKey) as! Key] != nil
    }
    
    /// Determine whether the resource downloaded is degraded
    var isDegraded: Bool {
        if let isDegraded = self[AnyHashable(PHImageResultIsDegradedKey) as! Key] as? Int {
            return isDegraded == 1
        }
        return false
    }
    
    /// Determine whether the resource download is completed
    var downloadFinined: Bool {
        !isCancel && !isError && !isDegraded
    }
}
