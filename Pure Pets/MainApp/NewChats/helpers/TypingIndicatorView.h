//
//  TypingIndicatorView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 21/01/2026.
//


typedef NS_ENUM(NSInteger, PTTypingAnimationStyle) {
   PTTypingAnimationStyleFade,
   PTTypingAnimationStyleSlide,
   PTTypingAnimationStylePulse
};



@interface TypingIndicatorView : UIButton

@property (nonatomic, assign) NSInteger dotsCount;
@property (nonatomic, assign) PTTypingAnimationStyle animationStyle;

- (void)startAnimating;
- (void)stopAnimating;

@end
