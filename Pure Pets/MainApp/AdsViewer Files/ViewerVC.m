//  ViewerVC.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/05/2025.
//

#import "ViewerVC.h"
#import "PPAdSharingHelper.h"
#import "PPInfoPillsView.h"
#import "PPSimilarAdsView.h"
#import "PPOverlayCoordinator.h"
#import "PPUserSigningManager.h"
#import "PPAnalytics.h"
#import "UIViewController+PPNavBar.h"
#import "PPCommerceFeedbackManager.h"

// 0.70 means the expanded meta sheet occupies 70% of the screen height.
static const CGFloat kViewerVcMetaSheetHeight = 0.85;
static const CGFloat kViewerVcTitleCardMinHeight = 116.0;

@interface ViewerVC()<UIGestureRecognizerDelegate,UIScrollViewDelegate>
@property (nonatomic, strong) CAGradientLayer *contactGradientLayer;
@property (nonatomic, strong) CAGradientLayer *galleryScrimLayer;
@property (nonatomic, strong) CAGradientLayer *contentSurfaceGradientLayer;
@property (nonatomic, strong) CAGradientLayer *descriptionSurfaceGradientLayer;
@property (nonatomic, strong) UIView *ambientGlowTopView;
@property (nonatomic, strong) UIView *ambientGlowBottomView;
@property BOOL isAdFavoritedLoaded;
@property BOOL isUserContactViewUpdated;

@property PetImageGalleryView *imageGallery;
@property UserModel *ownerModel;
@property PPSimilarAdsView *similarAdsView;
@property PPSimilarAdsView *similarAccessView;
@property (nonatomic, assign) BOOL didAnimate;
@property (nonatomic, strong) UIScrollView *contentScrollView;
@property (nonatomic, strong) UIView *contentContainer;
@property (nonatomic, strong) UIView *heroContainerView;
@property (nonatomic, strong) UIView *sheetGripContainerView;
@property (nonatomic, strong) UIView *sheetGripView;
@property (nonatomic, strong) UIView *titleCard;
@property (nonatomic, strong) UIVisualEffectView *titleBlurView;
@property (nonatomic, strong) UIStackView *titleContentStack;
@property (nonatomic, strong) UIStackView *titleLocationStack;
@property (nonatomic, strong) UILabel *titleCardTitleLabel;
@property (nonatomic, strong) UILabel *titleCardLocationLabel;
@property (nonatomic, strong) UIImageView *titleCardLocationIconView;
@property (nonatomic, strong) UIView *titlePricePillView;
@property (nonatomic, strong) UILabel *titlePriceLabel;
@property (nonatomic, strong) UIView *titleAccentRuleView;
@property PetAdCardView *petCard;
// Layout constraints
@property (nonatomic, strong) NSLayoutConstraint *tableViewTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *tableViewHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *heroHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *contentSheetTopConstraint;
@property (nonatomic, assign) CGFloat contentSheetRestingTopConstant;
@property (nonatomic, assign) CGFloat contentSheetExpandedTopConstant;
@property (nonatomic, assign) BOOL isUpdatingContentSheetFromScroll;

@property (nonatomic, assign) BOOL isFavorite;
@property (nonatomic, strong) UserContactView *contactView;
@property (nonatomic, assign) float actionPadding;
@property (nonatomic, strong) PPQuickActionsView *actionsViewTop;
@property (nonatomic, strong) PPQuickActionsView *actionsViewBottom;

// @property (nonatomic, strong) UIButton *galleryShareButton;
@property (nonatomic, strong) UIButton *galleryReportButton;
@property (nonatomic, strong) UIView *descriptionSurfaceView;
@property (nonatomic, strong) UITextView *descriptionTextView;
@property (nonatomic, strong) NSLayoutConstraint *descriptionHeightConstraint;
@property (nonatomic, strong) UIButton *descriptionToggleButton;
@property (nonatomic, strong) NSLayoutConstraint *descriptionToggleHeightConstraint;
@property (nonatomic, copy) NSString *fullDescriptionText;
@property (nonatomic, assign) BOOL isDescriptionExpanded;
@property (nonatomic, assign) BOOL shouldCollapseDescription;
@property (nonatomic, assign) CGFloat galleryMaxHeight;
@property (nonatomic, assign) BOOL isHeroReadMorePulseActive;

@property (nonatomic, strong) UIView *infoView;
@property (nonatomic, strong) UIView *similarAdsSeparator;
@property (nonatomic, strong) UIView *similarAccessoriesSeparator;
@property (nonatomic, assign) BOOL didTrackViewInteraction;
@property (nonatomic, strong) NSLayoutConstraint *contactViewHeightConstraint;
@property (nonatomic, strong) UIView *contactDockView;
@property (nonatomic, strong) NSLayoutConstraint *contactDockHeightConstraint;
@property (nonatomic, strong) UIVisualEffectView *contactLockOverlayView;
@property (nonatomic, strong) UIButton *contactLockButton;
@property (nonatomic, assign) BOOL isLoadingOwnerModel;
@property (nonatomic, strong) UIView *galleryScrimView;
@property (nonatomic, assign) BOOL didCaptureNavigationBarState;
@property (nonatomic, assign) BOOL previousNavigationBarHidden;
@property (nonatomic, strong) UIBarButtonItem *favBarButtonItem;
@property (nonatomic, strong) UIBarButtonItem *shareBarButtonItem;
@property (nonatomic, strong) UIBarButtonItem *reportBarButtonItem;

@end
/*
 please bro complete
 shareBarButtonItem
 */
@implementation ViewerVC



- (void)viewDidLoad {
    [super viewDidLoad];

    self.isUserContactViewUpdated =NO;
    self.actionPadding = 20.00;
    _isAdFavoritedLoaded = NO;
    self.isFavorite = NO; // default
    [self initData];
    NSLog(@"USER ------>>> %@",self.ad.ownerID);
    NSLog(@"adID ------>>> %@",self.ad.adID);

    [PPAnalytics logViewItemForAd:self.ad];
}

- (UIColor *)pp_luxuryBackgroundColor
{
    if (@available(iOS 13.0, *)) {
        if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithHexString:@"#0E0E0C"];
        }
    }
    return [UIColor colorWithHexString:@"#FAF8F2"];
}

- (UIColor *)pp_luxurySurfaceColor
{
    if (@available(iOS 13.0, *)) {
        if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithWhite:0.10 alpha:1.0];
        }
    }
    return [UIColor colorWithHexString:@"#FFFFFF"];
}

- (UIColor *)pp_luxuryTextColor
{
    return UIColor.labelColor ?: [UIColor colorWithHexString:@"#111111"];
}

- (UIColor *)pp_luxuryEmeraldColor
{
    // Routed through the brand asset so every accent (chips, toggles, CTAs)
    // tracks the design-system primary color.
    return AppPrimaryClr ?: [UIColor colorWithHexString:@"#0F5138"];
}

- (UIColor *)pp_luxuryGoldColor
{
    return [UIColor colorWithHexString:@"#C59A35"];
}

- (NSString *)pp_titleCardLocationText
{
    if (self.ad.adLocation <= 0) {
        return kLang(@"AdViewerLocationSelectedFallback");
    }

    NSString *cityName = [[CitiesManager.shared cityNameForID:self.ad.adLocation]
                          stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (cityName.length > 0) {
        return cityName;
    }

    return kLang(@"AdViewerLocationSelectedFallback");
}

- (NSString *)pp_titleCardPriceText
{
    NSString *price = [GM formatPrice:self.ad.price currencyCode:kLang(@"Rials")];
    return price.length > 0 ? price : @"";
}

- (UILabel *)pp_makeTitleCardLabelWithFont:(UIFont *)font
                                      color:(UIColor *)color
                              numberOfLines:(NSInteger)numberOfLines
{
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = numberOfLines;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.adjustsFontForContentSizeCategory = YES;
    label.textAlignment = [Language alignmentForCurrentLanguage];
    label.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    return label;
}

- (void)pp_buildLocalTitleCardContent
{
    if (!self.titleCard || self.titleCardTitleLabel) {
        return;
    }

    self.titleCard.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.titleCard.backgroundColor = UIColor.clearColor;
    self.titleCard.userInteractionEnabled = YES;
    self.titleCard.isAccessibilityElement = YES;
    self.titleCard.accessibilityTraits = UIAccessibilityTraitStaticText;
    self.titleCard.layer.cornerRadius = 28.0;
    self.titleCard.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.titleCard.layer.shadowRadius = 26.0;
    self.titleCard.layer.shadowOffset = CGSizeMake(0.0, 14.0);
    if (@available(iOS 13.0, *)) {
        self.titleCard.layer.cornerCurve = kCACornerCurveContinuous;
    }
    
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    
    self.titleBlurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    self.titleBlurView.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleBlurView.userInteractionEnabled = NO;
    self.titleBlurView.clipsToBounds = YES;
    self.titleBlurView.alpha = 0.3;
    self.titleBlurView.layer.cornerRadius = self.titleCard.layer.cornerRadius;
    if (@available(iOS 13.0, *)) {
        self.titleBlurView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.titleCard addSubview:self.titleBlurView];

    self.titleCardTitleLabel = [self pp_makeTitleCardLabelWithFont:[GM boldFontWithSize:25.0]
                                                              color:[self pp_luxuryTextColor]
                                                      numberOfLines:2];
    self.titleCardTitleLabel.text = self.ad.adTitle.length > 0 ? self.ad.adTitle : @"";
    [self.titleCardTitleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh
                                                              forAxis:UILayoutConstraintAxisVertical];

    UIImageSymbolConfiguration *locationConfig =
    [UIImageSymbolConfiguration configurationWithPointSize:13.0 weight:UIImageSymbolWeightSemibold];
    self.titleCardLocationIconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"mappin.and.ellipse"
                                                                                withConfiguration:locationConfig]];
    self.titleCardLocationIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleCardLocationIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.titleCardLocationIconView.tintColor = [[self pp_luxuryEmeraldColor] colorWithAlphaComponent:0.70];
    self.titleCardLocationIconView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    self.titleCardLocationLabel = [self pp_makeTitleCardLabelWithFont:[GM MidFontWithSize:14.0]
                                                                 color:UIColor.secondaryLabelColor
                                                         numberOfLines:2];
    self.titleCardLocationLabel.text = [self pp_titleCardLocationText];

    self.titleLocationStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.titleCardLocationIconView,
        self.titleCardLocationLabel
    ]];
    self.titleLocationStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLocationStack.axis = UILayoutConstraintAxisHorizontal;
    self.titleLocationStack.spacing = 7.0;
    self.titleLocationStack.alignment = UIStackViewAlignmentCenter;
    self.titleLocationStack.distribution = UIStackViewDistributionFill;
    self.titleLocationStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.titleLocationStack.hidden = self.titleCardLocationLabel.text.length == 0;

    self.titleContentStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.titleCardTitleLabel,
        self.titleLocationStack
    ]];
    self.titleContentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleContentStack.axis = UILayoutConstraintAxisVertical;
    self.titleContentStack.spacing = 9.0;
    self.titleContentStack.alignment = UIStackViewAlignmentFill;
    self.titleContentStack.distribution = UIStackViewDistributionFill;
    self.titleContentStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.titleCard addSubview:self.titleContentStack];

    self.titlePricePillView = [[UIView alloc] init];
    self.titlePricePillView.translatesAutoresizingMaskIntoConstraints = NO;
    self.titlePricePillView.layer.cornerRadius = 25.0;
    self.titlePricePillView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.titlePricePillView.clipsToBounds = NO;
    if (@available(iOS 13.0, *)) {
        self.titlePricePillView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.titleCard addSubview:self.titlePricePillView];

    self.titlePriceLabel = [self pp_makeTitleCardLabelWithFont:[GM boldFontWithSize:19.0]
                                                          color:UIColor.whiteColor
                                                  numberOfLines:1];
    self.titlePriceLabel.text = [self pp_titleCardPriceText];
    self.titlePriceLabel.textAlignment = NSTextAlignmentCenter;
    self.titlePriceLabel.adjustsFontSizeToFitWidth = YES;
    self.titlePriceLabel.minimumScaleFactor = 0.72;
    [self.titlePricePillView addSubview:self.titlePriceLabel];

    self.titleAccentRuleView = [[UIView alloc] init];
    self.titleAccentRuleView.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleAccentRuleView.layer.cornerRadius = 0.5;
    self.titleAccentRuleView.userInteractionEnabled = NO;
    [self.titleCard addSubview:self.titleAccentRuleView];

    [NSLayoutConstraint activateConstraints:@[
        [self.titleBlurView.topAnchor constraintEqualToAnchor:self.titleCard.topAnchor],
        [self.titleBlurView.leadingAnchor constraintEqualToAnchor:self.titleCard.leadingAnchor],
        [self.titleBlurView.trailingAnchor constraintEqualToAnchor:self.titleCard.trailingAnchor],
        [self.titleBlurView.bottomAnchor constraintEqualToAnchor:self.titleCard.bottomAnchor],

        [self.titleContentStack.topAnchor constraintEqualToAnchor:self.titleCard.topAnchor constant:22.0],
        [self.titleContentStack.leadingAnchor constraintEqualToAnchor:self.titleCard.leadingAnchor constant:22.0],
        [self.titleContentStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.titlePricePillView.leadingAnchor constant:-16.0],
        [self.titleContentStack.bottomAnchor constraintEqualToAnchor:self.titleAccentRuleView.topAnchor constant:-15.0],

        [self.titleCardLocationIconView.widthAnchor constraintEqualToConstant:16.0],
        [self.titleCardLocationIconView.heightAnchor constraintEqualToConstant:16.0],

        [self.titlePricePillView.topAnchor constraintEqualToAnchor:self.titleCard.topAnchor constant:22.0],
        [self.titlePricePillView.trailingAnchor constraintEqualToAnchor:self.titleCard.trailingAnchor constant:-20.0],
        [self.titlePricePillView.bottomAnchor constraintLessThanOrEqualToAnchor:self.titleCard.bottomAnchor constant:-22.0],
        [self.titlePricePillView.widthAnchor constraintGreaterThanOrEqualToConstant:120.0],
        [self.titlePricePillView.widthAnchor constraintLessThanOrEqualToConstant:154.0],
        [self.titlePricePillView.heightAnchor constraintGreaterThanOrEqualToConstant:50.0],

        [self.titlePriceLabel.topAnchor constraintEqualToAnchor:self.titlePricePillView.topAnchor constant:8.0],
        [self.titlePriceLabel.leadingAnchor constraintEqualToAnchor:self.titlePricePillView.leadingAnchor constant:12.0],
        [self.titlePriceLabel.trailingAnchor constraintEqualToAnchor:self.titlePricePillView.trailingAnchor constant:-12.0],
        [self.titlePriceLabel.bottomAnchor constraintEqualToAnchor:self.titlePricePillView.bottomAnchor constant:-8.0],

        [self.titleAccentRuleView.leadingAnchor constraintEqualToAnchor:self.titleCard.leadingAnchor constant:22.0],
        [self.titleAccentRuleView.trailingAnchor constraintEqualToAnchor:self.titleCard.trailingAnchor constant:-22.0],
        [self.titleAccentRuleView.bottomAnchor constraintEqualToAnchor:self.titleCard.bottomAnchor constant:-18.0],
        [self.titleAccentRuleView.heightAnchor constraintEqualToConstant:1.0],
    ]];
}

