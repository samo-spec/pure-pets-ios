//
//  PPBannerCollectionCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 30/09/2025.
//

#import "PPBannerCollectionCell.h"
#import "PPBannersManager.h"
#import "Language.h"
#import <SDWebImage/SDWebImage.h>

static NSString * const kPPHomePromoCarouselPageCellReuseID = @"PPHomePromoCarouselPageCell";
static const CGFloat kPPHomeBannerSectionHeight = 168.0;
static const CGFloat kPPHomeBannerSectionTopInset = 4.0;
static const CGFloat kPPHomeBannerSectionHorizontalInset = 16.0;
static const CGFloat kPPHomeBannerSectionBottomInset = 12.0;
static const CGFloat kPPHomeBannerCellVerticalPadding = 4.0;
static const CGFloat kPPHomePromoCarouselCardWidthFraction = 0.88;
static const CGFloat kPPHomePromoCarouselLineSpacing = 12.0;
static const CGFloat kPPHomePromoCarouselPageControlBottomInset = 10.0;
static const CGFloat kPPHomePromoCarouselPageControlHeight = 20.0;
static const CGFloat kPPHomePromoCarouselViewportEpsilon = 1.0;
static const CGFloat kPPHomePromoCarouselMinScale = 0.96;
static const CGFloat kPPHomePromoCarouselMaxTranslateY = 4.0;

static UIColor *PPPromoColorFromHex(NSString *hexString, UIColor *fallback)
{
    if (![hexString isKindOfClass:NSString.class] || hexString.length == 0) {
        return fallback ?: UIColor.systemOrangeColor;
    }

    NSString *hex = [[hexString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] uppercaseString];
    if ([hex hasPrefix:@"#"]) hex = [hex substringFromIndex:1];
    if (hex.length == 3) {
        unichar c0 = [hex characterAtIndex:0];
        unichar c1 = [hex characterAtIndex:1];
        unichar c2 = [hex characterAtIndex:2];
        hex = [NSString stringWithFormat:@"%C%C%C%C%C%C", c0, c0, c1, c1, c2, c2];
    }
    if (hex.length != 6) {
        return fallback ?: UIColor.systemOrangeColor;
    }

    unsigned rgb = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hex];
    if (![scanner scanHexInt:&rgb]) {
        return fallback ?: UIColor.systemOrangeColor;
    }
    CGFloat r = ((rgb & 0xFF0000) >> 16) / 255.0;
    CGFloat g = ((rgb & 0x00FF00) >> 8) / 255.0;
    CGFloat b = (rgb & 0x0000FF) / 255.0;
    return [UIColor colorWithRed:r green:g blue:b alpha:1.0];
}

static NSString *PPPromoSymbolNameForTapAction(PPBannerOnTapAction action, BOOL isPrimary)
{
    switch (action) {
        case PPBannerOnTapViewAccessory:
            return isPrimary ? @"bag.fill" : @"square.grid.2x2";
        case PPBannerOnTapViewAd:
            return isPrimary ? @"pawprint.fill" : @"eye.fill";
        case PPBannerOnTapOpenUrl:
            return isPrimary ? @"safari.fill" : @"arrow.up.right";
        case PPBannerOnTapCallPhoneNumber:
            return isPrimary ? @"phone.fill" : @"phone.badge.plus";
        case PPBannerOnTapWhatsApp:
            return isPrimary ? @"message.fill" : @"paperplane.fill";
        default:
            return isPrimary ? @"sparkles" : @"chevron.right";
    }
}

static UIColor *PPPromoBlendColor(UIColor *fromColor, UIColor *toColor, CGFloat progress)
{
    if (!fromColor) return toColor ?: UIColor.clearColor;
    if (!toColor) return fromColor;

    progress = MAX(0.0, MIN(1.0, progress));

    CGFloat fr = 0.0, fg = 0.0, fb = 0.0, fa = 0.0;
    CGFloat tr = 0.0, tg = 0.0, tb = 0.0, ta = 0.0;
    [fromColor getRed:&fr green:&fg blue:&fb alpha:&fa];
    [toColor getRed:&tr green:&tg blue:&tb alpha:&ta];

    return [UIColor colorWithRed:(fr + ((tr - fr) * progress))
                           green:(fg + ((tg - fg) * progress))
                            blue:(fb + ((tb - fb) * progress))
                           alpha:(fa + ((ta - fa) * progress))];
}

static void PPPickRandomModernGradient(UIColor **outStart, UIColor **outEnd, UIColor **outAccent) {
    static NSArray<NSArray<NSString *> *> *palettes = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        palettes = @[
            @[@"#FF6B6B", @"#EE5A24", @"#FFE66D"],   // Sunset Coral
            @[@"#4FACFE", @"#00F2FE", @"#B8ECFF"],   // Ocean Blue
            @[@"#A18CD1", @"#764BA2", @"#FBC2EB"],   // Purple Bliss
            @[@"#43E97B", @"#38F9D7", @"#B8FFE0"],   // Fresh Lime
            @[@"#667EEA", @"#764BA2", @"#DDD6FE"],   // Cosmic Indigo
            @[@"#FF9A9E", @"#FECFEF", @"#FFF0F5"],   // Warm Rose
            @[@"#F093FB", @"#F5576C", @"#FFD6E0"],   // Berry Pink
            @[@"#4E54C8", @"#8F94FB", @"#C7C9FF"],   // Indigo Wave
            @[@"#11998E", @"#38EF7D", @"#B8FFD6"],   // Teal Green
            @[@"#FC5C7D", @"#6A82FB", @"#FFD0DB"],   // Candy
            @[@"#ED6EA0", @"#EC8C69", @"#FFD6C4"],   // Peach Bloom
            @[@"#00B4DB", @"#0083B0", @"#B8ECFF"],   // Deep Sea
        ];
    });

    NSUInteger idx = arc4random_uniform((uint32_t)palettes.count);
    NSArray *p = palettes[idx];
    if (outStart)  *outStart  = PPPromoColorFromHex(p[0], UIColor.systemOrangeColor);
    if (outEnd)    *outEnd    = PPPromoColorFromHex(p[1], UIColor.systemOrangeColor);
    if (outAccent) *outAccent = PPPromoColorFromHex(p[2], UIColor.systemOrangeColor);
}

static UIImage *PPPromoFallbackIllustration(PPBannerOnTapAction action)
{
    if (@available(iOS 13.0, *)) {
        NSString *symbolName = PPPromoSymbolNameForTapAction(action, YES);
        if (symbolName.length == 0) {
            symbolName = @"pawprint.fill";
        }

        UIImageSymbolConfiguration *config =
            [UIImageSymbolConfiguration configurationWithPointSize:68
                                                            weight:UIImageSymbolWeightBold];
        UIImage *symbol = [UIImage systemImageNamed:symbolName withConfiguration:config];
        if (symbol) {
            return [symbol imageWithTintColor:[UIColor colorWithWhite:1.0 alpha:0.96]
                                renderingMode:UIImageRenderingModeAlwaysOriginal];
        }
    }

    return nil;
}

