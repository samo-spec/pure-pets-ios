//
//  SellerProfileVC.m
//  Pure Pets
//
//  Minimal premium seller profile UI
//

#import "SellerProfileVC.h"
#import "AccessViewerVC.h"
#import "CartManager.h"
#import "CartViewController.h"
#import "PetAccessory.h"
#import "PetAccessoryManager.h"
#import "PPFunc.h"
#import "PPHUD.h"
#import "PPHomeCartNavButton.h"
#import "PPRootTabBarController.h"
#import "PPUniversalCell.h"
#import "PPUniversalCellViewModel.h"
#import "PPImageLoaderManager.h"
#import "PPMarketplaceHeroCardStyle.h"
#import "PPModernAvatarRenderer.h"
#import "UIViewController+PPBottomSurface.h"
#import "PPBackgroundView.h"
#import <QuartzCore/QuartzCore.h>
@import FirebaseAuth;
@import FirebaseFirestore;
@import FirebaseFunctions;

static CGFloat SPSellerBottomNavigationClearanceForController(UIViewController *controller)
{
    if (!controller || !controller.tabBarController || CGRectIsEmpty(controller.view.bounds)) {
        return 0.0;
    }

    UITabBarController *tabBarController = controller.tabBarController;
    SEL clearanceSelector = NSSelectorFromString(@"pp_bottomNavigationContentClearance");
    if ([tabBarController respondsToSelector:clearanceSelector]) {
        CGFloat (*clearanceIMP)(id, SEL) = (CGFloat (*)(id, SEL))[tabBarController methodForSelector:clearanceSelector];
        CGFloat rootClearance = clearanceIMP ? clearanceIMP(tabBarController, clearanceSelector) : 0.0;
        if (rootClearance > 0.0) {
            return ceil(rootClearance);
        }
    }

    UIView *bottomNavigationView = nil;
    SEL anchorSelector = NSSelectorFromString(@"pp_novaAmbientBottomNavigationAnchorView");
    if ([tabBarController respondsToSelector:anchorSelector]) {
        UIView *(*anchorIMP)(id, SEL) = (UIView *(*)(id, SEL))[tabBarController methodForSelector:anchorSelector];
        bottomNavigationView = anchorIMP ? anchorIMP(tabBarController, anchorSelector) : nil;
    }
    if (!bottomNavigationView && !tabBarController.tabBar.hidden && tabBarController.tabBar.alpha > 0.01) {
        bottomNavigationView = tabBarController.tabBar;
    }
    if (!bottomNavigationView ||
        bottomNavigationView.hidden ||
        bottomNavigationView.alpha <= 0.01 ||
        !bottomNavigationView.superview) {
        return 0.0;
    }

    CGRect navigationFrame = [bottomNavigationView.superview convertRect:bottomNavigationView.frame
                                                                  toView:controller.view];
    if (CGRectIsEmpty(navigationFrame)) {
        return 0.0;
    }

    CGFloat safeBottomY = CGRectGetMaxY(controller.view.bounds) - controller.view.safeAreaInsets.bottom;
    CGFloat overlapAboveSafeArea = MAX(0.0, safeBottomY - CGRectGetMinY(navigationFrame));
    return ceil(overlapAboveSafeArea + 12.0);
}

static const CGFloat kSPSpace4 = 4.0;
static const CGFloat kSPSpace8 = 8.0;
static const CGFloat kSPSpace12 = 12.0;
static const CGFloat kSPSpace16 = 16.0;
static const CGFloat kSPSpace20 = 20.0;
static const CGFloat kSPSpace24 = 24.0;
static const CGFloat kSPSpace32 = 32.0;
static const CGFloat kSPAvatarSize = 66.0;
static const CGFloat kSPAvatarShellSize = 82.0;
static const CGFloat kSPAvatarHaloSize = 98.0;
static const CGFloat kSPSurfaceCornerRadius = 30.0;
static const CGFloat kSPButtonHeight = 44.0;

static UIColor *SPSellerInkColor(void) {
    return AppPrimaryClr ?: [UIColor colorWithWhite:0.08 alpha:1.0];
}

static UIColor *SPSellerSecondaryTextColor(void) {
    return AppSecondaryTextClr ?: [UIColor colorWithWhite:0.42 alpha:1.0];
}

static UIColor *SPSellerSurfaceColor(UITraitCollection *traitCollection) {
    if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        return [UIColor colorWithWhite:0.105 alpha:1.0];
    }
    return [AppForgroundColr colorWithAlphaComponent:0.7] ?: UIColor.whiteColor;
}

static UIColor *SPSellerAppForegroundColor(UITraitCollection *traitCollection) {
    UIColor *foreground = AppForgroundColr;
    if (foreground) {
        return foreground;
    }
    if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        return [UIColor colorWithWhite:0.115 alpha:1.0];
    }
    return UIColor.systemBackgroundColor;
}

static UIColor *SPSellerBackgroundColor(UITraitCollection *traitCollection) {
    if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        return [UIColor colorWithWhite:0.055 alpha:1.0];
    }
    UIColor *appBackground = AppBackgroundClr;
    return appBackground ?: [UIColor colorWithRed:0.982 green:0.976 blue:0.956 alpha:1.0];
}

static UIColor *SPSellerAccentTealColor(void) {
    return [AppPrimaryClr colorWithAlphaComponent:1.0];
}

static UIColor *SPSellerGoldColor(void) {
    return [UIColor colorWithRed:0.78 green:0.62 blue:0.30 alpha:1.0];
}

static UIColor *SPSellerRoseColor(void) {
    return [UIColor colorWithRed:0.72 green:0.28 blue:0.34 alpha:1.0];
}

typedef NS_ENUM(NSInteger, SPSellerHeroActionRole) {
    SPSellerHeroActionRolePrimary = 0,
    SPSellerHeroActionRoleSecondary,
    SPSellerHeroActionRoleTertiary
};

static UIColor *SPSellerBrandAccentColor(void) {
    return AppPrimaryClr ?: [UIColor colorWithRed:0.88 green:0.02 blue:0.30 alpha:1.0];
}

static UIColor *SPSellerHeroAvatarShellColor(UITraitCollection *traitCollection) {
    BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    if (dark) {
        return [UIColor colorWithWhite:1.0 alpha:0.080];
    }
    return [SPSellerAppForegroundColor(traitCollection) colorWithAlphaComponent:0.98];
}

static UIColor *SPSellerHeroAvatarStrokeColor(UITraitCollection *traitCollection) {
    BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    return [SPSellerBrandAccentColor() colorWithAlphaComponent:dark ? 0.28 : 0.18];
}

static NSString *SPSellerNormalizedCategoryIdentifier(NSString *identifier)
{
    return [[PPSafeString(identifier) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
}

static BOOL SPSellerIsPharmacyCategory(NSString *identifier)
{
    return [SPSellerNormalizedCategoryIdentifier(identifier) isEqualToString:@"pharmacy"];
}

@interface SPSellerAmbientGlowView : UIView
@property (nonatomic, strong) CAGradientLayer *radialLayer;
@property (nonatomic, assign, getter=isFaded) BOOL faded;
- (void)applyColor:(UIColor *)color
         peakAlpha:(CGFloat)peakAlpha
       middleAlpha:(CGFloat)middleAlpha;
@end

@implementation SPSellerAmbientGlowView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.userInteractionEnabled = NO;
    self.isAccessibilityElement = NO;
    self.accessibilityElementsHidden = YES;
    self.backgroundColor = UIColor.clearColor;
    self.opaque = NO;
    self.faded = NO;

    _radialLayer = [CAGradientLayer layer];
    if (@available(iOS 12.0, *)) {
        _radialLayer.type = kCAGradientLayerRadial;
        _radialLayer.startPoint = CGPointMake(0.5, 0.5);
        _radialLayer.endPoint = CGPointMake(1.0, 1.0);
    } else {
        _radialLayer.startPoint = CGPointMake(0.0, 0.5);
        _radialLayer.endPoint = CGPointMake(1.0, 0.5);
    }
    _radialLayer.locations = @[@0.0, @0.46, @1.0];
    _radialLayer.drawsAsynchronously = YES;
    [self.layer addSublayer:_radialLayer];
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.layer.cornerRadius = CGRectGetWidth(self.bounds) * 0.5;
    self.layer.masksToBounds = !self.isFaded;
    self.radialLayer.frame = self.bounds;
    [CATransaction commit];
}

- (void)applyColor:(UIColor *)color
         peakAlpha:(CGFloat)peakAlpha
       middleAlpha:(CGFloat)middleAlpha
{
    UIColor *safeColor = color ?: UIColor.clearColor;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.layer.cornerRadius = CGRectGetWidth(self.bounds) * 0.5;
    self.layer.masksToBounds = !self.isFaded;
    if (self.isFaded) {
        self.backgroundColor = UIColor.clearColor;
        self.radialLayer.hidden = NO;
        self.radialLayer.locations = @[@0.0, @0.46, @1.0];
        self.radialLayer.colors = @[
            (id)[safeColor colorWithAlphaComponent:peakAlpha].CGColor,
            (id)[safeColor colorWithAlphaComponent:middleAlpha].CGColor,
            (id)[safeColor colorWithAlphaComponent:0.0].CGColor
        ];
    } else {
        self.radialLayer.hidden = YES;
        self.backgroundColor = [safeColor colorWithAlphaComponent:peakAlpha];
    }
    [CATransaction commit];
}

@end

static NSString * const SPSellerMiddleBackgroundGlowPositionMotionKey = @"pp.sellerProfile.background.mid.position";
static NSString * const SPSellerMiddleBackgroundGlowPeekMotionKey = @"pp.sellerProfile.background.mid.peek";
static NSString * const SPSellerAvatarBreathingMotionKey = @"pp.sellerProfile.hero.avatar.breathing";

typedef void (^SPProviderRatingSubmitBlock)(NSInteger rating, NSString *comment);

@interface SPProviderRatingSheetViewController : UIViewController <UITextViewDelegate>
- (instancetype)initWithProviderName:(NSString *)providerName
                       currentRating:(NSInteger)currentRating
                      currentComment:(NSString *)currentComment
                              submit:(SPProviderRatingSubmitBlock)submit;
- (void)setSubmitting:(BOOL)submitting;
@end

@interface SPProviderRatingSheetViewController ()
@property (nonatomic, copy) NSString *providerName;
@property (nonatomic, copy) NSString *currentComment;
@property (nonatomic, copy) NSString *commentPlaceholder;
@property (nonatomic, copy) SPProviderRatingSubmitBlock submitBlock;
@property (nonatomic, assign) NSInteger selectedRating;
@property (nonatomic, assign) BOOL submitting;
@property (nonatomic, strong) NSArray<UIButton *> *starButtons;
@property (nonatomic, strong) UILabel *ratingMeaningLabel;
@property (nonatomic, strong) UITextView *commentTextView;
@property (nonatomic, strong) UIButton *submitButton;
@end

@implementation SPProviderRatingSheetViewController

- (instancetype)initWithProviderName:(NSString *)providerName
                       currentRating:(NSInteger)currentRating
                      currentComment:(NSString *)currentComment
                              submit:(SPProviderRatingSubmitBlock)submit
{
    self = [super init];
    if (self) {
        _providerName = [providerName copy] ?: @"";
        _selectedRating = MAX(0, MIN(currentRating, 5));
        _currentComment = [currentComment copy] ?: @"";
        _submitBlock = [submit copy];
        self.modalPresentationStyle = UIModalPresentationPageSheet;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self pp_buildRatingUI];
    [self pp_updateStarsAnimated:NO];
}

- (void)pp_buildRatingUI
{
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.alwaysBounceVertical = YES;
    scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:scrollView];

    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
     [scrollView addSubview:contentView];

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    closeButton.accessibilityLabel = kLang(@"Close") ?: @"Close";
    UIButtonConfiguration *closeConfiguration = [UIButtonConfiguration tintedButtonConfiguration];
    closeConfiguration.image = [UIImage systemImageNamed:@"xmark"];
    closeConfiguration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    closeConfiguration.baseForegroundColor = UIColor.labelColor;
    closeConfiguration.baseBackgroundColor = UIColor.secondarySystemBackgroundColor;
    closeButton.configuration = closeConfiguration;
    [closeButton addTarget:self action:@selector(pp_closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:closeButton];

    UIView *iconShell = [[UIView alloc] init];
    iconShell.translatesAutoresizingMaskIntoConstraints = NO;
    iconShell.backgroundColor = [SPSellerGoldColor() colorWithAlphaComponent:0.11];
    iconShell.layer.cornerRadius = 28.0;
    iconShell.layer.borderWidth = 0.25;
    iconShell.layer.masksToBounds = YES;
    [iconShell pp_setBorderColor:[SPSellerGoldColor() colorWithAlphaComponent:0.20]];

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"star.fill"]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = SPSellerGoldColor();
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [iconShell addSubview:iconView];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleTitle2]
                       scaledFontForFont:([GM boldFontWithSize:24.0] ?: [UIFont boldSystemFontOfSize:24.0])];
    titleLabel.adjustsFontForContentSizeCategory = YES;
    titleLabel.textColor = UIColor.labelColor;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.numberOfLines = 2;
    NSString *titleFormat = kLang(@"provider_rating_sheet_title_format") ?: @"Rate %@";
    titleLabel.text = [NSString stringWithFormat:titleFormat, self.providerName];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline]
                          scaledFontForFont:([GM MidFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0])];
    subtitleLabel.adjustsFontForContentSizeCategory = YES;
    subtitleLabel.textColor = UIColor.secondaryLabelColor;
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.text = kLang(@"provider_rating_sheet_subtitle") ?: @"Share an honest rating based on your purchase.";

    UIStackView *starsStack = [[UIStackView alloc] init];
    starsStack.translatesAutoresizingMaskIntoConstraints = NO;
    starsStack.axis = UILayoutConstraintAxisHorizontal;
    starsStack.alignment = UIStackViewAlignmentCenter;
    starsStack.distribution = UIStackViewDistributionFillEqually;
    starsStack.spacing = 8.0;
 
    NSMutableArray<UIButton *> *starButtons = [NSMutableArray arrayWithCapacity:5];
    for (NSInteger rating = 1; rating <= 5; rating++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        button.tag = rating;
        button.adjustsImageWhenHighlighted = NO;
        button.accessibilityLabel =
            [NSString stringWithFormat:(kLang(@"provider_rating_star_accessibility_format") ?: @"%ld stars"),
             (long)rating];
        [button addTarget:self action:@selector(pp_starTapped:) forControlEvents:UIControlEventTouchUpInside];
        [button.heightAnchor constraintEqualToConstant:52.0].active = YES;
        [starsStack addArrangedSubview:button];
        [starButtons addObject:button];
    }
    self.starButtons = starButtons.copy;

    self.ratingMeaningLabel = [[UILabel alloc] init];
    self.ratingMeaningLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.ratingMeaningLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline]
                                    scaledFontForFont:([GM boldFontWithSize:14.0] ?: [UIFont boldSystemFontOfSize:14.0])];
    self.ratingMeaningLabel.adjustsFontForContentSizeCategory = YES;
    self.ratingMeaningLabel.textAlignment = NSTextAlignmentCenter;
    self.ratingMeaningLabel.textColor = SPSellerGoldColor();

    self.commentPlaceholder = kLang(@"provider_rating_comment_placeholder") ?: @"Add a short note about your experience";
    self.commentTextView = [[UITextView alloc] init];
    self.commentTextView.translatesAutoresizingMaskIntoConstraints = NO;
    self.commentTextView.delegate = self;
    self.commentTextView.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
                                 scaledFontForFont:([GM MidFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0])];
    self.commentTextView.adjustsFontForContentSizeCategory = YES;
    self.commentTextView.textAlignment = Language.alignmentForCurrentLanguage;
     self.commentTextView.backgroundColor = UIColor.secondarySystemBackgroundColor;
    self.commentTextView.layer.cornerRadius = 18.0;
    self.commentTextView.layer.borderWidth = 0.75;
    self.commentTextView.layer.masksToBounds = YES;
    [self.commentTextView pp_setBorderColor:[UIColor.separatorColor colorWithAlphaComponent:0.30]];
    self.commentTextView.textContainerInset = UIEdgeInsetsMake(13.0, 14.0, 13.0, 14.0);
    UIToolbar *keyboardToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0.0, 0.0, 0.0, 44.0)];
    UIBarButtonItem *flexible =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                     target:nil
                                                     action:nil];
    UIBarButtonItem *done =
        [[UIBarButtonItem alloc] initWithTitle:(kLang(@"Done") ?: @"Done")
                                        style:UIBarButtonItemStyleDone
                                       target:self
                                       action:@selector(pp_keyboardDone)];
    keyboardToolbar.items = @[flexible, done];
    self.commentTextView.inputAccessoryView = keyboardToolbar;
    if (self.currentComment.length > 0) {
        self.commentTextView.text = self.currentComment;
        self.commentTextView.textColor = UIColor.labelColor;
    } else {
        self.commentTextView.text = self.commentPlaceholder;
        self.commentTextView.textColor = UIColor.placeholderTextColor;
    }

    self.submitButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.submitButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.submitButton addTarget:self action:@selector(pp_submitTapped) forControlEvents:UIControlEventTouchUpInside];
    [self pp_updateSubmitButton];

    [contentView addSubview:iconShell];
    [contentView addSubview:titleLabel];
    [contentView addSubview:subtitleLabel];
    [contentView addSubview:starsStack];
    [contentView addSubview:self.ratingMeaningLabel];
    [contentView addSubview:self.commentTextView];
    [contentView addSubview:self.submitButton];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [contentView.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor],
        [contentView.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor],
        [contentView.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor],

        [closeButton.topAnchor constraintEqualToAnchor:safe.topAnchor constant:16.0],
        [closeButton.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-22.0],
        [closeButton.widthAnchor constraintEqualToConstant:40.0],
        [closeButton.heightAnchor constraintEqualToConstant:40.0],

        [iconShell.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:18.0],
        [iconShell.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20.0],
        [iconShell.widthAnchor constraintEqualToConstant:56.0],
        [iconShell.heightAnchor constraintEqualToConstant:56.0],
        [iconView.centerXAnchor constraintEqualToAnchor:iconShell.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconShell.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:24.0],
        [iconView.heightAnchor constraintEqualToConstant:24.0],

        [titleLabel.topAnchor constraintEqualToAnchor:iconShell.bottomAnchor constant:16.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:7.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],

        [starsStack.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:22.0],
        [starsStack.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20.0],
        [starsStack.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20.0],

        [self.ratingMeaningLabel.topAnchor constraintEqualToAnchor:starsStack.bottomAnchor constant:8.0],
        [self.ratingMeaningLabel.leadingAnchor constraintEqualToAnchor:starsStack.leadingAnchor],
        [self.ratingMeaningLabel.trailingAnchor constraintEqualToAnchor:starsStack.trailingAnchor],

        [self.commentTextView.topAnchor constraintEqualToAnchor:self.ratingMeaningLabel.bottomAnchor constant:18.0],
        [self.commentTextView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20.0],
        [self.commentTextView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20.0],
        [self.commentTextView.heightAnchor constraintGreaterThanOrEqualToConstant:96.0],

        [self.submitButton.topAnchor constraintEqualToAnchor:self.commentTextView.bottomAnchor constant:16.0],
        [self.submitButton.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20.0],
        [self.submitButton.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20.0],
        [self.submitButton.heightAnchor constraintEqualToConstant:52.0],
        [self.submitButton.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-24.0],
    ]];
    [self.view bringSubviewToFront:closeButton];
}

