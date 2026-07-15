//
//  PPOrderStatusAppearance.h
//  Pure Pets
//
//  Shared semantic color and material system for customer-visible order states.
//

#import <UIKit/UIKit.h>
#import <math.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PPOrderStatusVisualPhase) {
    PPOrderStatusVisualPhasePlaced,
    PPOrderStatusVisualPhasePaymentConfirmed,
    PPOrderStatusVisualPhasePreparing,
    PPOrderStatusVisualPhaseReady,
    PPOrderStatusVisualPhaseAssigned,
    PPOrderStatusVisualPhaseInTransit,
    PPOrderStatusVisualPhaseDelivered,
    PPOrderStatusVisualPhaseCompleted,
    PPOrderStatusVisualPhaseCancelled,
    PPOrderStatusVisualPhaseDelayed,
    PPOrderStatusVisualPhaseReturned,
    PPOrderStatusVisualPhaseNeutral,
};

NS_INLINE NSString *PPOrderStatusAppearanceNormalizedKey(id _Nullable value)
{
    if (![value isKindOfClass:NSString.class]) return @"";
    NSString *key = [[(NSString *)value lowercaseString]
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    key = [key stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    key = [key stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
    while ([key containsString:@"__"]) {
        key = [key stringByReplacingOccurrencesOfString:@"__" withString:@"_"];
    }
    return key;
}

NS_INLINE BOOL PPOrderStatusAppearanceMatchesAny(NSString *statusKey, NSArray<NSString *> *tokens)
{
    NSString *key = PPOrderStatusAppearanceNormalizedKey(statusKey);
    if (key.length == 0 || tokens.count == 0) return NO;

    NSString *wrappedKey = [NSString stringWithFormat:@"_%@_", key];
    for (NSString *rawToken in tokens) {
        NSString *token = PPOrderStatusAppearanceNormalizedKey(rawToken);
        if (token.length == 0) continue;
        if ([key isEqualToString:token]) return YES;
        if ([wrappedKey containsString:[NSString stringWithFormat:@"_%@_", token]]) return YES;
    }
    return NO;
}

NS_INLINE PPOrderStatusVisualPhase PPOrderStatusVisualPhaseForKey(NSString * _Nullable statusKey)
{
    NSString *key = PPOrderStatusAppearanceNormalizedKey(statusKey);

    if (PPOrderStatusAppearanceMatchesAny(key, @[@"delivery_cancelled", @"cancelled", @"canceled", @"abandoned"])) {
        return PPOrderStatusVisualPhaseCancelled;
    }
    if (PPOrderStatusAppearanceMatchesAny(key, @[@"returned_to_store", @"returned", @"refunded", @"partially_refunded"])) {
        return PPOrderStatusVisualPhaseReturned;
    }
    if (PPOrderStatusAppearanceMatchesAny(key, @[@"delivery_delayed", @"delivery_failed", @"failed", @"rejected", @"declined", @"expired", @"voided", @"error"])) {
        return PPOrderStatusVisualPhaseDelayed;
    }
    if (PPOrderStatusAppearanceMatchesAny(key, @[@"completed", @"fulfilled", @"closed"])) {
        return PPOrderStatusVisualPhaseCompleted;
    }
    if (PPOrderStatusAppearanceMatchesAny(key, @[@"delivered", @"payment_pending", @"payment_confirmed"])) {
        return PPOrderStatusVisualPhaseDelivered;
    }
    if (PPOrderStatusAppearanceMatchesAny(key, @[@"picked_up", @"in_transit", @"out_for_delivery", @"shipped", @"shipping", @"handed_over"])) {
        return PPOrderStatusVisualPhaseInTransit;
    }
    if (PPOrderStatusAppearanceMatchesAny(key, @[@"delivery_partner_assigned", @"delivery_assigned", @"awaiting_handover", @"accepted_by_company", @"assigned_to_driver"])) {
        return PPOrderStatusVisualPhaseAssigned;
    }
    if (PPOrderStatusAppearanceMatchesAny(key, @[@"ready_for_delivery", @"ready_to_ship", @"delivery_requested", @"delivery_reassigned", @"ready_for_pickup", @"ready"])) {
        return PPOrderStatusVisualPhaseReady;
    }
    if (PPOrderStatusAppearanceMatchesAny(key, @[@"preparing_for_shipment", @"processing", @"preparing", @"packed", @"confirmed", @"accepted", @"start_preparing"])) {
        return PPOrderStatusVisualPhasePreparing;
    }
    if (PPOrderStatusAppearanceMatchesAny(key, @[@"paid", @"payment_verified", @"payment_collected", @"success", @"approved", @"captured", @"authorized", @"verified"])) {
        return PPOrderStatusVisualPhasePaymentConfirmed;
    }
    if (PPOrderStatusAppearanceMatchesAny(key, @[@"pending", @"placed", @"created", @"new_request", @"waiting", @"pending_review", @"pending_collection"])) {
        return PPOrderStatusVisualPhasePlaced;
    }
    return PPOrderStatusVisualPhaseNeutral;
}

NS_INLINE UIColor *PPOrderStatusHexColor(uint32_t hex)
{
    return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                           green:((hex >> 8) & 0xFF) / 255.0
                            blue:(hex & 0xFF) / 255.0
                           alpha:1.0];
}

NS_INLINE UIColor *PPOrderStatusDynamicColor(uint32_t lightHex, uint32_t darkHex)
{
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traits) {
        return PPOrderStatusHexColor(traits.userInterfaceStyle == UIUserInterfaceStyleDark ? darkHex : lightHex);
    }];
}

