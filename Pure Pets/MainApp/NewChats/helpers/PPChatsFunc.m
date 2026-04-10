//
//  PPChatsFunc.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 19/01/2026.
//

#import "PPChatsFunc.h"
#import "CitiesManager.h"
#import "CountryModel.h"
  

@implementation PPChatsFunc
 

#pragma mark - Currency Formatting Helper

// Helper to format currency using locale-aware NSNumberFormatter
+ (NSString *)formattedCurrency:(CGFloat)value
{
    // Always use en_QA so digits are Latin (0-9) while keeping QAR symbol (ر.ق).
    // Arabic-Indic digits (٠-٩) must never appear in prices.
    NSString *countryISO = @"QA";
    NSLocale *formatterLocale = [[NSLocale alloc] initWithLocaleIdentifier:
                                 [NSString stringWithFormat:@"en_%@", countryISO]];

    NSString *currencyCode = @"QAR";

    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    formatter.locale = formatterLocale;
    formatter.currencyCode = currencyCode;
    formatter.maximumFractionDigits = 2;
    formatter.minimumFractionDigits = 2;
    formatter.roundingMode = NSNumberFormatterRoundHalfUp;

    NSString *formatted = [formatter stringFromNumber:@(value)];
    if (formatted.length > 0 && [formatted rangeOfString:@"¤"].location == NSNotFound) {
        return [self pp_forceLatinDigits:formatted];
    }

    // Fallback (never show generic currency sign)
    NSNumberFormatter *decimalFormatter = [[NSNumberFormatter alloc] init];
    decimalFormatter.numberStyle = NSNumberFormatterDecimalStyle;
    decimalFormatter.locale = formatterLocale;
    decimalFormatter.maximumFractionDigits = 2;
    decimalFormatter.minimumFractionDigits = 2;
    decimalFormatter.roundingMode = NSNumberFormatterRoundHalfUp;

    NSString *amount = [decimalFormatter stringFromNumber:@(value)] ?: @"0.00";
    return [self pp_forceLatinDigits:
            [NSString stringWithFormat:@"%@ %@", amount, @"ر.ق"]];
}

#pragma mark - Latin Digit Enforcement

+ (NSString *)pp_forceLatinDigits:(NSString *)input
{
    if (!input.length) return input;
    NSMutableString *result = [input mutableCopy];
    // Arabic-Indic digits ٠١٢٣٤٥٦٧٨٩ → 0123456789
    NSDictionary *map = @{
        @"٠": @"0", @"١": @"1", @"٢": @"2", @"٣": @"3", @"٤": @"4",
        @"٥": @"5", @"٦": @"6", @"٧": @"7", @"٨": @"8", @"٩": @"9",
        // Extended Arabic-Indic (Farsi/Urdu) ۰۱۲۳۴۵۶۷۸۹
        @"۰": @"0", @"۱": @"1", @"۲": @"2", @"۳": @"3", @"۴": @"4",
        @"۵": @"5", @"۶": @"6", @"۷": @"7", @"۸": @"8", @"۹": @"9"
    };
    for (NSString *key in map) {
        [result replaceOccurrencesOfString:key
                                withString:map[key]
                                   options:0
                                     range:NSMakeRange(0, result.length)];
    }
    return [result copy];
}

/*
 switch (position) {

     case PPChatGroupPositionSingle:
         if (incoming) {
             bl = s;
             
         } else {
             
             br = s;
         }
         break;

     case PPChatGroupPositionFirst:
         if (incoming) {
             bl = s;
             br = s;
         } else {
             bl = s;
             br = s;
         }
         break;

     case PPChatGroupPositionMiddle:
         if (incoming) {
             tl = s; bl = s;
             tr = s; br = s;
         } else {
             tl = s; bl = s;
             tr = s; br = s;
         }
         break;

     case PPChatGroupPositionLast:
         if (incoming) {
             tl = s;
             tr = s;
             bl = s;
         } else {
             br = s;
             tr = s;
             tl = s;
         }
         break;
 }+ (void)applyMaskToBubble:(UIView *)bubble
 isIncoming:(BOOL)isIncoming
groupPosition:(PPChatGroupPosition)position
{
// Force final layout first (CRITICAL)
[bubble layoutIfNeeded];

CGRect b = bubble.bounds;
if (CGRectIsEmpty(b)) return;

//CGFloat s = 6.0;         // stack radius (middle)

CGFloat r = position == PPChatGroupPositionSingle ? 26.0 : 26.0;        // main radius
CGFloat s = 8.0;         // stack radius (middle)


CGFloat tl = r, tr = r, bl = r, br = r;

BOOL incoming = isIncoming;

if (incoming) {
//bl = s;

} else {

//br = s;
}

switch (position) {

case PPChatGroupPositionSingle:
if (incoming) {
  //bl = s;
  
} else {
  
  //br = s;
}

//tl = 26; tr =  26; bl =  26; br = r;

break;

case PPChatGroupPositionFirst:
if (incoming) {
  //bl = s;
 // br = s;
} else {
 // bl = s;
  //br = s;
}
break;

case PPChatGroupPositionMiddle:
if (incoming) {
 // tl = s; bl = s;
 // tr = s; br = s;
} else {
 // tl = s; bl = s;
 //tr = s; br = s;
}
break;

case PPChatGroupPositionLast:
if (incoming) {
  //tl = s;
  //tr = s;
  bl = s;
} else {
  br = s;
  //tr = s;
  //tl = s;
}
break;
}

UIBezierPath *path = [UIBezierPath bezierPath];
CGFloat w = b.size.width;
CGFloat h = b.size.height;

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

bubble.layer.mask = mask;
}
 */





