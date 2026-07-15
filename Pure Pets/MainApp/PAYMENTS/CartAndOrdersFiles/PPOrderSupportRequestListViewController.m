//
//  PPOrderSupportRequestListViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 7/14/26.
//

#import "PPOrderSupportRequestListViewController.h"
#import "PPOrder.h"
#import "PPOrderManager.h"
#import "OrderSupportFunc.h"
#import "PPOrderSupportRequestDetailsViewController.h"

static CGFloat const PPOrderSupportListBottomComfortInset = 96.0;
static CGFloat const PPOrderSupportListCardMinHeight = 116.0;

static UIFont *PPOrderSupportListFont(UIFontTextStyle textStyle, UIFontWeight weight)
{
    UIFontDescriptor *descriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle:textStyle];
    UIFont *font = [UIFont systemFontOfSize:descriptor.pointSize weight:weight];
    return [[UIFontMetrics metricsForTextStyle:textStyle] scaledFontForFont:font];
}

static UIColor *PPOrderSupportListAccentColor(void)
{
    return AppPrimaryClr ?: UIColor.systemOrangeColor;
}

static NSString *PPOrderSupportListCleanText(NSString *text, NSString *fallback)
{
    if ([text isKindOfClass:NSString.class] && text.length > 0) {
        return text;
    }
    return fallback ?: @"";
}

static NSString *PPOrderSupportListDateString(NSDateFormatter *formatter, NSDate *date)
{
    if (!date) {
        return @"";
    }
    return [formatter stringFromDate:date] ?: @"";
}

@interface PPOrderSupportListInsetLabel : UILabel
@property (nonatomic, assign) UIEdgeInsets contentInsets;
@end

@implementation PPOrderSupportListInsetLabel

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _contentInsets = UIEdgeInsetsMake(5.0, 10.0, 5.0, 10.0);
    }
    return self;
}

- (CGSize)intrinsicContentSize
{
    CGSize size = [super intrinsicContentSize];
    size.width += self.contentInsets.left + self.contentInsets.right;
    size.height += self.contentInsets.top + self.contentInsets.bottom;
    return size;
}

- (void)drawTextInRect:(CGRect)rect
{
    [super drawTextInRect:UIEdgeInsetsInsetRect(rect, self.contentInsets)];
}

@end

@interface PPOrderSupportRequestCardControl : UIControl
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIView *iconPlate;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *reasonLabel;
@property (nonatomic, strong) UILabel *metaLabel;
@property (nonatomic, strong) PPOrderSupportListInsetLabel *statusLabel;
@property (nonatomic, strong) UIImageView *chevronView;
- (void)configureWithRequest:(PPOrderSupportRequest *)request dateFormatter:(NSDateFormatter *)dateFormatter;
@end