- (void)pp_applyLocalTitleCardTheme
{
    if (!self.titleCard || !self.titleCardTitleLabel) {
        return;
    }

    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    UIColor *accent = [self pp_luxuryEmeraldColor];
    UIColor *surface = dark
    ? [[UIColor colorWithHexString:@"#141415"] colorWithAlphaComponent:0.82]
    : [UIColor colorWithWhite:1.0 alpha:0.76];

    self.titleCard.backgroundColor = surface;
    [self.titleCard pp_setBorderColor:[UIColor colorWithWhite:dark ? 1.0 : 0.0 alpha:dark ? 0.08 : 0.055]];
    [self.titleCard pp_setShadowColor:UIColor.blackColor];
    self.titleCard.layer.shadowOpacity = dark ? 0.26 : 0.075;
    self.titleCard.layer.shadowRadius = dark ? 30.0 : 26.0;
    self.titleCard.layer.shadowOffset = CGSizeMake(0.0, dark ? 16.0 : 14.0);

    UIBlurEffectStyle blurStyle = dark ? UIBlurEffectStyleSystemChromeMaterialDark : UIBlurEffectStyleSystemThinMaterialLight;
    self.titleBlurView.effect = [UIBlurEffect effectWithStyle:blurStyle];
    self.titleBlurView.backgroundColor = [surface colorWithAlphaComponent:dark ? 0.30 : 0.20];

    self.titleCardTitleLabel.textColor = [self pp_luxuryTextColor];
    self.titleCardTitleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.titleCardLocationLabel.textColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:dark ? 0.86 : 0.78];
    self.titleCardLocationLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.titleCardLocationIconView.tintColor = [accent colorWithAlphaComponent:dark ? 0.88 : 0.72];

    self.titlePricePillView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.14 : 0.09];
    [self.titlePricePillView pp_setBorderColor:[accent colorWithAlphaComponent:dark ? 0.36 : 0.28]];
    [self.titlePricePillView pp_setShadowColor:accent];
    self.titlePricePillView.layer.shadowOpacity = dark ? 0.32 : 0.22;
    self.titlePricePillView.layer.shadowRadius = 24.0;
    self.titlePricePillView.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    self.titlePriceLabel.textColor = accent;
    self.titleAccentRuleView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.26 : 0.18];

    self.titleCard.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.titleContentStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.titleLocationStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    NSMutableArray<NSString *> *accessibilityParts = [NSMutableArray array];
    if (self.titleCardTitleLabel.text.length > 0) {
        [accessibilityParts addObject:self.titleCardTitleLabel.text];
    }
    if (self.titleCardLocationLabel.text.length > 0) {
        [accessibilityParts addObject:self.titleCardLocationLabel.text];
    }
    if (self.titlePriceLabel.text.length > 0) {
        [accessibilityParts addObject:self.titlePriceLabel.text];
    }
    self.titleCard.accessibilityLabel = [accessibilityParts componentsJoinedByString:@", "];
}

- (void)pp_refreshLocalTitleCardTexts
{
    if (!self.titleCardTitleLabel) {
        return;
    }

    self.titleCardTitleLabel.text = self.ad.adTitle.length > 0 ? self.ad.adTitle : @"";
    self.titlePriceLabel.text = [self pp_titleCardPriceText];

    NSString *locationText = [self pp_titleCardLocationText];
    self.titleCardLocationLabel.text = locationText;
    BOOL hasLocationText = locationText.length > 0;
    self.titleLocationStack.hidden = !hasLocationText;
    self.titleCardLocationIconView.hidden = !hasLocationText;

    [self pp_applyLocalTitleCardTheme];
}

- (void)pp_buildSheetGripCueIfNeeded
{
    if (self.sheetGripContainerView || !self.contentScrollView) {
        return;
    }

    self.sheetGripContainerView = [[UIView alloc] init];
    self.sheetGripContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.sheetGripContainerView.userInteractionEnabled = NO;
    self.sheetGripContainerView.isAccessibilityElement = NO;
    [self.contentScrollView addSubview:self.sheetGripContainerView];

    self.sheetGripView = [[UIView alloc] init];
    self.sheetGripView.translatesAutoresizingMaskIntoConstraints = NO;
    self.sheetGripView.userInteractionEnabled = NO;
    self.sheetGripView.layer.cornerRadius = 2.5;
    if (@available(iOS 13.0, *)) {
        self.sheetGripView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.sheetGripContainerView addSubview:self.sheetGripView];

    if (@available(iOS 11.0, *)) {
        [NSLayoutConstraint activateConstraints:@[
            [self.sheetGripContainerView.topAnchor constraintEqualToAnchor:self.contentScrollView.frameLayoutGuide.topAnchor constant:7.0],
            [self.sheetGripContainerView.centerXAnchor constraintEqualToAnchor:self.contentScrollView.frameLayoutGuide.centerXAnchor],
            [self.sheetGripContainerView.widthAnchor constraintEqualToConstant:74.0],
            [self.sheetGripContainerView.heightAnchor constraintEqualToConstant:18.0],
        ]];
    } else {
        [NSLayoutConstraint activateConstraints:@[
            [self.sheetGripContainerView.topAnchor constraintEqualToAnchor:self.contentScrollView.topAnchor constant:7.0],
            [self.sheetGripContainerView.centerXAnchor constraintEqualToAnchor:self.contentScrollView.centerXAnchor],
            [self.sheetGripContainerView.widthAnchor constraintEqualToConstant:74.0],
            [self.sheetGripContainerView.heightAnchor constraintEqualToConstant:18.0],
        ]];
    }

    [NSLayoutConstraint activateConstraints:@[
        [self.sheetGripView.centerXAnchor constraintEqualToAnchor:self.sheetGripContainerView.centerXAnchor],
        [self.sheetGripView.centerYAnchor constraintEqualToAnchor:self.sheetGripContainerView.centerYAnchor],
        [self.sheetGripView.widthAnchor constraintEqualToConstant:42.0],
        [self.sheetGripView.heightAnchor constraintEqualToConstant:5.0],
    ]];

    [self pp_applySheetGripTheme];
}

- (void)pp_applySheetGripTheme
{
    if (!self.sheetGripView) {
        return;
    }

    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    UIColor *accent = [self pp_luxuryEmeraldColor];
    self.sheetGripContainerView.backgroundColor = UIColor.clearColor;
    self.sheetGripView.backgroundColor = dark
        ? [UIColor.whiteColor colorWithAlphaComponent:0.36]
        : [accent colorWithAlphaComponent:0.30];
    [self.sheetGripView pp_setShadowColor:dark ? UIColor.blackColor : accent];
    self.sheetGripView.layer.shadowOpacity = dark ? 0.20 : 0.14;
    self.sheetGripView.layer.shadowRadius = 8.0;
    self.sheetGripView.layer.shadowOffset = CGSizeMake(0.0, 2.0);
}

- (UIView *)pp_makeAmbientGlowViewWithRadius:(CGFloat)radius
{
    UIView *view = [[UIView alloc] init];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.userInteractionEnabled = NO;
    view.layer.cornerRadius = radius;
    view.layer.shadowRadius = 58.0;
    view.layer.shadowOpacity = 0.22;
    view.layer.shadowOffset = CGSizeZero;
    return view;
}

- (void)pp_buildLiveBackgroundIfNeeded
{
    if (self.ambientGlowTopView || self.ambientGlowBottomView || !self.contentContainer) {
        return;
    }

    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    UIColor *accent = [self pp_luxuryEmeraldColor];
    UIColor *gold = [self pp_luxuryGoldColor];

    self.ambientGlowTopView = [self pp_makeAmbientGlowViewWithRadius:140.0];
    self.ambientGlowTopView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.10 : 0.075];
    self.ambientGlowTopView.layer.shadowOpacity = 0.0;
    [self.contentContainer addSubview:self.ambientGlowTopView];

    self.ambientGlowBottomView = [self pp_makeAmbientGlowViewWithRadius:168.0];
    self.ambientGlowBottomView.backgroundColor = [gold colorWithAlphaComponent:dark ? 0.10 : 0.085];
    self.ambientGlowBottomView.layer.shadowOpacity = 0.0;
    [self.contentContainer addSubview:self.ambientGlowBottomView];
    [self.contentContainer sendSubviewToBack:self.ambientGlowBottomView];
    [self.contentContainer sendSubviewToBack:self.ambientGlowTopView];

    [NSLayoutConstraint activateConstraints:@[
        [self.ambientGlowTopView.widthAnchor constraintEqualToConstant:280.0],
        [self.ambientGlowTopView.heightAnchor constraintEqualToConstant:280.0],
        [self.ambientGlowTopView.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:-132.0],
        [self.ambientGlowTopView.topAnchor constraintEqualToAnchor:self.contentContainer.topAnchor constant:-92.0],

        [self.ambientGlowBottomView.widthAnchor constraintEqualToConstant:336.0],
        [self.ambientGlowBottomView.heightAnchor constraintEqualToConstant:336.0],
        [self.ambientGlowBottomView.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:138.0],
        [self.ambientGlowBottomView.bottomAnchor constraintEqualToAnchor:self.contentContainer.bottomAnchor constant:110.0],
    ]];
}

- (void)pp_styleSeparator:(UIView *)separator
{
    if (!separator) {
        return;
    }

    UIColor *accent = [self pp_luxuryEmeraldColor];
    separator.backgroundColor = [accent colorWithAlphaComponent:0.16];
    separator.alpha = 1.0;
}

- (void)pp_applyViewerTheme
{
    UIColor *surfaceColor = [self pp_luxurySurfaceColor];
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    self.view.backgroundColor = [self pp_luxuryBackgroundColor];
    self.contentScrollView.backgroundColor = [self pp_luxuryBackgroundColor];
    self.ambientGlowTopView.backgroundColor = [[self pp_luxuryEmeraldColor] colorWithAlphaComponent:dark ? 0.10 : 0.075];
    self.ambientGlowBottomView.backgroundColor = [[self pp_luxuryGoldColor] colorWithAlphaComponent:dark ? 0.10 : 0.085];

    self.contentSurfaceGradientLayer.colors = @[
        (__bridge id)[UIColor.clearColor CGColor],
        (__bridge id)[UIColor.clearColor CGColor]
    ];

    [self pp_applySheetGripTheme];
    self.descriptionSurfaceView.backgroundColor = surfaceColor;
    [self.descriptionSurfaceView pp_setBorderColor:[UIColor colorWithWhite:dark ? 1.0 : 0.0 alpha:dark ? 0.08 : 0.06]];
    [self.descriptionSurfaceView pp_setShadowColor:UIColor.blackColor];
    self.descriptionSurfaceView.layer.shadowOpacity = dark ? 0.18 : 0.05;
    self.descriptionSurfaceView.layer.shadowRadius = dark ? 22.0 : 24.0;
    self.descriptionSurfaceView.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    self.descriptionSurfaceGradientLayer.colors = @[
        (__bridge id)[UIColor.clearColor CGColor],
        (__bridge id)[UIColor.clearColor CGColor]
    ];

    [self pp_applyLocalTitleCardTheme];
    [self pp_styleSeparator:self.similarAdsSeparator];
    [self pp_styleSeparator:self.similarAccessoriesSeparator];

    self.contactDockView.layer.shadowOpacity = dark ? 0.28 : 0.10;
    self.contactDockView.layer.shadowRadius = dark ? 28.0 : 24.0;
    self.contactDockView.layer.shadowOffset = CGSizeMake(0.0, 14.0);
    self.contactView.backgroundColor = dark
        ? [surfaceColor colorWithAlphaComponent:0.86]
        : [surfaceColor colorWithAlphaComponent:0.96];
    [self.contactView pp_setBorderColor:[UIColor colorWithWhite:dark ? 1.0 : 0.0 alpha:dark ? 0.08 : 0.05]];
    self.contactGradientLayer.colors = @[
        (__bridge id)[UIColor.clearColor CGColor],
        (__bridge id)[UIColor.clearColor CGColor]
    ];

    self.contactLockOverlayView.backgroundColor = [[UIColor systemBackgroundColor] colorWithAlphaComponent:dark ? 0.14 : 0.08];
    [self.contactLockOverlayView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:dark ? 0.12 : 0.18]];

    [self pp_styleContactActionButtons];
}

