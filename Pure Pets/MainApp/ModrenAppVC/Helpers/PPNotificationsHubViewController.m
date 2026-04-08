//
//  PPNotificationsHubViewController 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/7/26.
//


#import "PPNotificationsHubViewController.h"
#import "PPPetRemindersViewController.h"
#import "UserChatsViewController.h"
#import "Language.h"

// ─── Modern Pill Tab Bar ───────────────────────────────────
@interface PPHubPillTabBar : UIView
@property (nonatomic, strong) UIView *pillContainer;
@property (nonatomic, strong) UIView *selectionIndicator;
@property (nonatomic, strong) NSArray<UIButton *> *tabButtons;
@property (nonatomic, assign) NSInteger selectedIndex;
@property (nonatomic, copy) void (^onTabChanged)(NSInteger index);
@property (nonatomic, strong) NSLayoutConstraint *indicatorLeading;
@property (nonatomic, strong) NSLayoutConstraint *indicatorWidth;
@end

@implementation PPHubPillTabBar

- (instancetype)initWithTitles:(NSArray<NSString *> *)titles
                         icons:(NSArray<NSString *> *)icons {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;

    self.translatesAutoresizingMaskIntoConstraints = NO;

    UIColor *brand = AppPrimaryClr ?: UIColor.systemOrangeColor;

    // Pill container
    _pillContainer = [UIView new];
    _pillContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _pillContainer.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.7];
    _pillContainer.layer.cornerRadius = 22.0;
    if (@available(iOS 13.0, *)) _pillContainer.layer.cornerCurve = kCACornerCurveContinuous;
    _pillContainer.layer.borderWidth = 1.0;
    _pillContainer.layer.borderColor = [[UIColor.secondaryLabelColor colorWithAlphaComponent:0.10] CGColor];
    [self addSubview:_pillContainer];

    // Selection indicator (sliding pill)
    _selectionIndicator = [UIView new];
    _selectionIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    _selectionIndicator.backgroundColor = brand;
    _selectionIndicator.layer.cornerRadius = 18.0;
    if (@available(iOS 13.0, *)) _selectionIndicator.layer.cornerCurve = kCACornerCurveContinuous;
    _selectionIndicator.layer.shadowColor = [brand colorWithAlphaComponent:0.40].CGColor;
    _selectionIndicator.layer.shadowOpacity = 0.30;
    _selectionIndicator.layer.shadowRadius = 8.0;
    _selectionIndicator.layer.shadowOffset = CGSizeMake(0.0, 3.0);
    [_pillContainer addSubview:_selectionIndicator];

    // Tab buttons
    NSMutableArray<UIButton *> *buttons = [NSMutableArray array];
    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.distribution = UIStackViewDistributionFillEqually;
    stack.spacing = 0;

    UIImageSymbolConfiguration *iconCfg = [UIImageSymbolConfiguration configurationWithPointSize:14.0 weight:UIImageSymbolWeightSemibold];

    for (NSUInteger i = 0; i < titles.count; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.tag = (NSInteger)i;
        btn.translatesAutoresizingMaskIntoConstraints = NO;

        UIImage *icon = [[UIImage systemImageNamed:icons[i] withConfiguration:iconCfg] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [btn setImage:icon forState:UIControlStateNormal];
        [btn setTitle:[@"  " stringByAppendingString:titles[i]] forState:UIControlStateNormal];
        btn.titleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
        btn.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

        [btn addTarget:self action:@selector(pp_tabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [stack addArrangedSubview:btn];
        [buttons addObject:btn];
    }
    self.tabButtons = [buttons copy];
    [_pillContainer addSubview:stack];

    // Constraints
    _indicatorLeading = [_selectionIndicator.leadingAnchor constraintEqualToAnchor:_pillContainer.leadingAnchor constant:4.0];
    _indicatorWidth = [_selectionIndicator.widthAnchor constraintEqualToConstant:100.0];

    [NSLayoutConstraint activateConstraints:@[
        [_pillContainer.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_pillContainer.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_pillContainer.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_pillContainer.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [_pillContainer.heightAnchor constraintEqualToConstant:44.0],

        _indicatorLeading,
        [_selectionIndicator.topAnchor constraintEqualToAnchor:_pillContainer.topAnchor constant:4.0],
        [_selectionIndicator.bottomAnchor constraintEqualToAnchor:_pillContainer.bottomAnchor constant:-4.0],
        _indicatorWidth,

        [stack.topAnchor constraintEqualToAnchor:_pillContainer.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:_pillContainer.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:_pillContainer.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:_pillContainer.bottomAnchor],
    ]];

    _selectedIndex = -1;

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.selectedIndex >= 0 && self.selectedIndex < (NSInteger)self.tabButtons.count) {
        [self pp_updateIndicatorForIndex:self.selectedIndex animated:NO];
    }
}

- (void)selectIndex:(NSInteger)index animated:(BOOL)animated {
    if (index < 0 || index >= (NSInteger)self.tabButtons.count) return;
    self.selectedIndex = index;
    [self pp_updateIndicatorForIndex:index animated:animated];
    [self pp_updateButtonColors];
}

- (void)pp_tabTapped:(UIButton *)sender {
    NSInteger idx = sender.tag;
    if (idx == self.selectedIndex) return;
    [self selectIndex:idx animated:YES];
    if (self.onTabChanged) self.onTabChanged(idx);
}

- (void)pp_updateIndicatorForIndex:(NSInteger)index animated:(BOOL)animated {
    UIButton *btn = self.tabButtons[index];
    CGFloat containerW = self.pillContainer.bounds.size.width;
    if (containerW <= 0) return;

    CGFloat tabW = containerW / (CGFloat)self.tabButtons.count;
    CGFloat leading = tabW * (CGFloat)index + 4.0;
    CGFloat width = tabW - 8.0;

    self.indicatorLeading.constant = leading;
    self.indicatorWidth.constant = width;

    void (^update)(void) = ^{
        [self.pillContainer layoutIfNeeded];
    };

    if (animated) {
        [UIView animateWithDuration:0.30
                              delay:0
             usingSpringWithDamping:0.78
              initialSpringVelocity:0.5
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:update
                         completion:nil];
    } else {
        update();
    }
}

- (void)pp_updateButtonColors {
    UIColor *brand = AppPrimaryClr ?: UIColor.systemOrangeColor;
    for (NSInteger i = 0; i < (NSInteger)self.tabButtons.count; i++) {
        BOOL active = (i == self.selectedIndex);
        self.tabButtons[i].tintColor = active ? UIColor.whiteColor : UIColor.secondaryLabelColor;
        [self.tabButtons[i] setTitleColor:(active ? UIColor.whiteColor : UIColor.secondaryLabelColor) forState:UIControlStateNormal];
    }
}

@end

// ─── Notifications Hub ─────────────────────────────────────

@interface PPNotificationsHubViewController ()
@property (nonatomic, strong) PPHubPillTabBar *pillTabBar;
@property (nonatomic, strong) UIViewController *activeChild;
@property (nonatomic, strong) PPPetRemindersViewController *remindersVC;
@property (nonatomic, strong) UserChatsViewController *chatsVC;
@end

@implementation PPNotificationsHubViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
    self.title = kLang(@"Notifications") ?: @"Notifications";

    self.remindersVC = [PPPetRemindersViewController new];
    self.chatsVC = [UserChatsViewController new];

    // Modern pill tab bar
    PPHubPillTabBar *pills = [[PPHubPillTabBar alloc] initWithTitles:@[
        (kLang(@"pet_chats_tab") ?: @"Chats"),
        (kLang(@"pet_reminders_tab") ?: @"Reminders"),
    ] icons:@[
        @"bubble.left.and.bubble.right.fill",
        @"bell.badge.fill",
    ]];
    self.pillTabBar = pills;

    // Size for nav bar titleView
    pills.frame = CGRectMake(0, 0, 320, 44);
    self.navigationItem.titleView = pills;

    __weak typeof(self) ws = self;
    pills.onTabChanged = ^(NSInteger index) {
        [ws pp_showChild:(index == 0 ? ws.chatsVC : ws.remindersVC)];
    };

    // Default: Chats (index 0)
    [self pp_showChild:self.chatsVC];

    dispatch_async(dispatch_get_main_queue(), ^{
        [pills selectIndex:0 animated:NO];
    });
}

- (void)pp_showChild:(UIViewController *)child {
    if (self.activeChild == child) return;

    [self.activeChild willMoveToParentViewController:nil];
    [self.activeChild.view removeFromSuperview];
    [self.activeChild removeFromParentViewController];

    [self addChildViewController:child];
    child.view.frame = self.view.bounds;
    child.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:child.view];
    [child didMoveToParentViewController:self];

    self.activeChild = child;
}

@end