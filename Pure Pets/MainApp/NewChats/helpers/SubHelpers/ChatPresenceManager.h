//
//  ChatPresenceManager.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/01/2026.
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ChatPresenceManager : NSObject

+ (instancetype)shared;

- (void)startObservingUsers:(NSArray<NSString *> *)userIDs;
- (void)stopAll;

- (BOOL)isUserOnline:(NSString *)userID;
- (NSDate * _Nullable)lastSeenForUser:(NSString *)userID;

 

// 🔥 NEW: Multi-observer support
- (id)addPresenceObserver:(void (^)(NSString *userID))block;
- (void)removePresenceObserver:(id)token;

@end

NS_ASSUME_NONNULL_END
