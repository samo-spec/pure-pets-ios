//
//  PPSelectOptionViewController.m
//  PurePetsAdmin
//
//  Created by Mohammed Ahmed on 24/08/2025.
//  (Updated with safe XLForm value handling + logging)
//

#import "PPSelectOptionViewController.h"
#import "Styling.h"
#import "Language.h"
#import "PPOptionCell.h"


// Simple log helpers
#ifndef DLog
#define DLog(fmt, ...) NSLog((@"[PPLOG] " fmt), ##__VA_ARGS__)
#endif

#define LogCurrentFunc() DLog(@"[%s]", __FUNCTION__)

@interface PPSelectOptionViewController ()<PPSDelegate>
{
    
}
@property (nonatomic, strong) PPS *searchView;
@property (nonatomic, strong) UIView *bgView;
@end
@implementation PPSelectOptionViewController

#pragma mark - Init

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        LogCurrentFunc();
        _showSearchBar = YES;
        _presentationStyle = PPSelectOptionPresentationSheet;

        _allOptions = @[];
        _filteredOptions = @[];
    }
    return self;
}


- (instancetype)initWithOptions:(NSArray *)options
                          title:(NSString *)title
                          row:(XLFormRowDescriptor *_Nullable)row
               presentationStyle:(PPSelectOptionPresentationStyle)style
                     completion:(PPSelectOptionBlock)completion
{
    return [self initWithOptions:options title:title row:row presentationStyle:style showSearchBar:NO completion:completion];
}
// ✅ Normalize your designated initializer name (lowercase completion)
- (instancetype)initWithOptions:(NSArray *)options
                          title:(NSString *)title
                          row:(XLFormRowDescriptor *_Nullable)row
               presentationStyle:(PPSelectOptionPresentationStyle)style
                  showSearchBar:(BOOL)showSearchBar
                     completion:(PPSelectOptionBlock)completion
{
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        
        _allOptions = options ?: @[];
        _filteredOptions = _allOptions;
        self.title = title;
        _showSearchBar = showSearchBar;
        _presentationStyle = style;
        _onSelectOption = [completion copy];
        self.rowDescriptor = row;
    }
    return self;
}

// ✅ Convenience initializer you’re trying to use
- (instancetype)initWithCompletion:(PPSelectOptionBlock)completion {
    return [self initWithOptions:@[]
                           title:@"Select"
                             row:self.rowDescriptor
                presentationStyle:PPSelectOptionPresentationSheet
                      completion:completion];
}



#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    LogCurrentFunc();
    
    
   

    self.tableView.rowHeight = 72.0;
    self.tableView.backgroundColor = PPIOS26() ? AppClearClr : [AppBackgroundClr colorWithAlphaComponent:0.8];
    self.tableView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    
    self.view.layer.cornerRadius = 25.0;

    // sheet config if using iOS sheet style
    if (self.presentationStyle == PPSelectOptionPresentationSheet) {
        if (@available(iOS 15.0, *)) {
            self.sheetPresentationController.detents = @[
                [UISheetPresentationControllerDetent mediumDetent],
                [UISheetPresentationControllerDetent largeDetent]
            ];
            self.sheetPresentationController.prefersGrabberVisible = YES;
        }
    }
    if (@available(iOS 16.0, *)) {
        UISheetPresentationControllerDetent *smallDetent =  [UISheetPresentationControllerDetent customDetentWithIdentifier:@"smallDetent" resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext>  _Nonnull context) {
            return 400.0;
      
        }];
        
        if (self.presentationStyle == PPSelectOptionPresentationMain) {
            if (@available(iOS 15.0, *)) {
                self.sheetPresentationController.detents = @[smallDetent
                ];
                self.sheetPresentationController.prefersGrabberVisible = YES;
            }
            
            self.tableView.showsVerticalScrollIndicator = NO;
            self.tableView.showsHorizontalScrollIndicator = NO;
        }
    } else {
        // Fallback on earlier versions
    }
    
    
    
    // Create a custom detent — you return the desired height (in points)
                

    // setup header search
    if (self.showSearchBar) {
        [self setupSearchView];
    }

    // set initial filteredOptions if not set
    if (!self.filteredOptions) self.filteredOptions = self.allOptions ?: @[];

    DLog(@"[PPSelectOption] allOptions=%lu", (unsigned long)self.allOptions.count);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    /*if(!PPIOS26() && !self.bgView)
    {
        DLog(@"[PPSelectOption] viewDidLayoutSubviews= !PPIOS26()");

        
        self.bgView = [Styling addBgForOldIOSOn:self.view  Corners:12 Constraints:nil];
        
        [NSLayoutConstraint activateConstraints:@[
            [self.bgView.topAnchor constraintEqualToAnchor:self.tableView.topAnchor],
            [self.bgView.bottomAnchor constraintEqualToAnchor:self.tableView.bottomAnchor constant:-10],
            [self.bgView.leadingAnchor constraintEqualToAnchor:self.tableView.leadingAnchor constant:10],
            [self.bgView.trailingAnchor constraintEqualToAnchor:self.tableView.trailingAnchor constant:-10],
         ]];
        self.bgView.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.8];
        [Styling addLiquidGlassBorderToView:self.bgView];
        
         self.tableView.backgroundView = self.bgView;
    }*/
}

