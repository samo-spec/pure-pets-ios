#import "EmptyStateView.h"

@implementation EmptyStateView

- (instancetype)initWithFrame:(CGRect)frame
               animationNamed:(NSString *)animationName
                        title:(NSString *)title
                     subTitle:(NSString *)subTitle
                  buttonTitle:(NSString *)buttonTitle
                       target:(id)target
                emptyIconSize:(float)emptyIconSize
                isNetworkFile:(BOOL)isNetworkFile
                       action:(SEL)action
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.animationViewSize = emptyIconSize;
    self.backgroundColor = UIColor.clearColor;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.distribution = UIStackViewDistributionFill;
    // Default spacing
    stack.spacing = 14;
    [self addSubview:stack];
    self.stackView = stack;

    // --- Animation View ---
    self.animationView = [[LOTAnimationView alloc] init];
    self.animationView.loopAnimation = YES;
    self.animationView.animationSpeed = 0.7;
    self.animationView.contentMode = UIViewContentModeScaleAspectFit;

    if (isNetworkFile) {
        [AppClasses fetchLottieJSONFromFirebasePath:[NSString stringWithFormat:@"LottieAnimations/%@", animationName]
                                         completion:^(NSDictionary * _Nonnull jsonDict, NSError * _Nonnull error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    NSLog(@"❌ Failed to fetch Lottie JSON: %@", error.localizedDescription);
                    return;
                }
                LOTComposition *composition = [LOTComposition animationFromJSON:jsonDict];
                if (composition) {
                    [self.animationView setSceneModel:composition];
                    [self.animationView play];
                }
            });
        }];
        [self.stackView addArrangedSubview:self.animationView];
    } else {
        LOTAnimationView *localAnim = [LOTAnimationView animationNamed:animationName];
        localAnim.loopAnimation = YES;
        localAnim.animationSpeed = 0.7;
        localAnim.contentMode = UIViewContentModeScaleAspectFit;
        [self.animationView removeFromSuperview];
        self.animationView = localAnim;
        [self.stackView addArrangedSubview:self.animationView];
    }
    self.animationView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [self.animationView.widthAnchor constraintEqualToConstant:self.animationViewSize],
        [self.animationView.heightAnchor constraintEqualToConstant:self.animationViewSize]
    ]];

    // --- Title Label ---
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = title ?: @"";
    self.titleLabel.textColor = UIColor.labelColor;
    self.titleLabel.font = [GM boldFontWithSize:16];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.numberOfLines = 0;
    [self.stackView addArrangedSubview:self.titleLabel];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.preferredMaxLayoutWidth = UIScreen.mainScreen.bounds.size.width - 40;

    // --- Subtitle Label ---
    self.subTitleLabel = [[UILabel alloc] init];
    self.subTitleLabel.text = subTitle ?: @"";
    self.subTitleLabel.textColor = UIColor.secondaryLabelColor;
    self.subTitleLabel.font = [GM MidFontWithSize:16];
    self.subTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.subTitleLabel.numberOfLines = 0;
    [self.stackView addArrangedSubview:self.subTitleLabel];
    // Hide subtitle if empty to collapse stack spacing
    BOOL hasSubtitle = (subTitle.length > 0);
    self.subTitleLabel.hidden = !hasSubtitle;
    if (!hasSubtitle) {
        // Reduce vertical gap when subtitle is missing
        [self.stackView setCustomSpacing:6 afterView:self.titleLabel];
    }
    self.subTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subTitleLabel.preferredMaxLayoutWidth = UIScreen.mainScreen.bounds.size.width - 60;

    // --- Button ---
    if (buttonTitle.length > 0) {
        if (@available(iOS 26.0, *)) {
            self.reloadButton = [PPButtonHelper pp_buttonWithTitle:buttonTitle font:[GM boldFontWithSize:16] textColor:[AppPrimaryClr colorWithAlphaComponent:1.1] corners:22 imageName:nil target:target config:[UIButtonConfiguration glassButtonConfiguration] btnSize:50 action:action];
        } else {
            self.reloadButton = [PPButtonHelper pp_buttonWithTitle:buttonTitle font:[GM boldFontWithSize:16] textColor:[AppPrimaryClr colorWithAlphaComponent:1.1] corners:22 imageName:nil target:target config:[UIButtonConfiguration filledButtonConfiguration] btnSize:50 action:action];
        }
       //  self.reloadButton.backgroundColor = appfo ?: UIColor.systemGray6Color;
       // [self.reloadButton setTitleColor:UIColor.darkGrayColor forState:UIControlStateNormal];
       // self.reloadButton.layer.cornerRadius = 22;
       // self.reloadButton.clipsToBounds = YES;
        [self.reloadButton addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
        [self.stackView addArrangedSubview:self.reloadButton];
        self.reloadButton.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [self.reloadButton.widthAnchor constraintEqualToConstant:180],
            [self.reloadButton.heightAnchor constraintEqualToConstant:44]
        ]];
    }

    // Force stackView to calculate its intrinsic size
    [self.stackView setNeedsLayout];
    [self.stackView layoutIfNeeded];

    CGSize fittingSize =
    [self.stackView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];

    self.stackView.bounds = (CGRect){CGPointZero, fittingSize};
    self.stackView.center = CGPointMake(CGRectGetMidX(self.bounds),
                                        CGRectGetMidY(self.bounds));

    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
               animationNamed:(NSString *)animationName
                        title:(NSString *)title
                     subTitle:(NSString *)subTitle
                  buttonTitle:(NSString *)buttonTitle
                       target:(id)target
                isNetworkFile:(BOOL)isNetworkFile
                       action:(SEL)action
{
    return [self initWithFrame:frame
                animationNamed:animationName
                         title:title
                      subTitle:subTitle
                   buttonTitle:buttonTitle
                        target:target
                 emptyIconSize:300
                 isNetworkFile:isNetworkFile
                        action:action];
}

// Update stackView's size and position on bounds changes
- (void)layoutSubviews {
    [super layoutSubviews];

    [self.stackView setNeedsLayout];
    [self.stackView layoutIfNeeded];

    CGSize fittingSize =
    [self.stackView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];

    self.stackView.bounds = (CGRect){CGPointZero, fittingSize};
    self.stackView.center = CGPointMake(CGRectGetMidX(self.bounds),
                                        CGRectGetMidY(self.bounds));
}

@end
