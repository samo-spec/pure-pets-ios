//
//  FirstEggVC.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 21/07/2024.
//

#import "FirstEggVC.h"
#import "AppDelegate.h"
#import "eggDatesCell.h"

@interface FirstEggVC ()<UITableViewDelegate,UITableViewDataSource,eggDelegate,getdataback>
{

    NSArray<SubKindModel *> *SubKindsArrayLocal;
    NSMutableArray *childsArray;
    NSMutableDictionary *datesArray;
    CardModel *FatherClass;
    CardModel *MotherClass;
    long Corners;
    NSDateFormatter *dateFormatter;
    
    NSDate *FristEggDateDate;
    NSDate *ReminderDate;
    PGDatePicker *datePicker;
    PGDatePickManager *datePickManager;
    
}
@property (nonatomic) TTGSnackbar *snakBar;
@property (strong, nonatomic) UITableView *datesTable;

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIStackView *fatherColumnStack;
@property (nonatomic, strong) UIStackView *motherColumnStack;
@property (nonatomic, strong) UIStackView *parentSectionStack;
@property (nonatomic, strong) UIView *childInputContainer;
@property (nonatomic, strong) UIButton *addChildButton;
@property (nonatomic, strong) UIButton *dismissButton;
@property (nonatomic, assign) BOOL didBuildLayout;

@end

@implementation FirstEggVC

// 340.0;

-(AppDelegate *)AppDelegate { return (AppDelegate*)[[UIApplication sharedApplication]delegate]; }

#pragma mark - Programmatic UI Setup

- (void)setupViews
{
    if (self.didBuildLayout) return;
    self.didBuildLayout = YES;

    self.view.backgroundColor = PPBackgroundColorForIOS26([UIColor systemBackgroundColor]);

    // --- Scroll view ---
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;

    self.contentView = [[UIView alloc] initWithFrame:CGRectZero];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;

    // --- Header ---
    self.headerView = [[UIView alloc] initWithFrame:CGRectZero];
    self.headerView.translatesAutoresizingMaskIntoConstraints = NO;

    self.headerTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.headerTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.headerTitleLabel.textColor = [UIColor whiteColor];
    self.headerTitleLabel.text = kLang(@"FirstEggDate");

    self.dismissButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.dismissButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.dismissButton setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
    self.dismissButton.tintColor = [UIColor whiteColor];
    [self.dismissButton addTarget:self action:@selector(dismissBTN:) forControlEvents:UIControlEventTouchUpInside];

    // --- Cage name text field ---
    self.CageName = [[UITextField alloc] initWithFrame:CGRectZero];
    self.CageName.translatesAutoresizingMaskIntoConstraints = NO;
    self.CageName.textAlignment = NSTextAlignmentCenter;
    self.CageName.borderStyle = UITextBorderStyleRoundedRect;
    self.CageName.placeholder = kLang(@"CageName");

    // --- Father button ---
    self.FatherBTN = [UIButton buttonWithType:UIButtonTypeSystem];
    self.FatherBTN.translatesAutoresizingMaskIntoConstraints = NO;
    [self.FatherBTN setTitle:kLang(@"Father") forState:UIControlStateNormal];
    [self.FatherBTN setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.FatherBTN.clipsToBounds = YES;
    [self.FatherBTN addTarget:self action:@selector(fatherRingIDTapped:) forControlEvents:UIControlEventTouchUpInside];

    // --- Mother button ---
    self.MotherBTN = [UIButton buttonWithType:UIButtonTypeSystem];
    self.MotherBTN.translatesAutoresizingMaskIntoConstraints = NO;
    [self.MotherBTN setTitle:kLang(@"Mother") forState:UIControlStateNormal];
    [self.MotherBTN setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.MotherBTN.clipsToBounds = YES;
    [self.MotherBTN addTarget:self action:@selector(motherRingIDTapped:) forControlEvents:UIControlEventTouchUpInside];

    // --- Father card (tioView) ---
    self.tioView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tioView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tioView.backgroundColor = [UIColor systemBackgroundColor];

    self.FatherImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.FatherImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.FatherImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.FatherImageView.clipsToBounds = YES;
    self.FatherImageView.layer.cornerRadius = 25;
    self.FatherImageView.image = [UIImage imageNamed:@"images.png"];

    self.fatherRingID = [[UILabel alloc] initWithFrame:CGRectZero];
    self.fatherRingID.translatesAutoresizingMaskIntoConstraints = NO;
    self.fatherRingID.textAlignment = NSTextAlignmentCenter;
    self.fatherRingID.numberOfLines = 1;

    self.FatherKind = [[UILabel alloc] initWithFrame:CGRectZero];
    self.FatherKind.translatesAutoresizingMaskIntoConstraints = NO;
    self.FatherKind.textAlignment = NSTextAlignmentCenter;
    self.FatherKind.numberOfLines = 1;

    // --- Mother card (MotherView) ---
    self.MotherView = [[UIView alloc] initWithFrame:CGRectZero];
    self.MotherView.translatesAutoresizingMaskIntoConstraints = NO;
    self.MotherView.backgroundColor = [UIColor systemBackgroundColor];

    self.MotherImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.MotherImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.MotherImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.MotherImageView.clipsToBounds = YES;
    self.MotherImageView.layer.cornerRadius = 25;
    self.MotherImageView.image = [UIImage imageNamed:@"images.png"];

    self.MotherRingID = [[UILabel alloc] initWithFrame:CGRectZero];
    self.MotherRingID.translatesAutoresizingMaskIntoConstraints = NO;
    self.MotherRingID.textAlignment = NSTextAlignmentCenter;
    self.MotherRingID.numberOfLines = 1;

    self.MotherKind = [[UILabel alloc] initWithFrame:CGRectZero];
    self.MotherKind.translatesAutoresizingMaskIntoConstraints = NO;
    self.MotherKind.textAlignment = NSTextAlignmentCenter;
    self.MotherKind.numberOfLines = 1;

    // --- Parent section stacks ---
    self.fatherColumnStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.FatherBTN, self.tioView]];
    self.fatherColumnStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.fatherColumnStack.axis = UILayoutConstraintAxisVertical;
    self.fatherColumnStack.spacing = 0;

    self.motherColumnStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.MotherBTN, self.MotherView]];
    self.motherColumnStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.motherColumnStack.axis = UILayoutConstraintAxisVertical;
    self.motherColumnStack.spacing = 0;

    self.parentSectionStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.fatherColumnStack, self.motherColumnStack]];
    self.parentSectionStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.parentSectionStack.axis = UILayoutConstraintAxisHorizontal;
    self.parentSectionStack.spacing = 10;
    self.parentSectionStack.distribution = UIStackViewDistributionFillEqually;

    // --- Dates table ---
    self.datesTable = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.datesTable.translatesAutoresizingMaskIntoConstraints = NO;
    self.datesTable.scrollEnabled = NO;
    self.datesTable.separatorInset = UIEdgeInsetsZero;

    // --- Child input area ---
    self.childInputContainer = [[UIView alloc] initWithFrame:CGRectZero];
    self.childInputContainer.translatesAutoresizingMaskIntoConstraints = NO;

    self.RingID = [[UITextField alloc] initWithFrame:CGRectZero];
    self.RingID.translatesAutoresizingMaskIntoConstraints = NO;
    self.RingID.borderStyle = UITextBorderStyleRoundedRect;
    self.RingID.placeholder = kLang(@"RingID");
    self.RingID.textAlignment = NSTextAlignmentCenter;

    self.addChildButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.addChildButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.addChildButton setImage:[UIImage systemImageNamed:@"plus.circle.fill"] forState:UIControlStateNormal];
    self.addChildButton.tintColor = [GM appPrimaryColor];
    [self.addChildButton addTarget:self action:@selector(addChildBTN:) forControlEvents:UIControlEventTouchUpInside];

    // --- Children table ---
    self.childsTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.childsTableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.childsTableView.scrollEnabled = NO;
    self.childsTableView.separatorInset = UIEdgeInsetsZero;

    // --- Bottom bar ---
    self.bottomBarView = [[UIView alloc] initWithFrame:CGRectZero];
    self.bottomBarView.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomBarView.backgroundColor = [UIColor systemBackgroundColor];

    // --- Unused outlets (created to prevent nil crashes) ---
    self.imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.tempSaveBTN = [UIButton buttonWithType:UIButtonTypeSystem];
    self.DNAImageViw = [[UIImageView alloc] initWithFrame:CGRectZero];
 
    // --- Build view hierarchy ---
    [self setupHierarchy];
}

