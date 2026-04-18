//
//  PetAdoptView.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 10/08/2025.
//


// PetAdoptView.m
#import "PetAdoptView.h"

static inline CGFloat PPPetAdoptResolvedWidth(CGFloat width)
{
    return width > 0.0 ? width : UIScreen.mainScreen.bounds.size.width;
}

static inline BOOL PPPetAdoptIsTablet(CGFloat width)
{
    return PPPetAdoptResolvedWidth(width) >= 768.0;
}

static inline BOOL PPPetAdoptIsWidePhone(CGFloat width)
{
    width = PPPetAdoptResolvedWidth(width);
    return width >= 430.0 && width < 768.0;
}

static inline BOOL PPPetAdoptIsCompactPhone(CGFloat width)
{
    return PPPetAdoptResolvedWidth(width) <= 360.0;
}

@interface PetAdoptView ()
@property (nonatomic, strong) CAGradientLayer *bgGradientLayer;
@end

@implementation PetAdoptView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {

        float CurrentPPCorners = PPNewCorner;
        self.layer.cornerRadius = CurrentPPCorners;

        _shadowView = [[UIView alloc] initWithFrame:self.bounds];
        _shadowView.backgroundColor = UIColor.clearColor;
        _shadowView.layer.masksToBounds = NO;
        _shadowView.layer.cornerRadius = CurrentPPCorners;
        [self addSubview:_shadowView];

        _ContView = [[UIView alloc] initWithFrame:self.bounds];
        _ContView.backgroundColor = GM.AppForegroundColor;
        _ContView.layer.masksToBounds = YES;
        _ContView.layer.cornerRadius = CurrentPPCorners;
        [self addSubview:_ContView];

        _bgGradientLayer = [CAGradientLayer layer];
        _bgGradientLayer.cornerRadius = CurrentPPCorners;
        [_ContView.layer insertSublayer:_bgGradientLayer atIndex:0];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.font = [GM boldFontWithSize:20];
        _titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
        _titleLabel.adjustsFontSizeToFitWidth = YES;
        _titleLabel.minimumScaleFactor = 0.82;
        _titleLabel.numberOfLines = 1;
        [self addSubview:_titleLabel];

        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.font = [GM fontWithSize:16];
        _subtitleLabel.textColor = UIColor.secondaryLabelColor;
        _subtitleLabel.numberOfLines = 0;
        _subtitleLabel.adjustsFontSizeToFitWidth = YES;
        _subtitleLabel.minimumScaleFactor = 0.90;
        [self addSubview:_subtitleLabel];

        _petImageView = [[UIImageView alloc] init];
        _petImageView.contentMode = UIViewContentModeScaleAspectFit;
        _petImageView.layer.masksToBounds = NO;
        [_petImageView pp_setShadowColor:GM.AppShadowColor];
        _petImageView.layer.shadowOffset = CGSizeMake(0, 1);
        _petImageView.layer.shadowOpacity = 0.3;
        _petImageView.layer.shadowRadius = 1;
        _petImageView.hidden = YES;
        _petImageView.backgroundColor = UIColor.clearColor;
        [self addSubview:_petImageView];

        self.lottieHeaderView = [[LOTAnimationView alloc] init];
        self.lottieHeaderView.contentMode = UIViewContentModeScaleAspectFill;
        self.lottieHeaderView.loopAnimation = YES;
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

        self.backgroundColor = UIColor.clearColor;
    }
    return self;
}


