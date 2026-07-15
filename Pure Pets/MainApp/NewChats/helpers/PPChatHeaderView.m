//
//  PPChatHeaderView 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 17/01/2026.
//


#import "PPChatHeaderView.h"
#import "PPModernAvatarRenderer.h"
#import "PPVerifiedBadgeHelper.h"

static NSString * const PPChatHeaderSupportAvatarToken = @"purepets://support-logo";

static BOOL PPChatHeaderUsesSupportLogo(UserModel *user) {
    NSString *avatarURL = user.UserImageUrl.absoluteString ?: @"";
    return [avatarURL hasPrefix:PPChatHeaderSupportAvatarToken];
}

static UIImage *PPChatHeaderSupportLogoImage(void) {
    return [UIImage imageNamed:@"PPLogo"] ?: [UIImage systemImageNamed:@"person.crop.circle.fill"];
}

@interface PPChatHeaderView ()

@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIView *blurView;
@property (nonatomic, strong) UIStackView *labelsStack;

@property (nonatomic, strong) UIView *onlineDotView;
@property (nonatomic, strong) UIImageView *verifiedBadgeView;
@property (nonatomic, strong) UserModel *currentUser;
@property (nonatomic, strong) _Nullable id<FIRListenerRegistration> presenceListener;

@property (nonatomic, strong) NSMutableArray *typingDots;
@property (nonatomic, strong) UIView *typingBubble;

@property (nonatomic, strong) UIButton *dismissButton;


@end

@implementation PPChatHeaderView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = NO;

    [self createPremiumBlurBackground];

    // Dismiss (close) button, glass style
    self.dismissButton =
    [PPButtonHelper buttonWithSystemName:@"xmark" target:self action:@selector(onDismissTapped)]; 
    self.dismissButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.dismissButton.tintColor = UIColor.secondaryLabelColor;
    [self.blurView addSubview:self.dismissButton];
    
    
    // --- Avatar ---
    self.avatarView = [[UIImageView alloc] init];
    self.avatarView.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarView.layer.cornerRadius = 22;
    self.avatarView.clipsToBounds = YES;
    self.avatarView.contentMode = UIViewContentModeScaleAspectFill;
    [self.blurView addSubview:self.avatarView];

    self.avatarView.userInteractionEnabled = YES;
    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self
                                                action:@selector(handleAvatarTap)];
    [self.avatarView addGestureRecognizer:tap];

    self.onlineDotView = [[UIView alloc] init];
    self.onlineDotView.translatesAutoresizingMaskIntoConstraints = NO;
    self.onlineDotView.backgroundColor = [UIColor systemGreenColor];
    self.onlineDotView.layer.cornerRadius = 6;
    self.onlineDotView.layer.borderWidth = 2;
    [self.onlineDotView pp_setBorderColor:UIColor.systemBackgroundColor];
    self.onlineDotView.hidden = YES;

    [self addSubview:self.onlineDotView];

    // Verified badge on avatar corner (14pt for 44pt avatar)
    self.verifiedBadgeView = [PPVerifiedBadgeHelper addBadgeToAvatarView:self.avatarView
                                                            inSuperview:self
                                                              badgeSize:14];

    self.nameLabel = [[UILabel alloc] init];
    self.nameLabel.font = [GM boldFontWithSize:16];
    self.nameLabel.textColor = UIColor.labelColor;
    self.nameLabel.numberOfLines = 1;

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font = [GM fontWithSize:14];
    self.statusLabel.textColor = UIColor.secondaryLabelColor;
    self.statusLabel.numberOfLines = 1;

    self.labelsStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.nameLabel,
        self.statusLabel
    ]];
    self.labelsStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.labelsStack.axis = UILayoutConstraintAxisVertical;
    self.labelsStack.spacing = 2;
    self.labelsStack.alignment = UIStackViewAlignmentLeading;

    [self.blurView addSubview:self.labelsStack];

    // --- Constraints ---
    [NSLayoutConstraint activateConstraints:@[
        [self.blurView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.blurView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.blurView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.blurView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

        [self.avatarView.leadingAnchor constraintEqualToAnchor:self.blurView.leadingAnchor constant:12],
        [self.avatarView.centerYAnchor constraintEqualToAnchor:self.blurView.centerYAnchor],
        [self.avatarView.widthAnchor constraintEqualToConstant:44],
        [self.avatarView.heightAnchor constraintEqualToConstant:44],

        [self.onlineDotView.widthAnchor constraintEqualToConstant:12],
        [self.onlineDotView.heightAnchor constraintEqualToConstant:12],
        [self.onlineDotView.trailingAnchor constraintEqualToAnchor:self.avatarView.trailingAnchor constant:-1],
        [self.onlineDotView.bottomAnchor constraintEqualToAnchor:self.avatarView.bottomAnchor constant:-1],

        [self.labelsStack.leadingAnchor constraintEqualToAnchor:self.avatarView.trailingAnchor constant:10],
        [self.labelsStack.centerYAnchor constraintEqualToAnchor:self.avatarView.centerYAnchor],
        [self.labelsStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.blurView.trailingAnchor constant:-12],

        [self.dismissButton.trailingAnchor constraintEqualToAnchor:self.blurView.trailingAnchor constant:-12],
        [self.dismissButton.centerYAnchor constraintEqualToAnchor:self.blurView.centerYAnchor],
        [self.dismissButton.widthAnchor constraintEqualToConstant:32],
        [self.dismissButton.heightAnchor constraintEqualToConstant:32],
    ]];

    [self setupTypingBubbleIfNeeded];
   
   
    
    return self;
}


