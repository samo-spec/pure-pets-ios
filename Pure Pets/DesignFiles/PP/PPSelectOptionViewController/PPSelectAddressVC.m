#import "PPSelectAddressVC.h"

#import "AddressFormVC.h"
#import "Language.h"
#import "PPAddressModel.h"
#import "PPAddressesManager.h"
#import "PPOptionCell.h"
#import "Styling.h"

@import CoreLocation;
@import FirebaseAuth;
#import <math.h>

static const CGFloat PPAddressCellHeight = 110.0;
static const CGFloat PPAddressBottomActionsHeight = 88.0;

@interface PPSelectAddressVC () <CLLocationManagerDelegate, AddressFormVCDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIView *headerContainer;
@property (nonatomic, strong) UILabel *headerTitleLabel;
@property (nonatomic, strong) UILabel *headerSubtitleLabel;
@property (nonatomic, strong) UIView *bottomActionsContainer;
@property (nonatomic, strong) UIVisualEffectView *bottomActionsBlurView;
@property (nonatomic, strong) UIView *bottomActionsTintView;
@property (nonatomic, strong) UIButton *deliverAnotherLocationButton;
@property (nonatomic, strong) UIButton *deliverCurrentLocationButton;

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) CLGeocoder *reverseGeocoder;
@property (nonatomic, assign) CLLocationCoordinate2D currentCoordinate;
@property (nonatomic, copy) NSString *currentLocationTitle;
@property (nonatomic, strong) UITapGestureRecognizer *backgroundDismissTapGesture;

@property (nonatomic, assign) BOOL didCompleteSelection;

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
        _currentCoordinate = kCLLocationCoordinate2DInvalid;
        _currentLocationTitle = @"";
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
        _currentCoordinate = kCLLocationCoordinate2DInvalid;
        _currentLocationTitle = @"";
    }
    return self;
}

#pragma mark - Lifecycle


- (void)viewDidLoad
{
    [super viewDidLoad];

    BOOL usesTransparentSurface = PPIOS26();
    self.view.backgroundColor = [self pp_sheetBackgroundColor];
    self.tableView.backgroundColor = usesTransparentSurface ? UIColor.clearColor : [self pp_sheetBackgroundColor];
    self.tableView.rowHeight = PPAddressCellHeight;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, PPAddressBottomActionsHeight + (usesTransparentSurface ? 24.0 : 20.0), 0);
    self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
    self.tableView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0.0;
    }

    [self.tableView registerClass:[PPOptionCell class] forCellReuseIdentifier:@"PPAddressOptionCell"];

    [self pp_configureHeader];
    [self pp_configureBottomActions];
    [self pp_applySheetStyleIfNeeded];
    [self pp_configureBackgroundDismissTap];
    [self pp_refreshVisibleColors];

    if (!self.filteredOptions) {
        self.filteredOptions = self.allOptions ?: @[];
    }
    


    [self pp_startResolvingCurrentLocation];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    if (self.headerContainer) {
        CGFloat targetWidth = CGRectGetWidth(self.tableView.bounds);
        CGRect frame = self.headerContainer.frame;
        if (fabs(frame.size.width - targetWidth) > 0.5) {
            frame.size.width = targetWidth;
            self.headerContainer.frame = frame;
            self.tableView.tableHeaderView = self.headerContainer;
        }
    }
}

#pragma mark - UI

- (NSString *)pp_localizedStringForKey:(NSString *)key fallback:(NSString *)fallback
{
    NSString *value = key.length > 0 ? kLang(key) : nil;
    if (![value isKindOfClass:NSString.class] || value.length == 0 || [value isEqualToString:key]) {
        return fallback ?: @"";
    }
    return value;
}

- (NSString *)pp_savedAddressesTitleText
{
    return [self pp_localizedStringForKey:@"saved_addresses_title" fallback:@"Saved addresses"];
}

- (NSString *)pp_deliverAddressesSubtitleText
{
    return [self pp_localizedStringForKey:@"deliver_addresses_subtitle" fallback:@"Deliver addresses"];
}

- (NSString *)pp_deliverToAnotherLocationText
{
    return [self pp_localizedStringForKey:@"deliver_to_another_location" fallback:@"Deliver to another location"];
}

