//
//  AnimalKindsClass.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 04/08/2024.
//


#import "MainKindsModel.h"
static NSString * const PPMainKindAccessoryCategoriesCacheKey = @"accessoryCategoriesSubCollection";

@implementation PPAccessoryCategoryModel

- (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot mainKindID:(NSInteger)mainKindID {
    NSMutableDictionary *data = [NSMutableDictionary dictionaryWithDictionary:snapshot.data ?: @{}];
    data[@"documentID"] = snapshot.documentID ?: @"";
    if (!data[@"id"]) data[@"id"] = snapshot.documentID ?: @"";
    return [self initWithDict:data mainKindID:mainKindID];
}

- (instancetype)initWithDict:(NSDictionary *)dict mainKindID:(NSInteger)mainKindID {
    self = [super init];
    if (self) {
        NSString *docID = [dict[@"documentID"] isKindOfClass:NSString.class] ? dict[@"documentID"] : @"";
        NSString *catID = [dict[@"id"] isKindOfClass:NSString.class] ? dict[@"id"] : nil;
        if (catID.length == 0 && [dict[@"categoryID"] isKindOfClass:NSString.class]) catID = dict[@"categoryID"];
        if (catID.length == 0) catID = docID;

        self.categoryID = catID ?: @"";
        self.documentID = docID.length ? docID : self.categoryID;
        self.nameAr = [dict[@"nameAr"] isKindOfClass:NSString.class] ? dict[@"nameAr"] : ([dict[@"name_ar"] isKindOfClass:NSString.class] ? dict[@"name_ar"] : @"");
        self.nameEn = [dict[@"nameEn"] isKindOfClass:NSString.class] ? dict[@"nameEn"] : ([dict[@"name_en"] isKindOfClass:NSString.class] ? dict[@"name_en"] : @"");
        self.mainKindID = mainKindID;
        self.sortingKey = dict[@"sortingKey"] ? [dict[@"sortingKey"] integerValue] : [dict[@"order"] integerValue];
        id enabledValue = dict[@"enabled"];
        self.enabled = enabledValue == nil ? YES : [enabledValue boolValue];
    }
    return self;
}

- (NSDictionary *)toCacheDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"id"] = self.categoryID ?: @"";
    dict[@"documentID"] = self.documentID ?: self.categoryID ?: @"";
    dict[@"nameAr"] = self.nameAr ?: @"";
    dict[@"nameEn"] = self.nameEn ?: @"";
    dict[@"mainKindID"] = @(self.mainKindID);
    dict[@"sortingKey"] = @(self.sortingKey);
    dict[@"enabled"] = @(self.enabled);
    return dict.copy;
}

- (NSString *)displayName {
    NSString *primary = [Language languageVal] == 0 ? self.nameEn : self.nameAr;
    NSString *fallback = [Language languageVal] == 0 ? self.nameAr : self.nameEn;
    if (primary.length) return primary;
    if (fallback.length) return fallback;
    return self.categoryID.length ? self.categoryID : (self.documentID ?: @"");
}

- (id)formValue {
    return self.categoryID ?: @"";
}

- (NSString *)formDisplayText {
    return [self displayName];
}

- (NSString *)description {
    return [self displayName];
}

@end

@implementation MainKindsModel

+ (NSString *)kindNameForID:(NSInteger)kindID inArray:(NSArray<MainKindsModel *> *)kindsArray {
    for (MainKindsModel *kind in kindsArray) {
        if (kind.ID == kindID) {
            // Return name based on device language
            return kind.KindName;
        }
    }
    return @""; // Return empty string if not found
}

+ (NSString *)kindNameForID:(NSInteger)kindID {
    for (MainKindsModel *kind in MKM.MainKindsArray) {
        if (kind.ID == kindID) {
            // Return name based on device language
            return kind.KindName;
        }
    }
    return @""; // Return empty string if not found
}


+ (MainKindsModel *)mainKindModelForID:(NSInteger)kindID {
    for (MainKindsModel *kind in MKM.MainKindsArray) {
        if (kind.ID == kindID) {
            // Return name based on device language
            return kind;
        }
    }
    return nil; // Return empty string if not found
}



