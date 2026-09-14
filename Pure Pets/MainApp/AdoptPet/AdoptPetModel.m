//
//  AdoptPetModel.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 13/08/2025.
//


#import "AdoptPetModel.h"

static NSInteger PPAdoptIntegerValue(id value) {
    return [value respondsToSelector:@selector(integerValue)] ? [value integerValue] : 0;
}

@implementation AdoptPetModel

- (instancetype)init {
    if (self = [super init]) {
        _documentID = @"";
        _name = @"";
        _kindID = 0;
        _breedID = 0;
        _ageMonths = 0;
        _gender = @"Male";
        _cityID = 0;
        _details = @"";
        _adoptionReason = @"";
        _ownerID = @"";
        _imageURLs = @[];
        _imageMeta = @[];
        _createdAt = [NSDate date];
        _visibility = 0;
        _status = @"";
        _version = 0;
        _petID = @"";
        _organizationID = @"";
        _organizationName = @"";
        _organizationVerified = NO;
        _ownerDisplayName = @"";
        _locationDisplayName = @"";
        _mediaAssetIDs = @[];
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
                         documentID:(NSString *)documentID {
    if (self = [self init]) {
        NSDictionary *d = [dictionary isKindOfClass:NSDictionary.class] ? dictionary : @{};
        NSDictionary *pet = [d[@"pet"] isKindOfClass:NSDictionary.class] ? d[@"pet"] : @{};
        NSDictionary *profile = [d[@"profile"] isKindOfClass:NSDictionary.class] ? d[@"profile"] : @{};
        NSDictionary *owner = [d[@"owner"] isKindOfClass:NSDictionary.class] ? d[@"owner"] : @{};
        NSDictionary *organization = [d[@"organization"] isKindOfClass:NSDictionary.class] ? d[@"organization"] : @{};
        NSDictionary *location = [d[@"location"] isKindOfClass:NSDictionary.class] ? d[@"location"] : @{};

        _documentID = documentID.length > 0 ? documentID : ([d[@"id"] isKindOfClass:NSString.class] ? d[@"id"] : @"");
        _petID = [d[@"petId"] isKindOfClass:NSString.class] ? d[@"petId"] : ([pet[@"petId"] isKindOfClass:NSString.class] ? pet[@"petId"] : _documentID);
        _name = [pet[@"name"] isKindOfClass:NSString.class] ? pet[@"name"] : ([profile[@"name"] isKindOfClass:NSString.class] ? profile[@"name"] : ([d[@"title"] isKindOfClass:NSString.class] ? d[@"title"] : @""));
        _kindID = PPAdoptIntegerValue(pet[@"categoryId"] ?: profile[@"categoryId"] ?: d[@"kindID"]);
        _breedID = PPAdoptIntegerValue(profile[@"breedId"] ?: d[@"breedID"]);
        _ageMonths = PPAdoptIntegerValue(pet[@"ageInMonths"] ?: profile[@"ageInMonths"] ?: d[@"ageMonths"]);
        _gender = [pet[@"sex"] isKindOfClass:NSString.class] ? pet[@"sex"] : ([profile[@"gender"] isKindOfClass:NSString.class] ? profile[@"gender"] : @"");
        _cityID = PPAdoptIntegerValue(profile[@"cityId"] ?: d[@"cityID"]);
        _details = [d[@"description"] isKindOfClass:NSString.class] ? d[@"description"] : @"";
        _adoptionReason = [d[@"adoptionReason"] isKindOfClass:NSString.class] ? d[@"adoptionReason"] : @"";
        _ownerID = [d[@"ownerUid"] isKindOfClass:NSString.class] ? d[@"ownerUid"] : ([d[@"ownerId"] isKindOfClass:NSString.class] ? d[@"ownerId"] : @"");
        _ownerDisplayName = [owner[@"displayName"] isKindOfClass:NSString.class] ? owner[@"displayName"] : @"";
        _organizationID = [d[@"organizationId"] isKindOfClass:NSString.class] ? d[@"organizationId"] : ([organization[@"organizationId"] isKindOfClass:NSString.class] ? organization[@"organizationId"] : @"");
        _organizationName = [organization[@"name"] isKindOfClass:NSString.class] ? organization[@"name"] : @"";
        _organizationVerified = [organization[@"verified"] boolValue];
        _locationDisplayName = [[@[location[@"district"] ?: @"", location[@"city"] ?: @""] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id value, NSDictionary *bindings) {
            return [value isKindOfClass:NSString.class] && [value length] > 0;
        }]] componentsJoinedByString:@"، "];
        _status = [d[@"status"] isKindOfClass:NSString.class] ? d[@"status"] : @"";
        _version = PPAdoptIntegerValue(d[@"version"]);
        _visibility = [d[@"visibility"] isKindOfClass:NSString.class] ? ([d[@"visibility"] isEqualToString:@"public"] ? 0 : 1) : PPAdoptIntegerValue(d[@"visibility"]);

        NSMutableArray<NSString *> *assetIDs = [NSMutableArray array];
        if ([d[@"mediaAssetIds"] isKindOfClass:NSArray.class]) {
            for (id raw in d[@"mediaAssetIds"]) {
                if ([raw isKindOfClass:NSString.class] && [raw length] > 0) [assetIDs addObject:raw];
            }
        }
        _mediaAssetIDs = assetIDs.copy;

        NSMutableArray<NSString *> *urls = [NSMutableArray array];
        NSMutableArray<NSDictionary *> *meta = [NSMutableArray array];
        if ([d[@"media"] isKindOfClass:NSArray.class]) {
            for (id rawAsset in d[@"media"]) {
                if (![rawAsset isKindOfClass:NSDictionary.class]) continue;
                NSDictionary *asset = rawAsset;
                NSDictionary *variants = [asset[@"variants"] isKindOfClass:NSDictionary.class] ? asset[@"variants"] : @{};
                NSString *resolvedURL = @"";
                for (NSString *key in @[@"detail", @"card", @"thumbnail", @"fullScreen", @"poster"]) {
                    NSDictionary *variant = [variants[key] isKindOfClass:NSDictionary.class] ? variants[key] : nil;
                    if ([variant[@"url"] isKindOfClass:NSString.class] && [variant[@"url"] length] > 0) {
                        resolvedURL = variant[@"url"];
                        break;
                    }
                }
                if (resolvedURL.length > 0) [urls addObject:resolvedURL];
                [meta addObject:@{
                    @"assetId": [asset[@"assetId"] isKindOfClass:NSString.class] ? asset[@"assetId"] : @"",
                    @"type": [asset[@"mediaKind"] isKindOfClass:NSString.class] ? asset[@"mediaKind"] : @"image"
                }];
            }
        }
        if (urls.count == 0 && [pet[@"imageURL"] isKindOfClass:NSString.class] && [pet[@"imageURL"] length] > 0) {
            [urls addObject:pet[@"imageURL"]];
        }
        _imageURLs = urls.copy;
        _imageMeta = meta.copy;

        id ts = d[@"createdAt"] ?: d[@"updatedAt"];
        if ([ts isKindOfClass:FIRTimestamp.class]) _createdAt = ((FIRTimestamp *)ts).dateValue;
    }
    return self;
}

