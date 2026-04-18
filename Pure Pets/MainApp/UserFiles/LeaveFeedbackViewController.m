//
//  LeaveFeedbackViewController 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/07/2025.
//


// LeaveFeedbackViewController.m
#import "LeaveFeedbackViewController.h"

// ─── Reason Selection Cell ─────────────────────────────────
@interface PPFeedbackReasonCell : UITableViewCell
@property (nonatomic, strong) UIView *cardContainer;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *reasonLabel;
@property (nonatomic, strong) UIImageView *checkView;
@end

@implementation PPFeedbackReasonCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid {
    self = [super initWithStyle:style reuseIdentifier:rid];
    if (!self) return nil;

    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;

    _cardContainer = [UIView new];
    _cardContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _cardContainer.layer.cornerRadius = 16.0;
    if (@available(iOS 13.0, *)) _cardContainer.layer.cornerCurve = kCACornerCurveContinuous;
    _cardContainer.layer.borderWidth = 1.5;
    [self.contentView addSubview:_cardContainer];

    _iconView = [UIImageView new];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    [_cardContainer addSubview:_iconView];

    _reasonLabel = [UILabel new];
    _reasonLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _reasonLabel.font = [GM MidFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
    _reasonLabel.numberOfLines = 2;
    [_cardContainer addSubview:_reasonLabel];

    _checkView = [UIImageView new];
    _checkView.translatesAutoresizingMaskIntoConstraints = NO;
    _checkView.contentMode = UIViewContentModeScaleAspectFit;
    _checkView.image = [[UIImage systemImageNamed:@"checkmark.circle.fill"
                          withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20.0 weight:UIImageSymbolWeightMedium]]
                         imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [_cardContainer addSubview:_checkView];

    [NSLayoutConstraint activateConstraints:@[
        [_cardContainer.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:5.0],
        [_cardContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20.0],
        [_cardContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20.0],
        [_cardContainer.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-5.0],

        [_iconView.leadingAnchor constraintEqualToAnchor:_cardContainer.leadingAnchor constant:16.0],
        [_iconView.centerYAnchor constraintEqualToAnchor:_cardContainer.centerYAnchor],
        [_iconView.widthAnchor constraintEqualToConstant:24.0],
        [_iconView.heightAnchor constraintEqualToConstant:24.0],

        [_reasonLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:12.0],
        [_reasonLabel.trailingAnchor constraintEqualToAnchor:_checkView.leadingAnchor constant:-10.0],
        [_reasonLabel.topAnchor constraintEqualToAnchor:_cardContainer.topAnchor constant:16.0],
        [_reasonLabel.bottomAnchor constraintEqualToAnchor:_cardContainer.bottomAnchor constant:-16.0],

        [_checkView.trailingAnchor constraintEqualToAnchor:_cardContainer.trailingAnchor constant:-16.0],
        [_checkView.centerYAnchor constraintEqualToAnchor:_cardContainer.centerYAnchor],
        [_checkView.widthAnchor constraintEqualToConstant:24.0],
        [_checkView.heightAnchor constraintEqualToConstant:24.0],

        [self.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:62.0],
    ]];

    return self;
}

- (void)configureWithReason:(NSString *)reason
                       icon:(NSString *)iconName
                   selected:(BOOL)selected
                 brandColor:(UIColor *)brand {

    self.reasonLabel.text = reason;
    self.reasonLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.cardContainer.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:18.0 weight:UIImageSymbolWeightMedium];
    self.iconView.image = [[UIImage systemImageNamed:iconName withConfiguration:cfg] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

    if (selected) {
        self.cardContainer.backgroundColor = [brand colorWithAlphaComponent:0.10];
        [self.cardContainer pp_setBorderColor:[brand colorWithAlphaComponent:0.50]];
        self.iconView.tintColor = brand;
        self.reasonLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
        self.checkView.tintColor = brand;
        self.checkView.hidden = NO;
    } else {
        self.cardContainer.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.6];
        [self.cardContainer pp_setBorderColor:[UIColor.secondaryLabelColor colorWithAlphaComponent:0.12]];
        self.iconView.tintColor = UIColor.secondaryLabelColor;
        self.reasonLabel.textColor = UIColor.secondaryLabelColor;
        self.checkView.hidden = YES;
    }
}

