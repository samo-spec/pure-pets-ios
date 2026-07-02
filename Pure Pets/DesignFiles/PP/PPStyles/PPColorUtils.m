//
//  PPColorUtils.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 09/09/2025.
//



#import "PPColorUtils.h"

@import FirebaseFirestore;

@implementation PPColorUtils

static NSCache<NSString *, NSArray<UIColor *> *> *_colorCache;
static dispatch_queue_t _colorQueue;

+ (void)initialize {
    if (self == [PPColorUtils class]) {
        _colorCache = [NSCache new];
        _colorCache.countLimit = 150; // safe for scrolling lists
        _colorQueue = dispatch_queue_create("com.purepets.imageColorQueue",
                                            DISPATCH_QUEUE_CONCURRENT);
    }
}


+ (UIColor *)pp_averageColorFromImage:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

    unsigned char rgba[4];
    CGContextRef context =
        CGBitmapContextCreate(rgba,
                              1, 1,
                              8, 4,
                              colorSpace,
                              (CGBitmapInfo)kCGBitmapByteOrder32Big | (CGBitmapInfo)kCGImageAlphaPremultipliedLast);

    CGContextDrawImage(context,
                       CGRectMake(0, 0, 1, 1),
                       image.CGImage);

    CGColorSpaceRelease(colorSpace);
    CGContextRelease(context);

    return [UIColor colorWithRed:rgba[0] / 255.0
                           green:rgba[1] / 255.0
                            blue:rgba[2] / 255.0
                           alpha:1.0];
}

#pragma mark - Public

+ (void)extractGradientColorsAsyncFromImage:(UIImage *)image
                             lightenAmount:(CGFloat)lightenAmount
                                 completion:(PPColorUtilsCompletion)completion
{
    if (!image) {
        if (completion) completion(@[]);
        return;
    }

    NSString *hashKey = [self imageHash:image];

    NSArray *cached = [_colorCache objectForKey:hashKey];
    if (cached) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(cached);
        });
        return;
    }

    dispatch_async(_colorQueue, ^{
        NSArray *colors =
        [self extractGradientColorsSync:image lightenAmount:lightenAmount];

        if (colors.count) {
            [_colorCache setObject:colors forKey:hashKey];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            completion(colors);
        });
    });
}

+ (void)clearCache {
    [_colorCache removeAllObjects];
}

#pragma mark - Core Extraction (SYNC / PRIVATE)

+ (NSArray<UIColor *> *)extractGradientColorsSync:(UIImage *)image
                                   lightenAmount:(CGFloat)amount
{
    CGSize size = CGSizeMake(20, 20);
    UIGraphicsBeginImageContextWithOptions(size, YES, 0);
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *thumb = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    CGImageRef cgImage = thumb.CGImage;
    NSUInteger width = CGImageGetWidth(cgImage);
    NSUInteger height = CGImageGetHeight(cgImage);

    unsigned char *data = calloc(width * height * 4, sizeof(unsigned char));
    CGContextRef ctx =
    CGBitmapContextCreate(data, width, height, 8,
                          width * 4,
                          CGColorSpaceCreateDeviceRGB(),
                          kCGImageAlphaPremultipliedLast);

    CGContextDrawImage(ctx, CGRectMake(0, 0, width, height), cgImage);
    CGContextRelease(ctx);

    NSMutableDictionary<NSString *, NSNumber *> *histogram = [NSMutableDictionary dictionary];

    for (NSUInteger i = 0; i < width * height; i++) {
        CGFloat r = data[i * 4]     / 255.0;
        CGFloat g = data[i * 4 + 1] / 255.0;
        CGFloat b = data[i * 4 + 2] / 255.0;

        if ((r + g + b) / 3.0 < 0.3) continue;

        int qr = (int)(r * 10);
        int qg = (int)(g * 10);
        int qb = (int)(b * 10);

        NSString *key =
        [NSString stringWithFormat:@"%d_%d_%d", qr, qg, qb];

        histogram[key] = @([histogram[key] integerValue] + 1);
    }

    free(data);

    NSArray *sorted =
    [histogram keysSortedByValueUsingComparator:^NSComparisonResult(id a, id b) {
        return [b compare:a];
    }];

    NSMutableArray<UIColor *> *colors = [NSMutableArray array];

    for (NSString *key in sorted) {
        NSArray *c = [key componentsSeparatedByString:@"_"];
        UIColor *color =
        [UIColor colorWithRed:[c[0] intValue]/10.0
                         green:[c[1] intValue]/10.0
                          blue:[c[2] intValue]/10.0
                         alpha:1.0];

        [colors addObject:[self lightenColor:color amount:amount]];
        if (colors.count >= 5) break;
    }

    if (colors.count < 3) {
        return @[
            [UIColor colorWithWhite:1 alpha:0.6],
            [UIColor colorWithWhite:0.95 alpha:0.6],
            [UIColor colorWithWhite:0.9 alpha:0.6]
        ];
    }

    return @[ colors.firstObject,
              colors[colors.count / 2],
              colors.lastObject ];
}

