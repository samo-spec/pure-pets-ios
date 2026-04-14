//
//  ServiceModel.m
//  Pure Pets
//
//  Upgraded to match PPServiceModel architecture.
//

#import "ServiceModel.h"
#import "ArabicNormalizer.h"

// Private readwrite redeclaration for readonly properties
@interface ServiceModel ()
@property (nonatomic, copy) NSString *searchTitle;
@property (nonatomic, assign) BOOL isDisabled;
@property (nonatomic, assign) BOOL isBlocked;
@property (nonatomic, assign) BOOL isDeleted;
@property (nonatomic, copy)   NSString *verificationStatus;
@property (nonatomic, copy)   NSString *subscriptionPlan;
@property (nonatomic, copy)   NSString *subscriptionStatus;
@property (nonatomic, assign) BOOL subscriptionActive;
@property (nonatomic, strong, nullable) NSDate *subscriptionStartDate;
@property (nonatomic, strong, nullable) NSDate *subscriptionEndDate;
@end

@implementation ServiceModel

#pragma mark - Date Helper

+ (nullable NSDate *)pp_dateFromValue:(id)value {
    if (!value || [value isKindOfClass:[NSNull class]]) return nil;
    if ([value isKindOfClass:[NSDate class]]) return value;
    if ([value respondsToSelector:@selector(dateValue)]) return [value dateValue];
    return nil;
}

#pragma mark - Computed Aliases

- (NSString *)descriptionText {
    return self.desc ?: @"";
}

#pragma mark - Search

- (NSString *)searchTitle {
    if (_searchTitle.length > 0) return _searchTitle;
    return [ArabicNormalizer normalize:self.title ?: @""];
}

#pragma mark - Localized Helpers

- (NSString *)localizedTypeName {
    switch (self.type) {
        case ServiceTypeGrooming: return kLang(@"typeGrooming");
        case ServiceTypeTraining: return kLang(@"typeTraining");
        default: return @"";
    }
}

- (NSString *)localizedVerificationStatus {
    NSString *v = [self.verificationStatus lowercaseString] ?: @"";
    if ([v isEqualToString:@"verified"]) return kLang(@"verifVerified");
    if ([v isEqualToString:@"pending"] || [v isEqualToString:@"pending_review"]) return kLang(@"verifPending");
    if ([v isEqualToString:@"rejected"] || [v isEqualToString:@"blocked"]) return kLang(@"verifRejected");
    return self.verificationStatus ?: kLang(@"verifNotSet");
}

- (NSString *)localizedAvailabilityStatus {
    if (self.isBlocked)  return kLang(@"statusBlocked");
    if (self.isDisabled) return kLang(@"statusDisabled");
    return self.isAvailable ? kLang(@"Serv_Available") : kLang(@"Serv_Unavailable");
}

- (BOOL)isLive {
    return !self.isDeleted && !self.isBlocked && !self.isDisabled && self.isAvailable;
}

#pragma mark - Provider Serialization (writes only provider-controlled fields)

- (NSDictionary *)providerToDictionary {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"title"]          = self.title ?: @"";
    d[@"searchTitle"]    = [ArabicNormalizer normalize:self.title ?: @""];
    d[@"description"]    = self.desc ?: @"";
    d[@"price"]          = @(self.price);
    d[@"currency"]       = self.currency ?: @"QAR";
    d[@"category"]       = self.category ?: @"";
    d[@"categoryID"]     = self.categoryID ?: @"";
    d[@"petMainKindID"]  = @(self.petMainKindID);
    d[@"type"]           = @(self.type);
    d[@"imageURL"]       = self.imageURL ?: @"";
    d[@"blurHash"]       = self.blurHash ?: @"";
    d[@"serviceOwnerID"] = self.serviceOwnerID ?: @"";
    d[@"isAvailable"]    = @(self.isAvailable);
    d[@"updatedAt"]      = [NSDate date];
    return [d copy];
}

#pragma mark - Full Serialization (backward compat round-trip)

