//
//  ArchiveManager.h
//  Pure Pets
//

#import <Foundation/Foundation.h>
@import FirebaseFirestore;

@class ArchiveModel;
@class ArchiveDetailsModel;

NS_ASSUME_NONNULL_BEGIN

@interface ArchivesManager : NSObject

+ (instancetype)shared;

/// In-memory cache: archiveID -> details array
@property (nonatomic, strong, readonly) NSDictionary<NSString *, NSArray<ArchiveDetailsModel *> *> *archiveDetailsCache;


- (NSArray<ArchiveDetailsModel *> *)cachedArchiveDetailsForArchiveID:(NSString *)archiveID;

/**
 Return cached ArchiveModel by ID (safe, no fetch)
 */
- (ArchiveModel * _Nullable)archiveByID:(NSString *)archiveID;

/**
 Fetch all archives for a user (isDeleted == 0)
 */
- (void)fetchArchivesForUserID:(NSString *)userID
                    completion:(void(^)(NSArray<ArchiveModel *> *archives,
                                         NSError * _Nullable error))completion;

/**
 Fetch archive details (subcollection) for archiveID
 */
- (void)fetchArchiveDetailsForArchiveID:(NSString *)archiveID
                             completion:(void(^)(NSArray<ArchiveDetailsModel *> *details,
                                                  NSError * _Nullable error))completion;

/**
 Add card to archive (creates ArchiveDetailsCol/{detailID})
 */
- (void)addCardToArchiveID:(NSString *)archiveID
                    cardID:(NSString *)cardID
                    userID:(NSString *)userID
                    cageID:(nullable NSString *)cageID
                completion:(void(^)(NSError * _Nullable error))completion;
- (void)fetchArchiveDetailsForCardID:(NSString *)cardID
                          completion:(void(^)(NSArray<ArchiveDetailsModel *> *details,
                                               NSError * _Nullable error))completion;

- (void)removeArchiveDetailsByCardID:(NSString *)cardID
                          completion:(void(^)(NSError * _Nullable error))completion;


- (void)softDeleteArchiveByID:(NSString *)archiveID
                   completion:(void(^)(NSError * _Nullable error))completion;

- (void)restoreArchiveDetail:(ArchiveDetailsModel *)detail
                   cageID:(NSString *)cageID
                completion:(void(^)(NSError * _Nullable error))completion;
/**
 Move archive detail to another archive
 */
- (void)moveArchiveDetail:(ArchiveDetailsModel *)detail
            toArchiveID:(NSString *)newArchiveID
              completion:(void(^)(NSError * _Nullable error))completion;

/**
 Soft delete archive detail (isDeleted = 1)
 */
- (void)deleteArchiveDetail:(ArchiveDetailsModel *)detail
                 completion:(void(^)(NSError * _Nullable error))completion;

- (void)syncDetailsCountForArchiveID:(NSString *)archiveID;

- (void)updateCardLocationToArchive:(NSString *)cardID
                          archiveID:(NSString *)archiveID
                    masterArchiveID:(NSString *)masterArchiveID;
/**
 Restore archive detail (isDeleted = 0)
 */
- (void)restoreArchiveDetail:(ArchiveDetailsModel *)detail
                  completion:(void(^)(NSError * _Nullable error))completion;
- (void)archiveDetailByID:(NSString *)detailID completion:(void(^)(ArchiveDetailsModel * _Nullable detail))completion;
- (void)addCard:(NSString *)cardID
      child:(ChildModel * _Nullable)child
      toArchive:(NSString *)archiveID
       ownerID:(NSString *)ownerID
     completion:(void(^)(NSError * _Nullable error))completion;

- (ArchiveDetailsModel *)cachedArchiveDetailByID:(NSString *)detailID;
@end

NS_ASSUME_NONNULL_END
 
