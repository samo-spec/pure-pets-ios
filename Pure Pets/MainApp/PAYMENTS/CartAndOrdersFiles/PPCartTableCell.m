//
//  PPCartTableCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 01/11/2025.
//

#import "PPCartTableCell.h"
#import "CartItem.h"
#import "PPChatsFunc.h"
#import "PPCommerceFeedbackManager.h"
#import <QuartzCore/QuartzCore.h>

#ifndef DLog
#define DLog(fmt, ...) NSLog((@"[PPCartCell] " fmt), ##__VA_ARGS__)
#endif

static CGFloat const kPPCartCellOuterVerticalInset = 8.0;
static CGFloat const kPPCartCellOuterHorizontalInset = 15.0;
static CGFloat const kPPCartCellCardCornerRadius = 24.0;
static CGFloat const kPPCartCellImageShellWidth = 94.0;
static CGFloat const kPPCartCellStepperHeight = 38.0;
static CGFloat const kPPCartCellAccentRailWidth = 3.0;

static UIColor *PPCartCellAccentColor(void)
{
    return AppPrimaryClr ?: UIColor.systemOrangeColor;
}

static UIColor *PPCartCellSurfaceColor(void)
{
    return AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;
}

static UIColor *PPCartCellPrimaryTextColor(void)
{
    return AppPrimaryTextClr ?: UIColor.labelColor;
}

static UIColor *PPCartCellSecondaryTextColor(void)
{
    return AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
}

static UIColor *PPCartCellHairlineColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
                ? [UIColor colorWithWhite:1.0 alpha:0.10]
                : [UIColor colorWithWhite:0.0 alpha:0.055];
        }];
    }
    return [UIColor colorWithWhite:0.0 alpha:0.06];
}

static UIColor *PPCartCellSoftFillColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
                ? [UIColor colorWithWhite:1.0 alpha:0.075]
                : [UIColor colorWithWhite:0.0 alpha:0.035];
        }];
    }
    return [UIColor colorWithWhite:0.0 alpha:0.035];
}

typedef NS_ENUM(NSInteger, PPCartActionButtonKind) {
    PPCartActionButtonKindNeutral = 0,
    PPCartActionButtonKindAccent = 1,
};

@interface PPCartInsetLabel : UILabel
@property (nonatomic, assign) UIEdgeInsets textInsets;
@end

@implementation PPCartInsetLabel

- (instancetype)init
{
    self = [super init];
    if (self) {
        _textInsets = UIEdgeInsetsMake(6.0, 10.0, 6.0, 10.0);
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

@interface PPCartTableCell ()

@property (nonatomic, strong) UIView *cardContainer;
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIView *accentRailView;
@property (nonatomic, strong) UIView *imageShellView;
@property (nonatomic, strong) UIView *stepperPillView;

@property (nonatomic, strong) PPCartInsetLabel *eyebrowLabel;
@property (nonatomic, strong) PPCartInsetLabel *subtotalPillLabel;
@property (nonatomic, strong) PPCartInsetLabel *savingsPillLabel;

@property (nonatomic, strong) UIStackView *textStack;
@property (nonatomic, strong) UIStackView *stepperStack;

@property (nonatomic, strong, readwrite) UIImageView *itemImageView;
@property (nonatomic, strong, readwrite) UILabel *nameLabel;
@property (nonatomic, strong, readwrite) UILabel *priceLabel;
@property (nonatomic, strong) UILabel *originalPriceLabel;
@property (nonatomic, strong, readwrite) UILabel *quantityLabel;

@property (nonatomic, strong) UIButton *minusButton;
@property (nonatomic, strong) UIButton *plusButton;

@property (nonatomic, strong) CartItem *currentItem;

@end

@implementation PPCartTableCell

#pragma mark - Init

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupViews];
    }
    return self;
}

#pragma mark - Setup UI

