//
//  PPProviderCompanyCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 6/28/26.
//

#import "PPProviderCompanyCell.h"
#import "PPModernAvatarRenderer.h"
#import "PPImageLoaderManager.h"

@implementation PPProviderCompanyEntry
@end

@implementation PPProviderCompanyCell {
    UIView *_cardView;
    UIView *_mediaView;
    UIImageView *_coverImageView;
    UIView *_imageScrimView;
    CAGradientLayer *_readabilityGradientLayer;
    UIView *_contentWrapView;
    UIView *_avatarShellView;
    UIView *_chevronContainerView;
    UIView *_cityPillView;
    NSLayoutConstraint *_cityPillHeightConstraint;
    UIStackView *_identityStackView;
    UIStackView *_titleRowStackView;
    UIStackView *_cityStackView;
    UIImageView *_avatarImageView;
    UIImageView *_cityIconView;
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
    UILabel *_cityLabel;
    UIImageView *_chevronView;
    UIImageView *_avatarVerifiedIconView;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self pp_buildUI];
    }
    return self;
}

+ (CGFloat)preferredHeightForTableWidth:(CGFloat)tableWidth
{
    CGFloat contentWidth = MAX(0.0, tableWidth - 32.0);
    CGFloat mediaHeight = contentWidth > 0.0 ? floor(contentWidth * 0.58) : 222.0;
    mediaHeight = MIN(260.0, MAX(206.0, mediaHeight));

    if (@available(iOS 11.0, *)) {
        if (UIContentSizeCategoryIsAccessibilityCategory(UIApplication.sharedApplication.preferredContentSizeCategory)) {
            mediaHeight += 36.0;
        }
    }

    return ceil(mediaHeight + 14.0);
}