NS_INLINE UIColor *PPOrderStatusAccentColorForPhase(PPOrderStatusVisualPhase phase)
{
    switch (phase) {
        case PPOrderStatusVisualPhasePlaced:
            return PPOrderStatusDynamicColor(0x955407, 0xFFBE6A);
        case PPOrderStatusVisualPhasePaymentConfirmed:
            return PPOrderStatusDynamicColor(0x00666E, 0x68DDE4);
        case PPOrderStatusVisualPhasePreparing:
            return PPOrderStatusDynamicColor(0x6E3C9E, 0xD2A6FF);
        case PPOrderStatusVisualPhaseReady:
            return PPOrderStatusDynamicColor(0x00695A, 0x5FE3C6);
        case PPOrderStatusVisualPhaseAssigned:
            return PPOrderStatusDynamicColor(0x414EB0, 0xAAB2FF);
        case PPOrderStatusVisualPhaseInTransit:
            return PPOrderStatusDynamicColor(0x005F9F, 0x74C7FF);
        case PPOrderStatusVisualPhaseDelivered:
            return PPOrderStatusDynamicColor(0x137548, 0x67DCA4);
        case PPOrderStatusVisualPhaseCompleted:
            return PPOrderStatusDynamicColor(0x466B2E, 0xB6DEA0);
        case PPOrderStatusVisualPhaseCancelled:
            return PPOrderStatusDynamicColor(0xAE213A, 0xFF8D9E);
        case PPOrderStatusVisualPhaseDelayed:
            return PPOrderStatusDynamicColor(0xA8481E, 0xFFAD79);
        case PPOrderStatusVisualPhaseReturned:
            return PPOrderStatusDynamicColor(0x84386C, 0xF1A1D3);
        case PPOrderStatusVisualPhaseNeutral:
        default:
            return PPOrderStatusDynamicColor(0x53606E, 0xBDC7D3);
    }
}

NS_INLINE UIColor *PPOrderStatusShineColorForPhase(PPOrderStatusVisualPhase phase)
{
    switch (phase) {
        case PPOrderStatusVisualPhasePlaced:
            return PPOrderStatusDynamicColor(0xFFB34F, 0xFFE0A2);
        case PPOrderStatusVisualPhasePaymentConfirmed:
            return PPOrderStatusDynamicColor(0x31C6D1, 0xB4F7FA);
        case PPOrderStatusVisualPhasePreparing:
            return PPOrderStatusDynamicColor(0xB77AF2, 0xEED7FF);
        case PPOrderStatusVisualPhaseReady:
            return PPOrderStatusDynamicColor(0x33CBAE, 0xC1FFF2);
        case PPOrderStatusVisualPhaseAssigned:
            return PPOrderStatusDynamicColor(0x7E89F7, 0xE1E4FF);
        case PPOrderStatusVisualPhaseInTransit:
            return PPOrderStatusDynamicColor(0x3BA8F5, 0xD1EDFF);
        case PPOrderStatusVisualPhaseDelivered:
            return PPOrderStatusDynamicColor(0x43C785, 0xCEFFE5);
        case PPOrderStatusVisualPhaseCompleted:
            return PPOrderStatusDynamicColor(0xA4C772, 0xF4FFD9);
        case PPOrderStatusVisualPhaseCancelled:
            return PPOrderStatusDynamicColor(0xEF5A72, 0xFFD3DA);
        case PPOrderStatusVisualPhaseDelayed:
            return PPOrderStatusDynamicColor(0xF08049, 0xFFE1CF);
        case PPOrderStatusVisualPhaseReturned:
            return PPOrderStatusDynamicColor(0xD66CAB, 0xFFE0F3);
        case PPOrderStatusVisualPhaseNeutral:
        default:
            return PPOrderStatusDynamicColor(0x8B98A7, 0xEFF3F7);
    }
}

