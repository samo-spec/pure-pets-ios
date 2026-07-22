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
static CGFloat const kPPCartCellOuterHorizontalInset = 16.0;
static CGFloat const kPPCartCellCardCornerRadius = 24.0;
static CGFloat const kPPCartCellImageShellWidth = 94.0;
static CGFloat const kPPCartCellStepperHeight = 38.0;
static CGFloat const kPPCartSavedActionCornerRadius = 16.0;
static CGFloat const kPPCartCellAccentRailWidth = 3.0;
static NSTimeInterval const kPPCartSavedArrivalDuration = 0.46;

static UIColor *PPCartCellAccentColor(void)
{
    return AppPrimaryClr ?: UIColor.systemOrangeColor;
}

static UIColor *PPCartCellDeferredAccentColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
                ? [UIColor colorWithRed:0.74 green:0.59 blue:0.64 alpha:1.0]
                : [UIColor colorWithRed:0.56 green:0.42 blue:0.47 alpha:1.0];
        }];
    }
    return [UIColor colorWithRed:0.56 green:0.42 blue:0.47 alpha:1.0];
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
    PPCartActionButtonKindDestructive = 2,
    PPCartActionButtonKindSuccess = 3,
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
@property (nonatomic, strong) UIView *savedStateTintView;
@property (nonatomic, strong) UIView *accentRailView;
@property (nonatomic, strong) UIView *imageShellView;
@property (nonatomic, strong) UIView *stepperPillView;

@property (nonatomic, strong) PPCartInsetLabel *eyebrowLabel;
@property (nonatomic, strong) PPCartInsetLabel *subtotalPillLabel;
@property (nonatomic, strong) PPCartInsetLabel *savingsPillLabel;
@property (nonatomic, strong) PPCartInsetLabel *savedStatusBadgeLabel;

@property (nonatomic, strong) UIStackView *textStack;
@property (nonatomic, strong) UIStackView *stepperStack;
@property (nonatomic, strong) UIStackView *bottomRow;
@property (nonatomic, strong) UIStackView *savedActionsRow;

@property (nonatomic, strong, readwrite) UIImageView *itemImageView;
@property (nonatomic, strong, readwrite) UILabel *nameLabel;
@property (nonatomic, strong, readwrite) UILabel *priceLabel;
@property (nonatomic, strong) UILabel *originalPriceLabel;
@property (nonatomic, strong, readwrite) UILabel *quantityLabel;

@property (nonatomic, strong) UIButton *minusButton;
@property (nonatomic, strong) UIButton *plusButton;
@property (nonatomic, strong) UIButton *savedRemoveButton;
@property (nonatomic, strong) UIButton *savedPrimaryButton;

@property (nonatomic, strong) CartItem *currentItem;
@property (nonatomic, assign) BOOL savedForLaterMode;
@property (nonatomic, copy) NSString *savedForLaterPrimaryActionName;
@property (nonatomic, assign) BOOL savedForLaterActionCompleted;
@property (nonatomic, assign) NSUInteger savedArrivalAnimationToken;

