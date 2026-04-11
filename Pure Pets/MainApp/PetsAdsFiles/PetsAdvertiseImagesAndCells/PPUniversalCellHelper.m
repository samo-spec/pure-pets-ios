//
//  PPUniversalCellHelper.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 20/10/2025.
//

#import "PPUniversalCellHelper.h"
#import <objc/runtime.h>










@implementation PPBottomOverlayBlur {
    CGFloat _height;
}

- (instancetype)initWithHeight:(CGFloat)height
                  cornerRadius:(CGFloat)cornerRadius
{
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;

    _height = height;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    //self.clipsToBounds = YES;
    //self.layer.cornerRadius = cornerRadius;
    
    
    self.layer.borderWidth = 0.0;
    self.layer.borderColor = UIColor.clearColor.CGColor;
    self.backgroundColor = UIColor.clearColor;
    if (@available(iOS 13.0, *)) {
        self.layer.cornerCurve = kCACornerCurveContinuous;
    }

    [self buildBlur];
    return self;
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    
    if (@available(iOS 13.0, *)) {
        self.layer.cornerCurve = kCACornerCurveContinuous;
    }

    for (CALayer *sublayer in self.layer.sublayers) {
        if ([sublayer isKindOfClass:[CAGradientLayer class]]) {
            sublayer.frame = self.bounds;
        }
    }
    
}

