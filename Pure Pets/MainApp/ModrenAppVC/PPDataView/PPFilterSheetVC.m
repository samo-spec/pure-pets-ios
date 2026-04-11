//
//  PPFilterSheetVC.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 31/12/2025.
//  Refactored: Data-driven modern filter sheet.
//

#import "PPFilterSheetVC.h"

// ─── Internal cell for a single option pill ──────────────────────────
@interface PPFilterOptionPill : UIButton
@property (nonatomic, assign) NSInteger optionValue;
- (void)pp_applySelected:(BOOL)selected;
@end

@implementation PPFilterOptionPill

- (void)pp_applySelected:(BOOL)selected
{
    UIColor *brand = AppPrimaryClr ?: UIColor.systemOrangeColor;
    UIButtonConfiguration *cfg = [UIButtonConfiguration filledButtonConfiguration];
    cfg.title = [self titleForState:UIControlStateNormal];
    cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    cfg.contentInsets = NSDirectionalEdgeInsetsMake(10, 16, 10, 16);

    if (selected) {
        cfg.baseBackgroundColor = brand;
        cfg.baseForegroundColor = UIColor.whiteColor;
    } else {
        cfg.baseBackgroundColor = UIColor.tertiarySystemFillColor;
        cfg.baseForegroundColor = UIColor.labelColor;
    }

    cfg.titleTextAttributesTransformer =
    ^NSDictionary<NSAttributedStringKey, id> * _Nonnull(NSDictionary<NSAttributedStringKey, id> * _Nonnull incoming) {
        NSMutableDictionary *attrs = [incoming mutableCopy];
        attrs[NSFontAttributeName] = selected
            ? [GM boldFontWithSize:14]
            : [GM MidFontWithSize:14];
        return attrs;
    };

    self.configuration = cfg;

    self.layer.borderWidth = selected ? 0.0 : 0.8;
    self.layer.borderColor = selected
        ? UIColor.clearColor.CGColor
        : [UIColor.separatorColor colorWithAlphaComponent:0.30].CGColor;

    // Subtle shadow for selected state
    self.layer.shadowColor   = [brand colorWithAlphaComponent:0.5].CGColor;
    self.layer.shadowOpacity = selected ? 0.20 : 0.0;
    self.layer.shadowRadius  = selected ? 6.0  : 0.0;
    self.layer.shadowOffset  = selected ? CGSizeMake(0, 2) : CGSizeZero;
}

@end

// ─── Main VC ─────────────────────────────────────────────────────────

@interface PPFilterSheetVC ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UILabel *activeCountLabel;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSArray<PPFilterOptionPill *> *> *pillsByGroupID;
@end

@implementation PPFilterSheetVC

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClrLigter);
    self.pillsByGroupID = [NSMutableDictionary dictionary];
    [self pp_buildUI];
}

#pragma mark - Section title helper

- (NSString *)pp_sectionTitle
{
    switch (self.currentSection) {
        case PPDataSectionAccessories: return kLang(@"Accessories");
        case PPDataSectionServices:    return kLang(@"services");
        case PPDataSectionFood:        return kLang(@"Food");
        case PPDataSectionAds:
        default:                       return kLang(@"Ads");
    }
}

#pragma mark - Build UI

