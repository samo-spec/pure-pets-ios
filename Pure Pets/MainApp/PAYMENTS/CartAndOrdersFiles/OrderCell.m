#import "OrderCell.h"
#import "OrderModel.h"
#import "GM.h"
#import "PPChatsFunc.h"

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

@implementation OrderCell {
    UIView *_cardView;
    UIVisualEffectView *_blurView;

    UIStackView *_rowStack;       // horizontal: image + textContainerStack + chevron
    UIStackView *_textStack;      // vertical: headerRow + qtyLabel + statusRow
    UIStackView *_headerRow;      // horizontal: nameLabel + priceLabel
    UIStackView *_statusRow;      // horizontal: statusPillContainer + customDateLabel + spacer

    UIView *_statusPillContainer;
    UILabel *_statusPillLabel;
    UILabel *_customDateLabel;
    UIImageView *_chevronImageView;

    BOOL _hasAnimatedEntrance;
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
    CGFloat verticalPadding = PPSpaceMDHalf; // 6pt
    CGFloat innerPadding = PPSpaceBase;      // 16pt

    // 1. Shadow Container (Card View)
    _cardView = [[UIView alloc] initWithFrame:CGRectZero];
    _cardView.translatesAutoresizingMaskIntoConstraints = NO;
    _cardView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.82];
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
    UIBlurEffect *blurEffect;
    if (@available(iOS 13.0, *)) {
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    } else {
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }
    
    _blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    _blurView.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(_blurView, PPCornerCard);
    _blurView.clipsToBounds = YES;
    _blurView.layer.borderWidth = 0.7;
    _blurView.layer.borderColor = [AppForgroundColr colorWithAlphaComponent:0.45].CGColor;
    _blurView.alpha = 0.4;
    [_cardView addSubview:_blurView];

    // Constraints for Blur Material (pins to Card View edges)
    [NSLayoutConstraint activateConstraints:@[
        [_blurView.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor],
        [_blurView.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor],
        [_blurView.topAnchor constraintEqualToAnchor:_cardView.topAnchor],
        [_blurView.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor]
    ]];

    // 3. Image View
    _itemImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _itemImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _itemImageView.contentMode = UIViewContentModeScaleAspectFill;
    _itemImageView.layer.masksToBounds = YES;
    _itemImageView.backgroundColor = AppBackgroundClr;
    PPApplyContinuousCorners(_itemImageView, PPCornerSmall);
    
    _itemImageView.layer.borderWidth = 0.5;

    // Constraints for Image (92x92)
    [NSLayoutConstraint activateConstraints:@[
        [_itemImageView.widthAnchor constraintEqualToConstant:92.0],
        [_itemImageView.heightAnchor constraintEqualToConstant:92.0]
    ]];

    // 4. Labels
    _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _nameLabel.font = [GM boldFontWithSize:16];
    _nameLabel.textColor = GM.PrimaryTextColor;
    _nameLabel.numberOfLines = 1;
    _nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    _priceLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _priceLabel.font = [GM boldFontWithSize:16];
    _priceLabel.textColor = GM.PrimaryTextColor;
    _priceLabel.numberOfLines = 1;
    [_priceLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_priceLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    _quantityLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _quantityLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _quantityLabel.font = [GM MidFontWithSize:13];
    _quantityLabel.textColor = GM.SecondaryTextColor;
    _quantityLabel.numberOfLines = 1;
    _quantityLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    // Date Label (Private Intercept Label, hidden but functional)
    _dateLabel = [[PPOrderCellStatusLabel alloc] initWithFrame:CGRectZero];
    _dateLabel.hidden = YES;
    [self.contentView addSubview:_dateLabel];

    // Status Pill Container & Label
    _statusPillContainer = [[UIView alloc] initWithFrame:CGRectZero];
    _statusPillContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _statusPillContainer.hidden = YES;

    _statusPillLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _statusPillLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _statusPillLabel.font = [GM boldFontWithSize:11];
    _statusPillLabel.textAlignment = NSTextAlignmentCenter;
    [_statusPillContainer addSubview:_statusPillLabel];

    [NSLayoutConstraint activateConstraints:@[
        [_statusPillLabel.leadingAnchor constraintEqualToAnchor:_statusPillContainer.leadingAnchor constant:8.0],
        [_statusPillLabel.trailingAnchor constraintEqualToAnchor:_statusPillContainer.trailingAnchor constant:-8.0],
        [_statusPillLabel.topAnchor constraintEqualToAnchor:_statusPillContainer.topAnchor constant:4.0],
        [_statusPillLabel.bottomAnchor constraintEqualToAnchor:_statusPillContainer.bottomAnchor constant:-4.0]
    ]];

    // Custom Date Label
    _customDateLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _customDateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _customDateLabel.font = [GM MidFontWithSize:12];
    _customDateLabel.textColor = [UIColor secondaryLabelColor];
    _customDateLabel.numberOfLines = 1;

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

    UIView *statusSpacer = [[UIView alloc] initWithFrame:CGRectZero];
    statusSpacer.translatesAutoresizingMaskIntoConstraints = NO;
    [statusSpacer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    _statusRow = [[UIStackView alloc] initWithArrangedSubviews:@[_statusPillContainer, _customDateLabel, statusSpacer]];
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

    // Connect intercept dateLabel update block
    __weak typeof(self) weakSelf = self;
    ((PPOrderCellStatusLabel *)_dateLabel).onStatusUpdate = ^(UIColor * _Nullable statusColor, NSString * _Nullable statusText, NSString * _Nullable dateText) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (statusText.length > 0) {
            strongSelf->_statusPillContainer.hidden = NO;
            strongSelf->_statusPillLabel.text = statusText;

            UIColor *baseColor = statusColor ?: GM.appPrimaryColor;
            strongSelf->_statusPillContainer.backgroundColor = [baseColor colorWithAlphaComponent:0.08];
            strongSelf->_statusPillLabel.textColor = baseColor;
            strongSelf->_statusPillContainer.layer.borderColor = [baseColor colorWithAlphaComponent:0.2].CGColor;
            strongSelf->_statusPillContainer.layer.borderWidth = 0.5;
            strongSelf->_statusPillContainer.layer.cornerRadius = 8.0;
            strongSelf->_statusPillContainer.layer.cornerCurve = kCACornerCurveContinuous;
            strongSelf->_statusPillContainer.clipsToBounds = YES;
        } else {
            strongSelf->_statusPillContainer.hidden = YES;
            strongSelf->_statusPillLabel.text = @"";
        }

        if (dateText.length > 0) {
            strongSelf->_customDateLabel.hidden = NO;
            strongSelf->_customDateLabel.text = dateText;
        } else {
            strongSelf->_customDateLabel.hidden = YES;
            strongSelf->_customDateLabel.text = @"";
        }
    };
}

