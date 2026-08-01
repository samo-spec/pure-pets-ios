#import "OrderCell.h"
#import "OrderModel.h"
#import "GM.h"
#import "PPChatsFunc.h"
#import "PPOrderStatusAppearance.h"
#import "UIImageView+YYWebImage.h"

#pragma mark - PPOrderCellStatusLabel (Private Intercept Label)

@interface PPOrderCellStatusLabel : UILabel
@property (nonatomic, copy, nullable) void (^onStatusUpdate)(UIColor * _Nullable statusColor, NSString * _Nullable statusText, NSString * _Nullable dateText);
@end

@implementation PPOrderCellStatusLabel

- (void)setAttributedText:(NSAttributedString *)attributedText {
    [super setAttributedText:attributedText];
    [self parseAndUpdate];
}

- (void)setText:(NSString *)text {
    [super setText:text];
    [self parseAndUpdate];
}

- (void)parseAndUpdate {
    NSAttributedString *attributedText = self.attributedText;
    if (!attributedText || attributedText.length == 0) {
        if (self.onStatusUpdate) {
            self.onStatusUpdate(nil, nil, nil);
        }
        return;
    }
    
    NSString *string = attributedText.string;
    UIColor *statusColor = nil;
    if (attributedText.length > 0) {
        statusColor = [attributedText attribute:NSForegroundColorAttributeName atIndex:0 effectiveRange:NULL];
    }
    
    NSString *statusText = nil;
    NSString *dateText = nil;
    
    if ([string hasPrefix:@"● "]) {
        NSString *remaining = [string substringFromIndex:2];
        NSRange doubleSpaceRange = [remaining rangeOfString:@"  "];
        if (doubleSpaceRange.location != NSNotFound) {
            statusText = [remaining substringToIndex:doubleSpaceRange.location];
            dateText = [remaining substringFromIndex:doubleSpaceRange.location + doubleSpaceRange.length];
        } else {
            statusText = remaining;
        }
    } else if ([string hasPrefix:@"●"]) {
        NSString *remaining = [string substringFromIndex:1];
        NSRange doubleSpaceRange = [remaining rangeOfString:@"  "];
        if (doubleSpaceRange.location != NSNotFound) {
            statusText = [remaining substringToIndex:doubleSpaceRange.location];
            dateText = [remaining substringFromIndex:doubleSpaceRange.location + doubleSpaceRange.length];
        } else {
            statusText = remaining;
        }
    } else {
        NSRange doubleSpaceRange = [string rangeOfString:@"  "];
        if (doubleSpaceRange.location != NSNotFound) {
            statusText = [string substringToIndex:doubleSpaceRange.location];
            dateText = [string substringFromIndex:doubleSpaceRange.location + doubleSpaceRange.length];
        } else {
            statusText = string;
        }
    }
    
    statusText = [statusText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    dateText = [dateText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    if (self.onStatusUpdate) {
        self.onStatusUpdate(statusColor, statusText, dateText);
    }
}

@end

#pragma mark - OrderCell Implementation

@interface OrderCell ()
- (void)pp_applyStatusText:(NSString *)statusText
                 statusKey:(nullable NSString *)statusKey
                  dateText:(nullable NSString *)dateText
             fallbackColor:(nullable UIColor *)fallbackColor;
- (void)pp_updateContentSizeLayout;
@end

@implementation OrderCell {
    UIView *_cardView;
    UIVisualEffectView *_blurView;
    UIView *_surfaceTintView;
    UIView *_statusRailView;

    UIStackView *_rowStack;       // horizontal: image + textContainerStack + chevron
    UIStackView *_textStack;      // vertical: headerRow + qtyLabel + statusRow
    UIStackView *_headerRow;      // horizontal: nameLabel + priceLabel
    UIStackView *_statusRow;      // horizontal: statusPillContainer + customDateLabel + spacer

    UIView *_statusPillContainer;
    CAGradientLayer *_statusPillGradientLayer;
    UIImageView *_statusIconView;
    UILabel *_statusPillLabel;
    UILabel *_customDateLabel;
    UIImageView *_chevronImageView;
    UIView *_statusSpacer;
    NSLayoutConstraint *_itemImageWidthConstraint;
    NSLayoutConstraint *_itemImageHeightConstraint;

    NSString *_currentStatusKey;
    NSString *_currentStatusText;
    NSString *_currentDateText;
    UIColor *_currentFallbackStatusColor;

}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupViews];
    }
    return self;
}

