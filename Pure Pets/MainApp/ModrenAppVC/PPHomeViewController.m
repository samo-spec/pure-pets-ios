

#import "MainBannerModel.h"
#import "PetAdoptCollectionViewCell.h"
#import "PPBannerCollectionCell.h"
#import "PPBannersCollection.h"
#import "PPBannersManager.h"
#import "PPBannerViewModel.h"
#import "PPCategoryCardCell.h"
#import "PPHomeFunc.h"
#import "PPHomeViewController.h"
#import "PPSPinnerView.h"
#import "PPDataViewInput.h"
#import "PPDataViewVC.h"
#import "PPVetLocator.h"
#import "PPBrowseHistoryManager.h"
#import "PPImageLoaderManager.h"
#import "SearchCacheManager.h"
#import "PPHomeLayoutManager.h"
#import "AdoptPetsViewController.h"
#import "PPAdSharingHelper.h"
#import "AppClasses.h"
#import "CartManager.h"
#import "CountryModel.h"
#import "OrderDetailsViewController.h"
#import "OrderHistoryViewController.h"
#import "PPOrder.h"
#import "PPHomeHeroCell.h"
#import "PPHUD.h"
#import "PPCommerceFeedbackManager.h"
#import "LocationPickerViewController.h"
#import <AudioToolbox/AudioToolbox.h>
#import <CoreLocation/CoreLocation.h>
#import <FirebaseAuth/FirebaseAuth.h>
#import <FirebaseFirestore/FirebaseFirestore.h>
#import <SafariServices/SafariServices.h>
#import <TargetConditionals.h>
#import <math.h>
#import <float.h>

static inline UIColor *PPHomeOrderBlendColor(UIColor *baseColor, UIColor *fallbackColor, CGFloat alpha)
{
    UIColor *resolved = baseColor ?: fallbackColor ?: UIColor.systemBlueColor;
    return [resolved colorWithAlphaComponent:alpha];
}

@interface PPHomeOrderStatusCell : UICollectionViewCell
+ (NSString *)reuseIdentifier;
- (void)configurePlaceholderExpanded:(BOOL)expanded;
- (void)configureWithOrderReference:(NSString *)orderReference
                   orderKickerTitle:(NSString *)orderKickerTitle
                    previewImageURLs:(NSArray<NSString *> *)previewImageURLs
                               meta:(NSString *)meta
                        statusTitle:(NSString *)statusTitle
                         statusHint:(NSString *)statusHint
                           progress:(double)progress
                        footerText:(NSString *)footerText
                        statusColor:(UIColor *)statusColor
                     statusIconName:(NSString *)statusIconName
                        actionTitle:(NSString *)actionTitle
                           expanded:(BOOL)expanded;
- (void)setExpandedState:(BOOL)expanded animated:(BOOL)animated;
- (void)refreshDecorativeLayersForCurrentBounds;
@property (nonatomic, copy, nullable) void (^onTrackTap)(void);
@property (nonatomic, copy, nullable) void (^onHistoryTap)(void);
@end

@interface PPHomeOrderStatusCell ()
@property (nonatomic, strong) UIView *shadowView;
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIVisualEffectView *materialView;
@property (nonatomic, strong) UIView *overlayView;
@property (nonatomic, strong) CAGradientLayer *overlayGradientLayer;
@property (nonatomic, strong) UIView *chipView;
@property (nonatomic, strong) UIImageView *chipIconView;
@property (nonatomic, strong) UILabel *chipLabel;
@property (nonatomic, strong) UILabel *orderKickerLabel;
@property (nonatomic, strong) UILabel *orderLabel;
@property (nonatomic, strong) UILabel *metaLabel;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, strong) UIView *progressTrackView;
@property (nonatomic, strong) UIView *progressFillView;
@property (nonatomic, strong) NSLayoutConstraint *progressFillWidthConstraint;
@property (nonatomic, strong) UILabel *footerLabel;
@property (nonatomic, strong) UIView *actionRailView;
@property (nonatomic, strong) UIStackView *actionsStackView;
@property (nonatomic, strong) UIButton *trackButton;
@property (nonatomic, strong) UIButton *historyButton;
@property (nonatomic, strong) UIView *collapsedContentView;
@property (nonatomic, strong) UIView *collapsedIconBadgeView;
@property (nonatomic, strong) UIImageView *collapsedIconView;
@property (nonatomic, copy) NSArray<NSString *> *previewImageURLs;
@property (nonatomic, copy) NSArray<UIImageView *> *collapsedPreviewImageViews;
@property (nonatomic, strong) UIStackView *collapsedTextStackView;
@property (nonatomic, strong) UILabel *collapsedKickerLabel;
@property (nonatomic, strong) UILabel *collapsedOrderLabel;
@property (nonatomic, strong) UILabel *collapsedSummaryLabel;
@property (nonatomic, strong) UIView *collapsedStatusPillView;
@property (nonatomic, strong) UILabel *collapsedStatusPillLabel;
@property (nonatomic, strong) UIView *collapsedChevronContainerView;
@property (nonatomic, strong) UIVisualEffectView *collapsedChevronMaterialView;
@property (nonatomic, strong) UIView *collapsedChevronTintView;
@property (nonatomic, strong) UIImageView *collapsedChevronView;
@property (nonatomic, strong) NSLayoutConstraint *collapsedChevronTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *collapsedChevronCenterYConstraint;
@property (nonatomic, copy) NSArray<NSLayoutConstraint *> *expandedConstraints;
@property (nonatomic, copy) NSArray<NSLayoutConstraint *> *collapsedConstraints;
@property (nonatomic, strong) UIColor *currentStatusColor;
@property (nonatomic, assign) BOOL showsExpandedState;
@end

@implementation PPHomeOrderStatusCell

+ (NSString *)reuseIdentifier
{
    return @"PPHomeOrderStatusCell";
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;

    [self pp_setupUI];
    return self;
}

- (void)pp_setupUI
{
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.clipsToBounds = NO;

    self.shadowView = [[UIView alloc] init];
    self.shadowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.shadowView.backgroundColor = UIColor.clearColor;
    self.shadowView.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:1.0].CGColor;
    self.shadowView.layer.shadowOpacity = PPIOS26() ? 0.16 : 0.10;
    self.shadowView.layer.shadowRadius = 24.0;
    self.shadowView.layer.shadowOffset = CGSizeMake(0.0, 14.0);
    self.shadowView.layer.cornerRadius = 30.0;
    if (@available(iOS 13.0, *)) {
        self.shadowView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.contentView addSubview:self.shadowView];

    self.surfaceView = [[UIView alloc] init];
    self.surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.surfaceView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:(PPIOS26() ? 0.10 : 0.94)];
    self.surfaceView.layer.cornerRadius = 30.0;
    self.surfaceView.layer.borderWidth = 1.0;
    self.surfaceView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:(PPIOS26() ? 0.18 : 0.18)].CGColor;
    self.surfaceView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.shadowView addSubview:self.surfaceView];

    UIBlurEffectStyle blurStyle = UIBlurEffectStyleSystemThinMaterial;
    if (@available(iOS 13.0, *)) {
        blurStyle = UIBlurEffectStyleSystemChromeMaterial;
    }
    self.materialView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:blurStyle]];
    self.materialView.translatesAutoresizingMaskIntoConstraints = NO;
    self.materialView.userInteractionEnabled = NO;
    [self.surfaceView addSubview:self.materialView];

    self.overlayView = [[UIView alloc] init];
    self.overlayView.translatesAutoresizingMaskIntoConstraints = NO;
    self.overlayView.userInteractionEnabled = NO;
    self.overlayView.backgroundColor = UIColor.clearColor;
    self.overlayView.layer.masksToBounds = YES;
    [self.surfaceView addSubview:self.overlayView];

    self.overlayGradientLayer = [CAGradientLayer layer];
    self.overlayGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    self.overlayGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    self.overlayGradientLayer.locations = @[@0.0, @0.38, @1.0];
    self.overlayGradientLayer.needsDisplayOnBoundsChange = YES;
    [self.overlayView.layer addSublayer:self.overlayGradientLayer];

    self.chipView = [[UIView alloc] init];
    self.chipView.translatesAutoresizingMaskIntoConstraints = NO;
    self.chipView.layer.cornerRadius = 15.0;
    self.chipView.layer.masksToBounds = YES;
    [self.surfaceView addSubview:self.chipView];

    self.chipIconView = [[UIImageView alloc] init];
    self.chipIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.chipIconView.contentMode = UIViewContentModeScaleToFill;
    [self.chipView addSubview:self.chipIconView];

    self.chipLabel = [[UILabel alloc] init];
    self.chipLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.chipLabel.font = [GM boldFontWithSize:12] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    [self.chipView addSubview:self.chipLabel];

    self.orderKickerLabel = [[UILabel alloc] init];
    self.orderKickerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.orderKickerLabel.font = [GM MidFontWithSize:11] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    self.orderKickerLabel.textColor = UIColor.secondaryLabelColor;
    self.orderKickerLabel.numberOfLines = 1;
    self.orderKickerLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.surfaceView addSubview:self.orderKickerLabel];

    self.orderLabel = [[UILabel alloc] init];
    self.orderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.orderLabel.font = [GM boldFontWithSize:20] ?: [UIFont systemFontOfSize:20.0 weight:UIFontWeightBold];
    self.orderLabel.textColor = UIColor.labelColor;
    self.orderLabel.numberOfLines = 1;
    self.orderLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.surfaceView addSubview:self.orderLabel];

    self.metaLabel = [[UILabel alloc] init];
    self.metaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.metaLabel.font = [GM MidFontWithSize:12] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    self.metaLabel.textColor = UIColor.secondaryLabelColor;
    self.metaLabel.numberOfLines = 1;
    self.metaLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.surfaceView addSubview:self.metaLabel];

    self.hintLabel = [[UILabel alloc] init];
    self.hintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.hintLabel.font = [GM MidFontWithSize:14] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    self.hintLabel.textColor = UIColor.labelColor;
    self.hintLabel.numberOfLines = 2;
    self.hintLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.surfaceView addSubview:self.hintLabel];

    self.progressTrackView = [[UIView alloc] init];
    self.progressTrackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressTrackView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:(PPIOS26() ? 0.16 : 0.38)];
    self.progressTrackView.layer.cornerRadius = 4.0;
    self.progressTrackView.layer.masksToBounds = YES;
    [self.surfaceView addSubview:self.progressTrackView];

    self.progressFillView = [[UIView alloc] init];
    self.progressFillView.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressFillView.layer.cornerRadius = 4.0;
    self.progressFillView.layer.masksToBounds = YES;
    [self.progressTrackView addSubview:self.progressFillView];

    self.footerLabel = [[UILabel alloc] init];
    self.footerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.footerLabel.font = [GM MidFontWithSize:11] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    self.footerLabel.textColor = UIColor.tertiaryLabelColor;
    self.footerLabel.numberOfLines = 1;
    self.footerLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.surfaceView addSubview:self.footerLabel];

    self.actionRailView = [[UIView alloc] init];
    self.actionRailView.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionRailView.layer.cornerRadius = 20.0;
    self.actionRailView.layer.borderWidth = 1.0;
    self.actionRailView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.actionRailView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.surfaceView addSubview:self.actionRailView];

    self.actionsStackView = [[UIStackView alloc] init];
    self.actionsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionsStackView.axis = UILayoutConstraintAxisHorizontal;
    self.actionsStackView.alignment = UIStackViewAlignmentFill;
    self.actionsStackView.distribution = UIStackViewDistributionFillEqually;
    self.actionsStackView.spacing = 8.0;
    [self.actionRailView addSubview:self.actionsStackView];

    self.trackButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.trackButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.trackButton.layer.cornerRadius = 16.0;
    self.trackButton.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.trackButton.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.trackButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.trackButton.titleLabel.minimumScaleFactor = 0.82;
    [self.trackButton addTarget:self action:@selector(pp_handleTrackTap) forControlEvents:UIControlEventTouchUpInside];
    [self.actionsStackView addArrangedSubview:self.trackButton];

    self.historyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.historyButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.historyButton.layer.cornerRadius = 16.0;
    self.historyButton.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.historyButton.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.historyButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.historyButton.titleLabel.minimumScaleFactor = 0.82;
    [self.historyButton addTarget:self action:@selector(pp_handleHistoryTap) forControlEvents:UIControlEventTouchUpInside];
    [self.actionsStackView addArrangedSubview:self.historyButton];

    self.collapsedContentView = [[UIView alloc] init];
    self.collapsedContentView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collapsedContentView.backgroundColor = UIColor.clearColor;
    [self.surfaceView addSubview:self.collapsedContentView];

    self.collapsedIconBadgeView = [[UIView alloc] init];
    self.collapsedIconBadgeView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collapsedIconBadgeView.layer.cornerRadius = 14.0;
    self.collapsedIconBadgeView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.collapsedIconBadgeView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.collapsedContentView addSubview:self.collapsedIconBadgeView];

    self.collapsedIconView = [[UIImageView alloc] init];
    self.collapsedIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collapsedIconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.collapsedIconBadgeView addSubview:self.collapsedIconView];

    NSMutableArray<UIImageView *> *collapsedPreviewImageViews = [NSMutableArray array];
    for (NSInteger index = 0; index < 3; index++) {
        UIImageView *previewImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        previewImageView.translatesAutoresizingMaskIntoConstraints = YES;
        previewImageView.contentMode = UIViewContentModeScaleAspectFill;
        previewImageView.clipsToBounds = YES;
        previewImageView.layer.masksToBounds = YES;
        previewImageView.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
        if (@available(iOS 13.0, *)) {
            previewImageView.layer.cornerCurve = kCACornerCurveContinuous;
        }
        previewImageView.hidden = YES;
        [self.collapsedIconBadgeView addSubview:previewImageView];
        [collapsedPreviewImageViews addObject:previewImageView];
    }
    self.collapsedPreviewImageViews = collapsedPreviewImageViews.copy;

    self.collapsedTextStackView = [[UIStackView alloc] init];
    self.collapsedTextStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collapsedTextStackView.axis = UILayoutConstraintAxisVertical;
    self.collapsedTextStackView.alignment = UIStackViewAlignmentFill;
    self.collapsedTextStackView.distribution = UIStackViewDistributionFill;
    self.collapsedTextStackView.spacing = 3.0;
    [self.collapsedContentView addSubview:self.collapsedTextStackView];

    self.collapsedKickerLabel = [[UILabel alloc] init];
    self.collapsedKickerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.collapsedKickerLabel.font = [GM MidFontWithSize:10] ?: [UIFont systemFontOfSize:10.0 weight:UIFontWeightSemibold];
    self.collapsedKickerLabel.textColor = UIColor.tertiaryLabelColor;
    self.collapsedKickerLabel.numberOfLines = 1;
    self.collapsedKickerLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.collapsedKickerLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.collapsedTextStackView addArrangedSubview:self.collapsedKickerLabel];

    self.collapsedOrderLabel = [[UILabel alloc] init];
    self.collapsedOrderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.collapsedOrderLabel.font = [GM boldFontWithSize:16] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    self.collapsedOrderLabel.textColor = UIColor.labelColor;
    self.collapsedOrderLabel.numberOfLines = 1;
    self.collapsedOrderLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.collapsedTextStackView addArrangedSubview:self.collapsedOrderLabel];

    self.collapsedSummaryLabel = [[UILabel alloc] init];
    self.collapsedSummaryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.collapsedSummaryLabel.font = [GM MidFontWithSize:12] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    self.collapsedSummaryLabel.textColor = UIColor.secondaryLabelColor;
    self.collapsedSummaryLabel.numberOfLines = 1;
    self.collapsedSummaryLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.collapsedSummaryLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.collapsedTextStackView addArrangedSubview:self.collapsedSummaryLabel];

    self.collapsedStatusPillView = [[UIView alloc] init];
    self.collapsedStatusPillView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collapsedStatusPillView.layer.cornerRadius = 14.0;
    self.collapsedStatusPillView.layer.masksToBounds = YES;
    [self.collapsedContentView addSubview:self.collapsedStatusPillView];

    self.collapsedStatusPillLabel = [[UILabel alloc] init];
    self.collapsedStatusPillLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.collapsedStatusPillLabel.font = [GM boldFontWithSize:11] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    self.collapsedStatusPillLabel.textAlignment = NSTextAlignmentCenter;
    [self.collapsedStatusPillView addSubview:self.collapsedStatusPillLabel];

    self.collapsedChevronContainerView = [[UIView alloc] init];
    self.collapsedChevronContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collapsedChevronContainerView.layer.cornerRadius = 17.0;
    self.collapsedChevronContainerView.layer.borderWidth = 1.0;
    self.collapsedChevronContainerView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.collapsedChevronContainerView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.surfaceView addSubview:self.collapsedChevronContainerView];

    UIBlurEffectStyle chevronBlurStyle = UIBlurEffectStyleSystemThinMaterial;
    if (@available(iOS 13.0, *)) {
        chevronBlurStyle = UIBlurEffectStyleSystemChromeMaterial;
    }
    self.collapsedChevronMaterialView =
        [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:chevronBlurStyle]];
    self.collapsedChevronMaterialView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collapsedChevronMaterialView.userInteractionEnabled = NO;
    [self.collapsedChevronContainerView addSubview:self.collapsedChevronMaterialView];

    self.collapsedChevronTintView = [[UIView alloc] init];
    self.collapsedChevronTintView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collapsedChevronTintView.userInteractionEnabled = NO;
    [self.collapsedChevronContainerView addSubview:self.collapsedChevronTintView];

    self.collapsedChevronView = [[UIImageView alloc] init];
    self.collapsedChevronView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collapsedChevronView.contentMode = UIViewContentModeScaleAspectFit;
    self.collapsedChevronView.tintColor = UIColor.labelColor;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *chevronConfig =
            [UIImageSymbolConfiguration configurationWithPointSize:11.0
                                                            weight:UIImageSymbolWeightBold
                                                             scale:UIImageSymbolScaleMedium];
        self.collapsedChevronView.preferredSymbolConfiguration = chevronConfig;
    }
    self.collapsedChevronView.image = [UIImage systemImageNamed:@"chevron.down"];
    [self.collapsedChevronContainerView addSubview:self.collapsedChevronView];

    self.progressFillWidthConstraint = [self.progressFillView.widthAnchor constraintEqualToConstant:0.0];
    self.collapsedChevronTopConstraint =
        [self.collapsedChevronContainerView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor constant:14.0];
    self.collapsedChevronCenterYConstraint =
        [self.collapsedChevronContainerView.centerYAnchor constraintEqualToAnchor:self.collapsedContentView.centerYAnchor];

    [NSLayoutConstraint activateConstraints:@[
        [self.shadowView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.shadowView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.shadowView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.shadowView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        [self.surfaceView.topAnchor constraintEqualToAnchor:self.shadowView.topAnchor],
        [self.surfaceView.leadingAnchor constraintEqualToAnchor:self.shadowView.leadingAnchor],
        [self.surfaceView.trailingAnchor constraintEqualToAnchor:self.shadowView.trailingAnchor],
        [self.surfaceView.bottomAnchor constraintEqualToAnchor:self.shadowView.bottomAnchor],
        [self.materialView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor],
        [self.materialView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor],
        [self.materialView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor],
        [self.materialView.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor],
        [self.overlayView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor],
        [self.overlayView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor],
        [self.overlayView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor],
        [self.overlayView.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor],
        [self.collapsedChevronContainerView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-14.0],
        [self.collapsedChevronContainerView.widthAnchor constraintEqualToConstant:34.0],
        [self.collapsedChevronContainerView.heightAnchor constraintEqualToConstant:34.0],
        [self.collapsedChevronMaterialView.topAnchor constraintEqualToAnchor:self.collapsedChevronContainerView.topAnchor],
        [self.collapsedChevronMaterialView.leadingAnchor constraintEqualToAnchor:self.collapsedChevronContainerView.leadingAnchor],
        [self.collapsedChevronMaterialView.trailingAnchor constraintEqualToAnchor:self.collapsedChevronContainerView.trailingAnchor],
        [self.collapsedChevronMaterialView.bottomAnchor constraintEqualToAnchor:self.collapsedChevronContainerView.bottomAnchor],
        [self.collapsedChevronTintView.topAnchor constraintEqualToAnchor:self.collapsedChevronContainerView.topAnchor],
        [self.collapsedChevronTintView.leadingAnchor constraintEqualToAnchor:self.collapsedChevronContainerView.leadingAnchor],
        [self.collapsedChevronTintView.trailingAnchor constraintEqualToAnchor:self.collapsedChevronContainerView.trailingAnchor],
        [self.collapsedChevronTintView.bottomAnchor constraintEqualToAnchor:self.collapsedChevronContainerView.bottomAnchor],
        [self.collapsedChevronView.centerXAnchor constraintEqualToAnchor:self.collapsedChevronContainerView.centerXAnchor],
        [self.collapsedChevronView.centerYAnchor constraintEqualToAnchor:self.collapsedChevronContainerView.centerYAnchor],
        [self.collapsedChevronView.widthAnchor constraintEqualToConstant:12.0],
        [self.collapsedChevronView.heightAnchor constraintEqualToConstant:12.0],
    ]];

    self.expandedConstraints = @[
        [self.chipView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor constant:16.0],
        [self.chipView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:18.0],
        [self.chipView.heightAnchor constraintEqualToConstant:30.0],
        [self.chipView.trailingAnchor constraintLessThanOrEqualToAnchor:self.collapsedChevronContainerView.leadingAnchor constant:-12.0],
        [self.chipIconView.leadingAnchor constraintEqualToAnchor:self.chipView.leadingAnchor constant:10.0],
        [self.chipIconView.centerYAnchor constraintEqualToAnchor:self.chipView.centerYAnchor],
        [self.chipIconView.widthAnchor constraintEqualToConstant:16.0],
        [self.chipIconView.heightAnchor constraintEqualToConstant:16.0],
        [self.chipLabel.leadingAnchor constraintEqualToAnchor:self.chipIconView.trailingAnchor constant:6.0],
        [self.chipLabel.trailingAnchor constraintEqualToAnchor:self.chipView.trailingAnchor constant:-12.0],
        [self.chipLabel.centerYAnchor constraintEqualToAnchor:self.chipView.centerYAnchor],
        [self.orderKickerLabel.topAnchor constraintEqualToAnchor:self.chipView.bottomAnchor constant:12.0],
        [self.orderKickerLabel.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:18.0],
        [self.orderKickerLabel.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-18.0],
        [self.orderLabel.topAnchor constraintEqualToAnchor:self.orderKickerLabel.bottomAnchor constant:2.0],
        [self.orderLabel.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:18.0],
        [self.orderLabel.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-18.0],
        [self.metaLabel.topAnchor constraintEqualToAnchor:self.orderLabel.bottomAnchor constant:4.0],
        [self.metaLabel.leadingAnchor constraintEqualToAnchor:self.orderLabel.leadingAnchor],
        [self.metaLabel.trailingAnchor constraintEqualToAnchor:self.orderLabel.trailingAnchor],
        [self.hintLabel.topAnchor constraintEqualToAnchor:self.metaLabel.bottomAnchor constant:8.0],
        [self.hintLabel.leadingAnchor constraintEqualToAnchor:self.orderLabel.leadingAnchor],
        [self.hintLabel.trailingAnchor constraintEqualToAnchor:self.orderLabel.trailingAnchor],
        [self.progressTrackView.topAnchor constraintEqualToAnchor:self.hintLabel.bottomAnchor constant:12.0],
        [self.progressTrackView.leadingAnchor constraintEqualToAnchor:self.orderLabel.leadingAnchor],
        [self.progressTrackView.trailingAnchor constraintEqualToAnchor:self.orderLabel.trailingAnchor],
        [self.progressTrackView.heightAnchor constraintEqualToConstant:8.0],
        [self.progressFillView.topAnchor constraintEqualToAnchor:self.progressTrackView.topAnchor],
        [self.progressFillView.leadingAnchor constraintEqualToAnchor:self.progressTrackView.leadingAnchor],
        [self.progressFillView.bottomAnchor constraintEqualToAnchor:self.progressTrackView.bottomAnchor],
        self.progressFillWidthConstraint,
        [self.footerLabel.topAnchor constraintEqualToAnchor:self.progressTrackView.bottomAnchor constant:10.0],
        [self.footerLabel.leadingAnchor constraintEqualToAnchor:self.orderLabel.leadingAnchor],
        [self.footerLabel.trailingAnchor constraintEqualToAnchor:self.orderLabel.trailingAnchor],
        [self.actionRailView.topAnchor constraintEqualToAnchor:self.footerLabel.bottomAnchor constant:14.0],
        [self.actionRailView.leadingAnchor constraintEqualToAnchor:self.orderLabel.leadingAnchor],
        [self.actionRailView.trailingAnchor constraintEqualToAnchor:self.orderLabel.trailingAnchor],
        [self.actionRailView.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor constant:-16.0],
        [self.actionRailView.heightAnchor constraintEqualToConstant:44.0],
        [self.actionsStackView.leadingAnchor constraintEqualToAnchor:self.actionRailView.leadingAnchor constant:4.0],
        [self.actionsStackView.trailingAnchor constraintEqualToAnchor:self.actionRailView.trailingAnchor constant:-4.0],
        [self.actionsStackView.topAnchor constraintEqualToAnchor:self.actionRailView.topAnchor constant:4.0],
        [self.actionsStackView.bottomAnchor constraintEqualToAnchor:self.actionRailView.bottomAnchor constant:-4.0],
    ];

    self.collapsedConstraints = @[
        [self.collapsedContentView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor constant:12.0],
        [self.collapsedContentView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:16.0],
        [self.collapsedContentView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-16.0],
        [self.collapsedContentView.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor constant:-12.0],
        [self.collapsedIconBadgeView.leadingAnchor constraintEqualToAnchor:self.collapsedContentView.leadingAnchor],
        [self.collapsedIconBadgeView.centerYAnchor constraintEqualToAnchor:self.collapsedContentView.centerYAnchor],
        [self.collapsedIconBadgeView.widthAnchor constraintEqualToConstant:52.0],
        [self.collapsedIconBadgeView.heightAnchor constraintEqualToConstant:52.0],
        [self.collapsedIconView.centerXAnchor constraintEqualToAnchor:self.collapsedIconBadgeView.centerXAnchor],
        [self.collapsedIconView.centerYAnchor constraintEqualToAnchor:self.collapsedIconBadgeView.centerYAnchor],
        [self.collapsedIconView.widthAnchor constraintEqualToConstant:22.0],
        [self.collapsedIconView.heightAnchor constraintEqualToConstant:22.0],
        [self.collapsedStatusPillView.trailingAnchor constraintEqualToAnchor:self.collapsedChevronContainerView.leadingAnchor constant:-10.0],
        [self.collapsedStatusPillView.centerYAnchor constraintEqualToAnchor:self.collapsedContentView.centerYAnchor],
        [self.collapsedStatusPillView.heightAnchor constraintEqualToConstant:28.0],
        [self.collapsedStatusPillLabel.leadingAnchor constraintEqualToAnchor:self.collapsedStatusPillView.leadingAnchor constant:12.0],
        [self.collapsedStatusPillLabel.trailingAnchor constraintEqualToAnchor:self.collapsedStatusPillView.trailingAnchor constant:-12.0],
        [self.collapsedStatusPillLabel.centerYAnchor constraintEqualToAnchor:self.collapsedStatusPillView.centerYAnchor],
        [self.collapsedTextStackView.leadingAnchor constraintEqualToAnchor:self.collapsedIconBadgeView.trailingAnchor constant:12.0],
        [self.collapsedTextStackView.trailingAnchor constraintLessThanOrEqualToAnchor:self.collapsedStatusPillView.leadingAnchor constant:-12.0],
        [self.collapsedTextStackView.centerYAnchor constraintEqualToAnchor:self.collapsedContentView.centerYAnchor],
        [self.collapsedTextStackView.topAnchor constraintGreaterThanOrEqualToAnchor:self.collapsedContentView.topAnchor],
        [self.collapsedTextStackView.bottomAnchor constraintLessThanOrEqualToAnchor:self.collapsedContentView.bottomAnchor],
    ];

    [self pp_setShowsExpandedState:NO];
    [self pp_applyStatusColor:UIColor.systemBlueColor];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self pp_updateDecorativeLayers];
}

- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    CGSize previousSize = self.bounds.size;
    [super applyLayoutAttributes:layoutAttributes];
    if (!CGSizeEqualToSize(previousSize, self.bounds.size)) {
        [self setNeedsLayout];
    }
}

