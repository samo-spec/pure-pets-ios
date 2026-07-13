//
//  PPChatInputBarView.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 26/01/2026.
//

#import "PPChatInputBarView.h"
#import "PPChatsFunc.h"
#import "Styling.h"


 
static CGFloat const kLockThreshold   = 60.0;
static CGFloat const kCancelThreshold = 120.0;
static NSString * const kPPDidShowRecordHintKey = @"PPDidShowRecordHint";

static BOOL PPChatInputBarIsDark(UITraitCollection *traitCollection)
{
    if (@available(iOS 13.0, *)) {
        return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return NO;
}

static UIColor *PPChatInputBarTextColor(UITraitCollection *traitCollection)
{
    return PPChatInputBarIsDark(traitCollection)
        ? [UIColor colorWithWhite:1.0 alpha:0.94]
        : (AppPrimaryTextClr ?: UIColor.labelColor);
}

static UIColor *PPChatInputBarSecondaryTextColor(UITraitCollection *traitCollection)
{
    return PPChatInputBarIsDark(traitCollection)
        ? [UIColor colorWithWhite:1.0 alpha:0.54]
        : UIColor.secondaryLabelColor;
}

static UIColor *PPChatInputBarSurfaceColor(UITraitCollection *traitCollection)
{
    BOOL isDark = PPChatInputBarIsDark(traitCollection);
    return isDark
        ? [UIColor colorWithWhite:1.0 alpha:0.090]
        : [UIColor colorWithRed:0.984 green:0.977 blue:0.958 alpha:0.94];
}

static UIColor *PPChatInputBarControlSurfaceColor(UITraitCollection *traitCollection)
{
    BOOL isDark = PPChatInputBarIsDark(traitCollection);
    return isDark
        ? [UIColor colorWithWhite:1.0 alpha:0.10]
        : [UIColor.labelColor colorWithAlphaComponent:0.075];
}

static UIColor *PPChatInputBarBorderColor(UITraitCollection *traitCollection)
{
    BOOL isDark = PPChatInputBarIsDark(traitCollection);
    return isDark
        ? [UIColor colorWithWhite:1.0 alpha:0.12]
        : [UIColor.labelColor colorWithAlphaComponent:0.055];
}

static UIColor *PPChatInputBarReplySurfaceColor(UITraitCollection *traitCollection)
{
    BOOL isDark = PPChatInputBarIsDark(traitCollection);
    return isDark
        ? [UIColor colorWithWhite:1.0 alpha:0.13]
    : [AppBackgroundClrLigter colorWithAlphaComponent:0.92];
}

static UIColor *PPChatInputBarReplyBorderColor(UITraitCollection *traitCollection)
{
    BOOL isDark = PPChatInputBarIsDark(traitCollection);
    return [UIColor.whiteColor colorWithAlphaComponent:(isDark ? 0.34 : 0.92)];
}

static UIColor *PPChatInputBarReplySecondaryTextColor(UITraitCollection *traitCollection)
{
    BOOL isDark = PPChatInputBarIsDark(traitCollection);
    return isDark
        ? [UIColor colorWithWhite:1.0 alpha:0.68]
        : [UIColor colorWithWhite:0.0 alpha:0.58];
}

static UIColor *PPChatInputBarControlTintColor(UITraitCollection *traitCollection)
{
    return PPChatInputBarIsDark(traitCollection)
        ? [UIColor colorWithWhite:1.0 alpha:0.88]
    : ([AppPrimaryClrDarker colorWithAlphaComponent:0.76] ?: UIColor.labelColor);
}

static UIColor *PPChatInputBarAccentColor(void)
{
    return [PPChatsFunc chatNeutralAccentColor];
}

static UIViewController *PPChatInputBarResolvedPresenter(UIView *view, UIViewController *preferredPresenter)
{
    UIViewController *presenter = preferredPresenter;
    if (presenter.isViewLoaded && presenter.view.window) {
        return presenter;
    }

    UIResponder *responder = view;
    while (responder) {
        responder = responder.nextResponder;
        if ([responder isKindOfClass:UIViewController.class]) {
            UIViewController *candidate = (UIViewController *)responder;
            if (candidate.isViewLoaded && candidate.view.window) {
                return candidate;
            }
            presenter = candidate;
        }
    }

    return presenter;
}

@interface PPChatInputBarView () <UITextViewDelegate,UIGestureRecognizerDelegate,PPRecordingBarViewDelegate>

@property (nonatomic, strong) UITextView *textView;
//@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) UIButton *actionsButton;
@property (nonatomic, strong) UIButton *mediaButton;
 
@property (nonatomic, strong) UIPanGestureRecognizer *panGesture;
@property (nonatomic, strong) ZMJTipView *tipView;
@property (nonatomic, assign) BOOL isRecording;
@property (nonatomic, assign) BOOL isLocked;
@property (nonatomic, assign) CGFloat currentTextHeight;
@property (nonatomic, strong) UILabel *placeholderLabel;
@property (nonatomic, assign) BOOL didShowRecordHint;
@property (nonatomic, strong) UIView *contentContainer;
@property (nonatomic, strong) UIStackView *stack;
@property (nonatomic, assign) BOOL didFinishOrCancel;
@property (nonatomic, assign) BOOL didCancelRecording;
@property (nonatomic, assign) BOOL recordingSessionEnded;
@property (nonatomic, strong) NSLayoutConstraint *textViewHeightConstraint;
@property (nonatomic, strong) UIButton *textBackgroundView;
@property (nonatomic, strong) UIControl *replyPreviewView;
@property (nonatomic, strong) UIView *replyAccentView;
@property (nonatomic, strong) UIImageView *replyIconView;
@property (nonatomic, strong) UILabel *replyTitleLabel;
@property (nonatomic, strong) UILabel *replySubtitleLabel;
@property (nonatomic, strong) UIButton *replyCancelButton;
@property (nonatomic, strong) NSLayoutConstraint *replyPreviewHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *stackTopConstraint;
- (void)pp_applyCurrentTheme;
- (void)pp_applyIconButtonTheme:(UIButton *)button systemName:(NSString *)systemName active:(BOOL)active;
- (void)pp_buildReplyPreview;
- (void)pp_setReplyPreviewVisible:(BOOL)visible animated:(BOOL)animated;
- (void)pp_iconTouchDown:(UIButton *)sender;
- (void)pp_iconTouchUp:(UIButton *)sender;
@end

@implementation PPChatInputBarView

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self buildUI];
        [self installGestures];
    }
    return self;
}

#pragma mark - UI

