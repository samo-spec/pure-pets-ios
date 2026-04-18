//
//  PPS.h
//  PurePetsAdmin
//
//  Created by Mohammed Ahmed on 24/08/2025.
//


//  PPS.m

#import "PPS.h"
#import <QuartzCore/QuartzCore.h>

#pragma mark - Helpers: Padded TextField

@interface PPS_PaddedTextField : UITextField
@property (nonatomic) UIEdgeInsets textInsets;
@end

@implementation PPS_PaddedTextField
- (CGRect)textRectForBounds:(CGRect)bounds { return UIEdgeInsetsInsetRect([super textRectForBounds:bounds], self.textInsets); }
- (CGRect)editingRectForBounds:(CGRect)bounds { return UIEdgeInsetsInsetRect([super editingRectForBounds:bounds], self.textInsets); }
- (CGRect)placeholderRectForBounds:(CGRect)bounds { return UIEdgeInsetsInsetRect([super placeholderRectForBounds:bounds], self.textInsets); }
@end

#pragma mark - String Normalization & Fuzzy

static NSString *PPNormalize(NSString *s, BOOL caseInsensitive, BOOL diacriticsInsensitive) {
    if (!s) return @"";
    NSString *result = [s copy];

    if (diacriticsInsensitive) {
        result = [result stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale currentLocale]];
    }
    if (caseInsensitive) {
        result = result.lowercaseString;
    }

    // Simple Arabic unifications (helps typo tolerance)
    // ا/أ/إ/آ -> ا , ى/ي -> ي , ة -> ه
    result = [result stringByReplacingOccurrencesOfString:@"أ" withString:@"ا"];
    result = [result stringByReplacingOccurrencesOfString:@"إ" withString:@"ا"];
    result = [result stringByReplacingOccurrencesOfString:@"آ" withString:@"ا"];
    result = [result stringByReplacingOccurrencesOfString:@"ى" withString:@"ي"];
    result = [result stringByReplacingOccurrencesOfString:@"ة" withString:@"ه"];

    // Arabic digits → Latin digits
    NSDictionary<NSString *, NSString *> *digitMap = @{
        @"٠":@"0",@"١":@"1",@"٢":@"2",@"٣":@"3",@"٤":@"4",
        @"٥":@"5",@"٦":@"6",@"٧":@"7",@"٨":@"8",@"٩":@"9"
    };
    for (NSString *k in digitMap) { result = [result stringByReplacingOccurrencesOfString:k withString:digitMap[k]]; }

    return result;
}





static NSInteger PPLevenshtein(NSString *a, NSString *b) {
    if (!a || !b) return NSIntegerMax/4;
    NSUInteger n = a.length, m = b.length;
    if (n == 0) return (NSInteger)m;
    if (m == 0) return (NSInteger)n;

    // Simple DP with rolling rows
    NSMutableData *prevRowData = [NSMutableData dataWithLength:(m+1)*sizeof(NSInteger)];
    NSMutableData *currRowData = [NSMutableData dataWithLength:(m+1)*sizeof(NSInteger)];
    NSInteger *prev = prevRowData.mutableBytes;
    NSInteger *curr = currRowData.mutableBytes;

    for (NSUInteger j=0;j<=m;j++) prev[j] = (NSInteger)j;

    for (NSUInteger i=1;i<=n;i++) {
        curr[0] = (NSInteger)i;
        unichar ca = [a characterAtIndex:i-1];
        for (NSUInteger j=1;j<=m;j++) {
            unichar cb = [b characterAtIndex:j-1];
            NSInteger cost = (ca == cb) ? 0 : 1;
            NSInteger del = prev[j] + 1;
            NSInteger ins = curr[j-1] + 1;
            NSInteger sub = prev[j-1] + cost;
            NSInteger v = MIN(MIN(del, ins), sub);
            curr[j] = v;
        }
        // swap
        NSInteger *tmp = prev; prev = curr; curr = tmp;
    }
    return prev[m];
}

static CGFloat PPRelevanceScore(NSString *query, NSString *candidate) {
    if (candidate.length == 0) return 0;
    if ([candidate containsString:query]) return 1.0; // direct substring wins
    NSInteger d = PPLevenshtein(query, candidate);
    CGFloat denom = MAX(query.length, candidate.length);
    return MAX(0.f, 1.f - ((CGFloat)d / denom)); // 1..0
}

#pragma mark - PPS

@interface PPS ()
@property (nonatomic, strong) UIVisualEffectView *blurView;

@property (nonatomic, strong) UIView *strokeView;
@property (nonatomic, strong) UIStackView *hStack;
@property (nonatomic, strong) PPS_PaddedTextField *tf;

@property (nonatomic, strong) NSTimer *debounceTimer;
@property (nonatomic) NSInteger searchGeneration;
@property (nonatomic, strong) dispatch_queue_t searchQueue;

@property (nonatomic) BOOL isEditing;
// Fuzzy store
@property (nonatomic, copy) NSArray *items;
@property (nonatomic, copy) NSArray<NSString *> *normalizedIndex;
@property (nonatomic, copy) PPSearchStringProvider stringProvider;

@property (nonatomic, copy) NSArray<NSArray<NSString *> *> *normalizedFieldsPerItem; // each item -> array of normalized field strings
@property (nonatomic, copy) NSArray<NSString *> *searchKeyPaths;
@property (nonatomic, copy) PPMultiStringProvider multiProvider;

// --- UISearchBar-style Cancel Button ---
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, strong) NSLayoutConstraint *ppsTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *cancelWidthConstraint;
@property (nonatomic) BOOL isInEditingState;

@end

@implementation PPS


-(void)setAlpha:(CGFloat)alpha
{
    self.glassView.alpha = alpha;
    self.hStack.alpha = alpha;

}
#pragma mark Init