#pragma mark - Public

- (void)configureWithUser:(UserModel *)user
{
    self.currentUser = user;
    self.verifiedBadgeView.hidden = !user.isVerified;

    self.nameLabel.text = [user PPBestDisplayName];

    // Animate status + online dot
    NSString *newStatusText = @"";
    BOOL shouldShowDot = NO;

    if (user.isOnline) {
        newStatusText = kLang(@"Online");
        shouldShowDot = YES;
    } else if (user.lastSeen) {
        newStatusText = [ChManager formattedLastSeen:user.lastSeen];
        shouldShowDot = NO;
    } else {
        newStatusText = @"";
        shouldShowDot = NO;
    }

    // --- Animate status label crossfade ---
    if (![self.statusLabel.text isEqualToString:newStatusText]) {
        [UIView transitionWithView:self.statusLabel
                          duration:0.2
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
            self.statusLabel.text = newStatusText;
        } completion:nil];
    }
    //shouldShowDot = YES;
    // --- Animate online dot fade ---
    if (shouldShowDot && self.onlineDotView.hidden) {
        self.onlineDotView.hidden = NO;
        self.onlineDotView.alpha = 0.0;
        [UIView animateWithDuration:0.2 animations:^{
            self.onlineDotView.alpha = 1.0;
        }];
    } else if (!shouldShowDot && !self.onlineDotView.hidden) {
        [UIView animateWithDuration:0.2 animations:^{
            self.onlineDotView.alpha = 0.0;
        } completion:^(BOOL finished) {
            self.onlineDotView.hidden = YES;
        }];
    }
   
    if (PPChatHeaderUsesSupportLogo(user)) {
        self.avatarView.image = PPChatHeaderSupportLogoImage();
        self.avatarView.contentMode = UIViewContentModeScaleAspectFit;
        self.avatarView.backgroundColor = UIColor.whiteColor;
    } else {
        self.avatarView.contentMode = UIViewContentModeScaleAspectFill;
        self.avatarView.backgroundColor = UIColor.clearColor;
        [self.avatarView sd_setImageWithURL:user.UserImageUrl
                           placeholderImage:[PPModernAvatarRenderer avatarImageForName:user.UserName size:44]];
    }
    
    [self startListeningToUserPresence:user];
}

- (void)updateStatusText:(NSString *)status
{
    self.statusLabel.text = status;
}

- (void)handleAvatarTap
{
    if (!self.currentUser) return;

    NSLog(@"👤 [Chat] Avatar tapped for userID=%@", self.currentUser.ID);

    UIViewController *vc = [self pp_parentViewController];
    if (!vc) return;

    //[PPOverlayCoordinator pp_openUserProfile:self.currentUser fromVC:vc];
}

- (UIViewController *)pp_parentViewController
{
    UIResponder *responder = self;
    while (responder) {
        responder = responder.nextResponder;
        if ([responder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)responder;
        }
    }
    return nil;
}

- (void)stopListeningToPresence
{
    if (self.presenceListener) {
        [self.presenceListener remove];
        self.presenceListener = nil;
    }
}

- (void)dealloc
{
    [self stopListeningToPresence];
}

- (void)startListeningToUserPresence:(UserModel *)user
{
    if (!user.ID.length) return;

    // Stop previous listener if any
    [self stopListeningToPresence];

    FIRDocumentReference *ref =
    [[[FIRFirestore firestore]
      collectionWithPath:@"UserPresence"]
     documentWithPath:user.ID];

    __weak typeof(self) weakSelf = self;
    self.presenceListener =
    [ref addSnapshotListener:^(FIRDocumentSnapshot *snapshot, NSError *error) {

        if (error || !snapshot.exists) return;

        NSDictionary *data = snapshot.data;
        if (!data) return;

        // Update model safely
        UserModel *updatedUser = user;
        updatedUser.isOnline = [data[@"online"] boolValue];
        updatedUser.lastSeen = data[@"lastSeen"];

        // UI must update on main thread
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{
            [weakSelf configureWithUser:updatedUser];
        });
    }];
}




- (UIView *)buildTypingBubble
{
    UIView *bubble = [[UIView alloc] init];
    bubble.backgroundColor = AppBackgroundClr;
    bubble.layer.cornerRadius = 16;
    bubble.translatesAutoresizingMaskIntoConstraints = NO;
    bubble.alpha = 1.0;

    NSMutableArray *dots = [NSMutableArray array];

    for (int i = 0; i < 3; i++) {
        UIView *dot = [[UIView alloc] init];
        dot.backgroundColor = [UIColor secondaryLabelColor];
        dot.layer.cornerRadius = 4;
        dot.translatesAutoresizingMaskIntoConstraints = NO;
        [bubble addSubview:dot];
        [dots addObject:dot];
    }

    self.typingDots = dots;
    self.typingBubble = bubble;

    return bubble;
}