- (void)layoutSubviews {
    [super layoutSubviews];

    BOOL isRTL = ([Language languageVal] == 1);

    // Setup semantic attributes for Stack Views (Flipped automatically for RTL layout)
    UISemanticContentAttribute semanticAttr = isRTL ? UISemanticContentAttributeForceRightToLeft : UISemanticContentAttributeForceLeftToRight;
    _rowStack.semanticContentAttribute = semanticAttr;
    _textStack.semanticContentAttribute = semanticAttr;
    _headerRow.semanticContentAttribute = semanticAttr;
    _statusRow.semanticContentAttribute = semanticAttr;

    // Setup text alignments
    NSTextAlignment leadingAlign = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    NSTextAlignment trailingAlign = isRTL ? NSTextAlignmentLeft : NSTextAlignmentRight;

    _nameLabel.textAlignment = leadingAlign;
    _quantityLabel.textAlignment = leadingAlign;
    _customDateLabel.textAlignment = leadingAlign;
    _priceLabel.textAlignment = trailingAlign;

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

#pragma mark - Interactive Selection Feedback

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    [self animatePress:highlighted];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
}

- (void)animatePress:(BOOL)pressed {
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

#pragma mark - Cascade Entrance Animations

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window && !_hasAnimatedEntrance) {
        [self performEntranceAnimation];
    }
}

- (void)performEntranceAnimation {
    _hasAnimatedEntrance = YES;

    UIView *superview = self.superview;
    while (superview && ![superview isKindOfClass:[UITableView class]]) {
        superview = superview.superview;
    }

    BOOL isScrolling = NO;
    NSTimeInterval delay = 0;
    if (superview) {
        UITableView *tableView = (UITableView *)superview;
        isScrolling = tableView.isDragging || tableView.isDecelerating;
        NSIndexPath *indexPath = [tableView indexPathForCell:self];
        // Apply stagger delay only to first screen visible cards
        if (indexPath && indexPath.row < 6) {
            delay = indexPath.row * 0.04;
        }
    }

    // If table view is scrolling, display cell instantly to maintain 60/120fps fluid scrolling
    if (isScrolling) {
        self.contentView.alpha = 1.0;
        self.contentView.transform = CGAffineTransformIdentity;
        return;
    }

    // Initial prepared state before first render
    self.contentView.alpha = 0.0;
    self.contentView.transform = CGAffineTransformMakeTranslation(0, 8.0);

    [UIView animateWithDuration:PPAnimDurationSlow
                          delay:delay
         usingSpringWithDamping:0.85
          initialSpringVelocity:0.4
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.contentView.alpha = 1.0;
        self.contentView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

#pragma mark - Cell Reuse Cleanup

- (void)prepareForReuse {
    [super prepareForReuse];
    _itemImageView.image = [UIImage imageNamed:@"placeholder"];
    _nameLabel.text = @"";
    _quantityLabel.text = @"";
    _priceLabel.text = @"";
    _customDateLabel.text = @"";
    _statusPillLabel.text = @"";
    _statusPillContainer.hidden = YES;
    _customDateLabel.hidden = YES;

    _hasAnimatedEntrance = NO;

    self.contentView.alpha = 1.0;
    self.contentView.transform = CGAffineTransformIdentity;
    _cardView.transform = CGAffineTransformIdentity;
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