#pragma mark - Helpers

+ (UIColor *)blendColor:(UIColor *)color
              withColor:(UIColor *)background
                 factor:(CGFloat)factor
{
    factor = MAX(0.0, MIN(1.0, factor));

    CGFloat r1, g1, b1, a1;
    CGFloat r2, g2, b2, a2;

    if (![color getRed:&r1 green:&g1 blue:&b1 alpha:&a1]) {
        return background;
    }
    if (![background getRed:&r2 green:&g2 blue:&b2 alpha:&a2]) {
        return color;
    }

    CGFloat r = r1 * factor + r2 * (1.0 - factor);
    CGFloat g = g1 * factor + g2 * (1.0 - factor);
    CGFloat b = b1 * factor + b2 * (1.0 - factor);
    CGFloat a = a1 * factor + a2 * (1.0 - factor);

    return [UIColor colorWithRed:r green:g blue:b alpha:a];
}


+ (NSDictionary *)serializeColor:(UIColor *)color
{
    CGFloat r, g, b, a;
    if (![color getRed:&r green:&g blue:&b alpha:&a]) return nil;

    return @{
        @"r": @(r),
        @"g": @(g),
        @"b": @(b),
        @"a": @(a)
    };
}

+ (UIColor *)colorFromSerialized:(NSDictionary *)dict
{
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;

    NSNumber *r = dict[@"r"];
    NSNumber *g = dict[@"g"];
    NSNumber *b = dict[@"b"];
    NSNumber *a = dict[@"a"];

    if (!r || !g || !b) return nil;

    return [UIColor colorWithRed:r.floatValue
                           green:g.floatValue
                            blue:b.floatValue
                           alpha:a ? a.floatValue : 1.0];
}

+ (UIColor *)lightenColor:(UIColor *)color amount:(CGFloat)amount {
    CGFloat r, g, b, a;
    if ([color getRed:&r green:&g blue:&b alpha:&a]) {
        return [UIColor colorWithRed:MIN(r + amount, 1)
                               green:MIN(g + amount, 1)
                                blue:MIN(b + amount, 1)
                               alpha:a];
    }
    return color;
}

+ (NSString *)imageHash:(UIImage *)image {
    NSData *data = UIImagePNGRepresentation(image);
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(data.bytes, (CC_LONG)data.length, digest);

    NSMutableString *hash = [NSMutableString string];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [hash appendFormat:@"%02x", digest[i]];
    }
    return hash;
}



#pragma mark - Singleton

+ (instancetype)shared {
    static PPColorUtils *tool;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        tool = [[self alloc] init];
    });
    return tool;
}

#pragma mark - Public API

