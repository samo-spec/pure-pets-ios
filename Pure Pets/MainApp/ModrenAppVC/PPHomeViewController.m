

#import "MainBannerModel.h"
#import "PPChatsFunc.h"
#import "PetAdoptCollectionViewCell.h"
#import "PPUniversalCell.h"
#import "PPBannerCollectionCell.h"
#import "PPBannersCollection.h"
#import "PPBannersManager.h"
#import "PPBannerViewModel.h"
#import "PPCategoryCardCell.h"
#import "PPHomeFunc.h"
#import "PPHomeItem.h"
#import "PPHomeActionCell.h"
#import "PPHomeViewController.h"
#import "PPRootTabBarController.h"
#import "PPSaveForLaterManager.h"
#import "PPSPinnerView.h"
#import "PPSearchViewController.h"
#import "PPDataViewInput.h"
#import "PPDataViewVC.h"
#import "PPPetProfile.h"
#import "PPPetProfileEditorViewController.h"
#import "PPHomePremiumCareCell.h"
#import "PPHomeUltraPremuimPetCareCell.h"
#import "PPPetProfilesViewController.h"
#import "PPMarketplaceHeroCardStyle.h"
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
#import "PurchasedItemsViewController.h"
#import "PPOrder.h"
#import <os/signpost.h>
#import "PPUniversalCellFlags.h"
static os_log_t PPHomePerformanceLog(void) {
    static os_log_t log;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        log = os_log_create("com.purepets", "DataView");
    });
    return log;
}
#import "PPRolePermission.h"
#import "PPHomeHeroCell.h"
#import "PPModernHomeActionCell.h"
#import "PPHomeModels.h"
#import "PPHUD.h"
#import "PPCommerceFeedbackManager.h"
#import "LocationPickerViewController.h"
#import <AudioToolbox/AudioToolbox.h>
#import <CoreLocation/CoreLocation.h>
#import <FirebaseAuth/FirebaseAuth.h>
#import <FirebaseFirestore/FirebaseFirestore.h>
#import <Pure_Pets-Swift.h>
#import <SafariServices/SafariServices.h>
#import <TargetConditionals.h>
#import <objc/runtime.h>
#import <math.h>
#import <float.h>
#import "PPHomeOrderStatusCell.h"
#import "PPOrderStatusAppearance.h"
#import "PPNovaChatViewController.h"
#import "UIView+Badge.h"
#import "PPHomeLocationSheetViewController.h"
#import "PPHomeInsetLabel.h"
#import "PPHomeLocationTitleView.h"
#import "PPHomeSmartSearchTitleView.h"
#import "PPHomePresentationTokens.h"
#import "PPHomePremiumSearchCell.h"
#import "PPBackgroundView.h"
#import "PPHomeMarketplaceHeroCell.h"
#import "ProviderCompaniesListVC.h"
#import "PPHomeProviderCategoryPillCell.h"
#import "PPHomeUltraPremuimProviderCategoryPillCell.h"
#import "PPHomeProviderUnifiedCategoryCardCell.h"

// Forward declaration so PPHomePrepareProfileMenuButton can call pp_buildProfileMenuElements
@class PPHomeViewController;
@interface PPHomeViewController (PPProfileMenuForward)
- (NSArray<UIMenuElement *> *)pp_buildProfileMenuElements;
@end

extern NSString * const PPThemePreferenceDidChangeNotification;
static BOOL const PPHomeUseHeroApex = YES;
static NSString * const PPHomeLanguageDidChangeNotification = @"LanguageDidChangeNotification";
static NSString * const PPHomeConfigCacheKey = @"PPHomeConfig.cache.v1";
static NSString * const PPHomeConfigCacheSectionsKey = @"sections";
static NSString * const PPHomeConfigCacheTitleModeKey = @"titleViewMode";
static NSString * const PPHomeConfigCachePremiumCareVisibleKey = @"premiumCareVisible";
static NSString * const PPHomeConfigCacheNovaFloatingVisibleKey = @"novaFloatingVisible";
static NSString * const PPHomeConfigCacheBackgroundGlowsFadedKey = @"backgroundGlowsFaded";
static NSString * const PPHomeConfigCacheNovaUseGenkitKey = @"novaUseGenkit";
static NSString * const PPHomeConfigCacheUseLegacyBarKey = @"PPUSE_LEGACY_BAR";
static NSString * const PPHomeLastSelectedMainKindIDKey = @"PPHome.lastSelectedMainKindID.v1";
static NSInteger const PPHomeAllMainKindID = -1;
static BOOL const PPHomeTemporarilyHideLeadingProfileItem = YES;
static NSString * const PPNovaFloatingVisibilityDidChangeNotification = @"PPNovaFloatingVisibilityDidChangeNotification";
static NSString * const PPNovaFloatingVisibilityValueKey = @"visible";
static NSString * const PPNovaFloatingVisibleDefaultsKey = @"pp_nova_floating_visible";
static CGFloat const PPHomeOrthogonalHorizontalIntentRatio = 1.15;
static char PPHomeOrthogonalPanGateAssociationKey;
static char PPHomeOrthogonalPanGateMarkerKey;
static NSString * const PPHomeCartButtonSurfaceLayerName = @"pp.home.cart.surface";
static NSString * const PPHomeSaveForLaterUpdatedNotificationName = @"PPSaveForLaterUpdatedNotification";
static CGFloat const PPHomeSmartSearchCartButtonSide = 44.0;
static CGFloat const PPHomeSmartSearchCartButtonSpacing = 8.0;
static NSTimeInterval const PPHomeSmartSearchCartRevealDuration = 0.42;

static UISemanticContentAttribute PPHomeCurrentSemanticAttribute(void)
{
    return [Language semanticAttributeForCurrentLanguage];
}

static NSTextAlignment PPHomeCurrentTextAlignment(void)
{
    return [Language alignmentForCurrentLanguage];
}

static UIColor *PPHomeCartButtonAccentColor(void)
{
    return AppPrimaryTextClr ?: [GM appPrimaryColor] ?: UIColor.systemPinkColor;
}

static UIColor *PPHomeCartButtonSurfaceColor(void)
{
    UIColor *surface = AppBackgroundClrLigter ?: UIColor.whiteColor;
    return [surface colorWithAlphaComponent:0.94];
}

static UIColor *PPHomeCartButtonLiquidBorderColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            CGFloat alpha = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.34 : 0.88;
            return [UIColor.whiteColor colorWithAlphaComponent:alpha];
        }];
    }
    return [UIColor.whiteColor colorWithAlphaComponent:0.88];
}

static CAShapeLayer *PPHomeCartButtonSurfaceLayer(UIButton *button)
{
    for (CALayer *layer in button.layer.sublayers.copy) {
        if ([layer.name isEqualToString:PPHomeCartButtonSurfaceLayerName] &&
            [layer isKindOfClass:CAShapeLayer.class]) {
            return (CAShapeLayer *)layer;
        }
    }

    CAShapeLayer *surfaceLayer = [CAShapeLayer layer];
    surfaceLayer.name = PPHomeCartButtonSurfaceLayerName;
    surfaceLayer.contentsScale = UIScreen.mainScreen.scale;
    surfaceLayer.allowsEdgeAntialiasing = YES;
    [button.layer insertSublayer:surfaceLayer atIndex:0];
    return surfaceLayer;
}

static CGAffineTransform PPHomeSmartSearchCartHiddenTransform(void)
{
    UIUserInterfaceLayoutDirection direction =
        [UIView userInterfaceLayoutDirectionForSemanticContentAttribute:PPHomeCurrentSemanticAttribute()];
    CGFloat outwardX = (direction == UIUserInterfaceLayoutDirectionRightToLeft) ? -7.0 : 7.0;
    return CGAffineTransformScale(CGAffineTransformMakeTranslation(outwardX, 0.0), 0.82, 0.82);
}

static NSArray<UIBarButtonItem *> *PPHomeBarButtonItems(UIBarButtonItem * _Nullable item)
{
    return item ? @[item] : @[];
}

static void PPHomePrepareProfileMenuButton(UIButton * _Nullable button, PPHomeViewController * _Nullable host)
{
    if (!button) { return; }
    __weak PPHomeViewController *weakHost = host;
    UIMenu *menu = [UIMenu menuWithTitle:@"" children:@[
        [UIDeferredMenuElement elementWithUncachedProvider:^(void (^completion)(NSArray<UIMenuElement *> *)) {
            PPHomeViewController *strongHost = weakHost;
            completion(strongHost ? [strongHost pp_buildProfileMenuElements] : @[]);
        }]
    ]];
    button.menu = menu;
    button.showsMenuAsPrimaryAction = YES;
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

        NSString *hex = [((NSString *)color) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
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

static void PPHomeInvokeVoidSelectorIfAvailable(id target, SEL selector)
{
    if (!target || !selector || ![target respondsToSelector:selector]) {
        return;
    }

    IMP implementation = [target methodForSelector:selector];
    if (!implementation) {
        return;
    }

    void (*sendMessage)(id, SEL) = (void (*)(id, SEL))implementation;
    sendMessage(target, selector);
}

@interface PPHomePetProfileCardCell : UICollectionViewCell
+ (NSString *)reuseIdentifier;
@property (nonatomic, copy, nullable) void (^onToggleExpanded)(BOOL expanded);
- (void)configureWithDefaultPet:(nullable PPPetProfile *)defaultPet
                       petCount:(NSInteger)petCount
                      isLoading:(BOOL)isLoading
                       expanded:(BOOL)expanded
             backgroundGlowsFaded:(BOOL)glowsFaded;
@end

@implementation PPHomePetProfileCardCell {
    UIView *_cardView;
    UIView *_accentRailView;
    UIView *_avatarShellView;
    UIImageView *_avatarImageView;
    LOTAnimationView *_avatarAnimationView;
    UIActivityIndicatorView *_loadingIndicator;
    PPInsetLabel *_eyebrowLabel;
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
    UILabel *_collapsedSummaryLabel;
    UIView *_detailsView;
    UIView *_detailsDividerView;
    UIStackView *_metaStackView;
    UIView *_metaPrimaryView;
    UIImageView *_metaPrimaryIconView;
    PPHomeInsetLabel *_metaPrimaryLabel;
    UIView *_metaSecondaryView;
    UIImageView *_metaSecondaryIconView;
    PPHomeInsetLabel *_metaSecondaryLabel;
    UIView *_ctaView;
    UILabel *_ctaLabel;
    UIImageView *_ctaImageView;
    UIButton *_expandButton;
    UIImageView *_expandImageView;
    PPBackgroundView *_heroGlassBackground;
    NSLayoutConstraint *_detailsHeightConstraint;
    BOOL _expanded;
    BOOL _backgroundGlowsFaded;
    BOOL _avatarAnimationLoaded;
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
    _backgroundGlowsFaded = backgroundGlowsFaded;

    UIView *cardView = [[UIView alloc] init];
    cardView.translatesAutoresizingMaskIntoConstraints = NO;
    cardView.layer.cornerRadius = 24.0;
    cardView.layer.borderWidth = 0.0;
    cardView.clipsToBounds = NO;
    [cardView pp_setShadowColor:UIColor.clearColor];
    cardView.layer.shadowOpacity = 0.0f;
    if (@available(iOS 13.0, *)) {
        cardView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.contentView addSubview:cardView];
    _cardView = cardView;

    PPBackgroundView *glass = [PPBackgroundView new];
    glass.translatesAutoresizingMaskIntoConstraints = NO;
    glass.accentStyle = PPHeroGlassAccentStyleFullScreen;
    glass.cornerGlowOpacityMultiplier = 0.48;
    glass.glowDirection = PPIsRL ? PPHeroGlowDirectionLeftDirect : PPHeroGlowDirectionRightDirection;
    glass.PPHeroApexUseShimmer = NO;
    [cardView insertSubview:glass atIndex:0];
    _heroGlassBackground = glass;

    [NSLayoutConstraint activateConstraints:@[
        [glass.topAnchor constraintEqualToAnchor:cardView.topAnchor],
        [glass.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor],
        [glass.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor],
        [glass.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor]
    ]];

    UIView *accentRailView = [[UIView alloc] init];
    accentRailView.translatesAutoresizingMaskIntoConstraints = NO;
    accentRailView.userInteractionEnabled = NO;
    accentRailView.layer.cornerRadius = 1.5;
    accentRailView.layer.masksToBounds = YES;
    [cardView addSubview:accentRailView];
    _accentRailView = accentRailView;

    UIView *avatarShellView = [[UIView alloc] init];
    avatarShellView.translatesAutoresizingMaskIntoConstraints = NO;
    avatarShellView.backgroundColor = UIColor.clearColor;
    avatarShellView.layer.cornerRadius = 32.0;
    avatarShellView.layer.borderWidth = 0.0;
    [avatarShellView pp_setShadowColor:UIColor.clearColor];
    avatarShellView.layer.shadowOpacity = 0.0f;
    if (@available(iOS 13.0, *)) {
        avatarShellView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [cardView addSubview:avatarShellView];
    _avatarShellView = avatarShellView;

    UIImageView *avatarImageView = [[UIImageView alloc] init];
    avatarImageView.translatesAutoresizingMaskIntoConstraints = NO;
    avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    avatarImageView.clipsToBounds = YES;
    avatarImageView.layer.cornerRadius = 27.0;
    avatarImageView.layer.borderWidth = 0.0;
    if (@available(iOS 13.0, *)) {
        avatarImageView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    avatarImageView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
    [avatarShellView addSubview:avatarImageView];
    _avatarImageView = avatarImageView;

    LOTAnimationView *avatarAnimationView = [[LOTAnimationView alloc] init];
    avatarAnimationView.translatesAutoresizingMaskIntoConstraints = NO;
    avatarAnimationView.userInteractionEnabled = NO;
    avatarAnimationView.isAccessibilityElement = NO;
    avatarAnimationView.accessibilityElementsHidden = YES;
    avatarAnimationView.contentMode = UIViewContentModeScaleAspectFit;
    avatarAnimationView.backgroundColor = UIColor.clearColor;
    avatarAnimationView.loopAnimation = YES;
    avatarAnimationView.animationSpeed = 0.7;
    avatarAnimationView.hidden = YES;
    avatarAnimationView.alpha = 0.0;
    [avatarShellView addSubview:avatarAnimationView];
    _avatarAnimationView = avatarAnimationView;

    UIActivityIndicatorView *loadingIndicator = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    loadingIndicator.hidesWhenStopped = YES;
    [avatarShellView addSubview:loadingIndicator];
    _loadingIndicator = loadingIndicator;

    PPInsetLabel *eyebrowLabel = [[PPInsetLabel alloc] init];
    eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowLabel.font = [GM boldFontWithSize:10.5] ?: [UIFont systemFontOfSize:10.5 weight:UIFontWeightSemibold];
    eyebrowLabel.layer.cornerRadius = 11.0;
    eyebrowLabel.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        eyebrowLabel.layer.cornerCurve = kCACornerCurveContinuous;
    }
    eyebrowLabel.numberOfLines = 1;
    eyebrowLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    eyebrowLabel.textInsets = UIEdgeInsetsMake(3.0, 10.0, 3.0, 10.0);
    eyebrowLabel.textAlignment = PPHomeCurrentTextAlignment();
    [cardView addSubview:eyebrowLabel];
    _eyebrowLabel = eyebrowLabel;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:22.0] ?: [UIFont systemFontOfSize:22.0 weight:UIFontWeightBold];
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
    subtitleLabel.numberOfLines = 2;
    subtitleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    subtitleLabel.textAlignment = PPHomeCurrentTextAlignment();
    [cardView addSubview:subtitleLabel];
    _subtitleLabel = subtitleLabel;

    UILabel *collapsedSummaryLabel = [[UILabel alloc] init];
    collapsedSummaryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    collapsedSummaryLabel.font = [GM MidFontWithSize:12.5] ?: [UIFont systemFontOfSize:12.5 weight:UIFontWeightSemibold];
    collapsedSummaryLabel.numberOfLines = 1;
    collapsedSummaryLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    collapsedSummaryLabel.textAlignment = PPHomeCurrentTextAlignment();
    collapsedSummaryLabel.alpha = 0.0;
    [cardView addSubview:collapsedSummaryLabel];
    _collapsedSummaryLabel = collapsedSummaryLabel;

    UIView *detailsView = [[UIView alloc] init];
    detailsView.translatesAutoresizingMaskIntoConstraints = NO;
    detailsView.clipsToBounds = YES;
    detailsView.userInteractionEnabled = NO;
    [cardView addSubview:detailsView];
    _detailsView = detailsView;

    UIView *detailsDividerView = [[UIView alloc] init];
    detailsDividerView.translatesAutoresizingMaskIntoConstraints = NO;
    detailsDividerView.userInteractionEnabled = NO;
    [detailsView addSubview:detailsDividerView];
    _detailsDividerView = detailsDividerView;

    UIStackView *metaStackView = [[UIStackView alloc] init];
    metaStackView.translatesAutoresizingMaskIntoConstraints = NO;
    metaStackView.axis = UILayoutConstraintAxisHorizontal;
    metaStackView.alignment = UIStackViewAlignmentFill;
    metaStackView.spacing = 10.0;
    metaStackView.distribution = UIStackViewDistributionFillEqually;
    [detailsView addSubview:metaStackView];
    _metaStackView = metaStackView;

    UIView *metaPrimaryView = [[UIView alloc] init];
    metaPrimaryView.translatesAutoresizingMaskIntoConstraints = NO;
    [metaStackView addArrangedSubview:metaPrimaryView];
    _metaPrimaryView = metaPrimaryView;

    UIImageView *metaPrimaryIconView = [[UIImageView alloc] init];
    metaPrimaryIconView.translatesAutoresizingMaskIntoConstraints = NO;
    metaPrimaryIconView.contentMode = UIViewContentModeScaleAspectFit;
    [metaPrimaryView addSubview:metaPrimaryIconView];
    _metaPrimaryIconView = metaPrimaryIconView;

    PPHomeInsetLabel *metaPrimaryLabel = [[PPHomeInsetLabel alloc] init];
    metaPrimaryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    metaPrimaryLabel.font = [GM MidFontWithSize:11.5] ?: [UIFont systemFontOfSize:11.5 weight:UIFontWeightSemibold];
    metaPrimaryLabel.backgroundColor = UIColor.clearColor;
    metaPrimaryLabel.contentInsets = UIEdgeInsetsZero;
    metaPrimaryLabel.textAlignment = PPHomeCurrentTextAlignment();
    metaPrimaryLabel.numberOfLines = 1;
    metaPrimaryLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    metaPrimaryLabel.adjustsFontSizeToFitWidth = YES;
    metaPrimaryLabel.minimumScaleFactor = 0.82;
    [metaPrimaryView addSubview:metaPrimaryLabel];
    _metaPrimaryLabel = metaPrimaryLabel;

    UIView *metaSecondaryView = [[UIView alloc] init];
    metaSecondaryView.translatesAutoresizingMaskIntoConstraints = NO;
    [metaStackView addArrangedSubview:metaSecondaryView];
    _metaSecondaryView = metaSecondaryView;

    UIImageView *metaSecondaryIconView = [[UIImageView alloc] init];
    metaSecondaryIconView.translatesAutoresizingMaskIntoConstraints = NO;
    metaSecondaryIconView.contentMode = UIViewContentModeScaleAspectFit;
    [metaSecondaryView addSubview:metaSecondaryIconView];
    _metaSecondaryIconView = metaSecondaryIconView;

    PPHomeInsetLabel *metaSecondaryLabel = [[PPHomeInsetLabel alloc] init];
    metaSecondaryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    metaSecondaryLabel.font = [GM MidFontWithSize:11.5] ?: [UIFont systemFontOfSize:11.5 weight:UIFontWeightSemibold];
    metaSecondaryLabel.backgroundColor = UIColor.clearColor;
    metaSecondaryLabel.contentInsets = UIEdgeInsetsZero;
    metaSecondaryLabel.textAlignment = PPHomeCurrentTextAlignment();
    metaSecondaryLabel.numberOfLines = 1;
    metaSecondaryLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    metaSecondaryLabel.adjustsFontSizeToFitWidth = YES;
    metaSecondaryLabel.minimumScaleFactor = 0.82;
    [metaSecondaryView addSubview:metaSecondaryLabel];
    _metaSecondaryLabel = metaSecondaryLabel;

    UIView *ctaView = [[UIView alloc] init];
    ctaView.translatesAutoresizingMaskIntoConstraints = NO;
    ctaView.layer.cornerRadius = 14.0;
    ctaView.layer.borderWidth = 0.0;
    if (@available(iOS 13.0, *)) {
        ctaView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [detailsView addSubview:ctaView];
    _ctaView = ctaView;

    UILabel *ctaLabel = [[UILabel alloc] init];
    ctaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    ctaLabel.font = [GM boldFontWithSize:13.5] ?: [UIFont systemFontOfSize:13.5 weight:UIFontWeightSemibold];
    ctaLabel.textAlignment = PPHomeCurrentTextAlignment();
    ctaLabel.numberOfLines = 1;
    ctaLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    ctaLabel.adjustsFontSizeToFitWidth = YES;
    ctaLabel.minimumScaleFactor = 0.82;
    [ctaView addSubview:ctaLabel];
    _ctaLabel = ctaLabel;

    UIImageView *ctaImageView = [[UIImageView alloc] init];
    ctaImageView.translatesAutoresizingMaskIntoConstraints = NO;
    ctaImageView.contentMode = UIViewContentModeScaleAspectFit;
    [ctaView addSubview:ctaImageView];
    _ctaImageView = ctaImageView;

    UIButton *expandButton = [UIButton buttonWithType:UIButtonTypeCustom];
    expandButton.translatesAutoresizingMaskIntoConstraints = NO;
    expandButton.layer.cornerRadius = 21.0;
    expandButton.layer.borderWidth = 0.0;
    expandButton.accessibilityTraits = UIAccessibilityTraitButton;
    expandButton.isAccessibilityElement = NO;
    if (@available(iOS 13.0, *)) {
        expandButton.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [expandButton addTarget:self action:@selector(pp_handleExpandButtonTap) forControlEvents:UIControlEventTouchUpInside];
    [expandButton addTarget:self action:@selector(pp_handleExpandButtonTouchDown) forControlEvents:UIControlEventTouchDown];
    [expandButton addTarget:self action:@selector(pp_handleExpandButtonTouchUp) forControlEvents:UIControlEventTouchUpInside];
    [expandButton addTarget:self action:@selector(pp_handleExpandButtonTouchUp) forControlEvents:UIControlEventTouchUpOutside];
    [expandButton addTarget:self action:@selector(pp_handleExpandButtonTouchUp) forControlEvents:UIControlEventTouchCancel];
    [cardView addSubview:expandButton];
    _expandButton = expandButton;

    UIImageView *expandImageView = [[UIImageView alloc] init];
    expandImageView.translatesAutoresizingMaskIntoConstraints = NO;
    expandImageView.contentMode = UIViewContentModeScaleAspectFit;
    expandImageView.userInteractionEnabled = NO;
    [expandButton addSubview:expandImageView];
    _expandImageView = expandImageView;

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

        [accentRailView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:22.0],
        [accentRailView.topAnchor constraintEqualToAnchor:cardView.topAnchor],
        [accentRailView.widthAnchor constraintEqualToConstant:54.0],
        [accentRailView.heightAnchor constraintEqualToConstant:3.0],

        [avatarShellView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:20.0],
        [avatarShellView.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:22.0],
        [avatarShellView.widthAnchor constraintEqualToConstant:108.0],
        [avatarShellView.heightAnchor constraintEqualToConstant:108.0],

        [avatarImageView.centerXAnchor constraintEqualToAnchor:avatarShellView.centerXAnchor],
        [avatarImageView.centerYAnchor constraintEqualToAnchor:avatarShellView.centerYAnchor],
        [avatarImageView.widthAnchor constraintEqualToConstant:84.0],
        [avatarImageView.heightAnchor constraintEqualToConstant:84.0],

        [avatarAnimationView.centerXAnchor constraintEqualToAnchor:avatarShellView.centerXAnchor],
        [avatarAnimationView.centerYAnchor constraintEqualToAnchor:avatarShellView.centerYAnchor],
        [avatarAnimationView.widthAnchor constraintEqualToConstant:88.0],
        [avatarAnimationView.heightAnchor constraintEqualToConstant:88.0],

        [loadingIndicator.centerXAnchor constraintEqualToAnchor:avatarShellView.centerXAnchor],
        [loadingIndicator.centerYAnchor constraintEqualToAnchor:avatarShellView.centerYAnchor],

        [eyebrowLabel.leadingAnchor constraintEqualToAnchor:avatarShellView.trailingAnchor constant:16.0],
        [eyebrowLabel.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:23.0],
        [eyebrowLabel.heightAnchor constraintGreaterThanOrEqualToConstant:24.0],
        [eyebrowLabel.trailingAnchor constraintLessThanOrEqualToAnchor:cardView.trailingAnchor constant:-20.0],

        [titleLabel.leadingAnchor constraintEqualToAnchor:eyebrowLabel.leadingAnchor],
        [titleLabel.topAnchor constraintEqualToAnchor:eyebrowLabel.bottomAnchor constant:8.0],
        [titleLabel.heightAnchor constraintGreaterThanOrEqualToConstant:27.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-20.0],

        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6.0],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],

        [collapsedSummaryLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [collapsedSummaryLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [collapsedSummaryLabel.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-22.0],

        [expandButton.trailingAnchor constraintEqualToAnchor:avatarShellView.trailingAnchor constant:4.0],
        [expandButton.bottomAnchor constraintEqualToAnchor:avatarShellView.bottomAnchor constant:4.0],
        [expandButton.widthAnchor constraintEqualToConstant:42.0],
        [expandButton.heightAnchor constraintEqualToConstant:42.0],

        [expandImageView.centerXAnchor constraintEqualToAnchor:expandButton.centerXAnchor],
        [expandImageView.centerYAnchor constraintEqualToAnchor:expandButton.centerYAnchor],
        [expandImageView.widthAnchor constraintEqualToConstant:15.0],
        [expandImageView.heightAnchor constraintEqualToConstant:15.0],

        [detailsView.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [detailsView.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [detailsView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-18.0],

        [detailsDividerView.leadingAnchor constraintEqualToAnchor:detailsView.leadingAnchor],
        [detailsDividerView.trailingAnchor constraintEqualToAnchor:detailsView.trailingAnchor],
        [detailsDividerView.topAnchor constraintEqualToAnchor:detailsView.topAnchor],
        [detailsDividerView.heightAnchor constraintEqualToConstant:1.0],

        [metaStackView.leadingAnchor constraintEqualToAnchor:detailsView.leadingAnchor],
        [metaStackView.trailingAnchor constraintEqualToAnchor:detailsView.trailingAnchor],
        [metaStackView.topAnchor constraintEqualToAnchor:detailsDividerView.bottomAnchor constant:10.0],
        [metaStackView.heightAnchor constraintEqualToConstant:24.0],

        [metaPrimaryIconView.leadingAnchor constraintEqualToAnchor:metaPrimaryView.leadingAnchor],
        [metaPrimaryIconView.centerYAnchor constraintEqualToAnchor:metaPrimaryView.centerYAnchor],
        [metaPrimaryIconView.widthAnchor constraintEqualToConstant:15.0],
        [metaPrimaryIconView.heightAnchor constraintEqualToConstant:15.0],
        [metaPrimaryLabel.leadingAnchor constraintEqualToAnchor:metaPrimaryIconView.trailingAnchor constant:6.0],
        [metaPrimaryLabel.trailingAnchor constraintEqualToAnchor:metaPrimaryView.trailingAnchor],
        [metaPrimaryLabel.centerYAnchor constraintEqualToAnchor:metaPrimaryView.centerYAnchor],

        [metaSecondaryIconView.leadingAnchor constraintEqualToAnchor:metaSecondaryView.leadingAnchor],
        [metaSecondaryIconView.centerYAnchor constraintEqualToAnchor:metaSecondaryView.centerYAnchor],
        [metaSecondaryIconView.widthAnchor constraintEqualToConstant:15.0],
        [metaSecondaryIconView.heightAnchor constraintEqualToConstant:15.0],
        [metaSecondaryLabel.leadingAnchor constraintEqualToAnchor:metaSecondaryIconView.trailingAnchor constant:6.0],
        [metaSecondaryLabel.trailingAnchor constraintEqualToAnchor:metaSecondaryView.trailingAnchor],
        [metaSecondaryLabel.centerYAnchor constraintEqualToAnchor:metaSecondaryView.centerYAnchor],

        [ctaView.leadingAnchor constraintEqualToAnchor:detailsView.leadingAnchor],
        [ctaView.trailingAnchor constraintEqualToAnchor:detailsView.trailingAnchor],
        [ctaView.bottomAnchor constraintEqualToAnchor:detailsView.bottomAnchor],
        [ctaView.heightAnchor constraintEqualToConstant:42.0],

        [ctaLabel.leadingAnchor constraintEqualToAnchor:ctaView.leadingAnchor constant:14.0],
        [ctaLabel.centerYAnchor constraintEqualToAnchor:ctaView.centerYAnchor],
        [ctaLabel.trailingAnchor constraintLessThanOrEqualToAnchor:ctaImageView.leadingAnchor constant:-10.0],

        [ctaImageView.trailingAnchor constraintEqualToAnchor:ctaView.trailingAnchor constant:-14.0],
        [ctaImageView.centerYAnchor constraintEqualToAnchor:ctaView.centerYAnchor],
        [ctaImageView.widthAnchor constraintEqualToConstant:13.0],
        [ctaImageView.heightAnchor constraintEqualToConstant:13.0],
    ]];

    NSLayoutConstraint *collapsedSummaryTopConstraint =
        [collapsedSummaryLabel.topAnchor constraintGreaterThanOrEqualToAnchor:subtitleLabel.bottomAnchor constant:8.0];
    collapsedSummaryTopConstraint.priority = UILayoutPriorityDefaultHigh;
    collapsedSummaryTopConstraint.active = YES;

    NSLayoutConstraint *detailsTopConstraint =
        [detailsView.topAnchor constraintGreaterThanOrEqualToAnchor:subtitleLabel.bottomAnchor constant:12.0];
    detailsTopConstraint.priority = UILayoutPriorityDefaultHigh;
    detailsTopConstraint.active = YES;

    _detailsHeightConstraint = [detailsView.heightAnchor constraintEqualToConstant:96.0];
    _detailsHeightConstraint.active = YES;

    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [[PPImageLoaderManager shared] cancelImageLoadForImageView:_avatarImageView];
    _avatarImageView.image = nil;
    [_avatarAnimationView stop];
    _avatarAnimationView.hidden = YES;
    _avatarAnimationView.alpha = 0.0;

    // Reset visual state to prevent stale gradient/text on cell reuse
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [_heroGlassBackground reapplyPalette];
    [CATransaction commit];

    [_loadingIndicator stopAnimating];
    _eyebrowLabel.text = nil;
    _titleLabel.text = nil;
    _subtitleLabel.text = nil;
    _metaPrimaryLabel.text = nil;
    _metaSecondaryLabel.text = nil;
    _ctaLabel.text = nil;
    _collapsedSummaryLabel.text = nil;
    _detailsView.hidden = NO;
    _detailsView.alpha = 1.0;
    _detailsView.transform = CGAffineTransformIdentity;
    _collapsedSummaryLabel.alpha = 0.0;
    _collapsedSummaryLabel.transform = CGAffineTransformIdentity;
    _expandImageView.transform = CGAffineTransformIdentity;
    _avatarShellView.transform = CGAffineTransformIdentity;
    _detailsHeightConstraint.constant = 96.0;
    [_avatarShellView.layer removeAllAnimations];
    // Sheen/Glow handled by PPBackgroundView
    self.onToggleExpanded = nil;
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
    _cardView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:cardBounds
                                                            cornerRadius:_cardView.layer.cornerRadius].CGPath;

    [CATransaction commit];

    _eyebrowLabel.layer.cornerRadius = CGRectGetHeight(_eyebrowLabel.bounds) * 0.5;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self pp_refreshCardGeometry];
}

- (void)pp_loadAvatarEmptyAnimationIfNeeded
{
    if (_avatarAnimationLoaded) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    [AppClasses setAnimationNamed:@"petprofile"
                           ToView:_avatarAnimationView
                        withSpeed:0.7
                       completion:^(BOOL success) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !success) {
            return;
        }
        self->_avatarAnimationLoaded = YES;
        if (!self->_avatarAnimationView.hidden && !self->_avatarAnimationView.isAnimationPlaying) {
            [self->_avatarAnimationView play];
        }
    }];
}