- (void)initData {
    self.view.backgroundColor = [self pp_luxuryBackgroundColor];

    self.heroContainerView = [[UIView alloc] init];
    self.heroContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroContainerView.backgroundColor = [UIColor colorWithWhite:0.06 alpha:1.0];
    self.heroContainerView.layer.cornerRadius = 0;
    self.heroContainerView.layer.masksToBounds = YES;
    [self.view addSubview:self.heroContainerView];

    self.imageGallery = [[PetImageGalleryView alloc] initWithFrame:CGRectZero
                                                        imageItems:self.ad.imageItems
                                                       galleryType:PetImageGalleryTypeAccessory
                                                        itemHeight:[self pp_heroHeight]
                                                          parentVC:self
                                                               obj:self.ad];

    self.imageGallery.translatesAutoresizingMaskIntoConstraints = NO;
    [self.heroContainerView addSubview:self.imageGallery];
    self.imageGallery.layer.cornerRadius = 0;
    if (@available(iOS 13.0, *)) {
        self.imageGallery.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.imageGallery.clipsToBounds = YES;
    self.imageGallery.layer.maskedCorners = self.heroContainerView.layer.maskedCorners;
    self.imageGallery.currentAd = self.ad;

    CGFloat galleryHeight = [self pp_heroHeight];
    self.galleryMaxHeight = galleryHeight;

    self.heroHeightConstraint = [self.heroContainerView.heightAnchor constraintEqualToConstant:galleryHeight];
    [NSLayoutConstraint activateConstraints:@[
        [self.heroContainerView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.heroContainerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.heroContainerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        self.heroHeightConstraint,

        [self.imageGallery.topAnchor constraintEqualToAnchor:self.heroContainerView.topAnchor],
        [self.imageGallery.leadingAnchor constraintEqualToAnchor:self.heroContainerView.leadingAnchor],
        [self.imageGallery.trailingAnchor constraintEqualToAnchor:self.heroContainerView.trailingAnchor],
        [self.imageGallery.bottomAnchor constraintEqualToAnchor:self.heroContainerView.bottomAnchor],
    ]];

    self.galleryScrimView = [[UIView alloc] init];
    self.galleryScrimView.translatesAutoresizingMaskIntoConstraints = NO;
    self.galleryScrimView.userInteractionEnabled = NO;
    self.galleryScrimView.backgroundColor = UIColor.clearColor;
    self.galleryScrimView.layer.cornerRadius = self.heroContainerView.layer.cornerRadius;
    self.galleryScrimView.layer.maskedCorners = self.heroContainerView.layer.maskedCorners;
    if (@available(iOS 13.0, *)) {
        self.galleryScrimView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.galleryScrimView.clipsToBounds = YES;
    self.galleryScrimView.hidden = YES;
    [self.view addSubview:self.galleryScrimView];

    [NSLayoutConstraint activateConstraints:@[
        [self.galleryScrimView.topAnchor constraintEqualToAnchor:self.heroContainerView.topAnchor],
        [self.galleryScrimView.leadingAnchor constraintEqualToAnchor:self.heroContainerView.leadingAnchor],
        [self.galleryScrimView.trailingAnchor constraintEqualToAnchor:self.heroContainerView.trailingAnchor],
        [self.galleryScrimView.bottomAnchor constraintEqualToAnchor:self.heroContainerView.bottomAnchor],
    ]];

    self.galleryScrimLayer = [CAGradientLayer layer];
    self.galleryScrimLayer.startPoint = CGPointMake(0.5, 0.0);
    self.galleryScrimLayer.endPoint = CGPointMake(0.5, 1.0);
    self.galleryScrimLayer.colors = @[
        (__bridge id)[UIColor.clearColor CGColor],
        (__bridge id)[UIColor.clearColor CGColor]
    ];
    self.galleryScrimLayer.locations = @[@0.0, @1.0];
    [self.galleryScrimView.layer addSublayer:self.galleryScrimLayer];

    self.titleCard = [[UIView alloc] init];
    self.titleCard.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleCard.backgroundColor = UIColor.clearColor;
    self.titleCard.userInteractionEnabled = YES;
    [self pp_buildLocalTitleCardContent];


    self.contentScrollView = [[UIScrollView alloc] init];
    self.contentScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentScrollView.showsVerticalScrollIndicator = NO;
    self.contentScrollView.alwaysBounceVertical = YES;
    self.contentScrollView.delegate = self;
    self.contentScrollView.decelerationRate = UIScrollViewDecelerationRateNormal;
    self.contentScrollView.backgroundColor = [self pp_luxuryBackgroundColor];
    self.contentScrollView.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    self.contentScrollView.layer.cornerRadius = 22.0;
    if (@available(iOS 13.0, *)) {
        self.contentScrollView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.contentScrollView.clipsToBounds = YES;
    self.contentScrollView.layer.borderWidth = 0.0;

    self.contentSurfaceGradientLayer = [CAGradientLayer layer];
    self.contentSurfaceGradientLayer.cornerRadius = self.contentScrollView.layer.cornerRadius;
    [self.contentScrollView.layer insertSublayer:self.contentSurfaceGradientLayer atIndex:0];
    [self.view addSubview:self.contentScrollView];

    self.contentSheetRestingTopConstant = -24.0;
    self.contentSheetExpandedTopConstant = [self pp_contentSheetExpandedTopConstantForHeroHeight:galleryHeight];
    self.contentSheetTopConstraint = [self.contentScrollView.topAnchor constraintEqualToAnchor:self.heroContainerView.bottomAnchor
                                                                                       constant:self.contentSheetRestingTopConstant];
    [NSLayoutConstraint activateConstraints:@[
        self.contentSheetTopConstraint,
        [self.contentScrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.contentScrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.contentScrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    self.contentContainer = [[UIView alloc] init];
    self.contentContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentScrollView addSubview:self.contentContainer];

    if (@available(iOS 11.0, *)) {
        [NSLayoutConstraint activateConstraints:@[
            [self.contentContainer.topAnchor constraintEqualToAnchor:self.contentScrollView.contentLayoutGuide.topAnchor],
            [self.contentContainer.leadingAnchor constraintEqualToAnchor:self.contentScrollView.contentLayoutGuide.leadingAnchor],
            [self.contentContainer.trailingAnchor constraintEqualToAnchor:self.contentScrollView.contentLayoutGuide.trailingAnchor],
            [self.contentContainer.bottomAnchor constraintEqualToAnchor:self.contentScrollView.contentLayoutGuide.bottomAnchor],
            [self.contentContainer.widthAnchor constraintEqualToAnchor:self.contentScrollView.frameLayoutGuide.widthAnchor]
        ]];
    } else {
        [NSLayoutConstraint activateConstraints:@[
            [self.contentContainer.topAnchor constraintEqualToAnchor:self.contentScrollView.topAnchor constant:0],
            [self.contentContainer.leadingAnchor constraintEqualToAnchor:self.contentScrollView.leadingAnchor],
            [self.contentContainer.trailingAnchor constraintEqualToAnchor:self.contentScrollView.trailingAnchor],
            [self.contentContainer.bottomAnchor constraintEqualToAnchor:self.contentScrollView.bottomAnchor],
            [self.contentContainer.widthAnchor constraintEqualToAnchor:self.contentScrollView.widthAnchor]
        ]];
    }

    [self pp_buildSheetGripCueIfNeeded];
    [self pp_buildLiveBackgroundIfNeeded];
    [self.contentContainer addSubview:self.titleCard];

    [NSLayoutConstraint activateConstraints:@[
        [self.titleCard.topAnchor constraintEqualToAnchor:self.contentContainer.topAnchor constant:24.0],
        [self.titleCard.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:20.0],
        [self.titleCard.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-20.0],
        [self.titleCard.heightAnchor constraintGreaterThanOrEqualToConstant:kViewerVcTitleCardMinHeight],
    ]];

    [self initInfoView];
    [self initUserContactView];
    [self initdescriptionTextView];
    [self initSimilarAds];
    [self initSimilarAccess];
    [self pp_applyViewerTheme];
    [self pp_updateHeroDepthForScrollOffset:0.0];
    [self pp_prepareEntranceAnimationState];
}

- (CGFloat)pp_heroHeight {
    CGFloat width = UIScreen.mainScreen.bounds.size.width;
    return MIN(MAX(width * 1.06, 360.0), 500.0) + 30.0;
}


#pragma mark - Quick actions header


-(void)initInfoView
{

    NSString *ageString;
    if (Language.isRTL)
        ageString = [NSString stringWithFormat:@"%@ شهر",
                     self.ad.petAgeMonths];
    else
        ageString = [NSString stringWithFormat:@"%@ month %@",
                     self.ad.petAgeMonths,
                     self.ad.petAgeMonths .integerValue> 1 ? @"s" : @""];

    NSString *gender = self.ad.isFemale ? kLang(@"female") :  kLang(@"male");
    NSString *SubKindName = [SubKindModel getSubKindName:self.ad.subcategory subKindsArrayLocal:[MKM getSubKindArray:self.ad.category]];
    NSString *typeText = [NSString stringWithFormat:@"%@: %@", kLang(@"Type"), SubKindName.length > 0 ? SubKindName : @"-"];
    NSString *ageText = [NSString stringWithFormat:@"%@: %@", kLang(@"Age"), ageString.length > 0 ? ageString : @"-"];
    NSString *genderText = [NSString stringWithFormat:@"%@: %@", kLang(@"Gender"), gender.length > 0 ? gender : @"-"];
    self.infoView =
    [self pp_makeViewerMetaBadgesViewWithItems:@[
        [PPInfoPill itemWithIcon:@"pawprint"
                            text:typeText],
        [PPInfoPill itemWithIcon:@"calendar"
                            text:ageText],
        [PPInfoPill itemWithIcon:@"person"
                            text:genderText],

    ]];
    [self.contentContainer addSubview:self.infoView];

    [NSLayoutConstraint activateConstraints:@[
        [self.infoView.topAnchor constraintEqualToAnchor:self.titleCard.bottomAnchor constant:18],
        [self.infoView.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:20],
        [self.infoView.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-20],
        [self.infoView.heightAnchor constraintGreaterThanOrEqualToConstant:64]
    ]];
}

- (UIView *)pp_makeViewerMetaBadgesViewWithItems:(NSArray<PPInfoPill *> *)items
{
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = UIColor.clearColor;
    container.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.alignment = UIStackViewAlignmentFill;
    stack.distribution = UIStackViewDistributionFillEqually;
    stack.spacing = 8.0;
    stack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [container addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:container.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];

    NSArray<UIColor *> *accentPalette = @[
        [self pp_luxuryEmeraldColor],
        [self pp_luxuryGoldColor],
        AppPrimaryClr ?: [UIColor systemPinkColor],
    ];

    [items enumerateObjectsUsingBlock:^(PPInfoPill * _Nonnull item, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)stop;
        if (item.text.length == 0 && item.iconName.length == 0) {
            return;
        }

        UIColor *accent = accentPalette[idx % accentPalette.count];
        [stack addArrangedSubview:[self pp_makeViewerMetaBadgeWithItem:item accent:accent]];
    }];

    return container;
}

- (UIView *)pp_makeViewerMetaBadgeWithItem:(PPInfoPill *)item
                                    accent:(UIColor *)accent
{
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    }

    UIView *badge = [[UIView alloc] init];
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    badge.backgroundColor = dark ? [UIColor colorWithWhite:0.13 alpha:1.0] : [UIColor colorWithWhite:1.0 alpha:0.96];
    badge.layer.cornerRadius = 22.0;
    badge.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    badge.clipsToBounds = NO;
    [badge pp_setBorderColor:[accent colorWithAlphaComponent:dark ? 0.22 : 0.13]];
    [badge pp_setShadowColor:UIColor.blackColor];
    badge.layer.shadowOpacity = dark ? 0.0 : 0.055;
    badge.layer.shadowRadius = 16.0;
    badge.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    badge.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    badge.isAccessibilityElement = YES;
    badge.accessibilityLabel = item.text;
    if (@available(iOS 13.0, *)) {
        badge.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIView *iconPlate = [[UIView alloc] init];
    iconPlate.translatesAutoresizingMaskIntoConstraints = NO;
    iconPlate.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.18 : 0.11];
    iconPlate.layer.cornerRadius = 14.0;
    iconPlate.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        iconPlate.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIImageSymbolConfiguration *symbolConfig =
        [UIImageSymbolConfiguration configurationWithPointSize:13.0
                                                        weight:UIImageSymbolWeightSemibold
                                                         scale:UIImageSymbolScaleMedium];
    NSString *symbolName = item.iconName.length > 0 ? item.iconName : @"sparkles";
    UIImage *symbolImage = [UIImage systemImageNamed:symbolName
                                  withConfiguration:symbolConfig];
    if (!symbolImage) {
        symbolImage = [UIImage systemImageNamed:@"sparkles"
                              withConfiguration:symbolConfig];
    }
    UIImageView *iconView = [[UIImageView alloc] initWithImage:symbolImage];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.tintColor = accent;
    iconView.hidden = item.iconName.length == 0;
    [iconPlate addSubview:iconView];

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = item.text;
    label.font = [GM boldFontWithSize:12.4] ?: [UIFont systemFontOfSize:12.4 weight:UIFontWeightSemibold];
    label.textColor = [self pp_luxuryTextColor];
    label.numberOfLines = 2;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.78;
    label.textAlignment = NSTextAlignmentNatural;
    label.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIStackView *content = [[UIStackView alloc] initWithArrangedSubviews:@[iconPlate, label]];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    content.axis = UILayoutConstraintAxisHorizontal;
    content.alignment = UIStackViewAlignmentCenter;
    content.distribution = UIStackViewDistributionFill;
    content.spacing = 8.0;
    content.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [badge addSubview:content];

    [NSLayoutConstraint activateConstraints:@[
        [iconPlate.widthAnchor constraintEqualToConstant:28.0],
        [iconPlate.heightAnchor constraintEqualToConstant:28.0],
        [iconView.centerXAnchor constraintEqualToAnchor:iconPlate.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconPlate.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:14.0],
        [iconView.heightAnchor constraintEqualToConstant:14.0],
        [content.topAnchor constraintEqualToAnchor:badge.topAnchor constant:10.0],
        [content.leadingAnchor constraintEqualToAnchor:badge.leadingAnchor constant:10.0],
        [content.trailingAnchor constraintEqualToAnchor:badge.trailingAnchor constant:-10.0],
        [content.bottomAnchor constraintEqualToAnchor:badge.bottomAnchor constant:-10.0],
    ]];

    return badge;
}


- (void)initdescriptionTextView {
    self.descriptionSurfaceView = [[UIView alloc] init];
    self.descriptionSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.descriptionSurfaceView.layer.cornerRadius = 26.0;
    if (@available(iOS 13.0, *)) {
        self.descriptionSurfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.descriptionSurfaceView.layer.borderWidth = 0.5;
    self.descriptionSurfaceView.clipsToBounds = NO;
    [self.contentContainer addSubview:self.descriptionSurfaceView];

    self.descriptionSurfaceGradientLayer = [CAGradientLayer layer];
    self.descriptionSurfaceGradientLayer.cornerRadius = self.descriptionSurfaceView.layer.cornerRadius;
    [self.descriptionSurfaceView.layer insertSublayer:self.descriptionSurfaceGradientLayer atIndex:0];

    self.descriptionTextView = [[UITextView alloc] init];
    self.descriptionTextView.translatesAutoresizingMaskIntoConstraints = NO;
    self.descriptionTextView.scrollEnabled = NO;   // ✅ key
    self.descriptionTextView.editable = NO;
    self.descriptionTextView.selectable = YES;
    self.descriptionTextView.backgroundColor = UIColor.clearColor;
    self.descriptionTextView.tintColor = [self pp_luxuryEmeraldColor];
    self.descriptionTextView.textAlignment = NSTextAlignmentNatural;
    self.descriptionTextView.textContainerInset = UIEdgeInsetsMake(8, 0, 8, 0);
    self.descriptionTextView.textContainer.lineFragmentPadding = 0;
    self.descriptionTextView.font = [GM MidFontWithSize:16];
    self.descriptionTextView.adjustsFontForContentSizeCategory = YES;
    self.descriptionTextView.linkTextAttributes = @{
        NSForegroundColorAttributeName: [self pp_luxuryEmeraldColor],
        NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle)
    };

    self.fullDescriptionText = [self pp_normalizedDescriptionText:self.ad.adDescription];
    self.shouldCollapseDescription = self.fullDescriptionText.length > 260;
    self.isDescriptionExpanded = !self.shouldCollapseDescription;
    [self.descriptionSurfaceView addSubview:self.descriptionTextView];

    self.descriptionToggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.descriptionToggleButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.descriptionToggleButton.titleLabel.font = [GM boldFontWithSize:14.0];
    self.descriptionToggleButton.contentHorizontalAlignment = Language.isRTL ? UIControlContentHorizontalAlignmentRight : UIControlContentHorizontalAlignmentLeft;
    [self.descriptionToggleButton setTitleColor:[self pp_luxuryEmeraldColor] forState:UIControlStateNormal];
    [self.descriptionToggleButton addTarget:self action:@selector(pp_toggleDescriptionExpanded:) forControlEvents:UIControlEventTouchUpInside];
    [self.descriptionSurfaceView addSubview:self.descriptionToggleButton];
    [self pp_styleInteractiveButton:self.descriptionToggleButton];
    [self pp_refreshDescriptionTextAnimated:NO];

    self.descriptionHeightConstraint =
    [self.descriptionTextView.heightAnchor
     constraintGreaterThanOrEqualToConstant:44];
    self.descriptionHeightConstraint.priority = UILayoutPriorityDefaultHigh;
    self.descriptionToggleHeightConstraint = [self.descriptionToggleButton.heightAnchor constraintEqualToConstant:self.shouldCollapseDescription ? 34.0 : 0.0];

    [NSLayoutConstraint activateConstraints:@[
        [self.descriptionSurfaceView.topAnchor
         constraintEqualToAnchor:self.contactDockView.bottomAnchor constant:24],
        [self.descriptionSurfaceView.leadingAnchor
         constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:20],
        [self.descriptionSurfaceView.trailingAnchor
         constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-20],

        [self.descriptionTextView.topAnchor
         constraintEqualToAnchor:self.descriptionSurfaceView.topAnchor constant:22],
        [self.descriptionTextView.leadingAnchor
         constraintEqualToAnchor:self.descriptionSurfaceView.leadingAnchor constant:22],
        [self.descriptionTextView.trailingAnchor
         constraintEqualToAnchor:self.descriptionSurfaceView.trailingAnchor constant:-22],
        [self.descriptionTextView.bottomAnchor
         constraintEqualToAnchor:self.descriptionToggleButton.topAnchor constant:-6],
        [self.descriptionToggleButton.leadingAnchor constraintEqualToAnchor:self.descriptionTextView.leadingAnchor],
        [self.descriptionToggleButton.trailingAnchor constraintEqualToAnchor:self.descriptionTextView.trailingAnchor],
        [self.descriptionToggleButton.bottomAnchor constraintEqualToAnchor:self.descriptionSurfaceView.bottomAnchor constant:-18],
        self.descriptionToggleHeightConstraint,
        self.descriptionHeightConstraint
    ]];

}


- (void)initUserContactView {
    self.contactDockView = [[UIView alloc] init];
    self.contactDockView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contactDockView.backgroundColor = UIColor.clearColor;
    self.contactDockView.layer.cornerRadius = 30.0;
    if (@available(iOS 13.0, *)) {
        self.contactDockView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.contactDockView pp_setShadowColor:UIColor.blackColor];
    self.contactDockView.layer.shadowOpacity = 0.10;
    self.contactDockView.layer.shadowRadius = 24.0;
    self.contactDockView.layer.shadowOffset = CGSizeMake(0.0, 14.0);
    [self.contentContainer addSubview:self.contactDockView];

    self.contactView = [[UserContactView alloc] initWithFrame:CGRectZero];
    self.contactView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contactDockView addSubview:self.contactView];

    self.contactView.layer.cornerRadius = 26.0;
    if (@available(iOS 13.0, *)) {
        self.contactView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.contactView.clipsToBounds = YES;
    self.contactView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    [self.contactView pp_setBorderColor:[UIColor colorWithWhite:0.0 alpha:0.05]];

    self.contactGradientLayer = [CAGradientLayer layer];
    self.contactGradientLayer.colors = @[
        (__bridge id)[UIColor.clearColor CGColor],
        (__bridge id)[UIColor.clearColor CGColor]
    ];
    self.contactGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    self.contactGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    self.contactGradientLayer.cornerRadius = 26.0;
    [self.contactView.layer insertSublayer:self.contactGradientLayer atIndex:0];

    self.contactView.backgroundColor = [self pp_luxurySurfaceColor];
    self.contactView.semanticContentAttribute = GM.setSemantic;
    self.contactViewHeightConstraint = [self.contactView.heightAnchor constraintEqualToConstant:88.0];
    self.contactDockHeightConstraint = [self.contactDockView.heightAnchor constraintEqualToConstant:88.0];

    [NSLayoutConstraint activateConstraints:@[
        [self.contactDockView.topAnchor constraintEqualToAnchor:self.infoView.bottomAnchor constant:22.0],
        [self.contactDockView.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:20.0],
        [self.contactDockView.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-20.0],
        self.contactDockHeightConstraint,

        [self.contactView.leadingAnchor constraintEqualToAnchor:self.contactDockView.leadingAnchor],
        [self.contactView.trailingAnchor constraintEqualToAnchor:self.contactDockView.trailingAnchor],
        [self.contactView.topAnchor constraintEqualToAnchor:self.contactDockView.topAnchor],
        [self.contactView.bottomAnchor constraintEqualToAnchor:self.contactDockView.bottomAnchor],
        self.contactViewHeightConstraint,
    ]];
    [self pp_styleContactActionButtons];

    [self pp_updateContactAccessStateAnimated:NO];
}
- (void)initSimilarAds {

    UIView *separator = [[UIView alloc] init];
    separator.translatesAutoresizingMaskIntoConstraints = NO;

    [self pp_styleSeparator:separator];
    [self.contentContainer addSubview:separator];
    self.similarAdsSeparator = separator;
    self.similarAdsSeparator.hidden = YES;
    [NSLayoutConstraint activateConstraints:@[
        [separator.topAnchor constraintEqualToAnchor:self.descriptionSurfaceView.bottomAnchor constant:26],
        [separator.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:28],
        [separator.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-28],

        // Hairline thickness (1px, not 1pt)
        [separator.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],
    ]];

    // titleCard,infoView,contactView,descriptionTextView,similarAdsView
    self.similarAdsView = [[PPSimilarAdsView alloc] initWithFrame:CGRectZero];
    self.similarAdsView.translatesAutoresizingMaskIntoConstraints = NO;
    self.similarAdsView.titleString =  kLang(@"Similar Ads");
    __weak typeof(self) weakSelf = self;
    self.similarAdsView.didSelectViewModel = ^(PPUniversalCellViewModel * _Nonnull vm) {
        __strong typeof(weakSelf) self = weakSelf;
        [PPOverlayCoordinator pp_openDetailForObject:vm.ModelObject
                                              fromVC:self
                                          routingNav:nil];
    };
    self.similarAdsView.didUpdateContentState = ^(BOOL hasContent, NSInteger itemCount) {
        __strong typeof(weakSelf) self = weakSelf;
        (void)itemCount;
        self.similarAdsSeparator.hidden = !hasContent;
    };
    // ✅ MUST be added before constraints
    [self.contentContainer addSubview:self.similarAdsView];

    [NSLayoutConstraint activateConstraints:@[
        [self.similarAdsView.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:0],
        [self.similarAdsView.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-0],

        // ⛔️ also fix this (see below)
        [self.similarAdsView.topAnchor constraintEqualToAnchor:separator.bottomAnchor constant:18],
    ]];


    PetAd *ad = [[PetAd alloc]init];
    ad.adID = self.ad.adID;
    ad.category = self.ad.category;
    ad.adTitle = self.ad.adTitle;
    ad.subcategory = 0;
    [[PetAdManager sharedManager]
     fetchSimilarAdsForAd:ad limit:15 completion:^(NSArray<PetAd *> * _Nonnull ads) {
        NSArray<PPUniversalCellViewModel *> *models = [self buildViewModelsFromModels:ads];
        //NSLog(@"models %@",[models modelToJSONString]);
        [self.similarAdsView updateWithViewModels:models];
    }];
}


- (void)initSimilarAccess {

    UIView *separator = [[UIView alloc] init];
    separator.translatesAutoresizingMaskIntoConstraints = NO;

    [self pp_styleSeparator:separator];
    [self.contentContainer addSubview:separator];
    self.similarAccessoriesSeparator = separator;
    self.similarAccessoriesSeparator.hidden = YES;
    [NSLayoutConstraint activateConstraints:@[
        [separator.topAnchor constraintEqualToAnchor:self.similarAdsView.bottomAnchor constant:24],
        [separator.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:28],
        [separator.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-28],

        // Hairline thickness (1px, not 1pt)
        [separator.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],
    ]];


    // titleCard,infoView,contactView,descriptionTextView,similarAdsView
    self.similarAccessView = [[PPSimilarAdsView alloc] initWithFrame:CGRectZero];
    self.similarAccessView.translatesAutoresizingMaskIntoConstraints = NO;
    self.similarAccessView.titleString =  kLang(@"SimilarAaccess");
    __weak typeof(self) weakSelf = self;
    self.similarAccessView.didSelectViewModel = ^(PPUniversalCellViewModel * _Nonnull vm) {
        __strong typeof(weakSelf) self = weakSelf;
        [PPOverlayCoordinator pp_openDetailForObject:vm.ModelObject
                                              fromVC:self
                                          routingNav:nil];
    };
    self.similarAccessView.didUpdateContentState = ^(BOOL hasContent, NSInteger itemCount) {
        __strong typeof(weakSelf) self = weakSelf;
        (void)itemCount;
        self.similarAccessoriesSeparator.hidden = !hasContent;
    };
    // ✅ MUST be added before constraints
    [self.contentContainer addSubview:self.similarAccessView];

    [NSLayoutConstraint activateConstraints:@[
        [self.similarAccessView.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:0],
        [self.similarAccessView.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-0],

        // ⛔️ also fix this (see below)
        [self.similarAccessView.topAnchor constraintEqualToAnchor:separator.bottomAnchor constant:18],

        [self.similarAccessView.bottomAnchor constraintEqualToAnchor:self.contentContainer.bottomAnchor constant:-28],
    ]];


    PetAd *ad = [[PetAd alloc]init];
    ad.adID = self.ad.adID;
    ad.category = self.ad.category;
    ad.adTitle = self.ad.adTitle;
    ad.subcategory = 0;


    [[PetAccessoryManager sharedManager] fetchAccessoriesForMainCategoryID:self.ad.category subCategoryID:0 limit:15 completion:^(NSArray<PetAccessory *> * _Nonnull accessories) {

        NSArray<PPUniversalCellViewModel *> *models = [self buildViewModelsFromModels:accessories];
        //NSLog(@"models %@",[models modelToJSONString]);
        [self.similarAccessView updateWithViewModels:models];
    }];
}
#pragma mark - ViewModel Builder

- (NSArray<PPUniversalCellViewModel *> *) buildViewModelsFromModels:(NSArray *)models
{
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:models.count];

    for (id model in models) {
        PPUniversalCellViewModel *vm =
        [[PPUniversalCellViewModel alloc] initWithModel:model context:PPCellForAds];
        if (vm) [result addObject:vm];
    }

    return result;
}



- (NSString *)pp_categorySummary {
    MainKindsModel *mainModel = [MainKindsModel mainKindModelForID:self.ad.category];
    if (mainModel.KindName.length > 0) {
        return mainModel.KindName;
    }
    return @"";
}

- (NSString *)pp_navigationSubtitle {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    NSString *categoryText = [self pp_categorySummary];
    NSString *subKindText =
        [SubKindModel getSubKindName:self.ad.subcategory
                 subKindsArrayLocal:[MKM getSubKindArray:self.ad.category]];

    if (categoryText.length > 0) {
        [parts addObject:categoryText];
    }
    if (subKindText.length > 0) {
        [parts addObject:subKindText];
    }
    if (parts.count == 0 && self.ad.locationName.length > 0) {
        [parts addObject:self.ad.locationName];
    }
    if (parts.count == 0) {
        return @"";
    }
    return [NSString stringWithFormat:@"(%@)", [parts componentsJoinedByString:@", "]];
}

- (UIBarButtonItem *)pp_barButtonItemWithSystemName:(NSString *)systemName
                                             action:(SEL)action
                                  accessibilityText:(NSString *)accessibilityText
{
    UIImage *image = [[UIImage systemImageNamed:systemName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithImage:image
                                                             style:UIBarButtonItemStylePlain
                                                            target:self
                                                            action:action];
    item.tintColor = AppPrimaryTextClr ?: UIColor.labelColor;
    item.accessibilityLabel = accessibilityText;
    return item;
}

- (BOOL)pp_shouldShowReportAction {
    NSString *currentUID = [self trackingUserID];
    if (currentUID.length == 0) {
        return YES;
    }
    return ![currentUID isEqualToString:self.ad.ownerID];
}






- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleDarkContent;
}
-(BOOL)prefersStatusBarHidden
{
    return NO;
}

- (void)favButtonTapped {
    NSLog(@"BUTTON ----->>>> FavoriteButton buttonTapped");
    if(!UserManager.sharedManager.isUserLoggedIn) { [UserManager showPromptOnTopController]; return; }
    [self toggleFavorite];
}
- (void)setSymbol:(NSString *)symbol
        forButton:(UIButton *)button
           filled:(BOOL)filled {

    if (!button) return;

    UIButtonConfiguration *config = button.configuration;
    if (!config) return;

    NSString *finalSymbol = filled
    ? [symbol stringByAppendingString:@".fill"]
    : symbol;

    config.image = [UIImage systemImageNamed:finalSymbol];

    // Keep symbol size consistent
    config.preferredSymbolConfigurationForImage =
    [UIImageSymbolConfiguration configurationWithPointSize:16
                                                    weight:UIImageSymbolWeightSemibold];

    // Apply back (IMPORTANT – configuration is copied)
    button.configuration = config;
}
- (void)toggleFavorite {
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }

    self.isFavorite = !self.isFavorite;

    if (self.isFavorite) {
        [self pp_updateFavoriteNavigationAppearance];
        [GM triggerHapticFeedback]; // if you have haptic util
        [PetAdManager addFavoriteAdWithID:self.ad.adID collection:@"favoritesAds" forUserID:[UserManager sharedManager].currentUser.ID];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentSuccess];
        NSLog(@"✅ Added to favorites");
    } else {
        [self pp_updateFavoriteNavigationAppearance];
        [PetAdManager removeFavoriteAdWithID:self.ad.adID collection:@"favoritesAds" forUserID:[UserManager sharedManager].currentUser.ID];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
        NSLog(@"❌ Removed from favorites");
    }

}

- (void)setupNavigation
{
    UISemanticContentAttribute semantic = [Language semanticAttributeForCurrentLanguage];
    self.view.semanticContentAttribute = semantic;
    self.navigationController.navigationBar.semanticContentAttribute = semantic;

    UIBarButtonItem *backItem =
    [[UIBarButtonItem alloc]
     initWithImage:[UIImage systemImageNamed:PPChevronName]
     style:UIBarButtonItemStylePlain
     target:self
     action:@selector(onBack)];
    backItem.accessibilityLabel = kLang(@"Back");

    _favBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"heart"]  style:UIBarButtonItemStylePlain target:self action:@selector(toggleFavorite)];
    _shareBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"heart"]  style:UIBarButtonItemStylePlain target:self action:@selector(toggleFavorite)];
    _reportBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"heart"]  style:UIBarButtonItemStylePlain target:self action:@selector(toggleFavorite)];

    self.navigationItem.leftBarButtonItem = backItem;
    self.navigationItem.rightBarButtonItem = _favBarButtonItem;

    [self pp_updateFavoriteNavigationAppearance];

}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setupNavigation];
    [self initValue];
    [self pp_refreshLocalTitleCardTexts];
    [self pp_applyViewerTheme];
    [self pp_updateContactAccessStateAnimated:NO];
}