- (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot {
    if (self = [self init]) {
        _documentID = snapshot.documentID ?: @"";
        NSDictionary *d = snapshot.data ?: @{};
        _name      = [d[@"name"] isKindOfClass:NSString.class] ? d[@"name"] : ([d[@"adTitle"] isKindOfClass:NSString.class] ? d[@"adTitle"] : ([d[@"title"] isKindOfClass:NSString.class] ? d[@"title"] : @""));
        _kindID    = PPAdoptIntegerValue(d[@"kindID"] ?: d[@"category"] ?: d[@"mainCategoryID"]);
        _breedID   = PPAdoptIntegerValue(d[@"breedID"] ?: d[@"subcategory"] ?: d[@"subCategoryID"]);
        _ageMonths = PPAdoptIntegerValue(d[@"ageMonths"] ?: d[@"petAge"] ?: d[@"petAgeMonths"] ?: d[@"age"]);
        _gender    = [d[@"gender"] isKindOfClass:NSString.class] ? d[@"gender"] : @"Male";
        _cityID    = PPAdoptIntegerValue(d[@"cityID"] ?: d[@"adLocation"]);
        _details   = [d[@"details"] isKindOfClass:NSString.class] ? d[@"details"] : ([d[@"desc"] isKindOfClass:NSString.class] ? d[@"desc"] : ([d[@"adDescription"] isKindOfClass:NSString.class] ? d[@"adDescription"] : ([d[@"description"] isKindOfClass:NSString.class] ? d[@"description"] : @"")));
        _ownerID   = [d[@"ownerID"] isKindOfClass:NSString.class] ? d[@"ownerID"] : ([d[@"uid"] isKindOfClass:NSString.class] ? d[@"uid"] : ([d[@"userId"] isKindOfClass:NSString.class] ? d[@"userId"] : @""));
        if ([d[@"visibility"] respondsToSelector:@selector(integerValue)]) {
            _visibility = [d[@"visibility"] integerValue];
        }

        id rawURLs = d[@"imageURLs"] ?: d[@"photos"] ?: d[@"images"] ?: d[@"photoURLs"];
        NSArray *urlsArray = [rawURLs isKindOfClass:NSArray.class] ? rawURLs : @[];
        NSMutableArray<NSString *> *urls = [NSMutableArray arrayWithCapacity:urlsArray.count];
        for (id raw in urlsArray) {
            if ([raw isKindOfClass:NSString.class] && [((NSString *)raw) length] > 0) {
                [urls addObject:raw];
            } else if ([raw isKindOfClass:NSDictionary.class] && [raw[@"url"] isKindOfClass:NSString.class]) {
                [urls addObject:raw[@"url"]];
            }
        }
        _imageURLs = urls.copy;
        NSMutableArray<NSDictionary *> *validImageMeta = [NSMutableArray array];
        if ([d[@"imageMeta"] isKindOfClass:NSArray.class]) {
            for (id item in d[@"imageMeta"]) {
                if ([item isKindOfClass:NSDictionary.class]) {
                    [validImageMeta addObject:item];
                }
            }
        }
        _imageMeta = validImageMeta.copy;

        id ts = d[@"createdAt"] ?: d[@"postedDate"] ?: d[@"updatedAt"];
        if ([ts isKindOfClass:[FIRTimestamp class]]) {
            _createdAt = ((FIRTimestamp *)ts).dateValue;
        }
    }
    return self;
}

- (NSDictionary *)toFirestoreDictionary {
    return @{
        @"documentID": self.documentID ?: @"",
        @"name": self.name ?: @"",
        @"ownerID": self.ownerID ?: @"",
        @"kindID": @(self.kindID),
        @"breedID": @(self.breedID),
        @"ageMonths": @(self.ageMonths),
        @"gender": self.gender ?: @"Male",
        @"cityID": @(self.cityID),
        @"details": self.details ?: @"",
        @"adoptionReason": self.adoptionReason ?: @"",
        @"imageURLs": self.imageURLs ?: @[],
        @"imageMeta": self.imageMeta ?: @[],
        @"visibility": @(self.visibility),
        @"createdAt": [FIRTimestamp timestampWithDate:self.createdAt ?: [NSDate date]]
    };
}

-(NSString *)mCityName
{
    NSString *canonical = self.locationDisplayName ?: @"";
    if (canonical.length > 0) return canonical;
    return [CitiesManager.shared cityNameForID:self.cityID] ?: @"";
}

-(NSString *)mKindName
{
    return [MainKindsModel kindNameForID:self.kindID] ?: @"";
}

-(NSString *)mBreedName
{
    if (self.kindID <= 0 && self.petID.length > 0) return @"";
    MainKindsModel *mainKind = [MainKindsModel mainKindClassForID:self.kindID inArray:MKM.MainKindsArray];
    SubKindModel *subKind = [mainKind subKindForID:self.breedID];
    return subKind.SubKindName ?: @"";
}

-(MainKindsModel *)mainKindModel
{
    return [MainKindsModel mainKindClassForID:self.kindID inArray:MKM.MainKindsArray];
}

-(SubKindModel *)subKindModel
{
    return [[self mainKindModel] subKindForID:self.breedID];
}

@end
