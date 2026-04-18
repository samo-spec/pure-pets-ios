//
//  RNFrostedMenu.m
//  RNFrostedMenu
//
//  Created by Ryan Nystrom on 8/13/13.
//  Copyright (c) 2013 Ryan Nystrom. All rights reserved.
//

#define __IPHONE_OS_VERSION_SOFT_MAX_REQUIRED __IPHONE_7_0

#import "RNFrostedSidebar.h"
#import <QuartzCore/QuartzCore.h>

#pragma mark - Categories

@implementation UIView (rn_Screenshot)

- (UIImage *)rn_screenshot {
    UIGraphicsBeginImageContext(self.bounds.size);
    [self.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    NSData *imageData = UIImageJPEGRepresentation(image, 0.75);
    image = [UIImage imageWithData:imageData];
    return image;
}

@end

#import <Accelerate/Accelerate.h>

@implementation UIImage (rn_Blur)

- (UIImage *)applyBlurWithRadius:(CGFloat)blurRadius tintColor:(UIColor *)tintColor saturationDeltaFactor:(CGFloat)saturationDeltaFactor maskImage:(UIImage *)maskImage
{
    // Check pre-conditions.
    if (self.size.width < 1 || self.size.height < 1) {
        NSLog (@"*** error: invalid size: (%.2f x %.2f). Both dimensions must be >= 1: %@", self.size.width, self.size.height, self);
        return nil;
    }
    if (!self.CGImage) {
        NSLog (@"*** error: image must be backed by a CGImage: %@", self);
        return nil;
    }
    if (maskImage && !maskImage.CGImage) {
        NSLog (@"*** error: maskImage must be backed by a CGImage: %@", maskImage);
        return nil;
    }
    
    CGRect imageRect = { CGPointZero, self.size };
    UIImage *effectImage = self;
    
    BOOL hasBlur = blurRadius > __FLT_EPSILON__;
    BOOL hasSaturationChange = fabs(saturationDeltaFactor - 1.) > __FLT_EPSILON__;
    if (hasBlur || hasSaturationChange) {
        UIGraphicsBeginImageContextWithOptions(self.size, NO, [[UIScreen mainScreen] scale]);
        CGContextRef effectInContext = UIGraphicsGetCurrentContext();
        CGContextScaleCTM(effectInContext, 1.0, -1.0);
        CGContextTranslateCTM(effectInContext, 0, -self.size.height);
        CGContextDrawImage(effectInContext, imageRect, self.CGImage);
        
        vImage_Buffer effectInBuffer;
        effectInBuffer.data     = CGBitmapContextGetData(effectInContext);
        effectInBuffer.width    = CGBitmapContextGetWidth(effectInContext);
        effectInBuffer.height   = CGBitmapContextGetHeight(effectInContext);
        effectInBuffer.rowBytes = CGBitmapContextGetBytesPerRow(effectInContext);
        
        UIGraphicsBeginImageContextWithOptions(self.size, NO, [[UIScreen mainScreen] scale]);
        CGContextRef effectOutContext = UIGraphicsGetCurrentContext();
        vImage_Buffer effectOutBuffer;
        effectOutBuffer.data     = CGBitmapContextGetData(effectOutContext);
        effectOutBuffer.width    = CGBitmapContextGetWidth(effectOutContext);
        effectOutBuffer.height   = CGBitmapContextGetHeight(effectOutContext);
        effectOutBuffer.rowBytes = CGBitmapContextGetBytesPerRow(effectOutContext);
        
        if (hasBlur) {
            // A description of how to compute the box kernel width from the Gaussian
            // radius (aka standard deviation) appears in the SVG spec:
            // http://www.w3.org/TR/SVG/filters.html#feGaussianBlurElement
            //
            // For larger values of 's' (s >= 2.0), an approximation can be used: Three
            // successive box-blurs build a piece-wise quadratic convolution kernel, which
            // approximates the Gaussian kernel to within roughly 3%.
            //
            // let d = floor(s * 3*sqrt(2*pi)/4 + 0.5)
            //
            // ... if d is odd, use three box-blurs of size 'd', centered on the output pixel.
            //
            CGFloat inputRadius = blurRadius * [[UIScreen mainScreen] scale];
            NSUInteger radius = floor(inputRadius * 3. * sqrt(2 * M_PI) / 4 + 0.5);
            if (radius % 2 != 1) {
                radius += 1; // force radius to be odd so that the three box-blur methodology works.
            }
            vImageBoxConvolve_ARGB8888(&effectInBuffer, &effectOutBuffer, NULL, 0, 0, radius, radius, 0, kvImageEdgeExtend);
            vImageBoxConvolve_ARGB8888(&effectOutBuffer, &effectInBuffer, NULL, 0, 0, radius, radius, 0, kvImageEdgeExtend);
            vImageBoxConvolve_ARGB8888(&effectInBuffer, &effectOutBuffer, NULL, 0, 0, radius, radius, 0, kvImageEdgeExtend);
        }
        BOOL effectImageBuffersAreSwapped = NO;
        if (hasSaturationChange) {
            CGFloat s = saturationDeltaFactor;
            CGFloat floatingPointSaturationMatrix[] = {
                0.0722 + 0.9278 * s,  0.0722 - 0.0722 * s,  0.0722 - 0.0722 * s,  0,
                0.7152 - 0.7152 * s,  0.7152 + 0.2848 * s,  0.7152 - 0.7152 * s,  0,
                0.2126 - 0.2126 * s,  0.2126 - 0.2126 * s,  0.2126 + 0.7873 * s,  0,
                0,                    0,                    0,  1,
            };
            const int32_t divisor = 256;
            NSUInteger matrixSize = sizeof(floatingPointSaturationMatrix)/sizeof(floatingPointSaturationMatrix[0]);
            int16_t saturationMatrix[matrixSize];
            for (NSUInteger i = 0; i < matrixSize; ++i) {
                saturationMatrix[i] = (int16_t)roundf(floatingPointSaturationMatrix[i] * divisor);
            }
            if (hasBlur) {
                vImageMatrixMultiply_ARGB8888(&effectOutBuffer, &effectInBuffer, saturationMatrix, divisor, NULL, NULL, kvImageNoFlags);
                effectImageBuffersAreSwapped = YES;
            }
            else {
                vImageMatrixMultiply_ARGB8888(&effectInBuffer, &effectOutBuffer, saturationMatrix, divisor, NULL, NULL, kvImageNoFlags);
            }
        }
        if (!effectImageBuffersAreSwapped)
            effectImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        if (effectImageBuffersAreSwapped)
            effectImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    
    // Set up output context.
    UIGraphicsBeginImageContextWithOptions(self.size, NO, [[UIScreen mainScreen] scale]);
    CGContextRef outputContext = UIGraphicsGetCurrentContext();
    CGContextScaleCTM(outputContext, 1.0, -1.0);
    CGContextTranslateCTM(outputContext, 0, -self.size.height);
    
    // Draw base image.
    CGContextDrawImage(outputContext, imageRect, self.CGImage);
    
    // Draw effect image.
    if (hasBlur) {
        CGContextSaveGState(outputContext);
        if (maskImage) {
            CGContextClipToMask(outputContext, imageRect, maskImage.CGImage);
        }
        CGContextDrawImage(outputContext, imageRect, effectImage.CGImage);
        CGContextRestoreGState(outputContext);
    }
    
    // Add in color tint.
    if (tintColor) {
        CGContextSaveGState(outputContext);
        CGContextSetFillColorWithColor(outputContext, tintColor.CGColor);
        CGContextFillRect(outputContext, imageRect);
        CGContextRestoreGState(outputContext);
    }
    
    // Output image is ready.
    UIImage *outputImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return outputImage;
}

@end

#pragma mark - Private Classes

@interface RNCalloutItemView : UIView
@property (nonatomic, strong) MainKindsModel *mainKind;
@property (nonatomic, strong) SubKindModel *subKindModel;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIView *titleBackgroundView;
@property (nonatomic, assign) NSInteger itemIndex;
@property (nonatomic, strong) UIColor *originalBackgroundColor;
@property (nonatomic, assign) NSInteger catID;
@property (nonatomic, strong) CAGradientLayer *fadeLayer;
@property (nonatomic, strong) UIView *dimView;   // 🔥 overlay for dimming

@end


@implementation RNCalloutItemView
- (instancetype)init {
    if (self = [super init]) {
        _imageView = [[UIImageView alloc] init];
        _imageView.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.5];
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = YES;
        [self addSubview:_imageView];
        
        _dimView = [[UIView alloc] init];
        _dimView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4];
        _dimView.alpha = 0; // hidden by default
        [_imageView addSubview:_dimView];
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.numberOfLines = 2;
        _titleLabel.font = [GM boldFontWithSize:12];
        _titleLabel.textColor = UIColor.whiteColor;
        _titleLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        [self addSubview:_titleLabel];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.imageView.frame = self.bounds;
    
    self.imageView.layer.cornerRadius = self.imageView.hx_h/2;
    self.dimView.frame = self.imageView.bounds;
    self.dimView.layer.cornerRadius = self.imageView.layer.cornerRadius;
    
    CGFloat labelHeight = 36;
    self.titleLabel.frame = CGRectMake(0,
                                       self.bounds.size.height - labelHeight,
                                       self.bounds.size.width,
                                       labelHeight);
    self.titleLabel.layer.cornerRadius = 35;
    self.titleLabel.clipsToBounds = YES;
    
}

- (void)setHighlighted:(BOOL)highlighted {
    [UIView animateWithDuration:0.25 animations:^{
        self.dimView.alpha = highlighted ? 0.0 : 1.0; // 🔥 hide dim for selected
        self.layer.borderWidth = highlighted ? 3 : 0;
        [self pp_setBorderColor:highlighted ? AppPrimaryClr : UIColor.clearColor];
        self.transform = highlighted ? CGAffineTransformMakeScale(1.1, 1.1) : CGAffineTransformIdentity;
    }];
}



























- (void)setOriginalBackgroundColor:(UIColor *)originalBackgroundColor {
    _originalBackgroundColor = originalBackgroundColor;
    self.backgroundColor = originalBackgroundColor;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    
    CGFloat r, g, b, a;
    CGFloat darkenFactor = 0.3f;
    UIColor *darkerColor;
    if ([self.originalBackgroundColor getRed:&r green:&g blue:&b alpha:&a]) {
        darkerColor = [UIColor colorWithRed:MAX(r - darkenFactor, 0.0) green:MAX(g - darkenFactor, 0.0) blue:MAX(b - darkenFactor, 0.0) alpha:a];
    }
    else if ([self.originalBackgroundColor getWhite:&r alpha:&a]) {
        darkerColor = [UIColor colorWithWhite:MAX(r - darkenFactor, 0.0) alpha:a];
    }
    else {
        @throw @"Item color should be RGBA or White/Alpha in order to darken the button color.";
    }
    self.backgroundColor = darkerColor;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    self.backgroundColor = self.originalBackgroundColor;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    self.backgroundColor = self.originalBackgroundColor;
}

@end

#pragma mark - Public Classes

@interface RNFrostedSidebar ()
@property (nonatomic, strong) UIScrollView *contentView;
@property (nonatomic, strong) UIView *modrenBlurView;
@property (nonatomic, strong) UITapGestureRecognizer *tapGesture;
@property (nonatomic, strong) NSArray *images;
@property (nonatomic, strong) NSArray<SubKindModel *> *subKindsArr;
@property (nonatomic, strong) NSArray *borderColors;
@property (nonatomic, strong) NSMutableArray *itemViews;
@property (nonatomic, strong) NSMutableIndexSet *selectedIndices;
@property (nonatomic, strong) UIView *dimView;   // ✅ new

@end

static RNFrostedSidebar *rn_frostedMenu;

@implementation RNFrostedSidebar

+ (instancetype)visibleSidebar {
    return rn_frostedMenu;
}

- (instancetype)initWithImages:(NSArray *)images selectedIndices:(NSIndexSet *)selectedIndices borderColors:(NSArray *)colors {
    if (self = [super init]) {
        _contentView = [[UIScrollView alloc] init];
        _contentView.alwaysBounceHorizontal = NO;
        _contentView.alwaysBounceVertical = YES;
        _contentView.bounces = YES;
        _contentView.clipsToBounds = NO;
        _contentView.showsHorizontalScrollIndicator = NO;
        _contentView.showsVerticalScrollIndicator = NO;
        
        _width = 130;
        _animationDuration = 0.25f;
        _itemSize = CGSizeMake(_width/2+20, _width/2+20);
        _itemViews = [NSMutableArray array];
        _tintColor = [UIColor colorWithWhite:0.2 alpha:0.73];
        _borderWidth = 2;
        _itemBackgroundColor = [UIColor colorWithRed:1 green:1 blue:1 alpha:0.25];
        
        if (colors) {
            NSAssert([colors count] == [images count], @"Border color count must match images count. If you want a blank border, use [UIColor clearColor].");
        }
        
        _selectedIndices = [selectedIndices mutableCopy] ?: [NSMutableIndexSet indexSet];
        _borderColors = colors;
        _images = images;
        
        [_images enumerateObjectsUsingBlock:^(UIImage *image, NSUInteger idx, BOOL *stop) {
            RNCalloutItemView *view = [[RNCalloutItemView alloc] init];
            view.itemIndex = idx;
            view.clipsToBounds = YES;
            view.imageView.image = image;
            [_contentView addSubview:view];
            
            [_itemViews addObject:view];
            
            if (_borderColors && _selectedIndices && [_selectedIndices containsIndex:idx]) {
                UIColor *color = _borderColors[idx];
                [view pp_setBorderColor:color];
            }
            else {
                [view pp_setBorderColor:[UIColor clearColor]];
            }
        }];
    }
    return self;
}

-(instancetype)initWithPetSubKindsArray:(NSArray<SubKindModel *> *)subKindsArr
{
    if (self = [super init]) {
        _contentView = [[UIScrollView alloc] init];
        _contentView.alwaysBounceHorizontal = NO;
        _contentView.alwaysBounceVertical = YES;
        _contentView.bounces = YES;
        _contentView.clipsToBounds = NO;
        _contentView.showsHorizontalScrollIndicator = NO;
        _contentView.showsVerticalScrollIndicator = NO;
        _contentView.backgroundColor = AppClearClr;
        
       
       _modrenBlurView = [[UIView alloc] initWithFrame:self.contentView.bounds];
        [self applyModernFrostedBackgroundToView:_modrenBlurView cornerRadius:0];
        
        _width = 130;
        _animationDuration = 0.35f;
        _itemSize = CGSizeMake(_width/2 + 35, _width/2 +35);
        _itemViews = [NSMutableArray array];
        _tintColor = AppClearClr;
        _borderWidth = 1.5;
        _itemBackgroundColor = [UIColor colorWithRed:1 green:1 blue:1 alpha:0.05];
       
        _selectedIndex = NSNotFound;

        _selectedIndices = nil;
        _borderColors = nil;
        
        _subKindsArr = subKindsArr;
        
        [_subKindsArr enumerateObjectsUsingBlock:^(SubKindModel *subKind, NSUInteger idx, BOOL *stop) {
            RNCalloutItemView *view = [[RNCalloutItemView alloc] init];
            view.itemIndex = idx;
            view.clipsToBounds = YES;
            view.subKindModel = subKind;
           // view.imageView.image = PPImage(subKind.SubKindImageName);
            view.titleLabel.text = subKind.SubKindName;
            view.catID = subKind.ID;
            [_contentView addSubview:view];
            
            [_itemViews addObject:view];
            
            if (_borderColors && _selectedIndices && [_selectedIndices containsIndex:idx]) {
                UIColor *color = _borderColors[idx];
                [view pp_setBorderColor:color];
            }
            else {
                [view pp_setBorderColor:[UIColor clearColor]];
            }
            
            [view pp_setBorderColor:[AppPrimaryClr colorWithAlphaComponent:0.5]];
        }];
    }
    return self;
}

- (instancetype)initWithImages:(NSArray *)images selectedIndices:(NSIndexSet *)selectedIndices {
    return [self initWithImages:images selectedIndices:selectedIndices borderColors:nil];
}

- (instancetype)initWithImages:(NSArray *)images {
    return [self initWithImages:images selectedIndices:nil borderColors:nil];
}

- (instancetype)init {
    NSAssert(NO, @"Unable to create with plain init.");
    return nil;
}

- (void)loadView {
    [super loadView];
    self.view.backgroundColor = [UIColor clearColor];
    
    
    [self.view addSubview:self.modrenBlurView];
    
    
    [self.view addSubview:self.contentView];
    self.tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    [self.view addGestureRecognizer:self.tapGesture];
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    if ([self isViewLoaded] && self.view.window != nil) {
        self.view.alpha = 0;
        self.view.alpha =0.1;
        self.modrenBlurView.alpha = 0.1;
        [self layoutSubviews];
    }
}

#pragma mark - Show

- (void)animateSpringWithView:(RNCalloutItemView *)view idx:(NSUInteger)idx initDelay:(CGFloat)initDelay {
#if __IPHONE_OS_VERSION_SOFT_MAX_REQUIRED
    [UIView animateWithDuration:0.5
                          delay:(initDelay + idx*0.1f)
         usingSpringWithDamping:10
          initialSpringVelocity:50
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         view.layer.transform = CATransform3DIdentity;
                         view.alpha = 1;
                     }
                     completion:nil];
#endif
}

