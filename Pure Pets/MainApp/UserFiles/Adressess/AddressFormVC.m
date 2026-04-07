//
//  AddressFormVC.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 28/10/2025.
//

#import "AddressFormVC.h"
#import "CountryModel.h"
#import "CityModel.h"
#import "GM.h"
#import "LocationPickerViewController.h"
@import FirebaseAuth;
@import CoreLocation;
#import <float.h>
#import <math.h>

typedef NS_ENUM(NSInteger, PPAddressSectionKind) {
    PPAddressSectionKindRecipient = 0,
    PPAddressSectionKindStreet,
    PPAddressSectionKindGeography,
    PPAddressSectionKindPreferences,
    PPAddressSectionKindDanger
};

typedef NS_ENUM(NSInteger, PPAddressFieldKind) {
    PPAddressFieldKindFullName = 1,
    PPAddressFieldKindPhoneNumber,
    PPAddressFieldKindAddressLine1,
    PPAddressFieldKindAddressLine2,
    PPAddressFieldKindPostalCode,
    PPAddressFieldKindCountry,
    PPAddressFieldKindCity,
    PPAddressFieldKindState,
    PPAddressFieldKindLocation
};

static const CGFloat kPPAddressCellHorizontalInset = 16.0;
static const CGFloat kPPAddressCellVerticalInset   = 6.0;

@interface PPAddressBaseCell : UITableViewCell
@end

@implementation PPAddressBaseCell

- (void)setFrame:(CGRect)frame
{
    frame.origin.x = kPPAddressCellHorizontalInset;
    frame.size.width -= kPPAddressCellHorizontalInset * 2.0;
    frame.origin.y += kPPAddressCellVerticalInset * 0.5;
    frame.size.height -= kPPAddressCellVerticalInset;
    if (frame.size.width  < 0.0) frame.size.width  = 0.0;
    if (frame.size.height < 0.0) frame.size.height = 0.0;
    [super setFrame:frame];
}

@end

@interface PPAddressTextFieldCell : PPAddressBaseCell
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UITextField *textField;
- (void)configureWithTitle:(NSString *)title
                      text:(NSString *)text
               placeholder:(NSString *)placeholder
              keyboardType:(UIKeyboardType)keyboardType
           textContentType:(UITextContentType)textContentType
             returnKeyType:(UIReturnKeyType)returnKeyType
    autocapitalizationType:(UITextAutocapitalizationType)autocapitalizationType
                 fieldKind:(PPAddressFieldKind)fieldKind
                    target:(id)target
                    action:(SEL)action
                  delegate:(id<UITextFieldDelegate>)delegate;
@end

@implementation PPAddressTextFieldCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) {
        return nil;
    }

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.contentView addSubview:titleLabel];
    self.titleLabel = titleLabel;

    UITextField *textField = [[UITextField alloc] init];
    textField.translatesAutoresizingMaskIntoConstraints = NO;
    textField.borderStyle = UITextBorderStyleNone;
    textField.backgroundColor = UIColor.clearColor;
    textField.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    textField.font = [GM MidFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
    textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    textField.autocorrectionType = UITextAutocorrectionTypeNo;
    [self.contentView addSubview:textField];
    self.textField = textField;

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:14.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],

        [textField.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],
        [textField.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [textField.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [textField.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-14.0],
        [textField.heightAnchor constraintGreaterThanOrEqualToConstant:24.0]
    ]];

    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [self.textField removeTarget:nil action:NULL forControlEvents:UIControlEventEditingChanged];
}

- (void)configureWithTitle:(NSString *)title
                      text:(NSString *)text
               placeholder:(NSString *)placeholder
              keyboardType:(UIKeyboardType)keyboardType
           textContentType:(UITextContentType)textContentType
             returnKeyType:(UIReturnKeyType)returnKeyType
    autocapitalizationType:(UITextAutocapitalizationType)autocapitalizationType
                 fieldKind:(PPAddressFieldKind)fieldKind
                    target:(id)target
                    action:(SEL)action
                  delegate:(id<UITextFieldDelegate>)delegate
{
    self.titleLabel.text = title ?: @"";
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;

    self.textField.text = text ?: @"";
    self.textField.placeholder = placeholder ?: @"";
    self.textField.tag = fieldKind;
    self.textField.delegate = delegate;
    self.textField.keyboardType = keyboardType;
    self.textField.textContentType = textContentType;
    self.textField.returnKeyType = returnKeyType;
    self.textField.autocapitalizationType = autocapitalizationType;
    self.textField.textAlignment = fieldKind == PPAddressFieldKindPhoneNumber
        ? NSTextAlignmentLeft
        : Language.alignmentForCurrentLanguage;
    self.textField.semanticContentAttribute = fieldKind == PPAddressFieldKindPhoneNumber
        ? UISemanticContentAttributeForceLeftToRight
        : Language.semanticAttributeForCurrentLanguage;

    [self.textField removeTarget:nil action:NULL forControlEvents:UIControlEventEditingChanged];
    if (target && action) {
        [self.textField addTarget:target action:action forControlEvents:UIControlEventEditingChanged];
    }
}

@end

@interface PPAddressSelectorCell : PPAddressBaseCell
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *valueLabel;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) UIImageView *chevronView;
- (void)configureWithTitle:(NSString *)title
                     value:(NSString *)value
               placeholder:(NSString *)placeholder
                    detail:(NSString *)detail;
@end

@implementation PPAddressSelectorCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) {
        return nil;
    }

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.contentView addSubview:titleLabel];
    self.titleLabel = titleLabel;

    UILabel *valueLabel = [[UILabel alloc] init];
    valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    valueLabel.font = [GM MidFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
    valueLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    valueLabel.numberOfLines = 2;
    valueLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.contentView addSubview:valueLabel];
    self.valueLabel = valueLabel;

    UILabel *detailLabel = [[UILabel alloc] init];
    detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    detailLabel.font = [GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    detailLabel.textColor = [UIColor secondaryLabelColor];
    detailLabel.numberOfLines = 2;
    detailLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.contentView addSubview:detailLabel];
    self.detailLabel = detailLabel;

    UIImageView *chevronView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.down"]];
    chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    chevronView.tintColor = [[UIColor secondaryLabelColor] colorWithAlphaComponent:0.8];
    chevronView.contentMode = UIViewContentModeScaleAspectFit;
    [self.contentView addSubview:chevronView];
    self.chevronView = chevronView;

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:14.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],

        [chevronView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [chevronView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
        [chevronView.widthAnchor constraintEqualToConstant:14.0],
        [chevronView.heightAnchor constraintEqualToConstant:14.0],

        [valueLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],
        [valueLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [valueLabel.trailingAnchor constraintEqualToAnchor:chevronView.leadingAnchor constant:-12.0],

        [detailLabel.topAnchor constraintEqualToAnchor:valueLabel.bottomAnchor constant:4.0],
        [detailLabel.leadingAnchor constraintEqualToAnchor:valueLabel.leadingAnchor],
        [detailLabel.trailingAnchor constraintEqualToAnchor:valueLabel.trailingAnchor],
        [detailLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-14.0]
    ]];

    return self;
}

- (void)configureWithTitle:(NSString *)title
                     value:(NSString *)value
               placeholder:(NSString *)placeholder
                    detail:(NSString *)detail
{
    NSString *trimmedValue = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    BOOL hasValue = trimmedValue.length > 0;

    self.titleLabel.text = title ?: @"";
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;

    self.valueLabel.text = hasValue ? trimmedValue : (placeholder ?: @"");
    self.valueLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.valueLabel.textColor = hasValue
        ? (AppPrimaryTextClr ?: UIColor.labelColor)
        : [[UIColor secondaryLabelColor] colorWithAlphaComponent:0.95];

    self.detailLabel.text = detail ?: @"";
    self.detailLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.detailLabel.hidden = detail.length == 0;
}

@end

@interface PPAddressSwitchCell : PPAddressBaseCell
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UISwitch *toggleSwitch;
- (void)configureWithTitle:(NSString *)title
                  subtitle:(NSString *)subtitle
                        on:(BOOL)isOn
                    target:(id)target
                    action:(SEL)action;
@end

@implementation PPAddressSwitchCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) {
        return nil;
    }

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.contentView addSubview:titleLabel];
    self.titleLabel = titleLabel;

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    subtitleLabel.textColor = [UIColor secondaryLabelColor];
    subtitleLabel.numberOfLines = 2;
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.contentView addSubview:subtitleLabel];
    self.subtitleLabel = subtitleLabel;

    UISwitch *toggleSwitch = [[UISwitch alloc] init];
    toggleSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    toggleSwitch.onTintColor = AppPrimaryClr ?: UIColor.systemOrangeColor;
    [self.contentView addSubview:toggleSwitch];
    self.toggleSwitch = toggleSwitch;

    [NSLayoutConstraint activateConstraints:@[
        [toggleSwitch.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [toggleSwitch.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],

        [titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:15.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:toggleSwitch.leadingAnchor constant:-14.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:5.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [subtitleLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-15.0]
    ]];

    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [self.toggleSwitch removeTarget:nil action:NULL forControlEvents:UIControlEventValueChanged];
}

- (void)configureWithTitle:(NSString *)title
                  subtitle:(NSString *)subtitle
                        on:(BOOL)isOn
                    target:(id)target
                    action:(SEL)action
{
    self.titleLabel.text = title ?: @"";
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.subtitleLabel.text = subtitle ?: @"";
    self.subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.toggleSwitch.on = isOn;

    [self.toggleSwitch removeTarget:nil action:NULL forControlEvents:UIControlEventValueChanged];
    if (target && action) {
        [self.toggleSwitch addTarget:target action:action forControlEvents:UIControlEventValueChanged];
    }
}

@end

@interface PPAddressActionCell : PPAddressBaseCell
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
- (void)configureWithTitle:(NSString *)title
                  iconName:(NSString *)iconName
               destructive:(BOOL)destructive;
@end

@implementation PPAddressActionCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) {
        return nil;
    }

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;

    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.contentView addSubview:iconView];
    self.iconView = iconView;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.contentView addSubview:titleLabel];
    self.titleLabel = titleLabel;

    [NSLayoutConstraint activateConstraints:@[
        [iconView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
        [iconView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:18.0],
        [iconView.heightAnchor constraintEqualToConstant:18.0],

        [titleLabel.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:10.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
        [titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:16.0],
        [titleLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-16.0]
    ]];

    return self;
}

- (void)configureWithTitle:(NSString *)title
                  iconName:(NSString *)iconName
               destructive:(BOOL)destructive
{
    UIColor *tintColor = destructive ? UIColor.systemRedColor : (AppPrimaryClr ?: UIColor.systemOrangeColor);
    self.iconView.tintColor = tintColor;
    self.iconView.image = [UIImage systemImageNamed:iconName ?: @"trash"];
    self.titleLabel.text = title ?: @"";
    self.titleLabel.textColor = tintColor;
}

@end

@interface PPAddressOptionsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating>
- (instancetype)initWithTitle:(NSString *)title
                      options:(NSArray *)options
               selectedOption:(nullable id)selectedOption
                titleProvider:(NSString * _Nonnull (^)(id option))titleProvider
             selectionHandler:(void (^)(id option))selectionHandler;
@end

@interface PPAddressOptionsViewController ()
@property (nonatomic, copy) NSArray *allOptions;
@property (nonatomic, copy) NSArray *filteredOptions;
@property (nonatomic, strong) id selectedOption;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, copy) NSString *(^titleProvider)(id option);
@property (nonatomic, copy) void (^selectionHandler)(id option);
@end