+ (void)applyBubbleMask:(UIView *)bubble
             isIncoming:(BOOL)isIncoming
          groupPosition:(PPChatGroupPosition)position
               showGlow:(BOOL)showGlow
{
    // ⚠️ Must layout first
    [bubble layoutIfNeeded];

    CGRect b = bubble.bounds;
    if (CGRectIsEmpty(b)) return;

    // === Radius system ===
    CGFloat R = b.size.height < 64.0 ? b.size.height/2 : 26.0;   // main bubble radius
    CGFloat S = 8.0;    // stacked / connected radius

    CGFloat tl = R, tr = R, bl = R, br = R;

    BOOL incoming = isIncoming;

    switch (position) {

        case PPChatGroupPositionSingle:
            // All corners rounded
            break;

        case PPChatGroupPositionFirst:
            if (incoming) {
                bl = S;
            } else {
                br = S;
            }
            break;

        case PPChatGroupPositionMiddle:
            if (incoming) {
                tl = S;
                bl = S;
            } else {
                tr = S;
                br = S;
            }
            break;

        case PPChatGroupPositionLast:
            if (incoming) {
                tl = S;
            } else {
                tr = S;
            }
            break;
    }
    
    
    // Build bubble path FIRST
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat w = b.size.width;
    CGFloat h = b.size.height;

    [path moveToPoint:CGPointMake(0, tl)];
    [path addQuadCurveToPoint:CGPointMake(tl, 0) controlPoint:CGPointZero];

    [path addLineToPoint:CGPointMake(w - tr, 0)];
    [path addQuadCurveToPoint:CGPointMake(w, tr)
                 controlPoint:CGPointMake(w, 0)];

    [path addLineToPoint:CGPointMake(w, h - br)];
    [path addQuadCurveToPoint:CGPointMake(w - br, h)
                 controlPoint:CGPointMake(w, h)];

    [path addLineToPoint:CGPointMake(bl, h)];
    [path addQuadCurveToPoint:CGPointMake(0, h - bl)
                 controlPoint:CGPointMake(0, h)];

    [path closePath];
    
    
    CAShapeLayer *mask = (CAShapeLayer *)bubble.layer.mask;
    if (![mask isKindOfClass:CAShapeLayer.class]) {
        mask = [CAShapeLayer layer];
        bubble.layer.mask = mask;
    }

    CGPathRef newPath = path.CGPath;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    mask.frame = b;
    [CATransaction commit];

    if (mask.path) {
        CABasicAnimation *anim =
            [CABasicAnimation animationWithKeyPath:@"path"];
        anim.fromValue = (__bridge id)mask.path;
        anim.toValue   = (__bridge id)newPath;
        anim.duration  = 0.28;
        anim.timingFunction =
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [mask addAnimation:anim forKey:@"pp_liquid_merge"];
    }

    mask.path = newPath;
 
}

