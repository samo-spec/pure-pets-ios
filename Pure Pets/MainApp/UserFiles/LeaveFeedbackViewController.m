//
//  LeaveFeedbackViewController 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/07/2025.
//


// LeaveFeedbackViewController.m
#import "LeaveFeedbackViewController.h"


@interface LeaveFeedbackViewController () <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

@property (nonatomic, strong) LOTAnimationView *sadAnimationView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIButton *logoutButton;
@property (nonatomic, strong) NSArray<NSString *> *reasons;
@property (nonatomic, assign) NSInteger selectedReasonIndex;
@property (nonatomic, strong) UITextField *customReasonField;

@end

@implementation LeaveFeedbackViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = PPBackgroundColorForIOS26([GM AppForegroundColor]);
    self.view.layer.cornerRadius = 42;
    self.view.clipsToBounds = YES;
    
    self.reasons = @[
        kLang(@"reason_toomany_notifications"),
        kLang(@"reason_not_useful"),
        kLang(@"reason_temp_break"),
        kLang(@"reason_other")
    ];
    self.selectedReasonIndex = -1;
    
    [self setupSadAnimation];
    [self setupTitleLabel];
    [self setupTableView];
    [self setupLogoutButton];
   
    if([Language languageVal] == 0)
        self.view.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    else
        self.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
}

#pragma mark - UI Setup

- (void)setupSadAnimation {
    self.sadAnimationView = [[LOTAnimationView alloc] init];
    
    [AppClasses fetchLottieJSONFromFirebasePath:@"LottieAnimations/SadFace.json" completion:^(NSDictionary * _Nonnull jsonDict, NSError * _Nonnull error) {
        if (error) {
            NSLog(@"Lottie ADS --- >>> ❌ Failed to fetch Lottie JSON: %@", error.localizedDescription);
            return;
        }
        if (!jsonDict || ![jsonDict isKindOfClass:[NSDictionary class]]) {
            NSLog(@"Lottie ADS --- >>> ❌ Invalid or nil JSON dictionary for Lottie");
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            // Set animation with JSON dictionary
            LOTComposition *composition = [LOTComposition animationFromJSON:jsonDict];
            [self.sadAnimationView setSceneModel:composition];
            [self.sadAnimationView play];
        });
    }];
    
    self.sadAnimationView.loopAnimation = YES;
    self.sadAnimationView.contentMode = UIViewContentModeScaleAspectFit;
    self.sadAnimationView.frame = CGRectMake(0, 30, self.view.bounds.size.width, 120);
    [self.sadAnimationView play];
    self.sadAnimationView.backgroundColor =  AppClearClr;
    [self.view addSubview:self.sadAnimationView];
}

- (void)setupTitleLabel {
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, CGRectGetMaxY(self.sadAnimationView.frame), self.view.bounds.size.width - 40, 40)];
    self.titleLabel.text = kLang(@"whyleavingus");
    self.titleLabel.font = [GM boldFontWithSize:18];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.numberOfLines = 0;
    [self.view addSubview:self.titleLabel];
}

- (void)setupTableView {
    CGFloat yOffset = CGRectGetMaxY(self.titleLabel.frame) + 10;
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, yOffset, self.view.bounds.size.width, self.view.hx_h) style:UITableViewStyleInsetGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = AppClearClr;
    if([Language languageVal] == 0)
        self.tableView.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    else
        self.tableView.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [self.view addSubview:self.tableView];
}

- (void)setupLogoutButton {
    self.logoutButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.logoutButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.logoutButton.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.1];
    [self.logoutButton setTitle:kLang(@"logout") forState:UIControlStateNormal];
    [self.logoutButton setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
    self.logoutButton.layer.cornerRadius = 25;
    [self.logoutButton.titleLabel setFont: [GM fontWithSize:14]];
    [self.logoutButton addTarget:self action:@selector(logoutTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.logoutButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.logoutButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:10],
        [self.logoutButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.logoutButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.logoutButton.heightAnchor constraintEqualToConstant:50]
    ]];
}

#pragma mark - UITableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? self.reasons.count : 1;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return indexPath.section ==  0 ? 50 : 80;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.section == 1) {
        
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        self.customReasonField = [[UITextField alloc] initWithFrame:CGRectMake(50, 7, self.view.hx_w - 100, 80)];
        self.customReasonField.placeholder = kLang(@"typeyourreason");
        self.customReasonField.delegate = self;
        [self.customReasonField setFont:[GM fontWithSize:14]];
        
        self.customReasonField.textAlignment = [Language languageVal] == 0 ? NSTextAlignmentLeft : NSTextAlignmentRight;
        
        cell.textAlignment = [Language languageVal] == 0 ? NSTextAlignmentLeft : NSTextAlignmentRight;
        [cell.contentView setBackgroundColor:[AppForgroundColr colorWithAlphaComponent:1]];

        [cell.contentView addSubview:self.customReasonField];
        return cell;
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ReasonCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ReasonCell"];
    }
    cell.textLabel.text = self.reasons[indexPath.row];
    cell.textLabel.font = [GM fontWithSize:14];
    cell.accessoryType = (indexPath.row == self.selectedReasonIndex) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    [cell.contentView setBackgroundColor:[AppForgroundColr colorWithAlphaComponent:1]];
    cell.textLabel.textAlignment = [Language languageVal] == 0 ? NSTextAlignmentLeft : NSTextAlignmentRight;
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;
    NSInteger rows = [tableView numberOfRowsInSection:section];

    UIBezierPath *maskPath;
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    CGRect bounds = cell.bounds;

    if (row == 0 && row == rows - 1) {
        // Single cell
        maskPath = [UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:12];
    } else if (row == 0) {
        // First cell
        maskPath = [UIBezierPath bezierPathWithRoundedRect:bounds
                                         byRoundingCorners:(UIRectCornerTopLeft | UIRectCornerTopRight)
                                               cornerRadii:CGSizeMake(20, 20)];
    } else if (row == rows - 1) {
        // Last cell
        maskPath = [UIBezierPath bezierPathWithRoundedRect:bounds
                                         byRoundingCorners:(UIRectCornerBottomLeft | UIRectCornerBottomRight)
                                               cornerRadii:CGSizeMake(20, 20)];
    } else {
        // Middle cell
        maskPath = [UIBezierPath bezierPathWithRect:bounds];
    }

    maskLayer.path = maskPath.CGPath;
    cell.layer.mask = maskLayer;
}



- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        self.selectedReasonIndex = indexPath.row;
        [self.tableView reloadData];
        [self.customReasonField resignFirstResponder];
    }
    
    [self.logoutButton setTitleColor:AppPrimaryClr forState:UIControlStateNormal];
}

#pragma mark - Action

- (void)logoutTapped {
    NSString *selectedReason = self.selectedReasonIndex >= 0 ? self.reasons[self.selectedReasonIndex] : @"";
    NSString *typedReason = self.customReasonField.text ?: @"";
    
    NSString *finalReason = typedReason.length > 0 ? typedReason : selectedReason;
    
    NSLog(@"User logout reason: %@", finalReason);
    [UserManager.sharedManager signOutCurrentUserWithCompletion:^(NSError * _Nullable error) {
        // Perform logout here
        [self dismissViewControllerAnimated:YES completion:^{
            // Add your logout logic
            [[NSNotificationCenter defaultCenter] postNotificationName:@"stopAllListener" object:self userInfo:nil];
            
          
            self.onLogout();
        }];
    }];
}

@end