- (void)setupHierarchy
{
    [self.view addSubview:self.scrollView];
    [self.scrollView addSubview:self.contentView];
    [self.view addSubview:self.bottomBarView];

    // Header
    [self.contentView addSubview:self.headerView];
    [self.headerView addSubview:self.headerTitleLabel];
    [self.headerView addSubview:self.dismissButton];

    // Cage name
    [self.contentView addSubview:self.CageName];

    // Parent section
    [self.contentView addSubview:self.parentSectionStack];

    // Father card contents
    [self.tioView addSubview:self.FatherImageView];
    [self.tioView addSubview:self.fatherRingID];
    [self.tioView addSubview:self.FatherKind];

    // Mother card contents
    [self.MotherView addSubview:self.MotherImageView];
    [self.MotherView addSubview:self.MotherRingID];
    [self.MotherView addSubview:self.MotherKind];

    // Dates table
    [self.contentView addSubview:self.datesTable];

    // Child input
    [self.contentView addSubview:self.childInputContainer];
    [self.childInputContainer addSubview:self.RingID];
    [self.childInputContainer addSubview:self.addChildButton];

    // Children table
    [self.contentView addSubview:self.childsTableView];
}

- (void)setupConstraints
{
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    CGFloat pad = 20.0;
    CGFloat cardPad = 8.0;

    // --- Bottom bar pinned to bottom ---
    [NSLayoutConstraint activateConstraints:@[
        [self.bottomBarView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.bottomBarView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.bottomBarView.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],
        [self.bottomBarView.heightAnchor constraintEqualToConstant:60]
    ]];

    // --- Scroll view fills between top and bottom bar ---
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.bottomBarView.topAnchor]
    ]];

    // --- Content view fills scroll view ---
    [NSLayoutConstraint activateConstraints:@[
        [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor]
    ]];

    // --- Header view ---
    [NSLayoutConstraint activateConstraints:@[
        [self.headerView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.headerView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.headerView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.headerView.heightAnchor constraintEqualToConstant:80]
    ]];
    [NSLayoutConstraint activateConstraints:@[
        [self.headerTitleLabel.centerXAnchor constraintEqualToAnchor:self.headerView.centerXAnchor],
        [self.headerTitleLabel.centerYAnchor constraintEqualToAnchor:self.headerView.centerYAnchor]
    ]];
    [NSLayoutConstraint activateConstraints:@[
        [self.dismissButton.trailingAnchor constraintEqualToAnchor:self.headerView.trailingAnchor constant:-16],
        [self.dismissButton.centerYAnchor constraintEqualToAnchor:self.headerView.centerYAnchor],
        [self.dismissButton.widthAnchor constraintEqualToConstant:36],
        [self.dismissButton.heightAnchor constraintEqualToConstant:36]
    ]];

    // --- CageName ---
    [NSLayoutConstraint activateConstraints:@[
        [self.CageName.topAnchor constraintEqualToAnchor:self.headerView.bottomAnchor constant:16],
        [self.CageName.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:pad],
        [self.CageName.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-pad],
        [self.CageName.heightAnchor constraintEqualToConstant:38]
    ]];

    // --- Parent section stack ---
    [NSLayoutConstraint activateConstraints:@[
        [self.parentSectionStack.topAnchor constraintEqualToAnchor:self.CageName.bottomAnchor constant:16],
        [self.parentSectionStack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:pad],
        [self.parentSectionStack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-pad]
    ]];

    // --- Button heights ---
    [NSLayoutConstraint activateConstraints:@[
        [self.FatherBTN.heightAnchor constraintEqualToConstant:36],
        [self.MotherBTN.heightAnchor constraintEqualToConstant:36]
    ]];

    // --- Father card (tioView) internal layout ---
    [NSLayoutConstraint activateConstraints:@[
        [self.tioView.heightAnchor constraintGreaterThanOrEqualToConstant:100],
        [self.FatherImageView.topAnchor constraintEqualToAnchor:self.tioView.topAnchor constant:cardPad],
        [self.FatherImageView.centerXAnchor constraintEqualToAnchor:self.tioView.centerXAnchor],
        [self.FatherImageView.widthAnchor constraintEqualToConstant:50],
        [self.FatherImageView.heightAnchor constraintEqualToConstant:50],
        [self.fatherRingID.topAnchor constraintEqualToAnchor:self.FatherImageView.bottomAnchor constant:4],
        [self.fatherRingID.leadingAnchor constraintEqualToAnchor:self.tioView.leadingAnchor constant:4],
        [self.fatherRingID.trailingAnchor constraintEqualToAnchor:self.tioView.trailingAnchor constant:-4],
        [self.FatherKind.topAnchor constraintEqualToAnchor:self.fatherRingID.bottomAnchor constant:2],
        [self.FatherKind.leadingAnchor constraintEqualToAnchor:self.tioView.leadingAnchor constant:4],
        [self.FatherKind.trailingAnchor constraintEqualToAnchor:self.tioView.trailingAnchor constant:-4],
        [self.FatherKind.bottomAnchor constraintLessThanOrEqualToAnchor:self.tioView.bottomAnchor constant:-cardPad]
    ]];

    // --- Mother card (MotherView) internal layout ---
    [NSLayoutConstraint activateConstraints:@[
        [self.MotherView.heightAnchor constraintGreaterThanOrEqualToConstant:100],
        [self.MotherImageView.topAnchor constraintEqualToAnchor:self.MotherView.topAnchor constant:cardPad],
        [self.MotherImageView.centerXAnchor constraintEqualToAnchor:self.MotherView.centerXAnchor],
        [self.MotherImageView.widthAnchor constraintEqualToConstant:50],
        [self.MotherImageView.heightAnchor constraintEqualToConstant:50],
        [self.MotherRingID.topAnchor constraintEqualToAnchor:self.MotherImageView.bottomAnchor constant:4],
        [self.MotherRingID.leadingAnchor constraintEqualToAnchor:self.MotherView.leadingAnchor constant:4],
        [self.MotherRingID.trailingAnchor constraintEqualToAnchor:self.MotherView.trailingAnchor constant:-4],
        [self.MotherKind.topAnchor constraintEqualToAnchor:self.MotherRingID.bottomAnchor constant:2],
        [self.MotherKind.leadingAnchor constraintEqualToAnchor:self.MotherView.leadingAnchor constant:4],
        [self.MotherKind.trailingAnchor constraintEqualToAnchor:self.MotherView.trailingAnchor constant:-4],
        [self.MotherKind.bottomAnchor constraintLessThanOrEqualToAnchor:self.MotherView.bottomAnchor constant:-cardPad]
    ]];

    // --- Dates table (3 rows x 46pt = 138pt) ---
    [NSLayoutConstraint activateConstraints:@[
        [self.datesTable.topAnchor constraintEqualToAnchor:self.parentSectionStack.bottomAnchor constant:16],
        [self.datesTable.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:pad],
        [self.datesTable.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-pad],
        [self.datesTable.heightAnchor constraintEqualToConstant:138]
    ]];

    // --- Child input row ---
    [NSLayoutConstraint activateConstraints:@[
        [self.childInputContainer.topAnchor constraintEqualToAnchor:self.datesTable.bottomAnchor constant:16],
        [self.childInputContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:pad],
        [self.childInputContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-pad],
        [self.childInputContainer.heightAnchor constraintEqualToConstant:44]
    ]];
    [NSLayoutConstraint activateConstraints:@[
        [self.addChildButton.trailingAnchor constraintEqualToAnchor:self.childInputContainer.trailingAnchor],
        [self.addChildButton.centerYAnchor constraintEqualToAnchor:self.childInputContainer.centerYAnchor],
        [self.addChildButton.widthAnchor constraintEqualToConstant:44],
        [self.addChildButton.heightAnchor constraintEqualToConstant:44],
        [self.RingID.leadingAnchor constraintEqualToAnchor:self.childInputContainer.leadingAnchor],
        [self.RingID.trailingAnchor constraintEqualToAnchor:self.addChildButton.leadingAnchor constant:-8],
        [self.RingID.centerYAnchor constraintEqualToAnchor:self.childInputContainer.centerYAnchor],
        [self.RingID.heightAnchor constraintEqualToConstant:38]
    ]];

    // --- Children table ---
    [NSLayoutConstraint activateConstraints:@[
        [self.childsTableView.topAnchor constraintEqualToAnchor:self.childInputContainer.bottomAnchor constant:8],
        [self.childsTableView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:pad],
        [self.childsTableView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-pad],
        [self.childsTableView.heightAnchor constraintEqualToConstant:200],
        [self.childsTableView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-20]
    ]];
}

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // --- Programmatic UI ---
    [self setupViews];
    [self setupConstraints];
    
    // --- Original setup code (unchanged) ---
    datePickManager = [[PGDatePickManager alloc]init];
    datePickManager.confirmButtonText = @"تم";
    datePickManager.cancelButtonText = @"الغاء";
    datePickManager.style = PGDatePickManagerStyleAlertBottomButton;
    datePickManager.cancelButtonTextColor = [GM appPrimaryColor];
    datePickManager.confirmButtonTextColor = [GM appPrimaryColor];
    datePickManager.cancelButtonFont =[GM MidFontWithSize:16];
    datePickManager.confirmButtonFont =[GM MidFontWithSize:16];
    datePickManager.isShadeBackground = YES;
    datePicker = datePickManager.datePicker;
    datePicker.delegate = self;
    datePicker.datePickerMode = PGDatePickerModeDate;
    datePicker.showUnit = PGShowUnitTypeAll;
    datePicker.titleColorForSelectedRow = [GM appPrimaryColor];
    datePicker.textFontOfSelectedRow = [GM boldFontWithSize:26];
    datePicker.textFontOfOtherRow = [GM MidFontWithSize:14];
    
    
    
    Corners = 10.0;
    _childsTableView.dataSource = self;
    _childsTableView.delegate = self;
    dateFormatter =[[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"dd/MM/yyyy"];
    NSLocale *locale = [[NSLocale alloc]
                        initWithLocaleIdentifier:@"en"];
    [dateFormatter setLocale:locale];
    
    childsArray = [[NSMutableArray alloc] init];
    
    [self LayoutMe];
   
   
    datesArray = [[NSMutableDictionary alloc]init];
    [datesArray setObject:@"zero" forKey:@"FristEggDate"];
    [datesArray setObject:@"zero" forKey:@"ReminderDate"];
   
    
    BKCircularLoadingButton* button2 = [BKCircularLoadingButton buttonWithFrame:CGRectMake(0, 0, 120 , 40)];
    
        [button2 setTitle:kLang(@"save") forState:UIControlStateNormal];
    [button2 setTitle:kLang(@"save") forState:UIControlStateSelected];
    [button2 setOriginalTitle:kLang(@"save")];
    [button2 setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [button2 setBackgroundColor:[GM appPrimaryColor]];
 
    button2.layer.cornerRadius = 19;
    [button2 setCircleColor:[UIColor whiteColor]];
    [button2 setCornerRadius:19];
    [button2.titleLabel setFont:[UIFont systemFontOfSize:14]];
    button2.translatesAutoresizingMaskIntoConstraints = NO;
    [self.bottomBarView addSubview:button2];
    [button2 addTarget:self action:@selector(click:) forControlEvents:UIControlEventTouchUpInside];
    
    [NSLayoutConstraint activateConstraints:@[
        [button2.centerXAnchor constraintEqualToAnchor:self.bottomBarView.centerXAnchor],
        [button2.topAnchor constraintEqualToAnchor:self.bottomBarView.topAnchor constant:-20],
        [button2.widthAnchor constraintEqualToConstant:120],
        [button2.heightAnchor constraintEqualToConstant:40]
    ]];
   

    
    _datesTable.delegate = self;
    _datesTable.dataSource = self;
    [_datesTable registerClass:eggDatesCell.class forCellReuseIdentifier:@"eggDatesCell"];
    [_datesTable registerClass:StepperCell.class forCellReuseIdentifier:@"StepperCell"];
    [_childsTableView registerClass:DetailsTableViewCell.class forCellReuseIdentifier:@"DetailsTableViewCell"];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    // Update gradient layer frame when layout changes
    for (CALayer *sublayer in _headerView.layer.sublayers) {
        if ([sublayer isKindOfClass:[CAGradientLayer class]]) {
            sublayer.frame = _headerView.bounds;
            break;
        }
    }
}



- (IBAction)addChildBTN:(id)sender {
    [childsArray addObject:_RingID.text];
    _RingID.text = @"";
    [_childsTableView reloadData];
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if(tableView == _datesTable)
        return 3;
    return childsArray.count;
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (void)showPickBtnTapped {
    
}

NSIndexPath *dateIndexP;
-(void)showDatePicKer:(NSIndexPath *)currentInexPath
{
    NSLog(@"tapped");
    /*
     PGDatePickManagerStyleSheet,
     PGDatePickManagerStyleAlertTopButton,
     PGDatePickManagerStyleAlertBottomButton
     */
    
    dateIndexP = currentInexPath;
    if(dateIndexP.row == 1)
    {
        NSString *ReminderDate =  [NSString stringWithFormat:@"%@",[datesArray objectForKey:@"ReminderDate"] ?: @""];
        NSDate *date = [dateFormatter dateFromString:ReminderDate];
        [datePicker setDate:date animated:YES];
        
        NSString *FristEggDate =  [NSString stringWithFormat:@"%@",[datesArray objectForKey:@"FristEggDate"] ?: @""];
        datePicker.minimumDate = [dateFormatter dateFromString:FristEggDate];
    }
    datePickManager.view.layer.cornerRadius = 15;
 
    [datePickManager.view pp_setShadowColor:UIColor.blackColor];
    datePickManager.view.layer.shadowOpacity = 1;
    datePickManager.view.layer.shadowOffset = CGSizeMake(5, 5);
    datePickManager.view.layer.shadowRadius = 2;
    datePickManager.view.layer.shouldRasterize = NO;
    datePickManager.view.layer.shadowPath = [[UIBezierPath bezierPathWithRoundedRect:[datePicker bounds] cornerRadius:15] CGPath];
   
    datePickManager.view.layer.masksToBounds = NO;
    datePickManager.view.clipsToBounds = NO;
   // self->dnaImageName = [NSString stringWithFormat:@"%@%@%@%@",self->_RingID.text,[dateFormatter stringFromDate:],@"DNA",@".jpeg"];
  
    [self presentViewController:datePickManager animated:false completion:nil];
    
    
}



-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    
    if(_CageModelData.FristEggDate)
    {
        NSLog(@"_CageModelData.FristEggDate %@",_CageModelData.FristEggDate);
        [datesArray setObject:_CageModelData.FristEggDate forKey:@"FristEggDate"];
        [datesArray setObject:_CageModelData.ReminderDate  forKey:@"ReminderDate"];
        
        NSDate *date = _CageModelData.FristEggDate;
        [datePicker setDate:date animated:YES];
        
        datePicker.minimumDate = _CageModelData.FristEggDate;
        
        
        NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"dd-MM-yyyy"];
        // or @"yyyy-MM-dd hh:mm:ss a" if you prefer the time with AM/PM
        NSLocale *locale = [[NSLocale alloc]
                            initWithLocaleIdentifier:@"en"];
        [dateFormatter setLocale:locale];
        
        
       //  NSString *ago = [dateComponents.date timeAgo];
       // NSLog(@"Output is: \"%@\"", ago);
        eggDatesCell *cell = [_datesTable cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
        NSString *FristEggDate = [dateFormatter stringFromDate:_CageModelData.FristEggDate];
        cell.selectedDateLabel.text =  FristEggDate;
        
        [datesArray setObject:FristEggDate forKey:@"FristEggDate"];
        
        //else
        //    cell.selectedDateLabel.text = @"حدد وقت إشعار اول انتاج";
        FristEggDateDate =_CageModelData.FristEggDate;
        ReminderDate = _CageModelData.ReminderDate;
        
        NSIndexPath *stepperIndexPath = [NSIndexPath indexPathForRow:2 inSection:0];
        StepperCell *stepCell = [_datesTable cellForRowAtIndexPath:stepperIndexPath];
        
        //return;
        NSDateComponents *ageComponents = [[NSCalendar currentCalendar]components:NSCalendarUnitDay
                                                                         fromDate:FristEggDateDate
                                                                           toDate:ReminderDate
                                                                          options:0];
        
        stepCell.plainStepper.value = ageComponents.day;
        [stepCell.plainStepper setup];
        
        NSIndexPath *alertIndexPath = [NSIndexPath indexPathForRow:1 inSection:0];
        eggDatesCell *alertCell = [_datesTable cellForRowAtIndexPath:alertIndexPath];
        alertCell.dateLabel.textColor = [GM appPrimaryColor];
        
        [datesArray setObject:ReminderDate forKey:@"ReminderDate"];
        alertCell.selectedDateLabel.text = [dateFormatter stringFromDate:ReminderDate] ;
        
         
        NSLog(@"dFristEggDate  %@  \n ReminderDate  %@", FristEggDate,ReminderDate);
        
        
    }
}


#pragma PGDatePickerDelegate
- (void)datePicker:(PGDatePicker *)datePicker didSelectDate:(NSDateComponents *)dateComponents {
    
    if(dateIndexP.row == 1)
    {
        ReminderDate = [NSDate dateFromComponents:dateComponents];

        eggDatesCell *cell = [_datesTable cellForRowAtIndexPath:dateIndexP];
        NSString *ReminderDate = [NSString stringWithFormat:@"%ld-%ld-%ld",dateComponents.day,dateComponents.month,(long)dateComponents.year];
        cell.selectedDateLabel.text =  ReminderDate;
        
        [datesArray setObject:ReminderDate forKey:@"ReminderDate"];
        
        NSString *FristEggDate = [NSString stringWithFormat:@"%@",[datesArray objectForKey:@"FristEggDate"] ?: @""];
        
        NSDate *date1 = [dateFormatter dateFromString:FristEggDate];
        NSDate *date2 = [dateFormatter dateFromString:ReminderDate];
        
        NSTimeInterval secondsBetween = [date2 timeIntervalSinceDate:date1];

        int numberOfDays = secondsBetween / 86400;

        NSLog(@"There are %d days in between the two dates.", numberOfDays);
        
        NSIndexPath *stepperIndexPath = [NSIndexPath indexPathForRow:2 inSection:0];
        StepperCell *stepCell = [_datesTable cellForRowAtIndexPath:stepperIndexPath];
        stepCell.plainStepper.value = numberOfDays;
        return;
    }
   //  NSString *ago = [dateComponents.date timeAgo];
   // NSLog(@"Output is: \"%@\"", ago);
    eggDatesCell *cell = [_datesTable cellForRowAtIndexPath:dateIndexP];
    NSString *FristEggDate = [NSString stringWithFormat:@"%ld-%ld-%ld",dateComponents.day,dateComponents.month,(long)dateComponents.year];
    cell.selectedDateLabel.text =  FristEggDate;
    
    [datesArray setObject:FristEggDate forKey:@"FristEggDate"];
    
    //else
    //    cell.selectedDateLabel.text = @"حدد وقت إشعار اول انتاج";
    FristEggDateDate = [NSDate dateFromComponents:dateComponents];
    
    NSIndexPath *stepperIndexPath = [NSIndexPath indexPathForRow:2 inSection:0];
    StepperCell *stepCell = [_datesTable cellForRowAtIndexPath:stepperIndexPath];
    [stepCell.plainStepper setup];
    //return;
    NSDateComponents* comps = [[NSDateComponents alloc]init];
    comps.day = 21;

    NSCalendar* calendar = [NSCalendar currentCalendar];
    ReminderDate = [calendar dateByAddingComponents:comps toDate:FristEggDateDate options:nil];
    
    NSIndexPath *alertIndexPath = [NSIndexPath indexPathForRow:1 inSection:0];
    eggDatesCell *alertCell = [_datesTable cellForRowAtIndexPath:alertIndexPath];
    alertCell.dateLabel.textColor = [GM appPrimaryColor];
    
    [datesArray setObject:ReminderDate forKey:@"ReminderDate"];
    
    NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"dd-MM-yyyy"];
    [dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en"]];
    
    alertCell.selectedDateLabel.text = [dateFormatter stringFromDate:ReminderDate] ;
    
     
    NSLog(@"dFristEggDate  %@  \n ReminderDate  %@", FristEggDate,ReminderDate);
    
}

-(void)daysCount:(NSInteger)count
{
    NSLog(@"-(void)daysCount:(NSInteger)count ----->>>>>>>>  %ld", count);
    
    NSDateComponents* comps = [[NSDateComponents alloc]init];
    comps.day = count;

    NSCalendar* calendar = [NSCalendar currentCalendar];
    NSDate* alertDay = [calendar dateByAddingComponents:comps toDate:FristEggDateDate options:nil];
    
    NSIndexPath *alertIndexPath = [NSIndexPath indexPathForRow:1 inSection:0];
    eggDatesCell *alertCell = [_datesTable cellForRowAtIndexPath:alertIndexPath];
    alertCell.dateLabel.textColor = [GM appPrimaryColor];
    ReminderDate = alertDay;
    NSString *ReminderDate =[dateFormatter stringFromDate:alertDay];
    
    [datesArray setObject:alertDay forKey:@"ReminderDate"];
    alertCell.selectedDateLabel.text =  ReminderDate;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self showDatePicKer:indexPath];
}
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if(tableView == _datesTable)
    {
        if(indexPath.row ==2)
        {
            static NSString *TableIdentifier = @"StepperCell";
            StepperCell *cell = [tableView dequeueReusableCellWithIdentifier:
                                     TableIdentifier];
            if (cell == nil) {
                cell = [[StepperCell alloc]
                        initWithStyle:UITableViewCellStyleDefault
                        reuseIdentifier:TableIdentifier];
            }
            cell.currentInexPath = indexPath;
            cell.delegate = self;
                
            return cell;
        
        }
        else
        {
            static NSString *TableIdentifier = @"eggDatesCell";
            eggDatesCell *cell = [tableView dequeueReusableCellWithIdentifier:
                                     TableIdentifier];
            if (cell == nil) {
                cell = [[eggDatesCell alloc]
                        initWithStyle:UITableViewCellStyleDefault
                        reuseIdentifier:TableIdentifier];
            }
            
            
            
            
            cell.currentInexPath = indexPath;
            cell.delegate = self;
                if(indexPath.row == 0)
                    cell.cellLabel.text = kLang(@"FirstEggDate");
                else
                    cell.cellLabel.text = kLang(@"eggAlarmTime");
                
                UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"pencil"]];
                imageView.tintColor = UIColor.lightGrayColor;
                //cell.accessoryView = imageView;
                
                return cell;
        }
        
    }
    static NSString *TableIdentifier = @"DetailsTableViewCell";
    DetailsTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:
                             TableIdentifier];
    if (cell == nil) {
        cell = [[DetailsTableViewCell alloc]
                initWithStyle:UITableViewCellStyleDefault
                reuseIdentifier:TableIdentifier];
    }
    cell.delegate = self;
    
    
    

    
    cell.titleLablel.text = [NSString stringWithFormat:@" %@",[childsArray objectAtIndex:indexPath.row]];

    cell.cellRowIndex = indexPath.row;
    return cell;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 46;
}