- (void)buildBlur
{
    if (@available(iOS 13.0, *)) {
        UIBlurEffect *effect =
        [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];

        UIVisualEffectView *blur =
        [[UIVisualEffectView alloc] initWithEffect:effect];
        blur.translatesAutoresizingMaskIntoConstraints = NO;
        blur.alpha = 0.82;

        [self addSubview:blur];
        [NSLayoutConstraint activateConstraints:@[
            [blur.topAnchor constraintEqualToAnchor:self.topAnchor],
            [blur.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            [blur.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [blur.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        ]];
        
 
        UIView *tintView = [[UIView alloc] init];
        tintView.translatesAutoresizingMaskIntoConstraints = NO;
        tintView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.08];
        tintView.userInteractionEnabled = NO;
        [self addSubview:tintView];
        [NSLayoutConstraint activateConstraints:@[
            [tintView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [tintView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            [tintView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [tintView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        ]];

        CAGradientLayer *gradient = [CAGradientLayer layer];
        gradient.colors = @[
            (id)[UIColor colorWithWhite:0.0 alpha:0.00].CGColor,
            (id)[UIColor colorWithWhite:0.0 alpha:0.06].CGColor,
            (id)[UIColor colorWithWhite:0.0 alpha:0.22].CGColor
        ];
        gradient.locations = @[@0.0, @0.35, @1.0];
        gradient.startPoint = CGPointMake(0.5, 0.0);
        gradient.endPoint = CGPointMake(0.5, 1.0);
        gradient.frame = self.bounds;
        gradient.needsDisplayOnBoundsChange = YES;
        [self.layer insertSublayer:gradient atIndex:0];

        UIView *topHairline = [[UIView alloc] init];
        topHairline.translatesAutoresizingMaskIntoConstraints = NO;
        topHairline.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
        topHairline.userInteractionEnabled = NO;
        [self addSubview:topHairline];
        [NSLayoutConstraint activateConstraints:@[
            [topHairline.topAnchor constraintEqualToAnchor:self.topAnchor],
            [topHairline.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14.0],
            [topHairline.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-14.0],
            [topHairline.heightAnchor constraintEqualToConstant:0.8]
        ]];
        
    } else {
        
        // Fallback gradient (older iOS)
        CAGradientLayer *g = [CAGradientLayer layer];
        g.colors = @[
            (id)[UIColor colorWithWhite:0.0 alpha:0.04].CGColor,
            (id)[UIColor colorWithWhite:0.0 alpha:0.12].CGColor,
            (id)[UIColor colorWithWhite:0.0 alpha:0.24].CGColor
        ];
        g.startPoint = CGPointMake(0.5, 0.0);
        g.endPoint   = CGPointMake(0.5, 1.0);
        g.frame = self.bounds;
        g.needsDisplayOnBoundsChange = YES;
        [self.layer insertSublayer:g atIndex:0];
    }
 
    if (@available(iOS 13.0, *)) {
        self.layer.cornerCurve = kCACornerCurveContinuous;
    }
    
}

- (CGSize)intrinsicContentSize
{
    return CGSizeMake(UIViewNoIntrinsicMetric, _height);
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

@end




@implementation PPUniversalCell (Helpers)
#pragma mark - Helpers
- (void)deactivateConstraints:(NSArray<NSLayoutConstraint *> *)constraints {
    for (NSLayoutConstraint *constraint in constraints) {
        constraint.active = NO;
    }
}


- (void)setAddButton:(UIButton *)addButton {
    objc_setAssociatedObject(self, @selector(addButton), addButton, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIButton *)addButton {
    return objc_getAssociatedObject(self, @selector(addButton));
}

@end



@implementation PPCornerBlurView
- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.layoutSubviewsBlock) self.layoutSubviewsBlock();
}
@end


NS_ASSUME_NONNULL_BEGIN
@interface PPUniversalCell ()
// Card container

@end


@implementation PPUniversalCell (PPUniversalCellHelper)






- (UIButton *)iconButton:(NSString *)systemName
              buttonKind:(ButtonKind)buttonKind
                    size:(CGFloat)size
{
    return [self iconButton:systemName buttonKind:buttonKind size:size baseForground:[AppForgroundColr colorWithAlphaComponent:1.0] baseBackground:[AppPrimaryClr colorWithAlphaComponent:1.0]];
}

- (UIButton *)iconButton:(NSString *)systemName
              buttonKind:(ButtonKind)buttonKind
                    size:(CGFloat)size
           baseForground:(UIColor *)baseForground
          baseBackground:(UIColor *)baseBackground
{
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.translatesAutoresizingMaskIntoConstraints = NO;
    
    if (@available(iOS 26.0, *)) {
        // 🔹 create a *glass-light* style configuration
        UIButtonConfiguration *config = [UIButtonConfiguration filledButtonConfiguration];
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        config.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);

        // base tint
        config.baseBackgroundColor = baseBackground;
        config.baseForegroundColor = baseForground;

        if (buttonKind == ButtonKindImage) {
             config.image = [UIImage systemImageNamed:systemName];
            UIImageSymbolConfiguration *symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:14
                                                                                                       weight:UIImageSymbolWeightMedium
                                                                                                        scale:UIImageSymbolScaleDefault];

            symbolConfig = [symbolConfig configurationByApplyingConfiguration:
                            [UIImageSymbolConfiguration configurationPreferringMulticolor]];

            config.preferredSymbolConfigurationForImage = symbolConfig;

           
        } else if (buttonKind == ButtonKindText) {
            config.title = systemName;
            config.titleTextAttributesTransformer =
            ^NSDictionary<NSAttributedStringKey, id> * (NSDictionary<NSAttributedStringKey, id> *attrs) {
                NSMutableDictionary *m = [attrs mutableCopy];
                m[NSFontAttributeName] = [GM boldFontWithSize:MAX(14, size * 0.55)];
                return m;
            };
        }

        b.configuration = config;

    } else {
        // 🔹 Fallback for iOS 15–25
        if (buttonKind == ButtonKindImage) {
            UIImage *icon = [UIImage pp_symbolNamed:systemName
                                          pointSize:size * 0.55
                                             weight:UIImageSymbolWeightRegular
                                              scale:UIImageSymbolScaleMedium
                                            palette:@[AppLightGrayColor]
                                        makeTemplate:YES];
            [b setImage:icon forState:UIControlStateNormal];
        } else if (buttonKind == ButtonKindText) {
            [b setTitle:systemName forState:UIControlStateNormal];
            b.titleLabel.font = [GM boldFontWithSize:MAX(14, size * 0.55)];
            [b setTitleColor:AppPrimaryClr forState:UIControlStateNormal];
        }

        [b applyGlassStyleWithCornerRadius:size / 2.0
                                     style:UIBlurEffectStyleSystemThinMaterialLight
                               tintOverlay:[UIColor colorWithWhite:1.0 alpha:0.1]];
    }
    // Keep the glass affordance light so the card stays clean.
    b.layer.shadowColor = UIColor.blackColor.CGColor;
    b.layer.shadowOpacity = 0.08;
    b.layer.shadowRadius = 6.0;
    b.layer.shadowOffset = CGSizeMake(0, 3);
    b.layer.masksToBounds = NO;
    b.clipsToBounds = NO;
    return b;
}

- (void)applyGlassStyleWithCornerRadius:(CGFloat)radius
                                  style:(UIBlurEffectStyle)style
                            tintOverlay:(nullable UIColor *)tint
{
    self.layer.cornerRadius = radius;
    self.layer.masksToBounds = YES;
    self.backgroundColor = UIColor.clearColor;
    
    // Remove existing blur/tint if reapplying
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UIVisualEffectView class]] || sub.tag == 9999) {
            [sub removeFromSuperview];
        }
    }

    if (@available(iOS 13.0, *)) {
        // Create blur
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:style];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurView.translatesAutoresizingMaskIntoConstraints = NO;
        blurView.userInteractionEnabled = NO;
        blurView.layer.cornerRadius = radius;
        blurView.layer.masksToBounds = YES;
        [self insertSubview:blurView atIndex:0];

        // Constrain blur to fill button
        [NSLayoutConstraint activateConstraints:@[
            [blurView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [blurView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            [blurView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [blurView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor]
        ]];

        // Optional tint overlay (subtle highlight or darkening)
        if (tint) {
            UIView *overlay = [[UIView alloc] init];
            overlay.translatesAutoresizingMaskIntoConstraints = NO;
            overlay.backgroundColor = tint;
            overlay.userInteractionEnabled = NO;
            overlay.layer.cornerRadius = radius;
            overlay.layer.masksToBounds = YES;
            overlay.tag = 9999;
            [self insertSubview:overlay aboveSubview:blurView];

            [NSLayoutConstraint activateConstraints:@[
                [overlay.topAnchor constraintEqualToAnchor:self.topAnchor],
                [overlay.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
                [overlay.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
                [overlay.trailingAnchor constraintEqualToAnchor:self.trailingAnchor]
            ]];
        }

    } else {
        // Fallback for iOS 12 and earlier
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.3];
    }
}


- (UIButton *)iconButton:(NSString *)systemName buttonKind:(ButtonKind)buttonKind {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.translatesAutoresizingMaskIntoConstraints = NO;

    // ✅ iOS 18+ (or 26.0 in your code): Modern Glass Configuration
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *config = [UIButtonConfiguration prominentGlassButtonConfiguration];
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;

        if (buttonKind == ButtonKindImage) {
            config.image = [UIImage systemImageNamed:systemName];
            config.preferredSymbolConfigurationForImage =
                [UIImageSymbolConfiguration configurationWithPointSize:16
                                                                weight:UIImageSymbolWeightRegular
                                                                 scale:UIImageSymbolScaleDefault];
            config.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);
        } else if (buttonKind == ButtonKindText) {
            config.title = systemName; // use the string as the label text
            config.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey,id> *
                (NSDictionary<NSAttributedStringKey,id> *incoming) {
                    NSMutableDictionary *attrs = [incoming mutableCopy];
                    attrs[NSFontAttributeName] = [GM boldFontWithSize:16];
                    attrs[NSForegroundColorAttributeName] = AppPrimaryClr;
                     return attrs;
            };
            float ins = -3;
            config.contentInsets = NSDirectionalEdgeInsetsMake(ins, ins, ins, ins);  //top   //leading  //bottom //trailing
         }

        
        // 🎨 Color configuration
        //config.baseForegroundColor = AppPrimaryClr;  // text or icon tint
        config.baseBackgroundColor = [AppForgroundColr colorWithAlphaComponent:0.5];

        // Assign config
        b.configuration = config;

        b.configurationUpdateHandler = ^(UIButton *btn) {
            if (btn.isHighlighted) {
                btn.transform = CGAffineTransformMakeScale(0.92, 0.92);
            } else {
                btn.transform = CGAffineTransformIdentity;
            }
        };

        
    } else {
        // ✅ iOS 13–17 fallback: Custom blur/tint simulation
        if (buttonKind == ButtonKindImage) {
            UIImage *icon = [UIImage pp_symbolNamed:systemName
                                          pointSize:14
                                             weight:UIImageSymbolWeightRegular
                                              scale:UIImageSymbolScaleSmall
                                            palette:@[AppLightGrayColor, AppLightGrayColor]
                                        makeTemplate:YES];
            [b setImage:icon forState:UIControlStateNormal];
        } else if (buttonKind == ButtonKindText) {
            [b setTitle:systemName forState:UIControlStateNormal];
            b.titleLabel.font = [UIFont boldSystemFontOfSize:15];
            [b setTitleColor:AppPrimaryClr forState:UIControlStateNormal];
            b.contentEdgeInsets = UIEdgeInsetsMake(6, 16, 6, 16);
        }

        // Apply custom "glass" look (your helper)
        [b applyGlassStyleWithCornerRadius:16
                                     style:UIBlurEffectStyleSystemThinMaterial
                               tintOverlay:[UIColor colorWithWhite:1.0 alpha:0.08]];

        
    }
   
    // ☁️ Drop shadow for depth
    b.layer.shadowColor = AppShadowClr.CGColor;
    b.layer.shadowOpacity = 0.15;
    b.layer.shadowRadius = 6;
    b.layer.shadowOffset = CGSizeMake(0, 6);
    b.layer.masksToBounds = NO;

    return b;
}



-(UIView *)createCard
{
    UIView *card = [UIView new];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = UIColor.clearColor;
    card.layer.masksToBounds  = NO;
    card.clipsToBounds = NO;
    card.backgroundColor= AppForgroundColr;
    
    card.layer.shadowColor = AppPrimaryClr.CGColor;
    card.layer.shadowOpacity = 0.15;
    card.layer.shadowRadius = 10;
    card.layer.shadowOffset = CGSizeMake(0, 6);
    return card;
}


-(UIImageView *)createImageView
{
    UIImageView *imageView = [UIImageView new];
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    imageView.contentMode = UIViewContentModeTop;
    imageView.clipsToBounds = YES;
    imageView.layer.cornerRadius = 22;
    if (@available(iOS 13.0, *)) {
        imageView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    imageView.layer.masksToBounds = YES;
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;
    imageView.backgroundColor = UIColor.secondarySystemBackgroundColor;
    return imageView;
}

-(UILabel *)createPriceLabel
{
    UILabel *priceLabel = [UILabel new];
    priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    priceLabel.font = [GM boldFontWithSize:18];
    priceLabel.textColor = UIColor.labelColor;
    return priceLabel;
}



- (UILabel *)createTitleLabel {

    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;

    label.font = [GM boldFontWithSize:15];
    label.numberOfLines = 2;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.textAlignment = Language.isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;

    // ✅ CRITICAL (missing)
    label.adjustsFontForContentSizeCategory = NO;

    [label setContentCompressionResistancePriority:UILayoutPriorityRequired
                                            forAxis:UILayoutConstraintAxisVertical];

    [label setContentHuggingPriority:UILayoutPriorityRequired
                              forAxis:UILayoutConstraintAxisVertical];

    return label;
}

-(UILabel *)createSubtitleLabel
{
    UILabel *lb = [UILabel new];
    lb.translatesAutoresizingMaskIntoConstraints = NO;
    lb.font = [GM MidFontWithSize:16];
    lb.textColor =  UIColor.secondaryLabelColor;
    lb.numberOfLines = 1;
    lb.textAlignment = GM.setAligment;
    //lb.backgroundColor = UIColor.greenColor;
    return lb;
}

-(UIStackView *)createTextStackWithElements:(NSArray *)elemnts
{
    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:elemnts];
    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = 4;
    textStack.semanticContentAttribute = GM.setSemantic;
    // Relax child vertical priorities for stack flexibility
    for (UIView *v in elemnts) {
        [v setContentHuggingPriority:UILayoutPriorityDefaultLow
                             forAxis:UILayoutConstraintAxisVertical];
        [v setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                           forAxis:UILayoutConstraintAxisVertical];
    }
    return textStack;
}


- (UILabel *)createDiscountValueLabel
{
    PPInsetLabel *discountValueLabel = [PPInsetLabel new];
    discountValueLabel.textInsets = UIEdgeInsetsMake(4, 7, 4, 7);
    discountValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    discountValueLabel.font = [GM boldFontWithSize:10.5];
    discountValueLabel.textColor =[UIColor whiteColor];
    discountValueLabel.backgroundColor = AppPrimaryClr;
    discountValueLabel.layer.cornerRadius = 10;
    discountValueLabel.layer.masksToBounds = YES;
    discountValueLabel.textAlignment = NSTextAlignmentCenter;
    NSLayoutConstraint *h =
    [discountValueLabel.heightAnchor constraintEqualToConstant:22.0];
    h.priority = UILayoutPriorityDefaultHigh;
    h.active = YES;
    [discountValueLabel sizeToFit];
    return discountValueLabel;
}

- (PPInsetLabel *)createDiscountLabel
{
    PPInsetLabel *discountLabel = [PPInsetLabel new];
    discountLabel.textInsets = UIEdgeInsetsMake(1, 2, 1, 2);
    discountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    discountLabel.font = [GM MidFontWithSize:12];
    discountLabel.textColor =  UIColor.secondaryLabelColor;
    discountLabel.backgroundColor = [UIColor clearColor];
    discountLabel.layer.cornerRadius = 14;
    discountLabel.layer.masksToBounds = YES;
    discountLabel.textAlignment = NSTextAlignmentCenter;
    //[discountLabel.widthAnchor constraintGreaterThanOrEqualToConstant:36].active = YES;
    NSLayoutConstraint *h =
    [discountLabel.heightAnchor constraintEqualToConstant:28.0];
    h.priority = UILayoutPriorityDefaultHigh;
    h.active = YES;
    return discountLabel;
}


- (UIStackView *)createPriceStackWithSubviews:(NSArray *)elemnts
{
    UIStackView *priceStack = [[UIStackView alloc] initWithArrangedSubviews:elemnts];
    priceStack.translatesAutoresizingMaskIntoConstraints = NO;
    priceStack.axis = UILayoutConstraintAxisHorizontal;
    priceStack.alignment = UIStackViewAlignmentCenter;
    priceStack.spacing = 6;
    return priceStack;
}

#pragma mark - Build UI

- (UILabel *)badgeWithText:(NSString *)text bg:(UIColor *)bg {
    UILabel *l = [UILabel new];
    l.translatesAutoresizingMaskIntoConstraints = NO;
    l.text = text;
    l.font = [UIFont boldSystemFontOfSize:12];
    l.textColor = AppForgroundColr;
    l.backgroundColor = [bg colorWithAlphaComponent:0.88];
    l.textAlignment = NSTextAlignmentCenter;
    l.layer.cornerRadius = 12;
    l.layer.masksToBounds = YES;
    NSLayoutConstraint *h =
    [l.heightAnchor constraintEqualToConstant:28.0];
    h.priority = UILayoutPriorityDefaultHigh;
    h.active = YES;
    return l;
}

- (PPInsetLabel *)createStockQtyLabel
{
    PPInsetLabel *qtyLabel = [PPInsetLabel new];
    qtyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    qtyLabel.text = @"0";
    qtyLabel.font = [GM boldFontWithSize:11];
    qtyLabel.textAlignment = NSTextAlignmentCenter;
    qtyLabel.textColor = UIColor.labelColor;
    qtyLabel.textInsets = UIEdgeInsetsMake(3, 7, 3, 7);
    qtyLabel.backgroundColor = UIColor.secondarySystemBackgroundColor;
    NSLayoutConstraint *h =
    [qtyLabel.heightAnchor constraintEqualToConstant:22];
    h.priority = UILayoutPriorityDefaultHigh;
    h.active = YES;
    qtyLabel.layer.cornerRadius = 10;
    qtyLabel.layer.masksToBounds = YES;
    qtyLabel.layer.borderWidth = 0.8;
    qtyLabel.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.18].CGColor;
    return qtyLabel ;
}

