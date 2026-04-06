//
//  PPStoryCollectionViewCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 2/22/26.
//

#import "PPStory.h"
#pragma mark - Story Thumbnail Cell

NS_ASSUME_NONNULL_BEGIN

@interface PPStoryCollectionViewCell : UICollectionViewCell
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UIView *ringHostView;
@property (nonatomic, strong) CAShapeLayer *ringTrackLayer;
@property (nonatomic, strong) CAShapeLayer *ringLayer;
@property (nonatomic, strong) CAGradientLayer *ringGradientLayer;
@property (nonatomic, strong) UIButton *addBadgeButton;
@property (nonatomic, copy, nullable) dispatch_block_t onAddBadgeTapped;

/// Entrance animation for staggered spring reveal
- (void)playEntranceAnimationWithDelay:(NSTimeInterval)delay;

- (void)configureWithStory:(PPStory *)story;
- (void)configureWithStory:(PPStory *)story
          currentUserEntry:(BOOL)isCurrentUserEntry
              showAddBadge:(BOOL)showAddBadge;
@end

NS_ASSUME_NONNULL_END