- (void)setupViews {
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.preservesSuperviewLayoutMargins = NO;
    self.contentView.preservesSuperviewLayoutMargins = NO;

    // Card padding setup following PPDesignTokens
    CGFloat horizontalPadding = PPSpaceBase; // 16pt
    CGFloat verticalPadding = PPSpaceMDHalf;
    CGFloat innerPadding = PPSpaceMD;

    // 1. Shadow Container (Card View)
    _cardView = [[UIView alloc] initWithFrame:CGRectZero];
    _cardView.translatesAutoresizingMaskIntoConstraints = NO;
    _cardView.backgroundColor = PPIOS26()
        ? UIColor.clearColor
        : [AppForgroundColr colorWithAlphaComponent:0.70];
    _cardView.userInteractionEnabled = NO;
    [self.contentView addSubview:_cardView];

    // Ultra-premium continuous corners & soft elevated shadow on container
    PPApplyContinuousCorners(_cardView, PPCornerCard);
    PPApplyCardShadow(_cardView);

    // Constraints for Shadow Container
    [NSLayoutConstraint activateConstraints:@[
        [_cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:horizontalPadding],
        [_cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-horizontalPadding],
        [_cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:verticalPadding],
        [_cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-verticalPadding]
    ]];

    // 2. Premium Material Background (UIVisualEffectView for blur / glassmorphism)
    UIVisualEffect *materialEffect = nil;
    if (@available(iOS 26.0, *)) {
        materialEffect = [UIGlassEffect effectWithStyle:UIGlassEffectStyleClear];
    } else if (@available(iOS 13.0, *)) {
        materialEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    } else {
        materialEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }
    
    _blurView = [[UIVisualEffectView alloc] initWithEffect:materialEffect];
    _blurView.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(_blurView, PPCornerCard);
    _blurView.clipsToBounds = YES;
    _blurView.layer.borderWidth = 0.7;
    _blurView.layer.borderColor = [AppForgroundColr colorWithAlphaComponent:0.45].CGColor;
    _blurView.alpha = PPIOS26() ? 1.0 : 0.78;
    [_cardView addSubview:_blurView];

    // Constraints for Blur Material (pins to Card View edges)
    [NSLayoutConstraint activateConstraints:@[
        [_blurView.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor],
        [_blurView.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor],
        [_blurView.topAnchor constraintEqualToAnchor:_cardView.topAnchor],
        [_blurView.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor]
    ]];

    _surfaceTintView = [[UIView alloc] initWithFrame:CGRectZero];
    _surfaceTintView.translatesAutoresizingMaskIntoConstraints = NO;
    _surfaceTintView.userInteractionEnabled = NO;
    [_blurView.contentView addSubview:_surfaceTintView];
    [NSLayoutConstraint activateConstraints:@[
        [_surfaceTintView.leadingAnchor constraintEqualToAnchor:_blurView.contentView.leadingAnchor],
        [_surfaceTintView.trailingAnchor constraintEqualToAnchor:_blurView.contentView.trailingAnchor],
        [_surfaceTintView.topAnchor constraintEqualToAnchor:_blurView.contentView.topAnchor],
        [_surfaceTintView.bottomAnchor constraintEqualToAnchor:_blurView.contentView.bottomAnchor]
    ]];

    _statusRailView = [[UIView alloc] initWithFrame:CGRectZero];
    _statusRailView.translatesAutoresizingMaskIntoConstraints = NO;
    _statusRailView.userInteractionEnabled = NO;
    _statusRailView.layer.cornerRadius = 1.5;
    _statusRailView.layer.masksToBounds = YES;
    [_cardView addSubview:_statusRailView];
    [NSLayoutConstraint activateConstraints:@[
        [_statusRailView.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:PPSpaceSM],
        [_statusRailView.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:PPSpaceMD],
        [_statusRailView.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor constant:-PPSpaceMD],
        [_statusRailView.widthAnchor constraintEqualToConstant:3.0],
        [_cardView.heightAnchor constraintGreaterThanOrEqualToConstant:116.0]
    ]];

    // 3. Image View
    _itemImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _itemImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _itemImageView.contentMode = UIViewContentModeScaleAspectFill;
    _itemImageView.layer.masksToBounds = YES;
    _itemImageView.backgroundColor = AppBackgroundClr;
    PPApplyContinuousCorners(_itemImageView, PPCornerSmall);
    
    _itemImageView.layer.borderWidth = 0.5;

    // Stable media plate keeps missing and loaded imagery from shifting the row.
    _itemImageWidthConstraint = [_itemImageView.widthAnchor constraintEqualToConstant:84.0];
    _itemImageHeightConstraint = [_itemImageView.heightAnchor constraintEqualToConstant:84.0];
    [NSLayoutConstraint activateConstraints:@[_itemImageWidthConstraint, _itemImageHeightConstraint]];

    // 4. Labels
    _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UIFont *nameBaseFont = [GM boldFontWithSize:16];
    _nameLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleHeadline] scaledFontForFont:nameBaseFont];
    _nameLabel.textColor = GM.PrimaryTextColor;
    _nameLabel.numberOfLines = 2;
    _nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _nameLabel.adjustsFontForContentSizeCategory = YES;

    _priceLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UIFont *priceBaseFont = [GM boldFontWithSize:15.5];
    _priceLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleHeadline] scaledFontForFont:priceBaseFont];
    _priceLabel.textColor = GM.PrimaryTextColor;
    _priceLabel.numberOfLines = 1;
    _priceLabel.adjustsFontSizeToFitWidth = YES;
    _priceLabel.minimumScaleFactor = 0.78;
    _priceLabel.adjustsFontForContentSizeCategory = YES;
    [_priceLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_priceLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    _quantityLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _quantityLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UIFont *quantityBaseFont = [GM MidFontWithSize:13];
    _quantityLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline] scaledFontForFont:quantityBaseFont];
    _quantityLabel.textColor = GM.SecondaryTextColor;
    _quantityLabel.numberOfLines = 2;
    _quantityLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _quantityLabel.adjustsFontForContentSizeCategory = YES;

    // Date Label (Private Intercept Label, hidden but functional)
    _dateLabel = [[PPOrderCellStatusLabel alloc] initWithFrame:CGRectZero];
    _dateLabel.hidden = YES;
    [self.contentView addSubview:_dateLabel];

    // Status Pill Container & Label
    _statusPillContainer = [[UIView alloc] initWithFrame:CGRectZero];
    _statusPillContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _statusPillContainer.hidden = YES;
    _statusPillContainer.layer.cornerRadius = 9.0;
    _statusPillContainer.layer.cornerCurve = kCACornerCurveContinuous;
    _statusPillContainer.layer.masksToBounds = YES;

    _statusPillGradientLayer = [CAGradientLayer layer];
    _statusPillGradientLayer.name = @"PPOrderHistoryStatusGradient";
    [_statusPillContainer.layer insertSublayer:_statusPillGradientLayer atIndex:0];

    _statusIconView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _statusIconView.translatesAutoresizingMaskIntoConstraints = NO;
    _statusIconView.contentMode = UIViewContentModeScaleAspectFit;
    [_statusPillContainer addSubview:_statusIconView];

    _statusPillLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _statusPillLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UIFont *statusBaseFont = [GM boldFontWithSize:11];
    _statusPillLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1] scaledFontForFont:statusBaseFont];
    _statusPillLabel.textAlignment = NSTextAlignmentCenter;
    _statusPillLabel.adjustsFontSizeToFitWidth = YES;
    _statusPillLabel.minimumScaleFactor = 0.82;
    _statusPillLabel.adjustsFontForContentSizeCategory = YES;
    [_statusPillContainer addSubview:_statusPillLabel];

    [NSLayoutConstraint activateConstraints:@[
        [_statusIconView.leadingAnchor constraintEqualToAnchor:_statusPillContainer.leadingAnchor constant:8.0],
        [_statusIconView.centerYAnchor constraintEqualToAnchor:_statusPillContainer.centerYAnchor],
        [_statusIconView.widthAnchor constraintEqualToConstant:13.0],
        [_statusIconView.heightAnchor constraintEqualToConstant:13.0],
        [_statusPillLabel.leadingAnchor constraintEqualToAnchor:_statusIconView.trailingAnchor constant:4.0],
        [_statusPillLabel.trailingAnchor constraintEqualToAnchor:_statusPillContainer.trailingAnchor constant:-8.0],
        [_statusPillLabel.topAnchor constraintEqualToAnchor:_statusPillContainer.topAnchor constant:4.0],
        [_statusPillLabel.bottomAnchor constraintEqualToAnchor:_statusPillContainer.bottomAnchor constant:-4.0]
    ]];

    // Custom Date Label
    _customDateLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _customDateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UIFont *dateBaseFont = [GM MidFontWithSize:12];
    _customDateLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1] scaledFontForFont:dateBaseFont];
    _customDateLabel.textColor = [UIColor secondaryLabelColor];
    _customDateLabel.numberOfLines = 1;
    _customDateLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _customDateLabel.adjustsFontForContentSizeCategory = YES;
    [_customDateLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                     forAxis:UILayoutConstraintAxisHorizontal];

    // 5. Chevron disclosure indicator
    _chevronImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _chevronImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _chevronImageView.contentMode = UIViewContentModeScaleAspectFit;

    [NSLayoutConstraint activateConstraints:@[
        [_chevronImageView.widthAnchor constraintEqualToConstant:14.0],
        [_chevronImageView.heightAnchor constraintEqualToConstant:14.0]
    ]];

    // Layout stacks setup
    _headerRow = [[UIStackView alloc] initWithArrangedSubviews:@[_nameLabel, _priceLabel]];
    _headerRow.translatesAutoresizingMaskIntoConstraints = NO;
    _headerRow.axis = UILayoutConstraintAxisHorizontal;
    _headerRow.alignment = UIStackViewAlignmentCenter;
    _headerRow.distribution = UIStackViewDistributionFill;
    _headerRow.spacing = PPSpaceSM;

    _statusSpacer = [[UIView alloc] initWithFrame:CGRectZero];
    _statusSpacer.translatesAutoresizingMaskIntoConstraints = NO;
    [_statusSpacer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    _statusRow = [[UIStackView alloc] initWithArrangedSubviews:@[_statusPillContainer, _customDateLabel, _statusSpacer]];
    _statusRow.translatesAutoresizingMaskIntoConstraints = NO;
    _statusRow.axis = UILayoutConstraintAxisHorizontal;
    _statusRow.alignment = UIStackViewAlignmentCenter;
    _statusRow.spacing = PPSpaceSM;
    _statusRow.distribution = UIStackViewDistributionFill;

    _textStack = [[UIStackView alloc] initWithArrangedSubviews:@[_headerRow, _quantityLabel, _statusRow]];
    _textStack.translatesAutoresizingMaskIntoConstraints = NO;
    _textStack.axis = UILayoutConstraintAxisVertical;
    _textStack.alignment = UIStackViewAlignmentFill;
    _textStack.distribution = UIStackViewDistributionFill;
    _textStack.spacing = PPSpaceMDHalf;
    [_textStack setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                forAxis:UILayoutConstraintAxisHorizontal];

    _rowStack = [[UIStackView alloc] initWithArrangedSubviews:@[_itemImageView, _textStack, _chevronImageView]];
    _rowStack.translatesAutoresizingMaskIntoConstraints = NO;
    _rowStack.axis = UILayoutConstraintAxisHorizontal;
    _rowStack.alignment = UIStackViewAlignmentCenter;
    _rowStack.distribution = UIStackViewDistributionFill;
    _rowStack.spacing = PPSpaceMD;
    [_cardView addSubview:_rowStack];

    // Constraints for Row Stack inside Card View
    [NSLayoutConstraint activateConstraints:@[
        [_rowStack.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:innerPadding],
        [_rowStack.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-innerPadding],
        [_rowStack.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:innerPadding],
        [_rowStack.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor constant:-innerPadding]
    ]];

    [self pp_updateContentSizeLayout];

    // Connect intercept dateLabel update block
    __weak typeof(self) weakSelf = self;
    ((PPOrderCellStatusLabel *)_dateLabel).onStatusUpdate = ^(UIColor * _Nullable statusColor, NSString * _Nullable statusText, NSString * _Nullable dateText) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        [strongSelf pp_applyStatusText:statusText
                            statusKey:nil
                             dateText:dateText
                        fallbackColor:statusColor];
    };
}