+ (MainKindsModel *)mainKindClassForID:(NSInteger)kindID inArray:(NSArray<MainKindsModel *> *)kindsArray {
    for (MainKindsModel *kind in kindsArray) {
        if (kind.ID == kindID) {
            // Return name based on device language
            return kind;
        }
    }
    return nil; // Return empty string if not found
}

- (void)pp_loadAccessoryCategoriesFromArray:(id)rawCategories {
    self.accessoryCategories = [NSMutableArray array];
    if (![rawCategories isKindOfClass:NSArray.class]) {
        self.didSeedAccessoryCategories = NO;
        return;
    }

    for (NSDictionary *dict in (NSArray *)rawCategories) {
        if (![dict isKindOfClass:NSDictionary.class]) continue;
        PPAccessoryCategoryModel *category = [[PPAccessoryCategoryModel alloc] initWithDict:dict mainKindID:self.ID];
        if (category.categoryID.length > 0 && category.enabled) {
            [self.accessoryCategories addObject:category];
        }
    }

    [self.accessoryCategories sortUsingComparator:^NSComparisonResult(PPAccessoryCategoryModel *a, PPAccessoryCategoryModel *b) {
        if (a.sortingKey != b.sortingKey) {
            return a.sortingKey < b.sortingKey ? NSOrderedAscending : NSOrderedDescending;
        }
        return [[a displayName] localizedCaseInsensitiveCompare:[b displayName]];
    }];
    self.didSeedAccessoryCategories = self.accessoryCategories.count > 0;
}

-(NSString *)KindName
{
    return [Language languageVal] == 0 ? self.KindNameEn : self.KindNameAr;
}
-(id)formValue
{
    return self;
}

- (nonnull NSString *)formDisplayText {
    return [Language languageVal] == 0 ? self.KindNameEn : self.KindNameAr ;
}

//[document.documentID integerValue]
- (instancetype)initWithId:(NSString *)mainKindID dictionary:(NSDictionary *)dictionary
{
    self = [super init];
    if (self) {
        id visibleInUserApp = dictionary[@"is_visible_in_user_app"];
        self.documentID = [dictionary[@"documentID"] isKindOfClass:NSString.class] ? dictionary[@"documentID"] : mainKindID;
        self.ID = [mainKindID integerValue];
        self.sortingKey = [dictionary[@"sortingKey"]  integerValue];
        self.isVisibleInUserApp = visibleInUserApp == nil ? YES : [visibleInUserApp boolValue];

        self.LightenAmount = [dictionary[@"LightenAmount"] floatValue];
        self.professionalAngle = [dictionary[@"professionalAngle"] floatValue];
        self.KindNameAr = dictionary[@"KindNameAr"];
        self.KindNameEn = dictionary[@"KindNameEn"];
        self.PetColor = dictionary[@"PetColor"];
        self.KindImageNamed = dictionary[@"KindImageNamed"];
        self.KindIconName = dictionary[@"KindIconName"];
        self.KindImageFile = (self.KindImageNamed.length > 0) ? [UIImage imageNamed:self.KindImageNamed] : nil;
        self.KindImageUrl = dictionary[@"KindImageUrl"];
        self.SubKindsArray = [[NSMutableArray<SubKindModel *> alloc] init];
        NSMutableDictionary *dic =dictionary[@"SubKindsArray"];

        for (NSDictionary *SubKind in dic) {
            // NSLog(@"subSubKind: %@", SubKind);
            SubKindModel *subKind = [[SubKindModel alloc] initWithDict:SubKind];
            [self.SubKindsArray addObject:subKind];
        }
        [self pp_loadAccessoryCategoriesFromArray:dictionary[PPMainKindAccessoryCategoriesCacheKey]];
    }
    return self;
}