- (void)pp_setAvatarEmptyAnimationVisible:(BOOL)visible
{
    if (visible) {
        [self pp_loadAvatarEmptyAnimationIfNeeded];
        _avatarAnimationView.hidden = NO;
        _avatarAnimationView.alpha = 1.0;
        _avatarImageView.hidden = YES;
        if (_avatarAnimationLoaded && !_avatarAnimationView.isAnimationPlaying) {
            [_avatarAnimationView play];
        }
        return;
    }

    [_avatarAnimationView stop];
    _avatarAnimationView.hidden = YES;
    _avatarAnimationView.alpha = 0.0;
    _avatarImageView.hidden = NO;
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

    PPMarketplaceHeroCardApplySurfaceChrome(_cardView, 24.0, self.traitCollection);
    _cardView.layer.borderWidth = 0.0;
    _cardView.layer.shadowOpacity = isDark ? 0.22 : 0.07;
    _cardView.layer.shadowRadius = isDark ? 18.0 : 20.0;
    _cardView.layer.shadowOffset = CGSizeMake(0.0, isDark ? 8.0 : 10.0);
    [_heroGlassBackground reapplyPalette];

    _avatarShellView.layer.borderWidth = 0.0;
    [_avatarImageView pp_setBorderColor:UIColor.clearColor];
    [_ctaView pp_setBorderColor:UIColor.clearColor];

    _expandButton.layer.borderWidth = 0.0;
    _detailsDividerView.backgroundColor = isDark
        ? [UIColor colorWithWhite:1.0 alpha:0.10]
        : [UIColor colorWithWhite:0.0 alpha:0.07];
}

- (void)configureWithDefaultPet:(nullable PPPetProfile *)defaultPet
                       petCount:(NSInteger)petCount
                      isLoading:(BOOL)isLoading
                       expanded:(BOOL)expanded
             backgroundGlowsFaded:(BOOL)glowsFaded
{
    _backgroundGlowsFaded = glowsFaded;
    [self pp_refreshThemeColors];

    self.semanticContentAttribute = PPHomeCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPHomeCurrentSemanticAttribute();
    _cardView.semanticContentAttribute = PPHomeCurrentSemanticAttribute();
    _metaStackView.semanticContentAttribute = PPHomeCurrentSemanticAttribute();
    _ctaView.semanticContentAttribute = PPHomeCurrentSemanticAttribute();
    _expandButton.semanticContentAttribute = PPHomeCurrentSemanticAttribute();
    _eyebrowLabel.textAlignment = PPHomeCurrentTextAlignment();
    _titleLabel.textAlignment = PPHomeCurrentTextAlignment();
    _subtitleLabel.textAlignment = PPHomeCurrentTextAlignment();
    _collapsedSummaryLabel.textAlignment = PPHomeCurrentTextAlignment();
    _metaPrimaryLabel.textAlignment = PPHomeCurrentTextAlignment();
    _metaSecondaryLabel.textAlignment = PPHomeCurrentTextAlignment();
    _ctaLabel.textAlignment = PPHomeCurrentTextAlignment();

    BOOL hasProfiles = (petCount > 0);
    BOOL isDark = NO;
    if (@available(iOS 13.0, *)) {
        isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    UIColor *textColor = isDark
        ? UIColor.whiteColor
        : UIColor.labelColor;
    UIColor *secondaryTextColor = isDark
        ? [UIColor colorWithWhite:1.0 alpha:0.68]
        : [UIColor colorWithWhite:0.0 alpha:0.58];
    UIColor *accentColor = AppPrimaryClr ?: UIColor.systemPinkColor;
  /*
   UIColor *baseSurfaceColor = AppSurfColor ?: (isDark
       ? [UIColor colorWithRed:0.16 green:0.17 blue:0.19 alpha:1.0]
       : UIColor.systemBackgroundColor);
   UIColor *secondarySurfaceColor = AppSurfSecColor ?: (isDark
       ? [UIColor colorWithRed:0.20 green:0.21 blue:0.23 alpha:1.0]
       : UIColor.secondarySystemBackgroundColor);
   */
    NSString *forwardSymbol = Language.isRTL ? @"arrow.left" : @"arrow.right";
    UIImage *avatarPlaceholder = nil;
    NSString *primaryIconName = @"cross.case.fill";
    NSString *secondaryIconName = @"pawprint.fill";
    BOOL showsEmptyProfileAnimation = NO;

    if (isLoading) {
        accentColor = AppPrimaryClr ?: [UIColor colorNamed:@"AppPrimaryColor"] ?: UIColor.systemPinkColor;
        _eyebrowLabel.text = kLang(@"please_wait") ?: @"Loading";
        _titleLabel.text = kLang(@"pet_profiles_title") ?: @"Pet Profiles";
        _subtitleLabel.text = kLang(@"pet_profiles_loading_home_subtitle") ?: @"Syncing your companion card and care details for the home feed.";
        _metaPrimaryLabel.text = kLang(@"home_pet_profile_meta_syncing") ?: @"Live sync";
        _metaSecondaryLabel.text = kLang(@"home_pet_profile_meta_health") ?: @"Health details";
        _ctaLabel.text = kLang(@"please_wait") ?: @"Please wait";
        primaryIconName = @"arrow.triangle.2.circlepath";
        secondaryIconName = @"heart.text.square.fill";
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
            ? (kLang(@"Default") ?: @"Default")
            : (kLang(@"pet_profiles_title") ?: @"Pet Profiles");
        _titleLabel.text = defaultPet.name.length > 0
            ? defaultPet.name
            : (kLang(@"pet_name_placeholder") ?: @"Your pet");

        NSString *headline = summaryParts.count > 0
            ? [summaryParts componentsJoinedByString:@" · "]
            : (kLang(@"pet_profiles_home_ready") ?: @"Care details ready on home");
        _subtitleLabel.text = headline;
        _metaPrimaryLabel.text = [NSString stringWithFormat:@"%ld %@",
                                  (long)defaultPet.vaccinations.count,
                                  (kLang(@"pet_vaccines_short") ?: @"vaccines")];
        _metaSecondaryLabel.text = [NSString stringWithFormat:@"%ld %@",
                                    (long)petCount,
                                    (petCount == 1
                                     ? (kLang(@"pet_profile_single") ?: @"saved profile")
                                     : (kLang(@"pet_profiles_title") ?: @"saved profiles"))];
        _ctaLabel.text = kLang(@"home_pet_profile_open_cta") ?: @"Open pet profile";
        avatarPlaceholder = defaultPet.imageURL.length > 0
            ? [[UIImage systemImageNamed:@"pawprint.circle.fill"
                       withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:28.0
                                                                                          weight:UIImageSymbolWeightSemibold]]
                imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
            : [PPModernAvatarRenderer avatarImageForName:(defaultPet.name ?: @"") size:84.0];
        _avatarImageView.tintColor = UIColor.whiteColor;
    } else if (hasProfiles) {
        accentColor = AppPrimaryClr ?: [UIColor colorNamed:@"AppPrimaryColor"] ?: UIColor.systemPinkColor;
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
        primaryIconName = @"pawprint.fill";
        secondaryIconName = @"pin.fill";
        avatarPlaceholder = [[UIImage systemImageNamed:@"pawprint.circle.fill"
                                     withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:30.0
                                                                                                    weight:UIImageSymbolWeightSemibold]]
                              imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        _avatarImageView.tintColor = [PPPetsUIBrandColor() colorWithAlphaComponent:0.88];
    } else {
        accentColor = AppPrimaryClr ?: [UIColor colorNamed:@"AppPrimaryColor"] ?: UIColor.systemPinkColor;
        _eyebrowLabel.text = kLang(@"pet_profiles_title") ?: @"Pet Profiles";
        _titleLabel.text = kLang(@"home_pet_profile_empty_compact_title") ?: @"Create your pet profile";
        _subtitleLabel.text = kLang(@"home_pet_profile_empty_compact_subtitle") ?: @"Keep care details, vaccines, and reminders together.";
        _metaPrimaryLabel.text = kLang(@"home_pet_profile_meta_vaccines") ?: @"Vaccines";
        _metaSecondaryLabel.text = kLang(@"home_pet_profile_meta_reminders") ?: @"Reminders";
        _ctaLabel.text = kLang(@"pet_profiles_add_first") ?: @"Add your first pet";
        primaryIconName = @"plus.circle.fill";
        secondaryIconName = @"bell.badge.fill";
        avatarPlaceholder = [[UIImage systemImageNamed:@"pawprint.circle.fill"
                                     withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:22.0
                                                                                                    weight:UIImageSymbolWeightRegular]]
                              imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        _avatarImageView.tintColor = [PPPetsUIBrandColor() colorWithAlphaComponent:0.84];
        showsEmptyProfileAnimation = YES;
    }

    _cardView.backgroundColor = UIColor.clearColor;
    _heroGlassBackground.accentColorOverride = accentColor;
    [_heroGlassBackground reapplyPalette];
    _accentRailView.backgroundColor = accentColor;
    _titleLabel.textColor = textColor;
    _subtitleLabel.textColor = secondaryTextColor;
    _collapsedSummaryLabel.textColor = secondaryTextColor;
    _metaPrimaryLabel.textColor = secondaryTextColor;
    _metaSecondaryLabel.textColor = secondaryTextColor;
    _eyebrowLabel.textColor = accentColor;
    _eyebrowLabel.backgroundColor = [accentColor colorWithAlphaComponent:(isDark ? 0.16 : 0.10)];
    _avatarShellView.backgroundColor = [accentColor colorWithAlphaComponent:(isDark ? 0.12 : 0.07)];
    [_avatarShellView pp_setBorderColor:[accentColor colorWithAlphaComponent:(isDark ? 0.28 : 0.18)]];
    _expandButton.backgroundColor = [accentColor colorWithAlphaComponent:(isDark ? 0.14 : 0.08)];
    [_expandButton pp_setBorderColor:[accentColor colorWithAlphaComponent:(isDark ? 0.28 : 0.18)]];
    _expandImageView.tintColor = accentColor;
    _ctaView.backgroundColor = accentColor;
    _ctaLabel.textColor = UIColor.whiteColor;
    _ctaImageView.tintColor = UIColor.whiteColor;
    _loadingIndicator.color = accentColor;
    _detailsDividerView.backgroundColor = isDark
        ? [UIColor colorWithWhite:1.0 alpha:0.10]
        : [UIColor colorWithWhite:0.0 alpha:0.07];
    _cardView.layer.shadowOpacity = 0.0f;

    UIImageSymbolConfiguration *metaSymbolConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:13.0 weight:UIImageSymbolWeightSemibold];
    _metaPrimaryIconView.image =
        [[[UIImage systemImageNamed:primaryIconName] imageByApplyingSymbolConfiguration:metaSymbolConfiguration]
         imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    _metaSecondaryIconView.image =
        [[[UIImage systemImageNamed:secondaryIconName] imageByApplyingSymbolConfiguration:metaSymbolConfiguration]
         imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    _metaPrimaryIconView.tintColor = accentColor;
    _metaSecondaryIconView.tintColor = accentColor;
    _ctaImageView.image = [UIImage systemImageNamed:forwardSymbol
                                  withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:13.0
                                                                                                 weight:UIImageSymbolWeightBold]];
    _avatarImageView.image = avatarPlaceholder;
    _avatarImageView.alpha = isLoading ? 0.34 : 1.0;
    [self pp_setAvatarEmptyAnimationVisible:showsEmptyProfileAnimation && !isLoading];
    if (isLoading) {
        [_loadingIndicator startAnimating];
    } else {
        [_loadingIndicator stopAnimating];
    }

    if (defaultPet.imageURL.length > 0) {
        [[PPImageLoaderManager shared] setImageOnImageView:_avatarImageView
                                                       url:defaultPet.imageURL
                                               placeholder:avatarPlaceholder
                                          transitionStyle:PPImageTransitionStyleNone
                                               complation:nil];
    }

    NSString *primaryMeta = _metaPrimaryLabel.text ?: @"";
    NSString *secondaryMeta = _metaSecondaryLabel.text ?: @"";
    if (primaryMeta.length > 0 && secondaryMeta.length > 0) {
        _collapsedSummaryLabel.text = [NSString stringWithFormat:@"%@ · %@", primaryMeta, secondaryMeta];
    } else {
        _collapsedSummaryLabel.text = primaryMeta.length > 0 ? primaryMeta : secondaryMeta;
    }
    BOOL resolvedExpanded = expanded && !isLoading;
    [self pp_applyExpanded:resolvedExpanded animated:NO];
    _expandButton.userInteractionEnabled = !isLoading;
    _expandButton.alpha = isLoading ? 0.52 : 1.0;

    NSString *accessibilityTitle = _titleLabel.text ?: @"";
    NSString *accessibilitySubtitle = _subtitleLabel.text ?: @"";
    self.accessibilityLabel = [NSString stringWithFormat:@"%@. %@", accessibilityTitle, accessibilitySubtitle];
    self.accessibilityValue = resolvedExpanded
        ? (kLang(@"home_pet_profile_collapse") ?: @"Expanded")
        : (kLang(@"home_pet_profile_expand") ?: @"Collapsed");
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

- (void)pp_handleExpandButtonTap
{
    if (!_expandButton.userInteractionEnabled) {
        return;
    }

    UISelectionFeedbackGenerator *feedback = [[UISelectionFeedbackGenerator alloc] init];
    [feedback selectionChanged];
    [self pp_applyExpanded:!_expanded animated:YES];
    if (self.onToggleExpanded) {
        self.onToggleExpanded(_expanded);
    }
}

- (void)pp_handleExpandButtonTouchDown
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    [UIView animateWithDuration:0.10
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self->_expandButton.transform = CGAffineTransformMakeScale(0.90, 0.90);
    } completion:nil];
}

- (void)pp_handleExpandButtonTouchUp
{
    [UIView animateWithDuration:0.28
                          delay:0.0
         usingSpringWithDamping:0.72
          initialSpringVelocity:0.30
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self->_expandButton.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (BOOL)pp_handleExpandAccessibilityAction:(UIAccessibilityCustomAction *)action
{
    (void)action;
    [self pp_handleExpandButtonTap];
    return YES;
}

- (void)pp_applyExpanded:(BOOL)expanded animated:(BOOL)animated
{
    _expanded = expanded;
    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    NSTimeInterval duration = (animated && !reduceMotion) ? 0.40 : 0.0;
    CGFloat detailsAlpha = expanded ? 1.0 : 0.0;
    CGFloat compactAlpha = expanded ? 0.0 : 1.0;
    CGAffineTransform detailsTransform = expanded
        ? CGAffineTransformIdentity
        : CGAffineTransformMakeTranslation(0.0, -6.0);
    CGAffineTransform compactTransform = expanded
        ? CGAffineTransformMakeTranslation(0.0, 5.0)
        : CGAffineTransformIdentity;
    _expandImageView.image = [UIImage systemImageNamed:@"chevron.down"
                                    withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14.0
                                                                                                   weight:UIImageSymbolWeightBold]];
    _expandButton.accessibilityLabel = expanded
        ? (kLang(@"home_pet_profile_collapse") ?: @"Collapse")
        : (kLang(@"home_pet_profile_expand") ?: @"Expand");
    _expandButton.accessibilityHint = expanded
        ? (kLang(@"home_pet_profile_collapse_hint") ?: @"Shows fewer pet profile details")
        : (kLang(@"home_pet_profile_expand_hint") ?: @"Shows pet profile details");
    NSString *accessibilityActionTitle = expanded
        ? (kLang(@"home_pet_profile_collapse") ?: @"Collapse")
        : (kLang(@"home_pet_profile_expand") ?: @"Expand");
    self.accessibilityCustomActions = @[
        [[UIAccessibilityCustomAction alloc] initWithName:accessibilityActionTitle
                                                   target:self
                                                 selector:@selector(pp_handleExpandAccessibilityAction:)]
    ];
    self.accessibilityValue = expanded
        ? (kLang(@"home_pet_profile_collapse") ?: @"Expanded")
        : (kLang(@"home_pet_profile_expand") ?: @"Collapsed");

    if (expanded) {
        _detailsView.hidden = NO;
    }
    _detailsHeightConstraint.constant = expanded ? 96.0 : 0.0;

    void (^changes)(void) = ^{
        self->_detailsView.alpha = detailsAlpha;
        self->_collapsedSummaryLabel.alpha = compactAlpha;
        self->_detailsView.transform = detailsTransform;
        self->_collapsedSummaryLabel.transform = compactTransform;
        self->_expandButton.transform = CGAffineTransformIdentity;
        self->_expandImageView.transform = expanded
            ? CGAffineTransformMakeRotation((CGFloat)M_PI)
            : CGAffineTransformIdentity;
        [self.contentView layoutIfNeeded];
    };

    if (duration <= 0.0) {
        changes();
        _detailsView.hidden = !expanded;
        return;
    }

    [self.contentView layoutIfNeeded];
    [UIView animateWithDuration:duration
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:changes
                     completion:^(__unused BOOL finished) {
        self->_detailsView.hidden = !expanded;
    }];
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
static NSString * const PPHomePetProfileCardExpandedKey = @"pp.home.petProfileCard.expanded.v1";
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
    PPHomeProfileMenuActionPurchased,
    PPHomeProfileMenuActionOrders,
    PPHomeProfileMenuActionProduction,
    PPHomeProfileMenuActionSettings,
    PPHomeProfileMenuActionSupport,
    PPHomeProfileMenuActionLogout
};

static inline BOOL PPHomeFiniteCGFloat(CGFloat value)
{
    return isfinite((double)value);
}

static inline CGFloat PPHomeClampedFiniteCGFloat(CGFloat value, CGFloat fallback, CGFloat minimum, CGFloat maximum)
{
    CGFloat resolved = PPHomeFiniteCGFloat(value) ? value : fallback;
    if (PPHomeFiniteCGFloat(minimum)) {
        resolved = MAX(minimum, resolved);
    }
    if (PPHomeFiniteCGFloat(maximum)) {
        resolved = MIN(maximum, resolved);
    }
    return resolved;
}

static inline BOOL PPHomeRectIsFiniteAndNotEmpty(CGRect rect)
{
    return !CGRectIsNull(rect) &&
           !CGRectIsEmpty(rect) &&
           PPHomeFiniteCGFloat(rect.origin.x) &&
           PPHomeFiniteCGFloat(rect.origin.y) &&
           PPHomeFiniteCGFloat(rect.size.width) &&
           PPHomeFiniteCGFloat(rect.size.height);
}

@interface PPHomeAmbientGlowView : UIView
@property (nonatomic, strong) CAGradientLayer *radialLayer;
@property (nonatomic, assign, getter=isFaded) BOOL faded;
- (void)applyColor:(UIColor *)color
         peakAlpha:(CGFloat)peakAlpha
       middleAlpha:(CGFloat)middleAlpha;
@end

@implementation PPHomeAmbientGlowView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.userInteractionEnabled = NO;
    self.isAccessibilityElement = NO;
    self.accessibilityElementsHidden = YES;
    self.backgroundColor = UIColor.clearColor;
    self.opaque = NO;
    self.faded = backgroundGlowsFaded;

    _radialLayer = [CAGradientLayer layer];
    if (@available(iOS 12.0, *)) {
        _radialLayer.type = kCAGradientLayerRadial;
        _radialLayer.startPoint = CGPointMake(0.5, 0.5);
        _radialLayer.endPoint = CGPointMake(1.0, 1.0);
    } else {
        _radialLayer.startPoint = CGPointMake(0.0, 0.5);
        _radialLayer.endPoint = CGPointMake(1.0, 0.5);
    }
    _radialLayer.locations = @[@0.0, @0.46, @1.0];
    _radialLayer.drawsAsynchronously = YES;
    [self.layer addSublayer:_radialLayer];
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect bounds = self.bounds;
    if (!PPHomeRectIsFiniteAndNotEmpty(bounds)) {
        self.layer.cornerRadius = 0.0;
        self.radialLayer.frame = CGRectZero;
        return;
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.layer.cornerRadius = MAX(0.0, CGRectGetWidth(bounds) * 0.5);
    self.layer.masksToBounds = !self.isFaded;
    self.radialLayer.frame = bounds;
    [CATransaction commit];
}

- (void)applyColor:(UIColor *)color
         peakAlpha:(CGFloat)peakAlpha
       middleAlpha:(CGFloat)middleAlpha
{
    UIColor *safeColor = color ?: UIColor.clearColor;
    CGFloat safePeakAlpha = PPHomeClampedFiniteCGFloat(peakAlpha, 0.0, 0.0, 1.0);
    CGFloat safeMiddleAlpha = PPHomeClampedFiniteCGFloat(middleAlpha, 0.0, 0.0, 1.0);
    CGRect bounds = self.bounds;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.layer.cornerRadius = PPHomeRectIsFiniteAndNotEmpty(bounds) ? MAX(0.0, CGRectGetWidth(bounds) * 0.5) : 0.0;
    self.layer.masksToBounds = !self.isFaded;
    if (self.isFaded) {
        self.backgroundColor = UIColor.clearColor;
        self.radialLayer.hidden = NO;
        self.radialLayer.locations = @[@0.0, @0.46, @1.0];
        self.radialLayer.colors = @[
            (id)[safeColor colorWithAlphaComponent:safePeakAlpha].CGColor,
            (id)[safeColor colorWithAlphaComponent:safeMiddleAlpha].CGColor,
            (id)[safeColor colorWithAlphaComponent:0.0].CGColor
        ];
    } else {
        self.radialLayer.hidden = YES;
        self.backgroundColor = [safeColor colorWithAlphaComponent:safePeakAlpha];
    }
    [CATransaction commit];
}

@end

static NSString * const PPHomeMiddleBackgroundGlowPositionMotionKey = @"pp.home.background.mid.position";
static NSString * const PPHomeMiddleBackgroundGlowPeekMotionKey = @"pp.home.background.mid.peek";


@interface PPHomeViewController ()<UICollectionViewDelegate, UICollectionViewDataSourcePrefetching, BannerTapsCollectionDelegate,PPUniversalCellDelegate, CLLocationManagerDelegate, UIGestureRecognizerDelegate>
- (void)pp_handleProfileMenuAction:(PPHomeProfileMenuAction)action;
- (void)pp_openPurchasedItems;
- (void)pp_handleOrthogonalPanGate:(UIPanGestureRecognizer *)panGestureRecognizer;
- (void)pp_installOrthogonalGestureGatesIfNeeded;

 @property (nonatomic, assign) BOOL warmUpCache;
@property (nonatomic, assign) BOOL chatsListenerStarted;
@property (nonatomic, copy, nullable) NSString *unreadListenerUserID;
@property (nonatomic, assign) BOOL adsLoaded;
@property (nonatomic, assign) BOOL accessoriesLoaded;
@property (nonatomic, assign) BOOL lastFoodLoaded;
@property (nonatomic, assign) BOOL nearbyLoaded;
@property (nonatomic, assign) BOOL nearbyLoading;
@property (nonatomic, strong) NSArray<ServiceModel *> *nearbyServiceProviders;
@property (nonatomic, assign) BOOL nearbyServicesLoaded;
@property (nonatomic, assign) BOOL nearbyServicesLoading;
@property (nonatomic, assign) BOOL nearbyServicesShowingLatest;
@property (nonatomic, strong, nullable) MainKindsModel *selectedCategory;
@property (nonatomic, assign) BOOL didResolveInitialHomeCategory;
@property (nonatomic, assign) BOOL didPositionInitialMainKindSelection;
@property (nonatomic, assign) BOOL usesRestoredMainKindSelectionAppearance;
@property (nonatomic, strong) PPHomeLayoutManager *layoutManager;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UICollectionViewDiffableDataSource<NSNumber *, PPHomeItem *> *dataSource;
@property (nonatomic, assign) BOOL didSelectInitialNearby;
@property (nonatomic, strong) NSArray<PetAd *> *ads;
@property (nonatomic, strong) NSArray<ServiceModel *> *services;
@property (nonatomic, strong) NSArray<MainKindsModel *> *mainKinds;
@property (nonatomic, strong) NSArray<PPCategoryItem *> *categories;
@property (nonatomic, copy, nullable) NSString *selectedProviderCategoryIdentifier;
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
@property (nonatomic, strong) UIView *pp_premiumBackgroundCanvasView;
@property (nonatomic, strong) PPHomeAmbientGlowView *pp_premiumBackgroundGlowViewTop;
@property (nonatomic, strong) PPHomeAmbientGlowView *pp_premiumBackgroundGlowViewMid;
@property (nonatomic, strong) PPHomeAmbientGlowView *pp_premiumBackgroundGlowViewBottom;
@property (nonatomic, strong) PPBackgroundView *ambientBackgroundView;
@property (nonatomic, strong) NSMutableSet<NSString *> *animatedHomeItemIdentifiers;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *animatedHomeHeaderSections;
@property (nonatomic, strong) NSMutableSet<NSString *> *animatedHomeHorizontalUniversalIdentifiers;
@property (nonatomic, assign) BOOL currentOrdersLoading;
@property (nonatomic, assign) BOOL currentOrdersLoaded;
@property (nonatomic, assign) BOOL petProfilesLoading;
@property (nonatomic, assign) BOOL petProfilesLoaded;
@property (nonatomic, assign) BOOL isCurrentOrdersExpanded;
@property (nonatomic, assign) BOOL isPetProfileCardExpanded;
@property (nonatomic, assign) BOOL backgroundGlowsFadedByHomeConfig;
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
@property (nonatomic, assign) CGSize premiumBackgroundGlowMotionCanvasSize;
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
@property (nonatomic, assign) BOOL didApplyServerHomeConfig;
@property (nonatomic, assign) BOOL isHomeBootstrapped;
@property (nonatomic, strong, nullable) UIView *bootstrapOverlayView;
@property (nonatomic, strong, nullable) UIActivityIndicatorView *bootstrapSpinner;
@property (nonatomic, strong, nullable) NSTimer *bootstrapTimeoutTimer;
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
- (NSArray<PPHomeProviderCategoryItem *> *)pp_homeProviderCategoryItems;
- (NSArray<PPHomeProviderCategoryItem *> *)pp_homeProviderUnifiedCategoryItems;
- (void)pp_handleProviderCategorySelection:(PPHomeProviderCategoryItem *)item;
- (void)pp_openMarketplaceProvidersListFromHero;
- (NSArray<MainKindsModel *> *)pp_mainKindsRailDataSource;
- (void)pp_applyInitialCategorySelectionIfNeeded;
- (void)pp_selectHomeMainKind:(MainKindsModel *)kind
                        isAll:(BOOL)isAll
                      persist:(BOOL)persist
                     navigate:(BOOL)navigate;
- (void)pp_refreshHomeCategorySelectionAnimated:(BOOL)animated;
- (void)pp_positionInitialSelectedMainKindIfNeededAnimated:(BOOL)animated;
- (NSInteger)pp_indexOfSelectedMainKindInRail;
- (NSArray<PPHomeItem *> *)pp_safeItemsInSection:(PPHomeSection)section
                                    fromSnapshot:(NSDiffableDataSourceSnapshot *)snapshot;
- (void)pp_refreshProviderCategoryNavigationSection;
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
- (BOOL)pp_shouldStageHomeEntranceContent;
- (BOOL)pp_shouldDeferHomeLayoutStabilization;
- (NSArray<NSNumber *> *)pp_collectionSectionIndexesOrderedForEntrance;
- (NSArray<NSIndexPath *> *)pp_sortedVisibleIndexPathsForEntrance;
- (void)pp_preparePremiumHomeEntranceStateIfNeeded;
- (void)pp_prepareVisibleHomeEntranceContentIfNeeded;
- (void)pp_beginPremiumHomeEntranceIfNeeded;
- (void)pp_addRandomizedMiddleBackgroundGlowPositionMotion;
- (void)pp_beginPremiumBackgroundGlowMotionIfNeeded;
- (void)pp_stopPremiumBackgroundGlowMotion;
- (void)pp_animateVisibleHomeEntranceContentIfNeeded;
- (void)pp_configureHomeEntranceInitialStateForCell:(UICollectionViewCell *)cell
                                        atIndexPath:(NSIndexPath *)indexPath
                                     lateAppearance:(BOOL)isLateAppearance;
- (void)pp_configureHomeEntranceInitialStateForSupplementaryView:(UICollectionReusableView *)supplementaryView
                                                            kind:(NSString *)kind
                                                     atIndexPath:(NSIndexPath *)indexPath
                                                  lateAppearance:(BOOL)isLateAppearance;
- (void)pp_stageHomeEntranceCellIfNeeded:(UICollectionViewCell *)cell
                              indexPath:(NSIndexPath *)indexPath;
- (void)pp_stageHomeEntranceSupplementaryViewIfNeeded:(UICollectionReusableView *)supplementaryView
                                                 kind:(NSString *)kind
                                            indexPath:(NSIndexPath *)indexPath;
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
- (void)pp_refreshVisibleHomeAppearanceForCurrentTheme;
- (void)pp_refreshLanguageSensitiveHomeContent;
- (void)pp_refreshVisibleHomeHeadersForCurrentLanguage;
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
- (void)handleLanguageDidChange:(NSNotification *)notification;
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
- (void)pp_setPetProfileCardExpanded:(BOOL)expanded animated:(BOOL)animated;
- (void)pp_scrollCurrentOrdersSectionIntoViewAnimated:(BOOL)animated;
- (NSString *)pp_homeRelativeDateString:(NSDate *)date;
- (NSString *)pp_homeShortDateString:(NSDate *)date;
- (nullable PPOrder *)pp_featuredHomeOrder;
- (NSArray<PPHomeItem *> *)pp_homeCurrentOrderItems;
- (BOOL)pp_shouldRenderCurrentOrdersSection;
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
             backgroundGlowsFaded:(BOOL)glowsFaded
                     novaUseGenkit:(BOOL)novaUseGenkit
                      useLegacyBar:(BOOL)useLegacyBar;
- (BOOL)pp_applyCachedHomeConfigIfAvailable;
- (BOOL)pp_cachedNovaFloatingVisibility;
- (void)pp_publishNovaFloatingVisibility:(BOOL)visible;
- (void)pp_applyNovaFloatingHomeConfigVisibilityAnimated:(BOOL)animated;
- (void)pp_startNovaFloatingAmbientMotionIfNeeded;
- (void)pp_stopNovaFloatingMotion;
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
- (void)pp_reloadHomeItems:(NSArray<PPHomeItem *> *)items
                 inSnapshot:(NSDiffableDataSourceSnapshot *)snapshot;
- (BOOL)pp_homeItemRequiresFullReload:(PPHomeItem *)item;

- (void)refreshNavigationRightItemsForCartCount:(NSUInteger)count;
- (void)pp_applyHomeCartButtonAppearance;
- (void)pp_updateHomeCartButtonPresenceAnimated:(BOOL)animated;
- (void)pp_handleSavedForLaterUpdatedNotification:(NSNotification *)notification;
@property (nonatomic, assign) BOOL isMainKindsExpanded;
@property (nonatomic, assign) BOOL didAutoScrollSuggestions;
@property (nonatomic, assign) BOOL didAutoScrollNearbyServices;
@property (nonatomic, assign) BOOL didFillSuggestionsOnce;
@property (nonatomic, assign) BOOL didApplyInitialHomeAppearanceRefresh;
@property (nonatomic, assign) BOOL needsVisibleHomeThemeAppearanceRefresh;
@property (nonatomic, assign) BOOL needsVisibleHomeLanguageRefresh;
@property (nonatomic, copy, nullable) NSString *lastHomeSuggestionsAppearanceSignature;
@property (nonatomic, copy, nullable) NSString *lastCurrentOrdersSectionSignature;
@property (nonatomic, copy, nullable) NSString *lastBuyAgainSectionSignature;
@property (nonatomic, copy, nullable) NSString *lastPetProfilesSectionSignature;
@property (nonatomic, copy, nullable) NSString *lastPetProfilesUserID;
@property (nonatomic, assign) BOOL shouldRefreshPetProfilesOnNextAppearance;
@property (nonatomic, strong) UIView *profileCard;
@property (nonatomic, strong, nullable) UIBarButtonItem *homeProfileItem;
 @property (nonatomic, strong, nullable) UIButton *homeCartButton;
@property (nonatomic, strong) UIButton *novaFloatingButton;
@property (nonatomic, strong, nullable) LOTAnimationView *novaFloatingLottieView;
@property (nonatomic, strong, nullable) UIView *novaFloatingHaloView;
@property (nonatomic, assign) BOOL novaFloatingVisibleByHomeConfig;
@property (nonatomic, assign) BOOL novaFloatingButtonScrollCompressed;
@property (nonatomic, assign) NSUInteger novaFloatingScrollMotionGeneration;
@property (nonatomic, strong, nullable) UIBarButtonItem *homeOptionsItem;
@property (nonatomic, strong, nullable) PPHomeSmartSearchTitleView *homeSmartSearchView;
@property (nonatomic, strong, nullable) NSLayoutConstraint *homeSmartSearchWidthConstraint;
@property (nonatomic, strong, nullable) UIView *homeSmartSearchAndCartContainer;
@property (nonatomic, strong, nullable) NSLayoutConstraint *homeSmartSearchAndCartContainerWidthConstraint;
@property (nonatomic, strong, nullable) NSLayoutConstraint *homeSmartSearchTrailingToContainerConstraint;
@property (nonatomic, strong, nullable) NSLayoutConstraint *homeSmartSearchTrailingToCartConstraint;
@property (nonatomic, strong, nullable) NSLayoutConstraint *homeCartButtonWidthConstraint;
@property (nonatomic, strong, nullable) NSLayoutConstraint *homeCartButtonHeightConstraint;
@property (nonatomic, assign) BOOL homeCartButtonPresencePrepared;
@property (nonatomic, assign) BOOL homeCartButtonSlotVisible;
@property (nonatomic, strong, nullable) NSTimer *homeSmartSearchTimer;
@property (nonatomic, copy) NSArray<NSString *> *homeSmartSearchPlaceholders;
@property (nonatomic, assign) NSInteger homeSmartSearchPlaceholderIndex;
@property (nonatomic, assign) CGFloat homeSmartSearchCollapseProgress;
@property (nonatomic, assign) CGFloat homeSmartSearchOverscrollProgress;
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
- (void)pp_applyPremiumHomeBackgroundAppearance;
- (void)pp_installPremiumBackgroundGlowViewsIfNeeded;
- (void)pp_layoutPremiumBackgroundGlowViews;
- (void)pp_updatePremiumBackgroundGlowAppearance;
- (void)handleHomeAccessibilityAppearanceDidChange:(NSNotification *)notification;
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
- (void)pp_applyHomeSmartSearchPlaceholderToVisiblePremiumSearchCells:(NSString *)placeholder
                                                              animated:(BOOL)animated;
- (void)pp_startHomeSmartSearchTimerIfNeeded;
- (void)pp_stopHomeSmartSearchTimer;
- (void)pp_scheduleSmartSearchTimerWithInterval:(NSTimeInterval)interval;
- (void)pp_advanceHomeSmartSearchPlaceholder;
- (void)pp_updateHomeSmartSearchForScrollView:(UIScrollView *)scrollView
                                      animated:(BOOL)animated;
- (void)pp_stabilizeHomeCollectionLayoutIfNeeded;
- (void)pp_refreshVisibleHomeCardsForSections:(NSArray<NSNumber *> *)sections;
- (void)pp_refreshInitialHomeRevealDependentContent;

@end


@implementation PPHomeViewController

- (void)setInitialSelectedMainKindID:(NSInteger)initialSelectedMainKindID
{
    _initialSelectedMainKindID = initialSelectedMainKindID;
    self.didPositionInitialMainKindSelection = NO;
    self.usesRestoredMainKindSelectionAppearance = NO;
    if (!self.isViewLoaded) {
        return;
    }
    self.didResolveInitialHomeCategory = NO;
    [self pp_applyInitialCategorySelectionIfNeeded];
    [self pp_refreshHomeCategorySelectionAnimated:YES];
}

- (NSArray<MainKindsModel *> *)pp_mainKindsRailDataSource
{
    NSMutableArray<MainKindsModel *> *items = [NSMutableArray array];
    [items addObject:[MainKindsModel allKind]];
    NSArray<MainKindsModel *> *source = [self.mainKinds isKindOfClass:NSArray.class] ? self.mainKinds : @[];
    for (MainKindsModel *kind in source) {
        if (![kind isKindOfClass:MainKindsModel.class] || kind.ID == PPHomeAllMainKindID) {
            continue;
        }
        [items addObject:kind];
    }
    return items.copy;
}

- (MainKindsModel *)pp_resolvedSavedHomeCategory
{
    id storedValue = [[NSUserDefaults standardUserDefaults] objectForKey:PPHomeLastSelectedMainKindIDKey];
    if (![storedValue respondsToSelector:@selector(integerValue)]) {
        return nil;
    }

    NSInteger storedID = [storedValue integerValue];
    if (storedID == PPHomeAllMainKindID) {
        return nil;
    }
    if (storedID > 0) {
        return [self resolveMainKindWithID:storedID];
    }
    return nil;
}

- (void)pp_applyInitialCategorySelectionIfNeeded
{
    if (self.didResolveInitialHomeCategory) {
        return;
    }
    self.didResolveInitialHomeCategory = YES;

    if (self.initialSelectedMainKindID == PPHomeAllMainKindID) {
        self.selectedCategory = nil;
        self.usesRestoredMainKindSelectionAppearance = YES;
        return;
    }
    if (self.initialSelectedMainKindID > 0) {
        MainKindsModel *navigationKind = [self resolveMainKindWithID:self.initialSelectedMainKindID];
        if (navigationKind) {
            self.selectedCategory = navigationKind;
            self.usesRestoredMainKindSelectionAppearance = NO;
            return;
        }
    }

    MainKindsModel *savedCategory = [self pp_resolvedSavedHomeCategory];
    self.selectedCategory = savedCategory;
    self.usesRestoredMainKindSelectionAppearance = YES;
}

- (void)pp_saveSelectedHomeCategory:(MainKindsModel *)kind
                              isAll:(BOOL)isAll
{
    NSInteger storedID = (isAll || !kind) ? PPHomeAllMainKindID : kind.ID;
    [[NSUserDefaults standardUserDefaults] setInteger:storedID
                                               forKey:PPHomeLastSelectedMainKindIDKey];
}

- (void)pp_refreshVisibleMarketplaceHeroAnimated:(BOOL)animated
{
    if (!self.collectionView) {
        return;
    }
    NSInteger sectionIndex = [self sectionIndexForType:PPHomeSectionMarketplaceHero];
    if (sectionIndex == NSNotFound) {
        return;
    }
    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:sectionIndex];
    UICollectionViewCell *rawCell = [self.collectionView cellForItemAtIndexPath:indexPath];
    if ([rawCell isKindOfClass:PPHomeMarketplaceHeroCell.class]) {
        [(PPHomeMarketplaceHeroCell *)rawCell configureWithMainKind:self.selectedCategory
                                                           animated:animated];
    }
}

