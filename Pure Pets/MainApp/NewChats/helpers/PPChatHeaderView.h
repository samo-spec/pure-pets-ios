//
//  PPChatHeaderView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 17/01/2026.
//


@interface PPChatHeaderView : UIView

- (void)configureWithUser:(UserModel *)user;
- (void)updateStatusText:(NSString *)status;
- (void)startTypingAnimation;
- (void)stopTypingAnimation;
@end


