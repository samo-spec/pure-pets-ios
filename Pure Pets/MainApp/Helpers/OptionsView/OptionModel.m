//
//  OptionModel.m
//

#import "OptionModel.h"

static NSString * const kDefaultsKey_Options      = @"SavedOptionModels_v2_secure"; // new, secure
static NSString * const kDefaultsKey_LegacyDicts  = @"SavedOptionModels";          // legacy [dict] array
static dispatch_queue_t OptionsQueue(void) {
    static dispatch_queue_t q;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        q = dispatch_queue_create("com.purepets.options.queue", DISPATCH_QUEUE_SERIAL);
    });
    return q;
}

@interface OptionModel ()
@property (nonatomic, copy, readwrite) NSString *optID;
@end

@implementation OptionModel


#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    // Use encodeObject:forKey: for all properties to ensure secure coding compatibility
    if (self.optID) [coder encodeObject:self.optID forKey:@"optID"];
    if (self.title) [coder encodeObject:self.title forKey:@"title"];
    if (self.subtitle) [coder encodeObject:self.subtitle forKey:@"subtitle"];
    if (self.imageName) [coder encodeObject:self.imageName forKey:@"imageName"];
    if (self.systemImageName) [coder encodeObject:self.systemImageName forKey:@"systemImageName"];
    
    [coder encodeInt64:self.sortOrder forKey:@"sortOrder"];
    [coder encodeBool:self.pinned forKey:@"pinned"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    NSString *oid = [coder decodeObjectOfClass:NSString.class forKey:@"optID"];
    NSString *ttl = [coder decodeObjectOfClass:NSString.class forKey:@"title"];
    
    // Provide defaults if decoding fails
    if (!oid) oid = [[NSUUID UUID] UUIDString];
    if (!ttl) ttl = @"";
    
    if (self = [self initWithID:oid title:ttl]) {
        _subtitle = [coder decodeObjectOfClass:NSString.class forKey:@"subtitle"];
        _imageName = [coder decodeObjectOfClass:NSString.class forKey:@"imageName"];
        _systemImageName = [coder decodeObjectOfClass:NSString.class forKey:@"systemImageName"];
        
        // Safe decoding for primitive types
        if ([coder containsValueForKey:@"sortOrder"]) {
            _sortOrder = [coder decodeInt64ForKey:@"sortOrder"];
        }
        
        if ([coder containsValueForKey:@"pinned"]) {
            _pinned = [coder decodeBoolForKey:@"pinned"];
        }
    }
    return self;
}


#pragma mark - Init

- (instancetype)init {
    return [self initWithID:[[NSUUID UUID] UUIDString]
                      title:@""
                   subtitle:nil
                  imageName:nil
            systemImageName:nil];
}


- (instancetype)initWithID:(NSString *)optID
                     title:(NSString *)title
                  subtitle:(NSString *)subtitle
                 imageName:(NSString *)imageName
           systemImageName:(NSString *)systemImageName
{
    NSParameterAssert(optID.length > 0);
    NSParameterAssert(title.length > 0);

    if (self = [super init]) {
        _optID           = [optID copy];
        _title           = [title copy];
        _subtitle        = [subtitle copy];
        _imageName       = [imageName copy];
        _systemImageName = [systemImageName copy];
        _sortOrder       = 0;
        _pinned          = NO;
    }
    return self;
}

- (instancetype)initWithID:(NSString *)optID title:(NSString *)title {
    return [self initWithID:optID title:title subtitle:nil imageName:nil systemImageName:nil];
}

+ (instancetype)optionWithID:(NSString *)optID title:(NSString *)title imageName:(NSString *)imageName {
    return [[self alloc] initWithID:optID title:title subtitle:nil imageName:imageName systemImageName:nil];
}

// New method with description support
+ (instancetype)optionWithID:(NSString *)optID
                       title:(NSString *)title
                   imageName:(nullable NSString *)imageName
                 systemImage:(nullable NSString *)systemImageName
                        desc:(NSString *)desc
{
    return [[self alloc] initWithID:optID
                              title:title
                           subtitle:desc
                          imageName:imageName
                    systemImageName:systemImageName];
}

+ (instancetype)optionWithID:(NSString *)optID title:(NSString *)title systemImage:(NSString *)systemImageName {
    return [[self alloc] initWithID:optID title:title subtitle:nil imageName:nil systemImageName:systemImageName];
}




#pragma mark - XLFormOptionObject

