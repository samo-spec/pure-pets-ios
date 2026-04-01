//
//  AppDataListenerManager.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 11/12/2025.
//



//
//  AppDataListenerManager.h
//  Pure Pets
//

#import <Foundation/Foundation.h>

#import "CagesManager.h"
#import "TrashModel.h"

#define AppData AppDataListenerManager.shared
NS_ASSUME_NONNULL_BEGIN

@interface AppDataListenerManager : NSObject

+ (instancetype)shared;
- (void)startListenersForUser:(NSString *)userID;
- (void)stopAllListeners;

// AppManager.h
@property (nonatomic, strong) NSMutableArray<CardModel *> *AllCardsDocs;      // ordered array
@property (nonatomic, strong) NSMutableArray<CardModel *> *UserCardsDocs;     // ordered array (filtered)
@property (nonatomic, strong) NSMutableDictionary<NSString *, CardModel *> *AllCardsByID; // id => model

@property (nonatomic, strong) NSMutableArray<CageModel *> *caGeDocs;
@property (nonatomic, strong) NSMutableArray<CageModel *> *UserCaGeDocs;

@property (nonatomic, strong) NSMutableArray<ArchiveModel *> *AllArchivesDocs;
@property (nonatomic, strong) NSMutableArray<ArchiveModel *> *UserArchivesDocs;

@property (nonatomic, strong) NSMutableArray<TrashModel *> *trashDocs;
@property (nonatomic, strong) NSMutableArray<TrashModel *> *UserTrashDocs;

@property (nonatomic, strong) NSMutableArray<BuyerModel *> *BuyerArray;

@end

NS_ASSUME_NONNULL_END



#import <Foundation/Foundation.h>
@class FIRQuerySnapshot;

NS_ASSUME_NONNULL_BEGIN

@interface PPDeepLog : NSObject

+ (void)logSnapshot:(FIRQuerySnapshot *)snapshot
   collectionName:(NSString *)collection;


@end

NS_ASSUME_NONNULL_END
