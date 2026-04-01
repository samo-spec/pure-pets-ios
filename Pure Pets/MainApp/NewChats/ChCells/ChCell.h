//
//  ChCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 22/01/2026.
//


#import <UIKit/UIKit.h>

@class ChatThreadModel;

NS_ASSUME_NONNULL_BEGIN

@interface ChCell : UITableViewCell

+ (NSString *)reuseID;
@property (nonatomic, copy, nullable) void (^onTap)(void);
/// Main configuration
- (void)configureWithThread:(ChatThreadModel *)thread;
@property (nonatomic, copy, nullable) NSString *representedUserID;
@property (nonatomic, copy, nullable) NSString *representedAvatarURL;
/// Optional state updates
- (void)setUnreadCount:(NSInteger)count;
- (void)setOnline:(BOOL)isOnline;
- (void)updatePresenceUI:(BOOL)isOnline;
- (void)applyPresenceOnline:(BOOL)online
                   lastSeen:(nullable NSDate *)lastSeen;
@end

NS_ASSUME_NONNULL_END
