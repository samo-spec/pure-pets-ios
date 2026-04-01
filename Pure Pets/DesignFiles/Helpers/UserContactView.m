//
//  UserContactView.m
//  Pure Pets
//

#import "UserContactView.h"
#import <QuartzCore/QuartzCore.h>
#import "PPImageLoaderManager.h"
#import "UserModel.h"
@interface UserContactView ()

@property (nonatomic, copy) dispatch_block_t chatBlock;
@property (nonatomic, copy) dispatch_block_t callBlock;

@end

@implementation UserContactView

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

#pragma mark - Setup

- (void)commonInit
{
    //self.backgroundColor = AppForgroundColr;
    self.adjustsImageWhenHighlighted = NO;

    // ---- Glass Container ----
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    blurView.layer.cornerRadius = 22.0;
    blurView.layer.masksToBounds = YES;
    [self addSubview:blurView];

    // Subtle border (liquid glass look)
    blurView.layer.borderWidth = 0.3;
    blurView.layer.borderColor = UIColor.separatorColor.CGColor;

    // ---- Shadow ----
    self.layer.shadowColor = UIColor.blackColor.CGColor;
    self.layer.shadowOpacity = 0.04;
    self.layer.shadowRadius = 4;
    self.layer.shadowOffset = CGSizeMake(0, 10);

    // ---- Avatar ----
    self.avatarImageView = [[UIImageView alloc] init];
    self.avatarImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarImageView.layer.cornerRadius = 22;
    self.avatarImageView.layer.masksToBounds = YES;
    self.avatarImageView.image = PPSYSImage(@"person.circle.fill");
    self.avatarImageView.tintColor = AppLightGrayColor;;

    [blurView.contentView addSubview:self.avatarImageView];
    // ---- Name ----
    self.nameLabel = [[UILabel alloc] init];
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.nameLabel.font = [GM boldFontWithSize:17];
    self.nameLabel.textColor = UIColor.labelColor;
    self.nameLabel.text = kLang(@"Contact Advertiser");
    [blurView.contentView addSubview:self.nameLabel];

    // ---- Call Button ----
    self.callButton = [self actionButtonWithSymbol:@"phone.fill"];
    [self.callButton addTarget:self action:@selector(callTapped) forControlEvents:UIControlEventTouchUpInside];
    [blurView.contentView addSubview:self.callButton];

    // ---- Chat Button ----
    self.chatButton = [self actionButtonWithSymbol:@"message.fill"];
    [self.chatButton addTarget:self action:@selector(chatTapped) forControlEvents:UIControlEventTouchUpInside];
    [blurView.contentView addSubview:self.chatButton];
    self.callButton.enabled = NO;
    self.chatButton.enabled = NO;
    self.callButton.alpha = 0.55;
    self.chatButton.alpha = 0.55;

    // ---- Layout ----
    [NSLayoutConstraint activateConstraints:@[
        [blurView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

        [self.avatarImageView.leadingAnchor constraintEqualToAnchor:blurView.contentView.leadingAnchor constant:14],
        [self.avatarImageView.centerYAnchor constraintEqualToAnchor:blurView.contentView.centerYAnchor],
        [self.avatarImageView.widthAnchor constraintEqualToConstant:44],
        [self.avatarImageView.heightAnchor constraintEqualToConstant:44],

        [self.nameLabel.leadingAnchor constraintEqualToAnchor:self.avatarImageView.trailingAnchor constant:12],
        [self.nameLabel.centerYAnchor constraintEqualToAnchor:blurView.contentView.centerYAnchor],

        [self.chatButton.trailingAnchor constraintEqualToAnchor:blurView.contentView.trailingAnchor constant:-14],
        [self.chatButton.centerYAnchor constraintEqualToAnchor:blurView.contentView.centerYAnchor],
        [self.chatButton.widthAnchor constraintEqualToConstant:40],
        [self.chatButton.heightAnchor constraintEqualToConstant:40],

        [self.callButton.trailingAnchor constraintEqualToAnchor:self.chatButton.leadingAnchor constant:-12],
        [self.callButton.centerYAnchor constraintEqualToAnchor:blurView.contentView.centerYAnchor],
        [self.callButton.widthAnchor constraintEqualToConstant:40],
        [self.callButton.heightAnchor constraintEqualToConstant:40],
    ]];
}

#pragma mark - Button Factory

- (UIButton *)actionButtonWithSymbol:(NSString *)symbol
{
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.translatesAutoresizingMaskIntoConstraints = NO;

    UIImageSymbolConfiguration *cfg =
    [UIImageSymbolConfiguration configurationWithPointSize:17
                                                     weight:UIImageSymbolWeightSemibold
                                                     scale:UIImageSymbolScaleLarge];

    UIImage *img = [UIImage imageNamed:symbol] ?: [UIImage systemImageNamed:symbol withConfiguration:cfg];
    [btn setImage:img forState:UIControlStateNormal];
    btn.tintColor = UIColor.labelColor;

    btn.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.6];
    btn.layer.cornerRadius = 20;
    btn.layer.masksToBounds = YES;

    return btn;
}

