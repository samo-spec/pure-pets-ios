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

static CGFloat const kPPCartCellOuterVerticalInset = 4.0;
static CGFloat const kPPCartCellOuterHorizontalInset = 16.0;
static CGFloat const kPPCartCellCardCornerRadius = 26.0;
static CGFloat const kPPCartCellImageShellWidth = 92.0;
static CGFloat const kPPCartCellStepperHeight = 40.0;

typedef NS_ENUM(NSInteger, PPCartActionButtonKind) {
    PPCartActionButtonKindNeutral = 0,
    PPCartActionButtonKindAccent = 1,
    PPCartActionButtonKindDestructive = 2,
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
@property (nonatomic, strong) UIButton *removeButton;

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
    cardContainer.layer.shadowColor = UIColor.blackColor.CGColor;
    cardContainer.layer.shadowOpacity = 0.11;
    cardContainer.layer.shadowOffset = CGSizeMake(0.0, 14.0);
    cardContainer.layer.shadowRadius = 24.0;
    cardContainer.layer.masksToBounds = NO;
    if (@available(iOS 13.0, *)) {
        cardContainer.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.contentView addSubview:cardContainer];
    self.cardContainer = cardContainer;

    UIView *surfaceView = [[UIView alloc] initWithFrame:CGRectZero];
    surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    surfaceView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.92] ?: [UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:0.92];
    surfaceView.layer.cornerRadius = kPPCartCellCardCornerRadius;
    surfaceView.layer.borderWidth = 0.8;
    surfaceView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.12].CGColor;
    surfaceView.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [cardContainer addSubview:surfaceView];
    self.surfaceView = surfaceView;

    UIView *topGlow = [[UIView alloc] initWithFrame:CGRectZero];
    topGlow.translatesAutoresizingMaskIntoConstraints = NO;
    topGlow.userInteractionEnabled = NO;
    topGlow.backgroundColor = [(AppPrimaryClr ?: UIColor.systemOrangeColor) colorWithAlphaComponent:0.07];
    topGlow.layer.cornerRadius = 78.0;
    topGlow.alpha = 0.38;
    [surfaceView addSubview:topGlow];

    UIView *bottomGlow = [[UIView alloc] initWithFrame:CGRectZero];
    bottomGlow.translatesAutoresizingMaskIntoConstraints = NO;
    bottomGlow.userInteractionEnabled = NO;
    bottomGlow.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.05];
    bottomGlow.layer.cornerRadius = 70.0;
    bottomGlow.alpha = 0.26;
    [surfaceView addSubview:bottomGlow];

    UIView *imageShellView = [[UIView alloc] initWithFrame:CGRectZero];
    imageShellView.translatesAutoresizingMaskIntoConstraints = NO;
    imageShellView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
    imageShellView.layer.cornerRadius = 24.0;
    imageShellView.layer.borderWidth = 0.8;
    imageShellView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.12].CGColor;
    imageShellView.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        imageShellView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [surfaceView addSubview:imageShellView];
    self.imageShellView = imageShellView;

    UIImageView *itemImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    itemImageView.translatesAutoresizingMaskIntoConstraints = NO;
    itemImageView.layer.cornerRadius = 20.0;
    itemImageView.clipsToBounds = YES;
    itemImageView.contentMode = UIViewContentModeScaleAspectFill;
    itemImageView.backgroundColor = UIColor.secondarySystemBackgroundColor;
    if (@available(iOS 13.0, *)) {
        itemImageView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [imageShellView addSubview:itemImageView];
    self.itemImageView = itemImageView;

    PPCartInsetLabel *eyebrowLabel = [self pp_buildCapsuleLabelWithFont:[GM MidFontWithSize:10.5]
                                                              textColor:AppPrimaryClr ?: UIColor.labelColor
                                                        backgroundColor:[(AppPrimaryClr ?: UIColor.systemOrangeColor) colorWithAlphaComponent:0.12]
                                                            borderColor:[(AppPrimaryClr ?: UIColor.systemOrangeColor) colorWithAlphaComponent:0.18]];
    eyebrowLabel.textInsets = UIEdgeInsetsMake(5.0, 10.0, 5.0, 10.0);
    eyebrowLabel.adjustsFontSizeToFitWidth = YES;
    eyebrowLabel.minimumScaleFactor = 0.80;
    self.eyebrowLabel = eyebrowLabel;

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.font = [GM boldFontWithSize:17.0];
    nameLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    nameLabel.numberOfLines = 2;
    nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    nameLabel.textAlignment = NSTextAlignmentNatural;
    [nameLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                               forAxis:UILayoutConstraintAxisVertical];
    self.nameLabel = nameLabel;

    UILabel *priceLabel = [[UILabel alloc] init];
    priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    priceLabel.font = [GM boldFontWithSize:18.0];
    priceLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    priceLabel.numberOfLines = 1;
    priceLabel.textAlignment = NSTextAlignmentNatural;
    [priceLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                forAxis:UILayoutConstraintAxisHorizontal];
    self.priceLabel = priceLabel;

    UILabel *originalPriceLabel = [[UILabel alloc] init];
    originalPriceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    originalPriceLabel.font = [GM fontWithSize:12.5];
    originalPriceLabel.textColor = [UIColor.labelColor colorWithAlphaComponent:0.36];
    originalPriceLabel.numberOfLines = 1;
    originalPriceLabel.textAlignment = NSTextAlignmentNatural;
    originalPriceLabel.hidden = YES;
    self.originalPriceLabel = originalPriceLabel;

    PPCartInsetLabel *savingsPillLabel = [self pp_buildCapsuleLabelWithFont:[GM boldFontWithSize:11.0]
                                                                  textColor:[UIColor systemRedColor]
                                                            backgroundColor:[[UIColor systemRedColor] colorWithAlphaComponent:0.10]
                                                                borderColor:[[UIColor systemRedColor] colorWithAlphaComponent:0.12]];
    savingsPillLabel.textInsets = UIEdgeInsetsMake(5.0, 9.0, 5.0, 9.0);
    savingsPillLabel.hidden = YES;
    savingsPillLabel.textAlignment = NSTextAlignmentCenter;
    savingsPillLabel.numberOfLines = 1;
    self.savingsPillLabel = savingsPillLabel;

    [imageShellView addSubview:eyebrowLabel];

    UIButton *removeButton = [self pp_createIconButtonWithSystemName:@"trash" kind:PPCartActionButtonKindDestructive];
    [removeButton addTarget:self action:@selector(didTapRemove) forControlEvents:UIControlEventTouchUpInside];
    [self pp_applyPressTargetsToButton:removeButton];
    self.removeButton = removeButton;

    UIView *headerSpacer = [[UIView alloc] initWithFrame:CGRectZero];
    headerSpacer.translatesAutoresizingMaskIntoConstraints = NO;
    [headerSpacer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [headerSpacer setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    UIStackView *headerRow = [[UIStackView alloc] initWithArrangedSubviews:@[
        nameLabel,
        headerSpacer,
        removeButton
    ]];
    headerRow.translatesAutoresizingMaskIntoConstraints = NO;
    headerRow.axis = UILayoutConstraintAxisHorizontal;
    headerRow.alignment = UIStackViewAlignmentTop;
    headerRow.spacing = 10.0;

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
                                                                   textColor:[UIColor.labelColor colorWithAlphaComponent:0.78]
                                                             backgroundColor:[UIColor colorWithWhite:1.0 alpha:0.15]
                                                                 borderColor:[UIColor colorWithWhite:1.0 alpha:0.12]];
    subtotalPillLabel.textInsets = UIEdgeInsetsMake(7.0, 10.0, 7.0, 10.0);
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
    quantityLabel.font = [GM boldFontWithSize:15.5];
    quantityLabel.textAlignment = NSTextAlignmentCenter;
    quantityLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
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
    stepperPillView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
    stepperPillView.layer.cornerRadius = 21.0;
    stepperPillView.layer.borderWidth = 0.8;
    stepperPillView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.12].CGColor;
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
    stepperStack.spacing = 8.0;
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
    bottomRow.spacing = 10.0;

    UIStackView *contentStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        headerRow,
        priceRow,
        bottomRow
    ]];
    contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    contentStack.axis = UILayoutConstraintAxisVertical;
    contentStack.alignment = UIStackViewAlignmentFill;
    contentStack.spacing = 6.0;
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

        [removeButton.widthAnchor constraintEqualToConstant:28.0],
        [removeButton.heightAnchor constraintEqualToConstant:28.0],

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

    self.removeButton.accessibilityLabel = NSLocalizedString(@"a11y_btn_remove_cart_item", @"Remove item");
    self.removeButton.accessibilityHint = NSLocalizedString(@"a11y_btn_remove_cart_item_hint", @"Double-tap to remove this item from your cart");
    self.minusButton.accessibilityLabel = NSLocalizedString(@"a11y_btn_decrease_qty", @"Decrease quantity");
    self.plusButton.accessibilityLabel = NSLocalizedString(@"a11y_btn_increase_qty", @"Increase quantity");

    [self pp_styleActionButton:self.minusButton kind:PPCartActionButtonKindNeutral enabled:YES];
    [self pp_styleActionButton:self.plusButton kind:PPCartActionButtonKindAccent enabled:YES];
    [self pp_styleActionButton:self.removeButton kind:PPCartActionButtonKindDestructive enabled:YES];
}

