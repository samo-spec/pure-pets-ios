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
    
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = [UIButtonConfiguration filledButtonConfiguration];
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        config.contentInsets = NSDirectionalEdgeInsetsMake(8, 8, 8, 8);

        config.baseBackgroundColor = baseBackground;
        config.baseForegroundColor = baseForground;

        if (buttonKind == ButtonKindImage) {
            config.image = [UIImage systemImageNamed:systemName];
            config.preferredSymbolConfigurationForImage = 
                [UIImageSymbolConfiguration configurationWithPointSize:14
                                                                weight:UIImageSymbolWeightMedium
                                                                 scale:UIImageSymbolScaleMedium];
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
        
        b.configurationUpdateHandler = ^(UIButton *button) {
            [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
                button.transform = button.isHighlighted ? CGAffineTransformMakeScale(0.92, 0.92) : CGAffineTransformIdentity;
                button.alpha = button.isHighlighted ? 0.85 : 1.0;
            } completion:nil];
        };

    } else {
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
    
    b.layer.shadowColor = UIColor.blackColor.CGColor;
    b.layer.shadowOpacity = 0.06;
    b.layer.shadowRadius = 8.0;
    b.layer.shadowOffset = CGSizeMake(0, 4);
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
    
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UIVisualEffectView class]] || sub.tag == 9999) {
            [sub removeFromSuperview];
        }
    }

    if (@available(iOS 13.0, *)) {
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:style];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurView.translatesAutoresizingMaskIntoConstraints = NO;
        blurView.userInteractionEnabled = NO;
        blurView.layer.cornerRadius = radius;
        blurView.layer.masksToBounds = YES;
        [self insertSubview:blurView atIndex:0];

        [NSLayoutConstraint activateConstraints:@[
            [blurView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [blurView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            [blurView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [blurView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor]
        ]];

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
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.3];
    }
}


- (UIButton *)iconButton:(NSString *)systemName buttonKind:(ButtonKind)buttonKind {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.translatesAutoresizingMaskIntoConstraints = NO;

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = [UIButtonConfiguration filledButtonConfiguration];
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;

        if (buttonKind == ButtonKindImage) {
            config.image = [UIImage systemImageNamed:systemName];
            config.preferredSymbolConfigurationForImage =
                [UIImageSymbolConfiguration configurationWithPointSize:15
                                                                weight:UIImageSymbolWeightMedium
                                                                 scale:UIImageSymbolScaleDefault];
            config.contentInsets = NSDirectionalEdgeInsetsMake(8, 8, 8, 8);
        } else if (buttonKind == ButtonKindText) {
            config.title = systemName;
            config.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey,id> *
                (NSDictionary<NSAttributedStringKey,id> *incoming) {
                    NSMutableDictionary *attrs = [incoming mutableCopy];
                    attrs[NSFontAttributeName] = [GM boldFontWithSize:16];
                    attrs[NSForegroundColorAttributeName] = AppPrimaryClr;
                     return attrs;
            };
            config.contentInsets = NSDirectionalEdgeInsetsMake(4, 16, 4, 16);
         }

        config.baseBackgroundColor = [AppForgroundColr colorWithAlphaComponent:0.8];
        config.baseForegroundColor = AppPrimaryClr;
        b.configuration = config;

        b.configurationUpdateHandler = ^(UIButton *btn) {
            [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
                btn.transform = btn.isHighlighted ? CGAffineTransformMakeScale(0.94, 0.92) : CGAffineTransformIdentity;
                btn.alpha = btn.isHighlighted ? 0.9 : 1.0;
            } completion:nil];
        };
        
    } else {
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

        [b applyGlassStyleWithCornerRadius:16
                                     style:UIBlurEffectStyleSystemThinMaterial
                               tintOverlay:[UIColor colorWithWhite:1.0 alpha:0.08]];
    }
   
    b.layer.shadowColor = AppShadowClr.CGColor;
    b.layer.shadowOpacity = 0.12;
    b.layer.shadowRadius = 8;
    b.layer.shadowOffset = CGSizeMake(0, 4);
    b.layer.masksToBounds = NO;

    return b;
}



-(UIView *)createCard
{
    UIView *card = [UIView new];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = AppForgroundColr;
    card.layer.masksToBounds = NO;
    card.clipsToBounds = NO;
    card.layer.cornerRadius = PPCornerCard;
    if (@available(iOS 13.0, *)) {
        card.layer.cornerCurve = kCACornerCurveContinuous;
    }
    
    card.layer.shadowColor = AppShadowClr.CGColor;
    card.layer.shadowOpacity = 0.08;
    card.layer.shadowRadius = 14;
    card.layer.shadowOffset = CGSizeMake(0, 8);
    return card;
}