- (UILabel *)createQtyLabel
{
    UILabel *qtyLabel = [UILabel new];
    qtyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    qtyLabel.text = @"0";
    qtyLabel.font = [GM boldFontWithSize:16];
    qtyLabel.textAlignment = NSTextAlignmentCenter;
    qtyLabel.textColor = AppForgroundColr;
    NSLayoutConstraint *w =
    [qtyLabel.widthAnchor constraintGreaterThanOrEqualToConstant:36];
    w.priority = UILayoutPriorityDefaultHigh;
    w.active = YES;
    return qtyLabel ;
}
- (UIView *)createStepperView
{
    UIView *stepperView = [UIView new];
    stepperView.translatesAutoresizingMaskIntoConstraints = NO;
    stepperView.backgroundColor = UIColor.secondarySystemBackgroundColor;
    stepperView.layer.cornerRadius = 18;
    stepperView.layer.masksToBounds = YES;
    stepperView.layer.borderWidth = 1.0;
    stepperView.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.16].CGColor;
    stepperView.alpha = 0.0;
    stepperView.hidden = YES;
    return stepperView;
}




#pragma mark - Stepper Auto-Collapse

- (void)restartStepperCollapseTimer {
    [self.stepperCollapseTimer invalidate];
    self.stepperCollapseTimer = [NSTimer scheduledTimerWithTimeInterval:3.0
                                                                 target:self
                                                               selector:@selector(autoCollapseStepper)
                                                               userInfo:nil
                                                                repeats:NO];
}

