#import "PPSearchFilterView.h"

static CGFloat const PPFilterChipHeight = 32.0;
static CGFloat const PPFilterSectionSpacing = 12.0;
static CGFloat const PPFilterChipSpacing = 8.0;

@interface PPFilterChip : UIButton
@property (nonatomic, copy) NSString *filterKey;
@property (nonatomic, copy) id filterValue;
@property (nonatomic, assign) BOOL allowsMultipleSelection;
@end

@implementation PPFilterChip
@end

@interface PPSearchFilterView ()
@property (nonatomic, strong) UIStackView *containerStack;
@property (nonatomic, strong) NSMutableArray<PPFilterChip *> *allChips;
@property (nonatomic, strong) UIButton *resetButton;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *sectionConfigs;
@property (nonatomic, assign) BOOL contentReady;
@end

@implementation PPSearchFilterView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    _allChips = [NSMutableArray array];
    _sectionConfigs = [NSMutableDictionary dictionary];
    _contentReady = NO;

    self.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    _containerStack = [[UIStackView alloc] init];
    _containerStack.translatesAutoresizingMaskIntoConstraints = NO;
    _containerStack.axis = UILayoutConstraintAxisVertical;
    _containerStack.spacing = PPFilterSectionSpacing;
    _containerStack.alignment = UIStackViewAlignmentFill;
    _containerStack.distribution = UIStackViewDistributionFill;
    [self addSubview:_containerStack];

    [NSLayoutConstraint activateConstraints:@[
        [_containerStack.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_containerStack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_containerStack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_containerStack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    ]];

    return self;
}

- (BOOL)hasContent {
    return self.contentReady;
}