+ (NSArray<UIColor *> *)extractDominantColorsFromImage:(UIImage *)image
                                             maxColors:(NSInteger)maxColors
                                         lightenAmount:(CGFloat)lightenAmount
{
    if (!image || maxColors <= 0) {
        return @[];
    }

    // Downscale for performance
    CGSize thumbSize = CGSizeMake(20, 20);
    UIGraphicsBeginImageContextWithOptions(thumbSize, YES, 0);
    [image drawInRect:CGRectMake(0, 0, thumbSize.width, thumbSize.height)];
    UIImage *thumb = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    CGImageRef cgImage = thumb.CGImage;
    NSUInteger width = CGImageGetWidth(cgImage);
    NSUInteger height = CGImageGetHeight(cgImage);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char *rawData = calloc(width * height * 4, sizeof(unsigned char));

    CGContextRef ctx = CGBitmapContextCreate(
        rawData,
        width,
        height,
        8,
        width * 4,
        colorSpace,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big
    );

    CGColorSpaceRelease(colorSpace);
    CGContextDrawImage(ctx, CGRectMake(0, 0, width, height), cgImage);
    CGContextRelease(ctx);

    NSMutableDictionary<NSString *, NSNumber *> *colorHistogram = [NSMutableDictionary dictionary];

    for (NSUInteger y = 0; y < height; y++) {
        for (NSUInteger x = 0; x < width; x++) {

            NSUInteger index = (y * width + x) * 4;
            CGFloat r = rawData[index]     / 255.0;
            CGFloat g = rawData[index + 1] / 255.0;
            CGFloat b = rawData[index + 2] / 255.0;

            // Skip very dark pixels
            if ((r + g + b) / 3.0 < 0.3) continue;

            // Quantize
            NSInteger qr = (NSInteger)(r * 10);
            NSInteger qg = (NSInteger)(g * 10);
            NSInteger qb = (NSInteger)(b * 10);

            NSString *key = [NSString stringWithFormat:@"%ld_%ld_%ld",
                             (long)qr, (long)qg, (long)qb];

            colorHistogram[key] =
            @([colorHistogram[key] integerValue] + 1);
        }
    }

    free(rawData);

    NSArray *sortedKeys =
    [colorHistogram keysSortedByValueUsingComparator:^NSComparisonResult(id a, id b) {
        return [b compare:a];
    }];

    NSMutableArray<UIColor *> *result = [NSMutableArray array];

    for (NSString *key in sortedKeys) {
        NSArray *parts = [key componentsSeparatedByString:@"_"];
        CGFloat r = [parts[0] integerValue] / 10.0;
        CGFloat g = [parts[1] integerValue] / 10.0;
        CGFloat b = [parts[2] integerValue] / 10.0;

        UIColor *color =
        [UIColor colorWithRed:r green:g blue:b alpha:1.0];

        [result addObject:[self lightenColor:color amount:lightenAmount]];

        if (result.count >= maxColors) break;
    }

    return result.count ? result : @[
        [UIColor colorWithWhite:1.0 alpha:0.6],
        [UIColor colorWithWhite:0.95 alpha:0.6]
    ];
}

+ (NSArray<UIColor *> *)extractGradientColorsFromImage:(UIImage *)image
                                        lightenAmount:(CGFloat)lightenAmount
{
    NSArray *colors =
    [self extractDominantColorsFromImage:image
                               maxColors:5
                           lightenAmount:lightenAmount];

    if (colors.count >= 3) {
        return @[ colors.firstObject,
                  colors[colors.count / 2],
                  colors.lastObject ];
    }

    return colors;
}



#pragma mark - Init

- (instancetype)init {
    self = [super init];
    if (self) {
        // Create gradient layer once
        _bgGradientLayer = [CAGradientLayer layer];
    }
    return self;
}

#pragma mark - Gradient setter (works with shadow)

- (void)setBackgroundGradientFrom:(UIColor *)startColor
                               to:(UIColor *)endColor
                            angle:(CGFloat)degrees
                            onView:(UIView *)view
{
    if (!view) return;

    _bgGradientLayer.frame = view.bounds;
    _bgGradientLayer.cornerRadius = view.layer.cornerRadius; // keep same radius as view
    _bgGradientLayer.colors = @[(__bridge id)startColor.CGColor,
                                (__bridge id)endColor.CGColor];
    _bgGradientLayer.locations = @[@0.0, @1.0];

    CGFloat theta = degrees * (CGFloat)M_PI / 180.0;
    CGPoint start = CGPointMake(0.5 - 0.5 * cos(theta), 0.5 - 0.5 * sin(theta));
    CGPoint end   = CGPointMake(0.5 + 0.5 * cos(theta), 0.5 + 0.5 * sin(theta));
    _bgGradientLayer.startPoint = start;
    _bgGradientLayer.endPoint   = end;
    
    if (_bgGradientLayer.superlayer != view.layer) {
        [view.layer insertSublayer:_bgGradientLayer atIndex:0];
    }
}

#pragma mark - Pastel helper

- (UIColor *)pastel:(CGFloat)brightness { // brightness ~0.9 looks airy
    CGFloat h = arc4random_uniform(256)/255.0;
    CGFloat s = 0.20 + arc4random_uniform(30)/255.0; // 0.20–0.32
    return [UIColor colorWithHue:h saturation:s brightness:brightness alpha:1];
}

#pragma mark - Extract colors

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
        
        if (colors.count >= 5) break;
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


