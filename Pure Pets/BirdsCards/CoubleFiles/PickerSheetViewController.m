//
//  PickerSheetViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 06/02/2025.
//

#import "PickerSheetViewController.h"

@interface PickerSheetViewController ()

@property (nonatomic, strong) UIPickerView *pickerView;
@property (nonatomic, strong) UIView *topBarView;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, assign) BOOL didBuildLayout;

@end

@implementation PickerSheetViewController

@synthesize rowDescriptor = _rowDescriptor;

#pragma mark - Programmatic UI

- (void)setupViews
{
    if (self.didBuildLayout) return;
    self.didBuildLayout = YES;

    // -- Top bar container --
    self.topBarView = [[UIView alloc] initWithFrame:CGRectZero];
    self.topBarView.translatesAutoresizingMaskIntoConstraints = NO;
    self.topBarView.backgroundColor = [GM appPrimaryColor];
    [self.view addSubview:self.topBarView];

    // -- topTitle label --
    self.topTitle = [[UILabel alloc] initWithFrame:CGRectZero];
    self.topTitle.translatesAutoresizingMaskIntoConstraints = NO;
    self.topTitle.textColor = [UIColor whiteColor];
    self.topTitle.font = [GM boldFontWithSize:17];
    self.topTitle.textAlignment = NSTextAlignmentCenter;
    self.topTitle.numberOfLines = 1;
    [self.topBarView addSubview:self.topTitle];

    // -- Close button --
    self.closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    UIImage *xImage = [UIImage systemImageNamed:@"xmark"];
    [self.closeButton setImage:xImage forState:UIControlStateNormal];
    self.closeButton.tintColor = [UIColor whiteColor];
    [self.closeButton addTarget:self action:@selector(cancelBTN:) forControlEvents:UIControlEventTouchUpInside];
    [self.topBarView addSubview:self.closeButton];

    // -- Table view --
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 16, 0, 16);
    [self.view addSubview:self.tableView];
}