@end

// ─── View Controller ───────────────────────────────────────

static NSString *const kFeedbackReasonCellID = @"PPFeedbackReasonCell";

@interface LeaveFeedbackViewController () <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentContainer;
@property (nonatomic, strong) LOTAnimationView *sadAnimationView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *customReasonCard;
@property (nonatomic, strong) UITextField *customReasonField;
@property (nonatomic, strong) UIButton *logoutButton;
@property (nonatomic, strong) NSArray<NSString *> *reasons;
@property (nonatomic, strong) NSArray<NSString *> *reasonIcons;
@property (nonatomic, assign) NSInteger selectedReasonIndex;
@property (nonatomic, strong) NSLayoutConstraint *tableHeightConstraint;
@end

@implementation LeaveFeedbackViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    UIColor *bg = PPBackgroundColorForIOS26([GM AppForegroundColor]);
    self.view.backgroundColor = bg;
    self.view.layer.cornerRadius = 42.0;
    self.view.clipsToBounds = YES;

    UISemanticContentAttribute sem = [Language semanticAttributeForCurrentLanguage];
    self.view.semanticContentAttribute = sem;

    self.reasons = @[
        kLang(@"reason_toomany_notifications") ?: @"Too many notifications",
        kLang(@"reason_not_useful") ?: @"Not useful",
        kLang(@"reason_temp_break") ?: @"Temporary break",
        kLang(@"reason_other") ?: @"Other"
    ];
    self.reasonIcons = @[
        @"bell.slash.fill",
        @"hand.thumbsdown.fill",
        @"moon.zzz.fill",
        @"ellipsis.bubble.fill"
    ];
    self.selectedReasonIndex = -1;

    [self pp_buildUI];
}

#pragma mark - Build UI