-(void)showData:(NSString *)parentID rowIndex:(long)rowIndex
{
    if (rowIndex < 0 || rowIndex >= (long)childsArray.count) {
        NSLog(@"❌ FirstEggVC: rowIndex %ld out of bounds (childsArray.count=%lu)", rowIndex, (unsigned long)childsArray.count);
        return;
    }
    [childsArray removeObjectAtIndex:rowIndex];
    [_childsTableView reloadData];
}


-(IBAction)click:(BKCircularLoadingButton*)button{
    
    NSString *localFristEggDate = [NSString stringWithFormat:@"%@",[datesArray objectForKey:@"FristEggDate"] ?: @""];
    NSString *localReminderDate =  [NSString stringWithFormat:@"%@",[datesArray objectForKey:@"ReminderDate"] ?: @""];
    NSLog(@"dFristEggDate  %@  \n ReminderDate  %@", FristEggDateDate,ReminderDate);
    //return;
    if([localFristEggDate isEqualToString:@"zero"])
    {
        
        
        
        
        
        self.snakBar = [[TTGSnackbar alloc]initWithMessage:kLang(@"setFirstEggDate") duration:1];
        [self.snakBar setAnimationType:TTGSnackbarAnimationTypeSlideFromBottomBackToBottom];
        self.snakBar.messageTextAlign = NSTextAlignmentCenter;
        self.snakBar.cornerRadius = 20;
        [self.snakBar setIconTintColor:[UIColor whiteColor]];
        [self.snakBar show];
        return;
    }
    
    if(![localFristEggDate isEqualToString:@"zero"])
    {
        if([localReminderDate isEqualToString:@"zero"])
        {
            self.snakBar = [[TTGSnackbar alloc]initWithMessage:kLang(@"seteggAlarmTime") duration:1];
            [self.snakBar setAnimationType:TTGSnackbarAnimationTypeSlideFromBottomBackToBottom];
            self.snakBar.messageTextAlign = NSTextAlignmentCenter;
            self.snakBar.cornerRadius = 20;
            [self.snakBar setIconTintColor:[UIColor whiteColor]];
            [self.snakBar show];
            return;
        }
    }
    
    
    
    
    NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"dd/mm/yyyy"];
    // or @"yyyy-MM-dd hh:mm:ss a" if you prefer the time with AM/PM
    NSLocale *locale = [[NSLocale alloc]
                        initWithLocaleIdentifier:@"en"];
    [dateFormatter setLocale:locale];

    [button startAnimation];

    [dateFormatter setDateFormat:@"ddMMHHmmssSSS"];
         NSDate *AddedDate = [NSDate date];
        NSMutableDictionary *Dic = [NSMutableDictionary new];
    
        [Dic setValue:FristEggDateDate forKey:@"FristEggDate"];
        [Dic setValue:ReminderDate forKey:@"ReminderDate"];
        [Dic setValue:AddedDate forKey:@"CreateDate"];
    
       NSDictionary *updateData = @{@"FristEggDate":FristEggDateDate ,@"ReminderDate":ReminderDate ,@"AddedDate":AddedDate };
    
    
        FIRFirestore *db = [FIRFirestore firestore];
        FIRCollectionReference *ref = [db collectionWithPath:@"CagesCol"];
         
     
    [[ref documentWithPath:_CageModelData.ID] updateData:updateData completion:^(NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"Error updating document: %@", error);
        } else {
                [button stopAnimation];
            [button setTitle:kLang(@"save") forState:UIControlStateNormal];
                NSLog(@"Document successfully updated!");
                [self presentDoneController];
            //}];
        }
    }];
    
   
            
    
  
}