- (void)pp_updateDecorativeLayers
{
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.overlayView.layer.cornerRadius = self.surfaceView.layer.cornerRadius;
    self.overlayGradientLayer.frame = self.overlayView.bounds;
    self.overlayGradientLayer.cornerRadius = self.surfaceView.layer.cornerRadius;
    self.shadowView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.shadowView.bounds cornerRadius:self.surfaceView.layer.cornerRadius].CGPath;
    [self pp_updateCollapsedPreviewLayout];
    [CATransaction commit];
}

- (void)refreshDecorativeLayersForCurrentBounds
{
    [self pp_updateDecorativeLayers];
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.onTrackTap = nil;
    self.onHistoryTap = nil;
    self.trackButton.hidden = NO;
    self.historyButton.hidden = NO;
    self.trackButton.enabled = YES;
    self.historyButton.enabled = YES;
    self.actionRailView.alpha = 1.0;
    self.chipView.alpha = 1.0;
    self.collapsedContentView.alpha = 1.0;
    self.surfaceView.transform = CGAffineTransformIdentity;
    self.shadowView.transform = CGAffineTransformIdentity;
    self.collapsedContentView.transform = CGAffineTransformIdentity;
    self.collapsedChevronContainerView.transform = CGAffineTransformIdentity;
    self.collapsedChevronView.transform = CGAffineTransformIdentity;
    self.previewImageURLs = @[];
    self.collapsedIconView.hidden = NO;
    self.collapsedIconView.image = nil;
    for (UIImageView *imageView in self.collapsedPreviewImageViews ?: @[]) {
        imageView.hidden = YES;
        imageView.image = [UIImage imageNamed:@"placeholder"];
    }
}

- (void)configurePlaceholderExpanded:(BOOL)expanded
{
    [self configureWithOrderReference:@"----"
                      orderKickerTitle:(kLang(@"Home_CurrentOrdersTitle") ?: (kLang(@"Home_LastOrderTitle") ?: @""))
                       previewImageURLs:@[]
                                 meta:@"------"
                          statusTitle:(kLang(@"Pending") ?: @"Pending")
                           statusHint:@" "
                             progress:0.22
                           footerText:@" "
                          statusColor:UIColor.systemOrangeColor
                       statusIconName:@"clock.fill"
                          actionTitle:(kLang(@"order_action_track") ?: @"Track order")
                             expanded:expanded];
    self.orderLabel.alpha = 0.55;
    self.orderKickerLabel.alpha = 0.45;
    self.metaLabel.alpha = 0.45;
    self.hintLabel.alpha = 0.35;
    self.footerLabel.alpha = 0.35;
    self.chipView.alpha = 0.72;
    self.trackButton.hidden = YES;
    self.historyButton.hidden = YES;
    self.actionRailView.alpha = 0.45;
    self.collapsedContentView.alpha = 0.72;
}

- (void)configureWithOrderReference:(NSString *)orderReference
                   orderKickerTitle:(NSString *)orderKickerTitle
                    previewImageURLs:(NSArray<NSString *> *)previewImageURLs
                               meta:(NSString *)meta
                        statusTitle:(NSString *)statusTitle
                         statusHint:(NSString *)statusHint
                           progress:(double)progress
                         footerText:(NSString *)footerText
                        statusColor:(UIColor *)statusColor
                     statusIconName:(NSString *)statusIconName
                        actionTitle:(NSString *)actionTitle
                           expanded:(BOOL)expanded
{
    self.orderLabel.alpha = 1.0;
    self.orderKickerLabel.alpha = 1.0;
    self.metaLabel.alpha = 1.0;
    self.hintLabel.alpha = 1.0;
    self.footerLabel.alpha = 1.0;
    self.chipView.alpha = 1.0;
    self.collapsedContentView.alpha = 1.0;
    self.trackButton.hidden = NO;
    self.historyButton.hidden = NO;
    self.actionRailView.alpha = 1.0;

    self.contentView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.surfaceView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.actionRailView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.actionsStackView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.collapsedContentView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.collapsedTextStackView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.orderKickerLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.orderLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.metaLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.hintLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.footerLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.collapsedKickerLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.collapsedOrderLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.collapsedSummaryLabel.textAlignment = Language.alignmentForCurrentLanguage;

    self.orderKickerLabel.text = PPSafeString(orderKickerTitle);
    self.collapsedKickerLabel.text = PPSafeString(orderKickerTitle);
    self.orderLabel.text = PPSafeString(orderReference);
    self.metaLabel.text = PPSafeString(meta);
    self.hintLabel.text = PPSafeString(statusHint);
    self.footerLabel.text = PPSafeString(footerText);
    self.chipLabel.text = PPSafeString(statusTitle);
    self.chipIconView.image = [UIImage systemImageNamed:(statusIconName.length > 0 ? statusIconName : @"shippingbox.circle.fill")];
    self.collapsedOrderLabel.text = PPSafeString(orderReference);
    self.collapsedSummaryLabel.text = [self pp_collapsedSummaryWithMeta:PPSafeString(meta)
                                                             footerText:PPSafeString(footerText)
                                                             statusHint:PPSafeString(statusHint)];
    self.collapsedStatusPillLabel.text = PPSafeString(statusTitle);
    self.collapsedIconView.image = [UIImage systemImageNamed:(statusIconName.length > 0 ? statusIconName : @"shippingbox.circle.fill")];
    self.collapsedChevronView.image = [UIImage systemImageNamed:@"chevron.down"];

    [self pp_applyStatusColor:statusColor ?: UIColor.systemBlueColor];
    [self pp_applyPreviewImageURLs:previewImageURLs];
    [self pp_setShowsExpandedState:expanded];

    double clamped = fmax(0.08, fmin(1.0, progress));
    CGFloat fillWidth = CGRectGetWidth(self.progressTrackView.bounds) * clamped;
    if (fillWidth <= 0.0) {
        fillWidth = 96.0 * clamped;
    }
    self.progressFillWidthConstraint.constant = fillWidth;

    NSString *resolvedActionTitle = actionTitle.length > 0 ? actionTitle : (kLang(@"order_action_track") ?: @"Track order");
    NSString *historyActionTitle = kLang(@"OrderHistory") ?: @"Order history";
    [self pp_configureActionButton:self.trackButton
                             title:resolvedActionTitle
                          iconName:@"location.fill"
                       statusColor:statusColor
                         isPrimary:YES];
    [self pp_configureActionButton:self.historyButton
                             title:historyActionTitle
                          iconName:@"clock.fill"
                       statusColor:statusColor
                         isPrimary:NO];

    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)pp_applyPreviewImageURLs:(NSArray<NSString *> *)previewImageURLs
{
    NSMutableArray<NSString *> *resolvedURLs = [NSMutableArray array];
    NSMutableOrderedSet<NSString *> *dedupedURLs = [NSMutableOrderedSet orderedSet];
    for (NSString *rawURL in previewImageURLs ?: @[]) {
        NSString *value = [rawURL isKindOfClass:NSString.class]
            ? [rawURL stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
            : @"";
        if (value.length == 0 || [dedupedURLs containsObject:value]) {
            continue;
        }
        [dedupedURLs addObject:value];
        [resolvedURLs addObject:value];
        if (resolvedURLs.count >= self.collapsedPreviewImageViews.count) {
            break;
        }
    }

    BOOL didChangePreviewURLs = ![self.previewImageURLs isEqualToArray:resolvedURLs];
    self.previewImageURLs = resolvedURLs.copy;

    UIImage *placeholder = [UIImage imageNamed:@"placeholder"];
    BOOL hasPreviewImages = (self.previewImageURLs.count > 0);
    self.collapsedIconView.hidden = hasPreviewImages;

    for (NSInteger index = 0; index < self.collapsedPreviewImageViews.count; index++) {
        UIImageView *imageView = self.collapsedPreviewImageViews[index];
        imageView.hidden = (index >= (NSInteger)self.previewImageURLs.count);
        if (imageView.hidden) {
            imageView.image = nil;
            continue;
        }

        NSString *imageURL = self.previewImageURLs[index];
        if (didChangePreviewURLs) {
            imageView.image = placeholder;
        }
        if (imageURL.length > 0 && (didChangePreviewURLs || imageView.image == nil)) {
            [GM setImageFromUrlString:imageURL imageView:imageView phImage:@"placeholder"];
        }
    }

    if (hasPreviewImages) {
        self.collapsedIconBadgeView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:(PPIOS26() ? 0.18 : 0.94)];
        self.collapsedIconBadgeView.layer.borderWidth = 1.0;
        self.collapsedIconBadgeView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.64].CGColor;
    } else {
        self.collapsedIconBadgeView.layer.borderWidth = 0.0;
        self.collapsedIconBadgeView.layer.borderColor = UIColor.clearColor.CGColor;
    }

    [self setNeedsLayout];
}

- (void)pp_updateCollapsedPreviewLayout
{
    CGRect bounds = self.collapsedIconBadgeView.bounds;
    if (CGRectIsEmpty(bounds)) {
        return;
    }

    NSUInteger visibleCount = MIN(self.previewImageURLs.count, self.collapsedPreviewImageViews.count);
    CGFloat width = CGRectGetWidth(bounds);
    CGFloat height = CGRectGetHeight(bounds);

    for (UIImageView *imageView in self.collapsedPreviewImageViews ?: @[]) {
        imageView.hidden = YES;
    }

    if (visibleCount == 0) {
        return;
    }

    NSArray<NSValue *> *frames = @[];
    if (visibleCount == 1) {
        frames = @[[NSValue valueWithCGRect:CGRectMake(0.0, 0.0, width, height)]];
    } else if (visibleCount == 2) {
        CGFloat size = MIN(width, height) - 8.0;
        CGFloat y = floor((height - size) * 0.5);
        frames = @[
            [NSValue valueWithCGRect:CGRectMake(1.0, y - 2.0, size, size)],
            [NSValue valueWithCGRect:CGRectMake(width - size - 1.0, y + 2.0, size, size)]
        ];
    } else {
        CGFloat size = MIN(width, height) - 14.0;
        frames = @[
            [NSValue valueWithCGRect:CGRectMake(1.0, height - size - 1.0, size, size)],
            [NSValue valueWithCGRect:CGRectMake(floor((width - size) * 0.5), 1.0, size, size)],
            [NSValue valueWithCGRect:CGRectMake(width - size - 1.0, height - size - 1.0, size, size)]
        ];
    }

    for (NSInteger index = 0; index < (NSInteger)visibleCount; index++) {
        UIImageView *imageView = self.collapsedPreviewImageViews[index];
        imageView.hidden = NO;
        imageView.frame = frames[index].CGRectValue;
        imageView.layer.cornerRadius = MIN(8.0, floor(CGRectGetWidth(imageView.bounds) * 0.22));
    }
}

- (NSString *)pp_collapsedSummaryWithMeta:(NSString *)meta
                               footerText:(NSString *)footerText
                               statusHint:(NSString *)statusHint
{
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    if (meta.length > 0) {
        [parts addObject:meta];
    }
    if (footerText.length > 0) {
        [parts addObject:footerText];
    }
    if (parts.count == 0 && statusHint.length > 0) {
        [parts addObject:statusHint];
    }
    return [parts componentsJoinedByString:@" | "];
}

- (NSArray<UIView *> *)pp_expandedContentViews
{
    return @[
        self.chipView,
        self.orderKickerLabel,
        self.orderLabel,
        self.metaLabel,
        self.hintLabel,
        self.progressTrackView,
        self.footerLabel,
        self.actionRailView
    ];
}

- (void)pp_applyExpandedConstraintState:(BOOL)expanded
{
    if (expanded) {
        [NSLayoutConstraint deactivateConstraints:self.collapsedConstraints];
        [NSLayoutConstraint activateConstraints:self.expandedConstraints];
    } else {
        [NSLayoutConstraint deactivateConstraints:self.expandedConstraints];
        [NSLayoutConstraint activateConstraints:self.collapsedConstraints];
    }

    self.collapsedChevronTopConstraint.active = expanded;
    self.collapsedChevronCenterYConstraint.active = !expanded;
}

- (void)pp_updateChevronAppearanceForExpanded:(BOOL)expanded
{
    self.collapsedChevronView.transform = expanded
        ? CGAffineTransformMakeRotation((CGFloat)M_PI)
        : CGAffineTransformIdentity;
    self.collapsedChevronTintView.alpha = expanded ? 1.0 : 0.86;
}

- (void)pp_applyExpandedVisibilityState:(BOOL)expanded
{
    for (UIView *view in [self pp_expandedContentViews]) {
        view.hidden = !expanded;
        view.alpha = expanded ? 1.0 : 0.0;
        view.transform = CGAffineTransformIdentity;
    }

    self.collapsedContentView.hidden = expanded;
    self.collapsedContentView.alpha = expanded ? 0.0 : 1.0;
    self.collapsedContentView.transform = CGAffineTransformIdentity;
    [self pp_updateChevronAppearanceForExpanded:expanded];
}

- (void)setExpandedState:(BOOL)expanded animated:(BOOL)animated
{
    if (!animated || self.showsExpandedState == expanded || !self.window) {
        [self pp_setShowsExpandedState:expanded];
        return;
    }

    _showsExpandedState = expanded;

    UIImpactFeedbackGenerator *haptic =
        [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [haptic prepare];
    [haptic impactOccurred];

    NSArray<UIView *> *expandedViews = [self pp_expandedContentViews];

    [self.contentView layoutIfNeeded];

    for (UIView *view in expandedViews) {
        view.hidden = NO;
    }
    self.collapsedContentView.hidden = NO;

    if (expanded) {
        for (UIView *view in expandedViews) {
            view.alpha = 0.0;
            view.transform = CGAffineTransformMakeTranslation(0.0, 16.0);
        }
        self.collapsedContentView.alpha = 1.0;
        self.collapsedContentView.transform = CGAffineTransformIdentity;
        self.surfaceView.transform = CGAffineTransformMakeScale(0.98, 0.98);
    } else {
        for (UIView *view in expandedViews) {
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        }
        self.collapsedContentView.alpha = 0.0;
        self.collapsedContentView.transform = CGAffineTransformMakeTranslation(0.0, -12.0);
    }

    [self pp_applyExpandedConstraintState:expanded];

    // ── Phase 1: Main layout spring — drives constraint change + chevron ──
    [UIView animateWithDuration:0.52
                          delay:0.0
         usingSpringWithDamping:(expanded ? 0.78 : 0.88)
          initialSpringVelocity:(expanded ? 0.6 : 0.12)
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        [self.contentView layoutIfNeeded];
        self.surfaceView.transform = CGAffineTransformIdentity;
        [self pp_updateChevronAppearanceForExpanded:expanded];
        self.collapsedChevronContainerView.transform = CGAffineTransformMakeScale(1.12, 1.12);
    } completion:^(__unused BOOL finished) {
        [self pp_updateDecorativeLayers];

        // Chevron overshoot settle-back spring
        [UIView animateWithDuration:0.32
                              delay:0.0
             usingSpringWithDamping:0.50
              initialSpringVelocity:0.2
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.collapsedChevronContainerView.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];

    // ── Phase 2: Staggered content crossfade ──
    if (expanded) {
        [UIView animateWithDuration:0.18
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
            self.collapsedContentView.alpha = 0.0;
            self.collapsedContentView.transform = CGAffineTransformMakeTranslation(0.0, -10.0);
        } completion:nil];

        NSTimeInterval baseDelay = 0.05;
        NSTimeInterval step = 0.035;
        for (NSInteger i = 0; i < (NSInteger)expandedViews.count; i++) {
            UIView *view = expandedViews[i];
            [UIView animateWithDuration:0.40
                                  delay:baseDelay + step * i
                 usingSpringWithDamping:0.80
                  initialSpringVelocity:0.5
                                options:UIViewAnimationOptionBeginFromCurrentState
                             animations:^{
                view.alpha = 1.0;
                view.transform = CGAffineTransformIdentity;
            } completion:nil];
        }
    } else {
        NSInteger count = (NSInteger)expandedViews.count;
        NSTimeInterval step = 0.025;
        for (NSInteger i = 0; i < count; i++) {
            UIView *view = expandedViews[count - 1 - i];
            [UIView animateWithDuration:0.20
                                  delay:step * i
                                options:UIViewAnimationOptionCurveEaseIn
                             animations:^{
                view.alpha = 0.0;
                view.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
            } completion:nil];
        }

        [UIView animateWithDuration:0.34
                              delay:0.10
             usingSpringWithDamping:0.84
              initialSpringVelocity:0.4
                            options:UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            self.collapsedContentView.alpha = 1.0;
            self.collapsedContentView.transform = CGAffineTransformIdentity;
        } completion:nil];
    }

    // ── Phase 3: Final state cleanup after all animations settle ──
    NSTimeInterval settleTime = expanded ? 0.72 : 0.56;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(settleTime * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (self.showsExpandedState == expanded) {
            [self pp_applyExpandedVisibilityState:expanded];
        }
    });
}

- (void)pp_setShowsExpandedState:(BOOL)expanded
{
    _showsExpandedState = expanded;
    [self pp_applyExpandedConstraintState:expanded];
    [self pp_applyExpandedVisibilityState:expanded];
}

- (void)pp_configureActionButton:(UIButton *)button
                           title:(NSString *)title
                        iconName:(NSString *)iconName
                     statusColor:(UIColor *)statusColor
                       isPrimary:(BOOL)isPrimary
{
    UIColor *resolved = statusColor ?: AppPrimaryClr ?: UIColor.systemBlueColor;
    NSString *resolvedTitle = title.length > 0 ? title : @"";

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config =
            isPrimary ? [UIButtonConfiguration filledButtonConfiguration]
                      : [UIButtonConfiguration tintedButtonConfiguration];
        config.title = resolvedTitle;
        config.image = [UIImage systemImageNamed:iconName];
        config.imagePlacement = NSDirectionalRectEdgeLeading;
        config.imagePadding = 6.0;
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        config.contentInsets = NSDirectionalEdgeInsetsMake(8.0, 12.0, 8.0, 12.0);
        config.baseForegroundColor = isPrimary ? UIColor.whiteColor : resolved;
        config.baseBackgroundColor = isPrimary
            ? resolved
            : PPHomeOrderBlendColor(resolved, AppPrimaryClr, PPIOS26() ? 0.16 : 0.14);
        config.attributedTitle = [[NSAttributedString alloc] initWithString:resolvedTitle attributes:@{
            NSFontAttributeName: [GM boldFontWithSize:13] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold],
            NSForegroundColorAttributeName: isPrimary ? UIColor.whiteColor : resolved
        }];
        button.configuration = config;
        return;
    }

    [button setTitle:resolvedTitle forState:UIControlStateNormal];
    [button setTitleColor:isPrimary ? UIColor.whiteColor : resolved forState:UIControlStateNormal];
    button.backgroundColor = isPrimary ? resolved : PPHomeOrderBlendColor(resolved, AppPrimaryClr, 0.14);
    button.titleLabel.font = [GM boldFontWithSize:13] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    button.layer.borderWidth = isPrimary ? 0.0 : 1.0;
    button.layer.borderColor = PPHomeOrderBlendColor(resolved, AppPrimaryClr, 0.18).CGColor;
}

- (void)pp_applyStatusColor:(UIColor *)statusColor
{
    self.currentStatusColor = statusColor ?: UIColor.systemBlueColor;
    UIColor *resolved = self.currentStatusColor;
    UIColor *chipBackground = PPHomeOrderBlendColor(resolved, AppPrimaryClr, PPIOS26() ? 0.22 : 0.18);
    UIColor *softOverlay = PPHomeOrderBlendColor(resolved, AppPrimaryClr, PPIOS26() ? 0.22 : 0.16);

    self.chipView.backgroundColor = chipBackground;
    self.chipLabel.textColor = resolved;
    self.chipIconView.tintColor = resolved;
    self.progressFillView.backgroundColor = resolved;
    self.surfaceView.layer.borderColor = [PPHomeOrderBlendColor(resolved, AppPrimaryClr, PPIOS26() ? 0.18 : 0.12) CGColor];
    self.actionRailView.backgroundColor = PPHomeOrderBlendColor(resolved, AppPrimaryClr, PPIOS26() ? 0.12 : 0.08)  ;
    self.actionRailView.layer.borderColor = [PPHomeOrderBlendColor(resolved, AppPrimaryClr, 0.14) CGColor];
    self.collapsedIconBadgeView.backgroundColor = chipBackground;
    self.collapsedIconView.tintColor = resolved;
    self.collapsedStatusPillView.backgroundColor = PPHomeOrderBlendColor(resolved, AppPrimaryClr, PPIOS26() ? 0.18 : 0.14);
    self.collapsedStatusPillLabel.textColor = resolved;
    self.collapsedChevronContainerView.layer.borderColor = [PPHomeOrderBlendColor(resolved, AppPrimaryClr, 0.18) CGColor];
    self.collapsedChevronTintView.backgroundColor = PPHomeOrderBlendColor(resolved, AppPrimaryClr, PPIOS26() ? 0.20 : 0.14);
    self.collapsedChevronView.tintColor = resolved;
    self.overlayGradientLayer.colors = @[
        (id)softOverlay.CGColor,
        (id)[PPHomeOrderBlendColor(resolved, AppPrimaryClr, 0.05) CGColor],
        (id)[UIColor clearColor].CGColor
    ];
}

- (void)pp_handleTrackTap
{
    if (self.onTrackTap) {
        self.onTrackTap();
    }
}

- (void)pp_handleHistoryTap
{
    if (self.onHistoryTap) {
        self.onHistoryTap();
    }
}

@end



@implementation PPHomeProfileView (TapFeedback)

- (void)pp_highlightDown
{
    [UIView animateWithDuration:0.12 animations:^{
        self.transform = CGAffineTransformMakeScale(0.96, 0.96);
        self.alpha = 0.85;
    }];
}

- (void)pp_highlightUp
{
    [UIView animateWithDuration:0.18
                          delay:0
         usingSpringWithDamping:0.7
          initialSpringVelocity:0.4
                        options:0
                     animations:^{
        self.transform = CGAffineTransformIdentity;
        self.alpha = 1.0;
    } completion:nil];
}

@end


@class PPCarouselItem;

@interface PPHomeHeaderConfig : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *actionTitle;
@property (nonatomic, copy) NSString *iconName;
@property (nonatomic, strong, nullable) UIMenu *menu;
@property (nonatomic, assign) BOOL hidden;
@property (nonatomic, assign) PPHomeSection section;
@end

@implementation PPHomeHeaderConfig
@end

static NSString * const PPNearbySelectedLatitudeKey = @"pp.home.nearby.latitude";
static NSString * const PPNearbySelectedLongitudeKey = @"pp.home.nearby.longitude";
static NSString * const PPNearbySelectedAreaNameKey = @"pp.home.nearby.areaName";
static NSString * const PPHomeTopCarouselBannerGroupID = @"HOME_MAIN_TOP_CAROUSEL";
static NSString * const PPHomeCompletedLastOrderSeenOrderIDKeyPrefix = @"pp.home.completedLastOrder.seen.orderID";
static NSString * const PPHomeCompletedLastOrderSeenSessionIDKeyPrefix = @"pp.home.completedLastOrder.seen.sessionID";
static NSString * const PPHomeTerminalOrderSeenOrderIDKeyPrefix = @"pp.home.terminalOrder.seen.orderID";
static NSString * const PPHomeTerminalOrderSeenSessionIDKeyPrefix = @"pp.home.terminalOrder.seen.sessionID";
static NSTimeInterval const PPNearbyMinimumRefreshInterval = 20.0;
static NSTimeInterval const PPHomeOtherOrdersRecentLookbackInterval = 24.0 * 60.0 * 60.0;
static NSTimeInterval const PPHomeCompletedLastOrderVisibilityInterval = 48.0 * 60.0 * 60.0;
static double const PPNearbyDefaultRadiusKm = 8.0;
static double const PPNearbyExpandedRadiusKm = 15.0;
static NSInteger const PPCurrentOrdersVisibleLimit = 4;
static NSInteger const PPBuyAgainVisibleLimit = 10;
static CLLocationCoordinate2D const PPNearbyDebugSimulatorCoordinate = {25.285447, 51.531040};

static NSString *PPHomeCurrentAppSessionIdentifier(void)
{
    static NSString *sessionIdentifier = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sessionIdentifier = NSUUID.UUID.UUIDString ?: @"";
    });
    return sessionIdentifier;
}

typedef NS_ENUM(NSInteger, PPNearbyLocationState) {
    PPNearbyLocationStateUnset = 0,
    PPNearbyLocationStateLoading,
    PPNearbyLocationStateReady,
    PPNearbyLocationStateDenied
};


@interface PPHomeViewController ()<UICollectionViewDelegate, UICollectionViewDataSourcePrefetching, BannerTapsCollectionDelegate,PPUniversalCellDelegate, CLLocationManagerDelegate>
 @property (nonatomic, assign) BOOL warmUpCache;
@property (nonatomic, assign) BOOL chatsListenerStarted;
@property (nonatomic, copy, nullable) NSString *unreadListenerUserID;
@property (nonatomic, assign) BOOL adsLoaded;
@property (nonatomic, assign) BOOL accessoriesLoaded;
@property (nonatomic, assign) BOOL nearbyLoaded;
@property (nonatomic, assign) BOOL nearbyLoading;
@property (nonatomic, strong, nullable) MainKindsModel *selectedCategory;
@property (nonatomic, strong) PPHomeLayoutManager *layoutManager;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UICollectionViewDiffableDataSource<NSNumber *, PPHomeItem *> *dataSource;
@property (nonatomic, assign) BOOL didSelectInitialNearby;
@property (nonatomic, strong) NSArray<PetAd *> *ads;
@property (nonatomic, strong) NSArray<ServiceModel *> *services;
@property (nonatomic, strong) NSArray<MainKindsModel *> *mainKinds;
@property (nonatomic, strong) NSArray<PPCategoryItem *> *categories;
@property (nonatomic, strong) NSArray<PetAccessory *> *accessories;
@property (nonatomic, strong) NSArray<PetAccessory *> *buyAgainAccessories;
@property (nonatomic, strong) NSArray<PetAd *> *nearbyAds;
@property (nonatomic, strong) NSArray<PPOrder *> *currentOrders;
@property (nonatomic, strong) NSArray<PPOrder *> *recentOrders;
@property (nonatomic, strong) NSArray<PPCarouselItem *> *carouselItems;
@property (nonatomic, strong) NSArray<PPHomePromoCarouselCard *> *promoCarouselCards;
@property (nonatomic, strong) CLLocationManager *homeLocationManager;
@property (nonatomic, strong) CLGeocoder *homeGeocoder;
@property (nonatomic, assign) CLLocationCoordinate2D selectedNearbyCoordinate;
@property (nonatomic, assign) BOOL hasSelectedNearbyCoordinate;
@property (nonatomic, copy) NSString *selectedNearbyAreaName;
@property (nonatomic, assign) PPNearbyLocationState nearbyLocationState;
@property (nonatomic, assign) BOOL hasRequestedLocationAuthorization;
@property (nonatomic, assign) NSInteger nearbyRequestToken;
@property (nonatomic, strong) NSDate *lastNearbyRefreshAt;
@property (nonatomic, assign) CLLocationCoordinate2D lastNearbyRefreshCoordinate;
@property (nonatomic, assign) BOOL hasLastNearbyRefreshCoordinate;
@property (nonatomic, assign) double nearbyRadiusKm;
@property (nonatomic, strong) NSTimer *nearbyRefreshTimer;
@property (nonatomic, assign) BOOL isUsingManualNearbySelection;
@property (nonatomic, assign) BOOL currentOrdersLoading;
@property (nonatomic, assign) BOOL currentOrdersLoaded;
@property (nonatomic, assign) BOOL isCurrentOrdersExpanded;
@property (nonatomic, assign) NSInteger currentOrdersRequestToken;
@property (nonatomic, assign) NSInteger buyAgainRequestToken;
@property (nonatomic, strong, nullable) NSDate *lastCurrentOrdersRefreshAt;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> currentOrdersQueryListener;
@property (nonatomic, copy) NSString *currentOrdersListenerUserID;
@property (nonatomic, assign) BOOL isHomeScreenVisible;
@property (nonatomic, copy, nullable) NSString *lastObservedHomeOrderID;
@property (nonatomic, copy, nullable) NSString *lastObservedHomeOrderStatusKey;
- (void)handleSeeAllForSection:(PPHomeSection)section;
- (NSString *)heroGreetingText;
- (NSString *)heroBaseGreetingText;
- (NSString *)heroDisplayNameText;
- (NSString *)heroCountryText;
- (nullable NSString *)heroLocationActionTitle;
- (void)refreshHeroSectionAppearance;
- (void)refreshNearbyAdsForce:(BOOL)force reason:(NSString *)reason;
- (void)openHomeLocationPicker;
- (void)presentHomeLocationOptions;
- (void)openLocationSettings;
- (void)configureLocationStateMachine;
- (void)switchHomeLocationBackToAutomatic;
- (BOOL)pp_canUseSimulatedNearbyLocation;
- (void)pp_applySimulatedNearbyLocationAndRefreshWithReason:(NSString *)reason;
- (void)pp_scheduleInitialMainKindsLayoutRefresh;
- (void)refreshCurrentOrdersForce:(BOOL)force;
- (NSString *)pp_currentOrdersUserID;
- (void)pp_stopCurrentOrdersListener;
- (void)pp_startCurrentOrdersListenerForUserID:(NSString *)userID requestToken:(NSInteger)requestToken;
- (void)pp_applyCurrentOrdersSnapshot:(FIRQuerySnapshot *)snapshot requestToken:(NSInteger)requestToken;
- (BOOL)pp_homeStatusKey:(NSString *)statusKey matchesAnyKeywords:(NSArray<NSString *> *)keywords;
- (BOOL)pp_isFailureHomeOrderStatusKey:(NSString *)statusKey;
- (BOOL)pp_isActiveHomeOrder:(PPOrder *)order;
- (NSString *)pp_homeOrderStatusKey:(PPOrder *)order;
- (NSString *)pp_homeOrderStatusTitle:(PPOrder *)order;
- (NSString *)pp_homeOrderStatusHint:(PPOrder *)order;
- (UIColor *)pp_homeOrderStatusColor:(PPOrder *)order;
- (NSString *)pp_homeOrderStatusIconName:(PPOrder *)order;
- (double)pp_homeOrderProgress:(PPOrder *)order;
- (NSInteger)pp_homeOrderItemCount:(PPOrder *)order;
- (NSString *)pp_homeOrderAmountText:(PPOrder *)order;
- (NSString *)pp_homeOrderMetaText:(PPOrder *)order;
- (NSString *)pp_homeOrderFooterText:(PPOrder *)order;
- (NSString *)pp_homeOrderKickerTitle:(PPOrder *)order;
- (NSString *)pp_homeOrderImageURLFromItemData:(NSDictionary *)data;
- (NSArray<NSString *> *)pp_homeOrderPreviewImageURLs:(PPOrder *)order limit:(NSInteger)limit;
- (BOOL)pp_hasOtherRecentHomeOrdersWithinInterval:(NSTimeInterval)interval excludingOrder:(PPOrder *)order;
- (BOOL)pp_shouldHideCompletedLastHomeOrder:(PPOrder *)order;
- (NSString *)pp_completedLastHomeOrderSeenOrderIDDefaultsKey;
- (NSString *)pp_completedLastHomeOrderSeenSessionDefaultsKey;
- (void)pp_setCurrentOrdersExpanded:(BOOL)expanded animated:(BOOL)animated;
- (NSString *)pp_homeRelativeDateString:(NSDate *)date;
- (NSString *)pp_homeShortDateString:(NSDate *)date;
- (nullable PPOrder *)pp_featuredHomeOrder;
- (NSArray<PPHomeItem *> *)pp_homeCurrentOrderItems;
- (NSArray<PPHomeItem *> *)pp_homeBuyAgainItems;
- (NSString *)pp_homeOrderItemIdentifier:(id)rawItem;
- (NSArray<NSString *> *)pp_buyAgainAccessoryIDsFromOrders:(NSArray<PPOrder *> *)orders
                                                     limit:(NSInteger)limit;