- (void)animateFauxBounceWithView:(RNCalloutItemView *)view idx:(NSUInteger)idx initDelay:(CGFloat)initDelay {
    [UIView animateWithDuration:0.2
                          delay:(initDelay + idx*0.1f)
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationCurveEaseInOut
                     animations:^{
                         view.layer.transform = CATransform3DMakeScale(1.1, 1.1, 1);
                         view.alpha = 1;
                     }
                     completion:^(BOOL finished) {
                         [UIView animateWithDuration:0.1 animations:^{
                             view.layer.transform = CATransform3DIdentity;
                         }];
                     }];
}

- (void)showInViewController:(UIViewController *)controller animated:(BOOL)animated {
    if (rn_frostedMenu != nil) {
        [rn_frostedMenu dismissAnimated:NO];
    }
    
    if ([self.delegate respondsToSelector:@selector(sidebar:willShowOnScreenAnimated:)]) {
        [self.delegate sidebar:self willShowOnScreenAnimated:animated];
    }
    
    rn_frostedMenu = self;
    
 
    
    
    [self rn_addToParentViewController:controller callingAppearanceMethods:YES];
    self.view.frame = controller.view.bounds;
    
    CGFloat parentWidth = self.view.bounds.size.width;
    
    CGRect contentFrame = self.view.bounds;
    contentFrame.origin.x = _showFromRight ? parentWidth : -_width;
    contentFrame.size.width = _width;
    self.contentView.frame = contentFrame;
    
    [self layoutItems];
    
    CGRect blurFrame = CGRectMake(_showFromRight ? self.view.bounds.size.width : 0, 0, 0, self.view.bounds.size.height);
    
    CGFloat sidebarWidth = self.width ?: 150.0; // your default sidebar width
    CGRect sidebarFrame;

    if (self.showFromRight) {
        sidebarFrame = CGRectMake(self.view.bounds.size.width - sidebarWidth,
                                  0,
                                  sidebarWidth,
                                  self.view.bounds.size.height);
    } else {
        sidebarFrame = CGRectMake(0, 0, sidebarWidth, self.view.bounds.size.height);
    }

  
    self.modrenBlurView.frame = sidebarFrame;
   
   
   
     
 
    contentFrame.origin.x = _showFromRight ? parentWidth - _width : 0;
    blurFrame.origin.x = contentFrame.origin.x;
    blurFrame.size.width = _width;
    
    void (^animations)() = ^{
        self.contentView.frame = contentFrame;
        self.modrenBlurView.frame = blurFrame;
    };
    void (^completion)(BOOL) = ^(BOOL finished) {
        if (finished && [self.delegate respondsToSelector:@selector(sidebar:didShowOnScreenAnimated:)]) {
            [self.delegate sidebar:self didShowOnScreenAnimated:animated];
        }
    };
    
    if (animated) {
        [UIView animateWithDuration:self.animationDuration
                              delay:0
                            options:kNilOptions
                         animations:animations
                         completion:completion];
    }
    else{
        animations();
        completion(YES);
    }
    
    CGFloat initDelay = 0.1f;
    SEL sdkSpringSelector = NSSelectorFromString(@"animateWithDuration:delay:usingSpringWithDamping:initialSpringVelocity:options:animations:completion:");
    BOOL sdkHasSpringAnimation = [UIView respondsToSelector:sdkSpringSelector];
    
    [self.itemViews enumerateObjectsUsingBlock:^(RNCalloutItemView *view, NSUInteger idx, BOOL *stop) {
        view.layer.transform = CATransform3DMakeScale(0.3, 0.3, 1);
        view.alpha = 0;
        view.originalBackgroundColor = self.itemBackgroundColor;
        view.layer.borderWidth = self.borderWidth;
        
        if (sdkHasSpringAnimation) {
            [self animateSpringWithView:view idx:idx initDelay:initDelay];
        }
        else {
            [self animateFauxBounceWithView:view idx:idx initDelay:initDelay];
        }
    }];
}