- (void)buildUI {
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.backgroundColor = AppClearClr;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.contentContainer =
    [UIView new];

    self.backgroundColor = AppClearClr;

    self.contentContainer.layer.cornerRadius = 0;

    self.contentContainer.translatesAutoresizingMaskIntoConstraints = NO;
    
    
     //self.contentContainer.clipsToBounds = YES;
    [self addSubview:self.contentContainer];
    [NSLayoutConstraint activateConstraints:@[
        [self.contentContainer.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.contentContainer.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.contentContainer.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.contentContainer.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    ]];
    
    
    /*
     self.mediaButton = [PPButtonHelper buttonWithSystemName:@"paperclip"  target:self action:@selector(onAttachTapped)];
     self.actionsButton = [PPButtonHelper buttonWithSystemName:@"mic.fill"  target:self action:@selector(actionButtonTapped)];
     */
    
    // Attach
    self.mediaButton = [self iconButton:@"paperclip"];
    [self.mediaButton addTarget:self
                          action:@selector(onAttachTapped)
                forControlEvents:UIControlEventTouchUpInside];

    
    // Text background container
    self.textBackgroundView = [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleFixed configType:PPButtonConfigrationGlass];
    self.textBackgroundView.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = self.textBackgroundView.configuration ?: [UIButtonConfiguration plainButtonConfiguration];
        config.background.cornerRadius = 16;
        config.background.backgroundColor = UIColor.clearColor;
        config.baseBackgroundColor = UIColor.clearColor;
        self.textBackgroundView.configuration = config;
    }
    
    
   //self.textBackgroundView.layer.cornerRadius = 12;
    //self.textBackgroundView.clipsToBounds = YES;
    
    
    // Text view
    self.textView = [[UITextView alloc] init];
    self.textView.font = [GM MidFontWithSize:16];
    self.textView.delegate = self;
    self.textView.backgroundColor = UIColor.clearColor;
    self.textView.textColor = PPChatInputBarTextColor(self.traitCollection);
    self.textView.tintColor = PPChatInputBarAccentColor();
    self.textView.keyboardAppearance = PPChatInputBarIsDark(self.traitCollection) ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
    self.textView.layer.cornerRadius = 0;
    self.textView.translatesAutoresizingMaskIntoConstraints = NO;
    // Normalize text sizing and constraints
    self.textView.scrollEnabled = NO;
    self.textView.textContainer.lineFragmentPadding = 0;
    self.textView.textContainerInset = UIEdgeInsetsMake(8, 4, 8, 4);
    // Ensure textView can grow vertically
    [self.textView setContentHuggingPriority:UILayoutPriorityDefaultLow
                                     forAxis:UILayoutConstraintAxisVertical];
    [self.textView setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                   forAxis:UILayoutConstraintAxisVertical];
    // Add explicit height constraint
    
    // Ensure textView can grow vertically
    [self.textBackgroundView setContentHuggingPriority:UILayoutPriorityDefaultLow
                                     forAxis:UILayoutConstraintAxisVertical];
    [self.textBackgroundView setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                   forAxis:UILayoutConstraintAxisVertical];
 
    self.textView.alwaysBounceVertical = YES;
    self.textView.showsVerticalScrollIndicator = NO;
 
    
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.textView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.textView.textAlignment = Language.alignmentForCurrentLanguage;
    
    [self.textBackgroundView addSubview:self.textView];
    self.textView.scrollEnabled = NO;
   //  [self.textView setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                     //  forAxis:UILayoutConstraintAxisVertical];
    // Placeholder label
    self.placeholderLabel = [[UILabel alloc] init];
    self.placeholderLabel.text = kLang(@"Message…");
    self.placeholderLabel.font = self.textView.font;
    self.placeholderLabel.textColor = PPChatInputBarSecondaryTextColor(self.traitCollection);
    self.placeholderLabel.backgroundColor = UIColor.clearColor;

    self.placeholderLabel.userInteractionEnabled = NO;
    self.placeholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.placeholderLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.textView addSubview:self.placeholderLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.placeholderLabel.centerXAnchor constraintEqualToAnchor:self.textView.centerXAnchor constant:0],
        [self.placeholderLabel.centerYAnchor constraintEqualToAnchor:self.textView.centerYAnchor],
        [self.placeholderLabel.heightAnchor constraintEqualToAnchor:self.textView.heightAnchor constant:-0],
        [self.placeholderLabel.widthAnchor constraintEqualToAnchor:self.textView.widthAnchor constant:-32],
    ]];

    // Action container
    self.textViewHeightConstraint =
        [self.textBackgroundView.heightAnchor constraintEqualToConstant:44.0];
    self.textViewHeightConstraint.priority = UILayoutPriorityRequired;
    self.textViewHeightConstraint.active = YES;
    
    
    self.actionsButton = [self iconButton:@"mic.fill"];
    
    UILongPressGestureRecognizer *longPress =
    [[UILongPressGestureRecognizer alloc]
     initWithTarget:self
             action:@selector(handleActionLongPress:)];

    longPress.minimumPressDuration = 0.15;
    [self.actionsButton addGestureRecognizer:longPress];
     
    [self.actionsButton addTarget:self
                          action:@selector(actionButtonTapped)
                forControlEvents:UIControlEventTouchUpInside];

    [self pp_buildReplyPreview];

    self.stack =
    [[UIStackView alloc] initWithArrangedSubviews:@[
        self.mediaButton,
        self.textBackgroundView,
        self.actionsButton
    ]];

    self.stack.axis = UILayoutConstraintAxisHorizontal;
    self.stack.spacing = 8;
    self.stack.alignment = UIStackViewAlignmentBottom;
    self.stack.translatesAutoresizingMaskIntoConstraints = NO;

    [self.contentContainer addSubview:self.stack];
    self.stackTopConstraint =
        [self.stack.topAnchor constraintEqualToAnchor:self.replyPreviewView.bottomAnchor constant:0.0];
    
    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.stack.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:12],
        [self.stack.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-12],
        self.stackTopConstraint,
        [self.stack.bottomAnchor constraintEqualToAnchor:self.contentContainer.bottomAnchor constant:-12],
        [self.actionsButton.widthAnchor constraintEqualToConstant:44.0],
        [self.actionsButton.heightAnchor constraintEqualToConstant:44.0],
        
        [self.textBackgroundView.leadingAnchor constraintEqualToAnchor:self.textView.leadingAnchor constant:0],
        [self.textBackgroundView.trailingAnchor constraintEqualToAnchor:self.textView.trailingAnchor constant:-0],
        [self.textBackgroundView.topAnchor constraintEqualToAnchor:self.textView.topAnchor constant:0],
        [self.stack.bottomAnchor constraintEqualToAnchor:self.textView.bottomAnchor constant:-0],
    ]];
 
   
    
    self.lockPill = [[PPRecordingLockPillView alloc] init];
    [self.contentContainer addSubview:self.lockPill];

    [NSLayoutConstraint activateConstraints:@[
        [self.lockPill.bottomAnchor constraintEqualToAnchor:self.topAnchor constant:-30],
        [self.lockPill.centerXAnchor constraintEqualToAnchor:self.actionsButton.centerXAnchor],
    ]];
    
    
    BOOL hasText = self.textView.text.length > 0;
     self.placeholderLabel.hidden = hasText;
    
     
    self.recordingBar = [[PPRecordingBarView alloc] init];
    self.recordingBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.recordingBar.userInteractionEnabled = YES;
    self.recordingBar.delegate = self;
    [self.contentContainer addSubview:self.recordingBar];
    [self.contentContainer bringSubviewToFront:self.recordingBar];

    //[self.recordingBar.widthAnchor constraintEqualToAnchor:self.contentContainer.widthAnchor].active = YES;
    //[self.recordingBar.heightAnchor constraintEqualToAnchor:self.contentContainer.heightAnchor].active = YES;
   
    
    [NSLayoutConstraint activateConstraints:@[
	        [self.recordingBar.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:0],
	        [self.recordingBar.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-0],
	        [self.recordingBar.heightAnchor constraintEqualToConstant:56],
	        //[self.recordingBar.bottomAnchor constraintEqualToAnchor:self.contentContainer.bottomAnchor constant:-0],
	        [self.recordingBar.centerYAnchor constraintEqualToAnchor:self.contentContainer.centerYAnchor],
     
    ]];
   
    self.clipsToBounds = NO;
    self.contentContainer.clipsToBounds = NO;   // ✅ VERY IMPORTANT
    //[self.recordingBar setRecordingState:PPRecordingBarStateRecording animated:NO];
    self.textView.clipsToBounds = YES;
    self.textView.layer.cornerRadius = 12;
    [self pp_applyCurrentTheme];

}
-(void)layoutSubviews
{
    [super layoutSubviews];
    self.clipsToBounds = NO;
    self.layer.masksToBounds = NO;
    
    self.contentContainer.clipsToBounds = NO;
    self.contentContainer.layer.masksToBounds = NO;

    if (!CGRectIsEmpty(self.textBackgroundView.bounds)) {
        self.textBackgroundView.layer.shadowPath =
            [UIBezierPath bezierPathWithRoundedRect:self.textBackgroundView.bounds
                                      cornerRadius:16.0].CGPath;
    }

    if (!self.replyPreviewView.hidden && !CGRectIsEmpty(self.replyPreviewView.bounds)) {
        [Styling addLiquidGlassBorderToView:self.replyPreviewView
                               cornerRadius:16.0
                                      color:PPChatInputBarReplyBorderColor(self.traitCollection)];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];

    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_applyCurrentTheme];
        }
    }
}