- (void)setupViews
{
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.contentView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    UIView *cardContainer = [[UIView alloc] initWithFrame:CGRectZero];
    cardContainer.translatesAutoresizingMaskIntoConstraints = NO;
    cardContainer.backgroundColor = UIColor.clearColor;
    cardContainer.layer.cornerRadius = kPPCartCellCardCornerRadius;
    [cardContainer pp_setShadowColor:UIColor.blackColor];
    cardContainer.layer.shadowOpacity = 0.10;
    cardContainer.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    cardContainer.layer.shadowRadius = 22.0;
    cardContainer.layer.masksToBounds = NO;
    if (@available(iOS 13.0, *)) {
        cardContainer.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.contentView addSubview:cardContainer];
    self.cardContainer = cardContainer;

    UIView *surfaceView = [[UIView alloc] initWithFrame:CGRectZero];
    surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    surfaceView.backgroundColor = PPCartCellSurfaceColor();
    surfaceView.layer.cornerRadius = kPPCartCellCardCornerRadius;
    surfaceView.layer.borderWidth = 0.8;
    [surfaceView pp_setBorderColor:PPCartCellHairlineColor()];
    surfaceView.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [cardContainer addSubview:surfaceView];
    self.surfaceView = surfaceView;

    UIView *accentRailView = [[UIView alloc] initWithFrame:CGRectZero];
    accentRailView.translatesAutoresizingMaskIntoConstraints = NO;
    accentRailView.userInteractionEnabled = NO;
    accentRailView.backgroundColor = [PPCartCellAccentColor() colorWithAlphaComponent:0.72];
    [surfaceView addSubview:accentRailView];
    self.accentRailView = accentRailView;

    UIView *topGlow = [[UIView alloc] initWithFrame:CGRectZero];
    topGlow.translatesAutoresizingMaskIntoConstraints = NO;
    topGlow.userInteractionEnabled = NO;
    topGlow.backgroundColor = [PPCartCellAccentColor() colorWithAlphaComponent:0.075];
    topGlow.layer.cornerRadius = 78.0;
    topGlow.alpha = 0.26;
    [surfaceView addSubview:topGlow];

    UIView *bottomGlow = [[UIView alloc] initWithFrame:CGRectZero];
    bottomGlow.translatesAutoresizingMaskIntoConstraints = NO;
    bottomGlow.userInteractionEnabled = NO;
    bottomGlow.backgroundColor = [UIColor.systemTealColor colorWithAlphaComponent:0.035];
    bottomGlow.layer.cornerRadius = 70.0;
    bottomGlow.alpha = 0.22;
    [surfaceView addSubview:bottomGlow];

    UIView *imageShellView = [[UIView alloc] initWithFrame:CGRectZero];
    imageShellView.translatesAutoresizingMaskIntoConstraints = NO;
    imageShellView.backgroundColor = PPCartCellSoftFillColor();
    imageShellView.layer.cornerRadius = 22.0;
    imageShellView.layer.borderWidth = 0.8;
    [imageShellView pp_setBorderColor:PPCartCellHairlineColor()];
    imageShellView.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        imageShellView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [surfaceView addSubview:imageShellView];
    self.imageShellView = imageShellView;

    UIImageView *itemImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    itemImageView.translatesAutoresizingMaskIntoConstraints = NO;
    itemImageView.layer.cornerRadius = 18.0;
    itemImageView.clipsToBounds = YES;
    itemImageView.contentMode = UIViewContentModeScaleAspectFill;
    itemImageView.backgroundColor = UIColor.secondarySystemBackgroundColor;
    if (@available(iOS 13.0, *)) {
        itemImageView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [imageShellView addSubview:itemImageView];
    self.itemImageView = itemImageView;

    PPCartInsetLabel *eyebrowLabel = [self pp_buildCapsuleLabelWithFont:[GM MidFontWithSize:10.5]
                                                              textColor:PPCartCellAccentColor()
                                                        backgroundColor:[PPCartCellAccentColor() colorWithAlphaComponent:0.13]
                                                            borderColor:[PPCartCellAccentColor() colorWithAlphaComponent:0.16] corners:9];
    eyebrowLabel.textInsets = UIEdgeInsetsMake(5.0, 9.0, 5.0, 9.0);
    eyebrowLabel.adjustsFontSizeToFitWidth = YES;
    eyebrowLabel.minimumScaleFactor = 0.80;
    eyebrowLabel.layer.cornerRadius = 14.0;
    self.eyebrowLabel = eyebrowLabel;

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.font = [GM boldFontWithSize:16.5];
    nameLabel.textColor = PPCartCellPrimaryTextColor();
    nameLabel.numberOfLines = 2;
    nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    nameLabel.textAlignment = NSTextAlignmentNatural;
    [nameLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                               forAxis:UILayoutConstraintAxisVertical];
    self.nameLabel = nameLabel;

    UILabel *priceLabel = [[UILabel alloc] init];
    priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    priceLabel.font = [GM boldFontWithSize:17.5];
    priceLabel.textColor = PPCartCellPrimaryTextColor();
    priceLabel.numberOfLines = 1;
    priceLabel.textAlignment = NSTextAlignmentNatural;
    [priceLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                forAxis:UILayoutConstraintAxisHorizontal];
    self.priceLabel = priceLabel;

    UILabel *originalPriceLabel = [[UILabel alloc] init];
    originalPriceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    originalPriceLabel.font = [GM fontWithSize:12.5];
    originalPriceLabel.textColor = [PPCartCellSecondaryTextColor() colorWithAlphaComponent:0.62];
    originalPriceLabel.numberOfLines = 1;
    originalPriceLabel.textAlignment = NSTextAlignmentNatural;
    originalPriceLabel.hidden = YES;
    self.originalPriceLabel = originalPriceLabel;

    PPCartInsetLabel *savingsPillLabel = [self pp_buildCapsuleLabelWithFont:[GM boldFontWithSize:11.0]
                                                                  textColor:[UIColor systemRedColor]
                                                            backgroundColor:[[UIColor systemRedColor] colorWithAlphaComponent:0.10]
                                                                borderColor:[[UIColor systemRedColor] colorWithAlphaComponent:0.12] corners:9];
    savingsPillLabel.textInsets = UIEdgeInsetsMake(5.0, 9.0, 5.0, 9.0);
    savingsPillLabel.hidden = YES;
    savingsPillLabel.textAlignment = NSTextAlignmentCenter;
    savingsPillLabel.numberOfLines = 1;
    self.savingsPillLabel = savingsPillLabel;

    [imageShellView addSubview:eyebrowLabel];

    UIView *headerSpacer = [[UIView alloc] initWithFrame:CGRectZero];
    headerSpacer.translatesAutoresizingMaskIntoConstraints = NO;
    [headerSpacer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [headerSpacer setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    UIStackView *headerRow = [[UIStackView alloc] initWithArrangedSubviews:@[
        nameLabel,
        headerSpacer
    ]];
    headerRow.translatesAutoresizingMaskIntoConstraints = NO;
    headerRow.axis = UILayoutConstraintAxisHorizontal;
    headerRow.alignment = UIStackViewAlignmentFill;
    headerRow.spacing = 12.0;

    UIStackView *priceRow = [[UIStackView alloc] initWithArrangedSubviews:@[
        priceLabel,
        originalPriceLabel,
        savingsPillLabel
    ]];
    priceRow.translatesAutoresizingMaskIntoConstraints = NO;
    priceRow.axis = UILayoutConstraintAxisHorizontal;
    priceRow.alignment = UIStackViewAlignmentCenter;
    priceRow.spacing = 8.0;

    PPCartInsetLabel *subtotalPillLabel = [self pp_buildCapsuleLabelWithFont:[GM MidFontWithSize:11.5]
                                                                   textColor:PPCartCellSecondaryTextColor()
                                                             backgroundColor:PPCartCellSoftFillColor()
                                                                 borderColor:PPCartCellHairlineColor() corners:14];
    subtotalPillLabel.textInsets = UIEdgeInsetsMake(6.0, 10.0, 6.0, 10.0);
    subtotalPillLabel.numberOfLines = 1;
    subtotalPillLabel.adjustsFontSizeToFitWidth = YES;
    subtotalPillLabel.minimumScaleFactor = 0.78;
    [subtotalPillLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                       forAxis:UILayoutConstraintAxisHorizontal];
    self.subtotalPillLabel = subtotalPillLabel;

    UIButton *minusButton = [self pp_createIconButtonWithSystemName:@"minus" kind:PPCartActionButtonKindNeutral];
    [minusButton addTarget:self action:@selector(didTapMinus) forControlEvents:UIControlEventTouchUpInside];
    [self pp_applyPressTargetsToButton:minusButton];
    self.minusButton = minusButton;

    UILabel *quantityLabel = [[UILabel alloc] init];
    quantityLabel.translatesAutoresizingMaskIntoConstraints = NO;
    quantityLabel.font = [GM boldFontWithSize:15.0];
    quantityLabel.textAlignment = NSTextAlignmentCenter;
    quantityLabel.textColor = PPCartCellPrimaryTextColor();
    quantityLabel.numberOfLines = 1;
    quantityLabel.adjustsFontSizeToFitWidth = YES;
    quantityLabel.minimumScaleFactor = 0.80;
    self.quantityLabel = quantityLabel;

    UIButton *plusButton = [self pp_createIconButtonWithSystemName:@"plus" kind:PPCartActionButtonKindAccent];
    [plusButton addTarget:self action:@selector(didTapPlus) forControlEvents:UIControlEventTouchUpInside];
    [self pp_applyPressTargetsToButton:plusButton];
    self.plusButton = plusButton;

    UIView *stepperPillView = [[UIView alloc] initWithFrame:CGRectZero];
    stepperPillView.translatesAutoresizingMaskIntoConstraints = NO;
    stepperPillView.backgroundColor = PPCartCellSoftFillColor();
    stepperPillView.layer.cornerRadius = kPPCartCellStepperHeight * 0.5;
    stepperPillView.layer.borderWidth = 0.8;
    [stepperPillView pp_setBorderColor:PPCartCellHairlineColor()];
    stepperPillView.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        stepperPillView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.stepperPillView = stepperPillView;

    UIStackView *stepperStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        minusButton,
        quantityLabel,
        plusButton
    ]];
    stepperStack.translatesAutoresizingMaskIntoConstraints = NO;
    stepperStack.axis = UILayoutConstraintAxisHorizontal;
    stepperStack.alignment = UIStackViewAlignmentCenter;
    stepperStack.spacing = 7.0;
    [stepperPillView addSubview:stepperStack];
    self.stepperStack = stepperStack;

    UIView *bottomRowSpacer = [[UIView alloc] initWithFrame:CGRectZero];
    bottomRowSpacer.translatesAutoresizingMaskIntoConstraints = NO;
    [bottomRowSpacer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [bottomRowSpacer setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    UIStackView *bottomRow = [[UIStackView alloc] initWithArrangedSubviews:@[
        subtotalPillLabel,
        bottomRowSpacer,
        stepperPillView
    ]];
    bottomRow.translatesAutoresizingMaskIntoConstraints = NO;
    bottomRow.axis = UILayoutConstraintAxisHorizontal;
    bottomRow.alignment = UIStackViewAlignmentCenter;
    bottomRow.spacing = 9.0;

    UIStackView *contentStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        headerRow,
        priceRow,
        bottomRow
    ]];
    contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    contentStack.axis = UILayoutConstraintAxisVertical;
    contentStack.alignment = UIStackViewAlignmentFill;
    contentStack.spacing = 7.0;
    contentStack.distribution = UIStackViewDistributionFill;
    [surfaceView addSubview:contentStack];
    self.textStack = contentStack;

    [NSLayoutConstraint activateConstraints:@[
        [cardContainer.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:kPPCartCellOuterVerticalInset],
        [cardContainer.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-kPPCartCellOuterVerticalInset],
        [cardContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:kPPCartCellOuterHorizontalInset],
        [cardContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-kPPCartCellOuterHorizontalInset],

        [surfaceView.topAnchor constraintEqualToAnchor:cardContainer.topAnchor],
        [surfaceView.bottomAnchor constraintEqualToAnchor:cardContainer.bottomAnchor],
        [surfaceView.leadingAnchor constraintEqualToAnchor:cardContainer.leadingAnchor],
        [surfaceView.trailingAnchor constraintEqualToAnchor:cardContainer.trailingAnchor],

        [accentRailView.topAnchor constraintEqualToAnchor:surfaceView.topAnchor constant:18.0],
        [accentRailView.bottomAnchor constraintEqualToAnchor:surfaceView.bottomAnchor constant:-18.0],
        [accentRailView.leadingAnchor constraintEqualToAnchor:surfaceView.leadingAnchor],
        [accentRailView.widthAnchor constraintEqualToConstant:kPPCartCellAccentRailWidth],

        [topGlow.widthAnchor constraintEqualToConstant:156.0],
        [topGlow.heightAnchor constraintEqualToConstant:156.0],
        [topGlow.topAnchor constraintEqualToAnchor:surfaceView.topAnchor constant:-54.0],
        [topGlow.trailingAnchor constraintEqualToAnchor:surfaceView.trailingAnchor constant:42.0],

        [bottomGlow.widthAnchor constraintEqualToConstant:140.0],
        [bottomGlow.heightAnchor constraintEqualToConstant:140.0],
        [bottomGlow.bottomAnchor constraintEqualToAnchor:surfaceView.bottomAnchor constant:52.0],
        [bottomGlow.leadingAnchor constraintEqualToAnchor:surfaceView.leadingAnchor constant:-34.0],

        [imageShellView.topAnchor constraintEqualToAnchor:surfaceView.topAnchor constant:10.0],
        [imageShellView.bottomAnchor constraintEqualToAnchor:surfaceView.bottomAnchor constant:-10.0],
        [imageShellView.leadingAnchor constraintEqualToAnchor:surfaceView.leadingAnchor constant:10.0],
        [imageShellView.widthAnchor constraintEqualToConstant:kPPCartCellImageShellWidth],

        [itemImageView.topAnchor constraintEqualToAnchor:imageShellView.topAnchor constant:4.0],
        [itemImageView.bottomAnchor constraintEqualToAnchor:imageShellView.bottomAnchor constant:-4.0],
        [itemImageView.leadingAnchor constraintEqualToAnchor:imageShellView.leadingAnchor constant:4.0],
        [itemImageView.trailingAnchor constraintEqualToAnchor:imageShellView.trailingAnchor constant:-4.0],

        [eyebrowLabel.leadingAnchor constraintEqualToAnchor:imageShellView.leadingAnchor constant:8.0],
        [eyebrowLabel.bottomAnchor constraintEqualToAnchor:imageShellView.bottomAnchor constant:-8.0],
        [eyebrowLabel.trailingAnchor constraintLessThanOrEqualToAnchor:imageShellView.trailingAnchor constant:-8.0],

        [contentStack.topAnchor constraintEqualToAnchor:surfaceView.topAnchor constant:12.0],
        [contentStack.bottomAnchor constraintEqualToAnchor:surfaceView.bottomAnchor constant:-12.0],
        [contentStack.leadingAnchor constraintEqualToAnchor:imageShellView.trailingAnchor constant:14.0],
        [contentStack.trailingAnchor constraintEqualToAnchor:surfaceView.trailingAnchor constant:-12.0],

        [stepperPillView.heightAnchor constraintEqualToConstant:kPPCartCellStepperHeight],
        [stepperPillView.widthAnchor constraintGreaterThanOrEqualToConstant:118.0],

        [stepperStack.topAnchor constraintEqualToAnchor:stepperPillView.topAnchor constant:6.0],
        [stepperStack.bottomAnchor constraintEqualToAnchor:stepperPillView.bottomAnchor constant:-6.0],
        [stepperStack.leadingAnchor constraintEqualToAnchor:stepperPillView.leadingAnchor constant:7.0],
        [stepperStack.trailingAnchor constraintEqualToAnchor:stepperPillView.trailingAnchor constant:-7.0],

        [minusButton.widthAnchor constraintEqualToConstant:28.0],
        [minusButton.heightAnchor constraintEqualToConstant:28.0],
        [plusButton.widthAnchor constraintEqualToConstant:28.0],
        [plusButton.heightAnchor constraintEqualToConstant:28.0],
        [quantityLabel.widthAnchor constraintGreaterThanOrEqualToConstant:28.0],
    ]];

    self.minusButton.accessibilityLabel = NSLocalizedString(@"a11y_btn_decrease_qty", @"Decrease quantity");
    self.plusButton.accessibilityLabel = NSLocalizedString(@"a11y_btn_increase_qty", @"Increase quantity");

    [self pp_styleActionButton:self.minusButton kind:PPCartActionButtonKindNeutral enabled:YES];
    [self pp_styleActionButton:self.plusButton kind:PPCartActionButtonKindAccent enabled:YES];
    [self pp_applyVisualTheme];
}

- (void)pp_applyVisualTheme
{
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    UIColor *accent = PPCartCellAccentColor();
    UIColor *surfaceColor = PPCartCellSurfaceColor();

    self.cardContainer.layer.shadowOpacity = dark ? 0.18 : 0.08;
    self.cardContainer.layer.shadowRadius = dark ? 18.0 : 22.0;
    self.cardContainer.layer.shadowOffset = CGSizeMake(0.0, dark ? 8.0 : 12.0);

    self.surfaceView.backgroundColor = surfaceColor;
    [self.surfaceView pp_setBorderColor:PPCartCellHairlineColor()];

    self.accentRailView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.62 : 0.72];
    self.imageShellView.backgroundColor = PPCartCellSoftFillColor();
    [self.imageShellView pp_setBorderColor:PPCartCellHairlineColor()];
    self.itemImageView.backgroundColor = dark ? UIColor.tertiarySystemBackgroundColor : UIColor.secondarySystemBackgroundColor;

    self.nameLabel.textColor = PPCartCellPrimaryTextColor();
    self.priceLabel.textColor = PPCartCellPrimaryTextColor();
    self.originalPriceLabel.textColor = [PPCartCellSecondaryTextColor() colorWithAlphaComponent:0.62];
    self.quantityLabel.textColor = PPCartCellPrimaryTextColor();

    self.eyebrowLabel.textColor = accent;
    self.eyebrowLabel.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.18 : 0.12];
    [self.eyebrowLabel pp_setBorderColor:[accent colorWithAlphaComponent:dark ? 0.22 : 0.16]];

    self.stepperPillView.backgroundColor = PPCartCellSoftFillColor();
    [self.stepperPillView pp_setBorderColor:PPCartCellHairlineColor()];

    if (self.currentItem.hasDiscount) {
        self.subtotalPillLabel.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.20 : 0.14];
        [self.subtotalPillLabel pp_setBorderColor:[accent colorWithAlphaComponent:dark ? 0.24 : 0.18]];
        self.subtotalPillLabel.textColor = accent;
    } else {
        self.subtotalPillLabel.backgroundColor = PPCartCellSoftFillColor();
        [self.subtotalPillLabel pp_setBorderColor:PPCartCellHairlineColor()];
        self.subtotalPillLabel.textColor = PPCartCellSecondaryTextColor();
    }

    if (self.currentItem) {
        [self pp_updateActionAvailability];
    }
}