NS_INLINE UIColor *PPOrderStatusAccentColorForKey(NSString * _Nullable statusKey)
{
    return PPOrderStatusAccentColorForPhase(PPOrderStatusVisualPhaseForKey(statusKey));
}

NS_INLINE UIColor *PPOrderStatusShineColorForKey(NSString * _Nullable statusKey)
{
    return PPOrderStatusShineColorForPhase(PPOrderStatusVisualPhaseForKey(statusKey));
}

NS_INLINE UITraitCollection *PPOrderStatusResolvedTraits(UITraitCollection * _Nullable traits)
{
    return traits ?: [UITraitCollection currentTraitCollection];
}

NS_INLINE UIColor *PPOrderStatusResolvedColor(UIColor * _Nullable color, UITraitCollection * _Nullable traits)
{
    UIColor *resolved = color ?: PPOrderStatusAccentColorForPhase(PPOrderStatusVisualPhaseNeutral);
    return [resolved resolvedColorWithTraitCollection:PPOrderStatusResolvedTraits(traits)];
}

NS_INLINE BOOL PPOrderStatusColorComponents(UIColor *color, CGFloat *red, CGFloat *green, CGFloat *blue, CGFloat *alpha)
{
    if ([color getRed:red green:green blue:blue alpha:alpha]) return YES;
    CGFloat white = 0.0;
    if ([color getWhite:&white alpha:alpha]) {
        if (red) *red = white;
        if (green) *green = white;
        if (blue) *blue = white;
        return YES;
    }
    return NO;
}

NS_INLINE UIColor *PPOrderStatusBlendColors(UIColor *baseColor,
                                             UIColor *overlayColor,
                                             CGFloat ratio,
                                             UITraitCollection * _Nullable traits)
{
    UIColor *base = PPOrderStatusResolvedColor(baseColor, traits);
    UIColor *overlay = PPOrderStatusResolvedColor(overlayColor, traits);
    CGFloat br = 0.0, bg = 0.0, bb = 0.0, ba = 1.0;
    CGFloat or = 0.0, og = 0.0, ob = 0.0, oa = 1.0;
    if (!PPOrderStatusColorComponents(base, &br, &bg, &bb, &ba) ||
        !PPOrderStatusColorComponents(overlay, &or, &og, &ob, &oa)) {
        return [overlay colorWithAlphaComponent:MAX(0.0, MIN(1.0, ratio))];
    }
    CGFloat amount = MAX(0.0, MIN(1.0, ratio));
    return [UIColor colorWithRed:(br + ((or - br) * amount))
                           green:(bg + ((og - bg) * amount))
                            blue:(bb + ((ob - bb) * amount))
                           alpha:(ba + ((oa - ba) * amount))];
}

NS_INLINE BOOL PPOrderStatusUsesDarkAppearance(UITraitCollection * _Nullable traits)
{
    return PPOrderStatusResolvedTraits(traits).userInterfaceStyle == UIUserInterfaceStyleDark;
}

NS_INLINE UIColor *PPOrderStatusSurfaceColorForAccent(UIColor *accentColor,
                                                       UITraitCollection * _Nullable traits)
{
    BOOL dark = PPOrderStatusUsesDarkAppearance(traits);
    return PPOrderStatusBlendColors(UIColor.secondarySystemBackgroundColor,
                                    accentColor,
                                    dark ? 0.23 : 0.095,
                                    traits);
}

NS_INLINE UIColor *PPOrderStatusStrongSurfaceColorForAccent(UIColor *accentColor,
                                                             UITraitCollection * _Nullable traits)
{
    BOOL dark = PPOrderStatusUsesDarkAppearance(traits);
    return PPOrderStatusBlendColors(UIColor.secondarySystemBackgroundColor,
                                    accentColor,
                                    dark ? 0.31 : 0.15,
                                    traits);
}

NS_INLINE UIColor *PPOrderStatusBorderColorForAccent(UIColor *accentColor,
                                                      UITraitCollection * _Nullable traits)
{
    UIColor *resolved = PPOrderStatusResolvedColor(accentColor, traits);
    return [resolved colorWithAlphaComponent:PPOrderStatusUsesDarkAppearance(traits) ? 0.46 : 0.30];
}

NS_INLINE UIColor *PPOrderStatusGlowColorForKey(NSString * _Nullable statusKey,
                                                UITraitCollection * _Nullable traits)
{
    UIColor *shine = PPOrderStatusResolvedColor(PPOrderStatusShineColorForKey(statusKey), traits);
    return [shine colorWithAlphaComponent:PPOrderStatusUsesDarkAppearance(traits) ? 0.30 : 0.22];
}

