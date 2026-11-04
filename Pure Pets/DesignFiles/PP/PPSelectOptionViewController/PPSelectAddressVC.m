#import "PPSelectAddressVC.h"

#import "AddressFormVC.h"
#import "Language.h"
#import "PPAddressModel.h"
#import "PPAddressesManager.h"
#import "PPDesignTokens.h"
#import "CitiesManager.h"
#import "CityModel.h"
#import "StateModel.h"
#import "CountryModel.h"
#import <math.h>

static const CGFloat PPAddressCellHeight = 168.0;
static const CGFloat PPAddressBottomActionsHeight = 128.0;

// This sheet owns its row surface. Shared option-cell styling must not repaint it.
@interface PPDeliveryAddressChoiceCell : UITableViewCell
@property (nonatomic, strong) UIView *addressSurface;
@property (nonatomic, strong) UIButton *chooseButton;
@property (nonatomic, strong) UIButton *editButton;
@property (nonatomic, strong) UIImageView *selectionMark;
@property (nonatomic, strong) UILabel *streetLabel;
@property (nonatomic, strong) UILabel *detailsLabel;
@property (nonatomic, strong) UILabel *recipientLabel;
@property (nonatomic, strong) UILabel *defaultLabel;
@property (nonatomic, copy) void (^onChoose)(void);
@property (nonatomic, copy) void (^onEdit)(void);
@property (nonatomic, assign) BOOL addressChosen;
- (void)configureStreet:(NSString *)street details:(NSString *)details recipient:(NSString *)recipient
             isDefault:(BOOL)isDefault chosen:(BOOL)chosen;
@end

@implementation PPDeliveryAddressChoiceCell

- (UILabel *)labelWithFont:(UIFont *)font style:(UIFontTextStyle)style
{
    UILabel *label = [UILabel new];
    label.font = [[UIFontMetrics metricsForTextStyle:style] scaledFontForFont:font];
    label.adjustsFontForContentSizeCategory = YES;
    label.numberOfLines = 0;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    return label;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.accessoryType = UITableViewCellAccessoryNone;
    self.backgroundConfiguration = UIBackgroundConfiguration.clearConfiguration;
    self.automaticallyUpdatesBackgroundConfiguration = NO;
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.isAccessibilityElement = NO;
    self.contentView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    self.addressSurface = [UIView new];
    self.addressSurface.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(self.addressSurface, PPCornerCard);
    self.addressSurface.clipsToBounds = YES;
    [self.contentView addSubview:self.addressSurface];

    self.chooseButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.chooseButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.chooseButton.isAccessibilityElement = YES;
    self.chooseButton.accessibilityHint = kLang(@"address_picker_choose_hint");
    [self.chooseButton addTarget:self action:@selector(chooseAddress) forControlEvents:UIControlEventTouchUpInside];

    self.selectionMark = [UIImageView new];
    self.selectionMark.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectionMark.contentMode = UIViewContentModeScaleAspectFit;
    self.selectionMark.isAccessibilityElement = NO;
    self.streetLabel = [self labelWithFont:[GM boldFontWithSize:PPFontHeadline] style:UIFontTextStyleHeadline];
    self.detailsLabel = [self labelWithFont:[GM MidFontWithSize:PPFontSubheadline] style:UIFontTextStyleSubheadline];
    self.recipientLabel = [self labelWithFont:[GM MidFontWithSize:PPFontFootnote] style:UIFontTextStyleFootnote];
    UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[self.streetLabel, self.detailsLabel, self.recipientLabel]];
    text.axis = UILayoutConstraintAxisVertical;
    text.spacing = PPSpaceXS;
    [text setCustomSpacing:PPSpaceSM afterView:self.detailsLabel];
    UIStackView *selection = [[UIStackView alloc] initWithArrangedSubviews:@[self.selectionMark, text]];
    selection.translatesAutoresizingMaskIntoConstraints = NO;
    selection.axis = UILayoutConstraintAxisHorizontal;
    selection.alignment = UIStackViewAlignmentTop;
    selection.spacing = PPSpaceMD;
    selection.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    selection.accessibilityElementsHidden = YES;
    selection.userInteractionEnabled = NO;
    [self.chooseButton addSubview:selection];

    self.defaultLabel = [self labelWithFont:[GM MidFontWithSize:PPFontFootnote] style:UIFontTextStyleFootnote];
    self.defaultLabel.text = kLang(@"Default");
    self.defaultLabel.isAccessibilityElement = NO; // Included in the selection button's spoken summary.
    self.editButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.editButton.titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCallout] scaledFontForFont:[GM boldFontWithSize:PPFontCallout]];
    self.editButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    self.editButton.titleLabel.numberOfLines = 0;
    self.editButton.contentEdgeInsets = UIEdgeInsetsMake(PPSpaceSM, PPSpaceMD, PPSpaceSM, PPSpaceMD);
    [self.editButton setTitle:kLang(@"Edit") forState:UIControlStateNormal];
    [self.editButton addTarget:self action:@selector(editAddress) forControlEvents:UIControlEventTouchUpInside];
    UIView *space = [UIView new];
    UIStackView *actions = [[UIStackView alloc] initWithArrangedSubviews:@[self.defaultLabel, space, self.editButton]];
    actions.axis = UILayoutConstraintAxisHorizontal;
    actions.alignment = UIStackViewAlignmentCenter;
    actions.spacing = PPSpaceSM;
    actions.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [space setContentHuggingPriority:UILayoutPriorityDefaultLow - 1 forAxis:UILayoutConstraintAxisHorizontal];
    [self.editButton setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    UIView *divider = [UIView new];
    divider.backgroundColor = UIColor.separatorColor;
    [divider.heightAnchor constraintEqualToConstant:0.5].active = YES;
    UIStackView *content = [[UIStackView alloc] initWithArrangedSubviews:@[self.chooseButton, divider, actions]];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    content.axis = UILayoutConstraintAxisVertical;
    content.spacing = PPSpaceXS;
    [self.addressSurface addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [self.addressSurface.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPScreenMargin],
        [self.addressSurface.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPScreenMargin],
        [self.addressSurface.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:PPSpaceXS],
        [self.addressSurface.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-PPSpaceSM],
        [content.leadingAnchor constraintEqualToAnchor:self.addressSurface.leadingAnchor constant:PPSpaceBase],
        [content.trailingAnchor constraintEqualToAnchor:self.addressSurface.trailingAnchor constant:-PPSpaceBase],
        [content.topAnchor constraintEqualToAnchor:self.addressSurface.topAnchor constant:PPSpaceBase],
        [content.bottomAnchor constraintEqualToAnchor:self.addressSurface.bottomAnchor constant:-PPSpaceXS],
        [selection.leadingAnchor constraintEqualToAnchor:self.chooseButton.leadingAnchor],
        [selection.trailingAnchor constraintEqualToAnchor:self.chooseButton.trailingAnchor],
        [selection.topAnchor constraintEqualToAnchor:self.chooseButton.topAnchor],
        [selection.bottomAnchor constraintEqualToAnchor:self.chooseButton.bottomAnchor constant:-PPSpaceSM],
        [self.chooseButton.heightAnchor constraintGreaterThanOrEqualToConstant:PPTouchTargetMin],
        [self.selectionMark.widthAnchor constraintEqualToConstant:PPSpaceXL],
        [self.selectionMark.heightAnchor constraintEqualToConstant:PPSpaceXL],
        [self.editButton.heightAnchor constraintGreaterThanOrEqualToConstant:PPTouchTargetMin],
        [self.editButton.widthAnchor constraintGreaterThanOrEqualToConstant:64.0]
    ]];
    self.accessibilityElements = @[self.chooseButton, self.editButton];
    return self;
}

