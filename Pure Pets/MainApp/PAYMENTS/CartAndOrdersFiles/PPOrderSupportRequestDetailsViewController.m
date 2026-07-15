//
//  PPOrderSupportRequestDetailsViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 7/14/26.
//

#import "PPOrderSupportRequestDetailsViewController.h"
#import "PPOrder.h"
#import "PPOrderManager.h"
#import "OrderSupportFunc.h"

static CGFloat const PPOrderSupportDetailsBottomComfortInset = 104.0;
static CGFloat const PPOrderSupportDetailsAttachmentSize = 82.0;

static CGFloat PPOrderSupportDetailsBaseFontSize(UIFontTextStyle textStyle)
{
    if ([textStyle isEqualToString:UIFontTextStyleTitle2]) {
        return 22.0;
    }
    if ([textStyle isEqualToString:UIFontTextStyleTitle3]) {
        return 20.0;
    }
    if ([textStyle isEqualToString:UIFontTextStyleHeadline]) {
        return 17.0;
    }
    if ([textStyle isEqualToString:UIFontTextStyleBody]) {
        return 16.0;
    }
    if ([textStyle isEqualToString:UIFontTextStyleSubheadline]) {
        return 15.0;
    }
    if ([textStyle isEqualToString:UIFontTextStyleFootnote]) {
        return 13.0;
    }
    if ([textStyle isEqualToString:UIFontTextStyleCaption1]) {
        return 12.0;
    }
    return 15.0;
}

static UIFont *PPOrderSupportDetailsFont(UIFontTextStyle textStyle, UIFontWeight weight)
{
    CGFloat size = PPOrderSupportDetailsBaseFontSize(textStyle);
    BOOL emphasized = weight >= UIFontWeightSemibold;
    UIFont *font = emphasized ? [GM boldFontWithSize:size] : [GM MidFontWithSize:size];
    return [[UIFontMetrics metricsForTextStyle:textStyle] scaledFontForFont:font];
}

static UIColor *PPOrderSupportDetailsAccentColor(void)
{
    return AppPrimaryClr ?: UIColor.systemOrangeColor;
}

static NSString *PPOrderSupportDetailsCleanText(NSString *text, NSString *fallback)
{
    if ([text isKindOfClass:NSString.class] && text.length > 0) {
        return text;
    }
    return fallback ?: @"";
}

static NSString *PPOrderSupportDetailsDateString(NSDateFormatter *formatter, NSDate *date)
{
    if (!date) {
        return @"";
    }
    return [formatter stringFromDate:date] ?: @"";
}

@interface PPOrderSupportDetailsInsetLabel : UILabel
@property (nonatomic, assign) UIEdgeInsets contentInsets;
@end

@implementation PPOrderSupportDetailsInsetLabel

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _contentInsets = UIEdgeInsetsMake(6.0, 11.0, 6.0, 11.0);
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

@interface PPOrderSupportRequestDetailsViewController ()
@property (nonatomic, strong) PPOrder *order;
@property (nonatomic, strong) PPOrderSupportRequest *request;
@property (nonatomic, strong) PPOrderManager *orderManager;
@property (nonatomic, strong) NSArray<PPOrderTimelineEvent *> *events;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) NSError *eventsError;
@property (nonatomic, strong) id<FIRListenerRegistration> listener;
@property (nonatomic, assign) BOOL isLoadingEvents;
@property (nonatomic, assign) BOOL didPlayEntranceAnimation;
@end

@implementation PPOrderSupportRequestDetailsViewController