- (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot {
    self = [super init];
    if (self) {
        id visibleInUserApp = snapshot.data[@"is_visible_in_user_app"];
        self.ID = [snapshot.data[@"ID"] integerValue];
        self.sortingKey = [snapshot.data[@"sortingKey"] integerValue];
        self.isVisibleInUserApp = visibleInUserApp == nil ? YES : [visibleInUserApp boolValue];
        self.KindNameAr = snapshot.data[@"KindNameAr"];
        self.documentID = snapshot.documentID;
        self.KindNameEn = snapshot.data[@"KindNameEn"];
        self.PetColor = snapshot.data[@"PetColor"];
        self.KindImageNamed = snapshot.data[@"KindImageNamed"];
        self.KindImageUrl = snapshot.data[@"KindImageUrl"];
        self.KindIconName = snapshot.data[@"KindIconName"];
        self.KindImageFile = (self.KindImageNamed.length > 0) ? [UIImage imageNamed:self.KindImageNamed] : nil;
        //NSLog(@"[ImageLoader] KindImageUrl %@", self.KindImageUrl);

        // ✅ Correct type conversion
        self.LightenAmount = [snapshot.data[@"LightenAmount"] floatValue];
        self.professionalAngle = [snapshot.data[@"professionalAngle"] floatValue];
        //NSLog(@"LightenAmount ----- >>>> %.2f", self.LightenAmount);

        self.SubKindsArray = [[NSMutableArray<SubKindModel *> alloc] init];
        NSMutableDictionary *dic = snapshot.data[@"SubKindsArray"];
        for (NSDictionary *subKind in dic) {
            SubKindModel *subKindModel = [[SubKindModel alloc] initWithDict:subKind];
            [self.SubKindsArray addObject:subKindModel];
        }
        [self pp_loadAccessoryCategoriesFromArray:snapshot.data[PPMainKindAccessoryCategoriesCacheKey]];


    }
    return self;
}

- (instancetype)initWithDict:(NSDictionary *)data {
    self = [super init];
    if (self) {
        id visibleInUserApp = data[@"is_visible_in_user_app"];
        self.ID = [data[@"ID"] integerValue];
        self.sortingKey = [data[@"sortingKey"] integerValue];
        self.isVisibleInUserApp = visibleInUserApp == nil ? YES : [visibleInUserApp boolValue];
        self.KindNameAr = data[@"KindNameAr"];
        self.documentID = [data[@"documentID"] isKindOfClass:NSString.class] ? data[@"documentID"] : [NSString stringWithFormat:@"%ld",[data[@"ID"] integerValue]];
        self.KindNameEn = data[@"KindNameEn"];
        self.PetColor = data[@"PetColor"];
        self.KindImageNamed = data[@"KindImageNamed"];
        self.KindIconName = data[@"KindIconName"];
        self.KindImageUrl = data[@"KindImageUrl"];
        self.KindImageFile = (self.KindImageNamed.length > 0) ? [UIImage imageNamed:self.KindImageNamed] : nil;
        //NSLog(@"[ImageLoader] KindImageUrl %@", self.KindImageUrl);

        // ✅ Correct type conversion
        self.LightenAmount = [data[@"LightenAmount"] floatValue];
        self.professionalAngle = [data[@"professionalAngle"] floatValue];
        //NSLog(@"LightenAmount ----- >>>> %.2f", self.LightenAmount);

        self.SubKindsArray = [[NSMutableArray<SubKindModel *> alloc] init];
        NSMutableDictionary *dic = data[@"SubKindsArray"];
        for (NSDictionary *subKind in dic) {
            SubKindModel *subKindModel = [[SubKindModel alloc] initWithDict:subKind];
            [self.SubKindsArray addObject:subKindModel];
        }
        [self pp_loadAccessoryCategoriesFromArray:data[PPMainKindAccessoryCategoriesCacheKey]];


    }
    return self;
}

- (void)addSubKind:(SubKindModel *)subKind {
    if (!self.SubKindsArray) {
        self.SubKindsArray = [NSMutableArray array];
    }

    // Prevent duplicates
    for (SubKindModel *existingSubKind in self.SubKindsArray) {
        if (existingSubKind.ID == subKind.ID) {
            NSLog(@"SubKind with ID %ld already exists", (long)subKind.ID);
            return;
        }
    }

    subKind.MainKindID = self.ID;  // Ensure correct reference
    [self.SubKindsArray addObject:subKind];
}

// Convert MainKindsModel (including SubKindsArray) to Firestore-compatible dictionary
- (NSDictionary *)toFirestoreDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"ID"] = @(self.ID);
    dict[@"sortingKey"] = @(self.sortingKey);
    dict[@"KindNameAr"] = self.KindNameAr ?: @"";
    dict[@"KindNameEn"] = self.KindNameEn ?: @"";
    dict[@"KindImageNamed"] = self.KindImageNamed ?: @"";
    dict[@"KindIconName"] = self.KindIconName ?: @"";
    dict[@"PetColor"] = self.PetColor ?: @"";
    dict[@"documentID"] = self.documentID ?: @"";
    dict[@"KindImageUrl"] = self.KindImageUrl ?: @"";
    dict[@"LightenAmount"] = @(self.LightenAmount);
    dict[@"professionalAngle"] = @(self.professionalAngle);
    dict[@"is_visible_in_user_app"] = @(self.isVisibleInUserApp);

    // Convert SubKindsArray to an array of dictionaries
    NSMutableArray *subKindsData = [NSMutableArray array];
    for (SubKindModel *subKind in self.SubKindsArray) {
        [subKindsData addObject:@{
            @"ID": @(subKind.ID),
            @"MainKindID": @(subKind.MainKindID),
            @"SubKindNameAr": subKind.SubKindNameAr ?: @"",
            @"SubKindNameEn": subKind.SubKindNameEn ?: @"",
            @"subKindIconUrl": subKind.subKindIconUrl ?: @"",
            @"subKindIconBlurHash": subKind.subKindIconBlurHash ?: @"",
            @"have_subSub": @(subKind.have_subSub),
            @"have_items": @(subKind.have_items),
            @"adultHood": @(subKind.adultHood)
        }];
    }
    dict[@"SubKindsArray"] = subKindsData;

    return dict;
}

