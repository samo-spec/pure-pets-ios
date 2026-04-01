//
//  ChTypingController 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 21/01/2026.
//

// ChTypingController.m

#import "ChTypingController.h"
#import <FirebaseFirestore/FirebaseFirestore.h>

static NSTimeInterval const kTypingDebounceInterval = 1.5;

@interface ChTypingController ()
@property (nonatomic, copy) NSString *threadID;
@property (nonatomic, copy) NSString *myUserID;
@property (nonatomic, copy) NSString *otherUserID;

@property (nonatomic, strong) FIRFirestore *db;
@property (nonatomic, strong) id<FIRListenerRegistration> listener;

@property (nonatomic, strong) NSTimer *debounceTimer;
@property (nonatomic, assign) BOOL otherUserTyping;
@end

@implementation ChTypingController

#pragma mark - Init

- (instancetype)initWithThreadID:(NSString *)threadID
                       myUserID:(NSString *)myUserID
                    otherUserID:(NSString *)otherUserID
{
    
    NSLog(@"⌨️ [Typing INIT] thread=%@ my=%@ other=%@",
          threadID, myUserID, otherUserID);
    
    NSLog(@"⌨️ [TypingInit] START");
    NSLog(@"⌨️ [TypingInit] threadID=%@", threadID);
    NSLog(@"⌨️ [TypingInit] myUserID=%@", myUserID);
    NSLog(@"⌨️ [TypingInit] otherUserID=%@", otherUserID);

    // Keep asserts for programmer errors
    NSParameterAssert(myUserID);
    NSParameterAssert(otherUserID);

    self = [super init];
    if (!self) {
        NSLog(@"❌ [TypingInit] super init failed");
        return nil;
    }

    _threadID = [threadID copy];
    _myUserID = [myUserID copy];
    _otherUserID = [otherUserID copy];
    _db = [FIRFirestore firestore];
    _otherUserTyping = NO;

    NSLog(@"✅ [TypingInit] SUCCESS threadID=%@", _threadID);
    return self;
}

#pragma mark - Public

- (void)start {
    if (self.threadID.length == 0) {
        NSLog(@"⌨️ [Typing] Start skipped — no threadID");
        return;
    }
    if (self.listener) {
        NSLog(@"⌨️ [Typing] Listener already active");
        return;
    }
    [self startListening];
}

- (void)stop {
    NSLog(@"⌨️ [Typing] Stop called");

    [self.listener remove];
    self.listener = nil;

    [self.debounceTimer invalidate];
    self.debounceTimer = nil;

    // Ensure typing is cleared on exit
    [self writeTyping:NO];
}

#pragma mark - Typing Input (ME)

- (void)userDidType {

    if (self.threadID.length == 0) {
        NSLog(@"⌨️ [Typing] userDidType ignored — no threadID");
        return;
    }

    [self.debounceTimer invalidate];

    // Write TRUE only if not already typing (reduces Firestore writes)
    [self writeTyping:YES];

    __weak typeof(self) weakSelf = self;
    self.debounceTimer =
    [NSTimer scheduledTimerWithTimeInterval:kTypingDebounceInterval
                                     repeats:NO
                                       block:^(NSTimer * _Nonnull timer) {
        [weakSelf writeTyping:NO];
    }];
}

#pragma mark - Firestore Write

- (void)writeTyping:(BOOL)isTyping {

    if (self.threadID.length == 0) return;

    FIRDocumentReference *ref =
    [[self.db collectionWithPath:@"Chats"]
     documentWithPath:self.threadID];

    NSString *field =
    [NSString stringWithFormat:@"typing.%@", self.myUserID];

    NSLog(@"⌨️ [TypingWrite] %@ = %@", field, isTyping ? @"YES" : @"NO");

    [ref updateData:@{
        field : @(isTyping)
    }];
}

#pragma mark - Firestore Listen (OTHER USER)

- (void)startListening {

    if (self.listener || self.threadID.length == 0) return;

    FIRDocumentReference *ref =
    [[self.db collectionWithPath:@"Chats"]
     documentWithPath:self.threadID];

    __weak typeof(self) weakSelf = self;
    self.listener =
    [ref addSnapshotListener:^(FIRDocumentSnapshot *snapshot,
                               NSError *error) {

        if (error) {
            NSLog(@"❌ [TypingListen] Error: %@", error.localizedDescription);
            return;
        }
        if (!snapshot.exists) return;

        NSDictionary *typing = snapshot.data[@"typing"];
        if (![typing isKindOfClass:NSDictionary.class]) {
            [weakSelf updateOtherUserTyping:NO];
            return;
        }

        BOOL isTyping =
            [typing[weakSelf.otherUserID] boolValue];

        NSLog(@"⌨️ [TypingListen] otherUser %@ typing=%@", weakSelf.otherUserID, isTyping ? @"YES" : @"NO");

        [weakSelf updateOtherUserTyping:isTyping];
    }];
}

#pragma mark - State Update

- (void)updateOtherUserTyping:(BOOL)isTyping {

    if (self.otherUserTyping == isTyping) return;
    self.otherUserTyping = isTyping;

    if (self.onTypingChanged) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.onTypingChanged(isTyping);
        });
    }
}

- (void)attachThreadID:(NSString *)threadID {

    if (threadID.length == 0) return;
    if ([self.threadID isEqualToString:threadID]) return;

    NSLog(@"⌨️ [Typing] Attaching threadID=%@", threadID);

    self.threadID = threadID;

    [self stop];   // reset old state safely
    [self start];  // attach listener for new thread
}

@end
