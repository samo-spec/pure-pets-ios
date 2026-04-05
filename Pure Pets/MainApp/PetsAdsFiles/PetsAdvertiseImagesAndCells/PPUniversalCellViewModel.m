//
//  PPUniversalCellViewModel.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 01/01/2026.
//

#import "PPUniversalCellViewModel.h"
@import QuartzCore;
#pragma mark - ViewModel

@implementation PPUniversalCellViewModel



- (instancetype)initWithModel:(id)model ppDataSection:(PPDataSection)ppDataSection
{
    
    PPCellContext context = PPCellForAds;
    if(ppDataSection == PPDataSectionAds) context = PPCellForAds;
    else if(ppDataSection == PPDataSectionAccessories) context = PPCellForMarket;
    else if(ppDataSection == PPDataSectionFood) context = PPCellForFood;
    //else if(ppDataSection == PPDataSectionVets) context = PPCellForVets;
    else if(ppDataSection == PPDataSectionServices) context = PPCellForServices;
    
    return  [self initWithModel:model context:context];
}
- (instancetype)initWithModel:(id)model
                      context:(PPCellContext)context
{
    self = [super init];
    if (!self) return nil;

    // ✅ Defaults
    _placeholder = [UIImage imageNamed:@"placeholder"];
    _isOwner = NO;
    _hasOffer = NO;
    _isNew = NO;
    _imageSize = CGSizeZero;
    _ModelID = [NSString stringWithFormat:@"%p", model];
    _priceText = @"";
    _subtitle = @"";
    _imageURL = nil;
    _modelContext = context;
    _preferredAspectRatio = 0; // 0 = unspecified
    _contextualReasonText = nil;
    _contextualReasonIconName = nil;
    
    
   // NSLog(@"modelPPPPP %p", model);
    /*
     typedef NS_ENUM(NSInteger, PPCellContext) {
         PPCellForMarket = 0,
         PPCellForAds,
         PPCellForFood,
         PPCellForVets,
         PPCellForServices
     };
     
     PPSectionAccess,
     PPSectionAds,
     PPSectionFood,
     PPSectionVets,
     PPSectionServices
     
     */
    
    
    // ===============================
    // Image size & aspect ratio
    // ===============================
    CGSize fallbackSize = CGSizeMake(1, 1); // safe default
 
    
    // Map context to sections without mixing enum types
    _cellSection = CellSectionAds; // default
    PPSection ppSection = PPSectionAds;        // default

    switch (context) {
        case PPCellForMarket:
            _cellSection = CellSectionAccessories;
            ppSection = PPSectionAccess;
            break;
        case PPCellForAds:
            _cellSection = CellSectionAds;
            ppSection = PPSectionAds;
            break;
        case PPCellForFood:
            _cellSection = CellSectionFood; // update if there is a specific CellSection for Food
            ppSection = PPSectionFood;
            break;
        case PPCellForVets:
            _cellSection = CellSectionVet; // update if there is a specific CellSection for Vets
            ppSection = PPSectionVets;
            break;
        case PPCellForServices:
            _cellSection = CellSectionServices; // update if there is a specific CellSection for Services
            ppSection = PPSectionServices;
            break;
        default:
            break;
    }
    
    
   
    // 🐾 PetAd
    // 🐾 PetAd
    if ([model isKindOfClass:[PetAd class]]) {
        PetAd *ad = model;

        _title   = ad.adTitle ?: kLang(@"UntitledAd");
        _ModelID = ad.adID;

        if (ad.imageItems.count > 0) {
            PetImageItem *item = ad.imageItems.firstObject;
            _imageURL  = item.url;
            _blurHash = item.blurHash;
            if (item.width > 0 && item.height > 0) {
                _imageSize = CGSizeMake(item.width, item.height);
            } else {
                _imageSize = fallbackSize;
            }
        } else {
            _imageSize = fallbackSize;
        }

        _priceText = ad.price
            ? [NSString stringWithFormat:@"%@ %@", ad.price, kLang(@"Rials")]
            : kLang(@"NoPrice");

        _finalPrice = ad.price;
        _isOwner = [PPCurrentUser.ID isEqualToString:ad.ownerID];
        NSString *resolvedLocation = ad.locationName;
        if (resolvedLocation.length == 0 && ad.adLocation > 0) {
            resolvedLocation = [CitiesManager.shared cityNameForID:ad.adLocation];
        }
        _location = resolvedLocation ?: @"";
       

        _ModelObject = ad;
        _cellSection = CellSectionAds;
        _ppSection   = PPSectionAds;
    }

    // 🧩 PetAccessory
    else if ([model isKindOfClass:[PetAccessory class]]) {
        PetAccessory *acc = model;

        _title = acc.name ?: kLang(@"UntitledAccessory");
        _ModelID = acc.accessoryID;
        _imageURL = acc.imageURLsArray.firstObject;
        _priceText = acc.price ? [NSString stringWithFormat:@"%@", acc.price] : kLang(@"NoPrice");

        _price = acc.price;
        _finalPrice = acc.finalPrice;
        _discountPercent = acc.discountPercent;
        _discountAmount = acc.discountAmount;
        _stockStatusText = acc.stockStatusText;
        _itemQuantitiy = acc.quantity;

        _isOwner = NO;//[[PPCurrentUser ID] isEqualToString:acc.ownerID];
        _hasOffer = acc.hasOffer;
        _isNew = acc.isNew;

        _ModelObject = acc;
        _ppSection = ppSection;
        _blurHash = acc.blurHash;
        _imageSize = fallbackSize;

    }

    // 🧰 ServiceModel
    else if ([model isKindOfClass:[ServiceModel class]]) {
        ServiceModel *svc = model;

        _title = svc.title ?: kLang(@"UntitledService");
        _ModelID = svc.serviceID;
        _imageURL = svc.imageURL;
        _price = @(svc.price);
        _finalPrice = @(svc.price);
         _isOwner =  NO;//[[PPCurrentUser ID] isEqualToString:svc.serviceOwnerID];
        _ModelObject = svc;
        _cellSection = CellSectionServices;
        _ppSection = PPSectionServices;
        _blurHash = svc.blurHash;
        _imageSize = fallbackSize;

    }

    // 🏥 VetModel
    else if ([model isKindOfClass:[VetModel class]]) {
        VetModel *vet = model;

        _title = vet.title ?: kLang(@"VetClinic");
        _ModelID = vet.vetID;
        _imageURL = vet.logoURL;
        _subtitle = vet.descriptionText ?: @"";

        _price = @(vet.vetCost);
        _finalPrice = @(vet.vetCost);
        _isOwner =  NO;//[[PPCurrentUser ID] isEqualToString:vet.userID];

        _ModelObject = vet;
        _cellSection = CellSectionVet;
        _ppSection = PPSectionVets;
        _blurHash = vet.blurHash;

        _imageSize = fallbackSize;

    }

    // ❌ Unknown
    else {
        _title = kLang(@"UnknownItem");
        _ModelID = @"";
    }
    // Final safety
    if (_imageSize.width <= 0 || _imageSize.height <= 0) {
        _imageSize = fallbackSize;
    }
    
    
    // 🔒 Force sane aspect ratio (Pinterest-safe)
    if (_imageSize.width > 0 && _imageSize.height > 0) {
        _preferredAspectRatio = _imageSize.height / _imageSize.width;
    }

    // Clamp extreme ratios
    if (_preferredAspectRatio < 0.75) _preferredAspectRatio = 0.75;
    if (_preferredAspectRatio > 1.6)  _preferredAspectRatio = 1.6;

    // Ultimate fallback
    if (_preferredAspectRatio <= 0) {
        _preferredAspectRatio = 1.15;
    }

    // 🔒 Max height safeguard (prevents ultra-tall cells)
    CGFloat maxHeight = 180.0;
    if (_imageSize.width > 0) {
        CGFloat computedHeight = _imageSize.width * _preferredAspectRatio;
        if (computedHeight > maxHeight) {
            _preferredAspectRatio = maxHeight / _imageSize.width;
        }
    }
    
    return self;
}


- (instancetype)initSkeleton
{
    self = [super init];
    if (!self) return nil;

    // ===== Skeleton defaults =====
    _placeholder = [UIImage imageNamed:@"placeholder"];
    _title = @"";
    _subtitle = @"";
    _priceText = @"";
    _imageURL = nil;
    _imageSize = CGSizeMake(1, 1.2);
    _preferredAspectRatio = 1.2;
    _contextualReasonText = nil;
    _contextualReasonIconName = nil;

    _isOwner = NO;
    _hasOffer = NO;
    _isNew = NO;

    _ModelID = [NSUUID UUID].UUIDString;
    _ModelObject = nil;

    // Skeleton is visually treated as Ads-style card
    _modelContext = PPCellForAds;
    _cellSection = CellSectionAds;
    _ppSection = PPSectionAds;

    // No discounts / stock info
    _price = nil;
    _finalPrice = nil;
    _discountPercent = 0;
    _discountAmount = 0;
    _stockStatusText = nil;
    _itemQuantitiy = 0;

    return self;
}

@end
