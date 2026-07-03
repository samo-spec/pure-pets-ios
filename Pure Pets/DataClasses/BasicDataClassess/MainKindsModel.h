//
//  AnimalKindsClass.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 04/08/2024.
//


#import "SubKindModel.h"
@import FirebaseFirestore;
NS_ASSUME_NONNULL_BEGIN

@interface PPAccessoryCategoryModel : NSObject<XLFormOptionObject>
@property (nonatomic, copy) NSString *categoryID;
@property (nonatomic, copy) NSString *documentID;
@property (nonatomic, copy) NSString *nameAr;
@property (nonatomic, copy) NSString *nameEn;
@property (nonatomic, assign) NSInteger mainKindID;
@property (nonatomic, assign) NSInteger sortingKey;
@property (nonatomic, assign) BOOL enabled;
- (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot mainKindID:(NSInteger)mainKindID;
- (instancetype)initWithDict:(NSDictionary *)dict mainKindID:(NSInteger)mainKindID;
- (NSDictionary *)toCacheDictionary;
- (NSString *)displayName;
@end

@interface MainKindsModel : NSObject<XLFormOptionObject>
@property (nonatomic, strong) NSArray<UIColor *> *cachedGradientColors;

@property (nonatomic) BOOL didSeedSubKinds;
@property (nonatomic) BOOL didSeedAccessoryCategories;
@property (nonatomic) NSInteger ID;
@property (nonatomic) NSInteger sortingKey;
@property (nonatomic, strong) NSString *documentID;
@property (nonatomic, strong) NSString *KindNameAr;
@property (nonatomic, strong) NSString *KindNameEn;
@property (nonatomic, strong) NSString *KindImageNamed;
@property (nonatomic, strong) NSMutableArray<SubKindModel *> *SubKindsArray;
@property (nonatomic, strong) NSMutableArray<PPAccessoryCategoryModel *> *accessoryCategories;
@property (nonatomic, strong) NSString *KindName;
@property (nonatomic, assign) BOOL isVisibleInUserApp;
- (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot;
- (instancetype)initWithId:(NSString *)mainKindID dictionary:(NSDictionary *)dictionary;
@property (nonatomic, strong, nullable) NSString *KindImageUrl;
@property (nonatomic, strong, nullable) NSString *KindIconName;
@property (nonatomic, strong, nullable) NSString *PetColor;
@property (nonatomic, strong) UIImage *KindImageFile;
@property (nonatomic, assign) float LightenAmount;
@property (nonatomic, assign) float professionalAngle;
@property (nonatomic, strong) _Nullable id<FIRListenerRegistration> subKindsListener;

+ (NSString *)kindNameForID:(NSInteger)kindID inArray:(NSArray<MainKindsModel *> *)kindsArray;
+ (NSString *)kindNameForID:(NSInteger)kindID ;
+ (MainKindsModel *)mainKindClassForID:(NSInteger)kindID inArray:(NSArray<MainKindsModel *> *)kindsArray;
- (void)addSubKind:(SubKindModel *)subKind;
- (NSDictionary *)toFirestoreDictionary;  // Helper to convert model to Firestore data
- (NSDictionary *)toCacheDictionary;
- (SubKindModel *)subKindForID:(NSInteger)subID;
- (PPAccessoryCategoryModel *)accessoryCategoryForID:(NSString *)categoryID;
+ (MainKindsModel *)mainKindModelForID:(NSInteger)kindID;
@property (nonatomic, strong) UIImage *image;
//LightenAmount:(float)LightenAmount IconName:(NSString *)iconName
- (instancetype)initWithDict:(NSDictionary *)data ;
+ (MainKindsModel *)allKind;
-(UIColor *)kindColor;
@end

NS_ASSUME_NONNULL_END
