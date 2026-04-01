//
//  ChTypingController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 21/01/2026.
//


 
// ChTypingController.h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^ChTypingChangedBlock)(BOOL isTyping);

@interface ChTypingController : NSObject

/// Called on MAIN THREAD when the OTHER user typing state changes
@property (nonatomic, copy) ChTypingChangedBlock onTypingChanged;

/// Designated initializer (1:1 chat)
- (instancetype)initWithThreadID:(NSString *)threadID
                       myUserID:(NSString *)myUserID
                    otherUserID:(NSString *)otherUserID;

/// Call from textViewDidChange
- (void)userDidType;
- (void)attachThreadID:(NSString *)threadID;
/// Lifecycle
- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