- (void)setupTypingBubbleIfNeeded
{
    if (self.typingBubble) return;

    self.typingBubble = [[UIView alloc] init];
    self.typingBubble.backgroundColor = AppClearClr;
    self.typingBubble.layer.cornerRadius = 16;
    self.typingBubble.translatesAutoresizingMaskIntoConstraints = NO;
    self.typingBubble.alpha = 0.0;

    NSMutableArray *dots = [NSMutableArray array];

    for (int i = 0; i < 3; i++) {
        UIView *dot = [[UIView alloc] init];
        dot.backgroundColor = [UIColor secondaryLabelColor];
        dot.layer.cornerRadius = 4;
        dot.translatesAutoresizingMaskIntoConstraints = NO;
        [self.typingBubble addSubview:dot];
        [dots addObject:dot];
    }

    self.typingDots = dots;
    [self addSubview:self.typingBubble];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.typingBubble.centerXAnchor constraintEqualToAnchor:self.centerXAnchor constant:0],
        [self.typingBubble.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-6],
        [self.typingBubble.widthAnchor constraintEqualToConstant:64],
        [self.typingBubble.heightAnchor constraintEqualToConstant:32]
    ]];
    
    
    UIView *d0 = self.typingDots[0];
    UIView *d1 = self.typingDots[1];
    UIView *d2 = self.typingDots[2];

    [NSLayoutConstraint activateConstraints:@[
        [d0.centerYAnchor constraintEqualToAnchor:self.typingBubble.centerYAnchor],
        [d1.centerYAnchor constraintEqualToAnchor:self.typingBubble.centerYAnchor],
        [d2.centerYAnchor constraintEqualToAnchor:self.typingBubble.centerYAnchor],

        [d0.leadingAnchor constraintEqualToAnchor:self.typingBubble.leadingAnchor constant:14],
        [d1.centerXAnchor constraintEqualToAnchor:self.typingBubble.centerXAnchor],
        [d2.trailingAnchor constraintEqualToAnchor:self.typingBubble.trailingAnchor constant:-14],

        [d0.widthAnchor constraintEqualToConstant:8],
        [d1.widthAnchor constraintEqualToConstant:8],
        [d2.widthAnchor constraintEqualToConstant:8],
        [d0.heightAnchor constraintEqualToConstant:8],
        [d1.heightAnchor constraintEqualToConstant:8],
        [d2.heightAnchor constraintEqualToConstant:8],
    ]];
}

- (void)startTypingAnimation
{
    if (!self.typingBubble) {
        [self setupTypingBubbleIfNeeded];
    }

    self.typingBubble.alpha = 1.0;

    for (NSInteger i = 0; i < self.typingDots.count; i++) {
        UIView *dot = self.typingDots[i];
        [dot.layer removeAllAnimations];

        [UIView animateWithDuration:0.6
                              delay:i * 0.15
                            options:UIViewAnimationOptionRepeat |
                                    UIViewAnimationOptionAutoreverse |
                                    UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            dot.transform = CGAffineTransformMakeTranslation(0, -4);
            dot.alpha = 0.4;
        } completion:nil];
    }
}

-(void)stopTypingAnimation
{
    [UIView animateWithDuration:0.2 animations:^{
        self.typingBubble.alpha = 0.0;
    } completion:^(BOOL finished) {
        for (UIView *dot in self.typingDots) {
            [dot.layer removeAllAnimations];
            dot.transform = CGAffineTransformIdentity;
            dot.alpha = 1.0;
        }
    }];
}

- (void)createPremiumBlurBackground
{
    self.blurView = [[UIView alloc] init];
    self.blurView.translatesAutoresizingMaskIntoConstraints = NO;
    self.blurView.backgroundColor = UIColor.clearColor;
    self.blurView.clipsToBounds = YES;
     if (@available(iOS 13.0, *)) {
        self.blurView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    [Styling addBlurToView:self.blurView
                 blurStyle:UIBlurEffectStyleExtraLight
              cornerRadius:PPCornerHero
                     alpha:0.85
          insertAtPosition:0];

    [self addSubview:self.blurView];

    [self.blurView pp_setShadowColor:AppShadowClr];
    self.blurView.layer.shadowOpacity = 0.12;
    self.blurView.layer.shadowRadius = 16;
    self.blurView.layer.shadowOffset = CGSizeMake(0, 4);
    self.blurView.layer.masksToBounds = NO;
}

-(void)layoutSubviews
{
    [super layoutSubviews];
  //  [Styling addLiquidGlassBorderToView:self.blurView cornerRadius:PPCornerHero];
}

#pragma mark - Actions

- (void)onDismissTapped
{
    UIViewController *vc = [self pp_parentViewController];
    if (!vc) return;

    [vc dismissViewControllerAnimated:YES completion:^{
        
    }];
}
@end