+ (instancetype)controllerWithOrder:(PPOrder *)order
                       orderManager:(PPOrderManager *)orderManager
                            request:(PPOrderSupportRequest *)request
{
    PPOrderSupportRequestDetailsViewController *vc = [PPOrderSupportRequestDetailsViewController new];
    vc.order = order;
    vc.orderManager = orderManager ?: [PPOrderManager shared];
    vc.request = request;
    return vc;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.title = [PPOrderManager displayTitleForRequestType:self.request.type];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    [self pp_orderApplyChevronBackButton];

    self.dateFormatter = [NSDateFormatter new];
    self.dateFormatter.locale = [NSLocale currentLocale];
    [self.dateFormatter setLocalizedDateFormatFromTemplate:@"EEE d MMM yyyy h:mm a"];

    self.events = @[];
    self.isLoadingEvents = YES;
    [self buildScrollLayout];
    [self reloadContentAnimated:NO];
    [self beginListeningForEvents];
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
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.scrollView.backgroundColor = UIColor.clearColor;
    self.scrollView.contentInset = UIEdgeInsetsMake(0.0, 0.0, PPOrderSupportDetailsBottomComfortInset, 0.0);
    self.scrollView.scrollIndicatorInsets = self.scrollView.contentInset;
    [self.view addSubview:self.scrollView];

    self.contentStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = PPSpaceMD;
    self.contentStack.alignment = UIStackViewAlignmentFill;
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentStack];

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

- (void)beginListeningForEvents
{
    if (self.order.orderId.length == 0 || self.request.requestId.length == 0) {
        self.isLoadingEvents = NO;
        [self reloadContentAnimated:YES];
        return;
    }

    __weak typeof(self) weakSelf = self;
    self.listener = [self.orderManager listenToRequestEventsForOrderID:self.order.orderId
                                                              requestID:self.request.requestId
                                                                 update:^(NSArray<PPOrderTimelineEvent *> *events, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            strongSelf.isLoadingEvents = NO;
            strongSelf.eventsError = error;
            if (!error) {
                strongSelf.events = events ?: @[];
            }
            [strongSelf reloadContentAnimated:YES];
        });
    }];
}

- (void)refreshEvents
{
    if (self.order.orderId.length == 0 || self.request.requestId.length == 0) {
        return;
    }
    self.isLoadingEvents = YES;
    self.eventsError = nil;
    [self reloadContentAnimated:YES];

    __weak typeof(self) weakSelf = self;
    [self.orderManager fetchRequestEventsForOrderID:self.order.orderId
                                          requestID:self.request.requestId
                                         completion:^(NSArray<PPOrderTimelineEvent *> *events, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            strongSelf.isLoadingEvents = NO;
            strongSelf.eventsError = error;
            if (!error) {
                strongSelf.events = events ?: @[];
            }
            [strongSelf reloadContentAnimated:YES];
        });
    }];
}

#pragma mark - Rendering