#pragma mark - Shadow only on shadowView
- (void)setupShadow {
    _shadowView.layer.cornerRadius = PPCornersMainCell;
    _shadowView.layer.masksToBounds = NO;
    [_shadowView pp_setShadowColor:GM.AppShadowColor];
    _shadowView.layer.shadowOffset = CGSizeMake(0, 2);
    _shadowView.layer.shadowOpacity = 0.081;
    _shadowView.layer.shadowRadius = 3;
    _shadowView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:_shadowView.bounds cornerRadius:PPCornersMainCell].CGPath;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    _shadowView.frame = self.bounds;
    _ContView.frame = _shadowView.bounds;
    _bgGradientLayer.frame = _ContView.bounds;
    _bgGradientLayer.cornerRadius = PPCornersMainCell;

    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    if (width <= 0.0 || height <= 0.0) {
        return;
    }

    CGFloat padding = PPPetAdoptIsTablet(width) ? 22.0 : (PPPetAdoptIsCompactPhone(width) ? 12.0 : 16.0);
    CGFloat minTextWidth = PPPetAdoptIsTablet(width) ? 240.0 : (PPPetAdoptIsCompactPhone(width) ? 118.0 : 140.0);
    CGFloat maxImageWidth = PPPetAdoptIsTablet(width) ? MIN(width * 0.38, 260.0) : MIN(width * 0.44, height + 20.0);
    CGFloat imageWidth = MAX(108.0, MIN(maxImageWidth, width - (padding * 3.0) - minTextWidth));
    CGFloat imageY = floor((height - imageWidth) * 0.5) - 2.0;
    CGFloat textWidth = MAX(minTextWidth, width - imageWidth - (padding * 3.0));
    CGFloat lottieSize = PPPetAdoptIsTablet(width) ? MIN(height + 24.0, 238.0) : MIN(height + 18.0, 214.0);
    CGFloat lottieY = -MIN(18.0, height * 0.12);
    CGFloat titleSize = PPPetAdoptIsTablet(width) ? 24.0 : (PPPetAdoptIsWidePhone(width) ? 22.0 : (PPPetAdoptIsCompactPhone(width) ? 17.0 : 20.0));
    CGFloat subtitleSize = PPPetAdoptIsTablet(width) ? 17.0 : (PPPetAdoptIsCompactPhone(width) ? 14.0 : 15.0);

    self.titleLabel.font = [GM boldFontWithSize:titleSize];
    self.subtitleLabel.font = [GM fontWithSize:subtitleSize];

    if (Language.languageVal == 0) {
        self.petImageView.frame = CGRectMake(width - imageWidth - padding,
                                             imageY,
                                             imageWidth,
                                             imageWidth);

        self.lottieHeaderView.frame = CGRectMake(width - lottieSize + (padding * 0.25),
                                                 lottieY,
                                                 lottieSize,
                                                 lottieSize);

        self.titleLabel.frame = CGRectMake(padding,
                                           padding + 8.0,
                                           textWidth,
                                           ceil(self.titleLabel.font.lineHeight));

        CGFloat subtitleY = CGRectGetMaxY(self.titleLabel.frame) + 6.0;
        self.subtitleLabel.frame = CGRectMake(padding,
                                              subtitleY,
                                              textWidth,
                                              MAX(0.0, height - subtitleY - padding));

        self.titleLabel.textAlignment = NSTextAlignmentLeft;
        self.subtitleLabel.textAlignment = NSTextAlignmentLeft;
    } else {
        self.petImageView.frame = CGRectMake(padding,
                                             imageY,
                                             imageWidth,
                                             imageWidth);

        self.lottieHeaderView.frame = CGRectMake(-padding * 0.25,
                                                 lottieY,
                                                 lottieSize,
                                                 lottieSize);

        self.titleLabel.frame = CGRectMake(CGRectGetMaxX(self.petImageView.frame) + padding,
                                           padding + 8.0,
                                           textWidth,
                                           ceil(self.titleLabel.font.lineHeight));

        CGFloat subtitleY = CGRectGetMaxY(self.titleLabel.frame) + 6.0;
        self.subtitleLabel.frame = CGRectMake(CGRectGetMaxX(self.petImageView.frame) + padding,
                                              subtitleY,
                                              textWidth,
                                              MAX(0.0, height - subtitleY - padding));

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
    CGPoint end = CGPointMake(0.5 + 0.5 * cos(theta), 0.5 + 0.5 * sin(theta));
    _bgGradientLayer.startPoint = start;
    _bgGradientLayer.endPoint = end;
}



- (UIColor *)pastel:(CGFloat)brightness {
    CGFloat h = arc4random_uniform(256) / 255.0;
    CGFloat s = 0.20 + arc4random_uniform(30) / 255.0;
    return [UIColor colorWithHue:h saturation:s brightness:brightness alpha:1];
}

- (NSArray<UIColor *> *)extractTwoMainColorsFromImage:(UIImage *)image andLightenAmount:(float)amount {
    if (!image) return @[[UIColor colorWithWhite:1 alpha:0.1], [UIColor colorWithWhite:0.95 alpha:0.1]];

    CGSize thumbSize = CGSizeMake(20, 20);
    UIGraphicsBeginImageContext(thumbSize);
    [image drawInRect:CGRectMake(0, 0, thumbSize.width, thumbSize.height)];
    UIImage *thumbImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    CGImageRef cgImage = thumbImage.CGImage;
    NSUInteger width = CGImageGetWidth(cgImage);
    NSUInteger height = CGImageGetHeight(cgImage);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char *rawData = (unsigned char *)calloc(height * width * 4, sizeof(unsigned char));
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

            CGFloat brightness = (r + g + b) / 3.0;
            if (brightness < 0.3) continue;

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

        UIColor *color = [UIColor colorWithRed:r green:g blue:b alpha:0.9];
        [colors addObject:[self lightenColor:color amount:amount]];

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