- (NSArray<PetAccessory *> *)pp_orderedBuyAgainAccessoriesFromResolvedByID:(NSDictionary<NSString *, PetAccessory *> *)resolvedByID
                                                                 orderedIDs:(NSArray<NSString *> *)orderedIDs
                                                                      limit:(NSInteger)limit;
- (void)pp_refreshBuyAgainSection;
- (void)pp_centerNearbySectionIfPossible;
- (void)pp_openOrderDetailsForOrder:(PPOrder *)order;

- (void)refreshNavigationRightItemsForCartCount:(NSUInteger)count;
@property (nonatomic, assign) BOOL isMainKindsExpanded;
@property (nonatomic, assign) BOOL didAutoScrollSuggestions;
@property (nonatomic, assign) BOOL didFillSuggestionsOnce;
@property (nonatomic, strong) UIView *profileCard;
@property (nonatomic, strong, nullable) UIBarButtonItem *homeProfileItem;
@property (nonatomic, strong, nullable) UIBarButtonItem *homeCartItem;
@property (nonatomic, strong, nullable) UIBarButtonItem *homeOptionsItem;
@property (nonatomic, assign) BOOL didRegisterTimeChangeObserver;
@property (nonatomic, strong) NSCache<NSString *, UIImage *> *blurHashCache;
@property (nonatomic, strong) dispatch_queue_t blurHashQueue;
@property (nonatomic, copy) NSString *lastHeroRenderSignature;
@property (nonatomic, assign) BOOL heroRefreshScheduled;
- (void)pp_prefetchImagesAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;
- (void)pp_prefetchTopImagesWithLimit:(NSInteger)limit;
- (void)pp_asyncBlurHashImageForHash:(NSString *)hash
                                size:(CGSize)size
                          completion:(void (^)(UIImage * _Nullable image))completion;
- (void)handleUserProfileSyncNotification:(NSNotification *)notification;
- (void)pp_handlePromoCardTap:(PPHomePromoCarouselCard *)card interaction:(NSString *)interaction;
- (void)pp_handleCarouselTapAction:(PPBannerOnTapAction)action
                             value:(NSString *)value
                       defaultKind:(NSInteger)fallbackMainKindID
                           context:(NSString *)context;
- (nullable MainBannerModel *)pp_homeTopCarouselBannerGroup;
- (NSArray<PPHomePromoCarouselCard *> *)pp_homePromoFallbackCards;
- (NSArray<PPHomePromoCarouselCard *> *)pp_promoCardsFromLegacyBannerGroup:(MainBannerModel *)group;

@end


@implementation PPHomeViewController


// Scroll Suggestions section to item index 2 after data is loaded
- (void)autoScrollIndextoIndex:(NSInteger)targetItem inSection:(PPHomeSection)section
{
    NSInteger sectionIndex = [self sectionIndexForType:section];
    if (sectionIndex == NSNotFound) return;

  
    if ([self.collectionView numberOfItemsInSection:sectionIndex] <= targetItem) {
        return;
    }

    NSIndexPath *indexPath =
        [NSIndexPath indexPathForItem:targetItem inSection:sectionIndex];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self.collectionView scrollToItemAtIndexPath:indexPath
                                    atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                            animated:YES];
    });
}

- (void)pp_centerNearbySectionIfPossible
{
    NSInteger sectionIndex = [self sectionIndexForType:PPHomeSectionAdsNearBy];
    if (sectionIndex == NSNotFound || !self.collectionView) {
        return;
    }

    NSInteger itemCount = [self.collectionView numberOfItemsInSection:sectionIndex];
    if (itemCount <= 1) {
        return;
    }

    NSInteger targetItem = MIN(1, itemCount - 1);
    NSIndexPath *centerIndexPath = [NSIndexPath indexPathForItem:targetItem inSection:sectionIndex];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.collectionView layoutIfNeeded];
        if ([self.collectionView numberOfItemsInSection:sectionIndex] <= targetItem) {
            return;
        }
        [self.collectionView scrollToItemAtIndexPath:centerIndexPath
                                    atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                            animated:NO];
    });
}

#pragma mark - Life Cycle
- (void)didTapOn_BannerViewModel:(PPBannerViewModel *)pannerViewModel
{
    if (!pannerViewModel) return;
    [self pp_handleCarouselTapAction:pannerViewModel.onTapAction
                               value:PPSafeString(pannerViewModel.onTapValue)
                         defaultKind:0
                             context:@"legacy-banner-card"];
}

- (void)pp_handlePromoCardTap:(PPHomePromoCarouselCard *)card
                  interaction:(NSString *)interaction
{
    if (!card) return;

    if ([interaction isEqualToString:@"primary"]) {
        [self pp_handleCarouselTapAction:card.primaryButtonTapAction
                                   value:PPSafeString(card.primaryButtonTapValue)
                             defaultKind:0
                                 context:@"promo-primary-button"];
        return;
    }

    if ([interaction isEqualToString:@"secondary"]) {
        [self pp_handleCarouselTapAction:card.secondaryButtonTapAction
                                   value:PPSafeString(card.secondaryButtonTapValue)
                             defaultKind:0
                                 context:@"promo-secondary-button"];
        return;
    }

    [self pp_handleCarouselTapAction:card.cardTapAction
                               value:PPSafeString(card.cardTapValue)
                         defaultKind:0
                             context:@"promo-card"];
}

- (void)pp_handleCarouselTapAction:(PPBannerOnTapAction)action
                             value:(NSString *)value
                       defaultKind:(NSInteger)fallbackMainKindID
                           context:(NSString *)context
{
    NSString *safeValue = PPSafeString(value);
    NSLog(@"[Home][CarouselTap] context=%@ action=%ld value=%@",
          context ?: @"(nil)", (long)action, safeValue);

    switch (action) {
        case PPBannerOnTapViewAccessory:
        case PPBannerOnTapViewAd: {
            NSInteger mainKindID = safeValue.integerValue;
            if (mainKindID <= 0) {
                mainKindID = fallbackMainKindID;
            }
            MainKindsModel *kind = (mainKindID > 0) ? [self resolveMainKindWithID:mainKindID] : nil;
            PPDeepLinkTarget target = (action == PPBannerOnTapViewAccessory)
                ? PPDeepLinkTargetAccessories
                : PPDeepLinkTargetAds;
            PPInputSource source = (action == PPBannerOnTapViewAccessory)
                ? PPInputSourceHomeAccessoriesSection
                : PPInputSourceHomeNearBySection;
            [self handleDeepLinkWithTarget:target mainKind:kind source:source];
            break;
        }

        case PPBannerOnTapOpenUrl: {
            NSString *urlString = safeValue;
            if (urlString.length == 0) return;
            if (![urlString containsString:@"://"]) {
                urlString = [NSString stringWithFormat:@"https://%@", urlString];
            }
            NSURL *url = [NSURL URLWithString:urlString];
            if (!url) return;

            if (@available(iOS 9.0, *)) {
                SFSafariViewController *safari = [[SFSafariViewController alloc] initWithURL:url];
                [PPFunc presentSheetFrom:self sheetVC:safari detentStyle:PPSheetDetentStyle80];
            } else {
                [[UIApplication sharedApplication] openURL:url];
            }
            break;
        }

        case PPBannerOnTapCallPhoneNumber:
            [AppClasses callPhoneNumber:safeValue fromViewController:self];
            break;

        case PPBannerOnTapWhatsApp:
            [AppClasses startWhatsAppWith:safeValue fromViewController:self];
            break;

        default:
            break;
    }
}

- (NSArray<PPHomePromoCarouselCard *> *)pp_homePromoFallbackCards
{
    PPHomePromoCarouselCard *card = [PPHomePromoCarouselCard new];
    card.cardID = @"home-promo-fallback-service";
    card.visible = YES;
    card.sortOrder = 0;
    NSString *badgeTitle = kLang(@"Popular") ?: @"Popular";
    NSString *title = kLang(@"Hire a Service Man") ?: @"Hire a Service Man";
    NSString *subtitle = kLang(@"Need help with setup, repairs & installation?") ?: @"Need help with setup, repairs & installation?";
    NSString *bookNow = kLang(@"Book Now") ?: @"Book Now";
    card.badgeTextEn = badgeTitle;
    card.badgeTextAr = badgeTitle;
    card.titleTextEn = title;
    card.titleTextAr = title;
    card.subtitleTextEn = subtitle;
    card.subtitleTextAr = subtitle;
    card.primaryButtonTitleEn = bookNow;
    card.primaryButtonTitleAr = bookNow;
    card.hidePrimaryButton = NO;
    card.hideSecondaryButton = YES;
    card.startColorHex = @"#F5A63A";
    card.endColorHex = @"#EF8628";
    card.accentColorHex = @"#FFC86D";
    card.cardTapAction = PPBannerOnTapViewAccessory;
    card.cardTapValue = @"";
    card.primaryButtonTapAction = PPBannerOnTapViewAccessory;
    card.primaryButtonTapValue = @"";
    card.autoScrollInterval = 4.8;
    return @[card];
}

- (NSArray<PPHomePromoCarouselCard *> *)pp_promoCardsFromLegacyBannerGroup:(MainBannerModel *)group
{
    if (!group || group.childBanners.count == 0) return @[];

    NSMutableArray<PPHomePromoCarouselCard *> *cards = [NSMutableArray arrayWithCapacity:group.childBanners.count];
    NSInteger idx = 0;
    for (PPBannerViewModel *vm in group.childBanners) {
        if (![vm isKindOfClass:PPBannerViewModel.class]) continue;

        PPHomePromoCarouselCard *card = [PPHomePromoCarouselCard new];
        card.cardID = PPSafeString(vm.bannerID).length > 0 ? PPSafeString(vm.bannerID) : [NSString stringWithFormat:@"legacy-banner-%ld", (long)idx];
        card.visible = YES;
        card.sortOrder = idx;

        NSString *titleEn = PPSafeString(vm.titleTextEn);
        NSString *titleAr = PPSafeString(vm.titleTextAr);
        NSString *descEn = PPSafeString(vm.descTextEn);
        NSString *descAr = PPSafeString(vm.descTextAr);

        card.titleTextEn = titleEn.length > 0 ? titleEn : [vm localizedTitleText];
        card.titleTextAr = titleAr;
        card.subtitleTextEn = descEn.length > 0 ? descEn : [vm localizedDescText];
        card.subtitleTextAr = descAr;

        NSString *badge = PPSafeString(vm.postDateText);
        if (badge.length == 0) badge = @"Popular";
        card.badgeTextEn = badge;
        card.badgeTextAr = badge;

        switch (vm.onTapAction) {
            case PPBannerOnTapViewAccessory:
                card.primaryButtonTitleEn = kLang(@"Shop Now") ?: @"Shop Now";
                card.primaryButtonTitleAr = card.primaryButtonTitleEn;
                break;
            case PPBannerOnTapViewAd:
                card.primaryButtonTitleEn = kLang(@"View Ads") ?: @"View Ads";
                card.primaryButtonTitleAr = card.primaryButtonTitleEn;
                break;
            case PPBannerOnTapCallPhoneNumber:
                card.primaryButtonTitleEn = kLang(@"Call") ?: @"Call";
                card.primaryButtonTitleAr = card.primaryButtonTitleEn;
                break;
            case PPBannerOnTapWhatsApp:
                card.primaryButtonTitleEn = kLang(@"WhatsApp") ?: @"WhatsApp";
                card.primaryButtonTitleAr = card.primaryButtonTitleEn;
                break;
            case PPBannerOnTapOpenUrl:
            default:
                card.primaryButtonTitleEn = kLang(@"Open") ?: @"Open";
                card.primaryButtonTitleAr = card.primaryButtonTitleEn;
                break;
        }

        card.hidePrimaryButton = NO;
        card.hideSecondaryButton = YES;
        card.cardTapAction = vm.onTapAction;
        card.cardTapValue = PPSafeString(vm.onTapValue);
        card.primaryButtonTapAction = vm.onTapAction;
        card.primaryButtonTapValue = PPSafeString(vm.onTapValue);
        card.characterImageURL = vm.sampleImageURL;
        card.backgroundImageURL = vm.backgroundImageURL;
        card.autoScrollInterval = 5.0;

        // Subtle color variance while keeping the same warm style
        switch (idx % 4) {
            case 1:
                card.startColorHex = @"#F39B3C";
                card.endColorHex = @"#E9792C";
                card.accentColorHex = @"#FFD893";
                break;
            case 2:
                card.startColorHex = @"#F2A84A";
                card.endColorHex = @"#D96F27";
                card.accentColorHex = @"#FFC773";
                break;
            case 3:
                card.startColorHex = @"#EF9740";
                card.endColorHex = @"#D86721";
                card.accentColorHex = @"#FFD28B";
                break;
            default:
                card.startColorHex = @"#F5A63A";
                card.endColorHex = @"#EF8628";
                card.accentColorHex = @"#FFC86D";
                break;
        }

        [cards addObject:card];
        idx += 1;
    }

    return cards.copy;
}
- (void)applyBaseSnapshot
{
    NSDiffableDataSourceSnapshot *snapshot =
        [[NSDiffableDataSourceSnapshot alloc] init];

    // ✅ Sections ALWAYS visible
    [snapshot appendSectionsWithIdentifiers:@[
        @(PPHomeSectionHero),
        @(PPHomeSectionServices),
        @(PPHomeSectionCurrentOrders),
        @(PPHomeSectionMainKinds),
        @(PPHomeSectionCarousel),
        @(PPHomeSectionSuggestions),
        @(PPHomeSectionAccessories),
        @(PPHomeSectionAdopt),
        @(PPHomeSectionAdsNearBy),
    ]];

    // ✅ Hero (always present)
    PPHomeItem *heroItem = [PPHomeItem new];
    heroItem.type = PPHomeItemTypeHero;
    heroItem.payload = [NSNull null];
    [snapshot appendItemsWithIdentifiers:@[heroItem]
               intoSectionWithIdentifier:@(PPHomeSectionHero)];

    // ✅ Services (static)
    NSMutableArray *services = [NSMutableArray array];
    for (PPHomeServiceItem *service in [PPHomeServiceItem defaultHomeServices]) {
        PPHomeItem *item = [PPHomeItem new];
        item.payload = service;
        [services addObject:item];
    }
    [snapshot appendItemsWithIdentifiers:services
               intoSectionWithIdentifier:@(PPHomeSectionServices)];

    NSArray<PPHomeItem *> *currentOrderItems = [self pp_homeCurrentOrderItems];
    [snapshot appendItemsWithIdentifiers:currentOrderItems
               intoSectionWithIdentifier:@(PPHomeSectionCurrentOrders)];
    
    // ✅ Carousel placeholder (always present)
    PPHomeItem *carouselPlaceholder = [PPHomeItem new];
    carouselPlaceholder.payload = [NSNull null];

    [snapshot appendItemsWithIdentifiers:@[carouselPlaceholder]
               intoSectionWithIdentifier:@(PPHomeSectionCarousel)];

    // ✅ MainKinds (static)
    NSMutableArray *kinds = [NSMutableArray array];
    for (MainKindsModel *k in self.mainKinds) {
        PPHomeItem *item = [PPHomeItem new];
        item.payload = k;
        [kinds addObject:item];
    }
    [snapshot appendItemsWithIdentifiers:kinds
               intoSectionWithIdentifier:@(PPHomeSectionMainKinds)];

    // 🟡 Empty dynamic sections (NO skeletons)
    // ✅ Suggestions placeholder (height anchor)
 
    
    
    [snapshot appendItemsWithIdentifiers:@[]
               intoSectionWithIdentifier:@(PPHomeSectionAccessories)];
    [snapshot appendItemsWithIdentifiers:@[]
               intoSectionWithIdentifier:@(PPHomeSectionAdsNearBy)];

    // ✅ Adopt (static)
    PPHomeItem *adoptItem =
        [[PPHomeItem alloc] initWithType:PPHomeItemTypeAdopt payload:@"adopt"];
    [snapshot appendItemsWithIdentifiers:@[adoptItem]
               intoSectionWithIdentifier:@(PPHomeSectionAdopt)];

    NSArray<PPHomeItem *> *buyAgainItems = [self pp_homeBuyAgainItems];
    if (buyAgainItems.count > 0) {
        [snapshot appendSectionsWithIdentifiers:@[@(PPHomeSectionBuyAgain)]];
        [snapshot appendItemsWithIdentifiers:buyAgainItems
                   intoSectionWithIdentifier:@(PPHomeSectionBuyAgain)];
    }

    [self.dataSource applySnapshot:snapshot animatingDifferences:NO];
}

- (void)pp_scheduleInitialMainKindsLayoutRefresh
{
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.collectionView) {
            return;
        }

        if ([self sectionIndexForType:PPHomeSectionMainKinds] == NSNotFound) {
            return;
        }

        [self.collectionView.collectionViewLayout invalidateLayout];
        [self.collectionView setNeedsLayout];
        [self.collectionView layoutIfNeeded];
    });
}

- (void)reloadSection:(PPHomeSection)section
{
    NSNumber *sectionIdentifier = @(section);
    CGPoint preservedOffset = CGPointZero;
    BOOL preserveOffset = (section == PPHomeSectionSuggestions);

    if (preserveOffset) {
        preservedOffset = self.collectionView.contentOffset;
    }
    
    
    NSDiffableDataSourceSnapshot *snapshot =
        self.dataSource.snapshot;

    NSArray<NSNumber *> *sectionIdentifiers = snapshot.sectionIdentifiers;
    BOOL sectionExists = [sectionIdentifiers containsObject:sectionIdentifier];

    NSArray *items = sectionExists
        ? [snapshot itemIdentifiersInSectionWithIdentifier:sectionIdentifier]
        : @[];

    NSMutableArray *newItems = [NSMutableArray array];

    switch (section) {
        case PPHomeSectionCurrentOrders:
            [newItems addObjectsFromArray:[self pp_homeCurrentOrderItems]];
            break;

        case PPHomeSectionBuyAgain:
            [newItems addObjectsFromArray:[self pp_homeBuyAgainItems]];
            break;

        case PPHomeSectionAccessories:
            for (PetAccessory *a in self.accessories) {
                PPHomeItem *item = [PPHomeItem new];
                PPUniversalCellViewModel *vm =
                    [[PPUniversalCellViewModel alloc] initWithModel:a
                                                            context:PPCellForMarket];
                vm.ModelObject = a;
                item.universalViewModel = vm;
                [newItems addObject:item];
            }
            break;

        case PPHomeSectionAdsNearBy:
            if (self.nearbyLoading && self.nearbyAds.count == 0) {
                NSInteger skeletonCount = 3;
                for (NSInteger i = 0; i < skeletonCount; i++) {
                    PPHomeItem *item = [PPHomeItem new];
                    item.universalViewModel = [[PPUniversalCellViewModel alloc] initSkeleton];
                    [newItems addObject:item];
                }
            } else if (self.nearbyAds.count == 0) {
                PPHomeItem *emptyItem = [PPHomeItem new];
                emptyItem.payload = @"nearby-empty-state";
                [newItems addObject:emptyItem];
            } else {
                for (PetAd *ad in self.nearbyAds) {
                    PPHomeItem *item = [PPHomeItem new];
                    PPUniversalCellViewModel *vm =
                        [[PPUniversalCellViewModel alloc] initWithModel:ad
                                                                context:PPCellForHomeAds];
                    vm.ModelObject = ad;
                    item.universalViewModel = vm;
                    [newItems addObject:item];
                }
            }
            break;
            
        case PPHomeSectionSuggestions: {
            NSMutableSet<NSString *> *seenSuggestionIDs = [NSMutableSet set];

            for (PetAd *ad in self.nearbyAds) {
                NSString *adID = PPSafeString(ad.adID);
                NSString *key = [NSString stringWithFormat:@"ad:%@", adID];
                if (adID.length == 0 || [seenSuggestionIDs containsObject:key]) {
                    continue;
                }
                [seenSuggestionIDs addObject:key];

                PPHomeItem *item = [PPHomeItem new];
                PPUniversalCellViewModel *vm =
                    [[PPUniversalCellViewModel alloc] initWithModel:ad
                                                            context:PPCellForHomeAds];
                vm.ModelObject = ad;
                item.universalViewModel = vm;
                [newItems addObject:item];
            }

            for (PetAccessory *acc in self.accessories) {
                NSString *accessoryID = PPSafeString(acc.accessoryID);
                NSString *key = [NSString stringWithFormat:@"acc:%@", accessoryID];
                if (accessoryID.length == 0 || [seenSuggestionIDs containsObject:key]) {
                    continue;
                }
                [seenSuggestionIDs addObject:key];

                PPHomeItem *item = [PPHomeItem new];
                PPUniversalCellViewModel *vm =
                    [[PPUniversalCellViewModel alloc] initWithModel:acc
                                                            context:PPCellForMarket];
                vm.ModelObject = acc;
                item.universalViewModel = vm;
                [newItems addObject:item];
            }
            break;
        }

        default:
            break;
    }

    if (section == PPHomeSectionCurrentOrders &&
        sectionExists &&
        items.count == newItems.count &&
        items.count == 1 &&
        [items.firstObject isKindOfClass:PPHomeItem.class] &&
        [newItems.firstObject isKindOfClass:PPHomeItem.class]) {
        PPHomeItem *existingItem = (PPHomeItem *)items.firstObject;
        PPHomeItem *replacementItem = (PPHomeItem *)newItems.firstObject;
        existingItem.type = replacementItem.type;
        existingItem.payload = replacementItem.payload;
        existingItem.universalViewModel = replacementItem.universalViewModel;
        [snapshot reloadItemsWithIdentifiers:@[existingItem]];
        [self.dataSource applySnapshot:snapshot animatingDifferences:NO];
        [self invalidateHeaderForSection:section];
        return;
    }

    if (items.count > 0) {
        [snapshot deleteItemsWithIdentifiers:items];
    }

    if (section == PPHomeSectionBuyAgain) {
        if (!sectionExists && newItems.count > 0) {
            [snapshot appendSectionsWithIdentifiers:@[sectionIdentifier]];
            sectionExists = YES;
        } else if (sectionExists && newItems.count == 0) {
            [snapshot deleteSectionsWithIdentifiers:@[sectionIdentifier]];
            [self.dataSource applySnapshot:snapshot animatingDifferences:YES];
            return;
        } else if (!sectionExists) {
            return;
        }
    } else if (!sectionExists) {
        return;
    }

    [snapshot appendItemsWithIdentifiers:newItems
               intoSectionWithIdentifier:sectionIdentifier];

    BOOL animate = YES;

    if (section == PPHomeSectionSuggestions ||
        section == PPHomeSectionAdsNearBy ||
        section == PPHomeSectionCurrentOrders) {
        // 🔒 Prevent visual flicker on frequently refreshed sections.
        animate = NO;
        if (section == PPHomeSectionSuggestions) {
            self.didFillSuggestionsOnce = YES;
        }
    }

    [self.dataSource applySnapshot:snapshot animatingDifferences:animate];

    if (section == PPHomeSectionCurrentOrders || section == PPHomeSectionBuyAgain) {
        [self invalidateHeaderForSection:section];
    }

    // 🔒 Restore scroll position (Suggestions only)
    if (preserveOffset) {
        self.collectionView.contentOffset = preservedOffset;
    }

    // 🎯 Center last section starting from index 1 (if available)
    if (section == PPHomeSectionAdsNearBy) {
        [self pp_centerNearbySectionIfPossible];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    //[PetAccessoryManager.sharedManager pp_oneTimeSetAllAccessoriesPriceToFixedValuesWithCompletion:^(NSError * _Nullable error, NSInteger updatedCount) {
        
    //}];
   // [PetAdManager.sharedManager migrateImageMetaToImageItemsOnce];
    //[CartManager.sharedManager clearCart];
    self.isMainKindsExpanded = NO; // collapsed = horizontal
    self.warmUpCache = NO;
    self.chatsListenerStarted = NO;
    self.view.backgroundColor = NewBgColor; //AppBackgroundClrDarker; //AppBackgroundClrDarker;
    self.mainKinds = PPMainKindsArray;
    self.selectedCategory = nil; // nil == "All"
    self.blurHashCache = [NSCache new];
    self.blurHashCache.countLimit = 250;
    self.blurHashQueue =
    dispatch_queue_create("com.purepets.home.blurhash.decode", DISPATCH_QUEUE_CONCURRENT);
    self.selectedNearbyCoordinate = kCLLocationCoordinate2DInvalid;
    self.lastNearbyRefreshCoordinate = kCLLocationCoordinate2DInvalid;
    self.nearbyLocationState = PPNearbyLocationStateUnset;
    self.hasSelectedNearbyCoordinate = NO;
    self.hasLastNearbyRefreshCoordinate = NO;
    self.nearbyLoading = YES;
    self.nearbyRadiusKm = PPNearbyDefaultRadiusKm;
    self.currentOrders = @[];
    self.recentOrders = @[];
    self.buyAgainAccessories = @[];
    self.isCurrentOrdersExpanded = NO;
    self.currentOrdersRequestToken = 0;
    self.buyAgainRequestToken = 0;
    self.lastCurrentOrdersRefreshAt = nil;
    self.currentOrdersLoading = ([self pp_currentOrdersUserID].length > 0);
    self.currentOrdersLoaded = !self.currentOrdersLoading;
    self.homeGeocoder = [[CLGeocoder alloc] init];
    self.promoCarouselCards = PPHomePromoCarouselManager.sharedManager.cards ?: @[];
    [self configureLocationStateMachine];
    
   
    
    [self setupCollectionView];
    [self configureDataSource];
    [self applyBaseSnapshot];   // 🔥 NEW
    [self pp_scheduleInitialMainKindsLayoutRefresh];
    [self refreshHeroSectionAppearance];

    __weak typeof(self) weakSelf = self;
    [[PPHomePromoCarouselManager sharedManager] startListeningWithCompletion:^(NSArray<PPHomePromoCarouselCard *> * _Nullable cards, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (error) {
            NSLog(@"[HomePromoCarousel] listener error: %@", error.localizedDescription);
            return;
        }
        self.promoCarouselCards = cards ?: @[];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self fillCarouselBanner];
        });
    }];

    [self loadData];
   
    // 🔥 Fill top banner once banners are ready
    dispatch_async(dispatch_get_main_queue(), ^{
        [self fillCarouselBanner];
    });
    
    
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(handleBrowseHistoryUpdate)
               name:@"PPBrowseHistoryDidUpdate"
             object:nil];
    
    
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(updateCartQuantityBadge)
               name:kCartUpdatedNotification //@"PPCartDidChangeNotification"
             object:nil];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(handleAppWillEnterForeground)
               name:UIApplicationWillEnterForegroundNotification
             object:nil];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(handleAdUploadCompletedNotification:)
               name:PPAdDidFinishUploadNotification
             object:nil];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(handleUserProfileSyncNotification:)
               name:PPUserManagerDidSyncCurrentUserNotification
             object:nil];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(handleUserProfileSyncNotification:)
               name:PPUserManagerDidSignOutNotification
             object:nil];
    
     
}


