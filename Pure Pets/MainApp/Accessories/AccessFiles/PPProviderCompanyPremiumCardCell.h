//
//  PPProviderCompanyPremiumCardCell.h
//  Pure Pets
//
//  Ultra-premium provider card cell for ProviderCompaniesListVC.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PPProviderCompanyPremiumCardAccessoryStyle) {
    PPProviderCompanyPremiumCardAccessoryStyleHeart = 0,
    PPProviderCompanyPremiumCardAccessoryStyleChevron = 1,
    PPProviderCompanyPremiumCardAccessoryStyleHidden = 2,
};

@interface PPProviderCompanyPremiumCardViewModel : NSObject <NSCopying>

@property (nonatomic, copy) NSString *providerIdentifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *categoryText;
@property (nonatomic, copy) NSString *countTitleText;
@property (nonatomic, copy) NSString *countValueText;
@property (nonatomic, copy) NSString *countDisplayText;
@property (nonatomic, copy) NSString *ratingText;
@property (nonatomic, copy) NSString *ratingCountText;
@property (nonatomic, copy) NSString *cityText;
@property (nonatomic, strong, nullable) NSURL *imageURL;
@property (nonatomic, strong, nullable) UIImage *placeholderImage;
@property (nonatomic, strong) UIColor *accentColor;
@property (nonatomic, assign, getter=isVerified) BOOL verified;
@property (nonatomic, assign, getter=isActive) BOOL active;
@property (nonatomic, assign, getter=isFavorite) BOOL favorite;
@property (nonatomic, assign) PPProviderCompanyPremiumCardAccessoryStyle accessoryStyle;

@end

@interface PPProviderCompanyPremiumCardCell : UITableViewCell

+ (NSString *)reuseIdentifier;
+ (CGFloat)preferredHeightForTableWidth:(CGFloat)tableWidth;

- (void)configureWithViewModel:(PPProviderCompanyPremiumCardViewModel *)viewModel;
- (void)pp_setFavoriteTarget:(nullable id)target action:(nullable SEL)action;
- (void)pp_runEntranceAnimationWithDelay:(NSTimeInterval)delay;

/// Upload a cover image for the provider and update the view model
- (void)pp_uploadCoverImage:(UIImage *)image
                completion:(void(^)(NSString * _Nullable downloadURL, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
