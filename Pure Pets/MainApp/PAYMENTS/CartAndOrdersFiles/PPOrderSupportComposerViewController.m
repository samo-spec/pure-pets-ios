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

@import PhotosUI;

@interface PPOrderSupportComposerViewController () <PHPickerViewControllerDelegate, UITextViewDelegate>
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
@property (nonatomic, strong) UILabel *heroKickerLabel;
@property (nonatomic, strong) UILabel *heroTitleLabel;
@property (nonatomic, strong) UILabel *heroSubtitleLabel;
@property (nonatomic, strong) UILabel *orderReferenceLabel;

@property (nonatomic, strong) UIView *formSurfaceView;
@property (nonatomic, strong) UIStackView *formStackView;
@property (nonatomic, strong) UIButton *reasonButton;
@property (nonatomic, strong) UILabel *reasonValueLabel;
@property (nonatomic, strong) UIImageView *reasonSymbolImageView;
@property (nonatomic, strong) UIStackView *itemsStackView;
@property (nonatomic, strong) UIView *notesSurfaceView;
@property (nonatomic, strong) UITextView *notesTextView;
@property (nonatomic, strong) UIButton *addPhotoButton;
@property (nonatomic, strong) UILabel *attachmentsLabel;
@property (nonatomic, strong) UIStackView *attachmentPreviewStackView;

