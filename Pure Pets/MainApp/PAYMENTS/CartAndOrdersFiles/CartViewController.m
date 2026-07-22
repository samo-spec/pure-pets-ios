
//  CartViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 29/06/2025.

#import "CartViewController.h"

#import "CartManager.h"
#import "PPSaveForLaterManager.h"
#import "PPCartCalculator.h"
#import "PPOrderManager.h"
#import "PPSPinnerView.h"
#import "PetAccessoryManager.h"
#import "ChManager.h"
#import "AppClasses.h"
#import "UIViewController+PPBottomSurface.h"
#import "PPCommerceFeedbackManager.h"
#import "PPChatsFunc.h"
#import "PPHUD.h"
#import "PPBackgroundView.h"
#import <QuartzCore/QuartzCore.h>
@import FirebaseFunctions;

static NSString *const kCartSupportPhoneNumber = @"+97459997720";
static NSString *const kPPCartTableCellIdentifier = @"PPCartTableCell";
static NSString *const kPPCartSavedDockCellIdentifier = @"PPCartSavedDockCell";
static CGFloat const kCartScreenHorizontalInset = 16.0;
static CGFloat const kCartFloatingSummaryBottomInset = 12.0;
static CGFloat const kCartHeaderExpandedHeight = 232.0;
static CGFloat const kCartHeaderCollapsedHeight = 76.0;
static CGFloat const kCartHeaderTopInset = 8.0;
static CGFloat const kCartHeaderTableSpacing = 18.0;
static CGFloat const kCartTableBottomInset = 0.0;
static CGFloat const kCartHeaderStretchLimit = 34.0;
static NSTimeInterval const kPPSavedDockMorphDuration = 0.30;
static NSTimeInterval const kPPSavedRowRevealDuration = 0.28;
static NSTimeInterval const kPPSavedTransferAnticipationDuration = 0.10;
static NSTimeInterval const kPPSavedTransferDuration = 0.62;
static NSTimeInterval const kPPSavedTableReflowDuration = 0.50;

static UIColor *PPCartScreenBackgroundColor(void)
{
    return PPBackgroundColorForIOS26(AppBackgroundClr);
}

static UIColor *PPSavedForLaterDeferredAccentColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
                ? [UIColor colorWithRed:0.94 green:0.69 blue:0.30 alpha:1.0]
                : [UIColor colorWithRed:0.72 green:0.45 blue:0.10 alpha:1.0];
        }];
    }
    return [UIColor colorWithRed:0.72 green:0.45 blue:0.10 alpha:1.0];
}

static UIFont *PPCartScaledFont(NSString *fontName,
                                CGFloat size,
                                UIFontWeight fallbackWeight,
                                UIFontTextStyle textStyle)
{
    UIFont *baseFont = [UIFont fontWithName:fontName size:size];
    if (!baseFont) {
        baseFont = [UIFont systemFontOfSize:size weight:fallbackWeight];
    }
    return [[UIFontMetrics metricsForTextStyle:textStyle] scaledFontForFont:baseFont];
}

@interface CustomTextViewCell : XLFormTextViewCell @end

@implementation CustomTextViewCell
- (void)configure {
    [super configure];
    self.textView.layer.cornerRadius = 12;
    self.textView.layer.masksToBounds = YES;
    self.textView.backgroundColor = AppBackgroundClr;
}

@end

@interface PPSavedForLaterDockTableCell : UITableViewCell
@property (nonatomic, strong) UIView *dockContainerView;
@property (nonatomic, strong) UIView *boundaryLineView;
@property (nonatomic, strong) UIView *boundaryAccentView;
@property (nonatomic, strong) NSLayoutConstraint *dockTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *dockBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *boundaryTopConstraint;
@property (nonatomic, strong) UIVisualEffectView *materialView;
@property (nonatomic, strong) UIView *tintView;
@property (nonatomic, strong) UIView *accentLineView;
@property (nonatomic, strong) UIView *iconContainerView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *countBadgeLabel;
@property (nonatomic, strong) UIView *chevronContainerView;
@property (nonatomic, strong) UIImageView *chevronView;
@property (nonatomic, assign) BOOL hasPlayedEntry;
- (void)configureWithSavedCount:(NSInteger)count expanded:(BOOL)expanded;
- (void)playExpansionEntryIfNeeded;
@end

@implementation PPSavedForLaterDockTableCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (self) {
        [self pp_setupDockCell];
    }
    return self;
}

- (void)pp_setupDockCell
{
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.contentView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    UIColor *accentColor = PPSavedForLaterDeferredAccentColor();
    UIColor *primaryTextColor = AppPrimaryTextClr ?: UIColor.labelColor;

    UIView *boundaryLineView = [[UIView alloc] init];
    boundaryLineView.translatesAutoresizingMaskIntoConstraints = NO;
    boundaryLineView.userInteractionEnabled = NO;
    boundaryLineView.backgroundColor = [UIColor.separatorColor colorWithAlphaComponent:0.34];
    [self.contentView addSubview:boundaryLineView];
    self.boundaryLineView = boundaryLineView;

    UIView *boundaryAccentView = [[UIView alloc] init];
    boundaryAccentView.translatesAutoresizingMaskIntoConstraints = NO;
    boundaryAccentView.userInteractionEnabled = NO;
    boundaryAccentView.backgroundColor = [accentColor colorWithAlphaComponent:0.70];
    boundaryAccentView.layer.cornerRadius = 1.0;
    [self.contentView addSubview:boundaryAccentView];
    self.boundaryAccentView = boundaryAccentView;

    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = UIColor.clearColor;
    container.layer.cornerRadius = 28.0;
    [container pp_setShadowColor:UIColor.blackColor];
    container.layer.shadowOpacity = 0.0;
    container.layer.shadowRadius = 0.0;
    container.layer.shadowOffset = CGSizeZero;
    if (@available(iOS 13.0, *)) {
        container.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.contentView addSubview:container];
    self.dockContainerView = container;

    UIVisualEffectView *materialView =
    [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial]];
    materialView.translatesAutoresizingMaskIntoConstraints = NO;
    materialView.clipsToBounds = YES;
    materialView.layer.cornerRadius = 28.0;
    materialView.layer.borderWidth = 0.85;
    UIColor *borderColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return [UIColor.whiteColor colorWithAlphaComponent:(tc.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.13 : 0.58];
    }];
    [materialView pp_setBorderColor:[borderColor resolvedColorWithTraitCollection:self.traitCollection]];
    if (@available(iOS 13.0, *)) {
        materialView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [container addSubview:materialView];
    self.materialView = materialView;

    UIView *tintView = [[UIView alloc] init];
    tintView.translatesAutoresizingMaskIntoConstraints = NO;
    tintView.userInteractionEnabled = NO;
    tintView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.13 green:0.13 blue:0.15 alpha:0.58];
        }
        return [[UIColor whiteColor] colorWithAlphaComponent:0.54];
    }];
    [materialView.contentView addSubview:tintView];
    self.tintView = tintView;

    UIView *accentLine = [[UIView alloc] init];
    accentLine.translatesAutoresizingMaskIntoConstraints = NO;
    accentLine.backgroundColor = [accentColor colorWithAlphaComponent:0.92];
    accentLine.layer.cornerRadius = 2.0;
    [materialView.contentView addSubview:accentLine];
    self.accentLineView = accentLine;

    UIView *iconContainer = [[UIView alloc] init];
    iconContainer.translatesAutoresizingMaskIntoConstraints = NO;
    iconContainer.backgroundColor = [accentColor colorWithAlphaComponent:0.13];
    iconContainer.layer.cornerRadius = 22.0;
    iconContainer.layer.borderWidth = 0.8;
    [iconContainer pp_setBorderColor:[accentColor colorWithAlphaComponent:0.20]];
    [materialView.contentView addSubview:iconContainer];
    self.iconContainerView = iconContainer;

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage pp_symbolNamed:@"bookmark.fill"
                                                                              pointSize:18
                                                                                 weight:UIImageSymbolWeightSemibold
                                                                                  scale:UIImageSymbolScaleMedium
                                                                                palette:@[accentColor, accentColor]
                                                                           makeTemplate:YES]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = accentColor;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [iconContainer addSubview:iconView];
    self.iconView = iconView;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = kLang(@"saved_for_later");
    titleLabel.font = PPCartScaledFont(@"Beiruti-Bold", 18.0, UIFontWeightBold, UIFontTextStyleHeadline);
    titleLabel.textColor = primaryTextColor;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.numberOfLines = 1;
    titleLabel.adjustsFontForContentSizeCategory = YES;
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.minimumScaleFactor = 0.82;
    [materialView.contentView addSubview:titleLabel];
    self.titleLabel = titleLabel;

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.text = kLang(@"choose_items_to_move");
    subtitleLabel.font = PPCartScaledFont(@"Beiruti-Medium", 12.5, UIFontWeightMedium, UIFontTextStyleFootnote);
    subtitleLabel.textColor = [UIColor.labelColor colorWithAlphaComponent:0.58];
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    subtitleLabel.numberOfLines = 1;
    subtitleLabel.adjustsFontForContentSizeCategory = YES;
    subtitleLabel.adjustsFontSizeToFitWidth = YES;
    subtitleLabel.minimumScaleFactor = 0.78;
    [materialView.contentView addSubview:subtitleLabel];
    self.subtitleLabel = subtitleLabel;

    UILabel *countBadge = [[UILabel alloc] init];
    countBadge.translatesAutoresizingMaskIntoConstraints = NO;
    countBadge.font = PPCartScaledFont(@"Beiruti-Bold", 12.2, UIFontWeightSemibold, UIFontTextStyleCaption1);
    countBadge.textColor = accentColor;
    countBadge.textAlignment = NSTextAlignmentCenter;
    countBadge.numberOfLines = 1;
    countBadge.adjustsFontForContentSizeCategory = YES;
    countBadge.adjustsFontSizeToFitWidth = YES;
    countBadge.minimumScaleFactor = 0.72;
    countBadge.backgroundColor = [accentColor colorWithAlphaComponent:0.11];
    countBadge.layer.cornerRadius = 16.0;
    countBadge.layer.masksToBounds = YES;
    countBadge.layer.borderWidth = 0.75;
    [countBadge pp_setBorderColor:[accentColor colorWithAlphaComponent:0.18]];
    [materialView.contentView addSubview:countBadge];
    self.countBadgeLabel = countBadge;

    UIView *chevronContainer = [[UIView alloc] init];
    chevronContainer.translatesAutoresizingMaskIntoConstraints = NO;
    chevronContainer.backgroundColor = [UIColor.labelColor colorWithAlphaComponent:0.055];
    chevronContainer.layer.cornerRadius = 17.0;
    [materialView.contentView addSubview:chevronContainer];
    self.chevronContainerView = chevronContainer;

    UIImageView *chevronView = [[UIImageView alloc] init];
    chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    chevronView.tintColor = [primaryTextColor colorWithAlphaComponent:0.76];
    chevronView.contentMode = UIViewContentModeScaleAspectFit;
    [chevronContainer addSubview:chevronView];
    self.chevronView = chevronView;

    self.boundaryTopConstraint = [boundaryLineView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:18.0];
    self.dockTopConstraint = [container.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:34.0];
    self.dockBottomConstraint = [container.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-2.0];
    [NSLayoutConstraint activateConstraints:@[
        [boundaryLineView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:34.0],
        [boundaryLineView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-34.0],
        self.boundaryTopConstraint,
        [boundaryLineView.heightAnchor constraintEqualToConstant:1.0],

        [boundaryAccentView.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [boundaryAccentView.centerYAnchor constraintEqualToAnchor:boundaryLineView.centerYAnchor],
        [boundaryAccentView.widthAnchor constraintEqualToConstant:34.0],
        [boundaryAccentView.heightAnchor constraintEqualToConstant:2.0],

        self.dockTopConstraint,
        self.dockBottomConstraint,
        [container.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0],
        [container.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16.0],

        [materialView.topAnchor constraintEqualToAnchor:container.topAnchor],
        [materialView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        [materialView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [materialView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],

        [tintView.topAnchor constraintEqualToAnchor:materialView.contentView.topAnchor],
        [tintView.bottomAnchor constraintEqualToAnchor:materialView.contentView.bottomAnchor],
        [tintView.leadingAnchor constraintEqualToAnchor:materialView.contentView.leadingAnchor],
        [tintView.trailingAnchor constraintEqualToAnchor:materialView.contentView.trailingAnchor],

        [accentLine.leadingAnchor constraintEqualToAnchor:materialView.contentView.leadingAnchor constant:14.0],
        [accentLine.centerYAnchor constraintEqualToAnchor:materialView.contentView.centerYAnchor],
        [accentLine.widthAnchor constraintEqualToConstant:4.0],
        [accentLine.heightAnchor constraintEqualToConstant:38.0],

        [iconContainer.leadingAnchor constraintEqualToAnchor:accentLine.trailingAnchor constant:10.0],
        [iconContainer.centerYAnchor constraintEqualToAnchor:materialView.contentView.centerYAnchor],
        [iconContainer.widthAnchor constraintEqualToConstant:44.0],
        [iconContainer.heightAnchor constraintEqualToConstant:44.0],

        [iconView.centerXAnchor constraintEqualToAnchor:iconContainer.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconContainer.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:19.0],
        [iconView.heightAnchor constraintEqualToConstant:19.0],

        [titleLabel.leadingAnchor constraintEqualToAnchor:iconContainer.trailingAnchor constant:12.0],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:countBadge.leadingAnchor constant:-10.0],
        [titleLabel.topAnchor constraintEqualToAnchor:materialView.contentView.topAnchor constant:16.0],

        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:chevronContainer.leadingAnchor constant:-10.0],
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:3.0],
        [subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:materialView.contentView.bottomAnchor constant:-14.0],

        [countBadge.centerYAnchor constraintEqualToAnchor:titleLabel.centerYAnchor],
        [countBadge.heightAnchor constraintEqualToConstant:32.0],
        [countBadge.widthAnchor constraintGreaterThanOrEqualToConstant:74.0],
        [countBadge.widthAnchor constraintLessThanOrEqualToConstant:112.0],

        [chevronContainer.leadingAnchor constraintEqualToAnchor:countBadge.trailingAnchor constant:8.0],
        [chevronContainer.trailingAnchor constraintEqualToAnchor:materialView.contentView.trailingAnchor constant:-14.0],
        [chevronContainer.centerYAnchor constraintEqualToAnchor:materialView.contentView.centerYAnchor],
        [chevronContainer.widthAnchor constraintEqualToConstant:34.0],
        [chevronContainer.heightAnchor constraintEqualToConstant:34.0],

        [chevronView.centerXAnchor constraintEqualToAnchor:chevronContainer.centerXAnchor],
        [chevronView.centerYAnchor constraintEqualToAnchor:chevronContainer.centerYAnchor],
        [chevronView.widthAnchor constraintEqualToConstant:13.0],
        [chevronView.heightAnchor constraintEqualToConstant:13.0],
    ]];

    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    if (!CGRectIsEmpty(self.dockContainerView.bounds)) {
        self.dockContainerView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.dockContainerView.bounds
                                  cornerRadius:self.dockContainerView.layer.cornerRadius].CGPath;
    }
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.hasPlayedEntry = NO;
    self.dockContainerView.alpha = 1.0;
    self.dockContainerView.transform = CGAffineTransformIdentity;
    self.accentLineView.transform = CGAffineTransformIdentity;
    self.iconContainerView.transform = CGAffineTransformIdentity;
    self.countBadgeLabel.transform = CGAffineTransformIdentity;
    self.chevronContainerView.transform = CGAffineTransformIdentity;
    self.boundaryAccentView.transform = CGAffineTransformIdentity;
    self.boundaryAccentView.alpha = 1.0;
}

- (void)configureWithSavedCount:(NSInteger)count expanded:(BOOL)expanded
{
    NSString *countText = [NSString stringWithFormat:kLang(@"saved_for_later_count_format"), (long)MAX(count, 0)];
    self.titleLabel.text = kLang(@"saved_for_later");
    self.subtitleLabel.text = expanded ? kLang(@"choose_items_to_move") : kLang(@"saved_for_later_open_hint");
    self.countBadgeLabel.text = countText;
    self.chevronView.image = [UIImage pp_symbolNamed:expanded ? @"chevron.up" : @"chevron.down"
                                           pointSize:12
                                              weight:UIImageSymbolWeightBold
                                               scale:UIImageSymbolScaleSmall
                                             palette:@[self.chevronView.tintColor ?: UIColor.labelColor,
                                                       self.chevronView.tintColor ?: UIColor.labelColor]
                                        makeTemplate:YES];
    self.accessibilityLabel = kLang(@"saved_for_later");
    self.accessibilityValue = countText;
    self.accessibilityHint = kLang(@"saved_for_later_open_hint");
    self.accessibilityTraits = UIAccessibilityTraitButton | (expanded ? UIAccessibilityTraitSelected : 0);
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.dockContainerView.alpha = highlighted ? 0.95 : 1.0;
        return;
    }
    void (^changes)(void) = ^{
        self.dockContainerView.transform = highlighted ? CGAffineTransformMakeScale(0.985, 0.985) : CGAffineTransformIdentity;
        self.dockContainerView.alpha = highlighted ? 0.96 : 1.0;
    };
    if (!animated) {
        changes();
        return;
    }
    [UIView animateWithDuration:highlighted ? 0.10 : 0.30
                          delay:0.0
         usingSpringWithDamping:highlighted ? 1.0 : 0.74
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:changes
                     completion:nil];
}

- (void)playExpansionEntryIfNeeded
{
    if (self.hasPlayedEntry || UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }
    self.hasPlayedEntry = YES;
    self.dockContainerView.alpha = 1.0;
    self.dockContainerView.transform = CGAffineTransformIdentity;
    self.accentLineView.transform = CGAffineTransformMakeScale(1.0, 0.34);
    self.iconContainerView.transform = CGAffineTransformMakeScale(0.88, 0.88);
    self.countBadgeLabel.transform = CGAffineTransformMakeScale(0.94, 0.94);
    self.chevronContainerView.transform = CGAffineTransformMakeScale(0.92, 0.92);
    self.boundaryAccentView.alpha = 0.24;
    self.boundaryAccentView.transform = CGAffineTransformMakeScale(0.34, 1.0);

    [UIView animateWithDuration:0.28
                          delay:0.0
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.28
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.accentLineView.transform = CGAffineTransformIdentity;
        self.iconContainerView.transform = CGAffineTransformIdentity;
        self.countBadgeLabel.transform = CGAffineTransformIdentity;
        self.chevronContainerView.transform = CGAffineTransformIdentity;
        self.boundaryAccentView.alpha = 1.0;
        self.boundaryAccentView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

@end
/*
@interface PPInsetLabel : UILabel
@property (nonatomic, assign) UIEdgeInsets textInsets;
@end

@implementation PPInsetLabel

- (instancetype)init
{
    self = [super init];
    if (self) {
        _textInsets = UIEdgeInsetsMake(12.0, 14.0, 12.0, 14.0);
    }
    return self;
}

- (CGRect)textRectForBounds:(CGRect)bounds limitedToNumberOfLines:(NSInteger)numberOfLines
{
    CGRect insetBounds = UIEdgeInsetsInsetRect(bounds, self.textInsets);
    CGRect textRect = [super textRectForBounds:insetBounds limitedToNumberOfLines:numberOfLines];
    textRect.origin.x -= self.textInsets.left;
    textRect.origin.y -= self.textInsets.top;
    textRect.size.width += (self.textInsets.left + self.textInsets.right);
    textRect.size.height += (self.textInsets.top + self.textInsets.bottom);
    return textRect;
}

- (void)drawTextInRect:(CGRect)rect
{
    [super drawTextInRect:UIEdgeInsetsInsetRect(rect, self.textInsets)];
}

@end
*/
@interface CartViewController ()
@property (nonatomic, strong) PPSPinnerView *spinner;

@property (nonatomic, strong) UITableView *cartTableView;
@property (nonatomic, strong) PPPremuimChekoutView *summaryView;
@property (nonatomic, strong) PPBackgroundView *premiumBackgroundView;
@property (nonatomic, strong) UIView *headerChromeContainerView;
@property (nonatomic, strong) UIVisualEffectView *headerChromeView;
@property (nonatomic, strong) UIView *headerTintOverlayView;
@property (nonatomic, strong) UIView *headerPrimaryOrbView;
@property (nonatomic, strong) UIView *headerSecondaryOrbView;
@property (nonatomic, strong) UIView *headerIconContainerView;
@property (nonatomic, strong) UIImageView *headerIconView;
@property (nonatomic, strong) UILabel *headerBadgeLabel;
@property (nonatomic, strong) UILabel *headerTitleLabel;
@property (nonatomic, strong) UILabel *headerSubtitleLabel;
@property (nonatomic, strong) UILabel *headerCompactSummaryLabel;
@property (nonatomic, strong) UIButton *headerEditButton;
@property (nonatomic, strong) UIStackView *headerMetricsStack;
@property (nonatomic, strong) UILabel *itemsMetricLabel;
@property (nonatomic, strong) UILabel *subtotalMetricLabel;
@property (nonatomic, strong) UILabel *shippingMetricLabel;
@property (nonatomic, strong) UIView *headerAccentBarView;
@property (nonatomic, strong, nullable) NSLayoutConstraint *headerHeightConstraint;
@property (nonatomic, strong) UIView *undoContainerView;
@property (nonatomic, strong) UILabel *undoLabel;
@property (nonatomic, strong) UIButton *undoButton;
@property (nonatomic, strong) CartItem *lastRemovedCartItem;
@property (nonatomic, assign) NSInteger lastRemovedCartIndex;
@property (nonatomic, assign) NSUInteger undoPresentationToken;

@property (nonatomic,
           strong,
           nullable) NSLayoutConstraint *tableBottomConstraint;
@property (nonatomic, strong, readonly) PPEmptyStateConfig *config;
@property (nonatomic, assign) BOOL isPerformingTableMutation;
@property (nonatomic, assign) NSUInteger pendingQuantitySyncReloadSkips;
@property (nonatomic, assign) BOOL cartEditingModeActive;
@property (nonatomic, assign) BOOL didRunEntranceAnimation;
@property (nonatomic, assign) BOOL didPrimeInitialCartScrollPosition;
@property (nonatomic, assign) CGFloat headerCollapseProgress;
@property (nonatomic, assign) BOOL savedForLaterExpanded;
@property (nonatomic, copy, nullable) NSString *pendingSavedForLaterItemID;
@property (nonatomic, copy, nullable) NSString *pendingSavedForLaterOperation;
@property (nonatomic, copy, nullable) NSString *completedSavedForLaterItemID;
@property (nonatomic, assign) NSUInteger savedForLaterAnimationToken;
@property (nonatomic, assign) BOOL savedForLaterRevealInProgress;
@property (nonatomic, assign) BOOL savedForLaterRetainsEmptyDockDuringTransition;
@property (nonatomic, weak, nullable) UIButton *savedForLaterFooterPillButton;
@property (nonatomic, strong, nullable) UINotificationFeedbackGenerator *savedMoveFeedbackGenerator;

- (void)pp_updateSavedForLaterFooter;
- (NSArray<CartItem *> *)pp_savedForLaterItems;
- (BOOL)pp_isSavedForLaterDockIndexPath:(NSIndexPath *)indexPath;
- (CartItem *)pp_savedForLaterItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)pp_setSavedForLaterExpanded:(BOOL)expanded
                            animated:(BOOL)animated
                          sourceView:(UIView * _Nullable)sourceView;
- (void)pp_moveSavedForLaterItemToCart:(CartItem *)item;
- (void)pp_confirmRemoveSavedForLaterItem:(CartItem *)item;
- (void)pp_registerStockNotificationForSavedItem:(CartItem *)item;
- (void)pp_configureActiveCartCell:(PPCartTableCell *)cell item:(CartItem *)item;
- (void)pp_configureSavedCartCell:(PPCartTableCell *)cell item:(CartItem *)item;
- (void)pp_refreshVisibleSavedItemID:(NSString * _Nullable)itemID;
- (void)pp_animateTransferSnapshot:(UIView * _Nullable)snapshot
                     toTargetFrame:(CGRect)targetFrame
                        completion:(void (^ _Nullable)(void))completion;
- (void)pp_performSavedTransferTableUpdates:(dispatch_block_t)updates
                                  completion:(void (^ _Nullable)(BOOL finished))completion;

@end

@implementation CartViewController

- (PPBottomSurfaceKind)pp_preferredBottomSurfaceKind
{
    return CartManager.sharedManager.cartItems.count > 0
        ? PPBottomSurfaceKindSummaryBottomBar
        : PPBottomSurfaceKindNone;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self pp_applyCartScreenBackgroundColor];
    [self pp_installPremiumCartBackgroundViewIfNeeded];
    [self pp_updatePremiumCartBackgroundAppearance];

    self.cartTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.cartTableView.dataSource = self;
    self.cartTableView.delegate = self;
    self.cartTableView.backgroundColor = UIColor.clearColor;
    self.cartTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.cartTableView.separatorColor = UIColor.clearColor;
    self.cartTableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.cartTableView.showsHorizontalScrollIndicator = NO;
    self.cartTableView.showsVerticalScrollIndicator = NO;
    self.cartTableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.cartTableView.contentInset = UIEdgeInsetsMake(12.0, 0.0, kCartTableBottomInset, 0.0);
    self.cartTableView.scrollIndicatorInsets = UIEdgeInsetsMake(0.0, 0.0, kCartTableBottomInset, 0.0);
    self.cartTableView.estimatedRowHeight = 144.0;
    if (@available(iOS 15.0, *)) {
        self.cartTableView.sectionHeaderTopPadding = 0.0;
    }

    [self.cartTableView registerClass:[PPCartTableCell class] forCellReuseIdentifier:kPPCartTableCellIdentifier];
    [self.cartTableView registerClass:[PPSavedForLaterDockTableCell class] forCellReuseIdentifier:kPPCartSavedDockCellIdentifier];

    // Start hidden — pp_runEntranceAnimationIfNeeded reveals with spring animation.
    self.cartTableView.alpha = 0.0;
    [self.view addSubview:self.cartTableView];

    [self setSummuryViewAtBottom];
    [self pp_setupUndoBarIfNeeded];

    [NSLayoutConstraint activateConstraints:@[
        [self.cartTableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.cartTableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.cartTableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor]
    ]];
    self.tableBottomConstraint =
    [self.cartTableView.bottomAnchor constraintEqualToAnchor:self.summaryView.topAnchor constant:0.0];
    self.tableBottomConstraint.active = YES;

    [self.view bringSubviewToFront:self.summaryView];
    if (self.undoContainerView) {
        [self.view bringSubviewToFront:self.undoContainerView];
    }

    // Empty state config (reused)
    [self emptyViewConfiger];

    // Notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateViewFromSync)
                                                 name:kCartUpdatedNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_updateSavedForLaterFooter)
                                                 name:@"PPSaveForLaterUpdatedNotification"
                                               object:nil];
    
    // Initial UI
    [self setupFormFooterFrom:@"LOAD"];
    [self updateTotalLabel];
    [self pp_updateSavedForLaterFooter];
    [self pp_applyEmptyStateIfNeeded];
}