- (void)reloadContentAnimated:(BOOL)animated
{
    void (^renderBlock)(void) = ^{
        [self clearContentStack];
        if (!self.request) {
            [self.contentStack addArrangedSubview:[self makeStateCardWithSymbol:@"exclamationmark.triangle.fill"
                                                                            tint:UIColor.systemRedColor
                                                                           title:kLang(@"Error")
                                                                        subtitle:kLang(@"unknownError")
                                                                     buttonTitle:nil
                                                                          action:nil]];
            return;
        }

        [self.contentStack addArrangedSubview:[self makeHeroCard]];

        if (self.request.notes.length > 0) {
            [self.contentStack addArrangedSubview:[self makeNotesSection]];
        }

        if (self.request.itemSnapshots.count > 0 || self.request.itemIDs.count > 0) {
            [self.contentStack addArrangedSubview:[self makeItemsSection]];
        }

        if (self.request.attachments.count > 0) {
            [self.contentStack addArrangedSubview:[self makeAttachmentsSection]];
        }

        [self.contentStack addArrangedSubview:[self makeTimelineSection]];
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

- (UIView *)makeHeroCard
{
    UIColor *statusColor = PPOrderRequestStatusColor(self.request.status) ?: PPOrderSupportDetailsAccentColor();
    NSString *typeTitle = [PPOrderManager displayTitleForRequestType:self.request.type];
    NSString *statusTitle = [PPOrderManager displayTitleForRequestStatus:self.request.status];
    NSString *reasonText = [self requestReasonText];
    NSString *createdDate = PPOrderSupportDetailsDateString(self.dateFormatter, self.request.submittedAt ?: self.request.createdAt);
    NSString *updatedDate = PPOrderSupportDetailsDateString(self.dateFormatter, self.request.updatedAt);

    UIView *card = [[UIView alloc] initWithFrame:CGRectZero];
    PPOrderDetailsApplySurface(card, PPCornerCard + 6.0, YES);
    card.layer.borderWidth = 1.0;
    [card pp_setBorderColor:[UIColor.labelColor colorWithAlphaComponent:0.065]];

    UIView *iconPlate = [[UIView alloc] initWithFrame:CGRectZero];
    iconPlate.translatesAutoresizingMaskIntoConstraints = NO;
    iconPlate.backgroundColor = [statusColor colorWithAlphaComponent:0.12];
    PPApplyContinuousCorners(iconPlate, 24.0);

    UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectZero];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = statusColor;
    iconView.contentMode = UIViewContentModeCenter;
    UIImageSymbolConfiguration *heroSymbol = [UIImageSymbolConfiguration configurationWithPointSize:25.0 weight:UIImageSymbolWeightSemibold];
    iconView.image = [[UIImage systemImageNamed:@"doc.text.magnifyingglass" withConfiguration:heroSymbol] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [iconPlate addSubview:iconView];

    UILabel *titleLabel = [self makeLabelWithText:typeTitle
                                        textStyle:UIFontTextStyleTitle2
                                           weight:UIFontWeightBold
                                            color:UIColor.labelColor
                                            lines:3];

    UILabel *reasonLabel = [self makeLabelWithText:reasonText
                                         textStyle:UIFontTextStyleSubheadline
                                            weight:UIFontWeightRegular
                                             color:UIColor.secondaryLabelColor
                                             lines:3];

    UIStackView *titleStack = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, reasonLabel]];
    titleStack.axis = UILayoutConstraintAxisVertical;
    titleStack.spacing = 6.0;

    UIStackView *headerStack = [[UIStackView alloc] initWithArrangedSubviews:@[iconPlate, titleStack]];
    headerStack.axis = UILayoutConstraintAxisHorizontal;
    headerStack.alignment = UIStackViewAlignmentCenter;
    headerStack.spacing = PPSpaceMD;
    headerStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    PPOrderSupportDetailsInsetLabel *statusPill = [self makePillWithText:statusTitle tint:statusColor];

    NSMutableArray<UIView *> *dateRows = [NSMutableArray array];
    if (createdDate.length > 0) {
        [dateRows addObject:[self makeInfoRowWithTitle:kLang(@"OrderDate")
                                                 detail:createdDate
                                                 symbol:@"calendar"
                                                   tint:PPOrderSupportDetailsAccentColor()]];
    }
    if (updatedDate.length > 0 && ![updatedDate isEqualToString:createdDate]) {
        [dateRows addObject:[self makeInfoRowWithTitle:kLang(@"order_request_timeline_updated")
                                                 detail:updatedDate
                                                 symbol:@"clock.arrow.circlepath"
                                                   tint:statusColor]];
    }

    UIStackView *dateStack = [[UIStackView alloc] initWithArrangedSubviews:dateRows];
    dateStack.axis = UILayoutConstraintAxisVertical;
    dateStack.spacing = 10.0;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[headerStack, statusPill, dateStack]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = Language.isRTL ? UIStackViewAlignmentTrailing : UIStackViewAlignmentLeading;
    stack.spacing = PPSpaceLG;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:PPSpaceLG],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-PPSpaceLG],
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:PPSpaceLG],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-PPSpaceLG],
        [iconPlate.widthAnchor constraintEqualToConstant:66.0],
        [iconPlate.heightAnchor constraintEqualToConstant:66.0],
        [iconView.centerXAnchor constraintEqualToAnchor:iconPlate.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconPlate.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:38.0],
        [iconView.heightAnchor constraintEqualToConstant:38.0],
        [headerStack.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
        [dateStack.widthAnchor constraintEqualToAnchor:stack.widthAnchor]
    ]];

    [titleStack setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    card.isAccessibilityElement = NO;
    return card;
}