+ (void)applyGlowIfNeededToBubble:(UIView *)bubble
                             path:(UIBezierPath *)path
                         showGlow:(BOOL)showGlow
                       isIncoming:(BOOL)isIncoming
{
    static NSString *kGlowLayerName = @"pp_bubble_glow";

    // Remove old glow (reuse-safe)
    for (CALayer *l in bubble.layer.sublayers.copy) {
        if ([l.name isEqualToString:kGlowLayerName]) {
            [l removeFromSuperlayer];
        }
    }

    if (!showGlow) return;

    CAShapeLayer *glow = [CAShapeLayer layer];
    glow.name = kGlowLayerName;
    glow.path = path.CGPath;
    glow.fillColor = UIColor.clearColor.CGColor;

    UIColor *glowColor = isIncoming
    ? [UIColor.secondaryLabelColor colorWithAlphaComponent:0.4]
    : [AppPrimaryClrDarker colorWithAlphaComponent:0.75];

    glow.strokeColor = glowColor.CGColor;
    glow.lineWidth = 1.2;
    glow.shadowColor = glowColor.CGColor;
    glow.shadowRadius = 6.0;
    glow.shadowOpacity = 1.0;
    glow.shadowOffset = CGSizeMake(0, 2);

    bubble.layer.masksToBounds = NO;
    [bubble.layer addSublayer:glow];
}










+ (UIButton *)buttonWithSystemName:(NSString *)imageName
                        buttonSide:(float)side
                            target:(id)target
                            action:(nullable SEL)action {
    NSParameterAssert(imageName.length > 0);

    UIButton *btn = nil;
    CGFloat size = side > 0 ? side : 44.0;

    if (@available(iOS 26.0, *)) {
        // ✅ iOS 26 Glass Button
        UIButtonConfiguration *cfg =
            [UIButtonConfiguration glassButtonConfiguration];

        cfg.contentInsets = NSDirectionalEdgeInsetsMake(8, 8, 8, 8);
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;

        UIImageSymbolConfiguration *symCfg = [UIImageSymbolConfiguration
            configurationWithPointSize:18
                                weight:UIImageSymbolWeightMedium
                                 scale:UIImageSymbolScaleMedium];

        cfg.image = [[UIImage systemImageNamed:imageName]
            imageByApplyingSymbolConfiguration:symCfg];

        cfg.baseForegroundColor = AppPrimaryTextClr;
        cfg.background.backgroundColor = UIColor.clearColor;
        cfg.baseBackgroundColor = UIColor.clearColor;

        btn = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    } else if (@available(iOS 15.0, *)) {
        // ✅ iOS 15–25 modern config
        UIButtonConfiguration *cfg =
            [UIButtonConfiguration plainButtonConfiguration];

        cfg.contentInsets = NSDirectionalEdgeInsetsMake(8, 8, 8, 8);
        cfg.background.backgroundColor =
            [[UIColor labelColor] colorWithAlphaComponent:0.08];
        cfg.background.cornerRadius = size * 0.5;

        UIImageSymbolConfiguration *symCfg = [UIImageSymbolConfiguration
            configurationWithPointSize:18
                                weight:UIImageSymbolWeightMedium];

        cfg.image = [[UIImage systemImageNamed:imageName]
            imageByApplyingSymbolConfiguration:symCfg];
        cfg.baseForegroundColor = AppPrimaryTextClr;

        btn = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    } else {
        // ✅ Legacy fallback
        btn = [UIButton buttonWithType:UIButtonTypeSystem];
        UIImage *img = [UIImage systemImageNamed:imageName];
        [btn setImage:img forState:UIControlStateNormal];
        btn.tintColor = AppPrimaryTextClr;
        btn.backgroundColor =
            [[UIColor labelColor] colorWithAlphaComponent:0.08];
        btn.layer.cornerRadius = size * 0.5;
    }

    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn.widthAnchor constraintEqualToConstant:size].active = YES;
    [btn.heightAnchor constraintEqualToConstant:size].active = YES;

    btn.layer.masksToBounds = YES;

    if (target && action) {
        [btn addTarget:target
                      action:action
            forControlEvents:UIControlEventTouchUpInside];
    }

    return btn;
}
@end


/* *************************** PPWaveformView  *************************** */



@interface PPChatGradientView ()
@property (nonatomic, strong) CAGradientLayer *gradientLayer;
@end

@implementation PPChatGradientView

- (instancetype)init
{
    self = [super init];
    if (!self) return nil;

    self.userInteractionEnabled = NO;

    _gradientLayer = [CAGradientLayer layer];
    _gradientLayer.colors = @[
        (id)[UIColor.blackColor colorWithAlphaComponent:0.18].CGColor,
        (id)[UIColor.clearColor CGColor]
    ];

    [self.layer addSublayer:_gradientLayer];
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.gradientLayer.frame = self.bounds;
}

- (void)applyTopGradient
{
    self.gradientLayer.startPoint = CGPointMake(0.5, 0.0);
    self.gradientLayer.endPoint   = CGPointMake(0.5, 1.0);
}

