// In PPBannerView.m
//
//  PPBannerView.m
//  PurePets
//
//  Manual CGRect layout (no Auto Layout):
//  - We compute frames in layoutSubviews for tight control & speed
//  - Right column (badge + sample) stays on the visual trailing side (RTL/LTR)
//  - Labels are measured with sizeThatFits
//  - Sample image size adapts for compact/regular width
//

#import "PPBannerView.h"
// #import "PPBannerViewModel.h"              // Uncomment if you want direct property access
 #import <SDWebImage/SDWebImage.h>          // Uncomment if you use SDWebImage
 

#pragma mark - Private Interface

@interface PPBannerView ()
@property (nonatomic, strong) CAGradientLayer *bgGradientLayer;

// Card container (rounded + clips). We draw everything inside this.
@property (nonatomic, strong) UIView *cardView;

// Background image behind content + gradient overlay for text readability
@property (nonatomic, strong) UIImageView *backgroundImageView;
@property (nonatomic, strong) UIImageView *badgeImageView;   // Small icon above sample (optional)
@property (nonatomic, strong) UIImageView *sampleImageView;  // Product/sample image

@property (nonatomic, strong) CAGradientLayer *gradientLayer;

// Foreground content: three labels on the text side, two images on the trailing side
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *descLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UIButton *takeOfferBTN;

// If you don't import PPBannerViewModel.h, we cache URLs via KVC here
@property (nonatomic, strong, nullable) NSURL *bgURL;
@property (nonatomic, strong, nullable) NSURL *sampleURL;
@property (nonatomic, strong, nullable) NSURL *badgeURL;

// Layout tuning knobs
@property (nonatomic, assign) CGFloat hSpacing;      // gap between text column and image column
@property (nonatomic, assign) CGFloat vSpacingText;  // vertical spacing between title/desc/date
@property (nonatomic, assign) CGFloat vSpacingRight; // vertical spacing between badge and sample

@end

@implementation PPBannerView {
    // Styling state
    UIEdgeInsets _contentInsets;  // inner padding for all content
     BOOL _showsShadow;            // shadow toggle (applied to self, not card)
}

- (void)takeOfferBTNTapped:(UIButton *)sender
{
    [self.delegate didTapOn_BannerViewModel:self.bannerModel];
}


#pragma mark - Init
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self commonInit_PPBannerView];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if ((self = [super initWithCoder:coder])) {
        [self commonInit_PPBannerView];
    }
    return self;
}

- (void)commonInit_PPBannerView {
    _contentInsets = UIEdgeInsetsMake(6, 6, 6, 6);

    self.layer.cornerRadius = PPNewCorner;
    self.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = NO;

    // ---- Card container ----
    _cardView = [[UIView alloc] initWithFrame:CGRectZero];
    _cardView.layer.cornerRadius = PPNewCorner;
    _cardView.clipsToBounds = YES;
    [self addSubview:_cardView];

    // Background
    _backgroundImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _backgroundImageView.contentMode = UIViewContentModeScaleAspectFill;
    _backgroundImageView.clipsToBounds = YES;
    _backgroundImageView.layer.cornerRadius = PPNewCorner;
    [_cardView addSubview:_backgroundImageView];

    // Gradient fallback
    _gradientLayer = [CAGradientLayer layer];
    _gradientLayer.colors = @[(__bridge id)AppPrimaryClr.CGColor,(__bridge id)AppPrimaryClrShiner.CGColor];
    _gradientLayer.startPoint = CGPointMake(0, 0);
    _gradientLayer.endPoint = CGPointMake(1, 1);
    //[_backgroundImageView.layer insertSublayer:_gradientLayer atIndex:0];

    // Labels
    _titleLabel = [UILabel new];
    _titleLabel.font = [GM boldFontWithSize:18];
    _titleLabel.textAlignment = GM.setAligment;
    _titleLabel.textColor = UIColor.whiteColor;
    _titleLabel.numberOfLines = 2;
    [_cardView addSubview:_titleLabel];

    _descLabel = [UILabel new];
    _descLabel.font = [GM MidFontWithSize:16];
    _descLabel.textColor = [UIColor colorWithWhite:1 alpha:0.92];
    _descLabel.textAlignment = GM.setAligment;
    _descLabel.numberOfLines = 0;
     _descLabel.lineBreakMode = NSLineBreakByWordWrapping;
    _descLabel.adjustsFontSizeToFitWidth = NO;
    [_cardView addSubview:_descLabel];

    _dateLabel = [UILabel new];
    _dateLabel.font = [GM fontWithSize:14];
    _dateLabel.textColor = [UIColor colorWithWhite:1 alpha:0.85];
    _dateLabel.numberOfLines = 1;
    _dateLabel.textAlignment = GM.setAligment;
    [_cardView addSubview:_dateLabel];

    // Right column
    _sampleImageView = [UIImageView new];
    _sampleImageView.contentMode = UIViewContentModeScaleAspectFill;
    _sampleImageView.clipsToBounds = YES;
    _sampleImageView.layer.cornerRadius = PPNewCorner;
    _sampleImageView.hidden = YES;
    [_cardView addSubview:_sampleImageView];

    _badgeImageView = [UIImageView new];
    _badgeImageView.contentMode = UIViewContentModeScaleAspectFit;
    _badgeImageView.clipsToBounds = YES;
    _badgeImageView.hidden = YES;
    [_cardView addSubview:_badgeImageView];
}