- (UIView *)makeNotesSection
{
    UILabel *label = [self makeLabelWithText:self.request.notes
                                   textStyle:UIFontTextStyleBody
                                      weight:UIFontWeightRegular
                                       color:UIColor.labelColor
                                       lines:0];
    return [self makeSectionCardWithTitle:kLang(@"order_request_notes_title")
                                   symbol:@"text.alignleft"
                                     tint:PPOrderSupportDetailsAccentColor()
                              contentViews:@[label]];
}

- (UIView *)makeItemsSection
{
    NSMutableArray<UIView *> *rows = [NSMutableArray array];
    for (NSDictionary *item in self.request.itemSnapshots) {
        NSString *name = [item[@"name"] isKindOfClass:NSString.class] ? item[@"name"] : @"";
        NSString *itemID = [item[@"itemId"] isKindOfClass:NSString.class] ? item[@"itemId"] : @"";
        NSInteger quantity = [item[@"quantity"] ?: item[@"qty"] integerValue];
        NSString *title = PPOrderSupportDetailsCleanText(name, PPOrderSupportDetailsCleanText(itemID, kLang(@"order_request_items_title")));
        NSString *detail = [NSString stringWithFormat:@"x%ld", (long)MAX(1, quantity)];
        [rows addObject:[self makeInfoRowWithTitle:title
                                            detail:detail
                                            symbol:@"shippingbox"
                                              tint:PPOrderSupportDetailsAccentColor()]];
    }

    if (rows.count == 0) {
        for (NSString *itemID in self.request.itemIDs) {
            [rows addObject:[self makeInfoRowWithTitle:kLang(@"order_request_items_title")
                                                detail:itemID
                                                symbol:@"shippingbox"
                                                  tint:PPOrderSupportDetailsAccentColor()]];
        }
    }

    return [self makeSectionCardWithTitle:kLang(@"order_request_items_title")
                                   symbol:@"shippingbox.fill"
                                     tint:PPOrderSupportDetailsAccentColor()
                              contentViews:rows];
}

- (UIView *)makeAttachmentsSection
{
    UIScrollView *scroller = [[UIScrollView alloc] initWithFrame:CGRectZero];
    scroller.translatesAutoresizingMaskIntoConstraints = NO;
    scroller.showsHorizontalScrollIndicator = NO;
    scroller.alwaysBounceHorizontal = YES;
    scroller.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    UIStackView *imageStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    imageStack.axis = UILayoutConstraintAxisHorizontal;
    imageStack.alignment = UIStackViewAlignmentCenter;
    imageStack.spacing = 10.0;
    imageStack.translatesAutoresizingMaskIntoConstraints = NO;
    [scroller addSubview:imageStack];

    for (PPOrderSupportAttachment *attachment in self.request.attachments) {
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        imageView.translatesAutoresizingMaskIntoConstraints = NO;
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.clipsToBounds = YES;
        imageView.backgroundColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.10];
        PPApplyContinuousCorners(imageView, 18.0);
        [GM setImageFromUrlString:attachment.attachmentURL imageView:imageView phImage:@"placeholder"];
        imageView.isAccessibilityElement = YES;
        imageView.accessibilityLabel = PPOrderSupportDetailsCleanText(attachment.fileName, kLang(@"order_request_attachments_title"));
        [NSLayoutConstraint activateConstraints:@[
            [imageView.widthAnchor constraintEqualToConstant:PPOrderSupportDetailsAttachmentSize],
            [imageView.heightAnchor constraintEqualToConstant:PPOrderSupportDetailsAttachmentSize]
        ]];
        [imageStack addArrangedSubview:imageView];
    }

    [NSLayoutConstraint activateConstraints:@[
        [scroller.heightAnchor constraintEqualToConstant:PPOrderSupportDetailsAttachmentSize],
        [imageStack.leadingAnchor constraintEqualToAnchor:scroller.contentLayoutGuide.leadingAnchor],
        [imageStack.trailingAnchor constraintEqualToAnchor:scroller.contentLayoutGuide.trailingAnchor],
        [imageStack.topAnchor constraintEqualToAnchor:scroller.contentLayoutGuide.topAnchor],
        [imageStack.bottomAnchor constraintEqualToAnchor:scroller.contentLayoutGuide.bottomAnchor],
        [imageStack.heightAnchor constraintEqualToAnchor:scroller.frameLayoutGuide.heightAnchor]
    ]];

    return [self makeSectionCardWithTitle:kLang(@"order_request_attachments_title")
                                   symbol:@"paperclip"
                                     tint:PPOrderSupportDetailsAccentColor()
                              contentViews:@[scroller]];
}

