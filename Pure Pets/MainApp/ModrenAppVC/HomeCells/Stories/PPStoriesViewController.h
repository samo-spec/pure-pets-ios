//
//  PPStoriesViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 2/22/26.
//

#import "PPStory.h"
#pragma mark - Stories Bar ViewController

NS_ASSUME_NONNULL_BEGIN

@interface PPStoriesViewController : UIViewController <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSArray<PPStory *> *stories;
@property (nonatomic, copy, nullable) void (^onStoriesChanged)(NSArray<PPStory *> *stories);
@property (nonatomic, copy, nullable) NSString *sectionTitleText;
@property (nonatomic, copy, nullable) NSString *sectionTitleLocalizationKey;
- (void)reloadStories;
- (void)startObservingStories;
- (void)stopObservingStories;
@end

NS_ASSUME_NONNULL_END
