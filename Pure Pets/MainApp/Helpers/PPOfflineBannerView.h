//
//  PPOfflineBannerView.h
//  Pure Pets
//
//  Persistent offline status banner using NWPathMonitor.
//  Displays a compact amber bar below the status bar when the device
//  loses network connectivity and auto-dismisses on reconnect.
//
//  Usage:
//      [[PPOfflineBannerView sharedBanner] startMonitoring];   // in AppDelegate
//      [[PPOfflineBannerView sharedBanner] stopMonitoring];    // optional teardown
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Notification posted on the main queue whenever connectivity state changes.
/// userInfo: @{ @"isConnected": @(BOOL) }
FOUNDATION_EXPORT NSNotificationName const PPConnectivityDidChangeNotification;

@interface PPOfflineBannerView : UIView

/// Thread-safe singleton. Created lazily on first access.
+ (instancetype)sharedBanner;

/// Begin monitoring network path via NWPathMonitor.
/// Safe to call multiple times — subsequent calls are no-ops.
- (void)startMonitoring;

/// Stop monitoring and remove the banner from the window hierarchy.
- (void)stopMonitoring;

/// Current reachability state. KVO-observable. Updated on main queue.
@property (nonatomic, readonly, getter=isConnected) BOOL connected;

@end

NS_ASSUME_NONNULL_END
