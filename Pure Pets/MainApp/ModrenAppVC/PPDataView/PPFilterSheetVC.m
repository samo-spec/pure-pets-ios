//
//  PPFilterSheetVC.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 31/12/2025.
//


#import "PPFilterSheetVC.h"

 
@interface PPFilterSheetVC ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIView *accessorySectionView;
@property (nonatomic, strong) UIView *serviceSectionView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) NSArray<UIButton *> *accessoryButtons;
@property (nonatomic, strong) NSArray<UIButton *> *serviceButtons;
@property (nonatomic, strong) UIButton *resetButton;
@property (nonatomic, strong) UIButton *applyButton;
@end

@implementation PPFilterSheetVC


-(void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClrLigter);
    [self setupUI];
    [self reloadVisibleSections];
    [self reloadFilterButtons];
}

- (BOOL)showsAccessoryFilters
{
    return self.currentSection == PPDataSectionAccessories;
}

- (BOOL)showsServiceFilters
{
    return self.currentSection == PPDataSectionServices;
}

- (NSString *)sectionTitle
{
    switch (self.currentSection) {
        case PPDataSectionAccessories:
            return kLang(@"Accessories");
        case PPDataSectionServices:
            return kLang(@"services");
        case PPDataSectionFood:
            return kLang(@"Food");
        case PPDataSectionAds:
        default:
            return kLang(@"Ads");
    }
}

- (void)setupUI
{
    UIView *handle = [[UIView alloc] init];
    handle.translatesAutoresizingMaskIntoConstraints = NO;
    handle.backgroundColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.22];
    handle.layer.cornerRadius = 2.5;
    [self.view addSubview:handle];

    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.showsVerticalScrollIndicator = NO;
    scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:scrollView];
    self.scrollView = scrollView;

    UIStackView *contentStack = [[UIStackView alloc] init];
    contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    contentStack.axis = UILayoutConstraintAxisVertical;
    contentStack.spacing = 18.0;
    [scrollView addSubview:contentStack];
    self.contentStack = contentStack;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.numberOfLines = 1;
    titleLabel.font = [GM boldFontWithSize:24];
    titleLabel.textColor = UIColor.labelColor;
    titleLabel.text = kLang(@"filterPPAction");
    [contentStack addArrangedSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.font = [GM MidFontWithSize:15];
    subtitleLabel.textColor = UIColor.secondaryLabelColor;
    subtitleLabel.text = [self sectionTitle];
    [contentStack addArrangedSubview:subtitleLabel];

    NSArray<UIButton *> *accessoryButtons = @[
        [self optionButtonWithTitle:kLang(@"All")
                                tag:PPFilterAccessoryAll
                             action:@selector(accessoryButtonTapped:)],
        [self optionButtonWithTitle:kLang(@"New")
                                tag:PPFilterAccessoryNew
                             action:@selector(accessoryButtonTapped:)],
        [self optionButtonWithTitle:kLang(@"Used")
                                tag:PPFilterAccessoryUsed
                             action:@selector(accessoryButtonTapped:)]
    ];
    self.accessoryButtons = accessoryButtons;
    self.accessorySectionView =
    [self optionSectionWithTitle:kLang(@"Accessories")
                          buttons:accessoryButtons];
    [contentStack addArrangedSubview:self.accessorySectionView];

    NSArray<UIButton *> *serviceButtons = @[
        [self optionButtonWithTitle:kLang(@"All")
                                tag:PPFilterServiceAll
                             action:@selector(serviceButtonTapped:)],
        [self optionButtonWithTitle:kLang(@"Training")
                                tag:PPFilterServiceTraining
                             action:@selector(serviceButtonTapped:)],
        [self optionButtonWithTitle:kLang(@"Grooming")
                                tag:PPFilterServiceGrooming
                             action:@selector(serviceButtonTapped:)]
    ];
    self.serviceButtons = serviceButtons;
    self.serviceSectionView =
    [self optionSectionWithTitle:kLang(@"services")
                          buttons:serviceButtons];
    [contentStack addArrangedSubview:self.serviceSectionView];

    UILabel *emptyLabel = [[UILabel alloc] init];
    emptyLabel.numberOfLines = 0;
    emptyLabel.textAlignment = NSTextAlignmentCenter;
    emptyLabel.font = [GM MidFontWithSize:15];
    emptyLabel.textColor = UIColor.secondaryLabelColor;
    emptyLabel.text = @"No extra filters for this section yet.";
    [contentStack addArrangedSubview:emptyLabel];
    self.emptyLabel = emptyLabel;

    UIStackView *buttonsStack = [[UIStackView alloc] init];
    buttonsStack.axis = UILayoutConstraintAxisHorizontal;
    buttonsStack.alignment = UIStackViewAlignmentFill;
    buttonsStack.distribution = UIStackViewDistributionFillEqually;
    buttonsStack.spacing = 12.0;
    [contentStack addArrangedSubview:buttonsStack];

    UIButton *resetButton = [self footerButtonWithTitle:kLang(@"Reset")
                                              filled:NO
                                             selector:@selector(resetButtonTapped)];
    UIButton *applyButton = [self footerButtonWithTitle:kLang(@"Done")
                                              filled:YES
                                             selector:@selector(applyButtonTapped)];
    self.resetButton = resetButton;
    self.applyButton = applyButton;
    [buttonsStack addArrangedSubview:resetButton];
    [buttonsStack addArrangedSubview:applyButton];

    [NSLayoutConstraint activateConstraints:@[
        [handle.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:10.0],
        [handle.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [handle.widthAnchor constraintEqualToConstant:42.0],
        [handle.heightAnchor constraintEqualToConstant:5.0],

        [scrollView.topAnchor constraintEqualToAnchor:handle.bottomAnchor constant:16.0],
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16.0],

        [contentStack.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor constant:8.0],
        [contentStack.leadingAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.leadingAnchor constant:20.0],
        [contentStack.trailingAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.trailingAnchor constant:-20.0],
        [contentStack.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor],
    ]];
}

