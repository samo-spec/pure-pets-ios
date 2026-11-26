//
//  PetCareHelpers.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/26/26.
//

#ifndef PetCareHelpers_h
#define PetCareHelpers_h

#import "PPHomeInsetLabel.h"
#import "VetManager.h"
#import "CartManager.h"
#import "CartItem.h"
#ifndef PPPetCareHelperInline
#define PPPetCareHelperInline static inline __attribute__((unused))
#endif

PPPetCareHelperInline NSString *PPPetCareLocalized(NSString *key, NSString *fallback)
{
    NSString *value = key.length ? kLang(key) : nil;
    return value.length > 0 ? value : fallback;
}
 
#pragma mark - Pet Care V10 Semantic Palette (PurePets-DesignSystem aligned)

PPPetCareHelperInline UIColor *PPPetCareDynamicHex(CGFloat lr, CGFloat lg, CGFloat lb, CGFloat la,
                                                   CGFloat dr, CGFloat dg, CGFloat db, CGFloat da)
{
    UIColor *light = [UIColor colorWithRed:lr / 255.0 green:lg / 255.0 blue:lb / 255.0 alpha:la];
    UIColor *dark = [UIColor colorWithRed:dr / 255.0 green:dg / 255.0 blue:db / 255.0 alpha:da];
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? dark : light;
        }];
    }
    return light;
}

PPPetCareHelperInline UIColor *PPPetCareCanvasColor(void)
{
    // PurePets-DesignSystem ppBackground: #F8F8F9 (light) / #0E0B0C (dark)
    return PPPetCareDynamicHex(248.0, 248.0, 249.0, 1.0, 14.0, 11.0, 12.0, 1.0);
}

PPPetCareHelperInline UIColor *PPPetCareSurfaceColor(void)
{
    // PurePets-DesignSystem ppElevatedSurface: #FFFDFC (light) / #21191C (dark)
    return PPPetCareDynamicHex(255.0, 253.0, 252.0, 1.0, 33.0, 25.0, 28.0, 1.0);
}

PPPetCareHelperInline UIColor *PPPetCareSecondarySurfaceColor(void)
{
    // PurePets-DesignSystem ppSecondarySurface: #F7F1ED (light) / #2B2024 (dark)
    return PPPetCareDynamicHex(247.0, 241.0, 237.0, 1.0, 43.0, 32.0, 36.0, 1.0);
}

PPPetCareHelperInline UIColor *PPPetCareBorderColor(void)
{
    // PurePets-DesignSystem ppSurfaceBorder (#EEDDE3 / #3B2D32) with increased-contrast escalation
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            if (traitCollection.accessibilityContrast == UIAccessibilityContrastHigh) {
                return dark
                    ? [UIColor colorWithRed:194.0/255.0 green:180.0/255.0 blue:185.0/255.0 alpha:1.0]
                    : [UIColor colorWithRed:117.0/255.0 green:102.0/255.0 blue:107.0/255.0 alpha:1.0];
            }
            return dark
                ? [UIColor colorWithRed:59.0/255.0 green:45.0/255.0 blue:50.0/255.0 alpha:1.0]
                : [UIColor colorWithRed:238.0/255.0 green:221.0/255.0 blue:227.0/255.0 alpha:1.0];
        }];
    }
    return [UIColor colorWithRed:238.0/255.0 green:221.0/255.0 blue:227.0/255.0 alpha:1.0];
}

PPPetCareHelperInline UIColor *PPPetCareSeparatorColor(void)
{
    // PurePets-DesignSystem ppSeparator: #E6DADD (light) / #3B2D32 (dark)
    return PPPetCareDynamicHex(230.0, 218.0, 221.0, 1.0, 59.0, 45.0, 50.0, 1.0);
}

PPPetCareHelperInline NSString *PPPetCareSafeString(id value)
{
    return [value isKindOfClass:NSString.class] ? (NSString *)value : @"";
}

PPPetCareHelperInline UIColor *PPPetCareTextColor(void)
{
    // PurePets-DesignSystem ppTextPrimary: #2A1D21 (light) / #FFF8FA (dark)
    return PPPetCareDynamicHex(42.0, 29.0, 33.0, 1.0, 255.0, 248.0, 250.0, 1.0);
}

PPPetCareHelperInline UIColor *PPPetCareSecondaryTextColor(void)
{
    // PurePets-DesignSystem ppTextSecondary: #75666B (light) / #C2B4B9 (dark)
    return PPPetCareDynamicHex(117.0, 102.0, 107.0, 1.0, 194.0, 180.0, 185.0, 1.0);
}

PPPetCareHelperInline UIColor *PPPetCareAccentColor(void)
{
    // PurePets-DesignSystem ppCareAccent: #47929C (light) / #64AAB0 (dark)
    return PPPetCareDynamicHex(71.0, 146.0, 156.0, 1.0, 100.0, 170.0, 176.0, 1.0);
}

PPPetCareHelperInline UIColor *PPPetCareAccentTextColor(void)
{
    // High-contrast care foreground for small text labels: #2B6971 (light) / #7AC0C6 (dark)
    return PPPetCareDynamicHex(43.0, 105.0, 113.0, 1.0, 122.0, 192.0, 198.0, 1.0);
}

PPPetCareHelperInline UIColor *PPPetCareActiveChipBackgroundColor(void)
{
    return PPPetCareDynamicHex(71.0, 146.0, 156.0, 0.13, 100.0, 170.0, 176.0, 0.20);
}