//self.isUserContactViewUpdated
-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self pp_beginEntranceAnimationsIfNeeded];
    [self pp_startLiveMotionIfNeeded];
    if (!self.didTrackViewInteraction) {
        self.didTrackViewInteraction = YES;
        [self trackAdInteraction:PPItemInteractionTypeView];
    }
}


- (void)pp_updateFavoriteNavigationAppearance {
    UIImage *favoriteImage = [UIImage systemImageNamed:self.isFavorite ? @"heart.fill" : @"heart"];
    UIColor *favoriteColor = self.isFavorite
    ? AppPrimaryClrShiner
        : (AppPrimaryTextClr ?: UIColor.labelColor);

    self.favBarButtonItem.image = favoriteImage;
    self.favBarButtonItem.tintColor = favoriteColor;
    NSString *favoriteLabel = self.isFavorite
        ? NSLocalizedString(@"a11y_btn_unfavorite", @"Remove from favorites")
        : NSLocalizedString(@"a11y_btn_favorite", @"Favorite");
    self.favBarButtonItem.accessibilityLabel = favoriteLabel;


}


















- (IBAction)shareAdBTN:(id)sender {
    [PPAdSharingHelper sharePetAd:self.ad fromViewController:self];
    [self trackAdInteraction:PPItemInteractionTypeShare];
}