@interface PPHomePromoCarouselPageCell : UICollectionViewCell
@property (nonatomic, strong) UIView *shadowContainer;
@property (nonatomic, strong) UIView *cardSurface;
@property (nonatomic, strong) UIImageView *backgroundImageView;
@property (nonatomic, strong) UIView *backgroundTintView;
@property (nonatomic, strong) UIView *contentPanelView;
@property (nonatomic, strong) UIImageView *characterImageView;
@property (nonatomic, strong) UIView *characterGlowView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIView *badgeContainer;
@property (nonatomic, strong) UILabel *badgeLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIView *buttonsContainer;
@property (nonatomic, strong) UIStackView *buttonsRow;
@property (nonatomic, strong) UIButton *primaryButton;
@property (nonatomic, strong) UIButton *secondaryButton;
@property (nonatomic, strong) NSLayoutConstraint *contentLeadingLTRConstraint;
@property (nonatomic, strong) NSLayoutConstraint *contentTrailingRTLConstraint;
@property (nonatomic, strong) NSLayoutConstraint *contentTrailingToImageLTRConstraint;
@property (nonatomic, strong) NSLayoutConstraint *contentLeadingToImageRTLConstraint;
@property (nonatomic, strong) NSLayoutConstraint *imageTrailingLTRConstraint;
@property (nonatomic, strong) NSLayoutConstraint *imageLeadingRTLConstraint;
@property (nonatomic, strong) CAGradientLayer *gradientLayer;
@property (nonatomic, strong) CAGradientLayer *scrimLayer;
@property (nonatomic, strong) CAGradientLayer *highlightLayer;
@property (nonatomic, strong) CAShapeLayer *shapeLayerOne;
@property (nonatomic, strong) CAShapeLayer *shapeLayerTwo;
@property (nonatomic, strong) CAShapeLayer *borderLayer;
@property (nonatomic, strong) PPHomePromoCarouselCard *card;
@property (nonatomic, copy) PPHomePromoCarouselTapBlock onCardTap;
@property (nonatomic, copy) PPHomePromoCarouselTapBlock onPrimaryTap;
@property (nonatomic, copy) PPHomePromoCarouselTapBlock onSecondaryTap;
- (void)pp_setBadgeVisible:(BOOL)visible;
- (void)pp_updateSemanticLayout:(BOOL)isRTL;
- (void)pp_applyPromoButtonStyle:(UIButton *)button
                           title:(NSString *)title
                         primary:(BOOL)isPrimary
                       tapAction:(PPBannerOnTapAction)tapAction;
@end

@interface PPHomePromoCarouselView : UIView <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UIPageControl *pageControl;
@property (nonatomic, strong) NSArray<PPHomePromoCarouselCard *> *cards;
@property (nonatomic, strong) NSTimer *autoScrollTimer;
@property (nonatomic, assign) CGFloat cachedViewportWidth;
@property (nonatomic, copy) PPHomePromoCarouselTapBlock onCardTap;
@property (nonatomic, copy) PPHomePromoCarouselTapBlock onPrimaryTap;
@property (nonatomic, copy) PPHomePromoCarouselTapBlock onSecondaryTap;
- (void)configureWithCards:(NSArray<PPHomePromoCarouselCard *> *)cards
                 onCardTap:(PPHomePromoCarouselTapBlock)onCardTap
              onPrimaryTap:(PPHomePromoCarouselTapBlock)onPrimaryTap
            onSecondaryTap:(PPHomePromoCarouselTapBlock)onSecondaryTap;
- (void)startAutoScroll;
- (void)stopAutoScroll;
- (CGFloat)pp_cardWidth;
- (CGFloat)pp_lineSpacing;
- (CGFloat)pp_sidePeekInset;
- (NSInteger)pp_virtualItemCount;
- (NSInteger)pp_realIndexForVirtualIndex:(NSInteger)virtualIndex;
- (NSInteger)pp_preferredVirtualIndexForRealIndex:(NSInteger)realIndex;
- (NSInteger)pp_centeredVirtualIndex;
- (NSInteger)pp_centeredIndex;
- (void)pp_scrollToIndex:(NSInteger)index animated:(BOOL)animated;
- (void)pp_scrollToVirtualIndex:(NSInteger)virtualIndex animated:(BOOL)animated;
- (void)pp_recenterIfNeeded;
- (void)pp_updateCarouselMetricsPreservingIndex;
- (void)pp_applyCarouselTransforms;
- (CGFloat)pp_cardStride;
- (UIEdgeInsets)pp_collectionInsets;
- (CGFloat)pp_targetContentOffsetXForVirtualIndex:(NSInteger)virtualIndex;
- (CGFloat)pp_viewportWidth;
@end

@interface PPBannerCollectionCell ()
@property (nonatomic, strong) UIView *shadowContainer;
@property (nonatomic, strong) UIView *placeholderView;
@property (nonatomic, strong) PPHomePromoCarouselView *promoCarouselView;
@end

@implementation PPHomePromoCarouselPageCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.contentView.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = NO;
    self.contentView.clipsToBounds = NO;

    _shadowContainer = [UIView new];
    _shadowContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _shadowContainer.backgroundColor = UIColor.clearColor;
    _shadowContainer.layer.shadowColor = [UIColor colorWithWhite:0 alpha:1].CGColor;
    _shadowContainer.layer.shadowOpacity = 0.08;
    _shadowContainer.layer.shadowRadius = 18.0;
    _shadowContainer.layer.shadowOffset = CGSizeMake(0, 10);
    [self.contentView addSubview:_shadowContainer];

    _cardSurface = [UIView new];
    _cardSurface.translatesAutoresizingMaskIntoConstraints = NO;
    _cardSurface.layer.cornerRadius = PPNewCorner;
    _cardSurface.layer.masksToBounds = YES;
    _cardSurface.backgroundColor = UIColor.systemOrangeColor;
    if (@available(iOS 13.0, *)) {
        _cardSurface.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.shadowContainer addSubview:_cardSurface];

    _gradientLayer = [CAGradientLayer layer];
    _gradientLayer.startPoint = CGPointMake(0.0, 0.15);
    _gradientLayer.endPoint = CGPointMake(1.0, 0.95);
    _gradientLayer.needsDisplayOnBoundsChange = YES;
    [_cardSurface.layer insertSublayer:_gradientLayer atIndex:0];

    _shapeLayerOne = [CAShapeLayer layer];
    _shapeLayerOne.fillColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12].CGColor;
    [_cardSurface.layer addSublayer:_shapeLayerOne];

    _shapeLayerTwo = [CAShapeLayer layer];
    _shapeLayerTwo.fillColor = [[UIColor whiteColor] colorWithAlphaComponent:0.04].CGColor;
    [_cardSurface.layer addSublayer:_shapeLayerTwo];

    _scrimLayer = [CAGradientLayer layer];
    _scrimLayer.startPoint = CGPointMake(0.0, 0.18);
    _scrimLayer.endPoint = CGPointMake(1.0, 0.95);
    _scrimLayer.colors = @[
        (__bridge id)[UIColor colorWithWhite:0 alpha:0.05].CGColor,
        (__bridge id)[UIColor colorWithWhite:0 alpha:0.16].CGColor
    ];
    [_cardSurface.layer addSublayer:_scrimLayer];

    _highlightLayer = [CAGradientLayer layer];
    _highlightLayer.startPoint = CGPointMake(0.05, 0.0);
    _highlightLayer.endPoint = CGPointMake(0.95, 1.0);
    _highlightLayer.colors = @[
        (__bridge id)[UIColor colorWithWhite:1 alpha:0.20].CGColor,
        (__bridge id)[UIColor colorWithWhite:1 alpha:0.02].CGColor,
        (__bridge id)[UIColor colorWithWhite:1 alpha:0.0].CGColor
    ];
    [_cardSurface.layer addSublayer:_highlightLayer];

    _borderLayer = [CAShapeLayer layer];
    _borderLayer.fillColor = UIColor.clearColor.CGColor;
    _borderLayer.lineWidth = 1.1;
    _borderLayer.strokeColor = [[UIColor whiteColor] colorWithAlphaComponent:0.14].CGColor;
    [_cardSurface.layer addSublayer:_borderLayer];

    _backgroundImageView = [UIImageView new];
    _backgroundImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _backgroundImageView.contentMode = UIViewContentModeScaleAspectFill;
    _backgroundImageView.alpha = 0.18;
    _backgroundImageView.clipsToBounds = YES;
    [_cardSurface addSubview:_backgroundImageView];

    _backgroundTintView = [UIView new];
    _backgroundTintView.translatesAutoresizingMaskIntoConstraints = NO;
    _backgroundTintView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.04];
    [_cardSurface addSubview:_backgroundTintView];

    _contentPanelView = [UIView new];
    _contentPanelView.translatesAutoresizingMaskIntoConstraints = NO;
    _contentPanelView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.10];
    _contentPanelView.layer.cornerRadius = PPCornerMedium;
    _contentPanelView.layer.borderWidth = 1.0;
    _contentPanelView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12].CGColor;
    _contentPanelView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        _contentPanelView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_cardSurface addSubview:_contentPanelView];

    UIButton *panelTapButton = [UIButton buttonWithType:UIButtonTypeCustom];
    panelTapButton.translatesAutoresizingMaskIntoConstraints = NO;
    panelTapButton.backgroundColor = UIColor.clearColor;
    [panelTapButton addTarget:self action:@selector(cardTapped:) forControlEvents:UIControlEventTouchUpInside];
    [_contentPanelView addSubview:panelTapButton];

    _contentStack = [[UIStackView alloc] init];
    _contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    _contentStack.axis = UILayoutConstraintAxisVertical;
    _contentStack.spacing = 8.0;
    _contentStack.alignment = UIStackViewAlignmentFill;
    [_contentPanelView addSubview:_contentStack];

    _badgeContainer = [UIView new];
    _badgeContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _badgeContainer.backgroundColor = [UIColor colorWithWhite:1 alpha:0.18];
    _badgeContainer.layer.cornerRadius = 15.0;
    _badgeContainer.layer.borderWidth = 0.0;
    _badgeContainer.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.14].CGColor;
    _badgeContainer.layer.masksToBounds = YES;

    _badgeLabel = [UILabel new];
    _badgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _badgeLabel.font = [GM boldFontWithSize:12];
    _badgeLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.98];
    [_badgeContainer addSubview:_badgeLabel];
    [_contentStack addArrangedSubview:_badgeContainer];
    _badgeContainer.hidden = YES;
    _badgeLabel.hidden = YES;
    _titleLabel = [UILabel new];
    _titleLabel.numberOfLines = 2;
    _titleLabel.font = [GM boldFontWithSize:19];
    _titleLabel.textColor = UIColor.whiteColor;
    _titleLabel.adjustsFontForContentSizeCategory = YES;
    _titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_contentStack addArrangedSubview:_titleLabel];

    _subtitleLabel = [UILabel new];
    _subtitleLabel.numberOfLines = 2;
    _subtitleLabel.font = [GM MidFontWithSize:13.0];
    _subtitleLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.88];
    _subtitleLabel.adjustsFontForContentSizeCategory = YES;
    _subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_contentStack addArrangedSubview:_subtitleLabel];

    _buttonsContainer = [UIView new];
    _buttonsContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [_contentStack addArrangedSubview:_buttonsContainer];

    _buttonsRow = [[UIStackView alloc] init];
    _buttonsRow.axis = UILayoutConstraintAxisHorizontal;
    _buttonsRow.spacing = 8.0;
    _buttonsRow.alignment = UIStackViewAlignmentCenter;
    _buttonsRow.distribution = UIStackViewDistributionFill;
    _buttonsRow.translatesAutoresizingMaskIntoConstraints = NO;
    [_buttonsContainer addSubview:_buttonsRow];

    _primaryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _primaryButton.translatesAutoresizingMaskIntoConstraints = NO;
    _primaryButton.titleLabel.font = [GM boldFontWithSize:14];
    [_primaryButton setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_primaryButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_primaryButton addTarget:self action:@selector(primaryButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [_buttonsRow addArrangedSubview:_primaryButton];
    [_primaryButton.heightAnchor constraintEqualToConstant:40.0].active = YES;
    [_primaryButton.widthAnchor constraintGreaterThanOrEqualToConstant:48.0].active = YES;

    _secondaryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _secondaryButton.translatesAutoresizingMaskIntoConstraints = NO;
    _secondaryButton.titleLabel.font = [GM MidFontWithSize:13];
    [_secondaryButton setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_secondaryButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_secondaryButton addTarget:self action:@selector(secondaryButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [_buttonsRow addArrangedSubview:_secondaryButton];
    [_secondaryButton.heightAnchor constraintEqualToConstant:40.0].active = YES;
    [_secondaryButton.widthAnchor constraintGreaterThanOrEqualToConstant:48.0].active = YES;

    _characterGlowView = [UIView new];
    _characterGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    _characterGlowView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.09];
    _characterGlowView.layer.cornerRadius = 56.0;
    _characterGlowView.layer.borderWidth = 1.0;
    _characterGlowView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.10].CGColor;
    _characterGlowView.layer.masksToBounds = YES;
    _characterGlowView.userInteractionEnabled = NO;
    [_cardSurface addSubview:_characterGlowView];

    _characterImageView = [UIImageView new];
    _characterImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _characterImageView.contentMode = UIViewContentModeScaleAspectFit;
    _characterImageView.clipsToBounds = YES;
    [_cardSurface addSubview:_characterImageView];

     

    _contentLeadingLTRConstraint = [self.contentPanelView.leadingAnchor constraintEqualToAnchor:_cardSurface.leadingAnchor constant:16.0];
    _contentTrailingRTLConstraint = [self.contentPanelView.trailingAnchor constraintEqualToAnchor:_cardSurface.trailingAnchor constant:-16.0];
    _contentTrailingToImageLTRConstraint = [self.contentPanelView.trailingAnchor constraintLessThanOrEqualToAnchor:_characterGlowView.leadingAnchor constant:-18.0];
    _contentLeadingToImageRTLConstraint = [self.contentPanelView.leadingAnchor constraintGreaterThanOrEqualToAnchor:_characterGlowView.trailingAnchor constant:18.0];
    _imageTrailingLTRConstraint = [_characterGlowView.trailingAnchor constraintEqualToAnchor:_cardSurface.trailingAnchor constant:-12.0];
    _imageLeadingRTLConstraint = [_characterGlowView.leadingAnchor constraintEqualToAnchor:_cardSurface.leadingAnchor constant:12.0];

    [NSLayoutConstraint activateConstraints:@[
        [_shadowContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [_shadowContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [_shadowContainer.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [_shadowContainer.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

        [_cardSurface.leadingAnchor constraintEqualToAnchor:_shadowContainer.leadingAnchor],
        [_cardSurface.trailingAnchor constraintEqualToAnchor:_shadowContainer.trailingAnchor],
        [_cardSurface.topAnchor constraintEqualToAnchor:_shadowContainer.topAnchor],
        [_cardSurface.bottomAnchor constraintEqualToAnchor:_shadowContainer.bottomAnchor],

        [_backgroundImageView.leadingAnchor constraintEqualToAnchor:_cardSurface.leadingAnchor],
        [_backgroundImageView.trailingAnchor constraintEqualToAnchor:_cardSurface.trailingAnchor],
        [_backgroundImageView.topAnchor constraintEqualToAnchor:_cardSurface.topAnchor],
        [_backgroundImageView.bottomAnchor constraintEqualToAnchor:_cardSurface.bottomAnchor],

        [_backgroundTintView.leadingAnchor constraintEqualToAnchor:_cardSurface.leadingAnchor],
        [_backgroundTintView.trailingAnchor constraintEqualToAnchor:_cardSurface.trailingAnchor],
        [_backgroundTintView.topAnchor constraintEqualToAnchor:_cardSurface.topAnchor],
        [_backgroundTintView.bottomAnchor constraintEqualToAnchor:_cardSurface.bottomAnchor],

       

        [_contentPanelView.topAnchor constraintEqualToAnchor:_cardSurface.topAnchor constant:12.0],
        [_contentPanelView.bottomAnchor constraintLessThanOrEqualToAnchor:_cardSurface.bottomAnchor constant:-12.0],
        [_contentPanelView.widthAnchor constraintLessThanOrEqualToAnchor:_cardSurface.widthAnchor multiplier:0.82],

        [panelTapButton.leadingAnchor constraintEqualToAnchor:_contentPanelView.leadingAnchor],
        [panelTapButton.trailingAnchor constraintEqualToAnchor:_contentPanelView.trailingAnchor],
        [panelTapButton.topAnchor constraintEqualToAnchor:_contentPanelView.topAnchor],
        [panelTapButton.bottomAnchor constraintEqualToAnchor:_contentPanelView.bottomAnchor],

        [_contentStack.leadingAnchor constraintEqualToAnchor:_contentPanelView.leadingAnchor constant:14.0],
        [_contentStack.trailingAnchor constraintEqualToAnchor:_contentPanelView.trailingAnchor constant:-14.0],
        [_contentStack.topAnchor constraintEqualToAnchor:_contentPanelView.topAnchor constant:14.0],
        [_contentStack.bottomAnchor constraintEqualToAnchor:_contentPanelView.bottomAnchor constant:-14.0],

        [_badgeContainer.heightAnchor constraintEqualToConstant:0.0],

        [_badgeLabel.leadingAnchor constraintEqualToAnchor:_badgeContainer.leadingAnchor constant:12.0],
        [_badgeLabel.trailingAnchor constraintEqualToAnchor:_badgeContainer.trailingAnchor constant:-12.0],
        [_badgeLabel.topAnchor constraintEqualToAnchor:_badgeContainer.topAnchor constant:6.0],
        [_badgeLabel.bottomAnchor constraintEqualToAnchor:_badgeContainer.bottomAnchor constant:-6.0],

        [_buttonsRow.leadingAnchor constraintEqualToAnchor:_buttonsContainer.leadingAnchor],
        [_buttonsRow.topAnchor constraintEqualToAnchor:_buttonsContainer.topAnchor],
        [_buttonsRow.bottomAnchor constraintEqualToAnchor:_buttonsContainer.bottomAnchor],
        [_buttonsRow.trailingAnchor constraintLessThanOrEqualToAnchor:_buttonsContainer.trailingAnchor],

        [_characterGlowView.centerYAnchor constraintEqualToAnchor:_cardSurface.centerYAnchor constant:4.0],
        [_characterGlowView.widthAnchor constraintEqualToConstant:112.0],
        [_characterGlowView.heightAnchor constraintEqualToConstant:112.0],

        [_characterImageView.centerXAnchor constraintEqualToAnchor:_characterGlowView.centerXAnchor],
        [_characterImageView.centerYAnchor constraintEqualToAnchor:_characterGlowView.centerYAnchor constant:4.0],
        [_characterImageView.widthAnchor constraintEqualToConstant:122.0],
        [_characterImageView.heightAnchor constraintEqualToConstant:122.0],
    ]];

    [self.contentStack setCustomSpacing:12.0 afterView:_badgeContainer];
    [self.contentStack setCustomSpacing:8.0 afterView:_titleLabel];
    [self.contentStack setCustomSpacing:12.0 afterView:_subtitleLabel];

    [_contentPanelView bringSubviewToFront:_contentStack];
    [_cardSurface bringSubviewToFront:_characterGlowView];
    [_cardSurface bringSubviewToFront:_characterImageView];
    [_cardSurface bringSubviewToFront:_contentPanelView];

    [self pp_updateSemanticLayout:Language.isRTL];
    [self pp_setBadgeVisible:NO];

    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    self.shadowContainer.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.shadowContainer.bounds cornerRadius:self.cardSurface.layer.cornerRadius].CGPath;

    self.gradientLayer.frame = self.cardSurface.bounds;
    self.scrimLayer.frame = self.cardSurface.bounds;
    self.highlightLayer.frame = self.cardSurface.bounds;
    self.shapeLayerOne.frame = self.cardSurface.bounds;
    self.shapeLayerTwo.frame = self.cardSurface.bounds;
    self.borderLayer.frame = self.cardSurface.bounds;
    self.borderLayer.path =
        [UIBezierPath bezierPathWithRoundedRect:CGRectInset(self.cardSurface.bounds, 0.5, 0.5)
                                   cornerRadius:self.cardSurface.layer.cornerRadius].CGPath;
    for (UIButton *button in @[self.primaryButton, self.secondaryButton]) {
        CGFloat radius = CGRectGetHeight(button.bounds) * 0.5;
        button.layer.cornerRadius = radius;
        button.layer.shadowPath =
            [UIBezierPath bezierPathWithRoundedRect:button.bounds cornerRadius:radius].CGPath;
    }
    self.characterGlowView.layer.cornerRadius = CGRectGetHeight(self.characterGlowView.bounds) * 0.5;

    CGRect bounds = self.cardSurface.bounds;
    BOOL isRTL = Language.isRTL;
    CGFloat dominantBlobX = isRTL ? (-bounds.size.width * 0.15) : (bounds.size.width * 0.50);
    CGFloat haloBlobX = isRTL ? (bounds.size.width * 0.04) : (bounds.size.width * 0.61);

    UIBezierPath *shape1 = [UIBezierPath bezierPath];
    [shape1 appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(dominantBlobX,
                                                                         -bounds.size.height * 0.10,
                                                                         bounds.size.width * 0.58,
                                                                         bounds.size.height * 1.05)]];
    self.shapeLayerOne.path = shape1.CGPath;

    UIBezierPath *shape2 = [UIBezierPath bezierPath];
    [shape2 appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(haloBlobX,
                                                                         bounds.size.height * 0.24,
                                                                         bounds.size.width * 0.28,
                                                                         bounds.size.height * 0.42)]];
    self.shapeLayerTwo.path = shape2.CGPath;
}

- (void)pp_setBadgeVisible:(BOOL)visible
{
    self.badgeContainer.hidden = !visible;
}

- (void)pp_updateSemanticLayout:(BOOL)isRTL
{
    UISemanticContentAttribute semantic = GM.setSemantic;

    self.contentView.semanticContentAttribute = semantic;
    self.shadowContainer.semanticContentAttribute = semantic;
    self.cardSurface.semanticContentAttribute = semantic;
    self.contentPanelView.semanticContentAttribute = semantic;
    self.contentStack.semanticContentAttribute = semantic;
    self.buttonsContainer.semanticContentAttribute = semantic;
    self.buttonsRow.semanticContentAttribute = semantic;
    self.primaryButton.semanticContentAttribute = semantic;
    self.secondaryButton.semanticContentAttribute = semantic;
    self.titleLabel.semanticContentAttribute = semantic;
    self.subtitleLabel.semanticContentAttribute = semantic;
    self.badgeLabel.semanticContentAttribute = semantic;

    self.titleLabel.textAlignment = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    self.subtitleLabel.textAlignment = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    self.badgeLabel.textAlignment = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    self.primaryButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    self.secondaryButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;

    self.contentLeadingLTRConstraint.active = NO;
    self.contentTrailingRTLConstraint.active = NO;
    self.contentTrailingToImageLTRConstraint.active = NO;
    self.contentLeadingToImageRTLConstraint.active = NO;
    self.imageTrailingLTRConstraint.active = NO;
    self.imageLeadingRTLConstraint.active = NO;

    if (isRTL) {
        self.contentTrailingRTLConstraint.active = YES;
        self.contentLeadingToImageRTLConstraint.active = YES;
        self.imageLeadingRTLConstraint.active = YES;
    } else {
        self.contentLeadingLTRConstraint.active = YES;
        self.contentTrailingToImageLTRConstraint.active = YES;
        self.imageTrailingLTRConstraint.active = YES;
    }
}

-(void)prepareForReuse
{
    [super prepareForReuse];
    self.card = nil;
    self.onCardTap = nil;
    self.onPrimaryTap = nil;
    self.onSecondaryTap = nil;
    [self.backgroundImageView sd_cancelCurrentImageLoad];
    [self.characterImageView sd_cancelCurrentImageLoad];
    self.badgeLabel.text = @"";
    self.titleLabel.text = @"";
    self.subtitleLabel.text = @"";
    self.subtitleLabel.hidden = NO;
    self.primaryButton.hidden = NO;
    self.secondaryButton.hidden = YES;
    self.primaryButton.configuration = nil;
    self.secondaryButton.configuration = nil;
    self.primaryButton.configurationUpdateHandler = nil;
    self.secondaryButton.configurationUpdateHandler = nil;
    self.buttonsRow.hidden = NO;
    self.buttonsContainer.hidden = NO;
    self.backgroundImageView.image = nil;
    self.backgroundImageView.alpha = 0.0;
    self.characterImageView.image = nil;
    self.backgroundTintView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.04];
    self.characterGlowView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.09];
    self.characterGlowView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.10].CGColor;
    self.contentPanelView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.10];
    self.contentPanelView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12].CGColor;
    self.shadowContainer.layer.shadowColor = [UIColor colorWithWhite:0 alpha:1].CGColor;
    self.gradientLayer.hidden = NO;
    self.shapeLayerOne.hidden = NO;
    self.shapeLayerTwo.hidden = NO;
    self.scrimLayer.hidden = NO;
    self.highlightLayer.hidden = NO;
    self.backgroundTintView.hidden = NO;
    self.cardSurface.backgroundColor = UIColor.systemOrangeColor;
    [self pp_setBadgeVisible:NO];
    [self pp_updateSemanticLayout:Language.isRTL];
}