- (PPCartInsetLabel *)pp_buildCapsuleLabelWithFont:(UIFont *)font
                                         textColor:(UIColor *)textColor
                                   backgroundColor:(UIColor *)backgroundColor
                                       borderColor:(UIColor *)borderColor
                                           corners:(float)corners
{
    PPCartInsetLabel *label = [[PPCartInsetLabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = font;
    label.textColor = textColor;
    label.backgroundColor = backgroundColor;
    label.layer.cornerRadius = corners;
    label.layer.borderWidth = 0.8;
    [label pp_setBorderColor:borderColor];
    label.layer.masksToBounds = YES;
    label.textAlignment = NSTextAlignmentNatural;
    label.numberOfLines = 1;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    if (@available(iOS 13.0, *)) {
        label.layer.cornerCurve = kCACornerCurveContinuous;
    }
    return label;
}

#pragma mark - Lifecycle

- (void)prepareForReuse
{
    [super prepareForReuse];

    self.currentItem = nil;
    self.itemImageView.image = nil;
    self.nameLabel.text = @"";
    self.eyebrowLabel.text = @"";
    self.priceLabel.text = @"";
    self.originalPriceLabel.attributedText = nil;
    self.originalPriceLabel.hidden = YES;
    self.quantityLabel.text = @"";
    self.subtotalPillLabel.text = @"";
    self.savingsPillLabel.text = @"";
    self.savingsPillLabel.hidden = YES;

    [self pp_setCardHighlighted:NO animated:NO];

    [self.cardContainer.layer removeAllAnimations];
    [self.surfaceView.layer removeAllAnimations];
    [self.stepperPillView.layer removeAllAnimations];
    [self.quantityLabel.layer removeAllAnimations];
    self.cardContainer.transform = CGAffineTransformIdentity;
    self.surfaceView.transform = CGAffineTransformIdentity;
    self.stepperPillView.transform = CGAffineTransformIdentity;
    self.quantityLabel.transform = CGAffineTransformIdentity;
    self.minusButton.transform = CGAffineTransformIdentity;
    self.plusButton.transform = CGAffineTransformIdentity;
    self.minusButton.alpha = 1.0;
    self.plusButton.alpha = 1.0;

    [self pp_applyVisualTheme];
    [self pp_styleActionButton:self.minusButton kind:PPCartActionButtonKindNeutral enabled:YES];
    [self pp_styleActionButton:self.plusButton kind:PPCartActionButtonKindAccent enabled:YES];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    if (!CGRectIsEmpty(self.cardContainer.bounds)) {
        self.cardContainer.layer.shadowPath =
            [UIBezierPath bezierPathWithRoundedRect:self.cardContainer.bounds
                                      cornerRadius:self.cardContainer.layer.cornerRadius].CGPath;
    }
    self.accentRailView.layer.cornerRadius = kPPCartCellAccentRailWidth * 0.5;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    [self pp_applyVisualTheme];
}

#pragma mark - Configuration

- (void)configureWithItem:(CartItem *)item
{
    self.currentItem = item;
    [self pp_refreshContentForCurrentItem];

    DLog(@"Configured cell | itemID=%@ | name=%@ | price=%.2f | original=%.2f | discount=%@ | qty=%ld",
         item.itemID, item.name, item.price, item.originalPrice,
         item.hasDiscount ? @"YES" : @"NO", (long)item.quantity);
}

- (void)pp_refreshContentForCurrentItem
{
    CartItem *item = self.currentItem;
    if (!item) return;

    NSInteger quantity = MAX(1, item.quantity);
    NSString *eyebrowText = item.type.length > 0 ? item.type : kLang(@"cartTitle");
    eyebrowText = [[eyebrowText stringByReplacingOccurrencesOfString:@"_" withString:@" "] uppercaseString];

    self.eyebrowLabel.text = eyebrowText;
    self.nameLabel.text = item.name ?: @"";
    self.quantityLabel.text = [NSString stringWithFormat:@"%ld", (long)quantity];
    self.priceLabel.text = [PPChatsFunc formattedCurrency:item.price];
    self.subtotalPillLabel.text = [NSString stringWithFormat:@"%@ %@",
                                   kLang(@"Subtotal"),
                                   [PPChatsFunc formattedCurrency:item.lineSubtotal]];

    if (item.hasDiscount) {
        NSString *originalText = [PPChatsFunc formattedCurrency:item.originalPrice];
        NSDictionary *attributes = @{
            NSStrikethroughStyleAttributeName: @(NSUnderlineStyleSingle),
            NSForegroundColorAttributeName: [PPCartCellSecondaryTextColor() colorWithAlphaComponent:0.62],
            NSFontAttributeName: self.originalPriceLabel.font
        };
        self.originalPriceLabel.attributedText = [[NSAttributedString alloc] initWithString:originalText
                                                                                 attributes:attributes];
        self.originalPriceLabel.hidden = NO;
        self.savingsPillLabel.text = [NSString stringWithFormat:@"-%@",
                                      [PPChatsFunc formattedCurrency:item.discountPerUnit]];
        self.savingsPillLabel.hidden = NO;
    } else {
        self.originalPriceLabel.attributedText = nil;
        self.originalPriceLabel.hidden = YES;
        self.savingsPillLabel.text = @"";
        self.savingsPillLabel.hidden = YES;
    }

    [self pp_applyVisualTheme];
    [GM setImageFromUrlString:item.imageURL imageView:self.itemImageView phImage:@"placeholder"];
    [self pp_updateActionAvailability];
}

- (void)pp_updateActionAvailability
{
    if (!self.currentItem) return;

    BOOL canDecrease = self.currentItem.quantity > 1;
    BOOL stockIsKnown = self.currentItem.stockQuantity != NSNotFound;
    BOOL canIncrease = !stockIsKnown || self.currentItem.quantity < self.currentItem.stockQuantity;

    [self pp_styleActionButton:self.minusButton kind:PPCartActionButtonKindNeutral enabled:canDecrease];
    [self pp_styleActionButton:self.plusButton kind:PPCartActionButtonKindAccent enabled:canIncrease];
}

#pragma mark - Actions

- (void)didTapMinus
{
    if (!self.currentItem || self.currentItem.quantity <= 1) return;

    DLog(@"Minus tapped for %@", self.currentItem.name);
    self.currentItem.quantity -= 1;
    [self pp_refreshContentForCurrentItem];
    [self pp_animateQuantityChangeWithIncreasing:NO];
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventCartQuantityChanged];

    if (self.onAction) {
        self.onAction(self.currentItem, @"minus");
    }
}

- (void)didTapPlus
{
    if (!self.currentItem) return;
    if (self.currentItem.stockQuantity != NSNotFound &&
        self.currentItem.quantity >= self.currentItem.stockQuantity) {
        return;
    }

    DLog(@"Plus tapped for %@", self.currentItem.name);
    self.currentItem.quantity += 1;
    [self pp_refreshContentForCurrentItem];
    [self pp_animateQuantityChangeWithIncreasing:YES];
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventCartQuantityChanged];

    if (self.onAction) {
        self.onAction(self.currentItem, @"plus");
    }
}

