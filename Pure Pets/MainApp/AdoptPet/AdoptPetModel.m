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
        _name      = [d[@"name"] isKindOfClass:NSString.class] ? d[@"name"] : @"";
        _kindID    = [d[@"kindID"]?:@(0) integerValue];
        _breedID   = [d[@"breedID"]?:@(0) integerValue];
        _ageMonths = [d[@"ageMonths"]?:@(0) integerValue];
        _gender    = [d[@"gender"] isKindOfClass:NSString.class] ? d[@"gender"] : @"Male";
        _cityID    = [d[@"cityID"]?:@(0) integerValue];
        _details   = [d[@"details"] isKindOfClass:NSString.class] ? d[@"details"] : @"";
        _ownerID   = [d[@"ownerID"] isKindOfClass:NSString.class] ? d[@"ownerID"] : @"";
        if ([d[@"visibility"] respondsToSelector:@selector(integerValue)]) {
            _visibility = [d[@"visibility"] integerValue];
        }

        NSArray *rawURLs = [d[@"imageURLs"] isKindOfClass:NSArray.class] ? d[@"imageURLs"] : @[];
        NSMutableArray<NSString *> *urls = [NSMutableArray arrayWithCapacity:rawURLs.count];
        for (id raw in rawURLs) {
            if ([raw isKindOfClass:NSString.class] && [((NSString *)raw) length] > 0) {
                [urls addObject:raw];
            }
        }
        _imageURLs = urls.copy;
        _imageMeta = [d[@"imageMeta"] isKindOfClass:NSArray.class] ? d[@"imageMeta"] : @[];

        id ts = d[@"createdAt"];
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