- (UIView *)makeTimelineSection
{
    NSMutableArray<UIView *> *rows = [NSMutableArray array];
    if (self.isLoadingEvents) {
        [rows addObject:[self makeTimelineSkeletonRowWithDelay:0.0]];
        [rows addObject:[self makeTimelineSkeletonRowWithDelay:0.08]];
    } else if (self.eventsError) {
        [rows addObject:[self makeInlineErrorRowWithError:self.eventsError]];
    } else if (self.events.count > 0) {
        for (PPOrderTimelineEvent *event in self.events) {
            [rows addObject:[self makeTimelineRowForEvent:event]];
        }
    } else {
        [rows addObject:[self makeFallbackTimelineRow]];
    }

    return [self makeSectionCardWithTitle:kLang(@"order_request_timeline_title")
                                   symbol:@"clock.arrow.circlepath"
                                     tint:PPOrderSupportDetailsAccentColor()
                              contentViews:rows];
}

- (UIView *)makeSectionCardWithTitle:(NSString *)title
                               symbol:(NSString *)symbol
                                 tint:(UIColor *)tint
                          contentViews:(NSArray<UIView *> *)contentViews
{
    UIView *card = [[UIView alloc] initWithFrame:CGRectZero];
    PPOrderDetailsApplySurface(card, PPCornerCard, NO);
    card.layer.borderWidth = 1.0;
    [card pp_setBorderColor:[UIColor.labelColor colorWithAlphaComponent:0.055]];

    UIView *iconPlate = [[UIView alloc] initWithFrame:CGRectZero];
    iconPlate.translatesAutoresizingMaskIntoConstraints = NO;
    iconPlate.backgroundColor = [tint colorWithAlphaComponent:0.10];
    PPApplyContinuousCorners(iconPlate, 15.0);

    UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectZero];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = tint;
    iconView.contentMode = UIViewContentModeCenter;
    UIImageSymbolConfiguration *symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:16.0 weight:UIImageSymbolWeightSemibold];
    iconView.image = [[UIImage systemImageNamed:symbol withConfiguration:symbolConfig] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [iconPlate addSubview:iconView];

    UILabel *titleLabel = [self makeLabelWithText:title
                                        textStyle:UIFontTextStyleHeadline
                                           weight:UIFontWeightSemibold
                                            color:UIColor.labelColor
                                            lines:2];

    UIStackView *header = [[UIStackView alloc] initWithArrangedSubviews:@[iconPlate, titleLabel]];
    header.axis = UILayoutConstraintAxisHorizontal;
    header.alignment = UIStackViewAlignmentCenter;
    header.spacing = 10.0;
    header.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    UIStackView *bodyStack = [[UIStackView alloc] initWithArrangedSubviews:contentViews];
    bodyStack.axis = UILayoutConstraintAxisVertical;
    bodyStack.spacing = 12.0;

    UIStackView *outer = [[UIStackView alloc] initWithArrangedSubviews:@[header, bodyStack]];
    outer.axis = UILayoutConstraintAxisVertical;
    outer.spacing = PPSpaceMD;
    outer.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:outer];

    [NSLayoutConstraint activateConstraints:@[
        [outer.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:PPSpaceLG],
        [outer.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-PPSpaceLG],
        [outer.topAnchor constraintEqualToAnchor:card.topAnchor constant:PPSpaceLG],
        [outer.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-PPSpaceLG],
        [iconPlate.widthAnchor constraintEqualToConstant:32.0],
        [iconPlate.heightAnchor constraintEqualToConstant:32.0],
        [iconView.centerXAnchor constraintEqualToAnchor:iconPlate.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconPlate.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:22.0],
        [iconView.heightAnchor constraintEqualToConstant:22.0]
    ]];

    card.isAccessibilityElement = NO;
    return card;
}