+ (UIImageSymbolConfiguration *)imageConfig:(CGFloat)pointSize
                 weight:(UIImageSymbolWeight)weight
                  scale:(UIImageSymbolScale)scale
                palette:(NSArray<UIColor *> * _Nullable)palette
           fallbackTint:(UIColor * _Nullable)fallbackTint
         renderOriginal:(BOOL)original
{

    UIImageSymbolConfiguration *cfg;
    // Build symbol configuration (size/weight/scale)
    if (@available(iOS 13.0, *)) {
        cfg = [UIImageSymbolConfiguration configurationWithPointSize:pointSize
                                                            weight:weight
                                                             scale:scale];
    }

    // Apply palette when supported (iOS 15+). If not, fallbackTint if provided.
    if (@available(iOS 15.0, *)) {
        if (palette.count > 0) {
            cfg  = [UIImageSymbolConfiguration configurationWithPaletteColors:palette];
        }
    } else if (fallbackTint) {
        cfg  = [UIImageSymbolConfiguration configurationWithPaletteColors:@[AppPrimaryClr]];
    }

    return cfg;
}


+ (UIImage *)imageNamed:(NSString *)name
              pointSize:(CGFloat)pointSize
                 weight:(UIImageSymbolWeight)weight
                  scale:(UIImageSymbolScale)scale
                palette:(NSArray<UIColor *> * _Nullable)palette
           fallbackTint:(UIColor * _Nullable)fallbackTint
         renderOriginal:(BOOL)original
{
    NSString *safeName = [name isKindOfClass:NSString.class]
        ? [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
        : @"";
    if (safeName.length == 0) {
        return nil;
    }

    UIImage *base = nil;

    // Prefer SF Symbols if available
    if (@available(iOS 13.0, *)) {
        base = [UIImage systemImageNamed:safeName];
    }
    // Fallback to asset catalog
    if (!base) {
        base = [UIImage imageNamed:safeName];
        if (!base) { return nil; }
    }

    // Build symbol configuration (size/weight/scale)
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg =
            [UIImageSymbolConfiguration configurationWithPointSize:pointSize
                                                            weight:weight
                                                             scale:scale];
        base = [base imageByApplyingSymbolConfiguration:cfg];
    }

    // Apply palette when supported (iOS 15+). If not, fallbackTint if provided.
    if (@available(iOS 15.0, *)) {
        if (palette.count > 0) {
            UIImageSymbolConfiguration *paletteCfg =
                [UIImageSymbolConfiguration configurationWithPaletteColors:palette];
            base = [base imageByApplyingSymbolConfiguration:paletteCfg];
        } else if (fallbackTint) {
            base = [base imageWithTintColor:fallbackTint renderingMode:UIImageRenderingModeAlwaysOriginal];
        }
    } else if (fallbackTint) {
        base = [base imageWithTintColor:fallbackTint];
    }

    // Rendering mode preference
    base = [base imageWithRenderingMode:(original ? UIImageRenderingModeAlwaysOriginal
                                                  : UIImageRenderingModeAlwaysTemplate)];
    return base;
}

+ (void)applyGradientFromImage:(UIImageView *)imageView
                        toView:(UIView *)targetView
             withToneAdjustment:(PPColorToneAdjustment)adjustment
                        degree:(CGFloat)degree {

    UIColor *baseColor = [self dominantColorFromImage:imageView.image];
    if (!baseColor) return;

    UIColor *startColor = [self adjustColor:baseColor tone:adjustment intensity:0.2];
    UIColor *endColor = [self adjustColor:baseColor tone:adjustment intensity:0.05];

    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    gradientLayer.frame = targetView.bounds;
    gradientLayer.colors = @[(__bridge id)startColor.CGColor,
                             (__bridge id)endColor.CGColor];

    // Convert degree to startPoint and endPoint
    CGFloat radians = degree * M_PI / 360.0;
    CGFloat x = cos(radians);
    CGFloat y = sin(radians);
    gradientLayer.startPoint = CGPointMake(0.5 - x / 2.0, 0.5 - y / 2.0);
    gradientLayer.endPoint   = CGPointMake(0.5 + x / 2.0, 0.5 + y / 2.0);

    // Clean existing gradients
    for (CALayer *layer in targetView.layer.sublayers.copy) {
        if ([layer isKindOfClass:[CAGradientLayer class]]) {
            [layer removeFromSuperlayer];
        }
    }

    [targetView.layer insertSublayer:gradientLayer atIndex:0];
}