- (UIImage *)pp_actionImageNamed:(NSString *)systemName;
- (void)pp_setActionButton:(UIButton *)button systemName:(NSString *)systemName;
- (void)pp_animateSavedForLaterActionFromButton:(UIButton *)button;
- (void)pp_configureSavedActionButton:(UIButton *)button
                                title:(NSString *)title
                           systemName:(NSString *)systemName
                              primary:(BOOL)primary
                          destructive:(BOOL)destructive
                              enabled:(BOOL)enabled;

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
    cardContainer.layer.shadowOpacity = 0.045;
    cardContainer.layer.shadowOffset = CGSizeMake(0.0, 7.0);
    cardContainer.layer.shadowRadius = 16.0;
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

    UIView *savedStateTintView = [[UIView alloc] initWithFrame:CGRectZero];
    savedStateTintView.translatesAutoresizingMaskIntoConstraints = NO;
    savedStateTintView.userInteractionEnabled = NO;
    savedStateTintView.alpha = 0.0;
    [surfaceView addSubview:savedStateTintView];
    self.savedStateTintView = savedStateTintView;

    UIView *accentRailView = [[UIView alloc] initWithFrame:CGRectZero];
    accentRailView.translatesAutoresizingMaskIntoConstraints = NO;
    accentRailView.userInteractionEnabled = NO;
    accentRailView.backgroundColor = [PPCartCellAccentColor() colorWithAlphaComponent:0.72];
    [surfaceView addSubview:accentRailView];
    self.accentRailView = accentRailView;

 

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

    PPCartInsetLabel *savedStatusBadgeLabel =
    [self pp_buildCapsuleLabelWithFont:[GM boldFontWithSize:10.5]
                             textColor:PPCartCellDeferredAccentColor()
                       backgroundColor:[PPCartCellDeferredAccentColor() colorWithAlphaComponent:0.10]
                           borderColor:[PPCartCellDeferredAccentColor() colorWithAlphaComponent:0.17]
                               corners:11.0];
    savedStatusBadgeLabel.textInsets = UIEdgeInsetsMake(4.0, 8.0, 4.0, 8.0);
    savedStatusBadgeLabel.textAlignment = NSTextAlignmentCenter;
    savedStatusBadgeLabel.adjustsFontSizeToFitWidth = YES;
    savedStatusBadgeLabel.minimumScaleFactor = 0.76;
    savedStatusBadgeLabel.hidden = YES;
    [savedStatusBadgeLabel setContentHuggingPriority:UILayoutPriorityRequired
                                             forAxis:UILayoutConstraintAxisHorizontal];
    [savedStatusBadgeLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                            forAxis:UILayoutConstraintAxisHorizontal];
    self.savedStatusBadgeLabel = savedStatusBadgeLabel;

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
        headerSpacer,
        savedStatusBadgeLabel
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
    self.bottomRow = bottomRow;

    UIButton *savedRemoveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    savedRemoveButton.translatesAutoresizingMaskIntoConstraints = NO;
    savedRemoveButton.adjustsImageWhenHighlighted = NO;
    [savedRemoveButton setContentHuggingPriority:UILayoutPriorityRequired
                                         forAxis:UILayoutConstraintAxisHorizontal];
    [savedRemoveButton setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                       forAxis:UILayoutConstraintAxisHorizontal];
    [savedRemoveButton addTarget:self
                          action:@selector(didTapSavedRemoveButton)
                forControlEvents:UIControlEventTouchUpInside];
    [self pp_applyPressTargetsToButton:savedRemoveButton];
    self.savedRemoveButton = savedRemoveButton;

    UIButton *savedPrimaryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    savedPrimaryButton.translatesAutoresizingMaskIntoConstraints = NO;
    savedPrimaryButton.adjustsImageWhenHighlighted = NO;
    [savedPrimaryButton setContentHuggingPriority:UILayoutPriorityDefaultLow
                                          forAxis:UILayoutConstraintAxisHorizontal];
    [savedPrimaryButton setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh
                                                        forAxis:UILayoutConstraintAxisHorizontal];
    [savedPrimaryButton addTarget:self
                           action:@selector(didTapSavedPrimaryButton)
                 forControlEvents:UIControlEventTouchUpInside];
    [self pp_applyPressTargetsToButton:savedPrimaryButton];
    self.savedPrimaryButton = savedPrimaryButton;

    UIStackView *savedActionsRow = [[UIStackView alloc] initWithArrangedSubviews:@[
        savedRemoveButton,
        savedPrimaryButton
    ]];
    savedActionsRow.translatesAutoresizingMaskIntoConstraints = NO;
    savedActionsRow.axis = UILayoutConstraintAxisHorizontal;
    savedActionsRow.alignment = UIStackViewAlignmentFill;
    savedActionsRow.distribution = UIStackViewDistributionFill;
    savedActionsRow.spacing = 8.0;
    savedActionsRow.hidden = YES;
    self.savedActionsRow = savedActionsRow;

    UIStackView *contentStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        headerRow,
        priceRow,
        bottomRow,
        savedActionsRow
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

        [savedStateTintView.topAnchor constraintEqualToAnchor:surfaceView.topAnchor],
        [savedStateTintView.bottomAnchor constraintEqualToAnchor:surfaceView.bottomAnchor],
        [savedStateTintView.leadingAnchor constraintEqualToAnchor:surfaceView.leadingAnchor],
        [savedStateTintView.trailingAnchor constraintEqualToAnchor:surfaceView.trailingAnchor],

        [accentRailView.topAnchor constraintEqualToAnchor:surfaceView.topAnchor constant:18.0],
        [accentRailView.bottomAnchor constraintEqualToAnchor:surfaceView.bottomAnchor constant:-18.0],
        [accentRailView.leadingAnchor constraintEqualToAnchor:surfaceView.leadingAnchor],
        [accentRailView.widthAnchor constraintEqualToConstant:kPPCartCellAccentRailWidth],


        

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

        [savedActionsRow.heightAnchor constraintEqualToConstant:kPPCartCellStepperHeight],
        [savedRemoveButton.widthAnchor constraintGreaterThanOrEqualToConstant:72.0],
        [savedPrimaryButton.widthAnchor constraintGreaterThanOrEqualToConstant:140.0],

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

    self.minusButton.accessibilityLabel = kLang(@"a11y_btn_decrease_qty");
    self.plusButton.accessibilityLabel = kLang(@"a11y_btn_increase_qty");

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
    UIColor *stateAccent = self.savedForLaterMode ? PPCartCellDeferredAccentColor() : accent;
    UIColor *surfaceColor = PPCartCellSurfaceColor();

    self.cardContainer.layer.shadowOpacity = self.savedForLaterMode ? (dark ? 0.075 : 0.028) : (dark ? 0.11 : 0.045);
    self.cardContainer.layer.shadowRadius = self.savedForLaterMode ? 10.0 : (dark ? 14.0 : 16.0);
    self.cardContainer.layer.shadowOffset = CGSizeMake(0.0, self.savedForLaterMode ? 4.0 : (dark ? 5.0 : 7.0));

    self.surfaceView.backgroundColor = surfaceColor;
    [self.surfaceView pp_setBorderColor:self.savedForLaterMode
        ? [stateAccent colorWithAlphaComponent:dark ? 0.22 : 0.14]
        : PPCartCellHairlineColor()];

    self.savedStateTintView.alpha = self.savedForLaterMode ? 1.0 : 0.0;
    self.savedStateTintView.backgroundColor = [stateAccent colorWithAlphaComponent:dark ? 0.075 : 0.040];

    self.savedStatusBadgeLabel.textColor = stateAccent;
    self.savedStatusBadgeLabel.backgroundColor = [stateAccent colorWithAlphaComponent:dark ? 0.18 : 0.10];
    [self.savedStatusBadgeLabel pp_setBorderColor:[stateAccent colorWithAlphaComponent:dark ? 0.26 : 0.17]];

    self.accentRailView.backgroundColor = [stateAccent colorWithAlphaComponent:self.savedForLaterMode
        ? (dark ? 0.56 : 0.48)
        : (dark ? 0.62 : 0.72)];
    self.imageShellView.backgroundColor = self.savedForLaterMode
        ? [stateAccent colorWithAlphaComponent:dark ? 0.070 : 0.036]
        : PPCartCellSoftFillColor();
    [self.imageShellView pp_setBorderColor:self.savedForLaterMode
        ? [stateAccent colorWithAlphaComponent:dark ? 0.16 : 0.09]
        : PPCartCellHairlineColor()];
    self.itemImageView.backgroundColor = dark ? UIColor.tertiarySystemBackgroundColor : UIColor.secondarySystemBackgroundColor;
    self.itemImageView.alpha = self.savedForLaterMode ? 0.90 : 1.0;

    self.nameLabel.textColor = PPCartCellPrimaryTextColor();
    self.priceLabel.textColor = self.savedForLaterMode
        ? [PPCartCellPrimaryTextColor() colorWithAlphaComponent:0.78]
        : PPCartCellPrimaryTextColor();
    self.originalPriceLabel.textColor = [PPCartCellSecondaryTextColor() colorWithAlphaComponent:0.62];
    self.quantityLabel.textColor = PPCartCellPrimaryTextColor();

    self.eyebrowLabel.textColor = stateAccent;
    self.eyebrowLabel.backgroundColor = [stateAccent colorWithAlphaComponent:dark ? 0.18 : 0.11];
    [self.eyebrowLabel pp_setBorderColor:[stateAccent colorWithAlphaComponent:dark ? 0.25 : 0.17]];

    self.stepperPillView.backgroundColor = self.savedForLaterMode
        ? [stateAccent colorWithAlphaComponent:dark ? 0.12 : 0.065]
        : PPCartCellSoftFillColor();
    [self.stepperPillView pp_setBorderColor:self.savedForLaterMode
        ? [stateAccent colorWithAlphaComponent:dark ? 0.22 : 0.14]
        : PPCartCellHairlineColor()];

    if (self.savedForLaterMode) {
        self.subtotalPillLabel.backgroundColor = [stateAccent colorWithAlphaComponent:dark ? 0.18 : 0.10];
        [self.subtotalPillLabel pp_setBorderColor:[stateAccent colorWithAlphaComponent:dark ? 0.25 : 0.16]];
        self.subtotalPillLabel.textColor = stateAccent;
    } else if (self.currentItem.hasDiscount) {
        self.subtotalPillLabel.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.20 : 0.14];
        [self.subtotalPillLabel pp_setBorderColor:[accent colorWithAlphaComponent:dark ? 0.24 : 0.18]];
        self.subtotalPillLabel.textColor = accent;
    } else {
        self.subtotalPillLabel.backgroundColor = PPCartCellSoftFillColor();
        [self.subtotalPillLabel pp_setBorderColor:PPCartCellHairlineColor()];
        self.subtotalPillLabel.textColor = PPCartCellSecondaryTextColor();
    }

    if (self.currentItem) {
        if (!self.savedForLaterMode) {
            [self pp_updateActionAvailability];
        }
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

    self.savedArrivalAnimationToken += 1;
    self.currentItem = nil;
    self.savedForLaterMode = NO;
    self.savedForLaterPrimaryActionName = nil;
    self.savedForLaterActionCompleted = NO;
    self.onAction = nil;
    self.itemImageView.image = nil;
    self.nameLabel.text = @"";
    self.eyebrowLabel.text = @"";
    self.priceLabel.text = @"";
    self.originalPriceLabel.attributedText = nil;
    self.originalPriceLabel.hidden = YES;
    self.quantityLabel.text = @"";
    self.quantityLabel.font = [GM boldFontWithSize:15.0];
    self.subtotalPillLabel.text = @"";
    self.savingsPillLabel.text = @"";
    self.savingsPillLabel.hidden = YES;
    self.savedStatusBadgeLabel.text = @"";
    self.savedStatusBadgeLabel.hidden = YES;
    self.bottomRow.hidden = NO;
    self.savedActionsRow.hidden = YES;

    [self pp_setCardHighlighted:NO animated:NO];

    [self.cardContainer.layer removeAllAnimations];
    [self.surfaceView.layer removeAllAnimations];
    [self.stepperPillView.layer removeAllAnimations];
    [self.savedActionsRow.layer removeAllAnimations];
    [self.quantityLabel.layer removeAllAnimations];
    [self.savedStateTintView.layer removeAllAnimations];
    [self.accentRailView.layer removeAllAnimations];
    [self.itemImageView.layer removeAllAnimations];
    self.cardContainer.alpha = 1.0;
    self.cardContainer.transform = CGAffineTransformIdentity;
    self.surfaceView.transform = CGAffineTransformIdentity;
    self.stepperPillView.transform = CGAffineTransformIdentity;
    self.savedActionsRow.transform = CGAffineTransformIdentity;
    self.quantityLabel.transform = CGAffineTransformIdentity;
    self.minusButton.transform = CGAffineTransformIdentity;
    self.plusButton.transform = CGAffineTransformIdentity;
    self.minusButton.alpha = 1.0;
    self.plusButton.alpha = 1.0;
    self.savedRemoveButton.alpha = 1.0;
    self.savedPrimaryButton.alpha = 1.0;
    self.savedRemoveButton.transform = CGAffineTransformIdentity;
    self.savedPrimaryButton.transform = CGAffineTransformIdentity;
    self.savedStateTintView.alpha = 0.0;
    self.itemImageView.alpha = 1.0;
    self.accentRailView.alpha = 1.0;
    self.accentRailView.transform = CGAffineTransformIdentity;
    [self pp_setActionButton:self.minusButton systemName:@"minus"];
    [self pp_setActionButton:self.plusButton systemName:@"plus"];
    self.minusButton.accessibilityLabel = kLang(@"a11y_btn_decrease_qty");
    self.minusButton.accessibilityHint = nil;
    self.plusButton.accessibilityLabel = kLang(@"a11y_btn_increase_qty");
    self.plusButton.accessibilityHint = nil;

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
    self.savedForLaterMode = NO;
    self.savedForLaterPrimaryActionName = nil;
    self.savedForLaterActionCompleted = NO;
    self.quantityLabel.font = [GM boldFontWithSize:15.0];
    [self pp_setActionButton:self.minusButton systemName:@"minus"];
    [self pp_setActionButton:self.plusButton systemName:@"plus"];
    self.minusButton.accessibilityLabel = kLang(@"a11y_btn_decrease_qty");
    self.minusButton.accessibilityHint = nil;
    self.plusButton.accessibilityLabel = kLang(@"a11y_btn_increase_qty");
    self.plusButton.accessibilityHint = nil;
    self.savedStatusBadgeLabel.hidden = YES;
    self.bottomRow.hidden = NO;
    self.savedActionsRow.hidden = YES;

    self.currentItem = item;
    [self pp_refreshContentForCurrentItem];

    DLog(@"Configured cell | itemID=%@ | name=%@ | price=%.2f | original=%.2f | discount=%@ | qty=%ld",
         item.itemID, item.name, item.price, item.originalPrice,
         item.hasDiscount ? @"YES" : @"NO", (long)item.quantity);
}