#pragma mark - Configure
- (void)configureWithModel:(PPBannerViewModel *)model {
    self.bannerModel = model.copy;

    _titleLabel.text = model.localizedTitleText ?: @"";
    _descLabel.text  = model.localizedDescText ?: @"";
    _dateLabel.text  = model.postDateText ?: @"";

    // Background
    _bgURL = model.backgroundImageURL;
    if (_bgURL && _bgURL.absoluteString.length > 5) {
        _backgroundImageView.hidden = NO;
        [GM setImageFromUrlString:_bgURL.absoluteString imageView:_backgroundImageView phImage:nil];
        _gradientLayer.hidden = YES;
    } else {
        _backgroundImageView.hidden = YES;
        _gradientLayer.hidden = NO;
    }

    // Sample vs countdown
    _sampleURL = model.sampleImageURL;
    if (_sampleURL && _sampleURL.absoluteString.length > 5) {
        _sampleImageView.hidden = NO;
        [GM setImageFromFirebaseURLString:_sampleURL.absoluteString
                                imageView:_sampleImageView
                                  phImage:nil
                              showShimmer:YES
                               completion:nil];
        [self hideCountdownView];
    } else if (model.expireInDateTime) {
        _sampleImageView.hidden = YES;
        [self configureCountdownWithEndDate:model.expireInDateTime];
    } else {
        _sampleImageView.hidden = YES;
        [self hideCountdownView];
    }
    [self applyTextColorsForStyle:model.textStyle];
   
    
    _badgeURL = model.badgeImageURL;
    _badgeImageView.hidden = !_badgeURL;
}



- (void)configureCountdownWithEndDate:(NSDate *)endDate {
    self.endDate = endDate;
    if (!self.countdownTitleLabel) {
        
    
        CGFloat pad = 5.0;
        self.countDownView = [PPFunc createEmptyModernCardView];
        [self addSubview:self.countDownView];
        self.countDownView.translatesAutoresizingMaskIntoConstraints = NO;
        self.countDownView.backgroundColor = [AppPrimaryTextClr colorWithAlphaComponent:0.1];
        // Center the card horizontally + vertically
        [NSLayoutConstraint activateConstraints:@[
            [self.countDownView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-pad],
            [self.countDownView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-pad],
            [self.countDownView.topAnchor constraintEqualToAnchor:self.topAnchor constant:pad],
            [self.countDownView.widthAnchor constraintEqualToAnchor:self.heightAnchor constant:50]
        ]];
        //self.countDownView.layer.maskedCorners = kCALayerMaxXMinYCorner | kCALayerMaxXMaxYCorner;
        self.countDownView.layer.shadowOpacity = 0.20;
        self.countDownView.layer.shadowOffset = CGSizeMake(2, 2);
        self.countDownView.layer.shadowRadius =6;
        self.countDownView.layer.cornerRadius =PPNewCorner;
        
        if (@available(iOS 13.0, *)) {
            self.countDownView.layer.cornerCurve = kCACornerCurveContinuous;
        }
        
        // Title
        self.countdownTitleLabel = [[UILabel alloc] init];
        self.countdownTitleLabel.text = kLang(@"REMAINING TIME");
        self.countdownTitleLabel.font = [GM boldFontWithSize:16];
        self.countdownTitleLabel.textColor = UIColor.secondaryLabelColor;
        self.countdownTitleLabel.textAlignment = NSTextAlignmentCenter;
        self.countdownTitleLabel.numberOfLines = 1;
        self.countdownTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.countDownView addSubview:self.countdownTitleLabel];

        // Time
        self.countdownTimeLabel = [[UILabel alloc] init];
        self.countdownTimeLabel.font = [GM boldFontWithSize:34];
        self.countdownTimeLabel.textColor = UIColor.labelColor;
        self.countdownTimeLabel.textAlignment = NSTextAlignmentCenter;
        self.countdownTimeLabel.numberOfLines = 1;
        self.countdownTimeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.countDownView addSubview:self.countdownTimeLabel];
        
        
        
        if (@available(iOS 26.0, *)) {
            self.takeOfferBTN = [PPButtonHelper pp_buttonWithTitle:kLang(@"takeTheOffer") font:[GM boldFontWithSize:14] textColor:AppPrimaryClr corners:8 imageName:nil target:self config:[UIButtonConfiguration glassButtonConfiguration] btnSize:34 action:@selector(takeOfferBTNTapped:)];
        } else {
            self.takeOfferBTN = [PPButtonHelper pp_buttonWithTitle:kLang(@"takeTheOffer") font:[GM boldFontWithSize:14] textColor:AppPrimaryTextClr corners:8 imageName:nil target:self config:[UIButtonConfiguration plainButtonConfiguration] btnSize:34 action:@selector(takeOfferBTNTapped:)];
        }
        
        
        self.takeOfferBTN.translatesAutoresizingMaskIntoConstraints = NO;
        [self.countDownView addSubview:self.takeOfferBTN];

        // Layout inside card
        [NSLayoutConstraint activateConstraints:@[
            [self.countdownTitleLabel.topAnchor constraintEqualToAnchor:self.countDownView.topAnchor constant:pad + 10],
            [self.countdownTitleLabel.centerXAnchor constraintEqualToAnchor:self.countDownView.centerXAnchor],
            [self.countdownTitleLabel.heightAnchor constraintEqualToConstant:14],
            
            
            [self.takeOfferBTN.bottomAnchor constraintEqualToAnchor:self.countDownView.bottomAnchor constant:-5],
            [self.takeOfferBTN.widthAnchor constraintEqualToAnchor:self.countDownView.widthAnchor constant:-20],
            [self.takeOfferBTN.centerXAnchor constraintEqualToAnchor:self.countDownView.centerXAnchor constant:0],
            [self.takeOfferBTN.heightAnchor constraintEqualToConstant:40],
            
            [self.countdownTimeLabel.topAnchor constraintEqualToAnchor:self.countdownTitleLabel.bottomAnchor constant:3],
            [self.countdownTimeLabel.centerXAnchor constraintEqualToAnchor:self.countDownView.centerXAnchor],
            [self.countdownTimeLabel.bottomAnchor constraintEqualToAnchor:self.takeOfferBTN.topAnchor constant:3],
            
            // KEY: Make countDownView width = countdownTimeLabel width + 30
            [self.countDownView.widthAnchor constraintEqualToAnchor:self.countdownTimeLabel.widthAnchor constant:30],

            
            //[self.takeOfferBTN.heightAnchor constraintEqualToConstant:38],
            
        
        ]];
        
 
    }
    self.countDownView.hidden = NO;
    [self startCountdown];
}

