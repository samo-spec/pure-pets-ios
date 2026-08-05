//
//  PPMessagingViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 19/01/2026.
//
#import "PPMessagingViewController.h"
#import "PPChatHeaderView.h"
#import "TypingIndicatorView.h"
#import "PPChatsFunc.h"

@import Firebase;
@import FirebaseFirestore;
@import FirebaseStorage;

@interface PPMessagingViewController (CHHelper)

 
 @property(nonatomic, assign) FIRAuthStateDidChangeListenerHandle authListenerHandle;
- (void)setupTableView;
- (UIView *)pp_activeChatInputBarViewForLayout;

 
- (void)setupChatHeader;
 - (void)pp_animateHeaderStatusText:(NSString *)text;
@property (nonatomic, strong) id<FIRListenerRegistration> messageListener;
 

 
- (void)presentMediaPickerForType:(NSString *)uti;
 
@end
