//
//  PPHomeOrderStatusCell 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/3/26.
//
#import "PPHomeOrderStatusCell.h"

@interface PPHomeOrderStatusCell ()
@property (nonatomic, strong) UIView *shadowView;
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIVisualEffectView *materialView;
@property (nonatomic, strong) UIView *overlayView;
@property (nonatomic, strong) CAGradientLayer *overlayGradientLayer;
@property (nonatomic, strong) UIView *chipView;
@property (nonatomic, strong) UIImageView *chipIconView;
@property (nonatomic, strong) UILabel *chipLabel;
@property (nonatomic, strong) UILabel *orderKickerLabel;
@property (nonatomic, strong) UILabel *orderLabel;
@property (nonatomic, strong) UILabel *metaLabel;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, strong) UIView *progressTrackView;
@property (nonatomic, strong) UIView *progressFillView;
@property (nonatomic, strong) NSLayoutConstraint *progressFillWidthConstraint;
@property (nonatomic, strong) UILabel *footerLabel;
@property (nonatomic, strong) UIView *actionRailView;
@property (nonatomic, strong) UIStackView *actionsStackView;
@property (nonatomic, strong) UIButton *trackButton;
@property (nonatomic, strong) UIButton *historyButton;
@property (nonatomic, strong) UIView *collapsedContentView;
@property (nonatomic, strong) UIView *collapsedIconBadgeView;
@property (nonatomic, strong) UIImageView *collapsedIconView;
@property (nonatomic, copy) NSArray<NSString *> *previewImageURLs;
@property (nonatomic, copy) NSArray<UIImageView *> *collapsedPreviewImageViews;
@property (nonatomic, strong) UIStackView *collapsedTextStackView;
@property (nonatomic, strong) UILabel *collapsedKickerLabel;
@property (nonatomic, strong) UILabel *collapsedOrderLabel;
@property (nonatomic, strong) UILabel *collapsedSummaryLabel;
@property (nonatomic, strong) UIView *collapsedStatusPillView;
@property (nonatomic, strong) UILabel *collapsedStatusPillLabel;
@property (nonatomic, strong) UIView *collapsedChevronContainerView;
@property (nonatomic, strong) UIVisualEffectView *collapsedChevronMaterialView;
@property (nonatomic, strong) UIView *collapsedChevronTintView;
@property (nonatomic, strong) UIImageView *collapsedChevronView;
@property (nonatomic, strong) NSLayoutConstraint *collapsedChevronTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *collapsedChevronCenterYConstraint;
@property (nonatomic, copy) NSArray<NSLayoutConstraint *> *expandedConstraints;
@property (nonatomic, copy) NSArray<NSLayoutConstraint *> *collapsedConstraints;
@property (nonatomic, strong) UIColor *currentStatusColor;
@property (nonatomic, assign) BOOL showsExpandedState;
@end

static inline UIColor *PPHomeOrderBlendColor(UIColor *baseColor, UIColor *fallbackColor, CGFloat alpha)
{
    UIColor *resolved = baseColor ?: fallbackColor ?: UIColor.systemBlueColor;
    return [resolved colorWithAlphaComponent:alpha];
}