- (void)pp_starTapped:(UIButton *)sender
{
    if (self.submitting) return;
    self.selectedRating = MAX(1, MIN(sender.tag, 5));
    [self pp_updateStarsAnimated:YES];
    UISelectionFeedbackGenerator *feedback = [[UISelectionFeedbackGenerator alloc] init];
    [feedback selectionChanged];
}

- (void)pp_updateStarsAnimated:(BOOL)animated
{
    NSArray<NSString *> *meaningKeys = @[
        @"provider_rating_meaning_select",
        @"provider_rating_meaning_1",
        @"provider_rating_meaning_2",
        @"provider_rating_meaning_3",
        @"provider_rating_meaning_4",
        @"provider_rating_meaning_5"
    ];
    self.ratingMeaningLabel.text = kLang(meaningKeys[MAX(0, MIN(self.selectedRating, 5))]);

    void (^changes)(void) = ^{
        for (UIButton *button in self.starButtons) {
            BOOL selected = button.tag <= self.selectedRating;
            UIButtonConfiguration *configuration = [UIButtonConfiguration tintedButtonConfiguration];
            configuration.image = [UIImage systemImageNamed:selected ? @"star.fill" : @"star"];
            configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
            configuration.baseForegroundColor = SPSellerGoldColor();
            configuration.baseBackgroundColor =
                [SPSellerGoldColor() colorWithAlphaComponent:selected ? 0.16 : 0.055];
            configuration.background.strokeColor =
                [SPSellerGoldColor() colorWithAlphaComponent:selected ? 0.24 : 0.10];
            configuration.background.strokeWidth = selected ? 1.0 : 0.65;
            button.configuration = configuration;
            button.accessibilityTraits =
                UIAccessibilityTraitButton | (button.tag == self.selectedRating ? UIAccessibilityTraitSelected : 0);
            button.transform = selected && !UIAccessibilityIsReduceMotionEnabled()
                ? CGAffineTransformMakeScale(1.035, 1.035)
                : CGAffineTransformIdentity;
        }
        [self pp_updateSubmitButton];
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        changes();
        return;
    }
    [UIView animateWithDuration:0.24
                          delay:0.0
         usingSpringWithDamping:0.82
          initialSpringVelocity:0.20
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:changes
                     completion:nil];
}

- (void)pp_updateSubmitButton
{
    UIButtonConfiguration *configuration = [UIButtonConfiguration filledButtonConfiguration];
    configuration.title = kLang(@"provider_rating_submit") ?: @"Submit rating";
    configuration.image = self.submitting ? nil : [UIImage systemImageNamed:@"checkmark.seal.fill"];
    configuration.imagePadding = 8.0;
    configuration.showsActivityIndicator = self.submitting;
    configuration.cornerStyle = UIButtonConfigurationCornerStyleLarge;
    configuration.baseBackgroundColor = SPSellerInkColor();
    configuration.baseForegroundColor = UIColor.systemBackgroundColor;
    self.submitButton.configuration = configuration;
    self.submitButton.enabled = self.selectedRating > 0 && !self.submitting;
    self.submitButton.alpha = self.submitButton.enabled ? 1.0 : 0.52;
}

- (void)setSubmitting:(BOOL)submitting
{
    _submitting = submitting;
    self.commentTextView.editable = !submitting;
    for (UIButton *button in self.starButtons) {
        button.enabled = !submitting;
    }
    [self pp_updateSubmitButton];
}

- (NSString *)pp_cleanComment
{
    if ([self.commentTextView.text isEqualToString:self.commentPlaceholder]) {
        return @"";
    }
    NSString *comment =
        [self.commentTextView.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return comment.length > 600 ? [comment substringToIndex:600] : comment;
}

- (void)pp_submitTapped
{
    if (self.selectedRating <= 0 || self.submitting) {
        return;
    }
    if (self.submitBlock) {
        self.submitBlock(self.selectedRating, [self pp_cleanComment]);
    }
}

- (void)pp_closeTapped
{
    if (!self.submitting) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)pp_keyboardDone
{
    [self.commentTextView resignFirstResponder];
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    if ([textView.text isEqualToString:self.commentPlaceholder]) {
        textView.text = @"";
        textView.textColor = UIColor.labelColor;
    }
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    if ([textView.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length == 0) {
        textView.text = self.commentPlaceholder;
        textView.textColor = UIColor.placeholderTextColor;
    }
}

@end

@interface SellerProfileVC () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, PPUniversalCellDelegate, UIScrollViewDelegate>

@property (nonatomic, strong) UIView *pp_premiumBackgroundCanvasView;
@property (nonatomic, strong) SPSellerAmbientGlowView *pp_premiumBackgroundGlowViewTop;
@property (nonatomic, strong) SPSellerAmbientGlowView *pp_premiumBackgroundGlowViewMid;
@property (nonatomic, strong) SPSellerAmbientGlowView *pp_premiumBackgroundGlowViewBottom;
@property (nonatomic, assign) BOOL livingBackgroundActive;
@property (nonatomic, assign) BOOL backgroundGlowsFadedByHomeConfig;
@property (nonatomic, assign) BOOL sellerScreenVisible;
@property (nonatomic, assign) BOOL didStartHeroAliveMotion;
@property (nonatomic, assign) CGSize premiumBackgroundGlowMotionCanvasSize;
@property (nonatomic, assign) BOOL didAnimateEntrance;
@property (nonatomic, assign) BOOL didRequestSellerItems;

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *heroSurfaceView;
@property (nonatomic, strong) PPBackgroundView *heroGlassBackgroundView;
@property (nonatomic, strong) UIView *topFadeView;
@property (nonatomic, strong) CAGradientLayer *heroBottomFadeLayer;
@property (nonatomic, strong) UIButton *heroBackButton;
@property (nonatomic, strong) UIView *avatarBreathingHaloView;
@property (nonatomic, strong) UIView *avatarShellView;
@property (nonatomic, strong) UIView *avatarInnerPlateView;
@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, strong) UILabel *eyebrowLabel;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIView *statusBadgeView;
@property (nonatomic, strong) UIImageView *statusBadgeIconView;
@property (nonatomic, strong) UILabel *descriptionLabel;
@property (nonatomic, strong) UIStackView *contactButtonStack;
@property (nonatomic, strong) UIButton *messageButton;
@property (nonatomic, strong) UIButton *callButton;
@property (nonatomic, strong) UIButton *rateButton;
@property (nonatomic, strong) UILabel *itemsTitleLabel;
@property (nonatomic, strong) UILabel *itemsStateLabel;
@property (nonatomic, strong) UIActivityIndicatorView *itemsActivityIndicator;
@property (nonatomic, strong) UIButton *itemsRetryButton;
@property (nonatomic, strong) UICollectionView *itemsCollectionView;
@property (nonatomic, strong) UIView *compactHeaderView;
@property (nonatomic, strong) UIView *compactHeaderAvatarShellView;
@property (nonatomic, strong) UIImageView *compactHeaderAvatarImageView;
@property (nonatomic, strong) UILabel *compactHeaderTitleLabel;
@property (nonatomic, strong) UILabel *compactHeaderBadgeLabel;
@property (nonatomic, strong) NSMutableArray<PPUniversalCellViewModel *> *itemViewModels;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *animatedItemIndexes;
@property (nonatomic, strong) NSLayoutConstraint *collectionHeightConstraint;
@property (nonatomic, strong, nullable) NSError *itemsLoadError;
@property (nonatomic, strong) PPHomeCartNavButton *cartNavButton;
@property (nonatomic, assign) CGFloat appliedHeroScrollInset;
@property (nonatomic, assign) CGFloat appliedBottomNavigationScrollInset;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> providerRatingListener;
@property (nonatomic, assign) BOOL ratingEligibilityLoaded;
@property (nonatomic, assign) BOOL isCheckingRatingEligibility;
@property (nonatomic, assign) BOOL canRateProvider;
@property (nonatomic, assign) BOOL hasExistingProviderReview;
@property (nonatomic, assign) BOOL isSubmittingProviderReview;
@property (nonatomic, assign) NSInteger existingProviderRating;
@property (nonatomic, copy) NSString *existingProviderReviewComment;
@property (nonatomic, copy) NSString *ratingEligibilityUID;
- (void)pp_startProviderRatingListener;
- (void)pp_refreshRatingEligibilityWithCompletion:(void (^ _Nullable)(BOOL eligible))completion;
- (void)pp_updateRateButtonState;
- (void)pp_presentProviderRatingSheet;
- (void)pp_applyHeroActionStyleToButton:(UIButton *)button role:(SPSellerHeroActionRole)role;
- (void)pp_updateBottomNavigationInsetsIfNeeded;
- (void)pp_applyPremiumSellerBackgroundAppearance;
- (SPSellerAmbientGlowView *)pp_makePremiumBackgroundGlowView;
- (void)pp_installPremiumBackgroundGlowViewsIfNeeded;
- (void)pp_applyPremiumGlowView:(SPSellerAmbientGlowView *)glowView
                          color:(UIColor *)color
                      peakAlpha:(CGFloat)peakAlpha
                    middleAlpha:(CGFloat)middleAlpha;
- (void)pp_updatePremiumBackgroundGlowAppearance;
- (void)pp_layoutPremiumBackgroundGlowViews;
- (void)pp_addRandomizedMiddleBackgroundGlowPositionMotion;
- (void)pp_addPremiumMiddleBackgroundGlowPeekMotionIfNeeded;
- (void)pp_beginHeroAliveMotionIfNeeded;
- (void)pp_stopHeroAliveMotion;
- (void)pp_prepareHeroEntranceState;
- (void)pp_resetHeroEntranceState;
- (void)pp_submitProviderRating:(NSInteger)rating
                         comment:(NSString *)comment
                           sheet:(SPProviderRatingSheetViewController *)sheet;

@end

@implementation SellerProfileVC

- (PPBottomSurfaceKind)pp_preferredBottomSurfaceKind
{
    return PPBottomSurfaceKindFloatingCartSurface;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.hidesBottomBarWhenPushed = YES;
        _itemViewModels = [NSMutableArray array];
        _animatedItemIndexes = [NSMutableSet set];
        _backgroundGlowsFadedByHomeConfig = NO;
    }
    return self;
}

- (void)dealloc
{
    [self stopLivingBackground];
    [self.providerRatingListener remove];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setSeller:(UserModel *)seller {
    [self.providerRatingListener remove];
    self.providerRatingListener = nil;
    _seller = seller;
    self.ratingEligibilityLoaded = NO;
    self.isCheckingRatingEligibility = NO;
    self.canRateProvider = NO;
    self.hasExistingProviderReview = NO;
    self.existingProviderRating = 0;
    self.existingProviderReviewComment = @"";
    if (self.isViewLoaded) {
        [self configureSellerIdentity];
        [self fetchSellerItemsIfNeeded];
        [self pp_startProviderRatingListener];
        [self pp_refreshRatingEligibilityWithCompletion:nil];
    }
}

- (void)setSellerItems:(NSArray<PetAccessory *> *)sellerItems {
    _sellerItems = [sellerItems copy] ?: @[];
    if (self.isViewLoaded) {
        [self applySellerItems:_sellerItems loading:NO];
    }
}

- (void)setProviderCategoryIdentifier:(NSString *)providerCategoryIdentifier
{
    _providerCategoryIdentifier = [providerCategoryIdentifier copy];
    self.didRequestSellerItems = NO;
    self.itemsLoadError = nil;
    if (self.isViewLoaded) {
        [self configureSellerIdentity];
        [self applySellerItems:self.sellerItems loading:self.sellerItems.count == 0];
        [self fetchSellerItemsIfNeeded];
    }
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupNavigationChrome];
    [self setupViews];
    [self setupConstraints];
    [self configureSellerIdentity];
    [self applySellerItems:self.sellerItems loading:self.sellerItems.count == 0];
    [self fetchSellerItemsIfNeeded];
    [self pp_startProviderRatingListener];
    [self pp_refreshRatingEligibilityWithCompletion:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_cartDidUpdate:)
                                                 name:kCartUpdatedNotification
                                               object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    [self applySemanticDirection];
    self.sellerScreenVisible = YES;
    [self startLivingBackgroundIfNeeded];
    [self pp_prepareHeroEntranceState];
    [self animateEntranceIfNeeded];
    [self pp_updateBottomNavigationInsetsIfNeeded];
    [self pp_startProviderRatingListener];
    self.ratingEligibilityLoaded = NO;
    [self pp_refreshRatingEligibilityWithCompletion:nil];
    [self pp_applyBottomSurfaceAnimated:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.sellerScreenVisible = NO;
    [self pp_stopHeroAliveMotion];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self stopLivingBackground];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutGlowViews];
    [self updateCollectionHeight];
    [self updateSurfaceShadowPaths];
    [self pp_updateScrollInsetsForHeroIfNeeded];
    [self pp_updateBottomNavigationInsetsIfNeeded];
    [self.view bringSubviewToFront:self.topFadeView];
    [self.view bringSubviewToFront:self.heroSurfaceView];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self pp_beginHeroAliveMotionIfNeeded];
}

- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
    [self layoutGlowViews];
    [self pp_updateBottomNavigationInsetsIfNeeded];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self applyTheme];
}

#pragma mark - View Setup

