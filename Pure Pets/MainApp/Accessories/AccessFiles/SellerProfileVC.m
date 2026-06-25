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
#import "PPUniversalCell.h"
#import "PPUniversalCellViewModel.h"
#import "PPImageLoaderManager.h"
#import "PPModernAvatarRenderer.h"
@import FirebaseAuth;
@import FirebaseFirestore;
@import FirebaseFunctions;

static CGFloat SPSellerBottomNavigationClearanceForController(UIViewController *controller)
{
    if (!controller || !controller.tabBarController || CGRectIsEmpty(controller.view.bounds)) {
        return 0.0;
    }

    UITabBarController *tabBarController = controller.tabBarController;
    if (PPIOS26()) {
        SEL clearanceSelector = NSSelectorFromString(@"pp_bottomNavigationContentClearance");
        if ([tabBarController respondsToSelector:clearanceSelector]) {
            CGFloat (*clearanceIMP)(id, SEL) = (CGFloat (*)(id, SEL))[tabBarController methodForSelector:clearanceSelector];
            CGFloat rootClearance = clearanceIMP ? clearanceIMP(tabBarController, clearanceSelector) : 0.0;
            if (rootClearance > 0.0) {
                return ceil(rootClearance);
            }
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
static const CGFloat kSPAvatarShellSize = 78.0;
static const CGFloat kSPSurfaceCornerRadius = 30.0;
static const CGFloat kSPButtonHeight = 46.0;

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

static UIColor *SPSellerBackgroundColor(UITraitCollection *traitCollection) {
    if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        return [UIColor colorWithWhite:0.055 alpha:1.0];
    }
    UIColor *appBackground = AppBageColor();
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
        return [UIColor colorWithRed:0.20 green:0.08 blue:0.13 alpha:0.96];
    }
    return [UIColor colorWithRed:1.00 green:0.925 blue:0.952 alpha:0.96];
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
    contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
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
    iconShell.layer.borderWidth = 0.75;
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
    starsStack.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;

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
    self.commentTextView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
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

        [closeButton.topAnchor constraintEqualToAnchor:safe.topAnchor constant:12.0],
        [closeButton.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-18.0],
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

@property (nonatomic, strong) UIView *glowTopView;
@property (nonatomic, strong) UIView *glowMiddleView;
@property (nonatomic, strong) UIView *glowBottomView;
@property (nonatomic, assign) BOOL livingBackgroundActive;
@property (nonatomic, assign) BOOL didAnimateEntrance;
@property (nonatomic, assign) BOOL didRequestSellerItems;

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *heroSurfaceView;
@property (nonatomic, strong) UIView *heroLiquidBorderView;
@property (nonatomic, strong) UIView *heroInnerGlowView;
@property (nonatomic, strong) CAGradientLayer *heroGradientLayer;
@property (nonatomic, strong) CAGradientLayer *heroBorderGradientLayer;
@property (nonatomic, strong) UIView *topFadeView;
@property (nonatomic, strong) CAGradientLayer *heroBottomFadeLayer;
@property (nonatomic, strong) UIButton *heroBackButton;
@property (nonatomic, strong) UIView *avatarShellView;
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
- (void)pp_submitProviderRating:(NSInteger)rating
                         comment:(NSString *)comment
                           sheet:(SPProviderRatingSheetViewController *)sheet;

@end

@implementation SellerProfileVC

- (instancetype)init {
    self = [super init];
    if (self) {
        self.hidesBottomBarWhenPushed = YES;
        _itemViewModels = [NSMutableArray array];
        _animatedItemIndexes = [NSMutableSet set];
    }
    return self;
}

- (void)dealloc
{
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
    [self startLivingBackgroundIfNeeded];
    [self animateEntranceIfNeeded];
    [self pp_updateBottomNavigationInsetsIfNeeded];
    [self pp_startProviderRatingListener];
    self.ratingEligibilityLoaded = NO;
    [self pp_refreshRatingEligibilityWithCompletion:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
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

- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
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
    self.glowTopView = [self createGlowViewWithColor:SPSellerAccentTealColor()];
    self.glowMiddleView = [self createGlowViewWithColor:SPSellerRoseColor()];
    self.glowBottomView = [self createGlowViewWithColor:SPSellerGoldColor()];

    [self.view addSubview:self.glowTopView];
    [self.view addSubview:self.glowMiddleView];
    [self.view addSubview:self.glowBottomView];
}

- (UIView *)createGlowViewWithColor:(UIColor *)color {
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    view.userInteractionEnabled = NO;
    view.backgroundColor = [color colorWithAlphaComponent:0.13];
    view.layer.shadowColor = color.CGColor;
    view.layer.shadowOpacity = 0.20;
    view.layer.shadowRadius = 44.0;
    view.layer.shadowOffset = CGSizeZero;
    view.alpha = 0.72;
    return view;
}

- (void)setupHeroSurface {
    self.heroSurfaceView = [self createSurfaceView];
    self.heroSurfaceView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.heroSurfaceView.layer.borderWidth = 0.55;
    self.heroSurfaceView.layer.shadowOpacity = 0.035;
    self.heroSurfaceView.layer.shadowRadius = 14.0;
    self.heroSurfaceView.layer.shadowOffset = CGSizeMake(0.0, 7.0);
    UIVisualEffectView *heroBlurView = [self.heroSurfaceView.subviews.firstObject isKindOfClass:UIVisualEffectView.class]
        ? (UIVisualEffectView *)self.heroSurfaceView.subviews.firstObject
        : nil;
    if (heroBlurView) {
        UIBlurEffect *heroBlur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleExtraLight];
        if (@available(iOS 13.0, *)) {
            heroBlur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
        }
        heroBlurView.effect = heroBlur;
        heroBlurView.alpha = 0.54;
    }
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

    self.heroGradientLayer = [CAGradientLayer layer];
    self.heroGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    self.heroGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    self.heroGradientLayer.locations = @[@0.0, @0.52, @1.0];
    self.heroGradientLayer.masksToBounds = YES;
    [self.heroSurfaceView.layer insertSublayer:self.heroGradientLayer atIndex:0];

    self.heroInnerGlowView = [[UIView alloc] init];
    self.heroInnerGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroInnerGlowView.userInteractionEnabled = NO;
    self.heroInnerGlowView.alpha = 0.26;
    [self.heroSurfaceView addSubview:self.heroInnerGlowView];

    self.heroLiquidBorderView = [[UIView alloc] init];
    self.heroLiquidBorderView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroLiquidBorderView.userInteractionEnabled = NO;
    self.heroLiquidBorderView.backgroundColor = UIColor.clearColor;
    self.heroLiquidBorderView.layer.borderWidth = 0.45;
    self.heroLiquidBorderView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.heroLiquidBorderView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.heroSurfaceView addSubview:self.heroLiquidBorderView];

    self.heroBorderGradientLayer = [CAGradientLayer layer];
    self.heroBorderGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    self.heroBorderGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    self.heroBorderGradientLayer.locations = @[@0.0, @0.44, @1.0];
    self.heroBorderGradientLayer.opacity = 0.16;
    self.heroBorderGradientLayer.masksToBounds = YES;
    [self.heroLiquidBorderView.layer insertSublayer:self.heroBorderGradientLayer atIndex:0];

    [self.heroSurfaceView addSubview:self.heroBackButton];
    [self.heroSurfaceView addSubview:self.cartNavButton];

    self.avatarShellView = [[UIView alloc] init];
    self.avatarShellView.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarShellView.backgroundColor = SPSellerHeroAvatarShellColor(self.traitCollection);
    self.avatarShellView.layer.cornerRadius = kSPAvatarShellSize / 2.0;
    self.avatarShellView.layer.borderWidth = 1.0;
    self.avatarShellView.layer.shadowColor = SPSellerBrandAccentColor().CGColor;
    self.avatarShellView.layer.shadowOpacity = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.0 : 0.10;
    self.avatarShellView.layer.shadowRadius = 18.0;
    self.avatarShellView.layer.shadowOffset = CGSizeMake(0.0, 9.0);
    [self.avatarShellView pp_setBorderColor:SPSellerHeroAvatarStrokeColor(self.traitCollection)];
    [self.heroSurfaceView addSubview:self.avatarShellView];

    self.avatarImageView = [[UIImageView alloc] initWithImage:PPSYSImage(@"person.crop.circle.fill")];
    self.avatarImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarImageView.layer.cornerRadius = kSPAvatarSize / 2.0;
    self.avatarImageView.layer.masksToBounds = YES;
    self.avatarImageView.backgroundColor = [SPSellerInkColor() colorWithAlphaComponent:0.045];
    self.avatarImageView.tintColor = [SPSellerSecondaryTextColor() colorWithAlphaComponent:0.72];
    [self.avatarShellView addSubview:self.avatarImageView];

    self.eyebrowLabel = [self labelWithFont:[GM boldFontWithSize:12] color:SPSellerAccentTealColor() lines:1];
    [self.heroSurfaceView addSubview:self.eyebrowLabel];

    self.nameLabel = [self labelWithFont:[GM boldFontWithSize:24] color:SPSellerInkColor() lines:1];
    self.nameLabel.adjustsFontSizeToFitWidth = YES;
    self.nameLabel.minimumScaleFactor = 0.78;
    [self.heroSurfaceView addSubview:self.nameLabel];

    self.subtitleLabel = [self labelWithFont:[GM MidFontWithSize:13.5] color:SPSellerSecondaryTextColor() lines:1];
    [self.heroSurfaceView addSubview:self.subtitleLabel];

    self.statusBadgeView = [[UIView alloc] init];
    self.statusBadgeView.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusBadgeView.isAccessibilityElement = YES;
    self.statusBadgeView.accessibilityTraits = UIAccessibilityTraitImage;
    self.statusBadgeView.layer.cornerRadius = 15.0;
    self.statusBadgeView.layer.borderWidth = 2.0;
    self.statusBadgeView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.98] ?: UIColor.systemBackgroundColor;
    [self.statusBadgeView pp_setBorderColor:[AppForgroundColr colorWithAlphaComponent:0.98] ?: UIColor.whiteColor];
    self.statusBadgeView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.statusBadgeView.layer.shadowOpacity = 0.08;
    self.statusBadgeView.layer.shadowRadius = 8.0;
    self.statusBadgeView.layer.shadowOffset = CGSizeMake(0.0, 4.0);
    [self.heroSurfaceView addSubview:self.statusBadgeView];

    self.statusBadgeIconView = [[UIImageView alloc] init];
    self.statusBadgeIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusBadgeIconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.statusBadgeView addSubview:self.statusBadgeIconView];
    [NSLayoutConstraint activateConstraints:@[
        [self.statusBadgeIconView.centerXAnchor constraintEqualToAnchor:self.statusBadgeView.centerXAnchor],
        [self.statusBadgeIconView.centerYAnchor constraintEqualToAnchor:self.statusBadgeView.centerYAnchor],
        [self.statusBadgeIconView.widthAnchor constraintEqualToConstant:16.0],
        [self.statusBadgeIconView.heightAnchor constraintEqualToConstant:16.0],
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
    self.rateButton = [self createActionButtonWithTitle:(kLang(@"provider_rating_action") ?: @"Rate provider")
                                              imageName:@"star.fill"
                                             emphasized:NO
                                               selector:@selector(handleRateProviderTap)];
    self.rateButton.titleLabel.font = [GM boldFontWithSize:12.0];
    self.rateButton.titleLabel.numberOfLines = 1;
    self.rateButton.titleLabel.textAlignment = NSTextAlignmentCenter;

    self.contactButtonStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.messageButton,
        self.callButton,
        self.rateButton
    ]];
    self.contactButtonStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contactButtonStack.axis = UILayoutConstraintAxisHorizontal;
    self.contactButtonStack.spacing = 10.0;
    self.contactButtonStack.distribution = UIStackViewDistributionFillEqually;
    [self.heroSurfaceView addSubview:self.contactButtonStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.heroInnerGlowView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:18.0],
        [self.heroInnerGlowView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-20.0],
        [self.heroInnerGlowView.widthAnchor constraintEqualToConstant:116.0],
        [self.heroInnerGlowView.heightAnchor constraintEqualToConstant:116.0],

        [self.heroLiquidBorderView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:1.0],
        [self.heroLiquidBorderView.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:1.0],
        [self.heroLiquidBorderView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-1.0],
        [self.heroLiquidBorderView.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:-1.0],

        [self.heroBackButton.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:kSPSpace12],
        [self.heroBackButton.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:kSPSpace12],
        [self.heroBackButton.widthAnchor constraintEqualToConstant:40.0],
        [self.heroBackButton.heightAnchor constraintEqualToConstant:40.0],

        [self.cartNavButton.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:kSPSpace12],
        [self.cartNavButton.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-kSPSpace12],
        [self.cartNavButton.widthAnchor constraintEqualToConstant:40.0],
        [self.cartNavButton.heightAnchor constraintEqualToConstant:40.0],
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
    surface.backgroundColor = [SPSellerSurfaceColor(self.traitCollection) colorWithAlphaComponent:0.75];
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
    button.layer.borderWidth = 0.85;
    button.titleLabel.font = [GM boldFontWithSize:14.0];
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.76;
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
    button.contentEdgeInsets = UIEdgeInsetsMake(0.0, 9.0, 0.0, 9.0);
    button.imageEdgeInsets = UIEdgeInsetsMake(0.0, 4.0, 0.0, 4.0);
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
    UIColor *brand = SPSellerBrandAccentColor();
    UIColor *gold = SPSellerGoldColor();
    UIColor *titleColor = brand;
    UIColor *fillColor = [brand colorWithAlphaComponent:dark ? 0.11 : 0.075];
    UIColor *borderColor = [brand colorWithAlphaComponent:dark ? 0.24 : 0.17];
    UIColor *shadowColor = UIColor.blackColor;
    CGFloat shadowOpacity = dark ? 0.0 : 0.04;
    CGFloat shadowRadius = 10.0;
    CGSize shadowOffset = CGSizeMake(0.0, 5.0);

    switch (role) {
        case SPSellerHeroActionRolePrimary:
            fillColor = brand;
            titleColor = UIColor.whiteColor;
            borderColor = [[UIColor whiteColor] colorWithAlphaComponent:dark ? 0.08 : 0.18];
            shadowColor = brand;
            shadowOpacity = dark ? 0.0 : 0.16;
            shadowRadius = 16.0;
            shadowOffset = CGSizeMake(0.0, 9.0);
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
                ? [gold colorWithAlphaComponent:0.15]
                : [UIColor colorWithRed:1.00 green:0.965 blue:0.895 alpha:0.84];
            titleColor = gold;
            borderColor = [gold colorWithAlphaComponent:dark ? 0.27 : 0.22];
            shadowColor = gold;
            shadowOpacity = dark ? 0.0 : 0.035;
            break;
    }

    button.backgroundColor = fillColor;
    button.tintColor = titleColor;
    [button setTitleColor:titleColor forState:UIControlStateNormal];
    [button pp_setBorderColor:borderColor];
    button.layer.cornerRadius = kSPButtonHeight / 2.0;
    button.layer.borderWidth = 0.85;
    button.layer.shadowColor = shadowColor.CGColor;
    button.layer.shadowOpacity = shadowOpacity;
    button.layer.shadowRadius = shadowRadius;
    button.layer.shadowOffset = shadowOffset;
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
        [self.heroSurfaceView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:2.0],
        [self.heroSurfaceView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:kSPSpace12],
        [self.heroSurfaceView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-kSPSpace12],

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

        [self.avatarShellView.topAnchor constraintEqualToAnchor:self.heroBackButton.bottomAnchor constant:kSPSpace12],
        [self.avatarShellView.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:kSPSpace16],
        [self.avatarShellView.widthAnchor constraintEqualToConstant:kSPAvatarShellSize],
        [self.avatarShellView.heightAnchor constraintEqualToConstant:kSPAvatarShellSize],

        [self.avatarImageView.centerXAnchor constraintEqualToAnchor:self.avatarShellView.centerXAnchor],
        [self.avatarImageView.centerYAnchor constraintEqualToAnchor:self.avatarShellView.centerYAnchor],
        [self.avatarImageView.widthAnchor constraintEqualToConstant:kSPAvatarSize],
        [self.avatarImageView.heightAnchor constraintEqualToConstant:kSPAvatarSize],

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
        [self.eyebrowLabel.leadingAnchor constraintEqualToAnchor:self.avatarShellView.trailingAnchor constant:kSPSpace12],
        [self.eyebrowLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-kSPSpace16],

        [self.nameLabel.topAnchor constraintEqualToAnchor:self.eyebrowLabel.bottomAnchor constant:kSPSpace4],
        [self.nameLabel.leadingAnchor constraintEqualToAnchor:self.eyebrowLabel.leadingAnchor],
        [self.nameLabel.trailingAnchor constraintEqualToAnchor:self.eyebrowLabel.trailingAnchor],

        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:kSPSpace4],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.nameLabel.trailingAnchor],
        [self.subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.avatarShellView.bottomAnchor],

        [self.statusBadgeView.trailingAnchor constraintEqualToAnchor:self.avatarShellView.trailingAnchor constant:3.0],
        [self.statusBadgeView.bottomAnchor constraintEqualToAnchor:self.avatarShellView.bottomAnchor constant:3.0],
        [self.statusBadgeView.heightAnchor constraintEqualToConstant:30.0],
        [self.statusBadgeView.widthAnchor constraintEqualToConstant:30.0],

        [self.contactButtonStack.topAnchor constraintEqualToAnchor:self.avatarShellView.bottomAnchor constant:kSPSpace20],
        [self.contactButtonStack.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:kSPSpace16],
        [self.contactButtonStack.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-kSPSpace16],
        [self.contactButtonStack.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:-kSPSpace16],
        [self.messageButton.heightAnchor constraintEqualToConstant:kSPButtonHeight],

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
    UIColor *foreground = AppForgroundColr ?: SPSellerSurfaceColor(self.traitCollection);
    UIColor *accent = AppPrimaryClr ?: UIColor.systemRedColor;
    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    self.heroSurfaceView.backgroundColor = dark
        ? [UIColor colorWithWhite:0.10 alpha:0.94]
        : [UIColor colorWithWhite:1.0 alpha:0.92];
    self.heroGradientLayer.colors = @[
        (__bridge id)[(dark ? [UIColor colorWithWhite:0.13 alpha:1.0] : UIColor.whiteColor) colorWithAlphaComponent:(dark ? 0.18 : 0.26)].CGColor,
        (__bridge id)[[accent colorWithAlphaComponent:(dark ? 0.026 : 0.014)] CGColor],
        (__bridge id)[[UIColor colorWithRed:0.80 green:0.66 blue:0.40 alpha:(dark ? 0.018 : 0.010)] CGColor]
    ];
    self.heroBottomFadeLayer.colors = @[
        (__bridge id)[AppBackgroundClr colorWithAlphaComponent:(dark ? 0.92 : 1.0)].CGColor,
        (__bridge id)[AppBackgroundClr colorWithAlphaComponent:(dark ? 0.30 : 0.40)].CGColor,
        (__bridge id)[AppBackgroundClr colorWithAlphaComponent:(dark ? 0.06 : 0.10)].CGColor
    ];
    self.heroBorderGradientLayer.colors = @[
        (__bridge id)[[UIColor whiteColor] colorWithAlphaComponent:(dark ? 0.72 : 0.96)].CGColor,
        (__bridge id)[[UIColor whiteColor] colorWithAlphaComponent:(dark ? 0.46 : 0.76)].CGColor,
        (__bridge id)[[UIColor whiteColor] colorWithAlphaComponent:(dark ? 0.26 : 0.54)].CGColor
    ];
    self.heroInnerGlowView.backgroundColor = [accent colorWithAlphaComponent:(dark ? 0.030 : 0.016)];
    self.heroInnerGlowView.layer.shadowColor = accent.CGColor;
    self.heroInnerGlowView.layer.shadowOpacity = 0.0;
    self.heroInnerGlowView.layer.shadowRadius = 0.0;
    self.heroInnerGlowView.layer.shadowOffset = CGSizeZero;
    [self.heroSurfaceView pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:(dark ? 0.34 : 0.82)]];
    [self.heroLiquidBorderView pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:(dark ? 0.52 : 0.94)]];
    self.heroSurfaceView.layer.shadowOpacity = 0.035;
    self.heroSurfaceView.layer.shadowRadius = 14.0;
    self.heroSurfaceView.layer.shadowOffset = CGSizeMake(0.0, 7.0);
    UIView *heroBlurView = self.heroSurfaceView.subviews.firstObject;
    if ([heroBlurView isKindOfClass:UIVisualEffectView.class]) {
        heroBlurView.alpha = 0.54;
    }
    self.avatarShellView.backgroundColor = SPSellerHeroAvatarShellColor(self.traitCollection);
    self.avatarShellView.layer.shadowColor = SPSellerBrandAccentColor().CGColor;
    self.avatarShellView.layer.shadowOpacity = dark ? 0.0 : 0.10;
    self.avatarShellView.layer.shadowRadius = 18.0;
    self.avatarShellView.layer.shadowOffset = CGSizeMake(0.0, 9.0);
    [self.avatarShellView pp_setBorderColor:SPSellerHeroAvatarStrokeColor(self.traitCollection)];
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
    self.statusBadgeView.backgroundColor = [foreground colorWithAlphaComponent:0.98];
    [self.statusBadgeView pp_setBorderColor:[foreground colorWithAlphaComponent:0.98]];
    [self pp_applyHeroActionStyleToButton:self.messageButton role:SPSellerHeroActionRolePrimary];
    [self pp_applyHeroActionStyleToButton:self.callButton role:SPSellerHeroActionRoleSecondary];
    [self pp_applyHeroActionStyleToButton:self.rateButton role:SPSellerHeroActionRoleTertiary];
    self.itemsRetryButton.backgroundColor = SPSellerInkColor();
    [self.itemsRetryButton setTitleColor:SPSellerSurfaceColor(self.traitCollection) forState:UIControlStateNormal];
    self.glowTopView.backgroundColor = [SPSellerAccentTealColor() colorWithAlphaComponent:self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.16 : 0.11];
    self.glowMiddleView.backgroundColor = [SPSellerRoseColor() colorWithAlphaComponent:self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.13 : 0.08];
    self.glowBottomView.backgroundColor = [SPSellerGoldColor() colorWithAlphaComponent:self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.14 : 0.10];
}