@implementation PPAddressOptionsViewController

- (instancetype)initWithTitle:(NSString *)title
                      options:(NSArray *)options
               selectedOption:(id)selectedOption
                titleProvider:(NSString * _Nonnull (^)(id option))titleProvider
             selectionHandler:(void (^)(id option))selectionHandler
{
    self = [super initWithNibName:nil bundle:nil];
    if (!self) {
        return nil;
    }

    self.title = title ?: @"";
    self.allOptions = options ?: @[];
    self.filteredOptions = self.allOptions;
    self.selectedOption = selectedOption;
    self.titleProvider = [titleProvider copy];
    self.selectionHandler = [selectionHandler copy];
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = PPBackgroundColorForIOS26([UIColor colorWithRed:0.968 green:0.962 blue:0.952 alpha:1.0]);
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    tableView.translatesAutoresizingMaskIntoConstraints = NO;
    tableView.delegate = self;
    tableView.dataSource = self;
    tableView.backgroundColor = UIColor.clearColor;
    tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    if (@available(iOS 15.0, *)) {
        tableView.sectionHeaderTopPadding = 0.0;
    }
    [self.view addSubview:tableView];
    [NSLayoutConstraint activateConstraints:@[
        [tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [tableView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [tableView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    self.tableView = tableView;

    UISearchController *searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    searchController.searchResultsUpdater = self;
    searchController.obscuresBackgroundDuringPresentation = NO;
    searchController.hidesNavigationBarDuringPresentation = NO;
    searchController.searchBar.placeholder = kLang(@"Search") ?: @"Search";
    self.navigationItem.searchController = searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;
    self.searchController = searchController;
}

- (NSArray *)pp_displayedOptions
{
    BOOL hasSearchText = self.searchController.isActive && self.searchController.searchBar.text.length > 0;
    return hasSearchText ? self.filteredOptions : self.allOptions;
}

- (NSString *)pp_titleForOption:(id)option
{
    if (!option) {
        return @"";
    }
    if (self.titleProvider) {
        return self.titleProvider(option) ?: @"";
    }
    return [option description];
}

- (BOOL)pp_option:(id)lhs matchesOption:(id)rhs
{
    if (lhs == rhs) {
        return YES;
    }
    if (!lhs || !rhs) {
        return NO;
    }
    if ([lhs isKindOfClass:CountryModel.class] && [rhs isKindOfClass:CountryModel.class]) {
        return ((CountryModel *)lhs).countryID == ((CountryModel *)rhs).countryID;
    }
    if ([lhs isKindOfClass:CityModel.class] && [rhs isKindOfClass:CityModel.class]) {
        return ((CityModel *)lhs).cityID == ((CityModel *)rhs).cityID;
    }
    if ([lhs isKindOfClass:StateModel.class] && [rhs isKindOfClass:StateModel.class]) {
        return ((StateModel *)lhs).stateID == ((StateModel *)rhs).stateID;
    }
    return [lhs isEqual:rhs];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController
{
    NSString *query = [[searchController.searchBar.text ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    if (query.length == 0) {
        self.filteredOptions = self.allOptions;
    } else {
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
            NSString *title = [[self pp_titleForOption:evaluatedObject] lowercaseString];
            return [title containsString:query];
        }];
        self.filteredOptions = [self.allOptions filteredArrayUsingPredicate:predicate];
    }
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self pp_displayedOptions].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"PPAddressOptionsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }

    NSArray *options = [self pp_displayedOptions];
    id option = options[indexPath.row];
    cell.textLabel.text = [self pp_titleForOption:option];
    cell.textLabel.font = [GM MidFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
    cell.textLabel.textAlignment = Language.alignmentForCurrentLanguage;
    cell.textLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    cell.backgroundColor = UIColor.clearColor;
    cell.accessoryType = [self pp_option:option matchesOption:self.selectedOption]
        ? UITableViewCellAccessoryCheckmark
        : UITableViewCellAccessoryNone;
    cell.tintColor = AppPrimaryClr ?: UIColor.systemOrangeColor;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSArray *options = [self pp_displayedOptions];
    if (indexPath.row >= options.count) {
        return;
    }

    id option = options[indexPath.row];
    if (self.selectionHandler) {
        self.selectionHandler(option);
    }

    if (self.navigationController) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

@end

@interface AddressFormVC () <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, CLLocationManagerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<CountryModel *> *countriesArray;
@property (nonatomic, strong) NSArray<CityModel *> *citiesArray;
@property (nonatomic, strong) NSArray<StateModel *> *statesArray;
@property (nonatomic, strong) CountryModel *selectedCountry;
@property (nonatomic, strong) StateModel *selectedState;
@property (nonatomic, strong) CityModel *selectedCity;
@property (nonatomic, copy) NSString *selectedLocationName;
@property (nonatomic, copy) NSString *selectedLocationPoints;

@property (nonatomic, copy) NSString *draftFullName;
@property (nonatomic, copy) NSString *draftPhoneNumber;
@property (nonatomic, copy) NSString *draftAddressLine1;
@property (nonatomic, copy) NSString *draftAddressLine2;
@property (nonatomic, copy) NSString *draftPostalCode;
@property (nonatomic, assign) BOOL draftIsDefault;

@property (nonatomic, assign) BOOL isSaving;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) CLGeocoder *reverseGeocoder;
@property (nonatomic, assign) CLLocationCoordinate2D currentDeviceCoordinate;
@property (nonatomic, assign) BOOL didApplyInitialLocation;
@property (nonatomic, strong) CountryModel *resolvedCountry;
@property (nonatomic, assign) BOOL didShowLocationPermissionAlert;

@property (nonatomic, strong) UIView *headerRoot;
@property (nonatomic, strong) UIView *headerCardView;
@property (nonatomic, strong) UIView *headerGradientBar;
@property (nonatomic, strong) UILabel *headerEyebrowLabel;
@property (nonatomic, strong) UILabel *headerTitleLabel;
@property (nonatomic, strong) UILabel *headerSubtitleLabel;
@property (nonatomic, strong) UILabel *headerMetaLabel;
@property (nonatomic, strong) UIView *backgroundGlowViewTop;
@property (nonatomic, strong) UIView *backgroundGlowViewBottom;

@property (nonatomic, strong) UIBarButtonItem *saveBarButtonItem;
@property (nonatomic, strong) UIBarButtonItem *leadingBarButtonItem;
@end

@implementation AddressFormVC

#pragma mark - Init

- (UITableView *)tableView
{
    if (!_tableView && !self.isViewLoaded) {
        [self loadViewIfNeeded];
    }
    return _tableView;
}

- (instancetype)init
{
    return [self initWithAddress:nil];
}

- (instancetype)initWithAddress:(PPAddressModel *)address
{
    self = [super initWithNibName:nil bundle:nil];
    if (!self) {
        return nil;
    }

    _address = address;
    _addressFormPresent = AddressFormPresentPush;
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (!self) {
        return nil;
    }

    _addressFormPresent = AddressFormPresentPush;
    return self;
}

#pragma mark - Appearance

- (UIColor *)pp_canvasColor
{
    return [UIColor colorWithRed:0.969 green:0.961 blue:0.951 alpha:1.0];
}

- (UIColor *)pp_surfaceColor
{
    return [[UIColor whiteColor] colorWithAlphaComponent:0.84];
}

- (UIColor *)pp_surfaceBorderColor
{
    return [UIColor colorWithRed:0.26 green:0.18 blue:0.17 alpha:0.08];
}

- (void)pp_applyCanvasBackground
{
    UIColor *canvasColor = [self pp_canvasColor];
    self.view.backgroundColor = canvasColor;
    self.view.opaque = YES;
    self.navigationController.view.backgroundColor = canvasColor;
    self.tableView.backgroundColor = UIColor.clearColor;
}

- (NSString *)pp_localizedAddressStringForKey:(NSString *)key fallback:(NSString *)fallback
{
    NSString *value = key.length ? kLang(key) : nil;
    if (![value isKindOfClass:NSString.class] || value.length == 0 || [value isEqualToString:key]) {
        return fallback ?: @"";
    }
    return value;
}

- (void)pp_setupBackdrop
{
    if (self.backgroundGlowViewTop || self.backgroundGlowViewBottom) {
        return;
    }

    UIView *topGlow = [[UIView alloc] init];
    topGlow.translatesAutoresizingMaskIntoConstraints = NO;
    topGlow.userInteractionEnabled = NO;
    topGlow.backgroundColor = [[UIColor colorWithRed:0.95 green:0.77 blue:0.65 alpha:1.0] colorWithAlphaComponent:0.30];
    topGlow.layer.shadowColor = [UIColor colorWithRed:0.95 green:0.73 blue:0.52 alpha:1.0].CGColor;
    topGlow.layer.shadowOpacity = 0.22;
    topGlow.layer.shadowRadius = 60.0;
    topGlow.layer.shadowOffset = CGSizeZero;

    UIView *bottomGlow = [[UIView alloc] init];
    bottomGlow.translatesAutoresizingMaskIntoConstraints = NO;
    bottomGlow.userInteractionEnabled = NO;
    bottomGlow.backgroundColor = [[UIColor colorWithRed:0.75 green:0.52 blue:0.58 alpha:1.0] colorWithAlphaComponent:0.22];
    bottomGlow.layer.shadowColor = [UIColor colorWithRed:0.71 green:0.34 blue:0.42 alpha:1.0].CGColor;
    bottomGlow.layer.shadowOpacity = 0.18;
    bottomGlow.layer.shadowRadius = 70.0;
    bottomGlow.layer.shadowOffset = CGSizeZero;

    [self.view insertSubview:topGlow belowSubview:self.tableView];
    [self.view insertSubview:bottomGlow belowSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [topGlow.widthAnchor constraintEqualToConstant:220.0],
        [topGlow.heightAnchor constraintEqualToConstant:220.0],
        [topGlow.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:-74.0],
        [topGlow.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:86.0],

        [bottomGlow.widthAnchor constraintEqualToConstant:210.0],
        [bottomGlow.heightAnchor constraintEqualToConstant:210.0],
        [bottomGlow.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:44.0],
        [bottomGlow.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-72.0]
    ]];

    self.backgroundGlowViewTop = topGlow;
    self.backgroundGlowViewBottom = bottomGlow;
}

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.currentDeviceCoordinate = kCLLocationCoordinate2DInvalid;
    self.reverseGeocoder = [[CLGeocoder alloc] init];
    self.countriesArray = CitiesManager.shared.countries ?: @[];
    self.resolvedCountry = [self pp_resolvedCountryForFormLoad];

    [self pp_prepareDraftState];
    [self pp_buildTableView];
    [self pp_setupBackdrop];
    [self pp_setupHeaderView];
    [self pp_applyCanvasBackground];
    [self pp_refreshHeaderContent];

    if (!self.address) {
        [self pp_applyResolvedCountryDefaultsIfNeeded];
        [self pp_startPrefillFromCurrentLocationIfNeeded];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.tableView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    [self pp_configureNavigationItems];
    [self pp_applyCanvasBackground];
    [self.tableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [PPHUD dismiss];
    [self.locationManager stopUpdatingLocation];
    [self.reverseGeocoder cancelGeocode];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];

    CGFloat headerWidth = CGRectGetWidth(self.tableView.bounds);
    if (headerWidth <= 0.0) {
        headerWidth = CGRectGetWidth(self.view.bounds);
    }

    CGRect headerBounds = self.headerRoot.bounds;
    if (ABS(headerBounds.size.width - headerWidth) > 0.5) {
        headerBounds.size.width = headerWidth;
        self.headerRoot.bounds = headerBounds;
    }

    [self.headerRoot setNeedsLayout];
    [self.headerRoot layoutIfNeeded];
    CGFloat headerHeight = [self.headerRoot systemLayoutSizeFittingSize:CGSizeMake(headerWidth, UILayoutFittingCompressedSize.height)
                                        withHorizontalFittingPriority:UILayoutPriorityRequired
                                              verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height;
    CGRect frame = self.headerRoot.frame;
    frame.size.width = headerWidth;
    frame.size.height = headerHeight;
    self.headerRoot.frame = frame;
    self.tableView.tableHeaderView = self.headerRoot;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    self.backgroundGlowViewTop.layer.cornerRadius = CGRectGetWidth(self.backgroundGlowViewTop.bounds) * 0.5;
    self.backgroundGlowViewBottom.layer.cornerRadius = CGRectGetWidth(self.backgroundGlowViewBottom.bounds) * 0.5;

    // Resize gradient accent bar layer to match its host view
    CAGradientLayer *gradient = (CAGradientLayer *)self.headerGradientBar.layer.sublayers.firstObject;
    if ([gradient isKindOfClass:CAGradientLayer.class]) {
        gradient.frame = self.headerGradientBar.bounds;
    }
}

#pragma mark - Setup

- (void)pp_buildTableView
{
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    tableView.translatesAutoresizingMaskIntoConstraints = NO;
    tableView.delegate = self;
    tableView.dataSource = self;
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    tableView.showsVerticalScrollIndicator = NO;
    tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    tableView.rowHeight = UITableViewAutomaticDimension;
    tableView.estimatedRowHeight = 84.0;
    tableView.contentInset = UIEdgeInsetsMake(6.0, 0.0, 28.0, 0.0);
    tableView.scrollIndicatorInsets = UIEdgeInsetsMake(6.0, 0.0, 28.0, 0.0);
    if (@available(iOS 15.0, *)) {
        tableView.sectionHeaderTopPadding = 0.0;
    }

    [tableView registerClass:PPAddressTextFieldCell.class forCellReuseIdentifier:@"PPAddressTextFieldCell"];
    [tableView registerClass:PPAddressSelectorCell.class forCellReuseIdentifier:@"PPAddressSelectorCell"];
    [tableView registerClass:PPAddressSwitchCell.class forCellReuseIdentifier:@"PPAddressSwitchCell"];
    [tableView registerClass:PPAddressActionCell.class forCellReuseIdentifier:@"PPAddressActionCell"];

    [self.view addSubview:tableView];
    [NSLayoutConstraint activateConstraints:@[
        [tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [tableView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [tableView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];

    self.tableView = tableView;
}

- (void)pp_setupHeaderView
{
    UIView *headerRoot = [[UIView alloc] init];
    headerRoot.backgroundColor = UIColor.clearColor;

    UIView *cardView = [[UIView alloc] init];
    cardView.translatesAutoresizingMaskIntoConstraints = NO;
    cardView.backgroundColor = [self pp_surfaceColor];
    cardView.layer.cornerRadius = 30.0;
    cardView.layer.borderWidth = 1.0;
    cardView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.68].CGColor;
    cardView.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:1.0].CGColor;
    cardView.layer.shadowOpacity = 0.08;
    cardView.layer.shadowRadius = 24.0;
    cardView.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    [headerRoot addSubview:cardView];

    UIView *tintView = [[UIView alloc] init];
    tintView.translatesAutoresizingMaskIntoConstraints = NO;
    tintView.backgroundColor = [[UIColor colorWithRed:0.99 green:0.96 blue:0.93 alpha:1.0] colorWithAlphaComponent:0.74];
    tintView.layer.cornerRadius = 30.0;
    tintView.layer.masksToBounds = YES;
    [cardView addSubview:tintView];

    UIColor *brandClr = AppPrimaryClr ?: UIColor.systemOrangeColor;

    UIView *ambientGlow = [[UIView alloc] init];
    ambientGlow.translatesAutoresizingMaskIntoConstraints = NO;
    ambientGlow.backgroundColor = [brandClr colorWithAlphaComponent:0.16];
    ambientGlow.userInteractionEnabled = NO;
    ambientGlow.layer.cornerRadius = 92.0;
    ambientGlow.layer.shadowColor = [brandClr colorWithAlphaComponent:0.58].CGColor;
    ambientGlow.layer.shadowOpacity = 0.18;
    ambientGlow.layer.shadowRadius = 42.0;
    ambientGlow.layer.shadowOffset = CGSizeZero;
    [cardView addSubview:ambientGlow];

    UIView *secondaryGlow = [[UIView alloc] init];
    secondaryGlow.translatesAutoresizingMaskIntoConstraints = NO;
    secondaryGlow.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.42];
    secondaryGlow.userInteractionEnabled = NO;
    secondaryGlow.layer.cornerRadius = 54.0;
    secondaryGlow.layer.shadowColor = [[UIColor whiteColor] colorWithAlphaComponent:0.45].CGColor;
    secondaryGlow.layer.shadowOpacity = 0.22;
    secondaryGlow.layer.shadowRadius = 24.0;
    secondaryGlow.layer.shadowOffset = CGSizeZero;
    [cardView addSubview:secondaryGlow];

    CAGradientLayer *accentGradient = [CAGradientLayer layer];
    accentGradient.colors = @[
        (id)[brandClr colorWithAlphaComponent:0.96].CGColor,
        (id)[[UIColor colorWithRed:0.99 green:0.77 blue:0.54 alpha:1.0] colorWithAlphaComponent:0.88].CGColor,
        (id)[[UIColor whiteColor] colorWithAlphaComponent:0.18].CGColor
    ];
    accentGradient.startPoint = CGPointMake(0.0, 0.5);
    accentGradient.endPoint = CGPointMake(1.0, 0.5);
    accentGradient.frame = CGRectMake(0.0, 0.0, 400.0, 6.0);
    accentGradient.cornerRadius = 3.0;

    UIView *gradientBar = [[UIView alloc] init];
    gradientBar.translatesAutoresizingMaskIntoConstraints = NO;
    gradientBar.layer.cornerRadius = 3.0;
    gradientBar.layer.masksToBounds = YES;
    [gradientBar.layer addSublayer:accentGradient];
    [cardView addSubview:gradientBar];

    UIView *iconBadge = [[UIView alloc] init];
    iconBadge.translatesAutoresizingMaskIntoConstraints = NO;
    iconBadge.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.66];
    iconBadge.layer.cornerRadius = 31.0;
    iconBadge.layer.masksToBounds = YES;
    iconBadge.layer.borderWidth = 1.0;
    iconBadge.layer.borderColor = [brandClr colorWithAlphaComponent:0.18].CGColor;
    iconBadge.layer.shadowColor = [brandClr colorWithAlphaComponent:0.35].CGColor;
    iconBadge.layer.shadowOpacity = 0.18;
    iconBadge.layer.shadowRadius = 18.0;
    iconBadge.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    [cardView addSubview:iconBadge];

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"mappin.and.ellipse"]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = brandClr;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [iconBadge addSubview:iconView];

    UIView *eyebrowPill = [[UIView alloc] init];
    eyebrowPill.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowPill.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.72];
    eyebrowPill.layer.cornerRadius = 14.0;
    eyebrowPill.layer.masksToBounds = YES;
    eyebrowPill.layer.borderWidth = 1.0;
    eyebrowPill.layer.borderColor = [brandClr colorWithAlphaComponent:0.10].CGColor;
    [cardView addSubview:eyebrowPill];

    UILabel *eyebrowLabel = [[UILabel alloc] init];
    eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowLabel.font = [GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    eyebrowLabel.textColor = [brandClr colorWithAlphaComponent:0.92];
    eyebrowLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [eyebrowPill addSubview:eyebrowLabel];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:29.0] ?: [UIFont systemFontOfSize:29.0 weight:UIFontWeightBold];
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.numberOfLines = 2;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [cardView addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    subtitleLabel.textColor = [[UIColor secondaryLabelColor] colorWithAlphaComponent:0.92];
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [cardView addSubview:subtitleLabel];

    UILabel *metaLabel = [[UILabel alloc] init];
    metaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    metaLabel.font = [GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    metaLabel.textColor = brandClr;
    metaLabel.numberOfLines = 2;
    metaLabel.textAlignment = Language.alignmentForCurrentLanguage;
    metaLabel.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.78];
    metaLabel.layer.cornerRadius = 17.0;
    metaLabel.layer.masksToBounds = YES;
    metaLabel.layer.borderWidth = 1.0;
    metaLabel.layer.borderColor = [brandClr colorWithAlphaComponent:0.14].CGColor;
    [cardView addSubview:metaLabel];

    [NSLayoutConstraint activateConstraints:@[
        [cardView.topAnchor constraintEqualToAnchor:headerRoot.topAnchor constant:10.0],
        [cardView.leadingAnchor constraintEqualToAnchor:headerRoot.leadingAnchor constant:16.0],
        [cardView.trailingAnchor constraintEqualToAnchor:headerRoot.trailingAnchor constant:-16.0],
        [cardView.bottomAnchor constraintEqualToAnchor:headerRoot.bottomAnchor constant:-14.0],

        [tintView.topAnchor constraintEqualToAnchor:cardView.topAnchor],
        [tintView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor],
        [tintView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor],
        [tintView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor],

        [ambientGlow.widthAnchor constraintEqualToConstant:184.0],
        [ambientGlow.heightAnchor constraintEqualToConstant:184.0],
        [ambientGlow.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:-72.0],
        [ambientGlow.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:76.0],

        [secondaryGlow.widthAnchor constraintEqualToConstant:108.0],
        [secondaryGlow.heightAnchor constraintEqualToConstant:108.0],
        [secondaryGlow.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:36.0],
        [secondaryGlow.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:-36.0],

        [gradientBar.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:20.0],
        [gradientBar.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:24.0],
        [gradientBar.widthAnchor constraintEqualToConstant:72.0],
        [gradientBar.heightAnchor constraintEqualToConstant:6.0],

        [iconBadge.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:24.0],
        [iconBadge.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-24.0],
        [iconBadge.widthAnchor constraintEqualToConstant:62.0],
        [iconBadge.heightAnchor constraintEqualToConstant:62.0],

        [iconView.centerXAnchor constraintEqualToAnchor:iconBadge.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconBadge.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:28.0],
        [iconView.heightAnchor constraintEqualToConstant:28.0],

        [eyebrowPill.topAnchor constraintEqualToAnchor:gradientBar.bottomAnchor constant:16.0],
        [eyebrowPill.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:24.0],
        [eyebrowPill.trailingAnchor constraintLessThanOrEqualToAnchor:iconBadge.leadingAnchor constant:-16.0],
        [eyebrowPill.heightAnchor constraintGreaterThanOrEqualToConstant:28.0],

        [eyebrowLabel.topAnchor constraintEqualToAnchor:eyebrowPill.topAnchor constant:6.0],
        [eyebrowLabel.leadingAnchor constraintEqualToAnchor:eyebrowPill.leadingAnchor constant:12.0],
        [eyebrowLabel.trailingAnchor constraintEqualToAnchor:eyebrowPill.trailingAnchor constant:-12.0],
        [eyebrowLabel.bottomAnchor constraintEqualToAnchor:eyebrowPill.bottomAnchor constant:-6.0],

        [titleLabel.topAnchor constraintEqualToAnchor:eyebrowPill.bottomAnchor constant:18.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:24.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-24.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:12.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],

        [metaLabel.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:18.0],
        [metaLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [metaLabel.trailingAnchor constraintLessThanOrEqualToAnchor:titleLabel.trailingAnchor],
        [metaLabel.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-24.0],
        [metaLabel.heightAnchor constraintGreaterThanOrEqualToConstant:34.0]
    ]];

    self.headerRoot = headerRoot;
    self.headerCardView = cardView;
    self.headerGradientBar = gradientBar;
    self.headerEyebrowLabel = eyebrowLabel;
    self.headerTitleLabel = titleLabel;
    self.headerSubtitleLabel = subtitleLabel;
    self.headerMetaLabel = metaLabel;

    CGSize fittingSize = [headerRoot systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    headerRoot.frame = CGRectMake(0.0, 0.0, CGRectGetWidth(self.view.bounds), fittingSize.height);
    self.tableView.tableHeaderView = headerRoot;
}

- (void)pp_prepareDraftState
{
    NSString *preferredName = self.address.fullName.length > 0
        ? self.address.fullName
        : (PPCurrentUser.UserName.length > 0 ? PPCurrentUser.UserName : ([FIRAuth auth].currentUser.displayName ?: @""));
    NSString *preferredPhone = self.address.phoneNumber.length > 0
        ? self.address.phoneNumber
        : (PPCurrentUser.MobileNo.length > 0 ? PPCurrentUser.MobileNo : ([FIRAuth auth].currentUser.phoneNumber ?: @""));

    self.draftFullName = [self pp_trimmedString:preferredName];
    self.draftPhoneNumber = [self pp_trimmedString:preferredPhone];
    self.draftAddressLine1 = [self pp_trimmedString:self.address.addressLine1];
    self.draftAddressLine2 = [self pp_trimmedString:self.address.addressLine2];
    self.draftPostalCode = [self pp_trimmedString:self.address.postalCode];
    self.draftIsDefault = self.address ? self.address.isDefault : (!self.address && PPCurrentUser.Addresses.count == 0);
    self.selectedLocationName = [self pp_trimmedString:self.address.locatioName];
    self.selectedLocationPoints = [self pp_trimmedString:self.address.locationPoints];

    if (self.address) {
        self.selectedCity = [CitiesManager.shared cityByID:self.address.cityID];
        self.selectedState = [CitiesManager.shared stateByID:self.address.stateID];
        self.selectedCountry = self.selectedCity.country ?: self.resolvedCountry ?: [self pp_qatarCountry];
        [self pp_applyCountry:self.selectedCountry preferredCity:self.selectedCity preferredState:self.selectedState];
    } else {
        self.selectedCountry = self.resolvedCountry ?: [self pp_qatarCountry];
        self.citiesArray = [self pp_citiesForCountryOrQatar:self.selectedCountry];
        self.statesArray = @[];
    }
}
 
- (void)pp_configureNavigationItems
{
    NSString *screenTitle = self.address ? (kLang(@"EditAddress") ?: @"Edit address") : (kLang(@"AddAddress") ?: @"Add address");
    self.navigationItem.title = screenTitle;

    NSString *leadingImageName = self.addressFormPresent == AddressFormPresentSheet
        ? @"xmark"
        : (PPChevronName ?: @"chevron.backward");
    self.leadingBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:leadingImageName]
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:@selector(pp_handleLeadingAction)];
    
    UIButton *sav = [PPButtonHelper pp_buttonWithTitle:kLang(@"Save") font:[GM fontWithSize:17] imageName:@"" target:self config:[UIButtonConfiguration tintedButtonConfiguration] action:@selector(saveButtonPressed:)];
    self.saveBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:sav];

    self.navigationItem.leftBarButtonItem = self.leadingBarButtonItem;
    self.navigationItem.rightBarButtonItem = self.saveBarButtonItem;
    [self pp_setSavingState:self.isSaving];
}

- (void)pp_handleLeadingAction
{
    if (self.addressFormPresent == AddressFormPresentSheet) {
        if (self.navigationController.presentingViewController) {
            [self.navigationController dismissViewControllerAnimated:YES completion:nil];
        } else {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
        return;
    }

    if (self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (NSString *)pp_formTitleText
{
    return self.address
        ? [self pp_localizedAddressStringForKey:@"EditAddress" fallback:@"Edit address"]
        : [self pp_localizedAddressStringForKey:@"AddAddress" fallback:@"Add address"];
}

- (NSString *)pp_formSubtitleText
{
    if (self.address) {
        return [self pp_localizedAddressStringForKey:@"AddressFormEditSubtitle"
                                            fallback:@"Update your delivery details, map pin, and checkout preferences."];
    }
    return [self pp_localizedAddressStringForKey:@"AddressFormAddSubtitle"
                                        fallback:@"Create a delivery address with the right country, city, area, and map pin."];
}

- (NSString *)pp_headerMetaText
{
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    NSString *cityName = [self pp_localizedCityName:self.selectedCity];
    NSString *countryName = [self pp_localizedCountryName:self.selectedCountry];
    if (cityName.length > 0) {
        [parts addObject:cityName];
    }
    if (countryName.length > 0) {
        [parts addObject:countryName];
    }
    if (parts.count > 0) {
        return [parts componentsJoinedByString:@"  •  "];
    }
    if (self.selectedLocationName.length > 0) {
        return self.selectedLocationName;
    }
    return [self pp_localizedAddressStringForKey:@"AddressHeroMetaFallback" fallback:@"Delivery details ready"];
}

- (void)pp_refreshHeaderContent
{
    self.headerEyebrowLabel.text = [self pp_localizedAddressStringForKey:@"AddressHeroEyebrow" fallback:@"Delivery destination"];
    self.headerTitleLabel.text = [self pp_formTitleText];
    self.headerSubtitleLabel.text = [self pp_formSubtitleText];

    NSString *metaText = [self pp_headerMetaText];
    self.headerMetaLabel.text = metaText.length > 0 ? [NSString stringWithFormat:@"  %@  ", metaText] : @"";
}

#pragma mark - Data Helpers

- (NSString *)pp_trimmedString:(id)value
{
    if (![value isKindOfClass:NSString.class]) {
        return @"";
    }
    return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (CountryModel *)pp_qatarCountry
{
    return [CitiesManager.shared qatarCountry];
}

- (NSArray<CountryModel *> *)pp_availableCountries
{
    NSArray<CountryModel *> *countries = self.countriesArray ?: CitiesManager.shared.countries;
    if (countries.count > 0) {
        return countries;
    }
    CountryModel *fallback = [self pp_qatarCountry];
    return fallback ? @[fallback] : @[];
}

- (NSString *)pp_localizedCountryName:(CountryModel *)country
{
    if (![country isKindOfClass:CountryModel.class]) {
        return @"";
    }
    if (Language.isRTL && country.arName.length > 0) {
        return country.arName;
    }
    if (country.enName.length > 0) {
        return country.enName;
    }
    return country.name ?: @"";
}

- (NSString *)pp_localizedCityName:(CityModel *)city
{
    if (![city isKindOfClass:CityModel.class]) {
        return @"";
    }
    if (Language.isRTL && city.arName.length > 0) {
        return city.arName;
    }
    if (city.enName.length > 0) {
        return city.enName;
    }
    return city.name ?: @"";
}

- (NSString *)pp_localizedStateName:(StateModel *)state
{
    if (![state isKindOfClass:StateModel.class]) {
        return @"";
    }
    if (Language.isRTL && state.arName.length > 0) {
        return state.arName;
    }
    return state.enName ?: @"";
}

- (NSArray<CityModel *> *)pp_citiesForCountryOrQatar:(CountryModel *)country
{
    NSArray<CityModel *> *cities = country.cities ?: @[];
    if (cities.count > 0) {
        return cities;
    }
    return [self pp_qatarCountry].cities ?: @[];
}

- (CountryModel *)pp_countryFromUserCountryID:(NSInteger)countryID
{
    if (countryID <= 0) {
        return nil;
    }

    NSArray<CountryCodeModel *> *countries = [GM getMiddleEastCountriesForLanguage:[Language currentLanguageCode]];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.ID == %ld", countryID];
    CountryCodeModel *matchedCountry = [[countries filteredArrayUsingPredicate:predicate] firstObject];
    if (matchedCountry.isoCountryCode.length == 0) {
        return nil;
    }
    return [CitiesManager.shared countryWithCode:matchedCountry.isoCountryCode];
}

- (CountryModel *)pp_countryFromPhoneNumber:(NSString *)phoneNumber
{
    NSString *trimmedPhone = [self pp_trimmedString:phoneNumber];
    if (trimmedPhone.length == 0 || ![trimmedPhone hasPrefix:@"+"]) {
        return nil;
    }

    CountryModel *best = nil;
    NSUInteger bestLength = 0;
    for (CountryModel *country in CitiesManager.shared.countries ?: @[]) {
        NSString *dialCode = [self pp_trimmedString:country.countryCode];
        if (dialCode.length == 0) {
            continue;
        }
        if (![dialCode hasPrefix:@"+"]) {
            dialCode = [@"+" stringByAppendingString:dialCode];
        }
        if ([trimmedPhone hasPrefix:dialCode] && dialCode.length > bestLength) {
            best = country;
            bestLength = dialCode.length;
        }
    }
    return best;
}

- (CountryModel *)pp_resolvedCountryForFormLoad
{
    if (self.address.cityID > 0) {
        CityModel *addressCity = [CitiesManager.shared cityByID:self.address.cityID];
        if (addressCity.country) {
            return addressCity.country;
        }
    }

    CountryModel *country = [self pp_countryFromUserCountryID:PPCurrentUser.CountryID];
    if (!country) {
        country = [self pp_countryFromPhoneNumber:PPCurrentUser.MobileNo];
    }
    if (!country) {
        country = [self pp_countryFromPhoneNumber:[FIRAuth auth].currentUser.phoneNumber];
    }
    if (!country) {
        country = [CitiesManager.shared countryWithCode:[GM getCurrentCountryFromCarrier]];
    }
    if (!country) {
        country = [CitiesManager.shared countryWithCode:[[NSLocale currentLocale] objectForKey:NSLocaleCountryCode]];
    }
    if (!country) {
        country = CitiesManager.shared.CurrentCountry;
    }
    return country ?: [self pp_qatarCountry];
}

- (void)pp_applyResolvedCountryDefaultsIfNeeded
{
    CountryModel *country = self.resolvedCountry ?: [self pp_qatarCountry];
    [self pp_applyCountry:country preferredCity:self.selectedCity preferredState:self.selectedState];
}

- (NSString *)pp_normalizedComparableName:(NSString *)value
{
    NSString *trimmed = [[self pp_trimmedString:value] lowercaseString];
    if (trimmed.length == 0) {
        return @"";
    }

    NSCharacterSet *stripSet = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
    NSArray<NSString *> *parts = [trimmed componentsSeparatedByCharactersInSet:stripSet];
    return [[parts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]] componentsJoinedByString:@""];
}

- (CityModel *)pp_cityMatchingPlacemark:(CLPlacemark *)placemark inCities:(NSArray<CityModel *> *)cities
{
    NSArray<NSString *> *candidateNames = @[
        placemark.locality ?: @"",
        placemark.subAdministrativeArea ?: @"",
        placemark.administrativeArea ?: @"",
    ];

    for (NSString *candidateName in candidateNames) {
        NSString *normalizedCandidate = [self pp_normalizedComparableName:candidateName];
        if (normalizedCandidate.length == 0) {
            continue;
        }

        for (CityModel *city in cities ?: @[]) {
            NSArray<NSString *> *cityNames = @[city.enName ?: @"", city.arName ?: @""];
            for (NSString *cityName in cityNames) {
                NSString *normalizedCity = [self pp_normalizedComparableName:cityName];
                if (normalizedCity.length == 0) {
                    continue;
                }
                if ([normalizedCandidate isEqualToString:normalizedCity] ||
                    [normalizedCandidate containsString:normalizedCity] ||
                    [normalizedCity containsString:normalizedCandidate]) {
                    return city;
                }
            }
        }
    }

    return nil;
}

- (StateModel *)pp_stateMatchingPlacemark:(CLPlacemark *)placemark inStates:(NSArray<StateModel *> *)states
{
    NSArray<NSString *> *candidateNames = @[
        placemark.subLocality ?: @"",
        placemark.thoroughfare ?: @"",
        placemark.name ?: @"",
    ];

    for (NSString *candidateName in candidateNames) {
        NSString *normalizedCandidate = [self pp_normalizedComparableName:candidateName];
        if (normalizedCandidate.length == 0) {
            continue;
        }

        for (StateModel *state in states ?: @[]) {
            NSArray<NSString *> *stateNames = @[state.enName ?: @"", state.arName ?: @""];
            for (NSString *stateName in stateNames) {
                NSString *normalizedState = [self pp_normalizedComparableName:stateName];
                if (normalizedState.length == 0) {
                    continue;
                }
                if ([normalizedCandidate isEqualToString:normalizedState] ||
                    [normalizedCandidate containsString:normalizedState] ||
                    [normalizedState containsString:normalizedCandidate]) {
                    return state;
                }
            }
        }
    }

    return nil;
}

- (BOOL)pp_isValidCoordinate:(CLLocationCoordinate2D)coordinate
{
    if (!CLLocationCoordinate2DIsValid(coordinate)) {
        return NO;
    }
    return !(fabs(coordinate.latitude) < 0.000001 && fabs(coordinate.longitude) < 0.000001);
}

- (CityModel *)pp_nearestCityForCoordinate:(CLLocationCoordinate2D)coordinate
{
    if (![self pp_isValidCoordinate:coordinate]) {
        return nil;
    }

    NSArray<CityModel *> *cities = self.citiesArray ?: @[];
    if (cities.count == 0) {
        cities = [self pp_citiesForCountryOrQatar:self.resolvedCountry];
    }
    if (cities.count == 0) {
        return nil;
    }

    CLLocation *target = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
    CityModel *nearestCity = nil;
    CLLocationDistance bestDistance = DBL_MAX;

    for (CityModel *city in cities) {
        CLLocationCoordinate2D cityCoordinate = CLLocationCoordinate2DMake(city.latitude, city.longitude);
        if (![self pp_isValidCoordinate:cityCoordinate]) {
            continue;
        }

        CLLocation *cityLocation = [[CLLocation alloc] initWithLatitude:cityCoordinate.latitude longitude:cityCoordinate.longitude];
        CLLocationDistance distance = [target distanceFromLocation:cityLocation];
        if (distance < bestDistance) {
            bestDistance = distance;
            nearestCity = city;
        }
    }

    return nearestCity ?: cities.firstObject;
}

- (StateModel *)pp_defaultStateForCity:(CityModel *)city
{
    if (![city isKindOfClass:CityModel.class]) {
        return nil;
    }
    return city.states.firstObject;
}

- (void)pp_reloadRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    if (!self.isViewLoaded || !self.tableView) {
        return;
    }

    NSArray<NSIndexPath *> *safeRows = [indexPaths filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSIndexPath *evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return [self.tableView numberOfSections] > evaluatedObject.section &&
        [self.tableView numberOfRowsInSection:evaluatedObject.section] > evaluatedObject.row;
    }]];
    if (safeRows.count == 0) {
        [self.tableView reloadData];
        return;
    }
    [self.tableView reloadRowsAtIndexPaths:safeRows withRowAnimation:UITableViewRowAnimationNone];
}

- (NSIndexPath *)pp_indexPathForFieldKind:(PPAddressFieldKind)fieldKind
{
    switch (fieldKind) {
        case PPAddressFieldKindFullName:
            return [NSIndexPath indexPathForRow:0 inSection:0];
        case PPAddressFieldKindPhoneNumber:
            return [NSIndexPath indexPathForRow:1 inSection:0];
        case PPAddressFieldKindAddressLine1:
            return [NSIndexPath indexPathForRow:0 inSection:1];
        case PPAddressFieldKindAddressLine2:
            return [NSIndexPath indexPathForRow:1 inSection:1];
        case PPAddressFieldKindPostalCode:
            return [NSIndexPath indexPathForRow:2 inSection:1];
        case PPAddressFieldKindCountry:
            return [NSIndexPath indexPathForRow:0 inSection:2];
        case PPAddressFieldKindCity:
            return [NSIndexPath indexPathForRow:1 inSection:2];
        case PPAddressFieldKindState:
            return [NSIndexPath indexPathForRow:2 inSection:2];
        case PPAddressFieldKindLocation:
            return [NSIndexPath indexPathForRow:3 inSection:2];
    }
}

- (void)pp_reloadGeographyRows
{
    [self pp_reloadRowsAtIndexPaths:@[
        [self pp_indexPathForFieldKind:PPAddressFieldKindCountry],
        [self pp_indexPathForFieldKind:PPAddressFieldKindCity],
        [self pp_indexPathForFieldKind:PPAddressFieldKindState],
        [self pp_indexPathForFieldKind:PPAddressFieldKindLocation]
    ]];
}

- (void)pp_applyCountry:(CountryModel *)country
          preferredCity:(CityModel *)preferredCity
         preferredState:(StateModel *)preferredState
{
    CountryModel *resolvedCountry = [country isKindOfClass:CountryModel.class] ? country : [self pp_qatarCountry];
    self.resolvedCountry = resolvedCountry;
    self.selectedCountry = resolvedCountry;
    self.countriesArray = [self pp_availableCountries];
    self.citiesArray = [self pp_citiesForCountryOrQatar:resolvedCountry];

    CityModel *resolvedCity = preferredCity;
    if (![resolvedCity isKindOfClass:CityModel.class] || ![self.citiesArray containsObject:resolvedCity]) {
        resolvedCity = [CitiesManager.shared defaultCityForCountry:resolvedCountry];
    }
    if (![resolvedCity isKindOfClass:CityModel.class]) {
        resolvedCity = self.citiesArray.firstObject;
    }
    if (![resolvedCity isKindOfClass:CityModel.class]) {
        self.selectedCity = nil;
        self.statesArray = @[];
        self.selectedState = nil;
        [self pp_reloadGeographyRows];
        [self pp_refreshHeaderContent];
        return;
    }

    [self pp_applyCity:resolvedCity state:preferredState];
}

- (void)pp_applyCity:(CityModel *)city state:(StateModel *)state
{
    if (![city isKindOfClass:CityModel.class]) {
        return;
    }

    self.resolvedCountry = city.country ?: self.resolvedCountry ?: [self pp_qatarCountry];
    self.selectedCountry = self.resolvedCountry;
    self.countriesArray = [self pp_availableCountries];
    self.citiesArray = [self pp_citiesForCountryOrQatar:self.resolvedCountry];
    self.selectedCity = city;
    self.statesArray = city.states ?: @[];

    StateModel *resolvedState = state;
    if (![resolvedState isKindOfClass:StateModel.class] || ![self.statesArray containsObject:resolvedState]) {
        resolvedState = [self pp_defaultStateForCity:city];
    }
    self.selectedState = resolvedState;

    [self pp_reloadGeographyRows];
    [self pp_refreshHeaderContent];
}

- (void)pp_applyCoordinateToForm:(CLLocationCoordinate2D)coordinate
                   suggestedTitle:(NSString *)suggestedTitle
{
    if (![self pp_isValidCoordinate:coordinate]) {
        return;
    }

    self.didApplyInitialLocation = YES;
    self.currentDeviceCoordinate = coordinate;
    self.selectedLocationPoints = [NSString stringWithFormat:@"%f, %f", coordinate.latitude, coordinate.longitude];
    self.selectedLocationName = suggestedTitle.length > 0
        ? suggestedTitle
        : [NSString stringWithFormat:@"%.6f, %.6f", coordinate.latitude, coordinate.longitude];

    CityModel *nearestCity = [self pp_nearestCityForCoordinate:coordinate];
    if (nearestCity) {
        [self pp_applyCity:nearestCity state:[self pp_defaultStateForCity:nearestCity]];
    } else {
        [self pp_reloadRowsAtIndexPaths:@[[self pp_indexPathForFieldKind:PPAddressFieldKindLocation]]];
        [self pp_refreshHeaderContent];
    }
}

- (NSString *)pp_titleFromPlacemark:(CLPlacemark *)placemark
{
    if (!placemark) {
        return @"";
    }

    NSString *primary = placemark.subLocality ?: placemark.locality ?: placemark.thoroughfare ?: @"";
    NSString *secondary = placemark.locality ?: placemark.administrativeArea ?: placemark.country ?: @"";
    if ([primary isEqualToString:secondary]) {
        secondary = @"";
    }
    if (primary.length > 0 && secondary.length > 0) {
        return [NSString stringWithFormat:@"%@, %@", primary, secondary];
    }
    return primary.length > 0 ? primary : secondary;
}

- (NSString *)titleFromAddress:(GMSAddress *)address
{
    if (!address) {
        return @"";
    }

    NSString *primary = address.subLocality ?: address.locality ?: address.thoroughfare ?: @"";
    NSString *secondary = address.locality ?: address.administrativeArea ?: address.country ?: @"";
    if ([primary isEqualToString:secondary]) {
        secondary = @"";
    }
    if (primary.length > 0 && secondary.length > 0) {
        return [NSString stringWithFormat:@"%@, %@", primary, secondary];
    }
    return primary.length > 0 ? primary : secondary;
}

- (void)pp_reverseGeocodeCoordinateForRowTitle:(CLLocationCoordinate2D)coordinate
{
    if (![self pp_isValidCoordinate:coordinate]) {
        return;
    }
    if (!self.reverseGeocoder) {
        self.reverseGeocoder = [[CLGeocoder alloc] init];
    }
    if (self.reverseGeocoder.isGeocoding) {
        [self.reverseGeocoder cancelGeocode];
    }

    CLLocation *location = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
    __weak typeof(self) weakSelf = self;
    [self.reverseGeocoder reverseGeocodeLocation:location completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
        if (error || placemarks.count == 0) {
            return;
        }

        CLPlacemark *placemark = placemarks.firstObject;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }

            CountryModel *placemarkCountry = [CitiesManager.shared countryWithCode:placemark.ISOcountryCode];
            if (!placemarkCountry) {
                placemarkCountry = self.resolvedCountry ?: [self pp_qatarCountry];
            }
            self.resolvedCountry = placemarkCountry ?: [self pp_qatarCountry];
            self.selectedCountry = self.resolvedCountry;
            self.citiesArray = [self pp_citiesForCountryOrQatar:self.resolvedCountry];

            CityModel *matchedCity = [self pp_cityMatchingPlacemark:placemark inCities:self.citiesArray];
            if (!matchedCity) {
                matchedCity = [self pp_nearestCityForCoordinate:coordinate];
            }
            if (matchedCity) {
                StateModel *matchedState = [self pp_stateMatchingPlacemark:placemark inStates:matchedCity.states];
                [self pp_applyCity:matchedCity state:matchedState];
            }

            NSString *resolvedTitle = [self pp_titleFromPlacemark:placemark];
            if (resolvedTitle.length == 0 && matchedCity) {
                resolvedTitle = [self pp_localizedCityName:matchedCity];
            }
            if (resolvedTitle.length == 0 && self.resolvedCountry) {
                resolvedTitle = [self pp_localizedCountryName:self.resolvedCountry];
            }
            if (resolvedTitle.length > 0) {
                self.selectedLocationName = resolvedTitle;
            }

            [self pp_reloadGeographyRows];
            [self pp_refreshHeaderContent];
        });
    }];
}