@implementation PPOrderSupportRequestCardControl

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.accessibilityTraits = UIAccessibilityTraitButton;

        _surfaceView = [[UIView alloc] initWithFrame:CGRectZero];
        _surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
        _surfaceView.userInteractionEnabled = NO;
        PPOrderDetailsApplySurface(_surfaceView, PPCornerCard, YES);
        _surfaceView.layer.borderWidth = 1.0;
        [_surfaceView pp_setBorderColor:[UIColor.labelColor colorWithAlphaComponent:0.07]];
        [self addSubview:_surfaceView];

        _iconPlate = [[UIView alloc] initWithFrame:CGRectZero];
        _iconPlate.translatesAutoresizingMaskIntoConstraints = NO;
        PPApplyContinuousCorners(_iconPlate, 18.0);
        [_surfaceView addSubview:_iconPlate];

        _iconView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        _iconView.contentMode = UIViewContentModeCenter;
        [_iconPlate addSubview:_iconView];

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.font = PPOrderSupportListFont(UIFontTextStyleHeadline, UIFontWeightSemibold);
        _titleLabel.adjustsFontForContentSizeCategory = YES;
        _titleLabel.textColor = UIColor.labelColor;
        _titleLabel.numberOfLines = 2;
        _titleLabel.textAlignment = Language.isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;

        _reasonLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _reasonLabel.font = PPOrderSupportListFont(UIFontTextStyleSubheadline, UIFontWeightRegular);
        _reasonLabel.adjustsFontForContentSizeCategory = YES;
        _reasonLabel.textColor = UIColor.secondaryLabelColor;
        _reasonLabel.numberOfLines = 2;
        _reasonLabel.textAlignment = Language.isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;

        UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[_titleLabel, _reasonLabel]];
        textStack.axis = UILayoutConstraintAxisVertical;
        textStack.spacing = 4.0;
        textStack.alignment = UIStackViewAlignmentFill;
        textStack.translatesAutoresizingMaskIntoConstraints = NO;

        _chevronView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _chevronView.translatesAutoresizingMaskIntoConstraints = NO;
        _chevronView.contentMode = UIViewContentModeCenter;
        _chevronView.tintColor = UIColor.tertiaryLabelColor;
        UIImageSymbolConfiguration *chevronConfig = [UIImageSymbolConfiguration configurationWithPointSize:13.0 weight:UIImageSymbolWeightSemibold];
        NSString *chevronName = Language.isRTL ? @"chevron.left" : @"chevron.right";
        _chevronView.image = [[UIImage systemImageNamed:chevronName withConfiguration:chevronConfig] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

        UIStackView *headerStack = [[UIStackView alloc] initWithArrangedSubviews:@[_iconPlate, textStack, _chevronView]];
        headerStack.axis = UILayoutConstraintAxisHorizontal;
        headerStack.alignment = UIStackViewAlignmentCenter;
        headerStack.spacing = PPSpaceMD;
        headerStack.translatesAutoresizingMaskIntoConstraints = NO;

        _statusLabel = [[PPOrderSupportListInsetLabel alloc] initWithFrame:CGRectZero];
        _statusLabel.font = PPOrderSupportListFont(UIFontTextStyleCaption1, UIFontWeightSemibold);
        _statusLabel.adjustsFontForContentSizeCategory = YES;
        _statusLabel.numberOfLines = 1;
        _statusLabel.textAlignment = NSTextAlignmentCenter;
        PPApplyContinuousCorners(_statusLabel, 14.0);
        _statusLabel.clipsToBounds = YES;

        _metaLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _metaLabel.font = PPOrderSupportListFont(UIFontTextStyleFootnote, UIFontWeightRegular);
        _metaLabel.adjustsFontForContentSizeCategory = YES;
        _metaLabel.textColor = UIColor.tertiaryLabelColor;
        _metaLabel.numberOfLines = 2;
        _metaLabel.textAlignment = Language.isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;

        UIStackView *footerStack = [[UIStackView alloc] initWithArrangedSubviews:@[_statusLabel, _metaLabel]];
        footerStack.axis = UILayoutConstraintAxisVertical;
        footerStack.alignment = Language.isRTL ? UIStackViewAlignmentTrailing : UIStackViewAlignmentLeading;
        footerStack.spacing = 7.0;
        footerStack.translatesAutoresizingMaskIntoConstraints = NO;

        UIStackView *contentStack = [[UIStackView alloc] initWithArrangedSubviews:@[headerStack, footerStack]];
        contentStack.axis = UILayoutConstraintAxisVertical;
        contentStack.spacing = PPSpaceMD;
        contentStack.translatesAutoresizingMaskIntoConstraints = NO;
        [_surfaceView addSubview:contentStack];

        [NSLayoutConstraint activateConstraints:@[
            [_surfaceView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_surfaceView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_surfaceView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [_surfaceView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            [_surfaceView.heightAnchor constraintGreaterThanOrEqualToConstant:PPOrderSupportListCardMinHeight],

            [contentStack.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:PPSpaceLG],
            [contentStack.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:-PPSpaceLG],
            [contentStack.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:PPSpaceLG],
            [contentStack.bottomAnchor constraintEqualToAnchor:_surfaceView.bottomAnchor constant:-PPSpaceLG],

            [_iconPlate.widthAnchor constraintEqualToConstant:50.0],
            [_iconPlate.heightAnchor constraintEqualToConstant:50.0],
            [_iconView.centerXAnchor constraintEqualToAnchor:_iconPlate.centerXAnchor],
            [_iconView.centerYAnchor constraintEqualToAnchor:_iconPlate.centerYAnchor],
            [_iconView.widthAnchor constraintEqualToConstant:28.0],
            [_iconView.heightAnchor constraintEqualToConstant:28.0],
            [_chevronView.widthAnchor constraintEqualToConstant:20.0],
            [_chevronView.heightAnchor constraintEqualToConstant:30.0]
        ]];

        [textStack setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
        [_statusLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    }
    return self;
}

- (void)configureWithRequest:(PPOrderSupportRequest *)request dateFormatter:(NSDateFormatter *)dateFormatter
{
    UIColor *statusColor = PPOrderRequestStatusColor(request.status) ?: PPOrderSupportListAccentColor();
    NSString *requestTitle = [PPOrderManager displayTitleForRequestType:request.type];
    NSString *statusTitle = [PPOrderManager displayTitleForRequestStatus:request.status];
    NSString *reason = PPOrderSupportListCleanText(request.subject, nil);
    if (reason.length == 0) {
        reason = PPOrderSupportListCleanText(request.reasonTitle, request.reasonCode);
    }
    if (reason.length == 0) {
        reason = statusTitle;
    }

    NSDate *date = request.updatedAt ?: request.createdAt ?: request.submittedAt;
    NSString *dateText = PPOrderSupportListDateString(dateFormatter, date);
    NSInteger itemCount = MAX(request.itemSnapshots.count, request.itemIDs.count);
    NSMutableArray<NSString *> *metaParts = [NSMutableArray array];
    if (dateText.length > 0) {
        [metaParts addObject:dateText];
    }
    if (itemCount > 0) {
        [metaParts addObject:[NSString stringWithFormat:@"%ld %@", (long)itemCount, kLang(@"items")]];
    }

    self.titleLabel.text = requestTitle;
    self.reasonLabel.text = reason;
    self.metaLabel.text = [metaParts componentsJoinedByString:@"  "];
    self.statusLabel.text = statusTitle;
    self.statusLabel.textColor = statusColor;
    self.statusLabel.backgroundColor = [statusColor colorWithAlphaComponent:0.12];
    self.iconPlate.backgroundColor = [statusColor colorWithAlphaComponent:0.12];
    self.iconView.tintColor = statusColor;
    UIImageSymbolConfiguration *symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:20.0 weight:UIImageSymbolWeightSemibold];
    self.iconView.image = [[UIImage systemImageNamed:@"doc.text.magnifyingglass" withConfiguration:symbolConfig] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

    self.isAccessibilityElement = YES;
    self.accessibilityLabel = [[@[requestTitle ?: @"", reason ?: @"", statusTitle ?: @"", dateText ?: @""] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *text, NSDictionary *bindings) {
        (void)bindings;
        return text.length > 0;
    }]] componentsJoinedByString:@", "];
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    CGFloat targetScale = highlighted ? 0.985 : 1.0;
    CGFloat targetAlpha = highlighted ? 0.92 : 1.0;
    NSTimeInterval duration = UIAccessibilityIsReduceMotionEnabled() ? 0.08 : 0.18;
    [UIView animateWithDuration:duration
                          delay:0.0
         usingSpringWithDamping:0.82
          initialSpringVelocity:0.12
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.surfaceView.transform = CGAffineTransformMakeScale(targetScale, targetScale);
        self.surfaceView.alpha = targetAlpha;
    } completion:nil];
}