- (void)configureStatusText:(NSString *)statusText
                  statusKey:(NSString *)statusKey
                   dateText:(NSString *)dateText
{
    [self pp_applyStatusText:statusText
                   statusKey:statusKey
                    dateText:dateText
               fallbackColor:nil];
}

- (void)pp_applyStatusText:(NSString *)statusText
                 statusKey:(NSString *)statusKey
                  dateText:(NSString *)dateText
             fallbackColor:(UIColor *)fallbackColor
{
    NSString *previousStatusKey = _currentStatusKey;
    _currentStatusKey = [PPOrderStatusAppearanceNormalizedKey(statusKey) copy];
    _currentStatusText = [statusText ?: @"" copy];
    _currentDateText = [dateText ?: @"" copy];
    _currentFallbackStatusColor = fallbackColor;

    BOOL hasStatus = (_currentStatusText.length > 0);
    _statusPillContainer.hidden = !hasStatus;
    _statusPillLabel.text = hasStatus ? _currentStatusText : @"";
    if (hasStatus) {
        UIColor *accent = _currentStatusKey.length > 0
            ? PPOrderStatusAccentColorForKey(_currentStatusKey)
            : (fallbackColor ?: PPOrderStatusAccentColorForKey(@"pending"));
        UIColor *resolvedAccent = PPOrderStatusResolvedColor(accent, self.traitCollection);
        _statusRailView.backgroundColor = resolvedAccent;
        _surfaceTintView.backgroundColor = [resolvedAccent colorWithAlphaComponent:
                                            PPOrderStatusUsesDarkAppearance(self.traitCollection) ? 0.055 : 0.026];
        if (@available(iOS 26.0, *)) {
            if ([_blurView.effect isKindOfClass:UIGlassEffect.class]) {
                ((UIGlassEffect *)_blurView.effect).tintColor =
                    [resolvedAccent colorWithAlphaComponent:PPOrderStatusUsesDarkAppearance(self.traitCollection) ? 0.10 : 0.065];
            }
        }
        _statusPillContainer.backgroundColor = PPOrderStatusSurfaceColorForAccent(accent, self.traitCollection);
        _statusPillContainer.layer.borderWidth = 1.0;
        _statusPillContainer.layer.borderColor = PPOrderStatusBorderColorForAccent(accent, self.traitCollection).CGColor;
        _statusPillLabel.textColor = accent;
        UIImage *statusIcon = [UIImage systemImageNamed:PPOrderStatusSymbolNameForKey(_currentStatusKey)];
        if (!statusIcon) {
            statusIcon = [UIImage systemImageNamed:@"circle.fill"];
        }
        _statusIconView.image = [statusIcon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        _statusIconView.tintColor = accent;
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        PPOrderStatusConfigureGradientLayer(_statusPillGradientLayer,
                                            _currentStatusKey,
                                            resolvedAccent,
                                            self.traitCollection,
                                            [Language isRTL]);
        [CATransaction commit];
    } else {
        UIColor *neutral = PPOrderStatusAccentColorForKey(nil);
        _statusRailView.backgroundColor = neutral;
        _surfaceTintView.backgroundColor = UIColor.clearColor;
        _statusIconView.image = nil;
        if (@available(iOS 26.0, *)) {
            if ([_blurView.effect isKindOfClass:UIGlassEffect.class]) {
                ((UIGlassEffect *)_blurView.effect).tintColor = nil;
            }
        }
    }

    _customDateLabel.hidden = (_currentDateText.length == 0);
    _customDateLabel.text = _currentDateText;

    BOOL statusChanged = previousStatusKey.length > 0 &&
        ![previousStatusKey isEqualToString:_currentStatusKey];
    if (statusChanged && self.window && !UIAccessibilityIsReduceMotionEnabled()) {
        CATransition *transition = [CATransition animation];
        transition.type = kCATransitionFade;
        transition.duration = 0.22;
        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        [_statusPillContainer.layer addAnimation:transition forKey:@"PPOrderStatusChange"];
        [_statusRailView.layer addAnimation:transition forKey:@"PPOrderRailChange"];
    }
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _statusPillGradientLayer.frame = _statusPillContainer.bounds;
    _statusPillGradientLayer.cornerRadius = _statusPillContainer.layer.cornerRadius;
    [CATransaction commit];

    BOOL isRTL = ([Language languageVal] == 1);

    // Setup semantic attributes for Stack Views (Flipped automatically for RTL layout)
    UISemanticContentAttribute semanticAttr = isRTL ? UISemanticContentAttributeForceRightToLeft : UISemanticContentAttributeForceLeftToRight;
    self.contentView.semanticContentAttribute = semanticAttr;
    _cardView.semanticContentAttribute = semanticAttr;
    _rowStack.semanticContentAttribute = semanticAttr;
    _textStack.semanticContentAttribute = semanticAttr;
    _headerRow.semanticContentAttribute = semanticAttr;
    _statusRow.semanticContentAttribute = semanticAttr;
    _statusPillContainer.semanticContentAttribute = semanticAttr;

    // Setup text alignments
    NSTextAlignment leadingAlign = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    NSTextAlignment trailingAlign = isRTL ? NSTextAlignmentLeft : NSTextAlignmentRight;

    _nameLabel.textAlignment = leadingAlign;
    _quantityLabel.textAlignment = leadingAlign;
    _customDateLabel.textAlignment = leadingAlign;
    BOOL usesAccessibilityLayout = UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);
    _priceLabel.textAlignment = usesAccessibilityLayout ? leadingAlign : trailingAlign;

    // Chevron display matching layout direction
    UIImage *chevronImg;
    if (@available(iOS 13.0, *)) {
        chevronImg = [UIImage systemImageNamed:isRTL ? @"chevron.left" : @"chevron.right"];
    } else {
        chevronImg = [UIImage imageNamed:isRTL ? @"chevron.left" : @"chevron.right"];
    }
    _chevronImageView.image = [chevronImg imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    if (@available(iOS 13.0, *)) {
        _chevronImageView.tintColor = [UIColor tertiaryLabelColor];
    } else {
        _chevronImageView.tintColor = [UIColor colorWithWhite:0.0 alpha:0.3];
    }

    // Dynamic borders resolved specifically for self.traitCollection (Fixes dark mode border caching)
    if (@available(iOS 13.0, *)) {
        UIColor *borderColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithWhite:1.0 alpha:0.08];
            } else {
                return [UIColor colorWithWhite:0.0 alpha:0.06];
            }
        }];
        _blurView.layer.borderColor = [borderColor resolvedColorWithTraitCollection:self.traitCollection].CGColor;
        _itemImageView.layer.borderColor = [[UIColor separatorColor] resolvedColorWithTraitCollection:self.traitCollection].CGColor;
    } else {
        _blurView.layer.borderColor = [UIColor colorWithWhite:0.0 alpha:0.06].CGColor;
        _itemImageView.layer.borderColor = [UIColor colorWithWhite:0.0 alpha:0.1].CGColor;
    }

    // Update smooth shadow path to avoid CPU layout hits
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:_cardView.bounds cornerRadius:_cardView.layer.cornerRadius];
    _cardView.layer.shadowPath = path.CGPath;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    [self pp_updateContentSizeLayout];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_applyStatusText:_currentStatusText
                           statusKey:_currentStatusKey
                            dateText:_currentDateText
                       fallbackColor:_currentFallbackStatusColor];
        }
    }
}