static BOOL PPHomeOrderStatusTextContainsAnyKeyword(NSString *text, NSArray<NSString *> *keywords)
{
    NSString *normalizedText = [[text ?: @"" lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (normalizedText.length == 0 || keywords.count == 0) {
        return NO;
    }

    for (NSString *keyword in keywords) {
        NSString *candidate = [[keyword ?: @"" lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (candidate.length == 0) {
            continue;
        }
        if ([normalizedText containsString:candidate]) {
            return YES;
        }
    }

    return NO;
}

static UIColor *PPHomeOrderProcessingAccentColor(void)
{
    if (@available(iOS 13.0, *)) {
        return UIColor.systemIndigoColor;
    }
    return [UIColor colorWithRed:0.35 green:0.45 blue:0.94 alpha:1.0];
}

static UIColor *PPHomeOrderResolvedStatusColor(UIColor *fallbackColor,
                                               NSString *statusTitle,
                                               NSString *statusHint,
                                               NSString *statusIconName)
{
    if (fallbackColor) {
        return fallbackColor;
    }

    NSString *iconName = [[statusIconName ?: @"" lowercaseString] copy];
    NSString *combinedText = [NSString stringWithFormat:@"%@ %@", statusTitle ?: @"", statusHint ?: @""];

    if ([iconName containsString:@"xmark"] ||
        PPHomeOrderStatusTextContainsAnyKeyword(combinedText, @[@"failed", @"cancel", @"declined", @"rejected", @"voided", @"ملغي", @"مرفوض", @"فشل"])) {
        return UIColor.systemRedColor;
    }

    if ([iconName containsString:@"checkmark"] ||
        PPHomeOrderStatusTextContainsAnyKeyword(combinedText, @[@"delivered", @"completed", @"fulfilled", @"تم التسليم", @"مكتمل"])) {
        return UIColor.systemGreenColor;
    }

    if ([iconName containsString:@"shippedtruck"] ||
        PPHomeOrderStatusTextContainsAnyKeyword(combinedText, @[@"shipped", @"shipping", @"transit", @"out for delivery", @"out_for_delivery", @"في الطريق", @"تم الشحن"])) {
        return UIColor.systemBlueColor;
    }

    if ([iconName containsString:@"shippingbox"] ||
        PPHomeOrderStatusTextContainsAnyKeyword(combinedText, @[@"processing", @"preparing", @"packed", @"confirmed", @"قيد المعالجة", @"التجهيز", @"جاري تجهيز", @"تم التأكيد"])) {
        return PPHomeOrderProcessingAccentColor();
    }

    if ([iconName containsString:@"creditcard"] ||
        PPHomeOrderStatusTextContainsAnyKeyword(combinedText, @[@"paid", @"payment", @"approved", @"captured", @"authorized", @"مدفوع", @"تم الدفع"])) {
        return fallbackColor ?: AppPrimaryClr ?: UIColor.systemBlueColor;
    }

    if ([iconName containsString:@"clock"] ||
        PPHomeOrderStatusTextContainsAnyKeyword(combinedText, @[@"pending", @"waiting", @"بانتظار", @"قيد الانتظار"])) {
        return UIColor.systemOrangeColor;
    }

    return fallbackColor ?: UIColor.systemBlueColor;
}


@implementation PPHomeOrderStatusCell

+ (NSString *)reuseIdentifier
{
    return @"PPHomeOrderStatusCell";
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;

    [self pp_setupUI];
    return self;
}

- (void)pp_setupUI
{
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.clipsToBounds = NO;
    self.layer.zPosition = 120.0;
    self.contentView.layer.zPosition = 120.0;

    self.shadowView = [[UIView alloc] init];
    self.shadowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.shadowView.backgroundColor = UIColor.clearColor;
    [self.shadowView pp_setShadowColor:UIColor.blackColor];
    self.shadowView.layer.shadowOpacity = 0.08;
    self.shadowView.layer.shadowRadius = 18.0;
    self.shadowView.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    self.shadowView.layer.cornerRadius = PPNewCorner;
    if (@available(iOS 13.0, *)) {
        self.shadowView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.contentView addSubview:self.shadowView];

    self.surfaceView = [[UIView alloc] init];
    self.surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.surfaceView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:(PPIOS26() ? 0.20 : 0.98)];
    self.surfaceView.layer.cornerRadius = PPNewCorner;
    self.surfaceView.layer.borderWidth = 1.0;
    [self.surfaceView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:(PPIOS26() ? 0.20 : 0.16)]];
    self.surfaceView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.shadowView addSubview:self.surfaceView];

    UIBlurEffectStyle blurStyle = UIBlurEffectStyleSystemThinMaterial;
    self.materialView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:blurStyle]];
    self.materialView.translatesAutoresizingMaskIntoConstraints = NO;
    self.materialView.userInteractionEnabled = NO;
    self.materialView.alpha = PPIOS26() ? 0.68 : 0.96;
    [self.surfaceView addSubview:self.materialView];

    self.overlayView = [[UIView alloc] init];
    self.overlayView.translatesAutoresizingMaskIntoConstraints = NO;
    self.overlayView.userInteractionEnabled = NO;
    self.overlayView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.85];
    self.overlayView.layer.masksToBounds = YES;
    [self.surfaceView addSubview:self.overlayView];

    self.overlayGradientLayer = [CAGradientLayer layer];
    self.overlayGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    self.overlayGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    self.overlayGradientLayer.locations = @[@0.0, @0.38, @1.0];
    self.overlayGradientLayer.needsDisplayOnBoundsChange = YES;
    [self.overlayView.layer addSublayer:self.overlayGradientLayer];

    self.chipView = [[UIView alloc] init];
    self.chipView.translatesAutoresizingMaskIntoConstraints = NO;
    self.chipView.layer.cornerRadius = 14.0;
    self.chipView.layer.masksToBounds = YES;
    [self.surfaceView addSubview:self.chipView];

    self.chipIconView = [[UIImageView alloc] init];
    self.chipIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.chipIconView.contentMode = UIViewContentModeScaleToFill;
    [self.chipView addSubview:self.chipIconView];

    self.chipLabel = [[UILabel alloc] init];
    self.chipLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.chipLabel.font = [GM boldFontWithSize:12] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    self.chipLabel.textAlignment = [Language alignmentForCurrentLanguage];
    [self.chipView addSubview:self.chipLabel];

    self.orderKickerLabel = [[UILabel alloc] init];
    self.orderKickerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.orderKickerLabel.font = [GM MidFontWithSize:10.5] ?: [UIFont systemFontOfSize:10.5 weight:UIFontWeightSemibold];
    self.orderKickerLabel.textColor = UIColor.secondaryLabelColor;
    self.orderKickerLabel.numberOfLines = 1;
    self.orderKickerLabel.textAlignment = [Language alignmentForCurrentLanguage];
    [self.surfaceView addSubview:self.orderKickerLabel];

    self.orderLabel = [[UILabel alloc] init];
    self.orderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.orderLabel.font = [GM boldFontWithSize:21] ?: [UIFont systemFontOfSize:21.0 weight:UIFontWeightBold];
    self.orderLabel.textColor = UIColor.labelColor;
    self.orderLabel.numberOfLines = 1;
    self.orderLabel.textAlignment = [Language alignmentForCurrentLanguage];
    [self.surfaceView addSubview:self.orderLabel];

    self.metaLabel = [[UILabel alloc] init];
    self.metaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.metaLabel.font = [GM MidFontWithSize:11.5] ?: [UIFont systemFontOfSize:11.5 weight:UIFontWeightMedium];
    self.metaLabel.textColor = UIColor.secondaryLabelColor;
    self.metaLabel.numberOfLines = 1;
    self.metaLabel.textAlignment = [Language alignmentForCurrentLanguage];
    [self.surfaceView addSubview:self.metaLabel];

    self.hintLabel = [[UILabel alloc] init];
    self.hintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.hintLabel.font = [GM MidFontWithSize:14] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    self.hintLabel.textColor = UIColor.labelColor;
    self.hintLabel.numberOfLines = 2;
    self.hintLabel.textAlignment = [Language alignmentForCurrentLanguage];
    [self.surfaceView addSubview:self.hintLabel];

    self.progressTrackView = [[UIView alloc] init];
    self.progressTrackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressTrackView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:(PPIOS26() ? 0.16 : 0.38)];
    self.progressTrackView.layer.cornerRadius = 4.0;
    self.progressTrackView.layer.masksToBounds = YES;
    [self.surfaceView addSubview:self.progressTrackView];

    self.progressFillView = [[UIView alloc] init];
    self.progressFillView.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressFillView.layer.cornerRadius = 4.0;
    self.progressFillView.layer.masksToBounds = YES;
    [self.progressTrackView addSubview:self.progressFillView];

    self.footerLabel = [[UILabel alloc] init];
    self.footerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.footerLabel.font = [GM MidFontWithSize:11] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    self.footerLabel.textColor = UIColor.tertiaryLabelColor;
    self.footerLabel.numberOfLines = 1;
    self.footerLabel.textAlignment = [Language alignmentForCurrentLanguage];
    [self.surfaceView addSubview:self.footerLabel];

    self.actionRailView = [[UIView alloc] init];
    self.actionRailView.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionRailView.layer.cornerRadius = PPCornerMedium;
    self.actionRailView.layer.borderWidth = 1.0;
    self.actionRailView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.actionRailView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.surfaceView addSubview:self.actionRailView];

    self.actionsStackView = [[UIStackView alloc] init];
    self.actionsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionsStackView.axis = UILayoutConstraintAxisHorizontal;
    self.actionsStackView.alignment = UIStackViewAlignmentFill;
    self.actionsStackView.distribution = UIStackViewDistributionFillEqually;
    self.actionsStackView.spacing = 8.0;
    [self.actionRailView addSubview:self.actionsStackView];

    self.trackButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.trackButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.trackButton.layer.cornerRadius = 17.0;
    self.trackButton.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.trackButton.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.trackButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.trackButton.titleLabel.minimumScaleFactor = 0.82;
    [self.trackButton addTarget:self action:@selector(pp_handleTrackTap) forControlEvents:UIControlEventTouchUpInside];
    [self.actionsStackView addArrangedSubview:self.trackButton];

    self.historyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.historyButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.historyButton.layer.cornerRadius = 17.0;
    self.historyButton.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.historyButton.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.historyButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.historyButton.titleLabel.minimumScaleFactor = 0.82;
    [self.historyButton addTarget:self action:@selector(pp_handleHistoryTap) forControlEvents:UIControlEventTouchUpInside];
    [self.actionsStackView addArrangedSubview:self.historyButton];

    self.collapsedContentView = [[UIView alloc] init];
    self.collapsedContentView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collapsedContentView.backgroundColor = UIColor.clearColor;
    [self.surfaceView addSubview:self.collapsedContentView];

    self.collapsedIconBadgeView = [[UIView alloc] init];
    self.collapsedIconBadgeView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collapsedIconBadgeView.layer.cornerRadius = 14.0;
    self.collapsedIconBadgeView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.collapsedIconBadgeView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.collapsedContentView addSubview:self.collapsedIconBadgeView];

    self.collapsedIconView = [[UIImageView alloc] init];
    self.collapsedIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collapsedIconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.collapsedIconBadgeView addSubview:self.collapsedIconView];

    NSMutableArray<UIImageView *> *collapsedPreviewImageViews = [NSMutableArray array];
    for (NSInteger index = 0; index < 3; index++) {
        UIImageView *previewImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        previewImageView.translatesAutoresizingMaskIntoConstraints = YES;
        previewImageView.contentMode = UIViewContentModeScaleAspectFill;
        previewImageView.clipsToBounds = YES;
        previewImageView.layer.masksToBounds = YES;
        previewImageView.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
        if (@available(iOS 13.0, *)) {
            previewImageView.layer.cornerCurve = kCACornerCurveContinuous;
        }
        previewImageView.hidden = YES;
        [self.collapsedIconBadgeView addSubview:previewImageView];
        [collapsedPreviewImageViews addObject:previewImageView];
    }
    self.collapsedPreviewImageViews = collapsedPreviewImageViews.copy;

    self.collapsedTextStackView = [[UIStackView alloc] init];
    self.collapsedTextStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collapsedTextStackView.axis = UILayoutConstraintAxisVertical;
    self.collapsedTextStackView.alignment = UIStackViewAlignmentFill;
    self.collapsedTextStackView.distribution = UIStackViewDistributionFill;
    self.collapsedTextStackView.spacing = 3.0;
    [self.collapsedContentView addSubview:self.collapsedTextStackView];

    self.collapsedKickerLabel = [[UILabel alloc] init];
    self.collapsedKickerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.collapsedKickerLabel.font = [GM MidFontWithSize:10] ?: [UIFont systemFontOfSize:10.0 weight:UIFontWeightSemibold];
    self.collapsedKickerLabel.textColor = UIColor.tertiaryLabelColor;
    self.collapsedKickerLabel.numberOfLines = 1;
    self.collapsedKickerLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.collapsedKickerLabel.textAlignment = [Language alignmentForCurrentLanguage];
    [self.collapsedTextStackView addArrangedSubview:self.collapsedKickerLabel];

    self.collapsedOrderLabel = [[UILabel alloc] init];
    self.collapsedOrderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.collapsedOrderLabel.font = [GM boldFontWithSize:16] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    self.collapsedOrderLabel.textColor = UIColor.labelColor;
    self.collapsedOrderLabel.numberOfLines = 1;
    self.collapsedOrderLabel.textAlignment = [Language alignmentForCurrentLanguage];
    [self.collapsedTextStackView addArrangedSubview:self.collapsedOrderLabel];

    self.collapsedSummaryLabel = [[UILabel alloc] init];
    self.collapsedSummaryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.collapsedSummaryLabel.font = [GM MidFontWithSize:12] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    self.collapsedSummaryLabel.textColor = UIColor.secondaryLabelColor;
    self.collapsedSummaryLabel.numberOfLines = 1;
    self.collapsedSummaryLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.collapsedSummaryLabel.textAlignment = [Language alignmentForCurrentLanguage];
    [self.collapsedTextStackView addArrangedSubview:self.collapsedSummaryLabel];

    self.collapsedStatusPillView = [[UIView alloc] init];
    self.collapsedStatusPillView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collapsedStatusPillView.layer.cornerRadius = 14.0;
    self.collapsedStatusPillView.layer.masksToBounds = YES;
    [self.collapsedContentView addSubview:self.collapsedStatusPillView];

    self.collapsedStatusPillLabel = [[UILabel alloc] init];
    self.collapsedStatusPillLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.collapsedStatusPillLabel.font = [GM boldFontWithSize:11] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    self.collapsedStatusPillLabel.textAlignment = NSTextAlignmentCenter;
    [self.collapsedStatusPillView addSubview:self.collapsedStatusPillLabel];

    self.collapsedChevronContainerView = [[UIView alloc] init];
    self.collapsedChevronContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collapsedChevronContainerView.layer.cornerRadius = 17.0;
    self.collapsedChevronContainerView.layer.borderWidth = 1.0;
    self.collapsedChevronContainerView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.collapsedChevronContainerView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.surfaceView addSubview:self.collapsedChevronContainerView];

    UIBlurEffectStyle chevronBlurStyle = UIBlurEffectStyleSystemThinMaterial;
    if (@available(iOS 13.0, *)) {
        chevronBlurStyle = UIBlurEffectStyleSystemChromeMaterial;
    }
    self.collapsedChevronMaterialView =
        [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:chevronBlurStyle]];
    self.collapsedChevronMaterialView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collapsedChevronMaterialView.userInteractionEnabled = NO;
    [self.collapsedChevronContainerView addSubview:self.collapsedChevronMaterialView];

    self.collapsedChevronTintView = [[UIView alloc] init];
    self.collapsedChevronTintView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collapsedChevronTintView.userInteractionEnabled = NO;
    [self.collapsedChevronContainerView addSubview:self.collapsedChevronTintView];

    self.collapsedChevronView = [[UIImageView alloc] init];
    self.collapsedChevronView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collapsedChevronView.contentMode = UIViewContentModeScaleAspectFit;
    self.collapsedChevronView.tintColor = UIColor.labelColor;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *chevronConfig =
            [UIImageSymbolConfiguration configurationWithPointSize:11.0
                                                            weight:UIImageSymbolWeightBold
                                                             scale:UIImageSymbolScaleMedium];
        self.collapsedChevronView.preferredSymbolConfiguration = chevronConfig;
    }
    self.collapsedChevronView.image = [UIImage systemImageNamed:@"chevron.down"];
    [self.collapsedChevronContainerView addSubview:self.collapsedChevronView];
    self.collapsedChevronContainerView.userInteractionEnabled = YES;
    UITapGestureRecognizer *collapseTapGesture =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_handleCollapseTap)];
    collapseTapGesture.cancelsTouchesInView = YES;
    [self.collapsedChevronContainerView addGestureRecognizer:collapseTapGesture];

    self.progressFillWidthConstraint = [self.progressFillView.widthAnchor constraintEqualToConstant:0.0];
    self.collapsedChevronTopConstraint =
        [self.collapsedChevronContainerView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor constant:14.0];
    self.collapsedChevronCenterYConstraint =
        [self.collapsedChevronContainerView.centerYAnchor constraintEqualToAnchor:self.collapsedContentView.centerYAnchor];

    [NSLayoutConstraint activateConstraints:@[
        [self.shadowView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.shadowView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.shadowView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.shadowView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        [self.surfaceView.topAnchor constraintEqualToAnchor:self.shadowView.topAnchor],
        [self.surfaceView.leadingAnchor constraintEqualToAnchor:self.shadowView.leadingAnchor],
        [self.surfaceView.trailingAnchor constraintEqualToAnchor:self.shadowView.trailingAnchor],
        [self.surfaceView.bottomAnchor constraintEqualToAnchor:self.shadowView.bottomAnchor],
        [self.materialView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor],
        [self.materialView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor],
        [self.materialView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor],
        [self.materialView.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor],
        [self.overlayView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor],
        [self.overlayView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor],
        [self.overlayView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor],
        [self.overlayView.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor],
        [self.collapsedChevronContainerView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-14.0],
        [self.collapsedChevronContainerView.widthAnchor constraintEqualToConstant:34.0],
        [self.collapsedChevronContainerView.heightAnchor constraintEqualToConstant:34.0],
        [self.collapsedChevronMaterialView.topAnchor constraintEqualToAnchor:self.collapsedChevronContainerView.topAnchor],
        [self.collapsedChevronMaterialView.leadingAnchor constraintEqualToAnchor:self.collapsedChevronContainerView.leadingAnchor],
        [self.collapsedChevronMaterialView.trailingAnchor constraintEqualToAnchor:self.collapsedChevronContainerView.trailingAnchor],
        [self.collapsedChevronMaterialView.bottomAnchor constraintEqualToAnchor:self.collapsedChevronContainerView.bottomAnchor],
        [self.collapsedChevronTintView.topAnchor constraintEqualToAnchor:self.collapsedChevronContainerView.topAnchor],
        [self.collapsedChevronTintView.leadingAnchor constraintEqualToAnchor:self.collapsedChevronContainerView.leadingAnchor],
        [self.collapsedChevronTintView.trailingAnchor constraintEqualToAnchor:self.collapsedChevronContainerView.trailingAnchor],
        [self.collapsedChevronTintView.bottomAnchor constraintEqualToAnchor:self.collapsedChevronContainerView.bottomAnchor],
        [self.collapsedChevronView.centerXAnchor constraintEqualToAnchor:self.collapsedChevronContainerView.centerXAnchor],
        [self.collapsedChevronView.centerYAnchor constraintEqualToAnchor:self.collapsedChevronContainerView.centerYAnchor],
        [self.collapsedChevronView.widthAnchor constraintEqualToConstant:12.0],
        [self.collapsedChevronView.heightAnchor constraintEqualToConstant:12.0],
    ]];

    self.expandedConstraints = @[
        [self.chipView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor constant:16.0],
        [self.chipView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:18.0],
        [self.chipView.heightAnchor constraintEqualToConstant:30.0],
        [self.chipView.trailingAnchor constraintLessThanOrEqualToAnchor:self.collapsedChevronContainerView.leadingAnchor constant:-12.0],
        [self.chipIconView.leadingAnchor constraintEqualToAnchor:self.chipView.leadingAnchor constant:10.0],
        [self.chipIconView.centerYAnchor constraintEqualToAnchor:self.chipView.centerYAnchor],
        [self.chipIconView.widthAnchor constraintEqualToConstant:16.0],
        [self.chipIconView.heightAnchor constraintEqualToConstant:16.0],
        [self.chipLabel.leadingAnchor constraintEqualToAnchor:self.chipIconView.trailingAnchor constant:6.0],
        [self.chipLabel.trailingAnchor constraintEqualToAnchor:self.chipView.trailingAnchor constant:-12.0],
        [self.chipLabel.centerYAnchor constraintEqualToAnchor:self.chipView.centerYAnchor],
        [self.orderKickerLabel.topAnchor constraintEqualToAnchor:self.chipView.bottomAnchor constant:12.0],
        [self.orderKickerLabel.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:18.0],
        [self.orderKickerLabel.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-18.0],
        [self.orderLabel.topAnchor constraintEqualToAnchor:self.orderKickerLabel.bottomAnchor constant:2.0],
        [self.orderLabel.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:18.0],
        [self.orderLabel.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-18.0],
        [self.metaLabel.topAnchor constraintEqualToAnchor:self.orderLabel.bottomAnchor constant:4.0],
        [self.metaLabel.leadingAnchor constraintEqualToAnchor:self.orderLabel.leadingAnchor],
        [self.metaLabel.trailingAnchor constraintEqualToAnchor:self.orderLabel.trailingAnchor],
        [self.hintLabel.topAnchor constraintEqualToAnchor:self.metaLabel.bottomAnchor constant:8.0],
        [self.hintLabel.leadingAnchor constraintEqualToAnchor:self.orderLabel.leadingAnchor],
        [self.hintLabel.trailingAnchor constraintEqualToAnchor:self.orderLabel.trailingAnchor],
        [self.progressTrackView.topAnchor constraintEqualToAnchor:self.hintLabel.bottomAnchor constant:12.0],
        [self.progressTrackView.leadingAnchor constraintEqualToAnchor:self.orderLabel.leadingAnchor],
        [self.progressTrackView.trailingAnchor constraintEqualToAnchor:self.orderLabel.trailingAnchor],
        [self.progressTrackView.heightAnchor constraintEqualToConstant:6.0],
        [self.progressFillView.topAnchor constraintEqualToAnchor:self.progressTrackView.topAnchor],
        [self.progressFillView.leadingAnchor constraintEqualToAnchor:self.progressTrackView.leadingAnchor],
        [self.progressFillView.bottomAnchor constraintEqualToAnchor:self.progressTrackView.bottomAnchor],
        self.progressFillWidthConstraint,
        [self.footerLabel.topAnchor constraintEqualToAnchor:self.progressTrackView.bottomAnchor constant:10.0],
        [self.footerLabel.leadingAnchor constraintEqualToAnchor:self.orderLabel.leadingAnchor],
        [self.footerLabel.trailingAnchor constraintEqualToAnchor:self.orderLabel.trailingAnchor],
        [self.actionRailView.topAnchor constraintEqualToAnchor:self.footerLabel.bottomAnchor constant:14.0],
        [self.actionRailView.leadingAnchor constraintEqualToAnchor:self.orderLabel.leadingAnchor],
        [self.actionRailView.trailingAnchor constraintEqualToAnchor:self.orderLabel.trailingAnchor],
        [self.actionRailView.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor constant:-16.0],
        [self.actionRailView.heightAnchor constraintEqualToConstant:42.0],
        [self.actionsStackView.leadingAnchor constraintEqualToAnchor:self.actionRailView.leadingAnchor constant:4.0],
        [self.actionsStackView.trailingAnchor constraintEqualToAnchor:self.actionRailView.trailingAnchor constant:-4.0],
        [self.actionsStackView.topAnchor constraintEqualToAnchor:self.actionRailView.topAnchor constant:4.0],
        [self.actionsStackView.bottomAnchor constraintEqualToAnchor:self.actionRailView.bottomAnchor constant:-4.0],
    ];

    self.collapsedConstraints = @[
        [self.collapsedContentView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor constant:12.0],
        [self.collapsedContentView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:16.0],
        [self.collapsedContentView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-16.0],
        [self.collapsedContentView.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor constant:-12.0],
        [self.collapsedIconBadgeView.leadingAnchor constraintEqualToAnchor:self.collapsedContentView.leadingAnchor],
        [self.collapsedIconBadgeView.centerYAnchor constraintEqualToAnchor:self.collapsedContentView.centerYAnchor],
        [self.collapsedIconBadgeView.widthAnchor constraintEqualToConstant:52.0],
        [self.collapsedIconBadgeView.heightAnchor constraintEqualToConstant:52.0],
        [self.collapsedIconView.centerXAnchor constraintEqualToAnchor:self.collapsedIconBadgeView.centerXAnchor],
        [self.collapsedIconView.centerYAnchor constraintEqualToAnchor:self.collapsedIconBadgeView.centerYAnchor],
        [self.collapsedIconView.widthAnchor constraintEqualToConstant:22.0],
        [self.collapsedIconView.heightAnchor constraintEqualToConstant:22.0],
        [self.collapsedStatusPillView.trailingAnchor constraintEqualToAnchor:self.collapsedChevronContainerView.leadingAnchor constant:-10.0],
        [self.collapsedStatusPillView.centerYAnchor constraintEqualToAnchor:self.collapsedContentView.centerYAnchor],
        [self.collapsedStatusPillView.heightAnchor constraintEqualToConstant:28.0],
        [self.collapsedStatusPillLabel.leadingAnchor constraintEqualToAnchor:self.collapsedStatusPillView.leadingAnchor constant:12.0],
        [self.collapsedStatusPillLabel.trailingAnchor constraintEqualToAnchor:self.collapsedStatusPillView.trailingAnchor constant:-12.0],
        [self.collapsedStatusPillLabel.centerYAnchor constraintEqualToAnchor:self.collapsedStatusPillView.centerYAnchor],
        [self.collapsedTextStackView.leadingAnchor constraintEqualToAnchor:self.collapsedIconBadgeView.trailingAnchor constant:12.0],
        [self.collapsedTextStackView.trailingAnchor constraintLessThanOrEqualToAnchor:self.collapsedStatusPillView.leadingAnchor constant:-12.0],
        [self.collapsedTextStackView.centerYAnchor constraintEqualToAnchor:self.collapsedContentView.centerYAnchor],
        [self.collapsedTextStackView.topAnchor constraintGreaterThanOrEqualToAnchor:self.collapsedContentView.topAnchor],
        [self.collapsedTextStackView.bottomAnchor constraintLessThanOrEqualToAnchor:self.collapsedContentView.bottomAnchor],
    ];

    [self pp_setShowsExpandedState:NO];
    [self pp_applyStatusColor:UIColor.systemBlueColor];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_applyThemeColors];
        }
    }
}