- (void)pp_openLocationPicker
{
    LocationPickerViewController *pickerVC = [[LocationPickerViewController alloc] init];
    CLLocationCoordinate2D initialCoordinate = kCLLocationCoordinate2DInvalid;
    if (self.selectedLocationPoints.length > 0) {
        NSArray<NSString *> *parts = [self.selectedLocationPoints componentsSeparatedByString:@","];
        if (parts.count >= 2) {
            double latitude = [parts[0] doubleValue];
            double longitude = [parts[1] doubleValue];
            CLLocationCoordinate2D parsed = CLLocationCoordinate2DMake(latitude, longitude);
            if ([self pp_isValidCoordinate:parsed]) {
                initialCoordinate = parsed;
            }
        }
    }
    if (![self pp_isValidCoordinate:initialCoordinate] && [self pp_isValidCoordinate:self.currentDeviceCoordinate]) {
        initialCoordinate = self.currentDeviceCoordinate;
    }
    if ([self pp_isValidCoordinate:initialCoordinate]) {
        pickerVC.initialCoordinate = initialCoordinate;
    }

    __weak typeof(self) weakSelf = self;
    pickerVC.onLocationConfirmed = ^(GMSAddress *gmsAddress) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !gmsAddress) {
            return;
        }

        CLLocationCoordinate2D coordinate = gmsAddress.coordinate;
        NSString *resolvedTitle = [self titleFromAddress:gmsAddress];
        [self pp_applyCoordinateToForm:coordinate suggestedTitle:resolvedTitle];
        [self pp_reverseGeocodeCoordinateForRowTitle:coordinate];
    };
    pickerVC.onCoordinateConfirmed = ^(CLLocationCoordinate2D coordinate, NSString *locationTitle) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        [self pp_applyCoordinateToForm:coordinate suggestedTitle:locationTitle];
        [self pp_reverseGeocodeCoordinateForRowTitle:coordinate];
    };

    if (self.navigationController) {
        [self.navigationController pushViewController:pickerVC animated:YES];
    } else {
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:pickerVC];
        [self presentViewController:navigationController animated:YES completion:nil];
    }
}