- (void)pp_updateContentSizeLayout
{
    BOOL usesAccessibilityLayout = UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);

    _itemImageWidthConstraint.constant = usesAccessibilityLayout ? 64.0 : 84.0;
    _itemImageHeightConstraint.constant = usesAccessibilityLayout ? 64.0 : 84.0;
    _headerRow.axis = usesAccessibilityLayout ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    _headerRow.alignment = usesAccessibilityLayout ? UIStackViewAlignmentFill : UIStackViewAlignmentCenter;
    _statusRow.axis = usesAccessibilityLayout ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    _statusRow.alignment = usesAccessibilityLayout ? UIStackViewAlignmentLeading : UIStackViewAlignmentCenter;
    _rowStack.alignment = usesAccessibilityLayout ? UIStackViewAlignmentTop : UIStackViewAlignmentCenter;
    _statusSpacer.hidden = usesAccessibilityLayout;

    _nameLabel.numberOfLines = usesAccessibilityLayout ? 0 : 2;
    _priceLabel.numberOfLines = usesAccessibilityLayout ? 0 : 1;
    _priceLabel.adjustsFontSizeToFitWidth = !usesAccessibilityLayout;
    _quantityLabel.numberOfLines = usesAccessibilityLayout ? 0 : 2;
    _statusPillLabel.numberOfLines = usesAccessibilityLayout ? 0 : 1;
    _statusPillLabel.adjustsFontSizeToFitWidth = !usesAccessibilityLayout;
    _customDateLabel.numberOfLines = usesAccessibilityLayout ? 0 : 1;

    [self setNeedsLayout];
}

