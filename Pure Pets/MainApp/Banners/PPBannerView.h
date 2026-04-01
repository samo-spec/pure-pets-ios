// In PPBannerView.h
//
//  PPBannerView.h
//  PurePets
//
//  Reusable banner (UIControl) with manual CGRect layout:
//  - Background image + gradient
//  - Left text (title/desc/date)
//  - Right images (badge + sample) on the visual trailing edge (RTL/LTR aware)
//  - Dynamic Type-friendly fonts, shadow, rounded corners
//

#import <UIKit/UIKit.h>
#import "PPBannerViewModel.h"
NS_ASSUME_NONNULL_BEGIN

@protocol BannerTapsViewDelegate <NSObject>
-(void)didTapOn_BannerViewModel:(PPBannerViewModel *)pannerViewModel;
@end

@interface PPBannerView : UIControl

@property (nonatomic, assign) UIEdgeInsets contentInsets;
@property (nonatomic, assign) BOOL showsShadow;

- (void)configureWithModel:(PPBannerViewModel *)model;
@property (nonatomic, strong) PPBannerViewModel *bannerModel;
- (void)prepareForReuse;

@property (nonatomic, strong) UILabel *countdownLabel;
@property (nonatomic, strong , nullable) NSTimer *countdownTimer;
@property (nonatomic, strong) NSDate *expireInDateTime;
@property (nonatomic, weak) id <BannerTapsViewDelegate> delegate;
@property (nonatomic, strong) UILabel *countdownTitleLabel;
@property (nonatomic, strong) UILabel *countdownTimeLabel;
@property (nonatomic, strong) NSDate *endDate;
@property (nonatomic, strong) UIView *countDownView;

@end


NS_ASSUME_NONNULL_END
