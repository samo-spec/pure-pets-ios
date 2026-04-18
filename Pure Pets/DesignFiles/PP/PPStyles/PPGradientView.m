//
//  UIView.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 18/09/2025.
//


#import "PPGradientView.h"
#import <objc/runtime.h>

// Association keys
static char kPPGradientLayerKey;

@implementation UIView (PPViewDesign)
 
- (void)setShadow:(UIColor*)color offset:(CGSize)offset radius:(CGFloat)radius {
    [self pp_setShadowColor:color];
    self.layer.shadowOffset = offset;
    self.layer.shadowRadius = radius;
    self.layer.shadowOpacity = 1;
    self.layer.shouldRasterize = YES;
    self.layer.rasterizationScale = [UIScreen mainScreen].scale;
}


- (void)setBlackShadowOffset:(CGSize)offset radius:(CGFloat)radius alpha:(CGFloat)alpha{
    [self pp_setShadowColor:[AppShadowClr colorWithAlphaComponent:alpha]];
    self.layer.shadowOffset = offset;
    self.layer.shadowRadius = radius;
    self.layer.shadowOpacity = 1;
    self.layer.shouldRasterize = YES;
    self.layer.rasterizationScale = [UIScreen mainScreen].scale;
}


- (void)pp_ApplyCornerMask_tl:(CGFloat)tl
                           tr:(CGFloat)tr
                           bl:(CGFloat)bl
                           br:(CGFloat)br
{
    [self layoutIfNeeded];
    CGRect bounds = self.bounds;
    if (CGRectIsEmpty(bounds)) return;

    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat w = bounds.size.width;
    CGFloat h = bounds.size.height;

    // Draw each corner manually
    [path moveToPoint:CGPointMake(0, tl)];
    [path addQuadCurveToPoint:CGPointMake(tl, 0) controlPoint:CGPointZero];

    [path addLineToPoint:CGPointMake(w - tr, 0)];
    [path addQuadCurveToPoint:CGPointMake(w, tr) controlPoint:CGPointMake(w, 0)];

    [path addLineToPoint:CGPointMake(w, h - br)];
    [path addQuadCurveToPoint:CGPointMake(w - br, h) controlPoint:CGPointMake(w, h)];

    [path addLineToPoint:CGPointMake(bl, h)];
    [path addQuadCurveToPoint:CGPointMake(0, h - bl) controlPoint:CGPointMake(0, h)];

    [path closePath];

    CAShapeLayer *mask = [CAShapeLayer layer];
    mask.path = path.CGPath;
    self.layer.mask = mask;
    
    
}


- (void)pp_applyGradientWithStartColor:(UIColor *)startColor
                              endColor:(UIColor *)endColor
                          cornerRadius:(CGFloat)cornerRadius {
    
    [self pp_applyGradientWithStartColor:startColor
                                endColor:endColor
                            cornerRadius:cornerRadius
                             shadowColor:AppShadowClr
                           shadowOpacity:0.0
                            shadowRadius:0.0
                            shadowOffset:CGSizeZero];
}