- (void)setSummuryViewAtBottom
{
    self.summaryView = [[PPPremuimChekoutView alloc] init];
    [self.summaryView setCollapsible:YES initiallyCollapsed:NO];
    
    [self.view addSubview:self.summaryView];
    [self.summaryView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor].active = YES;
    [self.summaryView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor].active = YES;
    [self.summaryView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor].active = YES;

    // Suppress the internal cardView entrance animation; this VC uses
    // its own entrance in pp_runEntranceAnimationIfNeeded instead.
    [self.summaryView skipCardEntranceAnimation];

    __weak typeof(self) weakSelf = self;
    self.summaryView.onTapCheckOut = ^{
        NSLog(@"🛒 Checkout tapped on CART      +Helper");
        [weakSelf checkoutTapped];
    };

    PPCartSummary *initSummary = [PPCartCalculator currentSummary];

    [UIView performWithoutAnimation:^{
        [self.summaryView updateTotalsWithItems:initSummary.subtotal shipping:initSummary.shippingFee showTitle:NO];
        self.summaryView.showDetails = YES;
        [self.summaryView updatePreviewItems:CartManager.sharedManager.cartItems];
        self.summaryView.showsItemsPreview = NO;
        [self.summaryView setCheckoutBTNTitle:kLang(@"Checkout")
                                        image:[UIImage pp_symbolNamed:Language.isRTL ? @"arrow.left" : @"arrow.right"
                                                            pointSize:18
                                                               weight:UIImageSymbolWeightSemibold
                                                                scale:UIImageSymbolScaleLarge
                                                              palette:@[AppForgroundColr, AppForgroundColr]
                                                         makeTemplate:NO]];
        [self.summaryView layoutIfNeeded];
    }];

    if ([CartManager sharedManager].cartItems.count > 0) {
        [self.summaryView pp_startTrustBannerShimmer];
    }

    self.summaryView.alpha = 0.0;
    self.summaryView.transform = CGAffineTransformMakeTranslation(0.0, 20.0);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    [self.summaryView layoutIfNeeded];

    if (self.undoContainerView && !CGRectIsEmpty(self.undoContainerView.bounds)) {
        self.undoContainerView.layer.shadowPath =
            [UIBezierPath bezierPathWithRoundedRect:self.undoContainerView.bounds
                                      cornerRadius:self.undoContainerView.layer.cornerRadius].CGPath;
    }

    if (!self.didPrimeInitialCartScrollPosition && self.cartTableView) {
        CGFloat restingOffsetY = -self.cartTableView.adjustedContentInset.top;
        self.cartTableView.contentOffset = CGPointMake(0.0, restingOffsetY);
        self.didPrimeInitialCartScrollPosition = YES;
    }
}

- (void)reloadFormData {
    // All pricing now flows through PPCartCalculator — no local math needed.
    // updateTotalLabel and pp_cartDidUpdate handle the UI refresh path.
}
- (void)setupFormFooterFrom:(NSString *)setupFrom {
    
  // // [self pp_applyEmptyStateIfNeeded];
}


-(void)startEditingCartItems
{
    UIAlertController *menu = [UIAlertController
                               alertControllerWithTitle:kLang(@"cart_support_menu_title")
                               message:nil
                               preferredStyle:UIAlertControllerStyleActionSheet];

    UIAlertAction *callAction = [UIAlertAction actionWithTitle:kLang(@"Call")
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(__unused UIAlertAction * _Nonnull action) {
        [AppClasses callPhoneNumber:kCartSupportPhoneNumber fromViewController:self];
    }];
    [menu addAction:callAction];

    UIAlertAction *chatAction = [UIAlertAction actionWithTitle:kLang(@"cart_support_chat")
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(__unused UIAlertAction * _Nonnull action) {
        if (!UserManager.sharedManager.isUserLoggedIn) {
            [UserManager showPromptOnTopController];
            return;
        }
        [[ChManager sharedManager] openSupportChatFromController:self];
    }];
    [menu addAction:chatAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:kLang(@"cancel")
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [menu addAction:cancelAction];

    UIPopoverPresentationController *popover = menu.popoverPresentationController;
    if (popover) {
        UIBarButtonItem *sourceButton = self.navigationItem.rightBarButtonItem;
        if (sourceButton) {
            popover.barButtonItem = sourceButton;
        } else {
            popover.sourceView = self.view;
            popover.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds),
                                            CGRectGetMinY(self.view.bounds) + 44.0,
                                            1.0,
                                            1.0);
        }
        popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
    }

    [self presentViewController:menu animated:YES completion:nil];
}

- (BOOL)pp_hasEditableCartItems
{
    return [CartManager sharedManager].cartItems.count > 0;
}

- (void)pp_toggleCartEditMode
{
    [self pp_setCartEditing:!self.cartTableView.isEditing animated:YES];
}

- (void)pp_setCartEditing:(BOOL)editing animated:(BOOL)animated
{
    BOOL shouldEdit = editing && [self pp_hasEditableCartItems];
    self.cartEditingModeActive = shouldEdit;
    [self.cartTableView setEditing:shouldEdit animated:animated];
    [self pp_refreshCartEditControls];
}

- (void)pp_refreshCartEditControls
{
    BOOL isEditing = self.cartTableView.isEditing || self.cartEditingModeActive;
    BOOL hasItems = [self pp_hasEditableCartItems];
    NSString *title = isEditing ? kLang(@"Done") : kLang(@"Edit");
    UIButton *editButton =
    [PPButtonHelper pp_buttonWithTitle:title
                                  font:[GM MidFontWithSize:16]
                             imageName:@""
                                target:self
                                config:[UIButtonConfiguration tintedButtonConfiguration]
                                action:@selector(pp_toggleCartEditMode)];
    editButton.enabled = hasItems || isEditing;
    editButton.alpha = editButton.enabled ? 1.0 : 0.46;
    editButton.accessibilityLabel = title;
    editButton.accessibilityHint = kLang(@"editing_mode");

    UIBarButtonItem *editItem =
    [[UIBarButtonItem alloc] initWithCustomView:editButton];
    editItem.enabled = hasItems || isEditing;
    editItem.accessibilityLabel = title;
    editItem.accessibilityHint = kLang(@"editing_mode");
    self.navigationItem.rightBarButtonItem = editItem;

    [self pp_styleHeaderEditButton:self.headerEditButton];
}

-(void)viewWillAppear:(BOOL)animated
{
    [CartManager.sharedManager refreshPricingConfiguration];
    [super viewWillAppear:animated];

    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"cartTitle") showBack:NO];
    [self pp_applyCartScreenBackgroundColor];
    [self pp_updatePremiumCartBackgroundAppearance];

    NSString *leadingSymbol = [self pp_cartCanNavigateBackInStack] ? PPChevronName : @"house.fill";
    self.navigationItem.leftBarButtonItem =
    [[UIBarButtonItem alloc] initWithImage:PPSYSImage(leadingSymbol)
                                     style:UIBarButtonItemStylePlain
                                    target:self
                                    action:@selector(pp_handleLeadingCartNavigation)];
    self.navigationItem.leftBarButtonItem.accessibilityLabel =
    [self pp_cartCanNavigateBackInStack]
    ? NSLocalizedString(@"Back", @"Navigate back")
    : NSLocalizedString(@"Home", @"Navigate home");

    [self pp_refreshCartEditControls];

    [self.summaryView setCheckoutLoading:NO];
    [self updateTotalLabel];
    [self.summaryView layoutIfNeeded];
    [self.premiumBackgroundView startAnimations];
    [self pp_updateSavedForLaterFooter];
    [self pp_applyBottomSurfaceAnimated:animated];
}

- (void)pp_applyCartScreenBackgroundColor
{

    self.view.backgroundColor = UIColor.clearColor;
    self.navigationController.view.backgroundColor = AppBackgroundClr;
    self.cartTableView.backgroundColor = UIColor.clearColor;
    self.cartTableView.backgroundView.backgroundColor = UIColor.clearColor;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self pp_runEntranceAnimationIfNeeded];
}

- (BOOL)pp_cartCanNavigateBackInStack
{
    UINavigationController *navigationController = self.navigationController;
    if (![navigationController isKindOfClass:UINavigationController.class]) {
        return NO;
    }
    return navigationController.viewControllers.count > 1 &&
    navigationController.viewControllers.lastObject == self;
}

- (void)pp_handleLeadingCartNavigation
{
    if ([self pp_cartCanNavigateBackInStack]) {
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }

    UITabBarController *tabBarController = self.tabBarController;
    if (tabBarController.viewControllers.count > 0) {
        UIViewController *homeController = tabBarController.viewControllers.firstObject;
        if ([homeController isKindOfClass:UINavigationController.class]) {
            UINavigationController *homeNavigationController = (UINavigationController *)homeController;
            BOOL isCurrentNavigation = (homeNavigationController == self.navigationController);
            [homeNavigationController popToRootViewControllerAnimated:isCurrentNavigation];
            tabBarController.selectedIndex = 0;
            return;
        }
        tabBarController.selectedIndex = 0;
        return;
    }

    if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }

    [self.navigationController popToRootViewControllerAnimated:YES];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    //[[NSNotificationCenter defaultCenter]   postNotificationName:PPExpandSystemTabBarNotification  object:nil];
    [_summaryView pp_stopTrustBannerShimmer];
    [self.premiumBackgroundView stopAnimations];
    [self pp_hideUndoBarAnimated:NO clearPayload:NO];
}

- (void)continueShopping
{
    [self pp_handleLeadingCartNavigation];
}

- (void)pp_installPremiumCartBackgroundViewIfNeeded
{
    if (!self.premiumBackgroundView) {
        PPBackgroundView *backgroundView = [[PPBackgroundView alloc] initWithFrame:CGRectZero];
        backgroundView.translatesAutoresizingMaskIntoConstraints = NO;
        backgroundView.userInteractionEnabled = NO;
        backgroundView.clipsToBounds = YES;
        backgroundView.overrideBorders = YES;
        backgroundView.overrideCornerRadius = 0.01;
        backgroundView.PPHeroApexUseShimmer = NO;
        backgroundView.PPHeroApexUseUnderFingerMotion = NO;
        backgroundView.accentStyle = PPHeroGlassAccentStyleFullScreen;
        self.premiumBackgroundView = backgroundView;
    }

    if (self.premiumBackgroundView.superview != self.view) {
        if (self.cartTableView.superview == self.view) {
            [self.view insertSubview:self.premiumBackgroundView belowSubview:self.cartTableView];
        } else {
            [self.view insertSubview:self.premiumBackgroundView atIndex:0];
        }

        [NSLayoutConstraint activateConstraints:@[
            [self.premiumBackgroundView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
            [self.premiumBackgroundView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [self.premiumBackgroundView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
            [self.premiumBackgroundView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
        ]];
    } else if (self.cartTableView.superview == self.view) {
        [self.view insertSubview:self.premiumBackgroundView belowSubview:self.cartTableView];
    } else {
        [self.view sendSubviewToBack:self.premiumBackgroundView];
    }
}

- (void)pp_updatePremiumCartBackgroundAppearance
{
    [self pp_installPremiumCartBackgroundViewIfNeeded];
    self.view.backgroundColor = UIColor.clearColor;
    self.navigationController.view.backgroundColor = AppBackgroundClr ?: UIColor.systemBackgroundColor;
    self.cartTableView.backgroundColor = UIColor.clearColor;
    self.cartTableView.backgroundView.backgroundColor = UIColor.clearColor;
    self.premiumBackgroundView.accentStyle = PPHeroGlassAccentStyleFullScreen;
    self.premiumBackgroundView.overrideBorders = YES;
    self.premiumBackgroundView.overrideBorderColor = UIColor.clearColor;
    self.premiumBackgroundView.overrideCornerRadius = 0.01;
    self.premiumBackgroundView.overrideSurfaceColor = AppBackgroundClr;
    self.premiumBackgroundView.accentColorOverride = AppPrimaryClr;
    self.premiumBackgroundView.overrideTopGlowColor = AppPrimaryClrShiner ?: AppPrimaryClr;
    self.premiumBackgroundView.overrideCenterGlowColor = AppPrimaryClr;
    self.premiumBackgroundView.overrideBottomGlowColor = AppPrimaryClr;
    [self.premiumBackgroundView reapplyPalette];
    self.premiumBackgroundView.layer.shadowOpacity = 0.0f;
}

- (UILabel *)pp_buildMetricLabel
{
    PPInsetLabel *label = [[PPInsetLabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.textInsets = UIEdgeInsetsMake(14.0, 14.0, 14.0, 14.0);
    label.numberOfLines = 0;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    label.layer.cornerRadius = 24.0;
    label.layer.masksToBounds = YES;
    label.layer.borderWidth = 0.8;
    [label pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.10]];
    label.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.11];
    return label;
}

- (void)pp_applyMetricLabel:(UILabel *)label
                      title:(NSString *)title
                      value:(NSString *)value
                 valueColor:(UIColor *)valueColor
{
    if (!label) return;

    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.alignment = Language.alignmentForCurrentLanguage;
    paragraphStyle.lineSpacing = 2.0;

    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:title ?: @""
                                                                             attributes:@{
        NSFontAttributeName: [GM MidFontWithSize:10.5],
        NSForegroundColorAttributeName: [UIColor.labelColor colorWithAlphaComponent:0.56],
        NSParagraphStyleAttributeName: paragraphStyle
    }];

    NSString *valueLine = value.length > 0 ? [NSString stringWithFormat:@"\n%@", value] : @"";
    [text appendAttributedString:[[NSAttributedString alloc] initWithString:valueLine
                                                                  attributes:@{
        NSFontAttributeName: [GM boldFontWithSize:17],
        NSForegroundColorAttributeName: valueColor ?: UIColor.labelColor,
        NSParagraphStyleAttributeName: paragraphStyle
    }]];

    label.attributedText = text;
}

- (void)pp_styleHeaderSupportButton:(UIButton *)button
{
    if (!button) return;

    UIImage *supportImage = [UIImage pp_symbolNamed:@"headphones.dots"
                                          pointSize:14
                                             weight:UIImageSymbolWeightSemibold
                                              scale:UIImageSymbolScaleMedium
                                            palette:@[AppPrimaryTextClr ?: UIColor.labelColor,
                                                      AppPrimaryTextClr ?: UIColor.labelColor]
                                       makeTemplate:YES];

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        config.image = supportImage;
        config.imagePlacement = NSDirectionalRectEdgeLeading;
        config.imagePadding = 6.0;
        config.contentInsets = NSDirectionalEdgeInsetsMake(10.0, 14.0, 10.0, 14.0);
        config.baseForegroundColor = AppPrimaryTextClr ?: UIColor.labelColor;
        config.background.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.14];
        config.background.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.10];
        config.background.strokeWidth = 0.8;
        config.attributedTitle = [[NSAttributedString alloc] initWithString:kLang(@"Support")
                                                                  attributes:@{
            NSFontAttributeName: [GM boldFontWithSize:13],
            NSForegroundColorAttributeName: AppPrimaryTextClr ?: UIColor.labelColor
        }];
        button.configuration = config;
    } else {
        [button setTitle:kLang(@"Support") forState:UIControlStateNormal];
        [button setImage:supportImage forState:UIControlStateNormal];
        [button setTitleColor:AppPrimaryTextClr ?: UIColor.labelColor forState:UIControlStateNormal];
        button.tintColor = AppPrimaryTextClr ?: UIColor.labelColor;
        button.titleLabel.font = [GM boldFontWithSize:13];
        button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.14];
        button.layer.cornerRadius = 19.0;
        button.layer.borderWidth = 0.8;
        [button pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.10]];
        button.contentEdgeInsets = UIEdgeInsetsMake(10.0, 14.0, 10.0, 14.0);
    }

    button.accessibilityLabel = NSLocalizedString(@"a11y_btn_cart_support", @"Contact support");
    button.accessibilityHint = NSLocalizedString(@"a11y_btn_cart_support_hint", @"Double-tap to contact customer support");
}

- (void)pp_styleHeaderEditButton:(UIButton *)button
{
    if (!button) return;

    BOOL isEditing = self.cartTableView.isEditing || self.cartEditingModeActive;
    BOOL hasItems = [CartManager sharedManager].cartItems.count > 0;
    NSString *title = isEditing ? kLang(@"Done") : kLang(@"Edit");
    NSString *symbolName = isEditing ? @"checkmark" : @"pencil";
    UIColor *foregroundColor = AppPrimaryTextClr ?: UIColor.labelColor;
    UIColor *backgroundColor = [UIColor colorWithWhite:1.0 alpha:(hasItems || isEditing) ? 0.14 : 0.07];
    UIColor *borderColor = [UIColor colorWithWhite:1.0 alpha:(hasItems || isEditing) ? 0.10 : 0.06];
    UIImage *editImage = [UIImage pp_symbolNamed:symbolName
                                       pointSize:14
                                          weight:UIImageSymbolWeightSemibold
                                           scale:UIImageSymbolScaleMedium
                                         palette:@[foregroundColor, foregroundColor]
                                    makeTemplate:YES];

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        config.image = editImage;
        config.imagePlacement = NSDirectionalRectEdgeLeading;
        config.imagePadding = 6.0;
        config.contentInsets = NSDirectionalEdgeInsetsMake(10.0, 14.0, 10.0, 14.0);
        config.baseForegroundColor = foregroundColor;
        config.background.backgroundColor = backgroundColor;
        config.background.strokeColor = borderColor;
        config.background.strokeWidth = 0.8;
        config.attributedTitle = [[NSAttributedString alloc] initWithString:title
                                                                  attributes:@{
            NSFontAttributeName: [GM boldFontWithSize:13],
            NSForegroundColorAttributeName: foregroundColor
        }];
        button.configuration = config;
    } else {
        [button setTitle:title forState:UIControlStateNormal];
        [button setImage:editImage forState:UIControlStateNormal];
        [button setTitleColor:foregroundColor forState:UIControlStateNormal];
        button.tintColor = foregroundColor;
        button.titleLabel.font = [GM boldFontWithSize:13];
        button.backgroundColor = backgroundColor;
        button.layer.cornerRadius = 19.0;
        button.layer.borderWidth = 0.8;
        [button pp_setBorderColor:borderColor];
        button.contentEdgeInsets = UIEdgeInsetsMake(10.0, 14.0, 10.0, 14.0);
    }

    button.enabled = hasItems || isEditing;
    button.alpha = button.enabled ? 1.0 : 0.46;
    button.accessibilityLabel = title;
    button.accessibilityHint = kLang(@"editing_mode");
}

