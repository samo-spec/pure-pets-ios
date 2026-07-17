#import "PPUniversalCellHelper.h"
#import "PPUniversalCellViewModel.h"
#import "CartManager.h"
#import "PetAccessory.h"
#import "PetAd.h"
#import "ServiceModel.h"
#import "VetModel.h"
#import "UserManager.h"
#import "PPHUD.h"
#import "PPFunc.h"
@import FirebaseFunctions;

static NSString * const PPUniversalSwiftUIStockNotificationCallableName =
    @"registerStockNotificationRequest";

static NSString *PPUniversalSwiftUISafeString(id value)
{
    if ([value isKindOfClass:NSString.class]) {
        return [(NSString *)value stringByTrimmingCharactersInSet:
                NSCharacterSet.whitespaceAndNewlineCharacterSet];
    }
    if ([value isKindOfClass:NSNumber.class]) {
        return [(NSNumber *)value stringValue];
    }
    return @"";
}

static NSString *PPUniversalSwiftUIItemIdentifier(PPUniversalCellViewModel *viewModel)
{
    if ([viewModel.ModelObject isKindOfClass:PetAccessory.class]) {
        return ((PetAccessory *)viewModel.ModelObject).accessoryID ?: @"";
    }
    return viewModel.ModelID ?: @"";
}

static NSString *PPUniversalSwiftUICompactNumber(NSNumber *number)
{
    if (!number) {
        return @"";
    }
    double value = number.doubleValue;
    if (!isfinite(value)) {
        return @"";
    }
    if (fabs(value - round(value)) < 0.0001) {
        return [NSString stringWithFormat:@"%.0f", value];
    }
    return [NSString stringWithFormat:@"%.2f", value];
}

@implementation PPCornerBlurView

- (void)layoutSubviews
{
    [super layoutSubviews];

    self.blurView.frame = self.bounds;

    for (CALayer *sublayer in self.layer.sublayers) {
        if ([sublayer.name isEqualToString:@"pp.cornerBlur.tint"]) {
            sublayer.frame = self.bounds;
        }
    }

    if (self.layoutSubviewsBlock) {
        self.layoutSubviewsBlock();
    }
}

