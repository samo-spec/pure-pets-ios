//
//  PPRootFeatureFlag.swift
//  PurePetsSwiftUIRefactor
//
//  Created for PurePets Platform SwiftUI Root Architecture.
//

import Foundation

/// Feature flag manager governing the runtime activation of the SwiftUI Root hierarchy refactor.
/// Provides reversible zero-downtime fallback to legacy Objective-C UIKit navigation if required.
@objc(PPRootFeatureFlag)
public final class PPRootFeatureFlag: NSObject, @unchecked Sendable {
    @objc public static let shared = PPRootFeatureFlag()
    
    private static let kUseSwiftUIRootKey = "PP_USE_SWIFTUI_ROOT_ENABLED"
    private static let kUseLegacyBarFallbackKey = "PPUSE_LEGACY_BAR"
    
    private override init() {
        super.init()
    }
    
    /// Global boolean controlling whether `PPRootSwiftCoordinator` is instantiated inside `PPRootTabBarController`.
    @objc public var isSwiftUIRootEnabled: Bool {
        get {
            #if DEBUG
            if let override = UserDefaults.standard.object(forKey: Self.kUseSwiftUIRootKey) as? Bool {
                return override
            }
            #endif
            return UserDefaults.standard.bool(forKey: Self.kUseSwiftUIRootKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.kUseSwiftUIRootKey)
            NotificationCenter.default.post(
                name: NSNotification.Name("PPRootFeatureFlagDidChangeNotification"),
                object: nil
            )
        }
    }
    
    /// Check whether system legacy bar is forced.
    @objc public var isLegacyBarForced: Bool {
        UserDefaults.standard.bool(forKey: Self.kUseLegacyBarFallbackKey)
    }
}