- (void)pp_buildReplyPreview
{
    self.replyPreviewView = [[UIControl alloc] init];
    self.replyPreviewView.translatesAutoresizingMaskIntoConstraints = NO;
    self.replyPreviewView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.replyPreviewView.alpha = 0.0;
    self.replyPreviewView.hidden = YES;
    self.replyPreviewView.clipsToBounds = NO;
    self.replyPreviewView.layer.masksToBounds = NO;
    self.replyPreviewView.layer.cornerRadius = 16.0;
    self.replyPreviewView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    if (@available(iOS 13.0, *)) {
        self.replyPreviewView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.contentContainer addSubview:self.replyPreviewView];

    self.replyAccentView = [[UIView alloc] init];
    self.replyAccentView.translatesAutoresizingMaskIntoConstraints = NO;
    self.replyAccentView.layer.cornerRadius = 2.0;
    [self.replyPreviewView addSubview:self.replyAccentView];

    UIImageSymbolConfiguration *iconConfig =
        [UIImageSymbolConfiguration configurationWithPointSize:15.0
                                                        weight:UIImageSymbolWeightSemibold
                                                         scale:UIImageSymbolScaleMedium];
    self.replyIconView = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:@"arrowshape.turn.up.left.fill"] imageByApplyingSymbolConfiguration:iconConfig]];
    self.replyIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.replyIconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.replyPreviewView addSubview:self.replyIconView];

    self.replyTitleLabel = [[UILabel alloc] init];
    self.replyTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.replyTitleLabel.font = [GM boldFontWithSize:12.0];
    self.replyTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.replyTitleLabel.numberOfLines = 1;
    [self.replyPreviewView addSubview:self.replyTitleLabel];

    self.replySubtitleLabel = [[UILabel alloc] init];
    self.replySubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.replySubtitleLabel.font = [GM MidFontWithSize:13.0];
    self.replySubtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.replySubtitleLabel.numberOfLines = 1;
    self.replySubtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.replyPreviewView addSubview:self.replySubtitleLabel];

    self.replyCancelButton = [self iconButton:@"xmark"];
    self.replyCancelButton.accessibilityLabel = kLang(@"chat_reply_cancel");
    [self.replyCancelButton addTarget:self
                               action:@selector(pp_replyCancelTapped)
                     forControlEvents:UIControlEventTouchUpInside];
    [self.replyPreviewView addSubview:self.replyCancelButton];

    self.replyPreviewHeightConstraint =
        [self.replyPreviewView.heightAnchor constraintEqualToConstant:0.0];

    [NSLayoutConstraint activateConstraints:@[
        [self.replyPreviewView.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:12.0],
        [self.replyPreviewView.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-12.0],
        [self.replyPreviewView.topAnchor constraintEqualToAnchor:self.contentContainer.topAnchor constant:12.0],
        self.replyPreviewHeightConstraint,

        [self.replyAccentView.leadingAnchor constraintEqualToAnchor:self.replyPreviewView.leadingAnchor constant:12.0],
        [self.replyAccentView.topAnchor constraintEqualToAnchor:self.replyPreviewView.topAnchor constant:12.0],
        [self.replyAccentView.bottomAnchor constraintEqualToAnchor:self.replyPreviewView.bottomAnchor constant:-12.0],
        [self.replyAccentView.widthAnchor constraintEqualToConstant:4.0],

        [self.replyIconView.leadingAnchor constraintEqualToAnchor:self.replyAccentView.trailingAnchor constant:10.0],
        [self.replyIconView.centerYAnchor constraintEqualToAnchor:self.replyPreviewView.centerYAnchor],
        [self.replyIconView.widthAnchor constraintEqualToConstant:18.0],
        [self.replyIconView.heightAnchor constraintEqualToConstant:18.0],

        [self.replyCancelButton.trailingAnchor constraintEqualToAnchor:self.replyPreviewView.trailingAnchor constant:-8.0],
        [self.replyCancelButton.centerYAnchor constraintEqualToAnchor:self.replyPreviewView.centerYAnchor],

        [self.replyTitleLabel.leadingAnchor constraintEqualToAnchor:self.replyIconView.trailingAnchor constant:10.0],
        [self.replyTitleLabel.trailingAnchor constraintEqualToAnchor:self.replyCancelButton.leadingAnchor constant:-8.0],
        [self.replyTitleLabel.topAnchor constraintEqualToAnchor:self.replyPreviewView.topAnchor constant:9.0],

        [self.replySubtitleLabel.leadingAnchor constraintEqualToAnchor:self.replyTitleLabel.leadingAnchor],
        [self.replySubtitleLabel.trailingAnchor constraintEqualToAnchor:self.replyTitleLabel.trailingAnchor],
        [self.replySubtitleLabel.topAnchor constraintEqualToAnchor:self.replyTitleLabel.bottomAnchor constant:1.0],
    ]];
}