- (void)configureWithSavedForLaterItem:(CartItem *)item
                      pendingOperation:(NSString * _Nullable)pendingOperation
                             completed:(BOOL)completed
{
    self.savedForLaterMode = YES;
    self.savedForLaterActionCompleted = completed;
    self.currentItem = item;

    BOOL pendingMove = [pendingOperation isEqualToString:@"move"];
    BOOL pendingRemove = [pendingOperation isEqualToString:@"remove"];
    BOOL pendingNotify = [pendingOperation isEqualToString:@"notify"];
    BOOL hasPending = pendingMove || pendingRemove || pendingNotify;
    BOOL stockIsKnown = item.stockQuantity != NSNotFound;
    BOOL isOutOfStock = stockIsKnown && item.stockQuantity <= 0;

    self.savedForLaterPrimaryActionName = isOutOfStock ? @"notifySavedWhenAvailable" : @"moveSavedToCart";
    self.quantityLabel.font = [GM boldFontWithSize:13.0];
    self.savedStatusBadgeLabel.text = kLang(@"saved_for_later_short_badge");
    self.savedStatusBadgeLabel.hidden = NO;
    self.bottomRow.hidden = YES;
    self.savedActionsRow.hidden = NO;

    NSString *eyebrowText = item.type.length > 0 ? item.type : kLang(@"saved_for_later_item_badge");
    eyebrowText = [[eyebrowText stringByReplacingOccurrencesOfString:@"_" withString:@" "] uppercaseString];
    self.eyebrowLabel.text = eyebrowText.length > 0 ? eyebrowText : kLang(@"saved_for_later_item_badge");
    self.nameLabel.text = item.name.length > 0 ? item.name : kLang(@"saved_for_later_unknown_item");
    self.priceLabel.text = [PPChatsFunc formattedCurrency:item.price];
    self.subtotalPillLabel.text = kLang(@"saved_for_later_item_badge");

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

    NSString *primarySymbol = isOutOfStock ? @"bell.badge" : @"cart.badge.plus";
    NSString *primaryLabel = isOutOfStock ? kLang(@"notify_me") : kLang(@"move_to_cart");
    NSString *primaryHint = isOutOfStock ? kLang(@"stock_notify_success") : kLang(@"saved_for_later_move_hint");

    if (pendingMove) {
        primarySymbol = @"hourglass";
        primaryLabel = kLang(@"moving_to_cart");
    } else if (pendingNotify) {
        primarySymbol = @"hourglass";
        primaryLabel = kLang(@"notify_me_loading");
    } else if (completed) {
        primarySymbol = @"checkmark";
        primaryLabel = kLang(@"saved_for_later_moved_action");
    }

    NSString *removeSymbol = pendingRemove ? @"hourglass" : @"trash";
    [self pp_setActionButton:self.minusButton systemName:removeSymbol];
    [self pp_setActionButton:self.plusButton systemName:primarySymbol];
    self.quantityLabel.text = primaryLabel;

    self.minusButton.accessibilityLabel = kLang(@"saved_for_later_delete_action");
    self.minusButton.accessibilityHint = kLang(@"saved_for_later_remove_hint");
    self.plusButton.accessibilityLabel = primaryLabel;
    self.plusButton.accessibilityHint = primaryHint;

    [self pp_configureSavedActionButton:self.savedRemoveButton
                                  title:pendingRemove ? kLang(@"saved_for_later_removing") : kLang(@"saved_for_later_remove_action")
                             systemName:removeSymbol
                                primary:NO
                            destructive:YES
                                enabled:!hasPending && !completed];
    [self pp_configureSavedActionButton:self.savedPrimaryButton
                                  title:primaryLabel
                             systemName:primarySymbol
                                primary:YES
                            destructive:NO
                                enabled:!hasPending && !completed];
    self.savedRemoveButton.accessibilityHint = kLang(@"saved_for_later_remove_hint");
    self.savedPrimaryButton.accessibilityHint = primaryHint;

    [self pp_applyVisualTheme];
    [self pp_styleActionButton:self.minusButton
                          kind:PPCartActionButtonKindDestructive
                       enabled:!hasPending && !completed];
    [self pp_styleActionButton:self.plusButton
                          kind:completed ? PPCartActionButtonKindSuccess : PPCartActionButtonKindAccent
                       enabled:!hasPending && !completed];
    [GM setImageFromUrlString:item.imageURL imageView:self.itemImageView phImage:@"placeholder"];
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
    if (self.savedForLaterMode) return;

    BOOL canDecrease = self.currentItem.quantity > 1;
    BOOL stockIsKnown = self.currentItem.stockQuantity != NSNotFound;
    BOOL canIncrease = !stockIsKnown || self.currentItem.quantity < self.currentItem.stockQuantity;

    [self pp_styleActionButton:self.minusButton kind:PPCartActionButtonKindNeutral enabled:canDecrease];
    [self pp_styleActionButton:self.plusButton kind:PPCartActionButtonKindAccent enabled:canIncrease];
}