- (void)pp_applyThemeColors
{
    [self.shadowView pp_setShadowColor:UIColor.blackColor];
    [self.surfaceView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:(PPIOS26() ? 0.20 : 0.16)]];
    self.overlayView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.85];
    [self pp_applyStatusColor:self.currentStatusColor];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self pp_updateDecorativeLayers];
}

- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    CGSize previousSize = self.bounds.size;
    [super applyLayoutAttributes:layoutAttributes];
    self.layer.zPosition = MAX(self.layer.zPosition, 120.0);
    self.contentView.layer.zPosition = self.layer.zPosition;
    if (!CGSizeEqualToSize(previousSize, self.bounds.size)) {
        [self setNeedsLayout];
    }
}

- (void)pp_updateDecorativeLayers
{
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.overlayView.layer.cornerRadius = self.surfaceView.layer.cornerRadius;
    self.overlayGradientLayer.frame = self.overlayView.bounds;
    self.overlayGradientLayer.cornerRadius = self.surfaceView.layer.cornerRadius;
    self.shadowView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.shadowView.bounds
                                   cornerRadius:self.surfaceView.layer.cornerRadius].CGPath;
    [self pp_updateCollapsedPreviewLayout];
    [CATransaction commit];
}

- (void)refreshDecorativeLayersForCurrentBounds
{
    [self pp_updateDecorativeLayers];
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.onTrackTap = nil;
    self.onHistoryTap = nil;
    self.onCollapseTap = nil;
    self.trackButton.hidden = NO;
    self.historyButton.hidden = NO;
    self.trackButton.enabled = YES;
    self.historyButton.enabled = YES;
    self.actionRailView.alpha = 1.0;
    self.chipView.alpha = 1.0;
    self.collapsedContentView.alpha = 1.0;
    self.surfaceView.transform = CGAffineTransformIdentity;
    self.shadowView.transform = CGAffineTransformIdentity;
    self.collapsedContentView.transform = CGAffineTransformIdentity;
    self.collapsedChevronContainerView.transform = CGAffineTransformIdentity;
    self.collapsedChevronView.transform = CGAffineTransformIdentity;
    self.previewImageURLs = @[];
    self.collapsedIconView.hidden = NO;
    self.collapsedIconView.image = nil;
    for (UIImageView *imageView in self.collapsedPreviewImageViews ?: @[]) {
        imageView.hidden = YES;
        imageView.image = [UIImage imageNamed:@"placeholder"];
    }
}

