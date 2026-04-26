//
//  VetModel.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 15/07/2025.
//

#import "VetModel.h"
@import FirebaseFirestore;

static NSString *PPVetSafeString(id value) {
    if ([value isKindOfClass:NSString.class]) {
        return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    if ([value respondsToSelector:@selector(stringValue)]) {
        return [[[value stringValue] ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
    }
    return @"";
}

static NSArray<NSString *> *PPVetStringArray(id value) {
    if (![value isKindOfClass:NSArray.class]) {
        return @[];
    }
    NSMutableArray<NSString *> *items = [NSMutableArray array];
    for (id entry in (NSArray *)value) {
        NSString *safeEntry = PPVetSafeString(entry);
        if (safeEntry.length > 0) {
            [items addObject:safeEntry];
        }
    }
    return items.copy;
}

static NSDate * _Nullable PPVetDateFromValue(id value) {
    if ([value isKindOfClass:[FIRTimestamp class]]) {
        return [(FIRTimestamp *)value dateValue];
    }
    if ([value isKindOfClass:[NSDate class]]) {
        return (NSDate *)value;
    }
    return nil;
}

static NSString *PPVetNormalizedTypeString(id value) {
    if ([value isKindOfClass:NSString.class]) {
        NSString *normalized = [PPVetSafeString(value).lowercaseString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([normalized isEqualToString:@"clinic"] || [normalized isEqualToString:@"company"] || [normalized isEqualToString:@"1"]) {
            return @"clinic";
        }
        if ([normalized isEqualToString:@"doctor"] || [normalized isEqualToString:@"personal"] || [normalized isEqualToString:@"0"]) {
            return @"doctor";
        }
    }
    if ([value respondsToSelector:@selector(integerValue)] && [value integerValue] == VetTypeCompany) {
        return @"clinic";
    }
    return @"doctor";
}

@implementation VetModel

- (instancetype)init {
    self = [super init];
    if (self) {
        _vetID = @"";
        _userID = @"";
        _logoURL = @"";
        _title = @"";
        _descriptionText = @"";
        _phone = @"";
        _whatsapp = @"";
        _blurHash = @"";
        _animalTypes = @[];
        _verificationStatus = @"pending";
        _canEditProfile = NO;
        _canPostServices = NO;
        _canPostMedicines = NO;
    }
    return self;
}

- (NSString *)name_lowercase {
    return self.title.lowercaseString ?: @"";
}

- (NSString *)normalizedTypeValue {
    return self.type == VetTypeCompany ? @"clinic" : @"doctor";
}

- (NSDictionary *)toDictionary {
    NSString *title = self.title ?: @"";
    NSString *descriptionText = self.descriptionText ?: @"";
    BOOL readyToContact = self.readyToContact || self.phone.length > 0 || self.whatsapp.length > 0;
    NSMutableDictionary *dict = [@{
        @"type": [self normalizedTypeValue],
        @"userId": self.userID ?: @"",
        @"petMainKindID": @(self.petMainKindID),
        @"logoUrl": self.logoURL ?: @"",
        @"title": title,
        @"name_lowercase": title.lowercaseString,
        @"description": descriptionText,
        @"descriptionText": descriptionText,
        @"phone": self.phone ?: @"",
        @"blurHash": self.blurHash ?: @"",
        @"whatsapp": self.whatsapp ?: @"",
        @"availableDate": self.availableDate ?: [NSNull null],
        @"animalTypes": self.animalTypes ?: @[],
        @"readyToContact": @(readyToContact),
        @"vetCost": @(self.vetCost),
        @"isDisabled": @(self.isDisabled),
        @"verificationStatus": PPVetSafeString(self.verificationStatus).length > 0 ? self.verificationStatus : @"pending",
        @"subscriptionActive": @(self.subscriptionActive),
        @"subscriptionTier": @(self.subscriptionTier),
        @"canEditProfile": @(self.canEditProfile),
        @"canPostServices": @(self.canPostServices),
        @"canPostMedicines": @(self.canPostMedicines),
    } mutableCopy];
    if (self.subscriptionStartDate) dict[@"subscriptionStartDate"] = self.subscriptionStartDate;
    if (self.subscriptionEndDate) dict[@"subscriptionEndDate"] = self.subscriptionEndDate;
    if (self.createdAt) dict[@"createdAt"] = self.createdAt;
    if (self.updatedAt) dict[@"updatedAt"] = self.updatedAt;
    return dict.copy;
}

+ (instancetype)fromDictionary:(NSDictionary *)dict withID:(NSString *)vetID {
    VetModel *model = [[VetModel alloc] init];
    model.vetID = vetID;
    model.type = [PPVetNormalizedTypeString(dict[@"type"]) isEqualToString:@"clinic"] ? VetTypeCompany : VetTypePersonal;
    model.userID = PPVetSafeString(dict[@"userId"]).length > 0 ? PPVetSafeString(dict[@"userId"]) : PPVetSafeString(dict[@"userID"]);
    model.petMainKindID = [dict[@"petMainKindID"] integerValue];
    model.logoURL = PPVetSafeString(dict[@"logoUrl"]).length > 0 ? PPVetSafeString(dict[@"logoUrl"]) : PPVetSafeString(dict[@"logoURL"]);
    model.title = PPVetSafeString(dict[@"title"]);
    model.blurHash = PPVetSafeString(dict[@"blurHash"]);
    /*
     name_lowercase is intentionally NOT stored on the model.
     It is derived from `title` to keep the model backward‑safe.
    */
    model.descriptionText = PPVetSafeString(dict[@"description"]).length > 0 ? PPVetSafeString(dict[@"description"]) : PPVetSafeString(dict[@"descriptionText"]);
    model.phone = PPVetSafeString(dict[@"phone"]);
    model.whatsapp = PPVetSafeString(dict[@"whatsapp"]);
    model.availableDate = PPVetDateFromValue(dict[@"availableDate"]);
    model.vetCost = [dict[@"vetCost"] respondsToSelector:@selector(doubleValue)] ? [dict[@"vetCost"] doubleValue] : 0.0;
    model.animalTypes = PPVetStringArray(dict[@"animalTypes"]);
    model.readyToContact = [dict[@"readyToContact"] boolValue] || model.phone.length > 0 || model.whatsapp.length > 0;
    model.isDisabled = [dict[@"isDisabled"] boolValue];
    model.verificationStatus = PPVetSafeString(dict[@"verificationStatus"]).length > 0 ? PPVetSafeString(dict[@"verificationStatus"]) : @"approved";
    model.subscriptionActive = [dict[@"subscriptionActive"] boolValue];
    model.subscriptionTier = [dict[@"subscriptionTier"] integerValue];
    model.subscriptionStartDate = PPVetDateFromValue(dict[@"subscriptionStartDate"]);
    model.subscriptionEndDate = PPVetDateFromValue(dict[@"subscriptionEndDate"]);
    model.canEditProfile = [dict[@"canEditProfile"] boolValue];
    model.canPostServices = [dict[@"canPostServices"] boolValue];
    model.canPostMedicines = [dict[@"canPostMedicines"] boolValue];
    model.createdAt = PPVetDateFromValue(dict[@"createdAt"]);
    model.updatedAt = PPVetDateFromValue(dict[@"updatedAt"]);
    return model;
}

@end