- (void)handleBrowseHistoryUpdate
{
    // Update layout so header is re-requested
    [self invalidateHeaderForSection:PPHomeSectionSuggestions];
}

- (void)pp_refreshNavigationMenusForCurrentUser {
    if (@available(iOS 14.0, *)) {
        if (self.homeOptionsItem) {
            self.homeOptionsItem.menu = [PPActionButton appActionsArrayfor:self];
        }

        UIBarButtonItem *profileItem = self.navigationItem.leftBarButtonItems.firstObject ?: self.navigationItem.leftBarButtonItem;
        UIView *customView = profileItem.customView;
        if ([customView isKindOfClass:UIButton.class]) {
            UIButton *profileButton = (UIButton *)customView;
            profileButton.menu = [PPActionButton userActionsArrayfor:self];
        }
    }
}

- (void)handleUserProfileSyncNotification:(NSNotification *)notification
{
    (void)notification;
    [self pp_refreshNavigationMenusForCurrentUser];
    [self refreshHeroSectionAppearance];
    [self refreshCurrentOrdersForce:YES];
}

- (NSString *)pp_currentOrdersUserID
{
    NSString *userID = @"";
    id value = UserManager.sharedManager.currentUser.ID;
    if ([value isKindOfClass:NSString.class]) {
        userID = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    if (userID.length == 0) {
        userID = [FIRAuth auth].currentUser.uid ?: @"";
    }
    return userID;
}

- (BOOL)pp_homeStatusKey:(NSString *)statusKey matchesAnyKeywords:(NSArray<NSString *> *)keywords
{
    NSString *normalizedStatus = [PPOrder normalizedStatusFromRawValue:statusKey];
    if (normalizedStatus.length == 0 || keywords.count == 0) {
        return NO;
    }

    NSString *wrappedStatus = [NSString stringWithFormat:@"_%@_", normalizedStatus];
    for (NSString *keyword in keywords) {
        NSString *normalizedKeyword = [PPOrder normalizedStatusFromRawValue:keyword];
        if (normalizedKeyword.length == 0) {
            continue;
        }
        NSString *wrappedKeyword = [NSString stringWithFormat:@"_%@_", normalizedKeyword];
        if ([wrappedStatus containsString:wrappedKeyword]) {
            return YES;
        }
    }

    return NO;
}

- (BOOL)pp_isFailureHomeOrderStatusKey:(NSString *)statusKey
{
    return [self pp_homeStatusKey:statusKey
                 matchesAnyKeywords:@[@"failed", @"rejected", @"cancelled", @"canceled", @"expired", @"voided", @"error"]];
}

- (NSString *)pp_homeOrderStatusKey:(PPOrder *)order
{
    NSString *statusKey = [PPOrder normalizedStatusFromRawValue:order.rawStatus];
    if (statusKey.length > 0) {
        return statusKey;
    }

    switch (order.status) {
        case PPOrderStatusPaid:
            return @"paid";
        case PPOrderStatusFailed:
            return @"failed";
        case PPOrderStatusPending:
        default:
            return @"pending";
    }
}

- (BOOL)pp_isActiveHomeOrder:(PPOrder *)order
{
    if (![order isKindOfClass:PPOrder.class]) {
        return NO;
    }

    NSString *statusKey = [self pp_homeOrderStatusKey:order];
    if ([self pp_isFailureHomeOrderStatusKey:statusKey]) {
        return NO;
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"delivered", @"completed", @"fulfilled"]]) {
        return NO;
    }

    return [self pp_homeStatusKey:statusKey
                 matchesAnyKeywords:@[@"pending",
                                      @"pending_collection",
                                      @"paid",
                                      @"success",
                                      @"processing",
                                      @"preparing",
                                      @"packed",
                                      @"confirmed",
                                      @"shipped",
                                      @"shipping",
                                      @"out_for_delivery",
                                      @"in_transit"]];
}

- (NSString *)pp_homeOrderStatusTitle:(PPOrder *)order
{
    NSString *statusKey = [self pp_homeOrderStatusKey:order];
    if ([self pp_isFailureHomeOrderStatusKey:statusKey]) {
        if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"cancelled", @"canceled"]]) {
            return kLang(@"Canceled");
        }
        return kLang(@"Failed");
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"delivered", @"completed", @"fulfilled"]]) {
        return kLang(@"Delivered");
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"shipped", @"shipping", @"out_for_delivery", @"in_transit"]]) {
        return kLang(@"Shipped");
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"processing", @"preparing", @"packed", @"confirmed"]]) {
        return kLang(@"Processing");
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"paid", @"success"]]) {
        return kLang(@"Paid");
    }
    return kLang(@"Pending");
}

- (NSString *)pp_homeOrderStatusHint:(PPOrder *)order
{
    NSString *statusKey = [self pp_homeOrderStatusKey:order];
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"shipped", @"shipping", @"out_for_delivery", @"in_transit"]]) {
        return kLang(@"Home_CurrentOrdersShippedHint") ?: (kLang(@"order_action_track_hint") ?: @"");
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"processing", @"preparing", @"packed", @"confirmed"]]) {
        return kLang(@"Home_CurrentOrdersProcessingHint") ?: (kLang(@"order_action_track_hint") ?: @"");
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"paid", @"success"]]) {
        return kLang(@"Home_CurrentOrdersPaidHint") ?: (kLang(@"order_action_track_hint") ?: @"");
    }
    return kLang(@"Home_CurrentOrdersPendingHint") ?: (kLang(@"order_action_track_hint") ?: @"");
}

- (UIColor *)pp_homeOrderStatusColor:(PPOrder *)order
{
    NSString *statusKey = [self pp_homeOrderStatusKey:order];
    if ([self pp_isFailureHomeOrderStatusKey:statusKey]) {
        return UIColor.systemRedColor;
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"delivered", @"completed", @"fulfilled"]]) {
        return UIColor.systemGreenColor;
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"shipped", @"shipping", @"out_for_delivery", @"in_transit"]]) {
        return UIColor.systemBlueColor;
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"processing", @"preparing", @"packed", @"confirmed"]]) {
        return UIColor.systemOrangeColor;
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"paid", @"success"]]) {
        return [GM appPrimaryColor];
    }
    return UIColor.systemOrangeColor;
}

- (NSString *)pp_homeOrderStatusIconName:(PPOrder *)order
{
    NSString *statusKey = [self pp_homeOrderStatusKey:order];
    if ([self pp_isFailureHomeOrderStatusKey:statusKey]) {
        return @"xmark.circle.fill";
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"delivered", @"completed", @"fulfilled"]]) {
        return @"checkmark.seal.fill";
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"shipped", @"shipping", @"out_for_delivery", @"in_transit"]]) {
        return @"shippedtruck";
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"processing", @"preparing", @"packed", @"confirmed"]]) {
        return @"shippingbox.circle.fill";
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"paid", @"success"]]) {
        return @"creditcard.fill";
    }
    return @"clock.fill";
}

- (double)pp_homeOrderProgress:(PPOrder *)order
{
    NSString *statusKey = [self pp_homeOrderStatusKey:order];
    if ([self pp_isFailureHomeOrderStatusKey:statusKey]) {
        return 1.0;
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"delivered", @"completed", @"fulfilled"]]) {
        return 1.0;
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"shipped", @"shipping", @"out_for_delivery", @"in_transit"]]) {
        return 0.86;
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"processing", @"preparing", @"packed", @"confirmed"]]) {
        return [order isCashOnDelivery] ? 0.56 : 0.68;
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"paid", @"success"]]) {
        return 0.38;
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"pending_collection"]]) {
        return 0.24;
    }
    return 0.16;
}

- (NSInteger)pp_homeOrderItemCount:(PPOrder *)order
{
    NSInteger totalCount = 0;
    for (id rawItem in order.items ?: @[]) {
        if ([rawItem isKindOfClass:NSDictionary.class]) {
            NSDictionary *item = (NSDictionary *)rawItem;
            id rawQty = item[@"qty"] ?: item[@"quantity"];
            NSInteger quantity = [rawQty respondsToSelector:@selector(integerValue)] ? [rawQty integerValue] : 1;
            totalCount += MAX(quantity, 1);
        } else {
            totalCount += 1;
        }
    }
    return MAX(totalCount, 0);
}

- (NSString *)pp_homeOrderAmountText:(PPOrder *)order
{
    double total = order.totalAmount;
    if (total <= 0.0) {
        total = order.amount;
    }
    if (total <= 0.0 && order.shippingFee > 0.0) {
        total = order.shippingFee;
    }
    if (total <= 0.0) {
        return @"";
    }

    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    formatter.currencyCode = order.currency.length > 0 ? order.currency : @"QAR";
    formatter.maximumFractionDigits = 2;
    formatter.minimumFractionDigits = 0;
    formatter.locale = Language.isRTL
        ? [NSLocale localeWithLocaleIdentifier:@"ar"]
        : [NSLocale localeWithLocaleIdentifier:@"en"];

    NSString *formattedAmount = [formatter stringFromNumber:@(total)];
    if (formattedAmount.length > 0) {
        return formattedAmount;
    }

    return [NSString stringWithFormat:@"%@ %.2f",
            order.currency.length > 0 ? order.currency : @"QAR",
            total];
}

- (NSString *)pp_homeOrderMetaText:(PPOrder *)order
{
    NSMutableArray<NSString *> *parts = [NSMutableArray array];

    NSInteger itemCount = [self pp_homeOrderItemCount:order];
    if (itemCount > 0) {
        NSString *itemsFormat = kLang(@"Home_CurrentOrdersItemsFormat") ?: @"%ld items";
        [parts addObject:[NSString stringWithFormat:itemsFormat, (long)itemCount]];
    }

    NSString *amountText = [self pp_homeOrderAmountText:order];
    if (amountText.length > 0) {
        [parts addObject:amountText];
    }

    return [parts componentsJoinedByString:@" | "];
}

- (NSString *)pp_homeRelativeDateString:(NSDate *)date
{
    if (![date isKindOfClass:NSDate.class]) {
        return @"";
    }

    if (@available(iOS 13.0, *)) {
        NSRelativeDateTimeFormatter *formatter = [[NSRelativeDateTimeFormatter alloc] init];
        formatter.unitsStyle = NSRelativeDateTimeFormatterUnitsStyleShort;
        formatter.locale = Language.isRTL
            ? [NSLocale localeWithLocaleIdentifier:@"ar"]
            : [NSLocale localeWithLocaleIdentifier:@"en"];
        return [formatter localizedStringForDate:date relativeToDate:[NSDate date]] ?: @"";
    }

    return [self pp_homeShortDateString:date];
}

- (NSString *)pp_homeShortDateString:(NSDate *)date
{
    if (![date isKindOfClass:NSDate.class]) {
        return @"";
    }

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = NSDateFormatterNoStyle;
    formatter.locale = Language.isRTL
        ? [NSLocale localeWithLocaleIdentifier:@"ar"]
        : [NSLocale localeWithLocaleIdentifier:@"en"];
    return [formatter stringFromDate:date] ?: @"";
}

- (NSString *)pp_homeOrderFooterText:(PPOrder *)order
{
    NSDate *estimatedDate = order.estimatedDeliveryAt;
    if ([estimatedDate isKindOfClass:NSDate.class]) {
        NSString *dateText = [self pp_homeShortDateString:estimatedDate];
        if (dateText.length > 0) {
            return [NSString stringWithFormat:@"%@ %@",
                    kLang(@"Home_CurrentOrdersExpectedPrefix") ?: @"Expected",
                    dateText];
        }
    }

    NSDate *updatedDate = order.statusUpdatedAt ?: order.updatedAt ?: order.createdAt;
    NSString *relativeDate = [self pp_homeRelativeDateString:updatedDate];
    if (relativeDate.length > 0) {
        return [NSString stringWithFormat:@"%@ %@",
                kLang(@"Home_CurrentOrdersUpdatedPrefix") ?: @"Updated",
                relativeDate];
    }

    return kLang(@"order_action_track_hint") ?: @"";
}

- (NSString *)pp_homeOrderKickerTitle:(PPOrder *)order
{
    if ([self pp_isActiveHomeOrder:order]) {
        return kLang(@"Home_CurrentOrdersTitle") ?: @"Active order";
    }

    return kLang(@"Home_LastOrderTitle") ?: @"Last order";
}

- (NSString *)pp_homeOrderImageURLFromItemData:(NSDictionary *)data
{
    if (![data isKindOfClass:NSDictionary.class]) {
        return @"";
    }

    NSArray<NSString *> *valueKeys = @[@"image", @"imageURL", @"imageUrl", @"photo", @"icon"];
    for (NSString *key in valueKeys) {
        NSString *value = PPSafeString(data[key]);
        value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (value.length > 0) {
            return value;
        }
    }

    NSArray<NSString *> *arrayKeys = @[@"imageURLsArray", @"imageURLs", @"images"];
    for (NSString *key in arrayKeys) {
        id rawValue = data[key];
        if (![rawValue isKindOfClass:NSArray.class]) {
            continue;
        }

        for (id item in (NSArray *)rawValue) {
            NSString *value = PPSafeString(item);
            value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (value.length > 0) {
                return value;
            }
        }
    }

    return @"";
}

- (NSArray<NSString *> *)pp_homeOrderPreviewImageURLs:(PPOrder *)order limit:(NSInteger)limit
{
    if (![order isKindOfClass:PPOrder.class] || limit == 0) {
        return @[];
    }

    NSMutableDictionary<NSString *, PetAccessory *> *resolvedByID = [NSMutableDictionary dictionary];
    for (PetAccessory *accessory in self.accessories ?: @[]) {
        if (![accessory isKindOfClass:PetAccessory.class]) {
            continue;
        }

        NSString *accessoryID = PPSafeString(accessory.accessoryID);
        accessoryID = [accessoryID stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (accessoryID.length == 0) {
            continue;
        }

        resolvedByID[accessoryID] = accessory;
    }

    NSInteger cappedLimit = MAX(limit, 0);
    NSMutableOrderedSet<NSString *> *orderedURLs = [NSMutableOrderedSet orderedSet];
    for (id rawItem in order.items ?: @[]) {
        NSString *imageURL = @"";
        if ([rawItem isKindOfClass:NSDictionary.class]) {
            NSDictionary *itemData = (NSDictionary *)rawItem;
            imageURL = [self pp_homeOrderImageURLFromItemData:itemData];

            if (imageURL.length == 0) {
                NSDictionary *nestedItemData =
                    [itemData[@"product"] isKindOfClass:NSDictionary.class] ? itemData[@"product"] :
                    ([itemData[@"item"] isKindOfClass:NSDictionary.class] ? itemData[@"item"] : nil);
                if (nestedItemData) {
                    imageURL = [self pp_homeOrderImageURLFromItemData:nestedItemData];
                }
            }
        }

        if (imageURL.length == 0) {
            NSString *itemID = [self pp_homeOrderItemIdentifier:rawItem];
            PetAccessory *accessory = resolvedByID[itemID];
            if ([accessory isKindOfClass:PetAccessory.class] &&
                [accessory.imageURLsArray isKindOfClass:NSArray.class] &&
                accessory.imageURLsArray.count > 0) {
                imageURL = PPSafeString(accessory.imageURLsArray.firstObject);
            }
        }

        imageURL = [imageURL stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (imageURL.length == 0 || [orderedURLs containsObject:imageURL]) {
            continue;
        }

        [orderedURLs addObject:imageURL];
        if (cappedLimit > 0 && orderedURLs.count >= cappedLimit) {
            break;
        }
    }

    return orderedURLs.array;
}

- (BOOL)pp_hasOtherRecentHomeOrdersWithinInterval:(NSTimeInterval)interval excludingOrder:(PPOrder *)order
{
    NSString *excludedOrderID = [order isKindOfClass:PPOrder.class] ? PPSafeString(order.orderId) : @"";
    NSDate *now = [NSDate date];

    for (PPOrder *candidate in self.recentOrders ?: @[]) {
        if (![candidate isKindOfClass:PPOrder.class]) {
            continue;
        }

        NSString *candidateOrderID = PPSafeString(candidate.orderId);
        if (excludedOrderID.length > 0 && [candidateOrderID isEqualToString:excludedOrderID]) {
            continue;
        }

        NSDate *activityDate = candidate.statusUpdatedAt ?: candidate.updatedAt ?: candidate.createdAt;
        if (![activityDate isKindOfClass:NSDate.class]) {
            continue;
        }

        NSTimeInterval elapsed = [now timeIntervalSinceDate:activityDate];
        if (elapsed <= interval) {
            return YES;
        }
    }

    return NO;
}

- (NSString *)pp_completedLastHomeOrderSeenOrderIDDefaultsKey
{
    NSString *userID = [self pp_currentOrdersUserID];
    if (userID.length == 0) {
        return PPHomeCompletedLastOrderSeenOrderIDKeyPrefix;
    }
    return [NSString stringWithFormat:@"%@.%@", PPHomeCompletedLastOrderSeenOrderIDKeyPrefix, userID];
}

- (NSString *)pp_completedLastHomeOrderSeenSessionDefaultsKey
{
    NSString *userID = [self pp_currentOrdersUserID];
    if (userID.length == 0) {
        return PPHomeCompletedLastOrderSeenSessionIDKeyPrefix;
    }
    return [NSString stringWithFormat:@"%@.%@", PPHomeCompletedLastOrderSeenSessionIDKeyPrefix, userID];
}

- (BOOL)pp_shouldHideCompletedLastHomeOrder:(PPOrder *)order
{
    if (![order isKindOfClass:PPOrder.class]) {
        return YES;
    }

    NSString *statusKey = [self pp_homeOrderStatusKey:order];
    if (![self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"delivered", @"completed", @"fulfilled"]]) {
        return NO;
    }

    NSDate *completedDate = order.statusUpdatedAt ?: order.updatedAt ?: order.createdAt;
    if (![completedDate isKindOfClass:NSDate.class]) {
        return NO;
    }

    NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:completedDate];
    if (elapsed > PPHomeCompletedLastOrderVisibilityInterval) {
        return YES;
    }

    BOOL hasOtherRecentOrders =
        [self pp_hasOtherRecentHomeOrdersWithinInterval:PPHomeOtherOrdersRecentLookbackInterval
                                         excludingOrder:order];
    if (hasOtherRecentOrders) {
        return NO;
    }

    NSString *orderID = PPSafeString(order.orderId);
    if (orderID.length == 0) {
        return NO;
    }

    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *storedOrderID = [defaults stringForKey:[self pp_completedLastHomeOrderSeenOrderIDDefaultsKey]] ?: @"";
    NSString *storedSessionID = [defaults stringForKey:[self pp_completedLastHomeOrderSeenSessionDefaultsKey]] ?: @"";
    NSString *currentSessionID = PPHomeCurrentAppSessionIdentifier();

    BOOL wasShownInPreviousLaunch =
        [storedOrderID isEqualToString:orderID] &&
        storedSessionID.length > 0 &&
        ![storedSessionID isEqualToString:currentSessionID];
    if (wasShownInPreviousLaunch) {
        return YES;
    }

    [defaults setObject:orderID forKey:[self pp_completedLastHomeOrderSeenOrderIDDefaultsKey]];
    [defaults setObject:currentSessionID forKey:[self pp_completedLastHomeOrderSeenSessionDefaultsKey]];
    return NO;
}

- (BOOL)pp_isTerminalHomeOrderStatusKey:(NSString *)statusKey
{
    return [self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"success", @"paid"]]
        || [self pp_isFailureHomeOrderStatusKey:statusKey];
}

- (NSString *)pp_terminalHomeOrderSeenOrderIDDefaultsKey
{
    NSString *userID = [self pp_currentOrdersUserID];
    if (userID.length == 0) {
        return PPHomeTerminalOrderSeenOrderIDKeyPrefix;
    }
    return [NSString stringWithFormat:@"%@.%@", PPHomeTerminalOrderSeenOrderIDKeyPrefix, userID];
}

- (NSString *)pp_terminalHomeOrderSeenSessionDefaultsKey
{
    NSString *userID = [self pp_currentOrdersUserID];
    if (userID.length == 0) {
        return PPHomeTerminalOrderSeenSessionIDKeyPrefix;
    }
    return [NSString stringWithFormat:@"%@.%@", PPHomeTerminalOrderSeenSessionIDKeyPrefix, userID];
}

- (BOOL)pp_shouldHideTerminalHomeOrder:(PPOrder *)order
{
    if (![order isKindOfClass:PPOrder.class]) {
        return NO;
    }

    NSString *statusKey = [self pp_homeOrderStatusKey:order];
    if (![self pp_isTerminalHomeOrderStatusKey:statusKey]) {
        return NO;
    }

    NSString *orderID = PPSafeString(order.orderId);
    if (orderID.length == 0) {
        return NO;
    }

    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *storedOrderID = [defaults stringForKey:[self pp_terminalHomeOrderSeenOrderIDDefaultsKey]] ?: @"";
    NSString *storedSessionID = [defaults stringForKey:[self pp_terminalHomeOrderSeenSessionDefaultsKey]] ?: @"";
    NSString *currentSessionID = PPHomeCurrentAppSessionIdentifier();

    BOOL wasShownInPreviousLaunch =
        [storedOrderID isEqualToString:orderID] &&
        storedSessionID.length > 0 &&
        ![storedSessionID isEqualToString:currentSessionID];
    if (wasShownInPreviousLaunch) {
        return YES;
    }

    [defaults setObject:orderID forKey:[self pp_terminalHomeOrderSeenOrderIDDefaultsKey]];
    [defaults setObject:currentSessionID forKey:[self pp_terminalHomeOrderSeenSessionDefaultsKey]];
    return NO;
}

- (nullable PPOrder *)pp_featuredHomeOrder
{
    id activeOrder = self.currentOrders.firstObject;
    if ([activeOrder isKindOfClass:PPOrder.class]) {
        PPOrder *order = (PPOrder *)activeOrder;

        if ([self pp_shouldHideTerminalHomeOrder:order]) {
            return nil;
        }

        NSDate *createdDate = order.createdAt ?: order.updatedAt;
        if ([createdDate isKindOfClass:NSDate.class]) {
            NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:createdDate];
            if (elapsed <= PPHomeCompletedLastOrderVisibilityInterval) {
                return order;
            }
        }
    }

    return nil;
}

- (NSArray<PPHomeItem *> *)pp_homeCurrentOrderItems
{
    NSMutableArray<PPHomeItem *> *items = [NSMutableArray array];
    PPOrder *featuredOrder = [self pp_featuredHomeOrder];

    if (self.currentOrdersLoading && !featuredOrder) {
        PPHomeItem *placeholderItem =
            [[PPHomeItem alloc] initWithType:PPHomeItemTypeCurrentOrder payload:[NSNull null]];
        [items addObject:placeholderItem];
        return items.copy;
    }

    if (featuredOrder) {
        PPHomeItem *item =
            [[PPHomeItem alloc] initWithType:PPHomeItemTypeCurrentOrder payload:featuredOrder];
        [items addObject:item];
    }

    return items.copy;
}

- (NSArray<PPHomeItem *> *)pp_homeBuyAgainItems
{
    NSMutableArray<PPHomeItem *> *items = [NSMutableArray array];

    for (PetAccessory *accessory in self.buyAgainAccessories ?: @[]) {
        if (![accessory isKindOfClass:PetAccessory.class]) {
            continue;
        }

        PPUniversalCellViewModel *vm =
            [[PPUniversalCellViewModel alloc] initWithModel:accessory
                                                    context:PPCellForMarket];
        vm.ModelObject = accessory;

        PPHomeItem *item =
            [[PPHomeItem alloc] initWithType:PPHomeItemTypeBuyAgain
                               universalModel:vm];
        [items addObject:item];
    }

    return items.copy;
}

- (NSString *)pp_homeOrderItemIdentifier:(id)rawItem
{
    if ([rawItem isKindOfClass:NSString.class]) {
        return [(NSString *)rawItem stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }

    if (![rawItem isKindOfClass:NSDictionary.class]) {
        return @"";
    }

    NSDictionary *item = (NSDictionary *)rawItem;
    NSArray<NSString *> *candidateKeys = @[@"id", @"itemID", @"productId", @"productID"];
    for (NSString *key in candidateKeys) {
        NSString *value = [item[key] isKindOfClass:NSString.class] ? item[key] : @"";
        value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (value.length > 0) {
            return value;
        }
    }

    return @"";
}

- (NSArray<NSString *> *)pp_buyAgainAccessoryIDsFromOrders:(NSArray<PPOrder *> *)orders
                                                     limit:(NSInteger)limit
{
    NSMutableOrderedSet<NSString *> *orderedIDs = [NSMutableOrderedSet orderedSet];

    for (PPOrder *order in orders ?: @[]) {
        if (![order isKindOfClass:PPOrder.class]) {
            continue;
        }

        NSString *statusKey = [self pp_homeOrderStatusKey:order];
        if ([self pp_isFailureHomeOrderStatusKey:statusKey]) {
            continue;
        }

        for (id rawItem in order.items ?: @[]) {
            NSString *itemID = [self pp_homeOrderItemIdentifier:rawItem];
            if (itemID.length == 0) {
                continue;
            }

            [orderedIDs addObject:itemID];
            if (limit > 0 && orderedIDs.count >= limit) {
                return orderedIDs.array;
            }
        }
    }

    return orderedIDs.array;
}

- (NSArray<PetAccessory *> *)pp_orderedBuyAgainAccessoriesFromResolvedByID:(NSDictionary<NSString *, PetAccessory *> *)resolvedByID
                                                                 orderedIDs:(NSArray<NSString *> *)orderedIDs
                                                                      limit:(NSInteger)limit
{
    NSMutableArray<PetAccessory *> *orderedAccessories = [NSMutableArray array];
    NSMutableSet<NSString *> *seenAccessoryIDs = [NSMutableSet set];

    for (NSString *itemID in orderedIDs ?: @[]) {
        PetAccessory *accessory = resolvedByID[itemID];
        if (![accessory isKindOfClass:PetAccessory.class]) {
            continue;
        }

        NSString *accessoryID = PPSafeString(accessory.accessoryID);
        if (accessoryID.length == 0 || [seenAccessoryIDs containsObject:accessoryID]) {
            continue;
        }

        if (accessory.quantity <= 0) {
            continue;
        }

        [seenAccessoryIDs addObject:accessoryID];
        [orderedAccessories addObject:accessory];

        if (limit > 0 && orderedAccessories.count >= limit) {
            break;
        }
    }

    return orderedAccessories.copy;
}

- (void)pp_refreshBuyAgainSection
{
    NSArray<NSString *> *orderedIDs =
        [self pp_buyAgainAccessoryIDsFromOrders:self.recentOrders
                                          limit:MAX(PPBuyAgainVisibleLimit * 2, PPBuyAgainVisibleLimit)];

    self.buyAgainRequestToken += 1;
    NSInteger requestToken = self.buyAgainRequestToken;

    if (orderedIDs.count == 0) {
        self.buyAgainAccessories = @[];
        if (self.dataSource) {
            [self reloadSection:PPHomeSectionBuyAgain];
        }
        return;
    }

    NSMutableDictionary<NSString *, PetAccessory *> *resolvedByID = [NSMutableDictionary dictionary];
    for (PetAccessory *accessory in self.accessories ?: @[]) {
        if (![accessory isKindOfClass:PetAccessory.class]) {
            continue;
        }

        NSString *accessoryID = PPSafeString(accessory.accessoryID);
        if (accessoryID.length == 0) {
            continue;
        }
        resolvedByID[accessoryID] = accessory;
    }

    NSMutableArray<NSString *> *missingIDs = [NSMutableArray array];
    for (NSString *itemID in orderedIDs) {
        if (itemID.length == 0 || resolvedByID[itemID] != nil) {
            continue;
        }
        [missingIDs addObject:itemID];
    }

    void (^applyResolvedAccessories)(NSDictionary<NSString *, PetAccessory *> *) =
    ^(NSDictionary<NSString *, PetAccessory *> *resolved) {
        NSArray<PetAccessory *> *orderedAccessories =
            [self pp_orderedBuyAgainAccessoriesFromResolvedByID:resolved
                                                      orderedIDs:orderedIDs
                                                           limit:PPBuyAgainVisibleLimit];
        self.buyAgainAccessories = orderedAccessories;
        if (self.dataSource) {
            [self reloadSection:PPHomeSectionBuyAgain];
        }
    };

    if (missingIDs.count == 0) {
        applyResolvedAccessories(resolvedByID.copy);
        return;
    }

    __weak typeof(self) weakSelf = self;
    [PetAccessoryManager fetchAccessoriesWithIDs:missingIDs
                                      completion:^(NSArray<PetAccessory *> *accessories) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (requestToken != self.buyAgainRequestToken) {
            return;
        }

        NSMutableDictionary<NSString *, PetAccessory *> *mergedByID = resolvedByID.mutableCopy;
        for (PetAccessory *accessory in accessories ?: @[]) {
            if (![accessory isKindOfClass:PetAccessory.class]) {
                continue;
            }

            NSString *accessoryID = PPSafeString(accessory.accessoryID);
            if (accessoryID.length == 0) {
                continue;
            }
            mergedByID[accessoryID] = accessory;
        }

        applyResolvedAccessories(mergedByID.copy);
    }];
}