- (void)setSearchItems:(NSArray *)items keyPaths:(NSArray<NSString *> *)keyPaths {
    self.items = items ?: @[];
    self.searchKeyPaths = keyPaths ?: @[];
    self.multiProvider = nil;
    self.stringProvider = nil;

    BOOL ci = self.caseInsensitive, di = self.diacriticsInsensitive;
    NSMutableArray *perItem = [NSMutableArray arrayWithCapacity:self.items.count];

    for (id it in self.items) {
        NSMutableArray<NSString *> *fields = [NSMutableArray array];
        for (NSString *kp in self.searchKeyPaths) {
            id v = nil;
            @try { v = [it valueForKeyPath:kp]; } @catch (__unused NSException *e) { v = nil; }
            if ([v isKindOfClass:NSString.class]) {
                [fields addObject:PPNormalize((NSString *)v, ci, di)];
            } else if ([v isKindOfClass:NSArray.class]) {
                // If a field is an array of strings (e.g., tags)
                for (id s in (NSArray *)v) if ([s isKindOfClass:NSString.class]) {
                    [fields addObject:PPNormalize((NSString *)s, ci, di)];
                }
            }
        }
        [perItem addObject:fields.copy];
    }
    self.normalizedFieldsPerItem = perItem.copy;
}

- (void)setSearchItems:(NSArray *)items multiStringProvider:(PPMultiStringProvider)provider {
    self.items = items ?: @[];
    self.multiProvider = provider;
    self.searchKeyPaths = nil;
    self.stringProvider = nil;

    BOOL ci = self.caseInsensitive, di = self.diacriticsInsensitive;
    NSMutableArray *perItem = [NSMutableArray arrayWithCapacity:self.items.count];

    for (id it in self.items) {
        NSArray<NSString *> *raw = provider ? provider(it) : @[];
        NSMutableArray<NSString *> *norm = [NSMutableArray arrayWithCapacity:raw.count];
        for (NSString *s in raw) { [norm addObject:PPNormalize(s ?: @"", ci, di)]; }
        [perItem addObject:norm.copy];
    }
    self.normalizedFieldsPerItem = perItem.copy;
}


- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) { [self commonInit]; }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) { [self commonInit]; }
    return self;
}

- (void)updateGlassBackgroundColor:(UIColor *)color
                           opacity:(CGFloat)opacity
{
    if (@available(iOS 26.0, *)) {

        // Defensive: configuration may be nil
        UIButtonConfiguration *cfg =
        self.glassView
            .configuration ?: [UIButtonConfiguration clearGlassButtonConfiguration];

        UIColor *baseColor = color ?: UIColor.labelColor;
        CGFloat alpha = MAX(0.0, MIN(opacity, 1.0));

        cfg.background.backgroundColor =
        [baseColor colorWithAlphaComponent:alpha];

        // Preserve corner + insets
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;

        self.glassView
            .configuration = cfg;
    }
}

