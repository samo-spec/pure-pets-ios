//
//  PPPetProfilesViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/7/26.
//

#import "PPPetProfilesViewController.h"
#import "PPPetProfileEditorViewController.h"
#import "PPPetRemindersViewController.h"
#import "PPPetProfile.h"
#import "PPPetProfilesUIStyle.h"
#import "PPModernAvatarRenderer.h"
#import "UserManager.h"
#import "Language.h"
#import "PPMarketplaceHeroCardStyle.h"

static CGFloat const PPPetProfilesMaximumContentWidth = 760.0;
static CGFloat const PPPetProfilesHorizontalMargin = 16.0;
static CGFloat const PPPetProfilesCardCornerRadius = 22.0;
static NSString * const PPPetProfilesCardCellIdentifier = @"PPPetProfilesCardCell";
static NSString * const PPPetProfilesSkeletonCellIdentifier = @"PPPetProfilesSkeletonCell";
static NSString * const PPPetProfilesStateCellIdentifier = @"PPPetProfilesStateCell";
static NSString * const PPPetProfilesSectionHeaderIdentifier = @"PPPetProfilesSectionHeader";

static UIFont *PPPetProfilesScaledFont(UIFont *font, UIFontTextStyle textStyle)
{
    UIFont *resolvedFont = font ?: [UIFont preferredFontForTextStyle:textStyle];
    if (@available(iOS 11.0, *)) {
        return [[UIFontMetrics metricsForTextStyle:textStyle] scaledFontForFont:resolvedFont];
    }
    return resolvedFont;
}

static void PPPetProfilesApplyContinuousCorners(UIView *view, CGFloat radius)
{
    view.layer.cornerRadius = radius;
    if (@available(iOS 13.0, *)) {
        view.layer.cornerCurve = kCACornerCurveContinuous;
    }
}

static NSCache<NSString *, UIImage *> *PPPetProfilesImageCache(void)
{
    static NSCache<NSString *, UIImage *> *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 80;
        cache.totalCostLimit = 32 * 1024 * 1024;
    });
    return cache;
}

static NSURLSession *PPPetProfilesImageSession(void)
{
    static NSURLSession *session;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        configuration.timeoutIntervalForRequest = 25.0;
        configuration.timeoutIntervalForResource = 45.0;
        configuration.requestCachePolicy = NSURLRequestReturnCacheDataElseLoad;
        session = [NSURLSession sessionWithConfiguration:configuration];
    });
    return session;
}

static NSURLSessionDataTask *PPPetProfilesLoadImage(NSString *URLString,
                                                     void (^completion)(UIImage *image))
{
    if (URLString.length == 0 || !completion) {
        return nil;
    }

    UIImage *cachedImage = [PPPetProfilesImageCache() objectForKey:URLString];
    if (cachedImage) {
        completion(cachedImage);
        return nil;
    }

    NSURL *URL = [NSURL URLWithString:URLString];
    if (!URL) {
        return nil;
    }

    NSURLSessionDataTask *task = [PPPetProfilesImageSession() dataTaskWithURL:URL
                                                           completionHandler:^(NSData *data,
                                                                               __unused NSURLResponse *response,
                                                                               __unused NSError *error) {
        if (data.length == 0) return;
        UIImage *image = [UIImage imageWithData:data];
        if (!image) return;
        [PPPetProfilesImageCache() setObject:image forKey:URLString cost:(NSUInteger)data.length];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(image);
        });
    }];
    [task resume];
    return task;
}

static UIButton *PPPetProfilesActionButton(NSString *title, NSString *systemImageName, BOOL primary)
{
    UIButtonConfiguration *configuration = primary
        ? [UIButtonConfiguration filledButtonConfiguration]
        : [UIButtonConfiguration tintedButtonConfiguration];
    configuration.cornerStyle = UIButtonConfigurationCornerStyleLarge;
    configuration.imagePlacement = NSDirectionalRectEdgeLeading;
    configuration.imagePadding = 8.0;
    configuration.titleLineBreakMode = NSLineBreakByWordWrapping;
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(12.0, 16.0, 12.0, 16.0);
    configuration.image = [UIImage systemImageNamed:systemImageName
                                  withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:15.0
                                                                                                   weight:UIImageSymbolWeightSemibold]];
    configuration.title = title ?: @"";
    configuration.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey, id> *(
        NSDictionary<NSAttributedStringKey, id> *incomingAttributes) {
        NSMutableDictionary<NSAttributedStringKey, id> *attributes = incomingAttributes.mutableCopy;
        attributes[NSFontAttributeName] = PPPetProfilesScaledFont([GM MidFontWithSize:14.0],
                                                                   UIFontTextStyleSubheadline);
        return attributes.copy;
    };
    configuration.baseForegroundColor = primary ? UIColor.whiteColor : PPPetsUIBrandColor();
    configuration.baseBackgroundColor = primary
        ? PPPetsUIBrandColor()
        : [PPPetsUIBrandColor() colorWithAlphaComponent:0.12];

    UIButton *button = [UIButton buttonWithConfiguration:configuration primaryAction:nil];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.titleLabel.numberOfLines = 2;
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    button.accessibilityLabel = title;
    button.configurationUpdateHandler = ^(UIButton *updatedButton) {
        CGFloat scale = updatedButton.highlighted && !UIAccessibilityIsReduceMotionEnabled() ? 0.975 : 1.0;
        [UIView animateWithDuration:updatedButton.highlighted ? 0.08 : 0.18
                              delay:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            updatedButton.transform = CGAffineTransformMakeScale(scale, scale);
        } completion:nil];
    };
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:50.0].active = YES;
    return button;
}

#pragma mark - Shimmer

@interface PPPetProfilesShimmerView : UIView
@property (nonatomic, strong) CAGradientLayer *gradientLayer;
- (void)applyTheme;
@end

@implementation PPPetProfilesShimmerView

- (instancetype)init
{
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.userInteractionEnabled = NO;
    self.clipsToBounds = YES;
    self.gradientLayer = [CAGradientLayer layer];
    self.gradientLayer.startPoint = CGPointMake(0.0, 0.5);
    self.gradientLayer.endPoint = CGPointMake(1.0, 0.5);
    self.gradientLayer.locations = @[@0.0, @0.5, @1.0];
    [self.layer addSublayer:self.gradientLayer];
    [self applyTheme];
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.bounds);
    self.gradientLayer.frame = CGRectMake(-width, 0.0, width * 3.0, CGRectGetHeight(self.bounds));
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (!self.window || UIAccessibilityIsReduceMotionEnabled()) {
        [self.gradientLayer removeAnimationForKey:@"pp.petProfiles.shimmer"];
        return;
    }

    if (![self.gradientLayer animationForKey:@"pp.petProfiles.shimmer"]) {
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
        animation.fromValue = @0.0;
        animation.toValue = @(MAX(CGRectGetWidth(self.bounds), 120.0));
        animation.duration = 1.35;
        animation.repeatCount = HUGE_VALF;
        animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.gradientLayer addAnimation:animation forKey:@"pp.petProfiles.shimmer"];
    }
}

- (void)applyTheme
{
    UIColor *base = [AppForgroundColr colorWithAlphaComponent:0.68];
    UIColor *highlight = [UIColor.whiteColor colorWithAlphaComponent:
                          self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.10 : 0.78];
    self.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.30];
    UIColor *resolvedBase = [base resolvedColorWithTraitCollection:self.traitCollection];
    UIColor *resolvedHighlight = [highlight resolvedColorWithTraitCollection:self.traitCollection];
    self.gradientLayer.colors = @[(id)resolvedBase.CGColor,
                                  (id)resolvedHighlight.CGColor,
                                  (id)resolvedBase.CGColor];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self applyTheme];
    }
}

@end

#pragma mark - Skeleton Cell

@interface PPPetProfilesSkeletonCell : UITableViewCell
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, copy) NSArray<PPPetProfilesShimmerView *> *shimmerViews;
- (void)applyTheme;
@end

@implementation PPPetProfilesSkeletonCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;

    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = NO;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.clipsToBounds = NO;

    self.surfaceView = [[UIView alloc] init];
    self.surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.surfaceView];

    PPPetProfilesShimmerView *image = [[PPPetProfilesShimmerView alloc] init];
    PPPetProfilesShimmerView *title = [[PPPetProfilesShimmerView alloc] init];
    PPPetProfilesShimmerView *detail = [[PPPetProfilesShimmerView alloc] init];
    PPPetProfilesShimmerView *meta = [[PPPetProfilesShimmerView alloc] init];
    PPPetProfilesApplyContinuousCorners(image, 18.0);
    PPPetProfilesApplyContinuousCorners(title, 7.0);
    PPPetProfilesApplyContinuousCorners(detail, 6.0);
    PPPetProfilesApplyContinuousCorners(meta, 12.0);
    [self.surfaceView addSubview:image];
    [self.surfaceView addSubview:title];
    [self.surfaceView addSubview:detail];
    [self.surfaceView addSubview:meta];
    self.shimmerViews = @[image, title, detail, meta];

    NSLayoutConstraint *preferredWidth = [self.surfaceView.widthAnchor constraintEqualToAnchor:self.contentView.widthAnchor
                                                                                        constant:-(PPPetProfilesHorizontalMargin * 2.0)];
    preferredWidth.priority = 999;
    NSLayoutConstraint *titleWidth = [title.widthAnchor constraintEqualToConstant:132.0];
    titleWidth.priority = UILayoutPriorityDefaultHigh;
    NSLayoutConstraint *detailWidth = [detail.widthAnchor constraintEqualToConstant:174.0];
    detailWidth.priority = UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [self.surfaceView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6.0],
        [self.surfaceView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6.0],
        [self.surfaceView.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [self.surfaceView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.contentView.leadingAnchor constant:PPPetProfilesHorizontalMargin],
        [self.surfaceView.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-PPPetProfilesHorizontalMargin],
        [self.surfaceView.widthAnchor constraintLessThanOrEqualToConstant:PPPetProfilesMaximumContentWidth],
        preferredWidth,

        [image.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:16.0],
        [image.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor constant:16.0],
        [image.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor constant:-16.0],
        [image.widthAnchor constraintEqualToConstant:84.0],
        [image.heightAnchor constraintEqualToConstant:84.0],

        [title.leadingAnchor constraintEqualToAnchor:image.trailingAnchor constant:16.0],
        [title.topAnchor constraintEqualToAnchor:image.topAnchor constant:5.0],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:self.surfaceView.trailingAnchor constant:-16.0],
        titleWidth,
        [title.heightAnchor constraintEqualToConstant:15.0],

        [detail.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [detail.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:10.0],
        [detail.trailingAnchor constraintLessThanOrEqualToAnchor:self.surfaceView.trailingAnchor constant:-16.0],
        detailWidth,
        [detail.heightAnchor constraintEqualToConstant:12.0],

        [meta.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [meta.topAnchor constraintEqualToAnchor:detail.bottomAnchor constant:12.0],
        [meta.widthAnchor constraintEqualToConstant:92.0],
        [meta.heightAnchor constraintEqualToConstant:25.0],
        [meta.trailingAnchor constraintLessThanOrEqualToAnchor:self.surfaceView.trailingAnchor constant:-16.0],
    ]];
    [self applyTheme];
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    if (!CGRectIsEmpty(self.surfaceView.bounds)) {
        self.surfaceView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.surfaceView.bounds
                                                                       cornerRadius:PPPetProfilesCardCornerRadius].CGPath;
    }
}