- (void)pp_setUndoButtonTitle:(NSString *)title
{
    NSString *resolvedTitle = title ?: kLang(@"cart_undo_action");
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = self.undoButton.configuration;
        config.attributedTitle = [[NSAttributedString alloc] initWithString:resolvedTitle
                                                                  attributes:@{
            NSFontAttributeName: [GM boldFontWithSize:14],
            NSForegroundColorAttributeName: UIColor.whiteColor
        }];
        self.undoButton.configuration = config;
    } else {
        [self.undoButton setTitle:resolvedTitle forState:UIControlStateNormal];
    }
}

- (void)pp_buildHeaderChrome
{
    if (self.headerChromeContainerView || self.headerChromeView) return;

    UIView *containerView = [[UIView alloc] init];
    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    containerView.backgroundColor = UIColor.clearColor;
    containerView.layer.cornerRadius = 34.0;
    [containerView pp_setShadowColor:UIColor.blackColor];
    containerView.layer.shadowOpacity = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.03 : 0.08;
    containerView.layer.shadowOffset = CGSizeMake(0.0, 14.0);
    containerView.layer.shadowRadius = 24.0;
    containerView.layer.masksToBounds = NO;
    if (@available(iOS 13.0, *)) {
        containerView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIBlurEffect *effect = nil;
    if (@available(iOS 13.0, *)) {
        effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    }

    UIVisualEffectView *chromeView = [[UIVisualEffectView alloc] initWithEffect:effect];
    chromeView.translatesAutoresizingMaskIntoConstraints = NO;
    chromeView.layer.cornerRadius = 34.0;
    chromeView.clipsToBounds = YES;
    chromeView.layer.masksToBounds = YES;
    chromeView.layer.borderWidth = 1.0;
    UIColor *chromeBorderDynamic = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        CGFloat a = (tc.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.68 * 0.18 : 0.68;
        return [[UIColor whiteColor] colorWithAlphaComponent:a];
    }];
    [chromeView pp_setBorderColor:[chromeBorderDynamic resolvedColorWithTraitCollection:self.traitCollection]];
    UIColor *chromeSurfaceColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.17 green:0.17 blue:0.19 alpha:0.92];
        }
        return [[UIColor whiteColor] colorWithAlphaComponent:0.82];
    }];
    chromeView.backgroundColor = chromeSurfaceColor;
    chromeView.contentView.layer.cornerRadius = 34.0;
    chromeView.contentView.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        chromeView.layer.cornerCurve = kCACornerCurveContinuous;
        chromeView.contentView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIView *tintOverlay = [[UIView alloc] init];
    tintOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    tintOverlay.userInteractionEnabled = NO;
    tintOverlay.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.22 green:0.19 blue:0.17 alpha:0.50];
        }
        return [[UIColor colorWithRed:0.99 green:0.96 blue:0.93 alpha:1.0] colorWithAlphaComponent:0.72];
    }];
    tintOverlay.layer.cornerRadius = 34.0;
    tintOverlay.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        tintOverlay.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIColor *brandColor = AppPrimaryClr ?: UIColor.systemOrangeColor;

    UIView *primaryOrb = [[UIView alloc] init];
    primaryOrb.translatesAutoresizingMaskIntoConstraints = NO;
    primaryOrb.userInteractionEnabled = NO;
    primaryOrb.backgroundColor = [brandColor colorWithAlphaComponent:0.16];
    primaryOrb.layer.cornerRadius = 94.0;
    [primaryOrb pp_setShadowColor:[brandColor colorWithAlphaComponent:0.50]];
    primaryOrb.layer.shadowOpacity = 0.16;
    primaryOrb.layer.shadowRadius = 42.0;
    primaryOrb.layer.shadowOffset = CGSizeZero;

    UIView *secondaryOrb = [[UIView alloc] init];
    secondaryOrb.translatesAutoresizingMaskIntoConstraints = NO;
    secondaryOrb.userInteractionEnabled = NO;
    secondaryOrb.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        CGFloat a = (tc.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.40 * 0.18 : 0.40;
        return [[UIColor whiteColor] colorWithAlphaComponent:a];
    }];
    secondaryOrb.layer.cornerRadius = 58.0;
    UIColor *secGlowShadowColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        CGFloat a = (tc.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.45 * 0.18 : 0.45;
        return [[UIColor whiteColor] colorWithAlphaComponent:a];
    }];
    [secondaryOrb pp_setShadowColor:[secGlowShadowColor resolvedColorWithTraitCollection:self.traitCollection]];
    secondaryOrb.layer.shadowOpacity = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.04 : 0.20;
    secondaryOrb.layer.shadowRadius = 22.0;
    secondaryOrb.layer.shadowOffset = CGSizeZero;

    UIView *accentBar = [[UIView alloc] init];
    accentBar.translatesAutoresizingMaskIntoConstraints = NO;
    accentBar.backgroundColor = brandColor;
    accentBar.layer.cornerRadius = 3.0;

    UIView *iconContainer = [[UIView alloc] init];
    iconContainer.translatesAutoresizingMaskIntoConstraints = NO;
    iconContainer.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
    iconContainer.layer.cornerRadius = 30.0;
    iconContainer.layer.borderWidth = 0.8;
    [iconContainer pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.12]];

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage pp_symbolNamed:@"bag.fill"
                                                                              pointSize:24
                                                                                 weight:UIImageSymbolWeightSemibold
                                                                                  scale:UIImageSymbolScaleLarge
                                                                                palette:@[AppPrimaryClr ?: UIColor.labelColor,
                                                                                          AppPrimaryClr ?: UIColor.labelColor]
                                                                           makeTemplate:YES]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = AppPrimaryClr ?: UIColor.labelColor;
    iconView.contentMode = UIViewContentModeScaleAspectFit;

    PPInsetLabel *badgeLabel = [[PPInsetLabel alloc] init];
    badgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    badgeLabel.textInsets = UIEdgeInsetsMake(6.0, 10.0, 6.0, 10.0);
    badgeLabel.text = @"PURE PETS";
    badgeLabel.font = [GM boldFontWithSize:11];
    badgeLabel.textColor = AppPrimaryClr;
    badgeLabel.textAlignment = NSTextAlignmentCenter;
    badgeLabel.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.13];
    badgeLabel.layer.cornerRadius = 14.0;
    badgeLabel.layer.masksToBounds = YES;
    badgeLabel.layer.borderWidth = 0.8;
    [badgeLabel pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.12]];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:30];
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.numberOfLines = 1;
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.minimumScaleFactor = 0.82;
    titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    titleLabel.text = kLang(@"cartTitle");
    [titleLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                forAxis:UILayoutConstraintAxisVertical];
    [titleLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                forAxis:UILayoutConstraintAxisHorizontal];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.numberOfLines = 1;
    subtitleLabel.font = [GM MidFontWithSize:14];
    subtitleLabel.textColor = [UIColor.labelColor colorWithAlphaComponent:0.60];
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [subtitleLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                   forAxis:UILayoutConstraintAxisVertical];

    PPInsetLabel *compactSummaryLabel = [[PPInsetLabel alloc] init];
    compactSummaryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    compactSummaryLabel.textInsets = UIEdgeInsetsMake(6.0, 10.0, 6.0, 10.0);
    compactSummaryLabel.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
    compactSummaryLabel.layer.cornerRadius = 14.0;
    compactSummaryLabel.layer.masksToBounds = YES;
    compactSummaryLabel.layer.borderWidth = 0.8;
    [compactSummaryLabel pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.10]];
    compactSummaryLabel.numberOfLines = 1;
    compactSummaryLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    compactSummaryLabel.textAlignment = NSTextAlignmentCenter;
    compactSummaryLabel.adjustsFontSizeToFitWidth = YES;
    compactSummaryLabel.minimumScaleFactor = 0.84;
    compactSummaryLabel.alpha = 0.0;
    [compactSummaryLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                         forAxis:UILayoutConstraintAxisHorizontal];
    [compactSummaryLabel setContentHuggingPriority:UILayoutPriorityDefaultLow
                                           forAxis:UILayoutConstraintAxisHorizontal];

    UIButton *editButton = [UIButton buttonWithType:UIButtonTypeSystem];
    editButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self pp_styleHeaderEditButton:editButton];
    [editButton addTarget:self action:@selector(pp_toggleCartEditMode) forControlEvents:UIControlEventTouchUpInside];

    UILabel *itemsMetricLabel = [self pp_buildMetricLabel];
    UILabel *subtotalMetricLabel = [self pp_buildMetricLabel];
    UILabel *shippingMetricLabel = [self pp_buildMetricLabel];

    UIStackView *metricsStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        itemsMetricLabel,
        subtotalMetricLabel,
        shippingMetricLabel
    ]];
    metricsStack.translatesAutoresizingMaskIntoConstraints = NO;
    metricsStack.axis = UILayoutConstraintAxisHorizontal;
    metricsStack.alignment = UIStackViewAlignmentFill;
    metricsStack.distribution = UIStackViewDistributionFillEqually;
    metricsStack.spacing = 12.0;

    UIView *spacer = [[UIView alloc] init];
    spacer.translatesAutoresizingMaskIntoConstraints = NO;
    [spacer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [spacer setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    UIStackView *topRow = [[UIStackView alloc] initWithArrangedSubviews:@[
        badgeLabel,
        spacer,
        editButton
    ]];
    topRow.translatesAutoresizingMaskIntoConstraints = NO;
    topRow.axis = UILayoutConstraintAxisHorizontal;
    topRow.alignment = UIStackViewAlignmentCenter;
    topRow.spacing = 12.0;

    UIView *titleCluster = [[UIView alloc] init];
    titleCluster.translatesAutoresizingMaskIntoConstraints = NO;

    [titleCluster addSubview:titleLabel];
    [titleCluster addSubview:subtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:titleCluster.topAnchor],
        [titleLabel.leadingAnchor constraintEqualToAnchor:titleCluster.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:titleCluster.trailingAnchor],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleCluster.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleCluster.trailingAnchor],
        [subtitleLabel.bottomAnchor constraintEqualToAnchor:titleCluster.bottomAnchor]
    ]];

    UIStackView *heroRow = [[UIStackView alloc] initWithArrangedSubviews:@[
        iconContainer,
        titleCluster
    ]];
    heroRow.translatesAutoresizingMaskIntoConstraints = NO;
    heroRow.axis = UILayoutConstraintAxisHorizontal;
    heroRow.alignment = UIStackViewAlignmentTop;
    heroRow.spacing = 14.0;

    [self.view addSubview:containerView];
    [containerView addSubview:chromeView];
    [chromeView.contentView addSubview:tintOverlay];
    [chromeView.contentView addSubview:primaryOrb];
    [chromeView.contentView addSubview:secondaryOrb];
    [chromeView.contentView addSubview:accentBar];
    [chromeView.contentView addSubview:topRow];
    [chromeView.contentView addSubview:compactSummaryLabel];
    [chromeView.contentView addSubview:heroRow];
    [chromeView.contentView addSubview:metricsStack];
    [iconContainer addSubview:iconView];

    NSLayoutConstraint *heightConstraint = [containerView.heightAnchor constraintEqualToConstant:kCartHeaderExpandedHeight];
    [NSLayoutConstraint activateConstraints:@[
        [containerView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:kCartHeaderTopInset],
        [containerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:kCartScreenHorizontalInset],
        [containerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-kCartScreenHorizontalInset],
        heightConstraint,

        [chromeView.topAnchor constraintEqualToAnchor:containerView.topAnchor],
        [chromeView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
        [chromeView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
        [chromeView.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor],

        [tintOverlay.topAnchor constraintEqualToAnchor:chromeView.contentView.topAnchor],
        [tintOverlay.leadingAnchor constraintEqualToAnchor:chromeView.contentView.leadingAnchor],
        [tintOverlay.trailingAnchor constraintEqualToAnchor:chromeView.contentView.trailingAnchor],
        [tintOverlay.bottomAnchor constraintEqualToAnchor:chromeView.contentView.bottomAnchor],

        [primaryOrb.widthAnchor constraintEqualToConstant:188.0],
        [primaryOrb.heightAnchor constraintEqualToConstant:188.0],
        [primaryOrb.topAnchor constraintEqualToAnchor:chromeView.contentView.topAnchor constant:-82.0],
        [primaryOrb.trailingAnchor constraintEqualToAnchor:chromeView.contentView.trailingAnchor constant:82.0],

        [secondaryOrb.widthAnchor constraintEqualToConstant:116.0],
        [secondaryOrb.heightAnchor constraintEqualToConstant:116.0],
        [secondaryOrb.bottomAnchor constraintEqualToAnchor:chromeView.contentView.bottomAnchor constant:42.0],
        [secondaryOrb.leadingAnchor constraintEqualToAnchor:chromeView.contentView.leadingAnchor constant:-34.0],

        [accentBar.topAnchor constraintEqualToAnchor:chromeView.contentView.topAnchor constant:14.0],
        [accentBar.leadingAnchor constraintEqualToAnchor:chromeView.contentView.leadingAnchor constant:18.0],
        [accentBar.widthAnchor constraintEqualToConstant:72.0],
        [accentBar.heightAnchor constraintEqualToConstant:6.0],

        [topRow.topAnchor constraintEqualToAnchor:chromeView.contentView.topAnchor constant:18.0],
        [topRow.leadingAnchor constraintEqualToAnchor:chromeView.contentView.leadingAnchor constant:18.0],
        [topRow.trailingAnchor constraintEqualToAnchor:chromeView.contentView.trailingAnchor constant:-18.0],

        [compactSummaryLabel.centerXAnchor constraintEqualToAnchor:chromeView.contentView.centerXAnchor],
        [compactSummaryLabel.centerYAnchor constraintEqualToAnchor:editButton.centerYAnchor],
        [compactSummaryLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:badgeLabel.trailingAnchor constant:10.0],
        [compactSummaryLabel.trailingAnchor constraintLessThanOrEqualToAnchor:editButton.leadingAnchor constant:-10.0],
        [compactSummaryLabel.widthAnchor constraintLessThanOrEqualToAnchor:chromeView.contentView.widthAnchor multiplier:0.42],
        [compactSummaryLabel.heightAnchor constraintEqualToConstant:30.0],

        [iconContainer.widthAnchor constraintEqualToConstant:60.0],
        [iconContainer.heightAnchor constraintEqualToConstant:60.0],
        [iconView.centerXAnchor constraintEqualToAnchor:iconContainer.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconContainer.centerYAnchor],

        [editButton.heightAnchor constraintEqualToConstant:40.0],

        [heroRow.topAnchor constraintEqualToAnchor:topRow.bottomAnchor constant:18.0],
        [heroRow.leadingAnchor constraintEqualToAnchor:chromeView.contentView.leadingAnchor constant:18.0],
        [heroRow.trailingAnchor constraintEqualToAnchor:chromeView.contentView.trailingAnchor constant:-18.0],

        [metricsStack.topAnchor constraintEqualToAnchor:heroRow.bottomAnchor constant:8.0],
        [metricsStack.leadingAnchor constraintEqualToAnchor:heroRow.leadingAnchor],
        [metricsStack.trailingAnchor constraintEqualToAnchor:heroRow.trailingAnchor],
        [metricsStack.heightAnchor constraintEqualToConstant:68.0],

        [itemsMetricLabel.heightAnchor constraintGreaterThanOrEqualToConstant:68.0]
    ]];

    self.headerChromeContainerView = containerView;
    self.headerChromeView = chromeView;
    self.headerTintOverlayView = tintOverlay;
    self.headerAccentBarView = accentBar;
    self.headerPrimaryOrbView = primaryOrb;
    self.headerSecondaryOrbView = secondaryOrb;
    self.headerIconContainerView = iconContainer;
    self.headerIconView = iconView;
    self.headerBadgeLabel = badgeLabel;
    self.headerTitleLabel = titleLabel;
    self.headerSubtitleLabel = subtitleLabel;
    self.headerCompactSummaryLabel = compactSummaryLabel;
    self.headerEditButton = editButton;
    self.headerMetricsStack = metricsStack;
    self.itemsMetricLabel = itemsMetricLabel;
    self.subtotalMetricLabel = subtotalMetricLabel;
    self.shippingMetricLabel = shippingMetricLabel;
    self.headerHeightConstraint = heightConstraint;
}

- (NSString *)pp_shippingMetricValueForSummary:(PPCartSummary *)summary
{
    if (!summary || summary.shippingFee <= 0.009) {
        return kLang(@"Free");
    }
    return [PPChatsFunc formattedCurrency:summary.shippingFee];
}

- (NSAttributedString *)pp_compactHeaderSummaryTextForSummary:(PPCartSummary *)summary
{
    PPCartSummary *resolvedSummary = summary ?: [PPCartCalculator currentSummary];
    NSString *valueText = [PPChatsFunc formattedCurrency:resolvedSummary.subtotal];
    NSString *titleText = resolvedSummary.totalQuantity > 0 ? kLang(@"Subtotal") : kLang(@"empty_cart_title");

    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@  ", titleText]
                                                                             attributes:@{
        NSFontAttributeName: [GM MidFontWithSize:11.0],
        NSForegroundColorAttributeName: [UIColor.labelColor colorWithAlphaComponent:0.60]
    }];
    [text appendAttributedString:[[NSAttributedString alloc] initWithString:valueText
                                                                  attributes:@{
        NSFontAttributeName: [GM boldFontWithSize:13.0],
        NSForegroundColorAttributeName: AppPrimaryTextClr ?: UIColor.labelColor
    }]];
    return text;
}

- (void)pp_updateHeaderChromeForScrollOffset:(CGFloat)offsetY
{
    if (!self.headerHeightConstraint || !(self.headerChromeContainerView ?: self.headerChromeView)) {
        return;
    }

    CGFloat restingOffsetY = -self.cartTableView.adjustedContentInset.top;
    CGFloat normalizedOffset = offsetY - restingOffsetY;
    CGFloat collapseRange = MAX(1.0, kCartHeaderExpandedHeight - kCartHeaderCollapsedHeight);
    CGFloat collapseProgress = MIN(1.0, MAX(0.0, normalizedOffset) / collapseRange);
    CGFloat stretchAmount = 0.0;
    CGFloat headerHeight = kCartHeaderExpandedHeight - (collapseRange * collapseProgress);

    if (normalizedOffset < 0.0) {
        stretchAmount = MIN(kCartHeaderStretchLimit, fabs(normalizedOffset) * 0.35);
        headerHeight = kCartHeaderExpandedHeight + stretchAmount;
    }

    self.headerHeightConstraint.constant = headerHeight;
    [self pp_applyHeaderCollapseProgress:collapseProgress stretchAmount:stretchAmount];

    self.cartTableView.scrollIndicatorInsets = UIEdgeInsetsMake(headerHeight + 10.0,
                                                                0.0,
                                                                kCartTableBottomInset,
                                                                0.0);
}

- (void)pp_applyHeaderCollapseProgress:(CGFloat)progress stretchAmount:(CGFloat)stretchAmount
{
    progress = MIN(1.0, MAX(0.0, progress));
    self.headerCollapseProgress = progress;

    CGFloat cornerRadius = 34.0 - (6.0 * progress) + (stretchAmount * 0.12);
    self.headerChromeContainerView.layer.cornerRadius = cornerRadius;
    self.headerChromeView.layer.cornerRadius = cornerRadius;
    self.headerChromeView.contentView.layer.cornerRadius = cornerRadius;
    self.headerTintOverlayView.layer.cornerRadius = cornerRadius;
    self.headerChromeContainerView.layer.shadowOpacity = 0.08 - (0.03 * progress);
    if (self.headerChromeContainerView && !CGRectIsEmpty(self.headerChromeContainerView.bounds)) {
        self.headerChromeContainerView.layer.shadowPath =
            [UIBezierPath bezierPathWithRoundedRect:self.headerChromeContainerView.bounds
                                      cornerRadius:cornerRadius].CGPath;
    }

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.headerBadgeLabel.alpha = 1.0;
        self.headerIconContainerView.alpha = progress >= 0.40 ? 0.0 : 1.0;
        self.headerTitleLabel.alpha = progress >= 0.40 ? 0.0 : 1.0;
        self.headerSubtitleLabel.alpha = progress >= 0.35 ? 0.0 : 1.0;
        self.headerCompactSummaryLabel.alpha = progress >= 0.40 ? 1.0 : 0.0;
        self.headerMetricsStack.alpha = progress >= 0.35 ? 0.0 : 1.0;
        self.headerTitleLabel.transform = CGAffineTransformIdentity;
        self.headerSubtitleLabel.transform = CGAffineTransformIdentity;
        self.headerCompactSummaryLabel.transform = CGAffineTransformIdentity;
        self.headerIconContainerView.transform = CGAffineTransformIdentity;
        self.headerEditButton.transform = CGAffineTransformIdentity;
        self.headerBadgeLabel.transform = CGAffineTransformIdentity;
        self.headerPrimaryOrbView.transform = CGAffineTransformIdentity;
        self.headerSecondaryOrbView.transform = CGAffineTransformIdentity;
        self.headerTintOverlayView.alpha = 1.0;
        self.headerAccentBarView.alpha = 1.0;
        return;
    }

    CGFloat iconScale = (1.0 - (0.28 * progress)) + (stretchAmount / 220.0);
    CGFloat iconAlpha = MAX(0.0, 1.0 - (2.8 * progress));
    CGFloat titleScale = (1.0 - (0.10 * progress)) + (stretchAmount / 300.0);
    CGFloat titleAlpha = MAX(0.0, 1.0 - (2.8 * progress));
    CGFloat subtitleAlpha = MAX(0.0, 1.0 - (3.2 * progress));
    CGFloat compactAlpha = MIN(1.0, MAX(0.0, (progress - 0.30) / 0.28));
    CGFloat metricsAlpha = MAX(0.0, 1.0 - (3.4 * progress));

    self.headerIconContainerView.alpha = iconAlpha;
    self.headerIconContainerView.transform =
        CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, -10.0 * progress),
                                CGAffineTransformMakeScale(iconScale, iconScale));

    self.headerTitleLabel.alpha = titleAlpha;
    self.headerTitleLabel.transform =
        CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, -12.0 * progress),
                                CGAffineTransformMakeScale(titleScale, titleScale));

    self.headerSubtitleLabel.alpha = subtitleAlpha;
    self.headerSubtitleLabel.transform = CGAffineTransformMakeTranslation(0.0, -10.0 * progress);

    self.headerCompactSummaryLabel.alpha = compactAlpha;
    self.headerCompactSummaryLabel.transform = CGAffineTransformMakeTranslation(0.0, 6.0 * (1.0 - compactAlpha));

    self.headerMetricsStack.alpha = metricsAlpha;
    self.headerMetricsStack.transform =
        CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, -14.0 * progress),
                                CGAffineTransformMakeScale(1.0 - (0.10 * progress),
                                                           1.0 - (0.10 * progress)));

    self.headerEditButton.transform = CGAffineTransformMakeScale(1.0 - (0.05 * progress),
                                                                 1.0 - (0.05 * progress));
    self.headerBadgeLabel.transform = CGAffineTransformMakeTranslation(0.0, -4.0 * progress);
    self.headerBadgeLabel.alpha = 1.0 - (0.18 * progress);

    self.headerPrimaryOrbView.transform =
        CGAffineTransformConcat(CGAffineTransformMakeTranslation(20.0 * progress, -14.0 * progress),
                                CGAffineTransformMakeScale(1.0 + (stretchAmount / 180.0),
                                                           1.0 + (stretchAmount / 180.0)));
    self.headerSecondaryOrbView.transform =
        CGAffineTransformConcat(CGAffineTransformMakeTranslation(-18.0 * progress, 12.0 * progress),
                                CGAffineTransformMakeScale(1.0 + (stretchAmount / 220.0),
                                                           1.0 + (stretchAmount / 220.0)));

    self.headerTintOverlayView.alpha = 1.0 - (0.06 * progress);
    self.headerAccentBarView.alpha = 1.0 - (0.50 * progress);
}