- (void)applyBlurStyle:(UIBlurEffectStyle)style
             tintColor:(nullable UIColor *)tintColor
{
    if (self.blurView.superview != self) {
        UIVisualEffectView *blurView =
            [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:style]];
        blurView.userInteractionEnabled = NO;
        blurView.translatesAutoresizingMaskIntoConstraints = NO;
        [self insertSubview:blurView atIndex:0];
        self.blurView = blurView;
        [NSLayoutConstraint activateConstraints:@[
            [blurView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [blurView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [blurView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [blurView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
        ]];
    } else {
        self.blurView.effect = [UIBlurEffect effectWithStyle:style];
    }

    CALayer *existingTint = nil;
    for (CALayer *sublayer in self.layer.sublayers) {
        if ([sublayer.name isEqualToString:@"pp.cornerBlur.tint"]) {
            existingTint = sublayer;
            break;
        }
    }

    if (tintColor) {
        
        if (!existingTint) {
            existingTint = [CALayer layer];
            existingTint.name = @"pp.cornerBlur.tint";
            [self.layer addSublayer:existingTint];
        }
        existingTint.backgroundColor = tintColor.CGColor;
        existingTint.frame = self.bounds;
    } else {
        [existingTint removeFromSuperlayer];
    }
}

@end

@implementation PPUniversalCellSwiftUIBridge

+ (NSString *)localizedStringForKey:(NSString *)key fallback:(NSString *)fallback
{
    NSString *value = [Language get:key alter:nil];
    return value.length > 0 ? value : (fallback ?: @"");
}

+ (BOOL)isRightToLeft
{
    return Language.isRTL;
}

+ (BOOL)isUserLoggedIn
{
    return UserManager.sharedManager.isUserLoggedIn;
}

+ (void)showLoginPrompt
{
    [UserManager showPromptOnTopController];
}

+ (BOOL)isAccessoryViewModel:(PPUniversalCellViewModel *)viewModel
{
    return [viewModel.ModelObject isKindOfClass:PetAccessory.class];
}

+ (BOOL)isUsedAccessoryViewModel:(PPUniversalCellViewModel *)viewModel
{
    if (![self isAccessoryViewModel:viewModel]) {
        return NO;
    }
    PetAccessory *accessory = (PetAccessory *)viewModel.ModelObject;
    return accessory.condition == AccessConditionsUsed;
}

+ (BOOL)isAdvertisementViewModel:(PPUniversalCellViewModel *)viewModel
{
    return [viewModel.ModelObject isKindOfClass:PetAd.class] ||
           [self isUsedAccessoryViewModel:viewModel] ||
           viewModel.modelContext == PPCellForAds ||
           viewModel.modelContext == PPCellForHomeAds;
}

+ (BOOL)isServiceLikeViewModel:(PPUniversalCellViewModel *)viewModel
{
    return [viewModel.ModelObject isKindOfClass:ServiceModel.class] ||
           [viewModel.ModelObject isKindOfClass:VetModel.class] ||
           viewModel.modelContext == PPCellForServices ||
           viewModel.modelContext == PPCellForVets;
}

+ (BOOL)usesQuantityControlForViewModel:(PPUniversalCellViewModel *)viewModel
{
    if (![self isAccessoryViewModel:viewModel]) {
        return NO;
    }
    PetAccessory *accessory = (PetAccessory *)viewModel.ModelObject;
    return accessory.condition != AccessConditionsUsed;
}

+ (BOOL)prefersContainedImageForViewModel:(PPUniversalCellViewModel *)viewModel
{
    return [self isAccessoryViewModel:viewModel] ||
           viewModel.cellSection == CellSectionAccessories ||
           viewModel.cellSection == CellSectionFood;
}

+ (BOOL)showsDiscountPresentationForViewModel:(PPUniversalCellViewModel *)viewModel
{
    if (![self isAccessoryViewModel:viewModel]) {
        return viewModel.modelContext == PPCellForMarket ||
               viewModel.modelContext == PPCellForContextAccessory;
    }
    PetAccessory *accessory = (PetAccessory *)viewModel.ModelObject;
    return !accessory.isFood && !accessory.isPetMedicine;
}

+ (NSInteger)stockLimitForViewModel:(PPUniversalCellViewModel *)viewModel
{
    if ([self isAccessoryViewModel:viewModel]) {
        return MAX(((PetAccessory *)viewModel.ModelObject).quantity, 0);
    }
    return MAX(viewModel.itemQuantitiy, 0);
}

+ (NSInteger)cartQuantityForViewModel:(PPUniversalCellViewModel *)viewModel
{
    NSInteger quantity = 0;
    if ([self isAccessoryViewModel:viewModel]) {
        quantity = [CartManager.sharedManager
                    quantityForAccessory:(PetAccessory *)viewModel.ModelObject];
    } else {
        NSString *itemID = PPUniversalSwiftUIItemIdentifier(viewModel);
        if (itemID.length > 0) {
            CartItem *item = [CartManager.sharedManager getCartItemForItemID:itemID];
            quantity = MAX(item.quantity, 0);
        }
    }

    NSInteger stock = [self stockLimitForViewModel:viewModel];
    return stock > 0 ? MIN(quantity, stock) : quantity;
}

+ (NSString *)favoritesCollectionForContext:(PPCellContext)context
{
    switch (context) {
        case PPCellForMarket:
        case PPCellForFood:
        case PPCellForContextAccessory:
            return @"favoritesAccessories";
        case PPCellForVets:
            return @"favoritesVets";
        case PPCellForServices:
            return @"favoritesServices";
        case PPCellForHomeAds:
        case PPCellForAds:
        case PPCellForAdopt:
        default:
            return @"favoritesAds";
    }
}

+ (NSString *)displaySubtitleForViewModel:(PPUniversalCellViewModel *)viewModel
                                  context:(PPCellContext)context
                         horizontalLayout:(BOOL)horizontalLayout
                         dataViewPresenter:(BOOL)dataViewPresenter
                            showsSubtitle:(BOOL)showsSubtitle
{
    if (horizontalLayout) {
        NSString *descriptionText = @"";
        if ([viewModel.ModelObject isKindOfClass:PetAd.class]) {
            descriptionText = PPUniversalSwiftUISafeString(
                ((PetAd *)viewModel.ModelObject).adDescription);
        } else if ([viewModel.ModelObject isKindOfClass:PetAccessory.class]) {
            descriptionText = PPUniversalSwiftUISafeString(
                ((PetAccessory *)viewModel.ModelObject).desc);
        } else if ([viewModel.ModelObject isKindOfClass:ServiceModel.class]) {
            descriptionText = PPUniversalSwiftUISafeString(
                ((ServiceModel *)viewModel.ModelObject).descriptionText);
        }
        return descriptionText.length > 0
            ? descriptionText
            : PPUniversalSwiftUISafeString(viewModel.subtitle);
    }

    if ([self isAdvertisementViewModel:viewModel]) {
        return dataViewPresenter
            ? PPUniversalSwiftUISafeString(viewModel.location)
            : @"";
    }
    return showsSubtitle ? PPUniversalSwiftUISafeString(viewModel.subtitle) : @"";
}

+ (NSString *)availabilityTextForViewModel:(PPUniversalCellViewModel *)viewModel
                                   context:(PPCellContext)context
                          horizontalLayout:(BOOL)horizontalLayout
                          dataViewPresenter:(BOOL)dataViewPresenter
{
    if ([self isUsedAccessoryViewModel:viewModel]) {
        return [self localizedStringForKey:@"used_accessory_badge"
                                  fallback:[self localizedStringForKey:@"Used" fallback:@"Used"]];
    }
    if (context == PPCellForAdopt) {
        return @"";
    }
    if ([self isAdvertisementViewModel:viewModel]) {
        NSString *identity = PPUniversalSwiftUISafeString(viewModel.subtitle);
        NSString *location = PPUniversalSwiftUISafeString(viewModel.location);
        if (horizontalLayout && identity.length > 0 && location.length > 0) {
            return [NSString stringWithFormat:@"%@ - %@", identity, location];
        }
        if (dataViewPresenter || horizontalLayout) {
            return identity.length > 0 ? identity : location;
        }
        return identity;
    }

    if ([self usesQuantityControlForViewModel:viewModel]) {
        NSInteger stock = [self stockLimitForViewModel:viewModel];
        if (stock <= 0) {
            return [self localizedStringForKey:@"Out of stock" fallback:@"Out of stock"];
        }
        if (stock < 5) {
            return [NSString stringWithFormat:@"%@ %ld %@",
                    [self localizedStringForKey:@"Only" fallback:@"Only"],
                    (long)stock,
                    [self localizedStringForKey:@"left in stock" fallback:@"left in stock"]];
        }
    }

    NSString *availability = PPUniversalSwiftUISafeString(viewModel.availabilityText);
    return availability.length > 0
        ? availability
        : [self localizedStringForKey:@"Available" fallback:@"Available"];
}

+ (PPUniversalAvailabilityTone)availabilityToneForViewModel:(PPUniversalCellViewModel *)viewModel
                                                    context:(PPCellContext)context
{
    if ([self isUsedAccessoryViewModel:viewModel]) {
        return PPUniversalAvailabilityToneUsed;
    }
    if ([self usesQuantityControlForViewModel:viewModel]) {
        NSInteger stock = [self stockLimitForViewModel:viewModel];
        if (stock <= 0) {
            return PPUniversalAvailabilityToneUnavailable;
        }
        if (stock < 5) {
            return PPUniversalAvailabilityToneLimited;
        }
        return PPUniversalAvailabilityToneAvailable;
    }

    NSString *lower = viewModel.availabilityText.lowercaseString;
    BOOL unavailable = [lower containsString:@"sold"] ||
                       [lower containsString:@"out"] ||
                       [lower containsString:@"نف"] ||
                       [lower containsString:@"غير"];
    return unavailable
        ? PPUniversalAvailabilityToneUnavailable
        : PPUniversalAvailabilityToneAvailable;
}

+ (NSString *)metadataTextForViewModel:(PPUniversalCellViewModel *)viewModel
{
    if ([viewModel.ModelObject isKindOfClass:ServiceModel.class]) {
        ServiceModel *service = (ServiceModel *)viewModel.ModelObject;
        if (service.hasDisplayableRating) {
            return [NSString stringWithFormat:@"%.1f",
                    MAX(service.ratingValue.doubleValue, 0.0)];
        }
    }

    if ([viewModel.ModelObject isKindOfClass:PetAccessory.class]) {
        PetAccessory *accessory = (PetAccessory *)viewModel.ModelObject;
        NSString *weightText = PPUniversalSwiftUISafeString(accessory.weightText);
        if (weightText.length > 0) {
            return weightText;
        }
        NSString *number = PPUniversalSwiftUICompactNumber(accessory.weight);
        NSString *unit = PPUniversalSwiftUISafeString(accessory.weightUnit);
        if (number.length > 0) {
            return unit.length > 0
                ? [NSString stringWithFormat:@"%@ %@", number, unit]
                : number;
        }
    }
    return nil;
}

+ (NSString *)metadataSystemImageForViewModel:(PPUniversalCellViewModel *)viewModel
{
    if ([viewModel.ModelObject isKindOfClass:ServiceModel.class] &&
        [(ServiceModel *)viewModel.ModelObject hasDisplayableRating]) {
        return @"star.fill";
    }
    return [self metadataTextForViewModel:viewModel].length > 0
        ? @"scalemass.fill"
        : nil;
}

+ (void)registerStockNotificationForViewModel:(PPUniversalCellViewModel *)viewModel
                                    completion:(void (^)(BOOL))completion
{
    NSString *itemID = PPUniversalSwiftUIItemIdentifier(viewModel);
    if (itemID.length == 0) {
        [PPHUD showError:[self localizedStringForKey:@"stock_notify_item_unavailable"
                                            fallback:@"We could not identify this item right now."]];
        [PPFunc triggerWarningHaptic];
        if (completion) {
            completion(NO);
        }
        return;
    }

    NSMutableDictionary *payload = [@{
        @"itemId": itemID,
        @"source": @"ios_market_cell",
        @"locale": Language.isRTL ? @"ar" : @"en"
    } mutableCopy];
    if (viewModel.title.length > 0) {
        payload[@"clientItemTitle"] = viewModel.title;
    }

    [PPHUD showLoading:[self localizedStringForKey:@"notify_me_loading"
                                          fallback:@"Saving alert"]];

    FIRHTTPSCallable *callable = [[FIRFunctions functionsForRegion:@"us-central1"]
                                  HTTPSCallableWithName:
                                  PPUniversalSwiftUIStockNotificationCallableName];
    callable.timeoutInterval = 30.0;
    [callable callWithObject:payload
                  completion:^(FIRHTTPSCallableResult * _Nullable result,
                               NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [PPHUD showError:[self localizedStringForKey:@"stock_notify_failed"
                                                    fallback:@"We could not save this alert. Try again."]];
                [PPFunc triggerWarningHaptic];
                if (completion) {
                    completion(NO);
                }
                return;
            }

            NSDictionary *response =
                [result.data isKindOfClass:NSDictionary.class] ? result.data : @{};
            NSString *status =
                [response[@"status"] isKindOfClass:NSString.class] ? response[@"status"] : @"";
            if ([status isEqualToString:@"already_available"]) {
                [PPHUD showInfo:[self localizedStringForKey:@"stock_notify_already_available"
                                                   fallback:@"This item is available now."]];
                [PPFunc triggerMediumHaptic];
                if (completion) {
                    completion(NO);
                }
                return;
            }

            NSString *successKey = [status isEqualToString:@"already_registered"]
                ? @"stock_notify_already_registered"
                : @"stock_notify_success";
            NSString *message = [self localizedStringForKey:successKey
                                                   fallback:@"We will notify you when it is back."];
            if ([status isEqualToString:@"already_registered"]) {
                [PPHUD showInfo:message];
            } else {
                [PPHUD showSuccess:message];
            }
            [PPFunc triggerMediumHaptic];
            if (completion) {
                completion(YES);
            }
        });
    }];
}

@end