- (void)applyTheme
{
    PPPetsApplySurfaceStyle(self.surfaceView, PPPetProfilesCardCornerRadius);
    self.surfaceView.layer.shadowOpacity = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.18 : 0.035;
    self.surfaceView.layer.shadowRadius = 12.0;
    self.surfaceView.layer.shadowOffset = CGSizeMake(0.0, 5.0);
    for (PPPetProfilesShimmerView *shimmerView in self.shimmerViews) {
        [shimmerView applyTheme];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self applyTheme];
    }
}

@end

#pragma mark - Profile Cell

@interface PPPetProfilesCardCell : UITableViewCell
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIImageView *petImageView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) UIView *vaccinationChip;
@property (nonatomic, strong) UIImageView *vaccinationIconView;
@property (nonatomic, strong) UILabel *vaccinationLabel;
@property (nonatomic, strong) UIView *defaultChip;
@property (nonatomic, strong) UIImageView *defaultIconView;
@property (nonatomic, strong) UILabel *defaultLabel;
@property (nonatomic, strong) UIImageView *chevronView;
@property (nonatomic, strong) NSURLSessionDataTask *imageTask;
@property (nonatomic, copy) NSString *representedImageURL;
@property (nonatomic, copy) dispatch_block_t makeDefaultHandler;
@property (nonatomic, copy) dispatch_block_t deleteHandler;
- (void)configureWithPet:(PPPetProfile *)pet
      makeDefaultHandler:(nullable dispatch_block_t)makeDefaultHandler
           deleteHandler:(nullable dispatch_block_t)deleteHandler;
- (void)applyTheme;
@end

@implementation PPPetProfilesCardCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;

    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = NO;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.clipsToBounds = NO;

    self.surfaceView = [[UIView alloc] init];
    self.surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.surfaceView];

    self.petImageView = [[UIImageView alloc] init];
    self.petImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.petImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.petImageView.clipsToBounds = YES;
    self.petImageView.backgroundColor = [PPPetsUIBrandColor() colorWithAlphaComponent:0.08];
    PPPetProfilesApplyContinuousCorners(self.petImageView, 18.0);
    [self.surfaceView addSubview:self.petImageView];

    self.nameLabel = [[UILabel alloc] init];
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.nameLabel.font = PPPetProfilesScaledFont([GM boldFontWithSize:19.0], UIFontTextStyleHeadline);
    self.nameLabel.adjustsFontForContentSizeCategory = YES;
    self.nameLabel.numberOfLines = 2;
    [self.surfaceView addSubview:self.nameLabel];

    self.detailLabel = [[UILabel alloc] init];
    self.detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.detailLabel.font = PPPetProfilesScaledFont([GM MidFontWithSize:13.5], UIFontTextStyleSubheadline);
    self.detailLabel.adjustsFontForContentSizeCategory = YES;
    self.detailLabel.numberOfLines = 0;
    [self.surfaceView addSubview:self.detailLabel];

    self.vaccinationChip = [[UIView alloc] init];
    self.vaccinationChip.translatesAutoresizingMaskIntoConstraints = NO;
    PPPetProfilesApplyContinuousCorners(self.vaccinationChip, 13.0);
    [self.surfaceView addSubview:self.vaccinationChip];

    self.vaccinationIconView = [[UIImageView alloc] initWithImage:
                                [[UIImage systemImageNamed:@"syringe.fill"
                                         withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:11.0
                                                                                                          weight:UIImageSymbolWeightSemibold]]
                                 imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    self.vaccinationIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.vaccinationIconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.vaccinationChip addSubview:self.vaccinationIconView];

    self.vaccinationLabel = [[UILabel alloc] init];
    self.vaccinationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.vaccinationLabel.font = PPPetProfilesScaledFont([GM MidFontWithSize:11.5], UIFontTextStyleFootnote);
    self.vaccinationLabel.adjustsFontForContentSizeCategory = YES;
    self.vaccinationLabel.numberOfLines = 0;
    [self.vaccinationChip addSubview:self.vaccinationLabel];

    self.defaultChip = [[UIView alloc] init];
    self.defaultChip.translatesAutoresizingMaskIntoConstraints = NO;
    PPPetProfilesApplyContinuousCorners(self.defaultChip, 13.0);
    [self.surfaceView addSubview:self.defaultChip];

    self.defaultIconView = [[UIImageView alloc] initWithImage:
                            [[UIImage systemImageNamed:@"star.fill"
                                     withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:10.5
                                                                                                      weight:UIImageSymbolWeightSemibold]]
                             imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    self.defaultIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.defaultIconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.defaultChip addSubview:self.defaultIconView];

    self.defaultLabel = [[UILabel alloc] init];
    self.defaultLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.defaultLabel.font = PPPetProfilesScaledFont([GM MidFontWithSize:11.5], UIFontTextStyleFootnote);
    self.defaultLabel.adjustsFontForContentSizeCategory = YES;
    self.defaultLabel.text = kLang(@"pet_profiles_default_badge");
    self.defaultLabel.numberOfLines = 0;
    [self.defaultChip addSubview:self.defaultLabel];

    self.chevronView = [[UIImageView alloc] init];
    self.chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    self.chevronView.contentMode = UIViewContentModeScaleAspectFit;
    [self.surfaceView addSubview:self.chevronView];

    UIStackView *metadataStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.vaccinationChip, self.defaultChip]];
    metadataStack.translatesAutoresizingMaskIntoConstraints = NO;
    metadataStack.axis = UILayoutConstraintAxisVertical;
    metadataStack.alignment = UIStackViewAlignmentLeading;
    metadataStack.spacing = 6.0;
    metadataStack.semanticContentAttribute = PPPetsCurrentSemanticAttribute();
    [self.surfaceView addSubview:metadataStack];

    NSLayoutConstraint *preferredWidth = [self.surfaceView.widthAnchor constraintEqualToAnchor:self.contentView.widthAnchor
                                                                                        constant:-(PPPetProfilesHorizontalMargin * 2.0)];
    preferredWidth.priority = 999;
    [NSLayoutConstraint activateConstraints:@[
        [self.surfaceView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6.0],
        [self.surfaceView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6.0],
        [self.surfaceView.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [self.surfaceView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.contentView.leadingAnchor constant:PPPetProfilesHorizontalMargin],
        [self.surfaceView.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-PPPetProfilesHorizontalMargin],
        [self.surfaceView.widthAnchor constraintLessThanOrEqualToConstant:PPPetProfilesMaximumContentWidth],
        preferredWidth,

        [self.petImageView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:16.0],
        [self.petImageView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor constant:16.0],
        [self.petImageView.widthAnchor constraintEqualToConstant:84.0],
        [self.petImageView.heightAnchor constraintEqualToConstant:84.0],
        [self.petImageView.bottomAnchor constraintLessThanOrEqualToAnchor:self.surfaceView.bottomAnchor constant:-16.0],

        [self.chevronView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-16.0],
        [self.chevronView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.chevronView.widthAnchor constraintEqualToConstant:13.0],
        [self.chevronView.heightAnchor constraintEqualToConstant:18.0],

        [self.nameLabel.leadingAnchor constraintEqualToAnchor:self.petImageView.trailingAnchor constant:16.0],
        [self.nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.chevronView.leadingAnchor constant:-12.0],
        [self.nameLabel.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor constant:17.0],

        [self.detailLabel.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
        [self.detailLabel.trailingAnchor constraintEqualToAnchor:self.nameLabel.trailingAnchor],
        [self.detailLabel.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:4.0],

        [metadataStack.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
        [metadataStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.chevronView.leadingAnchor constant:-12.0],
        [metadataStack.topAnchor constraintEqualToAnchor:self.detailLabel.bottomAnchor constant:10.0],
        [metadataStack.bottomAnchor constraintLessThanOrEqualToAnchor:self.surfaceView.bottomAnchor constant:-15.0],

        [self.vaccinationChip.heightAnchor constraintGreaterThanOrEqualToConstant:26.0],
        [self.vaccinationIconView.leadingAnchor constraintEqualToAnchor:self.vaccinationChip.leadingAnchor constant:9.0],
        [self.vaccinationIconView.centerYAnchor constraintEqualToAnchor:self.vaccinationChip.centerYAnchor],
        [self.vaccinationIconView.widthAnchor constraintEqualToConstant:13.0],
        [self.vaccinationIconView.heightAnchor constraintEqualToConstant:13.0],
        [self.vaccinationLabel.leadingAnchor constraintEqualToAnchor:self.vaccinationIconView.trailingAnchor constant:5.0],
        [self.vaccinationLabel.trailingAnchor constraintEqualToAnchor:self.vaccinationChip.trailingAnchor constant:-9.0],
        [self.vaccinationLabel.topAnchor constraintEqualToAnchor:self.vaccinationChip.topAnchor constant:5.0],
        [self.vaccinationLabel.bottomAnchor constraintEqualToAnchor:self.vaccinationChip.bottomAnchor constant:-5.0],

        [self.defaultChip.heightAnchor constraintGreaterThanOrEqualToConstant:26.0],
        [self.defaultIconView.leadingAnchor constraintEqualToAnchor:self.defaultChip.leadingAnchor constant:9.0],
        [self.defaultIconView.centerYAnchor constraintEqualToAnchor:self.defaultChip.centerYAnchor],
        [self.defaultIconView.widthAnchor constraintEqualToConstant:12.0],
        [self.defaultIconView.heightAnchor constraintEqualToConstant:12.0],
        [self.defaultLabel.leadingAnchor constraintEqualToAnchor:self.defaultIconView.trailingAnchor constant:5.0],
        [self.defaultLabel.trailingAnchor constraintEqualToAnchor:self.defaultChip.trailingAnchor constant:-9.0],
        [self.defaultLabel.topAnchor constraintEqualToAnchor:self.defaultChip.topAnchor constant:5.0],
        [self.defaultLabel.bottomAnchor constraintEqualToAnchor:self.defaultChip.bottomAnchor constant:-5.0],
    ]];

    [self applyTheme];
    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [self.imageTask cancel];
    self.imageTask = nil;
    self.representedImageURL = nil;
    self.petImageView.image = nil;
    self.nameLabel.text = nil;
    self.detailLabel.text = nil;
    self.vaccinationLabel.text = nil;
    self.defaultChip.hidden = YES;
    self.makeDefaultHandler = nil;
    self.deleteHandler = nil;
    self.accessibilityCustomActions = nil;
    self.alpha = 1.0;
    self.transform = CGAffineTransformIdentity;
    self.surfaceView.transform = CGAffineTransformIdentity;
    self.surfaceView.alpha = 1.0;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    if (!CGRectIsEmpty(self.surfaceView.bounds)) {
        self.surfaceView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.surfaceView.bounds
                                                                       cornerRadius:PPPetProfilesCardCornerRadius].CGPath;
    }
}

- (void)configureWithPet:(PPPetProfile *)pet
      makeDefaultHandler:(dispatch_block_t)makeDefaultHandler
           deleteHandler:(dispatch_block_t)deleteHandler
{
    [self.imageTask cancel];
    self.imageTask = nil;
    self.makeDefaultHandler = makeDefaultHandler;
    self.deleteHandler = deleteHandler;

    self.nameLabel.text = pet.name.length > 0 ? pet.name : kLang(@"pet_name_placeholder");
    NSMutableArray<NSString *> *details = [NSMutableArray array];
    NSString *breed = pet.breed.length > 0 ? pet.breed : pet.categoryName;
    if (breed.length > 0) [details addObject:breed];
    NSString *age = [pet displayAgeText];
    if (age.length > 0) [details addObject:age];
    self.detailLabel.text = details.count > 0
        ? [details componentsJoinedByString:@"  \u2022  "]
        : kLang(@"pet_breed_unknown");
    self.vaccinationLabel.text = [NSString stringWithFormat:kLang(@"pet_profiles_vaccine_count_format"),
                                  (long)pet.vaccinations.count];
    self.defaultChip.hidden = !pet.isDefaultPet;

    UIImage *placeholder = [PPModernAvatarRenderer avatarImageForName:(pet.name ?: @"") size:96.0];
    self.petImageView.image = placeholder;
    self.petImageView.tintColor = PPPetsUIBrandColor();
    self.representedImageURL = pet.imageURL ?: @"";
    NSString *requestedURL = self.representedImageURL;
    if (requestedURL.length > 0) {
        __weak typeof(self) weakSelf = self;
        self.imageTask = PPPetProfilesLoadImage(requestedURL, ^(UIImage *image) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || ![self.representedImageURL isEqualToString:requestedURL]) return;
            [UIView transitionWithView:self.petImageView
                              duration:UIAccessibilityIsReduceMotionEnabled() ? 0.0 : 0.22
                               options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowUserInteraction
                            animations:^{
                self.petImageView.image = image;
            } completion:nil];
        });
    }

    self.surfaceView.semanticContentAttribute = PPPetsCurrentSemanticAttribute();
    self.nameLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.detailLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.chevronView.image = [[UIImage systemImageNamed:PPPetsForwardChevronSymbolName()
                                       withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:13.0
                                                                                                        weight:UIImageSymbolWeightSemibold]]
                              imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

    self.isAccessibilityElement = YES;
    self.accessibilityLabel = [NSString stringWithFormat:@"%@, %@, %@",
                               self.nameLabel.text ?: @"",
                               self.detailLabel.text ?: @"",
                               self.vaccinationLabel.text ?: @""];
    self.accessibilityHint = kLang(@"pet_profile_tap_hint");
    self.accessibilityTraits = UIAccessibilityTraitButton | (pet.isDefaultPet ? UIAccessibilityTraitSelected : 0);

    NSMutableArray<UIAccessibilityCustomAction *> *customActions = [NSMutableArray array];
    if (!pet.isDefaultPet && makeDefaultHandler) {
        [customActions addObject:[[UIAccessibilityCustomAction alloc] initWithName:kLang(@"pet_default_action")
                                                                             target:self
                                                                           selector:@selector(pp_accessibilityMakeDefault)]];
    }
    if (deleteHandler) {
        [customActions addObject:[[UIAccessibilityCustomAction alloc] initWithName:kLang(@"Delete")
                                                                             target:self
                                                                           selector:@selector(pp_accessibilityDelete)]];
    }
    self.accessibilityCustomActions = customActions.copy;
    [self applyTheme];
}