- (void)addSectionWithTitle:(NSString *)title items:(NSArray<NSDictionary *> *)items key:(NSString *)key allowMultiple:(BOOL)allowMultiple {
    UIView *sectionView = [[UIView alloc] init];
    sectionView.translatesAutoresizingMaskIntoConstraints = NO;
    sectionView.backgroundColor = [[GM AppForegroundColor] colorWithAlphaComponent:1];
    sectionView.layer.cornerRadius = 20;
    sectionView.layer.masksToBounds = NO;
    sectionView.layer.borderWidth = 0.75;
    [sectionView pp_setBorderColor:[GM.appPrimaryColor colorWithAlphaComponent:0.10]];

    UILabel *sectionLabel = [[UILabel alloc] init];
    sectionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    sectionLabel.font = [GM boldFontWithSize:13];
    sectionLabel.textColor = GM.SecondaryTextColor;
    sectionLabel.text = title;
    sectionLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [sectionView addSubview:sectionLabel];

    UIScrollView *chipScrollView = [[UIScrollView alloc] init];
    chipScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    chipScrollView.backgroundColor = UIColor.clearColor;
    chipScrollView.showsHorizontalScrollIndicator = NO;
    chipScrollView.showsVerticalScrollIndicator = NO;
    chipScrollView.alwaysBounceHorizontal = YES;
    chipScrollView.alwaysBounceVertical = NO;
    chipScrollView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [sectionView addSubview:chipScrollView];

    UIStackView *chipRow = [[UIStackView alloc] init];
    chipRow.translatesAutoresizingMaskIntoConstraints = NO;
    chipRow.axis = UILayoutConstraintAxisHorizontal;
    chipRow.spacing = PPFilterChipSpacing;
    chipRow.alignment = UIStackViewAlignmentCenter;
    chipRow.distribution = UIStackViewDistributionFill;
    chipRow.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [chipScrollView addSubview:chipRow];

    [NSLayoutConstraint activateConstraints:@[
        [sectionLabel.topAnchor constraintEqualToAnchor:sectionView.topAnchor constant:14],
        [sectionLabel.leadingAnchor constraintEqualToAnchor:sectionView.leadingAnchor constant:14],
        [sectionLabel.trailingAnchor constraintEqualToAnchor:sectionView.trailingAnchor constant:-14],

        [chipScrollView.topAnchor constraintEqualToAnchor:sectionLabel.bottomAnchor constant:10],
        [chipScrollView.leadingAnchor constraintEqualToAnchor:sectionView.leadingAnchor constant:14],
        [chipScrollView.trailingAnchor constraintEqualToAnchor:sectionView.trailingAnchor constant:-14],
        [chipScrollView.bottomAnchor constraintEqualToAnchor:sectionView.bottomAnchor constant:-14],
        [chipScrollView.heightAnchor constraintEqualToConstant:PPFilterChipHeight],

        [chipRow.topAnchor constraintEqualToAnchor:chipScrollView.contentLayoutGuide.topAnchor],
        [chipRow.leadingAnchor constraintEqualToAnchor:chipScrollView.contentLayoutGuide.leadingAnchor],
        [chipRow.trailingAnchor constraintEqualToAnchor:chipScrollView.contentLayoutGuide.trailingAnchor],
        [chipRow.bottomAnchor constraintEqualToAnchor:chipScrollView.contentLayoutGuide.bottomAnchor],
        [chipRow.heightAnchor constraintEqualToAnchor:chipScrollView.frameLayoutGuide.heightAnchor],
    ]];

    for (NSDictionary *item in items) {
        PPFilterChip *chip = [PPFilterChip buttonWithType:UIButtonTypeCustom];
        chip.translatesAutoresizingMaskIntoConstraints = NO;
        [chip setTitle:item[@"title"] forState:UIControlStateNormal];
        chip.titleLabel.font = [GM MidFontWithSize:13];
        chip.filterKey = key;
        chip.filterValue = item[@"id"];
        chip.allowsMultipleSelection = allowMultiple;
        chip.layer.cornerRadius = PPFilterChipHeight / 2.0;
        chip.layer.masksToBounds = YES;
        chip.adjustsImageWhenHighlighted = NO;
        chip.contentEdgeInsets = UIEdgeInsetsMake(0, 14, 0, 14);
        [chip addTarget:self action:@selector(pp_chipTapped:) forControlEvents:UIControlEventTouchUpInside];
        [chip addTarget:self action:@selector(pp_chipTouchDown:) forControlEvents:UIControlEventTouchDown];
        [chip addTarget:self action:@selector(pp_chipTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
        [chip.heightAnchor constraintEqualToConstant:PPFilterChipHeight].active = YES;

        [self pp_styleChip:chip selected:NO];
        [chipRow addArrangedSubview:chip];
        [self.allChips addObject:chip];
    }

    [self.containerStack addArrangedSubview:sectionView];
    self.contentReady = YES;
    [self invalidateIntrinsicContentSize];
}

- (void)addResetButtonWithTitle:(NSString *)title {
    if (self.resetButton) return;

    self.resetButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.resetButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.resetButton setTitle:title forState:UIControlStateNormal];
    self.resetButton.titleLabel.font = [GM MidFontWithSize:14];
    [self.resetButton setTitleColor:GM.appPrimaryColor forState:UIControlStateNormal];
    self.resetButton.backgroundColor = [GM.appPrimaryColor colorWithAlphaComponent:0.08];
    self.resetButton.layer.cornerRadius = 16;
    self.resetButton.layer.masksToBounds = YES;
    self.resetButton.contentEdgeInsets = UIEdgeInsetsMake(10, 16, 10, 16);
    [self.resetButton addTarget:self action:@selector(pp_resetTapped) forControlEvents:UIControlEventTouchUpInside];

    UIView *resetContainer = [[UIView alloc] init];
    resetContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [resetContainer addSubview:self.resetButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.resetButton.topAnchor constraintEqualToAnchor:resetContainer.topAnchor],
        [self.resetButton.centerXAnchor constraintEqualToAnchor:resetContainer.centerXAnchor],
        [self.resetButton.bottomAnchor constraintEqualToAnchor:resetContainer.bottomAnchor],
    ]];

    [self.containerStack addArrangedSubview:resetContainer];
    [self invalidateIntrinsicContentSize];
}

- (void)pp_chipTapped:(PPFilterChip *)chip {
    BOOL shouldSelect = !chip.selected;
    if (shouldSelect && !chip.allowsMultipleSelection) {
        for (PPFilterChip *otherChip in self.allChips) {
            if (otherChip == chip || ![otherChip.filterKey isEqualToString:chip.filterKey]) {
                continue;
            }
            otherChip.selected = NO;
            [self pp_styleChip:otherChip selected:NO];
        }
    }

    chip.selected = shouldSelect;
    [self pp_styleChip:chip selected:chip.selected];

    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [feedback impactOccurred];
    }

    if ([self.delegate respondsToSelector:@selector(searchFilterView:didSelectFilters:)]) {
        [self.delegate searchFilterView:self didSelectFilters:[self activeFilters]];
    }
}

