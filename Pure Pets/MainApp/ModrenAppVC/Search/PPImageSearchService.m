//
//  PPImageSearchService.m
//  Pure Pets
//
//  Direct search by photo service.
//  Sends compressed image to Firebase callable function: imageSearch.
//  Keep Gemini API key only on Firebase Functions, never in iOS.
//

#import "PPImageSearchService.h"
#import "MainKindsArrayManager.h"
#import "MainKindsModel.h"
#import "PetAccessory.h"
#import "PetAccessoryManager.h"
#import "PPOverlayCoordinator.h"
#import "ServiceModel.h"
#import "ServicesManager.h"
@import FirebaseFunctions;

@interface PPImageSearchService ()
@property (nonatomic, strong) FIRFunctions *functions;
@end

#pragma mark - Pure Lens discovery adapter

static NSString *PPPureLensNormalizedText(NSString *value)
{
    NSString *normalized = [value.lowercaseString stringByReplacingOccurrencesOfString:@"_" withString:@" "];
    normalized = [normalized stringByReplacingOccurrencesOfString:@"-" withString:@" "];
    NSCharacterSet *allowed = [NSCharacterSet alphanumericCharacterSet];
    NSMutableString *result = [NSMutableString stringWithCapacity:normalized.length];
    BOOL previousWasSpace = YES;
    for (NSUInteger index = 0; index < normalized.length; index++) {
        unichar character = [normalized characterAtIndex:index];
        if ([allowed characterIsMember:character]) {
            [result appendFormat:@"%C", character];
            previousWasSpace = NO;
        } else if (!previousWasSpace) {
            [result appendString:@" "];
            previousWasSpace = YES;
        }
    }
    return [result stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static NSArray<NSString *> *PPPureLensSpeciesAliases(NSString *species)
{
    NSString *key = PPPureLensNormalizedText(species);
    NSDictionary<NSString *, NSArray<NSString *> *> *aliases = @{
        @"dog": @[@"dog", @"dogs", @"canine", @"puppy", @"puppies", @"كلب", @"كلاب"],
        @"cat": @[@"cat", @"cats", @"feline", @"kitten", @"kittens", @"قط", @"قطة", @"قطط"],
        @"bird": @[@"bird", @"birds", @"avian", @"parrot", @"طائر", @"طيور", @"عصفور", @"عصافير"],
        @"rabbit": @[@"rabbit", @"rabbits", @"bunny", @"bunnies", @"أرنب", @"ارنب", @"أرانب", @"ارانب"],
        @"fish": @[@"fish", @"fishes", @"aquatic", @"سمك", @"أسماك", @"اسماك"],
        @"reptile": @[@"reptile", @"reptiles", @"turtle", @"snake", @"lizard", @"زاحف", @"زواحف", @"سلحفاة"],
        @"small mammal": @[@"small mammal", @"hamster", @"guinea pig", @"ferret", @"ثديي صغير", @"هامستر"],
        @"horse": @[@"horse", @"horses", @"equine", @"حصان", @"خيول"],
        @"camel": @[@"camel", @"camels", @"جمل", @"جمال"],
        @"sheep": @[@"sheep", @"lamb", @"خروف", @"أغنام", @"اغنام"],
        @"goat": @[@"goat", @"goats", @"ماعز"],
        @"cow": @[@"cow", @"cows", @"cattle", @"بقرة", @"أبقار", @"ابقار"]
    };
    return aliases[key] ?: (key.length > 0 ? @[key] : @[]);
}

static BOOL PPPureLensNameContainsAlias(NSString *normalizedName, NSString *normalizedAlias)
{
    if (normalizedName.length == 0 || normalizedAlias.length == 0) return NO;
    if ([normalizedName isEqualToString:normalizedAlias]) return YES;
    NSString *paddedName = [NSString stringWithFormat:@" %@ ", normalizedName];
    NSString *paddedAlias = [NSString stringWithFormat:@" %@ ", normalizedAlias];
    return [paddedName containsString:paddedAlias];
}

static NSError *PPPureLensDiscoveryError(NSInteger code)
{
    NSString *message = kLang(@"ImageSearchError");
    return [NSError errorWithDomain:@"PurePets.PureLens.Discovery"
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @""}];
}

@interface PPPureLensDiscoveryBridge ()
@property (nonatomic, weak) UIViewController *presenter;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *objectsByIdentity;
@end

@implementation PPPureLensDiscoveryBridge

- (instancetype)initWithPresenter:(UIViewController *)presenter
{
    self = [super init];
    if (self) {
        _presenter = presenter;
        _objectsByIdentity = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)validateSpecies:(NSString *)species
             completion:(void (^)(BOOL supported, NSError * _Nullable error))completion
{
    NSArray<MainKindsModel *> *availableKinds = [[MainKindsArrayManager shared] visibleMainKindsSnapshot];
    if (availableKinds.count > 0) {
        if (completion) completion([self pp_mainKindForSpecies:species] != nil, nil);
        return;
    }

    [[MainKindsArrayManager shared] loadMainDataCompletionHandler:^(int result) {
        if (result == 0) {
            if (completion) completion(NO, PPPureLensDiscoveryError(2005));
            return;
        }
        if (completion) completion([self pp_mainKindForSpecies:species] != nil, nil);
    }];
}

- (void)searchImageData:(NSData *)imageData
             contentType:(NSString *)contentType
                 species:(NSString *)species
                   breed:(NSString * _Nullable)breed
                   limit:(NSInteger)limit
              completion:(void (^)(NSArray<NSDictionary *> * _Nullable items,
                                    NSError * _Nullable error))completion
{
    NSInteger boundedLimit = MAX(1, MIN(limit, 24));
    [self pp_resolveMainKindForSpecies:species allowReload:YES completion:^(MainKindsModel * _Nullable mainKind) {
        if (!mainKind) {
            if (completion) completion(nil, PPPureLensDiscoveryError(2001));
            return;
        }

        [[PPImageSearchService shared] searchWithImageData:imageData
                                               contentType:contentType
                                                      mode:PPImageSearchModeProducts
                                                     limit:@(boundedLimit)
                                                completion:^(NSDictionary * _Nullable response, NSError * _Nullable error) {
            if (error || !response) {
                if (completion) completion(nil, error ?: PPPureLensDiscoveryError(2002));
                return;
            }

            NSArray *rawResults = [response[@"results"] isKindOfClass:NSArray.class]
                ? response[@"results"]
                : @[];
            NSMutableArray<NSString *> *orderedIDs = [NSMutableArray array];
            NSMutableDictionary<NSString *, NSDictionary *> *resultByID = [NSMutableDictionary dictionary];
            for (id value in rawResults) {
                if (![value isKindOfClass:NSDictionary.class]) continue;
                NSDictionary *result = (NSDictionary *)value;
                NSString *kind = [result[@"kind"] isKindOfClass:NSString.class] ? result[@"kind"] : @"";
                NSString *identifier = [result[@"id"] isKindOfClass:NSString.class] ? result[@"id"] : @"";
                if (identifier.length == 0 ||
                    (!([kind isEqualToString:@"product"] || [kind isEqualToString:@"medicine"]))) {
                    continue;
                }
                if (!resultByID[identifier]) [orderedIDs addObject:identifier];
                resultByID[identifier] = result;
            }

            [PetAccessoryManager fetchAccessoriesWithIDs:orderedIDs completion:^(NSArray<PetAccessory *> *accessories) {
                NSMutableDictionary<NSString *, PetAccessory *> *objectByID = [NSMutableDictionary dictionary];
                for (PetAccessory *item in accessories) {
                    if (item.accessoryID.length > 0) objectByID[item.accessoryID] = item;
                }

                NSMutableArray<NSDictionary *> *mapped = [NSMutableArray array];
                for (NSUInteger rank = 0; rank < orderedIDs.count && mapped.count < boundedLimit; rank++) {
                    NSString *identifier = orderedIDs[rank];
                    PetAccessory *item = objectByID[identifier];
                    if (!item || ![self pp_item:item isCompatibleWithMainKindID:mainKind.ID]) continue;
                    NSDictionary *raw = resultByID[identifier] ?: @{};
                    NSNumber *rankScore = [raw[@"rankScore"] isKindOfClass:NSNumber.class]
                        ? raw[@"rankScore"]
                        : nil;
                    NSDictionary *dictionary = [self pp_dictionaryForAccessory:item
                                                                        source:@"imageSearch"
                                                                          rank:rank
                                                                   visualScore:rankScore
                                                                       species:species
                                                                         breed:breed];
                    if (dictionary) [mapped addObject:dictionary];
                }
                if (completion) completion(mapped.copy, nil);
            }];
        }];
    }];
}

- (void)searchMarketplaceCategory:(NSString *)category
                           species:(NSString *)species
                             breed:(NSString * _Nullable)breed
                             limit:(NSInteger)limit
                        completion:(void (^)(NSArray<NSDictionary *> * _Nullable items,
                                              NSError * _Nullable error))completion
{
    NSInteger boundedLimit = MAX(1, MIN(limit, 24));
    [self pp_resolveMainKindForSpecies:species allowReload:YES completion:^(MainKindsModel * _Nullable mainKind) {
        if (!mainKind) {
            if (completion) completion(nil, PPPureLensDiscoveryError(2001));
            return;
        }

        if ([category isEqualToString:@"services"]) {
            [[ServicesManager sharedInstance] fetchServicesForPetMainKindID:mainKind.ID
                                                                 completion:^(NSArray<ServiceModel *> *services, NSError * _Nullable error) {
                if (error) {
                    if (completion) completion(nil, error);
                    return;
                }
                NSMutableArray<NSDictionary *> *mapped = [NSMutableArray array];
                for (NSUInteger rank = 0; rank < services.count && mapped.count < boundedLimit; rank++) {
                    ServiceModel *service = services[rank];
                    if (!service.isLive) continue;
                    NSDictionary *dictionary = [self pp_dictionaryForService:service
                                                                        rank:rank
                                                                     species:species
                                                                       breed:breed];
                    if (dictionary) [mapped addObject:dictionary];
                }
                if (completion) completion(mapped.copy, nil);
            }];
            return;
        }

        AccessKindType accessKind;
        if ([category isEqualToString:@"accessories"]) {
            accessKind = AccessTypeAccessory;
        } else if ([category isEqualToString:@"medicine"]) {
            accessKind = AccessTypePetMedicine;
        } else if ([category isEqualToString:@"products"]) {
            accessKind = AccessTypeFood;
        } else {
            if (completion) completion(nil, PPPureLensDiscoveryError(2003));
            return;
        }

        [[PetAccessoryManager sharedManager] fetchAccessoriesOfKind:accessKind
                                                       MainCategory:mainKind.ID
                                                          completion:^(NSArray<PetAccessory *> *items) {
            NSMutableArray<NSDictionary *> *mapped = [NSMutableArray array];
            for (NSUInteger rank = 0; rank < items.count && mapped.count < boundedLimit; rank++) {
                NSDictionary *dictionary = [self pp_dictionaryForAccessory:items[rank]
                                                                    source:@"marketplaceTaxonomy"
                                                                      rank:rank
                                                               visualScore:nil
                                                                   species:species
                                                                     breed:breed];
                if (dictionary) [mapped addObject:dictionary];
            }
            if (completion) completion(mapped.copy, nil);
        }];
    }];
}

- (void)openItemWithIdentifier:(NSString *)identifier
                           kind:(NSString *)kind
                     completion:(void (^)(NSError * _Nullable error))completion
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *identity = [self pp_identityForIdentifier:identifier kind:kind];
        id object = [self pp_objectForIdentity:identity];
        UIViewController *presenter = [PPOverlayCoordinator pp_resolvedPresenterFrom:self.presenter];
        if (!object || !presenter || !presenter.view.window) {
            if (completion) completion(PPPureLensDiscoveryError(2004));
            return;
        }
        [PPOverlayCoordinator pp_openDetailForObject:object fromVC:presenter routingNav:nil];
        if (completion) completion(nil);
    });
}