- (void)configureWithCard:(PPHomePromoCarouselCard *)card
                onCardTap:(PPHomePromoCarouselTapBlock)onCardTap
             onPrimaryTap:(PPHomePromoCarouselTapBlock)onPrimaryTap
           onSecondaryTap:(PPHomePromoCarouselTapBlock)onSecondaryTap
{
    self.card = card;
    self.onCardTap = onCardTap;
    self.onPrimaryTap = onPrimaryTap;
    self.onSecondaryTap = onSecondaryTap;

    BOOL isRTL = Language.isRTL;
    [self pp_updateSemanticLayout:isRTL];

    BOOL hasBackgroundImage = (card.backgroundImageURL.absoluteString.length > 0);

    if (hasBackgroundImage) {
        // Background image mode — show image cleanly, no color overlays
        self.backgroundImageView.alpha = 1.0;
        [self.backgroundImageView sd_setImageWithURL:card.backgroundImageURL placeholderImage:nil];
        self.gradientLayer.hidden = YES;
        self.shapeLayerOne.hidden = YES;
        self.shapeLayerTwo.hidden = YES;
        self.scrimLayer.hidden = YES;
        self.highlightLayer.hidden = YES;
        self.backgroundTintView.hidden = YES;
        self.cardSurface.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
        self.contentPanelView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.26];
        self.contentPanelView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.16].CGColor;
        self.characterGlowView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.16];
        self.characterGlowView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.10].CGColor;
        self.shadowContainer.layer.shadowColor = [UIColor colorWithWhite:0 alpha:1].CGColor;
    } else {
        // Gradient mode — use card colors or random modern gradient
        UIColor *startColor, *endColor, *accentColor;
        BOOL hasCardColors = (card.startColorHex.length > 0 && card.endColorHex.length > 0);
        if (hasCardColors) {
            startColor  = PPPromoColorFromHex(card.startColorHex, nil);
            endColor    = PPPromoColorFromHex(card.endColorHex, nil);
            accentColor = PPPromoColorFromHex(card.accentColorHex, nil);
        } else {
            PPPickRandomModernGradient(&startColor, &endColor, &accentColor);
        }

        UIColor *deepTone = PPPromoBlendColor(startColor, [UIColor colorWithWhite:0.0 alpha:1.0], 0.14);
        UIColor *softTone = PPPromoBlendColor(startColor, accentColor, 0.34);

        self.gradientLayer.hidden = NO;
        self.shapeLayerOne.hidden = NO;
        self.shapeLayerTwo.hidden = NO;
        self.scrimLayer.hidden = NO;
        self.highlightLayer.hidden = NO;
        self.backgroundTintView.hidden = NO;

        self.gradientLayer.colors = @[
            (__bridge id)deepTone.CGColor,
            (__bridge id)softTone.CGColor,
            (__bridge id)endColor.CGColor
        ];
        self.shapeLayerOne.fillColor = [accentColor colorWithAlphaComponent:0.16].CGColor;
        self.shapeLayerTwo.fillColor = [UIColor.whiteColor colorWithAlphaComponent:0.06].CGColor;
        self.backgroundTintView.backgroundColor = [deepTone colorWithAlphaComponent:0.06];
        self.contentPanelView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
        self.contentPanelView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.13].CGColor;
        self.characterGlowView.backgroundColor = [accentColor colorWithAlphaComponent:0.14];
        self.characterGlowView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.10].CGColor;
        self.shadowContainer.layer.shadowColor = [PPPromoBlendColor(endColor, UIColor.blackColor, 0.25) CGColor];
        self.cardSurface.backgroundColor = deepTone;

        self.backgroundImageView.alpha = 0.0;
        self.backgroundImageView.image = nil;
    }

    NSString *badgeText = [card localizedBadgeText];
    self.badgeLabel.text = badgeText;
    [self pp_setBadgeVisible:(badgeText.length > 0)];

    self.titleLabel.text = [card localizedTitleText];
    self.subtitleLabel.text = [card localizedSubtitleText];
    self.subtitleLabel.hidden = (self.subtitleLabel.text.length == 0);

    BOOL showPrimary = [card showsPrimaryButton];
    BOOL showSecondary = [card showsSecondaryButton];
    self.primaryButton.hidden = !showPrimary;
    self.secondaryButton.hidden = !showSecondary;
    self.buttonsContainer.hidden = (!showPrimary && !showSecondary);
    self.buttonsRow.hidden = (!showPrimary && !showSecondary);
    if (showPrimary) {
        [self pp_applyPromoButtonStyle:self.primaryButton
                                title:[card localizedPrimaryButtonTitle]
                              primary:YES
                            tapAction:card.primaryButtonTapAction];
    }
    if (showSecondary) {
        [self pp_applyPromoButtonStyle:self.secondaryButton
                                title:[card localizedSecondaryButtonTitle]
                              primary:NO
                            tapAction:card.secondaryButtonTapAction];
    }

    UIImage *fallbackCharacter = PPPromoFallbackIllustration(card.cardTapAction);
    if (card.characterImageURL.absoluteString.length > 0) {
        [self.characterImageView sd_setImageWithURL:card.characterImageURL
                                   placeholderImage:fallbackCharacter];
    } else {
        self.characterImageView.image = fallbackCharacter;
    }

    [self setNeedsLayout];
}

