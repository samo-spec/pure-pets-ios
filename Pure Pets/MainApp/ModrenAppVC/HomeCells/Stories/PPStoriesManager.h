//
//  PPStoriesManager.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 2/22/26.
//

#import "PPStory.h"
#pragma mark - Stories Manager

NS_ASSUME_NONNULL_BEGIN

typedef void (^PPStoriesFetchCompletion)(NSArray<PPStory *> *stories,
                                         NSError * _Nullable error);
typedef void (^PPStoriesSeedCompletion)(NSInteger insertedCount,
                                        NSError * _Nullable error);
typedef void (^PPStoriesWriteCompletion)(NSError * _Nullable error);

@interface PPStoriesManager : NSObject
@property (nonatomic, strong) FIRFirestore *db;
+ (instancetype)shared;
- (void)fetchStoriesWithCompletion:(PPStoriesFetchCompletion)completion;
- (void)fetchStoriesForUserID:(NSString *)userID
                    completion:(PPStoriesFetchCompletion)completion;
- (nullable id<FIRListenerRegistration>)observeStoriesWithCompletion:(PPStoriesFetchCompletion)completion;
- (void)markStorySeenForUserID:(NSString *)userID
                     completion:(void (^ _Nullable)(NSError * _Nullable error))completion;
- (void)addImageStoryItemForCurrentUser:(UIImage *)image
                              completion:(PPStoriesWriteCompletion _Nullable)completion;
- (void)seedDemoStoriesOnceIfNeededWithCompletion:(PPStoriesSeedCompletion _Nullable)completion;
- (void)seedDemoStoriesForceWithCompletion:(PPStoriesSeedCompletion _Nullable)completion;
@end

NS_ASSUME_NONNULL_END