- (void)setupNavigationChrome
{
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;

    self.cartNavButton = [[PPHomeCartNavButton alloc] init];
    self.cartNavButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.cartNavButton setIconName:@"cart.fill"];
    self.cartNavButton.accessibilityLabel = kLang(@"Cart") ?: @"Cart";
    self.cartNavButton.accessibilityHint = kLang(@"a11y_btn_cart_hint") ?: @"Double-tap to open your cart";
    [self.cartNavButton applyHeroPresentationStyle];
    [self.cartNavButton addTarget:self
                           action:@selector(pp_openCart)
                 forControlEvents:UIControlEventTouchUpInside];

    self.heroBackButton = [self pp_makeHeroBackButton];
    [self pp_cartDidUpdate:nil];
}



- (UIButton *)pp_makeHeroBackButton
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.accessibilityLabel = kLang(@"Back") ?: @"Back";
    button.accessibilityHint = kLang(@"seller_profile_back_hint") ?: @"Double-tap to go back";
    button.accessibilityTraits = UIAccessibilityTraitButton;
    button.adjustsImageWhenHighlighted = NO;

    UIImage *image = [UIImage pp_symbolNamed:PPChevronName
                                    pointSize:17.0
                                       weight:UIImageSymbolWeightSemibold
                                        scale:UIImageSymbolScaleMedium
                                      palette:@[UIColor.labelColor, UIColor.labelColor]
                                 makeTemplate:YES];
    UIColor *fill = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.08]
            : ([AppForgroundColr colorWithAlphaComponent:0.92] ?: [UIColor colorWithWhite:1.0 alpha:0.92]);
    }];
    UIColor *stroke = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.12]
            : [UIColor colorWithWhite:1.0 alpha:0.82];
    }];

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
        configuration.image = image;
        configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        configuration.contentInsets = NSDirectionalEdgeInsetsMake(11.0, 11.0, 11.0, 11.0);
        configuration.baseForegroundColor = UIColor.labelColor;
        configuration.background.backgroundColor = fill;
        configuration.background.strokeColor = stroke;
        configuration.background.strokeWidth = 0.8;
        button.configuration = configuration;
    } else {
        [button setImage:image forState:UIControlStateNormal];
        button.tintColor = UIColor.labelColor;
        button.backgroundColor = fill;
        button.layer.cornerRadius = 22.0;
        button.layer.borderWidth = 0.8;
        [button pp_setBorderColor:[stroke resolvedColorWithTraitCollection:self.traitCollection]];
    }

    button.layer.shadowColor = UIColor.blackColor.CGColor;
    button.layer.shadowOpacity = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.0 : 0.06;
    button.layer.shadowRadius = 12.0;
    button.layer.shadowOffset = CGSizeMake(0.0, 6.0);
    [button addTarget:self action:@selector(pp_handleHeroBack) forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:self action:@selector(handleButtonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(handleButtonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    return button;
}



- (void)setupViews {
    self.view.backgroundColor = SPSellerBackgroundColor(self.traitCollection);
    self.view.clipsToBounds = YES;

    [self setupLivingBackground];

    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.delegate = self;
    if (@available(iOS 11.0, *)) {
        self.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    [self.view addSubview:self.scrollView];

    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentView.backgroundColor = UIColor.clearColor;
    [self.scrollView addSubview:self.contentView];

    [self setupHeroSurface];
    [self setupItemsSection];
    [self setupCompactHeader];
    [self applyTheme];
}

- (void)setupLivingBackground {
    [self pp_applyPremiumSellerBackgroundAppearance];
}

- (UIView *)createGlowViewWithColor:(UIColor *)color {
    SPSellerAmbientGlowView *view = [[SPSellerAmbientGlowView alloc] initWithFrame:CGRectZero];
    view.faded = self.backgroundGlowsFadedByHomeConfig;
    [view applyColor:color peakAlpha:0.0 middleAlpha:0.0];
    return view;
}

- (void)setupHeroSurface {
    self.heroSurfaceView = [self createSurfaceView];
    self.heroSurfaceView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.heroSurfaceView.layer.borderWidth = 0.55;
    self.heroSurfaceView.layer.shadowOpacity = 0.035;
    self.heroSurfaceView.layer.shadowRadius = 16.0;
    self.heroSurfaceView.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    self.heroSurfaceView.backgroundColor = UIColor.clearColor;
    for (UIView *subview in [self.heroSurfaceView.subviews copy]) {
        if ([subview isKindOfClass:UIVisualEffectView.class]) {
            [subview removeFromSuperview];
        }
    }

    PPBackgroundView *glassBg = [PPBackgroundView new];
    glassBg.translatesAutoresizingMaskIntoConstraints = NO;
    glassBg.layer.cornerRadius = kSPSurfaceCornerRadius;
    glassBg.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        glassBg.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.heroSurfaceView insertSubview:glassBg atIndex:0];
    self.heroGlassBackgroundView = glassBg;
    [NSLayoutConstraint activateConstraints:@[
        [glassBg.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor],
        [glassBg.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor],
        [glassBg.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor],
        [glassBg.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor],
    ]];

    [self.view addSubview:self.heroSurfaceView];

    self.topFadeView = [[UIView alloc] init];
    self.topFadeView.translatesAutoresizingMaskIntoConstraints = NO;
    self.topFadeView.userInteractionEnabled = NO;
    self.topFadeView.backgroundColor = UIColor.clearColor;
    [self.view addSubview:self.topFadeView];

    self.heroBottomFadeLayer = [CAGradientLayer layer];
    self.heroBottomFadeLayer.startPoint = CGPointMake(0.5, 0.0);
    self.heroBottomFadeLayer.endPoint = CGPointMake(0.5, 1.0);
    //self.heroBottomFadeLayer.locations = @[@0.0, @0.42, @1.0];
    [self.topFadeView.layer addSublayer:self.heroBottomFadeLayer];

    [self.heroSurfaceView addSubview:self.heroBackButton];
    [self.heroSurfaceView addSubview:self.cartNavButton];

    self.avatarBreathingHaloView = [[UIView alloc] init];
    self.avatarBreathingHaloView.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarBreathingHaloView.userInteractionEnabled = NO;
    self.avatarBreathingHaloView.isAccessibilityElement = NO;
    self.avatarBreathingHaloView.layer.cornerRadius = kSPAvatarHaloSize / 2.0;
    self.avatarBreathingHaloView.layer.masksToBounds = NO;
    if (@available(iOS 13.0, *)) {
        self.avatarBreathingHaloView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.heroSurfaceView addSubview:self.avatarBreathingHaloView];

    self.avatarShellView = [[UIView alloc] init];
    self.avatarShellView.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarShellView.backgroundColor = SPSellerHeroAvatarShellColor(self.traitCollection);
    self.avatarShellView.layer.cornerRadius = kSPAvatarShellSize / 2.0;
    self.avatarShellView.layer.borderWidth = 1.0;
    self.avatarShellView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.avatarShellView.layer.shadowOpacity = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.0 : 0.075;
    self.avatarShellView.layer.shadowRadius = 18.0;
    self.avatarShellView.layer.shadowOffset = CGSizeMake(0.0, 9.0);
    self.avatarShellView.clipsToBounds = NO;
    [self.avatarShellView pp_setBorderColor:[SPSellerHeroAvatarStrokeColor(self.traitCollection) colorWithAlphaComponent:0.38]];
    [self.heroSurfaceView addSubview:self.avatarShellView];

    self.avatarInnerPlateView = [[UIView alloc] init];
    self.avatarInnerPlateView.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarInnerPlateView.layer.cornerRadius = kSPAvatarSize / 2.0;
    self.avatarInnerPlateView.layer.borderWidth = 0.75;
    self.avatarInnerPlateView.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.avatarInnerPlateView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.avatarShellView addSubview:self.avatarInnerPlateView];

    self.avatarImageView = [[UIImageView alloc] initWithImage:PPSYSImage(@"person.crop.circle.fill")];
    self.avatarImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarImageView.layer.cornerRadius = kSPAvatarSize / 2.0;
    self.avatarImageView.layer.masksToBounds = YES;
    self.avatarImageView.backgroundColor = [SPSellerInkColor() colorWithAlphaComponent:0.045];
    self.avatarImageView.tintColor = [SPSellerSecondaryTextColor() colorWithAlphaComponent:0.72];
    [self.avatarInnerPlateView addSubview:self.avatarImageView];

    self.eyebrowLabel = [self labelWithFont:[GM boldFontWithSize:11.0] color:SPSellerAccentTealColor() lines:1];
    [self.heroSurfaceView addSubview:self.eyebrowLabel];

    self.nameLabel = [self labelWithFont:[GM boldFontWithSize:24.0] color:SPSellerInkColor() lines:1];
    self.nameLabel.adjustsFontSizeToFitWidth = YES;
    self.nameLabel.minimumScaleFactor = 0.72;
    [self.heroSurfaceView addSubview:self.nameLabel];

    self.subtitleLabel = [self labelWithFont:[GM MidFontWithSize:12.5] color:SPSellerSecondaryTextColor() lines:2];
    self.subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.heroSurfaceView addSubview:self.subtitleLabel];

    self.statusBadgeView = [[UIView alloc] init];
    self.statusBadgeView.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusBadgeView.isAccessibilityElement = YES;
    self.statusBadgeView.accessibilityTraits = UIAccessibilityTraitImage;
    self.statusBadgeView.layer.cornerRadius = 11.0;
    self.statusBadgeView.layer.borderWidth = 1.5;
    self.statusBadgeView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.98] ?: UIColor.systemBackgroundColor;
    [self.statusBadgeView pp_setBorderColor:[AppForgroundColr colorWithAlphaComponent:0.98] ?: UIColor.whiteColor];
    self.statusBadgeView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.statusBadgeView.layer.shadowOpacity = 0.055;
    self.statusBadgeView.layer.shadowRadius = 5.0;
    self.statusBadgeView.layer.shadowOffset = CGSizeMake(0.0, 2.0);
    [self.heroSurfaceView addSubview:self.statusBadgeView];

    self.statusBadgeIconView = [[UIImageView alloc] init];
    self.statusBadgeIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusBadgeIconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.statusBadgeView addSubview:self.statusBadgeIconView];
    [NSLayoutConstraint activateConstraints:@[
        [self.statusBadgeIconView.centerXAnchor constraintEqualToAnchor:self.statusBadgeView.centerXAnchor],
        [self.statusBadgeIconView.centerYAnchor constraintEqualToAnchor:self.statusBadgeView.centerYAnchor],
        [self.statusBadgeIconView.widthAnchor constraintEqualToConstant:12.0],
        [self.statusBadgeIconView.heightAnchor constraintEqualToConstant:12.0],
    ]];

    self.descriptionLabel = [self labelWithFont:[GM MidFontWithSize:14] color:SPSellerSecondaryTextColor() lines:0];
    self.descriptionLabel.hidden = YES;
    self.descriptionLabel.isAccessibilityElement = NO;
    [self.heroSurfaceView addSubview:self.descriptionLabel];

    self.messageButton = [self createActionButtonWithTitle:kLang(@"message")
                                                 imageName:@"message.fill"
                                                emphasized:YES
                                                  selector:@selector(handleMessageTap)];
    self.callButton = [self createActionButtonWithTitle:kLang(@"call")
                                              imageName:@"phone.fill"
                                             emphasized:NO
                                               selector:@selector(handleCallTap)];
    self.callButton.hidden = YES;
    self.callButton.enabled = NO;
    self.callButton.alpha = 0.0;
    self.callButton.accessibilityElementsHidden = YES;
    self.rateButton = [self createActionButtonWithTitle:(kLang(@"provider_rating_action") ?: @"Rate provider")
                                              imageName:@"star.fill"
                                             emphasized:NO
                                               selector:@selector(handleRateProviderTap)];
    self.rateButton.titleLabel.font = [GM boldFontWithSize:12.0];
    self.rateButton.titleLabel.numberOfLines = 1;
    self.rateButton.titleLabel.textAlignment = NSTextAlignmentCenter;

    self.contactButtonStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.messageButton,
        self.rateButton
    ]];
    self.contactButtonStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contactButtonStack.axis = UILayoutConstraintAxisHorizontal;
    self.contactButtonStack.spacing = 12.0;
    self.contactButtonStack.distribution = UIStackViewDistributionFillEqually;
    self.contactButtonStack.alignment = UIStackViewAlignmentFill;
    [self.heroSurfaceView addSubview:self.contactButtonStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.heroBackButton.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:kSPSpace16],
        [self.heroBackButton.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:kSPSpace16],
        [self.heroBackButton.widthAnchor constraintEqualToConstant:40.0],
        [self.heroBackButton.heightAnchor constraintEqualToConstant:40.0],

        [self.cartNavButton.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:kSPSpace16],
        [self.cartNavButton.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-kSPSpace16],
        [self.cartNavButton.widthAnchor constraintEqualToConstant:40.0],
        [self.cartNavButton.heightAnchor constraintEqualToConstant:40.0],

        [self.avatarBreathingHaloView.centerXAnchor constraintEqualToAnchor:self.avatarShellView.centerXAnchor],
        [self.avatarBreathingHaloView.centerYAnchor constraintEqualToAnchor:self.avatarShellView.centerYAnchor],
        [self.avatarBreathingHaloView.widthAnchor constraintEqualToConstant:kSPAvatarHaloSize],
        [self.avatarBreathingHaloView.heightAnchor constraintEqualToConstant:kSPAvatarHaloSize],
    ]];

    [self.heroSurfaceView bringSubviewToFront:self.heroBackButton];
    [self.heroSurfaceView bringSubviewToFront:self.cartNavButton];
}

