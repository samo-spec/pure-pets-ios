//
//  ChManager.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 28/07/2025.
//


// ChManager.h
// Pure Pets
//
// Created by Mohammed Ahmed on [Date].

#import <Foundation/Foundation.h>
#import "ChatThreadModel.h"
#import "ChMessagingController.h"
#import "PPChatFeedbackManager.h"
typedef void (^ChThreadFetchCompletion)(ChatThreadModel * _Nullable thread);

@class ChatMessageModel;
NS_ASSUME_NONNULL_BEGIN

@protocol ChManagerDelegate <NSObject>
/// Called whenever a chat’s peer goes online/offline
- (void)chat:(ChatThreadModel *_Nullable)chat didUpdateOnlineStatus:(BOOL)status;
 
@end

@interface ChManager : NSObject

- (void)sendMessage:(ChatMessageModel *)msg
           inThread:(NSString *)threadID
           senderID:(NSString *)senderID
         completion:(void (^)(NSError * _Nullable error))completion;


- (void)uploadVideoThumbnail:(UIImage *)image
                     message:(ChatMessageModel *)msg
                  completion:(void (^)(NSString *thumbURL))completion;

- (void)sendImageMessage:(UIImage *)image
                 message:(ChatMessageModel *)msg
                inThread:(NSString *)threadID
                progress:(void (^)(CGFloat progress))progress
              completion:(void (^)(NSError * _Nullable error))completion;


// Send a video message: uploads video, sets fileURL, and then sends message
- (void)sendVideoMessage:(NSURL *)videoURL
                 message:(ChatMessageModel *)msg
                inThread:(NSString *)threadID
              completion:(void (^)(NSError * _Nullable error))completion;;
- (nullable id<FIRListenerRegistration>)listenForOtherUserTypingInThread:(NSString *)threadID
                                      otherUser:(NSString *)otherUserID
                                                              completion:(void (^)(BOOL isTyping))completion;
@property (nonatomic, weak) id<ChManagerDelegate> delegate;
+ (instancetype)sharedManager;
- (void)uploadVideoThumbnail:(UIImage *)image
                   messageID:(NSString *)msgID
                  completion:(void (^)(NSString *thumbURL))completion;
@property (nonatomic, strong) NSString *AccessToken;
// Observe all chat threads for a user
 
// Stop listening
- (void)stopListening;

- (void)createOrGetChatThreadWithUser:(UserModel *)otherUser
                           completion:(void (^)(ChatThreadModel * _Nullable thread, NSError * _Nullable error))completion;
- (void)startListeningForOtherUserTypingInThread:(NSString *)threadID
                                      otherUser:(NSString *)otherUserID
                                      completion:(void (^)(BOOL isTyping))completion;
- (void)stopListeningForOtherUserTypingInThread:(NSString *)threadID
                                      otherUser:(NSString *)otherUserID;
+ (CGFloat)heightForMessage:(NSString *)text onController:(ChMessagingController *)cont;

- (void)setTyping:(BOOL)isTyping
         inThread:(NSString *)threadID
           byUser:(NSString *)userID;


+ (NSString *)formattedLastSeen:(NSDate *)date;

@property (nonatomic, strong) AVAudioPlayer *globalPlayer;
@property (nonatomic, strong) NSArray<ChatThreadModel *> *chatsArray;

/// Set the user’s online flag (YES/NO) and update lastSeen to server timestamp
- (void)setOnline:(BOOL)isOnline
        forUserID:(NSString *)userID
       completion:(void(^)(NSError * _Nullable error))completion;

/// Update only lastSeen (to server timestamp) without touching online flag
- (void)updateLastSeenForUserID:(NSString *)userID
                     completion:(void(^)(NSError * _Nullable error))completion;
+ (void)chatWith:(UserModel *)user FromController:(UIViewController *)controller;
- (void)checkChatAvailabilityForUser:(NSString *)toUserID
                          completion:(void (^)(BOOL available, NSString * _Nullable reason))completion;
- (void)checkUserAvailabilityForUser:(NSString *)toUserID
                          completion:(void (^)(BOOL available, NSString * _Nullable reason))completion;
- (void)openSupportChatFromController:(UIViewController *)controller;
- (void)sendChatPushToUserID:(NSString *)toUserID
                       title:(NSString *)title
                        body:(NSString *)body
                    threadID:(NSString *)threadID
                    senderID:(NSString *)senderID;

// In ChManager.h or .m
 - (void)startListeningForThreadMessages:(NSArray<ChatThreadModel *> *)threads;

- (void)stopAllThreadMessageListeners;

- (void)deleteChatThreadWithID:(NSString *)threadID
                    completion:(void (^)(NSError * _Nullable error))completion;

- (void)startChatWith:(UserModel *)user fromController:(UIViewController *)controller;
// Thread actions
- (void)muteThreadWithID:(NSString *)threadID
                 muted:(BOOL)muted
             completion:(void (^)(NSError * _Nullable error))completion;
- (void)binThreadWithID:(NSString *)threadID
                binned:(BOOL)binned
            completion:(void (^)(NSError * _Nullable error))completion;
- (void)reportThread:(ChatThreadModel *)thread
              reason:(nullable NSString *)reason
          completion:(void (^)(NSError * _Nullable error))completion;

+ (void)setOnline:(BOOL)online orText:(NSString *)TXT onLabel:(UILabel *)label;

- (_Nullable id<FIRListenerRegistration>)getListenerFromObserveChatThreadsForUserID:(NSString *)userID
                                completion:(void (^)(NSArray<ChatThreadModel *> *threads,
                                                     NSError *  error))completion;

+ (UIImage *)createCircleWithColor:(UIColor *)color size:(CGFloat)size ;
+ (void)fetchThreadWithID:(NSString *)threadID
               completion:(ChThreadFetchCompletion)completion;

@property (nonatomic, strong) NSDictionary<NSString *, NSNumber *> *unreadCounts;
#pragma mark - Message Status Flow Helpers
@property (nonatomic, assign) BOOL isHandlingNotificationHandoff;
@property (nonatomic, copy, nullable) NSString *activeThreadID;
/// Mark a message as DELIVERED when receiver snapshot is observed
- (void)markMessageAsDelivered:(NSString *)messageID
                       threadID:(NSString *)threadID;
+ (void)playIncomingMessageFeedback;
/// Mark all messages as READ in a thread (called when chat opens)
- (void)markMessagesAsReadInThread:(NSString *)threadID
                          fromUser:(NSString *)senderID;

- (void)startGlobalUnreadListenerForUser:(NSString *)userID;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> globalUnreadListener;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *liveUnreadCounts;
@property (nonatomic, strong, nullable) NSMutableDictionary<NSString *, ChatMessageModel *> *latestUnreadMessages;

+ (UIImage *)normalizedImage:(UIImage *)image;
- (_Nullable id<FIRListenerRegistration>)
observeChatThreadsWithUnreadCountsForUserID:(NSString *)userID
                                 completion:(void (^)(NSArray<ChatThreadModel *> *threads,
                                                      NSError * _Nullable error))completion;
- (void)syncPendingDeliveriesForUser:(nullable NSString *)userID
                          completion:(nullable void (^)(void))completion;
- (void)startGlobalIncomingMessageListenerForUser:(NSString *)userID;
- (NSSet<NSString *> *)mutedThreadIDs;
//- (void)startGlobalDeliveryListenerForUser:(NSString *)userID;
@end

NS_ASSUME_NONNULL_END

 