- (NSDictionary *)toDictionary {
    NSMutableDictionary *d = [[self providerToDictionary] mutableCopy];

    // Legacy / system fields preserved for Firestore round-trip
    d[@"availableDate"]  = self.availableDate ?: [NSNull null];
    d[@"timestamp"]      = self.timestamp ?: [NSDate date];
    d[@"createdAt"]      = self.createdAt ?: [NSNull null];

    // Rating / reviews
    if (self.ratingValue != nil) {
        d[@"rating"] = self.ratingValue;
    }
    if (self.reviewCount > 0) {
        d[@"reviewCount"] = @(self.reviewCount);
    }
    if (self.availabilityStatus.length > 0) {
        d[@"availabilityStatus"] = self.availabilityStatus;
    }

    // System status (read-only but preserved on full write)
    d[@"isDisabled"]          = @(self.isDisabled);
    d[@"isBlocked"]           = @(self.isBlocked);
    d[@"isDeleted"]           = @(self.isDeleted);
    d[@"verificationStatus"]  = self.verificationStatus ?: @"";

    // Subscription (read-only but preserved on full write)
    d[@"subscriptionPlan"]      = self.subscriptionPlan ?: @"";
    d[@"subscriptionStatus"]    = self.subscriptionStatus ?: @"";
    d[@"subscriptionActive"]    = @(self.subscriptionActive);
    d[@"subscriptionStartDate"] = self.subscriptionStartDate ?: [NSNull null];
    d[@"subscriptionEndDate"]   = self.subscriptionEndDate ?: [NSNull null];

    // Extra passthrough
    [d addEntriesFromDictionary:self.extraFields ?: @{}];

    return [d copy];
}

#pragma mark - Deserialization

- (instancetype)initWithDictionary:(NSDictionary *)dict documentID:(NSString *)documentID {
    self = [super init];
    if (self) {
        [self parseFromDictionary:dict documentID:documentID];
    }
    return self;
}

+ (instancetype)fromDictionary:(NSDictionary *)dict withID:(NSString *)serviceID {
    return [[self alloc] initWithDictionary:dict documentID:serviceID];
}