/********** DID SELECT HELPERS **********
 - Normalizes incoming option to UserModel if possible
 - Updates XLForm row value with display text (STRING) to avoid XLForm NSString crashes
 - Calls onSelectOption callback (preserves previous behavior)
 - Returns the PPUserTokenID/device token if present (or nil)
*****************************************/
- (nullable NSString *)didSelectObjectAndReturnDevID:(id)obj {

    // Normalize to UserModel where possible
  
    if ([obj isKindOfClass:[CountryCodeModel class]]) {
        DLog(@"didSelectObject called with CountryCodeModel obj: %@", obj);

    } else if ([obj isKindOfClass:[PPAddressModel class]]) {
        DLog(@"didSelectObjectAndReturnDevID called with PPAddressModel obj: %@", obj);

    } else if ([obj isKindOfClass:[XLFormOptionsObject class]]) {
        // if the options object stored a UserModel in userInfo or value, try that
       /*
        XLFormOptionsObject *opt = (XLFormOptionsObject *)obj;
        if ([opt.valueData isKindOfClass:[UserModel class]]) {
            user = (UserModel *)opt.valueData;
        } else if ([opt.userInfo isKindOfClass:[NSDictionary class]]) {
            id maybeUser = opt.userInfo[@"user"];
            if ([maybeUser isKindOfClass:[UserModel class]]) {
                user = (UserModel *)maybeUser;
            }
        }
        */
    } else if ([obj isKindOfClass:[NSDictionary class]]) {
        // sometimes you may be passing a dict (e.g. from some earlier mapping)
        NSDictionary *d = (NSDictionary *)obj;
        // attempt to create a user or extract dev id directly
        NSString *dev = d[@"PPUserTokenID"] ?: d[@"deviceToken"] ?: d[@"token"];
        if (dev) {
            DLog(@"didSelect: got PPUserTokenID from NSDictionary: %@", dev);
            // Update row with readable text if available
            NSString *display = d[@"display"] ?: d[@"name"] ?: d[@"email"] ?: dev;
            [self updateRowValue:display];
            if (self.onSelectOption) self.onSelectOption(obj);
            return dev;
        }
    } else if ([obj isKindOfClass:NSString.class]) {
        // selected a plain string — nothing to parse to user
        DLog(@"didSelect: got NSString -> %@", (NSString *)obj);
        [self updateRowValue:(NSString *)obj]; // but make sure updateRowValue accepts string
        if (self.onSelectOption) self.onSelectOption(obj);
        return nil;
    }
 

    // fallback: still update row and call callback
    DLog(@"didSelect: couldn't resolve UserModel — calling callback with raw object");
    NSString *displayFallback = [obj description] ?: @"";
    [self updateRowValue:displayFallback];
    if (self.onSelectOption) self.onSelectOption(obj);
    return nil;
}