- (void)pp_applyCurrentTheme
{
    BOOL isDark = PPChatInputBarIsDark(self.traitCollection);
    UIColor *surfaceColor = PPChatInputBarSurfaceColor(self.traitCollection);
    UIColor *borderColor = PPChatInputBarBorderColor(self.traitCollection);

    self.backgroundColor = UIColor.clearColor;
    self.contentContainer.backgroundColor = UIColor.clearColor;

    self.textView.textColor = PPChatInputBarTextColor(self.traitCollection);
    self.textView.tintColor = PPChatInputBarAccentColor();
    self.textView.keyboardAppearance = isDark ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;

    self.placeholderLabel.textColor = PPChatInputBarSecondaryTextColor(self.traitCollection);
    self.placeholderLabel.backgroundColor = UIColor.clearColor;

    self.textBackgroundView.backgroundColor = surfaceColor;
    self.textBackgroundView.tintColor = self.textView.tintColor;
    self.textBackgroundView.clipsToBounds = NO;
    self.textBackgroundView.layer.masksToBounds = NO;
    self.textBackgroundView.layer.cornerRadius = 16.0;
    self.textBackgroundView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.textBackgroundView.layer.borderColor = borderColor.CGColor;
    self.textBackgroundView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.textBackgroundView.layer.shadowOpacity = isDark ? 0.18 : 0.06;
    self.textBackgroundView.layer.shadowRadius = isDark ? 14.0 : 10.0;
    self.textBackgroundView.layer.shadowOffset = CGSizeMake(0.0, isDark ? 8.0 : 5.0);
    if (@available(iOS 13.0, *)) {
        self.textBackgroundView.layer.cornerCurve = kCACornerCurveContinuous;
        self.textView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = self.textBackgroundView.configuration ?: [UIButtonConfiguration plainButtonConfiguration];
        config.background.cornerRadius = 16.0;
        config.background.backgroundColor = surfaceColor;
        config.baseBackgroundColor = surfaceColor;
        config.baseForegroundColor = self.textView.tintColor;
        self.textBackgroundView.configuration = config;
    }

    [self pp_applyIconButtonTheme:self.mediaButton systemName:@"paperclip" active:NO];
    NSString *actionName = (self.actionMode == PPActionButtonModeSend) ? @"arrow.up" : @"mic.fill";
    [self pp_applyIconButtonTheme:self.actionsButton
                       systemName:actionName
                           active:(self.actionMode == PPActionButtonModeSend)];

    UIColor *replyBorderColor = PPChatInputBarReplyBorderColor(self.traitCollection);
    UIColor *replyAccentColor =
        isDark ? [UIColor.whiteColor colorWithAlphaComponent:0.88] : PPChatInputBarAccentColor();

    self.replyPreviewView.backgroundColor = PPChatInputBarReplySurfaceColor(self.traitCollection);
    self.replyPreviewView.layer.borderColor = replyBorderColor.CGColor;
    self.replyPreviewView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.replyPreviewView.layer.shadowOpacity = isDark ? 0.18 : 0.08;
    self.replyPreviewView.layer.shadowRadius = isDark ? 14.0 : 12.0;
    self.replyPreviewView.layer.shadowOffset = CGSizeMake(0.0, 6.0);
    self.replyAccentView.backgroundColor = replyAccentColor;
    self.replyIconView.tintColor = replyAccentColor;
    self.replyTitleLabel.textColor = PPChatInputBarTextColor(self.traitCollection);
    self.replySubtitleLabel.textColor = PPChatInputBarReplySecondaryTextColor(self.traitCollection);
    [self pp_applyIconButtonTheme:self.replyCancelButton systemName:@"xmark" active:NO];

    if (!self.replyPreviewView.hidden && !CGRectIsEmpty(self.replyPreviewView.bounds)) {
        [Styling addLiquidGlassBorderToView:self.replyPreviewView
                               cornerRadius:16.0
                                      color:replyBorderColor];
    }
}

- (void)pp_applyIconButtonTheme:(UIButton *)button systemName:(NSString *)systemName active:(BOOL)active
{
    if (!button) return;

    BOOL isDark = PPChatInputBarIsDark(self.traitCollection);
    UIColor *accentColor = PPChatInputBarAccentColor();
    UIColor *foregroundColor = active ? accentColor : PPChatInputBarControlTintColor(self.traitCollection);
    UIColor *surfaceColor = active
        ? [accentColor colorWithAlphaComponent:(isDark ? 0.22 : 0.13)]
        : PPChatInputBarControlSurfaceColor(self.traitCollection);
    UIColor *borderColor = active
        ? [accentColor colorWithAlphaComponent:(isDark ? 0.34 : 0.20)]
        : PPChatInputBarBorderColor(self.traitCollection);

    UIImageSymbolConfiguration *symbolConfig =
        [UIImageSymbolConfiguration configurationWithPointSize:(active ? 17.0 : 18.0)
                                                        weight:UIImageSymbolWeightMedium
                                                         scale:UIImageSymbolScaleMedium];
    UIImage *image = [[UIImage systemImageNamed:systemName] imageByApplyingSymbolConfiguration:symbolConfig];

    BOOL usesSystemGlass = NO;
    if (@available(iOS 26.0, *)) {
        usesSystemGlass = YES;
    }

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = nil;
        if (@available(iOS 26.0, *)) {
            config = [UIButtonConfiguration glassButtonConfiguration];
        } else {
            config = [UIButtonConfiguration plainButtonConfiguration];
            config.background.backgroundColor = surfaceColor;
            config.baseBackgroundColor = surfaceColor;
            config.background.cornerRadius = 22.0;
        }
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        config.contentInsets = NSDirectionalEdgeInsetsMake(8.0, 8.0, 8.0, 8.0);
        config.image = image;
        config.baseForegroundColor = foregroundColor;
        button.configuration = config;
    } else {
        [button setImage:image forState:UIControlStateNormal];
    }

    button.tintColor = foregroundColor;
    button.imageView.tintColor = foregroundColor;
    button.backgroundColor = usesSystemGlass ? UIColor.clearColor : surfaceColor;
    button.clipsToBounds = YES;
    button.layer.cornerRadius = 22.0;
    button.layer.borderWidth = usesSystemGlass ? 0.0 : (1.0 / UIScreen.mainScreen.scale);
    button.layer.borderColor = borderColor.CGColor;
    button.layer.shadowColor = UIColor.blackColor.CGColor;
    button.layer.shadowOpacity = (!usesSystemGlass && isDark) ? 0.16 : 0.0;
    button.layer.shadowRadius = (!usesSystemGlass && isDark) ? 8.0 : 0.0;
    button.layer.shadowOffset = CGSizeMake(0.0, 4.0);
}