-(void)initValue
{
    if (PPCurrentUser && PPCurrentFIRAuthUser  && !self.isAdFavoritedLoaded) {
        self.isAdFavoritedLoaded = YES;
        [PetAdManager isAdFavorited:self.ad.adID
                            forUser:PPCurrentUser.ID
                         collection:@"favoritesAds"
                         completion:^(BOOL favorited) {
            self.isFavorite = favorited;
            [self pp_updateFavoriteNavigationAppearance];
        }];
    }

}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    [self pp_refreshContentSheetMetricsPreservingPosition];
    if (self.descriptionTextView && self.descriptionTextView.bounds.size.width > 0) {
        CGSize fittingSize =
        [self.descriptionTextView sizeThatFits:
         CGSizeMake(self.descriptionTextView.bounds.size.width,
                    CGFLOAT_MAX)];
        self.descriptionHeightConstraint.constant = MAX(44, fittingSize.height);
    }
    if (self.contactGradientLayer) {
        self.contactGradientLayer.frame = self.contactView.bounds;
        self.contactGradientLayer.cornerRadius = self.contactView.layer.cornerRadius;
    }
    if (self.galleryScrimLayer) {
        self.galleryScrimLayer.frame = self.galleryScrimView.bounds;
    }
    if (self.contentSurfaceGradientLayer) {
        self.contentSurfaceGradientLayer.frame = self.contentScrollView.bounds;
        self.contentSurfaceGradientLayer.cornerRadius = self.contentScrollView.layer.cornerRadius;
    }
    if (self.descriptionSurfaceGradientLayer) {
        self.descriptionSurfaceGradientLayer.frame = self.descriptionSurfaceView.bounds;
        self.descriptionSurfaceGradientLayer.cornerRadius = self.descriptionSurfaceView.layer.cornerRadius;
    }
    self.sheetGripView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.sheetGripView.bounds
                                                                     cornerRadius:self.sheetGripView.layer.cornerRadius].CGPath;
    self.titleCard.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.titleCard.bounds
                                                                 cornerRadius:self.titleCard.layer.cornerRadius].CGPath;
    self.titlePricePillView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.titlePricePillView.bounds
                                                                          cornerRadius:self.titlePricePillView.layer.cornerRadius].CGPath;
    self.descriptionSurfaceView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.descriptionSurfaceView.bounds
                                                                              cornerRadius:self.descriptionSurfaceView.layer.cornerRadius].CGPath;
    self.contactView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.contactView.bounds
                                                                    cornerRadius:self.contactView.layer.cornerRadius].CGPath;
    self.contactDockView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.contactDockView.bounds
                                                                       cornerRadius:self.contactDockView.layer.cornerRadius].CGPath;
    [self pp_updatePinnedContactInsets];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    if (self.view.window) {
        [self pp_beginEntranceAnimationsIfNeeded];
        [self pp_startLiveMotionIfNeeded];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];

    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_applyViewerTheme];
            [self.view setNeedsLayout];
        }
    }
}

#pragma mark - Motion

- (void)pp_addAmbientTranslationToView:(UIView *)view
                                   key:(NSString *)key
                                     x:(CGFloat)x
                                     y:(CGFloat)y
                              duration:(NSTimeInterval)duration
{
    if (!view || key.length == 0 || [view.layer animationForKey:key]) {
        return;
    }

    CABasicAnimation *xAnimation = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
    xAnimation.fromValue = @0.0;
    xAnimation.toValue = @(x);

    CABasicAnimation *yAnimation = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
    yAnimation.fromValue = @0.0;
    yAnimation.toValue = @(y);

    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[xAnimation, yAnimation];
    group.duration = duration;
    group.autoreverses = YES;
    group.repeatCount = HUGE_VALF;
    group.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [view.layer addAnimation:group forKey:key];
}

- (void)pp_startLiveMotionIfNeeded
{
    if (!self.sheetGripView) {
        return;
    }

    NSString *animationKey = @"pp.sheetGrip.breathing";
    if ([self.sheetGripView.layer animationForKey:animationKey]) {
        return;
    }

    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self.sheetGripView.layer removeAnimationForKey:animationKey];
        self.sheetGripView.alpha = 0.72;
        self.sheetGripView.transform = CGAffineTransformIdentity;
        return;
    }

    self.sheetGripView.alpha = 0.82;

    CABasicAnimation *scaleAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale.x"];
    scaleAnimation.fromValue = @0.92;
    scaleAnimation.toValue = @1.16;

    CABasicAnimation *opacityAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacityAnimation.fromValue = @0.44;
    opacityAnimation.toValue = @0.86;

    CABasicAnimation *liftAnimation = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
    liftAnimation.fromValue = @0.0;
    liftAnimation.toValue = @(-1.2);

    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[scaleAnimation, opacityAnimation, liftAnimation];
    group.duration = 2.4;
    group.autoreverses = YES;
    group.repeatCount = HUGE_VALF;
    group.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.sheetGripView.layer addAnimation:group forKey:animationKey];
}

- (void)pp_stopLiveMotion
{
    [self.sheetGripView.layer removeAnimationForKey:@"pp.sheetGrip.breathing"];
}

- (NSArray<UIView *> *)pp_primaryEntranceViews
{
    NSMutableArray<UIView *> *views = [NSMutableArray array];

    if (self.sheetGripContainerView) {
        [views addObject:self.sheetGripContainerView];
    }
    if (self.titleCard) {
        [views addObject:self.titleCard];
    }
    if (self.infoView) {
        [views addObject:self.infoView];
    }
    if (self.descriptionSurfaceView) {
        [views addObject:self.descriptionSurfaceView];
    }
    if (self.contactDockView) {
        [views addObject:self.contactDockView];
    }
    if (self.similarAdsView) {
        [views addObject:self.similarAdsView];
    }
    if (self.similarAccessView) {
        [views addObject:self.similarAccessView];
    }

    return views.copy;
}

- (NSArray<UIView *> *)pp_secondaryEntranceViews
{
    NSMutableArray<UIView *> *views = [NSMutableArray array];

    if (self.titleContentStack) {
        [views addObject:self.titleContentStack];
    }
    if (self.titlePricePillView) {
        [views addObject:self.titlePricePillView];
    }

    if (self.contactLockOverlayView && !self.contactLockOverlayView.hidden) {
        [views addObject:self.contactLockOverlayView];
    } else {
        if (self.contactView.avatarImageView) {
            [views addObject:self.contactView.avatarImageView];
        }
        if (self.contactView.nameLabel) {
            [views addObject:self.contactView.nameLabel];
        }
        if (self.contactView.callButton) {
            [views addObject:self.contactView.callButton];
        }
        if (self.contactView.chatButton) {
            [views addObject:self.contactView.chatButton];
        }
        if (self.contactView.whatsappButton && !self.contactView.whatsappButton.hidden) {
            [views addObject:self.contactView.whatsappButton];
        }
    }

    return views.copy;
}


- (CGFloat)pp_initialEntranceAlphaForView:(UIView *)view
                             reduceMotion:(BOOL)reduceMotion
{
    if (reduceMotion) {
        return 1.0;
    }

    if (view == self.titleCard) {
        return 0.76;
    }
    if (view == self.sheetGripContainerView) {
        return 0.34;
    }
    if (view == self.infoView) {
        return 0.42;
    }
    if (view == self.descriptionSurfaceView) {
        return 0.28;
    }
    if (view == self.titleContentStack || view == self.titlePricePillView) {
        return 0.20;
    }
    if (view == self.contactDockView) {
        return 0.12;
    }

    return 0.0;
}

- (void)pp_prepareView:(UIView *)view
      translationY:(CGFloat)translationY
             scale:(CGFloat)scale
      reduceMotion:(BOOL)reduceMotion
{
    if (!view) {
        return;
    }

    view.alpha = [self pp_initialEntranceAlphaForView:view reduceMotion:reduceMotion];
    if (reduceMotion) {
        view.transform = CGAffineTransformIdentity;
        return;
    }

    CGAffineTransform translate = CGAffineTransformMakeTranslation(0.0, translationY);
    CGAffineTransform shrink = CGAffineTransformMakeScale(scale, scale);
    view.transform = CGAffineTransformConcat(translate, shrink);
}