- (void)pp_openOrderDetailsForOrder:(PPOrder *)order
{
    if (![order isKindOfClass:PPOrder.class]) {
        return;
    }

    OrderDetailsViewController *detailsVC =
        [[OrderDetailsViewController alloc] initWithOrder:order];
    detailsVC.order = order;
    [PPHomeHelper pushViewControllerSafely:detailsVC from:self animated:YES];
}

- (void)refreshCurrentOrdersForce:(BOOL)force
{
    NSString *userID = [self pp_currentOrdersUserID];
    if (userID.length == 0) {
        self.currentOrdersRequestToken += 1;
        [self pp_stopCurrentOrdersListener];
        self.currentOrders = @[];
        self.recentOrders = @[];
        self.buyAgainAccessories = @[];
        self.currentOrdersLoading = NO;
        self.currentOrdersLoaded = YES;
        self.lastCurrentOrdersRefreshAt = nil;
        if (self.dataSource) {
            [self reloadSection:PPHomeSectionCurrentOrders];
            [self reloadSection:PPHomeSectionBuyAgain];
        }
        return;
    }

    BOOL listenerMatchesCurrentUser =
        self.currentOrdersQueryListener != nil &&
        [self.currentOrdersListenerUserID isEqualToString:userID];
    if (listenerMatchesCurrentUser && !force) {
        return;
    }

    self.currentOrdersRequestToken += 1;
    NSInteger requestToken = self.currentOrdersRequestToken;
    [self pp_stopCurrentOrdersListener];
    self.currentOrdersListenerUserID = userID;
    self.currentOrdersLoading = YES;
    self.currentOrdersLoaded = NO;

    if (self.currentOrders.count == 0 && self.dataSource) {
        [self reloadSection:PPHomeSectionCurrentOrders];
    }

    [self pp_startCurrentOrdersListenerForUserID:userID requestToken:requestToken];
}

- (void)pp_stopCurrentOrdersListener
{
    [self.currentOrdersQueryListener remove];
    self.currentOrdersQueryListener = nil;
    self.currentOrdersListenerUserID = @"";
}

- (void)pp_startCurrentOrdersListenerForUserID:(NSString *)userID requestToken:(NSInteger)requestToken
{
    if (userID.length == 0) {
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    FIRQuery *query = [[db collectionWithPath:@"Orders"] queryWhereField:@"userId" isEqualTo:userID];
    query = [query queryOrderedByField:@"createdAt" descending:YES];
    query = [query queryLimitedTo:12];

    __weak typeof(self) weakSelf = self;
    self.currentOrdersQueryListener =
    [query addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            if (requestToken != self.currentOrdersRequestToken) {
                return;
            }

            if (error) {
                self.currentOrdersLoading = NO;
                self.currentOrdersLoaded = YES;
                NSLog(@"[Home][CurrentOrders] fetch failed: %@", error.localizedDescription ?: @"Unknown error");
                [self reloadSection:PPHomeSectionCurrentOrders];
                [self pp_refreshBuyAgainSection];
                return;
            }

            [self pp_applyCurrentOrdersSnapshot:snapshot requestToken:requestToken];
        });
    }];
}

- (void)pp_applyCurrentOrdersSnapshot:(FIRQuerySnapshot *)snapshot requestToken:(NSInteger)requestToken
{
    if (requestToken != self.currentOrdersRequestToken) {
        return;
    }

    self.currentOrdersLoading = NO;
    self.currentOrdersLoaded = YES;
    self.lastCurrentOrdersRefreshAt = [NSDate date];

    NSMutableArray<PPOrder *> *recentOrders = [NSMutableArray array];
    NSMutableArray<PPOrder *> *resolvedOrders = [NSMutableArray array];
    for (FIRDocumentSnapshot *document in snapshot.documents ?: @[]) {
        PPOrder *order = [PPOrder orderFromSnapshot:document];
        if (![order isKindOfClass:PPOrder.class]) {
            continue;
        }
        [recentOrders addObject:order];
        if (![self pp_isActiveHomeOrder:order]) {
            continue;
        }
        if (resolvedOrders.count >= PPCurrentOrdersVisibleLimit) {
            continue;
        }
        [resolvedOrders addObject:order];
    }

    self.recentOrders = recentOrders.copy;
    self.currentOrders = resolvedOrders.copy;

    PPOrder *featuredOrder = [self pp_featuredHomeOrder];
    NSString *nextObservedOrderID = [featuredOrder isKindOfClass:PPOrder.class]
        ? PPSafeString(featuredOrder.orderId)
        : @"";
    NSString *nextObservedStatusKey = [featuredOrder isKindOfClass:PPOrder.class]
        ? [self pp_homeOrderStatusKey:featuredOrder]
        : @"";
    NSString *previousOrderID = PPSafeString(self.lastObservedHomeOrderID);
    NSString *previousStatusKey = PPSafeString(self.lastObservedHomeOrderStatusKey);

    BOOL shouldPlayStatusFeedback = self.isHomeScreenVisible &&
                                    previousOrderID.length > 0 &&
                                    nextObservedOrderID.length > 0 &&
                                    [previousOrderID isEqualToString:nextObservedOrderID] &&
                                    previousStatusKey.length > 0 &&
                                    nextObservedStatusKey.length > 0 &&
                                    ![previousStatusKey isEqualToString:nextObservedStatusKey];
    if (shouldPlayStatusFeedback) {
        AudioServicesPlaySystemSound(1110);
    }

    self.lastObservedHomeOrderID = nextObservedOrderID;
    self.lastObservedHomeOrderStatusKey = nextObservedStatusKey;
    [self reloadSection:PPHomeSectionCurrentOrders];
    [self pp_refreshBuyAgainSection];
}

- (void)persistNearbyLocationIfNeeded
{
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if (self.hasSelectedNearbyCoordinate &&
        CLLocationCoordinate2DIsValid(self.selectedNearbyCoordinate) &&
        isfinite(self.selectedNearbyCoordinate.latitude) &&
        isfinite(self.selectedNearbyCoordinate.longitude)) {
        [defaults setDouble:self.selectedNearbyCoordinate.latitude forKey:PPNearbySelectedLatitudeKey];
        [defaults setDouble:self.selectedNearbyCoordinate.longitude forKey:PPNearbySelectedLongitudeKey];
        [defaults setObject:self.selectedNearbyAreaName ?: @"" forKey:PPNearbySelectedAreaNameKey];
    } else {
        [defaults removeObjectForKey:PPNearbySelectedLatitudeKey];
        [defaults removeObjectForKey:PPNearbySelectedLongitudeKey];
        [defaults removeObjectForKey:PPNearbySelectedAreaNameKey];
    }
}

- (void)startNearbyRefreshTimerIfNeeded
{
    if (self.nearbyRefreshTimer) return;

    __weak typeof(self) weakSelf = self;
    self.nearbyRefreshTimer =
    [NSTimer scheduledTimerWithTimeInterval:90.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self refreshNearbyAdsForce:NO reason:@"periodic"];
    }];
}

- (void)stopNearbyRefreshTimer
{
    [self.nearbyRefreshTimer invalidate];
    self.nearbyRefreshTimer = nil;
}

- (void)configureLocationStateMachine
{
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if ([defaults objectForKey:PPNearbySelectedLatitudeKey] &&
        [defaults objectForKey:PPNearbySelectedLongitudeKey]) {
        CLLocationCoordinate2D persisted =
            CLLocationCoordinate2DMake([defaults doubleForKey:PPNearbySelectedLatitudeKey],
                                       [defaults doubleForKey:PPNearbySelectedLongitudeKey]);
        if (CLLocationCoordinate2DIsValid(persisted) &&
            !(fabs(persisted.latitude) < DBL_EPSILON && fabs(persisted.longitude) < DBL_EPSILON)) {
            self.selectedNearbyCoordinate = persisted;
            self.hasSelectedNearbyCoordinate = YES;
            self.selectedNearbyAreaName = [defaults stringForKey:PPNearbySelectedAreaNameKey] ?: @"";
            self.nearbyLocationState = PPNearbyLocationStateReady;
        }
    }

    self.homeLocationManager = [[CLLocationManager alloc] init];
    self.homeLocationManager.delegate = self;
    self.homeLocationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
    self.homeLocationManager.distanceFilter = 75.0;

    CLAuthorizationStatus status;
    if (@available(iOS 14.0, *)) {
        status = self.homeLocationManager.authorizationStatus;
    } else {
        status = [CLLocationManager authorizationStatus];
    }
    [self updateLocationStateForAuthorizationStatus:status];
}

- (BOOL)pp_canUseSimulatedNearbyLocation
{
#if DEBUG
#if TARGET_OS_SIMULATOR
    return YES;
#else
    return NO;
#endif
#else
    return NO;
#endif
}

- (void)pp_applySimulatedNearbyLocationAndRefreshWithReason:(NSString *)reason
{
    if (![self pp_canUseSimulatedNearbyLocation]) {
        return;
    }

    CLLocationCoordinate2D coordinate = self.selectedNearbyCoordinate;
    if (!CLLocationCoordinate2DIsValid(coordinate) ||
        (fabs(coordinate.latitude) < DBL_EPSILON && fabs(coordinate.longitude) < DBL_EPSILON)) {
        coordinate = PPNearbyDebugSimulatorCoordinate;
    }
    if (!CLLocationCoordinate2DIsValid(coordinate)) {
        return;
    }

    NSString *areaName = PPSafeString(self.selectedNearbyAreaName);
    if (areaName.length == 0) {
        CountryModel *country = CitiesManager.shared.CurrentCountry;
        CityModel *defaultCity = [CitiesManager.shared defaultCityForCountry:country];
        if (defaultCity.name.length > 0) {
            areaName = defaultCity.name;
        } else {
            areaName = kLang(@"Select your location") ?: @"Select your location";
        }
    }

    self.selectedNearbyCoordinate = coordinate;
    self.hasSelectedNearbyCoordinate = YES;
    self.selectedNearbyAreaName = areaName;
    self.nearbyLocationState = PPNearbyLocationStateReady;
    self.nearbyRadiusKm = PPNearbyDefaultRadiusKm;
    [self persistNearbyLocationIfNeeded];
    [self refreshHeroSectionAppearance];
    [self refreshNearbyAdsForce:YES reason:(reason.length > 0 ? reason : @"simulator-location")];
}

- (void)updateLocationStateForAuthorizationStatus:(CLAuthorizationStatus)status
{
    // ⚠️ Do NOT call +locationServicesEnabled on main thread repeatedly.
    // Rely on authorization status changes instead.
    // If services are globally disabled, the status will be Denied/Restricted.

    if (status == kCLAuthorizationStatusDenied ||
        status == kCLAuthorizationStatusRestricted) {

        if (!self.hasSelectedNearbyCoordinate && [self pp_canUseSimulatedNearbyLocation]) {
            [self pp_applySimulatedNearbyLocationAndRefreshWithReason:@"simulator-denied"];
            return;
        }

        self.nearbyLocationState = self.hasSelectedNearbyCoordinate
            ? PPNearbyLocationStateReady
            : PPNearbyLocationStateDenied;

        [self refreshHeroSectionAppearance];
        return;
    }

    switch (status) {
        case kCLAuthorizationStatusAuthorizedAlways:
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            self.nearbyLocationState = (self.hasSelectedNearbyCoordinate || self.isUsingManualNearbySelection)
                ? PPNearbyLocationStateReady
                : PPNearbyLocationStateLoading;
            if (!self.isUsingManualNearbySelection) {
                [self requestCurrentLocationIfNeeded];
            }
            break;

        case kCLAuthorizationStatusDenied:
        case kCLAuthorizationStatusRestricted:
            self.nearbyLocationState = self.hasSelectedNearbyCoordinate
                ? PPNearbyLocationStateReady
                : PPNearbyLocationStateDenied;
            break;

        case kCLAuthorizationStatusNotDetermined:
            self.nearbyLocationState = self.hasSelectedNearbyCoordinate
                ? PPNearbyLocationStateReady
                : PPNearbyLocationStateLoading;
            if (!self.hasRequestedLocationAuthorization) {
                self.hasRequestedLocationAuthorization = YES;
                [self.homeLocationManager requestWhenInUseAuthorization];
            }
            break;
    }

    [self refreshHeroSectionAppearance];
    [self startNearbyRefreshTimerIfNeeded];
    BOOL shouldForceRefresh = (self.nearbyAds.count == 0);
    [self refreshNearbyAdsForce:shouldForceRefresh
                         reason:@"viewDidAppear"];
}

- (void)requestCurrentLocationIfNeeded
{
    if (!self.homeLocationManager) return;
    if (self.isUsingManualNearbySelection) return;
    [self.homeLocationManager requestLocation];
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager API_AVAILABLE(ios(14.0))
{
    [self updateLocationStateForAuthorizationStatus:manager.authorizationStatus];
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    [self updateLocationStateForAuthorizationStatus:status];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    if (self.isUsingManualNearbySelection) {
        return;
    }

    CLLocation *latest = locations.lastObject;
    if (!latest) return;

    CLLocationCoordinate2D coordinate = latest.coordinate;
    if (!CLLocationCoordinate2DIsValid(coordinate)) return;
    if (fabs(coordinate.latitude) < DBL_EPSILON && fabs(coordinate.longitude) < DBL_EPSILON) return;

    if (!self.hasSelectedNearbyCoordinate) {
        self.selectedNearbyCoordinate = coordinate;
        self.hasSelectedNearbyCoordinate = YES;
    }

    [self.homeGeocoder cancelGeocode];
    __weak typeof(self) weakSelf = self;
    CLLocation *location = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
    [self.homeGeocoder reverseGeocodeLocation:location completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        NSString *area = self.selectedNearbyAreaName;
        CLPlacemark *placemark = placemarks.firstObject;
        if (!error && placemark) {
            NSString *locality = placemark.locality ?: placemark.subLocality;
            NSString *admin = placemark.administrativeArea;
            if (locality.length > 0 && admin.length > 0 && ![locality isEqualToString:admin]) {
                area = [NSString stringWithFormat:@"%@, %@", locality, admin];
            } else if (locality.length > 0) {
                area = locality;
            } else if (admin.length > 0) {
                area = admin;
            }
        }

        if (area.length == 0) {
            area = kLang(@"Select your location");
        }

        self.selectedNearbyCoordinate = coordinate;
        self.selectedNearbyAreaName = area;
        self.hasSelectedNearbyCoordinate = YES;
        self.nearbyLocationState = PPNearbyLocationStateReady;
        [self persistNearbyLocationIfNeeded];
        [self refreshHeroSectionAppearance];
        [self refreshNearbyAdsForce:YES reason:@"location-updated"];
    }];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"[HomeNearby] location failed: %@", error.localizedDescription);
    if (!self.hasSelectedNearbyCoordinate) {
        if ([self pp_canUseSimulatedNearbyLocation]) {
            [self pp_applySimulatedNearbyLocationAndRefreshWithReason:@"simulator-fail"];
            return;
        }
        self.nearbyLocationState = PPNearbyLocationStateDenied;
        [self refreshHeroSectionAppearance];
    }
}

- (void)openHomeLocationPicker
{
    LocationPickerViewController *picker = [[LocationPickerViewController alloc] init];
    if (self.hasSelectedNearbyCoordinate && CLLocationCoordinate2DIsValid(self.selectedNearbyCoordinate)) {
        picker.initialCoordinate = self.selectedNearbyCoordinate;
    }
    __weak typeof(self) weakSelf = self;
    void (^applyPickedCoordinate)(CLLocationCoordinate2D, NSString *) =
    ^(CLLocationCoordinate2D coordinate, NSString *resolvedTitle) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (!CLLocationCoordinate2DIsValid(coordinate) ||
            (fabs(coordinate.latitude) < DBL_EPSILON && fabs(coordinate.longitude) < DBL_EPSILON)) {
            return;
        }

        NSString *resolvedAreaName = PPSafeString(resolvedTitle);
        if (resolvedAreaName.length == 0) {
            resolvedAreaName = kLang(@"Select your location") ?: @"Select your location";
        }
        self.isUsingManualNearbySelection = YES;
        self.selectedNearbyCoordinate = coordinate;
        self.hasSelectedNearbyCoordinate = YES;
        self.selectedNearbyAreaName = resolvedAreaName;
        self.nearbyLocationState = PPNearbyLocationStateReady;
        self.nearbyRadiusKm = PPNearbyDefaultRadiusKm;
        [self persistNearbyLocationIfNeeded];
        [self refreshHeroSectionAppearance];
        [self refreshNearbyAdsForce:YES reason:@"manual-picker"];
    };
    picker.onLocationConfirmed = ^(GMSAddress *gmsAddress) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !gmsAddress) return;

        NSString *resolvedAreaName = [LocationPickerViewController titleFromAddress:gmsAddress] ?: @"";
        if (resolvedAreaName.length == 0 && gmsAddress.lines.count > 0) {
            resolvedAreaName = [gmsAddress.lines componentsJoinedByString:@", "] ?: @"";
        }
        if (resolvedAreaName.length == 0) {
            resolvedAreaName = gmsAddress.country ?: @"";
        }
        applyPickedCoordinate(gmsAddress.coordinate, resolvedAreaName);
    };
    picker.onCoordinateConfirmed = ^(CLLocationCoordinate2D coordinate, NSString *locationTitle) {
        applyPickedCoordinate(coordinate, locationTitle);
    };
    if (self.navigationController) {
        [self.navigationController pushViewController:picker animated:YES];
    } else {
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:picker];
        [self presentViewController:nav animated:YES completion:nil];
    }
}

- (void)presentHomeLocationOptions
{
    UIAlertControllerStyle style = UIAlertControllerStyleActionSheet;
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:nil
                                                                   message:nil
                                                            preferredStyle:style];
    __weak typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:(kLang(@"UseCurrentLocation") ?: @"Use current location")
                                             style:UIAlertActionStyleDefault
                                           handler:^(__unused UIAlertAction * _Nonnull action) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self switchHomeLocationBackToAutomatic];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:(kLang(@"Hero_ChangeArea") ?: @"Change area")
                                             style:UIAlertActionStyleDefault
                                           handler:^(__unused UIAlertAction * _Nonnull action) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self openHomeLocationPicker];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:(kLang(@"Cancel") ?: @"Cancel")
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];

    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    if (popover) {
        UICollectionViewCell *heroCell =
            [self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
        popover.sourceView = heroCell ?: self.view;
        popover.sourceRect = heroCell ? heroCell.bounds : self.view.bounds;
    }

    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)switchHomeLocationBackToAutomatic
{
    self.isUsingManualNearbySelection = NO;
    if (!self.homeLocationManager) {
        [self refreshHeroSectionAppearance];
        return;
    }

    CLAuthorizationStatus status;
    if (@available(iOS 14.0, *)) {
        status = self.homeLocationManager.authorizationStatus;
    } else {
        status = [CLLocationManager authorizationStatus];
    }
    [self updateLocationStateForAuthorizationStatus:status];
}

- (void)openLocationSettings
{
    NSURL *settingsURL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    if ([[UIApplication sharedApplication] canOpenURL:settingsURL]) {
        [[UIApplication sharedApplication] openURL:settingsURL options:@{} completionHandler:nil];
    }
}

- (void)handleAppWillEnterForeground
{
    if (self.homeLocationManager && !self.isUsingManualNearbySelection) {
        CLAuthorizationStatus status;
        if (@available(iOS 14.0, *)) {
            status = self.homeLocationManager.authorizationStatus;
        } else {
            status = [CLLocationManager authorizationStatus];
        }
        [self updateLocationStateForAuthorizationStatus:status];
    }
    [self refreshCurrentOrdersForce:YES];
    [self refreshNearbyAdsForce:YES reason:@"foreground"];
}

- (void)handleAdUploadCompletedNotification:(NSNotification *)notification
{
    [self refreshNearbyAdsForce:YES reason:@"ad-upload"];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.isHomeScreenVisible = YES;
    [self pp_centerNearbySectionIfPossible];
    //[PPHUD showLoading];
    if(!self.warmUpCache)
    {
        NSLog(@"Starting cache warm-up...");
        [[SearchCacheManager shared] warmUpCacheIfNeeded:^{
            NSLog(@"Cache Warm Up Complete ****** *******...");
        }];
        NSLog(@"Cache warm-up initiated");;
        self.warmUpCache = YES;
    }
    
    NSString *currentUserID = UserManager.sharedManager.currentUser.ID;
    if (currentUserID.length > 0) {
        if (!self.chatsListenerStarted ||
            ![self.unreadListenerUserID isEqualToString:currentUserID]) {
            self.chatsListenerStarted = YES;
            self.unreadListenerUserID = currentUserID;
            [[ChManager sharedManager] startGlobalUnreadListenerForUser:currentUserID];
        }
    } else {
        self.chatsListenerStarted = NO;
        self.unreadListenerUserID = nil;
    }
    [self.view bringSubviewToFront:self.profileCard];
    
    
    [self refreshHeroSectionAppearance];
    if (self.homeLocationManager) {
        CLAuthorizationStatus status;
        if (@available(iOS 14.0, *)) {
            status = self.homeLocationManager.authorizationStatus;
        } else {
            status = [CLLocationManager authorizationStatus];
        }
        [self updateLocationStateForAuthorizationStatus:status];
    }
    
    if (!self.didRegisterTimeChangeObserver) {
        self.didRegisterTimeChangeObserver = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleTimeChange)
                                                     name:UIApplicationSignificantTimeChangeNotification
                                                   object:nil];
    }

}

- (void)handleTimeChange
{
    // Time crossed hour / day / DST → refresh hero
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshHeroSectionAppearance];
    });
}



#pragma mark - Categories Selection

- (BOOL)isSelected:(PPHomeItem *)item
{
    // "All" option
    if ([item.payload isKindOfClass:NSString.class]) {
        return self.selectedCategory == nil;
    }

    if (![item.payload isKindOfClass:MainKindsModel.class]) {
        return NO;
    }

    MainKindsModel *kind = (MainKindsModel *)item.payload;

    if (!self.selectedCategory) {
        return NO;
    }

    return kind.ID == self.selectedCategory.ID;
}


- (PPHomeHeaderConfig *)headerConfigForSection:(PPHomeSection)section
{
    PPHomeHeaderConfig *cfg = [PPHomeHeaderConfig new];

    cfg.section = section;
    cfg.hidden = YES; // default SAFE
    NSString *arrowImage = Language.isRTL ?  @"arrow.left" :  @"arrow.right";

    switch (section) {
        case PPHomeSectionSuggestions: {
            cfg.hidden = NO;
            cfg.title = kLang(@"SuggestedForYou");
            //cfg.actionTitle = kLang(@"ShowLess");
            cfg.iconName = arrowImage;
             cfg.subtitle = kLang(@"RecommendedForYouHint");
            
            NSDictionary *event =
                [[PPBrowseHistoryManager shared] latestEvent];

            if (event) {
                NSInteger kindID = [event[@"kind"] integerValue];
                PPBrowseItemType type = [event[@"type"] integerValue];

                MainKindsModel *kind = [self resolveMainKindWithID:kindID];
                if (kind) {
                    NSString *typeKey =
                        type == PPBrowseItemTypeAd
                        ? kLang(@"BrowseType_Ads")
                        : type == PPBrowseItemTypeAccessory
                            ? kLang(@"BrowseType_Accessories")
                            : kLang(@"BrowseType_Services");

                    cfg.subtitle =
                        [NSString stringWithFormat:
                         kLang(@"BecauseYouViewedFormat"),
                         typeKey,kind.KindName
                         ];
                }
            }

            break;
        }

        case PPHomeSectionCurrentOrders: {
            cfg.hidden = !(self.currentOrdersLoading || [self pp_featuredHomeOrder] != nil);
            cfg.title = kLang(@"Home_LastOrderTitle");
            cfg.subtitle = kLang(@"Home_LastOrderSubtitle");
            cfg.actionTitle = kLang(@"OrderHistory");
            cfg.iconName = arrowImage;
            break;
        }
            
        case PPHomeSectionMainKinds:
        {
            cfg.hidden = NO;
            cfg.title = kLang(@"MainCategories");
            //cfg.actionTitle = self.isMainKindsExpanded
             //   ? kLang(@"ShowLess")
             //   : kLang(@"ShowAll");

            cfg.iconName = self.isMainKindsExpanded
                ? @"chevron.up"// @"chevron.up.circle"
                : @"chevron.down";

            cfg.menu = nil; // IMPORTANT – header tap controls layout
            break;
        }

        case PPHomeSectionAccessories: {
            cfg.hidden = NO;
            cfg.title = kLang(@"Accessories");
           // cfg.actionTitle = kLang(@"ShowAll");
            cfg.iconName = @"list.bullet";

            cfg.menu =
                [PPActionButton generateActionsForMainKind:MKM.MainKindsArray
                                                 tintColor:AppPrimaryTextClr
                                                   handler:^(MainKindsModel *category) {
                [self handleDeepLinkWithTarget:PPDeepLinkTargetAccessories
                                      mainKind:category
                                        source:PPInputSourceHomeAccessoriesSection];
            }];
            break;
        }

        case PPHomeSectionAdsNearBy: {
            cfg.hidden = NO;
            cfg.title = kLang(@"Home_NearbyAds");
           // cfg.actionTitle = kLang(@"ShowAll");
            cfg.iconName = arrowImage;
            break;
        }

        case PPHomeSectionBuyAgain: {
            cfg.hidden = self.buyAgainAccessories.count == 0;
            cfg.title = kLang(@"Home_BuyAgainTitle");
            cfg.subtitle = kLang(@"Home_BuyAgainSubtitle");
            cfg.actionTitle = kLang(@"ShowAll");
            cfg.iconName = arrowImage;
            break;
        }

        default:
            break;
    }

    return cfg;
}

#pragma mark - CollectionView


