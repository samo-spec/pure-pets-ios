//
//  PPOrderSupportRequestDetailsViewController 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 7/14/26.
//

#import "PPOrderSupportRequestDetailsViewController.h"

@interface PPOrderSupportRequestDetailsViewController ()
@property (nonatomic, strong) PPOrder *order;
@property (nonatomic, strong) PPOrderSupportRequest *request;
@property (nonatomic, strong) PPOrderManager *orderManager;
@property (nonatomic, strong) NSArray<PPOrderTimelineEvent *> *events;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *stackView;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) id<FIRListenerRegistration> listener;
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
    self.title = [PPOrderManager displayTitleForRequestType:self.request.type];
    [self pp_orderApplyChevronBackButton];
    self.dateFormatter = [NSDateFormatter new];
    self.dateFormatter.locale = [NSLocale currentLocale];
    [self.dateFormatter setLocalizedDateFormatFromTemplate:@"EEE d MMM yyyy h:mm a"];

    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.scrollView];

    self.stackView = [[UIStackView alloc] initWithFrame:CGRectZero];
    self.stackView.axis = UILayoutConstraintAxisVertical;
    self.stackView.spacing = PPSpaceMD;
    self.stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.stackView];

    [NSLayoutConstraint activateConstraints:@[
        [self.stackView.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor constant:kOrderDetailsScreenMargin],
        [self.stackView.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor constant:-kOrderDetailsScreenMargin],
        [self.stackView.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:PPSpaceBase],
        [self.stackView.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-PPSpaceXL],
        [self.stackView.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor constant:-(kOrderDetailsScreenMargin * 2.0)]
    ]];

    [self reloadContent];

    __weak typeof(self) weakSelf = self;
    self.listener = [self.orderManager listenToRequestEventsForOrderID:self.order.orderId
                                                              requestID:self.request.requestId
                                                                 update:^(NSArray<PPOrderTimelineEvent *> *events, NSError * _Nullable __unused error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.events = events ?: @[];
            [strongSelf reloadContent];
        });
    }];
}

- (void)dealloc
{
    [self.listener remove];
}

- (UIView *)cardViewWithTitle:(NSString *)title value:(NSString *)value tintColor:(UIColor *)tintColor
{
    UIView *card = [[UIView alloc] initWithFrame:CGRectZero];
    PPOrderDetailsApplySurface(card, PPCornerCard, NO);

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM MidFontWithSize:13];
    titleLabel.textColor = UIColor.secondaryLabelColor;
    titleLabel.text = title;

    UILabel *valueLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    valueLabel.font = [GM boldFontWithSize:16];
    valueLabel.textColor = tintColor ?: UIColor.labelColor;
    valueLabel.numberOfLines = 0;
    valueLabel.text = value;

    [card addSubview:titleLabel];
    [card addSubview:valueLabel];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:PPSpaceBase],
        [titleLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-PPSpaceBase],
        [titleLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:PPSpaceBase],
        [valueLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:PPSpaceBase],
        [valueLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-PPSpaceBase],
        [valueLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8],
        [valueLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-PPSpaceBase]
    ]];

    return card;
}