- (void)pp_buildUI {
    UIColor *brand = AppPrimaryClr ?: UIColor.systemOrangeColor;

    // ── Scroll view (full screen) ──
    UIScrollView *scroll = [UIScrollView new];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.alwaysBounceVertical = YES;
    scroll.showsVerticalScrollIndicator = NO;
    scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self.view addSubview:scroll];
    self.scrollView = scroll;

    UIView *content = [UIView new];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:content];
    self.contentContainer = content;

    // ── Sad animation ──
    LOTAnimationView *anim = [[LOTAnimationView alloc] init];
    anim.translatesAutoresizingMaskIntoConstraints = NO;
    anim.loopAnimation = YES;
    anim.contentMode = UIViewContentModeScaleAspectFit;
    anim.backgroundColor = UIColor.clearColor;
    [content addSubview:anim];
    self.sadAnimationView = anim;

    [AppClasses fetchLottieJSONFromFirebasePath:@"LottieAnimations/SadFace.json" completion:^(NSDictionary *jsonDict, NSError *error) {
        if (error || !jsonDict || ![jsonDict isKindOfClass:[NSDictionary class]]) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            LOTComposition *comp = [LOTComposition animationFromJSON:jsonDict];
            [self.sadAnimationView setSceneModel:comp];
            [self.sadAnimationView play];
        });
    }];
    [anim play];

    // ── Title ──
    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = kLang(@"whyleavingus") ?: @"Can you tell us why you're leaving us?";
    title.font = [GM boldFontWithSize:22.0] ?: [UIFont systemFontOfSize:22.0 weight:UIFontWeightBold];
    title.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    title.textAlignment = NSTextAlignmentCenter;
    title.numberOfLines = 0;
    [content addSubview:title];
    self.titleLabel = title;

    // ── Subtitle ──
    UILabel *subtitle = [UILabel new];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = kLang(@"feedback_subtitle") ?: @"Your feedback helps us improve";
    subtitle.font = [GM MidFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    subtitle.textColor = UIColor.secondaryLabelColor;
    subtitle.textAlignment = NSTextAlignmentCenter;
    subtitle.numberOfLines = 0;
    [content addSubview:subtitle];
    self.subtitleLabel = subtitle;

    // ── Reasons table ──
    UITableView *table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    table.translatesAutoresizingMaskIntoConstraints = NO;
    table.delegate = self;
    table.dataSource = self;
    table.backgroundColor = UIColor.clearColor;
    table.separatorStyle = UITableViewCellSeparatorStyleNone;
    table.scrollEnabled = NO;
    table.rowHeight = UITableViewAutomaticDimension;
    table.estimatedRowHeight = 62.0;
    table.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [table registerClass:PPFeedbackReasonCell.class forCellReuseIdentifier:kFeedbackReasonCellID];
    [content addSubview:table];
    self.tableView = table;

    // ── Custom reason card ──
    UIView *reasonCard = [UIView new];
    reasonCard.translatesAutoresizingMaskIntoConstraints = NO;
    reasonCard.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.6];
    reasonCard.layer.cornerRadius = 16.0;
    if (@available(iOS 13.0, *)) reasonCard.layer.cornerCurve = kCACornerCurveContinuous;
    reasonCard.layer.borderWidth = 1.5;
    [reasonCard pp_setBorderColor:[UIColor.secondaryLabelColor colorWithAlphaComponent:0.12]];
    [content addSubview:reasonCard];
    self.customReasonCard = reasonCard;

    UIImageView *pencilIcon = [UIImageView new];
    pencilIcon.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *pencilCfg = [UIImageSymbolConfiguration configurationWithPointSize:16.0 weight:UIImageSymbolWeightMedium];
    pencilIcon.image = [[UIImage systemImageNamed:@"pencil.line" withConfiguration:pencilCfg] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    pencilIcon.tintColor = UIColor.tertiaryLabelColor;
    pencilIcon.contentMode = UIViewContentModeScaleAspectFit;
    [reasonCard addSubview:pencilIcon];

    UITextField *field = [UITextField new];
    field.translatesAutoresizingMaskIntoConstraints = NO;
    field.placeholder = kLang(@"typeyourreason") ?: @"Type your reason here...";
    field.font = [GM MidFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
    field.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    field.textAlignment = Language.alignmentForCurrentLanguage;
    field.delegate = self;
    field.returnKeyType = UIReturnKeyDone;
    field.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [reasonCard addSubview:field];
    self.customReasonField = field;

    // ── Logout button ──
    UIButton *logout = [UIButton buttonWithType:UIButtonTypeSystem];
    logout.translatesAutoresizingMaskIntoConstraints = NO;
    [logout setTitle:(kLang(@"logout") ?: @"Log Out") forState:UIControlStateNormal];
    [logout setTitleColor:[UIColor.systemRedColor colorWithAlphaComponent:0.85] forState:UIControlStateNormal];
    logout.titleLabel.font = [GM boldFontWithSize:17.0] ?: [UIFont systemFontOfSize:17.0 weight:UIFontWeightBold];
    logout.backgroundColor = [UIColor.systemRedColor colorWithAlphaComponent:0.08];
    logout.layer.cornerRadius = 16.0;
    if (@available(iOS 13.0, *)) logout.layer.cornerCurve = kCACornerCurveContinuous;
    logout.layer.borderWidth = 1.0;
    [logout pp_setBorderColor:[UIColor.systemRedColor colorWithAlphaComponent:0.15]];
    [logout addTarget:self action:@selector(logoutTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:logout];
    self.logoutButton = logout;

    // ── Constraints ──
    self.tableHeightConstraint = [table.heightAnchor constraintEqualToConstant:self.reasons.count * 62.0];

    [NSLayoutConstraint activateConstraints:@[
        // Scroll
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:logout.topAnchor constant:-12.0],

        // Content
        [content.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [content.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
        [content.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [content.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor],

        // Animation
        [anim.topAnchor constraintEqualToAnchor:content.topAnchor constant:20.0],
        [anim.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],
        [anim.widthAnchor constraintEqualToConstant:120.0],
        [anim.heightAnchor constraintEqualToConstant:120.0],

        // Title
        [title.topAnchor constraintEqualToAnchor:anim.bottomAnchor constant:16.0],
        [title.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:28.0],
        [title.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-28.0],

        // Subtitle
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:6.0],
        [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [subtitle.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],

        // Table
        [table.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:20.0],
        [table.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [table.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        self.tableHeightConstraint,

        // Custom reason card
        [reasonCard.topAnchor constraintEqualToAnchor:table.bottomAnchor constant:10.0],
        [reasonCard.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20.0],
        [reasonCard.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20.0],
        [reasonCard.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-20.0],

        [pencilIcon.leadingAnchor constraintEqualToAnchor:reasonCard.leadingAnchor constant:16.0],
        [pencilIcon.centerYAnchor constraintEqualToAnchor:reasonCard.centerYAnchor],
        [pencilIcon.widthAnchor constraintEqualToConstant:22.0],
        [pencilIcon.heightAnchor constraintEqualToConstant:22.0],

        [field.leadingAnchor constraintEqualToAnchor:pencilIcon.trailingAnchor constant:10.0],
        [field.trailingAnchor constraintEqualToAnchor:reasonCard.trailingAnchor constant:-16.0],
        [field.topAnchor constraintEqualToAnchor:reasonCard.topAnchor constant:14.0],
        [field.bottomAnchor constraintEqualToAnchor:reasonCard.bottomAnchor constant:-14.0],
        [reasonCard.heightAnchor constraintGreaterThanOrEqualToConstant:56.0],

        // Logout pinned to bottom
        [logout.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20.0],
        [logout.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20.0],
        [logout.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-6.0],
        [logout.heightAnchor constraintEqualToConstant:54.0],
    ]];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self.tableView layoutIfNeeded];
    CGFloat h = self.tableView.contentSize.height;
    if (h > 0 && self.tableHeightConstraint.constant != h) {
        self.tableHeightConstraint.constant = h;
    }
}

#pragma mark - UITableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return (NSInteger)self.reasons.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PPFeedbackReasonCell *cell = [tableView dequeueReusableCellWithIdentifier:kFeedbackReasonCellID forIndexPath:indexPath];
    [cell configureWithReason:self.reasons[indexPath.row]
                         icon:self.reasonIcons[indexPath.row]
                     selected:(indexPath.row == self.selectedReasonIndex)
                   brandColor:(AppPrimaryClr ?: UIColor.systemOrangeColor)];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    self.selectedReasonIndex = indexPath.row;
    [self.customReasonField resignFirstResponder];
    [UIView animateWithDuration:0.25 animations:^{
        [self.tableView reloadData];
        [self.tableView layoutIfNeeded];
    }];

    // Activate logout styling
    UIColor *brand = AppPrimaryClr ?: UIColor.systemOrangeColor;
    [UIView animateWithDuration:0.2 animations:^{
        self.logoutButton.backgroundColor = [UIColor.systemRedColor colorWithAlphaComponent:0.12];
        [self.logoutButton setTitleColor:UIColor.systemRedColor forState:UIControlStateNormal];
        [self.logoutButton pp_setBorderColor:[UIColor.systemRedColor colorWithAlphaComponent:0.25]];
        self.logoutButton.transform = CGAffineTransformMakeScale(1.02, 1.02);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.15 animations:^{
            self.logoutButton.transform = CGAffineTransformIdentity;
        }];
    }];
}

#pragma mark - UITextField

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    UIColor *brand = AppPrimaryClr ?: UIColor.systemOrangeColor;
    [UIView animateWithDuration:0.2 animations:^{
        [self.customReasonCard pp_setBorderColor:[brand colorWithAlphaComponent:0.50]];
        self.customReasonCard.backgroundColor = [brand colorWithAlphaComponent:0.06];
    }];
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    [UIView animateWithDuration:0.2 animations:^{
        [self.customReasonCard pp_setBorderColor:[UIColor.secondaryLabelColor colorWithAlphaComponent:0.12]];
        self.customReasonCard.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.6];
    }];
}

#pragma mark - Action

- (void)logoutTapped {
    NSString *selectedReason = self.selectedReasonIndex >= 0 ? self.reasons[self.selectedReasonIndex] : @"";
    NSString *typedReason = self.customReasonField.text ?: @"";
    NSString *finalReason = typedReason.length > 0 ? typedReason : selectedReason;

    NSLog(@"User logout reason: %@", finalReason);

    // Disable button to prevent double-tap
    self.logoutButton.enabled = NO;
    self.logoutButton.alpha = 0.6;

    [UserManager.sharedManager signOutCurrentUserWithCompletion:^(NSError * _Nullable error) {
        [self dismissViewControllerAnimated:YES completion:^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"stopAllListener" object:self userInfo:nil];
            if (self.onLogout) {
                self.onLogout();
            }
        }];
    }];
}

@end