- (void)configureStreet:(NSString *)street details:(NSString *)details recipient:(NSString *)recipient
             isDefault:(BOOL)isDefault chosen:(BOOL)chosen
{
    self.addressChosen = chosen;
    self.streetLabel.text = street;
    self.detailsLabel.text = details;
    self.detailsLabel.hidden = details.length == 0;
    self.recipientLabel.text = recipient;
    self.recipientLabel.hidden = recipient.length == 0;
    self.defaultLabel.hidden = !isDefault;
    self.selectionMark.image = [UIImage systemImageNamed:chosen ? @"checkmark.circle.fill" : @"circle"
        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium]];
    self.chooseButton.accessibilityLabel = [@[street ?: @"", details ?: @"", recipient ?: @"", isDefault ? kLang(@"Default") : @""] componentsJoinedByString:@"\n"];
    self.chooseButton.accessibilityTraits = UIAccessibilityTraitButton | (chosen ? UIAccessibilityTraitSelected : 0);
    self.chooseButton.accessibilityValue = nil; // The selected trait already announces selection.
    self.editButton.accessibilityLabel = [NSString stringWithFormat:kLang(@"address_picker_edit_format"), street];
    [self refreshAppearance];
}

- (void)refreshAppearance
{
    self.addressSurface.backgroundColor = [(AppForgroundColr ?: UIColor.secondarySystemGroupedBackgroundColor) colorWithAlphaComponent:1.0];
    self.addressSurface.layer.borderWidth = self.addressChosen ? 2.0 : (self.traitCollection.accessibilityContrast == UIAccessibilityContrastHigh ? 1.0 : 0.5);
    UIColor *border = self.addressChosen ? AppPrimaryClr : UIColor.separatorColor;
    self.addressSurface.layer.borderColor = [border resolvedColorWithTraitCollection:self.traitCollection].CGColor;
    self.selectionMark.tintColor = self.addressChosen ? AppPrimaryClr : UIColor.secondaryLabelColor;
    self.streetLabel.textColor = AppPrimaryTextClr;
    self.detailsLabel.textColor = AppSecondaryTextClr;
    self.recipientLabel.textColor = AppSecondaryTextClr;
    self.defaultLabel.textColor = AppPrimaryClr;
    [self.editButton setTitleColor:AppPrimaryClr forState:UIControlStateNormal];
}

- (void)chooseAddress { if (self.onChoose) self.onChoose(); }
- (void)editAddress { if (self.onEdit) self.onEdit(); }

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.onChoose = nil;
    self.onEdit = nil;
    self.addressChosen = NO;
    self.chooseButton.accessibilityValue = nil;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    [self refreshAppearance];
}
@end



@interface PPSelectAddressVC () <AddressFormVCDelegate>

