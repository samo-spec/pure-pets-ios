//
//  PPProviderSubscriptionManagementVC.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 6/13/26.
//

#import "PPProviderSubscriptionManagementVC.h"
#import <QuartzCore/QuartzCore.h>

@interface PPProviderSubscriptionManagementVC ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *secondCardView;
@property (nonatomic, strong) UILabel *titleLabel;
@end

@implementation PPProviderSubscriptionManagementVC

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupView];
    [self setupConstraints];
}

- (void)setupView {
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = kLang(@"subscription_management_title") ?: @"Subscription Management";

    // Setup scroll view
    _scrollView = [[UIScrollView alloc] init];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.alwaysBounceVertical = YES;
    _scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:_scrollView];

    // Setup content view
    _contentView = [[UIView alloc] init];
    _contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [_scrollView addSubview:_contentView];

    // Setup second card view (since we removed the first card)
    _secondCardView = [[UIView alloc] init];
    _secondCardView.translatesAutoresizingMaskIntoConstraints = NO;
    _secondCardView.layer.cornerRadius = 16.0;
    _secondCardView.layer.masksToBounds = YES;
    
    // Apply thin blur with liquid borders
    if (@available(iOS 26.0, *)) {
        UIButton *glassButton = [UIButton buttonWithType:UIButtonTypeSystem];
        glassButton.translatesAutoresizingMaskIntoConstraints = NO;
        glassButton.backgroundColor = [UIColor clearColor];
        
        UIButtonConfiguration *configuration = [UIButtonConfiguration glassButtonConfiguration];
        configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        configuration.contentInsets = NSDirectionalEdgeInsetsZero;
        configuration.baseForegroundColor = [UIColor clearColor];
        
        UIBackgroundConfiguration *background = configuration.background ?: [UIBackgroundConfiguration clearConfiguration];
        background.backgroundInsets = NSDirectionalEdgeInsetsZero;
        background.backgroundColor = [UIColor clearColor];
        background.strokeColor = [[UIColor labelColor] colorWithAlphaComponent:0.3];
        background.strokeWidth = 1.0;
        background.visualEffect = [UIGlassEffect effectWithStyle:UIGlassEffectStyleClear];
        background.cornerRadius = 16.0;
        configuration.background = background;
        
        glassButton.configuration = configuration;
        [_secondCardView addSubview:glassButton];
        
        [NSLayoutConstraint activateConstraints:@[
            [glassButton.topAnchor constraintEqualToAnchor:_secondCardView.topAnchor],
            [glassButton.leadingAnchor constraintEqualToAnchor:_secondCardView.leadingAnchor],
            [glassButton.trailingAnchor constraintEqualToAnchor:_secondCardView.trailingAnchor],
            [glassButton.bottomAnchor constraintEqualToAnchor:_secondCardView.bottomAnchor]
        ]];
    } else {
        // Fallback for earlier versions - use blur effect
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurView.translatesAutoresizingMaskIntoConstraints = NO;
        blurView.userInteractionEnabled = NO;
        [_secondCardView addSubview:blurView];
        
        [NSLayoutConstraint activateConstraints:@[
            [blurView.topAnchor constraintEqualToAnchor:_secondCardView.topAnchor],
            [blurView.leadingAnchor constraintEqualToAnchor:_secondCardView.leadingAnchor],
            [blurView.trailingAnchor constraintEqualToAnchor:_secondCardView.trailingAnchor],
            [blurView.bottomAnchor constraintEqualToAnchor:_secondCardView.bottomAnchor]
        ]];
        
        // Add liquid border effect for older iOS
        _secondCardView.layer.borderWidth = 1.0;
        _secondCardView.layer.borderColor = [[UIColor labelColor] colorWithAlphaComponent:0.2].CGColor;
    }
    
    [_contentView addSubview:_secondCardView];

    // Setup title label
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.text = kLang(@"subscription_management_title") ?: @"Subscription Management";
    _titleLabel.font = [UIFont systemFontOfSize:24.0 weight:UIFontWeightBold];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.textColor = [UIColor labelColor];
    [_secondCardView addSubview:_titleLabel];
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        [_scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        [_contentView.topAnchor constraintEqualToAnchor:_scrollView.topAnchor],
        [_contentView.leadingAnchor constraintEqualToAnchor:_scrollView.leadingAnchor],
        [_contentView.trailingAnchor constraintEqualToAnchor:_scrollView.trailingAnchor],
        [_contentView.bottomAnchor constraintEqualToAnchor:_scrollView.bottomAnchor],
        [_contentView.widthAnchor constraintEqualToAnchor:_scrollView.widthAnchor],
        
        [_secondCardView.topAnchor constraintEqualToAnchor:_contentView.topAnchor constant:20.0],
        [_secondCardView.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:20.0],
        [_secondCardView.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-20.0],
        [_secondCardView.heightAnchor constraintEqualToConstant:200.0],
        
        [_titleLabel.centerXAnchor constraintEqualToAnchor:_secondCardView.centerXAnchor],
        [_titleLabel.centerYAnchor constraintEqualToAnchor:_secondCardView.centerYAnchor],
        
        [_contentView.bottomAnchor constraintEqualToAnchor:_secondCardView.bottomAnchor constant:20.0]
    ]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}

@end