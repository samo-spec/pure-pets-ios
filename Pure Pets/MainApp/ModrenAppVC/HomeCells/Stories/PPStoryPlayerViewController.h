//
//  PPStoryPlayerViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 2/22/26.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "PPStory.h"
#pragma mark - Story Playback

@interface PPStoryPlayerViewController : UIViewController
@property (nonatomic, strong) NSArray<PPStory *> *stories;
@property (nonatomic) NSInteger currentStoryIndex;
@property (nonatomic) NSInteger currentItemIndex;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) UIView *progressContainer;
@property (nonatomic, strong) NSMutableArray<UIProgressView *> *progressBars;
@property (nonatomic, strong) NSTimer *timer;
- (instancetype)initWithStories:(NSArray<PPStory *> *)stories startIndex:(NSInteger)index;
@end
