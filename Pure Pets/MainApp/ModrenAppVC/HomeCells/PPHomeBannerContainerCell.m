//
//  PPHomeBannerContainerCell 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 30/12/2025.
//

#import "PPHomeBannerContainerCell.h"
#import "PPBannerView.h"

@interface PPHomeBannerContainerCell ()
@property (nonatomic, strong) PPBannerView *bannerView;
@end

@implementation PPHomeBannerContainerCell

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {

        self.bannerView = [[PPBannerView alloc] init];
        self.bannerView.translatesAutoresizingMaskIntoConstraints = NO;

        [self.contentView addSubview:self.bannerView];

        [NSLayoutConstraint activateConstraints:@[
            [self.bannerView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [self.bannerView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [self.bannerView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [self.bannerView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        ]];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    //[self.bannerView reset]; // optional safety
}

- (void)configureWithBanners:(NSArray<PPBannerViewModel *> *)banners {
    [self.bannerView configureWithModel:banners.firstObject];
}

@end