- (void)pp_refreshHeaderChromeWithSummary:(PPCartSummary *)summary
{
    NSInteger itemsCount = summary.totalQuantity;
    UIColor *accentColor = AppPrimaryClr ?: UIColor.labelColor;

    self.headerTitleLabel.text = kLang(@"cartTitle");
    self.headerSubtitleLabel.text = itemsCount > 0 ? kLang(@"Securecheckout") : kLang(@"empty_cart_subtitle");
    self.headerCompactSummaryLabel.attributedText = [self pp_compactHeaderSummaryTextForSummary:summary];
    self.headerIconContainerView.backgroundColor =
        [UIColor colorWithWhite:1.0 alpha:itemsCount > 0 ? 0.13 : 0.10];
    self.headerBadgeLabel.text = @"PURE PETS";

    [self pp_applyMetricLabel:self.itemsMetricLabel
                        title:kLang(@"Selected Items")
                        value:[NSString stringWithFormat:@"%ld", (long)itemsCount]
                   valueColor:AppPrimaryTextClr ?: UIColor.labelColor];

    [self pp_applyMetricLabel:self.subtotalMetricLabel
                        title:kLang(@"Subtotal")
                        value:[PPChatsFunc formattedCurrency:summary.subtotal]
                   valueColor:AppPrimaryTextClr ?: UIColor.labelColor];

    [self pp_applyMetricLabel:self.shippingMetricLabel
                        title:kLang(@"Shipping Fee")
                        value:[self pp_shippingMetricValueForSummary:summary]
                   valueColor:summary.shippingFee <= 0.009 ? accentColor : (AppPrimaryTextClr ?: UIColor.labelColor)];

    [self pp_updateHeaderChromeForScrollOffset:self.cartTableView.contentOffset.y];
}

- (void)pp_runEntranceAnimationIfNeeded
{
    if (self.didRunEntranceAnimation) return;
    self.didRunEntranceAnimation = YES;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    BOOL shouldShowSummary = ([CartManager sharedManager].cartItems.count > 0);
    self.cartTableView.alpha = 0.0;
    self.cartTableView.transform = CGAffineTransformMakeTranslation(0.0, 32.0);

    [UIView animateWithDuration:0.62
                          delay:0.0
         usingSpringWithDamping:0.90
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.cartTableView.alpha = 1.0;
        self.cartTableView.transform = CGAffineTransformIdentity;
    } completion:nil];
    self.summaryView.alpha = shouldShowSummary ? self.summaryView.alpha : 0.0;
}


- (void)emptyViewConfiger {

    _config = [PPEmptyStateConfig new];
    _config.animationName = @"Shopping Cart Empty.json";
    _config.title =  kLang(@"empty_cart_title");
    _config.subTitle = kLang(@"empty_cart_subtitle");
    _config.buttonTitle = kLang(@"continue_shopping");
    _config.target = self;
    _config.action = @selector(continueShopping);
    _config.isNetworkFile = YES;
    
    if ([CartManager sharedManager].cartItems.count == 0) {
        // self.checkoutButton.alpha = 0;
    } else {
        // self.checkoutButton.alpha = 1;
    }
}

#pragma mark - Empty State (Reusable Block)

- (void)pp_applyEmptyStateIfNeeded
{
    if (!self.cartTableView) return;

    NSInteger itemsCount = [CartManager sharedManager].cartItems.count;
    BOOL hasExpandedSavedItems = self.savedForLaterExpanded && [self pp_savedForLaterItems].count > 0;
    if (itemsCount > 0 || hasExpandedSavedItems) {
        self.cartTableView.backgroundView = nil;
        return;
    }

    UIView *container = [[UIView alloc] initWithFrame:self.cartTableView.bounds];
    container.backgroundColor = UIColor.clearColor;
    container.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    UIView *orbView = [[UIView alloc] init];
    orbView.translatesAutoresizingMaskIntoConstraints = NO;
    orbView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.10];
    orbView.layer.cornerRadius = 42.0;

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage pp_symbolNamed:@"bag"
                                                                         pointSize:34
                                                                            weight:UIImageSymbolWeightMedium
                                                                             scale:UIImageSymbolScaleLarge
                                                                           palette:@[AppPrimaryClr ?: UIColor.labelColor,
                                                                                     AppPrimaryClr ?: UIColor.labelColor]
                                                                      makeTemplate:YES]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = AppPrimaryClr ?: UIColor.labelColor;
    icon.contentMode = UIViewContentModeScaleAspectFit;

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 14;
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = kLang(@"empty_cart_title");
    titleLabel.font = [GM boldFontWithSize:24];
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.textAlignment = NSTextAlignmentCenter;

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.text = kLang(@"empty_cart_subtitle");
    subtitleLabel.font = [GM MidFontWithSize:15];
    subtitleLabel.textColor = [UIColor.labelColor colorWithAlphaComponent:0.62];
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.numberOfLines = 0;

    UIButton *actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self pp_styleHeaderSupportButton:actionButton];
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = actionButton.configuration;
        config.image = [UIImage pp_symbolNamed:Language.isRTL ? @"arrow.left" : @"arrow.right"
                                     pointSize:14
                                        weight:UIImageSymbolWeightSemibold
                                         scale:UIImageSymbolScaleMedium
                                       palette:@[AppForgroundColr ?: UIColor.whiteColor,
                                                 AppForgroundColr ?: UIColor.whiteColor]
                                  makeTemplate:YES];
        config.baseForegroundColor = AppForgroundColr ?: UIColor.whiteColor;
        config.background.backgroundColor = AppPrimaryClr ?: UIColor.labelColor;
        config.background.strokeWidth = 0.0;
        config.imagePlacement = NSDirectionalRectEdgeTrailing;
        config.attributedTitle = [[NSAttributedString alloc] initWithString:kLang(@"continue_shopping")
                                                                  attributes:@{
            NSFontAttributeName: [GM boldFontWithSize:15],
            NSForegroundColorAttributeName: AppForgroundColr ?: UIColor.whiteColor
        }];
        actionButton.configuration = config;
    } else {
        [actionButton setTitle:kLang(@"continue_shopping") forState:UIControlStateNormal];
        [actionButton setTitleColor:AppForgroundColr ?: UIColor.whiteColor forState:UIControlStateNormal];
        actionButton.backgroundColor = AppPrimaryClr ?: UIColor.labelColor;
        actionButton.layer.borderWidth = 0.0;
    }
    [actionButton addTarget:self
                     action:@selector(continueShopping)
           forControlEvents:UIControlEventTouchUpInside];
    actionButton.accessibilityLabel = kLang(@"continue_shopping");
    actionButton.accessibilityHint = nil;

    [orbView addSubview:icon];
    [stack addArrangedSubview:titleLabel];
    [stack addArrangedSubview:subtitleLabel];
    [stack addArrangedSubview:actionButton];

    [container addSubview:stack];
    [container addSubview:orbView];

    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:container.centerYAnchor constant:120.0],
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:container.leadingAnchor constant:24],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:container.trailingAnchor constant:-24],

        [orbView.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [orbView.bottomAnchor constraintEqualToAnchor:stack.topAnchor constant:-18.0],
        [orbView.widthAnchor constraintEqualToConstant:84.0],
        [orbView.heightAnchor constraintEqualToConstant:84.0],

        [icon.centerXAnchor constraintEqualToAnchor:orbView.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:orbView.centerYAnchor]
    ]];

    self.cartTableView.backgroundView = container;
}

 
- (void)showOders {
    OrderHistoryViewController *vc = [[OrderHistoryViewController alloc] init];
    vc.pp_transitionStyle = PPTransitionStyleNone;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)updateTotalLabel {
    PPCartSummary *summary = [PPCartCalculator currentSummary];

    self.summaryView.showDetails = YES;
    [self.summaryView updateTotalsWithItems:summary.subtotal shipping:summary.shippingFee showTitle:NO];
    [self.summaryView updatePreviewItems:CartManager.sharedManager.cartItems];

    // Button: "Continue to Checkout" (localized) with navigation arrow
    [self.summaryView setCheckoutBTNTitle:kLang(@"Checkout")
                                    image:[UIImage pp_symbolNamed:Language.isRTL ? @"arrow.left" : @"arrow.right"
                                                        pointSize:18
                                                           weight:UIImageSymbolWeightSemibold
                                                            scale:UIImageSymbolScaleLarge
                                                          palette:@[AppForgroundColr, AppForgroundColr]
                                                     makeTemplate:NO]];

    self.summaryView.alpha = (summary.uniqueItems > 0) ? 1.0 : 0.0;
    if (summary.uniqueItems > 0) {
        [self.summaryView pp_startTrustBannerShimmer];
    } else {
        [self.summaryView pp_stopTrustBannerShimmer];
    }

    if (summary.uniqueItems == 0 && (self.cartTableView.isEditing || self.cartEditingModeActive)) {
        [self pp_setCartEditing:NO animated:YES];
    } else {
        [self pp_refreshCartEditControls];
    }

    [self pp_applyEmptyStateIfNeeded];
    [self pp_applyBottomSurfaceAnimated:YES];
}

// Guard: avoid structural table reloads during local quantity taps or row mutations.
- (void)updateViewFromSync
{
    if (self.pendingQuantitySyncReloadSkips > 0) {
        if ([self.pendingSavedForLaterOperation isEqualToString:@"move"]) {
            self.pendingQuantitySyncReloadSkips -= 1;
            return;
        }
        NSInteger currentRows = CartManager.sharedManager.cartItems.count;
        NSInteger displayedRows = 0;
        if ([self.cartTableView numberOfSections] > 0) {
            NSInteger totalDisplayedRows = [self.cartTableView numberOfRowsInSection:0];
            NSInteger savedChromeRows = [self pp_shouldShowSavedForLaterInlineRows]
                ? 1 + [self pp_savedForLaterItems].count
                : 0;
            displayedRows = MAX(0, totalDisplayedRows - savedChromeRows);
        }
        if (displayedRows == currentRows) {
            self.pendingQuantitySyncReloadSkips -= 1;
            [self updateTotalLabel];
            return;
        }
        self.pendingQuantitySyncReloadSkips = 0;
    }

    if (self.isPerformingTableMutation) {
        NSLog(@"[CART] 🔁 Skipping reload during table mutation");
        return;
    }

    [self.cartTableView reloadData];
    [self updateTotalLabel];
    [self pp_updateSavedForLaterFooter];
}

- (void)pp_notifyCartBadgeAndCollections
{
    if ([self.delegate respondsToSelector:@selector(loadItemsCountInBadge)]) {
        [self.delegate loadItemsCountInBadge];
    }
    if ([self.delegate respondsToSelector:@selector(updateCartAndReloadCollection)]) {
        [self.delegate updateCartAndReloadCollection];
    }
}

- (CartItem *)pp_cloneCartItem:(CartItem *)item
{
    if (!item) return nil;
    CartItem *copy = [[CartItem alloc] init];
    copy.itemID = item.itemID ?: @"";
    copy.name = item.name ?: @"";
    copy.quantity = item.quantity;
    copy.price = item.price;
    copy.imageURL = item.imageURL ?: @"";
    copy.type = item.type ?: @"";
    return copy;
}

- (void)pp_setupUndoBarIfNeeded
{
    if (self.undoContainerView) return;

    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.94];
    container.layer.cornerRadius = 20.0;
    container.layer.borderWidth = 0.0;
    [container pp_setBorderColor:[UIColor.labelColor colorWithAlphaComponent:0.06]];
    [container pp_setShadowColor:UIColor.blackColor];
    container.layer.shadowOpacity = 0.10;
    container.layer.shadowOffset = CGSizeMake(0, 10);
    container.layer.shadowRadius = 18;
    container.layer.masksToBounds = NO;
    container.alpha = 0.0;
    container.hidden = YES;

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [GM MidFontWithSize:15];
    label.textColor = UIColor.whiteColor;
    label.numberOfLines = 2;
    label.text = kLang(@"cart_undo_message");
    label.textAlignment = Language.alignmentForCurrentLanguage;

    UIButton *undoButton = [UIButton buttonWithType:UIButtonTypeSystem];
    undoButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self pp_styleHeaderSupportButton:undoButton];
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = undoButton.configuration;
        config.baseForegroundColor = UIColor.whiteColor;
        config.background.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.22];
        config.background.strokeWidth = 0.0;
        config.image = nil;
        config.attributedTitle = [[NSAttributedString alloc] initWithString:kLang(@"cart_undo_action")
                                                                  attributes:@{
            NSFontAttributeName: [GM boldFontWithSize:14],
            NSForegroundColorAttributeName: UIColor.whiteColor
        }];
        undoButton.configuration = config;
    } else {
        undoButton.titleLabel.font = [GM boldFontWithSize:14];
        [undoButton setTitle:kLang(@"cart_undo_action") forState:UIControlStateNormal];
        [undoButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        undoButton.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.22];
        undoButton.layer.borderWidth = 0.0;
    }
    [undoButton addTarget:self action:@selector(pp_undoLastRemovalTapped) forControlEvents:UIControlEventTouchUpInside];
    undoButton.accessibilityLabel = NSLocalizedString(@"a11y_btn_undo_remove", @"Undo remove");
    undoButton.accessibilityHint  = NSLocalizedString(@"a11y_btn_undo_remove_hint", @"Double-tap to restore the removed item");

    [container addSubview:label];
    [container addSubview:undoButton];
    [self.view addSubview:container];

    [NSLayoutConstraint activateConstraints:@[
        [container.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [container.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [container.bottomAnchor constraintEqualToAnchor:self.summaryView.topAnchor constant:-14],
        [container.heightAnchor constraintGreaterThanOrEqualToConstant:58],

        [label.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:16],
        [label.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [label.trailingAnchor constraintLessThanOrEqualToAnchor:undoButton.leadingAnchor constant:-12],

        [undoButton.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-14],
        [undoButton.centerYAnchor constraintEqualToAnchor:container.centerYAnchor]
    ]];

    self.undoContainerView = container;
    self.undoLabel = label;
    self.undoButton = undoButton;
    self.lastRemovedCartIndex = NSNotFound;
    [self pp_setUndoButtonTitle:kLang(@"cart_undo_action")];
}

- (void)pp_presentUndoForItem:(CartItem *)item originalIndex:(NSInteger)index
{
    self.lastRemovedCartItem = [self pp_cloneCartItem:item];
    self.lastRemovedCartIndex = index;
    self.undoLabel.text = kLang(@"cart_undo_message");
    [self pp_setUndoButtonTitle:kLang(@"cart_undo_action")];

    self.undoPresentationToken += 1;
    NSUInteger token = self.undoPresentationToken;

    self.undoContainerView.hidden = NO;
    [UIView animateWithDuration:0.22 animations:^{
        self.undoContainerView.alpha = 1.0;
    }];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (token != self.undoPresentationToken) return;
        [self pp_hideUndoBarAnimated:YES clearPayload:YES];
    });
}

- (void)pp_hideUndoBarAnimated:(BOOL)animated clearPayload:(BOOL)clearPayload
{
    self.undoPresentationToken += 1;
    if (clearPayload) {
        self.lastRemovedCartItem = nil;
        self.lastRemovedCartIndex = NSNotFound;
    }

    if (!animated) {
        self.undoContainerView.alpha = 0.0;
        self.undoContainerView.hidden = YES;
        return;
    }

    [UIView animateWithDuration:0.2 animations:^{
        self.undoContainerView.alpha = 0.0;
    } completion:^(__unused BOOL finished) {
        self.undoContainerView.hidden = YES;
    }];
}

- (void)pp_undoLastRemovalTapped
{
    if (!self.lastRemovedCartItem) return;

    CartItem *restored = [self pp_cloneCartItem:self.lastRemovedCartItem];
    NSInteger preferredIndex = self.lastRemovedCartIndex;
    [self pp_hideUndoBarAnimated:YES clearPayload:YES];

    CartManager *manager = [CartManager sharedManager];
    CartItem *existing = [manager getCartItemForItemID:restored.itemID];
    if (existing) {
        NSInteger mergedQuantity = existing.quantity + restored.quantity;
        [manager updateQuantity:mergedQuantity forItem:existing completion:nil];
    } else {
        NSInteger safeIndex = MIN(MAX(preferredIndex, 0), manager.cartItems.count);
        [manager.cartItems insertObject:restored atIndex:safeIndex];
        [manager saveCart];

        if (UserManager.sharedManager.currentUser.ID.length > 0) {
            [manager syncCartToFirestore:@[restored]];
        } else {
            [[NSNotificationCenter defaultCenter] postNotificationName:kCartUpdatedNotification object:nil];
        }
    }

    [self pp_notifyCartBadgeAndCollections];
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventCartUndo];
}

- (void)pp_removeItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (!indexPath) return;
    if (indexPath.row >= CartManager.sharedManager.cartItems.count) return;
    if (self.isPerformingTableMutation) return;

    self.isPerformingTableMutation = YES;

    CartItem *item = CartManager.sharedManager.cartItems[indexPath.row];
    CartItem *removedSnapshot = [self pp_cloneCartItem:item];
    NSInteger removedIndex = indexPath.row;

    [[CartManager sharedManager] removeItem:item];
    [[CartManager sharedManager] saveCart];
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventCartItemRemoved];

    [self.cartTableView performBatchUpdates:^{
        [self.cartTableView deleteRowsAtIndexPaths:@[indexPath]
                                  withRowAnimation:UITableViewRowAnimationFade];
    } completion:^(__unused BOOL finished) {
        self.isPerformingTableMutation = NO;
        [self updateTotalLabel];
        [self pp_notifyCartBadgeAndCollections];
        [self pp_presentUndoForItem:removedSnapshot originalIndex:removedIndex];
    }];
}

- (void)checkoutTapped {
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [self.summaryView setCheckoutLoading:NO];
        [UserManager showPromptOnTopController];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        return;
    }

    if ([CartManager sharedManager].cartItems.count == 0) {
        [self.summaryView setCheckoutLoading:NO];
        [PPAlertHelper showWarningIn:self
                               title:kLang(@"checkout_cart_empty")
                            subtitle:kLang(@"checkout_cart_empty_message")];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        return;
    }

    [self.summaryView setCheckoutLoading:YES];
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];

    // Order is created in PPCheckoutCoordinator from payment screen.
    PPSelectPaymentVC *vc = [[PPSelectPaymentVC alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - Saved For Later Inline Rows

- (NSArray<CartItem *> *)pp_savedForLaterItems
{
    return [[PPSaveForLaterManager sharedManager] savedItems] ?: @[];
}

- (NSInteger)pp_cartItemsCount
{
    return [CartManager sharedManager].cartItems.count;
}

- (NSInteger)pp_savedForLaterDockRowIndex
{
    return [self pp_cartItemsCount];
}

- (BOOL)pp_shouldShowSavedForLaterInlineRows
{
    return self.savedForLaterExpanded &&
    ([self pp_savedForLaterItems].count > 0 || self.savedForLaterRetainsEmptyDockDuringTransition);
}

- (BOOL)pp_isCartItemIndexPath:(NSIndexPath *)indexPath
{
    return indexPath && indexPath.section == 0 && indexPath.row < [self pp_cartItemsCount];
}

- (BOOL)pp_isSavedForLaterDockIndexPath:(NSIndexPath *)indexPath
{
    return indexPath &&
    indexPath.section == 0 &&
    [self pp_shouldShowSavedForLaterInlineRows] &&
    indexPath.row == [self pp_savedForLaterDockRowIndex];
}

- (CartItem *)pp_savedForLaterItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (!indexPath || ![self pp_shouldShowSavedForLaterInlineRows]) {
        return nil;
    }
    NSInteger savedIndex = indexPath.row - [self pp_savedForLaterDockRowIndex] - 1;
    NSArray<CartItem *> *savedItems = [self pp_savedForLaterItems];
    if (savedIndex < 0 || savedIndex >= (NSInteger)savedItems.count) {
        return nil;
    }
    return savedItems[savedIndex];
}

- (NSArray<NSIndexPath *> *)pp_savedForLaterExpandedIndexPathsForSavedCount:(NSInteger)savedCount
{
    if (savedCount <= 0) {
        return @[];
    }
    NSInteger dockRow = [self pp_savedForLaterDockRowIndex];
    NSMutableArray<NSIndexPath *> *indexPaths = [NSMutableArray arrayWithCapacity:(NSUInteger)savedCount + 1];
    [indexPaths addObject:[NSIndexPath indexPathForRow:dockRow inSection:0]];
    for (NSInteger index = 0; index < savedCount; index += 1) {
        [indexPaths addObject:[NSIndexPath indexPathForRow:dockRow + 1 + index inSection:0]];
    }
    return [indexPaths copy];
}

- (UIView *)pp_snapshotForSourceView:(UIView *)sourceView
{
    if (!sourceView || !sourceView.window) {
        return nil;
    }
    [sourceView layoutIfNeeded];
    UIView *snapshot = [sourceView snapshotViewAfterScreenUpdates:NO];
    snapshot.frame = [sourceView.superview convertRect:sourceView.frame toView:self.view];
    snapshot.layer.cornerRadius = sourceView.layer.cornerRadius;
    snapshot.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        snapshot.layer.cornerCurve = kCACornerCurveContinuous;
    }
    return snapshot;
}

