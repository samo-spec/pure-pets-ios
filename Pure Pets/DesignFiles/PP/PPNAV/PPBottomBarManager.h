//
//  PPBottomBarManager.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 28/11/2025.
//




NS_ASSUME_NONNULL_BEGIN


@interface PPBottomBarManager : NSObject

@property (nonatomic, strong, readonly) PPNewBottomBar *bar;

+ (instancetype)shared;
- (void)attachToWindow;
- (void)show;
- (void)hide;


- (NSLayoutYAxisAnchor *)topAnchor;
- (CGFloat)barHeight;
- (CGFloat)barTopY;
@end
NS_ASSUME_NONNULL_END
