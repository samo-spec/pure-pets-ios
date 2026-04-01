//
//  PetAdoptView.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 10/08/2025.
//


// PetAdoptView.m
#import "PetAdoptView.h"


@interface PetAdoptView ()
     @property (nonatomic, strong) CAGradientLayer *bgGradientLayer;


@end

@implementation PetAdoptView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        
        float CurrentPPCorners = PPNewCorner;
        //self.contentView.backgroundColor = [UIColor colorWithRed:0.90 green:0.96 blue:1.0 alpha:1.0]; // light blue background
        self.layer.cornerRadius = CurrentPPCorners;
        //self.contentView.layer.masksToBounds = YES;
        
        // 1) Shadow container (no clipping)
        _shadowView = [[UIView alloc] initWithFrame:self.bounds];
        _shadowView.backgroundColor = UIColor.clearColor;
        _shadowView.layer.masksToBounds = NO;
        _shadowView.layer.cornerRadius = CurrentPPCorners;
        [self addSubview:_shadowView];
        
        
        _ContView = [[UIView alloc] initWithFrame:self.bounds];
        _ContView.backgroundColor = GM.AppForegroundColor;
        _ContView.layer.masksToBounds = YES;
        _ContView.layer.cornerRadius = CurrentPPCorners;
       //_ContView.backgroundColor = [UIColor colorWithRed:0.90 green:0.96 blue:1.0 alpha:1.0]; //
        [self addSubview:_ContView];
        
        
        // 3) Gradient behind everything inside cardView
        _bgGradientLayer = [CAGradientLayer layer];
        _bgGradientLayer.cornerRadius = CurrentPPCorners;
        [_ContView.layer insertSublayer:_bgGradientLayer atIndex:0];
        
        
        // Title label
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.font = [GM boldFontWithSize:20];
        _titleLabel.textColor = [UIColor blackColor];
        [self addSubview:_titleLabel];
        
        // Subtitle label
        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.font = [GM fontWithSize:16];
        _subtitleLabel.textColor = [UIColor darkGrayColor];
        _subtitleLabel.numberOfLines = 0;
        [self addSubview:_subtitleLabel];
        
        // Pet image
        _petImageView = [[UIImageView alloc] init];
        _petImageView.contentMode = UIViewContentModeScaleAspectFit;
        
        _petImageView.layer.masksToBounds = NO;
        _petImageView.layer.shadowColor = GM.AppShadowColor.CGColor;
        _petImageView.layer.shadowOffset = CGSizeMake(0, 1);
        _petImageView.layer.shadowOpacity = 0.3;
        _petImageView.layer.shadowRadius = 1;
        _petImageView.hidden = YES;
        _petImageView.backgroundColor = UIColor.clearColor;
        [self addSubview:_petImageView];
        
        
        // Load Lottie animation
        self.lottieHeaderView = [[LOTAnimationView alloc] init]; //[LOTAnimationView animationNamed:@"animaicom"];// paw_waiting_animation deliveryMan
        
        self.lottieHeaderView.contentMode = UIViewContentModeScaleAspectFill;
        self.lottieHeaderView.loopAnimation = YES;
        // Enable user interaction
        // Add tap gesture recognizer
        //UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(cancelTapped)];
        //[self.lottieHeaderView addGestureRecognizer:tap];
        [self addSubview:self.lottieHeaderView];
        
        [AppClasses fetchLottieJSONFromFirebasePath:@"LottieAnimations/WomanPlayingWithCat.json" completion:^(NSDictionary * _Nonnull jsonDict, NSError * _Nonnull error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    NSLog(@"Lottie ADS --- >>> ❌ Failed to fetch Lottie JSON: %@", error.localizedDescription);
                    return;
                }
                if (!jsonDict || ![jsonDict isKindOfClass:[NSDictionary class]]) {
                    NSLog(@"Lottie ADS --- >>> ❌ Invalid or nil JSON dictionary for Lottie");
                    return;
                }
                LOTComposition *composition = [LOTComposition animationFromJSON:jsonDict];
                if (composition) {
                    [self.lottieHeaderView setSceneModel:composition];
                    [self.lottieHeaderView play];
                } else {
                    NSLog(@"Lottie --- >>> ❌ Failed to create LOTComposition from JSON");
                }
            });
        }];
        
        
      
        self.backgroundColor = UIColor.clearColor; // important
    }
    return self;
}