- (BOOL)pp_accessibilityMakeDefault
{
    if (self.makeDefaultHandler) self.makeDefaultHandler();
    return self.makeDefaultHandler != nil;
}

- (BOOL)pp_accessibilityDelete
{
    if (self.deleteHandler) self.deleteHandler();
    return self.deleteHandler != nil;
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.surfaceView.alpha = highlighted ? 0.92 : 1.0;
        return;
    }
    highlighted ? PPTapFeedbackDown(self.surfaceView) : PPTapFeedbackUp(self.surfaceView);
}

- (void)applyTheme
{
    PPPetsApplySurfaceStyle(self.surfaceView, PPPetProfilesCardCornerRadius);
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    self.surfaceView.layer.shadowOpacity = isDark ? 0.20 : 0.055;
    self.surfaceView.layer.shadowRadius = isDark ? 14.0 : 16.0;
    self.surfaceView.layer.shadowOffset = CGSizeMake(0.0, isDark ? 6.0 : 8.0);
    self.nameLabel.textColor = AppPrimaryTextClr;
    self.detailLabel.textColor = PPPetsUISecondaryTextColor();
    self.chevronView.tintColor = [UIColor.tertiaryLabelColor colorWithAlphaComponent:0.72];
    self.petImageView.layer.borderWidth = 1.0;
    self.petImageView.layer.borderColor = [[PPPetsUIBrandColor() colorWithAlphaComponent:isDark ? 0.22 : 0.12]
                                           resolvedColorWithTraitCollection:self.traitCollection].CGColor;
    self.vaccinationChip.backgroundColor = [PPPetsUIBrandColor() colorWithAlphaComponent:isDark ? 0.13 : 0.08];
    self.vaccinationIconView.tintColor = PPPetsUIBrandColor();
    self.vaccinationLabel.textColor = PPPetsUIBrandColor();
    self.defaultChip.backgroundColor = [UIColor.systemYellowColor colorWithAlphaComponent:isDark ? 0.14 : 0.11];
    self.defaultIconView.tintColor = UIColor.systemYellowColor;
    self.defaultLabel.textColor = isDark ? UIColor.systemYellowColor : [UIColor colorWithRed:0.56 green:0.40 blue:0.04 alpha:1.0];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self applyTheme];
    }
}

@end

#pragma mark - State Cell

typedef NS_ENUM(NSInteger, PPPetProfilesStateKind) {
    PPPetProfilesStateKindEmpty,
    PPPetProfilesStateKindError,
};

@interface PPPetProfilesStateCell : UITableViewCell
@property (nonatomic, strong) UIView *stateContainer;
@property (nonatomic, strong) UIView *iconContainer;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, copy) dispatch_block_t actionHandler;
- (void)configureForKind:(PPPetProfilesStateKind)kind actionHandler:(dispatch_block_t)actionHandler;
- (void)applyTheme;
@end

@implementation PPPetProfilesStateCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;

    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;

    self.stateContainer = [[UIView alloc] init];
    self.stateContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.stateContainer];

    self.iconContainer = [[UIView alloc] init];
    self.iconContainer.translatesAutoresizingMaskIntoConstraints = NO;
    PPPetProfilesApplyContinuousCorners(self.iconContainer, 30.0);
    [self.stateContainer addSubview:self.iconContainer];

    self.iconView = [[UIImageView alloc] init];
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconView.accessibilityElementsHidden = YES;
    [self.iconContainer addSubview:self.iconView];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = PPPetProfilesScaledFont([GM boldFontWithSize:20.0], UIFontTextStyleTitle3);
    self.titleLabel.adjustsFontForContentSizeCategory = YES;
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.numberOfLines = 2;
    [self.stateContainer addSubview:self.titleLabel];

    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.font = PPPetProfilesScaledFont([GM MidFontWithSize:14.0], UIFontTextStyleBody);
    self.subtitleLabel.adjustsFontForContentSizeCategory = YES;
    self.subtitleLabel.textAlignment = NSTextAlignmentCenter;
    self.subtitleLabel.numberOfLines = 0;
    [self.stateContainer addSubview:self.subtitleLabel];

    self.actionButton = PPPetProfilesActionButton(@"", @"arrow.clockwise", YES);
    [self.actionButton addTarget:self action:@selector(pp_actionTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.stateContainer addSubview:self.actionButton];

    NSLayoutConstraint *preferredWidth = [self.stateContainer.widthAnchor constraintEqualToAnchor:self.contentView.widthAnchor constant:-64.0];
    preferredWidth.priority = 999;
    [NSLayoutConstraint activateConstraints:@[
        [self.stateContainer.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:30.0],
        [self.stateContainer.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-34.0],
        [self.stateContainer.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [self.stateContainer.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.contentView.leadingAnchor constant:32.0],
        [self.stateContainer.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-32.0],
        [self.stateContainer.widthAnchor constraintLessThanOrEqualToConstant:440.0],
        preferredWidth,

        [self.iconContainer.topAnchor constraintEqualToAnchor:self.stateContainer.topAnchor],
        [self.iconContainer.centerXAnchor constraintEqualToAnchor:self.stateContainer.centerXAnchor],
        [self.iconContainer.widthAnchor constraintEqualToConstant:60.0],
        [self.iconContainer.heightAnchor constraintEqualToConstant:60.0],

        [self.iconView.centerXAnchor constraintEqualToAnchor:self.iconContainer.centerXAnchor],
        [self.iconView.centerYAnchor constraintEqualToAnchor:self.iconContainer.centerYAnchor],
        [self.iconView.widthAnchor constraintEqualToConstant:28.0],
        [self.iconView.heightAnchor constraintEqualToConstant:28.0],

        [self.titleLabel.topAnchor constraintEqualToAnchor:self.iconContainer.bottomAnchor constant:18.0],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.stateContainer.leadingAnchor],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.stateContainer.trailingAnchor],

        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:8.0],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.stateContainer.leadingAnchor],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.stateContainer.trailingAnchor],

        [self.actionButton.topAnchor constraintEqualToAnchor:self.subtitleLabel.bottomAnchor constant:20.0],
        [self.actionButton.centerXAnchor constraintEqualToAnchor:self.stateContainer.centerXAnchor],
        [self.actionButton.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.stateContainer.leadingAnchor],
        [self.actionButton.trailingAnchor constraintLessThanOrEqualToAnchor:self.stateContainer.trailingAnchor],
        [self.actionButton.widthAnchor constraintGreaterThanOrEqualToConstant:154.0],
        [self.actionButton.bottomAnchor constraintEqualToAnchor:self.stateContainer.bottomAnchor],
    ]];

    [self applyTheme];
    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.actionHandler = nil;
    self.alpha = 1.0;
    self.transform = CGAffineTransformIdentity;
}

