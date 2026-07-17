//
//  PPHomeOrderStatusCell.m
//  Pure Pets
//
//  UIKit collection-view bridge for the SwiftUI order status experience.
//

#import "PPHomeOrderStatusCell.h"
#import "PPOrderStatusAppearance.h"
#import <Pure_Pets-Swift.h>

@interface PPHomeOrderStatusCell ()
@property (nonatomic, strong) PPHomeOrderStatusHostingView *hostingView;
@property (nonatomic, copy) NSString *currentOrderReference;
@property (nonatomic, copy) NSString *currentStatusKey;
@end

static NSString * const PPHomeOrderDefaultStatusIconName = @"shippingbox.circle.fill";

static inline NSString *PPHomeOrderTrimmedString(NSString *value)
{
    if (![value isKindOfClass:NSString.class]) {
        return @"";
    }
    return [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static inline NSString *PPHomeOrderResolvedSymbolName(NSString *symbolName)
{
    NSString *trimmed = PPHomeOrderTrimmedString(symbolName);
    return trimmed.length > 0 ? trimmed : PPHomeOrderDefaultStatusIconName;
}

static BOOL PPHomeOrderStatusTextContainsAnyKeyword(NSString *text,
                                                     NSArray<NSString *> *keywords)
{
    NSString *normalizedText = [PPHomeOrderTrimmedString(text) lowercaseString];
    if (normalizedText.length == 0 || keywords.count == 0) {
        return NO;
    }

    for (NSString *keyword in keywords) {
        NSString *candidate = [PPHomeOrderTrimmedString(keyword) lowercaseString];
        if (candidate.length > 0 && [normalizedText containsString:candidate]) {
            return YES;
        }
    }
    return NO;
}

static UIColor *PPHomeOrderResolvedStatusColor(UIColor *fallbackColor,
                                               NSString *statusTitle,
                                               NSString *statusHint,
                                               NSString *statusIconName)
{
    if (fallbackColor) {
        return fallbackColor;
    }

    NSString *iconName = [PPHomeOrderTrimmedString(statusIconName) lowercaseString];
    NSString *combinedText = [NSString stringWithFormat:@"%@ %@",
                              PPHomeOrderTrimmedString(statusTitle),
                              PPHomeOrderTrimmedString(statusHint)];

    if ([iconName containsString:@"xmark"] ||
        PPHomeOrderStatusTextContainsAnyKeyword(combinedText,
                                                @[@"failed", @"cancel", @"declined", @"rejected", @"voided",
                                                  @"ملغي", @"مرفوض", @"فشل"])) {
        return PPOrderStatusAccentColorForKey(@"delivery_cancelled");
    }
    if ([iconName containsString:@"checkmark"] ||
        PPHomeOrderStatusTextContainsAnyKeyword(combinedText,
                                                @[@"delivered", @"completed", @"fulfilled", @"تم التسليم", @"مكتمل"])) {
        return PPOrderStatusAccentColorForKey([iconName containsString:@"seal"] ? @"completed" : @"delivered");
    }
    if ([iconName containsString:@"shippedtruck"] ||
        PPHomeOrderStatusTextContainsAnyKeyword(combinedText,
                                                @[@"shipped", @"shipping", @"transit", @"out for delivery",
                                                  @"out_for_delivery", @"في الطريق", @"تم الشحن"])) {
        return PPOrderStatusAccentColorForKey(@"on_the_way");
    }
    if ([iconName containsString:@"shippingbox"] ||
        PPHomeOrderStatusTextContainsAnyKeyword(combinedText,
                                                @[@"processing", @"preparing", @"packed", @"confirmed",
                                                  @"قيد المعالجة", @"التجهيز", @"جاري تجهيز", @"تم التأكيد"])) {
        return PPOrderStatusAccentColorForKey(@"preparing_for_shipment");
    }
    if ([iconName containsString:@"creditcard"] ||
        PPHomeOrderStatusTextContainsAnyKeyword(combinedText,
                                                @[@"paid", @"payment", @"approved", @"captured", @"authorized",
                                                  @"مدفوع", @"تم الدفع"])) {
        return PPOrderStatusAccentColorForKey(@"paid");
    }
    if ([iconName containsString:@"clock"] ||
        PPHomeOrderStatusTextContainsAnyKeyword(combinedText,
                                                @[@"pending", @"waiting", @"بانتظار", @"قيد الانتظار"])) {
        return PPOrderStatusAccentColorForKey(@"pending");
    }
    return PPOrderStatusAccentColorForKey(@"neutral");
}

@implementation PPHomeOrderStatusCell

+ (NSString *)reuseIdentifier
{
    return @"PPHomeOrderStatusCell";
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }
    [self pp_setupHostingView];
    return self;
}

- (void)pp_setupHostingView
{
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.clipsToBounds = NO;
    self.clipsToBounds = NO;
    self.isAccessibilityElement = NO;
    self.contentView.isAccessibilityElement = NO;

    self.hostingView = [[PPHomeOrderStatusHostingView alloc] initWithFrame:CGRectZero];
    self.hostingView.translatesAutoresizingMaskIntoConstraints = NO;
    self.hostingView.backgroundColor = UIColor.clearColor;
    [self.contentView addSubview:self.hostingView];

    [NSLayoutConstraint activateConstraints:@[
        [self.hostingView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.hostingView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.hostingView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.hostingView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
    ]];

    __weak typeof(self) weakSelf = self;
    self.hostingView.onTrackTap = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (self.onTrackTap) {
            self.onTrackTap();
        }
    };
    self.hostingView.onHistoryTap = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (self.onHistoryTap) {
            self.onHistoryTap();
        }
    };
    self.hostingView.onCollapseTap = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (self.onCollapseTap) {
            self.onCollapseTap();
        }
    };

    [self pp_applyCurrentLanguageDirection];
}