#pragma mark - Shadow only on shadowView
- (void)setupShadow {
    _shadowView.layer.cornerRadius = PPCornersMainCell;
    _shadowView.layer.masksToBounds = NO;
    _shadowView.layer.shadowColor = GM.AppShadowColor.CGColor;
    _shadowView.layer.shadowOffset = CGSizeMake(0, 2);
    _shadowView.layer.shadowOpacity = 0.081;
    _shadowView.layer.shadowRadius = 3;
    _shadowView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:_shadowView.bounds cornerRadius:PPCornersMainCell].CGPath;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    
    _shadowView.frame  = self.bounds;
       _ContView.frame    = _shadowView.bounds;

       // Keep gradient sized + rounded to the container
       _bgGradientLayer.frame = _ContView.bounds;
       _bgGradientLayer.cornerRadius = PPCornersMainCell; // <<< add this
    
    
    CGFloat padding = 12;
    CGFloat imageWidth = self.bounds.size.height - padding * 2;
    imageWidth = imageWidth + 30;
    CGFloat textWidth = self.bounds.size.width - imageWidth - padding * 3;
    CGFloat lottieHeight = self.bounds.size.height + 40;
    //CGFloat ContViewHeight = self.contentView.hx_h / 2;

    
    //self.shadowView.frame = CGRectMake(0, ContViewHeight, self.contentView.hx_w, ContViewHeight);
    
    //_shadowView.layer.cornerRadius = ContViewHeight/2;
    //_ContView.layer.cornerRadius = ContViewHeight/2;
    
    
    if (Language.languageVal == 0) {
        // LTR: Image on the right, text on the left
        self.petImageView.frame = CGRectMake(self.bounds.size.width - imageWidth - padding,
                                             -5,imageWidth ,
                                             imageWidth );
        
        self.lottieHeaderView.frame = CGRectMake(self.bounds.size.width - lottieHeight , -20, lottieHeight,  lottieHeight );

        
        self.titleLabel.frame = CGRectMake(padding,
                                           padding + 10,
                                           textWidth,
                                           22);
        
        self.subtitleLabel.frame = CGRectMake(padding,
                                              CGRectGetMaxY(self.titleLabel.frame) + 4,
                                              textWidth,
                                              self.bounds.size.height - CGRectGetMaxY(self.titleLabel.frame) - padding - 4);
        
        self.titleLabel.textAlignment = NSTextAlignmentLeft;
        self.subtitleLabel.textAlignment = NSTextAlignmentLeft;
    } else {
        // RTL: Image on the left, text on the right
        self.petImageView.frame = CGRectMake(padding,
                                             -5,
                                             imageWidth,
                                             imageWidth );
        
        self.lottieHeaderView.frame = CGRectMake(0 ,-20, lottieHeight,  lottieHeight);
        
        self.titleLabel.frame = CGRectMake(CGRectGetMaxX(self.petImageView.frame) + padding,
                                           padding  + 10,
                                           textWidth,
                                           22);
        
        self.subtitleLabel.frame = CGRectMake(CGRectGetMaxX(self.petImageView.frame) + padding,
                                              CGRectGetMaxY(self.titleLabel.frame) + 4,
                                              textWidth,
                                              self.bounds.size.height - CGRectGetMaxY(self.titleLabel.frame) - padding - 4);
        
        self.titleLabel.textAlignment = NSTextAlignmentRight;
        self.subtitleLabel.textAlignment = NSTextAlignmentRight;
    }
    
    
    
    [self setupShadow];
}

#pragma mark - Gradient setter (works with shadow)
- (void)setBackgroundGradientFrom:(UIColor *)startColor
                               to:(UIColor *)endColor
                            angle:(CGFloat)degrees
{
    _bgGradientLayer.colors = @[(__bridge id)startColor.CGColor,
                                (__bridge id)endColor.CGColor];
    _bgGradientLayer.locations = @[@0.0, @1.0];

    CGFloat theta = degrees * (CGFloat)M_PI / 180.0;
    CGPoint start = CGPointMake(0.5 - 0.5 * cos(theta), 0.5 - 0.5 * sin(theta));
    CGPoint end   = CGPointMake(0.5 + 0.5 * cos(theta), 0.5 + 0.5 * sin(theta));
    _bgGradientLayer.startPoint = start;
    _bgGradientLayer.endPoint   = end;
}



