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

/// Retrieve up to the `limit` most recent messages as an array of dictionaries: @{@"role":..., @"text":...}
- (NSArray<NSDictionary *> *)recentHistoryLimit:(NSUInteger)limit;

/// Returns the concatenated recent conversation text (useful if injecting as facts)
- (NSString *)recentContextSummary;

/// Extracts the last known pet type and need from the memory
- (nullable NSString *)lastKnownPetType;
- (nullable NSString *)lastKnownNeed;

/// Returns all stored messages (thread-safe snapshot)
- (NSArray<NSDictionary *> *)allMessages;

/// Clears all stored messages from memory and disk
- (void)clearAllMessages;

@end

NS_ASSUME_NONNULL_END
