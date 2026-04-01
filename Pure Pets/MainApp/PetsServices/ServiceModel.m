//
//  ServiceModel.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 14/07/2025.
//
#import "ServiceModel.h"

@interface ServiceModel ()
@property (nonatomic, copy) NSString *searchTitle;
@end

@implementation ServiceModel

- (instancetype)initWithDictionary:(NSDictionary *)dict documentID:(NSString *)documentID {
    self = [super init];
    if (self) {
        _serviceID = documentID ?: @"";
        _title = dict[@"title"];
        _searchTitle = dict[@"searchTitle"];
        _desc = dict[@"description"];
        _price = [dict[@"price"] doubleValue];
        _type = [dict[@"type"] integerValue];
        _blurHash = dict[@"blurHash"];
        _category = dict[@"category"];
        _petMainKindID = [dict[@"petMainKindID"] integerValue];
        _availableDate = dict[@"availableDate"];
        _timestamp = dict[@"timestamp"] ?: [NSDate date];
        _imageURL = dict[@"imageURL"];
        _serviceOwnerID = dict[@"serviceOwnerID"];
        _categoryID = dict[@"categoryID"];
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

@end















