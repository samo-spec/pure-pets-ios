//
//  PPAgentMessage.h
//  PurePets
//
//  Model for Nova chat messages (user + agent).
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PPAgentRole) {
    PPAgentRoleUser,
    PPAgentRoleAgent,
    PPAgentRoleSystem
};

@interface PPAgentMessage : NSObject

@property (nonatomic, assign) PPAgentRole role;
@property (nonatomic, copy)   NSString *text;
@property (nonatomic, copy, nullable) NSString *toolName;             // e.g. "lookupOrder"
@property (nonatomic, copy, nullable) NSArray<NSString *> *suggestions;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *responseData;
@property (nonatomic, strong) NSDate *createdAt;

+ (instancetype)userText:(NSString *)text;
+ (instancetype)agentText:(NSString *)text;
+ (instancetype)agentText:(NSString *)text tool:(nullable NSString *)tool;

@end

NS_ASSUME_NONNULL_END