@property (nonatomic, strong) UIView *actionBar;
@property (nonatomic, strong) UIButton *submitButton;
@property (nonatomic, strong) UIActivityIndicatorView *submitActivityIndicator;
@property (nonatomic, strong) NSArray<UIView *> *entranceViews;
@property (nonatomic, assign) BOOL didPrepareEntrance;
@property (nonatomic, assign) BOOL didRunEntrance;
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
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self pp_prepareEntranceState];
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

    [NSLayoutConstraint activateConstraints:@[
        [ambientWash.widthAnchor constraintEqualToAnchor:self.view.widthAnchor multiplier:0.78],
        [ambientWash.heightAnchor constraintEqualToAnchor:ambientWash.widthAnchor],
        [ambientWash.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:96.0],
        [ambientWash.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:22.0],

        [self.actionBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.actionBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.actionBar.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor],

        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.actionBar.topAnchor],

        [self.contentStackView.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor constant:20.0],
        [self.contentStackView.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor constant:-20.0],
        [self.contentStackView.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:16.0],
        [self.contentStackView.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-28.0],
        [self.contentStackView.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor constant:-40.0]
    ]];

    [self pp_buildHero];
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
    [self.contentStackView addArrangedSubview:self.heroSurfaceView];
    [self.heroSurfaceView.heightAnchor constraintGreaterThanOrEqualToConstant:178.0].active = YES;

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

    UIView *iconBadge = [[UIView alloc] initWithFrame:CGRectZero];
    iconBadge.translatesAutoresizingMaskIntoConstraints = NO;
    iconBadge.backgroundColor = [accent colorWithAlphaComponent:0.16];
    PPApplyContinuousCorners(iconBadge, 24.0);
    [self.heroContentView addSubview:iconBadge];

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:[self pp_heroSymbolName]
                                                                   withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:22.0
                                                                                                                             weight:UIImageSymbolWeightSemibold]]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.tintColor = accent;
    iconView.isAccessibilityElement = NO;
    [iconBadge addSubview:iconView];

    self.orderReferenceLabel = [self pp_makeLabelWithFont:[GM boldFontWithSize:12]
                                                 textStyle:UIFontTextStyleCaption1
                                                     color:UIColor.labelColor];
    self.orderReferenceLabel.numberOfLines = 1;
    self.orderReferenceLabel.textAlignment = NSTextAlignmentCenter;
    self.orderReferenceLabel.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    self.orderReferenceLabel.backgroundColor = [UIColor.systemBackgroundColor colorWithAlphaComponent:0.64];
    PPApplyContinuousCorners(self.orderReferenceLabel, 14.0);
    self.orderReferenceLabel.text = [self pp_orderReferenceText];
    [self.heroContentView addSubview:self.orderReferenceLabel];

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
    self.heroKickerLabel.text = kLang(@"OrderID");
    self.heroKickerLabel.textAlignment = alignment;

    self.heroTitleLabel = [self pp_makeLabelWithFont:[GM boldFontWithSize:25]
                                            textStyle:UIFontTextStyleTitle2
                                                color:UIColor.labelColor];
    self.heroTitleLabel.numberOfLines = 2;
    self.heroTitleLabel.text = self.title;
    self.heroTitleLabel.textAlignment = alignment;

    self.heroSubtitleLabel = [self pp_makeLabelWithFont:[GM MidFontWithSize:15]
                                               textStyle:UIFontTextStyleSubheadline
                                                   color:UIColor.secondaryLabelColor];
    self.heroSubtitleLabel.numberOfLines = 3;
    self.heroSubtitleLabel.text = [self.orderManager eligibilityForAction:self.actionType
                                                                      order:self.order
                                                                   requests:@[]
                                                              referenceDate:[NSDate date]].message;
    self.heroSubtitleLabel.textAlignment = alignment;

    [textStack addArrangedSubview:self.heroKickerLabel];
    [textStack addArrangedSubview:self.heroTitleLabel];
    [textStack addArrangedSubview:self.heroSubtitleLabel];
    [textStack setCustomSpacing:8.0 afterView:self.heroKickerLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.heroBackgroundView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor],
        [self.heroBackgroundView.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor],
        [self.heroBackgroundView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor],
        [self.heroBackgroundView.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor],

        [self.heroContentView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor],
        [self.heroContentView.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor],
        [self.heroContentView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor],
        [self.heroContentView.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor],

        [iconBadge.leadingAnchor constraintEqualToAnchor:self.heroContentView.leadingAnchor constant:20.0],
        [iconBadge.topAnchor constraintEqualToAnchor:self.heroContentView.topAnchor constant:20.0],
        [iconBadge.widthAnchor constraintEqualToConstant:48.0],
        [iconBadge.heightAnchor constraintEqualToConstant:48.0],
        [iconView.centerXAnchor constraintEqualToAnchor:iconBadge.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconBadge.centerYAnchor],

        [self.orderReferenceLabel.trailingAnchor constraintEqualToAnchor:self.heroContentView.trailingAnchor constant:-20.0],
        [self.orderReferenceLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:iconBadge.trailingAnchor constant:16.0],
        [self.orderReferenceLabel.centerYAnchor constraintEqualToAnchor:iconBadge.centerYAnchor],
        [self.orderReferenceLabel.heightAnchor constraintGreaterThanOrEqualToConstant:28.0],
        [self.orderReferenceLabel.widthAnchor constraintGreaterThanOrEqualToConstant:74.0],

        [textStack.leadingAnchor constraintEqualToAnchor:self.heroContentView.leadingAnchor constant:20.0],
        [textStack.trailingAnchor constraintEqualToAnchor:self.heroContentView.trailingAnchor constant:-20.0],
        [textStack.topAnchor constraintGreaterThanOrEqualToAnchor:iconBadge.bottomAnchor constant:18.0],
        [textStack.bottomAnchor constraintEqualToAnchor:self.heroContentView.bottomAnchor constant:-20.0]
    ]];

    self.heroSurfaceView.isAccessibilityElement = YES;
    self.heroSurfaceView.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", self.title ?: @"", self.orderReferenceLabel.text ?: @""];
    self.heroSurfaceView.accessibilityTraits = UIAccessibilityTraitStaticText;
}

