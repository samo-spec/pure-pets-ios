//
//  PPOrderSupportComposerViewController.m
//  Pure Pets
//

#import "PPOrderSupportComposerViewController.h"
#import "PPOrderSupportRequestDetailsViewController.h"
#import "PPOrder.h"
#import "PPOrderManager.h"
#import "OrderSupportFunc.h"
#import "PPFirebaseSessionBridge.h"
#import "PPHeroGlassBackgroundView.h"
#import "PPFormEngine.h"
#import "PPSelectOptionViewController.h"
#import "OptionModel.h"
#import "UIViewController+PPBottomSurface.h"

@import PhotosUI;

static NSString * const kPPOrderSupportReasonFieldID = @"orderSupportReason";
static NSString * const kPPOrderSupportNotesFieldID = @"orderSupportNotes";
static NSString * const kPPOrderSupportAttachmentFieldID = @"orderSupportAttachment";

static CGFloat PPOrderSupportPremiumTabBarClearance(void)
{
    return (PPIOS26() ? 86.0 : 64.0) + 12.0;
}

@interface PPOrderSupportComposerViewController () <PHPickerViewControllerDelegate>
@property (nonatomic, strong) PPOrder *order;
@property (nonatomic, assign) PPOrderCustomerActionType actionType;
@property (nonatomic, strong) PPOrderManager *orderManager;
@property (nonatomic, copy) dispatch_block_t onComplete;
@property (nonatomic, strong) NSArray<NSDictionary *> *reasonOptions;
@property (nonatomic, strong) NSDictionary *selectedReason;
@property (nonatomic, strong) NSArray<NSDictionary *> *composerItems;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedItemIDs;
@property (nonatomic, strong) NSMutableArray<UIImage *> *selectedImages;

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStackView;
@property (nonatomic, strong) UIView *heroSurfaceView;
@property (nonatomic, strong) UIView *heroContentView;
@property (nonatomic, strong) PPHeroGlassBackgroundView *heroBackgroundView;
@property (nonatomic, strong) UIButton *heroBackButton;
@property (nonatomic, strong) UILabel *heroKickerLabel;
@property (nonatomic, strong) UILabel *heroTitleLabel;
@property (nonatomic, strong) UILabel *heroSubtitleLabel;

@property (nonatomic, strong) UIView *formSurfaceView;
@property (nonatomic, strong) UIStackView *formStackView;
@property (nonatomic, strong) PPFormEngineView *supportFormView;
@property (nonatomic, strong) UIStackView *itemsStackView;

@property (nonatomic, strong) UIView *actionBar;
@property (nonatomic, strong) NSLayoutConstraint *actionBarBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *submitButtonBottomConstraint;
@property (nonatomic, strong) UIButton *submitButton;
@property (nonatomic, strong) UIActivityIndicatorView *submitActivityIndicator;
@property (nonatomic, strong) NSArray<UIView *> *entranceViews;
@property (nonatomic, assign) BOOL didPrepareEntrance;
@property (nonatomic, assign) BOOL didRunEntrance;
@property (nonatomic, assign) BOOL didCaptureNavigationBarHiddenState;
@property (nonatomic, assign) BOOL previousNavigationBarHiddenState;
@end

@implementation PPOrderSupportComposerViewController

+ (instancetype)controllerWithOrder:(PPOrder *)order
                         actionType:(PPOrderCustomerActionType)actionType
                       orderManager:(PPOrderManager *)orderManager
                         onComplete:(dispatch_block_t)onComplete
{
    PPOrderSupportComposerViewController *vc = [PPOrderSupportComposerViewController new];
    vc.order = order;
    vc.actionType = actionType;
    vc.orderManager = orderManager ?: [PPOrderManager shared];
    vc.onComplete = onComplete;
    return vc;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = [PPOrderManager displayTitleForActionType:self.actionType];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    [self pp_orderApplyChevronBackButton];

    self.reasonOptions = [self.orderManager reasonOptionsForAction:self.actionType] ?: @[];
    self.selectedItemIDs = [NSMutableSet set];
    self.selectedImages = [NSMutableArray array];
    self.composerItems = PPOrderSupportComposerItems(self.order) ?: @[];
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);

    [self pp_buildHierarchy];
    [self pp_refreshVisualStyle];
    [self pp_prepareEntranceState];

    UITapGestureRecognizer *dismissKeyboardTap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                             action:@selector(pp_dismissKeyboard)];
    dismissKeyboardTap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:dismissKeyboardTap];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_keyboardWillChangeFrame:)
                                                 name:UIKeyboardWillChangeFrameNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (!self.didCaptureNavigationBarHiddenState) {
        self.previousNavigationBarHiddenState = self.navigationController.navigationBarHidden;
        self.didCaptureNavigationBarHiddenState = YES;
    }
    [self.navigationController setNavigationBarHidden:YES animated:animated];
    [[PPBottomSurfaceCoordinator sharedCoordinator] applySurfaceForController:self animated:animated];
    [self pp_prepareEntranceState];
    [self pp_updateActionBarForCurrentInsets];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.heroBackgroundView startAnimations];
    [self pp_runEntranceIfNeeded];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.heroBackgroundView stopAnimations];
    if (self.didCaptureNavigationBarHiddenState && self.navigationController) {
        [self.navigationController setNavigationBarHidden:self.previousNavigationBarHiddenState animated:animated];
    }
}

- (void)viewSafeAreaInsetsDidChange
{
    [super viewSafeAreaInsetsDidChange];
    [self pp_updateActionBarForCurrentInsets];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_refreshVisualStyle];
            [self.heroBackgroundView reapplyPalette];
        }
    }
}

#pragma mark - Hierarchy