- (UIView *)makeInfoRowWithTitle:(NSString *)title detail:(NSString *)detail symbol:(NSString *)symbol tint:(UIColor *)tint
{
    UIView *row = [[UIView alloc] initWithFrame:CGRectZero];

    UIView *iconPlate = [[UIView alloc] initWithFrame:CGRectZero];
    iconPlate.translatesAutoresizingMaskIntoConstraints = NO;
    iconPlate.backgroundColor = [tint colorWithAlphaComponent:0.10];
    PPApplyContinuousCorners(iconPlate, 14.0);

    UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectZero];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = tint;
    iconView.contentMode = UIViewContentModeCenter;
    UIImageSymbolConfiguration *symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:15.0 weight:UIImageSymbolWeightMedium];
    iconView.image = [[UIImage systemImageNamed:symbol withConfiguration:symbolConfig] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [iconPlate addSubview:iconView];

    UILabel *titleLabel = [self makeLabelWithText:title
                                        textStyle:UIFontTextStyleFootnote
                                           weight:UIFontWeightMedium
                                            color:UIColor.secondaryLabelColor
                                            lines:2];
    UILabel *detailLabel = [self makeLabelWithText:detail
                                         textStyle:UIFontTextStyleSubheadline
                                            weight:UIFontWeightSemibold
                                             color:UIColor.labelColor
                                             lines:3];
    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, detailLabel]];
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = 3.0;

    UIStackView *rowStack = [[UIStackView alloc] initWithArrangedSubviews:@[iconPlate, textStack]];
    rowStack.axis = UILayoutConstraintAxisHorizontal;
    rowStack.alignment = UIStackViewAlignmentCenter;
    rowStack.spacing = 11.0;
    rowStack.translatesAutoresizingMaskIntoConstraints = NO;
    rowStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [row addSubview:rowStack];

    [NSLayoutConstraint activateConstraints:@[
        [rowStack.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [rowStack.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [rowStack.topAnchor constraintEqualToAnchor:row.topAnchor],
        [rowStack.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
        [iconPlate.widthAnchor constraintEqualToConstant:34.0],
        [iconPlate.heightAnchor constraintEqualToConstant:34.0],
        [iconView.centerXAnchor constraintEqualToAnchor:iconPlate.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconPlate.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:22.0],
        [iconView.heightAnchor constraintEqualToConstant:22.0]
    ]];

    [textStack setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    row.isAccessibilityElement = YES;
    row.accessibilityLabel = [[@[title ?: @"", detail ?: @""] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *text, NSDictionary *bindings) {
        (void)bindings;
        return text.length > 0;
    }]] componentsJoinedByString:@", "];
    return row;
}

- (UIView *)makeTimelineRowForEvent:(PPOrderTimelineEvent *)event
{
    UIColor *tint = PPOrderRequestStatusColor(event.status) ?: PPOrderSupportDetailsAccentColor();
    NSString *title = PPOrderTimelineTitle(event);
    NSString *date = PPOrderSupportDetailsDateString(self.dateFormatter, event.createdAt);
    NSString *subtitle = PPOrderTimelineSubtitle(event);
    NSMutableArray<NSString *> *detailParts = [NSMutableArray array];
    if (date.length > 0) {
        [detailParts addObject:date];
    }
    if (subtitle.length > 0 && ![subtitle isEqualToString:title]) {
        [detailParts addObject:subtitle];
    }
    NSString *detail = detailParts.count > 0 ? [detailParts componentsJoinedByString:@"\n"] : @"";

    return [self makeInfoRowWithTitle:title
                                detail:detail
                                symbol:@"circle.fill"
                                  tint:tint];
}

- (UIView *)makeFallbackTimelineRow
{
    NSString *date = PPOrderSupportDetailsDateString(self.dateFormatter, self.request.submittedAt ?: self.request.createdAt);
    NSString *detail = PPOrderSupportDetailsCleanText(date, [PPOrderManager displayTitleForRequestStatus:self.request.status]);
    return [self makeInfoRowWithTitle:kLang(@"order_request_timeline_submitted")
                                detail:detail
                                symbol:@"paperplane.fill"
                                  tint:PPOrderSupportDetailsAccentColor()];
}

- (UIView *)makeTimelineSkeletonRowWithDelay:(CFTimeInterval)delay
{
    UIView *row = [[UIView alloc] initWithFrame:CGRectZero];
    UIView *dot = [self makeSkeletonBlockWithCornerRadius:15.0 delay:delay];
    UIView *lineA = [self makeSkeletonBlockWithCornerRadius:6.0 delay:delay + 0.04];
    UIView *lineB = [self makeSkeletonBlockWithCornerRadius:5.0 delay:delay + 0.08];
    for (UIView *view in @[dot, lineA, lineB]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [row addSubview:view];
    }

    [NSLayoutConstraint activateConstraints:@[
        [dot.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [dot.topAnchor constraintEqualToAnchor:row.topAnchor constant:2.0],
        [dot.widthAnchor constraintEqualToConstant:30.0],
        [dot.heightAnchor constraintEqualToConstant:30.0],
        [lineA.leadingAnchor constraintEqualToAnchor:dot.trailingAnchor constant:12.0],
        [lineA.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-28.0],
        [lineA.topAnchor constraintEqualToAnchor:row.topAnchor constant:4.0],
        [lineA.heightAnchor constraintEqualToConstant:12.0],
        [lineB.leadingAnchor constraintEqualToAnchor:lineA.leadingAnchor],
        [lineB.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-78.0],
        [lineB.topAnchor constraintEqualToAnchor:lineA.bottomAnchor constant:10.0],
        [lineB.heightAnchor constraintEqualToConstant:10.0],
        [lineB.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-2.0]
    ]];
    return row;
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
        [view.layer addAnimation:animation forKey:@"pp_order_support_detail_skeleton_opacity"];
    }
    return view;
}

- (UIView *)makeInlineErrorRowWithError:(NSError *)error
{
    UIView *row = [[UIView alloc] initWithFrame:CGRectZero];

    UILabel *titleLabel = [self makeLabelWithText:kLang(@"Error")
                                        textStyle:UIFontTextStyleSubheadline
                                           weight:UIFontWeightSemibold
                                            color:UIColor.labelColor
                                            lines:2];
    UILabel *detailLabel = [self makeLabelWithText:(error.localizedDescription.length > 0 ? error.localizedDescription : kLang(@"unknownError"))
                                         textStyle:UIFontTextStyleFootnote
                                            weight:UIFontWeightRegular
                                             color:UIColor.secondaryLabelColor
                                             lines:3];

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button setTitle:kLang(@"KLang_Retry") forState:UIControlStateNormal];
    button.titleLabel.font = PPOrderSupportDetailsFont(UIFontTextStyleSubheadline, UIFontWeightSemibold);
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    [button setTitleColor:PPOrderSupportDetailsAccentColor() forState:UIControlStateNormal];
    button.backgroundColor = [PPOrderSupportDetailsAccentColor() colorWithAlphaComponent:0.10];
    PPApplyContinuousCorners(button, 16.0);
    [button addTarget:self action:@selector(refreshEvents) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, detailLabel, button]];
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.alignment = Language.isRTL ? UIStackViewAlignmentTrailing : UIStackViewAlignmentLeading;
    textStack.spacing = 8.0;
    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:textStack];

    [NSLayoutConstraint activateConstraints:@[
        [textStack.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [textStack.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [textStack.topAnchor constraintEqualToAnchor:row.topAnchor],
        [textStack.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
        [button.heightAnchor constraintGreaterThanOrEqualToConstant:42.0],
        [button.widthAnchor constraintGreaterThanOrEqualToConstant:116.0]
    ]];

    return row;
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
    UIImageSymbolConfiguration *symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:25.0 weight:UIImageSymbolWeightSemibold];
    iconView.image = [[UIImage systemImageNamed:symbol withConfiguration:symbolConfig] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [iconPlate addSubview:iconView];

    UILabel *titleLabel = [self makeLabelWithText:title textStyle:UIFontTextStyleHeadline weight:UIFontWeightSemibold color:UIColor.labelColor lines:2];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    UILabel *subtitleLabel = [self makeLabelWithText:subtitle textStyle:UIFontTextStyleSubheadline weight:UIFontWeightRegular color:UIColor.secondaryLabelColor lines:4];
    subtitleLabel.textAlignment = NSTextAlignmentCenter;

    NSMutableArray<UIView *> *views = [NSMutableArray arrayWithArray:@[iconPlate, titleLabel, subtitleLabel]];
    UIButton *button = nil;
    if (buttonTitle.length > 0 && action) {
        button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        [button setTitle:buttonTitle forState:UIControlStateNormal];
        button.titleLabel.font = PPOrderSupportDetailsFont(UIFontTextStyleSubheadline, UIFontWeightSemibold);
        button.titleLabel.adjustsFontForContentSizeCategory = YES;
        [button setTitleColor:PPOrderSupportDetailsAccentColor() forState:UIControlStateNormal];
        button.backgroundColor = [PPOrderSupportDetailsAccentColor() colorWithAlphaComponent:0.10];
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

    return card;
}

#pragma mark - Helpers

- (NSString *)requestReasonText
{
    NSString *reason = PPOrderSupportDetailsCleanText(self.request.subject, nil);
    if (reason.length == 0) {
        reason = PPOrderSupportDetailsCleanText(self.request.reasonTitle, self.request.reasonCode);
    }
    if (reason.length == 0) {
        reason = kLang(@"order_reason_other_title");
    }
    return reason;
}

- (UILabel *)makeLabelWithText:(NSString *)text
                      textStyle:(UIFontTextStyle)textStyle
                         weight:(UIFontWeight)weight
                          color:(UIColor *)color
                          lines:(NSInteger)lines
{
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.font = PPOrderSupportDetailsFont(textStyle, weight);
    label.adjustsFontForContentSizeCategory = YES;
    label.textColor = color ?: UIColor.labelColor;
    label.numberOfLines = lines;
    label.text = text;
    label.textAlignment = Language.isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    return label;
}

- (PPOrderSupportDetailsInsetLabel *)makePillWithText:(NSString *)text tint:(UIColor *)tint
{
    PPOrderSupportDetailsInsetLabel *label = [[PPOrderSupportDetailsInsetLabel alloc] initWithFrame:CGRectZero];
    label.font = PPOrderSupportDetailsFont(UIFontTextStyleCaption1, UIFontWeightSemibold);
    label.adjustsFontForContentSizeCategory = YES;
    label.textColor = tint;
    label.backgroundColor = [tint colorWithAlphaComponent:0.12];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 1;
    label.text = text;
    PPApplyContinuousCorners(label, 15.0);
    label.clipsToBounds = YES;
    [label setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    return label;
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