@end

@interface PPOrderSupportRequestListViewController ()
@property (nonatomic, strong) PPOrder *order;
@property (nonatomic, strong) PPOrderManager *orderManager;
@property (nonatomic, strong) NSArray<PPOrderSupportRequest *> *requests;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) NSError *loadError;
@property (nonatomic, strong) id<FIRListenerRegistration> listener;
@property (nonatomic, assign) BOOL isLoadingRequests;
@property (nonatomic, assign) BOOL didPlayEntranceAnimation;
@end

@implementation PPOrderSupportRequestListViewController

+ (instancetype)controllerWithOrder:(PPOrder *)order
                       orderManager:(PPOrderManager *)orderManager
                           requests:(NSArray<PPOrderSupportRequest *> *)requests
{
    PPOrderSupportRequestListViewController *vc = [PPOrderSupportRequestListViewController new];
    vc.order = order;
    vc.orderManager = orderManager ?: [PPOrderManager shared];
    vc.requests = requests ?: @[];
    return vc;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.title = kLang(@"order_requests_history_title");
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    [self pp_orderApplyChevronBackButton];

    self.dateFormatter = [NSDateFormatter new];
    self.dateFormatter.locale = [NSLocale currentLocale];
    [self.dateFormatter setLocalizedDateFormatFromTemplate:@"EEE d MMM h:mm a"];

    self.isLoadingRequests = self.requests.count == 0;
    [self buildScrollLayout];
    [self renderContentAnimated:NO];
    [self beginListeningForRequests];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self playEntranceAnimationIfNeeded];
}

