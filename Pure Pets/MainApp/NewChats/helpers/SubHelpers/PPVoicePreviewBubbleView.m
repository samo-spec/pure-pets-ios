//
//  PPVoicePreviewBubbleView.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/01/2026.
//

#import "PPVoicePreviewBubbleView.h"
#import "PPChatsFunc.h"

@implementation PPVoicePreviewBubbleView {
    UILabel *_durationLabel;
    UIButton *_playButton;
    UIButton *_sendButton;
    UIButton *_deleteButton;
    UIView *_waveformPlaceholder;
}

- (instancetype)init {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;

    self.backgroundColor = [[PPChatsFunc chatNeutralAccentColor] colorWithAlphaComponent:0.10];
    self.layer.cornerRadius = 18;
    self.layer.borderWidth = 1;
    [self pp_setBorderColor:[[PPChatsFunc chatNeutralAccentColor] colorWithAlphaComponent:0.25]];

    [self buildUI];
    return self;
}

- (void)buildUI {

    _waveformPlaceholder = [[UIView alloc] init];
    _waveformPlaceholder.backgroundColor =
        [UIColor secondarySystemFillColor];
    _waveformPlaceholder.layer.cornerRadius = 6;

    _durationLabel = [[UILabel alloc] init];
    _durationLabel.font = [GM MidFontWithSize:13];
    _durationLabel.textColor = UIColor.secondaryLabelColor;

    _playButton   = [self iconButton:@"play.fill" action:@selector(playTapped)];
    _sendButton   = [self iconButton:@"arrow.up.circle.fill" action:@selector(sendTapped)];
    _deleteButton = [self iconButton:@"trash" action:@selector(deleteTapped)];

    UIStackView *buttons =
    [[UIStackView alloc] initWithArrangedSubviews:@[
        _playButton, _sendButton, _deleteButton
    ]];
    buttons.axis = UILayoutConstraintAxisHorizontal;
    buttons.spacing = 16;
    buttons.alignment = UIStackViewAlignmentCenter;

    UIStackView *stack =
    [[UIStackView alloc] initWithArrangedSubviews:@[
        _waveformPlaceholder,
        _durationLabel,
        buttons
    ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10;
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    [self addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:self.topAnchor constant:12],
        [stack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-12],
        [stack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
        [stack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],

        [_waveformPlaceholder.heightAnchor constraintEqualToConstant:22]
    ]];
}

- (UIButton *)iconButton:(NSString *)systemName action:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setImage:[UIImage systemImageNamed:systemName]
        forState:UIControlStateNormal];
    b.tintColor = [PPChatsFunc chatNeutralAccentColor];
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}

- (void)configureWithDuration:(NSTimeInterval)duration {
    int m = duration / 60;
    int s = (int)duration % 60;
    _durationLabel.text =
        [NSString stringWithFormat:@"%d:%02d", m, s];
}

- (void)playTapped   { if (self.onPlay)   self.onPlay(); }
- (void)sendTapped   { if (self.onSend)   self.onSend(); }
- (void)deleteTapped { if (self.onDelete) self.onDelete(); }

@end
