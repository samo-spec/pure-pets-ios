#import "PPUniversalCellViewModel.h"
#import "PetAccessory.h"
#import "PetAd.h"
#import "ServiceModel.h"
#import "VetModel.h"
#import "AdoptPetModel.h"
#import "CitiesManager.h"
#import "MainKindsModel.h"
#import "SubKindModel.h"

static NSString *PPUniversalLocalizedString(NSString *key, NSString *fallback)
{
    NSString *value = kLang(key);
    return value.length > 0 ? value : fallback;
}

static NSString *PPUniversalLocalizedPair(NSString *english, NSString *arabic)
{
    NSString *fallbackEnglish = english ?: @"";
    NSString *fallbackArabic = arabic ?: fallbackEnglish;
    return Language.isRTL ? fallbackArabic : fallbackEnglish;
}

static CGFloat PPUniversalClampedAspectRatio(CGSize size, CGFloat fallback)
{
    CGFloat ratio = fallback;
    if (size.width > 0.0 && size.height > 0.0) {
        ratio = size.height / size.width;
    }
    ratio = MAX(0.68, MIN(1.24, ratio));
    return ratio > 0.0 ? ratio : fallback;
}

static NSString *PPUniversalSafeString(id value)
{
    if ([value isKindOfClass:NSString.class]) {
        return (NSString *)value;
    }
    if ([value isKindOfClass:NSNumber.class]) {
        return [(NSNumber *)value stringValue];
    }
    return @"";
}

static NSDictionary *PPUniversalFirstMediaMetadata(NSArray<NSDictionary *> *metadata)
{
    if (!PPReusableVideoMediaEnabled()) {
        return nil;
    }
    NSDictionary *fallback = nil;
    for (NSDictionary *item in metadata) {
        if (![item isKindOfClass:NSDictionary.class]) {
            continue;
        }
        if (!fallback) {
            fallback = item;
        }
        NSString *type = PPUniversalSafeString(item[@"media_type"]).lowercaseString;
        if ([type isEqualToString:@"video"]) {
            return item;
        }
    }
    return fallback;
}

static NSString *PPUniversalShortAgeText(NSNumber * _Nullable ageInMonths)
{
    NSInteger months = MAX(ageInMonths.integerValue, 0);
    if (months <= 0) {
        return @"";
    }

    if (months < 12) {
        NSString *monthLabel = months == 1
            ? PPUniversalLocalizedPair(@"m", @"ش")
            : PPUniversalLocalizedPair(@"m", @"ش");
        return [NSString stringWithFormat:@"%ld %@", (long)months, monthLabel];
    }

    NSInteger years = months / 12;
    NSInteger remainingMonths = months % 12;
    NSString *yearLabel = years == 1
        ? PPUniversalLocalizedPair(@"y", @"س")
        : PPUniversalLocalizedPair(@"y", @"س");

    if (remainingMonths == 0) {
        return [NSString stringWithFormat:@"%ld %@", (long)years, yearLabel];
    }

    NSString *monthLabel = remainingMonths == 1
        ? PPUniversalLocalizedPair(@"m", @"ش")
        : PPUniversalLocalizedPair(@"m", @"ش");
    return [NSString stringWithFormat:@"%ld %@ · %ld %@",
            (long)years,
            yearLabel,
            (long)remainingMonths,
            monthLabel];
}

static NSString *PPUniversalAccessorySubtitle(PetAccessory *accessory)
{
    NSMutableArray<NSString *> *parts = [NSMutableArray array];

    NSString *typeText = [PetAccessory typeTextForAccessory:accessory];
    if (typeText.length > 0) {
        [parts addObject:typeText];
    }

    NSString *conditionText = [PetAccessory conditionTextForAccessory:accessory];
    if (conditionText.length > 0 &&
        ![conditionText isEqualToString:PPUniversalLocalizedString(@"Not specified", @"Not specified")]) {
        [parts addObject:conditionText];
    }

    return [parts componentsJoinedByString:@" • "];
}

static NSString *PPUniversalAdBadgeText(PetAd *ad)
{
    NSString *kindName = [MainKindsModel kindNameForID:ad.category];
    if (kindName.length > 0) {
        return kindName;
    }
    return PPUniversalLocalizedString(@"Ads", PPUniversalLocalizedPair(@"Ad", @"إعلان"));
}

