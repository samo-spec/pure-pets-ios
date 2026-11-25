//
//  PPCartBranchBannerView.h
//  Pure Pets
//
//  Apple-grade, real-time fulfillment branch change notice banner for CartViewController.
//  Informs the user when the store branch changes, detail stock adjustments, and provides
//  one-tap remediation (remove unavailable items or move to saved for later).
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPCartBranchBannerView : UIView

@property (nonatomic, copy, nullable) void (^onRemoveUnavailable)(void);
@property (nonatomic, copy, nullable) void (^onSaveUnavailableToSavedForLater)(void);
@property (nonatomic, copy, nullable) void (^onDismiss)(void);

- (void)configureWithBranchName:(NSString *)branchName
                outOfStockCount:(NSInteger)outOfStockCount
                   clampedCount:(NSInteger)clampedCount;

@end

NS_ASSUME_NONNULL_END