- (UIView *)optionSectionWithTitle:(NSString *)title buttons:(NSArray<UIButton *> *)buttons
{
    UIView *cardView = [[UIView alloc] init];
    cardView.translatesAutoresizingMaskIntoConstraints = NO;
    cardView.backgroundColor = UIColor.secondarySystemBackgroundColor;
    cardView.layer.cornerRadius = 24.0;
    cardView.layer.borderWidth = 1.0;
    cardView.layer.borderColor = [AppPrimaryClr colorWithAlphaComponent:0.10].CGColor;
    if (@available(iOS 13.0, *)) {
        cardView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14.0;
    [cardView addSubview:stack];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.numberOfLines = 1;
    titleLabel.font = [GM boldFontWithSize:17];
    titleLabel.textColor = UIColor.labelColor;
    titleLabel.text = title;
    [stack addArrangedSubview:titleLabel];

    UIStackView *buttonsRow = [[UIStackView alloc] initWithArrangedSubviews:buttons];
    buttonsRow.axis = UILayoutConstraintAxisHorizontal;
    buttonsRow.alignment = UIStackViewAlignmentFill;
    buttonsRow.distribution = UIStackViewDistributionFillEqually;
    buttonsRow.spacing = 10.0;
    [stack addArrangedSubview:buttonsRow];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:18.0],
        [stack.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:16.0],
        [stack.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-16.0],
        [stack.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-18.0],
    ]];

    return cardView;
}

- (UIButton *)optionButtonWithTitle:(NSString *)title tag:(NSInteger)tag action:(SEL)action
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tag = tag;
    button.titleLabel.font = [GM boldFontWithSize:15];
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintEqualToConstant:44.0].active = YES;
    return button;
}

- (UIButton *)footerButtonWithTitle:(NSString *)title filled:(BOOL)filled selector:(SEL)selector
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.titleLabel.font = [GM boldFontWithSize:16];
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintEqualToConstant:50.0].active = YES;
    [self applyFooterStyleToButton:button filled:filled];
    return button;
}

- (void)applyFooterStyleToButton:(UIButton *)button filled:(BOOL)filled
{
    UIButtonConfiguration *config = [UIButtonConfiguration filledButtonConfiguration];
    config.title = [button titleForState:UIControlStateNormal];
    config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    config.contentInsets = NSDirectionalEdgeInsetsMake(12.0, 18.0, 12.0, 18.0);
    if (filled) {
        config.baseBackgroundColor = AppPrimaryClr;
        config.baseForegroundColor = UIColor.whiteColor;
    } else {
        config.baseBackgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.10];
        config.baseForegroundColor = AppPrimaryClr;
    }
    button.configuration = config;
}

- (void)reloadVisibleSections
{
    BOOL showsAccessory = [self showsAccessoryFilters];
    BOOL showsService = [self showsServiceFilters];

    self.accessorySectionView.hidden = !showsAccessory;
    self.serviceSectionView.hidden = !showsService;
    self.emptyLabel.hidden = showsAccessory || showsService;
    self.resetButton.hidden = !(showsAccessory || showsService);
}

- (void)reloadFilterButtons
{
    for (UIButton *button in self.accessoryButtons) {
        [self applySelectionStyleToButton:button selected:(button.tag == self.accessoryFilter)];
    }

    for (UIButton *button in self.serviceButtons) {
        [self applySelectionStyleToButton:button selected:(button.tag == self.serviceFilter)];
    }
}

- (void)applySelectionStyleToButton:(UIButton *)button selected:(BOOL)selected
{
    UIButtonConfiguration *config = [UIButtonConfiguration filledButtonConfiguration];
    config.title = [button titleForState:UIControlStateNormal];
    config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    config.contentInsets = NSDirectionalEdgeInsetsMake(10.0, 10.0, 10.0, 10.0);
    config.baseBackgroundColor = selected
    ? AppPrimaryClr
    : [UIColor tertiarySystemFillColor];
    config.baseForegroundColor = selected
    ? UIColor.whiteColor
    : UIColor.labelColor;
    button.configuration = config;
    button.layer.cornerRadius = 18.0;
    button.layer.borderWidth = selected ? 0.0 : 1.0;
    button.layer.borderColor = selected
    ? UIColor.clearColor.CGColor
    : [UIColor.separatorColor colorWithAlphaComponent:0.35].CGColor;
}

- (void)accessoryButtonTapped:(UIButton *)sender
{
    self.accessoryFilter = (PPFilterAccessoryType)sender.tag;
    [self reloadFilterButtons];
}

- (void)serviceButtonTapped:(UIButton *)sender
{
    self.serviceFilter = (PPFilterServiceType)sender.tag;
    [self reloadFilterButtons];
}

- (void)resetButtonTapped
{
    self.accessoryFilter = PPFilterAccessoryAll;
    self.serviceFilter = PPFilterServiceAll;
    [self reloadFilterButtons];
}


- (void)applyButtonTapped
{
    if (self.onApply) {
        self.onApply(self.accessoryFilter, self.serviceFilter);
    }

    [self dismissViewControllerAnimated:YES completion:nil];
}
@end