- (void)showAnimated:(BOOL)animated {
    UIViewController *controller = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (controller.presentedViewController != nil) {
        controller = controller.presentedViewController;
    }
    [self showInViewController:controller animated:animated];
}

- (void)show {
    [self showAnimated:YES];
}

#pragma mark - Dismiss

- (void)dismiss {
    [self dismissAnimated:YES];
}

- (void)dismissAnimated:(BOOL)animated {
    void (^completion)(BOOL) = ^(BOOL finished){
        [self rn_removeFromParentViewControllerCallingAppearanceMethods:YES];
        
        if ([self.delegate respondsToSelector:@selector(sidebar:didDismissFromScreenAnimated:)]) {
            [self.delegate sidebar:self didDismissFromScreenAnimated:YES];
        }
    };
    
    if ([self.delegate respondsToSelector:@selector(sidebar:willDismissFromScreenAnimated:)]) {
        [self.delegate sidebar:self willDismissFromScreenAnimated:YES];
    }
    
    if (animated) {
        CGFloat parentWidth = self.view.bounds.size.width;
        CGRect contentFrame = self.contentView.frame;
        contentFrame.origin.x = self.showFromRight ? parentWidth : -_width;
        
        CGRect blurFrame = self.modrenBlurView.frame;
        blurFrame.origin.x = self.showFromRight ? parentWidth : 0;
        blurFrame.size.width = 0;
        
        [UIView animateWithDuration:self.animationDuration
                              delay:0
                            options:UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                             self.contentView.frame = contentFrame;
                             self.modrenBlurView.frame = blurFrame;
                         }
                         completion:completion];
    }
    else {
        completion(YES);
    }
}

