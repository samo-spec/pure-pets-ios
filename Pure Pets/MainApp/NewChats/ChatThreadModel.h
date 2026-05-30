//
//  ChatThreadModel.h
//  Pure Pets
//

#import <Foundation/Foundation.h>
@class UserModel;

NS_ASSUME_NONNULL_BEGIN

@interface ChatThreadModel : NSObject <NSSecureCoding>

#pragma mark - Identity

@property (nonatomic, copy) NSString *ID;

#pragma mark - Firestore-backed fields (SOURCE OF TRUTH)

@property (nonatomic, copy) NSArray<NSString *> *memberIDs;
@property (nonatomic, copy) NSString *lastMessage;
@property (nonatomic, copy) NSString *lastSenderID;
@property (nonatomic, strong) NSDate *timestamp;        // 🔒 ONE time field
@property (nonatomic, assign) NSInteger messagesCount;
@property (nonatomic, strong) NSDate *lastMessageAt;
@property (nonatomic, strong) NSNumber *chatBackgroundIndex;
@property (nonatomic, strong) NSString *lastReadBy;
@property (nonatomic, strong) NSDate *lastReadAt;
@property (nonatomic, assign) NSInteger isPinned;
@property (nonatomic, copy) NSArray<NSString *> *mutedBy;
@property (nonatomic, copy) NSArray<NSString *> *binnedBy;
@property (nonatomic, copy) NSArray<NSString *> *reportedBy;
@property (nonatomic, copy) NSString *conversationType;
@property (nonatomic, copy) NSString *threadType;
@property (nonatomic, assign) BOOL supportThread;
@property (nonatomic, copy) NSString *supportUserID;
@property (nonatomic, copy) NSString *supportDisplayName;
@property (nonatomic, copy) NSString *supportPhotoURLString;

#pragma mark - Derived / Runtime-only (NOT Firestore)

@property (nonatomic, assign) NSInteger unreadCount;
@property (nonatomic, strong, nullable) UserModel *otherUser;
@property (nonatomic, assign) BOOL isMuted;
@property (nonatomic, assign) BOOL isBinned;
@property (nonatomic, assign) BOOL isReportedByMe;

#pragma mark - Init

- (instancetype)initWithDictionary:(NSDictionary *)dict;
+ (BOOL)isSupportThread:(ChatThreadModel *)thread;
+ (NSString *)purePetsOfficialSupportUserID;
+ (NSString *)canonicalSupportThreadIDForCustomerID:(NSString *)customerID;
+ (UserModel *)resolveOtherUserFromThread:(ChatThreadModel *)thread;
@end

NS_ASSUME_NONNULL_END
