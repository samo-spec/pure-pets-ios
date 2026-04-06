//
//  PPStoryPlayerViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 2/22/26.
//

#import <UIKit/UIKit.h>
#import "PPStory.h"
#pragma mark - Story Playback

@interface PPStoryPlayerViewController : UIViewController
- (instancetype)initWithStories:(NSArray<PPStory *> *)stories startIndex:(NSInteger)index;
@end
