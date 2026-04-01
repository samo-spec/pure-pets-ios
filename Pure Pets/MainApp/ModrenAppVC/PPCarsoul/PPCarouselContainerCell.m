//
//  PPCarouselContainerCell 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 27/12/2025.
//


#import "PPCarouselContainerCell.h"
#import "PPCarouselView.h"
#import "PPCarouselItem.h"

@interface PPCarouselContainerCell ()
@property (nonatomic, strong) PPCarouselView *carouselView;
@end

@implementation PPCarouselContainerCell

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    // 🔒 Absolutely no background leakage
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.layer.masksToBounds = YES;

    [self setupCarouselView];
    return self;
}

#pragma mark - Setup

- (void)setupCarouselView {

    self.carouselView = [[PPCarouselView alloc] initWithFrame:CGRectZero];
    self.carouselView.translatesAutoresizingMaskIntoConstraints = NO;
    self.carouselView.backgroundColor = UIColor.clearColor;

    [self.contentView addSubview:self.carouselView];

    // Pin to all edges — section controls height
    [NSLayoutConstraint activateConstraints:@[
        [self.carouselView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.carouselView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:0],
        [self.carouselView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-0],
        [self.carouselView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
    ]];
}

#pragma mark - Configuration

- (void)prepareForReuse {
    [super prepareForReuse];
    [self.carouselView stopAutoScroll];
}

- (void)configureWithCarouselItems:(NSArray<PPCarouselItem *> *)items {

    // Safety: hide carousel if empty
    if (items.count == 0) {
        [self.carouselView configureWithItems:@[]];
        [self.carouselView stopAutoScroll];
        return;
    }

    [self.carouselView configureWithItems:items];
}

@end
