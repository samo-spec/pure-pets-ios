

#import "MainBannerModel.h"
#import "PPChatsFunc.h"
#import "PetAdoptCollectionViewCell.h"
#import "PPBannerCollectionCell.h"
#import "PPBannersCollection.h"
#import "PPBannersManager.h"
#import "PPBannerViewModel.h"
#import "PPCategoryCardCell.h"
#import "PPHomeFunc.h"
#import "PPHomeViewController.h"
#import "PPSPinnerView.h"
#import "PPSearchViewController.h"
#import "PPDataViewInput.h"
#import "PPDataViewVC.h"
#import "PPPetProfile.h"
#import "PPPetProfileEditorViewController.h"
#import "PPHomePremiumCareCell.h"
#import "PPPetProfilesViewController.h"
#import "PetCare/PPPetCareViewController.h"
#import "PPVetLocator.h"
#import "PPBrowseHistoryManager.h"
#import "PPImageLoaderManager.h"
#import "PPModernAvatarRenderer.h"
#import "SearchCacheManager.h"
#import "PPHomeLayoutManager.h"
#import "AdoptPetsViewController.h"
#import "PPAdSharingHelper.h"
#import "AppClasses.h"
#import "CartManager.h"
#import "CountryModel.h"
#import "OrderDetailsViewController.h"
#import "OrderHistoryViewController.h"
#import "PPOrder.h"
#import "PPRolePermission.h"
#import "PPHomeHeroCell.h"
#import "PPModerHomeCell.h"
#import "PPModernHomeActionCell.h"
#import "PPHomeModels.h"
#import "PPHUD.h"
#import "PPCommerceFeedbackManager.h"
#import "LocationPickerViewController.h"
#import <AudioToolbox/AudioToolbox.h>
#import <CoreLocation/CoreLocation.h>
#import <FirebaseAuth/FirebaseAuth.h>
#import <FirebaseFirestore/FirebaseFirestore.h>
#import <SafariServices/SafariServices.h>
#import <TargetConditionals.h>
#import <math.h>
#import <float.h>
#import "PPHomeOrderStatusCell.h"
#import "PPNovaChatViewController.h"
#import "UIView+Badge.h"
#import "PPHomeLocationSheetViewController.h"
#import "PPHomeInsetLabel.h"
#import "PPHomeLocationTitleView.h"
#import "PPHomeSmartSearchTitleView.h"
#import "PPHomePremiumSearchCell.h"


extern NSString * const PPThemePreferenceDidChangeNotification;
static NSString * const PPHomeConfigCacheKey = @"PPHomeConfig.cache.v1";
static NSString * const PPHomeConfigCacheSectionsKey = @"sections";
static NSString * const PPHomeConfigCacheTitleModeKey = @"titleViewMode";
static NSString * const PPHomeConfigCachePremiumCareVisibleKey = @"premiumCareVisible";
static NSString * const PPHomeConfigCacheNovaFloatingVisibleKey = @"novaFloatingVisible";
static NSString * const PPHomeConfigCacheNovaUseGenkitKey = @"novaUseGenkit";
static NSString * const PPNovaFloatingVisibilityDidChangeNotification = @"PPNovaFloatingVisibilityDidChangeNotification";
static NSString * const PPNovaFloatingVisibilityValueKey = @"visible";

static UISemanticContentAttribute PPHomeCurrentSemanticAttribute(void)
{
    return [Language semanticAttributeForCurrentLanguage];
}

static NSTextAlignment PPHomeCurrentTextAlignment(void)
{
    return [Language alignmentForCurrentLanguage];
}

static NSArray<UIBarButtonItem *> *PPHomeBarButtonItems(UIBarButtonItem * _Nullable item)
{
    return item ? @[item] : @[];
}

static void PPHomePrepareProfileMenuButton(UIButton * _Nullable button)
{
    if (!button) {
        return;
    }

    if (@available(iOS 14.0, *)) {
        button.menu = nil;
        button.showsMenuAsPrimaryAction = NO;
    }
}

static void PPHomeApplySemanticToViewTree(UIView * _Nullable view, UISemanticContentAttribute semantic)
{
    if (!view) {
        return;
    }

    view.semanticContentAttribute = semantic;
    for (UIView *subview in view.subviews) {
        PPHomeApplySemanticToViewTree(subview, semantic);
    }
}

static NSArray<NSString *> *PPHomeSanitizedGradientHexColors(NSArray<NSString *> * _Nullable colors)
{
    if (![colors isKindOfClass:NSArray.class] || colors.count == 0) {
        return @[];
    }

    NSMutableArray<NSString *> *sanitizedColors = [NSMutableArray arrayWithCapacity:colors.count];
    for (id color in colors) {
        if (![color isKindOfClass:NSString.class]) {
            continue;
        }

        NSString *hex = [((NSString *)color) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (hex.length == 0) {
            continue;
        }
        [sanitizedColors addObject:hex];
    }

    return sanitizedColors.copy;
}

static void PPHomeApplyFallbackPromoPalette(PPHomePromoCarouselCard *card, NSInteger idx)
{
    switch (idx % 4) {
        case 1:
            card.startColorHex = @"#F39B3C";
            card.endColorHex = @"#E9792C";
            card.accentColorHex = @"#FFD893";
            break;
        case 2:
            card.startColorHex = @"#F2A84A";
            card.endColorHex = @"#D96F27";
            card.accentColorHex = @"#FFC773";
            break;
        case 3:
            card.startColorHex = @"#EF9740";
            card.endColorHex = @"#D86721";
            card.accentColorHex = @"#FFD28B";
            break;
        default:
            card.startColorHex = @"#F5A63A";
            card.endColorHex = @"#EF8628";
            card.accentColorHex = @"#FFC86D";
            break;
    }
}

static void PPHomeApplyPromoGradientPalette(PPHomePromoCarouselCard *card, NSArray<NSString *> *gradientColors, NSInteger idx)
{
    NSArray<NSString *> *sanitizedColors = PPHomeSanitizedGradientHexColors(gradientColors);
    if (sanitizedColors.count >= 2) {
        card.startColorHex = sanitizedColors.firstObject;
        card.endColorHex = sanitizedColors.lastObject;
        NSUInteger accentIndex = sanitizedColors.count > 2 ? (sanitizedColors.count / 2) : 0;
        NSString *accentHex = PPSafeString(sanitizedColors[accentIndex]);
        if (accentHex.length == 0) {
            accentHex = PPSafeString(sanitizedColors.firstObject);
        }
        card.accentColorHex = accentHex;
        return;
    }

    PPHomeApplyFallbackPromoPalette(card, idx);
}

@interface PPHomePetProfileCardCell : UICollectionViewCell
+ (NSString *)reuseIdentifier;
- (void)configureWithDefaultPet:(nullable PPPetProfile *)defaultPet
                       petCount:(NSInteger)petCount
                      isLoading:(BOOL)isLoading;
@end

@implementation PPHomePetProfileCardCell {
    UIView *_cardView;
    UIView *_largeOrbView;
    UIView *_smallOrbView;
    UIView *_avatarShellView;
    UIImageView *_avatarImageView;
    PPInsetLabel *_eyebrowLabel;
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
    UIStackView *_metaStackView;
    PPHomeInsetLabel *_metaPrimaryLabel;
    PPHomeInsetLabel *_metaSecondaryLabel;
    UIView *_ctaView;
    UILabel *_ctaLabel;
    UIImageView *_ctaImageView;
    CAGradientLayer *_gradientLayer;
}

+ (NSString *)reuseIdentifier
{
    return @"PPHomePetProfileCardCell";
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;
    self.contentView.isAccessibilityElement = NO;

    UIView *cardView = [[UIView alloc] init];
    cardView.translatesAutoresizingMaskIntoConstraints = NO;
    cardView.layer.cornerRadius = 30.0;
    cardView.layer.borderWidth = 0.7;
    [cardView pp_setBorderColor:[PPPetsUISurfaceBorderColor() colorWithAlphaComponent:0.08]];
    [cardView pp_setShadowColor:UIColor.blackColor];
    cardView.layer.shadowOpacity = 0.06f;
    cardView.layer.shadowRadius = 14.0f;
    cardView.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    if (@available(iOS 13.0, *)) {
        cardView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.contentView addSubview:cardView];
    _cardView = cardView;

    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    gradientLayer.startPoint = CGPointMake(0.0, 0.18);
    gradientLayer.endPoint = CGPointMake(1.0, 1.0);
    gradientLayer.cornerRadius = 30.0;
    [cardView.layer insertSublayer:gradientLayer atIndex:0];
    _gradientLayer = gradientLayer;

    UIView *largeOrbView = [[UIView alloc] init];
    largeOrbView.translatesAutoresizingMaskIntoConstraints = NO;
    largeOrbView.userInteractionEnabled = NO;
    largeOrbView.layer.cornerRadius = 54.0;
    [cardView addSubview:largeOrbView];
    _largeOrbView = largeOrbView;

    UIView *smallOrbView = [[UIView alloc] init];
    smallOrbView.translatesAutoresizingMaskIntoConstraints = NO;
    smallOrbView.userInteractionEnabled = NO;
    smallOrbView.layer.cornerRadius = 18.0;
    [cardView addSubview:smallOrbView];
    _smallOrbView = smallOrbView;

    UIView *avatarShellView = [[UIView alloc] init];
    avatarShellView.translatesAutoresizingMaskIntoConstraints = NO;
    avatarShellView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.18];
    avatarShellView.layer.cornerRadius = 41.0;
    avatarShellView.layer.borderWidth = 1.0;
    [avatarShellView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.24]];
    [avatarShellView pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
    avatarShellView.layer.shadowOpacity = 0.10f;
    avatarShellView.layer.shadowRadius = 20.0f;
    avatarShellView.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    if (@available(iOS 13.0, *)) {
        avatarShellView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [cardView addSubview:avatarShellView];
    _avatarShellView = avatarShellView;

    UIImageView *avatarImageView = [[UIImageView alloc] init];
    avatarImageView.translatesAutoresizingMaskIntoConstraints = NO;
    avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    avatarImageView.clipsToBounds = YES;
    avatarImageView.layer.cornerRadius = 34.0;
    avatarImageView.layer.borderWidth = 1.5;
    [avatarImageView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.35]];
    if (@available(iOS 13.0, *)) {
        avatarImageView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    avatarImageView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
    [avatarShellView addSubview:avatarImageView];
    _avatarImageView = avatarImageView;

    PPInsetLabel *eyebrowLabel = [[PPInsetLabel alloc] init];
    eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowLabel.font = [GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    eyebrowLabel.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.72];
    eyebrowLabel.textColor = [UIColor colorWithRed:0.29 green:0.18 blue:0.10 alpha:1.0];
    eyebrowLabel.layer.cornerRadius = 14.0;
    eyebrowLabel.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        eyebrowLabel.layer.cornerCurve = kCACornerCurveContinuous;
    }
    eyebrowLabel.numberOfLines = 1;
    eyebrowLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    eyebrowLabel.textInsets = UIEdgeInsetsMake(4.0, 14.0, 4.0, 14.0);
    eyebrowLabel.textAlignment = PPHomeCurrentTextAlignment();
    [cardView addSubview:eyebrowLabel];
    _eyebrowLabel = eyebrowLabel;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:24.0] ?: [UIFont systemFontOfSize:24.0 weight:UIFontWeightBold];
    titleLabel.textColor = [UIColor colorWithRed:0.23 green:0.13 blue:0.10 alpha:1.0];
    titleLabel.numberOfLines = 1;
    titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.minimumScaleFactor = 0.84;
    titleLabel.allowsDefaultTighteningForTruncation = YES;
    titleLabel.textAlignment = PPHomeCurrentTextAlignment();
    [cardView addSubview:titleLabel];
    _titleLabel = titleLabel;

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    subtitleLabel.textColor = [UIColor colorWithRed:0.33 green:0.22 blue:0.18 alpha:0.82];
    subtitleLabel.numberOfLines = 2;
    subtitleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    subtitleLabel.textAlignment = PPHomeCurrentTextAlignment();
    [cardView addSubview:subtitleLabel];
    _subtitleLabel = subtitleLabel;

    UIStackView *metaStackView = [[UIStackView alloc] init];
    metaStackView.translatesAutoresizingMaskIntoConstraints = NO;
    metaStackView.axis = UILayoutConstraintAxisHorizontal;
    metaStackView.alignment = UIStackViewAlignmentLeading;
    metaStackView.spacing = 8.0;
    metaStackView.distribution = UIStackViewDistributionFillProportionally;
    [cardView addSubview:metaStackView];
    _metaStackView = metaStackView;

    PPHomeInsetLabel *metaPrimaryLabel = [[PPHomeInsetLabel alloc] init];
    metaPrimaryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    metaPrimaryLabel.font = [GM MidFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    metaPrimaryLabel.textColor = [UIColor colorWithRed:0.33 green:0.22 blue:0.18 alpha:0.94];
    metaPrimaryLabel.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.54];
    metaPrimaryLabel.layer.cornerRadius = 13.0;
    metaPrimaryLabel.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        metaPrimaryLabel.layer.cornerCurve = kCACornerCurveContinuous;
    }
    metaPrimaryLabel.contentInsets = UIEdgeInsetsMake(7.0, 10.0, 7.0, 10.0);
    metaPrimaryLabel.textAlignment = PPHomeCurrentTextAlignment();
    [metaPrimaryLabel.heightAnchor constraintEqualToConstant:28.0].active = YES;
    [metaStackView addArrangedSubview:metaPrimaryLabel];
    _metaPrimaryLabel = metaPrimaryLabel;

    PPHomeInsetLabel *metaSecondaryLabel = [[PPHomeInsetLabel alloc] init];
    metaSecondaryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    metaSecondaryLabel.font = [GM MidFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    metaSecondaryLabel.textColor = [UIColor colorWithRed:0.33 green:0.22 blue:0.18 alpha:0.94];
    metaSecondaryLabel.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.46];
    metaSecondaryLabel.layer.cornerRadius = 13.0;
    metaSecondaryLabel.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        metaSecondaryLabel.layer.cornerCurve = kCACornerCurveContinuous;
    }
    metaSecondaryLabel.contentInsets = UIEdgeInsetsMake(7.0, 10.0, 7.0, 10.0);
    metaSecondaryLabel.textAlignment = PPHomeCurrentTextAlignment();
    [metaSecondaryLabel.heightAnchor constraintEqualToConstant:28.0].active = YES;
    [metaStackView addArrangedSubview:metaSecondaryLabel];
    _metaSecondaryLabel = metaSecondaryLabel;

    UIView *ctaView = [[UIView alloc] init];
    ctaView.translatesAutoresizingMaskIntoConstraints = NO;
    ctaView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.26];
    ctaView.layer.cornerRadius = 18.0;
    ctaView.layer.borderWidth = 1.0;
    [ctaView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.24]];
    if (@available(iOS 13.0, *)) {
        ctaView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [cardView addSubview:ctaView];
    _ctaView = ctaView;

    UILabel *ctaLabel = [[UILabel alloc] init];
    ctaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    ctaLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    ctaLabel.textColor = [UIColor colorWithRed:0.22 green:0.13 blue:0.09 alpha:1.0];
    ctaLabel.textAlignment = PPHomeCurrentTextAlignment();
    [ctaView addSubview:ctaLabel];
    _ctaLabel = ctaLabel;

    UIImageView *ctaImageView = [[UIImageView alloc] init];
    ctaImageView.translatesAutoresizingMaskIntoConstraints = NO;
    ctaImageView.contentMode = UIViewContentModeScaleAspectFit;
    [ctaView addSubview:ctaImageView];
    _ctaImageView = ctaImageView;

    [eyebrowLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                 forAxis:UILayoutConstraintAxisVertical];
    [eyebrowLabel setContentHuggingPriority:UILayoutPriorityRequired
                                    forAxis:UILayoutConstraintAxisVertical];
    [titleLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                forAxis:UILayoutConstraintAxisVertical];
    [subtitleLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                   forAxis:UILayoutConstraintAxisVertical];

    [NSLayoutConstraint activateConstraints:@[
        [cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

        [largeOrbView.widthAnchor constraintEqualToConstant:108.0],
        [largeOrbView.heightAnchor constraintEqualToConstant:108.0],
        [largeOrbView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:28.0],
        [largeOrbView.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:-26.0],

        [smallOrbView.widthAnchor constraintEqualToConstant:36.0],
        [smallOrbView.heightAnchor constraintEqualToConstant:36.0],
        [smallOrbView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:18.0],
        [smallOrbView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-24.0],

        [avatarShellView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-18.0],
        [avatarShellView.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:18.0],
        [avatarShellView.widthAnchor constraintEqualToConstant:82.0],
        [avatarShellView.heightAnchor constraintEqualToConstant:82.0],

        [avatarImageView.centerXAnchor constraintEqualToAnchor:avatarShellView.centerXAnchor],
        [avatarImageView.centerYAnchor constraintEqualToAnchor:avatarShellView.centerYAnchor],
        [avatarImageView.widthAnchor constraintEqualToConstant:68.0],
        [avatarImageView.heightAnchor constraintEqualToConstant:68.0],

        [eyebrowLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:18.0],
        [eyebrowLabel.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:18.0],
        [eyebrowLabel.heightAnchor constraintGreaterThanOrEqualToConstant:28.0],
        [eyebrowLabel.trailingAnchor constraintLessThanOrEqualToAnchor:avatarShellView.leadingAnchor constant:-14.0],

        [titleLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:12.0],
        [titleLabel.topAnchor constraintEqualToAnchor:eyebrowLabel.bottomAnchor constant:6.0],
        [titleLabel.heightAnchor constraintGreaterThanOrEqualToConstant:30.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:avatarShellView.leadingAnchor constant:-14.0],

        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:avatarShellView.leadingAnchor constant:-14.0],

        [metaStackView.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [metaStackView.topAnchor constraintGreaterThanOrEqualToAnchor:subtitleLabel.bottomAnchor constant:12.0],
        [metaStackView.trailingAnchor constraintLessThanOrEqualToAnchor:cardView.trailingAnchor constant:-18.0],

        [ctaView.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [ctaView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-18.0],
        [ctaView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-18.0],
        [ctaView.heightAnchor constraintEqualToConstant:44.0],
        [ctaView.topAnchor constraintEqualToAnchor:metaStackView.bottomAnchor constant:12.0],

        [ctaLabel.leadingAnchor constraintEqualToAnchor:ctaView.leadingAnchor constant:14.0],
        [ctaLabel.centerYAnchor constraintEqualToAnchor:ctaView.centerYAnchor],
        [ctaLabel.trailingAnchor constraintLessThanOrEqualToAnchor:ctaImageView.leadingAnchor constant:-10.0],

        [ctaImageView.trailingAnchor constraintEqualToAnchor:ctaView.trailingAnchor constant:-14.0],
        [ctaImageView.centerYAnchor constraintEqualToAnchor:ctaView.centerYAnchor],
        [ctaImageView.widthAnchor constraintEqualToConstant:13.0],
        [ctaImageView.heightAnchor constraintEqualToConstant:13.0],
    ]];

    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [[PPImageLoaderManager shared] cancelImageLoadForImageView:_avatarImageView];
    _avatarImageView.image = nil;

    // Reset visual state to prevent stale gradient/text on cell reuse
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _gradientLayer.colors = nil;
    [CATransaction commit];

    _eyebrowLabel.text = nil;
    _titleLabel.text = nil;
    _subtitleLabel.text = nil;
    _metaPrimaryLabel.text = nil;
    _metaSecondaryLabel.text = nil;
    _ctaLabel.text = nil;
}

- (void)pp_refreshCardGeometry
{
    CGRect cardBounds = _cardView.bounds;
    if (CGRectIsEmpty(cardBounds)) {
        return;
    }

    // Keep decorative layers locked to the resolved card bounds on first render.
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _gradientLayer.frame = cardBounds;
    _gradientLayer.cornerRadius = _cardView.layer.cornerRadius;
    [CATransaction commit];

    _eyebrowLabel.layer.cornerRadius = CGRectGetHeight(_eyebrowLabel.bounds) * 0.5;
    _cardView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:cardBounds
                                                            cornerRadius:_cardView.layer.cornerRadius].CGPath;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self pp_refreshCardGeometry];
}

- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    [super applyLayoutAttributes:layoutAttributes];
    [self setNeedsLayout];
    [self.contentView setNeedsLayout];
    [self layoutIfNeeded];
    [self pp_refreshCardGeometry];
}

- (void)setBounds:(CGRect)bounds
{
    [super setBounds:bounds];
    [self pp_refreshCardGeometry];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_refreshThemeColors];
        }
    }
}

- (void)pp_refreshThemeColors
{
    BOOL isDark = NO;
    if (@available(iOS 13.0, *)) {
        isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    [_cardView pp_setBorderColor:[PPPetsUISurfaceBorderColor() colorWithAlphaComponent:0.08]];
    _cardView.layer.shadowOpacity = isDark ? 0.0f : 0.10f;
    [_avatarShellView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:(isDark ? 0.10 : 0.24)]];
    [_avatarImageView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.35]];
    [_ctaView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:(isDark ? 0.12 : 0.24)]];
}

- (void)configureWithDefaultPet:(nullable PPPetProfile *)defaultPet
                       petCount:(NSInteger)petCount
                      isLoading:(BOOL)isLoading
{
    [self pp_refreshThemeColors];

    self.semanticContentAttribute = PPHomeCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPHomeCurrentSemanticAttribute();
    _cardView.semanticContentAttribute = PPHomeCurrentSemanticAttribute();
    _metaStackView.semanticContentAttribute = PPHomeCurrentSemanticAttribute();
    _ctaView.semanticContentAttribute = PPHomeCurrentSemanticAttribute();
    _eyebrowLabel.textAlignment = PPHomeCurrentTextAlignment();
    _titleLabel.textAlignment = PPHomeCurrentTextAlignment();
    _subtitleLabel.textAlignment = PPHomeCurrentTextAlignment();
    _metaPrimaryLabel.textAlignment = PPHomeCurrentTextAlignment();
    _metaSecondaryLabel.textAlignment = PPHomeCurrentTextAlignment();
    _ctaLabel.textAlignment = PPHomeCurrentTextAlignment();

    BOOL hasProfiles = (petCount > 0);
    BOOL isDark = NO;
    if (@available(iOS 13.0, *)) {
        isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    UIColor *textColor = isDark
        ? [UIColor colorWithRed:0.95 green:0.90 blue:0.86 alpha:1.0]
        : [UIColor colorWithRed:0.23 green:0.13 blue:0.10 alpha:1.0];
    NSString *forwardSymbol = Language.isRTL ? @"arrow.left" : @"arrow.right";
    NSArray<UIColor *> *gradientColors = nil;
    UIColor *orbColor = [PPPetsUIBrandColor() colorWithAlphaComponent:0.24];
    UIImage *avatarPlaceholder = nil;

    if (isLoading) {
        _eyebrowLabel.text = kLang(@"please_wait") ?: @"Loading";
        _titleLabel.text = kLang(@"pet_profiles_title") ?: @"Pet Profiles";
        _subtitleLabel.text = kLang(@"pet_profiles_loading_home_subtitle") ?: @"Syncing your companion card and care details for the home feed.";
        _metaPrimaryLabel.text = kLang(@"home_pet_profile_meta_syncing") ?: @"Live sync";
        _metaSecondaryLabel.text = kLang(@"home_pet_profile_meta_health") ?: @"Health details";
        _ctaLabel.text = kLang(@"please_wait") ?: @"Please wait";
        gradientColors = isDark
            ? @[[UIColor colorWithRed:0.14 green:0.10 blue:0.08 alpha:1.0],
                [UIColor colorWithRed:0.18 green:0.13 blue:0.10 alpha:1.0]]
            : @[[UIColor colorWithRed:0.98 green:0.92 blue:0.82 alpha:1.0],
                [UIColor colorWithRed:0.94 green:0.83 blue:0.71 alpha:1.0]];
        avatarPlaceholder = [[UIImage systemImageNamed:@"hourglass.circle.fill"
                                     withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:30.0
                                                                                                    weight:UIImageSymbolWeightSemibold]] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        _avatarImageView.tintColor = [PPPetsUIBrandColor() colorWithAlphaComponent:0.85];
    } else if (defaultPet) {
        NSString *ageText = [defaultPet displayAgeText];
        NSMutableArray<NSString *> *summaryParts = [NSMutableArray array];
        if (defaultPet.breed.length > 0) {
            [summaryParts addObject:defaultPet.breed];
        }
        if (ageText.length > 0) {
            [summaryParts addObject:ageText];
        }

        _eyebrowLabel.text = defaultPet.isDefaultPet
            ? (kLang(@"pet_default_action") ?: @"Default pet")
            : (kLang(@"pet_profiles_title") ?: @"Pet Profiles");
        _titleLabel.text = defaultPet.name.length > 0
            ? defaultPet.name
            : (kLang(@"pet_name_placeholder") ?: @"Your pet");

        NSString *headline = summaryParts.count > 0
            ? [summaryParts componentsJoinedByString:@" · "]
            : (kLang(@"pet_profiles_home_ready") ?: @"Care details ready on home");
        NSString *detailLine = defaultPet.vaccinations.count > 0
            ? [NSString stringWithFormat:@"%ld %@ ready for  access",
               (long)defaultPet.vaccinations.count,
               (kLang(@"pet_vaccines_short") ?: @"vaccines")]
            : (kLang(@"home_pet_profile_vaccine_prompt") ?: @"Open the profile to update vaccines, notes, and reminders.");
        _subtitleLabel.text = [NSString stringWithFormat:@"%@\n%@", headline, detailLine];
        _metaPrimaryLabel.text = [NSString stringWithFormat:@"💉 %ld %@",
                                  (long)defaultPet.vaccinations.count,
                                  (kLang(@"pet_vaccines_short") ?: @"vaccines")];
        _metaSecondaryLabel.text = [NSString stringWithFormat:@"%ld %@",
                                    (long)petCount,
                                    (petCount == 1
                                     ? (kLang(@"pet_profile_single") ?: @"saved profile")
                                     : (kLang(@"pet_profiles_title") ?: @"saved profiles"))];
        _ctaLabel.text = kLang(@"home_pet_profile_open_cta") ?: @"Open pet profile";
        gradientColors = isDark
            ? @[[UIColor colorWithRed:0.16 green:0.10 blue:0.06 alpha:1.0],
                [UIColor colorWithRed:0.22 green:0.12 blue:0.06 alpha:1.0]]
            : @[[UIColor colorWithRed:0.99 green:0.88 blue:0.76 alpha:1.0],
                [UIColor colorWithRed:0.96 green:0.65 blue:0.43 alpha:1.0]];
        avatarPlaceholder = defaultPet.imageURL.length > 0
            ? [[UIImage systemImageNamed:@"pawprint.circle.fill"
                       withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:28.0
                                                                                          weight:UIImageSymbolWeightSemibold]]
                imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
            : [PPModernAvatarRenderer avatarImageForName:(defaultPet.name ?: @"") size:84.0];
        _avatarImageView.tintColor = UIColor.whiteColor;
    } else if (hasProfiles) {
        _eyebrowLabel.text = kLang(@"pet_profiles_title") ?: @"Pet Profiles";
        _titleLabel.text = kLang(@"home_pet_profile_choose_default_title") ?: @"Choose your default pet";
        _subtitleLabel.text = kLang(@"home_pet_profile_choose_default_subtitle") ?: @"Pin one companion here for quick home access to care details, vaccines, and reminders.";
        _metaPrimaryLabel.text = [NSString stringWithFormat:@"%ld %@",
                                  (long)petCount,
                                  (petCount == 1
                                   ? (kLang(@"pet_profile_single") ?: @"saved profile")
                                   : (kLang(@"pet_profiles_title") ?: @"saved profiles"))];
        _metaSecondaryLabel.text = kLang(@"home_pet_profile_set_default_meta") ?: @"Tap to set default";
        _ctaLabel.text = kLang(@"home_pet_profile_open_editor_cta") ?: @"Open pet editor";
        gradientColors = isDark
            ? @[[UIColor colorWithRed:0.15 green:0.10 blue:0.07 alpha:1.0],
                [UIColor colorWithRed:0.20 green:0.12 blue:0.08 alpha:1.0]]
            : @[[UIColor colorWithRed:0.99 green:0.91 blue:0.82 alpha:1.0],
                [UIColor colorWithRed:0.96 green:0.75 blue:0.58 alpha:1.0]];
        orbColor = isDark
            ? [[UIColor colorWithRed:0.95 green:0.52 blue:0.31 alpha:1.0] colorWithAlphaComponent:0.12]
            : [[UIColor colorWithRed:0.95 green:0.52 blue:0.31 alpha:1.0] colorWithAlphaComponent:0.22];
        avatarPlaceholder = [[UIImage systemImageNamed:@"pawprint.circle.fill"
                                     withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:30.0
                                                                                                    weight:UIImageSymbolWeightSemibold]]
                              imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        _avatarImageView.tintColor = [PPPetsUIBrandColor() colorWithAlphaComponent:0.88];
    } else {
        _eyebrowLabel.text = kLang(@"pet_profiles_title") ?: @"Pet Profiles";
        _titleLabel.text = kLang(@"home_pet_profile_empty_title") ?: @"Create your pet profile";
        _subtitleLabel.text = kLang(@"home_pet_profile_empty_subtitle") ?: @"Turn this card into a pet dashboard with breed, vaccines, reminders, and your default companion.";
        _metaPrimaryLabel.text = kLang(@"home_pet_profile_meta_vaccines") ?: @"Vaccines";
        _metaSecondaryLabel.text = kLang(@"home_pet_profile_meta_reminders") ?: @"Reminders";
        _ctaLabel.text = kLang(@"pet_profiles_add_first") ?: @"Add your first pet";
        gradientColors = isDark
            ? @[[UIColor colorWithRed:0.13 green:0.10 blue:0.07 alpha:1.0],
                [UIColor colorWithRed:0.18 green:0.13 blue:0.09 alpha:1.0]]
            : @[[UIColor colorWithRed:0.98 green:0.93 blue:0.86 alpha:1.0],
                [UIColor colorWithRed:0.95 green:0.80 blue:0.63 alpha:1.0]];
        orbColor = isDark
            ? [[UIColor colorWithRed:0.93 green:0.58 blue:0.32 alpha:1.0] colorWithAlphaComponent:0.10]
            : [[UIColor colorWithRed:0.93 green:0.58 blue:0.32 alpha:1.0] colorWithAlphaComponent:0.18];
        avatarPlaceholder = [[UIImage systemImageNamed:@"sparkles"
                                     withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:28.0
                                                                                                    weight:UIImageSymbolWeightSemibold]]
                              imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        _avatarImageView.tintColor = [PPPetsUIBrandColor() colorWithAlphaComponent:0.84];
    }

    _gradientLayer.colors = @[(id)gradientColors.firstObject.CGColor,
                              (id)gradientColors.lastObject.CGColor];
    _largeOrbView.backgroundColor = orbColor;
    _smallOrbView.backgroundColor = [UIColor colorWithWhite:(isDark ? 0.0 : 1.0) alpha:(isDark ? 0.18 : 0.28)];
    _titleLabel.textColor = textColor;
    _ctaLabel.textColor = textColor;
    _ctaImageView.tintColor = textColor;

    UIColor *subtleText = isDark
        ? [UIColor colorWithRed:0.85 green:0.78 blue:0.72 alpha:0.90]
        : [UIColor colorWithRed:0.33 green:0.22 blue:0.18 alpha:0.82];
    UIColor *tagText = isDark
        ? [UIColor colorWithRed:0.88 green:0.82 blue:0.76 alpha:0.94]
        : [UIColor colorWithRed:0.33 green:0.22 blue:0.18 alpha:0.94];
    CGFloat pillAlpha = isDark ? 0.16 : 0.54;
    _eyebrowLabel.textColor = isDark
        ? [UIColor colorWithRed:0.90 green:0.82 blue:0.74 alpha:1.0]
        : [UIColor colorWithRed:0.29 green:0.18 blue:0.10 alpha:1.0];
    _eyebrowLabel.backgroundColor = [UIColor colorWithWhite:(isDark ? 0.0 : 1.0) alpha:(isDark ? 0.24 : 0.72)];
    _subtitleLabel.textColor = subtleText;
    _metaPrimaryLabel.textColor = tagText;
    _metaPrimaryLabel.backgroundColor = [UIColor colorWithWhite:(isDark ? 0.0 : 1.0) alpha:pillAlpha];
    _metaSecondaryLabel.textColor = tagText;
    _metaSecondaryLabel.backgroundColor = [UIColor colorWithWhite:(isDark ? 0.0 : 1.0) alpha:(isDark ? 0.14 : 0.46)];
    _ctaView.backgroundColor = [UIColor colorWithWhite:(isDark ? 0.0 : 1.0) alpha:(isDark ? 0.16 : 0.26)];
    _avatarShellView.backgroundColor = [UIColor colorWithWhite:(isDark ? 0.0 : 1.0) alpha:(isDark ? 0.12 : 0.18)];
    _cardView.layer.shadowOpacity = isDark ? 0.0f : 0.10f;
    _ctaImageView.image = [UIImage systemImageNamed:forwardSymbol
                                  withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:13.0
                                                                                                 weight:UIImageSymbolWeightBold]];
    _avatarImageView.image = avatarPlaceholder;

    if (defaultPet.imageURL.length > 0) {
        [[PPImageLoaderManager shared] setImageOnImageView:_avatarImageView
                                                       url:defaultPet.imageURL
                                               placeholder:avatarPlaceholder
                                          transitionStyle:PPImageTransitionStyleNone
                                                complation:nil];
    }

    NSString *accessibilityTitle = _titleLabel.text ?: @"";
    NSString *accessibilitySubtitle = _subtitleLabel.text ?: @"";
    self.accessibilityLabel = [NSString stringWithFormat:@"%@. %@", accessibilityTitle, accessibilitySubtitle];
    self.accessibilityHint = (defaultPet || hasProfiles)
        ? (kLang(@"home_pet_profile_open_hint") ?: @"Opens the pet profile editor")
        : (kLang(@"home_pet_profile_create_hint") ?: @"Opens pet profiles so you can add your first pet");

    // Configuration can land before the compositional layout settles.
    [self setNeedsLayout];
    [self.contentView setNeedsLayout];
    if (!CGRectIsEmpty(_cardView.bounds)) {
        [self layoutIfNeeded];
        [self pp_refreshCardGeometry];
    }
}

@end




@implementation PPHomeProfileView (TapFeedback)

- (void)pp_highlightDown
{
    [UIView animateWithDuration:0.12 animations:^{
        self.transform = CGAffineTransformMakeScale(0.96, 0.96);
        self.alpha = 0.85;
    }];
}

- (void)pp_highlightUp
{
    [UIView animateWithDuration:0.18
                          delay:0
         usingSpringWithDamping:0.7
          initialSpringVelocity:0.4
                        options:0
                     animations:^{
        self.transform = CGAffineTransformIdentity;
        self.alpha = 1.0;
    } completion:nil];
}

@end






@class PPCarouselItem;

@interface PPHomeHeaderConfig : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *actionTitle;
@property (nonatomic, copy) NSString *iconName;
@property (nonatomic, strong, nullable) UIMenu *menu;
@property (nonatomic, assign) BOOL hidden;
@property (nonatomic, assign) PPHomeSection section;
@end

@implementation PPHomeHeaderConfig
@end

@interface PPHomeBuyAgainSnapshotItem : NSObject
@property (nonatomic, copy) NSString *itemID;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *imageURL;
@property (nonatomic, assign) NSInteger mainKindID;
@property (nonatomic, assign) NSInteger accessKindType;
@end

@implementation PPHomeBuyAgainSnapshotItem
@end

@interface PPHomeUnavailableBuyAgainButton : UIButton
@property (nonatomic, strong) PPHomeBuyAgainSnapshotItem *buyAgainItem;
@end

@implementation PPHomeUnavailableBuyAgainButton
@end

 
static NSString * const PPNearbySelectedLatitudeKey = @"pp.home.nearby.latitude";
static NSString * const PPNearbySelectedLongitudeKey = @"pp.home.nearby.longitude";
static NSString * const PPNearbySelectedAreaNameKey = @"pp.home.nearby.areaName";
static NSString * const PPNearbyRecentLocationsKey = @"pp.home.nearby.recentLocations";
static NSString * const PPHomeTopCarouselBannerGroupID = @"HOME_MAIN_TOP_CAROUSEL";
static NSString * const PPHomeCompletedLastOrderSeenOrderIDKeyPrefix = @"pp.home.completedLastOrder.seen.orderID";
static NSString * const PPHomeCompletedLastOrderSeenSessionIDKeyPrefix = @"pp.home.completedLastOrder.seen.sessionID";
static NSString * const PPHomeTerminalOrderSeenOrderIDKeyPrefix = @"pp.home.terminalOrder.seen.orderID";
static NSString * const PPHomeTerminalOrderSeenSessionIDKeyPrefix = @"pp.home.terminalOrder.seen.sessionID";
static NSTimeInterval const PPNearbyMinimumRefreshInterval = 20.0;
static NSTimeInterval const PPHomeOtherOrdersRecentLookbackInterval = 24.0 * 60.0 * 60.0;
static NSTimeInterval const PPHomeCompletedLastOrderVisibilityInterval = 48.0 * 60.0 * 60.0;
static double const PPNearbyDefaultRadiusKm = 8.0;
static double const PPNearbyExpandedRadiusKm = 15.0;
static NSInteger const PPCurrentOrdersVisibleLimit = 4;
static NSInteger const PPBuyAgainVisibleLimit = 10;
static NSInteger const PPHomeUnavailableBuyAgainCoverTag = 551021;
static NSInteger const PPNearbyRecentLocationsLimit = 4;
static CLLocationCoordinate2D const PPNearbyDebugSimulatorCoordinate = {25.285447, 51.531040};

static NSString *PPHomeCurrentAppSessionIdentifier(void)
{
    static NSString *sessionIdentifier = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sessionIdentifier = NSUUID.UUID.UUIDString ?: @"";
    });
    return sessionIdentifier;
}

typedef NS_ENUM(NSInteger, PPNearbyLocationState) {
    PPNearbyLocationStateUnset = 0,
    PPNearbyLocationStateLoading,
    PPNearbyLocationStateReady,
    PPNearbyLocationStateDenied
};

typedef NS_ENUM(NSInteger, PPHomeProfileMenuAction) {
    PPHomeProfileMenuActionProfile = 0,
    PPHomeProfileMenuActionLogin,
    PPHomeProfileMenuActionFavorites,
    PPHomeProfileMenuActionMyAds,
    PPHomeProfileMenuActionCart,
    PPHomeProfileMenuActionOrders,
    PPHomeProfileMenuActionProduction,
    PPHomeProfileMenuActionSettings,
    PPHomeProfileMenuActionSupport
};


@interface PPHomeViewController ()<UICollectionViewDelegate, UICollectionViewDataSourcePrefetching, BannerTapsCollectionDelegate,PPUniversalCellDelegate, CLLocationManagerDelegate>
- (void)pp_handleProfileMenuAction:(PPHomeProfileMenuAction)action;

 @property (nonatomic, assign) BOOL warmUpCache;
@property (nonatomic, assign) BOOL chatsListenerStarted;
@property (nonatomic, copy, nullable) NSString *unreadListenerUserID;
@property (nonatomic, assign) BOOL adsLoaded;
@property (nonatomic, assign) BOOL accessoriesLoaded;
@property (nonatomic, assign) BOOL nearbyLoaded;
@property (nonatomic, assign) BOOL nearbyLoading;
@property (nonatomic, strong) NSArray<ServiceModel *> *nearbyServiceProviders;
@property (nonatomic, assign) BOOL nearbyServicesLoaded;
@property (nonatomic, assign) BOOL nearbyServicesLoading;
@property (nonatomic, assign) BOOL nearbyServicesShowingLatest;
@property (nonatomic, strong, nullable) MainKindsModel *selectedCategory;
@property (nonatomic, strong) PPHomeLayoutManager *layoutManager;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UICollectionViewDiffableDataSource<NSNumber *, PPHomeItem *> *dataSource;
@property (nonatomic, assign) BOOL didSelectInitialNearby;
@property (nonatomic, strong) NSArray<PetAd *> *ads;
@property (nonatomic, strong) NSArray<ServiceModel *> *services;
@property (nonatomic, strong) NSArray<MainKindsModel *> *mainKinds;
@property (nonatomic, strong) NSArray<PPCategoryItem *> *categories;
@property (nonatomic, strong) NSArray<PetAccessory *> *accessories;
@property (nonatomic, strong) NSArray *buyAgainEntries;
@property (nonatomic, strong) NSArray<PetAccessory *> *lastFoodAccessories;
@property (nonatomic, strong) NSArray<PPPetProfile *> *petProfiles;
@property (nonatomic, strong) NSArray<PetAd *> *nearbyAds;
@property (nonatomic, strong, nullable) PPPetProfile *defaultPetProfile;
@property (nonatomic, strong) NSArray<PPOrder *> *currentOrders;
@property (nonatomic, strong) NSArray<PPOrder *> *recentOrders;
@property (nonatomic, strong) NSArray<PPCarouselItem *> *carouselItems;
@property (nonatomic, strong) NSArray<PPHomePromoCarouselCard *> *promoCarouselCards;
@property (nonatomic, strong) CLLocationManager *homeLocationManager;
@property (nonatomic, strong) CLGeocoder *homeGeocoder;
@property (nonatomic, assign) CLLocationCoordinate2D selectedNearbyCoordinate;
@property (nonatomic, assign) BOOL hasSelectedNearbyCoordinate;
@property (nonatomic, copy) NSString *selectedNearbyAreaName;
@property (nonatomic, assign) PPNearbyLocationState nearbyLocationState;
@property (nonatomic, assign) BOOL hasRequestedLocationAuthorization;
@property (nonatomic, assign) NSInteger nearbyRequestToken;
@property (nonatomic, strong) NSDate *lastNearbyRefreshAt;
@property (nonatomic, assign) CLLocationCoordinate2D lastNearbyRefreshCoordinate;
@property (nonatomic, assign) BOOL hasLastNearbyRefreshCoordinate;
@property (nonatomic, assign) double nearbyRadiusKm;
@property (nonatomic, strong) NSTimer *nearbyRefreshTimer;
@property (nonatomic, assign) BOOL isUsingManualNearbySelection;
@property (nonatomic, assign) BOOL nearbyShowingRecentlyAdded;
@property (nonatomic, strong) UIView *pp_premiumBackgroundGlowViewTop;
@property (nonatomic, strong) UIView *pp_premiumBackgroundGlowViewMid;
@property (nonatomic, strong) UIView *pp_premiumBackgroundGlowViewBottom;
@property (nonatomic, strong) NSMutableSet<NSString *> *animatedHomeItemIdentifiers;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *animatedHomeHeaderSections;
@property (nonatomic, strong) NSMutableSet<NSString *> *animatedHomeHorizontalUniversalIdentifiers;
@property (nonatomic, assign) BOOL currentOrdersLoading;
@property (nonatomic, assign) BOOL currentOrdersLoaded;
@property (nonatomic, assign) BOOL petProfilesLoading;
@property (nonatomic, assign) BOOL petProfilesLoaded;
@property (nonatomic, assign) BOOL isCurrentOrdersExpanded;
@property (nonatomic, assign) NSInteger currentOrdersRequestToken;
@property (nonatomic, assign) NSInteger buyAgainRequestToken;
@property (nonatomic, assign) NSInteger petProfilesRequestToken;
@property (nonatomic, strong, nullable) NSDate *lastCurrentOrdersRefreshAt;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> currentOrdersQueryListener;
@property (nonatomic, copy) NSString *currentOrdersListenerUserID;
@property (nonatomic, assign) BOOL isHomeScreenVisible;
@property (nonatomic, copy, nullable) NSString *lastObservedHomeOrderID;
@property (nonatomic, copy, nullable) NSString *lastObservedHomeOrderStatusKey;
@property (nonatomic, assign) BOOL didPrefetchHomeEntranceAnimations;
@property (nonatomic, assign) BOOL didPreparePremiumHomeEntrance;
@property (nonatomic, assign) BOOL didPrepareVisibleHomeEntranceContent;
@property (nonatomic, assign) BOOL didRunPremiumHomeEntranceAnimation;
@property (nonatomic, assign) BOOL isPremiumHomeEntranceAnimating;
@property (nonatomic, assign) BOOL didStartPremiumBackgroundGlowMotion;
@property (nonatomic, assign) CGSize lastPreparedHomeEntranceBoundsSize;
@property (nonatomic, assign) NSUInteger lastPreparedHomeEntranceItemCount;
@property (nonatomic, assign) NSUInteger lastPreparedHomeEntranceSectionCount;
@property (nonatomic, assign) NSInteger premiumCareAnimationCursor;
@property (nonatomic, copy, nullable) NSString *currentPremiumCareAnimationName;
@property (nonatomic, strong) NSArray<NSDictionary *> *homeConfigSections;
@property (nonatomic, copy) NSString *homeTitleViewMode; // @"location" (default) or @"search"
@property (nonatomic, assign) BOOL homePremiumCareVisible; // remote-config toggle for PPPetCareViewController
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> homeConfigListener;
@property (nonatomic, copy, nullable) NSString *lastAppliedHomeConfigOrderSignature;
@property (nonatomic, assign) BOOL shouldResetHomeScrollForConfigOrderChange;
// YES once the HomeConfig listener has reported (or the safety timeout has fired).
// Until this flips, applyBaseSnapshot renders an empty snapshot so we don't show
// the full default-section set just to relayout to the config-filtered set seconds
// later — the staged reveal is handled by the premium entrance animation instead.
@property (nonatomic, assign) BOOL didReceiveHomeConfig;
- (void)handleSeeAllForSection:(PPHomeSection)section;
- (void)openPremiumPetCare;
- (NSArray<NSString *> *)pp_premiumCareAnimationNames;
- (NSString *)pp_currentPremiumCareAnimationName;
- (void)pp_advancePremiumCareAnimationForAppearance;
- (void)pp_refreshVisiblePremiumCareAnimation;
- (void)pp_prefetchHomeEntranceAnimationsIfNeeded;
- (NSString *)heroGreetingText;
- (NSString *)heroBaseGreetingText;
- (NSString *)heroDisplayNameText;
- (NSString *)heroCountryText;
- (nullable NSString *)heroLocationActionTitle;
- (void)refreshHeroSectionAppearance;
- (void)refreshNearbyAdsForce:(BOOL)force reason:(NSString *)reason;
- (void)openHomeLocationPicker;
- (void)presentHomeLocationOptions;
- (void)openLocationSettings;
- (void)configureLocationStateMachine;
- (void)switchHomeLocationBackToAutomatic;
- (void)presentHomeLocationSheet;
- (BOOL)pp_canUseSimulatedNearbyLocation;
- (void)pp_applySimulatedNearbyLocationAndRefreshWithReason:(NSString *)reason;
- (NSArray<PPHomeQuickActionModel *> *)pp_homeQuickActions;
- (void)handleQuickActionSelection:(PPHomeQuickActionModel *)quickAction;
- (void)pp_openAddNewAdComposer;
- (void)pp_openAdoptFlow;
- (NSArray<NSDictionary *> *)pp_recentNearbyLocationRecords;
- (void)pp_recordRecentNearbyLocationCoordinate:(CLLocationCoordinate2D)coordinate
                                          title:(NSString *)title
                                         source:(NSString *)source;
- (void)pp_applyNearbyLocationRecord:(NSDictionary *)record;
- (NSDictionary<NSString *, NSString *> *)pp_suggestionReasonForModel:(id)model
                                                      latestEvent:(NSDictionary *)latestEvent
                                             orderedAccessoryIDs:(NSArray<NSString *> *)orderedAccessoryIDs;
- (NSString *)pp_browseReasonTextForEvent:(NSDictionary *)event;
- (void)pp_emitSelectionHaptic;
- (void)pp_emitSoftImpactHaptic;
- (void)pp_animateHomeCell:(UICollectionViewCell *)cell highlighted:(BOOL)highlighted;
- (BOOL)pp_isInitialHomeRevealSettled;
- (BOOL)pp_shouldReduceHomeMotion;
- (BOOL)pp_shouldDeferHomeLayoutStabilization;
- (NSArray<NSNumber *> *)pp_collectionSectionIndexesOrderedForEntrance;
- (NSArray<NSIndexPath *> *)pp_sortedVisibleIndexPathsForEntrance;
- (void)pp_preparePremiumHomeEntranceStateIfNeeded;
- (void)pp_prepareVisibleHomeEntranceContentIfNeeded;
- (void)pp_beginPremiumHomeEntranceIfNeeded;
- (void)pp_beginPremiumBackgroundGlowMotionIfNeeded;
- (void)pp_animateVisibleHomeEntranceContentIfNeeded;
- (void)pp_configureHomeEntranceInitialStateForCell:(UICollectionViewCell *)cell
                                        atIndexPath:(NSIndexPath *)indexPath
                                     lateAppearance:(BOOL)isLateAppearance;
- (void)pp_configureHomeEntranceInitialStateForSupplementaryView:(UICollectionReusableView *)supplementaryView
                                                            kind:(NSString *)kind
                                                     atIndexPath:(NSIndexPath *)indexPath
                                                  lateAppearance:(BOOL)isLateAppearance;
- (void)pp_animateHomeEntranceForCell:(UICollectionViewCell *)cell
                          atIndexPath:(NSIndexPath *)indexPath
                       initialOrdinal:(NSUInteger)initialOrdinal;
- (void)pp_animateHomeEntranceForSupplementaryView:(UICollectionReusableView *)supplementaryView
                                              kind:(NSString *)kind
                                       atIndexPath:(NSIndexPath *)indexPath
                                    initialOrdinal:(NSUInteger)initialOrdinal;
- (void)pp_animateHorizontalUniversalCellIfNeeded:(UICollectionViewCell *)cell
                                      atIndexPath:(NSIndexPath *)indexPath
                                          section:(PPHomeSection)section;
- (nullable NSString *)pp_homeEntranceKeyForIndexPath:(NSIndexPath *)indexPath
                                                 kind:(nullable NSString *)kind;
- (void)pp_refreshThemeSensitiveHomeContent;
- (void)pp_refreshHomeAppearanceChromeWithoutCollectionReload;
- (void)pp_refreshSuggestionsForAppearanceIfNeeded;
- (NSString *)pp_homeSuggestionsRefreshSignature;
- (NSString *)pp_homeDateSignaturePart:(nullable NSDate *)date;
- (NSString *)pp_homeOrderSignaturePart:(nullable PPOrder *)order;
- (NSString *)pp_homeCurrentOrdersSectionSignatureWithLoading:(BOOL)loading;
- (NSString *)pp_homeBuyAgainSignatureForEntries:(NSArray *)entries;
- (void)pp_refreshPetProfilesSectionForAppearanceIfNeeded;
- (NSString *)pp_homePetProfilesSignatureForProfiles:(NSArray<PPPetProfile *> *)profiles
                                           defaultPet:(nullable PPPetProfile *)defaultPet
                                              loading:(BOOL)loading;
- (void)handleThemePreferenceDidChange:(NSNotification *)notification;
- (void)pp_applyCurrentLanguageDirectionToHomeUI;
- (void)pp_forceHomeCollectionLayoutRefresh;
- (void)pp_scheduleInitialMainKindsLayoutRefresh;
- (void)refreshCurrentOrdersForce:(BOOL)force;
- (NSString *)pp_currentOrdersUserID;
- (void)pp_stopCurrentOrdersListener;
- (void)pp_startCurrentOrdersListenerForUserID:(NSString *)userID requestToken:(NSInteger)requestToken;
- (void)pp_applyCurrentOrdersSnapshot:(FIRQuerySnapshot *)snapshot requestToken:(NSInteger)requestToken;
- (BOOL)pp_homeStatusKey:(NSString *)statusKey matchesAnyKeywords:(NSArray<NSString *> *)keywords;
- (BOOL)pp_isFailureHomeOrderStatusKey:(NSString *)statusKey;
- (BOOL)pp_isActiveHomeOrder:(PPOrder *)order;
- (NSString *)pp_homeOrderStatusKey:(PPOrder *)order;
- (NSString *)pp_homeOrderStatusTitle:(PPOrder *)order;
- (NSString *)pp_homeOrderStatusHint:(PPOrder *)order;
- (UIColor *)pp_homeOrderStatusColor:(PPOrder *)order;
- (NSString *)pp_homeOrderStatusIconName:(PPOrder *)order;
- (double)pp_homeOrderProgress:(PPOrder *)order;
- (NSInteger)pp_homeOrderItemCount:(PPOrder *)order;
- (NSString *)pp_homeOrderAmountText:(PPOrder *)order;
- (NSString *)pp_homeOrderMetaText:(PPOrder *)order;
- (NSString *)pp_homeOrderFooterText:(PPOrder *)order;
- (NSString *)pp_homeOrderKickerTitle:(PPOrder *)order;
- (NSString *)pp_homeOrderImageURLFromItemData:(NSDictionary *)data;
- (NSArray<NSString *> *)pp_homeOrderPreviewImageURLs:(PPOrder *)order limit:(NSInteger)limit;
- (BOOL)pp_hasOtherRecentHomeOrdersWithinInterval:(NSTimeInterval)interval excludingOrder:(PPOrder *)order;
- (BOOL)pp_shouldHideCompletedLastHomeOrder:(PPOrder *)order;
- (NSString *)pp_completedLastHomeOrderSeenOrderIDDefaultsKey;
- (NSString *)pp_completedLastHomeOrderSeenSessionDefaultsKey;
- (void)pp_setCurrentOrdersExpanded:(BOOL)expanded animated:(BOOL)animated;
- (void)pp_scrollCurrentOrdersSectionIntoViewAnimated:(BOOL)animated;
- (NSString *)pp_homeRelativeDateString:(NSDate *)date;
- (NSString *)pp_homeShortDateString:(NSDate *)date;
- (nullable PPOrder *)pp_featuredHomeOrder;
- (NSArray<PPHomeItem *> *)pp_homeCurrentOrderItems;
- (NSArray<PPHomeItem *> *)pp_homeBuyAgainItems;
- (NSArray<NSNumber *> *)pp_orderedHomeSectionIdentifiers;
- (NSArray<NSDictionary *> *)pp_mergeHomeConfigSectionsWithCatalog:(NSArray<NSDictionary *> *)stored;
- (BOOL)pp_defaultVisibilityForHomeSection:(PPHomeSection)section;
- (void)pp_reloadHomeCollectionLayoutPreservingScrollOffset;
- (BOOL)pp_isHomeSectionVisibleInConfig:(PPHomeSection)section;
- (NSArray<NSDictionary *> *)pp_resolvedHomeConfigSectionsFromSanitizedSections:(NSArray<NSDictionary *> *)sanitized
                                                        legacyPremiumCareVisible:(BOOL)premiumCareVisible;
- (void)pp_cacheHomeConfigSections:(NSArray<NSDictionary *> *)sections
                     titleViewMode:(NSString *)titleViewMode
                premiumCareVisible:(BOOL)premiumCareVisible
               novaFloatingVisible:(BOOL)novaFloatingVisible
                     novaUseGenkit:(BOOL)novaUseGenkit;
- (BOOL)pp_applyCachedHomeConfigIfAvailable;
- (NSString *)pp_homeConfigOrderSignatureForSectionIdentifiers:(NSArray<NSNumber *> *)sectionIdentifiers;
- (void)pp_fetchHomeConfigFromServerOnceWithDocumentReference:(FIRDocumentReference *)docRef;
- (void)pp_applyHomeConfigSnapshot:(FIRDocumentSnapshot *)snapshot source:(NSString *)source;
- (NSArray<PPHomeItem *> *)pp_buildItemsForSection:(PPHomeSection)section;
- (NSArray<PPHomeBuyAgainSnapshotItem *> *)pp_buyAgainSnapshotItemsFromOrders:(NSArray<PPOrder *> *)orders
                                                                        limit:(NSInteger)limit;
- (void)pp_refreshPetProfilesSection;
- (nullable PPPetProfile *)pp_homeEntryPetProfile;
- (void)pp_openPetProfilesEntryPoint;
- (NSString *)pp_homeOrderItemIdentifier:(id)rawItem;
- (NSArray<NSString *> *)pp_buyAgainAccessoryIDsFromOrders:(NSArray<PPOrder *> *)orders
                                                     limit:(NSInteger)limit;
- (NSArray *)pp_orderedBuyAgainEntriesFromResolvedByID:(NSDictionary<NSString *, PetAccessory *> *)resolvedByID
                                         snapshotItems:(NSArray<PPHomeBuyAgainSnapshotItem *> *)snapshotItems
                                                 limit:(NSInteger)limit;
- (void)pp_refreshBuyAgainSection;
- (void)pp_clearUnavailableBuyAgainCoverFromCell:(UICollectionViewCell *)cell;
- (void)pp_applyUnavailableBuyAgainCoverToCell:(UICollectionViewCell *)cell
                                  snapshotItem:(PPHomeBuyAgainSnapshotItem *)snapshotItem;
- (void)pp_openSimilarItemsForUnavailableBuyAgainItem:(PPHomeBuyAgainSnapshotItem *)snapshotItem;
- (void)pp_centerNearbySectionIfPossible;
- (void)pp_openOrderDetailsForOrder:(PPOrder *)order;
- (NSString *)pp_stableKeyForHomeItem:(PPHomeItem *)item
                               section:(PPHomeSection)section
                                 index:(NSInteger)index;
- (NSArray<PPHomeItem *> *)pp_homeItemsByReusingExistingItems:(NSArray<PPHomeItem *> *)existingItems
                                                     newItems:(NSArray<PPHomeItem *> *)newItems
                                                      section:(PPHomeSection)section;
- (void)pp_reconfigureHomeItems:(NSArray<PPHomeItem *> *)items
                      inSnapshot:(NSDiffableDataSourceSnapshot *)snapshot;

- (void)refreshNavigationRightItemsForCartCount:(NSUInteger)count;
@property (nonatomic, assign) BOOL isMainKindsExpanded;
@property (nonatomic, assign) BOOL didAutoScrollSuggestions;
@property (nonatomic, assign) BOOL didAutoScrollNearbyServices;
@property (nonatomic, assign) BOOL didFillSuggestionsOnce;
@property (nonatomic, assign) BOOL didApplyInitialHomeAppearanceRefresh;
@property (nonatomic, copy, nullable) NSString *lastHomeSuggestionsAppearanceSignature;
@property (nonatomic, copy, nullable) NSString *lastCurrentOrdersSectionSignature;
@property (nonatomic, copy, nullable) NSString *lastBuyAgainSectionSignature;
@property (nonatomic, copy, nullable) NSString *lastPetProfilesSectionSignature;
@property (nonatomic, copy, nullable) NSString *lastPetProfilesUserID;
@property (nonatomic, assign) BOOL shouldRefreshPetProfilesOnNextAppearance;
@property (nonatomic, strong) UIView *profileCard;
@property (nonatomic, strong, nullable) UIBarButtonItem *homeProfileItem;
@property (nonatomic, strong, nullable) UIBarButtonItem *homeCartItem;
@property (nonatomic, strong, nullable) UIButton *homeCartButton;
@property (nonatomic, strong) UIButton *novaFloatingButton;
@property (nonatomic, strong, nullable) LOTAnimationView *novaFloatingLottieView;
@property (nonatomic, strong, nullable) UIView *novaFloatingHaloView;
@property (nonatomic, assign) BOOL novaFloatingButtonScrollCompressed;
@property (nonatomic, assign) NSUInteger novaFloatingScrollMotionGeneration;
@property (nonatomic, strong, nullable) UIBarButtonItem *homeOptionsItem;
@property (nonatomic, strong, nullable) PPHomeSmartSearchTitleView *homeSmartSearchView;
@property (nonatomic, strong, nullable) NSLayoutConstraint *homeSmartSearchWidthConstraint;
@property (nonatomic, strong, nullable) NSTimer *homeSmartSearchTimer;
@property (nonatomic, copy) NSArray<NSString *> *homeSmartSearchPlaceholders;
@property (nonatomic, assign) NSInteger homeSmartSearchPlaceholderIndex;
@property (nonatomic, strong, nullable) PPHomeLocationTitleView *homeLocationTitleView;
@property (nonatomic, strong, nullable) NSLayoutConstraint *homeLocationTitleWidthConstraint;
@property (nonatomic, assign) BOOL didRegisterTimeChangeObserver;
@property (nonatomic, strong) NSCache<NSString *, UIImage *> *blurHashCache;
@property (nonatomic, strong) dispatch_queue_t blurHashQueue;
@property (nonatomic, copy) NSString *lastHeroRenderSignature;
@property (nonatomic, assign) BOOL heroRefreshScheduled;
@property (nonatomic, assign) BOOL didStabilizeInitialHomeLayout;
@property (nonatomic, assign) BOOL didApplyInitialBaseSnapshot;
@property (nonatomic, assign) BOOL isPresentingHomeLocationSheet;
@property (nonatomic, assign) CGSize lastHomeLayoutBoundsSize;
@property (nonatomic, assign) UIEdgeInsets lastHomeLayoutAdjustedInsets;
- (void)pp_prefetchImagesAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;
- (void)pp_prefetchTopImagesWithLimit:(NSInteger)limit;
- (void)pp_asyncBlurHashImageForHash:(NSString *)hash
                                size:(CGSize)size
                          completion:(void (^)(UIImage * _Nullable image))completion;
- (void)handleUserProfileSyncNotification:(NSNotification *)notification;
- (void)handleUserAccessUpdateNotification:(NSNotification *)notification;
- (void)pp_handlePromoCardTap:(PPHomePromoCarouselCard *)card interaction:(NSString *)interaction;
- (void)pp_configureBannerCell:(PPBannerCollectionCell *)cell
                       forItem:(PPHomeItem *)item;
- (void)pp_handleCarouselTapAction:(PPBannerOnTapAction)action
                             value:(NSString *)value
                       defaultKind:(NSInteger)fallbackMainKindID
                           context:(NSString *)context;
- (nullable MainBannerModel *)pp_homeTopCarouselBannerGroup;
- (NSArray<PPHomePromoCarouselCard *> *)pp_homePromoFallbackCards;
- (NSArray<PPHomePromoCarouselCard *> *)pp_promoCardsFromLegacyBannerGroup:(MainBannerModel *)group;
- (void)pp_applyOrderDetailsBackgroundAppearance;
- (void)pp_installPremiumBackgroundGlowViewsIfNeeded;
- (void)pp_layoutPremiumBackgroundGlowViews;
- (void)pp_updatePremiumBackgroundGlowAppearance;
- (CGFloat)preferredNavigationCenterViewWidth;
- (CGFloat)pp_widthForBarButtonItem:(UIBarButtonItem *)item fallback:(CGFloat)fallback;
- (CGFloat)pp_preferredNavigationSearchWidth;
- (void)pp_updateHomeSmartSearchTitleViewWidth;
- (CGFloat)pp_preferredNavigationLocationTitleWidth;
- (void)pp_updateHomeLocationTitleViewWidth;
- (void)pp_refreshHomeLocationTitleViewAnimated:(BOOL)animated;
- (UIColor *)pp_homeLocationTitleStatusColor;
- (BOOL)pp_homeLocationTitleShowsLoading;
- (NSString *)pp_homeLocationTitleAccessibilityHint;
- (void)pp_detachHomeLocationTitleViewIfNeeded;
- (BOOL)pp_canOwnHomeNavigationChrome;
- (void)pp_detachHomeSmartSearchTitleViewIfNeeded;
- (UIView *)pp_navigationLocationTitleView;
- (UIView *)pp_navigationSmartSearchTitleView;
- (void)pp_openSmartSearch;
- (NSArray<NSString *> *)pp_resolvedHomeSmartSearchPlaceholders;
- (NSString *)pp_currentHomeSmartSearchPlaceholder;
- (void)pp_updateHomeSmartSearchPlaceholderAnimated:(BOOL)animated;
- (void)pp_startHomeSmartSearchTimerIfNeeded;
- (void)pp_stopHomeSmartSearchTimer;
- (void)pp_scheduleSmartSearchTimerWithInterval:(NSTimeInterval)interval;
- (void)pp_advanceHomeSmartSearchPlaceholder;
- (void)pp_stabilizeHomeCollectionLayoutIfNeeded;
- (void)pp_refreshVisibleHomeCardsForSections:(NSArray<NSNumber *> *)sections;
- (void)pp_refreshInitialHomeRevealDependentContent;

@end


@implementation PPHomeViewController

- (NSArray<NSString *> *)pp_premiumCareAnimationNames
{
    static NSArray<NSString *> *names = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        names = @[@"Health1"]; // @"pet-care2", @"pet-care3", @"pet-care4", @"pet-care5"
    });
    return names;
}

- (NSString *)pp_currentPremiumCareAnimationName
{
    NSString *name = PPSafeString(self.currentPremiumCareAnimationName);
    return name.length > 0 ? name : @"Health1";
}

- (void)pp_advancePremiumCareAnimationForAppearance
{
    NSArray<NSString *> *names = [self pp_premiumCareAnimationNames];
    if (names.count == 0) {
        self.currentPremiumCareAnimationName = @"Health1";
        return;
    }

    NSInteger index = self.premiumCareAnimationCursor % (NSInteger)names.count;
    if (index < 0) {
        index = 0;
    }

    self.currentPremiumCareAnimationName = names[(NSUInteger)index];
    self.premiumCareAnimationCursor = (index + 1) % (NSInteger)names.count;
    [self pp_refreshVisiblePremiumCareAnimation];
}

- (void)pp_refreshVisiblePremiumCareAnimation
{
    if (![self pp_isInitialHomeRevealSettled]) {
        return;
    }

    NSInteger sectionIndex = [self sectionIndexForType:PPHomeSectionPremiumCare];
    if (sectionIndex == NSNotFound) {
       // sectionIndex = [self sectionIndexForType:PPHomeSectionPremiumCare];
    }
    if (sectionIndex == NSNotFound || !self.collectionView) {
        return;
    }

    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:sectionIndex];
    UICollectionViewCell *rawCell = [self.collectionView cellForItemAtIndexPath:indexPath];
    if (![rawCell isKindOfClass:PPHomePremiumCareCell.class]) {
        return;
    }

    PPHomePremiumCareCell *cell = (PPHomePremiumCareCell *)rawCell;
    [cell configureWithAnimationName:[self pp_currentPremiumCareAnimationName]];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [cell setNeedsLayout];
    [cell.contentView setNeedsLayout];
    [cell.contentView layoutIfNeeded];
    [cell layoutIfNeeded];
    [CATransaction commit];
}

- (void)pp_prefetchHomeEntranceAnimationsIfNeeded
{
    if (self.didPrefetchHomeEntranceAnimations) {
        return;
    }
    self.didPrefetchHomeEntranceAnimations = YES;

    NSMutableOrderedSet<NSString *> *storagePaths = [NSMutableOrderedSet orderedSet];
    for (NSString *animationName in [self pp_premiumCareAnimationNames]) {
        NSString *safeName = PPSafeString(animationName);
        if (safeName.length == 0) {
            continue;
        }
        [storagePaths addObject:[NSString stringWithFormat:@"LottieAnimations/%@.json", safeName]];
    }

    for (NSString *heroAnimationName in @[
        @"Woman playing with a dog",
        @"Boy Giving Food To Bird",
        @"Man playing with a dog",
        @"Womanlovingpetcats",
        @"evening chair cat and girl",
        @"man playing with cat during free time"
    ]) {
        NSString *safeName = PPSafeString(heroAnimationName);
        if (safeName.length == 0) {
            continue;
        }
        [storagePaths addObject:[NSString stringWithFormat:@"LottieAnimations/%@.json", safeName]];
    }

    // Floating Nova orb — prefetch so the button animates the moment Home appears.
    [storagePaths addObject:@"LottieAnimations/nova.json"];

    for (NSString *storagePath in storagePaths) {
        [AppClasses fetchLottieJSONFromFirebasePath:storagePath
                                         completion:^(__unused NSDictionary *jsonDict,
                                                      __unused NSError *error) {
        }];
    }
}


// Scroll Suggestions section to item index 2 after data is loaded
- (void)autoScrollIndextoIndex:(NSInteger)targetItem inSection:(PPHomeSection)section
{
    NSInteger sectionIndex = [self sectionIndexForType:section];
    if (sectionIndex == NSNotFound) return;


    if ([self.collectionView numberOfItemsInSection:sectionIndex] <= targetItem) {
        return;
    }

    NSIndexPath *indexPath =
        [NSIndexPath indexPathForItem:targetItem inSection:sectionIndex];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self.collectionView scrollToItemAtIndexPath:indexPath
                                    atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                            animated:YES];
    });
}

- (void)pp_centerNearbySectionIfPossible
{
    if (self.didSelectInitialNearby || self.isPremiumHomeEntranceAnimating) {
        return;
    }

    NSInteger sectionIndex = [self sectionIndexForType:PPHomeSectionAdsNearBy];
    if (sectionIndex == NSNotFound || !self.collectionView) {
        return;
    }

    NSInteger itemCount = [self.collectionView numberOfItemsInSection:sectionIndex];
    if (itemCount <= 1) {
        return;
    }

    NSInteger targetItem = MIN(1, itemCount - 1);
    NSIndexPath *centerIndexPath = [NSIndexPath indexPathForItem:targetItem inSection:sectionIndex];

    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.didSelectInitialNearby || self.isPremiumHomeEntranceAnimating) {
            return;
        }
        [self.collectionView layoutIfNeeded];
        if ([self.collectionView numberOfItemsInSection:sectionIndex] <= targetItem) {
            return;
        }
        self.didSelectInitialNearby = YES;
        [self.collectionView scrollToItemAtIndexPath:centerIndexPath
                                    atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                            animated:NO];
    });
}

#pragma mark - Life Cycle
- (void)didTapOn_BannerViewModel:(PPBannerViewModel *)pannerViewModel
{
    if (!pannerViewModel) return;
    [self pp_handleCarouselTapAction:pannerViewModel.onTapAction
                               value:PPSafeString(pannerViewModel.onTapValue)
                         defaultKind:0
                             context:@"legacy-banner-card"];
}

- (void)pp_handlePromoCardTap:(PPHomePromoCarouselCard *)card
                  interaction:(NSString *)interaction
{
    if (!card) return;

    if ([interaction isEqualToString:@"primary"]) {
        [self pp_handleCarouselTapAction:card.primaryButtonTapAction
                                   value:PPSafeString(card.primaryButtonTapValue)
                             defaultKind:0
                                 context:@"promo-primary-button"];
        return;
    }

    if ([interaction isEqualToString:@"secondary"]) {
        [self pp_handleCarouselTapAction:card.secondaryButtonTapAction
                                   value:PPSafeString(card.secondaryButtonTapValue)
                             defaultKind:0
                                 context:@"promo-secondary-button"];
        return;
    }

    [self pp_handleCarouselTapAction:card.cardTapAction
                               value:PPSafeString(card.cardTapValue)
                         defaultKind:0
                             context:@"promo-card"];
}

- (void)pp_handleCarouselTapAction:(PPBannerOnTapAction)action
                             value:(NSString *)value
                       defaultKind:(NSInteger)fallbackMainKindID
                           context:(NSString *)context
{
    NSString *safeValue = PPSafeString(value);
    NSLog(@"[Home][CarouselTap] context=%@ action=%ld value=%@",
          context ?: @"(nil)", (long)action, safeValue);

    switch (action) {
        case PPBannerOnTapViewAccessory:
        case PPBannerOnTapViewAd: {
            NSInteger mainKindID = safeValue.integerValue;
            if (mainKindID <= 0) {
                mainKindID = fallbackMainKindID;
            }
            MainKindsModel *kind = (mainKindID > 0) ? [self resolveMainKindWithID:mainKindID] : nil;
            PPDeepLinkTarget target = (action == PPBannerOnTapViewAccessory)
                ? PPDeepLinkTargetAccessories
                : PPDeepLinkTargetAds;
            PPInputSource source = (action == PPBannerOnTapViewAccessory)
                ? PPInputSourceHomeAccessoriesSection
                : PPInputSourceHomeNearBySection;
            [self handleDeepLinkWithTarget:target mainKind:kind source:source];
            break;
        }

        case PPBannerOnTapOpenUrl: {
            NSString *urlString = safeValue;
            if (urlString.length == 0) return;
            if (![urlString containsString:@"://"]) {
                urlString = [NSString stringWithFormat:@"https://%@", urlString];
            }
            NSURL *url = [NSURL URLWithString:urlString];
            if (!url) return;

            if (@available(iOS 9.0, *)) {
                SFSafariViewController *safari = [[SFSafariViewController alloc] initWithURL:url];
                [PPFunc presentSheetFrom:self sheetVC:safari detentStyle:PPSheetDetentStyle80];
            } else {
                [[UIApplication sharedApplication] openURL:url];
            }
            break;
        }

        case PPBannerOnTapCallPhoneNumber:
            [AppClasses callPhoneNumber:safeValue fromViewController:self];
            break;

        case PPBannerOnTapWhatsApp:
            [AppClasses startWhatsAppWith:safeValue fromViewController:self];
            break;

        default:
            break;
    }
}

- (NSArray<PPHomePromoCarouselCard *> *)pp_homePromoFallbackCards
{
    PPHomePromoCarouselCard *card = [PPHomePromoCarouselCard new];
    card.cardID = @"home-promo-fallback-service";
    card.visible = YES;
    card.sortOrder = 0;
    NSString *badgeTitle = kLang(@"Popular") ?: @"Popular";
    NSString *title = kLang(@"Hire a Service Man") ?: @"Hire a Service Man";
    NSString *subtitle = kLang(@"Need help with setup, repairs & installation?") ?: @"Need help with setup, repairs & installation?";
    NSString *bookNow = kLang(@"Book Now") ?: @"Book Now";
    card.badgeTextEn = badgeTitle;
    card.badgeTextAr = badgeTitle;
    card.titleTextEn = title;
    card.titleTextAr = title;
    card.subtitleTextEn = subtitle;
    card.subtitleTextAr = subtitle;
    card.primaryButtonTitleEn = bookNow;
    card.primaryButtonTitleAr = bookNow;
    card.hidePrimaryButton = NO;
    card.hideSecondaryButton = YES;
    card.startColorHex = @"#F5A63A";
    card.endColorHex = @"#EF8628";
    card.accentColorHex = @"#FFC86D";
    card.textStyle = PPBannerTextStyleWhite;
    card.cardTapAction = PPBannerOnTapViewAccessory;
    card.cardTapValue = @"";
    card.primaryButtonTapAction = PPBannerOnTapViewAccessory;
    card.primaryButtonTapValue = @"";
    card.autoScrollInterval = 4.8;
    return @[card];
}

- (NSArray<PPHomePromoCarouselCard *> *)pp_promoCardsFromLegacyBannerGroup:(MainBannerModel *)group
{
    if (!group || group.childBanners.count == 0) return @[];

    NSMutableArray<PPHomePromoCarouselCard *> *cards = [NSMutableArray arrayWithCapacity:group.childBanners.count];
    NSInteger idx = 0;
    for (PPBannerViewModel *vm in group.childBanners) {
        if (![vm isKindOfClass:PPBannerViewModel.class]) continue;

        PPHomePromoCarouselCard *card = [PPHomePromoCarouselCard new];
        card.cardID = PPSafeString(vm.bannerID).length > 0 ? PPSafeString(vm.bannerID) : [NSString stringWithFormat:@"legacy-banner-%ld", (long)idx];
        card.visible = YES;
        card.sortOrder = idx;

        NSString *titleEn = PPSafeString(vm.titleTextEn);
        NSString *titleAr = PPSafeString(vm.titleTextAr);
        NSString *descEn = PPSafeString(vm.descTextEn);
        NSString *descAr = PPSafeString(vm.descTextAr);

        card.titleTextEn = titleEn.length > 0 ? titleEn : [vm localizedTitleText];
        card.titleTextAr = titleAr;
        card.subtitleTextEn = descEn.length > 0 ? descEn : [vm localizedDescText];
        card.subtitleTextAr = descAr;

        NSString *badge = PPSafeString(vm.postDateText);
        if (badge.length == 0) badge = @"Popular";
        card.badgeTextEn = badge;
        card.badgeTextAr = badge;

        switch (vm.onTapAction) {
            case PPBannerOnTapViewAccessory:
                card.primaryButtonTitleEn = kLang(@"Shop Now") ?: @"Shop Now";
                card.primaryButtonTitleAr = card.primaryButtonTitleEn;
                break;
            case PPBannerOnTapViewAd:
                card.primaryButtonTitleEn = kLang(@"View Ads") ?: @"View Ads";
                card.primaryButtonTitleAr = card.primaryButtonTitleEn;
                break;
            case PPBannerOnTapCallPhoneNumber:
                card.primaryButtonTitleEn = kLang(@"Call") ?: @"Call";
                card.primaryButtonTitleAr = card.primaryButtonTitleEn;
                break;
            case PPBannerOnTapWhatsApp:
                card.primaryButtonTitleEn = kLang(@"WhatsApp") ?: @"WhatsApp";
                card.primaryButtonTitleAr = card.primaryButtonTitleEn;
                break;
            case PPBannerOnTapOpenUrl:
            default:
                card.primaryButtonTitleEn = kLang(@"Open") ?: @"Open";
                card.primaryButtonTitleAr = card.primaryButtonTitleEn;
                break;
        }

        card.hidePrimaryButton = NO;
        card.hideSecondaryButton = YES;
        card.cardTapAction = vm.onTapAction;
        card.cardTapValue = PPSafeString(vm.onTapValue);
        card.primaryButtonTapAction = vm.onTapAction;
        card.primaryButtonTapValue = PPSafeString(vm.onTapValue);
        card.characterImageURL = vm.sampleImageURL;
        card.backgroundImageURL = vm.backgroundImageURL;
        card.autoScrollInterval = 5.0;
        card.textStyle = (vm.textStyle == PPBannerTextStyleBlack) ? PPBannerTextStyleBlack : PPBannerTextStyleWhite;

        PPHomeApplyPromoGradientPalette(card, vm.backgroundGradientColors, idx);

        [cards addObject:card];
        idx += 1;
    }

    return cards.copy;
}
/// Canonical fallback order — mirrors Console `HomeControlPanel` / `IOS_SECTION_CATALOG`.
- (NSArray<NSNumber *> *)pp_defaultHomeSectionCatalogOrder {
    return @[
        @(PPHomeSectionHero),
        @(PPHomeSectionPremiumSearch),
        @(PPHomeSectionPremiumCare),
        @(PPHomeSectionQuickActions),
        @(PPHomeSectionMainKinds),
        @(PPHomeSectionCurrentOrders),
        @(PPHomeSectionAccessories),
        @(PPHomeSectionSuggestions),
        @(PPHomeSectionCarousel),
        @(PPHomeSectionLastFood),
        @(PPHomeSectionAdsNearBy),
        @(PPHomeSectionPetProfile),
        @(PPHomeSectionNearbyServices),
        @(PPHomeSectionAdopt),
        @(PPHomeSectionBuyAgain),
        @(PPHomeSectionServices),
    ];
}

static NSInteger PPHomeSectionIDFromConfigValue(id value)
{
    if ([value isKindOfClass:NSNumber.class]) {
        return [(NSNumber *)value integerValue];
    }
    if ([value isKindOfClass:NSString.class]) {
        NSString *raw = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (raw.length == 0) {
            return NSNotFound;
        }
        NSInteger numeric = raw.integerValue;
        if ([raw isEqualToString:[@(numeric) stringValue]]) {
            return numeric;
        }
        static NSDictionary<NSString *, NSNumber *> *typeNameMap;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            typeNameMap = @{
                @"PPHomeSectionHero" : @(PPHomeSectionHero),
                @"PPHomeSectionQuickActions" : @(PPHomeSectionQuickActions),
                @"PPHomeSectionCurrentOrders" : @(PPHomeSectionCurrentOrders),
                @"PPHomeSectionServices" : @(PPHomeSectionServices),
                @"PPHomeSectionCarousel" : @(PPHomeSectionCarousel),
                @"PPHomeSectionMainKinds" : @(PPHomeSectionMainKinds),
                @"PPHomeSectionSuggestions" : @(PPHomeSectionSuggestions),
                @"PPHomeSectionAccessories" : @(PPHomeSectionAccessories),
                @"PPHomeSectionPetProfile" : @(PPHomeSectionPetProfile),
                @"PPHomeSectionPremiumCare" : @(PPHomeSectionPremiumCare),
                @"PPHomeSectionLastFood" : @(PPHomeSectionLastFood),
                @"PPHomeSectionNearbyServices" : @(PPHomeSectionNearbyServices),
                @"PPHomeSectionAdsNearBy" : @(PPHomeSectionAdsNearBy),
                @"PPHomeSectionAdopt" : @(PPHomeSectionAdopt),
                @"PPHomeSectionBuyAgain" : @(PPHomeSectionBuyAgain),
                @"PPHomeSectionPremiumSearch" : @(PPHomeSectionPremiumSearch),
            };
        });
        NSNumber *mapped = typeNameMap[raw];
        if (mapped) {
            return mapped.integerValue;
        }
    }
    return NSNotFound;
}

- (BOOL)pp_isHomeSectionVisibleInConfig:(PPHomeSection)section {
    if (self.homeConfigSections.count == 0) {
        switch (section) {
            case PPHomeSectionServices:
                return [self pp_defaultVisibilityForHomeSection:section];
            case PPHomeSectionPremiumCare:
                return self.homePremiumCareVisible;
            default:
                return YES;
        }
    }

    for (NSDictionary *sectionCfg in self.homeConfigSections) {
        NSInteger sectionID = PPHomeSectionIDFromConfigValue(sectionCfg[@"id"]);
        if (sectionID != section) {
            continue;
        }
        BOOL visible = [sectionCfg[@"visible"] boolValue];
        if (section == PPHomeSectionPremiumCare) {
            return visible && self.homePremiumCareVisible;
        }
        return visible;
    }

    return NO;
}

- (BOOL)pp_shouldRenderHomeSection:(PPHomeSection)section {
    if (![self pp_isHomeSectionVisibleInConfig:section]) {
        return NO;
    }

    return YES;
}

/// Appends catalog sections missing from stored Console config (preserves operator order).
- (NSArray<NSDictionary *> *)pp_mergeHomeConfigSectionsWithCatalog:(NSArray<NSDictionary *> *)stored {
    NSArray<NSNumber *> *catalogOrder = [self pp_defaultHomeSectionCatalogOrder];
    if (stored.count == 0) {
        NSMutableArray<NSDictionary *> *seeded = [NSMutableArray arrayWithCapacity:catalogOrder.count];
        for (NSNumber *sectionID in catalogOrder) {
            [seeded addObject:@{
                @"id" : sectionID,
                @"visible" : @([self pp_defaultVisibilityForHomeSection:(PPHomeSection)sectionID.integerValue]),
                @"type" : @""
            }];
        }
        return seeded.copy;
    }

    NSMutableSet<NSNumber *> *presentIDs = [NSMutableSet set];
    for (NSDictionary *row in stored) {
        NSInteger sectionID = PPHomeSectionIDFromConfigValue(row[@"id"]);
        if (sectionID != NSNotFound) {
            [presentIDs addObject:@(sectionID)];
        }
    }

    NSMutableArray<NSDictionary *> *merged = [stored mutableCopy];
    for (NSNumber *sectionID in catalogOrder) {
        if ([presentIDs containsObject:sectionID]) {
            continue;
        }
        [merged addObject:@{
            @"id" : sectionID,
            @"visible" : @([self pp_defaultVisibilityForHomeSection:(PPHomeSection)sectionID.integerValue]),
            @"type" : @""
        }];
    }
    return merged.copy;
}

- (BOOL)pp_defaultVisibilityForHomeSection:(PPHomeSection)section {
    switch (section) {
        case PPHomeSectionServices:
            return NO;
        default:
            return YES;
    }
}

- (NSArray<NSDictionary *> *)pp_resolvedHomeConfigSectionsFromSanitizedSections:(NSArray<NSDictionary *> *)sanitized
                                                        legacyPremiumCareVisible:(BOOL)premiumCareVisible
{
    BOOL hasPremiumCareSection =
        [sanitized indexOfObjectPassingTest:^BOOL(NSDictionary *row, NSUInteger idx, BOOL *stop) {
            (void)idx;
            (void)stop;
            return PPHomeSectionIDFromConfigValue(row[@"id"]) == PPHomeSectionPremiumCare;
        }] != NSNotFound;

    NSArray<NSDictionary *> *merged = [self pp_mergeHomeConfigSectionsWithCatalog:sanitized];
    if (hasPremiumCareSection) {
        return merged;
    }

    NSMutableArray<NSDictionary *> *adjusted = [merged mutableCopy];
    for (NSUInteger idx = 0; idx < adjusted.count; idx++) {
        NSDictionary *row = adjusted[idx];
        if (PPHomeSectionIDFromConfigValue(row[@"id"]) != PPHomeSectionPremiumCare) {
            continue;
        }
        NSMutableDictionary *mutableRow = [row mutableCopy];
        mutableRow[@"visible"] = @(premiumCareVisible);
        adjusted[idx] = mutableRow;
        break;
    }
    return adjusted.copy;
}

- (void)pp_cacheHomeConfigSections:(NSArray<NSDictionary *> *)sections
                     titleViewMode:(NSString *)titleViewMode
                premiumCareVisible:(BOOL)premiumCareVisible
               novaFloatingVisible:(BOOL)novaFloatingVisible
                     novaUseGenkit:(BOOL)novaUseGenkit
{
    if (sections.count == 0) {
        return;
    }

    NSDictionary *payload = @{
        PPHomeConfigCacheSectionsKey : sections,
        PPHomeConfigCacheTitleModeKey : titleViewMode ?: @"location",
        PPHomeConfigCachePremiumCareVisibleKey : @(premiumCareVisible),
        PPHomeConfigCacheNovaFloatingVisibleKey : @(novaFloatingVisible),
        PPHomeConfigCacheNovaUseGenkitKey : @(novaUseGenkit)
    };
    [[NSUserDefaults standardUserDefaults] setObject:payload forKey:PPHomeConfigCacheKey];
    
    // We also set it individually so other view controllers can read it easily
    [[NSUserDefaults standardUserDefaults] setBool:novaUseGenkit forKey:@"pp_nova_use_genkit"];
}

- (BOOL)pp_applyCachedHomeConfigIfAvailable
{
    NSDictionary *payload = [[NSUserDefaults standardUserDefaults] dictionaryForKey:PPHomeConfigCacheKey];
    if (![payload isKindOfClass:NSDictionary.class]) {
        return NO;
    }

    NSArray<NSDictionary *> *sanitized = [self pp_sanitizedHomeConfigSections:payload[PPHomeConfigCacheSectionsKey]];
    if (sanitized.count == 0) {
        return NO;
    }

    BOOL premiumCareVisible = YES;
    id cachedPremiumCare = payload[PPHomeConfigCachePremiumCareVisibleKey];
    if ([cachedPremiumCare respondsToSelector:@selector(boolValue)]) {
        premiumCareVisible = [cachedPremiumCare boolValue];
    }

    BOOL novaVisible = YES;
    id cachedNovaVisible = payload[PPHomeConfigCacheNovaFloatingVisibleKey];
    if ([cachedNovaVisible respondsToSelector:@selector(boolValue)]) {
        novaVisible = [cachedNovaVisible boolValue];
    }

    NSString *cachedMode = payload[PPHomeConfigCacheTitleModeKey];
    NSString *resolvedTitleViewMode = @"location";
    if ([cachedMode isKindOfClass:NSString.class] &&
        ([cachedMode isEqualToString:@"location"] || [cachedMode isEqualToString:@"search"])) {
        resolvedTitleViewMode = cachedMode;
    }

    self.homePremiumCareVisible = premiumCareVisible;
    self.homeTitleViewMode = resolvedTitleViewMode;
    self.homeConfigSections = [self pp_resolvedHomeConfigSectionsFromSanitizedSections:sanitized
                                                               legacyPremiumCareVisible:premiumCareVisible];
    self.didReceiveHomeConfig = YES;
    self.lastAppliedHomeConfigOrderSignature =
        [self pp_homeConfigOrderSignatureForSectionIdentifiers:[self pp_orderedHomeSectionIdentifiers]];

    [[NSNotificationCenter defaultCenter] postNotificationName:PPNovaFloatingVisibilityDidChangeNotification
                                                        object:self
                                                      userInfo:@{ PPNovaFloatingVisibilityValueKey : @(novaVisible) }];

    NSLog(@"[HomeConfig] Applied cached Console section order: %@",
          self.lastAppliedHomeConfigOrderSignature ?: @"");
    return YES;
}

- (NSString *)pp_homeConfigOrderSignatureForSectionIdentifiers:(NSArray<NSNumber *> *)sectionIdentifiers
{
    if (sectionIdentifiers.count == 0) {
        return @"";
    }

    NSMutableArray<NSString *> *parts = [NSMutableArray arrayWithCapacity:sectionIdentifiers.count];
    for (NSNumber *sectionID in sectionIdentifiers) {
        if (![sectionID isKindOfClass:NSNumber.class]) {
            continue;
        }
        [parts addObject:sectionID.stringValue];
    }
    return [parts componentsJoinedByString:@"|"];
}

- (void)pp_reloadHomeCollectionLayoutPreservingScrollOffset {
    if (!self.isViewLoaded || !self.collectionView || !self.layoutManager) {
        return;
    }

    CGPoint preservedOffset = self.collectionView.contentOffset;
    UICollectionViewCompositionalLayout *layout = [self.layoutManager buildLayout];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [UIView performWithoutAnimation:^{
        [self.collectionView setCollectionViewLayout:layout animated:NO];
        [self.collectionView.collectionViewLayout invalidateLayout];
        [self.collectionView setNeedsLayout];
        [self.collectionView layoutIfNeeded];

        CGFloat minOffsetY = -self.collectionView.adjustedContentInset.top;
        CGFloat maxOffsetY = MAX(minOffsetY,
                                 self.collectionView.contentSize.height -
                                 CGRectGetHeight(self.collectionView.bounds) +
                                 self.collectionView.adjustedContentInset.bottom);
        CGFloat targetOffsetY = MIN(MAX(preservedOffset.y, minOffsetY), maxOffsetY);
        self.collectionView.contentOffset = CGPointMake(preservedOffset.x, targetOffsetY);
    }];
    [CATransaction commit];

    if (self.shouldResetHomeScrollForConfigOrderChange) {
        self.shouldResetHomeScrollForConfigOrderChange = NO;
        CGFloat topOffsetY = -self.collectionView.adjustedContentInset.top;
        [self.collectionView setContentOffset:CGPointMake(0.0, topOffsetY) animated:NO];
    }
}

/// Live section order from `AppConfigCol/HomeConfig.sections` (Console Home Control).
- (NSArray<NSNumber *> *)pp_orderedHomeSectionIdentifiers {
    NSMutableArray<NSNumber *> *sections = [NSMutableArray array];

    if (self.homeConfigSections.count > 0) {
        for (NSDictionary *sectionCfg in self.homeConfigSections) {
            NSInteger sectionID = PPHomeSectionIDFromConfigValue(sectionCfg[@"id"]);
            if (sectionID == NSNotFound) {
                continue;
            }
            if (![self pp_shouldRenderHomeSection:(PPHomeSection)sectionID]) {
                continue;
            }
            [sections addObject:@(sectionID)];
        }
        return sections.copy;
    }

    for (NSNumber *sectionID in [self pp_defaultHomeSectionCatalogOrder]) {
        if ([self pp_shouldRenderHomeSection:(PPHomeSection)sectionID.integerValue]) {
            [sections addObject:sectionID];
        }
    }
    return sections.copy;
}

- (void)pp_insertHomeSectionIdentifier:(NSNumber *)sectionIdentifier
                            intoSnapshot:(NSDiffableDataSourceSnapshot *)snapshot {
    if ([snapshot.sectionIdentifiers containsObject:sectionIdentifier]) {
        return;
    }

    NSArray<NSNumber *> *resolvedOrder = [self pp_orderedHomeSectionIdentifiers];
    NSUInteger targetIndex = [resolvedOrder indexOfObject:sectionIdentifier];
    if (targetIndex == NSNotFound) {
        [snapshot appendSectionsWithIdentifiers:@[sectionIdentifier]];
        return;
    }

    NSNumber *insertBefore = nil;
    for (NSUInteger idx = targetIndex + 1; idx < resolvedOrder.count; idx++) {
        NSNumber *candidate = resolvedOrder[idx];
        if ([snapshot.sectionIdentifiers containsObject:candidate]) {
            insertBefore = candidate;
            break;
        }
    }

    if (insertBefore) {
        [snapshot insertSectionsWithIdentifiers:@[sectionIdentifier]
                      beforeSectionWithIdentifier:insertBefore];
    } else {
        [snapshot appendSectionsWithIdentifiers:@[sectionIdentifier]];
    }
}

- (void)applyBaseSnapshot
{
    // Until the HomeConfig listener (or the safety timeout) tells us which
    // sections are visible, keep the snapshot empty. Rendering defaults first
    // and relaying out after the config arrives produces the "everything appears
    // then half of it disappears" flash we're trying to avoid. The premium
    // entrance animation runs once below, on the first non-empty apply.
    if (!self.didReceiveHomeConfig) {
        NSDiffableDataSourceSnapshot *emptySnapshot = [[NSDiffableDataSourceSnapshot alloc] init];
        [self.dataSource applySnapshot:emptySnapshot animatingDifferences:NO];
        return;
    }

    NSDiffableDataSourceSnapshot *snapshot = [[NSDiffableDataSourceSnapshot alloc] init];
    NSArray<NSNumber *> *sections = [self pp_orderedHomeSectionIdentifiers];

    // 🔒 Deduplicate section identifiers to prevent diffable data source crash
    // when Firestore remote config contains duplicate ids.
    NSOrderedSet<NSNumber *> *dedupedSections = [NSOrderedSet orderedSetWithArray:sections];
    if (dedupedSections.count != sections.count) {
        NSLog(@"[HomeConfig] WARNING: Duplicate section identifiers detected — deduplicated from %lu to %lu",
              (unsigned long)sections.count, (unsigned long)dedupedSections.count);
        sections = dedupedSections.array;
    }

    [snapshot appendSectionsWithIdentifiers:sections];

    void (^safeAppend)(NSArray *, NSNumber *) = ^(NSArray *items, NSNumber *section) {
        if ([sections containsObject:section]) {
            [snapshot appendItemsWithIdentifiers:items intoSectionWithIdentifier:section];
        }
    };

    // ✅ Hero
    PPHomeItem *heroItem = [[PPHomeItem alloc] initWithType:PPHomeItemTypeHero payload:@"hero-card"];
    safeAppend(@[heroItem], @(PPHomeSectionHero));

    // ✅ Premium Search
    PPHomeItem *premiumSearchItem = [[PPHomeItem alloc] initWithType:PPHomeItemTypePremiumSearch payload:@"premium-search-card"];
    safeAppend(@[premiumSearchItem], @(PPHomeSectionPremiumSearch));

    // ✅ Quick Actions
    NSMutableArray<PPHomeItem *> *quickActions = [NSMutableArray array];
    for (PPHomeQuickActionModel *qa in [self pp_homeQuickActions]) {
        PPHomeItem *item = [PPHomeItem new];
        item.type = PPHomeItemTypeQuickActions;
        item.payload = qa;
        [quickActions addObject:item];
    }
    safeAppend(quickActions, @(PPHomeSectionQuickActions));

    // ✅ Services
    NSMutableArray *servicesItems = [NSMutableArray array];
    for (PPHomeServiceItem *service in [PPHomeServiceItem defaultHomeServices]) {
        PPHomeItem *item = [PPHomeItem new];
        item.payload = service;
        [servicesItems addObject:item];
    }
    safeAppend(servicesItems, @(PPHomeSectionServices));

    // ✅ Current Orders
    safeAppend([self pp_homeCurrentOrderItems], @(PPHomeSectionCurrentOrders));

    // ✅ Carousel
    PPHomeItem *carouselItem = [PPHomeItem new];
    NSArray *cards = self.promoCarouselCards;
    if (cards.count == 0) cards = [self pp_homePromoFallbackCards];
    carouselItem.payload = cards.count > 0 ? cards : (id)[NSNull null];
    safeAppend(@[carouselItem], @(PPHomeSectionCarousel));

    // ✅ MainKinds
    NSMutableArray *kinds = [NSMutableArray array];
    for (MainKindsModel *k in self.mainKinds) {
        PPHomeItem *item = [PPHomeItem new];
        item.payload = k;
        [kinds addObject:item];
    }
    safeAppend(kinds, @(PPHomeSectionMainKinds));

    // ✅ Pet Profile
    PPHomeItem *petProfileItem = [[PPHomeItem alloc] initWithType:PPHomeItemTypePetProfile payload:@"pet-profile-card"];
    safeAppend(@[petProfileItem], @(PPHomeSectionPetProfile));

    // ✅ Premium Care
    PPHomeItem *premiumCareItem = [[PPHomeItem alloc] initWithType:PPHomeItemTypePremiumCare payload:@"premium-care-card"];
    safeAppend(@[premiumCareItem], @(PPHomeSectionPremiumCare));

    // ✅ Adopt
    PPHomeItem *adoptItem = [[PPHomeItem alloc] initWithType:PPHomeItemTypeAdopt payload:@"adopt"];
    safeAppend(@[adoptItem], @(PPHomeSectionAdopt));

    // ✅ Buy Again
    safeAppend([self pp_homeBuyAgainItems], @(PPHomeSectionBuyAgain));

    // Dynamic sections (Suggestions, Accessories, LastFood, NearbyServices, AdsNearBy)
    NSArray<NSNumber *> *dynamicSections = @[
        @(PPHomeSectionSuggestions),
        @(PPHomeSectionAccessories),
        @(PPHomeSectionLastFood),
        @(PPHomeSectionNearbyServices),
        @(PPHomeSectionAdsNearBy),
    ];
    for (NSNumber *sec in dynamicSections) {
        safeAppend([self pp_buildItemsForSection:(PPHomeSection)sec.integerValue], sec);
    }

    // 🔒 Config-driven rebuilds may delete sections that currently have visible
    // cells. Animating that diff can crash mid-transition with
    // NSInternalInconsistencyException. We also want the premium entrance
    // animation (not the diffable default) to drive the first reveal, so we
    // always apply non-animated and let pp_beginPremiumHomeEntranceIfNeeded
    // stage the fade-in below.
    BOOL isFirstContentApply = !self.didApplyInitialBaseSnapshot;
    self.didApplyInitialBaseSnapshot = YES;
    [self.dataSource applySnapshot:snapshot animatingDifferences:NO];
    [self pp_reloadHomeCollectionLayoutPreservingScrollOffset];

    // First time we render non-empty sections and the screen is on stage: stage
    // every visible surface in one non-animated pass, then run the premium
    // entrance so order matches Console Home Control without a layout jump.
    if (isFirstContentApply && sections.count > 0 && self.isViewLoaded && self.view.window != nil) {
        self.didPrepareVisibleHomeEntranceContent = NO;
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        [UIView performWithoutAnimation:^{
            [self pp_preparePremiumHomeEntranceStateIfNeeded];
            [self.collectionView setNeedsLayout];
            [self.collectionView layoutIfNeeded];
            [self pp_prepareVisibleHomeEntranceContentIfNeeded];
        }];
        [CATransaction commit];
        [self pp_beginPremiumHomeEntranceIfNeeded];
    } else if (isFirstContentApply && sections.count > 0) {
        [self pp_preparePremiumHomeEntranceStateIfNeeded];
    }
}

- (void)pp_scheduleInitialMainKindsLayoutRefresh
{
    // Single deferred layout pass for orthogonal QuickActions + MainKinds sizing.
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.collectionView) {
            return;
        }

        [self.collectionView.collectionViewLayout invalidateLayout];
        [self.collectionView setNeedsLayout];
        [self.collectionView layoutIfNeeded];
    });
}

- (void)pp_stabilizeHomeCollectionLayoutIfNeeded
{
    if (!self.isViewLoaded || !self.collectionView || !self.layoutManager || !self.dataSource) {
        return;
    }

    if ([self pp_shouldDeferHomeLayoutStabilization]) {
        return;
    }

    CGSize boundsSize = self.collectionView.bounds.size;
    if (boundsSize.width <= 1.0 || boundsSize.height <= 1.0) {
        return;
    }

    UIEdgeInsets adjustedInsets = self.collectionView.adjustedContentInset;
    BOOL needsInitialPass = !self.didStabilizeInitialHomeLayout;
    BOOL widthChanged = fabs(boundsSize.width - self.lastHomeLayoutBoundsSize.width) > 0.5;

    // 🔒 We only trigger stabilization if it's the first time or if the width/safe area significantly changed.
    if (!needsInitialPass && !widthChanged) {
        return;
    }

    self.didStabilizeInitialHomeLayout = YES;
    self.lastHomeLayoutBoundsSize = boundsSize;
    self.lastHomeLayoutAdjustedInsets = adjustedInsets;

    CGPoint preservedOffset = self.collectionView.contentOffset;

    // 🎯 Smooth invalidation: Since our layout provider block captures self/layoutManager,
    // a simple invalidation will use the latest properties without flickering the whole screen.
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [UIView performWithoutAnimation:^{
        [self.collectionView.collectionViewLayout invalidateLayout];
        [self.collectionView setNeedsLayout];
        [self.collectionView layoutIfNeeded];
    }];
    [CATransaction commit];

    CGFloat minOffsetY = -self.collectionView.adjustedContentInset.top;
    CGFloat maxOffsetY = MAX(minOffsetY,
                             self.collectionView.contentSize.height -
                             CGRectGetHeight(self.collectionView.bounds) +
                             self.collectionView.adjustedContentInset.bottom);
    CGFloat targetOffsetY = MIN(MAX(preservedOffset.y, minOffsetY), maxOffsetY);
    self.collectionView.contentOffset = CGPointMake(0.0, targetOffsetY);

    [self refreshHeroSectionAppearance];
    [self pp_refreshVisibleHomeCardsForSections:@[
        @(PPHomeSectionPetProfile),
        @(PPHomeSectionPremiumSearch),
        @(PPHomeSectionPremiumCare),
        @(PPHomeSectionAdopt)
    ]];
}

- (void)pp_refreshVisibleHomeCardsForSections:(NSArray<NSNumber *> *)sections
{
    if (sections.count == 0 || !self.isViewLoaded || !self.collectionView) {
        return;
    }

    NSArray<NSNumber *> *sectionsToRefresh = sections.copy;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.isViewLoaded || !self.collectionView) {
            return;
        }
        if (![self pp_isInitialHomeRevealSettled]) {
            return;
        }

        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        [UIView performWithoutAnimation:^{
            [self.collectionView setNeedsLayout];
            [self.collectionView layoutIfNeeded];

            for (UICollectionViewCell *cell in self.collectionView.visibleCells) {
                NSIndexPath *indexPath = [self.collectionView indexPathForCell:cell];
                if (!indexPath) {
                    continue;
                }

                NSNumber *sectionNumber = @([self sectionTypeForIndexPath:indexPath]);
                if (![sectionsToRefresh containsObject:sectionNumber]) {
                    continue;
                }

                [cell setNeedsLayout];
                [cell.contentView setNeedsLayout];
                [cell.contentView layoutIfNeeded];
                [cell layoutIfNeeded];
            }
        }];
        [CATransaction commit];
    });
}

- (void)pp_refreshInitialHomeRevealDependentContent
{
    if (![self pp_isInitialHomeRevealSettled] || !self.isViewLoaded || !self.collectionView) {
        return;
    }

    [self pp_refreshVisibleHomeCardsForSections:@[
        @(PPHomeSectionPetProfile),
        @(PPHomeSectionPremiumSearch),
        @(PPHomeSectionPremiumCare),
        @(PPHomeSectionAdopt)
    ]];

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || ![self pp_isInitialHomeRevealSettled]) {
            return;
        }
        [self pp_refreshVisiblePremiumCareAnimation];
    });
}

- (void)pp_applyCurrentLanguageDirectionToHomeUI
{
    UISemanticContentAttribute semantic = PPHomeCurrentSemanticAttribute();
    self.view.semanticContentAttribute = semantic;
    self.collectionView.semanticContentAttribute = semantic;
    self.navigationController.navigationBar.semanticContentAttribute = semantic;

    PPHomeApplySemanticToViewTree(self.navigationItem.titleView, semantic);
    PPHomeApplySemanticToViewTree(self.homeSmartSearchView, semantic);
    PPHomeApplySemanticToViewTree(self.homeLocationTitleView, semantic);
    PPHomeApplySemanticToViewTree(self.homeProfileItem.customView, semantic);
    PPHomeApplySemanticToViewTree(self.homeCartItem.customView, semantic);
    [self pp_refreshHomeLocationTitleViewAnimated:NO];

    for (UICollectionViewCell *cell in self.collectionView.visibleCells) {
        cell.semanticContentAttribute = semantic;
        cell.contentView.semanticContentAttribute = semantic;
    }

    for (UICollectionReusableView *header in
         [self.collectionView visibleSupplementaryViewsOfKind:UICollectionElementKindSectionHeader]) {
        PPHomeApplySemanticToViewTree(header, semantic);
    }
}

- (void)pp_forceHomeCollectionLayoutRefresh
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pp_forceHomeCollectionLayoutRefresh];
        });
        return;
    }

    if (!self.isViewLoaded || !self.collectionView || !self.dataSource) {
        return;
    }

    CGPoint preservedOffset = self.collectionView.contentOffset;
    NSArray<NSIndexPath *> *visibleIndexPaths = self.collectionView.indexPathsForVisibleItems ?: @[];
    NSMutableArray<PPHomeItem *> *visibleIdentifiers = [NSMutableArray arrayWithCapacity:visibleIndexPaths.count];
    for (NSIndexPath *indexPath in visibleIndexPaths) {
        PPHomeItem *item = [self.dataSource itemIdentifierForIndexPath:indexPath];
        if (item) {
            [visibleIdentifiers addObject:item];
        }
    }

    self.didStabilizeInitialHomeLayout = NO;
    self.lastHomeLayoutBoundsSize = CGSizeZero;
    self.lastHomeLayoutAdjustedInsets = UIEdgeInsetsZero;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [UIView performWithoutAnimation:^{
        [self.collectionView.collectionViewLayout invalidateLayout];
        [self.collectionView setNeedsLayout];
        [self.collectionView layoutIfNeeded];
    }];
    [CATransaction commit];

    if (visibleIdentifiers.count > 0) {
        NSDiffableDataSourceSnapshot *snapshot = self.dataSource.snapshot;
        [self pp_reconfigureHomeItems:visibleIdentifiers inSnapshot:snapshot];
    }

    CGFloat minOffsetY = -self.collectionView.adjustedContentInset.top;
    CGFloat maxOffsetY = MAX(minOffsetY,
                             self.collectionView.contentSize.height -
                             CGRectGetHeight(self.collectionView.bounds) +
                             self.collectionView.adjustedContentInset.bottom);
    CGFloat targetOffsetY = MIN(MAX(preservedOffset.y, minOffsetY), maxOffsetY);
    self.collectionView.contentOffset = CGPointMake(preservedOffset.x, targetOffsetY);

    [self pp_applyCurrentLanguageDirectionToHomeUI];
    [self pp_stabilizeHomeCollectionLayoutIfNeeded];
}

- (void)pp_refreshThemeSensitiveHomeContent
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pp_refreshThemeSensitiveHomeContent];
        });
        return;
    }

    if (!self.isViewLoaded || !self.collectionView || !self.dataSource) {
        return;
    }

    NSArray<NSNumber *> *themeSections = @[
        @(PPHomeSectionSuggestions),
        @(PPHomeSectionAccessories),
        @(PPHomeSectionPremiumSearch),
        @(PPHomeSectionPremiumCare),
        @(PPHomeSectionLastFood),
        @(PPHomeSectionNearbyServices),
        @(PPHomeSectionAdsNearBy),
        @(PPHomeSectionBuyAgain)
    ];

    [self pp_applyOrderDetailsBackgroundAppearance];
    if ([self pp_canOwnHomeNavigationChrome]) {
        [self configureNavigationBar];
    } else {
        [self pp_detachHomeSmartSearchTitleViewIfNeeded];
        [self pp_detachHomeLocationTitleViewIfNeeded];
    }
    [self refreshHeroSectionAppearance];
    [self setNeedsStatusBarAppearanceUpdate];

    NSArray<NSIndexPath *> *visibleIndexPaths = self.collectionView.indexPathsForVisibleItems ?: @[];
    NSMutableArray<PPHomeItem *> *visibleIdentifiers = [NSMutableArray array];
    for (NSIndexPath *indexPath in visibleIndexPaths) {
        NSNumber *sectionNumber = @([self sectionTypeForIndexPath:indexPath]);
        if (![themeSections containsObject:sectionNumber]) {
            continue;
        }

        PPHomeItem *item = [self.dataSource itemIdentifierForIndexPath:indexPath];
        if (item) {
            [visibleIdentifiers addObject:item];
        }
    }

    if (visibleIdentifiers.count > 0) {
        NSDiffableDataSourceSnapshot *snapshot = self.dataSource.snapshot;
        [self pp_reconfigureHomeItems:visibleIdentifiers inSnapshot:snapshot];
    }

    [self pp_refreshVisibleHomeCardsForSections:themeSections];
    [self.collectionView.collectionViewLayout invalidateLayout];
    [self.collectionView setNeedsLayout];
    [self.collectionView layoutIfNeeded];

    NSInteger cartCount = [CartManager.sharedManager totalItemsCount];
    [self pp_applyHomeCartBadgeCount:cartCount animated:NO];
    [self pp_applyCurrentLanguageDirectionToHomeUI];
}

- (void)pp_refreshHomeAppearanceChromeWithoutCollectionReload
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pp_refreshHomeAppearanceChromeWithoutCollectionReload];
        });
        return;
    }

    if (!self.isViewLoaded) {
        return;
    }

    [self pp_applyOrderDetailsBackgroundAppearance];
    if ([self pp_canOwnHomeNavigationChrome]) {
        [self configureNavigationBar];
    } else {
        [self pp_detachHomeSmartSearchTitleViewIfNeeded];
        [self pp_detachHomeLocationTitleViewIfNeeded];
    }
    [self refreshHeroSectionAppearance];
    [self setNeedsStatusBarAppearanceUpdate];

    NSInteger cartCount = [CartManager.sharedManager totalItemsCount];
    [self pp_applyHomeCartBadgeCount:cartCount animated:NO];
    [self pp_applyCurrentLanguageDirectionToHomeUI];
}

- (NSString *)pp_homeSuggestionsRefreshSignature
{
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    [parts addObject:[NSString stringWithFormat:@"nearby:%lu", (unsigned long)self.nearbyAds.count]];
    for (PetAd *ad in self.nearbyAds ?: @[]) {
        NSString *adID = PPSafeString(ad.adID);
        if (adID.length == 0) {
            adID = [NSString stringWithFormat:@"%ld:%@", (long)ad.category, PPSafeString(ad.adTitle)];
        }
        [parts addObject:[NSString stringWithFormat:@"ad:%@", adID]];
    }

    [parts addObject:[NSString stringWithFormat:@"accessories:%lu", (unsigned long)self.accessories.count]];
    for (PetAccessory *accessory in self.accessories ?: @[]) {
        NSString *accessoryID = PPSafeString(accessory.accessoryID);
        if (accessoryID.length == 0) {
            accessoryID = [NSString stringWithFormat:@"%ld:%@", (long)accessory.petMainCategoryID, PPSafeString(accessory.name)];
        }
        [parts addObject:[NSString stringWithFormat:@"acc:%@", accessoryID]];
    }

    [parts addObject:[NSString stringWithFormat:@"orders:%lu", (unsigned long)self.recentOrders.count]];
    for (PPOrder *order in self.recentOrders ?: @[]) {
        [parts addObject:[NSString stringWithFormat:@"order:%@", PPSafeString(order.orderId)]];
    }

    NSDictionary *latestEvent = [[PPBrowseHistoryManager shared] latestEvent];
    id eventType = latestEvent[@"type"];
    id eventKind = latestEvent[@"kind"];
    [parts addObject:[NSString stringWithFormat:@"event:%@:%@",
                      [eventType respondsToSelector:@selector(description)] ? [eventType description] : @"",
                      [eventKind respondsToSelector:@selector(description)] ? [eventKind description] : @""]];

    return [parts componentsJoinedByString:@"|"];
}

- (void)pp_refreshSuggestionsForAppearanceIfNeeded
{
    if (!(self.accessoriesLoaded || self.nearbyLoaded)) {
        return;
    }

    NSString *signature = [self pp_homeSuggestionsRefreshSignature];
    if (signature.length > 0 &&
        [signature isEqualToString:PPSafeString(self.lastHomeSuggestionsAppearanceSignature)]) {
        return;
    }

    self.lastHomeSuggestionsAppearanceSignature = signature;
    [self reloadSection:PPHomeSectionSuggestions];
}

- (NSString *)pp_homeDateSignaturePart:(nullable NSDate *)date
{
    if (![date isKindOfClass:NSDate.class]) {
        return @"0";
    }
    return [NSString stringWithFormat:@"%.0f", date.timeIntervalSince1970];
}

- (NSString *)pp_homeOrderSignaturePart:(nullable PPOrder *)order
{
    if (![order isKindOfClass:PPOrder.class]) {
        return @"none";
    }

    return [@[
        PPSafeString(order.orderId),
        PPSafeString(order.orderNumber),
        PPSafeString(order.rawStatus),
        PPSafeString(order.deliveryStatus),
        PPSafeString(order.paymentStatus),
        PPSafeString(order.verificationStatus),
        PPSafeString(order.paymentMethodId),
        PPSafeString([self pp_homeOrderStatusKey:order]),
        [NSString stringWithFormat:@"%.2f", order.amount],
        [NSString stringWithFormat:@"%.2f", order.shippingFee],
        [NSString stringWithFormat:@"%.2f", order.totalAmount],
        [NSString stringWithFormat:@"%lu", (unsigned long)(order.items ?: @[]).count],
        [self pp_homeDateSignaturePart:order.updatedAt],
        [self pp_homeDateSignaturePart:order.statusUpdatedAt],
        [self pp_homeDateSignaturePart:order.paymentConfirmedAt],
        [self pp_homeDateSignaturePart:order.completedAt],
        [self pp_homeDateSignaturePart:order.cancelledAt]
    ] componentsJoinedByString:@":"];
}

- (NSString *)pp_homeCurrentOrdersSectionSignatureWithLoading:(BOOL)loading
{
    PPOrder *featuredOrder = [self pp_featuredHomeOrder];
    return [NSString stringWithFormat:@"loading:%d|featured:%@",
            loading && !featuredOrder,
            [self pp_homeOrderSignaturePart:featuredOrder]];
}

- (NSString *)pp_homeBuyAgainSignatureForEntries:(NSArray *)entries
{
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    [parts addObject:[NSString stringWithFormat:@"count:%lu", (unsigned long)(entries ?: @[]).count]];

    for (id entry in entries ?: @[]) {
        if ([entry isKindOfClass:PetAccessory.class]) {
            PetAccessory *accessory = (PetAccessory *)entry;
            NSNumber *price = accessory.finalPrice ?: accessory.price ?: @0;
            NSString *imageURL = @"";
            if ([accessory.imageURLsArray isKindOfClass:NSArray.class]) {
                imageURL = PPSafeString(accessory.imageURLsArray.firstObject);
            }
            [parts addObject:[NSString stringWithFormat:@"accessory:%@:%@:%ld:%ld:%@:%ld:%@",
                              PPSafeString(accessory.accessoryID),
                              PPSafeString(accessory.name),
                              (long)accessory.accessKindType,
                              (long)accessory.petMainCategoryID,
                              price.stringValue ?: @"0",
                              (long)accessory.quantity,
                              imageURL]];
            continue;
        }

        if ([entry isKindOfClass:PPHomeBuyAgainSnapshotItem.class]) {
            PPHomeBuyAgainSnapshotItem *snapshotItem = (PPHomeBuyAgainSnapshotItem *)entry;
            [parts addObject:[NSString stringWithFormat:@"snapshot:%@:%@:%ld:%ld:%@",
                              PPSafeString(snapshotItem.itemID),
                              PPSafeString(snapshotItem.title),
                              (long)snapshotItem.accessKindType,
                              (long)snapshotItem.mainKindID,
                              PPSafeString(snapshotItem.imageURL)]];
            continue;
        }

        [parts addObject:NSStringFromClass([entry class]) ?: @"unknown"];
    }

    return [parts componentsJoinedByString:@"|"];
}

- (void)pp_refreshPetProfilesSectionForAppearanceIfNeeded
{
    NSString *userID = [self pp_currentOrdersUserID];
    BOOL isLoggedIn = userID.length > 0 && UserManager.sharedManager.isUserLoggedIn;
    if (!isLoggedIn) {
        self.shouldRefreshPetProfilesOnNextAppearance = NO;
        BOOL hasStaleProfileState =
            self.lastPetProfilesUserID.length > 0 ||
            self.petProfiles.count > 0 ||
            self.defaultPetProfile != nil ||
            self.petProfilesLoading ||
            !self.petProfilesLoaded;
        if (hasStaleProfileState) {
            [self pp_refreshPetProfilesSection];
        }
        return;
    }

    if (self.shouldRefreshPetProfilesOnNextAppearance) {
        self.shouldRefreshPetProfilesOnNextAppearance = NO;
        [self pp_refreshPetProfilesSection];
        return;
    }

    BOOL userChanged = ![userID isEqualToString:PPSafeString(self.lastPetProfilesUserID)];
    if (!self.petProfilesLoaded || userChanged) {
        [self pp_refreshPetProfilesSection];
    }
}

- (NSString *)pp_homePetProfilesSignatureForProfiles:(NSArray<PPPetProfile *> *)profiles
                                           defaultPet:(nullable PPPetProfile *)defaultPet
                                              loading:(BOOL)loading
{
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    [parts addObject:[NSString stringWithFormat:@"loading:%d", loading]];
    [parts addObject:[NSString stringWithFormat:@"default:%@", PPSafeString(defaultPet.petID)]];
    for (PPPetProfile *profile in profiles ?: @[]) {
        NSTimeInterval updatedAt = profile.updatedAt ? profile.updatedAt.timeIntervalSince1970 : 0.0;
        [parts addObject:[NSString stringWithFormat:@"pet:%@:%@:%@:%ld:%@:%d:%.0f",
                          PPSafeString(profile.petID),
                          PPSafeString(profile.name),
                          PPSafeString(profile.breed),
                          (long)profile.ageInMonths,
                          PPSafeString(profile.imageURL),
                          profile.isDefaultPet,
                          updatedAt]];
    }
    return [parts componentsJoinedByString:@"|"];
}

- (NSString *)pp_stableKeyForHomeItem:(PPHomeItem *)item
                               section:(PPHomeSection)section
                                 index:(NSInteger)index
{
    if (![item isKindOfClass:PPHomeItem.class]) {
        return [NSString stringWithFormat:@"section:%ld:index:%ld:empty", (long)section, (long)index];
    }

    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    [parts addObject:[NSString stringWithFormat:@"section:%ld", (long)section]];
    [parts addObject:[NSString stringWithFormat:@"type:%ld", (long)item.type]];

    PPUniversalCellViewModel *vm = item.universalViewModel;
    if ([vm isKindOfClass:PPUniversalCellViewModel.class]) {
        if (vm.isSkeleton) {
            [parts addObject:[NSString stringWithFormat:@"skeleton:%ld", (long)index]];
            return [parts componentsJoinedByString:@"|"];
        }

        NSString *modelID = PPSafeString(vm.ModelID);
        NSString *modelType = PPSafeString(vm.modelType);
        NSString *imageURL = PPSafeString(vm.imageURL);
        if (modelID.length > 0 || imageURL.length > 0 || modelType.length > 0) {
            [parts addObject:[NSString stringWithFormat:@"model:%@:%@:%@", modelType, modelID, imageURL]];
            return [parts componentsJoinedByString:@"|"];
        }
    }

    id payload = item.payload;
    if (payload == NSNull.null) {
        [parts addObject:@"payload:null"];
        return [parts componentsJoinedByString:@"|"];
    }

    if ([payload isKindOfClass:MainKindsModel.class]) {
        MainKindsModel *kind = (MainKindsModel *)payload;
        [parts addObject:[NSString stringWithFormat:@"kind:%ld:%@", (long)kind.ID, PPSafeString(kind.KindName)]];
        return [parts componentsJoinedByString:@"|"];
    }

    if ([payload isKindOfClass:PPHomeQuickActionModel.class]) {
        PPHomeQuickActionModel *quickAction = (PPHomeQuickActionModel *)payload;
        [parts addObject:[NSString stringWithFormat:@"quick:%ld", (long)quickAction.type]];
        return [parts componentsJoinedByString:@"|"];
    }

    if ([payload isKindOfClass:PPOrder.class]) {
        PPOrder *order = (PPOrder *)payload;
        NSString *orderID = PPSafeString(order.orderId);
        [parts addObject:[NSString stringWithFormat:@"order:%@", orderID.length > 0 ? orderID : PPSafeString(order.orderNumber)]];
        return [parts componentsJoinedByString:@"|"];
    }

    if ([payload isKindOfClass:NSString.class]) {
        [parts addObject:[NSString stringWithFormat:@"token:%@", PPSafeString((NSString *)payload)]];
        return [parts componentsJoinedByString:@"|"];
    }

    // Static card sections should keep a single identity even when their payload content changes.
    if (section == PPHomeSectionHero ||
        section == PPHomeSectionCarousel ||
        section == PPHomeSectionPetProfile ||
        section == PPHomeSectionPremiumSearch ||
        section == PPHomeSectionPremiumCare ||
        section == PPHomeSectionAdopt) {
        [parts addObject:[NSString stringWithFormat:@"static:%ld", (long)section]];
        return [parts componentsJoinedByString:@"|"];
    }

    [parts addObject:[NSString stringWithFormat:@"index:%ld", (long)index]];
    return [parts componentsJoinedByString:@"|"];
}

- (NSArray<PPHomeItem *> *)pp_homeItemsByReusingExistingItems:(NSArray<PPHomeItem *> *)existingItems
                                                     newItems:(NSArray<PPHomeItem *> *)newItems
                                                      section:(PPHomeSection)section
{
    if (existingItems.count == 0 || newItems.count == 0) {
        return newItems ?: @[];
    }

    NSMutableDictionary<NSString *, NSMutableArray<PPHomeItem *> *> *existingBuckets = [NSMutableDictionary dictionary];
    [existingItems enumerateObjectsUsingBlock:^(PPHomeItem * _Nonnull existingItem, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)stop;
        NSString *key = [self pp_stableKeyForHomeItem:existingItem section:section index:(NSInteger)idx];
        if (key.length == 0) {
            return;
        }

        NSMutableArray<PPHomeItem *> *bucket = existingBuckets[key];
        if (!bucket) {
            bucket = [NSMutableArray array];
            existingBuckets[key] = bucket;
        }
        [bucket addObject:existingItem];
    }];

    NSMutableArray<PPHomeItem *> *resolvedItems = [NSMutableArray arrayWithCapacity:newItems.count];
    [newItems enumerateObjectsUsingBlock:^(PPHomeItem * _Nonnull newItem, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)stop;
        NSString *key = [self pp_stableKeyForHomeItem:newItem section:section index:(NSInteger)idx];
        NSMutableArray<PPHomeItem *> *bucket = key.length > 0 ? existingBuckets[key] : nil;
        PPHomeItem *reusedItem = bucket.firstObject;

        if (reusedItem) {
            [bucket removeObjectAtIndex:0];
            reusedItem.type = newItem.type;
            reusedItem.payload = newItem.payload;
            reusedItem.universalViewModel = newItem.universalViewModel;
            reusedItem.categoryKind = newItem.categoryKind;
            [resolvedItems addObject:reusedItem];
        } else if (newItem) {
            [resolvedItems addObject:newItem];
        }
    }];

    return resolvedItems.copy;
}

- (void)pp_reconfigureHomeItems:(NSArray<PPHomeItem *> *)items
                      inSnapshot:(NSDiffableDataSourceSnapshot *)snapshot
{
    if (items.count == 0 || !snapshot || !self.dataSource) {
        return;
    }

    if (@available(iOS 15.0, *)) {
        [snapshot reconfigureItemsWithIdentifiers:items];
    } else {
        [snapshot reloadItemsWithIdentifiers:items];
    }
    [self.dataSource applySnapshot:snapshot animatingDifferences:NO];
}

// 🔒 Safe accessor: returns @[] if the section is not present in the snapshot.
// UICollectionViewDiffableDataSource throws NSInternalInconsistencyException
// from -itemIdentifiersInSectionWithIdentifier: when the section was hidden by
// Home Control config. All home-snapshot reads must go through this helper.
- (NSArray<PPHomeItem *> *)pp_safeItemsInSection:(PPHomeSection)section
                                     fromSnapshot:(NSDiffableDataSourceSnapshot *)snapshot
{
    if (!snapshot) {
        return @[];
    }
    NSNumber *sectionID = @(section);
    if (![snapshot.sectionIdentifiers containsObject:sectionID]) {
        return @[];
    }
    return [snapshot itemIdentifiersInSectionWithIdentifier:sectionID] ?: @[];
}

- (BOOL)pp_isSectionPresent:(PPHomeSection)section
                 inSnapshot:(NSDiffableDataSourceSnapshot *)snapshot
{
    if (!snapshot) {
        return NO;
    }
    return [snapshot.sectionIdentifiers containsObject:@(section)];
}

// Builds the current items for a reloadable Home section straight from the
// controller's backing data (self.accessories, self.nearbyAds, etc.).
// Used by both applyBaseSnapshot (so a Home Control rebuild keeps the
// already-loaded content in place) and reloadSection: (so the
// per-section refresh path sees the exact same item shape).
- (NSArray<PPHomeItem *> *)pp_buildItemsForSection:(PPHomeSection)section
{
    NSMutableArray<PPHomeItem *> *items = [NSMutableArray array];

    switch (section) {
        case PPHomeSectionCurrentOrders:
            [items addObjectsFromArray:[self pp_homeCurrentOrderItems]];
            break;

        case PPHomeSectionBuyAgain:
            [items addObjectsFromArray:[self pp_homeBuyAgainItems]];
            break;

        case PPHomeSectionAccessories:
            for (PetAccessory *a in self.accessories) {
                PPHomeItem *item = [PPHomeItem new];
                PPUniversalCellViewModel *vm =
                    [[PPUniversalCellViewModel alloc] initWithModel:a
                                                            context:PPCellForMarket];
                vm.ModelObject = a;
                item.universalViewModel = vm;
                [items addObject:item];
            }
            break;

        case PPHomeSectionPetProfile: {
            PPHomeItem *item =
                [[PPHomeItem alloc] initWithType:PPHomeItemTypePetProfile payload:@"pet-profile-card"];
            [items addObject:item];
            break;
        }

        case PPHomeSectionLastFood:
            for (PetAccessory *food in self.lastFoodAccessories) {
                PPHomeItem *item = [PPHomeItem new];
                PPUniversalCellViewModel *vm =
                    [[PPUniversalCellViewModel alloc] initWithModel:food
                                                            context:PPCellForMarket];
                vm.ModelObject = food;
                item.universalViewModel = vm;
                [items addObject:item];
            }
            break;

        case PPHomeSectionAdsNearBy:
            if (self.nearbyLoading && self.nearbyAds.count == 0) {
                for (NSInteger i = 0; i < 3; i++) {
                    PPHomeItem *item = [PPHomeItem new];
                    item.universalViewModel = [[PPUniversalCellViewModel alloc] initSkeleton];
                    [items addObject:item];
                }
            } else if (self.nearbyAds.count == 0) {
                PPHomeItem *emptyItem = [PPHomeItem new];
                emptyItem.payload = @"nearby-empty-state";
                [items addObject:emptyItem];
            } else {
                for (PetAd *ad in self.nearbyAds) {
                    PPHomeItem *item = [PPHomeItem new];
                    PPUniversalCellViewModel *vm =
                        [[PPUniversalCellViewModel alloc] initWithModel:ad
                                                                context:PPCellForHomeAds];
                    vm.ModelObject = ad;
                    item.universalViewModel = vm;
                    [items addObject:item];
                }
            }
            break;

        case PPHomeSectionNearbyServices:
            if (self.nearbyServicesLoading && self.nearbyServiceProviders.count == 0) {
                for (NSInteger i = 0; i < 3; i++) {
                    PPHomeItem *item = [PPHomeItem new];
                    item.universalViewModel = [[PPUniversalCellViewModel alloc] initSkeleton];
                    [items addObject:item];
                }
            } else if (self.nearbyServiceProviders.count == 0) {
                PPHomeItem *emptyItem = [PPHomeItem new];
                emptyItem.payload = @"services-empty-state";
                [items addObject:emptyItem];
            } else {
                for (ServiceModel *svc in self.nearbyServiceProviders) {
                    PPHomeItem *item = [PPHomeItem new];
                    PPUniversalCellViewModel *vm =
                        [[PPUniversalCellViewModel alloc] initWithModel:svc
                                                                context:PPCellForServices];
                    vm.ModelObject = svc;
                    item.universalViewModel = vm;
                    [items addObject:item];
                }
            }
            break;

        case PPHomeSectionSuggestions: {
            NSMutableSet<NSString *> *seen = [NSMutableSet set];
            NSDictionary *latestEvent =
                [[PPBrowseHistoryManager shared] latestEvent];
            NSArray<NSString *> *orderedAccessoryIDs =
                [self pp_buyAgainAccessoryIDsFromOrders:self.recentOrders
                                                  limit:MAX(PPBuyAgainVisibleLimit * 2, PPBuyAgainVisibleLimit)];

            for (PetAd *ad in self.nearbyAds) {
                NSString *adID = PPSafeString(ad.adID);
                NSString *key = [NSString stringWithFormat:@"ad:%@", adID];
                if (adID.length == 0 || [seen containsObject:key]) continue;
                [seen addObject:key];

                PPHomeItem *item = [PPHomeItem new];
                PPUniversalCellViewModel *vm =
                    [[PPUniversalCellViewModel alloc] initWithModel:ad
                                                            context:PPCellForAds];
                vm.ModelObject = ad;
                NSDictionary<NSString *, NSString *> *reason =
                    [self pp_suggestionReasonForModel:ad
                                          latestEvent:latestEvent
                                    orderedAccessoryIDs:orderedAccessoryIDs];
                vm.contextualReasonText = PPSafeString(reason[@"text"]);
                vm.contextualReasonIconName = PPSafeString(reason[@"icon"]);
                item.universalViewModel = vm;
                [items addObject:item];
            }
            for (PetAccessory *acc in self.accessories) {
                NSString *accessoryID = PPSafeString(acc.accessoryID);
                NSString *key = [NSString stringWithFormat:@"acc:%@", accessoryID];
                if (accessoryID.length == 0 || [seen containsObject:key]) continue;
                [seen addObject:key];

                PPHomeItem *item = [PPHomeItem new];
                PPUniversalCellViewModel *vm =
                    [[PPUniversalCellViewModel alloc] initWithModel:acc
                                                            context:PPCellForMarket];
                vm.ModelObject = acc;
                NSDictionary<NSString *, NSString *> *reason =
                    [self pp_suggestionReasonForModel:acc
                                          latestEvent:latestEvent
                                    orderedAccessoryIDs:orderedAccessoryIDs];
                vm.contextualReasonText = PPSafeString(reason[@"text"]);
                vm.contextualReasonIconName = PPSafeString(reason[@"icon"]);
                item.universalViewModel = vm;
                [items addObject:item];
            }
            break;
        }

        default:
            break;
    }

    return items.copy;
}

- (void)reloadSection:(PPHomeSection)section
{
    NSNumber *sectionIdentifier = @(section);
    CGPoint preservedOffset = CGPointZero;
    BOOL preserveOffset = (section == PPHomeSectionSuggestions);

    if (preserveOffset) {
        preservedOffset = self.collectionView.contentOffset;
    }


    NSDiffableDataSourceSnapshot *snapshot =
        self.dataSource.snapshot;

    NSArray<NSNumber *> *sectionIdentifiers = snapshot.sectionIdentifiers;
    BOOL sectionExists = [sectionIdentifiers containsObject:sectionIdentifier];

    NSArray *items = sectionExists
        ? [snapshot itemIdentifiersInSectionWithIdentifier:sectionIdentifier]
        : @[];

    NSMutableArray *newItems = [[self pp_buildItemsForSection:section] mutableCopy];

    NSArray<PPHomeItem *> *stableNewItems =
        [self pp_homeItemsByReusingExistingItems:items
                                        newItems:newItems
                                         section:section];

    BOOL canReconfigureInPlace = sectionExists && items.count == stableNewItems.count;
    if (canReconfigureInPlace) {
        for (NSUInteger idx = 0; idx < items.count; idx++) {
            if (items[idx] != stableNewItems[idx]) {
                canReconfigureInPlace = NO;
                break;
            }
        }
    }

    newItems = [stableNewItems mutableCopy];

    if (canReconfigureInPlace && items.count > 0) {
        [self pp_reconfigureHomeItems:items inSnapshot:snapshot];

        if (section == PPHomeSectionSuggestions) {
            self.lastHomeSuggestionsAppearanceSignature = [self pp_homeSuggestionsRefreshSignature];
        }

        if (section == PPHomeSectionPetProfile ||
            section == PPHomeSectionPremiumSearch ||
            section == PPHomeSectionPremiumCare ||
            section == PPHomeSectionAdopt) {
            [self.collectionView setNeedsLayout];
            [self.collectionView layoutIfNeeded];
            [self pp_refreshVisibleHomeCardsForSections:@[@(section)]];
        }

        if (preserveOffset) {
            self.collectionView.contentOffset = preservedOffset;
        }

        return;
    }

    if (section == PPHomeSectionCurrentOrders &&
        sectionExists &&
        items.count == newItems.count &&
        items.count == 1 &&
        [items.firstObject isKindOfClass:PPHomeItem.class] &&
        [newItems.firstObject isKindOfClass:PPHomeItem.class]) {
        PPHomeItem *existingItem = (PPHomeItem *)items.firstObject;
        PPHomeItem *replacementItem = (PPHomeItem *)newItems.firstObject;
        existingItem.type = replacementItem.type;
        existingItem.payload = replacementItem.payload;
        existingItem.universalViewModel = replacementItem.universalViewModel;
        existingItem.categoryKind = replacementItem.categoryKind;
        [self pp_reconfigureHomeItems:@[existingItem] inSnapshot:snapshot];
        return;
    }

    if (items.count > 0) {
        [snapshot deleteItemsWithIdentifiers:items];
    }

    if (section == PPHomeSectionBuyAgain) {
        if (![self pp_shouldRenderHomeSection:PPHomeSectionBuyAgain]) {
            if (sectionExists) {
                [snapshot deleteSectionsWithIdentifiers:@[sectionIdentifier]];
                [self.dataSource applySnapshot:snapshot animatingDifferences:NO];
            }
            return;
        }

        if (!sectionExists) {
            [self pp_insertHomeSectionIdentifier:sectionIdentifier intoSnapshot:snapshot];
            sectionExists = YES;
        }
    } else if (!sectionExists) {
        return;
    }

    [snapshot appendItemsWithIdentifiers:newItems
               intoSectionWithIdentifier:sectionIdentifier];

    BOOL animate = YES;

    if (section == PPHomeSectionSuggestions ||
        section == PPHomeSectionAdsNearBy ||
        section == PPHomeSectionCurrentOrders ||
        section == PPHomeSectionPetProfile ||
        section == PPHomeSectionPremiumSearch ||
        section == PPHomeSectionPremiumCare ||
        section == PPHomeSectionAdopt ||
        section == PPHomeSectionAccessories ||
        section == PPHomeSectionLastFood ||
        section == PPHomeSectionMainKinds) {
        // 🔒 Prevent visual jumping on sections that fill from empty.
        animate = NO;
        if (section == PPHomeSectionSuggestions) {
            self.didFillSuggestionsOnce = YES;
        }
    }

    [self.dataSource applySnapshot:snapshot animatingDifferences:animate];
    if (section == PPHomeSectionSuggestions) {
        self.lastHomeSuggestionsAppearanceSignature = [self pp_homeSuggestionsRefreshSignature];
    }

    if (section == PPHomeSectionPetProfile ||
        section == PPHomeSectionPremiumSearch ||
        section == PPHomeSectionPremiumCare ||
        section == PPHomeSectionAdopt) {
        [self.collectionView setNeedsLayout];
        [self.collectionView layoutIfNeeded];
        [self pp_refreshVisibleHomeCardsForSections:@[@(section)]];
    }

    // 🔒 Restore scroll position (Suggestions only)
    if (preserveOffset) {
        self.collectionView.contentOffset = preservedOffset;
    }

    // 🎯 Center last section starting from index 1 (if available)
    if (section == PPHomeSectionAdsNearBy) {
        [self pp_centerNearbySectionIfPossible];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.isMainKindsExpanded = NO; // collapsed = horizontal
    self.homeTitleViewMode = @"location";
    self.homePremiumCareVisible = YES;
    self.nearbyServiceProviders = @[];
    self.nearbyServicesLoaded = NO;
    self.nearbyServicesLoading = NO;
    self.nearbyServicesShowingLatest = NO;
    self.warmUpCache = NO;
    self.chatsListenerStarted = NO;
    [self pp_applyOrderDetailsBackgroundAppearance];

    self.mainKinds = PPMainKindsArray;
    self.selectedCategory = nil; // nil == "All"
    self.blurHashCache = [NSCache new];
    self.blurHashCache.countLimit = 250;
    self.blurHashQueue =
    dispatch_queue_create("com.purepets.home.blurhash.decode", DISPATCH_QUEUE_CONCURRENT);
    self.selectedNearbyCoordinate = kCLLocationCoordinate2DInvalid;
    self.lastNearbyRefreshCoordinate = kCLLocationCoordinate2DInvalid;
    self.nearbyLocationState = PPNearbyLocationStateUnset;
    self.hasSelectedNearbyCoordinate = NO;
    self.hasLastNearbyRefreshCoordinate = NO;
    self.nearbyLoading = YES;
    self.nearbyRadiusKm = PPNearbyDefaultRadiusKm;
    self.currentOrders = @[];
    self.recentOrders = @[];
    self.petProfiles = @[];
    self.defaultPetProfile = nil;
    self.petProfilesLoading = YES;
    self.petProfilesLoaded = NO;
    self.buyAgainEntries = @[];
    self.lastFoodAccessories = @[];
    self.isCurrentOrdersExpanded = NO;
    self.currentOrdersRequestToken = 0;
    self.buyAgainRequestToken = 0;
    self.petProfilesRequestToken = 0;
    self.lastCurrentOrdersRefreshAt = nil;
    self.currentOrdersLoading = ([self pp_currentOrdersUserID].length > 0);
    self.currentOrdersLoaded = !self.currentOrdersLoading;
    self.homeGeocoder = [[CLGeocoder alloc] init];
    self.promoCarouselCards = PPHomePromoCarouselManager.sharedManager.cards ?: @[];
    self.animatedHomeItemIdentifiers = [NSMutableSet set];
    self.animatedHomeHeaderSections = [NSMutableSet set];
    self.animatedHomeHorizontalUniversalIdentifiers = [NSMutableSet set];
    [self configureLocationStateMachine];



    [self setupCollectionView];
    [self pp_applyOrderDetailsBackgroundAppearance];
    [self pp_applyCurrentLanguageDirectionToHomeUI];
    [self configureDataSource];
    [self pp_applyCachedHomeConfigIfAvailable];
    [self applyBaseSnapshot];   // 🔥 NEW
    [self refreshHeroSectionAppearance];

    __weak typeof(self) weakSelf = self;
    [[PPHomePromoCarouselManager sharedManager] startListeningWithCompletion:^(NSArray<PPHomePromoCarouselCard *> * _Nullable cards, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (error) {
            NSLog(@"[HomePromoCarousel] listener error: %@", error.localizedDescription);
            return;
        }
        self.promoCarouselCards = cards ?: @[];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self fillCarouselBanner];
        });
    }];

    [self loadData];
    [self pp_startHomeConfigListener];
    [self pp_prefetchHomeEntranceAnimationsIfNeeded];

    // Safety net: if HomeConfig never reports (fresh install offline, doc missing,
    // listener stalled) we still need to render *something*. After 800ms with no
    // signal, flip the gate and let applyBaseSnapshot fall back to defaultOrder.
    __weak typeof(self) weakSelfHomeConfigTimeout = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        __strong typeof(weakSelfHomeConfigTimeout) self = weakSelfHomeConfigTimeout;
        if (!self || self.didReceiveHomeConfig) {
            return;
        }
        if ([self pp_applyCachedHomeConfigIfAvailable]) {
            NSLog(@"[HomeConfig] Listener silent for 800ms — using cached Console sections.");
            [self applyBaseSnapshot];
            return;
        }
        NSLog(@"[HomeConfig] Listener silent for 800ms — using default sections fallback.");
        self.homeConfigSections = [self pp_mergeHomeConfigSectionsWithCatalog:@[]];
        self.didReceiveHomeConfig = YES;
        self.lastAppliedHomeConfigOrderSignature =
            [self pp_homeConfigOrderSignatureForSectionIdentifiers:[self pp_orderedHomeSectionIdentifiers]];
        [self applyBaseSnapshot];
    });

    // 🔥 Fill top banner once banners are ready
    dispatch_async(dispatch_get_main_queue(), ^{
        [self fillCarouselBanner];
    });


    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(handleBrowseHistoryUpdate)
               name:@"PPBrowseHistoryDidUpdate"
             object:nil];


    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(updateCartQuantityBadge)
               name:kCartUpdatedNotification //@"PPCartDidChangeNotification"
             object:nil];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(handleAppWillEnterForeground)
               name:UIApplicationWillEnterForegroundNotification
             object:nil];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(handleAdUploadCompletedNotification:)
               name:PPAdDidFinishUploadNotification
             object:nil];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(handleUserProfileSyncNotification:)
               name:PPUserManagerDidSyncCurrentUserNotification
             object:nil];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(handleUserProfileSyncNotification:)
               name:PPUserManagerDidSignOutNotification
             object:nil];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(handleUserAccessUpdateNotification:)
              name:PPUserManagerDidUpdateUserAccessNotification
              object:nil];

    // Language changes rebuild the root controller via SceneDelegate/Language.
    // Home must not do a second in-place language reload, which can leave stale
    // collection work running during the root swap on older iPad/iOS builds.
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(handleThemePreferenceDidChange:)
               name:PPThemePreferenceDidChangeNotification
              object:nil];
}

- (void)setupNovaFloatingButton
{
    UIColor *brand = AppPrimaryClr ?: [UIColor colorWithRed:0.98 green:0.70 blue:0.42 alpha:1.0];

    // Soft brand halo behind the orb. Breathes when motion is allowed.
    UIView *halo = [[UIView alloc] init];
    halo.translatesAutoresizingMaskIntoConstraints = NO;
    halo.userInteractionEnabled = NO;
    halo.backgroundColor = [brand colorWithAlphaComponent:0.16];
    halo.layer.cornerRadius = 36.0;
    if (@available(iOS 13.0, *)) {
        halo.layer.cornerCurve = kCACornerCurveContinuous;
    }
    halo.layer.shadowColor = brand.CGColor;
    halo.layer.shadowOpacity = 0.45;
    halo.layer.shadowRadius = 22.0;
    halo.layer.shadowOffset = CGSizeZero;
    halo.alpha = 0.0; // revealed by pp_startNovaFloatingHaloBreathing
    [self.view addSubview:halo];
    self.novaFloatingHaloView = halo;

    // Glass orb that hosts the Lottie. Continuous-curve circle with a hairline rim.
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.layer.cornerRadius = 28.0;
    button.clipsToBounds = NO;
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
    
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *con = [UIButtonConfiguration glassButtonConfiguration];
        con.baseBackgroundColor = AppClearClr;
        con.background.backgroundColor = AppClearClr;
        con.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        button.configuration = con;
    } else {
        button.backgroundColor = [brand colorWithAlphaComponent:0.10];
        button.layer.borderWidth = 1.0 / [UIScreen mainScreen].scale;
        button.layer.borderColor = [brand colorWithAlphaComponent:0.28].CGColor;

        button.layer.shadowOpacity = 0.22;
        button.layer.shadowRadius = 18.0;
        button.layer.shadowOffset = CGSizeMake(0, 8);
    }


    PPApplyCardShadow(button);
    button.layer.shadowColor = brand.CGColor;


    [button addTarget:self
               action:@selector(novaFloatingButtonTapped)
     forControlEvents:UIControlEventTouchUpInside];

    button.isAccessibilityElement = YES;
    button.accessibilityLabel = kLang(@"nova_chat_accessibility") ?: @"Chat with Nova";
    button.accessibilityTraits = UIAccessibilityTraitButton;

    [self.view addSubview:button];
    self.novaFloatingButton = button;

    LOTAnimationView *lot = [[LOTAnimationView alloc] init];
    lot.translatesAutoresizingMaskIntoConstraints = NO;
    lot.userInteractionEnabled = NO;
    lot.contentMode = UIViewContentModeScaleAspectFit;
    lot.loopAnimation = YES;
    lot.animationSpeed = 0.3;
    [button addSubview:lot];
    self.novaFloatingLottieView = lot;

    [NSLayoutConstraint activateConstraints:@[
        [button.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [button.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-PPSpaceBase],
        [button.widthAnchor constraintEqualToConstant:56.0],
        [button.heightAnchor constraintEqualToConstant:56.0],

        [halo.centerXAnchor constraintEqualToAnchor:button.centerXAnchor],
        [halo.centerYAnchor constraintEqualToAnchor:button.centerYAnchor],
        [halo.widthAnchor constraintEqualToConstant:0.0],
        [halo.heightAnchor constraintEqualToConstant:0.0],

        [lot.centerXAnchor constraintEqualToAnchor:button.centerXAnchor],
        [lot.centerYAnchor constraintEqualToAnchor:button.centerYAnchor],
        [lot.widthAnchor constraintEqualToConstant:42.0],
        [lot.heightAnchor constraintEqualToConstant:42.0],
    ]];

    // Lottie loads from Firebase Storage path LottieAnimations/nova.json via the project's helper.
    __weak typeof(self) weakSelf = self;
    __weak LOTAnimationView *weakLot = lot;
    [AppClasses setAnimationNamed:@"Ncolored"
                            ToView:lot
                         withSpeed:0.6
                        completion:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            LOTAnimationView *strongLot = weakLot;
            if (!strongSelf || !strongLot) {
                return;
            }
            if (success) {
                [strongLot play];
            } else {
                // Graceful fallback: use the original SF Symbol so the button never looks empty.
                strongLot.hidden = YES;
                UIImageSymbolConfiguration *iconConfig =
                    [UIImageSymbolConfiguration configurationWithPointSize:22.0
                                                                    weight:UIImageSymbolWeightSemibold];
                UIImage *icon = [UIImage systemImageNamed:@"wand.and.stars" withConfiguration:iconConfig];
                [strongSelf.novaFloatingButton setImage:icon forState:UIControlStateNormal];
                strongSelf.novaFloatingButton.tintColor = UIColor.whiteColor;
                strongSelf.novaFloatingButton.backgroundColor =
                    AppPrimaryClr ?: [UIColor colorWithRed:0.98 green:0.70 blue:0.42 alpha:1.0];
            }
        });
    }];

    [self pp_startNovaFloatingHaloBreathing];
}

- (void)pp_startNovaFloatingHaloBreathing
{
    UIView *halo = self.novaFloatingHaloView;
    if (!halo) { return; }

    [halo.layer removeAnimationForKey:@"pp_novaHaloBreath"];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        halo.alpha = 0.55;
        return;
    }

    halo.alpha = 0.65;

    CABasicAnimation *breath = [CABasicAnimation animationWithKeyPath:@"opacity"];
    breath.fromValue = @0.42;
    breath.toValue = @0.85;
    breath.duration = 5.2;
    breath.autoreverses = YES;
    breath.repeatCount = HUGE_VALF;
    breath.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [halo.layer addAnimation:breath forKey:@"pp_novaHaloBreath"];
}

- (void)pp_startNovaFloatingAmbientMotionIfNeeded
{
    if (!self.novaFloatingButton) {
        return;
    }

    if (self.novaFloatingHaloView.superview == self.view) {
        [self.view bringSubviewToFront:self.novaFloatingHaloView];
    }
    [self.view bringSubviewToFront:self.novaFloatingButton];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self pp_applyNovaFloatingReduceMotionState];
        return;
    }

    self.novaFloatingButton.alpha = 1.0;
    self.novaFloatingLottieView.alpha = 1.0;
    self.novaFloatingButton.transform = self.novaFloatingButtonScrollCompressed
        ? self.novaFloatingButton.transform
        : CGAffineTransformIdentity;

    if (!self.novaFloatingLottieView.hidden) {
        self.novaFloatingLottieView.animationSpeed = 0.6;
        [self.novaFloatingLottieView play];
    }
    [self pp_startNovaFloatingHaloBreathing];
}

- (void)pp_stopNovaFloatingMotion
{
    self.novaFloatingScrollMotionGeneration++;
    self.novaFloatingButtonScrollCompressed = NO;
    [self.novaFloatingButton.layer removeAllAnimations];
    [self.novaFloatingHaloView.layer removeAnimationForKey:@"pp_novaHaloBreath"];
    [self.novaFloatingHaloView.layer removeAnimationForKey:@"pp_novaHaloPulseScale"];
    [self.novaFloatingLottieView.layer removeAllAnimations];
    [self.novaFloatingLottieView stop];
    self.novaFloatingButton.transform = CGAffineTransformIdentity;
    self.novaFloatingButton.alpha = 1.0;
    self.novaFloatingLottieView.alpha = 1.0;
    self.novaFloatingHaloView.transform = CGAffineTransformIdentity;
    self.novaFloatingHaloView.alpha = 0.55;
}

- (void)pp_applyNovaFloatingReduceMotionState
{
    self.novaFloatingScrollMotionGeneration++;
    self.novaFloatingButtonScrollCompressed = NO;
    [self.novaFloatingButton.layer removeAllAnimations];
    [self.novaFloatingHaloView.layer removeAnimationForKey:@"pp_novaHaloBreath"];
    [self.novaFloatingHaloView.layer removeAnimationForKey:@"pp_novaHaloPulseScale"];
    [self.novaFloatingLottieView.layer removeAllAnimations];
    [self.novaFloatingLottieView stop];
    self.novaFloatingButton.transform = CGAffineTransformIdentity;
    self.novaFloatingButton.alpha = 1.0;
    self.novaFloatingLottieView.alpha = 1.0;
    self.novaFloatingHaloView.transform = CGAffineTransformIdentity;
    self.novaFloatingHaloView.alpha = 0.55;
}

- (void)pp_setNovaFloatingButtonScrollCompressed:(BOOL)compressed velocityY:(CGFloat)velocityY
{
    UIButton *button = self.novaFloatingButton;
    if (!button || button.hidden) {
        return;
    }

    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self pp_applyNovaFloatingReduceMotionState];
        return;
    }

    if (self.novaFloatingButtonScrollCompressed == compressed) {
        return;
    }

    self.novaFloatingButtonScrollCompressed = compressed;
    self.novaFloatingScrollMotionGeneration++;

    BOOL rtl = (PPHomeCurrentSemanticAttribute() == UISemanticContentAttributeForceRightToLeft);
    CGFloat outwardX = rtl ? -4.0 : 4.0;
    CGFloat fastScroll = MIN(1.0, fabs(velocityY) / 1400.0);
    CGFloat tuckY = 8.0 + (4.0 * fastScroll);
    CGFloat scale = 0.89 - (0.03 * fastScroll);
    CGAffineTransform buttonTransform = compressed
        ? CGAffineTransformScale(CGAffineTransformMakeTranslation(outwardX, tuckY), scale, scale)
        : CGAffineTransformIdentity;
    CGAffineTransform haloTransform = compressed
        ? CGAffineTransformScale(CGAffineTransformMakeTranslation(outwardX, tuckY), 0.72, 0.72)
        : CGAffineTransformIdentity;

    NSTimeInterval duration = compressed ? 0.26 : 0.46;
    CGFloat damping = compressed ? 0.98 : 0.78;
    CGFloat initialVelocity = compressed ? 0.12 : 0.42;
    [UIView animateWithDuration:duration
                          delay:0.0
         usingSpringWithDamping:damping
          initialSpringVelocity:initialVelocity
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        button.transform = buttonTransform;
        button.alpha = compressed ? 0.78 : 1.0;
        self.novaFloatingHaloView.transform = haloTransform;
        self.novaFloatingHaloView.alpha = compressed ? 0.24 : 0.65;
        self.novaFloatingLottieView.alpha = compressed ? 0.86 : 1.0;
    } completion:nil];

    self.novaFloatingLottieView.animationSpeed = compressed ? 0.38 : 0.6;
    if (!compressed && !self.novaFloatingLottieView.hidden) {
        [self.novaFloatingLottieView play];
    }
}

- (void)pp_scheduleNovaFloatingScrollSettle
{
    NSUInteger generation = ++self.novaFloatingScrollMotionGeneration;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.14 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || generation != self.novaFloatingScrollMotionGeneration) {
            return;
        }
        if (self.collectionView.isDragging || self.collectionView.isTracking || self.collectionView.isDecelerating) {
            return;
        }
        [self pp_setNovaFloatingButtonScrollCompressed:NO velocityY:0.0];
    });
}

- (void)pp_updateNovaFloatingButtonForScrollView:(UIScrollView *)scrollView
{
    if (scrollView != self.collectionView) {
        return;
    }
    BOOL activeScroll = scrollView.isTracking || scrollView.isDragging || scrollView.isDecelerating;
    if (activeScroll) {
        CGFloat velocityY = [scrollView.panGestureRecognizer velocityInView:self.view].y;
        [self pp_setNovaFloatingButtonScrollCompressed:YES velocityY:velocityY];
    } else {
        [self pp_scheduleNovaFloatingScrollSettle];
    }
}

- (void)novaFloatingButtonTapped
{
    [self pp_setNovaFloatingButtonScrollCompressed:NO velocityY:0.0];
    PPTapFeedbackDown(self.novaFloatingButton);

    UIImpactFeedbackGenerator *haptic =
        [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [haptic prepare];
    [haptic impactOccurred];

    if (!UIAccessibilityIsReduceMotionEnabled() && self.novaFloatingHaloView) {
        [self.novaFloatingHaloView.layer removeAnimationForKey:@"pp_novaHaloPulseScale"];
        CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        pulse.fromValue = @1.0;
        pulse.toValue = @1.18;
        pulse.duration = 0.28;
        pulse.autoreverses = YES;
        pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.novaFloatingHaloView.layer addAnimation:pulse forKey:@"pp_novaHaloPulseScale"];
    }

    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.14 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        PPTapFeedbackUp(self.novaFloatingButton);
    });

    [PPNovaChatViewController presentNovaFromViewController:self];
}

// 🔒 Validates Home Control config rows against the canonical PPHomeSection
// enum range, drops unknown/duplicate ids, and coerces the visible flag.
// This is the only entry point that should populate self.homeConfigSections.
- (NSArray<NSDictionary *> *)pp_sanitizedHomeConfigSections:(id)rawSections
{
    if (![rawSections isKindOfClass:NSArray.class]) {
        return @[];
    }

    NSArray *sectionsArray = (NSArray *)rawSections;
    NSMutableArray<NSDictionary *> *sanitized =
        [NSMutableArray arrayWithCapacity:sectionsArray.count];
    NSMutableSet<NSNumber *> *seenIDs = [NSMutableSet set];
    NSInteger maxKnownID = (NSInteger)PPHomeSectionPremiumSearch;

    for (id raw in sectionsArray) {
        if (![raw isKindOfClass:NSDictionary.class]) {
            continue;
        }
        NSDictionary *row = (NSDictionary *)raw;
        NSInteger sectionID = PPHomeSectionIDFromConfigValue(row[@"id"]);
        if (sectionID == NSNotFound) {
            sectionID = PPHomeSectionIDFromConfigValue(row[@"type"]);
        }
        if (sectionID == NSNotFound || sectionID < 0 || sectionID > maxKnownID) {
            NSLog(@"[HomeConfig] Dropping unknown section id %ld", (long)sectionID);
            continue;
        }
        NSNumber *boxedID = @(sectionID);
        if ([seenIDs containsObject:boxedID]) {
            NSLog(@"[HomeConfig] Dropping duplicate section id %ld", (long)sectionID);
            continue;
        }
        [seenIDs addObject:boxedID];

        BOOL visible = YES;
        id visibleValue = row[@"visible"];
        if ([visibleValue respondsToSelector:@selector(boolValue)]) {
            visible = [visibleValue boolValue];
        }

        id typeValue = row[@"type"];
        NSString *type = [typeValue isKindOfClass:NSString.class]
            ? (NSString *)typeValue
            : @"";

        [sanitized addObject:@{ @"id" : boxedID,
                                @"visible" : @(visible),
                                @"type" : type }];
    }

    return sanitized.copy;
}

- (void)pp_startHomeConfigListener {
    [self.homeConfigListener remove];

    FIRFirestore *db = AppMgr.dF ?: [FIRFirestore firestore];
    FIRDocumentReference *docRef = [[db collectionWithPath:@"AppConfigCol"] documentWithPath:@"HomeConfig"];

    [self pp_fetchHomeConfigFromServerOnceWithDocumentReference:docRef];

    __weak typeof(self) weakSelf = self;
    self.homeConfigListener =
        [docRef addSnapshotListenerWithIncludeMetadataChanges:YES
                                                     listener:^(FIRDocumentSnapshot * _Nullable snapshot,
                                                                NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        if (error) {
            NSLog(@"[HomeConfig] Listener error: %@", error.localizedDescription);
            return;
        }

        if (!snapshot) {
            NSLog(@"[HomeConfig] Listener returned an empty snapshot.");
            return;
        }

        NSString *source = snapshot.metadata.isFromCache ? @"listener-cache" : @"listener-server";
        [self pp_applyHomeConfigSnapshot:snapshot source:source];
    }];
}

- (void)pp_fetchHomeConfigFromServerOnceWithDocumentReference:(FIRDocumentReference *)docRef
{
    if (!docRef) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    [docRef getDocumentWithSource:FIRFirestoreSourceServer
                       completion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        if (error) {
            NSLog(@"[HomeConfig] Server fetch error: %@", error.localizedDescription);
            return;
        }

        if (!snapshot) {
            NSLog(@"[HomeConfig] Server fetch returned an empty snapshot.");
            return;
        }

        [self pp_applyHomeConfigSnapshot:snapshot source:@"server-fetch"];
    }];
}

- (void)pp_applyHomeConfigSnapshot:(FIRDocumentSnapshot *)snapshot source:(NSString *)source
{
    if (!snapshot.exists) {
        NSLog(@"[HomeConfig] %@ snapshot missing.", source ?: @"unknown");
        return;
    }

    NSDictionary *data = snapshot.data ?: @{};
    NSArray<NSDictionary *> *sanitized =
        [self pp_sanitizedHomeConfigSections:data[@"sections"]];

    NSString *remoteMode = data[@"titleViewMode"];
    NSString *resolvedTitleViewMode = @"location";
    if ([remoteMode isKindOfClass:NSString.class] &&
        ([remoteMode isEqualToString:@"location"] || [remoteMode isEqualToString:@"search"])) {
        resolvedTitleViewMode = remoteMode;
    }

    BOOL novaVisible = YES;
    id remoteNova = data[@"novaFloatingVisible"];
    if ([remoteNova respondsToSelector:@selector(boolValue)]) {
        novaVisible = [remoteNova boolValue];
    }

    BOOL novaUseGenkit = NO;
    id remoteNovaGenkit = data[@"novaUseGenkit"];
    if ([remoteNovaGenkit respondsToSelector:@selector(boolValue)]) {
        novaUseGenkit = [remoteNovaGenkit boolValue];
    }
    novaUseGenkit = YES;
    
    
    BOOL premiumCareVisible = YES;
    id remotePremiumCare = data[@"premiumCareVisible"];
    if ([remotePremiumCare respondsToSelector:@selector(boolValue)]) {
        premiumCareVisible = [remotePremiumCare boolValue];
    }

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        NSString *previousSignature = strongSelf.lastAppliedHomeConfigOrderSignature ?: @"";
        if (previousSignature.length == 0 && strongSelf.dataSource) {
            previousSignature =
                [strongSelf pp_homeConfigOrderSignatureForSectionIdentifiers:strongSelf.dataSource.snapshot.sectionIdentifiers];
        }

        [[NSNotificationCenter defaultCenter] postNotificationName:PPNovaFloatingVisibilityDidChangeNotification
                                                            object:strongSelf
                                                          userInfo:@{ PPNovaFloatingVisibilityValueKey : @(novaVisible) }];

        strongSelf.homePremiumCareVisible = premiumCareVisible;

        NSArray<NSDictionary *> *merged =
            [strongSelf pp_resolvedHomeConfigSectionsFromSanitizedSections:sanitized
                                                    legacyPremiumCareVisible:premiumCareVisible];
        strongSelf.homeConfigSections = merged;
        [strongSelf pp_cacheHomeConfigSections:merged
                                 titleViewMode:resolvedTitleViewMode
                            premiumCareVisible:premiumCareVisible
                           novaFloatingVisible:novaVisible
                                 novaUseGenkit:novaUseGenkit];

        NSArray<NSNumber *> *nextIdentifiers = [strongSelf pp_orderedHomeSectionIdentifiers];
        NSString *nextSignature =
            [strongSelf pp_homeConfigOrderSignatureForSectionIdentifiers:nextIdentifiers];
        BOOL orderChanged =
            previousSignature.length > 0 &&
            nextSignature.length > 0 &&
            ![previousSignature isEqualToString:nextSignature];

        strongSelf.lastAppliedHomeConfigOrderSignature = nextSignature;
        strongSelf.shouldResetHomeScrollForConfigOrderChange = orderChanged;

        NSLog(@"[HomeConfig] Applied %@ section order: %@ changed=%@",
              source ?: @"unknown",
              nextSignature ?: @"",
              orderChanged ? @"YES" : @"NO");

        strongSelf.didReceiveHomeConfig = YES;

        BOOL titleModeChanged =
            ![(strongSelf.homeTitleViewMode ?: @"location") isEqualToString:resolvedTitleViewMode];
        strongSelf.homeTitleViewMode = resolvedTitleViewMode;

        [strongSelf applyBaseSnapshot];

        // HomeConfig can add/remove the carousel section; keep its payload current.
        [strongSelf fillCarouselBanner];

        BOOL expectsSearchTitle =
            [resolvedTitleViewMode isEqualToString:@"search"];
        BOOL showingSearchTitle =
            strongSelf.homeSmartSearchView &&
            strongSelf.navigationItem.titleView == strongSelf.homeSmartSearchView;
        BOOL showingLocationTitle =
            strongSelf.homeLocationTitleView &&
            strongSelf.navigationItem.titleView == strongSelf.homeLocationTitleView;
        BOOL titleViewMatchesConfig =
            expectsSearchTitle ? showingSearchTitle : showingLocationTitle;

        if (titleModeChanged || !titleViewMatchesConfig) {
            if ([strongSelf pp_canOwnHomeNavigationChrome]) {
                [strongSelf configureNavigationBar];
            } else {
                [strongSelf pp_detachHomeSmartSearchTitleViewIfNeeded];
                [strongSelf pp_detachHomeLocationTitleViewIfNeeded];
            }
        } else if (expectsSearchTitle) {
            [strongSelf pp_updateHomeSmartSearchTitleViewWidth];
            [strongSelf pp_updateHomeSmartSearchPlaceholderAnimated:NO];
            [strongSelf pp_startHomeSmartSearchTimerIfNeeded];
        } else {
            [strongSelf pp_refreshHomeLocationTitleViewAnimated:NO];
            [strongSelf.homeLocationTitleView startLivingMotion];
        }
    });
}

- (void)handleBrowseHistoryUpdate

{
    [self reloadSection:PPHomeSectionSuggestions];
}

- (void)pp_refreshNavigationMenusForCurrentUser {
    UIBarButtonItem *profileItem = self.homeProfileItem
        ?: self.navigationItem.leftBarButtonItems.firstObject
        ?: self.navigationItem.leftBarButtonItem;
    UIView *customView = profileItem.customView;
    UIButton *profileButton = nil;
    if ([customView isKindOfClass:UIButton.class]) {
        profileButton = (UIButton *)customView;
    } else {
        UIView *tagged = [customView viewWithTag:8801];
        if ([tagged isKindOfClass:UIButton.class]) {
            profileButton = (UIButton *)tagged;
        }
    }
    PPHomePrepareProfileMenuButton(profileButton);
}

- (void)handleUserProfileSyncNotification:(NSNotification *)notification
{
    (void)notification;
    [self pp_refreshNavigationMenusForCurrentUser];
    [self refreshHeroSectionAppearance];
    [self refreshCurrentOrdersForce:YES];
    [self pp_refreshPetProfilesSection];
}

- (void)handleUserAccessUpdateNotification:(NSNotification *)notification
{
    (void)notification;
    UIBarButtonItem *profileItem = [self pp_buildProfileBarButtonItem];
    self.homeProfileItem = profileItem;
    NSInteger cartCount = [CartManager.sharedManager totalItemsCount];
    self.navigationItem.leftBarButtonItems  = PPHomeBarButtonItems(profileItem);
    [self refreshNavigationRightItemsForCartCount:cartCount];
    [self pp_refreshNavigationMenusForCurrentUser];
}

- (NSString *)pp_currentOrdersUserID
{
    NSString *userID = @"";
    id value = UserManager.sharedManager.currentUser.ID;
    if ([value isKindOfClass:NSString.class]) {
        userID = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    if (userID.length == 0) {
        userID = [FIRAuth auth].currentUser.uid ?: @"";
    }
    return userID;
}

- (BOOL)pp_homeStatusKey:(NSString *)statusKey matchesAnyKeywords:(NSArray<NSString *> *)keywords
{
    NSString *normalizedStatus = [PPOrder normalizedStatusFromRawValue:statusKey];
    if (normalizedStatus.length == 0 || keywords.count == 0) {
        return NO;
    }

    NSString *wrappedStatus = [NSString stringWithFormat:@"_%@_", normalizedStatus];
    for (NSString *keyword in keywords) {
        NSString *normalizedKeyword = [PPOrder normalizedStatusFromRawValue:keyword];
        if (normalizedKeyword.length == 0) {
            continue;
        }
        NSString *wrappedKeyword = [NSString stringWithFormat:@"_%@_", normalizedKeyword];
        if ([wrappedStatus containsString:wrappedKeyword]) {
            return YES;
        }
    }

    return NO;
}

- (BOOL)pp_isFailureHomeOrderStatusKey:(NSString *)statusKey
{
    return [self pp_homeStatusKey:statusKey
                 matchesAnyKeywords:@[@"delivery_cancelled", @"delivery_delayed", @"failed", @"rejected", @"cancelled", @"canceled", @"expired", @"voided", @"error"]];
}

- (NSString *)pp_homeOrderStatusKey:(PPOrder *)order
{
    if (![order isKindOfClass:PPOrder.class]) {
        return @"preparing_for_shipment";
    }
    NSString *statusKey = [PPOrder normalizedStatusFromRawValue:[order customerVisibleStatusKey]];
    return statusKey.length > 0 ? statusKey : @"preparing_for_shipment";
}

- (BOOL)pp_isActiveHomeOrder:(PPOrder *)order
{
    if (![order isKindOfClass:PPOrder.class]) {
        return NO;
    }

    NSString *statusKey = [self pp_homeOrderStatusKey:order];
    if ([self pp_isFailureHomeOrderStatusKey:statusKey]) {
        return NO;
    }
    if ([self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"delivered", @"completed"]]) {
        return NO;
    }

    return [self pp_homeStatusKey:statusKey
                 matchesAnyKeywords:@[@"preparing_for_shipment",
                                      @"ready_for_delivery",
                                      @"delivery_partner_assigned",
                                      @"on_the_way"]];
}

- (NSString *)pp_homeOrderStatusTitle:(PPOrder *)order
{
    NSString *statusKey = [self pp_homeOrderStatusKey:order];
    if ([statusKey isEqualToString:@"ready_for_delivery"]) {
        return kLang(@"Ready for Delivery");
    }
    if ([statusKey isEqualToString:@"delivery_partner_assigned"]) {
        return kLang(@"Delivery Partner Assigned");
    }
    if ([statusKey isEqualToString:@"on_the_way"]) {
        return kLang(@"On the Way");
    }
    if ([statusKey isEqualToString:@"delivered"]) {
        return kLang(@"Delivered");
    }
    if ([statusKey isEqualToString:@"completed"]) {
        return kLang(@"Completed");
    }
    if ([statusKey isEqualToString:@"delivery_cancelled"]) {
        return kLang(@"Delivery Cancelled");
    }
    if ([statusKey isEqualToString:@"delivery_delayed"]) {
        return kLang(@"Delivery Delayed");
    }
    return kLang(@"Preparing for Shipment");
}

- (NSString *)pp_homeOrderStatusHint:(PPOrder *)order
{
    NSString *statusKey = [self pp_homeOrderStatusKey:order];
    if ([statusKey isEqualToString:@"ready_for_delivery"]) {
        return kLang(@"Home_CurrentOrdersReadyHint") ?: (kLang(@"order_action_track_hint") ?: @"");
    }
    if ([statusKey isEqualToString:@"delivery_partner_assigned"]) {
        return kLang(@"Home_CurrentOrdersAssignedHint") ?: (kLang(@"order_action_track_hint") ?: @"");
    }
    if ([statusKey isEqualToString:@"on_the_way"]) {
        return kLang(@"Home_CurrentOrdersShippedHint") ?: (kLang(@"order_action_track_hint") ?: @"");
    }
    if ([statusKey isEqualToString:@"delivered"]) {
        return kLang(@"Home_CurrentOrdersDeliveredHint") ?: (kLang(@"order_action_track_hint") ?: @"");
    }
    if ([statusKey isEqualToString:@"completed"]) {
        return kLang(@"Home_CurrentOrdersCompletedHint") ?: (kLang(@"order_action_track_hint") ?: @"");
    }
    if ([statusKey isEqualToString:@"delivery_cancelled"]) {
        return kLang(@"Home_CurrentOrdersCancelledHint") ?: (kLang(@"order_action_track_hint") ?: @"");
    }
    if ([statusKey isEqualToString:@"delivery_delayed"]) {
        return kLang(@"Home_CurrentOrdersDelayedHint") ?: (kLang(@"order_action_track_hint") ?: @"");
    }
    if ([statusKey isEqualToString:@"preparing_for_shipment"]) {
        return kLang(@"Home_CurrentOrdersProcessingHint") ?: (kLang(@"order_action_track_hint") ?: @"");
    }
    return kLang(@"Home_CurrentOrdersPendingHint") ?: (kLang(@"order_action_track_hint") ?: @"");
}

- (UIColor *)pp_homeOrderStatusColor:(PPOrder *)order
{
    NSString *statusKey = [self pp_homeOrderStatusKey:order];
    if ([statusKey isEqualToString:@"delivery_cancelled"]) {
        return UIColor.systemRedColor;
    }
    if ([statusKey isEqualToString:@"delivery_delayed"]) {
        return UIColor.systemOrangeColor;
    }
    if ([statusKey isEqualToString:@"completed"]) {
        return [GM appPrimaryColor];
    }
    if ([statusKey isEqualToString:@"delivered"]) {
        return UIColor.systemGreenColor;
    }
    if ([statusKey isEqualToString:@"on_the_way"]) {
        return UIColor.systemBlueColor;
    }
    if ([statusKey isEqualToString:@"ready_for_delivery"] ||
        [statusKey isEqualToString:@"delivery_partner_assigned"]) {
        if (@available(iOS 13.0, *)) {
            return UIColor.systemIndigoColor;
        }
        return [UIColor colorWithRed:0.35 green:0.45 blue:0.94 alpha:1.0];
    }
    return UIColor.systemOrangeColor;
}

- (NSString *)pp_homeOrderStatusIconName:(PPOrder *)order
{
    NSString *statusKey = [self pp_homeOrderStatusKey:order];
    if ([statusKey isEqualToString:@"delivery_cancelled"]) {
        return @"xmark.circle.fill";
    }
    if ([statusKey isEqualToString:@"delivery_delayed"]) {
        return @"exclamationmark.triangle.fill";
    }
    if ([statusKey isEqualToString:@"completed"]) {
        return @"checkmark.seal.fill";
    }
    if ([statusKey isEqualToString:@"delivered"]) {
        return @"checkmark.circle.fill";
    }
    if ([statusKey isEqualToString:@"on_the_way"]) {
        return @"shippedtruck";
    }
    if ([statusKey isEqualToString:@"ready_for_delivery"]) {
        return @"shippingbox.fill";
    }
    if ([statusKey isEqualToString:@"delivery_partner_assigned"]) {
        return @"person.crop.circle.fill";
    }
    if ([statusKey isEqualToString:@"preparing_for_shipment"]) {
        return @"shippingbox.circle.fill";
    }
    return @"clock.fill";
}

- (double)pp_homeOrderProgress:(PPOrder *)order
{
    NSString *statusKey = [self pp_homeOrderStatusKey:order];
    if ([self pp_isFailureHomeOrderStatusKey:statusKey]) {
        return 1.0;
    }
    if ([statusKey isEqualToString:@"completed"]) {
        return 1.0;
    }
    if ([statusKey isEqualToString:@"delivered"]) {
        return 0.94;
    }
    if ([statusKey isEqualToString:@"on_the_way"]) {
        return 0.86;
    }
    if ([statusKey isEqualToString:@"delivery_partner_assigned"]) {
        return 0.62;
    }
    if ([statusKey isEqualToString:@"ready_for_delivery"]) {
        return 0.46;
    }
    if ([statusKey isEqualToString:@"preparing_for_shipment"]) {
        return 0.28;
    }
    return 0.16;
}

- (NSInteger)pp_homeOrderItemCount:(PPOrder *)order
{
    NSInteger totalCount = 0;
    for (id rawItem in order.items ?: @[]) {
        if ([rawItem isKindOfClass:NSDictionary.class]) {
            NSDictionary *item = (NSDictionary *)rawItem;
            id rawQty = item[@"qty"] ?: item[@"quantity"];
            NSInteger quantity = [rawQty respondsToSelector:@selector(integerValue)] ? [rawQty integerValue] : 1;
            totalCount += MAX(quantity, 1);
        } else {
            totalCount += 1;
        }
    }
    return MAX(totalCount, 0);
}

- (NSString *)pp_homeOrderAmountText:(PPOrder *)order
{
    double total = order.totalAmount;
    if (total <= 0.0) {
        total = order.amount;
    }
    if (total <= 0.0 && order.shippingFee > 0.0) {
        total = order.shippingFee;
    }
    if (total <= 0.0) {
        return @"";
    }

    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    formatter.currencyCode = order.currency.length > 0 ? order.currency : @"QAR";
    formatter.maximumFractionDigits = 2;
    formatter.minimumFractionDigits = 0;
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en"];

    NSString *formattedAmount = [PPChatsFunc pp_forceLatinDigits:[formatter stringFromNumber:@(total)] ?: @""];
    if (formattedAmount.length > 0) {
        return formattedAmount;
    }

    return [NSString stringWithFormat:@"%@ %.2f",
            order.currency.length > 0 ? order.currency : @"QAR",
            total];
}

- (NSString *)pp_homeOrderMetaText:(PPOrder *)order
{
    NSMutableArray<NSString *> *parts = [NSMutableArray array];

    NSInteger itemCount = [self pp_homeOrderItemCount:order];
    if (itemCount > 0) {
        NSString *itemsFormat = kLang(@"Home_CurrentOrdersItemsFormat") ?: @"%ld items";
        [parts addObject:[NSString stringWithFormat:itemsFormat, (long)itemCount]];
    }

    NSString *amountText = [self pp_homeOrderAmountText:order];
    if (amountText.length > 0) {
        [parts addObject:amountText];
    }

    return [parts componentsJoinedByString:@" | "];
}

- (NSString *)pp_homeRelativeDateString:(NSDate *)date
{
    if (![date isKindOfClass:NSDate.class]) {
        return @"";
    }

    if (@available(iOS 13.0, *)) {
        NSRelativeDateTimeFormatter *formatter = [[NSRelativeDateTimeFormatter alloc] init];
        formatter.unitsStyle = NSRelativeDateTimeFormatterUnitsStyleShort;
        formatter.locale = Language.isRTL
            ? [NSLocale localeWithLocaleIdentifier:@"ar"]
            : [NSLocale localeWithLocaleIdentifier:@"en"];
        return [formatter localizedStringForDate:date relativeToDate:[NSDate date]] ?: @"";
    }

    return [self pp_homeShortDateString:date];
}

- (NSString *)pp_homeShortDateString:(NSDate *)date
{
    if (![date isKindOfClass:NSDate.class]) {
        return @"";
    }

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = NSDateFormatterNoStyle;
    formatter.locale = Language.isRTL
        ? [NSLocale localeWithLocaleIdentifier:@"ar"]
        : [NSLocale localeWithLocaleIdentifier:@"en"];
    return [formatter stringFromDate:date] ?: @"";
}

- (NSString *)pp_homeOrderFooterText:(PPOrder *)order
{
    NSDate *estimatedDate = order.estimatedDeliveryAt;
    if ([estimatedDate isKindOfClass:NSDate.class]) {
        NSString *dateText = [self pp_homeShortDateString:estimatedDate];
        if (dateText.length > 0) {
            return [NSString stringWithFormat:@"%@ %@",
                    kLang(@"Home_CurrentOrdersExpectedPrefix") ?: @"Expected",
                    dateText];
        }
    }

    NSDate *updatedDate = order.statusUpdatedAt ?: order.updatedAt ?: order.createdAt;
    NSString *relativeDate = [self pp_homeRelativeDateString:updatedDate];
    if (relativeDate.length > 0) {
        return [NSString stringWithFormat:@"%@ %@",
                kLang(@"Home_CurrentOrdersUpdatedPrefix") ?: @"Updated",
                relativeDate];
    }

    return kLang(@"order_action_track_hint") ?: @"";
}

- (NSString *)pp_homeOrderKickerTitle:(PPOrder *)order
{
    if ([self pp_isActiveHomeOrder:order]) {
        return kLang(@"Home_CurrentOrdersTitle") ?: @"Active order";
    }

    return kLang(@"Home_LastOrderTitle") ?: @"Last order";
}

- (NSString *)pp_homeOrderImageURLFromItemData:(NSDictionary *)data
{
    if (![data isKindOfClass:NSDictionary.class]) {
        return @"";
    }

    NSArray<NSString *> *valueKeys = @[@"image", @"imageURL", @"imageUrl", @"photo", @"icon"];
    for (NSString *key in valueKeys) {
        NSString *value = PPSafeString(data[key]);
        value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (value.length > 0) {
            return value;
        }
    }

    NSArray<NSString *> *arrayKeys = @[@"imageURLsArray", @"imageURLs", @"images"];
    for (NSString *key in arrayKeys) {
        id rawValue = data[key];
        if (![rawValue isKindOfClass:NSArray.class]) {
            continue;
        }

        for (id item in (NSArray *)rawValue) {
            NSString *value = PPSafeString(item);
            value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (value.length > 0) {
                return value;
            }
        }
    }

    return @"";
}

- (NSArray<NSString *> *)pp_homeOrderPreviewImageURLs:(PPOrder *)order limit:(NSInteger)limit
{
    if (![order isKindOfClass:PPOrder.class] || limit == 0) {
        return @[];
    }

    NSMutableDictionary<NSString *, PetAccessory *> *resolvedByID = [NSMutableDictionary dictionary];
    for (PetAccessory *accessory in self.accessories ?: @[]) {
        if (![accessory isKindOfClass:PetAccessory.class]) {
            continue;
        }

        NSString *accessoryID = PPSafeString(accessory.accessoryID);
        accessoryID = [accessoryID stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (accessoryID.length == 0) {
            continue;
        }

        resolvedByID[accessoryID] = accessory;
    }

    NSInteger cappedLimit = MAX(limit, 0);
    NSMutableOrderedSet<NSString *> *orderedURLs = [NSMutableOrderedSet orderedSet];
    for (id rawItem in order.items ?: @[]) {
        NSString *imageURL = @"";
        if ([rawItem isKindOfClass:NSDictionary.class]) {
            NSDictionary *itemData = (NSDictionary *)rawItem;
            imageURL = [self pp_homeOrderImageURLFromItemData:itemData];

            if (imageURL.length == 0) {
                NSDictionary *nestedItemData =
                    [itemData[@"product"] isKindOfClass:NSDictionary.class] ? itemData[@"product"] :
                    ([itemData[@"item"] isKindOfClass:NSDictionary.class] ? itemData[@"item"] : nil);
                if (nestedItemData) {
                    imageURL = [self pp_homeOrderImageURLFromItemData:nestedItemData];
                }
            }
        }

        if (imageURL.length == 0) {
            NSString *itemID = [self pp_homeOrderItemIdentifier:rawItem];
            PetAccessory *accessory = resolvedByID[itemID];
            if ([accessory isKindOfClass:PetAccessory.class] &&
                [accessory.imageURLsArray isKindOfClass:NSArray.class] &&
                accessory.imageURLsArray.count > 0) {
                imageURL = PPSafeString(accessory.imageURLsArray.firstObject);
            }
        }

        imageURL = [imageURL stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (imageURL.length == 0 || [orderedURLs containsObject:imageURL]) {
            continue;
        }

        [orderedURLs addObject:imageURL];
        if (cappedLimit > 0 && orderedURLs.count >= cappedLimit) {
            break;
        }
    }

    return orderedURLs.array;
}

- (BOOL)pp_hasOtherRecentHomeOrdersWithinInterval:(NSTimeInterval)interval excludingOrder:(PPOrder *)order
{
    NSString *excludedOrderID = [order isKindOfClass:PPOrder.class] ? PPSafeString(order.orderId) : @"";
    NSDate *now = [NSDate date];

    for (PPOrder *candidate in self.recentOrders ?: @[]) {
        if (![candidate isKindOfClass:PPOrder.class]) {
            continue;
        }

        NSString *candidateOrderID = PPSafeString(candidate.orderId);
        if (excludedOrderID.length > 0 && [candidateOrderID isEqualToString:excludedOrderID]) {
            continue;
        }

        NSDate *activityDate = candidate.statusUpdatedAt ?: candidate.updatedAt ?: candidate.createdAt;
        if (![activityDate isKindOfClass:NSDate.class]) {
            continue;
        }

        NSTimeInterval elapsed = [now timeIntervalSinceDate:activityDate];
        if (elapsed <= interval) {
            return YES;
        }
    }

    return NO;
}

- (NSString *)pp_completedLastHomeOrderSeenOrderIDDefaultsKey
{
    NSString *userID = [self pp_currentOrdersUserID];
    if (userID.length == 0) {
        return PPHomeCompletedLastOrderSeenOrderIDKeyPrefix;
    }
    return [NSString stringWithFormat:@"%@.%@", PPHomeCompletedLastOrderSeenOrderIDKeyPrefix, userID];
}

- (NSString *)pp_completedLastHomeOrderSeenSessionDefaultsKey
{
    NSString *userID = [self pp_currentOrdersUserID];
    if (userID.length == 0) {
        return PPHomeCompletedLastOrderSeenSessionIDKeyPrefix;
    }
    return [NSString stringWithFormat:@"%@.%@", PPHomeCompletedLastOrderSeenSessionIDKeyPrefix, userID];
}

- (BOOL)pp_shouldHideCompletedLastHomeOrder:(PPOrder *)order
{
    if (![order isKindOfClass:PPOrder.class]) {
        return YES;
    }

    NSString *statusKey = [self pp_homeOrderStatusKey:order];
    if (![self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"delivered", @"completed", @"fulfilled"]]) {
        return NO;
    }

    NSDate *completedDate = order.statusUpdatedAt ?: order.updatedAt ?: order.createdAt;
    if (![completedDate isKindOfClass:NSDate.class]) {
        return NO;
    }

    NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:completedDate];
    if (elapsed > PPHomeCompletedLastOrderVisibilityInterval) {
        return YES;
    }

    BOOL hasOtherRecentOrders =
        [self pp_hasOtherRecentHomeOrdersWithinInterval:PPHomeOtherOrdersRecentLookbackInterval
                                         excludingOrder:order];
    if (hasOtherRecentOrders) {
        return NO;
    }

    NSString *orderID = PPSafeString(order.orderId);
    if (orderID.length == 0) {
        return NO;
    }

    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *storedOrderID = [defaults stringForKey:[self pp_completedLastHomeOrderSeenOrderIDDefaultsKey]] ?: @"";
    NSString *storedSessionID = [defaults stringForKey:[self pp_completedLastHomeOrderSeenSessionDefaultsKey]] ?: @"";
    NSString *currentSessionID = PPHomeCurrentAppSessionIdentifier();

    BOOL wasShownInPreviousLaunch =
        [storedOrderID isEqualToString:orderID] &&
        storedSessionID.length > 0 &&
        ![storedSessionID isEqualToString:currentSessionID];
    if (wasShownInPreviousLaunch) {
        return YES;
    }

    [defaults setObject:orderID forKey:[self pp_completedLastHomeOrderSeenOrderIDDefaultsKey]];
    [defaults setObject:currentSessionID forKey:[self pp_completedLastHomeOrderSeenSessionDefaultsKey]];
    return NO;
}

- (BOOL)pp_isTerminalHomeOrderStatusKey:(NSString *)statusKey
{
    return [self pp_homeStatusKey:statusKey matchesAnyKeywords:@[@"completed"]]
        || [self pp_isFailureHomeOrderStatusKey:statusKey];
}

- (NSString *)pp_terminalHomeOrderSeenOrderIDDefaultsKey
{
    NSString *userID = [self pp_currentOrdersUserID];
    if (userID.length == 0) {
        return PPHomeTerminalOrderSeenOrderIDKeyPrefix;
    }
    return [NSString stringWithFormat:@"%@.%@", PPHomeTerminalOrderSeenOrderIDKeyPrefix, userID];
}

- (NSString *)pp_terminalHomeOrderSeenSessionDefaultsKey
{
    NSString *userID = [self pp_currentOrdersUserID];
    if (userID.length == 0) {
        return PPHomeTerminalOrderSeenSessionIDKeyPrefix;
    }
    return [NSString stringWithFormat:@"%@.%@", PPHomeTerminalOrderSeenSessionIDKeyPrefix, userID];
}

- (BOOL)pp_shouldHideTerminalHomeOrder:(PPOrder *)order
{
    if (![order isKindOfClass:PPOrder.class]) {
        return NO;
    }

    NSString *statusKey = [self pp_homeOrderStatusKey:order];
    if (![self pp_isTerminalHomeOrderStatusKey:statusKey]) {
        return NO;
    }

    NSString *orderID = PPSafeString(order.orderId);
    if (orderID.length == 0) {
        return NO;
    }

    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *storedOrderID = [defaults stringForKey:[self pp_terminalHomeOrderSeenOrderIDDefaultsKey]] ?: @"";
    NSString *storedSessionID = [defaults stringForKey:[self pp_terminalHomeOrderSeenSessionDefaultsKey]] ?: @"";
    NSString *currentSessionID = PPHomeCurrentAppSessionIdentifier();

    BOOL wasShownInPreviousLaunch =
        [storedOrderID isEqualToString:orderID] &&
        storedSessionID.length > 0 &&
        ![storedSessionID isEqualToString:currentSessionID];
    if (wasShownInPreviousLaunch) {
        return YES;
    }

    [defaults setObject:orderID forKey:[self pp_terminalHomeOrderSeenOrderIDDefaultsKey]];
    [defaults setObject:currentSessionID forKey:[self pp_terminalHomeOrderSeenSessionDefaultsKey]];
    return NO;
}

- (nullable PPOrder *)pp_featuredHomeOrder
{
    id activeOrder = self.currentOrders.firstObject;
    if ([activeOrder isKindOfClass:PPOrder.class]) {
        PPOrder *order = (PPOrder *)activeOrder;

        if ([self pp_shouldHideTerminalHomeOrder:order]) {
            return nil;
        }

        if ([self pp_isActiveHomeOrder:order]) {
            return order;
        }

        NSDate *createdDate = order.createdAt ?: order.updatedAt;
        if ([createdDate isKindOfClass:NSDate.class]) {
            NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:createdDate];
            if (elapsed <= PPHomeCompletedLastOrderVisibilityInterval) {
                return order;
            }
        }
    }

    return nil;
}

- (NSArray<PPHomeItem *> *)pp_homeCurrentOrderItems
{
    NSMutableArray<PPHomeItem *> *items = [NSMutableArray array];
    PPOrder *featuredOrder = [self pp_featuredHomeOrder];

    if (self.currentOrdersLoading && !featuredOrder) {
        PPHomeItem *placeholderItem =
            [[PPHomeItem alloc] initWithType:PPHomeItemTypeCurrentOrder payload:[NSNull null]];
        [items addObject:placeholderItem];
        return items.copy;
    }

    if (featuredOrder) {
        PPHomeItem *item =
            [[PPHomeItem alloc] initWithType:PPHomeItemTypeCurrentOrder payload:featuredOrder];
        [items addObject:item];
    }

    return items.copy;
}

- (NSArray<PPHomeItem *> *)pp_homeBuyAgainItems
{
    NSMutableArray<PPHomeItem *> *items = [NSMutableArray array];

    for (id entry in self.buyAgainEntries ?: @[]) {
        PPUniversalCellViewModel *vm = nil;
        if ([entry isKindOfClass:PetAccessory.class]) {
            PetAccessory *accessory = (PetAccessory *)entry;
            PPCellContext context = accessory.accessKindType == AccessTypeFood ? PPCellForFood : PPCellForMarket;
            vm = [[PPUniversalCellViewModel alloc] initWithModel:accessory
                                                         context:context];
            vm.ModelObject = accessory;
        } else if ([entry isKindOfClass:PPHomeBuyAgainSnapshotItem.class]) {
            PPHomeBuyAgainSnapshotItem *snapshotItem = (PPHomeBuyAgainSnapshotItem *)entry;
            PPCellContext context = snapshotItem.accessKindType == AccessTypeFood ? PPCellForFood : PPCellForMarket;
            vm = [[PPUniversalCellViewModel alloc] initWithModel:nil
                                                         context:context];
            vm.ModelID = snapshotItem.itemID.length > 0 ? snapshotItem.itemID : [NSUUID UUID].UUIDString;
            vm.ModelObject = snapshotItem;
            vm.modelContext = context;
            vm.title = snapshotItem.title.length > 0 ? snapshotItem.title : (kLang(@"Home_BuyAgainUnavailableFallbackTitle") ?: @"");
            vm.subtitle = kLang(@"Home_BuyAgainUnavailableSubtitle") ?: @"";
            vm.imageURL = snapshotItem.imageURL;
            vm.availabilityText = kLang(@"Home_BuyAgainUnavailableBadge") ?: @"";
            vm.badgeText = vm.availabilityText;
            vm.contextualReasonText = vm.availabilityText;
            vm.contextualReasonIconName = @"exclamationmark.circle.fill";
            vm.priceText = @"";
            vm.preferredAspectRatio = 0.78;
            vm.imageSize = CGSizeMake(1.0, 0.78);
        }

        if (!vm) {
            continue;
        }

        PPHomeItem *item =
            [[PPHomeItem alloc] initWithType:PPHomeItemTypeBuyAgain
                               universalModel:vm];
        [items addObject:item];
    }

    return items.copy;
}

- (NSString *)pp_buyAgainStringFromValue:(id)value
{
    if ([value isKindOfClass:NSString.class]) {
        return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    if ([value respondsToSelector:@selector(stringValue)]) {
        return [[value stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    return @"";
}

- (NSInteger)pp_buyAgainIntegerFromValue:(id)value fallback:(NSInteger)fallback
{
    if ([value respondsToSelector:@selector(integerValue)]) {
        return [value integerValue];
    }
    return fallback;
}

- (id)pp_buyAgainValueForKeys:(NSArray<NSString *> *)keys rawItem:(id)rawItem
{
    if (![rawItem isKindOfClass:NSDictionary.class]) {
        return nil;
    }

    NSDictionary *item = (NSDictionary *)rawItem;
    for (NSString *key in keys) {
        id value = item[key];
        if (value && ![value isKindOfClass:NSNull.class]) {
            return value;
        }
    }

    NSArray<NSString *> *nestedKeys = @[@"product", @"item", @"accessory", @"snapshot"];
    for (NSString *nestedKey in nestedKeys) {
        NSDictionary *nested = [item[nestedKey] isKindOfClass:NSDictionary.class] ? item[nestedKey] : nil;
        if (!nested) {
            continue;
        }
        for (NSString *key in keys) {
            id value = nested[key];
            if (value && ![value isKindOfClass:NSNull.class]) {
                return value;
            }
        }
    }

    return nil;
}

- (NSInteger)pp_buyAgainAccessKindTypeFromRawItem:(id)rawItem
{
    id value = [self pp_buyAgainValueForKeys:@[@"accessKindType",
                                               @"itemSection",
                                               @"section",
                                               @"ppDataSection",
                                               @"dataSection",
                                               @"type"]
                                      rawItem:rawItem];
    NSInteger numericValue = [self pp_buyAgainIntegerFromValue:value fallback:0];
    if (numericValue > 0) {
        return numericValue;
    }

    NSString *section = [[self pp_buyAgainStringFromValue:value] lowercaseString];
    if ([section containsString:@"food"]) {
        return AccessTypeFood;
    }
    if ([section containsString:@"medicine"] || [section containsString:@"pharmacy"]) {
        return AccessTypePetMedicine;
    }
    if ([section containsString:@"live"]) {
        return AccessTypeLivePet;
    }
    return AccessTypeAccessory;
}

- (PPHomeBuyAgainSnapshotItem *)pp_buyAgainSnapshotItemFromRawOrderItem:(id)rawItem
{
    NSString *itemID = [self pp_homeOrderItemIdentifier:rawItem];
    if (itemID.length == 0) {
        return nil;
    }

    PPHomeBuyAgainSnapshotItem *snapshotItem = [PPHomeBuyAgainSnapshotItem new];
    snapshotItem.itemID = itemID;
    snapshotItem.title = [self pp_buyAgainStringFromValue:
                          [self pp_buyAgainValueForKeys:@[@"name",
                                                          @"title",
                                                          @"itemName",
                                                          @"productName"]
                                                 rawItem:rawItem]];
    NSString *imageURL = [self pp_buyAgainStringFromValue:
                          [self pp_buyAgainValueForKeys:@[@"imageURL",
                                                          @"imageUrl",
                                                          @"image",
                                                          @"photo",
                                                          @"icon"]
                                                 rawItem:rawItem]];
    if (imageURL.length == 0) {
        imageURL = [self pp_homeOrderImageURLFromItemData:
                    [rawItem isKindOfClass:NSDictionary.class] ? (NSDictionary *)rawItem : @{}];
    }
    snapshotItem.imageURL = imageURL;
    snapshotItem.mainKindID = [self pp_buyAgainIntegerFromValue:
                               [self pp_buyAgainValueForKeys:@[@"petMainCategoryID",
                                                               @"mainKindID",
                                                               @"mainKindId",
                                                               @"mainKind",
                                                               @"categoryID",
                                                               @"categoryId",
                                                               @"category"]
                                                      rawItem:rawItem]
                                                     fallback:0];
    snapshotItem.accessKindType = [self pp_buyAgainAccessKindTypeFromRawItem:rawItem];
    return snapshotItem;
}

- (NSArray<PPHomeBuyAgainSnapshotItem *> *)pp_buyAgainSnapshotItemsFromOrders:(NSArray<PPOrder *> *)orders
                                                                        limit:(NSInteger)limit
{
    NSMutableArray<PPHomeBuyAgainSnapshotItem *> *items = [NSMutableArray array];
    NSMutableSet<NSString *> *seenIDs = [NSMutableSet set];

    for (PPOrder *order in orders ?: @[]) {
        if (![order isKindOfClass:PPOrder.class]) {
            continue;
        }

        NSString *statusKey = [self pp_homeOrderStatusKey:order];
        if ([self pp_isFailureHomeOrderStatusKey:statusKey]) {
            continue;
        }

        for (id rawItem in order.items ?: @[]) {
            PPHomeBuyAgainSnapshotItem *snapshotItem =
                [self pp_buyAgainSnapshotItemFromRawOrderItem:rawItem];
            if (!snapshotItem || snapshotItem.itemID.length == 0 ||
                [seenIDs containsObject:snapshotItem.itemID]) {
                continue;
            }

            [seenIDs addObject:snapshotItem.itemID];
            [items addObject:snapshotItem];
            if (limit > 0 && items.count >= limit) {
                return items.copy;
            }
        }
    }

    return items.copy;
}

static NSInteger const PPLastFoodVisibleLimit = 10;

- (void)pp_refreshLastFoodSection
{
    NSMutableArray<PetAccessory *> *foodItems = [NSMutableArray array];
    for (PetAccessory *accessory in self.accessories ?: @[]) {
        if (![accessory isKindOfClass:PetAccessory.class]) continue;
        if (accessory.accessKindType == AccessTypeFood) {
            [foodItems addObject:accessory];
        }
    }

    // Sort by createdAt descending (newest first)
    [foodItems sortUsingComparator:^NSComparisonResult(PetAccessory *a, PetAccessory *b) {
        NSDate *aDate = a.createdAt ?: [NSDate distantPast];
        NSDate *bDate = b.createdAt ?: [NSDate distantPast];
        return [bDate compare:aDate];
    }];

    // Limit to visible count
    if (foodItems.count > PPLastFoodVisibleLimit) {
        [foodItems removeObjectsInRange:NSMakeRange(PPLastFoodVisibleLimit,
                                                     foodItems.count - PPLastFoodVisibleLimit)];
    }

    self.lastFoodAccessories = foodItems.copy;
    [self reloadSection:PPHomeSectionLastFood];
}

- (NSString *)pp_homeOrderItemIdentifier:(id)rawItem
{
    if ([rawItem isKindOfClass:NSString.class]) {
        return [(NSString *)rawItem stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }

    if (![rawItem isKindOfClass:NSDictionary.class]) {
        return @"";
    }

    NSDictionary *item = (NSDictionary *)rawItem;
    NSArray<NSString *> *candidateKeys = @[@"id", @"itemID", @"productId", @"productID"];
    NSString *nestedValue = [self pp_buyAgainStringFromValue:[self pp_buyAgainValueForKeys:candidateKeys
                                                                                   rawItem:item]];
    if (nestedValue.length > 0) {
        return nestedValue;
    }

    for (NSString *key in candidateKeys) {
        NSString *value = [item[key] isKindOfClass:NSString.class] ? item[key] : @"";
        value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (value.length > 0) {
            return value;
        }
    }

    return @"";
}

- (NSArray<NSString *> *)pp_buyAgainAccessoryIDsFromOrders:(NSArray<PPOrder *> *)orders
                                                     limit:(NSInteger)limit
{
    NSArray<PPHomeBuyAgainSnapshotItem *> *snapshotItems =
        [self pp_buyAgainSnapshotItemsFromOrders:orders limit:limit];
    NSMutableArray<NSString *> *orderedIDs = [NSMutableArray arrayWithCapacity:snapshotItems.count];
    for (PPHomeBuyAgainSnapshotItem *snapshotItem in snapshotItems) {
        if (snapshotItem.itemID.length > 0) {
            [orderedIDs addObject:snapshotItem.itemID];
        }
    }

    return orderedIDs.copy;
}

- (NSArray *)pp_orderedBuyAgainEntriesFromResolvedByID:(NSDictionary<NSString *, PetAccessory *> *)resolvedByID
                                         snapshotItems:(NSArray<PPHomeBuyAgainSnapshotItem *> *)snapshotItems
                                                 limit:(NSInteger)limit
{
    NSMutableArray *orderedEntries = [NSMutableArray array];
    NSMutableSet<NSString *> *seenAccessoryIDs = [NSMutableSet set];

    for (PPHomeBuyAgainSnapshotItem *snapshotItem in snapshotItems ?: @[]) {
        if (![snapshotItem isKindOfClass:PPHomeBuyAgainSnapshotItem.class] ||
            snapshotItem.itemID.length == 0 ||
            [seenAccessoryIDs containsObject:snapshotItem.itemID]) {
            continue;
        }

        PetAccessory *accessory = resolvedByID[snapshotItem.itemID];
        if ([accessory isKindOfClass:PetAccessory.class]) {
            NSString *accessoryID = PPSafeString(accessory.accessoryID);
            if (accessoryID.length == 0) {
                continue;
            }

            [seenAccessoryIDs addObject:accessoryID];
            if (accessory.quantity > 0) {
                [orderedEntries addObject:accessory];
            } else {
                if (snapshotItem.mainKindID <= 0) {
                    snapshotItem.mainKindID = accessory.petMainCategoryID;
                }
                if (snapshotItem.accessKindType <= 0) {
                    snapshotItem.accessKindType = accessory.accessKindType;
                }
                if (snapshotItem.title.length == 0) {
                    snapshotItem.title = accessory.name ?: @"";
                }
                if (snapshotItem.imageURL.length == 0 &&
                    [accessory.imageURLsArray isKindOfClass:NSArray.class]) {
                    snapshotItem.imageURL = PPSafeString(accessory.imageURLsArray.firstObject);
                }
                [orderedEntries addObject:snapshotItem];
            }
        } else {
            [seenAccessoryIDs addObject:snapshotItem.itemID];
            [orderedEntries addObject:snapshotItem];
        }

        if (limit > 0 && orderedEntries.count >= limit) {
            break;
        }
    }

    return orderedEntries.copy;
}

- (void)pp_refreshBuyAgainSection
{
    NSArray<PPHomeBuyAgainSnapshotItem *> *snapshotItems =
        [self pp_buyAgainSnapshotItemsFromOrders:self.recentOrders
                                           limit:MAX(PPBuyAgainVisibleLimit * 2, PPBuyAgainVisibleLimit)];

    self.buyAgainRequestToken += 1;
    NSInteger requestToken = self.buyAgainRequestToken;

    if (snapshotItems.count == 0) {
        self.buyAgainEntries = @[];
        NSString *nextSignature = [self pp_homeBuyAgainSignatureForEntries:@[]];
        BOOL shouldReload =
            ![nextSignature isEqualToString:PPSafeString(self.lastBuyAgainSectionSignature)];
        self.lastBuyAgainSectionSignature = nextSignature;
        if (self.dataSource) {
            if (shouldReload) {
                [self reloadSection:PPHomeSectionBuyAgain];
            }
        }
        return;
    }

    NSMutableDictionary<NSString *, PetAccessory *> *resolvedByID = [NSMutableDictionary dictionary];
    for (PetAccessory *accessory in self.accessories ?: @[]) {
        if (![accessory isKindOfClass:PetAccessory.class]) {
            continue;
        }

        NSString *accessoryID = PPSafeString(accessory.accessoryID);
        if (accessoryID.length == 0) {
            continue;
        }
        resolvedByID[accessoryID] = accessory;
    }

    NSMutableArray<NSString *> *missingIDs = [NSMutableArray array];
    for (PPHomeBuyAgainSnapshotItem *snapshotItem in snapshotItems) {
        NSString *itemID = snapshotItem.itemID ?: @"";
        if (itemID.length == 0 || resolvedByID[itemID] != nil) {
            continue;
        }
        [missingIDs addObject:itemID];
    }

    void (^applyResolvedEntries)(NSDictionary<NSString *, PetAccessory *> *) =
    ^(NSDictionary<NSString *, PetAccessory *> *resolved) {
        NSArray *orderedEntries =
            [self pp_orderedBuyAgainEntriesFromResolvedByID:resolved
                                              snapshotItems:snapshotItems
                                                      limit:PPBuyAgainVisibleLimit];
        self.buyAgainEntries = orderedEntries;
        NSString *nextSignature = [self pp_homeBuyAgainSignatureForEntries:orderedEntries];
        BOOL shouldReload =
            ![nextSignature isEqualToString:PPSafeString(self.lastBuyAgainSectionSignature)];
        self.lastBuyAgainSectionSignature = nextSignature;
        if (self.dataSource) {
            if (shouldReload) {
                [self reloadSection:PPHomeSectionBuyAgain];
            }
        }
    };

    if (missingIDs.count == 0) {
        applyResolvedEntries(resolvedByID.copy);
        return;
    }

    __weak typeof(self) weakSelf = self;
    [PetAccessoryManager fetchAccessoriesWithIDs:missingIDs
                                      completion:^(NSArray<PetAccessory *> *accessories) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (requestToken != self.buyAgainRequestToken) {
            return;
        }

        NSMutableDictionary<NSString *, PetAccessory *> *mergedByID = resolvedByID.mutableCopy;
        for (PetAccessory *accessory in accessories ?: @[]) {
            if (![accessory isKindOfClass:PetAccessory.class]) {
                continue;
            }

            NSString *accessoryID = PPSafeString(accessory.accessoryID);
            if (accessoryID.length == 0) {
                continue;
            }
            mergedByID[accessoryID] = accessory;
        }

        applyResolvedEntries(mergedByID.copy);
    }];
}

- (void)pp_clearUnavailableBuyAgainCoverFromCell:(UICollectionViewCell *)cell
{
    UIView *cover = [cell.contentView viewWithTag:PPHomeUnavailableBuyAgainCoverTag];
    [cover.layer removeAllAnimations];
    [cover removeFromSuperview];
    cell.accessibilityElements = nil;
}

- (void)pp_applyUnavailableBuyAgainCoverToCell:(PPUniversalCell *)cell
                                  snapshotItem:(PPHomeBuyAgainSnapshotItem *)snapshotItem
{
    if (!cell || ![snapshotItem isKindOfClass:PPHomeBuyAgainSnapshotItem.class]) {
        return;
    }

    [self pp_clearUnavailableBuyAgainCoverFromCell:cell];

    UIView *cover = [[UIView alloc] init];
    cover.translatesAutoresizingMaskIntoConstraints = NO;
    cover.tag = PPHomeUnavailableBuyAgainCoverTag;
    cover.clipsToBounds = YES;
    cover.userInteractionEnabled = YES;
    cover.isAccessibilityElement = YES;
    cover.accessibilityTraits = UIAccessibilityTraitButton;
    cover.accessibilityLabel = kLang(@"Home_BuyAgainUnavailableTitle") ?: @"";
    cover.accessibilityHint = kLang(@"Home_BuyAgainDiscoverSimilars") ?: @"";
    cover.semanticContentAttribute = PPHomeCurrentSemanticAttribute();
    cover.layer.cornerRadius = 24.0;
    if (@available(iOS 13.0, *)) {
        cover.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIBlurEffectStyle blurStyle = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
        ? UIBlurEffectStyleSystemUltraThinMaterialDark
        : UIBlurEffectStyleSystemUltraThinMaterialLight;
    UIVisualEffectView *blurView =
        [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:blurStyle]];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    blurView.userInteractionEnabled = NO;
    blurView.alpha = 0.75;
    [cover addSubview:blurView];

    UIView *tintView = [[UIView alloc] init];
    tintView.translatesAutoresizingMaskIntoConstraints = NO;
    tintView.userInteractionEnabled = NO;
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    tintView.backgroundColor = isDark
        ? [UIColor colorWithWhite:0.02 alpha:0.74]
        : [UIColor colorWithWhite:1.0 alpha:0.72];
    [cover addSubview:tintView];

    UIStackView *stackView = [[UIStackView alloc] init];
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    stackView.axis = UILayoutConstraintAxisVertical;
    stackView.alignment = UIStackViewAlignmentCenter;
    stackView.distribution = UIStackViewDistributionFill;
    stackView.spacing = 8.0;
    stackView.userInteractionEnabled = YES;
    stackView.semanticContentAttribute = PPHomeCurrentSemanticAttribute();
    [cover addSubview:stackView];

    UIImageView *iconView =
        [[UIImageView alloc] initWithImage:[UIImage pp_symbolNamed:@"exclamationmark.circle.fill"
                                                         pointSize:22.0
                                                            weight:UIImageSymbolWeightSemibold
                                                             scale:UIImageSymbolScaleMedium
                                                           palette:@[UIColor.secondaryLabelColor]
                                                      makeTemplate:YES]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.tintColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:isDark ? 0.86 : 0.70];
    [stackView addArrangedSubview:iconView];
    [iconView.widthAnchor constraintEqualToConstant:24.0].active = YES;
    [iconView.heightAnchor constraintEqualToConstant:24.0].active = YES;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = kLang(@"Home_BuyAgainUnavailableTitle") ?: @"";
    titleLabel.textColor = UIColor.labelColor;
    titleLabel.font = [GM boldFontWithSize:13.5] ?: [UIFont systemFontOfSize:13.5 weight:UIFontWeightSemibold];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.numberOfLines = 2;
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.minimumScaleFactor = 0.82;
    titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [stackView addArrangedSubview:titleLabel];
    [titleLabel.widthAnchor constraintLessThanOrEqualToConstant:150.0].active = YES;

    PPHomeUnavailableBuyAgainButton *button =
        [PPHomeUnavailableBuyAgainButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.buyAgainItem = snapshotItem;
    button.semanticContentAttribute = PPHomeCurrentSemanticAttribute();
    button.accessibilityLabel = kLang(@"Home_BuyAgainDiscoverSimilars") ?: @"";
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.82;
    button.titleLabel.numberOfLines = 1;
    button.layer.cornerRadius = 16.0;
    button.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *configuration = [UIButtonConfiguration filledButtonConfiguration];
        configuration.cornerStyle = UIButtonConfigurationCornerStyleLarge;
        configuration.baseBackgroundColor = AppPrimaryClr ?: UIColor.systemBlueColor;
        configuration.baseForegroundColor = UIColor.whiteColor;
        configuration.contentInsets = NSDirectionalEdgeInsetsMake(7.0, 12.0, 7.0, 12.0);
        configuration.title = kLang(@"Home_BuyAgainDiscoverSimilars") ?: @"";
        configuration.image = [UIImage systemImageNamed:Language.isRTL ? @"chevron.left" : @"chevron.right"];
        configuration.imagePlacement = NSDirectionalRectEdgeTrailing;
        configuration.imagePadding = 5.0;
        button.configuration = configuration;
    } else {
        [button setTitle:kLang(@"Home_BuyAgainDiscoverSimilars") ?: @""
                forState:UIControlStateNormal];
        button.titleLabel.font = [GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
        button.contentEdgeInsets = UIEdgeInsetsMake(7.0, 12.0, 7.0, 12.0);
        button.backgroundColor = AppPrimaryClr ?: UIColor.systemBlueColor;
        [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    }

    [button addTarget:self action:@selector(pp_unavailableBuyAgainDiscoverTapped:)
     forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:self action:@selector(pp_unavailableBuyAgainButtonTouchDown:)
     forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(pp_unavailableBuyAgainButtonTouchUp:)
     forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [stackView addArrangedSubview:button];
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:32.0].active = YES;
    [button.widthAnchor constraintLessThanOrEqualToConstant:156.0].active = YES;
    cell.imageView.alpha = 0.7;
    [cell.contentView addSubview:cover];
    [NSLayoutConstraint activateConstraints:@[
        [cover.topAnchor constraintEqualToAnchor:cell.imageContainer.bottomAnchor constant:9.0],
        [cover.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:6.0],
        [cover.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-6.0],
        [cover.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-6.0],

        [blurView.topAnchor constraintEqualToAnchor:cover.topAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:cover.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:cover.trailingAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:cover.bottomAnchor],

        [tintView.topAnchor constraintEqualToAnchor:cover.topAnchor],
        [tintView.leadingAnchor constraintEqualToAnchor:cover.leadingAnchor],
        [tintView.trailingAnchor constraintEqualToAnchor:cover.trailingAnchor],
        [tintView.bottomAnchor constraintEqualToAnchor:cover.bottomAnchor],

        [stackView.centerXAnchor constraintEqualToAnchor:cover.centerXAnchor],
        [stackView.centerYAnchor constraintEqualToAnchor:cover.centerYAnchor],
        [stackView.leadingAnchor constraintGreaterThanOrEqualToAnchor:cover.leadingAnchor constant:12.0],
        [stackView.trailingAnchor constraintLessThanOrEqualToAnchor:cover.trailingAnchor constant:-12.0]
    ]];

    cell.accessibilityElements = @[cover];

    if ([self pp_shouldReduceHomeMotion]) {
        cover.alpha = 1.0;
        return;
    }

    cover.alpha = 0.0;
    stackView.transform = CGAffineTransformMakeTranslation(0.0, 4.0);
    [UIView animateWithDuration:0.30
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        cover.alpha = 1.0;
        stackView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_unavailableBuyAgainButtonTouchDown:(UIButton *)button
{
    if ([self pp_shouldReduceHomeMotion]) {
        return;
    }
    [UIView animateWithDuration:0.10
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        button.transform = CGAffineTransformMakeScale(0.96, 0.96);
        button.alpha = 0.92;
    } completion:nil];
}

- (void)pp_unavailableBuyAgainButtonTouchUp:(UIButton *)button
{
    if ([self pp_shouldReduceHomeMotion]) {
        button.transform = CGAffineTransformIdentity;
        button.alpha = 1.0;
        return;
    }
    [UIView animateWithDuration:0.18
                          delay:0.0
         usingSpringWithDamping:0.78
          initialSpringVelocity:0.24
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        button.transform = CGAffineTransformIdentity;
        button.alpha = 1.0;
    } completion:nil];
}

- (void)pp_unavailableBuyAgainDiscoverTapped:(PPHomeUnavailableBuyAgainButton *)button
{
    [self pp_emitSoftImpactHaptic];
    [self pp_openSimilarItemsForUnavailableBuyAgainItem:button.buyAgainItem];
}

- (PPDeepLinkTarget)pp_buyAgainTargetForAccessKindType:(NSInteger)accessKindType
{
    return accessKindType == AccessTypeFood ? PPDeepLinkTargetFood : PPDeepLinkTargetAccessories;
}

- (void)pp_openSimilarItemsForUnavailableBuyAgainItem:(PPHomeBuyAgainSnapshotItem *)snapshotItem
{
    if (![snapshotItem isKindOfClass:PPHomeBuyAgainSnapshotItem.class]) {
        return;
    }

    PPDeepLinkTarget target = [self pp_buyAgainTargetForAccessKindType:snapshotItem.accessKindType];
    MainKindsModel *mainKind = snapshotItem.mainKindID > 0
        ? [self resolveMainKindWithID:snapshotItem.mainKindID]
        : nil;

    PPDataViewInput *input =
        [PPDataViewInput inputWithMainKind:mainKind
                              sourceTarget:target
                                    source:PPInputSourceHomeAccessoriesSection];
    input.mainKindsArr = self.mainKinds ?: @[];
    input.initialSectionOverride = @([PPHomeHelper sectionFromSourceTarget:target]);

    PPDataViewVC *vc = [[PPDataViewVC alloc] initWithInput:input];
    vc.pp_transitionStyle = PPTransitionStyleNone;
    [PPHomeHelper pushViewControllerSafely:vc from:self animated:YES];
}

- (void)pp_openOrderDetailsForOrder:(PPOrder *)order
{
    if (![order isKindOfClass:PPOrder.class]) {
        return;
    }

    OrderDetailsViewController *detailsVC =
        [[OrderDetailsViewController alloc] initWithOrder:order];
    detailsVC.order = order;
    [PPHomeHelper pushViewControllerSafely:detailsVC from:self animated:YES];
}

- (void)refreshCurrentOrdersForce:(BOOL)force
{
    NSString *userID = [self pp_currentOrdersUserID];
    if (userID.length == 0) {
        self.currentOrdersRequestToken += 1;
        [self pp_stopCurrentOrdersListener];
        self.currentOrders = @[];
        self.recentOrders = @[];
        self.buyAgainEntries = @[];
        self.currentOrdersLoading = NO;
        self.currentOrdersLoaded = YES;
        self.lastCurrentOrdersRefreshAt = nil;
        self.lastObservedHomeOrderID = nil;
        self.lastObservedHomeOrderStatusKey = nil;
        NSString *nextCurrentSignature =
            [self pp_homeCurrentOrdersSectionSignatureWithLoading:NO];
        BOOL shouldReloadCurrentOrders =
            ![nextCurrentSignature isEqualToString:PPSafeString(self.lastCurrentOrdersSectionSignature)];
        self.lastCurrentOrdersSectionSignature = nextCurrentSignature;

        NSString *nextBuyAgainSignature =
            [self pp_homeBuyAgainSignatureForEntries:@[]];
        BOOL shouldReloadBuyAgain =
            ![nextBuyAgainSignature isEqualToString:PPSafeString(self.lastBuyAgainSectionSignature)];
        self.lastBuyAgainSectionSignature = nextBuyAgainSignature;

        if (self.dataSource) {
            if (shouldReloadCurrentOrders) {
                [self reloadSection:PPHomeSectionCurrentOrders];
            }
            if (shouldReloadBuyAgain) {
                [self reloadSection:PPHomeSectionBuyAgain];
            }
        }
        return;
    }

    BOOL listenerMatchesCurrentUser =
        self.currentOrdersQueryListener != nil &&
        [self.currentOrdersListenerUserID isEqualToString:userID];
    if (listenerMatchesCurrentUser && !force) {
        return;
    }

    self.currentOrdersRequestToken += 1;
    NSInteger requestToken = self.currentOrdersRequestToken;
    [self pp_stopCurrentOrdersListener];
    self.currentOrdersListenerUserID = userID;
    self.currentOrdersLoading = YES;
    self.currentOrdersLoaded = NO;

    if (self.currentOrders.count == 0 && self.dataSource) {
        NSString *loadingSignature =
            [self pp_homeCurrentOrdersSectionSignatureWithLoading:YES];
        if (![loadingSignature isEqualToString:PPSafeString(self.lastCurrentOrdersSectionSignature)]) {
            self.lastCurrentOrdersSectionSignature = loadingSignature;
            [self reloadSection:PPHomeSectionCurrentOrders];
        }
    }

    [self pp_startCurrentOrdersListenerForUserID:userID requestToken:requestToken];
}

- (void)pp_stopCurrentOrdersListener
{
    [self.currentOrdersQueryListener remove];
    self.currentOrdersQueryListener = nil;
    self.currentOrdersListenerUserID = @"";
}

- (void)pp_startCurrentOrdersListenerForUserID:(NSString *)userID requestToken:(NSInteger)requestToken
{
    if (userID.length == 0) {
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    FIRQuery *query = [[db collectionWithPath:@"Orders"] queryWhereField:@"userId" isEqualTo:userID];
    query = [query queryOrderedByField:@"createdAt" descending:YES];
    query = [query queryLimitedTo:12];

    __weak typeof(self) weakSelf = self;
    self.currentOrdersQueryListener =
    [query addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            if (requestToken != self.currentOrdersRequestToken) {
                return;
            }

            if (error) {
                self.currentOrdersLoading = NO;
                self.currentOrdersLoaded = YES;
                NSLog(@"[Home][CurrentOrders] fetch failed: %@", error.localizedDescription ?: @"Unknown error");
                [self reloadSection:PPHomeSectionCurrentOrders];
                [self pp_refreshBuyAgainSection];
                return;
            }

            [self pp_applyCurrentOrdersSnapshot:snapshot requestToken:requestToken];
        });
    }];
}

- (void)pp_applyCurrentOrdersSnapshot:(FIRQuerySnapshot *)snapshot requestToken:(NSInteger)requestToken
{
    if (requestToken != self.currentOrdersRequestToken) {
        return;
    }

    self.currentOrdersLoading = NO;
    self.currentOrdersLoaded = YES;
    self.lastCurrentOrdersRefreshAt = [NSDate date];

    NSMutableArray<PPOrder *> *recentOrders = [NSMutableArray array];
    NSMutableArray<PPOrder *> *resolvedOrders = [NSMutableArray array];
    for (FIRDocumentSnapshot *document in snapshot.documents ?: @[]) {
        PPOrder *order = [PPOrder orderFromSnapshot:document];
        if (![order isKindOfClass:PPOrder.class]) {
            continue;
        }
        [recentOrders addObject:order];
        if (![self pp_isActiveHomeOrder:order]) {
            continue;
        }
        if (resolvedOrders.count >= PPCurrentOrdersVisibleLimit) {
            continue;
        }
        [resolvedOrders addObject:order];
    }

    self.recentOrders = recentOrders.copy;
    self.currentOrders = resolvedOrders.copy;

    PPOrder *featuredOrder = [self pp_featuredHomeOrder];
    NSString *nextObservedOrderID = [featuredOrder isKindOfClass:PPOrder.class]
        ? PPSafeString(featuredOrder.orderId)
        : @"";
    NSString *nextObservedStatusKey = [featuredOrder isKindOfClass:PPOrder.class]
        ? [self pp_homeOrderStatusKey:featuredOrder]
        : @"";
    NSString *previousOrderID = PPSafeString(self.lastObservedHomeOrderID);
    NSString *previousStatusKey = PPSafeString(self.lastObservedHomeOrderStatusKey);

    BOOL shouldPlayStatusFeedback = self.isHomeScreenVisible &&
                                    previousOrderID.length > 0 &&
                                    nextObservedOrderID.length > 0 &&
                                    [previousOrderID isEqualToString:nextObservedOrderID] &&
                                    previousStatusKey.length > 0 &&
                                    nextObservedStatusKey.length > 0 &&
                                    ![previousStatusKey isEqualToString:nextObservedStatusKey];
    if (shouldPlayStatusFeedback) {
        AudioServicesPlaySystemSound(1110);
    }

    self.lastObservedHomeOrderID = nextObservedOrderID;
    self.lastObservedHomeOrderStatusKey = nextObservedStatusKey;
    NSString *nextCurrentSignature =
        [self pp_homeCurrentOrdersSectionSignatureWithLoading:NO];
    BOOL shouldReloadCurrentOrders =
        ![nextCurrentSignature isEqualToString:PPSafeString(self.lastCurrentOrdersSectionSignature)];
    self.lastCurrentOrdersSectionSignature = nextCurrentSignature;
    if (shouldReloadCurrentOrders) {
        [self reloadSection:PPHomeSectionCurrentOrders];
    }
    [self pp_refreshBuyAgainSection];
    [self pp_refreshSuggestionsForAppearanceIfNeeded];
    // Refresh hero peek strip to reflect order changes
    [self refreshHeroSectionAppearance];
}

- (void)persistNearbyLocationIfNeeded
{
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if (self.hasSelectedNearbyCoordinate &&
        CLLocationCoordinate2DIsValid(self.selectedNearbyCoordinate) &&
        isfinite(self.selectedNearbyCoordinate.latitude) &&
        isfinite(self.selectedNearbyCoordinate.longitude)) {
        [defaults setDouble:self.selectedNearbyCoordinate.latitude forKey:PPNearbySelectedLatitudeKey];
        [defaults setDouble:self.selectedNearbyCoordinate.longitude forKey:PPNearbySelectedLongitudeKey];
        [defaults setObject:self.selectedNearbyAreaName ?: @"" forKey:PPNearbySelectedAreaNameKey];
    } else {
        [defaults removeObjectForKey:PPNearbySelectedLatitudeKey];
        [defaults removeObjectForKey:PPNearbySelectedLongitudeKey];
        [defaults removeObjectForKey:PPNearbySelectedAreaNameKey];
    }
}

- (void)startNearbyRefreshTimerIfNeeded
{
    if (self.nearbyRefreshTimer) return;

    __weak typeof(self) weakSelf = self;
    self.nearbyRefreshTimer =
    [NSTimer scheduledTimerWithTimeInterval:90.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self refreshNearbyAdsForce:NO reason:@"periodic"];
    }];
}

- (void)stopNearbyRefreshTimer
{
    [self.nearbyRefreshTimer invalidate];
    self.nearbyRefreshTimer = nil;
}

- (void)configureLocationStateMachine
{
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if ([defaults objectForKey:PPNearbySelectedLatitudeKey] &&
        [defaults objectForKey:PPNearbySelectedLongitudeKey]) {
        CLLocationCoordinate2D persisted =
            CLLocationCoordinate2DMake([defaults doubleForKey:PPNearbySelectedLatitudeKey],
                                       [defaults doubleForKey:PPNearbySelectedLongitudeKey]);
        if (CLLocationCoordinate2DIsValid(persisted) &&
            !(fabs(persisted.latitude) < DBL_EPSILON && fabs(persisted.longitude) < DBL_EPSILON)) {
            self.selectedNearbyCoordinate = persisted;
            self.hasSelectedNearbyCoordinate = YES;
            self.selectedNearbyAreaName = [defaults stringForKey:PPNearbySelectedAreaNameKey] ?: @"";
            self.nearbyLocationState = PPNearbyLocationStateReady;
        }
    }

    self.homeLocationManager = [[CLLocationManager alloc] init];
    self.homeLocationManager.delegate = self;
    self.homeLocationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
    self.homeLocationManager.distanceFilter = 75.0;

    CLAuthorizationStatus status;
    if (@available(iOS 14.0, *)) {
        status = self.homeLocationManager.authorizationStatus;
    } else {
        status = [CLLocationManager authorizationStatus];
    }
    [self updateLocationStateForAuthorizationStatus:status];
}

- (BOOL)pp_canUseSimulatedNearbyLocation
{
#if DEBUG
#if TARGET_OS_SIMULATOR
    return YES;
#else
    return NO;
#endif
#else
    return NO;
#endif
}

- (void)pp_applySimulatedNearbyLocationAndRefreshWithReason:(NSString *)reason
{
    if (![self pp_canUseSimulatedNearbyLocation]) {
        return;
    }

    CLLocationCoordinate2D coordinate = self.selectedNearbyCoordinate;
    if (!CLLocationCoordinate2DIsValid(coordinate) ||
        (fabs(coordinate.latitude) < DBL_EPSILON && fabs(coordinate.longitude) < DBL_EPSILON)) {
        coordinate = PPNearbyDebugSimulatorCoordinate;
    }
    if (!CLLocationCoordinate2DIsValid(coordinate)) {
        return;
    }

    NSString *areaName = PPSafeString(self.selectedNearbyAreaName);
    if (areaName.length == 0) {
        CountryModel *country = CitiesManager.shared.CurrentCountry;
        CityModel *defaultCity = [CitiesManager.shared defaultCityForCountry:country];
        if (defaultCity.name.length > 0) {
            areaName = defaultCity.name;
        } else {
            areaName = kLang(@"Select your location") ?: @"Select your location";
        }
    }

    self.selectedNearbyCoordinate = coordinate;
    self.hasSelectedNearbyCoordinate = YES;
    self.selectedNearbyAreaName = areaName;
    self.nearbyLocationState = PPNearbyLocationStateReady;
    self.nearbyRadiusKm = PPNearbyDefaultRadiusKm;
    [self pp_recordRecentNearbyLocationCoordinate:coordinate
                                            title:areaName
                                           source:@"simulator"];
    [self persistNearbyLocationIfNeeded];
    [self refreshHeroSectionAppearance];
    [self refreshNearbyAdsForce:YES reason:(reason.length > 0 ? reason : @"simulator-location")];
}

- (void)updateLocationStateForAuthorizationStatus:(CLAuthorizationStatus)status
{
    // ⚠️ Do NOT call +locationServicesEnabled on main thread repeatedly.
    // Rely on authorization status changes instead.
    // If services are globally disabled, the status will be Denied/Restricted.

    if (status == kCLAuthorizationStatusDenied ||
        status == kCLAuthorizationStatusRestricted) {

        if (!self.hasSelectedNearbyCoordinate && [self pp_canUseSimulatedNearbyLocation]) {
            [self pp_applySimulatedNearbyLocationAndRefreshWithReason:@"simulator-denied"];
            return;
        }

        self.nearbyLocationState = self.hasSelectedNearbyCoordinate
            ? PPNearbyLocationStateReady
            : PPNearbyLocationStateDenied;

        [self refreshHeroSectionAppearance];
        return;
    }

    switch (status) {
        case kCLAuthorizationStatusAuthorizedAlways:
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            self.nearbyLocationState = (self.hasSelectedNearbyCoordinate || self.isUsingManualNearbySelection)
                ? PPNearbyLocationStateReady
                : PPNearbyLocationStateLoading;
            if (!self.isUsingManualNearbySelection) {
                [self requestCurrentLocationIfNeeded];
            }
            break;

        case kCLAuthorizationStatusDenied:
        case kCLAuthorizationStatusRestricted:
            self.nearbyLocationState = self.hasSelectedNearbyCoordinate
                ? PPNearbyLocationStateReady
                : PPNearbyLocationStateDenied;
            break;

        case kCLAuthorizationStatusNotDetermined:
            self.nearbyLocationState = self.hasSelectedNearbyCoordinate
                ? PPNearbyLocationStateReady
                : PPNearbyLocationStateLoading;
            if (!self.hasRequestedLocationAuthorization) {
                self.hasRequestedLocationAuthorization = YES;
                [self.homeLocationManager requestWhenInUseAuthorization];
            }
            break;
    }

    [self refreshHeroSectionAppearance];
    [self startNearbyRefreshTimerIfNeeded];
    BOOL shouldForceRefresh = (!self.nearbyLoaded && self.nearbyAds.count == 0);
    [self refreshNearbyAdsForce:shouldForceRefresh
                         reason:@"viewDidAppear"];
}

- (void)requestCurrentLocationIfNeeded
{
    if (!self.homeLocationManager) return;
    if (self.isUsingManualNearbySelection) return;
    [self.homeLocationManager requestLocation];
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager API_AVAILABLE(ios(14.0))
{
    [self updateLocationStateForAuthorizationStatus:manager.authorizationStatus];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    [self updateLocationStateForAuthorizationStatus:status];
}
#pragma clang diagnostic pop

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    if (self.isUsingManualNearbySelection) {
        return;
    }

    CLLocation *latest = locations.lastObject;
    if (!latest) return;

    CLLocationCoordinate2D coordinate = latest.coordinate;
    if (!CLLocationCoordinate2DIsValid(coordinate)) return;
    if (fabs(coordinate.latitude) < DBL_EPSILON && fabs(coordinate.longitude) < DBL_EPSILON) return;

    if (!self.hasSelectedNearbyCoordinate) {
        self.selectedNearbyCoordinate = coordinate;
        self.hasSelectedNearbyCoordinate = YES;
    }

    [self.homeGeocoder cancelGeocode];
    __weak typeof(self) weakSelf = self;
    CLLocation *location = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
    [self.homeGeocoder reverseGeocodeLocation:location completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        NSString *area = self.selectedNearbyAreaName;
        CLPlacemark *placemark = placemarks.firstObject;
        if (!error && placemark) {
            NSString *locality = placemark.locality ?: placemark.subLocality;
            NSString *admin = placemark.administrativeArea;
            if (locality.length > 0 && admin.length > 0 && ![locality isEqualToString:admin]) {
                area = [NSString stringWithFormat:@"%@, %@", locality, admin];
            } else if (locality.length > 0) {
                area = locality;
            } else if (admin.length > 0) {
                area = admin;
            }
        }

        if (area.length == 0) {
            area = kLang(@"Select your location");
        }

        self.selectedNearbyCoordinate = coordinate;
        self.selectedNearbyAreaName = area;
        self.hasSelectedNearbyCoordinate = YES;
        self.nearbyLocationState = PPNearbyLocationStateReady;
        [self pp_recordRecentNearbyLocationCoordinate:coordinate
                                                title:area
                                               source:@"gps"];
        [self persistNearbyLocationIfNeeded];
        [self refreshHeroSectionAppearance];
        [self refreshNearbyAdsForce:YES reason:@"location-updated"];
    }];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"[HomeNearby] location failed: %@", error.localizedDescription);
    if (!self.hasSelectedNearbyCoordinate) {
        if ([self pp_canUseSimulatedNearbyLocation]) {
            [self pp_applySimulatedNearbyLocationAndRefreshWithReason:@"simulator-fail"];
            return;
        }
        self.nearbyLocationState = PPNearbyLocationStateDenied;
        [self refreshHeroSectionAppearance];
    }
}

- (void)openHomeLocationPicker
{
    LocationPickerViewController *picker = [[LocationPickerViewController alloc] init];
    picker.hidesBottomBarWhenPushed = YES;
    if (self.hasSelectedNearbyCoordinate && CLLocationCoordinate2DIsValid(self.selectedNearbyCoordinate)) {
        picker.initialCoordinate = self.selectedNearbyCoordinate;
    }
    __weak typeof(self) weakSelf = self;
    void (^applyPickedCoordinate)(CLLocationCoordinate2D, NSString *) =
    ^(CLLocationCoordinate2D coordinate, NSString *resolvedTitle) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (!CLLocationCoordinate2DIsValid(coordinate) ||
            (fabs(coordinate.latitude) < DBL_EPSILON && fabs(coordinate.longitude) < DBL_EPSILON)) {
            return;
        }

        NSString *resolvedAreaName = PPSafeString(resolvedTitle);
        if (resolvedAreaName.length == 0) {
            resolvedAreaName = kLang(@"Select your location") ?: @"Select your location";
        }
        self.isUsingManualNearbySelection = YES;
        self.selectedNearbyCoordinate = coordinate;
        self.hasSelectedNearbyCoordinate = YES;
        self.selectedNearbyAreaName = resolvedAreaName;
        self.nearbyLocationState = PPNearbyLocationStateReady;
        self.nearbyRadiusKm = PPNearbyDefaultRadiusKm;
        [self pp_recordRecentNearbyLocationCoordinate:coordinate
                                                title:resolvedAreaName
                                               source:@"manual"];
        [self persistNearbyLocationIfNeeded];
        [self refreshHeroSectionAppearance];
        [self refreshNearbyAdsForce:YES reason:@"manual-picker"];
    };
    picker.onLocationConfirmed = ^(GMSAddress *gmsAddress) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !gmsAddress) return;

        NSString *resolvedAreaName = [LocationPickerViewController titleFromAddress:gmsAddress] ?: @"";
        if (resolvedAreaName.length == 0 && gmsAddress.lines.count > 0) {
            resolvedAreaName = [gmsAddress.lines componentsJoinedByString:@", "] ?: @"";
        }
        if (resolvedAreaName.length == 0) {
            resolvedAreaName = gmsAddress.country ?: @"";
        }
        applyPickedCoordinate(gmsAddress.coordinate, resolvedAreaName);
    };
    picker.onCoordinateConfirmed = ^(CLLocationCoordinate2D coordinate, NSString *locationTitle) {
        applyPickedCoordinate(coordinate, locationTitle);
    };
    if (self.navigationController) {
        [self.navigationController pushViewController:picker animated:YES];
    } else {
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:picker];
        [self presentViewController:nav animated:YES completion:nil];
    }
}

- (void)presentHomeLocationOptions
{
    [self presentHomeLocationSheet];
}

- (void)presentHomeLocationSheet
{
    if (self.isPresentingHomeLocationSheet) {
        return;
    }
    if ([self.presentedViewController isKindOfClass:PPHomeLocationSheetViewController.class]) {
        return;
    }
    if (self.presentedViewController || self.isBeingPresented || self.isBeingDismissed) {
        return;
    }

    self.isPresentingHomeLocationSheet = YES;
    PPHomeLocationSheetViewController *sheet = [[PPHomeLocationSheetViewController alloc] init];
    sheet.sheetTitleText = kLang(@"home_location_sheet_title") ?: @"Choose your smart location";
    sheet.sheetSubtitleText = kLang(@"home_location_sheet_subtitle") ?: @"Switch between your live GPS position and recent areas quickly, while keeping nearby discovery smooth.";
    sheet.currentLocationTitle = [self heroCountryText];

    NSString *currentSubtitleKey = @"home_location_sheet_current_subtitle_unset";
    if (self.nearbyLocationState == PPNearbyLocationStateDenied) {
        currentSubtitleKey = @"home_location_sheet_current_subtitle_denied";
    } else if (self.isUsingManualNearbySelection) {
        currentSubtitleKey = @"home_location_sheet_current_subtitle_manual";
    } else if (self.nearbyLocationState == PPNearbyLocationStateReady) {
        currentSubtitleKey = @"home_location_sheet_current_subtitle_auto";
    }
    sheet.currentLocationSubtitle = kLang(currentSubtitleKey) ?: @"";
    sheet.showsUseCurrentLocationAction = (self.nearbyLocationState != PPNearbyLocationStateDenied);
    sheet.showsOpenSettingsAction = (self.nearbyLocationState == PPNearbyLocationStateDenied);
    sheet.recentLocations = [self pp_recentNearbyLocationRecords];

    __weak typeof(self) weakSelf = self;
    sheet.onUseCurrentLocation = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self switchHomeLocationBackToAutomatic];
    };
    sheet.onChangeArea = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self openHomeLocationPicker];
    };
    sheet.onOpenSettings = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self openLocationSettings];
    };
    sheet.onSelectRecentLocation = ^(NSDictionary *locationRecord) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self pp_applyNearbyLocationRecord:locationRecord];
    };

    [self pp_emitSoftImpactHaptic];

    [self presentViewController:sheet
                       animated:YES
                     completion:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.isPresentingHomeLocationSheet = NO;
    }];
}

- (void)switchHomeLocationBackToAutomatic
{
    self.isUsingManualNearbySelection = NO;
    [self pp_emitSelectionHaptic];
    if (!self.homeLocationManager) {
        [self refreshHeroSectionAppearance];
        return;
    }

    CLAuthorizationStatus status;
    if (@available(iOS 14.0, *)) {
        status = self.homeLocationManager.authorizationStatus;
    } else {
        status = [CLLocationManager authorizationStatus];
    }
    [self updateLocationStateForAuthorizationStatus:status];
}

- (void)openLocationSettings
{
    NSURL *settingsURL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    if ([[UIApplication sharedApplication] canOpenURL:settingsURL]) {
        [[UIApplication sharedApplication] openURL:settingsURL options:@{} completionHandler:nil];
    }
}

- (void)handleAppWillEnterForeground
{
    if (![self pp_canOwnHomeNavigationChrome]) {
        [self pp_detachHomeSmartSearchTitleViewIfNeeded];
        [self pp_detachHomeLocationTitleViewIfNeeded];
        return;
    }

    if (self.homeLocationManager && !self.isUsingManualNearbySelection) {
        CLAuthorizationStatus status;
        if (@available(iOS 14.0, *)) {
            status = self.homeLocationManager.authorizationStatus;
        } else {
            status = [CLLocationManager authorizationStatus];
        }
        [self updateLocationStateForAuthorizationStatus:status];
    }
    [self.view pp_resolveLayerColorsRecursively];
    [self refreshCurrentOrdersForce:YES];
    [self pp_refreshPetProfilesSection];
    [self refreshNearbyAdsForce:YES reason:@"foreground"];
    [self pp_refreshThemeSensitiveHomeContent];
}

- (void)handleThemePreferenceDidChange:(NSNotification *)notification
{
    (void)notification;
    [self pp_refreshThemeSensitiveHomeContent];
    [self pp_forceHomeCollectionLayoutRefresh];
}

- (void)handleAdUploadCompletedNotification:(NSNotification *)notification
{
    [self refreshNearbyAdsForce:YES reason:@"ad-upload"];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.isHomeScreenVisible = YES;
    [self pp_advancePremiumCareAnimationForAppearance];
    [self pp_beginPremiumHomeEntranceIfNeeded];
    if ([self pp_isInitialHomeRevealSettled]) {
        [self pp_stabilizeHomeCollectionLayoutIfNeeded];
    }
    [self pp_centerNearbySectionIfPossible];
    [self updateCartQuantityBadge];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateCartQuantityBadge];
    });
    //[PPHUD showLoading];
    if(!self.warmUpCache)
    {
        NSLog(@"Starting cache warm-up...");
        [[SearchCacheManager shared] warmUpCacheIfNeeded:^{
            NSLog(@"Cache Warm Up Complete ****** *******...");
        }];
        NSLog(@"Cache warm-up initiated");;
        self.warmUpCache = YES;
    }

    NSString *currentUserID = UserManager.sharedManager.currentUser.ID;
    if (currentUserID.length > 0) {
        if (!self.chatsListenerStarted ||
            ![self.unreadListenerUserID isEqualToString:currentUserID]) {
            self.chatsListenerStarted = YES;
            self.unreadListenerUserID = currentUserID;
            [[ChManager sharedManager] startGlobalUnreadListenerForUser:currentUserID];
        }
    } else {
        self.chatsListenerStarted = NO;
        self.unreadListenerUserID = nil;
    }
    [self.view bringSubviewToFront:self.profileCard];


    [self refreshHeroSectionAppearance];
    if (self.homeLocationManager) {
        CLAuthorizationStatus status;
        if (@available(iOS 14.0, *)) {
            status = self.homeLocationManager.authorizationStatus;
        } else {
            status = [CLLocationManager authorizationStatus];
        }
        [self updateLocationStateForAuthorizationStatus:status];
    }

    if (!self.didRegisterTimeChangeObserver) {
        self.didRegisterTimeChangeObserver = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleTimeChange)
                                                     name:UIApplicationSignificantTimeChangeNotification
                                                   object:nil];
    }

    [self pp_startNovaFloatingAmbientMotionIfNeeded];
}

- (void)handleTimeChange
{
    // Time crossed hour / day / DST → refresh hero
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshHeroSectionAppearance];
    });
}



#pragma mark - Categories Selection

- (BOOL)isSelected:(PPHomeItem *)item
{
    // "All" option
    if ([item.payload isKindOfClass:NSString.class]) {
        return self.selectedCategory == nil;
    }

    if (![item.payload isKindOfClass:MainKindsModel.class]) {
        return NO;
    }

    MainKindsModel *kind = (MainKindsModel *)item.payload;

    if (!self.selectedCategory) {
        return NO;
    }

    return kind.ID == self.selectedCategory.ID;
}


- (PPHomeHeaderConfig *)headerConfigForSection:(PPHomeSection)section
{
    PPHomeHeaderConfig *cfg = [PPHomeHeaderConfig new];

    cfg.section = section;
    cfg.hidden = YES; // default SAFE
    NSString *arrowImage = Language.isRTL ?  @"arrow.left" :  @"arrow.right";

    switch (section) {
        case PPHomeSectionSuggestions: {
            cfg.hidden = NO;
            cfg.title = kLang(@"SuggestedForYou");
            //cfg.actionTitle = kLang(@"ShowLess");
            cfg.iconName = arrowImage;
             cfg.subtitle = kLang(@"RecommendedForYouHint");

            NSDictionary *event =
                [[PPBrowseHistoryManager shared] latestEvent];

            if (event) {
                NSInteger kindID = [event[@"kind"] integerValue];
                PPBrowseItemType type = [event[@"type"] integerValue];

                MainKindsModel *kind = [self resolveMainKindWithID:kindID];
                if (kind) {
                    NSString *typeKey =
                        type == PPBrowseItemTypeAd
                        ? kLang(@"BrowseType_Ads")
                        : type == PPBrowseItemTypeAccessory
                            ? kLang(@"BrowseType_Accessories")
                            : kLang(@"BrowseType_Services");

                    cfg.subtitle =
                        [NSString stringWithFormat:
                         kLang(@"BecauseYouViewedFormat"),
                         typeKey,kind.KindName
                         ];
                }
            }

            break;
        }

        case PPHomeSectionCurrentOrders: {
            cfg.hidden = !self.isCurrentOrdersExpanded ||
                         !(self.currentOrdersLoading || [self pp_featuredHomeOrder] != nil);
            cfg.title = kLang(@"Home_LastOrderTitle");
            cfg.subtitle = kLang(@"Home_LastOrderSubtitle");
            cfg.actionTitle = kLang(@"OrderHistory");
            cfg.iconName = arrowImage;
            break;
        }

        case PPHomeSectionMainKinds:
        {
            cfg.hidden = NO;
            cfg.title = kLang(@"MainCategories");
            cfg.actionTitle = self.isMainKindsExpanded
                ? kLang(@"ShowLess")
                : kLang(@"ShowAll");

            cfg.iconName = self.isMainKindsExpanded
                ? @"chevron.up"
                : @"chevron.down";

            cfg.menu = nil; // IMPORTANT – header tap controls layout
            break;
        }

        case PPHomeSectionAccessories: {
            cfg.hidden = NO;
            cfg.title = kLang(@"Accessories");
           // cfg.actionTitle = kLang(@"ShowAll");
            cfg.iconName = @"list.bullet";

            cfg.menu =
                [PPActionButton generateActionsForMainKind:MKM.MainKindsArray
                                                 tintColor:AppPrimaryTextClr
                                                   handler:^(MainKindsModel *category) {
                [self handleDeepLinkWithTarget:PPDeepLinkTargetAccessories
                                      mainKind:category
                                        source:PPInputSourceHomeAccessoriesSection];
            }];
            break;
        }

        case PPHomeSectionAdsNearBy: {
            cfg.hidden = NO;
            if (self.nearbyShowingRecentlyAdded) {
                cfg.title = kLang(@"Home_RecentlyAdded") ?: @"Recently Added";
            } else {
                cfg.title = kLang(@"Home_NearbyAds");
            }
           // cfg.actionTitle = kLang(@"ShowAll");
            cfg.iconName = arrowImage;
            break;
        }

        case PPHomeSectionNearbyServices: {
            cfg.hidden = (self.nearbyServiceProviders.count == 0 && !self.nearbyServicesLoading);
            if (self.nearbyServicesShowingLatest) {
                cfg.title = kLang(@"Home_ServiceProviders") ?: @"Service Providers";
            } else {
                cfg.title = kLang(@"Home_NearbyServiceProviders") ?: @"Nearby Service Providers";
            }
            cfg.subtitle = kLang(@"Home_ServiceProvidersSubtitle") ?: @"Find grooming, training & more";
            cfg.iconName = arrowImage;
            break;
        }

        case PPHomeSectionLastFood: {
            cfg.hidden = self.lastFoodAccessories.count == 0;
            cfg.title = kLang(@"Home_LastFoodAdded") ?: @"Last Food Added";
            cfg.subtitle = kLang(@"Home_LastFoodSubtitle") ?: @"Recently added pet food";
            cfg.iconName = arrowImage;
            break;
        }

        case PPHomeSectionBuyAgain: {
            cfg.hidden = self.buyAgainEntries.count == 0;
            cfg.title = kLang(@"Home_BuyAgainTitle");
            cfg.subtitle = kLang(@"Home_BuyAgainSubtitle");
            cfg.actionTitle = kLang(@"ShowAll");
            cfg.iconName = arrowImage;
            break;
        }

        default:
            break;
    }

    return cfg;
}

#pragma mark - CollectionView


- (void)setupCollectionView {
    if (self.collectionView) {
        return;
    }

    self.layoutManager =
        [[PPHomeLayoutManager alloc] initWithMainKindsExpanded:self.isMainKindsExpanded];
    self.layoutManager.isCurrentOrdersExpanded = self.isCurrentOrdersExpanded;

    __weak typeof(self) weakSelf = self;
    self.layoutManager.sectionIdentifierProvider = ^PPHomeSection(NSInteger sectionIndex) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.dataSource) return PPHomeSectionHero;
        NSDiffableDataSourceSnapshot *snapshot = self.dataSource.snapshot;
        if (sectionIndex >= 0 && sectionIndex < snapshot.sectionIdentifiers.count) {
            return (PPHomeSection)[snapshot.sectionIdentifiers[sectionIndex] integerValue];
        }
        return PPHomeSectionHero;
    };

    self.layoutManager.itemCountProvider = ^NSInteger(NSInteger sectionIndex) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.dataSource) return 0;
        NSDiffableDataSourceSnapshot *snapshot = self.dataSource.snapshot;
        if (sectionIndex >= 0 && sectionIndex < snapshot.sectionIdentifiers.count) {
            NSNumber *sectionID = snapshot.sectionIdentifiers[sectionIndex];
            return [snapshot numberOfItemsInSection:sectionID];
        }
        return 0;
    };

    UICollectionViewCompositionalLayout *layout =
        [self.layoutManager buildLayout];

    self.collectionView =
        [[UICollectionView alloc] initWithFrame:CGRectZero
                           collectionViewLayout:layout];

    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.backgroundColor = UIColor.clearColor;
    self.collectionView.semanticContentAttribute = PPHomeCurrentSemanticAttribute();
    self.collectionView.delegate = self;
    self.collectionView.prefetchingEnabled = YES;
    self.collectionView.prefetchDataSource = self;


    //self.collectionView.contentInset = UIEdgeInsetsMake(0, 6, 6, 6);
    self.collectionView.scrollIndicatorInsets = self.collectionView.contentInset;
    self.collectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;


    [self.view addSubview:self.collectionView];

    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView.topAnchor
            constraintEqualToAnchor:self.view.topAnchor],
         [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
         [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
         [self.collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:0]
    ]];

    [self.collectionView registerClass:PPHomeHeroCell.class
            forCellWithReuseIdentifier:PPHomeHeroCell.reuseIdentifier];
    [self.collectionView registerClass:PPHomeOrderStatusCell.class
            forCellWithReuseIdentifier:PPHomeOrderStatusCell.reuseIdentifier];
    [self.collectionView registerClass:PPCategoryCardCell.class forCellWithReuseIdentifier:PPCategoryCardCell.reuseIdentifier];
    [self.collectionView registerClass:PPUniversalCell.class forCellWithReuseIdentifier:PPUniversalCell.reuseIdentifier];
    [self.collectionView registerClass:PPModerHomeCell.class
            forCellWithReuseIdentifier:PPModerHomeCell.reuseIdentifier];
    [self.collectionView registerClass:PPModernHomeActionCell.class
            forCellWithReuseIdentifier:PPModernHomeActionCell.reuseIdentifier];
    [self.collectionView registerClass:PPHomeActionCell.class forCellWithReuseIdentifier:@"PPHomeActionCell"];
    [self.collectionView registerClass:PPHomePetProfileCardCell.class
            forCellWithReuseIdentifier:PPHomePetProfileCardCell.reuseIdentifier];
    [self.collectionView registerClass:PPHomePremiumCareCell.class
            forCellWithReuseIdentifier:PPHomePremiumCareCell.reuseIdentifier];
    [self.collectionView registerClass:PPHomePremiumSearchCell.class
            forCellWithReuseIdentifier:@"PPHomePremiumSearchCell"];
    

    [self.collectionView registerClass:PPCarouselContainerCell.class forCellWithReuseIdentifier:@"PPCarouselContainerCell"];
    [self.collectionView registerClass:PPHomeServicesCell.class forCellWithReuseIdentifier:PPHomeServicesCell.reuseIdentifier];
    [self.collectionView registerClass:PPBannerCollectionCell.class forCellWithReuseIdentifier:PPBannerCollectionCell.reuseIdentifier];
    [self.collectionView registerClass:PetAdoptCollectionViewCell.class forCellWithReuseIdentifier:@"PetAdoptCollectionViewCell"];

    [self.collectionView registerClass:PPSectionHeaderView.class
            forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                   withReuseIdentifier:@"PPSectionHeaderView"];

    [self.collectionView registerClass:PPCategoryCardCell.class
            forCellWithReuseIdentifier:PPCategoryCardCell.reuseIdentifier];
}


- (void)reloadCarouselBanner
{
    NSDiffableDataSourceSnapshot *snapshot = self.dataSource.snapshot;

    NSArray *items = [self pp_safeItemsInSection:PPHomeSectionCarousel
                                     fromSnapshot:snapshot];
    if (items.count == 0) return;

    [self pp_reconfigureHomeItems:items inSnapshot:snapshot];
}

- (void)pp_configureBannerCell:(PPBannerCollectionCell *)cell
                       forItem:(PPHomeItem *)item
{
    if (!cell) return;

    if ([item.payload isKindOfClass:NSArray.class]) {
        NSArray *promoCards = (NSArray *)item.payload;
        BOOL hasPromoCardObjects =
            promoCards.count > 0 &&
            [promoCards.firstObject isKindOfClass:PPHomePromoCarouselCard.class];

        if (hasPromoCardObjects) {
            __weak typeof(self) weakSelf = self;
            [cell configureWithPromoCards:(NSArray<PPHomePromoCarouselCard *> *)promoCards
                                onCardTap:^(PPHomePromoCarouselCard *card) {
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;
                [self pp_handlePromoCardTap:card interaction:@"card"];
            }
                             onPrimaryTap:^(PPHomePromoCarouselCard *card) {
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;
                [self pp_handlePromoCardTap:card interaction:@"primary"];
            }
                           onSecondaryTap:^(PPHomePromoCarouselCard *card) {
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;
                [self pp_handlePromoCardTap:card interaction:@"secondary"];
            }];
            return;
        }
    }

    // 🔒 Fall through to legacy banners when no promo cards (NSNull or
    // empty array). A short-circuit on NSNull here used to wipe the carousel
    // after a Home Control rebuild, because applyBaseSnapshot constructs a
    // fresh carousel item with payload=NSNull when promoCarouselCards hasn't
    // landed yet — even though the legacy banner data is available.
    MainBannerModel *homeTop = [self pp_homeTopCarouselBannerGroup];
    if (!homeTop || homeTop.childBanners.count == 0) {
        [cell configurePlaceholder];
        return;
    }

    [cell configureWithBanners:homeTop.childBanners
                         group:homeTop
                      delegate:self];
}





#pragma mark - DataSource
- (void)configureDataSource {
    __weak typeof(self) weakSelf = self;

    self.dataSource =
        [[UICollectionViewDiffableDataSource alloc]
         initWithCollectionView:self.collectionView
                   cellProvider:^UICollectionViewCell *_Nullable
             (UICollectionView *collectionView, NSIndexPath *indexPath, PPHomeItem *item) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return [collectionView dequeueReusableCellWithReuseIdentifier:PPUniversalCell.reuseIdentifier
                                                             forIndexPath:indexPath];
        }
        PPHomeSection section = [strongSelf sectionTypeForIndexPath:indexPath];

        if (section == PPHomeSectionHero) {
            PPHomeHeroCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:PPHomeHeroCell.reuseIdentifier
                                                          forIndexPath:indexPath];
            [strongSelf pp_configureHeroCell:cell];
            return cell;
        }

        if (section == PPHomeSectionQuickActions) {
            PPModernHomeActionCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:PPModernHomeActionCell.reuseIdentifier
                                                          forIndexPath:indexPath];
            if (@available(iOS 13.0, *)) {
                cell.overrideUserInterfaceStyle = UIUserInterfaceStyleUnspecified;
            }
            PPHomeQuickActionModel *quickAction =
                [item.payload isKindOfClass:PPHomeQuickActionModel.class]
                ? (PPHomeQuickActionModel *)item.payload
                : nil;
            if (quickAction) {
                [cell configureWithQuickAction:quickAction];
            } else {
                [cell configureWithTitle:@"" systemIcon:@"sparkles"];
            }

            __weak typeof(strongSelf) weakHome = strongSelf;
            cell.onTap = ^{
                __strong typeof(weakHome) self = weakHome;
                if (!self || !quickAction) {
                    return;
                }
                [self handleQuickActionSelection:quickAction];
            };
            return cell;
        }

        if (section == PPHomeSectionCurrentOrders) {
            PPHomeOrderStatusCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:PPHomeOrderStatusCell.reuseIdentifier
                                                          forIndexPath:indexPath];
            BOOL expanded = strongSelf.isCurrentOrdersExpanded;

            if (item.payload == [NSNull null] || ![item.payload isKindOfClass:PPOrder.class]) {
                [cell configurePlaceholderExpanded:expanded];
                return cell;
            }

            PPOrder *order = (PPOrder *)item.payload;
            [cell configureWithOrderReference:[order displayOrderReference]
                             orderKickerTitle:[strongSelf pp_homeOrderKickerTitle:order]
                              previewImageURLs:[strongSelf pp_homeOrderPreviewImageURLs:order limit:3]
                                         meta:[strongSelf pp_homeOrderMetaText:order]
                                  statusTitle:[strongSelf pp_homeOrderStatusTitle:order]
                                   statusHint:[strongSelf pp_homeOrderStatusHint:order]
                                     progress:[strongSelf pp_homeOrderProgress:order]
                                   footerText:[strongSelf pp_homeOrderFooterText:order]
                                  statusColor:[strongSelf pp_homeOrderStatusColor:order]
                               statusIconName:[strongSelf pp_homeOrderStatusIconName:order]
                                  actionTitle:(kLang(@"order_action_track") ?: @"Track order")
                                     expanded:expanded];

            // 🎯 Ensure gradient layers are matched to final bounds on first load/re-config
            [cell refreshDecorativeLayersForCurrentBounds];

            __weak typeof(strongSelf) weakHome = strongSelf;
            cell.onTrackTap = ^{
                __strong typeof(weakHome) self = weakHome;
                if (!self) return;
                [self pp_openOrderDetailsForOrder:order];
            };
            cell.onHistoryTap = ^{
                __strong typeof(weakHome) self = weakHome;
                if (!self) return;
                [self handleSeeAllForSection:PPHomeSectionCurrentOrders];
            };
            cell.onCollapseTap = ^{
                __strong typeof(weakHome) self = weakHome;
                if (!self) return;
                BOOL shouldExpand = !self.isCurrentOrdersExpanded;
                [self pp_setCurrentOrdersExpanded:shouldExpand animated:YES];
                if (shouldExpand) {
                    [self pp_scrollCurrentOrdersSectionIntoViewAnimated:YES];
                }
            };
            return cell;
        }

        if (section == PPHomeSectionPetProfile) {
            PPHomePetProfileCardCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:PPHomePetProfileCardCell.reuseIdentifier
                                                          forIndexPath:indexPath];
            [cell configureWithDefaultPet:strongSelf.defaultPetProfile
                                 petCount:strongSelf.petProfiles.count
                                isLoading:strongSelf.petProfilesLoading];
            return cell;
        }
   
            if ( section == PPHomeSectionPremiumSearch) {
                PPHomePremiumSearchCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:@"PPHomePremiumSearchCell"
                                                              forIndexPath:indexPath];

                __weak typeof(strongSelf) weakHome = strongSelf;
                cell.onTap = ^{
                    __strong typeof(weakHome) self = weakHome;
                    if (!self) return;
                    [self pp_openSmartSearch];
                };

                return cell;
            }

        if ( section == PPHomeSectionPremiumCare) {
            PPHomePremiumCareCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:PPHomePremiumCareCell.reuseIdentifier
                                                          forIndexPath:indexPath];
            [cell configureWithAnimationName:[strongSelf pp_currentPremiumCareAnimationName]];
            return cell;
        }

        if (section == PPHomeSectionCarousel) {

            PPBannerCollectionCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:PPBannerCollectionCell.reuseIdentifier
                                                          forIndexPath:indexPath];
            [strongSelf pp_configureBannerCell:cell forItem:item];
            return cell;
        }

        /*
        if (indexPath.section == PPHomeSectionCategoriesOptions) {
            PPCategoryCardCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:
                    PPCategoryCardCell.reuseIdentifier
                                                            forIndexPath:indexPath];
            BOOL isAll = [item.payload isKindOfClass:NSString.class];
            MainKindsModel *kind = isAll ? nil : (MainKindsModel *)item.payload;

            // selection state
            BOOL selected = NO;
            if (isAll) {
                selected = (self.selectedCategory == nil);
            } else if (self.selectedCategory) {
                selected = (kind.ID == self.selectedCategory.ID);
            }

            [cell configureWithMainKind:kind
                                    isAll:isAll
                                selected:selected];

            // Wire up selection for category options
            __weak typeof(self) weakSelf = self;
            cell.onSelect = ^(MainKindsModel *kind, BOOL isAll) {
                if (isAll) {
                    [weakSelf didSelectCategory:nil];   // "All"
                } else {
                    [weakSelf didSelectCategory:kind];
                }
            };

            return cell;
        }
        if (indexPath.section == PPHomeSectionCategoriesItems) {
            PPUniversalCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:
                    PPUniversalCell.reuseIdentifier
                                                            forIndexPath:indexPath];

            PPUniversalCellViewModel *vm = item.universalViewModel;
            vm.indexPath = indexPath;

            [cell applyViewModel:vm
                            context:PPCellForVets
                        layoutMode:PPCellLayoutModeSquare
                    discountMode:PPDiscountStylePlain
                        imageLoader:^(UIImageView *iv, NSString *url, UIImage *ph, UIView *card) {
                [GM pp_setImageURL:url imageView:iv placeholder:@"placeholder"];
            }];

            return cell;
        }
        */

        if (section == PPHomeSectionServices) {
            PPHomeServicesCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:PPHomeServicesCell.reuseIdentifier
                                                                                 forIndexPath:indexPath];

            if (item.payload == [NSNull null]) {
                [cell configureSkeleton];
                return cell;
            }

            PPHomeServiceItem *service = (PPHomeServiceItem *)item.payload;
            [cell configureWithService:service];

            __weak typeof(cell) weakCell = cell;
             cell.onTap = ^{
                __strong typeof(weakCell) cell = weakCell;
                NSIndexPath *path = [collectionView indexPathForCell:cell];

                if (path) {
                    NSLog(@"onTap");
                    [strongSelf collectionView:collectionView
                        didSelectItemAtIndexPath:path];
                }
            };
            cell.onTapMenu = ^(PPHomeServiceItem *_Nonnull service, MainKindsModel *_Nonnull mainKindModel) {
                NSLog(@"onTapMenu %ld", mainKindModel.ID);
                PPDeepLinkTarget targt = service.type == PPHomeServiceTypeGrooming ? PPDeepLinkTargetGrooming : service.type == PPHomeServiceTypeTraining ? PPDeepLinkTargetTraning : PPDeepLinkTargetFood;
                [weakSelf handleDeepLinkWithTarget:targt
                                          mainKind:mainKindModel
                                            source:PPInputSourceHomeServicesSection];
            };

            return cell;
        }


            if (section == PPHomeSectionAdopt) {
            PetAdoptCollectionViewCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:@"PetAdoptCollectionViewCell"
                                                          forIndexPath:indexPath];

            [cell configureWithTitle:kLang(@"Adopt a Pet")
                            subtitle:kLang(@"Find your new best friend")
                           seedImage:[UIImage imageNamed:@"icn_cat"]];

            __weak typeof(cell) weakCell = cell;
            cell.onTap = ^{
                __strong typeof(weakCell) tappedCell = weakCell;
                NSIndexPath *path = [collectionView indexPathForCell:tappedCell];
                if (path) {
                    [strongSelf collectionView:collectionView didSelectItemAtIndexPath:path];
                }
            };

            return cell;
        }

                if (section == PPHomeSectionSuggestions) {

                if (item.payload == [NSNull null]) {
                    PPUniversalCell *cell =
                            [collectionView dequeueReusableCellWithReuseIdentifier:PPUniversalCell.reuseIdentifier
                                                                      forIndexPath:indexPath];
                        return cell; // height-only placeholder
                    }

            // ✅ REAL CONTENT
            PPUniversalCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:
                    PPUniversalCell.reuseIdentifier
                                                        forIndexPath:indexPath];
            [strongSelf pp_clearUnavailableBuyAgainCoverFromCell:cell];
            cell.delegate = strongSelf;

            PPUniversalCellViewModel *vm = item.universalViewModel;
            if (!vm || !vm.ModelObject) {
                return cell;
            }

            vm.indexPath = indexPath;

            [cell applyViewModel:vm
                         context:vm.modelContext
                      layoutMode:PPCellLayoutModeSquare
                    discountMode:PPDiscountStyleBadge
                     imageLoader:^(UIImageView *iv,
                                   NSString *url,
                                   UIImage *placeholder,
                                   UIView *card) {
                (void)placeholder;
                (void)card;

                UIImage *fallback =
                vm.placeholder ?: [UIImage imageNamed:@"placeholder"];
                iv.image = fallback;

                NSString *currentHash = vm.blurHash;
                __weak UIImageView *weakIV = iv;

                if (currentHash.length > 0) {
                    [strongSelf pp_asyncBlurHashImageForHash:currentHash
                                                         size:CGSizeMake(40, 40)
                                                   completion:^(UIImage * _Nullable blurImage) {
                        if (!blurImage || !weakIV) {
                            return;
                        }
                        if (![currentHash isEqualToString:vm.blurHash]) {
                            return;
                        }
                        [UIView performWithoutAnimation:^{
                            if (weakIV.image == fallback) {
                                weakIV.image = blurImage;
                            }
                        }];
                    }];
                }

                [[PPImageLoaderManager shared]
                    setImageOnImageView:iv
                                     url:url
                              placeholder:fallback
                          transitionStyle:PPImageTransitionStyleNone
                               complation:nil];
            }];

            return cell;
        }


                if (section == PPHomeSectionMainKinds) {

                PPModerHomeCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:PPModerHomeCell.reuseIdentifier
                                                          forIndexPath:indexPath];
                if (@available(iOS 13.0, *)) {
                    cell.overrideUserInterfaceStyle = UIUserInterfaceStyleUnspecified;
                }

                // ⛔️ HARD GUARD – skeleton or invalid payload
                if (![item.payload isKindOfClass:MainKindsModel.class]) {
                    // skeleton cell
                        [cell configureWithMainKind:nil
                                              isAll:YES
                                          selected:(strongSelf.selectedCategory == nil)];
                        return cell;
                    }

                MainKindsModel *kind = (MainKindsModel *)item.payload;
                BOOL isAll = (kind.ID == -1);


                // selection state
                    BOOL selected = NO;
                    if (isAll) {
                        selected = (strongSelf.selectedCategory == nil);
                    } else if (strongSelf.selectedCategory) {
                        selected = (kind.ID == strongSelf.selectedCategory.ID);
                    }

                if (selected) {
                    NSLog(@"[Home][MainKinds][Cell] ✅ SELECTED → %@", kind.KindName);
                }

                [cell configureWithMainKind:kind
                                        isAll:isAll
                                    selected:selected];

                __weak typeof(strongSelf) weakStrongSelf = strongSelf;
                cell.onSelect = ^(MainKindsModel *kind, BOOL isAll) {
                    __strong typeof(weakStrongSelf) strongSelf = weakStrongSelf;
                    if (!strongSelf) return;

                    // ✅ ONLY update selection state here
                    strongSelf.selectedCategory = isAll ? nil : kind;

                    if (isAll) {
                        NSLog(@"[Home][MainKinds][Action] ALL selected → deep link");
                        [strongSelf handleDeepLinkWithTarget:PPDeepLinkTargetAllCategories
                                                     mainKind:nil
                                                       source:PPInputSourceHomeMainKindsSection];
                    } else {
                        NSLog(@"[Home][MainKinds][Action] Kind selected → %@",
                              kind.KindName);
                        [strongSelf handleMainKindSelection:(MainKindsModel *)item.payload];
                    }




                     // 🔁 Refresh main kinds visuals only
                     NSDiffableDataSourceSnapshot *snapshot = strongSelf.dataSource.snapshot;
                     NSArray *items =
                         [strongSelf pp_safeItemsInSection:PPHomeSectionMainKinds
                                              fromSnapshot:snapshot];
                     [strongSelf pp_reconfigureHomeItems:items inSnapshot:snapshot];


                };


                return cell;
            }

        if (section == PPHomeSectionAdsNearBy &&
            [item.payload isKindOfClass:NSString.class]) {
            PPHomeActionCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:PPHomeActionCell.reuseIdentifier
                                                          forIndexPath:indexPath];
            NSString *token = (NSString *)item.payload;
            if ([token isEqualToString:@"nearby-empty-state"]) {
                [cell configureWithTitle:kLang(@"No nearby ads available")
                              systemIcon:@"location.slash.fill"];
                __weak typeof(strongSelf) weakSelfAction = strongSelf;
                cell.onTap = ^{
                    __strong typeof(weakSelfAction) self = weakSelfAction;
                    if (!self) return;
                    self.nearbyRadiusKm = MIN(PPNearbyExpandedRadiusKm, self.nearbyRadiusKm + 3.0);
                    [self refreshNearbyAdsForce:YES reason:@"expand-radius"];
                };
            } else {
                [cell configureWithTitle:kLang(@"Loading...")
                              systemIcon:@"hourglass"];
                cell.onTap = nil;
            }
            return cell;
        }

        if (section == PPHomeSectionNearbyServices &&
            [item.payload isKindOfClass:NSString.class]) {
            PPHomeActionCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:PPHomeActionCell.reuseIdentifier
                                                          forIndexPath:indexPath];
            NSString *token = (NSString *)item.payload;
            if ([token isEqualToString:@"services-empty-state"]) {
                [cell configureWithTitle:kLang(@"Home_NoServicesAvailable") ?: @"No services available"
                              systemIcon:@"wrench.and.screwdriver"];
                cell.onTap = nil;
            } else {
                [cell configureWithTitle:kLang(@"Loading...")
                              systemIcon:@"hourglass"];
                cell.onTap = nil;
            }
            return cell;
        }


            PPUniversalCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:PPUniversalCell.reuseIdentifier forIndexPath:indexPath];
            [strongSelf pp_clearUnavailableBuyAgainCoverFromCell:cell];
            cell.delegate = strongSelf;
            cell.delegate = self;
        if (item.universalViewModel) {


            PPUniversalCellViewModel *vm = item.universalViewModel;
            vm.indexPath = indexPath;
            [cell applyViewModel:vm
                         context:vm.modelContext
                      layoutMode:PPCellLayoutModeSquare
                    discountMode:PPDiscountStyleBadge
                     imageLoader:^(UIImageView *iv,
                                   NSString *url,
                                   UIImage *placeholder,
                                   UIView *card) {
                (void)placeholder;
                (void)card;

                UIImage *fallback =
                vm.placeholder ?: [UIImage imageNamed:@"placeholder"];
                iv.image = fallback;

                NSString *currentHash = vm.blurHash;
                __weak UIImageView *weakIV = iv;

                if (currentHash.length > 0) {
                    [strongSelf pp_asyncBlurHashImageForHash:currentHash
                                                         size:CGSizeMake(40, 40)
                                                   completion:^(UIImage * _Nullable blurImage) {
                        if (!blurImage || !weakIV) {
                            return;
                        }
                        if (![currentHash isEqualToString:vm.blurHash]) {
                            return;
                        }
                        [UIView performWithoutAnimation:^{
                            if (weakIV.image == fallback) {
                                weakIV.image = blurImage;
                            }
                        }];
                    }];
                }

                [[PPImageLoaderManager shared]
                 setImageOnImageView:iv
                                  url:url
                           placeholder:fallback
                       transitionStyle:PPImageTransitionStyleNone
                            complation:nil];
            }];

            if (section == PPHomeSectionBuyAgain &&
                [vm.ModelObject isKindOfClass:PPHomeBuyAgainSnapshotItem.class]) {
                [strongSelf pp_applyUnavailableBuyAgainCoverToCell:cell
                                                      snapshotItem:(PPHomeBuyAgainSnapshotItem *)vm.ModelObject];
            } else {
                [strongSelf pp_clearUnavailableBuyAgainCoverFromCell:cell];
            }

        }

        return cell;
    }];

    // =========================
    // Supplementary Views
    // =========================


    self.dataSource.supplementaryViewProvider =
    ^UICollectionReusableView * _Nullable(UICollectionView *collectionView,
                                          NSString *kind,
                                          NSIndexPath *indexPath)
    {
        if (![kind isEqualToString:UICollectionElementKindSectionHeader]) {
            return nil;
        }

        NSArray *sectionIDs = weakSelf.dataSource.snapshot.sectionIdentifiers;
        if (indexPath.section >= (NSInteger)sectionIDs.count) return nil;
        NSNumber *sectionID = sectionIDs[indexPath.section];
        PPHomeSection section = (PPHomeSection)sectionID.integerValue;

        PPHomeHeaderConfig *cfg =
            [weakSelf headerConfigForSection:section];

        PPSectionHeaderView *header =
        [collectionView dequeueReusableSupplementaryViewOfKind:kind
                                           withReuseIdentifier:@"PPSectionHeaderView"
                                                  forIndexPath:indexPath];

        if (@available(iOS 13.0, *)) {
            header.overrideUserInterfaceStyle = UIUserInterfaceStyleUnspecified;
        }

        if (cfg.hidden) {
            header.hidden = YES;
            return header;
        }

        header.hidden = NO;

        [header configureWithTitle:cfg.title
                          subtitle:cfg.subtitle
                       actionTitle:cfg.actionTitle
                          iconName:cfg.iconName
                              menu:cfg.section == PPHomeSectionMainKinds ? nil : cfg.menu
                     ppHomeSection:cfg.section];

        header.onTap = ^{
            [weakSelf handleSeeAllForSection:cfg.section];
        };

        return header;
    };



    /*self.dataSource.supplementaryViewProvider =
    ^UICollectionReusableView * _Nullable(UICollectionView *collectionView,
                                          NSString *kind,
                                          NSIndexPath *indexPath)
    {

        NSNumber *sectionID = weakSelf.dataSource.snapshot.sectionIdentifiers[indexPath.section];
        PPHomeSection section = (PPHomeSection)sectionID.integerValue;

        if (section == PPHomeSectionMainKinds)
        {
            PPCollectionSectionHeader *header =
                [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                                                   withReuseIdentifier:@"PPCollectionSectionHeader"
                                                          forIndexPath:indexPath];

            [header configureWithTitle:@"إدارة الإنتاج"
                              subtitle:@"آخر العناصر المضافة"
                           actionTitle:@"عرض الكل"
                                action:^{
                                    [weakSelf handleSeeAllForSection:PPHomeSectionMainKinds];
                                }];

            return header;
        }

        PPSectionHeaderView *header =
        [collectionView dequeueReusableSupplementaryViewOfKind:kind
                                           withReuseIdentifier:@"PPSectionHeaderView"
                                                  forIndexPath:indexPath];

        PPHomeHeaderConfig *cfg =
        [weakSelf headerConfigForSection:section];

        if (cfg.hidden) {
            header.hidden = YES;
            return header;
        }

        header.hidden = NO;

        if (cfg.subtitle.length > 0) {
            [header configureWithTitle:cfg.title
                              subtitle:cfg.subtitle
                           actionTitle:cfg.actionTitle
                              iconName:cfg.iconName
                                  menu:cfg.section == PPHomeSectionMainKinds ? nil : cfg.menu
                         ppHomeSection:cfg.section];
        } else {
            [header configureWithTitle:cfg.title
                           actionTitle:cfg.actionTitle
                              iconName:cfg.iconName
                                  menu:cfg.section == PPHomeSectionMainKinds ? nil : cfg.menu
                         ppHomeSection:cfg.section];
        }

        header.onTap = ^{
            if (cfg.section == PPHomeSectionMainKinds) {
                [weakSelf handleSeeAllForSection:cfg.section];
                //[weakSelf handleMainKindsHeaderTap];
            } else {
                [weakSelf handleSeeAllForSection:cfg.section];
            }
        };

        return header;
    };*/

}

- (void)invalidateHeaderForSection:(PPHomeSection)section
{
    NSInteger sectionIndex = [self sectionIndexForType:section];
    if (sectionIndex == NSNotFound) return;

    UICollectionViewLayout *layout = self.collectionView.collectionViewLayout;

    if ([layout isKindOfClass:UICollectionViewCompositionalLayout.class]) {
        [layout invalidateLayout];
    }
}
#pragma mark - MainKinds Header Tap

- (void)handleMainKindsHeaderTap
{
    NSLog(@"[Home][MainKinds] Header tapped → open ALL categories (PPDataViewVC)");

    if (self.mainKinds.count == 0) {
        NSLog(@"[Home][MainKinds] ❌ No categories available");
        return;
    }

    // Build input object for PPDataViewVC
    PPDataViewInput *input = [PPDataViewInput inputWithMainKindsArr:self.mainKinds sourceTarget:PPDeepLinkTargetAllCategories source:PPInputSourceHomeMainKindsSection];
    PPDataViewVC *vc =  [[PPDataViewVC alloc] initWithInput:input];
    vc.pp_transitionStyle = PPTransitionStyleNone;
    input.title = kLang(@"MainCategories");
    if (![PPHomeHelper pushViewControllerSafely:vc from:self animated:YES]) {
        return;
    }
    //input.layout = PPDataLayoutGrid;                 // ✅ grid lives here
    //input.items = ;


}

#pragma mark - Data
- (void)loadData {
    __weak typeof(self) weakSelf = self;

    /*
     [[PetAdManager sharedManager]
      fetchLatestAdsWithLimit:8
                   completion:^(NSArray<PetAd *> *ads) {
         weakSelf.ads = ads ? : @[];
         weakSelf.adsLoaded = YES;
         [weakSelf tryApplySnapshot];
     }];
     */

    [[PetAccessoryManager sharedManager] fetchLatestAccessoriesWithLimit:50
                          completion:^(NSArray *accessories, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [PPHUD showError:kLang(@"SomethingWentWrong")];
            });
            return;
        }

        NSArray *source = accessories ?: @[];
        NSArray *sorted =
        [source sortedArrayUsingComparator:^NSComparisonResult(PetAccessory *a, PetAccessory *b) {

            BOOL aHasDiscount = (a.discountPercent > 0 || a.discountAmount > 0);
            BOOL bHasDiscount = (b.discountPercent > 0 || b.discountAmount > 0);

            if (aHasDiscount && !bHasDiscount) return NSOrderedAscending;
            if (!aHasDiscount && bHasDiscount) return NSOrderedDescending;

            NSDate *aDate = a.createdAt ?: [NSDate distantPast];
            NSDate *bDate = b.createdAt ?: [NSDate distantPast];
            NSComparisonResult dateOrder = [bDate compare:aDate];
            if (dateOrder != NSOrderedSame) return dateOrder;

            NSString *aID = PPSafeString(a.accessoryID);
            NSString *bID = PPSafeString(b.accessoryID);
            return [aID compare:bID options:NSCaseInsensitiveSearch];
        }];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.accessories = sorted;
            self.accessoriesLoaded = YES;
            [self pp_refreshBuyAgainSection];
            [self pp_refreshLastFoodSection];

            // Batch all section reloads into a single layout pass
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            [self reloadSection:PPHomeSectionCurrentOrders];
            [self reloadSection:PPHomeSectionAccessories];
            [self reloadSection:PPHomeSectionSuggestions];
            [self reloadSection:PPHomeSectionLastFood];
            [CATransaction commit];

            [self tryApplySnapshot];
            [self pp_prefetchTopImagesWithLimit:20];
        });

    }];

    [self refreshCurrentOrdersForce:YES];
    [self refreshNearbyAdsForce:YES reason:@"initial-load"];
    [self refreshNearbyServicesForce:YES];
}

- (void)refreshNearbyAdsForce:(BOOL)force reason:(NSString *)reason
{
    if (!self.hasSelectedNearbyCoordinate ||
        !CLLocationCoordinate2DIsValid(self.selectedNearbyCoordinate)) {
        BOOL shouldReloadEmptyNearby =
            self.nearbyLoading ||
            !self.nearbyLoaded ||
            self.nearbyAds.count > 0 ||
            self.nearbyShowingRecentlyAdded;
        self.nearbyAds = @[];
        self.nearbyLoading = NO;
        self.nearbyLoaded = YES;
        self.nearbyShowingRecentlyAdded = NO;
        if (shouldReloadEmptyNearby) {
            [self reloadSection:PPHomeSectionAdsNearBy];
            [self pp_refreshSuggestionsForAppearanceIfNeeded];
        }
        [self tryApplySnapshot];
        return;
    }

    NSDate *now = [NSDate date];
    if (!force && self.lastNearbyRefreshAt) {
        NSTimeInterval elapsed = [now timeIntervalSinceDate:self.lastNearbyRefreshAt];
        if (elapsed < PPNearbyMinimumRefreshInterval && self.hasLastNearbyRefreshCoordinate) {
            CLLocation *last =
                [[CLLocation alloc] initWithLatitude:self.lastNearbyRefreshCoordinate.latitude
                                           longitude:self.lastNearbyRefreshCoordinate.longitude];
            CLLocation *current =
                [[CLLocation alloc] initWithLatitude:self.selectedNearbyCoordinate.latitude
                                           longitude:self.selectedNearbyCoordinate.longitude];
            if ([current distanceFromLocation:last] < 150.0) {
                return;
            }
        }
    }

    self.nearbyRequestToken += 1;
    NSInteger requestToken = self.nearbyRequestToken;
    self.nearbyLoading = YES;
    if (self.nearbyAds.count == 0) {
        [self reloadSection:PPHomeSectionAdsNearBy];
    }

    __weak typeof(self) weakSelf = self;
    [[PetAdManager sharedManager]
        fetchNearbyAdsAtCoordinate:self.selectedNearbyCoordinate
                          radiusKm:self.nearbyRadiusKm
                             limit:30
                          category:0
                        completion:^(NSArray<PetAd *> *ads) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (requestToken != self.nearbyRequestToken) {
            return; // stale response guard
        }

        NSMutableDictionary<NSString *, PetAd *> *uniqueByID = [NSMutableDictionary dictionary];
        for (PetAd *ad in ads ?: @[]) {
            if (!ad.adID.length) continue;
            uniqueByID[ad.adID] = ad;
        }

        NSArray<PetAd *> *deduped =
            [uniqueByID.allValues sortedArrayUsingComparator:^NSComparisonResult(PetAd *a, PetAd *b) {
            NSDate *aDate = a.createdAt ?: a.postedDate ?: [NSDate distantPast];
            NSDate *bDate = b.createdAt ?: b.postedDate ?: [NSDate distantPast];
            NSComparisonResult dateOrder = [bDate compare:aDate];
            if (dateOrder != NSOrderedSame) return dateOrder;
            return [a.adID compare:b.adID options:NSCaseInsensitiveSearch];
        }];
        if (deduped.count < 3) {
            // 🔁 Fallback: show latest 10 ads when fewer than 3 nearby ads found
            [[PetAdManager sharedManager] fetchLatestAdsWithLimit:10
                                                       completion:^(NSArray<PetAd *> *latestAds) {
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;

                self.nearbyAds = latestAds ?: @[];
                self.nearbyShowingRecentlyAdded = YES;
                self.nearbyLoaded = YES;
                self.nearbyLoading = NO;
                self.lastNearbyRefreshAt = [NSDate date];
                self.lastNearbyRefreshCoordinate = self.selectedNearbyCoordinate;
                self.hasLastNearbyRefreshCoordinate = YES;

                [self reloadSection:PPHomeSectionAdsNearBy];
                [self reloadSection:PPHomeSectionSuggestions];
                [self tryApplySnapshot];
                [self pp_prefetchTopImagesWithLimit:24];
            }];
            return;
        } else {
            self.nearbyAds = deduped;
            self.nearbyShowingRecentlyAdded = NO;
        }
        self.nearbyLoaded = YES;
        self.nearbyLoading = NO;
        self.lastNearbyRefreshAt = [NSDate date];
        self.lastNearbyRefreshCoordinate = self.selectedNearbyCoordinate;
        self.hasLastNearbyRefreshCoordinate = YES;

        NSLog(@"[HomeNearby] refreshed reason=%@ radius=%.1fkm count=%lu",
              reason, self.nearbyRadiusKm, (unsigned long)self.nearbyAds.count);

        [self reloadSection:PPHomeSectionAdsNearBy];
        [self reloadSection:PPHomeSectionSuggestions];
        [self tryApplySnapshot];
        [self pp_prefetchTopImagesWithLimit:24];

        if (!self.didAutoScrollSuggestions && self.nearbyAds.count > 1) {
            self.didAutoScrollSuggestions = YES;
            [self autoScrollIndextoIndex:2 inSection:PPHomeSectionSuggestions];
        }
    }];
}

#pragma mark - Nearby Services Providers (Smart Section)

- (void)refreshNearbyServicesForce:(BOOL)force
{
    self.nearbyServicesLoading = YES;
    if (self.nearbyServiceProviders.count == 0) {
        [self reloadSection:PPHomeSectionNearbyServices];
    }

    __weak typeof(self) weakSelf = self;

    // Smart logic: if user has a valid location, try nearby first
    if (self.hasSelectedNearbyCoordinate &&
        CLLocationCoordinate2DIsValid(self.selectedNearbyCoordinate)) {

        // Services don't have geolocation yet — go straight to latest
        [[ServicesManager sharedInstance]
            fetchLatestServicesWithLimit:10
                             completion:^(NSArray<ServiceModel *> *services,
                                          NSError *error) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;

            dispatch_async(dispatch_get_main_queue(), ^{
                NSArray *result = services ?: @[];
                if (result.count < 3) {
                    self.nearbyServiceProviders = result;
                    self.nearbyServicesShowingLatest = YES;
                } else {
                    self.nearbyServiceProviders = result;
                    self.nearbyServicesShowingLatest = NO;
                }
                self.nearbyServicesLoaded = YES;
                self.nearbyServicesLoading = NO;
                [self reloadSection:PPHomeSectionNearbyServices];

                if (!self.didAutoScrollNearbyServices && self.nearbyServiceProviders.count > 1) {
                    self.didAutoScrollNearbyServices = YES;
                    [self autoScrollIndextoIndex:1 inSection:PPHomeSectionNearbyServices];
                }
            });
        }];
    } else {
        // No location → always show latest service providers
        [[ServicesManager sharedInstance]
            fetchLatestServicesWithLimit:10
                             completion:^(NSArray<ServiceModel *> *services,
                                          NSError *error) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;

            dispatch_async(dispatch_get_main_queue(), ^{
                self.nearbyServiceProviders = services ?: @[];
                self.nearbyServicesShowingLatest = YES;
                self.nearbyServicesLoaded = YES;
                self.nearbyServicesLoading = NO;
                [self reloadSection:PPHomeSectionNearbyServices];

                if (!self.didAutoScrollNearbyServices && self.nearbyServiceProviders.count > 1) {
                    self.didAutoScrollNearbyServices = YES;
                    [self autoScrollIndextoIndex:1 inSection:PPHomeSectionNearbyServices];
                }
            });
        }];
    }
}

- (void)tryApplySnapshot {
    if (!self.accessoriesLoaded || !self.nearbyLoaded) {
        return;
    }

    // ✅ Data ready → dismiss HUD once
    if ([PPHUD isVisible]) {
        [PPHUD dismiss];
    }

}

- (NSString *)pp_currentHeroRenderSignature
{
    NSString *greeting = [self heroGreetingText] ?: @"";
    NSString *name = [self heroDisplayNameText] ?: @"";
    NSString *location = [self heroCountryText] ?: @"";
    NSString *actionTitle = [self heroLocationActionTitle] ?: @"";
    return [NSString stringWithFormat:@"%@|%@|%@|%ld|%@",
            greeting,
            name,
            location,
            (long)self.nearbyLocationState,
            actionTitle];
}

- (void)pp_configureHeroCell:(PPHomeHeroCell *)cell
{
    if (!cell) return;

    [cell configureWithGreeting:[self heroGreetingText]
                       userName:[self heroDisplayNameText]
                       location:[self heroCountryText]
                  locationState:(PPHomeHeroLocationState)self.nearbyLocationState
                    actionTitle:[self heroLocationActionTitle]];

    __weak typeof(self) weakSelf = self;
    cell.onLocationTap = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self presentHomeLocationSheet];
    };
    cell.onLocationActionTap = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self presentHomeLocationSheet];
    };

    [cell hideOrderPeek:NO];
    cell.onOrderPeekTap = nil;
}

- (void)refreshHeroSectionAppearance
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self refreshHeroSectionAppearance];
        });
        return;
    }

    if (self.heroRefreshScheduled) {
        return;
    }
    self.heroRefreshScheduled = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        self.heroRefreshScheduled = NO;

        if (!self.isViewLoaded || !self.collectionView || !self.dataSource) {
            return;
        }

        [self pp_refreshHomeLocationTitleViewAnimated:YES];

        NSString *renderSignature = [self pp_currentHeroRenderSignature];
        NSInteger sectionIndex = [self sectionIndexForType:PPHomeSectionHero];
        if (sectionIndex == NSNotFound) {
            return;
        }

        NSIndexPath *heroIndexPath = [NSIndexPath indexPathForItem:0 inSection:sectionIndex];
        PPHomeHeroCell *visibleHeroCell =
            (PPHomeHeroCell *)[self.collectionView cellForItemAtIndexPath:heroIndexPath];
        if (visibleHeroCell) {
            [self pp_configureHeroCell:visibleHeroCell];
            self.lastHeroRenderSignature = renderSignature;
            return;
        }

        if ([renderSignature isEqualToString:self.lastHeroRenderSignature]) {
            return;
        }

        NSDiffableDataSourceSnapshot *snapshot = self.dataSource.snapshot;
        NSArray *items = [self pp_safeItemsInSection:PPHomeSectionHero
                                         fromSnapshot:snapshot];
        if (items.count == 0) {
            return;
        }

        [self pp_reconfigureHomeItems:items inSnapshot:snapshot];
        self.lastHeroRenderSignature = renderSignature;
    });
}

// MARK: - Carousel Data

#pragma mark - Carousel Data

- (void)reloadHomeCarousel {
    // Convert ads → carousel items
    if (self.ads.count == 0) {
        self.carouselItems = @[];
        return;
    }

    NSMutableArray<PPCarouselItem *> *items = [NSMutableArray array];


    for (PetAd *ad in self.ads) {

        NSString *imageURL = nil;
        UIImage *placeholder = [UIImage imageNamed:@"placeholder"];

        PetImageItem *firstItem = ad.imageItems.firstObject;
        if (firstItem) {
            imageURL = PPSafeString(firstItem.url);

            if (firstItem.blurHash.length > 0) {
                UIImage *cachedPlaceholder =
                [self.blurHashCache objectForKey:firstItem.blurHash];
                if (cachedPlaceholder) {
                    placeholder = cachedPlaceholder;
                } else {
                    [self pp_asyncBlurHashImageForHash:firstItem.blurHash
                                                  size:CGSizeMake(40, 40)
                                            completion:nil];
                }
            }
        }


        PPCarouselItem *item =
            [PPCarouselItem itemWithIdentifier:PPSafeString(ad.adID)
                                      imageURL:imageURL
                                         title:PPSafeString(ad.adTitle)
                                      subtitle:@""
                              placeholderImage:placeholder];

        [items addObject:item];
    }

    self.carouselItems = items.copy;

}


- (NSInteger)sectionIndexForType:(PPHomeSection)section
{
    NSArray *sections = self.dataSource.snapshot.sectionIdentifiers;

    return [sections indexOfObject:@(section)];
}

- (PPHomeSection)sectionTypeForIndexPath:(NSIndexPath *)indexPath
{
    NSArray<NSNumber *> *sections = self.dataSource.snapshot.sectionIdentifiers;
    if (indexPath.section < sections.count) {
        return (PPHomeSection)sections[indexPath.section].integerValue;
    }
    return (PPHomeSection)indexPath.section;
}

- (void)handleSeeAllForSection:(PPHomeSection)section {
    switch (section) {
        case PPHomeSectionMainKinds: {
            self.isMainKindsExpanded = !self.isMainKindsExpanded;
            self.layoutManager.isMainKindsExpanded = self.isMainKindsExpanded;

            UICollectionViewCompositionalLayout *newLayout =
            [self.layoutManager buildLayout];

            // Capture scroll position to prevent layout jump
            CGPoint savedOffset = self.collectionView.contentOffset;

            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            [self.collectionView setCollectionViewLayout:newLayout animated:NO];
            self.collectionView.contentOffset = savedOffset;
            [self.collectionView layoutIfNeeded];
            [CATransaction commit];

            // Force gradient/overlay re-layout on all visible MainKinds cells
            NSInteger sectionIdx = [self sectionIndexForType:PPHomeSectionMainKinds];
            if (sectionIdx != NSNotFound) {
                NSArray<UICollectionViewCell *> *cells =
                    [self.collectionView visibleCells];
                for (UICollectionViewCell *cell in cells) {
                    NSIndexPath *ip = [self.collectionView indexPathForCell:cell];
                    if (ip && ip.section == sectionIdx) {
                        [cell setNeedsLayout];
                        [cell layoutIfNeeded];
                        cell.alpha = 0.0;
                        cell.transform = CGAffineTransformMakeScale(0.92, 0.92);
                        [UIView animateWithDuration:0.3
                                              delay:0
                             usingSpringWithDamping:0.85
                              initialSpringVelocity:0.3
                                            options:UIViewAnimationOptionCurveEaseOut
                                         animations:^{
                            cell.alpha = 1.0;
                            cell.transform = CGAffineTransformIdentity;
                        } completion:nil];
                    }
                }
            }

            [self refreshMainKindsHeader];
            break;
        }

        case PPHomeSectionCurrentOrders: {
            OrderHistoryViewController *vc = [[OrderHistoryViewController alloc] init];
            [PPHomeHelper pushViewControllerSafely:vc from:self animated:YES];
            break;
        }

        case PPHomeSectionPremiumCare:
            [self openPremiumPetCare];
            break;

        case PPHomeSectionAccessories:
            [self handleDeepLinkWithTarget:PPDeepLinkTargetAccessories
                                  mainKind:nil
                                    source:PPInputSourceHomeAccessoriesSection];
            break;

        case PPHomeSectionAdsNearBy:
            if (!self.hasSelectedNearbyCoordinate) {
                [self openHomeLocationPicker];
                break;
            }
            [self handleDeepLinkWithTarget:PPDeepLinkTargetNewByAds
                                  mainKind:nil
                                    source:PPInputSourceHomeNearBySection];
            break;

        case PPHomeSectionNearbyServices:
            [self handleDeepLinkWithTarget:PPDeepLinkTargetServices
                                  mainKind:nil
                                    source:PPInputSourceHomeServicesSection];
            break;

        case PPHomeSectionSuggestions:
            [self handleDeepLinkWithTarget:PPDeepLinkTargetAllCategories
                                  mainKind:nil
                                    source:PPInputSourceHomeMainKindsSection];
            break;

        case PPHomeSectionBuyAgain:
            [self handleDeepLinkWithTarget:PPDeepLinkTargetAccessories
                                  mainKind:nil
                                    source:PPInputSourceHomeAccessoriesSection];
            break;

        case PPHomeSectionLastFood:
            [self handleDeepLinkWithTarget:PPDeepLinkTargetFood
                                  mainKind:nil
                                    source:PPInputSourceHomeAccessoriesSection];
            break;

        default:
            break;
    }
}

- (void)pp_setCurrentOrdersExpanded:(BOOL)expanded animated:(BOOL)animated
{
    if (self.isCurrentOrdersExpanded == expanded &&
        (!self.layoutManager || self.layoutManager.isCurrentOrdersExpanded == expanded)) {
        [self refreshHeroSectionAppearance];
        return;
    }

    self.isCurrentOrdersExpanded = expanded;

    if (!self.collectionView || !self.layoutManager) {
        [self refreshHeroSectionAppearance];
        return;
    }

    NSInteger sectionIndex = [self sectionIndexForType:PPHomeSectionCurrentOrders];
    NSIndexPath *currentOrderIndexPath = nil;
    if (sectionIndex != NSNotFound &&
        [self.collectionView numberOfItemsInSection:sectionIndex] > 0) {
        currentOrderIndexPath = [NSIndexPath indexPathForItem:0 inSection:sectionIndex];
    }

    PPHomeOrderStatusCell *visibleOrderCell =
        currentOrderIndexPath
        ? (PPHomeOrderStatusCell *)[self.collectionView cellForItemAtIndexPath:currentOrderIndexPath]
        : nil;
    if (![visibleOrderCell isKindOfClass:PPHomeOrderStatusCell.class]) {
        visibleOrderCell = nil;
    }

    // Update the flag — the existing section provider already reads it
    // and returns the correct height on the next layout pass.
    self.layoutManager.isCurrentOrdersExpanded = expanded;
    [self refreshHeroSectionAppearance];

    if (visibleOrderCell) {
        [visibleOrderCell setExpandedState:expanded animated:animated];
    }

    // Invalidate the existing layout instead of rebuilding it entirely.
    // The section provider re-fires and returns the correct section height.
    // Spring animation produces a smooth, jump-free transition without
    // the forced contentOffset restoration that caused the snap.
    __weak typeof(self) weakSelf = self;

    void (^applyInvalidation)(void) = ^{
        [weakSelf.collectionView.collectionViewLayout invalidateLayout];
        [weakSelf.collectionView layoutIfNeeded];
    };

    void (^completionWork)(void) = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !currentOrderIndexPath) return;

        UICollectionViewCell *updatedCell =
            [self.collectionView cellForItemAtIndexPath:currentOrderIndexPath];
        if (![updatedCell isKindOfClass:PPHomeOrderStatusCell.class]) return;

        PPHomeOrderStatusCell *updatedOrderCell = (PPHomeOrderStatusCell *)updatedCell;
        if (updatedOrderCell != visibleOrderCell) {
            [updatedOrderCell setExpandedState:expanded animated:NO];
        }
        [updatedOrderCell refreshDecorativeLayersForCurrentBounds];
    };

    if (animated) {
        [UIView animateWithDuration:0.4
                              delay:0.0
             usingSpringWithDamping:0.88
              initialSpringVelocity:0.0
                            options:UIViewAnimationOptionAllowUserInteraction |
                                    UIViewAnimationOptionBeginFromCurrentState
                         animations:applyInvalidation
                         completion:^(__unused BOOL finished) {
            completionWork();
        }];
    } else {
        applyInvalidation();
        completionWork();
    }
}

- (void)pp_scrollCurrentOrdersSectionIntoViewAnimated:(BOOL)animated
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSInteger sectionIndex = [self sectionIndexForType:PPHomeSectionCurrentOrders];
        if (sectionIndex == NSNotFound || [self.collectionView numberOfItemsInSection:sectionIndex] == 0) {
            return;
        }

        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:sectionIndex];
        UICollectionViewLayoutAttributes *attributes =
            [self.collectionView layoutAttributesForItemAtIndexPath:indexPath];
        if (attributes) {
            CGRect targetRect = CGRectInset(attributes.frame, 0.0, -18.0);
            [self.collectionView scrollRectToVisible:targetRect animated:animated];
            return;
        }

        [self.collectionView scrollToItemAtIndexPath:indexPath
                                    atScrollPosition:UICollectionViewScrollPositionTop
                                            animated:animated];
    });
}


- (void)refreshMainKindsHeader
{
    NSInteger sectionIndex = [self sectionIndexForType:PPHomeSectionMainKinds];
    if (sectionIndex == NSNotFound) return;

    NSIndexPath *indexPath =
        [NSIndexPath indexPathForItem:0 inSection:sectionIndex];

    UICollectionReusableView *view =
        [self.collectionView supplementaryViewForElementKind:UICollectionElementKindSectionHeader
                                                 atIndexPath:indexPath];

    if (![view isKindOfClass:PPSectionHeaderView.class]) {
        return;
    }

    PPSectionHeaderView *header = (PPSectionHeaderView *)view;

    NSString *iconName = self.isMainKindsExpanded
        ? @"chevron.up"
        : @"chevron.down";

    NSString *actionTitle = self.isMainKindsExpanded
        ? kLang(@"ShowLess")
        : kLang(@"ShowAll");

    [header configureWithTitle:kLang(@"MainCategories")
                      subtitle:nil
                   actionTitle:actionTitle
                      iconName:iconName
                          menu:nil
                 ppHomeSection:PPHomeSectionMainKinds];
}

#pragma mark - Prefetching

- (NSArray<NSString *> *)pp_imageURLsFromIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    if (indexPaths.count == 0 || !self.dataSource) {
        return @[];
    }

    NSMutableOrderedSet<NSString *> *urls = [NSMutableOrderedSet orderedSet];
    for (NSIndexPath *indexPath in indexPaths) {
        PPHomeItem *item = [self.dataSource itemIdentifierForIndexPath:indexPath];
        NSString *url = item.universalViewModel.imageURL;
        if (url.length > 0) {
            [urls addObject:url];
        }
    }

    return urls.array;
}

- (void)pp_prefetchImagesAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    NSArray<NSString *> *urls = [self pp_imageURLsFromIndexPaths:indexPaths];
    if (urls.count == 0) {
        return;
    }

    [[PPImageLoaderManager shared] prefetchURLs:urls];
}

- (void)pp_prefetchTopImagesWithLimit:(NSInteger)limit
{
    if (limit <= 0 || !self.dataSource) {
        return;
    }

    NSDiffableDataSourceSnapshot<NSNumber *, PPHomeItem *> *snapshot =
    self.dataSource.snapshot;
    NSArray<NSNumber *> *sections = snapshot.sectionIdentifiers;
    if (sections.count == 0) {
        return;
    }

    NSMutableArray<NSIndexPath *> *indexPaths = [NSMutableArray array];
    NSInteger remaining = limit;

    for (NSInteger sectionIndex = 0;
         sectionIndex < (NSInteger)sections.count && remaining > 0;
         sectionIndex++) {
        NSArray<PPHomeItem *> *items =
        [snapshot itemIdentifiersInSectionWithIdentifier:sections[(NSUInteger)sectionIndex]];

        for (NSInteger itemIndex = 0;
             itemIndex < (NSInteger)items.count && remaining > 0;
             itemIndex++) {
            PPHomeItem *item = items[(NSUInteger)itemIndex];
            if (item.universalViewModel.imageURL.length == 0) {
                continue;
            }

            [indexPaths addObject:[NSIndexPath indexPathForItem:itemIndex
                                                       inSection:sectionIndex]];
            remaining--;
        }
    }

    [self pp_prefetchImagesAtIndexPaths:indexPaths];
}

- (void)collectionView:(UICollectionView *)collectionView
prefetchItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    (void)collectionView;
    [self pp_prefetchImagesAtIndexPaths:indexPaths];
}

- (void)collectionView:(UICollectionView *)collectionView
cancelPrefetchingForItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    (void)collectionView;
    if (indexPaths.count == 0) {
        return;
    }
    [[PPImageLoaderManager shared] cancelAllPrefetching];
}

- (void)pp_asyncBlurHashImageForHash:(NSString *)hash
                                size:(CGSize)size
                          completion:(void (^)(UIImage * _Nullable image))completion
{
    if (hash.length == 0) {
        if (completion) {
            completion(nil);
        }
        return;
    }

    UIImage *cached = [self.blurHashCache objectForKey:hash];
    if (cached) {
        if (completion) {
            completion(cached);
        }
        return;
    }

    dispatch_async(self.blurHashQueue, ^{
        UIImage *image = [PPBlurHashBridge imageFrom:hash
                                            syncSize:size
                                               punch:1.0];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (image) {
                [self.blurHashCache setObject:image forKey:hash];
            }
            if (completion) {
                completion(image);
            }
        });
    });
}


- (void)dealloc
{
    [[PPHomePromoCarouselManager sharedManager] stopListening];
    [self pp_stopCurrentOrdersListener];
    [self stopNearbyRefreshTimer];
    [self pp_stopHomeSmartSearchTimer];
    [self.homeLocationTitleView stopLivingMotion];
    self.collectionView.prefetchDataSource = nil;
    [[PPImageLoaderManager shared] cancelAllPrefetching];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
- (NSArray<PPHomeItem *> *)identifiersForIndexPaths:(NSArray<NSIndexPath *> *)paths {
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:paths.count];

    for (NSIndexPath *path in paths) {
        PPHomeItem *item = [self.dataSource itemIdentifierForIndexPath:path];

        if (item) {
            [items addObject:item];
        }
    }

    return items;
}

- (void)pp_refreshPetProfilesSection
{
    NSString *userID = [self pp_currentOrdersUserID];
    if (userID.length == 0 || !UserManager.sharedManager.isUserLoggedIn) {
        self.lastPetProfilesUserID = @"";
        NSString *nextSignature = [self pp_homePetProfilesSignatureForProfiles:@[]
                                                                     defaultPet:nil
                                                                        loading:NO];
        BOOL shouldReload = ![nextSignature isEqualToString:PPSafeString(self.lastPetProfilesSectionSignature)];
        self.petProfiles = @[];
        self.defaultPetProfile = nil;
        self.petProfilesLoading = NO;
        self.petProfilesLoaded = YES;
        self.lastPetProfilesSectionSignature = nextSignature;
        if (shouldReload) {
            [self reloadSection:PPHomeSectionPetProfile];
        }
        return;
    }

    self.lastPetProfilesUserID = userID;
    self.petProfilesRequestToken += 1;
    NSInteger requestToken = self.petProfilesRequestToken;
    BOOL wasLoaded = self.petProfilesLoaded;
    NSString *previousSignature = [self pp_homePetProfilesSignatureForProfiles:self.petProfiles
                                                                    defaultPet:self.defaultPetProfile
                                                                       loading:NO];
    self.petProfilesLoading = YES;
    if (!self.petProfilesLoaded) {
        self.lastPetProfilesSectionSignature =
            [self pp_homePetProfilesSignatureForProfiles:self.petProfiles
                                              defaultPet:self.defaultPetProfile
                                                 loading:YES];
        [self reloadSection:PPHomeSectionPetProfile];
    }

    __weak typeof(self) weakSelf = self;
    [[UserManager sharedManager] fetchPetProfilesForCurrentUserWithCompletion:^(NSArray<PPPetProfile *> * _Nullable pets, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || requestToken != self.petProfilesRequestToken) {
                return;
            }

            if (!error) {
                self.petProfiles = [pets isKindOfClass:NSArray.class] ? pets : @[];
                PPPetProfile *resolvedDefaultPet = nil;
                for (PPPetProfile *candidate in self.petProfiles) {
                    if (candidate.isDefaultPet) {
                        resolvedDefaultPet = candidate;
                        break;
                    }
                }
                self.defaultPetProfile = resolvedDefaultPet;
            } else {
                if (!self.petProfilesLoaded) {
                    self.petProfiles = @[];
                    self.defaultPetProfile = nil;
                }
                NSLog(@"[HomePetProfile] fetch failed: %@", error.localizedDescription);
            }

            self.petProfilesLoading = NO;
            self.petProfilesLoaded = YES;
            NSString *nextSignature =
                [self pp_homePetProfilesSignatureForProfiles:self.petProfiles
                                                  defaultPet:self.defaultPetProfile
                                                     loading:NO];
            BOOL shouldReload = !wasLoaded ||
                                ![nextSignature isEqualToString:previousSignature] ||
                                ![nextSignature isEqualToString:PPSafeString(self.lastPetProfilesSectionSignature)];
            self.lastPetProfilesSectionSignature = nextSignature;
            if (shouldReload) {
                [self reloadSection:PPHomeSectionPetProfile];
            }
        });
    }];
}

- (nullable PPPetProfile *)pp_homeEntryPetProfile
{
    if (self.defaultPetProfile) {
        return self.defaultPetProfile;
    }
    return self.petProfiles.firstObject;
}

- (void)pp_openPetProfilesEntryPoint
{
    UIViewController *destination = nil;
    PPPetProfile *entryPet = [self pp_homeEntryPetProfile];

    if (entryPet) {
        destination = [[PPPetProfileEditorViewController alloc] initWithPet:entryPet];
    } else {
        destination = [PPPetProfilesViewController new];
    }

    if (!destination) {
        return;
    }

    self.shouldRefreshPetProfilesOnNextAppearance = YES;
    [PPHomeHelper pushViewControllerSafely:destination from:self animated:YES];
}

- (void)openNearestVet {
    PPPetCareViewController *vc =
        [[PPPetCareViewController alloc] initWithInitialSection:PPPetCareInitialSectionVeterinarians
                                                       mainKind:nil];
    vc.hidesBottomBarWhenPushed = YES;
    [PPHomeHelper pushViewControllerSafely:vc from:self animated:YES];
}

- (void)openAccessories {
    // push accessories listing
    NSLog(@"PPHomeQuickActionAccessories");
}

- (void)openFood {
    // push food listing
    NSLog(@"PPHomeQuickActionFood");
}

- (void)openPremiumPetCare {
    PPPetCareViewController *vc =
        [[PPPetCareViewController alloc] initWithInitialSection:PPPetCareInitialSectionMedicines
                                                       mainKind:nil];
    vc.hidesBottomBarWhenPushed = YES;
    [PPHomeHelper pushViewControllerSafely:vc from:self animated:YES];
}

#pragma mark - UICollectionViewDelegate

// MARK: - UICollectionViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self pp_updateNovaFloatingButtonForScrollView:scrollView];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if (scrollView != self.collectionView) {
        return;
    }
    CGFloat velocityY = [scrollView.panGestureRecognizer velocityInView:self.view].y;
    [self pp_setNovaFloatingButtonScrollCompressed:YES velocityY:velocityY];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (scrollView != self.collectionView) {
        return;
    }
    if (!decelerate) {
        [self pp_scheduleNovaFloatingScrollSettle];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if (scrollView != self.collectionView) {
        return;
    }
    [self pp_scheduleNovaFloatingScrollSettle];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    if (scrollView != self.collectionView) {
        return;
    }
    [self pp_scheduleNovaFloatingScrollSettle];
}

- (void)collectionView:(UICollectionView *)collectionView
    didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    PPHomeSection section = [self sectionTypeForIndexPath:indexPath];
    if (section == PPHomeSectionHero) {
        return;
    }

    NSLog(@"[Home][Tap] section=%ld item=%ld",
             (long)indexPath.section,
             (long)indexPath.item);


    PPHomeItem *item =
        [self.dataSource itemIdentifierForIndexPath:indexPath];

    if (!item) {
        return;
    }

    switch (section) {
        case PPHomeSectionQuickActions:
            return;

        case PPHomeSectionServices: {
            [self pp_emitSelectionHaptic];
            NSLog(@"[Home][Tap][Services] tapped service=%@",
                  item.payload);
            PPHomeServiceItem *service =
                (PPHomeServiceItem *)item.payload;

            if (![service isKindOfClass:PPHomeServiceItem.class]) {
                return;
            }

            [self handleServiceSelection:service
                           fromIndexPath:indexPath];
            break;
        }

        case PPHomeSectionMainKinds: {
            [self pp_emitSelectionHaptic];
            if (![item.payload isKindOfClass:MainKindsModel.class]) {
                return;
            }

            MainKindsModel *kind = (MainKindsModel *)item.payload;
            BOOL isAll = (kind.ID == -1);

            NSLog(@"[Home][Tap][MainKinds] isAll=%@ payload=%@",
                  isAll ? @"YES" : @"NO",
                  item.payload);

            if (isAll) {
                // ✅ Route ALL to DataViewVC
                [self handleDeepLinkWithTarget:PPDeepLinkTargetAllCategories
                                      mainKind:nil
                                        source:PPInputSourceHomeMainKindsSection];
                return;
            }


            // ✅ Route specific kind
            [self handleMainKindSelection:kind];
            return;
            break;
        }

        case PPHomeSectionCurrentOrders: {
            [self pp_emitSelectionHaptic];
            if (![item.payload isKindOfClass:PPOrder.class]) {
                return;
            }
            [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
            [self pp_openOrderDetailsForOrder:(PPOrder *)item.payload];
            return;
        }

        case PPHomeSectionPremiumSearch:
        case PPHomeSectionPremiumCare: {
            [self pp_emitSelectionHaptic];
            [self openPremiumPetCare];
            return;
        }

        case PPHomeSectionSuggestions: {
            [self pp_emitSelectionHaptic];
            PPUniversalCellViewModel *vm = item.universalViewModel;
            id model = vm.ModelObject;

            if (!model) return;

            // 🔥 Track browse history (important for "Because you viewed")
            if ([model isKindOfClass:PetAd.class]) {
                PetAd *ad = (PetAd *)model;

                [[PPBrowseHistoryManager shared]
                    trackItemWithType:PPBrowseItemTypeAd
                           mainKindID:ad.category];
            }
            else if ([model isKindOfClass:PetAccessory.class]) {
                PetAccessory *acc = (PetAccessory *)model;

                [[PPBrowseHistoryManager shared]
                    trackItemWithType:PPBrowseItemTypeAccessory
                           mainKindID:acc.petMainCategoryID];
            }

            // ✅ Open overlay (same UX as nearby / accessories)
            [self pp_openOverlayForObject:model];
            break;
        }

        case PPHomeSectionAccessories:
        case PPHomeSectionPetProfile:
        case PPHomeSectionBuyAgain:
        case PPHomeSectionLastFood:
        case PPHomeSectionAdsNearBy:
        case PPHomeSectionNearbyServices: {
            [self pp_emitSelectionHaptic];
            if (section == PPHomeSectionPetProfile) {
                [self pp_openPetProfilesEntryPoint];
                return;
            }

            PPUniversalCellViewModel *vm = item.universalViewModel;
            id model = vm.ModelObject;

            NSLog(@"[Home][Tap][ResolvedModel] %@",
                  NSStringFromClass([model class]));

            if (!model) return;
            if ([model isKindOfClass:PPHomeBuyAgainSnapshotItem.class]) {
                [self pp_openSimilarItemsForUnavailableBuyAgainItem:(PPHomeBuyAgainSnapshotItem *)model];
                return;
            }

            [self pp_openOverlayForObject:model];
            break;
        }

        case PPHomeSectionAdopt: {
            [self pp_emitSelectionHaptic];
            NSLog(@"[Home][Tap][Adopt] Open BitsViewController");

            AdoptPetsViewController *vc = [[AdoptPetsViewController alloc] init];
            vc.pp_transitionStyle = PPTransitionStyleNone;

            PPNavigationController *nav =
                (PPNavigationController *)[PPHomeHelper currentNavigationControllerFor:self];
            if (!nav) return;

            [PPHomeHelper pushViewControllerSafely:vc from:self animated:YES];
            break;
        }

        default:
            break;
    }
}

- (void)collectionView:(UICollectionView *)collectionView
       willDisplayCell:(UICollectionViewCell *)cell
    forItemAtIndexPath:(NSIndexPath *)indexPath
{
    (void)collectionView;

    // First-reveal flash guard: when applyBaseSnapshot inserts sections after
    // HomeConfig arrives, cells are composited at full opacity for one frame
    // before pp_prepareVisibleHomeEntranceContentIfNeeded can fade them. Pre-
    // fade them here so they're already in the entrance "before" state at the
    // moment of display, then let the staggered animation reveal them.
    if (!self.didRunPremiumHomeEntranceAnimation && ![self pp_shouldReduceHomeMotion]) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        [self pp_configureHomeEntranceInitialStateForCell:cell
                                              atIndexPath:indexPath
                                           lateAppearance:NO];
        [CATransaction commit];
    }

    PPHomeSection section = [self sectionTypeForIndexPath:indexPath];
    if (section == PPHomeSectionPetProfile ||
        section == PPHomeSectionPremiumSearch ||
        section == PPHomeSectionPremiumCare ||
        section == PPHomeSectionAdopt) {
        if ([self pp_isInitialHomeRevealSettled]) {
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            [cell setNeedsLayout];
            [cell.contentView setNeedsLayout];
            [cell.contentView layoutIfNeeded];
            [cell layoutIfNeeded];
            [CATransaction commit];
        }
    }

    [self pp_animateHorizontalUniversalCellIfNeeded:cell
                                        atIndexPath:indexPath
                                            section:section];
}

- (void)collectionView:(UICollectionView *)collectionView
didHighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    PPHomeSection section = [self sectionTypeForIndexPath:indexPath];
    if (section == PPHomeSectionHero ||
        section == PPHomeSectionCurrentOrders ||
        section == PPHomeSectionCarousel) {
        return;
    }

    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    [self pp_animateHomeCell:cell highlighted:YES];
}

- (void)collectionView:(UICollectionView *)collectionView
didUnhighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    [self pp_animateHomeCell:cell highlighted:NO];
}

#pragma mark - Overlay Routing (Home → OverlayCoordinator)

- (void)pp_openOverlayForObject:(id)object
{
    if ([object isKindOfClass:PetAd.class]) {
        PetAd *ad = object;
        [[PPBrowseHistoryManager shared]
            trackItemWithType:PPBrowseItemTypeAd
                   mainKindID:ad.category];
    }
    else if ([object isKindOfClass:PetAccessory.class]) {
        PetAccessory *acc = object;
        [[PPBrowseHistoryManager shared]
            trackItemWithType:PPBrowseItemTypeAccessory
                   mainKindID:acc.petMainCategoryID];
    }


    if (!object) return;
    UIViewController *sourceVC = self;
    [PPOverlayCoordinator pp_openDetailForObject:object
                                         fromVC:sourceVC
                                     routingNav:nil];
}


- (BOOL)isCategorySelected:(MainKindsModel *)kind
{
    if (!kind) {
        return self.selectedCategory == nil; // All
    }

    return self.selectedCategory &&
           kind.ID == self.selectedCategory.ID;
}
- (void)handleServiceSelection:(PPHomeServiceItem *)service
                 fromIndexPath:(NSIndexPath *)indexPath {
    switch (service.type) {
        case PPHomeServiceTypeMainService:
            [self handleDeepLinkWithTarget:PPDeepLinkTargetServices
                                  mainKind:nil
                                    source:PPInputSourceHomeServicesSection];
            break;

        case PPHomeServiceTypeVet:
            [self openNearestVet];
            break;

        case PPHomeServiceTypeGrooming:
            [self handleDeepLinkWithTarget:PPDeepLinkTargetGrooming
                                  mainKind:nil
                                    source:PPInputSourceHomeServicesSection];
            break;

        case PPHomeServiceTypeTraining:
            [self handleDeepLinkWithTarget:PPDeepLinkTargetTraning
                                  mainKind:nil
                                    source:PPInputSourceHomeServicesSection];
            break;

        case PPHomeServiceTypeFood:
            [self handleDeepLinkWithTarget:PPDeepLinkTargetFood
                                  mainKind:nil
                                    source:PPInputSourceHomeServicesSection];
            break;
    }
}

- (CGFloat)currentYOffsetForSection:(PPHomeSection)section {
    NSIndexPath *headerIndexPath = [NSIndexPath indexPathForItem:0 inSection:section];

    UICollectionViewLayoutAttributes *attrs =
        [self.collectionView layoutAttributesForSupplementaryElementOfKind:@"PPHomeSectionHeaderKind"
                                                               atIndexPath:headerIndexPath];

    if (!attrs) {
        return self.collectionView.contentOffset.y;
    }

    return attrs.frame.origin.y - self.collectionView.contentOffset.y;
}

#pragma mark - View Data Routing (PPDataViewVC)

// MainKinds now open unified PPDataViewVC
- (void)handleMainKindSelection:(MainKindsModel *)kind {
    if (!kind) {
        return;
    }

    // Build input object for PPDataViewVC
    PPDataViewInput *input = [PPDataViewInput inputWithMainKind:kind sourceTarget:PPDeepLinkTargetAds source:PPInputSourceHomeMainKindsSection];
    PPDataViewVC *vc =  [[PPDataViewVC alloc] initWithInput:input];
    vc.pp_transitionStyle = PPTransitionStyleNone;
    if (![PPHomeHelper pushViewControllerSafely:vc from:self animated:YES]) {
        return;
    }
}

- (void)handleDeepLinkWithTarget:(PPDeepLinkTarget)target
                        mainKind:(MainKindsModel *)mainKind
                          source:(PPInputSource)source
{
    NSLog(@"[MainKindsModel] handleDeepLinkWithTarget resolvedKind %@",
          mainKind ? mainKind.KindName : @"(nil)");
    UINavigationController *nav = [PPHomeHelper currentNavigationControllerFor:self];

    if (!nav) {
        NSLog(@"[DeepLink] ❌ No navigation controller available");
        return;
    }

    UIViewController *vc;

    switch (target) {
        case PPDeepLinkTargetAllCategories: {
            NSLog(@"[DeepLink] Building ALL MainKinds DataViewVC");

            PPDataViewInput *input =
                [PPDataViewInput inputWithMainKindsArr:self.mainKinds
                                          sourceTarget:PPDeepLinkTargetAllCategories
                                                source:source];

            PPDataViewVC *allVC =
                [[PPDataViewVC alloc] initWithInput:input];

            allVC.pp_transitionStyle = PPTransitionStyleNone;
            [PPHomeHelper pushViewControllerSafely:allVC from:self animated:YES];
            return;
        }
        case PPDeepLinkTargetAccessories:
        case PPDeepLinkTargetFood:
        case PPDeepLinkTargetServices:
        case PPDeepLinkTargetGrooming:
        case PPDeepLinkTargetTraning:
        case PPDeepLinkTargetNewByAds:
        case PPDeepLinkTargetAds:{
            vc = [self buildDataViewVCForTarget:target
                                       mainKind:mainKind
                                         source:source];

            if (!vc) {
                NSLog(@"[DeepLink] ❌ Failed to build destination VC"); return;
            }

            break;
        }

        default:{
            vc = [self buildDataViewVCForTarget:target mainKind:mainKind source:source];

            if (!vc) {
                NSLog(@"[DeepLink] ❌ Failed to build destination VC"); return;
            }
        }

        break;
    }
    // =========================
    // Navigate Safely
    // =========================

    [PPHomeHelper pushViewControllerSafely:vc from:self animated:YES];
}

// Unified builder for PPDataViewVC for deep-link targets
- (PPDataViewVC *)buildDataViewVCForTarget:(PPDeepLinkTarget)target
                                  mainKind:(MainKindsModel *_Nullable)mainKind
                                    source:(PPInputSource)source
{
    PPDataViewInput *input;
    if (mainKind) {
        input = [PPDataViewInput inputWithMainKind:mainKind
                                      sourceTarget:target
                                            source:source];
    } else {
        input = [PPDataViewInput inputWithMainKind:nil
                                      sourceTarget:target
                                            source:source];
    }

    if (!input) {
        return nil;
    }

    // Create unified data viewer
    PPDataViewVC *vc =
        [[PPDataViewVC alloc] initWithInput:input];

    vc.pp_transitionStyle = PPTransitionStyleNone;
    return vc;
}

- (BOOL)deepLinkTargetRequiresMainKind:(PPDeepLinkTarget)target {
    switch (target) {
        case PPDeepLinkTargetAds:
        case PPDeepLinkTargetAccessories:
        case PPDeepLinkTargetFood:
        case PPDeepLinkTargetServices:
            return YES;    // Global listings

        default:
            return NO;
    }
}

- (MainKindsModel *)resolveMainKindWithID:(NSInteger)mainKindID {
    for (MainKindsModel *kind in self.mainKinds) {
        if (kind.ID == mainKindID) {
            return kind;
        }
    }

    return nil;
}

- (NSString *)heroBaseGreetingText
{
    return [PPHomeGreetingProvider baseGreetingForDate:NSDate.date];
}

- (NSString *)heroDisplayNameText
{
    if (!PPIsUserLoggedIn) {
        return @"";
    }

    id resolvedUser = PPCurrentUser ?: UserManager.sharedManager.currentUser;
    if (!resolvedUser) {
        return @"";
    }

    NSString *bestName = PPSafeString([resolvedUser valueForKey:@"PPBestDisplayName"]);
    if (bestName.length > 0) {
        return bestName;
    }

    NSString *username = PPSafeString([resolvedUser valueForKey:@"UserName"]);
    return username.length > 0 ? username : @"";
}

- (NSString *)heroCountryText
{
    switch (self.nearbyLocationState) {
        case PPNearbyLocationStateLoading:
            return kLang(@"Loading...") ?: @"Loading...";
        case PPNearbyLocationStateDenied:
            return kLang(@"Location permission denied") ?: @"Location permission denied";
        case PPNearbyLocationStateReady:
            if (self.selectedNearbyAreaName.length > 0) {
                return self.selectedNearbyAreaName;
            }
            return kLang(@"Select your location") ?: @"Select your location";
        case PPNearbyLocationStateUnset:
        default:
            return kLang(@"Select your location") ?: @"Select your location";
    }
}

- (NSString *)heroLocationActionTitle
{
    switch (self.nearbyLocationState) {
        case PPNearbyLocationStateDenied:
            return kLang(@"Open Settings") ?: @"Open Settings";
        case PPNearbyLocationStateReady:
            return kLang(@"Hero_ChangeArea") ?: @"Change area";
        case PPNearbyLocationStateUnset:
            return kLang(@"Hero_LocationCTA") ?: @"Choose area";
        case PPNearbyLocationStateLoading:
        default:
            return nil;
    }
}

- (NSString *)pp_sanitizedHeroLine:(NSString *)line
{
    NSString *safe = PPSafeString(line);
    safe = [safe stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    safe = [safe stringByReplacingOccurrencesOfString:@"\r" withString:@" "];
    return [safe stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)heroGreetingText
{
    return [self pp_sanitizedHeroLine:[self heroBaseGreetingText]];
}

- (void)openAdoption {
    AdoptPetsViewController *vc = [[AdoptPetsViewController alloc] init];

    vc.pp_transitionStyle = PPTransitionStyleNone;
}

- (NSArray<PPHomeQuickActionModel *> *)pp_homeQuickActions
{
    return [PPHomeQuickActionModel defaultHomeQuickActions];
}

- (void)handleQuickActionSelection:(PPHomeQuickActionModel *)quickAction
{
    if (![quickAction isKindOfClass:PPHomeQuickActionModel.class]) {
        return;
    }

    [self pp_emitSoftImpactHaptic];

    switch (quickAction.type) {
        case PPHomeQuickActionTypeNearestVet:
            [self openNearestVet];
            break;
        case PPHomeQuickActionTypeSellPet:
        case PPHomeQuickActionTypeAddAd:
            [self pp_openAddNewAdComposer];
            break;
        case PPHomeQuickActionTypeAdopt:
            [self pp_openAdoptFlow];
            break;
        case PPHomeQuickActionTypeRequestService:
            [self handleDeepLinkWithTarget:PPDeepLinkTargetServices
                                  mainKind:nil
                                    source:PPInputSourceHomeServicesSection];
            break;
    }
}

- (void)pp_openAddNewAdComposer
{
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }

    if (UserManager.sharedManager.isCurrentUserBlocked) {
        [PPAlertHelper showErrorIn:self
                             title:(kLang(@"Account blocked") ?: @"Account blocked")
                          subtitle:(kLang(@"Your account is blocked. You can't add ads right now.") ?: @"Your account is blocked. You can't add ads right now.")];
        return;
    }

    UserModel *currentUser = UserManager.sharedManager.currentUser;
    BOOL canPostAds = [currentUser hasAnyPermissionInKeys:@[kPermPostAds, kPermAdminAll]];
    if (!canPostAds) {
        [PPAlertHelper showErrorIn:self
                             title:(kLang(@"Permission denied") ?: @"Permission denied")
                          subtitle:(kLang(@"You don't have permission to add ads.") ?: @"You don't have permission to add ads.")];
        return;
    }

    AddNewAd *vc = [AddNewAd new];
    vc.mode = AdEditorModeCreate;
    vc.FromVC = @"HomeVC";
    vc.pp_transitionStyle = PPTransitionStyleNone;
    [PPHomeHelper pushViewControllerSafely:vc from:self animated:YES];
}

- (void)pp_openAdoptFlow
{
    AdoptPetsViewController *vc = [[AdoptPetsViewController alloc] init];
    vc.pp_transitionStyle = PPTransitionStyleNone;
    [PPHomeHelper pushViewControllerSafely:vc from:self animated:YES];
}

- (NSArray<NSDictionary *> *)pp_recentNearbyLocationRecords
{
    id savedRecords =
        [[NSUserDefaults standardUserDefaults] objectForKey:PPNearbyRecentLocationsKey];
    if (![savedRecords isKindOfClass:NSArray.class]) {
        return @[];
    }

    NSMutableArray<NSDictionary *> *records = [NSMutableArray array];
    for (NSDictionary *record in (NSArray *)savedRecords) {
        if (![record isKindOfClass:NSDictionary.class]) {
            continue;
        }

        NSNumber *latitude = record[@"latitude"];
        NSNumber *longitude = record[@"longitude"];
        NSString *title = PPSafeString(record[@"title"]);
        CLLocationCoordinate2D coordinate =
            CLLocationCoordinate2DMake(latitude.doubleValue, longitude.doubleValue);
        if (!CLLocationCoordinate2DIsValid(coordinate) || title.length == 0) {
            continue;
        }
        [records addObject:record];
    }

    [records sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
        NSNumber *time1 = obj1[@"timestamp"];
        NSNumber *time2 = obj2[@"timestamp"];
        return [time2 compare:time1];
    }];

    if (records.count > PPNearbyRecentLocationsLimit) {
        return [records subarrayWithRange:NSMakeRange(0, PPNearbyRecentLocationsLimit)];
    }
    return records.copy;
}

- (void)pp_recordRecentNearbyLocationCoordinate:(CLLocationCoordinate2D)coordinate
                                          title:(NSString *)title
                                         source:(NSString *)source
{
    if (!CLLocationCoordinate2DIsValid(coordinate)) {
        return;
    }

    NSString *safeTitle = PPSafeString(title);
    if (safeTitle.length == 0) {
        return;
    }

    NSMutableArray<NSDictionary *> *records =
        [[self pp_recentNearbyLocationRecords] mutableCopy] ?: [NSMutableArray array];
    NSMutableArray<NSDictionary *> *filtered = [NSMutableArray array];

    for (NSDictionary *record in records) {
        NSNumber *latitude = record[@"latitude"];
        NSNumber *longitude = record[@"longitude"];
        NSString *existingTitle = PPSafeString(record[@"title"]);
        BOOL sameTitle = [existingTitle isEqualToString:safeTitle];
        BOOL sameCoordinate =
            fabs(latitude.doubleValue - coordinate.latitude) < 0.0001 &&
            fabs(longitude.doubleValue - coordinate.longitude) < 0.0001;
        if (sameTitle || sameCoordinate) {
            continue;
        }
        [filtered addObject:record];
    }

    NSDictionary *newRecord = @{
        @"latitude" : @(coordinate.latitude),
        @"longitude" : @(coordinate.longitude),
        @"title" : safeTitle,
        @"source" : PPSafeString(source),
        @"timestamp" : @([[NSDate date] timeIntervalSince1970])
    };
    [filtered insertObject:newRecord atIndex:0];

    if (filtered.count > PPNearbyRecentLocationsLimit) {
        [filtered removeObjectsInRange:NSMakeRange(PPNearbyRecentLocationsLimit,
                                                   filtered.count - PPNearbyRecentLocationsLimit)];
    }

    [[NSUserDefaults standardUserDefaults] setObject:filtered.copy
                                              forKey:PPNearbyRecentLocationsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)pp_applyNearbyLocationRecord:(NSDictionary *)record
{
    if (![record isKindOfClass:NSDictionary.class]) {
        return;
    }

    NSNumber *latitude = record[@"latitude"];
    NSNumber *longitude = record[@"longitude"];
    NSString *title = PPSafeString(record[@"title"]);
    CLLocationCoordinate2D coordinate =
        CLLocationCoordinate2DMake(latitude.doubleValue, longitude.doubleValue);
    if (!CLLocationCoordinate2DIsValid(coordinate) || title.length == 0) {
        return;
    }

    self.isUsingManualNearbySelection = YES;
    self.selectedNearbyCoordinate = coordinate;
    self.hasSelectedNearbyCoordinate = YES;
    self.selectedNearbyAreaName = title;
    self.nearbyLocationState = PPNearbyLocationStateReady;
    self.nearbyRadiusKm = PPNearbyDefaultRadiusKm;
    [self pp_recordRecentNearbyLocationCoordinate:coordinate title:title source:@"recent"];
    [self persistNearbyLocationIfNeeded];
    [self refreshHeroSectionAppearance];
    [self refreshNearbyAdsForce:YES reason:@"recent-location"];
    [self pp_emitSelectionHaptic];
}

- (NSDictionary<NSString *, NSString *> *)pp_suggestionReasonForModel:(id)model
                                                          latestEvent:(NSDictionary *)latestEvent
                                                    orderedAccessoryIDs:(NSArray<NSString *> *)orderedAccessoryIDs
{
    if ([model isKindOfClass:PetAccessory.class]) {
        PetAccessory *accessory = (PetAccessory *)model;
        NSString *accessoryID = PPSafeString(accessory.accessoryID);
        if (accessoryID.length > 0 && [orderedAccessoryIDs containsObject:accessoryID]) {
            return @{
                @"text" : (kLang(@"home_suggestion_reason_previous_orders") ?: @"Based on your previous orders"),
                @"icon" : @"clock.arrow.circlepath"
            };
        }
    }

    NSString *browseReason = [self pp_browseReasonTextForEvent:latestEvent];
    NSInteger latestKindID = [latestEvent[@"kind"] integerValue];
    PPBrowseItemType latestType = [latestEvent[@"type"] integerValue];

    if (browseReason.length > 0) {
        if ([model isKindOfClass:PetAd.class]) {
            PetAd *ad = (PetAd *)model;
            if (latestType == PPBrowseItemTypeAd && ad.category == latestKindID) {
                return @{
                    @"text" : browseReason,
                    @"icon" : @"sparkles"
                };
            }
        } else if ([model isKindOfClass:PetAccessory.class]) {
            PetAccessory *accessory = (PetAccessory *)model;
            if (latestType == PPBrowseItemTypeAccessory &&
                accessory.petMainCategoryID == latestKindID) {
                return @{
                    @"text" : browseReason,
                    @"icon" : @"sparkles"
                };
            }
        }
    }

    if ([model isKindOfClass:PetAd.class]) {
        return @{
            @"text" : (kLang(@"home_suggestion_reason_nearby") ?: @"Near you"),
            @"icon" : @"location.fill"
        };
    }

    return nil;
}

- (NSString *)pp_browseReasonTextForEvent:(NSDictionary *)event
{
    if (![event isKindOfClass:NSDictionary.class]) {
        return @"";
    }

    NSInteger kindID = [event[@"kind"] integerValue];
    PPBrowseItemType type = [event[@"type"] integerValue];
    MainKindsModel *kind = [self resolveMainKindWithID:kindID];
    if (!kind){
        return @"";
    }

    NSString *typeKey =
        type == PPBrowseItemTypeAd
        ? (kLang(@"BrowseType_Ads") ?: @"ads")
        : type == PPBrowseItemTypeAccessory
            ? (kLang(@"BrowseType_Accessories") ?: @"accessories")
            : (kLang(@"BrowseType_Services") ?: @"services");
    NSString *format = kLang(@"BecauseYouViewedFormat") ?: @"Because you viewed %@ %@";
    return [NSString stringWithFormat:format, typeKey, kind.KindName ?: @""];
}

- (void)pp_emitSelectionHaptic
{
    UISelectionFeedbackGenerator *generator = [[UISelectionFeedbackGenerator alloc] init];
    [generator selectionChanged];
}

- (void)pp_emitSoftImpactHaptic
{
    UIImpactFeedbackGenerator *generator =
        [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleSoft];
    [generator impactOccurred];
}

- (BOOL)pp_shouldReduceHomeMotion
{
    return UIAccessibilityIsReduceMotionEnabled();
}

- (BOOL)pp_shouldDeferHomeLayoutStabilization
{
    if (self.isPremiumHomeEntranceAnimating) {
        return YES;
    }

    // Hold layout stabilization until the first config-ordered entrance finishes.
    if (self.didApplyInitialBaseSnapshot && ![self pp_isInitialHomeRevealSettled]) {
        return YES;
    }

    return NO;
}

- (NSArray<NSNumber *> *)pp_collectionSectionIndexesOrderedForEntrance
{
    if (!self.dataSource) {
        return @[];
    }

    NSMutableArray<NSNumber *> *ordered = [NSMutableArray array];
    for (NSNumber *sectionID in self.dataSource.snapshot.sectionIdentifiers) {
        NSInteger collectionSection = [self sectionIndexForType:(PPHomeSection)sectionID.integerValue];
        if (collectionSection != NSNotFound) {
            [ordered addObject:@(collectionSection)];
        }
    }
    return ordered.copy;
}

- (NSArray<NSIndexPath *> *)pp_sortedVisibleIndexPathsForEntrance
{
    NSArray<NSIndexPath *> *visibleIndexPaths = self.collectionView.indexPathsForVisibleItems;
    if (visibleIndexPaths.count <= 1) {
        return visibleIndexPaths;
    }

    return [visibleIndexPaths sortedArrayUsingComparator:^NSComparisonResult(NSIndexPath *obj1, NSIndexPath *obj2) {
        if (obj1.section < obj2.section) {
            return NSOrderedAscending;
        }
        if (obj1.section > obj2.section) {
            return NSOrderedDescending;
        }
        if (obj1.item < obj2.item) {
            return NSOrderedAscending;
        }
        if (obj1.item > obj2.item) {
            return NSOrderedDescending;
        }
        return NSOrderedSame;
    }];
}

- (BOOL)pp_isInitialHomeRevealSettled
{
    return self.didRunPremiumHomeEntranceAnimation && !self.isPremiumHomeEntranceAnimating;
}

- (nullable NSString *)pp_homeEntranceKeyForIndexPath:(NSIndexPath *)indexPath
                                                 kind:(nullable NSString *)kind
{
    if (!indexPath || !self.dataSource) {
        return nil;
    }

    if (kind.length > 0) {
        PPHomeSection section = [self sectionTypeForIndexPath:indexPath];
        return [NSString stringWithFormat:@"%@-%ld", kind, (long)section];
    }

    PPHomeItem *item = [self.dataSource itemIdentifierForIndexPath:indexPath];
    NSString *identifier = PPSafeString(item.identifier);
    if (identifier.length > 0) {
        return identifier;
    }

    PPHomeSection section = [self sectionTypeForIndexPath:indexPath];
    return [NSString stringWithFormat:@"cell-%ld-%ld", (long)section, (long)indexPath.item];
}

- (void)pp_preparePremiumHomeEntranceStateIfNeeded
{
    if (self.didPreparePremiumHomeEntrance || self.didRunPremiumHomeEntranceAnimation) {
        return;
    }
    // Don't fade chrome while the snapshot is still empty — the user would
    // stare at faded glow + faded nav chrome until HomeConfig finally lands.
    // Wait until we actually have sections to reveal.
    if (self.dataSource && self.dataSource.snapshot.numberOfItems == 0) {
        return;
    }
    self.didPreparePremiumHomeEntrance = YES;

    NSArray<UIView *> *glowViews = @[
        self.pp_premiumBackgroundGlowViewTop ?: [UIView new],
        self.pp_premiumBackgroundGlowViewMid ?: [UIView new],
        self.pp_premiumBackgroundGlowViewBottom ?: [UIView new]
    ];

    NSMutableArray<UIView *> *chromeViews = [NSMutableArray array];
    if (self.homeSmartSearchView) {
        [chromeViews addObject:self.homeSmartSearchView];
    }
    if (self.homeProfileItem.customView) {
        [chromeViews addObject:self.homeProfileItem.customView];
    }
    if (self.homeCartItem.customView) {
        [chromeViews addObject:self.homeCartItem.customView];
    }

    if ([self pp_shouldReduceHomeMotion]) {
        self.collectionView.alpha = 1.0;
        self.collectionView.transform = CGAffineTransformIdentity;
        for (UIView *glowView in glowViews) {
            glowView.alpha = 1.0;
            glowView.transform = CGAffineTransformIdentity;
        }
        for (UIView *chromeView in chromeViews) {
            chromeView.alpha = 1.0;
            chromeView.transform = CGAffineTransformIdentity;
        }
        return;
    }

    self.collectionView.alpha = 1.0;
    self.collectionView.transform = CGAffineTransformIdentity;

    for (UIView *glowView in glowViews) {
        glowView.alpha = 0.09;
        glowView.transform = CGAffineTransformMakeScale(0.96, 0.96);
    }

    for (UIView *chromeView in chromeViews) {
        chromeView.alpha = 0.22;
        chromeView.transform = CGAffineTransformMakeTranslation(0.0, -6.0);
    }
}

- (void)pp_prepareVisibleHomeEntranceContentIfNeeded
{
    if (!self.collectionView || [self pp_shouldReduceHomeMotion] || self.didRunPremiumHomeEntranceAnimation) {
        return;
    }

    CGSize boundsSize = self.collectionView.bounds.size;
    if (boundsSize.width <= 1.0 || boundsSize.height <= 1.0) {
        return;
    }

    NSArray<NSIndexPath *> *visibleIndexPaths = [self pp_sortedVisibleIndexPathsForEntrance];
    NSArray<NSNumber *> *orderedCollectionSections = [self pp_collectionSectionIndexesOrderedForEntrance];

    NSUInteger visibleItemCount = visibleIndexPaths.count;
    NSUInteger visibleSectionCount = orderedCollectionSections.count;
    if (visibleItemCount == 0 && visibleSectionCount == 0) {
        return;
    }

    if (self.didPrepareVisibleHomeEntranceContent) {
        return;
    }

    self.didPrepareVisibleHomeEntranceContent = YES;
    self.lastPreparedHomeEntranceBoundsSize = boundsSize;
    self.lastPreparedHomeEntranceItemCount = visibleItemCount;
    self.lastPreparedHomeEntranceSectionCount = visibleSectionCount;

    __block NSUInteger headerOrdinal = 0;
    [orderedCollectionSections enumerateObjectsUsingBlock:^(NSNumber * _Nonnull sectionNumber, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)idx;
        (void)stop;
        NSIndexPath *headerIndexPath = [NSIndexPath indexPathForItem:0 inSection:sectionNumber.integerValue];
        UICollectionReusableView *header =
            [self.collectionView supplementaryViewForElementKind:UICollectionElementKindSectionHeader
                                                     atIndexPath:headerIndexPath];
        if (!header) {
            return;
        }
        [self pp_configureHomeEntranceInitialStateForSupplementaryView:header
                                                                  kind:UICollectionElementKindSectionHeader
                                                           atIndexPath:headerIndexPath
                                                        lateAppearance:NO];
        headerOrdinal += 1;
    }];

    [visibleIndexPaths enumerateObjectsUsingBlock:^(NSIndexPath * _Nonnull indexPath, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)idx;
        (void)stop;
        UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:indexPath];
        [self pp_configureHomeEntranceInitialStateForCell:cell
                                              atIndexPath:indexPath
                                           lateAppearance:NO];
    }];
}

- (void)pp_beginPremiumBackgroundGlowMotionIfNeeded
{
    if (self.didStartPremiumBackgroundGlowMotion || [self pp_shouldReduceHomeMotion]) {
        return;
    }
    self.didStartPremiumBackgroundGlowMotion = YES;

    [UIView animateWithDuration:8.6
                          delay:0.0
                        options:UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        CGAffineTransform transform = CGAffineTransformMakeTranslation(-14.0, 16.0);
        self.pp_premiumBackgroundGlowViewTop.transform = CGAffineTransformScale(transform, 1.05, 1.05);
    } completion:nil];

    [UIView animateWithDuration:10.2
                          delay:0.0
                        options:UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        CGAffineTransform transform = CGAffineTransformMakeTranslation(16.0, -10.0);
        self.pp_premiumBackgroundGlowViewMid.transform = CGAffineTransformScale(transform, 1.03, 1.03);
    } completion:nil];

    [UIView animateWithDuration:9.4
                          delay:0.0
                        options:UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        CGAffineTransform transform = CGAffineTransformMakeTranslation(-12.0, -18.0);
        self.pp_premiumBackgroundGlowViewBottom.transform = CGAffineTransformScale(transform, 1.04, 1.04);
    } completion:nil];
}

- (void)pp_beginPremiumHomeEntranceIfNeeded
{
    if (self.didRunPremiumHomeEntranceAnimation) {
        return;
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [UIView performWithoutAnimation:^{
        [self.collectionView setNeedsLayout];
        [self.collectionView layoutIfNeeded];
        [self pp_prepareVisibleHomeEntranceContentIfNeeded];
    }];
    [CATransaction commit];

    // If the snapshot is still empty (e.g. HomeConfig hasn't arrived yet) there
    // are no cells/headers to animate. Bail out WITHOUT setting the "done" flag
    // so that the post-config apply in applyBaseSnapshot can retrigger this and
    // get a real reveal. Setting the flag here would silently consume the only
    // entrance we have.
    if (self.collectionView.indexPathsForVisibleItems.count == 0) {
        return;
    }

    NSArray<UIView *> *glowViews = @[
        self.pp_premiumBackgroundGlowViewTop ?: [UIView new],
        self.pp_premiumBackgroundGlowViewMid ?: [UIView new],
        self.pp_premiumBackgroundGlowViewBottom ?: [UIView new]
    ];

    NSMutableArray<UIView *> *chromeViews = [NSMutableArray array];
    if (self.homeSmartSearchView) {
        [chromeViews addObject:self.homeSmartSearchView];
    }
    if (self.homeProfileItem.customView) {
        [chromeViews addObject:self.homeProfileItem.customView];
    }
    if (self.homeCartItem.customView) {
        [chromeViews addObject:self.homeCartItem.customView];
    }

    if ([self pp_shouldReduceHomeMotion]) {
        self.didRunPremiumHomeEntranceAnimation = YES;
        self.isPremiumHomeEntranceAnimating = NO;
        self.collectionView.alpha = 1.0;
        self.collectionView.transform = CGAffineTransformIdentity;
        for (UIView *glowView in glowViews) {
            glowView.alpha = 1.0;
            glowView.transform = CGAffineTransformIdentity;
        }
        for (UIView *chromeView in chromeViews) {
            chromeView.alpha = 1.0;
            chromeView.transform = CGAffineTransformIdentity;
        }
        [self pp_refreshInitialHomeRevealDependentContent];
        return;
    }

    self.didRunPremiumHomeEntranceAnimation = YES;
    self.isPremiumHomeEntranceAnimating = YES;

    [glowViews enumerateObjectsUsingBlock:^(UIView * _Nonnull glowView, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)stop;
        [UIView animateWithDuration:0.68
                              delay:0.04 * idx
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            glowView.alpha = 1.0;
            glowView.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];

    [chromeViews enumerateObjectsUsingBlock:^(UIView * _Nonnull chromeView, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)stop;
        [UIView animateWithDuration:0.30
                              delay:0.03 * idx
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            chromeView.alpha = 1.0;
            chromeView.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];

    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.06 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.isViewLoaded) {
            return;
        }
        [self pp_animateVisibleHomeEntranceContentIfNeeded];
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.80 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.isViewLoaded) {
            return;
        }
        [self pp_beginPremiumBackgroundGlowMotionIfNeeded];
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.86 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.isViewLoaded) {
            return;
        }
        self.isPremiumHomeEntranceAnimating = NO;
        [self pp_stabilizeHomeCollectionLayoutIfNeeded];
        [self pp_refreshInitialHomeRevealDependentContent];
        [self pp_centerNearbySectionIfPossible];
    });
}

- (void)pp_animateVisibleHomeEntranceContentIfNeeded
{
    if (!self.collectionView || [self pp_shouldReduceHomeMotion]) {
        return;
    }

    NSArray<NSIndexPath *> *visibleIndexPaths = [self pp_sortedVisibleIndexPathsForEntrance];
    NSArray<NSNumber *> *orderedCollectionSections = [self pp_collectionSectionIndexesOrderedForEntrance];
    __block NSUInteger entranceOrdinal = 0;

    [orderedCollectionSections enumerateObjectsUsingBlock:^(NSNumber * _Nonnull sectionNumber, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)idx;
        (void)stop;
        NSIndexPath *headerIndexPath = [NSIndexPath indexPathForItem:0 inSection:sectionNumber.integerValue];
        UICollectionReusableView *header =
            [self.collectionView supplementaryViewForElementKind:UICollectionElementKindSectionHeader
                                                     atIndexPath:headerIndexPath];
        if (!header) {
            return;
        }
        [self pp_animateHomeEntranceForSupplementaryView:header
                                                   kind:UICollectionElementKindSectionHeader
                                            atIndexPath:headerIndexPath
                                         initialOrdinal:entranceOrdinal];
        entranceOrdinal += 1;
    }];

    [visibleIndexPaths enumerateObjectsUsingBlock:^(NSIndexPath * _Nonnull indexPath, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)idx;
        (void)stop;
        UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:indexPath];
        [self pp_animateHomeEntranceForCell:cell
                                atIndexPath:indexPath
                             initialOrdinal:entranceOrdinal];
        entranceOrdinal += 1;
    }];
}

- (void)pp_animateHomeEntranceForCell:(UICollectionViewCell *)cell
                          atIndexPath:(NSIndexPath *)indexPath
                       initialOrdinal:(NSUInteger)initialOrdinal
{
    if (!cell || !indexPath) {
        return;
    }

    NSString *key = [self pp_homeEntranceKeyForIndexPath:indexPath kind:nil];
    if (key.length == 0 || [self.animatedHomeItemIdentifiers containsObject:key]) {
        return;
    }
    [self.animatedHomeItemIdentifiers addObject:key];

    if ([self pp_shouldReduceHomeMotion]) {
        cell.alpha = 1.0;
        cell.transform = CGAffineTransformIdentity;
        return;
    }

    [cell.layer removeAllAnimations];
    [cell.contentView.layer removeAllAnimations];

    BOOL isLateAppearance = (initialOrdinal == NSNotFound);
    if (isLateAppearance) {
        cell.alpha = 1.0;
        cell.transform = CGAffineTransformIdentity;
        return;
    }

    PPHomeSection section = [self sectionTypeForIndexPath:indexPath];
    BOOL isHero = (section == PPHomeSectionHero);
    BOOL isPrimarySurface = isHero
        || section == PPHomeSectionQuickActions
        || section == PPHomeSectionCurrentOrders
        || section == PPHomeSectionPetProfile
        || section == PPHomeSectionPremiumSearch
        || section == PPHomeSectionPremiumCare;

    NSTimeInterval duration = isHero ? 0.48 : (isPrimarySurface ? 0.38 : 0.32);
    NSTimeInterval delay = MIN(0.04 + (0.032 * initialOrdinal), 0.24);
    CGFloat damping = isHero ? 0.84 : 0.88;

    [self pp_configureHomeEntranceInitialStateForCell:cell
                                          atIndexPath:indexPath
                                       lateAppearance:NO];

    [UIView animateWithDuration:duration
                          delay:delay
         usingSpringWithDamping:damping
          initialSpringVelocity:0.12
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        cell.alpha = 1.0;
        cell.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_animateHomeEntranceForSupplementaryView:(UICollectionReusableView *)supplementaryView
                                              kind:(NSString *)kind
                                       atIndexPath:(NSIndexPath *)indexPath
                                    initialOrdinal:(NSUInteger)initialOrdinal
{
    if (!supplementaryView || !indexPath || ![kind isEqualToString:UICollectionElementKindSectionHeader]) {
        return;
    }

    PPHomeSection section = [self sectionTypeForIndexPath:indexPath];
    NSNumber *sectionNumber = @(section);
    if ([self.animatedHomeHeaderSections containsObject:sectionNumber]) {
        return;
    }
    [self.animatedHomeHeaderSections addObject:sectionNumber];

    if ([self pp_shouldReduceHomeMotion]) {
        supplementaryView.alpha = 1.0;
        supplementaryView.transform = CGAffineTransformIdentity;
        return;
    }

    [supplementaryView.layer removeAllAnimations];
    BOOL isLateAppearance = (initialOrdinal == NSNotFound);
    if (isLateAppearance) {
        // Section headers should also avoid replaying the entrance reset after the initial
        // home reveal, otherwise the section stack visibly jitters when the screen reappears.
        supplementaryView.alpha = 1.0;
        supplementaryView.transform = CGAffineTransformIdentity;
        return;
    }

    NSTimeInterval delay = isLateAppearance ? 0.0 : MIN(0.03 + (0.028 * initialOrdinal), 0.20);
    NSTimeInterval duration = isLateAppearance ? 0.18 : 0.30;

    [self pp_configureHomeEntranceInitialStateForSupplementaryView:supplementaryView
                                                              kind:kind
                                                       atIndexPath:indexPath
                                                    lateAppearance:isLateAppearance];

    [UIView animateWithDuration:duration
                          delay:delay
         usingSpringWithDamping:0.9
          initialSpringVelocity:0.1
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        supplementaryView.alpha = 1.0;
        supplementaryView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (BOOL)pp_homeSectionUsesHorizontalUniversalCards:(PPHomeSection)section
{
    return section == PPHomeSectionSuggestions ||
           section == PPHomeSectionAccessories ||
           section == PPHomeSectionLastFood ||
           section == PPHomeSectionAdsNearBy ||
           section == PPHomeSectionNearbyServices ||
           section == PPHomeSectionBuyAgain;
}

- (void)pp_animateHorizontalUniversalCellIfNeeded:(UICollectionViewCell *)cell
                                      atIndexPath:(NSIndexPath *)indexPath
                                          section:(PPHomeSection)section
{
    if (!cell || !indexPath || ![cell isKindOfClass:PPUniversalCell.class]) {
        return;
    }

    if (![self pp_homeSectionUsesHorizontalUniversalCards:section]) {
        return;
    }

    if (![self pp_isInitialHomeRevealSettled]) {
        return;
    }

    if ([self pp_shouldReduceHomeMotion]) {
        cell.alpha = 1.0;
        cell.transform = CGAffineTransformIdentity;
        cell.contentView.alpha = 1.0;
        return;
    }

    NSString *baseKey = [self pp_homeEntranceKeyForIndexPath:indexPath kind:nil];
    if (baseKey.length == 0) {
        baseKey = [NSString stringWithFormat:@"section-%ld-item-%ld", (long)section, (long)indexPath.item];
    }
    NSString *motionKey = [@"horizontal-universal-" stringByAppendingString:baseKey];
    if ([self.animatedHomeHorizontalUniversalIdentifiers containsObject:motionKey]) {
        cell.alpha = 1.0;
        cell.transform = CGAffineTransformIdentity;
        cell.contentView.alpha = 1.0;
        return;
    }
    [self.animatedHomeHorizontalUniversalIdentifiers addObject:motionKey];

    [cell.layer removeAnimationForKey:@"pp.home.horizontalUniversal.display"];
    CGFloat direction = Language.isRTL ? -1.0 : 1.0;
    cell.alpha = 0.0;
    cell.contentView.alpha = 0.78;
    cell.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(direction * 26.0, 10.0),
                                             CGAffineTransformMakeScale(0.970, 0.970));

    NSTimeInterval delay = MIN((indexPath.item % 4) * 0.045, 0.135);
    [UIView animateWithDuration:0.62
                          delay:delay
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.14
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        cell.alpha = 1.0;
        cell.contentView.alpha = 1.0;
        cell.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_animateHomeCell:(UICollectionViewCell *)cell highlighted:(BOOL)highlighted
{
    if (!cell) {
        return;
    }

    if (UIAccessibilityIsReduceMotionEnabled()) {
        cell.transform = CGAffineTransformIdentity;
        cell.alpha = 1.0;
        return;
    }

    [UIView animateWithDuration:(highlighted ? 0.12 : 0.20)
                          delay:0.0
         usingSpringWithDamping:(highlighted ? 1.0 : 0.78)
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        cell.transform = highlighted ? CGAffineTransformMakeScale(0.975, 0.975) : CGAffineTransformIdentity;
        cell.alpha = highlighted ? 0.96 : 1.0;
    } completion:nil];
}

- (void)pp_configureHomeEntranceInitialStateForCell:(UICollectionViewCell *)cell
                                        atIndexPath:(NSIndexPath *)indexPath
                                     lateAppearance:(BOOL)isLateAppearance
{
    if (!cell || !indexPath) {
        return;
    }

    PPHomeSection section = [self sectionTypeForIndexPath:indexPath];
    BOOL isHero = (section == PPHomeSectionHero);
    BOOL isPrimarySurface = isHero
        || section == PPHomeSectionQuickActions
        || section == PPHomeSectionCurrentOrders
        || section == PPHomeSectionPetProfile
        || section == PPHomeSectionPremiumSearch
        || section == PPHomeSectionPremiumCare;

    CGFloat translateY = isLateAppearance ? (isHero ? 6.0 : (isPrimarySurface ? 4.0 : 3.0))
                                          : (isHero ? 14.0 : (isPrimarySurface ? 10.0 : 7.0));
    CGFloat scale = isLateAppearance ? (isHero ? 0.996 : (isPrimarySurface ? 0.997 : 0.998))
                                     : (isHero ? 0.992 : (isPrimarySurface ? 0.994 : 0.996));
    CGFloat initialAlpha = isLateAppearance ? 0.0 : (isHero ? 0.0 : 0.04);

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [cell.layer removeAllAnimations];
    [cell.contentView.layer removeAllAnimations];
    cell.contentView.layer.transform = CATransform3DIdentity;
    cell.contentView.layer.opacity = 1.0f;
    cell.contentView.layer.zPosition = 0.0f;

    cell.alpha = initialAlpha;
    CGAffineTransform transform = CGAffineTransformMakeTranslation(0.0, translateY);
    cell.transform = CGAffineTransformScale(transform, scale, scale);
    [CATransaction commit];
}

- (void)pp_configureHomeEntranceInitialStateForSupplementaryView:(UICollectionReusableView *)supplementaryView
                                                            kind:(NSString *)kind
                                                     atIndexPath:(NSIndexPath *)indexPath
                                                  lateAppearance:(BOOL)isLateAppearance
{
    if (!supplementaryView || !indexPath || ![kind isEqualToString:UICollectionElementKindSectionHeader]) {
        return;
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [supplementaryView.layer removeAllAnimations];
    supplementaryView.layer.transform = CATransform3DIdentity;
    supplementaryView.layer.opacity = 1.0f;
    supplementaryView.layer.zPosition = 0.0f;
    supplementaryView.alpha = 0.0;
    supplementaryView.transform = CGAffineTransformMakeTranslation(0.0, isLateAppearance ? 3.0 : 8.0);
    [CATransaction commit];
}



- (void)setProfileCard
{
    UIImage *profileAvatar = [PPModernAvatarRenderer avatarImageForName:PPCurrentUser.UserName size:36];
    NSString *title = [UsrMgr profileNameAndTitleWithMode:ProfileGreetingShorteningModeShotNameOnly] ? : @"";
    NSString *subtitle = Language.isRTL ? CitiesManager.shared.CurrentCountry.arName : CitiesManager.shared.CurrentCountry.enName ? : @"";
    UIButton *profile = (UIButton *)[self pp_profileViewWithImage:profileAvatar
                                              title:title
                                           subtitle:subtitle
                                          userModel:PPCurrentUser
                                             target:self
                                             action:@selector(profileTapped:)];

    if (@available(iOS 26.0, *)) {
        profile.configuration = [UIButtonConfiguration glassButtonConfiguration];
    } else {
        profile.configuration = nil;
        profile.layer.cornerRadius = 22;
        profile.clipsToBounds = YES;
    }

    self.profileCard =
        [self pp_wrappedNavigationTitleView:profile];
    self.profileCard.translatesAutoresizingMaskIntoConstraints = NO;
   // [self.view addSubview:self.profileCard];
}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    if (!self.didApplyInitialHomeAppearanceRefresh) {
        self.didApplyInitialHomeAppearanceRefresh = YES;
        [self pp_refreshThemeSensitiveHomeContent];
    } else {
        [self pp_refreshHomeAppearanceChromeWithoutCollectionReload];
    }
    [self pp_refreshPetProfilesSectionForAppearanceIfNeeded];
    [self pp_refreshSuggestionsForAppearanceIfNeeded];
    [self refreshCurrentOrdersForce:NO];
    [self refreshHeroSectionAppearance];

    PPNavigationController *nav = (PPNavigationController *)self.navigationController;
    if (nav) {
        UIGestureRecognizer *pop = nav.interactivePopGestureRecognizer;

        pop.delegate = nil;   // 🔥 reset UIKit state
        pop.enabled = YES;
        pop.delegate = self;
    }

    if (!self.didAutoScrollSuggestions) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.didAutoScrollSuggestions = YES;
        });
    }

    [self updateCartQuantityBadge];
    [self pp_preparePremiumHomeEntranceStateIfNeeded];
    [self pp_prepareVisibleHomeEntranceContentIfNeeded];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    self.isHomeScreenVisible = NO;
    // Keep the active order listener warm across tab/push transitions. Restarting it
    // on every return replays the cached snapshot and restages the visible Home cells.
    [self stopNearbyRefreshTimer];
    [self pp_stopHomeSmartSearchTimer];
    [self pp_detachHomeSmartSearchTitleViewIfNeeded];
    [self pp_detachHomeLocationTitleViewIfNeeded];
    [self pp_stopNovaFloatingMotion];
}

// Show bottom card with haptic feedback
- (void)showBottomCard:(UIView *)card
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self showBottomCard:card]; });
        return;
    }
    // Hardware haptic feedback
    UIImpactFeedbackGenerator *gen =
        [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleSoft];
    [gen prepare];
    [gen impactOccurred];

    card.hidden = NO;
    card.transform = CGAffineTransformMakeTranslation(0, 40);
    card.alpha = 0.0;

    [UIView animateWithDuration:0.45
                          delay:0
         usingSpringWithDamping:0.85
          initialSpringVelocity:0.6
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        card.transform = CGAffineTransformIdentity;
        card.alpha = 1.0;
    } completion:nil];
}


// Hide bottom card with haptic feedback
- (void)hideBottomCard:(UIView *)card
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self hideBottomCard:card]; });
        return;
    }
    // Hardware haptic feedback
    UIImpactFeedbackGenerator *gen =
        [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [gen prepare];
    [gen impactOccurred];

    [UIView animateWithDuration:0.25
                          delay:0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        card.transform = CGAffineTransformMakeTranslation(0, 30);
        card.alpha = 0.0;
    } completion:^(BOOL finished) {
        card.hidden = YES;
        card.transform = CGAffineTransformIdentity;
    }];
}

- (void)cartClick
{
    NSLog(@"[Cart] Tap");

    if (!PPIsUserLoggedIn) { [UserManager showPromptOnTopController]; return; }

    CartViewController *vc = [[CartViewController alloc] init];
    vc.pp_transitionStyle = PPTransitionStyleFade;

    // Embed in nav
    PPNavigationController *nav =
        [[PPNavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;

    // ✅ PRESENT THE NAV — NOT vc
    [PPHomeHelper presentViewControllerSafely:nav
                                         from:self
                                     animated:YES
                                   completion:nil];
}

- (BOOL)pp_canOwnHomeNavigationChrome
{
    UINavigationController *nav = self.navigationController;
    return self.isViewLoaded && (!nav || nav.topViewController == self);
}

- (void)pp_detachHomeSmartSearchTitleViewIfNeeded
{
    if (!self.homeSmartSearchView) {
        return;
    }

    [self pp_stopHomeSmartSearchTimer];

    if (self.navigationItem.titleView == self.homeSmartSearchView) {
        self.navigationItem.titleView = nil;
    }

    if (self.homeSmartSearchView.superview) {
        [self.homeSmartSearchView removeFromSuperview];
    }
}

- (void)pp_detachHomeLocationTitleViewIfNeeded
{
    if (!self.homeLocationTitleView) {
        return;
    }

    [self.homeLocationTitleView stopLivingMotion];

    if (self.navigationItem.titleView == self.homeLocationTitleView) {
        self.navigationItem.titleView = nil;
    }

    if (self.homeLocationTitleView.superview) {
        [self.homeLocationTitleView removeFromSuperview];
    }
}

- (void)configureNavigationBar {
    if (!self.navigationController) {
        return;
    }
    if (![self pp_canOwnHomeNavigationChrome]) {
        [self pp_detachHomeSmartSearchTitleViewIfNeeded];
        [self pp_detachHomeLocationTitleViewIfNeeded];
        return;
    }

    BOOL useSmartSearch = [self.homeTitleViewMode isEqualToString:@"search"];

    if (useSmartSearch) {
        [self pp_detachHomeLocationTitleViewIfNeeded];
    } else {
        [self pp_detachHomeSmartSearchTitleViewIfNeeded];
    }

    self.navigationItem.title = nil;
    UIView *centerView = useSmartSearch
        ? [self pp_navigationSmartSearchTitleView]
        : [self pp_navigationLocationTitleView];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    UIBarButtonItem *profileItem = [self pp_buildProfileBarButtonItem];
    self.homeProfileItem = profileItem;
    self.homeCartItem = [self pp_buildCartBarButtonItem];

    self.navigationItem.leftBarButtonItems  = PPHomeBarButtonItems(profileItem);
    NSInteger cartCount = [CartManager.sharedManager totalItemsCount];
    [self refreshNavigationRightItemsForCartCount:cartCount];
    [self pp_applyHomeCartBadgeCount:cartCount animated:NO];

    [self pp_navBarSetTitleViewCentered:nil];
    self.navigationItem.titleView = centerView;
    centerView.hidden = NO;

    if (useSmartSearch) {
        [self pp_updateHomeSmartSearchTitleViewWidth];
        [self pp_updateHomeSmartSearchPlaceholderAnimated:NO];
        [self pp_startHomeSmartSearchTimerIfNeeded];
    } else {
        [self pp_refreshHomeLocationTitleViewAnimated:NO];
        [self.homeLocationTitleView playEntranceIfNeeded];
        [self.homeLocationTitleView startLivingMotion];
        [self pp_updateHomeLocationTitleViewWidth];
    }
}

- (UIBarButtonItem *)pp_buildCartBarButtonItem
{
    self.homeCartButton = [self pp_ButtonWithSystemName:@"cart" action:@selector(cartClick)];
    self.homeCartButton.accessibilityLabel = NSLocalizedString(@"a11y_btn_cart", @"Shopping cart");
    self.homeCartButton.accessibilityHint  = NSLocalizedString(@"a11y_btn_cart_hint", @"Double-tap to open your cart");

    NSMutableArray<NSLayoutConstraint *> *sizeConstraints = [NSMutableArray array];
    for (NSLayoutConstraint *constraint in self.homeCartButton.constraints.copy) {
        if (constraint.firstItem == self.homeCartButton &&
            (constraint.firstAttribute == NSLayoutAttributeWidth ||
             constraint.firstAttribute == NSLayoutAttributeHeight)) {
            [sizeConstraints addObject:constraint];
        }
    }
    [NSLayoutConstraint deactivateConstraints:sizeConstraints];

    CGFloat cartButtonSide = 35.0;
    self.homeCartButton.translatesAutoresizingMaskIntoConstraints = YES;
    self.homeCartButton.frame = CGRectMake(0.0, 0.0, cartButtonSide, cartButtonSide);
    self.homeCartButton.bounds = CGRectMake(0.0, 0.0, cartButtonSide, cartButtonSide);
    self.homeCartButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

   

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *configuration = self.homeCartButton.configuration;
        if (configuration) {
            configuration.background.cornerRadius = cartButtonSide * 0.5;
            self.homeCartButton.configuration = configuration;
        }
    } else {
        self.homeCartButton.layer.cornerRadius = cartButtonSide * 0.5;
    }

    return [[UIBarButtonItem alloc] initWithCustomView:self.homeCartButton];
}


- (UIView *)pp_buildProfileVerificationBadgeView
{
    static const CGFloat kBadgeSize = 18.0;
    static const CGFloat kIconSize  = 16.0;

    // Outer ring — visible white circle so badge floats above the avatar
    UIView *badgeView = [[UIView alloc] init];
    badgeView.translatesAutoresizingMaskIntoConstraints = NO;
    badgeView.userInteractionEnabled = NO;
    badgeView.isAccessibilityElement = NO;
    badgeView.backgroundColor = [UIColor systemBackgroundColor];
    badgeView.layer.cornerRadius = kBadgeSize / 2.0;
    badgeView.clipsToBounds = YES;

    // Force .alwaysOriginal rendering — the asset catalog marks this
    // image as "template", which strips the colors and applies tintColor.
    // We need the actual colored icon.
    UIImage *rawIcon = [UIImage imageNamed:@"verify_icon_colored"];
    UIImage *coloredIcon = [rawIcon imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];

    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.image = coloredIcon;
    [badgeView addSubview:iconView];

    [NSLayoutConstraint activateConstraints:@[
        [badgeView.widthAnchor constraintEqualToConstant:kBadgeSize],
        [badgeView.heightAnchor constraintEqualToConstant:kBadgeSize],
        [iconView.centerXAnchor constraintEqualToAnchor:badgeView.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:badgeView.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:kIconSize],
        [iconView.heightAnchor constraintEqualToConstant:kIconSize],
    ]];

    // Spring entrance animation
    badgeView.alpha = 0.0;
    badgeView.transform = CGAffineTransformMakeScale(0.82, 0.82);
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.36
                              delay:0.04
             usingSpringWithDamping:0.72
              initialSpringVelocity:0.28
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            badgeView.alpha = 1.0;
            badgeView.transform = CGAffineTransformIdentity;
        } completion:nil];
    });

    return badgeView;
}

- (UIBarButtonItem *)pp_buildProfileBarButtonItem
{
    static const CGFloat kSize = 36.0;
    static const CGFloat kBadgeOverflow = 0.0;
    static const CGFloat kContainerSize = kSize + kBadgeOverflow;

    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.clipsToBounds = NO;
    container.backgroundColor = UIColor.clearColor;
    container.userInteractionEnabled = YES;
    container.frame = CGRectMake(0.0, 0.0, kContainerSize, kContainerSize);
    container.bounds = (CGRect){CGPointZero, CGSizeMake(kContainerSize, kContainerSize)};

    [NSLayoutConstraint activateConstraints:@[
        [container.widthAnchor constraintEqualToConstant:kContainerSize],
        [container.heightAnchor constraintEqualToConstant:kContainerSize],
    ]];

    [container setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.tag = 8801; // tag for lookup in pp_refreshNavigationMenusForCurrentUser
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.contentEdgeInsets = UIEdgeInsetsZero;
    button.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.72] ?: [UIColor colorWithWhite:1.0 alpha:0.90];
    button.clipsToBounds = NO;
    button.layer.cornerRadius = kSize * 0.5;
    button.layer.borderWidth = 0.8;
    [button pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:0.12]];
    [button pp_setShadowColor:UIColor.clearColor];
    button.layer.shadowOpacity = 0.0;
    button.layer.shadowRadius = 0.0;
    button.layer.shadowOffset = CGSizeMake(0.0, 0.0);
    button.adjustsImageWhenHighlighted = NO;
    button.accessibilityLabel = kLang(@"Profile") ?: @"Profile";
    button.accessibilityValue = PPCurrentUser.isVerified ? (kLang(@"a11y_profile_verified_value") ?: @"Verified account") : nil;
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [button addTarget:self
               action:@selector(profileTapped:)
     forControlEvents:UIControlEventTouchUpInside];

    [container addSubview:button];
    [NSLayoutConstraint activateConstraints:@[
        [button.widthAnchor constraintEqualToConstant:kSize],
        [button.heightAnchor constraintEqualToConstant:kSize],
        [button.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [button.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [button.centerYAnchor constraintEqualToAnchor:container.centerYAnchor]
    ]];

    UIImageView *avatar = [[UIImageView alloc] init];
    avatar.translatesAutoresizingMaskIntoConstraints = NO;
    avatar.contentMode = UIViewContentModeScaleAspectFill;
    avatar.clipsToBounds = YES;
    avatar.layer.cornerRadius = (kSize * 0.5) - 1.0;
    avatar.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    [button addSubview:avatar];
    [NSLayoutConstraint activateConstraints:@[
        [avatar.topAnchor constraintEqualToAnchor:button.topAnchor constant:1.0],
        [avatar.leadingAnchor constraintEqualToAnchor:button.leadingAnchor constant:1.0],
        [avatar.trailingAnchor constraintEqualToAnchor:button.trailingAnchor constant:-1.0],
        [avatar.bottomAnchor constraintEqualToAnchor:button.bottomAnchor constant:-1.0]
    ]];

    // Placeholder — PPModernAvatarRenderer for personalized initials
    UIImage *renderedAvatar = [PPModernAvatarRenderer avatarImageForName:PPCurrentUser.UserName size:34];

    avatar.image = renderedAvatar;
    avatar.tintColor = nil;
    avatar.contentMode = UIViewContentModeScaleAspectFill;

    // Remote image
    NSString *url = PPSafeString(PPCurrentUser.UserImageUrl.absoluteString);
    if (url.length > 0) {
        [GM setImageFromUrlString:url
                        imageView:avatar
                          phImage:@"man"
                       completion:^(UIImage * _Nullable image,
                                    NSError * _Nullable error)
        {
            if (!image || error) {
                avatar.image = renderedAvatar;
                avatar.tintColor = nil;
                avatar.contentMode = UIViewContentModeScaleAspectFill;
                return;
            }
            avatar.image = image;
            avatar.tintColor = nil;
            avatar.contentMode = UIViewContentModeScaleAspectFill;
        }];
    }

    // ── Verified badge — added to CONTAINER (above button) so it is never clipped ──
    if (PPCurrentUser.isVerified) {
        UIView *verifiedBadge = [self pp_buildProfileVerificationBadgeView];
        [container addSubview:verifiedBadge];
        [NSLayoutConstraint activateConstraints:@[
            [verifiedBadge.trailingAnchor constraintEqualToAnchor:button.trailingAnchor constant:2],
            [verifiedBadge.bottomAnchor constraintEqualToAnchor:button.bottomAnchor constant:2]
        ]];
    }

    PPHomePrepareProfileMenuButton(button);

    return [[UIBarButtonItem alloc] initWithCustomView:container];
}


- (void)refreshNavigationRightItemsForCartCount:(NSUInteger)count
{
    (void)count;
    UIBarButtonItem *cartItem = self.homeCartItem;
    if (!cartItem) {
        self.navigationItem.rightBarButtonItems = @[];
        return;
    }

    BOOL isAlreadyShowing = [self.navigationItem.rightBarButtonItems containsObject:cartItem];
    if (!isAlreadyShowing || self.navigationItem.rightBarButtonItems.count != 1) {
        self.navigationItem.rightBarButtonItems = PPHomeBarButtonItems(cartItem);
    }

    [self pp_updateHomeSmartSearchTitleViewWidth];
    [self pp_updateHomeLocationTitleViewWidth];
}

- (void)pp_applyHomeCartBadgeCount:(NSInteger)count animated:(BOOL)animated
{
    if (!self.homeCartButton) {
        return;
    }

    UIButton *badgeHost = self.homeCartButton;
    [badgeHost removeBadge];

    if (count <= 0) {
        return;
    }

    NSString *badgeText = (count > 99) ? @"99+" : [NSString stringWithFormat:@"%ld", (long)count];
    UIColor *badgeColor = AppPrimaryClr ?: UIColor.systemPinkColor;

    void (^applyBadge)(void) = ^{
        UIButton *strongBadgeHost = self.homeCartButton;
        if (!strongBadgeHost) {
            return;
        }

        [strongBadgeHost layoutIfNeeded];
        [self.homeCartItem.customView layoutIfNeeded];

        if (CGRectIsEmpty(strongBadgeHost.bounds)) {
            return;
        }

        [strongBadgeHost removeBadge];
        [strongBadgeHost addBadgeWithContent:badgeText
                                  badgeColor:badgeColor
                                     offset:CGPointMake(-10, 10)
                                badgeRadius:9.5];
    };

    applyBadge();

    if (animated || CGRectIsEmpty(badgeHost.bounds)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.navigationController.navigationBar setNeedsLayout];
            [self.navigationController.navigationBar layoutIfNeeded];
            applyBadge();
        });
    }
}

- (CGFloat)preferredNavigationCenterViewWidth
{
    UINavigationBar *navigationBar = self.navigationController.navigationBar;
    if (!navigationBar) {
        return 220.0;
    }

    CGFloat navBarWidth = CGRectGetWidth(navigationBar.bounds);
    if (navBarWidth <= 0.0) {
        return self.homeSmartSearchWidthConstraint.constant > 0.0 ? self.homeSmartSearchWidthConstraint.constant : 220.0;
    }

    UIBarButtonItem *leftItem = self.navigationItem.leftBarButtonItem ?: self.navigationItem.leftBarButtonItems.firstObject;
    UIBarButtonItem *rightItem = self.navigationItem.rightBarButtonItem ?: self.navigationItem.rightBarButtonItems.firstObject;
    CGFloat leftWidth = [self pp_widthForBarButtonItem:leftItem fallback:40.0];
    CGFloat rightWidth = [self pp_widthForBarButtonItem:rightItem fallback:40.0];
    UIEdgeInsets layoutMargins = navigationBar.layoutMargins;
    CGFloat sideMargins = layoutMargins.left + layoutMargins.right;
    CGFloat breathingRoom = 20.0;

    CGFloat availableWidth = navBarWidth - sideMargins - leftWidth - rightWidth - breathingRoom;
    if (availableWidth <= 0.0) {
        return self.homeSmartSearchWidthConstraint.constant > 0.0 ? self.homeSmartSearchWidthConstraint.constant : 220.0;
    }

    return floor(availableWidth);
}

- (CGFloat)pp_widthForBarButtonItem:(UIBarButtonItem *)item fallback:(CGFloat)fallback
{
    if (!item) {
        return fallback;
    }

    UIView *customView = item.customView;
    if (customView) {
        CGFloat width = CGRectGetWidth(customView.bounds);
        if (width <= 0.0) {
            CGSize fittingSize = [customView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
            width = fittingSize.width;
        }
        if (width > 0.0) {
            return ceil(width);
        }
    }

    if (item.width > 0.0) {
        return item.width;
    }

    return fallback;
}

- (CGFloat)pp_preferredNavigationSearchWidth
{
    return [self preferredNavigationCenterViewWidth];
}

- (CGFloat)pp_preferredNavigationLocationTitleWidth
{
    CGFloat width = [self pp_preferredNavigationSearchWidth];
    return width > 0.0 ? floor(width) : 220.0;
}

- (void)pp_updateHomeLocationTitleViewWidth
{
    if (!self.homeLocationTitleView) {
        return;
    }

    CGFloat targetWidth = [self pp_preferredNavigationLocationTitleWidth];
    if (targetWidth > 0.0) {
        self.homeLocationTitleWidthConstraint.constant = targetWidth;
        CGRect frame = self.homeLocationTitleView.frame;
        frame.size = CGSizeMake(targetWidth, 46.0);
        self.homeLocationTitleView.frame = frame;
        self.homeLocationTitleView.bounds = (CGRect){CGPointZero, frame.size};
        [self.homeLocationTitleView invalidateIntrinsicContentSize];
    }

    [self.homeLocationTitleView setNeedsLayout];
    [self.homeLocationTitleView layoutIfNeeded];
    [self.navigationController.navigationBar setNeedsLayout];
}

- (UIColor *)pp_homeLocationTitleStatusColor
{
    switch (self.nearbyLocationState) {
        case PPNearbyLocationStateDenied:
            return UIColor.systemRedColor;
        case PPNearbyLocationStateLoading:
            return UIColor.systemOrangeColor;
        case PPNearbyLocationStateReady:
            return AppPrimaryClr ?: UIColor.systemGreenColor;
        case PPNearbyLocationStateUnset:
        default:
            return AppSecondaryTextClr ?: UIColor.systemGrayColor;
    }
}

- (BOOL)pp_homeLocationTitleShowsLoading
{
    return self.nearbyLocationState == PPNearbyLocationStateLoading;
}

- (NSString *)pp_homeLocationTitleAccessibilityHint
{
    NSString *actionTitle = [self heroLocationActionTitle];
    NSString *safeActionTitle = PPSafeString(actionTitle);
    if (safeActionTitle.length > 0) {
        return safeActionTitle;
    }

    return kLang(@"Hero_LocationCTA") ?: @"Choose area";
}

- (void)pp_refreshHomeLocationTitleViewAnimated:(BOOL)animated
{
    if (!self.homeLocationTitleView) {
        return;
    }

    NSString *title = PPSafeString([self heroCountryText]);
    if (title.length == 0) {
        title = kLang(@"Select your location") ?: @"Select your location";
    }

    [self.homeLocationTitleView configureWithTitle:title
                                       statusColor:[self pp_homeLocationTitleStatusColor]
                                           loading:[self pp_homeLocationTitleShowsLoading]
                                 accessibilityHint:[self pp_homeLocationTitleAccessibilityHint]
                                          animated:animated];
    [self pp_updateHomeLocationTitleViewWidth];
}

- (void)pp_updateHomeSmartSearchTitleViewWidth
{
    if (!self.homeSmartSearchView) {
        return;
    }

    CGFloat targetWidth = [self preferredNavigationCenterViewWidth];
    if (targetWidth > 0.0) {
        self.homeSmartSearchWidthConstraint.constant = targetWidth;
        CGRect frame = self.homeSmartSearchView.frame;
        frame.size = CGSizeMake(targetWidth, 42.0);
        self.homeSmartSearchView.frame = frame;
        self.homeSmartSearchView.bounds = (CGRect){CGPointZero, frame.size};
        [self.homeSmartSearchView invalidateIntrinsicContentSize];
    }

    [self.homeSmartSearchView setNeedsLayout];
    [self.homeSmartSearchView layoutIfNeeded];
    [self.navigationController.navigationBar setNeedsLayout];
}

- (UIView *)pp_navigationLocationTitleView
{
    CGFloat width = [self pp_preferredNavigationLocationTitleWidth];
    if (!self.homeLocationTitleView) {
        self.homeLocationTitleView =
            [[PPHomeLocationTitleView alloc] initWithFrame:CGRectMake(0.0, 0.0, width, 46.0)];
        self.homeLocationTitleView.translatesAutoresizingMaskIntoConstraints = NO;
        self.homeLocationTitleWidthConstraint =
            [self.homeLocationTitleView.widthAnchor constraintEqualToConstant:MAX(width, 220.0)];
        self.homeLocationTitleWidthConstraint.priority = UILayoutPriorityRequired;
        self.homeLocationTitleWidthConstraint.active = YES;
        [self.homeLocationTitleView.heightAnchor constraintEqualToConstant:46.0].active = YES;
        [self.homeLocationTitleView addTarget:self
                                       action:@selector(presentHomeLocationOptions)
                             forControlEvents:UIControlEventTouchUpInside];
    }

    CGRect frame = self.homeLocationTitleView.frame;
    frame.size.width = width;
    frame.size.height = 46.0;
    self.homeLocationTitleView.frame = frame;
    self.homeLocationTitleView.bounds = (CGRect){CGPointZero, frame.size};
    self.homeLocationTitleView.semanticContentAttribute = PPHomeCurrentSemanticAttribute();
    [self pp_refreshHomeLocationTitleViewAnimated:NO];
    return self.homeLocationTitleView;
}

- (UIView *)pp_navigationSmartSearchTitleView
{
    CGFloat width = [self pp_preferredNavigationSearchWidth];
    if (!self.homeSmartSearchView) {
        self.homeSmartSearchView =
            [[PPHomeSmartSearchTitleView alloc] initWithFrame:CGRectMake(0.0, 0.0, width, 46.0)];
        self.homeSmartSearchView.translatesAutoresizingMaskIntoConstraints = NO;
        self.homeSmartSearchWidthConstraint =
            [self.homeSmartSearchView.widthAnchor constraintEqualToConstant:MAX(width, 220.0)];
        self.homeSmartSearchWidthConstraint.priority = UILayoutPriorityRequired;
        self.homeSmartSearchWidthConstraint.active = YES;
        [self.homeSmartSearchView.heightAnchor constraintEqualToConstant:46.0].active = YES;
        self.homeSmartSearchView.showSmartPillBackground = NO;
        [self.homeSmartSearchView addTarget:self
                                     action:@selector(pp_openSmartSearch)
                           forControlEvents:UIControlEventTouchUpInside];
    }

    CGRect frame = self.homeSmartSearchView.frame;
    frame.size.width = width;
    frame.size.height = 46.0;
    self.homeSmartSearchView.frame = frame;
    self.homeSmartSearchView.bounds = (CGRect){CGPointZero, frame.size};
    self.homeSmartSearchView.semanticContentAttribute = PPHomeCurrentSemanticAttribute();
    return self.homeSmartSearchView;
}

- (void)pp_openSmartSearch
{
    UINavigationController *nav = self.navigationController;
    PPSearchViewController *searchVC = nil;

    for (UIViewController *vc in nav.viewControllers.reverseObjectEnumerator) {
        if ([vc isKindOfClass:PPSearchViewController.class]) {
            searchVC = (PPSearchViewController *)vc;
            break;
        }
    }

    if (searchVC) {
        if (nav.topViewController != searchVC) {
            [nav popToViewController:searchVC animated:YES];
        }
    } else {
        searchVC = [PPSearchViewController new];
        [PPHomeHelper pushViewControllerSafely:searchVC from:self animated:YES];
    }

    [searchVC focusSearchField];
}

- (NSArray<NSString *> *)pp_resolvedHomeSmartSearchPlaceholders
{
    if (self.homeSmartSearchPlaceholders.count > 0) {
        return self.homeSmartSearchPlaceholders;
    }

    NSMutableArray<NSString *> *items = [NSMutableArray array];
    BOOL prefersExpandedExamples = [self pp_preferredNavigationSearchWidth] >= 280.0;

    // Base placeholder at index 0 — stays visible longer than rotating examples
    NSString *basePlaceholder = prefersExpandedExamples
        ? (kLang(@"home_nav_search_base_placeholder")         ?: @"What does your pet need today?")
        : (kLang(@"home_nav_search_base_placeholder_compact") ?: @"Search here");
    NSString *safeBase = PPSafeString(basePlaceholder);
    if (safeBase.length > 0) {
        [items addObject:safeBase];
    }

    NSArray<NSString *> *candidates = prefersExpandedExamples
        ? @[
            kLang(@"home_nav_search_example_cats")        ?: @"Cats for sale",
            kLang(@"home_nav_search_example_vets")        ?: @"Nearby vets",
            kLang(@"home_nav_search_example_food")        ?: @"Dog food",
            kLang(@"home_nav_search_example_accessories") ?: @"Pet accessories",
            kLang(@"home_nav_search_example_grooming")    ?: @"Pet grooming",
            kLang(@"home_nav_search_example_training")    ?: @"Dog training",
            kLang(@"home_nav_search_example_birds")       ?: @"Birds for sale",
            kLang(@"home_nav_search_example_toys")        ?: @"Pet toys & games",
            kLang(@"home_nav_search_example_adopt")       ?: @"Adopt a pet",
            kLang(@"home_nav_search_example_fish")        ?: @"Aquarium fish",
            kLang(@"home_nav_search_example_boarding")    ?: @"Pet boarding",
            kLang(@"home_nav_search_example_pharmacy")    ?: @"Pet pharmacy",
        ]
        : @[
            kLang(@"home_nav_search_example_cats_compact")        ?: @"Cats",
            kLang(@"home_nav_search_example_vets_compact")        ?: @"Vet",
            kLang(@"home_nav_search_example_food_compact")        ?: @"Food",
            kLang(@"home_nav_search_example_accessories_compact") ?: @"Gear",
            kLang(@"home_nav_search_example_grooming_compact")    ?: @"Groom",
            kLang(@"home_nav_search_example_training_compact")    ?: @"Train",
            kLang(@"home_nav_search_example_birds_compact")       ?: @"Birds",
            kLang(@"home_nav_search_example_toys_compact")        ?: @"Toys",
            kLang(@"home_nav_search_example_adopt_compact")       ?: @"Adopt",
            kLang(@"home_nav_search_example_fish_compact")        ?: @"Fish",
            kLang(@"home_nav_search_example_boarding_compact")    ?: @"Board",
            kLang(@"home_nav_search_example_pharmacy_compact")    ?: @"Meds",
        ];

    for (NSString *item in candidates) {
        NSString *safeItem = PPSafeString(item);
        if (safeItem.length > 0 && ![items containsObject:safeItem]) {
            [items addObject:safeItem];
        }
    }

    if (items.count == 0) {
        [items addObject:(kLang(@"home_search_placeholder_short") ?: @"Search in Pure Pets")];
    }

    self.homeSmartSearchPlaceholders = items.copy;
    self.homeSmartSearchPlaceholderIndex = 0;
    return self.homeSmartSearchPlaceholders;
}

- (NSString *)pp_currentHomeSmartSearchPlaceholder
{
    NSArray<NSString *> *placeholders = [self pp_resolvedHomeSmartSearchPlaceholders];
    if (placeholders.count == 0) {
        return kLang(@"home_nav_search_example_cats") ?: @"Cats for sale";
    }

    NSInteger safeIndex = MAX(0, MIN(self.homeSmartSearchPlaceholderIndex,
                                     (NSInteger)placeholders.count - 1));
    return placeholders[safeIndex];
}

- (void)pp_updateHomeSmartSearchPlaceholderAnimated:(BOOL)animated
{
    NSString *placeholder = [self pp_currentHomeSmartSearchPlaceholder];

    if (self.homeSmartSearchView) {
        [self.homeSmartSearchView setQueryText:placeholder
                                      animated:animated];
    }
}

- (void)pp_startHomeSmartSearchTimerIfNeeded
{
    [self pp_updateHomeSmartSearchPlaceholderAnimated:NO];

    NSArray<NSString *> *placeholders = [self pp_resolvedHomeSmartSearchPlaceholders];
    if (placeholders.count <= 1 || self.homeSmartSearchTimer) {
        return;
    }

    // Base placeholder (index 0) stays visible longer than rotating examples
    NSTimeInterval firstInterval =
        (self.homeSmartSearchPlaceholderIndex == 0) ? 5.0 : 2.4;
    [self pp_scheduleSmartSearchTimerWithInterval:firstInterval];
}

- (void)pp_stopHomeSmartSearchTimer
{
    [self.homeSmartSearchTimer invalidate];
    self.homeSmartSearchTimer = nil;
}

- (void)pp_scheduleSmartSearchTimerWithInterval:(NSTimeInterval)interval
{
    [self.homeSmartSearchTimer invalidate];
    NSTimer *timer =
        [NSTimer timerWithTimeInterval:interval
                                target:self
                              selector:@selector(pp_advanceHomeSmartSearchPlaceholder)
                              userInfo:nil
                               repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    self.homeSmartSearchTimer = timer;
}

- (void)pp_advanceHomeSmartSearchPlaceholder
{
    NSArray<NSString *> *placeholders = [self pp_resolvedHomeSmartSearchPlaceholders];
    if (placeholders.count == 0) {
        return;
    }

    self.homeSmartSearchPlaceholderIndex =
        (self.homeSmartSearchPlaceholderIndex + 1) % placeholders.count;
    [self pp_updateHomeSmartSearchPlaceholderAnimated:YES];

    // Base placeholder (index 0) lingers ~2× longer than category examples
    NSTimeInterval nextInterval =
        (self.homeSmartSearchPlaceholderIndex == 0) ? 5.0 : 2.4;
    [self pp_scheduleSmartSearchTimerWithInterval:nextInterval];
}

#pragma mark - Navigation Logo Title View

- (UIView *)pp_logoTitleView
{
    UIImage *logo = [UIImage imageNamed:@"newlogo"]; // 🔁 change name if needed
    if (!logo) return nil;

    UIImageView *logoView = [[UIImageView alloc] initWithImage:logo];
    logoView.translatesAutoresizingMaskIntoConstraints = NO;
    logoView.contentMode = UIViewContentModeScaleToFill;

    // Prevent compression / jumping
    [logoView setContentHuggingPriority:UILayoutPriorityRequired
                                forAxis:UILayoutConstraintAxisHorizontal];
    [logoView setContentCompressionResistancePriority:UILayoutPriorityRequired
                                              forAxis:UILayoutConstraintAxisHorizontal];

    // Wrap using YOUR helper (important)
    UIView *wrapped = [self pp_wrappedNavigationTitleView:logoView];

    // Explicit size so UIKit never guesses
    CGFloat height =  46.0;

    [NSLayoutConstraint activateConstraints:@[
        [logoView.heightAnchor constraintEqualToConstant:height],
        [logoView.centerXAnchor constraintEqualToAnchor:wrapped.centerXAnchor],
        [logoView.centerYAnchor constraintEqualToAnchor:wrapped.centerYAnchor],
        [logoView.widthAnchor constraintEqualToConstant:height],

    ]];

    [NSLayoutConstraint activateConstraints:@[
        [wrapped.heightAnchor constraintEqualToConstant:height],
        [wrapped.widthAnchor constraintEqualToConstant:height],

    ]];

    return wrapped;
}

- (UIView *)pp_wrappedNavigationTitleView:(UIView *)content
{
    CGFloat navHeight = 36.0;

    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.hx_w - 32, navHeight)];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = UIColor.clearColor;
    container.semanticContentAttribute = PPHomeCurrentSemanticAttribute();

    content.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:content];

    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [content.topAnchor constraintEqualToAnchor:container.topAnchor],
        [content.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];

    return container;
}

#pragma mark - Top/Nav UI
- (void)profileTapped:(UIButton *)sender {
    NSMutableArray<FTPopOverMenuModel *> *menuItems = [NSMutableArray array];
    NSMutableArray<NSNumber *> *menuActions = [NSMutableArray array];
    void (^appendAction)(NSString *, NSString *, PPHomeProfileMenuAction) =
    ^(NSString *title, NSString *imageName, PPHomeProfileMenuAction action) {
        FTPopOverMenuModel *item = [[FTPopOverMenuModel alloc] init];
        item.title = title ?: @"";
        item.image = [UIImage systemImageNamed:imageName];
        [menuItems addObject:item];
        [menuActions addObject:@(action)];
    };

    if (UserManager.sharedManager.currentUser) {
        appendAction(kLang(@"showProfile"), @"person.circle.fill", PPHomeProfileMenuActionProfile);
    } else {
        appendAction(kLang(@"go_to_login"), @"person.crop.circle.fill.badge.plus", PPHomeProfileMenuActionLogin);
    }
    appendAction(kLang(@"showfav"), @"star.fill", PPHomeProfileMenuActionFavorites);
    appendAction(kLang(@"myadsTitle"), @"circle.hexagonpath.fill", PPHomeProfileMenuActionMyAds);
    appendAction(kLang(@"Cart"), @"cart.fill", PPHomeProfileMenuActionCart);
    appendAction(kLang(@"OrderHistory"), @"bag.fill", PPHomeProfileMenuActionOrders);

    UserModel *currentUser = UserManager.sharedManager.currentUser;
    if ([currentUser.prodectionStatus isEqualToString:@"active"]) {
        appendAction(kLang(@"showProdection"), @"doc.on.doc.fill", PPHomeProfileMenuActionProduction);
    }
    appendAction(kLang(@"Setting"), @"gear", PPHomeProfileMenuActionSettings);
    appendAction(kLang(@"supprot"), @"person.crop.circle.badge.questionmark", PPHomeProfileMenuActionSupport);

    FTPopOverMenuConfiguration *configuration = [GM configMenu:nil];
    configuration.textFont = [GM MidFontWithSize:16];

    __weak typeof(self) weakSelf = self;
    [FTPopOverMenu showForSender:sender
                   withMenuArray:menuItems
                      imageArray:nil
                   configuration:configuration
                       doneBlock:^(NSInteger selectedIndex) {
        if (selectedIndex < 0 || selectedIndex >= (NSInteger)menuActions.count) {
            return;
        }
        [weakSelf pp_handleProfileMenuAction:(PPHomeProfileMenuAction)menuActions[selectedIndex].integerValue];
    }
                    dismissBlock:nil];
}

- (void)pp_handleProfileMenuAction:(PPHomeProfileMenuAction)action {
    switch (action) {
        case PPHomeProfileMenuActionProfile: {
            ProfileVC *vc = [ProfileVC new];
            vc.view.layer.cornerRadius = 42;
            vc.view.backgroundColor = AppBackgroundClr;
            vc.view.clipsToBounds = YES;
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }
        case PPHomeProfileMenuActionLogin:
            [PPUserSigningManager presentSignInFrom:self
                                    withCountryCode:CitiesManager.shared.CurrentCountry.countryCode
                                  presentationStyle:PPSignInPresentationStyleSheet
                               autoDismissOnSuccess:YES
                                             success:^(UserModel *user) {
                [PPFunc reloadAppUI];
                [[AppDataListenerManager shared] stopAllListeners];
                [[AppDataListenerManager shared] startListenersForUser:PPCurrentUser.ID];
            } failure:nil cancelled:nil];
            break;
        case PPHomeProfileMenuActionFavorites: {
            if (![PPFunc PPUserCheck]) return;
            MyItemsViewController *vc = [[MyItemsViewController alloc] initWithMode:MyItemsModeFavorites];
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }
        case PPHomeProfileMenuActionMyAds: {
            if (![PPFunc PPUserCheck]) return;
            MyItemsViewController *vc = [[MyItemsViewController alloc] initWithMode:MyItemsModeMyAds];
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }
        case PPHomeProfileMenuActionCart: {
            if (![PPFunc PPUserCheck]) return;
            CartViewController *vc = [CartViewController new];
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }
        case PPHomeProfileMenuActionOrders: {
            if (![PPFunc PPUserCheck]) return;
            OrderHistoryViewController *vc = [OrderHistoryViewController new];
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }
        case PPHomeProfileMenuActionProduction: {
            MainController *vc = [MainController new];
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }
        case PPHomeProfileMenuActionSettings: {
            SettingVC *vc = [SettingVC new];
            [PPFunc presentSheetFrom:self sheetVC:vc detentStyle:PPSheetDetentStyle70];
            break;
        }
        case PPHomeProfileMenuActionSupport: {
            CompanyLocationVC *vc = [CompanyLocationVC new];
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }
    }
}

- (void)presentMenu:(UIMenu *)menu fromView:(UIView *)sourceView {
    (void)menu;
    (void)sourceView;
}

- (MainBannerModel *)pp_homeTopCarouselBannerGroup
{
    NSArray<MainBannerModel *> *candidates =
    [PPBannersManager.sharedManager.bannerGroups filteredArrayUsingPredicate:
     [NSPredicate predicateWithBlock:^BOOL (MainBannerModel *g, NSDictionary *_) {
        return (g.bannerViewHolder == PPBannerHolderMainView &&
                g.bannerViewPosition == PPBannerPositionTop &&
                g.bannerViewVisible);
    }]];

    if (candidates.count == 0) return nil;

    for (MainBannerModel *group in candidates) {
        if ([PPSafeString(group.bannerViewID) caseInsensitiveCompare:PPHomeTopCarouselBannerGroupID] == NSOrderedSame) {
            return group;
        }
    }

    NSArray<MainBannerModel *> *sorted =
    [candidates sortedArrayUsingComparator:^NSComparisonResult(MainBannerModel *a, MainBannerModel *b) {
        return [PPSafeString(a.bannerViewID) localizedCaseInsensitiveCompare:PPSafeString(b.bannerViewID)];
    }];
    return sorted.firstObject;
}

- (void)fillCarouselBanner
{
    if (!self.dataSource) return;

    NSDiffableDataSourceSnapshot *snapshot = self.dataSource.snapshot;
    NSArray *carouselItems = [self pp_safeItemsInSection:PPHomeSectionCarousel
                                              fromSnapshot:snapshot];
    if (carouselItems.count == 0) return;

    PPHomeItem *existing = carouselItems.firstObject;

    // Resolve promo cards: Firestore → legacy banners → fallback
    NSArray<PPHomePromoCarouselCard *> *promoCards = self.promoCarouselCards;
    if (promoCards.count == 0) {
        MainBannerModel *legacyGroup = [self pp_homeTopCarouselBannerGroup];
        if (legacyGroup && legacyGroup.childBanners.count > 0) {
            promoCards = [self pp_promoCardsFromLegacyBannerGroup:legacyGroup];
        }
    }
    if (promoCards.count == 0) {
        promoCards = [self pp_homePromoFallbackCards];
    }
    if (promoCards.count == 0) return;

    // Skip if the payload is already the same array (pointer equality)
    if (existing.payload == (id)promoCards) return;

    // Update payload in-place and reload — NO insert/delete, NO layout shift
    existing.payload = promoCards;
    [self pp_reconfigureHomeItems:@[existing] inSnapshot:snapshot];
}

/*
 - (void)fillCarouselBanner
 {
     NSDiffableDataSourceSnapshot *snapshot = self.dataSource.snapshot;

     NSArray *items =
         [snapshot itemIdentifiersInSectionWithIdentifier:@(PPHomeSectionCarousel)];
     if (items.count == 0) return;

     PPHomeItem *item = items.firstObject;

     NSArray<PPHomePromoCarouselCard *> *promoCards = self.promoCarouselCards;
     if (promoCards.count > 0) {
         item.payload = promoCards;
         [snapshot reloadItemsWithIdentifiers:@[item]];
         [self.dataSource applySnapshot:snapshot animatingDifferences:NO];
         return;
     }

     MainBannerModel *homeTop = [self pp_homeTopCarouselBannerGroup];

     NSArray<PPHomePromoCarouselCard *> *legacyPromoCards = [self pp_promoCardsFromLegacyBannerGroup:homeTop];
     if (legacyPromoCards.count > 0) {
         item.payload = legacyPromoCards;
         [snapshot reloadItemsWithIdentifiers:@[item]];
         [self.dataSource applySnapshot:snapshot animatingDifferences:NO];
         return;
     }

     if (!homeTop || homeTop.childBanners.count == 0) {
         NSArray<PPHomePromoCarouselCard *> *fallbackCards = [self pp_homePromoFallbackCards];
         if (fallbackCards.count > 0) {
             item.payload = fallbackCards;
             [snapshot reloadItemsWithIdentifiers:@[item]];
             [self.dataSource applySnapshot:snapshot animatingDifferences:NO];
             return;
         }
         item.payload = [NSNull null];
         [snapshot reloadItemsWithIdentifiers:@[item]];
         [self.dataSource applySnapshot:snapshot animatingDifferences:NO];
         return;
     }

     item.payload = homeTop;

     [snapshot reloadItemsWithIdentifiers:@[item]];
     [self.dataSource applySnapshot:snapshot animatingDifferences:NO];
 }
 */




- (UIView *)pp_profileViewWithImage:(UIImage *_Nullable)image
                              title:(NSString *_Nullable)title
                           subtitle:(NSString *_Nullable)subtitle
                          userModel:(UserModel *_Nullable)usr
                             target:(id _Nullable)target
                             action:(SEL _Nullable)action
{
    static const CGFloat kAvatarSize = 36.0;
    static const CGFloat kMinHeight  = 46.0;

    // =====================================================
    // 1️⃣ Container (UIButton – nav-safe)
    // =====================================================
    PPHomeProfileView *container =
        [PPHomeProfileView buttonWithType:UIButtonTypeCustom];
    if (@available(iOS 26.0, *)) {
        container.configuration = [UIButtonConfiguration glassButtonConfiguration];
    } else {
        container.configuration = nil;
    }

    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.adjustsImageWhenHighlighted = NO;
    container.clipsToBounds = NO;
    container.semanticContentAttribute = PPHomeCurrentSemanticAttribute();

    PPHomePrepareProfileMenuButton(container);

    if (target && action) {
        [container addTarget:target
                      action:action
            forControlEvents:UIControlEventTouchUpInside];
    }

    // Hard height for navigation bar stability
    [container.heightAnchor constraintGreaterThanOrEqualToConstant:kMinHeight].active = YES;

    // =====================================================
    // 2️⃣ Avatar
    // =====================================================
    UIImageView *avatar = [[UIImageView alloc] init];
    avatar.translatesAutoresizingMaskIntoConstraints = NO;
    avatar.contentMode = UIViewContentModeScaleAspectFill;
    avatar.layer.cornerRadius = kAvatarSize / 2.0;
    avatar.layer.masksToBounds = YES;
    avatar.tintColor = AppPrimaryTextClr;
    avatar.image = usr
        ? [PPModernAvatarRenderer avatarImageForName:usr.UserName size:kAvatarSize]
        : (image ?: [UIImage systemImageNamed:@"person.crop.circle.fill"]);

    [NSLayoutConstraint activateConstraints:@[
        [avatar.widthAnchor constraintEqualToConstant:kAvatarSize],
        [avatar.heightAnchor constraintEqualToConstant:kAvatarSize]
    ]];

    if (usr) {
        NSString *avatarURLStr = PPSafeString(usr.UserImageUrl.absoluteString);
        if (avatarURLStr.length > 0) {
            [GM setImageFromUrlString:avatarURLStr
                            imageView:avatar
                              phImage:@"person.crop.circle.fill"];
        }
    }

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:16];
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.text = title ?: kLang(@"JoinUs");
    titleLabel.numberOfLines = 1;
    titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    titleLabel.textAlignment = PPHomeCurrentTextAlignment();

    // =====================================================
    // 4️⃣ Subtitle (icon + text, baseline safe)
    // =====================================================
    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM fontWithSize:12];
    subtitleLabel.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    subtitleLabel.numberOfLines = 1;
    subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    subtitleLabel.textAlignment = PPHomeCurrentTextAlignment();

    if (subtitle.length > 0) {
        UIImageSymbolConfiguration *cfg =
            [UIImageSymbolConfiguration configurationWithPointSize:11
                                                            weight:UIImageSymbolWeightRegular];

        NSTextAttachment *att = [[NSTextAttachment alloc] init];
        att.image = [UIImage systemImageNamed:@"location.fill"
                             withConfiguration:cfg];
        att.bounds = CGRectMake(0, -1.5, 12, 12);

        NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] init];
        [attr appendAttributedString:[NSAttributedString attributedStringWithAttachment:att]];
        [attr appendAttributedString:[[NSAttributedString alloc] initWithString:@" "]];
        [attr appendAttributedString:[[NSAttributedString alloc] initWithString:subtitle]];

        subtitleLabel.attributedText = attr;
    }

    // =====================================================
    // 5️⃣ Text stack
    // =====================================================
    UIStackView *textStack =
        [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, subtitleLabel]];

    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = 0;
    textStack.alignment = UIStackViewAlignmentLeading;
    textStack.semanticContentAttribute = PPHomeCurrentSemanticAttribute();

    [titleLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                forAxis:UILayoutConstraintAxisHorizontal];
    [subtitleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                   forAxis:UILayoutConstraintAxisHorizontal];

    // =====================================================
    // 6️⃣ Horizontal layout
    // =====================================================
    UIStackView *contentStack =
        [[UIStackView alloc] initWithArrangedSubviews:@[avatar, textStack]];

    contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    contentStack.axis = UILayoutConstraintAxisHorizontal;
    contentStack.spacing = 10;
    contentStack.alignment = UIStackViewAlignmentCenter;
    contentStack.semanticContentAttribute = PPHomeCurrentSemanticAttribute();

    [container addSubview:contentStack];

    [NSLayoutConstraint activateConstraints:@[
        [contentStack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:6],
        [contentStack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor  constant:-16],
        [contentStack.topAnchor constraintEqualToAnchor:container.topAnchor],
        [contentStack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];

    // =====================================================
    // 7️⃣ Touch feedback (safe)
    // =====================================================
    [container addTarget:container
                  action:@selector(pp_highlightDown)
        forControlEvents:UIControlEventTouchDown];

    [container addTarget:container
                  action:@selector(pp_highlightUp)
        forControlEvents:UIControlEventTouchUpInside |
                        UIControlEventTouchCancel |
                        UIControlEventTouchDragExit];

    return container;
}




#pragma mark - Swipe Back Gesture

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer ==
        self.navigationController.interactivePopGestureRecognizer) {

        // Disable on root VC only
        return self.navigationController.viewControllers.count > 1;
    }
    return YES;
}


-(void)PPUniversalCell_changeQuantity:(PPUniversalCellViewModel *)universalModel quantity:(NSInteger)quantity
{


    if (![universalModel.ModelObject isKindOfClass:[PetAccessory class]]) {
        NSLog(@"[Home][Cart] Ignored quantity change for non-accessory model");
        return;
    }
    PetAccessory *access = (PetAccessory *)universalModel.ModelObject;
    NSInteger maxStock = MAX(access.quantity, 0);
    NSInteger safeQuantity = MAX(0, quantity);

    if (maxStock <= 0 && safeQuantity > 0) {
        [PPHUD showError:kLang(@"Out of stock")];
        safeQuantity = 0;
    } else if (safeQuantity > maxStock) {
        safeQuantity = maxStock;
        [PPHUD showInfo:[NSString stringWithFormat:@"%@ %ld %@",
                         kLang(@"Only"),
                         (long)maxStock,
                         kLang(@"left in stock")]];
    }

    if (safeQuantity == 0) {
        [PPFunc triggerWarningHaptic];
        [[CartManager sharedManager] removeItemForAccessory:access];
    } else {
        CartManager *cart = [CartManager sharedManager];
        CartItem *existing = [cart getCartItemForItemID:access.accessoryID];
        CartItem *item = [[CartItem alloc] initWithAccessory:access quantity:safeQuantity];
        if (existing) {
            [cart updateQuantity:safeQuantity forItem:item completion:nil];
        } else {
            BOOL didAdd = [cart addItem:item];
            if (!didAdd) {
                [PPHUD showError:kLang(@"Out of stock")];
            }
        }

        if (safeQuantity == 1) {
            [PPFunc triggerLightHaptic];
        } else {
            [PPFunc triggerMediumHaptic];
        }
    }

    [self updateCartQuantityBadge];

    NSLog(@"[Quantity] Quantity %ld", (long)safeQuantity);

        // ✅ NOTIFY controllers to update badge
        [[NSNotificationCenter defaultCenter]
            postNotificationName:kCartUpdatedNotification
                          object:nil];

}




- (void)updateCartQuantityBadge
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateCartQuantityBadge];
        });
        return;
    }

    NSInteger count = [CartManager.sharedManager totalItemsCount];
    count = MAX(count, 0);
    [self refreshNavigationRightItemsForCartCount:count];
    [self pp_applyHomeCartBadgeCount:count animated:YES];
    [self.homeCartItem.customView setNeedsLayout];
    [self.homeCartItem.customView layoutIfNeeded];
    [self.navigationController.navigationBar setNeedsLayout];
    [self.navigationController.navigationBar layoutIfNeeded];
    NSLog(@"[CartBadge] Updated count=%ld", (long)count);
}


-(void)PPUniversalCell_tapShare:(PPUniversalCellViewModel *)universalModel
{
    if (!PPIsUserLoggedIn) { [UserManager showPromptOnTopController]; return; }
    if (![universalModel.ModelObject isKindOfClass:[PetAd class]]) {
        NSLog(@"[Home][Share] Ignored share for unsupported model class");
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [PPAdSharingHelper sharePetAd:(PetAd *)universalModel.ModelObject fromViewController:self];
    });
}

-(void)PPUniversalCell_tapEdit:(PPUniversalCellViewModel *)universalModel
{

    NSLog(@"[AdsVC] PPUniversalCell_tapEdit");

    if(universalModel.cellSection == CellSectionAds && [universalModel.ModelObject isKindOfClass:[PetAd class]])
    {
        AddNewAd *vc = (AddNewAd *)[AddNewAd new];
        vc.mode = AdEditorModeEdit;
        vc.editingAd = (PetAd *)universalModel.ModelObject;                 // the existing PetAd you want to edit
        //vc.delegate = self;                // optional to get callbacks
         [PPHomeHelper pushViewControllerSafely:vc from:self animated:YES];
    }
    else  if(universalModel.cellSection == CellSectionAccessories && [universalModel.ModelObject isKindOfClass:[PetAccessory class]])
    {
        // Edit
        AddNewAccessory *editVC = [AddNewAccessory new];
        editVC.editingAccessory = (PetAccessory *)universalModel.ModelObject;   ;   // prefill from this model
        editVC.onFinish = ^(PetAccessory *result, BOOL isEdit) {
            // refresh list, etc.
            [AppClasses reloadThisCollectionView:self.collectionView completion:^(BOOL finished) { }];

        };
        [PPHomeHelper pushViewControllerSafely:editVC from:self animated:YES];
    }
}

-(void)PPUniversalCell_tapDelete:(PPUniversalCellViewModel *)universalModel
{
    if (!PPIsUserLoggedIn) { [UserManager showPromptOnTopController]; return; }
    NSLog(@"[AdsVC] PPUniversalCell_tapDelete");
    if(universalModel.cellSection == CellSectionAds && [universalModel.ModelObject isKindOfClass:[PetAd class]])
    {
        [GM showDeleteConfirmationFrom:self
                                 title:kLang(@"Confirm Deletion")
                               message:kLang(@"Are you sure you want to delete this item?")
                            completion:^(BOOL confirmed) {
            if (confirmed) {
                // Perform delete action
                [PetAdManager.sharedManager deletePetAd:(PetAd *)universalModel.ModelObject completion:^(NSError * _Nonnull error) {
                    [AppClasses reloadThisCollectionView:self.collectionView completion:^(BOOL finished) { }];
                }];
            }
        }];
    }


}

#pragma mark - Background

- (void)pp_applyOrderDetailsBackgroundAppearance
{
    UIColor *premiumBackground = [UIColor colorWithHexString:@"#E8EDF2"];
    UIColor *novaBackground = [UIColor colorWithRed:1.0 green:0.97 blue:0.98 alpha:1.0];
    self.view.backgroundColor = AppBageColor();// [UIColor colorNamed:@"AppBackgroundColorDarker"]; //PPBackgroundColorForIOS26() ;
    self.collectionView.backgroundColor = AppClearClr;
    [self pp_installPremiumBackgroundGlowViewsIfNeeded];
    [self pp_updatePremiumBackgroundGlowAppearance];
}

- (UIView *)pp_makePremiumBackgroundGlowView
{
    UIView *glowView = [[UIView alloc] initWithFrame:CGRectZero];
    glowView.userInteractionEnabled = NO;
    glowView.backgroundColor = UIColor.clearColor;
    glowView.clipsToBounds = NO;
    glowView.layer.masksToBounds = NO;
    glowView.layer.shadowOffset = CGSizeZero;
    return glowView;
}

- (void)pp_insertPremiumBackgroundGlowView:(UIView *)glowView
{
    if (!glowView || glowView.superview == self.view) {
        return;
    }

    if (self.collectionView.superview == self.view) {
        [self.view insertSubview:glowView belowSubview:self.collectionView];
    } else {
        [self.view addSubview:glowView];
    }
}

- (void)pp_installPremiumBackgroundGlowViewsIfNeeded
{
    if (!self.pp_premiumBackgroundGlowViewTop) {
        self.pp_premiumBackgroundGlowViewTop = [self pp_makePremiumBackgroundGlowView];
    }
    if (!self.pp_premiumBackgroundGlowViewMid) {
        self.pp_premiumBackgroundGlowViewMid = [self pp_makePremiumBackgroundGlowView];
    }
    if (!self.pp_premiumBackgroundGlowViewBottom) {
        self.pp_premiumBackgroundGlowViewBottom = [self pp_makePremiumBackgroundGlowView];
    }

    [self pp_insertPremiumBackgroundGlowView:self.pp_premiumBackgroundGlowViewTop];
    [self pp_insertPremiumBackgroundGlowView:self.pp_premiumBackgroundGlowViewMid];
    [self pp_insertPremiumBackgroundGlowView:self.pp_premiumBackgroundGlowViewBottom];

    if (self.collectionView.superview == self.view) {
        [self.view insertSubview:self.pp_premiumBackgroundGlowViewTop belowSubview:self.collectionView];
        [self.view insertSubview:self.pp_premiumBackgroundGlowViewMid belowSubview:self.collectionView];
        [self.view insertSubview:self.pp_premiumBackgroundGlowViewBottom belowSubview:self.collectionView];
    }
}

- (void)pp_applyPremiumGlowView:(UIView *)glowView
                          color:(UIColor *)color
                   surfaceAlpha:(CGFloat)surfaceAlpha
                  shadowOpacity:(CGFloat)shadowOpacity
                   shadowRadius:(CGFloat)shadowRadius
{
    if (!glowView || !color) {
        return;
    }

    glowView.alpha = 1.0;
    glowView.backgroundColor = [color colorWithAlphaComponent:surfaceAlpha];
    glowView.layer.shadowColor = AppClearClr.CGColor;
    glowView.layer.shadowOpacity = 0;
    glowView.layer.shadowRadius = 0;
}

- (void)pp_updatePremiumBackgroundGlowAppearance
{
    BOOL isDark = NO;
    if (@available(iOS 12.0, *)) {
        isDark = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    }

    UIColor *primaryColor = NewBgColor ?: AppPrimaryClr ?: UIColor.systemPinkColor;
    UIColor *secondaryColor = AppPrimaryClr ?: [primaryColor colorWithAlphaComponent:1.0];
    UIColor *ambientColor = isDark ? UIColor.whiteColor : UIColor.blackColor;

    [self pp_applyPremiumGlowView:self.pp_premiumBackgroundGlowViewTop
                            color:AppSurfColor
                     surfaceAlpha:isDark ? 0.13 : 0.075
                    shadowOpacity:isDark ? 0.16f : 0.10f
                     shadowRadius:isDark ? 82.0 : 74.0];

    [self pp_applyPremiumGlowView:self.pp_premiumBackgroundGlowViewMid
                            color:secondaryColor
                     surfaceAlpha:isDark ? 0.10 : 0.055
                    shadowOpacity:isDark ? 0.12f : 0.075f
                     shadowRadius:isDark ? 72.0 : 64.0];

    [self pp_applyPremiumGlowView:self.pp_premiumBackgroundGlowViewBottom
                            color:ambientColor
                     surfaceAlpha:isDark ? 0.05 : 0.025
                    shadowOpacity:isDark ? 0.08f : 0.045f
                     shadowRadius:isDark ? 62.0 : 54.0];
}

- (void)pp_layoutPremiumBackgroundGlowViews
{
    CGRect bounds = self.view.bounds;
    if (CGRectIsEmpty(bounds)) {
        return;
    }

    CGFloat width = CGRectGetWidth(bounds);
    CGFloat height = CGRectGetHeight(bounds);
    CGFloat safeTop = self.view.safeAreaInsets.top;

    CGFloat topSize = MIN(360.0, MAX(248.0, width * 0.74));
    CGFloat midSize = MIN(300.0, MAX(210.0, width * 0.58));
    CGFloat bottomSize = MIN(340.0, MAX(220.0, width * 0.66));

    self.pp_premiumBackgroundGlowViewTop.frame =
        CGRectMake(width - (topSize * 0.62),
                   safeTop - (topSize * 0.72),
                   topSize,
                   topSize);

    self.pp_premiumBackgroundGlowViewMid.frame =
        CGRectMake(-(midSize * 0.44),
                   MAX(112.0, height * 0.28),
                   midSize,
                   midSize);

    self.pp_premiumBackgroundGlowViewBottom.frame =
        CGRectMake(width - (bottomSize * 0.56),
                   height - (bottomSize * 0.62),
                   bottomSize,
                   bottomSize);

    NSArray<UIView *> *glowViews = @[
        self.pp_premiumBackgroundGlowViewTop,
        self.pp_premiumBackgroundGlowViewMid,
        self.pp_premiumBackgroundGlowViewBottom
    ];

    for (UIView *glowView in glowViews) {
        CGFloat radius = CGRectGetWidth(glowView.bounds) * 0.5;
        glowView.layer.cornerRadius = radius;
        glowView.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:glowView.bounds].CGPath;
    }
    _pp_premiumBackgroundGlowViewMid.alpha = 0.5;
    if (self.collectionView.superview == self.view) {
        [self.view insertSubview:self.pp_premiumBackgroundGlowViewBottom belowSubview:self.collectionView];
        [self.view insertSubview:self.pp_premiumBackgroundGlowViewMid belowSubview:self.collectionView];
        [self.view insertSubview:self.pp_premiumBackgroundGlowViewTop belowSubview:self.collectionView];
    }
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self pp_applyOrderDetailsBackgroundAppearance];
    [self pp_layoutPremiumBackgroundGlowViews];

    [self pp_updateHomeSmartSearchTitleViewWidth];
    [self pp_updateHomeLocationTitleViewWidth];

    if (![self pp_shouldDeferHomeLayoutStabilization]) {
        [self pp_stabilizeHomeCollectionLayoutIfNeeded];
    }
    [self pp_prepareVisibleHomeEntranceContentIfNeeded];
}


// MARK: - changeLanguageWithCode Delagate
- (void)changeLanguageWithCode:(int)code {
    self.currentLanguage = LanguageCode[code];
    [Language userSelectedLanguage:LanguageCode[code]];
}



-(void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];

    [self pp_applyCurrentLanguageDirectionToHomeUI];
}

- (void)viewSafeAreaInsetsDidChange
{
    [super viewSafeAreaInsetsDidChange];
    [self pp_stabilizeHomeCollectionLayoutIfNeeded];
}

- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

    __weak typeof(self) weakSelf = self;
    [coordinator animateAlongsideTransition:^(__unused id<UIViewControllerTransitionCoordinatorContext> context) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        self.lastHomeLayoutBoundsSize = CGSizeZero;
        [self pp_updateHomeSmartSearchTitleViewWidth];
        [self pp_updateHomeLocationTitleViewWidth];
        [self pp_stabilizeHomeCollectionLayoutIfNeeded];
    } completion:^(__unused id<UIViewControllerTransitionCoordinatorContext> context) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        self.lastHomeLayoutBoundsSize = CGSizeZero;
        [self pp_updateHomeSmartSearchTitleViewWidth];
        [self pp_updateHomeLocationTitleViewWidth];
        [self pp_stabilizeHomeCollectionLayoutIfNeeded];
        [self refreshHeroSectionAppearance];
    }];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self pp_refreshThemeSensitiveHomeContent];
        [self pp_forceHomeCollectionLayoutRefresh];
    }
}



@end