- (void)setMicVisible:(BOOL)visible animated:(BOOL)animated {
    void (^changes)(void) = ^{
        self.actionsButton.alpha = visible ? 1.0 : 0.0;
        self.actionsButton.userInteractionEnabled = visible;
    };

    if (animated) {
        [UIView animateWithDuration:0.18
                              delay:0
                            options:UIViewAnimationOptionBeginFromCurrentState
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }
}


#pragma mark - PPRecordingBarViewDelegate

- (void)recordingBarDidTapPlayFromLocked
{
    NSLog(@"🔒▶️ LOCK → PREVIEW triggered");

    if (!self.isRecording) return;
    if (self.didFinishOrCancel) return;
    
    // 1️⃣ HARD STOP recording UI + state
     self.panGesture.enabled = NO;
    
    self.isRecording = YES;
    self.isLocked = YES;
    self.didFinishOrCancel = NO;
    self.recordingSessionEnded = NO;

    // 2️⃣ Freeze waveform + duration
    [self.recordingBar prepareForPreview];

    // 3️⃣ Hide lock UI
    [self.lockPill setState:PPRecordingLockPillStateHidden animated:YES];

    // 4️⃣ Tell controller: FINISH RECORDING (NO SEND)
    if ([self.delegate respondsToSelector:@selector(recordingBarDidTapPlayFromLocked)]) {
        [self.delegate recordingBarDidTapPlayFromLocked];
    }
}

- (void)recordingBarDidTogglePlayback
{
    // 🔓 Re-enable Send & Cancel after preview play
    self.didFinishOrCancel = NO;
    self.recordingSessionEnded = NO;
    self.isRecording = YES;

    if ([self.delegate respondsToSelector:
         @selector(recordingBarDidTogglePlayback)]) {
        [self.delegate recordingBarDidTogglePlayback];
    }
}
- (void)stopPreviewPlaybackIfNeeded
{
    // Tell controller to stop preview audio immediately
    if ([self.delegate respondsToSelector:
         @selector(inputBarDidStopRecordingPreview:)]) {
        [self.delegate inputBarDidStopRecordingPreview:self];
    }

    // Reset preview-related state
    self.didFinishOrCancel = NO;
    self.recordingSessionEnded = NO;
}
- (void)recordingBarDidTapSend {
    [self stopPreviewPlaybackIfNeeded];

    if (!self.isRecording) return;
    if (self.didFinishOrCancel) return;

    NSLog(@"📤 [REC] SEND tapped");

    self.didFinishOrCancel = YES;
    self.isLocked = YES;

    // Freeze waveform + show preview state
    [self.recordingBar prepareForPreview];

    [self.lockPill setState:PPRecordingLockPillStateHidden animated:YES];
    
    // End UI immediately
    [self recordingEnd];

    // Notify controller to upload/send
    if ([self.delegate respondsToSelector:
         @selector(inputBar:didFinishRecordingWithURL:duration:locked:)]) {

        [self.delegate inputBar:self
        didFinishRecordingWithURL:self.currentRecordingURL
                         duration:self.currentRecordingDuration
                           locked:YES];
    }
}

- (void)recordingBarDidTapPlayPause {
    NSLog(@"▶︎⏸ [REC] Preview play/pause");
 
    if ([self.delegate respondsToSelector:
         @selector(inputBarDidToggleRecordingPreview:)]) {
        [self.delegate inputBarDidToggleRecordingPreview:self];
    }
}

- (void)recordingBarDidTapCancel {
    [self stopPreviewPlaybackIfNeeded];
    if (!self.isRecording) return;
    if (self.didFinishOrCancel) return;

    NSLog(@"🗑 [REC] DELETE tapped");

    self.didFinishOrCancel = YES;
    self.didCancelRecording = YES;
    [self.lockPill setState:PPRecordingLockPillStateHidden animated:YES];
    [self cancelRecording];
}
- (void)handleActionLongPress:(UILongPressGestureRecognizer *)gr {

    if (self.actionMode != PPActionButtonModeRecord) return;

    switch (gr.state) {

        case UIGestureRecognizerStateBegan: {
            NSLog(@"🎙️ LP BEGAN → start recording");

            [self recordingStart];

            if ([self.delegate respondsToSelector:@selector(inputBarDidStartRecording:)]) {
                [self.delegate inputBarDidStartRecording:self];
            }
            break;
        }

        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {

            NSLog(@"🎙️ LP ENDED");

            // 🔴 THIS IS THE MISSING PIECE
            if (!self.isRecording) return;
            if (self.didFinishOrCancel) return;
            if (self.isLocked) {
                NSLog(@"🔒 Locked → release ignored");
                return;
            }

            NSLog(@"✅ LP RELEASE → finish recording");
            self.didFinishOrCancel = YES;
            [self finishRecording];
            break;
        }

        default:
            break;
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {

    NSLog(@"🟡 [PAN] state=%ld recording=%d locked=%d cancelled=%d",
          (long)pan.state,
          self.isRecording,
          self.isLocked,
          self.didCancelRecording);

   /*
    if (self.isLocked) {
        NSLog(@"🔒 [PAN] Ignored — locked owns lifecycle");
        return;
    }
    */

    if (!self.isRecording) {
        NSLog(@"⛔️ [PAN] Ignored — not recording");
        return;
    }

    CGPoint t = [pan translationInView:self.contentContainer];;
    CGFloat dx = t.x;
    CGFloat dy = -t.y; // up = positive

    NSLog(@"➡️ [PAN] dx=%.1f dy=%.1f", dx, dy);

    BOOL isRTL = Language.isRTL;

    // Logical left swipe (cancel)
    CGFloat logicalDX = isRTL ? dx : -dx;
    
    
    CGFloat progress = MIN(fabs(dx) / kCancelThreshold, 1.0);
    self.recordingBar.hintLabel.alpha = 1.0 - progress;

    self.recordingBar.transform =
        CGAffineTransformMakeTranslation(dx * 0.15, 0);

    switch (pan.state) {

        case UIGestureRecognizerStateChanged: {

            NSLog(@"🟠 [PAN] CHANGED");

            // 🔒 LOCK (UP)
            if (!self.isLocked && dy > kLockThreshold) {
                NSLog(@"🔒 [PAN] LOCK triggered (dy=%.1f)", dy);
                self.isLocked = YES;
                [self.recordingBar setRecordingState:PPRecordingBarStateLocked animated:YES];
                [self.lockPill setState:PPRecordingLockPillStateLocked animated:YES];
                [self setMicVisible:NO animated:YES];
                self.recordingSessionEnded = NO;
                // IMPORTANT
                self.panGesture.enabled = NO;
                return;
            }

            if (!self.isLocked && logicalDX > kCancelThreshold) {
                NSLog(@"❌ [PAN] CANCEL triggered (logicalDX=%.1f)", logicalDX);
                self.didCancelRecording = YES;
                    self.didFinishOrCancel = YES;
                    [self cancelRecording];
                [self setMicVisible:NO animated:NO];
                return;
            }
            break;
        }

        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {

            NSLog(@"🔵 [PAN] END");

            if (self.didFinishOrCancel) {
                NSLog(@"🛑 [PAN] Already resolved");
                return;
            }

            if (self.didCancelRecording) {
                NSLog(@"🛑 [PAN] Was cancelled");
                return;
            }

            if (self.isLocked) {
                NSLog(@"🔒 [PAN] Locked → ignore END");
                return;
            }

            NSLog(@"✅ [PAN] FINISH recording (release)");
            self.didFinishOrCancel = YES;
            [self finishRecording];
            break;
        }

        default:
            NSLog(@"⚪️ [PAN] state=%ld ignored", (long)pan.state);
            break;
    }
}

/*
 
 
 - (void)recordingBarDidTapSend {

     if (!self.isRecording || self.didFinishOrCancel) return;

     NSLog(@"📤 [REC] SEND tapped");

     self.didFinishOrCancel = YES;
     self.isLocked = YES;

     [self.recordingBar prepareForPreview];
     [self recordingEnd];

     if ([self.delegate respondsToSelector:
          @selector(inputBar:didFinishRecordingWithURL:duration:locked:)]) {

         [self.delegate inputBar:self
         didFinishRecordingWithURL:nil
                          duration:0
                            locked:YES];
     }
 }

 - (void)recordingBarDidTapCancel {

     if (!self.isRecording || self.didFinishOrCancel) return;

     NSLog(@"🗑 [REC] DELETE tapped");

     self.didFinishOrCancel = YES;
     self.didCancelRecording = YES;

     [self cancelRecording];
 }
 */


#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {

    // Allow long-press + pan together for recording gestures
    if ([gestureRecognizer isKindOfClass:UILongPressGestureRecognizer.class] &&
        [otherGestureRecognizer isKindOfClass:UIPanGestureRecognizer.class]) {
        return YES;
    }

    if ([gestureRecognizer isKindOfClass:UIPanGestureRecognizer.class] &&
        [otherGestureRecognizer isKindOfClass:UILongPressGestureRecognizer.class]) {
        return YES;
    }

    return NO;
}






- (void)actionButtonTapped {

    if (self.actionMode == PPActionButtonModeSend) {
        [self sendText];
        return;
    }

    // 🎙 RECORD MODE + SINGLE TAP
    if (self.actionMode == PPActionButtonModeRecord) {

        if ([[NSUserDefaults standardUserDefaults] boolForKey:kPPDidShowRecordHintKey]) {
            //return;
        }

        [[NSUserDefaults standardUserDefaults] setBool:YES
                                                forKey:kPPDidShowRecordHintKey];
        [[NSUserDefaults standardUserDefaults] synchronize];

        [self showRecordHintTooltipOnView:self.actionsButton
                                      text:kLang(@"Press and hold to record")];
        
    }
}

#pragma mark - Tooltip Helper

- (void)showRecordHintTooltipOnView:(UIView *)targetView
                               text:(NSString *)text {

    if (!targetView) return;

    // 1️⃣ Dismiss existing tooltip (if any)
    if (self.tipView) {
        [self.tipView dismissWithCompletion:^{}];
        self.tipView = nil;
    }

    // 2️⃣ Sanitize text
    NSString *message = text;
    if (![message isKindOfClass:NSString.class] || message.length == 0) {
        message = @" "; // minimal fallback (prevents layout crash)
    }

    // 3️⃣ Preferences (modern, compact, WhatsApp-like)
    ZMJPreferences *preferences = [ZMJPreferences new];

    BOOL isDark = PPChatInputBarIsDark(self.traitCollection);
    preferences.drawing.backgroundColor = isDark
        ? [UIColor colorWithWhite:0.10 alpha:0.96]
        : [PPChatInputBarAccentColor() colorWithAlphaComponent:0.92];
    preferences.drawing.foregroundColor = isDark
        ? UIColor.whiteColor
        : UIColor.whiteColor;
    preferences.drawing.textAlignment = NSTextAlignmentCenter;
    preferences.drawing.font = [GM MidFontWithSize:15];
    preferences.drawing.cornerRadius = 14;
    preferences.drawing.arrowPosition = ZMJArrowPosition_bottom;
    preferences.drawing.shadowColor =
    [AppShadowClr colorWithAlphaComponent:0.25];

    preferences.animating.showInitialAlpha = 0;
    preferences.animating.showDuration = 0.38;
    preferences.animating.dismissDuration = 0.28;

    // 4️⃣ Create tooltip
    self.tipView =
        [[ZMJTipView alloc] initWithText:message
                             preferences:preferences
                                delegate:nil];

    // IMPORTANT:
    // Use contentContainer instead of self.view (safer inside input bar)
    UIView *hostView = self.contentContainer ?: self;

    [self.tipView showAnimated:YES
                       forView:targetView
               withinSuperview:hostView];

    // 5️⃣ Auto dismiss (short, non-annoying)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(1.8 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (self.tipView) {
            [self.tipView dismissWithCompletion:^{}];
            self.tipView = nil;
        }
    });

    // 6️⃣ Light haptic
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *haptic =
            [[UIImpactFeedbackGenerator alloc]
             initWithStyle:UIImpactFeedbackStyleLight];
        [haptic prepare];
        [haptic impactOccurred];
    }

    NSLog(@"💬 [RecordHint] Tooltip shown → %@", message);
}