- (NSString *)pp_deliverToCurrentLocationText
{
    return [self pp_localizedStringForKey:@"deliver_to_current_location" fallback:@"Deliver to current location"];
}

- (NSString *)pp_locatingCurrentLocationText
{
    return [self pp_localizedStringForKey:@"locating_current_location" fallback:@"Locating current location..."];
}

- (NSString *)pp_locationAccessDisabledText
{
    return [self pp_localizedStringForKey:@"location_access_disabled" fallback:@"Location access disabled"];
}

- (NSString *)pp_unableToDetectCurrentLocationText
{
    return [self pp_localizedStringForKey:@"unable_detect_current_location" fallback:@"Unable to detect current location."];
}

- (BOOL)pp_isDarkMode
{
    if (@available(iOS 13.0, *)) {
        return self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return NO;
}

- (UIColor *)pp_sheetBackgroundColor
{
    if ([self pp_isDarkMode]) {
        return [UIColor colorWithRed:0.036 green:0.034 blue:0.042 alpha:1.0];
    }
    return PPBackgroundColorForIOS26(PPIOS26()
                                    ? [AppForgroundColr colorWithAlphaComponent:0.64]
                                    : AppBackgroundClr);
}

- (UIColor *)pp_sheetSurfaceColor
{
    if ([self pp_isDarkMode]) {
        return [UIColor colorWithWhite:1.0 alpha:PPIOS26() ? 0.10 : 0.075];
    }
    return PPIOS26()
        ? [AppForgroundColr colorWithAlphaComponent:0.48]
        : [UIColor colorWithWhite:1.0 alpha:0.96];
}

- (UIColor *)pp_sheetElevatedSurfaceColor
{
    if ([self pp_isDarkMode]) {
        return [UIColor colorWithRed:0.118 green:0.112 blue:0.128 alpha:0.96];
    }
    return PPIOS26()
        ? [AppForgroundColr colorWithAlphaComponent:0.72]
        : AppForgroundColr;
}

- (UIColor *)pp_sheetTintOverlayColor
{
    if ([self pp_isDarkMode]) {
        return [UIColor colorWithRed:0.050 green:0.047 blue:0.056 alpha:PPIOS26() ? 0.72 : 0.94];
    }
    return [AppForgroundColr colorWithAlphaComponent:PPIOS26() ? 0.30 : 0.86];
}

- (UIColor *)pp_sheetTextColor
{
    if ([self pp_isDarkMode]) {
        return [UIColor colorWithWhite:1.0 alpha:0.96];
    }
    return AppPrimaryTextClr;
}

- (UIColor *)pp_sheetSecondaryTextColor
{
    if ([self pp_isDarkMode]) {
        return [UIColor colorWithWhite:1.0 alpha:0.64];
    }
    return [AppPrimaryTextClr colorWithAlphaComponent:0.64];
}

- (UIColor *)pp_sheetStrokeColor
{
    if ([self pp_isDarkMode]) {
        return [UIColor colorWithWhite:1.0 alpha:0.12];
    }
    return [UIColor colorWithWhite:0.0 alpha:0.075];
}

- (UIColor *)pp_sheetAccentSurfaceColor
{
    return [AppPrimaryClr colorWithAlphaComponent:[self pp_isDarkMode] ? 0.20 : 0.12];
}

- (UIBlurEffectStyle)pp_bottomActionsBlurStyle
{
    if (@available(iOS 13.0, *)) {
        if ([self pp_isDarkMode]) {
            return PPIOS26() ? UIBlurEffectStyleSystemThinMaterialDark : UIBlurEffectStyleSystemMaterialDark;
        }
        return PPIOS26() ? UIBlurEffectStyleSystemThinMaterialLight : UIBlurEffectStyleSystemUltraThinMaterialLight;
    }
    return UIBlurEffectStyleExtraLight;
}

- (void)pp_refreshSearchBarColors
{
    if (!self.searchBar) {
        return;
    }

    self.searchBar.tintColor = AppPrimaryClr;
    self.searchBar.barTintColor = UIColor.clearColor;

    if (@available(iOS 13.0, *)) {
        UITextField *textField = self.searchBar.searchTextField;
        textField.textColor = [self pp_sheetTextColor];
        textField.tintColor = AppPrimaryClr;
        textField.backgroundColor = [self pp_sheetSurfaceColor];
        textField.layer.cornerRadius = 16.0;
        textField.layer.masksToBounds = YES;
        textField.font = [GM MidFontWithSize:14.5];
        textField.textAlignment = [Language alignmentForCurrentLanguage];

        NSString *placeholder = self.searchBar.placeholder ?: [self pp_localizedStringForKey:@"SearchHere" fallback:@"Search addresses"];
        textField.attributedPlaceholder =
            [[NSAttributedString alloc] initWithString:placeholder
                                            attributes:@{
            NSForegroundColorAttributeName: [self pp_sheetSecondaryTextColor],
            NSFontAttributeName: [GM MidFontWithSize:14.5]
        }];

        if ([textField.leftView respondsToSelector:@selector(setTintColor:)]) {
            textField.leftView.tintColor = [self pp_sheetSecondaryTextColor];
        }
    }
}

- (void)pp_refreshActionButton:(UIButton *)button primary:(BOOL)primary
{
    if (!button) {
        return;
    }

    if (primary) {
        button.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:[self pp_isDarkMode] ? 0.92 : 0.96];
        button.layer.borderWidth = 0.0;
        [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    } else {
        button.backgroundColor = [self pp_sheetElevatedSurfaceColor];
        button.layer.borderWidth = 1.0;
        [button pp_setBorderColor:[AppPrimaryClr colorWithAlphaComponent:[self pp_isDarkMode] ? 0.34 : 0.24]];
        [button setTitleColor:AppPrimaryClr forState:UIControlStateNormal];
    }
}

- (void)pp_refreshVisibleColors
{
    BOOL usesTransparentSurface = PPIOS26();
    self.view.backgroundColor = [self pp_sheetBackgroundColor];
    self.tableView.backgroundColor = usesTransparentSurface ? UIColor.clearColor : [self pp_sheetBackgroundColor];

    self.headerTitleLabel.textColor = [self pp_sheetTextColor];
    self.headerSubtitleLabel.textColor = [self pp_sheetSecondaryTextColor];
    [self pp_refreshSearchBarColors];

    self.bottomActionsBlurView.effect = [UIBlurEffect effectWithStyle:[self pp_bottomActionsBlurStyle]];
    self.bottomActionsTintView.backgroundColor = [self pp_sheetTintOverlayColor];
    [self.bottomActionsContainer pp_setBorderColor:[self pp_sheetStrokeColor]];
    self.bottomActionsContainer.layer.shadowColor = UIColor.blackColor.CGColor;
    self.bottomActionsContainer.layer.shadowOpacity = [self pp_isDarkMode] ? 0.24 : 0.10;
    self.bottomActionsContainer.layer.shadowRadius = 18.0;
    self.bottomActionsContainer.layer.shadowOffset = CGSizeMake(0.0, 8.0);

    [self pp_refreshActionButton:self.deliverAnotherLocationButton primary:YES];
    [self pp_refreshActionButton:self.deliverCurrentLocationButton primary:NO];
    [self pp_refreshCurrentLocationButtonTitle];
}

- (void)pp_configureHeader
{
    CGFloat headerHeight = self.showSearchBar ? 168.0 : 116.0;
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.tableView.bounds), headerHeight)];
    header.backgroundColor = UIColor.clearColor;
    header.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:28];
    titleLabel.textColor = [self pp_sheetTextColor];
    titleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    titleLabel.text = [self pp_savedAddressesTitleText];

    UILabel *subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:15];
    subtitleLabel.textColor = [self pp_sheetSecondaryTextColor];
    subtitleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    subtitleLabel.text = [self pp_deliverAddressesSubtitleText];
    self.headerTitleLabel = titleLabel;
    self.headerSubtitleLabel = subtitleLabel;

    [header addSubview:titleLabel];
    [header addSubview:subtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:header.topAnchor constant:16.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:20.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-20.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:20.0],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-20.0]
    ]];

    if (self.showSearchBar) {
        UISearchBar *searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
        searchBar.translatesAutoresizingMaskIntoConstraints = NO;
        searchBar.searchBarStyle = UISearchBarStyleMinimal;
        searchBar.delegate = self;
        searchBar.placeholder = [self pp_localizedStringForKey:@"SearchHere" fallback:@"Search addresses"];
        searchBar.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

        [header addSubview:searchBar];
        self.searchBar = searchBar;
        [self pp_refreshSearchBarColors];

        [NSLayoutConstraint activateConstraints:@[
            [searchBar.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:22.0],
            [searchBar.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:14.0],
            [searchBar.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-14.0],
            [searchBar.heightAnchor constraintEqualToConstant:48.0]
        ]];
    }

    self.headerContainer = header;
    self.searchContainer = header;
    self.tableView.tableHeaderView = header;
}