- (void)pp_refreshHomeCategorySelectionAnimated:(BOOL)animated
{
    if (!self.dataSource) {
        return;
    }
    NSDiffableDataSourceSnapshot *snapshot = self.dataSource.snapshot;
    NSArray *items = [self pp_safeItemsInSection:PPHomeSectionMainKinds
                                    fromSnapshot:snapshot];
    if (items.count > 0) {
        [self pp_reconfigureHomeItems:items inSnapshot:snapshot];
    }
    [self pp_refreshVisibleMarketplaceHeroAnimated:animated];
}

- (NSInteger)pp_indexOfSelectedMainKindInRail
{
    if (!self.selectedCategory) {
        return 0;
    }

    NSArray<MainKindsModel *> *railItems = [self pp_mainKindsRailDataSource];
    for (NSUInteger idx = 0; idx < railItems.count; idx++) {
        MainKindsModel *kind = railItems[idx];
        if ([kind isKindOfClass:MainKindsModel.class] &&
            kind.ID == self.selectedCategory.ID) {
            return (NSInteger)idx;
        }
    }
    return NSNotFound;
}

- (void)pp_positionInitialSelectedMainKindIfNeededAnimated:(BOOL)animated
{
    if (self.didPositionInitialMainKindSelection ||
        self.isMainKindsExpanded ||
        !self.isViewLoaded ||
        !self.collectionView ||
        !self.dataSource ||
        self.isPremiumHomeEntranceAnimating) {
        return;
    }

    NSInteger selectedIndex = [self pp_indexOfSelectedMainKindInRail];
    if (selectedIndex == NSNotFound || selectedIndex < 0) {
        self.didPositionInitialMainKindSelection = YES;
        return;
    }

    NSInteger sectionIndex = [self sectionIndexForType:PPHomeSectionMainKinds];
    if (sectionIndex == NSNotFound) {
        return;
    }

    if ([self.collectionView numberOfSections] <= sectionIndex ||
        [self.collectionView numberOfItemsInSection:sectionIndex] <= selectedIndex) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self ||
            self.didPositionInitialMainKindSelection ||
            self.isMainKindsExpanded ||
            self.isPremiumHomeEntranceAnimating) {
            return;
        }

        NSInteger currentSelectedIndex = [self pp_indexOfSelectedMainKindInRail];
        NSInteger currentSectionIndex = [self sectionIndexForType:PPHomeSectionMainKinds];
        if (currentSelectedIndex == NSNotFound ||
            currentSelectedIndex < 0 ||
            currentSectionIndex == NSNotFound ||
            [self.collectionView numberOfSections] <= currentSectionIndex ||
            [self.collectionView numberOfItemsInSection:currentSectionIndex] <= currentSelectedIndex) {
            return;
        }

        [self.collectionView layoutIfNeeded];
        BOOL shouldAnimate = animated && !UIAccessibilityIsReduceMotionEnabled();
        UICollectionViewScrollPosition leadingPosition = Language.isRTL
            ? UICollectionViewScrollPositionRight
            : UICollectionViewScrollPositionLeft;
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:currentSelectedIndex
                                                     inSection:currentSectionIndex];
        [self.collectionView scrollToItemAtIndexPath:indexPath
                                    atScrollPosition:leadingPosition
                                            animated:shouldAnimate];
        void (^applyRestoredSelectionLayout)(PPHomeViewController *) = ^(PPHomeViewController *host) {
            [host.collectionView.collectionViewLayout invalidateLayout];
            [host.collectionView setNeedsLayout];
            [host.collectionView layoutIfNeeded];
            [host pp_refreshHomeCategorySelectionAnimated:NO];
            [host.collectionView layoutIfNeeded];
            UICollectionViewCell *visibleCell = [host.collectionView cellForItemAtIndexPath:indexPath];
            if ([visibleCell isKindOfClass:PPMainKindsCell.class]) {
                [visibleCell setNeedsLayout];
                [visibleCell.contentView setNeedsLayout];
                [visibleCell.contentView layoutIfNeeded];
                [visibleCell layoutIfNeeded];
                [(PPMainKindsCell *)visibleCell playRestoredSelectionAnimation];
            }
            host.didPositionInitialMainKindSelection = YES;
        };
        if (shouldAnimate) {
            __weak typeof(self) weakSelf = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.32 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) { return; }
                applyRestoredSelectionLayout(self);
            });
        } else {
            applyRestoredSelectionLayout(self);
        }
    });
}

- (void)pp_selectHomeMainKind:(MainKindsModel *)kind
                        isAll:(BOOL)isAll
                      persist:(BOOL)persist
                     navigate:(BOOL)navigate
{
    MainKindsModel *nextCategory = isAll ? nil : kind;
    BOOL changed = (self.selectedCategory == nil && nextCategory != nil) ||
                   (self.selectedCategory != nil && nextCategory == nil) ||
                   (self.selectedCategory != nil && nextCategory != nil &&
                    self.selectedCategory.ID != nextCategory.ID);

    self.selectedCategory = nextCategory;
    self.usesRestoredMainKindSelectionAppearance = NO;
    if (persist) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self pp_saveSelectedHomeCategory:kind isAll:isAll];
        });
    }

    void (^applySelectionAndRoute)(void) = ^{
        [self pp_refreshHomeCategorySelectionAnimated:changed];

        if (!navigate) {
            return;
        }
        if (isAll) {
            [self handleDeepLinkWithTarget:PPDeepLinkTargetAllCategories
                                  mainKind:nil
                                    source:PPInputSourceHomeMainKindsSection];
        } else if (kind) {
            [self handleMainKindSelection:kind];
        }
    };

    if ([NSThread isMainThread]) {
        applySelectionAndRoute();
        return;
    }

    dispatch_async(dispatch_get_main_queue(), applySelectionAndRoute);
}

- (NSArray<NSString *> *)pp_premiumCareAnimationNames
{
    static NSArray<NSString *> *names = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        names = @[@"ecg3"]; // @"pet-care2", @"pet-care3", @"pet-care4", @"pet-care5"
    });
    return names;
}

- (NSString *)pp_currentPremiumCareAnimationName
{
    NSString *name = PPSafeString(self.currentPremiumCareAnimationName);
    return name.length > 0 ? name : @"ecg3";
}

