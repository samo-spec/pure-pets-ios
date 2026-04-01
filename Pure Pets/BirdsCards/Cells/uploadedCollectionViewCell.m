//
//  uploadedCollectionViewCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/07/2024.
//

#import "uploadedCollectionViewCell.h"

@implementation uploadedCollectionViewCell


- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}
-(void)awakeFromNib
{
    [super awakeFromNib];
    
    [self setupUI];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.mainImageView.frame = self.contentView.bounds;
    
   
}
- (void)setupUI {
    
   // [self.contentView addSubview:self.videoContainerView];

    // Add constraints to fill the cell with videoContainerView

}

- (void)prepareForReuse {
    [super prepareForReuse];
    [self.videoContainerView jp_stopPlay];
   
}


@end
