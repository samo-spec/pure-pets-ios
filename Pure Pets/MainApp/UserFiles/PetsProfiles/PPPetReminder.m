//
//  PPPetReminder.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/7/26.
//


#import "PPPetReminder.h"

static NSDate * PPReminderDateFromValue(id value) {
    if ([value isKindOfClass:NSDate.class]) return value;
    if ([value isKindOfClass:FIRTimestamp.class]) return ((FIRTimestamp *)value).dateValue;
    return nil;
}

@implementation PPPetReminder

- (instancetype)init {
    self = [super init];
    if (self) {
        _reminderID = @"";
        _petID = @"";
        _title = @"";
        _enabled = YES;
        _type = PPPetReminderTypeVaccination;
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [self init];
    if (!self) return nil;

    _reminderID = [dictionary[@"reminderID"] ?: @"" copy];
    _petID = [dictionary[@"petID"] ?: @"" copy];
    _title = [dictionary[@"title"] ?: @"" copy];
    _type = [dictionary[@"type"] integerValue];
    _fireDate = PPReminderDateFromValue(dictionary[@"fireDate"]);
    _repeatRule = [dictionary[@"repeatRule"] copy];
    _enabled = dictionary[@"enabled"] ? [dictionary[@"enabled"] boolValue] : YES;
    _createdAt = PPReminderDateFromValue(dictionary[@"createdAt"]);
    _updatedAt = PPReminderDateFromValue(dictionary[@"updatedAt"]);
    return self;
}

- (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot {
    self = [self initWithDictionary:(snapshot.data ?: @{})];
    if (!self) return nil;
    if (self.reminderID.length == 0) self.reminderID = snapshot.documentID ?: @"";
    return self;
}

- (NSDictionary *)toDictionary {
    return @{
        @"reminderID": self.reminderID ?: @"",
        @"petID": self.petID ?: @"",
        @"title": self.title ?: @"",
        @"type": @(self.type),
        @"fireDate": self.fireDate ?: [NSDate date],
        @"repeatRule": self.repeatRule ?: @"",
        @"enabled": @(self.enabled),
        @"createdAt": self.createdAt ?: [FIRFieldValue fieldValueForServerTimestamp],
        @"updatedAt": [FIRFieldValue fieldValueForServerTimestamp]
    };
}

- (NSString *)typeLabelKey {
    switch (self.type) {
        case PPPetReminderTypeFood: return @"pet_reminder_food";
        case PPPetReminderTypeAppointment: return @"pet_reminder_appointment";
        default: return @"pet_reminder_vaccination";
    }
}

- (NSString *)displayTypeText {
    NSString *key = [self typeLabelKey];
    return kLang(key) ?: key;
}

@end