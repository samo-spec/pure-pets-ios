//
//  PPHomeLocationSheetViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/11/26.
//

#import "PPHomeLocationSheetViewController.h"


@implementation PPHomeLocationActionCard {
    UIView *_iconChipView;
    UIImageView *_iconView;
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
    UIImageView *_chevronView;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = NO;

    _iconChipView = [[UIView alloc] init];
    _iconChipView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconChipView.userInteractionEnabled = NO;
    _iconChipView.layer.cornerRadius = 18.0;
    _iconChipView.layer.cornerCurve = kCACornerCurveContinuous;
    [self addSubview:_iconChipView];

    _iconView = [[UIImageView alloc] init];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    [_iconChipView addSubview:_iconView];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [GM boldFontWithSize:16] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    _titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    _titleLabel.numberOfLines = 1;
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self addSubview:_titleLabel];

    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.font = [GM MidFontWithSize:12] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    _subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _subtitleLabel.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.64] ?: UIColor.secondaryLabelColor;
    _subtitleLabel.numberOfLines = 2;
    _subtitleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [self addSubview:_subtitleLabel];

    UIImage *chevronImage =
        [UIImage pp_symbolNamed:(Language.isRTL ? @"chevron.left" : @"chevron.right")
                      pointSize:12
                         weight:UIImageSymbolWeightBold
                          scale:UIImageSymbolScaleSmall
                        palette:@[[AppPrimaryTextClr colorWithAlphaComponent:0.46] ?: UIColor.secondaryLabelColor]
                   makeTemplate:YES];
    _chevronView = [[UIImageView alloc] initWithImage:chevronImage];
    _chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    _chevronView.contentMode = UIViewContentModeScaleAspectFit;
    [self addSubview:_chevronView];

    [NSLayoutConstraint activateConstraints:@[
        [_iconChipView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14.0],
        [_iconChipView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_iconChipView.widthAnchor constraintEqualToConstant:36.0],
        [_iconChipView.heightAnchor constraintEqualToConstant:36.0],

        [_iconView.centerXAnchor constraintEqualToAnchor:_iconChipView.centerXAnchor],
        [_iconView.centerYAnchor constraintEqualToAnchor:_iconChipView.centerYAnchor],
        [_iconView.widthAnchor constraintEqualToConstant:18.0],
        [_iconView.heightAnchor constraintEqualToConstant:18.0],

        [_chevronView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16.0],
        [_chevronView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_chevronView.widthAnchor constraintEqualToConstant:12.0],
        [_chevronView.heightAnchor constraintEqualToConstant:12.0],

        [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconChipView.trailingAnchor constant:12.0],
        [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_chevronView.leadingAnchor constant:-10.0],
        [_titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:14.0],

        [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_chevronView.leadingAnchor constant:-10.0],
        [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:3.0],
        [_subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.bottomAnchor constant:-14.0],
        [self.heightAnchor constraintGreaterThanOrEqualToConstant:70.0]
    ]];

    [self addTarget:self action:@selector(pp_touchDown) forControlEvents:UIControlEventTouchDown];
    [self addTarget:self action:@selector(pp_touchUp) forControlEvents:UIControlEventTouchUpInside];
    [self addTarget:self action:@selector(pp_touchUp) forControlEvents:UIControlEventTouchUpOutside];
    [self addTarget:self action:@selector(pp_touchUp) forControlEvents:UIControlEventTouchCancel];

    return self;
}

- (void)configureWithTitle:(NSString *)title
                  subtitle:(nullable NSString *)subtitle
                  iconName:(nullable NSString *)iconName
                 tintColor:(UIColor *)tintColor
               showsChevron:(BOOL)showsChevron
{
    UIColor *resolvedTint = tintColor ?: (AppPrimaryClr ?: UIColor.systemPinkColor);
    _titleLabel.text = PPSafeString(title);
    _subtitleLabel.text = PPSafeString(subtitle);
    _subtitleLabel.hidden = (PPSafeString(subtitle).length == 0);
    _chevronView.hidden = !showsChevron;
    _iconChipView.backgroundColor = [resolvedTint colorWithAlphaComponent:0.14];
    _iconChipView.layer.borderWidth = 1.0;
    _iconChipView.layer.borderColor = [resolvedTint colorWithAlphaComponent:0.08].CGColor;
    _iconView.tintColor = resolvedTint;
    _iconView.image =
        [UIImage pp_symbolNamed:PPSafeString(iconName)
                      pointSize:17
                         weight:UIImageSymbolWeightSemibold
                          scale:UIImageSymbolScaleMedium
                        palette:@[resolvedTint]
                   makeTemplate:YES];
}