- (void)configurePlaceholderExpanded:(BOOL)expanded
{
    [self configureWithOrderReference:@"----"
                      orderKickerTitle:(kLang(@"Home_CurrentOrdersTitle") ?: (kLang(@"Home_LastOrderTitle") ?: @""))
                       previewImageURLs:@[]
                                 meta:@"------"
                          statusTitle:(kLang(@"Pending") ?: @"Pending")
                           statusHint:@" "
                             progress:0.22
                           footerText:@" "
                          statusColor:UIColor.systemOrangeColor
                       statusIconName:@"clock.fill"
                          actionTitle:(kLang(@"order_action_track") ?: @"Track order")
                             expanded:expanded];
    self.orderLabel.alpha = 0.55;
    self.orderKickerLabel.alpha = 0.45;
    self.metaLabel.alpha = 0.45;
    self.hintLabel.alpha = 0.35;
    self.footerLabel.alpha = 0.35;
    self.chipView.alpha = 0.72;
    self.trackButton.hidden = YES;
    self.historyButton.hidden = YES;
    self.actionRailView.alpha = 0.45;
    self.collapsedContentView.alpha = 0.72;
}

- (void)configureWithOrderReference:(NSString *)orderReference
                   orderKickerTitle:(NSString *)orderKickerTitle
                    previewImageURLs:(NSArray<NSString *> *)previewImageURLs
                               meta:(NSString *)meta
                        statusTitle:(NSString *)statusTitle
                         statusHint:(NSString *)statusHint
                           progress:(double)progress
                         footerText:(NSString *)footerText
                        statusColor:(UIColor *)statusColor
                     statusIconName:(NSString *)statusIconName
                        actionTitle:(NSString *)actionTitle
                           expanded:(BOOL)expanded
{
    self.orderLabel.alpha = 1.0;
    self.orderKickerLabel.alpha = 1.0;
    self.metaLabel.alpha = 1.0;
    self.hintLabel.alpha = 1.0;
    self.footerLabel.alpha = 1.0;
    self.chipView.alpha = 1.0;
    self.collapsedContentView.alpha = 1.0;
    self.trackButton.hidden = NO;
    self.historyButton.hidden = NO;
    self.actionRailView.alpha = 1.0;

    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.contentView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.surfaceView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.chipView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.actionRailView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.actionsStackView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.collapsedContentView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.collapsedTextStackView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.chipLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.orderKickerLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.orderLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.metaLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.hintLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.footerLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.collapsedKickerLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.collapsedOrderLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.collapsedSummaryLabel.textAlignment = [Language alignmentForCurrentLanguage];

    self.orderKickerLabel.text = PPSafeString(orderKickerTitle);
    self.collapsedKickerLabel.text = PPSafeString(orderKickerTitle);
    self.orderLabel.text = PPSafeString(orderReference);
    self.metaLabel.text = PPSafeString(meta);
    self.hintLabel.text = PPSafeString(statusHint);
    self.footerLabel.text = PPSafeString(footerText);
    self.chipLabel.text = PPSafeString(statusTitle);
    self.chipIconView.image = [UIImage systemImageNamed:(statusIconName.length > 0 ? statusIconName : @"shippingbox.circle.fill")];
    self.collapsedOrderLabel.text = PPSafeString(orderReference);
    self.collapsedSummaryLabel.text = [self pp_collapsedSummaryWithMeta:PPSafeString(meta)
                                                             footerText:PPSafeString(footerText)
                                                             statusHint:PPSafeString(statusHint)];
    self.collapsedStatusPillLabel.text = PPSafeString(statusTitle);
    self.collapsedIconView.image = [UIImage systemImageNamed:(statusIconName.length > 0 ? statusIconName : @"shippingbox.circle.fill")];
    self.collapsedChevronView.image = [UIImage systemImageNamed:@"chevron.down"];

    UIColor *resolvedStatusColor = PPHomeOrderResolvedStatusColor(statusColor,
                                                                  statusTitle,
                                                                  statusHint,
                                                                  statusIconName);

    [self pp_applyStatusColor:resolvedStatusColor];
    [self pp_applyPreviewImageURLs:previewImageURLs];
    [self pp_setShowsExpandedState:expanded];

    double clamped = fmax(0.08, fmin(1.0, progress));
    CGFloat fillWidth = CGRectGetWidth(self.progressTrackView.bounds) * clamped;
    if (fillWidth <= 0.0) {
        fillWidth = 96.0 * clamped;
    }
    self.progressFillWidthConstraint.constant = fillWidth;

    NSString *resolvedActionTitle = actionTitle.length > 0 ? actionTitle : (kLang(@"order_action_track") ?: @"Track order");
    NSString *historyActionTitle = kLang(@"OrderHistory") ?: @"Order history";
    [self pp_configureActionButton:self.trackButton
                             title:resolvedActionTitle
                          iconName:@"location.fill"
                       statusColor:resolvedStatusColor
                         isPrimary:YES];
    [self pp_configureActionButton:self.historyButton
                             title:historyActionTitle
                          iconName:@"clock.fill"
                       statusColor:resolvedStatusColor
                         isPrimary:NO];

    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)pp_applyPreviewImageURLs:(NSArray<NSString *> *)previewImageURLs
{
    NSMutableArray<NSString *> *resolvedURLs = [NSMutableArray array];
    NSMutableOrderedSet<NSString *> *dedupedURLs = [NSMutableOrderedSet orderedSet];
    for (NSString *rawURL in previewImageURLs ?: @[]) {
        NSString *value = [rawURL isKindOfClass:NSString.class]
            ? [rawURL stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
            : @"";
        if (value.length == 0 || [dedupedURLs containsObject:value]) {
            continue;
        }
        [dedupedURLs addObject:value];
        [resolvedURLs addObject:value];
        if (resolvedURLs.count >= self.collapsedPreviewImageViews.count) {
            break;
        }
    }

    BOOL didChangePreviewURLs = ![self.previewImageURLs isEqualToArray:resolvedURLs];
    self.previewImageURLs = resolvedURLs.copy;

    UIImage *placeholder = [UIImage imageNamed:@"placeholder"];
    BOOL hasPreviewImages = (self.previewImageURLs.count > 0);
    self.collapsedIconView.hidden = hasPreviewImages;

    for (NSInteger index = 0; index < self.collapsedPreviewImageViews.count; index++) {
        UIImageView *imageView = self.collapsedPreviewImageViews[index];
        imageView.hidden = (index >= (NSInteger)self.previewImageURLs.count);
        if (imageView.hidden) {
            imageView.image = nil;
            continue;
        }

        NSString *imageURL = self.previewImageURLs[index];
        if (didChangePreviewURLs) {
            imageView.image = placeholder;
        }
        if (imageURL.length > 0 && (didChangePreviewURLs || imageView.image == nil)) {
            [GM setImageFromUrlString:imageURL imageView:imageView phImage:@"placeholder"];
        }
    }

    if (hasPreviewImages) {
        self.collapsedIconBadgeView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:(PPIOS26() ? 0.18 : 0.94)];
        self.collapsedIconBadgeView.layer.borderWidth = 1.0;
        [self.collapsedIconBadgeView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.64]];
    } else {
        self.collapsedIconBadgeView.layer.borderWidth = 0.0;
        [self.collapsedIconBadgeView pp_setBorderColor:UIColor.clearColor];
    }

    [self setNeedsLayout];
}

