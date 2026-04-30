//
//  UserContactView.m
//  Pure Pets
//

#import "UserContactView.h"
#import <QuartzCore/QuartzCore.h>
#import "PPImageLoaderManager.h"
#import "UserModel.h"
#import "PPModernAvatarRenderer.h"
#import "PPVerifiedBadgeHelper.h"
@interface UserContactView ()

@property (nonatomic, copy) dispatch_block_t chatBlock;
@property (nonatomic, copy) dispatch_block_t callBlock;
@property (nonatomic, strong) UIImageView *verifiedBadgeView;
@property (nonatomic, strong) UIView *statusIndicatorView;
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIView *topGlowView;
@property (nonatomic, strong) UIView *bottomGlowView;
@property (nonatomic, strong) UILabel *eyebrowLabel;

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
    self.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = NO;
    self.adjustsImageWhenHighlighted = NO;
    

    [self pp_setShadowColor:UIColor.blackColor];
    self.layer.shadowOpacity = 0.08;
    self.layer.shadowRadius = 24.0;
    self.layer.shadowOffset = CGSizeMake(0.0, 14.0);

    self.surfaceView = [[UIView alloc] init];
    self.surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.surfaceView.backgroundColor = AppForgroundColr ?: UIColor.systemBackgroundColor;
    self.surfaceView.layer.cornerRadius = 28.0;
    self.surfaceView.layer.masksToBounds = YES;
    self.surfaceView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    [self.surfaceView pp_setBorderColor:[UIColor colorWithWhite:0.0 alpha:0.05]];
    if (@available(iOS 13.0, *)) {
        self.surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self addSubview:self.surfaceView];

    self.topGlowView = [[UIView alloc] init];
    self.topGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.topGlowView.userInteractionEnabled = NO;
    self.topGlowView.backgroundColor = [(AppPrimaryClr ?: [UIColor colorWithHexString:@"#CF375B"]) colorWithAlphaComponent:0.10];
    [self.surfaceView addSubview:self.topGlowView];

    self.bottomGlowView = [[UIView alloc] init];
    self.bottomGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomGlowView.userInteractionEnabled = NO;
    self.bottomGlowView.backgroundColor = [[UIColor colorWithHexString:@"#F3C46A"] colorWithAlphaComponent:0.10];
    [self.surfaceView addSubview:self.bottomGlowView];

    self.avatarImageView = [[UIImageView alloc] init];
    self.avatarImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarImageView.layer.cornerRadius = 26.0;
    self.avatarImageView.layer.masksToBounds = YES;
    self.avatarImageView.image = PPSYSImage(@"person.circle.fill");
    self.avatarImageView.tintColor = AppLightGrayColor;
    self.avatarImageView.backgroundColor = [[UIColor colorWithWhite:0.0 alpha:0.05] colorWithAlphaComponent:0.06];
    [self.surfaceView addSubview:self.avatarImageView];

    self.eyebrowLabel = [[UILabel alloc] init];
    self.eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.eyebrowLabel.font = [GM MidFontWithSize:11.0];
    self.eyebrowLabel.textColor = UIColor.secondaryLabelColor;
    self.eyebrowLabel.text = kLang(@"Contact Advertiser");
    self.eyebrowLabel.numberOfLines = 1;
    self.eyebrowLabel.textAlignment = GM.setAligment;
 
    self.nameLabel = [[UILabel alloc] init];
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.nameLabel.font = [GM boldFontWithSize:18.0];
    self.nameLabel.textColor = UIColor.labelColor;
    self.nameLabel.text = @"";
    self.nameLabel.numberOfLines = 1;
    self.nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.nameLabel.textAlignment = GM.setAligment;
 
    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.eyebrowLabel,
        self.nameLabel
    ]];
    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = 3.0;
    textStack.alignment = UIStackViewAlignmentFill;
     [self.surfaceView addSubview:textStack];

    // ---- Verified Badge (on avatar corner) ----
    self.verifiedBadgeView = [PPVerifiedBadgeHelper addBadgeToAvatarView:self.avatarImageView
                                                            inSuperview:self.surfaceView
                                                              badgeSize:16];

    self.statusIndicatorView = [[UIView alloc] init];
    self.statusIndicatorView.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusIndicatorView.backgroundColor = [UIColor colorWithHexString:@"#2FA36B"];
    self.statusIndicatorView.layer.cornerRadius = 5.0;
    self.statusIndicatorView.layer.borderWidth = 1.5;
    [self.statusIndicatorView pp_setBorderColor:UIColor.whiteColor];
    [self.surfaceView addSubview:self.statusIndicatorView];

    self.callButton = [self actionButtonWithSymbol:@"phone.fill"];
    self.callButton.accessibilityLabel = NSLocalizedString(@"a11y_btn_call_advertiser", @"Call advertiser");
    self.callButton.accessibilityHint  = NSLocalizedString(@"a11y_btn_call_advertiser_hint", @"Double-tap to call this person");
    [self.callButton addTarget:self action:@selector(callTapped) forControlEvents:UIControlEventTouchUpInside];

    self.chatButton = [self actionButtonWithSymbol:@"message.fill"];
    self.chatButton.accessibilityLabel = NSLocalizedString(@"a11y_btn_chat_advertiser", @"Chat with advertiser");
    self.chatButton.accessibilityHint  = NSLocalizedString(@"a11y_btn_chat_advertiser_hint", @"Double-tap to start a chat with this person");
    [self.chatButton addTarget:self action:@selector(chatTapped) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *actionsStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.callButton,
        self.chatButton
    ]];
    actionsStack.translatesAutoresizingMaskIntoConstraints = NO;
    actionsStack.axis = UILayoutConstraintAxisHorizontal;
    actionsStack.spacing = 10.0;
    actionsStack.alignment = UIStackViewAlignmentCenter;
    actionsStack.distribution = UIStackViewDistributionFill;
     [self.surfaceView addSubview:actionsStack];
    self.emptyCardBellowButtons = actionsStack;

    self.callButton.enabled = NO;
    self.chatButton.enabled = NO;
    self.callButton.alpha = 0.55;
    self.chatButton.alpha = 0.55;

    [NSLayoutConstraint activateConstraints:@[
        [self.surfaceView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.surfaceView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.surfaceView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.surfaceView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

        [self.topGlowView.widthAnchor constraintEqualToConstant:132.0],
        [self.topGlowView.heightAnchor constraintEqualToConstant:132.0],
        [self.topGlowView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:-54.0],
        [self.topGlowView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor constant:-64.0],

        [self.bottomGlowView.widthAnchor constraintEqualToConstant:146.0],
        [self.bottomGlowView.heightAnchor constraintEqualToConstant:146.0],
        [self.bottomGlowView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:52.0],
        [self.bottomGlowView.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor constant:64.0],

        [self.avatarImageView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:18.0],
        [self.avatarImageView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.avatarImageView.widthAnchor constraintEqualToConstant:52.0],
        [self.avatarImageView.heightAnchor constraintEqualToConstant:52.0],

        [self.statusIndicatorView.trailingAnchor constraintEqualToAnchor:self.avatarImageView.trailingAnchor constant:0],
        [self.statusIndicatorView.bottomAnchor constraintEqualToAnchor:self.avatarImageView.bottomAnchor constant:0],
        [self.statusIndicatorView.widthAnchor constraintEqualToConstant:10],
        [self.statusIndicatorView.heightAnchor constraintEqualToConstant:10],

        [textStack.leadingAnchor constraintEqualToAnchor:self.avatarImageView.trailingAnchor constant:14.0],
        [textStack.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [textStack.trailingAnchor constraintLessThanOrEqualToAnchor:actionsStack.leadingAnchor constant:-12.0],

        [actionsStack.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-16.0],
        [actionsStack.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],

        [self.callButton.widthAnchor constraintGreaterThanOrEqualToConstant:78.0],
        [self.callButton.heightAnchor constraintEqualToConstant:44.0],
        [self.chatButton.widthAnchor constraintGreaterThanOrEqualToConstant:78.0],
        [self.chatButton.heightAnchor constraintEqualToConstant:44.0],
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
    btn.titleLabel.font = [GM boldFontWithSize:13.0];
    btn.semanticContentAttribute = Language.isRTL ? UISemanticContentAttributeForceRightToLeft : UISemanticContentAttributeForceLeftToRight;
    btn.imageEdgeInsets = UIEdgeInsetsMake(0, -3, 0, 3);
    btn.titleEdgeInsets = UIEdgeInsetsMake(0, 3, 0, -3);
    if ([symbol containsString:@"phone"]) {
        [btn setTitle:kLang(@"Call") forState:UIControlStateNormal];
    } else {
        [btn setTitle:kLang(@"Chat") forState:UIControlStateNormal];
    }
    [btn setTitleColor:UIColor.labelColor forState:UIControlStateNormal];

    BOOL primary = [symbol containsString:@"phone"];
    UIColor *accent = AppPrimaryClr ?: [UIColor colorWithHexString:@"#CF375B"];
    btn.backgroundColor = primary ? [accent colorWithAlphaComponent:0.78] : UIColor.clearColor;
    btn.tintColor = primary ? UIColor.whiteColor : accent;
    [btn setTitleColor:(primary ? UIColor.whiteColor : accent) forState:UIControlStateNormal];
    btn.layer.cornerRadius = 22.0;
    btn.layer.masksToBounds = YES;
    btn.layer.borderWidth = primary ? 0.0 : 1.4;
    [btn pp_setBorderColor:primary ? UIColor.clearColor : [accent colorWithAlphaComponent:0.48]];
    btn.contentEdgeInsets = UIEdgeInsetsMake(0.0, 12.0, 0.0, 12.0);

    return btn;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
 
    self.nameLabel.textAlignment = GM.setAligment;
    self.eyebrowLabel.textAlignment = GM.setAligment;
    self.callButton.semanticContentAttribute = Language.isRTL ? UISemanticContentAttributeForceRightToLeft : UISemanticContentAttributeForceLeftToRight;
    self.chatButton.semanticContentAttribute = Language.isRTL ? UISemanticContentAttributeForceRightToLeft : UISemanticContentAttributeForceLeftToRight;
    self.topGlowView.layer.cornerRadius = CGRectGetWidth(self.topGlowView.bounds) * 0.5;
    self.bottomGlowView.layer.cornerRadius = CGRectGetWidth(self.bottomGlowView.bounds) * 0.5;
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                                        cornerRadius:self.surfaceView.layer.cornerRadius].CGPath;
}

#pragma mark - Configure

- (void)configureWithUser:(UserModel *)user
             chatCallback:(dispatch_block_t)chatBlock
             callCallback:(dispatch_block_t)callBlock
{
    self.chatBlock = chatBlock;
    self.callBlock = callBlock;

    self.nameLabel.text = user.PPBestDisplayName ?: user.UserName ?: kLang(@"Contact Advertiser");
    self.verifiedBadgeView.hidden = !user.isVerified;

    BOOL canContact = ![user.ID isEqualToString:PPCurrentUser.ID];
    self.callButton.enabled = canContact;
    self.chatButton.enabled = canContact;
    self.callButton.alpha = canContact ? 1.0 : 0.55;
    self.chatButton.alpha = canContact ? 1.0 : 0.55;

    // ── Accessibility: Update contact view label with user name ──
    self.isAccessibilityElement = NO; // Let children be individually accessible
    NSString *displayName = self.nameLabel.text;
    self.callButton.accessibilityLabel = [NSString stringWithFormat:
        NSLocalizedString(@"a11y_btn_call_user_format", @"Call %@"), displayName];
    self.chatButton.accessibilityLabel = [NSString stringWithFormat:
        NSLocalizedString(@"a11y_btn_chat_user_format", @"Chat with %@"), displayName];
    
    [PPImageLoaderManager.shared setImageOnImageView:self.avatarImageView url:user.UserImageUrl.absoluteString placeholder:[PPModernAvatarRenderer avatarImageForName:user.UserName size:44] complation:^(UIImage * _Nonnull image,
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
        [self pp_setShadowColor:[UIColor blackColor]];
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
        _avatarView.image = [PPModernAvatarRenderer avatarImageForName:user.UserName size:44];
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
