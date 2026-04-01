//
//  VideoCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 08/01/2025.
//

// VideoCollectionViewCell.h

#import "JPVideoPlayerKit.h"

@interface VideoCollectionViewCell : UICollectionViewCell
@property (nonatomic, strong) JPVideoPlayer *player;
@property (nonatomic, strong) NSString *videoURLString;
@end