#pragma mark - Configure

- (void)configureWithUser:(UserModel *)user
             chatCallback:(dispatch_block_t)chatBlock
             callCallback:(dispatch_block_t)callBlock
{
    self.chatBlock = chatBlock;
    self.callBlock = callBlock;

    self.nameLabel.text = user.PPBestDisplayName ?: user.UserName ?: kLang(@"Contact Advertiser");
    /*
     if([self.ad.ownerID isEqualToString:PPCurrentUser.ID])
     {
         self.contactView.userInteractionEnabled = NO;
         self.contactView.alpha = 0.85;
         
     }
     */
    
    BOOL canContact = ![user.ID isEqualToString:PPCurrentUser.ID];
    self.callButton.enabled = canContact;
    self.chatButton.enabled = canContact;
    self.callButton.alpha = canContact ? 1.0 : 0.55;
    self.chatButton.alpha = canContact ? 1.0 : 0.55;
    
    [PPImageLoaderManager.shared setImageOnImageView:self.avatarImageView url:user.UserImageUrl.absoluteString placeholder:PPSYSImage(@"person.crop.circle.fill") complation:^(UIImage * _Nonnull image,
                                                                                                                                                    NSString * _Nullable urlString) {
        
    }];
    // Assume you already load images elsewhere (SDWebImage / PPImageLoader)
    // self.avatarImageView.image = ...
}

#pragma mark - Actions

- (void)chatTapped
{
    if (self.chatBlock) {
        self.chatBlock();
    }
}

- (void)callTapped
{
    if (self.callBlock) {
        self.callBlock();
    }
}

@end


