//
//  uploadedCollectionViewCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/07/2024.
//


#import "JPVideoPlayerKit.h"

NS_ASSUME_NONNULL_BEGIN

@interface uploadedCollectionViewCell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet UIImageView *mainImageView;

@property (nonatomic, strong) IBOutlet UIView *videoContainerView;
@property (nonatomic, strong) NSURL *videoURL;

- (void)prepareForReuse; // Override

@end

NS_ASSUME_NONNULL_END