#pragma mark - Taxonomy and mapping

- (void)pp_resolveMainKindForSpecies:(NSString *)species
                         allowReload:(BOOL)allowReload
                          completion:(void (^)(MainKindsModel * _Nullable mainKind))completion
{
    MainKindsModel *match = [self pp_mainKindForSpecies:species];
    NSArray<MainKindsModel *> *availableKinds = [[MainKindsArrayManager shared] visibleMainKindsSnapshot];
    if (match || !allowReload || availableKinds.count > 0) {
        if (completion) completion(match);
        return;
    }

    [[MainKindsArrayManager shared] loadMainDataCompletionHandler:^(int result) {
        if (completion) completion(result == 0 ? nil : [self pp_mainKindForSpecies:species]);
    }];
}

- (MainKindsModel * _Nullable)pp_mainKindForSpecies:(NSString *)species
{
    NSArray<MainKindsModel *> *kinds = [[MainKindsArrayManager shared] visibleMainKindsSnapshot];
    NSArray<NSString *> *aliases = PPPureLensSpeciesAliases(species);
    for (MainKindsModel *kind in kinds) {
        if (!kind.isVisibleInUserApp) continue;
        NSArray<NSString *> *names = @[
            kind.KindNameEn ?: @"",
            kind.KindNameAr ?: @"",
            kind.KindName ?: @""
        ];
        for (NSString *name in names) {
            NSString *normalizedName = PPPureLensNormalizedText(name);
            for (NSString *alias in aliases) {
                NSString *normalizedAlias = PPPureLensNormalizedText(alias);
                if (PPPureLensNameContainsAlias(normalizedName, normalizedAlias)) {
                    return kind;
                }
            }
        }
    }
    return nil;
}

