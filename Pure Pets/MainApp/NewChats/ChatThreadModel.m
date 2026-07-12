//
//  ChatThreadModel.m
//  Pure Pets
//

#import "ChatThreadModel.h"
#import <FirebaseFirestore/FirebaseFirestore.h>
#import <FirebaseAuth/FirebaseAuth.h>
#import "UserManager.h"
#import "UserModel.h"

static NSString *PPCurrentChatIdentity(void) {
    NSString *authUID = [FIRAuth auth].currentUser.uid ?: @"";
    if (authUID.length > 0) {
        return authUID;
    }
    return UserManager.sharedManager.currentUser.ID ?: @"";
}

static NSString * const PPSupportAvatarToken = @"purepets://support-logo";
static NSString * const PPPurePetsOfficialSupportUserID = @"PUIDPOFFICILAL20262214";
static NSString * const PPChatUnsentPreviewToken = @"__pp_message_unsent__";

static NSString *PPChatTrimmedString(id value) {
    if (![value isKindOfClass:NSString.class]) {
        return @"";
    }
    return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static BOOL PPChatBoolValue(id value) {
    if ([value isKindOfClass:NSNumber.class]) {
        return [(NSNumber *)value boolValue];
    }
    if ([value isKindOfClass:NSString.class]) {
        NSString *lower = [PPChatTrimmedString(value) lowercaseString];
        return [lower isEqualToString:@"true"] || [lower isEqualToString:@"1"];
    }
    return NO;
}

static NSString *PPThreadOtherUserID(ChatThreadModel *thread) {
    if ([ChatThreadModel isSupportThread:thread]) {
        return PPPurePetsOfficialSupportUserID;
    }

    NSString *myUID = PPCurrentChatIdentity();
    for (NSString *userID in thread.memberIDs) {
        if (userID.length > 0 && ![userID isEqualToString:myUID]) {
            return userID;
        }
    }
    return @"";
}

static UserModel *PPResolvedBaseOtherUser(ChatThreadModel *thread) {
    NSString *otherUserID = PPThreadOtherUserID(thread);
    if (otherUserID.length == 0) {
        return nil;
    }

    UserModel *cached = [UserManager userModelForID:otherUserID];
    if (cached.ID.length > 0) {
        return cached;
    }
    return [UserManager userModelFromUsersArrayForID:otherUserID];
}

static UserModel *PPBrandedSupportUser(ChatThreadModel *thread, UserModel *baseUser) {
    UserModel *displayUser = [UserModel new];
    displayUser.ID = PPPurePetsOfficialSupportUserID;
    displayUser.UserName = kLang(@"Support") ?: @"Support";
    displayUser.UserImageUrl = [NSURL URLWithString:PPSupportAvatarToken];
    displayUser.isOnline = baseUser.isOnline;
    displayUser.lastSeen = baseUser.lastSeen;
    return displayUser;
}

@implementation ChatThreadModel

#pragma mark - Init

- (instancetype)initWithDictionary:(NSDictionary *)dict
{
    self = [super init];
    if (!self) return nil;

    // Firestore-backed fields
    _memberIDs =
        [dict[@"members"] isKindOfClass:NSArray.class]
        ? dict[@"members"]
        : @[];

    _lastMessage =
        [dict[@"lastMessage"] isKindOfClass:NSString.class]
        ? dict[@"lastMessage"]
        : @"";
    if ([_lastMessage isEqualToString:PPChatUnsentPreviewToken]) {
        _lastMessage = kLang(@"chat_message_unsent");
    }

    _lastSenderID =
        [dict[@"senderID"] isKindOfClass:NSString.class]
        ? dict[@"senderID"]
        : @"";

    id ts = dict[@"timestamp"];
    if ([ts isKindOfClass:FIRTimestamp.class]) {
        _timestamp = [(FIRTimestamp *)ts dateValue];
    } else if ([ts isKindOfClass:NSDate.class]) {
        _timestamp = ts;
    } else {
        _timestamp = [NSDate distantPast];
    }
    
    _lastReadBy =
        [dict[@"lastReadBy"] isKindOfClass:NSString.class]
        ? dict[@"lastReadBy"]
        : @"";
    
    id lastRead = dict[@"lastReadAt"];
    if ([lastRead isKindOfClass:FIRTimestamp.class]) {
        _lastReadAt = [(FIRTimestamp *)lastRead dateValue];
    } else if ([lastRead isKindOfClass:NSDate.class]) {
        _lastReadAt = lastRead;
    } else {
        _lastReadAt = [NSDate date];
    }
    
    id lastAt = dict[@"lastMessageAt"];
    if ([lastAt isKindOfClass:FIRTimestamp.class]) {
        _lastMessageAt = [(FIRTimestamp *)lastAt dateValue];
    } else if ([lastAt isKindOfClass:NSDate.class]) {
        _lastMessageAt = lastAt;
    } else {
        _lastMessageAt = _timestamp ?: [NSDate distantPast];
    }
    
    

    id count = dict[@"messagesCount"];
    _messagesCount =
        [count respondsToSelector:@selector(integerValue)]
        ? [count integerValue]
        : 0;

    _mutedBy =
        [dict[@"mutedBy"] isKindOfClass:NSArray.class]
        ? dict[@"mutedBy"]
        : @[];

    _binnedBy =
        [dict[@"binnedBy"] isKindOfClass:NSArray.class]
        ? dict[@"binnedBy"]
        : @[];

    _reportedBy =
        [dict[@"reportedBy"] isKindOfClass:NSArray.class]
        ? dict[@"reportedBy"]
        : @[];
    _conversationType = PPChatTrimmedString(dict[@"conversationType"]);
    _threadType = PPChatTrimmedString(dict[@"threadType"]);
    _supportThread = PPChatBoolValue(dict[@"supportThread"]);
    _supportUserID = PPChatTrimmedString(dict[@"supportUserId"]);
    _customerId = PPChatTrimmedString(dict[@"customerId"]);
    _supportDisplayName = PPChatTrimmedString(dict[@"supportDisplayName"]);
    _supportPhotoURLString = PPChatTrimmedString(dict[@"supportPhotoUrl"]);

    // Derived fields
    _unreadCount = 0;

    NSString *myUID = PPCurrentChatIdentity();
    _isMuted = [_mutedBy containsObject:myUID];
    _isBinned = [_binnedBy containsObject:myUID];
    _isReportedByMe = [_reportedBy containsObject:myUID];

    for (NSString *uid in _memberIDs) {
        if (![uid isEqualToString:myUID]) {
            UserModel *cachedUser = [UserManager userModelForID:uid];
            _otherUser = [ChatThreadModel isSupportThread:self]
                ? PPBrandedSupportUser(self, cachedUser)
                : cachedUser;
            break;
        }
    }

    return self;
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.ID forKey:@"ID"];
    [coder encodeObject:self.memberIDs forKey:@"members"];
    [coder encodeObject:self.lastMessage forKey:@"lastMessage"];
    [coder encodeObject:self.lastSenderID forKey:@"senderID"];
    [coder encodeObject:self.timestamp forKey:@"timestamp"];
    [coder encodeInteger:self.messagesCount forKey:@"messagesCount"];
    [coder encodeInteger:self.unreadCount forKey:@"unreadCount"];
    [coder encodeObject:self.memberIDs forKey:@"members"];
    [coder encodeObject:self.lastMessageAt forKey:@"lastMessageAt"];
    [coder encodeObject:self.lastReadAt forKey:@"lastReadAt"];
    [coder encodeObject:self.lastReadBy forKey:@"lastReadBy"];
    [coder encodeObject:self.mutedBy forKey:@"mutedBy"];
    [coder encodeObject:self.binnedBy forKey:@"binnedBy"];
    [coder encodeObject:self.reportedBy forKey:@"reportedBy"];
    [coder encodeObject:self.conversationType forKey:@"conversationType"];
    [coder encodeObject:self.threadType forKey:@"threadType"];
    [coder encodeBool:self.supportThread forKey:@"supportThread"];
    [coder encodeObject:self.supportUserID forKey:@"supportUserId"];
    [coder encodeObject:self.customerId forKey:@"customerId"];
    [coder encodeObject:self.supportDisplayName forKey:@"supportDisplayName"];
    [coder encodeObject:self.supportPhotoURLString forKey:@"supportPhotoUrl"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (!self) return nil;

    self.ID = [coder decodeObjectOfClass:NSString.class forKey:@"ID"];
    self.memberIDs =
        [coder decodeObjectOfClass:NSArray.class forKey:@"members"] ?: @[];

    self.lastMessage =
        [coder decodeObjectOfClass:NSString.class forKey:@"lastMessage"] ?: @"";

    self.lastSenderID =
        [coder decodeObjectOfClass:NSString.class forKey:@"senderID"] ?: @"";
    
    self.lastReadBy =
        [coder decodeObjectOfClass:NSString.class forKey:@"lastReadBy"] ?: @"";
    
    self.lastReadAt =
        [coder decodeObjectOfClass:NSDate.class forKey:@"lastReadAt"] ?: [NSDate date];

    self.timestamp =
        [coder decodeObjectOfClass:NSDate.class forKey:@"timestamp"] ?: [NSDate date];

    self.messagesCount = [coder decodeIntegerForKey:@"messagesCount"];
    self.unreadCount = [coder decodeIntegerForKey:@"unreadCount"];
    self.mutedBy = [coder decodeObjectOfClass:NSArray.class forKey:@"mutedBy"] ?: @[];
    self.binnedBy = [coder decodeObjectOfClass:NSArray.class forKey:@"binnedBy"] ?: @[];
    self.reportedBy = [coder decodeObjectOfClass:NSArray.class forKey:@"reportedBy"] ?: @[];
    self.conversationType = [coder decodeObjectOfClass:NSString.class forKey:@"conversationType"] ?: @"";
    self.threadType = [coder decodeObjectOfClass:NSString.class forKey:@"threadType"] ?: @"";
    self.supportThread = [coder decodeBoolForKey:@"supportThread"];
    self.supportUserID = [coder decodeObjectOfClass:NSString.class forKey:@"supportUserId"] ?: @"";
    self.customerId = [coder decodeObjectOfClass:NSString.class forKey:@"customerId"] ?: @"";
    self.supportDisplayName = [coder decodeObjectOfClass:NSString.class forKey:@"supportDisplayName"] ?: @"";
    self.supportPhotoURLString = [coder decodeObjectOfClass:NSString.class forKey:@"supportPhotoUrl"] ?: @"";

    NSString *myUID = PPCurrentChatIdentity();
    self.isMuted = [self.mutedBy containsObject:myUID];
    self.isBinned = [self.binnedBy containsObject:myUID];
    self.isReportedByMe = [self.reportedBy containsObject:myUID];

    return self;
}

-(UserModel *)otherUser
{
    if (_otherUser.ID.length > 0) {
        return _otherUser;
    }

    UserModel *baseUser = PPResolvedBaseOtherUser(self);
    if ([ChatThreadModel isSupportThread:self]) {
        _otherUser = PPBrandedSupportUser(self, baseUser);
        if (_otherUser.ID.length > 0) {
            return _otherUser;
        }
    }
    return baseUser;
}

+ (BOOL)isSupportThread:(ChatThreadModel *)thread
{
    if (![thread isKindOfClass:ChatThreadModel.class]) {
        return NO;
    }
    BOOL hasOfficialSupportMember = [thread.memberIDs containsObject:PPPurePetsOfficialSupportUserID];
    NSString *supportUserID = thread.supportUserID ?: @"";
    BOOL hasOfficialSupportUser = [supportUserID isEqualToString:PPPurePetsOfficialSupportUserID];
    BOOL markedSupport = thread.supportThread ||
        [thread.conversationType.lowercaseString isEqualToString:@"support"] ||
        [thread.threadType.lowercaseString isEqualToString:@"support"];
    return hasOfficialSupportMember || (markedSupport && hasOfficialSupportUser);
}

+ (NSString *)purePetsOfficialSupportUserID
{
    return PPPurePetsOfficialSupportUserID;
}

+ (NSString *)canonicalSupportThreadIDForCustomerID:(NSString *)customerID
{
    NSString *customer = PPChatTrimmedString(customerID);
    if (customer.length == 0 ||
        [customer isEqualToString:PPPurePetsOfficialSupportUserID]) {
        return @"";
    }

    return ([customer compare:PPPurePetsOfficialSupportUserID] == NSOrderedAscending)
        ? [NSString stringWithFormat:@"%@_%@", customer, PPPurePetsOfficialSupportUserID]
        : [NSString stringWithFormat:@"%@_%@", PPPurePetsOfficialSupportUserID, customer];
}

+ (UserModel *)resolveOtherUserFromThread:(ChatThreadModel *)thread
{
    if (![thread isKindOfClass:ChatThreadModel.class]) {
        return nil;
    }
    if (thread.otherUser.ID.length > 0) {
        return thread.otherUser;
    }

    UserModel *baseUser = PPResolvedBaseOtherUser(thread);
    if ([ChatThreadModel isSupportThread:thread]) {
        UserModel *displayUser = PPBrandedSupportUser(thread, baseUser);
        if (displayUser.ID.length > 0) {
            thread.otherUser = displayUser;
            return displayUser;
        }
    }
    return baseUser;
}
@end


/*
 + (UserModel *)otherUserInThread:(ChatThreadModel *)thread {
     NSString *myUID = [UserManager sharedManager].currentUser.ID ?: @"";
     for (UserModel *user in thread.chMembers) {
         if (![user.ID isKindOfClass:NSString.class]) continue;
         if (![user.ID isEqualToString:myUID]) {
             return [UserManager userModelFromUsersArrayForID:user.ID];
         }
     }
     return nil;
 }


 + (void)otherUserInThread:(ChatThreadModel *)thread completion:(void (^)(UserModel * _Nullable user, NSError * _Nullable error))completion {
     NSString *myUID = [UserManager sharedManager].currentUser.ID ?: @"";
     for (UserModel *user in thread.chMembers) {
         if (![user.ID isEqualToString:myUID]) {
             [UsrMgr getOtherUserModelFromFirestoreWithUID:user.ID completion:completion];
         }
     }
    
 }

 - (NSString *)chatWithName {
     
     UserModel *u = [ChatThreadModel otherUserInThread:self];
     NSLog(@"chat other user chatWithName %@",u.modelToJSONString);
     return u.UserName.length ? u.UserName : u.UserName ?: u.UserEmail ?: @"";
 }

 - (NSString *)chatWithImage {
     UserModel *u = [ChatThreadModel otherUserInThread:self];
     NSLog(@"chat other user chatWithImage %@",u.modelToJSONString);
     return u.UserImageUrl.absoluteString ?: @"";
 }
 */