// New implementation
-(void)pp_applyPromoButtonStyle:(UIButton *)button
                          title:(NSString *)title
                        primary:(BOOL)isPrimary
                      tapAction:(PPBannerOnTapAction)tapAction
{
    NSString *safeTitle = title ?: @"";
    if (safeTitle.length == 0) {
        safeTitle = kLang(@"Open") ?: @"Open";
    }

    UIColor *primaryText = AppPrimaryTextClr ?: [UIColor colorWithRed:0.10 green:0.11 blue:0.13 alpha:1.0];
    UIColor *secondaryText = AppForgroundColr;
    NSString *symbolName = PPPromoSymbolNameForTapAction(tapAction, isPrimary);

    UIImage *icon = nil;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *imgCfg =
        [UIImageSymbolConfiguration configurationWithPointSize:(isPrimary ? 14 : 13)
                                                        weight:(isPrimary ? UIImageSymbolWeightBold : UIImageSymbolWeightSemibold)];
        icon = [UIImage systemImageNamed:symbolName.length > 0 ? symbolName : @"sparkles"
                           withConfiguration:imgCfg];
    }

    button.adjustsImageWhenHighlighted = NO;
    button.configurationUpdateHandler = nil;

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *cfg = isPrimary
        ? [UIButtonConfiguration filledButtonConfiguration]
        : [UIButtonConfiguration tintedButtonConfiguration];

        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(10, 16, 10, 16);
        cfg.image = icon;
        cfg.imagePadding = 6;
        cfg.imagePlacement = Language.isRTL ? NSDirectionalRectEdgeTrailing : NSDirectionalRectEdgeLeading;
        cfg.titleLineBreakMode = NSLineBreakByTruncatingTail;

        cfg.attributedTitle = [[NSAttributedString alloc] initWithString:safeTitle
                                                              attributes:@{
            NSFontAttributeName : (isPrimary ? [GM boldFontWithSize:14] : [GM MidFontWithSize:13]),
            NSForegroundColorAttributeName : (isPrimary ? primaryText : secondaryText)
        }];

        if (isPrimary) {
            cfg.baseBackgroundColor = [AppForgroundColr colorWithAlphaComponent:0.67];
            cfg.baseForegroundColor = primaryText;
        } else {
            cfg.baseBackgroundColor = [AppForgroundColr colorWithAlphaComponent:0.14];
            cfg.baseForegroundColor = secondaryText;
        }

        button.configuration = cfg;
        button.contentEdgeInsets = UIEdgeInsetsZero;

    } else {

        // Clear configuration for legacy path
        button.configuration = nil;

        [button setTitle:safeTitle forState:UIControlStateNormal];
        [button setTitleColor:(isPrimary ? primaryText : secondaryText) forState:UIControlStateNormal];
        button.titleLabel.font = isPrimary ? [GM boldFontWithSize:14] : [GM MidFontWithSize:13];
        [button setImage:icon forState:UIControlStateNormal];
        button.tintColor = isPrimary ? primaryText : secondaryText;

        button.semanticContentAttribute = Language.isRTL
        ? UISemanticContentAttributeForceRightToLeft
        : UISemanticContentAttributeForceLeftToRight;

        button.backgroundColor = isPrimary
        ? [UIColor colorWithWhite:1 alpha:0.97]
        : [UIColor colorWithWhite:1 alpha:0.14];

        button.layer.cornerRadius = 20.0;
        button.layer.borderWidth = isPrimary ? 0.0 : 1.0;
        button.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.16].CGColor;
        button.layer.masksToBounds = NO;
        button.contentEdgeInsets = UIEdgeInsetsMake(10, 16, 10, 16);
    }

    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
    if (!isPrimary) {
        button.layer.borderWidth = 1.0;
        button.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.16].CGColor;
    } else {
        button.layer.borderWidth = 0.0;
    }
    button.layer.shadowColor = UIColor.blackColor.CGColor;
    button.layer.shadowOpacity = isPrimary ? 0.12f : 0.0f;
    button.layer.shadowRadius = isPrimary ? 8.0f : 0.0f;
    button.layer.shadowOffset = isPrimary ? CGSizeMake(0.0, 4.0) : CGSizeZero;

    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;

    [button setNeedsLayout];
    [button layoutIfNeeded];
}