- (void)pp_updateCollapsedPreviewLayout
{
    CGRect bounds = self.collapsedIconBadgeView.bounds;
    if (CGRectIsEmpty(bounds)) {
        return;
    }

    NSUInteger visibleCount = MIN(self.previewImageURLs.count, self.collapsedPreviewImageViews.count);
    CGFloat width = CGRectGetWidth(bounds);
    CGFloat height = CGRectGetHeight(bounds);

    for (UIImageView *imageView in self.collapsedPreviewImageViews ?: @[]) {
        imageView.hidden = YES;
    }

    if (visibleCount == 0) {
        return;
    }

    NSArray<NSValue *> *frames = @[];
    if (visibleCount == 1) {
        frames = @[[NSValue valueWithCGRect:CGRectMake(0.0, 0.0, width, height)]];
    } else if (visibleCount == 2) {
        CGFloat size = MIN(width, height) - 8.0;
        CGFloat y = floor((height - size) * 0.5);
        frames = @[
            [NSValue valueWithCGRect:CGRectMake(1.0, y - 2.0, size, size)],
            [NSValue valueWithCGRect:CGRectMake(width - size - 1.0, y + 2.0, size, size)]
        ];
    } else {
        CGFloat size = MIN(width, height) - 14.0;
        frames = @[
            [NSValue valueWithCGRect:CGRectMake(1.0, height - size - 1.0, size, size)],
            [NSValue valueWithCGRect:CGRectMake(floor((width - size) * 0.5), 1.0, size, size)],
            [NSValue valueWithCGRect:CGRectMake(width - size - 1.0, height - size - 1.0, size, size)]
        ];
    }

    for (NSInteger index = 0; index < (NSInteger)visibleCount; index++) {
        UIImageView *imageView = self.collapsedPreviewImageViews[index];
        imageView.hidden = NO;
        imageView.frame = frames[index].CGRectValue;
        imageView.layer.cornerRadius = MIN(8.0, floor(CGRectGetWidth(imageView.bounds) * 0.22));
    }
}