-(void)addedDone
{
    
    [self dismissViewControllerAnimated:YES completion:^{

    }];
}

- (void)presentDoneController
{
   
}

-(void)SendImage:(UIImage *)Myiamge ImageName:(NSString *)iman UrlString:(NSString *)urlStr
{

    NSData *result = UIImageJPEGRepresentation(Myiamge, 0.2);
    NSString *postLength = [NSString stringWithFormat:@"%d", (int)[result length]];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setHTTPMethod:@"POST"];
    NSURL *URLty = [NSURL URLWithString:[urlStr stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLFragmentAllowedCharacterSet]]];
    [request setURL:URLty];
    [request setValue:@"multipart/form-data" forHTTPHeaderField:@"Content-Type"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setHTTPBody:result];
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:
                                  ^(NSData *data, NSURLResponse *response, NSError *error) {
        if (data == nil) {
            NSLog(@"response  %@ ",response);
            NSLog(@"errorrrrr  %@ ",error);
        } else {
            NSLog(@"response  %@ DATAAAAAAAAA %@",response,data);
        }
    }];
    [task resume];
   
}


-(void)setParentClass:(CardModel *)ParentClass fromVC:(NSString *)fromVc
{
    if([fromVc isEqual:@"motherCage"])
    {
        MotherClass = ParentClass;
        _MotherRingID.text = MotherClass.RingID;
        self.MotherKind.text = MotherClass.CardTitle;
        NSString *motherFirstImg = [[MotherClass imagesNames] firstObject];
        if (motherFirstImg) {
            [_MotherImageView sd_setImageWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://purepets.net/uploads/%@/%@",[GM CardsImagesRefStr],motherFirstImg]]
                         placeholderImage:[UIImage imageNamed:@"images.png"]];
        } else {
            NSLog(@"❌ FirstEggVC: mother imagesNames.firstObject is nil");
            [_MotherImageView setImage:[UIImage imageNamed:@"images.png"]];
        }
    }
    else
    {
        FatherClass = ParentClass;
        _fatherRingID.text = FatherClass.RingID;
        self.FatherKind.text = FatherClass.CardTitle;
        NSString *fatherFirstImg = [[FatherClass imagesNames] firstObject];
        if (fatherFirstImg) {
            [_FatherImageView sd_setImageWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://purepets.net/uploads/%@/%@",[GM CardsImagesRefStr],fatherFirstImg]]
                         placeholderImage:[UIImage imageNamed:@"images.png"]];
        } else {
            NSLog(@"❌ FirstEggVC: father imagesNames.firstObject is nil");
            [_FatherImageView setImage:[UIImage imageNamed:@"images.png"]];
        }
    }
}