#pragma mark - Gestures

 - (void)handleTap:(UITapGestureRecognizer *)recognizer {
     CGPoint location = [recognizer locationInView:self.view];
     if (! CGRectContainsPoint(self.contentView.frame, location)) {
         [self dismissAnimated:YES];
     }
     else {
         NSInteger tapIndex = [self indexOfTap:[recognizer locationInView:self.contentView]];
         if (tapIndex != NSNotFound) {
             self.selectedSubKindModel = [self.subKindsArr objectAtIndex:tapIndex];
             [self didTapItemAtIndex:tapIndex];
         }
     }
 }


#pragma mark - Private

- (void)didTapItemAtIndex:(NSUInteger)index {
    BOOL didEnable = ! [self.selectedIndices containsIndex:index];
    
    
    // Deselect all first
       [self.itemViews enumerateObjectsUsingBlock:^(RNCalloutItemView *view, NSUInteger idx, BOOL *stop) {
           [view setHighlighted:(idx == index)];
       }];
       
       // Animation bounce
       RNCalloutItemView *selectedView = self.itemViews[index];
       [UIView animateWithDuration:0.15 animations:^{
           selectedView.transform = CGAffineTransformMakeScale(1.2, 1.2);
       } completion:^(BOOL finished) {
           [UIView animateWithDuration:0.15 animations:^{
               selectedView.transform = CGAffineTransformIdentity;
           }];
       }];
    NSLog(@"didTapItemAtIndex");
          //  [self.delegate sidebar:self didTapItemAtIndex:index];
 
    
    [self.itemViews enumerateObjectsUsingBlock:^(RNCalloutItemView *view, NSUInteger idx, BOOL *stop) {
            if (idx == index) {
                // Highlight tapped item
                [view pp_setBorderColor:AppPrimaryClr];
                view.layer.borderWidth = 1.5;
                
                // ✅ Tap bounce animation
                [UIView animateWithDuration:0.15 animations:^{
                    view.transform = CGAffineTransformMakeScale(1.15, 1.15);
                } completion:^(BOOL finished) {
                    [UIView animateWithDuration:0.15 animations:^{
                        view.transform = CGAffineTransformIdentity;
                    }];
                }];
            } else {
                // Reset others
                [view pp_setBorderColor:[UIColor clearColor]];
                view.layer.borderWidth = 0;
            }
        }];
        
        self.selectedIndex = index;
        
 
  
    
    if ([self.delegate respondsToSelector:@selector(sidebar:didTapItemAtIndex:WithSubKind:)]) {
        [self.delegate sidebar:self  didTapItemAtIndex:index WithSubKind:self.subKindsArr[index]];
    }
    if ([self.delegate respondsToSelector:@selector(sidebar:didTapItemAtIndex:)]) {
        [self.delegate sidebar:self didTapItemAtIndex:index];
    }
    if ([self.delegate respondsToSelector:@selector(sidebar:didEnable:itemAtIndex:)]) {
        [self.delegate sidebar:self didEnable:didEnable itemAtIndex:index];
    }
}

