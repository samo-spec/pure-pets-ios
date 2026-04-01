//
//  ChatPresenceManager 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/01/2026.
//


#import "ChatPresenceManager.h"
@import FirebaseFirestore;

@interface ChatPresenceManager ()
// existing properties…
@property (nonatomic, strong) NSMutableDictionary<NSString*, id> *listeners;
@property (nonatomic, strong) NSMutableDictionary<NSString*, NSNumber*> *onlineMap;
@property (nonatomic, strong) NSMutableDictionary<NSString*, NSDate*> *lastSeenMap;

@property (nonatomic, strong) NSMutableDictionary<NSUUID *, void (^)(NSString *)> *observers;
@property (nonatomic, strong) dispatch_queue_t isolationQueue;

// 🔥 ADD THIS
- (void)notifyObserversForUser:(NSString *)userID;
@end

@implementation ChatPresenceManager

- (instancetype)init
{
    self = [super init];
    if (!self) return nil;

    _onlineMap = [NSMutableDictionary dictionary];
    _lastSeenMap = [NSMutableDictionary dictionary];
    _listeners = [NSMutableDictionary dictionary];

    _observers = [NSMutableDictionary dictionary];
    _isolationQueue = dispatch_queue_create("com.purepets.chatpresence.observers",
                                            DISPATCH_QUEUE_SERIAL);

    return self;
}


+ (instancetype)shared {
    static ChatPresenceManager *m;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        m = [ChatPresenceManager new];
        m.listeners = [NSMutableDictionary dictionary];
        m.onlineMap = [NSMutableDictionary dictionary];
        m.lastSeenMap = [NSMutableDictionary dictionary];
    });
    return m;
}

- (void)notifyObserversForUser:(NSString *)userID
{
    if (!userID.length) return;

    dispatch_async(self.isolationQueue, ^{
        NSArray *blocks = self.observers.allValues;

        dispatch_async(dispatch_get_main_queue(), ^{
            for (void (^block)(NSString *) in blocks) {
                block(userID);
            }
        });
    });
}

- (id)addPresenceObserver:(void (^)(NSString *userID))block
{
    if (!block) return nil;

    NSUUID *token = [NSUUID UUID];

    dispatch_async(self.isolationQueue, ^{
        self.observers[token] = [block copy];
    });

    return token;
}

- (void)startObservingUsers:(NSArray<NSString *> *)userIDs {

    FIRFirestore *db = FIRFirestore.firestore;

    for (NSString *uid in userIDs) {

        if (self.listeners[uid]) continue; // already observing

        id<FIRListenerRegistration> listener =
        [[[db collectionWithPath:@"UserPresence"] documentWithPath:uid]
         addSnapshotListener:^(FIRDocumentSnapshot *snapshot, NSError *error) {

            if (!snapshot.exists || error) return;

            [self handlePresenceChangeForUser:uid snapshot:snapshot];
        }];

        self.listeners[uid] = listener;
    }
    
    for (NSString *uid in userIDs) {
        if (self.onlineMap[uid] != nil) {
            [self notifyObserversForUser:uid];
        }
    }
}

- (void)removePresenceObserver:(id)token
{
    if (![token isKindOfClass:[NSUUID class]]) return;

    dispatch_async(self.isolationQueue, ^{
        [self.observers removeObjectForKey:token];
    });
}


- (void)handlePresenceChangeForUser:(NSString *)userID
                           snapshot:(FIRDocumentSnapshot *)snapshot
{
    BOOL online = [snapshot[@"online"] boolValue];
    if (!online && [snapshot[@"isOnline"] respondsToSelector:@selector(boolValue)]) {
        online = [snapshot[@"isOnline"] boolValue];
    }
 
    id ts = snapshot[@"lastSeen"];

    NSDate *date = nil;

    if ([ts isKindOfClass:[FIRTimestamp class]]) {
        date = [(FIRTimestamp *)ts dateValue];
    } else if ([ts isKindOfClass:[NSDate class]]) {
        date = ts;
    }

    if (date) {
        self.lastSeenMap[userID] = date;
    } else {
        [self.lastSeenMap removeObjectForKey:userID];
    }
    
     
    
    self.onlineMap[userID] = @(online);
 
    // 🔔 Notify ALL observers safely
    dispatch_async(self.isolationQueue, ^{
        NSArray *blocks = self.observers.allValues;
        dispatch_async(dispatch_get_main_queue(), ^{
            for (void (^block)(NSString *) in blocks) {
                block(userID);
            }
        });
    });
}






- (BOOL)isUserOnline:(NSString *)userID {
    return [self.onlineMap[userID] boolValue];
}

- (NSDate *)lastSeenForUser:(NSString *)userID {
    return self.lastSeenMap[userID];
}

- (void)stopAll {
    for (id<FIRListenerRegistration> l in self.listeners.allValues) {
        [l remove];
    }
    [self.listeners removeAllObjects];
}

@end