- (void)commonInit {
    self.backgroundColor = UIColor.clearColor;
    
    self.isEditing = NO;
    self.dateButton =
    [[PPGlassDateButton alloc] initWithFrame:CGRectZero];
    
    self.dateButton.translatesAutoresizingMaskIntoConstraints = NO;
    //self.dateButton.sizeVariant = PPGlassDateButtonSizeCompact; // default
    // or
    //self.dateButton.sizeVariant = PPGlassDateButtonSizeLarge;
    
    [self addSubview:self.dateButton];
    self.showsDateButton = NO;
   
    // Change date later
    [self.dateButton setDate:NSDate.date animated:YES];

    // Tap action
    [self.dateButton addTarget:self
                        action:@selector(showDatePicker:)
         forControlEvents:UIControlEventTouchUpInside];
    
    _barStyle = PPSBarStyleSearch;
    _contentInsets = UIEdgeInsetsMake(8, 12, 8, 8);
    _cornerRadius = 30.0;
    _shadowEnabled = YES;
    _shadowColor = [UIColor colorWithWhite:0 alpha:1.0];
    _shadowOpacity = 0.08;
    _shadowRadius = 10;
    _shadowOffset = CGSizeMake(0, 4);
    
    _blurEnabled = YES;
    if (@available(iOS 13.0, *)) _blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
    else _blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    _glassAlpha = 1.0;
    _strokeColor = UIColor.clearColor;
    
    _debounceInterval = 0.18;
    _returnKeyType = UIReturnKeySearch;
    
    _fuzzyEnabled = YES;
    _maxEditDistance = 2;
    _minRelevanceScore = 0.55;
    _caseInsensitive = NO;
    _diacriticsInsensitive = YES;
    _maxResults = 50;
    _sortByRelevance = YES;
    
    _searchQueue = dispatch_queue_create("pp.search.queue", DISPATCH_QUEUE_CONCURRENT);
    
    if (@available(iOS 26.0, *)) {
        // iOS 26+ Glass background (no blur view)
        _glassView = [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleCapsule];
        _glassView.translatesAutoresizingMaskIntoConstraints = NO;
        
        _glassView.layer.cornerRadius = _cornerRadius;
        _glassView.layer.masksToBounds = YES;
        _glassView.layer.opacity = 1.0;
    } else {
        // iOS < 26 Blur background
        _blurView = [[UIVisualEffectView alloc] initWithEffect:_blurEffect];
        _blurView.translatesAutoresizingMaskIntoConstraints = NO;
        _blurView.alpha = _glassAlpha;
        _blurView.layer.cornerRadius = _cornerRadius;
        _blurView.layer.masksToBounds = YES;
    }
    
    // Optional 1px stroke for definition on bright backgrounds
    _strokeView = [UIView new];
    _strokeView.translatesAutoresizingMaskIntoConstraints = NO;
    _strokeView.userInteractionEnabled = NO;
    
    // Text field
    _tf = [PPS_PaddedTextField new];
    _tf.translatesAutoresizingMaskIntoConstraints = NO;
    _tf.textInsets = UIEdgeInsetsMake(0, 8, 0, 8);
    _tf.clearButtonMode = UITextFieldViewModeWhileEditing;
    _tf.returnKeyType = _returnKeyType;
    _tf.delegate = self;
    _tf.font = [GM MidFontWithSize:16];
    _tf.textAlignment = GM.setAligment;
    _tf.textColor = UIColor.labelColor;
    _tf.tintColor = AppPrimaryClr;
    _tf.placeholder = kLang(@"SearchHere");
    _tf.inputAccessoryView = nil;
    _tf.returnKeyType = UIReturnKeyDone;
    _tf.clearButtonMode = UITextFieldViewModeNever;
    _tf.returnKeyType = UIReturnKeyDone;
    _tf.inputAccessoryView = nil;
    
    
   
    
    // Buttons (hidden by default)
    _btn1 = [UIButton buttonWithType:UIButtonTypeSystem];
    _btn1.translatesAutoresizingMaskIntoConstraints = NO;
    _btn1.hidden = YES;
    //_btn1.tintColor = AppPrimaryClr;
    _btn2 = [UIButton buttonWithType:UIButtonTypeSystem];
    _btn2.translatesAutoresizingMaskIntoConstraints = NO;
    _btn2.hidden = YES;
    
   // _btn2.tintColor = AppPrimaryClr;
    [NSLayoutConstraint activateConstraints:@[
        [self.dateButton.widthAnchor constraintEqualToConstant:72],
        [self.dateButton.heightAnchor constraintEqualToConstant:56]
    ]];

    // Horizontal stack (LTR default) -> [ tf, btn1, btn2 ]
    _hStack = [[UIStackView alloc] initWithArrangedSubviews:@[_tf, self.dateButton, _btn1, _btn2]];
    _hStack.translatesAutoresizingMaskIntoConstraints = NO;
    _hStack.axis = UILayoutConstraintAxisHorizontal;
    _hStack.alignment = UIStackViewAlignmentCenter;
    _hStack.distribution = UIStackViewDistributionFill;
    _hStack.spacing = 8;

    // Container hierarchy
    if (@available(iOS 26.0, *)) {
        [self addSubview:_glassView];
        [NSLayoutConstraint activateConstraints:@[
             [_glassView.topAnchor constraintEqualToAnchor:self.topAnchor],
             [_glassView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
             [_glassView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
             [_glassView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        ]];
    } else {
        [self addSubview:_blurView];
        [NSLayoutConstraint activateConstraints:@[
             [_blurView.topAnchor constraintEqualToAnchor:self.topAnchor],
             [_blurView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
             [_blurView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
             [_blurView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        ]];
    }
    [self addSubview:_strokeView];
    [self addSubview:_hStack];

    // ===============================
    // Cancel button (UISearchBar-style)
    // ===============================
    _cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    _cancelButton.alpha = 0.0;
    _cancelButton.hidden = YES;
    [_cancelButton setTitle:kLang(@"Cancel") forState:UIControlStateNormal];
    _cancelButton.titleLabel.font = [GM MidFontWithSize:16];
    [_cancelButton setTitleColor:AppPrimaryClr forState:UIControlStateNormal];
    [_cancelButton addTarget:self
                      action:@selector(_cancelTapped)
            forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_cancelButton];

    // Constraints
    // Remove old hStack trailing constraint and replace with animatable trailing and cancel button constraints
    self.ppsTrailingConstraint =
        [_hStack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12];
    self.cancelWidthConstraint =
        [_cancelButton.widthAnchor constraintEqualToConstant:0];
    [NSLayoutConstraint activateConstraints:@[
        [_strokeView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_strokeView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_strokeView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_strokeView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

        [_hStack.topAnchor constraintEqualToAnchor:self.topAnchor constant:_contentInsets.top],
        [_hStack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        self.ppsTrailingConstraint,
        [_hStack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-_contentInsets.bottom],

        [_btn1.widthAnchor constraintEqualToConstant:44],
        [_btn1.heightAnchor constraintEqualToConstant:44],
        [_btn2.widthAnchor constraintEqualToConstant:44],
        [_btn2.heightAnchor constraintEqualToConstant:44],

        [_cancelButton.centerYAnchor constraintEqualToAnchor:_hStack.centerYAnchor],
        [_cancelButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
        self.cancelWidthConstraint,
    ]];

    // Corners & shadow (on self)
    self.layer.cornerRadius = _cornerRadius;
    self.layer.masksToBounds = NO;
    [self applyShadow];

    // Stroke 1px
    [self updateStroke];

    _tf.font = [GM MidFontWithSize:16];
    _tf.textAlignment = GM.setAligment;
    
    [_tf addTarget:self action:@selector(_textDidChange:) forControlEvents:UIControlEventEditingChanged];

}

#pragma mark - Public accessors
#pragma mark - Public accessors
- (void)showDatePicker:(UIButton *)sender
{
    // 🔐 Capture keyboard state BEFORE dismissing it
    BOOL wasEditing = self.tf.isFirstResponder;

    [self.dateButton presentDatePickerFrom:self.vcParent
                                 completion:^(NSDate * _Nonnull selectedDate) {

        // 🔁 Restore keyboard only if it was previously visible
        if (wasEditing) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [self.tf becomeFirstResponder];
            });
        }
    }];
}

- (UITextField *)textField { return _tf; }
- (UIButton *)primaryButton { return _btn1; }
- (UIButton *)secondaryButton { return _btn2; }
 
- (BOOL)focus { return [_tf becomeFirstResponder]; }
- (void)unfocus { [_tf resignFirstResponder]; }

#pragma mark - Config

- (void)setContentInsets:(UIEdgeInsets)contentInsets {
    _contentInsets = contentInsets;
    
    // Re-apply edge constraints
    [NSLayoutConstraint deactivateConstraints:self.constraints];
    [self commonInit]; // easiest safe refresh; for production, update constraints selectively
}

- (void)setCornerRadius:(CGFloat)cornerRadius {
    _cornerRadius = cornerRadius;
    self.layer.cornerRadius = cornerRadius;
    _blurView.layer.cornerRadius = cornerRadius;
}

// OS-aware blur/glass enable
- (void)setBlurEnabled:(BOOL)blurEnabled {
    _blurEnabled = blurEnabled;

    if (@available(iOS 26.0, *)) {
        _glassView.hidden = !blurEnabled;
    } else {
        _blurView.hidden = !blurEnabled;
    }
}

// OS-aware blur effect
- (void)setBlurEffect:(UIBlurEffect *)blurEffect {
    if (@available(iOS 26.0, *)) {
        return; // glass ignores blur effects
    }
    _blurEffect = blurEffect ?: _blurEffect;
    _blurView.effect = _blurEffect;
}

// OS-aware glass alpha
- (void)setGlassAlpha:(CGFloat)glassAlpha {
    _glassAlpha = glassAlpha;

    if (@available(iOS 26.0, *)) {
        _glassView.layer.opacity = glassAlpha;
    } else {
        _blurView.alpha = glassAlpha;
    }
}

- (void)setReturnKeyType:(UIReturnKeyType)returnKeyType {
    _returnKeyType = returnKeyType;
    _tf.returnKeyType = returnKeyType;
}

- (void)setShadowEnabled:(BOOL)shadowEnabled { _shadowEnabled = shadowEnabled; [self applyShadow]; }
- (void)setShadowColor:(UIColor *)shadowColor { _shadowColor = shadowColor ?: [UIColor colorWithWhite:0 alpha:1]; [self applyShadow]; }
- (void)setShadowOpacity:(CGFloat)shadowOpacity { _shadowOpacity = shadowOpacity; [self applyShadow]; }
- (void)setShadowRadius:(CGFloat)shadowRadius { _shadowRadius = shadowRadius; [self applyShadow]; }
- (void)setShadowOffset:(CGSize)shadowOffset { _shadowOffset = shadowOffset; [self applyShadow]; }

- (void)applyShadow {
    if (_shadowEnabled) {
        [self pp_setShadowColor:_shadowColor];
        self.layer.shadowOpacity = (float)_shadowOpacity;
        self.layer.shadowRadius = _shadowRadius;
        self.layer.shadowOffset = _shadowOffset;
        self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:self.cornerRadius].CGPath;
    } else {
        self.layer.shadowOpacity = 0.0;
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self applyShadow];
    [self updateStroke];
}

- (void)updateStroke {
    self.strokeView.layer.cornerRadius = self.cornerRadius;
    self.strokeView.layer.borderWidth = self.strokeColor == UIColor.clearColor ? 0.0 : 1.0 / UIScreen.mainScreen.scale;
    [self.strokeView pp_setBorderColor:self.strokeColor];
}

#pragma mark - Buttons

- (void)configurePrimaryButtonWithImage:(UIImage *)image target:(id)target action:(SEL)action {
    self.showsPrimaryButton = YES;
    if (image) { [_btn1 setImage:image forState:UIControlStateNormal]; }
    [_btn1 removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    if (target && action) { [_btn1 addTarget:target action:action forControlEvents:UIControlEventTouchUpInside]; }
    _btn1.hidden = !self.showsPrimaryButton;
}

#pragma mark - Button Configuration (iOS 26 Glass)

- (void)configureGlassButton:(UIButton *)button
                       image:(UIImage *)image
                      target:(id)target
                      action:(SEL)action
{
    NSAssert(button, @"❌ Button must not be nil");

    button.hidden = NO;
    button.userInteractionEnabled = YES;
    button.enabled = YES;

    if (@available(iOS 26.0, *)) {

        UIButtonConfiguration *cfg =
        [UIButtonConfiguration clearGlassButtonConfiguration];

        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.image = image;
        cfg.baseForegroundColor = AppPrimaryClr;
        

        cfg.contentInsets = NSDirectionalEdgeInsetsMake(8, 8, 8, 8);

        button.configuration = cfg;

    } else {

        // ✅ iOS 15–25 fallback (clean & tappable)
        UIButtonConfiguration *cfg =
        [UIButtonConfiguration plainButtonConfiguration];

        cfg.image = image;
        cfg.baseForegroundColor = AppPrimaryClr;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(8, 8, 8, 8);

        button.configuration = cfg;

        // Optional visual polish
        button.layer.cornerRadius = 20;
        button.backgroundColor =
            [AppPrimaryClr colorWithAlphaComponent:0.08];
    }

    // Target
    [button removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    if (target && action) {
        [button addTarget:target
                   action:action
         forControlEvents:UIControlEventTouchUpInside];
    }
}

- (void)configurePrimaryButtonWithImage:(UIImage *)image selectedImage:(UIImage *)selectedImage target:(id)target action:(SEL)action {
     self.showsPrimaryButton = YES;

        [self configureGlassButton:self.btn1
                             image:image
                            target:target
                            action:action];

        if (selectedImage) {
            [self.btn1 setImage:selectedImage forState:UIControlStateHighlighted];
        }
}
#pragma mark - Glass Button State Styling

- (void)configureGlassButton:(UIButton *)button
                       image:(UIImage *)image
               selectedImage:(UIImage *)selectedImage
                      target:(id)target
                      action:(SEL)action
{
    NSAssert(button, @"❌ Button must not be nil");

    button.hidden = NO;
    button.enabled = YES;
    button.userInteractionEnabled = YES;

    if (@available(iOS 26.0, *)) {

        // 🔹 NORMAL
        UIButtonConfiguration *normal =
        [UIButtonConfiguration clearGlassButtonConfiguration];

        normal.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        normal.image = image;
        normal.baseForegroundColor = AppPrimaryClr;
        
        normal.contentInsets = NSDirectionalEdgeInsetsMake(8, 8, 8, 8);

        // 🔹 SELECTED / HIGHLIGHTED
        UIButtonConfiguration *selected = normal.copy;
        selected.image = selectedImage ?: image;
        selected.baseForegroundColor = AppForgroundColr;
 
        button.configuration = normal;

        // ✅ State update handler (BEST PRACTICE)
        button.configurationUpdateHandler =
        ^(UIButton *btn) {

            if (btn.isSelected || btn.isHighlighted) {
                //btn.configuration = selected;
            } else {
                //btn.configuration = normal;
            }
        };

    } else {

        // ===== iOS ≤25 fallback =====

        UIButtonConfiguration *cfg =
        [UIButtonConfiguration plainButtonConfiguration];

        cfg.image = image;
        cfg.baseForegroundColor = AppPrimaryClr;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(8, 8, 8, 8);
        button.configuration = cfg;

        button.layer.cornerRadius = 20;
        
        // Selected colors
        [button setImage:selectedImage ?: image
                forState:UIControlStateSelected];

        [button setTintColor:AppPrimaryClr];

        //[button addTarget:self action:@selector(_legacyButtonStateFix:) forControlEvents:UIControlEventAllTouchEvents];
    }

    // Target
    [button removeTarget:nil action:NULL
        forControlEvents:UIControlEventTouchUpInside];

    if (target && action) {
        [button addTarget:target
                   action:action
         forControlEvents:UIControlEventTouchUpInside];
    }
}
- (void)configureSecondaryButtonWithImage:(UIImage *)image target:(id)target action:(SEL)action {
    self.showsSecondaryButton = YES;
    if (image) { [_btn2 setImage:image forState:UIControlStateNormal]; }
    [_btn2 removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    if (target && action) { [_btn2 addTarget:target action:action forControlEvents:UIControlEventTouchUpInside]; }
    _btn2.hidden = !self.showsSecondaryButton;
}



- (void)setShowsPrimaryButton:(BOOL)showsPrimaryButton {
    _showsPrimaryButton = showsPrimaryButton;
    _btn1.hidden = !showsPrimaryButton;
}

- (void)setShowsSecondaryButton:(BOOL)showsSecondaryButton {
    _showsSecondaryButton = showsSecondaryButton;
    _btn2.hidden = !showsSecondaryButton;
}


-(void)setShowsDateButton:(BOOL)showsDateButton
{
    _showsDateButton = showsDateButton;
    _dateButton.hidden = !showsDateButton;
}

#pragma mark - UITextFieldDelegate

- (void)_textDidChange:(UITextField *)sender {
    [self.debounceTimer invalidate];
    if (self.debounceInterval <= 0) {
        if ([self.delegate respondsToSelector:@selector(searchView:didChangeText:)]) {
            [self.delegate searchView:self didChangeText:sender.text ?: @""];
        }
        return;
    }
    __weak typeof(self) weakSelf = self;
    self.debounceTimer = [NSTimer scheduledTimerWithTimeInterval:self.debounceInterval repeats:NO block:^(NSTimer * _Nonnull t) {
        __strong typeof(weakSelf) self = weakSelf;
        if ([self.delegate respondsToSelector:@selector(searchView:didChangeText:)]) {
            [self.delegate searchView:self didChangeText:self->_tf.text ?: @""];
        }
    }];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    if(self.barStyle == PPSBarStyleSearch)
    {
        self.isEditing = YES;
        [self setEditingState:YES animated:YES];
    }
    
    if ([self.delegate respondsToSelector:@selector(searchViewDidBeginEditing:)]) {
        [self.delegate searchViewDidBeginEditing:self];
    }
}
- (void)textFieldDidEndEditing:(UITextField *)textField {
    if(self.barStyle == PPSBarStyleSearch)
    {
        self.isEditing = NO;
        [self setEditingState:NO animated:YES];
    }
    
    if ([self.delegate respondsToSelector:@selector(searchViewDidEndEditing:)]) {
        [self.delegate searchViewDidEndEditing:self];
    }
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if ([self.delegate respondsToSelector:@selector(searchViewDidSubmit:)]) {
        [self.delegate searchViewDidSubmit:self];
    }
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - UISearchBar-style Cancel Button Animation

- (UIButton *)cancelButton {
    return _cancelButton;
}

- (void)setEditingState:(BOOL)editing animated:(BOOL)animated
{
    
    if(self.barStyle == PPSBarStyleTextfield) return;
    // If ending editing but text still exists, keep editing-style UI
    if (!editing && self.tf.text.length > 0) {
        self.isInEditingState = NO;
        return;
    }

    if (self.isInEditingState == editing) return;
    self.isInEditingState = editing;

    CGFloat cancelTargetWidth = editing ? 54.0 : 0.0;
    CGFloat trailingTarget =
    editing ? -(cancelTargetWidth + 8 + 12) : -12;

    void (^changes)(void) = ^{
        BOOL shouldShowCancel = editing || self.tf.text.length > 0;
        self.cancelButton.hidden = NO;
        self.cancelButton.alpha = shouldShowCancel ? 1.0 : 0.0;
        self.cancelWidthConstraint.constant = cancelTargetWidth;
        self.ppsTrailingConstraint.constant = trailingTarget;
        [self layoutIfNeeded];
    };

    void (^completion)(BOOL) = ^(BOOL finished){
        if (!editing && self.tf.text.length == 0) {
            self.cancelButton.hidden = YES;
        }
    };

    if (!animated) {
        changes();
        completion(YES);
        return;
    }

    [UIView animateWithDuration:0.28
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:changes
                     completion:completion];
}

- (void)_cancelTapped
{
    self.tf.text = @"";
    [self.tf resignFirstResponder];
    [self setEditingState:NO animated:YES];

    if ([self.delegate respondsToSelector:@selector(searchView:didChangeText:)]) {
        [self.delegate searchView:self didChangeText:@""];
    }
}

#pragma mark - Fuzzy Search API

- (void)setSearchItems:(NSArray *)items stringProvider:(PPSearchStringProvider)provider {
    self.items = items ?: @[];
    self.stringProvider = provider;
    if (!provider) { self.normalizedIndex = @[]; return; }

    BOOL ci = self.caseInsensitive, di = self.diacriticsInsensitive;
    NSMutableArray<NSString *> *norm = [NSMutableArray arrayWithCapacity:self.items.count];
    for (id it in self.items) {
        NSString *s = provider(it) ?: @"";
        [norm addObject:PPNormalize(s, ci, di)];
    }
    self.normalizedIndex = norm;
}

- (void)filterAsyncForText:(NSString *)query completion:(PPSearchResultsHandler)completion {
    if (!self.fuzzyEnabled || query.length == 0 || !self.stringProvider) {
        if (completion) completion(query ?: @"", @[]);
        return;
    }

    NSString *normQ = PPNormalize(query, self.caseInsensitive, self.diacriticsInsensitive);
    NSInteger token = ++self.searchGeneration;
    NSArray *items = self.items;
    //NSArray<NSString *> *index = self.normalizedIndex;
    BOOL sortByRel = self.sortByRelevance;
    CGFloat minScore = self.minRelevanceScore;
    NSInteger maxResults = self.maxResults;

    dispatch_async(self.searchQueue, ^{
        NSMutableArray *results = [NSMutableArray array];
        NSMutableArray<NSNumber *> *scores = [NSMutableArray array];

        for (NSInteger i = 0; i < self.items.count; i++) {
            NSArray<NSString *> *fields = (self.normalizedFieldsPerItem.count > 0)
                ? self.normalizedFieldsPerItem[i]
                : (self.normalizedIndex.count > i ? @[ self.normalizedIndex[i] ] : @[]);

            CGFloat best = 0.f;
            for (NSString *cand in fields) {
                CGFloat s = PPRelevanceScore(normQ, cand);
                if (s > best) best = s;
                if (best >= 1.0) break; // exact substring in any field: early win
            }

            if (best >= minScore) {
                [results addObject:items[i]];
                [scores addObject:@(best)];
            }
        }

        if (sortByRel && results.count > 1) {
            NSArray *sorted = [results sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
                NSUInteger i1 = [results indexOfObjectIdenticalTo:obj1];
                NSUInteger i2 = [results indexOfObjectIdenticalTo:obj2];
                CGFloat s1 = scores[i1].doubleValue;
                CGFloat s2 = scores[i2].doubleValue;
                if (s1 > s2) return NSOrderedAscending;
                if (s1 < s2) return NSOrderedDescending;
                return NSOrderedSame;
            }];
            results = [sorted mutableCopy];
        }

        if (maxResults > 0 && results.count > maxResults) {
            results = [[results subarrayWithRange:NSMakeRange(0, maxResults)] mutableCopy];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (token == self.searchGeneration) { // latest query only
                if (completion) completion(query, results);
            }
        });
    });
}


- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    //[Styling applyBackgroundStyleForTableView:tableView cell:cell indexPath:indexPath useRowCardMode:NO buttonRowIndex:0 buttonSection:1];
}


@end



















 
@interface PPGlassDateButton ()
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIStackView *stackView;
@property (nonatomic, strong) UILabel *dayMonthLabel;
@property (nonatomic, strong) UILabel *yearLabel;
@property (nonatomic, strong) NSDateFormatter *dayMonthFormatter;
@property (nonatomic, strong) NSDateFormatter *yearFormatter;
@end

@implementation PPGlassDateButton

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        [self commonInit];
    }
    return self;
}

- (void)presentDatePickerFrom:(UIViewController *)controller
                    completion:(void (^ _Nullable)(NSDate *selectedDate))completion
{
    if (!controller) return;

    // Always dismiss keyboard first
    [controller.view endEditing:YES];

    if (@available(iOS 26.0, *)) {

        UIViewController *pickerVC = [UIViewController new];
        pickerVC.view.backgroundColor =
            [AppForgroundColr colorWithAlphaComponent:0.5];

        UIDatePicker *picker = [UIDatePicker new];
        picker.translatesAutoresizingMaskIntoConstraints = NO;
        picker.datePickerMode = UIDatePickerModeDate;
        picker.preferredDatePickerStyle = UIDatePickerStyleInline;
        picker.date = self.date ?: NSDate.date;
        picker.tintColor = AppPrimaryClr;

        // Title
        UILabel *titleLabel = [UILabel new];
        titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        titleLabel.text = kLang(@"pickBirthDateOrToday");
        titleLabel.font = [GM boldFontWithSize:18];
        titleLabel.textColor = AppPrimaryTextClr;
        titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
        titleLabel.alpha = 0.85;

        // Done button
        UIButtonConfiguration *doneCfg;
        if (@available(iOS 26.0, *)) {
            doneCfg = [UIButtonConfiguration glassButtonConfiguration];
        } else {
            doneCfg = [UIButtonConfiguration filledButtonConfiguration];
        }
        UIButton *doneBtn =
        [PPButtonHelper pp_buttonWithTitle:kLang(@"Done")
                                      font:[GM boldFontWithSize:16]
                                 textColor:AppPrimaryClr
                                   corners:23
                                 imageName:@"checkmark"
                                    target:nil
                                     config:doneCfg
                                   btnSize:46
                                     action:nil];
        doneBtn.translatesAutoresizingMaskIntoConstraints = NO;

        __weak typeof(self) weakSelf = self;
        __weak typeof(pickerVC) weakPickerVC = pickerVC;

        [doneBtn addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {

            __strong typeof(weakSelf) self = weakSelf;
            NSDate *selected = picker.date;

            [weakPickerVC dismissViewControllerAnimated:YES completion:^{
                // Update button UI
                [self setDate:selected animated:YES];

                // 🔔 Completion callback
                if (completion) {
                    completion(selected);
                }
            }];

        }] forControlEvents:UIControlEventTouchUpInside];

        // Layout
        [pickerVC.view addSubview:titleLabel];
        [pickerVC.view addSubview:picker];
        [pickerVC.view addSubview:doneBtn];

        [NSLayoutConstraint activateConstraints:@[
            [titleLabel.topAnchor constraintEqualToAnchor:pickerVC.view.safeAreaLayoutGuide.topAnchor constant:12],
            [titleLabel.leadingAnchor constraintEqualToAnchor:pickerVC.view.leadingAnchor constant:16],
            [titleLabel.trailingAnchor constraintEqualToAnchor:pickerVC.view.trailingAnchor constant:-16],
            [titleLabel.heightAnchor constraintEqualToConstant:44],

            [doneBtn.topAnchor constraintEqualToAnchor:pickerVC.view.safeAreaLayoutGuide.topAnchor constant:8],
            [doneBtn.trailingAnchor constraintEqualToAnchor:pickerVC.view.trailingAnchor constant:-16],
            [doneBtn.widthAnchor constraintEqualToConstant:80],
            [doneBtn.heightAnchor constraintEqualToConstant:46],

            [picker.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8],
            [picker.leadingAnchor constraintEqualToAnchor:pickerVC.view.leadingAnchor constant:12],
            [picker.trailingAnchor constraintEqualToAnchor:pickerVC.view.trailingAnchor constant:-12],
            [picker.bottomAnchor constraintEqualToAnchor:pickerVC.view.safeAreaLayoutGuide.bottomAnchor constant:-12],
        ]];

        [PPFunc presentSheetFrom:controller
                         sheetVC:pickerVC
                     detentStyle:PPSheetDetentStyle300];
        return;
    }

    // ===== iOS ≤25 fallback =====

    UIDatePicker *picker = [UIDatePicker new];
    picker.datePickerMode = UIDatePickerModeDate;
    picker.preferredDatePickerStyle = UIDatePickerStyleInline;
    picker.date = self.date ?: NSDate.date;

    UIAlertController *sheet =
    [UIAlertController alertControllerWithTitle:nil
                                        message:nil
                                 preferredStyle:UIAlertControllerStyleActionSheet];

    [sheet.view addSubview:picker];
    picker.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[
        [picker.leadingAnchor constraintEqualToAnchor:sheet.view.leadingAnchor constant:16],
        [picker.trailingAnchor constraintEqualToAnchor:sheet.view.trailingAnchor constant:-16],
        [picker.topAnchor constraintEqualToAnchor:sheet.view.topAnchor constant:8]
    ]];

    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"Done")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *a) {

        NSDate *selected = picker.date;
        [self setDate:selected animated:YES];

        if (completion) {
            completion(selected);
        }
    }]];

    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = self;
        sheet.popoverPresentationController.sourceRect = self.bounds;
    }

    [controller presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - Setup

// iOS 26 glass button support
- (void)commonInit {
    self.clipsToBounds = YES;
    self.layer.cornerRadius = 14;

    // Disable UIButton default content
    self.titleLabel.hidden = YES;
    self.imageView.hidden = YES;
    self.adjustsImageWhenHighlighted = NO;
    self.hapticsEnabled = YES;
    if (@available(iOS 26.0, *)) {
        // iOS 26+ native glass button
        UIButtonConfiguration *cfg =
        [UIButtonConfiguration clearGlassButtonConfiguration];

        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.background.backgroundColor =
            [[UIColor labelColor] colorWithAlphaComponent:0.08];
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);

        self.configuration = cfg;
    } else {
        // iOS ≤25 fallback blur
        [self setupBlur];
    }

    [self setupLabels];
    [self setupFormatters];

    [self setToday];
}