- (NSDictionary *)toCacheDictionary {
    NSMutableDictionary *dict = [[self toFirestoreDictionary] mutableCopy];
    NSMutableArray *categoryData = [NSMutableArray array];
    for (PPAccessoryCategoryModel *category in self.accessoryCategories ?: @[]) {
        [categoryData addObject:[category toCacheDictionary]];
    }
    dict[PPMainKindAccessoryCategoriesCacheKey] = categoryData.copy;
    return dict.copy;
}


- (SubKindModel *)subKindForID:(NSInteger)subID {
    for (SubKindModel *sk in self.SubKindsArray) {
        if (sk.ID == subID) return sk;
    }
    return nil;
}

- (PPAccessoryCategoryModel *)accessoryCategoryForID:(NSString *)categoryID {
    if (categoryID.length == 0) return nil;
    for (PPAccessoryCategoryModel *category in self.accessoryCategories ?: @[]) {
        if ([category.categoryID isEqualToString:categoryID] || [category.documentID isEqualToString:categoryID]) {
            return category;
        }
    }
    return nil;
}


+ (MainKindsModel *)allKind
{
    MainKindsModel *model = [[MainKindsModel alloc]init];

    model.documentID = @"-1";
    model.ID = -1;
    model.KindNameAr = @"الكل";
    model.KindNameEn = @"all";
    model.KindImageNamed = @"square-layout";
    model.KindIconName = @"square-layout";
    model.isVisibleInUserApp = YES;
    model.KindImageFile = [UIImage imageNamed:@"square-layout"];
    model.SubKindsArray = [[NSMutableArray<SubKindModel *> alloc] init];
    model.accessoryCategories = [NSMutableArray array];
    return  model;
}

#pragma mark - Accent Color

- (UIColor *)accentColorForKind:(MainKindsModel *)kind
{
    if (!kind) {
        return UIColor.systemGrayColor;
    }

    switch (kind.ID) {
        case 1: // Dogs
            return [UIColor colorWithRed:0.25 green:0.55 blue:0.95 alpha:1.0];
        case 2: // Cats
            return [UIColor colorWithRed:0.95 green:0.55 blue:0.25 alpha:1.0];
        case 3: // Birds
            return [UIColor colorWithRed:0.30 green:0.75 blue:0.55 alpha:1.0];
        case 4: // Fish
            return [UIColor colorWithRed:0.20 green:0.65 blue:0.85 alpha:1.0];
        case 5: // Small Pets
            return [UIColor colorWithRed:0.70 green:0.55 blue:0.90 alpha:1.0];
        default:
            return UIColor.systemBlueColor;
    }
}