- (NSString *)pp_collapsedSummaryWithMeta:(NSString *)meta
                               footerText:(NSString *)footerText
                               statusHint:(NSString *)statusHint
{
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    if (meta.length > 0) {
        [parts addObject:meta];
    }
    if (footerText.length > 0) {
        [parts addObject:footerText];
    }
    if (parts.count == 0 && statusHint.length > 0) {
        [parts addObject:statusHint];
    }
    return [parts componentsJoinedByString:@" | "];
}

- (NSArray<UIView *> *)pp_expandedContentViews
{
    return @[
        self.chipView,
        self.orderKickerLabel,
        self.orderLabel,
        self.metaLabel,
        self.hintLabel,
        self.progressTrackView,
        self.footerLabel,
        self.actionRailView
    ];
}

- (void)pp_applyExpandedConstraintState:(BOOL)expanded
{
    if (expanded) {
        [NSLayoutConstraint deactivateConstraints:self.collapsedConstraints];
        [NSLayoutConstraint activateConstraints:self.expandedConstraints];
    } else {
        [NSLayoutConstraint deactivateConstraints:self.expandedConstraints];
        [NSLayoutConstraint activateConstraints:self.collapsedConstraints];
    }

    self.collapsedChevronTopConstraint.active = expanded;
    self.collapsedChevronCenterYConstraint.active = !expanded;
}