- (void)setupBlur {
    if (@available(iOS 26.0, *)) { return; }
    UIBlurEffectStyle style = UIBlurEffectStyleSystemChromeMaterial;

    if (@available(iOS 15.0, *)) {
        style = UIBlurEffectStyleSystemUltraThinMaterial;
    }

    UIVisualEffect *blur = [UIBlurEffect effectWithStyle:style];
    self.blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    self.blurView.translatesAutoresizingMaskIntoConstraints = NO;
    self.blurView.userInteractionEnabled = NO;

    [self addSubview:self.blurView];

    [NSLayoutConstraint activateConstraints:@[
        [self.blurView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.blurView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [self.blurView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.blurView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
    ]];
}

- (void)setupLabels {
    self.dayMonthLabel = [[UILabel alloc] init];
    self.dayMonthLabel.font = [GM boldFontWithSize:18];
    self.dayMonthLabel.textColor = UIColor.labelColor;
    self.dayMonthLabel.textAlignment = NSTextAlignmentCenter;

    self.yearLabel = [[UILabel alloc] init];
    self.yearLabel.font = [GM MidFontWithSize:12];
    self.yearLabel.textColor = UIColor.secondaryLabelColor;
    self.yearLabel.textAlignment = NSTextAlignmentCenter;

    self.stackView =
    [[UIStackView alloc] initWithArrangedSubviews:@[
        self.dayMonthLabel,
        self.yearLabel
    ]];

    self.stackView.axis = UILayoutConstraintAxisVertical;
    self.stackView.alignment = UIStackViewAlignmentCenter;
    self.stackView.spacing = 0;
    self.stackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.stackView.userInteractionEnabled = NO;

    [self addSubview:self.stackView];

    [NSLayoutConstraint activateConstraints:@[
        [self.stackView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [self.stackView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
    ]];
}

- (void)setupFormatters {
    self.dayMonthFormatter = [NSDateFormatter new];
    self.dayMonthFormatter.dateFormat = @"dd/MM";

    self.yearFormatter = [NSDateFormatter new];
    self.yearFormatter.dateFormat = @"YYYY";
}

#pragma mark - Public API

- (void)setToday {
    [self setDate:[NSDate date] animated:NO];
}

- (void)setDate:(NSDate *)date animated:(BOOL)animated {
    _date = date ?: [NSDate date];

    NSString *dayMonth = [self.dayMonthFormatter stringFromDate:_date];
    NSString *year = [self.yearFormatter stringFromDate:_date];

    if (!animated) {
        self.dayMonthLabel.text = dayMonth;
        self.yearLabel.text = year;
        return;
    }
    
    if (animated && self.hapticsEnabled) {
        UISelectionFeedbackGenerator *gen = [UISelectionFeedbackGenerator new];
        [gen prepare];
        [gen selectionChanged];
    }

    [UIView transitionWithView:self.stackView
                      duration:0.2
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        self.dayMonthLabel.text = dayMonth;
        self.yearLabel.text = year;
    } completion:nil];
}
- (void)setSizeVariant:(PPGlassDateButtonSize)sizeVariant {
    _sizeVariant = sizeVariant;

    CGFloat w = (sizeVariant == PPGlassDateButtonSizeLarge) ? 88 : 72;
    CGFloat h = (sizeVariant == PPGlassDateButtonSizeLarge) ? 64 : 56;

    [NSLayoutConstraint deactivateConstraints:self.constraints];
    [NSLayoutConstraint activateConstraints:@[
        [self.widthAnchor constraintEqualToConstant:w],
        [self.heightAnchor constraintEqualToConstant:h]
    ]];
}

- (void)setDateFromPicker {
    NSLog(@"doneBtn addAction:setDateFromPicker");
}

// Custom iOS 26+ clear popover, fallback to UIAlertController for <=25
- (void)presentDatePickerFrom:(UIViewController *)controller
{
    if (!controller) return;
    [controller.view endEditing:YES];
    [self endEditing:YES];
    if (@available(iOS 26.0, *)) {
        // iOS 26+ : Custom clear background picker VC
        UIViewController *pickerVC = [UIViewController new];
        pickerVC.view.backgroundColor = PPIOS26() ? [AppForgroundColr colorWithAlphaComponent:0.5] : AppBackgroundClr;
 
        UIView *container = [UIView new];
        container.translatesAutoresizingMaskIntoConstraints = NO;
        container.backgroundColor = [UIColor clearColor];
        container.layer.masksToBounds = YES;

        UIDatePicker *picker = [UIDatePicker new];
        picker.translatesAutoresizingMaskIntoConstraints = NO;
        picker.datePickerMode = UIDatePickerModeDate;
        picker.preferredDatePickerStyle = UIDatePickerStyleInline;
        picker.date = self.date ?: NSDate.date;
        picker.tintColor = AppPrimaryClr;
         
        // ✅ Title
        UILabel *titleLabel = [UILabel new];
        titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        titleLabel.text = kLang(@"pickBirthDateOrToday");
        titleLabel.font = [GM boldFontWithSize:18];
        titleLabel.textColor = AppPrimaryTextClr;
        titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
        titleLabel.alpha = 0.85;
        [pickerVC.view addSubview:titleLabel];
        
        UIButtonConfiguration *doneCfg2;
        if (@available(iOS 26.0, *)) {
            doneCfg2 = [UIButtonConfiguration glassButtonConfiguration];
        } else {
            doneCfg2 = [UIButtonConfiguration filledButtonConfiguration];
        }
        UIButton *doneBtn = [PPButtonHelper pp_buttonWithTitle:kLang(@"Done") font:[GM boldFontWithSize:16] textColor:AppPrimaryClr corners:23 imageName:@"checkmark" target:self config:doneCfg2 btnSize:46 action:@selector(setDateFromPicker)];
        doneBtn.translatesAutoresizingMaskIntoConstraints = NO;
        
        
        //[doneBtn addTarget:self action:@selector(setDateFromPicker) forControlEvents:UIControlEventTouchUpInside];
        __weak typeof(self) weakSelf = self;
        [doneBtn addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
            
            NSLog(@"doneBtn addAction:[UIAction actionWithHandler:");
            
            __strong typeof(weakSelf) self = weakSelf;
            
            [controller dismissViewControllerAnimated:YES completion:^{
                [self setDate:picker.date animated:YES];
            }];
        }] forControlEvents:UIControlEventTouchUpInside];
//@"pickBirthDateOrToday"
        [container addSubview:picker];
       
        [pickerVC.view addSubview:container];
        [pickerVC.view addSubview:doneBtn];
        [self updateGlassBackgroundColor:AppPrimaryClr opacity:0.03 forButton:doneBtn];
        [NSLayoutConstraint activateConstraints:@[
            // Title
            [titleLabel.topAnchor constraintEqualToAnchor:pickerVC.view.safeAreaLayoutGuide.topAnchor constant:12],
            [titleLabel.leadingAnchor constraintEqualToAnchor:pickerVC.view.leadingAnchor constant:16],
            [titleLabel.trailingAnchor constraintEqualToAnchor:pickerVC.view.trailingAnchor constant:-16],
            [titleLabel.heightAnchor constraintEqualToConstant:44],

               
            [doneBtn.topAnchor constraintEqualToAnchor:pickerVC.view.safeAreaLayoutGuide.topAnchor constant:8],
            [doneBtn.trailingAnchor constraintEqualToAnchor:pickerVC.view.trailingAnchor constant:-16],
            [doneBtn.widthAnchor constraintEqualToConstant:80],
            [doneBtn.heightAnchor constraintEqualToConstant:46],
               
            // Container
            [container.widthAnchor constraintEqualToAnchor:pickerVC.view.widthAnchor],
            [container.bottomAnchor constraintEqualToAnchor:pickerVC.view.safeAreaLayoutGuide.bottomAnchor],
            [container.centerXAnchor constraintEqualToAnchor:pickerVC.view.centerXAnchor],
            [container.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8],
            
            
            [picker.topAnchor constraintEqualToAnchor:container.topAnchor constant:12],
            [picker.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:12],
            [picker.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-12],
               [picker.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-12],

           
        ]];

        
        [PPFunc presentSheetFrom:controller sheetVC:pickerVC detentStyle:PPSheetDetentStyle300];
        return;
    }

    // iOS <=25 fallback (UIAlertController)
    UIDatePicker *picker = [UIDatePicker new];
    picker.datePickerMode = UIDatePickerModeDate;
    picker.preferredDatePickerStyle = UIDatePickerStyleInline;
    picker.date = self.date ?: NSDate.date;

    UIAlertController *sheet =
    [UIAlertController alertControllerWithTitle:nil
                                        message:nil
                                 preferredStyle:UIAlertControllerStyleActionSheet];

    [sheet.view addSubview:picker];
    picker.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[
        [picker.leadingAnchor constraintEqualToAnchor:sheet.view.leadingAnchor constant:16],
        [picker.trailingAnchor constraintEqualToAnchor:sheet.view.trailingAnchor constant:-16],
        [picker.topAnchor constraintEqualToAnchor:sheet.view.topAnchor constant:8]
    ]];

    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"Done")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *a) {
        [self setDate:picker.date animated:YES];
    }]];

    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = self;
        sheet.popoverPresentationController.sourceRect = self.bounds;
    }

    [controller presentViewController:sheet animated:YES completion:nil];
}
- (void)updateGlassBackgroundColor:(UIColor *)color
                           opacity:(CGFloat)opacity
                             forButton:(UIButton *)button
{
    if (@available(iOS 26.0, *)) {

        // Defensive: configuration may be nil
        UIButtonConfiguration *cfg =
        button.configuration ?: [UIButtonConfiguration clearGlassButtonConfiguration];

        UIColor *baseColor = color ?: UIColor.labelColor;
        CGFloat alpha = MAX(0.0, MIN(opacity, 1.0));

        cfg.background.backgroundColor =
        [baseColor colorWithAlphaComponent:alpha];

        // Preserve corner + insets
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;

        button.configuration = cfg;
    }
}


- (void)showTipOnceWithText:(NSString *)text
         inViewController:(UIViewController *)controller
{
    if (!text.length || !controller) return;

    NSString *key =
    [NSString stringWithFormat:@"pp.tip.datebutton.%@",
     NSStringFromClass(controller.class)];

    // Optional: show only once
    // if ([[NSUserDefaults standardUserDefaults] boolForKey:key]) return;

    // ⏱️ Delay to next run loop so view is in window & layout is done
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.window) return;

        if (@available(iOS 17.0, *)) {

            Class ToolTipCfgClass = NSClassFromString(@"UIToolTipConfiguration");
            if (!ToolTipCfgClass) goto finish;

            SEL cfgSel = NSSelectorFromString(@"configurationWithToolTip:");
            if (![ToolTipCfgClass respondsToSelector:cfgSel]) goto finish;

            id config =
            ((id (*)(id, SEL, NSString *))objc_msgSend)
            (ToolTipCfgClass, cfgSel, text);

            SEL showSel = NSSelectorFromString(@"showToolTipWithConfiguration:");
            if ([self respondsToSelector:showSel]) {
                ((void (*)(id, SEL, id))objc_msgSend)
                (self, showSel, config);
            }
        }

    finish:
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:key];
    });
}

@end

