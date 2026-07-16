//
//  ChMessagingController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 19/01/2026.
//
#import "ChMessagingController.h"
#import "PPChatHeaderView.h"
#import "TypingIndicatorView.h"
#import "ChatAudioMessageCell.h"
#import "ChatImageMessageCell.h"
#import "ChatVideoMessageCell.h"
#import "ChatStickerMessageCell.h"
#import "PPChatsFunc.h"
#import "ChMessagingController+Record.h"

@interface ChMessagingController (CHHelper)
//- (void)markMessagesAsReadForThreadID:(NSString *)threadID currentUserID:(NSString *)myID;

 
 @property(nonatomic, assign) FIRAuthStateDidChangeListenerHandle authListenerHandle;
- (void)setupTableView;
- (UIView *)pp_activeChatInputBarViewForLayout;

 
- (void)setupChatHeader;
 - (void)pp_animateHeaderStatusText:(NSString *)text;
@property (nonatomic, strong) id<FIRListenerRegistration> messageListener;
 

 
- (void)presentMediaPickerForType:(NSString *)uti;
 
@end