- (void)pp_buildForm
{
    UISemanticContentAttribute semantic = Language.semanticAttributeForCurrentLanguage;
    NSTextAlignment alignment = Language.alignmentForCurrentLanguage;

    self.formSurfaceView = [[UIView alloc] initWithFrame:CGRectZero];
    self.formSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.formSurfaceView.semanticContentAttribute = semantic;
    PPOrderDetailsApplySurface(self.formSurfaceView, PPCornerCard, NO);
    [self.contentStackView addArrangedSubview:self.formSurfaceView];

    self.formStackView = [[UIStackView alloc] initWithFrame:CGRectZero];
    self.formStackView.axis = UILayoutConstraintAxisVertical;
    self.formStackView.spacing = 16.0;
    self.formStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.formStackView.semanticContentAttribute = semantic;
    [self.formSurfaceView addSubview:self.formStackView];
    [NSLayoutConstraint activateConstraints:@[
        [self.formStackView.leadingAnchor constraintEqualToAnchor:self.formSurfaceView.leadingAnchor constant:16.0],
        [self.formStackView.trailingAnchor constraintEqualToAnchor:self.formSurfaceView.trailingAnchor constant:-16.0],
        [self.formStackView.topAnchor constraintEqualToAnchor:self.formSurfaceView.topAnchor constant:18.0],
        [self.formStackView.bottomAnchor constraintEqualToAnchor:self.formSurfaceView.bottomAnchor constant:-18.0]
    ]];

    [self.formStackView addArrangedSubview:[self pp_makeSectionTitle:kLang(@"order_request_reason_title")]];
    [self pp_buildReasonControl];
    [self.formStackView addArrangedSubview:self.reasonButton];

    self.itemsStackView = [[UIStackView alloc] initWithFrame:CGRectZero];
    self.itemsStackView.axis = UILayoutConstraintAxisVertical;
    self.itemsStackView.spacing = 8.0;
    self.itemsStackView.semanticContentAttribute = semantic;
    [self.formStackView addArrangedSubview:self.itemsStackView];

    self.notesSurfaceView = [[UIView alloc] initWithFrame:CGRectZero];
    self.notesSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.notesSurfaceView.semanticContentAttribute = semantic;
    self.notesSurfaceView.backgroundColor = PPOrderDetailsSubsurfaceColor();
    PPApplyContinuousCorners(self.notesSurfaceView, PPCornerMedium);
    self.notesSurfaceView.layer.borderWidth = 0.75;
    [self.notesSurfaceView pp_setBorderColor:[[UIColor labelColor] colorWithAlphaComponent:0.06]];
    [self.formStackView addArrangedSubview:self.notesSurfaceView];

    UILabel *notesTitle = [self pp_makeSectionTitle:kLang(@"order_request_notes_title")];
    notesTitle.translatesAutoresizingMaskIntoConstraints = NO;
    notesTitle.textColor = UIColor.secondaryLabelColor;
    [self.notesSurfaceView addSubview:notesTitle];

    self.notesTextView = [[UITextView alloc] initWithFrame:CGRectZero];
    self.notesTextView.translatesAutoresizingMaskIntoConstraints = NO;
    self.notesTextView.delegate = self;
    self.notesTextView.font = [self pp_composerFont:[GM MidFontWithSize:16] textStyle:UIFontTextStyleBody];
    self.notesTextView.adjustsFontForContentSizeCategory = YES;
    self.notesTextView.backgroundColor = UIColor.clearColor;
    self.notesTextView.textColor = UIColor.labelColor;
    self.notesTextView.textContainerInset = UIEdgeInsetsMake(6.0, 0.0, 4.0, 0.0);
    self.notesTextView.textAlignment = alignment;
    self.notesTextView.semanticContentAttribute = semantic;
    self.notesTextView.accessibilityLabel = kLang(@"order_request_notes_title");
    [self.notesSurfaceView addSubview:self.notesTextView];

    [NSLayoutConstraint activateConstraints:@[
        [notesTitle.leadingAnchor constraintEqualToAnchor:self.notesSurfaceView.leadingAnchor constant:16.0],
        [notesTitle.trailingAnchor constraintEqualToAnchor:self.notesSurfaceView.trailingAnchor constant:-16.0],
        [notesTitle.topAnchor constraintEqualToAnchor:self.notesSurfaceView.topAnchor constant:14.0],
        [self.notesTextView.leadingAnchor constraintEqualToAnchor:self.notesSurfaceView.leadingAnchor constant:12.0],
        [self.notesTextView.trailingAnchor constraintEqualToAnchor:self.notesSurfaceView.trailingAnchor constant:-12.0],
        [self.notesTextView.topAnchor constraintEqualToAnchor:notesTitle.bottomAnchor constant:2.0],
        [self.notesTextView.bottomAnchor constraintEqualToAnchor:self.notesSurfaceView.bottomAnchor constant:-10.0],
        [self.notesTextView.heightAnchor constraintGreaterThanOrEqualToConstant:128.0]
    ]];

    [self.formStackView addArrangedSubview:[self pp_makeSectionTitle:kLang(@"order_request_attachments_title")]];
    [self pp_buildAttachmentControl];
    [self.formStackView addArrangedSubview:self.addPhotoButton];
    [self.formStackView addArrangedSubview:self.attachmentsLabel];
    [self.formStackView addArrangedSubview:self.attachmentPreviewStackView];

    [self pp_updateReasonSelectionUI];
    [self rebuildItemsSelection];
    [self refreshAttachmentLabel];
}