- (void)cardTapped:(UIButton *)sender
{
    (void)sender;
    if (self.card && self.onCardTap) self.onCardTap(self.card);
}

- (void)primaryButtonTapped:(UIButton *)sender
{
    (void)sender;
    if (self.card && self.onPrimaryTap) self.onPrimaryTap(self.card);
}

- (void)secondaryButtonTapped:(UIButton *)sender
{
    (void)sender;
    if (self.card && self.onSecondaryTap) self.onSecondaryTap(self.card);
}

@end

@implementation PPHomePromoCarouselView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = NO;
    self.layer.masksToBounds = NO;
    self.cards = @[];

    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.minimumLineSpacing = kPPHomePromoCarouselLineSpacing;
    layout.minimumInteritemSpacing = 0;

    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    _collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    _collectionView.backgroundColor = UIColor.clearColor;
    if (@available(iOS 11.0, *)) {
        _collectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    _collectionView.pagingEnabled = NO;
    _collectionView.showsHorizontalScrollIndicator = NO;
    _collectionView.decelerationRate = UIScrollViewDecelerationRateFast;
    _collectionView.directionalLockEnabled = YES;
    _collectionView.alwaysBounceHorizontal = YES;
    _collectionView.clipsToBounds = NO;
    _collectionView.delegate = self;
    _collectionView.dataSource = self;
    [_collectionView registerClass:PPHomePromoCarouselPageCell.class forCellWithReuseIdentifier:kPPHomePromoCarouselPageCellReuseID];
    [self addSubview:_collectionView];

    _pageControl = [UIPageControl new];
    _pageControl.translatesAutoresizingMaskIntoConstraints = NO;
    _pageControl.userInteractionEnabled = NO;
    _pageControl.hidesForSinglePage = YES;
    _pageControl.currentPageIndicatorTintColor = [UIColor colorWithWhite:1 alpha:0.95];
    _pageControl.pageIndicatorTintColor = [UIColor colorWithWhite:1 alpha:0.34];
    if (@available(iOS 14.0, *)) {
        _pageControl.backgroundStyle = UIPageControlBackgroundStyleMinimal;
    }
    _pageControl.backgroundColor = UIColor.clearColor;
    _pageControl.transform = CGAffineTransformMakeScale(0.84, 0.84);
    [_pageControl setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [self addSubview:_pageControl];
    _pageControl.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    [NSLayoutConstraint activateConstraints:@[
        [_collectionView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_collectionView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_collectionView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_collectionView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [_pageControl.widthAnchor constraintEqualToConstant:160],
        [_pageControl.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:kPPHomePromoCarouselPageControlBottomInset*2],
        [_pageControl.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-8],
        [_pageControl.heightAnchor constraintEqualToConstant:kPPHomePromoCarouselPageControlHeight],
    ]];

    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.bounds);
    if (width <= 0.0) {
        width = CGRectGetWidth(self.collectionView.bounds);
    }
    width = floor(width);

    if (width > 0.0 && fabs(width - self.cachedViewportWidth) > kPPHomePromoCarouselViewportEpsilon) {
        self.cachedViewportWidth = width;
        [self pp_updateCarouselMetricsPreservingIndex];
        [self.collectionView.collectionViewLayout invalidateLayout];
    }
    [self pp_applyCarouselTransforms];
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window) {
        [self startAutoScroll];
    } else {
        [self stopAutoScroll];
    }
}

- (void)configureWithCards:(NSArray<PPHomePromoCarouselCard *> *)cards
                 onCardTap:(PPHomePromoCarouselTapBlock)onCardTap
              onPrimaryTap:(PPHomePromoCarouselTapBlock)onPrimaryTap
            onSecondaryTap:(PPHomePromoCarouselTapBlock)onSecondaryTap
{
    [self stopAutoScroll];
    self.cards = cards ?: @[];
    self.onCardTap = onCardTap;
    self.onPrimaryTap = onPrimaryTap;
    self.onSecondaryTap = onSecondaryTap;
    self.cachedViewportWidth = 0.0;

    self.pageControl.numberOfPages = self.cards.count;
    self.pageControl.currentPage = 0;
    self.collectionView.alwaysBounceHorizontal = self.cards.count > 1;
    [self.collectionView reloadData];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self layoutIfNeeded];
        [self.collectionView layoutIfNeeded];
        self.cachedViewportWidth = floor([self pp_viewportWidth]);
        [self pp_updateCarouselMetricsPreservingIndex];
        [self pp_scrollToIndex:0 animated:NO];
        [self pp_applyCarouselTransforms];
        [self startAutoScroll];
    });
}

- (void)startAutoScroll
{
    [self stopAutoScroll];
    if (self.cards.count <= 1) return;

    NSTimeInterval interval = MAX(2.0, self.cards.firstObject.autoScrollInterval);
    self.autoScrollTimer = [NSTimer timerWithTimeInterval:interval
                                                   target:self
                                                 selector:@selector(scrollToNextPage)
                                                 userInfo:nil
                                                  repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.autoScrollTimer forMode:NSRunLoopCommonModes];
}

- (void)stopAutoScroll
{
    [self.autoScrollTimer invalidate];
    self.autoScrollTimer = nil;
}