- (void)pp_runSavedDockMorphFromSnapshot:(UIView *)sourceSnapshot
                               toTargetView:(UIView *)targetView
                                  expanding:(BOOL)expanding
                                  completion:(void (^)(void))completion
{
    if (!targetView || !targetView.superview) {
        [sourceSnapshot removeFromSuperview];
        if (completion) completion();
        return;
    }

    [targetView.superview layoutIfNeeded];
    CGRect targetFrame = [targetView.superview convertRect:targetView.frame toView:self.view];
    UIView *targetSnapshot = [targetView snapshotViewAfterScreenUpdates:YES];
    if (!targetSnapshot) {
        [sourceSnapshot removeFromSuperview];
        targetView.alpha = 1.0;
        if (completion) completion();
        return;
    }
    targetSnapshot.frame = targetFrame;
    targetSnapshot.userInteractionEnabled = NO;
    targetView.alpha = 0.0;

    if (!sourceSnapshot || UIAccessibilityIsReduceMotionEnabled()) {
        [sourceSnapshot removeFromSuperview];
        if (targetSnapshot) {
            targetSnapshot.alpha = 0.0;
            [self.view addSubview:targetSnapshot];
            [UIView animateWithDuration:0.18 animations:^{
                targetSnapshot.alpha = 1.0;
            } completion:^(__unused BOOL finished) {
                targetView.alpha = 1.0;
                [targetSnapshot removeFromSuperview];
                if (completion) completion();
            }];
        } else if (completion) {
            targetView.alpha = 1.0;
            completion();
        }
        return;
    }

    self.savedForLaterAnimationToken += 1;
    NSUInteger token = self.savedForLaterAnimationToken;

    CGFloat sourceWidth = MAX(CGRectGetWidth(sourceSnapshot.bounds), 1.0);
    CGFloat targetWidth = MAX(CGRectGetWidth(targetFrame), 1.0);
    CGFloat sourceToTargetScale = targetWidth / sourceWidth;
    CGFloat targetFromSourceScale = sourceWidth / targetWidth;

    UIView *accentBloom = [[UIView alloc] initWithFrame:CGRectInset(targetFrame, -8.0, -6.0)];
    accentBloom.userInteractionEnabled = NO;
    accentBloom.backgroundColor = [PPSavedForLaterDeferredAccentColor() colorWithAlphaComponent:0.12];
    accentBloom.layer.cornerRadius = CGRectGetHeight(accentBloom.bounds) * 0.42;
    accentBloom.alpha = 0.0;
    accentBloom.transform = CGAffineTransformMakeScale(0.94, 0.94);

    targetSnapshot.alpha = 0.0;
    targetSnapshot.transform = CGAffineTransformMakeScale(targetFromSourceScale, targetFromSourceScale);
    [self.view addSubview:accentBloom];
    [self.view addSubview:sourceSnapshot];
    [self.view addSubview:targetSnapshot];

    [UIView animateKeyframesWithDuration:kPPSavedDockMorphDuration
                                   delay:0.0
                                 options:UIViewKeyframeAnimationOptionCalculationModeCubic | UIViewKeyframeAnimationOptionAllowUserInteraction
                              animations:^{
        [UIView addKeyframeWithRelativeStartTime:0.00 relativeDuration:0.76 animations:^{
            sourceSnapshot.center = CGPointMake(CGRectGetMidX(targetFrame), CGRectGetMidY(targetFrame));
            sourceSnapshot.transform = CGAffineTransformMakeScale(sourceToTargetScale, sourceToTargetScale);
            sourceSnapshot.alpha = 0.94;
            accentBloom.alpha = 0.16;
            accentBloom.transform = CGAffineTransformMakeScale(1.02, 1.02);
        }];
        [UIView addKeyframeWithRelativeStartTime:0.42 relativeDuration:0.48 animations:^{
            sourceSnapshot.alpha = 0.0;
            targetSnapshot.alpha = 1.0;
            targetSnapshot.transform = CGAffineTransformIdentity;
        }];
        [UIView addKeyframeWithRelativeStartTime:0.70 relativeDuration:0.30 animations:^{
            accentBloom.alpha = 0.0;
            accentBloom.transform = CGAffineTransformMakeScale(1.06, 1.06);
        }];
    } completion:^(__unused BOOL finished) {
        [sourceSnapshot removeFromSuperview];
        [targetSnapshot removeFromSuperview];
        [accentBloom removeFromSuperview];
        targetView.alpha = 1.0;

        if (token == self.savedForLaterAnimationToken && expanding &&
            [targetView.superview.superview isKindOfClass:PPSavedForLaterDockTableCell.class]) {
            [(PPSavedForLaterDockTableCell *)targetView.superview.superview playExpansionEntryIfNeeded];
        }
        if (UIAccessibilityIsVoiceOverRunning()) {
            id focusTarget = expanding && [targetView.superview.superview isKindOfClass:PPSavedForLaterDockTableCell.class]
                ? targetView.superview.superview
                : targetView;
            UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, focusTarget);
        }
        if (completion) completion();
    }];
}

- (void)pp_revealSavedForLaterRowsFromDock
{
    NSArray<NSIndexPath *> *visiblePaths = [[self.cartTableView indexPathsForVisibleRows]
        sortedArrayUsingSelector:@selector(compare:)];
    NSMutableArray<NSIndexPath *> *savedPaths = [NSMutableArray array];
    for (NSIndexPath *indexPath in visiblePaths) {
        if ([self pp_savedForLaterItemAtIndexPath:indexPath]) {
            [savedPaths addObject:indexPath];
        }
    }

    if (savedPaths.count == 0 || UIAccessibilityIsReduceMotionEnabled()) {
        for (NSIndexPath *indexPath in savedPaths) {
            UITableViewCell *cell = [self.cartTableView cellForRowAtIndexPath:indexPath];
            cell.alpha = 1.0;
            cell.transform = CGAffineTransformIdentity;
        }
        self.savedForLaterRevealInProgress = NO;
        return;
    }

    for (NSInteger index = 0; index < (NSInteger)savedPaths.count; index += 1) {
        UITableViewCell *cell = [self.cartTableView cellForRowAtIndexPath:savedPaths[index]];
        if (!cell) continue;

        CGFloat offset = MIN(34.0, 18.0 + (index * 4.0));
        cell.alpha = 0.0;
        cell.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, -offset),
                                                 CGAffineTransformMakeScale(0.974, 0.974));
        NSTimeInterval delay = 0.055 + MIN(0.034 * index, 0.14);
        [UIView animateWithDuration:kPPSavedRowRevealDuration
                              delay:delay
             usingSpringWithDamping:0.90
              initialSpringVelocity:0.20
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            cell.alpha = 1.0;
            cell.transform = CGAffineTransformIdentity;
        } completion:nil];
    }

    NSTimeInterval finalDelay = 0.055 + MIN(0.034 * MAX((NSInteger)savedPaths.count - 1, 0), 0.14);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)((finalDelay + kPPSavedRowRevealDuration) * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        self.savedForLaterRevealInProgress = NO;
    });
}

- (void)pp_setSavedForLaterExpanded:(BOOL)expanded
                            animated:(BOOL)animated
                          sourceView:(UIView *)sourceView
{
    NSArray<CartItem *> *savedItems = [self pp_savedForLaterItems];
    if (expanded && savedItems.count == 0) {
        return;
    }
    if (self.savedForLaterExpanded == expanded || self.isPerformingTableMutation) {
        return;
    }

    NSInteger savedCount = savedItems.count;
    NSArray<NSIndexPath *> *indexPaths = [self pp_savedForLaterExpandedIndexPathsForSavedCount:savedCount];
    if (indexPaths.count == 0) {
        return;
    }

    UISelectionFeedbackGenerator *selection = [[UISelectionFeedbackGenerator alloc] init];
    [selection prepare];
    [selection selectionChanged];

    self.isPerformingTableMutation = YES;
    self.cartTableView.userInteractionEnabled = NO;
    if (expanded) {
        self.savedForLaterExpanded = YES;
        self.savedForLaterRevealInProgress = animated && !UIAccessibilityIsReduceMotionEnabled();
        self.savedForLaterRetainsEmptyDockDuringTransition = NO;
        UIView *source = sourceView ?: self.cartTableView.tableFooterView;
        UIView *sourceSnapshot = [self pp_snapshotForSourceView:source];
        self.savedForLaterFooterPillButton = nil;
        self.cartTableView.tableFooterView = nil;
        [UIView performWithoutAnimation:^{
            [self.cartTableView performBatchUpdates:^{
                [self.cartTableView insertRowsAtIndexPaths:indexPaths
                                          withRowAnimation:UITableViewRowAnimationNone];
            } completion:nil];
            [self.cartTableView layoutIfNeeded];
        }];

        PPSavedForLaterDockTableCell *dockCell =
        (PPSavedForLaterDockTableCell *)[self.cartTableView cellForRowAtIndexPath:indexPaths.firstObject];
        [self pp_revealSavedForLaterRowsFromDock];
        [self pp_runSavedDockMorphFromSnapshot:animated ? sourceSnapshot : nil
                                  toTargetView:dockCell.dockContainerView
                                     expanding:YES
                                     completion:^{
            self.isPerformingTableMutation = NO;
            self.cartTableView.userInteractionEnabled = YES;
            [self pp_applyEmptyStateIfNeeded];
        }];
        return;
    }

    NSIndexPath *dockIndexPath = indexPaths.firstObject;
    PPSavedForLaterDockTableCell *dockCell =
    (PPSavedForLaterDockTableCell *)[self.cartTableView cellForRowAtIndexPath:dockIndexPath];
    UIView *sourceSnapshot = [self pp_snapshotForSourceView:dockCell.dockContainerView ?: dockCell];
    self.savedForLaterExpanded = NO;
    self.savedForLaterRevealInProgress = NO;
    self.savedForLaterRetainsEmptyDockDuringTransition = NO;
    self.pendingSavedForLaterItemID = nil;
    self.pendingSavedForLaterOperation = nil;
    self.completedSavedForLaterItemID = nil;
    [UIView performWithoutAnimation:^{
        [self.cartTableView performBatchUpdates:^{
            [self.cartTableView deleteRowsAtIndexPaths:indexPaths
                                      withRowAnimation:UITableViewRowAnimationNone];
        } completion:nil];
        [self pp_updateSavedForLaterFooter];
        [self.cartTableView layoutIfNeeded];
    }];

    [self pp_runSavedDockMorphFromSnapshot:animated ? sourceSnapshot : nil
                              toTargetView:self.savedForLaterFooterPillButton
                                 expanding:NO
                                 completion:^{
        self.isPerformingTableMutation = NO;
        self.cartTableView.userInteractionEnabled = YES;
        [self pp_applyEmptyStateIfNeeded];
    }];
}

- (NSIndexPath *)pp_indexPathForSavedForLaterItemID:(NSString *)itemID
{
    if (itemID.length == 0 || ![self pp_shouldShowSavedForLaterInlineRows]) {
        return nil;
    }

    NSArray<CartItem *> *savedItems = [self pp_savedForLaterItems];
    NSInteger dockRow = [self pp_savedForLaterDockRowIndex];
    for (NSInteger index = 0; index < (NSInteger)savedItems.count; index += 1) {
        CartItem *item = savedItems[index];
        if ([item.itemID isEqualToString:itemID]) {
            return [NSIndexPath indexPathForRow:dockRow + 1 + index inSection:0];
        }
    }
    return nil;
}

- (CartItem *)pp_copySavedCartItem:(CartItem *)item
{
    CartItem *copy = [[CartItem alloc] init];
    copy.itemID = item.itemID ?: @"";
    copy.name = item.name ?: @"";
    copy.quantity = MAX(1, item.quantity);
    copy.stockQuantity = item.stockQuantity;
    copy.price = item.price;
    copy.originalPrice = item.originalPrice;
    copy.imageURL = item.imageURL ?: @"";
    copy.providerID = item.providerID ?: @"";
    copy.type = item.type ?: @"";
    return copy;
}

- (CartItem *)pp_cartItemFromSavedItem:(CartItem *)savedItem
                             accessory:(PetAccessory *)accessory
{
    CartItem *resolvedItem = [[CartItem alloc] initWithAccessory:accessory
                                                        quantity:MAX(1, savedItem.quantity)];
    if (savedItem.type.length > 0) {
        resolvedItem.type = savedItem.type;
    }
    return resolvedItem;
}

- (void)pp_resolveCartItemForMoveToCart:(CartItem *)savedItem
                              completion:(void (^)(CartItem * _Nullable resolvedItem,
                                                   BOOL isOutOfStock))completion
{
    if (!savedItem || savedItem.itemID.length == 0) {
        if (completion) completion(nil, NO);
        return;
    }

    if (savedItem.stockQuantity != NSNotFound) {
        if (savedItem.stockQuantity <= 0) {
            if (completion) completion(nil, YES);
            return;
        }
        if (savedItem.price >= 0.01) {
            if (completion) completion([self pp_copySavedCartItem:savedItem], NO);
            return;
        }
    }

    PetAccessory *cachedAccessory = [[PetAccessoryManager sharedManager] getAccessoryID:savedItem.itemID];
    if (cachedAccessory) {
        if (cachedAccessory.quantity <= 0) {
            if (completion) completion(nil, YES);
            return;
        }
        if (completion) completion([self pp_cartItemFromSavedItem:savedItem accessory:cachedAccessory], NO);
        return;
    }

    [PetAccessoryManager fetchAccessoriesWithIDs:@[savedItem.itemID ?: @""]
                                      completion:^(NSArray<PetAccessory *> *accessories) {
        PetAccessory *freshAccessory = accessories.firstObject;
        if (!freshAccessory) {
            if (completion) completion(nil, NO);
            return;
        }
        if (freshAccessory.quantity <= 0) {
            if (completion) completion(nil, YES);
            return;
        }
        if (completion) completion([self pp_cartItemFromSavedItem:savedItem accessory:freshAccessory], NO);
    }];
}

- (void)pp_setSavedForLaterPendingItemID:(NSString *)itemID operation:(NSString *)operation
{
    self.pendingSavedForLaterItemID = itemID.length > 0 ? itemID : nil;
    self.pendingSavedForLaterOperation = self.pendingSavedForLaterItemID ? operation : nil;
    if (self.pendingSavedForLaterItemID) {
        self.completedSavedForLaterItemID = nil;
    }
    [self pp_refreshVisibleSavedItemID:self.pendingSavedForLaterItemID];
}

- (void)pp_clearSavedForLaterPendingStateAndReload
{
    NSString *previousItemID = self.pendingSavedForLaterItemID;
    self.pendingSavedForLaterItemID = nil;
    self.pendingSavedForLaterOperation = nil;
    self.completedSavedForLaterItemID = nil;
    [self pp_refreshVisibleSavedItemID:previousItemID];
}

- (NSInteger)pp_cartRowForItemID:(NSString *)itemID
{
    if (itemID.length == 0) return NSNotFound;
    NSArray<CartItem *> *cartItems = [CartManager sharedManager].cartItems;
    for (NSInteger index = 0; index < (NSInteger)cartItems.count; index += 1) {
        CartItem *item = cartItems[index];
        if ([item.itemID isEqualToString:itemID]) {
            return index;
        }
    }
    return NSNotFound;
}

- (void)pp_configureActiveCartCell:(PPCartTableCell *)cell item:(CartItem *)item
{
    if (![cell isKindOfClass:PPCartTableCell.class] || !item) {
        return;
    }

    [cell configureWithItem:item];
    __weak typeof(self) weakSelf = self;
    cell.onAction = ^(CartItem *actionItem, NSString *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if ([action isEqualToString:@"plus"] || [action isEqualToString:@"minus"]) {
            NSUInteger previousSkipCount = strongSelf.pendingQuantitySyncReloadSkips;
            strongSelf.pendingQuantitySyncReloadSkips = MIN(previousSkipCount + 2, 8);
            [[CartManager sharedManager] updateQuantity:actionItem.quantity
                                                forItem:actionItem
                                             completion:^(BOOL success) {
                if (!success) {
                    strongSelf.pendingQuantitySyncReloadSkips = previousSkipCount;
                }
            }];
            [strongSelf updateTotalLabel];
        }
    };
}

- (void)pp_configureSavedCartCell:(PPCartTableCell *)cell item:(CartItem *)item
{
    if (![cell isKindOfClass:PPCartTableCell.class] || !item) {
        return;
    }

    NSString *pendingOperation = [item.itemID isEqualToString:self.pendingSavedForLaterItemID]
        ? self.pendingSavedForLaterOperation
        : nil;
    BOOL completed = [item.itemID isEqualToString:self.completedSavedForLaterItemID];
    [cell configureWithSavedForLaterItem:item
                        pendingOperation:pendingOperation
                               completed:completed];

    __weak typeof(self) weakSelf = self;
    cell.onAction = ^(CartItem *actionItem, NSString *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if ([action isEqualToString:@"moveSavedToCart"]) {
            [strongSelf pp_moveSavedForLaterItemToCart:actionItem];
        } else if ([action isEqualToString:@"removeSavedForLater"]) {
            [strongSelf pp_confirmRemoveSavedForLaterItem:actionItem];
        } else if ([action isEqualToString:@"notifySavedWhenAvailable"]) {
            [strongSelf pp_registerStockNotificationForSavedItem:actionItem];
        }
    };
}

- (void)pp_refreshVisibleSavedItemID:(NSString *)itemID
{
    if (itemID.length == 0) return;
    NSIndexPath *indexPath = [self pp_indexPathForSavedForLaterItemID:itemID];
    if (!indexPath) return;
    PPCartTableCell *cell = (PPCartTableCell *)[self.cartTableView cellForRowAtIndexPath:indexPath];
    CartItem *item = [self pp_savedForLaterItemAtIndexPath:indexPath];
    if ([cell isKindOfClass:PPCartTableCell.class] && item) {
        [self pp_configureSavedCartCell:cell item:item];
    }
}

- (void)pp_animateTransferSnapshot:(UIView *)snapshot
                     toTargetFrame:(CGRect)targetFrame
                        completion:(void (^)(void))completion
{
    if (!snapshot || CGRectIsEmpty(targetFrame)) {
        [snapshot removeFromSuperview];
        if (completion) completion();
        return;
    }

    if (UIAccessibilityIsReduceMotionEnabled()) {
        if (!snapshot.superview) [self.view addSubview:snapshot];
        [UIView animateWithDuration:0.18 animations:^{
            snapshot.alpha = 0.0;
        } completion:^(__unused BOOL finished) {
            [snapshot removeFromSuperview];
            if (completion) completion();
        }];
        return;
    }

    if (!snapshot.superview) {
        [self.view addSubview:snapshot];
    }
    [self.view bringSubviewToFront:snapshot];
    snapshot.userInteractionEnabled = NO;

    CGPoint startPoint = snapshot.center;
    CGPoint endPoint = CGPointMake(CGRectGetMidX(targetFrame), CGRectGetMidY(targetFrame));
    CGFloat direction = Language.isRTL ? -1.0 : 1.0;
    CGFloat verticalDistance = fabs(endPoint.y - startPoint.y);
    CGFloat arcDistance = MIN(28.0, MAX(12.0, verticalDistance * 0.08));
    CGPoint liftedPoint = CGPointMake(startPoint.x + (5.0 * direction), startPoint.y - 8.0);
    CGPoint midpoint = CGPointMake((startPoint.x + endPoint.x) * 0.5 + (arcDistance * direction),
                                   (startPoint.y + endPoint.y) * 0.5 - MIN(24.0, MAX(14.0, verticalDistance * 0.06)));

    CGFloat sourceWidth = MAX(CGRectGetWidth(snapshot.bounds), 1.0);
    CGFloat sourceHeight = MAX(CGRectGetHeight(snapshot.bounds), 1.0);
    CGFloat widthScale = CGRectGetWidth(targetFrame) / sourceWidth;
    CGFloat heightScale = CGRectGetHeight(targetFrame) / sourceHeight;
    CGFloat targetScale = MAX(0.88, MIN(1.02, MIN(widthScale, heightScale)));
    UIViewKeyframeAnimationOptions options = UIViewKeyframeAnimationOptionCalculationModeCubic |
        UIViewAnimationOptionBeginFromCurrentState |
        UIViewAnimationOptionAllowUserInteraction;

    [UIView animateKeyframesWithDuration:kPPSavedTransferDuration
                                   delay:0.0
                                 options:options
                              animations:^{
        [UIView addKeyframeWithRelativeStartTime:0.0
                                relativeDuration:0.16
                                      animations:^{
            snapshot.center = liftedPoint;
            snapshot.transform = CGAffineTransformMakeScale(0.985, 0.985);
            snapshot.alpha = 1.0;
        }];
        [UIView addKeyframeWithRelativeStartTime:0.16
                                relativeDuration:0.50
                                      animations:^{
            snapshot.center = midpoint;
            snapshot.transform = CGAffineTransformMakeScale(1.006, 1.006);
            snapshot.alpha = 1.0;
        }];
        [UIView addKeyframeWithRelativeStartTime:0.66
                                relativeDuration:0.34
                                      animations:^{
            snapshot.center = endPoint;
            snapshot.transform = CGAffineTransformMakeScale(targetScale, targetScale);
            snapshot.alpha = 0.04;
        }];
    } completion:^(__unused BOOL finished) {
        [snapshot removeFromSuperview];
        if (completion) completion();
    }];
}