- (void)pp_buildReasonControl
{
    UISemanticContentAttribute semantic = Language.semanticAttributeForCurrentLanguage;
    NSTextAlignment alignment = Language.alignmentForCurrentLanguage;

    self.reasonButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.reasonButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.reasonButton.semanticContentAttribute = semantic;
    self.reasonButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
    self.reasonButton.accessibilityLabel = kLang(@"order_request_reason_title");
    [self pp_applyQuietControlStyleToButton:self.reasonButton];
    [self.reasonButton addTarget:self action:@selector(selectReasonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self pp_installPressMotionOnControl:self.reasonButton];
    [self.reasonButton.heightAnchor constraintGreaterThanOrEqualToConstant:64.0].active = YES;

    UILabel *caption = [self pp_makeLabelWithFont:[GM MidFontWithSize:12]
                                         textStyle:UIFontTextStyleCaption1
                                             color:UIColor.secondaryLabelColor];
    caption.translatesAutoresizingMaskIntoConstraints = NO;
    caption.text = kLang(@"order_request_reason_title");
    caption.textAlignment = alignment;
    [self.reasonButton addSubview:caption];

    self.reasonValueLabel = [self pp_makeLabelWithFont:[GM boldFontWithSize:16]
                                              textStyle:UIFontTextStyleBody
                                                  color:UIColor.labelColor];
    self.reasonValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.reasonValueLabel.numberOfLines = 2;
    self.reasonValueLabel.textAlignment = alignment;
    [self.reasonButton addSubview:self.reasonValueLabel];

    self.reasonSymbolImageView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.down"
                                                                     withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14.0
                                                                                                                               weight:UIImageSymbolWeightSemibold]]];
    self.reasonSymbolImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.reasonSymbolImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.reasonSymbolImageView.isAccessibilityElement = NO;
    [self.reasonButton addSubview:self.reasonSymbolImageView];

    [NSLayoutConstraint activateConstraints:@[
        [caption.leadingAnchor constraintEqualToAnchor:self.reasonButton.leadingAnchor constant:16.0],
        [caption.trailingAnchor constraintLessThanOrEqualToAnchor:self.reasonSymbolImageView.leadingAnchor constant:-12.0],
        [caption.topAnchor constraintEqualToAnchor:self.reasonButton.topAnchor constant:11.0],
        [self.reasonValueLabel.leadingAnchor constraintEqualToAnchor:self.reasonButton.leadingAnchor constant:16.0],
        [self.reasonValueLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.reasonSymbolImageView.leadingAnchor constant:-12.0],
        [self.reasonValueLabel.topAnchor constraintEqualToAnchor:caption.bottomAnchor constant:2.0],
        [self.reasonValueLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.reasonButton.bottomAnchor constant:-10.0],
        [self.reasonSymbolImageView.trailingAnchor constraintEqualToAnchor:self.reasonButton.trailingAnchor constant:-16.0],
        [self.reasonSymbolImageView.centerYAnchor constraintEqualToAnchor:self.reasonButton.centerYAnchor],
        [self.reasonSymbolImageView.widthAnchor constraintEqualToConstant:20.0],
        [self.reasonSymbolImageView.heightAnchor constraintEqualToConstant:20.0]
    ]];
}