- (void)configureForKind:(PPPetProfilesStateKind)kind actionHandler:(dispatch_block_t)actionHandler
{
    self.actionHandler = actionHandler;
    NSString *buttonTitle = nil;
    NSString *buttonImage = nil;
    if (kind == PPPetProfilesStateKindError) {
        self.titleLabel.text = kLang(@"pet_profiles_error_title");
        self.subtitleLabel.text = kLang(@"pet_profiles_error_subtitle");
        self.iconView.image = [[UIImage systemImageNamed:@"exclamationmark.triangle.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        buttonTitle = kLang(@"Retry");
        buttonImage = @"arrow.clockwise";
    } else {
        self.titleLabel.text = kLang(@"pet_profiles_empty_title");
        self.subtitleLabel.text = kLang(@"pet_profiles_empty_subtitle");
        self.iconView.image = [[UIImage systemImageNamed:@"pawprint.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        buttonTitle = kLang(@"pet_add_title");
        buttonImage = @"plus";
    }

    UIButtonConfiguration *configuration = self.actionButton.configuration;
    configuration.title = buttonTitle ?: @"";
    configuration.image = [UIImage systemImageNamed:buttonImage
                                  withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14.0
                                                                                                   weight:UIImageSymbolWeightSemibold]];
    self.actionButton.configuration = configuration;
    self.actionButton.accessibilityLabel = buttonTitle;
    self.isAccessibilityElement = NO;
    [self applyTheme];
}

- (void)pp_actionTapped
{
    if (self.actionHandler) self.actionHandler();
}

- (void)applyTheme
{
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    self.iconContainer.backgroundColor = [PPPetsUIBrandColor() colorWithAlphaComponent:isDark ? 0.15 : 0.09];
    self.iconView.tintColor = PPPetsUIBrandColor();
    self.titleLabel.textColor = AppPrimaryTextClr;
    self.subtitleLabel.textColor = PPPetsUISecondaryTextColor();
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self applyTheme];
    }
}

@end

#pragma mark - Section Header

@interface PPPetProfilesSectionHeaderView : UITableViewHeaderFooterView
@property (nonatomic, strong) UIView *contentContainer;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *countLabel;
- (void)configureWithCount:(NSInteger)count;
- (void)applyTheme;
@end

@implementation PPPetProfilesSectionHeaderView

- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithReuseIdentifier:reuseIdentifier];
    if (!self) return nil;

    self.contentView.backgroundColor = UIColor.clearColor;
    self.backgroundView = [[UIView alloc] init];
    self.backgroundView.backgroundColor = UIColor.clearColor;

    self.contentContainer = [[UIView alloc] init];
    self.contentContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.contentContainer];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = PPPetProfilesScaledFont([GM boldFontWithSize:19.0], UIFontTextStyleHeadline);
    self.titleLabel.adjustsFontForContentSizeCategory = YES;
    self.titleLabel.text = kLang(@"pet_profiles_manage");
    self.titleLabel.numberOfLines = 2;
    [self.contentContainer addSubview:self.titleLabel];

    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.font = PPPetProfilesScaledFont([GM MidFontWithSize:12.5], UIFontTextStyleFootnote);
    self.subtitleLabel.adjustsFontForContentSizeCategory = YES;
    self.subtitleLabel.text = kLang(@"pet_profiles_section_subtitle");
    self.subtitleLabel.numberOfLines = 0;
    [self.contentContainer addSubview:self.subtitleLabel];

    self.countLabel = [[UILabel alloc] init];
    self.countLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.countLabel.font = PPPetProfilesScaledFont([GM boldFontWithSize:12.0], UIFontTextStyleFootnote);
    self.countLabel.adjustsFontForContentSizeCategory = YES;
    self.countLabel.textAlignment = NSTextAlignmentCenter;
    PPPetProfilesApplyContinuousCorners(self.countLabel, 14.0);
    [self.contentContainer addSubview:self.countLabel];

    NSLayoutConstraint *preferredWidth = [self.contentContainer.widthAnchor constraintEqualToAnchor:self.contentView.widthAnchor
                                                                                              constant:-(PPPetProfilesHorizontalMargin * 2.0)];
    preferredWidth.priority = 999;
    [NSLayoutConstraint activateConstraints:@[
        [self.contentContainer.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12.0],
        [self.contentContainer.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8.0],
        [self.contentContainer.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [self.contentContainer.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.contentView.leadingAnchor constant:PPPetProfilesHorizontalMargin],
        [self.contentContainer.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-PPPetProfilesHorizontalMargin],
        [self.contentContainer.widthAnchor constraintLessThanOrEqualToConstant:PPPetProfilesMaximumContentWidth],
        preferredWidth,

        [self.titleLabel.topAnchor constraintEqualToAnchor:self.contentContainer.topAnchor],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor],
        [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.countLabel.leadingAnchor constant:-12.0],

        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:3.0],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.countLabel.leadingAnchor constant:-12.0],
        [self.subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentContainer.bottomAnchor],

        [self.countLabel.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor],
        [self.countLabel.centerYAnchor constraintEqualToAnchor:self.contentContainer.centerYAnchor],
        [self.countLabel.widthAnchor constraintGreaterThanOrEqualToConstant:34.0],
        [self.countLabel.heightAnchor constraintGreaterThanOrEqualToConstant:28.0],
    ]];

    [self applyTheme];
    return self;
}

- (void)configureWithCount:(NSInteger)count
{
    self.contentContainer.semanticContentAttribute = PPPetsCurrentSemanticAttribute();
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.countLabel.text = [NSString stringWithFormat:@"%ld", (long)MAX(0, count)];
    self.countLabel.accessibilityLabel = [NSString stringWithFormat:kLang(@"pet_profiles_profile_count_accessibility_format"),
                                          (long)MAX(0, count)];
    [self applyTheme];
}

- (void)applyTheme
{
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    self.titleLabel.textColor = AppPrimaryTextClr;
    self.subtitleLabel.textColor = PPPetsUISecondaryTextColor();
    self.countLabel.textColor = PPPetsUIBrandColor();
    self.countLabel.backgroundColor = [PPPetsUIBrandColor() colorWithAlphaComponent:isDark ? 0.14 : 0.09];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self applyTheme];
    }
}

@end

#pragma mark - View Controller

@interface PPPetProfilesViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, copy) NSArray<PPPetProfile *> *pets;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL isFetching;
@property (nonatomic, assign) BOOL reloadRequestedWhileFetching;
@property (nonatomic, strong) NSError *loadError;
@property (nonatomic, strong) CAGradientLayer *backgroundGradientLayer;

@property (nonatomic, strong) UIView *headerRootView;
@property (nonatomic, strong) UIView *heroCardView;
@property (nonatomic, strong) UIView *heroMaterialView;
@property (nonatomic, strong) CAGradientLayer *heroGradientLayer;
@property (nonatomic, strong) UIView *heroAccentBarView;
@property (nonatomic, strong) UIStackView *heroTextStack;
@property (nonatomic, strong) UILabel *heroEyebrowLabel;
@property (nonatomic, strong) UILabel *heroTitleLabel;
@property (nonatomic, strong) UILabel *heroSubtitleLabel;
@property (nonatomic, strong) UIView *heroImageContainer;
@property (nonatomic, strong) UIImageView *heroImageView;
@property (nonatomic, strong) UIView *heroDefaultBadgeView;
@property (nonatomic, strong) UIImageView *heroDefaultBadgeIcon;
@property (nonatomic, strong) UIActivityIndicatorView *heroActivityIndicator;
@property (nonatomic, strong) UIView *heroMetricsView;
@property (nonatomic, strong) UIView *heroMetricsTopRule;
@property (nonatomic, strong) UIView *heroMetricsDivider;
@property (nonatomic, strong) UILabel *heroProfilesValueLabel;
@property (nonatomic, strong) UILabel *heroProfilesCaptionLabel;
@property (nonatomic, strong) UILabel *heroVaccinesValueLabel;
@property (nonatomic, strong) UILabel *heroVaccinesCaptionLabel;
@property (nonatomic, strong) UIStackView *heroActionsStack;
@property (nonatomic, strong) UIButton *heroAddButton;
@property (nonatomic, strong) UIButton *heroRemindersButton;
@property (nonatomic, strong) NSURLSessionDataTask *heroImageTask;
@property (nonatomic, copy) NSString *heroRepresentedImageURL;
@property (nonatomic, copy) NSArray<NSLayoutConstraint *> *heroStandardIdentityConstraints;
@property (nonatomic, copy) NSArray<NSLayoutConstraint *> *heroAccessibilityIdentityConstraints;

@property (nonatomic, assign) BOOL didPrepareEntrance;
@property (nonatomic, assign) BOOL didRunEntrance;
@property (nonatomic, strong) NSMutableSet<NSString *> *animatedRowIdentifiers;
@end

@implementation PPPetProfilesViewController

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.semanticContentAttribute = PPPetsCurrentSemanticAttribute();
    self.title = kLang(@"pet_profiles_title");
    self.pets = @[];
    self.isLoading = YES;
    self.animatedRowIdentifiers = [NSMutableSet set];

    [self pp_configureNavigation];
    [self pp_buildBackground];
    [self pp_buildTableView];
    [self pp_buildHeroHeader];
    [self pp_installRefreshControl];
    [self pp_applyTheme];
    [self pp_updateHeroContent];
    [self pp_prepareEntranceIfNeeded];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.view.semanticContentAttribute = PPPetsCurrentSemanticAttribute();
    self.tableView.semanticContentAttribute = PPPetsCurrentSemanticAttribute();
    [self pp_applyTheme];
    [self pp_updateHeroContent];
    [self pp_prepareEntranceIfNeeded];
    [self pp_reload];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self pp_runEntranceIfNeeded];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    self.backgroundGradientLayer.frame = self.view.bounds;
    [self pp_updateHeaderLayout];
    [self pp_layoutHeroMaterial];
}

- (void)dealloc
{
    [self.heroImageTask cancel];
}

#pragma mark - Build

- (void)pp_configureNavigation
{
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithImage:PPSYSImage(PPChevronName)
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(pp_handleBack)];
    backItem.accessibilityLabel = kLang(@"Back");
    self.navigationItem.leftBarButtonItem = backItem;

    UIBarButtonItem *addItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"plus"]
                                                                style:UIBarButtonItemStylePlain
                                                               target:self
                                                               action:@selector(pp_addPet)];
    addItem.tintColor = PPPetsUIBrandColor();
    addItem.accessibilityLabel = kLang(@"pet_add_title");

    UIBarButtonItem *remindersItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"bell"]
                                                                      style:UIBarButtonItemStylePlain
                                                                     target:self
                                                                     action:@selector(pp_openReminders)];
    remindersItem.tintColor = PPPetsUIBrandColor();
    remindersItem.accessibilityLabel = kLang(@"pet_reminders_tab");
    self.navigationItem.rightBarButtonItems = @[addItem, remindersItem];
}