- (void)pp_buildUI
{
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.isAccessibilityElement = YES;

    _cardView = [[UIView alloc] init];
    _cardView.translatesAutoresizingMaskIntoConstraints = NO;
    _cardView.backgroundColor = UIColor.clearColor;
    PPProviderCompaniesApplyContinuousCorners(_cardView, 30.0);
    _cardView.layer.borderWidth = 0.0;
    _cardView.layer.masksToBounds = NO;
    [_cardView pp_setShadowColor:UIColor.blackColor];
    _cardView.layer.shadowOpacity = 0.14;
    _cardView.layer.shadowRadius = 26.0;
    _cardView.layer.shadowOffset = CGSizeMake(0.0, 16.0);
    [self.contentView addSubview:_cardView];

    _mediaView = [[UIView alloc] init];
    _mediaView.translatesAutoresizingMaskIntoConstraints = NO;
    _mediaView.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
    _mediaView.layer.borderWidth = 1.0;
    _mediaView.layer.masksToBounds = YES;
    PPProviderCompaniesApplyContinuousCorners(_mediaView, 30.0);
    [_mediaView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.70]];
    [_cardView addSubview:_mediaView];

    _coverImageView = [[UIImageView alloc] init];
    _coverImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _coverImageView.contentMode = UIViewContentModeScaleAspectFill;
    _coverImageView.clipsToBounds = YES;
    _coverImageView.backgroundColor = [UIColor colorWithWhite:0.90 alpha:1.0];
    _coverImageView.isAccessibilityElement = NO;
    [_mediaView addSubview:_coverImageView];

    _imageScrimView = [[UIView alloc] init];
    _imageScrimView.translatesAutoresizingMaskIntoConstraints = NO;
    _imageScrimView.userInteractionEnabled = NO;
    _imageScrimView.backgroundColor = UIColor.clearColor;
    [_mediaView addSubview:_imageScrimView];

    _readabilityGradientLayer = [CAGradientLayer layer];
    _readabilityGradientLayer.startPoint = CGPointMake(0.5, 0.0);
    _readabilityGradientLayer.endPoint = CGPointMake(0.5, 1.0);
    [_imageScrimView.layer addSublayer:_readabilityGradientLayer];

    _contentWrapView = [[UIView alloc] init];
    _contentWrapView.translatesAutoresizingMaskIntoConstraints = NO;
    _contentWrapView.backgroundColor = UIColor.clearColor;
    [_mediaView addSubview:_contentWrapView];

    _avatarShellView = [[UIView alloc] init];
    _avatarShellView.translatesAutoresizingMaskIntoConstraints = NO;
    _avatarShellView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.20];
    PPProviderCompaniesApplyContinuousCorners(_avatarShellView, 24.0);
    _avatarShellView.layer.masksToBounds = NO;
    _avatarShellView.layer.borderWidth = 1.0;
    [_avatarShellView pp_setShadowColor:UIColor.blackColor];
    _avatarShellView.layer.shadowOpacity = 0.16;
    _avatarShellView.layer.shadowRadius = 12.0;
    _avatarShellView.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    [_avatarShellView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.52]];
    [_contentWrapView addSubview:_avatarShellView];

    _avatarImageView = [[UIImageView alloc] init];
    _avatarImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    PPProviderCompaniesApplyContinuousCorners(_avatarImageView, 20.0);
    _avatarImageView.layer.masksToBounds = YES;
    _avatarImageView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.18];
    _avatarImageView.isAccessibilityElement = NO;
    [_avatarShellView addSubview:_avatarImageView];

    _identityStackView = [[UIStackView alloc] init];
    _identityStackView.translatesAutoresizingMaskIntoConstraints = NO;
    _identityStackView.axis = UILayoutConstraintAxisVertical;
    _identityStackView.alignment = UIStackViewAlignmentFill;
    _identityStackView.distribution = UIStackViewDistributionFill;
    _identityStackView.spacing = 4.0;
    _identityStackView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [_contentWrapView addSubview:_identityStackView];

    _titleRowStackView = [[UIStackView alloc] init];
    _titleRowStackView.translatesAutoresizingMaskIntoConstraints = NO;
    _titleRowStackView.axis = UILayoutConstraintAxisHorizontal;
    _titleRowStackView.alignment = UIStackViewAlignmentCenter;
    _titleRowStackView.distribution = UIStackViewDistributionFill;
    _titleRowStackView.spacing = 6.0;
    _titleRowStackView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [_identityStackView addArrangedSubview:_titleRowStackView];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = PPProviderCompaniesScaledFont([GM boldFontWithSize:21.0],
                                                     UIFontTextStyleHeadline);
    _titleLabel.textColor = UIColor.whiteColor;
    _titleLabel.numberOfLines = 1;
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _titleLabel.adjustsFontSizeToFitWidth = YES;
    _titleLabel.minimumScaleFactor = 0.86;
    _titleLabel.adjustsFontForContentSizeCategory = YES;
    _titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_titleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                 forAxis:UILayoutConstraintAxisHorizontal];
    [_titleLabel setContentHuggingPriority:UILayoutPriorityRequired
                                    forAxis:UILayoutConstraintAxisHorizontal];
    [_titleRowStackView addArrangedSubview:_titleLabel];

    _avatarVerifiedIconView = [[UIImageView alloc] init];
    _avatarVerifiedIconView.translatesAutoresizingMaskIntoConstraints = NO;
    _avatarVerifiedIconView.contentMode = UIViewContentModeScaleAspectFit;
    _avatarVerifiedIconView.tintColor = [UIColor colorWithRed:0.30 green:0.86 blue:0.56 alpha:1.0];
    [_avatarVerifiedIconView setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                             forAxis:UILayoutConstraintAxisHorizontal];
    [_avatarVerifiedIconView setContentHuggingPriority:UILayoutPriorityRequired
                                               forAxis:UILayoutConstraintAxisHorizontal];
    [_titleRowStackView addArrangedSubview:_avatarVerifiedIconView];

    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.font = PPProviderCompaniesScaledFont([GM MidFontWithSize:13.0], UIFontTextStyleSubheadline);
    _subtitleLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.84];
    _subtitleLabel.numberOfLines = 1;
    _subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _subtitleLabel.adjustsFontForContentSizeCategory = YES;
    _subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_identityStackView addArrangedSubview:_subtitleLabel];

    _cityPillView = [[UIView alloc] init];
    _cityPillView.translatesAutoresizingMaskIntoConstraints = NO;
    _cityPillView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.16];
    _cityPillView.layer.borderWidth = 0.75;
    _cityPillView.layer.masksToBounds = YES;
    PPProviderCompaniesApplyContinuousCorners(_cityPillView, 15.0);
    [_cityPillView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.25]];
    [_identityStackView addArrangedSubview:_cityPillView];

    _cityIconView = [[UIImageView alloc] init];
    _cityIconView.translatesAutoresizingMaskIntoConstraints = NO;
    _cityIconView.contentMode = UIViewContentModeScaleAspectFit;
    _cityIconView.tintColor = [UIColor colorWithWhite:1.0 alpha:0.82];

    _cityLabel = [[UILabel alloc] init];
    _cityLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _cityLabel.font = PPProviderCompaniesScaledFont([GM MidFontWithSize:12.0], UIFontTextStyleCaption1);
    _cityLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.88];
    _cityLabel.numberOfLines = 1;
    _cityLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _cityLabel.adjustsFontForContentSizeCategory = YES;
    _cityLabel.textAlignment = Language.alignmentForCurrentLanguage;

    _cityStackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        _cityIconView,
        _cityLabel
    ]];
    _cityStackView.translatesAutoresizingMaskIntoConstraints = NO;
    _cityStackView.axis = UILayoutConstraintAxisHorizontal;
    _cityStackView.alignment = UIStackViewAlignmentCenter;
    _cityStackView.distribution = UIStackViewDistributionFill;
    _cityStackView.spacing = 5.0;
    _cityStackView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [_cityPillView addSubview:_cityStackView];

    _chevronContainerView = [[UIView alloc] init];
    _chevronContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    _chevronContainerView.layer.masksToBounds = YES;
    _chevronContainerView.layer.borderWidth = 0.75;
    [_chevronContainerView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.30]];
    _chevronContainerView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.18];
    [_contentWrapView addSubview:_chevronContainerView];

    _chevronView = [[UIImageView alloc] init];
    _chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    _chevronView.contentMode = UIViewContentModeScaleAspectFit;
    if (@available(iOS 13.0, *)) {
        NSString *chevronName = Language.isRTL ? @"arrow.left" : @"arrow.right";
        _chevronView.image = [[UIImage systemImageNamed:chevronName
                                      withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14.0
                                                                                                weight:UIImageSymbolWeightBold]]
                             imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    _chevronView.tintColor = [UIColor colorWithWhite:1.0 alpha:0.86];
    [_chevronContainerView addSubview:_chevronView];

    _cityPillHeightConstraint = [_cityPillView.heightAnchor constraintGreaterThanOrEqualToConstant:30.0];
    _cityPillHeightConstraint.priority = UILayoutPriorityDefaultHigh;

    [NSLayoutConstraint activateConstraints:@[
        [_cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:7.0],
        [_cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0],
        [_cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16.0],
        [_cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-7.0],

        [_mediaView.topAnchor constraintEqualToAnchor:_cardView.topAnchor],
        [_mediaView.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor],
        [_mediaView.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor],
        [_mediaView.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor],
        [_mediaView.heightAnchor constraintGreaterThanOrEqualToConstant:206.0],

        [_coverImageView.topAnchor constraintEqualToAnchor:_mediaView.topAnchor],
        [_coverImageView.leadingAnchor constraintEqualToAnchor:_mediaView.leadingAnchor],
        [_coverImageView.trailingAnchor constraintEqualToAnchor:_mediaView.trailingAnchor],
        [_coverImageView.bottomAnchor constraintEqualToAnchor:_mediaView.bottomAnchor],

        [_imageScrimView.topAnchor constraintEqualToAnchor:_mediaView.topAnchor],
        [_imageScrimView.leadingAnchor constraintEqualToAnchor:_mediaView.leadingAnchor],
        [_imageScrimView.trailingAnchor constraintEqualToAnchor:_mediaView.trailingAnchor],
        [_imageScrimView.bottomAnchor constraintEqualToAnchor:_mediaView.bottomAnchor],

        [_contentWrapView.leadingAnchor constraintEqualToAnchor:_mediaView.leadingAnchor constant:16.0],
        [_contentWrapView.trailingAnchor constraintEqualToAnchor:_mediaView.trailingAnchor constant:-16.0],
        [_contentWrapView.bottomAnchor constraintEqualToAnchor:_mediaView.bottomAnchor constant:-16.0],
        [_contentWrapView.topAnchor constraintGreaterThanOrEqualToAnchor:_mediaView.topAnchor constant:58.0],

        [_avatarShellView.leadingAnchor constraintEqualToAnchor:_contentWrapView.leadingAnchor],
        [_avatarShellView.centerYAnchor constraintEqualToAnchor:_contentWrapView.centerYAnchor],
        [_avatarShellView.widthAnchor constraintEqualToConstant:54.0],
        [_avatarShellView.heightAnchor constraintEqualToConstant:54.0],

        [_avatarImageView.topAnchor constraintEqualToAnchor:_avatarShellView.topAnchor constant:4.0],
        [_avatarImageView.leadingAnchor constraintEqualToAnchor:_avatarShellView.leadingAnchor constant:4.0],
        [_avatarImageView.trailingAnchor constraintEqualToAnchor:_avatarShellView.trailingAnchor constant:-4.0],
        [_avatarImageView.bottomAnchor constraintEqualToAnchor:_avatarShellView.bottomAnchor constant:-4.0],

        [_identityStackView.leadingAnchor constraintEqualToAnchor:_avatarShellView.trailingAnchor constant:12.0],
        [_identityStackView.trailingAnchor constraintEqualToAnchor:_chevronContainerView.leadingAnchor constant:-12.0],
        [_identityStackView.topAnchor constraintEqualToAnchor:_contentWrapView.topAnchor],
        [_identityStackView.bottomAnchor constraintEqualToAnchor:_contentWrapView.bottomAnchor],

        [_avatarVerifiedIconView.widthAnchor constraintEqualToConstant:17.0],
        [_avatarVerifiedIconView.heightAnchor constraintEqualToConstant:17.0],

        [_cityPillView.widthAnchor constraintLessThanOrEqualToAnchor:_identityStackView.widthAnchor],
        _cityPillHeightConstraint,

        [_cityStackView.topAnchor constraintEqualToAnchor:_cityPillView.topAnchor constant:6.0],
        [_cityStackView.leadingAnchor constraintEqualToAnchor:_cityPillView.leadingAnchor constant:10.0],
        [_cityStackView.trailingAnchor constraintEqualToAnchor:_cityPillView.trailingAnchor constant:-10.0],
        [_cityStackView.bottomAnchor constraintEqualToAnchor:_cityPillView.bottomAnchor constant:-6.0],

        [_cityIconView.widthAnchor constraintEqualToConstant:12.0],
        [_cityIconView.heightAnchor constraintEqualToConstant:12.0],

        [_chevronContainerView.trailingAnchor constraintEqualToAnchor:_contentWrapView.trailingAnchor],
        [_chevronContainerView.centerYAnchor constraintEqualToAnchor:_contentWrapView.centerYAnchor],
        [_chevronContainerView.widthAnchor constraintEqualToConstant:38.0],
        [_chevronContainerView.heightAnchor constraintEqualToConstant:38.0],

        [_chevronView.centerXAnchor constraintEqualToAnchor:_chevronContainerView.centerXAnchor],
        [_chevronView.centerYAnchor constraintEqualToAnchor:_chevronContainerView.centerYAnchor],
        [_chevronView.widthAnchor constraintEqualToConstant:14.0],
        [_chevronView.heightAnchor constraintEqualToConstant:14.0]
    ]];
}