- (void)dealloc
{
    [self.listener remove];
}

#pragma mark - Layout

- (void)buildScrollLayout
{
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.backgroundColor = UIColor.clearColor;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.scrollView.contentInset = UIEdgeInsetsMake(0.0, 0.0, PPOrderSupportListBottomComfortInset, 0.0);
    self.scrollView.scrollIndicatorInsets = self.scrollView.contentInset;
    [self.view addSubview:self.scrollView];

    self.contentStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = PPSpaceMD;
    self.contentStack.alignment = UIStackViewAlignmentFill;
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentStack];

    self.refreshControl = [[UIRefreshControl alloc] initWithFrame:CGRectZero];
    self.refreshControl.tintColor = PPOrderSupportListAccentColor();
    [self.refreshControl addTarget:self action:@selector(handleRefresh) forControlEvents:UIControlEventValueChanged];
    self.scrollView.refreshControl = self.refreshControl;

    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.topAnchor constraintEqualToAnchor:safeArea.topAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor constant:kOrderDetailsScreenMargin],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor constant:-kOrderDetailsScreenMargin],
        [self.contentStack.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:PPSpaceBase],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-PPSpaceXL],
        [self.contentStack.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor constant:-(kOrderDetailsScreenMargin * 2.0)]
    ]];
}

#pragma mark - Data

- (void)beginListeningForRequests
{
    __weak typeof(self) weakSelf = self;
    self.listener = [self.orderManager listenToSupportRequestsForOrderID:self.order.orderId
                                                                  update:^(NSArray<PPOrderSupportRequest *> *requests, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            strongSelf.isLoadingRequests = NO;
            strongSelf.loadError = error;
            if (!error) {
                strongSelf.requests = requests ?: @[];
            }
            [strongSelf.refreshControl endRefreshing];
            [strongSelf renderContentAnimated:YES];
        });
    }];

    if (!self.listener) {
        self.isLoadingRequests = NO;
        [self renderContentAnimated:YES];
    }
}

- (void)handleRefresh
{
    __weak typeof(self) weakSelf = self;
    [self.orderManager fetchSupportRequestsForOrderID:self.order.orderId
                                           completion:^(NSArray<PPOrderSupportRequest *> *requests, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            strongSelf.isLoadingRequests = NO;
            strongSelf.loadError = error;
            if (!error) {
                strongSelf.requests = requests ?: @[];
            }
            [strongSelf.refreshControl endRefreshing];
            [strongSelf renderContentAnimated:YES];
        });
    }];
}

#pragma mark - Rendering

- (void)renderContentAnimated:(BOOL)animated
{
    void (^renderBlock)(void) = ^{
        [self clearContentStack];
        [self.contentStack addArrangedSubview:[self makeHeaderCard]];

        if (self.isLoadingRequests) {
            [self addLoadingState];
        } else if (self.loadError) {
            [self.contentStack addArrangedSubview:[self makeErrorCardWithError:self.loadError]];
        } else if (self.requests.count == 0) {
            [self.contentStack addArrangedSubview:[self makeEmptyCard]];
        } else {
            for (PPOrderSupportRequest *request in self.requests) {
                [self.contentStack addArrangedSubview:[self makeCardForRequest:request]];
            }
        }
        [self.view layoutIfNeeded];
    };

    if (animated && self.view.window && !UIAccessibilityIsReduceMotionEnabled()) {
        [UIView transitionWithView:self.contentStack
                          duration:0.22
                           options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowUserInteraction
                        animations:renderBlock
                        completion:nil];
    } else {
        renderBlock();
    }
}

