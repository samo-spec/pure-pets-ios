//
//  VideoCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 08/01/2025.
//

// VideoCollectionViewCell.m
#import "VideoCollectionViewCell.h"

@interface VideoCollectionViewCell ()

@property (nonatomic, strong) UIView *videoContainerView;
@property (nonatomic, strong) JPVideoPlayer *videoPlayer;

@end



@implementation VideoCollectionViewCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupView];
    }
    return self;
}


- (void)setupView {
  
    // 1. Create a container view
    _videoContainerView = [[UIView alloc] init];
    _videoContainerView.backgroundColor = [UIColor grayColor]; // Placeholder color, customize as needed
    _videoContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_videoContainerView];
    
     // Setting constraints
        [[_videoContainerView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:0] setActive:YES];
        [[_videoContainerView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:0] setActive:YES];
        [[_videoContainerView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:0] setActive:YES];
        [[_videoContainerView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:0] setActive:YES];
        
    
    // 2. Initialize JPVideoPlayer
    _videoPlayer = [JPVideoPlayer init]; // Use shared player or create an instance per cell

}


- (void)prepareForReuse {
    [super prepareForReuse];
    // Stop playback when cell is reused to avoid issues with scrolling
    [_videoPlayer stopPlay];
    _videoContainerView.backgroundColor = [UIColor grayColor]; // Reset if you change color
}

- (void)configureCellWithURL:(NSString *)urlString {

    if (urlString.length > 0) {
        _videoContainerView.backgroundColor = [UIColor blackColor];
        //self.videoPlayer = _videoContainerView;
       // [self.videoPlayer playWithURLString:urlString view:self.videoContainerView];
    }
   
}

@end