- (void)pp_buildHierarchy
{
    UISemanticContentAttribute semantic = Language.semanticAttributeForCurrentLanguage;

    UIView *ambientWash = [[UIView alloc] initWithFrame:CGRectZero];
    ambientWash.translatesAutoresizingMaskIntoConstraints = NO;
    ambientWash.userInteractionEnabled = NO;
    ambientWash.isAccessibilityElement = NO;
    ambientWash.backgroundColor = [[self pp_primaryColor] colorWithAlphaComponent:0.028];
    PPApplyContinuousCorners(ambientWash, 999.0);
    [self.view addSubview:ambientWash];

    self.actionBar = [[UIView alloc] initWithFrame:CGRectZero];
    self.actionBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionBar.semanticContentAttribute = semantic;
    [self.view addSubview:self.actionBar];

    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.scrollView.semanticContentAttribute = semantic;
    [self.view insertSubview:self.scrollView belowSubview:self.actionBar];

    self.contentStackView = [[UIStackView alloc] initWithFrame:CGRectZero];
    self.contentStackView.axis = UILayoutConstraintAxisVertical;
    self.contentStackView.spacing = 16.0;
    self.contentStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStackView.semanticContentAttribute = semantic;
    [self.scrollView addSubview:self.contentStackView];

    self.actionBarBottomConstraint = [self.actionBar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor];

    [self pp_buildHero];

    [NSLayoutConstraint activateConstraints:@[
        [ambientWash.widthAnchor constraintEqualToAnchor:self.view.widthAnchor multiplier:0.78],
        [ambientWash.heightAnchor constraintEqualToAnchor:ambientWash.widthAnchor],
        [ambientWash.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:96.0],
        [ambientWash.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:22.0],

        [self.actionBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.actionBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        self.actionBarBottomConstraint,

        [self.heroSurfaceView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20.0],
        [self.heroSurfaceView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20.0],
        [self.heroSurfaceView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12.0],
        [self.heroSurfaceView.heightAnchor constraintGreaterThanOrEqualToConstant:156.0],

        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:14.0],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.actionBar.topAnchor],

        [self.contentStackView.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor constant:20.0],
        [self.contentStackView.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor constant:-20.0],
        [self.contentStackView.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor],
        [self.contentStackView.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-28.0],
        [self.contentStackView.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor constant:-40.0]
    ]];

    [self pp_buildForm];
    [self pp_buildActionBar];
}

- (void)pp_buildHero
{
    UISemanticContentAttribute semantic = Language.semanticAttributeForCurrentLanguage;
    NSTextAlignment alignment = Language.alignmentForCurrentLanguage;
    UIColor *accent = [self pp_primaryColor];

    self.heroSurfaceView = [[UIView alloc] initWithFrame:CGRectZero];
    self.heroSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSurfaceView.clipsToBounds = YES;
    self.heroSurfaceView.semanticContentAttribute = semantic;
    PPApplyContinuousCorners(self.heroSurfaceView, PPCornerHero);
    [self.view insertSubview:self.heroSurfaceView belowSubview:self.actionBar];

    self.heroBackgroundView = [PPHeroGlassBackgroundView new];
    self.heroBackgroundView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroBackgroundView.accentStyle = PPHeroGlassAccentStyleCornerGlow;
    self.heroBackgroundView.cornerGlowOpacityMultiplier = 0.56;
    self.heroBackgroundView.accentColorOverride = accent;
    [self.heroSurfaceView addSubview:self.heroBackgroundView];

    self.heroContentView = [[UIView alloc] initWithFrame:CGRectZero];
    self.heroContentView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroContentView.semanticContentAttribute = semantic;
    [self.heroSurfaceView addSubview:self.heroContentView];

    UIStackView *topChromeStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    topChromeStack.axis = UILayoutConstraintAxisHorizontal;
    topChromeStack.alignment = UIStackViewAlignmentCenter;
    topChromeStack.distribution = UIStackViewDistributionFill;
    topChromeStack.spacing = 12.0;
    topChromeStack.translatesAutoresizingMaskIntoConstraints = NO;
    topChromeStack.semanticContentAttribute = semantic;
    [self.heroContentView addSubview:topChromeStack];

    self.heroBackButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.heroBackButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroBackButton.accessibilityLabel = kLang(@"Back");
    self.heroBackButton.tintColor = UIColor.labelColor;
    self.heroBackButton.backgroundColor = [UIColor.systemBackgroundColor colorWithAlphaComponent:0.58];
    self.heroBackButton.layer.borderWidth = 0.75;
    [self.heroBackButton pp_setBorderColor:[[UIColor labelColor] colorWithAlphaComponent:0.08]];
    PPApplyContinuousCorners(self.heroBackButton, 22.0);
    UIImage *backImage = [UIImage systemImageNamed:(semantic == UISemanticContentAttributeForceRightToLeft ? @"chevron.right" : @"chevron.left")
                                 withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:16.0
                                                                                                   weight:UIImageSymbolWeightSemibold]];
    [self.heroBackButton setImage:backImage forState:UIControlStateNormal];
    [self.heroBackButton addTarget:self action:@selector(backTapped) forControlEvents:UIControlEventTouchUpInside];
    [self pp_installPressMotionOnControl:self.heroBackButton];
    [topChromeStack addArrangedSubview:self.heroBackButton];

    self.heroTitleLabel = [self pp_makeLabelWithFont:[GM boldFontWithSize:27]
                                            textStyle:UIFontTextStyleTitle2
                                                color:UIColor.labelColor];
    self.heroTitleLabel.numberOfLines = 1;
    self.heroTitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.heroTitleLabel.text = self.title;
    self.heroTitleLabel.textAlignment = NSTextAlignmentCenter;
    [self.heroTitleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                         forAxis:UILayoutConstraintAxisHorizontal];
    [self.heroTitleLabel setContentHuggingPriority:UILayoutPriorityDefaultLow
                                           forAxis:UILayoutConstraintAxisHorizontal];
    [topChromeStack addArrangedSubview:self.heroTitleLabel];

    UIView *iconBadge = [[UIView alloc] initWithFrame:CGRectZero];
    iconBadge.translatesAutoresizingMaskIntoConstraints = NO;
    iconBadge.backgroundColor = [accent colorWithAlphaComponent:0.16];
    PPApplyContinuousCorners(iconBadge, 22.0);
    [topChromeStack addArrangedSubview:iconBadge];

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:[self pp_heroSymbolName]
                                                                   withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20.0
                                                                                                                             weight:UIImageSymbolWeightSemibold]]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.tintColor = accent;
    iconView.isAccessibilityElement = NO;
    [iconBadge addSubview:iconView];

    UIStackView *textStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.alignment = UIStackViewAlignmentFill;
    textStack.spacing = 6.0;
    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    textStack.semanticContentAttribute = semantic;
    [self.heroContentView addSubview:textStack];

    self.heroKickerLabel = [self pp_makeLabelWithFont:[GM boldFontWithSize:12]
                                             textStyle:UIFontTextStyleCaption1
                                                 color:[accent colorWithAlphaComponent:0.95]];
    self.heroKickerLabel.text = [self pp_orderReferenceText];
    self.heroKickerLabel.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    self.heroKickerLabel.textAlignment = alignment;

    self.heroSubtitleLabel = [self pp_makeLabelWithFont:[GM MidFontWithSize:15]
                                               textStyle:UIFontTextStyleSubheadline
                                                   color:UIColor.secondaryLabelColor];
    self.heroSubtitleLabel.numberOfLines = 2;
    self.heroSubtitleLabel.text = [self.orderManager eligibilityForAction:self.actionType
                                                                      order:self.order
                                                                   requests:@[]
                                                              referenceDate:[NSDate date]].message;
    self.heroSubtitleLabel.textAlignment = alignment;

    [textStack addArrangedSubview:self.heroKickerLabel];
    [textStack addArrangedSubview:self.heroSubtitleLabel];
    [textStack setCustomSpacing:5.0 afterView:self.heroKickerLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.heroBackgroundView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor],
        [self.heroBackgroundView.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor],
        [self.heroBackgroundView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor],
        [self.heroBackgroundView.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor],

        [self.heroContentView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor],
        [self.heroContentView.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor],
        [self.heroContentView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor],
        [self.heroContentView.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor],

        [topChromeStack.leadingAnchor constraintEqualToAnchor:self.heroContentView.leadingAnchor constant:16.0],
        [topChromeStack.trailingAnchor constraintEqualToAnchor:self.heroContentView.trailingAnchor constant:-16.0],
        [topChromeStack.topAnchor constraintEqualToAnchor:self.heroContentView.topAnchor constant:14.0],
        [self.heroBackButton.widthAnchor constraintEqualToConstant:44.0],
        [self.heroBackButton.heightAnchor constraintEqualToConstant:44.0],
        [iconBadge.widthAnchor constraintEqualToConstant:44.0],
        [iconBadge.heightAnchor constraintEqualToConstant:44.0],
        [iconView.centerXAnchor constraintEqualToAnchor:iconBadge.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconBadge.centerYAnchor],

        [textStack.leadingAnchor constraintEqualToAnchor:self.heroContentView.leadingAnchor constant:18.0],
        [textStack.trailingAnchor constraintEqualToAnchor:self.heroContentView.trailingAnchor constant:-18.0],
        [textStack.topAnchor constraintEqualToAnchor:topChromeStack.bottomAnchor constant:12.0],
        [textStack.bottomAnchor constraintEqualToAnchor:self.heroContentView.bottomAnchor constant:-16.0]
    ]];

    self.heroSurfaceView.isAccessibilityElement = YES;
    self.heroSurfaceView.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", self.title ?: @"", [self pp_orderReferenceText]];
    self.heroSurfaceView.accessibilityTraits = UIAccessibilityTraitStaticText;
}