- (void)pp_buildBackground
{
    self.view.backgroundColor = PPPetsUICanvasColor();
    self.view.opaque = YES;
    self.backgroundGradientLayer = [CAGradientLayer layer];
    self.backgroundGradientLayer.drawsAsynchronously = YES;
    self.backgroundGradientLayer.startPoint = CGPointMake(0.5, 0.0);
    self.backgroundGradientLayer.endPoint = CGPointMake(0.5, 1.0);
    self.backgroundGradientLayer.locations = @[@0.0, @0.58, @1.0];
    [self.view.layer insertSublayer:self.backgroundGradientLayer atIndex:0];
}

- (void)pp_buildTableView
{
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.opaque = NO;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 128.0;
    self.tableView.sectionHeaderHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedSectionHeaderHeight = 74.0;
    self.tableView.contentInset = UIEdgeInsetsMake(0.0, 0.0, 28.0, 0.0);
    self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
    self.tableView.semanticContentAttribute = PPPetsCurrentSemanticAttribute();
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0.0;
    }
    [self.tableView registerClass:PPPetProfilesCardCell.class forCellReuseIdentifier:PPPetProfilesCardCellIdentifier];
    [self.tableView registerClass:PPPetProfilesSkeletonCell.class forCellReuseIdentifier:PPPetProfilesSkeletonCellIdentifier];
    [self.tableView registerClass:PPPetProfilesStateCell.class forCellReuseIdentifier:PPPetProfilesStateCellIdentifier];
    [self.tableView registerClass:PPPetProfilesSectionHeaderView.class
       forHeaderFooterViewReuseIdentifier:PPPetProfilesSectionHeaderIdentifier];
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)pp_buildHeroHeader
{
    self.headerRootView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, CGRectGetWidth(self.view.bounds), 1.0)];
    self.headerRootView.backgroundColor = UIColor.clearColor;
    self.headerRootView.semanticContentAttribute = PPPetsCurrentSemanticAttribute();

    self.heroCardView = [[UIView alloc] init];
    self.heroCardView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroCardView.semanticContentAttribute = PPPetsCurrentSemanticAttribute();
    [self.headerRootView addSubview:self.heroCardView];

    self.heroMaterialView = [[UIView alloc] init];
    self.heroMaterialView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroMaterialView.clipsToBounds = YES;
    [self.heroCardView addSubview:self.heroMaterialView];

    self.heroGradientLayer = [CAGradientLayer layer];
    self.heroGradientLayer.drawsAsynchronously = YES;
    [self.heroMaterialView.layer addSublayer:self.heroGradientLayer];

    self.heroAccentBarView = [[UIView alloc] init];
    self.heroAccentBarView.translatesAutoresizingMaskIntoConstraints = NO;
    PPPetProfilesApplyContinuousCorners(self.heroAccentBarView, 2.0);
    [self.heroCardView addSubview:self.heroAccentBarView];

    self.heroEyebrowLabel = [[UILabel alloc] init];
    self.heroEyebrowLabel.font = PPPetProfilesScaledFont([GM boldFontWithSize:11.5], UIFontTextStyleCaption1);
    self.heroEyebrowLabel.adjustsFontForContentSizeCategory = YES;
    self.heroEyebrowLabel.text = kLang(@"pet_profiles_manage");
    self.heroEyebrowLabel.numberOfLines = 1;

    self.heroTitleLabel = [[UILabel alloc] init];
    self.heroTitleLabel.font = PPPetProfilesScaledFont([GM boldFontWithSize:29.0], UIFontTextStyleTitle1);
    self.heroTitleLabel.adjustsFontForContentSizeCategory = YES;
    self.heroTitleLabel.text = kLang(@"pet_profiles_title");
    self.heroTitleLabel.numberOfLines = 0;

    self.heroSubtitleLabel = [[UILabel alloc] init];
    self.heroSubtitleLabel.font = PPPetProfilesScaledFont([GM MidFontWithSize:14.0], UIFontTextStyleBody);
    self.heroSubtitleLabel.adjustsFontForContentSizeCategory = YES;
    self.heroSubtitleLabel.text = kLang(@"pet_profiles_subtitle");
    self.heroSubtitleLabel.numberOfLines = 0;

    self.heroTextStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.heroEyebrowLabel,
        self.heroTitleLabel,
        self.heroSubtitleLabel,
    ]];
    self.heroTextStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroTextStack.axis = UILayoutConstraintAxisVertical;
    self.heroTextStack.alignment = UIStackViewAlignmentFill;
    self.heroTextStack.spacing = 6.0;
    self.heroTextStack.semanticContentAttribute = PPPetsCurrentSemanticAttribute();
    [self.heroTextStack setCustomSpacing:9.0 afterView:self.heroTitleLabel];
    [self.heroCardView addSubview:self.heroTextStack];

    self.heroImageContainer = [[UIView alloc] init];
    self.heroImageContainer.translatesAutoresizingMaskIntoConstraints = NO;
    PPPetProfilesApplyContinuousCorners(self.heroImageContainer, 24.0);
    [self.heroCardView addSubview:self.heroImageContainer];

    self.heroImageView = [[UIImageView alloc] init];
    self.heroImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.heroImageView.clipsToBounds = YES;
    self.heroImageView.isAccessibilityElement = YES;
    PPPetProfilesApplyContinuousCorners(self.heroImageView, 21.0);
    [self.heroImageContainer addSubview:self.heroImageView];

    self.heroDefaultBadgeView = [[UIView alloc] init];
    self.heroDefaultBadgeView.translatesAutoresizingMaskIntoConstraints = NO;
    PPPetProfilesApplyContinuousCorners(self.heroDefaultBadgeView, 14.0);
    self.heroDefaultBadgeView.hidden = YES;
    self.heroDefaultBadgeView.isAccessibilityElement = YES;
    self.heroDefaultBadgeView.accessibilityLabel = kLang(@"pet_profiles_default_badge");
    [self.heroImageContainer addSubview:self.heroDefaultBadgeView];

    self.heroDefaultBadgeIcon = [[UIImageView alloc] initWithImage:
                                 [[UIImage systemImageNamed:@"star.fill"
                                          withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:12.0
                                                                                                           weight:UIImageSymbolWeightBold]]
                                  imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    self.heroDefaultBadgeIcon.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroDefaultBadgeIcon.contentMode = UIViewContentModeScaleAspectFit;
    [self.heroDefaultBadgeView addSubview:self.heroDefaultBadgeIcon];

    self.heroActivityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.heroActivityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroActivityIndicator.hidesWhenStopped = YES;
    [self.heroImageContainer addSubview:self.heroActivityIndicator];

    self.heroMetricsView = [[UIView alloc] init];
    self.heroMetricsView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroMetricsView.semanticContentAttribute = PPPetsCurrentSemanticAttribute();
    [self.heroCardView addSubview:self.heroMetricsView];

    self.heroMetricsTopRule = [[UIView alloc] init];
    self.heroMetricsTopRule.translatesAutoresizingMaskIntoConstraints = NO;
    [self.heroMetricsView addSubview:self.heroMetricsTopRule];

    self.heroMetricsDivider = [[UIView alloc] init];
    self.heroMetricsDivider.translatesAutoresizingMaskIntoConstraints = NO;
    [self.heroMetricsView addSubview:self.heroMetricsDivider];

    self.heroProfilesValueLabel = [self pp_metricValueLabel];
    self.heroProfilesCaptionLabel = [self pp_metricCaptionLabelWithText:kLang(@"pet_profiles_profile_count_label")];
    self.heroVaccinesValueLabel = [self pp_metricValueLabel];
    self.heroVaccinesCaptionLabel = [self pp_metricCaptionLabelWithText:kLang(@"pet_profiles_vaccination_count_label")];
    [self.heroMetricsView addSubview:self.heroProfilesValueLabel];
    [self.heroMetricsView addSubview:self.heroProfilesCaptionLabel];
    [self.heroMetricsView addSubview:self.heroVaccinesValueLabel];
    [self.heroMetricsView addSubview:self.heroVaccinesCaptionLabel];

    self.heroAddButton = PPPetProfilesActionButton(kLang(@"pet_add_title"), @"plus", YES);
    [self.heroAddButton addTarget:self action:@selector(pp_addPet) forControlEvents:UIControlEventTouchUpInside];
    self.heroRemindersButton = PPPetProfilesActionButton(kLang(@"pet_reminders_tab"), @"bell", NO);
    [self.heroRemindersButton addTarget:self action:@selector(pp_openReminders) forControlEvents:UIControlEventTouchUpInside];
    self.heroActionsStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.heroAddButton, self.heroRemindersButton]];
    self.heroActionsStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroActionsStack.axis = UILayoutConstraintAxisVertical;
    self.heroActionsStack.alignment = UIStackViewAlignmentFill;
    self.heroActionsStack.distribution = UIStackViewDistributionFillEqually;
    self.heroActionsStack.spacing = 8.0;
    self.heroActionsStack.semanticContentAttribute = PPPetsCurrentSemanticAttribute();
    [self.heroCardView addSubview:self.heroActionsStack];

    NSLayoutConstraint *metricsTopFromText = [self.heroMetricsView.topAnchor constraintEqualToAnchor:self.heroTextStack.bottomAnchor constant:22.0];
    metricsTopFromText.priority = UILayoutPriorityDefaultHigh;
    NSLayoutConstraint *preferredWidth = [self.heroCardView.widthAnchor constraintEqualToAnchor:self.headerRootView.widthAnchor
                                                                                        constant:-(PPPetProfilesHorizontalMargin * 2.0)];
    preferredWidth.priority = 999;

    self.heroStandardIdentityConstraints = @[
        [self.heroImageContainer.trailingAnchor constraintEqualToAnchor:self.heroCardView.trailingAnchor constant:-22.0],
        [self.heroTextStack.topAnchor constraintEqualToAnchor:self.heroCardView.topAnchor constant:28.0],
        [self.heroTextStack.leadingAnchor constraintEqualToAnchor:self.heroCardView.leadingAnchor constant:22.0],
        [self.heroTextStack.trailingAnchor constraintEqualToAnchor:self.heroImageContainer.leadingAnchor constant:-16.0],
    ];
    self.heroAccessibilityIdentityConstraints = @[
        [self.heroImageContainer.centerXAnchor constraintEqualToAnchor:self.heroCardView.centerXAnchor],
        [self.heroTextStack.topAnchor constraintEqualToAnchor:self.heroImageContainer.bottomAnchor constant:18.0],
        [self.heroTextStack.leadingAnchor constraintEqualToAnchor:self.heroCardView.leadingAnchor constant:22.0],
        [self.heroTextStack.trailingAnchor constraintEqualToAnchor:self.heroCardView.trailingAnchor constant:-22.0],
    ];

    [NSLayoutConstraint activateConstraints:@[
        [self.heroCardView.topAnchor constraintEqualToAnchor:self.headerRootView.topAnchor constant:10.0],
        [self.heroCardView.bottomAnchor constraintEqualToAnchor:self.headerRootView.bottomAnchor constant:-18.0],
        [self.heroCardView.centerXAnchor constraintEqualToAnchor:self.headerRootView.centerXAnchor],
        [self.heroCardView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.headerRootView.leadingAnchor constant:PPPetProfilesHorizontalMargin],
        [self.heroCardView.trailingAnchor constraintLessThanOrEqualToAnchor:self.headerRootView.trailingAnchor constant:-PPPetProfilesHorizontalMargin],
        [self.heroCardView.widthAnchor constraintLessThanOrEqualToConstant:PPPetProfilesMaximumContentWidth],
        preferredWidth,

        [self.heroMaterialView.topAnchor constraintEqualToAnchor:self.heroCardView.topAnchor],
        [self.heroMaterialView.leadingAnchor constraintEqualToAnchor:self.heroCardView.leadingAnchor],
        [self.heroMaterialView.trailingAnchor constraintEqualToAnchor:self.heroCardView.trailingAnchor],
        [self.heroMaterialView.bottomAnchor constraintEqualToAnchor:self.heroCardView.bottomAnchor],

        [self.heroAccentBarView.topAnchor constraintEqualToAnchor:self.heroCardView.topAnchor],
        [self.heroAccentBarView.leadingAnchor constraintEqualToAnchor:self.heroCardView.leadingAnchor constant:34.0],
        [self.heroAccentBarView.widthAnchor constraintEqualToConstant:44.0],
        [self.heroAccentBarView.heightAnchor constraintEqualToConstant:4.0],

        [self.heroImageContainer.topAnchor constraintEqualToAnchor:self.heroCardView.topAnchor constant:28.0],
        [self.heroImageContainer.widthAnchor constraintEqualToConstant:100.0],
        [self.heroImageContainer.heightAnchor constraintEqualToConstant:100.0],

        [self.heroImageView.topAnchor constraintEqualToAnchor:self.heroImageContainer.topAnchor constant:3.0],
        [self.heroImageView.leadingAnchor constraintEqualToAnchor:self.heroImageContainer.leadingAnchor constant:3.0],
        [self.heroImageView.trailingAnchor constraintEqualToAnchor:self.heroImageContainer.trailingAnchor constant:-3.0],
        [self.heroImageView.bottomAnchor constraintEqualToAnchor:self.heroImageContainer.bottomAnchor constant:-3.0],

        [self.heroDefaultBadgeView.trailingAnchor constraintEqualToAnchor:self.heroImageContainer.trailingAnchor constant:3.0],
        [self.heroDefaultBadgeView.bottomAnchor constraintEqualToAnchor:self.heroImageContainer.bottomAnchor constant:3.0],
        [self.heroDefaultBadgeView.widthAnchor constraintEqualToConstant:28.0],
        [self.heroDefaultBadgeView.heightAnchor constraintEqualToConstant:28.0],
        [self.heroDefaultBadgeIcon.centerXAnchor constraintEqualToAnchor:self.heroDefaultBadgeView.centerXAnchor],
        [self.heroDefaultBadgeIcon.centerYAnchor constraintEqualToAnchor:self.heroDefaultBadgeView.centerYAnchor],
        [self.heroDefaultBadgeIcon.widthAnchor constraintEqualToConstant:14.0],
        [self.heroDefaultBadgeIcon.heightAnchor constraintEqualToConstant:14.0],

        [self.heroActivityIndicator.centerXAnchor constraintEqualToAnchor:self.heroImageContainer.centerXAnchor],
        [self.heroActivityIndicator.centerYAnchor constraintEqualToAnchor:self.heroImageContainer.centerYAnchor],

        metricsTopFromText,
        [self.heroMetricsView.topAnchor constraintGreaterThanOrEqualToAnchor:self.heroImageContainer.bottomAnchor constant:20.0],
        [self.heroMetricsView.leadingAnchor constraintEqualToAnchor:self.heroCardView.leadingAnchor constant:22.0],
        [self.heroMetricsView.trailingAnchor constraintEqualToAnchor:self.heroCardView.trailingAnchor constant:-22.0],
        [self.heroMetricsView.heightAnchor constraintGreaterThanOrEqualToConstant:68.0],

        [self.heroMetricsTopRule.topAnchor constraintEqualToAnchor:self.heroMetricsView.topAnchor],
        [self.heroMetricsTopRule.leadingAnchor constraintEqualToAnchor:self.heroMetricsView.leadingAnchor],
        [self.heroMetricsTopRule.trailingAnchor constraintEqualToAnchor:self.heroMetricsView.trailingAnchor],
        [self.heroMetricsTopRule.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],

        [self.heroMetricsDivider.centerXAnchor constraintEqualToAnchor:self.heroMetricsView.centerXAnchor],
        [self.heroMetricsDivider.topAnchor constraintEqualToAnchor:self.heroMetricsTopRule.bottomAnchor constant:12.0],
        [self.heroMetricsDivider.bottomAnchor constraintEqualToAnchor:self.heroMetricsView.bottomAnchor constant:-8.0],
        [self.heroMetricsDivider.widthAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],

        [self.heroProfilesValueLabel.topAnchor constraintEqualToAnchor:self.heroMetricsTopRule.bottomAnchor constant:10.0],
        [self.heroProfilesValueLabel.leadingAnchor constraintEqualToAnchor:self.heroMetricsView.leadingAnchor],
        [self.heroProfilesValueLabel.trailingAnchor constraintEqualToAnchor:self.heroMetricsDivider.leadingAnchor constant:-14.0],
        [self.heroProfilesCaptionLabel.topAnchor constraintEqualToAnchor:self.heroProfilesValueLabel.bottomAnchor constant:2.0],
        [self.heroProfilesCaptionLabel.leadingAnchor constraintEqualToAnchor:self.heroProfilesValueLabel.leadingAnchor],
        [self.heroProfilesCaptionLabel.trailingAnchor constraintEqualToAnchor:self.heroProfilesValueLabel.trailingAnchor],
        [self.heroProfilesCaptionLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.heroMetricsView.bottomAnchor constant:-6.0],

        [self.heroVaccinesValueLabel.topAnchor constraintEqualToAnchor:self.heroProfilesValueLabel.topAnchor],
        [self.heroVaccinesValueLabel.leadingAnchor constraintEqualToAnchor:self.heroMetricsDivider.trailingAnchor constant:14.0],
        [self.heroVaccinesValueLabel.trailingAnchor constraintEqualToAnchor:self.heroMetricsView.trailingAnchor],
        [self.heroVaccinesCaptionLabel.topAnchor constraintEqualToAnchor:self.heroVaccinesValueLabel.bottomAnchor constant:2.0],
        [self.heroVaccinesCaptionLabel.leadingAnchor constraintEqualToAnchor:self.heroVaccinesValueLabel.leadingAnchor],
        [self.heroVaccinesCaptionLabel.trailingAnchor constraintEqualToAnchor:self.heroVaccinesValueLabel.trailingAnchor],
        [self.heroVaccinesCaptionLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.heroMetricsView.bottomAnchor constant:-6.0],

        [self.heroActionsStack.topAnchor constraintEqualToAnchor:self.heroMetricsView.bottomAnchor constant:16.0],
        [self.heroActionsStack.leadingAnchor constraintEqualToAnchor:self.heroCardView.leadingAnchor constant:22.0],
        [self.heroActionsStack.trailingAnchor constraintEqualToAnchor:self.heroCardView.trailingAnchor constant:-22.0],
        [self.heroActionsStack.bottomAnchor constraintEqualToAnchor:self.heroCardView.bottomAnchor constant:-22.0],
    ]];

    [self pp_updateHeroIdentityLayoutForContentSizeCategory];
    self.tableView.tableHeaderView = self.headerRootView;
    [self pp_applyHeroMaterial];
    [self pp_updateHeaderLayout];
}