- (void)startCountdown {
    [self stopCountdown];
    [self updateCountdown]; // set immediately
    self.countdownTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                           target:self
                                                         selector:@selector(updateCountdown)
                                                         userInfo:nil
                                                          repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.countdownTimer forMode:NSRunLoopCommonModes];
}

- (void)stopCountdown {
    [self.countdownTimer invalidate];
    self.countdownTimer = nil;
}

- (void)updateCountdown {
    if (!self.endDate) return;

    NSTimeInterval remaining = [self.endDate timeIntervalSinceNow];
    if (remaining <= 0) {
        [self stopCountdown];
        self.countdownTimeLabel.text = @"00:00:00";
        return;
    }

    NSInteger days    = remaining / (24*3600);
    NSInteger hours   = ((NSInteger)remaining % (24*3600)) / 3600;
    NSInteger minutes = ((NSInteger)remaining % 3600) / 60;
    NSInteger seconds = (NSInteger)remaining % 60;

    if (days > 0) {
        self.countdownTimeLabel.text = [NSString stringWithFormat:@"%ld %@, %02ld:%02ld:%02ld",
                                        (long)days,kLang(@"Days"), (long)hours, (long)minutes, (long)seconds];
    } else {
        self.countdownTimeLabel.text = [NSString stringWithFormat:@"%02ld:%02ld:%02ld",
                                        (long)hours, (long)minutes, (long)seconds];
    }
    
    self.countdownTimeLabel.text = [NSString stringWithFormat:@"%02ld:%02ld:%02ld",
                                    (long)hours, (long)minutes, (long)seconds];
}



- (void)hideCountdownView {
    if (self.countDownView) {
        self.countDownView.hidden = YES;
    }
}

#pragma mark - Layout
- (void)layoutSubviews {
    [super layoutSubviews];
    _cardView.frame = self.bounds;
    _backgroundImageView.frame = _cardView.bounds;
    _gradientLayer.frame = _cardView.bounds;

    // Layout sample right column
    CGFloat side = 72.0;
    CGFloat pad = 12.0;
    CGFloat SampleX = Language.isRTL ? pad : self.bounds.size.width - side - pad;
    
    _sampleImageView.frame = CGRectMake(SampleX ,
                                        (self.bounds.size.height - side) / 2,
                                        side, side);
    _badgeImageView.frame = CGRectMake(SampleX,
                                       _sampleImageView.frame.origin.y - 24,
                                       20, 20);

    CGFloat textWidth = self.bounds.size.width - side - 32;
    
    CGFloat TextX = Language.isRTL ? self.frame.size.width - textWidth - pad : pad ;

    
    _titleLabel.frame = CGRectMake(TextX, 12, textWidth, 22);
    _descLabel.frame  = CGRectMake(TextX, CGRectGetMaxY(_titleLabel.frame)+4, textWidth, 20);
    _dateLabel.frame  = CGRectMake(TextX,
                                   CGRectGetMaxY(self.frame) - 20,
                                   textWidth - self.countdownLabel.hx_w - 12,
                                   18);
    
    
}

#pragma mark - Reuse
- (void)prepareForReuse {
    _titleLabel.text = @"";
    _descLabel.text  = @"";
    _dateLabel.text  = @"";

    _backgroundImageView.image = nil;
    _backgroundImageView.hidden = YES;
    _gradientLayer.hidden = NO;

    _sampleImageView.image = nil;
    _sampleImageView.hidden = YES;

    _badgeImageView.image = nil;
    _badgeImageView.hidden = YES;

    [self hideCountdownView];
}


#pragma mark - Public API

// Updating content padding → request a relayout
- (void)setContentInsets:(UIEdgeInsets)contentInsets {
    _contentInsets = contentInsets;
    [self setNeedsLayout];
}

// Change corner radius at runtime
- (void)setCornerRadius:(CGFloat)cornerRadius {
    _cardView.layer.cornerRadius = PPCorners;
    
    if (@available(iOS 13.0, *)) {
        self.cardView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    
    // Tip: also mirror to self.layer.cornerRadius and _gradientLayer.cornerRadius if you want perfect match
}

// Toggle shadow on/off and re-apply params
- (void)setShowsShadow:(BOOL)showsShadow {
    _showsShadow = showsShadow;
    [self applyShadowIfNeeded];
}

#pragma mark - Layout (CGRect)

// Determine RTL/LTR. You use a custom Language helper here:
// Language.languageVal == 1 → RTL, else LTR.
// If you’d rather follow system layout direction, use:
// return (self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft);
- (BOOL)_isRTL {
    return (Language.languageVal == 1);
}

// Decide sample image size depending on horizontal size class
- (CGSize)_sampleImageSize {
    BOOL compact = (self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassCompact);
    CGFloat side = compact ? 72.0 : 88.0;
    return CGSizeMake(side, side);
}

// Apply content insets to any rect
- (CGRect)_contentRectForBounds:(CGRect)b {
    return UIEdgeInsetsInsetRect(b, _contentInsets);
}




// Let containers ask for a “natural” height for a given width (helps Auto Layout & self-sizing cells)
- (CGSize)sizeThatFits:(CGSize)size {
    CGFloat width = size.width > 0 ? size.width : UIScreen.mainScreen.bounds.size.width;
    CGRect content = [self _contentRectForBounds:CGRectMake(0, 0, width, 1000)];

    // Width for text after reserving trailing column and spacing
    CGSize sampleSize = [self _sampleImageSize];
    CGFloat rightColWidth = MAX(sampleSize.width, 24.0);
    CGFloat textWidth = content.size.width - rightColWidth - _hSpacing;

    // Measure three labels stacked
    CGSize maxText = CGSizeMake(MAX(0.0, textWidth), CGFLOAT_MAX);
    CGFloat h = 0;
    h += [_titleLabel sizeThatFits:maxText].height + _vSpacingText;
    h += [_descLabel  sizeThatFits:maxText].height + _vSpacingText;
    h += [_dateLabel  sizeThatFits:maxText].height;

    // Ensure minimum inner height is at least the sample column (plus room for badge)
    CGFloat innerHeight = MAX(h, sampleSize.height + 24.0 /* badge room */);
    innerHeight = MAX(innerHeight, 64.0); // safety floor so it never collapses

    // Add top/bottom insets
    innerHeight += _contentInsets.top + _contentInsets.bottom;
    return CGSizeMake(width, ceil(innerHeight));
}

#pragma mark - Trait / Theme Changes

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];

    // Slightly stronger gradient in dark mode for readability
    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        _gradientLayer.colors = @[
            (id)[UIColor colorWithWhite:0 alpha:0.45].CGColor,
            (id)[UIColor colorWithWhite:0 alpha:0.10].CGColor
        ];
    } else {
        _gradientLayer.colors = @[
            (id)[UIColor colorWithWhite:0 alpha:0.35].CGColor,
            (id)[UIColor colorWithWhite:0 alpha:0.05].CGColor
        ];
    }

    // Any size class or layout direction changes → relayout
    [self setNeedsLayout];
}