- (void)pp_applyCurrentLanguageDirection
{
    UISemanticContentAttribute semantic = Language.semanticAttributeForCurrentLanguage;
    self.semanticContentAttribute = semantic;
    self.contentView.semanticContentAttribute = semantic;
    self.hostingView.semanticContentAttribute = semantic;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.onTrackTap = nil;
    self.onHistoryTap = nil;
    self.onCollapseTap = nil;
    self.currentOrderReference = @"";
    self.currentStatusKey = @"";
    [self.hostingView prepareForReuse];
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    [self.hostingView setHighlighted:highlighted animated:self.window != nil];
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    if (!selected) {
        [self.hostingView setHighlighted:NO animated:self.window != nil];
    }
}

- (void)configurePlaceholderExpanded:(BOOL)expanded
{
    [self pp_configureWithOrderReference:@"----"
                        orderKickerTitle:(kLang(@"Home_CurrentOrdersTitle") ?: (kLang(@"Home_LastOrderTitle") ?: @""))
                         previewImageURLs:@[]
                                    meta:@"------"
                             statusTitle:(kLang(@"Pending") ?: @"")
                              statusHint:@" "
                               statusKey:@"pending"
                                progress:0.22
                              footerText:@" "
                             statusColor:PPOrderStatusAccentColorForKey(@"pending")
                          statusIconName:@"clock.fill"
                             actionTitle:(kLang(@"order_action_track") ?: @"")
                                expanded:expanded
                             placeholder:YES];
}

- (void)configureWithOrderReference:(NSString *)orderReference
                   orderKickerTitle:(NSString *)orderKickerTitle
                    previewImageURLs:(NSArray<NSString *> *)previewImageURLs
                               meta:(NSString *)meta
                        statusTitle:(NSString *)statusTitle
                         statusHint:(NSString *)statusHint
                          statusKey:(NSString *)statusKey
                           progress:(double)progress
                         footerText:(NSString *)footerText
                        statusColor:(UIColor *)statusColor
                     statusIconName:(NSString *)statusIconName
                        actionTitle:(NSString *)actionTitle
                           expanded:(BOOL)expanded
{
    [self pp_configureWithOrderReference:orderReference
                        orderKickerTitle:orderKickerTitle
                         previewImageURLs:previewImageURLs
                                    meta:meta
                             statusTitle:statusTitle
                              statusHint:statusHint
                               statusKey:statusKey
                                progress:progress
                              footerText:footerText
                             statusColor:statusColor
                          statusIconName:statusIconName
                             actionTitle:actionTitle
                                expanded:expanded
                             placeholder:NO];
}