- (void)pp_advancePremiumCareAnimationForAppearance
{
    NSArray<NSString *> *names = [self pp_premiumCareAnimationNames];
    if (names.count == 0) {
        self.currentPremiumCareAnimationName = @"ecg3";
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
    if (PPULTRA_CARE_IS_ACTIVATED &&
        [rawCell isKindOfClass:PPHomeUltraPremuimPetCareCell.class]) {
        [(PPHomeUltraPremuimPetCareCell *)rawCell
            configureWithAnimationName:[self pp_currentPremiumCareAnimationName]];
    } else if (!PPULTRA_CARE_IS_ACTIVATED &&
               [rawCell isKindOfClass:PPHomePremiumCareCell.class]) {
        [(PPHomePremiumCareCell *)rawCell
            configureWithAnimationName:[self pp_currentPremiumCareAnimationName]];
    } else {
        return;
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [rawCell setNeedsLayout];
    [rawCell.contentView setNeedsLayout];
    [rawCell.contentView layoutIfNeeded];
    [rawCell layoutIfNeeded];
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
    [storagePaths addObject:@"LottieAnimations/NovaHome.json"];

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
        @(PPHomeSectionPremiumSearch),
        @(PPHomeSectionMarketplaceHero),
        @(PPHomeSectionProviderCategoryNav),
        @(PPHomeSectionHero),
        @(PPHomeSectionPremiumCare),
        @(PPHomeSectionQuickActions),
        @(PPHomeSectionMainKinds),
        @(PPHomeSectionCurrentOrders),
        @(PPHomeSectionAccessories),
        @(PPHomeSectionSuggestionAds),
        @(PPHomeSectionSuggestionAccessories),
        @(PPHomeSectionSuggestions),
        @(PPHomeSectionCarousel),
        @(PPHomeSectionLastFood),
        @(PPHomeSectionAdsNearBy),
        @(PPHomeSectionPetProfile),
        @(PPHomeSectionNearbyServices),
        @(PPHomeSectionAdopt),
        @(PPHomeSectionBuyAgain),
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
                @"PPHomeSectionCarousel" : @(PPHomeSectionCarousel),
                @"PPHomeSectionMainKinds" : @(PPHomeSectionMainKinds),
                @"PPHomeSectionSuggestions" : @(PPHomeSectionSuggestions),
                @"PPHomeSectionSuggestionAds" : @(PPHomeSectionSuggestionAds),
                @"PPHomeSectionSuggestionAccessories" : @(PPHomeSectionSuggestionAccessories),
                @"PPHomeSectionAccessories" : @(PPHomeSectionAccessories),
                @"PPHomeSectionPetProfile" : @(PPHomeSectionPetProfile),
                @"PPHomeSectionPremiumCare" : @(PPHomeSectionPremiumCare),
                @"PPHomeSectionLastFood" : @(PPHomeSectionLastFood),
                @"PPHomeSectionNearbyServices" : @(PPHomeSectionNearbyServices),
                @"PPHomeSectionAdsNearBy" : @(PPHomeSectionAdsNearBy),
                @"PPHomeSectionAdopt" : @(PPHomeSectionAdopt),
                @"PPHomeSectionBuyAgain" : @(PPHomeSectionBuyAgain),
                @"PPHomeSectionPremiumSearch" : @(PPHomeSectionPremiumSearch),
                @"PPHomeSectionProviderCategoryNav" : @(PPHomeSectionProviderCategoryNav),
                @"PPHomeSectionMarketplaceHero" : @(PPHomeSectionMarketplaceHero),
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

    if (section == PPHomeSectionCurrentOrders) {
        return [self pp_shouldRenderCurrentOrdersSection];
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
    NSNumber *marketplaceHeroID = @(PPHomeSectionMarketplaceHero);
    if (![presentIDs containsObject:marketplaceHeroID]) {
        NSDictionary *marketplaceHeroRow = @{
            @"id" : marketplaceHeroID,
            @"visible" : @([self pp_defaultVisibilityForHomeSection:PPHomeSectionMarketplaceHero]),
            @"type" : @""
        };
        NSUInteger premiumSearchIndex =
            [merged indexOfObjectPassingTest:^BOOL(NSDictionary *row, NSUInteger idx, BOOL *stop) {
                (void)idx;
                (void)stop;
                return PPHomeSectionIDFromConfigValue(row[@"id"]) == PPHomeSectionPremiumSearch ||
                       PPHomeSectionIDFromConfigValue(row[@"type"]) == PPHomeSectionPremiumSearch;
            }];
        if (premiumSearchIndex != NSNotFound) {
            [merged insertObject:marketplaceHeroRow
                          atIndex:MIN(premiumSearchIndex + 1, merged.count)];
        } else {
            [merged insertObject:marketplaceHeroRow atIndex:0];
        }
        [presentIDs addObject:marketplaceHeroID];
    }

    NSNumber *providerCategoryNavID = @(PPHomeSectionProviderCategoryNav);
    if (![presentIDs containsObject:providerCategoryNavID]) {
        NSDictionary *providerCategoryNavRow = @{
            @"id" : providerCategoryNavID,
            @"visible" : @([self pp_defaultVisibilityForHomeSection:PPHomeSectionProviderCategoryNav]),
            @"type" : @""
        };
        NSUInteger marketplaceHeroIndex =
            [merged indexOfObjectPassingTest:^BOOL(NSDictionary *row, NSUInteger idx, BOOL *stop) {
                (void)idx;
                (void)stop;
                return PPHomeSectionIDFromConfigValue(row[@"id"]) == PPHomeSectionMarketplaceHero ||
                       PPHomeSectionIDFromConfigValue(row[@"type"]) == PPHomeSectionMarketplaceHero;
            }];
        if (marketplaceHeroIndex != NSNotFound) {
            [merged insertObject:providerCategoryNavRow
                          atIndex:MIN(marketplaceHeroIndex + 1, merged.count)];
        } else {
            NSUInteger premiumSearchIndex =
                [merged indexOfObjectPassingTest:^BOOL(NSDictionary *row, NSUInteger idx, BOOL *stop) {
                    (void)idx;
                    (void)stop;
                    return PPHomeSectionIDFromConfigValue(row[@"id"]) == PPHomeSectionPremiumSearch ||
                           PPHomeSectionIDFromConfigValue(row[@"type"]) == PPHomeSectionPremiumSearch;
                }];
            if (premiumSearchIndex != NSNotFound) {
                [merged insertObject:providerCategoryNavRow
                              atIndex:MIN(premiumSearchIndex + 1, merged.count)];
            } else {
                [merged insertObject:providerCategoryNavRow atIndex:0];
            }
        }
        [presentIDs addObject:providerCategoryNavID];
    }

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
             backgroundGlowsFaded:(BOOL)glowsFaded
                     novaUseGenkit:(BOOL)novaUseGenkit
                      useLegacyBar:(BOOL)useLegacyBar
{
    if (sections.count == 0) {
        return;
    }

    NSDictionary *payload = @{
        PPHomeConfigCacheSectionsKey : sections,
        PPHomeConfigCacheTitleModeKey : titleViewMode ?: @"location",
        PPHomeConfigCachePremiumCareVisibleKey : @(premiumCareVisible),
        PPHomeConfigCacheNovaFloatingVisibleKey : @(novaFloatingVisible),
        PPHomeConfigCacheBackgroundGlowsFadedKey : @(glowsFaded),
        PPHomeConfigCacheNovaUseGenkitKey : @(novaUseGenkit),
        PPHomeConfigCacheUseLegacyBarKey : @(useLegacyBar),
        @"BBUniversalCellUseSwiftUI" : @(YES)
    };
    [[NSUserDefaults standardUserDefaults] setObject:payload forKey:PPHomeConfigCacheKey];
    [[NSUserDefaults standardUserDefaults] setBool:novaFloatingVisible
                                            forKey:PPNovaFloatingVisibleDefaultsKey];
    [[NSUserDefaults standardUserDefaults] setBool:useLegacyBar forKey:@"PPUSE_LEGACY_BAR"];
    [[NSUserDefaults standardUserDefaults] setBool:BBUniversalCellUseSwiftUI forKey:@"BBUniversalCellUseSwiftUI"];
    [[NSUserDefaults standardUserDefaults] synchronize];

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

    BOOL glowsFaded = backgroundGlowsFaded;
    id cachedGlowsFaded = payload[PPHomeConfigCacheBackgroundGlowsFadedKey];
    if ([cachedGlowsFaded respondsToSelector:@selector(boolValue)]) {
        glowsFaded = [cachedGlowsFaded boolValue];
    }

    BOOL useLegacyBar = NO;
    id cachedUseLegacyBar = payload[PPHomeConfigCacheUseLegacyBarKey];
    if ([cachedUseLegacyBar respondsToSelector:@selector(boolValue)]) {
        useLegacyBar = [cachedUseLegacyBar boolValue];
    }
    [[NSUserDefaults standardUserDefaults] setBool:useLegacyBar forKey:@"PPUSE_LEGACY_BAR"];

    BOOL useSwiftUICells = YES;
    id cachedUseSwiftUICells = payload[@"BBUniversalCellUseSwiftUI"];
    if ([cachedUseSwiftUICells respondsToSelector:@selector(boolValue)]) {
        useSwiftUICells = [cachedUseSwiftUICells boolValue];
    }
    BBUniversalCellUseSwiftUI = useSwiftUICells;
    [[NSUserDefaults standardUserDefaults] setBool:useSwiftUICells forKey:@"BBUniversalCellUseSwiftUI"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    NSString *cachedMode = payload[PPHomeConfigCacheTitleModeKey];
    NSString *resolvedTitleViewMode = @"location";
    if ([cachedMode isKindOfClass:NSString.class] &&
        ([cachedMode isEqualToString:@"location"] || [cachedMode isEqualToString:@"search"])) {
        resolvedTitleViewMode = cachedMode;
    }

    self.homePremiumCareVisible = premiumCareVisible;
    self.backgroundGlowsFadedByHomeConfig = glowsFaded;
    self.homeTitleViewMode = resolvedTitleViewMode;
    self.homeConfigSections = [self pp_resolvedHomeConfigSectionsFromSanitizedSections:sanitized
                                                               legacyPremiumCareVisible:premiumCareVisible];
    self.didReceiveHomeConfig = YES;
    self.lastAppliedHomeConfigOrderSignature =
        [self pp_homeConfigOrderSignatureForSectionIdentifiers:[self pp_orderedHomeSectionIdentifiers]];

    [self pp_publishNovaFloatingVisibility:novaVisible];
    [self pp_updatePremiumBackgroundGlowAppearance];

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
    [self pp_installOrthogonalGestureGatesIfNeeded];

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
    // Until the Home controller is fully bootstrapped with section config and real data,
    // keep the snapshot empty to ensure all sections are hidden by default. This avoids
    // any initial flash of placeholder/incorrect sections on first launch.
    if (!self.isHomeBootstrapped) {
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

    NSLog(@"[Home] Sections in snapshot (%lu): %@", (unsigned long)sections.count,
          [sections componentsJoinedByString:@", "]);

    NSDiffableDataSourceSnapshot *existingSnapshot = self.dataSource ? self.dataSource.snapshot : nil;
    void (^safeAppend)(NSArray *, NSNumber *) = ^(NSArray *newItems, NSNumber *section) {
        if ([sections containsObject:section]) {
            NSArray *existingItems = @[];
            if (existingSnapshot && [existingSnapshot.sectionIdentifiers containsObject:section]) {
                existingItems = [existingSnapshot itemIdentifiersInSectionWithIdentifier:section];
            }
            NSArray *stableItems = [self pp_homeItemsByReusingExistingItems:existingItems
                                                                   newItems:newItems
                                                                    section:(PPHomeSection)section.integerValue];
            [snapshot appendItemsWithIdentifiers:stableItems intoSectionWithIdentifier:section];
        }
    };

    // ✅ Hero
    PPHomeItem *heroItem = [[PPHomeItem alloc] initWithType:PPHomeItemTypeHero payload:@"hero-card"];
    safeAppend(@[heroItem], @(PPHomeSectionHero));

    // ✅ Premium Search
    PPHomeItem *premiumSearchItem = [[PPHomeItem alloc] initWithType:PPHomeItemTypePremiumSearch payload:@"premium-search-card"];
    safeAppend(@[premiumSearchItem], @(PPHomeSectionPremiumSearch));

    // Marketplace Hero
    PPHomeItem *marketplaceHeroItem = [[PPHomeItem alloc] initWithType:PPHomeItemTypeMarketplaceHero payload:@"marketplace-hero-card"];
    safeAppend(@[marketplaceHeroItem], @(PPHomeSectionMarketplaceHero));

    // ✅ Provider Marketplace Navigation
    safeAppend([self pp_buildItemsForSection:PPHomeSectionProviderCategoryNav],
               @(PPHomeSectionProviderCategoryNav));

    // ✅ Quick Actions
    NSMutableArray<PPHomeItem *> *quickActions = [NSMutableArray array];
    for (PPHomeQuickActionModel *qa in [self pp_homeQuickActions]) {
        PPHomeItem *item = [PPHomeItem new];
        item.type = PPHomeItemTypeQuickActions;
        item.payload = qa;
        [quickActions addObject:item];
    }
    safeAppend(quickActions, @(PPHomeSectionQuickActions));

    // ✅ Current Orders
    NSArray *currentOrderItems = [self pp_homeCurrentOrderItems];
    NSLog(@"[Home] CurrentOrdersSection: visible=%@ items=%lu currentOrders=%lu loading=%d featured=%@",
          [sections containsObject:@(PPHomeSectionCurrentOrders)] ? @"YES" : @"NO",
          (unsigned long)currentOrderItems.count,
          (unsigned long)self.currentOrders.count,
          self.currentOrdersLoading,
          [self pp_featuredHomeOrder] ? @"yes" : @"nil");
    safeAppend(currentOrderItems, @(PPHomeSectionCurrentOrders));

    // ✅ Carousel
    PPHomeItem *carouselItem = [PPHomeItem new];
    carouselItem.type = PPHomeItemTypeCarousel;
    NSArray *cards = self.promoCarouselCards;
    if (cards.count == 0) cards = [self pp_homePromoFallbackCards];
    carouselItem.payload = cards.count > 0 ? cards : (id)[NSNull null];
    safeAppend(@[carouselItem], @(PPHomeSectionCarousel));

    // ✅ MainKinds
    NSMutableArray *kinds = [NSMutableArray array];
    for (MainKindsModel *k in [self pp_mainKindsRailDataSource]) {
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
        @(PPHomeSectionSuggestionAds),
        @(PPHomeSectionSuggestionAccessories),
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
    [self.dataSource applySnapshot:snapshot animatingDifferences:!isFirstContentApply];
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
    [self pp_positionInitialSelectedMainKindIfNeededAnimated:YES];
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
    [self pp_updateVisibleHomeHeaderScrollAppearanceAnimated:NO];
    [self pp_refreshVisibleHomeCardsForSections:@[
        @(PPHomeSectionPetProfile),
        @(PPHomeSectionPremiumSearch),
        @(PPHomeSectionMarketplaceHero),
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

                // Layout alone does NOT re-resolve dynamic CGColor borders (e.g.
                // PPUniversalCell card/image borders). When the theme toggles in-app,
                // already-visible cells keep their stale (light) border until reuse.
                // Ask theme-aware cells to re-resolve their colors for the current traits.
                if ([cell respondsToSelector:@selector(refreshThemeAppearance)]) {
                    [(id)cell refreshThemeAppearance];
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

- (void)pp_refreshVisibleHomeAppearanceForCurrentTheme
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pp_refreshVisibleHomeAppearanceForCurrentTheme];
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

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [UIView performWithoutAnimation:^{
        if (@available(iOS 13.0, *)) {
            self.collectionView.overrideUserInterfaceStyle = UIUserInterfaceStyleUnspecified;
        }

        [self.view pp_resolveLayerColorsRecursively];

        if (visibleIdentifiers.count > 0) {
            NSDiffableDataSourceSnapshot *snapshot = self.dataSource.snapshot;
            [self pp_reconfigureHomeItems:visibleIdentifiers inSnapshot:snapshot];
        }

        NSArray<NSString *> *themeRefreshSelectorNames = @[
            @"refreshThemeAppearance",
            @"pp_refreshThemeColors",
            @"pp_refreshAppearance",
            @"pp_applyTheme",
            @"pp_applyPalette",
            @"pp_applyThemeColors"
        ];

        for (UICollectionViewCell *cell in self.collectionView.visibleCells) {
            if (@available(iOS 13.0, *)) {
                cell.overrideUserInterfaceStyle = UIUserInterfaceStyleUnspecified;
            }

            for (NSString *selectorName in themeRefreshSelectorNames) {
                PPHomeInvokeVoidSelectorIfAvailable(cell, NSSelectorFromString(selectorName));
            }

            [cell pp_resolveLayerColorsRecursively];
            [cell setNeedsLayout];
            [cell.contentView setNeedsLayout];
            [cell.contentView layoutIfNeeded];
            [cell layoutIfNeeded];
        }

        for (UICollectionReusableView *header in
             [self.collectionView visibleSupplementaryViewsOfKind:UICollectionElementKindSectionHeader]) {
            if (@available(iOS 13.0, *)) {
                header.overrideUserInterfaceStyle = UIUserInterfaceStyleUnspecified;
            }

            for (NSString *selectorName in themeRefreshSelectorNames) {
                PPHomeInvokeVoidSelectorIfAvailable(header, NSSelectorFromString(selectorName));
            }

            [header pp_resolveLayerColorsRecursively];
            [header setNeedsLayout];
            [header layoutIfNeeded];
        }

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
    self.collectionView.contentOffset = CGPointMake(preservedOffset.x, targetOffsetY);
}

- (void)pp_refreshInitialHomeRevealDependentContent
{
    if (![self pp_isInitialHomeRevealSettled] || !self.isViewLoaded || !self.collectionView) {
        return;
    }

    [self pp_refreshVisibleHomeCardsForSections:@[
        @(PPHomeSectionPetProfile),
        @(PPHomeSectionPremiumSearch),
        @(PPHomeSectionMarketplaceHero),
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
    if (!PPHomeTemporarilyHideLeadingProfileItem) {
        PPHomeApplySemanticToViewTree(self.homeProfileItem.customView, semantic);
    }
    PPHomeApplySemanticToViewTree(self.homeCartButton, semantic);
    [self pp_refreshHomeLocationTitleViewAnimated:NO];

    for (UICollectionViewCell *cell in self.collectionView.visibleCells) {
        PPHomeApplySemanticToViewTree(cell, semantic);
    }

    for (UICollectionReusableView *header in
         [self.collectionView visibleSupplementaryViewsOfKind:UICollectionElementKindSectionHeader]) {
        PPHomeApplySemanticToViewTree(header, semantic);
    }
}

- (void)pp_refreshVisibleHomeHeadersForCurrentLanguage
{
    if (!self.isViewLoaded || !self.collectionView || !self.dataSource) {
        return;
    }

    NSArray<NSNumber *> *sectionIdentifiers = self.dataSource.snapshot.sectionIdentifiers ?: @[];
    __weak typeof(self) weakSelf = self;
    for (UICollectionReusableView *visibleHeader in
         [self.collectionView visibleSupplementaryViewsOfKind:UICollectionElementKindSectionHeader]) {
        if (![visibleHeader isKindOfClass:PPSectionHeaderView.class]) {
            PPHomeApplySemanticToViewTree(visibleHeader, PPHomeCurrentSemanticAttribute());
            continue;
        }

        NSIndexPath *indexPath = [self.collectionView indexPathForSupplementaryView:visibleHeader];
        if (!indexPath || indexPath.section >= (NSInteger)sectionIdentifiers.count) {
            continue;
        }

        PPSectionHeaderView *header = (PPSectionHeaderView *)visibleHeader;
        PPHomeSection section = (PPHomeSection)sectionIdentifiers[indexPath.section].integerValue;
        PPHomeHeaderConfig *cfg = [self headerConfigForSection:section];
        if (cfg.hidden) {
            header.hidden = YES;
            continue;
        }

        header.hidden = NO;
        [header configureWithTitle:cfg.title
                          subtitle:cfg.subtitle
                       actionTitle:cfg.actionTitle
                          iconName:cfg.iconName
                              menu:cfg.section == PPHomeSectionMainKinds ? nil : cfg.menu
                     ppHomeSection:cfg.section];
        [header setSurfaceDecorationActive:[self pp_shouldShowScrolledSectionHeaderDecoration] animated:NO];
        header.onTap = ^{
            __strong typeof(weakSelf) self = weakSelf;
            [self handleSeeAllForSection:cfg.section];
        };
        PPHomeApplySemanticToViewTree(header, PPHomeCurrentSemanticAttribute());
    }
}

- (BOOL)pp_shouldShowScrolledSectionHeaderDecoration
{
    return YES;
}

- (void)pp_updateVisibleHomeHeaderScrollAppearanceAnimated:(BOOL)animated
{
    if (!self.isViewLoaded || !self.collectionView) {
        return;
    }

    BOOL decorationActive = [self pp_shouldShowScrolledSectionHeaderDecoration];
    for (UICollectionReusableView *visibleHeader in
         [self.collectionView visibleSupplementaryViewsOfKind:UICollectionElementKindSectionHeader]) {
        if (![visibleHeader isKindOfClass:PPSectionHeaderView.class]) {
            continue;
        }
        [(PPSectionHeaderView *)visibleHeader setSurfaceDecorationActive:decorationActive animated:animated];
    }
}

- (void)pp_refreshLanguageSensitiveHomeContent
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pp_refreshLanguageSensitiveHomeContent];
        });
        return;
    }

    if (!self.isViewLoaded) {
        return;
    }

    self.needsVisibleHomeLanguageRefresh = NO;
    CGPoint preservedOffset = self.collectionView ? self.collectionView.contentOffset : CGPointZero;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [UIView performWithoutAnimation:^{
        [self pp_applyCurrentLanguageDirectionToHomeUI];
        if ([self pp_canOwnHomeNavigationChrome]) {
            [self configureNavigationBar];
        }
        [self refreshHeroSectionAppearance];
        [self pp_updateHomeSmartSearchPlaceholderAnimated:NO];
        [self pp_refreshHomeLocationTitleViewAnimated:NO];

        if (self.collectionView && self.dataSource) {
            NSDiffableDataSourceSnapshot *snapshot = self.dataSource.snapshot;
            if ([self pp_isSectionPresent:PPHomeSectionQuickActions inSnapshot:snapshot]) {
                [self reloadSection:PPHomeSectionQuickActions];
                snapshot = self.dataSource.snapshot;
            }
            NSArray<NSIndexPath *> *visibleIndexPaths = self.collectionView.indexPathsForVisibleItems ?: @[];
            NSMutableArray<PPHomeItem *> *visibleIdentifiers = [NSMutableArray arrayWithCapacity:visibleIndexPaths.count];
            for (NSIndexPath *indexPath in visibleIndexPaths) {
                PPHomeItem *item = [self.dataSource itemIdentifierForIndexPath:indexPath];
                if (item) {
                    [visibleIdentifiers addObject:item];
                }
            }
            if (visibleIdentifiers.count > 0) {
                [self pp_reconfigureHomeItems:visibleIdentifiers inSnapshot:self.dataSource.snapshot];
            }

            [self pp_refreshVisibleHomeHeadersForCurrentLanguage];
            [self.collectionView.collectionViewLayout invalidateLayout];
            [self.collectionView setNeedsLayout];
            [self.collectionView layoutIfNeeded];
        }

        [self pp_applyCurrentLanguageDirectionToHomeUI];
        [self setNeedsStatusBarAppearanceUpdate];
    }];
    [CATransaction commit];

    if (self.collectionView) {
        CGFloat minOffsetY = -self.collectionView.adjustedContentInset.top;
        CGFloat maxOffsetY = MAX(minOffsetY,
                                 self.collectionView.contentSize.height -
                                 CGRectGetHeight(self.collectionView.bounds) +
                                 self.collectionView.adjustedContentInset.bottom);
        CGFloat targetOffsetY = MIN(MAX(preservedOffset.y, minOffsetY), maxOffsetY);
        self.collectionView.contentOffset = CGPointMake(preservedOffset.x, targetOffsetY);
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

    [self pp_applyPremiumHomeBackgroundAppearance];
    if ([self pp_canOwnHomeNavigationChrome]) {
        [self configureNavigationBar];
    } else {
        [self pp_detachHomeSmartSearchTitleViewIfNeeded];
        [self pp_detachHomeLocationTitleViewIfNeeded];
    }
    [self refreshHeroSectionAppearance];
    [self setNeedsStatusBarAppearanceUpdate];

    [self pp_refreshVisibleHomeAppearanceForCurrentTheme];
    [self.collectionView.collectionViewLayout invalidateLayout];
    [self.collectionView setNeedsLayout];
    [self.collectionView layoutIfNeeded];

    NSInteger cartCount = [CartManager.sharedManager totalItemsCount];
    [self pp_applyHomeCartBadgeCount:cartCount animated:NO];
    [self pp_updateHomeCartButtonPresenceAnimated:NO];
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

    [self pp_applyPremiumHomeBackgroundAppearance];
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
    [self pp_updateHomeCartButtonPresenceAnimated:NO];
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
    [self reloadSection:PPHomeSectionSuggestionAds];
    [self reloadSection:PPHomeSectionSuggestionAccessories];
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

    if ([payload isKindOfClass:PPHomeProviderCategoryItem.class]) {
        PPHomeProviderCategoryItem *category = (PPHomeProviderCategoryItem *)payload;
        [parts addObject:[NSString stringWithFormat:@"provider-category:%@",
                          PPSafeString(category.identifier)]];
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
        section == PPHomeSectionMarketplaceHero ||
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

    NSMutableArray<PPHomeItem *> *fullReloadItems = [NSMutableArray array];
    NSMutableArray<PPHomeItem *> *reconfigureItems = [NSMutableArray array];
    for (PPHomeItem *item in items) {
        if (![item isKindOfClass:PPHomeItem.class]) {
            continue;
        }
        if ([self pp_homeItemRequiresFullReload:item]) {
            [fullReloadItems addObject:item];
        } else {
            [reconfigureItems addObject:item];
        }
    }

    if (reconfigureItems.count > 0) {
        if (@available(iOS 15.0, *)) {
            [snapshot reconfigureItemsWithIdentifiers:reconfigureItems];
        } else {
            [snapshot reloadItemsWithIdentifiers:reconfigureItems];
        }
    }

    if (fullReloadItems.count > 0) {
        [snapshot reloadItemsWithIdentifiers:fullReloadItems];
    }
    [self.dataSource applySnapshot:snapshot animatingDifferences:NO];
}

- (void)pp_reloadHomeItems:(NSArray<PPHomeItem *> *)items
                 inSnapshot:(NSDiffableDataSourceSnapshot *)snapshot
{
    if (items.count == 0 || !snapshot || !self.dataSource) {
        return;
    }

    [snapshot reloadItemsWithIdentifiers:items];
    [self.dataSource applySnapshot:snapshot animatingDifferences:NO];
}

- (BOOL)pp_homeItemRequiresFullReload:(PPHomeItem *)item
{
    if (![item isKindOfClass:PPHomeItem.class]) {
        return NO;
    }

    if (item.type == PPHomeItemTypeCarousel) {
        return YES;
    }

    id payload = item.payload;
    if (![payload isKindOfClass:NSArray.class]) {
        return NO;
    }

    NSArray *payloadArray = (NSArray *)payload;
    if (payloadArray.count == 0) {
        return NO;
    }

    return [payloadArray.firstObject isKindOfClass:PPHomePromoCarouselCard.class];
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
        case PPHomeSectionMarketplaceHero: {
            PPHomeItem *item = [[PPHomeItem alloc] initWithType:PPHomeItemTypeMarketplaceHero
                                                        payload:@"marketplace-hero-card"];
            [items addObject:item];
            break;
        }

        case PPHomeSectionProviderCategoryNav:
            if (PPHomeUseUnifiedProviderCategoryCard) {
                PPHomeItem *item = [[PPHomeItem alloc] initWithType:PPHomeItemTypeProviderCategoryNav
                                                            payload:[self pp_homeProviderUnifiedCategoryItems]];
                [items addObject:item];
            } else {
                for (PPHomeProviderCategoryItem *category in [self pp_homeProviderCategoryItems]) {
                    PPHomeItem *item = [[PPHomeItem alloc] initWithType:PPHomeItemTypeProviderCategoryNav
                                                                payload:category];
                    [items addObject:item];
                }
            }
            break;

        case PPHomeSectionQuickActions:
            for (PPHomeQuickActionModel *qa in [self pp_homeQuickActions]) {
                PPHomeItem *item = [PPHomeItem new];
                item.payload = qa;
                [items addObject:item];
            }
            break;

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
                vm.cellSection = CellSectionAccessories;
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

        case PPHomeSectionSuggestionAds: {
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
            break;
        }

        case PPHomeSectionSuggestionAccessories: {
            NSMutableSet<NSString *> *seen = [NSMutableSet set];
            NSDictionary *latestEvent =
                [[PPBrowseHistoryManager shared] latestEvent];
            NSArray<NSString *> *orderedAccessoryIDs =
                [self pp_buyAgainAccessoryIDsFromOrders:self.recentOrders
                                                  limit:MAX(PPBuyAgainVisibleLimit * 2, PPBuyAgainVisibleLimit)];

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
    // Prevent partial section reloads and layout updates until the Home controller is fully bootstrapped
    if (!self.isHomeBootstrapped) {
        return;
    }

    NSNumber *sectionIdentifier = @(section);
    CGPoint preservedOffset = CGPointZero;
    BOOL preserveOffset = (section == PPHomeSectionSuggestions || section == PPHomeSectionSuggestionAds || section == PPHomeSectionSuggestionAccessories);

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

        if (section == PPHomeSectionSuggestions || section == PPHomeSectionSuggestionAds || section == PPHomeSectionSuggestionAccessories) {
            self.lastHomeSuggestionsAppearanceSignature = [self pp_homeSuggestionsRefreshSignature];
        }

        if (section == PPHomeSectionPetProfile ||
            section == PPHomeSectionPremiumSearch ||
            section == PPHomeSectionMarketplaceHero ||
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

    if (section == PPHomeSectionBuyAgain ||
        section == PPHomeSectionCurrentOrders) {
        BOOL shouldRemoveDynamicSection =
            ![self pp_shouldRenderHomeSection:section] ||
            (section == PPHomeSectionCurrentOrders && newItems.count == 0);
        if (shouldRemoveDynamicSection) {
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
        section == PPHomeSectionSuggestionAds ||
        section == PPHomeSectionSuggestionAccessories ||
        section == PPHomeSectionAdsNearBy ||
        section == PPHomeSectionCurrentOrders ||
        section == PPHomeSectionPetProfile ||
        section == PPHomeSectionPremiumSearch ||
        section == PPHomeSectionMarketplaceHero ||
        section == PPHomeSectionPremiumCare ||
        section == PPHomeSectionAdopt ||
        section == PPHomeSectionAccessories ||
        section == PPHomeSectionLastFood ||
        section == PPHomeSectionMainKinds) {
        // 🔒 Prevent visual jumping on sections that fill from empty.
        animate = NO;
        if (section == PPHomeSectionSuggestions || section == PPHomeSectionSuggestionAds || section == PPHomeSectionSuggestionAccessories) {
            self.didFillSuggestionsOnce = YES;
        }
    }

    [self.dataSource applySnapshot:snapshot animatingDifferences:animate];
    if (section == PPHomeSectionSuggestions || section == PPHomeSectionSuggestionAds || section == PPHomeSectionSuggestionAccessories) {
        self.lastHomeSuggestionsAppearanceSignature = [self pp_homeSuggestionsRefreshSignature];
    }

    if (section == PPHomeSectionPetProfile ||
        section == PPHomeSectionPremiumSearch ||
        section == PPHomeSectionMarketplaceHero ||
        section == PPHomeSectionMainKinds ||
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
    [self pp_applyPremiumHomeBackgroundAppearance];

    self.mainKinds = PPMainKindsArray ?: @[];
    [self pp_applyInitialCategorySelectionIfNeeded];
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
    self.lastFoodLoaded = NO;
    self.isCurrentOrdersExpanded = NO;
    id storedPetProfileCardExpanded = [[NSUserDefaults standardUserDefaults] objectForKey:PPHomePetProfileCardExpandedKey];
    self.isPetProfileCardExpanded = storedPetProfileCardExpanded
        ? [[NSUserDefaults standardUserDefaults] boolForKey:PPHomePetProfileCardExpandedKey]
        : YES;
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
    self.novaFloatingVisibleByHomeConfig = [self pp_cachedNovaFloatingVisibility];
    self.backgroundGlowsFadedByHomeConfig = backgroundGlowsFaded;
    [self configureLocationStateMachine];



    [self setupCollectionView];
    [self pp_applyPremiumHomeBackgroundAppearance];
    [self pp_applyCurrentLanguageDirectionToHomeUI];
    [self configureDataSource];

    // 🏁 Production-grade First-Render Gate setup: restored to prevent flash/stacking
    self.isHomeBootstrapped = NO;
    self.bootstrapTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:4.0
                                                                   target:self
                                                                 selector:@selector(pp_bootstrapTimeoutFired)
                                                                 userInfo:nil
                                                                  repeats:NO];

    [self pp_applyCachedHomeConfigIfAvailable];
    [self applyBaseSnapshot];   // Will render empty snapshot initially since bootstrapped is NO
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
            [self pp_checkBootstrapStatus];
            return;
        }
        NSLog(@"[HomeConfig] Listener silent for 800ms — using default sections fallback.");
        self.homeConfigSections = [self pp_mergeHomeConfigSectionsWithCatalog:@[]];
        self.didReceiveHomeConfig = YES;
        self.lastAppliedHomeConfigOrderSignature =
            [self pp_homeConfigOrderSignatureForSectionIdentifiers:[self pp_orderedHomeSectionIdentifiers]];
        [self pp_publishNovaFloatingVisibility:YES];
        [self applyBaseSnapshot];
        [self pp_checkBootstrapStatus];
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
           selector:@selector(pp_handleSavedForLaterUpdatedNotification:)
               name:PPHomeSaveForLaterUpdatedNotificationName
             object:nil];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(handleAppWillEnterForeground)
               name:UIApplicationWillEnterForegroundNotification
             object:nil];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(handleAppDidEnterBackground)
               name:UIApplicationDidEnterBackgroundNotification
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

    // Root rebuild is still the primary language-change path, but Home also
    // refreshes visible cells/menus in place for iPad sessions where the
    // existing root remains alive long enough to display stale semantics.
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(handleLanguageDidChange:)
               name:PPHomeLanguageDidChangeNotification
              object:nil];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(handleThemePreferenceDidChange:)
               name:PPThemePreferenceDidChangeNotification
              object:nil];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(handleHomeAccessibilityAppearanceDidChange:)
               name:UIAccessibilityReduceMotionStatusDidChangeNotification
              object:nil];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(handleHomeAccessibilityAppearanceDidChange:)
               name:UIAccessibilityReduceTransparencyStatusDidChangeNotification
              object:nil];
}

#pragma mark - First-Render Gate Bootstrap System

- (void)pp_checkBootstrapStatus
{
    if (self.isHomeBootstrapped) {
        return;
    }

    BOOL configReady = self.didReceiveHomeConfig;
    BOOL dataReady = self.accessoriesLoaded &&
                     self.lastFoodLoaded &&
                     self.nearbyLoaded &&
                     self.nearbyServicesLoaded &&
                     self.petProfilesLoaded &&
                     self.currentOrdersLoaded;

    if (configReady && dataReady) {
        [self pp_revealHomeAtomic];
    }
}

- (void)pp_bootstrapTimeoutFired
{
    if (self.isHomeBootstrapped) {
        return;
    }
    self.bootstrapTimeoutTimer = nil;
    NSLog(@"[HomeBootstrap] ⚠️ Bootstrap watchdog fired. Keeping splash cover until real Home data is ready.");

    if (!self.didReceiveHomeConfig) {
        if ([self pp_applyCachedHomeConfigIfAvailable]) {
            NSLog(@"[HomeBootstrap] Applied cached HomeConfig while waiting for first complete data snapshot.");
        } else {
            self.homeConfigSections = [self pp_mergeHomeConfigSectionsWithCatalog:@[]];
            self.didReceiveHomeConfig = YES;
            self.lastAppliedHomeConfigOrderSignature =
                [self pp_homeConfigOrderSignatureForSectionIdentifiers:[self pp_orderedHomeSectionIdentifiers]];
            [self pp_publishNovaFloatingVisibility:YES];
            NSLog(@"[HomeBootstrap] Applied default HomeConfig while waiting for first complete data snapshot.");
        }
        [self applyBaseSnapshot];
    }

    [self pp_checkBootstrapStatus];
}

- (void)pp_revealHomeAtomic
{
    if (self.isHomeBootstrapped) {
        return;
    }
    self.isHomeBootstrapped = YES;

    if (self.bootstrapTimeoutTimer) {
        [self.bootstrapTimeoutTimer invalidate];
        self.bootstrapTimeoutTimer = nil;
    }

    NSLog(@"[HomeBootstrap] 🚀 Revealing Home atomically with final allowed sections!");

    // Build the first visible snapshot with real resolved data
    [self applyBaseSnapshot];
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    [self.collectionView setNeedsLayout];
    [self.collectionView layoutIfNeeded];

    if ([PPHUD isVisible]) {
        [PPHUD dismiss];
    }

    if (self.bootstrapOverlayView) {
        [UIView animateWithDuration:0.38
                              delay:0.1
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
            self.bootstrapOverlayView.alpha = 0.0;
            self.bootstrapSpinner.alpha = 0.0;
        } completion:^(BOOL finished) {
            [self.bootstrapOverlayView removeFromSuperview];
            self.bootstrapOverlayView = nil;
            [self.bootstrapSpinner removeFromSuperview];
            self.bootstrapSpinner = nil;
        }];
    }

    // Find and fade out the window-level splash cover view overlay
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = self.view.window;
        UIView *coverView = [window viewWithTag:99182];
        if (coverView) {
            coverView.frame = window.bounds;
            [window bringSubviewToFront:coverView];
            [UIView animateWithDuration:0.4
                                  delay:0.04
                                options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                coverView.alpha = 0.0;
            } completion:^(BOOL finished) {
                [coverView removeFromSuperview];
            }];
        }
    });
}

- (BOOL)pp_cachedNovaFloatingVisibility
{
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if ([defaults objectForKey:PPNovaFloatingVisibleDefaultsKey] != nil) {
        return [defaults boolForKey:PPNovaFloatingVisibleDefaultsKey];
    }

    NSDictionary *payload = [defaults dictionaryForKey:PPHomeConfigCacheKey];
    id cachedNovaVisible = payload[PPHomeConfigCacheNovaFloatingVisibleKey];
    if ([cachedNovaVisible respondsToSelector:@selector(boolValue)]) {
        return [cachedNovaVisible boolValue];
    }
    return YES;
}

- (void)pp_publishNovaFloatingVisibility:(BOOL)visible
{
    self.novaFloatingVisibleByHomeConfig = visible;
    [NSUserDefaults.standardUserDefaults setBool:visible
                                          forKey:PPNovaFloatingVisibleDefaultsKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:PPNovaFloatingVisibilityDidChangeNotification
                                                        object:self
                                                      userInfo:@{ PPNovaFloatingVisibilityValueKey : @(visible) }];
    [self pp_applyNovaFloatingHomeConfigVisibilityAnimated:YES];
}

- (void)pp_applyNovaFloatingHomeConfigVisibilityAnimated:(BOOL)animated
{
    UIButton *button = self.novaFloatingButton;
    UIView *halo = self.novaFloatingHaloView;
    if (!button && !halo) {
        return;
    }

    BOOL visible = self.novaFloatingVisibleByHomeConfig;
    if (!visible) {
        [self pp_stopNovaFloatingMotion];
    } else {
        button.hidden = NO;
        halo.hidden = NO;
    }

    button.userInteractionEnabled = visible;
    void (^changes)(void) = ^{
        button.alpha = visible ? 1.0 : 0.0;
        self.novaFloatingLottieView.alpha = visible ? 1.0 : 0.0;
        halo.alpha = visible ? 0.65 : 0.0;
    };
    void (^completion)(BOOL) = ^(__unused BOOL finished) {
        button.hidden = !visible;
        halo.hidden = !visible;
        if (visible) {
            [self pp_startNovaFloatingAmbientMotionIfNeeded];
        }
    };

    if (!animated) {
        changes();
        completion(YES);
        return;
    }

    [UIView animateWithDuration:PPAnimDurationFast
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:changes
                     completion:completion];
}

- (void)setupNovaFloatingButton
{
    self.novaFloatingVisibleByHomeConfig = [self pp_cachedNovaFloatingVisibility];
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
        [button.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12 ],
        [button.widthAnchor constraintEqualToConstant:54.0],
        [button.heightAnchor constraintEqualToConstant:54.0],

        [halo.centerXAnchor constraintEqualToAnchor:button.centerXAnchor],
        [halo.centerYAnchor constraintEqualToAnchor:button.centerYAnchor],
        [halo.widthAnchor constraintEqualToConstant:0.0],
        [halo.heightAnchor constraintEqualToConstant:0.0],

        [lot.centerXAnchor constraintEqualToAnchor:button.centerXAnchor],
        [lot.centerYAnchor constraintEqualToAnchor:button.centerYAnchor],
        [lot.widthAnchor constraintEqualToConstant:42.0],
        [lot.heightAnchor constraintEqualToConstant:42.0],
    ]];

    // Lottie loads from Firebase Storage path LottieAnimations/NovaHome.json via the project's helper.
    __weak typeof(self) weakSelf = self;
    __weak LOTAnimationView *weakLot = lot;
    [AppClasses setAnimationNamed:@"NovaHome"
                            ToView:lot
                         withSpeed:0.3
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

    [self pp_applyNovaFloatingHomeConfigVisibilityAnimated:NO];
}

- (void)pp_startNovaFloatingHaloBreathing
{
    UIView *halo = self.novaFloatingHaloView;
    if (!halo) { return; }

    [halo.layer removeAnimationForKey:@"pp_novaHaloBreath"];

    if (!self.novaFloatingVisibleByHomeConfig) {
        halo.alpha = 0.0;
        return;
    }

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
    if (!self.novaFloatingVisibleByHomeConfig) {
        [self pp_applyNovaFloatingHomeConfigVisibilityAnimated:NO];
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
        self.novaFloatingLottieView.animationSpeed = 0.4;
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
    if (!self.novaFloatingVisibleByHomeConfig || !button || button.hidden) {
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
    if (!self.novaFloatingVisibleByHomeConfig) {
        [self pp_applyNovaFloatingHomeConfigVisibilityAnimated:NO];
        return;
    }
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
    if (!self.novaFloatingVisibleByHomeConfig || self.novaFloatingButton.hidden) {
        return;
    }
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
    NSInteger maxKnownID = (NSInteger)PPHomeSectionSuggestionAccessories;

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

    BOOL isCacheSource = [source hasSuffix:@"cache"];
    if (isCacheSource && self.didApplyServerHomeConfig) {
        NSLog(@"[HomeConfig] Ignoring cached listener snapshot because server ordering is already active.");
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

    BOOL glowsFaded = backgroundGlowsFaded;
    id remoteGlowsFaded = data[@"backgroundGlowsFaded"];
    if ([remoteGlowsFaded respondsToSelector:@selector(boolValue)]) {
        glowsFaded = [remoteGlowsFaded boolValue];
    }

    BOOL novaUseGenkit = YES; // Force to YES as required by the code

    BOOL premiumCareVisible = YES;
    id remotePremiumCare = data[@"premiumCareVisible"];
    if ([remotePremiumCare respondsToSelector:@selector(boolValue)]) {
        premiumCareVisible = [remotePremiumCare boolValue];
    }

    BOOL useLegacyBar = NO;
    id remoteUseLegacyBar = data[@"PPUSE_LEGACY_BAR"];
    if ([remoteUseLegacyBar respondsToSelector:@selector(boolValue)]) {
        useLegacyBar = [remoteUseLegacyBar boolValue];
    }

    BOOL useSwiftUICells = YES;
    id remoteUseSwiftUICells = data[@"BBUniversalCellUseSwiftUI"];
    if ([remoteUseSwiftUICells respondsToSelector:@selector(boolValue)]) {
        useSwiftUICells = [remoteUseSwiftUICells boolValue];
    }

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        BBUniversalCellUseSwiftUI = useSwiftUICells;
        [[NSUserDefaults standardUserDefaults] setBool:useSwiftUICells forKey:@"BBUniversalCellUseSwiftUI"];

        NSString *previousSignature = strongSelf.lastAppliedHomeConfigOrderSignature ?: @"";
        if (previousSignature.length == 0 && strongSelf.dataSource) {
            previousSignature =
                [strongSelf pp_homeConfigOrderSignatureForSectionIdentifiers:strongSelf.dataSource.snapshot.sectionIdentifiers];
        }

        [strongSelf pp_publishNovaFloatingVisibility:novaVisible];

        strongSelf.homePremiumCareVisible = premiumCareVisible;
        BOOL glowModeChanged =
            strongSelf.backgroundGlowsFadedByHomeConfig != glowsFaded;
        strongSelf.backgroundGlowsFadedByHomeConfig = glowsFaded;
        [strongSelf pp_updatePremiumBackgroundGlowAppearance];

        NSArray<NSDictionary *> *merged =
            [strongSelf pp_resolvedHomeConfigSectionsFromSanitizedSections:sanitized
                                                    legacyPremiumCareVisible:premiumCareVisible];
        strongSelf.homeConfigSections = merged;
        [strongSelf pp_cacheHomeConfigSections:merged
                                 titleViewMode:resolvedTitleViewMode
                            premiumCareVisible:premiumCareVisible
                           novaFloatingVisible:novaVisible
                          backgroundGlowsFaded:glowsFaded
                                 novaUseGenkit:novaUseGenkit
                                  useLegacyBar:useLegacyBar];

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
        if (![source hasSuffix:@"cache"]) {
            strongSelf.didApplyServerHomeConfig = YES;
        }

        BOOL titleModeChanged =
            ![(strongSelf.homeTitleViewMode ?: @"location") isEqualToString:resolvedTitleViewMode];
        strongSelf.homeTitleViewMode = resolvedTitleViewMode;

        [strongSelf applyBaseSnapshot];
        if (glowModeChanged) {
            [strongSelf reloadSection:PPHomeSectionPetProfile];
        }

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
        [strongSelf pp_checkBootstrapStatus];
    });
}

- (void)handleBrowseHistoryUpdate

{
    [self reloadSection:PPHomeSectionSuggestions];
}

- (void)pp_refreshNavigationMenusForCurrentUser {
    if (PPHomeTemporarilyHideLeadingProfileItem) {
        return;
    }

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
    PPHomePrepareProfileMenuButton(profileButton, self);
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
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.leftBarButtonItems =
        PPHomeTemporarilyHideLeadingProfileItem ? @[] : PPHomeBarButtonItems(profileItem);
    [self refreshNavigationRightItemsForCartCount:cartCount];
    [self pp_applyHomeCartBadgeCount:cartCount animated:NO];
    [self pp_updateHomeCartButtonPresenceAnimated:NO];
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
    if ([statusKey isEqualToString:@"pending"]) {
        return kLang(@"order_placed_title") ?: kLang(@"Pending");
    }
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
    return PPOrderStatusAccentColorForKey([self pp_homeOrderStatusKey:order]);
}

- (NSString *)pp_homeOrderStatusIconName:(PPOrder *)order
{
    return PPOrderStatusSymbolNameForKey([self pp_homeOrderStatusKey:order]);
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
        NSLog(@"[Home][Orders] featured candidate: orderId=%@ statusKey=%@", order.orderId ?: @"nil", [self pp_homeOrderStatusKey:order] ?: @"nil");

        if ([self pp_shouldHideTerminalHomeOrder:order]) {
            NSLog(@"[Home][Orders] featured=HIDDEN (terminal)");
            return nil;
        }

        if ([self pp_isActiveHomeOrder:order]) {
            NSLog(@"[Home][Orders] featured=ACTIVE");
            return order;
        }
        NSLog(@"[Home][Orders] featured=INACTIVE");
    } else {
        NSLog(@"[Home][Orders] featured=nil — currentOrders empty or firstObject not PPOrder");
    }

    return nil;
}

- (BOOL)pp_shouldRenderCurrentOrdersSection
{
    return [self pp_featuredHomeOrder] != nil;
}

- (NSArray<PPHomeItem *> *)pp_homeCurrentOrderItems
{
    NSMutableArray<PPHomeItem *> *items = [NSMutableArray array];
    PPOrder *featuredOrder = [self pp_featuredHomeOrder];

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

- (NSArray<PetAccessory *> *)pp_lastFoodItemsFromSource:(NSArray<PetAccessory *> *)source
{
    NSMutableArray<PetAccessory *> *foodItems = [NSMutableArray array];
    for (PetAccessory *accessory in source ?: @[]) {
        if (![accessory isKindOfClass:PetAccessory.class]) continue;
        if (accessory.accessKindType == AccessTypeFood) {
            [foodItems addObject:accessory];
        }
    }

    // Sort by createdAt descending (newest first)
    [foodItems sortUsingComparator:^NSComparisonResult(PetAccessory *a, PetAccessory *b) {
        NSDate *aDate = a.createdAt ?: [NSDate distantPast];
        NSDate *bDate = b.createdAt ?: [NSDate distantPast];
        NSComparisonResult dateOrder = [bDate compare:aDate];
        if (dateOrder != NSOrderedSame) return dateOrder;

        NSString *aID = PPSafeString(a.accessoryID);
        NSString *bID = PPSafeString(b.accessoryID);
        return [aID compare:bID options:NSCaseInsensitiveSearch];
    }];

    // Limit to visible count
    if (foodItems.count > PPLastFoodVisibleLimit) {
        [foodItems removeObjectsInRange:NSMakeRange(PPLastFoodVisibleLimit,
                                                     foodItems.count - PPLastFoodVisibleLimit)];
    }

    return foodItems.copy;
}

- (void)pp_applyLastFoodItems:(NSArray<PetAccessory *> *)items
{
    self.lastFoodAccessories = [self pp_lastFoodItemsFromSource:items];
    [self reloadSection:PPHomeSectionLastFood];
}

- (void)pp_refreshLastFoodSection
{
    [self pp_applyLastFoodItems:self.accessories ?: @[]];
}

- (void)pp_fetchLastFoodSection
{
    __weak typeof(self) weakSelf = self;
    [[PetAccessoryManager sharedManager] fetchFoodForAllMainKinds:^(NSArray<PetAccessory *> *foods) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self.lastFoodLoaded = YES;
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            [self pp_applyLastFoodItems:foods ?: @[]];
            [CATransaction commit];
            [self tryApplySnapshot];
            [self pp_checkBootstrapStatus];
        });
    }];
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
            BOOL shouldUseNormalNoStockMode =
                accessory.quantity <= 0 &&
                accessory.showInAppMarket &&
                !accessory.isDeleted &&
                !accessory.isBlocked &&
                !accessory.isDisabled;
            if (accessory.quantity > 0 || shouldUseNormalNoStockMode) {
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

- (void)pp_applyUnavailableBuyAgainCoverToCell:(UICollectionViewCell *)cell
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
        configuration.baseBackgroundColor = [UIColor clearColor];
        configuration.baseForegroundColor = AppPrimaryClr ?: UIColor.systemPinkColor;
        configuration.contentInsets = NSDirectionalEdgeInsetsMake(7.0, 12.0, 7.0, 12.0);
        configuration.image = [UIImage systemImageNamed:Language.isRTL ? @"chevron.left" : @"chevron.right"];
        configuration.imagePlacement = NSDirectionalRectEdgeTrailing;
        configuration.imagePadding = 5.0;

        UIBackgroundConfiguration *bgConfig = [UIBackgroundConfiguration clearConfiguration];
        bgConfig.visualEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
        bgConfig.cornerRadius = 16.0;
        bgConfig.strokeColor = [[UIColor whiteColor] colorWithAlphaComponent:0.18];
        bgConfig.strokeWidth = 1.0;
        configuration.background = bgConfig;

        configuration.attributedTitle = [[NSAttributedString alloc] initWithString:kLang(@"Home_BuyAgainDiscoverSimilars")
                                                              attributes:@{
            NSFontAttributeName: [GM boldFontWithSize:12],
            NSForegroundColorAttributeName: AppPrimaryClr ?: UIColor.systemPinkColor
        }];

        button.configuration = configuration;
    } else {
        [button setTitle:kLang(@"Home_BuyAgainDiscoverSimilars") ?: @""
                forState:UIControlStateNormal];
        button.titleLabel.font = [GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
        button.contentEdgeInsets = UIEdgeInsetsMake(7.0, 12.0, 7.0, 12.0);
        button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
        [button setTitleColor:(AppPrimaryClr ?: UIColor.systemPinkColor) forState:UIControlStateNormal];
        button.layer.borderWidth = 1.0;
        button.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.18].CGColor;
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

    CGFloat contentHeight = CGRectGetHeight(cell.contentView.bounds);
    CGFloat coverTopInset = contentHeight > 1.0
        ? MAX(86.0, MIN(156.0, floor(contentHeight * 0.44)))
        : 112.0;

    [cell.contentView addSubview:cover];
    [NSLayoutConstraint activateConstraints:@[
        [cover.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:coverTopInset],
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
        [self pp_checkBootstrapStatus];
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
    NSLog(@"[Home][CurrentOrders] started listener userID=%@ requestToken=%ld force=%d", userID, (long)requestToken, force);
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
                [self pp_checkBootstrapStatus];
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

    NSLog(@"[Home][CurrentOrders] snapshot received: total=%lu active=%lu featured=%@",
          (unsigned long)recentOrders.count,
          (unsigned long)resolvedOrders.count,
          [self pp_featuredHomeOrder] ? @"yes" : @"nil");

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
    [self pp_checkBootstrapStatus];
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
        picker.view.layer.cornerRadius = 42;
        [PPFunc presentFloatingSheetFrom:self sheetVC:picker detentStyle:PPSheetDetentStyle80];
        //UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:picker];
        //[self presentViewController:nav animated:YES completion:nil];
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

    [PPFunc presentFloatingSheetFrom:self sheetVC:sheet detentStyle:PPSheetDetentStyle80 withCompletion:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.isPresentingHomeLocationSheet = NO;
    }];

   /*
    [self presentViewController:sheet
                       animated:YES
                     completion:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.isPresentingHomeLocationSheet = NO;
    }];
    */
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
    BOOL appliedCachedHomeConfig = [self pp_applyCachedHomeConfigIfAvailable];
    if (appliedCachedHomeConfig) {
        [self applyBaseSnapshot];
    }
    [self pp_startHomeConfigListener];

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
    if (self.isHomeScreenVisible) {
        [self pp_beginPremiumBackgroundGlowMotionIfNeeded];
    }
}

- (void)handleAppDidEnterBackground
{
    [self pp_stopPremiumBackgroundGlowMotion];
}

- (void)handleThemePreferenceDidChange:(NSNotification *)notification
{
    (void)notification;
    self.needsVisibleHomeThemeAppearanceRefresh = YES;
    [self pp_refreshThemeSensitiveHomeContent];
    [self pp_forceHomeCollectionLayoutRefresh];
}

- (void)handleHomeAccessibilityAppearanceDidChange:(NSNotification *)notification
{
    (void)notification;
    [self pp_updatePremiumBackgroundGlowAppearance];
    if ([self pp_shouldReduceHomeMotion]) {
        [self pp_stopPremiumBackgroundGlowMotion];
    } else if (self.isHomeScreenVisible) {
        [self pp_beginPremiumBackgroundGlowMotionIfNeeded];
    }
}

- (void)handleLanguageDidChange:(NSNotification *)notification
{
    (void)notification;
    self.needsVisibleHomeLanguageRefresh = YES;
    [self pp_refreshLanguageSensitiveHomeContent];
    [self pp_stopPremiumBackgroundGlowMotion];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self pp_layoutPremiumBackgroundGlowViews];
        [self pp_beginPremiumBackgroundGlowMotionIfNeeded];
    });
}