- (void)layoutSubviews {
    CGFloat x = self.showFromRight ? self.parentViewController.view.bounds.size.width - _width : 0;
    self.contentView.frame = CGRectMake(x, 0, _width, self.parentViewController.view.bounds.size.height);
    self.modrenBlurView.frame = self.contentView.frame;
    
    [self layoutItems];
}

- (void)layoutItems {
    CGFloat leftPadding = (self.width - self.itemSize.width)/2;
    CGFloat topPadding = leftPadding;
    [self.itemViews enumerateObjectsUsingBlock:^(RNCalloutItemView *view, NSUInteger idx, BOOL *stop) {
        CGRect frame = CGRectMake(leftPadding, topPadding*idx + self.itemSize.height*idx + topPadding, self.itemSize.width, self.itemSize.height);
        view.frame = frame;
        view.layer.cornerRadius = frame.size.width/2.f;
    }];
    
    NSInteger items = [self.itemViews count];
    self.contentView.contentSize = CGSizeMake(0, items * (self.itemSize.height + leftPadding) + leftPadding);
}

- (NSInteger)indexOfTap:(CGPoint)location {
    __block NSUInteger index = NSNotFound;
    
    [self.itemViews enumerateObjectsUsingBlock:^(UIView *view, NSUInteger idx, BOOL *stop) {
        if (CGRectContainsPoint(view.frame, location)) {
            index = idx;
            *stop = YES;
        }
    }];
    
    return index;
}