- (void)pp_updateChevronAppearanceForExpanded:(BOOL)expanded
{
    self.collapsedChevronView.transform = expanded
        ? CGAffineTransformMakeRotation((CGFloat)M_PI)
        : CGAffineTransformIdentity;
    self.collapsedChevronTintView.alpha = expanded ? 1.0 : 0.86;
}

- (void)pp_applyExpandedVisibilityState:(BOOL)expanded
{
    for (UIView *view in [self pp_expandedContentViews]) {
        view.hidden = !expanded;
        view.alpha = expanded ? 1.0 : 0.0;
        view.transform = CGAffineTransformIdentity;
    }

    self.collapsedContentView.hidden = expanded;
    self.collapsedContentView.alpha = expanded ? 0.0 : 1.0;
    self.collapsedContentView.transform = CGAffineTransformIdentity;
    [self pp_updateChevronAppearanceForExpanded:expanded];
}

- (void)setExpandedState:(BOOL)expanded animated:(BOOL)animated
{
    if (!animated || self.showsExpandedState == expanded || !self.window) {
        [self pp_setShowsExpandedState:expanded];
        return;
    }

    _showsExpandedState = expanded;

    UIImpactFeedbackGenerator *haptic =
        [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [haptic prepare];
    [haptic impactOccurred];

    NSArray<UIView *> *expandedViews = [self pp_expandedContentViews];

    [self.contentView layoutIfNeeded];
    [self pp_applyExpandedConstraintState:expanded];

    for (UIView *view in expandedViews) {
        view.hidden = NO;
    }
    self.collapsedContentView.hidden = NO;

    if (expanded) {
        for (UIView *view in expandedViews) {
            view.alpha = 0.0;
            view.transform = CGAffineTransformMakeTranslation(0.0, 16.0);
        }
        self.collapsedContentView.alpha = 1.0;
        self.collapsedContentView.transform = CGAffineTransformIdentity;
        self.surfaceView.transform = CGAffineTransformMakeScale(0.98, 0.98);
    } else {
        for (UIView *view in expandedViews) {
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        }
        self.collapsedContentView.alpha = 0.0;
        self.collapsedContentView.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
    }

    [UIView animateWithDuration:0.46
                              delay:0.0
             usingSpringWithDamping:0.90
              initialSpringVelocity:0.28
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            [self.contentView layoutIfNeeded];
            self.surfaceView.transform = CGAffineTransformIdentity;
            [self pp_updateChevronAppearanceForExpanded:expanded];
            self.collapsedChevronContainerView.transform = CGAffineTransformMakeScale(1.04, 1.04);

            for (UIView *view in expandedViews) {
                view.alpha = expanded ? 1.0 : 0.0;
                view.transform = expanded
                    ? CGAffineTransformIdentity
                    : CGAffineTransformMakeTranslation(0.0, 10.0);
            }

            self.collapsedContentView.alpha = expanded ? 0.0 : 1.0;
            self.collapsedContentView.transform = expanded
                ? CGAffineTransformMakeTranslation(0.0, -6.0)
                : CGAffineTransformIdentity;
        } completion:^(__unused BOOL finished) {
            [UIView animateWithDuration:0.18
                                  delay:0.0
                                options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                             animations:^{
                self.collapsedChevronContainerView.transform = CGAffineTransformIdentity;
            } completion:nil];

            if (self.showsExpandedState == expanded) {
                [self pp_applyExpandedVisibilityState:expanded];
                [self pp_updateDecorativeLayers];
            }
        }];
}