-(UIImageView *)createImageView
{
    UIImageView *imageView = [UIImageView new];
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;
    imageView.layer.cornerRadius = 18.0; // Refined for inner image
    if (@available(iOS 13.0, *)) {
        imageView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    imageView.backgroundColor = [UIColor colorWithWhite:0.96 alpha:1.0];
    return imageView;
}

-(UILabel *)createPriceLabel
{
    UILabel *priceLabel = [UILabel new];
    priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    priceLabel.font = [GM boldFontWithSize:18];
    priceLabel.textColor = UIColor.labelColor;
    priceLabel.adjustsFontSizeToFitWidth = YES;
    priceLabel.minimumScaleFactor = 0.8;
    return priceLabel;
}



- (UILabel *)createTitleLabel {
    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [GM boldFontWithSize:15];
    label.numberOfLines = 1;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.textColor = UIColor.labelColor;
    label.adjustsFontForContentSizeCategory = NO;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.82;

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
    lb.font = [GM MidFontWithSize:13];
    lb.textColor = UIColor.secondaryLabelColor;
    lb.numberOfLines = 1;
    lb.textAlignment = Language.alignmentForCurrentLanguage;
    return lb;
}

-(UIStackView *)createTextStackWithElements:(NSArray *)elemnts
{
    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:elemnts];
    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = 6; // Increased for better readability
    textStack.semanticContentAttribute = Language.isRTL ? UISemanticContentAttributeForceRightToLeft : UISemanticContentAttributeForceLeftToRight;
    
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
    discountValueLabel.textInsets = UIEdgeInsetsMake(4, 8, 4, 8);
    discountValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    discountValueLabel.font = [GM boldFontWithSize:11];
    discountValueLabel.textColor = [UIColor whiteColor];
    discountValueLabel.backgroundColor = [UIColor systemRedColor];
    discountValueLabel.layer.cornerRadius = 8;
    discountValueLabel.layer.masksToBounds = YES;
    discountValueLabel.textAlignment = NSTextAlignmentCenter;
    
    [discountValueLabel.heightAnchor constraintEqualToConstant:24.0].active = YES;
    return discountValueLabel;
}

- (PPInsetLabel *)createDiscountLabel
{
    PPInsetLabel *discountLabel = [PPInsetLabel new];
    discountLabel.textInsets = UIEdgeInsetsMake(1, 2, 1, 2);
    discountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    discountLabel.font = [GM MidFontWithSize:13];
    discountLabel.textColor = UIColor.secondaryLabelColor;
    discountLabel.backgroundColor = [UIColor clearColor];
    discountLabel.textAlignment = NSTextAlignmentCenter;
    return discountLabel;
}


- (UIStackView *)createPriceStackWithSubviews:(NSArray *)elemnts
{
    UIStackView *priceStack = [[UIStackView alloc] initWithArrangedSubviews:elemnts];
    priceStack.translatesAutoresizingMaskIntoConstraints = NO;
    priceStack.axis = UILayoutConstraintAxisHorizontal;
    priceStack.alignment = UIStackViewAlignmentFirstBaseline; // Better for price/discount alignment
    priceStack.spacing = 8;
    return priceStack;
}

#pragma mark - Build UI

- (UILabel *)badgeWithText:(NSString *)text bg:(UIColor *)bg {
    PPInsetLabel *l = [PPInsetLabel new];
    l.textInsets = UIEdgeInsetsMake(4, 8, 4, 8);
    l.translatesAutoresizingMaskIntoConstraints = NO;
    l.text = text;
    l.font = [GM boldFontWithSize:10.5];
    l.textColor = [UIColor whiteColor];
    l.backgroundColor = [bg colorWithAlphaComponent:0.9];
    l.textAlignment = NSTextAlignmentCenter;
    l.layer.cornerRadius = 6;
    l.layer.masksToBounds = YES;
    [l.heightAnchor constraintEqualToConstant:22.0].active = YES;
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
    qtyLabel.textInsets = UIEdgeInsetsMake(4, 10, 4, 10);
    qtyLabel.backgroundColor = [UIColor colorWithWhite:0.96 alpha:1.0];
    qtyLabel.layer.cornerRadius = 8;
    qtyLabel.layer.masksToBounds = YES;
    qtyLabel.layer.borderWidth = 1.0;
    qtyLabel.layer.borderColor = [[UIColor labelColor] colorWithAlphaComponent:0.06].CGColor;
    [qtyLabel.heightAnchor constraintEqualToConstant:24].active = YES;
    return qtyLabel;
}

- (UILabel *)createQtyLabel
{
    UILabel *qtyLabel = [UILabel new];
    qtyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    qtyLabel.text = @"0";
    qtyLabel.font = [GM boldFontWithSize:16];
    qtyLabel.textAlignment = NSTextAlignmentCenter;
    qtyLabel.textColor = AppPrimaryClr;
    [qtyLabel.widthAnchor constraintGreaterThanOrEqualToConstant:32].active = YES;
    return qtyLabel ;
}
- (UIView *)createStepperView
{
    UIView *stepperView = [UIView new];
    stepperView.translatesAutoresizingMaskIntoConstraints = NO;
    stepperView.backgroundColor = [UIColor colorWithWhite:0.96 alpha:1.0];
    stepperView.layer.cornerRadius = 12;
    stepperView.layer.masksToBounds = YES;
    stepperView.layer.borderWidth = 1.0;
    stepperView.layer.borderColor = [[UIColor labelColor] colorWithAlphaComponent:0.08].CGColor;
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