- (UILabel *)pp_metricValueLabel
{
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = PPPetProfilesScaledFont([GM boldFontWithSize:20.0], UIFontTextStyleTitle3);
    label.adjustsFontForContentSizeCategory = YES;
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 1;
    return label;
}

- (UILabel *)pp_metricCaptionLabelWithText:(NSString *)text
{
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = PPPetProfilesScaledFont([GM MidFontWithSize:11.5], UIFontTextStyleCaption1);
    label.adjustsFontForContentSizeCategory = YES;
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    label.text = text;
    return label;
}

- (void)pp_installRefreshControl
{
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    refreshControl.tintColor = PPPetsUIBrandColor();
    refreshControl.accessibilityLabel = kLang(@"pet_profiles_refresh_accessibility");
    [refreshControl addTarget:self action:@selector(pp_pullRefresh) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = refreshControl;
}

#pragma mark - Theme and Layout

- (void)pp_applyTheme
{
    UIColor *canvas = PPPetsUICanvasColor();
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    UIColor *middle = PPMarketplaceHeroCardBlend(canvas,
                                                 PPMarketplaceHeroCardSurfaceBaseColor(self.traitCollection),
                                                 isDark ? 0.10 : 0.24,
                                                 self.traitCollection);
    UIColor *tail = PPMarketplaceHeroCardBlend(canvas,
                                               PPPetsUIBrandColor(),
                                               isDark ? 0.018 : 0.026,
                                               self.traitCollection);
    self.view.backgroundColor = canvas;
    self.backgroundGradientLayer.colors = @[
        (id)[canvas resolvedColorWithTraitCollection:self.traitCollection].CGColor,
        (id)[middle resolvedColorWithTraitCollection:self.traitCollection].CGColor,
        (id)[tail resolvedColorWithTraitCollection:self.traitCollection].CGColor,
    ];
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.backgroundView = nil;
    [self pp_applyHeroMaterial];

    for (UITableViewCell *cell in self.tableView.visibleCells) {
        if ([cell respondsToSelector:@selector(applyTheme)]) {
            [(id)cell applyTheme];
        }
    }
    for (UIView *header in self.tableView.subviews) {
        if ([header isKindOfClass:PPPetProfilesSectionHeaderView.class]) {
            [(PPPetProfilesSectionHeaderView *)header applyTheme];
        }
    }
}

- (void)pp_applyHeroMaterial
{
    if (!self.heroCardView) return;
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    UIColor *accent = PPPetsUIBrandColor();
    PPMarketplaceHeroCardApplySurfaceChrome(self.heroCardView, 28.0, self.traitCollection);
    self.heroCardView.layer.shadowOpacity = isDark ? 0.22 : 0.07;
    self.heroCardView.layer.shadowRadius = isDark ? 18.0 : 20.0;
    self.heroCardView.layer.shadowOffset = CGSizeMake(0.0, isDark ? 8.0 : 10.0);

    self.heroMaterialView.backgroundColor = UIColor.clearColor;
    PPPetProfilesApplyContinuousCorners(self.heroMaterialView, 28.0);
    PPMarketplaceHeroCardConfigureSurfaceGradient(self.heroGradientLayer,
                                                  accent,
                                                  self.traitCollection,
                                                  Language.isRTL);
    self.heroAccentBarView.backgroundColor = [accent colorWithAlphaComponent:0.62];
    self.heroEyebrowLabel.textColor = [accent colorWithAlphaComponent:0.94];
    self.heroTitleLabel.textColor = AppPrimaryTextClr;
    self.heroSubtitleLabel.textColor = PPPetsUISecondaryTextColor();
    self.heroImageContainer.backgroundColor = [accent colorWithAlphaComponent:isDark ? 0.13 : 0.075];
    self.heroImageContainer.layer.borderWidth = 1.0;
    self.heroImageContainer.layer.borderColor = [[accent colorWithAlphaComponent:isDark ? 0.20 : 0.11]
                                                  resolvedColorWithTraitCollection:self.traitCollection].CGColor;
    self.heroDefaultBadgeView.backgroundColor = UIColor.systemYellowColor;
    self.heroDefaultBadgeView.layer.borderWidth = 2.0;
    self.heroDefaultBadgeView.layer.borderColor = [PPMarketplaceHeroCardSurfaceBaseColor(self.traitCollection)
                                                    resolvedColorWithTraitCollection:self.traitCollection].CGColor;
    self.heroDefaultBadgeIcon.tintColor = UIColor.whiteColor;
    self.heroActivityIndicator.color = accent;

    UIColor *ruleColor = [PPMarketplaceHeroCardStrokeColor(self.traitCollection) colorWithAlphaComponent:isDark ? 0.88 : 0.72];
    self.heroMetricsTopRule.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.32];
    self.heroMetricsDivider.backgroundColor = ruleColor;
    self.heroProfilesValueLabel.textColor = AppPrimaryTextClr;
    self.heroVaccinesValueLabel.textColor = AppPrimaryTextClr;
    self.heroProfilesCaptionLabel.textColor = PPPetsUISecondaryTextColor();
    self.heroVaccinesCaptionLabel.textColor = PPPetsUISecondaryTextColor();
}