- (void)pp_touchDown
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    [UIView animateWithDuration:0.12
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.transform = CGAffineTransformMakeScale(0.98, 0.98);
        self.alpha = 0.97;
    } completion:nil];
}

- (void)pp_touchUp
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.transform = CGAffineTransformIdentity;
        self.alpha = 1.0;
        return;
    }

    [UIView animateWithDuration:0.24
                          delay:0.0
         usingSpringWithDamping:0.80
          initialSpringVelocity:0.30
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.transform = CGAffineTransformIdentity;
        self.alpha = 1.0;
    } completion:nil];
}

@end





@implementation PPHomeLocationSheetViewController {
    UIScrollView *_scrollView;
    UIStackView *_contentStack;
    UIStackView *_recentStack;
    PPHomeLocationActionCard *_currentCard;
    PPHomeLocationActionCard *_useCurrentCard;
    PPHomeLocationActionCard *_changeAreaCard;
    PPHomeLocationActionCard *_settingsCard;
    UILabel *_recentTitleLabel;
    UIView *_heroSurfaceView;
    UIButton *_backButton;
    BOOL _didAnimateEntrance;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self pp_buildUI];
    [self pp_applySheetConfigurationIfNeeded];
    [self pp_reloadContent];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (_didAnimateEntrance || UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    _didAnimateEntrance = YES;
    NSArray<UIView *> *arrangedViews = _contentStack.arrangedSubviews ?: @[];
    [_recentStack.arrangedSubviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull view, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)idx;
        (void)stop;
    }];

    NSInteger index = 0;
    for (UIView *view in arrangedViews) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0.0, 14.0);
        [UIView animateWithDuration:0.34
                              delay:0.03 * index
             usingSpringWithDamping:0.86
              initialSpringVelocity:0.18
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
        index += 1;
    }
    
    
}