- (void)clearContentStack
{
    NSArray<UIView *> *views = self.contentStack.arrangedSubviews.copy;
    for (UIView *view in views) {
        [self.contentStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
}

- (UIView *)makeHeaderCard
{
    UIView *card = [[UIView alloc] initWithFrame:CGRectZero];
    PPOrderDetailsApplySurface(card, PPCornerCard + 4.0, YES);
    card.layer.borderWidth = 1.0;
    [card pp_setBorderColor:[UIColor.labelColor colorWithAlphaComponent:0.06]];

    UIView *iconPlate = [[UIView alloc] initWithFrame:CGRectZero];
    iconPlate.translatesAutoresizingMaskIntoConstraints = NO;
    iconPlate.backgroundColor = [PPOrderSupportListAccentColor() colorWithAlphaComponent:0.12];
    PPApplyContinuousCorners(iconPlate, 20.0);

    UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectZero];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = PPOrderSupportListAccentColor();
    iconView.contentMode = UIViewContentModeCenter;
    UIImageSymbolConfiguration *symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:22.0 weight:UIImageSymbolWeightSemibold];
    iconView.image = [[UIImage systemImageNamed:@"rectangle.stack.badge.person.crop" withConfiguration:symbolConfig] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [iconPlate addSubview:iconView];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    titleLabel.font = PPOrderSupportListFont(UIFontTextStyleTitle3, UIFontWeightBold);
    titleLabel.adjustsFontForContentSizeCategory = YES;
    titleLabel.textColor = UIColor.labelColor;
    titleLabel.numberOfLines = 2;
    titleLabel.textAlignment = Language.isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    titleLabel.text = kLang(@"order_requests_history_title");

    UILabel *subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    subtitleLabel.font = PPOrderSupportListFont(UIFontTextStyleSubheadline, UIFontWeightRegular);
    subtitleLabel.adjustsFontForContentSizeCategory = YES;
    subtitleLabel.textColor = UIColor.secondaryLabelColor;
    subtitleLabel.numberOfLines = 3;
    subtitleLabel.textAlignment = Language.isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    subtitleLabel.text = kLang(@"order_action_support_hint");

    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, subtitleLabel]];
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = 5.0;
    textStack.translatesAutoresizingMaskIntoConstraints = NO;

    PPOrderSupportListInsetLabel *countPill = [[PPOrderSupportListInsetLabel alloc] initWithFrame:CGRectZero];
    countPill.font = PPOrderSupportListFont(UIFontTextStyleCaption1, UIFontWeightSemibold);
    countPill.adjustsFontForContentSizeCategory = YES;
    countPill.textColor = PPOrderSupportListAccentColor();
    countPill.backgroundColor = [PPOrderSupportListAccentColor() colorWithAlphaComponent:0.10];
    countPill.textAlignment = NSTextAlignmentCenter;
    PPApplyContinuousCorners(countPill, 14.0);
    countPill.clipsToBounds = YES;
    countPill.text = self.isLoadingRequests ? @"..." : [NSString stringWithFormat:@"%ld", (long)self.requests.count];

    UIStackView *rowStack = [[UIStackView alloc] initWithArrangedSubviews:@[iconPlate, textStack, countPill]];
    rowStack.axis = UILayoutConstraintAxisHorizontal;
    rowStack.alignment = UIStackViewAlignmentCenter;
    rowStack.spacing = PPSpaceMD;
    rowStack.translatesAutoresizingMaskIntoConstraints = NO;
    rowStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [card addSubview:rowStack];

    [NSLayoutConstraint activateConstraints:@[
        [rowStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:PPSpaceLG],
        [rowStack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-PPSpaceLG],
        [rowStack.topAnchor constraintEqualToAnchor:card.topAnchor constant:PPSpaceLG],
        [rowStack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-PPSpaceLG],

        [iconPlate.widthAnchor constraintEqualToConstant:56.0],
        [iconPlate.heightAnchor constraintEqualToConstant:56.0],
        [iconView.centerXAnchor constraintEqualToAnchor:iconPlate.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconPlate.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:32.0],
        [iconView.heightAnchor constraintEqualToConstant:32.0]
    ]];

    [textStack setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [countPill setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    card.isAccessibilityElement = NO;
    return card;
}

- (void)addLoadingState
{
    for (NSInteger index = 0; index < 3; index++) {
        UIView *card = [self makeSkeletonCardWithDelay:(CFTimeInterval)index * 0.08];
        [self.contentStack addArrangedSubview:card];
    }
}

- (UIView *)makeSkeletonCardWithDelay:(CFTimeInterval)delay
{
    UIView *card = [[UIView alloc] initWithFrame:CGRectZero];
    PPOrderDetailsApplySurface(card, PPCornerCard, NO);
    card.layer.borderWidth = 1.0;
    [card pp_setBorderColor:[UIColor.labelColor colorWithAlphaComponent:0.045]];

    UIView *circle = [self makeSkeletonBlockWithCornerRadius:20.0 delay:delay];
    UIView *lineA = [self makeSkeletonBlockWithCornerRadius:7.0 delay:delay + 0.04];
    UIView *lineB = [self makeSkeletonBlockWithCornerRadius:6.0 delay:delay + 0.08];
    UIView *lineC = [self makeSkeletonBlockWithCornerRadius:6.0 delay:delay + 0.12];

    for (UIView *view in @[circle, lineA, lineB, lineC]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [card addSubview:view];
    }

    [NSLayoutConstraint activateConstraints:@[
        [card.heightAnchor constraintGreaterThanOrEqualToConstant:PPOrderSupportListCardMinHeight],
        [circle.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:PPSpaceLG],
        [circle.topAnchor constraintEqualToAnchor:card.topAnchor constant:PPSpaceLG],
        [circle.widthAnchor constraintEqualToConstant:48.0],
        [circle.heightAnchor constraintEqualToConstant:48.0],

        [lineA.leadingAnchor constraintEqualToAnchor:circle.trailingAnchor constant:PPSpaceMD],
        [lineA.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-PPSpaceLG],
        [lineA.topAnchor constraintEqualToAnchor:card.topAnchor constant:PPSpaceLG],
        [lineA.heightAnchor constraintEqualToConstant:15.0],

        [lineB.leadingAnchor constraintEqualToAnchor:lineA.leadingAnchor],
        [lineB.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-80.0],
        [lineB.topAnchor constraintEqualToAnchor:lineA.bottomAnchor constant:10.0],
        [lineB.heightAnchor constraintEqualToConstant:12.0],

        [lineC.leadingAnchor constraintEqualToAnchor:lineA.leadingAnchor],
        [lineC.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-130.0],
        [lineC.topAnchor constraintEqualToAnchor:lineB.bottomAnchor constant:18.0],
        [lineC.heightAnchor constraintEqualToConstant:12.0],
        [lineC.bottomAnchor constraintLessThanOrEqualToAnchor:card.bottomAnchor constant:-PPSpaceLG]
    ]];

    return card;
}

- (UIView *)makeSkeletonBlockWithCornerRadius:(CGFloat)cornerRadius delay:(CFTimeInterval)delay
{
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    view.backgroundColor = [UIColor.labelColor colorWithAlphaComponent:0.075];
    PPApplyContinuousCorners(view, cornerRadius);
    if (!UIAccessibilityIsReduceMotionEnabled()) {
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"opacity"];
        animation.fromValue = @(0.42);
        animation.toValue = @(1.0);
        animation.duration = 0.86;
        animation.autoreverses = YES;
        animation.repeatCount = HUGE_VALF;
        animation.beginTime = CACurrentMediaTime() + delay;
        animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [view.layer addAnimation:animation forKey:@"pp_order_support_skeleton_opacity"];
    }
    return view;
}

