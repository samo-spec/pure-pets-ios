//
//  RoundedImageViewWithShadow.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 14/02/2025.
//



#import <UIKit/UIKit.h>

@interface RoundedImageViewWithShadow : UIView

@property (nonatomic, strong, readonly) UIImageView *imageView;
@property (nonatomic, assign) CGFloat progress;

- (instancetype)initWithFrame:(CGRect)frame;
- (instancetype)initWithImage:(UIImage *)image;
- (instancetype)initWithFrame:(CGRect)frame image:(UIImage *)image;

@end