- (void)applyBottomGradient
{
    self.gradientLayer.startPoint = CGPointMake(0.5, 1.0);
    self.gradientLayer.endPoint   = CGPointMake(0.5, 0.0);
}

@end
















 
@import FirebaseStorage;

@interface PPChatBackgroundManager ()
@property (nonatomic, strong) NSCache *imageCache;
@end

@implementation PPChatBackgroundManager

+ (instancetype)shared
{
    static PPChatBackgroundManager *m;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        m = [[PPChatBackgroundManager alloc] init];
    });
    return m;
}

- (instancetype)init
{
    self = [super init];
    if (!self) return nil;

    _imageCache = [[NSCache alloc] init];

    return self;
}

#pragma mark - Public

- (void)fetchRandomChatBackground:(void (^)(UIImage * _Nullable))completion
{
    NSInteger index = arc4random_uniform(19) + 1;
    [self fetchChatBackgroundAtIndex:index completion:completion];
}

- (void)fetchChatBackgroundAtIndex:(NSInteger)index
                        completion:(void (^)(UIImage * _Nullable))completion
{
    NSString *key = [NSString stringWithFormat:@"%ld", (long)index];

    UIImage *cached = [self.imageCache objectForKey:key];
    if (cached) {
        if (completion) completion(cached);
        return;
    }

    // Storage path: ChatBGs/1.jpg ... ChatBGs/10.jpg
    NSString *path =
        [NSString stringWithFormat:@"ChatsBgs/%@.jpeg", key];

    FIRStorageReference *ref =
        [[FIRStorage storage] referenceWithPath:path];

    [ref dataWithMaxSize:10 * 1024 * 1024
              completion:^(NSData * _Nullable data, NSError * _Nullable error) {

        if (error || !data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil);
            });
            return;
        }

        UIImage *image = [UIImage imageWithData:data];
        if (image) {
            [self.imageCache setObject:image forKey:key];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(image);
        });
    }];
}

@end

























@interface PPChatBackgroundPickerController ()
@property (nonatomic, assign) NSInteger selectedIndex;
@property (nonatomic, copy) void (^selectionBlock)(NSInteger);
@property (nonatomic, strong) UICollectionView *collectionView;
@end

@implementation PPChatBackgroundPickerController