- (void)setupItemsSection {
    self.itemsTitleLabel = [self labelWithFont:[GM boldFontWithSize:22] color:SPSellerInkColor() lines:1];
    [self.contentView addSubview:self.itemsTitleLabel];

    self.itemsStateLabel = [self labelWithFont:[GM MidFontWithSize:14] color:SPSellerSecondaryTextColor() lines:0];
    self.itemsStateLabel.textAlignment = NSTextAlignmentCenter;
    [self.contentView addSubview:self.itemsStateLabel];

    self.itemsActivityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.itemsActivityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.itemsActivityIndicator.hidesWhenStopped = YES;
    self.itemsActivityIndicator.color = SPSellerAccentTealColor();
    [self.contentView addSubview:self.itemsActivityIndicator];

    self.itemsRetryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.itemsRetryButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.itemsRetryButton.layer.cornerRadius = 16.0;
    self.itemsRetryButton.layer.masksToBounds = YES;
    self.itemsRetryButton.titleLabel.font = [GM boldFontWithSize:15.0];
    self.itemsRetryButton.backgroundColor = SPSellerInkColor();
    [self.itemsRetryButton setTitleColor:SPSellerSurfaceColor(self.traitCollection) forState:UIControlStateNormal];
    [self.itemsRetryButton setTitle:(kLang(@"provider_retry") ?: @"Retry") forState:UIControlStateNormal];
    [self.itemsRetryButton addTarget:self action:@selector(handleRetryItemsTap) forControlEvents:UIControlEventTouchUpInside];
    [self.itemsRetryButton addTarget:self action:@selector(handleButtonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [self.itemsRetryButton addTarget:self action:@selector(handleButtonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    self.itemsRetryButton.hidden = YES;
    [self.contentView addSubview:self.itemsRetryButton];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
    layout.minimumLineSpacing = kSPSpace12;
    layout.minimumInteritemSpacing = kSPSpace12;

    self.itemsCollectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.itemsCollectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.itemsCollectionView.backgroundColor = UIColor.clearColor;
    self.itemsCollectionView.scrollEnabled = NO;
    self.itemsCollectionView.showsVerticalScrollIndicator = NO;
    self.itemsCollectionView.dataSource = self;
    self.itemsCollectionView.delegate = self;
    [self.itemsCollectionView registerClass:PPUniversalCell.class forCellWithReuseIdentifier:PPUniversalCell.reuseIdentifier];
    [self.contentView addSubview:self.itemsCollectionView];
}

- (void)setupCompactHeader
{
    self.compactHeaderView = [self createSurfaceView];
    self.compactHeaderView.translatesAutoresizingMaskIntoConstraints = NO;
    self.compactHeaderView.alpha = 0.0;
    self.compactHeaderView.hidden = YES;
    self.compactHeaderView.userInteractionEnabled = NO;
    self.compactHeaderView.layer.cornerRadius = 24.0;
    self.compactHeaderView.layer.shadowRadius = 16.0;
    self.compactHeaderView.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    self.compactHeaderView.layer.shadowOpacity = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.18 : 0.06;
    UIView *compactBlurView = self.compactHeaderView.subviews.firstObject;
    if ([compactBlurView isKindOfClass:UIView.class]) {
        compactBlurView.layer.cornerRadius = 24.0;
    }
    [self.view addSubview:self.compactHeaderView];

    self.compactHeaderAvatarShellView = [[UIView alloc] init];
    self.compactHeaderAvatarShellView.translatesAutoresizingMaskIntoConstraints = NO;
    self.compactHeaderAvatarShellView.layer.masksToBounds = YES;
    self.compactHeaderAvatarShellView.layer.borderWidth = 1.0;
    [self.compactHeaderView addSubview:self.compactHeaderAvatarShellView];

    self.compactHeaderAvatarImageView = [[UIImageView alloc] init];
    self.compactHeaderAvatarImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.compactHeaderAvatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.compactHeaderAvatarImageView.layer.masksToBounds = YES;
    [self.compactHeaderAvatarShellView addSubview:self.compactHeaderAvatarImageView];

    self.compactHeaderTitleLabel = [self labelWithFont:[GM boldFontWithSize:16.0]
                                                 color:SPSellerInkColor()
                                                 lines:1];
    self.compactHeaderTitleLabel.adjustsFontSizeToFitWidth = YES;
    self.compactHeaderTitleLabel.minimumScaleFactor = 0.82;
    [self.compactHeaderView addSubview:self.compactHeaderTitleLabel];

    self.compactHeaderBadgeLabel = [self labelWithFont:[GM boldFontWithSize:11.0]
                                                 color:SPSellerAccentTealColor()
                                                 lines:1];
    self.compactHeaderBadgeLabel.textAlignment = NSTextAlignmentCenter;
    self.compactHeaderBadgeLabel.layer.cornerRadius = 11.0;
    self.compactHeaderBadgeLabel.layer.masksToBounds = YES;
    self.compactHeaderBadgeLabel.layer.borderWidth = 1.0;
    [self.compactHeaderView addSubview:self.compactHeaderBadgeLabel];
}

- (UIView *)createSurfaceView {
    UIView *surface = [[UIView alloc] init];
    surface.translatesAutoresizingMaskIntoConstraints = NO;
    surface.backgroundColor = [SPSellerSurfaceColor(self.traitCollection) colorWithAlphaComponent:0.82];
    surface.layer.cornerRadius = kSPSurfaceCornerRadius;
    surface.layer.masksToBounds = NO;
    surface.layer.borderWidth = 0.25;
    [surface pp_setBorderColor:[SPSellerInkColor() colorWithAlphaComponent:0.06]];
    [surface pp_setShadowColor:UIColor.blackColor];
    surface.layer.shadowOpacity = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.14 : 0.045;
    surface.layer.shadowRadius = 16.0;
    surface.layer.shadowOffset = CGSizeMake(0.0, 8.0);

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleExtraLight];
    if (@available(iOS 13.0, *)) {
        blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    }
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    blurView.layer.cornerRadius = kSPSurfaceCornerRadius;
    blurView.layer.masksToBounds = YES;
    blurView.userInteractionEnabled = NO;
    [surface addSubview:blurView];

    [NSLayoutConstraint activateConstraints:@[
        [blurView.topAnchor constraintEqualToAnchor:surface.topAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor],
    ]];

    return surface;
}

- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color lines:(NSInteger)lines {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = lines;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.adjustsFontForContentSizeCategory = YES;
    return label;
}

- (UIButton *)createActionButtonWithTitle:(NSString *)title
                                imageName:(NSString *)imageName
                               emphasized:(BOOL)emphasized
                                 selector:(SEL)selector {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.layer.cornerRadius = kSPButtonHeight / 2.0;
    button.layer.masksToBounds = NO;
    button.layer.borderWidth = 0.65;
    button.titleLabel.font = [GM boldFontWithSize:13.2];
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.78;
    button.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    button.titleLabel.numberOfLines = 1;
    button.adjustsImageWhenHighlighted = NO;
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    button.tintColor = emphasized ? SPSellerSurfaceColor(self.traitCollection) : SPSellerInkColor();
    button.backgroundColor = emphasized ? SPSellerInkColor() : [SPSellerInkColor() colorWithAlphaComponent:0.045];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:(emphasized ? SPSellerSurfaceColor(self.traitCollection) : SPSellerInkColor()) forState:UIControlStateNormal];
    UIImage *image = PPSYSImage(imageName);
    [button setImage:image forState:UIControlStateNormal];
    button.imageView.contentMode = UIViewContentModeScaleAspectFit;
    button.contentEdgeInsets = UIEdgeInsetsMake(0.0, 12.0, 0.0, 12.0);
    button.imageEdgeInsets = UIEdgeInsetsMake(0.0, 2.0, 0.0, 2.0);
    button.titleEdgeInsets = UIEdgeInsetsMake(0.0, 4.0, 0.0, 4.0);
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:self action:@selector(handleButtonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(handleButtonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    return button;
}

- (void)pp_applyHeroActionStyleToButton:(UIButton *)button role:(SPSellerHeroActionRole)role
{
    if (!button) {
        return;
    }

    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    UIColor *foreground = SPSellerAppForegroundColor(self.traitCollection);
    UIColor *brand = SPSellerBrandAccentColor();
    UIColor *gold = SPSellerGoldColor();
    UIColor *primaryText = PPMarketplaceHeroCardPrimaryTextColor() ?: SPSellerInkColor();
    UIColor *titleColor = brand;
    UIColor *fillColor = [foreground colorWithAlphaComponent:dark ? 0.12 : 0.96];
    UIColor *borderColor = [primaryText colorWithAlphaComponent:dark ? 0.16 : 0.075];
    UIColor *shadowColor = UIColor.blackColor;
    CGFloat shadowOpacity = dark ? 0.0 : 0.035;
    CGFloat shadowRadius = 10.0;
    CGSize shadowOffset = CGSizeMake(0.0, 5.0);

    switch (role) {
        case SPSellerHeroActionRolePrimary:
            fillColor = brand;
            titleColor = UIColor.whiteColor;
            borderColor = [[UIColor whiteColor] colorWithAlphaComponent:dark ? 0.10 : 0.20];
            shadowColor = brand;
            shadowOpacity = dark ? 0.0 : 0.12;
            shadowRadius = 14.0;
            shadowOffset = CGSizeMake(0.0, 7.0);
            break;
        case SPSellerHeroActionRoleSecondary:
            fillColor = dark
                ? [[UIColor whiteColor] colorWithAlphaComponent:0.075]
                : [brand colorWithAlphaComponent:0.072];
            titleColor = brand;
            borderColor = [brand colorWithAlphaComponent:dark ? 0.25 : 0.18];
            break;
        case SPSellerHeroActionRoleTertiary:
            fillColor = dark
                ? [gold colorWithAlphaComponent:0.11]
                : [foreground colorWithAlphaComponent:0.96];
            titleColor = gold;
            borderColor = [gold colorWithAlphaComponent:dark ? 0.24 : 0.20];
            shadowColor = UIColor.blackColor;
            shadowOpacity = dark ? 0.0 : 0.035;
            shadowRadius = 11.0;
            shadowOffset = CGSizeMake(0.0, 5.0);
            break;
    }

    button.backgroundColor = fillColor;
    button.tintColor = titleColor;
    [button setTitleColor:titleColor forState:UIControlStateNormal];
    [button pp_setBorderColor:borderColor];
    button.layer.cornerRadius = kSPButtonHeight / 2.0;
    button.layer.borderWidth = role == SPSellerHeroActionRolePrimary ? 0.65 : 0.75;
    button.layer.shadowColor = shadowColor.CGColor;
    button.layer.shadowOpacity = shadowOpacity;
    button.layer.shadowRadius = shadowRadius;
    button.layer.shadowOffset = shadowOffset;
}



- (void)setupConstraints {
    UILayoutGuide *contentGuide;
    UILayoutGuide *frameGuide;
    if (@available(iOS 11.0, *)) {
        contentGuide = self.scrollView.contentLayoutGuide;
        frameGuide = self.scrollView.frameLayoutGuide;
    } else {
        contentGuide = (id)self.scrollView;
        frameGuide = (id)self.scrollView;
    }

    [NSLayoutConstraint activateConstraints:@[
        [self.heroSurfaceView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12.0],
        [self.heroSurfaceView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:kSPSpace16],
        [self.heroSurfaceView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-kSPSpace16],

        [self.topFadeView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:0.0],
        [self.topFadeView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.topFadeView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.topFadeView.heightAnchor constraintEqualToConstant:104.0],

        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.compactHeaderView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:6.0],
        [self.compactHeaderView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:kSPSpace16],
        [self.compactHeaderView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-kSPSpace16],
        [self.compactHeaderView.heightAnchor constraintEqualToConstant:60.0],

        [self.contentView.topAnchor constraintEqualToAnchor:contentGuide.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:contentGuide.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:contentGuide.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:contentGuide.bottomAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:frameGuide.widthAnchor],

        [self.avatarShellView.topAnchor constraintEqualToAnchor:self.heroBackButton.bottomAnchor constant:kSPSpace20],
        [self.avatarShellView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-kSPSpace24],
        [self.avatarShellView.widthAnchor constraintEqualToConstant:kSPAvatarShellSize],
        [self.avatarShellView.heightAnchor constraintEqualToConstant:kSPAvatarShellSize],

        [self.avatarInnerPlateView.centerXAnchor constraintEqualToAnchor:self.avatarShellView.centerXAnchor],
        [self.avatarInnerPlateView.centerYAnchor constraintEqualToAnchor:self.avatarShellView.centerYAnchor],
        [self.avatarInnerPlateView.widthAnchor constraintEqualToConstant:kSPAvatarSize],
        [self.avatarInnerPlateView.heightAnchor constraintEqualToConstant:kSPAvatarSize],

        [self.avatarImageView.topAnchor constraintEqualToAnchor:self.avatarInnerPlateView.topAnchor],
        [self.avatarImageView.leadingAnchor constraintEqualToAnchor:self.avatarInnerPlateView.leadingAnchor],
        [self.avatarImageView.trailingAnchor constraintEqualToAnchor:self.avatarInnerPlateView.trailingAnchor],
        [self.avatarImageView.bottomAnchor constraintEqualToAnchor:self.avatarInnerPlateView.bottomAnchor],

        [self.compactHeaderAvatarShellView.leadingAnchor constraintEqualToAnchor:self.compactHeaderView.leadingAnchor constant:10.0],
        [self.compactHeaderAvatarShellView.centerYAnchor constraintEqualToAnchor:self.compactHeaderView.centerYAnchor],
        [self.compactHeaderAvatarShellView.widthAnchor constraintEqualToConstant:40.0],
        [self.compactHeaderAvatarShellView.heightAnchor constraintEqualToConstant:40.0],

        [self.compactHeaderAvatarImageView.centerXAnchor constraintEqualToAnchor:self.compactHeaderAvatarShellView.centerXAnchor],
        [self.compactHeaderAvatarImageView.centerYAnchor constraintEqualToAnchor:self.compactHeaderAvatarShellView.centerYAnchor],
        [self.compactHeaderAvatarImageView.widthAnchor constraintEqualToConstant:32.0],
        [self.compactHeaderAvatarImageView.heightAnchor constraintEqualToConstant:32.0],

        [self.compactHeaderBadgeLabel.trailingAnchor constraintEqualToAnchor:self.compactHeaderView.trailingAnchor constant:-12.0],
        [self.compactHeaderBadgeLabel.centerYAnchor constraintEqualToAnchor:self.compactHeaderView.centerYAnchor],
        [self.compactHeaderBadgeLabel.heightAnchor constraintEqualToConstant:22.0],
        [self.compactHeaderBadgeLabel.widthAnchor constraintGreaterThanOrEqualToConstant:74.0],

        [self.compactHeaderTitleLabel.leadingAnchor constraintEqualToAnchor:self.compactHeaderAvatarShellView.trailingAnchor constant:12.0],
        [self.compactHeaderTitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.compactHeaderBadgeLabel.leadingAnchor constant:-10.0],
        [self.compactHeaderTitleLabel.centerYAnchor constraintEqualToAnchor:self.compactHeaderView.centerYAnchor],

        [self.eyebrowLabel.topAnchor constraintEqualToAnchor:self.avatarShellView.topAnchor],
        [self.eyebrowLabel.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:kSPSpace24],
        [self.eyebrowLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.avatarShellView.leadingAnchor constant:-kSPSpace16],

        [self.nameLabel.topAnchor constraintEqualToAnchor:self.eyebrowLabel.bottomAnchor constant:kSPSpace4],
        [self.nameLabel.leadingAnchor constraintEqualToAnchor:self.eyebrowLabel.leadingAnchor],
        [self.nameLabel.trailingAnchor constraintEqualToAnchor:self.eyebrowLabel.trailingAnchor],

        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:kSPSpace4],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.nameLabel.trailingAnchor],
        [self.subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.avatarShellView.bottomAnchor],

        [self.statusBadgeView.trailingAnchor constraintEqualToAnchor:self.avatarShellView.trailingAnchor constant:2.0],
        [self.statusBadgeView.bottomAnchor constraintEqualToAnchor:self.avatarShellView.bottomAnchor constant:2.0],
        [self.statusBadgeView.heightAnchor constraintEqualToConstant:22.0],
        [self.statusBadgeView.widthAnchor constraintEqualToConstant:22.0],

        [self.contactButtonStack.topAnchor constraintEqualToAnchor:self.avatarShellView.bottomAnchor constant:18.0],
        [self.contactButtonStack.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:kSPSpace24],
        [self.contactButtonStack.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-kSPSpace24],
        [self.contactButtonStack.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:-kSPSpace20],
        [self.messageButton.heightAnchor constraintEqualToConstant:kSPButtonHeight],
        [self.rateButton.heightAnchor constraintEqualToConstant:kSPButtonHeight],

        [self.itemsTitleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:kSPSpace16],
        [self.itemsTitleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:kSPSpace20],
        [self.itemsTitleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-kSPSpace20],

        [self.itemsActivityIndicator.topAnchor constraintEqualToAnchor:self.itemsTitleLabel.bottomAnchor constant:kSPSpace24],
        [self.itemsActivityIndicator.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],

        [self.itemsStateLabel.topAnchor constraintEqualToAnchor:self.itemsTitleLabel.bottomAnchor constant:kSPSpace20],
        [self.itemsStateLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:kSPSpace32],
        [self.itemsStateLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-kSPSpace32],

        [self.itemsRetryButton.topAnchor constraintEqualToAnchor:self.itemsStateLabel.bottomAnchor constant:kSPSpace16],
        [self.itemsRetryButton.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [self.itemsRetryButton.heightAnchor constraintEqualToConstant:50.0],
        [self.itemsRetryButton.widthAnchor constraintGreaterThanOrEqualToConstant:128.0],

        [self.itemsCollectionView.topAnchor constraintEqualToAnchor:self.itemsTitleLabel.bottomAnchor constant:kSPSpace16],
        [self.itemsCollectionView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:kSPSpace12],
        [self.itemsCollectionView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-kSPSpace12],
        [self.itemsCollectionView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-44.0],
    ]];

    self.collectionHeightConstraint = [self.itemsCollectionView.heightAnchor constraintEqualToConstant:0.0];
    self.collectionHeightConstraint.active = YES;
}

#pragma mark - Theme

- (void)applyTheme {
    self.view.backgroundColor = SPSellerBackgroundColor(self.traitCollection);
    UIColor *accent = PPMarketplaceHeroCardAccentColor();
    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;

    self.heroSurfaceView.backgroundColor = UIColor.clearColor;
    self.topFadeView.hidden = YES;
    self.topFadeView.alpha = 0.0;
    self.heroBottomFadeLayer.colors = @[
        (__bridge id)UIColor.clearColor.CGColor,
        (__bridge id)UIColor.clearColor.CGColor
    ];
    [self.heroSurfaceView pp_setBorderColor:UIColor.clearColor];
    self.heroSurfaceView.layer.borderWidth = 0.0;
    self.heroSurfaceView.layer.shadowOpacity = dark ? 0.14 : 0.050;
    self.heroSurfaceView.layer.shadowRadius = 18.0;
    self.heroSurfaceView.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    [self.heroGlassBackgroundView reapplyPalette];
    self.eyebrowLabel.textColor = accent;
    self.nameLabel.textColor = PPMarketplaceHeroCardPrimaryTextColor();
    self.subtitleLabel.textColor = PPMarketplaceHeroCardSecondaryTextColor();
    self.descriptionLabel.textColor = PPMarketplaceHeroCardSecondaryTextColor();
    self.avatarBreathingHaloView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.20 : 0.12];
    self.avatarBreathingHaloView.layer.shadowColor = accent.CGColor;
    self.avatarBreathingHaloView.layer.shadowOpacity = dark ? 0.10 : 0.13;
    self.avatarBreathingHaloView.layer.shadowRadius = 22.0;
    self.avatarBreathingHaloView.layer.shadowOffset = CGSizeZero;
    self.avatarShellView.backgroundColor = SPSellerHeroAvatarShellColor(self.traitCollection);
    self.avatarShellView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.avatarShellView.layer.shadowOpacity = dark ? 0.0 : 0.075;
    self.avatarShellView.layer.shadowRadius = 18.0;
    self.avatarShellView.layer.shadowOffset = CGSizeMake(0.0, 9.0);
    [self.avatarShellView pp_setBorderColor:[SPSellerHeroAvatarStrokeColor(self.traitCollection) colorWithAlphaComponent:dark ? 0.62 : 0.42]];
    self.avatarInnerPlateView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:dark ? 0.12 : 0.92];
    [self.avatarInnerPlateView pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:dark ? 0.10 : 0.70]];
    self.compactHeaderView.backgroundColor = [SPSellerSurfaceColor(self.traitCollection) colorWithAlphaComponent:0.88];
    [self.compactHeaderView pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.12 : 0.44]];
    self.compactHeaderView.layer.shadowOpacity = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.18 : 0.06;
    self.compactHeaderAvatarShellView.backgroundColor = [SPSellerSurfaceColor(self.traitCollection) colorWithAlphaComponent:0.94];
    self.compactHeaderAvatarShellView.layer.cornerRadius = 20.0;
    [self.compactHeaderAvatarShellView pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.10 : 0.44]];
    self.compactHeaderAvatarImageView.layer.cornerRadius = 16.0;
    self.compactHeaderTitleLabel.textColor = SPSellerInkColor();
    self.compactHeaderBadgeLabel.textColor = SPSellerAccentTealColor();
    self.compactHeaderBadgeLabel.backgroundColor = [SPSellerAccentTealColor() colorWithAlphaComponent:0.10];
    [self.compactHeaderBadgeLabel pp_setBorderColor:[SPSellerAccentTealColor() colorWithAlphaComponent:0.16]];
    self.statusBadgeView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.98];
    [self.statusBadgeView pp_setBorderColor:[AppForgroundColr colorWithAlphaComponent:0.98]];
    [self pp_applyHeroActionStyleToButton:self.messageButton role:SPSellerHeroActionRolePrimary];
    [self pp_applyHeroActionStyleToButton:self.callButton role:SPSellerHeroActionRoleSecondary];
    [self pp_applyHeroActionStyleToButton:self.rateButton role:SPSellerHeroActionRoleTertiary];
    self.callButton.hidden = YES;
    self.callButton.enabled = NO;
    self.callButton.alpha = 0.0;
    self.callButton.accessibilityElementsHidden = YES;
    self.itemsRetryButton.backgroundColor = SPSellerInkColor();
    [self.itemsRetryButton setTitleColor:SPSellerSurfaceColor(self.traitCollection) forState:UIControlStateNormal];
    [self pp_updatePremiumBackgroundGlowAppearance];
}

