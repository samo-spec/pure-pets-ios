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
 
PPPetCareHelperInline UIColor *PPPetCareBorderColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            return dark
                ? [UIColor colorWithWhite:1.0 alpha:0.11]
            : [AppBackgroundClr colorWithAlphaComponent:0.22];
        }];
    }
    return [UIColor colorWithRed:0.72 green:0.66 blue:0.62 alpha:0.22];
}


PPPetCareHelperInline NSString *PPPetCareSafeString(id value)
{
    return [value isKindOfClass:NSString.class] ? (NSString *)value : @"";
}

PPPetCareHelperInline UIColor *PPPetCareTextColor(void)
{
    return AppPrimaryTextClr ?: UIColor.labelColor;
}

PPPetCareHelperInline UIColor *PPPetCareSecondaryTextColor(void)
{
    return AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
}

PPPetCareHelperInline UIColor *PPPetCareAccentColor(void)
{
    return AppPrimaryClr ?: UIColor.systemTealColor;
}


PPPetCareHelperInline UIColor *PPPetCareSurfaceColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            return dark
            ? [AppBackgroundClr colorWithAlphaComponent:0.075]
            : [AppBackgroundClr colorWithAlphaComponent:1];
        }];
    }
    return [UIColor colorWithWhite:1.0 alpha:0.76];
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
    item.type = @"petMedicine";
    return item;
}



#endif /* PetCareHelpers_h */