- (void)pp_pushOptionsControllerWithTitle:(NSString *)title
                                  options:(NSArray *)options
                           selectedOption:(id)selectedOption
                            titleProvider:(NSString * _Nonnull (^)(id option))titleProvider
                         selectionHandler:(void (^)(id option))selectionHandler
{
    PPAddressOptionsViewController *controller = [[PPAddressOptionsViewController alloc] initWithTitle:title
                                                                                                options:options
                                                                                         selectedOption:selectedOption
                                                                                          titleProvider:titleProvider
                                                                                       selectionHandler:selectionHandler];
    if (self.navigationController) {
        [self.navigationController pushViewController:controller animated:YES];
    } else {
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:controller];
        [self presentViewController:navigationController animated:YES completion:nil];
    }
}

- (void)pp_presentCountryOptions
{
    NSArray<CountryModel *> *options = [self pp_availableCountries];
    if (options.count == 0) {
        [PPHUD showInfo:kLang(@"TapToSelect") ?: @"No countries available"];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [self pp_pushOptionsControllerWithTitle:kLang(@"Country") ?: @"Country"
                                    options:options
                             selectedOption:self.selectedCountry
                              titleProvider:^NSString * _Nonnull(CountryModel *option) {
        return [weakSelf pp_localizedCountryName:option];
    } selectionHandler:^(CountryModel *option) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || ![option isKindOfClass:CountryModel.class]) {
            return;
        }
        [self pp_applyCountry:option preferredCity:nil preferredState:nil];
    }];
}