- (void)updateActionMode {
    BOOL hasText = self.textView.text.length > 0;
    self.actionMode = hasText
        ? PPActionButtonModeSend
        : PPActionButtonModeRecord;

    [self updateActionButtonUIAnimated:YES];
}

- (void)updateActionButtonUIAnimated:(BOOL)animated {
    BOOL isSendMode = (self.actionMode == PPActionButtonModeSend);
    NSString *systemName = isSendMode ? @"arrow.up" : @"mic.fill";
    UIImage *image =
        [UIImage systemImageNamed:systemName];

    void (^changes)(void) = ^{
        [self pp_applyIconButtonTheme:self.actionsButton systemName:systemName active:isSendMode];

        if (@available(iOS 18.0, *)) {
            [self.actionsButton.imageView setSymbolImage:image withContentTransition:[NSSymbolReplaceContentTransition magicTransitionWithFallback: NSSymbolReplaceContentTransition.replaceDownUpTransition.transitionWithByLayer] options: [NSSymbolEffectOptions optionsWithRepeatBehavior:[NSSymbolEffectOptionsRepeatBehavior behaviorPeriodic]]];
        }
    };

    
    if (animated) {
        [UIView transitionWithView:self.actionsButton
                          duration:0.18
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:changes
                        completion:nil];
    } else {
        changes();
    }
}
 
