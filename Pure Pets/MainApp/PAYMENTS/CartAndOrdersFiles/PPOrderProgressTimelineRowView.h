//
//  PPOrderProgressTimelineRowView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 7/14/26.
//


typedef NS_ENUM(NSInteger, PPOrderProgressTimelineRowState) {
    PPOrderProgressTimelineRowStateCompleted,
    PPOrderProgressTimelineRowStateCurrent,
    PPOrderProgressTimelineRowStateUpcoming,
    PPOrderProgressTimelineRowStateFailure
};

@interface PPOrderProgressTimelineRowView : UIView

- (void)configureWithTitle:(NSString *)title
                  subtitle:(NSString *)subtitle
                  metaText:(NSString *)metaText
                symbolName:(NSString *)symbolName
                     state:(PPOrderProgressTimelineRowState)state
                  expanded:(BOOL)expanded
                 tintColor:(nullable UIColor *)tintColor
                     isRTL:(BOOL)isRTL;
- (CGFloat)preferredHeightForWidth:(CGFloat)width;
- (CGFloat)markerCenterY;
- (CGFloat)trackCenterXForWidth:(CGFloat)width;
- (void)refreshCurrentStatusMotion;

@end