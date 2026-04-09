//
//  AssetPermissionsUtil.swift
//  HXPhotoPicker
//
//  Created by Silence on 2024/3/25.
//  Copyright © 2024 Silence. All rights reserved.
//

import Photos

public struct AssetPermissionsUtil {
    
    /// Get the current album permission status
    /// - Returns: permission status
    public static var authorizationStatus: PHAuthorizationStatus {
        let status: PHAuthorizationStatus
        if #available(iOS 14, *) {
            status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        } else {
            status = PHPhotoLibrary.authorizationStatus()
        }
        return status
    }
    
    /// Get camera permissions
    /// - Parameter completionHandler: Get the result
    public static func requestCameraAccess(
        completionHandler: @escaping (Bool) -> Void
    ) {
        #if !targetEnvironment(macCatalyst)
        AVCaptureDevice.requestAccess(
            for: .video
        ) { (granted) in
            DispatchQueue.main.async {
                completionHandler(granted)
            }
        }
        #else
        completionHandler(false)
        #endif
    }
    
    /// Current camera permission status
    /// - Returns: permission status
    #if !targetEnvironment(macCatalyst)
    public static var cameraAuthorizationStatus:  AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
    }
    #endif
    
    /// Whether the current album permission status is Limited
    public static var isLimitedAuthorizationStatus:  Bool {
        #if !targetEnvironment(macCatalyst)
        if #available(iOS 14, *), authorizationStatus == .limited  {
            return true
        }
        #endif
        return false
    }
    
    /// Request for album permissions
    /// - Parameters:
    /// - handler: request permission completed
    public static func requestAuthorization(
        with handler: @escaping (PHAuthorizationStatus) -> Void
    ) {
        let status = authorizationStatus
        if status == PHAuthorizationStatus.notDetermined {
            if #available(iOS 14, *) {
                PHPhotoLibrary.requestAuthorization(
                    for: .readWrite
                ) { (authorizationStatus) in
                    DispatchQueue.main.async {
                        handler(authorizationStatus)
                    }
                }
            } else {
                PHPhotoLibrary.requestAuthorization { (authorizationStatus) in
                    DispatchQueue.main.async {
                        handler(authorizationStatus)
                    }
                }
            }
        }else {
            handler(status)
        }
    }
}