- (UIButton *)iconButton:(NSString *)systemName {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setImage:[UIImage systemImageNamed:systemName]
        forState:UIControlStateNormal];
    b.tintColor = PPChatInputBarControlTintColor(self.traitCollection);
    b.translatesAutoresizingMaskIntoConstraints = NO;
    [b.widthAnchor constraintEqualToConstant:44.0].active = YES;
    [b.heightAnchor constraintEqualToConstant:44.0].active = YES;
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = nil;
        if (@available(iOS 26.0, *)) {
            config = [UIButtonConfiguration glassButtonConfiguration];
        } else {
            config = [UIButtonConfiguration plainButtonConfiguration];
            config.background.backgroundColor = UIColor.clearColor;
            config.baseBackgroundColor = UIColor.clearColor;
            config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        }
        b.configuration = config;
    } else {
        b.backgroundColor = PPChatInputBarControlSurfaceColor(self.traitCollection);
    }

	    b.clipsToBounds = YES;
	    b.layer.cornerRadius = 22;
        [b addTarget:self
              action:@selector(pp_iconTouchDown:)
    forControlEvents:UIControlEventTouchDown];
        [b addTarget:self
              action:@selector(pp_iconTouchUp:)
    forControlEvents:UIControlEventTouchUpInside |
                     UIControlEventTouchUpOutside |
                     UIControlEventTouchCancel];
	    return b;
	}

- (void)pp_iconTouchDown:(UIButton *)sender
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        sender.alpha = 0.88;
        return;
    }

    [UIView animateWithDuration:0.08
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseOut
                     animations:^{
        sender.transform = CGAffineTransformMakeScale(0.96, 0.96);
        sender.alpha = 0.88;
    } completion:nil];
}

- (void)pp_iconTouchUp:(UIButton *)sender
{
    [UIView animateWithDuration:(UIAccessibilityIsReduceMotionEnabled() ? 0.01 : 0.16)
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        sender.transform = CGAffineTransformIdentity;
        sender.alpha = 1.0;
    } completion:nil];
}

- (void)setReplyPreviewTitle:(NSString *)title subtitle:(NSString *)subtitle animated:(BOOL)animated
{
    self.replyTitleLabel.text = title.length > 0 ? title : kLang(@"chat_replying");
    self.replySubtitleLabel.text = subtitle.length > 0 ? subtitle : kLang(@"Message");
    [self pp_setReplyPreviewVisible:YES animated:animated];
}

- (void)clearReplyPreviewAnimated:(BOOL)animated
{
    [self pp_setReplyPreviewVisible:NO animated:animated];
}

- (void)pp_replyCancelTapped
{
    if ([self.delegate respondsToSelector:@selector(inputBarDidCancelReply:)]) {
        [self.delegate inputBarDidCancelReply:self];
    } else {
        [self clearReplyPreviewAnimated:YES];
    }
}

- (void)pp_setReplyPreviewVisible:(BOOL)visible animated:(BOOL)animated
{
    if (visible) {
        self.replyPreviewView.hidden = NO;
    }

    self.replyPreviewHeightConstraint.constant = visible ? 54.0 : 0.0;
    self.stackTopConstraint.constant = visible ? 8.0 : 0.0;
    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();

    void (^changes)(void) = ^{
        self.replyPreviewView.alpha = visible ? 1.0 : 0.0;
        self.replyPreviewView.transform =
            visible ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0.0, 8.0);
        [self layoutIfNeeded];
        [self.superview layoutIfNeeded];
    };

    void (^finish)(BOOL) = ^(__unused BOOL finished) {
        self.replyPreviewView.hidden = !visible;
        if ([self.delegate respondsToSelector:@selector(inputBar:didChangeHeight:)]) {
            [self.delegate inputBar:self didChangeHeight:CGRectGetHeight(self.bounds)];
        }
    };

    if (!animated || reduceMotion) {
        changes();
        finish(YES);
        return;
    }

    if (visible) {
        self.replyPreviewView.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
    }

    [UIView animateWithDuration:0.24
                          delay:0.0
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.3
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:changes
                     completion:finish];
}

/*#pragma mark - Table View
 - (void)updateMessagePlaceholderVisibility {
     BOOL hasText = self.messageTextView.text.length > 0;

     self.messagePlaceholderLabel.hidden = hasText;
     self.messagePlaceholderLabel.alpha = hasText ? 0.0 : 1.0;
 }*/
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
    shouldReceiveTouch:(UITouch *)touch {

    // Always allow mic gestures immediately
    return YES;
}


- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    return YES;
}

// (Removed -intrinsicContentSize override)

#pragma mark - Text

- (void)textViewDidChange:(UITextView *)textView
{
    [self layoutIfNeeded];
    [self.delegate inputBar:self didChangeText:textView];
    self.placeholderLabel.hidden = (textView.text.length > 0);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateActionMode];
    });
   

    CGFloat maxHeight = 120.0;
 
    CGFloat bgWidth = self.textBackgroundView.bounds.size.width;

    CGSize fittingSize =
        [textView sizeThatFits:CGSizeMake(bgWidth - 16, CGFLOAT_MAX)];

    CGFloat targetHeight =
        MIN(MAX(44.0, fittingSize.height), maxHeight);

    if (fabs(self.textViewHeightConstraint.constant - targetHeight) > 0.5) {

        self.textViewHeightConstraint.constant = targetHeight;

        [UIView animateWithDuration:0.22
                              delay:0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
            
            [self layoutIfNeeded];
        } completion:nil];
    }

    textView.scrollEnabled = (fittingSize.height > maxHeight);
}

#pragma mark - Gestures