- (void)applySemanticDirection {
    UISemanticContentAttribute semantic = [Language semanticAttributeForCurrentLanguage];
    self.view.semanticContentAttribute = semantic;
    self.heroSurfaceView.semanticContentAttribute = semantic;
    self.contactButtonStack.semanticContentAttribute = semantic;
    self.itemsCollectionView.semanticContentAttribute = semantic;
    self.compactHeaderView.semanticContentAttribute = semantic;
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

    self.messageButton.semanticContentAttribute = semantic;
    self.callButton.semanticContentAttribute = semantic;
    self.rateButton.semanticContentAttribute = semantic;
    self.itemsRetryButton.semanticContentAttribute = semantic;
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
    BOOL canCall = self.seller.MobileNo.length > 0;
    self.messageButton.enabled = canContact;
    self.callButton.enabled = canCall;
    self.messageButton.alpha = canContact ? 1.0 : 0.48;
    self.callButton.alpha = canCall ? 1.0 : 0.48;
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

    BOOL shouldAllowWrappedRateTitle = title.length > 13;
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
    CGFloat width = CGRectGetWidth(self.view.bounds);
    CGFloat height = CGRectGetHeight(self.view.bounds);

    self.glowTopView.frame = CGRectMake(-118.0, 72.0, 246.0, 246.0);
    self.glowMiddleView.frame = CGRectMake(width - 132.0, height * 0.30, 226.0, 226.0);
    self.glowBottomView.frame = CGRectMake(width * 0.15, MAX(height - 236.0, 320.0), 286.0, 286.0);

    self.glowTopView.layer.cornerRadius = CGRectGetWidth(self.glowTopView.bounds) / 2.0;
    self.glowMiddleView.layer.cornerRadius = CGRectGetWidth(self.glowMiddleView.bounds) / 2.0;
    self.glowBottomView.layer.cornerRadius = CGRectGetWidth(self.glowBottomView.bounds) / 2.0;
}