- (void)pp_chipTouchDown:(UIButton *)chip {
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }
    [UIView animateWithDuration:0.09
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        chip.transform = CGAffineTransformMakeScale(0.96, 0.96);
    } completion:nil];
}

- (void)pp_chipTouchUp:(UIButton *)chip {
    if (UIAccessibilityIsReduceMotionEnabled()) {
        chip.transform = CGAffineTransformIdentity;
        return;
    }
    [UIView animateWithDuration:0.18
                          delay:0.0
         usingSpringWithDamping:0.80
          initialSpringVelocity:0.24
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        chip.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_styleChip:(UIButton *)chip selected:(BOOL)selected {
    if (selected) {
        chip.backgroundColor = GM.appPrimaryColor;
        [chip setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        chip.layer.borderWidth = 0;
    } else {
        chip.backgroundColor = [GM.appPrimaryColor colorWithAlphaComponent:0.08];
        [chip setTitleColor:GM.appPrimaryColor forState:UIControlStateNormal];
        chip.layer.borderWidth = 0.5;
        chip.layer.borderColor = [GM.appPrimaryColor colorWithAlphaComponent:0.18].CGColor;
    }
}

- (void)pp_resetTapped {
    [self resetAll];
    if ([self.delegate respondsToSelector:@selector(searchFilterViewDidReset:)]) {
        [self.delegate searchFilterViewDidReset:self];
    }
}

- (void)resetAll {
    for (PPFilterChip *chip in self.allChips) {
        chip.selected = NO;
        [self pp_styleChip:chip selected:NO];
    }
}

- (void)applySelectedFilters:(NSDictionary<NSString *, id> *)filters notify:(BOOL)notify {
    for (PPFilterChip *chip in self.allChips) {
        id selectedValue = filters[chip.filterKey];
        BOOL selected = NO;
        if ([selectedValue isKindOfClass:[NSArray class]]) {
            selected = [(NSArray *)selectedValue containsObject:chip.filterValue];
        } else if (selectedValue) {
            selected = [chip.filterValue isEqual:selectedValue] ||
                [[chip.filterValue description] isEqualToString:[selectedValue description]];
        }
        chip.selected = selected;
        [self pp_styleChip:chip selected:selected];
    }

    if (notify && [self.delegate respondsToSelector:@selector(searchFilterView:didSelectFilters:)]) {
        [self.delegate searchFilterView:self didSelectFilters:[self activeFilters]];
    }
}

- (void)removeAllSections {
    for (UIView *view in self.containerStack.arrangedSubviews.copy) {
        [self.containerStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    [self.allChips removeAllObjects];
    [self.sectionConfigs removeAllObjects];
    self.resetButton = nil;
    self.contentReady = NO;
    [self invalidateIntrinsicContentSize];
}

- (NSDictionary<NSString *, id> *)activeFilters {
    NSMutableDictionary *filters = [NSMutableDictionary dictionary];
    for (PPFilterChip *chip in self.allChips) {
        if (chip.selected && chip.filterKey.length > 0) {
            filters[chip.filterKey] = chip.filterValue;
        }
    }
    return filters;
}

- (CGSize)intrinsicContentSize {
    if (!self.contentReady) return CGSizeMake(UIViewNoIntrinsicMetric, 0);
    [self layoutIfNeeded];
    CGFloat width = CGRectGetWidth(self.bounds);
    if (width <= 0) {
        width = MAX(1.0, UIScreen.mainScreen.bounds.size.width - 32.0);
    }
    CGSize targetSize = CGSizeMake(width, UILayoutFittingCompressedSize.height);
    CGFloat height = [self.containerStack systemLayoutSizeFittingSize:targetSize
                                        withHorizontalFittingPriority:UILayoutPriorityRequired
                                              verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height;
    return CGSizeMake(UIViewNoIntrinsicMetric, height);
}

@end
