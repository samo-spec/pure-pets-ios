//
//  PPRatingView.h
//  Pure Pets
//
//  Design System — Star rating display (read-only).
//  Uses SF Symbols star icons with half-star support.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPRatingView : UIView

/// Rating value (0.0 – 5.0). Supports half-stars.
@property (nonatomic, assign) CGFloat rating;

/// Number of ratings to display beside stars (optional).
@property (nonatomic, assign) NSInteger reviewCount;

/// Star icon size in points. Default = 14.
@property (nonatomic, assign) CGFloat starSize;

/// Tint color for filled stars. Default = WarningColor (amber).
@property (nonatomic, strong) UIColor *starColor;

/// Initialize with a rating value.
- (instancetype)initWithRating:(CGFloat)rating;

/// Update the view.
- (void)setRating:(CGFloat)rating reviewCount:(NSInteger)count;

@end

NS_ASSUME_NONNULL_END