- (void)pp_buildAttachmentControl
{
    UISemanticContentAttribute semantic = Language.semanticAttributeForCurrentLanguage;
    NSTextAlignment alignment = Language.alignmentForCurrentLanguage;

    self.addPhotoButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.addPhotoButton.semanticContentAttribute = semantic;
    self.addPhotoButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    self.addPhotoButton.contentEdgeInsets = UIEdgeInsetsMake(14.0, 16.0, 14.0, 16.0);
    self.addPhotoButton.titleLabel.font = [self pp_composerFont:[GM boldFontWithSize:16] textStyle:UIFontTextStyleBody];
    self.addPhotoButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    self.addPhotoButton.titleLabel.numberOfLines = 0;
    self.addPhotoButton.titleLabel.textAlignment = alignment;
    [self.addPhotoButton setTitle:kLang(@"order_request_add_photos") forState:UIControlStateNormal];
    [self.addPhotoButton setImage:[UIImage systemImageNamed:@"photo.on.rectangle.angled"
                                          withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:18.0
                                                                                                    weight:UIImageSymbolWeightSemibold]]
                           forState:UIControlStateNormal];
    self.addPhotoButton.accessibilityLabel = kLang(@"order_request_add_photos");
    [self pp_applyQuietControlStyleToButton:self.addPhotoButton];
    [self.addPhotoButton addTarget:self action:@selector(addPhotosTapped) forControlEvents:UIControlEventTouchUpInside];
    [self pp_installPressMotionOnControl:self.addPhotoButton];
    [self.addPhotoButton.heightAnchor constraintGreaterThanOrEqualToConstant:54.0].active = YES;

    self.attachmentsLabel = [self pp_makeLabelWithFont:[GM MidFontWithSize:13]
                                               textStyle:UIFontTextStyleFootnote
                                                   color:UIColor.secondaryLabelColor];
    self.attachmentsLabel.numberOfLines = 0;
    self.attachmentsLabel.textAlignment = alignment;
    self.attachmentsLabel.semanticContentAttribute = semantic;

    self.attachmentPreviewStackView = [[UIStackView alloc] initWithFrame:CGRectZero];
    self.attachmentPreviewStackView.axis = UILayoutConstraintAxisHorizontal;
    self.attachmentPreviewStackView.alignment = UIStackViewAlignmentCenter;
    self.attachmentPreviewStackView.spacing = 8.0;
    self.attachmentPreviewStackView.semanticContentAttribute = semantic;
    self.attachmentPreviewStackView.hidden = YES;
    self.attachmentPreviewStackView.isAccessibilityElement = NO;
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
        [self.submitButton.bottomAnchor constraintEqualToAnchor:materialView.contentView.safeAreaLayoutGuide.bottomAnchor constant:-10.0],
        [self.submitButton.heightAnchor constraintGreaterThanOrEqualToConstant:56.0],
        [self.submitActivityIndicator.centerYAnchor constraintEqualToAnchor:self.submitButton.centerYAnchor],
        [self.submitActivityIndicator.trailingAnchor constraintEqualToAnchor:self.submitButton.trailingAnchor constant:-18.0]
    ]];
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