- (void)pp_buildForm
{
    UISemanticContentAttribute semantic = Language.semanticAttributeForCurrentLanguage;

    self.formSurfaceView = [[UIView alloc] initWithFrame:CGRectZero];
    self.formSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.formSurfaceView.semanticContentAttribute = semantic;
    self.formSurfaceView.backgroundColor = UIColor.clearColor;
    self.formSurfaceView.layer.borderWidth = 0.0;
    self.formSurfaceView.layer.shadowOpacity = 0.0;
    [self.contentStackView addArrangedSubview:self.formSurfaceView];

    self.formStackView = [[UIStackView alloc] initWithFrame:CGRectZero];
    self.formStackView.axis = UILayoutConstraintAxisVertical;
    self.formStackView.spacing = 14.0;
    self.formStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.formStackView.semanticContentAttribute = semantic;
    [self.formSurfaceView addSubview:self.formStackView];
    [NSLayoutConstraint activateConstraints:@[
        [self.formStackView.leadingAnchor constraintEqualToAnchor:self.formSurfaceView.leadingAnchor],
        [self.formStackView.trailingAnchor constraintEqualToAnchor:self.formSurfaceView.trailingAnchor],
        [self.formStackView.topAnchor constraintEqualToAnchor:self.formSurfaceView.topAnchor],
        [self.formStackView.bottomAnchor constraintEqualToAnchor:self.formSurfaceView.bottomAnchor]
    ]];

    self.supportFormView = [[PPFormEngineView alloc] initWithStyle:[self pp_supportFormStyle]];
    self.supportFormView.translatesAutoresizingMaskIntoConstraints = NO;
    self.supportFormView.validatesOnChange = YES;
    [self.formStackView addArrangedSubview:self.supportFormView];
    [self pp_configureSupportFormFields];

    self.itemsStackView = [[UIStackView alloc] initWithFrame:CGRectZero];
    self.itemsStackView.axis = UILayoutConstraintAxisVertical;
    self.itemsStackView.spacing = 8.0;
    self.itemsStackView.semanticContentAttribute = semantic;
    [self.formStackView addArrangedSubview:self.itemsStackView];

    [self rebuildItemsSelection];
    [self refreshAttachmentLabel];
}

- (PPFormStyle *)pp_supportFormStyle
{
    PPFormStyle *style = [PPFormStyle defaultStyle];
    UIColor *accent = [self pp_primaryColor];
    style.cardBackgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithRed:0.16 green:0.16 blue:0.18 alpha:1.0]
            : UIColor.whiteColor;
    }];
    style.fieldBackgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithRed:0.12 green:0.12 blue:0.13 alpha:1.0]
            : [UIColor colorWithRed:0.973 green:0.974 blue:0.978 alpha:1.0];
    }];
    style.accentColor = accent;
    style.primaryTextColor = UIColor.labelColor;
    style.secondaryTextColor = UIColor.secondaryLabelColor;
    style.cardBorderColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.06]
            : [[UIColor labelColor] colorWithAlphaComponent:0.055];
    }];
    style.fieldBorderColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.065]
            : [[UIColor labelColor] colorWithAlphaComponent:0.06];
    }];
    style.shadowColor = UIColor.blackColor;
    style.shadowOpacity = 0.022;
    style.shadowRadius = 16.0;
    style.shadowOffset = CGSizeMake(0.0, 8.0);
    style.cardBorderWidth = 0.75;
    style.stackSpacing = 12.0;
    style.cardCornerRadius = 24.0;
    style.fieldCornerRadius = 14.0;
    style.minimumSingleLineFieldHeight = 60.0;
    style.minimumTextViewFieldHeight = 132.0;
    style.attachmentThumbSize = 48.0;
    style.titleFont = [self pp_composerFont:[GM boldFontWithSize:14] textStyle:UIFontTextStyleSubheadline];
    style.inputFont = [self pp_composerFont:[GM MidFontWithSize:16] textStyle:UIFontTextStyleBody];
    style.placeholderFont = [self pp_composerFont:[GM MidFontWithSize:15] textStyle:UIFontTextStyleBody];
    style.attachmentTitleFont = [self pp_composerFont:[GM boldFontWithSize:15] textStyle:UIFontTextStyleSubheadline];
    style.attachmentSubtitleFont = [self pp_composerFont:[GM MidFontWithSize:13] textStyle:UIFontTextStyleFootnote];
    return style;
}