- (void)pp_layoutHeroMaterial
{
    self.heroGradientLayer.frame = self.heroMaterialView.bounds;
    self.heroGradientLayer.cornerRadius = self.heroMaterialView.layer.cornerRadius;
    if (!CGRectIsEmpty(self.heroCardView.bounds)) {
        self.heroCardView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.heroCardView.bounds
                                                                        cornerRadius:self.heroCardView.layer.cornerRadius].CGPath;
    }
}

- (void)pp_updateHeaderLayout
{
    if (!self.headerRootView || CGRectGetWidth(self.tableView.bounds) <= 0.0) return;

    CGFloat width = CGRectGetWidth(self.tableView.bounds);
    CGRect frame = self.headerRootView.frame;
    frame.size.width = width;
    self.headerRootView.frame = frame;
    [self.headerRootView setNeedsLayout];
    [self.headerRootView layoutIfNeeded];

    CGFloat height = [self.headerRootView systemLayoutSizeFittingSize:CGSizeMake(width, UILayoutFittingCompressedSize.height)
                                       withHorizontalFittingPriority:UILayoutPriorityRequired
                                             verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height;
    height = ceil(height);
    if (height > 0.0 && fabs(CGRectGetHeight(frame) - height) > 0.5) {
        frame.size.height = height;
        self.headerRootView.frame = frame;
        self.tableView.tableHeaderView = self.headerRootView;
    }
}

- (void)pp_updateHeroIdentityLayoutForContentSizeCategory
{
    BOOL usesAccessibilityLayout = UIContentSizeCategoryIsAccessibilityCategory(
        self.traitCollection.preferredContentSizeCategory);
    NSArray<NSLayoutConstraint *> *activeConstraints = usesAccessibilityLayout
        ? self.heroAccessibilityIdentityConstraints
        : self.heroStandardIdentityConstraints;
    NSArray<NSLayoutConstraint *> *inactiveConstraints = usesAccessibilityLayout
        ? self.heroStandardIdentityConstraints
        : self.heroAccessibilityIdentityConstraints;
    [NSLayoutConstraint deactivateConstraints:inactiveConstraints];
    [NSLayoutConstraint activateConstraints:activeConstraints];
}

#pragma mark - Content State

- (PPPetProfile *)pp_featuredPet
{
    for (PPPetProfile *pet in self.pets) {
        if (pet.isDefaultPet) return pet;
    }
    return self.pets.firstObject;
}

- (NSInteger)pp_totalVaccinationCount
{
    NSInteger count = 0;
    for (PPPetProfile *pet in self.pets) {
        count += pet.vaccinations.count;
    }
    return count;
}

- (void)pp_updateHeroContent
{
    self.heroTextStack.semanticContentAttribute = PPPetsCurrentSemanticAttribute();
    self.heroActionsStack.semanticContentAttribute = PPPetsCurrentSemanticAttribute();
    self.heroEyebrowLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.heroTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.heroSubtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.heroEyebrowLabel.text = kLang(@"pet_profiles_manage");
    self.heroTitleLabel.text = kLang(@"pet_profiles_title");
    self.heroSubtitleLabel.text = kLang(@"pet_profiles_subtitle");

    PPPetProfile *featuredPet = [self pp_featuredPet];
    NSInteger vaccinationCount = [self pp_totalVaccinationCount];
    self.heroProfilesValueLabel.text = self.isLoading ? @"--" : [NSString stringWithFormat:@"%ld", (long)self.pets.count];
    self.heroVaccinesValueLabel.text = self.isLoading ? @"--" : [NSString stringWithFormat:@"%ld", (long)vaccinationCount];

    [self.heroImageTask cancel];
    self.heroImageTask = nil;
    self.heroRepresentedImageURL = nil;
    self.heroDefaultBadgeView.hidden = !featuredPet.isDefaultPet;
    if (self.isLoading) {
        [self.heroActivityIndicator startAnimating];
        self.heroImageView.image = nil;
        self.heroImageView.isAccessibilityElement = YES;
        self.heroImageView.accessibilityLabel = kLang(@"Loading");
    } else {
        [self.heroActivityIndicator stopAnimating];
        if (featuredPet) {
            self.heroImageView.image = [PPModernAvatarRenderer avatarImageForName:(featuredPet.name ?: @"") size:116.0];
            self.heroImageView.accessibilityLabel = [NSString stringWithFormat:kLang(@"pet_profiles_image_accessibility_format"),
                                                     featuredPet.name ?: kLang(@"pet_unknown")];
            self.heroRepresentedImageURL = featuredPet.imageURL ?: @"";
            NSString *requestedURL = self.heroRepresentedImageURL;
            if (requestedURL.length > 0) {
                __weak typeof(self) weakSelf = self;
                self.heroImageTask = PPPetProfilesLoadImage(requestedURL, ^(UIImage *image) {
                    __strong typeof(weakSelf) self = weakSelf;
                    if (!self || ![self.heroRepresentedImageURL isEqualToString:requestedURL]) return;
                    [UIView transitionWithView:self.heroImageView
                                      duration:UIAccessibilityIsReduceMotionEnabled() ? 0.0 : 0.28
                                       options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowUserInteraction
                                    animations:^{
                        self.heroImageView.image = image;
                    } completion:nil];
                });
            }
        } else {
            self.heroImageView.image = [UIImage imageNamed:@"pawprintfill"];
            self.heroImageView.tintColor = PPPetsUIBrandColor();
            self.heroImageView.contentMode = UIViewContentModeCenter;
            self.heroImageView.isAccessibilityElement = NO;
        }
    }
    if (featuredPet) {
        self.heroImageView.contentMode = UIViewContentModeScaleAspectFill;
        self.heroImageView.isAccessibilityElement = YES;
    }
    [self pp_updateHeaderLayout];
}

- (void)pp_reload
{
    if (self.isFetching) {
        self.reloadRequestedWhileFetching = YES;
        [self.tableView.refreshControl endRefreshing];
        return;
    }

    self.isFetching = YES;
    if (self.pets.count == 0) {
        self.isLoading = YES;
        self.loadError = nil;
        [self pp_renderState];
    }

    __weak typeof(self) weakSelf = self;
    [[UserManager sharedManager] fetchPetProfilesForCurrentUserWithCompletion:^(NSArray<PPPetProfile *> *pets, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            self.isFetching = NO;
            self.isLoading = NO;
            [self.tableView.refreshControl endRefreshing];
            BOOL shouldReloadAgain = self.reloadRequestedWhileFetching;
            self.reloadRequestedWhileFetching = NO;

            if (error) {
                if (self.pets.count == 0) {
                    self.loadError = error;
                    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,
                                                    kLang(@"pet_profiles_error_title"));
                } else {
                    [PPHUD showError:kLang(@"pet_profiles_error_title")
                            subtitle:kLang(@"pet_profiles_error_subtitle")];
                }
                [self pp_renderState];
                if (shouldReloadAgain) [self pp_reload];
                return;
            }

            self.loadError = nil;
            self.pets = pets ?: @[];
            [self pp_renderState];
            if (shouldReloadAgain) [self pp_reload];
        });
    }];
}

- (void)pp_renderState
{
    [self pp_updateHeroContent];
    [self.tableView reloadData];
    [self.tableView layoutIfNeeded];
}

- (void)pp_pullRefresh
{
    [self pp_reload];
}

#pragma mark - Actions

- (void)pp_handleBack
{
    if (self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)pp_addPet
{
    PPPetProfileEditorViewController *editor = [[PPPetProfileEditorViewController alloc] initWithPet:nil];
    [self.navigationController pushViewController:editor animated:YES];
}

- (void)pp_openReminders
{
    PPPetRemindersViewController *reminders = [[PPPetRemindersViewController alloc] init];
    [self.navigationController pushViewController:reminders animated:YES];
}

- (void)pp_editPet:(PPPetProfile *)pet
{
    if (!pet) return;
    PPPetProfileEditorViewController *editor = [[PPPetProfileEditorViewController alloc] initWithPet:pet];
    [self.navigationController pushViewController:editor animated:YES];
}

- (void)pp_deletePet:(PPPetProfile *)pet
{
    if (pet.petID.length == 0) return;
    __weak typeof(self) weakSelf = self;
    [PPAlertHelper showConfirmationIn:self
                                title:kLang(@"pet_delete_confirm_title")
                             subtitle:kLang(@"pet_delete_confirm_msg")
                        confirmButton:kLang(@"Delete")
                         cancelButton:kLang(@"Cancel")
                                 icon:[UIImage systemImageNamed:@"trash.circle.fill"]
                         confirmBlock:^(__unused NSString *text, __unused BOOL checked) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [PPHUD showIndeterminateIn:self.view title:kLang(@"Please wait") subtitle:nil];
        [[UserManager sharedManager] deletePetProfileWithID:pet.petID completion:^(NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;
                if (error) {
                    [PPHUD showError:kLang(@"SomethingWentWrong") subtitle:error.localizedDescription];
                    return;
                }
                [PPHUD showSuccess:kLang(@"Done") subtitle:nil];
                UINotificationFeedbackGenerator *feedback = [[UINotificationFeedbackGenerator alloc] init];
                [feedback notificationOccurred:UINotificationFeedbackTypeSuccess];
                [self pp_reload];
            });
        }];
    } cancelBlock:nil];
}

