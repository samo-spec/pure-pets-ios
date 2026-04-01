#import <Foundation/Foundation.h>
#import "PetImageItem.h"
NS_ASSUME_NONNULL_BEGIN


typedef NS_ENUM(NSInteger, PetAdStatus) {
    PetAdStatusDraft = 0,
    PetAdStatusActive = 1,
    PetAdStatusSold = 2,
    PetAdStatusExpired = 3,
    PetAdStatusArchived = 4,
    PetAdStatusRejected = 5
};

typedef NS_ENUM(NSInteger, PetAdVisibility) {
    PetAdVisibilityPublic = 0,
    PetAdVisibilityHidden = 1,
    PetAdVisibilityReported = 2,
    PetAdVisibilityShadowBanned = 3
};


typedef NS_ENUM(NSInteger, PetCategory) {
    PetCategoryUnknown = 0,
    PetCategoryBirds = 1,
    PetCategoryCamel = 2,
    PetCategoryHorse = 3,
    PetCategorySheep = 4,
    PetCategoryCats = 5,
    PetCategoryDogs = 6,
    PetCategoryFish = 7,
    PetCategoryDeer = 10,
    PetCategoryFalcon = 11

};



@interface PetAd : NSObject <NSSecureCoding>
@property (nonatomic, strong)   NSString *blurHash;

// ---- Status & Moderation ----
@property (nonatomic, assign) PetAdStatus status;
@property (nonatomic, assign) PetAdVisibility visibility;

// ---- Ranking / Feed ----
@property (nonatomic, strong, nullable) NSNumber *priorityScore; // boosts, featured ads
@property (nonatomic, strong, nullable) NSNumber *rankScore;     // ML / popularity

// ---- Engagement ----
@property (nonatomic, strong, nullable) NSNumber *favoritesCount;
@property (nonatomic, strong, nullable) NSNumber *sharesCount;

// ---- Flags (cached, UI-friendly) ----
@property (nonatomic, assign) BOOL isMine;        // computed once
@property (nonatomic, assign) BOOL isFavorite;    // user-specific
@property (nonatomic, assign) BOOL isNew;         // computed
@property (nonatomic, assign) BOOL isDiscounted;  // computed

// ---- Search ----
@property (nonatomic, strong, nullable) NSArray<NSString *> *keywords;
@property (nonatomic, readonly) NSString *searchIndex;

 
/// Firestore document ID
@property (nonatomic, strong) NSString *adID;
 
/// Owner info
@property (nonatomic, strong) NSString *ownerID;
@property (nonatomic, strong, nullable) NSString *ownerName;
@property (nonatomic, strong, nullable) NSString *ownerContact;

/// Classification
@property (nonatomic, assign) PetCategory category;
@property (nonatomic, assign) NSInteger subcategory;

/// Main Ad Info
@property (nonatomic, strong, nullable) NSString *adTitle;
@property (nonatomic, strong, nullable) NSString *name_lowercase;
@property (nonatomic, readonly) NSString *searchTitle; // optional
@property (nonatomic, strong, nullable) NSString *adDescription;
@property (nonatomic, assign) NSInteger adLocation;
@property (nonatomic, assign) double latitude;
@property (nonatomic, assign) double longitude;
@property (nonatomic, strong, nullable) NSString *geohash;
@property (nonatomic, strong, nullable) NSString *locationName;

/// Pet Details
@property (nonatomic, strong, nullable) NSNumber *price;              ///< In Rials
@property (nonatomic, strong, nullable) NSNumber *discountPercent;    ///< 0–100%
@property (nonatomic, strong, nullable) NSNumber *petAgeMonths;       ///< Age in months
@property (nonatomic, assign) BOOL isFemale;

 @property (nonatomic, strong) NSArray<NSDictionary *> *imageItemsRaw;

/// Media
/// @property (nonatomic, strong, nullable) NSArray<NSString *> *imageURLs;
 @property (nonatomic, strong)  NSArray<PetImageItem *> *imageItems;    // computed items
 @property (nonatomic, strong, nullable) NSMutableArray<UIImage *> *localImages; ///< Temporary local images (not saved to Firestore)

/// Flags
@property (nonatomic, assign) BOOL isSold;

/// Analytics
@property (nonatomic, strong, nullable) NSNumber *viewsCount;

/// Timestamps
@property (nonatomic, strong, nullable) NSDate *postedDate;
@property (nonatomic, strong, nullable) NSDate *createdAt;
@property (nonatomic, strong, nullable) NSDate *updatedAt;
@property (nonatomic, strong, nullable) NSDate *expiresAt;

/// Moderation / integrity flags
@property (nonatomic, assign) BOOL isApproved;
@property (nonatomic, assign) BOOL isDeleted;
@property (nonatomic, assign) BOOL isBlocked;

/// Derived convenience
@property (nonatomic, readonly, strong) NSString *formattedPrice;
@property (nonatomic, readonly, strong) NSString *genderText;
@property (nonatomic, readonly) BOOL hasImages;
@property (nonatomic, readonly) BOOL requiresUpload;

/// Geo validation
- (BOOL)hasValidGeoLocation;

/// Firestore mapping
- (instancetype)initWithDictionary:(NSDictionary *)dict documentID:(NSString *)docID;
- (NSDictionary *)toFirestoreDictionary;
+ (instancetype)adFromFirestoreData:(NSDictionary *)data documentID:(NSString *)docID;
+ (void)sharePetAd:(PetAd *)petAd fromViewController:(UIViewController *)vc;
+ (void)sharePetAd:(PetAd *)petAd
fromViewController:(UIViewController *)vc
        sourceView:(nullable UIView *)sourceView;
+ (NSString *)shareMessageForPetAd:(PetAd *)petAd;
- (void)shareFromViewController:(UIViewController *)vc sourceView:(nullable UIView *)sourceView ;
+ (nullable NSURL *)shareableLinkForPetAd:(PetAd *)petAd;
+ (void)exportPetAdAsTextFile:(PetAd *)petAd
           fromViewController:(UIViewController *)vc;
- (void)copyToClipboard;
+ (void)copyPetAdToClipboard:(PetAd *)petAd;
@end

NS_ASSUME_NONNULL_END
 