- (void)pp_configureSupportFormFields
{
    __weak typeof(self) weakSelf = self;

    PPFormFieldConfig *reason = [PPFormFieldConfig fieldWithIdentifier:kPPOrderSupportReasonFieldID
                                                                  title:kLang(@"order_request_reason_title")
                                                            placeholder:kLang(@"order_request_select_reason")
                                                              inputType:PPFormInputTypePicker];
    reason.required = self.reasonOptions.count > 0;
    reason.value = self.selectedReason ? (self.selectedReason[@"title"] ?: @"") : @"";
    reason.pickerTapBlock = ^(PPFormFieldConfig *config, PPFormFieldRowView *row) {
        (void)config;
        (void)row;
        [weakSelf selectReasonTapped];
    };

    PPFormFieldConfig *notes = [PPFormFieldConfig fieldWithIdentifier:kPPOrderSupportNotesFieldID
                                                                 title:kLang(@"order_request_notes_title")
                                                           placeholder:kLang(@"order_request_notes_title")
                                                             inputType:PPFormInputTypeTextView];

    PPFormFieldConfig *attachment = [PPFormFieldConfig fieldWithIdentifier:kPPOrderSupportAttachmentFieldID
                                                                      title:kLang(@"order_request_attachments_title")
                                                                placeholder:@""
                                                                  inputType:PPFormInputTypeAttachment];
    attachment.attachmentTitle = kLang(@"order_request_add_photos");
    attachment.attachmentSubtitle = kLang(@"order_request_photos_optional");
    attachment.attachmentTapBlock = ^(PPFormFieldConfig *config, PPFormFieldRowView *row) {
        (void)config;
        (void)row;
        [weakSelf addPhotosTapped];
    };
    attachment.attachmentRemoveBlock = ^(PPFormFieldConfig *config, PPFormFieldRowView *row) {
        (void)config;
        (void)row;
        [weakSelf.selectedImages removeAllObjects];
        [weakSelf refreshAttachmentLabel];
    };

    [self.supportFormView setFields:@[reason, notes, attachment]];
    [self refreshAttachmentLabel];
}

- (void)pp_buildActionBar
{
    UIVisualEffectView *materialView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial]];
    materialView.translatesAutoresizingMaskIntoConstraints = NO;
    materialView.userInteractionEnabled = YES;
    [self.actionBar addSubview:materialView];

    UIView *hairline = [[UIView alloc] initWithFrame:CGRectZero];
    hairline.translatesAutoresizingMaskIntoConstraints = NO;
    hairline.backgroundColor = [UIColor.separatorColor colorWithAlphaComponent:0.32];
    [self.actionBar addSubview:hairline];

    self.submitButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.submitButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.submitButton.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.submitButton.titleLabel.font = [self pp_composerFont:[GM boldFontWithSize:17] textStyle:UIFontTextStyleHeadline];
    self.submitButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    self.submitButton.titleLabel.numberOfLines = 1;
    [self.submitButton setTitle:kLang(@"order_request_submit") forState:UIControlStateNormal];
    [self.submitButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.submitButton.accessibilityLabel = kLang(@"order_request_submit");
    [self pp_applyPrimaryActionStyleToButton:self.submitButton];
    [self.submitButton addTarget:self action:@selector(submitTapped) forControlEvents:UIControlEventTouchUpInside];
    [self pp_installPressMotionOnControl:self.submitButton];
    [materialView.contentView addSubview:self.submitButton];

    self.submitActivityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.submitActivityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.submitActivityIndicator.hidesWhenStopped = YES;
    self.submitActivityIndicator.color = UIColor.whiteColor;
    self.submitActivityIndicator.isAccessibilityElement = NO;
    [self.submitButton addSubview:self.submitActivityIndicator];

    self.submitButtonBottomConstraint = [self.submitButton.bottomAnchor constraintEqualToAnchor:materialView.contentView.safeAreaLayoutGuide.bottomAnchor
                                                                                       constant:-10.0];

    [NSLayoutConstraint activateConstraints:@[
        [materialView.leadingAnchor constraintEqualToAnchor:self.actionBar.leadingAnchor],
        [materialView.trailingAnchor constraintEqualToAnchor:self.actionBar.trailingAnchor],
        [materialView.topAnchor constraintEqualToAnchor:self.actionBar.topAnchor],
        [materialView.bottomAnchor constraintEqualToAnchor:self.actionBar.bottomAnchor],
        [hairline.leadingAnchor constraintEqualToAnchor:self.actionBar.leadingAnchor],
        [hairline.trailingAnchor constraintEqualToAnchor:self.actionBar.trailingAnchor],
        [hairline.topAnchor constraintEqualToAnchor:self.actionBar.topAnchor],
        [hairline.heightAnchor constraintEqualToConstant:0.5],
        [self.submitButton.leadingAnchor constraintEqualToAnchor:materialView.contentView.leadingAnchor constant:20.0],
        [self.submitButton.trailingAnchor constraintEqualToAnchor:materialView.contentView.trailingAnchor constant:-20.0],
        [self.submitButton.topAnchor constraintEqualToAnchor:materialView.contentView.topAnchor constant:12.0],
        self.submitButtonBottomConstraint,
        [self.submitButton.heightAnchor constraintGreaterThanOrEqualToConstant:56.0],
        [self.submitActivityIndicator.centerYAnchor constraintEqualToAnchor:self.submitButton.centerYAnchor],
        [self.submitActivityIndicator.trailingAnchor constraintEqualToAnchor:self.submitButton.trailingAnchor constant:-18.0]
    ]];

    [self pp_updateActionBarForCurrentInsets];
}