- (UIView *)makeEmptyCard
{
    return [self makeStateCardWithSymbol:@"tray"
                                    tint:UIColor.secondaryLabelColor
                                   title:kLang(@"order_requests_empty_title")
                                subtitle:kLang(@"order_requests_empty_subtitle")
                             buttonTitle:nil
                                  action:nil];
}

- (UIView *)makeErrorCardWithError:(NSError *)error
{
    NSString *message = error.localizedDescription.length > 0 ? error.localizedDescription : kLang(@"unknownError");
    return [self makeStateCardWithSymbol:@"exclamationmark.triangle.fill"
                                    tint:UIColor.systemRedColor
                                   title:kLang(@"Error")
                                subtitle:message
                             buttonTitle:kLang(@"KLang_Retry")
                                  action:@selector(handleRefresh)];
}

- (UIView *)makeStateCardWithSymbol:(NSString *)symbol
                                tint:(UIColor *)tint
                               title:(NSString *)title
                            subtitle:(NSString *)subtitle
                         buttonTitle:(NSString *)buttonTitle
                              action:(SEL)action
{
    UIView *card = [[UIView alloc] initWithFrame:CGRectZero];
    PPOrderDetailsApplySurface(card, PPCornerCard, NO);
    card.layer.borderWidth = 1.0;
    [card pp_setBorderColor:[UIColor.labelColor colorWithAlphaComponent:0.06]];

    UIView *iconPlate = [[UIView alloc] initWithFrame:CGRectZero];
    iconPlate.translatesAutoresizingMaskIntoConstraints = NO;
    iconPlate.backgroundColor = [tint colorWithAlphaComponent:0.12];
    PPApplyContinuousCorners(iconPlate, 24.0);

    UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectZero];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = tint;
    iconView.contentMode = UIViewContentModeCenter;
    UIImageSymbolConfiguration *symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:25.0 weight:UIImageSymbolWeightSemibold];
    iconView.image = [[UIImage systemImageNamed:symbol withConfiguration:symbolConfig] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [iconPlate addSubview:iconView];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    titleLabel.font = PPOrderSupportListFont(UIFontTextStyleHeadline, UIFontWeightSemibold);
    titleLabel.adjustsFontForContentSizeCategory = YES;
    titleLabel.textColor = UIColor.labelColor;
    titleLabel.numberOfLines = 2;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.text = title;

    UILabel *subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    subtitleLabel.font = PPOrderSupportListFont(UIFontTextStyleSubheadline, UIFontWeightRegular);
    subtitleLabel.adjustsFontForContentSizeCategory = YES;
    subtitleLabel.textColor = UIColor.secondaryLabelColor;
    subtitleLabel.numberOfLines = 4;
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.text = subtitle;

    NSMutableArray<UIView *> *views = [NSMutableArray arrayWithArray:@[iconPlate, titleLabel, subtitleLabel]];
    UIButton *button = nil;
    if (buttonTitle.length > 0 && action) {
        button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        [button setTitle:buttonTitle forState:UIControlStateNormal];
        button.titleLabel.font = PPOrderSupportListFont(UIFontTextStyleSubheadline, UIFontWeightSemibold);
        button.titleLabel.adjustsFontForContentSizeCategory = YES;
        [button setTitleColor:PPOrderSupportListAccentColor() forState:UIControlStateNormal];
        button.backgroundColor = [PPOrderSupportListAccentColor() colorWithAlphaComponent:0.10];
        PPApplyContinuousCorners(button, 16.0);
        [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
        [views addObject:button];
    }

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:views];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = PPSpaceMD;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:PPSpaceXL],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-PPSpaceXL],
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:PPSpaceXL],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-PPSpaceXL],
        [iconPlate.widthAnchor constraintEqualToConstant:64.0],
        [iconPlate.heightAnchor constraintEqualToConstant:64.0],
        [iconView.centerXAnchor constraintEqualToAnchor:iconPlate.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconPlate.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:36.0],
        [iconView.heightAnchor constraintEqualToConstant:36.0]
    ]];

    if (button) {
        [NSLayoutConstraint activateConstraints:@[
            [button.heightAnchor constraintGreaterThanOrEqualToConstant:44.0],
            [button.widthAnchor constraintGreaterThanOrEqualToConstant:118.0]
        ]];
    }

    card.isAccessibilityElement = NO;
    return card;
}