PPPetCareHelperInline UIColor *PPPetCareActiveChipBorderColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            BOOL highContrast = traitCollection.accessibilityContrast == UIAccessibilityContrastHigh;
            CGFloat alpha = highContrast ? 0.90 : (dark ? 0.58 : 0.45);
            return dark
                ? [UIColor colorWithRed:100.0/255.0 green:170.0/255.0 blue:176.0/255.0 alpha:alpha]
                : [UIColor colorWithRed:71.0/255.0 green:146.0/255.0 blue:156.0/255.0 alpha:alpha];
        }];
    }
    return [UIColor colorWithRed:71.0/255.0 green:146.0/255.0 blue:156.0/255.0 alpha:0.45];
}

PPPetCareHelperInline UIColor *PPPetCareActiveChipTextColor(void)
{
    // #1F565E (light) / #A3DCE0 (dark)
    return PPPetCareDynamicHex(31.0, 86.0, 94.0, 1.0, 163.0, 220.0, 224.0, 1.0);
}

PPPetCareHelperInline UIColor *PPPetCareDarkAccentColor(void)
{
    // Deeper Pet Care teal for filled controls, marks, and ECG accents:
    // #1F565E (light, 8.23:1 with white) / #2B6971 (dark, 6.25:1 with white)
    return PPPetCareDynamicHex(31.0, 86.0, 94.0, 1.0, 43.0, 105.0, 113.0, 1.0);
}

PPPetCareHelperInline UIColor *PPPetCareDarkAccentTextColor(void)
{
    // High-contrast darker Pet Care teal for foreground labels, icons, and ECG pulse:
    // #1F565E / #18444B (light, >= 7.35:1) / #5CA5AD / #7AC0C6 (dark, >= 5.57:1)
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            BOOL highContrast = traitCollection.accessibilityContrast == UIAccessibilityContrastHigh;
            if (dark) {
                return highContrast
                    ? [UIColor colorWithRed:122.0/255.0 green:192.0/255.0 blue:198.0/255.0 alpha:1.0]
                    : [UIColor colorWithRed:92.0/255.0 green:165.0/255.0 blue:173.0/255.0 alpha:1.0];
            }
            return highContrast
                ? [UIColor colorWithRed:24.0/255.0 green:68.0/255.0 blue:75.0/255.0 alpha:1.0]
                : [UIColor colorWithRed:31.0/255.0 green:86.0/255.0 blue:94.0/255.0 alpha:1.0];
        }];
    }
    return [UIColor colorWithRed:31.0/255.0 green:86.0/255.0 blue:94.0/255.0 alpha:1.0];
}

PPPetCareHelperInline UIColor *PPPetCareBrandPrimaryColor(void)
{
    // PurePets-DesignSystem ppPrimary: #CB2654
    return [UIColor colorWithRed:203.0/255.0 green:38.0/255.0 blue:84.0/255.0 alpha:1.0];
}

PPPetCareHelperInline UIColor *PPPetCareBrandAccentTextColor(void)
{
    // PurePets-DesignSystem ppAccentText: #CB2654 (light) / #E05A7E (dark)
    return PPPetCareDynamicHex(203.0, 38.0, 84.0, 1.0, 224.0, 90.0, 126.0, 1.0);
}

PPPetCareHelperInline NSString *PPPetCareMedicineItemIdentifier(VetMedicineModel *medicine)
{
    if (![medicine isKindOfClass:VetMedicineModel.class]) {
        return @"";
    }
    return PPPetCareSafeString(medicine.medicineID);
}

PPPetCareHelperInline NSString *PPPetCareMedicineCurrencyCode(VetMedicineModel *medicine)
{
    NSString *currency = [medicine isKindOfClass:VetMedicineModel.class] ? PPPetCareSafeString(medicine.currency) : @"";
    return currency.length > 0 ? currency : @"QAR";
}

PPPetCareHelperInline NSInteger PPPetCareCartQuantityForMedicine(VetMedicineModel *medicine)
{
    NSString *itemID = PPPetCareMedicineItemIdentifier(medicine);
    if (itemID.length == 0) {
        return 0;
    }
    CartItem *existing = [[CartManager sharedManager] getCartItemForItemID:itemID];
    return MAX(existing.quantity, 0);
}

PPPetCareHelperInline CartItem * _Nullable PPPetCareCartItemForMedicine(VetMedicineModel *medicine, NSInteger quantity)
{
    NSString *itemID = PPPetCareMedicineItemIdentifier(medicine);
    if (itemID.length == 0) {
        return nil;
    }

    CartItem *item = [[CartItem alloc] init];
    item.itemID = itemID;
    item.name = PPPetCareSafeString(medicine.title).length > 0
        ? PPPetCareSafeString(medicine.title)
        : PPPetCareLocalized(@"pet_care_medicine_untitled", @"Medicine");
    item.quantity = MAX(quantity, 0);
    item.stockQuantity = MAX(medicine.stockQuantity, 0);
    item.price = MAX(medicine.price, 0.0);
    item.originalPrice = MAX(medicine.price, 0.0);
    item.imageURL = PPPetCareSafeString(medicine.imageUrl);
    item.providerID = PPPetCareSafeString(medicine.userId);
    item.type = @"petMedicine";
    return item;
}



#endif /* PetCareHelpers_h */