- (void)applySemanticDirection {
    UISemanticContentAttribute semantic = [Language semanticAttributeForCurrentLanguage];
    self.view.semanticContentAttribute = semantic;
     self.compactHeaderTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;

    NSArray<UILabel *> *labels = @[
        self.eyebrowLabel,
        self.nameLabel,
        self.subtitleLabel,
        self.descriptionLabel,
        self.itemsTitleLabel,
        self.itemsStateLabel,
        self.compactHeaderTitleLabel
    ];
    for (UILabel *label in labels) {
        label.textAlignment = Language.alignmentForCurrentLanguage;
    }

    
}

#pragma mark - Data

- (BOOL)pp_isProviderStorefrontMode
{
    return SPSellerNormalizedCategoryIdentifier(self.providerCategoryIdentifier).length > 0;
}

- (BOOL)pp_isPharmacyStorefront
{
    return [self pp_isProviderStorefrontMode] && SPSellerIsPharmacyCategory(self.providerCategoryIdentifier);
}

- (NSString *)pp_categoryTitleText
{
    if (![self pp_isProviderStorefrontMode]) {
        return kLang(@"premium_seller") ?: @"Premium Seller";
    }
    return [self pp_isPharmacyStorefront]
        ? (kLang(@"provider_pharmacies_title") ?: @"Pharmacies")
        : (kLang(@"provider_marketplace_title") ?: @"Marketplace");
}

- (NSString *)pp_categorySupportText
{
    if (![self pp_isProviderStorefrontMode]) {
        return kLang(@"premium_seller_on_platform") ?: @"Premium seller on platform";
    }
    return [self pp_isPharmacyStorefront]
        ? (kLang(@"provider_storefront_subtitle_pharmacy") ?: @"Curated pet medicines prepared by trusted pharmacies.")
        : (kLang(@"provider_storefront_subtitle_marketplace") ?: @"Browse trusted pet essentials from this provider.");
}

- (NSString *)pp_storefrontDescriptionText
{
    if (![self pp_isProviderStorefrontMode]) {
        return kLang(@"premium_seller_description") ?: @"A trusted seller offering high-quality products with excellent customer service.";
    }
    return [self pp_isPharmacyStorefront]
        ? (kLang(@"provider_storefront_description_pharmacy") ?: @"Each medicine here belongs to this pharmacy only and stays in the existing cart flow.")
        : (kLang(@"provider_storefront_description_marketplace") ?: @"Only this provider’s published products appear here, with the same viewer and cart behavior you already use.");
}

- (NSString *)pp_itemsTitleText
{
    if (![self pp_isProviderStorefrontMode]) {
        return kLang(@"seller_items") ?: @"Seller's Items";
    }
    return [self pp_isPharmacyStorefront]
        ? (kLang(@"provider_storefront_items_title_pharmacy") ?: @"Available medicines")
        : (kLang(@"provider_storefront_items_title_marketplace") ?: @"Available products");
}

- (NSString *)pp_emptyItemsText
{
    if (![self pp_isProviderStorefrontMode]) {
        return kLang(@"seller_profile_empty_items") ?: @"No available items from this seller right now.";
    }
    return [self pp_isPharmacyStorefront]
        ? (kLang(@"provider_storefront_empty_pharmacy") ?: @"No medicines are available from this pharmacy right now.")
        : (kLang(@"provider_storefront_empty_marketplace") ?: @"No products are available from this provider right now.");
}

- (NSString *)pp_statusBadgeText
{
    if (![self pp_isProviderStorefrontMode]) {
        return kLang(@"verified") ?: @"Verified";
    }
    if (self.seller.isVerified) {
        return kLang(@"verified") ?: @"Verified";
    }

    if ([PPSafeString(self.seller.accountStatus) isEqualToString:@"active"]) {
        return kLang(@"provider_company_status_active") ?: @"Active";
    }

    return @"";
}

- (UIColor *)pp_statusBadgeColor
{
    if (self.seller.isVerified) {
        return [UIColor colorWithRed:0.14 green:0.52 blue:0.34 alpha:1.0];
    }
    return SPSellerAccentTealColor();
}

- (void)configureSellerIdentity {
    self.eyebrowLabel.text = [self pp_categoryTitleText];
    self.nameLabel.text = [self sellerDisplayName];
    self.subtitleLabel.text = self.seller.UserAbout.length > 0 ? self.seller.UserAbout : [self pp_categorySupportText];
    NSString *statusText = [self pp_statusBadgeText];
    self.statusBadgeView.hidden = (statusText.length == 0);
    self.statusBadgeView.accessibilityLabel = statusText;
    UIColor *statusColor = [self pp_statusBadgeColor];
    NSString *statusSymbol = self.seller.isVerified ? @"checkmark.seal.fill" : @"circle.fill";
    self.statusBadgeIconView.image =
        [[UIImage systemImageNamed:statusSymbol
                 withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:self.seller.isVerified ? 15.0 : 9.0
                                                                                   weight:UIImageSymbolWeightBold]]
         imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.statusBadgeIconView.tintColor = statusColor;
    self.statusBadgeView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.98] ?: UIColor.systemBackgroundColor;
    [self.statusBadgeView pp_setBorderColor:[AppForgroundColr colorWithAlphaComponent:0.98] ?: UIColor.whiteColor];
    self.descriptionLabel.text = [self pp_storefrontDescriptionText];
    self.itemsTitleLabel.text = [self pp_itemsTitleText];
    [self.itemsRetryButton setTitle:(kLang(@"provider_retry") ?: @"Retry") forState:UIControlStateNormal];
    self.compactHeaderTitleLabel.text = [self sellerDisplayName];
    self.compactHeaderBadgeLabel.text = [NSString stringWithFormat:@"  %@  ", [self pp_categoryTitleText]];

    UIImage *placeholder = [PPModernAvatarRenderer avatarImageForName:[self sellerDisplayName] size:kSPAvatarSize];
    self.avatarImageView.image = placeholder ?: PPSYSImage(@"person.crop.circle.fill");
    UIImage *compactPlaceholder = [PPModernAvatarRenderer avatarImageForName:[self sellerDisplayName] size:32.0];
    self.compactHeaderAvatarImageView.image = compactPlaceholder ?: self.avatarImageView.image;

    NSString *imageURL = PPSafeString(self.seller.UserImageUrl.absoluteString);
    if (imageURL.length > 0) {
        [PPImageLoaderManager.shared setImageOnImageView:self.avatarImageView
                                                     url:imageURL
                                             placeholder:self.avatarImageView.image
                                              complation:nil];
        [PPImageLoaderManager.shared setImageOnImageView:self.compactHeaderAvatarImageView
                                                     url:imageURL
                                             placeholder:self.compactHeaderAvatarImageView.image
                                              complation:nil];
    }

    BOOL canContact = self.seller != nil;
    self.messageButton.enabled = canContact;
    self.messageButton.alpha = canContact ? 1.0 : 0.48;
    self.callButton.hidden = YES;
    self.callButton.enabled = NO;
    self.callButton.alpha = 0.0;
    self.callButton.accessibilityElementsHidden = YES;
    [self pp_updateRateButtonState];
    [self updateAccessibility];
    [self pp_updateCollapsibleHeaderForScrollOffset:self.scrollView.contentOffset.y animated:NO];
}

- (NSString *)sellerDisplayName {
    if (!self.seller) return kLang(@"premium_seller");

    NSMutableArray<NSString *> *nameParts = [NSMutableArray array];
    if (self.seller.FirstName.length > 0) [nameParts addObject:self.seller.FirstName];
    if (self.seller.LastName.length > 0) [nameParts addObject:self.seller.LastName];
    if (nameParts.count > 0) return [nameParts componentsJoinedByString:@" "];

    if ([self.seller respondsToSelector:@selector(bestDisplayName)]) {
        NSString *name = [self.seller bestDisplayName];
        if (name.length > 0) return name;
    }
    if ([self.seller respondsToSelector:@selector(PPBestDisplayName)]) {
        NSString *name = [self.seller PPBestDisplayName];
        if (name.length > 0) return name;
    }
    if (self.seller.UserName.length > 0) return self.seller.UserName;
    return kLang(@"premium_seller");
}

- (NSString *)sellerID {
    return PPSafeString(self.seller.ID);
}

#pragma mark - Provider Rating

- (NSString *)pp_currentRatingUserID
{
    NSString *authUID = [FIRAuth auth].currentUser.uid ?: @"";
    return authUID.length > 0 ? authUID : PPSafeString([UserManager sharedManager].currentUser.ID);
}

- (BOOL)pp_isCurrentUserSeller
{
    NSString *currentUID = [self pp_currentRatingUserID];
    return currentUID.length > 0 && [[self sellerID] isEqualToString:currentUID];
}

- (void)pp_startProviderRatingListener
{
    [self.providerRatingListener remove];
    self.providerRatingListener = nil;

    NSString *providerID = [self sellerID];
    if (providerID.length == 0 || ![UserManager sharedManager].isUserLoggedIn) {
        [self pp_updateRateButtonState];
        return;
    }

    FIRDocumentReference *providerRef =
        [[[FIRFirestore firestore] collectionWithPath:@"UsersCol"] documentWithPath:providerID];
    __weak typeof(self) weakSelf = self;
    self.providerRatingListener =
        [providerRef addSnapshotListener:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
            if (error || !snapshot.exists) {
                return;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf || ![[strongSelf sellerID] isEqualToString:providerID]) {
                    return;
                }
                NSDictionary *data = snapshot.data ?: @{};
                strongSelf.seller.providerRatingValue =
                    MAX(0.0, MIN(5.0, [data[@"providerRatingValue"] doubleValue]));
                strongSelf.seller.providerReviewCount =
                    MAX(0, PPSafeIntegerUniversal(data[@"providerReviewCount"]));
                [strongSelf pp_updateRateButtonState];
                [strongSelf updateAccessibility];
            });
        }];
}

- (void)pp_refreshRatingEligibilityWithCompletion:(void (^ _Nullable)(BOOL eligible))completion
{
    NSString *providerID = [self sellerID];
    NSString *currentUID = [self pp_currentRatingUserID];
    if (providerID.length == 0 || currentUID.length == 0 || ![UserManager sharedManager].isUserLoggedIn) {
        self.ratingEligibilityLoaded = YES;
        self.isCheckingRatingEligibility = NO;
        self.canRateProvider = NO;
        self.hasExistingProviderReview = NO;
        self.ratingEligibilityUID = currentUID ?: @"";
        [self pp_updateRateButtonState];
        if (completion) completion(NO);
        return;
    }

    if ([providerID isEqualToString:currentUID]) {
        self.ratingEligibilityLoaded = YES;
        self.isCheckingRatingEligibility = NO;
        self.canRateProvider = NO;
        self.hasExistingProviderReview = NO;
        self.ratingEligibilityUID = currentUID;
        [self pp_updateRateButtonState];
        if (completion) completion(NO);
        return;
    }

    if (self.isCheckingRatingEligibility) {
        return;
    }
    if (self.ratingEligibilityLoaded && [self.ratingEligibilityUID isEqualToString:currentUID]) {
        if (completion) completion(self.canRateProvider);
        return;
    }

    self.isCheckingRatingEligibility = YES;
    self.ratingEligibilityLoaded = NO;
    self.ratingEligibilityUID = currentUID;
    [self pp_updateRateButtonState];

    FIRHTTPSCallable *callable =
        [[FIRFunctions functionsForRegion:@"us-central1"] HTTPSCallableWithName:@"getProviderReviewEligibility"];
    __weak typeof(self) weakSelf = self;
    [callable callWithObject:@{@"providerID": providerID}
                  completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf ||
                ![[strongSelf sellerID] isEqualToString:providerID] ||
                ![[strongSelf pp_currentRatingUserID] isEqualToString:currentUID]) {
                return;
            }

            strongSelf.isCheckingRatingEligibility = NO;
            if (error || ![result.data isKindOfClass:NSDictionary.class]) {
                strongSelf.ratingEligibilityLoaded = NO;
                strongSelf.canRateProvider = NO;
                [strongSelf pp_updateRateButtonState];
                if (completion) completion(NO);
                return;
            }

            NSDictionary *data = (NSDictionary *)result.data;
            strongSelf.ratingEligibilityLoaded = YES;
            strongSelf.canRateProvider = [data[@"eligible"] boolValue];
            strongSelf.hasExistingProviderReview = [data[@"hasReview"] boolValue];
            strongSelf.existingProviderRating = MAX(0, MIN(5, [data[@"rating"] integerValue]));
            strongSelf.existingProviderReviewComment = PPSafeString(data[@"comment"]);
            strongSelf.seller.providerRatingValue =
                MAX(0.0, MIN(5.0, [data[@"providerRatingValue"] doubleValue]));
            strongSelf.seller.providerReviewCount =
                MAX(0, [data[@"providerReviewCount"] integerValue]);
            [strongSelf pp_updateRateButtonState];
            [strongSelf updateAccessibility];
            if (completion) completion(strongSelf.canRateProvider);
        });
    }];
}