#pragma mark - Visual System

- (UIFont *)pp_composerFont:(UIFont *)font textStyle:(UIFontTextStyle)textStyle
{
    if (!font) return [UIFont preferredFontForTextStyle:textStyle];
    return [[UIFontMetrics metricsForTextStyle:textStyle] scaledFontForFont:font];
}

- (UILabel *)pp_makeLabelWithFont:(UIFont *)font textStyle:(UIFontTextStyle)textStyle color:(UIColor *)color
{
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.font = [self pp_composerFont:font textStyle:textStyle];
    label.adjustsFontForContentSizeCategory = YES;
    label.textColor = color;
    label.numberOfLines = 0;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    return label;
}

- (UILabel *)pp_makeSectionTitle:(NSString *)title
{
    UILabel *label = [self pp_makeLabelWithFont:[GM boldFontWithSize:14]
                                      textStyle:UIFontTextStyleSubheadline
                                          color:UIColor.labelColor];
    label.text = title;
    return label;
}

- (UIColor *)pp_primaryColor
{
    return [GM appPrimaryColor] ?: UIColor.systemTealColor;
}

- (NSString *)pp_heroSymbolName
{
    switch (self.actionType) {
        case PPOrderCustomerActionTypeCancel:
            return @"xmark.circle.fill";
        case PPOrderCustomerActionTypeReturn:
            return @"arrow.uturn.backward.circle.fill";
        case PPOrderCustomerActionTypeRefund:
            return @"creditcard.fill";
        case PPOrderCustomerActionTypeReplacement:
            return @"arrow.triangle.2.circlepath.circle.fill";
        case PPOrderCustomerActionTypeComplaint:
            return @"exclamationmark.bubble.fill";
        case PPOrderCustomerActionTypeSupport:
            return @"bubble.left.and.bubble.right.fill";
        case PPOrderCustomerActionTypeTrack:
        default:
            return @"questionmark.bubble.fill";
    }
}

- (NSString *)pp_orderReferenceText
{
    NSString *reference = [self.order displayOrderReference];
    if (reference.length == 0) reference = self.order.orderNumber;
    if (reference.length == 0) reference = self.order.orderId;
    return reference.length > 0 ? [NSString stringWithFormat:@"#%@", reference] : @"#--";
}

- (void)pp_keyboardWillChangeFrame:(NSNotification *)notification
{
    CGRect keyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardFrameInView = [self.view convertRect:keyboardFrame fromView:nil];
    CGFloat overlap = MAX(0.0, CGRectGetMaxY(self.view.bounds) - CGRectGetMinY(keyboardFrameInView));
    CGFloat keyboardInset = MAX(0.0, overlap - self.view.safeAreaInsets.bottom);
    [self pp_animateActionBarToBottomConstant:-keyboardInset notification:notification];
    [self pp_updateActionBarForKeyboardVisible:keyboardInset > 0.0];
}

- (void)pp_keyboardWillHide:(NSNotification *)notification
{
    [self pp_animateActionBarToBottomConstant:0.0 notification:notification];
    [self pp_updateActionBarForKeyboardVisible:NO];
}