@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIView *headerContainer;
@property (nonatomic, strong) UILabel *headerTitleLabel;
@property (nonatomic, strong) UILabel *headerSubtitleLabel;
@property (nonatomic, strong) UIView *bottomActionsContainer;
@property (nonatomic, strong) UIStackView *bottomActionsStack;
@property (nonatomic, strong) NSLayoutConstraint *bottomActionsBottomConstraint;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIStackView *headerStack;
@property (nonatomic, strong) UILabel *refreshStatusLabel;
@property (nonatomic, strong) UIButton *refreshRetryButton;
@property (nonatomic, assign) BOOL isRefreshingAddresses;
@property (nonatomic, assign) BOOL addressRefreshFailed;
@property (nonatomic, assign) CGFloat keyboardOverlap;
@property (nonatomic, assign) CGFloat sheetContentHeight;
@property (nonatomic, assign) BOOL didConfigureSheet;
@property (nonatomic, strong) UIButton *deliverAnotherLocationButton;
@property (nonatomic, strong) UIButton *deliverCurrentLocationButton;

@property (nonatomic, assign) BOOL didCompleteSelection;
@property (nonatomic, strong) PPAddressModel *pendingSavedSelection;
@property (nonatomic, assign) NSUInteger addressRefreshGeneration;
@property (nonatomic, copy) NSString *pickerUserID;

@end

@implementation PPSelectAddressVC

#pragma mark - Init

- (instancetype)init
{
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _showSearchBar = YES;
        _presentationStyle = PPSelectOptionPresentationSheet;
        _allOptions = @[];
        _filteredOptions = @[];
    }
    return self;
}

- (instancetype)initWithCompletion:(PPSelectOptionBlock)completion
{
    return [self initWithOptions:@[]
                           title:kLang(@"select_delivery_location_title")
                             row:nil
                presentationStyle:PPSelectOptionPresentationSheet
                      completion:completion];
}

- (instancetype)initWithOptions:(NSArray *)options
                          title:(NSString *)title
                            row:(XLFormRowDescriptor *)row
               presentationStyle:(PPSelectOptionPresentationStyle)style
                     completion:(PPSelectOptionBlock)completion
{
    return [self initWithOptions:options
                           title:title
                             row:row
                presentationStyle:style
                   showSearchBar:NO
                      completion:completion];
}

- (instancetype)initWithOptions:(NSArray *)options
                          title:(NSString *)title
                            row:(XLFormRowDescriptor *)row
               presentationStyle:(PPSelectOptionPresentationStyle)style
                  showSearchBar:(BOOL)showSearchBar
                     completion:(PPSelectOptionBlock)completion
{
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _allOptions = options ?: @[];
        _filteredOptions = _allOptions;
        _showSearchBar = showSearchBar;
        _presentationStyle = style;
        _onSelectOption = [completion copy];
        _rowDescriptor = row;
        self.title = title.length > 0 ? title : kLang(@"select_delivery_location_title");
    }
    return self;
}

#pragma mark - Lifecycle


- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = [self pp_sheetBackgroundColor];
    self.tableView.backgroundColor = [self pp_sheetBackgroundColor];
    self.pickerUserID = [PPADDRESS currentAuthenticatedUserID] ?: @"";
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = PPAddressCellHeight;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, PPAddressBottomActionsHeight + PPSpaceXL, 0);
    self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
    self.tableView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0.0;
    }

    [self.tableView registerClass:[PPDeliveryAddressChoiceCell class] forCellReuseIdentifier:@"PPAddressOptionCell"];

    [self pp_configureHeader];
    [self pp_configureBottomActions];
    [self pp_refreshVisibleColors];

    if (!self.filteredOptions) {
        self.filteredOptions = self.allOptions ?: @[];
    }
    [self pp_updateSheetState];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pp_keyboardChanged:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pp_keyboardChanged:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (!self.searchBar.searchTextField.isFirstResponder) self.keyboardOverlap = 0;
    // Apply after the shared presenter configures its generic sheet defaults.
    if (!self.didConfigureSheet) {
        self.didConfigureSheet = YES;
        [self pp_applySheetStyleIfNeeded];
    }
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    if (self.headerContainer) {
        CGFloat targetWidth = CGRectGetWidth(self.tableView.bounds);
        CGRect frame = self.headerContainer.frame;
        CGSize size = [self.headerContainer systemLayoutSizeFittingSize:CGSizeMake(targetWidth, UILayoutFittingCompressedSize.height)
                                        withHorizontalFittingPriority:UILayoutPriorityRequired
                                              verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
        if (fabs(frame.size.width - targetWidth) > 0.5 || fabs(frame.size.height - size.height) > 0.5) {
            frame.size.width = targetWidth;
            frame.size.height = size.height;
            self.headerContainer.frame = frame;
            self.tableView.tableHeaderView = self.headerContainer;
        }
    }
    CGFloat bottom = MAX(self.view.safeAreaInsets.bottom, self.keyboardOverlap);
    self.bottomActionsBottomConstraint.constant = -bottom;
    CGFloat bottomInset = CGRectGetHeight(self.bottomActionsContainer.bounds) + MAX(0, bottom - self.view.safeAreaInsets.bottom) + PPSpaceSM;
    if (fabs(self.tableView.contentInset.bottom - bottomInset) > 0.5) {
        self.tableView.contentInset = UIEdgeInsetsMake(0, 0, bottomInset, 0);
        self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
    }
    [self.view bringSubviewToFront:self.bottomActionsContainer];
    CGFloat desired = ceil(self.tableView.contentSize.height + CGRectGetHeight(self.bottomActionsContainer.bounds) + self.view.safeAreaInsets.bottom + PPSpaceXL);
    if (fabs(desired - self.sheetContentHeight) > 1.0) {
        self.sheetContentHeight = desired;
        if (@available(iOS 16.0, *)) [self.sheetPresentationController invalidateDetents];
    }
}