- (void)autoCollapseStepper {
    [self collapseStepper:YES];
}

- (void)dealloc {
    [self.stepperCollapseTimer invalidate];
}


 










/*
- (PPCornerBlurView *)createBottomBlurOnView:(UIView *)cardView
                                          tl:(CGFloat)tl
                                          tr:(CGFloat)tr
                                          bl:(CGFloat)bl
                                          br:(CGFloat)br
                                          height:(CGFloat)height
{
    
    PPCornerBlurView *overlay = [PPCornerBlurView new];
    overlay.translatesAutoresizingMaskIntoConstraints = NO;
    overlay.userInteractionEnabled = NO;
    overlay.clipsToBounds = NO;
    overlay.tag = 9991;

    overlay.layer.shadowColor = UIColor.blackColor.CGColor;
    overlay.layer.shadowOpacity = 0.55;
    overlay.layer.shadowRadius = 4.0;
    overlay.layer.shadowOffset = CGSizeMake(0, 3);
    
    // Check if one already exists (e.g., during cell reuse)
    for (UIView *sub in cardView.subviews) {
        if (sub.tag == 9991) {
            [sub removeFromSuperview];
        }
    }

    // --- Modern blur on iOS 18+, gradient fallback below ---
    if (@available(iOS 18.0, *)) {
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterial]; //UIBlurEffectStyleLight //UIBlurEffectStyleSystemThinMaterial
        overlay.blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        overlay.blurView.translatesAutoresizingMaskIntoConstraints = NO;
        overlay.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.0];

        overlay.blurView.alpha = 0.85;
        [overlay addSubview:overlay.blurView];
        [NSLayoutConstraint activateConstraints:@[
            [overlay.blurView.topAnchor constraintEqualToAnchor:overlay.topAnchor],
            [overlay.blurView.bottomAnchor constraintEqualToAnchor:overlay.bottomAnchor],
            [overlay.blurView.leadingAnchor constraintEqualToAnchor:overlay.leadingAnchor],
            [overlay.blurView.trailingAnchor constraintEqualToAnchor:overlay.trailingAnchor]
        ]];

        // Subtle tint for contrast
      
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
        [overlay.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:0],
        [overlay.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-0],
        [overlay.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-0]    ]];

    // 🔸 Store corner values for later re-masking on resize
    overlay.layer.name = [NSString stringWithFormat:@"tl%.1f_tr%.1f_bl%.1f_br%.1f", tl, tr, bl, br];

    // Apply mask now
    [self applyCornerMaskToView:overlay tl:0 tr:0 bl:bl br:br];

    // Observe layout changes to keep corners correct
    __weak typeof(self) weakSelf = self;
    __weak typeof(overlay) weakOverlay = overlay;
    overlay.layoutSubviewsBlock = ^{
        __strong typeof(weakOverlay) overlay = weakOverlay;
        [weakSelf applyCornerMaskToView:overlay tl:tl tr:tr bl:bl br:br];
    };
    return overlay;
} */

