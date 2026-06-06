  






//
//  PetCategoryCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 08/05/2025.
//


#import "MainAppCell.h"
#import "PPUniversalCellHelper.h"


@interface MainAppCell ()
@property (nonatomic, strong) UIView *cardView;     // rounded, clips to bounds
@property (nonatomic, strong) CAGradientLayer *bgGradientLayer;
@property (nonatomic, strong) NSIndexPath *cellIndexP;
@property (nonatomic, strong) PPCornerBlurView *overlay;
@property (nonatomic, assign) BOOL didSetupConstraints;
@property (nonatomic, strong) UIButton *glassButton;
@property (nonatomic, strong) UIColor *currentColor;
@end


@implementation MainAppCell

- (UIColor *)pp_safeColorInArray:(NSArray<UIColor *> *)colors
                          atIndex:(NSUInteger)index
                         fallback:(UIColor *)fallback
{
    if (index < colors.count) {
        id candidate = colors[index];
        if ([candidate isKindOfClass:UIColor.class]) {
            return (UIColor *)candidate;
        }
    }
    return fallback ?: [UIColor colorWithWhite:0.85 alpha:1.0];
}


#pragma mark - Public Configure API
- (void)updateConstraints {
    [super updateConstraints];
    if (self.didSetupConstraints) return;
    self.didSetupConstraints = YES;
    
    if (self.cellIndexP.item == 4) {
        // Image width follows height
        [NSLayoutConstraint activateConstraints:@[
            [self.imageView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [self.imageView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
            [self.imageView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor], 
            [self.imageView.widthAnchor constraintEqualToAnchor:self.contentView.heightAnchor]
        ]];
    } else {
        // Image fills the card
        [NSLayoutConstraint activateConstraints:@[
            [self.imageView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [self.imageView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [self.imageView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [self.imageView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
        ]];
    }
}


- (void)mainScreenTap
{
    NSLog(@"PRESSING ........");
    [self.delegate mainScreenTapCellAtIndex:self.cellIndexPath];
}
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        
 
        self.glassButton = [self setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleSmall masked:kCALayerMinXMaxYCorner];

        self.cardView = [[UIView alloc] initWithFrame:self.contentView.bounds];
        self.glassButton.tag = self.cellIndexPath.row; // or use a custom method to map section & row
        
        [self.glassButton addTarget:self action:@selector(mainScreenTap) forControlEvents:UIControlEventTouchUpInside];
        self.cardView.backgroundColor = UIColor.clearColor; // or clearColor
        [self.contentView addSubview:_cardView];

        // 3) Gradient behind everything inside cardView
        _bgGradientLayer = [CAGradientLayer layer];
        
        // 5) Foreground image
        _imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _imageView.contentMode = UIViewContentModeScaleAspectFit;
        _imageView.translatesAutoresizingMaskIntoConstraints = NO;
        //_imageView.backgroundColor = AppPrimaryClrWithAlpha(0.0); // or clearColor
        _imageView.userInteractionEnabled = NO;
        //[_cardView addSubview:_BackImage];
        [self addSubview:self.glassButton];
        self.glassButton.translatesAutoresizingMaskIntoConstraints = NO;
        

        // Action
        //[self.glassButton addTarget:self action:@selector(glassTapped:) forControlEvents:UIControlEventTouchUpInside];

        [NSLayoutConstraint activateConstraints:@[
            [self.glassButton.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [self.glassButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [self.glassButton.widthAnchor constraintEqualToAnchor:self.widthAnchor],
            [self.glassButton.heightAnchor constraintEqualToAnchor:self.heightAnchor],
        ]];
        
        [self.glassButton addSubview:_imageView];
       
        // 6) Name overlay + label
        _nameView = [[UIView alloc] initWithFrame:CGRectZero];
        [self addSubview:_nameView];
    
        if(Language.isRTL)
            self.overlay = [self createBottomBlurOnView:self.glassButton tl:PPCornersMainCell tr:8 bl:18 br:PPCornersMainCell];
        else
            self.overlay = [self createBottomBlurOnView:self.glassButton tl:18 tr:PPCornersMainCell bl:PPCornersMainCell+3 br:8];
        self.overlay.alpha = 0;
        _nameLabel = [[PPInsetLabel alloc] initWithFrame:CGRectZero];
        _nameLabel.textAlignment = NSTextAlignmentCenter ;// (Language.languageVal == 0) ? NSTextAlignmentLeft : NSTextAlignmentRight;
        _nameLabel.font = [GM boldFontWithSize:16];
        _nameLabel.textColor = GM.PrimaryTextColor;
        _nameLabel.backgroundColor = [GM.AppForegroundColor colorWithAlphaComponent:0.0];
        _nameLabel.textInsets = UIEdgeInsetsMake(5, 10, 5, 10);
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
       
        
        
        // Add text shadow
        //[self.glassButton addSubview:_overlay];
        _nameLabel.layer.masksToBounds = NO;                        // must be NO for shadow to show
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.glassButton addSubview:_nameLabel];
       

        // --- Small badge under name (icon + text) ---
        _metaBadgeView = [[UIView alloc] initWithFrame:CGRectZero];
        _metaBadgeView.backgroundColor = [GM.AppForegroundColor colorWithAlphaComponent:0.0];

        _metaIconView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _metaIconView.contentMode = UIViewContentModeScaleAspectFit;
        _metaIconView.tintColor = GM.PrimaryTextColor; // use tintable asset for consistent color

        _metaLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _metaLabel.font = [GM boldFontWithSize:14];
        _metaLabel.textColor = GM.PrimaryTextColor;

        [_metaBadgeView addSubview:_metaIconView];
        [_metaBadgeView addSubview:_metaLabel];
        [_cardView addSubview:_metaBadgeView];

        // Example default content (you will override per cell)
        
         self.contentView.backgroundColor = UIColor.clearColor; // important
         self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        
    }
    return self;
}
- (UIColor *)mixColor:(UIColor *)c1 with:(UIColor *)c2 {
    CGFloat r1, g1, b1, a1;
    CGFloat r2, g2, b2, a2;
    [c1 getRed:&r1 green:&g1 blue:&b1 alpha:&a1];
    [c2 getRed:&r2 green:&g2 blue:&b2 alpha:&a2];

    return [UIColor colorWithRed:(r1 + r2) / 2.0
                           green:(g1 + g2) / 2.0
                            blue:(b1 + b2) / 2.0
                           alpha:(a1 + a2) / 2.0];
}

- (void)configureWithMainKindModel:(MainKindsModel *)model atIndexPath:(NSIndexPath *)indexPath {
    self.cellIndexPath = indexPath;
    // 1) Image & name
    self.imageView.image = model.KindImageFile;
  
    // 2) Hide BackImage unless you want overlays
    self.BackImage.hidden = YES;
    self.nameLabel.text = model.KindName;
    [self.nameLabel sizeToFit];
    
    UIImage *colorsImage = model.KindImageFile;
    NSArray<UIColor *> *colors = [self extractTwoMainColorsFromImage:colorsImage
                                                     andLightenAmount:model.LightenAmount ?: 0.45f];
    UIColor *fallback0 = GM.AppForegroundColor ?: [UIColor colorWithWhite:0.92 alpha:1.0];
    UIColor *fallback1 = AppBackgroundClrLigter ?: [UIColor colorWithWhite:0.82 alpha:1.0];
    UIColor *fallback2 = [fallback0 colorWithAlphaComponent:0.75];

    UIColor *safe0 = [self pp_safeColorInArray:colors atIndex:0 fallback:fallback0];
    UIColor *safe1 = [self pp_safeColorInArray:colors atIndex:1 fallback:fallback1];
    UIColor *safe2 = [self pp_safeColorInArray:colors atIndex:2 fallback:fallback2];
    UIColor *safe3 = [self pp_safeColorInArray:colors atIndex:3 fallback:safe1];
    UIColor *safe4 = [self pp_safeColorInArray:colors atIndex:4 fallback:safe2];

    if (colors.count >= 5) {

        UIColor *c1 = safe0;
        UIColor *c3 = safe2;
        UIColor *c5 = safe4;

        CGFloat professionalAngle = (Language.languageVal == 1) ? 30.0 : 135.0;
        professionalAngle = model.professionalAngle;

        // Use first, middle, last for a smooth 5-color blend
        [self setBackgroundGradientFrom:[c1 colorWithAlphaComponent:1.0]
                           middleColor:[c3 colorWithAlphaComponent:1.0]
                                    to:[c5 colorWithAlphaComponent:1.0]
                                 angle:professionalAngle];

    } else if (colors.count >= 4) {

        UIColor *c1 = safe0;
        UIColor *c2 = safe1;
        UIColor *c3 = safe2;
        UIColor *c4 = safe3;

        CGFloat professionalAngle = (Language.languageVal == 1) ? 30.0 : 135.0;
        professionalAngle = model.professionalAngle;

        // Use first, second/third blended, last
        UIColor *mid = [self mixColor:c2 with:c3];
        [self setBackgroundGradientFrom:[c1 colorWithAlphaComponent:1.0]
                           middleColor:[mid colorWithAlphaComponent:1.0]
                                    to:[c4 colorWithAlphaComponent:1.0]
                                 angle:professionalAngle];

    } else if (colors.count >= 3) {
        
        UIColor *c1 = safe0;
        UIColor *c2 = safe1;
        UIColor *c3 = safe2;

        CGFloat professionalAngle = (Language.languageVal == 1) ? 30.0 : 135.0;
        professionalAngle = model.professionalAngle;

        [self setBackgroundGradientFrom:[c1 colorWithAlphaComponent:1.0]
                           middleColor:[c3 colorWithAlphaComponent:1.0]
                                    to:[c2 colorWithAlphaComponent:1.0]
                                 angle:professionalAngle];

    } else if (colors.count >= 2) {

        UIColor *c1 = safe0;
        UIColor *c2 = safe1;

        CGFloat professionalAngle = (Language.languageVal == 1) ? 30.0 : 135.0;
        professionalAngle = model.professionalAngle;

        [self setBackgroundGradientFrom:c1
                           middleColor:c1
                                    to:c2
                                 angle:professionalAngle];

    } else {

        [self setBackgroundGradientFrom:GM.AppForegroundColor
                           middleColor:AppBackgroundClrLigter
                                    to:[GM.AppForegroundColor colorWithAlphaComponent:0.7]
                                 angle:135.0];
    }
    
    
  
    
    self.metaBadgeView.hidden = YES;
    if (indexPath.item == 0 || indexPath.item == 1) {
        self.nameLabel.textAlignment = GM.setAligment;
        self.imageView.contentMode   = UIViewContentModeScaleToFill;
    } else if ( indexPath.item == 4 || indexPath.item == 3) {
        self.nameLabel.textAlignment = GM.setAligment;
        self.imageView.contentMode   = UIViewContentModeScaleAspectFit;
    } else {
      
        self.imageView.contentMode   = UIViewContentModeScaleAspectFit;
    }
    self.nameLabel.textAlignment = NSTextAlignmentCenter;
    
    // Apply shadow settings (best practice)
    self.imageView.layer.masksToBounds = YES;
    self.imageView.clipsToBounds = YES;
  
    UIImage *img = model.ID == 2 ? [UIImage imageNamed:@"EB_Reds"] : self.imageView.image;
    
    CALayer *imageLayer = [CALayer layer];
    imageLayer.contents = model.ID == 2 ? (__bridge id)img.CGImage : (__bridge id)img.CGImage;
    imageLayer.frame = CGRectMake(1, 1, self.contentView.hx_w - 2, self.contentView.hx_h - 2);
    
    imageLayer.contentsGravity = kCAGravityCenter;
    imageLayer.masksToBounds = YES;
    imageLayer.opacity = 1.5;   // Adjust 0.0 – 1.0
    _bgGradientLayer.opacity = 0.0;
    // Optional: corner radius match
    //imageLayer.cornerRadius = yourView.layer.cornerRadius;

    // Insert as background (bottom-most)
    //[self.glassButton.layer insertSublayer:_bgGradientLayer atIndex:0];
    imageLayer.cornerRadius =  55;
    imageLayer.masksToBounds = YES;
     self.cardView.layer.cornerRadius = 55;
    if(PPIOS26())
    {
       
        //[self.glassButton.layer insertSublayer:imageLayer atIndex:0];
       // [self.cardView.layer insertSublayer:_bgGradientLayer atIndex:0];
    }
    else
    {
        [self.glassButton.layer insertSublayer:imageLayer atIndex:0];
        [self.glassButton.layer insertSublayer:_bgGradientLayer atIndex:1];
    }
    UIColor *c1 = safe2;
    
    if (indexPath.item == 1)
        c1 = safe2;
    if (indexPath.item == 3)
        c1 = safe1;
    if (indexPath.item == 4)
        c1 = safe1;
    if (indexPath.item == 1)
        c1 = safe2;
    if (indexPath.item == 10)
        c1 = safe3;
    //c1=UIColor.clearColor;
    
    UIButtonConfiguration *Gconfig = _glassButton.configuration;
    Gconfig.background.backgroundColor = [c1 colorWithAlphaComponent:0.6];
    _glassButton.configuration = Gconfig;
    [_glassButton setNeedsLayout];

    _nameLabel.backgroundColor = [c1 colorWithAlphaComponent:1.0];
    _currentColor = [c1 colorWithAlphaComponent:1.0];
    
 
     [self.glassButton updateConfiguration];
    [self.glassButton setNeedsLayout];
    [self setNeedsLayout];
    [self layoutSubviews];
}




- (void)applyCornerMaskToView:(UIView *)view
                           tl:(CGFloat)tl
                           tr:(CGFloat)tr
                           bl:(CGFloat)bl
                           br:(CGFloat)br
{
    [view layoutIfNeeded];
    CGRect bounds = view.bounds;
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
    view.layer.mask = mask;
    
    
}



- (void)layoutSubviews {
    [super layoutSubviews];

    _cardView.frame    = CGRectMake(0.5, 0.5, self.hx_w - 1, self.hx_h - 1);
    //_cardView.layer.cornerRadius = PPCornersMainCell+10;
    // Must keep gradient sized to card
    _bgGradientLayer.frame = _cardView.bounds;
    //_bgGradientLayer.opacity = 1.0;
    
    // Content layout
    CGFloat w = _cardView.bounds.size.width;
    CGFloat h = _cardView.bounds.size.height;
    
    
     
    CGFloat innerPad = 8.0; // inside badge between icon and text
    CGFloat iconSide = 14.0;

    [_metaLabel sizeToFit];
    
    CGFloat badgeW = iconSide + innerPad + _metaLabel.bounds.size.width + innerPad + 10;
    badgeW = w - 20;
    CGFloat badgeH = 24.0;

    // Respect LTR/RTL using your Language.languageVal
    BOOL isLTR = (Language.languageVal == 0);
    CGFloat badgeX = isLTR ? 10.0 : (w - 10.0 - badgeW);
    CGFloat badgeY = h - 25; // a bit below the title

    _metaBadgeView.frame = CGRectMake(badgeX, badgeY, badgeW, badgeH);

    // Icon & text inside the pill
    _metaIconView.frame = CGRectMake(innerPad, (badgeH - iconSide)/2.0, iconSide, iconSide);
    CGFloat textX = CGRectGetMaxX(_metaIconView.frame) + 6.0;
    _metaLabel.frame = CGRectMake(textX, (badgeH - _metaLabel.font.lineHeight)/2.0 - 1.0,
                                  _metaLabel.bounds.size.width, _metaLabel.font.lineHeight);
    
    
    [NSLayoutConstraint activateConstraints:@[

        [self.nameLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-0],
        [self.nameLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:0],

    ]];
    
       // Apply shadow settings (best practice)
    self.contentView.layer.masksToBounds = NO;
    self.contentView.clipsToBounds = NO;
    [self.contentView pp_setShadowColor:[UIColor.blackColor colorWithAlphaComponent:1.0]];
    self.contentView.layer.shadowRadius = 5;
    self.contentView.layer.shadowOpacity = 0.5;
    self.contentView.layer.shadowOffset = CGSizeMake(0, 0);

       // Use shadowPath for better performance
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                                     cornerRadius:55].CGPath;

       // Optional: rasterize for offscreen caching (boosts performance in scrolling cells)
    self.contentView.layer.shouldRasterize = YES;
    self.contentView.layer.rasterizationScale = UIScreen.mainScreen.scale;
    self.contentView.clipsToBounds = NO;
    
    
     
    self.contentView.backgroundColor = AppClearClr;
    self.imageView.backgroundColor = AppClearClr;
    self.backgroundColor = AppClearClr;
    self.backgroundColor = AppClearClr;
    self.cardView.backgroundColor = AppClearClr;

    self.semanticContentAttribute = GM.setSemantic;
    self.contentView.semanticContentAttribute = GM.setSemantic;
    [self.glassButton bringSubviewToFront:_overlay];
    [self bringSubviewToFront:_nameLabel];
    
    if(_cellIndexPath.item == 7 || _cellIndexPath.item == 8)
    {
        [self applyCornerMaskToView:_nameLabel tl:4  tr:4 bl:_glassButton.layer.cornerRadius  br:_glassButton.layer.cornerRadius];
        [self.nameLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-0].active = YES;
    }
    else
        [self applyCornerMaskToView:_nameLabel tl:_glassButton.layer.cornerRadius  tr:8 bl:16.0 br:_glassButton.layer.cornerRadius];
    
    [self addLiquidGlassBorderToView:_glassButton cornerRadius:_glassButton.configuration.background.cornerRadius];
 
}


- (void)addLiquidGlassBorderToView:(UIView *)view cornerRadius:(float)cornerRadius{
    // Remove any old effect
    for (CALayer *layer in view.layer.sublayers.copy) {
        if ([layer.name isEqualToString:@"liquidGlassBorder"]) {
            [layer removeFromSuperlayer];
        }
    }
    
    // Outer glow
    CALayer *glow = [CALayer layer];
    glow.name = @"liquidGlassBorder";
    glow.frame = view.bounds;
    glow.cornerRadius = cornerRadius;
    glow.borderWidth = 0.5;
    glow.borderColor = [[_currentColor colorWithAlphaComponent:0.1] CGColor];
    glow.shadowColor = AppShadowClr.CGColor;
    glow.shadowOpacity = 0.4;
    glow.shadowRadius = 6;
    glow.shadowOffset = CGSizeMake(0, 0);
    glow.shouldRasterize = YES;
    glow.rasterizationScale = UIScreen.mainScreen.scale;
    [view.layer addSublayer:glow];
    
    // Keep it updated on layout
    glow.needsDisplayOnBoundsChange = YES;
    
    
   
    
     // Animate shimmer (slow)
     CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
     anim.fromValue = @0;
     anim.toValue = @(M_PI * 2);
     anim.duration = 12.0;
     anim.repeatCount = HUGE_VALF;
    [glow addAnimation:anim forKey:@"liquidShimmer"];
     
}



- (CGFloat)widthForText:(NSString *)text withFont:(UIFont *)font {
    if (text.length == 0) return 0;
    CGSize size = [text sizeWithAttributes:@{NSFontAttributeName: font}];
    return ceil(size.width); // round up for pixel-perfect rendering
}



- (void)setMetaText:(NSString *)text iconNamed:(NSString *)iconName {
    _metaLabel.text = text ?: @"";
    [_metaLabel sizeToFit];

    UIImage *icon = nil;
    if (@available(iOS 13.0, *)) {
        // Prefer SF Symbol if you like:
        // icon = [UIImage systemImageNamed:@"pawprint.fill"];
    }
    if (!icon) {
        icon = [[UIImage imageNamed:iconName ?: @"cat_badge"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    _metaIconView.image = icon;
    _metaIconView.tintColor = GM.SecondaryTextColor;

    [self setNeedsLayout];
}



#pragma mark - Appearance helpers (unchanged)
- (void)layoutStyle {
    //[GM gardToView:_nameView colorOne:[GM.AppShadowColor colorWithAlphaComponent:0.0] colorTwo:[GM.AppShadowColor colorWithAlphaComponent:0.5] colorThree:[GM.AppShadowColor colorWithAlphaComponent:0.7] rds:0];
}


- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    
    // Check if the userInterfaceStyle has changed
    if (@available(iOS 12.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                //NSLog(@"🌙 Dark Mode activated ---- >> MainAppCell");
                [self layoutStyle];
            } else {
                //NSLog(@"☀️ Light Mode activated ---- >> MainAppCell");
                [self layoutStyle];
            }
        }
    }
}


- (NSArray<UIColor *> *)extractTwoMainColorsFromImage:(UIImage *)image andLightenAmount:(float)amount {
    if (!image) {
        NSLog(@"⚠️ extractTwoMainColorsFromImage: image is nil → fallback colors");
        return @[AppPrimaryClrShiner, AppPrimaryClrDarker];
    }
    
    //NSLog(@"🎨 Starting color extraction with lightenAmount: %f", amount);
    
    // Downscale for speed
    CGSize thumbSize = CGSizeMake(20, 20);
    UIGraphicsBeginImageContext(thumbSize);
    [image drawInRect:CGRectMake(0, 0, thumbSize.width, thumbSize.height)];
    UIImage *thumbImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    CGImageRef cgImage = thumbImage.CGImage;
    NSUInteger width = CGImageGetWidth(cgImage);
    NSUInteger height = CGImageGetHeight(cgImage);
    //NSLog(@"🎨 Thumbnail size: %lux%lu", (unsigned long)width, (unsigned long)height);
    
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
            if (brightness < 0.3) continue;
            
            // Quantize
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
        UIColor *lightened = [self lightenColor:color amount:amount];
        
        //NSLog(@"🎨 Candidate color: %@ → Lightened: %@", color, lightened);
        
        [colors addObject:lightened];
        if (colors.count >= 5) break;
    }
    
    if (colors.count < 2) {
        //NSLog(@"⚠️ extractTwoMainColorsFromImage: less than 2 dominant colors found, fallback.");
        return @[[UIColor colorWithWhite:1 alpha:0.6], [UIColor colorWithWhite:0.95 alpha:0.6]];
    }
    
    //NSLog(@"🎨 Final picked colors: %@ and %@", colors[0], colors[1]);
    return colors;
}

#pragma mark - Gradient setter (works with shadow)
- (void)setBackgroundGradientFrom:(UIColor *)startColor
                               middleColor:(UIColor *)middleColor
                               to:(UIColor *)endColor
                            angle:(CGFloat)degrees
{
    UIColor *safeStart = startColor ?: [UIColor colorWithWhite:0.92 alpha:1.0];
    UIColor *safeMiddle = middleColor ?: [UIColor colorWithWhite:0.86 alpha:1.0];
    UIColor *safeEnd = endColor ?: [UIColor colorWithWhite:0.80 alpha:1.0];

    _bgGradientLayer.colors = @[(__bridge id)safeStart.CGColor,(__bridge id)safeMiddle.CGColor,
                                (__bridge id)safeEnd.CGColor];
    _bgGradientLayer.locations = @[@0.0,@0.5, @1.0];

    CGFloat theta = degrees * (CGFloat)M_PI / 180.0;
    CGPoint start = CGPointMake(0.5 - 0.5 * cos(theta), 0.5 - 0.5 * sin(theta));
    CGPoint end   = CGPointMake(0.5 + 0.5 * cos(theta), 0.5 + 0.5 * sin(theta));
    _bgGradientLayer.startPoint = start;
    _bgGradientLayer.endPoint   = end;
    _bgGradientLayer.cornerRadius=55;
    
    
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



- (void)addTapAnimationToView:(UIView *)view {
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleCardTap:)];
    [view addGestureRecognizer:tap];
    view.userInteractionEnabled = YES;
}

- (void)handleCardTap:(UITapGestureRecognizer *)tap {
    UIView *view = tap.view;
    
    [GM triggerHapticFeedback];
    
    [UIView animateWithDuration:0.1 animations:^{
        view.transform = CGAffineTransformMakeScale(0.95, 0.95);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.1 animations:^{
            view.transform = CGAffineTransformIdentity;
        }];
        [self.delegate mainScreenTapCellAtIndex:self.cellIndexP];
        // TODO: Handle actual navigation or action here
    }];
}

- (void)styleCardView:(UIView *)view {
    
}


- (void)cancelTapped {
    if (self.onCancelTap) {
        self.onCancelTap();
    }
}


- (UIButton *)setButtonAsBackroundButton:(NSString *)title icon:(NSString *)icon {
    UIButton *bgButton;
    if (@available(iOS 26.0, *)) {
        // 🧊 iOS 26+ system glass button
        UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(12, 12, 12, 12);
 
        if (icon.length > 0) {
            cfg.image = [UIImage systemImageNamed:icon];
            cfg.preferredSymbolConfigurationForImage =
                [UIImageSymbolConfiguration configurationWithPointSize:16
                                                                weight:UIImageSymbolWeightMedium
                                                                 scale:UIImageSymbolScaleMedium];
        }
        if (title.length > 0) {
            cfg.title = title;
            cfg.titleTextAttributesTransformer =
            ^NSDictionary<NSAttributedStringKey, id> * (NSDictionary<NSAttributedStringKey, id> *attrs) {
                NSMutableDictionary *m = [attrs mutableCopy];
                m[NSFontAttributeName] = [GM boldFontWithSize:16];
                return m;
            };
        }


        bgButton = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
        bgButton.configuration = cfg;
    } else {
        // 🌫️ Fallback for iOS <26
        bgButton = [UIButton buttonWithType:UIButtonTypeSystem];
        bgButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
        bgButton.layer.cornerRadius = PPCornersMainCell;
        [bgButton pp_setShadowColor:AppShadowClr];
        bgButton.layer.shadowOpacity = 0.15;
        bgButton.layer.shadowRadius = 8;
        bgButton.layer.shadowOffset = CGSizeMake(0, 4);
        bgButton.clipsToBounds = YES;
       
        if (icon.length > 0) {
            [bgButton setImage:[UIImage systemImageNamed:icon] forState:UIControlStateNormal];
        }
        if (title.length > 0) {
            [bgButton setTitle:title forState:UIControlStateNormal];
            [bgButton.titleLabel setFont:[GM boldFontWithSize:16]];
        }
    }

    bgButton.translatesAutoresizingMaskIntoConstraints = NO;
    bgButton.layer.cornerRadius = PPCornersMainCell;
    bgButton.clipsToBounds = NO;
    return bgButton;
}

- (PPCornerBlurView *)createBottomBlurOnView:(UIView *)cardView
                                 tl:(CGFloat)tl
                                 tr:(CGFloat)tr
                                 bl:(CGFloat)bl
                                 br:(CGFloat)br
{
    
    PPCornerBlurView *overlay = [PPCornerBlurView new];
    overlay.translatesAutoresizingMaskIntoConstraints = NO;
    overlay.userInteractionEnabled = NO;
    overlay.clipsToBounds = NO;
    overlay.tag = 9991;

     
    overlay.clipsToBounds = NO;
    overlay.layer.masksToBounds = NO;
    // Check if one already exists (e.g., during cell reuse)
    for (UIView *sub in cardView.subviews) {
        if (sub.tag == 9991) {
            [sub removeFromSuperview];
        }
    }

    // --- Modern blur on iOS 18+, gradient fallback below ---
    if (@available(iOS 18.0, *)) {
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]; //UIBlurEffectStyleLight //UIBlurEffectStyleSystemThinMaterial
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        blurView.translatesAutoresizingMaskIntoConstraints = NO;
        blurView.alpha = 0.95;
        [overlay addSubview:blurView];
        [NSLayoutConstraint activateConstraints:@[
            [blurView.topAnchor constraintEqualToAnchor:overlay.topAnchor],
            [blurView.bottomAnchor constraintEqualToAnchor:overlay.bottomAnchor],
            [blurView.leadingAnchor constraintEqualToAnchor:overlay.leadingAnchor],
            [blurView.trailingAnchor constraintEqualToAnchor:overlay.trailingAnchor]
        ]];
 
    } else {
        // Gradient fallback for older iOS
        CAGradientLayer *gradient = [CAGradientLayer layer];
        gradient.colors = @[
            (id)[UIColor colorWithWhite:0 alpha:0.55].CGColor,
            (id)[UIColor clearColor].CGColor
        ];
        gradient.startPoint = CGPointMake(0.5, 1.0);
        gradient.endPoint = CGPointMake(0.5, 0.0);
        [overlay.layer insertSublayer:gradient atIndex:0];

        // Resize gradient on layout
        gradient.needsDisplayOnBoundsChange = YES;
    }

    [cardView addSubview:overlay];

    // Layout overlay
    [NSLayoutConstraint activateConstraints:@[
        [overlay.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:2],
        [overlay.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-2],
        //[overlay.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:4],
     ]];

    // 🔸 Store corner values for later re-masking on resize
    overlay.layer.name = [NSString stringWithFormat:@"tl%.1f_tr%.1f_bl%.1f_br%.1f", tl, tr, bl, br];

    // Apply mask now
    [overlay pp_ApplyCornerMask_tl:tl tr:tr bl:bl br:br];

    // Observe layout changes to keep corners correct
   // __weak typeof(self) weakSelf = self;
    __weak typeof(overlay) weakOverlay = overlay;
    overlay.layoutSubviewsBlock = ^{
        __strong typeof(weakOverlay) overlay = weakOverlay;
        [overlay pp_ApplyCornerMask_tl:tl tr:tr bl:bl br:br];
    };
    return overlay;
}




- (UIButton *)setButtonAsBackroundButtonWithStyle:(UIButtonConfigurationCornerStyle)style  masked:(CACornerMask)masked{
    if (@available(iOS 26.0, *)) {
        return [self setButtonAsBackroundButtonWithStyle:style configType:PPButtonConfigrationGlass masked:masked];
    } else {
        return [self setButtonAsBackroundButtonWithStyle:style configType:PPButtonConfigrationFilled  masked:masked];
    }
}

- (UIButton *)setButtonAsBackroundButtonWithStyle:(UIButtonConfigurationCornerStyle)style configType:(PPButtonConfigration)configType masked:(CACornerMask)masked{
    UIButton *bgButton;
    
    

    
    if (@available(iOS 26.0, *)) {
        // 🧊 iOS 26+ system glass button
        UIButtonConfiguration *cfg = configType == PPButtonConfigrationGlass ? [UIButtonConfiguration glassButtonConfiguration] :
        configType == PPButtonConfigrationClearGlass ? [UIButtonConfiguration glassButtonConfiguration] :
        configType == PPButtonConfigrationFilled ? [UIButtonConfiguration filledButtonConfiguration] :
        configType == PPButtonConfigrationPromp ? [UIButtonConfiguration prominentGlassButtonConfiguration] :
        configType == PPButtonConfigrationClearPromp ? [UIButtonConfiguration prominentClearGlassButtonConfiguration] :
        configType == PPButtonConfigrationTintedBorderd ? [UIButtonConfiguration borderedTintedButtonConfiguration] :
        configType == PPButtonConfigrationTinted ? [UIButtonConfiguration tintedButtonConfiguration] : [UIButtonConfiguration plainButtonConfiguration] ;
        
        
        cfg.cornerStyle = style;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(12, 12, 12, 12);
        cfg.background.cornerRadius = 4.0;
 

        bgButton = [UIButton  buttonWithType:UIButtonTypeSystem];
        bgButton.configuration = cfg;
        bgButton.clipsToBounds = NO;
        bgButton.layer.cornerRadius = 16.0;
        bgButton.layer.maskedCorners = masked;
        
     } else {
         
 
        // 🌫️ Fallback for iOS <26
        bgButton = [UIButton buttonWithType:UIButtonTypeSystem];
        bgButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
        bgButton.layer.cornerRadius = PPCornersMainCell;
        [bgButton pp_setShadowColor:AppShadowClr];
        bgButton.layer.shadowOpacity = 0.15;
        bgButton.layer.shadowRadius = 16.0;
        bgButton.layer.shadowOffset = CGSizeMake(0, 4);
    }

    bgButton.translatesAutoresizingMaskIntoConstraints = NO;
 
    return bgButton;
}


@end
