- (void)pp_presentCityOptions
{
    if (!self.selectedCountry) {
        [PPHUD showInfo:kLang(@"TapToSelect") ?: @"Select a country first"];
        return;
    }
    if (self.citiesArray.count == 0) {
        self.citiesArray = [self pp_citiesForCountryOrQatar:self.selectedCountry];
    }
    if (self.citiesArray.count == 0) {
        [PPHUD showInfo:kLang(@"TapToSelect") ?: @"No cities available"];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [self pp_pushOptionsControllerWithTitle:kLang(@"City") ?: @"City"
                                    options:self.citiesArray
                             selectedOption:self.selectedCity
                              titleProvider:^NSString * _Nonnull(CityModel *option) {
        return [weakSelf pp_localizedCityName:option];
    } selectionHandler:^(CityModel *option) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || ![option isKindOfClass:CityModel.class]) {
            return;
        }
        [self pp_applyCity:option state:nil];
    }];
}

- (void)pp_presentStateOptions
{
    if (!self.selectedCity) {
        [PPHUD showInfo:kLang(@"TapToSelect") ?: @"Select a city first"];
        return;
    }
    if (self.statesArray.count == 0) {
        self.statesArray = self.selectedCity.states ?: @[];
    }
    if (self.statesArray.count == 0) {
        [PPHUD showInfo:kLang(@"TapToSelect") ?: @"No areas available"];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [self pp_pushOptionsControllerWithTitle:kLang(@"State") ?: @"State"
                                    options:self.statesArray
                             selectedOption:self.selectedState
                              titleProvider:^NSString * _Nonnull(StateModel *option) {
        return [weakSelf pp_localizedStateName:option];
    } selectionHandler:^(StateModel *option) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || ![option isKindOfClass:StateModel.class]) {
            return;
        }
        self.selectedState = option;
        [self pp_reloadRowsAtIndexPaths:@[[self pp_indexPathForFieldKind:PPAddressFieldKindState]]];
    }];
}