#pragma mark - Sheet presentation

- (UIColor *)pp_sheetBackgroundColor
{
    // An opaque canvas prevents checkout content showing through address text.
    return [(AppBackgroundClr ?: UIColor.systemGroupedBackgroundColor) colorWithAlphaComponent:1.0];
}

- (void)pp_refreshVisibleColors
{
    self.view.backgroundColor = [self pp_sheetBackgroundColor];
    self.tableView.backgroundColor = [self pp_sheetBackgroundColor];
    self.bottomActionsContainer.backgroundColor = [self pp_sheetBackgroundColor];
    self.headerTitleLabel.textColor = AppPrimaryTextClr;
    self.headerSubtitleLabel.textColor = AppSecondaryTextClr;
    self.refreshStatusLabel.textColor = AppSecondaryTextClr;
    self.closeButton.tintColor = AppSecondaryTextClr;
    self.closeButton.backgroundColor = [(AppForgroundColr ?: UIColor.secondarySystemGroupedBackgroundColor) colorWithAlphaComponent:1.0];
    self.searchBar.tintColor = AppPrimaryClr;
    self.searchBar.searchTextField.textColor = AppPrimaryTextClr;
    self.searchBar.searchTextField.textAlignment = Language.alignmentForCurrentLanguage;
}

- (void)pp_configureHeader
{
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.tableView.bounds), 120)];
    header.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.headerTitleLabel = [UILabel new];
    self.headerTitleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleTitle2] scaledFontForFont:[GM boldFontWithSize:PPFontTitle2]];
    self.headerTitleLabel.adjustsFontForContentSizeCategory = YES;
    self.headerTitleLabel.numberOfLines = 0;
    self.headerTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.headerTitleLabel.text = kLang(@"address_picker_title");
    self.headerTitleLabel.accessibilityTraits = UIAccessibilityTraitHeader;

    self.closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.closeButton setImage:[UIImage systemImageNamed:@"xmark" withConfiguration:
        [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightSemibold]] forState:UIControlStateNormal];
    self.closeButton.accessibilityLabel = kLang(@"Close");
    self.closeButton.accessibilityIdentifier = @"addressPicker.close";
    PPApplyContinuousCorners(self.closeButton, PPCornerCard);
    [self.closeButton.widthAnchor constraintEqualToConstant:PPTouchTargetMin].active = YES;
    [self.closeButton.heightAnchor constraintEqualToConstant:PPTouchTargetMin].active = YES;
    [self.closeButton addTarget:self action:@selector(pp_closeSheet) forControlEvents:UIControlEventTouchUpInside];
    NSArray<UIView *> *headingViews = self.presentationStyle == PPSelectOptionPresentationPush
        ? @[self.headerTitleLabel] : @[self.headerTitleLabel, self.closeButton];
    UIStackView *heading = [[UIStackView alloc] initWithArrangedSubviews:headingViews];
    heading.axis = UILayoutConstraintAxisHorizontal;
    heading.alignment = UIStackViewAlignmentCenter;
    heading.spacing = PPSpaceMD;
    heading.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    self.headerSubtitleLabel = [UILabel new];
    self.headerSubtitleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline] scaledFontForFont:[GM MidFontWithSize:PPFontSubheadline]];
    self.headerSubtitleLabel.adjustsFontForContentSizeCategory = YES;
    self.headerSubtitleLabel.numberOfLines = 0;
    self.headerSubtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.refreshStatusLabel = [UILabel new];
    self.refreshStatusLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    self.refreshStatusLabel.adjustsFontForContentSizeCategory = YES;
    self.refreshStatusLabel.numberOfLines = 0;
    self.refreshStatusLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.refreshStatusLabel.hidden = YES;
    self.refreshRetryButton = [self pp_actionButton:kLang(@"payment_review_retry") symbol:@"arrow.clockwise" primary:NO action:@selector(pp_retryAddressRefresh)];
    self.refreshRetryButton.hidden = YES;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[heading, self.headerSubtitleLabel, self.refreshStatusLabel, self.refreshRetryButton]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = PPSpaceSM;
    if (self.showSearchBar) {
        self.searchBar = [UISearchBar new];
        self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
        self.searchBar.delegate = self;
        self.searchBar.placeholder = kLang(@"address_picker_search");
        self.searchBar.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
        [stack addArrangedSubview:self.searchBar];
    }
    [header addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:header.topAnchor constant:PPSpaceLG],
        [stack.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:PPScreenMargin],
        [stack.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-PPScreenMargin],
        [stack.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-PPSpaceBase]
    ]];
    self.headerStack = stack;
    self.headerContainer = header;
    self.searchContainer = header;
    self.tableView.tableHeaderView = header;
}