- (UIButton *)pp_createActionButtonWithTitle:(NSString *)title primary:(BOOL)primary action:(SEL)action
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.layer.cornerRadius = 17.0;
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
    button.layer.masksToBounds = YES;
    button.titleLabel.font = [GM MidFontWithSize:16];
    button.titleLabel.numberOfLines = 2;
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.8;
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    button.contentEdgeInsets = UIEdgeInsetsMake(14, 16, 14, 16);
    button.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    [button setTitle:title forState:UIControlStateNormal];
    [self pp_refreshActionButton:button primary:primary];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)pp_configureBottomActions
{
    UIView *container = [[UIView alloc] initWithFrame:CGRectZero];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = UIColor.clearColor;
    container.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    container.layer.cornerRadius = 24.0;
    if (@available(iOS 13.0, *)) {
        container.layer.cornerCurve = kCACornerCurveContinuous;
    }
    container.layer.masksToBounds = NO;
    container.layer.borderWidth = 0.8;
    [container pp_setBorderColor:[self pp_sheetStrokeColor]];

    UIBlurEffectStyle blurStyle = [self pp_bottomActionsBlurStyle];
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:blurStyle];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    blurView.layer.cornerRadius = 24.0;
    if (@available(iOS 13.0, *)) {
        blurView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    blurView.layer.masksToBounds = YES;

    UIView *tintView = [[UIView alloc] initWithFrame:CGRectZero];
    tintView.translatesAutoresizingMaskIntoConstraints = NO;
    tintView.backgroundColor = [self pp_sheetTintOverlayColor];
    tintView.layer.cornerRadius = 24.0;
    if (@available(iOS 13.0, *)) {
        tintView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    tintView.layer.masksToBounds = YES;

    UIButton *anotherButton = [self pp_createActionButtonWithTitle:[self pp_deliverToAnotherLocationText]
                                                            primary:YES
                                                             action:@selector(pp_handleDeliverAnotherLocationTapped:)];

    UIButton *currentButton = [self pp_createActionButtonWithTitle:[self pp_deliverToCurrentLocationText]
                                                            primary:NO
                                                             action:@selector(pp_handleDeliverCurrentLocationTapped:)];

    [container addSubview:blurView];
    [container addSubview:tintView];
    [container addSubview:anotherButton];
    [container addSubview:currentButton];

    [self.view addSubview:container];
    self.bottomActionsContainer = container;
    self.bottomActionsBlurView = blurView;
    self.bottomActionsTintView = tintView;
    self.deliverAnotherLocationButton = anotherButton;
    self.deliverCurrentLocationButton = currentButton;

    [NSLayoutConstraint activateConstraints:@[
        [container.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16.0],
        [container.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16.0],
        [container.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-10.0],
        [container.heightAnchor constraintEqualToConstant:PPAddressBottomActionsHeight],

        [blurView.topAnchor constraintEqualToAnchor:container.topAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],

        [tintView.topAnchor constraintEqualToAnchor:container.topAnchor],
        [tintView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [tintView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [tintView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],

        [anotherButton.topAnchor constraintEqualToAnchor:container.topAnchor constant:14.0],
        [anotherButton.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-14.0],
        [anotherButton.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:14.0],

        [currentButton.topAnchor constraintEqualToAnchor:container.topAnchor constant:14.0],
        [currentButton.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-14.0],
        [currentButton.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-14.0],
        [currentButton.leadingAnchor constraintEqualToAnchor:anotherButton.trailingAnchor constant:12.0],
        [currentButton.widthAnchor constraintEqualToAnchor:anotherButton.widthAnchor]
    ]];

    [self pp_refreshCurrentLocationButtonTitle];
}

- (void)pp_applySheetStyleIfNeeded
{
    if (self.presentationStyle != PPSelectOptionPresentationSheet) {
        return;
    }

    if (@available(iOS 15.0, *)) {
        if (@available(iOS 16.0, *)) {
            UISheetPresentationControllerDetent *detent70 =
                [UISheetPresentationControllerDetent customDetentWithIdentifier:@"pp.select.address.70"
                                                                        resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> _Nonnull context) {
                return context.maximumDetentValue * 0.70;
            }];
            self.sheetPresentationController.detents = @[detent70];
            self.sheetPresentationController.selectedDetentIdentifier = detent70.identifier;
        } else {
            self.sheetPresentationController.detents = @[
                [UISheetPresentationControllerDetent largeDetent]
            ];
        }
        self.sheetPresentationController.preferredCornerRadius = PPIOS26() ? 34.0 : 24.0;
        self.sheetPresentationController.prefersScrollingExpandsWhenScrolledToEdge = NO;
        self.sheetPresentationController.prefersGrabberVisible = YES;
    }
}

- (void)pp_configureBackgroundDismissTap
{
    if (self.backgroundDismissTapGesture || self.presentationStyle != PPSelectOptionPresentationSheet) {
        return;
    }

    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_handleBackgroundDismissTap:)];
    tap.cancelsTouchesInView = NO;
    tap.delegate = self;
    [self.view addGestureRecognizer:tap];
    self.backgroundDismissTapGesture = tap;
}