- (void)setupCollectionView {
    if (self.collectionView) {
        return;
    }

    self.layoutManager =
        [[PPHomeLayoutManager alloc] initWithMainKindsExpanded:self.isMainKindsExpanded];
    self.layoutManager.isCurrentOrdersExpanded = self.isCurrentOrdersExpanded;
  
    
    UICollectionViewCompositionalLayout *layout =
        [self.layoutManager buildLayout];

    self.collectionView =
        [[UICollectionView alloc] initWithFrame:CGRectZero
                           collectionViewLayout:layout];

    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.backgroundColor = UIColor.clearColor;
    self.collectionView.delegate = self;
    self.collectionView.prefetchingEnabled = YES;
    self.collectionView.prefetchDataSource = self;
   

    //self.collectionView.contentInset = UIEdgeInsetsMake(0, 6, 6, 6);
    self.collectionView.scrollIndicatorInsets = self.collectionView.contentInset;
    self.collectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    
    
    [self.view addSubview:self.collectionView];

    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView.topAnchor
            constraintEqualToAnchor:self.view.topAnchor],
         [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
         [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
         [self.collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:0]
    ]];
    
    [self.collectionView registerClass:PPHomeHeroCell.class
            forCellWithReuseIdentifier:PPHomeHeroCell.reuseIdentifier];
    [self.collectionView registerClass:PPHomeOrderStatusCell.class
            forCellWithReuseIdentifier:PPHomeOrderStatusCell.reuseIdentifier];
    [self.collectionView registerClass:PPCategoryCardCell.class forCellWithReuseIdentifier:PPCategoryCardCell.reuseIdentifier];
    [self.collectionView registerClass:PPUniversalCell.class forCellWithReuseIdentifier:PPUniversalCell.reuseIdentifier];
    [self.collectionView registerClass:PPHomeCell.class forCellWithReuseIdentifier:@"PPHomeCell"];
    [self.collectionView registerClass:PPHomeActionCell.class forCellWithReuseIdentifier:@"PPHomeActionCell"];

    [self.collectionView registerClass:PPCarouselContainerCell.class forCellWithReuseIdentifier:@"PPCarouselContainerCell"];
    [self.collectionView registerClass:PPHomeServicesCell.class forCellWithReuseIdentifier:PPHomeServicesCell.reuseIdentifier];
    [self.collectionView registerClass:PPBannerCollectionCell.class forCellWithReuseIdentifier:PPBannerCollectionCell.reuseIdentifier];
    [self.collectionView registerClass:PetAdoptCollectionViewCell.class forCellWithReuseIdentifier:@"PetAdoptCollectionViewCell"];
    
    [self.collectionView registerClass:PPSectionHeaderView.class
            forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                   withReuseIdentifier:@"PPSectionHeaderView"];
    
    [self.collectionView registerClass:PPCollectionSectionHeader.class
            forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                   withReuseIdentifier:@"PPCollectionSectionHeader"];
    
    [self.collectionView registerClass:PPCategoryCardCell.class
            forCellWithReuseIdentifier:PPCategoryCardCell.reuseIdentifier];
}


- (void)reloadCarouselBanner
{
    NSDiffableDataSourceSnapshot *snapshot = self.dataSource.snapshot;

    NSArray *items =
        [snapshot itemIdentifiersInSectionWithIdentifier:@(PPHomeSectionCarousel)];
    if (items.count == 0) return;

    [snapshot reloadItemsWithIdentifiers:items];

    [self.dataSource applySnapshot:snapshot animatingDifferences:NO];
}



#pragma mark - DataSource
- (void)configureDataSource {
    __weak typeof(self) weakSelf = self;

    self.dataSource =
        [[UICollectionViewDiffableDataSource alloc]
         initWithCollectionView:self.collectionView
                   cellProvider:^UICollectionViewCell *_Nullable
             (UICollectionView *collectionView, NSIndexPath *indexPath, PPHomeItem *item) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return [collectionView dequeueReusableCellWithReuseIdentifier:PPUniversalCell.reuseIdentifier
                                                             forIndexPath:indexPath];
        }
        PPHomeSection section = [strongSelf sectionTypeForIndexPath:indexPath];

        if (section == PPHomeSectionHero) {
            PPHomeHeroCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:PPHomeHeroCell.reuseIdentifier
                                                          forIndexPath:indexPath];
            [strongSelf pp_configureHeroCell:cell];
            return cell;
        }

        if (section == PPHomeSectionCurrentOrders) {
            PPHomeOrderStatusCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:PPHomeOrderStatusCell.reuseIdentifier
                                                          forIndexPath:indexPath];
            BOOL expanded = strongSelf.isCurrentOrdersExpanded;

            if (item.payload == [NSNull null] || ![item.payload isKindOfClass:PPOrder.class]) {
                [cell configurePlaceholderExpanded:expanded];
                return cell;
            }

            PPOrder *order = (PPOrder *)item.payload;
            [cell configureWithOrderReference:[order displayOrderReference]
                             orderKickerTitle:[strongSelf pp_homeOrderKickerTitle:order]
                              previewImageURLs:[strongSelf pp_homeOrderPreviewImageURLs:order limit:3]
                                         meta:[strongSelf pp_homeOrderMetaText:order]
                                  statusTitle:[strongSelf pp_homeOrderStatusTitle:order]
                                   statusHint:[strongSelf pp_homeOrderStatusHint:order]
                                     progress:[strongSelf pp_homeOrderProgress:order]
                                   footerText:[strongSelf pp_homeOrderFooterText:order]
                                  statusColor:[strongSelf pp_homeOrderStatusColor:order]
                               statusIconName:[strongSelf pp_homeOrderStatusIconName:order]
                                  actionTitle:(kLang(@"order_action_track") ?: @"Track order")
                                     expanded:expanded];

            __weak typeof(strongSelf) weakHome = strongSelf;
            cell.onTrackTap = ^{
                __strong typeof(weakHome) self = weakHome;
                if (!self) return;
                [self pp_openOrderDetailsForOrder:order];
            };
            cell.onHistoryTap = ^{
                __strong typeof(weakHome) self = weakHome;
                if (!self) return;
                [self handleSeeAllForSection:PPHomeSectionCurrentOrders];
            };
            return cell;
        }
            
        if (section == PPHomeSectionCarousel) {
            
            PPBannerCollectionCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:@"PPBannerCollectionCell"
                                                          forIndexPath:indexPath];

            if (item.payload == [NSNull null]) {
                // 🔥 Soft placeholder — NO skeleton, NO shimmer
                [cell configurePlaceholder];
               
                
                return cell;
            }

            if ([item.payload isKindOfClass:NSArray.class]) {
                NSArray *promoCards = (NSArray *)item.payload;
                BOOL hasPromoCardObjects =
                    promoCards.count > 0 &&
                    [promoCards.firstObject isKindOfClass:PPHomePromoCarouselCard.class];

                if (hasPromoCardObjects) {
                    __weak typeof(strongSelf) weakHome = strongSelf;
                    [cell configureWithPromoCards:(NSArray<PPHomePromoCarouselCard *> *)promoCards
                                        onCardTap:^(PPHomePromoCarouselCard *card) {
                        __strong typeof(weakHome) self = weakHome;
                        if (!self) return;
                        [self pp_handlePromoCardTap:card interaction:@"card"];
                    }
                                     onPrimaryTap:^(PPHomePromoCarouselCard *card) {
                        __strong typeof(weakHome) self = weakHome;
                        if (!self) return;
                        [self pp_handlePromoCardTap:card interaction:@"primary"];
                    }
                                   onSecondaryTap:^(PPHomePromoCarouselCard *card) {
                        __strong typeof(weakHome) self = weakHome;
                        if (!self) return;
                        [self pp_handlePromoCardTap:card interaction:@"secondary"];
                    }];
                    return cell;
                }
            }

            MainBannerModel *homeTop = [strongSelf pp_homeTopCarouselBannerGroup];

            if (!homeTop || homeTop.childBanners.count == 0) {
                [cell configurePlaceholder];
                return cell;
            }

            [cell configureWithBanners:homeTop.childBanners
                                 group:homeTop
                              delegate:strongSelf];
            
            return cell;
        }
            
        /*
        if (indexPath.section == PPHomeSectionCategoriesOptions) {
            PPCategoryCardCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:
                    PPCategoryCardCell.reuseIdentifier
                                                            forIndexPath:indexPath];
            BOOL isAll = [item.payload isKindOfClass:NSString.class];
            MainKindsModel *kind = isAll ? nil : (MainKindsModel *)item.payload;

            // selection state
            BOOL selected = NO;
            if (isAll) {
                selected = (self.selectedCategory == nil);
            } else if (self.selectedCategory) {
                selected = (kind.ID == self.selectedCategory.ID);
            }

            [cell configureWithMainKind:kind
                                    isAll:isAll
                                selected:selected];

            // Wire up selection for category options
            __weak typeof(self) weakSelf = self;
            cell.onSelect = ^(MainKindsModel *kind, BOOL isAll) {
                if (isAll) {
                    [weakSelf didSelectCategory:nil];   // "All"
                } else {
                    [weakSelf didSelectCategory:kind];
                }
            };

            return cell;
        }
        if (indexPath.section == PPHomeSectionCategoriesItems) {
            PPUniversalCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:
                    PPUniversalCell.reuseIdentifier
                                                            forIndexPath:indexPath];

            PPUniversalCellViewModel *vm = item.universalViewModel;
            vm.indexPath = indexPath;

            [cell applyViewModel:vm
                            context:PPCellForVets
                        layoutMode:PPCellLayoutModeSquare
                    discountMode:PPDiscountStylePlain
                        imageLoader:^(UIImageView *iv, NSString *url, UIImage *ph, UIView *card) {
                [GM pp_setImageURL:url imageView:iv placeholder:@"placeholder"];
            }];

            return cell;
        }
        */
            
        if (section == PPHomeSectionServices) {
            PPHomeServicesCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:PPHomeServicesCell.reuseIdentifier
                                                                                 forIndexPath:indexPath];
            
            if (item.payload == [NSNull null]) {
                [cell configureSkeleton];
                return cell;
            }

            PPHomeServiceItem *service = (PPHomeServiceItem *)item.payload;
            [cell configureWithService:service];
            
            __weak typeof(cell) weakCell = cell;
             cell.onTap = ^{
                __strong typeof(weakCell) cell = weakCell;
                NSIndexPath *path = [collectionView indexPathForCell:cell];

                if (path) {
                    NSLog(@"onTap");
                    [strongSelf collectionView:collectionView
                        didSelectItemAtIndexPath:path];
                }
            };
            cell.onTapMenu = ^(PPHomeServiceItem *_Nonnull service, MainKindsModel *_Nonnull mainKindModel) {
                NSLog(@"onTapMenu %ld", mainKindModel.ID);
                PPDeepLinkTarget targt = service.type == PPHomeServiceTypeGrooming ? PPDeepLinkTargetGrooming : service.type == PPHomeServiceTypeTraining ? PPDeepLinkTargetTraning : PPDeepLinkTargetFood;
                [weakSelf handleDeepLinkWithTarget:targt
                                          mainKind:mainKindModel
                                            source:PPInputSourceHomeServicesSection];
            };

            return cell;
        }
            
             
            if (section == PPHomeSectionAdopt) {
            PetAdoptCollectionViewCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:@"PetAdoptCollectionViewCell"
                                                          forIndexPath:indexPath];

            [cell configureWithTitle:kLang(@"Adopt a Pet")
                            subtitle:kLang(@"Find your new best friend")
                           seedImage:[UIImage imageNamed:@"icn_cat"]];

            __weak typeof(cell) weakCell = cell;
            cell.onTap = ^{
                __strong typeof(weakCell) tappedCell = weakCell;
                NSIndexPath *path = [collectionView indexPathForCell:tappedCell];
                if (path) {
                    [strongSelf collectionView:collectionView didSelectItemAtIndexPath:path];
                }
            };

            return cell;
        }
            
                if (section == PPHomeSectionSuggestions) {

                if (item.payload == [NSNull null]) {
                    PPUniversalCell *cell =
                            [collectionView dequeueReusableCellWithReuseIdentifier:PPUniversalCell.reuseIdentifier
                                                                      forIndexPath:indexPath];
                        return cell; // height-only placeholder
                    }

            // ✅ REAL CONTENT
            PPUniversalCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:
                    PPUniversalCell.reuseIdentifier
                                                        forIndexPath:indexPath];
            cell.delegate = strongSelf;

            PPUniversalCellViewModel *vm = item.universalViewModel;
            if (!vm || !vm.ModelObject) {
                return cell;
            }

            vm.indexPath = indexPath;

            [cell applyViewModel:vm
                         context:vm.modelContext
                      layoutMode:PPCellLayoutModeSquare
                    discountMode:PPDiscountStyleBadge
                     imageLoader:^(UIImageView *iv,
                                   NSString *url,
                                   UIImage *placeholder,
                                   UIView *card) {
                (void)placeholder;
                (void)card;

                UIImage *fallback =
                vm.placeholder ?: [UIImage imageNamed:@"placeholder"];
                iv.image = fallback;

                NSString *currentHash = vm.blurHash;
                __weak UIImageView *weakIV = iv;

                if (currentHash.length > 0) {
                    [strongSelf pp_asyncBlurHashImageForHash:currentHash
                                                         size:CGSizeMake(40, 40)
                                                   completion:^(UIImage * _Nullable blurImage) {
                        if (!blurImage || !weakIV) {
                            return;
                        }
                        if (![currentHash isEqualToString:vm.blurHash]) {
                            return;
                        }
                        [UIView performWithoutAnimation:^{
                            if (weakIV.image == fallback) {
                                weakIV.image = blurImage;
                            }
                        }];
                    }];
                }

                [[PPImageLoaderManager shared]
                    setImageOnImageView:iv
                                     url:url
                              placeholder:fallback
                          transitionStyle:PPImageTransitionStyleNone
                               complation:nil];
            }];

            return cell;
        }

       
                if (section == PPHomeSectionMainKinds) {

                PPHomeCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:@"PPHomeCell"
                                                          forIndexPath:indexPath];

                // ⛔️ HARD GUARD – skeleton or invalid payload
                if (![item.payload isKindOfClass:MainKindsModel.class]) {
                    // skeleton cell
                        [cell configureWithMainKind:nil
                                              isAll:YES
                                          selected:(strongSelf.selectedCategory == nil)];
                        return cell;
                    }

                MainKindsModel *kind = (MainKindsModel *)item.payload;
                BOOL isAll = (kind.ID == -1);

 
                // selection state
                    BOOL selected = NO;
                    if (isAll) {
                        selected = (strongSelf.selectedCategory == nil);
                    } else if (strongSelf.selectedCategory) {
                        selected = (kind.ID == strongSelf.selectedCategory.ID);
                    }

                if (selected) {
                    NSLog(@"[Home][MainKinds][Cell] ✅ SELECTED → %@", kind.KindName);
                }

                [cell configureWithMainKind:kind
                                        isAll:isAll
                                    selected:selected];

                __weak typeof(strongSelf) weakStrongSelf = strongSelf;
                cell.onSelect = ^(MainKindsModel *kind, BOOL isAll) {
                    __strong typeof(weakStrongSelf) strongSelf = weakStrongSelf;
                    if (!strongSelf) return;

                    // ✅ ONLY update selection state here
                    strongSelf.selectedCategory = isAll ? nil : kind;
                    
                    if (isAll) {
                        NSLog(@"[Home][MainKinds][Action] ALL selected → deep link");
                        [strongSelf handleDeepLinkWithTarget:PPDeepLinkTargetAllCategories
                                                     mainKind:nil
                                                       source:PPInputSourceHomeMainKindsSection];
                    } else {
                        NSLog(@"[Home][MainKinds][Action] Kind selected → %@",
                              kind.KindName);
                        [strongSelf handleMainKindSelection:(MainKindsModel *)item.payload];
                    }
                    
                    

                    
                     // 🔁 Refresh main kinds visuals only
                     NSDiffableDataSourceSnapshot *snapshot = strongSelf.dataSource.snapshot;
                     NSArray *items =
                         [snapshot itemIdentifiersInSectionWithIdentifier:@(PPHomeSectionMainKinds)];
                     [snapshot reloadItemsWithIdentifiers:items];

                     [strongSelf.dataSource applySnapshot:snapshot animatingDifferences:YES];
                     
                
                };


                return cell;
            }

        if (section == PPHomeSectionAdsNearBy &&
            [item.payload isKindOfClass:NSString.class]) {
            PPHomeActionCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:PPHomeActionCell.reuseIdentifier
                                                          forIndexPath:indexPath];
            NSString *token = (NSString *)item.payload;
            if ([token isEqualToString:@"nearby-empty-state"]) {
                [cell configureWithTitle:kLang(@"No nearby ads available")
                              systemIcon:@"location.slash.fill"];
                __weak typeof(strongSelf) weakSelfAction = strongSelf;
                cell.onTap = ^{
                    __strong typeof(weakSelfAction) self = weakSelfAction;
                    if (!self) return;
                    self.nearbyRadiusKm = MIN(PPNearbyExpandedRadiusKm, self.nearbyRadiusKm + 3.0);
                    [self refreshNearbyAdsForce:YES reason:@"expand-radius"];
                };
            } else {
                [cell configureWithTitle:kLang(@"Loading...")
                              systemIcon:@"hourglass"];
                cell.onTap = nil;
            }
            return cell;
        }
            
            
            PPUniversalCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:PPUniversalCell.reuseIdentifier forIndexPath:indexPath];
                cell.delegate = strongSelf;
        if (item.universalViewModel) {
            
            
            PPUniversalCellViewModel *vm = item.universalViewModel;
            vm.indexPath = indexPath;
            [cell applyViewModel:vm
                         context:vm.modelContext
                      layoutMode:PPCellLayoutModeSquare
                    discountMode:PPDiscountStyleBadge
                     imageLoader:^(UIImageView *iv,
                                   NSString *url,
                                   UIImage *placeholder,
                                   UIView *card) {
                (void)placeholder;
                (void)card;

                UIImage *fallback =
                vm.placeholder ?: [UIImage imageNamed:@"placeholder"];
                iv.image = fallback;

                NSString *currentHash = vm.blurHash;
                __weak UIImageView *weakIV = iv;

                if (currentHash.length > 0) {
                    [strongSelf pp_asyncBlurHashImageForHash:currentHash
                                                         size:CGSizeMake(40, 40)
                                                   completion:^(UIImage * _Nullable blurImage) {
                        if (!blurImage || !weakIV) {
                            return;
                        }
                        if (![currentHash isEqualToString:vm.blurHash]) {
                            return;
                        }
                        [UIView performWithoutAnimation:^{
                            if (weakIV.image == fallback) {
                                weakIV.image = blurImage;
                            }
                        }];
                    }];
                }

                [[PPImageLoaderManager shared]
                 setImageOnImageView:iv
                                  url:url
                           placeholder:fallback
                       transitionStyle:PPImageTransitionStyleNone
                            complation:nil];
            }];
            
             
        }

        return cell;
    }];

    // =========================
    // Supplementary Views
    // =========================
   

    self.dataSource.supplementaryViewProvider =
    ^UICollectionReusableView * _Nullable(UICollectionView *collectionView,
                                          NSString *kind,
                                          NSIndexPath *indexPath)
    {
        if (![kind isEqualToString:UICollectionElementKindSectionHeader]) {
            return nil;
        }

        NSArray *sectionIDs = weakSelf.dataSource.snapshot.sectionIdentifiers;
        if (indexPath.section >= (NSInteger)sectionIDs.count) return nil;
        NSNumber *sectionID = sectionIDs[indexPath.section];
        PPHomeSection section = (PPHomeSection)sectionID.integerValue;

        PPHomeHeaderConfig *cfg =
            [weakSelf headerConfigForSection:section];

        PPSectionHeaderView *header =
        [collectionView dequeueReusableSupplementaryViewOfKind:kind
                                           withReuseIdentifier:@"PPSectionHeaderView"
                                                  forIndexPath:indexPath];
 

        if (cfg.hidden) {
            header.hidden = YES;
            return header;
        }

        header.hidden = NO;

        [header configureWithTitle:cfg.title
                          subtitle:cfg.subtitle
                       actionTitle:cfg.actionTitle
                          iconName:cfg.iconName
                              menu:cfg.section == PPHomeSectionMainKinds ? nil : cfg.menu
                     ppHomeSection:cfg.section];

        header.onTap = ^{
            [weakSelf handleSeeAllForSection:cfg.section];
        };

        return header;
    };
    
    
    
    /*self.dataSource.supplementaryViewProvider =
    ^UICollectionReusableView * _Nullable(UICollectionView *collectionView,
                                          NSString *kind,
                                          NSIndexPath *indexPath)
    {
        
        NSNumber *sectionID = weakSelf.dataSource.snapshot.sectionIdentifiers[indexPath.section];
        PPHomeSection section = (PPHomeSection)sectionID.integerValue;
        
        if (section == PPHomeSectionMainKinds)
        {
            PPCollectionSectionHeader *header =
                [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                                                   withReuseIdentifier:@"PPCollectionSectionHeader"
                                                          forIndexPath:indexPath];

            [header configureWithTitle:@"إدارة الإنتاج"
                              subtitle:@"آخر العناصر المضافة"
                           actionTitle:@"عرض الكل"
                                action:^{
                                    [weakSelf handleSeeAllForSection:PPHomeSectionMainKinds];
                                }];

            return header;
        }
        
        PPSectionHeaderView *header =
        [collectionView dequeueReusableSupplementaryViewOfKind:kind
                                           withReuseIdentifier:@"PPSectionHeaderView"
                                                  forIndexPath:indexPath];

        PPHomeHeaderConfig *cfg =
        [weakSelf headerConfigForSection:section];

        if (cfg.hidden) {
            header.hidden = YES;
            return header;
        }

        header.hidden = NO;

        if (cfg.subtitle.length > 0) {
            [header configureWithTitle:cfg.title
                              subtitle:cfg.subtitle
                           actionTitle:cfg.actionTitle
                              iconName:cfg.iconName
                                  menu:cfg.section == PPHomeSectionMainKinds ? nil : cfg.menu
                         ppHomeSection:cfg.section];
        } else {
            [header configureWithTitle:cfg.title
                           actionTitle:cfg.actionTitle
                              iconName:cfg.iconName
                                  menu:cfg.section == PPHomeSectionMainKinds ? nil : cfg.menu
                         ppHomeSection:cfg.section];
        }

        header.onTap = ^{
            if (cfg.section == PPHomeSectionMainKinds) {
                [weakSelf handleSeeAllForSection:cfg.section];
                //[weakSelf handleMainKindsHeaderTap];
            } else {
                [weakSelf handleSeeAllForSection:cfg.section];
            }
        };

        return header;
    };*/
    
}

- (void)invalidateHeaderForSection:(PPHomeSection)section
{
    NSInteger sectionIndex = [self sectionIndexForType:section];
    if (sectionIndex == NSNotFound) return;

    UICollectionViewLayout *layout = self.collectionView.collectionViewLayout;

    if ([layout isKindOfClass:UICollectionViewCompositionalLayout.class]) {
        [layout invalidateLayout];
    }
}
#pragma mark - MainKinds Header Tap

- (void)handleMainKindsHeaderTap
{
    NSLog(@"[Home][MainKinds] Header tapped → open ALL categories (PPDataViewVC)");

    if (self.mainKinds.count == 0) {
        NSLog(@"[Home][MainKinds] ❌ No categories available");
        return;
    }

    // Build input object for PPDataViewVC
    PPDataViewInput *input = [PPDataViewInput inputWithMainKindsArr:self.mainKinds sourceTarget:PPDeepLinkTargetAllCategories source:PPInputSourceHomeMainKindsSection];
    PPDataViewVC *vc =  [[PPDataViewVC alloc] initWithInput:input];
    vc.pp_transitionStyle = PPTransitionStyleNone;
    input.title = kLang(@"MainCategories");
    if (![PPHomeHelper pushViewControllerSafely:vc from:self animated:YES]) {
        return;
    }
    //input.layout = PPDataLayoutGrid;                 // ✅ grid lives here
    //input.items = ;

  
}

#pragma mark - Data
- (void)loadData {
    __weak typeof(self) weakSelf = self;

    /*
     [[PetAdManager sharedManager]
      fetchLatestAdsWithLimit:8
                   completion:^(NSArray<PetAd *> *ads) {
         weakSelf.ads = ads ? : @[];
         weakSelf.adsLoaded = YES;
         [weakSelf tryApplySnapshot];
     }];
     */

    [[PetAccessoryManager sharedManager] fetchLatestAccessoriesWithLimit:50
                          completion:^(NSArray *accessories, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [PPHUD showError:kLang(@"SomethingWentWrong")];
            });
            return;
        }
        
        NSArray *source = accessories ?: @[];
        NSArray *sorted =
        [source sortedArrayUsingComparator:^NSComparisonResult(PetAccessory *a, PetAccessory *b) {

            BOOL aHasDiscount = (a.discountPercent > 0 || a.discountAmount > 0);
            BOOL bHasDiscount = (b.discountPercent > 0 || b.discountAmount > 0);

            if (aHasDiscount && !bHasDiscount) return NSOrderedAscending;
            if (!aHasDiscount && bHasDiscount) return NSOrderedDescending;
            
            NSDate *aDate = a.createdAt ?: [NSDate distantPast];
            NSDate *bDate = b.createdAt ?: [NSDate distantPast];
            NSComparisonResult dateOrder = [bDate compare:aDate];
            if (dateOrder != NSOrderedSame) return dateOrder;

            NSString *aID = PPSafeString(a.accessoryID);
            NSString *bID = PPSafeString(b.accessoryID);
            return [aID compare:bID options:NSCaseInsensitiveSearch];
        }];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.accessories = sorted;
            self.accessoriesLoaded = YES;
            [self pp_refreshBuyAgainSection];
            [self reloadSection:PPHomeSectionCurrentOrders];
            [self reloadSection:PPHomeSectionAccessories];
            [self reloadSection:PPHomeSectionSuggestions];
            [self tryApplySnapshot];
            [self pp_prefetchTopImagesWithLimit:20];
        });
   
    }];

    [self refreshCurrentOrdersForce:YES];
    [self refreshNearbyAdsForce:YES reason:@"initial-load"];
}

- (void)refreshNearbyAdsForce:(BOOL)force reason:(NSString *)reason
{
    if (!self.hasSelectedNearbyCoordinate ||
        !CLLocationCoordinate2DIsValid(self.selectedNearbyCoordinate)) {
        self.nearbyAds = @[];
        self.nearbyLoading = NO;
        self.nearbyLoaded = YES;
        [self reloadSection:PPHomeSectionAdsNearBy];
        [self reloadSection:PPHomeSectionSuggestions];
        [self tryApplySnapshot];
        return;
    }

    NSDate *now = [NSDate date];
    if (!force && self.lastNearbyRefreshAt) {
        NSTimeInterval elapsed = [now timeIntervalSinceDate:self.lastNearbyRefreshAt];
        if (elapsed < PPNearbyMinimumRefreshInterval && self.hasLastNearbyRefreshCoordinate) {
            CLLocation *last =
                [[CLLocation alloc] initWithLatitude:self.lastNearbyRefreshCoordinate.latitude
                                           longitude:self.lastNearbyRefreshCoordinate.longitude];
            CLLocation *current =
                [[CLLocation alloc] initWithLatitude:self.selectedNearbyCoordinate.latitude
                                           longitude:self.selectedNearbyCoordinate.longitude];
            if ([current distanceFromLocation:last] < 150.0) {
                return;
            }
        }
    }

    self.nearbyRequestToken += 1;
    NSInteger requestToken = self.nearbyRequestToken;
    self.nearbyLoading = YES;
    if (self.nearbyAds.count == 0) {
        [self reloadSection:PPHomeSectionAdsNearBy];
    }

    __weak typeof(self) weakSelf = self;
    [[PetAdManager sharedManager]
        fetchNearbyAdsAtCoordinate:self.selectedNearbyCoordinate
                          radiusKm:self.nearbyRadiusKm
                             limit:30
                          category:0
                        completion:^(NSArray<PetAd *> *ads) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (requestToken != self.nearbyRequestToken) {
            return; // stale response guard
        }

        NSMutableDictionary<NSString *, PetAd *> *uniqueByID = [NSMutableDictionary dictionary];
        for (PetAd *ad in ads ?: @[]) {
            if (!ad.adID.length) continue;
            uniqueByID[ad.adID] = ad;
        }

        NSArray<PetAd *> *deduped =
            [uniqueByID.allValues sortedArrayUsingComparator:^NSComparisonResult(PetAd *a, PetAd *b) {
            NSDate *aDate = a.createdAt ?: a.postedDate ?: [NSDate distantPast];
            NSDate *bDate = b.createdAt ?: b.postedDate ?: [NSDate distantPast];
            NSComparisonResult dateOrder = [bDate compare:aDate];
            if (dateOrder != NSOrderedSame) return dateOrder;
            return [a.adID compare:b.adID options:NSCaseInsensitiveSearch];
        }];
        if (deduped.count == 0) {
            // 🔁 Fallback: show latest 5 ads when no nearby ads found
            [[PetAdManager sharedManager] fetchLatestAdsWithLimit:5
                                                       completion:^(NSArray<PetAd *> *latestAds) {
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;

                self.nearbyAds = latestAds ?: @[];
                self.nearbyLoaded = YES;
                self.nearbyLoading = NO;
                self.lastNearbyRefreshAt = [NSDate date];
                self.lastNearbyRefreshCoordinate = self.selectedNearbyCoordinate;
                self.hasLastNearbyRefreshCoordinate = YES;

                [self reloadSection:PPHomeSectionAdsNearBy];
                [self reloadSection:PPHomeSectionSuggestions];
                [self tryApplySnapshot];
                [self pp_prefetchTopImagesWithLimit:24];
            }];
            return;
        } else {
            self.nearbyAds = deduped;
        }
        self.nearbyLoaded = YES;
        self.nearbyLoading = NO;
        self.lastNearbyRefreshAt = [NSDate date];
        self.lastNearbyRefreshCoordinate = self.selectedNearbyCoordinate;
        self.hasLastNearbyRefreshCoordinate = YES;

        NSLog(@"[HomeNearby] refreshed reason=%@ radius=%.1fkm count=%lu",
              reason, self.nearbyRadiusKm, (unsigned long)self.nearbyAds.count);

        [self reloadSection:PPHomeSectionAdsNearBy];
        [self reloadSection:PPHomeSectionSuggestions];
        [self tryApplySnapshot];
        [self pp_prefetchTopImagesWithLimit:24];

        if (!self.didAutoScrollSuggestions && self.nearbyAds.count > 1) {
            self.didAutoScrollSuggestions = YES;
            [self autoScrollIndextoIndex:2 inSection:PPHomeSectionSuggestions];
        }
    }];
}