- (void)setMotherId:(nonnull NSString *)motherID fromVC:(nonnull NSString *)fromVc { 
    
}


- (IBAction)motherRingIDTapped:(id)sender {
    selectTableViewController *add=[selectTableViewController new];
    add.delegate = self;
    add.vcName = @"motherCage";
    [self presentViewController:add animated:YES completion:nil];
    NSLog(@"motherRingIDTapped");
}


- (IBAction)fatherRingIDTapped:(id)sender {

    selectTableViewController *add = [selectTableViewController new];
    add.delegate = self;
    add.vcName = @"fatherCage";
    [self presentViewController:add animated:YES completion:nil];
    NSLog(@"motherRingIDTapped");
}



/*
 #pragma mark - Navigation

 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */


-(void)LayoutMe
{
    [_bottomBarView.layer setShadowColor:[UIColor lightGrayColor].CGColor];
    [_bottomBarView.layer setShadowOffset:CGSizeMake(1, 1)];
    [_bottomBarView.layer setShadowOpacity:0.8];
    [_bottomBarView.layer setShadowRadius:2];
    
    [_tioView.layer setShadowColor:[UIColor lightGrayColor].CGColor];
    [_tioView.layer setShadowOffset:CGSizeMake(-1, 1)];
    [_tioView.layer setShadowOpacity:0.2];
    [_tioView.layer setShadowRadius:1];
    _tioView.layer.cornerRadius = Corners;

    [_MotherView.layer setShadowColor:[UIColor lightGrayColor].CGColor];
    [_MotherView.layer setShadowOffset:CGSizeMake(-1, 1)];
    [_MotherView.layer setShadowOpacity:0.2];
    [_MotherView.layer setShadowRadius:1];
    _MotherView.layer.cornerRadius = Corners;

    [_FatherBTN.layer setMaskedCorners:kCALayerMaxXMinYCorner | kCALayerMinXMinYCorner];
    _FatherBTN.layer.cornerRadius = Corners;
    _FatherBTN.titleLabel.font = [GM MidFontWithSize:13];
    [_MotherBTN.layer setMaskedCorners:kCALayerMaxXMinYCorner | kCALayerMinXMinYCorner];
    _MotherBTN.layer.cornerRadius = Corners;
    _MotherBTN.titleLabel.font = [GM MidFontWithSize:13];
    _FatherBTN.backgroundColor = [GM appPrimaryColor];
    _MotherBTN.backgroundColor = [GM appPrimaryColor];
    
    [_childsTableView.layer setShadowOpacity:0.4];
    [_childsTableView.layer setShadowRadius:1];
    [_childsTableView.layer setShadowColor:[UIColor lightGrayColor].CGColor];
    
    self.MotherRingID.font = [GM MidFontWithSize:12];
    self.MotherKind.font = [GM MidFontWithSize:12];
    
    self.fatherRingID.font = [GM MidFontWithSize:12];
    self.FatherKind.font = [GM MidFontWithSize:12];
    _headerTitleLabel.font = [GM MidFontWithSize:17];
    
    self.CageName.hx_h = 38;
    self.CageName.font = [GM MidFontWithSize:13];
    [[AppManager sharedInstance] setCornerRadius:self.CageName.hx_h/2 withOpacity:0.3 shadowOffset:4 shadowRadius:4 onView:self.CageName  color:[UIColor lightGrayColor]];
    self.CageName.layer.cornerRadius = 15;
    self.CageName.clipsToBounds = YES;
    self.CageName.layer.masksToBounds = YES;
    self.CageName.layer.borderWidth = 0;
    [self setTopGard:_headerView];
}

-(void)setTopGard:(UIView *)theView
{
    CAGradientLayer *theViewGradient = [CAGradientLayer layer];
    theViewGradient.colors = [NSArray arrayWithObjects:(id)[GM appPrimaryColor].CGColor,
                              (id)[GM appPrimaryColor].CGColor,
                              nil];
    theViewGradient.frame = theView.bounds;
    theViewGradient.cornerRadius = 0.0;
    
    [theView.layer insertSublayer:theViewGradient atIndex:0];
}

- (IBAction)dismissBTN:(id)sender {
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}

@end