- (void)handleAdUploadCompletedNotification:(NSNotification *)notification
{
    [self refreshNearbyAdsForce:YES reason:@"ad-upload"];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.isHomeScreenVisible = YES;
    [self pp_beginPremiumBackgroundGlowMotionIfNeeded];
    [self pp_startHomeSmartSearchTimerIfNeeded];
    [self pp_advancePremiumCareAnimationForAppearance];
    [self pp_beginPremiumHomeEntranceIfNeeded];
    if ([self pp_isInitialHomeRevealSettled]) {
        [self pp_stabilizeHomeCollectionLayoutIfNeeded];
    }
    [self pp_positionInitialSelectedMainKindIfNeededAnimated:YES];
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
    [self pp_updateVisibleHomeHeaderScrollAppearanceAnimated:NO];
    if (self.needsVisibleHomeThemeAppearanceRefresh) {
        self.needsVisibleHomeThemeAppearanceRefresh = NO;
        [self pp_refreshVisibleHomeAppearanceForCurrentTheme];
    }
    if (self.needsVisibleHomeLanguageRefresh) {
        [self pp_refreshLanguageSensitiveHomeContent];
    }
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

    [[NovaAmbientAssistantCoordinator sharedCoordinator] screenDidAppearInViewController:self
                                                                                 screen:@"home"];
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
        case PPHomeSectionProviderCategoryNav:
            cfg.hidden = YES;
            break;

        case PPHomeSectionSuggestions: {
            cfg.hidden = NO;
            cfg.title = kLang(@"home_header_picks_for_you") ?: kLang(@"SuggestedForYou");
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

        case PPHomeSectionSuggestionAds: {
            cfg.hidden = NO;
            NSString *titlePrefix = kLang(@"home_header_picks_for_you") ?: kLang(@"SuggestedForYou");
            NSString *typeSuffix = kLang(@"BrowseType_Ads") ?: @"Ads";
            cfg.title = [NSString stringWithFormat:@"%@ - %@", titlePrefix, typeSuffix];
            cfg.iconName = arrowImage;
            cfg.subtitle = kLang(@"RecommendedForYouHint");

            NSDictionary *event = [[PPBrowseHistoryManager shared] latestEvent];
            if (event) {
                NSInteger kindID = [event[@"kind"] integerValue];
                MainKindsModel *kind = [self resolveMainKindWithID:kindID];
                if (kind) {
                    cfg.subtitle = [NSString stringWithFormat:kLang(@"BecauseYouViewedFormat"), typeSuffix, kind.KindName];
                }
            }
            break;
        }

        case PPHomeSectionSuggestionAccessories: {
            cfg.hidden = NO;
            NSString *titlePrefix = kLang(@"home_header_picks_for_you") ?: kLang(@"SuggestedForYou");
            NSString *typeSuffix = kLang(@"BrowseType_Accessories") ?: @"Accessories";
            cfg.title = [NSString stringWithFormat:@"%@ - %@", titlePrefix, typeSuffix];
            cfg.iconName = arrowImage;
            cfg.subtitle = kLang(@"RecommendedForYouHint");

            NSDictionary *event = [[PPBrowseHistoryManager shared] latestEvent];
            if (event) {
                NSInteger kindID = [event[@"kind"] integerValue];
                MainKindsModel *kind = [self resolveMainKindWithID:kindID];
                if (kind) {
                    cfg.subtitle = [NSString stringWithFormat:kLang(@"BecauseYouViewedFormat"), typeSuffix, kind.KindName];
                }
            }
            break;
        }

        case PPHomeSectionCurrentOrders: {
            cfg.hidden = !self.isCurrentOrdersExpanded ||
                         ![self pp_shouldRenderCurrentOrdersSection];
            cfg.title = kLang(@"home_header_most_requested") ?: kLang(@"Home_LastOrderTitle");
            cfg.subtitle = kLang(@"Home_LastOrderSubtitle");
            cfg.actionTitle = kLang(@"OrderHistory");
            cfg.iconName = arrowImage;
            break;
        }

        case PPHomeSectionMainKinds:
        {
            cfg.hidden = NO;
            cfg.title = kLang(@"home_header_discover_by_category") ?: kLang(@"MainCategories");
            cfg.actionTitle = self.isMainKindsExpanded
                ? (kLang(@"ShowLess") ?: @"Show less")
                : (kLang(@"ShowAll") ?: @"Show all");

            cfg.iconName = self.isMainKindsExpanded
                ? @"chevron.up"
                : @"chevron.down";

            cfg.menu = nil; // IMPORTANT – header tap controls layout
            break;
        }

        case PPHomeSectionAccessories: {
            cfg.hidden = NO;
            cfg.title = kLang(@"home_header_featured_products") ?: kLang(@"Accessories");
            cfg.actionTitle = kLang(@"home_accessories_refine") ?: @"Refine";
            cfg.iconName = arrowImage;
            cfg.menu = nil;
            break;
        }

        case PPHomeSectionAdsNearBy: {
            cfg.hidden = NO;
            if (self.nearbyShowingRecentlyAdded) {
                cfg.title = kLang(@"home_header_most_popular") ?: kLang(@"Home_RecentlyAdded") ?: @"Recently Added";
            } else {
                cfg.title = kLang(@"home_header_near_you") ?: kLang(@"Home_NearbyAds");
            }
            cfg.subtitle = kLang(@"Home_NearbyAdsSubtitle") ?: @"Premium";
            cfg.iconName = arrowImage;
            break;
        }

        case PPHomeSectionNearbyServices: {
            cfg.hidden = (self.nearbyServiceProviders.count == 0 && !self.nearbyServicesLoading);
            if (self.nearbyServicesShowingLatest) {
                cfg.title = kLang(@"home_header_most_requested") ?: kLang(@"Home_ServiceProviders") ?: @"Service Providers";
            } else {
                cfg.title = kLang(@"Home_NearbyServiceProviders") ?: kLang(@"home_header_near_you") ?: @"Nearby Services Providers";
            }
            cfg.subtitle = kLang(@"Home_ServiceProvidersSubtitle") ?: @"Find grooming, training & more";
            cfg.iconName = arrowImage;
            break;
        }

        case PPHomeSectionLastFood: {
            cfg.hidden = self.lastFoodAccessories.count == 0;
            cfg.title = kLang(@"home_header_featured_products") ?: kLang(@"Home_LastFoodAdded") ?: @"Last Food Added";
            cfg.subtitle = kLang(@"Home_LastFoodSubtitle") ?: @"Recently added pet food";
            cfg.iconName = arrowImage;
            break;
        }

        case PPHomeSectionBuyAgain: {
            cfg.hidden = self.buyAgainEntries.count == 0;
            cfg.title = kLang(@"home_header_picks_for_you") ?: kLang(@"Home_BuyAgainTitle");
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

- (void)pp_installOrthogonalGestureGateOnScrollView:(UIScrollView *)scrollView
{
    if (objc_getAssociatedObject(scrollView, &PPHomeOrthogonalPanGateAssociationKey)) {
        return;
    }

    UIPanGestureRecognizer *gatePan =
        [[UIPanGestureRecognizer alloc] initWithTarget:self
                                               action:@selector(pp_handleOrthogonalPanGate:)];
    gatePan.delegate = self;
    gatePan.cancelsTouchesInView = NO;
    gatePan.delaysTouchesBegan = NO;
    gatePan.delaysTouchesEnded = NO;

    [scrollView addGestureRecognizer:gatePan];
    [scrollView.panGestureRecognizer requireGestureRecognizerToFail:gatePan];
    objc_setAssociatedObject(gatePan,
                             &PPHomeOrthogonalPanGateMarkerKey,
                             @YES,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(scrollView,
                             &PPHomeOrthogonalPanGateAssociationKey,
                             @YES,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)pp_handleOrthogonalPanGate:(UIPanGestureRecognizer *)panGestureRecognizer
{
    // Direction arbitration happens in gestureRecognizerShouldBegin:.
}

- (void)pp_installOrthogonalGestureGatesBelowView:(UIView *)view
{
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:UICollectionViewCell.class]) {
            continue;
        }

        if ([subview isKindOfClass:UIScrollView.class]) {
            UIScrollView *scrollView = (UIScrollView *)subview;
            UIEdgeInsets inset = scrollView.adjustedContentInset;
            CGFloat contentWidth = scrollView.contentSize.width + inset.left + inset.right;
            BOOL hasHorizontalRange =
                scrollView.alwaysBounceHorizontal ||
                contentWidth > CGRectGetWidth(scrollView.bounds) + 1.0;

            if (scrollView != self.collectionView &&
                scrollView.scrollEnabled &&
                hasHorizontalRange) {
                [self pp_installOrthogonalGestureGateOnScrollView:scrollView];
            }
        }

        [self pp_installOrthogonalGestureGatesBelowView:subview];
    }
}

- (void)pp_installOrthogonalGestureGatesIfNeeded
{
    if (!self.collectionView) {
        return;
    }
    [self pp_installOrthogonalGestureGatesBelowView:self.collectionView];
}

- (void)setupCollectionView {
    if (self.collectionView) {
        return;
    }

    self.layoutManager =
        [[PPHomeLayoutManager alloc] initWithMainKindsExpanded:self.isMainKindsExpanded];
    self.layoutManager.isCurrentOrdersExpanded = self.isCurrentOrdersExpanded;
    self.layoutManager.isPetProfileExpanded = self.isPetProfileCardExpanded;

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
         [self.collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-0]
    ]];

    [self.collectionView registerClass:PPHomeHeroCell.class
            forCellWithReuseIdentifier:PPHomeHeroCell.reuseIdentifier];
    [self.collectionView registerClass:PPHomeOrderStatusCell.class
            forCellWithReuseIdentifier:PPHomeOrderStatusCell.reuseIdentifier];
    [self.collectionView registerClass:PPCategoryCardCell.class forCellWithReuseIdentifier:PPCategoryCardCell.reuseIdentifier];
    [PPUniversalCell pp_registerInCollectionView:self.collectionView];
    [self.collectionView registerClass:PPMainKindsCell.class
            forCellWithReuseIdentifier:PPMainKindsCell.reuseIdentifier];
    [self.collectionView registerClass:PPModernHomeActionCell.class
            forCellWithReuseIdentifier:PPModernHomeActionCell.reuseIdentifier];
     [self.collectionView registerClass:PPHomePetProfileCardCell.class
            forCellWithReuseIdentifier:PPHomePetProfileCardCell.reuseIdentifier];
    if (PPULTRA_CARE_IS_ACTIVATED) {
        [self.collectionView registerClass:PPHomeUltraPremuimPetCareCell.class
                forCellWithReuseIdentifier:PPHomeUltraPremuimPetCareCell.reuseIdentifier];
    } else {
        [self.collectionView registerClass:PPHomePremiumCareCell.class
                forCellWithReuseIdentifier:PPHomePremiumCareCell.reuseIdentifier];
    }
    [self.collectionView registerClass:PPHomePremiumSearchCell.class
            forCellWithReuseIdentifier:@"PPHomePremiumSearchCell"];
    [self.collectionView registerClass:PPHomeMarketplaceHeroCell.class
            forCellWithReuseIdentifier:PPHomeMarketplaceHeroCell.reuseIdentifier];
    [self.collectionView registerClass:PPHomeUltraPremuimProviderCategoryPillCell.class
            forCellWithReuseIdentifier:PPHomeUltraPremuimProviderCategoryPillCell.reuseIdentifier];
    [self.collectionView registerClass:PPHomeProviderUnifiedCategoryCardCell.class
            forCellWithReuseIdentifier:PPHomeProviderUnifiedCategoryCardCell.reuseIdentifier];


    [self.collectionView registerClass:PPCarouselContainerCell.class forCellWithReuseIdentifier:@"PPCarouselContainerCell"];
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

    [self pp_reloadHomeItems:items inSnapshot:snapshot];
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
            UICollectionViewCell *fallbackCell = [collectionView dequeueReusableCellWithReuseIdentifier:PPUniversalCell.reuseIdentifier
                                                             forIndexPath:indexPath];
            fallbackCell.alpha = 0.0;
            return fallbackCell;
        }

        // ── Born-hidden entrance gate ──────────────────────────────────
        // Every cell the provider returns is born invisible when the
        // premium entrance animation hasn't fired yet. The staggered
        // entrance system (pp_animateHomeEntranceForCell / horizontal
        // universal) will reveal each cell with its proper delay &
        // spring. After the first entrance settles, cells appear
        // normally so scrolling and reconfiguration are unaffected.
        BOOL shouldStageForEntrance = !strongSelf.didRunPremiumHomeEntranceAnimation &&
                                      ![strongSelf pp_shouldReduceHomeMotion];

        // Inline staging block — sets a cell to its pre-entrance hidden
        // state (alpha 0, slight translateY + scale) so it never flashes
        // at full opacity before the staggered entrance animation fires.
        void (^pp_stageCell)(UICollectionViewCell *) = ^(UICollectionViewCell *cell) {
            if (!shouldStageForEntrance || !cell) return;
            cell.alpha = 0.0;
            cell.transform = CGAffineTransformConcat(
                CGAffineTransformMakeTranslation(0.0, 7.0),
                CGAffineTransformMakeScale(0.996, 0.996));
        };

        PPHomeSection section = [strongSelf sectionTypeForIndexPath:indexPath];

        if (section == PPHomeSectionHero) {
            PPHomeHeroCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:PPHomeHeroCell.reuseIdentifier
                                                          forIndexPath:indexPath];
            [strongSelf pp_configureHeroCell:cell];
            pp_stageCell(cell); return cell;
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
            pp_stageCell(cell); return cell;
        }

        if (section == PPHomeSectionCurrentOrders) {
            PPHomeOrderStatusCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:PPHomeOrderStatusCell.reuseIdentifier
                                                          forIndexPath:indexPath];
            BOOL expanded = strongSelf.isCurrentOrdersExpanded;

            if (item.payload == [NSNull null] || ![item.payload isKindOfClass:PPOrder.class]) {
                [cell configurePlaceholderExpanded:expanded];
                pp_stageCell(cell); return cell;
            }

            PPOrder *order = (PPOrder *)item.payload;
            [cell configureWithOrderReference:[order displayOrderReference]
                             orderKickerTitle:[strongSelf pp_homeOrderKickerTitle:order]
                              previewImageURLs:[strongSelf pp_homeOrderPreviewImageURLs:order limit:3]
                                         meta:[strongSelf pp_homeOrderMetaText:order]
                                  statusTitle:[strongSelf pp_homeOrderStatusTitle:order]
                                   statusHint:[strongSelf pp_homeOrderStatusHint:order]
                                    statusKey:[strongSelf pp_homeOrderStatusKey:order]
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
            pp_stageCell(cell); return cell;
        }

        if (section == PPHomeSectionPetProfile) {
            PPHomePetProfileCardCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:PPHomePetProfileCardCell.reuseIdentifier
                                                          forIndexPath:indexPath];
            [cell configureWithDefaultPet:strongSelf.defaultPetProfile
                                 petCount:strongSelf.petProfiles.count
                                isLoading:strongSelf.petProfilesLoading
                                 expanded:strongSelf.isPetProfileCardExpanded
                       backgroundGlowsFaded:strongSelf.backgroundGlowsFadedByHomeConfig];
            __weak typeof(strongSelf) weakHome = strongSelf;
            cell.onToggleExpanded = ^(BOOL expanded) {
                __strong typeof(weakHome) home = weakHome;
                if (!home) return;
                [home pp_setPetProfileCardExpanded:expanded animated:YES];
            };
            pp_stageCell(cell); return cell;
        }

            if ( section == PPHomeSectionPremiumSearch) {
                PPHomePremiumSearchCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:@"PPHomePremiumSearchCell"
                                                              forIndexPath:indexPath];
                [cell setQueryText:[strongSelf pp_currentHomeSmartSearchPlaceholder]
                          animated:NO];

                __weak typeof(strongSelf) weakHome = strongSelf;
                cell.onTap = ^{
                    __strong typeof(weakHome) self = weakHome;
                    if (!self) return;
                    [self pp_openSmartSearch];
                };

	                pp_stageCell(cell); return cell;
	            }

        if (section == PPHomeSectionMarketplaceHero) {
            PPHomeMarketplaceHeroCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:PPHomeMarketplaceHeroCell.reuseIdentifier
                                                          forIndexPath:indexPath];
            [cell configureWithMainKind:strongSelf.selectedCategory animated:NO];

            __weak typeof(strongSelf) weakHome = strongSelf;
            cell.onTap = ^{
                __strong typeof(weakHome) self = weakHome;
                if (!self) return;
                [self pp_openMarketplaceProvidersListFromHero];
            };

            pp_stageCell(cell); return cell;
        }

        if (section == PPHomeSectionProviderCategoryNav) {
            if (PPHomeUseUnifiedProviderCategoryCard) {
                PPHomeProviderUnifiedCategoryCardCell *cell =
                    [collectionView dequeueReusableCellWithReuseIdentifier:PPHomeProviderUnifiedCategoryCardCell.reuseIdentifier
                                                              forIndexPath:indexPath];
                NSArray<PPHomeProviderCategoryItem *> *providerItems =
                    [item.payload isKindOfClass:NSArray.class]
                    ? (NSArray<PPHomeProviderCategoryItem *> *)item.payload
                    : [strongSelf pp_homeProviderUnifiedCategoryItems];
                PPHomeProviderCategoryItem *leftItem = providerItems.count > 0 ? providerItems[0] : nil;
                PPHomeProviderCategoryItem *rightItem = providerItems.count > 1 ? providerItems[1] : nil;
                [cell configureWithLeftItem:leftItem rightItem:rightItem];

                __weak typeof(strongSelf) weakHome = strongSelf;
                cell.onTap = ^(PPHomeProviderCategoryItem *selectedItem) {
                    __strong typeof(weakHome) self = weakHome;
                    if (!self) return;
                    [self pp_handleProviderCategorySelection:selectedItem];
                };

                pp_stageCell(cell); return cell;
            }

            PPHomeUltraPremuimProviderCategoryPillCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:PPHomeUltraPremuimProviderCategoryPillCell.reuseIdentifier
                                                          forIndexPath:indexPath];

            PPHomeProviderCategoryItem *categoryItem =
                [item.payload isKindOfClass:PPHomeProviderCategoryItem.class]
                ? (PPHomeProviderCategoryItem *)item.payload
                : [strongSelf pp_homeProviderCategoryItems].firstObject;

            [cell configureWithItem:categoryItem selected:NO];

            __weak typeof(strongSelf) weakHome = strongSelf;
            cell.onTap = ^(PPHomeProviderCategoryItem *selectedItem) {
                __strong typeof(weakHome) self = weakHome;
                if (!self) return;
                [self pp_handleProviderCategorySelection:selectedItem];
            };

            pp_stageCell(cell); return cell;
        }

        if ( section == PPHomeSectionPremiumCare) {
            if (PPULTRA_CARE_IS_ACTIVATED) {
                PPHomeUltraPremuimPetCareCell *cell =
                    [collectionView dequeueReusableCellWithReuseIdentifier:PPHomeUltraPremuimPetCareCell.reuseIdentifier
                                                              forIndexPath:indexPath];
                [cell configureWithAnimationName:[strongSelf pp_currentPremiumCareAnimationName]];
                pp_stageCell(cell); return cell;
            }

            PPHomePremiumCareCell *legacyCell =
                [collectionView dequeueReusableCellWithReuseIdentifier:PPHomePremiumCareCell.reuseIdentifier
                                                          forIndexPath:indexPath];
            [legacyCell configureWithAnimationName:[strongSelf pp_currentPremiumCareAnimationName]];
            pp_stageCell(legacyCell); return legacyCell;
        }

        if (section == PPHomeSectionCarousel) {

            PPBannerCollectionCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:PPBannerCollectionCell.reuseIdentifier
                                                          forIndexPath:indexPath];
            [strongSelf pp_configureBannerCell:cell forItem:item];
            pp_stageCell(cell); return cell;
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
                        layoutMode:PPCellLayoutModeHorizontalRow
                    discountMode:PPDiscountStylePlain
                        imageLoader:^(UIImageView *iv, NSString *url, UIImage *ph, UIView *card) {
                [GM pp_setImageURL:url imageView:iv placeholder:@"placeholder"];
            }];

            return cell;
        }
        */

            if (section == PPHomeSectionAdopt) {
            PetAdoptCollectionViewCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:@"PetAdoptCollectionViewCell"
                                                          forIndexPath:indexPath];

            [cell configureWithTitle:kLang(@"home_adopt_title")
                            subtitle:kLang(@"home_adopt_subtitle")
                           seedImage:[UIImage imageNamed:@"icn_cat"]];

            pp_stageCell(cell); return cell;
        }

                if (section == PPHomeSectionSuggestions || section == PPHomeSectionSuggestionAds || section == PPHomeSectionSuggestionAccessories) {

                if (item.payload == [NSNull null]) {
                    PPUniversalCell *cell =
                            [collectionView dequeueReusableCellWithReuseIdentifier:PPUniversalCell.reuseIdentifier
                                                                      forIndexPath:indexPath];
                        pp_stageCell(cell); return cell; // height-only placeholder
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
                pp_stageCell(cell); return cell;
            }

            vm.indexPath = indexPath;

            [cell applyViewModel:vm
                         context:vm.modelContext
                      layoutMode:PPCellLayoutModeHorizontalRow
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

            pp_stageCell(cell); return cell;
        }


                if (section == PPHomeSectionMainKinds) {

                PPMainKindsCell *cell =
                [collectionView dequeueReusableCellWithReuseIdentifier:PPMainKindsCell.reuseIdentifier
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
                        pp_stageCell(cell); return cell;
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

                BOOL restoredSelectionAppearance =
                    selected && strongSelf.usesRestoredMainKindSelectionAppearance;
                [cell configureWithMainKind:kind
                                      isAll:isAll
                                   selected:selected
                restoredSelectionAppearance:restoredSelectionAppearance];

                __weak typeof(strongSelf) weakStrongSelf = strongSelf;
                cell.onSelect = ^(NSObject *rawKind, BOOL isAll) {
                    __strong typeof(weakStrongSelf) strongSelf = weakStrongSelf;
                    if (!strongSelf) return;

                    MainKindsModel *kind =
                        [rawKind isKindOfClass:MainKindsModel.class]
                            ? (MainKindsModel *)rawKind
                            : nil;
                    if (isAll) {
                        NSLog(@"[Home][MainKinds][Action] ALL selected → deep link");
                    } else {
                        NSLog(@"[Home][MainKinds][Action] Kind selected → %@",
                              kind.KindName);
                    }
                    [strongSelf pp_selectHomeMainKind:kind
                                                isAll:isAll
                                              persist:YES
                                             navigate:YES];
                };


                pp_stageCell(cell); return cell;
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
            pp_stageCell(cell); return cell;
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
            pp_stageCell(cell); return cell;
        }


            PPUniversalCell *cell = (PPUniversalCell *)[PPUniversalCell pp_dequeueFromCollectionView:collectionView indexPath:indexPath];
            [strongSelf pp_clearUnavailableBuyAgainCoverFromCell:cell];
            cell.delegate = strongSelf;
            cell.delegate = self;
        if (item.universalViewModel) {


            PPUniversalCellViewModel *vm = item.universalViewModel;
            vm.indexPath = indexPath;
            [cell applyViewModel:vm
                         context:vm.modelContext
                      layoutMode:PPCellLayoutModeHorizontalRow
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

        pp_stageCell(cell); return cell;
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

        // ── Born-hidden entrance gate for headers ────────────────────
        BOOL stageHeader = weakSelf &&
                           !weakSelf.didRunPremiumHomeEntranceAnimation &&
                           ![weakSelf pp_shouldReduceHomeMotion];
        if (stageHeader) {
            header.alpha = 0.0;
            header.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
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
        [header setSurfaceDecorationActive:[weakSelf pp_shouldShowScrolledSectionHeaderDecoration] animated:NO];
        [weakSelf pp_stageHomeEntranceSupplementaryViewIfNeeded:header
                                                           kind:kind
                                                      indexPath:indexPath];

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
                self.accessories = @[];
                self.accessoriesLoaded = YES;
                [self pp_refreshBuyAgainSection];
                [self reloadSection:PPHomeSectionCurrentOrders];
                [self reloadSection:PPHomeSectionAccessories];
                [self reloadSection:PPHomeSectionSuggestions];
                [self tryApplySnapshot];
                [self pp_checkBootstrapStatus];
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

            // Batch all section reloads into a single layout pass
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            [self reloadSection:PPHomeSectionCurrentOrders];
            [self reloadSection:PPHomeSectionAccessories];
            [self reloadSection:PPHomeSectionSuggestions];
            [CATransaction commit];

            [self tryApplySnapshot];
            [self pp_prefetchTopImagesWithLimit:20];
            [self pp_checkBootstrapStatus];
        });

    }];

    [self pp_fetchLastFoodSection];
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
        [self pp_checkBootstrapStatus];
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
                [self pp_checkBootstrapStatus];
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
        [self pp_checkBootstrapStatus];
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
                [self pp_checkBootstrapStatus];
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
                [self pp_checkBootstrapStatus];
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
            [self pp_installOrthogonalGestureGatesIfNeeded];

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
            [self pp_openPurchasedItems];
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
    animated = animated && !UIAccessibilityIsReduceMotionEnabled();
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
        [UIView animateWithDuration:0.28
                              delay:0.0
             usingSpringWithDamping:0.92
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

- (void)pp_setPetProfileCardExpanded:(BOOL)expanded animated:(BOOL)animated
{
    if (self.isPetProfileCardExpanded == expanded &&
        (!self.layoutManager || self.layoutManager.isPetProfileExpanded == expanded)) {
        return;
    }

    self.isPetProfileCardExpanded = expanded;
    [[NSUserDefaults standardUserDefaults] setBool:expanded forKey:PPHomePetProfileCardExpandedKey];

    if (!self.collectionView || !self.layoutManager) {
        return;
    }

    self.layoutManager.isPetProfileExpanded = expanded;
    void (^layoutChanges)(void) = ^{
        [self.collectionView.collectionViewLayout invalidateLayout];
        [self.collectionView layoutIfNeeded];
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        layoutChanges();
        return;
    }

    [UIView animateWithDuration:0.40
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:layoutChanges
                     completion:nil];
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

    [header configureWithTitle:(kLang(@"home_header_discover_by_category") ?: kLang(@"MainCategories"))
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
    [self.homeConfigListener remove];
    [self pp_stopCurrentOrdersListener];
    [self stopNearbyRefreshTimer];
    [self pp_stopHomeSmartSearchTimer];
    [self.homeLocationTitleView stopLivingMotion];
    [self pp_stopPremiumBackgroundGlowMotion];
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
        [self pp_checkBootstrapStatus];
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
            [self pp_checkBootstrapStatus];
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

- (void)pp_updateHomeSmartSearchForScrollView:(UIScrollView *)scrollView
                                      animated:(BOOL)animated
{
    if (scrollView != self.collectionView || !self.homeSmartSearchView) {
        return;
    }

    CGFloat effectiveOffset = scrollView.contentOffset.y + scrollView.adjustedContentInset.top;
    CGFloat collapse = PPHomeClamp(effectiveOffset / PPHomeSearchCollapseDistance, 0.0, 1.0);
    CGFloat overscroll = PPHomeClamp(-effectiveOffset / PPHomeSearchOverscrollDistance, 0.0, 1.0);

    // Quantize to roughly one content point so 120 Hz scroll sampling does not
    // invalidate the navigation title view for sub-point changes.
    CGFloat step = PPHomeSearchCollapseDistance;
    collapse = round(collapse * step) / step;
    overscroll = round(overscroll * step) / step;
    BOOL materiallyChanged =
        fabs(self.homeSmartSearchCollapseProgress - collapse) >= (1.0 / step) ||
        fabs(self.homeSmartSearchOverscrollProgress - overscroll) >= (1.0 / step);
    if (!materiallyChanged && !animated) {
        return;
    }

    self.homeSmartSearchCollapseProgress = collapse;
    self.homeSmartSearchOverscrollProgress = overscroll;
    [self.homeSmartSearchView setCollapseProgress:collapse
                               overscrollProgress:overscroll
                                         animated:animated];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView == self.collectionView) {
        [[NovaAmbientAssistantCoordinator sharedCoordinator] userDidScroll];
        [self pp_updateHomeSmartSearchForScrollView:scrollView animated:NO];
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if (scrollView != self.collectionView) {
        return;
    }
    [[NovaAmbientAssistantCoordinator sharedCoordinator] userDidScroll];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (scrollView != self.collectionView) {
        return;
    }
    if (!decelerate) {
        [[NovaAmbientAssistantCoordinator sharedCoordinator] userDidStopScrolling];
        [self pp_updateHomeSmartSearchForScrollView:scrollView animated:YES];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if (scrollView != self.collectionView) {
        return;
    }
    [[NovaAmbientAssistantCoordinator sharedCoordinator] userDidStopScrolling];
    [self pp_updateHomeSmartSearchForScrollView:scrollView animated:YES];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    if (scrollView != self.collectionView) {
        return;
    }
    [[NovaAmbientAssistantCoordinator sharedCoordinator] userDidStopScrolling];
    [self pp_updateHomeSmartSearchForScrollView:scrollView animated:YES];
}

- (BOOL)collectionView:(UICollectionView *)collectionView
shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    PPHomeSection section = [self sectionTypeForIndexPath:indexPath];
    if (section == PPHomeSectionAdopt &&
        (collectionView.tracking || collectionView.dragging || collectionView.decelerating)) {
        return NO;
    }
    return YES;
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
        case PPHomeSectionMarketplaceHero:
            [self pp_openMarketplaceProvidersListFromHero];
            return;

        case PPHomeSectionProviderCategoryNav: {
            if ([item.payload isKindOfClass:PPHomeProviderCategoryItem.class]) {
                [self pp_handleProviderCategorySelection:(PPHomeProviderCategoryItem *)item.payload];
            }
            return;
        }

        case PPHomeSectionQuickActions:
            return;

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
                [self pp_selectHomeMainKind:nil
                                      isAll:YES
                                    persist:YES
                                   navigate:YES];
                return;
            }


            // ✅ Route specific kind
            [self pp_selectHomeMainKind:kind
                                  isAll:NO
                                persist:YES
                               navigate:YES];
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

        case PPHomeSectionSuggestions:
        case PPHomeSectionSuggestionAds:
        case PPHomeSectionSuggestionAccessories: {
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
    [self pp_installOrthogonalGestureGatesIfNeeded];

    // First-reveal flash guard: when applyBaseSnapshot inserts sections after
    // HomeConfig arrives, cells are composited at full opacity for one frame
    // before pp_prepareVisibleHomeEntranceContentIfNeeded can fade them. Pre-
    // fade them here so they're already in the entrance "before" state at the
    // moment of display, then let the staggered animation reveal them.
    [self pp_stageHomeEntranceCellIfNeeded:cell indexPath:indexPath];

    PPHomeSection section = [self sectionTypeForIndexPath:indexPath];
    if (section == PPHomeSectionPetProfile ||
        section == PPHomeSectionPremiumSearch ||
        section == PPHomeSectionMarketplaceHero ||
        section == PPHomeSectionMainKinds ||
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
willDisplaySupplementaryView:(UICollectionReusableView *)view
        forElementKind:(NSString *)elementKind
           atIndexPath:(NSIndexPath *)indexPath
{
    (void)collectionView;
    [self pp_stageHomeEntranceSupplementaryViewIfNeeded:view
                                                   kind:elementKind
                                              indexPath:indexPath];
}

- (void)collectionView:(UICollectionView *)collectionView
didHighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    PPHomeSection section = [self sectionTypeForIndexPath:indexPath];
    if (section == PPHomeSectionHero ||
        section == PPHomeSectionMarketplaceHero ||
        section == PPHomeSectionCurrentOrders ||
        section == PPHomeSectionCarousel ||
        section == PPHomeSectionAdopt) {
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

    os_log_t log = PPHomePerformanceLog();
    os_signpost_id_t tapSignpostID = os_signpost_id_generate(log);
    os_signpost_interval_begin(log, tapSignpostID, "home.category.tap", "kind=%{public}@", kind.KindName ?: @"");

    os_signpost_id_t prepSignpostID = os_signpost_id_generate(log);
    os_signpost_interval_begin(log, prepSignpostID, "navigation.prepare");

    // MainKinds rail is an ads/category browse entry. Do not let a previously
    // saved marketplace section force this fresh route into Accessories.
    PPDataViewInput *input = [PPDataViewInput inputWithMainKind:kind
                                                   sourceTarget:PPDeepLinkTargetAds
                                                         source:PPInputSourceHomeMainKindsSection];
    input.mainKindsArr = self.mainKinds ?: @[];
    input.initialSectionOverride = @(PPDataSectionAds);
    PPDataViewVC *vc =  [[PPDataViewVC alloc] initWithInput:input];
    vc.pp_transitionStyle = PPTransitionStyleNone;

    os_signpost_interval_end(log, prepSignpostID, "navigation.prepare");

    os_signpost_id_t pushSignpostID = os_signpost_id_generate(log);
    os_signpost_interval_begin(log, pushSignpostID, "navigation.push_or_present");

    if (![PPHomeHelper pushViewControllerSafely:vc from:self animated:YES]) {
        os_signpost_interval_end(log, pushSignpostID, "navigation.push_or_present", "status=failed");
        os_signpost_interval_end(log, tapSignpostID, "home.category.tap", "status=failed");
        return;
    }

    os_signpost_interval_end(log, pushSignpostID, "navigation.push_or_present", "status=success");
    os_signpost_interval_end(log, tapSignpostID, "home.category.tap", "status=success");
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

- (NSArray<PPHomeProviderCategoryItem *> *)pp_homeProviderCategoryItems
{
    static NSArray<PPHomeProviderCategoryItem *> *items;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        items = @[
            [PPHomeProviderCategoryItem itemWithIdentifier:@"veterinarians"
                                                  titleKey:@"provider_vets_title"
                                               subtitleKey:@"provider_vets_subtitle"
                                                systemIcon:@"veterinaryNewColor"
                                                     route:PPHomeProviderCategoryRouteVeterinarians],
            [PPHomeProviderCategoryItem itemWithIdentifier:@"pharmacy"
                                                  titleKey:@"provider_pharmacies_title"
                                               subtitleKey:@"provider_pharmacies_subtitle"
                                                systemIcon:@"cross.case.fill"
                                                     route:PPHomeProviderCategoryRouteServices],
        ];
    });
    return items;
}

- (NSArray<PPHomeProviderCategoryItem *> *)pp_homeProviderUnifiedCategoryItems
{
    NSArray<PPHomeProviderCategoryItem *> *items = [self pp_homeProviderCategoryItems];
    PPHomeProviderCategoryItem *pharmacyItem = nil;
    PPHomeProviderCategoryItem *doctorsItem = nil;

    for (PPHomeProviderCategoryItem *item in items) {
        NSString *identifier = PPSafeString(item.identifier);
        if ([identifier isEqualToString:@"pharmacy"]) {
            pharmacyItem = item;
        } else if ([identifier isEqualToString:@"veterinarians"]) {
            doctorsItem = item;
        }
    }

    if (!pharmacyItem && items.count > 1) {
        pharmacyItem = items[1];
    }
    if (!doctorsItem && items.count > 0) {
        doctorsItem = items[0];
    }

    NSMutableArray<PPHomeProviderCategoryItem *> *orderedItems = [NSMutableArray arrayWithCapacity:2];
    if (pharmacyItem) {
        [orderedItems addObject:pharmacyItem];
    }
    if (doctorsItem) {
        [orderedItems addObject:doctorsItem];
    }
    return orderedItems.copy;
}

- (PPHomeProviderCategoryItem *)pp_marketplaceProviderCategoryItem
{
    for (PPHomeProviderCategoryItem *item in [self pp_homeProviderCategoryItems]) {
        if ([PPSafeString(item.identifier) isEqualToString:@"marketplace"]) {
            return item;
        }
    }

    return [PPHomeProviderCategoryItem itemWithIdentifier:@"marketplace"
                                                 titleKey:@"provider_marketplace_title"
                                              subtitleKey:@"provider_marketplace_subtitle"
                                               systemIcon:@"square.grid.2x2.fill"
                                                    route:PPHomeProviderCategoryRouteServices];
}

- (void)pp_openMarketplaceProvidersListFromHero
{
    MainKindsModel *selectedMainKind = self.selectedCategory;
    [self pp_emitSelectionHaptic];

    if (!selectedMainKind) {
        ProviderCompaniesListVC *vc = [[ProviderCompaniesListVC alloc] init];
        [PPHomeHelper pushViewControllerSafely:vc from:self animated:YES];
        return;
    }

    PPDataViewInput *input =
        [PPDataViewInput inputWithMainKind:selectedMainKind
                              sourceTarget:PPDeepLinkTargetAccessories
                                    source:PPInputSourceHomeAccessoriesSection];
    input.mainKindsArr = self.mainKinds ?: @[];
    input.initialSectionOverride = @(PPDataSectionAccessories);

    PPDataViewVC *vc = [[PPDataViewVC alloc] initWithInput:input];
    vc.pp_transitionStyle = PPTransitionStyleNone;
    [PPHomeHelper pushViewControllerSafely:vc from:self animated:YES];
}

- (void)pp_refreshProviderCategoryNavigationSection
{
    NSDiffableDataSourceSnapshot *snapshot = self.dataSource.snapshot;
    NSArray<PPHomeItem *> *items =
        [self pp_safeItemsInSection:PPHomeSectionProviderCategoryNav
                         fromSnapshot:snapshot];
    if (items.count == 0) {
        return;
    }
    [self pp_reconfigureHomeItems:items inSnapshot:snapshot];
}

- (void)pp_handleProviderCategorySelection:(PPHomeProviderCategoryItem *)item
{
    if (![item isKindOfClass:PPHomeProviderCategoryItem.class]) {
        return;
    }

    [self pp_emitSelectionHaptic];

    if (item.route == PPHomeProviderCategoryRouteVeterinarians) {
        [self openNearestVet];
        return;
    }

    ProviderCompaniesListVC *vc = [[ProviderCompaniesListVC alloc] init];
    vc.selectedProviderCategoryIdentifier = PPSafeString(item.identifier);
    vc.selectedProviderCategoryTitleKey = PPSafeString(item.titleKey);
    vc.selectedProviderCategorySubtitleKey = PPSafeString(item.subtitleKey);
    [PPHomeHelper pushViewControllerSafely:vc from:self animated:YES];
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
        case PPHomeQuickActionTypeRequestService: {
            PPDataViewInput *input = [PPDataViewInput inputWithMainKind:nil
                                                           sourceTarget:PPDeepLinkTargetServices
                                                                 source:PPInputSourceHomeServicesSection];
            input.initialSectionOverride = @(PPDataSectionServices);
            PPDataViewVC *vc = [[PPDataViewVC alloc] initWithInput:input];
            vc.pp_transitionStyle = PPTransitionStyleNone;
            [PPHomeHelper pushViewControllerSafely:vc from:self animated:YES];
            break;
        }
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
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:nav animated:YES completion:nil];
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

- (BOOL)pp_shouldStageHomeEntranceContent
{
    return self.collectionView != nil &&
           !self.didRunPremiumHomeEntranceAnimation &&
           ![self pp_shouldReduceHomeMotion];
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
    // Don't fade navigation chrome while the snapshot is still empty. The
    // ambient background runs independently of HomeConfig/content entrance.
    if (self.dataSource && self.dataSource.snapshot.numberOfItems == 0) {
        return;
    }
    self.didPreparePremiumHomeEntrance = YES;

    NSMutableArray<UIView *> *chromeViews = [NSMutableArray array];
    if (self.homeSmartSearchView) {
        [chromeViews addObject:self.homeSmartSearchView];
    }
    if (!PPHomeTemporarilyHideLeadingProfileItem && self.homeProfileItem.customView) {
        [chromeViews addObject:self.homeProfileItem.customView];
    }
    if (self.homeCartButton) {
        [chromeViews addObject:self.homeCartButton];
    }

    if ([self pp_shouldReduceHomeMotion]) {
        self.collectionView.alpha = 1.0;
        self.collectionView.transform = CGAffineTransformIdentity;
        for (UIView *chromeView in chromeViews) {
            chromeView.alpha = 1.0;
            chromeView.transform = CGAffineTransformIdentity;
        }
        return;
    }

    self.collectionView.alpha = 1.0;
    self.collectionView.transform = CGAffineTransformIdentity;

    for (UIView *chromeView in chromeViews) {
        chromeView.alpha = 0.22;
        chromeView.transform = CGAffineTransformMakeTranslation(0.0, -6.0);
    }
}

- (void)pp_prepareVisibleHomeEntranceContentIfNeeded
{
    if (![self pp_shouldStageHomeEntranceContent]) {
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
        [self pp_stageHomeEntranceSupplementaryViewIfNeeded:header
                                                       kind:UICollectionElementKindSectionHeader
                                                  indexPath:headerIndexPath];
        headerOrdinal += 1;
    }];

    [visibleIndexPaths enumerateObjectsUsingBlock:^(NSIndexPath * _Nonnull indexPath, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)idx;
        (void)stop;
        UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:indexPath];
        [self pp_stageHomeEntranceCellIfNeeded:cell indexPath:indexPath];
    }];
}

- (void)pp_addRandomizedMiddleBackgroundGlowPositionMotion
{
    PPHomeAmbientGlowView *glowView = self.pp_premiumBackgroundGlowViewMid;
    if (!glowView || !PPHomeRectIsFiniteAndNotEmpty(glowView.bounds) ||
        [glowView.layer animationForKey:PPHomeMiddleBackgroundGlowPositionMotionKey]) {
        return;
    }

    CGFloat canvasWidth = CGRectGetWidth(self.pp_premiumBackgroundCanvasView.bounds);
    CGFloat canvasHeight = CGRectGetHeight(self.pp_premiumBackgroundCanvasView.bounds);
    if (!PPHomeFiniteCGFloat(canvasWidth) || canvasWidth <= 0.0 ||
        !PPHomeFiniteCGFloat(canvasHeight) || canvasHeight <= 0.0) {
        return;
    }

    CGFloat maximumXOffset = MIN(92.0, MAX(64.0, canvasWidth * 0.22));
    CGFloat maximumYOffset = MIN(116.0, MAX(78.0, canvasHeight * 0.115));
    CGPoint restingPosition = glowView.layer.position;
    if (!PPHomeFiniteCGFloat(restingPosition.x) || !PPHomeFiniteCGFloat(restingPosition.y)) {
        return;
    }

    NSMutableArray<NSValue *> *positions = [NSMutableArray arrayWithObject:[NSValue valueWithCGPoint:restingPosition]];
    NSMutableArray<NSNumber *> *keyTimes = [NSMutableArray arrayWithObject:@0.0];
    static NSInteger const waypointCount = 7;
    for (NSInteger index = 1; index <= waypointCount; index++) {
        CGFloat randomXUnit = ((CGFloat)arc4random_uniform(2001) / 1000.0) - 1.0;
        CGFloat randomYUnit = ((CGFloat)arc4random_uniform(2001) / 1000.0) - 1.0;
        CGPoint waypoint = CGPointMake(restingPosition.x + (randomXUnit * maximumXOffset),
                                       restingPosition.y + (randomYUnit * maximumYOffset));
        if (!PPHomeFiniteCGFloat(waypoint.x) || !PPHomeFiniteCGFloat(waypoint.y)) {
            continue;
        }
        [positions addObject:[NSValue valueWithCGPoint:waypoint]];
        [keyTimes addObject:@((CGFloat)index / (CGFloat)(waypointCount + 1))];
    }
    [positions addObject:[NSValue valueWithCGPoint:restingPosition]];
    [keyTimes addObject:@1.0];

    CFTimeInterval duration = 13.0 + ((CGFloat)arc4random_uniform(3501) / 1000.0);
    if (!isfinite(duration) || duration <= 0.0 || positions.count != keyTimes.count) {
        return;
    }
    CAKeyframeAnimation *positionAnimation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
    positionAnimation.values = positions;
    positionAnimation.keyTimes = keyTimes;
    positionAnimation.calculationMode = kCAAnimationCubic;
    positionAnimation.duration = duration;
    positionAnimation.repeatCount = HUGE_VALF;
    positionAnimation.removedOnCompletion = YES;
    positionAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    CFTimeInterval localNow = [glowView.layer convertTime:CACurrentMediaTime() fromLayer:nil];
    CGFloat randomPhase = ((CGFloat)arc4random_uniform(10001) / 10000.0) * duration;
    positionAnimation.beginTime = localNow - randomPhase;

    [glowView.layer addAnimation:positionAnimation forKey:PPHomeMiddleBackgroundGlowPositionMotionKey];
}

- (void)pp_addPremiumMiddleBackgroundGlowPeekMotionIfNeeded
{
    PPHomeAmbientGlowView *glowView = self.pp_premiumBackgroundGlowViewMid;
    if (!glowView || !PPHomeRectIsFiniteAndNotEmpty(glowView.bounds) ||
        [glowView.layer animationForKey:PPHomeMiddleBackgroundGlowPeekMotionKey]) {
        return;
    }

    CGFloat travelDistance = MIN(26.0, MAX(16.0, CGRectGetWidth(glowView.bounds) * 0.08));
    if (!PPHomeFiniteCGFloat(travelDistance) || travelDistance <= 0.0) {
        return;
    }
    CGFloat direction = self.view.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft ? -1.0 : 1.0;

    CABasicAnimation *positionAnimation =
        [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
    positionAnimation.fromValue = @(0.0);
    positionAnimation.toValue = @(travelDistance * direction);

    CABasicAnimation *opacityAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacityAnimation.fromValue = @0.88;
    opacityAnimation.toValue = @1.0;

    CABasicAnimation *scaleAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scaleAnimation.fromValue = @0.985;
    scaleAnimation.toValue = @1.018;

    CAAnimationGroup *peekAnimation = [CAAnimationGroup animation];
    peekAnimation.animations = @[positionAnimation, opacityAnimation, scaleAnimation];
    peekAnimation.duration = 4.8;
    peekAnimation.autoreverses = YES;
    peekAnimation.repeatCount = HUGE_VALF;
    peekAnimation.removedOnCompletion = YES;
    peekAnimation.timingFunction =
        [CAMediaTimingFunction functionWithControlPoints:0.35 :0.0 :0.18 :1.0];

    [glowView.layer addAnimation:peekAnimation forKey:PPHomeMiddleBackgroundGlowPeekMotionKey];
}

- (void)pp_beginPremiumBackgroundGlowMotionIfNeeded
{

    [self.ambientBackgroundView startAnimations];
}

- (void)pp_stopPremiumBackgroundGlowMotion
{
    if (PPHomeUseHeroApex) {
        [self.ambientBackgroundView stopAnimations];
    } else {
        self.didStartPremiumBackgroundGlowMotion = NO;
        [self.pp_premiumBackgroundGlowViewMid.layer removeAnimationForKey:PPHomeMiddleBackgroundGlowPositionMotionKey];
        [self.pp_premiumBackgroundGlowViewMid.layer removeAnimationForKey:PPHomeMiddleBackgroundGlowPeekMotionKey];
    }
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
    BOOL hasVisibleCells = (self.collectionView.indexPathsForVisibleItems.count > 0);
    BOOL hasVisibleHeaders =
        ([self.collectionView visibleSupplementaryViewsOfKind:UICollectionElementKindSectionHeader].count > 0);
    if (!hasVisibleCells && !hasVisibleHeaders) {
        return;
    }

    NSMutableArray<UIView *> *chromeViews = [NSMutableArray array];
    if (self.homeSmartSearchView) {
        [chromeViews addObject:self.homeSmartSearchView];
    }
    if (!PPHomeTemporarilyHideLeadingProfileItem && self.homeProfileItem.customView) {
        [chromeViews addObject:self.homeProfileItem.customView];
    }
    if (self.homeCartButton) {
        [chromeViews addObject:self.homeCartButton];
    }

    if ([self pp_shouldReduceHomeMotion]) {
        self.didRunPremiumHomeEntranceAnimation = YES;
        self.isPremiumHomeEntranceAnimating = NO;
        self.collectionView.alpha = 1.0;
        self.collectionView.transform = CGAffineTransformIdentity;
        for (UIView *chromeView in chromeViews) {
            chromeView.alpha = 1.0;
            chromeView.transform = CGAffineTransformIdentity;
        }
        [self pp_refreshInitialHomeRevealDependentContent];
        [self pp_positionInitialSelectedMainKindIfNeededAnimated:NO];
        return;
    }

    self.didRunPremiumHomeEntranceAnimation = YES;
    self.isPremiumHomeEntranceAnimating = YES;

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

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.86 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.isViewLoaded) {
            return;
        }
        self.isPremiumHomeEntranceAnimating = NO;
        [self pp_stabilizeHomeCollectionLayoutIfNeeded];
        [self pp_refreshInitialHomeRevealDependentContent];
        [self pp_positionInitialSelectedMainKindIfNeededAnimated:YES];
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
    BOOL isHero = (section == PPHomeSectionHero ||
                   section == PPHomeSectionMarketplaceHero);
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

    if (section == PPHomeSectionPremiumCare) {
        if (PPULTRA_CARE_IS_ACTIVATED &&
            [cell isKindOfClass:PPHomeUltraPremuimPetCareCell.class]) {
            [(PPHomeUltraPremuimPetCareCell *)cell
                pp_playPostLayoutEntranceWithDelay:(delay + 0.10)];
        } else if (!PPULTRA_CARE_IS_ACTIVATED &&
                   [cell isKindOfClass:PPHomePremiumCareCell.class]) {
            [(PPHomePremiumCareCell *)cell
                pp_playPostLayoutEntranceWithDelay:(delay + 0.10)];
        }
    }
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
           section == PPHomeSectionSuggestionAds ||
           section == PPHomeSectionSuggestionAccessories ||
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
    if (!cell || !indexPath || ![PPUniversalCell pp_isUniversalCell:cell]) {
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
    BOOL isHero = (section == PPHomeSectionHero ||
                   section == PPHomeSectionMarketplaceHero);
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
    CGFloat initialAlpha = 0.0;

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
    if (section == PPHomeSectionPremiumCare && !isLateAppearance) {
        if (PPULTRA_CARE_IS_ACTIVATED &&
            [cell isKindOfClass:PPHomeUltraPremuimPetCareCell.class]) {
            [(PPHomeUltraPremuimPetCareCell *)cell pp_preparePostLayoutEntranceState];
        } else if (!PPULTRA_CARE_IS_ACTIVATED &&
                   [cell isKindOfClass:PPHomePremiumCareCell.class]) {
            [(PPHomePremiumCareCell *)cell pp_preparePostLayoutEntranceState];
        }
    }
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

- (void)pp_stageHomeEntranceCellIfNeeded:(UICollectionViewCell *)cell
                               indexPath:(NSIndexPath *)indexPath
{
    if (![self pp_shouldStageHomeEntranceContent] || !cell || !indexPath) {
        return;
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [self pp_configureHomeEntranceInitialStateForCell:cell
                                          atIndexPath:indexPath
                                       lateAppearance:NO];
    [CATransaction commit];
}

- (void)pp_stageHomeEntranceSupplementaryViewIfNeeded:(UICollectionReusableView *)supplementaryView
                                                 kind:(NSString *)kind
                                            indexPath:(NSIndexPath *)indexPath
{
    if (![self pp_shouldStageHomeEntranceContent] ||
        !supplementaryView ||
        !indexPath ||
        ![kind isEqualToString:UICollectionElementKindSectionHeader]) {
        return;
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [self pp_configureHomeEntranceInitialStateForSupplementaryView:supplementaryView
                                                              kind:kind
                                                       atIndexPath:indexPath
                                                    lateAppearance:NO];
    [CATransaction commit];
}



- (void)setProfileCard
{
    NSString *profileAvatarName = PPSafeString(PPCurrentUser.UserName);
    if (profileAvatarName.length == 0) {
        profileAvatarName = @"PurePets";
    }
    UIImage *profileAvatar = [PPModernAvatarRenderer avatarImageForName:profileAvatarName size:36];
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
    if ([self.tabBarController respondsToSelector:@selector(setPremiumTabDockViewHidden:animation:)]) {
        [(PPRootTabBarController *)self.tabBarController setPremiumTabDockViewHidden:NO animation:NO];
    }

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
    [self pp_stopPremiumBackgroundGlowMotion];
    [self pp_stopNovaFloatingMotion];
    [[NovaAmbientAssistantCoordinator sharedCoordinator] hideNova];
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

    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.leftBarButtonItems =
        PPHomeTemporarilyHideLeadingProfileItem ? @[] : PPHomeBarButtonItems(profileItem);
    NSInteger cartCount = [CartManager.sharedManager totalItemsCount];
    [self refreshNavigationRightItemsForCartCount:cartCount];
    [self pp_applyHomeCartBadgeCount:cartCount animated:NO];
    [self pp_updateHomeCartButtonPresenceAnimated:NO];

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

- (void)pp_buildCartBarButtonItem
{
    if (self.homeCartButton) {
        [self.homeCartButton removeFromSuperview];
    }

    UIButton *btn;
    CGFloat cartButtonSide = PPHomeSmartSearchCartButtonSide;

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
        cfg.contentInsets = NSDirectionalEdgeInsetsZero;
        cfg.baseForegroundColor = PPHomeCartButtonAccentColor();
        cfg.background.backgroundColor = UIColor.clearColor;
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        btn = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    } else {
        btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.contentEdgeInsets = UIEdgeInsetsZero;
    }

    // Apply standard system cart icon
    UIImage *icon = [UIImage systemImageNamed:@"cart"];
    if (!icon) {
        icon = [UIImage imageNamed:@"cart"];
    }

    if (icon) {
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightRegular scale:UIImageSymbolScaleMedium];
            icon = [icon imageByApplyingSymbolConfiguration:config];
            icon = [icon imageWithTintColor:PPHomeCartButtonAccentColor()
                              renderingMode:UIImageRenderingModeAlwaysOriginal];
        }
        [btn setImage:icon forState:UIControlStateNormal];
        [btn setImage:icon forState:UIControlStateHighlighted];
    }

    btn.tintColor = PPHomeCartButtonAccentColor();
    btn.tintAdjustmentMode = UIViewTintAdjustmentModeNormal;
    btn.imageView.tintAdjustmentMode = UIViewTintAdjustmentModeNormal;
    btn.backgroundColor = UIColor.clearColor;
    btn.adjustsImageWhenHighlighted = NO;
    [btn addTarget:self action:@selector(cartClick) forControlEvents:UIControlEventTouchUpInside];

    btn.accessibilityLabel = NSLocalizedString(@"a11y_btn_cart", @"Shopping cart");
    btn.accessibilityHint  = NSLocalizedString(@"a11y_btn_cart_hint", @"Double-tap to open your cart");

    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.frame = CGRectMake(0.0, 0.0, cartButtonSide, cartButtonSide);
    btn.bounds = CGRectMake(0.0, 0.0, cartButtonSide, cartButtonSide);

    btn.clipsToBounds = NO;
    btn.layer.masksToBounds = NO;
    btn.layer.cornerRadius = cartButtonSide * 0.5;
    btn.hidden = YES;
    btn.alpha = 0.0;
    btn.transform = PPHomeSmartSearchCartHiddenTransform();
    btn.userInteractionEnabled = NO;
    btn.accessibilityElementsHidden = YES;
    if (@available(iOS 13.0, *)) {
        btn.layer.cornerCurve = kCACornerCurveContinuous;
    }
    btn.layer.borderWidth = 0.0;
    [btn pp_setBorderColor:UIColor.clearColor];

    // Explicitly strip any layer-level shadows
    btn.layer.shadowColor = nil;
    btn.layer.shadowOpacity = 0.0;
    btn.layer.shadowRadius = 0.0;
    btn.layer.shadowOffset = CGSizeZero;
    [btn pp_setShadowColor:UIColor.clearColor];

    self.homeCartButton = btn;
    self.homeCartButtonPresencePrepared = NO;
    self.homeCartButtonSlotVisible = NO;
    [self pp_applyHomeCartButtonAppearance];
}

- (void)pp_applyHomeCartButtonAppearance
{
    if (!self.homeCartButton) {
        return;
    }

    UIButton *button = self.homeCartButton;
    UIColor *accentColor = PPHomeCartButtonAccentColor();
    UIColor *surfaceColor = PPHomeCartButtonSurfaceColor();
    UIColor *liquidBorderColor = PPHomeCartButtonLiquidBorderColor();
    CGFloat buttonSide = MIN(CGRectGetWidth(button.bounds), CGRectGetHeight(button.bounds));
    if (self.homeCartButtonHeightConstraint && self.homeCartButtonHeightConstraint.constant > 1.0) {
        buttonSide = self.homeCartButtonHeightConstraint.constant;
    }
    if (buttonSide <= 1.0) {
        buttonSide = 44.0;
    }

    button.tintColor = accentColor;
    button.tintAdjustmentMode = UIViewTintAdjustmentModeNormal;
    button.backgroundColor = UIColor.clearColor;
    button.adjustsImageWhenHighlighted = NO;
    button.clipsToBounds = NO;
    button.layer.masksToBounds = NO;
    button.layer.cornerRadius = buttonSide * 0.5;
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
    button.layer.borderWidth = 0.0;
    [button pp_setBorderColor:UIColor.clearColor];

    CAShapeLayer *surfaceLayer = PPHomeCartButtonSurfaceLayer(button);
    surfaceLayer.frame = CGRectMake(0.0, 0.0, buttonSide, buttonSide);
    CGRect surfaceRect = CGRectInset(surfaceLayer.bounds, 0.7, 0.7);
    surfaceLayer.path = [UIBezierPath bezierPathWithOvalInRect:surfaceRect].CGPath;
    surfaceLayer.fillColor = surfaceColor.CGColor;
    surfaceLayer.strokeColor = liquidBorderColor.CGColor;
    surfaceLayer.lineWidth = 1.35;
    if (button.imageView) {
        button.imageView.tintAdjustmentMode = UIViewTintAdjustmentModeNormal;
    }

    UIImage *icon = [UIImage systemImageNamed:@"cart"];
    if (!icon) {
        icon = [UIImage imageNamed:@"cart"];
    }
    if (icon) {
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *config =
                [UIImageSymbolConfiguration configurationWithPointSize:20
                                                                 weight:UIImageSymbolWeightRegular
                                                                  scale:UIImageSymbolScaleMedium];
            icon = [icon imageByApplyingSymbolConfiguration:config];
            icon = [icon imageWithTintColor:accentColor renderingMode:UIImageRenderingModeAlwaysOriginal];
        } else {
            icon = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
        [button setImage:icon forState:UIControlStateNormal];
        [button setImage:icon forState:UIControlStateHighlighted];
    }

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *configuration = button.configuration ?: [UIButtonConfiguration plainButtonConfiguration];
        configuration.image = icon;
        configuration.imagePadding = 0.0;
        configuration.baseForegroundColor = accentColor;
        configuration.background.backgroundColor = UIColor.clearColor;
        configuration.background.strokeColor = UIColor.clearColor;
        configuration.background.strokeWidth = 0.0;
        configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        button.configuration = configuration;
    }
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
    static const CGFloat kSize = 40.0;
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

    NSString *renderedAvatarName = PPSafeString(PPCurrentUser.UserName);
    if (renderedAvatarName.length == 0) {
        renderedAvatarName = @"PurePets";
    }
    UIImage *renderedAvatar = [PPModernAvatarRenderer avatarImageForName:renderedAvatarName size:38.0];

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

    PPHomePrepareProfileMenuButton(button, self);

    return [[UIBarButtonItem alloc] initWithCustomView:container];
}


- (void)refreshNavigationRightItemsForCartCount:(NSUInteger)count
{
    (void)count;
    // Hide the trailing cart button from the navigation bar.
    self.navigationItem.rightBarButtonItems = @[];

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
    [self pp_applyHomeCartButtonAppearance];


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
        [self.homeCartButton layoutIfNeeded];

        if (CGRectIsEmpty(strongBadgeHost.bounds)) {
            return;
        }

        [strongBadgeHost removeBadge];
        [strongBadgeHost addBadgeWithContent:badgeText
                                  badgeColor:badgeColor
                                     offset:CGPointMake(-9, 9)
                                badgeRadius:9.5];
    };

    applyBadge();

    if (animated || CGRectIsEmpty(badgeHost.bounds)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.homeCartButton setNeedsLayout];
            [self.homeCartButton layoutIfNeeded];
            applyBadge();
        });
    }
}