- (UIButton *)pp_actionButton:(NSString *)title symbol:(NSString *)symbol primary:(BOOL)primary action:(SEL)action
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    UIButtonConfiguration *config = primary ? UIButtonConfiguration.filledButtonConfiguration : UIButtonConfiguration.plainButtonConfiguration;
    config.title = title;
    config.titleLineBreakMode = NSLineBreakByWordWrapping;
    config.titleAlignment = UIButtonConfigurationTitleAlignmentCenter;
    config.image = [UIImage systemImageNamed:symbol];
    config.imagePadding = PPSpaceSM;
    config.imagePlacement = NSDirectionalRectEdgeLeading;
    config.baseBackgroundColor = AppPrimaryClr;
    config.baseForegroundColor = primary ? UIColor.whiteColor : AppPrimaryClr;
    config.background.cornerRadius = PPCornerMedium;
    config.contentInsets = NSDirectionalEdgeInsetsMake(PPSpaceMD, PPSpaceBase, PPSpaceMD, PPSpaceBase);
    config.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey, id> *(NSDictionary<NSAttributedStringKey, id> *attributes) {
        NSMutableDictionary *result = attributes.mutableCopy;
        result[NSFontAttributeName] = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:[GM boldFontWithSize:PPFontBody]];
        return result;
    };
    button.configuration = config;
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    button.titleLabel.numberOfLines = 0;
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    button.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    NSLayoutConstraint *minimumHeight = [button.heightAnchor constraintGreaterThanOrEqualToConstant:(primary ? 54.0 : PPTouchTargetMin)];
    // The retry action is hidden in a stack until needed; allow its hidden height to be zero.
    minimumHeight.priority = UILayoutPriorityRequired - 1;
    minimumHeight.active = YES;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)pp_configureBottomActions
{
    UIView *container = [UIView new];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomActionsContainer = container;
    self.deliverAnotherLocationButton = [self pp_actionButton:kLang(@"address_picker_add") symbol:@"plus" primary:YES action:@selector(pp_handleDeliverAnotherLocationTapped:)];
    self.deliverCurrentLocationButton = [self pp_actionButton:kLang(@"ordering_address_use_location") symbol:@"location" primary:NO action:@selector(pp_handleDeliverCurrentLocationTapped:)];
    self.deliverAnotherLocationButton.accessibilityIdentifier = @"addressPicker.add";
    self.deliverCurrentLocationButton.accessibilityIdentifier = @"addressPicker.useLocation";
    self.deliverCurrentLocationButton.accessibilityHint = kLang(@"address_picker_location_hint");
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[self.deliverAnotherLocationButton, self.deliverCurrentLocationButton]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = PPSpaceXS;
    self.bottomActionsStack = stack;
    [container addSubview:stack];
    [self.view addSubview:container];
    UILayoutGuide *viewport = self.tableView.frameLayoutGuide;
    self.bottomActionsBottomConstraint = [container.bottomAnchor constraintEqualToAnchor:viewport.bottomAnchor];
    [NSLayoutConstraint activateConstraints:@[
        [container.leadingAnchor constraintEqualToAnchor:viewport.leadingAnchor],
        [container.trailingAnchor constraintEqualToAnchor:viewport.trailingAnchor],
        self.bottomActionsBottomConstraint,
        [stack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:PPScreenMargin],
        [stack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-PPScreenMargin],
        [stack.topAnchor constraintEqualToAnchor:container.topAnchor constant:PPSpaceMD],
        [stack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-PPSpaceSM]
    ]];
}

- (void)pp_applySheetStyleIfNeeded
{
    if (self.presentationStyle != PPSelectOptionPresentationSheet) return;
    if (@available(iOS 16.0, *)) {
        __weak typeof(self) weakSelf = self;
        UISheetPresentationControllerDetent *content = [UISheetPresentationControllerDetent customDetentWithIdentifier:@"pp.address.content"
            resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) {
                CGFloat desired = weakSelf.sheetContentHeight > 0 ? weakSelf.sheetContentHeight : 520.0;
                return MIN(context.maximumDetentValue * 0.82, MAX(360.0, desired));
            }];
        self.sheetPresentationController.detents = @[content, UISheetPresentationControllerDetent.largeDetent];
        self.sheetPresentationController.selectedDetentIdentifier = UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory)
            ? UISheetPresentationControllerDetentIdentifierLarge : content.identifier;
    }
    self.sheetPresentationController.preferredCornerRadius = PPCornerHero;
    self.sheetPresentationController.prefersScrollingExpandsWhenScrolledToEdge = YES;
    self.sheetPresentationController.prefersGrabberVisible = YES;
}

- (void)pp_closeSheet
{
    [self.view endEditing:YES];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)pp_keyboardChanged:(NSNotification *)notification
{
    if ([notification.name isEqualToString:UIKeyboardWillHideNotification]) {
        self.keyboardOverlap = 0;
        [self.view setNeedsLayout];
        return;
    }
    if (!self.view.window || self.presentedViewController) return;
    CGRect keyboard = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect local = [self.view convertRect:keyboard fromCoordinateSpace:self.view.window.screen.coordinateSpace];
    CGRect intersection = CGRectIntersection(self.view.bounds, local);
    BOOL docked = !CGRectIsNull(intersection) && CGRectGetWidth(intersection) >= CGRectGetWidth(self.view.bounds) * 0.7 &&
        CGRectGetMaxY(intersection) >= CGRectGetMaxY(self.view.bounds) - 1.0;
    self.keyboardOverlap = docked ? CGRectGetHeight(intersection) : 0;
    [self.view setNeedsLayout];
}