/*

#import <UIKit/UIKit.h>
#import "UserContactView.h"
#import "UserModel.h"
@implementation UserContactView {
    UILabel *_titleLabel;
    //UIView  *_separatorLine;   // NEW
    UIImageView *_avatarView;
    UILabel *_nameLabel;
    UIButton *_chatButton;
    UIButton *_callButton;
 
    dispatch_block_t _chatBlock;
    dispatch_block_t _callBlock;
}



- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {

        self.backgroundColor = UIColor.clearColor;
        self.clipsToBounds = NO;

        // --- Shadow for the whole card ---
        self.layer.shadowColor   = [UIColor blackColor].CGColor;
        self.layer.shadowOpacity = 0.16;
        self.layer.shadowOffset  = CGSizeMake(0, 4);
        self.layer.shadowRadius  = 8;
        self.layer.masksToBounds = NO;

        // --- Title Label ---
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.text = kLang(@"Contact Advertiser");
        _titleLabel.font = [GM MidFontWithSize:13];
        _titleLabel.textColor = [GM.SecondaryTextColor colorWithAlphaComponent:0.8];
        _titleLabel.textAlignment = GM.setAligment;
        [self addSubview:_titleLabel];

        // --- Avatar Image ---
        _avatarView = [[UIImageView alloc] init];
        _avatarView.translatesAutoresizingMaskIntoConstraints = NO;
        _avatarView.layer.cornerRadius = 25;
        _avatarView.clipsToBounds = YES;
        _avatarView.contentMode = UIViewContentModeScaleAspectFill;
        [self addSubview:_avatarView];

        // --- Name Label ---
        _nameLabel = [[UILabel alloc] init];
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _nameLabel.textColor = GM.PrimaryTextColor;
        _nameLabel.font = [GM MidFontWithSize:16];
        [self addSubview:_nameLabel];

        // --- Empty Card Behind Buttons ---
        self.emptyCardBellowButtons = [PPFunc createEmptyModernCardView];
        [self addSubview:self.emptyCardBellowButtons];
        self.emptyCardBellowButtons.backgroundColor = AppBackgroundClr;
        self.emptyCardBellowButtons.layer.shadowOpacity = 0.07;
        self.emptyCardBellowButtons.layer.shadowOffset = CGSizeMake(0, 2);
        self.emptyCardBellowButtons.layer.shadowRadius = 6.0;
        self.emptyCardBellowButtons.layer.cornerRadius = 23;
        self.emptyCardBellowButtons.translatesAutoresizingMaskIntoConstraints = NO;

        // --- Buttons (Glass Circular) ---
        _chatButton = [self PPCircleButtonWithTintColor:AppPrimaryClr
                                        backgroundColor:AppBackgroundClr
                                               andImage:@"message"];

        _callButton = [self PPCircleButtonWithTintColor:AppPrimaryClr
                                        backgroundColor:AppBackgroundClr
                                               andImage:@"phone"];

        [_callButton addTarget:self action:@selector(callTapped)
              forControlEvents:UIControlEventTouchUpInside];
        [_chatButton addTarget:self action:@selector(chatTapped)
              forControlEvents:UIControlEventTouchUpInside];

        [self.emptyCardBellowButtons addSubview:_chatButton];
        [self.emptyCardBellowButtons addSubview:_callButton];
        _chatButton.translatesAutoresizingMaskIntoConstraints = NO;
        _callButton.translatesAutoresizingMaskIntoConstraints = NO;

        // --- Layout Constants ---
        CGFloat pad = 12.0;

        // --- Auto Layout Constraints ---
        [NSLayoutConstraint activateConstraints:@[
            // Avatar
            [_avatarView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:pad],
            [_avatarView.topAnchor constraintEqualToAnchor:self.topAnchor constant:0],
            [_avatarView.widthAnchor constraintEqualToConstant:50],
            [_avatarView.heightAnchor constraintEqualToConstant:50],

            // Title
            [_titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:8],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:_avatarView.trailingAnchor constant:pad],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-pad],
            [_titleLabel.heightAnchor constraintEqualToConstant:16],

            // Name
            [_nameLabel.leadingAnchor constraintEqualToAnchor:_avatarView.trailingAnchor constant:pad],
            [_nameLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4],
            [_nameLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-pad],

            // Button Card
            [self.emptyCardBellowButtons.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-pad],
            [self.emptyCardBellowButtons.topAnchor constraintEqualToAnchor:self.topAnchor constant:0],
            [self.emptyCardBellowButtons.heightAnchor constraintEqualToConstant:60],
            [self.emptyCardBellowButtons.widthAnchor constraintEqualToConstant:120],

            // Call button
            [_callButton.trailingAnchor constraintEqualToAnchor:self.emptyCardBellowButtons.trailingAnchor constant:-10],
            [_callButton.centerYAnchor constraintEqualToAnchor:self.emptyCardBellowButtons.centerYAnchor],
            [_callButton.widthAnchor constraintEqualToConstant:44],
            [_callButton.heightAnchor constraintEqualToConstant:44],

            // Chat button
            [_chatButton.trailingAnchor constraintEqualToAnchor:_callButton.leadingAnchor constant:-10],
            [_chatButton.centerYAnchor constraintEqualToAnchor:self.emptyCardBellowButtons.centerYAnchor],
            [_chatButton.widthAnchor constraintEqualToConstant:44],
            [_chatButton.heightAnchor constraintEqualToConstant:44],

            // Ensure bottom anchoring for layout height
            [self.bottomAnchor constraintGreaterThanOrEqualToAnchor:_avatarView.bottomAnchor constant:8]
        ]];
    }

    return self;
}




- (UIButton *)PPCircleButtonWithTintColor:(UIColor *)tintColor
                           backgroundColor:(UIColor *)bgColor
                                 andImage:(NSString *)imageName{
    UIButton *button;

    if (@available(iOS 26.0, *)) {
        // 🧊 New glass-style configuration (iOS 26+)
        UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
        cfg.preferredSymbolConfigurationForImage  = [PPColorUtils imageConfig:22 weight:UIImageSymbolWeightHeavy scale:UIImageSymbolScaleLarge palette:@[AppPrimaryClr,AppPrimaryClrDarker] fallbackTint:AppPrimaryClr renderOriginal:YES];
        
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(12, 12, 12, 12);
        cfg.buttonSize = UIButtonConfigurationSizeMedium;
        cfg.baseForegroundColor = tintColor ?: UIColor.whiteColor;

        
        
        
        UIImageSymbolConfiguration *symbolConfig;

        if (@available(iOS 17.0, *)) {
            // Modern configuration supporting hierarchical + gradient rendering
            symbolConfig =
            [[UIImageSymbolConfiguration configurationWithHierarchicalColor:AppPrimaryClr]
                 configurationByApplyingConfiguration:
                 [UIImageSymbolConfiguration configurationWithPointSize:16
                                                                  weight:UIImageSymbolWeightRegular
                                                                  scale:UIImageSymbolScaleLarge]];

            
        } else {
            // Older fallback (no hierarchical gradients)
            symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightRegular];
        }

        // Apply configuration to your system image
        UIImage *img = [UIImage systemImageNamed:imageName withConfiguration:symbolConfig];
 
        //cfg.image = img;
        button = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
        button.configuration = cfg;
        [button setImage:img forState:UIControlStateNormal];
        [button setImage:[UIImage systemImageNamed:[NSString stringWithFormat:@"%@.fill",imageName] withConfiguration:symbolConfig] forState:UIControlStateSelected];
        [button setImage:[UIImage systemImageNamed:[NSString stringWithFormat:@"%@.fill",imageName] withConfiguration:symbolConfig] forState:UIControlStateHighlighted];
        [button setTintColor:tintColor];
        
        cfg.preferredSymbolConfigurationForImage  = [PPColorUtils imageConfig:22 weight:UIImageSymbolWeightHeavy scale:UIImageSymbolScaleLarge palette:@[AppPrimaryClr,AppPrimaryClrDarker] fallbackTint:AppPrimaryClr renderOriginal:YES];
        
    } else if (@available(iOS 15.0, *)) {
        // 🌫 Fallback for iOS 15–25: manual glass look using filled configuration
        UIButtonConfiguration *cfg = [UIButtonConfiguration filledButtonConfiguration];
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.baseForegroundColor = tintColor ?: UIColor.whiteColor;
        cfg.background.visualEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark];
        cfg.background.backgroundColor = bgColor ?: [[UIColor colorWithWhite:0 alpha:0.3] colorWithAlphaComponent:0.4];
        cfg.background.strokeColor = [UIColor colorWithWhite:1 alpha:0.15];
        cfg.background.strokeWidth = 1.0;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(12, 12, 12, 12);
        cfg.buttonSize = UIButtonConfigurationSizeMedium;
       
        UIImageSymbolConfiguration *symbolConfig;

        if (@available(iOS 17.0, *)) {
            // Modern configuration supporting hierarchical + gradient rendering
            symbolConfig = [UIImageSymbolConfiguration configurationWithHierarchicalColor:AppPrimaryClr];
        } else {
            // Older fallback (no hierarchical gradients)
            symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightRegular];
        }

        // Apply configuration to your system image
        UIImage *img = [UIImage systemImageNamed:imageName withConfiguration:symbolConfig];
 
        cfg.image = img;
        button = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
        button.configuration = cfg;
        button.clipsToBounds = YES;

    } else {
        // ⚙️ Legacy (< iOS 15): create custom circular blur button
        button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tintColor = tintColor ?: UIColor.whiteColor;
        button.backgroundColor = bgColor ?: [[UIColor colorWithWhite:0 alpha:0.3] colorWithAlphaComponent:0.4];
        button.layer.cornerRadius = 25;
        button.clipsToBounds = YES;

        UIVisualEffectView *blur = [[UIVisualEffectView alloc]
            initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
        blur.frame = button.bounds;
        blur.userInteractionEnabled = NO;
        blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [button insertSubview:blur atIndex:0];
        
        [button setImage:[UIImage systemImageNamed:imageName] forState:UIControlStateNormal];
        [button setTintColor:AppPrimaryClr];
        [button.imageView setTintColor:AppPrimaryClr];
    }

    // Enforce circular shape (update after layout)
    button.layer.cornerRadius = 25;
    button.clipsToBounds = YES;
    button.translatesAutoresizingMaskIntoConstraints = NO;

    return button;
}




- (void)layoutSubviews {
    [super layoutSubviews];
    [PPFunc removeOldGradientsFromView:self];
    CGRect frame = CGRectMake(0, 0, self.hx_w + 0, self.hx_h + 0);
    CAGradientLayer *gradient = [UIView gradientLayerWithFadeForColor:AppBackgroundClr direction:PPGradientDirectionBottomToTop frame:frame];

    gradient.cornerRadius = 8;
    gradient.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    [self.layer insertSublayer:gradient atIndex:0];
    self.semanticContentAttribute = GM.setSemantic;
    
    
    
    

 ///[self bringSubviewToFront:_avatarView];
}


- (void)configureWithUser:(UserModel *)user
             chatCallback:(dispatch_block_t)chatBlock
             callCallback:(dispatch_block_t)callBlock {
    _nameLabel.text = user.UserName ?: @"Unknown";
    _chatBlock = chatBlock;
    _callBlock = callBlock;
    
    NSLog(@"user.UserImageUrl %@",user.UserImageUrl.absoluteString);
    if (user.UserImageUrl) {
        [GM setImageFromUrlString:user.UserImageUrl.absoluteString
                        imageView:_avatarView
                         phImage:@"person.crop.circle.fill"
                       completion:^(UIImage * _Nullable image, NSError * _Nullable error) {
        }];

    } else {
        _avatarView.image = [UIImage systemImageNamed:@"person.crop.circle.fill"];
    }
    [self setNeedsLayout];
    _avatarView.layer.cornerRadius = _avatarView.hx_h / 2;
   // [self bringSubviewToFront:_avatarView];
}

- (void)chatTapped {
    if (_chatBlock) _chatBlock();
}

- (void)callTapped {
    if (_callBlock) _callBlock();
}

@end

 
*/