- (void)tryApplySnapshot {
    if (!self.accessoriesLoaded || !self.nearbyLoaded) {
        return;
    }

    // ✅ Data ready → dismiss HUD once
    if ([PPHUD isVisible]) {
        [PPHUD dismiss];
    }
 
}

- (NSString *)pp_currentHeroRenderSignature
{
    NSString *greeting = [self heroGreetingText] ?: @"";
    NSString *name = [self heroDisplayNameText] ?: @"";
    NSString *location = [self heroCountryText] ?: @"";
    NSString *actionTitle = [self heroLocationActionTitle] ?: @"";
    return [NSString stringWithFormat:@"%@|%@|%@|%ld|%@",
            greeting,
            name,
            location,
            (long)self.nearbyLocationState,
            actionTitle];
}

- (void)pp_configureHeroCell:(PPHomeHeroCell *)cell
{
    if (!cell) return;

    [cell configureWithGreeting:[self heroGreetingText]
                       userName:[self heroDisplayNameText]
                       location:[self heroCountryText]
                  locationState:(PPHomeHeroLocationState)self.nearbyLocationState
                    actionTitle:[self heroLocationActionTitle]];

    __weak typeof(self) weakSelf = self;
    cell.onLocationTap = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self openHomeLocationPicker];
    };
    cell.onLocationActionTap = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (self.nearbyLocationState == PPNearbyLocationStateDenied) {
            [self openLocationSettings];
        } else if (self.isUsingManualNearbySelection) {
            [self presentHomeLocationOptions];
        } else {
            [self openHomeLocationPicker];
        }
    };
}

- (void)refreshHeroSectionAppearance
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self refreshHeroSectionAppearance];
        });
        return;
    }

    if (self.heroRefreshScheduled) {
        return;
    }
    self.heroRefreshScheduled = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        self.heroRefreshScheduled = NO;

        if (!self.isViewLoaded || !self.collectionView || !self.dataSource) {
            return;
        }

        NSString *renderSignature = [self pp_currentHeroRenderSignature];
        NSInteger sectionIndex = [self sectionIndexForType:PPHomeSectionHero];
        if (sectionIndex == NSNotFound) {
            return;
        }

        NSIndexPath *heroIndexPath = [NSIndexPath indexPathForItem:0 inSection:sectionIndex];
        PPHomeHeroCell *visibleHeroCell =
            (PPHomeHeroCell *)[self.collectionView cellForItemAtIndexPath:heroIndexPath];
        if (visibleHeroCell) {
            [self pp_configureHeroCell:visibleHeroCell];
            self.lastHeroRenderSignature = renderSignature;
            return;
        }

        if ([renderSignature isEqualToString:self.lastHeroRenderSignature]) {
            return;
        }

        NSDiffableDataSourceSnapshot *snapshot = self.dataSource.snapshot;
        NSArray *items = [snapshot itemIdentifiersInSectionWithIdentifier:@(PPHomeSectionHero)];
        if (items.count == 0) {
            return;
        }

        [snapshot reloadItemsWithIdentifiers:items];
        [self.dataSource applySnapshot:snapshot animatingDifferences:NO];
        self.lastHeroRenderSignature = renderSignature;
    });
}

// MARK: - Carousel Data

#pragma mark - Carousel Data

- (void)reloadHomeCarousel {
    // Convert ads → carousel items
    if (self.ads.count == 0) {
        self.carouselItems = @[];
        return;
    }

    NSMutableArray<PPCarouselItem *> *items = [NSMutableArray array];

    
    for (PetAd *ad in self.ads) {
        
        NSString *imageURL = nil;
        UIImage *placeholder = [UIImage imageNamed:@"placeholder"];

        PetImageItem *firstItem = ad.imageItems.firstObject;
        if (firstItem) {
            imageURL = PPSafeString(firstItem.url);

            if (firstItem.blurHash.length > 0) {
                UIImage *cachedPlaceholder =
                [self.blurHashCache objectForKey:firstItem.blurHash];
                if (cachedPlaceholder) {
                    placeholder = cachedPlaceholder;
                } else {
                    [self pp_asyncBlurHashImageForHash:firstItem.blurHash
                                                  size:CGSizeMake(40, 40)
                                            completion:nil];
                }
            }
        }
        
        
        PPCarouselItem *item =
            [PPCarouselItem itemWithIdentifier:PPSafeString(ad.adID)
                                      imageURL:imageURL
                                         title:PPSafeString(ad.adTitle)
                                      subtitle:@""
                              placeholderImage:placeholder];

        [items addObject:item];
    }

    self.carouselItems = items.copy;
     
}


- (NSInteger)sectionIndexForType:(PPHomeSection)section
{
    NSArray *sections = self.dataSource.snapshot.sectionIdentifiers;

    return [sections indexOfObject:@(section)];
}

- (PPHomeSection)sectionTypeForIndexPath:(NSIndexPath *)indexPath
{
    NSArray<NSNumber *> *sections = self.dataSource.snapshot.sectionIdentifiers;
    if (indexPath.section < sections.count) {
        return (PPHomeSection)sections[indexPath.section].integerValue;
    }
    return (PPHomeSection)indexPath.section;
}

- (void)handleSeeAllForSection:(PPHomeSection)section {
    switch (section) {
        case PPHomeSectionMainKinds: {
            self.isMainKindsExpanded = !self.isMainKindsExpanded;
            self.layoutManager.isMainKindsExpanded = self.isMainKindsExpanded;

            UICollectionViewCompositionalLayout *newLayout =
            [self.layoutManager buildLayout];

            [UIView animateWithDuration:0.25
                                  delay:0
                                options:UIViewAnimationOptionCurveEaseInOut
                             animations:^{
                [self.collectionView setCollectionViewLayout:newLayout
                                                    animated:NO];
                [self.collectionView layoutIfNeeded];
            }
                             completion:nil];
            [self refreshMainKindsHeader];
            break;
        }

        case PPHomeSectionCurrentOrders: {
            OrderHistoryViewController *vc = [[OrderHistoryViewController alloc] init];
            [PPHomeHelper pushViewControllerSafely:vc from:self animated:YES];
            break;
        }

        case PPHomeSectionAccessories:
            [self handleDeepLinkWithTarget:PPDeepLinkTargetAccessories
                                  mainKind:nil
                                    source:PPInputSourceHomeAccessoriesSection];
            break;

        case PPHomeSectionAdsNearBy:
            if (!self.hasSelectedNearbyCoordinate) {
                [self openHomeLocationPicker];
                break;
            }
            [self handleDeepLinkWithTarget:PPDeepLinkTargetNewByAds
                                  mainKind:nil
                                    source:PPInputSourceHomeNearBySection];
            break;

        case PPHomeSectionSuggestions:
            [self handleDeepLinkWithTarget:PPDeepLinkTargetAllCategories
                                  mainKind:nil
                                    source:PPInputSourceHomeMainKindsSection];
            break;

        case PPHomeSectionBuyAgain:
            [self handleDeepLinkWithTarget:PPDeepLinkTargetAccessories
                                  mainKind:nil
                                    source:PPInputSourceHomeAccessoriesSection];
            break;

        default:
            break;
    }
}

- (void)pp_setCurrentOrdersExpanded:(BOOL)expanded animated:(BOOL)animated
{
    if (!self.collectionView || !self.layoutManager) {
        self.isCurrentOrdersExpanded = expanded;
        return;
    }

    if (self.isCurrentOrdersExpanded == expanded &&
        self.layoutManager.isCurrentOrdersExpanded == expanded) {
        return;
    }

    self.isCurrentOrdersExpanded = expanded;
    self.layoutManager.isCurrentOrdersExpanded = expanded;

    NSIndexPath *currentOrderIndexPath = nil;
    NSInteger sectionIndex = [self sectionIndexForType:PPHomeSectionCurrentOrders];
    if (sectionIndex != NSNotFound) {
        currentOrderIndexPath = [NSIndexPath indexPathForItem:0 inSection:sectionIndex];
        UICollectionViewCell *visibleCell =
            [self.collectionView cellForItemAtIndexPath:currentOrderIndexPath];
        if ([visibleCell isKindOfClass:PPHomeOrderStatusCell.class]) {
            [(PPHomeOrderStatusCell *)visibleCell setExpandedState:expanded animated:animated];
        }
    }

    [self invalidateHeaderForSection:PPHomeSectionCurrentOrders];

    UICollectionViewCompositionalLayout *newLayout = [self.layoutManager buildLayout];

    if (!animated) {
        [self.collectionView setCollectionViewLayout:newLayout animated:NO];
        [self.collectionView layoutIfNeeded];
        if (currentOrderIndexPath) {
            UICollectionViewCell *visibleCell =
                [self.collectionView cellForItemAtIndexPath:currentOrderIndexPath];
            if ([visibleCell isKindOfClass:PPHomeOrderStatusCell.class]) {
                [(PPHomeOrderStatusCell *)visibleCell refreshDecorativeLayersForCurrentBounds];
            }
        }
        return;
    }

    __weak typeof(self) weakSelf = self;
    [self.collectionView setCollectionViewLayout:newLayout
                                        animated:YES
                                      completion:^(__unused BOOL finished) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.collectionView) return;

        [self.collectionView layoutIfNeeded];
        if (!currentOrderIndexPath) return;

        UICollectionViewCell *visibleCell =
            [self.collectionView cellForItemAtIndexPath:currentOrderIndexPath];
        if ([visibleCell isKindOfClass:PPHomeOrderStatusCell.class]) {
            [(PPHomeOrderStatusCell *)visibleCell refreshDecorativeLayersForCurrentBounds];
        }
    }];
}


- (void)refreshMainKindsHeader
{
    NSInteger sectionIndex = [self sectionIndexForType:PPHomeSectionMainKinds];
    if (sectionIndex == NSNotFound) return;

    NSIndexPath *indexPath =
        [NSIndexPath indexPathForItem:0 inSection:sectionIndex];

    UICollectionReusableView *view =
        [self.collectionView supplementaryViewForElementKind:UICollectionElementKindSectionHeader
                                                 atIndexPath:indexPath];

    if (![view isKindOfClass:PPSectionHeaderView.class]) {
        return;
    }

    PPSectionHeaderView *header = (PPSectionHeaderView *)view;

    NSString *iconName = self.isMainKindsExpanded
        ? @"chevron.up"
        : @"chevron.down";

    [header configureWithTitle:kLang(@"MainCategories")
                      subtitle:nil
                   actionTitle:nil
                      iconName:iconName
                          menu:nil
                 ppHomeSection:PPHomeSectionMainKinds];
}

#pragma mark - Prefetching

- (NSArray<NSString *> *)pp_imageURLsFromIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    if (indexPaths.count == 0 || !self.dataSource) {
        return @[];
    }

    NSMutableOrderedSet<NSString *> *urls = [NSMutableOrderedSet orderedSet];
    for (NSIndexPath *indexPath in indexPaths) {
        PPHomeItem *item = [self.dataSource itemIdentifierForIndexPath:indexPath];
        NSString *url = item.universalViewModel.imageURL;
        if (url.length > 0) {
            [urls addObject:url];
        }
    }

    return urls.array;
}

- (void)pp_prefetchImagesAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    NSArray<NSString *> *urls = [self pp_imageURLsFromIndexPaths:indexPaths];
    if (urls.count == 0) {
        return;
    }

    [[PPImageLoaderManager shared] prefetchURLs:urls];
}

- (void)pp_prefetchTopImagesWithLimit:(NSInteger)limit
{
    if (limit <= 0 || !self.dataSource) {
        return;
    }

    NSDiffableDataSourceSnapshot<NSNumber *, PPHomeItem *> *snapshot =
    self.dataSource.snapshot;
    NSArray<NSNumber *> *sections = snapshot.sectionIdentifiers;
    if (sections.count == 0) {
        return;
    }

    NSMutableArray<NSIndexPath *> *indexPaths = [NSMutableArray array];
    NSInteger remaining = limit;

    for (NSInteger sectionIndex = 0;
         sectionIndex < (NSInteger)sections.count && remaining > 0;
         sectionIndex++) {
        NSArray<PPHomeItem *> *items =
        [snapshot itemIdentifiersInSectionWithIdentifier:sections[(NSUInteger)sectionIndex]];

        for (NSInteger itemIndex = 0;
             itemIndex < (NSInteger)items.count && remaining > 0;
             itemIndex++) {
            PPHomeItem *item = items[(NSUInteger)itemIndex];
            if (item.universalViewModel.imageURL.length == 0) {
                continue;
            }

            [indexPaths addObject:[NSIndexPath indexPathForItem:itemIndex
                                                       inSection:sectionIndex]];
            remaining--;
        }
    }

    [self pp_prefetchImagesAtIndexPaths:indexPaths];
}

- (void)collectionView:(UICollectionView *)collectionView
prefetchItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    (void)collectionView;
    [self pp_prefetchImagesAtIndexPaths:indexPaths];
}

- (void)collectionView:(UICollectionView *)collectionView
cancelPrefetchingForItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    (void)collectionView;
    if (indexPaths.count == 0) {
        return;
    }
    [[PPImageLoaderManager shared] cancelAllPrefetching];
}

- (void)pp_asyncBlurHashImageForHash:(NSString *)hash
                                size:(CGSize)size
                          completion:(void (^)(UIImage * _Nullable image))completion
{
    if (hash.length == 0) {
        if (completion) {
            completion(nil);
        }
        return;
    }

    UIImage *cached = [self.blurHashCache objectForKey:hash];
    if (cached) {
        if (completion) {
            completion(cached);
        }
        return;
    }

    dispatch_async(self.blurHashQueue, ^{
        UIImage *image = [PPBlurHashBridge imageFrom:hash
                                            syncSize:size
                                               punch:1.0];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (image) {
                [self.blurHashCache setObject:image forKey:hash];
            }
            if (completion) {
                completion(image);
            }
        });
    });
}


- (void)dealloc
{
    [[PPHomePromoCarouselManager sharedManager] stopListening];
    [self pp_stopCurrentOrdersListener];
    [self stopNearbyRefreshTimer];
    self.collectionView.prefetchDataSource = nil;
    [[PPImageLoaderManager shared] cancelAllPrefetching];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
- (NSArray<PPHomeItem *> *)identifiersForIndexPaths:(NSArray<NSIndexPath *> *)paths {
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:paths.count];

    for (NSIndexPath *path in paths) {
        PPHomeItem *item = [self.dataSource itemIdentifierForIndexPath:path];

        if (item) {
            [items addObject:item];
        }
    }

    return items;
}

- (void)openNearestVet {
    // push nearest vet map / list
    NSLog(@"PPHomeQuickActionNearestVet");
    PPVetLocator *vc = [PPVetLocator new];
    [PPFunc presentSheetFrom:self sheetVC:vc detentStyle:PPSheetDetentStyle70];
}

- (void)openAccessories {
    // push accessories listing
    NSLog(@"PPHomeQuickActionAccessories");
}

- (void)openFood {
    // push food listing
    NSLog(@"PPHomeQuickActionFood");
}

#pragma mark - UICollectionViewDelegate

// MARK: - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView
    didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    PPHomeSection section = [self sectionTypeForIndexPath:indexPath];
    if (section == PPHomeSectionHero) {
        [self openHomeLocationPicker];
        return;
    }

    NSLog(@"[Home][Tap] section=%ld item=%ld",
             (long)indexPath.section,
             (long)indexPath.item);
    
    
    PPHomeItem *item =
        [self.dataSource itemIdentifierForIndexPath:indexPath];

    if (!item) {
        return;
    }

    switch (section) {
        case PPHomeSectionServices: {
            NSLog(@"[Home][Tap][Services] tapped service=%@",
                  item.payload);
            PPHomeServiceItem *service =
                (PPHomeServiceItem *)item.payload;

            if (![service isKindOfClass:PPHomeServiceItem.class]) {
                return;
            }

            [self handleServiceSelection:service
                           fromIndexPath:indexPath];
            break;
        }

        case PPHomeSectionMainKinds: {
            if (![item.payload isKindOfClass:MainKindsModel.class]) {
                return;
            }

            MainKindsModel *kind = (MainKindsModel *)item.payload;
            BOOL isAll = (kind.ID == -1);

            NSLog(@"[Home][Tap][MainKinds] isAll=%@ payload=%@",
                  isAll ? @"YES" : @"NO",
                  item.payload);

            if (isAll) {
                // ✅ Route ALL to DataViewVC
                [self handleDeepLinkWithTarget:PPDeepLinkTargetAllCategories
                                      mainKind:nil
                                        source:PPInputSourceHomeMainKindsSection];
                return;
            }

 
            // ✅ Route specific kind
            [self handleMainKindSelection:kind];
            return;
            break;
        }

        case PPHomeSectionCurrentOrders: {
            if (![item.payload isKindOfClass:PPOrder.class]) {
                return;
            }
            [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
            [self pp_setCurrentOrdersExpanded:!self.isCurrentOrdersExpanded animated:YES];
            return;
        }
            
        case PPHomeSectionSuggestions: {
            PPUniversalCellViewModel *vm = item.universalViewModel;
            id model = vm.ModelObject;

            if (!model) return;

            // 🔥 Track browse history (important for "Because you viewed")
            if ([model isKindOfClass:PetAd.class]) {
                PetAd *ad = (PetAd *)model;

                [[PPBrowseHistoryManager shared]
                    trackItemWithType:PPBrowseItemTypeAd
                           mainKindID:ad.category];
            }
            else if ([model isKindOfClass:PetAccessory.class]) {
                PetAccessory *acc = (PetAccessory *)model;

                [[PPBrowseHistoryManager shared]
                    trackItemWithType:PPBrowseItemTypeAccessory
                           mainKindID:acc.petMainCategoryID];
            }

            // ✅ Open overlay (same UX as nearby / accessories)
            [self pp_openOverlayForObject:model];
            break;
        }
            
        case PPHomeSectionAccessories:
        case PPHomeSectionBuyAgain:
        case PPHomeSectionAdsNearBy: {
             PPUniversalCellViewModel *vm = item.universalViewModel;
            id model = vm.ModelObject;

            NSLog(@"[Home][Tap][ResolvedModel] %@",
                  NSStringFromClass([model class]));

            if (!model) return;

            [self pp_openOverlayForObject:model];
            break;
        }

        case PPHomeSectionAdopt: {
            NSLog(@"[Home][Tap][Adopt] Open BitsViewController");

            AdoptPetsViewController *vc = [[AdoptPetsViewController alloc] init];
            vc.pp_transitionStyle = PPTransitionStyleNone;

            PPNavigationController *nav =
                (PPNavigationController *)[PPHomeHelper currentNavigationControllerFor:self];
            if (!nav) return;

            [PPHomeHelper pushViewControllerSafely:vc from:self animated:YES];
            break;
        }
            
        default:
            break;
    }
}
 
#pragma mark - Overlay Routing (Home → OverlayCoordinator)

- (void)pp_openOverlayForObject:(id)object
{
    if ([object isKindOfClass:PetAd.class]) {
        PetAd *ad = object;
        [[PPBrowseHistoryManager shared]
            trackItemWithType:PPBrowseItemTypeAd
                   mainKindID:ad.category];
    }
    else if ([object isKindOfClass:PetAccessory.class]) {
        PetAccessory *acc = object;
        [[PPBrowseHistoryManager shared]
            trackItemWithType:PPBrowseItemTypeAccessory
                   mainKindID:acc.petMainCategoryID];
    }
    
    
    if (!object) return;
    UIViewController *sourceVC = self;
    [PPOverlayCoordinator pp_openDetailForObject:object
                                         fromVC:sourceVC
                                     routingNav:nil];
}


- (BOOL)isCategorySelected:(MainKindsModel *)kind
{
    if (!kind) {
        return self.selectedCategory == nil; // All
    }

    return self.selectedCategory &&
           kind.ID == self.selectedCategory.ID;
}
- (void)handleServiceSelection:(PPHomeServiceItem *)service
                 fromIndexPath:(NSIndexPath *)indexPath {
    switch (service.type) {
        case PPHomeServiceTypeVet:
            [self openNearestVet];
            break;

        case PPHomeServiceTypeGrooming:
            [self handleDeepLinkWithTarget:PPDeepLinkTargetGrooming
                                  mainKind:nil
                                    source:PPInputSourceHomeServicesSection];
            break;

        case PPHomeServiceTypeTraining:
            [self handleDeepLinkWithTarget:PPDeepLinkTargetTraning
                                  mainKind:nil
                                    source:PPInputSourceHomeServicesSection];
            break;

        case PPHomeServiceTypeFood:
            [self handleDeepLinkWithTarget:PPDeepLinkTargetFood
                                  mainKind:nil
                                    source:PPInputSourceHomeServicesSection];
            break;
    }
}

- (CGFloat)currentYOffsetForSection:(PPHomeSection)section {
    NSIndexPath *headerIndexPath = [NSIndexPath indexPathForItem:0 inSection:section];

    UICollectionViewLayoutAttributes *attrs =
        [self.collectionView layoutAttributesForSupplementaryElementOfKind:@"PPHomeSectionHeaderKind"
                                                               atIndexPath:headerIndexPath];

    if (!attrs) {
        return self.collectionView.contentOffset.y;
    }

    return attrs.frame.origin.y - self.collectionView.contentOffset.y;
}

#pragma mark - View Data Routing (PPDataViewVC)

// MainKinds now open unified PPDataViewVC
- (void)handleMainKindSelection:(MainKindsModel *)kind {
    if (!kind) {
        return;
    }

    // Build input object for PPDataViewVC
    PPDataViewInput *input = [PPDataViewInput inputWithMainKind:kind sourceTarget:PPDeepLinkTargetAds source:PPInputSourceHomeMainKindsSection];
    PPDataViewVC *vc =  [[PPDataViewVC alloc] initWithInput:input];
    vc.pp_transitionStyle = PPTransitionStyleNone;
    if (![PPHomeHelper pushViewControllerSafely:vc from:self animated:YES]) {
        return;
    }
}

- (void)handleDeepLinkWithTarget:(PPDeepLinkTarget)target
                        mainKind:(MainKindsModel *)mainKind
                          source:(PPInputSource)source
{
    NSLog(@"[MainKindsModel] handleDeepLinkWithTarget resolvedKind %@",
          mainKind ? mainKind.KindName : @"(nil)");
    UINavigationController *nav = [PPHomeHelper currentNavigationControllerFor:self];

    if (!nav) {
        NSLog(@"[DeepLink] ❌ No navigation controller available");
        return;
    }

    UIViewController *vc;

    switch (target) {
        case PPDeepLinkTargetAllCategories: {
            NSLog(@"[DeepLink] Building ALL MainKinds DataViewVC");

            PPDataViewInput *input =
                [PPDataViewInput inputWithMainKindsArr:self.mainKinds
                                          sourceTarget:PPDeepLinkTargetAllCategories
                                                source:source];

            PPDataViewVC *allVC =
                [[PPDataViewVC alloc] initWithInput:input];

            allVC.pp_transitionStyle = PPTransitionStyleNone;
            [PPHomeHelper pushViewControllerSafely:allVC from:self animated:YES];
            return;
        }
        case PPDeepLinkTargetAccessories:
        case PPDeepLinkTargetFood:
        case PPDeepLinkTargetServices:
        case PPDeepLinkTargetGrooming:
        case PPDeepLinkTargetTraning:
        case PPDeepLinkTargetNewByAds:
        case PPDeepLinkTargetAds:{
            vc = [self buildDataViewVCForTarget:target
                                       mainKind:mainKind
                                         source:source];

            if (!vc) {
                NSLog(@"[DeepLink] ❌ Failed to build destination VC"); return;
            }

            break;
        }

        default:{
            vc = [self buildDataViewVCForTarget:target mainKind:mainKind source:source];

            if (!vc) {
                NSLog(@"[DeepLink] ❌ Failed to build destination VC"); return;
            }
        }

        break;
    }
    // =========================
    // Navigate Safely
    // =========================

    [PPHomeHelper pushViewControllerSafely:vc from:self animated:YES];
}

// Unified builder for PPDataViewVC for deep-link targets
- (PPDataViewVC *)buildDataViewVCForTarget:(PPDeepLinkTarget)target
                                  mainKind:(MainKindsModel *_Nullable)mainKind
                                    source:(PPInputSource)source
{
    PPDataViewInput *input;
    if (mainKind) {
        input = [PPDataViewInput inputWithMainKind:mainKind
                                      sourceTarget:target
                                            source:source];
    } else {
        input = [PPDataViewInput inputWithMainKind:nil
                                      sourceTarget:target
                                            source:source];
    }

    if (!input) {
        return nil;
    }

    // Create unified data viewer
    PPDataViewVC *vc =
        [[PPDataViewVC alloc] initWithInput:input];

    vc.pp_transitionStyle = PPTransitionStyleNone;
    return vc;
}

- (BOOL)deepLinkTargetRequiresMainKind:(PPDeepLinkTarget)target {
    switch (target) {
        case PPDeepLinkTargetAds:
        case PPDeepLinkTargetAccessories:
        case PPDeepLinkTargetFood:
        case PPDeepLinkTargetServices:
            return YES;    // Global listings

        default:
            return NO;
    }
}

- (MainKindsModel *)resolveMainKindWithID:(NSInteger)mainKindID {
    for (MainKindsModel *kind in self.mainKinds) {
        if (kind.ID == mainKindID) {
            return kind;
        }
    }

    return nil;
}

- (NSString *)heroBaseGreetingText
{
    NSInteger hour = [[NSCalendar currentCalendar] component:NSCalendarUnitHour fromDate:NSDate.date];

    if (hour < 5 || hour >= 22) {   // ✅ after 20:00 => Good night
        return kLang(@"Good evening") ?: @"Good evening";
    }
    if (hour < 12) return kLang(@"Good morning") ?: @"Good morning";
    if (hour < 17) return kLang(@"Good afternoon") ?: @"Good afternoon";
    return kLang(@"Good evening") ?: @"Good evening";
}

- (NSString *)heroDisplayNameText
{
    if (!PPIsUserLoggedIn) {
        return @"";
    }

    id resolvedUser = PPCurrentUser ?: UserManager.sharedManager.currentUser;
    if (!resolvedUser) {
        return @"";
    }

    NSString *bestName = PPSafeString([resolvedUser valueForKey:@"PPBestDisplayName"]);
    if (bestName.length > 0) {
        return bestName;
    }

    NSString *username = PPSafeString([resolvedUser valueForKey:@"UserName"]);
    return username.length > 0 ? username : @"";
}

- (NSString *)heroCountryText
{
    switch (self.nearbyLocationState) {
        case PPNearbyLocationStateLoading:
            return kLang(@"Loading...") ?: @"Loading...";
        case PPNearbyLocationStateDenied:
            return kLang(@"Location permission denied") ?: @"Location permission denied";
        case PPNearbyLocationStateReady:
            if (self.selectedNearbyAreaName.length > 0) {
                return self.selectedNearbyAreaName;
            }
            return kLang(@"Select your location") ?: @"Select your location";
        case PPNearbyLocationStateUnset:
        default:
            return kLang(@"Select your location") ?: @"Select your location";
    }
}