- (instancetype)initWithSelectedIndex:(NSInteger)index
                            selection:(void (^)(NSInteger))selection
{
    if (self = [super init]) {
        _selectedIndex = index;
        _selectionBlock = selection;
        self.modalPresentationStyle = UIModalPresentationPageSheet;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = PPBackgroundColorForIOS26(UIColor.systemBackgroundColor);
    [self setupCollection];
}

- (void)setupCollection
{
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.itemSize = CGSizeMake(110, 180);
    layout.minimumLineSpacing = 16;
    layout.minimumInteritemSpacing = 12;
    layout.sectionInset = UIEdgeInsetsMake(20, 16, 20, 16);

    UICollectionView *cv =
        [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    cv.translatesAutoresizingMaskIntoConstraints = NO;
    cv.backgroundColor = UIColor.clearColor;

    [cv registerClass:UICollectionViewCell.class
forCellWithReuseIdentifier:@"cell"];

    cv.dataSource = self;
    cv.delegate = self;

    [self.view addSubview:cv];
    self.collectionView = cv;

    [NSLayoutConstraint activateConstraints:@[
        [cv.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [cv.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [cv.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [cv.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

#pragma mark - UICollectionView

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section
{
    return 19;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)cv
                           cellForItemAtIndexPath:(NSIndexPath *)ip
{
    UICollectionViewCell *cell =
        [cv dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:ip];

    UIImageView *iv = [cell.contentView viewWithTag:100];
    if (!iv) {
        iv = [[UIImageView alloc] initWithFrame:cell.contentView.bounds];
        iv.tag = 100;
        iv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        iv.contentMode = UIViewContentModeScaleAspectFill;
        iv.clipsToBounds = YES;
        iv.layer.cornerRadius = 14;
        [cell.contentView addSubview:iv];
    }

    NSInteger index = ip.item + 1;

    [[PPChatBackgroundManager shared]
     fetchChatBackgroundAtIndex:index
     completion:^(UIImage *image) {
        iv.image = image;
    }];

    cell.layer.borderWidth = (index == self.selectedIndex) ? 2 : 0;
    cell.layer.borderColor = UIColor.systemBlueColor.CGColor;

    return cell;
}

- (void)collectionView:(UICollectionView *)cv
didSelectItemAtIndexPath:(NSIndexPath *)ip
{
    NSInteger index = ip.item + 1;

    if (self.selectionBlock) {
        self.selectionBlock(index);
    }

    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

























//
//  PPAmazingBar.m
//  PurePets
//
//  Implementation of PPAmazingBar with dynamic text, voice, media.
//  All UI is built with Auto Layout and constraint animations.
//
 
@interface PPAmazingBar () <UITextViewDelegate, AVAudioRecorderDelegate, AVAudioPlayerDelegate, UINavigationControllerDelegate>

@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIVisualEffectView *vibrancyView;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UIButton *attachButton;
@property (nonatomic, strong) UIButton *recordButton;
@property (nonatomic, strong) UIButton *sendButton;

@property (nonatomic, strong) UIView *recordingContainer; // holds waveform & controls
@property (nonatomic, strong) UIImageView *waveformImageView;
@property (nonatomic, strong) UIButton *playPauseButton;
@property (nonatomic, strong) UIButton *cancelButton;

// Audio properties
@property (nonatomic, strong) AVAudioRecorder *audioRecorder;
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;
@property (nonatomic, strong) NSURL *recordedAudioURL;
@property (nonatomic, assign) NSTimeInterval recordingDuration;

// Constraints
@property (nonatomic, strong) NSLayoutConstraint *textViewHeightConstraint;

// State flags
@property (nonatomic, assign) BOOL isRecording;
@property (nonatomic, assign) BOOL isPreviewing;

@end

@implementation PPAmazingBar

#pragma mark - Init

- (instancetype)initWithMaxLines:(NSInteger)maxLines {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _maxLines = maxLines > 0 ? maxLines : 5;
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    return [self initWithMaxLines:5];
}

- (void)commonInit {
    self.backgroundColor = [UIColor clearColor];
    [self setupBlurBackground];
    [self setupSubviews];
    [self setupLayout];
    [self setupAudioSession];
}

#pragma mark - Subviews Setup

- (void)setupBlurBackground {
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    self.blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    self.blurView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.blurView];
    
    UIVibrancyEffect *vibrancy = [UIVibrancyEffect effectForBlurEffect:blurEffect];
    self.vibrancyView = [[UIVisualEffectView alloc] initWithEffect:vibrancy];
    self.vibrancyView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.blurView.contentView addSubview:self.vibrancyView];
    
    // Blur & vibrancy fill entire bar
    [NSLayoutConstraint activateConstraints:@[
        [self.blurView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.blurView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.blurView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.blurView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [self.vibrancyView.leadingAnchor constraintEqualToAnchor:self.blurView.contentView.leadingAnchor],
        [self.vibrancyView.trailingAnchor constraintEqualToAnchor:self.blurView.contentView.trailingAnchor],
        [self.vibrancyView.topAnchor constraintEqualToAnchor:self.blurView.contentView.topAnchor],
        [self.vibrancyView.bottomAnchor constraintEqualToAnchor:self.blurView.contentView.bottomAnchor],
    ]];
}

- (void)setupSubviews {
    // Attach Button (left)
    self.attachButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImage *attachImage = [UIImage systemImageNamed:@"paperclip"];
    [self.attachButton setImage:attachImage forState:UIControlStateNormal];
    self.attachButton.tintColor = [UIColor labelColor];
    self.attachButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.attachButton addTarget:self action:@selector(handleAttach) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.attachButton];
    
    // Text View (center)
    self.textView = [[UITextView alloc] init];
    self.textView.translatesAutoresizingMaskIntoConstraints = NO;
    self.textView.delegate = self;
    self.textView.backgroundColor = [UIColor clearColor];
    self.textView.layer.cornerRadius = 16;
    self.textView.textContainerInset = UIEdgeInsetsMake(8, 8, 8, 8);
    self.textView.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.textView.textColor = [UIColor labelColor];
    self.textView.scrollEnabled = NO;
    self.textView.text = @"";
    [self addSubview:self.textView];
    
    // Record Button (right, default to mic)
    self.recordButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImage *micImage = [UIImage systemImageNamed:@"mic.fill"];
    [self.recordButton setImage:micImage forState:UIControlStateNormal];
    self.recordButton.tintColor = [UIColor labelColor];
    self.recordButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.recordButton addTarget:self action:@selector(recordButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    // Long press gesture for hold-to-record
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(recordButtonLongPressed:)];
    longPress.minimumPressDuration = 0.3;
    [self.recordButton addGestureRecognizer:longPress];
    [self addSubview:self.recordButton];
    
    // Send Button (initially hidden)
    self.sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImage *sendImage = [UIImage systemImageNamed:@"paperplane.fill"];
    [self.sendButton setImage:sendImage forState:UIControlStateNormal];
    self.sendButton.tintColor = [UIColor labelColor];
    self.sendButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.sendButton addTarget:self action:@selector(sendButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    self.sendButton.alpha = 0; // hidden by default
    [self addSubview:self.sendButton];
    
    // Recording Preview Container (hidden by default)
    self.recordingContainer = [[UIView alloc] init];
    self.recordingContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.recordingContainer.backgroundColor = [UIColor systemGray6Color];
    self.recordingContainer.layer.cornerRadius = 16;
    self.recordingContainer.clipsToBounds = YES;
    self.recordingContainer.alpha = 0;
    [self addSubview:self.recordingContainer];
    
    // Waveform (static image or generated view; using image placeholder here)
    self.waveformImageView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"waveform.path"]];
    self.waveformImageView.tintColor = [UIColor systemBlueColor];
    self.waveformImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.recordingContainer addSubview:self.waveformImageView];
    
    // Play/Pause button in preview
    self.playPauseButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImage *playImage = [UIImage systemImageNamed:@"play.fill"];
    [self.playPauseButton setImage:playImage forState:UIControlStateNormal];
    self.playPauseButton.tintColor = [UIColor labelColor];
    self.playPauseButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.playPauseButton addTarget:self action:@selector(playPauseTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.recordingContainer addSubview:self.playPauseButton];
    
    // Cancel button in preview
    self.cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImage *cancelImage = [UIImage systemImageNamed:@"xmark.circle.fill"];
    [self.cancelButton setImage:cancelImage forState:UIControlStateNormal];
    self.cancelButton.tintColor = [UIColor systemRedColor];
    self.cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.cancelButton addTarget:self action:@selector(cancelRecording) forControlEvents:UIControlEventTouchUpInside];
    [self.recordingContainer addSubview:self.cancelButton];
}

#pragma mark - Layout

- (void)setupLayout {
    CGFloat padding = 8;
    CGFloat iconSize = 32;
    
    // Attach button at left
    [NSLayoutConstraint activateConstraints:@[
        [self.attachButton.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:padding],
        [self.attachButton.centerYAnchor constraintEqualToAnchor:self.textView.centerYAnchor],
        [self.attachButton.widthAnchor constraintEqualToConstant:iconSize],
        [self.attachButton.heightAnchor constraintEqualToConstant:iconSize],
    ]];
    
    // Record and Send buttons at right
    [NSLayoutConstraint activateConstraints:@[
        [self.recordButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-padding],
        [self.recordButton.centerYAnchor constraintEqualToAnchor:self.textView.centerYAnchor],
        [self.recordButton.widthAnchor constraintEqualToConstant:iconSize],
        [self.recordButton.heightAnchor constraintEqualToConstant:iconSize],
        
        [self.sendButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-padding],
        [self.sendButton.centerYAnchor constraintEqualToAnchor:self.textView.centerYAnchor],
        [self.sendButton.widthAnchor constraintEqualToConstant:iconSize],
        [self.sendButton.heightAnchor constraintEqualToConstant:iconSize],
    ]];
    
    // TextView constraints
    self.textViewHeightConstraint = [self.textView.heightAnchor constraintEqualToConstant:34];
    CGFloat maxTextHeight = self.textView.font.lineHeight * self.maxLines + self.textView.textContainerInset.top + self.textView.textContainerInset.bottom;
    self.textViewHeightConstraint.constant = 34; // initial single line height with padding
    [NSLayoutConstraint activateConstraints:@[
        [self.textView.leadingAnchor constraintEqualToAnchor:self.attachButton.trailingAnchor constant:padding],
        [self.textView.trailingAnchor constraintEqualToAnchor:self.recordButton.leadingAnchor constant:-padding],
        [self.textView.topAnchor constraintEqualToAnchor:self.topAnchor constant:padding],
        [self.textView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-padding],
        self.textViewHeightConstraint
    ]];
    
    // Recording container covers the same area as text view (for preview state)
    [NSLayoutConstraint activateConstraints:@[
        [self.recordingContainer.leadingAnchor constraintEqualToAnchor:self.attachButton.trailingAnchor constant:padding],
        [self.recordingContainer.trailingAnchor constraintEqualToAnchor:self.sendButton.leadingAnchor constant:-padding],
        [self.recordingContainer.topAnchor constraintEqualToAnchor:self.topAnchor constant:padding],
        [self.recordingContainer.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-padding],
    ]];
    
    // Waveform and controls inside recordingContainer
    [NSLayoutConstraint activateConstraints:@[
        [self.waveformImageView.leadingAnchor constraintEqualToAnchor:self.recordingContainer.leadingAnchor constant:8],
        [self.waveformImageView.trailingAnchor constraintEqualToAnchor:self.recordingContainer.trailingAnchor constant:-8],
        [self.waveformImageView.topAnchor constraintEqualToAnchor:self.recordingContainer.topAnchor constant:12],
        [self.waveformImageView.heightAnchor constraintEqualToConstant:24],
        
        [self.playPauseButton.leadingAnchor constraintEqualToAnchor:self.waveformImageView.leadingAnchor],
        [self.playPauseButton.topAnchor constraintEqualToAnchor:self.waveformImageView.bottomAnchor constant:8],
        [self.playPauseButton.widthAnchor constraintEqualToConstant:32],
        [self.playPauseButton.heightAnchor constraintEqualToConstant:32],
        
        [self.cancelButton.trailingAnchor constraintEqualToAnchor:self.waveformImageView.trailingAnchor],
        [self.cancelButton.topAnchor constraintEqualToAnchor:self.waveformImageView.bottomAnchor constant:8],
        [self.cancelButton.widthAnchor constraintEqualToConstant:32],
        [self.cancelButton.heightAnchor constraintEqualToConstant:32],
    ]];
}

#pragma mark - Keyboard Handling

- (void)didMoveToSuperview {
    [super didMoveToSuperview];
    if (@available(iOS 15.0, *)) {
        // Constrain bottom to keyboard (or safe area if no keyboard)
        UIView *sup = self.superview;
        if (sup) {
            self.translatesAutoresizingMaskIntoConstraints = NO;
            [NSLayoutConstraint activateConstraints:@[
                [self.leadingAnchor constraintEqualToAnchor:sup.leadingAnchor],
                [self.trailingAnchor constraintEqualToAnchor:sup.trailingAnchor],
                [self.bottomAnchor constraintEqualToAnchor:sup.keyboardLayoutGuide.topAnchor]
            ]];
        }
    } else {
        // Fallback for earlier (if needed, use keyboard notifications)
    }
}

#pragma mark - UITextViewDelegate (dynamic height)

- (void)textViewDidChange:(UITextView *)textView {
    // Toggle send vs mic button
    BOOL hasText = textView.text.length > 0;
    [UIView animateWithDuration:0.2 animations:^{
        self.sendButton.alpha = hasText ? 1 : 0;
        self.recordButton.alpha = hasText ? 0 : 1;
    }];
    
    // Resize text view height
    CGFloat maxHeight = self.textView.font.lineHeight * self.maxLines + self.textView.textContainerInset.top + self.textView.textContainerInset.bottom;
    CGSize size = [textView sizeThatFits:CGSizeMake(textView.frame.size.width, CGFLOAT_MAX)];
    BOOL shouldScroll = NO;
    CGFloat newHeight = size.height;
    if (newHeight > maxHeight) {
        newHeight = maxHeight;
        shouldScroll = YES;
    }
    self.textView.scrollEnabled = shouldScroll;
    // Update constraint if needed
    if (self.textViewHeightConstraint.constant != newHeight) {
        self.textViewHeightConstraint.constant = newHeight;
        [UIView animateWithDuration:0.1 animations:^{
            [self layoutIfNeeded];
        }];
    }
}

#pragma mark - Button Actions

- (void)sendButtonTapped {
    if (self.textView.text.length == 0) return;
    NSString *text = [self.textView.text copy];
    self.textView.text = @"";
    [self textViewDidChange:self.textView]; // update UI
    [self.delegate amazingBar:self didSendText:text];
}

- (void)handleAttach {
    // Use PPPickerBridge (Swift HXPhotoPicker bridge) for media selection
    PPPickerBridge *picker = [[PPPickerBridge alloc] init];
    [picker configureForMixedMediaWithMaxCount:9 useArabic:[kLang(@"lang") isEqualToString:@"ar"]];

    // Observe result via notification
    __weak typeof(self) weakSelf = self;
    id __block token = [[NSNotificationCenter defaultCenter]
        addObserverForName:@"PPPickerBridgeDidFinish"
                    object:nil
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *note) {
        [[NSNotificationCenter defaultCenter] removeObserver:token];
        NSArray<UIImage *> *images = [PPPickerBridge imagesFromNotification:note];
        if (images.count > 0) {
            [weakSelf.delegate amazingBar:(PPAmazingBar *)weakSelf didAttachMedia:images];
        }
    }];

    UIViewController *vc = [self topViewController];
    if (vc) {
        [picker presentPickerFromViewController:vc];
    }
}

#pragma mark - Recording Actions

- (void)recordButtonTapped:(UIButton *)sender {
    if (self.isRecording) {
        [self stopRecording];
    } else {
        [self startRecording];
    }
}

- (void)recordButtonLongPressed:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        [self startRecording];
    } else if (gesture.state == UIGestureRecognizerStateEnded ||
               gesture.state == UIGestureRecognizerStateCancelled) {
        [self stopRecording];
    }
}

- (void)startRecording {
    if (self.isRecording) return;
    self.isRecording = YES;
    // Update UI: hide text input, show recording container
    self.textView.hidden = YES;
    self.sendButton.enabled = NO;
    [self.recordButton setImage:[UIImage systemImageNamed:@"stop.fill"] forState:UIControlStateNormal];
    [self.delegate amazingBarDidStartRecording:self];
    
    // Start AVAudioRecorder
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"ppamazing_audio.m4a"];
    self.recordedAudioURL = [NSURL fileURLWithPath:path];
    NSDictionary *settings = @{
        AVFormatIDKey: @(kAudioFormatMPEG4AAC),
        AVSampleRateKey: @44100,
        AVNumberOfChannelsKey: @1
    };
    self.audioRecorder = [[AVAudioRecorder alloc] initWithURL:self.recordedAudioURL settings:settings error:nil];
    self.audioRecorder.delegate = self;
    [self.audioRecorder record];
    self.recordingDuration = 0;
    // Show recording UI
    [UIView animateWithDuration:0.3 animations:^{
        self.recordingContainer.alpha = 1.0;
    }];
}

- (void)stopRecording {
    if (!self.isRecording) return;
    self.isRecording = NO;
    [self.audioRecorder stop];
    self.audioRecorder.delegate = nil;
    self.audioRecorder = nil;
    [self.recordButton setImage:[UIImage systemImageNamed:@"stop.fill"] forState:UIControlStateNormal]; // stays as stop briefly
    // Switch to preview mode
    self.isPreviewing = YES;
    [self showRecordingPreview];
}

- (void)showRecordingPreview {
    // Recording is done; show preview controls
    [self.playPauseButton setImage:[UIImage systemImageNamed:@"play.fill"] forState:UIControlStateNormal];
    self.recordingDuration = [[AVAudioSession sharedInstance] outputLatency]; // placeholder if needed
}

- (void)playPauseTapped {
    if (self.audioPlayer.isPlaying) {
        [self.audioPlayer pause];
        [self.playPauseButton setImage:[UIImage systemImageNamed:@"play.fill"] forState:UIControlStateNormal];
    } else {
        NSError *error;
        self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:self.recordedAudioURL error:&error];
        self.audioPlayer.delegate = self;
        [self.audioPlayer play];
        [self.playPauseButton setImage:[UIImage systemImageNamed:@"pause.fill"] forState:UIControlStateNormal];
    }
}