NS_INLINE NSArray<UIColor *> *PPOrderStatusGradientColors(NSString * _Nullable statusKey,
                                                          UIColor * _Nullable fallbackAccent,
                                                          UITraitCollection * _Nullable traits)
{
    UIColor *accent = fallbackAccent ?: PPOrderStatusAccentColorForKey(statusKey);
    UIColor *shine = PPOrderStatusShineColorForKey(statusKey);
    UIColor *surface = PPOrderStatusSurfaceColorForAccent(accent, traits);
    BOOL dark = PPOrderStatusUsesDarkAppearance(traits);
    UIColor *highlight = PPOrderStatusBlendColors(surface, shine, dark ? 0.34 : 0.24, traits);
    UIColor *tail = PPOrderStatusBlendColors(surface, accent, dark ? 0.28 : 0.18, traits);
    return @[highlight, surface, tail];
}

NS_INLINE void PPOrderStatusConfigureGradientLayer(CAGradientLayer *layer,
                                                    NSString * _Nullable statusKey,
                                                    UIColor * _Nullable fallbackAccent,
                                                    UITraitCollection * _Nullable traits,
                                                    BOOL rightToLeft)
{
    if (!layer) return;
    NSArray<UIColor *> *colors = PPOrderStatusGradientColors(statusKey, fallbackAccent, traits);
    layer.colors = @[(id)colors[0].CGColor, (id)colors[1].CGColor, (id)colors[2].CGColor];
    layer.locations = @[@0.0, @0.46, @1.0];
    layer.startPoint = rightToLeft ? CGPointMake(1.0, 0.0) : CGPointMake(0.0, 0.0);
    layer.endPoint = rightToLeft ? CGPointMake(0.0, 1.0) : CGPointMake(1.0, 1.0);
}

NS_INLINE CGFloat PPOrderStatusLinearColorComponent(CGFloat component)
{
    return component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4);
}

NS_INLINE UIColor *PPOrderStatusContrastingForegroundColor(UIColor *backgroundColor,
                                                            UITraitCollection * _Nullable traits)
{
    UIColor *resolved = PPOrderStatusResolvedColor(backgroundColor, traits);
    CGFloat red = 0.0, green = 0.0, blue = 0.0, alpha = 1.0;
    if (!PPOrderStatusColorComponents(resolved, &red, &green, &blue, &alpha)) {
        return UIColor.whiteColor;
    }
    CGFloat luminance = (0.2126 * PPOrderStatusLinearColorComponent(red)) +
                        (0.7152 * PPOrderStatusLinearColorComponent(green)) +
                        (0.0722 * PPOrderStatusLinearColorComponent(blue));
    CGFloat whiteContrast = 1.05 / (luminance + 0.05);
    CGFloat darkContrast = (luminance + 0.05) / 0.055;
    return whiteContrast >= darkContrast ? UIColor.whiteColor : PPOrderStatusHexColor(0x121416);
}

NS_INLINE BOOL PPOrderStatusVisualPhaseIsFailure(PPOrderStatusVisualPhase phase)
{
    return phase == PPOrderStatusVisualPhaseCancelled ||
           phase == PPOrderStatusVisualPhaseDelayed ||
           phase == PPOrderStatusVisualPhaseReturned;
}

NS_INLINE NSString *PPOrderStatusSymbolNameForKey(NSString * _Nullable statusKey)
{
    switch (PPOrderStatusVisualPhaseForKey(statusKey)) {
        case PPOrderStatusVisualPhasePlaced: return @"clock.fill";
        case PPOrderStatusVisualPhasePaymentConfirmed: return @"creditcard.fill";
        case PPOrderStatusVisualPhasePreparing: return @"shippingbox.circle.fill";
        case PPOrderStatusVisualPhaseReady: return @"shippingbox.fill";
        case PPOrderStatusVisualPhaseAssigned: return @"person.crop.circle.fill";
        case PPOrderStatusVisualPhaseInTransit: return @"shippedtruck";
        case PPOrderStatusVisualPhaseDelivered: return @"checkmark.circle.fill";
        case PPOrderStatusVisualPhaseCompleted: return @"checkmark.seal.fill";
        case PPOrderStatusVisualPhaseCancelled: return @"xmark.circle.fill";
        case PPOrderStatusVisualPhaseDelayed: return @"exclamationmark.triangle.fill";
        case PPOrderStatusVisualPhaseReturned: return @"arrow.uturn.backward.circle.fill";
        case PPOrderStatusVisualPhaseNeutral:
        default: return @"circle.dashed";
    }
}

NS_ASSUME_NONNULL_END