#pragma mark - Helpers

- (UIButton *)pp_createIconButtonWithSystemName:(NSString *)iconName kind:(PPCartActionButtonKind)kind
{
    UIImageSymbolConfiguration *configuration =
        [UIImageSymbolConfiguration configurationWithPointSize:13.0
                                                        weight:UIImageSymbolWeightSemibold];
    UIImage *image = [[UIImage systemImageNamed:iconName] imageByApplyingSymbolConfiguration:configuration];

    UIButton *button;
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        config.contentInsets = NSDirectionalEdgeInsetsMake(6.0, 6.0, 6.0, 6.0);
        config.image = image;
        button = [UIButton buttonWithConfiguration:config primaryAction:nil];
    } else {
        button = [UIButton buttonWithType:UIButtonTypeSystem];
        [button setImage:image forState:UIControlStateNormal];
        button.contentEdgeInsets = UIEdgeInsetsMake(6.0, 6.0, 6.0, 6.0);
        button.layer.cornerRadius = 14.0;
        button.clipsToBounds = YES;
    }

    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.adjustsImageWhenHighlighted = NO;
    [self pp_styleActionButton:button kind:kind enabled:YES];
    return button;
}

- (void)pp_styleActionButton:(UIButton *)button kind:(PPCartActionButtonKind)kind enabled:(BOOL)enabled
{
    if (!button) return;

    UIColor *foregroundColor = PPCartCellPrimaryTextColor();
    UIColor *backgroundColor = PPCartCellSoftFillColor();
    UIColor *borderColor = PPCartCellHairlineColor();

    switch (kind) {
        case PPCartActionButtonKindAccent:
            foregroundColor = PPCartCellAccentColor();
            backgroundColor = [PPCartCellAccentColor() colorWithAlphaComponent:enabled ? 0.15 : 0.06];
            borderColor = [PPCartCellAccentColor() colorWithAlphaComponent:enabled ? 0.20 : 0.08];
            break;
        case PPCartActionButtonKindNeutral:
        default:
            foregroundColor = PPCartCellPrimaryTextColor();
            backgroundColor = PPCartCellSoftFillColor();
            borderColor = PPCartCellHairlineColor();
            break;
    }

    button.userInteractionEnabled = enabled;
    button.alpha = enabled ? 1.0 : 0.46;

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = button.configuration ?: [UIButtonConfiguration plainButtonConfiguration];
        config.baseForegroundColor = foregroundColor;
        config.background.backgroundColor = backgroundColor;
        config.background.strokeColor = borderColor;
        config.background.strokeWidth = 0.8;
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        config.contentInsets = NSDirectionalEdgeInsetsMake(6.0, 6.0, 6.0, 6.0);
        button.configuration = config;
    } else {
        button.tintColor = foregroundColor;
        button.backgroundColor = backgroundColor;
        button.layer.borderWidth = 0.8;
        [button pp_setBorderColor:borderColor];
    }
}