- (void)reloadContent
{
    for (UIView *view in self.stackView.arrangedSubviews) {
        [self.stackView removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    UIColor *statusColor = PPOrderRequestStatusColor(self.request.status);
    [self.stackView addArrangedSubview:[self cardViewWithTitle:kLang(@"order_request_status_title")
                                                         value:[PPOrderManager displayTitleForRequestStatus:self.request.status]
                                                     tintColor:statusColor]];

    NSString *reasonText = self.request.reasonTitle.length > 0 ? self.request.reasonTitle : self.request.reasonCode;
    [self.stackView addArrangedSubview:[self cardViewWithTitle:kLang(@"order_request_reason_title")
                                                         value:reasonText.length > 0 ? reasonText : kLang(@"order_reason_other_title")
                                                     tintColor:UIColor.labelColor]];

    NSString *dateText = self.request.createdAt ? [self.dateFormatter stringFromDate:self.request.createdAt] : @"--";
    [self.stackView addArrangedSubview:[self cardViewWithTitle:kLang(@"OrderDate")
                                                         value:dateText
                                                     tintColor:UIColor.labelColor]];

    if (self.request.notes.length > 0) {
        [self.stackView addArrangedSubview:[self cardViewWithTitle:kLang(@"order_request_notes_title")
                                                             value:self.request.notes
                                                         tintColor:UIColor.labelColor]];
    }

    if (self.request.itemSnapshots.count > 0 || self.request.itemIDs.count > 0) {
        NSMutableArray<NSString *> *lines = [NSMutableArray array];
        for (NSDictionary *item in self.request.itemSnapshots) {
            NSString *name = [item[@"name"] isKindOfClass:NSString.class] ? item[@"name"] : @"";
            NSInteger qty = [item[@"quantity"] ?: item[@"qty"] integerValue];
            [lines addObject:[NSString stringWithFormat:@"%@ ×%ld", name.length > 0 ? name : (item[@"itemId"] ?: @"Item"), (long)MAX(1, qty)]];
        }
        if (lines.count == 0) {
            [lines addObjectsFromArray:self.request.itemIDs];
        }
        [self.stackView addArrangedSubview:[self cardViewWithTitle:kLang(@"order_request_items_title")
                                                             value:[lines componentsJoinedByString:@"\n"]
                                                         tintColor:UIColor.labelColor]];
    }

    if (self.request.attachments.count > 0) {
        UIView *card = [self cardViewWithTitle:kLang(@"order_request_attachments_title")
                                         value:@""
                                     tintColor:UIColor.labelColor];
        UIStackView *imageStack = [[UIStackView alloc] initWithFrame:CGRectZero];
        imageStack.axis = UILayoutConstraintAxisHorizontal;
        imageStack.spacing = 8.0;
        imageStack.translatesAutoresizingMaskIntoConstraints = NO;
        [card addSubview:imageStack];

        for (PPOrderSupportAttachment *attachment in self.request.attachments) {
            UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 72, 72)];
            imageView.layer.cornerRadius = 12.0;
            imageView.layer.masksToBounds = YES;
            imageView.contentMode = UIViewContentModeScaleAspectFill;
            imageView.translatesAutoresizingMaskIntoConstraints = NO;
            [GM setImageFromUrlString:attachment.attachmentURL imageView:imageView phImage:@"placeholder"];
            [NSLayoutConstraint activateConstraints:@[
                [imageView.widthAnchor constraintEqualToConstant:72],
                [imageView.heightAnchor constraintEqualToConstant:72]
            ]];
            [imageStack addArrangedSubview:imageView];
        }

        [NSLayoutConstraint activateConstraints:@[
            [imageStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
            [imageStack.trailingAnchor constraintLessThanOrEqualToAnchor:card.trailingAnchor constant:-16],
            [imageStack.topAnchor constraintEqualToAnchor:card.topAnchor constant:50],
            [imageStack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14]
        ]];
        [self.stackView addArrangedSubview:card];
    }

    NSArray<PPOrderTimelineEvent *> *events = self.events;
    if (events.count == 0) {
        events = @[];
    }
    if (events.count > 0) {
        UIView *card = [self cardViewWithTitle:kLang(@"order_request_timeline_title")
                                         value:@""
                                     tintColor:UIColor.labelColor];
        UIStackView *timelineStack = [[UIStackView alloc] initWithFrame:CGRectZero];
        timelineStack.axis = UILayoutConstraintAxisVertical;
        timelineStack.spacing = 10.0;
        timelineStack.translatesAutoresizingMaskIntoConstraints = NO;
        [card addSubview:timelineStack];

        for (PPOrderTimelineEvent *event in events) {
            UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
            label.numberOfLines = 0;
            label.font = [GM MidFontWithSize:14];
            label.textColor = UIColor.labelColor;
            NSString *dateTextLine = event.createdAt ? [self.dateFormatter stringFromDate:event.createdAt] : @"";
            label.text = [NSString stringWithFormat:@"%@\n%@", PPOrderTimelineTitle(event), dateTextLine.length > 0 ? dateTextLine : PPOrderTimelineSubtitle(event)];
            [timelineStack addArrangedSubview:label];
        }

        [NSLayoutConstraint activateConstraints:@[
            [timelineStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
            [timelineStack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
            [timelineStack.topAnchor constraintEqualToAnchor:card.topAnchor constant:50],
            [timelineStack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14]
        ]];
        [self.stackView addArrangedSubview:card];
    }
}

@end