#pragma mark - Interactive Selection Feedback

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    [self animatePress:highlighted];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
}

- (void)animatePress:(BOOL)pressed {
    if (UIAccessibilityIsReduceMotionEnabled()) {
        _cardView.transform = CGAffineTransformIdentity;
        _cardView.alpha = pressed ? 0.88 : 1.0;
        return;
    }
    _cardView.alpha = 1.0;
    [UIView animateWithDuration:PPAnimDurationNormal
                          delay:0
         usingSpringWithDamping:PPAnimSpringDamping
          initialSpringVelocity:PPAnimSpringVelocity
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        if (pressed) {
            self->_cardView.transform = CGAffineTransformMakeScale(PPTapCardScaleDown, PPTapCardScaleDown);
        } else {
            self->_cardView.transform = CGAffineTransformIdentity;
        }
    } completion:nil];
}

#pragma mark - Order Ledger Entrance

- (void)playEntranceWithOrdinal:(NSInteger)ordinal animated:(BOOL)animated
{
    [_cardView.layer removeAnimationForKey:@"PPOrderCardEntrance"];
    [_statusRailView.layer removeAnimationForKey:@"PPOrderRailEntrance"];
    self.contentView.alpha = 1.0;
    self.contentView.transform = CGAffineTransformIdentity;

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        _cardView.alpha = 1.0;
        _cardView.transform = CGAffineTransformIdentity;
        _statusRailView.transform = CGAffineTransformIdentity;
        return;
    }

    BOOL isRTL = ([Language languageVal] == 1);
    CGFloat horizontalResolve = isRTL ? -14.0 : 14.0;
    _cardView.alpha = 1.0;
    _cardView.transform = CGAffineTransformScale(CGAffineTransformMakeTranslation(horizontalResolve, 0.0),
                                                 0.988,
                                                 0.988);
    _statusRailView.transform = CGAffineTransformMakeScale(1.0, 0.08);

    NSTimeInterval delay = MIN(MAX(ordinal, 0), 5) * 0.035;
    [UIView animateWithDuration:0.34
                          delay:delay
                        options:UIViewAnimationOptionCurveEaseOut |
                                UIViewAnimationOptionAllowUserInteraction |
                                UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self->_cardView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.40
                          delay:delay + 0.04
                        options:UIViewAnimationOptionCurveEaseOut |
                                UIViewAnimationOptionAllowUserInteraction |
                                UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self->_statusRailView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

#pragma mark - Cell Reuse Cleanup

- (void)prepareForReuse {
    [super prepareForReuse];
    [_itemImageView cancelCurrentImageRequest];
    _itemImageView.image = [UIImage imageNamed:@"placeholder"];
    _nameLabel.text = @"";
    _quantityLabel.text = @"";
    _priceLabel.text = @"";
    _customDateLabel.text = @"";
    _statusPillLabel.text = @"";
    _statusPillContainer.hidden = YES;
    _customDateLabel.hidden = YES;
    _currentStatusKey = nil;
    _currentStatusText = nil;
    _currentDateText = nil;
    _currentFallbackStatusColor = nil;
    self.isAccessibilityElement = NO;
    self.accessibilityLabel = nil;
    self.accessibilityHint = nil;

    self.contentView.alpha = 1.0;
    self.contentView.transform = CGAffineTransformIdentity;
    _cardView.alpha = 1.0;
    _cardView.transform = CGAffineTransformIdentity;
    _statusRailView.transform = CGAffineTransformIdentity;
    [_cardView.layer removeAllAnimations];
    [_statusRailView.layer removeAllAnimations];
    [_statusPillContainer.layer removeAllAnimations];
}

#pragma mark - Configuration (Standard / Fallback)

- (void)configureWithItem:(CartItem *)item {
    _nameLabel.text = item.name ?: @"";
    _quantityLabel.text = [NSString stringWithFormat:@"%@: %ld", kLang(@"QuantityLabel"), (long)item.quantity];

    double total = item.price * item.quantity;
    _priceLabel.text = [PPChatsFunc formattedCurrency:MAX(0.0, total)];

    if (item.imageURL.length > 0) {
        [GM setImageFromUrlString:item.imageURL imageView:_itemImageView phImage:@"placeholder"];
    } else {
        _itemImageView.image = [UIImage imageNamed:@"placeholder"];
    }

    [self setNeedsLayout];
    [self layoutIfNeeded];
}

@end