- (PPCartInsetLabel *)pp_buildCapsuleLabelWithFont:(UIFont *)font
                                         textColor:(UIColor *)textColor
                                   backgroundColor:(UIColor *)backgroundColor
                                       borderColor:(UIColor *)borderColor
{
    PPCartInsetLabel *label = [[PPCartInsetLabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = font;
    label.textColor = textColor;
    label.backgroundColor = backgroundColor;
    label.layer.cornerRadius = 14.0;
    label.layer.borderWidth = 0.8;
    label.layer.borderColor = borderColor.CGColor;
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

    self.minusButton.transform = CGAffineTransformIdentity;
    self.plusButton.transform = CGAffineTransformIdentity;
    self.removeButton.transform = CGAffineTransformIdentity;
    self.minusButton.alpha = 1.0;
    self.plusButton.alpha = 1.0;
    self.removeButton.alpha = 1.0;

    [self pp_styleActionButton:self.minusButton kind:PPCartActionButtonKindNeutral enabled:YES];
    [self pp_styleActionButton:self.plusButton kind:PPCartActionButtonKindAccent enabled:YES];
    [self pp_styleActionButton:self.removeButton kind:PPCartActionButtonKindDestructive enabled:YES];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    if (!CGRectIsEmpty(self.cardContainer.bounds)) {
        self.cardContainer.layer.shadowPath =
            [UIBezierPath bezierPathWithRoundedRect:self.cardContainer.bounds
                                      cornerRadius:self.cardContainer.layer.cornerRadius].CGPath;
    }
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
            NSForegroundColorAttributeName: [UIColor.labelColor colorWithAlphaComponent:0.38],
            NSFontAttributeName: self.originalPriceLabel.font
        };
        self.originalPriceLabel.attributedText = [[NSAttributedString alloc] initWithString:originalText
                                                                                 attributes:attributes];
        self.originalPriceLabel.hidden = NO;
        self.savingsPillLabel.text = [NSString stringWithFormat:@"-%@",
                                      [PPChatsFunc formattedCurrency:item.discountPerUnit]];
        self.savingsPillLabel.hidden = NO;
        self.subtotalPillLabel.backgroundColor = [(AppPrimaryClr ?: UIColor.systemOrangeColor) colorWithAlphaComponent:0.16];
        self.subtotalPillLabel.layer.borderColor = [(AppPrimaryClr ?: UIColor.systemOrangeColor) colorWithAlphaComponent:0.18].CGColor;
        self.subtotalPillLabel.textColor = AppPrimaryClr ?: UIColor.labelColor;
    } else {
        self.originalPriceLabel.attributedText = nil;
        self.originalPriceLabel.hidden = YES;
        self.savingsPillLabel.text = @"";
        self.savingsPillLabel.hidden = YES;
        self.subtotalPillLabel.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
        self.subtotalPillLabel.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.12].CGColor;
        self.subtotalPillLabel.textColor = [UIColor.labelColor colorWithAlphaComponent:0.78];
    }

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
    [self pp_styleActionButton:self.removeButton kind:PPCartActionButtonKindDestructive enabled:YES];
}