- (void)parseFromDictionary:(NSDictionary *)dict documentID:(NSString *)documentID {
    // Identity
    _serviceID      = documentID ?: @"";
    _serviceOwnerID = [dict[@"serviceOwnerID"] isKindOfClass:NSString.class] ? dict[@"serviceOwnerID"] : @"";
    _title          = [dict[@"title"] isKindOfClass:NSString.class] ? dict[@"title"] : @"";
    _searchTitle    = [dict[@"searchTitle"] isKindOfClass:NSString.class] ? dict[@"searchTitle"] : @"";
    _desc           = [dict[@"description"] isKindOfClass:NSString.class] ? dict[@"description"] : @"";
    _price          = [dict[@"price"] doubleValue];
    _currency       = [dict[@"currency"] isKindOfClass:NSString.class] ? dict[@"currency"] : @"QAR";
    _category       = [dict[@"category"] isKindOfClass:NSString.class] ? dict[@"category"] : @"";
    _categoryID     = [dict[@"categoryID"] isKindOfClass:NSString.class] ? dict[@"categoryID"] : @"";
    _petMainKindID  = [dict[@"petMainKindID"] integerValue];
    _type           = [dict[@"type"] integerValue];
    _imageURL       = [dict[@"imageURL"] isKindOfClass:NSString.class] ? dict[@"imageURL"] : nil;
    _blurHash       = [dict[@"blurHash"] isKindOfClass:NSString.class] ? dict[@"blurHash"] : @"";

    // Availability: prefer explicit isAvailable, fall back to legacy availableDate
    if (dict[@"isAvailable"] != nil && ![dict[@"isAvailable"] isKindOfClass:[NSNull class]]) {
        _isAvailable = [dict[@"isAvailable"] boolValue];
    } else {
        NSDate *avDate = [self.class pp_dateFromValue:dict[@"availableDate"]];
        _isAvailable = (avDate == nil) || ([avDate compare:[NSDate date]] != NSOrderedDescending);
    }

    // Rating / reviews (multiple Firestore key fallbacks)
    id ratingVal = dict[@"rating"] ?: dict[@"averageRating"] ?: dict[@"ratingValue"];
    if ([ratingVal isKindOfClass:NSNumber.class]) {
        _ratingValue = ratingVal;
    } else if ([ratingVal isKindOfClass:NSString.class] && [((NSString *)ratingVal) length] > 0) {
        _ratingValue = @([((NSString *)ratingVal) doubleValue]);
    }
    id reviewVal = dict[@"reviewCount"] ?: dict[@"reviewsCount"] ?: dict[@"ratingsCount"];
    if ([reviewVal respondsToSelector:@selector(integerValue)]) {
        _reviewCount = [reviewVal integerValue];
    }

    // Legacy availability status string
    _availabilityStatus = [dict[@"availabilityStatus"] isKindOfClass:NSString.class]
        ? dict[@"availabilityStatus"]
        : ([dict[@"status"] isKindOfClass:NSString.class] ? dict[@"status"] : nil);

    // System status (read-only)
    _isDisabled          = [dict[@"isDisabled"] boolValue];
    _isBlocked           = [dict[@"isBlocked"] boolValue];
    _isDeleted           = [dict[@"isDeleted"] boolValue];
    _verificationStatus  = dict[@"verificationStatus"] ?: @"";

    // Subscription (read-only)
    _subscriptionPlan      = dict[@"subscriptionPlan"] ?: @"free";
    _subscriptionStatus    = dict[@"subscriptionStatus"] ?: @"";
    _subscriptionActive    = [dict[@"subscriptionActive"] boolValue];
    _subscriptionStartDate = [self.class pp_dateFromValue:dict[@"subscriptionStartDate"]];
    _subscriptionEndDate   = [self.class pp_dateFromValue:dict[@"subscriptionEndDate"]];

    // Timestamps
    _createdAt     = [self.class pp_dateFromValue:dict[@"createdAt"]];
    _updatedAt     = [self.class pp_dateFromValue:dict[@"updatedAt"]];
    _availableDate = [self.class pp_dateFromValue:dict[@"availableDate"]];
    _timestamp     = [self.class pp_dateFromValue:dict[@"timestamp"]] ?: [NSDate date];

    // Extra fields passthrough
    NSSet *knownKeys = [NSSet setWithArray:@[
        @"title", @"searchTitle", @"description", @"price", @"currency",
        @"category", @"categoryID", @"petMainKindID", @"type",
        @"imageURL", @"blurHash", @"serviceOwnerID", @"isAvailable",
        @"availableDate", @"timestamp", @"createdAt", @"updatedAt",
        @"isDisabled", @"isBlocked", @"isDeleted", @"verificationStatus",
        @"subscriptionType", @"subscriptionPlan", @"subscriptionStatus",
        @"subscriptionActive", @"subscriptionStartDate", @"subscriptionEndDate",
        @"rating", @"averageRating", @"ratingValue", @"reviewCount",
        @"reviewsCount", @"ratingsCount", @"availabilityStatus", @"status",
        @"serviceFlags", @"archivedAt", @"archivedBy", @"blockedBy", @"disabledBy"
    ]];
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    [dict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if (![knownKeys containsObject:key]) extra[key] = obj;
    }];
    _extraFields = [extra copy];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    ServiceModel *c = [[ServiceModel allocWithZone:zone] init];
    c->_serviceID      = [_serviceID copy];
    c->_serviceOwnerID = [_serviceOwnerID copy];
    c->_title          = [_title copy];
    c->_searchTitle    = [_searchTitle copy];
    c->_desc           = [_desc copy];
    c.price            = _price;
    c->_currency       = [_currency copy];
    c->_category       = [_category copy];
    c->_categoryID     = [_categoryID copy];
    c.petMainKindID    = _petMainKindID;
    c.type             = _type;
    c->_imageURL       = [_imageURL copy];
    c->_blurHash       = [_blurHash copy];
    c.isAvailable      = _isAvailable;
    c->_ratingValue    = [_ratingValue copy];
    c.reviewCount      = _reviewCount;
    c->_availabilityStatus = [_availabilityStatus copy];
    c.isDisabled       = _isDisabled;
    c.isBlocked        = _isBlocked;
    c.isDeleted        = _isDeleted;
    c.verificationStatus   = [_verificationStatus copy];
    c.subscriptionPlan     = [_subscriptionPlan copy];
    c.subscriptionStatus   = [_subscriptionStatus copy];
    c.subscriptionActive   = _subscriptionActive;
    c.subscriptionStartDate = _subscriptionStartDate;
    c.subscriptionEndDate  = _subscriptionEndDate;
    c->_createdAt      = _createdAt;
    c->_updatedAt      = _updatedAt;
    c->_availableDate  = _availableDate;
    c->_timestamp      = _timestamp;
    c->_extraFields    = [_extraFields copy];
    return c;
}

@end