- (void)rn_addToParentViewController:(UIViewController *)parentViewController callingAppearanceMethods:(BOOL)callAppearanceMethods {
    if (self.parentViewController != nil) {
        [self rn_removeFromParentViewControllerCallingAppearanceMethods:callAppearanceMethods];
    }
    
    if (callAppearanceMethods) [self beginAppearanceTransition:YES animated:NO];
    [parentViewController addChildViewController:self];
    [parentViewController.view addSubview:self.view];
    [self didMoveToParentViewController:self];
    if (callAppearanceMethods) [self endAppearanceTransition];
}

- (void)rn_removeFromParentViewControllerCallingAppearanceMethods:(BOOL)callAppearanceMethods {
    if (callAppearanceMethods) [self beginAppearanceTransition:NO animated:NO];
    [self willMoveToParentViewController:nil];
    [self.view removeFromSuperview];
    [self removeFromParentViewController];
    if (callAppearanceMethods) [self endAppearanceTransition];
}









/// Modern Frosted Background (iOS 13+ optimized, fallback for legacy)
- (void)applyModernFrostedBackgroundToView:(UIView *)view
                              cornerRadius:(CGFloat)cornerRadius
{
    // Remove old background artifacts if any
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:[UIVisualEffectView class]] || sub.layer.name == @"GradientOverlayLayer") {
            [sub removeFromSuperview];
        }
    }

    if (@available(iOS 26.0, *)) {
        // 🧊 iOS 26+ native frosted glass (Metal blur)
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialLight];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurView.frame = view.bounds;
        blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        blurView.layer.cornerRadius = cornerRadius;
        blurView.layer.masksToBounds = YES;
        [view insertSubview:blurView atIndex:0];
        
        // Add gradient fade overlay
        CAGradientLayer *gradient = [CAGradientLayer layer];
        gradient.frame = view.bounds;
        gradient.name = @"GradientOverlayLayer";
        gradient.colors = @[
            (id)[UIColor colorWithWhite:1.0 alpha:0.15].CGColor,
            (id)[UIColor colorWithWhite:0.0 alpha:0.35].CGColor
        ];
        gradient.startPoint = CGPointMake(0.5, 0.0);
        gradient.endPoint   = CGPointMake(0.5, 1.0);
        gradient.cornerRadius = cornerRadius;
        gradient.masksToBounds = YES;
        [blurView.layer addSublayer:gradient];
    }
    else if (@available(iOS 13.0, *)) {
        // 🍎 Modern fallback for iOS 13–25
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurView.frame = view.bounds;
        blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        blurView.layer.cornerRadius = cornerRadius;
        blurView.layer.masksToBounds = YES;
        [view insertSubview:blurView atIndex:0];
        
        // Add a more subtle gradient fade
        CAGradientLayer *gradient = [CAGradientLayer layer];
        gradient.frame = view.bounds;
        gradient.name = @"GradientOverlayLayer";
        gradient.colors = @[
            (id)[UIColor colorWithWhite:1.0 alpha:0.1].CGColor,
            (id)[UIColor colorWithWhite:0.0 alpha:0.25].CGColor
        ];
        gradient.startPoint = CGPointMake(0.5, 0.0);
        gradient.endPoint   = CGPointMake(0.5, 1.0);
        gradient.cornerRadius = cornerRadius;
        gradient.masksToBounds = YES;
        [blurView.layer addSublayer:gradient];
    }
    else {
        // 🧱 Fallback for older iOS: use static dim gradient
        CAGradientLayer *gradient = [CAGradientLayer layer];
        gradient.frame = view.bounds;
        gradient.colors = @[
            (id)[UIColor colorWithWhite:1.0 alpha:0.15].CGColor,
            (id)[UIColor colorWithWhite:0.0 alpha:0.45].CGColor
        ];
        gradient.startPoint = CGPointMake(0.5, 0.0);
        gradient.endPoint   = CGPointMake(0.5, 1.0);
        gradient.cornerRadius = cornerRadius;
        gradient.masksToBounds = YES;
        [view.layer insertSublayer:gradient atIndex:0];
    }
}