- (id)formValue { return self; }
- (NSString *)formDisplayText { return self.title ?: @""; }

#pragma mark - NSSecureCoding


#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    OptionModel *c = [[[self class] allocWithZone:zone] initWithID:self.optID
                                                             title:self.title ?: @""
                                                          subtitle:self.subtitle
                                                         imageName:self.imageName
                                                   systemImageName:self.systemImageName];
    c.sortOrder = self.sortOrder;
    c.pinned    = self.pinned;
    return c;
}

#pragma mark - Equality

- (BOOL)isEqual:(id)object {
    if (self == object) return YES;
    if (![object isKindOfClass:OptionModel.class]) return NO;
    return [self.optID isEqualToString:((OptionModel *)object).optID];
}

- (NSUInteger)hash {
    return self.optID.hash;
}

#pragma mark - Sorting helper

+ (NSArray<OptionModel *> *)sortedArray:(NSArray<OptionModel *> *)arr {
    return [arr sortedArrayUsingComparator:^NSComparisonResult(OptionModel *a, OptionModel *b) {
        // pinned first
        if (a.isPinned != b.isPinned) return a.isPinned ? NSOrderedAscending : NSOrderedDescending;
        // then sortOrder
        if (a.sortOrder != b.sortOrder) return (a.sortOrder < b.sortOrder) ? NSOrderedAscending : NSOrderedDescending;
        // then localized title
        return [a.title ?: @"" localizedCaseInsensitiveCompare:b.title ?: @""];
    }];
}

#pragma mark - Persistence (NSUserDefaults)

#pragma mark - Persistence (NSUserDefaults)

+ (NSArray<OptionModel *> *)getSavedOptionModels {
    __block NSArray<OptionModel *> *result = nil;
        NSUserDefaults *d = NSUserDefaults.standardUserDefaults;

        // Try secure (new) - with better error handling
        NSData *data = [d objectForKey:kDefaultsKey_Options];
        if ([data isKindOfClass:NSData.class]) {
            NSError *err = nil;
            NSSet *classes = [NSSet setWithObjects:NSArray.class, OptionModel.class, NSString.class, NSNumber.class, nil];
            NSArray *decoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:data error:&err];
            
            if (err) {
                NSLog(@"❌ Error unarchiving OptionModels: %@", err);
                // Fall through to legacy method
            } else if ([decoded isKindOfClass:NSArray.class]) {
                result = [self sortedArray:decoded];
               
            }
        }

        // Fallback: legacy array of dictionaries
        NSArray *legacy = [d objectForKey:kDefaultsKey_LegacyDicts];
        NSMutableArray<OptionModel *> *converted = [NSMutableArray array];
        if ([legacy isKindOfClass:NSArray.class]) {
            for (id obj in legacy) {
                if ([obj isKindOfClass:NSDictionary.class]) {
                    OptionModel *m = [OptionModel fromDictionary:(NSDictionary *)obj];
                    if (m) [converted addObject:m];
                }
            }
            result = [self sortedArray:converted];
            
            // Migrate to new format
            if (converted.count > 0) {
                [self saveOptionsArray:converted];
                // Remove legacy key
                [d removeObjectForKey:kDefaultsKey_LegacyDicts];
                [d synchronize];
            }
        }
        
        // If still no result, return empty array
        if (!result) {
            result = @[];
        }

    return result ?: @[];
}

+ (void)saveOptionsArray:(NSArray<OptionModel *> *)options {
    dispatch_async(OptionsQueue(), ^{
        NSArray<OptionModel *> *unique = [self uniqueByID:options];
        NSArray<OptionModel *> *sorted = [self sortedArray:unique];
        
        NSError *err = nil;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:sorted requiringSecureCoding:YES error:&err];
        
        if (err) {
            NSLog(@"❌ Error archiving OptionModels: %@", err);
            
            // Fallback: try non-secure coding
            @try {
                if (@available(iOS 11.0, *)) {
                    data = [NSKeyedArchiver archivedDataWithRootObject:sorted requiringSecureCoding:NO error:&err];
                } else {
                    // iOS 10 and below
                    data = [NSKeyedArchiver archivedDataWithRootObject:sorted];
                }
            } @catch (NSException *exception) {
                NSLog(@"❌ Exception during fallback archiving: %@", exception);
                data = nil;
            }
        }
        
        if (data) {
            [NSUserDefaults.standardUserDefaults setObject:data forKey:kDefaultsKey_Options];
            [NSUserDefaults.standardUserDefaults synchronize];
            NSLog(@"✅ Saved %ld OptionModels", (long)sorted.count);
        } else {
            NSLog(@"❌ Failed to archive OptionModels for saving");
        }
    });
}