- (PPOrderSupportRequestCardControl *)makeCardForRequest:(PPOrderSupportRequest *)request
{
    PPOrderSupportRequestCardControl *card = [[PPOrderSupportRequestCardControl alloc] initWithFrame:CGRectZero];
    [card configureWithRequest:request dateFormatter:self.dateFormatter];
    [card addTarget:self action:@selector(requestCardTapped:) forControlEvents:UIControlEventTouchUpInside];
    return card;
}

#pragma mark - Actions

- (void)requestCardTapped:(PPOrderSupportRequestCardControl *)sender
{
    NSUInteger rawIndex = [self.contentStack.arrangedSubviews indexOfObject:sender];
    if (rawIndex == NSNotFound || rawIndex == 0) {
        return;
    }
    NSInteger index = (NSInteger)rawIndex - 1;
    if (index < 0 || index >= (NSInteger)self.requests.count) {
        return;
    }
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedback impactOccurred];

    PPOrderSupportRequest *request = self.requests[index];
    UIViewController *details = [PPOrderSupportRequestDetailsViewController controllerWithOrder:self.order
                                                                                   orderManager:self.orderManager
                                                                                        request:request];
    [self.navigationController pushViewController:details animated:YES];
}

#pragma mark - Motion

- (void)playEntranceAnimationIfNeeded
{
    if (self.didPlayEntranceAnimation || UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }
    self.didPlayEntranceAnimation = YES;
    NSArray<UIView *> *views = self.contentStack.arrangedSubviews.copy;
    [views enumerateObjectsUsingBlock:^(UIView *view, NSUInteger idx, BOOL *stop) {
        (void)stop;
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0.0, 18.0);
        [UIView animateWithDuration:0.42
                              delay:0.035 * (NSTimeInterval)idx
             usingSpringWithDamping:0.86
              initialSpringVelocity:0.16
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

@end