- (void)pp_prepareEntranceAnimationState
{
    if (self.didAnimate) {
        return;
    }

    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();

    NSArray<UIView *> *primaryViews = [self pp_primaryEntranceViews];
    [primaryViews enumerateObjectsUsingBlock:^(UIView * _Nonnull view, NSUInteger idx, BOOL * _Nonnull stop) {
        CGFloat translationY = 16.0 + MIN((CGFloat)idx * 2.0, 8.0);
        CGFloat scale = 0.985;
        if (view == self.sheetGripContainerView) {
            translationY = 3.0;
            scale = 0.98;
        } else if (view == self.titleCard) {
            translationY = 8.0;
            scale = 0.992;
        } else if (view == self.infoView) {
            translationY = 10.0;
            scale = 0.988;
        } else if (view == self.descriptionSurfaceView) {
            translationY = 8.0;
            scale = 0.992;
        } else if (view == self.contactDockView) {
            translationY = 12.0;
            scale = 0.986;
        }
        [self pp_prepareView:view
                translationY:translationY
                       scale:scale
                reduceMotion:reduceMotion];
    }];

    for (UIView *view in [self pp_secondaryEntranceViews]) {
        BOOL isTitleDetail = (view == self.titleContentStack || view == self.titlePricePillView);
        CGFloat translationY = isTitleDetail ? 5.0 : 8.0;
        CGFloat scale = isTitleDetail ? 0.992 : 0.97;
        [self pp_prepareView:view
                translationY:translationY
                       scale:scale
                reduceMotion:reduceMotion];
    }

}

- (void)pp_beginEntranceAnimationsIfNeeded
{
    if (self.didAnimate) {
        return;
    }
    self.didAnimate = YES;

    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    [self.view layoutIfNeeded];

    NSArray<UIView *> *primaryViews = [self pp_primaryEntranceViews];
    [primaryViews enumerateObjectsUsingBlock:^(UIView * _Nonnull view, NSUInteger idx, BOOL * _Nonnull stop) {
        NSTimeInterval delay = 0.08 + (0.05 * idx);
        NSTimeInterval duration = 0.28;

        if (view == self.sheetGripContainerView) {
            delay = 0.0;
            duration = 0.20;
        } else if (view == self.titleCard) {
            delay = 0.0;
            duration = 0.26;
        } else if (view == self.infoView) {
            delay = 0.03;
            duration = 0.24;
        } else if (view == self.descriptionSurfaceView) {
            delay = 0.06;
            duration = 0.26;
        } else if (view == self.contactDockView) {
            delay = 0.10;
            duration = 0.28;
        }

        if (reduceMotion) {
            [UIView animateWithDuration:0.18
                                  delay:delay
                                options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                             animations:^{
                view.alpha = 1.0;
                view.transform = CGAffineTransformIdentity;
            } completion:nil];
            return;
        }

        [UIView animateWithDuration:duration
                              delay:delay
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];

    NSArray<UIView *> *secondaryViews = [self pp_secondaryEntranceViews];
    [secondaryViews enumerateObjectsUsingBlock:^(UIView * _Nonnull view, NSUInteger idx, BOOL * _Nonnull stop) {
        BOOL isTitleDetail = (view == self.titleContentStack || view == self.titlePricePillView);
        NSTimeInterval delay = isTitleDetail ? (view == self.titleContentStack ? 0.02 : 0.055) : (0.12 + (0.04 * idx));
        NSTimeInterval duration = isTitleDetail ? 0.24 : 0.28;
        if (reduceMotion) {
            [UIView animateWithDuration:0.16
                                  delay:delay
                                options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                             animations:^{
                view.alpha = 1.0;
                view.transform = CGAffineTransformIdentity;
            } completion:nil];
            return;
        }

        [UIView animateWithDuration:duration
                              delay:delay
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

#pragma mark - Contact Access

- (void)pp_updatePinnedContactInsets
{
    if (!self.contentScrollView) {
        return;
    }

    CGFloat safeBottom = 0.0;
    if (@available(iOS 11.0, *)) {
        safeBottom = self.view.safeAreaInsets.bottom;
    }
    CGFloat bottomInset = 28.0 + safeBottom;
    UIEdgeInsets inset = self.contentScrollView.contentInset;
    inset.bottom = bottomInset;
    self.contentScrollView.contentInset = inset;

    UIEdgeInsets indicatorInset = self.contentScrollView.scrollIndicatorInsets;
    indicatorInset.bottom = bottomInset;
    self.contentScrollView.scrollIndicatorInsets = indicatorInset;
}

- (void)pp_updateContactAccessStateAnimated:(BOOL)animated
{
    BOOL isLoggedIn = UserManager.sharedManager.isUserLoggedIn;
    CGFloat contactHeight = isLoggedIn ? 88.0 : 108.0;
    self.contactViewHeightConstraint.constant = contactHeight;
    self.contactDockHeightConstraint.constant = contactHeight;
    [self pp_updatePinnedContactInsets];

    if (isLoggedIn) {
        self.contactLockOverlayView.hidden = YES;
        self.contactView.accessibilityHint = nil;
        [self pp_loadOwnerContactIfNeeded];
    } else {
        [self pp_buildGuestContactOverlayIfNeeded];
        self.contactLockOverlayView.hidden = NO;
        self.ownerModel = nil;
        self.contactView.nameLabel.text = kLang(@"Contact Advertiser");
        self.contactView.avatarImageView.image = PPSYSImage(@"person.crop.circle.fill");
        self.contactView.callButton.enabled = NO;
        self.contactView.chatButton.enabled = NO;
        self.contactView.whatsappButton.enabled = NO;
        self.contactView.callButton.alpha = 0.35;
        self.contactView.chatButton.alpha = 0.35;
        self.contactView.whatsappButton.alpha = 0.35;
        self.contactView.accessibilityHint = kLang(@"AdOwnerInfoGuestSubtitle");
    }

    [self pp_styleContactActionButtons];

    if (animated) {
        [UIView animateWithDuration:0.24 animations:^{
            [self.view layoutIfNeeded];
        }];
    } else {
        [self.view layoutIfNeeded];
    }
}

- (void)pp_buildGuestContactOverlayIfNeeded
{
    if (self.contactLockOverlayView) {
        return;
    }

    UIBlurEffect *blurEffect;
    if (@available(iOS 17.0, *)) {
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    } else {
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
    }

    self.contactLockOverlayView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    self.contactLockOverlayView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contactLockOverlayView.layer.cornerRadius = 18.0;
    self.contactLockOverlayView.layer.masksToBounds = YES;
    self.contactLockOverlayView.userInteractionEnabled = YES;
    self.contactLockOverlayView.backgroundColor = [[UIColor systemBackgroundColor] colorWithAlphaComponent:0.08];
    self.contactLockOverlayView.layer.borderWidth = 0.75;
    [self.contactLockOverlayView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.16]];

    [self.contactView addSubview:self.contactLockOverlayView];

    [NSLayoutConstraint activateConstraints:@[
        [self.contactLockOverlayView.leadingAnchor constraintEqualToAnchor:self.contactView.leadingAnchor constant:4],
        [self.contactLockOverlayView.trailingAnchor constraintEqualToAnchor:self.contactView.trailingAnchor constant:-4],
        [self.contactLockOverlayView.topAnchor constraintEqualToAnchor:self.contactView.topAnchor constant:4],
        [self.contactLockOverlayView.bottomAnchor constraintEqualToAnchor:self.contactView.bottomAnchor constant:-4],
    ]];

    UIView *contentView = self.contactLockOverlayView.contentView;

    UIView *iconBadge = [[UIView alloc] init];
    iconBadge.translatesAutoresizingMaskIntoConstraints = NO;
    iconBadge.backgroundColor = [[self pp_luxuryEmeraldColor] colorWithAlphaComponent:0.12];
    iconBadge.layer.cornerRadius = 18.0;
    [contentView addSubview:iconBadge];

    UIImageView *lockIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"lock.fill"]];
    lockIcon.translatesAutoresizingMaskIntoConstraints = NO;
    lockIcon.tintColor = [self pp_luxuryEmeraldColor];
    lockIcon.contentMode = UIViewContentModeScaleAspectFit;
    [iconBadge addSubview:lockIcon];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:14];
    titleLabel.textColor = UIColor.labelColor;
    titleLabel.textAlignment = NSTextAlignmentNatural;
    titleLabel.numberOfLines = 1;
    titleLabel.text = kLang(@"AdOwnerInfoGuestTitle");
    [contentView addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:11];
    subtitleLabel.textColor = UIColor.secondaryLabelColor;
    subtitleLabel.textAlignment = NSTextAlignmentNatural;
    subtitleLabel.numberOfLines = 2;
    subtitleLabel.text = kLang(@"AdOwnerInfoGuestSubtitle");
    [contentView addSubview:subtitleLabel];

    self.contactLockButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.contactLockButton setTitle:kLang(@"AdOwnerInfoGuestCTA") forState:UIControlStateNormal];
    [self.contactLockButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.contactLockButton.backgroundColor = [self pp_luxuryEmeraldColor];
    self.contactLockButton.layer.cornerRadius = 18.0;
    self.contactLockButton.layer.masksToBounds = YES;
    self.contactLockButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.contactLockButton.titleLabel.font = [GM boldFontWithSize:13];
    [self.contactLockButton addTarget:self action:@selector(pp_contactRegisterTapped) forControlEvents:UIControlEventTouchUpInside];
    [contentView addSubview:self.contactLockButton];
    [self pp_styleInteractiveButton:self.contactLockButton];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_contactRegisterTapped)];
    [self.contactLockOverlayView addGestureRecognizer:tap];

    [NSLayoutConstraint activateConstraints:@[
        [iconBadge.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:12],
        [iconBadge.centerYAnchor constraintEqualToAnchor:contentView.centerYAnchor],
        [iconBadge.widthAnchor constraintEqualToConstant:36],
        [iconBadge.heightAnchor constraintEqualToConstant:36],

        [lockIcon.centerXAnchor constraintEqualToAnchor:iconBadge.centerXAnchor],
        [lockIcon.centerYAnchor constraintEqualToAnchor:iconBadge.centerYAnchor],
        [lockIcon.widthAnchor constraintEqualToConstant:16],
        [lockIcon.heightAnchor constraintEqualToConstant:16],

        [self.contactLockButton.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-12],
        [self.contactLockButton.centerYAnchor constraintEqualToAnchor:contentView.centerYAnchor],
        [self.contactLockButton.heightAnchor constraintEqualToConstant:36],

        [titleLabel.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:12],
        [titleLabel.leadingAnchor constraintEqualToAnchor:iconBadge.trailingAnchor constant:12],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.contactLockButton.leadingAnchor constant:-10],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:2],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.contactLockButton.leadingAnchor constant:-10],
        [subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:contentView.bottomAnchor constant:-12],
    ]];
}

- (void)pp_contactRegisterTapped
{
    if (UserManager.sharedManager.isUserLoggedIn) {
        [self pp_updateContactAccessStateAnimated:YES];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [PPUserSigningManager presentSignInFrom:self
                                    success:^(UserModel *user) {
        __strong typeof(weakSelf) self = weakSelf;
        (void)user;
        [self pp_updateContactAccessStateAnimated:YES];
    }
                                    failure:nil
                                  cancelled:nil];
}

- (void)pp_loadOwnerContactIfNeeded
{
    if (!UserManager.sharedManager.isUserLoggedIn ||
        self.ownerModel ||
        self.isLoadingOwnerModel ||
        self.ad.ownerID.length == 0) {
        return;
    }

    self.isLoadingOwnerModel = YES;
    __weak typeof(self) weakSelf = self;
    [UsrMgr getOtherUserModelFromFirestoreWithUID:self.ad.ownerID completion:^(UserModel * _Nullable user, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        self.isLoadingOwnerModel = NO;
        if (error || !user || !UserManager.sharedManager.isUserLoggedIn) {
            return;
        }

        self.ownerModel = user;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.contactView configureWithUser:user
                                   chatCallback:^{
                [PPAnalytics logContactIntentForAd:self.ad channel:PPContactChannelChat];
                [self startChatWith:user];
            }
                                   callCallback:^{
                if (!user.MobileNo.length) {
                    [PPAlertHelper showInfoIn:self
                                        title:kLang(@"No Number")
                                     subtitle:kLang(@"This user has no phone number")];
                    return;
                }

                [PPAnalytics logContactIntentForAd:self.ad channel:PPContactChannelCall];
                [self trackAdInteraction:PPItemInteractionTypeCall];
                [AppClasses callPhoneNumber:user.MobileNo fromViewController:self];
            } whatsappCallback:^{
                [PPAnalytics logContactIntentForAd:self.ad channel:PPContactChannelWhatsapp];
                [self pp_openWhatsAppForUser:user];
            }];
            [self pp_styleContactActionButtons];

            [UIView animateWithDuration:0.26 animations:^{
                self.contactView.alpha = 1.0;
            }];
        });
    }];
}

#pragma mark - Actions

- (IBAction)callOwnerBtn:(id)sender {
    if (self.ownerModel) {
        [self trackAdInteraction:PPItemInteractionTypeCall];
        [AppClasses callPhoneNumber:self.ownerModel.MobileNo fromViewController:self];
    }
}

- (void)pp_openWhatsAppForUser:(UserModel *)user
{
    if (!user.MobileNo.length) {
        [PPAlertHelper showInfoIn:self
                            title:kLang(@"No Number")
                         subtitle:kLang(@"This user has no phone number")];
        return;
    }

    NSString *cleanNumber = [self pp_whatsAppNumberFromRawPhone:user.MobileNo];
    if (cleanNumber.length == 0) {
        [PPAlertHelper showInfoIn:self
                            title:kLang(@"No Number")
                         subtitle:kLang(@"This user has no phone number")];
        return;
    }

    [self trackAdInteraction:PPItemInteractionTypeChat];
    [AppClasses startWhatsAppWith:cleanNumber fromViewController:self];
}