- (void)pp_updateRateButtonState
{
    if (!self.rateButton) {
        return;
    }

    BOOL isOwner = [self pp_isCurrentUserSeller];
    BOOL loggedIn = [UserManager sharedManager].isUserLoggedIn;
    self.rateButton.hidden = isOwner || [self sellerID].length == 0;

    NSString *title = kLang(@"provider_rating_action") ?: @"Rate provider";
    NSString *symbolName = @"star.fill";
    if (self.isCheckingRatingEligibility || self.isSubmittingProviderReview) {
        title = self.isSubmittingProviderReview
            ? (kLang(@"provider_rating_submitting") ?: @"Submitting")
            : (kLang(@"provider_rating_checking") ?: @"Checking");
        symbolName = @"clock";
    } else if (loggedIn && self.ratingEligibilityLoaded && !self.canRateProvider) {
        title = kLang(@"provider_rating_purchase_required_short") ?: @"Rate after purchase";
        symbolName = @"lock.fill";
    } else if (self.hasExistingProviderReview) {
        title = kLang(@"provider_rating_update_action") ?: @"Update rating";
        symbolName = @"star.circle.fill";
    } else if (self.seller.providerReviewCount > 0 && self.seller.providerRatingValue > 0.0) {
        NSString *format = kLang(@"provider_rating_action_score_format") ?: @"%.1f · Rate";
        title = [NSString stringWithFormat:format, self.seller.providerRatingValue];
    }

    BOOL shouldAllowWrappedRateTitle = NO;
    self.rateButton.titleLabel.numberOfLines = shouldAllowWrappedRateTitle ? 2 : 1;
    self.rateButton.titleLabel.lineBreakMode = shouldAllowWrappedRateTitle
        ? NSLineBreakByWordWrapping
        : NSLineBreakByTruncatingTail;
    [self.rateButton setTitle:title forState:UIControlStateNormal];
    [self.rateButton setImage:PPSYSImage(symbolName) forState:UIControlStateNormal];
    self.rateButton.enabled = !self.isCheckingRatingEligibility && !self.isSubmittingProviderReview;
    self.rateButton.alpha = self.rateButton.enabled ? 1.0 : 0.54;
}

- (void)handleRateProviderTap
{
    if (![UserManager sharedManager].isUserLoggedIn || [self pp_currentRatingUserID].length == 0) {
        [UserManager showPromptOnTopController];
        return;
    }
    if ([self pp_isCurrentUserSeller]) {
        [PPHUD showInfo:kLang(@"provider_rating_owner_block") ?: @"You cannot rate your own storefront."];
        return;
    }
    if (self.isCheckingRatingEligibility || self.isSubmittingProviderReview) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    void (^continueWithEligibility)(BOOL) = ^(BOOL eligible) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (!strongSelf.ratingEligibilityLoaded) {
            [PPHUD showError:(kLang(@"provider_rating_check_failed") ?: @"Couldn’t verify purchase")
                    subtitle:(kLang(@"provider_rating_check_failed_subtitle") ?: @"Check your connection and try again.")];
            return;
        }
        if (!eligible) {
            [PPHUD showInfo:(kLang(@"provider_rating_purchase_required_title") ?: @"Purchase required")
                   subtitle:(kLang(@"provider_rating_purchase_required_subtitle") ?: @"Only customers who bought from this provider can submit a rating.")];
            return;
        }
        [strongSelf pp_presentProviderRatingSheet];
    };

    if (!self.ratingEligibilityLoaded) {
        [self pp_refreshRatingEligibilityWithCompletion:continueWithEligibility];
        return;
    }
    continueWithEligibility(self.canRateProvider);
}

- (void)pp_presentProviderRatingSheet
{
    __weak typeof(self) weakSelf = self;
    __block __weak SPProviderRatingSheetViewController *weakSheet = nil;
    SPProviderRatingSheetViewController *sheet =
        [[SPProviderRatingSheetViewController alloc] initWithProviderName:[self sellerDisplayName]
                                                            currentRating:self.existingProviderRating
                                                           currentComment:self.existingProviderReviewComment
                                                                   submit:^(NSInteger rating, NSString *comment) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        SPProviderRatingSheetViewController *ratingSheet = weakSheet;
        if (!strongSelf || !ratingSheet) return;
        [strongSelf pp_submitProviderRating:rating comment:comment sheet:ratingSheet];
    }];
    weakSheet = sheet;

    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *presentation = sheet.sheetPresentationController;
        presentation.detents = @[UISheetPresentationControllerDetent.largeDetent];
        presentation.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierLarge;
        presentation.prefersGrabberVisible = YES;
        presentation.preferredCornerRadius = 28.0;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)pp_submitProviderRating:(NSInteger)rating
                         comment:(NSString *)comment
                           sheet:(SPProviderRatingSheetViewController *)sheet
{
    NSString *providerID = [self sellerID];
    if (providerID.length == 0 || rating < 1 || rating > 5) {
        return;
    }

    self.isSubmittingProviderReview = YES;
    [sheet setSubmitting:YES];
    [self pp_updateRateButtonState];

    FIRHTTPSCallable *callable =
        [[FIRFunctions functionsForRegion:@"us-central1"] HTTPSCallableWithName:@"submitProviderReview"];
    NSDictionary *payload = @{
        @"providerID": providerID,
        @"rating": @(rating),
        @"comment": comment ?: @"",
        @"platform": @"ios"
    };

    BOOL wasExistingReview = self.hasExistingProviderReview;
    NSInteger previousRating = self.existingProviderRating;
    __weak typeof(self) weakSelf = self;
    [callable callWithObject:payload
                  completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            strongSelf.isSubmittingProviderReview = NO;
            [sheet setSubmitting:NO];
            if (error || ![result.data isKindOfClass:NSDictionary.class]) {
                if (error.code == FIRFunctionsErrorCodePermissionDenied) {
                    strongSelf.ratingEligibilityLoaded = YES;
                    strongSelf.canRateProvider = NO;
                    [PPHUD showInfo:(kLang(@"provider_rating_purchase_required_title") ?: @"Purchase required")
                           subtitle:(kLang(@"provider_rating_purchase_required_subtitle") ?: @"Only customers who bought from this provider can submit a rating.")];
                } else {
                    [PPHUD showError:(kLang(@"provider_rating_failed") ?: @"Couldn’t submit rating")
                            subtitle:(kLang(@"provider_rating_failed_subtitle") ?: @"Please try again in a moment.")];
                }
                [strongSelf pp_updateRateButtonState];
                return;
            }

            NSInteger oldCount = MAX(0, strongSelf.seller.providerReviewCount);
            double oldAverage = MAX(0.0, MIN(5.0, strongSelf.seller.providerRatingValue));
            if (wasExistingReview && oldCount > 0 && previousRating > 0) {
                strongSelf.seller.providerRatingValue =
                    MAX(0.0, MIN(5.0, ((oldAverage * oldCount) - previousRating + rating) / oldCount));
            } else {
                strongSelf.seller.providerRatingValue =
                    ((oldAverage * oldCount) + rating) / (double)(oldCount + 1);
                strongSelf.seller.providerReviewCount = oldCount + 1;
            }

            strongSelf.ratingEligibilityLoaded = YES;
            strongSelf.canRateProvider = YES;
            strongSelf.hasExistingProviderReview = YES;
            strongSelf.existingProviderRating = rating;
            strongSelf.existingProviderReviewComment = comment ?: @"";
            [strongSelf pp_updateRateButtonState];
            [strongSelf updateAccessibility];

            UINotificationFeedbackGenerator *feedback = [[UINotificationFeedbackGenerator alloc] init];
            [feedback notificationOccurred:UINotificationFeedbackTypeSuccess];
            [sheet dismissViewControllerAnimated:YES completion:^{
                [PPHUD showSuccess:(kLang(@"provider_rating_success") ?: @"Rating submitted")
                          subtitle:(kLang(@"provider_rating_success_subtitle") ?: @"Thank you for sharing a verified purchase experience.")];
            }];
        });
    }];
}

- (void)fetchSellerItemsIfNeeded {
    NSString *sellerID = [self sellerID];
    if (sellerID.length == 0 || self.didRequestSellerItems) {
        if (self.sellerItems.count == 0) {
            [self applySellerItems:@[] loading:NO error:nil];
        }
        return;
    }

    self.didRequestSellerItems = YES;
    self.itemsLoadError = nil;
    if (self.sellerItems.count == 0) {
        [self applySellerItems:@[] loading:YES error:nil];
    }

    __weak typeof(self) weakSelf = self;
    void (^completion)(NSArray<PetAccessory *> *, NSError * _Nullable) = ^(NSArray<PetAccessory *> *accessories, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            NSArray<PetAccessory *> *mergedItems = [strongSelf mergedItemsWithFetchedItems:accessories ?: @[]];
            strongSelf->_sellerItems = [mergedItems copy];
            [strongSelf applySellerItems:mergedItems loading:NO error:error];
        });
    };

    if ([self pp_isPharmacyStorefront]) {
        [PetAccessoryManager fetchProviderPharmacyAccessoriesForOwnerID:sellerID
                                                      excludingAccessory:nil
                                                     completionWithError:completion];
    } else {
        [PetAccessoryManager fetchProviderMarketplaceAccessoriesForOwnerID:sellerID
                                                         excludingAccessory:nil
                                                        completionWithError:completion];
    }
}

- (NSArray<PetAccessory *> *)mergedItemsWithFetchedItems:(NSArray<PetAccessory *> *)fetchedItems {
    NSMutableArray<PetAccessory *> *items = [NSMutableArray array];
    NSMutableSet<NSString *> *seenIDs = [NSMutableSet set];

    void (^appendItem)(PetAccessory *) = ^(PetAccessory *item) {
        if (![self shouldDisplayAccessory:item]) return;
        NSString *itemID = PPSafeString(item.accessoryID);
        if (itemID.length > 0 && [seenIDs containsObject:itemID]) return;
        if (itemID.length > 0) [seenIDs addObject:itemID];
        [items addObject:item];
    };

    for (PetAccessory *item in self.sellerItems) appendItem(item);
    for (PetAccessory *item in fetchedItems) appendItem(item);
    return items.copy;
}

- (BOOL)shouldDisplayAccessory:(PetAccessory *)item {
    if (![item isKindOfClass:PetAccessory.class]) return NO;
    if (item.isBlocked || item.isDeleted || item.isDisabled) return NO;
    NSString *sellerID = [self sellerID];
    if (sellerID.length > 0 && item.ownerID.length > 0 && ![item.ownerID isEqualToString:sellerID]) {
        return NO;
    }
    if (![self pp_isProviderStorefrontMode]) {
        return YES;
    }
    if ([self pp_isPharmacyStorefront]) {
        return item.accessKindType == AccessTypePetMedicine;
    }
    return (item.accessKindType == AccessTypeAccessory || item.accessKindType == AccessTypeFood) && item.showInAppMarket;
}

- (void)applySellerItems:(NSArray<PetAccessory *> *)items loading:(BOOL)loading {
    [self applySellerItems:items loading:loading error:nil];
}

- (void)applySellerItems:(NSArray<PetAccessory *> *)items
                 loading:(BOOL)loading
                   error:(NSError * _Nullable)error
{
    self.itemsLoadError = error;
    [self.itemViewModels removeAllObjects];
    [self.animatedItemIndexes removeAllObjects];

    for (PetAccessory *item in items) {
        if (![self shouldDisplayAccessory:item]) continue;
        PPCellContext context = item.accessKindType == AccessTypeFood ? PPCellForFood : PPCellForMarket;
        PPUniversalCellViewModel *viewModel = [[PPUniversalCellViewModel alloc] initWithModel:item context:context];
        [self.itemViewModels addObject:viewModel];
    }

    BOOL hasItems = self.itemViewModels.count > 0;
    BOOL showsError = (!loading && error != nil && !hasItems);
    self.itemsCollectionView.hidden = !hasItems;
    self.itemsStateLabel.hidden = hasItems || loading;
    self.itemsStateLabel.text = hasItems ? @"" : (showsError
                                                  ? (kLang(@"provider_storefront_error_message") ?: @"We couldn’t load this storefront right now.")
                                                  : [self pp_emptyItemsText]);
    self.itemsRetryButton.hidden = !showsError;

    if (loading) {
        [self.itemsActivityIndicator startAnimating];
    } else {
        [self.itemsActivityIndicator stopAnimating];
    }

    [self.itemsCollectionView reloadData];
    [self updateCollectionHeight];
}

- (void)handleRetryItemsTap
{
    self.didRequestSellerItems = NO;
    self.itemsLoadError = nil;
    [self fetchSellerItemsIfNeeded];
}

#pragma mark - Layout Helpers

- (void)layoutGlowViews {
    [self pp_layoutPremiumBackgroundGlowViews];
}

- (void)pp_applyPremiumSellerBackgroundAppearance
{
    UIColor *backgroundColor = SPSellerBackgroundColor(self.traitCollection);
    self.view.backgroundColor = backgroundColor;
    [self pp_installPremiumBackgroundGlowViewsIfNeeded];
    self.pp_premiumBackgroundCanvasView.backgroundColor = backgroundColor;
    self.scrollView.backgroundColor = UIColor.clearColor;
    [self pp_updatePremiumBackgroundGlowAppearance];
}

- (SPSellerAmbientGlowView *)pp_makePremiumBackgroundGlowView
{
    return [[SPSellerAmbientGlowView alloc] initWithFrame:CGRectZero];
}

