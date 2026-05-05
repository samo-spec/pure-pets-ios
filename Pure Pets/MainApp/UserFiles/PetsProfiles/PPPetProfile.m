//
//  PPPetVaccinationRecord.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/7/26.
//


#import "PPPetProfile.h"

static NSDate * PPDateFromValue(id value) {
    if ([value isKindOfClass:NSDate.class]) return value;
    if ([value isKindOfClass:FIRTimestamp.class]) return ((FIRTimestamp *)value).dateValue;
    return nil;
}


@implementation PPPetVaccinationRecord

- (instancetype)init {
    self = [super init];
    if (self) {
        _recordID = [NSUUID UUID].UUIDString;
        _name = @"";
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [self init];
    if (!self) return nil;

    _recordID = [PPSafeString(dictionary[@"recordID"]) copy];
    if (_recordID.length == 0) _recordID = [NSUUID UUID].UUIDString;
    _name = [PPSafeString(dictionary[@"name"]) copy];
    _appliedAt = PPDateFromValue(dictionary[@"appliedAt"]);
    _nextDueDate = PPDateFromValue(dictionary[@"nextDueDate"]);
    _notes = [PPSafeString(dictionary[@"notes"]) copy];
    return self;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"recordID"] = self.recordID ?: [NSUUID UUID].UUIDString;
    dict[@"name"] = self.name ?: @"";
    if (self.appliedAt) dict[@"appliedAt"] = self.appliedAt;
    if (self.nextDueDate) dict[@"nextDueDate"] = self.nextDueDate;
    if (self.notes.length) dict[@"notes"] = self.notes;
    return dict.copy;
}

@end

@implementation PPPetProfile

- (instancetype)init {
    self = [super init];
    if (self) {
        _petID = @"";
        _name = @"";
        _breed = @"";
        _vaccinations = @[];
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [self init];
    if (!self) return nil;

    _petID = [PPSafeString(dictionary[@"petID"]) copy];
    _name = [PPSafeString(dictionary[@"name"]) copy];
    _breed = [PPSafeString(dictionary[@"breed"]) copy];
    _categoryId = [dictionary[@"categoryId"] respondsToSelector:@selector(integerValue)]
                  ? [dictionary[@"categoryId"] integerValue] : 0;
    _categoryName = [PPSafeString(dictionary[@"categoryName"]) copy];
    _ageInMonths = [dictionary[@"ageInMonths"] respondsToSelector:@selector(integerValue)]
                   ? [dictionary[@"ageInMonths"] integerValue] : 0;
    _imageURL = [PPSafeString(dictionary[@"imageURL"]) copy];
    _isDefaultPet = [dictionary[@"isDefaultPet"] respondsToSelector:@selector(boolValue)]
                    ? [dictionary[@"isDefaultPet"] boolValue] : NO;
    _createdAt = PPDateFromValue(dictionary[@"createdAt"]);
    _updatedAt = PPDateFromValue(dictionary[@"updatedAt"]);

    NSMutableArray *records = [NSMutableArray array];
    for (NSDictionary *record in (dictionary[@"vaccinations"] ?: @[])) {
        PPPetVaccinationRecord *item = [[PPPetVaccinationRecord alloc] initWithDictionary:record];
        if (item) [records addObject:item];
    }
    _vaccinations = records.copy;

    return self;
}

- (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot {
    self = [self initWithDictionary:(snapshot.data ?: @{})];
    if (!self) return nil;
    if (self.petID.length == 0) self.petID = snapshot.documentID ?: @"";
    return self;
}

- (NSDictionary *)toDictionary {
    NSMutableArray *records = [NSMutableArray array];
    for (PPPetVaccinationRecord *record in self.vaccinations ?: @[]) {
        [records addObject:[record toDictionary]];
    }

    return @{
        @"petID": self.petID ?: @"",
        @"name": self.name ?: @"",
        @"breed": self.breed ?: @"",
        @"ageInMonths": @(MAX(0, self.ageInMonths)),
        @"imageURL": self.imageURL ?: @"",
        @"isDefaultPet": @(self.isDefaultPet),
        @"vaccinations": records.copy,
        @"createdAt": self.createdAt ?: [FIRFieldValue fieldValueForServerTimestamp],
        @"updatedAt": [FIRFieldValue fieldValueForServerTimestamp]
    };
}

- (NSString *)displayAgeText {
    NSInteger months = MAX(0, self.ageInMonths);
    NSString *moUnit = kLang(@"pet_age_months_short") ?: @"mo";
    NSString *yrUnit = kLang(@"pet_age_years_short") ?: @"yr";
    if (months < 12) return [NSString stringWithFormat:@"%ld %@", (long)months, moUnit];
    NSInteger years = months / 12;
    NSInteger rem = months % 12;
    return rem == 0 ? [NSString stringWithFormat:@"%ld %@", (long)years, yrUnit]
                    : [NSString stringWithFormat:@"%ld %@ %ld %@", (long)years, yrUnit, (long)rem, moUnit];
}

@end