static NSString *PPUniversalAdSubtitle(PetAd *ad, NSString *locationText)
{
    NSMutableArray<NSString *> *parts = [NSMutableArray array];

    MainKindsModel *kind = [MainKindsModel mainKindModelForID:ad.category];
    if (kind && ad.subcategory > 0) {
        NSString *breedName = [SubKindModel getSubKindName:ad.subcategory subKindsArrayLocal:kind.SubKindsArray];
        if (breedName.length > 0) {
            [parts addObject:breedName];
        }
    }

    NSString *genderText = ad.genderText;
    if (genderText.length > 0) {
        [parts addObject:genderText];
    }

    NSString *ageText = PPUniversalShortAgeText(ad.petAgeMonths);
    if (ageText.length > 0) {
        [parts addObject:ageText];
    }

    if (locationText.length > 0) {
       // [parts addObject:locationText];
    }

    return [parts componentsJoinedByString:@" · "];
}

static NSNumber *PPUniversalPetAdFinalPrice(PetAd *ad)
{
    if (!ad.price) {
        return nil;
    }

    if (!(ad.discountPercent.doubleValue > 0.0)) {
        return ad.price;
    }

    NSDecimalNumber *base = [NSDecimalNumber decimalNumberWithDecimal:ad.price.decimalValue];
    NSDecimalNumber *discount = [NSDecimalNumber decimalNumberWithDecimal:ad.discountPercent.decimalValue];
    NSDecimalNumber *percentage = [discount decimalNumberByDividingBy:[NSDecimalNumber decimalNumberWithString:@"100"]];
    NSDecimalNumber *result = [base decimalNumberByMultiplyingBy:[[NSDecimalNumber one] decimalNumberBySubtracting:percentage]];
    return result;
}

@implementation PPUniversalCellViewModel

- (instancetype)initWithModel:(id)model
                ppDataSection:(PPDataSection)ppDataSection
{
    PPCellContext context = PPCellForAds;
    switch (ppDataSection) {
        case PPDataSectionAccessories:
            context = PPCellForMarket;
            break;
        case PPDataSectionFood:
            context = PPCellForFood;
            break;
        case PPDataSectionServices:
            context = PPCellForServices;
            break;
        case PPDataSectionAds:
        default:
            context = PPCellForAds;
            break;
    }
    return [self initWithModel:model context:context];
}