- (NSInteger)pp_currentSavedForLaterItemCount
{
    NSArray<CartItem *> *savedItems = [[PPSaveForLaterManager sharedManager] savedItems];
    return MAX((NSInteger)savedItems.count, 0);
}

- (BOOL)pp_shouldShowHomeCartButton
{
    NSInteger cartCount = MAX([CartManager.sharedManager totalItemsCount], 0);
    NSInteger savedCount = [self pp_currentSavedForLaterItemCount];
    return cartCount > 0 || savedCount > 0;
}

- (void)pp_updateHomeCartButtonPresenceAnimated:(BOOL)animated
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pp_updateHomeCartButtonPresenceAnimated:animated];
        });
        return;
    }

    if (!self.homeCartButton ||
        !self.homeSmartSearchAndCartContainer ||
        !self.homeCartButtonWidthConstraint ||
        !self.homeCartButtonHeightConstraint ||
        !self.homeSmartSearchTrailingToContainerConstraint ||
        !self.homeSmartSearchTrailingToCartConstraint) {
        return;
    }

    BOOL shouldShow = [self pp_shouldShowHomeCartButton];
    BOOL stateChanged =
        !self.homeCartButtonPresencePrepared || self.homeCartButtonSlotVisible != shouldShow;
    UIView *layoutHost = self.homeSmartSearchAndCartContainer.superview ?: self.homeSmartSearchAndCartContainer;

    [layoutHost layoutIfNeeded];
    [self.homeSmartSearchAndCartContainer layoutIfNeeded];

    if (shouldShow) {
        self.homeCartButton.hidden = NO;
        if (stateChanged && animated) {
            self.homeCartButton.alpha = 0.0;
            self.homeCartButton.transform = PPHomeSmartSearchCartHiddenTransform();
        }
    }

    self.homeCartButtonPresencePrepared = YES;
    self.homeCartButtonSlotVisible = shouldShow;
    self.homeCartButtonWidthConstraint.constant = shouldShow ? PPHomeSmartSearchCartButtonSide : 0.0;
    self.homeCartButtonHeightConstraint.constant = PPHomeSmartSearchCartButtonSide;
    self.homeCartButton.userInteractionEnabled = shouldShow;
    self.homeCartButton.accessibilityElementsHidden = !shouldShow;

    if (shouldShow) {
        self.homeSmartSearchTrailingToContainerConstraint.active = NO;
        self.homeSmartSearchTrailingToCartConstraint.active = YES;
    } else {
        self.homeSmartSearchTrailingToCartConstraint.active = NO;
        self.homeSmartSearchTrailingToContainerConstraint.active = YES;
    }

    self.homeCartButton.layer.cornerRadius = PPHomeSmartSearchCartButtonSide * 0.5;
    [self pp_applyHomeCartButtonAppearance];

    void (^applyFinalState)(void) = ^{
        self.homeCartButton.alpha = shouldShow ? 1.0 : 0.0;
        self.homeCartButton.transform = shouldShow ? CGAffineTransformIdentity : PPHomeSmartSearchCartHiddenTransform();
        [self.homeSmartSearchAndCartContainer setNeedsLayout];
        [self.homeSmartSearchAndCartContainer layoutIfNeeded];
        [layoutHost setNeedsLayout];
        [layoutHost layoutIfNeeded];
        [self.navigationController.navigationBar setNeedsLayout];
        [self.navigationController.navigationBar layoutIfNeeded];
    };

    void (^finish)(BOOL) = ^(BOOL finished) {
        (void)finished;
        self.homeCartButton.hidden = !shouldShow;
        self.homeCartButton.userInteractionEnabled = shouldShow;
        if (shouldShow) {
            NSInteger cartCount = MAX([CartManager.sharedManager totalItemsCount], 0);
            [self pp_applyHomeCartBadgeCount:cartCount animated:NO];
        }
    };

    if (!animated || !stateChanged) {
        [UIView performWithoutAnimation:applyFinalState];
        finish(YES);
        return;
    }

    [UIView animateWithDuration:PPHomeSmartSearchCartRevealDuration
                          delay:0.0
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.32
                        options:UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionAllowUserInteraction |
                                UIViewAnimationOptionCurveEaseInOut
                     animations:applyFinalState
                     completion:finish];
}