- (void)pp_updateSheetState
{
    if (!self.isViewLoaded) return;
    self.headerSubtitleLabel.text = self.allOptions.count == 0 ? kLang(@"address_picker_empty") :
        (self.filteredOptions.count == 0 ? kLang(@"address_picker_no_results") : kLang(@"address_picker_hint"));
    self.refreshStatusLabel.text = self.addressRefreshFailed ? kLang(@"checkout_address_refresh_failed") : kLang(@"checkout_loading_addresses");
    self.refreshStatusLabel.hidden = !self.isRefreshingAddresses && !self.addressRefreshFailed;
    self.refreshRetryButton.hidden = !self.addressRefreshFailed;
    [self.view setNeedsLayout];
}

- (void)pp_retryAddressRefresh { [self pp_reloadAddressesFromServerSelectingID:nil]; }

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

#pragma mark - Data

- (void)setAllOptions:(NSArray *)allOptions
{
    _allOptions = allOptions ?: @[];
    [self pp_applyFilterWithQuery:self.searchBar.text ?: @""];
}

- (void)pp_applyFilterWithQuery:(NSString *)query
{
    NSString *text = [query stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];

    if (text.length == 0) {
        self.filteredOptions = self.allOptions ?: @[];
    } else {
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
            (void)bindings;
            if (![evaluatedObject isKindOfClass:PPAddressModel.class]) {
                return NO;
            }
            PPAddressModel *address = (PPAddressModel *)evaluatedObject;
            NSString *searchable = [self pp_searchableTextForAddress:address];
            return [searchable localizedCaseInsensitiveContainsString:text];
        }];
        self.filteredOptions = [self.allOptions filteredArrayUsingPredicate:predicate] ?: @[];
    }

    if (self.isViewLoaded) {
        [self.tableView reloadData];
        [self pp_updateSheetState];
    }
}

- (NSString *)pp_effectiveAddressID:(PPAddressModel *)address
{
    if (!address) return @"";
    NSString *documentID = [address.documentID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (documentID.length > 0) return documentID;
    NSString *addressID = [address.addressID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return addressID ?: @"";
}

- (NSString *)pp_displayTextForAddress:(PPAddressModel *)address
{
    if (!address) return @"";

    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSString *value in @[address.addressLine1 ?: @"", address.addressLine2 ?: @"",
                               address.displayName ?: address.locatioName ?: @""]) {
        NSString *part = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (part.length && ![parts containsObject:part]) [parts addObject:part];
    }
    return parts.count ? [parts componentsJoinedByString:@"\n"] : (address.fullName ?: @"");
}

// Display the structured fields once. Keep pp_displayTextForAddress unchanged
// for legacy XLForm values; presentation does not redefine saved identity.
- (NSString *)pp_trimAddressPart:(NSString *)value
{
    return [value isKindOfClass:NSString.class]
        ? [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : @"";
}

- (NSString *)pp_isolatedAddressPart:(NSString *)value
{
    NSString *text = [self pp_trimAddressPart:value];
    return text.length ? [NSString stringWithFormat:@"\u2068%@\u2069", text] : @"";
}

- (NSString *)pp_localizedAddressName:(NSString *)arabic english:(NSString *)english
{
    NSString *preferred = [self pp_trimAddressPart:Language.isRTL ? arabic : english];
    return preferred.length ? preferred : [self pp_trimAddressPart:Language.isRTL ? english : arabic];
}

- (NSString *)pp_streetForAddress:(PPAddressModel *)address
{
    for (NSString *candidate in @[address.addressLine1 ?: @"", address.locatioName ?: @"", address.fullName ?: @""]) {
        NSString *value = [self pp_trimAddressPart:candidate];
        if (value.length) return value;
    }
    return kLang(@"checkout_complete_address");
}

- (NSString *)pp_detailsForAddress:(PPAddressModel *)address street:(NSString *)street
{
    CityModel *city = [CitiesManager.shared cityByID:address.cityID];
    StateModel *area = [CitiesManager.shared stateByID:address.stateID];
    CountryModel *country = city.country;
    NSMutableSet<NSString *> *seen = [NSMutableSet setWithObject:street.lowercaseString];
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    NSString *line2 = [self pp_trimAddressPart:address.addressLine2];
    if (line2.length && ![seen containsObject:line2.lowercaseString]) {
        [lines addObject:[self pp_isolatedAddressPart:line2]];
        [seen addObject:line2.lowercaseString];
    }
    NSMutableArray<NSString *> *region = [NSMutableArray array];
    for (NSString *candidate in @[
        [self pp_localizedAddressName:area.arName english:area.enName],
        [self pp_localizedAddressName:city.arName english:city.enName],
        [self pp_trimAddressPart:address.postalCode],
        [self pp_localizedAddressName:country.arName english:country.enName]
    ]) {
        if (candidate.length == 0 || [seen containsObject:candidate.lowercaseString]) continue;
        [seen addObject:candidate.lowercaseString];
        [region addObject:[self pp_isolatedAddressPart:candidate]];
    }
    if (region.count) [lines addObject:[region componentsJoinedByString:Language.isRTL ? @"، " : @", "]];
    return [lines componentsJoinedByString:@"\n"];
}

- (NSString *)pp_searchableTextForAddress:(PPAddressModel *)address
{
    NSMutableArray<NSString *> *parts = [NSMutableArray array];

    NSString *display = [self pp_displayTextForAddress:address];
    if (display.length > 0) [parts addObject:display];

    if (address.fullName.length > 0) [parts addObject:address.fullName];
    if (address.phoneNumber.length > 0) [parts addObject:address.phoneNumber];
    if (address.addressLine1.length > 0) [parts addObject:address.addressLine1];
    if (address.addressLine2.length > 0) [parts addObject:address.addressLine2];
    if (address.locatioName.length > 0) [parts addObject:address.locatioName];

    return [parts componentsJoinedByString:@" "];
}

- (PPAddressModel *)pp_addressForID:(NSString *)addressID
{
    if (addressID.length == 0) return nil;

    for (id obj in self.allOptions ?: @[]) {
        if (![obj isKindOfClass:PPAddressModel.class]) continue;
        PPAddressModel *address = (PPAddressModel *)obj;
        if ([[self pp_effectiveAddressID:address] isEqualToString:addressID]) {
            return address;
        }
    }
    return nil;
}

- (void)pp_reloadAddressesFromServerSelectingID:(NSString *)selectedAddressID
{
    NSString *uid = self.pickerUserID.copy;
    if (!uid.length || ![[PPADDRESS currentAuthenticatedUserID] isEqualToString:uid]) return;
    NSUInteger generation = ++self.addressRefreshGeneration;
    self.isRefreshingAddresses = YES;
    self.addressRefreshFailed = NO;
    [self pp_updateSheetState];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.addressRefreshGeneration != generation || !self.isRefreshingAddresses ||
            ![[PPADDRESS currentAuthenticatedUserID] isEqualToString:uid]) return;
        self.addressRefreshGeneration += 1;
        self.isRefreshingAddresses = NO;
        self.addressRefreshFailed = YES;
        [self pp_updateSheetState];
    });
    [PPADDRESS getAllAddressesWithCompletion:^(NSArray<PPAddressModel *> * _Nullable addresses, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.addressRefreshGeneration != generation ||
                ![[PPADDRESS currentAuthenticatedUserID] isEqualToString:uid]) return;
            self.isRefreshingAddresses = NO;
            self.addressRefreshFailed = error != nil;
            if (error) {
                [self pp_updateSheetState];
                if (self.view.window && !self.presentedViewController) {
                    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, kLang(@"checkout_address_refresh_failed"));
                }
                return;
            }
            NSString *currentID = selectedAddressID ?: ([self.selectedOption isKindOfClass:PPAddressModel.class]
                ? [self pp_effectiveAddressID:self.selectedOption] : @"");
            self.allOptions = addresses ?: @[];
            self.selectedOption = [self pp_addressForID:currentID];
            [self pp_applyFilterWithQuery:self.searchBar.text ?: @""];
        });
    }];
}