#pragma mark - Search header
- (void)setupSearchView {
    CGFloat padding = 20.0;
    CGFloat searchHeight = 50.0;
    CGFloat containerHeight = padding + searchHeight + padding;
    CGFloat width = self.view.bounds.size.width;

    // ✅ tableHeaderView must have a concrete frame
    self.searchContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, containerHeight)];
    self.searchContainer.backgroundColor = UIColor.clearColor;

    // PPS instance
    self.searchView = [[PPS alloc] initWithFrame:CGRectZero];
    self.searchView.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchView.cornerRadius = searchHeight/2.0;
    self.searchView.blurEnabled = NO;
    self.searchView.shadowEnabled = YES;
    self.searchView.debounceInterval = 0.16;
    self.searchView.fuzzyEnabled = YES;
    self.searchView.caseInsensitive = YES;
    self.searchView.diacriticsInsensitive = YES;
    self.searchView.minRelevanceScore = 0.45;
    self.searchView.maxResults = 200;
    self.searchView.delegate = self;
    self.searchView.backgroundColor = AppForgroundColr;

    // Buttons
    UIImage *fil = [UIImage systemImageNamed:@"line.3.horizontal.decrease.circle"];
    [self.searchView configurePrimaryButtonWithImage:fil target:self action:@selector(onFilterTapped:)];
    self.searchView.showsPrimaryButton = YES;
    self.searchView.showsSecondaryButton = NO;

    // Localization
    self.searchView.textField.placeholder = kLang(@"SearchHere");
    self.searchView.textField.textAlignment = [Language alignmentForCurrentLanguage];
    self.searchView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    [self.searchContainer addSubview:self.searchView];

    // ✅ pin searchView inside searchContainer with 15 padding
    [NSLayoutConstraint activateConstraints:@[
        [self.searchView.topAnchor constraintEqualToAnchor:self.searchContainer.topAnchor constant:padding],
        [self.searchView.leadingAnchor constraintEqualToAnchor:self.searchContainer.leadingAnchor constant:padding],
        [self.searchView.trailingAnchor constraintEqualToAnchor:self.searchContainer.trailingAnchor constant:-padding],
        [self.searchView.bottomAnchor constraintEqualToAnchor:self.searchContainer.bottomAnchor constant:-padding],
        [self.searchView.heightAnchor constraintEqualToConstant:searchHeight]
    ]];

    // ✅ assign header
    self.tableView.tableHeaderView = self.searchContainer;

    // provide search items (empty for now)
    [self.searchView setSearchItems: self.allOptions stringProvider:^NSString * _Nonnull(id item) {
        NSString *srhTXT = @"";
        if (![item isKindOfClass:PPAddressModel.class])
        {
            PPAddressModel *m = (PPAddressModel *)item;
            srhTXT = m.fullName;
        }
        
        if (![item isKindOfClass:PPAddressModel.class])
        {
            UserModel *m = (UserModel *)item;
            srhTXT =[NSString stringWithFormat:@"%@ %@", m.UserName ?: @"", m.UserEmail ?: @""];
        }

        return srhTXT;
    }];
    
    
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}


- (void)onFilterTapped:(id)sender {
    DLog(@"[PPSelectOption] onFilterTapped");
    // hook for client; leave empty to not change logic
}

- (void)onClearTapped:(id)sender {
    DLog(@"[PPSelectOption] onClearTapped — clearing search");
  
    self.filteredOptions = self.allOptions;
    [self reloadTableViewAnimated];
}

#pragma mark - UITableView helpers

- (void)reloadTableViewAnimated {
    // simple fade animation to show updated results
    [UIView transitionWithView:self.tableView
                      duration:0.25
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        [self.tableView reloadData];
    } completion:nil];
}

#pragma mark - Table data source / delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredOptions.count;
}

- (PPOptionCell *)makeCellForTable:(UITableView *)tableView reuseId:(NSString *)reuse {
    PPOptionCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) {
        cell = [[PPOptionCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuse];
    }
    return cell;
}

#pragma mark - UITableViewDataSource

