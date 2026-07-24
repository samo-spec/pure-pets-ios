//
//  AdoptPetModel.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 13/08/2025.
//


#import "AdoptPetModel.h"

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
        _ownerID = @"";
        _imageURLs = @[];
        _imageMeta = @[];
        _createdAt = [NSDate date];
        _visibility = 0;
    }
    return self;
}

- (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot {
    if (self = [self init]) {
        _documentID = snapshot.documentID ?: @"";
        NSDictionary *d = snapshot.data ?: @{};
        _name      = [d[@"name"] isKindOfClass:NSString.class] ? d[@"name"] : ([d[@"adTitle"] isKindOfClass:NSString.class] ? d[@"adTitle"] : ([d[@"title"] isKindOfClass:NSString.class] ? d[@"title"] : @""));
        _kindID    = [(d[@"kindID"] ?: d[@"category"] ?: d[@"mainCategoryID"] ?: @(0)) integerValue];
        _breedID   = [(d[@"breedID"] ?: d[@"subcategory"] ?: d[@"subCategoryID"] ?: @(0)) integerValue];
        _ageMonths = [(d[@"ageMonths"] ?: d[@"petAge"] ?: d[@"petAgeMonths"] ?: d[@"age"] ?: @(0)) integerValue];
        _gender    = [d[@"gender"] isKindOfClass:NSString.class] ? d[@"gender"] : @"Male";
        _cityID    = [(d[@"cityID"] ?: d[@"adLocation"] ?: @(0)) integerValue];
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
        _imageMeta = [d[@"imageMeta"] isKindOfClass:NSArray.class] ? d[@"imageMeta"] : @[];

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
        @"imageURLs": self.imageURLs ?: @[],
        @"imageMeta": self.imageMeta ?: @[],
        @"visibility": @(self.visibility),
        @"createdAt": [FIRTimestamp timestampWithDate:self.createdAt ?: [NSDate date]]
    };
}

-(NSString *)mCityName
{
    return [CitiesManager.shared cityNameForID:self.cityID];
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