- (void)pp_applyGradientWithColors:(NSArray<UIColor *> *)colors  cornerRadius:(CGFloat)cornerRadius shadowColor:(UIColor *)shadowColor shadowOpacity:(float)shadowOpacity shadowRadius:(CGFloat)shadowRadius shadowOffset:(CGSize)shadowOffset
{
    // Remove existing gradient
    [self pp_removeGradient];
    
    // Create gradient layer
    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    gradientLayer.needsDisplayOnBoundsChange = YES;
    
    // Configure gradient direction (top to bottom)
    gradientLayer.startPoint = CGPointMake(0.5, 0.0);
    gradientLayer.endPoint = CGPointMake(0.5, 1.0);
    
    // Set gradient colors with smooth transition
    gradientLayer.colors = colors;
   
    // Optional: Add mid-point for smoother transition
    // gradientLayer.locations = @[@0.0, @0.3, @1.0]; // For 3-color gradient
    
    // Set frame and corner radius
    gradientLayer.frame = self.bounds;
    gradientLayer.cornerRadius = cornerRadius;
    gradientLayer.masksToBounds = YES;
    
    // Insert at the back
    [self.layer insertSublayer:gradientLayer atIndex:0];
    
    // Configure shadow if provided
    if (shadowColor && shadowOpacity > 0) {
        self.layer.masksToBounds = NO;
        [self pp_setShadowColor:shadowColor];
        self.layer.shadowOpacity = shadowOpacity;
        self.layer.shadowRadius = shadowRadius;
        self.layer.shadowOffset = shadowOffset;
        self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:cornerRadius].CGPath;
    }
    
    // Store reference
    objc_setAssociatedObject(self, &kPPGradientLayerKey, gradientLayer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)pp_applyGradientWithStartColor:(UIColor *)startColor
                              endColor:(UIColor *)endColor
                          cornerRadius:(CGFloat)cornerRadius
                           shadowColor:(UIColor *)shadowColor
                         shadowOpacity:(float)shadowOpacity
                          shadowRadius:(CGFloat)shadowRadius
                          shadowOffset:(CGSize)shadowOffset {
    NSArray<UIColor *>  *colors = @[
        (__bridge id)startColor.CGColor,
        (__bridge id)endColor.CGColor
    ];
    
    // Remove existing gradient
    [self pp_removeGradient];
    
    // Create gradient layer
    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    gradientLayer.needsDisplayOnBoundsChange = YES;
    
    // Configure gradient direction (top to bottom)
    gradientLayer.startPoint = CGPointMake(0.5, 0.0);
    gradientLayer.endPoint = CGPointMake(0.5, 1.0);
    
    // Set gradient colors with smooth transition
    gradientLayer.colors = colors;
   
    // Optional: Add mid-point for smoother transition
    // gradientLayer.locations = @[@0.0, @0.3, @1.0]; // For 3-color gradient
    
    // Set frame and corner radius
    gradientLayer.frame = self.bounds;
    gradientLayer.cornerRadius = cornerRadius;
    gradientLayer.masksToBounds = YES;
    
    // Insert at the back
    [self.layer insertSublayer:gradientLayer atIndex:0];
    
    // Configure shadow if provided
    if (shadowColor && shadowOpacity > 0) {
        self.layer.masksToBounds = NO;
        [self pp_setShadowColor:shadowColor];
        self.layer.shadowOpacity = shadowOpacity;
        self.layer.shadowRadius = shadowRadius;
        self.layer.shadowOffset = shadowOffset;
        self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:cornerRadius].CGPath;
    }
    
    // Store reference
    objc_setAssociatedObject(self, &kPPGradientLayerKey, gradientLayer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)pp_removeGradient {
    CAGradientLayer *gradientLayer = objc_getAssociatedObject(self, &kPPGradientLayerKey);
    
    if (gradientLayer) {
        [gradientLayer removeFromSuperlayer];
        objc_setAssociatedObject(self, &kPPGradientLayerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    // Reset shadow
    [self pp_setShadowColor:nil];
    self.layer.shadowOpacity = 0;
    self.layer.shadowRadius = 0;
    self.layer.shadowPath = nil;
}

- (void)layoutSubviews {
    
    // Update gradient layer frame on layout changes
    CAGradientLayer *gradientLayer = objc_getAssociatedObject(self, &kPPGradientLayerKey);
    
    if (gradientLayer) {
        // Animate frame change smoothly
        [CATransaction begin];
        [CATransaction setDisableActions:YES]; // Prevent animation
        gradientLayer.frame = self.bounds;
        
        // Update shadow path if shadow is enabled
        if (self.layer.shadowOpacity > 0) {
            self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds 
                                                              cornerRadius:gradientLayer.cornerRadius].CGPath;
        }
        
        [CATransaction commit];
    }
}

+ (CAGradientLayer *)gradientLayerWithFadeForColor:(UIColor *)gardColor
                                   direction:(PPGradientDirection)direction
                                       frame:(CGRect)frame {
    
    NSArray *colors = @[
        [gardColor colorWithAlphaComponent:1.0],
        [gardColor colorWithAlphaComponent:0.9],
        [gardColor colorWithAlphaComponent:0.8],
        [gardColor colorWithAlphaComponent:0.7],
        [gardColor colorWithAlphaComponent:0.6],
        [gardColor colorWithAlphaComponent:0.5],
        [gardColor colorWithAlphaComponent:0.4],
        [gardColor colorWithAlphaComponent:0.3],
        [gardColor colorWithAlphaComponent:0.2],
        [gardColor colorWithAlphaComponent:0.1],
        [gardColor colorWithAlphaComponent:0.0]
    ];
    
    
    if (colors.count < 2) {
        NSLog(@"⚠️ GradientUtils: At least 2 colors are required.");
        return nil;
    }

    CAGradientLayer *layer = [CAGradientLayer layer];
    layer.frame = frame;

    NSMutableArray *cgColors = [NSMutableArray arrayWithCapacity:colors.count];
    for (UIColor *color in colors) {
        [cgColors addObject:(id)color.CGColor];
    }
    layer.colors = cgColors;

    switch (direction) {
        case PPGradientDirectionLeftToRight:
            layer.startPoint = CGPointMake(0.0, 0.5);
            layer.endPoint   = CGPointMake(1.0, 0.5);
            break;
        case PPGradientDirectionRightToLeft:
            layer.startPoint = CGPointMake(1.0, 0.5);
            layer.endPoint   = CGPointMake(0.0, 0.5);
            break;
        case PPGradientDirectionTopToBottom:
            layer.startPoint = CGPointMake(0.5, 0.0);
            layer.endPoint   = CGPointMake(0.5, 1.0);
            break;
        case PPGradientDirectionBottomToTop:
            layer.startPoint = CGPointMake(0.5, 1.0);
            layer.endPoint   = CGPointMake(0.5, 0.0);
            break;
    }

    return layer;
}


+ (CAGradientLayer *)halfGradientLayerWithFadeForColor:(UIColor *)gardColor
                                   direction:(PPGradientDirection)direction
                                       frame:(CGRect)frame {
    
    NSArray *colors = @[
        //[gardColor colorWithAlphaComponent:1.0],
        //[gardColor colorWithAlphaComponent:0.9],
        //[gardColor colorWithAlphaComponent:0.8],
        //[gardColor colorWithAlphaComponent:0.7],
        //[gardColor colorWithAlphaComponent:0.6],
        [gardColor colorWithAlphaComponent:0.5],
        [gardColor colorWithAlphaComponent:0.4],
        [gardColor colorWithAlphaComponent:0.3],
        [gardColor colorWithAlphaComponent:0.2],
        [gardColor colorWithAlphaComponent:0.1],
        [gardColor colorWithAlphaComponent:0.0]
    ];
    
    
    if (colors.count < 2) {
        NSLog(@"⚠️ GradientUtils: At least 2 colors are required.");
        return nil;
    }

    CAGradientLayer *layer = [CAGradientLayer layer];
    layer.frame = frame;

    NSMutableArray *cgColors = [NSMutableArray arrayWithCapacity:colors.count];
    for (UIColor *color in colors) {
        [cgColors addObject:(id)color.CGColor];
    }
    layer.colors = cgColors;

    switch (direction) {
        case PPGradientDirectionLeftToRight:
            layer.startPoint = CGPointMake(0.0, 0.5);
            layer.endPoint   = CGPointMake(1.0, 0.5);
            break;
        case PPGradientDirectionRightToLeft:
            layer.startPoint = CGPointMake(1.0, 0.5);
            layer.endPoint   = CGPointMake(0.0, 0.5);
            break;
        case PPGradientDirectionTopToBottom:
            layer.startPoint = CGPointMake(0.5, 0.0);
            layer.endPoint   = CGPointMake(0.5, 1.0);
            break;
        case PPGradientDirectionBottomToTop:
            layer.startPoint = CGPointMake(0.5, 1.0);
            layer.endPoint   = CGPointMake(0.5, 0.0);
            break;
    }

    return layer;
}

+ (UIView *)blurredGradientViewWithColor:(UIColor *)gardColor
                               direction:(PPGradientDirection)direction
                                   frame:(CGRect)frame {
    // 1️⃣ Create base container
    UIView *container = [[UIView alloc] initWithFrame:frame];
    container.clipsToBounds = YES;
    container.userInteractionEnabled = NO;

    // 2️⃣ Add modern blur effect
    if (@available(iOS 18.0, *)) {
        // iOS 18+ system glass blur
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurView.frame = container.bounds;
        blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        blurView.alpha = 1.0; // adjust between 0.8–1.0 for intensity
        [container addSubview:blurView];
    } else {
        // Older iOS fallback
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurView.frame = container.bounds;
        blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        blurView.alpha = 0.95;
        [container addSubview:blurView];
    }

    // 3️⃣ Create gradient overlay using your existing fade logic
    
    CAGradientLayer *gradient = [self halfGradientLayerWithFadeForColor:gardColor
                                                              direction:direction
                                                                  frame:container.bounds];
 
    // Make gradient track view size automatically
    container.layer.needsDisplayOnBoundsChange = YES;
    gradient.needsDisplayOnBoundsChange = YES;

    gradient.frame = container.bounds;
    gradient.opacity = 0.95;
    gradient.needsDisplayOnBoundsChange = YES;
    [container.layer addSublayer:gradient];

    return container;
}




+ (CAGradientLayer *)gradientLayerWithColors:(NSArray<UIColor *> *)colors
                                   direction:(PPGradientDirection)direction
                                       frame:(CGRect)frame {
    if (colors.count < 2) {
        NSLog(@"⚠️ GradientUtils: At least 2 colors are required.");
        return nil;
    }

    CAGradientLayer *layer = [CAGradientLayer layer];
    layer.frame = frame;

    NSMutableArray *cgColors = [NSMutableArray arrayWithCapacity:colors.count];
    for (UIColor *color in colors) {
        [cgColors addObject:(id)color.CGColor];
    }
    layer.colors = cgColors;

    switch (direction) {
        case PPGradientDirectionLeftToRight:
            layer.startPoint = CGPointMake(0.0, 0.5);
            layer.endPoint   = CGPointMake(1.0, 0.5);
            break;
        case PPGradientDirectionRightToLeft:
            layer.startPoint = CGPointMake(1.0, 0.5);
            layer.endPoint   = CGPointMake(0.0, 0.5);
            break;
        case PPGradientDirectionTopToBottom:
            layer.startPoint = CGPointMake(0.5, 0.0);
            layer.endPoint   = CGPointMake(0.5, 1.0);
            break;
        case PPGradientDirectionBottomToTop:
            layer.startPoint = CGPointMake(0.5, 1.0);
            layer.endPoint   = CGPointMake(0.5, 0.0);
            break;
    }

    return layer;
}


@end











@implementation UIView (PPHXExtension)


- (CGFloat)hx_maxx
{
    return ([self hx_x] + [self hx_w]);
}


- (void)setHx_maxx:(CGFloat)hx_maxx
{
}


- (CGFloat)hx_maxy
{
    return ([self hx_y] + [self hx_h]);
}
- (void)setHx_maxy:(CGFloat)hx_maxx
{
}

- (void)setHx_x:(CGFloat)hx_x
{
    CGRect frame = self.frame;
    frame.origin.x = hx_x;
    self.frame = frame;
}

- (CGFloat)hx_x
{
    return self.frame.origin.x;
}

- (void)setHx_y:(CGFloat)hx_y
{
    CGRect frame = self.frame;
    frame.origin.y = hx_y;
    self.frame = frame;
}

- (CGFloat)hx_y
{
    return self.frame.origin.y;
}

- (void)setHx_w:(CGFloat)hx_w
{
    CGRect frame = self.frame;
    frame.size.width = hx_w;
    self.frame = frame;
}

- (CGFloat)hx_w
{
    return self.frame.size.width;
}

- (void)setHx_h:(CGFloat)hx_h
{
    CGRect frame = self.frame;
    frame.size.height = hx_h;
    self.frame = frame;
}

- (CGFloat)hx_h
{
    return self.frame.size.height;
}

- (CGFloat)hx_centerX
{
    return self.center.x;
}

- (void)setHx_centerX:(CGFloat)hx_centerX {
    CGPoint center = self.center;
    center.x = hx_centerX;
    self.center = center;
}

- (CGFloat)hx_centerY
{
    return self.center.y;
}

- (void)setHx_centerY:(CGFloat)hx_centerY {
    CGPoint center = self.center;
    center.y = hx_centerY;
    self.center = center;
}

- (void)setHx_size:(CGSize)hx_size
{
    CGRect frame = self.frame;
    frame.size = hx_size;
    self.frame = frame;
}

- (CGSize)hx_size
{
    return self.frame.size;
}

- (void)setHx_origin:(CGPoint)hx_origin
{
    CGRect frame = self.frame;
    frame.origin = hx_origin;
    self.frame = frame;
}

- (CGPoint)hx_origin
{
    return self.frame.origin;
}

@end