- (BOOL)pp_itemIsDisplayable:(PetAccessory *)item
{
    if (item.isLivePet || item.isBlocked || item.isDeleted || item.isDisabled) return NO;
    if (item.accessKindType != AccessTypePetMedicine && !item.showInAppMarket) return NO;
    return item.accessKindType == AccessTypeAccessory ||
        item.accessKindType == AccessTypeFood ||
        item.accessKindType == AccessTypePetMedicine;
}

- (BOOL)pp_item:(PetAccessory *)item isCompatibleWithMainKindID:(NSInteger)mainKindID
{
    if (![self pp_itemIsDisplayable:item]) return NO;
    return mainKindID > 0 && item.petMainCategoryID == mainKindID;
}

- (NSDictionary * _Nullable)pp_dictionaryForAccessory:(PetAccessory *)item
                                                source:(NSString *)source
                                                  rank:(NSUInteger)rank
                                           visualScore:(NSNumber * _Nullable)visualScore
                                               species:(NSString *)species
                                                 breed:(NSString * _Nullable)breed
{
    if (![self pp_itemIsDisplayable:item]) return nil;
    NSString *identifier = item.accessoryID ?: @"";
    NSString *title = item.name ?: @"";
    if (identifier.length == 0 || title.length == 0) return nil;

    NSString *category;
    NSString *kind;
    switch (item.accessKindType) {
        case AccessTypeAccessory:
            category = @"accessories";
            kind = @"accessory";
            break;
        case AccessTypePetMedicine:
            category = @"medicine";
            kind = @"medicine";
            break;
        case AccessTypeFood:
        default:
            category = @"products";
            kind = @"product";
            break;
    }

    NSURL *imageURL = [PetAccessory firstImageURLForAccessory:item];
    NSString *priceText = item.finalPrice.doubleValue > 0
        ? [PetAccessory formatCurrency:item.finalPrice]
        : @"";
    NSMutableDictionary *metadata = [@{@"species": species ?: @""} mutableCopy];
    if (breed.length > 0) metadata[@"breed"] = breed;

    NSMutableDictionary *result = [@{
        @"id": identifier,
        @"category": category,
        @"kind": kind,
        @"title": title,
        @"subtitle": item.desc ?: @"",
        @"priceText": priceText ?: @"",
        @"imageURL": imageURL.absoluteString ?: @"",
        @"source": source,
        @"petMainKindID": @(item.petMainCategoryID),
        @"marketplaceRank": @(rank),
        @"metadata": metadata.copy
    } mutableCopy];
    if (visualScore) {
        double normalized = MAX(0.0, MIN(1.0, visualScore.doubleValue / 100.0));
        result[@"visualScore"] = @(normalized);
    }
    [self pp_storeObject:item
             forIdentity:[self pp_identityForIdentifier:identifier kind:kind]];
    return result.copy;
}