- (void)pp_handleSavedForLaterUpdatedNotification:(NSNotification *)notification
{
    (void)notification;
    NSInteger cartCount = MAX([CartManager.sharedManager totalItemsCount], 0);
    [self pp_updateHomeCartButtonPresenceAnimated:YES];
    [self pp_applyHomeCartBadgeCount:cartCount animated:NO];
}

- (CGFloat)preferredNavigationCenterViewWidth
{
    UINavigationBar *navigationBar = self.navigationController.navigationBar;
    if (!navigationBar) {
        return 160.0;
    }

    CGFloat navBarWidth = CGRectGetWidth(navigationBar.bounds);
    if (navBarWidth <= 0.0) {
        return 160.0;
    }

    UIBarButtonItem *leftItem = PPHomeTemporarilyHideLeadingProfileItem
        ? nil
        : (self.navigationItem.leftBarButtonItem ?: self.navigationItem.leftBarButtonItems.firstObject);
    UIBarButtonItem *rightItem = self.navigationItem.rightBarButtonItem ?: self.navigationItem.rightBarButtonItems.firstObject;
    CGFloat leftWidth = [self pp_widthForBarButtonItem:leftItem fallback:0.0];
    CGFloat rightWidth = [self pp_widthForBarButtonItem:rightItem fallback:40.0];
    UIEdgeInsets layoutMargins = navigationBar.layoutMargins;
    CGFloat sideMargins = layoutMargins.left + layoutMargins.right;
    CGFloat breathingRoom = PPHomeTemporarilyHideLeadingProfileItem ? 12.0 : 20.0;

    CGFloat availableWidth = navBarWidth - sideMargins  - breathingRoom;
    if (availableWidth <= 0.0) {
        return 160.0;
    }

    return floor(MAX(160.0, availableWidth));
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
    return width > 0.0 ? floor(width) : 160.0;
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
        frame.size = CGSizeMake(targetWidth, 48.0);
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
    if (!self.homeSmartSearchAndCartContainer) {
        return;
    }

    CGFloat targetWidth = [self preferredNavigationCenterViewWidth];
    if (targetWidth > 0.0) {
        self.homeSmartSearchAndCartContainerWidthConstraint.constant = targetWidth;
        CGRect frame = self.homeSmartSearchAndCartContainer.frame;
        frame.size = CGSizeMake(targetWidth, 48.0);
        self.homeSmartSearchAndCartContainer.frame = frame;
        self.homeSmartSearchAndCartContainer.bounds = (CGRect){CGPointZero, frame.size};
        [self.homeSmartSearchAndCartContainer invalidateIntrinsicContentSize];
    }

    [self.homeSmartSearchView setNeedsLayout];
    [self.homeSmartSearchView layoutIfNeeded];
    [self.homeSmartSearchAndCartContainer setNeedsLayout];
    [self.homeSmartSearchAndCartContainer layoutIfNeeded];
    [self.navigationController.navigationBar setNeedsLayout];
}

- (UIView *)pp_navigationLocationTitleView
{
    CGFloat width = [self pp_preferredNavigationLocationTitleWidth];
    if (!self.homeLocationTitleView) {
        self.homeLocationTitleView =
            [[PPHomeLocationTitleView alloc] initWithFrame:CGRectMake(0.0, 0.0, width, 48.0)];
        self.homeLocationTitleView.translatesAutoresizingMaskIntoConstraints = NO;
        self.homeLocationTitleWidthConstraint =
            [self.homeLocationTitleView.widthAnchor constraintEqualToConstant:MAX(width, 160.0)];
        self.homeLocationTitleWidthConstraint.priority = UILayoutPriorityDefaultHigh;
        self.homeLocationTitleWidthConstraint.active = YES;
        [self.homeLocationTitleView.heightAnchor constraintEqualToConstant:48.0].active = YES;
        [self.homeLocationTitleView addTarget:self
                                       action:@selector(presentHomeLocationOptions)
                             forControlEvents:UIControlEventTouchUpInside];
    }

    CGRect frame = self.homeLocationTitleView.frame;
    frame.size.width = width;
    frame.size.height = 48.0;
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
            [[PPHomeSmartSearchTitleView alloc] initWithFrame:CGRectMake(0.0, 0.0, width, 48.0)];
        self.homeSmartSearchView.translatesAutoresizingMaskIntoConstraints = NO;
        self.homeSmartSearchView.showSmartPillBackground = NO;
        [self.homeSmartSearchView addTarget:self
                                     action:@selector(pp_openSmartSearch)
                           forControlEvents:UIControlEventTouchUpInside];
    }

    if (!self.homeCartButton) {
        [self pp_buildCartBarButtonItem];
    }

    if (!self.homeSmartSearchAndCartContainer) {
        self.homeSmartSearchAndCartContainer = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, width, 48.0)];
        self.homeSmartSearchAndCartContainer.backgroundColor = UIColor.clearColor;
        self.homeSmartSearchAndCartContainer.translatesAutoresizingMaskIntoConstraints = NO;

        self.homeSmartSearchAndCartContainerWidthConstraint =
            [self.homeSmartSearchAndCartContainer.widthAnchor constraintEqualToConstant:MAX(width, 220.0)];
        self.homeSmartSearchAndCartContainerWidthConstraint.priority = UILayoutPriorityDefaultHigh;
        self.homeSmartSearchAndCartContainerWidthConstraint.active = YES;

        [self.homeSmartSearchAndCartContainer.heightAnchor constraintEqualToConstant:48.0].active = YES;
    }

    if (self.homeSmartSearchView.superview != self.homeSmartSearchAndCartContainer) {
        [self.homeSmartSearchView removeFromSuperview];
        [self.homeSmartSearchAndCartContainer addSubview:self.homeSmartSearchView];
    }

    if (self.homeCartButton.superview != self.homeSmartSearchAndCartContainer) {
        [self.homeCartButton removeFromSuperview];
        [self.homeSmartSearchAndCartContainer addSubview:self.homeCartButton];
    }
    [self pp_applyHomeCartButtonAppearance];

    // Safeguard: Ensure no duplicate or stale cart buttons are lingering in the container
    for (UIView *subview in self.homeSmartSearchAndCartContainer.subviews.copy) {
        if ([subview isKindOfClass:[UIButton class]] && subview != self.homeCartButton) {
            [subview removeFromSuperview];
        }
    }

    // Configure Constraints for subviews inside container:
    // Remove previous layout constraints inside container to prevent duplicates
    for (NSLayoutConstraint *c in self.homeSmartSearchAndCartContainer.constraints.copy) {
        if (c.firstItem == self.homeSmartSearchView || c.secondItem == self.homeSmartSearchView ||
            c.firstItem == self.homeCartButton || c.secondItem == self.homeCartButton) {
            if (c != self.homeSmartSearchAndCartContainerWidthConstraint) {
                c.active = NO;
            }
        }
    }
    self.homeSmartSearchTrailingToContainerConstraint = nil;
    self.homeSmartSearchTrailingToCartConstraint = nil;

    self.homeCartButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.homeSmartSearchView.translatesAutoresizingMaskIntoConstraints = NO;

    NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray array];

    // Cart button: starts collapsed; pp_updateHomeCartButtonPresenceAnimated owns reveal/collapse.
    self.homeCartButtonWidthConstraint = [self.homeCartButton.widthAnchor constraintEqualToConstant:0.0];
    self.homeCartButtonHeightConstraint = [self.homeCartButton.heightAnchor constraintEqualToConstant:PPHomeSmartSearchCartButtonSide];
    [constraints addObject:self.homeCartButtonWidthConstraint];
    [constraints addObject:self.homeCartButtonHeightConstraint];
    [constraints addObject:[self.homeCartButton.centerYAnchor constraintEqualToAnchor:self.homeSmartSearchAndCartContainer.centerYAnchor]];
    [constraints addObject:[self.homeCartButton.trailingAnchor constraintEqualToAnchor:self.homeSmartSearchAndCartContainer.trailingAnchor constant:0.0]];

    // Smart search view: full width while the cart slot is collapsed, then shrinks to make room.
    self.homeSmartSearchTrailingToContainerConstraint =
        [self.homeSmartSearchView.trailingAnchor constraintEqualToAnchor:self.homeSmartSearchAndCartContainer.trailingAnchor
                                                                constant:0.0];
    self.homeSmartSearchTrailingToCartConstraint =
        [self.homeSmartSearchView.trailingAnchor constraintEqualToAnchor:self.homeCartButton.leadingAnchor
                                                                constant:-PPHomeSmartSearchCartButtonSpacing];
    [constraints addObject:[self.homeSmartSearchView.leadingAnchor constraintEqualToAnchor:self.homeSmartSearchAndCartContainer.leadingAnchor constant:0.0]];
    [constraints addObject:self.homeSmartSearchTrailingToContainerConstraint];
    [constraints addObject:[self.homeSmartSearchView.topAnchor constraintEqualToAnchor:self.homeSmartSearchAndCartContainer.topAnchor]];
    [constraints addObject:[self.homeSmartSearchView.bottomAnchor constraintEqualToAnchor:self.homeSmartSearchAndCartContainer.bottomAnchor]];

    [NSLayoutConstraint activateConstraints:constraints];

    CGRect frame = self.homeSmartSearchAndCartContainer.frame;
    frame.size.width = width;
    frame.size.height = 48.0;
    self.homeSmartSearchAndCartContainer.frame = frame;
    self.homeSmartSearchAndCartContainer.bounds = (CGRect){CGPointZero, frame.size};
    self.homeSmartSearchAndCartContainer.semanticContentAttribute = PPHomeCurrentSemanticAttribute();
    self.homeSmartSearchView.semanticContentAttribute = PPHomeCurrentSemanticAttribute();

    [self pp_updateHomeCartButtonPresenceAnimated:NO];
    [self pp_updateHomeSmartSearchForScrollView:self.collectionView animated:NO];
    return self.homeSmartSearchAndCartContainer;
}

