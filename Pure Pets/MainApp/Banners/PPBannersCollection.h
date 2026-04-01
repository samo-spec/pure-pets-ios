//
//  PPBannersCollection.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 08/09/2025.
//


//
//  PPBannersCollection.h
//  PurePets
//

#import <UIKit/UIKit.h>
#import "PPBannersCollection.h"
#import "EllipsePageControl.h"

// In PPBannersCollection.h
typedef NS_ENUM(NSInteger, PPBannersAutoScrollStyle) {
    PPBannersAutoScrollStyleSlide, // default
    PPBannersAutoScrollStyleFade
};

NS_ASSUME_NONNULL_BEGIN


@protocol BannerTapsCollectionDelegate <NSObject>
-(void)didTapOn_BannerViewModel:(PPBannerViewModel *)pannerViewModel;
@end



@interface PPBannersCollection : UIView

@property (nonatomic, strong) MainBannerModel *mainBannerGroup;
@property (nonatomic, weak) id <BannerTapsCollectionDelegate> delegate;

@property (nonatomic) PPBannersAutoScrollStyle autoScrollStyle;            // default Slide
@property (nonatomic) NSTimeInterval autoScrollAnimationDuration;          // default 0.6

/// Array of UIViews or UIImages (UIImage auto wrapped into UIImageView)
@property (nonatomic, strong) NSArray<PPBannerViewModel *> *banners;

// PPBannersCollection.h
@property (nonatomic) NSTimeInterval autoScrollInterval;          // default 3.0
@property (nonatomic, strong) UICollectionView *collectionView;


/// Page control (exposed if you want custom style)
@property (nonatomic, strong) EllipsePageControl *pageControl;

/// Start auto-scroll
- (void)startAutoScroll;

/// Stop auto-scroll
- (void)stopAutoScroll;

/// Convenience init
- (instancetype)initWithBanners:(NSArray<PPBannerViewModel *> *)banners;

@end

NS_ASSUME_NONNULL_END
