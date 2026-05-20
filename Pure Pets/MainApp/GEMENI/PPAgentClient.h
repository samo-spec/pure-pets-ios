//
//  PPAgentClient.h
//  PurePets
//
//  Network client for the Nova ADK agent. Creates ADK sessions lazily,
//  persists the session mapping across relaunches, sends messages via
//  /run with Firebase ID token + App Check, and parses ADK event arrays
//  into PPAgentMessage on the main queue.
//

#import <Foundation/Foundation.h>
#import "PPAgentMessage.h"

NS_ASSUME_NONNULL_BEGIN

// ADK Cloud Run base URL.
extern NSString * const kPPAgentBaseURL;

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

- (nullable NSURLSessionDataTask *)sendMessage:(NSString *)message
                                      language:(nullable NSString *)language
                                       idToken:(NSString *)idToken
                                 appCheckToken:(nullable NSString *)appCheckToken
                                    completion:(void (^)(PPAgentMessage * _Nullable reply,
                                                         NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
