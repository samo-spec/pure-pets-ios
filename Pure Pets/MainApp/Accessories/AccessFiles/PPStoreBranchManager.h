//
//  PPStoreBranchManager.h
//  Pure Pets
//
//  Single source of truth for the active consumer store branch in Pure Pets iOS.
//  Observes AppConfigCol/ConsumerStockConfig which is configured from the Admin app Branches screen.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const PPStoreBranchDidChangeNotification;

@interface PPStoreBranchManager : NSObject

@property (nonatomic, copy, readonly) NSString *currentBranchId;
@property (nonatomic, copy, readonly) NSString *currentBranchNameAr;
@property (nonatomic, copy, readonly) NSString *currentBranchNameEn;
@property (nonatomic, copy, readonly) NSString *currentBranchCode;
@property (nonatomic, assign, readonly) BOOL isConfigLoaded;

+ (instancetype)sharedManager;

- (void)startObservingStoreBranch;
- (void)stopObserving;
- (NSString *)localizedCurrentBranchName;

@end

NS_ASSUME_NONNULL_END