- (void)pp_configureWithOrderReference:(NSString *)orderReference
                      orderKickerTitle:(NSString *)orderKickerTitle
                       previewImageURLs:(NSArray<NSString *> *)previewImageURLs
                                  meta:(NSString *)meta
                           statusTitle:(NSString *)statusTitle
                            statusHint:(NSString *)statusHint
                             statusKey:(NSString *)statusKey
                              progress:(double)progress
                            footerText:(NSString *)footerText
                           statusColor:(UIColor *)statusColor
                        statusIconName:(NSString *)statusIconName
                           actionTitle:(NSString *)actionTitle
                              expanded:(BOOL)expanded
                           placeholder:(BOOL)placeholder
{
    [self pp_applyCurrentLanguageDirection];

    NSString *resolvedOrderReference = PPHomeOrderTrimmedString(orderReference);
    NSString *resolvedStatusKey = PPOrderStatusAppearanceNormalizedKey(statusKey);
    BOOL animateStatusChange = !placeholder &&
                               self.window != nil &&
                               self.currentOrderReference.length > 0 &&
                               [self.currentOrderReference isEqualToString:resolvedOrderReference] &&
                               self.currentStatusKey.length > 0 &&
                               ![self.currentStatusKey isEqualToString:resolvedStatusKey] &&
                               !UIAccessibilityIsReduceMotionEnabled();

    NSMutableArray<NSString *> *resolvedImageURLs = [NSMutableArray arrayWithCapacity:3];
    NSMutableSet<NSString *> *seenImageURLs = [NSMutableSet setWithCapacity:3];
    for (id rawValue in previewImageURLs ?: @[]) {
        NSString *imageURL = PPHomeOrderTrimmedString(rawValue);
        if (imageURL.length == 0 || [seenImageURLs containsObject:imageURL]) {
            continue;
        }
        [seenImageURLs addObject:imageURL];
        [resolvedImageURLs addObject:imageURL];
        if (resolvedImageURLs.count == 3) {
            break;
        }
    }

    UIColor *resolvedColor = PPHomeOrderResolvedStatusColor(statusColor,
                                                            statusTitle,
                                                            statusHint,
                                                            statusIconName);
    NSString *resolvedActionTitle = PPHomeOrderTrimmedString(actionTitle);
    if (resolvedActionTitle.length == 0) {
        resolvedActionTitle = kLang(@"order_action_track") ?: @"";
    }

    self.currentOrderReference = resolvedOrderReference;
    self.currentStatusKey = resolvedStatusKey;

    [self.hostingView configureWithOrderReference:resolvedOrderReference
                                orderKickerTitle:PPHomeOrderTrimmedString(orderKickerTitle)
                                 previewImageURLs:resolvedImageURLs.copy
                                            meta:PPHomeOrderTrimmedString(meta)
                                     statusTitle:PPHomeOrderTrimmedString(statusTitle)
                                      statusHint:PPHomeOrderTrimmedString(statusHint)
                                       statusKey:resolvedStatusKey
                                        progress:progress
                                      footerText:PPHomeOrderTrimmedString(footerText)
                                     statusColor:resolvedColor
                                  statusIconName:PPHomeOrderResolvedSymbolName(statusIconName)
                                     actionTitle:resolvedActionTitle
                                    historyTitle:(kLang(@"OrderHistory") ?: @"")
                      loadingAccessibilityLabel:(kLang(@"Loading") ?: @"")
                        toggleAccessibilityLabel:(kLang(@"order_tracking_toggle_accessibility_label") ?: @"")
                         toggleAccessibilityHint:(kLang(@"order_tracking_toggle_accessibility_hint") ?: @"")
                             expandedStateValue:(kLang(@"order_tracking_toggle_expanded") ?: @"")
                            collapsedStateValue:(kLang(@"order_tracking_toggle_collapsed") ?: @"")
                                        expanded:expanded
                                     placeholder:placeholder
                                        animated:animateStatusChange];
}

- (void)setExpandedState:(BOOL)expanded animated:(BOOL)animated
{
    BOOL shouldAnimate = animated && self.window != nil && !UIAccessibilityIsReduceMotionEnabled();
    if (shouldAnimate) {
        UIImpactFeedbackGenerator *generator =
            [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [generator prepare];
        [generator impactOccurred];
    }
    [self.hostingView setExpanded:expanded animated:shouldAnimate];
}

- (void)refreshDecorativeLayersForCurrentBounds
{
    [self.hostingView refreshForCurrentBounds];
}

@end
