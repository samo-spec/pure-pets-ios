//
//  PPBirdCardView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 20/12/2025.
//


#import <UIKit/UIKit.h>
@class CardModel;

 
#ifdef DEBUG

#define LOG_EMOJI_INFO(fmt, ...)   NSLog((@"ℹ️ " fmt), ##__VA_ARGS__)
#define LOG_EMOJI_DEBUG(fmt, ...)  NSLog((@"🐞 " fmt), ##__VA_ARGS__)
#define LOG_EMOJI_WARN(fmt, ...)   NSLog((@"⚠️ " fmt), ##__VA_ARGS__)
#define LOG_EMOJI_ERROR(fmt, ...)  NSLog((@"❌ " fmt), ##__VA_ARGS__)
#define LOG_EMOJI_ACTION(fmt, ...) NSLog((@"👉 " fmt), ##__VA_ARGS__)

#else

#define LOG_EMOJI_INFO(...)
#define LOG_EMOJI_DEBUG(...)
#define LOG_EMOJI_WARN(...)
#define LOG_EMOJI_ERROR(...)
#define LOG_EMOJI_ACTION(...)

#endif

typedef NS_ENUM(NSInteger, ParentIs)
{
    ParentIsFather = 1,
    ParentIsMother = 2
};

typedef NS_ENUM(NSInteger, PPBirdCardStatus) {
    PPBirdCardStatusNormal = 0,
    PPBirdCardStatusSold,
    PPBirdCardStatusDeleted,
    PPBirdCardStatusArchived
};

NS_ASSUME_NONNULL_BEGIN

@interface PPBirdCardView : UIView
@property (nonatomic, assign) PPBirdCardStatus status;

- (void)setStatus:(PPBirdCardStatus)status
       archiveName:(nullable NSString *)archiveName;
@property (nonatomic, assign, readonly) ParentIs parentType;

/// Designated initializer
- (instancetype)initWithParentIs:(ParentIs)parent;

/// Configure content
- (void)configureWithCard:(nullable CardModel *)card
                   ringID:(nullable NSString *)ringID
                 isFather:(BOOL)isFather;

/// Status overlays
- (void)showSoldState;
- (void)showDeletedState;
- (void)showArchivedStateWithName:(NSString *)archiveName;
- (void)clearStatusState;

/// Menu button
@property (nonatomic, strong, readonly) UIButton *menuButton;

@end

NS_ASSUME_NONNULL_END
