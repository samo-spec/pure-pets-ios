#import <UIKit/UIKit.h>

NS_INLINE UIColor *PPMarketplaceHeroCardColor(uint32_t hex, CGFloat alpha)
{
    return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                           green:((hex >> 8) & 0xFF) / 255.0
                            blue:(hex & 0xFF) / 255.0
                           alpha:alpha];
}

NS_INLINE UIColor *PPMarketplaceHeroCardResolvedColor(UIColor *color, UITraitCollection *traitCollection)
{
    if (!color) {
        return UIColor.clearColor;
    }
    if (@available(iOS 13.0, *)) {
        return [color resolvedColorWithTraitCollection:(traitCollection ?: [UITraitCollection currentTraitCollection])];
    }
    return color;
}

NS_INLINE UIColor *PPMarketplaceHeroCardBlend(UIColor *baseColor,
                                              UIColor *overlayColor,
                                              CGFloat amount,
                                              UITraitCollection *traitCollection)
{
    UIColor *base = PPMarketplaceHeroCardResolvedColor(baseColor, traitCollection);
    UIColor *overlay = PPMarketplaceHeroCardResolvedColor(overlayColor, traitCollection);

    CGFloat baseRed = 0.0;
    CGFloat baseGreen = 0.0;
    CGFloat baseBlue = 0.0;
    CGFloat baseAlpha = 0.0;
    CGFloat overlayRed = 0.0;
    CGFloat overlayGreen = 0.0;
    CGFloat overlayBlue = 0.0;
    CGFloat overlayAlpha = 0.0;
    if (![base getRed:&baseRed green:&baseGreen blue:&baseBlue alpha:&baseAlpha] ||
        ![overlay getRed:&overlayRed green:&overlayGreen blue:&overlayBlue alpha:&overlayAlpha]) {
        return baseColor ?: overlayColor ?: UIColor.clearColor;
    }

    CGFloat t = MIN(MAX(amount, 0.0), 1.0);
    return [UIColor colorWithRed:(baseRed * (1.0 - t)) + (overlayRed * t)
                           green:(baseGreen * (1.0 - t)) + (overlayGreen * t)
                            blue:(baseBlue * (1.0 - t)) + (overlayBlue * t)
                           alpha:(baseAlpha * (1.0 - t)) + (overlayAlpha * t)];
}

NS_INLINE UIColor *PPMarketplaceHeroCardAccentColor(void)
{
    return AppPrimaryClr ?: PPMarketplaceHeroCardColor(0xEA6D54, 1.0);
}

NS_INLINE UIColor *PPMarketplaceHeroCardSurfaceBaseColor(UITraitCollection *traitCollection)
{
    UIColor *fallback = [UIColor colorWithRed:0.992 green:0.989 blue:0.991 alpha:1.0];
    if (@available(iOS 13.0, *)) {
        fallback = PPMarketplaceHeroCardResolvedColor(
            [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traits) {
                return traits.userInterfaceStyle == UIUserInterfaceStyleDark
                    ? [UIColor colorWithWhite:0.104 alpha:1.0]
                    : [UIColor colorWithRed:0.992 green:0.989 blue:0.991 alpha:1.0];
            }],
            traitCollection
        );
    }
    return AppForgroundColr ?: fallback;
}

NS_INLINE UIColor *PPMarketplaceHeroCardSurfaceHighlightColor(UITraitCollection *traitCollection)
{
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return PPMarketplaceHeroCardBlend(PPMarketplaceHeroCardSurfaceBaseColor(traitCollection),
                                      UIColor.whiteColor,
                                      dark ? 0.08 : 0.20,
                                      traitCollection);
}

NS_INLINE UIColor *PPMarketplaceHeroCardSurfaceTintColor(UITraitCollection *traitCollection)
{
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return PPMarketplaceHeroCardBlend(PPMarketplaceHeroCardSurfaceBaseColor(traitCollection),
                                      PPMarketplaceHeroCardAccentColor(),
                                      dark ? 0.11 : 0.045,
                                      traitCollection);
}

NS_INLINE UIColor *PPMarketplaceHeroCardSurfaceTailColor(UITraitCollection *traitCollection)
{
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return PPMarketplaceHeroCardBlend(PPMarketplaceHeroCardSurfaceTintColor(traitCollection),
                                      PPMarketplaceHeroCardAccentColor(),
                                      dark ? 0.08 : 0.03,
                                      traitCollection);
}

NS_INLINE UIColor *PPMarketplaceHeroCardStrokeColor(UITraitCollection *traitCollection)
{
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return [UIColor.whiteColor colorWithAlphaComponent:(dark ? 0.26 : 0.78)];
}

NS_INLINE UIColor *PPMarketplaceHeroCardTopAccentColor(UITraitCollection *traitCollection)
{
    (void)traitCollection;
    return [PPMarketplaceHeroCardAccentColor() colorWithAlphaComponent:0.58];
}

NS_INLINE UIColor *PPMarketplaceHeroCardOrbColor(UITraitCollection *traitCollection)
{
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return [PPMarketplaceHeroCardAccentColor() colorWithAlphaComponent:(dark ? 0.15 : 0.10)];
}

NS_INLINE UIColor *PPMarketplaceHeroCardPrimaryTextColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
                ? [UIColor colorWithWhite:0.96 alpha:1.0]
                : PPMarketplaceHeroCardColor(0x2A171D, 1.0);
        }];
    }
    return PPMarketplaceHeroCardColor(0x2A171D, 1.0);
}

NS_INLINE UIColor *PPMarketplaceHeroCardSecondaryTextColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
                ? [UIColor colorWithWhite:0.76 alpha:1.0]
                : PPMarketplaceHeroCardColor(0x7A666C, 1.0);
        }];
    }
    return PPMarketplaceHeroCardColor(0x7A666C, 1.0);
}