- (void)changeBlurStyleForOverlay:(PPCornerBlurView *)overlay
                             style:(UIBlurEffectStyle)newStyle
                          animated:(BOOL)animated {
    if (!overlay.blurView) return;
    
    UIBlurEffect *newEffect = [UIBlurEffect effectWithStyle:newStyle];
    
    if (animated) {
        [UIView animateWithDuration:0.35
                         animations:^{
            overlay.blurView.effect = newEffect;
        }];
    } else {
        overlay.blurView.effect = newEffect;
    }
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

- (CAShapeLayer *)maskLayerForView:(UIView *)view
                                tl:(CGFloat)tl
                                tr:(CGFloat)tr
                                bl:(CGFloat)bl
                                br:(CGFloat)br
{
    CGRect bounds = view.bounds;
    if (CGRectIsEmpty(bounds)) {
        // Force layout before using bounds if called before layoutSubviews
        [view layoutIfNeeded];
        bounds = view.bounds;
    }

    UIBezierPath *path = [UIBezierPath bezierPath];

    CGFloat w = bounds.size.width;
    CGFloat h = bounds.size.height;

    // Start top-left
    [path moveToPoint:CGPointMake(0, tl)];
    [path addQuadCurveToPoint:CGPointMake(tl, 0) controlPoint:CGPointZero];

    // Top edge to top-right
    [path addLineToPoint:CGPointMake(w - tr, 0)];
    [path addQuadCurveToPoint:CGPointMake(w, tr)
                 controlPoint:CGPointMake(w, 0)];

    // Right edge to bottom-right
    [path addLineToPoint:CGPointMake(w, h - br)];
    [path addQuadCurveToPoint:CGPointMake(w - br, h)
                 controlPoint:CGPointMake(w, h)];

    // Bottom edge to bottom-left
    [path addLineToPoint:CGPointMake(bl, h)];
    [path addQuadCurveToPoint:CGPointMake(0, h - bl)
                 controlPoint:CGPointMake(0, h)];

    [path closePath];

    CAShapeLayer *mask = [CAShapeLayer layer];
    mask.path = path.CGPath;
    return mask;
}

//NSString *FavCollection = context == PPCellForAds ? @"favoritesAds" : context == PPCellForMarket? @"favoritesAccess" : context == PPCellForVets ? @"favoritesVets" : @"favoritesServices" ;
//[self setFavForCollection:FavCollection andID:vm.ModelID andButton:self.favButton];
-(void)setFavForCollection:(NSString *)collection andID:(NSString *)ID andButton:(FavoriteFloatingButton *)favButton
{//favoritesAds
    
    if(!UserManager.sharedManager.isUserLoggedIn) return;
    
    favButton.adID = ID;
    favButton.collection = collection;
    [favButton initValue];
}



- (UIMenu *)ownerActionsArray
{
    
    NSMutableArray *editGroup = [NSMutableArray array];
    NSMutableArray *shareGroup = [NSMutableArray array];

    UIAction *editPPAction = [PPActionButton actionWithTitle:kLang(@"EditAdTitle")
                                   systemImageName:@"pencil.and.scribble"
                                              font:[GM MidFontWithSize:16]
                                                       color:AppSecondaryTextClr handler:^(UIAction * _Nonnull action) {
        [self tapEdit];
    }];
    
    
  
    UIAction *deletePPAction = [PPActionButton actionWithTitle:kLang(@"DeleteAdTitle")
                                   systemImageName:@"trash"
                                              font:[GM MidFontWithSize:16]
                                             color:AppSecondaryTextClr handler:^(UIAction * _Nonnull action) {
        [self tapDelete];
    }];
    
    [editGroup addObject:editPPAction];
    [editGroup addObject:deletePPAction];
    
    
    UIAction *sharePPAction = [PPActionButton actionWithTitle:kLang(@"shareAd")
                                   systemImageName:@"square.and.arrow.up"
                                              font:[GM MidFontWithSize:16]
                                             color:AppSecondaryTextClr handler:^(UIAction * _Nonnull action) {
        [self tapShare];
    }];
    
    //[shareGroup addObject:sharePPAction];
   
    
    UIMenu *menu;

    if (@available(iOS 17.0, *)) {
        menu  = [UIMenu menuWithTitle:@""
                                       image:nil
                                  identifier:nil
                                     options:UIMenuOptionsDisplayAsPalette
                                    children:@[
            [UIMenu menuWithTitle:kLang(@"edit") image:nil identifier:nil options:UIMenuOptionsDisplayInline children:editGroup],
            [UIMenu menuWithTitle:kLang(@"share") image:nil identifier:nil options:UIMenuOptionsDisplayInline children:shareGroup]       ]];
        
        return  menu;
    } else {
        // Fallback on earlier versions
        
        menu  = [UIMenu menuWithTitle:kLang(@"edit")
                                       image:nil
                                  identifier:nil
                                     options:UIMenuOptionsDisplayAsPalette
                                    children:@[
            [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:editGroup],
            [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:shareGroup]
        ]];
        
    }
    
    return  menu;
}



- (void)addLiquidGlassBorderToView:(UIView *)view {
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
    glow.cornerRadius = 24.0;
    glow.borderWidth = 1.0;
    glow.borderColor = [[UIColor colorWithWhite:1 alpha:0.3] CGColor];
    glow.shadowColor = AppShadowClr.CGColor;
    glow.shadowOpacity = 0.9;
    glow.shadowRadius = 8;
    glow.shadowOffset = CGSizeMake(0, 0);
    glow.shouldRasterize = YES;
    glow.rasterizationScale = UIScreen.mainScreen.scale;
    [view.layer addSublayer:glow];

    // Keep it updated on layout
    glow.needsDisplayOnBoundsChange = YES;

   

   /*
    // Animate shimmer (slow)
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    anim.fromValue = @0;
    anim.toValue = @(M_PI * 2);
    anim.duration = 12.0;
    anim.repeatCount = HUGE_VALF;
    [gradient addAnimation:anim forKey:@"liquidShimmer"];
    */
}
- (void)addParallaxToView:(UIView *)view intensity:(CGFloat)intensity {
    UIInterpolatingMotionEffect *xMotion =
        [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"layer.transform.translation.x"
                                                        type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
    xMotion.minimumRelativeValue = @(-intensity);
    xMotion.maximumRelativeValue = @(intensity);

    UIInterpolatingMotionEffect *yMotion =
        [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"layer.transform.translation.y"
                                                        type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
    yMotion.minimumRelativeValue = @(-intensity);
    yMotion.maximumRelativeValue = @(intensity);

    UIMotionEffectGroup *group = [UIMotionEffectGroup new];
    group.motionEffects = @[xMotion, yMotion];
    [view addMotionEffect:group];
}

@end

NS_ASSUME_NONNULL_END




























































































@implementation UIButton (Style)

-(void)setTitleForAllState:(nullable NSString *)title textColor:(nullable UIColor *)textColor bgColor:(nullable UIColor *)bgColor font:(nullable UIFont *)font
{
    
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *config = self.configuration;
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;

            config.title = title; // use the string as the label text
            config.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey,id> *
                (NSDictionary<NSAttributedStringKey,id> *incoming) {
                    NSMutableDictionary *attrs = [incoming mutableCopy];
                    attrs[NSFontAttributeName] = font;
                    attrs[NSForegroundColorAttributeName] = textColor;
                     return attrs;
            };
        config.baseBackgroundColor = bgColor;
        // Assign config
        self.configuration = config;
        [self updateConfiguration];
    } else {
        // ✅ iOS 13–17 fallback: Custom blur/tint simulation
        
        [self setTitle:title forState:UIControlStateNormal];
        self.titleLabel.font = [UIFont boldSystemFontOfSize:15];
        [self setTitleColor:textColor forState:UIControlStateNormal];
        self.backgroundColor = bgColor;
    }
    
}
- (void)applyGlassStyleWithCornerRadius:(CGFloat)radius
                                  style:(UIBlurEffectStyle)style
                            tintOverlay:(nullable UIColor *)tint
{
    self.layer.cornerRadius = radius;
    self.layer.masksToBounds = YES;
    self.backgroundColor = UIColor.clearColor;
    
    // Remove existing blur/tint if reapplying
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UIVisualEffectView class]] || sub.tag == 9999) {
            [sub removeFromSuperview];
        }
    }

    if (@available(iOS 13.0, *)) {
        // Create blur
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:style];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurView.translatesAutoresizingMaskIntoConstraints = NO;
        blurView.userInteractionEnabled = NO;
        blurView.layer.cornerRadius = radius;
        blurView.layer.masksToBounds = YES;
        [self insertSubview:blurView atIndex:0];

        // Constrain blur to fill button
        [NSLayoutConstraint activateConstraints:@[
            [blurView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [blurView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            [blurView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [blurView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor]
        ]];

        // Optional tint overlay (subtle highlight or darkening)
        if (tint) {
            UIView *overlay = [[UIView alloc] init];
            overlay.translatesAutoresizingMaskIntoConstraints = NO;
            overlay.backgroundColor = tint;
            overlay.userInteractionEnabled = NO;
            overlay.layer.cornerRadius = radius;
            overlay.layer.masksToBounds = YES;
            overlay.tag = 9999;
            [self insertSubview:overlay aboveSubview:blurView];

            [NSLayoutConstraint activateConstraints:@[
                [overlay.topAnchor constraintEqualToAnchor:self.topAnchor],
                [overlay.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
                [overlay.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
                [overlay.trailingAnchor constraintEqualToAnchor:self.trailingAnchor]
            ]];
        }

    } else {
        // Fallback for iOS 12 and earlier
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.3];
    }
}






@end