- (NSString *)pp_whatsAppNumberFromRawPhone:(NSString *)rawPhone
{
    NSString *trimmed = [rawPhone stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length == 0) {
        return @"";
    }

    NSMutableString *clean = [NSMutableString string];
    NSCharacterSet *digits = NSCharacterSet.decimalDigitCharacterSet;
    for (NSUInteger idx = 0; idx < trimmed.length; idx++) {
        unichar character = [trimmed characterAtIndex:idx];
        if (character == '+' && clean.length == 0) {
            [clean appendString:@"+"];
            continue;
        }
        if ([digits characterIsMember:character]) {
            [clean appendFormat:@"%C", character];
        }
    }
    return [clean stringByReplacingOccurrencesOfString:@"+" withString:@""];
}

- (void)handleShareAction  {
    [PPAdSharingHelper sharePetAd:self.ad fromViewController:self];
    [self trackAdInteraction:PPItemInteractionTypeShare];
}



#pragma mark - Chat Methods
- (void)startChatWith:(UserModel *)user
{
    NSLog(@"💬 [Chat] Start chat requested with userID=%@", user.ID);

    [ChManager.sharedManager createOrGetChatThreadWithUser:user
                                                completion:^(ChatThreadModel * _Nullable thread,
                                                             NSError * _Nullable error)
    {
        if (error) {
            NSLog(@"❌ [Chat] Failed to create/get chat thread for userID=%@ | error=%@",
                  user.ID,
                  error.localizedDescription);
            return;
        }

        if (!thread) {
            NSLog(@"⚠️ [Chat] Thread is nil for userID=%@", user.ID);
            return;
        }

        NSLog(@"✅ [Chat] Thread ready | threadID=%@ | messagesCount=%ld",
              thread.ID,
              (long)thread.messagesCount);

        [self trackAdInteraction:PPItemInteractionTypeChat];

        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"➡️ [Chat] Opening chat UI for threadID=%@", thread.ID);

            // Coordinator is optional here, but keeping for consistency
            //PPOverlayCoordinator *over = [[PPOverlayCoordinator alloc] initWithPresenter:self];
            [PPOverlayCoordinator pp_openChatThread:thread fromVC:self];
        });
    }];
}


#pragma mark - Memory Management

- (void)dealloc {
    // Clean up any observers or timers if needed
}

- (NSString *)trackingUserID {
    NSString *userID = [UserManager sharedManager].currentUser.ID;
    if (userID.length > 0) {
        return userID;
    }
    if (PPCurrentFIRAuthUser.uid.length > 0) {
        return PPCurrentFIRAuthUser.uid;
    }
    return nil;
}

- (void)trackAdInteraction:(PPItemInteractionType)interaction {
    if (self.ad.adID.length == 0) return;
    [PetAdManager trackInteraction:interaction
                         forItemID:self.ad.adID
                        collection:kPetAdsCollection
                            userID:[self trackingUserID]
                        completion:nil];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self pp_stopLiveMotion];

}

- (UIButton *)pp_makeGlassCircleButtonWithSymbol:(NSString *)symbol
                                          action:(SEL)action {

    UIButtonConfiguration *config;

    if (@available(iOS 26.0, *)) {
        config = [UIButtonConfiguration glassButtonConfiguration];
        config.baseForegroundColor = UIColor.whiteColor;
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    } else {
        config = [UIButtonConfiguration filledButtonConfiguration];
        config.baseForegroundColor = UIColor.whiteColor;
        config.baseBackgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.20];
        UIBackgroundConfiguration *background = config.background;
        background.visualEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark];
        background.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.22];
        background.strokeWidth = 0.8;
        config.background = background;
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    }

    config.image = [UIImage systemImageNamed:symbol];
    config.preferredSymbolConfigurationForImage =
    [UIImageSymbolConfiguration configurationWithPointSize:16.5
                                                    weight:UIImageSymbolWeightSemibold];
    config.contentInsets = NSDirectionalEdgeInsetsMake(12.0, 12.0, 12.0, 12.0);

    UIButton *btn =
    [UIButton buttonWithConfiguration:config primaryAction:nil];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.clipsToBounds = NO;
    btn.adjustsImageWhenHighlighted = YES;

    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];

    [NSLayoutConstraint activateConstraints:@[
        [btn.widthAnchor constraintEqualToConstant:46],
        [btn.heightAnchor constraintEqualToConstant:46],
    ]];

    return btn;
}