- (void)pp_refreshVisualStyle
{
    UIColor *accent = [self pp_primaryColor];
    self.heroBackgroundView.accentColorOverride = accent;
    self.heroSurfaceView.layer.borderWidth = 0.75;
    [self.heroSurfaceView pp_setBorderColor:[accent colorWithAlphaComponent:0.18]];
    self.orderReferenceLabel.backgroundColor = [UIColor.systemBackgroundColor colorWithAlphaComponent:0.64];
    self.formSurfaceView.backgroundColor = PPOrderDetailsSurfaceColor();
    self.notesSurfaceView.backgroundColor = PPOrderDetailsSubsurfaceColor();
    [self.notesSurfaceView pp_setBorderColor:[[UIColor labelColor] colorWithAlphaComponent:0.06]];
    [self pp_updateReasonSelectionUI];
    [self pp_applyQuietControlStyleToButton:self.addPhotoButton];
    [self pp_applyPrimaryActionStyleToButton:self.submitButton];
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

- (void)pp_updateReasonSelectionUI
{
    if (!self.reasonButton) return;
    BOOL selected = self.selectedReason != nil;
    UIColor *accent = [self pp_primaryColor];
    self.reasonValueLabel.text = selected ? (self.selectedReason[@"title"] ?: @"") : kLang(@"order_request_select_reason");
    self.reasonValueLabel.textColor = selected ? UIColor.labelColor : UIColor.secondaryLabelColor;
    self.reasonSymbolImageView.tintColor = selected ? accent : UIColor.tertiaryLabelColor;
    self.reasonButton.backgroundColor = selected ? [accent colorWithAlphaComponent:0.10] : PPOrderDetailsSubsurfaceColor();
    self.reasonButton.layer.borderWidth = selected ? 1.0 : 0.75;
    [self.reasonButton pp_setBorderColor:selected ? [accent colorWithAlphaComponent:0.55] : [[UIColor labelColor] colorWithAlphaComponent:0.075]];
    self.reasonButton.accessibilityValue = self.reasonValueLabel.text;
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

- (void)pp_dismissKeyboard
{
    [self.view endEditing:YES];
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    if (textView != self.notesTextView) return;
    CGRect rect = [self.notesSurfaceView convertRect:self.notesSurfaceView.bounds toView:self.scrollView];
    [self.scrollView scrollRectToVisible:CGRectInset(rect, 0.0, -16.0) animated:YES];
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
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:kLang(@"order_request_select_reason")
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    sheet.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    for (NSDictionary *reason in self.reasonOptions) {
        [sheet addAction:[UIAlertAction actionWithTitle:reason[@"title"]
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction * _Nonnull action) {
            self.selectedReason = reason;
            [self pp_updateReasonSelectionUI];
            UISelectionFeedbackGenerator *feedback = [UISelectionFeedbackGenerator new];
            [feedback prepare];
            [feedback selectionChanged];
            [self rebuildItemsSelection];
            if (!UIAccessibilityIsReduceMotionEnabled()) {
                self.reasonButton.transform = CGAffineTransformMakeScale(0.985, 0.985);
                [UIView animateWithDuration:0.22
                                      delay:0.0
                     usingSpringWithDamping:0.78
                      initialSpringVelocity:0.45
                                    options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                                 animations:^{
                    self.reasonButton.transform = CGAffineTransformIdentity;
                } completion:nil];
            }
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"cancel") style:UIAlertActionStyleCancel handler:nil]];
    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = self.reasonButton;
        sheet.popoverPresentationController.sourceRect = self.reasonButton.bounds;
    }
    [self presentViewController:sheet animated:YES completion:nil];
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
    if (self.selectedImages.count == 0) {
        self.attachmentsLabel.text = kLang(@"order_request_photos_optional");
    } else {
        self.attachmentsLabel.text = [NSString stringWithFormat:kLang(@"order_request_photos_count"), (long)self.selectedImages.count];
    }
    self.attachmentsLabel.accessibilityLabel = self.attachmentsLabel.text;

    for (UIView *view in self.attachmentPreviewStackView.arrangedSubviews) {
        [self.attachmentPreviewStackView removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    self.attachmentPreviewStackView.hidden = self.selectedImages.count == 0;
    for (UIImage *image in self.selectedImages) {
        UIImageView *preview = [[UIImageView alloc] initWithImage:image];
        preview.translatesAutoresizingMaskIntoConstraints = NO;
        preview.contentMode = UIViewContentModeScaleAspectFill;
        preview.clipsToBounds = YES;
        preview.isAccessibilityElement = NO;
        PPApplyContinuousCorners(preview, 12.0);
        [self.attachmentPreviewStackView addArrangedSubview:preview];
        [preview.widthAnchor constraintEqualToConstant:48.0].active = YES;
        [preview.heightAnchor constraintEqualToConstant:48.0].active = YES;
    }
}

- (void)setSubmitLoading:(BOOL)loading
{
    self.submitButton.enabled = !loading;
    self.formSurfaceView.userInteractionEnabled = !loading;
    self.formSurfaceView.alpha = loading ? 0.76 : 1.0;
    self.notesTextView.editable = !loading;
    self.addPhotoButton.enabled = !loading;
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
        draft.notes = self.notesTextView.text ?: @"";
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

@end