- (void)scrollToNextPage
{
    if (self.cards.count <= 1) return;
    NSInteger currentVirtual = [self pp_centeredVirtualIndex];
    NSInteger nextVirtual = currentVirtual + 1;
    if (nextVirtual >= [self pp_virtualItemCount]) {
        nextVirtual = [self pp_preferredVirtualIndexForRealIndex:0];
    }
    [self pp_scrollToVirtualIndex:nextVirtual animated:YES];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    (void)collectionView;
    (void)section;
    return [self pp_virtualItemCount];
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    PPHomePromoCarouselPageCell *cell =
        [collectionView dequeueReusableCellWithReuseIdentifier:kPPHomePromoCarouselPageCellReuseID forIndexPath:indexPath];

    NSInteger realIndex = [self pp_realIndexForVirtualIndex:indexPath.item];
    PPHomePromoCarouselCard *card = self.cards[realIndex];
    [cell configureWithCard:card
                  onCardTap:self.onCardTap
               onPrimaryTap:self.onPrimaryTap
             onSecondaryTap:self.onSecondaryTap];
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)layout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    (void)layout;
    (void)indexPath;
    return CGSizeMake([self pp_cardWidth], collectionView.bounds.size.height);
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    (void)scrollView;
    [self stopAutoScroll];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    (void)scrollView;
    NSInteger page = [self pp_centeredIndex];
    self.pageControl.currentPage = page;
    [self pp_applyCarouselTransforms];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    (void)scrollView;
    [self pp_recenterIfNeeded];
    [self startAutoScroll];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    (void)scrollView;
    if (!decelerate) {
        [self pp_recenterIfNeeded];
        [self startAutoScroll];
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    (void)scrollView;
    [self pp_recenterIfNeeded];
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView
                     withVelocity:(CGPoint)velocity
              targetContentOffset:(inout CGPoint *)targetContentOffset
{
    NSInteger totalItems = [self pp_virtualItemCount];
    if (totalItems == 0) return;

    CGFloat stride = [self pp_cardStride];
    if (stride <= 0.0) return;

    CGFloat leftInset = self.collectionView.contentInset.left;
    CGFloat proposed = targetContentOffset->x;
    CGFloat rawIndex = (proposed + leftInset) / stride;

    NSInteger index;
    if (fabs(velocity.x) > 0.25) {
        NSInteger current = [self pp_centeredVirtualIndex];
        index = current + (velocity.x > 0 ? 1 : -1);
    } else {
        index = (NSInteger)llround(rawIndex);
    }

    index = MAX(0, MIN(index, totalItems - 1));
    targetContentOffset->x = [self pp_targetContentOffsetXForVirtualIndex:index];
    self.pageControl.currentPage = [self pp_realIndexForVirtualIndex:index];
}

- (CGFloat)pp_cardWidth
{
    CGFloat width = [self pp_viewportWidth];
    return floor(width * kPPHomePromoCarouselCardWidthFraction);
}

- (CGFloat)pp_lineSpacing
{
    return kPPHomePromoCarouselLineSpacing;
}

- (CGFloat)pp_sidePeekInset
{
    CGFloat width = [self pp_viewportWidth];
    CGFloat peekInset = (width - [self pp_cardWidth]) * 0.5;
    return MAX(0.0, floor(peekInset));
}

- (CGFloat)pp_cardStride
{
    return [self pp_cardWidth] + [self pp_lineSpacing];
}

- (UIEdgeInsets)pp_collectionInsets
{
    CGFloat inset = [self pp_sidePeekInset];
    return UIEdgeInsetsMake(0.0, inset, 0.0, inset);
}

- (CGFloat)pp_targetContentOffsetXForVirtualIndex:(NSInteger)virtualIndex
{
    return (-self.collectionView.contentInset.left) + (virtualIndex * [self pp_cardStride]);
}

- (CGFloat)pp_viewportWidth
{
    CGFloat width = self.cachedViewportWidth;
    if (width <= 0.0) {
        width = CGRectGetWidth(self.bounds);
    }
    if (width <= 0.0) {
        width = CGRectGetWidth(self.collectionView.bounds);
    }
    return MAX(width, 1.0);
}

- (NSInteger)pp_centeredIndex
{
    if (self.cards.count == 0) return 0;
    return [self pp_realIndexForVirtualIndex:[self pp_centeredVirtualIndex]];
}

- (NSInteger)pp_virtualItemCount
{
    NSInteger count = (NSInteger)self.cards.count;
    if (count <= 1) return count;
    return count * 200;
}

- (NSInteger)pp_realIndexForVirtualIndex:(NSInteger)virtualIndex
{
    if (self.cards.count == 0) return 0;
    NSInteger count = (NSInteger)self.cards.count;
    NSInteger idx = (count > 0) ? (virtualIndex % count) : 0;
    if (idx < 0) idx += count;
    return idx;
}

- (NSInteger)pp_preferredVirtualIndexForRealIndex:(NSInteger)realIndex
{
    if (self.cards.count == 0) return 0;
    NSInteger count = (NSInteger)self.cards.count;
    NSInteger normalizedReal = realIndex % count;
    if (normalizedReal < 0) normalizedReal += count;

    if (count <= 1) {
        return normalizedReal;
    }

    NSInteger total = [self pp_virtualItemCount];
    NSInteger middle = total / 2;
    NSInteger base = (middle / count) * count;
    NSInteger virtualIndex = base + normalizedReal;
    return MAX(0, MIN(total - 1, virtualIndex));
}

- (NSInteger)pp_centeredVirtualIndex
{
    NSInteger total = [self pp_virtualItemCount];
    if (total == 0) return 0;

    CGFloat stride = [self pp_cardStride];
    if (stride <= 0.0) return 0;
    CGFloat leftInset = self.collectionView.contentInset.left;
    CGFloat raw = (self.collectionView.contentOffset.x + leftInset) / stride;
    NSInteger idx = (NSInteger)llround(raw);
    return MAX(0, MIN(idx, total - 1));
}

- (void)pp_scrollToIndex:(NSInteger)index animated:(BOOL)animated
{
    if (self.cards.count == 0) return;
    NSInteger virtualIndex = [self pp_preferredVirtualIndexForRealIndex:index];
    [self pp_scrollToVirtualIndex:virtualIndex animated:animated];
}

- (void)pp_scrollToVirtualIndex:(NSInteger)virtualIndex animated:(BOOL)animated
{
    NSInteger total = [self pp_virtualItemCount];
    if (total == 0) return;
    virtualIndex = MAX(0, MIN(virtualIndex, total - 1));

    CGPoint target = CGPointMake([self pp_targetContentOffsetXForVirtualIndex:virtualIndex], 0);

    [self.collectionView setContentOffset:target animated:animated];
    self.pageControl.currentPage = [self pp_realIndexForVirtualIndex:virtualIndex];
    if (!animated) {
        [self pp_applyCarouselTransforms];
    }
}

- (void)pp_recenterIfNeeded
{
    if (self.cards.count <= 1) return;

    NSInteger total = [self pp_virtualItemCount];
    NSInteger count = (NSInteger)self.cards.count;
    NSInteger currentVirtual = [self pp_centeredVirtualIndex];

    NSInteger threshold = count * 3;
    if (currentVirtual > threshold && currentVirtual < (total - threshold - 1)) {
        return;
    }

    NSInteger realIndex = [self pp_realIndexForVirtualIndex:currentVirtual];
    NSInteger targetVirtual = [self pp_preferredVirtualIndexForRealIndex:realIndex];
    if (targetVirtual != currentVirtual) {
        [self pp_scrollToVirtualIndex:targetVirtual animated:NO];
    }
}

- (void)pp_updateCarouselMetricsPreservingIndex
{
    NSInteger current = [self pp_centeredIndex];
    UIEdgeInsets contentInset = [self pp_collectionInsets];
    self.collectionView.contentInset = contentInset;
    self.collectionView.scrollIndicatorInsets = contentInset;

    UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout;
    if ([layout isKindOfClass:UICollectionViewFlowLayout.class]) {
        layout.minimumLineSpacing = [self pp_lineSpacing];
        layout.minimumInteritemSpacing = 0.0;
        [layout invalidateLayout];
    }

    if (self.cards.count > 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pp_scrollToIndex:current animated:NO];
        });
    }
}

- (void)pp_applyCarouselTransforms
{
    CGFloat centerX = self.collectionView.contentOffset.x + (CGRectGetWidth(self.collectionView.bounds) * 0.5);
    CGFloat maxDistance = MAX(1.0, [self pp_cardStride]);

    for (UICollectionViewCell *cell in self.collectionView.visibleCells) {
        CGFloat distance = MIN(fabs(cell.center.x - centerX), maxDistance);
        CGFloat progress = 1.0 - (distance / maxDistance);
        CGFloat scale = kPPHomePromoCarouselMinScale + ((1.0 - kPPHomePromoCarouselMinScale) * progress);
        CGFloat translateY = (1.0 - progress) * kPPHomePromoCarouselMaxTranslateY;
        CGAffineTransform transform = CGAffineTransformIdentity;
        transform = CGAffineTransformTranslate(transform, 0.0, translateY);
        transform = CGAffineTransformScale(transform, scale, scale);
        cell.transform = transform;
        cell.alpha = 0.80 + (0.20 * progress);
        cell.layer.zPosition = progress * 10.0;
    }
}