- (void)configureWithEntry:(PPProviderCompanyEntry *)entry
        categoryIdentifier:(NSString *)categoryIdentifier
{
    NSString *title = [PPProviderCompaniesSafeString([entry.user bestDisplayName]) copy];
    if (title.length == 0) {
        NSMutableArray<NSString *> *parts = [NSMutableArray array];
        if (entry.user.FirstName.length > 0) [parts addObject:entry.user.FirstName];
        if (entry.user.LastName.length > 0) [parts addObject:entry.user.LastName];
        title = parts.count > 0 ? [parts componentsJoinedByString:@" "] : PPProviderCompaniesSafeString(entry.user.UserName);
    }
    if (title.length == 0) {
        title = PPProviderCompaniesTitleForCategoryIdentifier(categoryIdentifier);
    }

    [_mediaView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.66]];
    [_avatarShellView pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:0.55]];
    _avatarShellView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.20];
    _cityPillView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.16];
    [_cityPillView pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:0.26]];
    _chevronContainerView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.18];
    [_chevronContainerView pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:0.30]];

    BOOL showVerified = entry.user.isVerified;
    _avatarVerifiedIconView.hidden = !showVerified;
    if (showVerified) {
        if (@available(iOS 13.0, *)) {
            _avatarVerifiedIconView.image =
                [[UIImage systemImageNamed:@"checkmark.seal.fill"
                         withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:15.0
                                                                                           weight:UIImageSymbolWeightBold]]
                 imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
        _avatarVerifiedIconView.tintColor = [UIColor colorWithRed:0.31 green:0.86 blue:0.57 alpha:1.0];
    } else {
        _avatarVerifiedIconView.image = nil;
    }

    _titleLabel.text = title;
    NSString *subtitle = PPProviderCompaniesCellDisplaySubtitle(entry, categoryIdentifier);
    _subtitleLabel.text = subtitle;
    _subtitleLabel.hidden = subtitle.length == 0;

    NSString *cityText = PPProviderCompaniesCityForEntry(entry);
    _cityLabel.text = cityText;
    BOOL hasCity = cityText.length > 0;
    if (hasCity) {
        if (![[_identityStackView arrangedSubviews] containsObject:_cityPillView]) {
            [_identityStackView insertArrangedSubview:_cityPillView atIndex:1];
        }
        _cityPillView.hidden = NO;
        _cityPillHeightConstraint.priority = UILayoutPriorityDefaultHigh;
    } else {
        [_identityStackView removeArrangedSubview:_cityPillView];
        _cityPillView.hidden = YES;
        _cityPillHeightConstraint.priority = UILayoutPriorityDefaultLow;
    }
    if (@available(iOS 13.0, *)) {
        _cityIconView.image = [[UIImage systemImageNamed:@"mappin.and.ellipse"
                                       withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:11.0
                                                                                                         weight:UIImageSymbolWeightSemibold]]
                              imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    _cityIconView.tintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.82];
    _cityLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.88];

    UIImage *placeholder = [PPModernAvatarRenderer avatarImageForName:title size:60.0];
    _avatarImageView.image = placeholder ?: PPSYSImage(@"person.crop.circle.fill");
    _coverImageView.image = PPImage(@"providers_placeholder") ?: _avatarImageView.image;

    NSString *avatarURL = PPProviderCompaniesSafeString(entry.user.UserImageUrl.absoluteString);
    if (avatarURL.length > 0) {
        [[PPImageLoaderManager shared] setImageOnImageView:_avatarImageView
                                                       url:avatarURL
                                               placeholder:_avatarImageView.image
                                                complation:nil];
    }

    NSString *coverImageURLString = @"";
    if (entry.user.coverImageUrls.count > 0) {
        coverImageURLString = PPProviderCompaniesSafeString(entry.user.coverImageUrls.firstObject);
    }
    if (coverImageURLString.length == 0 && entry.items.count > 0) {
        PetAccessory *latestProduct = entry.items.firstObject;
        if (latestProduct.imageURLsArray.count > 0) {
            coverImageURLString = PPProviderCompaniesSafeString(latestProduct.imageURLsArray.firstObject);
        }
    }
    if (coverImageURLString.length == 0) {
        coverImageURLString = avatarURL;
    }
    if (coverImageURLString.length > 0) {
        [[PPImageLoaderManager shared] setImageOnImageView:_coverImageView
                                                       url:coverImageURLString
                                               placeholder:_coverImageView.image
                                           transitionStyle:PPImageTransitionStyleCrossDissolve
                                                complation:nil];
    }

    self.accessibilityLabel = [NSString stringWithFormat:@"%@, %@, %@, %@",
                               title,
                               _subtitleLabel.text ?: @"",
                               PPProviderCompaniesTitleForCategoryIdentifier(categoryIdentifier),
                               _cityLabel.text ?: @""];
    self.accessibilityHint = kLang(@"a11y_cell_tap_hint") ?: @"Double-tap to view details";
    self.accessibilityTraits = UIAccessibilityTraitButton;
    [self setNeedsLayout];
    [self.contentView setNeedsLayout];
    [UIView performWithoutAnimation:^{
        [self.contentView layoutIfNeeded];
    }];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    if (UIAccessibilityIsReduceMotionEnabled()) {
        _cardView.transform = CGAffineTransformIdentity;
        _cardView.alpha = highlighted ? 0.92 : 1.0;
        return;
    }

    CGAffineTransform target = highlighted ? CGAffineTransformMakeScale(0.982, 0.982) : CGAffineTransformIdentity;
    CGFloat alpha = highlighted ? 0.94 : 1.0;
    NSTimeInterval duration = highlighted ? 0.09 : 0.24;
    UIViewAnimationOptions options = UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState;
    [UIView animateWithDuration:duration
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.18
                        options:options
                     animations:^{
        self->_cardView.transform = target;
        self->_cardView.alpha = alpha;
    } completion:nil];
}

