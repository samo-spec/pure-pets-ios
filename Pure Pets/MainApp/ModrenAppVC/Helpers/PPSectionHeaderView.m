#import "PPSectionHeaderView.h"
#import <QuartzCore/QuartzCore.h>

@interface PPSectionHeaderView ()
<UIGestureRecognizerDelegate>

@property (nonatomic, strong) NSLayoutConstraint *titleTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *titleCenterConstraint;
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, assign) BOOL isExpanded;
@property (nonatomic, assign) PPHomeSection currentSection;
@property (nonatomic, assign) CFTimeInterval lastActionTimestamp;
@end

@implementation PPSectionHeaderView

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self buildUI];
    }
    return self;
}

#pragma mark - UI

- (void)buildUI {

    self.backgroundColor = UIColor.clearColor;
    
    // Modern section surface (2026)
    self.surfaceView = [[UIView alloc] init];
    self.surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.surfaceView.backgroundColor = [AppBackgroundClrLigter colorWithAlphaComponent:0.6];
    self.surfaceView.layer.cornerRadius = PPCornerMedium;

    // Modern subtle border
    self.surfaceView.layer.borderWidth = 0.5;
    self.surfaceView.layer.borderColor =
        [UIColor.separatorColor colorWithAlphaComponent:0.12].CGColor;
    
    // Design-system elevated shadow
    self.surfaceView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.surfaceView.layer.shadowOpacity = PPShadowCardOpacity;
    self.surfaceView.layer.shadowRadius = PPShadowCardRadius;
    self.surfaceView.layer.shadowOffset = CGSizeMake(0, PPShadowCardOffsetY);
    
    

    [self addSubview:self.surfaceView];
    [self sendSubviewToBack:self.surfaceView];
    
    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self
                                                 action:@selector(actionTapped)];
    tap.delegate = self;
    tap.cancelsTouchesInView = NO;
    [self addGestureRecognizer:tap];
    
    self.semanticContentAttribute = GM.setSemantic;
    // Title
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.textColor = UIColor.labelColor;

   
    self.titleLabel.font = [GM boldFontWithSize:PPFontTitle2];
    self.titleLabel.textColor = AppPrimaryTextClr;
    
    // Subtitle
    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.font = [GM MidFontWithSize:PPFontSubheadline];
    self.subtitleLabel.textColor = UIColor.secondaryLabelColor;
    self.subtitleLabel.numberOfLines = 1;
    self.subtitleLabel.hidden = YES;
    
    // Subtle shadow container
   
   
    [self addSubview:self.titleLabel];
    [self addSubview:self.subtitleLabel];
    // Action button (Glass)
    self.actionButton =
    [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleFixed
                                                     configType:PPButtonConfigrationFilled];
    self.actionButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionButton.hidden = YES;

    UIButtonConfiguration *cfg = self.actionButton.configuration;

    UIImageSymbolConfiguration *symbolCfg =
    [UIImageSymbolConfiguration configurationWithPointSize:17
                                                    weight:UIImageSymbolWeightSemibold
                                                     scale:UIImageSymbolScaleMedium];

    UIImage *symbol =
    [UIImage systemImageNamed:@"chevron.down"
             withConfiguration:symbolCfg];

    if (@available(iOS 15.0, *)) {
        symbol = [symbol imageByApplyingSymbolConfiguration:
                  [UIImageSymbolConfiguration configurationWithPaletteColors:@[UIColor.lightGrayColor,AppPrimaryClr]]];
    }

    cfg.image = symbol;
    cfg.imagePlacement = NSDirectionalRectEdgeTrailing;
    cfg.imagePadding = 6;
    cfg.background.cornerRadius = PPNewCorner;
    cfg.titleTextAttributesTransformer =
    ^NSDictionary<NSAttributedStringKey,id> * _Nonnull(NSDictionary<NSAttributedStringKey,id> *attrs) {
        NSMutableDictionary *m = attrs.mutableCopy;
        m[NSFontAttributeName] = [GM MidFontWithSize:14];
        m[NSForegroundColorAttributeName] = UIColor.secondaryLabelColor;
        return m;
    };
    cfg.background.backgroundColor = [AppBackgroundClrLigter colorWithAlphaComponent:0.0];
    cfg.baseBackgroundColor = [AppBackgroundClrLigter colorWithAlphaComponent:0.0];
    
    self.actionButton.configuration = cfg;

    [self.actionButton addTarget:self
                          action:@selector(actionTapped)
                forControlEvents:UIControlEventTouchUpInside];
   
    [self addSubview:self.actionButton];

    // Layout
    
    self.titleTopConstraint =
    [self.titleLabel.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor constant:4];

    self.titleCenterConstraint =
    [self.titleLabel.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor];

    self.titleTopConstraint.active = YES;
    self.titleCenterConstraint.active = NO;
    [NSLayoutConstraint activateConstraints:@[
        
        [self.surfaceView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:PPSpaceXS],
        [self.surfaceView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-PPSpaceXS],
        [self.surfaceView.topAnchor constraintEqualToAnchor:self.topAnchor constant:PPSpaceXS],
        [self.surfaceView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-PPSpaceXS],
        
        [self.actionButton.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-1],
        [self.actionButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],

        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:16],

        [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.actionButton.leadingAnchor constant:-8],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:1],
        [self.subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.actionButton.leadingAnchor constant:-8]
    ]];
    
}


- (void)hide
{
    self.actionButton.hidden = YES;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
}

#pragma mark - Configuration

 