#pragma mark - Selection

- (BOOL)pp_isAddressSelected:(PPAddressModel *)address
{
    if (!address) return NO;

    if ([self.selectedOption isKindOfClass:PPAddressModel.class]) {
        PPAddressModel *selected = (PPAddressModel *)self.selectedOption;
        NSString *selectedID = [self pp_effectiveAddressID:selected];
        NSString *candidateID = [self pp_effectiveAddressID:address];
        if (selectedID.length > 0) return [selectedID isEqualToString:candidateID];
    }

    if ([self.rowDescriptor.value isKindOfClass:NSString.class]) {
        NSString *current = [(NSString *)self.rowDescriptor.value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (current.length > 0) {
            return [[self pp_displayTextForAddress:address] isEqualToString:current] ||
                [address.displayName isEqualToString:current];
        }
    }

    return NO;
}

- (void)pp_completeWithAddress:(PPAddressModel *)address
{
    NSString *uid = [PPADDRESS currentAuthenticatedUserID] ?: @"";
    if (!address || self.didCompleteSelection || uid.length == 0 ||
        ![uid isEqualToString:self.pickerUserID] || [self pp_effectiveAddressID:address].length == 0 ||
        (address.userID.length > 0 && ![address.userID isEqualToString:uid])) {
        return;
    }
    self.didCompleteSelection = YES;

    self.selectedOption = address;
    NSString *display = [self pp_displayTextForAddress:address];
    if (self.rowDescriptor) {
        self.rowDescriptor.value = display;
    }

    if (self.parentForm && [self.parentForm respondsToSelector:@selector(updateFormRow:)]) {
        ((void (*)(id, SEL, id))[self.parentForm methodForSelector:@selector(updateFormRow:)])(
            self.parentForm,
            @selector(updateFormRow:),
            self.rowDescriptor
        );
    }

    if (self.onSelectOption) {
        self.onSelectOption(address);
    }

    if (self.presentationStyle == PPSelectOptionPresentationPush) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    (void)tableView;
    (void)section;
    return self.filteredOptions.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    PPDeliveryAddressChoiceCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPAddressOptionCell" forIndexPath:indexPath];
    PPAddressModel *address = indexPath.row < self.filteredOptions.count ? self.filteredOptions[indexPath.row] : nil;
    if (![address isKindOfClass:PPAddressModel.class]) {
        [cell configureStreet:@"" details:@"" recipient:@"" isDefault:NO chosen:NO];
        cell.onChoose = nil;
        cell.onEdit = nil;
        return cell;
    }
    NSString *street = [self pp_streetForAddress:address];
    NSString *recipient = [self pp_trimAddressPart:address.fullName];
    if ([recipient caseInsensitiveCompare:street] == NSOrderedSame) recipient = @"";
    [cell configureStreet:[self pp_isolatedAddressPart:street]
                  details:[self pp_detailsForAddress:address street:street]
                recipient:[self pp_isolatedAddressPart:recipient]
                isDefault:address.isDefault chosen:[self pp_isAddressSelected:address]];
    cell.chooseButton.accessibilityIdentifier = @"addressPicker.chooseSavedAddress";
    cell.editButton.accessibilityIdentifier = @"addressPicker.editSavedAddress";
    __weak typeof(self) weakSelf = self;
    cell.onChoose = ^{ [weakSelf pp_completeWithAddress:address]; };
    cell.onEdit = ^{ [weakSelf pp_presentAddressForm:address useLocation:NO]; };
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    (void)tableView;
    id item = (indexPath.row < self.filteredOptions.count) ? self.filteredOptions[indexPath.row] : nil;
    if (![item isKindOfClass:PPAddressModel.class]) {
        return;
    }

    [self pp_completeWithAddress:(PPAddressModel *)item];
}

#pragma mark - Search

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [self pp_applyFilterWithQuery:searchText ?: @""];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
}