#pragma mark - Helpers

// Apply (or clear) drop shadow on the outer view (not clipped)
- (void)applyShadowIfNeeded {
    if (_showsShadow) {
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOpacity = 0.15;
        self.layer.shadowRadius = 10;

        self.layer.masksToBounds = NO; // IMPORTANT for visible shadow
    } else {
        self.layer.shadowOpacity = 0.0;
    }
   
}


// Provide an intrinsic height so Auto Layout can size the banner without you hardcoding a height
- (CGSize)intrinsicContentSize {
    CGFloat width = (self.bounds.size.width > 0) ? self.bounds.size.width : UIScreen.mainScreen.bounds.size.width;
    return [self sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];
}


#pragma mark - Gradient setter (works with shadow)
- (void)setBackgroundGradientFrom:(UIColor *)startColor
                               to:(UIColor *)endColor
                            angle:(CGFloat)degrees
{
    // 3) Gradient behind everything inside cardView
    _bgGradientLayer = [CAGradientLayer layer];
    _bgGradientLayer.cornerRadius = PPCornersHome;
    
    if (@available(iOS 13.0, *)) {
        _bgGradientLayer.cornerCurve = kCACornerCurveContinuous;
    }
    
    [_cardView.layer insertSublayer:_bgGradientLayer atIndex:0];
    
    
    _gradientLayer.colors = @[(__bridge id)startColor.CGColor,
                                (__bridge id)endColor.CGColor];
    _gradientLayer.locations = @[@0.0, @1.0];

    CGFloat theta = degrees * (CGFloat)M_PI / 180.0;
    CGPoint start = CGPointMake(0.5 - 0.5 * cos(theta), 0.5 - 0.5 * sin(theta));
    CGPoint end   = CGPointMake(0.5 + 0.5 * cos(theta), 0.5 + 0.5 * sin(theta));
    _gradientLayer.startPoint = start;
    _gradientLayer.endPoint   = end;
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


- (NSArray<UIColor *> *)extractThreeMainColorsFromImage:(UIImage *)image lightenAmount:(CGFloat)amount {
    if (!image) return @[[UIColor whiteColor], [UIColor lightGrayColor], [UIColor darkGrayColor]];
    
    // Downscale to speed things up
    CGSize thumbSize = CGSizeMake(30, 30);
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
                                                 bitsPerComponent, bytesPerRow,
                                                 colorSpace,
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
            if (brightness < 0.25) continue; // ignore very dark pixels
            
            int qr = (int)(r * 15);
            int qg = (int)(g * 15);
            int qb = (int)(b * 15);
            
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
        CGFloat r = [parts[0] intValue] / 15.0;
        CGFloat g = [parts[1] intValue] / 15.0;
        CGFloat b = [parts[2] intValue] / 15.0;
        
        UIColor *c = [UIColor colorWithRed:r green:g blue:b alpha:1.0];
        [colors addObject:[self lightenColor:c amount:amount]];
        if (colors.count >= 3) break;
    }
    
    if (colors.count < 3) {
        [colors addObject:[UIColor whiteColor]];
        [colors addObject:[UIColor lightGrayColor]];
        [colors addObject:[UIColor darkGrayColor]];
    }
    
    return colors;
}



// Call this whenever the style or theme changes
- (void)applyTextColorsForStyle:(PPBannerTextStyle)style {
    // Fallback: use white if your app color is nil
    UIColor *brandFG = PPColorOr(AppForgroundColr, UIColor.whiteColor);

    UIColor *titleColor = (style == PPBannerTextStyleBlack) ? UIColor.blackColor : brandFG;
    UIColor *subColor   = (style == PPBannerTextStyleBlack) ? UIColor.darkGrayColor : brandFG;

    // Always on main thread to be safe
    dispatch_async(dispatch_get_main_queue(), ^{
        self.titleLabel.textColor = titleColor;
        self.descLabel.textColor  = subColor;
        self.dateLabel.textColor  = subColor;
    });
}




@end