- (void)pp_setShowsExpandedState:(BOOL)expanded
{
    _showsExpandedState = expanded;
    [self pp_applyExpandedConstraintState:expanded];
    [self pp_applyExpandedVisibilityState:expanded];
}

- (void)pp_configureActionButton:(UIButton *)button
                           title:(NSString *)title
                        iconName:(NSString *)iconName
                     statusColor:(UIColor *)statusColor
                       isPrimary:(BOOL)isPrimary
{
    UIColor *resolved = statusColor ?: AppPrimaryClr ?: UIColor.systemBlueColor;
    NSString *resolvedTitle = title.length > 0 ? title : @"";

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config =
            isPrimary ? [UIButtonConfiguration filledButtonConfiguration]
                      : [UIButtonConfiguration tintedButtonConfiguration];
        config.title = resolvedTitle;
        config.image = [UIImage systemImageNamed:iconName];
        config.imagePlacement = NSDirectionalRectEdgeLeading;
        config.imagePadding = 6.0;
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        config.contentInsets = NSDirectionalEdgeInsetsMake(7.0, 12.0, 7.0, 12.0);
        config.baseForegroundColor = isPrimary ? UIColor.whiteColor : resolved;
        config.baseBackgroundColor = isPrimary
            ? resolved
            : PPHomeOrderBlendColor(resolved, AppPrimaryClr, PPIOS26() ? 0.12 : 0.10);
        config.attributedTitle = [[NSAttributedString alloc] initWithString:resolvedTitle attributes:@{
            NSFontAttributeName: [GM boldFontWithSize:13] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold],
            NSForegroundColorAttributeName: isPrimary ? UIColor.whiteColor : resolved
        }];
        button.configuration = config;
        return;
    }

    [button setTitle:resolvedTitle forState:UIControlStateNormal];
    [button setTitleColor:isPrimary ? UIColor.whiteColor : resolved forState:UIControlStateNormal];
    button.backgroundColor = isPrimary ? resolved : PPHomeOrderBlendColor(resolved, AppPrimaryClr, 0.14);
    button.titleLabel.font = [GM boldFontWithSize:13] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    button.layer.borderWidth = isPrimary ? 0.0 : 1.0;
    [button pp_setBorderColor:PPHomeOrderBlendColor(resolved, AppPrimaryClr, 0.18)];
}

- (void)pp_applyStatusColor:(UIColor *)statusColor
{
    self.currentStatusColor = statusColor ?: UIColor.systemBlueColor;
    UIColor *resolved = self.currentStatusColor;
    UIColor *chipBackground = PPHomeOrderBlendColor(resolved, AppPrimaryClr, PPIOS26() ? 0.24 : 0.15);
    UIColor *softOverlay = PPHomeOrderBlendColor(resolved, AppPrimaryClr, PPIOS26() ? 0.12 : 0.08);

    self.chipView.backgroundColor = chipBackground;
    self.chipView.layer.borderWidth = 0.8;
    [self.chipView pp_setBorderColor:PPHomeOrderBlendColor(resolved, AppPrimaryClr, 0.20)];
    self.chipLabel.textColor = resolved;
    self.chipIconView.tintColor = resolved;
    self.progressFillView.backgroundColor = resolved;
    [self.surfaceView pp_setBorderColor:PPHomeOrderBlendColor(resolved, AppPrimaryClr, PPIOS26() ? 0.22 : 0.16)];
    self.actionRailView.backgroundColor = PPHomeOrderBlendColor(resolved, AppPrimaryClr, PPIOS26() ? 0.12 : 0.08);
    [self.actionRailView pp_setBorderColor:PPHomeOrderBlendColor(resolved, AppPrimaryClr, 0.20)];
    self.collapsedIconBadgeView.backgroundColor = chipBackground;
    self.collapsedIconView.tintColor = resolved;
    self.collapsedStatusPillView.backgroundColor = PPHomeOrderBlendColor(resolved, AppPrimaryClr, PPIOS26() ? 0.18 : 0.14);
    self.collapsedStatusPillLabel.textColor = resolved;
    [self.collapsedChevronContainerView pp_setBorderColor:PPHomeOrderBlendColor(resolved, AppPrimaryClr, 0.14)];
    self.collapsedChevronTintView.backgroundColor = PPHomeOrderBlendColor(resolved, AppPrimaryClr, PPIOS26() ? 0.12 : 0.10);
    self.collapsedChevronView.tintColor = resolved;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.overlayGradientLayer.colors = @[
        (id)softOverlay.CGColor,
        (id)[PPHomeOrderBlendColor(resolved, AppPrimaryClr, 0.03) CGColor],
        (id)[UIColor clearColor].CGColor
    ];
    [self.overlayGradientLayer setNeedsDisplay];
    [CATransaction commit];

    [self setNeedsLayout];
}

- (void)pp_handleTrackTap
{
    if (self.onTrackTap) {
        self.onTrackTap();
    }
}

- (void)pp_handleHistoryTap
{
    if (self.onHistoryTap) {
        self.onHistoryTap();
    }
}

- (void)pp_handleCollapseTap
{
    if (self.onCollapseTap) {
        self.onCollapseTap();
    }
}

@end
