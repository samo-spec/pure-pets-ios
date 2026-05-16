//
//  PPAgentClient.h
//  PurePets
//
//  Network client for the Nova chat agent. Sends user text to the
//  Cloud Run proxy with Firebase ID token + App Check token, parses
//  the response into a PPAgentMessage on the main queue.
//

#import <Foundation/Foundation.h>
#import "PPAgentMessage.h"

NS_ASSUME_NONNULL_BEGIN

// Proxy URL constant — replace the placeholder with the real Cloud Run URL.
// Accessible externally so the view controller can gate fallback behavior.
extern NSString * const kPPAgentProxyURL;

@interface PPAgentClient : NSObject

@property (class, nonatomic, readonly) PPAgentClient *shared;

/// Persistent session id for the current conversation.
/// Call -resetSession to start a new conversation.
@property (nonatomic, copy) NSString *sessionId;

- (void)resetSession;

- (nullable NSURLSessionDataTask *)sendMessage:(NSString *)message
                                    completion:(void (^)(PPAgentMessage * _Nullable reply,
                                                         NSError * _Nullable error))completion;

/// Same as sendMessage:completion: but propagates a 2-letter language code ("ar"/"en")
/// to the proxy so Nova replies in the same language as the user's message.
- (nullable NSURLSessionDataTask *)sendMessage:(NSString *)message
                                      language:(nullable NSString *)language
                                    completion:(void (^)(PPAgentMessage * _Nullable reply,
                                                         NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