- (instancetype)initWithModel:(id)model
                      context:(PPCellContext)context
{
    self = [super init];
    if (!self) {
        return nil;
    }

    _placeholder = [UIImage imageNamed:@"placeholder"];
    _title = @"";
    _subtitle = @"";
    _priceText = @"";
    _discountText = @"";
    _blurHash = @"";
    _currencyCode = PPUniversalLocalizedString(@"Rials", @"QAR");
    _availabilityText = @"";
    _badgeText = @"";
    _stockStatusText = @"";
    _location = @"";
    _isVideoMedia = NO;
    _videoURL = @"";
    _videoThumbnailURL = @"";
    _mediaMetadata = nil;
    _modelContext = context;
    _ModelObject = model;
    _ModelID = [NSString stringWithFormat:@"%p", model];
    _modelType = NSStringFromClass([model class]);
    _preferredAspectRatio = 0.90;
    _imageSize = CGSizeMake(1.0, 1.0);
    _itemQuantitiy = 0;
    _skeleton = NO;
    _publiclyVisible = YES;

    switch (context) {
        case PPCellForMarket:
        case PPCellForContextAccessory:
            _cellSection = CellSectionAccessories;
            _ppSection = PPSectionAccess;
            break;
        case PPCellForFood:
            _cellSection = CellSectionFood;
            _ppSection = PPSectionFood;
            break;
        case PPCellForServices:
            _cellSection = CellSectionServices;
            _ppSection = PPSectionServices;
            break;
        case PPCellForVets:
            _cellSection = CellSectionVet;
            _ppSection = PPSectionVets;
            break;
        case PPCellForHomeAds:
        case PPCellForAds:
        case PPCellForAdopt:
        default:
            _cellSection = CellSectionAds;
            _ppSection = PPSectionAds;
            break;
    }

    NSString *currentUserID = UserManager.sharedManager.currentUser.ID ?: @"";

    if ([model isKindOfClass:[PetAccessory class]]) {
        PetAccessory *accessory = (PetAccessory *)model;
        PetImageItem *firstImage = accessory.imageItems.firstObject;
        NSDictionary *firstMedia = PPUniversalFirstMediaMetadata(accessory.imageMeta);
        NSString *firstMediaType = PPUniversalSafeString(firstMedia[@"media_type"]).lowercaseString;
        BOOL firstIsVideo = PPReusableVideoMediaEnabled() && [firstMediaType isEqualToString:@"video"];
        NSString *firstMediaURL = PPUniversalSafeString(firstMedia[@"url"]);
        NSString *firstAccessoryImageURL = PPUniversalSafeString(firstImage.url);
        if (firstAccessoryImageURL.length == 0) {
            firstAccessoryImageURL = PPUniversalSafeString(accessory.imageURLsArray.firstObject);
        }

        _title = accessory.name ?: PPUniversalLocalizedString(@"UntitledAccessory", PPUniversalLocalizedPair(@"Untitled accessory", @"منتج بدون اسم"));
        _subtitle = PPUniversalAccessorySubtitle(accessory);
        _ModelID = accessory.accessoryID.length > 0 ? accessory.accessoryID : _ModelID;
        _mediaMetadata = firstMedia;
        _isVideoMedia = firstIsVideo;
        _videoURL = firstIsVideo ? PPUniversalSafeString(firstMedia[@"url"]) : @"";
        _videoThumbnailURL = firstIsVideo ? PPUniversalSafeString(firstMedia[@"thumbnail_url"]) : @"";
        _imageURL = firstIsVideo && _videoThumbnailURL.length > 0
            ? _videoThumbnailURL
            : (firstMediaURL.length > 0 ? firstMediaURL : firstAccessoryImageURL);
        _blurHash = accessory.blurHash ?: @"";
        _price = accessory.price;
        _finalPrice = accessory.finalPrice;
        _discountPercent = accessory.discountPercent;
        _discountAmount = accessory.discountAmount;
        _itemQuantitiy = MAX(accessory.quantity, 0);
        _stockStatusText = accessory.stockStatusText ?: @"";
        if (accessory.quantity <= 0) {
            _availabilityText = PPUniversalLocalizedString(@"Out of stock", PPUniversalLocalizedPair(@"Out of stock", @"غير متوفر"));
        } else if (accessory.quantity < 5) {
            _availabilityText = [NSString stringWithFormat:@"%@ %ld %@",
                                 PPUniversalLocalizedString(@"Only", PPUniversalLocalizedPair(@"Only", @"متبقي")),
                                 (long)accessory.quantity,
                                 PPUniversalLocalizedString(@"left in stock", PPUniversalLocalizedPair(@"left in stock", @"في المخزون"))];
        } else {
            _availabilityText = _stockStatusText.length > 0
                ? _stockStatusText
                : PPUniversalLocalizedString(@"Available", PPUniversalLocalizedPair(@"Available", @"متوفر"));
        }
        _badgeText = [PetAccessory typeTextForAccessory:accessory] ?: @"";
        _isOwner = currentUserID.length > 0 && [currentUserID isEqualToString:accessory.ownerID];
        _publiclyVisible = accessory.showInAppMarket && !accessory.isDeleted && !accessory.isBlocked && !accessory.isDisabled;
        _hasOffer = accessory.hasOffer;
        _isNew = accessory.isNew;
        _contextualReasonText = accessory.isNew
            ? PPUniversalLocalizedString(@"New", PPUniversalLocalizedPair(@"New", @"جديد"))
            : @"";
        _priceText = [GM formatPrice:(accessory.finalPrice ?: accessory.price)
                        currencyCode:_currencyCode] ?: @"";
        if (firstIsVideo) {
            CGFloat thumbWidth = [firstMedia[@"thumbnail_width"] doubleValue];
            CGFloat thumbHeight = [firstMedia[@"thumbnail_height"] doubleValue];
            CGFloat width = thumbWidth > 0.0 ? thumbWidth : [firstMedia[@"width"] doubleValue];
            CGFloat height = thumbHeight > 0.0 ? thumbHeight : [firstMedia[@"height"] doubleValue];
            _imageSize = CGSizeMake(MAX(width, 1.0), MAX(height, 1.0));
        } else if (firstImage) {
            _imageSize = CGSizeMake(MAX(firstImage.width, 1.0), MAX(firstImage.height, 1.0));
        }
        _preferredAspectRatio = PPUniversalClampedAspectRatio(_imageSize, 0.78);
    } else if ([model isKindOfClass:[PetAd class]]) {
        PetAd *ad = (PetAd *)model;
        PetImageItem *firstImage = ad.imageItems.firstObject;
        NSDictionary *firstMedia = PPUniversalFirstMediaMetadata(ad.imageItemsRaw);
        NSString *firstMediaType = PPUniversalSafeString(firstMedia[@"media_type"]).lowercaseString;
        BOOL firstIsVideo = PPReusableVideoMediaEnabled() && [firstMediaType isEqualToString:@"video"];
        NSString *firstAdImageURL = PPUniversalSafeString(firstImage.url);
        if (firstAdImageURL.length == 0) {
            firstAdImageURL = PPUniversalSafeString(ad.imageURLs.firstObject);
        }

        NSString *resolvedLocation = ad.locationName ?: @"";
        if (resolvedLocation.length == 0 && ad.adLocation > 0) {
            resolvedLocation = [CitiesManager.shared cityNameForID:ad.adLocation] ?: @"";
        }

        _title = ad.adTitle ?: PPUniversalLocalizedString(@"UntitledAd", PPUniversalLocalizedPair(@"Untitled ad", @"إعلان بدون عنوان"));
        _ModelID = ad.adID.length > 0 ? ad.adID : _ModelID;
        _mediaMetadata = firstMedia;
        _isVideoMedia = firstIsVideo;
        _videoURL = firstIsVideo ? PPUniversalSafeString(firstMedia[@"url"]) : @"";
        _videoThumbnailURL = firstIsVideo ? PPUniversalSafeString(firstMedia[@"thumbnail_url"]) : @"";
        _imageURL = firstIsVideo && _videoThumbnailURL.length > 0 ? _videoThumbnailURL : firstAdImageURL;
        _blurHash = firstImage.blurHash ?: ad.blurHash ?: @"";
        if (firstIsVideo) {
            CGFloat thumbWidth = [firstMedia[@"thumbnail_width"] doubleValue];
            CGFloat thumbHeight = [firstMedia[@"thumbnail_height"] doubleValue];
            CGFloat width = thumbWidth > 0.0 ? thumbWidth : [firstMedia[@"width"] doubleValue];
            CGFloat height = thumbHeight > 0.0 ? thumbHeight : [firstMedia[@"height"] doubleValue];
            _imageSize = CGSizeMake(MAX(width, 1.0), MAX(height, 1.0));
        } else {
            _imageSize = CGSizeMake(MAX(firstImage.width, 1.0), MAX(firstImage.height, 1.0));
        }
        _location = resolvedLocation;
        _subtitle = PPUniversalAdSubtitle(ad, resolvedLocation);
        _price = ad.price;
        _finalPrice = PPUniversalPetAdFinalPrice(ad);
        _discountPercent = ad.discountPercent;
        _priceText = _finalPrice ? [GM formatPrice:_finalPrice currencyCode:_currencyCode] : @"";
        _availabilityText = ad.isSold
            ? PPUniversalLocalizedString(@"Sold", PPUniversalLocalizedPair(@"Sold", @"تم البيع"))
            : PPUniversalLocalizedString(@"Available", PPUniversalLocalizedPair(@"Available", @"متوفر"));
        _badgeText = PPUniversalAdBadgeText(ad);
        _isOwner = currentUserID.length > 0 && [currentUserID isEqualToString:ad.ownerID];
        _publiclyVisible = ad.visibility == PetAdVisibilityPublic && !ad.isDeleted && !ad.isBlocked;
        _isNew = ad.isNew;
        _hasOffer = ad.isDiscounted;
        if (ad.priorityScore.doubleValue > 0.0 || context == PPCellForHomeAds) {
            _contextualReasonText = PPUniversalLocalizedString(@"Promoted", PPUniversalLocalizedPair(@"Promoted", @"مميز"));
        } else if (ad.isNew) {
            _contextualReasonText = PPUniversalLocalizedString(@"New", PPUniversalLocalizedPair(@"New", @"جديد"));
        }
        _preferredAspectRatio = PPUniversalClampedAspectRatio(_imageSize, 0.98);
    } else if ([model isKindOfClass:[AdoptPetModel class]]) {
        AdoptPetModel *pet = (AdoptPetModel *)model;
        NSDictionary *firstMedia = PPUniversalFirstMediaMetadata(pet.imageMeta);
        NSString *firstMediaType = PPUniversalSafeString(firstMedia[@"media_type"]).lowercaseString;
        BOOL firstIsVideo = PPReusableVideoMediaEnabled() && [firstMediaType isEqualToString:@"video"];
        NSString *firstImage = [pet.imageURLs.firstObject isKindOfClass:NSString.class] ? pet.imageURLs.firstObject : @"";
        NSString *cityName = pet.mCityName.length > 0 ? pet.mCityName : ([CitiesManager.shared cityNameForID:pet.cityID] ?: @"");

        _title = pet.name ?: PPUniversalLocalizedString(@"AdoptPet", PPUniversalLocalizedPair(@"Adoption pet", @"حيوان للتبني"));
        _subtitle = pet.details.length > 0 ? pet.details : cityName;
        _ModelID = pet.documentID.length > 0 ? pet.documentID : _ModelID;
        _mediaMetadata = firstMedia;
        _isVideoMedia = firstIsVideo;
        _videoURL = firstIsVideo ? PPUniversalSafeString(firstMedia[@"url"]) : @"";
        _videoThumbnailURL = firstIsVideo ? PPUniversalSafeString(firstMedia[@"thumbnail_url"]) : @"";
        _imageURL = firstIsVideo && _videoThumbnailURL.length > 0 ? _videoThumbnailURL : firstImage;
        _location = cityName;
        _priceText = @"";
        _availabilityText = PPUniversalLocalizedString(@"Available", PPUniversalLocalizedPair(@"Available", @"متوفر"));
        _badgeText = PPUniversalLocalizedString(@"For Adoption", PPUniversalLocalizedPair(@"For Adoption", @"للتبني"));
        _isOwner = currentUserID.length > 0 && [currentUserID isEqualToString:pet.ownerID];
        _publiclyVisible = pet.visibility == 0;
        if (firstIsVideo) {
            CGFloat thumbWidth = [firstMedia[@"thumbnail_width"] doubleValue];
            CGFloat thumbHeight = [firstMedia[@"thumbnail_height"] doubleValue];
            CGFloat width = thumbWidth > 0.0 ? thumbWidth : [firstMedia[@"width"] doubleValue];
            CGFloat height = thumbHeight > 0.0 ? thumbHeight : [firstMedia[@"height"] doubleValue];
            _imageSize = CGSizeMake(MAX(width, 1.0), MAX(height, 1.0));
        }
        _preferredAspectRatio = PPUniversalClampedAspectRatio(_imageSize, 0.98);
    } else if ([model isKindOfClass:[ServiceModel class]]) {
        ServiceModel *service = (ServiceModel *)model;

        _title = service.title ?: PPUniversalLocalizedString(@"UntitledService", PPUniversalLocalizedPair(@"Untitled service", @"خدمة بدون اسم"));
        _subtitle = service.category.length > 0 ? service.category : service.localizedTypeName;
        _ModelID = service.serviceID.length > 0 ? service.serviceID : _ModelID;
        _imageURL = service.imageURL;
        _blurHash = service.blurHash ?: @"";
        _price = @(MAX(service.price, 0.0));
        _finalPrice = _price;
        _currencyCode = service.currency.length > 0 ? service.currency : _currencyCode;
        _priceText = [GM formatPrice:_finalPrice currencyCode:_currencyCode] ?: @"";
        _availabilityText = service.localizedAvailabilityStatus.length > 0
            ? service.localizedAvailabilityStatus
            : (service.isAvailable
               ? PPUniversalLocalizedString(@"Available", PPUniversalLocalizedPair(@"Available", @"متوفر"))
               : PPUniversalLocalizedString(@"Unavailable", PPUniversalLocalizedPair(@"Unavailable", @"غير متوفر")));
        _badgeText = service.localizedTypeName.length > 0
            ? service.localizedTypeName
            : PPUniversalLocalizedString(@"services", PPUniversalLocalizedPair(@"Service", @"خدمة"));
        _preferredAspectRatio = 0.72;
        _isOwner = currentUserID.length > 0 && [currentUserID isEqualToString:service.serviceOwnerID];
    } else if ([model isKindOfClass:[VetModel class]]) {
        VetModel *vet = (VetModel *)model;

        _title = vet.title ?: PPUniversalLocalizedString(@"VetClinic", PPUniversalLocalizedPair(@"Veterinary clinic", @"عيادة بيطرية"));
        _subtitle = vet.descriptionText ?: @"";
        _ModelID = vet.vetID.length > 0 ? vet.vetID : _ModelID;
        _imageURL = vet.logoURL;
        _blurHash = vet.blurHash ?: @"";
        _price = @(MAX(vet.vetCost, 0.0));
        _finalPrice = _price;
        _priceText = [GM formatPrice:_price currencyCode:_currencyCode] ?: @"";
        _availabilityText = PPUniversalLocalizedString(@"Available", PPUniversalLocalizedPair(@"Available", @"متوفر"));
        _badgeText = PPUniversalLocalizedPair(@"Clinic", @"عيادة");
        _preferredAspectRatio = 0.72;
        _isOwner = currentUserID.length > 0 && [currentUserID isEqualToString:vet.userID];
    } else if (model != nil) {
        _title = PPUniversalLocalizedString(@"UnknownItem", PPUniversalLocalizedPair(@"Unknown item", @"عنصر غير معروف"));
    }

    if (_priceText.length == 0 && _finalPrice != nil) {
        _priceText = [GM formatPrice:_finalPrice currencyCode:_currencyCode] ?: @"";
    }

    if (_discountPercent.doubleValue > 0.0) {
        _discountText = [NSString stringWithFormat:@"%@%%", _discountPercent];
    } else if (_discountAmount.doubleValue > 0.0) {
        NSString *formattedAmount = [GM formatPrice:_discountAmount currencyCode:_currencyCode] ?: _discountAmount.stringValue;
        _discountText = [NSString stringWithFormat:@"%@ %@", PPUniversalLocalizedPair(@"Save", @"وفر"), formattedAmount];
    }

    if (_imageSize.width <= 0.0 || _imageSize.height <= 0.0) {
        _imageSize = CGSizeMake(1.0, MAX(_preferredAspectRatio, 0.75));
    }

    return self;
}