- (void)pp_openSmartSearch
{
    [[NovaAmbientAssistantCoordinator sharedCoordinator] hideNova];

    PPSearchViewController *searchVC = [PPSearchViewController new];
    PPNavigationController *presentNav = [[PPNavigationController alloc] initWithRootViewController:searchVC];
    presentNav.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:presentNav animated:YES completion:nil];
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

    [self pp_applyHomeSmartSearchPlaceholderToVisiblePremiumSearchCells:placeholder
                                                               animated:animated];
}

- (void)pp_applyHomeSmartSearchPlaceholderToVisiblePremiumSearchCells:(NSString *)placeholder
                                                              animated:(BOOL)animated
{
    if (!self.isViewLoaded || !self.collectionView) {
        return;
    }

    NSString *safePlaceholder = PPSafeString(placeholder);
    if (safePlaceholder.length == 0) {
        return;
    }

    for (UICollectionViewCell *cell in self.collectionView.visibleCells) {
        if (![cell isKindOfClass:PPHomePremiumSearchCell.class]) {
            continue;
        }
        [(PPHomePremiumSearchCell *)cell setQueryText:safePlaceholder
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
    CGFloat height =  48.0;

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
    // Menu is presented natively via button.menu / showsMenuAsPrimaryAction — this selector is kept
    // only so addTarget: references remain valid; it is never reached on iOS 14+.
    (void)sender;
}

- (NSArray<UIMenuElement *> *)pp_buildProfileMenuElements {
    __weak typeof(self) weakSelf = self;
    UIFont *itemFont = [GM boldFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];

    UIAction *(^makeAction)(NSString *, NSString *, PPHomeProfileMenuAction) =
    ^UIAction *(NSString *title, NSString *imageName, PPHomeProfileMenuAction menuAction) {
        UIAction *action = [UIAction actionWithTitle:title ?: @""
                                              image:[UIImage systemImageNamed:imageName]
                                         identifier:nil
                                            handler:^(__kindof UIAction *a) {
            [weakSelf pp_handleProfileMenuAction:menuAction];
        }];
        NSAttributedString *attrTitle = [[NSAttributedString alloc]
            initWithString:title ?: @""
                attributes:@{NSFontAttributeName: itemFont}];
        [action setValue:attrTitle forKey:@"attributedTitle"];
        return action;
    };

    // Account
    UIAction *accountAction = UserManager.sharedManager.currentUser
        ? makeAction(kLang(@"showProfile"), @"person.circle.fill", PPHomeProfileMenuActionProfile)
        : makeAction(kLang(@"go_to_login"), @"person.crop.circle.fill.badge.plus", PPHomeProfileMenuActionLogin);
    UIMenu *accountSection = [UIMenu menuWithTitle:@"" image:nil identifier:nil
                                           options:UIMenuOptionsDisplayInline
                                          children:@[accountAction]];

    // Activity
    NSMutableArray<UIAction *> *activityActions = [NSMutableArray array];
    [activityActions addObject:makeAction(kLang(@"showfav"), @"star.fill", PPHomeProfileMenuActionFavorites)];
    [activityActions addObject:makeAction(kLang(@"myadsTitle"), @"circle.hexagonpath.fill", PPHomeProfileMenuActionMyAds)];
    [activityActions addObject:makeAction(kLang(@"Cart"), @"cart.fill", PPHomeProfileMenuActionCart)];
    [activityActions addObject:makeAction(kLang(@"purchased_profile_menu_title"), @"bag.badge.plus", PPHomeProfileMenuActionPurchased)];
    [activityActions addObject:makeAction(kLang(@"OrderHistory"), @"bag.fill", PPHomeProfileMenuActionOrders)];
    if ([UserManager.sharedManager.currentUser.prodectionStatus isEqualToString:@"active"]) {
        [activityActions addObject:makeAction(kLang(@"showProdection"), @"doc.on.doc.fill", PPHomeProfileMenuActionProduction)];
    }
    UIMenu *activitySection = [UIMenu menuWithTitle:@"" image:nil identifier:nil
                                            options:UIMenuOptionsDisplayInline
                                           children:activityActions];

    // Tools
    UIMenu *toolsSection = [UIMenu menuWithTitle:@"" image:nil identifier:nil
                                         options:UIMenuOptionsDisplayInline
                                        children:@[
        makeAction(kLang(@"Setting"), @"gear", PPHomeProfileMenuActionSettings),
        makeAction(kLang(@"supprot"), @"person.crop.circle.badge.questionmark", PPHomeProfileMenuActionSupport),
    ]];

    NSMutableArray<UIMenuElement *> *sections = [@[accountSection, activitySection, toolsSection] mutableCopy];

    if (UserManager.sharedManager.currentUser) {
        UIAction *logoutAction = [UIAction actionWithTitle:(kLang(@"logout") ?: @"Sign Out")
                                                     image:[UIImage systemImageNamed:@"rectangle.portrait.and.arrow.right"]
                                                identifier:nil
                                                   handler:^(__kindof UIAction *a) {
            [weakSelf pp_handleProfileMenuAction:PPHomeProfileMenuActionLogout];
        }];
        logoutAction.attributes = UIMenuElementAttributesDestructive;
        NSAttributedString *attrTitle = [[NSAttributedString alloc]
            initWithString:(kLang(@"logout") ?: @"Sign Out")
                attributes:@{NSFontAttributeName: itemFont}];
        [logoutAction setValue:attrTitle forKey:@"attributedTitle"];
        UIMenu *logoutSection = [UIMenu menuWithTitle:@"" image:nil identifier:nil
                                              options:UIMenuOptionsDisplayInline
                                             children:@[logoutAction]];
        [sections addObject:logoutSection];
    }

    return sections;
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
            vc.hidesBackButtonWhenOpenedFromHomeDeck = YES;
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }
        case PPHomeProfileMenuActionCart: {
            if (![PPFunc PPUserCheck]) return;
            CartViewController *vc = [CartViewController new];
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }
        case PPHomeProfileMenuActionPurchased: {
            [self pp_openPurchasedItems];
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
        case PPHomeProfileMenuActionLogout: {
            LeaveFeedbackViewController *feedbackVC = [[LeaveFeedbackViewController alloc] init];
            __weak typeof(self) weakSelf = self;
            feedbackVC.onLogout = ^{
                [GM clearUserProfileDefaults];
                [PPFunc reloadAppUI];
            };
            [PPFunc presentSheetFrom:self sheetVC:feedbackVC detentStyle:PPSheetDetentStyle70];
            break;
        }
    }
}

- (void)pp_openPurchasedItems
{
    if (![PPFunc PPUserCheck]) return;
    PurchasedItemsViewController *vc = [PurchasedItemsViewController new];
    [self.navigationController pushViewController:vc animated:YES];
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
    if (!self.isHomeBootstrapped) return;
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

    // Update the existing item's payload in place to preserve its identifier and avoid cell recreation
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
    static const CGFloat kMinHeight  = 48.0;

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

    PPHomePrepareProfileMenuButton(container, self);

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




#pragma mark - Gesture Arbitration

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if ([objc_getAssociatedObject(gestureRecognizer, &PPHomeOrthogonalPanGateMarkerKey) boolValue]) {
        UIPanGestureRecognizer *panGestureRecognizer = (UIPanGestureRecognizer *)gestureRecognizer;
        CGPoint velocity = [panGestureRecognizer velocityInView:gestureRecognizer.view];
        if (fabs(velocity.x) < DBL_EPSILON && fabs(velocity.y) < DBL_EPSILON) {
            velocity = [panGestureRecognizer translationInView:gestureRecognizer.view];
        }

        BOOL hasHorizontalIntent =
            fabs(velocity.x) > fabs(velocity.y) * PPHomeOrthogonalHorizontalIntentRatio;
        return !hasHorizontalIntent;
    }

    if (gestureRecognizer ==
        self.navigationController.interactivePopGestureRecognizer) {

        // Disable on root VC only
        return self.navigationController.viewControllers.count > 1;
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
        shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    BOOL gestureIsGate =
        [objc_getAssociatedObject(gestureRecognizer, &PPHomeOrthogonalPanGateMarkerKey) boolValue];
    BOOL otherGestureIsGate =
        [objc_getAssociatedObject(otherGestureRecognizer, &PPHomeOrthogonalPanGateMarkerKey) boolValue];

    return (gestureIsGate && otherGestureRecognizer == self.collectionView.panGestureRecognizer) ||
           (otherGestureIsGate && gestureRecognizer == self.collectionView.panGestureRecognizer);
}


- (void)PPUniversalCell_tapCard:(PPUniversalCellViewModel *)universalModel {
    id model = universalModel.ModelObject;
    if (!model) return;
    [self pp_openOverlayForObject:model];
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
            __weak typeof(self) weakSelf = self;
            [cart addItem:item
presentingViewController:self
       completion:^(BOOL didAdd, BOOL didCancel) {
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) { return; }
                if (didCancel) {
                    [self updateCartQuantityBadge];
                    [[NSNotificationCenter defaultCenter]
                        postNotificationName:kCartUpdatedNotification
                                      object:nil];
                    return;
                }
                if (!didAdd) {
                    [PPHUD showError:kLang(@"Out of stock")];
                    return;
                }
                if (safeQuantity == 1) {
                    [PPFunc triggerLightHaptic];
                } else {
                    [PPFunc triggerMediumHaptic];
                }
                [self updateCartQuantityBadge];
                [[NSNotificationCenter defaultCenter]
                    postNotificationName:kCartUpdatedNotification
                                  object:nil];
            }];
            return;
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
    [self pp_updateHomeCartButtonPresenceAnimated:YES];
    [self pp_applyHomeCartBadgeCount:count animated:YES];
    [self.homeCartButton setNeedsLayout];
    [self.homeCartButton layoutIfNeeded];
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
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        nav.modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewController:nav animated:YES completion:nil];
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
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:editVC];
        nav.modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewController:nav animated:YES completion:nil];
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

-(void)PPUniversalCell_tapVisibilityToggle:(PPUniversalCellViewModel *)universalModel
{
    if (!PPIsUserLoggedIn) { [UserManager showPromptOnTopController]; return; }
    BOOL nextVisible = !universalModel.isPubliclyVisible;
    void (^handleResult)(NSError * _Nullable error) = ^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:error.localizedDescription ?: kLang(@"listing_visibility_failed")];
                return;
            }
            NSString *message = nextVisible ? kLang(@"listing_visible_success") : kLang(@"listing_hidden_success");
            [AppManager.sharedInstance showSnakBar:message withColor:GM.appPrimaryColor andDuration:0.6 containerView:self.view];
            [AppClasses reloadThisCollectionView:self.collectionView completion:^(BOOL finished) { }];
        });
    };

    if(universalModel.cellSection == CellSectionAds && [universalModel.ModelObject isKindOfClass:[PetAd class]]) {
        PetAd *ad = (PetAd *)universalModel.ModelObject;
        [[PetAdManager sharedManager] updatePetAdID:ad.adID
                                         visibility:(nextVisible ? PetAdVisibilityPublic : PetAdVisibilityHidden)
                                         completion:handleResult];
    } else if(universalModel.cellSection == CellSectionAccessories && [universalModel.ModelObject isKindOfClass:[PetAccessory class]]) {
        PetAccessory *accessory = (PetAccessory *)universalModel.ModelObject;
        [[PetAccessoryManager sharedManager] updateAccessoryID:accessory.accessoryID
                                               showInAppMarket:nextVisible
                                                    completion:handleResult];
    }
}

- (NSString *)pp_chatOwnerIDForViewModel:(PPUniversalCellViewModel *)viewModel
{
    id model = viewModel.ModelObject;
    if ([model isKindOfClass:NSClassFromString(@"PetAd")]) {
        return [model valueForKey:@"ownerID"];
    }
    if ([model isKindOfClass:NSClassFromString(@"ServiceModel")]) {
        return [model valueForKey:@"serviceOwnerID"];
    }
    if ([model respondsToSelector:@selector(ownerID)]) {
        return [model performSelector:@selector(ownerID)];
    }
    if ([model respondsToSelector:@selector(userID)]) {
        return [model performSelector:@selector(userID)];
    }
    return @"";
}

- (void)PPUniversalCell_tapChat:(PPUniversalCellViewModel *)universalModel
{
    if (!PPIsUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }

    NSString *ownerID = [self pp_chatOwnerIDForViewModel:universalModel];
    if (ownerID.length == 0) {
        [PPHUD showInfo:kLang(@"bb_dataview_full_details_contact_unavailable")];
        return;
    }

    NSString *currentUID = UserManager.sharedManager.currentUser.ID ?: PPCurrentFIRAuthUser.uid ?: @"";
    if ([ownerID isEqualToString:currentUID]) {
        [PPHUD showInfo:kLang(@"bb_dataview_full_details_chat_self_unavailable")];
        return;
    }

    [PPHUD showLoading:kLang(@"bb_dataview_full_details_opening_chat")];
    __weak typeof(self) weakSelf = self;
    [UsrMgr getOtherUserModelFromFirestoreWithUID:ownerID completion:^(UserModel * _Nullable user, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) { return; }
            [PPHUD dismiss];

            if (error || !user || user.ID.length == 0) {
                [PPHUD showError:kLang(@"bb_dataview_full_details_contact_unavailable")];
                return;
            }

            [ChManager.sharedManager createOrGetChatThreadWithUser:user
                                                        completion:^(ChatThreadModel * _Nullable thread, NSError * _Nullable chatError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (chatError || !thread) {
                        [PPHUD showError:kLang(@"SomethingWentWrong") subtitle:chatError.localizedDescription ?: @""];
                        return;
                    }
                    [PPOverlayCoordinator pp_openChatThread:thread fromVC:self];
                });
            }];
        });
    }];
}

- (void)PPUniversalCell_tapReport:(PPUniversalCellViewModel *)universalModel
{
    [PPHUD showSuccess:kLang(@"reported_successfully")];
}

- (void)PPUniversalCell_tapSaveForLater:(PPUniversalCellViewModel *)universalModel
{
    NSString *itemID = universalModel.ModelID ?: @"";
    if (itemID.length == 0) {
        [PPHUD showError:kLang(@"SomethingWentWrong")];
        return;
    }
    PPSaveForLaterManager *manager = [PPSaveForLaterManager sharedManager];
    if ([manager isItemSaved:itemID]) {
        CartItem *item = [[CartItem alloc] init];
        item.itemID = itemID;
        item.name = universalModel.title ?: @"";
        [manager removeItem:item];
        [PPHUD showInfo:kLang(@"saved_for_later_removed_toast") ?: @"Removed from saved for later."];
    } else {
        [manager saveViewModelForLater:universalModel];
        [PPHUD showSuccess:kLang(@"saved_for_later_added_toast") ?: @"Saved for later. You can find it in your saved items."];
    }
}

#pragma mark - Background

- (void)pp_applyPremiumHomeBackgroundAppearance
{
    UIColor *backgroundColor =   AppBackgroundClr;
    self.view.backgroundColor = backgroundColor;
    [self pp_installPremiumBackgroundGlowViewsIfNeeded];
    self.pp_premiumBackgroundCanvasView.backgroundColor = backgroundColor;
    self.collectionView.backgroundColor = UIColor.clearColor;
    [self pp_updatePremiumBackgroundGlowAppearance];
}

- (PPHomeAmbientGlowView *)pp_makePremiumBackgroundGlowView
{
    return [[PPHomeAmbientGlowView alloc] initWithFrame:CGRectZero];
}

- (void)pp_installPremiumBackgroundGlowViewsIfNeeded
{
    if (PPHomeUseHeroApex) {
        self.pp_premiumBackgroundCanvasView.hidden = YES;
        if (!self.ambientBackgroundView) {
            self.ambientBackgroundView = [[PPBackgroundView alloc] init];
            self.ambientBackgroundView.translatesAutoresizingMaskIntoConstraints = NO;
            self.ambientBackgroundView.userInteractionEnabled = NO;
            self.ambientBackgroundView.PPHeroApexUseShimmer = NO;
            self.ambientBackgroundView.PPHeroApexUseUnderFingerMotion = NO;
            self.ambientBackgroundView.accentStyle = PPHeroGlassAccentStyleFullScreen;
            //self.ambientBackgroundView.overrideSolidColor = PPHomeSemanticCanvasColor();
            self.ambientBackgroundView.overrideBorders = YES;
            self.ambientBackgroundView.overrideBorderColor = UIColor.clearColor;
            self.ambientBackgroundView.overrideCenterGlowColor = [[UIColor colorNamed:@"NewBg"] colorWithAlphaComponent:1.0];
            self.ambientBackgroundView.overrideBottomGlowColor = [[UIColor colorNamed:@"AppBage"] colorWithAlphaComponent:1.0];
            self.ambientBackgroundView.accentColorOverride = [[UIColor colorNamed:@"AppBage"] colorWithAlphaComponent:1.0];
            self.ambientBackgroundView.overrideSurfureColor = AppBackgroundClr;
            self.ambientBackgroundView.overrideTopGlowColor = [[UIColor colorNamed:@"AppBage"] colorWithAlphaComponent:1.0];

            self.ambientBackgroundView.cornerGlowOpacityMultiplier = 0.22;
            [self.view insertSubview:self.ambientBackgroundView atIndex:0];
            [NSLayoutConstraint activateConstraints:@[
                [self.ambientBackgroundView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
                [self.ambientBackgroundView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
                [self.ambientBackgroundView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
                [self.ambientBackgroundView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
            ]];
        } else if (self.ambientBackgroundView.superview != self.view) {
            [self.view insertSubview:self.ambientBackgroundView atIndex:0];
        }
        self.ambientBackgroundView.hidden = NO;
        [self.view sendSubviewToBack:self.ambientBackgroundView];
    } else {
        if (self.ambientBackgroundView) {
            self.ambientBackgroundView.hidden = YES;
        }
        if (!self.pp_premiumBackgroundCanvasView) {
            UIView *canvasView = [[UIView alloc] initWithFrame:CGRectZero];
            canvasView.translatesAutoresizingMaskIntoConstraints = NO;
            canvasView.userInteractionEnabled = NO;
            canvasView.isAccessibilityElement = NO;
            canvasView.accessibilityElementsHidden = YES;
            canvasView.clipsToBounds = YES;
            canvasView.opaque = YES;
            self.pp_premiumBackgroundCanvasView = canvasView;
            [self.view insertSubview:canvasView atIndex:0];
            [NSLayoutConstraint activateConstraints:@[
                [canvasView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
                [canvasView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
                [canvasView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
                [canvasView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
            ]];
        } else if (self.pp_premiumBackgroundCanvasView.superview != self.view) {
            [self.view insertSubview:self.pp_premiumBackgroundCanvasView atIndex:0];
        }
        self.pp_premiumBackgroundCanvasView.hidden = NO;

        if (!self.pp_premiumBackgroundGlowViewTop) {
            self.pp_premiumBackgroundGlowViewTop = [self pp_makePremiumBackgroundGlowView];
        }
        if (!self.pp_premiumBackgroundGlowViewMid) {
            self.pp_premiumBackgroundGlowViewMid = [self pp_makePremiumBackgroundGlowView];
        }
        if (!self.pp_premiumBackgroundGlowViewBottom) {
            self.pp_premiumBackgroundGlowViewBottom = [self pp_makePremiumBackgroundGlowView];
        }

        for (PPHomeAmbientGlowView *glowView in @[
            self.pp_premiumBackgroundGlowViewBottom,
            self.pp_premiumBackgroundGlowViewMid,
            self.pp_premiumBackgroundGlowViewTop
        ]) {
            if (glowView.superview != self.pp_premiumBackgroundCanvasView) {
                [self.pp_premiumBackgroundCanvasView addSubview:glowView];
            }
        }

        [self.view sendSubviewToBack:self.pp_premiumBackgroundCanvasView];
    }
}

- (void)pp_applyPremiumGlowView:(PPHomeAmbientGlowView *)glowView
                          color:(UIColor *)color
                      peakAlpha:(CGFloat)peakAlpha
                    middleAlpha:(CGFloat)middleAlpha
{
    if (!glowView || !color) {
        return;
    }

    glowView.alpha = 1.0;
    UIColor *resolvedColor = color;
    if (@available(iOS 13.0, *)) {
        resolvedColor = [color resolvedColorWithTraitCollection:self.traitCollection];
    }
    glowView.faded = self.backgroundGlowsFadedByHomeConfig;
    [glowView setNeedsLayout];
    [glowView applyColor:resolvedColor peakAlpha:peakAlpha middleAlpha:middleAlpha];
}

- (void)pp_updatePremiumBackgroundGlowAppearance
{
    if (PPHomeUseHeroApex) {
       /// self.ambientBackgroundView.accentStyle = PPHeroGlassAccentStyleSolid;
       // self.ambientBackgroundView.overrideSolidColor = PPHomeSemanticCanvasColor();
        [self.ambientBackgroundView stopAnimations];
        [self.ambientBackgroundView reapplyPalette];
    } else {
        BOOL isDark = NO;
        if (@available(iOS 12.0, *)) {
            isDark = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
        }

        BOOL reduceTransparency = UIAccessibilityIsReduceTransparencyEnabled();
        BOOL increaseContrast = UIAccessibilityDarkerSystemColorsEnabled();
        CGFloat accessibilityScale = (reduceTransparency || increaseContrast) ? 0.70 : 1.0;

        UIColor *signatureColor = AppPrimaryClrShiner ?: AppPrimaryClr ?: UIColor.systemPinkColor;
        UIColor *centerGlowColor = AppPrimaryClr ?: signatureColor;
        self.pp_premiumBackgroundGlowViewTop.hidden = NO;
        self.pp_premiumBackgroundGlowViewMid.hidden = NO;
        self.pp_premiumBackgroundGlowViewBottom.hidden = NO;
        [self pp_stopPremiumBackgroundGlowMotion];

        [self pp_applyPremiumGlowView:self.pp_premiumBackgroundGlowViewTop
                                color:signatureColor
                            peakAlpha:(isDark ? 0.112 : 0.032) * accessibilityScale
                          middleAlpha:(isDark ? 0.048 : 0.018) * accessibilityScale];

        //[self.pp_premiumBackgroundGlowViewMid pp_setNeedsLayout];
        [self pp_applyPremiumGlowView:self.pp_premiumBackgroundGlowViewMid
                                color:centerGlowColor
                            peakAlpha:(isDark ? 0.074 : 0.021) * accessibilityScale
                          middleAlpha:(isDark ? 0.030 : (self.backgroundGlowsFadedByHomeConfig ? 0.021 : 0.017)) * accessibilityScale];

        [self pp_applyPremiumGlowView:self.pp_premiumBackgroundGlowViewBottom
                                color:signatureColor
                            peakAlpha:(isDark ? 0.16 : 0.040) * accessibilityScale
                          middleAlpha:(isDark ? 0.052 : 0.030) * accessibilityScale];
    }
}

- (void)pp_layoutPremiumBackgroundGlowViews
{
    if (PPHomeUseHeroApex) {
        // Hero Apex fills view via Auto Layout
    } else {
        CGRect bounds = self.view.bounds;
        if (!PPHomeRectIsFiniteAndNotEmpty(bounds)) {
            return;
        }

        CGFloat width = CGRectGetWidth(bounds);
        CGFloat height = CGRectGetHeight(bounds);
        CGFloat safeTop = self.view.safeAreaInsets.top;
        if (!PPHomeFiniteCGFloat(width) || !PPHomeFiniteCGFloat(height) || !PPHomeFiniteCGFloat(safeTop)) {
            return;
        }
        CGSize canvasSize = bounds.size;
        BOOL motionLayoutChanged = (fabs(canvasSize.width - self.premiumBackgroundGlowMotionCanvasSize.width) > 0.5 ||
                                    fabs(canvasSize.height - self.premiumBackgroundGlowMotionCanvasSize.height) > 0.5);
        if (motionLayoutChanged && self.didStartPremiumBackgroundGlowMotion) {
            [self pp_stopPremiumBackgroundGlowMotion];
        }
        self.premiumBackgroundGlowMotionCanvasSize = canvasSize;

        CGFloat topSize = MIN(228.0, MAX(176.0, width * 0.72));
        CGFloat midSize = MIN(340.0, MAX(150.0, width * 0.86));
        CGFloat bottomSize = MIN(260.0, MAX(280.0, width * 1.12));
        if (!PPHomeFiniteCGFloat(topSize) || !PPHomeFiniteCGFloat(midSize) || !PPHomeFiniteCGFloat(bottomSize)) {
            return;
        }
        BOOL isRTL = self.view.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;

        [CATransaction begin];
        [CATransaction setDisableActions:YES];

        self.pp_premiumBackgroundGlowViewTop.bounds = CGRectMake(0.0, 0.0, topSize, topSize);
        self.pp_premiumBackgroundGlowViewTop.center = CGPointMake(
            isRTL ? topSize * 0.22 : width - (topSize * 0.22),
            safeTop + (topSize * 0.10)
        );

        self.pp_premiumBackgroundGlowViewMid.bounds = CGRectMake(0.0, 0.0, midSize, midSize);
        CGFloat middleY = MAX(180.0, height * 0.52);
        if (self.backgroundGlowsFadedByHomeConfig) {
            self.pp_premiumBackgroundGlowViewMid.center = CGPointMake(CGRectGetMidX(bounds) + 40, middleY);
        } else {
            self.pp_premiumBackgroundGlowViewMid.center = CGPointMake(
                isRTL ? width - (midSize * 0.10) : midSize * 0.10,
                middleY
            );
        }

        self.pp_premiumBackgroundGlowViewBottom.bounds = CGRectMake(0.0, 0.0, bottomSize, bottomSize);
        self.pp_premiumBackgroundGlowViewBottom.center = CGPointMake(
            isRTL ? width - (bottomSize * 0.34) : bottomSize * 0.34,
            height - (bottomSize * 0.07)
        );

        [CATransaction commit];

        [self.pp_premiumBackgroundGlowViewTop setNeedsLayout];
        [self.pp_premiumBackgroundGlowViewMid setNeedsLayout];
        [self.pp_premiumBackgroundGlowViewBottom setNeedsLayout];

        if (motionLayoutChanged && self.isHomeScreenVisible) {
            [self pp_beginPremiumBackgroundGlowMotionIfNeeded];
        }
    }
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self pp_layoutPremiumBackgroundGlowViews];



    [self pp_updateHomeSmartSearchTitleViewWidth];
    [self pp_updateHomeLocationTitleViewWidth];

    if (![self pp_shouldDeferHomeLayoutStabilization]) {
        [self pp_stabilizeHomeCollectionLayoutIfNeeded];
    }
    [self pp_installOrthogonalGestureGatesIfNeeded];
    [self pp_prepareVisibleHomeEntranceContentIfNeeded];
    [self pp_positionInitialSelectedMainKindIfNeededAnimated:YES];
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
    [self pp_updateCollectionViewDockBottomInset];
    [self pp_stabilizeHomeCollectionLayoutIfNeeded];
}

- (void)pp_updateCollectionViewDockBottomInset
{
    CGFloat extra = 0.0;
    if ([self.tabBarController isKindOfClass:PPRootTabBarController.class]) {
        extra =
            [(PPRootTabBarController *)self.tabBarController
                pp_currentBottomNavigationContentClearance];
    }
    UIEdgeInsets inset = self.collectionView.contentInset;
    if (fabs(inset.bottom - extra) > 0.5) {
        inset.bottom = extra;
        self.collectionView.contentInset = inset;
        UIEdgeInsets indicator = self.collectionView.scrollIndicatorInsets;
        indicator.bottom = extra;
        self.collectionView.scrollIndicatorInsets = indicator;
    }
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
        self.needsVisibleHomeThemeAppearanceRefresh = YES;
        [self pp_applyHomeCartButtonAppearance];
        [self pp_refreshThemeSensitiveHomeContent];
        [self pp_forceHomeCollectionLayoutRefresh];
    }
}



@end