- (CGRect)pp_controllerFrameForCartRow:(NSInteger)row
{
    if (row == NSNotFound || row < 0) {
        return CGRectZero;
    }

    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
    UITableViewCell *visibleCell = [self.cartTableView cellForRowAtIndexPath:indexPath];
    CGRect frame = CGRectZero;
    if (visibleCell && visibleCell.superview) {
        frame = [visibleCell.superview convertRect:visibleCell.frame toView:self.view];
        frame.size.height = 134.0;
    } else {
        CGRect rowRect = [self.cartTableView rectForRowAtIndexPath:indexPath];
        rowRect.size.height = 134.0;
        frame = [self.cartTableView convertRect:rowRect toView:self.view];
    }

    CGRect visibleTableFrame = [self.cartTableView convertRect:self.cartTableView.bounds toView:self.view];
    if (CGRectGetMaxY(frame) < CGRectGetMinY(visibleTableFrame)) {
        frame.origin.y = CGRectGetMinY(visibleTableFrame) - (CGRectGetHeight(frame) * 0.56);
    } else if (CGRectGetMinY(frame) > CGRectGetMaxY(visibleTableFrame)) {
        frame.origin.y = CGRectGetMaxY(visibleTableFrame) - (CGRectGetHeight(frame) * 0.44);
    }
    return frame;
}

- (void)pp_performSavedTransferTableUpdates:(dispatch_block_t)updates
                                  completion:(void (^)(BOOL finished))completion
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(kPPSavedTransferAnticipationDuration * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [CATransaction begin];
        [CATransaction setAnimationDuration:kPPSavedTableReflowDuration];
        [CATransaction setAnimationTimingFunction:
         [CAMediaTimingFunction functionWithControlPoints:0.40 :0.0 :0.20 :1.0]];
        [self.cartTableView performBatchUpdates:^{
            if (updates) updates();
        } completion:^(BOOL finished) {
            if (completion) completion(finished);
        }];
        [CATransaction commit];
    });
}

- (void)pp_finishSavedForLaterMoveFeedback
{
    self.isPerformingTableMutation = NO;
    self.cartTableView.userInteractionEnabled = YES;
    [self updateTotalLabel];
    [self pp_notifyCartBadgeAndCollections];
    [self pp_updateSavedForLaterFooter];
    [self pp_applyEmptyStateIfNeeded];

    UINotificationFeedbackGenerator *notification = self.savedMoveFeedbackGenerator;
    if (!notification) {
        notification = [[UINotificationFeedbackGenerator alloc] init];
        [notification prepare];
    }
    [notification notificationOccurred:UINotificationFeedbackTypeSuccess];
    self.savedMoveFeedbackGenerator = nil;
    [PPHUD showSuccess:kLang(@"moved_to_cart_success")];
}

- (void)pp_finishSavedForLaterArrivalAtRow:(NSInteger)targetRow
                              savedCount:(NSInteger)savedCount
                               completion:(void (^)(void))completion
{
    [self.savedMoveFeedbackGenerator prepare];
    dispatch_group_t choreographyGroup = dispatch_group_create();
    NSIndexPath *targetIndexPath = targetRow == NSNotFound
        ? nil
        : [NSIndexPath indexPathForRow:targetRow inSection:0];
    PPCartTableCell *targetCell = targetIndexPath
        ? (PPCartTableCell *)[self.cartTableView cellForRowAtIndexPath:targetIndexPath]
        : nil;
    if ([targetCell isKindOfClass:PPCartTableCell.class]) {
        NSArray<CartItem *> *cartItems = [CartManager sharedManager].cartItems;
        if (targetRow >= 0 && targetRow < (NSInteger)cartItems.count) {
            [self pp_configureActiveCartCell:targetCell item:cartItems[targetRow]];
        }
        targetCell.alpha = 1.0;
        targetCell.transform = CGAffineTransformIdentity;
        dispatch_group_enter(choreographyGroup);
        [targetCell playSavedForLaterArrivalAnimationWithCompletion:^{
            if (UIAccessibilityIsVoiceOverRunning()) {
                UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, targetCell);
            }
            dispatch_group_leave(choreographyGroup);
        }];
    }

    if (savedCount > 0) {
        NSIndexPath *dockIndexPath = [NSIndexPath indexPathForRow:[self pp_cartItemsCount] inSection:0];
        PPSavedForLaterDockTableCell *dockCell =
        (PPSavedForLaterDockTableCell *)[self.cartTableView cellForRowAtIndexPath:dockIndexPath];
        if ([dockCell isKindOfClass:PPSavedForLaterDockTableCell.class]) {
            dispatch_group_enter(choreographyGroup);
            [UIView transitionWithView:dockCell.countBadgeLabel
                              duration:0.20
                               options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowUserInteraction
                            animations:^{
                [dockCell configureWithSavedCount:savedCount expanded:YES];
                dockCell.countBadgeLabel.transform = CGAffineTransformMakeScale(1.035, 1.035);
            } completion:^(__unused BOOL finished) {
                [UIView animateWithDuration:0.18
                                      delay:0.0
                     usingSpringWithDamping:0.92
                      initialSpringVelocity:0.16
                                    options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                                 animations:^{
                    dockCell.countBadgeLabel.transform = CGAffineTransformIdentity;
                } completion:^(__unused BOOL settled) {
                    dispatch_group_leave(choreographyGroup);
                }];
            }];
        }
    } else if (self.savedForLaterRetainsEmptyDockDuringTransition) {
        NSIndexPath *emptyDockIndexPath = [NSIndexPath indexPathForRow:[self pp_cartItemsCount] inSection:0];
        PPSavedForLaterDockTableCell *emptyDockCell =
        (PPSavedForLaterDockTableCell *)[self.cartTableView cellForRowAtIndexPath:emptyDockIndexPath];
        dispatch_group_enter(choreographyGroup);

        void (^deleteEmptyDock)(void) = ^{
            self.savedForLaterRetainsEmptyDockDuringTransition = NO;
            self.savedForLaterExpanded = NO;
            [UIView performWithoutAnimation:^{
                [self.cartTableView performBatchUpdates:^{
                    [self.cartTableView deleteRowsAtIndexPaths:@[emptyDockIndexPath]
                                              withRowAnimation:UITableViewRowAnimationNone];
                } completion:^(__unused BOOL finished) {
                    dispatch_group_leave(choreographyGroup);
                }];
            }];
        };

        if (!emptyDockCell || UIAccessibilityIsReduceMotionEnabled()) {
            deleteEmptyDock();
        } else {
            [UIView animateWithDuration:0.22
                                  delay:0.04
                                options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                emptyDockCell.dockContainerView.alpha = 0.0;
                emptyDockCell.dockContainerView.transform =
                CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, -8.0),
                                        CGAffineTransformMakeScale(0.982, 0.982));
            } completion:^(__unused BOOL finished) {
                deleteEmptyDock();
            }];
        }
    }

    dispatch_group_notify(choreographyGroup, dispatch_get_main_queue(), ^{
        if (completion) completion();
    });
}

- (void)pp_presentSuccessfulSavedMoveForItem:(CartItem *)item
                              sourceIndexPath:(NSIndexPath *)sourceIndexPath
                               sourceSnapshot:(UIView *)sourceSnapshot
                                  oldCartCount:(NSInteger)oldCartCount
                                    oldCartRow:(NSInteger)oldCartRow
{
    NSInteger newCartCount = [self pp_cartItemsCount];
    NSInteger newSavedCount = [self pp_savedForLaterItems].count;
    NSInteger targetRow = [self pp_cartRowForItemID:item.itemID];
    BOOL insertedNewCartRow = oldCartRow == NSNotFound &&
        targetRow != NSNotFound && newCartCount == oldCartCount + 1;
    BOOL mergedIntoCartRow = oldCartRow != NSNotFound &&
        targetRow != NSNotFound && newCartCount == oldCartCount;

    self.pendingSavedForLaterItemID = nil;
    self.pendingSavedForLaterOperation = nil;
    self.completedSavedForLaterItemID = nil;
    self.cartTableView.userInteractionEnabled = NO;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        [sourceSnapshot removeFromSuperview];
        void (^finishReducedMotionUpdate)(void) = ^{
            [self pp_finishSavedForLaterArrivalAtRow:targetRow
                                         savedCount:newSavedCount
                                          completion:^{
                [self pp_finishSavedForLaterMoveFeedback];
            }];
        };

        if (insertedNewCartRow && sourceIndexPath) {
            self.savedForLaterRetainsEmptyDockDuringTransition = newSavedCount == 0;
            self.savedForLaterExpanded = YES;
            NSIndexPath *targetIndexPath = [NSIndexPath indexPathForRow:targetRow inSection:0];
            [UIView performWithoutAnimation:^{
                [self.cartTableView performBatchUpdates:^{
                    [self.cartTableView moveRowAtIndexPath:sourceIndexPath toIndexPath:targetIndexPath];
                } completion:^(__unused BOOL finished) {
                    finishReducedMotionUpdate();
                }];
            }];
            return;
        }

        if (mergedIntoCartRow && sourceIndexPath) {
            NSMutableArray<NSIndexPath *> *deletePaths = [NSMutableArray arrayWithObject:sourceIndexPath];
            if (newSavedCount == 0) {
                [deletePaths addObject:[NSIndexPath indexPathForRow:oldCartCount inSection:0]];
            }
            self.savedForLaterRetainsEmptyDockDuringTransition = NO;
            self.savedForLaterExpanded = newSavedCount > 0;
            [UIView performWithoutAnimation:^{
                [self.cartTableView performBatchUpdates:^{
                    [self.cartTableView deleteRowsAtIndexPaths:deletePaths
                                              withRowAnimation:UITableViewRowAnimationNone];
                } completion:^(__unused BOOL finished) {
                    finishReducedMotionUpdate();
                }];
            }];
            return;
        }

        self.savedForLaterRetainsEmptyDockDuringTransition = NO;
        self.savedForLaterExpanded = newSavedCount > 0;
        [UIView performWithoutAnimation:^{
            [self.cartTableView reloadData];
            [self.cartTableView layoutIfNeeded];
        }];
        finishReducedMotionUpdate();
        return;
    }

    if (insertedNewCartRow && sourceIndexPath) {
        self.savedForLaterRetainsEmptyDockDuringTransition = newSavedCount == 0;
        self.savedForLaterExpanded = YES;

        NSIndexPath *targetIndexPath = [NSIndexPath indexPathForRow:targetRow inSection:0];
        CGRect targetFrame = [self pp_controllerFrameForCartRow:targetRow];
        UITableViewCell *sourceCell = [self.cartTableView cellForRowAtIndexPath:sourceIndexPath];
        if (sourceSnapshot && sourceCell.window) {
            sourceSnapshot.frame = [sourceCell.superview convertRect:sourceCell.frame toView:self.view];
        } else if (sourceSnapshot) {
            [sourceSnapshot removeFromSuperview];
            sourceSnapshot = nil;
        }
        if (sourceSnapshot) sourceCell.alpha = 0.0;

        __block BOOL tableFinished = NO;
        __block BOOL visualFinished = sourceSnapshot == nil;
        __block BOOL didFinish = NO;
        void (^finishWhenReady)(void) = ^{
            if (didFinish || !tableFinished || !visualFinished) return;
            didFinish = YES;
            sourceCell.alpha = 1.0;
            [self pp_finishSavedForLaterArrivalAtRow:targetRow
                                         savedCount:newSavedCount
                                          completion:^{
                [self pp_finishSavedForLaterMoveFeedback];
            }];
        };

        [self pp_animateTransferSnapshot:sourceSnapshot
                           toTargetFrame:targetFrame
                              completion:^{
            visualFinished = YES;
            finishWhenReady();
        }];

        [self pp_performSavedTransferTableUpdates:^{
            [self.cartTableView moveRowAtIndexPath:sourceIndexPath toIndexPath:targetIndexPath];
        } completion:^(__unused BOOL finished) {
            tableFinished = YES;
            finishWhenReady();
        }];
        return;
    }

    if (mergedIntoCartRow && sourceIndexPath) {
        CGRect targetFrame = [self pp_controllerFrameForCartRow:targetRow];
        UITableViewCell *sourceCell = [self.cartTableView cellForRowAtIndexPath:sourceIndexPath];
        if (sourceSnapshot && sourceCell.window) {
            sourceSnapshot.frame = [sourceCell.superview convertRect:sourceCell.frame toView:self.view];
        } else if (sourceSnapshot) {
            [sourceSnapshot removeFromSuperview];
            sourceSnapshot = nil;
        }
        if (sourceSnapshot) sourceCell.alpha = 0.0;

        NSMutableArray<NSIndexPath *> *deletePaths = [NSMutableArray arrayWithObject:sourceIndexPath];
        if (newSavedCount == 0) {
            [deletePaths addObject:[NSIndexPath indexPathForRow:oldCartCount inSection:0]];
        }
        self.savedForLaterRetainsEmptyDockDuringTransition = NO;
        self.savedForLaterExpanded = newSavedCount > 0;

        __block BOOL tableFinished = NO;
        __block BOOL visualFinished = sourceSnapshot == nil;
        __block BOOL didFinish = NO;
        void (^finishWhenReady)(void) = ^{
            if (didFinish || !tableFinished || !visualFinished) return;
            didFinish = YES;
            sourceCell.alpha = 1.0;
            [self pp_finishSavedForLaterArrivalAtRow:targetRow
                                         savedCount:newSavedCount
                                          completion:^{
                [self pp_finishSavedForLaterMoveFeedback];
            }];
        };

        [self pp_animateTransferSnapshot:sourceSnapshot
                           toTargetFrame:targetFrame
                              completion:^{
            visualFinished = YES;
            finishWhenReady();
        }];

        [self pp_performSavedTransferTableUpdates:^{
            [self.cartTableView deleteRowsAtIndexPaths:deletePaths
                                      withRowAnimation:UITableViewRowAnimationTop];
        } completion:^(__unused BOOL finished) {
            tableFinished = YES;
            finishWhenReady();
        }];
        return;
    }

    self.savedForLaterRetainsEmptyDockDuringTransition = NO;
    self.savedForLaterExpanded = newSavedCount > 0;
    UIView *continuitySnapshot = [self.cartTableView snapshotViewAfterScreenUpdates:NO];
    if (continuitySnapshot) {
        continuitySnapshot.frame = [self.cartTableView.superview convertRect:self.cartTableView.frame toView:self.view];
        continuitySnapshot.userInteractionEnabled = NO;
        [self.view insertSubview:continuitySnapshot aboveSubview:self.cartTableView];
    }
    [UIView performWithoutAnimation:^{
        [self.cartTableView reloadData];
        [self.cartTableView layoutIfNeeded];
    }];

    void (^continueTransfer)(void) = ^{
        CGRect targetFrame = [self pp_controllerFrameForCartRow:targetRow];
        [self pp_animateTransferSnapshot:sourceSnapshot
                           toTargetFrame:targetFrame
                              completion:^{
            [self pp_finishSavedForLaterArrivalAtRow:targetRow
                                         savedCount:newSavedCount
                                          completion:^{
                [self pp_finishSavedForLaterMoveFeedback];
            }];
        }];
    };

    if (!continuitySnapshot) {
        continueTransfer();
        return;
    }
    [UIView animateWithDuration:0.22
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        continuitySnapshot.alpha = 0.0;
        continuitySnapshot.transform =
        CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, -6.0),
                                CGAffineTransformMakeScale(0.995, 0.995));
    } completion:^(__unused BOOL finished) {
        [continuitySnapshot removeFromSuperview];
        continueTransfer();
    }];
}

- (void)pp_presentPartialSavedMoveForItem:(CartItem *)item
                          sourceIndexPath:(NSIndexPath *)sourceIndexPath
                           sourceSnapshot:(UIView *)sourceSnapshot
                              oldCartCount:(NSInteger)oldCartCount
                                oldCartRow:(NSInteger)oldCartRow
{
    self.savedMoveFeedbackGenerator = nil;
    NSInteger newCartCount = [self pp_cartItemsCount];
    NSInteger targetRow = [self pp_cartRowForItemID:item.itemID];
    BOOL insertedNewCartRow = oldCartRow == NSNotFound &&
        targetRow != NSNotFound && newCartCount == oldCartCount + 1;
    BOOL mergedIntoCartRow = oldCartRow != NSNotFound &&
        targetRow != NSNotFound && newCartCount == oldCartCount;

    self.pendingSavedForLaterItemID = nil;
    self.pendingSavedForLaterOperation = nil;
    self.completedSavedForLaterItemID = nil;
    self.cartTableView.userInteractionEnabled = NO;

    if (targetRow == NSNotFound) {
        [sourceSnapshot removeFromSuperview];
        [self.cartTableView reloadData];
        self.isPerformingTableMutation = NO;
        self.cartTableView.userInteractionEnabled = YES;
        [self updateTotalLabel];
        [self pp_notifyCartBadgeAndCollections];
        [self pp_updateSavedForLaterFooter];
        [self pp_applyEmptyStateIfNeeded];
        [PPHUD showError:kLang(@"saved_for_later_move_partial_error")];

        UINotificationFeedbackGenerator *notification = [[UINotificationFeedbackGenerator alloc] init];
        [notification prepare];
        [notification notificationOccurred:UINotificationFeedbackTypeError];
        return;
    }

    UITableViewCell *sourceCell = sourceIndexPath
        ? [self.cartTableView cellForRowAtIndexPath:sourceIndexPath]
        : nil;
    if (sourceSnapshot && sourceCell.window) {
        sourceSnapshot.frame = [sourceCell.superview convertRect:sourceCell.frame toView:self.view];
    } else if (sourceSnapshot) {
        [sourceSnapshot removeFromSuperview];
        sourceSnapshot = nil;
    }

    void (^startTransfer)(void) = ^{
        [self.cartTableView layoutIfNeeded];
        CGRect targetFrame = [self pp_controllerFrameForCartRow:targetRow];
        [self pp_animateTransferSnapshot:sourceSnapshot
                           toTargetFrame:targetFrame
                              completion:^{
            PPCartTableCell *targetCell = (PPCartTableCell *)[self.cartTableView cellForRowAtIndexPath:
                [NSIndexPath indexPathForRow:targetRow inSection:0]];
            if ([targetCell isKindOfClass:PPCartTableCell.class]) {
                NSArray<CartItem *> *cartItems = [CartManager sharedManager].cartItems;
                if (targetRow >= 0 && targetRow < (NSInteger)cartItems.count) {
                    [self pp_configureActiveCartCell:targetCell item:cartItems[targetRow]];
                }
            }

            void (^finishPartialFeedback)(void) = ^{
                self.isPerformingTableMutation = NO;
                self.cartTableView.userInteractionEnabled = YES;
                [self updateTotalLabel];
                [self pp_notifyCartBadgeAndCollections];
                [self pp_updateSavedForLaterFooter];
                [self pp_applyEmptyStateIfNeeded];

                UINotificationFeedbackGenerator *notification = [[UINotificationFeedbackGenerator alloc] init];
                [notification prepare];
                [notification notificationOccurred:UINotificationFeedbackTypeError];
                [PPHUD showError:kLang(@"saved_for_later_move_partial_error")];
            };

            if ([targetCell isKindOfClass:PPCartTableCell.class]) {
                [targetCell playSavedForLaterArrivalAnimationWithCompletion:finishPartialFeedback];
            } else {
                finishPartialFeedback();
            }
        }];
    };

    if (insertedNewCartRow) {
        [self.cartTableView performBatchUpdates:^{
            [self.cartTableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:targetRow inSection:0]]
                                      withRowAnimation:UITableViewRowAnimationTop];
        } completion:^(__unused BOOL finished) {
            startTransfer();
        }];
        return;
    }

    if (mergedIntoCartRow) {
        PPCartTableCell *targetCell = (PPCartTableCell *)[self.cartTableView cellForRowAtIndexPath:
            [NSIndexPath indexPathForRow:targetRow inSection:0]];
        NSArray<CartItem *> *cartItems = [CartManager sharedManager].cartItems;
        if ([targetCell isKindOfClass:PPCartTableCell.class] &&
            targetRow >= 0 && targetRow < (NSInteger)cartItems.count) {
            [self pp_configureActiveCartCell:targetCell item:cartItems[targetRow]];
        }
        startTransfer();
        return;
    }

    UIView *continuitySnapshot = [self.cartTableView snapshotViewAfterScreenUpdates:NO];
    if (continuitySnapshot) {
        continuitySnapshot.frame = [self.cartTableView.superview convertRect:self.cartTableView.frame toView:self.view];
        continuitySnapshot.userInteractionEnabled = NO;
        [self.view insertSubview:continuitySnapshot aboveSubview:self.cartTableView];
    }
    [UIView performWithoutAnimation:^{
        [self.cartTableView reloadData];
        [self.cartTableView layoutIfNeeded];
    }];
    if (!continuitySnapshot) {
        startTransfer();
        return;
    }
    [UIView animateWithDuration:0.18
                     animations:^{
        continuitySnapshot.alpha = 0.0;
        continuitySnapshot.transform = CGAffineTransformMakeTranslation(0.0, -4.0);
    } completion:^(__unused BOOL finished) {
        [continuitySnapshot removeFromSuperview];
        startTransfer();
    }];
}

- (void)pp_finishSuccessfulSavedForLaterRemovalForItemID:(NSString *)itemID
                                            oldIndexPath:(NSIndexPath *)oldIndexPath
                                           oldSavedCount:(NSInteger)oldSavedCount
{
    NSInteger newSavedCount = [self pp_savedForLaterItems].count;
    NSMutableArray<NSIndexPath *> *deleteIndexPaths = [NSMutableArray array];
    NSIndexPath *dockIndexPath = [NSIndexPath indexPathForRow:[self pp_savedForLaterDockRowIndex] inSection:0];
    if (oldIndexPath) {
        [deleteIndexPaths addObject:oldIndexPath];
    }
    if (newSavedCount == 0 && oldSavedCount > 0) {
        [deleteIndexPaths insertObject:dockIndexPath atIndex:0];
    }

    self.pendingSavedForLaterItemID = nil;
    self.pendingSavedForLaterOperation = nil;
    self.completedSavedForLaterItemID = nil;

    if (deleteIndexPaths.count == 0 || !self.savedForLaterExpanded) {
        self.isPerformingTableMutation = NO;
        self.savedForLaterExpanded = newSavedCount > 0 ? self.savedForLaterExpanded : NO;
        [self.cartTableView reloadData];
        [self pp_updateSavedForLaterFooter];
        [self pp_applyEmptyStateIfNeeded];
        return;
    }

    [self.cartTableView performBatchUpdates:^{
        if (newSavedCount == 0) {
            self.savedForLaterExpanded = NO;
        }
        [self.cartTableView deleteRowsAtIndexPaths:deleteIndexPaths
                                  withRowAnimation:UITableViewRowAnimationTop];
    } completion:^(__unused BOOL finished) {
        self.isPerformingTableMutation = NO;
        [self pp_updateSavedForLaterFooter];
        [self pp_applyEmptyStateIfNeeded];
    }];
}

