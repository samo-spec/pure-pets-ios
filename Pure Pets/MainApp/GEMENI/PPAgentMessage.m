//
//  PPAgentMessage.m
//  PurePets
//

#import "PPAgentMessage.h"

@implementation PPAgentMessage

+ (instancetype)userText:(NSString *)text {
    PPAgentMessage *m = [PPAgentMessage new];
    m.role      = PPAgentRoleUser;
    m.text      = text ?: @"";
    m.createdAt = [NSDate date];
    return m;
}

+ (instancetype)agentText:(NSString *)text {
    return [self agentText:text tool:nil];
}

+ (instancetype)agentText:(NSString *)text tool:(NSString *)tool {
    PPAgentMessage *m = [PPAgentMessage new];
    m.role      = PPAgentRoleAgent;
    m.text      = text ?: @"";
    m.toolName  = tool;
    m.createdAt = [NSDate date];
    return m;
}

@end