// Extract dominant color using CIFilter
+ (UIColor *)dominantColorFromImage:(UIImage *)image {
    if (!image) return nil;

    CIImage *ciImage = [[CIImage alloc] initWithImage:image];
    CIFilter *filter = [CIFilter filterWithName:@"CIAreaAverage"
                                  keysAndValues: kCIInputImageKey, ciImage,
                        kCIInputExtentKey, [CIVector vectorWithCGRect:ciImage.extent], nil];

    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef outputImage = [context createCGImage:filter.outputImage fromRect:CGRectMake(0, 0, 1, 1)];

    unsigned char pixel[4] = {0};
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = (CGBitmapInfo)kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big;
    CGContextRef bitmap = CGBitmapContextCreate(pixel, 1, 1, 8, 4, rgb, bitmapInfo);
    CGColorSpaceRelease(rgb);

    CGContextDrawImage(bitmap, CGRectMake(0, 0, 1, 1), outputImage);
    CGContextRelease(bitmap);
    CGImageRelease(outputImage);

    return [UIColor colorWithRed:pixel[0] / 255.0
                           green:pixel[1] / 255.0
                            blue:pixel[2] / 255.0
                           alpha:1.0];
}

// Lighten or darken color
+ (UIColor *)adjustColor:(UIColor *)color tone:(PPColorToneAdjustment)tone intensity:(CGFloat)intensity {
    CGFloat h, s, b, a;
    if (![color getHue:&h saturation:&s brightness:&b alpha:&a]) {
        return color;
    }

    switch (tone) {
        case PPColorToneAdjustmentLighten:
            b = MIN(b + intensity, 1.0);
            break;
        case PPColorToneAdjustmentDarken:
            b = MAX(b - intensity, 0.0);
            break;
        default:
            break;
    }

    return [UIColor colorWithHue:h saturation:s brightness:b alpha:a];
}




+ (UIButton *)buttonWithSymbolName:(NSString *)name
                         pointSize:(CGFloat)pointSize
                            weight:(UIImageSymbolWeight)weight
                             scale:(UIImageSymbolScale)scale
                           palette:(NSArray<UIColor *> * _Nullable)palette
                      fallbackTint:(UIColor * _Nullable)fallbackTint
                    renderOriginal:(BOOL)original
                            target:(id)target
                            action:(SEL)action
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;

    UIImage *symbolImage = [PPColorUtils imageNamed:name
                                             pointSize:pointSize
                                                weight:weight
                                                 scale:scale
                                               palette:palette
                                          fallbackTint:fallbackTint
                                        renderOriginal:original];

    [button setImage:symbolImage forState:UIControlStateNormal];

    if (target && action) {
        [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    }

    // Optional: standardize appearance
    button.imageView.contentMode = UIViewContentModeScaleAspectFit;
    button.tintColor = fallbackTint ?: [UIColor systemBlueColor];

    return button;
}


+ (void)setSymImage:(NSString *)image  toButton:(UIButton *)button
{
    UIImage *img =
    [PPColorUtils imageNamed:image
                      pointSize:20
                         weight:UIImageSymbolWeightRegular
                          scale:UIImageSymbolScaleLarge
                        palette:@[AppPrimaryClr, UIColor.darkGrayColor]
                   fallbackTint:AppPrimaryClr
                 renderOriginal:NO];

    // Example: set on an image view
    [button setImage:img forState:UIControlStateNormal];
}


+ (UIColor *)pp_selectedCellColorFromPrimary
{
    return [self pp_selectedCellColorFromPrimaryWithAlpha:0.1];;
}

+ (UIColor *)pp_selectedCellColorFromPrimaryWithAlpha:(float)cusAlpha {
    UIColor *baseColor = [UIColor colorWithRed:0.698 green:0.106 blue:0.282 alpha:0.5]; // #B21B48
    CGFloat hue, sat, bright, alpha;
    [baseColor getHue:&hue saturation:&sat brightness:&bright alpha:&alpha];
    // lighten slightly and add transparency
    return [UIColor colorWithHue:hue saturation:sat brightness:MIN(bright + 0.2, 1.0) alpha:cusAlpha];
}