- (UIColor *)pastel:(CGFloat)brightness { // brightness ~0.9 looks airy
    CGFloat h = arc4random_uniform(256)/255.0;
    CGFloat s = 0.20 + arc4random_uniform(30)/255.0; // 0.20–0.32
    return [UIColor colorWithHue:h saturation:s brightness:brightness alpha:1];
}
- (NSArray<UIColor *> *)extractTwoMainColorsFromImage:(UIImage *)image andLightenAmount:(float)amount {
    if (!image) return @[[UIColor colorWithWhite:1 alpha:0.1], [UIColor colorWithWhite:0.95 alpha:0.1]];
    
    // Downscale for speed
    CGSize thumbSize = CGSizeMake(20, 20);
    UIGraphicsBeginImageContext(thumbSize);
    [image drawInRect:CGRectMake(0, 0, thumbSize.width, thumbSize.height)];
    UIImage *thumbImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    CGImageRef cgImage = thumbImage.CGImage;
    NSUInteger width = CGImageGetWidth(cgImage);
    NSUInteger height = CGImageGetHeight(cgImage);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char *rawData = (unsigned char*) calloc(height * width * 4, sizeof(unsigned char));
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    CGContextRef context = CGBitmapContextCreate(rawData, width, height,
                                                 bitsPerComponent, bytesPerRow, colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);
    CGContextRelease(context);
    
    NSMutableDictionary<NSString *, NSNumber *> *colorCounts = [NSMutableDictionary dictionary];
    
    for (NSUInteger y = 0; y < height; y++) {
        for (NSUInteger x = 0; x < width; x++) {
            NSUInteger byteIndex = (bytesPerRow * y) + x * bytesPerPixel;
            CGFloat r = rawData[byteIndex] / 255.0;
            CGFloat g = rawData[byteIndex + 1] / 255.0;
            CGFloat b = rawData[byteIndex + 2] / 255.0;
            
            // Brightness filter — skip very dark colors
            CGFloat brightness = (r + g + b) / 3.0;
            if (brightness < 0.3) continue; // exclude dark shades
            
            // Quantize to reduce small variations
            int qr = (int)(r * 10);
            int qg = (int)(g * 10);
            int qb = (int)(b * 10);
            
            NSString *key = [NSString stringWithFormat:@"%d_%d_%d", qr, qg, qb];
            NSNumber *count = colorCounts[key] ?: @0;
            colorCounts[key] = @(count.integerValue + 1);
        }
    }
    free(rawData);
    
    NSArray *sortedKeys = [colorCounts keysSortedByValueUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj2 compare:obj1];
    }];
    
    NSMutableArray<UIColor *> *colors = [NSMutableArray array];
    for (NSString *key in sortedKeys) {
        NSArray *parts = [key componentsSeparatedByString:@"_"];
        CGFloat r = [parts[0] intValue] / 10.0;
        CGFloat g = [parts[1] intValue] / 10.0;
        CGFloat b = [parts[2] intValue] / 10.0;
        
        UIColor *color = [UIColor colorWithRed:r green:g blue:b alpha:0.9]; // softer alpha
        [colors addObject:[self lightenColor:color amount:amount]]; // pastel effect
        
        if (colors.count >= 2) break;
    }
    
    if (colors.count < 2) {
        return @[[UIColor colorWithWhite:1 alpha:0.6], [UIColor colorWithWhite:0.95 alpha:0.6]];
    }
    
    return colors;
}

- (UIColor *)lightenColor:(UIColor *)color amount:(CGFloat)amount {
    CGFloat r, g, b, a;
    if ([color getRed:&r green:&g blue:&b alpha:&a]) {
        return [UIColor colorWithRed:MIN(r + amount, 1.0)
                               green:MIN(g + amount, 1.0)
                                blue:MIN(b + amount, 1.0)
                               alpha:a];
    }
    return color;
}


@end