- (void)setupConstraints
{
    CGFloat topBarHeight = 56.0;

    [NSLayoutConstraint activateConstraints:@[
        // Top bar
        [self.topBarView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.topBarView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.topBarView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.topBarView.heightAnchor constraintEqualToConstant:topBarHeight],

        // topTitle – centered in top bar
        [self.topTitle.centerYAnchor constraintEqualToAnchor:self.topBarView.centerYAnchor],
        [self.topTitle.leadingAnchor constraintEqualToAnchor:self.topBarView.leadingAnchor constant:44],
        [self.topTitle.trailingAnchor constraintEqualToAnchor:self.topBarView.trailingAnchor constant:-44],

        // Close button – trailing side of top bar
        [self.closeButton.centerYAnchor constraintEqualToAnchor:self.topBarView.centerYAnchor],
        [self.closeButton.trailingAnchor constraintEqualToAnchor:self.topBarView.trailingAnchor constant:-12],
        [self.closeButton.widthAnchor constraintEqualToConstant:32],
        [self.closeButton.heightAnchor constraintEqualToConstant:32],

        // Table view – fills remaining space below top bar
        [self.tableView.topAnchor constraintEqualToAnchor:self.topBarView.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setupViews];
    [self setupConstraints];

    _tableView.delegate = self;
    _tableView.dataSource = self;

    if (self.pick == PickSunKinds) {
        // Remove any subkind with ID == 0 (safe filter)
        NSPredicate *noZeroID = [NSPredicate predicateWithBlock:^BOOL(SubKindModel *obj, NSDictionary *_) {
            return obj.ID != 0;
        }];
        self.subKindsData = [[self.subKindsData filteredArrayUsingPredicate:noZeroID] mutableCopy];

        // Ensure "Show all cards" item (ID == 0) exists at top
        BOOL hasShowAll =
        [self.subKindsData indexOfObjectPassingTest:^BOOL(SubKindModel *obj, NSUInteger idx, BOOL *stop) {
            return obj.ID == 0;
        }] != NSNotFound;

        if (!hasShowAll) {
            SubKindModel *sub = [[SubKindModel alloc] init];
            sub.ID = 0;
            sub.SubKindNameAr = kLang(@"ShowAllCards_Ar");   // "عرض كل البطاقات"
            sub.SubKindNameEn = kLang(@"ShowAllCards_En");   // "Show all cards"
            [self.subKindsData insertObject:sub atIndex:0];
        }
    
        NSLog(@"subKindsArrayForFilter -->> %@", [self.subKindsData valueForKey:@"SubKindNameEn"]);
        _topTitle.text = kLang(@"PickTypeTitle"); // "قم باختيار النوع"

    } else if (self.pick == PickSunCage) {

        _topTitle.text = kLang(@"PickCageTitle"); // "قم باختيار صندوق لنقل الفرخ اليه"

    } else {
        _topTitle.text = kLang(@"SelectCountryTitle"); // "اختر دولتك"
        // Use current language code, not a hardcoded "ar"
        _pickerData = [GM getMiddleEastCountriesForLanguage:[Language currentLanguageCode]];
    }

    self.view.layer.cornerRadius = 20;
    self.view.clipsToBounds = YES;
    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
    
    if ([Language languageVal] == 0) {
        // English
        self.tableView.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    } else {
        // Arabic
        self.tableView.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    }
}


-(void)setSubKindsArr:(NSMutableArray<SubKindModel *> *)subKindsAr
{
    _pick = PickSunKinds;
    _subKindsData = subKindsAr.mutableCopy;
    [_tableView reloadData];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [_tableView reloadData];
}

#pragma mark - Button Actions

- (void)cancelBTN:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}



-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if(self.pick == PickSunKinds)
        return self.subKindsData.count;
    else if (self.pick == PickSunCage)
        return  AppData.UserCaGeDocs.count;
    return self.pickerData.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"PlainCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];

    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }

    // Set text based on type
    if (self.pick == PickSunKinds) {
        cell.textLabel.text = [self.subKindsData objectAtIndex:indexPath.row].SubKindNameAr;
    }
    else if (self.pick == PickSunCage) {
        cell.textLabel.text = [AppData.UserCaGeDocs objectAtIndex:indexPath.row].CageName;
    }
    else {
        cell.textLabel.text = [self.pickerData objectAtIndex:indexPath.row].country;
    }

    // ✅ Use semantic alignment for RTL/LTR
    if ([Language languageVal] == 0) {
        // English
        cell.textLabel.textAlignment = NSTextAlignmentLeft; // respects system LTR
    } else {
        // Arabic
        cell.textLabel.textAlignment = NSTextAlignmentRight; // respects system RTL
    }

    [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    [cell.textLabel setFont:[GM MidFontWithSize:14]];
    cell.semanticContentAttribute = PPSemanticAuto;
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 48.0f;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger selectedRow = indexPath.row;
    
    
    if(self.pick == PickSunKinds){

        if (self.subCompletionHandler && selectedRow >= 0 && selectedRow < self.subKindsData.count) {
            SubKindModel *selectedItem = self.subKindsData[selectedRow];
            self.subCompletionHandler(selectedItem);
            [self dismissViewControllerAnimated:YES completion:nil];
            return;
        }
    }
    
    
    if(self.pick == PickSunCage){

        if (self.cageCompletionHandler && selectedRow >= 0 && selectedRow <  AppData.UserCaGeDocs.count) {
            CageModel *selectedItem = AppData.UserCaGeDocs[selectedRow];
            self.cageCompletionHandler(selectedItem);
            [self dismissViewControllerAnimated:YES completion:nil];
            return;
        }
    }
    
        
        
    CountryCodeModel *selectedItem = self.pickerData[selectedRow];
    self.rowDescriptor.value = selectedItem;
    NSLog(@"self.rowDescriptor %@",self.rowDescriptor.value);
    NSLog(@"self.rowDescriptor title %@",self.rowDescriptor.title);
    if(self.rowDescriptor.title){
        self.rowDescriptor.value = selectedItem;
        UIViewController *popoverController = self.presentedViewController;
        if (popoverController && popoverController.modalPresentationStyle == UIModalPresentationPopover) {
            [self dismissViewControllerAnimated:YES completion:nil];
        } else if ([self.parentViewController isKindOfClass:[UINavigationController class]]) {
            [self.navigationController popViewControllerAnimated:YES];
        } else
        {
            [[self.presentingViewController navigationController] popViewControllerAnimated:YES];
        }
        return;
    }
    
    
   {
        if (self.completionHandler && selectedRow >= 0 && selectedRow < self.pickerData.count) {
            CountryCodeModel *selectedItem = self.pickerData[selectedRow];
            self.completionHandler(selectedItem);
        }
    }
    
    
    [self dismissViewControllerAnimated:YES completion:nil];
}


@end