+ (UIColor *)pp_selectedCellColorFromPrimaryFull {
    UIColor *baseColor = [UIColor colorWithRed:0.698 green:0.106 blue:0.282 alpha:1.0]; // #B21B48
    CGFloat hue, sat, bright, alpha;
    [baseColor getHue:&hue saturation:&sat brightness:&bright alpha:&alpha];
    // lighten slightly and add transparency
    return [UIColor colorWithHue:hue saturation:sat brightness:MIN(bright + 0.2, 1.0) alpha:1.1];
}

@end



/*
 
 #pragma mark - Firestore Persistence (Optional)

 + (void)persistBubbleColor:(UIColor *)color
                forMessageID:(NSString *)messageID
 {
     if (!color || messageID.length == 0) return;

     NSDictionary *payload = [self serializeColor:color];
     if (!payload) return;

     FIRFirestore *db = [FIRFirestore firestore];

     [[[db collection:@"messages"] document:messageID]
      updateData:@{ @"bubbleColor" : payload }];
 }

 + (UIColor *)loadPersistedBubbleColorFromData:(NSDictionary *)data
 {
     NSDictionary *dict = data[@"bubbleColor"];
     return [self colorFromSerialized:dict];
 }

 */








@implementation UIColor (HXEExtension)

+ (UIColor *)hx_colorWithHexStr:(NSString *)string {
    return [UIColor hx_colorWithHexStr:string alpha:1.0];
}

+ (UIColor *)hx_colorWithHexStr:(NSString *)string alpha:(CGFloat)alpha {
    NSString *str;
    if ([string containsString:@"#"]) {
        str = [string substringFromIndex:1];
    } else {
        str = string;
    }
    
    NSScanner *scanner = [[NSScanner alloc] initWithString:str];
    UInt32 hexNum = 0;
    if ([scanner scanHexInt:&hexNum] == NO) {
        NSLog(@"16进制转UIColor, hexString为空");
    }
    
    return [UIColor hx_colorWithR:(hexNum & 0xFF0000) >> 16 g:(hexNum & 0x00FF00) >> 8 b:hexNum & 0x0000FF a:alpha];
}

+ (UIColor *)hx_colorWithR:(CGFloat)red g:(CGFloat)green b:(CGFloat)blue a:(CGFloat)alpha {
    return [UIColor colorWithRed:red / 255.0 green:green / 255.0 blue:blue / 255.0 alpha:alpha];
}
 
+ (NSString *)hx_hexStringWithColor:(UIColor *)color {
    CGFloat r, g, b, a;
    BOOL bo = [color getRed:&r green:&g blue:&b alpha:&a];
    if (bo) {
        int rgb = (int) (r * 255.0f)<<16 | (int) (g * 255.0f)<<8 | (int) (b * 255.0f)<<0;
        return [NSString stringWithFormat:@"#%06x", rgb].uppercaseString;
    } else {
        return @"";
    }
}
- (BOOL)hx_colorIsWhite {
    CGFloat red = 0;
    CGFloat green = 0;
    CGFloat blue = 0;
    [self getRed:&red green:&green blue:&blue alpha:NULL];
    if (red >= 0.99 && green >= 0.99 & blue >= 0.99) {
        return YES;
    }
    return NO;
}
@end







 
@implementation UIView (PPGradient)

- (void)setBackgroundGradientFrom:(UIColor *)start
                     middleColor:(UIColor *)middle
                               to:(UIColor *)end
                            angle:(CGFloat)degrees
                      cornerRadius:(CGFloat)radius
{
    CAGradientLayer *layer = nil;

    for (CALayer *l in self.layer.sublayers) {
        if ([l.name isEqualToString:@"PPGradientLayer"]) {
            layer = (CAGradientLayer *)l;
            break;
        }
    }

    if (!layer) {
        layer = [CAGradientLayer layer];
        layer.name = @"PPGradientLayer";
        [self.layer insertSublayer:layer atIndex:0];
    }

    layer.frame = self.bounds;
    layer.cornerRadius = radius;
    layer.colors = @[
        (__bridge id)start.CGColor,
        (__bridge id)middle.CGColor,
        (__bridge id)end.CGColor
    ];
    layer.locations = @[@0.0, @0.5, @1.0];

    CGFloat rad = degrees * M_PI / 180.0;
    layer.startPoint = CGPointMake(0.5 - cos(rad)/2, 0.5 - sin(rad)/2);
    layer.endPoint   = CGPointMake(0.5 + cos(rad)/2, 0.5 + sin(rad)/2);
}

@end