- (void)pp_removeSavedForLaterItem:(CartItem *)item showLoading:(BOOL)showLoading
{
    if (!item || item.itemID.length == 0) {
        [PPHUD showError:kLang(@"SomethingWentWrong")];
        return;
    }

    NSIndexPath *oldIndexPath = [self pp_indexPathForSavedForLaterItemID:item.itemID];
    NSInteger oldSavedCount = [self pp_savedForLaterItems].count;
    if (showLoading && ![self.pendingSavedForLaterItemID isEqualToString:item.itemID]) {
        [self pp_setSavedForLaterPendingItemID:item.itemID operation:@"remove"];
    }

    self.isPerformingTableMutation = YES;
    __weak typeof(self) weakSelf = self;
    [[PPSaveForLaterManager sharedManager] removeItem:item completion:^(NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) { return; }

        if (error) {
            strongSelf.isPerformingTableMutation = NO;
            [strongSelf pp_clearSavedForLaterPendingStateAndReload];
            [PPHUD showError:showLoading ? kLang(@"saved_for_later_delete_failed") : kLang(@"saved_for_later_move_partial_error")];
            return;
        }

        if (showLoading) {
            [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventCartItemRemoved];
        }
        if (showLoading) {
            [PPHUD showSuccess:kLang(@"saved_for_later_delete_success")];
        }
        [strongSelf pp_finishSuccessfulSavedForLaterRemovalForItemID:item.itemID
                                                        oldIndexPath:oldIndexPath
                                                       oldSavedCount:oldSavedCount];
    }];
}

- (void)pp_confirmRemoveSavedForLaterItem:(CartItem *)item
{
    if (!item || item.itemID.length == 0) {
        [PPHUD showError:kLang(@"SomethingWentWrong")];
        return;
    }

    [self pp_setSavedForLaterPendingItemID:item.itemID operation:@"remove"];
    __weak typeof(self) weakSelf = self;
    [PPAlertHelper showConfirmationIn:self
                                title:kLang(@"saved_for_later_delete_confirm_title")
                             subtitle:kLang(@"saved_for_later_delete_confirm_message")
                        confirmButton:kLang(@"saved_for_later_delete_confirm_action")
                         cancelButton:kLang(@"cancel")
                                 icon:[UIImage systemImageNamed:@"trash"]
                         confirmBlock:^(NSString * _Nullable text, BOOL didConfirm) {
        (void)text;
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) { return; }
        if (!didConfirm) {
            [strongSelf pp_clearSavedForLaterPendingStateAndReload];
            return;
        }
        [strongSelf pp_removeSavedForLaterItem:item showLoading:YES];
    } cancelBlock:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf pp_clearSavedForLaterPendingStateAndReload];
        }
    }];
}

- (void)pp_moveSavedForLaterItemToCart:(CartItem *)item
{
    if (!item || item.itemID.length == 0 || self.pendingSavedForLaterItemID.length > 0) {
        return;
    }

    [PPHUD dismiss];
    NSInteger oldCartCount = [self pp_cartItemsCount];
    NSInteger oldCartRow = [self pp_cartRowForItemID:item.itemID];
    NSIndexPath *sourceIndexPath = [self pp_indexPathForSavedForLaterItemID:item.itemID];
    UITableViewCell *sourceCell = sourceIndexPath ? [self.cartTableView cellForRowAtIndexPath:sourceIndexPath] : nil;
    UIView *transferSnapshot = [self pp_snapshotForSourceView:sourceCell];
    [self pp_setSavedForLaterPendingItemID:item.itemID operation:@"move"];
    self.isPerformingTableMutation = YES;
    self.cartTableView.userInteractionEnabled = NO;
    self.savedMoveFeedbackGenerator = [[UINotificationFeedbackGenerator alloc] init];
    [self.savedMoveFeedbackGenerator prepare];

    __weak typeof(self) weakSelf = self;
    [self pp_resolveCartItemForMoveToCart:item
                                completion:^(CartItem * _Nullable resolvedItem,
                                             BOOL isOutOfStock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) { return; }

            if (!resolvedItem) {
                strongSelf.isPerformingTableMutation = NO;
                strongSelf.cartTableView.userInteractionEnabled = YES;
                strongSelf.savedMoveFeedbackGenerator = nil;
                if (isOutOfStock) {
                    [strongSelf pp_registerStockNotificationForSavedItem:item];
                    return;
                }
                [strongSelf pp_clearSavedForLaterPendingStateAndReload];
                [PPHUD showError:kLang(@"SomethingWentWrong")];
                [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
                return;
            }

            NSUInteger previousSkipCount = strongSelf.pendingQuantitySyncReloadSkips;
            strongSelf.pendingQuantitySyncReloadSkips = MIN(previousSkipCount + 2, 8);
            [[CartManager sharedManager] addItem:resolvedItem
                         presentingViewController:strongSelf
                                      completion:^(BOOL success, BOOL didCancel) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    if (!strongSelf) { return; }

                    if (!success) {
                        strongSelf.pendingQuantitySyncReloadSkips = previousSkipCount;
                        strongSelf.isPerformingTableMutation = NO;
                        strongSelf.cartTableView.userInteractionEnabled = YES;
                        strongSelf.savedMoveFeedbackGenerator = nil;
                        [strongSelf pp_clearSavedForLaterPendingStateAndReload];
                        if (!didCancel) {
                            [PPHUD showError:kLang(@"SomethingWentWrong")];
                            [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
                        }
                        return;
                    }

                    strongSelf.pendingQuantitySyncReloadSkips = previousSkipCount;

                    [[PPSaveForLaterManager sharedManager] removeItem:item
                                                            completion:^(NSError * _Nullable error) {
                        __strong typeof(weakSelf) innerSelf = weakSelf;
                        if (!innerSelf) { return; }

                        if (error) {
                            [innerSelf pp_presentPartialSavedMoveForItem:item
                                                        sourceIndexPath:sourceIndexPath
                                                         sourceSnapshot:transferSnapshot
                                                            oldCartCount:oldCartCount
                                                              oldCartRow:oldCartRow];
                            return;
                        }

                        [innerSelf pp_presentSuccessfulSavedMoveForItem:item
                                                        sourceIndexPath:sourceIndexPath
                                                         sourceSnapshot:transferSnapshot
                                                            oldCartCount:oldCartCount
                                                              oldCartRow:oldCartRow];
                    }];
                });
            }];
        });
    }];
}

- (void)pp_registerStockNotificationForSavedItem:(CartItem *)item
{
    if (!item || item.itemID.length == 0) {
        [self pp_clearSavedForLaterPendingStateAndReload];
        [PPHUD showError:kLang(@"SomethingWentWrong")];
        return;
    }

    [self pp_setSavedForLaterPendingItemID:item.itemID operation:@"notify"];

    FIRHTTPSCallable *callable = [[FIRFunctions functionsForRegion:@"us-central1"]
                                  HTTPSCallableWithName:@"registerStockNotificationRequest"];
    callable.timeoutInterval = 30.0;

    NSDictionary *payload = @{
        @"itemId": item.itemID ?: @"",
        @"source": @"ios_saved_for_later_inline_cart",
        @"locale": [Language isRTL] ? @"ar" : @"en"
    };

    __weak typeof(self) weakSelf = self;
    [callable callWithObject:payload completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) { return; }

            [strongSelf pp_clearSavedForLaterPendingStateAndReload];
            if (error) {
                [PPHUD showError:kLang(@"stock_notify_failed")];
                [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
                UINotificationFeedbackGenerator *notification = [[UINotificationFeedbackGenerator alloc] init];
                [notification notificationOccurred:UINotificationFeedbackTypeError];
                return;
            }

            NSDictionary *response = [result.data isKindOfClass:NSDictionary.class] ? result.data : @{};
            NSString *status = [response[@"status"] isKindOfClass:NSString.class] ? response[@"status"] : @"";
            NSString *message = [status isEqualToString:@"already_available"]
                ? kLang(@"stock_notify_already_available")
                : kLang(@"stock_notify_success");
            [PPHUD showSuccess:message];
            UINotificationFeedbackGenerator *notification = [[UINotificationFeedbackGenerator alloc] init];
            [notification notificationOccurred:UINotificationFeedbackTypeSuccess];
        });
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    (void)section;
    NSInteger rows = [self pp_cartItemsCount];
    if ([self pp_shouldShowSavedForLaterInlineRows]) {
        rows += 1 + [self pp_savedForLaterItems].count;
    }
    return rows;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    if ([self pp_isSavedForLaterDockIndexPath:indexPath]) {
        PPSavedForLaterDockTableCell *dockCell =
        [tableView dequeueReusableCellWithIdentifier:kPPCartSavedDockCellIdentifier
                                        forIndexPath:indexPath];
        [dockCell configureWithSavedCount:[self pp_savedForLaterItems].count
                                  expanded:self.savedForLaterExpanded];
        BOOL hasActiveCartBoundary = [self pp_cartItemsCount] > 0;
        dockCell.boundaryLineView.hidden = !hasActiveCartBoundary;
        dockCell.boundaryAccentView.hidden = !hasActiveCartBoundary;
        dockCell.boundaryTopConstraint.constant = hasActiveCartBoundary ? 18.0 : 8.0;
        dockCell.dockTopConstraint.constant = hasActiveCartBoundary ? 34.0 : 9.0;
        dockCell.dockBottomConstraint.constant = hasActiveCartBoundary ? -2.0 : -9.0;
        dockCell.layer.masksToBounds = NO;
        dockCell.clipsToBounds = NO;
        return dockCell;
    }

    PPCartTableCell *cell = [tableView dequeueReusableCellWithIdentifier:kPPCartTableCellIdentifier];
    if (!cell) {
        cell = [[PPCartTableCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:kPPCartTableCellIdentifier];
    }

    CartItem *savedItem = [self pp_savedForLaterItemAtIndexPath:indexPath];
    if (savedItem) {
        [self pp_configureSavedCartCell:cell item:savedItem];
        cell.layer.masksToBounds = NO;
        cell.clipsToBounds = NO;
        return cell;
    }

    NSArray<CartItem *> *items = [CartManager sharedManager].cartItems;
    if (indexPath.row >= (NSInteger)items.count) {
        return cell;
    }
    CartItem *item = items[indexPath.row];
    [self pp_configureActiveCartCell:cell item:item];

    cell.layer.masksToBounds = NO;
    cell.clipsToBounds = NO;
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    (void)tableView;
    if ([self pp_isSavedForLaterDockIndexPath:indexPath]) {
        BOOL isAccessibilitySize =
        UIContentSizeCategoryIsAccessibilityCategory(UIApplication.sharedApplication.preferredContentSizeCategory);
        BOOL hasActiveCartBoundary = [self pp_cartItemsCount] > 0;
        if (!hasActiveCartBoundary) {
            return isAccessibilitySize ? 110.0 : 88.0;
        }
        return isAccessibilitySize ? 130.0 : 108.0;
    }
    if ([self pp_savedForLaterItemAtIndexPath:indexPath]) {
        BOOL isAccessibilitySize =
        UIContentSizeCategoryIsAccessibilityCategory(UIApplication.sharedApplication.preferredContentSizeCategory);
        return isAccessibilitySize ? 174.0 : 154.0;
    }
    return 134.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if ([self pp_isSavedForLaterDockIndexPath:indexPath]) {
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        [self pp_setSavedForLaterExpanded:NO
                                  animated:YES
                                sourceView:cell];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    (void)scrollView;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    (void)tableView;
    return [self pp_isCartItemIndexPath:indexPath];
}

// Enable swipe-to-delete (SAFE)
- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)style
forRowAtIndexPath:(NSIndexPath *)indexPath {

    if (style != UITableViewCellEditingStyleDelete) return;
    if (![self pp_isCartItemIndexPath:indexPath]) return;
    [self pp_removeItemAtIndexPath:indexPath];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (![self pp_isCartItemIndexPath:indexPath]) return nil;

    UIContextualAction *removeAction =
    [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                            title:kLang(@"cart_swipe_remove")
                                          handler:^(__unused UIContextualAction * _Nonnull action,
                                                    __unused UIView * _Nonnull sourceView,
                                                    void (^ _Nonnull completionHandler)(BOOL)) {
        [self pp_removeItemAtIndexPath:indexPath];
        completionHandler(YES);
    }];

    if (@available(iOS 13.0, *)) {
        removeAction.image = [UIImage systemImageNamed:@"trash.fill"];
    }
    removeAction.backgroundColor = [UIColor systemRedColor];

    UISwipeActionsConfiguration *config =
    [UISwipeActionsConfiguration configurationWithActions:@[removeAction]];
    config.performsFirstActionWithFullSwipe = YES;
    return config;
}

- (NSString *)tableView:(UITableView *)tableView
titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    (void)tableView;
    if (![self pp_isCartItemIndexPath:indexPath]) {
        return nil;
    }
    return kLang(@"cart_swipe_remove");
}
/*
 // Remove from CartManager (single source of truth)
 [[CartManager sharedManager] removeItem:item];
 [[CartManager sharedManager] saveCart];
 */
- (void)syncCartToFirestore:(NSArray<CartItem *> *)items {
    // U8: Use authenticated UID from FIRAuth as primary source, with UserManager fallback
    NSString *userID = PPCurrentFIRAuthUser.uid;
    if (userID.length == 0) {
        userID = UserManager.sharedManager.currentUser.ID;
    }

    if (!userID || userID.length == 0) {
        NSLog(@"⚠️ [Cart] Cannot sync — no authenticated user");
        return;
    }

    // U6: Validate cart items before Firestore write
    if (items.count == 0) {
        NSLog(@"⚠️ [Cart] syncCartToFirestore called with empty items array");
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    NSString *orderID = [NSString stringWithFormat:@"order_%@", [[NSUUID UUID] UUIDString]];

    FIRDocumentReference *orderRef = [[[[db collectionWithPath:@"UsersCol"]
                                        documentWithPath:userID]
                                       collectionWithPath:@"orders"]
                                      documentWithPath:orderID];

    NSMutableDictionary *orderSummary = [NSMutableDictionary dictionary];
    NSMutableArray *itemData = [NSMutableArray array];
    NSInteger totalQty = 0;
    double totalPrice = 0;

    for (CartItem *item in items) {
        // U6: Validate each item before including in order
        if (item.itemID.length == 0 || item.name.length == 0) {
            NSLog(@"⚠️ [Cart] Skipping invalid item (missing ID or name)");
            continue;
        }
        NSInteger safeQty = MAX(1, MIN(item.quantity, 9999));
        double safePrice = MAX(0.0, MIN(item.price, 999999.0));
        totalQty += safeQty;
        totalPrice += safePrice * safeQty;
        [itemData addObject:@{
             @"itemID": item.itemID,
             @"name": item.name,
             @"quantity": @(safeQty),
             @"price": @(safePrice)
        }];
    }

    if (itemData.count == 0) {
        NSLog(@"⚠️ [Cart] No valid items to sync after validation");
        return;
    }

    orderSummary[@"totalQuantity"] = @(totalQty);
    orderSummary[@"totalPrice"] = @(totalPrice);
    orderSummary[@"createdAt"] = [FIRTimestamp timestamp];
    orderSummary[@"items"] = itemData;
    orderSummary[@"status"] = @(0);

    FIRWriteBatch *batch = [db batch];
    [batch setData:orderSummary forDocument:orderRef];

    [batch commitWithCompletion:^(NSError *_Nullable error) {
        if (error) {
            NSLog(@"❌ Batch upload failed: %@", error.localizedDescription);
        } else {
            NSLog(@"✅ Order %@ uploaded successfully", orderID);
            [[CartManager sharedManager] clearCart];
            [self.cartTableView reloadData];
            [self updateTotalLabel];
            
            [self.delegate loadItemsCountInBadge];

            if ([self.delegate respondsToSelector:@selector(updateCartAndReloadCollection)]) {
                [self.delegate updateCartAndReloadCollection];
            }
            
        }
    }];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;

    cell.layer.mask = nil;
    cell.contentView.layer.mask = nil;

    if (self.savedForLaterRevealInProgress &&
        !UIAccessibilityIsReduceMotionEnabled() &&
        [self pp_savedForLaterItemAtIndexPath:indexPath]) {
        NSInteger savedOffset = MAX(0, indexPath.row - [self pp_savedForLaterDockRowIndex] - 1);
        CGFloat offset = MIN(34.0, 18.0 + (savedOffset * 4.0));
        cell.alpha = 0.0;
        cell.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, -offset),
                                                 CGAffineTransformMakeScale(0.974, 0.974));
        return;
    }

    cell.alpha = 1.0;
    cell.transform = CGAffineTransformIdentity;
}