#pragma mark - Selection / Motion

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    [self pp_setCardHighlighted:highlighted animated:animated];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    [self pp_setCardHighlighted:selected animated:animated];
}

- (void)pp_setCardHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    UIView *target = self.cardContainer ?: self.contentView;
    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    CGFloat scale = (highlighted && !reduceMotion) ? 0.985 : 1.0;
    CGFloat alpha = highlighted ? 0.97 : 1.0;
    CGFloat shadowOpacity = highlighted ? 0.06 : (dark ? 0.18 : 0.08);

    void (^changes)(void) = ^{
        target.transform = CGAffineTransformMakeScale(scale, scale);
        target.alpha = alpha;
        self.cardContainer.layer.shadowOpacity = shadowOpacity;
    };

    if (!animated) {
        changes();
        return;
    }

    [UIView animateWithDuration:0.14
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                     animations:changes
                     completion:nil];
}

- (void)pp_applyPressTargetsToButton:(UIButton *)button
{
    if (!button) return;

    [button addTarget:self action:@selector(pp_buttonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(pp_buttonTouchUp:) forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:self action:@selector(pp_buttonTouchUp:) forControlEvents:UIControlEventTouchUpOutside];
    [button addTarget:self action:@selector(pp_buttonTouchUp:) forControlEvents:UIControlEventTouchCancel];
}

- (void)pp_buttonTouchDown:(UIButton *)button
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        button.alpha = button.userInteractionEnabled ? 0.90 : button.alpha;
        return;
    }

    [UIView animateWithDuration:0.08
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                     animations:^{
        button.transform = CGAffineTransformMakeScale(0.90, 0.90);
        button.alpha = button.userInteractionEnabled ? 0.92 : button.alpha;
    } completion:nil];
}

- (void)pp_buttonTouchUp:(UIButton *)button
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        button.transform = CGAffineTransformIdentity;
        button.alpha = button.userInteractionEnabled ? 1.0 : 0.46;
        return;
    }

    [UIView animateWithDuration:0.34
                          delay:0.0
         usingSpringWithDamping:0.60
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        button.transform = CGAffineTransformIdentity;
        button.alpha = button.userInteractionEnabled ? 1.0 : 0.46;
    } completion:nil];
}

- (void)pp_animateQuantityChangeWithIncreasing:(BOOL)increasing
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    CGFloat direction = increasing ? -3.0 : 3.0;
    self.quantityLabel.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, direction),
                                                           CGAffineTransformMakeScale(1.16, 1.16));
    self.stepperPillView.transform = CGAffineTransformMakeScale(1.018, 1.018);

    [UIView animateWithDuration:0.38
                          delay:0.0
         usingSpringWithDamping:0.68
          initialSpringVelocity:0.12
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.quantityLabel.transform = CGAffineTransformIdentity;
        self.stepperPillView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

@end