- (NSDictionary * _Nullable)pp_dictionaryForService:(ServiceModel *)service
                                                rank:(NSUInteger)rank
                                             species:(NSString *)species
                                               breed:(NSString * _Nullable)breed
{
    if (!service.isLive || service.serviceID.length == 0 || service.title.length == 0) return nil;
    NSMutableDictionary *metadata = [@{@"species": species ?: @""} mutableCopy];
    if (breed.length > 0) metadata[@"breed"] = breed;
    NSString *priceText = service.price > 0
        ? [PetAccessory formatCurrency:@(service.price)]
        : @"";
    NSDictionary *result = @{
        @"id": service.serviceID,
        @"category": @"services",
        @"kind": @"service",
        @"title": service.title,
        @"subtitle": service.localizedTypeName ?: service.desc ?: @"",
        @"priceText": priceText ?: @"",
        @"imageURL": service.imageURL ?: @"",
        @"source": @"marketplaceTaxonomy",
        @"petMainKindID": @(service.petMainKindID),
        @"marketplaceRank": @(rank),
        @"metadata": metadata.copy
    };
    [self pp_storeObject:service
             forIdentity:[self pp_identityForIdentifier:service.serviceID kind:@"service"]];
    return result;
}

- (void)pp_storeObject:(id)object forIdentity:(NSString *)identity
{
    if (!object || identity.length == 0) return;
    @synchronized (self.objectsByIdentity) {
        self.objectsByIdentity[identity] = object;
    }
}

