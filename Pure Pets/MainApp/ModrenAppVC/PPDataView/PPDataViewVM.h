#import <Foundation/Foundation.h>

@class MainKindsModel;
@class PPUniversalCellViewModel;

NS_ASSUME_NONNULL_BEGIN
@interface PPDataViewVM : NSObject


@property (nonatomic, copy, nullable) void (^onReloadData)(void);
@property (nonatomic, copy, nullable) void (^onAppendData)(NSArray<NSIndexPath *> * _Nonnull indexPaths);
@property (nonatomic, copy, nullable) void (^onError)(NSError * _Nonnull error);
 

// State
@property (nonatomic, assign) PPDataSection currentSection;//readonly
@property (nonatomic, assign) NSInteger currentSubKindID;
@property (nonatomic, assign) PPDataSection pendingRestoreSection;
@property (nonatomic, assign) PPDeepLinkTarget currentDeepLinkTarget;
@property (nonatomic, assign, readonly) PPFilterAccessoryType accessoryFilter;
@property (nonatomic, assign, readonly) PPFilterServiceType serviceFilter;
// Data access
@property (nonatomic, strong, readonly) NSArray<PPUniversalCellViewModel *> *items;
@property (nonatomic, assign, readonly) NSInteger itemCount;
- (void)reloadForSubKind:(SubKindModel *)subKind;
// Init
- (instancetype)initWithMainKind:(MainKindsModel *)mainKind
                    sourceTarget:(PPDeepLinkTarget)sourceTarget;
- (void)switchToMainKind:(MainKindsModel *)mainKind;
// Actions
- (void)fetchInitialData;
- (void)fetchNextPage;
- (void)switchToSection:(PPDataSection)section;

// Filters
- (void)applyAccessoryFilter:(PPFilterAccessoryType)accessory
               serviceFilter:(PPFilterServiceType)service;
- (NSString *)subKindKeyForMainKind:(MainKindsModel *)mainKind;
// Cell access
- (PPUniversalCellViewModel *)viewModelAtIndex:(NSInteger)index;
- (void)reloadDataWithCompletion:(void (^)(NSError * _Nullable error))completion;
@end
NS_ASSUME_NONNULL_END