- (NSString *)heroLocationActionTitle
{
    switch (self.nearbyLocationState) {
        case PPNearbyLocationStateDenied:
            return kLang(@"Open Settings") ?: @"Open Settings";
        case PPNearbyLocationStateReady:
            return kLang(@"Hero_ChangeArea") ?: @"Change area";
        case PPNearbyLocationStateUnset:
            return kLang(@"Hero_LocationCTA") ?: @"Choose area";
        case PPNearbyLocationStateLoading:
        default:
            return nil;
    }
}

- (NSString *)pp_sanitizedHeroLine:(NSString *)line
{
    NSString *safe = PPSafeString(line);
    safe = [safe stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    safe = [safe stringByReplacingOccurrencesOfString:@"\r" withString:@" "];
    return [safe stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)heroGreetingText
{
    BOOL rtl = Language.isRTL;
    NSString *line1 = [self pp_sanitizedHeroLine:[self heroBaseGreetingText]];
    if (line1.length == 0) {
        line1 = kLang(@"Hello") ?: @"Hello";
    }

    if (PPIsUserLoggedIn) {
        NSString *name = [self pp_sanitizedHeroLine:[self heroDisplayNameText]];
        if (name.length == 0) {
            name = [self pp_sanitizedHeroLine:PPSafeString(PPCurrentUser.UserName)];
        }
        if (name.length > 0) {
            NSString *howAreYou = [self pp_sanitizedHeroLine:(kLang(@"How are you") ?: @"How are you")];
            NSString *separator = rtl ? @"، " : @", ";
            NSString *line2 = [NSString stringWithFormat:@"%@%@%@", howAreYou, separator, name];
            return [NSString stringWithFormat:@"%@\n%@", line1, line2];
        }
    }

    NSString *line2 = [self pp_sanitizedHeroLine:(kLang(@"join our pets lover community") ?: @"join our pets lover community")];
    return [NSString stringWithFormat:@"%@\n%@", line1, line2];
}

- (void)openAdoption {
    AdoptPetsViewController *vc = [[AdoptPetsViewController alloc] init];

    vc.pp_transitionStyle = PPTransitionStyleNone;
}

 


- (void)setProfileCard
{
    UIImage *profileAvatar = [UIImage systemImageNamed:@"person.crop.circle.fill"];
    NSString *title = [UsrMgr profileNameAndTitleWithMode:ProfileGreetingShorteningModeShotNameOnly] ? : @"";
    NSString *subtitle = Language.isRTL ? CitiesManager.shared.CurrentCountry.arName : CitiesManager.shared.CurrentCountry.enName ? : @"";
    UIButton *profile = (UIButton *)[self pp_profileViewWithImage:profileAvatar
                                              title:title
                                           subtitle:subtitle
                                          userModel:PPCurrentUser
                                             target:self
                                             action:@selector(profileTapped:)];

    if (@available(iOS 26.0, *)) {
        profile.configuration = [UIButtonConfiguration glassButtonConfiguration];
    } else {
        profile.configuration = nil;
        profile.layer.cornerRadius = 22;
        profile.clipsToBounds = YES;
    }
     
    self.profileCard =
        [self pp_wrappedNavigationTitleView:profile];
    self.profileCard.translatesAutoresizingMaskIntoConstraints = NO;
   // [self.view addSubview:self.profileCard];
}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
   
    [self configureNavigationBar];
    [self updateCartQuantityBadge];
    if (self.accessoriesLoaded || self.nearbyLoaded) {
        [self reloadSection:PPHomeSectionSuggestions];
    }
    [self refreshCurrentOrdersForce:NO];
    [self refreshHeroSectionAppearance];
    
    PPNavigationController *nav = (PPNavigationController *)self.navigationController;
    if (nav) {
        UIGestureRecognizer *pop = nav.interactivePopGestureRecognizer;

        pop.delegate = nil;   // 🔥 reset UIKit state
        pop.enabled = YES;
        pop.delegate = self;
    }
    
    if (!self.didAutoScrollSuggestions) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.didAutoScrollSuggestions = YES;
        });
    }

    self.navigationItem.titleView = nil;
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    self.isHomeScreenVisible = NO;
    self.lastObservedHomeOrderID = nil;
    self.lastObservedHomeOrderStatusKey = nil;
    [self pp_stopCurrentOrdersListener];
    [self stopNearbyRefreshTimer];
}

// Show bottom card with haptic feedback
- (void)showBottomCard:(UIView *)card
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self showBottomCard:card]; });
        return;
    }
    // Hardware haptic feedback
    UIImpactFeedbackGenerator *gen =
        [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleSoft];
    [gen prepare];
    [gen impactOccurred];

    card.hidden = NO;
    card.transform = CGAffineTransformMakeTranslation(0, 40);
    card.alpha = 0.0;

    [UIView animateWithDuration:0.45
                          delay:0
         usingSpringWithDamping:0.85
          initialSpringVelocity:0.6
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        card.transform = CGAffineTransformIdentity;
        card.alpha = 1.0;
    } completion:nil];
}


// Hide bottom card with haptic feedback
- (void)hideBottomCard:(UIView *)card
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self hideBottomCard:card]; });
        return;
    }
    // Hardware haptic feedback
    UIImpactFeedbackGenerator *gen =
        [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [gen prepare];
    [gen impactOccurred];

    [UIView animateWithDuration:0.25
                          delay:0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        card.transform = CGAffineTransformMakeTranslation(0, 30);
        card.alpha = 0.0;
    } completion:^(BOOL finished) {
        card.hidden = YES;
        card.transform = CGAffineTransformIdentity;
    }];
}

- (void)cartClick
{
    NSLog(@"[Cart] Tap");

    if (!PPIsUserLoggedIn) { [UserManager showPromptOnTopController]; return; }

    CartViewController *vc = [[CartViewController alloc] init];
    vc.pp_transitionStyle = PPTransitionStyleFade;

    // Embed in nav
    PPNavigationController *nav =
        [[PPNavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;

    // ✅ PRESENT THE NAV — NOT vc
    [PPHomeHelper presentViewControllerSafely:nav
                                         from:self
                                     animated:YES
                                   completion:nil];
}

- (void)configureNavigationBar {
     self.navigationItem.title = nil;
    self.navigationItem.titleView = nil;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

 
    UIImage *baseImage =
        [UIImage pp_symbolNamed:@"list.bullet"
                      pointSize:17
                         weight:UIImageSymbolWeightSemibold
                          scale:UIImageSymbolScaleLarge
                        palette:@[UIColor.grayColor, AppPrimaryTextClr ?: UIColor.systemTealColor]
                   makeTemplate:NO];

    UIImage *cartImage =
        [UIImage pp_symbolNamed:@"cart"
                      pointSize:17
                         weight:UIImageSymbolWeightSemibold
                          scale:UIImageSymbolScaleLarge
                        palette:@[UIColor.grayColor, AppPrimaryTextClr ?: UIColor.systemTealColor]
                   makeTemplate:NO];

    UIBarButtonItem *profileItem = [self pp_buildProfileBarButtonItem];

    UIBarButtonItem *cartItem =
        [[UIBarButtonItem alloc] initWithImage:cartImage
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(cartClick)];

    self.homeOptionsItem =
        [[UIBarButtonItem alloc] initWithImage:baseImage
                                          menu:[PPActionButton appActionsArrayfor:self]];

    self.homeCartItem = cartItem;


        self.navigationItem.leftBarButtonItems = @[profileItem];
        self.navigationItem.rightBarButtonItems = @[self.homeOptionsItem,self.homeCartItem];
   
    // 🔔 Notify cart change (already your system)
    [[NSNotificationCenter defaultCenter]
        postNotificationName:kCartUpdatedNotification
                      object:nil];
}


- (void)pp_showCartBarButtonAnimated
{
    if ([self.navigationItem.rightBarButtonItems containsObject:self.homeCartItem]) {
        return; // already visible
    }

    NSMutableArray *items = [NSMutableArray array];
    [items addObject:self.homeOptionsItem];
    [items addObject:self.homeCartItem];

    [UIView transitionWithView:self.navigationController.navigationBar
                      duration:0.25
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        self.navigationItem.rightBarButtonItems = items;
    } completion:nil];
}

- (void)pp_hideCartBarButtonAnimated
{
    if (![self.navigationItem.rightBarButtonItems containsObject:self.homeCartItem]) {
        return; // already hidden
    }

    NSMutableArray *items = [NSMutableArray array];
    [items addObject:self.homeOptionsItem];

    [UIView transitionWithView:self.navigationController.navigationBar
                      duration:0.20
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        self.navigationItem.rightBarButtonItems = items;
    } completion:nil];
}

- (UIBarButtonItem *)pp_buildProfileBarButtonItem
{
    static const CGFloat kSize = 36.0;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(0, 0, kSize, kSize);
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.contentEdgeInsets = UIEdgeInsetsZero;
    button.backgroundColor = UIColor.clearColor;
    button.clipsToBounds = YES;
    button.layer.cornerRadius = kSize * 0.5;
    button.adjustsImageWhenHighlighted = NO;
    button.accessibilityLabel = kLang(@"Profile") ?: @"Profile";

    [NSLayoutConstraint activateConstraints:@[
        [button.widthAnchor constraintEqualToConstant:kSize],
        [button.heightAnchor constraintEqualToConstant:kSize]
    ]];

    UIImageView *avatar = [[UIImageView alloc] init];
    avatar.translatesAutoresizingMaskIntoConstraints = NO;
    avatar.contentMode = UIViewContentModeScaleAspectFill;
    avatar.clipsToBounds = YES;
    avatar.layer.cornerRadius = kSize * 0.5;
    avatar.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    [button addSubview:avatar];
    [NSLayoutConstraint activateConstraints:@[
        [avatar.topAnchor constraintEqualToAnchor:button.topAnchor],
        [avatar.leadingAnchor constraintEqualToAnchor:button.leadingAnchor],
        [avatar.trailingAnchor constraintEqualToAnchor:button.trailingAnchor],
        [avatar.bottomAnchor constraintEqualToAnchor:button.bottomAnchor]
    ]];

    // Placeholder
    UIImage *placeholder = [UIImage imageNamed:@"man"];
    UIImage *fallback =
        [UIImage pp_symbolNamed:@"person.crop.circle.fill"
                      pointSize:22
                         weight:UIImageSymbolWeightSemibold
                          scale:UIImageSymbolScaleMedium
                        palette:@[AppPrimaryClr ?: UIColor.systemTealColor]
                   makeTemplate:YES];

    avatar.image = placeholder ?: fallback;
    avatar.tintColor = placeholder ? nil : (AppPrimaryClr ?: UIColor.systemTealColor);
    avatar.contentMode = placeholder ? UIViewContentModeScaleAspectFill : UIViewContentModeCenter;

    // Remote image
    NSString *url = PPSafeString(PPCurrentUser.UserImageUrl.absoluteString);
    if (url.length > 0) {
        [GM setImageFromUrlString:url
                        imageView:avatar
                          phImage:@"man"
                       completion:^(UIImage * _Nullable image,
                                    NSError * _Nullable error)
        {
            if (!image || error) {
                avatar.image = placeholder ?: fallback;
                avatar.tintColor = placeholder ? nil : (AppPrimaryClr ?: UIColor.systemTealColor);
                avatar.contentMode = placeholder ? UIViewContentModeScaleAspectFill
                                                 : UIViewContentModeCenter;
                return;
            }
            avatar.image = image;
            avatar.tintColor = nil;
            avatar.contentMode = UIViewContentModeScaleAspectFill;
        }];
    }

    if (@available(iOS 14.0, *)) {
        button.menu = [PPActionButton userActionsArrayfor:self];
        button.showsMenuAsPrimaryAction = YES;
    }

    return [[UIBarButtonItem alloc] initWithCustomView:button];
}


- (void)refreshNavigationRightItemsForCartCount:(NSUInteger)count
{
   
    NSMutableArray<UIBarButtonItem *> *items = [NSMutableArray array];
    [items addObject:self.homeOptionsItem];
    if (count > 0) {
        if (!self.homeCartItem) {
            UIImage *cartImage = [UIImage pp_symbolNamed:@"cart"
                                                pointSize:16
                                                   weight:UIImageSymbolWeightBold
                                                    scale:UIImageSymbolScaleLarge
                                                  palette:@[UIColor.grayColor, AppPrimaryClr]
                                             makeTemplate:NO];
            self.homeCartItem =
                [[UIBarButtonItem alloc] initWithImage:cartImage
                                                 style:UIBarButtonItemStylePlain
                                                target:self
                                                action:@selector(cartClick)];
        }
        [items addObject:self.homeCartItem];
    }

    
    self.navigationItem.rightBarButtonItems = items.copy;
}
 
#pragma mark - Navigation Logo Title View

- (UIView *)pp_logoTitleView
{
    UIImage *logo = [UIImage imageNamed:@"newlogo"]; // 🔁 change name if needed
    if (!logo) return nil;

    UIImageView *logoView = [[UIImageView alloc] initWithImage:logo];
    logoView.translatesAutoresizingMaskIntoConstraints = NO;
    logoView.contentMode = UIViewContentModeScaleToFill;

    // Prevent compression / jumping
    [logoView setContentHuggingPriority:UILayoutPriorityRequired
                                forAxis:UILayoutConstraintAxisHorizontal];
    [logoView setContentCompressionResistancePriority:UILayoutPriorityRequired
                                              forAxis:UILayoutConstraintAxisHorizontal];

    // Wrap using YOUR helper (important)
    UIView *wrapped = [self pp_wrappedNavigationTitleView:logoView];

    // Explicit size so UIKit never guesses
    CGFloat height =  46.0;

    [NSLayoutConstraint activateConstraints:@[
        [logoView.heightAnchor constraintEqualToConstant:height],
        [logoView.centerXAnchor constraintEqualToAnchor:wrapped.centerXAnchor],
        [logoView.centerYAnchor constraintEqualToAnchor:wrapped.centerYAnchor],
        [logoView.widthAnchor constraintEqualToConstant:height],

    ]];
    
    [NSLayoutConstraint activateConstraints:@[
        [wrapped.heightAnchor constraintEqualToConstant:height],
        [wrapped.widthAnchor constraintEqualToConstant:height],

    ]];

    return wrapped;
}

- (UIView *)pp_wrappedNavigationTitleView:(UIView *)content
{
    CGFloat navHeight = 36.0;
    
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.hx_w - 32, navHeight)];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = UIColor.clearColor;

    content.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:content];

    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [content.topAnchor constraintEqualToAnchor:container.topAnchor],
        [content.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];

    return container;
}

#pragma mark - Top/Nav UI
- (void)profileTapped:(UIButton *)sender {
    // Menu is already presented via `showsMenuAsPrimaryAction`.
    // Keep this as a safe no-op fallback.
    (void)sender;
}

- (void)presentMenu:(UIMenu *)menu fromView:(UIView *)sourceView {
    (void)menu;
    (void)sourceView;
}

- (MainBannerModel *)pp_homeTopCarouselBannerGroup
{
    NSArray<MainBannerModel *> *candidates =
    [PPBannersManager.sharedManager.bannerGroups filteredArrayUsingPredicate:
     [NSPredicate predicateWithBlock:^BOOL (MainBannerModel *g, NSDictionary *_) {
        return (g.bannerViewHolder == PPBannerHolderMainView &&
                g.bannerViewPosition == PPBannerPositionTop &&
                g.bannerViewVisible);
    }]];

    if (candidates.count == 0) return nil;

    for (MainBannerModel *group in candidates) {
        if ([PPSafeString(group.bannerViewID) caseInsensitiveCompare:PPHomeTopCarouselBannerGroupID] == NSOrderedSame) {
            return group;
        }
    }

    NSArray<MainBannerModel *> *sorted =
    [candidates sortedArrayUsingComparator:^NSComparisonResult(MainBannerModel *a, MainBannerModel *b) {
        return [PPSafeString(a.bannerViewID) localizedCaseInsensitiveCompare:PPSafeString(b.bannerViewID)];
    }];
    return sorted.firstObject;
}



- (void)fillCarouselBanner
{
    NSDiffableDataSourceSnapshot *snapshot = self.dataSource.snapshot;

    NSArray *items =
        [snapshot itemIdentifiersInSectionWithIdentifier:@(PPHomeSectionCarousel)];
    if (items.count == 0) return;

    PPHomeItem *item = items.firstObject;

    NSArray<PPHomePromoCarouselCard *> *promoCards = self.promoCarouselCards;
    if (promoCards.count > 0) {
        item.payload = promoCards;
        [snapshot reloadItemsWithIdentifiers:@[item]];
        [self.dataSource applySnapshot:snapshot animatingDifferences:NO];
        return;
    }

    MainBannerModel *homeTop = [self pp_homeTopCarouselBannerGroup];

    NSArray<PPHomePromoCarouselCard *> *legacyPromoCards = [self pp_promoCardsFromLegacyBannerGroup:homeTop];
    if (legacyPromoCards.count > 0) {
        item.payload = legacyPromoCards;
        [snapshot reloadItemsWithIdentifiers:@[item]];
        [self.dataSource applySnapshot:snapshot animatingDifferences:NO];
        return;
    }

    if (!homeTop || homeTop.childBanners.count == 0) {
        NSArray<PPHomePromoCarouselCard *> *fallbackCards = [self pp_homePromoFallbackCards];
        if (fallbackCards.count > 0) {
            item.payload = fallbackCards;
            [snapshot reloadItemsWithIdentifiers:@[item]];
            [self.dataSource applySnapshot:snapshot animatingDifferences:NO];
            return;
        }
        item.payload = [NSNull null];
        [snapshot reloadItemsWithIdentifiers:@[item]];
        [self.dataSource applySnapshot:snapshot animatingDifferences:NO];
        return;
    }

    item.payload = homeTop;

    [snapshot reloadItemsWithIdentifiers:@[item]];
    [self.dataSource applySnapshot:snapshot animatingDifferences:NO];
}


- (UIView *)pp_profileViewWithImage:(UIImage *_Nullable)image
                              title:(NSString *_Nullable)title
                           subtitle:(NSString *_Nullable)subtitle
                          userModel:(UserModel *_Nullable)usr
                             target:(id _Nullable)target
                             action:(SEL _Nullable)action
{
    static const CGFloat kAvatarSize = 36.0;
    static const CGFloat kMinHeight  = 46.0;

    // =====================================================
    // 1️⃣ Container (UIButton – nav-safe)
    // =====================================================
    PPHomeProfileView *container =
        [PPHomeProfileView buttonWithType:UIButtonTypeCustom];
    if (@available(iOS 26.0, *)) {
        container.configuration = [UIButtonConfiguration glassButtonConfiguration];
    } else {
        container.configuration = nil;
    }
     
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.adjustsImageWhenHighlighted = NO;
    container.clipsToBounds = NO;

    container.semanticContentAttribute =
        Language.isRTL
        ? UISemanticContentAttributeForceRightToLeft
        : UISemanticContentAttributeForceLeftToRight;

    // Menu + tap safely coexist
    container.menu = [PPActionButton userActionsArrayfor:self];
    container.showsMenuAsPrimaryAction = YES;

    if (target && action) {
        [container addTarget:target
                      action:action
            forControlEvents:UIControlEventTouchUpInside];
    }

    // Hard height for navigation bar stability
    [container.heightAnchor constraintGreaterThanOrEqualToConstant:kMinHeight].active = YES;

    // =====================================================
    // 2️⃣ Avatar
    // =====================================================
    UIImageView *avatar = [[UIImageView alloc] init];
    avatar.translatesAutoresizingMaskIntoConstraints = NO;
    avatar.contentMode = UIViewContentModeScaleAspectFill;
    avatar.layer.cornerRadius = kAvatarSize / 2.0;
    avatar.layer.masksToBounds = YES;
    avatar.tintColor = AppPrimaryTextClr;
    avatar.image = image ?: [UIImage systemImageNamed:@"person.crop.circle.fill"];

    [NSLayoutConstraint activateConstraints:@[
        [avatar.widthAnchor constraintEqualToConstant:kAvatarSize],
        [avatar.heightAnchor constraintEqualToConstant:kAvatarSize]
    ]];

    if (usr) {
        [GM setImageFromUrlString:PPSafeString(usr.UserImageUrl.absoluteString)
                        imageView:avatar
                          phImage:@"person.crop.circle.fill"];
    }

    // =====================================================
    // 3️⃣ Title
    // =====================================================
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:16];
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.text = title ?: kLang(@"JoinUs");
    titleLabel.numberOfLines = 1;
    titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    // =====================================================
    // 4️⃣ Subtitle (icon + text, baseline safe)
    // =====================================================
    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM fontWithSize:12];
    subtitleLabel.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    subtitleLabel.numberOfLines = 1;
    subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    if (subtitle.length > 0) {
        UIImageSymbolConfiguration *cfg =
            [UIImageSymbolConfiguration configurationWithPointSize:11
                                                            weight:UIImageSymbolWeightRegular];

        NSTextAttachment *att = [[NSTextAttachment alloc] init];
        att.image = [UIImage systemImageNamed:@"location.fill"
                             withConfiguration:cfg];
        att.bounds = CGRectMake(0, -1.5, 12, 12);

        NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] init];
        [attr appendAttributedString:[NSAttributedString attributedStringWithAttachment:att]];
        [attr appendAttributedString:[[NSAttributedString alloc] initWithString:@" "]];
        [attr appendAttributedString:[[NSAttributedString alloc] initWithString:subtitle]];

        subtitleLabel.attributedText = attr;
    }

    // =====================================================
    // 5️⃣ Text stack
    // =====================================================
    UIStackView *textStack =
        [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, subtitleLabel]];

    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = 0;
    textStack.alignment = UIStackViewAlignmentLeading;

    [titleLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                forAxis:UILayoutConstraintAxisHorizontal];
    [subtitleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                   forAxis:UILayoutConstraintAxisHorizontal];

    // =====================================================
    // 6️⃣ Horizontal layout
    // =====================================================
    UIStackView *contentStack =
        [[UIStackView alloc] initWithArrangedSubviews:@[avatar, textStack]];

    contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    contentStack.axis = UILayoutConstraintAxisHorizontal;
    contentStack.spacing = 10;
    contentStack.alignment = UIStackViewAlignmentCenter;

    [container addSubview:contentStack];

    [NSLayoutConstraint activateConstraints:@[
        [contentStack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:6],
        [contentStack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor  constant:-16],
        [contentStack.topAnchor constraintEqualToAnchor:container.topAnchor],
        [contentStack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];

    // =====================================================
    // 7️⃣ Touch feedback (safe)
    // =====================================================
    [container addTarget:container
                  action:@selector(pp_highlightDown)
        forControlEvents:UIControlEventTouchDown];

    [container addTarget:container
                  action:@selector(pp_highlightUp)
        forControlEvents:UIControlEventTouchUpInside |
                        UIControlEventTouchCancel |
                        UIControlEventTouchDragExit];

    return container;
}

 


#pragma mark - Swipe Back Gesture

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer ==
        self.navigationController.interactivePopGestureRecognizer) {

        // Disable on root VC only
        return self.navigationController.viewControllers.count > 1;
    }
    return YES;
}


-(void)PPUniversalCell_changeQuantity:(PPUniversalCellViewModel *)universalModel quantity:(NSInteger)quantity
{
   
    
    if (![universalModel.ModelObject isKindOfClass:[PetAccessory class]]) {
        NSLog(@"[Home][Cart] Ignored quantity change for non-accessory model");
        return;
    }
    PetAccessory *access = (PetAccessory *)universalModel.ModelObject;
    NSInteger maxStock = MAX(access.quantity, 0);
    NSInteger safeQuantity = MAX(0, quantity);

    if (maxStock <= 0 && safeQuantity > 0) {
        [PPHUD showError:kLang(@"Out of stock")];
        safeQuantity = 0;
    } else if (safeQuantity > maxStock) {
        safeQuantity = maxStock;
        [PPHUD showInfo:[NSString stringWithFormat:@"%@ %ld %@",
                         kLang(@"Only"),
                         (long)maxStock,
                         kLang(@"left in stock")]];
    }
    
         if (safeQuantity == 0) {
            [[CartManager sharedManager] removeItemForAccessory:access];
        } else {
            CartManager *cart = [CartManager sharedManager];
            CartItem *existing = [cart getCartItemForItemID:access.accessoryID];
            CartItem *item = [[CartItem alloc] initWithAccessory:access quantity:safeQuantity];
            if (existing) {
                [cart updateQuantity:safeQuantity forItem:item completion:nil];
            } else {
                BOOL didAdd = [cart addItem:item];
                if (!didAdd) {
                    [PPHUD showError:kLang(@"Out of stock")];
                }
            }
        }
        
    NSLog(@"[Quantity] Quantity %ld", (long)safeQuantity);

        // ✅ NOTIFY controllers to update badge
        [[NSNotificationCenter defaultCenter]
            postNotificationName:kCartUpdatedNotification
                          object:nil];
    
}


- (void)updateCartQuantityBadge
{
     
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateCartQuantityBadge];
        });
        return;
    }

    NSUInteger count = CartManager.sharedManager.cartItems.count;
    [self refreshNavigationRightItemsForCartCount:count];

    if (@available(iOS 26.0, *)) {
        UIBarButtonItemBadge *badge =
            count > 0 ? [UIBarButtonItemBadge badgeWithCount:count] : nil;
        badge.font = [GM MidFontWithSize:12];
        [self.homeCartItem setBadge:badge];
    } else {
        [self.homeCartItem pp_setBadgeValue:
            count > 0 ? [NSString stringWithFormat:@"%lu",(unsigned long)count] : nil];
    }
    
    // Animated show / hide
    if (count > 0) {
       //+ ** [self pp_showCartBarButtonAnimated];
    } else {
       // [self pp_hideCartBarButtonAnimated];
    }
    [self pp_showCartBarButtonAnimated];
    NSLog(@"[CartBadge] Updated count=%lu", (unsigned long)count);
}


-(void)PPUniversalCell_tapShare:(PPUniversalCellViewModel *)universalModel
{
    if (!PPIsUserLoggedIn) { [UserManager showPromptOnTopController]; return; }
    if (![universalModel.ModelObject isKindOfClass:[PetAd class]]) {
        NSLog(@"[Home][Share] Ignored share for unsupported model class");
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [PPAdSharingHelper sharePetAd:(PetAd *)universalModel.ModelObject fromViewController:self];
    });
}

-(void)PPUniversalCell_tapEdit:(PPUniversalCellViewModel *)universalModel
{
    
    NSLog(@"[AdsVC] PPUniversalCell_tapEdit");
    
    if(universalModel.cellSection == CellSectionAds && [universalModel.ModelObject isKindOfClass:[PetAd class]])
    {
        AddNewAd *vc = (AddNewAd *)[AddNewAd new];
        vc.mode = AdEditorModeEdit;
        vc.editingAd = (PetAd *)universalModel.ModelObject;                 // the existing PetAd you want to edit
        //vc.delegate = self;                // optional to get callbacks
         [PPHomeHelper pushViewControllerSafely:vc from:self animated:YES];
    }
    else  if(universalModel.cellSection == CellSectionAccessories && [universalModel.ModelObject isKindOfClass:[PetAccessory class]])
    {
        // Edit
        AddNewAccessory *editVC = [AddNewAccessory new];
        editVC.editingAccessory = (PetAccessory *)universalModel.ModelObject;   ;   // prefill from this model
        editVC.onFinish = ^(PetAccessory *result, BOOL isEdit) {
            // refresh list, etc.
            [AppClasses reloadThisCollectionView:self.collectionView completion:^(BOOL finished) { }];
            
        };
        [PPHomeHelper pushViewControllerSafely:editVC from:self animated:YES];
    }
}

-(void)PPUniversalCell_tapDelete:(PPUniversalCellViewModel *)universalModel
{
    if (!PPIsUserLoggedIn) { [UserManager showPromptOnTopController]; return; }
    NSLog(@"[AdsVC] PPUniversalCell_tapDelete");
    if(universalModel.cellSection == CellSectionAds && [universalModel.ModelObject isKindOfClass:[PetAd class]])
    {
        [GM showDeleteConfirmationFrom:self
                                 title:kLang(@"Confirm Deletion")
                               message:kLang(@"Are you sure you want to delete this item?")
                            completion:^(BOOL confirmed) {
            if (confirmed) {
                // Perform delete action
                [PetAdManager.sharedManager deletePetAd:(PetAd *)universalModel.ModelObject completion:^(NSError * _Nonnull error) {
                    [AppClasses reloadThisCollectionView:self.collectionView completion:^(BOOL finished) { }];
                }];
            }
        }];
    }
    
    
}



@end