- (void)pp_updateSavedForLaterFooter
{
    NSArray *saved = [self pp_savedForLaterItems];
    if (saved.count == 0) {
        self.savedForLaterFooterPillButton = nil;
        if (self.isPerformingTableMutation) {
            self.cartTableView.tableFooterView = nil;
            return;
        }
        BOOL wasExpanded = self.savedForLaterExpanded;
        self.savedForLaterExpanded = NO;
        self.savedForLaterRetainsEmptyDockDuringTransition = NO;
        self.savedForLaterRevealInProgress = NO;
        self.pendingSavedForLaterItemID = nil;
        self.pendingSavedForLaterOperation = nil;
        self.completedSavedForLaterItemID = nil;
        self.cartTableView.tableFooterView = nil;
        if (wasExpanded && !self.isPerformingTableMutation) {
            [self.cartTableView reloadData];
        }
        return;
    }

    if (self.savedForLaterExpanded) {
        self.savedForLaterFooterPillButton = nil;
        self.cartTableView.tableFooterView = nil;
        if (!self.isPerformingTableMutation) {
            NSInteger expectedRows = [self pp_cartItemsCount] + 1 + saved.count;
            NSInteger displayedRows = [self.cartTableView numberOfSections] > 0
                ? [self.cartTableView numberOfRowsInSection:0]
                : 0;
            if (displayedRows != expectedRows) {
                [UIView performWithoutAnimation:^{
                    [self.cartTableView reloadData];
                    [self.cartTableView layoutIfNeeded];
                }];
            } else {
                NSIndexPath *dockIndexPath =
                [NSIndexPath indexPathForRow:[self pp_savedForLaterDockRowIndex] inSection:0];
                PPSavedForLaterDockTableCell *dockCell =
                (PPSavedForLaterDockTableCell *)[self.cartTableView cellForRowAtIndexPath:dockIndexPath];
                if ([dockCell isKindOfClass:PPSavedForLaterDockTableCell.class]) {
                    [dockCell configureWithSavedCount:saved.count expanded:YES];
                }
            }
        }
        return;
    }

    BOOL hadFooter = self.cartTableView.tableFooterView != nil;
    BOOL isAccessibilitySize = UIContentSizeCategoryIsAccessibilityCategory(UIApplication.sharedApplication.preferredContentSizeCategory);
    CGFloat tableWidth = CGRectGetWidth(self.cartTableView.bounds);
    if (tableWidth < 1.0) {
        tableWidth = CGRectGetWidth(self.view.bounds);
    }
    if (tableWidth < 1.0) {
        tableWidth = CGRectGetWidth(UIScreen.mainScreen.bounds);
    }
    CGFloat footerHeight = isAccessibilitySize ? 102.0 : 78.0;
    CGFloat pillHeight = isAccessibilitySize ? 70.0 : 58.0;
    CGFloat availableCompactWidth = MAX(0.0, tableWidth - (isAccessibilitySize ? 56.0 : 104.0));
    CGFloat pillWidth = MIN(MAX(isAccessibilitySize ? 318.0 : 282.0, availableCompactWidth),
                            isAccessibilitySize ? 356.0 : 326.0);
    CGFloat iconSize = isAccessibilitySize ? 42.0 : 38.0;
    CGFloat countBadgeHeight = isAccessibilitySize ? 34.0 : 32.0;
    CGFloat chevronSize = isAccessibilitySize ? 32.0 : 30.0;
    CGFloat cornerRadius = pillHeight * 0.43;
    UIColor *accentColor = PPSavedForLaterDeferredAccentColor();
    UIColor *primaryTextColor = AppPrimaryTextClr ?: UIColor.labelColor;
    NSString *countText = [NSString stringWithFormat:kLang(@"saved_for_later_count_format"), (long)saved.count];

    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableWidth, footerHeight)];
    footerView.backgroundColor = UIColor.clearColor;
    footerView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    UIButton *pillButton = [UIButton buttonWithType:UIButtonTypeCustom];
    pillButton.translatesAutoresizingMaskIntoConstraints = NO;
    pillButton.backgroundColor = UIColor.clearColor;
    pillButton.layer.cornerRadius = cornerRadius;
    pillButton.layer.masksToBounds = NO;
    pillButton.exclusiveTouch = YES;
    pillButton.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    pillButton.accessibilityLabel = kLang(@"saved_for_later");
    pillButton.accessibilityValue = countText;
    pillButton.accessibilityHint = kLang(@"saved_for_later_open_hint");
    pillButton.accessibilityTraits = UIAccessibilityTraitButton;
    [pillButton pp_setShadowColor:UIColor.blackColor];
    pillButton.layer.shadowOpacity = 0.0;
    pillButton.layer.shadowRadius = 0.0;
    pillButton.layer.shadowOffset = CGSizeZero;
    if (@available(iOS 13.0, *)) {
        pillButton.layer.cornerCurve = kCACornerCurveContinuous;
    }
    if (@available(iOS 13.4, *)) {
        pillButton.pointerInteractionEnabled = YES;
    }

    UIBlurEffectStyle blurStyle = UIBlurEffectStyleSystemThinMaterial;
    UIVisualEffectView *materialView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:blurStyle]];
    materialView.translatesAutoresizingMaskIntoConstraints = NO;
    materialView.userInteractionEnabled = NO;
    materialView.clipsToBounds = YES;
    materialView.layer.cornerRadius = cornerRadius;
    materialView.layer.borderWidth = 0.8;
    UIColor *borderColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return [UIColor.whiteColor colorWithAlphaComponent:(tc.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.10 : 0.62];
    }];
    [materialView pp_setBorderColor:[borderColor resolvedColorWithTraitCollection:self.traitCollection]];
    if (@available(iOS 13.0, *)) {
        materialView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [pillButton addSubview:materialView];

    UIView *tintView = [[UIView alloc] init];
    tintView.translatesAutoresizingMaskIntoConstraints = NO;
    tintView.userInteractionEnabled = NO;
    tintView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.12 green:0.12 blue:0.14 alpha:0.48];
        }
        return [[UIColor whiteColor] colorWithAlphaComponent:0.46];
    }];
    [materialView.contentView addSubview:tintView];

    UIView *accentLine = [[UIView alloc] init];
    accentLine.translatesAutoresizingMaskIntoConstraints = NO;
    accentLine.userInteractionEnabled = NO;
    accentLine.backgroundColor = [accentColor colorWithAlphaComponent:0.92];
    accentLine.layer.cornerRadius = 1.5;
    [materialView.contentView addSubview:accentLine];

    UIView *iconContainer = [[UIView alloc] init];
    iconContainer.translatesAutoresizingMaskIntoConstraints = NO;
    iconContainer.userInteractionEnabled = NO;
    iconContainer.backgroundColor = [accentColor colorWithAlphaComponent:(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.20 : 0.12];
    iconContainer.layer.cornerRadius = iconSize * 0.5;
    iconContainer.layer.borderWidth = 0.75;
    [iconContainer pp_setBorderColor:[accentColor colorWithAlphaComponent:0.18]];
    [materialView.contentView addSubview:iconContainer];

    UIImage *bookmarkIcon = [UIImage pp_symbolNamed:@"bookmark.fill"
                                          pointSize:17
                                             weight:UIImageSymbolWeightSemibold
                                              scale:UIImageSymbolScaleMedium
                                            palette:@[accentColor, accentColor]
                                       makeTemplate:YES];
    UIImageView *iconView = [[UIImageView alloc] initWithImage:bookmarkIcon];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = accentColor;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [iconContainer addSubview:iconView];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.textColor = primaryTextColor;
    titleLabel.font = PPCartScaledFont(@"Beiruti-Bold", isAccessibilitySize ? 16.4 : 15.8, UIFontWeightBold, UIFontTextStyleSubheadline);
    titleLabel.adjustsFontForContentSizeCategory = YES;
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.minimumScaleFactor = 0.82;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.numberOfLines = 1;
    titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    titleLabel.text = kLang(@"saved_for_later");
    [titleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh
                                                forAxis:UILayoutConstraintAxisHorizontal];
    [materialView.contentView addSubview:titleLabel];

    PPInsetLabel *countBadge = [[PPInsetLabel alloc] init];
    countBadge.translatesAutoresizingMaskIntoConstraints = NO;
    countBadge.text = countText;
    countBadge.textInsets = UIEdgeInsetsMake(5.0, 12.0, 5.0, 12.0);
    countBadge.font = PPCartScaledFont(@"Beiruti-Bold", 12.2, UIFontWeightSemibold, UIFontTextStyleCaption1);
    countBadge.adjustsFontForContentSizeCategory = YES;
    countBadge.textColor = accentColor;
    countBadge.textAlignment = NSTextAlignmentCenter;
    countBadge.numberOfLines = 1;
    countBadge.adjustsFontSizeToFitWidth = YES;
    countBadge.minimumScaleFactor = 0.76;
    countBadge.backgroundColor = [accentColor colorWithAlphaComponent:(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.18 : 0.10];
    countBadge.layer.cornerRadius = countBadgeHeight * 0.5;
    countBadge.layer.masksToBounds = YES;
    countBadge.layer.borderWidth = 0.75;
    [countBadge pp_setBorderColor:[accentColor colorWithAlphaComponent:0.18]];
    [countBadge setContentHuggingPriority:UILayoutPriorityRequired
                                  forAxis:UILayoutConstraintAxisHorizontal];
    [countBadge setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                forAxis:UILayoutConstraintAxisHorizontal];
    [materialView.contentView addSubview:countBadge];

    UIView *chevronContainer = [[UIView alloc] init];
    chevronContainer.translatesAutoresizingMaskIntoConstraints = NO;
    chevronContainer.userInteractionEnabled = NO;
    chevronContainer.backgroundColor = [UIColor.labelColor colorWithAlphaComponent:(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.12 : 0.055];
    chevronContainer.layer.cornerRadius = chevronSize * 0.5;
    [materialView.contentView addSubview:chevronContainer];

    NSString *chevronName = Language.isRTL ? @"chevron.left" : @"chevron.right";
    UIImageView *chevronView = [[UIImageView alloc] initWithImage:[UIImage pp_symbolNamed:chevronName
                                                                                pointSize:12
                                                                                   weight:UIImageSymbolWeightBold
                                                                                    scale:UIImageSymbolScaleSmall
                                                                                  palette:@[primaryTextColor, primaryTextColor]
                                                                             makeTemplate:YES]];
    chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    chevronView.tintColor = [primaryTextColor colorWithAlphaComponent:0.78];
    chevronView.contentMode = UIViewContentModeScaleAspectFit;
    [chevronContainer addSubview:chevronView];

    [pillButton addTarget:self action:@selector(pp_didTapSavedForLaterPill:) forControlEvents:UIControlEventTouchUpInside];
    [pillButton addTarget:self action:@selector(pp_savedForLaterPillTouchDown:) forControlEvents:UIControlEventTouchDown];
    [pillButton addTarget:self
                   action:@selector(pp_savedForLaterPillTouchCancel:)
         forControlEvents:(UIControlEventTouchCancel | UIControlEventTouchUpOutside | UIControlEventTouchDragExit | UIControlEventTouchUpInside)];

    [footerView addSubview:pillButton];

    CGFloat horizontalInset = 18.0;
    CGFloat internalInset = isAccessibilitySize ? 14.0 : 12.0;

    [NSLayoutConstraint activateConstraints:@[
        [materialView.leadingAnchor constraintEqualToAnchor:pillButton.leadingAnchor],
        [materialView.trailingAnchor constraintEqualToAnchor:pillButton.trailingAnchor],
        [materialView.topAnchor constraintEqualToAnchor:pillButton.topAnchor],
        [materialView.bottomAnchor constraintEqualToAnchor:pillButton.bottomAnchor],

        [tintView.leadingAnchor constraintEqualToAnchor:materialView.contentView.leadingAnchor],
        [tintView.trailingAnchor constraintEqualToAnchor:materialView.contentView.trailingAnchor],
        [tintView.topAnchor constraintEqualToAnchor:materialView.contentView.topAnchor],
        [tintView.bottomAnchor constraintEqualToAnchor:materialView.contentView.bottomAnchor],

        [pillButton.centerXAnchor constraintEqualToAnchor:footerView.centerXAnchor],
        [pillButton.centerYAnchor constraintEqualToAnchor:footerView.centerYAnchor],
        [pillButton.leadingAnchor constraintGreaterThanOrEqualToAnchor:footerView.leadingAnchor constant:horizontalInset],
        [pillButton.trailingAnchor constraintLessThanOrEqualToAnchor:footerView.trailingAnchor constant:-horizontalInset],
        [pillButton.heightAnchor constraintEqualToConstant:pillHeight],
        [pillButton.widthAnchor constraintEqualToConstant:pillWidth],

        [accentLine.leadingAnchor constraintEqualToAnchor:materialView.contentView.leadingAnchor constant:internalInset],
        [accentLine.centerYAnchor constraintEqualToAnchor:materialView.contentView.centerYAnchor],
        [accentLine.widthAnchor constraintEqualToConstant:3.0],
        [accentLine.heightAnchor constraintEqualToConstant:isAccessibilitySize ? 38.0 : 30.0],

        [iconContainer.leadingAnchor constraintEqualToAnchor:accentLine.trailingAnchor constant:9.0],
        [iconContainer.centerYAnchor constraintEqualToAnchor:materialView.contentView.centerYAnchor],
        [iconContainer.widthAnchor constraintEqualToConstant:iconSize],
        [iconContainer.heightAnchor constraintEqualToConstant:iconSize],

        [iconView.centerXAnchor constraintEqualToAnchor:iconContainer.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconContainer.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:18.0],
        [iconView.heightAnchor constraintEqualToConstant:18.0],

        [titleLabel.leadingAnchor constraintEqualToAnchor:iconContainer.trailingAnchor constant:10.0],
        [titleLabel.centerYAnchor constraintEqualToAnchor:materialView.contentView.centerYAnchor],
        [titleLabel.topAnchor constraintGreaterThanOrEqualToAnchor:materialView.contentView.topAnchor constant:8.0],
        [titleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:materialView.contentView.bottomAnchor constant:-8.0],

        [countBadge.leadingAnchor constraintGreaterThanOrEqualToAnchor:titleLabel.trailingAnchor constant:8.0],
        [countBadge.centerYAnchor constraintEqualToAnchor:materialView.contentView.centerYAnchor],
        [countBadge.heightAnchor constraintGreaterThanOrEqualToConstant:countBadgeHeight],
        [countBadge.widthAnchor constraintGreaterThanOrEqualToConstant:isAccessibilitySize ? 76.0 : 68.0],
        [countBadge.widthAnchor constraintLessThanOrEqualToConstant:isAccessibilitySize ? 110.0 : 92.0],

        [chevronContainer.leadingAnchor constraintEqualToAnchor:countBadge.trailingAnchor constant:6.0],
        [chevronContainer.trailingAnchor constraintEqualToAnchor:materialView.contentView.trailingAnchor constant:-internalInset],
        [chevronContainer.centerYAnchor constraintEqualToAnchor:materialView.contentView.centerYAnchor],
        [chevronContainer.widthAnchor constraintEqualToConstant:chevronSize],
        [chevronContainer.heightAnchor constraintEqualToConstant:chevronSize],

        [chevronView.centerXAnchor constraintEqualToAnchor:chevronContainer.centerXAnchor],
        [chevronView.centerYAnchor constraintEqualToAnchor:chevronContainer.centerYAnchor],
        [chevronView.widthAnchor constraintEqualToConstant:12.0],
        [chevronView.heightAnchor constraintEqualToConstant:12.0]
    ]];

    self.cartTableView.tableFooterView = footerView;
    self.savedForLaterFooterPillButton = pillButton;

    if (!hadFooter && !UIAccessibilityIsReduceMotionEnabled()) {
        footerView.alpha = 0.0;
        footerView.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
        [UIView animateWithDuration:0.42
                              delay:0.04
             usingSpringWithDamping:0.86
              initialSpringVelocity:0.24
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            footerView.alpha = 1.0;
            footerView.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

- (void)pp_didTapSavedForLaterPill:(UIButton *)sender
{
    [self.summaryView setSummaryCollapsed:YES animated:YES];
    [self pp_setSavedForLaterExpanded:YES
                              animated:YES
                            sourceView:sender ?: self.cartTableView.tableFooterView];
}

- (void)pp_savedForLaterPillTouchDown:(UIButton *)button
{
    if (!button) return;

    [UIView animateWithDuration:0.10
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        button.transform = CGAffineTransformMakeScale(0.982, 0.982);
        button.alpha = 0.96;
    } completion:nil];
}

- (void)pp_savedForLaterPillTouchCancel:(UIButton *)button
{
    if (!button) return;

    [UIView animateWithDuration:0.28
                          delay:0.0
         usingSpringWithDamping:0.82
          initialSpringVelocity:0.32
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        button.transform = CGAffineTransformIdentity;
        button.alpha = 1.0;
    } completion:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end























//
//  PPPaymentSheettHelper.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 02/11/2025.
//

@implementation PPPaymentSheettHelper

#pragma mark - Public API

+ (void)showPaymentSheetIn:(UIViewController *)vc
             selectedMethod:(NSString *)methodName
                  onConfirm:(dispatch_block_t)confirm
                   onCancel:(dispatch_block_t)cancel {

    if (@available(iOS 15.0, *)) {
        // 🧊 Modern iOS Action Sheet
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"payment_confirm_title")
                                                                       message:[NSString stringWithFormat:kLang(@"payment_pay_using_format"), methodName ?: @""]
                                                                preferredStyle:UIAlertControllerStyleActionSheet];

        UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:kLang(@"payment_confirm_action")
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * _Nonnull action) {
            [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
            if (confirm) confirm();
        }];

        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:kLang(@"payment_cancel_action")
                                                               style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction * _Nonnull action) {
            [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
            if (cancel) cancel();
        }];

        [alert addAction:confirmAction];
        [alert addAction:cancelAction];

        // 🧭 Customize sheet appearance (iOS 15+)
        if (@available(iOS 15.0, *)) {
            alert.sheetPresentationController.detents = @[
                [UISheetPresentationControllerDetent mediumDetent],
                [UISheetPresentationControllerDetent largeDetent]
            ];
            alert.sheetPresentationController.prefersGrabberVisible = YES;
            alert.sheetPresentationController.preferredCornerRadius = 22;
        }

        // iPad: actionSheet requires sourceView to avoid crash
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            alert.popoverPresentationController.sourceView = vc.view;
            alert.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(vc.view.bounds), CGRectGetMidY(vc.view.bounds), 0, 0);
        }
        [vc presentViewController:alert animated:YES completion:nil];
    }
    else {
        // 🌫️ Fallback custom blur alert
        [self showLegacyBlurSheetIn:vc methodName:methodName onConfirm:confirm onCancel:cancel];
    }
}

#pragma mark - Legacy Blur Implementation

+ (void)showLegacyBlurSheetIn:(UIViewController *)vc
                   methodName:(NSString *)methodName
                    onConfirm:(dispatch_block_t)confirm
                     onCancel:(dispatch_block_t)cancel {

    UIView *container = [[UIView alloc] initWithFrame:vc.view.bounds];
    container.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4];
    container.alpha = 0;
    [vc.view addSubview:container];

    // Blur background card
    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:effect];
    blurView.layer.cornerRadius = 18;
    blurView.layer.masksToBounds = YES;
    blurView.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *title = [[UILabel alloc] init];
    title.text = kLang(@"payment_confirm_title");
    title.font = [GM boldFontWithSize:20];
    title.textAlignment = NSTextAlignmentCenter;
    title.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *message = [[UILabel alloc] init];
    message.text = [NSString stringWithFormat:kLang(@"payment_pay_using_format"), methodName ?: @""];
    message.textAlignment = NSTextAlignmentCenter;
    message.textColor = UIColor.secondaryLabelColor;
    message.numberOfLines = 0;
    message.translatesAutoresizingMaskIntoConstraints = NO;

    UIButton *confirmBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [confirmBtn setTitle:kLang(@"payment_confirm_action") forState:UIControlStateNormal];
    confirmBtn.titleLabel.font = [GM boldFontWithSize:17];
    confirmBtn.translatesAutoresizingMaskIntoConstraints = NO;
    confirmBtn.backgroundColor = AppPrimaryClr;
    confirmBtn.tintColor = UIColor.whiteColor;
    confirmBtn.layer.cornerRadius = 10;
    [confirmBtn addTarget:self action:@selector(_confirmTap:) forControlEvents:UIControlEventTouchUpInside];
    confirmBtn.tag = 1; // tag to identify action

    UIButton *cancelBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [cancelBtn setTitle:kLang(@"payment_cancel_action") forState:UIControlStateNormal];
    cancelBtn.titleLabel.font = [GM MidFontWithSize:16];
    cancelBtn.translatesAutoresizingMaskIntoConstraints = NO;
    cancelBtn.backgroundColor = [UIColor.systemGray5Color colorWithAlphaComponent:0.6];
    cancelBtn.tintColor = UIColor.labelColor;
    cancelBtn.layer.cornerRadius = 10;
    [cancelBtn addTarget:self action:@selector(_confirmTap:) forControlEvents:UIControlEventTouchUpInside];
    cancelBtn.tag = 2;

    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [vc.view addSubview:container];
    [container addSubview:blurView];
    [blurView.contentView addSubview:title];
    [blurView.contentView addSubview:message];
    [blurView.contentView addSubview:confirmBtn];
    [blurView.contentView addSubview:cancelBtn];

    [NSLayoutConstraint activateConstraints:@[
        [blurView.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [blurView.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [blurView.widthAnchor constraintEqualToAnchor:container.widthAnchor multiplier:0.85],
        [title.topAnchor constraintEqualToAnchor:blurView.topAnchor constant:24],
        [title.leadingAnchor constraintEqualToAnchor:blurView.leadingAnchor constant:16],
        [title.trailingAnchor constraintEqualToAnchor:blurView.trailingAnchor constant:-16],
        [message.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:12],
        [message.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [message.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],
        [confirmBtn.topAnchor constraintEqualToAnchor:message.bottomAnchor constant:20],
        [confirmBtn.leadingAnchor constraintEqualToAnchor:blurView.leadingAnchor constant:20],
        [confirmBtn.trailingAnchor constraintEqualToAnchor:blurView.trailingAnchor constant:-20],
        [confirmBtn.heightAnchor constraintEqualToConstant:44],
        [cancelBtn.topAnchor constraintEqualToAnchor:confirmBtn.bottomAnchor constant:12],
        [cancelBtn.leadingAnchor constraintEqualToAnchor:confirmBtn.leadingAnchor],
        [cancelBtn.trailingAnchor constraintEqualToAnchor:confirmBtn.trailingAnchor],
        [cancelBtn.heightAnchor constraintEqualToConstant:42],
        [cancelBtn.bottomAnchor constraintEqualToAnchor:blurView.bottomAnchor constant:-24]
    ]];

    // Fade-in animation
    [UIView animateWithDuration:0.25 animations:^{
        container.alpha = 1.0;
    }];

    // Store actions in associated objects
    objc_setAssociatedObject(confirmBtn, @"confirmBlock", confirm, OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(cancelBtn, @"cancelBlock", cancel, OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(container, @"containerView", container, OBJC_ASSOCIATION_ASSIGN);
}

#pragma mark - Button Actions

+ (void)_confirmTap:(UIButton *)sender {
    dispatch_block_t confirmBlock = objc_getAssociatedObject(sender, @"confirmBlock");
    dispatch_block_t cancelBlock = objc_getAssociatedObject(sender, @"cancelBlock");
    UIView *container = objc_getAssociatedObject(sender, @"containerView");

    [UIView animateWithDuration:0.25 animations:^{
        container.alpha = 0.0;
    } completion:^(BOOL finished) {
        [container removeFromSuperview];
        if (sender.tag == 1 && confirmBlock) confirmBlock();
        else if (sender.tag == 2 && cancelBlock) cancelBlock();
    }];
}

@end



























//
//  PPBottomAlertSheet.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 02/11/2025.
//

 #import "Styling.h"
#import "Language.h"

@interface PPBottomAlertSheet ()
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UIButton *confirmButton;
@property (nonatomic, strong) UIButton *cancelButton;
@end

@implementation PPBottomAlertSheet

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
}

#pragma mark - UI Setup

- (void)setupUI {
   
    
    self.view.backgroundColor = PPBackgroundColorForIOS26([UIColor systemBackgroundColor]);
    self.view.layer.cornerRadius = 24;
    self.view.layer.masksToBounds = YES;

    // 📄 Title
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.text = self.sheetTitle ?: kLang(@"payment_confirm_title");
    _titleLabel.font = [UIFont boldSystemFontOfSize:20];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    // 📜 Message
    _messageLabel = [[UILabel alloc] init];
    _messageLabel.text = self.message ?: @"";
    _messageLabel.font = [UIFont systemFontOfSize:16];
    _messageLabel.textAlignment = NSTextAlignmentCenter;
    _messageLabel.textColor = UIColor.secondaryLabelColor;
    _messageLabel.numberOfLines = 0;
    _messageLabel.translatesAutoresizingMaskIntoConstraints = NO;

    // ✅ Confirm button
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration tintedButtonConfiguration];
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.baseBackgroundColor = AppPrimaryClr;
        cfg.baseForegroundColor = UIColor.whiteColor;
        cfg.attributedTitle = [[NSAttributedString alloc] initWithString:kLang(@"payment_confirm_action")
                                                              attributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:17]}];
        _confirmButton = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    } else {
        _confirmButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_confirmButton setTitle:kLang(@"payment_confirm_action") forState:UIControlStateNormal];
        _confirmButton.backgroundColor = AppPrimaryClr;
        _confirmButton.tintColor = UIColor.whiteColor;
        _confirmButton.layer.cornerRadius = 12;
    }
    _confirmButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_confirmButton addTarget:self action:@selector(confirmTapped) forControlEvents:UIControlEventTouchUpInside];

    // ❌ Cancel button
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration grayButtonConfiguration];
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.baseForegroundColor = UIColor.labelColor;
        cfg.attributedTitle = [[NSAttributedString alloc] initWithString:kLang(@"payment_cancel_action")
                                                              attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:17]}];
        _cancelButton = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    } else {
        _cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_cancelButton setTitle:kLang(@"payment_cancel_action") forState:UIControlStateNormal];
        _cancelButton.backgroundColor = [UIColor systemGray5Color];
        _cancelButton.layer.cornerRadius = 12;
    }
    _cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_cancelButton addTarget:self action:@selector(cancelTapped) forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:_titleLabel];
    [self.view addSubview:_messageLabel];
    [self.view addSubview:_confirmButton];
    [self.view addSubview:_cancelButton];

    // 📐 Constraints
    [NSLayoutConstraint activateConstraints:@[
        [_titleLabel.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:28],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],

        [_messageLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:8],
        [_messageLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [_messageLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],

        [_confirmButton.topAnchor constraintEqualToAnchor:_messageLabel.bottomAnchor constant:24],
        [_confirmButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:30],
        [_confirmButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-30],
        [_confirmButton.heightAnchor constraintEqualToConstant:48],

        [_cancelButton.topAnchor constraintEqualToAnchor:_confirmButton.bottomAnchor constant:12],
        [_cancelButton.leadingAnchor constraintEqualToAnchor:_confirmButton.leadingAnchor],
        [_cancelButton.trailingAnchor constraintEqualToAnchor:_confirmButton.trailingAnchor],
        [_cancelButton.heightAnchor constraintEqualToConstant:46],
        [_cancelButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20]
    ]];
}

#pragma mark - Presentation

- (void)presentIn:(UIViewController *)parentVC {
    if (@available(iOS 15.0, *)) {
        self.modalPresentationStyle = UIModalPresentationPageSheet;
        UISheetPresentationController *sheet = self.sheetPresentationController;
        sheet.detents = @[
            [UISheetPresentationControllerDetent mediumDetent],
            [UISheetPresentationControllerDetent largeDetent]
        ];
        sheet.prefersGrabberVisible = YES;
        sheet.preferredCornerRadius = 24;
        [parentVC presentViewController:self animated:YES completion:nil];
    } else {
        // Legacy fallback — fade from bottom
        self.modalPresentationStyle = UIModalPresentationOverCurrentContext;
        self.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
        [parentVC presentViewController:self animated:YES completion:nil];
    }
}

#pragma mark - Actions

- (void)confirmTapped {
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
    [self dismissViewControllerAnimated:YES completion:^{
        if (self.onConfirm) self.onConfirm();
    }];
}

- (void)cancelTapped {
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
    [self dismissViewControllerAnimated:YES completion:^{
        if (self.onCancel) self.onCancel();
    }];
}

@end
