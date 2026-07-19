//
//  PPSectionHeader.m
//  Pure Pets
//
//  Design System — Reusable section header with title + trailing action.
//

#import "PPSectionHeader.h"

@interface PPSectionHeader ()

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, copy, nullable) void(^onAction)(void);

@end

@implementation PPSectionHeader

+ (NSString *)reuseIdentifier {
    return @"PPSectionHeader";
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self pp_setupUI];
    }
    return self;
}

#pragma mark - UI

- (void)pp_setupUI {
    self.backgroundColor = UIColor.clearColor;

    // Title
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [GM boldFontWithSize:PPFontTitle3] ?: [UIFont systemFontOfSize:20.0 weight:UIFontWeightBold];
    _titleLabel.textColor = AppPrimaryTextClr;
    _titleLabel.numberOfLines = 1;
    [self addSubview:_titleLabel];

    // "عرض الكل" trailing button
    _actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _actionButton.translatesAutoresizingMaskIntoConstraints = NO;
    _actionButton.titleLabel.font = [GM MidFontWithSize:PPFontFootnote] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    [_actionButton setTitle:(kLang(@"SeeAll") ?: @"عرض الكل") forState:UIControlStateNormal];
    [_actionButton setTitleColor:AppPrimaryClr forState:UIControlStateNormal];
    _actionButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentTrailing;
    [_actionButton addTarget:self action:@selector(pp_handleAction) forControlEvents:UIControlEventTouchUpInside];
    _actionButton.hidden = YES;
    [self addSubview:_actionButton];

    // Constraints — 8pt grid, safe for RTL
    [NSLayoutConstraint activateConstraints:@[
        [_titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:PPSpaceMD],
        [_titleLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_actionButton.leadingAnchor constant:-PPSpaceSM],

        [_actionButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-PPSpaceMD],
        [_actionButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_actionButton.heightAnchor constraintGreaterThanOrEqualToConstant:44],
    ]];

    [_titleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    [_actionButton setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
}

#pragma mark - Configure

- (void)configureWithTitle:(NSString *)title
                   showAll:(BOOL)showAll
                    action:(nullable void(^)(void))action {
    self.titleLabel.text = title;
    self.actionButton.hidden = !showAll;
    self.onAction = action;
}

- (void)pp_handleAction {
    if (self.onAction) {
        self.onAction();
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.titleLabel.text = nil;
    self.actionButton.hidden = YES;
    self.onAction = nil;
}

@end
