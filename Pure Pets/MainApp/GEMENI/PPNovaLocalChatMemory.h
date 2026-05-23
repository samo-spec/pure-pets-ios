//
//  PPNovaLocalChatMemory.h
//  Pure Pets
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPNovaLocalChatMemory : NSObject

+ (instancetype)sharedMemory;

@property (nonatomic, assign) BOOL isMemoryEnabled;

/// Loads messages from disk, removing any older than 30 days.
- (void)cleanupAndLoad;

/// Check if we have previous history (to skip greetings)
- (BOOL)hasPreviousHistory;

/// Append a message to local memory (persisted immediately)
- (void)addMessageWithRole:(NSString *)role text:(NSString *)text;

/// Append a message with a stable local id so UI-only metadata like stars can be restored.
- (void)addMessageWithRole:(NSString *)role
                      text:(NSString *)text
                 messageId:(nullable NSString *)messageId
                 sessionId:(nullable NSString *)sessionId;

/// Retrieve up to the `limit` most recent messages as an array of dictionaries: @{@"role":..., @"text":...}
- (NSArray<NSDictionary *> *)recentHistoryLimit:(NSUInteger)limit;

/// Returns the concatenated recent conversation text (useful if injecting as facts)
- (NSString *)recentContextSummary;

/// Extracts the last known pet type and need from the memory
- (nullable NSString *)lastKnownPetType;
- (nullable NSString *)lastKnownNeed;

/// Returns all stored messages (thread-safe snapshot)
- (NSArray<NSDictionary *> *)allMessages;

/// Returns only messages marked as starred.
- (NSArray<NSDictionary *> *)starredMessages;

/// Update and query the local starred state for a saved Nova message.
- (void)setMessageStarred:(BOOL)starred messageId:(NSString *)messageId;
- (BOOL)isMessageStarred:(NSString *)messageId;

/// Clears all stored messages from memory and disk
- (void)clearAllMessages;

/// Stable session ID so the backend Agent Runtime sees consistent conversation context.
/// Returns nil if no session has ever been stored.
- (nullable NSString *)lastKnownSessionId;

/// Persist the session ID for reuse across VC lifecycles.
- (void)setLastKnownSessionId:(NSString *)sessionId;

@end

NS_ASSUME_NONNULL_END