- (void)dealloc {
    [self.autoScrollTimer invalidate];
    self.autoScrollTimer = nil;
}

@end

@implementation PPBannerCollectionCell

+ (CGFloat)preferredCarouselSectionHeight
{
    return kPPHomeBannerSectionHeight;
}

+ (CGFloat)preferredCarouselSectionTopInset
{
    return kPPHomeBannerSectionTopInset;
}

+ (CGFloat)preferredCarouselSectionHorizontalInset
{
    return kPPHomeBannerSectionHorizontalInset;
}

+ (CGFloat)preferredCarouselSectionBottomInset
{
    return kPPHomeBannerSectionBottomInset;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.contentView.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = NO;
    self.contentView.clipsToBounds = NO;

    _shadowContainer = [UIView new];
    _shadowContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _shadowContainer.backgroundColor = UIColor.clearColor;
    _shadowContainer.layer.cornerRadius = PPNewCorner;
    _shadowContainer.layer.shadowColor = UIColor.blackColor.CGColor;
    _shadowContainer.layer.shadowOpacity = 0.08;
    _shadowContainer.layer.shadowRadius = 18;
    _shadowContainer.layer.shadowOffset = CGSizeMake(0, 10);
    [self.contentView addSubview:_shadowContainer];

    _bannersView = [[PPBannersCollection alloc] init];
    _bannersView.translatesAutoresizingMaskIntoConstraints = NO;
    _bannersView.layer.cornerRadius = PPNewCorner;
    _bannersView.layer.masksToBounds = YES;
    [self.shadowContainer addSubview:_bannersView];

    _promoCarouselView = [[PPHomePromoCarouselView alloc] initWithFrame:CGRectZero];
    _promoCarouselView.translatesAutoresizingMaskIntoConstraints = NO;
    _promoCarouselView.layer.cornerRadius = PPNewCorner;
    _promoCarouselView.layer.masksToBounds = NO;
    _promoCarouselView.clipsToBounds = NO;
    _promoCarouselView.hidden = YES;
    [self.shadowContainer addSubview:_promoCarouselView];

    _placeholderView = [UIView new];
    _placeholderView.translatesAutoresizingMaskIntoConstraints = NO;
    _placeholderView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    _placeholderView.hidden = YES;
    _placeholderView.layer.cornerRadius = PPNewCorner;
    _placeholderView.layer.masksToBounds = YES;
    [self.shadowContainer addSubview:_placeholderView];

    UIView *placeholderGlow = [UIView new];
    placeholderGlow.translatesAutoresizingMaskIntoConstraints = NO;
    placeholderGlow.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.18];
    placeholderGlow.layer.cornerRadius = 18;
    [self.placeholderView addSubview:placeholderGlow];

    UIView *placeholderButton = [UIView new];
    placeholderButton.translatesAutoresizingMaskIntoConstraints = NO;
    placeholderButton.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.22];
    placeholderButton.layer.cornerRadius = 14;
    [self.placeholderView addSubview:placeholderButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.shadowContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.shadowContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.shadowContainer.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:kPPHomeBannerCellVerticalPadding],
        [self.shadowContainer.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-kPPHomeBannerCellVerticalPadding],

        [self.bannersView.leadingAnchor constraintEqualToAnchor:self.shadowContainer.leadingAnchor],
        [self.bannersView.trailingAnchor constraintEqualToAnchor:self.shadowContainer.trailingAnchor],
        [self.bannersView.topAnchor constraintEqualToAnchor:self.shadowContainer.topAnchor],
        [self.bannersView.bottomAnchor constraintEqualToAnchor:self.shadowContainer.bottomAnchor],

        [self.promoCarouselView.leadingAnchor constraintEqualToAnchor:self.shadowContainer.leadingAnchor],
        [self.promoCarouselView.trailingAnchor constraintEqualToAnchor:self.shadowContainer.trailingAnchor],
        [self.promoCarouselView.topAnchor constraintEqualToAnchor:self.shadowContainer.topAnchor],
        [self.promoCarouselView.bottomAnchor constraintEqualToAnchor:self.shadowContainer.bottomAnchor],

        [self.placeholderView.leadingAnchor constraintEqualToAnchor:self.shadowContainer.leadingAnchor],
        [self.placeholderView.trailingAnchor constraintEqualToAnchor:self.shadowContainer.trailingAnchor],
        [self.placeholderView.topAnchor constraintEqualToAnchor:self.shadowContainer.topAnchor],
        [self.placeholderView.bottomAnchor constraintEqualToAnchor:self.shadowContainer.bottomAnchor],

        [placeholderGlow.leadingAnchor constraintEqualToAnchor:self.placeholderView.leadingAnchor constant:14],
        [placeholderGlow.topAnchor constraintEqualToAnchor:self.placeholderView.topAnchor constant:14],
        [placeholderGlow.widthAnchor constraintEqualToConstant:74],
        [placeholderGlow.heightAnchor constraintEqualToConstant:30],

        [placeholderButton.leadingAnchor constraintEqualToAnchor:self.placeholderView.leadingAnchor constant:14],
        [placeholderButton.bottomAnchor constraintEqualToAnchor:self.placeholderView.bottomAnchor constant:-14],
        [placeholderButton.widthAnchor constraintEqualToConstant:110],
        [placeholderButton.heightAnchor constraintEqualToConstant:38],
    ]];

    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.shadowContainer.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.shadowContainer.bounds cornerRadius:PPNewCorner].CGPath;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [self.bannersView stopAutoScroll];
    [self.promoCarouselView stopAutoScroll];
    self.promoCarouselView.onCardTap = nil;
    self.promoCarouselView.onPrimaryTap = nil;
    self.promoCarouselView.onSecondaryTap = nil;
}

+ (NSString *)reuseIdentifier
{
    return @"PPBannerCollectionCell";
}

- (void)configureWithBanners:(NSArray<PPBannerViewModel *> *)banners group:(MainBannerModel *)group delegate:(id<BannerTapsCollectionDelegate>)delegate
{
    self.placeholderView.hidden = YES;
    self.promoCarouselView.hidden = YES;
    self.bannersView.hidden = NO;

    self.bannersView.banners = banners ?: @[];
    self.bannersView.mainBannerGroup = group;
    self.bannersView.delegate = delegate;
    self.bannersView.autoScrollAnimationDuration = 0.6;
    self.bannersView.autoScrollInterval = 5.0;
    self.bannersView.autoScrollStyle = PPBannersAutoScrollStyleFade;
    [self.bannersView startAutoScroll];
    [self.bannersView.collectionView reloadData];
}

- (void)configureWithPromoCards:(NSArray<PPHomePromoCarouselCard *> *)cards
                      onCardTap:(PPHomePromoCarouselTapBlock)onCardTap
                   onPrimaryTap:(PPHomePromoCarouselTapBlock)onPrimaryTap
                 onSecondaryTap:(PPHomePromoCarouselTapBlock)onSecondaryTap
{
    [self.bannersView stopAutoScroll];
    self.bannersView.hidden = YES;
    self.placeholderView.hidden = YES;
    self.promoCarouselView.hidden = NO;

    [self.promoCarouselView configureWithCards:cards ?: @[]
                                     onCardTap:onCardTap
                                  onPrimaryTap:onPrimaryTap
                                onSecondaryTap:onSecondaryTap];
}

- (void)configurePlaceholder
{
    self.placeholderView.hidden = NO;
    self.bannersView.hidden = YES;
    self.promoCarouselView.hidden = YES;
    [self.bannersView stopAutoScroll];
    [self.promoCarouselView stopAutoScroll];
}

- (void)dealloc {
    [self.bannersView stopAutoScroll];
    [self.promoCarouselView stopAutoScroll];
}

@end