- (instancetype)initSkeleton
{
    return [self initSkeletonForDataSection:PPDataSectionAds];
}

- (instancetype)initSkeletonForDataSection:(PPDataSection)section
{
    self = [super init];
    if (!self) {
        return nil;
    }

    _placeholder = [UIImage imageNamed:@"placeholder"];
    _title = @"";
    _subtitle = @"";
    _priceText = @"";
    _discountText = @"";
    _blurHash = @"";
    _currencyCode = PPUniversalLocalizedString(@"Rials", @"QAR");
    _availabilityText = @"";
    _badgeText = @"";
    _stockStatusText = @"";
    _location = @"";
    _ModelID = [NSUUID UUID].UUIDString;
    _modelType = @"Skeleton";
    _itemQuantitiy = 0;
    _isVideoMedia = NO;
    _videoURL = @"";
    _videoThumbnailURL = @"";
    _mediaMetadata = nil;
    _publiclyVisible = YES;
    _skeleton = YES;

    switch (section) {
        case PPDataSectionAccessories:
            _modelContext = PPCellForMarket;
            _cellSection = CellSectionAccessories;
            _ppSection = PPSectionAccess;
            _preferredAspectRatio = 0.78;
            _imageSize = CGSizeMake(1.0, 0.78);
            break;
        case PPDataSectionFood:
            _modelContext = PPCellForFood;
            _cellSection = CellSectionFood;
            _ppSection = PPSectionFood;
            _preferredAspectRatio = 0.78;
            _imageSize = CGSizeMake(1.0, 0.78);
            break;
        case PPDataSectionServices:
            _modelContext = PPCellForServices;
            _cellSection = CellSectionServices;
            _ppSection = PPSectionServices;
            _preferredAspectRatio = 0.72;
            _imageSize = CGSizeMake(1.0, 0.72);
            break;
        case PPDataSectionAds:
        default:
            _modelContext = PPCellForAds;
            _cellSection = CellSectionAds;
            _ppSection = PPSectionAds;
            _preferredAspectRatio = 0.86;
            _imageSize = CGSizeMake(1.0, 0.86);
            break;
    }

    return self;
}

@end