@end
/*
if (self.borderColors) {
    UIColor *stroke = self.borderColors[index];
    UIView *view = self.itemViews[index];
    
    if (didEnable) {
        [view pp_setBorderColor:stroke];
        
        CABasicAnimation *borderAnimation = [CABasicAnimation animationWithKeyPath:@"borderColor"];
        borderAnimation.fromValue = (id)[UIColor clearColor].CGColor;
        borderAnimation.toValue = (id)stroke.CGColor;
        borderAnimation.duration = 0.5f;
        [view.layer addAnimation:borderAnimation forKey:nil];
        
        [self.selectedIndices addIndex:index];
    }
    else {
        [view pp_setBorderColor:[UIColor clearColor]];
        [self.selectedIndices removeIndex:index];
    }
    
    CGRect pathFrame = CGRectMake(-CGRectGetMidX(view.bounds), -CGRectGetMidY(view.bounds), view.bounds.size.width, view.bounds.size.height);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:pathFrame cornerRadius:view.layer.cornerRadius];
    
    // accounts for left/right offset and contentOffset of scroll view
    CGPoint shapePosition = [self.view convertPoint:view.center fromView:self.contentView];
    
    CAShapeLayer *circleShape = [CAShapeLayer layer];
    circleShape.path = path.CGPath;
    circleShape.position = shapePosition;
    circleShape.fillColor = [UIColor clearColor].CGColor;
    circleShape.opacity = 0;
    circleShape.strokeColor = stroke.CGColor;
    circleShape.lineWidth = self.borderWidth;
    
    [self.view.layer addSublayer:circleShape];
    
    CABasicAnimation *scaleAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scaleAnimation.fromValue = [NSValue valueWithCATransform3D:CATransform3DIdentity];
    scaleAnimation.toValue = [NSValue valueWithCATransform3D:CATransform3DMakeScale(2.5, 2.5, 1)];
    
    CABasicAnimation *alphaAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    alphaAnimation.fromValue = @1;
    alphaAnimation.toValue = @0;
    
    CAAnimationGroup *animation = [CAAnimationGroup animation];
    animation.animations = @[scaleAnimation, alphaAnimation];
    animation.duration = 0.5f;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    [circleShape addAnimation:animation forKey:nil];
}
 
 
 
 
 
 
 
 
 
 
 
 
- (void)didTapItemAtIndex:(NSUInteger)index {
    // ✅ Deselect all other items
    [self.itemViews enumerateObjectsUsingBlock:^(RNCalloutItemView *view, NSUInteger idx, BOOL *stop) {
        if (idx == index) {
            // Highlight tapped item
            [view pp_setBorderColor:AppPrimaryClr];
            view.layer.borderWidth = 3.0;
            
            // ✅ Tap bounce animation
            [UIView animateWithDuration:0.15 animations:^{
                view.transform = CGAffineTransformMakeScale(1.15, 1.15);
            } completion:^(BOOL finished) {
                [UIView animateWithDuration:0.15 animations:^{
                    view.transform = CGAffineTransformIdentity;
                }];
            }];
        } else {
            // Reset others
            [view pp_setBorderColor:[UIColor clearColor]];
            view.layer.borderWidth = 0;
        }
    }];
    
    self.selectedIndex = index;
    
    // Delegate callbacks
    if ([self.delegate respondsToSelector:@selector(sidebar:didTapItemAtIndex:)]) {
        [self.delegate sidebar:self didTapItemAtIndex:index];
    }
}
*/