+ (NSArray<OptionModel *> *)uniqueByID:(NSArray<OptionModel *> *)arr {
    NSMutableOrderedSet<NSString *> *seen = [NSMutableOrderedSet orderedSet];
    NSMutableArray<OptionModel *> *out = [NSMutableArray array];
    for (OptionModel *m in arr) {
        if (![seen containsObject:m.optID]) {
            [seen addObject:m.optID];
            [out addObject:m];
        }
    }
    return out;
}

+ (void)saveOptionModel:(OptionModel *)newOption {
    if (!newOption.optID.length) return;
    dispatch_async(OptionsQueue(), ^{
        NSMutableArray<OptionModel *> *current = [[self getSavedOptionModels] mutableCopy];
        NSInteger idx = [current indexOfObjectPassingTest:^BOOL(OptionModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [obj.optID isEqualToString:newOption.optID];
        }];
        if (idx != NSNotFound) {
            [current replaceObjectAtIndex:idx withObject:newOption];
        } else {
            [current addObject:newOption];
        }
        [self saveOptionsArray:current];
    });
}

+ (BOOL)removeOptionWithID:(NSString *)optID {
    if (!optID.length) return NO;
    __block BOOL removed = NO;
    dispatch_sync(OptionsQueue(), ^{
        NSMutableArray<OptionModel *> *current = [[self getSavedOptionModels] mutableCopy];
        NSUInteger before = current.count;
        [current filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(OptionModel *obj, NSDictionary *_) {
            return ![obj.optID isEqualToString:optID];
        }]];
        removed = (current.count != before);
        if (removed) [self saveOptionsArray:current];
    });
    return removed;
}

+ (nullable OptionModel *)getOptionByID:(NSString *)optID {
    if (!optID.length) return nil;
    for (OptionModel *m in [self getSavedOptionModels]) {
        if ([m.optID isEqualToString:optID]) return m;
    }
    return nil;
}

+ (nullable NSString *)getOptionTitleByID:(NSString *)optionID {
    return [self getOptionByID:optionID].title;
}

#pragma mark - Dictionary bridge (legacy interop)

- (NSDictionary *)toDictionary {
    NSMutableDictionary *d = [@{
        @"optID": self.optID ?: @"",
        @"title": self.title ?: @"",
        @"sortOrder": @(self.sortOrder),
        @"pinned": @(self.isPinned)
    } mutableCopy];
    if (self.subtitle)        d[@"subtitle"]        = self.subtitle;
    if (self.imageName)       d[@"imageName"]       = self.imageName;
    if (self.systemImageName) d[@"systemImageName"] = self.systemImageName;
    return d;
}

+ (OptionModel *)fromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:NSDictionary.class]) return nil;
    NSString *oid = [dict[@"optID"] isKindOfClass:NSString.class] ? dict[@"optID"] : nil;
    NSString *ttl = [dict[@"title"] isKindOfClass:NSString.class] ? dict[@"title"] : nil;
    if (oid.length == 0 || ttl.length == 0) return nil;

    OptionModel *m = [[self alloc] initWithID:oid
                                        title:ttl
                                     subtitle:[dict[@"subtitle"] isKindOfClass:NSString.class] ? dict[@"subtitle"] : nil
                                    imageName:[dict[@"imageName"] isKindOfClass:NSString.class] ? dict[@"imageName"] : nil
                              systemImageName:[dict[@"systemImageName"] isKindOfClass:NSString.class] ? dict[@"systemImageName"] : nil];
    if ([dict[@"sortOrder"] respondsToSelector:@selector(integerValue)]) {
        m.sortOrder = [dict[@"sortOrder"] integerValue];
    }
    if ([dict[@"pinned"] respondsToSelector:@selector(boolValue)]) {
        m.pinned = [dict[@"pinned"] boolValue];
    }
    return m;
}

- (nonnull instancetype)initWithID:(nonnull NSString *)optID title:(nonnull NSString *)title desc:(nonnull NSString *)desc {
    return [self initWithID:optID
                      title:title
                   subtitle:desc
                  imageName:nil
            systemImageName:nil];
}

@end
