//
//  HJCarouselViewLayout.h
//  HJCarouselDemo
//
//  Created by haijiao on 15/8/20.
//  Copyright (c) 2015年 olinone. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, HJCarouselAnim) {
    HJCarouselAnimLinear,
    HJCarouselAnimRotary,
    HJCarouselAnimCarousel,
    HJCarouselAnimCarousel1,
    HJCarouselAnimCoverFlow,
};

@interface HJCarouselViewLayout : UICollectionViewLayout

- (instancetype)initWithAnim:(HJCarouselAnim)anim;
@property (nonatomic) UIEdgeInsets sectionInset;
@property (readonly)  HJCarouselAnim carouselAnim;
@property (nonatomic) UIEdgeInsets contentInset;
@property (nonatomic) CGSize itemSize;
@property (nonatomic) NSInteger visibleCount;
@property (nonatomic) UICollectionViewScrollDirection scrollDirection;

@end
