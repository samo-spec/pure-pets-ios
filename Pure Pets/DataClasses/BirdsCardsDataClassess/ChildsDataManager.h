//
//  ChildsDataManager.h
//  Pure Pets
//
//  Refactored: ChildsCol subcollection only
//

@import FirebaseFirestore;

@class ChildModel;

NS_ASSUME_NONNULL_BEGIN

@interface ChildsDataManager : NSObject

#pragma mark - Fetch

/// Fetch all non-deleted children for a cage
+ (void)fetchChildrenForCageID:(NSString *)cageID
                    completion:(void(^)(NSArray<ChildModel *> *children,
                                         NSError * _Nullable error))completion;

#pragma mark - Create

/// Add a new child document to ChildsCol under a cage
+ (void)addChild:(ChildModel *)child
       toCageID:(NSString *)cageID
      completion:(void(^)(NSError * _Nullable error))completion;

#pragma mark - Soft Delete / Restore

/// Mark child as deleted or restored (isDeleted = 1 / 0)
+ (void)setChildDeleted:(BOOL)deleted
             forChildID:(NSString *)childID
                cageID:(NSString *)cageID
             completion:(void(^)(NSError * _Nullable error))completion;

#pragma mark - Update by CardID

/// Update a child by CardID (one child per card rule)
+ (void)updateChildWithCardID:(NSString *)cardID
                      cageID:(NSString *)cageID
                        data:(NSDictionary *)data
                   completion:(void(^)(NSError * _Nullable error))completion;

#pragma mark - Convenience APIs

/// Mark child as sold using CardID
+ (void)markChildSoldByCardID:(NSString *)cardID
                      cageID:(NSString *)cageID
                   completion:(void(^)(NSError * _Nullable error))completion;

/// Update child transfer box info (Home / Away / Guest)
+ (void)updateChildBox:(ChildBox)childBox
            childBoxID:(nullable NSString *)childBoxID
              childID:(NSString *)childID
               cageID:(NSString *)cageID
           completion:(void(^)(NSError * _Nullable error))completion;

#pragma mark - Sync

/// Recalculate childsCount for a cage from ChildsCol (repair / fallback)
+ (void)syncDetailsCountForCageID:(NSString *)cageID
                       completion:(void(^)(NSError * _Nullable error))completion;

+ (NSInteger)indexOfChild:(ChildModel *)child inArray:(NSMutableArray<ChildModel *> *)childsArr;
@end

NS_ASSUME_NONNULL_END