- (id _Nullable)pp_objectForIdentity:(NSString *)identity
{
    if (identity.length == 0) return nil;
    @synchronized (self.objectsByIdentity) {
        return self.objectsByIdentity[identity];
    }
}

- (NSString *)pp_identityForIdentifier:(NSString *)identifier kind:(NSString *)kind
{
    return [NSString stringWithFormat:@"%@|%@", kind ?: @"", identifier ?: @""];
}

@end

@implementation PPImageSearchService

static const CGFloat PPImageSearchInitialMaxSide = 1024.0;
static const CGFloat PPImageSearchMinimumMaxSide = 512.0;
static const CGFloat PPImageSearchInitialJPEGQuality = 0.72;
static const CGFloat PPImageSearchMinimumJPEGQuality = 0.48;
static const NSUInteger PPImageSearchMaxBase64Length = 1100000;
static const NSInteger PPImageSearchFunctionsErrorCodeResourceExhausted = 8;

static NSString *PPImageSearchDisplayMessageForError(NSError *error)
{
    NSString *rawMessage = error.localizedDescription ?: @"";
    NSString *normalized = rawMessage.lowercaseString;
    BOOL isRawInternal =
        [normalized isEqualToString:@"internal"] ||
        [normalized containsString:@"internal error"] ||
        [normalized containsString:@"image understanding"] ||
        [normalized containsString:@"gemini"] ||
        [normalized containsString:@"api key"] ||
        error.code == FIRFunctionsErrorCodeInternal ||
        error.code == FIRFunctionsErrorCodeFailedPrecondition ||
        error.code == FIRFunctionsErrorCodeUnavailable ||
        error.code == FIRFunctionsErrorCodeDeadlineExceeded ||
        error.code == PPImageSearchFunctionsErrorCodeResourceExhausted;

    if (isRawInternal) {
        NSString *message = kLang(@"ImageSearchServiceUnavailable");
        return message.length > 0 ? message : kLang(@"ImageSearchError");
    }

    return rawMessage.length > 0 ? rawMessage : kLang(@"ImageSearchError");
}

+ (instancetype)shared {
    static PPImageSearchService *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[PPImageSearchService alloc] initPrivate];
    });
    return sharedInstance;
}

- (instancetype)init {
    return [PPImageSearchService shared];
}

- (instancetype)initPrivate {
    self = [super init];
    if (self) {
        _functions = [FIRFunctions functionsForRegion:@"us-central1"];
    }
    return self;
}

+ (NSString *)stringForMode:(PPImageSearchMode)mode {
    switch (mode) {
        case PPImageSearchModeProducts:
            return @"products";
        case PPImageSearchModePets:
            return @"pets";
        case PPImageSearchModeAdoption:
            return @"adoption";
        case PPImageSearchModeAuto:
        default:
            return @"auto";
    }
}

