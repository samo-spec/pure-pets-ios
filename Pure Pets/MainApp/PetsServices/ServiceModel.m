//
//  ServiceModel.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 14/07/2025.
//
#import "ServiceModel.h"
#import "ArabicNormalizer.h"

@interface ServiceModel ()
@property (nonatomic, copy) NSString *searchTitle;
+ (NSDate *)pp_dateFromValue:(id)value;
@end

@implementation ServiceModel

- (instancetype)initWithDictionary:(NSDictionary *)dict documentID:(NSString *)documentID {
    self = [super init];
    if (self) {
        _serviceID = documentID ?: @"";
        _title = [dict[@"title"] isKindOfClass:NSString.class] ? dict[@"title"] : @"";
        _searchTitle = [dict[@"searchTitle"] isKindOfClass:NSString.class] ? dict[@"searchTitle"] : @"";
        _desc = [dict[@"description"] isKindOfClass:NSString.class] ? dict[@"description"] : @"";
        _price = [dict[@"price"] doubleValue];
        _type = [dict[@"type"] integerValue];
        _blurHash = [dict[@"blurHash"] isKindOfClass:NSString.class] ? dict[@"blurHash"] : @"";
        _category = [dict[@"category"] isKindOfClass:NSString.class] ? dict[@"category"] : @"";
        _petMainKindID = [dict[@"petMainKindID"] integerValue];
        _availableDate = [self.class pp_dateFromValue:dict[@"availableDate"]];
        _timestamp = [self.class pp_dateFromValue:dict[@"timestamp"]] ?: [NSDate date];
        _imageURL = [dict[@"imageURL"] isKindOfClass:NSString.class] ? dict[@"imageURL"] : nil;
        _serviceOwnerID = [dict[@"serviceOwnerID"] isKindOfClass:NSString.class] ? dict[@"serviceOwnerID"] : nil;
        _categoryID = [dict[@"categoryID"] isKindOfClass:NSString.class] ? dict[@"categoryID"] : @"";
    }
    return self;
}

- (NSDictionary *)toDictionary {
    NSString *title = self.title ?: @"";

    NSMutableDictionary *dict = [@{
        @"title": title,
        @"searchTitle": self.searchTitle ?: @"",
        @"description": self.desc ?: @"",
        @"blurHash": self.blurHash ?: @"",
        @"price": @(self.price),
        @"type": @(self.type),
        @"category": self.category ?: @"",
        @"categoryID": self.categoryID ?: @"",
        @"petMainKindID": @(self.petMainKindID),
        @"availableDate": self.availableDate ?: [NSNull null],
        @"timestamp": self.timestamp ?: [NSDate date]
    } mutableCopy];

    if (self.imageURL) {
        dict[@"imageURL"] = self.imageURL;
    }
    if (self.serviceOwnerID) {
        dict[@"serviceOwnerID"] = self.serviceOwnerID;
    }
    return dict;
}

- (NSString *)searchTitle {
    if (_searchTitle.length > 0) {
        return _searchTitle;
    }
    return [ArabicNormalizer normalize:self.title ?: @""];
}

+ (NSDate *)pp_dateFromValue:(id)value {
    if ([value isKindOfClass:[NSDate class]]) {
        return value;
    }
    if ([value respondsToSelector:@selector(dateValue)]) {
        return [value dateValue];
    }
    return nil;
}

@end