-(UIColor *)kindColor
{
    if (self.PetColor && self.PetColor.length > 0) {
        return [UIColor colorWithHexString:self.PetColor];
    }

    if(self.ID == 1)        return [UIColor colorWithRed:0.08 green:0.68 blue:0.68 alpha:1.0]; // Distinct Teal #14B8A6
    else if(self.ID == 2)    return [UIColor colorWithHexString:@"#D57E3C"];
    else if(self.ID == 3)    return [UIColor colorWithHexString:@"#491708"];
    else if(self.ID == 4)    return [UIColor colorWithHexString:@"#A49179"];
    else if(self.ID == 5)    return [UIColor colorWithRed:0.25 green:0.55 blue:0.95 alpha:1.0]; // Cat Blue
    else if(self.ID == 6)    return [UIColor colorWithRed:0.95 green:0.55 blue:0.25 alpha:1.0]; //[UIColor colorWithHexString:@"#BFA779"];
    else if(self.ID == 7)    return [UIColor colorWithHexString:@"#A4491F"]; //76D6FF
    else if(self.ID == 8)    return [UIColor colorWithHexString:@"#D7606E"];
    else if(self.ID == 9)    return [UIColor colorWithHexString:@"#D7606E"];
    else if(self.ID == 10)    return [UIColor colorWithHexString:@"#B49F80"];
    else if(self.ID == 11)    return [UIColor colorWithHexString:@"#A4937B"];
    else  return [UIColor colorWithHexString:@"#"];

}



/*

-(UIColor *)kindColor
{
    if(self.ID == 1)        return [UIColor colorWithHexString:@"#E55B46"];
    else if(self.ID == 2)    return [UIColor colorWithHexString:@"#D57E3C"];
    else if(self.ID == 3)    return [UIColor colorWithHexString:@"#491708"];
    else if(self.ID == 4)    return [UIColor colorWithHexString:@"#A49179"];
    else if(self.ID == 5)    return [UIColor colorWithHexString:@"#A46C36"];
    else if(self.ID == 6)    return [UIColor colorWithHexString:@"#BFA779"];
    else if(self.ID == 7)    return [UIColor colorWithHexString:@"#A4491F"]; //76D6FF
    else if(self.ID == 8)    return [UIColor colorWithHexString:@"#D7606E"];
    else if(self.ID == 9)    return [UIColor colorWithHexString:@"#D7606E"];
    else if(self.ID == 10)    return [UIColor colorWithHexString:@"#B49F80"];
    else if(self.ID == 11)    return [UIColor colorWithHexString:@"#A4937B"];
    else  return [UIColor colorWithHexString:@"#"];

}



 -(UIColor *)kindColor
 {
     switch (self.ID) {

         case 1: // Parrots
             return [UIColor colorWithHexString:@"#2FA36B"]; // Soft Emerald Green

         case 2: // Falcons
             return [UIColor colorWithHexString:@"#3A4A5E"]; // Deep Falcon Blue-Gray

         case 3: // Cats
             return [UIColor colorWithHexString:@"#9B9BB3"]; // Warm Lavender Gray

         case 4: // Dogs
             return [UIColor colorWithHexString:@"#5DADE2"]; // Soft Sky Blue

         case 5: // Horses
             return [UIColor colorWithHexString:@"#8B5E3C"]; // Earthy Saddle Brown

         case 6: // Sheep
             return [UIColor colorWithHexString:@"#B8B5AF"]; // Warm Stone Gray

         case 7: // Fish
             return [UIColor colorWithHexString:@"#3CBCC3"]; // Aqua Teal

         case 8: // Camels
             return [UIColor colorWithHexString:@"#D2B48C"]; // Desert Sand

         default:
             return [UIColor colorWithHexString:@"#6C757D"]; // Neutral fallback
     }
 }

 */
@end