- (void)configureWithTitle:(nullable NSString *)title
               actionTitle:(nullable NSString *)actionTitle
                  iconName:(nullable NSString *)iconName
                      menu:(nullable UIMenu *)menu
             ppHomeSection:(PPHomeSection)ppHomeSection{
    
    self.currentSection = ppHomeSection;
    self.actionButton.hidden = (ppHomeSection != PPHomeSectionMainKinds && actionTitle.length == 0);

    self.titleLabel.text = title;
    //NSLog(@"actionTitle title %@",actionTitle);
    
    if (actionTitle.length > 0) {
        [self.actionButton setTitle:actionTitle forState:UIControlStateNormal];
        self.actionButton.semanticContentAttribute =
        UISemanticContentAttributeForceLeftToRight;
        self.actionButton.hidden = NO;
    } else {
        self.actionButton.hidden = NO;
    }
    
    if(iconName.length > 0 && ppHomeSection != PPHomeSectionMainKinds)
    {
        UIButtonConfiguration *cfg = self.actionButton.configuration;
        UIImage *symbol = [UIImage pp_symbolNamed:iconName pointSize:16 weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleMedium palette:@[UIColor.grayColor] makeTemplate:YES];

        if (@available(iOS 15.0, *)) { symbol = [symbol imageByApplyingSymbolConfiguration: [UIImageSymbolConfiguration configurationWithPaletteColors:@[UIColor.grayColor]]];  }
        cfg.image = symbol;
        cfg.imagePlacement = NSDirectionalRectEdgeLeading;
        cfg.imagePadding = 6;
        self.actionButton.configuration = cfg;
        [self.actionButton setNeedsLayout];
    }
    
    
    
    

    if (menu) {
        self.actionButton.menu = menu;
        self.actionButton.showsMenuAsPrimaryAction = YES;
        [PPMenuHelper presentMenuFromButton:self.actionButton  Menu:menu  destructive:nil  handler:^(NSInteger index, NSString *title) {  }];
    } else {
        // 🔥 CRITICAL: disable menu behavior completely
        self.actionButton.showsMenuAsPrimaryAction = NO;
        self.actionButton.menu = nil;
    }
    
    self.titleTopConstraint.active = NO;
    self.titleCenterConstraint.active = YES;
    
    if(ppHomeSection == PPHomeSectionSuggestions) self.surfaceView.layer.cornerRadius = PPNewCorner; else self.surfaceView.layer.cornerRadius = PPNewCorner;
    
    if(ppHomeSection != PPHomeSectionMainKinds) return;
    BOOL expanded =
        (ppHomeSection == PPHomeSectionMainKinds && self.isExpanded);

    [self setExpanded:expanded animated:NO];
}

#pragma mark - Extended Configuration

- (void)configureWithTitle:(nullable NSString *)title
                  subtitle:(nullable NSString *)subtitle
               actionTitle:(nullable NSString *)actionTitle
                  iconName:(nullable NSString *)iconName
                      menu:(nullable UIMenu *)menu
             ppHomeSection:(PPHomeSection)ppHomeSection
{
    self.currentSection = ppHomeSection;
    self.actionButton.hidden = (ppHomeSection != PPHomeSectionMainKinds && actionTitle.length == 0);

    // Reuse existing logic
    [self configureWithTitle:title
                 actionTitle:actionTitle
                    iconName:iconName
                        menu:menu
               ppHomeSection:ppHomeSection];

    if (subtitle.length > 0) {
        self.subtitleLabel.text = subtitle;
        self.subtitleLabel.hidden = NO;
        
        self.titleTopConstraint.active = YES;
        self.titleCenterConstraint.active = NO;
        
    } else {
        self.subtitleLabel.text = nil;
        self.subtitleLabel.hidden = YES;
        
        self.titleTopConstraint.active = NO;
        self.titleCenterConstraint.active = YES;
        
    }
    
    BOOL expanded =
        (ppHomeSection == PPHomeSectionMainKinds && self.isExpanded);

    [self setExpanded:expanded animated:NO];
}

#pragma mark - Reuse

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.subtitleLabel.text = nil;
    self.subtitleLabel.hidden = YES;
    self.lastActionTimestamp = 0;
}

#pragma mark - Actions

- (void)actionTapped
{
    CFTimeInterval now = CACurrentMediaTime();
    if ((now - self.lastActionTimestamp) < 0.25) {
        return;
    }
    self.lastActionTimestamp = now;

    // Only MainKinds supports expand/collapse
    if (self.currentSection != PPHomeSectionMainKinds) {
        if (self.onTap) {
            self.onTap();
        }
        return;
    }

    [PPFunc triggerMediumHaptic];

    self.isExpanded = !self.isExpanded;
    [self setExpanded:self.isExpanded animated:YES];

    if (self.onTap) {
        self.onTap();
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
       shouldReceiveTouch:(UITouch *)touch
{
    (void)gestureRecognizer;

    UIView *view = touch.view;
    while (view) {
        if (view == self.actionButton) {
            return NO;
        }
        view = view.superview;
    }
    return YES;
}

#pragma mark - Arrow Rotation

- (void)setExpanded:(BOOL)expanded animated:(BOOL)animated
{
    _isExpanded = expanded;

    // Only rotate arrow for MainKinds
    if (self.currentSection != PPHomeSectionMainKinds) {
        self.actionButton.imageView.transform = CGAffineTransformIdentity;
        return;
    }

    CGFloat angle = expanded ? M_PI : 0;

    void (^animations)(void) = ^{
        self.actionButton.imageView.transform =
            CGAffineTransformMakeRotation(angle);
    };

    if (animated) {
        [UIView animateWithDuration:0.25
                              delay:0
             usingSpringWithDamping:0.85
              initialSpringVelocity:0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:animations
                         completion:nil];
    } else {
        animations();
    }
}

@end