- (void)installGestures {

    self.panGesture =
    [[UIPanGestureRecognizer alloc] initWithTarget:self
                                            action:@selector(handlePan:)];
    self.panGesture.cancelsTouchesInView = NO;
    self.panGesture.delegate = self;
    // IMPORTANT: only on action container
    [self.actionsButton addGestureRecognizer:self.panGesture];
}


#pragma mark - Recording
- (void)recordingStart {
    self.recordingSessionEnded = NO;
    [self setMicVisible:YES animated:YES];
    self.isRecording = YES;
    self.isLocked = NO;

    self.didFinishOrCancel = NO;
    self.didCancelRecording = NO;
    self.panGesture.enabled = YES;

    [self.recordingBar reset];
    self.recordingBar.transform = UIAccessibilityIsReduceMotionEnabled()
        ? CGAffineTransformIdentity
        : CGAffineTransformMakeTranslation(0.0, 6.0);
    [self.recordingBar setRecordingState:PPRecordingBarStateRecording animated:NO];

    void (^changes)(void) = ^{
        self.textBackgroundView.alpha = 0.0;
        self.textView.alpha = 0.0;
        self.placeholderLabel.alpha = 0.0;
        self.mediaButton.alpha = 0.0;
        self.recordingBar.transform = CGAffineTransformIdentity;
    };

    if (UIAccessibilityIsReduceMotionEnabled()) {
        changes();
    } else {
        [UIView animateWithDuration:0.22
                              delay:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseOut
                         animations:changes
                         completion:nil];
    }

    [self.lockPill setState:PPRecordingLockPillStateIdle animated:YES];
}

- (void)recordingEnd {
    [self stopPreviewPlaybackIfNeeded];

    self.recordingSessionEnded = YES;

    [self setMicVisible:YES animated:YES];
    self.isRecording = NO;
    self.isLocked = NO;
    self.didCancelRecording = NO;
    
    self.panGesture.enabled = YES;
    self.recordingBar.transform = CGAffineTransformIdentity;
    self.recordingBar.hintLabel.alpha = 1.0;

    [self.recordingBar setRecordingState:PPRecordingBarStateHidden animated:YES];
    [self.lockPill setState:PPRecordingLockPillStateHidden animated:YES];

    void (^changes)(void) = ^{
        self.textBackgroundView.alpha = 1.0;
        self.textView.alpha = 1.0;
        self.mediaButton.alpha = 1.0;
        self.placeholderLabel.alpha = (self.textView.text.length == 0) ? 1.0 : 0.0;
    };

    if (UIAccessibilityIsReduceMotionEnabled()) {
        changes();
    } else {
        [UIView animateWithDuration:0.20
                              delay:0.03
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseInOut
                         animations:changes
                         completion:nil];
    }
}

 

- (void)cancelRecording {
    [self stopPreviewPlaybackIfNeeded];

    if (!self.isRecording) return;
    self.recordingSessionEnded = YES;

    self.didCancelRecording = YES;
    self.isRecording = NO;
    self.isLocked = NO;
    self.panGesture.enabled = YES;
    [self recordingEnd];
    [self setMicVisible:YES animated:YES];
    if ([self.delegate respondsToSelector:@selector(inputBarDidCancelRecording:)]) {
        [self.delegate inputBarDidCancelRecording:self];
    }
}

- (void)finishRecording {
    [self stopPreviewPlaybackIfNeeded];
    self.isRecording = NO;
    self.recordingSessionEnded = YES;
    [self setMicVisible:YES animated:YES];
    [self recordingEnd];
    
    if ([self.delegate respondsToSelector:@selector(inputBar:didFinishRecordingWithURL:duration:locked:)]) {
        [self.delegate inputBar:self didFinishRecordingWithURL:nil duration:0 locked:self.isLocked];
    }
}

#pragma mark - Public API

- (void)updateRecordingDuration:(NSTimeInterval)duration {
    [self.recordingBar updateDuration:duration];
}

- (void)setRecordingLocked:(BOOL)locked {
    self.isLocked = locked;
    //[self.recordingBar setLocked:locked];
}

- (void)resetRecordingUI {
    self.isRecording = NO;
    self.isLocked = NO;
    
}

#pragma mark - Actions

- (void)sendText
{
    NSString *text = self.textView.text;
    if (text.length == 0) return;

    // Clear text
    self.textView.text = @"";
    self.placeholderLabel.hidden = NO;

    // 🔥 RESET HEIGHT
    CGFloat minHeight = 44.0;
    self.textViewHeightConstraint.constant = minHeight;

    [UIView animateWithDuration:0.2
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        [self layoutIfNeeded];
    } completion:nil];

    if ([self.delegate respondsToSelector:@selector(inputBar:didSendText:)]) {
        [self.delegate inputBar:self didSendText:text];
    }

    [self updateActionMode];
}

 
// === Modern Composer Actions ===
- (void)onAttachTapped
{
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:nil
                                            message:nil
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    // 🖼 Image
    UIAlertAction *imageAction =
        [UIAlertAction actionWithTitle:kLang(@"imageFile")
                                 style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction * _Nonnull action) {
        //[self presentMediaPickerForType:UTTypeImage.identifier];
            
            if ([self.delegate respondsToSelector:@selector(inputBarDidTapAttachImage:)]) {
                [self.delegate inputBarDidTapAttachImage:self];
            }
            
    }];
     
    // 🎬 Video
    UIAlertAction *videoAction =
        [UIAlertAction actionWithTitle:kLang(@"VideoFile")
                                 style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction * _Nonnull action) {
       //
            if ([self.delegate respondsToSelector:@selector(inputBarDidTapAttachVideo:)]) {
                [self.delegate inputBarDidTapAttachVideo:self];
            }
    }];

    // ❌ Cancel
    UIAlertAction *cancelAction =
        [UIAlertAction actionWithTitle:kLang(@"cancel")
                                 style:UIAlertActionStyleCancel
                               handler:nil];

    [alert addAction:imageAction];
    [alert addAction:videoAction];
    [alert addAction:cancelAction];

    // iPad safety
    alert.popoverPresentationController.sourceView = self.mediaButton;
    alert.popoverPresentationController.sourceRect = self.mediaButton.bounds;

    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *presenter = PPChatInputBarResolvedPresenter(self, self.parentContainerViewController);
        if (!presenter) {
            NSLog(@"[PPChatInputBarView] Unable to present attachment sheet: missing presenter");
            return;
        }
        [presenter presentViewController:alert animated:YES completion:nil];
    });
}

- (void)appendRecordingWaveSample:(float)level
{
    if (self.recordingSessionEnded) return;
    if (!self.isRecording) return;

    [self.recordingBar appendWaveformSample:level];
}

@end