- (void)pp_animateActionBarToBottomConstant:(CGFloat)bottomConstant notification:(NSNotification *)notification
{
    self.actionBarBottomConstraint.constant = bottomConstant;
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    if (duration <= 0.0) duration = 0.25;
    UIViewAnimationCurve curve = [notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    UIViewAnimationOptions options = (UIViewAnimationOptions)(curve << 16);
    options |= UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction;
    [UIView animateWithDuration:duration
                          delay:0.0
                        options:options
                     animations:^{
        [self.view layoutIfNeeded];
    } completion:nil];
}

- (void)pp_updateActionBarForCurrentInsets
{
    [self pp_updateActionBarForKeyboardVisible:self.actionBarBottomConstraint.constant < -0.5];
}

- (void)pp_updateActionBarForKeyboardVisible:(BOOL)keyboardVisible
{
    CGFloat rootDockClearance = keyboardVisible ? 0.0 : [self pp_rootTabBarBottomClearance];
    self.submitButtonBottomConstraint.constant = -(10.0 + rootDockClearance);

    UIEdgeInsets contentInset = self.scrollView.contentInset;
    contentInset.bottom = 18.0;
    self.scrollView.contentInset = contentInset;

    UIEdgeInsets indicatorInset = self.scrollView.scrollIndicatorInsets;
    indicatorInset.bottom = contentInset.bottom;
    self.scrollView.scrollIndicatorInsets = indicatorInset;
}

- (CGFloat)pp_rootTabBarBottomClearance
{
    if (!self.tabBarController || self.tabBarController.tabBar.hidden) {
        return 0.0;
    }
    return PPOrderSupportPremiumTabBarClearance();
}

- (void)pp_refreshVisualStyle
{
    UIColor *accent = [self pp_primaryColor];
    self.heroBackgroundView.accentColorOverride = accent;
    self.heroSurfaceView.layer.borderWidth = 0.75;
    [self.heroSurfaceView pp_setBorderColor:[accent colorWithAlphaComponent:0.18]];
    self.heroBackButton.backgroundColor = [UIColor.systemBackgroundColor colorWithAlphaComponent:0.58];
    [self.heroBackButton pp_setBorderColor:[[UIColor labelColor] colorWithAlphaComponent:0.08]];
    self.formSurfaceView.backgroundColor = UIColor.clearColor;
    self.formSurfaceView.layer.borderWidth = 0.0;
    self.formSurfaceView.layer.shadowOpacity = 0.0;
    self.supportFormView.style = [self pp_supportFormStyle];
    [self pp_syncReasonSelectionToForm];
    [self pp_applyPrimaryActionStyleToButton:self.submitButton];
    [self refreshAttachmentLabel];
}

- (void)pp_applyQuietControlStyleToButton:(UIButton *)button
{
    if (!button) return;
    button.adjustsImageWhenHighlighted = NO;
    button.backgroundColor = PPOrderDetailsSubsurfaceColor();
    button.tintColor = [self pp_primaryColor];
    button.layer.borderWidth = 0.75;
    button.layer.shadowOpacity = 0.0;
    PPApplyContinuousCorners(button, PPCornerMedium);
    [button pp_setBorderColor:[[UIColor labelColor] colorWithAlphaComponent:0.075]];
}

- (void)pp_applyPrimaryActionStyleToButton:(UIButton *)button
{
    if (!button) return;
    UIColor *accent = [self pp_primaryColor];
    button.adjustsImageWhenHighlighted = NO;
    button.backgroundColor = accent;
    button.tintColor = UIColor.whiteColor;
    button.layer.borderWidth = 0.0;
    button.layer.shadowColor = accent.CGColor;
    button.layer.shadowOpacity = 0.12;
    button.layer.shadowRadius = 10.0;
    button.layer.shadowOffset = CGSizeMake(0.0, 5.0);
    PPApplyContinuousCorners(button, 20.0);
}

- (void)pp_syncReasonSelectionToForm
{
    [self.supportFormView setValue:(self.selectedReason ? (self.selectedReason[@"title"] ?: @"") : @"")
                     forIdentifier:kPPOrderSupportReasonFieldID];
}

#pragma mark - Motion

- (void)pp_installPressMotionOnControl:(UIControl *)control
{
    [control addTarget:self action:@selector(pp_controlTouchDown:) forControlEvents:UIControlEventTouchDown];
    [control addTarget:self action:@selector(pp_controlTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
}

- (void)pp_prepareEntranceState
{
    if (self.didRunEntrance || self.didPrepareEntrance) return;
    self.didPrepareEntrance = YES;
    self.entranceViews = @[self.heroSurfaceView, self.formSurfaceView, self.actionBar];
    if (UIAccessibilityIsReduceMotionEnabled()) return;

    self.heroSurfaceView.alpha = 0.0;
    self.heroSurfaceView.transform = CGAffineTransformMakeScale(0.985, 0.985);
    self.formSurfaceView.alpha = 0.0;
    self.formSurfaceView.transform = CGAffineTransformMakeTranslation(0.0, 12.0);
    self.actionBar.alpha = 0.0;
    self.actionBar.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
}

- (void)pp_runEntranceIfNeeded
{
    if (self.didRunEntrance) return;
    self.didRunEntrance = YES;
    if (UIAccessibilityIsReduceMotionEnabled()) return;

    [self.view layoutIfNeeded];
    [UIView animateWithDuration:0.42
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.heroSurfaceView.alpha = 1.0;
        self.heroSurfaceView.transform = CGAffineTransformIdentity;
    } completion:nil];
    [UIView animateWithDuration:0.36
                          delay:0.07
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.formSurfaceView.alpha = 1.0;
        self.formSurfaceView.transform = CGAffineTransformIdentity;
    } completion:nil];
    [UIView animateWithDuration:0.42
                          delay:0.13
         usingSpringWithDamping:0.90
          initialSpringVelocity:0.35
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.actionBar.alpha = 1.0;
        self.actionBar.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_controlTouchDown:(UIControl *)control
{
    if (UIAccessibilityIsReduceMotionEnabled() || !control.enabled) return;
    [UIView animateWithDuration:0.08
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        control.transform = CGAffineTransformMakeScale(0.985, 0.985);
    } completion:nil];
}

- (void)pp_controlTouchUp:(UIControl *)control
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        control.transform = CGAffineTransformIdentity;
        return;
    }
    [UIView animateWithDuration:0.18
                          delay:0.0
         usingSpringWithDamping:0.82
          initialSpringVelocity:0.35
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        control.transform = CGAffineTransformIdentity;
    } completion:nil];
}

#pragma mark - Inputs

- (void)backTapped
{
    if (self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)pp_dismissKeyboard
{
    [self.view endEditing:YES];
}

- (void)showMessage:(NSString *)message title:(NSString *)title
{
    NSString *safeMessage = message.length > 0
        ? [PPFirebaseSessionBridge publicMessageForText:message fallbackKey:@"pp_order_support_submit_failed"]
        : message;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:safeMessage
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"OK") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)selectReasonTapped
{
    if (self.reasonOptions.count == 0) return;

    NSArray<OptionModel *> *options = [self pp_reasonOptionModels];
    __weak typeof(self) weakSelf = self;
    PPSelectOptionViewController *selector =
    [[PPSelectOptionViewController alloc] initWithOptions:options
                                                    title:kLang(@"order_request_select_reason")
                                                      row:nil
                                         presentationStyle:PPSelectOptionPresentationSheet
                                               completion:^(id  _Nullable selectedObject) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || ![selectedObject isKindOfClass:OptionModel.class]) return;
            OptionModel *option = (OptionModel *)selectedObject;
            NSDictionary *reason = [strongSelf pp_reasonOptionForCode:option.optID];
            if (!reason) return;

            strongSelf.selectedReason = reason;
            [strongSelf pp_syncReasonSelectionToForm];
            [strongSelf.supportFormView clearErrors];
            UISelectionFeedbackGenerator *feedback = [UISelectionFeedbackGenerator new];
            [feedback prepare];
            [feedback selectionChanged];
            [strongSelf rebuildItemsSelection];
        });
    }];
    selector.showSearchBar = NO;
    selector.usesCompactOptionIcons = YES;
    selector.usesCompactPremiumHero = YES;
    selector.premiumHeroAccentColor = [self pp_primaryColor];
    [selector configurePremiumHeroWithEyebrow:[self pp_orderReferenceText]
                                        title:kLang(@"order_request_select_reason")
                                     subtitle:[PPOrderManager displayTitleForActionType:self.actionType]
                                   symbolName:[self pp_heroSymbolName]
                                    badgeText:nil];

    NSDictionary *selectedReason = self.selectedReason;
    if (selectedReason) {
        NSString *selectedCode = selectedReason[@"code"] ?: @"";
        for (OptionModel *option in options) {
            if ([option.optID isEqualToString:selectedCode]) {
                selector.selectedOption = option;
                break;
            }
        }
    }

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:selector];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (NSArray<OptionModel *> *)pp_reasonOptionModels
{
    NSMutableArray<OptionModel *> *options = [NSMutableArray arrayWithCapacity:self.reasonOptions.count];
    for (NSDictionary *reason in self.reasonOptions) {
        NSString *code = [reason[@"code"] isKindOfClass:NSString.class] ? reason[@"code"] : @"other";
        NSString *title = [reason[@"title"] isKindOfClass:NSString.class] ? reason[@"title"] : code;
        NSString *subtitle = [reason[@"subtitle"] isKindOfClass:NSString.class] ? reason[@"subtitle"] : nil;
        OptionModel *option = [[OptionModel alloc] initWithID:code
                                                        title:title
                                                     subtitle:subtitle
                                                    imageName:nil
                                              systemImageName:[self pp_reasonSymbolNameForCode:code]];
        [options addObject:option];
    }
    return options.copy;
}