#pragma mark - Actions

- (void)pp_presentAddressForm:(PPAddressModel *)address useLocation:(BOOL)useLocation
{
    if (self.presentedViewController || ![[PPADDRESS currentAuthenticatedUserID] isEqualToString:self.pickerUserID]) return;
    [self.view endEditing:YES];
    self.keyboardOverlap = 0;
    [self.view setNeedsLayout];
    AddressFormVC *formVC = [[AddressFormVC alloc] initWithAddress:address];
    formVC.addressFormPresent = AddressFormPresentSheet;
    formVC.prefillFromCurrentLocation = useLocation;
    formVC.delegate = self;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:formVC];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 15.0, *)) {
        nav.sheetPresentationController.detents = @[[UISheetPresentationControllerDetent largeDetent]];
        nav.sheetPresentationController.prefersGrabberVisible = YES;
    }
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)pp_handleDeliverAnotherLocationTapped:(id)sender
{
    [self pp_presentAddressForm:nil useLocation:NO];
}

- (void)pp_handleDeliverCurrentLocationTapped:(id)sender
{
    [self pp_presentAddressForm:nil useLocation:YES];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row >= self.filteredOptions.count) return;
    PPAddressModel *address = self.filteredOptions[indexPath.row];
    if ([address isKindOfClass:PPAddressModel.class]) [self pp_presentAddressForm:address useLocation:NO];
}

#pragma mark - AddressFormVCDelegate

- (void)addressFormVC:(AddressFormVC *)controller didSaveAddress:(PPAddressModel *)address
{
    if (![address isKindOfClass:PPAddressModel.class]) return;
    self.pendingSavedSelection = address;
    [self pp_reloadAddressesFromServerSelectingID:[self pp_effectiveAddressID:address]];
}

- (void)addressFormVCDidFinishClosing:(AddressFormVC *)controller
{
    PPAddressModel *saved = self.pendingSavedSelection;
    self.pendingSavedSelection = nil;
    if (saved) [self pp_completeWithAddress:saved];
}

- (void)addressFormVC:(AddressFormVC *)controller didDeleteAddress:(PPAddressModel *)address
{
    (void)controller;
    if (![[PPADDRESS currentAuthenticatedUserID] isEqualToString:self.pickerUserID]) return;
    NSString *deletedID = [self pp_effectiveAddressID:address];

    if (deletedID.length > 0 && [self.selectedOption isKindOfClass:PPAddressModel.class]) {
        PPAddressModel *selected = (PPAddressModel *)self.selectedOption;
        if ([[self pp_effectiveAddressID:selected] isEqualToString:deletedID]) {
            self.selectedOption = nil;
        }
    }

    // The editor only reports deletion after persistence succeeds. Keep the
    // acknowledged deletion visible even if the subsequent read is offline.
    if (deletedID.length > 0) {
        NSMutableArray *remaining = [NSMutableArray arrayWithCapacity:self.allOptions.count];
        for (id option in self.allOptions) {
            if ([option isKindOfClass:PPAddressModel.class] &&
                [[self pp_effectiveAddressID:option] isEqualToString:deletedID]) continue;
            [remaining addObject:option];
        }
        self.allOptions = remaining;
    }

    [self pp_reloadAddressesFromServerSelectingID:nil];
}

#pragma mark - Appearance

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (![self.traitCollection.preferredContentSizeCategory isEqualToString:previousTraitCollection.preferredContentSizeCategory]) {
        [self.deliverAnotherLocationButton setNeedsUpdateConfiguration];
        [self.deliverCurrentLocationButton setNeedsUpdateConfiguration];
        [self.refreshRetryButton setNeedsUpdateConfiguration];
        if (UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory)) {
            self.sheetPresentationController.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierLarge;
        }
        [self.tableView reloadData];
        [self.view setNeedsLayout];
    }
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_refreshVisibleColors];
            [self.tableView reloadData];
        }
    }
}

@end
