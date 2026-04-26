//
//  PetCareHelpers.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/26/26.
//

#ifndef PetCareHelpers_h
#define PetCareHelpers_h


static NSString *PPPetCareLocalized(NSString *key, NSString *fallback)
{
    NSString *value = key.length ? kLang(key) : nil;
    return value.length > 0 ? value : fallback;
}
 
static UIColor *PPPetCareBorderColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            return dark
                ? [UIColor colorWithWhite:1.0 alpha:0.11]
                : [UIColor colorWithRed:0.72 green:0.66 blue:0.62 alpha:0.22];
        }];
    }
    return [UIColor colorWithRed:0.72 green:0.66 blue:0.62 alpha:0.22];
}


static NSString *PPPetCareSafeString(id value)
{
    return [value isKindOfClass:NSString.class] ? (NSString *)value : @"";
}

static UIColor *PPPetCareTextColor(void)
{
    return AppPrimaryTextClr ?: UIColor.labelColor;
}

static UIColor *PPPetCareSecondaryTextColor(void)
{
    return AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
}

static UIColor *PPPetCareAccentColor(void)
{
    return AppPrimaryClr ?: UIColor.systemTealColor;
}


static UIColor *PPPetCareSurfaceColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            return dark
            ? [AppBackgroundClr colorWithAlphaComponent:0.075]
            : [AppBackgroundClrLigter colorWithAlphaComponent:0.76];
        }];
    }
    return [UIColor colorWithWhite:1.0 alpha:0.76];
}



#endif /* PetCareHelpers_h */