- (NSDictionary *)pp_reasonOptionForCode:(NSString *)code
{
    NSString *safeCode = [code isKindOfClass:NSString.class] ? code : @"";
    for (NSDictionary *reason in self.reasonOptions) {
        NSString *reasonCode = [reason[@"code"] isKindOfClass:NSString.class] ? reason[@"code"] : @"";
        if ([reasonCode isEqualToString:safeCode]) return reason;
    }
    return nil;
}

- (NSString *)pp_reasonSymbolNameForCode:(NSString *)code
{
    NSString *safeCode = [code isKindOfClass:NSString.class] ? code : @"";
    if ([safeCode containsString:@"payment"] || [safeCode containsString:@"billing"] || [safeCode containsString:@"charged"]) {
        return @"creditcard.and.123";
    }
    if ([safeCode containsString:@"damaged"] || [safeCode containsString:@"quality"] || [safeCode containsString:@"defective"]) {
        return @"shippingbox.and.arrow.backward.fill";
    }
    if ([safeCode containsString:@"wrong"] || [safeCode containsString:@"missing"]) {
        return @"exclamationmark.triangle.fill";
    }
    if ([safeCode containsString:@"delivery"] || [safeCode containsString:@"late"]) {
        return @"truck.box.fill";
    }
    if ([safeCode containsString:@"mind"] || [safeCode containsString:@"mistake"] || [safeCode containsString:@"alternative"]) {
        return @"arrow.uturn.backward.circle.fill";
    }
    return @"bubble.left.and.exclamationmark.bubble.right.fill";
}