- (void)pp_buildUI
{
    UIView *backdropView = [[UIView alloc] init];
    backdropView.translatesAutoresizingMaskIntoConstraints = NO;
    backdropView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    backdropView.layer.cornerRadius = PPIOS26() ? 34.0 : 28.0;
    backdropView.layer.cornerCurve = kCACornerCurveContinuous;
    backdropView.clipsToBounds = YES;
    [self.view addSubview:backdropView];

    _scrollView = [[UIScrollView alloc] init];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.showsVerticalScrollIndicator = NO;
    _scrollView.alwaysBounceVertical = YES;
    _scrollView.backgroundColor = UIColor.clearColor;
    [backdropView addSubview:_scrollView];

    // Back button (icon only)
    UIImage *backIcon = [UIImage pp_symbolNamed:(Language.isRTL ? @"chevron.right" : @"chevron.left")
                                      pointSize:16
                                         weight:UIImageSymbolWeightSemibold
                                          scale:UIImageSymbolScaleMedium
                                        palette:@[AppPrimaryTextClr ?: UIColor.labelColor]
                                   makeTemplate:YES];
    _backButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _backButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_backButton setImage:backIcon forState:UIControlStateNormal];
    _backButton.tintColor = AppPrimaryTextClr ?: UIColor.labelColor;
    _backButton.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.5];
    _backButton.layer.cornerRadius = 16.0;
    _backButton.layer.cornerCurve = kCACornerCurveContinuous;
    _backButton.clipsToBounds = YES;
    [_backButton addTarget:self action:@selector(pp_handleBack) forControlEvents:UIControlEventTouchUpInside];
    [backdropView addSubview:_backButton];

    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    contentView.backgroundColor = UIColor.clearColor;
    [_scrollView addSubview:contentView];

    _contentStack = [[UIStackView alloc] init];
    _contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    _contentStack.axis = UILayoutConstraintAxisVertical;
    _contentStack.spacing = 14.0;
    _contentStack.alignment = UIStackViewAlignmentFill;
    [_scrollView addSubview:_contentStack];

    _heroSurfaceView = [[UIView alloc] init];
    _heroSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    _heroSurfaceView.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.94] ?: [UIColor secondarySystemBackgroundColor];
    _heroSurfaceView.layer.cornerRadius = 26.0;
    _heroSurfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    _heroSurfaceView.layer.borderWidth = 0.8;
    _heroSurfaceView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.08].CGColor;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:24] ?: [UIFont systemFontOfSize:24.0 weight:UIFontWeightBold];
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.numberOfLines = 2;
    titleLabel.tag = 601;
    [_heroSurfaceView addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:14] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    subtitleLabel.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.62] ?: UIColor.secondaryLabelColor;
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.tag = 602;
    [_heroSurfaceView addSubview:subtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:_heroSurfaceView.topAnchor constant:18.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:_heroSurfaceView.leadingAnchor constant:18.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:_heroSurfaceView.trailingAnchor constant:-18.0],
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [subtitleLabel.bottomAnchor constraintEqualToAnchor:_heroSurfaceView.bottomAnchor constant:-18.0]
    ]];

    _currentCard = [[PPHomeLocationActionCard alloc] init];
    _useCurrentCard = [[PPHomeLocationActionCard alloc] init];
    _changeAreaCard = [[PPHomeLocationActionCard alloc] init];
    _settingsCard = [[PPHomeLocationActionCard alloc] init];
    [_useCurrentCard addTarget:self action:@selector(pp_handleUseCurrentLocation) forControlEvents:UIControlEventTouchUpInside];
    [_changeAreaCard addTarget:self action:@selector(pp_handleChangeArea) forControlEvents:UIControlEventTouchUpInside];
    [_settingsCard addTarget:self action:@selector(pp_handleOpenSettings) forControlEvents:UIControlEventTouchUpInside];

    _recentTitleLabel = [[UILabel alloc] init];
    _recentTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _recentTitleLabel.font = [GM boldFontWithSize:14] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    _recentTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _recentTitleLabel.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.74] ?: UIColor.secondaryLabelColor;

    _recentStack = [[UIStackView alloc] init];
    _recentStack.translatesAutoresizingMaskIntoConstraints = NO;
    _recentStack.axis = UILayoutConstraintAxisVertical;
    _recentStack.spacing = 10.0;
    _recentStack.alignment = UIStackViewAlignmentFill;

    [_contentStack addArrangedSubview:_heroSurfaceView];
    [_contentStack addArrangedSubview:_currentCard];
    [_contentStack addArrangedSubview:_useCurrentCard];
    [_contentStack addArrangedSubview:_changeAreaCard];
    [_contentStack addArrangedSubview:_settingsCard];
    [_contentStack addArrangedSubview:_recentTitleLabel];
    [_contentStack addArrangedSubview:_recentStack];

    [NSLayoutConstraint activateConstraints:@[
        [backdropView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [backdropView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [backdropView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [backdropView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [_backButton.topAnchor constraintEqualToAnchor:backdropView.topAnchor constant:14.0],
        [_backButton.leadingAnchor constraintEqualToAnchor:backdropView.leadingAnchor constant:16.0],
        [_backButton.widthAnchor constraintEqualToConstant:32.0],
        [_backButton.heightAnchor constraintEqualToConstant:32.0],

        [_scrollView.topAnchor constraintEqualToAnchor:_backButton.bottomAnchor constant:8.0],
        [_scrollView.leadingAnchor constraintEqualToAnchor:backdropView.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:backdropView.trailingAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:backdropView.bottomAnchor],

        [contentView.topAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.topAnchor],
        [contentView.leadingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.trailingAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.bottomAnchor],
        [contentView.widthAnchor constraintEqualToAnchor:_scrollView.frameLayoutGuide.widthAnchor],

        [_contentStack.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:20.0],
        [_contentStack.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:16.0],
        [_contentStack.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-16.0],
        [_contentStack.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-24.0]
    ]];
}

- (void)pp_applySheetConfigurationIfNeeded
{
    self.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = self.sheetPresentationController;
        if (!sheet) {
            return;
        }
        sheet.detents = @[
            UISheetPresentationControllerDetent.mediumDetent,
            UISheetPresentationControllerDetent.largeDetent
        ];
        sheet.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierMedium;
        sheet.prefersGrabberVisible = YES;
        sheet.prefersScrollingExpandsWhenScrolledToEdge = NO;
        sheet.preferredCornerRadius = PPIOS26() ? 34.0 : 28.0;
        if (@available(iOS 16.0, *)) {
            sheet.prefersEdgeAttachedInCompactHeight = YES;
            sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = YES;
        }
    }
}

- (void)pp_reloadContent
{
    UILabel *titleLabel = [_heroSurfaceView viewWithTag:601];
    UILabel *subtitleLabel = [_heroSurfaceView viewWithTag:602];
    titleLabel.text = PPSafeString(self.sheetTitleText);
    subtitleLabel.text = PPSafeString(self.sheetSubtitleText);

    [_currentCard configureWithTitle:(self.currentLocationTitle.length > 0 ? self.currentLocationTitle : (kLang(@"Select your location") ?: @"Select your location"))
                            subtitle:PPSafeString(self.currentLocationSubtitle)
                            iconName:@"location.fill"
                           tintColor:(AppPrimaryClr ?: UIColor.systemPinkColor)
                         showsChevron:NO];

    [_useCurrentCard configureWithTitle:(kLang(@"home_location_sheet_use_current") ?: @"Use current location")
                               subtitle:(kLang(@"home_location_sheet_use_current_subtitle") ?: @"Refresh nearby pets and services using GPS")
                               iconName:@"location.north.fill"
                              tintColor:UIColor.systemBlueColor
                            showsChevron:YES];

    [_changeAreaCard configureWithTitle:(kLang(@"home_location_sheet_change_area") ?: @"Change area")
                               subtitle:(kLang(@"home_location_sheet_change_area_subtitle") ?: @"Pick another city or neighborhood")
                               iconName:@"map.fill"
                              tintColor:UIColor.systemOrangeColor
                            showsChevron:YES];

    [_settingsCard configureWithTitle:(kLang(@"Open Settings") ?: @"Open Settings")
                             subtitle:(kLang(@"home_location_sheet_open_settings_subtitle") ?: @"Allow location access to keep nearby results accurate")
                             iconName:@"gearshape.fill"
                            tintColor:UIColor.systemIndigoColor
                          showsChevron:YES];
    _useCurrentCard.hidden = !self.showsUseCurrentLocationAction;
    _settingsCard.hidden = !self.showsOpenSettingsAction;

    _recentTitleLabel.text = kLang(@"home_location_sheet_recent_title") ?: @"Recent locations";
    _recentTitleLabel.hidden = (self.recentLocations.count == 0);

    for (UIView *subview in _recentStack.arrangedSubviews.copy) {
        [_recentStack removeArrangedSubview:subview];
        [subview removeFromSuperview];
    }

    NSInteger index = 0;
    for (NSDictionary *record in self.recentLocations ?: @[]) {
        PPHomeLocationActionCard *card = [[PPHomeLocationActionCard alloc] init];
        card.tag = index;
        NSString *title = PPSafeString(record[@"title"]);
        NSString *subtitle = PPSafeString(record[@"subtitle"]);
        if (subtitle.length == 0) {
            subtitle = kLang(@"home_location_sheet_recent_subtitle") ?: @"Tap to reuse this location";
        }
        [card configureWithTitle:title
                        subtitle:subtitle
                        iconName:@"clock.arrow.circlepath"
                       tintColor:UIColor.systemTealColor
                     showsChevron:YES];
        [card addTarget:self action:@selector(pp_handleRecentLocationTap:) forControlEvents:UIControlEventTouchUpInside];
        [_recentStack addArrangedSubview:card];
        index += 1;
    }
    _recentStack.hidden = (self.recentLocations.count == 0);
}

- (void)pp_handleUseCurrentLocation
{
    [self pp_dismissThenRun:self.onUseCurrentLocation];
}

- (void)pp_handleChangeArea
{
    [self pp_dismissThenRun:self.onChangeArea];
}

- (void)pp_handleOpenSettings
{
    [self pp_dismissThenRun:self.onOpenSettings];
}

- (void)pp_handleRecentLocationTap:(PPHomeLocationActionCard *)sender
{
    NSInteger index = sender.tag;
    if (index < 0 || index >= (NSInteger)self.recentLocations.count) {
        return;
    }

    NSDictionary *record = self.recentLocations[(NSUInteger)index];
    void (^selectBlock)(void) = ^{
        if (self.onSelectRecentLocation) {
            self.onSelectRecentLocation(record);
        }
    };
    [self pp_dismissThenRun:selectBlock];
}

- (void)pp_handleBack
{
    [self pp_dismissThenRun:nil];
}

- (void)pp_dismissThenRun:(dispatch_block_t)block
{
    if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:block];
    } else if (block) {
        block();
    }
}

@end