- (void)pp_buildUI
{
    UISemanticContentAttribute semantic = Language.semanticAttributeForCurrentLanguage;

    // ── Handle bar ──
    UIView *handle = [[UIView alloc] init];
    handle.translatesAutoresizingMaskIntoConstraints = NO;
    handle.backgroundColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.22];
    handle.layer.cornerRadius = 2.5;
    [self.view addSubview:handle];

    // ── Scroll ──
    UIScrollView *sv = [[UIScrollView alloc] init];
    sv.translatesAutoresizingMaskIntoConstraints = NO;
    sv.showsVerticalScrollIndicator = NO;
    sv.alwaysBounceVertical = YES;
    sv.semanticContentAttribute = semantic;
    [self.view addSubview:sv];
    self.scrollView = sv;

    // ── Content stack ──
    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 20.0;
    stack.semanticContentAttribute = semantic;
    [sv addSubview:stack];
    self.contentStack = stack;

    // ── Header row: title + active count ──
    UIView *headerRow = [[UIView alloc] init];
    headerRow.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:24];
    titleLabel.textColor = UIColor.labelColor;
    titleLabel.text = kLang(@"filterPPAction");
    titleLabel.textAlignment = Language.isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    [headerRow addSubview:titleLabel];

    UILabel *countLabel = [[UILabel alloc] init];
    countLabel.translatesAutoresizingMaskIntoConstraints = NO;
    countLabel.font = [GM boldFontWithSize:12];
    countLabel.textColor = UIColor.whiteColor;
    countLabel.textAlignment = NSTextAlignmentCenter;
    countLabel.backgroundColor = AppPrimaryClr ?: UIColor.systemOrangeColor;
    countLabel.layer.cornerRadius = 11;
    countLabel.clipsToBounds = YES;
    countLabel.hidden = YES;
    self.activeCountLabel = countLabel;
    [headerRow addSubview:countLabel];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.leadingAnchor constraintEqualToAnchor:headerRow.leadingAnchor],
        [titleLabel.centerYAnchor constraintEqualToAnchor:headerRow.centerYAnchor],
        [countLabel.leadingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor constant:8],
        [countLabel.centerYAnchor constraintEqualToAnchor:titleLabel.centerYAnchor],
        [countLabel.widthAnchor constraintGreaterThanOrEqualToConstant:22],
        [countLabel.heightAnchor constraintEqualToConstant:22],
        [headerRow.trailingAnchor constraintGreaterThanOrEqualToAnchor:countLabel.trailingAnchor],
        [headerRow.heightAnchor constraintGreaterThanOrEqualToConstant:30],
    ]];
    [stack addArrangedSubview:headerRow];

    // ── Subtitle (section name) ──
    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.font = [GM MidFontWithSize:15];
    subtitleLabel.textColor = UIColor.secondaryLabelColor;
    subtitleLabel.text = [self pp_sectionTitle];
    subtitleLabel.textAlignment = Language.isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    [stack addArrangedSubview:subtitleLabel];

    // ── Filter group cards ──
    if (self.filterState.groups.count == 0) {
        UILabel *emptyLabel = [[UILabel alloc] init];
        emptyLabel.numberOfLines = 0;
        emptyLabel.textAlignment = NSTextAlignmentCenter;
        emptyLabel.font = [GM MidFontWithSize:15];
        emptyLabel.textColor = UIColor.tertiaryLabelColor;
        emptyLabel.text = Language.isRTL
            ? @"لا توجد فلاتر اضافية لهذا القسم"
            : @"No filters available for this section.";
        [stack addArrangedSubview:emptyLabel];
    } else {
        for (PPFilterGroup *group in self.filterState.groups) {
            UIView *card = [self pp_cardForGroup:group];
            [stack addArrangedSubview:card];
        }
    }

    // ── Footer buttons ──
    UIStackView *footer = [[UIStackView alloc] init];
    footer.axis = UILayoutConstraintAxisHorizontal;
    footer.alignment = UIStackViewAlignmentFill;
    footer.distribution = UIStackViewDistributionFillEqually;
    footer.spacing = 12.0;
    footer.semanticContentAttribute = semantic;

    UIButton *resetBtn = [self pp_footerButtonWithTitle:kLang(@"Reset") filled:NO action:@selector(pp_resetTapped)];
    UIButton *applyBtn = [self pp_footerButtonWithTitle:kLang(@"Done") filled:YES action:@selector(pp_applyTapped)];
    [footer addArrangedSubview:resetBtn];
    [footer addArrangedSubview:applyBtn];
    [stack addArrangedSubview:footer];

    // ── Layout ──
    [NSLayoutConstraint activateConstraints:@[
        [handle.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:10],
        [handle.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [handle.widthAnchor constraintEqualToConstant:42],
        [handle.heightAnchor constraintEqualToConstant:5],

        [sv.topAnchor constraintEqualToAnchor:handle.bottomAnchor constant:16],
        [sv.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [sv.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [sv.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16],

        [stack.topAnchor constraintEqualToAnchor:sv.contentLayoutGuide.topAnchor constant:8],
        [stack.leadingAnchor constraintEqualToAnchor:sv.frameLayoutGuide.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:sv.frameLayoutGuide.trailingAnchor constant:-20],
        [stack.bottomAnchor constraintEqualToAnchor:sv.contentLayoutGuide.bottomAnchor constant:-8],
    ]];

    [self pp_updateActiveCount];
}

#pragma mark - Card builder

- (UIView *)pp_cardForGroup:(PPFilterGroup *)group
{
    UISemanticContentAttribute semantic = Language.semanticAttributeForCurrentLanguage;

    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = UIColor.secondarySystemBackgroundColor;
    card.layer.cornerRadius = 20.0;
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.12].CGColor;
    if (@available(iOS 13.0, *)) {
        card.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIStackView *inner = [[UIStackView alloc] init];
    inner.translatesAutoresizingMaskIntoConstraints = NO;
    inner.axis = UILayoutConstraintAxisVertical;
    inner.spacing = 14.0;
    inner.semanticContentAttribute = semantic;
    [card addSubview:inner];

    // Group title with icon
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.font = [GM boldFontWithSize:16];
    titleLabel.textColor = UIColor.labelColor;
    titleLabel.textAlignment = Language.isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;

    if (group.chipIconName.length > 0) {
        NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] init];
        UIImageSymbolConfiguration *iconCfg =
            [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium];
        UIImage *icon = [[UIImage systemImageNamed:group.chipIconName withConfiguration:iconCfg]
                         imageWithTintColor:AppPrimaryClr ?: UIColor.systemOrangeColor
                              renderingMode:UIImageRenderingModeAlwaysOriginal];
        if (icon) {
            NSTextAttachment *att = [[NSTextAttachment alloc] init];
            att.image = icon;
            att.bounds = CGRectMake(0, -2, 16, 16);
            [attr appendAttributedString:[NSAttributedString attributedStringWithAttachment:att]];
            [attr appendAttributedString:[[NSAttributedString alloc] initWithString:@"  "]];
        }
        [attr appendAttributedString:[[NSAttributedString alloc]
            initWithString:group.title
                attributes:@{NSFontAttributeName: [GM boldFontWithSize:16],
                              NSForegroundColorAttributeName: UIColor.labelColor}]];
        titleLabel.attributedText = attr;
    } else {
        titleLabel.text = group.title;
    }
    [inner addArrangedSubview:titleLabel];

    // Options flow layout (wrap-capable via stack of rows)
    UIView *optionsContainer = [self pp_flowLayoutForGroup:group];
    [inner addArrangedSubview:optionsContainer];

    [NSLayoutConstraint activateConstraints:@[
        [inner.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
        [inner.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [inner.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [inner.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16],
    ]];

    return card;
}

- (UIView *)pp_flowLayoutForGroup:(PPFilterGroup *)group
{
    // Use a horizontal stack with wrapping via multiple rows
    UIStackView *row = [[UIStackView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.distribution = UIStackViewDistributionFillProportionally;
    row.spacing = 8.0;
    row.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    NSMutableArray<PPFilterOptionPill *> *pills = [NSMutableArray array];

    for (PPFilterOption *opt in group.options) {
        PPFilterOptionPill *pill = [PPFilterOptionPill buttonWithType:UIButtonTypeSystem];
        pill.translatesAutoresizingMaskIntoConstraints = NO;
        pill.optionValue = opt.value;
        [pill setTitle:opt.title forState:UIControlStateNormal];
        [pill pp_applySelected:(opt.value == group.selectedValue)];
        [pill.heightAnchor constraintEqualToConstant:40].active = YES;
        pill.accessibilityIdentifier = [NSString stringWithFormat:@"pp.filter.%@.%ld", group.filterID, (long)opt.value];

        // Store group filterID in layer.name for action routing
        pill.layer.name = group.filterID;
        [pill addTarget:self action:@selector(pp_pillTapped:) forControlEvents:UIControlEventTouchUpInside];

        [pills addObject:pill];
        [row addArrangedSubview:pill];
    }

    self.pillsByGroupID[group.filterID] = pills;
    return row;
}

#pragma mark - Actions

- (void)pp_pillTapped:(PPFilterOptionPill *)pill
{
    NSString *groupID = pill.layer.name;
    PPFilterGroup *group = [self.filterState groupForID:groupID];
    if (!group) return;

    group.selectedValue = pill.optionValue;
    [PPFunc triggerLightHaptic];

    // Update pill visuals for this group
    NSArray<PPFilterOptionPill *> *pills = self.pillsByGroupID[groupID];
    for (PPFilterOptionPill *p in pills) {
        [UIView animateWithDuration:0.18 animations:^{
            [p pp_applySelected:(p.optionValue == group.selectedValue)];
        }];
    }

    [self pp_updateActiveCount];
}

- (void)pp_resetTapped
{
    [self.filterState resetAll];
    [PPFunc triggerMediumHaptic];

    for (PPFilterGroup *group in self.filterState.groups) {
        NSArray<PPFilterOptionPill *> *pills = self.pillsByGroupID[group.filterID];
        for (PPFilterOptionPill *p in pills) {
            [UIView animateWithDuration:0.18 animations:^{
                [p pp_applySelected:(p.optionValue == group.selectedValue)];
            }];
        }
    }

    [self pp_updateActiveCount];
}

- (void)pp_applyTapped
{
    if (self.onApply) {
        self.onApply(self.filterState);
    }
    [PPFunc triggerLightHaptic];
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Active count badge

- (void)pp_updateActiveCount
{
    NSInteger count = self.filterState.activeFilterCount;
    if (count > 0) {
        self.activeCountLabel.text = [NSString stringWithFormat:@" %ld ", (long)count];
        self.activeCountLabel.hidden = NO;
    } else {
        self.activeCountLabel.hidden = YES;
    }
}

#pragma mark - Footer button helper

- (UIButton *)pp_footerButtonWithTitle:(NSString *)title filled:(BOOL)filled action:(SEL)action
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintEqualToConstant:50].active = YES;

    UIButtonConfiguration *cfg = [UIButtonConfiguration filledButtonConfiguration];
    cfg.title = title;
    cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    cfg.contentInsets = NSDirectionalEdgeInsetsMake(12, 18, 12, 18);

    UIColor *brand = AppPrimaryClr ?: UIColor.systemOrangeColor;
    if (filled) {
        cfg.baseBackgroundColor = brand;
        cfg.baseForegroundColor = UIColor.whiteColor;
    } else {
        cfg.baseBackgroundColor = [brand colorWithAlphaComponent:0.10];
        cfg.baseForegroundColor = brand;
    }
    button.configuration = cfg;
    return button;
}

@end