#pragma mark - Actions

- (void)didTapMinus
{
    if (!self.currentItem || self.currentItem.quantity <= 1) return;

    DLog(@"Minus tapped for %@", self.currentItem.name);
    self.currentItem.quantity -= 1;
    [self pp_refreshContentForCurrentItem];
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
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventCartQuantityChanged];

    if (self.onAction) {
        self.onAction(self.currentItem, @"plus");
    }
}

- (void)didTapRemove
{
    if (!self.currentItem) return;

    DLog(@"Remove tapped for %@", self.currentItem.name);
    if (self.onAction) {
        self.onAction(self.currentItem, @"remove");
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

    UIColor *foregroundColor = AppPrimaryTextClr ?: UIColor.labelColor;
    UIColor *backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
    UIColor *borderColor = [UIColor colorWithWhite:1.0 alpha:0.12];

    switch (kind) {
        case PPCartActionButtonKindAccent:
            foregroundColor = AppPrimaryClr ?: UIColor.labelColor;
            backgroundColor = [(AppPrimaryClr ?: UIColor.systemOrangeColor) colorWithAlphaComponent:enabled ? 0.15 : 0.06];
            borderColor = [(AppPrimaryClr ?: UIColor.systemOrangeColor) colorWithAlphaComponent:enabled ? 0.20 : 0.08];
            break;
        case PPCartActionButtonKindDestructive:
            foregroundColor = UIColor.systemRedColor;
            backgroundColor = [UIColor.systemRedColor colorWithAlphaComponent:enabled ? 0.12 : 0.05];
            borderColor = [UIColor.systemRedColor colorWithAlphaComponent:enabled ? 0.14 : 0.08];
            break;
        case PPCartActionButtonKindNeutral:
        default:
            foregroundColor = AppPrimaryTextClr ?: UIColor.labelColor;
            backgroundColor = [UIColor colorWithWhite:1.0 alpha:enabled ? 0.10 : 0.05];
            borderColor = [UIColor colorWithWhite:1.0 alpha:enabled ? 0.12 : 0.06];
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
        button.layer.borderColor = borderColor.CGColor;
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
    CGFloat scale = highlighted ? 0.985 : 1.0;
    CGFloat alpha = highlighted ? 0.97 : 1.0;
    CGFloat shadowOpacity = highlighted ? 0.07 : 0.11;

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

@end