- (NSString *)emojiFlagForCountryCode:(NSString *)countryCode {
    if (countryCode.length < 2) return @"";
    NSString *code = [[countryCode substringToIndex:2] uppercaseString];
    
    int base = 127397; // regional indicator base
    uint32_t first = [code characterAtIndex:0] + base;
    uint32_t second = [code characterAtIndex:1] + base;
    
    // Combine both into a proper UTF-32 array
    uint32_t scalars[] = { first, second };
    NSString *flag = [[NSString alloc] initWithBytes:scalars
                                              length:sizeof(scalars)
                                            encoding:NSUTF32LittleEndianStringEncoding];
    return flag;
}

- (UIImage *)imageFromEmoji:(NSString *)emoji size:(CGFloat)size {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, size, size)];
    label.text = emoji;
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont systemFontOfSize:size];

    UIGraphicsBeginImageContextWithOptions(label.bounds.size, NO, 0.0);
    [label.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}


- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    id option = (indexPath.row < self.filteredOptions.count)
        ? self.filteredOptions[indexPath.row] : nil;

    PPOptionCell *cell = [self makeCellForTable:tableView reuseId:@"PPOptionCell"];
    if (!option) return cell;

    // --- Extract title, subtitle, and image safely ---
    NSString *title = [self displayTextForOption:option] ?: @"";
    NSString *subtitle = @"";
    UIImage *image = nil;
    NSString *imageNamed = nil;
    NSString *imageURLString = nil;
    NSString *flag = nil;
    // ✅ Handle XLFormOptionsObject properly
    if ([option isKindOfClass:[XLFormOptionsObject class]]) {
        XLFormOptionsObject *xlObj = (XLFormOptionsObject *)option;
        if ([xlObj.formValue isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dict = (NSDictionary *)xlObj.formValue;
            subtitle = dict[@"desc"] ?: @"";
            NSString *imgName = dict[@"image"];
            if (imgName.length > 0)
                image = [UIImage imageNamed:imgName];
        }
    }
    
    
    else if ([option isKindOfClass:[UserModel class]]) {
        
        UserModel *op = (UserModel *)option;
        title = op.UserName;
        subtitle = op.MobileNo ?: op.UserEmail;
        imageURLString = op.UserImageUrl.absoluteString;
    }
    
    else if ([option isKindOfClass:[MainKindsModel class]]) {
        
        MainKindsModel *op = (MainKindsModel *)option;
        title = op.KindName;
        imageURLString = op.KindImageUrl;
    }
    
    
    else if ([option isKindOfClass:[SubKindModel class]]) {
        
        SubKindModel *op = (SubKindModel *)option;
        title = op.SubKindName;
        imageURLString = op.subKindIconUrl;
    }
    
    
    else if ([option isKindOfClass:[OptionModel class]]) {
        
        OptionModel *op = (OptionModel *)option;
        title = op.title;
        subtitle = op.subtitle;
        imageNamed = op.systemImageName ?: op.imageName; 
    }
    
    
    else if ([option isKindOfClass:[CountryCodeModel class]]) {
        
        CountryCodeModel *op = (CountryCodeModel *)option;
        
        
        NSString *flag = [self emojiFlagForCountryCode:op.isoCountryCode];
        NSData *data = [flag dataUsingEncoding:NSUTF8StringEncoding];
        NSLog(@"Flag: %@ (%@)", flag, data);
        title = op.country;
        cell.titleLabel.numberOfLines = 1;
        
        if(flag)
       {
           image = [self imageFromEmoji:flag size:40];
           cell.circleImageView.layer.cornerRadius = 0; // circle (40x40)
           cell.circleImageView.layer.masksToBounds = NO;
           cell.circleImageView.clipsToBounds = NO;
       }
       

    }


    else if ([option isKindOfClass:[PPAddressModel class]]) {
        
        if ([option respondsToSelector:@selector(UserAbout)]) {
            subtitle = [option performSelector:@selector(UserAbout)] ?: @"";
        }
        
        if ([option respondsToSelector:@selector(UserImageUrl)]) {
            id val = [option performSelector:@selector(UserImageUrl)];
            if ([val isKindOfClass:[NSURL class]]) {
                imageURLString = [(NSURL *)val absoluteString];
            } else if ([val isKindOfClass:[NSString class]]) {
                imageURLString = val;
            }
        }
        
        cell.titleLabel.numberOfLines = 2;
        imageNamed = @"mappin.and.ellipse.circle.fill";

    }

    // Handle CardModel (birds cards — father/mother selection)
    else if ([option respondsToSelector:@selector(RingID)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        NSString *ringID = [option performSelector:@selector(RingID)];
#pragma clang diagnostic pop
        title = ringID ?: title;
    }

    // Handle any XLFormOptionObject conformant (subSubKindModel, subKindItemsModel, etc.)
    else if ([option respondsToSelector:@selector(formDisplayText)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        title = [option performSelector:@selector(formDisplayText)] ?: title;
#pragma clang diagnostic pop
    }

    // ✅ Handle NSString option
    else if ([option isKindOfClass:[NSString class]]) {
        subtitle = @"";
    }
    
    


    // --- Configure cell ---
    if (imageURLString.length > 0) {
        [cell configureWithTitle:title subtitle:subtitle imageUrl:imageURLString];
    } else if (imageNamed.length > 0) {
        [cell configureWithTitle:title subtitle:subtitle imageNamed:imageNamed];
    } else {
        [cell configureWithTitle:title subtitle:subtitle image:image];
    }
    if (self.optionCellBackgroundColor) {
        cell.backgroundColor = self.optionCellBackgroundColor;
        cell.contentView.backgroundColor = self.optionCellBackgroundColor;
    }
    // --- Determine selection state safely ---
    BOOL selected = NO;
    id currentValue = self.rowDescriptor.value;

    if ([currentValue isKindOfClass:[NSString class]]) {
        selected = [title isEqualToString:(NSString *)currentValue];
    } else if (currentValue != nil) {
        selected = [currentValue isEqual:option];
    } else if (self.selectedOption) {
        selected = [self.selectedOption isEqual:option];
    }

    cell.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    cell.tintColor = AppPrimaryClr;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    return cell;
}


#pragma mark - Selection

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    LogCurrentFunc();
    id option = self.filteredOptions[indexPath.row];
    if ([option isKindOfClass:[OptionModel class]]) {
        
        if (self.presentationStyle == PPSelectOptionPresentationPush) {
            [self.navigationController popViewControllerAnimated:YES ];
        } else {
            [self dismissViewControllerAnimated:YES completion:^{
                self.onSelectOption(option);
            }];
        }
        return;
    }
    
    NSString *display = [self displayTextForOption:option] ?: @"";
    DLog(@"[PPSelectOption] didSelect option display='%@' index=%ld", display, (long)indexPath.row);

    
    NSString *PPUserTokenID = [self didSelectObjectAndReturnDevID:option];
    DLog(@"[PPSelectOption] didSelectRowAtIndexPath -> extracted PPUserTokenID: %@", PPUserTokenID ?: @"(nil)");
    // keep the original object
    self.selectedOption = option;

    // store **string** into XLForm row.value to avoid XLForm internal string methods crashes
    if (self.rowDescriptor) {
        self.rowDescriptor.value = display;
        DLog(@"[PPSelectOption] rowDescriptor.value set to string '%@'", display);
    } else {
        DLog(@"[PPSelectOption] WARNING: rowDescriptor is nil — caller must set vc.rowDescriptor before presenting");
    }

    // refresh the list (updates checkmarks safely)
    [self.tableView reloadData];

    // fire callback with the real model
    if (self.onSelectOption) {
        DLog(@"[PPSelectOption] calling onSelectOption callback with model: %@", option);
        self.onSelectOption(option);
    }

    // ask parent form to update UI (caller should have set vc.parentForm = self (XLFormViewController))
    [self updateRowValue:display];

    // dismiss/pop
    if (self.presentationStyle == PPSelectOptionPresentationPush) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - Search (UISearchBarDelegate)

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    LogCurrentFunc();
    if (searchText.length == 0) {
        self.filteredOptions = self.allOptions ?: @[];
        [self reloadTableViewAnimated];
        return;
    }

    NSPredicate *p = [NSPredicate predicateWithBlock:^BOOL(id option, NSDictionary *bindings) {
        NSString *display = [self displayTextForOption:option];
        if (!display) return NO;
        return [display localizedCaseInsensitiveContainsString:searchText];
    }];

    self.filteredOptions = [self.allOptions filteredArrayUsingPredicate:p];
    DLog(@"[PPSelectOption] search text='%@' results=%lu", searchText, (unsigned long)self.filteredOptions.count);
    [self reloadTableViewAnimated];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

#pragma mark - Helpers

- (NSString *)displayTextForOption:(id)option {
    if (!option) return @"";
    if ([option isKindOfClass:XLFormOptionsObject.class]) {
        return [(XLFormOptionsObject *)option displayText] ?: @"";
    } else if ([option respondsToSelector:@selector(UserName)] ||
               [option respondsToSelector:@selector(UserEmail)] ||
               [option respondsToSelector:@selector(MobileNo)]) {
        // Try common UserModel properties via selectors to avoid needing header
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        NSString *name = nil;
        if ([option respondsToSelector:@selector(UserName)]) name = [option performSelector:@selector(UserName)];
        if (!name && [option respondsToSelector:@selector(UserEmail)]) name = [option performSelector:@selector(UserEmail)];
        if (!name && [option respondsToSelector:@selector(MobileNo)]) name = [option performSelector:@selector(MobileNo)];
#pragma clang diagnostic pop
        return name ?: [option description] ?: @"";
    } else if ([option isKindOfClass:NSString.class]) {
        return (NSString *)option;
    } else if ([option isKindOfClass:PPAddressModel.class]) {
        PPAddressModel *optionPP = (PPAddressModel *)option;
        return optionPP.displayText;
    } else if ([option respondsToSelector:@selector(formDisplayText)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        return [option performSelector:@selector(formDisplayText)] ?: @"";
#pragma clang diagnostic pop
    }
    // fallback
    return [option description] ?: @"";
}

- (void)updateRowValue:(id)value {
    LogCurrentFunc();
    if (!self.rowDescriptor) {
        DLog(@"[PPSelectOption] updateRowValue: rowDescriptor missing — cannot update form");
        return;
    }

    // rowDescriptor already updated in selection handler, but keep idempotent
    self.rowDescriptor.value = value;

    // ask parent form to refresh row (caller must set parentForm)
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.parentForm && [self.parentForm respondsToSelector:@selector(updateFormRow:)]) {
            DLog(@"[PPSelectOption] calling parentForm updateFormRow:");
            //[self.parentForm updateFormRow:self.rowDescriptor];
        } else {
            DLog(@"[PPSelectOption] parentForm nil or doesn't respond to updateFormRow:");
        }
    });
}

#pragma mark - Public API helpers (convenience)

- (void)setAllOptions:(NSArray *)allOptions {
    _allOptions = allOptions ?: @[];
    // initialize filtered as well
    self.filteredOptions = _allOptions;
}

#pragma mark - Debugging hints / suggestions

/********** ISSUE CATCHER **********
 If you see crashes like:
  - '-[UserModel rangeOfCharacterFromSet:]: unrecognized selector sent to instance ...'
 It means some XLForm (or your code) attempted to call NSString APIs on `rowDescriptor.value`.
 SUGGESTED SOLUTION:
 1) Always set `rowDescriptor.value` to an NSString (display string or unique ID).
 2) Keep the selected model in `vc.selectedOption` (or in `rowDescriptor.userInfo`).
 3) Caller (XLForm controller) **must** set `vc.rowDescriptor = row; vc.parentForm = self;` before presenting.
 4) If you need to store the actual model in the form, store safely under userInfo or separate property.
 ********** END ISSUE CATCHER **********/

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!PPIOS26())  [Styling applyBackgroundStyleForTableView:tableView cell:cell indexPath:indexPath useRowCardMode:NO];
}
@end