- (void)pp_installPremiumBackgroundGlowViewsIfNeeded
{
    if (!self.pp_premiumBackgroundCanvasView) {
        UIView *canvasView = [[UIView alloc] initWithFrame:CGRectZero];
        canvasView.translatesAutoresizingMaskIntoConstraints = NO;
        canvasView.userInteractionEnabled = NO;
        canvasView.isAccessibilityElement = NO;
        canvasView.accessibilityElementsHidden = YES;
        canvasView.clipsToBounds = YES;
        canvasView.opaque = YES;
        self.pp_premiumBackgroundCanvasView = canvasView;
        [self.view insertSubview:canvasView atIndex:0];
        [NSLayoutConstraint activateConstraints:@[
            [canvasView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
            [canvasView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [canvasView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
            [canvasView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
        ]];
    } else if (self.pp_premiumBackgroundCanvasView.superview != self.view) {
        [self.view insertSubview:self.pp_premiumBackgroundCanvasView atIndex:0];
    }

    if (!self.pp_premiumBackgroundGlowViewTop) {
        self.pp_premiumBackgroundGlowViewTop = [self pp_makePremiumBackgroundGlowView];
    }
    if (!self.pp_premiumBackgroundGlowViewMid) {
        self.pp_premiumBackgroundGlowViewMid = [self pp_makePremiumBackgroundGlowView];
    }
    if (!self.pp_premiumBackgroundGlowViewBottom) {
        self.pp_premiumBackgroundGlowViewBottom = [self pp_makePremiumBackgroundGlowView];
    }

    for (SPSellerAmbientGlowView *glowView in @[
        self.pp_premiumBackgroundGlowViewBottom,
        self.pp_premiumBackgroundGlowViewMid,
        self.pp_premiumBackgroundGlowViewTop
    ]) {
        if (glowView.superview != self.pp_premiumBackgroundCanvasView) {
            [self.pp_premiumBackgroundCanvasView addSubview:glowView];
        }
    }

    [self.view sendSubviewToBack:self.pp_premiumBackgroundCanvasView];
}

- (void)pp_applyPremiumGlowView:(SPSellerAmbientGlowView *)glowView
                          color:(UIColor *)color
                      peakAlpha:(CGFloat)peakAlpha
                    middleAlpha:(CGFloat)middleAlpha
{
    if (!glowView || !color) {
        return;
    }

    glowView.alpha = 1.0;
    UIColor *resolvedColor = color;
    if (@available(iOS 13.0, *)) {
        resolvedColor = [color resolvedColorWithTraitCollection:self.traitCollection];
    }
    glowView.faded = self.backgroundGlowsFadedByHomeConfig;
    [glowView setNeedsLayout];
    [glowView applyColor:resolvedColor peakAlpha:peakAlpha middleAlpha:middleAlpha];
}

- (void)pp_updatePremiumBackgroundGlowAppearance
{
    BOOL isDark = NO;
    if (@available(iOS 12.0, *)) {
        isDark = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    }

    BOOL reduceTransparency = UIAccessibilityIsReduceTransparencyEnabled();
    BOOL increaseContrast = UIAccessibilityDarkerSystemColorsEnabled();
    CGFloat accessibilityScale = (reduceTransparency || increaseContrast) ? 0.70 : 1.0;

    UIColor *signatureColor = AppPrimaryClr ?: [UIColor colorWithRed:0.92 green:0.16 blue:0.42 alpha:1.0];
    UIColor *supportingColor = AppForgroundColr ?: signatureColor;
    UIColor *topAtmosphereColor = SPSellerSurfaceColor(self.traitCollection);
    [self pp_applyPremiumGlowView:self.pp_premiumBackgroundGlowViewTop
                            color:topAtmosphereColor
                        peakAlpha:(isDark ? 0.050 : 0.018) * accessibilityScale
                      middleAlpha:(isDark ? 0.025 : 0.010) * accessibilityScale];

    [self pp_applyPremiumGlowView:self.pp_premiumBackgroundGlowViewMid
                            color:supportingColor
                        peakAlpha:(isDark ? 0.050 : 0.014) * accessibilityScale
                      middleAlpha:(isDark ? 0.018 : 0.008) * accessibilityScale];

    [self pp_applyPremiumGlowView:self.pp_premiumBackgroundGlowViewBottom
                            color:signatureColor
                        peakAlpha:(isDark ? 0.090 : 0.016) * accessibilityScale
                      middleAlpha:(isDark ? 0.032 : 0.010) * accessibilityScale];
}

- (void)pp_layoutPremiumBackgroundGlowViews
{
    CGRect bounds = self.view.bounds;
    if (CGRectIsEmpty(bounds)) {
        return;
    }

    CGFloat width = CGRectGetWidth(bounds);
    CGFloat height = CGRectGetHeight(bounds);
    CGFloat safeTop = self.view.safeAreaInsets.top;
    CGSize canvasSize = bounds.size;
    BOOL motionLayoutChanged = (fabs(canvasSize.width - self.premiumBackgroundGlowMotionCanvasSize.width) > 0.5 ||
                                fabs(canvasSize.height - self.premiumBackgroundGlowMotionCanvasSize.height) > 0.5);
    if (motionLayoutChanged && self.livingBackgroundActive) {
        [self stopLivingBackground];
    }
    self.premiumBackgroundGlowMotionCanvasSize = canvasSize;

    CGFloat topSize = MIN(178.0, MAX(132.0, width * 0.46));
    CGFloat midSize = MIN(238.0, MAX(150.0, width * 0.62));
    CGFloat bottomSize = MIN(220.0, MAX(176.0, width * 0.72));
    BOOL isRTL = self.view.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    self.pp_premiumBackgroundGlowViewTop.bounds = CGRectMake(0.0, 0.0, topSize, topSize);
    self.pp_premiumBackgroundGlowViewTop.center = CGPointMake(
        isRTL ? topSize * 0.22 : width - (topSize * 0.22),
        safeTop + (topSize * 0.05)
    );

    self.pp_premiumBackgroundGlowViewMid.bounds = CGRectMake(0.0, 0.0, midSize, midSize);
    CGFloat middleY = MAX(210.0, height * 0.54);
    if (self.backgroundGlowsFadedByHomeConfig) {
        self.pp_premiumBackgroundGlowViewMid.center = CGPointMake(CGRectGetMidX(bounds), middleY);
    } else {
        self.pp_premiumBackgroundGlowViewMid.center = CGPointMake(
            isRTL ? width - (midSize * 0.10) : midSize * 0.10,
            middleY
        );
    }

    self.pp_premiumBackgroundGlowViewBottom.bounds = CGRectMake(0.0, 0.0, bottomSize, bottomSize);
    self.pp_premiumBackgroundGlowViewBottom.center = CGPointMake(
        isRTL ? bottomSize * 0.34 : width - (bottomSize * 0.34),
        height - (bottomSize * 0.03)
    );

    [CATransaction commit];

    [self.pp_premiumBackgroundGlowViewTop setNeedsLayout];
    [self.pp_premiumBackgroundGlowViewMid setNeedsLayout];
    [self.pp_premiumBackgroundGlowViewBottom setNeedsLayout];

    if (motionLayoutChanged && self.sellerScreenVisible) {
        [self startLivingBackgroundIfNeeded];
    }
}

- (void)updateSurfaceShadowPaths {
    if (!CGRectIsEmpty(self.heroSurfaceView.bounds)) {
        self.heroSurfaceView.layer.shadowPath =
            [UIBezierPath bezierPathWithRoundedRect:self.heroSurfaceView.bounds
                                       cornerRadius:kSPSurfaceCornerRadius].CGPath;
        self.avatarBreathingHaloView.layer.cornerRadius = CGRectGetWidth(self.avatarBreathingHaloView.bounds) * 0.5;
        self.avatarBreathingHaloView.layer.shadowPath =
            [UIBezierPath bezierPathWithOvalInRect:self.avatarBreathingHaloView.bounds].CGPath;
        self.avatarShellView.layer.cornerRadius = CGRectGetWidth(self.avatarShellView.bounds) * 0.5;
        self.avatarInnerPlateView.layer.cornerRadius = CGRectGetWidth(self.avatarInnerPlateView.bounds) * 0.5;
        self.avatarImageView.layer.cornerRadius = CGRectGetWidth(self.avatarImageView.bounds) * 0.5;
    }
    self.heroBottomFadeLayer.frame = self.topFadeView.bounds;
    if (!CGRectIsEmpty(self.compactHeaderView.bounds)) {
        self.compactHeaderView.layer.shadowPath =
            [UIBezierPath bezierPathWithRoundedRect:self.compactHeaderView.bounds
                                       cornerRadius:24.0].CGPath;
    }
}

- (void)pp_updateBottomNavigationInsetsIfNeeded
{
    if (!self.scrollView) {
        return;
    }

    CGFloat bottomInset = SPSellerBottomNavigationClearanceForController(self);
    UIEdgeInsets contentInset = self.scrollView.contentInset;
    UIEdgeInsets indicatorInset = self.scrollView.verticalScrollIndicatorInsets;
    if (fabs(bottomInset - self.appliedBottomNavigationScrollInset) < 0.5 &&
        fabs(contentInset.bottom - bottomInset) < 0.5 &&
        fabs(indicatorInset.bottom - bottomInset) < 0.5) {
        return;
    }

    contentInset.bottom = bottomInset;
    indicatorInset.bottom = bottomInset;
    self.scrollView.contentInset = contentInset;
    self.scrollView.verticalScrollIndicatorInsets = indicatorInset;
    self.appliedBottomNavigationScrollInset = bottomInset;
}

- (void)pp_updateScrollInsetsForHeroIfNeeded
{
    if (CGRectIsEmpty(self.heroSurfaceView.frame) || CGRectIsEmpty(self.scrollView.bounds)) {
        return;
    }

    CGFloat heroBottomInScroll = CGRectGetMaxY(self.heroSurfaceView.frame) - CGRectGetMinY(self.scrollView.frame);
    CGFloat topInset = MAX(0.0, heroBottomInScroll + kSPSpace8);
    if (fabs(topInset - self.appliedHeroScrollInset) < 0.5) {
        return;
    }

    BOOL isInitialInset = self.appliedHeroScrollInset <= 0.0;
    CGFloat relativeOffset = self.scrollView.contentOffset.y + self.appliedHeroScrollInset;
    UIEdgeInsets contentInset = self.scrollView.contentInset;
    contentInset.top = topInset;
    self.scrollView.contentInset = contentInset;

    UIEdgeInsets indicatorInset = self.scrollView.verticalScrollIndicatorInsets;
    indicatorInset.top = topInset;
    self.scrollView.verticalScrollIndicatorInsets = indicatorInset;
    self.appliedHeroScrollInset = topInset;

    CGPoint offset = self.scrollView.contentOffset;
    offset.y = isInitialInset ? -topInset : (relativeOffset - topInset);
    [self.scrollView setContentOffset:offset animated:NO];
}

- (CGSize)itemSizeForCollectionWidth:(CGFloat)collectionWidth {
    NSInteger columns = collectionWidth < 330.0 ? 1 : 2;
    CGFloat spacing = columns == 1 ? 0.0 : kSPSpace12;
    CGFloat itemWidth = floor((collectionWidth - spacing) / columns);
    return CGSizeMake(itemWidth, itemWidth + 144.0);
}

- (void)updateCollectionHeight {
    if (!self.collectionHeightConstraint) return;
    if (self.itemViewModels.count == 0) {
        self.collectionHeightConstraint.constant = 0.0;
        [self pp_updateCollapsibleHeaderForScrollOffset:self.scrollView.contentOffset.y animated:NO];
        return;
    }

    CGFloat width = CGRectGetWidth(self.itemsCollectionView.bounds);
    if (width <= 0.0) {
        width = CGRectGetWidth(self.view.bounds) - (kSPSpace16 * 2.0);
    }
    CGSize itemSize = [self itemSizeForCollectionWidth:width];
    NSInteger columns = width < 330.0 ? 1 : 2;
    NSInteger rows = (self.itemViewModels.count + columns - 1) / columns;
    CGFloat spacing = kSPSpace12 * MAX(rows - 1, 0);
    self.collectionHeightConstraint.constant = rows * itemSize.height + spacing;
    [self pp_updateCollapsibleHeaderForScrollOffset:self.scrollView.contentOffset.y animated:NO];
}

- (BOOL)pp_shouldUseCollapsibleHeader
{
    return NO;
}

- (void)pp_updateCollapsibleHeaderForScrollOffset:(CGFloat)offsetY animated:(BOOL)animated
{
    BOOL enabled = [self pp_shouldUseCollapsibleHeader];
    CGFloat startOffset = 18.0;
    CGFloat travel = 104.0;
    CGFloat progress = 0.0;
    if (enabled) {
        progress = MIN(MAX((offsetY - startOffset) / travel, 0.0), 1.0);
    }

    BOOL showCompact = enabled && progress > 0.01;
    self.compactHeaderView.hidden = !showCompact;

    CGFloat subtitleAlpha = MAX(0.0, 1.0 - (progress * 0.95));
    CGFloat bodyAlpha = MAX(0.0, 1.0 - (progress * 1.2));
    CGAffineTransform avatarTransform = CGAffineTransformIdentity;
    if (enabled && !UIAccessibilityIsReduceMotionEnabled()) {
        CGFloat scale = 1.0 - (0.12 * progress);
        avatarTransform = CGAffineTransformMakeScale(scale, scale);
    }

    void (^changes)(void) = ^{
        self.compactHeaderView.alpha = showCompact ? progress : 0.0;
        self.compactHeaderView.transform = UIAccessibilityIsReduceMotionEnabled()
            ? CGAffineTransformIdentity
            : CGAffineTransformMakeTranslation(0.0, -8.0 * (1.0 - progress));
        self.avatarBreathingHaloView.transform = avatarTransform;
        self.avatarShellView.transform = avatarTransform;
        self.subtitleLabel.alpha = subtitleAlpha;
        self.descriptionLabel.alpha = bodyAlpha;
        self.contactButtonStack.alpha = bodyAlpha;
        self.statusBadgeView.alpha = MAX(0.0, 1.0 - (progress * 0.9));
        self.eyebrowLabel.alpha = MAX(0.0, 1.0 - (progress * 0.75));
        self.nameLabel.transform = UIAccessibilityIsReduceMotionEnabled()
            ? CGAffineTransformIdentity
            : CGAffineTransformMakeTranslation(0.0, -10.0 * progress);
    };

    if (animated) {
        [UIView animateWithDuration:0.24
                              delay:0.0
                            options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }
}

#pragma mark - Motion

- (void)startLivingBackgroundIfNeeded {
    if (self.livingBackgroundActive ||
        UIAccessibilityIsReduceMotionEnabled() ||
        !self.sellerScreenVisible ||
        self.view.window == nil ||
        CGRectIsEmpty(self.pp_premiumBackgroundGlowViewMid.bounds)) {
        return;
    }
    self.livingBackgroundActive = YES;
    if (self.backgroundGlowsFadedByHomeConfig) {
        [self pp_addRandomizedMiddleBackgroundGlowPositionMotion];
    } else {
        [self pp_addPremiumMiddleBackgroundGlowPeekMotionIfNeeded];
    }
}

- (void)animateGlowView:(UIView *)view
                keyPath:(NSString *)key
                  scale:(CGFloat)scale
            translation:(CGPoint)translation
                   duration:(NSTimeInterval)duration
                      delay:(NSTimeInterval)delay {
    (void)view;
    (void)key;
    (void)scale;
    (void)translation;
    (void)duration;
    (void)delay;
}

- (void)stopLivingBackground {
    self.livingBackgroundActive = NO;
    [self.pp_premiumBackgroundGlowViewMid.layer removeAnimationForKey:SPSellerMiddleBackgroundGlowPositionMotionKey];
    [self.pp_premiumBackgroundGlowViewMid.layer removeAnimationForKey:SPSellerMiddleBackgroundGlowPeekMotionKey];
}

- (void)pp_addRandomizedMiddleBackgroundGlowPositionMotion
{
    SPSellerAmbientGlowView *glowView = self.pp_premiumBackgroundGlowViewMid;
    if (!glowView || CGRectIsEmpty(glowView.bounds) ||
        [glowView.layer animationForKey:SPSellerMiddleBackgroundGlowPositionMotionKey]) {
        return;
    }

    CGFloat canvasWidth = CGRectGetWidth(self.pp_premiumBackgroundCanvasView.bounds);
    CGFloat canvasHeight = CGRectGetHeight(self.pp_premiumBackgroundCanvasView.bounds);
    CGFloat maximumXOffset = MIN(92.0, MAX(64.0, canvasWidth * 0.22));
    CGFloat maximumYOffset = MIN(116.0, MAX(78.0, canvasHeight * 0.115));
    CGPoint restingPosition = glowView.layer.position;

    NSMutableArray<NSValue *> *positions = [NSMutableArray arrayWithObject:[NSValue valueWithCGPoint:restingPosition]];
    NSMutableArray<NSNumber *> *keyTimes = [NSMutableArray arrayWithObject:@0.0];
    static NSInteger const waypointCount = 7;
    for (NSInteger index = 1; index <= waypointCount; index++) {
        CGFloat randomXUnit = ((CGFloat)arc4random_uniform(2001) / 1000.0) - 1.0;
        CGFloat randomYUnit = ((CGFloat)arc4random_uniform(2001) / 1000.0) - 1.0;
        CGPoint waypoint = CGPointMake(restingPosition.x + (randomXUnit * maximumXOffset),
                                       restingPosition.y + (randomYUnit * maximumYOffset));
        [positions addObject:[NSValue valueWithCGPoint:waypoint]];
        [keyTimes addObject:@((CGFloat)index / (CGFloat)(waypointCount + 1))];
    }
    [positions addObject:[NSValue valueWithCGPoint:restingPosition]];
    [keyTimes addObject:@1.0];

    CFTimeInterval duration = 13.0 + ((CGFloat)arc4random_uniform(3501) / 1000.0);
    CAKeyframeAnimation *positionAnimation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
    positionAnimation.values = positions;
    positionAnimation.keyTimes = keyTimes;
    positionAnimation.calculationMode = kCAAnimationCubic;
    positionAnimation.duration = duration;
    positionAnimation.repeatCount = HUGE_VALF;
    positionAnimation.removedOnCompletion = YES;
    positionAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    CFTimeInterval localNow = [glowView.layer convertTime:CACurrentMediaTime() fromLayer:nil];
    CGFloat randomPhase = ((CGFloat)arc4random_uniform(10001) / 10000.0) * duration;
    positionAnimation.beginTime = localNow - randomPhase;

    [glowView.layer addAnimation:positionAnimation forKey:SPSellerMiddleBackgroundGlowPositionMotionKey];
}

- (void)pp_addPremiumMiddleBackgroundGlowPeekMotionIfNeeded
{
    SPSellerAmbientGlowView *glowView = self.pp_premiumBackgroundGlowViewMid;
    if (!glowView || CGRectIsEmpty(glowView.bounds) ||
        [glowView.layer animationForKey:SPSellerMiddleBackgroundGlowPeekMotionKey]) {
        return;
    }

    CGFloat travelDistance = MIN(26.0, MAX(16.0, CGRectGetWidth(glowView.bounds) * 0.08));
    CGFloat direction = self.view.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft ? -1.0 : 1.0;

    CABasicAnimation *positionAnimation =
        [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
    positionAnimation.fromValue = @(0.0);
    positionAnimation.toValue = @(travelDistance * direction);

    CABasicAnimation *opacityAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacityAnimation.fromValue = @0.88;
    opacityAnimation.toValue = @1.0;

    CABasicAnimation *scaleAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scaleAnimation.fromValue = @0.985;
    scaleAnimation.toValue = @1.018;

    CAAnimationGroup *peekAnimation = [CAAnimationGroup animation];
    peekAnimation.animations = @[positionAnimation, opacityAnimation, scaleAnimation];
    peekAnimation.duration = 4.8;
    peekAnimation.autoreverses = YES;
    peekAnimation.repeatCount = HUGE_VALF;
    peekAnimation.removedOnCompletion = YES;
    peekAnimation.timingFunction =
        [CAMediaTimingFunction functionWithControlPoints:0.35 :0.0 :0.18 :1.0];

    [glowView.layer addAnimation:peekAnimation forKey:SPSellerMiddleBackgroundGlowPeekMotionKey];
}

- (void)pp_prepareHeroEntranceState
{
    if (self.didAnimateEntrance || UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    self.heroSurfaceView.alpha = 0.0;
    self.heroSurfaceView.transform =
        CGAffineTransformScale(CGAffineTransformMakeTranslation(0.0, 14.0), 0.982, 0.982);

    self.avatarShellView.alpha = 0.0;
    self.avatarShellView.transform =
        CGAffineTransformScale(CGAffineTransformMakeTranslation(0.0, 8.0), 0.92, 0.92);
    self.avatarBreathingHaloView.alpha = 0.0;
    self.avatarBreathingHaloView.transform =
        CGAffineTransformScale(CGAffineTransformMakeTranslation(0.0, 8.0), 0.90, 0.90);

    NSArray<UIView *> *textViews = @[self.eyebrowLabel, self.nameLabel, self.subtitleLabel];
    [textViews enumerateObjectsUsingBlock:^(UIView *view, NSUInteger idx, BOOL *stop) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0.0, 10.0 + (CGFloat)idx * 2.0);
    }];

    self.statusBadgeView.alpha = 0.0;
    self.statusBadgeView.transform = CGAffineTransformMakeScale(0.84, 0.84);

    self.contactButtonStack.alpha = 0.0;
    self.contactButtonStack.transform = CGAffineTransformMakeTranslation(0.0, 12.0);
}

- (void)pp_resetHeroEntranceState
{
    NSArray<UIView *> *heroViews = @[
        self.heroSurfaceView,
        self.avatarBreathingHaloView,
        self.avatarShellView,
        self.eyebrowLabel,
        self.nameLabel,
        self.subtitleLabel,
        self.statusBadgeView,
        self.contactButtonStack
    ];
    [heroViews enumerateObjectsUsingBlock:^(UIView *view, NSUInteger idx, BOOL *stop) {
        view.alpha = 1.0;
        view.transform = CGAffineTransformIdentity;
    }];

    self.callButton.hidden = YES;
    self.callButton.enabled = NO;
    self.callButton.alpha = 0.0;
    self.callButton.accessibilityElementsHidden = YES;
}

- (void)pp_beginHeroAliveMotionIfNeeded
{
    if (self.didStartHeroAliveMotion ||
        UIAccessibilityIsReduceMotionEnabled() ||
        !self.sellerScreenVisible ||
        !self.view.window ||
        CGRectIsEmpty(self.heroSurfaceView.bounds)) {
        return;
    }

    self.didStartHeroAliveMotion = YES;
    [self.heroGlassBackgroundView startAnimations];
    CAMediaTimingFunction *softEase =
        [CAMediaTimingFunction functionWithControlPoints:0.45 :0.0 :0.55 :1.0];

    CABasicAnimation *avatarScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    avatarScale.fromValue = @0.965;
    avatarScale.toValue = @1.035;

    CABasicAnimation *avatarOpacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
    avatarOpacity.fromValue = @0.72;
    avatarOpacity.toValue = @1.0;

    CAAnimationGroup *avatarBreathingGroup = [CAAnimationGroup animation];
    avatarBreathingGroup.animations = @[avatarScale, avatarOpacity];
    avatarBreathingGroup.duration = 3.8;
    avatarBreathingGroup.autoreverses = YES;
    avatarBreathingGroup.repeatCount = HUGE_VALF;
    avatarBreathingGroup.removedOnCompletion = YES;
    avatarBreathingGroup.timingFunction = softEase;
    [self.avatarBreathingHaloView.layer addAnimation:avatarBreathingGroup forKey:SPSellerAvatarBreathingMotionKey];

}

- (void)pp_stopHeroAliveMotion
{
    self.didStartHeroAliveMotion = NO;
    [self.heroGlassBackgroundView stopAnimations];
    [self.avatarBreathingHaloView.layer removeAnimationForKey:SPSellerAvatarBreathingMotionKey];
}

- (void)animateEntranceIfNeeded {
    if (self.didAnimateEntrance || UIAccessibilityIsReduceMotionEnabled()) {
        [self pp_resetHeroEntranceState];
        self.itemsTitleLabel.alpha = 1.0;
        self.itemsTitleLabel.transform = CGAffineTransformIdentity;
        self.itemsCollectionView.alpha = 1.0;
        self.itemsCollectionView.transform = CGAffineTransformIdentity;
        return;
    }
    [self pp_prepareHeroEntranceState];
    self.didAnimateEntrance = YES;
    NSArray<UIView *> *contentViews = @[self.itemsTitleLabel, self.itemsCollectionView];
    [contentViews enumerateObjectsUsingBlock:^(UIView *view, NSUInteger idx, BOOL *stop) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0.0, 18.0);
    }];

    [UIView animateWithDuration:0.48
                          delay:0.0
         usingSpringWithDamping:0.94
          initialSpringVelocity:0.12
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.heroSurfaceView.alpha = 1.0;
        self.heroSurfaceView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.42
                          delay:0.07
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.avatarShellView.alpha = 1.0;
        self.avatarShellView.transform = CGAffineTransformIdentity;
        self.avatarBreathingHaloView.alpha = 1.0;
        self.avatarBreathingHaloView.transform = CGAffineTransformIdentity;
        self.statusBadgeView.alpha = 1.0;
        self.statusBadgeView.transform = CGAffineTransformIdentity;
    } completion:nil];

    NSArray<UIView *> *textViews = @[self.eyebrowLabel, self.nameLabel, self.subtitleLabel];
    [textViews enumerateObjectsUsingBlock:^(UIView *view, NSUInteger idx, BOOL *stop) {
        [UIView animateWithDuration:0.34
                              delay:0.12 + (0.045 * idx)
                            options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];

    [UIView animateWithDuration:0.42
                          delay:0.24
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.10
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.contactButtonStack.alpha = 1.0;
        self.contactButtonStack.transform = CGAffineTransformIdentity;
    } completion:nil];

    [contentViews enumerateObjectsUsingBlock:^(UIView *view, NSUInteger idx, BOOL *stop) {
        [UIView animateWithDuration:0.46
                              delay:0.30 + (0.06 * idx)
             usingSpringWithDamping:0.92
              initialSpringVelocity:0.0
                            options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

- (void)animateCellIfNeeded:(UICollectionViewCell *)cell index:(NSInteger)index {
    if (UIAccessibilityIsReduceMotionEnabled()) {
        cell.alpha = 1.0;
        cell.transform = CGAffineTransformIdentity;
        return;
    }

    NSNumber *key = @(index);
    if ([self.animatedItemIndexes containsObject:key]) {
        cell.alpha = 1.0;
        cell.transform = CGAffineTransformIdentity;
        return;
    }
    [self.animatedItemIndexes addObject:key];

    cell.alpha = 0.0;
    cell.transform = CGAffineTransformMakeTranslation(0.0, 14.0);
    NSTimeInterval delay = MIN(index * 0.035, 0.18);
    [UIView animateWithDuration:0.36
                          delay:delay
         usingSpringWithDamping:0.95
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        cell.alpha = 1.0;
        cell.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)handleButtonTouchDown:(UIButton *)sender {
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    [UIView animateWithDuration:0.10
                          delay:0.0
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                     animations:^{
        sender.transform = CGAffineTransformMakeScale(0.965, 0.965);
    } completion:nil];
}

- (void)handleButtonTouchUp:(UIButton *)sender {
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    [UIView animateWithDuration:0.20
                          delay:0.0
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        sender.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    (void)scrollView;
}

#pragma mark - Collection View

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.itemViewModels.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PPUniversalCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:PPUniversalCell.reuseIdentifier
                                                                      forIndexPath:indexPath];
    if (indexPath.item >= self.itemViewModels.count) return cell;

    PPUniversalCellViewModel *viewModel = self.itemViewModels[indexPath.item];
    viewModel.indexPath = indexPath;
    cell.delegate = self;
    cell.showsSubtitle = YES;
    cell.hideTopBadge = NO;

    PetAccessory *item = (PetAccessory *)viewModel.ModelObject;
    PPCellContext context = item.accessKindType == AccessTypeFood ? PPCellForFood : PPCellForMarket;
    [cell applyViewModel:viewModel
                 context:context
              layoutMode:PPCellLayoutModeVertical
            discountMode:PPDiscountStyleBadge
             imageLoader:^void(UIImageView *imageView, NSString *url, UIImage *placeholder, UIView *card) {
        (void)card;
        [PPImageLoaderManager.shared setImageOnImageView:imageView
                                                     url:url
                                             placeholder:placeholder
                                              complation:nil];
    }];

    [self animateCellIfNeeded:cell index:indexPath.item];
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return [self itemSizeForCollectionWidth:CGRectGetWidth(collectionView.bounds)];
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.item >= self.itemViewModels.count) return;
    PPUniversalCellViewModel *viewModel = self.itemViewModels[indexPath.item];
    [self notifySelectedItem:viewModel.ModelObject];

    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    if (!cell || UIAccessibilityIsReduceMotionEnabled()) return;
    [UIView animateWithDuration:0.10
                          delay:0.0
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        cell.transform = CGAffineTransformMakeScale(0.97, 0.97);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.20
                              delay:0.0
             usingSpringWithDamping:0.86
              initialSpringVelocity:0.0
                            options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            cell.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

- (void)PPUniversalCell_tapCard:(PPUniversalCellViewModel *)universalModel {
    [self notifySelectedItem:universalModel.ModelObject];
}

- (void)PPUniversalCell_changeQuantity:(PPUniversalCellViewModel *)universalModel quantity:(NSInteger)quantity
{
    if (![universalModel.ModelObject isKindOfClass:PetAccessory.class]) {
        return;
    }

    PetAccessory *accessory = (PetAccessory *)universalModel.ModelObject;
    NSInteger maxStock = MAX(accessory.quantity, 0);
    NSInteger safeQuantity = MAX(0, quantity);

    if (maxStock <= 0 && safeQuantity > 0) {
        [PPHUD showError:kLang(@"Out of stock") ?: @"Out of stock"];
        safeQuantity = 0;
    } else if (safeQuantity > maxStock) {
        safeQuantity = maxStock;
        [PPHUD showInfo:[NSString stringWithFormat:@"%@ %ld %@",
                         kLang(@"Only") ?: @"Only",
                         (long)maxStock,
                         kLang(@"left in stock") ?: @"left in stock"]];
    }

    CartManager *cart = [CartManager sharedManager];
    if (safeQuantity == 0) {
        [cart removeItemForAccessory:accessory];
        [PPFunc triggerWarningHaptic];
        [self.itemsCollectionView reloadData];
        [[NSNotificationCenter defaultCenter] postNotificationName:kCartUpdatedNotification object:nil];
        return;
    }

    CartItem *existing = [cart getCartItemForItemID:accessory.accessoryID];
    CartItem *item = [[CartItem alloc] initWithAccessory:accessory quantity:safeQuantity];
    __weak typeof(self) weakSelf = self;

    if (existing) {
        [cart updateQuantity:safeQuantity forItem:item completion:^(BOOL success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;
                if (!success) {
                    [PPHUD showError:kLang(@"Out of stock") ?: @"Out of stock"];
                } else if (safeQuantity == 1) {
                    [PPFunc triggerLightHaptic];
                } else {
                    [PPFunc triggerMediumHaptic];
                }
                [self.itemsCollectionView reloadData];
                [[NSNotificationCenter defaultCenter] postNotificationName:kCartUpdatedNotification object:nil];
            });
        }];
        return;
    }

    [cart addItem:item presentingViewController:self completion:^(BOOL didAdd, BOOL didCancel) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            if (!didCancel && !didAdd) {
                [PPHUD showError:kLang(@"Out of stock") ?: @"Out of stock"];
            } else if (didAdd) {
                if (safeQuantity == 1) {
                    [PPFunc triggerLightHaptic];
                } else {
                    [PPFunc triggerMediumHaptic];
                }
            }
            [self.itemsCollectionView reloadData];
            [[NSNotificationCenter defaultCenter] postNotificationName:kCartUpdatedNotification object:nil];
        });
    }];
}

- (void)notifySelectedItem:(id)item {
    if ([self.delegate respondsToSelector:@selector(sellerProfileDidSelectItem:)]) {
        [self.delegate sellerProfileDidSelectItem:item];
        return;
    }

    if (![item isKindOfClass:PetAccessory.class]) {
        return;
    }

    AccessViewerVC *viewer = [[AccessViewerVC alloc] init];
    viewer.accessAds = (PetAccessory *)item;
    viewer.ParentVC = self.parentVC ?: self;
    [self.navigationController pushViewController:viewer animated:YES];
}

#pragma mark - Actions

- (void)pp_handleHeroBack
{
    if (self.navigationController.viewControllers.firstObject != self) {
        [self.navigationController popViewControllerAnimated:YES];
    } else if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    [self playLightFeedback];
}

- (void)pp_cartDidUpdate:(NSNotification * _Nullable)notification
{
    (void)notification;
    NSInteger count = [[CartManager sharedManager] totalItemsCount];
    [self.cartNavButton updateCount:count animated:(notification != nil)];
    [self pp_updateBottomNavigationInsetsIfNeeded];
}

- (void)pp_openCart
{
    CartViewController *cartVC = [[CartViewController alloc] init];
    cartVC.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:cartVC animated:YES];
    [self playLightFeedback];
}

- (void)handleMessageTap {
    if ([self.delegate respondsToSelector:@selector(sellerProfileDidTapContact:)]) {
        [self.delegate sellerProfileDidTapContact:self.seller];
    } else if (self.seller) {
        [GM chatWith:self.seller FromController:self.parentVC ?: self];
    }
    [self playLightFeedback];
}

- (void)handleCallTap {
    if ([self.delegate respondsToSelector:@selector(sellerProfileDidTapCall:)]) {
        [self.delegate sellerProfileDidTapCall:self.seller];
    } else if ([self.delegate respondsToSelector:@selector(sellerProfileDidTapContact:)]) {
        [self.delegate sellerProfileDidTapContact:self.seller];
    } else if (self.seller.MobileNo.length > 0) {
        [AppClasses callPhoneNumber:self.seller.MobileNo fromViewController:self.parentVC ?: self];
    }
    [self playLightFeedback];
}

- (void)playLightFeedback {
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [generator prepare];
        [generator impactOccurred];
    }
}

- (void)updateAccessibility {
    NSString *sellerName = self.nameLabel.text.length > 0 ? self.nameLabel.text : kLang(@"premium_seller");
    self.avatarImageView.accessibilityLabel = sellerName;
    self.statusBadgeView.accessibilityLabel = [self pp_statusBadgeText];
    self.messageButton.accessibilityLabel = [NSString stringWithFormat:@"%@ %@", kLang(@"message"), sellerName];
    self.callButton.accessibilityLabel = nil;
    self.callButton.accessibilityElementsHidden = YES;
    NSString *ratingSummary = self.seller.providerReviewCount > 0
        ? [NSString stringWithFormat:(kLang(@"provider_rating_accessibility_format") ?: @"Rated %.1f out of 5 from %ld reviews"),
           self.seller.providerRatingValue,
           (long)self.seller.providerReviewCount]
        : (kLang(@"provider_rating_no_reviews") ?: @"No provider ratings yet");
    self.rateButton.accessibilityLabel =
        [NSString stringWithFormat:@"%@, %@", kLang(@"provider_rating_action") ?: @"Rate provider", ratingSummary];
    self.rateButton.accessibilityHint = self.canRateProvider
        ? (kLang(@"provider_rating_action_hint") ?: @"Opens the provider rating sheet")
        : (kLang(@"provider_rating_purchase_required_subtitle") ?: @"Only customers who bought from this provider can submit a rating.");
}

@end