- (void)cancelRecording {
    // Discard recording and revert UI
    [self.audioPlayer stop];
    self.audioPlayer = nil;
    self.recordedAudioURL = nil;
    self.isPreviewing = NO;
    [UIView animateWithDuration:0.3 animations:^{
        self.recordingContainer.alpha = 0.0;
    } completion:^(BOOL finished) {
        self.textView.hidden = NO;
        [self.recordButton setImage:[UIImage systemImageNamed:@"mic.fill"] forState:UIControlStateNormal];
        self.sendButton.enabled = YES;
    }];
}

#pragma mark - AVAudioRecorderDelegate

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
    if (flag) {
        // Notify delegate that recording is ready to send
        if ([self.delegate respondsToSelector:@selector(amazingBar:didSendRecording:duration:)]) {
            NSTimeInterval duration = recorder.currentTime;
            self.recordingDuration = duration;
            [self.delegate amazingBar:self didSendRecording:self.recordedAudioURL duration:duration];
        }
    } else {
        // Recording failed; reset UI
        [self cancelRecording];
    }
}

#pragma mark - Media Picker (legacy delegate removed — now uses PPPickerBridge notifications)

#pragma mark - Helpers

- (UIViewController *)topViewController {
    // Find the topmost view controller to present modals
    UIViewController *root = UIApplication.sharedApplication.windows.firstObject.rootViewController;
    UIViewController *vc = root;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}

- (void)setupAudioSession {
    // Request permission and configure session
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session requestRecordPermission:^(BOOL granted) {
        // Handle if needed
    }];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [session setActive:YES error:nil];
}

@end