- (void)pp_handleBackgroundDismissTap:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state != UIGestureRecognizerStateEnded ||
        self.presentationStyle != PPSelectOptionPresentationSheet) {
        return;
    }

    CGPoint pointInView = [recognizer locationInView:self.view];
    if (self.bottomActionsContainer && CGRectContainsPoint(self.bottomActionsContainer.frame, pointInView)) {
        return;
    }

    CGPoint pointInTable = [recognizer locationInView:self.tableView];
    if (self.tableView.tableHeaderView && CGRectContainsPoint(self.tableView.tableHeaderView.frame, pointInTable)) {
        return;
    }
    NSIndexPath *rowPath = [self.tableView indexPathForRowAtPoint:pointInTable];
    if (rowPath) {
        return;
    }

    [self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    if (gestureRecognizer != self.backgroundDismissTapGesture) {
        return YES;
    }

    UIView *touchView = touch.view;
    if ([touchView isKindOfClass:UIControl.class]) {
        return NO;
    }
    if (self.bottomActionsContainer && [touchView isDescendantOfView:self.bottomActionsContainer]) {
        return NO;
    }
    if (self.tableView.tableHeaderView && [touchView isDescendantOfView:self.tableView.tableHeaderView]) {
        return NO;
    }

    CGPoint pointInTable = [touch locationInView:self.tableView];
    if ([self.tableView indexPathForRowAtPoint:pointInTable]) {
        return NO;
    }
    return YES;
}

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

    [self.tableView reloadData];
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

    NSString *displayName = [address.displayName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (displayName.length > 0) return displayName;

    NSString *locationName = [address.locatioName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (locationName.length > 0) return locationName;

    NSString *line1 = [address.addressLine1 stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (line1.length > 0) return line1;

    NSString *fullName = [address.fullName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (fullName.length > 0) return fullName;

    return @"";
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
    __weak typeof(self) weakSelf = self;
    [[PPAddressesManager sharedManager] getAllAddressesWithCompletion:^(NSArray<PPAddressModel *> * _Nullable addresses, NSError * _Nullable error) {
        if (error || addresses.count == 0) {
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }
            self.allOptions = addresses;
            [self pp_applyFilterWithQuery:self.searchBar.text ?: @""];

            if (selectedAddressID.length > 0) {
                PPAddressModel *selected = [self pp_addressForID:selectedAddressID];
                if (selected) {
                    self.selectedOption = selected;
                    [self.tableView reloadData];
                }
            }
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
        if (selectedID.length > 0 && [selectedID isEqualToString:candidateID]) {
            return YES;
        }
    }

    if ([self.rowDescriptor.value isKindOfClass:NSString.class]) {
        NSString *current = [(NSString *)self.rowDescriptor.value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (current.length > 0) {
            return [[self pp_displayTextForAddress:address] isEqualToString:current];
        }
    }

    return NO;
}

- (void)pp_completeWithAddress:(PPAddressModel *)address
{
    if (!address || self.didCompleteSelection) {
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
    PPOptionCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPAddressOptionCell" forIndexPath:indexPath];
    id item = (indexPath.row < self.filteredOptions.count) ? self.filteredOptions[indexPath.row] : nil;

    if (![item isKindOfClass:PPAddressModel.class]) {
        [cell configureWithTitle:@"" subtitle:@" " imageNamed:@"mappin.and.ellipse.circle.fill"];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.backgroundColor = UIColor.clearColor;
        cell.contentView.backgroundColor = UIColor.clearColor;
        return cell;
    }

    PPAddressModel *address = (PPAddressModel *)item;

    NSString *title = [address.fullName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (title.length == 0) {
        title = [self pp_displayTextForAddress:address];
    }

    NSString *subtitle = [self pp_displayTextForAddress:address];
    if (subtitle.length == 0) {
        subtitle = @" ";
    }

    if (address.isDefault) {
        NSString *defaultText = [self pp_localizedStringForKey:@"Default" fallback:@"Default"];
        subtitle = [NSString stringWithFormat:@"%@ • %@", subtitle, defaultText];
    }

    NSString *iconName = address.isDefault ? @"flag.circle.fill" : @"mappin.and.ellipse.circle.fill";
    [cell configureWithTitle:title subtitle:subtitle imageNamed:iconName];
    cell.titleLabel.numberOfLines = 1;
    cell.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    cell.subtitleLabel.numberOfLines = 3;
    cell.subtitleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    cell.titleLabel.font = [GM MidFontWithSize:17];
    cell.subtitleLabel.font = [GM MidFontWithSize:14];
    cell.titleLabel.textColor = [self pp_sheetTextColor];
    cell.subtitleLabel.textColor = [self pp_sheetSecondaryTextColor];
    cell.circleImageView.tintColor = AppPrimaryClr;
    cell.circleImageView.backgroundColor = [self pp_sheetAccentSurfaceColor];
    cell.circleImageView.layer.cornerRadius = 20.0;
    cell.circleImageView.layer.masksToBounds = YES;
    BOOL isSelected = [self pp_isAddressSelected:address];
    cell.accessoryType = isSelected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    cell.tintColor = AppPrimaryClr;
    cell.backgroundColor = UIColor.clearColor;
    cell.contentView.backgroundColor = UIColor.clearColor;
    if (@available(iOS 14.0, *)) {
        UIBackgroundConfiguration *backgroundConfig = [UIBackgroundConfiguration clearConfiguration];
        backgroundConfig.cornerRadius = 22.0;
        backgroundConfig.backgroundColor = [self pp_sheetSurfaceColor];
        if (@available(iOS 15.0, *)) {
            backgroundConfig.backgroundInsets = NSDirectionalEdgeInsetsMake(6.0, 14.0, 6.0, 14.0);
            backgroundConfig.strokeColor = [self pp_sheetStrokeColor];
            backgroundConfig.strokeWidth = 1.0;
        }
        cell.backgroundConfiguration = backgroundConfig;

        UIBackgroundConfiguration *selectedConfig = [backgroundConfig copy];
        selectedConfig.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:[self pp_isDarkMode] ? 0.22 : 0.10];
        if (@available(iOS 15.0, *)) {
            selectedConfig.strokeColor = [AppPrimaryClr colorWithAlphaComponent:[self pp_isDarkMode] ? 0.92 : 0.84];
            selectedConfig.strokeWidth = 2.0;
        }
        cell.backgroundConfiguration = isSelected ? selectedConfig : backgroundConfig;
    }

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

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (@available(iOS 14.0, *)) {
        return;
    }

    [Styling applyBackgroundStyleForTableView:tableView
                                         cell:cell
                                    indexPath:indexPath
                               useRowCardMode:YES];
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

- (void)pp_handleDeliverAnotherLocationTapped:(id)sender
{
    (void)sender;

    AddressFormVC *formVC = [[AddressFormVC alloc] initWithAddress:nil];
    formVC.addressFormPresent = AddressFormPresentSheet;
    formVC.delegate = self;

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:formVC];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;

    if (@available(iOS 15.0, *)) {
        nav.sheetPresentationController.detents = @[
            [UISheetPresentationControllerDetent mediumDetent],
            [UISheetPresentationControllerDetent largeDetent]
        ];
        nav.sheetPresentationController.prefersGrabberVisible = YES;
    }

    [self presentViewController:nav animated:YES completion:nil];
}

- (void)pp_handleDeliverCurrentLocationTapped:(id)sender
{
    (void)sender;

    if (![self pp_isValidCoordinate:self.currentCoordinate]) {
        NSString *title = [self pp_localizedStringForKey:@"Location" fallback:@"Location"];
        NSString *message = [self pp_localizedStringForKey:@"unable_detect_current_location_now"
                                                  fallback:@"Unable to detect current location right now."];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:[self pp_localizedStringForKey:@"ok" fallback:@"OK"]
                                                  style:UIAlertActionStyleDefault
                                                handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    FIRUser *authUser = [FIRAuth auth].currentUser;
    NSString *tempID = [NSString stringWithFormat:@"current_%@", NSUUID.UUID.UUIDString.lowercaseString];
    NSString *locationTitle = self.currentLocationTitle.length > 0
        ? self.currentLocationTitle
        : [NSString stringWithFormat:@"%.6f, %.6f", self.currentCoordinate.latitude, self.currentCoordinate.longitude];

    PPAddressModel *currentAddress = [PPAddressModel new];
    currentAddress.documentID = tempID;
    currentAddress.addressID = tempID;
    currentAddress.userID = authUser.uid ?: @"";
    currentAddress.fullName = authUser.displayName ?: @"";
    currentAddress.phoneNumber = authUser.phoneNumber ?: @"";
    currentAddress.addressLine1 = locationTitle;
    currentAddress.addressLine2 = nil;
    currentAddress.locatioName = locationTitle;
    currentAddress.locationPoints = [NSString stringWithFormat:@"%.6f, %.6f", self.currentCoordinate.latitude, self.currentCoordinate.longitude];
    currentAddress.postalCode = @"";
    currentAddress.isDefault = NO;

    [self pp_completeWithAddress:currentAddress];
}

#pragma mark - AddressFormVCDelegate

- (void)addressFormVC:(AddressFormVC *)controller didSaveAddress:(PPAddressModel *)address
{
    (void)controller;
    if (![address isKindOfClass:PPAddressModel.class]) {
        return;
    }

    NSString *savedID = [self pp_effectiveAddressID:address];
    [self pp_reloadAddressesFromServerSelectingID:savedID];

    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.42 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.didCompleteSelection) {
            return;
        }

        PPAddressModel *resolved = [self pp_addressForID:savedID] ?: address;
        [self pp_completeWithAddress:resolved];
    });
}

- (void)addressFormVC:(AddressFormVC *)controller didDeleteAddress:(PPAddressModel *)address
{
    (void)controller;
    NSString *deletedID = [self pp_effectiveAddressID:address];

    if (deletedID.length > 0 && [self.selectedOption isKindOfClass:PPAddressModel.class]) {
        PPAddressModel *selected = (PPAddressModel *)self.selectedOption;
        if ([[self pp_effectiveAddressID:selected] isEqualToString:deletedID]) {
            self.selectedOption = nil;
        }
    }

    [self pp_reloadAddressesFromServerSelectingID:nil];
}

#pragma mark - Current Location

- (BOOL)pp_isValidCoordinate:(CLLocationCoordinate2D)coordinate
{
    if (!CLLocationCoordinate2DIsValid(coordinate)) {
        return NO;
    }
    return !(fabs(coordinate.latitude) < 0.000001 && fabs(coordinate.longitude) < 0.000001);
}

- (void)pp_refreshCurrentLocationButtonTitle
{
    NSString *title = [self pp_deliverToCurrentLocationText];
    NSString *subtitle = self.currentLocationTitle.length > 0
        ? self.currentLocationTitle
        : [self pp_locatingCurrentLocationText];

    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.alignment = NSTextAlignmentCenter;
    style.lineSpacing = 2.0;

    NSDictionary *titleAttrs = @{
        NSFontAttributeName: [GM MidFontWithSize:15],
        NSForegroundColorAttributeName: AppPrimaryClr,
        NSParagraphStyleAttributeName: style
    };

    NSDictionary *subtitleAttrs = @{
        NSFontAttributeName: [GM MidFontWithSize:12],
        NSForegroundColorAttributeName: [self pp_isDarkMode] ? [UIColor colorWithWhite:1.0 alpha:0.68] : [AppPrimaryClr colorWithAlphaComponent:PPIOS26() ? 0.82 : 0.74],
        NSParagraphStyleAttributeName: style
    };

    NSMutableAttributedString *combined = [[NSMutableAttributedString alloc] initWithString:title attributes:titleAttrs];
    [combined appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:titleAttrs]];
    [combined appendAttributedString:[[NSAttributedString alloc] initWithString:subtitle attributes:subtitleAttrs]];

    [self.deliverCurrentLocationButton setAttributedTitle:combined forState:UIControlStateNormal];
}

- (void)pp_startResolvingCurrentLocation
{
    self.currentCoordinate = kCLLocationCoordinate2DInvalid;
    self.currentLocationTitle = [self pp_locatingCurrentLocationText];
    [self pp_refreshCurrentLocationButtonTitle];

    if (!self.locationManager) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
    }

    if (!self.reverseGeocoder) {
        self.reverseGeocoder = [[CLGeocoder alloc] init];
    }

    CLAuthorizationStatus status;
    if (@available(iOS 14.0, *)) {
        status = self.locationManager.authorizationStatus;
    } else {
        status = [CLLocationManager authorizationStatus];
    }

    if (status == kCLAuthorizationStatusNotDetermined) {
        [self.locationManager requestWhenInUseAuthorization];
        return;
    }

    if (status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted) {
        self.currentLocationTitle = [self pp_locationAccessDisabledText];
        [self pp_refreshCurrentLocationButtonTitle];
        return;
    }

    [self pp_requestCurrentLocationSample];
}

- (void)pp_requestCurrentLocationSample
{
    if (@available(iOS 9.0, *)) {
        [self.locationManager requestLocation];
    } else {
        [self.locationManager startUpdatingLocation];
    }
}

- (void)pp_reverseGeocodeCoordinate:(CLLocationCoordinate2D)coordinate
{
    if (![self pp_isValidCoordinate:coordinate]) {
        return;
    }

    if (self.reverseGeocoder.isGeocoding) {
        [self.reverseGeocoder cancelGeocode];
    }

    CLLocation *location = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
    __weak typeof(self) weakSelf = self;
    [self.reverseGeocoder reverseGeocodeLocation:location completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || error || placemarks.count == 0) {
            return;
        }

        CLPlacemark *placemark = placemarks.firstObject;
        NSString *primary = placemark.subLocality ?: placemark.locality ?: placemark.thoroughfare ?: @"";
        NSString *secondary = placemark.locality ?: placemark.administrativeArea ?: placemark.country ?: @"";

        NSString *resolved = @"";
        if (primary.length > 0 && secondary.length > 0 && ![primary isEqualToString:secondary]) {
            resolved = [NSString stringWithFormat:@"%@, %@", primary, secondary];
        } else {
            resolved = primary.length > 0 ? primary : secondary;
        }

        if (resolved.length == 0) {
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self.currentLocationTitle = resolved;
            [self pp_refreshCurrentLocationButtonTitle];
        });
    }];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    (void)manager;
    CLLocation *location = locations.lastObject;
    if (!location) {
        return;
    }

    self.currentCoordinate = location.coordinate;
    self.currentLocationTitle = [NSString stringWithFormat:@"%.6f, %.6f",
                                 self.currentCoordinate.latitude,
                                 self.currentCoordinate.longitude];
    [self pp_refreshCurrentLocationButtonTitle];

    [self.locationManager stopUpdatingLocation];
    [self pp_reverseGeocodeCoordinate:self.currentCoordinate];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    (void)manager;
    (void)error;

    if (![self pp_isValidCoordinate:self.currentCoordinate]) {
        self.currentLocationTitle = [self pp_unableToDetectCurrentLocationText];
        [self pp_refreshCurrentLocationButtonTitle];
    }
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager
{
    (void)manager;
    [self pp_startResolvingCurrentLocation];
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    (void)manager;
    (void)status;
    [self pp_startResolvingCurrentLocation];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_refreshVisibleColors];
            [self.tableView reloadData];
        }
    }
}

@end