- (UIImage *)pp_resizedImage:(UIImage *)image maxSide:(CGFloat)maxSide {
    if (!image) { return nil; }

    CGFloat width = image.size.width;
    CGFloat height = image.size.height;

    if (width <= 0 || height <= 0) { return image; }

    CGFloat scale = MIN(maxSide / width, maxSide / height);
    if (scale >= 1.0) { return image; }

    CGSize newSize = CGSizeMake(width * scale, height * scale);

    UIGraphicsBeginImageContextWithOptions(newSize, NO, 1.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *resized = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return resized ?: image;
}

- (NSData *)pp_jpegDataForImage:(UIImage *)image {
    CGFloat maxSide = PPImageSearchInitialMaxSide;
    CGFloat quality = PPImageSearchInitialJPEGQuality;

    while (maxSide >= PPImageSearchMinimumMaxSide) {
        UIImage *resizedImage = [self pp_resizedImage:image maxSide:maxSide];

        while (quality >= PPImageSearchMinimumJPEGQuality) {
            NSData *data = UIImageJPEGRepresentation(resizedImage, quality);
            NSUInteger base64Length = ((data.length + 2) / 3) * 4;
            if (data && base64Length <= PPImageSearchMaxBase64Length) {
                return data;
            }

            quality -= 0.08;
        }

        maxSide -= 120.0;
        quality = PPImageSearchInitialJPEGQuality;
    }

    UIImage *fallbackImage = [self pp_resizedImage:image maxSide:PPImageSearchMinimumMaxSide];
    return UIImageJPEGRepresentation(fallbackImage, PPImageSearchMinimumJPEGQuality);
}

- (void)searchWithImage:(UIImage *)image
                   mode:(PPImageSearchMode)mode
                  limit:(NSNumber * _Nullable)limit
             completion:(void (^)(NSDictionary * _Nullable response,
                                   NSError * _Nullable error))completion {
    if (!image) {
        NSError *error = [NSError errorWithDomain:@"PPImageSearchService"
                                             code:1001
                                         userInfo:@{NSLocalizedDescriptionKey: kLang(@"ImageSearchImageRequired")}];
        if (completion) { completion(nil, error); }
        return;
    }

    NSData *jpegData = [self pp_jpegDataForImage:image];

    if (!jpegData) {
        NSError *error = [NSError errorWithDomain:@"PPImageSearchService"
                                             code:1002
                                         userInfo:@{NSLocalizedDescriptionKey: kLang(@"ImageSearchCompressionFailed")}];
        if (completion) { completion(nil, error); }
        return;
    }

    [self searchWithImageData:jpegData
                  contentType:@"image/jpeg"
                         mode:mode
                        limit:limit
                   completion:completion];
}

- (void)searchWithImageData:(NSData *)imageData
                contentType:(NSString *)contentType
                       mode:(PPImageSearchMode)mode
                      limit:(NSNumber * _Nullable)limit
                 completion:(void (^)(NSDictionary * _Nullable response,
                                       NSError * _Nullable error))completion {
    if (imageData.length == 0) {
        NSError *error = [NSError errorWithDomain:@"PPImageSearchService"
                                             code:1001
                                         userInfo:@{NSLocalizedDescriptionKey: kLang(@"ImageSearchImageRequired")}];
        if (completion) { completion(nil, error); }
        return;
    }

    NSSet<NSString *> *allowedTypes = [NSSet setWithArray:@[@"image/jpeg", @"image/png", @"image/webp"]];
    NSString *normalizedContentType = contentType.lowercaseString;
    if (![allowedTypes containsObject:normalizedContentType]) {
        NSError *error = [NSError errorWithDomain:@"PPImageSearchService"
                                             code:1005
                                         userInfo:@{NSLocalizedDescriptionKey: kLang(@"ImageSearchInvalidResponse")}];
        if (completion) { completion(nil, error); }
        return;
    }

    NSString *base64 = [imageData base64EncodedStringWithOptions:0];
    if (base64.length > PPImageSearchMaxBase64Length) {
        NSError *error = [NSError errorWithDomain:@"PPImageSearchService"
                                             code:1004
                                         userInfo:@{NSLocalizedDescriptionKey: kLang(@"ImageSearchImageTooLarge")}];
        if (completion) { completion(nil, error); }
        return;
    }

    NSDictionary *payload = @{
        @"imageBase64": base64,
        @"contentType": normalizedContentType,
        @"searchMode": [PPImageSearchService stringForMode:mode],
        @"limit": limit ?: @20
    };

    FIRHTTPSCallable *callable = [self.functions HTTPSCallableWithName:@"imageSearch"];

    [callable callWithObject:payload completion:^(FIRHTTPSCallableResult * _Nullable result,
                                                  NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSString *message = PPImageSearchDisplayMessageForError(error);
                NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:error.userInfo ?: @{}];
                userInfo[NSLocalizedDescriptionKey] = message ?: @"";
                userInfo[NSUnderlyingErrorKey] = error;
                NSError *displayError = [NSError errorWithDomain:@"PPImageSearchService"
                                                            code:error.code
                                                        userInfo:userInfo.copy];
                if (completion) { completion(nil, displayError); }
                return;
            }

            NSDictionary *data = [result.data isKindOfClass:[NSDictionary class]]
                ? (NSDictionary *)result.data
                : nil;

            if (!data) {
                NSError *parseError = [NSError errorWithDomain:@"PPImageSearchService"
                                                          code:1003
                                                      userInfo:@{NSLocalizedDescriptionKey: kLang(@"ImageSearchInvalidResponse")}];
                if (completion) { completion(nil, parseError); }
                return;
            }

            if (completion) { completion(data, nil); }
        });
    }];
}

@end