- (void)pp_styleInteractiveButton:(UIButton *)button
{
    if (!button) {
        return;
    }

    if (button == self.descriptionToggleButton) {
        button.layer.shadowOpacity = 0.0;
        button.layer.borderWidth = 0.0;
        [button pp_setBorderColor:UIColor.clearColor];
        [button removeTarget:self action:@selector(pp_interactiveButtonTouchDown:) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
        [button removeTarget:self action:@selector(pp_interactiveButtonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
        [button addTarget:self action:@selector(pp_interactiveButtonTouchDown:) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
        [button addTarget:self action:@selector(pp_interactiveButtonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
        return;
    }

    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
    button.layer.masksToBounds = NO;
    [button pp_setShadowColor:UIColor.blackColor];
    button.layer.shadowOpacity = 0.18;
    button.layer.shadowRadius = 18.0;
    button.layer.shadowOffset = CGSizeMake(0, 10);
    button.layer.borderWidth = 0.75;
    [button pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.16]];

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = button.configuration;
        if (config) {
            UIBackgroundConfiguration *background = config.background;
            if (button == self.contactLockButton) {
                background.backgroundColor = [self pp_luxuryEmeraldColor];
                background.visualEffect = nil;
                background.strokeColor = UIColor.clearColor;
                background.strokeWidth = 0.0;
                config.baseForegroundColor = UIColor.whiteColor;
            }
            config.background = background;
            button.configuration = config;
        }
    }

    [button removeTarget:self action:@selector(pp_interactiveButtonTouchDown:) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
    [button removeTarget:self action:@selector(pp_interactiveButtonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
    [button addTarget:self action:@selector(pp_interactiveButtonTouchDown:) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
    [button addTarget:self action:@selector(pp_interactiveButtonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
}

- (void)pp_styleContactActionButtons
{
    UIButton *callButton = self.contactView.callButton;
    UIButton *chatButton = self.contactView.chatButton;
    BOOL compactActions = self.contactView.whatsappButton && !self.contactView.whatsappButton.hidden;

    if (callButton) {
        [callButton setTitle:compactActions ? nil : kLang(@"Call") forState:UIControlStateNormal];
        callButton.semanticContentAttribute = GM.setSemantic;
        [self pp_attachPressFeedbackToButton:callButton];
    }
    if (chatButton) {
        [chatButton setTitle:compactActions ? nil : kLang(@"Chat") forState:UIControlStateNormal];
        chatButton.semanticContentAttribute = GM.setSemantic;
        [self pp_attachPressFeedbackToButton:chatButton];
    }
    if (self.contactView.whatsappButton) {
        [self.contactView.whatsappButton setTitle:compactActions ? nil : kLang(@"WhatsApp") forState:UIControlStateNormal];
        self.contactView.whatsappButton.semanticContentAttribute = GM.setSemantic;
        [self pp_attachPressFeedbackToButton:self.contactView.whatsappButton];
    }
}

- (void)pp_attachPressFeedbackToButton:(UIButton *)button
{
    [button removeTarget:self action:@selector(pp_interactiveButtonTouchDown:) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
    [button removeTarget:self action:@selector(pp_interactiveButtonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
    [button addTarget:self action:@selector(pp_interactiveButtonTouchDown:) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
    [button addTarget:self action:@selector(pp_interactiveButtonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
}

- (void)pp_interactiveButtonTouchDown:(UIButton *)sender
{
    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    [UIView animateWithDuration:0.10
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                     animations:^{
        sender.transform = reduceMotion ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.96, 0.96);
        sender.alpha = 0.94;
    } completion:nil];
}

- (void)pp_interactiveButtonTouchUp:(UIButton *)sender
{
    [UIView animateWithDuration:0.22
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                     animations:^{
        sender.transform = CGAffineTransformIdentity;
        sender.alpha = 1.0;
    } completion:nil];
}

- (CGFloat)pp_unitProgressForValue:(CGFloat)value
{
    return MIN(MAX(value, 0.0), 1.0);
}

- (CGFloat)pp_smoothedScrollProgress:(CGFloat)progress
{
    CGFloat p = [self pp_unitProgressForValue:progress];
    return p * p * (3.0 - (2.0 * p));
}

- (CGFloat)pp_viewerScreenHeightForSheetMetrics
{
    CGFloat screenHeight = CGRectGetHeight(self.view.bounds);
    if (screenHeight <= 0.0) {
        screenHeight = UIScreen.mainScreen.bounds.size.height;
    }
    return MAX(screenHeight, 1.0);
}

- (CGFloat)pp_visibleTitleCardHeight
{
    CGFloat height = CGRectGetHeight(self.titleCard.bounds);
    if (height <= 1.0 && self.titleCard) {
        CGSize fittingSize = [self.titleCard systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
        height = fittingSize.height;
    }
    return MIN(MAX(height, 76.0), 132.0);
}

- (CGFloat)pp_navigationStopHeight
{
    CGFloat safeTop = 0.0;
    if (@available(iOS 11.0, *)) {
        safeTop = self.view.safeAreaInsets.top;
    }

    CGFloat navHeight = 0.0;
    if (self.navigationController && !self.navigationController.navigationBarHidden) {
        navHeight = CGRectGetHeight(self.navigationController.navigationBar.bounds);
    }
    if (navHeight <= 0.0) {
        navHeight = 44.0;
    }

    return safeTop + navHeight + [self pp_visibleTitleCardHeight] + 10.0;
}

- (CGFloat)pp_contentSheetExpandedTopConstantForHeroHeight:(CGFloat)heroHeight
{
    CGFloat screenHeight = [self pp_viewerScreenHeightForSheetMetrics];
    CGFloat targetSheetHeight = screenHeight * [self pp_unitProgressForValue:kViewerVcMetaSheetHeight];
    CGFloat targetSheetTop = screenHeight - targetSheetHeight;
    CGFloat expandedConstant = targetSheetTop - heroHeight;
    return MIN(self.contentSheetRestingTopConstant, expandedConstant);
}

- (CGFloat)pp_currentContentSheetProgress
{
    CGFloat travel = self.contentSheetRestingTopConstant - self.contentSheetExpandedTopConstant;
    if (travel <= 0.0 || !self.contentSheetTopConstraint) {
        return 0.0;
    }
    return [self pp_unitProgressForValue:(self.contentSheetRestingTopConstant - self.contentSheetTopConstraint.constant) / travel];
}

- (CGFloat)pp_clampedContentSheetConstant:(CGFloat)constant
{
    CGFloat lowerBound = MIN(self.contentSheetExpandedTopConstant, self.contentSheetRestingTopConstant);
    CGFloat upperBound = MAX(self.contentSheetExpandedTopConstant, self.contentSheetRestingTopConstant);
    return MIN(MAX(constant, lowerBound), upperBound);
}

- (void)pp_setContentSheetTopConstant:(CGFloat)constant
{
    if (!self.contentSheetTopConstraint) {
        return;
    }

    CGFloat clampedConstant = [self pp_clampedContentSheetConstant:constant];
    self.contentSheetTopConstraint.constant = clampedConstant;

    CGFloat progress = [self pp_smoothedScrollProgress:[self pp_currentContentSheetProgress]];
    self.contentScrollView.layer.cornerRadius = 22.0 + (progress * 12.0);
}

- (void)pp_refreshContentSheetMetricsPreservingPosition
{
    CGFloat progress = [self pp_currentContentSheetProgress];
    CGFloat heroHeight = [self pp_heroHeight];
    self.galleryMaxHeight = heroHeight;
    self.heroHeightConstraint.constant = heroHeight;
    self.contentSheetRestingTopConstant = -24.0;
    self.contentSheetExpandedTopConstant = [self pp_contentSheetExpandedTopConstantForHeroHeight:heroHeight];

    CGFloat travel = self.contentSheetRestingTopConstant - self.contentSheetExpandedTopConstant;
    CGFloat targetConstant = self.contentSheetRestingTopConstant - (travel * progress);
    [self pp_setContentSheetTopConstant:targetConstant];
}

- (void)pp_updateHeroDepthForScrollOffset:(CGFloat)offsetY
{
    if (!self.contentSheetTopConstraint || self.isUpdatingContentSheetFromScroll) {
        return;
    }

    self.galleryScrimView.hidden = YES;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.galleryScrimLayer.colors = @[
        (__bridge id)[UIColor.clearColor CGColor],
        (__bridge id)[UIColor.clearColor CGColor]
    ];
    self.galleryScrimLayer.locations = @[@0.0, @1.0];
    [CATransaction commit];

    CGFloat topInset = 0.0;
    if (@available(iOS 11.0, *)) {
        topInset = self.contentScrollView.adjustedContentInset.top;
    }
    CGFloat normalizedOffset = offsetY + topInset;
    CGFloat currentConstant = self.contentSheetTopConstraint.constant;

    if (normalizedOffset > 0.0 && currentConstant > self.contentSheetExpandedTopConstant + 0.5) {
        CGFloat availableTravel = currentConstant - self.contentSheetExpandedTopConstant;
        CGFloat consumedOffset = MIN(normalizedOffset, availableTravel);
        CGFloat remainingOffset = normalizedOffset - consumedOffset;

        self.isUpdatingContentSheetFromScroll = YES;
        [self pp_setContentSheetTopConstant:currentConstant - consumedOffset];
        self.contentScrollView.contentOffset = CGPointMake(self.contentScrollView.contentOffset.x,
                                                           -topInset + MAX(remainingOffset, 0.0));
        [self.view layoutIfNeeded];
        self.isUpdatingContentSheetFromScroll = NO;
        return;
    }

    if (normalizedOffset < 0.0 && currentConstant < self.contentSheetRestingTopConstant - 0.5) {
        CGFloat availableTravel = self.contentSheetRestingTopConstant - currentConstant;
        CGFloat consumedOffset = MIN(fabs(normalizedOffset), availableTravel);

        self.isUpdatingContentSheetFromScroll = YES;
        [self pp_setContentSheetTopConstant:currentConstant + consumedOffset];
        self.contentScrollView.contentOffset = CGPointMake(self.contentScrollView.contentOffset.x, -topInset);
        [self.view layoutIfNeeded];
        self.isUpdatingContentSheetFromScroll = NO;
        return;
    }

    [self pp_setContentSheetTopConstant:currentConstant];
}

- (void)pp_snapContentSheetWithVelocity:(CGFloat)velocityY
{
    if (!self.contentSheetTopConstraint) {
        return;
    }

    CGFloat progress = [self pp_currentContentSheetProgress];
    if (progress <= 0.02 || progress >= 0.98) {
        CGFloat target = progress >= 0.5 ? self.contentSheetExpandedTopConstant : self.contentSheetRestingTopConstant;
        [self pp_setContentSheetTopConstant:target];
        return;
    }

    BOOL shouldExpand = fabs(velocityY) > 0.08 ? (velocityY > 0.0) : (progress >= 0.5);
    CGFloat targetConstant = shouldExpand ? self.contentSheetExpandedTopConstant : self.contentSheetRestingTopConstant;
    NSTimeInterval duration = UIAccessibilityIsReduceMotionEnabled() ? 0.16 : 0.48;
    CGFloat springVelocity = MIN(fabs(velocityY) / 8.0, 1.0);

    self.isUpdatingContentSheetFromScroll = YES;
    [UIView animateWithDuration:duration
                          delay:0.0
         usingSpringWithDamping:UIAccessibilityIsReduceMotionEnabled() ? 1.0 : 0.80
          initialSpringVelocity:springVelocity
                        options:UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        [self pp_setContentSheetTopConstant:targetConstant];
        [self.view layoutIfNeeded];
    } completion:^(__unused BOOL finished) {
        self.isUpdatingContentSheetFromScroll = NO;
    }];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView != self.contentScrollView) {
        return;
    }

    [self pp_updateHeroDepthForScrollOffset:scrollView.contentOffset.y];
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView
                      withVelocity:(CGPoint)velocity
               targetContentOffset:(inout CGPoint *)targetContentOffset
{
    if (scrollView != self.contentScrollView || !self.contentSheetTopConstraint) {
        return;
    }

    CGFloat progress = [self pp_currentContentSheetProgress];
    if (progress > 0.02 && progress < 0.98) {
        CGFloat topInset = 0.0;
        if (@available(iOS 11.0, *)) {
            topInset = scrollView.adjustedContentInset.top;
        }
        targetContentOffset->y = -topInset;
        [self pp_snapContentSheetWithVelocity:velocity.y];
    }
}

#pragma mark - Description Styling Helper

- (NSString *)pp_normalizedDescriptionText:(NSString *)text
{
    NSString *trimmed = [PPSafeString(text) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length == 0) {
        return @"";
    }

    NSMutableArray<NSString *> *paragraphs = [NSMutableArray array];
    for (NSString *line in [trimmed componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
        NSString *cleanLine = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (cleanLine.length > 0) {
            [paragraphs addObject:cleanLine];
        }
    }

    if (paragraphs.count > 1) {
        return [paragraphs componentsJoinedByString:@"\n\n"];
    }

    if (trimmed.length < 190) {
        return trimmed;
    }

    NSMutableString *balanced = [NSMutableString string];
    __block NSUInteger lastBreak = 0;
    NSCharacterSet *sentenceEnders = [NSCharacterSet characterSetWithCharactersInString:@".!?؟،"];
    [trimmed enumerateSubstringsInRange:NSMakeRange(0, trimmed.length)
                                options:NSStringEnumerationByComposedCharacterSequences
                             usingBlock:^(NSString * _Nullable substring, NSRange substringRange, NSRange enclosingRange, BOOL * _Nonnull stop) {
        (void)enclosingRange;
        if (!substring) {
            return;
        }
        [balanced appendString:substring];
        if ([substring rangeOfCharacterFromSet:sentenceEnders].location != NSNotFound &&
            substringRange.location - lastBreak > 135 &&
            substringRange.location + 1 < trimmed.length) {
            [balanced appendString:@"\n\n"];
            lastBreak = substringRange.location;
        }
    }];

    return balanced.copy;
}

- (NSString *)pp_visibleDescriptionText
{
    if (self.fullDescriptionText.length == 0) {
        return kLang(@"No description added for this pet.");
    }
    if (!self.shouldCollapseDescription || self.isDescriptionExpanded) {
        return self.fullDescriptionText;
    }

    NSUInteger maxLength = MIN((NSUInteger)220, self.fullDescriptionText.length);
    NSString *prefix = [self.fullDescriptionText substringToIndex:maxLength];
    NSRange lastSpace = [prefix rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet
                                                options:NSBackwardsSearch];
    if (lastSpace.location != NSNotFound && lastSpace.location > 120) {
        prefix = [prefix substringToIndex:lastSpace.location];
    }
    return [prefix stringByAppendingString:@"..."];
}

- (void)pp_refreshDescriptionTextAnimated:(BOOL)animated
{
    NSAttributedString *updatedText = [self pp_styledDescriptionFromText:[self pp_visibleDescriptionText]];
    void (^updates)(void) = ^{
        self.descriptionTextView.attributedText = updatedText;
        NSString *toggleTitle = self.isDescriptionExpanded ? kLang(@"ShowLess") : kLang(@"ReadMore");
        [self.descriptionToggleButton setTitle:toggleTitle forState:UIControlStateNormal];
        self.descriptionToggleButton.alpha = self.shouldCollapseDescription ? 1.0 : 0.0;
        self.descriptionToggleHeightConstraint.constant = self.shouldCollapseDescription ? 34.0 : 0.0;
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    };

    if (!animated) {
        updates();
        return;
    }

    [UIView transitionWithView:self.descriptionTextView
                      duration:UIAccessibilityIsReduceMotionEnabled() ? 0.16 : 0.28
                       options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                    animations:updates
                    completion:nil];
}

- (void)pp_performReadMoreHeroPulse
{
    if (self.isHeroReadMorePulseActive || UIAccessibilityIsReduceMotionEnabled() || !self.descriptionSurfaceView) {
        [self pp_updateHeroDepthForScrollOffset:self.contentScrollView.contentOffset.y];
        return;
    }

    self.isHeroReadMorePulseActive = YES;
    CGFloat originalAlpha = self.descriptionSurfaceView.alpha > 0.0 ? self.descriptionSurfaceView.alpha : 1.0;

    [UIView animateKeyframesWithDuration:0.34
                                   delay:0.0
                                 options:UIViewKeyframeAnimationOptionBeginFromCurrentState |
                                         UIViewAnimationOptionAllowUserInteraction |
                                         UIViewKeyframeAnimationOptionCalculationModeCubic
                              animations:^{
        [UIView addKeyframeWithRelativeStartTime:0.0
                                relativeDuration:0.38
                                      animations:^{
            self.descriptionSurfaceView.alpha = MAX(originalAlpha * 0.92, 0.82);
        }];
        [UIView addKeyframeWithRelativeStartTime:0.38
                                relativeDuration:0.62
                                      animations:^{
            self.descriptionSurfaceView.alpha = originalAlpha;
        }];
    } completion:^(__unused BOOL finished) {
        self.isHeroReadMorePulseActive = NO;
        [self pp_updateHeroDepthForScrollOffset:self.contentScrollView.contentOffset.y];
    }];
}

- (void)pp_toggleDescriptionExpanded:(UIButton *)sender
{
    (void)sender;
    if (!self.shouldCollapseDescription) {
        return;
    }
    self.isDescriptionExpanded = !self.isDescriptionExpanded;
    [self pp_performReadMoreHeroPulse];
    [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0.16 : 0.28
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        [self pp_refreshDescriptionTextAnimated:NO];
    } completion:nil];
}

- (NSAttributedString *)pp_styledDescriptionFromText:(NSString *)text {

    UIFont *bodyFont = [GM MidFontWithSize:17];
    UIColor *textColor = [self pp_luxuryTextColor];
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineSpacing = 7.0;
    paragraphStyle.paragraphSpacing = 13.0;
    paragraphStyle.alignment = NSTextAlignmentNatural;
    paragraphStyle.baseWritingDirection = Language.isRTL ? NSWritingDirectionRightToLeft : NSWritingDirectionLeftToRight;

    NSMutableAttributedString *attr =
    [[NSMutableAttributedString alloc] initWithString:text ?: @""];

    [attr addAttributes:@{
        NSFontAttributeName: bodyFont,
        NSForegroundColorAttributeName: textColor,
        NSParagraphStyleAttributeName: paragraphStyle
    } range:NSMakeRange(0, attr.length)];

    // Detect links automatically
    NSDataDetector *detector =
    [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:nil];

    [detector enumerateMatchesInString:attr.string
                               options:0
                                 range:NSMakeRange(0, attr.length)
                            usingBlock:^(NSTextCheckingResult *result,
                                         NSMatchingFlags flags,
                                         BOOL *stop) {

        if (result.resultType == NSTextCheckingTypeLink) {
            [attr addAttributes:@{
                NSForegroundColorAttributeName: [self pp_luxuryEmeraldColor],
                NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle)
            } range:result.range];
        }
    }];

    // Very light markdown: **bold**
    NSRegularExpression *boldRegex =
    [NSRegularExpression regularExpressionWithPattern:@"\\*\\*(.*?)\\*\\*"
                                              options:0 error:nil];

    NSArray *matches =
    [boldRegex matchesInString:attr.string
                       options:0
                         range:NSMakeRange(0, attr.length)];

    for (NSTextCheckingResult *match in matches.reverseObjectEnumerator) {
        NSRange boldRange = [match rangeAtIndex:1];
        [attr addAttribute:NSFontAttributeName
                     value:[UIFont boldSystemFontOfSize:bodyFont.pointSize]
                     range:boldRange];

        // Remove ** markers
        [attr replaceCharactersInRange:NSMakeRange(match.range.location, 2)
                            withString:@""];
        [attr replaceCharactersInRange:NSMakeRange(match.range.location + boldRange.length, 2)
                            withString:@""];
    }

    return attr;
}


#pragma mark - Report Ad

- (void)reportAdBTN:(id)sender {
    if (![UserManager sharedManager].isUserLoggedIn) {
         [UserManager showPromptOnTopController];
        return;
    }

    NSString *currentUID = [self trackingUserID];
    if ([currentUID isEqualToString:self.ad.ownerID]) {
        return;
    }

    UIAlertController *sheet = [UIAlertController
        alertControllerWithTitle:kLang(@"report_alert_title")
        message:kLang(@"report_alert_message")
        preferredStyle:UIAlertControllerStyleActionSheet];

    NSDictionary *reasons = @{
        @"inappropriate_content": kLang(@"report_reason_inappropriate"),
        @"scam_fraud": kLang(@"report_reason_fraud"),
        @"wrong_category": kLang(@"report_reason_wrong_category"),
        @"spam": kLang(@"report_reason_spam"),
        @"other": kLang(@"report_reason_other")
    };

    for (NSString *code in @[@"inappropriate_content", @"scam_fraud", @"wrong_category", @"spam", @"other"]) {
        [sheet addAction:[UIAlertAction actionWithTitle:reasons[code]
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *action) {
                [self submitAdReportWithReason:code collection:kPetAdsCollection documentID:self.ad.adID];
            }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"cancel")
        style:UIAlertActionStyleCancel handler:nil]];

    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        if ([sender isKindOfClass:UIBarButtonItem.class]) {
            sheet.popoverPresentationController.barButtonItem = (UIBarButtonItem *)sender;
        } else {
            UIView *sourceView = [sender isKindOfClass:UIView.class] ? (UIView *)sender : self.view;
            sheet.popoverPresentationController.sourceView = sourceView;
            sheet.popoverPresentationController.sourceRect = sourceView.bounds;
        }
    }

    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)submitAdReportWithReason:(NSString *)reason
                      collection:(NSString *)collection
                      documentID:(NSString *)docID {
    if (docID.length == 0) return;

    NSString *currentUID = [self trackingUserID];
    if (currentUID.length == 0) return;

    FIRFirestore *db = [FIRFirestore firestore];

    // 1. Flag on the content document (array-union for multi-reporter support)
    FIRDocumentReference *docRef =
        [[db collectionWithPath:collection] documentWithPath:docID];

    [docRef updateData:@{
        @"reportedBy"    : [FIRFieldValue fieldValueForArrayUnion:@[currentUID]],
        @"reportCount"   : [FIRFieldValue fieldValueForIntegerIncrement:1],
        @"lastReportedAt": [FIRFieldValue fieldValueForServerTimestamp]
    } completion:nil];

    // 2. Write a dedicated report document for audit trail
    NSString *reportID = [NSString stringWithFormat:@"%@_%@", docID, currentUID];
    FIRDocumentReference *reportRef = [[db collectionWithPath:@"reports"] documentWithPath:reportID];

    NSDictionary *reportData = @{
        @"reportId"         : reportID,
        @"contentId"        : docID,
        @"contentType"      : @"pet_ad",
        @"collection"       : collection,
        @"reason"           : reason,
        @"reporterUid"      : currentUID,
        @"reportedOwnerUid" : self.ad.ownerID ?: @"",
        @"status"           : @"pending",
        @"platform"         : @"ios",
        @"createdAt"        : [FIRFieldValue fieldValueForServerTimestamp],
        @"updatedAt"        : [FIRFieldValue fieldValueForServerTimestamp]
    };

    [reportRef setData:reportData merge:YES completion:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [GM showAlertWithTitle:kLang(@"Error") message:kLang(@"report_submit_failed_message") imageName:@"" inViewController:self];
            } else {
                [PPAlertHelper showSuccessIn:self title:kLang(@"report_submit_title") subtitle:kLang(@"report_submit_message")];
            }
        });
    }];
}



@end