- (void)pp_makeDefaultPet:(PPPetProfile *)pet
{
    if (pet.petID.length == 0 || pet.isDefaultPet) return;
    __weak typeof(self) weakSelf = self;
    [PPHUD showIndeterminateIn:self.view title:kLang(@"Please wait") subtitle:nil];
    [[UserManager sharedManager] setDefaultPetProfileID:pet.petID completion:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            if (error) {
                [PPHUD showError:kLang(@"SomethingWentWrong") subtitle:error.localizedDescription];
                return;
            }
            [PPHUD showSuccess:kLang(@"Done") subtitle:nil];
            UINotificationFeedbackGenerator *feedback = [[UINotificationFeedbackGenerator alloc] init];
            [feedback notificationOccurred:UINotificationFeedbackTypeSuccess];
            [self pp_reload];
        });
    }];
}

#pragma mark - Table Data Source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (self.isLoading) return 4;
    if (self.loadError || self.pets.count == 0) return 1;
    return self.pets.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.isLoading) {
        return [tableView dequeueReusableCellWithIdentifier:PPPetProfilesSkeletonCellIdentifier
                                               forIndexPath:indexPath];
    }

    if (self.loadError || self.pets.count == 0) {
        PPPetProfilesStateCell *cell = [tableView dequeueReusableCellWithIdentifier:PPPetProfilesStateCellIdentifier
                                                                       forIndexPath:indexPath];
        __weak typeof(self) weakSelf = self;
        PPPetProfilesStateKind kind = self.loadError ? PPPetProfilesStateKindError : PPPetProfilesStateKindEmpty;
        [cell configureForKind:kind actionHandler:^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            kind == PPPetProfilesStateKindError ? [self pp_reload] : [self pp_addPet];
        }];
        return cell;
    }

    PPPetProfilesCardCell *cell = [tableView dequeueReusableCellWithIdentifier:PPPetProfilesCardCellIdentifier
                                                                  forIndexPath:indexPath];
    PPPetProfile *pet = self.pets[indexPath.row];
    __weak typeof(self) weakSelf = self;
    [cell configureWithPet:pet
        makeDefaultHandler:pet.isDefaultPet ? nil : ^{
            [weakSelf pp_makeDefaultPet:pet];
        }
             deleteHandler:^{
        [weakSelf pp_deletePet:pet];
    }];
    return cell;
}

#pragma mark - Table Delegate

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return (!self.isLoading && !self.loadError && self.pets.count > 0) ? UITableViewAutomaticDimension : 0.01;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForHeaderInSection:(NSInteger)section
{
    return 74.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (self.isLoading || self.loadError || self.pets.count == 0) return nil;
    PPPetProfilesSectionHeaderView *header = [tableView dequeueReusableHeaderFooterViewWithIdentifier:PPPetProfilesSectionHeaderIdentifier];
    [header configureWithCount:self.pets.count];
    return header;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.isLoading || self.loadError || indexPath.row >= (NSInteger)self.pets.count) return;
    [self pp_editPet:self.pets[indexPath.row]];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0))
{
    if (self.isLoading || self.loadError || indexPath.row >= (NSInteger)self.pets.count) return nil;
    PPPetProfile *pet = self.pets[indexPath.row];
    __weak typeof(self) weakSelf = self;

    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                                title:kLang(@"Delete")
                                                                              handler:^(__unused UIContextualAction *action,
                                                                                        __unused UIView *sourceView,
                                                                                        void (^completionHandler)(BOOL)) {
        [weakSelf pp_deletePet:pet];
        completionHandler(YES);
    }];
    deleteAction.image = [UIImage systemImageNamed:@"trash.fill"];

    NSMutableArray<UIContextualAction *> *actions = [NSMutableArray arrayWithObject:deleteAction];
    if (!pet.isDefaultPet) {
        UIContextualAction *defaultAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                                    title:kLang(@"pet_default_action")
                                                                                  handler:^(__unused UIContextualAction *action,
                                                                                            __unused UIView *sourceView,
                                                                                            void (^completionHandler)(BOOL)) {
            [weakSelf pp_makeDefaultPet:pet];
            completionHandler(YES);
        }];
        defaultAction.backgroundColor = UIColor.systemYellowColor;
        defaultAction.image = [UIImage systemImageNamed:@"star.fill"];
        [actions addObject:defaultAction];
    }

    UISwipeActionsConfiguration *configuration = [UISwipeActionsConfiguration configurationWithActions:actions];
    configuration.performsFirstActionWithFullSwipe = NO;
    return configuration;
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView
    contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath
                                       point:(CGPoint)point API_AVAILABLE(ios(13.0))
{
    if (self.isLoading || self.loadError || indexPath.row >= (NSInteger)self.pets.count) return nil;
    PPPetProfile *pet = self.pets[indexPath.row];
    __weak typeof(self) weakSelf = self;
    return [UIContextMenuConfiguration configurationWithIdentifier:pet.petID
                                                   previewProvider:nil
                                                    actionProvider:^UIMenu *(__unused NSArray<UIMenuElement *> *suggestedActions) {
        UIAction *editAction = [UIAction actionWithTitle:kLang(@"Edit")
                                                  image:[UIImage systemImageNamed:@"pencil"]
                                             identifier:nil
                                                handler:^(__unused UIAction *action) {
            [weakSelf pp_editPet:pet];
        }];
        NSMutableArray<UIMenuElement *> *actions = [NSMutableArray arrayWithObject:editAction];
        if (!pet.isDefaultPet) {
            UIAction *defaultAction = [UIAction actionWithTitle:kLang(@"pet_default_action")
                                                         image:[UIImage systemImageNamed:@"star"]
                                                    identifier:nil
                                                       handler:^(__unused UIAction *action) {
                [weakSelf pp_makeDefaultPet:pet];
            }];
            [actions addObject:defaultAction];
        }
        UIAction *deleteAction = [UIAction actionWithTitle:kLang(@"Delete")
                                                    image:[UIImage systemImageNamed:@"trash"]
                                               identifier:nil
                                                  handler:^(__unused UIAction *action) {
            [weakSelf pp_deletePet:pet];
        }];
        deleteAction.attributes = UIMenuElementAttributesDestructive;
        [actions addObject:deleteAction];
        return [UIMenu menuWithTitle:@"" children:actions];
    }];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.isLoading) return;

    NSString *identifier = nil;
    if (self.loadError) {
        identifier = @"state.error";
    } else if (self.pets.count == 0) {
        identifier = @"state.empty";
    } else if (indexPath.row < (NSInteger)self.pets.count) {
        PPPetProfile *pet = self.pets[indexPath.row];
        identifier = pet.petID.length > 0 ? pet.petID : [NSString stringWithFormat:@"pet.%ld", (long)indexPath.row];
    }
    if (identifier.length == 0 || [self.animatedRowIdentifiers containsObject:identifier]) return;
    [self.animatedRowIdentifiers addObject:identifier];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        cell.alpha = 1.0;
        cell.transform = CGAffineTransformIdentity;
        return;
    }

    cell.alpha = 0.0;
    cell.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 12.0),
                                             CGAffineTransformMakeScale(0.992, 0.992));
    NSTimeInterval delay = MIN(indexPath.row * 0.045, 0.18);
    [UIView animateWithDuration:0.34
                          delay:delay
         usingSpringWithDamping:0.90
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        cell.alpha = 1.0;
        cell.transform = CGAffineTransformIdentity;
    } completion:nil];
}

#pragma mark - Entrance Motion

- (void)pp_prepareEntranceIfNeeded
{
    if (self.didRunEntrance || !self.heroCardView) return;
    self.didPrepareEntrance = YES;
    self.heroCardView.alpha = 0.0;
    self.heroCardView.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 10.0),
                                                          CGAffineTransformMakeScale(0.992, 0.992));
    self.heroTextStack.alpha = 0.0;
    self.heroTextStack.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
    self.heroImageContainer.alpha = 0.0;
    self.heroImageContainer.transform = CGAffineTransformMakeScale(1.04, 1.04);
    self.heroMetricsView.alpha = 0.0;
    self.heroMetricsView.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
    self.heroActionsStack.alpha = 0.0;
    self.heroActionsStack.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
}

- (void)pp_runEntranceIfNeeded
{
    if (self.didRunEntrance || !self.didPrepareEntrance) return;
    self.didRunEntrance = YES;
    [self.view layoutIfNeeded];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self pp_applyFinalEntranceState];
        return;
    }

    [UIView animateWithDuration:0.40 delay:0.0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        self.heroCardView.alpha = 1.0;
        self.heroCardView.transform = CGAffineTransformIdentity;
    } completion:nil];
    [UIView animateWithDuration:0.34 delay:0.05 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        self.heroImageContainer.alpha = 1.0;
        self.heroImageContainer.transform = CGAffineTransformIdentity;
    } completion:nil];
    [UIView animateWithDuration:0.36 delay:0.09 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        self.heroTextStack.alpha = 1.0;
        self.heroTextStack.transform = CGAffineTransformIdentity;
    } completion:nil];
    [UIView animateWithDuration:0.38 delay:0.14 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        self.heroMetricsView.alpha = 1.0;
        self.heroMetricsView.transform = CGAffineTransformIdentity;
    } completion:nil];
    [UIView animateWithDuration:0.44
                          delay:0.18
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.heroActionsStack.alpha = 1.0;
        self.heroActionsStack.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_applyFinalEntranceState
{
    self.heroCardView.alpha = 1.0;
    self.heroCardView.transform = CGAffineTransformIdentity;
    self.heroTextStack.alpha = 1.0;
    self.heroTextStack.transform = CGAffineTransformIdentity;
    self.heroImageContainer.alpha = 1.0;
    self.heroImageContainer.transform = CGAffineTransformIdentity;
    self.heroMetricsView.alpha = 1.0;
    self.heroMetricsView.transform = CGAffineTransformIdentity;
    self.heroActionsStack.alpha = 1.0;
    self.heroActionsStack.transform = CGAffineTransformIdentity;
}

#pragma mark - Traits

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    BOOL appearanceChanged = [self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection];
    BOOL contentSizeChanged = ![self.traitCollection.preferredContentSizeCategory
                                isEqualToString:previousTraitCollection.preferredContentSizeCategory];
    if (appearanceChanged || contentSizeChanged) {
        if (contentSizeChanged) [self pp_updateHeroIdentityLayoutForContentSizeCategory];
        [self pp_applyTheme];
        [self pp_updateHeroContent];
        if (contentSizeChanged) [self.tableView reloadData];
        [self pp_updateHeaderLayout];
    }
}

@end