- (void)updateSurfaceShadowPaths {
    if (!CGRectIsEmpty(self.heroSurfaceView.bounds)) {
        self.heroGradientLayer.frame = self.heroSurfaceView.bounds;
        self.heroGradientLayer.cornerRadius = kSPSurfaceCornerRadius;
        self.heroSurfaceView.layer.shadowPath =
            [UIBezierPath bezierPathWithRoundedRect:self.heroSurfaceView.bounds
                                       cornerRadius:kSPSurfaceCornerRadius].CGPath;
        self.heroLiquidBorderView.layer.cornerRadius = MAX(kSPSurfaceCornerRadius - 1.0, 0.0);
        self.heroBorderGradientLayer.frame = self.heroLiquidBorderView.bounds;
        self.heroBorderGradientLayer.cornerRadius = MAX(kSPSurfaceCornerRadius - 1.0, 0.0);
        self.heroInnerGlowView.layer.cornerRadius = CGRectGetWidth(self.heroInnerGlowView.bounds) * 0.5;
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
    if (self.livingBackgroundActive || UIAccessibilityIsReduceMotionEnabled()) return;
    self.livingBackgroundActive = YES;
    [self animateGlowView:self.glowTopView
                  keyPath:@"seller.profile.glow.top"
                    scale:1.08
              translation:CGPointMake(14.0, -10.0)
                 duration:6.8
                    delay:0.0];
    [self animateGlowView:self.glowMiddleView
                  keyPath:@"seller.profile.glow.middle"
                    scale:1.10
              translation:CGPointMake(-16.0, 18.0)
                 duration:7.6
                    delay:0.35];
    [self animateGlowView:self.glowBottomView
                  keyPath:@"seller.profile.glow.bottom"
                    scale:1.07
              translation:CGPointMake(18.0, 12.0)
                 duration:8.4
                    delay:0.18];

}

- (void)animateGlowView:(UIView *)view
                keyPath:(NSString *)key
                  scale:(CGFloat)scale
            translation:(CGPoint)translation
               duration:(NSTimeInterval)duration
                  delay:(NSTimeInterval)delay {
    view.transform = CGAffineTransformIdentity;
    [UIView animateWithDuration:duration
                          delay:delay
                        options:UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        view.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(translation.x, translation.y),
                                                 CGAffineTransformMakeScale(scale, scale));
        view.alpha = 0.92;
    } completion:nil];
    (void)key;
}

- (void)stopLivingBackground {
    self.livingBackgroundActive = NO;
    NSArray<UIView *> *glows = @[self.glowTopView, self.glowMiddleView, self.glowBottomView];
    for (UIView *view in glows) {
        [view.layer removeAllAnimations];
        view.transform = CGAffineTransformIdentity;
    }
}

- (void)animateEntranceIfNeeded {
    if (self.didAnimateEntrance || UIAccessibilityIsReduceMotionEnabled()) {
        self.heroSurfaceView.alpha = 1.0;
        self.itemsTitleLabel.alpha = 1.0;
        self.itemsCollectionView.alpha = 1.0;
        return;
    }
    self.didAnimateEntrance = YES;

    NSArray<UIView *> *views = @[self.heroSurfaceView, self.itemsTitleLabel, self.itemsCollectionView];
    [views enumerateObjectsUsingBlock:^(UIView *view, NSUInteger idx, BOOL *stop) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0.0, 18.0);
        [UIView animateWithDuration:0.52
                              delay:0.06 * idx
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
    self.callButton.accessibilityLabel = [NSString stringWithFormat:@"%@ %@", kLang(@"call"), sellerName];
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
