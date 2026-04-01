//
//  VetModel.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 15/07/2025.
//

#import "VetModel.h"

@implementation VetModel

- (NSDictionary *)toDictionary {
    NSString *title = self.title ?: @"";
    return @{
        @"type": @(self.type),
        @"userID": self.userID ?: @"",
        @"petMainKindID": @(self.petMainKindID),
        @"logoURL": self.logoURL ?: @"",
        @"title": title,
        @"name_lowercase": title.lowercaseString,
        @"descriptionText": self.descriptionText ?: @"",
        @"phone": self.phone ?: @"",
        @"blurHash": self.blurHash ?: @"",
        @"whatsapp": self.whatsapp ?: @"",
        @"availableDate": self.availableDate ?: [NSNull null]
    };
}

+ (instancetype)fromDictionary:(NSDictionary *)dict withID:(NSString *)vetID {
    VetModel *model = [[VetModel alloc] init];
    model.vetID = vetID;
    model.type = [dict[@"type"] integerValue];
    model.userID = dict[@"userID"] ?: @"";
    model.petMainKindID = [dict[@"petMainKindID"] integerValue];
    model.logoURL = dict[@"logoURL"] ?: @"";
    model.title = dict[@"title"] ?: @"";
    model.blurHash = dict[@"blurHash"] ?: @"";
    /*
     name_lowercase is intentionally NOT stored on the model.
     It is derived from `title` to keep the model backward‑safe.
    */
    model.descriptionText = dict[@"descriptionText"] ?: @"";
    model.phone = dict[@"phone"] ?: @"";
    model.whatsapp = dict[@"whatsapp"] ?: @"";
    model.availableDate = dict[@"availableDate"];
    return model;
}

@end