#pragma mark - Table Structure

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return self.address ? 5 : 4;
}

- (PPAddressSectionKind)pp_sectionKindForSection:(NSInteger)section
{
    switch (section) {
        case 0:
            return PPAddressSectionKindRecipient;
        case 1:
            return PPAddressSectionKindStreet;
        case 2:
            return PPAddressSectionKindGeography;
        case 3:
            return PPAddressSectionKindPreferences;
        default:
            return PPAddressSectionKindDanger;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch ([self pp_sectionKindForSection:section]) {
        case PPAddressSectionKindRecipient:
            return 2;
        case PPAddressSectionKindStreet:
            return 3;
        case PPAddressSectionKindGeography:
            return 4;
        case PPAddressSectionKindPreferences:
            return 1;
        case PPAddressSectionKindDanger:
            return self.address ? 1 : 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch ([self pp_sectionKindForSection:indexPath.section]) {
        case PPAddressSectionKindRecipient: {
            PPAddressTextFieldCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPAddressTextFieldCell" forIndexPath:indexPath];
            if (indexPath.row == 0) {
                [cell configureWithTitle:kLang(@"FullName") ?: @"Full name"
                                    text:self.draftFullName
                             placeholder:kLang(@"FullNamePlaceholder") ?: @"Who should receive this order?"
                            keyboardType:UIKeyboardTypeDefault
                         textContentType:UITextContentTypeName
                           returnKeyType:UIReturnKeyNext
                  autocapitalizationType:UITextAutocapitalizationTypeWords
                               fieldKind:PPAddressFieldKindFullName
                                  target:self
                                  action:@selector(pp_textFieldEditingChanged:)
                                delegate:self];
            } else {
                [cell configureWithTitle:kLang(@"MobileNo_Palce") ?: @"Phone number"
                                    text:self.draftPhoneNumber
                             placeholder:kLang(@"MobileNo_Palce") ?: @"Add a reachable phone number"
                            keyboardType:UIKeyboardTypePhonePad
                         textContentType:UITextContentTypeTelephoneNumber
                           returnKeyType:UIReturnKeyNext
                  autocapitalizationType:UITextAutocapitalizationTypeNone
                               fieldKind:PPAddressFieldKindPhoneNumber
                                  target:self
                                  action:@selector(pp_textFieldEditingChanged:)
                                delegate:self];
            }
            return cell;
        }

        case PPAddressSectionKindStreet: {
            PPAddressTextFieldCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPAddressTextFieldCell" forIndexPath:indexPath];
            if (indexPath.row == 0) {
                [cell configureWithTitle:kLang(@"AddressLine1") ?: @"Address line 1"
                                    text:self.draftAddressLine1
                             placeholder:kLang(@"AddressLine1Placeholder") ?: @"Street, building, or house number"
                            keyboardType:UIKeyboardTypeDefault
                         textContentType:UITextContentTypeFullStreetAddress
                           returnKeyType:UIReturnKeyNext
                  autocapitalizationType:UITextAutocapitalizationTypeWords
                               fieldKind:PPAddressFieldKindAddressLine1
                                  target:self
                                  action:@selector(pp_textFieldEditingChanged:)
                                delegate:self];
            } else if (indexPath.row == 1) {
                [cell configureWithTitle:kLang(@"AddressLine2Optional") ?: @"Address line 2"
                                    text:self.draftAddressLine2
                             placeholder:kLang(@"AddressLine2Placeholder") ?: @"Apartment, suite, landmark, or notes"
                            keyboardType:UIKeyboardTypeDefault
                         textContentType:UITextContentTypeFullStreetAddress
                           returnKeyType:UIReturnKeyNext
                  autocapitalizationType:UITextAutocapitalizationTypeWords
                               fieldKind:PPAddressFieldKindAddressLine2
                                  target:self
                                  action:@selector(pp_textFieldEditingChanged:)
                                delegate:self];
            } else {
                [cell configureWithTitle:kLang(@"PostalCode") ?: @"Postal code"
                                    text:self.draftPostalCode
                             placeholder:kLang(@"PostalCodePlaceholder") ?: @"Postal or zip code"
                            keyboardType:UIKeyboardTypeDefault
                         textContentType:UITextContentTypePostalCode
                           returnKeyType:UIReturnKeyDone
                  autocapitalizationType:UITextAutocapitalizationTypeNone
                               fieldKind:PPAddressFieldKindPostalCode
                                  target:self
                                  action:@selector(pp_textFieldEditingChanged:)
                                delegate:self];
            }
            return cell;
        }

        case PPAddressSectionKindGeography: {
            PPAddressSelectorCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPAddressSelectorCell" forIndexPath:indexPath];
            if (indexPath.row == 0) {
                [cell configureWithTitle:kLang(@"Country") ?: @"Country"
                                   value:[self pp_localizedCountryName:self.selectedCountry]
                             placeholder:kLang(@"TapToSelect") ?: @"Tap to select"
                                  detail:kLang(@"SelectCountryTitle") ?: @"Country controls the available cities and areas."];
            } else if (indexPath.row == 1) {
                NSString *detail = self.selectedCountry
                    ? ([NSString stringWithFormat:@"%@ %@", kLang(@"Country") ?: @"Country:", [self pp_localizedCountryName:self.selectedCountry]])
                    : (kLang(@"TapToSelect") ?: @"Select a country first");
                [cell configureWithTitle:kLang(@"City") ?: @"City"
                                   value:[self pp_localizedCityName:self.selectedCity]
                             placeholder:kLang(@"TapToSelect") ?: @"Tap to select"
                                  detail:detail];
            } else if (indexPath.row == 2) {
                NSString *detail = self.selectedCity
                    ? [self pp_localizedCityName:self.selectedCity]
                    : (kLang(@"TapToSelect") ?: @"Select a city first");
                [cell configureWithTitle:kLang(@"State") ?: @"Area"
                                   value:[self pp_localizedStateName:self.selectedState]
                             placeholder:kLang(@"TapToSelect") ?: @"Tap to select"
                                  detail:detail];
            } else {
                NSString *locationDetail = self.selectedLocationPoints.length > 0
                    ? self.selectedLocationPoints
                    : (kLang(@"MapLocation") ?: @"Pin the exact drop-off point for couriers.");
                [cell configureWithTitle:kLang(@"MapLocation") ?: @"Map location"
                                   value:self.selectedLocationName
                             placeholder:kLang(@"TapToSelect") ?: @"Tap to select"
                                  detail:locationDetail];
            }
            return cell;
        }

        case PPAddressSectionKindPreferences: {
            PPAddressSwitchCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPAddressSwitchCell" forIndexPath:indexPath];
            [cell configureWithTitle:kLang(@"DefaultShippingAddress") ?: @"Default shipping address"
                            subtitle:kLang(@"DefaultShippingAddressSubtitle") ?: @"Use this address automatically when checkout opens."
                                  on:self.draftIsDefault
                              target:self
                              action:@selector(pp_defaultSwitchChanged:)];
            return cell;
        }

        case PPAddressSectionKindDanger: {
            PPAddressActionCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPAddressActionCell" forIndexPath:indexPath];
            [cell configureWithTitle:kLang(@"DeleteAddress") ?: @"Delete address" iconName:@"trash" destructive:YES];
            return cell;
        }
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    BOOL isDangerSection = [self pp_sectionKindForSection:indexPath.section] == PPAddressSectionKindDanger;
    UIColor *surfaceColor = isDangerSection
        ? [[UIColor systemRedColor] colorWithAlphaComponent:0.08]
        : [self pp_surfaceColor];
    UIColor *borderColor = isDangerSection
        ? [[UIColor systemRedColor] colorWithAlphaComponent:0.18]
        : [self pp_surfaceBorderColor];

    cell.backgroundColor = UIColor.clearColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.contentView.backgroundColor = surfaceColor;
    cell.contentView.layer.cornerRadius = 20.0;
    cell.contentView.layer.masksToBounds = YES;
    cell.contentView.layer.borderWidth = 1.0;
    cell.contentView.layer.borderColor = borderColor.CGColor;
    cell.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:1.0].CGColor;
    cell.layer.shadowOpacity = 0.05;
    cell.layer.shadowRadius = 12.0;
    cell.layer.shadowOffset = CGSizeMake(0.0, 6.0);
    cell.layer.masksToBounds = NO;
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    PPAddressSectionKind sectionKind = [self pp_sectionKindForSection:indexPath.section];
    return sectionKind == PPAddressSectionKindGeography || sectionKind == PPAddressSectionKindDanger;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    PPAddressSectionKind sectionKind = [self pp_sectionKindForSection:indexPath.section];
    if (sectionKind == PPAddressSectionKindDanger) {
        [self showDeleteConfirmation];
        return;
    }
    if (sectionKind != PPAddressSectionKindGeography) {
        return;
    }

    switch (indexPath.row) {
        case 0:
            [self pp_presentCountryOptions];
            break;
        case 1:
            [self pp_presentCityOptions];
            break;
        case 2:
            [self pp_presentStateOptions];
            break;
        default:
            [self pp_openLocationPicker];
            break;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return section == 0 ? 64.0 : 72.0;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForHeaderInSection:(NSInteger)section
{
    return [self tableView:tableView heightForHeaderInSection:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 22.0;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForFooterInSection:(NSInteger)section
{
    return 22.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    return [UIView new];
}

- (NSArray<NSString *> *)pp_sectionHeaderContentForSectionKind:(PPAddressSectionKind)sectionKind
{
    switch (sectionKind) {
        case PPAddressSectionKindRecipient:
            return @[
                [self pp_localizedAddressStringForKey:@"Recipient" fallback:@"Recipient"],
                [self pp_localizedAddressStringForKey:@"RecipientSubtitle" fallback:@"Who receives the order and which number should delivery call?"]
            ];
        case PPAddressSectionKindStreet:
            return @[
                [self pp_localizedAddressStringForKey:@"StreetDetails" fallback:@"Street details"],
                [self pp_localizedAddressStringForKey:@"StreetDetailsSubtitle" fallback:@"Add the lines couriers need to find the exact door."]
            ];
        case PPAddressSectionKindGeography:
            return @[
                [self pp_localizedAddressStringForKey:@"AreaAndMap" fallback:@"Area and map"],
                [self pp_localizedAddressStringForKey:@"AreaAndMapSubtitle" fallback:@"Country, city, area, and the map pin should all point to the same place."]
            ];
        case PPAddressSectionKindPreferences:
            return @[
                [self pp_localizedAddressStringForKey:@"DeliveryPreferences" fallback:@"Delivery preferences"],
                [self pp_localizedAddressStringForKey:@"DeliveryPreferencesSubtitle" fallback:@"Choose how this address should behave at checkout."]
            ];
        case PPAddressSectionKindDanger:
            return @[
                [self pp_localizedAddressStringForKey:@"DangerZone" fallback:@"Danger zone"],
                [self pp_localizedAddressStringForKey:@"DangerZoneSubtitle" fallback:@"Remove this saved address permanently."]
            ];
    }
}

- (UIView *)pp_sectionHeaderViewWithTitle:(NSString *)title subtitle:(NSString *)subtitle tintColor:(UIColor *)tintColor
{
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = UIColor.clearColor;

    UIView *accentBar = [[UIView alloc] init];
    accentBar.translatesAutoresizingMaskIntoConstraints = NO;
    accentBar.backgroundColor = tintColor ?: (AppPrimaryClr ?: UIColor.systemOrangeColor);
    accentBar.layer.cornerRadius = 2.0;
    [container addSubview:accentBar];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.text = title ?: @"";
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [container addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    subtitleLabel.textColor = [[UIColor secondaryLabelColor] colorWithAlphaComponent:0.92];
    subtitleLabel.text = subtitle ?: @"";
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [container addSubview:subtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [accentBar.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:18.0],
        [accentBar.topAnchor constraintEqualToAnchor:container.topAnchor constant:14.0],
        [accentBar.widthAnchor constraintEqualToConstant:28.0],
        [accentBar.heightAnchor constraintEqualToConstant:4.0],

        [titleLabel.topAnchor constraintEqualToAnchor:accentBar.bottomAnchor constant:9.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:accentBar.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-18.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:container.bottomAnchor constant:-6.0]
    ]];

    return container;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    PPAddressSectionKind sectionKind = [self pp_sectionKindForSection:section];
    NSArray<NSString *> *content = [self pp_sectionHeaderContentForSectionKind:sectionKind];
    UIColor *tintColor = sectionKind == PPAddressSectionKindDanger
        ? UIColor.systemRedColor
        : (AppPrimaryClr ?: UIColor.systemOrangeColor);
    return [self pp_sectionHeaderViewWithTitle:content.firstObject subtitle:content.lastObject tintColor:tintColor];
}

#pragma mark - Editing

- (void)pp_textFieldEditingChanged:(UITextField *)textField
{
    NSString *value = textField.text ?: @"";
    switch ((PPAddressFieldKind)textField.tag) {
        case PPAddressFieldKindFullName:
            self.draftFullName = value;
            break;
        case PPAddressFieldKindPhoneNumber:
            self.draftPhoneNumber = value;
            break;
        case PPAddressFieldKindAddressLine1:
            self.draftAddressLine1 = value;
            break;
        case PPAddressFieldKindAddressLine2:
            self.draftAddressLine2 = value;
            break;
        case PPAddressFieldKindPostalCode:
            self.draftPostalCode = value;
            break;
        default:
            break;
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    switch ((PPAddressFieldKind)textField.tag) {
        case PPAddressFieldKindFullName:
            [self pp_focusFieldKind:PPAddressFieldKindPhoneNumber];
            return NO;
        case PPAddressFieldKindPhoneNumber:
            [self pp_focusFieldKind:PPAddressFieldKindAddressLine1];
            return NO;
        case PPAddressFieldKindAddressLine1:
            [self pp_focusFieldKind:PPAddressFieldKindAddressLine2];
            return NO;
        case PPAddressFieldKindAddressLine2:
            [self pp_focusFieldKind:PPAddressFieldKindPostalCode];
            return NO;
        default:
            [textField resignFirstResponder];
            return YES;
    }
}

- (void)pp_focusFieldKind:(PPAddressFieldKind)fieldKind
{
    NSIndexPath *indexPath = [self pp_indexPathForFieldKind:fieldKind];
    if (!indexPath) {
        return;
    }

    [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        if ([cell isKindOfClass:PPAddressTextFieldCell.class]) {
            [((PPAddressTextFieldCell *)cell).textField becomeFirstResponder];
        }
    });
}

- (void)pp_defaultSwitchChanged:(UISwitch *)sender
{
    self.draftIsDefault = sender.isOn;
}

#pragma mark - Validation and Save

- (void)animateCell:(UITableViewCell *)cell
{
    if (!cell) {
        return;
    }

    CAKeyframeAnimation *animation = [CAKeyframeAnimation animation];
    animation.keyPath = @"position.x";
    animation.values = @[@0, @20, @-20, @10, @0];
    animation.keyTimes = @[@0, @(1 / 6.0), @(3 / 6.0), @(5 / 6.0), @1];
    animation.duration = 0.3;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    animation.additive = YES;
    [cell.layer addAnimation:animation forKey:@"shake"];
}

- (void)pp_showValidationErrorForFieldKind:(PPAddressFieldKind)fieldKind subtitle:(NSString *)subtitle
{
    NSIndexPath *indexPath = [self pp_indexPathForFieldKind:fieldKind];
    if (indexPath) {
        [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UITableViewCell *badCell = [self.tableView cellForRowAtIndexPath:indexPath];
            [self animateCell:badCell];
        });
    }
    [PPHUD showInfo:subtitle.length > 0 ? subtitle : (kLang(@"PleaseFillFields") ?: @"Please fill the required fields")];
}

- (void)pp_setSavingState:(BOOL)isSaving
{
    self.isSaving = isSaving;
    self.saveBarButtonItem.enabled = !isSaving;
    self.leadingBarButtonItem.enabled = !isSaving;
    self.tableView.userInteractionEnabled = !isSaving;
    self.view.userInteractionEnabled = !isSaving;
}

- (void)pp_closeAfterPersistence
{
    if (self.addressFormPresent == AddressFormPresentSheet) {
        if (self.navigationController.presentingViewController) {
            [self.navigationController dismissViewControllerAnimated:YES completion:nil];
        } else {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
        return;
    }

    if (self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
    } else if (self.navigationController.presentingViewController) {
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)saveButtonPressed:(id)sender
{
    if (self.isSaving) {
        return;
    }

    [self.view endEditing:YES];

    NSString *fullName = [self pp_trimmedString:self.draftFullName];
    NSString *phoneNumber = [self pp_trimmedString:self.draftPhoneNumber];
    NSString *addressLine1 = [self pp_trimmedString:self.draftAddressLine1];
    NSString *addressLine2 = [self pp_trimmedString:self.draftAddressLine2];
    NSString *postalCode = [self pp_trimmedString:self.draftPostalCode];

    if (fullName.length == 0) {
        [self pp_showValidationErrorForFieldKind:PPAddressFieldKindFullName subtitle:kLang(@"FullNamePlaceholder") ?: @"Full name is required"];
        return;
    }
    if (phoneNumber.length == 0) {
        [self pp_showValidationErrorForFieldKind:PPAddressFieldKindPhoneNumber subtitle:kLang(@"MobileNo_Palce") ?: @"Phone number is required"];
        return;
    }
    if (addressLine1.length == 0) {
        [self pp_showValidationErrorForFieldKind:PPAddressFieldKindAddressLine1 subtitle:kLang(@"AddressLine1Placeholder") ?: @"Address line 1 is required"];
        return;
    }
    if (!self.selectedCountry) {
        [self pp_showValidationErrorForFieldKind:PPAddressFieldKindCountry subtitle:kLang(@"SelectCountryTitle") ?: @"Select a country"];
        return;
    }
    if (self.selectedCity.cityID <= 0) {
        [self pp_showValidationErrorForFieldKind:PPAddressFieldKindCity subtitle:kLang(@"TapToSelect") ?: @"Select a city"];
        return;
    }
    if (self.selectedState.stateID <= 0) {
        [self pp_showValidationErrorForFieldKind:PPAddressFieldKindState subtitle:kLang(@"TapToSelect") ?: @"Select an area"];
        return;
    }
    if (postalCode.length == 0) {
        [self pp_showValidationErrorForFieldKind:PPAddressFieldKindPostalCode subtitle:kLang(@"PostalCodePlaceholder") ?: @"Postal code is required"];
        return;
    }

    [self pp_setSavingState:YES];
    [PPHUD showLoading:kLang(@"Saving") ?: @"Saving"];

    BOOL isNewAddress = self.address == nil;
    PPAddressModel *addressToSave = self.address ?: [[PPAddressModel alloc] init];
    NSString *fallbackPhone = PPCurrentUser.MobileNo.length > 0
        ? PPCurrentUser.MobileNo
        : ([FIRAuth auth].currentUser.phoneNumber ?: @"");

    addressToSave.fullName = fullName;
    addressToSave.phoneNumber = phoneNumber.length > 0 ? phoneNumber : fallbackPhone;
    addressToSave.addressLine1 = addressLine1;
    addressToSave.addressLine2 = addressLine2.length > 0 ? addressLine2 : nil;
    addressToSave.cityID = self.selectedCity.cityID;
    addressToSave.stateID = self.selectedState.stateID;
    addressToSave.locatioName = self.selectedLocationName ?: @"";
    addressToSave.locationPoints = self.selectedLocationPoints ?: @"";
    addressToSave.postalCode = postalCode;
    addressToSave.isDefault = self.draftIsDefault;

    NSString *currentUID = [PPAddressesManager.sharedManager currentAuthenticatedUserID];
    if (currentUID.length > 0) {
        addressToSave.userID = currentUID;
    }

    __weak typeof(self) weakSelf = self;
    void (^handleResult)(PPAddressModel * _Nullable, NSError * _Nullable) =
    ^(PPAddressModel * _Nullable savedAddress, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }

            [self pp_setSavingState:NO];
            [PPHUD dismiss];

            if (error || !savedAddress) {
                [PPAlertHelper showErrorIn:self
                                     title:kLang(@"StatusSaveFailed") ?: @"Save failed"
                                  subtitle:error.localizedDescription ?: (kLang(@"SomethingWentWrong") ?: @"Something went wrong")];
                return;
            }

            if ([self.delegate respondsToSelector:@selector(addressFormVC:didSaveAddress:)]) {
                [self.delegate addressFormVC:self didSaveAddress:savedAddress];
            }

            [PPHUD showSuccess:kLang(@"Saved") ?: @"Saved"];
            [self pp_closeAfterPersistence];
        });
    };

    if (isNewAddress) {
        [[PPAddressesManager sharedManager] addAddress:addressToSave completion:handleResult];
    } else {
        [[PPAddressesManager sharedManager] updateAddress:addressToSave completion:handleResult];
    }
}

- (void)showDeleteConfirmation
{
    if (!self.address || self.address.documentID.length == 0) {
        return;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"DeleteAddress") ?: @"Delete address"
                                                                   message:kLang(@"DeleteConfirmMessage") ?: @"Are you sure you want to delete this address?"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"Cancel") ?: @"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"Delete") ?: @"Delete"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(__unused UIAlertAction *action) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        [self pp_setSavingState:YES];
        [PPHUD showLoading];
        [[PPAddressesManager sharedManager] deleteAddress:self.address completion:^(BOOL success, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self pp_setSavingState:NO];
                [PPHUD dismiss];
                if (!success || error) {
                    [PPAlertHelper showErrorIn:self
                                         title:kLang(@"DeleteFailed") ?: @"Delete failed"
                                      subtitle:error.localizedDescription ?: (kLang(@"SomethingWentWrong") ?: @"Something went wrong")];
                    return;
                }

                if ([self.delegate respondsToSelector:@selector(addressFormVC:didDeleteAddress:)]) {
                    [self.delegate addressFormVC:self didDeleteAddress:self.address];
                }

                [PPHUD showSuccess:kLang(@"AddressesDeleted") ?: @"Deleted"];
                [self pp_closeAfterPersistence];
            });
        }];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Location

- (void)pp_startPrefillFromCurrentLocationIfNeeded
{
    if (self.address || self.didApplyInitialLocation) {
        return;
    }

    if (!self.locationManager) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
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
        [self pp_applyResolvedCountryDefaultsIfNeeded];
        [self pp_showLocationPermissionDeniedAlertIfNeeded];
        return;
    }

    CLLocation *cachedLocation = self.locationManager.location;
    if (cachedLocation && [self pp_isValidCoordinate:cachedLocation.coordinate]) {
        [self pp_applyCoordinateToForm:cachedLocation.coordinate suggestedTitle:nil];
        [self pp_reverseGeocodeCoordinateForRowTitle:cachedLocation.coordinate];
        return;
    }

    [self.locationManager startUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    CLLocation *location = locations.lastObject;
    if (!location || ![self pp_isValidCoordinate:location.coordinate]) {
        return;
    }

    [manager stopUpdatingLocation];
    [self pp_applyCoordinateToForm:location.coordinate suggestedTitle:nil];
    [self pp_reverseGeocodeCoordinateForRowTitle:location.coordinate];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    [manager stopUpdatingLocation];
    NSLog(@"[AddressFormVC] Current location failed: %@", error.localizedDescription ?: @"Unknown error");
    [self pp_applyResolvedCountryDefaultsIfNeeded];
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        [manager startUpdatingLocation];
    } else if (status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted) {
        [self pp_applyResolvedCountryDefaultsIfNeeded];
        [self pp_showLocationPermissionDeniedAlertIfNeeded];
    }
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager API_AVAILABLE(ios(14.0))
{
    CLAuthorizationStatus status = manager.authorizationStatus;
    if (status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        [manager startUpdatingLocation];
    } else if (status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted) {
        [self pp_applyResolvedCountryDefaultsIfNeeded];
        [self pp_showLocationPermissionDeniedAlertIfNeeded];
    }
}

#pragma mark - Permission

- (void)pp_showLocationPermissionDeniedAlertIfNeeded
{
    if (self.didShowLocationPermissionAlert) {
        return;
    }
    self.didShowLocationPermissionAlert = YES;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"pp_perm_location_title")
                                                                   message:kLang(@"pp_perm_location_denied_message")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"pp_perm_open_settings")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        NSURL *settingsURL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
        if ([[UIApplication sharedApplication] canOpenURL:settingsURL]) {
            [[UIApplication sharedApplication] openURL:settingsURL options:@{} completionHandler:nil];
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"pp_perm_not_now")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