#pragma mark - Actions

- (void)didTapMinus
{
    if (self.savedForLaterMode) {
        [self pp_animateSavedForLaterActionFromButton:self.minusButton];
        if (self.onAction) {
            self.onAction(self.currentItem, @"removeSavedForLater");
        }
        return;
    }

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
    if (self.savedForLaterMode) {
        [self pp_animateSavedForLaterActionFromButton:self.plusButton];
        if (self.onAction) {
            self.onAction(self.currentItem, self.savedForLaterPrimaryActionName ?: @"moveSavedToCart");
        }
        return;
    }

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

- (void)didTapSavedRemoveButton
{
    if (!self.savedForLaterMode || !self.currentItem || !self.savedRemoveButton.userInteractionEnabled) {
        return;
    }
    [self pp_animateSavedForLaterActionFromButton:self.savedRemoveButton];
    if (self.onAction) {
        self.onAction(self.currentItem, @"removeSavedForLater");
    }
}

- (void)didTapSavedPrimaryButton
{
    if (!self.savedForLaterMode || !self.currentItem || !self.savedPrimaryButton.userInteractionEnabled) {
        return;
    }
    [self pp_animateSavedForLaterActionFromButton:self.savedPrimaryButton];
    if (self.onAction) {
        self.onAction(self.currentItem, self.savedForLaterPrimaryActionName ?: @"moveSavedToCart");
    }
}

#pragma mark - Helpers

- (UIButton *)pp_createIconButtonWithSystemName:(NSString *)iconName kind:(PPCartActionButtonKind)kind
{
    UIImage *image = [self pp_actionImageNamed:iconName];

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

- (UIImage *)pp_actionImageNamed:(NSString *)systemName
{
    UIImageSymbolConfiguration *configuration =
        [UIImageSymbolConfiguration configurationWithPointSize:13.0
                                                        weight:UIImageSymbolWeightSemibold];
    return [[UIImage systemImageNamed:systemName ?: @"circle"] imageByApplyingSymbolConfiguration:configuration];
}

- (void)pp_setActionButton:(UIButton *)button systemName:(NSString *)systemName
{
    if (!button) return;
    UIImage *image = [self pp_actionImageNamed:systemName];
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = button.configuration ?: [UIButtonConfiguration plainButtonConfiguration];
        config.image = image;
        button.configuration = config;
    } else {
        [button setImage:image forState:UIControlStateNormal];
    }
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
        case PPCartActionButtonKindDestructive:
            foregroundColor = UIColor.systemRedColor;
            backgroundColor = [UIColor.systemRedColor colorWithAlphaComponent:enabled ? 0.12 : 0.05];
            borderColor = [UIColor.systemRedColor colorWithAlphaComponent:enabled ? 0.18 : 0.07];
            break;
        case PPCartActionButtonKindSuccess:
            foregroundColor = UIColor.systemGreenColor;
            backgroundColor = [UIColor.systemGreenColor colorWithAlphaComponent:enabled ? 0.16 : 0.10];
            borderColor = [UIColor.systemGreenColor colorWithAlphaComponent:0.22];
            break;
        case PPCartActionButtonKindNeutral:
        default:
            foregroundColor = PPCartCellPrimaryTextColor();
            backgroundColor = PPCartCellSoftFillColor();
            borderColor = PPCartCellHairlineColor();
            break;
    }

    button.enabled = enabled;
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

- (void)pp_configureSavedActionButton:(UIButton *)button
                                title:(NSString *)title
                           systemName:(NSString *)systemName
                              primary:(BOOL)primary
                          destructive:(BOOL)destructive
                              enabled:(BOOL)enabled
{
    if (!button) return;
    (void)destructive;

    NSString *resolvedTitle = title.length > 0 ? title : @"";
    UIColor *savedAccentColor = PPCartCellDeferredAccentColor();
    UIColor *foregroundColor = primary ? UIColor.whiteColor : savedAccentColor;
    UIColor *backgroundColor = primary
        ? savedAccentColor
        : [savedAccentColor colorWithAlphaComponent:enabled ? 0.105 : 0.050];
    UIColor *borderColor = primary
        ? [UIColor.whiteColor colorWithAlphaComponent:0.17]
        : [savedAccentColor colorWithAlphaComponent:enabled ? 0.22 : 0.10];
    UIImage *image = [self pp_actionImageNamed:systemName];

    button.enabled = enabled;
    button.userInteractionEnabled = enabled;
    button.alpha = enabled ? 1.0 : 0.52;
    button.accessibilityLabel = resolvedTitle;
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.78;
    button.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *configuration = primary
            ? [UIButtonConfiguration filledButtonConfiguration]
            : [UIButtonConfiguration tintedButtonConfiguration];
        configuration.cornerStyle = UIButtonConfigurationCornerStyleFixed;
        configuration.baseForegroundColor = foregroundColor;
        configuration.background.backgroundColor = backgroundColor;
        configuration.background.cornerRadius = kPPCartSavedActionCornerRadius;
        configuration.background.strokeColor = borderColor;
        configuration.background.strokeWidth = 0.8;
        configuration.image = image;
        configuration.imagePadding = 6.0;
        configuration.imagePlacement = NSDirectionalRectEdgeLeading;
        configuration.contentInsets = NSDirectionalEdgeInsetsMake(7.0, primary ? 14.0 : 11.0, 7.0, primary ? 14.0 : 11.0);
        configuration.attributedTitle = [[NSAttributedString alloc]
            initWithString:resolvedTitle
                attributes:@{
                    NSFontAttributeName: [GM boldFontWithSize:12.5],
                    NSForegroundColorAttributeName: foregroundColor
                }];
        button.configuration = configuration;
    } else {
        [button setTitle:resolvedTitle forState:UIControlStateNormal];
        [button setTitleColor:foregroundColor forState:UIControlStateNormal];
        [button setImage:image forState:UIControlStateNormal];
        button.tintColor = foregroundColor;
        button.titleLabel.font = [GM boldFontWithSize:12.5];
        button.backgroundColor = backgroundColor;
        button.layer.cornerRadius = kPPCartSavedActionCornerRadius;
        button.layer.borderWidth = 0.8;
        [button pp_setBorderColor:borderColor];
        button.contentEdgeInsets = UIEdgeInsetsMake(7.0, primary ? 14.0 : 11.0, 7.0, primary ? 14.0 : 11.0);
        if (@available(iOS 13.0, *)) {
            button.layer.cornerCurve = kCACornerCurveContinuous;
        }
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
    CGFloat shadowOpacity = highlighted ? 0.04 : (self.savedForLaterMode ? (dark ? 0.075 : 0.028) : (dark ? 0.11 : 0.045));

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

- (void)pp_animateSavedForLaterActionFromButton:(UIButton *)button
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    UIView *targetButton = button ?: self.plusButton;
    self.savedActionsRow.transform = CGAffineTransformMakeScale(0.992, 0.992);
    targetButton.transform = CGAffineTransformMakeScale(0.94, 0.94);

    [UIView animateWithDuration:0.30
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.savedActionsRow.transform = CGAffineTransformIdentity;
        targetButton.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)playSavedForLaterArrivalAnimation
{
    [self playSavedForLaterArrivalAnimationWithCompletion:nil];
}

- (void)playSavedForLaterArrivalAnimationWithCompletion:(dispatch_block_t)completion
{
    NSUInteger animationToken = self.savedArrivalAnimationToken + 1;
    self.savedArrivalAnimationToken = animationToken;
    [self.cardContainer.layer removeAllAnimations];
    [self.savedStateTintView.layer removeAllAnimations];
    [self.accentRailView.layer removeAllAnimations];
    [self.itemImageView.layer removeAllAnimations];

    self.cardContainer.alpha = 0.0;
    self.cardContainer.transform = CGAffineTransformIdentity;
    self.savedStateTintView.alpha = 0.0;
    self.accentRailView.alpha = 1.0;
    self.accentRailView.transform = CGAffineTransformIdentity;
    self.itemImageView.alpha = 1.0;
    self.itemImageView.transform = CGAffineTransformIdentity;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:0.18
                              delay:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState |
                                    UIViewAnimationOptionCurveEaseOut |
                                    UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.cardContainer.alpha = 1.0;
        } completion:^(__unused BOOL finished) {
            if (self.savedArrivalAnimationToken != animationToken) {
                if (completion) completion();
                return;
            }
            if (completion) completion();
        }];
        return;
    }

    self.cardContainer.alpha = 0.08;
    self.cardContainer.transform =
        CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 10.0),
                                CGAffineTransformMakeScale(0.978, 0.978));
    self.savedStateTintView.backgroundColor = [PPCartCellAccentColor() colorWithAlphaComponent:0.10];
    self.savedStateTintView.alpha = 0.16;
    self.accentRailView.alpha = 0.22;
    self.accentRailView.transform = CGAffineTransformMakeScale(1.0, 0.18);
    self.itemImageView.alpha = 0.72;
    self.itemImageView.transform = CGAffineTransformMakeScale(1.035, 1.035);

    [UIView animateWithDuration:kPPCartSavedArrivalDuration
                          delay:0.0
         usingSpringWithDamping:0.93
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.cardContainer.alpha = 1.0;
        self.cardContainer.transform = CGAffineTransformIdentity;
        self.accentRailView.alpha = 1.0;
        self.accentRailView.transform = CGAffineTransformIdentity;
        self.itemImageView.alpha = 1.0;
        self.itemImageView.transform = CGAffineTransformIdentity;
    } completion:^(__unused BOOL finished) {
        if (self.savedArrivalAnimationToken != animationToken) {
            if (completion) completion();
            return;
        }
        self.cardContainer.alpha = 1.0;
        self.cardContainer.transform = CGAffineTransformIdentity;
        self.savedStateTintView.alpha = 0.0;
        self.accentRailView.alpha = 1.0;
        self.accentRailView.transform = CGAffineTransformIdentity;
        self.itemImageView.alpha = 1.0;
        self.itemImageView.transform = CGAffineTransformIdentity;
        if (completion) completion();
    }];

    [UIView animateWithDuration:0.34
                          delay:0.10
                        options:UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionCurveEaseOut |
                                UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.savedStateTintView.alpha = 0.0;
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