/*
 // In PPBannerView.m
 //
 //  PPBannerView.m
 //  PurePets
 //
 //  Manual CGRect layout (no Auto Layout):
 //  - We compute frames in layoutSubviews for tight control & speed
 //  - Right column (badge + sample) stays on the visual trailing side (RTL/LTR)
 //  - Labels are measured with sizeThatFits
 //  - Sample image size adapts for compact/regular width
 //

 #import "PPBannerView.h"
 // #import "PPBannerViewModel.h"              // Uncomment if you want direct property access
  #import <SDWebImage/SDWebImage.h>          // Uncomment if you use SDWebImage


 #pragma mark - Private Interface

 @interface PPBannerView ()
 @property (nonatomic, strong) CAGradientLayer *bgGradientLayer;
 // Card container (rounded + clips). We draw everything inside this.
 @property (nonatomic, strong) UIView *cardView;

 // Background image behind content + gradient overlay for text readability
 @property (nonatomic, strong) UIImageView *backgroundImageView;
 @property (nonatomic, strong) UIImageView *badgeImageView;   // Small icon above sample (optional)
 @property (nonatomic, strong) UIImageView *sampleImageView;  // Product/sample image

 @property (nonatomic, strong) CAGradientLayer *gradientLayer;

 // Foreground content: three labels on the text side, two images on the trailing side
 @property (nonatomic, strong) UILabel *titleLabel;
 @property (nonatomic, strong) UILabel *descLabel;
 @property (nonatomic, strong) UILabel *dateLabel;
 @property (nonatomic, strong) UIButton *takeOfferBTN;
 // If you don't import PPBannerViewModel.h, we cache URLs via KVC here
 @property (nonatomic, strong, nullable) NSURL *bgURL;
 @property (nonatomic, strong, nullable) NSURL *sampleURL;
 @property (nonatomic, strong, nullable) NSURL *badgeURL;

 // Layout tuning knobs
 @property (nonatomic, assign) CGFloat hSpacing;      // gap between text column and image column
 @property (nonatomic, assign) CGFloat vSpacingText;  // vertical spacing between title/desc/date
 @property (nonatomic, assign) CGFloat vSpacingRight; // vertical spacing between badge and sample

 @end

 @implementation PPBannerView {
     // Styling state
     UIEdgeInsets _contentInsets;  // inner padding for all content
      BOOL _showsShadow;            // shadow toggle (applied to self, not card)
 }

 - (void)takeOfferBTNTapped:(UIButton *)sender
 {
     [self.delegate didTapOn_BannerViewModel:self.bannerModel];
 }



 - (void)configureCountdownWithEndDate:(NSDate *)endDate {
     self.endDate = endDate;
     if (!self.countdownTitleLabel) {
         
     
         CGFloat pad = 5.0;
         self.countDownView = [PPFunc createEmptyModernCardView];
         [self addSubview:self.countDownView];
         self.countDownView.translatesAutoresizingMaskIntoConstraints = NO;
         self.countDownView.backgroundColor = AppPrimaryClrShiner;
         // Center the card horizontally + vertically
         [NSLayoutConstraint activateConstraints:@[
             [self.countDownView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-pad],
             [self.countDownView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-pad],
             [self.countDownView.topAnchor constraintEqualToAnchor:self.topAnchor constant:pad]
         ]];
         //self.countDownView.layer.maskedCorners = kCALayerMaxXMinYCorner | kCALayerMaxXMaxYCorner;
         self.countDownView.layer.shadowOpacity = 0.20;
         self.countDownView.layer.shadowOffset = CGSizeMake(2, 2);
         self.countDownView.layer.shadowRadius =6;
         self.countDownView.layer.cornerRadius =PPCorners;
         
         // Title
         self.countdownTitleLabel = [[UILabel alloc] init];
         self.countdownTitleLabel.text = kLang(@"REMAINING TIME");
         self.countdownTitleLabel.font = [GM boldFontWithSize:14];
         self.countdownTitleLabel.textColor = AppBackgroundClrLigter;
         self.countdownTitleLabel.textAlignment = NSTextAlignmentCenter;
         self.countdownTitleLabel.numberOfLines = 0;
         self.countdownTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
         [self.countDownView addSubview:self.countdownTitleLabel];

         // Time
         self.countdownTimeLabel = [[UILabel alloc] init];
         self.countdownTimeLabel.font = [GM boldFontWithSize:26];
         self.countdownTimeLabel.textColor = AppForgroundColr;
         self.countdownTimeLabel.textAlignment = NSTextAlignmentCenter;
         self.countdownTimeLabel.numberOfLines = 1;
         self.countdownTimeLabel.translatesAutoresizingMaskIntoConstraints = NO;
         [self.countDownView addSubview:self.countdownTimeLabel];
         
         
         
         if (@available(iOS 26.0, *)) {
             self.takeOfferBTN = [PPButtonHelper pp_buttonWithTitle:kLang(@"takeTheOffer") font:[GM boldFontWithSize:14] textColor:AppForgroundColr corners:16 imageName:nil target:self config:[UIButtonConfiguration prominentGlassButtonConfiguration] action:@selector(takeOfferBTNTapped:)];
         } else {
             self.takeOfferBTN = [PPButtonHelper pp_buttonWithTitle:kLang(@"takeTheOffer") font:[GM boldFontWithSize:14] textColor:AppForgroundColr corners:16 imageName:nil target:self config:[UIButtonConfiguration plainButtonConfiguration] action:@selector(takeOfferBTNTapped:)];
         }
         
         
         self.takeOfferBTN.translatesAutoresizingMaskIntoConstraints = NO;
         [self.countDownView addSubview:self.takeOfferBTN];

         // Layout inside card
         [NSLayoutConstraint activateConstraints:@[
             [self.countdownTitleLabel.topAnchor constraintEqualToAnchor:self.countDownView.topAnchor constant:pad],
             [self.countdownTitleLabel.centerXAnchor constraintEqualToAnchor:self.countDownView.centerXAnchor],
             [self.countdownTitleLabel.heightAnchor constraintEqualToConstant:14],
             
             
             [self.takeOfferBTN.bottomAnchor constraintEqualToAnchor:self.countDownView.bottomAnchor constant:-5],
             [self.takeOfferBTN.widthAnchor constraintEqualToAnchor:self.countDownView.widthAnchor constant:-20],
             [self.takeOfferBTN.centerXAnchor constraintEqualToAnchor:self.countDownView.centerXAnchor constant:0],
             [self.takeOfferBTN.heightAnchor constraintEqualToConstant:36],
             
             [self.countdownTimeLabel.topAnchor constraintEqualToAnchor:self.countdownTitleLabel.bottomAnchor constant:3],
             [self.countdownTimeLabel.centerXAnchor constraintEqualToAnchor:self.countDownView.centerXAnchor],
             [self.countdownTimeLabel.bottomAnchor constraintEqualToAnchor:self.takeOfferBTN.topAnchor constant:3],
             
             // KEY: Make countDownView width = countdownTimeLabel width + 30
             [self.countDownView.widthAnchor constraintEqualToAnchor:self.countdownTimeLabel.widthAnchor constant:30],

             
             //[self.takeOfferBTN.heightAnchor constraintEqualToConstant:38],
             
         
         ]];
         
  
     }

     [self startCountdown];
 }

 - (void)startCountdown {
     [self stopCountdown];
     [self updateCountdown]; // set immediately
     self.countdownTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                            target:self
                                                          selector:@selector(updateCountdown)
                                                          userInfo:nil
                                                           repeats:YES];
     [[NSRunLoop mainRunLoop] addTimer:self.countdownTimer forMode:NSRunLoopCommonModes];
 }

 - (void)stopCountdown {
     [self.countdownTimer invalidate];
     self.countdownTimer = nil;
 }

 - (void)updateCountdown {
     if (!self.endDate) return;

     NSTimeInterval remaining = [self.endDate timeIntervalSinceNow];
     if (remaining <= 0) {
         [self stopCountdown];
         self.countdownTimeLabel.text = @"00:00:00";
         return;
     }

     NSInteger days    = remaining / (24*3600);
     NSInteger hours   = ((NSInteger)remaining % (24*3600)) / 3600;
     NSInteger minutes = ((NSInteger)remaining % 3600) / 60;
     NSInteger seconds = (NSInteger)remaining % 60;

     if (days > 0) {
         self.countdownTimeLabel.text = [NSString stringWithFormat:@"%ld %@, %02ld:%02ld:%02ld",
                                         (long)days,kLang(@"Days"), (long)hours, (long)minutes, (long)seconds];
     } else {
         self.countdownTimeLabel.text = [NSString stringWithFormat:@"%02ld:%02ld:%02ld",
                                         (long)hours, (long)minutes, (long)seconds];
     }
     
     self.countdownTimeLabel.text = [NSString stringWithFormat:@"%02ld:%02ld:%02ld",
                                     (long)hours, (long)minutes, (long)seconds];
 }


 #pragma mark - Init

 - (instancetype)initWithFrame:(CGRect)frame {
     if ((self = [super initWithFrame:frame])) {
         [self commonInit_PPBannerView]; // centralizes setup
     }
     return self;
 }

 - (instancetype)initWithCoder:(NSCoder *)coder {
     if ((self = [super initWithCoder:coder])) {
         [self commonInit_PPBannerView]; // same setup when loaded from nib/storyboard
     }
     return self;
 }

 - (void)commonInit_PPBannerView {
     // ---- Default styling & spacing ----
     
     //self.backgroundColor = GM.AppForegroundColor;  // let card/gradient handle visuals
     _contentInsets = UIEdgeInsetsMake(6, 6, 6, 6);
     _showsShadow   = NO;
   
     _hSpacing      = 2.0;
     _vSpacingText  = 4.0;
     _vSpacingRight = 6.0;
     
     // ---- Card container ----
     // We clip inside the card so the background image (and gradient) respect corners.
     _cardView = [[UIView alloc] initWithFrame:CGRectZero];
     _cardView.layer.cornerRadius = PPCorners;
     _cardView.clipsToBounds = YES;
     [self addSubview:_cardView];
     
     // Shadow is applied on self, not card, so it's not clipped.
     [self applyShadowIfNeeded];
     
     // ---- Background image + gradient overlay ----
     _backgroundImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
     _backgroundImageView.contentMode = UIViewContentModeScaleToFill;
     _backgroundImageView.clipsToBounds = YES;
     _backgroundImageView.layer.cornerRadius = PPCorners;
     [_cardView addSubview:_backgroundImageView];
     
    
     
     // ---- Labels (text column) ----
     _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
     _titleLabel.numberOfLines = 2;                                // allow two lines
     _titleLabel.adjustsFontForContentSizeCategory = YES;          // Dynamic Type
     _titleLabel.font = [GM boldFontWithSize:18];
     _titleLabel.textColor = UIColor.whiteColor;
     _titleLabel.textAlignment = GM.setAligment;                   // your helper: LTR/RTL alignment
     _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
     [_cardView addSubview:_titleLabel];
     
     _descLabel = [[UILabel alloc] initWithFrame:CGRectZero];
     _descLabel.numberOfLines = 2;
     _descLabel.adjustsFontForContentSizeCategory = YES;
     _descLabel.font = [GM MidFontWithSize:16];
     _descLabel.textColor = [UIColor colorWithWhite:1 alpha:0.92];
     _descLabel.textAlignment = GM.setAligment;                    // your helper: LTR/RTL alignment
     _descLabel.lineBreakMode = NSLineBreakByTruncatingTail;
     [_cardView addSubview:_descLabel];
     
     _dateLabel = [[UILabel alloc] initWithFrame:CGRectZero];
     _dateLabel.numberOfLines = 1;                                 // single line
     _dateLabel.adjustsFontForContentSizeCategory = YES;
     _dateLabel.font = [GM fontWithSize:14];
     _dateLabel.textColor = [UIColor colorWithWhite:1 alpha:0.85];
     _dateLabel.textAlignment = GM.setAligment;                    // your helper: LTR/RTL alignment
     _dateLabel.lineBreakMode = NSLineBreakByTruncatingTail;
     [_cardView addSubview:_dateLabel];
     
     // ---- Right column (badge + sample) ----
     _badgeImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
     _badgeImageView.contentMode = UIViewContentModeScaleAspectFit;
     _badgeImageView.clipsToBounds = YES;
     _badgeImageView.hidden = YES;                                 // hidden if no URL provided
     [_cardView addSubview:_badgeImageView];
     
     _sampleImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
     _sampleImageView.contentMode = UIViewContentModeScaleAspectFill;
     _sampleImageView.clipsToBounds = YES;
     _sampleImageView.layer.cornerRadius = PPCorners;                   // sample corner
     _sampleImageView.backgroundColor = UIColor.clearColor;
     [_cardView addSubview:_sampleImageView];
     
     // ---- Accessibility ----
     // Make the whole banner behave like a tappable card.
     self.isAccessibilityElement = YES;
     self.accessibilityTraits = UIAccessibilityTraitButton;
     
     // If you want outer rounded corners on the banner view itself (not just card):
     self.layer.cornerRadius = PPCorners;
     self.clipsToBounds = NO;      // NOTE: this will clip shadow if you also set shadow on self
     self.layer.masksToBounds = NO;// (We apply shadow on self earlier; if you want shadow visible, remove this line.)
     
     self.backgroundColor = UIColor.clearColor;
     
 }

 #pragma mark - Public API

 // Updating content padding → request a relayout
 - (void)setContentInsets:(UIEdgeInsets)contentInsets {
     _contentInsets = contentInsets;
     [self setNeedsLayout];
 }

 // Change corner radius at runtime
 - (void)setCornerRadius:(CGFloat)cornerRadius {
     _cardView.layer.cornerRadius = PPCorners;
     // Tip: also mirror to self.layer.cornerRadius and _gradientLayer.cornerRadius if you want perfect match
 }

 // Toggle shadow on/off and re-apply params
 - (void)setShowsShadow:(BOOL)showsShadow {
     _showsShadow = showsShadow;
     [self applyShadowIfNeeded];
 }

 // Main entry to fill the banner
 - (void)configureWithModel:(PPBannerViewModel *)model {
  
     self.bannerModel = model.copy;
     _titleLabel.text =   self.bannerModel.localizedTitleText ?: @"";
     _descLabel.text  = self.bannerModel.localizedDescText ?: @"";
     _dateLabel.text  = self.bannerModel.postDateText ?: @"";
     
     // Accessibility announcement text
     self.accessibilityLabel = [@[
         _titleLabel.text ?: @"",
         _descLabel.text  ?: @"",
         _dateLabel.text  ?: @""
     ] componentsJoinedByString:@". "];
     self.accessibilityHint = NSLocalizedString(@"Double-tap to open details.", @"Banner accessibility hint");

     // Cache URLs for loaders
     _bgURL     = self.bannerModel.backgroundImageURL ;
     _sampleURL = self.bannerModel.sampleImageURL ;
     _badgeURL  = self.bannerModel.badgeImageURL ;

     if (_bgURL && _bgURL.absoluteString.length > 10) {
         _backgroundImageView.hidden = NO;
         [GM setImageFromUrlString:_bgURL.absoluteString imageView:_backgroundImageView phImage:nil];
     } else {
         _backgroundImageView.hidden = YES;
         _backgroundImageView.image = nil;
     }

     if (model.expireInDateTime) {
         [self configureCountdownWithEndDate:model.expireInDateTime];
      }
     else
     {
         [self.countDownView removeAllSubviews];
         [self.countDownView removeFromSuperview];
     }
     
     
     
     __weak typeof(self) weakSelf = self;
     
     if (_sampleURL && _sampleURL.absoluteString.length > 10) {
         _sampleImageView.hidden = NO;
         [GM setImageFromFirebaseURLString:_sampleURL.absoluteString imageView:_sampleImageView phImage:nil showShimmer:YES completion:^(UIImage * _Nullable image, NSError * _Nullable error) {
            
             dispatch_async(dispatch_get_main_queue(), ^{
                   __strong typeof(weakSelf) strongSelf = weakSelf;
                   if (!strongSelf || !image) return;
                 [PPColorUtils applyGradientFromImage:strongSelf.sampleImageView toView:strongSelf withToneAdjustment:PPColorToneAdjustmentLighten degree:0.35];
               });
         }];
     } else {
         _sampleImageView.hidden = YES;
         _sampleImageView.image = nil;
     }
     
     
      //_badgeImageView.hidden = (_badgeURL == nil);
     _badgeImageView.hidden = YES;
     _badgeImageView.image = nil;
     
     
     [self applyTextColorsForStyle:(PPBannerTextStyle)self.bannerModel.textStyle];
     
     //[self.countDownView pp_applyGradientWithColors:@[AppPrimaryClr,AppPrimaryClrShiner] cornerRadius:32 shadowColor:AppShadowClr shadowOpacity:0.15 shadowRadius:4 shadowOffset:CGSizeMake(1, 2)];
     [self.countDownView pp_applyGradientWithColors:@[AppPrimaryClr,AppShadowClr] cornerRadius:PPCorners shadowColor:AppShadowClr shadowOpacity:0.15 shadowRadius:4 shadowOffset:CGSizeMake(1, 2)];
     //[self.countDownView pp_applyTwoToneTopColor:AppPrimaryClrDarker bottomColor:AppPrimaryClr  cornerRadius:PPCorners shadowColor:AppShadowClr shadowOpacity:0.1 shadowRadius:3 shadowOffset:CGSizeMake(0, 2)];
     [self setNeedsLayout]; // trigger relayout with new content
 }



 // Reset visuals when cells reuse this view
 - (void)prepareForReuse {
     _titleLabel.text = @"";
     _descLabel.text  = @"";
     _dateLabel.text  = @"";
     _badgeImageView.image = nil;
     _badgeImageView.hidden = YES;

     _sampleImageView.image = nil;
     _sampleImageView.hidden = YES;
     _sampleImageView.backgroundColor = UIColor.clearColor;
     [self setNeedsLayout];
     _sampleImageView.backgroundColor = UIColor.clearColor;
     
     // Add tap gesture recognizer
     //UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(profileImageTapped:)];
     //[imageView addGestureRecognizer:tapGesture];

 }

 #pragma mark - Layout (CGRect)

 // Determine RTL/LTR. You use a custom Language helper here:
 // Language.languageVal == 1 → RTL, else LTR.
 // If you’d rather follow system layout direction, use:
 // return (self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft);
 - (BOOL)_isRTL {
     return (Language.languageVal == 1);
 }

 // Decide sample image size depending on horizontal size class
 - (CGSize)_sampleImageSize {
     BOOL compact = (self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassCompact);
     CGFloat side = compact ? 72.0 : 88.0;
     return CGSizeMake(side, side);
 }

 // Apply content insets to any rect
 - (CGRect)_contentRectForBounds:(CGRect)b {
     return UIEdgeInsetsInsetRect(b, _contentInsets);
 }




 // Let containers ask for a “natural” height for a given width (helps Auto Layout & self-sizing cells)
 - (CGSize)sizeThatFits:(CGSize)size {
     CGFloat width = size.width > 0 ? size.width : UIScreen.mainScreen.bounds.size.width;
     CGRect content = [self _contentRectForBounds:CGRectMake(0, 0, width, 1000)];

     // Width for text after reserving trailing column and spacing
     CGSize sampleSize = [self _sampleImageSize];
     CGFloat rightColWidth = MAX(sampleSize.width, 24.0);
     CGFloat textWidth = content.size.width - rightColWidth - _hSpacing;

     // Measure three labels stacked
     CGSize maxText = CGSizeMake(MAX(0.0, textWidth), CGFLOAT_MAX);
     CGFloat h = 0;
     h += [_titleLabel sizeThatFits:maxText].height + _vSpacingText;
     h += [_descLabel  sizeThatFits:maxText].height + _vSpacingText;
     h += [_dateLabel  sizeThatFits:maxText].height;

     // Ensure minimum inner height is at least the sample column (plus room for badge)
     CGFloat innerHeight = MAX(h, sampleSize.height + 24.0  );
     innerHeight = MAX(innerHeight, 64.0); // safety floor so it never collapses

     // Add top/bottom insets
     innerHeight += _contentInsets.top + _contentInsets.bottom;
     return CGSizeMake(width, ceil(innerHeight));
 }

 #pragma mark - Trait / Theme Changes

 - (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
     [super traitCollectionDidChange:previousTraitCollection];

     // Slightly stronger gradient in dark mode for readability
     if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
         _gradientLayer.colors = @[
             (id)[UIColor colorWithWhite:0 alpha:0.45].CGColor,
             (id)[UIColor colorWithWhite:0 alpha:0.10].CGColor
         ];
     } else {
         _gradientLayer.colors = @[
             (id)[UIColor colorWithWhite:0 alpha:0.35].CGColor,
             (id)[UIColor colorWithWhite:0 alpha:0.05].CGColor
         ];
     }

     // Any size class or layout direction changes → relayout
     [self setNeedsLayout];
 }

 #pragma mark - Helpers

 // Apply (or clear) drop shadow on the outer view (not clipped)
 - (void)applyShadowIfNeeded {
     if (_showsShadow) {
         self.layer.shadowColor = [UIColor blackColor].CGColor;
         self.layer.shadowOpacity = 0.15;
         self.layer.shadowRadius = 10;

         self.layer.masksToBounds = NO; // IMPORTANT for visible shadow
     } else {
         self.layer.shadowOpacity = 0.0;
     }
    
 }


 // Provide an intrinsic height so Auto Layout can size the banner without you hardcoding a height
 - (CGSize)intrinsicContentSize {
     CGFloat width = (self.bounds.size.width > 0) ? self.bounds.size.width : UIScreen.mainScreen.bounds.size.width;
     return [self sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];
 }


 #pragma mark - Gradient setter (works with shadow)
 - (void)setBackgroundGradientFrom:(UIColor *)startColor
                                to:(UIColor *)endColor
                             angle:(CGFloat)degrees
 {
     // 3) Gradient behind everything inside cardView
     _bgGradientLayer = [CAGradientLayer layer];
     _bgGradientLayer.cornerRadius = PPCorners;
     [_cardView.layer insertSublayer:_bgGradientLayer atIndex:0];
     
     
     _gradientLayer.colors = @[(__bridge id)startColor.CGColor,
                                 (__bridge id)endColor.CGColor];
     _gradientLayer.locations = @[@0.0, @1.0];

     CGFloat theta = degrees * (CGFloat)M_PI / 180.0;
     CGPoint start = CGPointMake(0.5 - 0.5 * cos(theta), 0.5 - 0.5 * sin(theta));
     CGPoint end   = CGPointMake(0.5 + 0.5 * cos(theta), 0.5 + 0.5 * sin(theta));
     _gradientLayer.startPoint = start;
     _gradientLayer.endPoint   = end;
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


 - (NSArray<UIColor *> *)extractThreeMainColorsFromImage:(UIImage *)image lightenAmount:(CGFloat)amount {
     if (!image) return @[[UIColor whiteColor], [UIColor lightGrayColor], [UIColor darkGrayColor]];
     
     // Downscale to speed things up
     CGSize thumbSize = CGSizeMake(30, 30);
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
                                                  bitsPerComponent, bytesPerRow,
                                                  colorSpace,
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
             if (brightness < 0.25) continue; // ignore very dark pixels
             
             int qr = (int)(r * 15);
             int qg = (int)(g * 15);
             int qb = (int)(b * 15);
             
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
         CGFloat r = [parts[0] intValue] / 15.0;
         CGFloat g = [parts[1] intValue] / 15.0;
         CGFloat b = [parts[2] intValue] / 15.0;
         
         UIColor *c = [UIColor colorWithRed:r green:g blue:b alpha:1.0];
         [colors addObject:[self lightenColor:c amount:amount]];
         if (colors.count >= 3) break;
     }
     
     if (colors.count < 3) {
         [colors addObject:[UIColor whiteColor]];
         [colors addObject:[UIColor lightGrayColor]];
         [colors addObject:[UIColor darkGrayColor]];
     }
     
     return colors;
 }



 // Call this whenever the style or theme changes
 - (void)applyTextColorsForStyle:(PPBannerTextStyle)style {
     // Fallback: use white if your app color is nil
     UIColor *brandFG = PPColorOr(AppForgroundColr, UIColor.whiteColor);

     UIColor *titleColor = (style == PPBannerTextStyleBlack) ? UIColor.blackColor : brandFG;
     UIColor *subColor   = (style == PPBannerTextStyleBlack) ? UIColor.darkGrayColor : brandFG;

     // Always on main thread to be safe
     dispatch_async(dispatch_get_main_queue(), ^{
         self.titleLabel.textColor = titleColor;
         self.descLabel.textColor  = subColor;
         self.dateLabel.textColor  = subColor;
     });
 }




 @end


 */
