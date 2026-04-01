//
//  PPChatInputBarView.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 26/01/2026.
//

#import "PPChatInputBarView.h"


 
 static CGFloat const kLockThreshold   = 60.0;
static CGFloat const kCancelThreshold = 120.0;
static NSString * const kPPDidShowRecordHintKey = @"PPDidShowRecordHint";
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
    UIButtonConfiguration *config = self.textBackgroundView.configuration;
    config.background.cornerRadius = 16;
    config.background.backgroundColor = UIColor.clearColor;
    config.baseBackgroundColor = UIColor.clearColor;
    self.textBackgroundView.configuration = config;
    
    
   //self.textBackgroundView.layer.cornerRadius = 12;
    //self.textBackgroundView.clipsToBounds = YES;
    
    
    // Text view
    self.textView = [[UITextView alloc] init];
    self.textView.font = [GM MidFontWithSize:16];
    self.textView.delegate = self;
    self.textView.backgroundColor = UIColor.clearColor;
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
    self.placeholderLabel.textColor = UIColor.secondaryLabelColor;
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
    
    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.stack.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:12],
        [self.stack.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-12],
        [self.stack.topAnchor constraintEqualToAnchor:self.contentContainer.topAnchor constant:12],
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
        [self.recordingBar.heightAnchor constraintEqualToConstant:44],
        //[self.recordingBar.bottomAnchor constraintEqualToAnchor:self.contentContainer.bottomAnchor constant:-0],
        [self.recordingBar.centerYAnchor constraintEqualToAnchor:self.contentContainer.centerYAnchor],
     
    ]];
   
    self.clipsToBounds = NO;
    self.contentContainer.clipsToBounds = NO;   // ✅ VERY IMPORTANT
    //[self.recordingBar setRecordingState:PPRecordingBarStateRecording animated:NO];
    self.textView.clipsToBounds = YES;
    self.textView.layer.cornerRadius = 12;

}
-(void)layoutSubviews
{
    [super layoutSubviews];
    self.clipsToBounds = NO;
    self.layer.masksToBounds = NO;
    
    self.contentContainer.clipsToBounds = NO;
    self.contentContainer.layer.masksToBounds = NO;
    
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

    preferences.drawing.backgroundColor =
        [AppPrimaryClr colorWithAlphaComponent:0.92];
    preferences.drawing.foregroundColor = AppForgroundColr;
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
    
    
     
    UIImage *image =
        (self.actionMode == PPActionButtonModeSend)
        ? [UIImage systemImageNamed:@"arrow.up"]
        : [UIImage systemImageNamed:@"mic.fill"];

    void (^changes)(void) = ^{
        //[self.actionsButton setImage:image forState:UIControlStateNormal];
        self.actionsButton.tintColor =
            (self.actionMode == PPActionButtonModeSend)
            ? AppPrimaryClr
        : AppPrimaryTextClr;
        
        if (@available(iOS 18.0, *)) {
            [self.actionsButton.imageView setSymbolImage:image withContentTransition:[NSSymbolReplaceContentTransition magicTransitionWithFallback: NSSymbolReplaceContentTransition.replaceDownUpTransition.transitionWithByLayer] options: [NSSymbolEffectOptions optionsWithRepeatBehavior:[NSSymbolEffectOptionsRepeatBehavior behaviorPeriodic]]];
        }
        else
            [self.actionsButton setImage:image forState:UIControlStateNormal];
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
    b.tintColor = AppPrimaryTextClr;
    b.translatesAutoresizingMaskIntoConstraints = NO;
    [b.widthAnchor constraintEqualToConstant:44.0].active = YES;
    [b.heightAnchor constraintEqualToConstant:44.0].active = YES;
    UIButtonConfiguration *config;
    
    
    
    if (@available(iOS 26.0, *)) {
        config = [UIButtonConfiguration glassButtonConfiguration];
    } else {
        config = [UIButtonConfiguration filledButtonConfiguration];
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    }
    
    b.clipsToBounds = YES;
    b.layer.cornerRadius = 22;
    b.configuration = config;
    return b;
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
    [self.recordingBar setRecordingState:PPRecordingBarStateRecording animated:NO];

    self.textView.alpha = 0.0;
    self.placeholderLabel.alpha = 0.0;
    self.mediaButton.alpha = 0.0;
    
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
    
    self.textView.alpha = 1.0;
    self.mediaButton.alpha = 1.0;
    self.placeholderLabel.alpha = (self.textView.text.length == 0) ? 1.0 : 0.0;
 
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

    [self.parentContainerViewController presentViewController:alert animated:YES completion:nil];
}

- (void)appendRecordingWaveSample:(float)level
{
    if (self.recordingSessionEnded) return;
    if (!self.isRecording) return;

    [self.recordingBar appendWaveformSample:level];
}

@end