- (void)rebuildItemsSelection
{
    for (UIView *view in self.itemsStackView.arrangedSubviews) {
        [self.itemsStackView removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    BOOL requiresItems = self.selectedReason ? [self.selectedReason[@"requiresItemSelection"] boolValue] : NO;
    self.itemsStackView.hidden = !requiresItems || self.composerItems.count == 0;
    if (self.itemsStackView.hidden) return;

    UILabel *title = [self pp_makeSectionTitle:kLang(@"order_request_items_title")];
    [self.itemsStackView addArrangedSubview:title];

    for (NSInteger index = 0; index < (NSInteger)self.composerItems.count; index++) {
        NSDictionary *item = self.composerItems[index];
        NSString *itemID = item[@"id"] ?: @"";
        BOOL selected = [self.selectedItemIDs containsObject:itemID];
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = index;
        button.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
        button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
        button.contentEdgeInsets = UIEdgeInsetsMake(12.0, 14.0, 12.0, 14.0);
        button.titleLabel.font = [self pp_composerFont:[GM MidFontWithSize:15] textStyle:UIFontTextStyleBody];
        button.titleLabel.adjustsFontForContentSizeCategory = YES;
        button.titleLabel.numberOfLines = 0;
        button.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
        NSString *titleText = [NSString stringWithFormat:@"%@ x%@", item[@"name"] ?: itemID, item[@"quantity"] ?: @1];
        [button setTitle:titleText forState:UIControlStateNormal];
        [button setImage:[UIImage systemImageNamed:selected ? @"checkmark.circle.fill" : @"circle"
                                        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:17.0
                                                                                                  weight:UIImageSymbolWeightSemibold]]
                 forState:UIControlStateNormal];
        UIColor *accent = [self pp_primaryColor];
        button.tintColor = selected ? accent : UIColor.tertiaryLabelColor;
        [button setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
        button.backgroundColor = selected ? [accent colorWithAlphaComponent:0.10] : PPOrderDetailsSubsurfaceColor();
        button.layer.borderWidth = selected ? 1.0 : 0.75;
        PPApplyContinuousCorners(button, PPCornerMedium);
        [button pp_setBorderColor:selected ? [accent colorWithAlphaComponent:0.56] : [[UIColor labelColor] colorWithAlphaComponent:0.07]];
        button.accessibilityLabel = titleText;
        button.accessibilityTraits = selected ? (UIAccessibilityTraitButton | UIAccessibilityTraitSelected) : UIAccessibilityTraitButton;
        [button addTarget:self action:@selector(toggleItemSelection:) forControlEvents:UIControlEventTouchUpInside];
        [self pp_installPressMotionOnControl:button];
        [self.itemsStackView addArrangedSubview:button];
        [button.heightAnchor constraintGreaterThanOrEqualToConstant:52.0].active = YES;
    }
}

- (void)toggleItemSelection:(UIButton *)sender
{
    NSInteger index = sender.tag;
    if (index < 0 || index >= (NSInteger)self.composerItems.count) return;
    NSDictionary *item = self.composerItems[index];
    NSString *itemID = item[@"id"] ?: @"";
    if (itemID.length == 0) return;

    if ([self.selectedItemIDs containsObject:itemID]) {
        [self.selectedItemIDs removeObject:itemID];
    } else {
        [self.selectedItemIDs addObject:itemID];
    }

    UISelectionFeedbackGenerator *feedback = [UISelectionFeedbackGenerator new];
    [feedback prepare];
    [feedback selectionChanged];
    [UIView transitionWithView:self.itemsStackView
                      duration:UIAccessibilityIsReduceMotionEnabled() ? 0.0 : 0.18
                       options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                    animations:^{
        [self rebuildItemsSelection];
        [self.view layoutIfNeeded];
    } completion:nil];
}

- (void)addPhotosTapped
{
    if (self.selectedImages.count >= kOrderSupportComposerMaxAttachments) {
        [self showMessage:kLang(@"order_support_too_many_photos")
                    title:kLang(@"order_request_attachments_title")];
        return;
    }

    PHPickerConfiguration *config = [PHPickerConfiguration new];
    config.selectionLimit = MAX(1, kOrderSupportComposerMaxAttachments - (NSInteger)self.selectedImages.count);
    config.filter = [PHPickerFilter imagesFilter];
    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results API_AVAILABLE(ios(14.0))
{
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (results.count == 0) return;

    dispatch_group_t group = dispatch_group_create();
    NSMutableArray<UIImage *> *loadedImages = [NSMutableArray array];
    for (PHPickerResult *result in results) {
        if (![result.itemProvider canLoadObjectOfClass:UIImage.class]) continue;
        dispatch_group_enter(group);
        [result.itemProvider loadObjectOfClass:UIImage.class completionHandler:^(UIImage * _Nullable image, NSError * _Nullable __unused error) {
            if ([image isKindOfClass:UIImage.class]) {
                @synchronized (loadedImages) {
                    [loadedImages addObject:image];
                }
            }
            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        for (UIImage *image in loadedImages) {
            if (self.selectedImages.count >= kOrderSupportComposerMaxAttachments) break;
            [self.selectedImages addObject:image];
        }
        [self refreshAttachmentLabel];
    });
}

- (void)refreshAttachmentLabel
{
    NSString *attachmentText = nil;
    if (self.selectedImages.count == 0) {
        attachmentText = kLang(@"order_request_photos_optional");
    } else {
        attachmentText = [NSString stringWithFormat:kLang(@"order_request_photos_count"), (long)self.selectedImages.count];
    }
    UIImage *previewImage = self.selectedImages.firstObject;
    UIImage *fallbackImage = [UIImage systemImageNamed:@"photo.on.rectangle.angled"];
    [self.supportFormView setAttachmentForIdentifier:kPPOrderSupportAttachmentFieldID
                                               title:self.selectedImages.count > 0 ? kLang(@"order_request_attachments_title") : kLang(@"order_request_add_photos")
                                            subtitle:attachmentText
                                               image:previewImage ?: fallbackImage
                                             loading:NO
                                  removeButtonHidden:self.selectedImages.count == 0];
}

- (void)setSubmitLoading:(BOOL)loading
{
    self.submitButton.enabled = !loading;
    self.formSurfaceView.userInteractionEnabled = !loading;
    self.formSurfaceView.alpha = loading ? 0.76 : 1.0;
    [self.supportFormView setFieldEnabled:!loading identifier:kPPOrderSupportReasonFieldID];
    [self.supportFormView setFieldEnabled:!loading identifier:kPPOrderSupportNotesFieldID];
    [self.supportFormView setFieldEnabled:!loading identifier:kPPOrderSupportAttachmentFieldID];
    [self.submitButton setTitle:(loading ? kLang(@"order_request_submitting") : kLang(@"order_request_submit")) forState:UIControlStateNormal];
    if (loading) {
        [self.submitActivityIndicator startAnimating];
    } else {
        [self.submitActivityIndicator stopAnimating];
    }
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,
                                    loading ? kLang(@"order_request_submitting") : kLang(@"order_request_submit"));
}

#pragma mark - Submission

- (void)submitTapped
{
    if (![self.supportFormView validate]) {
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, kLang(@"order_request_select_reason"));
        return;
    }
    if (!self.selectedReason && self.reasonOptions.count > 0) {
        [self showMessage:kLang(@"order_request_select_reason") title:self.title];
        return;
    }
    if ([self.selectedReason[@"requiresItemSelection"] boolValue] && self.selectedItemIDs.count == 0) {
        [self showMessage:kLang(@"order_request_select_items_error") title:self.title];
        return;
    }

    [self setSubmitLoading:YES];
    NSString *draftID = NSUUID.UUID.UUIDString;
    __weak typeof(self) weakSelf = self;

    void (^submitDraft)(NSArray<PPOrderSupportAttachment *> *) = ^(NSArray<PPOrderSupportAttachment *> *attachments) {
        PPOrderSupportDraft *draft = [PPOrderSupportDraft new];
        draft.actionType = self.actionType;
        draft.reasonCode = self.selectedReason ? (self.selectedReason[@"code"] ?: @"other") : @"other";
        draft.reasonTitle = self.selectedReason ? (self.selectedReason[@"title"] ?: @"") : @"";
        draft.issueCategory = self.selectedReason ? (self.selectedReason[@"code"] ?: @"other") : @"other";
        draft.subject = [PPOrderManager displayTitleForActionType:self.actionType];
        draft.notes = [self.supportFormView valueForIdentifier:kPPOrderSupportNotesFieldID] ?: @"";
        draft.selectedItemIDs = self.selectedItemIDs.allObjects ?: @[];
        draft.attachments = attachments ?: @[];

        [self.orderManager submitSupportDraft:draft
                                     forOrder:self.order
                                   completion:^(PPOrderSupportRequest * _Nullable request, BOOL __unused deduplicated, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                [strongSelf setSubmitLoading:NO];
                if (error) {
                    [strongSelf showMessage:error.localizedDescription ?: kLang(@"SomethingWentWrong") title:strongSelf.title];
                    return;
                }
                if (strongSelf.onComplete) strongSelf.onComplete();
                if (request) {
                    UINotificationFeedbackGenerator *feedback = [UINotificationFeedbackGenerator new];
                    [feedback prepare];
                    [feedback notificationOccurred:UINotificationFeedbackTypeSuccess];
                    UIViewController *detailsVC = [PPOrderSupportRequestDetailsViewController controllerWithOrder:strongSelf.order
                                                                                                   orderManager:strongSelf.orderManager
                                                                                                        request:request];
                    if (strongSelf.navigationController) {
                        NSMutableArray *stack = strongSelf.navigationController.viewControllers.mutableCopy;
                        if (stack.count > 0) [stack removeLastObject];
                        [stack addObject:detailsVC];
                        [strongSelf.navigationController setViewControllers:stack animated:YES];
                    }
                } else {
                    [strongSelf.navigationController popViewControllerAnimated:YES];
                }
            });
        }];
    };

    if (self.selectedImages.count == 0) {
        submitDraft(@[]);
        return;
    }

    [self.orderManager uploadEvidenceImages:self.selectedImages
                                   forOrder:self.order
                            draftIdentifier:draftID
                                   progress:nil
                                 completion:^(NSArray<PPOrderSupportAttachment *> *attachments, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (error) {
                [strongSelf setSubmitLoading:NO];
                [strongSelf showMessage:error.localizedDescription ?: kLang(@"order_support_upload_failed") title:strongSelf.title];
                return;
            }
            submitDraft(attachments ?: @[]);
        });
    }];
}

#pragma mark - PPBottomSurface

- (PPBottomSurfaceKind)pp_preferredBottomSurfaceKind
{
    return PPBottomSurfaceKindNone;
}

@end