- (void)pp_runEntranceAnimationWithDelay:(NSTimeInterval)delay
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        _cardView.alpha = 1.0;
        _cardView.transform = CGAffineTransformIdentity;
        return;
    }

    _cardView.alpha = 0.0;
    _cardView.transform = CGAffineTransformScale(CGAffineTransformMakeTranslation(0.0, 10.0), 0.985, 0.985);

    [UIView animateWithDuration:0.34
                          delay:delay
         usingSpringWithDamping:0.90
          initialSpringVelocity:0.22
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self->_cardView.alpha = 1.0;
        self->_cardView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    PPProviderCompaniesApplyContinuousCorners(_cardView, 30.0);
    _cardView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:_cardView.bounds cornerRadius:30.0].CGPath;
    PPProviderCompaniesApplyContinuousCorners(_mediaView, 30.0);
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _readabilityGradientLayer.frame = _imageScrimView.bounds;
    _readabilityGradientLayer.colors = @[
        (__bridge id)[UIColor colorWithWhite:0.0 alpha:0.06].CGColor,
        (__bridge id)[UIColor colorWithWhite:0.0 alpha:0.14].CGColor,
        (__bridge id)[UIColor colorWithWhite:0.0 alpha:0.72].CGColor
    ];
    _readabilityGradientLayer.locations = @[@0.0, @0.45, @1.0];
    [CATransaction commit];
    PPProviderCompaniesApplyContinuousCorners(_avatarShellView, CGRectGetWidth(_avatarShellView.bounds) * 0.5);
    PPProviderCompaniesApplyContinuousCorners(_avatarImageView, CGRectGetWidth(_avatarImageView.bounds) * 0.5);
    _avatarShellView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:_avatarShellView.bounds
                                                                   cornerRadius:CGRectGetWidth(_avatarShellView.bounds) * 0.5].CGPath;
    PPProviderCompaniesApplyContinuousCorners(_cityPillView, CGRectGetHeight(_cityPillView.bounds) * 0.5);
    _chevronContainerView.layer.cornerRadius = CGRectGetWidth(_chevronContainerView.bounds) * 0.5;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    _cardView.transform = CGAffineTransformIdentity;
    _cardView.alpha = 1.0;
    [[PPImageLoaderManager shared] cancelImageLoadForImageView:_coverImageView];
    [[PPImageLoaderManager shared] cancelImageLoadForImageView:_avatarImageView];
    _coverImageView.image = nil;
    _avatarImageView.image = nil;
    _cityIconView.image = nil;
    _titleLabel.text = nil;
    _subtitleLabel.text = nil;
    _subtitleLabel.hidden = NO;
    _cityLabel.text = nil;
    if (![[_identityStackView arrangedSubviews] containsObject:_cityPillView]) {
        [_identityStackView insertArrangedSubview:_cityPillView atIndex:1];
    }
    _cityPillView.hidden = NO;
    _cityPillHeightConstraint.priority = UILayoutPriorityDefaultHigh;
    _avatarVerifiedIconView.image = nil;
    _avatarVerifiedIconView.hidden = YES;
    self.accessibilityHint = nil;
    self.accessibilityLabel = nil;
}

@end
