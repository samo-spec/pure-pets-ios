//
//  OrderDetailsViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 04/07/2025.
//

#import "OrderDetailsViewController.h"
#import "OrderItemCell.h"
#import "AccessViewerVC.h"
#import "PetAccessoryManager.h"
#import "PPOrderManager.h"
#import "PPFulfillmentOrder.h"
#import "PPAddressesManager.h"
#import "AddressFormVC.h"
#import "AppClasses.h"
#import "PPAlertHelper.h"
#import "UserManager.h"
#import "ChManager.h"
#import "PPSelectOptionViewController.h"
#import "CountryModel.h"
#import "CartManager.h"
#import "PPHomeViewController.h"
#import "Styling.h"
#import "PPFirebaseSessionBridge.h"
#import <AudioToolbox/AudioToolbox.h>
#import <math.h>
@import FirebaseFirestore;
@import FirebaseAuth;
@import PhotosUI;

static NSString * const kOrderDetailsItemCellID = @"OrderItemCell";
static NSString * const kOrderDetailsPlaceholderCellID = @"OrderDetailsPlaceholderCell";
static CGFloat const kOrderDetailsHeaderCornerRadius = 16.0;
static CGFloat const kOrderDetailsButtonCornerRadius = 18.0;
static CGFloat const kOrderDetailsContentBottomInset = 132.0;
static NSString * const kOrderSupportPhoneNumber = @"+97459997720";
static NSInteger const kOrderSupportComposerMaxAttachments = 4;

static NSString *PPOrderStepperNormalizedKey(NSString *value)
{
    if (![value isKindOfClass:NSString.class]) return @"";
    NSString *key = [[(NSString *)value lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    key = [key stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    key = [key stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
    while ([key containsString:@"__"]) {
        key = [key stringByReplacingOccurrencesOfString:@"__" withString:@"_"];
    }
    return key;
}

static NSString *PPOrderCustomerVisibleTimelineStatusKey(NSString *statusKey)
{
    NSString *normalized = PPOrderStepperNormalizedKey(statusKey);
    if (normalized.length == 0) return @"preparing_for_shipment";
    if ([normalized isEqualToString:@"delivery_cancelled"] ||
        [normalized containsString:@"cancelled"] ||
        [normalized containsString:@"canceled"]) {
        return @"delivery_cancelled";
    }
    if ([normalized isEqualToString:@"delivery_failed"] ||
        [normalized isEqualToString:@"returned_to_store"] ||
        [normalized containsString:@"returned_to_store"] ||
        [normalized containsString:@"failed"]) {
        return @"delivery_delayed";
    }
    if ([normalized isEqualToString:@"completed"] ||
        [normalized containsString:@"completed"] ||
        [normalized containsString:@"fulfilled"]) {
        return @"completed";
    }
    if ([normalized isEqualToString:@"delivered"] ||
        [normalized isEqualToString:@"payment_pending"] ||
        [normalized isEqualToString:@"payment_confirmed"] ||
        [normalized containsString:@"delivered"]) {
        return @"delivered";
    }
    if ([normalized isEqualToString:@"picked_up"] ||
        [normalized isEqualToString:@"in_transit"] ||
        [normalized containsString:@"shipped"] ||
        [normalized containsString:@"shipping"] ||
        [normalized containsString:@"out_for_delivery"] ||
        [normalized containsString:@"in_transit"]) {
        return @"on_the_way";
    }
    if ([normalized isEqualToString:@"delivery_assigned"] ||
        [normalized isEqualToString:@"awaiting_handover"]) {
        return @"delivery_partner_assigned";
    }
    if ([normalized isEqualToString:@"ready_to_ship"] ||
        [normalized isEqualToString:@"delivery_requested"] ||
        [normalized isEqualToString:@"delivery_reassigned"]) {
        return @"ready_for_delivery";
    }
    return @"preparing_for_shipment";
}

static NSString *PPOrderCustomerVisibleStatusTitle(NSString *statusKey)
{
    NSString *normalized = PPOrderStepperNormalizedKey(statusKey);
    if ([normalized isEqualToString:@"ready_for_delivery"]) return kLang(@"Ready for Delivery");
    if ([normalized isEqualToString:@"delivery_partner_assigned"]) return kLang(@"Delivery Partner Assigned");
    if ([normalized isEqualToString:@"on_the_way"]) return kLang(@"On the Way");
    if ([normalized isEqualToString:@"delivered"]) return kLang(@"Delivered");
    if ([normalized isEqualToString:@"completed"]) return kLang(@"Completed");
    if ([normalized isEqualToString:@"delivery_cancelled"]) return kLang(@"Delivery Cancelled");
    if ([normalized isEqualToString:@"delivery_delayed"]) return kLang(@"Delivery Delayed");
    return kLang(@"Preparing for Shipment");
}

static NSString *PPOrderCustomerVisibleStatusHint(NSString *statusKey)
{
    NSString *normalized = PPOrderStepperNormalizedKey(statusKey);
    if ([normalized isEqualToString:@"ready_for_delivery"]) return kLang(@"order_delivery_hint_ready");
    if ([normalized isEqualToString:@"delivery_partner_assigned"]) return kLang(@"order_delivery_hint_assigned");
    if ([normalized isEqualToString:@"on_the_way"]) return kLang(@"order_delivery_hint_on_the_way");
    if ([normalized isEqualToString:@"delivered"]) return kLang(@"order_delivery_hint_delivered");
    if ([normalized isEqualToString:@"completed"]) return kLang(@"order_delivery_hint_completed");
    if ([normalized isEqualToString:@"delivery_cancelled"]) return kLang(@"order_delivery_hint_cancelled");
    if ([normalized isEqualToString:@"delivery_delayed"]) return kLang(@"order_delivery_hint_delayed");
    return kLang(@"order_delivery_hint_preparing");
}

static BOOL PPOrderTimelineUsesDeliveryPresentation(NSString *statusKey)
{
    NSString *normalized = PPOrderStepperNormalizedKey(statusKey);
    if (normalized.length == 0) return NO;
    NSArray<NSString *> *keywords = @[
        @"ready_to_ship",
        @"delivery_requested",
        @"delivery_assigned",
        @"awaiting_handover",
        @"picked_up",
        @"in_transit",
        @"delivered",
        @"payment_pending",
        @"payment_confirmed",
        @"completed",
        @"delivery_cancelled",
        @"delivery_failed",
        @"returned_to_store",
        @"delivery_reassigned"
    ];
    for (NSString *keyword in keywords) {
        NSString *wrappedStatus = [NSString stringWithFormat:@"_%@_", normalized];
        NSString *wrappedKeyword = [NSString stringWithFormat:@"_%@_", keyword];
        if ([wrappedStatus containsString:wrappedKeyword]) {
            return YES;
        }
    }
    return NO;
}

static NSString *PPOrderStepperSymbolForTitle(NSString *title, NSInteger index)
{
    NSString *key = PPOrderStepperNormalizedKey(title);
    if ([key containsString:@"pending"]) return @"clock.fill";
    if ([key containsString:@"paid"] || [key containsString:@"success"]) return @"creditcard.fill";
    if ([key containsString:@"processing"] || [key containsString:@"preparing"] || [key containsString:@"packed"]) return @"shippingbox.fill";
    if ([key containsString:@"shipped"] || [key containsString:@"shipping"] ||
        [key containsString:@"out_for_delivery"] || [key containsString:@"in_transit"]) {
        return @"shippedtruck";
    }
    if ([key containsString:@"delivered"] || [key containsString:@"completed"] || [key containsString:@"fulfilled"]) {
        return @"checkmark.seal.fill";
    }
    if ([key containsString:@"failed"] || [key containsString:@"rejected"] ||
        [key containsString:@"cancelled"] || [key containsString:@"canceled"] ||
        [key containsString:@"expired"]) {
        return @"xmark.octagon.fill";
    }

    switch (index) {
        case 0: return @"shippingbox.circle.fill";
        case 1: return @"shippingbox.fill";
        case 2: return @"person.crop.circle.fill";
        case 3: return @"shippedtruck";
        case 4: return @"checkmark.circle.fill";
        case 5: return @"checkmark.seal.fill";
        default: break;
    }
    return @"circle";
}

static UIImage *PPOrderStepperImage(NSString *name)
{
    if (![name isKindOfClass:NSString.class] || name.length == 0) {
        return nil;
    }

    UIImage *image = [UIImage imageNamed:name];
    if (image) {
        return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }

    if (@available(iOS 13.0, *)) {
        return [UIImage systemImageNamed:name];
    }

    return nil;
}

@interface PPOrderStatusStepperView : UIView

- (void)configureWithSteps:(NSArray<NSString *> *)steps
              currentIndex:(NSInteger)currentIndex
              showsFailure:(BOOL)showsFailure
                 tintColor:(nullable UIColor *)tintColor;

@end

static UIColor *PPOrderRequestStatusColor(NSString *status)
{
    NSString *normalized = PPOrderStepperNormalizedKey(status);
    if ([normalized isEqualToString:@"approved"] ||
        [normalized isEqualToString:@"completed"] ||
        [normalized isEqualToString:@"refunded"]) {
        return UIColor.systemGreenColor;
    }
    if ([normalized isEqualToString:@"rejected"] ||
        [normalized isEqualToString:@"cancelled"] ||
        [normalized isEqualToString:@"closed"]) {
        return UIColor.systemRedColor;
    }
    if ([normalized isEqualToString:@"partially_refunded"]) {
        return UIColor.systemTealColor;
    }
    return UIColor.systemOrangeColor;
}

static NSString *PPOrderTimelineTitle(PPOrderTimelineEvent *event)
{
    NSString *type = PPOrderStepperNormalizedKey(event.type);
    if ([type isEqualToString:@"order_created"]) return kLang(@"order_timeline_created_title");
    if ([type isEqualToString:@"payment_verified"]) return kLang(@"order_timeline_paid_title");
    if ([type isEqualToString:@"payment_collected"]) return kLang(@"order_timeline_payment_collected_title");
    if ([type isEqualToString:@"payment_verification_pending"]) return kLang(@"order_timeline_pending_title");
    if ([type isEqualToString:@"fulfillment_processing"]) return kLang(@"order_timeline_processing_title");
    if ([type isEqualToString:@"fulfillment_shipped"]) return kLang(@"order_timeline_shipped_title");
    if ([type isEqualToString:@"fulfillment_delivered"]) return kLang(@"order_timeline_delivered_title");
    if ([type isEqualToString:@"order_cancelled"]) return kLang(@"order_timeline_cancelled_title");
    if ([type isEqualToString:@"order_mark_ready"] ||
        [type isEqualToString:@"ready_to_ship"] ||
        [type isEqualToString:@"delivery_requested"]) {
        return PPOrderCustomerVisibleStatusTitle(@"ready_for_delivery");
    }
    if ([type isEqualToString:@"order_accept_delivery"] ||
        [type isEqualToString:@"delivery_assigned"] ||
        [type isEqualToString:@"awaiting_handover"]) {
        return PPOrderCustomerVisibleStatusTitle(@"delivery_partner_assigned");
    }
    if ([type isEqualToString:@"order_confirm_handover"] ||
        [type isEqualToString:@"order_mark_shipped"] ||
        [type isEqualToString:@"order_mark_in_transit"] ||
        [type isEqualToString:@"picked_up"] ||
        [type isEqualToString:@"in_transit"]) {
        return PPOrderCustomerVisibleStatusTitle(@"on_the_way");
    }
    if ([type isEqualToString:@"order_mark_delivered"]) {
        return PPOrderCustomerVisibleStatusTitle(@"delivered");
    }
    if ([type isEqualToString:@"order_mark_completed"]) {
        return PPOrderCustomerVisibleStatusTitle(@"completed");
    }
    if ([type isEqualToString:@"order_cancel_delivery"]) {
        return PPOrderCustomerVisibleStatusTitle(@"delivery_cancelled");
    }
    if ([type isEqualToString:@"order_mark_delivery_failed"] ||
        [type isEqualToString:@"order_return_to_store"]) {
        return PPOrderCustomerVisibleStatusTitle(@"delivery_delayed");
    }
    if ([type isEqualToString:@"customer_request_created"]) return kLang(@"order_request_timeline_submitted");
    if ([type isEqualToString:@"request_submitted"]) return kLang(@"order_request_timeline_submitted");
    if ([type isEqualToString:@"request_status_updated"]) return kLang(@"order_request_timeline_updated");
    NSString *eventStatus = PPOrderStepperNormalizedKey(event.status);
    if (PPOrderTimelineUsesDeliveryPresentation(eventStatus)) {
        NSString *statusTitle = PPOrderCustomerVisibleStatusTitle(PPOrderCustomerVisibleTimelineStatusKey(eventStatus));
        return statusTitle;
    }
    return event.summary.length > 0 ? event.summary : kLang(@"order_tracking_title");
}

static NSString *PPOrderTimelineSubtitle(PPOrderTimelineEvent *event)
{
    if (event.summary.length > 0) return event.summary;
    NSString *status = PPOrderStepperNormalizedKey(event.status);
    if (PPOrderTimelineUsesDeliveryPresentation(status)) {
        NSString *deliveryHint = PPOrderCustomerVisibleStatusHint(PPOrderCustomerVisibleTimelineStatusKey(status));
        return deliveryHint;
    }
    if ([status isEqualToString:@"paid"]) return kLang(@"Paid");
    if ([status isEqualToString:@"pending"]) return kLang(@"Pending");
    if ([status isEqualToString:@"pending_collection"]) return kLang(@"order_payment_status_pending_collection");
    if ([status isEqualToString:@"processing"]) return kLang(@"Processing");
    if ([status isEqualToString:@"shipped"]) return kLang(@"Shipped");
    if ([status isEqualToString:@"delivered"]) return kLang(@"Delivered");
    if ([status isEqualToString:@"cancelled"]) return kLang(@"Canceled");
    NSString *statusTitle = [PPOrderManager displayTitleForRequestStatus:event.status];
    return statusTitle.length > 0 ? statusTitle : kLang(@"order_tracking_empty");
}

static NSArray<NSDictionary *> *PPOrderSupportComposerItems(PPOrder *order)
{
    NSMutableArray<NSDictionary *> *items = [NSMutableArray array];
    for (id rawItem in order.items ?: @[]) {
        if ([rawItem isKindOfClass:NSString.class]) {
            NSString *itemID = [(NSString *)rawItem stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (itemID.length == 0) continue;
            [items addObject:@{
                @"id": itemID,
                @"name": itemID,
                @"quantity": @(1)
            }];
            continue;
        }
        if (![rawItem isKindOfClass:NSDictionary.class]) continue;
        NSDictionary *item = (NSDictionary *)rawItem;
        NSString *itemID = [item[@"id"] isKindOfClass:NSString.class] ? item[@"id"] : item[@"itemID"];
        if (![itemID isKindOfClass:NSString.class] || itemID.length == 0) continue;
        NSString *name = [item[@"name"] isKindOfClass:NSString.class] ? item[@"name"] : (item[@"title"] ?: itemID);
        NSInteger qty = [item[@"qty"] ?: item[@"quantity"] integerValue];
        [items addObject:@{
            @"id": itemID ?: @"",
            @"name": name ?: itemID ?: @"",
            @"quantity": @(MAX(1, qty))
        }];
    }
    return items.copy;
}

@interface UIViewController (PPOrderChevronBack)
- (void)pp_orderApplyChevronBackButton;
- (void)pp_orderHandleChevronBack;
@end

@implementation UIViewController (PPOrderChevronBack)

- (void)pp_orderApplyChevronBackButton
{
    if (@available(iOS 13.0, *)) {
        UIImage *backImage = [UIImage systemImageNamed:PPChevronName];
        self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithImage:backImage
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(pp_orderHandleChevronBack)];
    } else {
        UIButton *backButton = [PPButtonHelper pp_buttonWithTitleForBar:nil imageName:PPChevronName target:self action:@selector(pp_orderHandleChevronBack)];
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backButton];
    }
}

- (void)pp_orderHandleChevronBack
{
    [self.navigationController popViewControllerAnimated:YES];
}

@end

@interface PPOrderTimelineViewController : UIViewController
+ (instancetype)controllerWithOrder:(PPOrder *)order
                       orderManager:(PPOrderManager *)orderManager
                             events:(NSArray<PPOrderTimelineEvent *> *)events;
@end

@interface PPOrderSupportRequestListViewController : UIViewController
+ (instancetype)controllerWithOrder:(PPOrder *)order
                       orderManager:(PPOrderManager *)orderManager
                           requests:(NSArray<PPOrderSupportRequest *> *)requests;
@end

@interface PPOrderSupportRequestDetailsViewController : UIViewController
+ (instancetype)controllerWithOrder:(PPOrder *)order
                       orderManager:(PPOrderManager *)orderManager
                            request:(PPOrderSupportRequest *)request;
@end

@interface PPOrderSupportComposerViewController : UIViewController
+ (instancetype)controllerWithOrder:(PPOrder *)order
                         actionType:(PPOrderCustomerActionType)actionType
                       orderManager:(PPOrderManager *)orderManager
                         onComplete:(dispatch_block_t)onComplete;
@end

@interface PPOrderTimelineViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) PPOrder *order;
@property (nonatomic, strong) PPOrderManager *orderManager;
@property (nonatomic, strong) NSArray<PPOrderTimelineEvent *> *events;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) id<FIRListenerRegistration> listener;
@end

@implementation PPOrderTimelineViewController

+ (instancetype)controllerWithOrder:(PPOrder *)order
                       orderManager:(PPOrderManager *)orderManager
                             events:(NSArray<PPOrderTimelineEvent *> *)events
{
    PPOrderTimelineViewController *vc = [PPOrderTimelineViewController new];
    vc.order = order;
    vc.orderManager = orderManager ?: [PPOrderManager shared];
    vc.events = events ?: @[];
    return vc;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = AppBackgroundClr;
    self.title = kLang(@"order_tracking_title");
    [self pp_orderApplyChevronBackButton];
    self.dateFormatter = [NSDateFormatter new];
    self.dateFormatter.locale = [NSLocale currentLocale];
    [self.dateFormatter setLocalizedDateFormatFromTemplate:@"EEE d MMM h:mm a"];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = AppClearClr;
    [self.view addSubview:self.tableView];

    __weak typeof(self) weakSelf = self;
    self.listener = [self.orderManager listenToTimelineEventsForOrder:self.order
                                                               update:^(NSArray<PPOrderTimelineEvent *> *events, NSError * _Nullable __unused error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.events = events ?: @[];
            [strongSelf.tableView reloadData];
        });
    }];
}

- (void)dealloc
{
    [self.listener remove];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    (void)tableView;
    (void)section;
    return MAX(1, self.events.count);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellID = @"TimelineCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellID];
        cell.textLabel.font = [GM boldFontWithSize:15];
        cell.detailTextLabel.font = [GM MidFontWithSize:13];
        cell.detailTextLabel.numberOfLines = 0;
    }

    if (self.events.count == 0) {
        cell.textLabel.text = kLang(@"order_tracking_empty");
        cell.detailTextLabel.text = kLang(@"order_tracking_empty_subtitle");
        cell.imageView.image = [UIImage systemImageNamed:@"clock.arrow.circlepath"];
        cell.imageView.tintColor = UIColor.secondaryLabelColor;
        return cell;
    }

    if (indexPath.row >= (NSInteger)self.events.count) {
        NSLog(@"❌ [OrderTimeline] events out of bounds: row=%ld count=%lu", (long)indexPath.row, (unsigned long)self.events.count);
        return cell;
    }
    PPOrderTimelineEvent *event = self.events[indexPath.row];
    cell.textLabel.text = PPOrderTimelineTitle(event);
    NSString *dateString = event.createdAt ? [self.dateFormatter stringFromDate:event.createdAt] : @"";
    NSString *subtitle = PPOrderTimelineSubtitle(event);
    cell.detailTextLabel.text = dateString.length > 0 ? [NSString stringWithFormat:@"%@\n%@", dateString, subtitle] : subtitle;
    cell.imageView.image = [UIImage systemImageNamed:@"circle.inset.filled"];
    cell.imageView.tintColor = PPOrderRequestStatusColor(event.status);
    return cell;
}

@end

@interface PPOrderSupportRequestListViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) PPOrder *order;
@property (nonatomic, strong) PPOrderManager *orderManager;
@property (nonatomic, strong) NSArray<PPOrderSupportRequest *> *requests;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) id<FIRListenerRegistration> listener;
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
    self.title = kLang(@"order_requests_history_title");
    [self pp_orderApplyChevronBackButton];
    self.dateFormatter = [NSDateFormatter new];
    self.dateFormatter.locale = [NSLocale currentLocale];
    [self.dateFormatter setLocalizedDateFormatFromTemplate:@"EEE d MMM h:mm a"];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];

    __weak typeof(self) weakSelf = self;
    self.listener = [self.orderManager listenToSupportRequestsForOrderID:self.order.orderId
                                                                  update:^(NSArray<PPOrderSupportRequest *> *requests, NSError * _Nullable __unused error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.requests = requests ?: @[];
            [strongSelf.tableView reloadData];
        });
    }];
}

- (void)dealloc
{
    [self.listener remove];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    (void)tableView;
    (void)section;
    return MAX(1, self.requests.count);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellID = @"RequestCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellID];
        cell.textLabel.font = [GM boldFontWithSize:15];
        cell.detailTextLabel.font = [GM MidFontWithSize:13];
        cell.detailTextLabel.numberOfLines = 0;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    if (self.requests.count == 0) {
        cell.textLabel.text = kLang(@"order_requests_empty_title");
        cell.detailTextLabel.text = kLang(@"order_requests_empty_subtitle");
        cell.imageView.image = [UIImage systemImageNamed:@"tray"];
        cell.imageView.tintColor = UIColor.secondaryLabelColor;
        cell.accessoryType = UITableViewCellAccessoryNone;
        return cell;
    }

    if (indexPath.row >= (NSInteger)self.requests.count) {
        NSLog(@"❌ [OrderRequests] requests out of bounds: row=%ld count=%lu", (long)indexPath.row, (unsigned long)self.requests.count);
        return cell;
    }
    PPOrderSupportRequest *request = self.requests[indexPath.row];
    UIColor *statusColor = PPOrderRequestStatusColor(request.status);
    NSString *dateString = request.updatedAt ? [self.dateFormatter stringFromDate:request.updatedAt] : @"";
    cell.textLabel.text = [PPOrderManager displayTitleForRequestType:request.type];
    cell.textLabel.textColor = statusColor;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@\n%@%@",
                                 request.reasonTitle.length > 0 ? request.reasonTitle : [PPOrderManager displayTitleForRequestStatus:request.status],
                                 [PPOrderManager displayTitleForRequestStatus:request.status],
                                 dateString.length > 0 ? [NSString stringWithFormat:@" • %@", dateString] : @""];
    cell.imageView.image = [UIImage systemImageNamed:@"doc.text.magnifyingglass"];
    cell.imageView.tintColor = statusColor;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.requests.count == 0 || indexPath.row >= (NSInteger)self.requests.count) return;
    PPOrderSupportRequest *request = self.requests[indexPath.row];
    UIViewController *details = [PPOrderSupportRequestDetailsViewController controllerWithOrder:self.order
                                                                                   orderManager:self.orderManager
                                                                                        request:request];
    [self.navigationController pushViewController:details animated:YES];
}

@end

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
    self.stackView.spacing = 14.0;
    self.stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.stackView];

    [NSLayoutConstraint activateConstraints:@[
        [self.stackView.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor constant:16],
        [self.stackView.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor constant:-16],
        [self.stackView.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:16],
        [self.stackView.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-24],
        [self.stackView.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor constant:-32]
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
    card.backgroundColor = AppForgroundColr;
    card.layer.cornerRadius = 16.0;

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
        [titleLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [titleLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [titleLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
        [valueLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [valueLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [valueLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8],
        [valueLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14]
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

@interface PPOrderSupportComposerViewController () <PHPickerViewControllerDelegate>
@property (nonatomic, strong) PPOrder *order;
@property (nonatomic, assign) PPOrderCustomerActionType actionType;
@property (nonatomic, strong) PPOrderManager *orderManager;
@property (nonatomic, copy) dispatch_block_t onComplete;
@property (nonatomic, strong) NSArray<NSDictionary *> *reasonOptions;
@property (nonatomic, strong) NSDictionary *selectedReason;
@property (nonatomic, strong) NSArray<NSDictionary *> *composerItems;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedItemIDs;
@property (nonatomic, strong) NSMutableArray<UIImage *> *selectedImages;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *stackView;
@property (nonatomic, strong) UIButton *reasonButton;
@property (nonatomic, strong) UIStackView *itemsStackView;
@property (nonatomic, strong) UITextView *notesTextView;
@property (nonatomic, strong) UIButton *addPhotoButton;
@property (nonatomic, strong) UILabel *attachmentsLabel;
@property (nonatomic, strong) UIButton *submitButton;
@end

@implementation PPOrderSupportComposerViewController

+ (instancetype)controllerWithOrder:(PPOrder *)order
                         actionType:(PPOrderCustomerActionType)actionType
                       orderManager:(PPOrderManager *)orderManager
                         onComplete:(dispatch_block_t)onComplete
{
    PPOrderSupportComposerViewController *vc = [PPOrderSupportComposerViewController new];
    vc.order = order;
    vc.actionType = actionType;
    vc.orderManager = orderManager ?: [PPOrderManager shared];
    vc.onComplete = onComplete;
    return vc;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
    self.title = [PPOrderManager displayTitleForActionType:self.actionType];
    [self pp_orderApplyChevronBackButton];
    self.reasonOptions = [self.orderManager reasonOptionsForAction:self.actionType];
    self.selectedItemIDs = [NSMutableSet set];
    self.selectedImages = [NSMutableArray array];
    self.composerItems = PPOrderSupportComposerItems(self.order);
    BOOL isRTL = [Language isRTL];
    NSTextAlignment leadingAlignment = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    UISemanticContentAttribute semantic = Language.semanticAttributeForCurrentLanguage;

    self.view.semanticContentAttribute = semantic;

    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.semanticContentAttribute = semantic;
    [self.view addSubview:self.scrollView];

    self.stackView = [[UIStackView alloc] initWithFrame:CGRectZero];
    self.stackView.axis = UILayoutConstraintAxisVertical;
    self.stackView.spacing = 14.0;
    self.stackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.stackView.semanticContentAttribute = semantic;
    [self.scrollView addSubview:self.stackView];

    [NSLayoutConstraint activateConstraints:@[
        [self.stackView.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor constant:16],
        [self.stackView.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor constant:-16],
        [self.stackView.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:16],
        [self.stackView.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-24],
        [self.stackView.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor constant:-32]
    ]];

    UILabel *intro = [[UILabel alloc] initWithFrame:CGRectZero];
    intro.font = [GM MidFontWithSize:15];
    intro.textColor = UIColor.secondaryLabelColor;
    intro.numberOfLines = 0;
    intro.textAlignment = leadingAlignment;
    intro.semanticContentAttribute = semantic;
    intro.text = [self.orderManager eligibilityForAction:self.actionType
                                                   order:self.order
                                                requests:@[]
                                           referenceDate:[NSDate date]].message;
    [self.stackView addArrangedSubview:intro];

    self.reasonButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.reasonButton.backgroundColor = AppForgroundColr;
    self.reasonButton.layer.cornerRadius = 14.0;
    self.reasonButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    self.reasonButton.semanticContentAttribute = semantic;
    self.reasonButton.titleLabel.font = [GM boldFontWithSize:16];
    self.reasonButton.titleLabel.textAlignment = leadingAlignment;
    [self.reasonButton setTitleColor:[GM appPrimaryColor] forState:UIControlStateNormal];
    [self.reasonButton setTitle:kLang(@"order_request_select_reason") forState:UIControlStateNormal];
    self.reasonButton.contentEdgeInsets = UIEdgeInsetsMake(14, 16, 14, 16);
    [self.reasonButton addTarget:self action:@selector(selectReasonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.stackView addArrangedSubview:self.reasonButton];

    self.itemsStackView = [[UIStackView alloc] initWithFrame:CGRectZero];
    self.itemsStackView.axis = UILayoutConstraintAxisVertical;
    self.itemsStackView.spacing = 10.0;
    [self.stackView addArrangedSubview:self.itemsStackView];
    [self rebuildItemsSelection];

    self.notesTextView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 0, 140)];
    self.notesTextView.font = [GM MidFontWithSize:15];
    self.notesTextView.backgroundColor = AppForgroundColr;
    self.notesTextView.layer.cornerRadius = 14.0;
    self.notesTextView.textContainerInset = UIEdgeInsetsMake(14, 12, 14, 12);
    self.notesTextView.textAlignment = leadingAlignment;
    self.notesTextView.semanticContentAttribute = semantic;
    self.notesTextView.text = @"";
    [self.stackView addArrangedSubview:self.notesTextView];
    [self.notesTextView.heightAnchor constraintEqualToConstant:140].active = YES;

    self.addPhotoButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.addPhotoButton.backgroundColor = AppForgroundColr;
    self.addPhotoButton.layer.cornerRadius = 14.0;
    self.addPhotoButton.contentEdgeInsets = UIEdgeInsetsMake(14, 16, 14, 16);
    self.addPhotoButton.titleLabel.font = [GM boldFontWithSize:16];
    [self.addPhotoButton setTitleColor:[GM appPrimaryColor] forState:UIControlStateNormal];
    [self.addPhotoButton setTitle:kLang(@"order_request_add_photos") forState:UIControlStateNormal];
    [self.addPhotoButton addTarget:self action:@selector(addPhotosTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.stackView addArrangedSubview:self.addPhotoButton];

    self.attachmentsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.attachmentsLabel.font = [GM MidFontWithSize:13];
    self.attachmentsLabel.textColor = UIColor.secondaryLabelColor;
    self.attachmentsLabel.numberOfLines = 0;
    self.attachmentsLabel.textAlignment = leadingAlignment;
    self.attachmentsLabel.semanticContentAttribute = semantic;
    [self.stackView addArrangedSubview:self.attachmentsLabel];
    [self refreshAttachmentLabel];

    self.submitButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.submitButton.backgroundColor = [GM appPrimaryColor];
    self.submitButton.layer.cornerRadius = 16.0;
    [self.submitButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.submitButton.titleLabel.font = [GM boldFontWithSize:17];
    [self.submitButton setTitle:kLang(@"order_request_submit") forState:UIControlStateNormal];
    [self.submitButton addTarget:self action:@selector(submitTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.stackView addArrangedSubview:self.submitButton];
    [self.submitButton.heightAnchor constraintEqualToConstant:54].active = YES;
}

- (void)showMessage:(NSString *)message title:(NSString *)title
{
    NSString *safeMessage = message.length > 0
        ? [PPFirebaseSessionBridge publicMessageForText:message fallbackKey:@"pp_order_support_submit_failed"]
        : message;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:safeMessage
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"OK") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)selectReasonTapped
{
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:kLang(@"order_request_select_reason")
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    sheet.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    for (NSDictionary *reason in self.reasonOptions) {
        [sheet addAction:[UIAlertAction actionWithTitle:reason[@"title"]
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction * _Nonnull action) {
            self.selectedReason = reason;
            [self.reasonButton setTitle:reason[@"title"] forState:UIControlStateNormal];
            [self rebuildItemsSelection];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"cancel") style:UIAlertActionStyleCancel handler:nil]];
    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = self.reasonButton;
        sheet.popoverPresentationController.sourceRect = self.reasonButton.bounds;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)rebuildItemsSelection
{
    for (UIView *view in self.itemsStackView.arrangedSubviews) {
        [self.itemsStackView removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    BOOL requiresItems = self.selectedReason ? [self.selectedReason[@"requiresItemSelection"] boolValue] : NO;
    self.itemsStackView.hidden = !requiresItems || self.composerItems.count == 0;
    if (self.itemsStackView.hidden) return;

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectZero];
    title.font = [GM boldFontWithSize:15];
    title.textColor = UIColor.labelColor;
    title.textAlignment = Language.alignmentForCurrentLanguage;
    title.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    title.text = kLang(@"order_request_items_title");
    [self.itemsStackView addArrangedSubview:title];

    for (NSInteger index = 0; index < (NSInteger)self.composerItems.count; index++) {
        NSDictionary *item = self.composerItems[index];
        NSString *itemID = item[@"id"] ?: @"";
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = index;
        button.backgroundColor = AppForgroundColr;
        button.layer.cornerRadius = 14.0;
        button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
        button.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
        button.contentEdgeInsets = UIEdgeInsetsMake(12, 16, 12, 16);
        button.titleLabel.font = [GM MidFontWithSize:15];
        button.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
        BOOL selected = [self.selectedItemIDs containsObject:itemID];
        NSString *titleText = [NSString stringWithFormat:@"%@%@ ×%@", selected ? @"✓ " : @"", item[@"name"] ?: itemID, item[@"quantity"] ?: @1];
        [button setTitle:titleText forState:UIControlStateNormal];
        [button addTarget:self action:@selector(toggleItemSelection:) forControlEvents:UIControlEventTouchUpInside];
        [self.itemsStackView addArrangedSubview:button];
    }
}

- (void)toggleItemSelection:(UIButton *)sender
{
    NSInteger index = sender.tag;
    if (index < 0 || index >= (NSInteger)self.composerItems.count) return;
    NSDictionary *item = self.composerItems[index];
    NSString *itemID = item[@"id"] ?: @"";
    if (itemID.length == 0) return;
    if ([self.selectedItemIDs containsObject:itemID]) {
        [self.selectedItemIDs removeObject:itemID];
    } else {
        [self.selectedItemIDs addObject:itemID];
    }
    [self rebuildItemsSelection];
}

- (void)addPhotosTapped
{
    if (self.selectedImages.count >= kOrderSupportComposerMaxAttachments) {
        [self showMessage:kLang(@"order_support_too_many_photos")
                    title:kLang(@"order_request_attachments_title")];
        return;
    }

    if (@available(iOS 14.0, *)) {
        PHPickerConfiguration *config = [PHPickerConfiguration new];
        config.selectionLimit = MAX(1, kOrderSupportComposerMaxAttachments - (NSInteger)self.selectedImages.count);
        config.filter = [PHPickerFilter imagesFilter];
        PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    } else {
        [self showMessage:kLang(@"order_request_photos_unavailable")
                    title:kLang(@"order_request_attachments_title")];
    }
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results API_AVAILABLE(ios(14.0))
{
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (results.count == 0) return;

    dispatch_group_t group = dispatch_group_create();
    NSMutableArray<UIImage *> *loadedImages = [NSMutableArray array];
    for (PHPickerResult *result in results) {
        if (![result.itemProvider canLoadObjectOfClass:UIImage.class]) continue;
        dispatch_group_enter(group);
        [result.itemProvider loadObjectOfClass:UIImage.class completionHandler:^(UIImage * _Nullable image, NSError * _Nullable __unused error) {
            if ([image isKindOfClass:UIImage.class]) {
                @synchronized (loadedImages) {
                    [loadedImages addObject:image];
                }
            }
            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        for (UIImage *image in loadedImages) {
            if (self.selectedImages.count >= kOrderSupportComposerMaxAttachments) break;
            [self.selectedImages addObject:image];
        }
        [self refreshAttachmentLabel];
    });
}

- (void)refreshAttachmentLabel
{
    if (self.selectedImages.count == 0) {
        self.attachmentsLabel.text = kLang(@"order_request_photos_optional");
    } else {
        self.attachmentsLabel.text = [NSString stringWithFormat:kLang(@"order_request_photos_count"), (long)self.selectedImages.count];
    }
}

- (void)setSubmitLoading:(BOOL)loading
{
    self.submitButton.enabled = !loading;
    self.reasonButton.enabled = !loading;
    self.addPhotoButton.enabled = !loading;
    [self.submitButton setTitle:(loading ? kLang(@"order_request_submitting") : kLang(@"order_request_submit")) forState:UIControlStateNormal];
}

- (void)submitTapped
{
    if (!self.selectedReason && self.reasonOptions.count > 0) {
        [self showMessage:kLang(@"order_request_select_reason")
                    title:self.title];
        return;
    }
    if ([self.selectedReason[@"requiresItemSelection"] boolValue] && self.selectedItemIDs.count == 0) {
        [self showMessage:kLang(@"order_request_select_items_error")
                    title:self.title];
        return;
    }

    [self setSubmitLoading:YES];
    NSString *draftID = NSUUID.UUID.UUIDString;
    __weak typeof(self) weakSelf = self;

    void (^submitDraft)(NSArray<PPOrderSupportAttachment *> *) = ^(NSArray<PPOrderSupportAttachment *> *attachments) {
        PPOrderSupportDraft *draft = [PPOrderSupportDraft new];
        draft.actionType = self.actionType;
        draft.reasonCode = self.selectedReason ? (self.selectedReason[@"code"] ?: @"other") : @"other";
        draft.reasonTitle = self.selectedReason ? (self.selectedReason[@"title"] ?: @"") : @"";
        draft.issueCategory = self.selectedReason ? (self.selectedReason[@"code"] ?: @"other") : @"other";
        draft.subject = [PPOrderManager displayTitleForActionType:self.actionType];
        draft.notes = self.notesTextView.text ?: @"";
        draft.selectedItemIDs = self.selectedItemIDs.allObjects ?: @[];
        draft.attachments = attachments ?: @[];

        [self.orderManager submitSupportDraft:draft
                                     forOrder:self.order
                                   completion:^(PPOrderSupportRequest * _Nullable request, BOOL __unused deduplicated, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                [strongSelf setSubmitLoading:NO];
                if (error) {
                    [strongSelf showMessage:error.localizedDescription ?: kLang(@"SomethingWentWrong")
                                    title:strongSelf.title];
                    return;
                }
                if (strongSelf.onComplete) strongSelf.onComplete();
                if (request) {
                    UIViewController *detailsVC = [PPOrderSupportRequestDetailsViewController controllerWithOrder:strongSelf.order
                                                                                                   orderManager:strongSelf.orderManager
                                                                                                        request:request];
                    if (strongSelf.navigationController) {
                        NSMutableArray *stack = strongSelf.navigationController.viewControllers.mutableCopy;
                        if (stack.count > 0) {
                            [stack removeLastObject];
                        }
                        [stack addObject:detailsVC];
                        [strongSelf.navigationController setViewControllers:stack animated:YES];
                    }
                } else {
                    [strongSelf.navigationController popViewControllerAnimated:YES];
                }
            });
        }];
    };

    if (self.selectedImages.count == 0) {
        submitDraft(@[]);
        return;
    }

    [self.orderManager uploadEvidenceImages:self.selectedImages
                                   forOrder:self.order
                            draftIdentifier:draftID
                                   progress:nil
                                 completion:^(NSArray<PPOrderSupportAttachment *> *attachments, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (error) {
                [strongSelf setSubmitLoading:NO];
                [strongSelf showMessage:error.localizedDescription ?: kLang(@"order_support_upload_failed")
                                title:strongSelf.title];
                return;
            }
            submitDraft(attachments ?: @[]);
        });
    }];
}

@end

@interface PPOrderStatusStepperView ()

@property (nonatomic, copy) NSArray<NSString *> *steps;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, assign) BOOL showsFailure;
@property (nonatomic, strong, nullable) UIColor *progressTintColor;
@property (nonatomic, strong) NSMutableArray<UIView *> *haloViews;
@property (nonatomic, strong) NSMutableArray<UIView *> *dotViews;
@property (nonatomic, strong) NSMutableArray<UIImageView *> *iconViews;
@property (nonatomic, strong) NSMutableArray<UILabel *> *labelViews;
@property (nonatomic, strong) NSMutableArray<UIView *> *connectorViews;

@end

static NSString * const PPOrderStepperCurrentDotMotionKey = @"pp_stepper_current_dot_breath";
static NSString * const PPOrderStepperCurrentHaloScaleKey = @"pp_stepper_current_halo_breath";
static NSString * const PPOrderStepperCurrentHaloOpacityKey = @"pp_stepper_current_halo_opacity";
static NSString * const PPOrderStepperCurrentIconMotionKey = @"pp_stepper_current_icon_settle";
static NSString * const PPOrderStepperCurrentLabelFloatKey = @"pp_stepper_current_label_float";
static NSString * const PPOrderStepperCurrentLabelOpacityKey = @"pp_stepper_current_label_opacity";
static NSString * const PPOrderStepperLegacyDotPulseKey = @"pp_stepper_dot_pulse";
static NSString * const PPOrderStepperLegacyHaloScaleKey = @"pp_stepper_halo_scale";
static NSString * const PPOrderStepperLegacyHaloOpacityKey = @"pp_stepper_halo_opacity";
static NSString * const PPOrderTimelineCurrentMarkerMotionKey = @"pp_timeline_current_marker_breath";
static NSString * const PPOrderTimelineCurrentHaloScaleKey = @"pp_timeline_current_halo_scale";
static NSString * const PPOrderTimelineCurrentHaloOpacityKey = @"pp_timeline_current_halo_opacity";
static NSString * const PPOrderTimelineCurrentIconMotionKey = @"pp_timeline_current_icon_breath";
static NSString * const PPOrderTimelineCurrentTitleFloatKey = @"pp_timeline_current_title_float";
static NSString * const PPOrderTimelineCurrentTitleOpacityKey = @"pp_timeline_current_title_opacity";
static NSString * const PPOrderSummaryStatusBadgeMotionKey = @"pp_summary_status_badge_breath";
static NSString * const PPOrderSummaryStatusHaloScaleKey = @"pp_summary_status_halo_scale";
static NSString * const PPOrderSummaryStatusHaloOpacityKey = @"pp_summary_status_halo_opacity";
static NSString * const PPOrderSummaryStatusIconMotionKey = @"pp_summary_status_icon_float";
static NSString * const PPOrderSummaryProgressChipMotionKey = @"pp_summary_progress_chip_breath";
static NSString * const PPOrderSummaryTimelineCounterMotionKey = @"pp_summary_timeline_counter_breath";

@implementation PPOrderStatusStepperView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _steps = @[];
        _currentIndex = 0;
        _showsFailure = NO;
        _haloViews = [NSMutableArray array];
        _dotViews = [NSMutableArray array];
        _iconViews = [NSMutableArray array];
        _labelViews = [NSMutableArray array];
        _connectorViews = [NSMutableArray array];
        self.backgroundColor = UIColor.clearColor;
    }
    return self;
}

- (void)configureWithSteps:(NSArray<NSString *> *)steps
              currentIndex:(NSInteger)currentIndex
              showsFailure:(BOOL)showsFailure
                 tintColor:(UIColor *)tintColor
{
    self.steps = [steps isKindOfClass:NSArray.class] ? steps : @[];
    if (self.steps.count == 0) {
        self.currentIndex = 0;
    } else {
        self.currentIndex = MAX(0, MIN(currentIndex, (NSInteger)self.steps.count - 1));
    }
    self.showsFailure = showsFailure;
    self.progressTintColor = tintColor;
    [self rebuildViews];
    [self setNeedsLayout];
}

- (void)rebuildViews
{
    for (UIView *view in self.dotViews) {
        [view removeFromSuperview];
    }
    for (UIView *view in self.haloViews) {
        [view removeFromSuperview];
    }
    for (UIImageView *view in self.iconViews) {
        [view removeFromSuperview];
    }
    for (UILabel *view in self.labelViews) {
        [view removeFromSuperview];
    }
    for (UIView *view in self.connectorViews) {
        [view removeFromSuperview];
    }
    [self.haloViews removeAllObjects];
    [self.dotViews removeAllObjects];
    [self.iconViews removeAllObjects];
    [self.labelViews removeAllObjects];
    [self.connectorViews removeAllObjects];

    NSInteger count = self.steps.count;
    if (count <= 0) return;

    for (NSInteger i = 0; i < count; i++) {
        UIView *halo = [[UIView alloc] initWithFrame:CGRectZero];
        halo.layer.cornerRadius = 18.0;
        halo.layer.masksToBounds = NO;
        halo.hidden = YES;
        [self addSubview:halo];
        [self.haloViews addObject:halo];

        UIView *dot = [[UIView alloc] initWithFrame:CGRectZero];
        dot.layer.cornerRadius = 11.0;
        dot.layer.masksToBounds = YES;
        dot.layer.borderWidth = 1.0;
        [self addSubview:dot];
        [self.dotViews addObject:dot];

        UIImageView *icon = [[UIImageView alloc] initWithFrame:CGRectZero];
        icon.contentMode = UIViewContentModeScaleAspectFit;
        if (@available(iOS 13.0, *)) {
            icon.preferredSymbolConfiguration =
            [UIImageSymbolConfiguration configurationWithPointSize:11
                                                            weight:UIImageSymbolWeightSemibold
                                                             scale:UIImageSymbolScaleMedium];
        }
        [dot addSubview:icon];
        [self.iconViews addObject:icon];

        UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.text = self.steps[i];
        label.font = [GM MidFontWithSize:11];
        label.textColor = UIColor.secondaryLabelColor;
        label.textAlignment = NSTextAlignmentCenter;
        label.numberOfLines = 1;
        label.adjustsFontSizeToFitWidth = YES;
        label.minimumScaleFactor = 0.72;
        label.lineBreakMode = NSLineBreakByTruncatingTail;
        [self addSubview:label];
        [self.labelViews addObject:label];
    }

    for (NSInteger i = 0; i < MAX(0, count - 1); i++) {
        UIView *connector = [[UIView alloc] initWithFrame:CGRectZero];
        connector.layer.cornerRadius = 1.0;
        connector.layer.masksToBounds = YES;
        [self insertSubview:connector atIndex:0];
        [self.connectorViews addObject:connector];
    }
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];

    if (!self.window) {
        [self stopCurrentStatusMotion];
        return;
    }

    [self setNeedsLayout];
}

- (NSInteger)visualIndexForLogicalIndex:(NSInteger)logicalIndex
{
    if ([Language languageVal] == 1) {
        return MAX(0, (NSInteger)self.steps.count - 1 - logicalIndex);
    }
    return logicalIndex;
}

- (CGFloat)centerXForVisualIndex:(NSInteger)visualIndex
{
    NSInteger count = self.steps.count;
    if (count <= 0) return 0.0;

    CGFloat maxDotSize = 30.0;
    CGFloat leadingInset = 8.0;
    CGFloat trailingInset = 8.0;
    CGFloat minCenter = leadingInset + (maxDotSize * 0.5);
    CGFloat maxCenter = MAX(minCenter, self.bounds.size.width - trailingInset - (maxDotSize * 0.5));
    if (count == 1) return (minCenter + maxCenter) * 0.5;

    CGFloat progress = (CGFloat)visualIndex / (CGFloat)(count - 1);
    return minCenter + ((maxCenter - minCenter) * progress);
}

- (BOOL)shouldRunCurrentStatusMotion
{
    return (self.window != nil && !UIAccessibilityIsReduceMotionEnabled());
}

- (void)removeCurrentStatusMotionFromDot:(UIView *)dot
                                    halo:(UIView *)halo
                                    icon:(UIImageView *)icon
                                   label:(UILabel *)label
{
    NSArray<NSString *> *dotKeys = @[PPOrderStepperCurrentDotMotionKey, PPOrderStepperLegacyDotPulseKey];
    for (NSString *key in dotKeys) {
        [dot.layer removeAnimationForKey:key];
    }

    NSArray<NSString *> *haloKeys = @[
        PPOrderStepperCurrentHaloScaleKey,
        PPOrderStepperCurrentHaloOpacityKey,
        PPOrderStepperLegacyHaloScaleKey,
        PPOrderStepperLegacyHaloOpacityKey
    ];
    for (NSString *key in haloKeys) {
        [halo.layer removeAnimationForKey:key];
    }

    [icon.layer removeAnimationForKey:PPOrderStepperCurrentIconMotionKey];
    [label.layer removeAnimationForKey:PPOrderStepperCurrentLabelFloatKey];
    [label.layer removeAnimationForKey:PPOrderStepperCurrentLabelOpacityKey];
}

- (void)stopCurrentStatusMotion
{
    NSInteger count = MIN(self.dotViews.count, self.haloViews.count);
    for (NSInteger index = 0; index < count; index++) {
        UIImageView *icon = (index < self.iconViews.count) ? self.iconViews[index] : nil;
        UILabel *label = (index < self.labelViews.count) ? self.labelViews[index] : nil;
        [self removeCurrentStatusMotionFromDot:self.dotViews[index]
                                          halo:self.haloViews[index]
                                          icon:icon
                                         label:label];
    }
}

- (void)applyScalePulseToLayer:(CALayer *)layer
                           key:(NSString *)key
                     fromScale:(CGFloat)fromScale
                       toScale:(CGFloat)toScale
                      duration:(CFTimeInterval)duration
                    beginDelay:(CFTimeInterval)beginDelay
{
    if (!layer || key.length == 0 || [layer animationForKey:key]) return;

    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    anim.fromValue = @(fromScale);
    anim.toValue = @(toScale);
    anim.duration = duration;
    anim.autoreverses = YES;
    anim.repeatCount = HUGE_VALF;
    anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    anim.beginTime = CACurrentMediaTime() + beginDelay;
    [layer addAnimation:anim forKey:key];
}

- (void)applyOpacityPulseToLayer:(CALayer *)layer
                             key:(NSString *)key
                            from:(CGFloat)fromValue
                              to:(CGFloat)toValue
                        duration:(CFTimeInterval)duration
                      beginDelay:(CFTimeInterval)beginDelay
{
    if (!layer || key.length == 0 || [layer animationForKey:key]) return;

    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"opacity"];
    anim.fromValue = @(fromValue);
    anim.toValue = @(toValue);
    anim.duration = duration;
    anim.autoreverses = YES;
    anim.repeatCount = HUGE_VALF;
    anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    anim.beginTime = CACurrentMediaTime() + beginDelay;
    [layer addAnimation:anim forKey:key];
}

- (void)applyVerticalFloatToLayer:(CALayer *)layer
                              key:(NSString *)key
                         distance:(CGFloat)distance
                         duration:(CFTimeInterval)duration
                       beginDelay:(CFTimeInterval)beginDelay
{
    if (!layer || key.length == 0 || [layer animationForKey:key]) return;

    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
    anim.fromValue = @(0.0);
    anim.toValue = @(-fabs(distance));
    anim.duration = duration;
    anim.autoreverses = YES;
    anim.repeatCount = HUGE_VALF;
    anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    anim.beginTime = CACurrentMediaTime() + beginDelay;
    [layer addAnimation:anim forKey:key];
}

- (void)applyCurrentStatusMotionToDot:(UIView *)dot
                                  halo:(UIView *)halo
                                  icon:(UIImageView *)icon
                                 label:(UILabel *)label
                            errorState:(BOOL)isError
{
    if (![self shouldRunCurrentStatusMotion]) return;

    [self applyScalePulseToLayer:dot.layer
                             key:PPOrderStepperCurrentDotMotionKey
                       fromScale:1.0
                         toScale:1.055
                        duration:1.85
                      beginDelay:0.0];

    [self applyScalePulseToLayer:halo.layer
                             key:PPOrderStepperCurrentHaloScaleKey
                       fromScale:1.0
                         toScale:(isError ? 1.12 : 1.16)
                        duration:2.65
                      beginDelay:0.08];
    [self applyOpacityPulseToLayer:halo.layer
                               key:PPOrderStepperCurrentHaloOpacityKey
                              from:0.42
                                to:(isError ? 0.78 : 0.86)
                          duration:2.65
                        beginDelay:0.08];

    [self applyScalePulseToLayer:icon.layer
                             key:PPOrderStepperCurrentIconMotionKey
                       fromScale:1.0
                         toScale:1.08
                        duration:1.85
                      beginDelay:0.18];

    [self applyVerticalFloatToLayer:label.layer
                                key:PPOrderStepperCurrentLabelFloatKey
                           distance:1.2
                           duration:2.1
                         beginDelay:0.16];
    [self applyOpacityPulseToLayer:label.layer
                               key:PPOrderStepperCurrentLabelOpacityKey
                              from:0.82
                                to:1.0
                          duration:2.1
                        beginDelay:0.16];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    NSInteger count = self.steps.count;
    if (count <= 0) return;

    UIColor *accentColor = self.progressTintColor ?: [GM appPrimaryColor];
    UIColor *pendingColor = [UIColor tertiarySystemFillColor];
    UIColor *pendingBorder = [UIColor quaternaryLabelColor];
    UIColor *errorColor = UIColor.systemRedColor;

    CGFloat maxDotSize = 30.0;
    CGFloat completedDotSize = 24.0;
    CGFloat pendingDotSize = 22.0;
    CGFloat dotY = 10.0;
    CGFloat labelTop = dotY + maxDotSize + 14.0;
    CGFloat labelHeight = 28.0;
    BOOL shouldAnimateCurrentStatus = [self shouldRunCurrentStatusMotion];

    NSMutableArray<NSNumber *> *centersX = [NSMutableArray arrayWithCapacity:count];
    NSMutableArray<NSNumber *> *dotSizes = [NSMutableArray arrayWithCapacity:count];
    NSMutableArray<NSNumber *> *visualCenters = [NSMutableArray arrayWithCapacity:count];
    for (NSInteger i = 0; i < count; i++) {
        [visualCenters addObject:@0.0];
        [dotSizes addObject:@(pendingDotSize)];
    }

    for (NSInteger i = 0; i < count; i++) {
        NSInteger visualIndex = [self visualIndexForLogicalIndex:i];
        CGFloat centerX = [self centerXForVisualIndex:visualIndex];
        visualCenters[visualIndex] = @(centerX);
    }

    BOOL hasNextStep = (!self.showsFailure && self.currentIndex < (count - 1));

    for (NSInteger i = 0; i < count; i++) {
        NSInteger visualIndex = [self visualIndexForLogicalIndex:i];
        CGFloat centerX = [self centerXForVisualIndex:visualIndex];
        [centersX addObject:@(centerX)];

        UIView *dot = self.dotViews[i];
        UIView *halo = self.haloViews[i];
        UIImageView *icon = self.iconViews[i];
        UILabel *label = self.labelViews[i];
        NSString *baseSymbol = PPOrderStepperSymbolForTitle(self.steps[i], i);

        CGFloat leftBoundary = (visualIndex == 0)
        ? 0.0
        : (([visualCenters[visualIndex - 1] doubleValue] + centerX) * 0.5);
        CGFloat rightBoundary = (visualIndex == (count - 1))
        ? self.bounds.size.width
        : ((centerX + [visualCenters[visualIndex + 1] doubleValue]) * 0.5);
        CGFloat labelInset = 4.0;
        CGFloat labelX = MAX(0.0, leftBoundary + labelInset);
        CGFloat labelWidth = MAX(28.0, rightBoundary - leftBoundary - (labelInset * 2.0));
        label.frame = CGRectMake(labelX, labelTop, labelWidth, labelHeight);

        BOOL isCompleted = (i < self.currentIndex);
        BOOL isCurrent = (i == self.currentIndex);
        BOOL isPending = (i > self.currentIndex);
        BOOL isError = (self.showsFailure && isCurrent);
        CGFloat dotSize = (isCurrent || isError) ? maxDotSize : (isCompleted ? completedDotSize : pendingDotSize);
        CGFloat dotOriginY = dotY + ((maxDotSize - dotSize) * 0.5);
        dotSizes[i] = @(dotSize);

        dot.frame = CGRectMake(centerX - (dotSize * 0.5), dotOriginY, dotSize, dotSize);
        dot.layer.cornerRadius = dotSize * 0.5;
        dot.layer.borderWidth = (isCurrent || isError) ? 1.4 : 1.0;
        CGFloat iconInset = (isCurrent || isError) ? 6.0 : 4.5;
        icon.frame = CGRectInset(dot.bounds, iconInset, iconInset);

        BOOL isActiveStatus = (isCurrent || isError);
        BOOL shouldKeepCurrentMotion = (isActiveStatus && shouldAnimateCurrentStatus);
        if (shouldKeepCurrentMotion) {
            [dot.layer removeAnimationForKey:PPOrderStepperLegacyDotPulseKey];
            [halo.layer removeAnimationForKey:PPOrderStepperLegacyHaloScaleKey];
            [halo.layer removeAnimationForKey:PPOrderStepperLegacyHaloOpacityKey];
        } else {
            [self removeCurrentStatusMotionFromDot:dot halo:halo icon:icon label:label];
        }
        halo.hidden = !(isCurrent || isError);
        halo.frame = CGRectZero;
        halo.layer.shadowOpacity = 0.0;
        halo.layer.shadowRadius = 0.0;
        halo.layer.shadowOffset = CGSizeZero;

        if (isError) {
            dot.backgroundColor = errorColor;
            [dot pp_setBorderColor:errorColor];
            icon.image = PPOrderStepperImage(@"xmark");
            icon.tintColor = UIColor.whiteColor;
            label.textColor = errorColor;
            label.font = [GM boldFontWithSize:12];
        } else if (isCompleted) {
            dot.backgroundColor = accentColor;
            [dot pp_setBorderColor:accentColor];
            icon.image = PPOrderStepperImage(baseSymbol.length > 0 ? baseSymbol : @"checkmark");
            icon.tintColor = UIColor.whiteColor;
            label.textColor = accentColor;
            label.font = [GM MidFontWithSize:11];
        } else if (isCurrent) {
            dot.backgroundColor = accentColor;
            [dot pp_setBorderColor:accentColor];
            icon.image = PPOrderStepperImage(baseSymbol.length > 0 ? baseSymbol : @"smallcircle.filled.circle.fill");
            icon.tintColor = UIColor.whiteColor;
            label.textColor = accentColor;
            label.font = [GM boldFontWithSize:12];
        } else if (isPending) {
            dot.backgroundColor = pendingColor;
            [dot pp_setBorderColor:pendingBorder];
            icon.image = PPOrderStepperImage(baseSymbol.length > 0 ? baseSymbol : @"circle");
            icon.tintColor = UIColor.secondaryLabelColor;
            label.textColor = UIColor.secondaryLabelColor;
            label.font = [GM MidFontWithSize:11];
        }

        if (isCurrent || isError) {
            UIColor *haloColor = isError ? errorColor : accentColor;
            CGFloat haloSize = dotSize + 14.0;
            halo.frame = CGRectMake(centerX - (haloSize * 0.5),
                                    dotOriginY - ((haloSize - dotSize) * 0.5),
                                    haloSize,
                                    haloSize);
            halo.layer.cornerRadius = haloSize * 0.5;
            halo.backgroundColor = [haloColor colorWithAlphaComponent:isError ? 0.14 : 0.18];
            halo.layer.borderWidth = 1.2;
            [halo pp_setBorderColor:[haloColor colorWithAlphaComponent:0.28]];
            halo.layer.shadowColor = haloColor.CGColor;
            halo.layer.shadowOpacity = shouldAnimateCurrentStatus ? (isError ? 0.16 : 0.18) : 0.08;
            halo.layer.shadowRadius = shouldAnimateCurrentStatus ? 9.0 : 4.0;
            halo.layer.shadowOffset = CGSizeZero;
            halo.hidden = NO;
            [self applyCurrentStatusMotionToDot:dot
                                           halo:halo
                                           icon:icon
                                          label:label
                                     errorState:isError];
        }
        icon.hidden = (icon.image == nil);
    }

    for (NSInteger i = 0; i < self.connectorViews.count; i++) {
        UIView *connector = self.connectorViews[i];
        CGFloat leftCenter = [centersX[i] doubleValue];
        CGFloat rightCenter = [centersX[i + 1] doubleValue];
        CGFloat leftDotSize = [dotSizes[i] doubleValue];
        CGFloat rightDotSize = [dotSizes[i + 1] doubleValue];
        CGFloat minX = MIN(leftCenter, rightCenter) + (leftDotSize * 0.5) + 5.0;
        CGFloat maxX = MAX(leftCenter, rightCenter) - (rightDotSize * 0.5) - 5.0;
        connector.frame = CGRectMake(minX, dotY + (maxDotSize * 0.5) - 1.0, MAX(0.0, maxX - minX), 2.0);
        [connector.layer removeAnimationForKey:@"pp_stepper_connector_pulse"];

        BOOL isCompletedConnector = (i < self.currentIndex);
        BOOL isCurrentConnector = (!self.showsFailure && i == self.currentIndex && hasNextStep);
        if (self.showsFailure && i == (self.currentIndex - 1)) {
            connector.backgroundColor = errorColor;
        } else if (isCurrentConnector) {
            connector.backgroundColor = [accentColor colorWithAlphaComponent:0.38];
        } else {
            connector.backgroundColor = isCompletedConnector ? accentColor : [UIColor quaternarySystemFillColor];
        }
    }
}

@end

typedef NS_ENUM(NSInteger, PPOrderProgressTimelineRowState) {
    PPOrderProgressTimelineRowStateCompleted,
    PPOrderProgressTimelineRowStateCurrent,
    PPOrderProgressTimelineRowStateUpcoming,
    PPOrderProgressTimelineRowStateFailure
};

@interface PPOrderProgressTimelineRowView : UIView

- (void)configureWithTitle:(NSString *)title
                  subtitle:(NSString *)subtitle
                  metaText:(NSString *)metaText
                symbolName:(NSString *)symbolName
                     state:(PPOrderProgressTimelineRowState)state
                  expanded:(BOOL)expanded
                 tintColor:(nullable UIColor *)tintColor
                     isRTL:(BOOL)isRTL;
- (CGFloat)preferredHeightForWidth:(CGFloat)width;
- (CGFloat)markerCenterY;
- (CGFloat)trackCenterXForWidth:(CGFloat)width;
- (void)refreshCurrentStatusMotion;

@end

@interface PPOrderProgressTimelineRowView ()

@property (nonatomic, strong) UIView *markerHaloView;
@property (nonatomic, strong) UIView *markerView;
@property (nonatomic, strong) UIImageView *markerIconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *metaLabel;
@property (nonatomic, copy) NSString *titleText;
@property (nonatomic, copy) NSString *subtitleText;
@property (nonatomic, copy) NSString *metaText;
@property (nonatomic, copy) NSString *symbolName;
@property (nonatomic, assign) PPOrderProgressTimelineRowState rowState;
@property (nonatomic, assign) BOOL expanded;
@property (nonatomic, assign) BOOL isRTL;
@property (nonatomic, strong) UIColor *accentColor;

@end

@implementation PPOrderProgressTimelineRowView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.userInteractionEnabled = NO;

        _markerHaloView = [[UIView alloc] initWithFrame:CGRectZero];
        _markerHaloView.hidden = YES;
        [self addSubview:_markerHaloView];

        _markerView = [[UIView alloc] initWithFrame:CGRectZero];
        [self addSubview:_markerView];

        _markerIconView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _markerIconView.contentMode = UIViewContentModeScaleAspectFit;
        [_markerView addSubview:_markerIconView];

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.numberOfLines = 2;
        [self addSubview:_titleLabel];

        _subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _subtitleLabel.numberOfLines = 0;
        [self addSubview:_subtitleLabel];

        _metaLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _metaLabel.numberOfLines = 1;
        [self addSubview:_metaLabel];
    }
    return self;
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    [self refreshCurrentStatusMotion];
}

- (BOOL)pp_shouldRunCurrentStatusMotion
{
    BOOL isCurrentLike = (self.rowState == PPOrderProgressTimelineRowStateCurrent ||
                          self.rowState == PPOrderProgressTimelineRowStateFailure);
    return (isCurrentLike && self.window != nil && !self.hidden && !UIAccessibilityIsReduceMotionEnabled());
}

- (void)pp_addScalePulseToLayer:(CALayer *)layer
                            key:(NSString *)key
                      fromScale:(CGFloat)fromScale
                        toScale:(CGFloat)toScale
                       duration:(CFTimeInterval)duration
                     beginDelay:(CFTimeInterval)beginDelay
{
    if (!layer || key.length == 0 || [layer animationForKey:key]) return;

    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    animation.fromValue = @(fromScale);
    animation.toValue = @(toScale);
    animation.duration = duration;
    animation.autoreverses = YES;
    animation.repeatCount = HUGE_VALF;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    animation.beginTime = CACurrentMediaTime() + beginDelay;
    [layer addAnimation:animation forKey:key];
}

- (void)pp_addOpacityPulseToLayer:(CALayer *)layer
                              key:(NSString *)key
                             from:(CGFloat)fromValue
                               to:(CGFloat)toValue
                         duration:(CFTimeInterval)duration
                       beginDelay:(CFTimeInterval)beginDelay
{
    if (!layer || key.length == 0 || [layer animationForKey:key]) return;

    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    animation.fromValue = @(fromValue);
    animation.toValue = @(toValue);
    animation.duration = duration;
    animation.autoreverses = YES;
    animation.repeatCount = HUGE_VALF;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    animation.beginTime = CACurrentMediaTime() + beginDelay;
    [layer addAnimation:animation forKey:key];
}

- (void)pp_addVerticalFloatToLayer:(CALayer *)layer
                               key:(NSString *)key
                          distance:(CGFloat)distance
                          duration:(CFTimeInterval)duration
                        beginDelay:(CFTimeInterval)beginDelay
{
    if (!layer || key.length == 0 || [layer animationForKey:key]) return;

    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
    animation.fromValue = @(0.0);
    animation.toValue = @(-fabs(distance));
    animation.duration = duration;
    animation.autoreverses = YES;
    animation.repeatCount = HUGE_VALF;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    animation.beginTime = CACurrentMediaTime() + beginDelay;
    [layer addAnimation:animation forKey:key];
}

- (void)pp_stopCurrentStatusMotion
{
    [self.markerView.layer removeAnimationForKey:PPOrderTimelineCurrentMarkerMotionKey];
    [self.markerHaloView.layer removeAnimationForKey:PPOrderTimelineCurrentHaloScaleKey];
    [self.markerHaloView.layer removeAnimationForKey:PPOrderTimelineCurrentHaloOpacityKey];
    [self.markerIconView.layer removeAnimationForKey:PPOrderTimelineCurrentIconMotionKey];
    [self.titleLabel.layer removeAnimationForKey:PPOrderTimelineCurrentTitleFloatKey];
    [self.titleLabel.layer removeAnimationForKey:PPOrderTimelineCurrentTitleOpacityKey];
}

- (void)refreshCurrentStatusMotion
{
    if (![self pp_shouldRunCurrentStatusMotion]) {
        [self pp_stopCurrentStatusMotion];
        return;
    }

    BOOL isFailure = (self.rowState == PPOrderProgressTimelineRowStateFailure);
    [self pp_addScalePulseToLayer:self.markerView.layer
                              key:PPOrderTimelineCurrentMarkerMotionKey
                        fromScale:1.0
                          toScale:1.055
                         duration:1.85
                       beginDelay:0.0];
    [self pp_addScalePulseToLayer:self.markerHaloView.layer
                              key:PPOrderTimelineCurrentHaloScaleKey
                        fromScale:1.0
                          toScale:(isFailure ? 1.13 : 1.18)
                         duration:2.75
                       beginDelay:0.05];
    [self pp_addOpacityPulseToLayer:self.markerHaloView.layer
                                key:PPOrderTimelineCurrentHaloOpacityKey
                               from:0.30
                                 to:(isFailure ? 0.72 : 0.82)
                           duration:2.75
                         beginDelay:0.05];
    [self pp_addScalePulseToLayer:self.markerIconView.layer
                              key:PPOrderTimelineCurrentIconMotionKey
                        fromScale:1.0
                          toScale:1.08
                         duration:1.85
                       beginDelay:0.14];
    [self pp_addVerticalFloatToLayer:self.titleLabel.layer
                                 key:PPOrderTimelineCurrentTitleFloatKey
                            distance:1.1
                            duration:2.25
                          beginDelay:0.12];
    [self pp_addOpacityPulseToLayer:self.titleLabel.layer
                                key:PPOrderTimelineCurrentTitleOpacityKey
                               from:0.82
                                 to:1.0
                           duration:2.25
                         beginDelay:0.12];
}

- (void)configureWithTitle:(NSString *)title
                  subtitle:(NSString *)subtitle
                  metaText:(NSString *)metaText
                symbolName:(NSString *)symbolName
                     state:(PPOrderProgressTimelineRowState)state
                  expanded:(BOOL)expanded
                 tintColor:(UIColor *)tintColor
                     isRTL:(BOOL)isRTL
{
    self.titleText = title ?: @"";
    self.subtitleText = subtitle ?: @"";
    self.metaText = metaText ?: @"";
    self.symbolName = symbolName ?: @"circle";
    self.rowState = state;
    self.expanded = expanded;
    self.isRTL = isRTL;
    self.accentColor = tintColor ?: [GM appPrimaryColor];

    NSTextAlignment alignment = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    self.titleLabel.textAlignment = alignment;
    self.subtitleLabel.textAlignment = alignment;
    self.metaLabel.textAlignment = alignment;
    self.titleLabel.text = self.titleText;
    self.subtitleLabel.text = self.subtitleText;
    self.metaLabel.text = self.metaText;

    UIColor *accent = self.accentColor ?: [GM appPrimaryColor];
    UIColor *errorColor = UIColor.systemRedColor;
    UIColor *upcomingFill = [UIColor tertiarySystemFillColor];
    UIColor *upcomingBorder = [UIColor quaternaryLabelColor];
    UIColor *titleColor = UIColor.labelColor;
    UIColor *subtitleColor = UIColor.secondaryLabelColor;
    UIColor *metaColor = UIColor.tertiaryLabelColor;
    UIColor *markerFill = accent;
    UIColor *markerBorder = accent;
    UIColor *iconTint = UIColor.whiteColor;
    BOOL showHalo = NO;

    switch (state) {
        case PPOrderProgressTimelineRowStateFailure:
            markerFill = errorColor;
            markerBorder = errorColor;
            titleColor = errorColor;
            subtitleColor = [errorColor colorWithAlphaComponent:0.86];
            metaColor = [errorColor colorWithAlphaComponent:0.72];
            showHalo = YES;
            self.titleLabel.font = [GM boldFontWithSize:16];
            break;
        case PPOrderProgressTimelineRowStateCurrent:
            markerFill = accent;
            markerBorder = accent;
            titleColor = accent;
            subtitleColor = UIColor.labelColor;
            metaColor = [accent colorWithAlphaComponent:0.78];
            showHalo = YES;
            self.titleLabel.font = [GM boldFontWithSize:17];
            break;
        case PPOrderProgressTimelineRowStateCompleted:
            markerFill = accent;
            markerBorder = accent;
            titleColor = UIColor.labelColor;
            subtitleColor = UIColor.secondaryLabelColor;
            metaColor = UIColor.tertiaryLabelColor;
            self.titleLabel.font = [GM boldFontWithSize:15];
            break;
        case PPOrderProgressTimelineRowStateUpcoming:
        default:
            markerFill = upcomingFill;
            markerBorder = upcomingBorder;
            iconTint = UIColor.secondaryLabelColor;
            titleColor = UIColor.secondaryLabelColor;
            subtitleColor = UIColor.tertiaryLabelColor;
            metaColor = UIColor.tertiaryLabelColor;
            self.titleLabel.font = [GM MidFontWithSize:15];
            break;
    }

    self.subtitleLabel.font = [GM MidFontWithSize:13];
    self.metaLabel.font = [GM MidFontWithSize:12];
    self.titleLabel.textColor = titleColor;
    self.subtitleLabel.textColor = subtitleColor;
    self.metaLabel.textColor = metaColor;

    self.markerView.backgroundColor = markerFill;
    [self.markerView pp_setBorderColor:markerBorder];
    self.markerView.layer.borderWidth = showHalo ? 1.3 : 1.0;
    self.markerIconView.image = PPOrderStepperImage(self.symbolName);
    self.markerIconView.tintColor = iconTint;

    self.markerHaloView.hidden = !showHalo;
    self.markerHaloView.backgroundColor = [(showHalo ? markerFill : accent) colorWithAlphaComponent:0.18];
    self.markerHaloView.layer.borderWidth = 1.0;
    [self.markerHaloView pp_setBorderColor:[(showHalo ? markerFill : accent) colorWithAlphaComponent:0.26]];

    BOOL showsSecondaryDetails = expanded;
    self.subtitleLabel.hidden = !showsSecondaryDetails || self.subtitleText.length == 0;
    self.metaLabel.hidden = !showsSecondaryDetails || self.metaText.length == 0;
    [self setNeedsLayout];
    [self refreshCurrentStatusMotion];
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width
{
    CGFloat contentWidth = MAX(110.0, width - 56.0);
    CGFloat topPadding = (self.rowState == PPOrderProgressTimelineRowStateCurrent ||
                          self.rowState == PPOrderProgressTimelineRowStateFailure) ? 8.0 : 6.0;
    CGFloat bottomPadding = self.expanded ? 12.0 : 10.0;
    CGFloat titleHeight = ceil([self.titleLabel sizeThatFits:CGSizeMake(contentWidth, CGFLOAT_MAX)].height);
    CGFloat detailsHeight = 0.0;
    if (self.expanded) {
        if (self.subtitleText.length > 0) {
            detailsHeight += 6.0 + ceil([self.subtitleLabel sizeThatFits:CGSizeMake(contentWidth, CGFLOAT_MAX)].height);
        }
        if (self.metaText.length > 0) {
            detailsHeight += 4.0 + ceil([self.metaLabel sizeThatFits:CGSizeMake(contentWidth, CGFLOAT_MAX)].height);
        }
    }

    CGFloat minimumHeight = self.expanded ? 78.0 : 54.0;
    return MAX(minimumHeight, topPadding + titleHeight + detailsHeight + bottomPadding);
}

- (CGFloat)markerCenterY
{
    CGFloat markerSize = (self.rowState == PPOrderProgressTimelineRowStateCurrent ||
                          self.rowState == PPOrderProgressTimelineRowStateFailure) ? 28.0 : 22.0;
    CGFloat topPadding = (self.rowState == PPOrderProgressTimelineRowStateCurrent ||
                          self.rowState == PPOrderProgressTimelineRowStateFailure) ? 8.0 : 6.0;
    return topPadding + (markerSize * 0.5) + 2.0;
}

- (CGFloat)trackCenterXForWidth:(CGFloat)width
{
    return self.isRTL ? (width - 18.0) : 18.0;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat trackCenterX = [self trackCenterXForWidth:width];
    CGFloat markerSize = (self.rowState == PPOrderProgressTimelineRowStateCurrent ||
                          self.rowState == PPOrderProgressTimelineRowStateFailure) ? 28.0 : 22.0;
    CGFloat markerCenterY = [self markerCenterY];
    CGFloat markerX = trackCenterX - (markerSize * 0.5);
    CGFloat markerY = markerCenterY - (markerSize * 0.5);
    self.markerView.frame = CGRectMake(markerX, markerY, markerSize, markerSize);
    self.markerView.layer.cornerRadius = markerSize * 0.5;

    CGFloat haloSize = markerSize + 12.0;
    self.markerHaloView.frame = CGRectMake(trackCenterX - (haloSize * 0.5),
                                           markerCenterY - (haloSize * 0.5),
                                           haloSize,
                                           haloSize);
    self.markerHaloView.layer.cornerRadius = haloSize * 0.5;
    self.markerIconView.frame = CGRectInset(self.markerView.bounds,
                                            (self.rowState == PPOrderProgressTimelineRowStateCurrent ||
                                             self.rowState == PPOrderProgressTimelineRowStateFailure) ? 6.0 : 4.5,
                                            (self.rowState == PPOrderProgressTimelineRowStateCurrent ||
                                             self.rowState == PPOrderProgressTimelineRowStateFailure) ? 6.0 : 4.5);

    CGFloat contentLeading = self.isRTL ? 0.0 : 46.0;
    CGFloat contentWidth = MAX(0.0, width - 46.0);
    CGFloat contentTop = (self.rowState == PPOrderProgressTimelineRowStateCurrent ||
                          self.rowState == PPOrderProgressTimelineRowStateFailure) ? 8.0 : 6.0;
    CGFloat y = contentTop;

    CGSize titleSize = [self.titleLabel sizeThatFits:CGSizeMake(contentWidth, CGFLOAT_MAX)];
    self.titleLabel.frame = CGRectMake(contentLeading, y, contentWidth, ceil(titleSize.height));
    y = CGRectGetMaxY(self.titleLabel.frame);

    if (!self.subtitleLabel.hidden) {
        y += 6.0;
        CGSize subtitleSize = [self.subtitleLabel sizeThatFits:CGSizeMake(contentWidth, CGFLOAT_MAX)];
        self.subtitleLabel.frame = CGRectMake(contentLeading, y, contentWidth, ceil(subtitleSize.height));
        y = CGRectGetMaxY(self.subtitleLabel.frame);
    } else {
        self.subtitleLabel.frame = CGRectZero;
    }

    if (!self.metaLabel.hidden) {
        y += 4.0;
        CGSize metaSize = [self.metaLabel sizeThatFits:CGSizeMake(contentWidth, CGFLOAT_MAX)];
        self.metaLabel.frame = CGRectMake(contentLeading, y, contentWidth, ceil(metaSize.height));
    } else {
        self.metaLabel.frame = CGRectZero;
    }

    [self refreshCurrentStatusMotion];
}

@end

@interface PPOrderProgressTimelineView : UIView

- (void)configureWithStepDescriptors:(NSArray<NSDictionary *> *)stepDescriptors
                        currentIndex:(NSInteger)currentIndex
                        showsFailure:(BOOL)showsFailure
                            expanded:(BOOL)expanded
                           tintColor:(nullable UIColor *)tintColor
                            animated:(BOOL)animated;
- (CGFloat)preferredHeightForWidth:(CGFloat)width;
- (void)refreshCurrentStatusMotion;

@end

@interface PPOrderProgressTimelineView ()

@property (nonatomic, strong) UIView *trackView;
@property (nonatomic, strong) NSMutableArray<PPOrderProgressTimelineRowView *> *rowViews;
@property (nonatomic, copy) NSArray<NSDictionary *> *stepDescriptors;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, assign) BOOL showsFailure;
@property (nonatomic, assign) BOOL expanded;
@property (nonatomic, strong) UIColor *accentColor;

@end

@implementation PPOrderProgressTimelineView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        _trackView = [[UIView alloc] initWithFrame:CGRectZero];
        _trackView.layer.cornerRadius = 1.0;
        [self addSubview:_trackView];
        _rowViews = [NSMutableArray array];
    }
    return self;
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    [self refreshCurrentStatusMotion];
}

- (void)ensureRowCount:(NSInteger)count
{
    while (self.rowViews.count < count) {
        PPOrderProgressTimelineRowView *row = [[PPOrderProgressTimelineRowView alloc] initWithFrame:CGRectZero];
        [self.rowViews addObject:row];
        [self addSubview:row];
    }
    for (NSInteger index = 0; index < self.rowViews.count; index++) {
        self.rowViews[index].hidden = (index >= count);
    }
}

- (void)configureWithStepDescriptors:(NSArray<NSDictionary *> *)stepDescriptors
                        currentIndex:(NSInteger)currentIndex
                        showsFailure:(BOOL)showsFailure
                            expanded:(BOOL)expanded
                           tintColor:(UIColor *)tintColor
                            animated:(BOOL)animated
{
    self.stepDescriptors = stepDescriptors ?: @[];
    self.currentIndex = MAX(0, MIN(currentIndex, MAX((NSInteger)self.stepDescriptors.count - 1, 0)));
    self.showsFailure = showsFailure;
    self.expanded = expanded;
    self.accentColor = tintColor ?: [GM appPrimaryColor];

    [self ensureRowCount:self.stepDescriptors.count];

    BOOL isRTL = [Language isRTL];
    for (NSInteger index = 0; index < self.stepDescriptors.count; index++) {
        NSDictionary *descriptor = self.stepDescriptors[index];
        PPOrderProgressTimelineRowState state = PPOrderProgressTimelineRowStateUpcoming;
        if (showsFailure && index == self.currentIndex) {
            state = PPOrderProgressTimelineRowStateFailure;
        } else if (index < self.currentIndex) {
            state = PPOrderProgressTimelineRowStateCompleted;
        } else if (index == self.currentIndex) {
            state = PPOrderProgressTimelineRowStateCurrent;
        }

        [self.rowViews[index] configureWithTitle:[descriptor[@"title"] isKindOfClass:NSString.class] ? descriptor[@"title"] : @""
                                        subtitle:[descriptor[@"subtitle"] isKindOfClass:NSString.class] ? descriptor[@"subtitle"] : @""
                                        metaText:[descriptor[@"meta"] isKindOfClass:NSString.class] ? descriptor[@"meta"] : @""
                                      symbolName:[descriptor[@"icon"] isKindOfClass:NSString.class] ? descriptor[@"icon"] : @"circle"
                                           state:state
                                        expanded:expanded
                                       tintColor:self.accentColor
                                           isRTL:isRTL];
    }

    if (animated) {
        [UIView transitionWithView:self
                          duration:0.26
                           options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowAnimatedContent
                        animations:^{
            [self setNeedsLayout];
            [self layoutIfNeeded];
        } completion:nil];
    } else {
        [self setNeedsLayout];
    }

    [self refreshCurrentStatusMotion];
}

- (void)refreshCurrentStatusMotion
{
    for (PPOrderProgressTimelineRowView *row in self.rowViews) {
        [row refreshCurrentStatusMotion];
    }
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width
{
    if (self.stepDescriptors.count == 0) return 0.0;

    CGFloat gap = self.expanded ? 12.0 : 7.0;
    CGFloat totalHeight = 0.0;
    for (NSInteger index = 0; index < self.stepDescriptors.count; index++) {
        PPOrderProgressTimelineRowView *row = (index < self.rowViews.count) ? self.rowViews[index] : nil;
        totalHeight += [row preferredHeightForWidth:width];
        if (index < (NSInteger)self.stepDescriptors.count - 1) {
            totalHeight += gap;
        }
    }
    return totalHeight;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat gap = self.expanded ? 12.0 : 7.0;
    CGFloat y = 0.0;
    CGFloat firstMarkerY = 0.0;
    CGFloat lastMarkerY = 0.0;
    CGFloat trackX = [Language isRTL] ? (width - 18.0) : 18.0;

    for (NSInteger index = 0; index < self.stepDescriptors.count; index++) {
        PPOrderProgressTimelineRowView *row = self.rowViews[index];
        row.hidden = NO;
        CGFloat rowHeight = [row preferredHeightForWidth:width];
        row.frame = CGRectMake(0.0, y, width, rowHeight);
        CGFloat markerY = y + [row markerCenterY];
        if (index == 0) firstMarkerY = markerY;
        lastMarkerY = markerY;
        y += rowHeight;
        if (index < (NSInteger)self.stepDescriptors.count - 1) {
            y += gap;
        }
    }

    self.trackView.hidden = (self.stepDescriptors.count < 2);
    self.trackView.backgroundColor = [self.accentColor colorWithAlphaComponent:self.expanded ? 0.18 : 0.12];
    self.trackView.frame = CGRectMake(trackX - 1.0,
                                      firstMarkerY,
                                      2.0,
                                      MAX(0.0, lastMarkerY - firstMarkerY));
    [self sendSubviewToBack:self.trackView];
}

@end

@interface OrderDetailsViewController () <UITableViewDataSource, UITableViewDelegate, MKMapViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *backgroundTopGlowView;
@property (nonatomic, strong) UIView *backgroundBottomGlowView;
@property (nonatomic, strong) CAGradientLayer *backgroundTopGlowLayer;
@property (nonatomic, strong) CAGradientLayer *backgroundBottomGlowLayer;
@property (nonatomic, strong) UIView *headerContainer;
@property (nonatomic, strong) UIView *headerCard;
@property (nonatomic, strong) CAGradientLayer *headerHeroLiquidBorderLayer;
@property (nonatomic, strong) CAShapeLayer *headerHeroLiquidBorderMaskLayer;
@property (nonatomic, strong) CAShapeLayer *headerHeroLiquidHaloLayer;
@property (nonatomic, strong) UILabel *orderIDLabel;
@property (nonatomic, strong) UILabel *orderStatusLabel;
@property (nonatomic, strong) UIView *statusSummaryCard;
@property (nonatomic, strong) UIView *ambientDot1;
@property (nonatomic, strong) UIView *ambientDot2;
@property (nonatomic, strong) UIView *ambientDot3;
@property (nonatomic, strong) UILabel *statusSummarySubtitleLabel;
@property (nonatomic, strong) UIView *statusProgressChip;
@property (nonatomic, strong) UIImageView *statusProgressChipIconView;
@property (nonatomic, strong) UILabel *statusProgressChipLabel;
@property (nonatomic, strong) UIView *statusEtaChip;
@property (nonatomic, strong) UIImageView *statusEtaChipIconView;
@property (nonatomic, strong) UILabel *statusEtaChipLabel;
@property (nonatomic, strong) UILabel *progressTimelineTitleLabel;
@property (nonatomic, strong) UILabel *progressTimelineProgressLabel;
@property (nonatomic, strong) UIButton *progressTimelineToggleButton;
@property (nonatomic, strong) UIImageView *progressTimelineToggleIconView;
@property (nonatomic, strong) PPOrderProgressTimelineView *progressTimelineView;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UILabel *totalPriceLabel;
@property (nonatomic, strong) UILabel *paymentProviderLabel;
@property (nonatomic, strong) UILabel *deliveryAddressLabel;
@property (nonatomic, strong) UIButton *openMapButton;
@property (nonatomic, strong) UIView *statusBadgeHaloView;
@property (nonatomic, strong) UIView *statusBadge;
@property (nonatomic, strong) UIImageView *statusIconView;
@property (nonatomic, strong) UIView *summaryPanel;
@property (nonatomic, strong) UIView *headerSeparatorTop;
@property (nonatomic, strong) UIView *headerSeparatorBottom;

@property (nonatomic, strong) UIView *footerContainer;
@property (nonatomic, strong, nullable) UIView *fulfillmentSectionCard;
@property (nonatomic, strong) UIView *deliveryMapCard;
@property (nonatomic, strong) UILabel *deliveryMapTitleLabel;
@property (nonatomic, strong) UILabel *deliveryMapSubtitleLabel;
@property (nonatomic, strong) MKMapView *deliveryMapView;
@property (nonatomic, strong) UIView *actionButtonsStack;
@property (nonatomic, strong) UIButton *contactSupportButton;
@property (nonatomic, strong) UIButton *editLocationButton;
@property (nonatomic, strong) UIButton *cancelOrderButton;
@property (nonatomic, strong) UIButton *trackOrderButton;
@property (nonatomic, strong) UIButton *viewRequestsButton;
@property (nonatomic, strong) UIButton *returnRequestButton;
@property (nonatomic, strong) UIButton *refundButton;
@property (nonatomic, strong) UIButton *replacementButton;
@property (nonatomic, strong) UIButton *reportIssueButton;
@property (nonatomic, strong) UILabel *postOrderHintLabel;

@property (nonatomic, strong) UIView *loadingOverlay;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, copy, nullable) dispatch_block_t loadingTimeoutBlock;
@property (nonatomic, strong) UIView *checkoutConfettiContainerView;
@property (nonatomic, strong) LOTAnimationView *checkoutConfettiAnimationView;

@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *lineItems;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *accessoryCache;
@property (nonatomic, strong) NSMutableSet<NSString *> *inFlightAccessoryIDs;
@property (nonatomic, strong) NSArray<PPAddressModel *> *availableAddresses;
@property (nonatomic, strong, nullable) PPAddressModel *selectedAddressModel;
@property (nonatomic, strong) PPOrderManager *orderManager;
@property (nonatomic, strong) NSArray<PPOrderSupportRequest *> *supportRequests;
@property (nonatomic, strong) NSArray<PPOrderTimelineEvent *> *timelineEvents;
@property (nonatomic, strong) NSArray<PPOrderEligibilityDecision *> *eligibilityDecisions;
@property (nonatomic, strong) NSArray<PPFulfillmentOrder *> *fulfillmentOrders;
@property (nonatomic, strong) id<FIRListenerRegistration> orderDocumentListener;
@property (nonatomic, strong) id<FIRListenerRegistration> requestsListener;
@property (nonatomic, strong) id<FIRListenerRegistration> timelineListener;
@property (nonatomic, assign) BOOL isOrderDetailsScreenVisible;
@property (nonatomic, copy, nullable) NSString *lastObservedOrderStatusKey;
@property (nonatomic, assign) BOOL didShowEntryPresentation;
@property (nonatomic, assign) BOOL didPlayCheckoutSuccessConfetti;
@property (nonatomic, assign) BOOL isProgressTimelineExpanded;
@property (nonatomic, assign) BOOL prefersBackToMainScreen;
@property (nonatomic, assign) BOOL isResolvingAddress;
@property (nonatomic, assign) NSInteger checkoutConfettiLoadToken;

- (void)pp_playCheckoutSuccessConfettiIfNeeded;
- (void)pp_stopCheckoutSuccessConfetti;
- (void)pp_removeCheckoutSuccessConfettiAnimated:(BOOL)animated;
- (void)pp_installLiveBackgroundGlowLayersIfNeeded;
- (void)pp_updateLiveBackgroundGlowFrames;
- (void)pp_refreshLiveBackgroundGlowColors;
- (void)pp_startLiveBackgroundGlowsIfNeeded;
- (void)pp_stopLiveBackgroundGlows;
- (void)pp_installHeaderHeroLiquidBorderIfNeeded;
- (void)pp_refreshHeaderHeroLiquidBorderColors;
- (void)pp_updateHeaderHeroLiquidBorder;
- (void)pp_updateHeaderHeroLiquidBorderAnimated:(BOOL)animated duration:(NSTimeInterval)duration;
- (void)pp_addHeaderHeroLiquidBorderResizeAnimationToLayer:(CALayer *)layer
                                                   keyPath:(NSString *)keyPath
                                                 fromValue:(id)fromValue
                                                   toValue:(id)toValue
                                                  duration:(NSTimeInterval)duration
                                                       key:(NSString *)key;
- (void)pp_startHeaderHeroLiquidBorderIfNeeded;
- (void)pp_stopHeaderHeroLiquidBorder;
- (void)pp_refreshCurrentStatusSummaryMotionColors;
- (void)pp_startCurrentStatusSummaryMotionIfNeeded;
- (void)pp_stopCurrentStatusSummaryMotion;
- (void)pp_playCurrentStatusChangeFeedback;
- (void)pp_handleReduceMotionStatusDidChange:(NSNotification *)notification;

@end

@implementation OrderDetailsViewController

#pragma mark - Init

- (instancetype)initWithOrder:(PPOrder *)order
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _order = order;
    }
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    return [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [super initWithCoder:coder];
}

- (void)setOrder:(PPOrder *)order
{
    NSString *previousOrderID = [self safeString:_order.orderId];
    _order = order;
    if (!self.isViewLoaded) return;
    [self configureWithCurrentOrder];
    NSString *nextOrderID = [self safeString:order.orderId];
    if (![previousOrderID isEqualToString:nextOrderID]) {
        [self startRealtimeObservers];
    }
}

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleCartPricingConfigurationDidChange:)
                                                 name:kCartPricingConfigurationDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleReduceMotionStatusDidChange:)
                                                 name:UIAccessibilityReduceMotionStatusDidChangeNotification
                                               object:nil];
    [self setupDefaults];
    [self setupViews];
    [self setupNavigationBar];
    [self configureWithCurrentOrder];
    [self startRealtimeObservers];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self setupNavigationBar];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.isOrderDetailsScreenVisible = YES;
    [self showEntryPresentationIfNeeded];
    [self pp_startLiveBackgroundGlowsIfNeeded];
    [self pp_startHeaderHeroLiquidBorderIfNeeded];
    [self pp_startCurrentStatusSummaryMotionIfNeeded];
    [self.progressTimelineView refreshCurrentStatusMotion];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    self.isOrderDetailsScreenVisible = NO;
    [self pp_stopLiveBackgroundGlows];
    [self pp_stopHeaderHeroLiquidBorder];
    [self pp_stopCurrentStatusSummaryMotion];
    [self.progressTimelineView refreshCurrentStatusMotion];
    [self pp_stopCheckoutSuccessConfetti];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self layoutViews];

    if (self.headerCard) {
        [self pp_updateHeaderHeroLiquidBorder];
        // L-03: Refresh shadowPath after Auto Layout resolves final bounds
        self.headerCard.layer.shadowPath =
            [UIBezierPath bezierPathWithRoundedRect:self.headerCard.bounds
                                      cornerRadius:self.headerCard.layer.cornerRadius].CGPath;
    }
    if (self.statusSummaryCard) {
        [self pp_refreshCurrentStatusSummaryMotionColors];
        if (self.isOrderDetailsScreenVisible) {
            [self pp_startCurrentStatusSummaryMotionIfNeeded];
        }
    }
    if (self.progressTimelineToggleButton) {
        [Styling addLiquidGlassBorderToView:self.progressTimelineToggleButton cornerRadius:18 color:[[UIColor whiteColor] colorWithAlphaComponent:0.16]];
    }
    if (self.deliveryMapCard) {
        [Styling addLiquidGlassBorderToView:self.deliveryMapCard cornerRadius:20 color:AppBackgroundClrDarker];
        // L-03: Refresh shadowPath after Auto Layout resolves final bounds
        self.deliveryMapCard.layer.shadowPath =
            [UIBezierPath bezierPathWithRoundedRect:self.deliveryMapCard.bounds
                                      cornerRadius:self.deliveryMapCard.layer.cornerRadius].CGPath;
    }
    self.backgroundTopGlowView.layer.cornerRadius = CGRectGetWidth(self.backgroundTopGlowView.bounds) * 0.5;
    self.backgroundBottomGlowView.layer.cornerRadius = CGRectGetWidth(self.backgroundBottomGlowView.bounds) * 0.5;
    [self pp_updateLiveBackgroundGlowFrames];
}

- (void)pp_installLiveBackgroundGlowLayersIfNeeded
{
    if (!self.backgroundTopGlowLayer && self.backgroundTopGlowView) {
        self.backgroundTopGlowLayer = [CAGradientLayer layer];
        self.backgroundTopGlowLayer.name = @"PPOrderLiveBackgroundTopGlow";
        self.backgroundTopGlowLayer.startPoint = CGPointMake(0.18, 0.16);
        self.backgroundTopGlowLayer.endPoint = CGPointMake(0.92, 0.92);
        self.backgroundTopGlowLayer.locations = @[@0.0, @0.42, @1.0];
        if (@available(iOS 12.0, *)) {
            self.backgroundTopGlowLayer.type = kCAGradientLayerRadial;
        }
        [self.backgroundTopGlowView.layer addSublayer:self.backgroundTopGlowLayer];
    }

    if (!self.backgroundBottomGlowLayer && self.backgroundBottomGlowView) {
        self.backgroundBottomGlowLayer = [CAGradientLayer layer];
        self.backgroundBottomGlowLayer.name = @"PPOrderLiveBackgroundBottomGlow";
        self.backgroundBottomGlowLayer.startPoint = CGPointMake(0.30, 0.20);
        self.backgroundBottomGlowLayer.endPoint = CGPointMake(0.88, 0.88);
        self.backgroundBottomGlowLayer.locations = @[@0.0, @0.48, @1.0];
        if (@available(iOS 12.0, *)) {
            self.backgroundBottomGlowLayer.type = kCAGradientLayerRadial;
        }
        [self.backgroundBottomGlowView.layer addSublayer:self.backgroundBottomGlowLayer];
    }

    self.backgroundTopGlowView.layer.masksToBounds = YES;
    self.backgroundBottomGlowView.layer.masksToBounds = YES;
}

- (void)pp_updateLiveBackgroundGlowFrames
{
    [self pp_installLiveBackgroundGlowLayersIfNeeded];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.backgroundTopGlowLayer.frame = self.backgroundTopGlowView.bounds;
    self.backgroundBottomGlowLayer.frame = self.backgroundBottomGlowView.bounds;
    [CATransaction commit];
    if (self.isOrderDetailsScreenVisible) {
        [self pp_startLiveBackgroundGlowsIfNeeded];
    }
}

- (void)pp_refreshLiveBackgroundGlowColors
{
    [self pp_installLiveBackgroundGlowLayersIfNeeded];
    UIColor *accent = self.order ? [self statusAccentColorForStatusKey:[self customerDisplayStatusKeyForOrder:self.order]] : [GM appPrimaryColor];
    if (!accent) accent = AppPrimaryClr ?: UIColor.systemTealColor;
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    UIColor *ink = isDark ? [UIColor colorWithRed:0.01 green:0.02 blue:0.018 alpha:1.0] : [UIColor colorWithRed:0.04 green:0.055 blue:0.048 alpha:1.0];
    UIColor *mint = [UIColor colorWithRed:0.36 green:0.92 blue:0.74 alpha:1.0];
    UIColor *warm = [UIColor colorWithRed:0.98 green:0.70 blue:0.34 alpha:1.0];

    self.backgroundTopGlowLayer.colors = @[
        (__bridge id)[mint colorWithAlphaComponent:isDark ? 0.26 : 0.20].CGColor,
        (__bridge id)[accent colorWithAlphaComponent:isDark ? 0.16 : 0.12].CGColor,
        (__bridge id)[ink colorWithAlphaComponent:0.0].CGColor
    ];
    self.backgroundBottomGlowLayer.colors = @[
        (__bridge id)[warm colorWithAlphaComponent:isDark ? 0.22 : 0.16].CGColor,
        (__bridge id)[accent colorWithAlphaComponent:isDark ? 0.14 : 0.10].CGColor,
        (__bridge id)[ink colorWithAlphaComponent:0.0].CGColor
    ];
}

- (void)pp_startLiveBackgroundGlowsIfNeeded
{
    [self pp_installLiveBackgroundGlowLayersIfNeeded];
    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self pp_stopLiveBackgroundGlows];
        return;
    }

    if (![self.backgroundTopGlowView.layer animationForKey:@"pp_order_top_glow_drift"]) {
        CAAnimationGroup *drift = [CAAnimationGroup animation];
        CABasicAnimation *x = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
        x.fromValue = @(-8.0);
        x.toValue = @(26.0);
        CABasicAnimation *y = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
        y.fromValue = @(-4.0);
        y.toValue = @(18.0);
        drift.animations = @[x, y];
        drift.duration = 8.6;
        drift.autoreverses = YES;
        drift.repeatCount = HUGE_VALF;
        drift.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.backgroundTopGlowView.layer addAnimation:drift forKey:@"pp_order_top_glow_drift"];
    }

    if (![self.backgroundBottomGlowView.layer animationForKey:@"pp_order_bottom_glow_drift"]) {
        CAAnimationGroup *drift = [CAAnimationGroup animation];
        CABasicAnimation *x = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
        x.fromValue = @(12.0);
        x.toValue = @(-24.0);
        CABasicAnimation *y = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
        y.fromValue = @(10.0);
        y.toValue = @(-14.0);
        drift.animations = @[x, y];
        drift.duration = 9.8;
        drift.autoreverses = YES;
        drift.repeatCount = HUGE_VALF;
        drift.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.backgroundBottomGlowView.layer addAnimation:drift forKey:@"pp_order_bottom_glow_drift"];
    }

    if (![self.backgroundTopGlowLayer animationForKey:@"pp_order_top_glow_breath"]) {
        CABasicAnimation *breath = [CABasicAnimation animationWithKeyPath:@"opacity"];
        breath.fromValue = @0.52;
        breath.toValue = @0.92;
        breath.duration = 5.8;
        breath.autoreverses = YES;
        breath.repeatCount = HUGE_VALF;
        breath.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.backgroundTopGlowLayer addAnimation:breath forKey:@"pp_order_top_glow_breath"];
    }

    if (![self.backgroundBottomGlowLayer animationForKey:@"pp_order_bottom_glow_breath"]) {
        CABasicAnimation *breath = [CABasicAnimation animationWithKeyPath:@"opacity"];
        breath.fromValue = @0.44;
        breath.toValue = @0.82;
        breath.duration = 6.8;
        breath.autoreverses = YES;
        breath.repeatCount = HUGE_VALF;
        breath.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.backgroundBottomGlowLayer addAnimation:breath forKey:@"pp_order_bottom_glow_breath"];
    }
}

- (void)pp_stopLiveBackgroundGlows
{
    [self.backgroundTopGlowView.layer removeAnimationForKey:@"pp_order_top_glow_drift"];
    [self.backgroundBottomGlowView.layer removeAnimationForKey:@"pp_order_bottom_glow_drift"];
    [self.backgroundTopGlowLayer removeAnimationForKey:@"pp_order_top_glow_breath"];
    [self.backgroundBottomGlowLayer removeAnimationForKey:@"pp_order_bottom_glow_breath"];
    self.backgroundTopGlowView.layer.transform = CATransform3DIdentity;
    self.backgroundBottomGlowView.layer.transform = CATransform3DIdentity;
    self.backgroundTopGlowLayer.opacity = UIAccessibilityIsReduceMotionEnabled() ? 0.50 : 0.72;
    self.backgroundBottomGlowLayer.opacity = UIAccessibilityIsReduceMotionEnabled() ? 0.42 : 0.64;
}

#pragma mark - Setup

- (void)setupDefaults
{

    UIColor *premiumBackground = [UIColor colorWithRed:0.98 green:0.97 blue:0.96 alpha:1.0];

    self.view.backgroundColor = AppBageColor();
    self.lineItems = [NSMutableArray array];
    self.accessoryCache = [NSMutableDictionary dictionary];
    self.inFlightAccessoryIDs = [NSMutableSet set];
    self.availableAddresses = @[];
    self.supportRequests = @[];
    self.timelineEvents = @[];
    self.eligibilityDecisions = @[];
    self.orderManager = [PPOrderManager shared];
    self.isResolvingAddress = NO;
    self.didShowEntryPresentation = NO;
    self.didPlayCheckoutSuccessConfetti = NO;
    self.checkoutConfettiLoadToken = 0;
    self.prefersBackToMainScreen = NO;
    self.isOrderDetailsScreenVisible = NO;
    self.isProgressTimelineExpanded = NO;
    self.lastObservedOrderStatusKey = nil;

    self.dateFormatter = [[NSDateFormatter alloc] init];
    self.dateFormatter.locale = [NSLocale currentLocale];
    [self.dateFormatter setLocalizedDateFormatFromTemplate:@"EEE d MMM yyyy h:mm a"];
}

- (BOOL)pp_isPushedFromPaymentSelectionViewController
{
    NSArray<UIViewController *> *viewControllers = self.navigationController.viewControllers ?: @[];
    NSUInteger currentIndex = [viewControllers indexOfObject:self];
    if (currentIndex == NSNotFound || currentIndex == 0) {
        return NO;
    }

    Class paymentSelectionClass = NSClassFromString(@"PPSelectPaymentVC");
    UIViewController *previousViewController = viewControllers[currentIndex - 1];
    return paymentSelectionClass != Nil && [previousViewController isKindOfClass:paymentSelectionClass];
}

- (void)pp_showHomeViewControllerAnimated:(BOOL)animated
{
    UITabBarController *tabBarController = self.tabBarController;
    if (tabBarController.viewControllers.count > 0) {
        UIViewController *homeController = tabBarController.viewControllers.firstObject;
        if ([homeController isKindOfClass:UINavigationController.class]) {
            UINavigationController *homeNavigationController = (UINavigationController *)homeController;
            BOOL isCurrentHomeNavigation = (homeNavigationController == self.navigationController);
            [homeNavigationController popToRootViewControllerAnimated:isCurrentHomeNavigation];
            tabBarController.selectedIndex = 0;
            return;
        }

        if ([homeController isKindOfClass:PPHomeViewController.class]) {
            tabBarController.selectedIndex = 0;
            return;
        }
    }

    for (UIViewController *viewController in self.navigationController.viewControllers ?: @[]) {
        if ([viewController isKindOfClass:PPHomeViewController.class]) {
            [self.navigationController popToViewController:viewController animated:animated];
            return;
        }
    }

    // Fallback: pop to root — keeps the tab bar controller hierarchy intact
    if (self.navigationController) {
        [self.navigationController popToRootViewControllerAnimated:animated];
        return;
    }

    [self dismissViewControllerAnimated:animated completion:nil];
}

- (void)setupNavigationBar
{
    self.prefersBackToMainScreen = [self pp_isPushedFromPaymentSelectionViewController];
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"order_details_title") showBack:NO];

    BOOL isPresentedModally = self.presentingViewController != nil;
    NSString *leftButtonImageName;
    if (isPresentedModally) {
        leftButtonImageName = @"xmark";
    } else if (self.prefersBackToMainScreen) {
        leftButtonImageName = @"house.fill";
    } else {
        leftButtonImageName = PPChevronName;
    }
    if (@available(iOS 13.0, *)) {
        UIImage *backImage = [UIImage systemImageNamed:leftButtonImageName];
        self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithImage:backImage
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(onBackBarButtonTapped)];
    } else {
        UIButton *backButton = [PPButtonHelper pp_buttonWithTitleForBar:nil imageName:leftButtonImageName target:self action:@selector(onBack:)];
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backButton];
    }

    UIButton *supportButton = [PPButtonHelper pp_buttonWithTitleForBar:nil imageName:@"headphones.dots" target:self action:@selector(contactSupportTapped)];
    UIBarButtonItem *supportItem = [[UIBarButtonItem alloc] initWithCustomView:supportButton];
    UIButton *shareButton = [PPButtonHelper pp_buttonWithTitleForBar:nil imageName:@"square.and.arrow.up" target:self action:@selector(shareOrderTapped)];
    UIBarButtonItem *shareItem = [[UIBarButtonItem alloc] initWithCustomView:shareButton];
    self.navigationItem.rightBarButtonItems = @[shareItem, supportItem];
}

- (void)setupViews
{
    self.backgroundTopGlowView = [[UIView alloc] initWithFrame:CGRectZero];
    self.backgroundTopGlowView.userInteractionEnabled = NO;
    self.backgroundTopGlowView.backgroundColor = UIColor.clearColor;
    self.backgroundTopGlowView.alpha = 0.92;
    [self.view addSubview:self.backgroundTopGlowView];

    self.backgroundBottomGlowView = [[UIView alloc] initWithFrame:CGRectZero];
    self.backgroundBottomGlowView.userInteractionEnabled = NO;
    self.backgroundBottomGlowView.backgroundColor = UIColor.clearColor;
    self.backgroundBottomGlowView.alpha = 0.82;
    [self.view addSubview:self.backgroundBottomGlowView];
    [self pp_installLiveBackgroundGlowLayersIfNeeded];

    UITableViewStyle tableStyle = UITableViewStyleGrouped;
    if (@available(iOS 13.0, *)) {
        tableStyle = UITableViewStyleInsetGrouped;
    }
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:tableStyle];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = AppClearClr;
    self.tableView.rowHeight = 96.0;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.sectionFooterHeight = 0.01;
    self.tableView.contentInset = UIEdgeInsetsMake(4.0, 0.0, kOrderDetailsContentBottomInset, 0.0);
    self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
    if (@available(iOS 11.0, *)) {
        self.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    }
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 6.0;
    }
    [self.tableView registerClass:[OrderItemCell class] forCellReuseIdentifier:kOrderDetailsItemCellID];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kOrderDetailsPlaceholderCellID];
    [self.view addSubview:self.tableView];

    [self setupHeaderView];
    [self setupFooterView];
    [self setupLoadingOverlay];
    [self refreshVisualTheme];
}

- (void)setupHeaderView
{
    self.headerContainer = [[UIView alloc] initWithFrame:CGRectZero];
    self.headerContainer.backgroundColor = UIColor.clearColor;

    self.headerCard = [[UIView alloc] initWithFrame:CGRectZero];
    self.headerCard.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:PPIOS26() ? 0.78 : 0.96];
    self.headerCard.layer.cornerRadius = 34.0;
    self.headerCard.layer.masksToBounds = NO;
    [self applyCardShadow:self.headerCard];
    [self.headerContainer addSubview:self.headerCard];
    [self pp_updateHeaderHeroLiquidBorder];

    self.orderIDLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.orderIDLabel.font = [GM MidFontWithSize:12];
    self.orderIDLabel.textColor = UIColor.tertiaryLabelColor;
    self.orderIDLabel.userInteractionEnabled = YES;
    self.orderIDLabel.adjustsFontSizeToFitWidth = YES;
    self.orderIDLabel.minimumScaleFactor = 0.72;
    self.orderIDLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    self.orderIDLabel.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    [self.headerCard addSubview:self.orderIDLabel];
    UITapGestureRecognizer *orderIDTapGesture =
    [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(orderIDTapped)];
    [self.orderIDLabel addGestureRecognizer:orderIDTapGesture];

    self.statusSummaryCard = [[UIView alloc] initWithFrame:CGRectZero];
    self.statusSummaryCard.layer.cornerRadius = 24.0;
    self.statusSummaryCard.layer.masksToBounds = YES;
    [self.headerCard addSubview:self.statusSummaryCard];

    self.ambientDot1 = [[UIView alloc] initWithFrame:CGRectZero];
    self.ambientDot1.userInteractionEnabled = NO;
    [self.statusSummaryCard addSubview:self.ambientDot1];

    self.ambientDot2 = [[UIView alloc] initWithFrame:CGRectZero];
    self.ambientDot2.userInteractionEnabled = NO;
    [self.statusSummaryCard addSubview:self.ambientDot2];

    self.ambientDot3 = [[UIView alloc] initWithFrame:CGRectZero];
    self.ambientDot3.userInteractionEnabled = NO;
    [self.statusSummaryCard addSubview:self.ambientDot3];

    self.statusBadgeHaloView = [[UIView alloc] initWithFrame:CGRectZero];
    self.statusBadgeHaloView.userInteractionEnabled = NO;
    self.statusBadgeHaloView.layer.masksToBounds = NO;
    self.statusBadgeHaloView.hidden = YES;
    [self.statusSummaryCard addSubview:self.statusBadgeHaloView];

    self.statusBadge = [[UIView alloc] initWithFrame:CGRectZero];
    self.statusBadge.layer.masksToBounds = YES;
    [self.statusSummaryCard addSubview:self.statusBadge];

    self.statusIconView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.statusIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.statusIconView.tintColor = [GM appPrimaryColor];
    [self.statusBadge addSubview:self.statusIconView];

    self.orderStatusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.orderStatusLabel.font = [GM boldFontWithSize:26];
    self.orderStatusLabel.textColor = [GM appPrimaryColor];
    self.orderStatusLabel.adjustsFontSizeToFitWidth = YES;
    self.orderStatusLabel.minimumScaleFactor = 0.74;
    self.orderStatusLabel.numberOfLines = 2;
    [self.statusSummaryCard addSubview:self.orderStatusLabel];

    self.statusSummarySubtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.statusSummarySubtitleLabel.font = [GM MidFontWithSize:14];
    self.statusSummarySubtitleLabel.textColor = UIColor.secondaryLabelColor;
    self.statusSummarySubtitleLabel.numberOfLines = 0;
    [self.statusSummaryCard addSubview:self.statusSummarySubtitleLabel];

    self.statusProgressChip = [[UIView alloc] initWithFrame:CGRectZero];
    self.statusProgressChip.layer.cornerRadius = 16.0;
    self.statusProgressChip.layer.masksToBounds = YES;
    [self.statusSummaryCard addSubview:self.statusProgressChip];

    self.statusProgressChipIconView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.statusProgressChipIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.statusProgressChipIconView.image = [UIImage systemImageNamed:@"circle.grid.2x2.fill"];
    [self.statusProgressChip addSubview:self.statusProgressChipIconView];

    self.statusProgressChipLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.statusProgressChipLabel.font = [GM boldFontWithSize:13];
    [self.statusProgressChip addSubview:self.statusProgressChipLabel];

    self.statusEtaChip = [[UIView alloc] initWithFrame:CGRectZero];
    self.statusEtaChip.layer.cornerRadius = 16.0;
    self.statusEtaChip.layer.masksToBounds = YES;
    [self.statusSummaryCard addSubview:self.statusEtaChip];

    self.statusEtaChipIconView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.statusEtaChipIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.statusEtaChipIconView.image = [UIImage systemImageNamed:@"clock.fill"];
    [self.statusEtaChip addSubview:self.statusEtaChipIconView];

    self.statusEtaChipLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.statusEtaChipLabel.font = [GM boldFontWithSize:13];
    [self.statusEtaChip addSubview:self.statusEtaChipLabel];

    self.progressTimelineTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.progressTimelineTitleLabel.font = [GM boldFontWithSize:18];
    self.progressTimelineTitleLabel.textColor = UIColor.labelColor;
    self.progressTimelineTitleLabel.text = kLang(@"order_tracking_title");
    [self.headerCard addSubview:self.progressTimelineTitleLabel];

    self.progressTimelineProgressLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.progressTimelineProgressLabel.font = [GM boldFontWithSize:13];
    self.progressTimelineProgressLabel.textColor = [GM appPrimaryColor];
    [self.headerCard addSubview:self.progressTimelineProgressLabel];

    self.progressTimelineToggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.progressTimelineToggleButton.layer.cornerRadius = 18.0;
    self.progressTimelineToggleButton.layer.masksToBounds = YES;
    self.progressTimelineToggleButton.accessibilityLabel = @"Toggle order timeline";
    self.progressTimelineToggleButton.accessibilityHint = @"Expands or collapses the order progress timeline";
    self.progressTimelineToggleButton.accessibilityTraits = UIAccessibilityTraitButton;
    [self.progressTimelineToggleButton addTarget:self action:@selector(toggleProgressTimelineTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.headerCard addSubview:self.progressTimelineToggleButton];

    self.progressTimelineToggleIconView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.progressTimelineToggleIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.progressTimelineToggleIconView.image = [UIImage systemImageNamed:@"chevron.down"];
    [self.progressTimelineToggleButton addSubview:self.progressTimelineToggleIconView];

    self.progressTimelineView = [[PPOrderProgressTimelineView alloc] initWithFrame:CGRectZero];
    [self.headerCard addSubview:self.progressTimelineView];

    self.headerSeparatorTop = [[UIView alloc] initWithFrame:CGRectZero];
    self.headerSeparatorTop.hidden = YES;

    self.headerSeparatorBottom = [[UIView alloc] initWithFrame:CGRectZero];
    self.headerSeparatorBottom.hidden = YES;

    self.summaryPanel = [[UIView alloc] initWithFrame:CGRectZero];
    self.summaryPanel.layer.cornerRadius = 22.0;
    self.summaryPanel.layer.masksToBounds = YES;
    self.summaryPanel.backgroundColor = AppForgroundColr;
    self.summaryPanel.layer.borderWidth = 1.0;
    [self.summaryPanel pp_setBorderColor:[[UIColor labelColor] colorWithAlphaComponent:0.12]];
    [self.headerCard addSubview:self.summaryPanel];

    self.dateLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.dateLabel.font = [GM MidFontWithSize:13];
    self.dateLabel.textColor = UIColor.secondaryLabelColor;
    self.dateLabel.numberOfLines = 0;
    self.dateLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [self.summaryPanel addSubview:self.dateLabel];

    self.totalPriceLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.totalPriceLabel.font = [GM boldFontWithSize:28];
    self.totalPriceLabel.textColor = UIColor.labelColor;
    self.totalPriceLabel.numberOfLines = 0;
    self.totalPriceLabel.adjustsFontSizeToFitWidth = YES;
    self.totalPriceLabel.minimumScaleFactor = 0.68;
    [self.summaryPanel addSubview:self.totalPriceLabel];

    self.paymentProviderLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.paymentProviderLabel.font = [GM MidFontWithSize:13];
    self.paymentProviderLabel.textColor = UIColor.secondaryLabelColor;
    self.paymentProviderLabel.numberOfLines = 0;
    self.paymentProviderLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [self.summaryPanel addSubview:self.paymentProviderLabel];

    self.deliveryAddressLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.deliveryAddressLabel.font = [GM MidFontWithSize:14];
    self.deliveryAddressLabel.textColor = UIColor.secondaryLabelColor;
    self.deliveryAddressLabel.numberOfLines = 2;
    self.deliveryAddressLabel.hidden = YES;

    self.tableView.tableHeaderView = self.headerContainer;
}

- (void)setupFooterView
{
    self.footerContainer = [[UIView alloc] initWithFrame:CGRectZero];
    self.footerContainer.backgroundColor = UIColor.clearColor;

    self.fulfillmentSectionCard = [[UIView alloc] initWithFrame:CGRectZero];
    self.fulfillmentSectionCard.hidden = YES;
    [self.footerContainer addSubview:self.fulfillmentSectionCard];

    self.deliveryMapCard = [[UIView alloc] initWithFrame:CGRectZero];
    self.deliveryMapCard.backgroundColor = [AppForgroundColr colorWithAlphaComponent:PPIOS26() ? 0.82 : 0.97];
    self.deliveryMapCard.layer.cornerRadius = 20.0;
    self.deliveryMapCard.layer.masksToBounds = NO;
    [self applyCardShadow:self.deliveryMapCard];
    [self.footerContainer addSubview:self.deliveryMapCard];

    self.deliveryMapTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.deliveryMapTitleLabel.font = [GM boldFontWithSize:18];
    self.deliveryMapTitleLabel.textColor = UIColor.labelColor;
    self.deliveryMapTitleLabel.text = kLang(@"DeliveryLocation");
    self.deliveryMapTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.deliveryMapCard addSubview:self.deliveryMapTitleLabel];

    self.deliveryMapSubtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.deliveryMapSubtitleLabel.font = [GM MidFontWithSize:14];
    self.deliveryMapSubtitleLabel.textColor = UIColor.secondaryLabelColor;
    self.deliveryMapSubtitleLabel.numberOfLines = 3;
    self.deliveryMapSubtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.deliveryMapCard addSubview:self.deliveryMapSubtitleLabel];

    self.openMapButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.openMapButton.backgroundColor = [[GM appPrimaryColor] colorWithAlphaComponent:0.10];
    self.openMapButton.layer.cornerRadius = 14.0;
    self.openMapButton.layer.masksToBounds = YES;
    self.openMapButton.tintColor = [GM appPrimaryColor];
    self.openMapButton.layer.borderWidth = 1.0;
    [self.openMapButton pp_setBorderColor:[[GM appPrimaryColor] colorWithAlphaComponent:0.16]];
    [self.openMapButton setImage:[UIImage systemImageNamed:@"map.fill"] forState:UIControlStateNormal];
    [self.openMapButton addTarget:self action:@selector(openMapTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.deliveryMapCard addSubview:self.openMapButton];

    self.deliveryMapView = [[MKMapView alloc] initWithFrame:CGRectZero];
    self.deliveryMapView.delegate = self;
    self.deliveryMapView.layer.cornerRadius = 18.0;
    self.deliveryMapView.layer.masksToBounds = YES;
    self.deliveryMapView.layer.borderWidth = 1.0;
    [self.deliveryMapView pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:0.22]];
    self.deliveryMapView.scrollEnabled = NO;
    self.deliveryMapView.zoomEnabled = NO;
    self.deliveryMapView.rotateEnabled = NO;
    self.deliveryMapView.pitchEnabled = NO;
    self.deliveryMapView.showsCompass = NO;
    [self.deliveryMapCard addSubview:self.deliveryMapView];

    UITapGestureRecognizer *mapTapGesture =
    [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openMapTapped)];
    [self.deliveryMapView addGestureRecognizer:mapTapGesture];

    self.actionButtonsStack = [[UIView alloc] initWithFrame:CGRectZero];
    [self.footerContainer addSubview:self.actionButtonsStack];

    self.contactSupportButton = [self actionButtonWithTitle:kLang(@"order_support_button")
                                                      image:@"headphones"
                                                  tintColor:[GM appPrimaryColor]
                                                   selector:@selector(contactSupportTapped)];
    self.editLocationButton = [self actionButtonWithTitle:kLang(@"order_change_delivery_address")
                                                    image:@"mappin.and.ellipse"
                                                tintColor:[GM appPrimaryColor]
                                                 selector:@selector(editLocationTapped)];
    self.cancelOrderButton = [self actionButtonWithTitle:kLang(@"order_cancel_button")
                                                   image:@"xmark.circle"
                                               tintColor:UIColor.systemRedColor
                                                selector:@selector(cancelOrderTapped)];
    self.trackOrderButton = [self actionButtonWithTitle:[PPOrderManager displayTitleForActionType:PPOrderCustomerActionTypeTrack]
                                                  image:@"point.bottomleft.forward.to.arrow.triangle.scurvepath"
                                              tintColor:[GM appPrimaryColor]
                                               selector:@selector(trackOrderTapped)];
    self.viewRequestsButton = [self actionButtonWithTitle:kLang(@"order_requests_history_title")
                                                    image:@"list.bullet.rectangle"
                                                tintColor:[GM appPrimaryColor]
                                                 selector:@selector(viewRequestsTapped)];
    self.returnRequestButton = [self actionButtonWithTitle:[PPOrderManager displayTitleForActionType:PPOrderCustomerActionTypeReturn]
                                                     image:@"arrow.uturn.backward.circle"
                                                 tintColor:[GM appPrimaryColor]
                                                  selector:@selector(requestReturnTapped)];
    self.refundButton = [self actionButtonWithTitle:[PPOrderManager displayTitleForActionType:PPOrderCustomerActionTypeRefund]
                                              image:@"banknote"
                                          tintColor:[GM appPrimaryColor]
                                           selector:@selector(requestRefundTapped)];
    self.replacementButton = [self actionButtonWithTitle:[PPOrderManager displayTitleForActionType:PPOrderCustomerActionTypeReplacement]
                                                   image:@"arrow.triangle.2.circlepath.circle"
                                               tintColor:[GM appPrimaryColor]
                                                selector:@selector(requestReplacementTapped)];
    self.reportIssueButton = [self actionButtonWithTitle:[PPOrderManager displayTitleForActionType:PPOrderCustomerActionTypeComplaint]
                                                   image:@"exclamationmark.bubble"
                                               tintColor:[GM appPrimaryColor]
                                                selector:@selector(reportIssueTapped)];

    [self.deliveryMapCard addSubview:self.editLocationButton];
    [self.actionButtonsStack addSubview:self.trackOrderButton];
    [self.actionButtonsStack addSubview:self.viewRequestsButton];
    [self.actionButtonsStack addSubview:self.contactSupportButton];
    [self.actionButtonsStack addSubview:self.cancelOrderButton];
    [self.actionButtonsStack addSubview:self.returnRequestButton];
    [self.actionButtonsStack addSubview:self.replacementButton];
    [self.actionButtonsStack addSubview:self.refundButton];
    [self.actionButtonsStack addSubview:self.reportIssueButton];

    self.postOrderHintLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.postOrderHintLabel.font = [GM MidFontWithSize:13];
    self.postOrderHintLabel.textColor = UIColor.secondaryLabelColor;
    self.postOrderHintLabel.numberOfLines = 0;
    self.postOrderHintLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.footerContainer addSubview:self.postOrderHintLabel];

    self.tableView.tableFooterView = self.footerContainer;
    [self refreshActionButtonAppearances];
}

- (UIButton *)actionButtonWithTitle:(NSString *)title image:(NSString *)imageName tintColor:(UIColor *)tintColor selector:(SEL)selector
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.backgroundColor = AppForgroundColr;
    button.layer.cornerRadius = kOrderDetailsButtonCornerRadius;
    button.layer.masksToBounds = YES;
    UIFont *buttonFont = [GM MidFontWithSize:15];
    button.titleLabel.numberOfLines = 2;
    button.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    button.layer.borderWidth = 1.0;
    [button pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.08]];


    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *config = [UIButtonConfiguration glassButtonConfiguration];
        config.attributedTitle = [[NSAttributedString alloc] initWithString:(title ?: @"")
                                                                 attributes:@{
            NSFontAttributeName: buttonFont,
            NSForegroundColorAttributeName: tintColor ?: UIColor.labelColor
        }];
        config.image = [UIImage systemImageNamed:imageName];
        config.imagePlacement = NSDirectionalRectEdgeLeading;
        config.imagePadding = 10.0;
        config.baseForegroundColor = tintColor;
        config.contentInsets = NSDirectionalEdgeInsetsMake(10.0, 14.0, 10.0, 14.0);
        config.background.backgroundColor = AppClearClr;
        config.background.cornerRadius = kOrderDetailsButtonCornerRadius;
        config.cornerStyle = UIButtonConfigurationCornerStyleFixed;
        button.configuration = config;
    }

    else if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = [UIButtonConfiguration tintedButtonConfiguration];
        config.attributedTitle = [[NSAttributedString alloc] initWithString:(title ?: @"")
                                                                 attributes:@{
            NSFontAttributeName: buttonFont,
            NSForegroundColorAttributeName: tintColor ?: UIColor.labelColor
        }];
        config.image = [UIImage systemImageNamed:imageName];
        config.imagePlacement = NSDirectionalRectEdgeLeading;
        config.imagePadding = 10.0;
        config.baseForegroundColor = tintColor;
        config.contentInsets = NSDirectionalEdgeInsetsMake(12.0, 14.0, 12.0, 14.0);
        config.background.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.96];
        config.background.cornerRadius = kOrderDetailsButtonCornerRadius;
        config.cornerStyle = UIButtonConfigurationCornerStyleFixed;
        button.configuration = config;
    } else {
        [button setTitle:title forState:UIControlStateNormal];
        [button setTitleColor:tintColor forState:UIControlStateNormal];
        [button setImage:[UIImage systemImageNamed:imageName] forState:UIControlStateNormal];
        button.tintColor = tintColor;
        button.imageEdgeInsets = UIEdgeInsetsMake(0, -8, 0, 8);
        button.contentEdgeInsets = UIEdgeInsetsMake(10, 12, 10, 12);
        button.layer.cornerRadius = kOrderDetailsButtonCornerRadius;
        button.clipsToBounds = YES;
    }
    button.titleLabel.font = buttonFont;
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
     return button;
}

- (void)setupLoadingOverlay
{
    self.loadingOverlay = [[UIView alloc] initWithFrame:CGRectZero];
    self.loadingOverlay.hidden = YES;
    self.loadingOverlay.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.28];
    [self.view addSubview:self.loadingOverlay];

    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.loadingIndicator.hidesWhenStopped = YES;
    self.loadingIndicator.color = [GM appPrimaryColor];
    [self.loadingOverlay addSubview:self.loadingIndicator];
}

- (void)layoutViews
{
    CGFloat width = CGRectGetWidth(self.view.bounds);
    CGFloat height = CGRectGetHeight(self.view.bounds);
    self.tableView.frame = self.view.bounds;
    [self pp_applyPremiumBottomContentInset];
    self.loadingOverlay.frame = self.view.bounds;
    self.loadingIndicator.center = self.loadingOverlay.center;
    self.backgroundTopGlowView.frame = CGRectMake(-72.0,
                                                  self.view.safeAreaInsets.top - 48.0,
                                                  MIN(240.0, width * 0.58),
                                                  MIN(240.0, width * 0.58));
    self.backgroundBottomGlowView.frame = CGRectMake(width - MIN(210.0, width * 0.52) + 36.0,
                                                     MIN(height * 0.42, 320.0),
                                                     MIN(210.0, width * 0.52),
                                                     MIN(210.0, width * 0.52));

    [self layoutHeaderView];
    [self layoutFooterView];
}

- (void)pp_applyPremiumBottomContentInset
{
    if (!self.tableView) {
        return;
    }
    UIEdgeInsets contentInset = self.tableView.contentInset;
    contentInset.top = MAX(contentInset.top, 4.0);
    contentInset.bottom = MAX(contentInset.bottom, kOrderDetailsContentBottomInset);
    self.tableView.contentInset = contentInset;

    UIEdgeInsets indicatorInset = self.tableView.scrollIndicatorInsets;
    indicatorInset.top = MAX(indicatorInset.top, 4.0);
    indicatorInset.bottom = MAX(indicatorInset.bottom, kOrderDetailsContentBottomInset);
    self.tableView.scrollIndicatorInsets = indicatorInset;
}

- (void)layoutHeaderView
{
    CGFloat width = self.view.bounds.size.width;
    CGFloat cardX = 16.0;
    CGFloat cardWidth = MAX(0.0, width - 32.0);
    self.headerContainer.frame = CGRectMake(0, 0, width, 1.0);
    self.headerCard.frame = CGRectMake(cardX, 8.0, cardWidth, 1.0);

    BOOL isRTL = ([Language languageVal] == 1);
    NSTextAlignment leading = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    NSTextAlignment trailing = isRTL ? NSTextAlignmentLeft : NSTextAlignmentRight;

    self.orderIDLabel.textAlignment = leading;
    self.orderStatusLabel.textAlignment = leading;
    self.statusSummarySubtitleLabel.textAlignment = leading;
    self.progressTimelineTitleLabel.textAlignment = leading;
    self.progressTimelineProgressLabel.textAlignment = trailing;
    self.headerCard.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.statusSummaryCard.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.dateLabel.textAlignment = leading;
    self.totalPriceLabel.textAlignment = leading;
    self.paymentProviderLabel.textAlignment = leading;

    CGFloat padding = 16.0;
    CGFloat separatorWidth = MAX(0.0, cardWidth - (padding * 2.0));
    CGFloat gap = 10.0;
    CGFloat headerY = 16.0;

    self.orderIDLabel.frame = CGRectMake(padding, headerY, separatorWidth, 18.0);

    CGFloat statusCardY = CGRectGetMaxY(self.orderIDLabel.frame) + 12.0;
    self.statusSummaryCard.frame = CGRectMake(padding, statusCardY, separatorWidth, 1.0);

    CGFloat statusCardInset = 18.0;
    CGFloat badgeSize = 48.0;
    CGFloat badgeX = isRTL ? statusCardInset : (separatorWidth - statusCardInset - badgeSize);
    self.statusBadge.frame = CGRectMake(badgeX, statusCardInset, badgeSize, badgeSize);
    self.statusBadge.layer.cornerRadius = badgeSize * 0.5;
    self.statusBadgeHaloView.frame = CGRectInset(self.statusBadge.frame, -9.0, -9.0);
    self.statusBadgeHaloView.layer.cornerRadius = CGRectGetWidth(self.statusBadgeHaloView.bounds) * 0.5;
    self.statusIconView.frame = CGRectInset(self.statusBadge.bounds, 12.0, 12.0);

    CGFloat textX = isRTL ? (statusCardInset + badgeSize + 14.0) : statusCardInset;
    CGFloat textMaxX = isRTL ? (separatorWidth - statusCardInset) : (CGRectGetMinX(self.statusBadge.frame) - 14.0);
    CGFloat textWidth = MAX(0.0, textMaxX - textX);
    CGSize statusTitleSize = [self.orderStatusLabel sizeThatFits:CGSizeMake(textWidth, CGFLOAT_MAX)];
    self.orderStatusLabel.frame = CGRectMake(textX, statusCardInset + 2.0, textWidth, ceil(statusTitleSize.height));

    CGFloat subtitleY = CGRectGetMaxY(self.orderStatusLabel.frame) + 8.0;
    CGSize subtitleSize = [self.statusSummarySubtitleLabel sizeThatFits:CGSizeMake(textWidth, CGFLOAT_MAX)];
    self.statusSummarySubtitleLabel.frame = CGRectMake(textX,
                                                       subtitleY,
                                                       textWidth,
                                                       ceil(subtitleSize.height));

    CGFloat chipY = CGRectGetMaxY(self.statusSummarySubtitleLabel.frame) + 16.0;
    CGFloat chipHeight = 32.0;
    CGSize progressChipSize = [self.statusProgressChipLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, chipHeight)];
    CGSize etaChipSize = [self.statusEtaChipLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, chipHeight)];
    CGFloat progressChipWidth = MAX(78.0, ceil(progressChipSize.width) + 38.0);
    CGFloat etaChipWidth = MAX(108.0, ceil(etaChipSize.width) + 38.0);
    CGFloat availableChipWidth = separatorWidth - (statusCardInset * 2.0);

    if ((progressChipWidth + etaChipWidth + gap) <= availableChipWidth) {
        if (isRTL) {
            self.statusProgressChip.frame = CGRectMake(separatorWidth - statusCardInset - progressChipWidth,
                                                       chipY,
                                                       progressChipWidth,
                                                       chipHeight);
            CGFloat etaTrail = 16.0;
            CGFloat etaW = CGRectGetMinX(self.statusProgressChip.frame) - gap - etaTrail;
            self.statusEtaChip.frame = CGRectMake(etaTrail, chipY, MAX(0.0, etaW), chipHeight);
        } else {
            self.statusProgressChip.frame = CGRectMake(statusCardInset, chipY, progressChipWidth, chipHeight);
            CGFloat etaX = CGRectGetMaxX(self.statusProgressChip.frame) + gap;
            CGFloat etaW = separatorWidth - 16.0 - etaX;
            self.statusEtaChip.frame = CGRectMake(etaX, chipY, MAX(0.0, etaW), chipHeight);
        }
    } else {
        self.statusProgressChip.frame = CGRectMake(statusCardInset, chipY, availableChipWidth, chipHeight);
        CGFloat etaW = separatorWidth - 16.0 - statusCardInset;
        self.statusEtaChip.frame = CGRectMake(statusCardInset,
                                              CGRectGetMaxY(self.statusProgressChip.frame) + 8.0,
                                              MAX(0.0, etaW),
                                              chipHeight);
    }

    NSArray<UIView *> *chips = @[self.statusProgressChip, self.statusEtaChip];
    NSArray<UIImageView *> *chipIcons = @[self.statusProgressChipIconView, self.statusEtaChipIconView];
    NSArray<UILabel *> *chipLabels = @[self.statusProgressChipLabel, self.statusEtaChipLabel];
    for (NSInteger index = 0; index < chips.count; index++) {
        UIView *chip = chips[index];
        UIImageView *iconView = chipIcons[index];
        UILabel *label = chipLabels[index];
        iconView.frame = CGRectMake(isRTL ? (CGRectGetWidth(chip.bounds) - 26.0) : 10.0, 9.0, 14.0, 14.0);
        CGFloat labelX = isRTL ? 10.0 : CGRectGetMaxX(iconView.frame) + 8.0;
        CGFloat labelWidth = MAX(0.0, CGRectGetWidth(chip.bounds) - 20.0 - 14.0 - 8.0);
        label.frame = CGRectMake(labelX, 7.0, labelWidth, 18.0);
        label.textAlignment = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    }

    CGFloat statusSummaryBottom = MAX(CGRectGetMaxY(self.statusProgressChip.frame), CGRectGetMaxY(self.statusEtaChip.frame));
    CGFloat statusSummaryHeight = statusSummaryBottom + statusCardInset;
    self.statusSummaryCard.frame = CGRectMake(padding, statusCardY, separatorWidth, statusSummaryHeight);

    self.ambientDot1.frame = CGRectMake(-18, -18, 56, 56);
    self.ambientDot1.layer.cornerRadius = 28.0;
    self.ambientDot2.frame = CGRectMake(separatorWidth - 36, statusSummaryHeight - 24, 72, 72);
    self.ambientDot2.layer.cornerRadius = 36.0;
    self.ambientDot3.frame = CGRectMake(separatorWidth * 0.4, statusSummaryHeight - 12, 32, 32);
    self.ambientDot3.layer.cornerRadius = 16.0;

    CGFloat toggleButtonSize = 36.0;
    CGFloat timelineHeaderY = CGRectGetMaxY(self.statusSummaryCard.frame) + 18.0;
    CGFloat toggleX = isRTL ? padding : (cardWidth - padding - toggleButtonSize);
    self.progressTimelineToggleButton.frame = CGRectMake(toggleX, timelineHeaderY - 3.0, toggleButtonSize, toggleButtonSize);
    self.progressTimelineToggleIconView.frame = CGRectInset(self.progressTimelineToggleButton.bounds, 10.0, 10.0);

    CGSize timelineProgressSize = [self.progressTimelineProgressLabel sizeThatFits:CGSizeMake(100.0, 20.0)];
    CGFloat timelineProgressWidth = MIN(96.0, MAX(42.0, ceil(timelineProgressSize.width)));
    CGFloat timelineProgressX = isRTL
    ? (CGRectGetMaxX(self.progressTimelineToggleButton.frame) + 10.0)
    : (CGRectGetMinX(self.progressTimelineToggleButton.frame) - timelineProgressWidth - 10.0);
    self.progressTimelineProgressLabel.frame = CGRectMake(timelineProgressX,
                                                          timelineHeaderY + 6.0,
                                                          timelineProgressWidth,
                                                          18.0);

    CGFloat titleX = padding;
    CGFloat titleWidth = isRTL
    ? MAX(0.0, CGRectGetMinX(self.progressTimelineToggleButton.frame) - 12.0 - titleX)
    : MAX(0.0, CGRectGetMinX(self.progressTimelineProgressLabel.frame) - 12.0 - titleX);
    if (isRTL) {
        titleX = CGRectGetMaxX(self.progressTimelineProgressLabel.frame) + 12.0;
        titleWidth = MAX(0.0, cardWidth - padding - titleX);
    }
    self.progressTimelineTitleLabel.frame = CGRectMake(titleX, timelineHeaderY + 2.0, titleWidth, 26.0);

    CGFloat timelineY = MAX(CGRectGetMaxY(self.progressTimelineTitleLabel.frame),
                            CGRectGetMaxY(self.progressTimelineToggleButton.frame)) + 10.0;
    CGFloat timelineHeight = [self.progressTimelineView preferredHeightForWidth:separatorWidth];
    self.progressTimelineView.frame = CGRectMake(padding, timelineY, separatorWidth, timelineHeight);

    CGFloat summaryY = CGRectGetMaxY(self.progressTimelineView.frame) + 18.0;
    CGFloat summaryPadding = 16.0;
    CGFloat summaryContentWidth = MAX(0.0, separatorWidth - (summaryPadding * 2.0));
    BOOL useStackedSummary = (summaryContentWidth < 248.0);

    if (useStackedSummary) {
        CGFloat totalHeight = MAX(64.0, ceil([self.totalPriceLabel sizeThatFits:CGSizeMake(summaryContentWidth, CGFLOAT_MAX)].height));
        CGFloat dateHeight = MAX(44.0, ceil([self.dateLabel sizeThatFits:CGSizeMake(summaryContentWidth, CGFLOAT_MAX)].height));
        CGFloat paymentHeight = MAX(48.0, ceil([self.paymentProviderLabel sizeThatFits:CGSizeMake(summaryContentWidth, CGFLOAT_MAX)].height));
        CGFloat summaryPanelHeight = 16.0 + totalHeight + 12.0 + dateHeight + 10.0 + paymentHeight + 16.0;
        self.summaryPanel.frame = CGRectMake(padding, summaryY, separatorWidth, summaryPanelHeight);
        self.totalPriceLabel.frame = CGRectMake(summaryPadding, 16.0, summaryContentWidth, totalHeight);
        self.dateLabel.frame = CGRectMake(summaryPadding, CGRectGetMaxY(self.totalPriceLabel.frame) + 12.0, summaryContentWidth, dateHeight);
        self.paymentProviderLabel.frame = CGRectMake(summaryPadding, CGRectGetMaxY(self.dateLabel.frame) + 10.0, summaryContentWidth, paymentHeight);
    } else {
        CGFloat totalHeight = MAX(64.0, ceil([self.totalPriceLabel sizeThatFits:CGSizeMake(summaryContentWidth, CGFLOAT_MAX)].height));
        CGFloat metaTop = 16.0 + totalHeight + 12.0;
        CGFloat metaGap = 12.0;
        CGFloat metaColumnWidth = floor((summaryContentWidth - metaGap) * 0.5);
        CGFloat leadingColumnX = summaryPadding;
        CGFloat trailingColumnX = CGRectGetWidth(self.summaryPanel.bounds) - summaryPadding - metaColumnWidth;
        CGFloat dateHeight = MAX(52.0, ceil([self.dateLabel sizeThatFits:CGSizeMake(metaColumnWidth, CGFLOAT_MAX)].height));
        CGFloat paymentHeight = MAX(52.0, ceil([self.paymentProviderLabel sizeThatFits:CGSizeMake(metaColumnWidth, CGFLOAT_MAX)].height));
        CGFloat metaHeight = MAX(dateHeight, paymentHeight);
        CGFloat summaryPanelHeight = 16.0 + totalHeight + 12.0 + metaHeight + 16.0;
        self.summaryPanel.frame = CGRectMake(padding, summaryY, separatorWidth, summaryPanelHeight);
        trailingColumnX = CGRectGetWidth(self.summaryPanel.bounds) - summaryPadding - metaColumnWidth;

        self.totalPriceLabel.frame = CGRectMake(summaryPadding, 16.0, summaryContentWidth, totalHeight);
        self.paymentProviderLabel.frame = CGRectMake(isRTL ? trailingColumnX : leadingColumnX,
                                                     metaTop,
                                                     metaColumnWidth,
                                                     metaHeight);
        self.dateLabel.frame = CGRectMake(isRTL ? leadingColumnX : trailingColumnX,
                                          metaTop,
                                          metaColumnWidth,
                                          metaHeight);
    }

    self.headerSeparatorBottom.frame = CGRectZero;
    self.headerSeparatorTop.frame = CGRectZero;
    self.deliveryAddressLabel.frame = CGRectZero;

    CGFloat finalCardHeight = CGRectGetMaxY(self.summaryPanel.frame) + 16.0;
    self.headerCard.frame = CGRectMake(cardX, 8.0, cardWidth, finalCardHeight);
    self.headerContainer.frame = CGRectMake(0, 0, width, finalCardHeight + 16.0);
    self.tableView.tableHeaderView = self.headerContainer;

    NSTimeInterval inheritedAnimationDuration = [UIView inheritedAnimationDuration];
    BOOL shouldAnimateLiquidBorder = (inheritedAnimationDuration > 0.0 &&
                                      !UIAccessibilityIsReduceMotionEnabled());
    [self pp_updateHeaderHeroLiquidBorderAnimated:shouldAnimateLiquidBorder
                                         duration:inheritedAnimationDuration];

    if (!CGRectIsEmpty(self.headerCard.bounds)) {
        UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.headerCard.bounds
                                                               cornerRadius:self.headerCard.layer.cornerRadius];
        [CATransaction begin];
        [CATransaction setDisableActions:!shouldAnimateLiquidBorder];
        self.headerCard.layer.shadowPath = shadowPath.CGPath;
        [CATransaction commit];
    }
}

- (void)pp_installHeaderHeroLiquidBorderIfNeeded
{
    if (!self.headerCard) return;

    if (!self.headerHeroLiquidHaloLayer) {
        self.headerHeroLiquidHaloLayer = [CAShapeLayer layer];
        self.headerHeroLiquidHaloLayer.name = @"PPOrderHeaderHeroLiquidHalo";
        self.headerHeroLiquidHaloLayer.fillColor = UIColor.clearColor.CGColor;
        self.headerHeroLiquidHaloLayer.lineCap = kCALineCapRound;
        self.headerHeroLiquidHaloLayer.lineJoin = kCALineJoinRound;
        self.headerHeroLiquidHaloLayer.lineWidth = 1.4;
        self.headerHeroLiquidHaloLayer.opacity = 0.32;
        self.headerHeroLiquidHaloLayer.shadowOffset = CGSizeZero;
        self.headerHeroLiquidHaloLayer.shadowRadius = 12.0;
        self.headerHeroLiquidHaloLayer.shadowOpacity = 0.34;
        self.headerHeroLiquidHaloLayer.zPosition = 998.0;
        [self.headerCard.layer addSublayer:self.headerHeroLiquidHaloLayer];
    }

    if (!self.headerHeroLiquidBorderLayer) {
        self.headerHeroLiquidBorderLayer = [CAGradientLayer layer];
        self.headerHeroLiquidBorderLayer.name = @"PPOrderHeaderHeroLiquidBorder";
        self.headerHeroLiquidBorderLayer.startPoint = CGPointMake(0.0, 0.15);
        self.headerHeroLiquidBorderLayer.endPoint = CGPointMake(1.0, 0.85);
        self.headerHeroLiquidBorderLayer.locations = @[@0.00, @0.18, @0.36, @0.58, @0.78, @1.00];
        self.headerHeroLiquidBorderLayer.zPosition = 999.0;
        [self.headerCard.layer addSublayer:self.headerHeroLiquidBorderLayer];
    }

    if (!self.headerHeroLiquidBorderMaskLayer) {
        self.headerHeroLiquidBorderMaskLayer = [CAShapeLayer layer];
        self.headerHeroLiquidBorderMaskLayer.name = @"PPOrderHeaderHeroLiquidBorderMask";
        self.headerHeroLiquidBorderMaskLayer.fillColor = UIColor.clearColor.CGColor;
        self.headerHeroLiquidBorderMaskLayer.strokeColor = UIColor.blackColor.CGColor;
        self.headerHeroLiquidBorderMaskLayer.lineCap = kCALineCapRound;
        self.headerHeroLiquidBorderMaskLayer.lineJoin = kCALineJoinRound;
        self.headerHeroLiquidBorderMaskLayer.lineWidth = 1.05;
        self.headerHeroLiquidBorderLayer.mask = self.headerHeroLiquidBorderMaskLayer;
    }

    [self pp_refreshHeaderHeroLiquidBorderColors];
}

- (void)pp_refreshHeaderHeroLiquidBorderColors
{
    if (!self.headerHeroLiquidBorderLayer && !self.headerHeroLiquidHaloLayer) return;

    UIColor *accent = self.order ? [self statusAccentColorForStatusKey:[self customerDisplayStatusKeyForOrder:self.order]] : [GM appPrimaryColor];
    if (!accent) {
        accent = AppPrimaryClr ?: [UIColor colorWithRed:0.81 green:0.22 blue:0.36 alpha:1.0];
    }
    UIColor *shine = AppForgroundColr ?: accent;
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    CGFloat accentAlpha = isDark ? 0.50 : 0.38;
    CGFloat shineAlpha = isDark ? 0.42 : 0.32;
    CGFloat whiteAlpha = isDark ? 0.72 : 0.58;

    self.headerHeroLiquidBorderLayer.colors = @[
        (__bridge id)[UIColor.whiteColor colorWithAlphaComponent:0.08].CGColor,
        (__bridge id)[accent colorWithAlphaComponent:accentAlpha].CGColor,
        (__bridge id)[UIColor.whiteColor colorWithAlphaComponent:whiteAlpha].CGColor,
        (__bridge id)[shine colorWithAlphaComponent:shineAlpha].CGColor,
        (__bridge id)[accent colorWithAlphaComponent:accentAlpha * 0.68].CGColor,
        (__bridge id)[UIColor.whiteColor colorWithAlphaComponent:0.10].CGColor
    ];
    self.headerHeroLiquidBorderLayer.opacity = UIAccessibilityIsReduceMotionEnabled() ? 0.70 : 0.84;

    CGColorRef haloColor = [accent colorWithAlphaComponent:isDark ? 0.44 : 0.30].CGColor;
    self.headerHeroLiquidHaloLayer.strokeColor = haloColor;
    self.headerHeroLiquidHaloLayer.shadowColor = haloColor;
}

- (void)pp_updateHeaderHeroLiquidBorder
{
    [self pp_updateHeaderHeroLiquidBorderAnimated:NO duration:0.0];
}

- (void)pp_updateHeaderHeroLiquidBorderAnimated:(BOOL)animated duration:(NSTimeInterval)duration
{
    [self pp_installHeaderHeroLiquidBorderIfNeeded];
    if (!self.headerCard || CGRectIsEmpty(self.headerCard.bounds)) return;

    CGRect bounds = self.headerCard.bounds;
    CGFloat strokeInset = 0.55;
    CGFloat cornerRadius = MAX(0.0, self.headerCard.layer.cornerRadius - strokeInset);
    CGRect strokeRect = CGRectInset(bounds, strokeInset, strokeInset);
    UIBezierPath *strokePath = [UIBezierPath bezierPathWithRoundedRect:strokeRect
                                                           cornerRadius:cornerRadius];

    BOOL shouldAnimateResize = (animated &&
                                duration > 0.0 &&
                                !UIAccessibilityIsReduceMotionEnabled());
    CALayer *borderPresentationLayer = self.headerHeroLiquidBorderLayer.presentationLayer;
    CALayer *maskPresentationLayer = self.headerHeroLiquidBorderMaskLayer.presentationLayer;
    CALayer *haloPresentationLayer = self.headerHeroLiquidHaloLayer.presentationLayer;
    CGRect previousBorderBounds = borderPresentationLayer ? borderPresentationLayer.bounds : self.headerHeroLiquidBorderLayer.bounds;
    CGPoint previousBorderPosition = borderPresentationLayer ? borderPresentationLayer.position : self.headerHeroLiquidBorderLayer.position;
    CGRect previousMaskBounds = maskPresentationLayer ? maskPresentationLayer.bounds : self.headerHeroLiquidBorderMaskLayer.bounds;
    CGPoint previousMaskPosition = maskPresentationLayer ? maskPresentationLayer.position : self.headerHeroLiquidBorderMaskLayer.position;
    CGRect previousHaloBounds = haloPresentationLayer ? haloPresentationLayer.bounds : self.headerHeroLiquidHaloLayer.bounds;
    CGPoint previousHaloPosition = haloPresentationLayer ? haloPresentationLayer.position : self.headerHeroLiquidHaloLayer.position;
    CGPathRef previousMaskPath = NULL;
    CGPathRef previousHaloPath = NULL;
    if (shouldAnimateResize) {
        CAShapeLayer *maskPresentationShape = (CAShapeLayer *)self.headerHeroLiquidBorderMaskLayer.presentationLayer;
        CAShapeLayer *haloPresentationShape = (CAShapeLayer *)self.headerHeroLiquidHaloLayer.presentationLayer;
        if (maskPresentationShape.path) {
            previousMaskPath = CGPathRetain(maskPresentationShape.path);
        } else if (self.headerHeroLiquidBorderMaskLayer.path) {
            previousMaskPath = CGPathRetain(self.headerHeroLiquidBorderMaskLayer.path);
        }
        if (haloPresentationShape.path) {
            previousHaloPath = CGPathRetain(haloPresentationShape.path);
        } else if (self.headerHeroLiquidHaloLayer.path) {
            previousHaloPath = CGPathRetain(self.headerHeroLiquidHaloLayer.path);
        }
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.headerHeroLiquidBorderLayer.frame = bounds;
    self.headerHeroLiquidBorderMaskLayer.frame = bounds;
    self.headerHeroLiquidBorderMaskLayer.path = strokePath.CGPath;
    self.headerHeroLiquidHaloLayer.frame = bounds;
    self.headerHeroLiquidHaloLayer.path = strokePath.CGPath;
    self.headerHeroLiquidHaloLayer.shadowPath = strokePath.CGPath;
    [CATransaction commit];

    if (shouldAnimateResize && !CGRectIsEmpty(previousBorderBounds)) {
        [self pp_addHeaderHeroLiquidBorderResizeAnimationToLayer:self.headerHeroLiquidBorderLayer
                                                         keyPath:@"bounds"
                                                       fromValue:[NSValue valueWithCGRect:previousBorderBounds]
                                                         toValue:[NSValue valueWithCGRect:self.headerHeroLiquidBorderLayer.bounds]
                                                        duration:duration
                                                             key:@"pp_order_liquid_border_bounds_resize"];
        [self pp_addHeaderHeroLiquidBorderResizeAnimationToLayer:self.headerHeroLiquidBorderLayer
                                                         keyPath:@"position"
                                                       fromValue:[NSValue valueWithCGPoint:previousBorderPosition]
                                                         toValue:[NSValue valueWithCGPoint:self.headerHeroLiquidBorderLayer.position]
                                                        duration:duration
                                                             key:@"pp_order_liquid_border_position_resize"];
        [self pp_addHeaderHeroLiquidBorderResizeAnimationToLayer:self.headerHeroLiquidBorderMaskLayer
                                                         keyPath:@"bounds"
                                                       fromValue:[NSValue valueWithCGRect:previousMaskBounds]
                                                         toValue:[NSValue valueWithCGRect:self.headerHeroLiquidBorderMaskLayer.bounds]
                                                        duration:duration
                                                             key:@"pp_order_liquid_mask_bounds_resize"];
        [self pp_addHeaderHeroLiquidBorderResizeAnimationToLayer:self.headerHeroLiquidBorderMaskLayer
                                                         keyPath:@"position"
                                                       fromValue:[NSValue valueWithCGPoint:previousMaskPosition]
                                                         toValue:[NSValue valueWithCGPoint:self.headerHeroLiquidBorderMaskLayer.position]
                                                        duration:duration
                                                             key:@"pp_order_liquid_mask_position_resize"];
        if (previousMaskPath) {
            [self pp_addHeaderHeroLiquidBorderResizeAnimationToLayer:self.headerHeroLiquidBorderMaskLayer
                                                             keyPath:@"path"
                                                           fromValue:(__bridge id)previousMaskPath
                                                             toValue:(__bridge id)strokePath.CGPath
                                                            duration:duration
                                                                 key:@"pp_order_liquid_mask_path_resize"];
        }
        [self pp_addHeaderHeroLiquidBorderResizeAnimationToLayer:self.headerHeroLiquidHaloLayer
                                                         keyPath:@"bounds"
                                                       fromValue:[NSValue valueWithCGRect:previousHaloBounds]
                                                         toValue:[NSValue valueWithCGRect:self.headerHeroLiquidHaloLayer.bounds]
                                                        duration:duration
                                                             key:@"pp_order_liquid_halo_bounds_resize"];
        [self pp_addHeaderHeroLiquidBorderResizeAnimationToLayer:self.headerHeroLiquidHaloLayer
                                                         keyPath:@"position"
                                                       fromValue:[NSValue valueWithCGPoint:previousHaloPosition]
                                                         toValue:[NSValue valueWithCGPoint:self.headerHeroLiquidHaloLayer.position]
                                                        duration:duration
                                                             key:@"pp_order_liquid_halo_position_resize"];
        if (previousHaloPath) {
            [self pp_addHeaderHeroLiquidBorderResizeAnimationToLayer:self.headerHeroLiquidHaloLayer
                                                             keyPath:@"path"
                                                           fromValue:(__bridge id)previousHaloPath
                                                             toValue:(__bridge id)strokePath.CGPath
                                                            duration:duration
                                                                 key:@"pp_order_liquid_halo_path_resize"];
            [self pp_addHeaderHeroLiquidBorderResizeAnimationToLayer:self.headerHeroLiquidHaloLayer
                                                             keyPath:@"shadowPath"
                                                           fromValue:(__bridge id)previousHaloPath
                                                             toValue:(__bridge id)strokePath.CGPath
                                                            duration:duration
                                                                 key:@"pp_order_liquid_halo_shadow_resize"];
        }
    }
    if (previousMaskPath) {
        CGPathRelease(previousMaskPath);
    }
    if (previousHaloPath) {
        CGPathRelease(previousHaloPath);
    }

    [self pp_refreshHeaderHeroLiquidBorderColors];
    if (self.isOrderDetailsScreenVisible) {
        [self pp_startHeaderHeroLiquidBorderIfNeeded];
    }
}

- (void)pp_addHeaderHeroLiquidBorderResizeAnimationToLayer:(CALayer *)layer
                                                   keyPath:(NSString *)keyPath
                                                 fromValue:(id)fromValue
                                                   toValue:(id)toValue
                                                  duration:(NSTimeInterval)duration
                                                       key:(NSString *)key
{
    if (!layer || keyPath.length == 0 || !fromValue || !toValue || duration <= 0.0) return;

    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:keyPath];
    animation.fromValue = fromValue;
    animation.toValue = toValue;
    animation.duration = duration;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    animation.fillMode = kCAFillModeRemoved;
    animation.removedOnCompletion = YES;
    [layer addAnimation:animation forKey:key];
}

- (void)pp_startHeaderHeroLiquidBorderIfNeeded
{
    if (!self.headerCard || UIAccessibilityIsReduceMotionEnabled()) {
        [self pp_stopHeaderHeroLiquidBorder];
        return;
    }

    [self pp_installHeaderHeroLiquidBorderIfNeeded];
    if (CGRectIsEmpty(self.headerCard.bounds)) return;

    if (![self.headerHeroLiquidBorderLayer animationForKey:@"pp_order_liquid_border_locations"]) {
        CABasicAnimation *flow = [CABasicAnimation animationWithKeyPath:@"locations"];
        flow.fromValue = @[@0.00, @0.08, @0.22, @0.38, @0.64, @1.00];
        flow.toValue = @[@0.00, @0.28, @0.50, @0.68, @0.88, @1.00];
        flow.duration = 7.6;
        flow.autoreverses = YES;
        flow.repeatCount = HUGE_VALF;
        flow.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.headerHeroLiquidBorderLayer addAnimation:flow forKey:@"pp_order_liquid_border_locations"];
    }

    if (![self.headerHeroLiquidBorderLayer animationForKey:@"pp_order_liquid_border_drift"]) {
        CABasicAnimation *drift = [CABasicAnimation animationWithKeyPath:@"startPoint"];
        drift.fromValue = [NSValue valueWithCGPoint:CGPointMake(0.0, 0.12)];
        drift.toValue = [NSValue valueWithCGPoint:CGPointMake(0.32, 0.0)];
        drift.duration = 6.4;
        drift.autoreverses = YES;
        drift.repeatCount = HUGE_VALF;
        drift.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.headerHeroLiquidBorderLayer addAnimation:drift forKey:@"pp_order_liquid_border_drift"];
    }

    if (![self.headerHeroLiquidHaloLayer animationForKey:@"pp_order_liquid_border_breath"]) {
        CABasicAnimation *breath = [CABasicAnimation animationWithKeyPath:@"opacity"];
        breath.fromValue = @0.20;
        breath.toValue = @0.42;
        breath.duration = 4.8;
        breath.autoreverses = YES;
        breath.repeatCount = HUGE_VALF;
        breath.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.headerHeroLiquidHaloLayer addAnimation:breath forKey:@"pp_order_liquid_border_breath"];
    }
}

- (void)pp_stopHeaderHeroLiquidBorder
{
    [self.headerHeroLiquidBorderLayer removeAnimationForKey:@"pp_order_liquid_border_locations"];
    [self.headerHeroLiquidBorderLayer removeAnimationForKey:@"pp_order_liquid_border_drift"];
    [self.headerHeroLiquidHaloLayer removeAnimationForKey:@"pp_order_liquid_border_breath"];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.headerHeroLiquidBorderLayer.locations = @[@0.00, @0.18, @0.36, @0.58, @0.78, @1.00];
    self.headerHeroLiquidBorderLayer.startPoint = CGPointMake(0.0, 0.15);
    self.headerHeroLiquidBorderLayer.endPoint = CGPointMake(1.0, 0.85);
    self.headerHeroLiquidHaloLayer.opacity = UIAccessibilityIsReduceMotionEnabled() ? 0.22 : 0.32;
    [CATransaction commit];
}

- (BOOL)pp_shouldRunCurrentStatusSummaryMotion
{
    return (self.isOrderDetailsScreenVisible &&
            self.statusSummaryCard.window != nil &&
            !UIAccessibilityIsReduceMotionEnabled());
}

- (void)pp_addSummaryScalePulseToLayer:(CALayer *)layer
                                   key:(NSString *)key
                             fromScale:(CGFloat)fromScale
                               toScale:(CGFloat)toScale
                              duration:(CFTimeInterval)duration
                            beginDelay:(CFTimeInterval)beginDelay
{
    if (!layer || key.length == 0 || [layer animationForKey:key]) return;

    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    animation.fromValue = @(fromScale);
    animation.toValue = @(toScale);
    animation.duration = duration;
    animation.autoreverses = YES;
    animation.repeatCount = HUGE_VALF;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    animation.beginTime = CACurrentMediaTime() + beginDelay;
    [layer addAnimation:animation forKey:key];
}

- (void)pp_addSummaryOpacityPulseToLayer:(CALayer *)layer
                                     key:(NSString *)key
                                    from:(CGFloat)fromValue
                                      to:(CGFloat)toValue
                                duration:(CFTimeInterval)duration
                              beginDelay:(CFTimeInterval)beginDelay
{
    if (!layer || key.length == 0 || [layer animationForKey:key]) return;

    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    animation.fromValue = @(fromValue);
    animation.toValue = @(toValue);
    animation.duration = duration;
    animation.autoreverses = YES;
    animation.repeatCount = HUGE_VALF;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    animation.beginTime = CACurrentMediaTime() + beginDelay;
    [layer addAnimation:animation forKey:key];
}

- (void)pp_addSummaryVerticalFloatToLayer:(CALayer *)layer
                                      key:(NSString *)key
                                 distance:(CGFloat)distance
                                 duration:(CFTimeInterval)duration
                               beginDelay:(CFTimeInterval)beginDelay
{
    if (!layer || key.length == 0 || [layer animationForKey:key]) return;

    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
    animation.fromValue = @(0.0);
    animation.toValue = @(-fabs(distance));
    animation.duration = duration;
    animation.autoreverses = YES;
    animation.repeatCount = HUGE_VALF;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    animation.beginTime = CACurrentMediaTime() + beginDelay;
    [layer addAnimation:animation forKey:key];
}

- (void)pp_refreshCurrentStatusSummaryMotionColors
{
    if (!self.statusBadgeHaloView) return;

    NSString *statusKey = [self customerDisplayStatusKeyForOrder:self.order];
    UIColor *accent = [self statusAccentColorForStatusKey:statusKey] ?: [GM appPrimaryColor];
    BOOL failure = [self isFailureStatusKey:statusKey];
    CGFloat haloAlpha = failure ? 0.16 : (PPIOS26() ? 0.18 : 0.14);

    self.statusBadgeHaloView.backgroundColor = [accent colorWithAlphaComponent:haloAlpha];
    self.statusBadgeHaloView.layer.borderWidth = 1.0;
    [self.statusBadgeHaloView pp_setBorderColor:[accent colorWithAlphaComponent:failure ? 0.26 : 0.22]];
    self.statusBadgeHaloView.layer.shadowColor = accent.CGColor;
    self.statusBadgeHaloView.layer.shadowOpacity = failure ? 0.13 : 0.16;
    self.statusBadgeHaloView.layer.shadowRadius = 10.0;
    self.statusBadgeHaloView.layer.shadowOffset = CGSizeZero;
    self.statusBadgeHaloView.hidden = UIAccessibilityIsReduceMotionEnabled();
}

- (void)pp_startCurrentStatusSummaryMotionIfNeeded
{
    [self pp_refreshCurrentStatusSummaryMotionColors];
    if (![self pp_shouldRunCurrentStatusSummaryMotion]) {
        [self pp_stopCurrentStatusSummaryMotion];
        return;
    }

    self.statusBadgeHaloView.hidden = NO;

    [self pp_addSummaryScalePulseToLayer:self.statusBadge.layer
                                     key:PPOrderSummaryStatusBadgeMotionKey
                               fromScale:1.0
                                 toScale:1.045
                                duration:1.9
                              beginDelay:0.0];
    [self pp_addSummaryScalePulseToLayer:self.statusBadgeHaloView.layer
                                     key:PPOrderSummaryStatusHaloScaleKey
                               fromScale:0.96
                                 toScale:1.15
                                duration:2.85
                              beginDelay:0.04];
    [self pp_addSummaryOpacityPulseToLayer:self.statusBadgeHaloView.layer
                                       key:PPOrderSummaryStatusHaloOpacityKey
                                      from:0.36
                                        to:0.82
                                  duration:2.85
                                beginDelay:0.04];
    [self pp_addSummaryVerticalFloatToLayer:self.statusIconView.layer
                                        key:PPOrderSummaryStatusIconMotionKey
                                   distance:1.1
                                   duration:2.05
                                 beginDelay:0.12];
    [self pp_addSummaryScalePulseToLayer:self.statusProgressChip.layer
                                     key:PPOrderSummaryProgressChipMotionKey
                               fromScale:1.0
                                 toScale:1.018
                                duration:2.6
                              beginDelay:0.18];
    [self pp_addSummaryOpacityPulseToLayer:self.progressTimelineProgressLabel.layer
                                       key:PPOrderSummaryTimelineCounterMotionKey
                                      from:0.76
                                        to:1.0
                                  duration:2.15
                                beginDelay:0.22];

    [self pp_addSummaryScalePulseToLayer:self.ambientDot1.layer
                                     key:@"PPAmbientDot1ScaleKey"
                               fromScale:1.0
                                 toScale:1.24
                                duration:3.4
                              beginDelay:0.0];
    [self pp_addSummaryOpacityPulseToLayer:self.ambientDot1.layer
                                       key:@"PPAmbientDot1OpacityKey"
                                      from:0.06
                                        to:0.18
                                  duration:3.4
                                beginDelay:0.0];
                                
    [self pp_addSummaryScalePulseToLayer:self.ambientDot2.layer
                                     key:@"PPAmbientDot2ScaleKey"
                               fromScale:1.0
                                 toScale:1.15
                                duration:4.1
                              beginDelay:0.8];
    [self pp_addSummaryOpacityPulseToLayer:self.ambientDot2.layer
                                       key:@"PPAmbientDot2OpacityKey"
                                      from:0.04
                                        to:0.14
                                  duration:4.1
                                beginDelay:0.8];
                                
    [self pp_addSummaryScalePulseToLayer:self.ambientDot3.layer
                                     key:@"PPAmbientDot3ScaleKey"
                               fromScale:1.0
                                 toScale:1.32
                                duration:2.8
                              beginDelay:1.2];
    [self pp_addSummaryOpacityPulseToLayer:self.ambientDot3.layer
                                       key:@"PPAmbientDot3OpacityKey"
                                      from:0.08
                                        to:0.24
                                  duration:2.8
                                beginDelay:1.2];
}

- (void)pp_stopCurrentStatusSummaryMotion
{
    [self.ambientDot1.layer removeAnimationForKey:@"PPAmbientDot1ScaleKey"];
    [self.ambientDot1.layer removeAnimationForKey:@"PPAmbientDot1OpacityKey"];
    [self.ambientDot2.layer removeAnimationForKey:@"PPAmbientDot2ScaleKey"];
    [self.ambientDot2.layer removeAnimationForKey:@"PPAmbientDot2OpacityKey"];
    [self.ambientDot3.layer removeAnimationForKey:@"PPAmbientDot3ScaleKey"];
    [self.ambientDot3.layer removeAnimationForKey:@"PPAmbientDot3OpacityKey"];

    [self.statusBadge.layer removeAnimationForKey:PPOrderSummaryStatusBadgeMotionKey];
    [self.statusBadgeHaloView.layer removeAnimationForKey:PPOrderSummaryStatusHaloScaleKey];
    [self.statusBadgeHaloView.layer removeAnimationForKey:PPOrderSummaryStatusHaloOpacityKey];
    [self.statusIconView.layer removeAnimationForKey:PPOrderSummaryStatusIconMotionKey];
    [self.statusProgressChip.layer removeAnimationForKey:PPOrderSummaryProgressChipMotionKey];
    [self.progressTimelineProgressLabel.layer removeAnimationForKey:PPOrderSummaryTimelineCounterMotionKey];
    self.statusBadgeHaloView.hidden = UIAccessibilityIsReduceMotionEnabled();
}

- (void)pp_playCurrentStatusChangeFeedback
{
    if (!self.isOrderDetailsScreenVisible) return;

    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedback prepare];
    [feedback impactOccurred];

    if (UIAccessibilityIsReduceMotionEnabled()) return;

    self.statusSummaryCard.transform = CGAffineTransformIdentity;
    [UIView animateKeyframesWithDuration:0.46
                                   delay:0.0
                                 options:UIViewKeyframeAnimationOptionCalculationModeCubic | UIViewKeyframeAnimationOptionAllowUserInteraction
                              animations:^{
        [UIView addKeyframeWithRelativeStartTime:0.0
                                relativeDuration:0.42
                                      animations:^{
            self.statusSummaryCard.transform = CGAffineTransformMakeScale(1.012, 1.012);
        }];
        [UIView addKeyframeWithRelativeStartTime:0.42
                                relativeDuration:0.58
                                      animations:^{
            self.statusSummaryCard.transform = CGAffineTransformIdentity;
        }];
    } completion:nil];
}

- (void)pp_handleReduceMotionStatusDidChange:(NSNotification *)notification
{
    (void)notification;
    [self pp_refreshHeaderHeroLiquidBorderColors];
    [self pp_refreshCurrentStatusSummaryMotionColors];
    [self.progressTimelineView refreshCurrentStatusMotion];
    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self pp_stopLiveBackgroundGlows];
        [self pp_stopHeaderHeroLiquidBorder];
        [self pp_stopCurrentStatusSummaryMotion];
    } else if (self.isOrderDetailsScreenVisible) {
        [self pp_startLiveBackgroundGlowsIfNeeded];
        [self pp_startHeaderHeroLiquidBorderIfNeeded];
        [self pp_startCurrentStatusSummaryMotionIfNeeded];
    }
}

- (void)layoutFooterView
{
    CGFloat width = self.view.bounds.size.width;
    CGFloat contentX = 16.0;
    CGFloat contentWidth = MAX(0.0, width - 32.0);
    CGFloat mapHeight = (width < 360.0) ? 158.0 : 176.0;
    CGFloat mapCardPadding = 16.0;
    CGFloat mapHeaderY = 16.0;
    CGFloat topButtonSize = 46.0;
    BOOL isRTL = [Language isRTL];

    CGFloat nextSectionY = 12.0;
    if (self.fulfillmentSectionCard && !self.fulfillmentSectionCard.hidden) {
        CGRect fulfillmentFrame = self.fulfillmentSectionCard.frame;
        fulfillmentFrame.origin.x = contentX;
        fulfillmentFrame.origin.y = nextSectionY;
        fulfillmentFrame.size.width = contentWidth;
        self.fulfillmentSectionCard.frame = fulfillmentFrame;
        nextSectionY = CGRectGetMaxY(fulfillmentFrame) + 16.0;
    } else {
        self.fulfillmentSectionCard.frame = CGRectZero;
    }

    self.deliveryMapCard.frame = CGRectMake(contentX, nextSectionY, contentWidth, 1.0);
    CGFloat openMapX = isRTL ? mapCardPadding : (contentWidth - mapCardPadding - topButtonSize);
    self.openMapButton.frame = CGRectMake(openMapX, mapHeaderY, topButtonSize, topButtonSize);

    CGFloat titleLeading = mapCardPadding;
    CGFloat titleWidth = isRTL
    ? MAX(0.0, contentWidth - CGRectGetMaxX(self.openMapButton.frame) - (mapCardPadding * 2.0))
    : MAX(0.0, CGRectGetMinX(self.openMapButton.frame) - mapCardPadding - 12.0 - titleLeading);
    CGFloat titleX = isRTL ? (CGRectGetMaxX(self.openMapButton.frame) + 12.0) : titleLeading;
    self.deliveryMapTitleLabel.frame = CGRectMake(titleX, mapHeaderY + 1.0, titleWidth, 22.0);
    self.deliveryMapSubtitleLabel.frame = CGRectMake(titleX,
                                                     CGRectGetMaxY(self.deliveryMapTitleLabel.frame) + 4.0,
                                                     titleWidth,
                                                     46.0);

    CGFloat mapTop = MAX(CGRectGetMaxY(self.openMapButton.frame), CGRectGetMaxY(self.deliveryMapSubtitleLabel.frame)) + 12.0;
    self.deliveryMapView.frame = CGRectMake(mapCardPadding,
                                            mapTop,
                                            contentWidth - (mapCardPadding * 2.0),
                                            mapHeight);

    if (!self.editLocationButton.hidden) {
        self.editLocationButton.frame = CGRectMake(mapCardPadding,
                                                   CGRectGetMaxY(self.deliveryMapView.frame) + 12.0,
                                                   contentWidth - (mapCardPadding * 2.0),
                                                   54.0);
    } else {
        self.editLocationButton.frame = CGRectZero;
    }

    CGFloat mapCardHeight = (!self.editLocationButton.hidden)
    ? (CGRectGetMaxY(self.editLocationButton.frame) + 14.0)
    : (CGRectGetMaxY(self.deliveryMapView.frame) + 14.0);
    self.deliveryMapCard.frame = CGRectMake(contentX, nextSectionY, contentWidth, mapCardHeight);

    NSArray<UIButton *> *orderedButtons = [self orderedActionButtons];
    NSMutableArray<UIButton *> *visibleButtons = [NSMutableArray array];
    for (UIButton *button in orderedButtons) {
        if (!button.hidden) {
            [visibleButtons addObject:button];
        } else {
            button.frame = CGRectZero;
        }
    }

    CGFloat buttonGap = 12.0;
    CGFloat buttonHeight = 54.0;
    CGFloat leadButtonHeight = 58.0;
    CGFloat buttonWidth = floor((contentWidth - buttonGap) * 0.5);
    NSInteger visibleCount = visibleButtons.count;
    UIButton *leadButton = nil;
    if ([visibleButtons containsObject:self.trackOrderButton]) {
        leadButton = self.trackOrderButton;
    } else {
        leadButton = visibleButtons.firstObject;
    }
    NSMutableArray<UIButton *> *secondaryButtons = [visibleButtons mutableCopy];
    if (leadButton) {
        [secondaryButtons removeObject:leadButton];
    }
    CGFloat buttonsHeight = 0.0;
    if (leadButton) {
        buttonsHeight += leadButtonHeight;
    }
    if (secondaryButtons.count > 0) {
        if (buttonsHeight > 0.0) buttonsHeight += buttonGap;
        NSInteger secondaryRows = (secondaryButtons.count + 1) / 2;
        buttonsHeight += (secondaryRows * buttonHeight) + ((secondaryRows - 1) * buttonGap);
    }
    self.actionButtonsStack.frame = CGRectMake(contentX,
                                               CGRectGetMaxY(self.deliveryMapCard.frame) + 16.0,
                                               contentWidth,
                                               buttonsHeight);

    CGFloat nextButtonY = 0.0;
    if (leadButton) {
        leadButton.frame = CGRectMake(0.0, 0.0, contentWidth, leadButtonHeight);
        nextButtonY = CGRectGetMaxY(leadButton.frame) + buttonGap;
    }
    for (NSInteger index = 0; index < secondaryButtons.count; index++) {
        UIButton *button = secondaryButtons[index];
        NSInteger row = index / 2;
        NSInteger column = index % 2;
        BOOL isLastOddButton = (secondaryButtons.count % 2 == 1) && (index == secondaryButtons.count - 1);
        CGFloat currentWidth = isLastOddButton ? contentWidth : buttonWidth;
        CGFloat buttonX = 0.0;
        if (!isLastOddButton) {
            if (isRTL) {
                buttonX = (column == 0) ? (buttonWidth + buttonGap) : 0.0;
            } else {
                buttonX = (column == 0) ? 0.0 : (buttonWidth + buttonGap);
            }
        }
        CGFloat buttonY = nextButtonY + (row * (buttonHeight + buttonGap));
        button.frame = CGRectMake(buttonX, buttonY, currentWidth, buttonHeight);
    }

    CGFloat hintHeight = 0.0;
    if (!self.postOrderHintLabel.hidden && self.postOrderHintLabel.text.length > 0) {
        CGSize hintSize = [self.postOrderHintLabel sizeThatFits:CGSizeMake(contentWidth, CGFLOAT_MAX)];
        hintHeight = ceil(hintSize.height);
        self.postOrderHintLabel.frame = CGRectMake(contentX,
                                                   CGRectGetMaxY(self.actionButtonsStack.frame) + 12.0,
                                                   contentWidth,
                                                   hintHeight);
    } else {
        self.postOrderHintLabel.frame = CGRectZero;
    }

    CGFloat footerHeight = CGRectGetMaxY(self.actionButtonsStack.frame) + 12.0;
    if (hintHeight > 0.0) {
        footerHeight = CGRectGetMaxY(self.postOrderHintLabel.frame) + 12.0;
    } else if (visibleCount == 0) {
        footerHeight = CGRectGetMaxY(self.deliveryMapCard.frame) + 12.0;
    }
    if (!self.fulfillmentSectionCard.hidden && CGRectGetMaxY(self.fulfillmentSectionCard.frame) > footerHeight) {
        footerHeight = CGRectGetMaxY(self.fulfillmentSectionCard.frame) + 12.0;
    }
    self.footerContainer.frame = CGRectMake(0, 0, width, footerHeight);
    self.tableView.tableFooterView = self.footerContainer;
}

- (NSArray<UIButton *> *)orderedActionButtons
{
    return @[
        self.trackOrderButton,
        self.viewRequestsButton,
        self.contactSupportButton,
        self.cancelOrderButton,
        self.returnRequestButton,
        self.replacementButton,
        self.refundButton,
        self.reportIssueButton
    ];
}

- (NSInteger)visibleActionButtonsCount
{
    NSInteger count = 0;
    for (UIView *view in [self orderedActionButtons]) {
        if (!view.hidden) count += 1;
    }
    return count;
}

- (void)refreshVisualTheme
{
    UIColor *accent = self.order ? [self statusAccentColorForStatusKey:[self customerDisplayStatusKeyForOrder:self.order]] : [GM appPrimaryColor];
    self.headerCard.backgroundColor = [AppForgroundColr colorWithAlphaComponent:PPIOS26() ? 0.78 : 0.97];
    self.deliveryMapCard.backgroundColor = [AppForgroundColr colorWithAlphaComponent:PPIOS26() ? 0.82 : 0.97];
    self.statusSummaryCard.backgroundColor = AppForgroundColr;
    
    self.ambientDot1.backgroundColor = [accent colorWithAlphaComponent:0.06];
    self.ambientDot2.backgroundColor = [accent colorWithAlphaComponent:0.04];
    self.ambientDot3.backgroundColor = [accent colorWithAlphaComponent:0.08];
    
    self.statusSummaryCard.layer.borderWidth = 1.0;
    [self.statusSummaryCard pp_setBorderColor:[accent colorWithAlphaComponent:0.12]];
    
    self.summaryPanel.backgroundColor = UIColor.clearColor;
    self.statusBadge.backgroundColor = [accent colorWithAlphaComponent:PPIOS26() ? 0.18 : 0.14];
    self.statusProgressChip.backgroundColor = [UIColor colorWithWhite:1.0 alpha:PPIOS26() ? 0.14 : 0.70];
    self.statusEtaChip.backgroundColor = [UIColor colorWithWhite:1.0 alpha:PPIOS26() ? 0.14 : 0.70];
    self.statusProgressChipIconView.tintColor = accent;
    self.statusEtaChipIconView.tintColor = accent;
    self.statusProgressChipLabel.textColor = UIColor.labelColor;
    self.statusEtaChipLabel.textColor = UIColor.labelColor;
    self.progressTimelineTitleLabel.textColor = UIColor.labelColor;
    self.progressTimelineProgressLabel.textColor = accent;
    self.progressTimelineToggleButton.backgroundColor = [accent colorWithAlphaComponent:PPIOS26() ? 0.12 : 0.10];
    self.progressTimelineToggleButton.tintColor = accent;
    self.progressTimelineToggleButton.layer.borderWidth = 1.0;
    [self.progressTimelineToggleButton pp_setBorderColor:[accent colorWithAlphaComponent:0.16]];
    self.progressTimelineToggleIconView.tintColor = accent;
    [self pp_refreshLiveBackgroundGlowColors];
    [self pp_refreshHeaderHeroLiquidBorderColors];
    self.openMapButton.backgroundColor = [accent colorWithAlphaComponent:0.12];
    self.openMapButton.tintColor = accent;
    [self.openMapButton pp_setBorderColor:[accent colorWithAlphaComponent:0.16]];
    [self.deliveryMapView pp_setBorderColor:[accent colorWithAlphaComponent:0.14]];
    [self refreshActionButtonAppearances];
    [self pp_refreshCurrentStatusSummaryMotionColors];
    if (self.isOrderDetailsScreenVisible) {
        [self pp_startCurrentStatusSummaryMotionIfNeeded];
    }
}

- (NSAttributedString *)stackedAttributedTextWithTitle:(NSString *)title
                                                 value:(NSString *)value
                                               emphasis:(BOOL)emphasis
                                             alignment:(NSTextAlignment)alignment
{
    NSString *resolvedTitle = [self safeString:title];
    NSString *resolvedValue = [self safeString:value];
    if (resolvedValue.length == 0) {
        resolvedValue = @"--";
    }

    NSMutableParagraphStyle *style = [NSMutableParagraphStyle new];
    style.alignment = alignment;
    style.lineBreakMode = NSLineBreakByWordWrapping;
    style.lineSpacing = emphasis ? 1.0 : 0.5;

    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:resolvedTitle
                                                                             attributes:@{
        NSFontAttributeName: [GM MidFontWithSize:12],
        NSForegroundColorAttributeName: UIColor.secondaryLabelColor,
        NSParagraphStyleAttributeName: style
    }];
    [text appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"
                                                                 attributes:@{
        NSParagraphStyleAttributeName: style
    }]];
    [text appendAttributedString:[[NSAttributedString alloc] initWithString:resolvedValue
                                                                 attributes:@{
        NSFontAttributeName: emphasis ? [GM boldFontWithSize:28] : [GM boldFontWithSize:15],
        NSForegroundColorAttributeName: UIColor.labelColor,
        NSParagraphStyleAttributeName: style
    }]];
    return text;
}

- (NSString *)multilineOrderDateValueFromDate:(NSDate *)date
{
    if (![date isKindOfClass:NSDate.class]) {
        return @"--";
    }

    NSLocale *locale = self.dateFormatter.locale ?: [NSLocale currentLocale];

    NSDateFormatter *dateOnlyFormatter = [[NSDateFormatter alloc] init];
    dateOnlyFormatter.locale = locale;
    [dateOnlyFormatter setLocalizedDateFormatFromTemplate:@"d MMM yyyy"];

    NSDateFormatter *timeOnlyFormatter = [[NSDateFormatter alloc] init];
    timeOnlyFormatter.locale = locale;
    [timeOnlyFormatter setLocalizedDateFormatFromTemplate:@"h:mm a"];

    NSString *dateText = [self safeString:[dateOnlyFormatter stringFromDate:date]];
    NSString *timeText = [self safeString:[timeOnlyFormatter stringFromDate:date]];

    if (dateText.length > 0 && timeText.length > 0) {
        return [NSString stringWithFormat:@"%@\n%@", dateText, timeText];
    }
    if (dateText.length > 0) {
        return dateText;
    }
    if (timeText.length > 0) {
        return timeText;
    }

    return @"--";
}

- (void)refreshActionButtonAppearances
{
    UIColor *surfaceBackground = [AppForgroundColr colorWithAlphaComponent:PPIOS26() ? 0.58 : 0.96];
    UIColor *surfaceBorder = [[UIColor whiteColor] colorWithAlphaComponent:PPIOS26() ? 0.18 : 0.08];
    UIColor *primaryTint = [GM appPrimaryColor];

    [self applyVisualStyleToActionButton:self.trackOrderButton
                               tintColor:AppForgroundColr
                         backgroundColor:primaryTint
                             borderColor:[primaryTint colorWithAlphaComponent:0.28]];
    [self applyVisualStyleToActionButton:self.editLocationButton
                               tintColor:primaryTint
                         backgroundColor:[primaryTint colorWithAlphaComponent:0.12]
                             borderColor:[primaryTint colorWithAlphaComponent:0.18]];
    [self applyVisualStyleToActionButton:self.cancelOrderButton
                               tintColor:UIColor.systemRedColor
                         backgroundColor:[UIColor.systemRedColor colorWithAlphaComponent:0.10]
                             borderColor:[UIColor.systemRedColor colorWithAlphaComponent:0.18]];

    NSArray<UIButton *> *secondaryButtons = @[
        self.viewRequestsButton,
        self.contactSupportButton,
        self.returnRequestButton,
        self.replacementButton,
        self.refundButton,
        self.reportIssueButton
    ];
    for (UIButton *button in secondaryButtons) {
        [self applyVisualStyleToActionButton:button
                                   tintColor:UIColor.labelColor
                             backgroundColor:surfaceBackground
                                 borderColor:surfaceBorder];
    }
}

- (void)applyVisualStyleToActionButton:(UIButton *)button
                             tintColor:(UIColor *)tintColor
                       backgroundColor:(UIColor *)backgroundColor
                           borderColor:(UIColor *)borderColor
{
    if (!button) return;

    button.backgroundColor = backgroundColor;
    button.tintColor = tintColor;
    button.layer.borderWidth = 1.0;
    [button pp_setBorderColor:borderColor];

    NSString *title = nil;
    if (@available(iOS 15.0, *)) {
        title = button.configuration.attributedTitle.string;
    }
    if (title.length == 0) {
        title = [button titleForState:UIControlStateNormal];
    }

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = button.configuration ?: [UIButtonConfiguration tintedButtonConfiguration];
        config.baseForegroundColor = tintColor;
        config.background.backgroundColor = backgroundColor;
        config.background.cornerRadius = kOrderDetailsButtonCornerRadius;
        config.attributedTitle = [[NSAttributedString alloc] initWithString:(title ?: @"")
                                                                 attributes:@{
            NSFontAttributeName: [GM MidFontWithSize:15],
            NSForegroundColorAttributeName: tintColor ?: UIColor.labelColor
        }];
        button.configuration = config;
    } else {
        [button setTitleColor:tintColor forState:UIControlStateNormal];
    }
}

#pragma mark - Configure

- (void)configureWithCurrentOrder
{
    BOOL isRTL = [Language isRTL];
    NSTextAlignment leading = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    NSString *dateValue = @"--";
    NSString *totalValue = @"--";
    NSString *paymentValue = @"--";

    if (!self.order) {
        self.orderIDLabel.text = @"#--";
        self.orderStatusLabel.text = kLang(@"Unknown");
        self.dateLabel.attributedText = [self stackedAttributedTextWithTitle:kLang(@"OrderDate") value:dateValue emphasis:NO alignment:leading];
        self.totalPriceLabel.attributedText = [self stackedAttributedTextWithTitle:kLang(@"order_total_label") value:totalValue emphasis:YES alignment:leading];
        self.paymentProviderLabel.attributedText = [self stackedAttributedTextWithTitle:kLang(@"PaymentMethod") value:paymentValue emphasis:NO alignment:leading];
        self.deliveryAddressLabel.text = [NSString stringWithFormat:@"%@: --", kLang(@"DeliveryAddress")];
        self.selectedAddressModel = nil;
        [self updateStatusStyle];
        [self updateStatusStepper];
        [self.lineItems removeAllObjects];
        [self.tableView reloadData];
        [self refreshDeliveryMap];
        [self updateButtonsState];
        [self.view setNeedsLayout];
        return;
    }

    NSString *orderID = [self displayOrderReference];
    if (orderID.length == 0) orderID = @"--";
    self.orderIDLabel.text = [NSString stringWithFormat:@"#%@", orderID];

    if ([self.order.createdAt isKindOfClass:NSDate.class]) {
        dateValue = [self multilineOrderDateValueFromDate:self.order.createdAt];
    }

    totalValue = [self formattedTotalForOrder:self.order];
    paymentValue = [self paymentProviderTextForOrder:self.order];
    self.dateLabel.attributedText = [self stackedAttributedTextWithTitle:kLang(@"OrderDate") value:dateValue emphasis:NO alignment:leading];
    self.totalPriceLabel.attributedText = [self stackedAttributedTextWithTitle:kLang(@"order_total_label") value:totalValue emphasis:YES alignment:leading];
    self.paymentProviderLabel.attributedText = [self stackedAttributedTextWithTitle:kLang(@"PaymentMethod") value:paymentValue emphasis:NO alignment:leading];
    self.deliveryAddressLabel.text = [NSString stringWithFormat:@"%@: %@", kLang(@"DeliveryAddress"), [self resolvedDeliveryAddressText]];
    self.orderStatusLabel.text = [self displayStatusTitleForOrder:self.order];

    [self updateStatusStyle];
    [self updateStatusStepper];
    [self buildLineItems];
    [self resolveLineItemsIfNeeded];
    [self resolveSelectedAddressFromOrderIfNeeded];
    [self refreshDeliveryMap];
    [self updateButtonsState];
    [self configureFulfillmentSection];
    [self.view setNeedsLayout];
}

- (void)updateStatusStyle
{
    NSString *statusKey = [self customerDisplayStatusKeyForOrder:self.order];
    UIColor *accent = [self statusAccentColorForStatusKey:statusKey];
    UIColor *badge = [self statusBadgeColorForStatusKey:statusKey];
    NSString *iconName = [self statusIconNameForStatusKey:statusKey];

    self.statusIconView.image = [UIImage systemImageNamed:iconName];
    self.statusIconView.tintColor = accent;
    self.orderStatusLabel.textColor = accent;
    [self refreshVisualTheme];
    self.statusBadge.backgroundColor = badge;
}

- (UIColor *)stepperTintColorForOrder:(PPOrder *)order
{
    NSString *statusKey = [self customerDisplayStatusKeyForOrder:order];
    return [self statusAccentColorForStatusKey:statusKey];
}

- (UIColor *)statusAccentColorForStatusKey:(NSString *)statusKey
{
    NSString *key = PPOrderStepperNormalizedKey(statusKey);
    if ([key isEqualToString:@"delivery_cancelled"]) {
        return UIColor.systemRedColor;
    }
    if ([key isEqualToString:@"delivery_delayed"]) {
        return UIColor.systemOrangeColor;
    }
    if ([key isEqualToString:@"completed"]) {
        return [GM appPrimaryColor];
    }
    if ([key isEqualToString:@"delivered"]) {
        return UIColor.systemGreenColor;
    }
    if ([key isEqualToString:@"on_the_way"]) {
        return UIColor.systemBlueColor;
    }
    if ([key isEqualToString:@"delivery_partner_assigned"]) {
        if (@available(iOS 13.0, *)) {
            return UIColor.systemIndigoColor;
        }
        return [UIColor colorWithRed:0.35 green:0.45 blue:0.94 alpha:1.0];
    }
    if ([key isEqualToString:@"ready_for_delivery"]) {
        return [GM appPrimaryColor];
    }
    if ([key isEqualToString:@"preparing_for_shipment"]) {
        return UIColor.systemOrangeColor;
    }
    return UIColor.systemOrangeColor;
}

- (UIColor *)statusBadgeColorForStatusKey:(NSString *)statusKey
{
    return [[self statusAccentColorForStatusKey:statusKey] colorWithAlphaComponent:0.2];
}

- (NSString *)statusIconNameForStatusKey:(NSString *)statusKey
{
    NSString *key = PPOrderStepperNormalizedKey(statusKey);
    if ([key isEqualToString:@"delivery_cancelled"]) {
        return @"xmark.circle.fill";
    }
    if ([key isEqualToString:@"delivery_delayed"]) {
        return @"exclamationmark.triangle.fill";
    }
    if ([key isEqualToString:@"completed"]) {
        return @"checkmark.seal.fill";
    }
    if ([key isEqualToString:@"delivered"]) {
        return @"checkmark.circle.fill";
    }
    if ([key isEqualToString:@"on_the_way"]) {
        return @"shippingbox.fill";
    }
    if ([key isEqualToString:@"delivery_partner_assigned"]) {
        return @"person.crop.circle.fill";
    }
    if ([key isEqualToString:@"ready_for_delivery"]) {
        return @"shippingbox.fill";
    }
    if ([key isEqualToString:@"preparing_for_shipment"]) {
        return @"shippingbox.circle.fill";
    }
    return @"clock.fill";
}

- (void)updateStatusStepper
{
    [self updateStatusStepperAnimated:NO];
}

- (void)updateStatusStepperAnimated:(BOOL)animated
{
    NSString *statusKey = [self customerDisplayStatusKeyForOrder:self.order];
    NSInteger currentIndex = 0;
    BOOL showsFailure = NO;
    NSArray<NSDictionary *> *descriptors = [self progressTimelineDescriptorsForOrder:self.order
                                                                         currentIndex:&currentIndex
                                                                         showsFailure:&showsFailure];
    UIColor *timelineTintColor = [self stepperTintColorForOrder:self.order];
    NSString *progressText = [self progressCounterTextForCurrentIndex:currentIndex totalSteps:descriptors.count];

    self.orderStatusLabel.text = PPOrderCustomerVisibleStatusTitle(statusKey);
    self.statusSummarySubtitleLabel.text = PPOrderCustomerVisibleStatusHint(statusKey);
    self.statusProgressChipLabel.text = progressText;
    self.progressTimelineProgressLabel.text = progressText;
    self.statusEtaChipLabel.text = [self summaryStatusDateTextForOrder:self.order statusKey:statusKey];
    self.progressTimelineToggleButton.accessibilityValue = self.isProgressTimelineExpanded ? @"Expanded" : @"Collapsed";

    [self.progressTimelineView configureWithStepDescriptors:descriptors
                                               currentIndex:currentIndex
                                               showsFailure:showsFailure
                                                   expanded:self.isProgressTimelineExpanded
                                                  tintColor:timelineTintColor
                                                   animated:animated];

    self.progressTimelineToggleIconView.transform = self.isProgressTimelineExpanded ? CGAffineTransformMakeRotation((CGFloat)M_PI) : CGAffineTransformIdentity;
}

- (NSArray<NSDictionary *> *)progressTimelineDescriptorsForOrder:(PPOrder *)order
                                                    currentIndex:(NSInteger *)currentIndex
                                                    showsFailure:(BOOL *)showsFailure
{
    NSString *statusKey = [self customerDisplayStatusKeyForOrder:order];
    BOOL failure = [self isFailureStatusKey:statusKey];
    NSMutableArray<NSString *> *stepKeys = [NSMutableArray array];
    if (failure) {
        [stepKeys addObject:@"preparing_for_shipment"];
        [stepKeys addObject:statusKey.length > 0 ? statusKey : @"delivery_delayed"];
    } else {
        [stepKeys addObjectsFromArray:@[
            @"preparing_for_shipment",
            @"ready_for_delivery",
            @"delivery_partner_assigned",
            @"on_the_way",
            @"delivered",
            @"completed"
        ]];
    }

    NSInteger resolvedIndex = failure ? 1 : [self progressTimelineIndexForStatusKey:statusKey];
    if (currentIndex) *currentIndex = resolvedIndex;
    if (showsFailure) *showsFailure = failure;

    NSMutableArray<NSDictionary *> *descriptors = [NSMutableArray arrayWithCapacity:stepKeys.count];
    [stepKeys enumerateObjectsUsingBlock:^(NSString * _Nonnull stepKey, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *resolvedKey = [self safeString:stepKey];
        NSString *title = PPOrderCustomerVisibleStatusTitle(resolvedKey);
        NSString *subtitle = PPOrderCustomerVisibleStatusHint(resolvedKey);
        NSString *metaText = (idx <= (NSUInteger)resolvedIndex) ? [self progressTimelineMetaTextForStatusKey:resolvedKey order:order] : @"";
        NSString *iconName = [self statusIconNameForStatusKey:resolvedKey];
        [descriptors addObject:@{
            @"statusKey": resolvedKey ?: @"",
            @"title": title ?: @"",
            @"subtitle": subtitle ?: @"",
            @"meta": metaText ?: @"",
            @"icon": iconName ?: @"circle"
        }];
        (void)stop;
    }];
    return descriptors.copy;
}

- (NSInteger)progressTimelineIndexForStatusKey:(NSString *)statusKey
{
    if ([statusKey isEqualToString:@"completed"]) return 5;
    if ([statusKey isEqualToString:@"delivered"]) return 4;
    if ([statusKey isEqualToString:@"on_the_way"]) return 3;
    if ([statusKey isEqualToString:@"delivery_partner_assigned"]) return 2;
    if ([statusKey isEqualToString:@"ready_for_delivery"]) return 1;
    return 0;
}

- (NSString *)progressCounterTextForCurrentIndex:(NSInteger)currentIndex totalSteps:(NSInteger)totalSteps
{
    NSInteger normalizedTotal = MAX(1, totalSteps);
    NSInteger normalizedCurrent = MAX(1, MIN(currentIndex + 1, normalizedTotal));
    return [NSString stringWithFormat:@"%ld / %ld", (long)normalizedCurrent, (long)normalizedTotal];
}

- (NSDate *)progressTimelineDateForStatusKey:(NSString *)statusKey order:(PPOrder *)order
{
    if (![order isKindOfClass:PPOrder.class]) {
        return nil;
    }

    NSString *normalized = PPOrderStepperNormalizedKey(statusKey);
    if ([normalized isEqualToString:@"preparing_for_shipment"]) {
        return order.processedAt ?: order.createdAt;
    }
    if ([normalized isEqualToString:@"ready_for_delivery"]) {
        return order.readyToShipAt ?: order.readyAt ?: order.deliveryRequestedAt ?: order.processedAt;
    }
    if ([normalized isEqualToString:@"delivery_partner_assigned"]) {
        return order.deliveryAcceptedAt;
    }
    if ([normalized isEqualToString:@"on_the_way"]) {
        return order.inTransitAt ?: order.pickedUpAt ?: order.shippedAt;
    }
    if ([normalized isEqualToString:@"delivered"]) {
        return order.deliveredAt ?: order.paymentPendingAt ?: order.paymentConfirmedAt;
    }
    if ([normalized isEqualToString:@"completed"]) {
        return order.completedAt ?: order.deliveredAt;
    }
    if ([normalized isEqualToString:@"delivery_cancelled"]) {
        return order.cancelledAt ?: order.statusUpdatedAt;
    }
    if ([normalized isEqualToString:@"delivery_delayed"]) {
        return order.deliveryFailedAt ?: order.returnedToStoreAt ?: order.statusUpdatedAt;
    }
    return order.statusUpdatedAt ?: order.updatedAt ?: order.createdAt;
}

- (NSString *)progressTimelineMetaTextForStatusKey:(NSString *)statusKey order:(PPOrder *)order
{
    NSDate *date = [self progressTimelineDateForStatusKey:statusKey order:order];
    if (![date isKindOfClass:NSDate.class]) {
        return @"";
    }
    return [self safeString:[self.dateFormatter stringFromDate:date]];
}

- (NSString *)summaryStatusDateTextForOrder:(PPOrder *)order statusKey:(NSString *)statusKey
{
    NSDate *preferredDate = nil;
    if ([order isKindOfClass:PPOrder.class] &&
        ![self isFailureStatusKey:statusKey] &&
        ![statusKey isEqualToString:@"delivered"] &&
        ![statusKey isEqualToString:@"completed"]) {
        preferredDate = order.estimatedDeliveryAt;
    }
    if (!preferredDate) {
        preferredDate = [self progressTimelineDateForStatusKey:statusKey order:order];
    }
    if (![preferredDate isKindOfClass:NSDate.class]) {
        return kLang(@"Pending");
    }
    return [self safeString:[self.dateFormatter stringFromDate:preferredDate]];
}

- (NSString *)displayStatusTitleForOrder:(PPOrder *)order
{
    return PPOrderCustomerVisibleStatusTitle([self customerDisplayStatusKeyForOrder:order]);
}

- (NSString *)failureStepTitleForStatusKey:(NSString *)statusKey
{
    NSString *key = PPOrderStepperNormalizedKey(statusKey);
    if ([key isEqualToString:@"delivery_cancelled"] ||
        [self statusKey:key matchesAnyKeywords:@[@"cancelled", @"canceled"]]) {
        return kLang(@"Delivery Cancelled");
    }
    return kLang(@"Delivery Delayed");
}

- (BOOL)isFailureStatusKey:(NSString *)statusKey
{
    return [self statusKey:statusKey matchesAnyKeywords:@[@"failed", @"rejected", @"cancelled", @"canceled", @"expired", @"returned_to_store", @"delivery_delayed"]];
}

- (NSString *)normalizedStatusKeyForOrder:(PPOrder *)order
{
    NSString *status = [self safeString:[order effectiveDeliveryStatus]];
    if (status.length == 0) {
        status = [self safeString:order.rawStatus];
    }
    if (status.length == 0) {
        switch (order.status) {
            case PPOrderStatusPending: status = @"pending"; break;
            case PPOrderStatusPaid: status = @"paid"; break;
            case PPOrderStatusFailed: status = @"failed"; break;
        }
    }

    status = [[status lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    status = [status stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    status = [status stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
    while ([status containsString:@"__"]) {
        status = [status stringByReplacingOccurrencesOfString:@"__" withString:@"_"];
    }
    return status;
}

- (NSString *)customerDisplayStatusKeyForOrder:(PPOrder *)order
{
    if (![order isKindOfClass:PPOrder.class]) {
        return @"preparing_for_shipment";
    }
    NSString *statusKey = PPOrderStepperNormalizedKey([order customerVisibleStatusKey]);
    return statusKey.length > 0 ? statusKey : @"preparing_for_shipment";
}

- (BOOL)statusKey:(NSString *)statusKey matchesAnyKeywords:(NSArray<NSString *> *)keywords
{
    if (statusKey.length == 0 || keywords.count == 0) return NO;

    NSString *wrappedStatus = [NSString stringWithFormat:@"_%@_", statusKey];
    for (NSString *keyword in keywords) {
        NSString *normalizedKeyword = [[self safeString:keyword] lowercaseString];
        if (normalizedKeyword.length == 0) continue;

        if ([statusKey isEqualToString:normalizedKeyword]) return YES;
        if ([normalizedKeyword containsString:@"_"]) {
            if ([statusKey containsString:normalizedKeyword]) return YES;
        } else {
            NSString *wrappedKeyword = [NSString stringWithFormat:@"_%@_", normalizedKeyword];
            if ([wrappedStatus containsString:wrappedKeyword]) return YES;
        }
    }
    return NO;
}

- (void)updateButtonsState
{
    BOOL hasOrder = (self.order != nil);
    NSString *statusKey = [self normalizedStatusKeyForOrder:self.order];
    BOOL deliveredLike = [self statusKey:statusKey matchesAnyKeywords:@[@"delivered", @"completed", @"fulfilled", @"payment_pending", @"payment_confirmed"]];
    BOOL shippedLike = [self statusKey:statusKey matchesAnyKeywords:@[@"shipped", @"shipping", @"in_transit", @"out_for_delivery", @"picked_up"]];
    BOOL cancelledLike = [self statusKey:statusKey matchesAnyKeywords:@[@"cancelled", @"canceled"]];
    BOOL chargeCapturedLike = hasOrder && [self.order hasCapturedPayment];
    BOOL issueRelevant = hasOrder;

    PPOrderEligibilityDecision *cancelDecision = [self decisionForAction:PPOrderCustomerActionTypeCancel];
    PPOrderEligibilityDecision *returnDecision = [self decisionForAction:PPOrderCustomerActionTypeReturn];
    PPOrderEligibilityDecision *refundDecision = [self decisionForAction:PPOrderCustomerActionTypeRefund];
    PPOrderEligibilityDecision *replacementDecision = [self decisionForAction:PPOrderCustomerActionTypeReplacement];
    PPOrderEligibilityDecision *complaintDecision = [self decisionForAction:PPOrderCustomerActionTypeComplaint];

    [self applyActionButton:self.trackOrderButton visible:hasOrder eligible:YES];
    [self applyActionButton:self.viewRequestsButton visible:hasOrder eligible:YES];
    [self applyActionButton:self.contactSupportButton visible:hasOrder eligible:YES];
    [self applyActionButton:self.editLocationButton visible:hasOrder && !deliveredLike && !shippedLike && !cancelledLike && ![self isFailureStatusKey:statusKey] eligible:cancelDecision.isEligible];
    [self applyActionButton:self.cancelOrderButton visible:hasOrder && !deliveredLike && !shippedLike && !cancelledLike && ![self isFailureStatusKey:statusKey] eligible:cancelDecision.isEligible];
    [self applyActionButton:self.returnRequestButton visible:hasOrder && deliveredLike eligible:returnDecision.isEligible];
    [self applyActionButton:self.replacementButton visible:hasOrder && deliveredLike eligible:replacementDecision.isEligible];
    [self applyActionButton:self.refundButton visible:hasOrder && chargeCapturedLike && !shippedLike eligible:refundDecision.isEligible];
    [self applyActionButton:self.reportIssueButton visible:issueRelevant eligible:complaintDecision.isEligible];

    self.postOrderHintLabel.text = [self buildEligibilityHintText];
    self.postOrderHintLabel.hidden = (self.postOrderHintLabel.text.length == 0);
    [self refreshActionButtonAppearances];
    [self layoutFooterView];
}

#pragma mark - Items

- (void)buildLineItems
{
    [self.lineItems removeAllObjects];

    for (id rawItem in self.order.items ?: @[]) {
        NSMutableDictionary *line = [@{
            @"itemId": @"",
            @"name": @"",
            @"quantity": @(1),
            @"price": @(0.0),
            @"imageURL": @"",
            @"needsLookup": @(NO)
        } mutableCopy];

        if ([rawItem isKindOfClass:NSString.class]) {
            NSString *itemID = [self safeString:rawItem];
            if (itemID.length == 0) continue;
            line[@"itemId"] = itemID;
            line[@"needsLookup"] = @(YES);
            [self.lineItems addObject:line];
            continue;
        }

        if (![rawItem isKindOfClass:NSDictionary.class]) {
            continue;
        }

        NSDictionary *item = (NSDictionary *)rawItem;
        NSString *itemID = [self itemIDFromOrderItem:item];
        NSString *name = [self safeString:(item[@"name"] ?: item[@"title"])];
        NSInteger quantity = [self integerFromValue:(item[@"qty"] ?: item[@"quantity"]) fallback:1];
        double price = [self doubleFromValue:(item[@"price"] ?: item[@"unitPrice"] ?: item[@"finalPrice"]) fallback:0.0];
        NSString *imageURL = [self imageURLFromData:item];

        line[@"itemId"] = itemID ?: @"";
        line[@"name"] = name ?: @"";
        line[@"quantity"] = @(MAX(1, quantity));
        line[@"price"] = @(MAX(0.0, price));
        line[@"imageURL"] = imageURL ?: @"";

        BOOL needsLookup = (itemID.length > 0) && (name.length == 0 || imageURL.length == 0 || price <= 0.0);
        line[@"needsLookup"] = @(needsLookup);

        if (itemID.length == 0 && name.length == 0) {
            continue;
        }

        [self.lineItems addObject:line];
    }

    [self.tableView reloadData];
}

- (void)resolveLineItemsIfNeeded
{
    if (self.lineItems.count == 0) return;

    __weak typeof(self) weakSelf = self;
    for (NSMutableDictionary *line in self.lineItems) {
        BOOL needsLookup = [line[@"needsLookup"] boolValue];
        NSString *itemID = [self safeString:line[@"itemId"]];
        if (!needsLookup || itemID.length == 0) {
            continue;
        }

        NSDictionary *cached = self.accessoryCache[itemID];
        if (cached) {
            [self applyAccessoryData:cached toLineItemsWithID:itemID];
            continue;
        }

        if ([self.inFlightAccessoryIDs containsObject:itemID]) {
            continue;
        }

        [self.inFlightAccessoryIDs addObject:itemID];
        [self fetchAccessoryDataForID:itemID completion:^(NSDictionary * _Nullable data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                [strongSelf.inFlightAccessoryIDs removeObject:itemID];
                if (!data) return;
                strongSelf.accessoryCache[itemID] = data;
                [strongSelf applyAccessoryData:data toLineItemsWithID:itemID];
            });
        }];
    }
}

- (void)applyAccessoryData:(NSDictionary *)data toLineItemsWithID:(NSString *)itemID
{
    if (itemID.length == 0 || ![data isKindOfClass:NSDictionary.class]) return;

    NSString *name = [self safeString:(data[@"name"] ?: data[@"title"])];
    NSString *imageURL = [self imageURLFromData:data];
    double price = [self doubleFromValue:(data[@"finalPrice"] ?: data[@"price"]) fallback:0.0];

    for (NSMutableDictionary *line in self.lineItems) {
        NSString *lineID = [self safeString:line[@"itemId"]];
        if (![lineID isEqualToString:itemID]) continue;

        if ([self safeString:line[@"name"]].length == 0 && name.length > 0) {
            line[@"name"] = name;
        }
        if ([self safeString:line[@"imageURL"]].length == 0 && imageURL.length > 0) {
            line[@"imageURL"] = imageURL;
        }
        if ([line[@"price"] doubleValue] <= 0.0 && price > 0.0) {
            line[@"price"] = @(price);
        }
        line[@"needsLookup"] = @(NO);
    }

    [self.tableView reloadData];
}

#pragma mark - Map

- (void)refreshDeliveryMap
{
    [self.deliveryMapView removeAnnotations:self.deliveryMapView.annotations];

    CLLocationCoordinate2D coordinate = [self currentDeliveryCoordinate];
    NSString *subtitle = [self deliverySubtitle];

    MKPointAnnotation *annotation = [[MKPointAnnotation alloc] init];
    annotation.coordinate = coordinate;
    annotation.title = kLang(@"DeliveryLocation");
    annotation.subtitle = subtitle.length > 0 ? subtitle : kLang(@"DeliveryLocationSub");
    [self.deliveryMapView addAnnotation:annotation];

    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(coordinate, 1200, 1200);
    [self.deliveryMapView setRegion:region animated:NO];

    NSString *resolvedSubtitle = subtitle.length > 0 ? subtitle : kLang(@"DeliveryLocationSub");
    self.deliveryAddressLabel.text = [NSString stringWithFormat:@"%@: %@", kLang(@"DeliveryAddress"), resolvedSubtitle];
    self.deliveryMapTitleLabel.text = kLang(@"DeliveryLocation");
    self.deliveryMapSubtitleLabel.text = resolvedSubtitle;
}

- (CLLocationCoordinate2D)currentDeliveryCoordinate
{
    NSDictionary *snapshot = [self.order.shippingAddressSnapshot isKindOfClass:NSDictionary.class] ? self.order.shippingAddressSnapshot : nil;
    double latitude = [self doubleFromValue:(snapshot[@"latitude"] ?: snapshot[@"lat"]) fallback:NAN];
    double longitude = [self doubleFromValue:(snapshot[@"longitude"] ?: snapshot[@"lng"]) fallback:NAN];

    if (isfinite(latitude) && isfinite(longitude) && CLLocationCoordinate2DIsValid(CLLocationCoordinate2DMake(latitude, longitude))) {
        return CLLocationCoordinate2DMake(latitude, longitude);
    }

    CLLocationCoordinate2D pointsCoordinate = [self coordinateFromLocationPointsString:[self safeString:snapshot[@"locationPoints"]]];
    if (CLLocationCoordinate2DIsValid(pointsCoordinate)) {
        return pointsCoordinate;
    }

    pointsCoordinate = [self coordinateFromLocationPointsString:self.selectedAddressModel.locationPoints];
    if (CLLocationCoordinate2DIsValid(pointsCoordinate)) {
        return pointsCoordinate;
    }

    return CLLocationCoordinate2DMake(25.285447, 51.531040);
}

- (NSString *)deliverySubtitle
{
    if (self.selectedAddressModel.displayName.length > 0) {
        return self.selectedAddressModel.displayName;
    }
    return [self resolvedDeliveryAddressText];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return MAX(1, self.lineItems.count);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.lineItems.count == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kOrderDetailsPlaceholderCellID forIndexPath:indexPath];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.backgroundColor = UIColor.clearColor;
        cell.contentView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:PPIOS26() ? 0.72 : 0.96];
        cell.contentView.layer.cornerRadius = 20.0;
        cell.contentView.layer.masksToBounds = YES;
        cell.textLabel.text = kLang(@"order_details_no_items");
        cell.textLabel.font = [GM MidFontWithSize:14];
        cell.textLabel.textColor = UIColor.secondaryLabelColor;
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        if (@available(iOS 13.0, *)) {
            cell.imageView.image = [UIImage systemImageNamed:@"shippingbox"];
        }
        cell.imageView.tintColor = [GM appPrimaryColor];
        return cell;
    }

    OrderItemCell *cell = [tableView dequeueReusableCellWithIdentifier:kOrderDetailsItemCellID forIndexPath:indexPath];
    cell.backgroundColor = UIColor.clearColor;

    if (indexPath.row >= (NSInteger)self.lineItems.count) {
        NSLog(@"❌ [OrderDetails] lineItems out of bounds: row=%ld count=%lu", (long)indexPath.row, (unsigned long)self.lineItems.count);
        return cell;
    }
    NSDictionary *line = self.lineItems[indexPath.row];
    NSString *itemID = [self itemIDFromOrderItem:line];
    NSString *name = [self safeString:line[@"name"]];
    NSInteger quantity = [self integerFromValue:line[@"quantity"] fallback:1];
    double unitPrice = [self doubleFromValue:line[@"price"] fallback:0.0];
    NSString *currency = [self safeString:self.order.currency];
    if (currency.length == 0) currency = [self safeString:[CountryModel safeCurrentCurrencyCode]];
    if (currency.length == 0) currency = @"QAR";
    BOOL canOpenAccessoryViewer = itemID.length > 0;
    cell.selectionStyle = canOpenAccessoryViewer ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    cell.accessoryType = UITableViewCellAccessoryNone;

    if (name.length == 0) {
        name = (itemID.length > 0) ? itemID : kLang(@"order_item");
    }

    cell.nameLabel.text = name;
    cell.quantityLabel.text = [NSString stringWithFormat:@"%@: %ld", kLang(@"QuantityLabel"), (long)quantity];

    if (quantity <= 0) {
        NSLog(@"[OrderDetails] Warning: order item '%@' has quantity %ld", itemID, (long)quantity);
    }
    double lineTotal = MAX(0.0, unitPrice) * MAX(1, quantity);
    cell.priceLabel.text = [NSString stringWithFormat:@"%.2f %@", lineTotal, currency];

    NSString *imageURL = [self safeString:line[@"imageURL"]];
    if (imageURL.length > 0) {
        [GM setImageFromUrlString:imageURL imageView:cell.itemImageView phImage:@"placeholder"];
    } else {
        cell.itemImageView.image = [UIImage imageNamed:@"placeholder"];
    }

    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    (void)tableView;
    (void)section;
    return nil;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    (void)section;
    if (self.lineItems.count == 0) return nil;

    CGFloat width = CGRectGetWidth(tableView.bounds);
    BOOL isRTL = [Language isRTL];
    UIColor *accent = self.order ? [self statusAccentColorForStatusKey:[self customerDisplayStatusKeyForOrder:self.order]] : [GM appPrimaryColor];

    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, width, 54.0)];
    container.backgroundColor = UIColor.clearColor;

    CGFloat horizontalInset = 18.0;
    UIView *iconBubble = [[UIView alloc] initWithFrame:CGRectMake(isRTL ? (width - horizontalInset - 34.0) : horizontalInset, 10.0, 34.0, 34.0)];
    iconBubble.backgroundColor = [accent colorWithAlphaComponent:0.14];
    iconBubble.layer.cornerRadius = 17.0;
    iconBubble.layer.masksToBounds = YES;
    [container addSubview:iconBubble];

    UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectMake(8.0, 8.0, 18.0, 18.0)];
    if (@available(iOS 13.0, *)) {
        iconView.image = [UIImage systemImageNamed:@"bag.fill"];
    }
    iconView.tintColor = accent;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [iconBubble addSubview:iconView];

    UILabel *countLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    countLabel.font = [GM boldFontWithSize:13];
    countLabel.textColor = UIColor.labelColor;
    countLabel.textAlignment = NSTextAlignmentCenter;
    countLabel.backgroundColor = [AppForgroundColr colorWithAlphaComponent:PPIOS26() ? 0.76 : 0.98];
    countLabel.layer.cornerRadius = 14.0;
    countLabel.layer.masksToBounds = YES;
    countLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)self.lineItems.count];
    CGSize countSize = [countLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, 28.0)];
    CGFloat countWidth = MAX(28.0, ceil(countSize.width) + 16.0);
    CGFloat countX = isRTL ? horizontalInset : (width - horizontalInset - countWidth);
    countLabel.frame = CGRectMake(countX, 13.0, countWidth, 28.0);
    [container addSubview:countLabel];

    CGFloat titleX = isRTL ? (horizontalInset + countWidth + 12.0) : CGRectGetMaxX(iconBubble.frame) + 12.0;
    CGFloat titleTrailing = isRTL ? CGRectGetMinX(iconBubble.frame) - 12.0 : (CGRectGetMinX(countLabel.frame) - 12.0);
    CGFloat titleWidth = MAX(0.0, titleTrailing - titleX);
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(titleX, 11.0, titleWidth, 30.0)];
    titleLabel.font = [GM boldFontWithSize:18];
    titleLabel.textColor = UIColor.labelColor;
    titleLabel.textAlignment = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    titleLabel.text = kLang(@"order_items_section_title");
    [container addSubview:titleLabel];

    return container;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    (void)tableView;
    (void)section;
    return (self.lineItems.count > 0) ? 54.0 : 0.01;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    (void)tableView;
    return (self.lineItems.count == 0) ? 88.0 : 96.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= self.lineItems.count) return;
    [self openAccessoryViewerForOrderLine:self.lineItems[indexPath.row]];
}

#pragma mark - MKMapViewDelegate

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    if ([annotation isKindOfClass:MKUserLocation.class]) return nil;

    static NSString * const markerID = @"OrderDeliveryMarker";
    MKAnnotationView *view = [mapView dequeueReusableAnnotationViewWithIdentifier:markerID];
    if (!view) {
        if (@available(iOS 11.0, *)) {
            MKMarkerAnnotationView *marker = [[MKMarkerAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:markerID];
            marker.markerTintColor = [GM appPrimaryColor];
            marker.canShowCallout = YES;
            view = marker;
        } else {
            MKPinAnnotationView *pin = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:markerID];
            pin.pinTintColor = [GM appPrimaryColor];
            pin.canShowCallout = YES;
            view = pin;
        }
    } else {
        view.annotation = annotation;
    }
    return view;
}

#pragma mark - Actions

- (void)toggleProgressTimelineTapped
{
    self.isProgressTimelineExpanded = !self.isProgressTimelineExpanded;
    [self updateStatusStepperAnimated:YES];
    [self refreshVisualTheme];

    [UIView animateWithDuration:0.28
                          delay:0.0
         usingSpringWithDamping:0.94
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        self.progressTimelineToggleIconView.transform = self.isProgressTimelineExpanded ? CGAffineTransformMakeRotation((CGFloat)M_PI) : CGAffineTransformIdentity;
        [self layoutHeaderView];
    } completion:nil];
}

- (void)contactSupportTapped
{
    UIAlertController *sheet = [UIAlertController
                                alertControllerWithTitle:kLang(@"cart_support_menu_title")
                                message:nil
                                preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"order_action_support_case")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction * _Nonnull action) {
        [self presentSupportComposerForAction:PPOrderCustomerActionTypeSupport];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"order_support_request_call")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction * _Nonnull action) {
        [AppClasses callPhoneNumber:kOrderSupportPhoneNumber fromViewController:self];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"cart_support_chat")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction * _Nonnull action) {
        if (!UserManager.sharedManager.isUserLoggedIn) {
            [UserManager showPromptOnTopController];
            return;
        }
        [[ChManager sharedManager] openSupportChatFromController:self];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    if (sheet.popoverPresentationController) {
        UIBarButtonItem *sourceBarButton = self.navigationItem.rightBarButtonItems.count > 1 ? self.navigationItem.rightBarButtonItems.lastObject : nil;
        if (sourceBarButton) {
            sheet.popoverPresentationController.barButtonItem = sourceBarButton;
        } else {
            sheet.popoverPresentationController.sourceView = self.contactSupportButton;
            sheet.popoverPresentationController.sourceRect = self.contactSupportButton.bounds;
        }
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)editLocationTapped
{
    PPOrderEligibilityDecision *decision = [self decisionForAction:PPOrderCustomerActionTypeCancel];
    if (!decision.isEligible) {
        [self showInfoMessage:decision.message.length > 0 ? decision.message : kLang(@"order_edit_location_pending_only")];
        return;
    }
    [self presentAddressPickerFromPaymentSource];
}

- (void)cancelOrderTapped
{
    PPOrderEligibilityDecision *decision = [self decisionForAction:PPOrderCustomerActionTypeCancel];
    if (!decision.isEligible) {
        [self showInfoMessage:decision.message.length > 0 ? decision.message : kLang(@"OrderCannotBeCanceled")];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [PPAlertHelper showConfirmationIn:self
                                title:kLang(@"order_cancel_title")
                             subtitle:kLang(@"order_cancel_confirm")
                        confirmButton:kLang(@"Yes")
                         cancelButton:kLang(@"No")
                                 icon:[UIImage systemImageNamed:@"xmark.circle"]
                         confirmBlock:^(__unused NSString * _Nullable text, BOOL didConfirm) {
        if (!didConfirm) return;
        [weakSelf performCancelOrder];
    } cancelBlock:nil];
}

- (void)performCancelOrder
{
    if (![self safeString:self.order.orderId].length) {
        [self showErrorMessage:kLang(@"order_missing_id")];
        return;
    }

    [self startLoading];
    PPOrderSupportDraft *draft = [PPOrderSupportDraft new];
    draft.actionType = PPOrderCustomerActionTypeCancel;
    draft.reasonCode = @"cancelled_by_user";
    draft.reasonTitle = kLang(@"order_cancel_button");

    __weak typeof(self) weakSelf = self;
    [self.orderManager submitSupportDraft:draft
                                 forOrder:self.order
                               completion:^(PPOrderSupportRequest * _Nullable request, BOOL deduplicated, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf stopLoading];
            if (error) {
                [strongSelf showErrorMessage:error.localizedDescription ?: kLang(@"Error")];
                return;
            }

            [strongSelf showSuccessMessage:deduplicated ? kLang(@"order_existing_request_opened") : kLang(@"OrderCanceled")];
            if (request) {
                [strongSelf openRequestDetailsForRequest:request];
            }
        });
    }];
}

- (void)shareOrderTapped
{
    if (!self.order) return;

    NSString *orderID = [self displayOrderReference];
    if (orderID.length == 0) orderID = @"--";

    NSString *shareText = [NSString stringWithFormat:@"%@ #%@\n%@: %@\n%@: %@",
                           kLang(@"OrderID"),
                           orderID,
                           kLang(@"order_status"),
                           [self displayStatusTitleForOrder:self.order],
                           kLang(@"Total"),
                           [self formattedTotalForOrder:self.order]];
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[shareText] applicationActivities:nil];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = self.view;
        activityVC.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds),
                                                                         CGRectGetMidY(self.view.bounds),
                                                                         0, 0);
        activityVC.popoverPresentationController.permittedArrowDirections = 0;
    }
    [self presentViewController:activityVC animated:YES completion:nil];
}

- (void)onBack:(UIButton *)sender
{
    (void)sender;
    if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    if (self.prefersBackToMainScreen) {
        [self pp_showHomeViewControllerAnimated:YES];
        return;
    }
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)onBackBarButtonTapped
{
    [self onBack:nil];
}

#pragma mark - Address Source

- (void)presentAddressPickerFromPaymentSource
{
    __weak typeof(self) weakSelf = self;
    void (^presentPicker)(NSArray<PPAddressModel *> *) = ^(NSArray<PPAddressModel *> *addresses) {
        if (addresses.count == 0) {
            [weakSelf showInfoMessage:kLang(@"addr_empty_subtitle")];
            return;
        }

        PPSelectOptionViewController *vc =
        [[PPSelectOptionViewController alloc] initWithOptions:addresses
                                                        title:kLang(@"Select Delivery Location")
                                                          row:nil
                                            presentationStyle:PPSelectOptionPresentationSheet
                                                   completion:^(id  _Nullable selectedObject) {
            PPAddressModel *selected = (PPAddressModel *)selectedObject;
            if (![selected isKindOfClass:PPAddressModel.class]) return;
            [weakSelf updateDeliveryAddressWithAddress:selected];
        }];
        [PPFunc presentSheetFrom:weakSelf sheetVC:vc detentStyle:PPSheetDetentStyle70];
        if (@available(iOS 15.0, *)) {
            vc.modalInPresentation = NO;
            UISheetPresentationController *sheet = vc.sheetPresentationController;
            sheet.largestUndimmedDetentIdentifier = nil;
            sheet.prefersGrabberVisible = YES;
        }
    };

    if (self.availableAddresses.count > 0) {
        presentPicker(self.availableAddresses);
        return;
    }

    [PPADDRESS getAllAddressesWithCompletion:^(NSArray<PPAddressModel *> * _Nonnull addresses, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!error && addresses.count > 0) {
                self.availableAddresses = addresses;
                presentPicker(addresses);
                return;
            }

            [PPAlertHelper showConfirmationIn:self
                                        title:kLang(@"addr_empty_title")
                                     subtitle:kLang(@"addr_empty_subtitle")
                                confirmButton:kLang(@"addr_empty_btn_add")
                                 cancelButton:kLang(@"addr_empty_btn_notnow")
                                         icon:[UIImage systemImageNamed:@"house.circle"]
                                 confirmBlock:^(NSString * _Nullable text, BOOL didConfirm) {
                if (!didConfirm) return;
                AddressFormVC *formVC = [[AddressFormVC alloc] initWithAddress:nil];
                [self.navigationController pushViewController:formVC animated:YES];
            } cancelBlock:^{}];
        });
    }];
}

- (void)resolveSelectedAddressFromOrderIfNeeded
{
    if (!self.order || self.isResolvingAddress) return;

    NSDictionary *snapshot = [self.order.shippingAddressSnapshot isKindOfClass:NSDictionary.class] ? self.order.shippingAddressSnapshot : nil;
    NSString *shippingAddressID = [self safeString:self.order.shippingAddressId];
    if (shippingAddressID.length == 0) {
        shippingAddressID = [self safeString:snapshot[@"addressID"]];
    }

    if (snapshot.count > 0) {
        PPAddressModel *snapshotAddress = [[PPAddressModel alloc] initWithDictionary:snapshot documentID:shippingAddressID];
        if (snapshotAddress) {
            snapshotAddress.documentID = shippingAddressID.length > 0 ? shippingAddressID : snapshotAddress.documentID;
            if (snapshotAddress.addressID.length == 0) {
                snapshotAddress.addressID = snapshotAddress.documentID;
            }
            self.selectedAddressModel = snapshotAddress;
        }
    }

    if (self.availableAddresses.count > 0) {
        PPAddressModel *matchedCached = [self preferredAddressFromList:self.availableAddresses
                                                     shippingAddressID:shippingAddressID];
        if (matchedCached) {
            self.selectedAddressModel = matchedCached;
        }
        if (self.selectedAddressModel) {
            [self refreshDeliveryMap];
            return;
        }
    }

    if (self.isResolvingAddress) {
        [self refreshDeliveryMap];
        return;
    }

    self.isResolvingAddress = YES;
    __weak typeof(self) weakSelf = self;
    [PPADDRESS getAllAddressesWithCompletion:^(NSArray<PPAddressModel *> * _Nonnull addresses, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.isResolvingAddress = NO;
            if (error || addresses.count == 0) {
                [strongSelf refreshDeliveryMap];
                return;
            }

            strongSelf.availableAddresses = addresses;
            PPAddressModel *matched = [strongSelf preferredAddressFromList:addresses shippingAddressID:shippingAddressID];
            if (matched) {
                strongSelf.selectedAddressModel = matched;
            }
            [strongSelf refreshDeliveryMap];
        });
    }];
}

- (PPAddressModel * _Nullable)preferredAddressFromList:(NSArray<PPAddressModel *> *)addresses shippingAddressID:(NSString *)shippingAddressID
{
    NSString *targetID = [self safeString:shippingAddressID];
    if (targetID.length == 0) {
        targetID = [self safeString:self.order.shippingAddressId];
    }
    if (targetID.length == 0) {
        targetID = [self safeString:self.order.shippingAddressSnapshot[@"addressID"]];
    }

    if (targetID.length > 0) {
        for (PPAddressModel *address in addresses) {
            NSString *candidate = [self effectiveAddressID:address];
            if ([candidate isEqualToString:targetID]) {
                return address;
            }
        }
    }

    NSString *snapshotDisplay = [self safeString:self.order.shippingAddressSnapshot[@"displayName"]];
    if (snapshotDisplay.length > 0) {
        for (PPAddressModel *address in addresses) {
            if ([[self safeString:address.displayName] isEqualToString:snapshotDisplay]) {
                return address;
            }
        }
    }

    if (self.selectedAddressModel) {
        return nil;
    }

    for (PPAddressModel *address in addresses) {
        if (address.isDefault) return address;
    }
    return addresses.firstObject;
}

- (NSString *)effectiveAddressID:(PPAddressModel *)address
{
    if (!address) return @"";
    NSString *effectiveID = [self safeString:address.documentID];
    if (effectiveID.length == 0) {
        effectiveID = [self safeString:address.addressID];
    }
    if (address.documentID.length == 0) address.documentID = effectiveID;
    if (address.addressID.length == 0) address.addressID = effectiveID;
    return effectiveID;
}

- (void)updateDeliveryAddressWithAddress:(PPAddressModel *)address
{
    if (!address) return;

    NSString *addressID = [self effectiveAddressID:address];
    NSDictionary *snapshot = [self shippingSnapshotFromAddress:address];
    if (snapshot.count == 0) {
        [self showErrorMessage:kLang(@"checkout_invalid_address")];
        return;
    }

    self.selectedAddressModel = address;
    self.order.shippingAddressId = addressID;
    self.order.shippingAddressSnapshot = snapshot;
    [self refreshDeliveryMap];

    NSString *orderID = [self safeString:self.order.orderId];
    if (orderID.length == 0) {
        [self showSuccessMessage:kLang(@"LocationUpdated")];
        return;
    }

    [self startLoading];
    NSDictionary *payload = @{
        @"shippingAddressId": addressID ?: @"",
        @"shippingAddressSnapshot": snapshot ?: @{},
        @"updatedAt": [FIRTimestamp timestamp]
    };

    FIRDocumentReference *ref = [[[FIRFirestore firestore] collectionWithPath:@"Orders"] documentWithPath:orderID];
    __weak typeof(self) weakSelf = self;
    [ref updateData:payload completion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf stopLoading];
            if (error) {
                [strongSelf showErrorMessage:error.localizedDescription ?: kLang(@"Error")];
                return;
            }
            [strongSelf showSuccessMessage:kLang(@"LocationUpdated")];
        });
    }];
}

- (NSDictionary *)shippingSnapshotFromAddress:(PPAddressModel *)address
{
    if (!address) return @{};
    NSString *addressID = [self effectiveAddressID:address];
    if (addressID.length == 0) return @{};

    NSMutableDictionary *snapshot = [[address toDictionary] mutableCopy];
    snapshot[@"addressID"] = addressID;
    snapshot[@"displayName"] = address.displayName ?: @"";
    if (address.locatioName.length > 0) {
        snapshot[@"address"] = address.locatioName;
    }
    NSString *userID = [self safeString:address.userID];
    if (userID.length == 0) {
        userID = [FIRAuth auth].currentUser.uid ?: @"";
    }
    snapshot[@"userID"] = userID ?: @"";

    CLLocationCoordinate2D coordinate = [self coordinateFromLocationPointsString:[self safeString:address.locationPoints]];
    if (CLLocationCoordinate2DIsValid(coordinate)) {
        snapshot[@"latitude"] = @(coordinate.latitude);
        snapshot[@"longitude"] = @(coordinate.longitude);
    }

    return snapshot.copy;
}

#pragma mark - Accessory Fetch

- (void)fetchAccessoryDataForID:(NSString *)itemID completion:(void (^)(NSDictionary * _Nullable data))completion
{
    if (itemID.length == 0) {
        if (completion) completion(nil);
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    FIRDocumentReference *primaryRef = [[db collectionWithPath:@"petAccessories"] documentWithPath:itemID];
    [primaryRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (!error && snapshot.exists) {
            if (completion) completion(snapshot.data);
            return;
        }

        FIRDocumentReference *fallbackRef = [[db collectionWithPath:@"Accessories"] documentWithPath:itemID];
        [fallbackRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable fallbackSnapshot, NSError * _Nullable fallbackError) {
            if (fallbackError || !fallbackSnapshot.exists) {
                if (completion) completion(nil);
                return;
            }
            if (completion) completion(fallbackSnapshot.data);
        }];
    }];
}

- (void)openAccessoryViewerForOrderLine:(NSDictionary *)line
{
    NSString *itemID = [self itemIDFromOrderItem:line];
    if (itemID.length == 0) return;

    PetAccessory *cachedAccessory = [[PetAccessoryManager sharedManager] getAccessoryID:itemID];
    if (cachedAccessory) {
        [self presentAccessoryViewerForAccessory:cachedAccessory];
        return;
    }

    [self startLoading];

    __weak typeof(self) weakSelf = self;
    [PetAccessoryManager fetchAccessoriesWithIDs:@[itemID] completion:^(NSArray<PetAccessory *> *accessories) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        PetAccessory *accessory = accessories.firstObject;
        if (accessory) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongSelf stopLoading];
                [strongSelf presentAccessoryViewerForAccessory:accessory];
            });
            return;
        }

        [strongSelf fetchAccessoryDataForID:itemID completion:^(NSDictionary * _Nullable data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) innerSelf = weakSelf;
                if (!innerSelf) return;
                [innerSelf stopLoading];
                if (![data isKindOfClass:NSDictionary.class] || data.count == 0) {
                    [innerSelf showInfoMessage:kLang(@"SomethingWentWrong")];
                    return;
                }

                PetAccessory *fallbackAccessory = [[PetAccessory alloc] initWithDictionary:data documentID:itemID];
                [innerSelf presentAccessoryViewerForAccessory:fallbackAccessory];
            });
        }];
    }];
}

- (void)presentAccessoryViewerForAccessory:(PetAccessory *)accessory
{
    if (!accessory) return;

    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    AccessViewerVC *viewer = (AccessViewerVC *)[AccessViewerVC  new];
    viewer.accessAds = accessory;
    viewer.ParentVC = self;
    viewer.hidesBottomBarWhenPushed = YES;

    if (self.navigationController) {
        [self.navigationController pushViewController:viewer animated:YES];
        return;
    }

    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewer];
    [self presentViewController:navigationController animated:YES completion:nil];
}

#pragma mark - Helpers

- (BOOL)isOrderCancelable
{
    return [self decisionForAction:PPOrderCustomerActionTypeCancel].isEligible;
}

- (void)trackOrderTapped
{
    [self openTimeline];
}

- (void)viewRequestsTapped
{
    [self openRequestHistory];
}

- (void)requestReturnTapped
{
    [self presentSupportComposerForAction:PPOrderCustomerActionTypeReturn];
}

- (void)requestRefundTapped
{
    [self presentSupportComposerForAction:PPOrderCustomerActionTypeRefund];
}

- (void)requestReplacementTapped
{
    [self presentSupportComposerForAction:PPOrderCustomerActionTypeReplacement];
}

- (void)reportIssueTapped
{
    [self presentSupportComposerForAction:PPOrderCustomerActionTypeComplaint];
}

- (void)startRealtimeObservers
{
    [self stopRealtimeObservers];
    if (![self safeString:self.order.orderId].length) return;
    self.lastObservedOrderStatusKey = [self normalizedStatusKeyForOrder:self.order];

    __weak typeof(self) weakSelf = self;
    FIRDocumentReference *orderRef = [[[FIRFirestore firestore] collectionWithPath:@"Orders"] documentWithPath:self.order.orderId];
    self.orderDocumentListener = [orderRef addSnapshotListener:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error || !snapshot.exists) return;
        PPOrder *updatedOrder = [PPOrder orderFromSnapshot:snapshot];
        if (!updatedOrder) return;

        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        NSString *nextStatusKey = [strongSelf normalizedStatusKeyForOrder:updatedOrder];
        NSString *previousStatusKey = [strongSelf safeString:strongSelf.lastObservedOrderStatusKey];
        BOOL shouldPlayStatusFeedback = strongSelf.isOrderDetailsScreenVisible &&
                                        previousStatusKey.length > 0 &&
                                        nextStatusKey.length > 0 &&
                                        ![previousStatusKey isEqualToString:nextStatusKey];

        if (shouldPlayStatusFeedback) {
            AudioServicesPlaySystemSound(1110);
        }

        strongSelf.lastObservedOrderStatusKey = nextStatusKey;
        strongSelf.order = updatedOrder;
        [strongSelf configureWithCurrentOrder];
        if (shouldPlayStatusFeedback) {
            [strongSelf pp_playCurrentStatusChangeFeedback];
        }
    }];

    self.requestsListener = [self.orderManager listenToSupportRequestsForOrderID:self.order.orderId
                                                                          update:^(NSArray<PPOrderSupportRequest *> *requests, NSError * _Nullable __unused error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.supportRequests = requests ?: @[];
            strongSelf.eligibilityDecisions = [strongSelf.orderManager eligibilityDecisionsForOrder:strongSelf.order
                                                                                        requests:strongSelf.supportRequests
                                                                                   referenceDate:[NSDate date]];
            [strongSelf updateButtonsState];
        });
    }];

    self.timelineListener = [self.orderManager listenToTimelineEventsForOrder:self.order
                                                                       update:^(NSArray<PPOrderTimelineEvent *> *events, NSError * _Nullable __unused error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.timelineEvents = events ?: @[];
        });
    }];
}

- (void)stopRealtimeObservers
{
    [self.orderDocumentListener remove];
    [self.requestsListener remove];
    [self.timelineListener remove];
    self.orderDocumentListener = nil;
    self.requestsListener = nil;
    self.timelineListener = nil;
}

- (void)pp_prepareCheckoutConfettiViewIfNeeded
{
    if (self.checkoutConfettiContainerView && self.checkoutConfettiAnimationView) {
        [self.view bringSubviewToFront:self.checkoutConfettiContainerView];
        return;
    }

    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.userInteractionEnabled = NO;
    container.backgroundColor = UIColor.clearColor;
    container.hidden = YES;
    container.alpha = 0.0;
    container.accessibilityElementsHidden = YES;
    [self.view addSubview:container];

    LOTAnimationView *animationView = [[LOTAnimationView alloc] init];
    animationView.translatesAutoresizingMaskIntoConstraints = NO;
    animationView.userInteractionEnabled = NO;
    animationView.backgroundColor = UIColor.clearColor;
    animationView.opaque = NO;
    animationView.contentMode = UIViewContentModeScaleAspectFit;
    animationView.loopAnimation = NO;
    animationView.animationSpeed = 1.04;
    animationView.hidden = YES;
    animationView.alpha = 1.0;
    animationView.accessibilityElementsHidden = YES;
    [container addSubview:animationView];

    [NSLayoutConstraint activateConstraints:@[
        [container.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [container.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [container.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [container.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [animationView.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [animationView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:-74.0],
        [animationView.widthAnchor constraintEqualToAnchor:container.widthAnchor multiplier:1.38],
        [animationView.heightAnchor constraintEqualToAnchor:animationView.widthAnchor]
    ]];

    self.checkoutConfettiContainerView = container;
    self.checkoutConfettiAnimationView = animationView;
}

- (void)pp_playCheckoutSuccessConfettiIfNeeded
{
    if (self.didPlayCheckoutSuccessConfetti || UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    self.didPlayCheckoutSuccessConfetti = YES;
    [self pp_prepareCheckoutConfettiViewIfNeeded];

    self.checkoutConfettiLoadToken += 1;
    NSInteger token = self.checkoutConfettiLoadToken;

    self.checkoutConfettiContainerView.hidden = NO;
    self.checkoutConfettiContainerView.alpha = 0.0;
    self.checkoutConfettiAnimationView.hidden = YES;
    self.checkoutConfettiAnimationView.alpha = 1.0;
    self.checkoutConfettiAnimationView.transform = CGAffineTransformIdentity;
    [self.checkoutConfettiAnimationView stop];

    __weak typeof(self) weakSelf = self;
    [Styling setAnimationNamed:@"Confetti.lottie"
                        toView:self.checkoutConfettiAnimationView
                     withSpeed:1.04
                 loopAnimation:NO
                      autoplay:NO
                    completion:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.checkoutConfettiLoadToken != token) {
                return;
            }

            if (!success || !self.isOrderDetailsScreenVisible) {
                [self pp_removeCheckoutSuccessConfettiAnimated:NO];
                return;
            }

            [self.view bringSubviewToFront:self.checkoutConfettiContainerView];
            self.checkoutConfettiAnimationView.hidden = NO;
            self.checkoutConfettiAnimationView.loopAnimation = NO;
            self.checkoutConfettiAnimationView.animationProgress = 0.0;

            [UIView animateWithDuration:0.18
                                  delay:0.0
                                options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                self.checkoutConfettiContainerView.alpha = 1.0;
            } completion:nil];

            __weak typeof(self) innerWeakSelf = self;
            [self.checkoutConfettiAnimationView playWithCompletion:^(__unused BOOL finished) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong typeof(innerWeakSelf) innerSelf = innerWeakSelf;
                    if (!innerSelf || innerSelf.checkoutConfettiLoadToken != token) {
                        return;
                    }
                    [innerSelf pp_removeCheckoutSuccessConfettiAnimated:YES];
                });
            }];
        });
    }];
}

- (void)pp_stopCheckoutSuccessConfetti
{
    self.checkoutConfettiLoadToken += 1;
    [self.checkoutConfettiAnimationView stop];
    [self pp_removeCheckoutSuccessConfettiAnimated:NO];
}

- (void)pp_removeCheckoutSuccessConfettiAnimated:(BOOL)animated
{
    if (!self.checkoutConfettiContainerView) {
        return;
    }

    void (^cleanup)(void) = ^{
        [self.checkoutConfettiAnimationView stop];
        [self.checkoutConfettiAnimationView removeFromSuperview];
        [self.checkoutConfettiContainerView removeFromSuperview];
        self.checkoutConfettiAnimationView = nil;
        self.checkoutConfettiContainerView = nil;
    };

    if (!animated) {
        cleanup();
        return;
    }

    [UIView animateWithDuration:0.24
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.checkoutConfettiContainerView.alpha = 0.0;
    } completion:^(__unused BOOL finished) {
        cleanup();
    }];
}

- (void)showEntryPresentationIfNeeded
{
    if (self.didShowEntryPresentation || self.entryPresentationState == PPOrderDetailsEntryPresentationStateNone) return;

    self.didShowEntryPresentation = YES;
    NSString *message = self.entryPresentationMessage.length > 0 ? self.entryPresentationMessage : kLang(@"order_paid_success_subtitle");
    if (self.entryPresentationState == PPOrderDetailsEntryPresentationStateCheckoutSuccess) {
        BOOL shouldPlayCheckoutSuccessConfetti = [self pp_isPushedFromPaymentSelectionViewController];
        if (shouldPlayCheckoutSuccessConfetti && message.length > 0) {
            __weak typeof(self) weakSelf = self;
            [PPAlertHelper showSuccessIn:self
                                   title:kLang(@"Success")
                                subtitle:message
                                OKAction:^(__unused NSString * _Nullable text, __unused BOOL didConfirm) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf || !strongSelf.isOrderDetailsScreenVisible) {
                    return;
                }
                [strongSelf pp_playCheckoutSuccessConfettiIfNeeded];
            }];
        } else {
            [self showSuccessMessage:message];
        }
    } else if (self.entryPresentationState == PPOrderDetailsEntryPresentationStateVerificationPending) {
        [self showInfoMessage:message];
    }
    self.entryPresentationState = PPOrderDetailsEntryPresentationStateNone;
}

- (PPOrderEligibilityDecision *)decisionForAction:(PPOrderCustomerActionType)actionType
{
    for (PPOrderEligibilityDecision *decision in self.eligibilityDecisions ?: @[]) {
        if (decision.actionType == actionType) return decision;
    }
    return [self.orderManager eligibilityForAction:actionType
                                             order:self.order
                                          requests:self.supportRequests
                                     referenceDate:[NSDate date]];
}

- (void)applyActionButton:(UIButton *)button visible:(BOOL)visible eligible:(BOOL)eligible
{
    button.hidden = !visible;
    button.enabled = visible;
    button.alpha = (!visible || eligible) ? 1.0 : 0.72;
}

- (NSString *)buildEligibilityHintText
{
    NSMutableArray<NSString *> *messages = [NSMutableArray array];
    NSArray<PPOrderEligibilityDecision *> *prioritized = @[
        [self decisionForAction:PPOrderCustomerActionTypeCancel],
        [self decisionForAction:PPOrderCustomerActionTypeReturn],
        [self decisionForAction:PPOrderCustomerActionTypeReplacement],
        [self decisionForAction:PPOrderCustomerActionTypeRefund]
    ];
    for (PPOrderEligibilityDecision *decision in prioritized) {
        if (decision.isEligible || decision.message.length == 0) continue;
        if ([messages containsObject:decision.message]) continue;
        [messages addObject:decision.message];
        if (messages.count == 2) break;
    }
    return [messages componentsJoinedByString:@"\n"];
}

- (void)presentSupportComposerForAction:(PPOrderCustomerActionType)actionType
{
    PPOrderEligibilityDecision *decision = [self decisionForAction:actionType];
    if (!decision.isEligible && actionType != PPOrderCustomerActionTypeSupport) {
        [self showInfoMessage:decision.message.length > 0 ? decision.message : kLang(@"order_action_unavailable_generic")];
        return;
    }

    UIViewController *composer = [PPOrderSupportComposerViewController controllerWithOrder:self.order
                                                                                actionType:actionType
                                                                              orderManager:self.orderManager
                                                                                onComplete:^{
        [self updateButtonsState];
    }];
    [self.navigationController pushViewController:composer animated:YES];
}

- (void)openTimeline
{
    UIViewController *timelineVC = [PPOrderTimelineViewController controllerWithOrder:self.order
                                                                         orderManager:self.orderManager
                                                                               events:self.timelineEvents];
    [self.navigationController pushViewController:timelineVC animated:YES];
}

- (void)openRequestHistory
{
    UIViewController *listVC = [PPOrderSupportRequestListViewController controllerWithOrder:self.order
                                                                               orderManager:self.orderManager
                                                                                   requests:self.supportRequests];
    [self.navigationController pushViewController:listVC animated:YES];
}

- (void)openRequestDetailsForRequest:(PPOrderSupportRequest *)request
{
    if (!request) return;
    UIViewController *detailsVC = [PPOrderSupportRequestDetailsViewController controllerWithOrder:self.order
                                                                                    orderManager:self.orderManager
                                                                                         request:request];
    [self.navigationController pushViewController:detailsVC animated:YES];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kCartPricingConfigurationDidChangeNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIAccessibilityReduceMotionStatusDidChangeNotification
                                                  object:nil];
    [self pp_stopLiveBackgroundGlows];
    [self pp_stopHeaderHeroLiquidBorder];
    [self pp_stopCheckoutSuccessConfetti];
    [self stopRealtimeObservers];
}

- (void)handleCartPricingConfigurationDidChange:(NSNotification *)notification
{
    (void)notification;
    if (!self.isViewLoaded || !self.order) return;
    [self configureWithCurrentOrder];
}

- (void)applyCardShadow:(UIView *)view
{
    [view pp_setShadowColor:[GM AppShadowColor]];
    view.layer.shadowOffset = CGSizeMake(0, 14);
    view.layer.shadowOpacity = PPIOS26() ? 0.12 : 0.08;
    view.layer.shadowRadius = 28;
    // L-03: Pre-compute shadow path to eliminate offscreen rendering passes.
    // Updated in viewDidLayoutSubviews once final bounds are resolved.
    if (!CGRectIsEmpty(view.bounds)) {
        view.layer.shadowPath =
            [UIBezierPath bezierPathWithRoundedRect:view.bounds
                                      cornerRadius:view.layer.cornerRadius].CGPath;
    }
}

- (NSString *)formattedTotalForOrder:(PPOrder *)order
{
    NSString *currency = [self safeString:order.currency];
    if (currency.length == 0) currency = [self safeString:[CountryModel safeCurrentCurrencyCode]];
    if (currency.length == 0) currency = @"QAR";
    double total = MAX(0.0, order.totalAmount);
    double effectiveShippingFee = MAX(0.0, order.shippingFee);
    if (effectiveShippingFee <= 0.0 &&
        total <= MAX(0.0, order.amount) + 0.009 &&
        order.amount > 0.0) {
        effectiveShippingFee = MAX(0.0, [CartManager sharedManager].deliveryFee);
    }
    double recomputedTotal = MAX(0.0, order.amount) + effectiveShippingFee;
    if (recomputedTotal > total) total = recomputedTotal;
    if (total <= 0.0) total = MAX(0.0, order.amount);
    return [NSString stringWithFormat:@"%.2f %@", total, currency];
}

- (NSString *)paymentProviderTextForOrder:(PPOrder *)order
{
    NSString *methodText = nil;
    if ([order.paymentMethodId isEqualToString:@"cash"]) {
        methodText = kLang(@"payment_method_name_cash");
    } else {
        methodText = kLang(@"order_payment_provider_default");
    }

    NSString *paymentStatus = [self safeString:order.paymentStatus];
    NSString *statusText = nil;
    if ([paymentStatus isEqualToString:@"pending_collection"]) {
        statusText = kLang(@"order_payment_status_pending_collection");
    } else if ([paymentStatus isEqualToString:@"paid"]) {
        statusText = kLang(@"Paid");
    } else if ([paymentStatus isEqualToString:@"failed"]) {
        statusText = kLang(@"Failed");
    } else if ([paymentStatus isEqualToString:@"cancelled"]) {
        statusText = kLang(@"Canceled");
    } else if (paymentStatus.length > 0) {
        statusText = kLang(@"Pending");
    }

    if (statusText.length > 0) {
        return [NSString stringWithFormat:@"%@ • %@", methodText, statusText];
    }
    return methodText;
}

- (NSString *)resolvedDeliveryAddressText
{
    if (self.selectedAddressModel.displayName.length > 0) {
        return self.selectedAddressModel.displayName;
    }

    NSDictionary *snapshot = [self.order.shippingAddressSnapshot isKindOfClass:NSDictionary.class] ? self.order.shippingAddressSnapshot : nil;
    if (!snapshot) return @"--";

    NSArray<NSString *> *preferredKeys = @[@"displayName", @"address", @"locatioName", @"addressLine1"];
    for (NSString *key in preferredKeys) {
        NSString *value = [self safeString:snapshot[key]];
        if (value.length > 0) return value;
    }

    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    NSString *line1 = [self safeString:snapshot[@"addressLine1"]];
    NSString *line2 = [self safeString:snapshot[@"addressLine2"]];
    NSString *postal = [self safeString:snapshot[@"postalCode"]];
    if (line1.length > 0) [parts addObject:line1];
    if (line2.length > 0) [parts addObject:line2];
    if (postal.length > 0) [parts addObject:postal];

    if (parts.count == 0) return @"--";
    return [parts componentsJoinedByString:@", "];
}

- (CLLocationCoordinate2D)coordinateFromLocationPointsString:(NSString *)locationPoints
{
    NSString *trimmed = [self safeString:locationPoints];
    if (trimmed.length == 0) {
        return kCLLocationCoordinate2DInvalid;
    }

    NSArray<NSString *> *parts = [trimmed componentsSeparatedByString:@","];
    if (parts.count < 2) {
        return kCLLocationCoordinate2DInvalid;
    }

    double latitude = [parts[0] doubleValue];
    double longitude = [parts[1] doubleValue];
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(latitude, longitude);
    if (!CLLocationCoordinate2DIsValid(coordinate) || !isfinite(latitude) || !isfinite(longitude)) {
        return kCLLocationCoordinate2DInvalid;
    }
    return coordinate;
}

- (NSString *)titleForStatus:(PPOrderStatus)status
{
    switch (status) {
        case PPOrderStatusPending: return kLang(@"Pending");
        case PPOrderStatusPaid: return kLang(@"Paid");
        case PPOrderStatusFailed: return kLang(@"Failed");
    }
    return kLang(@"Unknown");
}

- (NSString *)itemIDFromOrderItem:(NSDictionary *)item
{
    if (![item isKindOfClass:NSDictionary.class]) return @"";
    NSString *itemID = [self safeString:item[@"id"]];
    if (itemID.length == 0) itemID = [self safeString:item[@"itemID"]];
    if (itemID.length == 0) itemID = [self safeString:item[@"productId"]];
    if (itemID.length == 0) itemID = [self safeString:item[@"productID"]];
    return itemID;
}

- (NSString *)imageURLFromData:(NSDictionary *)data
{
    if (![data isKindOfClass:NSDictionary.class]) return @"";

    NSArray<NSString *> *keys = @[@"image", @"imageURL", @"imageUrl", @"photo", @"icon"];
    for (NSString *key in keys) {
        NSString *value = [self safeString:data[key]];
        if (value.length > 0) return value;
    }

    id imageURLsArray = data[@"imageURLsArray"];
    if ([imageURLsArray isKindOfClass:NSArray.class]) {
        NSArray *arr = (NSArray *)imageURLsArray;
        if (arr.count > 0) {
            NSString *value = [self safeString:arr.firstObject];
            if (value.length > 0) return value;
        }
    }
    return @"";
}

- (NSInteger)integerFromValue:(id)value fallback:(NSInteger)fallback
{
    if ([value respondsToSelector:@selector(integerValue)]) {
        return [value integerValue];
    }
    return fallback;
}

- (double)doubleFromValue:(id)value fallback:(double)fallback
{
    if ([value respondsToSelector:@selector(doubleValue)]) {
        return [value doubleValue];
    }
    return fallback;
}

- (NSString *)safeString:(id)value
{
    if (![value isKindOfClass:NSString.class]) return @"";
    return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)cancelLoadingTimeout
{
    if (self.loadingTimeoutBlock) {
        dispatch_block_cancel(self.loadingTimeoutBlock);
        self.loadingTimeoutBlock = nil;
    }
}

- (void)scheduleLoadingTimeout
{
    [self cancelLoadingTimeout];

    __weak typeof(self) weakSelf = self;
    dispatch_block_t timeoutBlock = dispatch_block_create(0, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.loadingTimeoutBlock = nil;

        if (strongSelf.loadingIndicator.isAnimating) {
            [strongSelf stopLoading];
            [strongSelf showLoadingTimeoutErrorWithRetry];
        }
    });
    self.loadingTimeoutBlock = timeoutBlock;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(),
                   timeoutBlock);
}

- (void)showLoadingTimeoutErrorWithRetry
{
    if (self.presentedViewController) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"connection_timeout_title")
                                                                  message:kLang(@"connection_timeout_message")
                                                           preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"KLang_Retry")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf configureWithCurrentOrder];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)startLoading
{
    self.loadingOverlay.hidden = NO;
    [self.loadingIndicator startAnimating];
    [self scheduleLoadingTimeout];
}

- (void)stopLoading
{
    [self cancelLoadingTimeout];
    self.loadingOverlay.hidden = YES;
    [self.loadingIndicator stopAnimating];
}

- (void)showSuccessMessage:(NSString *)message
{
    if (message.length == 0) return;
    [PPAlertHelper showSuccessIn:self title:kLang(@"Success") subtitle:message];
}

- (void)showErrorMessage:(NSString *)message
{
    if (message.length == 0) return;
    [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:message];
}

- (void)showInfoMessage:(NSString *)message
{
    if (message.length == 0) return;
    [PPAlertHelper showInfoIn:self title:kLang(@"Info") subtitle:message];
}

- (void)showMessageWithTitle:(NSString *)title message:(NSString *)message
{
    if (message.length == 0) return;
    [PPAlertHelper showInfoIn:self title:title subtitle:message];
}

- (void)orderIDTapped
{
    NSString *orderID = [self displayOrderReference];
    if (orderID.length == 0) return;

    __weak typeof(self) weakSelf = self;
    [PPAlertHelper showConfirmationIn:self
                                title:self.orderIDLabel.text ?: [NSString stringWithFormat:@"#%@", orderID]
                             subtitle:kLang(@"order_copy_id_subtitle")
                        confirmButton:kLang(@"Copy")
                         cancelButton:kLang(@"cancel")
                                 icon:[UIImage systemImageNamed:@"doc.on.doc"]
                         confirmBlock:^(__unused NSString * _Nullable text, BOOL didConfirm) {
        if (!didConfirm) return;
        [UIPasteboard generalPasteboard].string = orderID;
        [weakSelf showSuccessMessage:kLang(@"order_id_copied")];
    } cancelBlock:nil];
}

- (NSString *)displayOrderReference
{
    NSString *reference = [self safeString:[self.order displayOrderReference]];
    if (reference.length > 0) {
        return reference;
    }
    return [self safeString:self.order.orderId];
}



#pragma mark - Actions

- (void)openMapTapped
{
    CLLocationCoordinate2D c = [self currentDeliveryCoordinate];
    if (!CLLocationCoordinate2DIsValid(c)) {
        [self showInfoMessage:kLang(@"DeliveryLocationSub")];
        return;
    }

    // Prefer Google Maps if installed, else fall back to Apple Maps.
    NSString *googleURLString = [NSString stringWithFormat:@"comgooglemaps://?q=%f,%f&center=%f,%f&zoom=15", c.latitude, c.longitude, c.latitude, c.longitude];
    NSURL *googleURL = [NSURL URLWithString:googleURLString];

    if (googleURL && [UIApplication.sharedApplication canOpenURL:googleURL]) {
        [UIApplication.sharedApplication openURL:googleURL options:@{} completionHandler:nil];
        return;
    }

    NSURL *appleURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://maps.apple.com/?q=%f,%f", c.latitude, c.longitude]];
    if (appleURL) {
        [UIApplication.sharedApplication openURL:appleURL options:@{} completionHandler:nil];
    }
}

#pragma mark - Fulfillment (Phase 15 — read-only, customer-side)

- (void)configureFulfillmentSection
{
    if (!self.order.hasFulfillmentOrders) {
        self.fulfillmentOrders = @[];
        self.fulfillmentSectionCard.hidden = YES;
        self.fulfillmentSectionCard.frame = CGRectZero;
        [self layoutFooterView];
        return;
    }
    PPweakify(self);
    [[PPOrderManager shared] fetchFulfillmentOrdersWithIDs:self.order.fulfillmentOrderIDs completion:^(NSArray<PPFulfillmentOrder *> *orders) {
        PPstrongify(self);
        if (!self) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            self.fulfillmentOrders = orders ?: @[];
            UIView *card = [self buildFulfillmentGroupsCard:self.fulfillmentOrders];
            [self.fulfillmentSectionCard removeFromSuperview];
            self.fulfillmentSectionCard = card ?: [[UIView alloc] initWithFrame:CGRectZero];
            self.fulfillmentSectionCard.hidden = (card == nil);
            [self.footerContainer addSubview:self.fulfillmentSectionCard];
            [self.footerContainer sendSubviewToBack:self.fulfillmentSectionCard];
            [self layoutFooterView];
        });
    }];
}

- (NSDictionary<NSString *, NSNumber *> *)fulfillmentSummaryMetricsForOrders:(NSArray<PPFulfillmentOrder *> *)orders
{
    NSInteger total = orders.count;
    NSInteger completed = 0;

    for (PPFulfillmentOrder *order in orders ?: @[]) {
        NSString *status = PPOrderStepperNormalizedKey(order.status);
        if ([status isEqualToString:@"completed"]) {
            completed += 1;
        }
    }

    NSDictionary *summary = [self.order.fulfillmentSummary isKindOfClass:NSDictionary.class] ? self.order.fulfillmentSummary : nil;
    NSInteger backendTotal = [summary[@"total"] integerValue];
    if (backendTotal <= 0) {
        backendTotal = [summary[@"totalCount"] integerValue];
    }
    NSInteger backendCompleted = [summary[@"completedCount"] integerValue];

    if (total <= 0) {
        total = MAX(0, backendTotal);
    }
    if (completed <= 0 && backendCompleted > 0) {
        completed = backendCompleted;
    }

    completed = MIN(MAX(0, completed), MAX(0, total));
    return @{
        @"total": @(MAX(0, total)),
        @"completed": @(completed)
    };
}

- (UIView *)buildFulfillmentGroupsCard:(NSArray<PPFulfillmentOrder *> *)orders
{
    if (orders.count == 0) return nil;

    UIView *card = [[UIView alloc] init];
    card.backgroundColor = AppForgroundColr;
    card.layer.cornerRadius = MAX(PPCornerCard, 24.0);
    card.layer.masksToBounds = YES;
    card.layer.borderWidth = 1.0;
    UIColor *accent = self.order ? [self statusAccentColorForStatusKey:[self customerDisplayStatusKeyForOrder:self.order]] : [GM appPrimaryColor];
    [card pp_setBorderColor:[accent colorWithAlphaComponent:0.12]];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = kLang(@"fulfillment_section_title");
    titleLabel.font = [GM boldFontWithSize:PPFontHeadline];
    titleLabel.textColor = UIColor.labelColor;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:titleLabel];

    UILabel *summaryLabel = [[UILabel alloc] init];
    NSDictionary<NSString *, NSNumber *> *metrics = [self fulfillmentSummaryMetricsForOrders:orders];
    NSInteger total = metrics[@"total"].integerValue;
    NSInteger completed = metrics[@"completed"].integerValue;
    summaryLabel.text = [NSString stringWithFormat:@"%ld/%ld %@", (long)completed, (long)total, kLang(@"fulfillment_summary_completed")];
    summaryLabel.font = [GM MidFontWithSize:PPFontCallout];
    summaryLabel.textColor = UIColor.secondaryLabelColor;
    summaryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:summaryLabel];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:PPSpaceBase],
        [titleLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-PPSpaceBase],
        [titleLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:PPSpaceBase],
        [summaryLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [summaryLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [summaryLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:PPSpaceSM],
    ]];

    UIView *previous = summaryLabel;
    for (PPFulfillmentOrder *fo in orders) {
        UIView *group = [self buildFulfillmentGroupCard:fo];
        group.translatesAutoresizingMaskIntoConstraints = NO;
        [card addSubview:group];
        [NSLayoutConstraint activateConstraints:@[
            [group.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
            [group.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
            [group.topAnchor constraintEqualToAnchor:previous.bottomAnchor constant:PPSpaceSM],
        ]];
        previous = group;
    }

    [[previous.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-PPSpaceBase] setActive:YES];

    CGFloat width = CGRectGetWidth(UIScreen.mainScreen.bounds) - 32.0;
    CGSize fit = [card systemLayoutSizeFittingSize:CGSizeMake(width, UIViewNoIntrinsicMetric)
                     withHorizontalFittingPriority:UILayoutPriorityRequired
                               verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    card.frame = CGRectMake(0, 0, width, fit.height);
    [card layoutIfNeeded];
    return card;
}

- (UIView *)buildFulfillmentGroupCard:(PPFulfillmentOrder *)fo
{
    UIView *group = [[UIView alloc] init];
    group.backgroundColor = AppForgroundColr;
    group.layer.cornerRadius = PPCornerMedium;
    group.layer.masksToBounds = YES;
    group.layer.borderWidth = 1.0;
    UIColor *accent = self.order ? [self statusAccentColorForStatusKey:[self customerDisplayStatusKeyForOrder:self.order]] : [GM appPrimaryColor];
    [group pp_setBorderColor:[accent colorWithAlphaComponent:0.06]];

    UILabel *ownerLabel = [[UILabel alloc] init];
    ownerLabel.text = [fo.ownerType isEqualToString:@"partner"] ? kLang(@"fulfillment_owner_partner") : kLang(@"fulfillment_owner_platform");
    ownerLabel.font = [GM boldFontWithSize:PPFontSubheadline];
    ownerLabel.textColor = UIColor.labelColor;
    ownerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [group addSubview:ownerLabel];

    UILabel *statusBadge = [[UILabel alloc] init];
    statusBadge.text = [NSString stringWithFormat:@"  %@  ", [self fulfillmentStatusDisplayName:fo.status]];
    statusBadge.font = [GM boldFontWithSize:10];
    UIColor *sc = [self fulfillmentStatusColor:fo.status];
    statusBadge.textColor = sc;
    statusBadge.backgroundColor = [sc colorWithAlphaComponent:0.12];
    statusBadge.layer.cornerRadius = PPCornerSmall / 2.0;
    statusBadge.clipsToBounds = YES;
    statusBadge.translatesAutoresizingMaskIntoConstraints = NO;
    [group addSubview:statusBadge];

    UILabel *metaLabel = [[UILabel alloc] init];
    metaLabel.text = [NSString stringWithFormat:kLang(@"fulfillment_items_count"), (long)fo.itemCount];
    metaLabel.font = [GM MidFontWithSize:PPFontFootnote];
    metaLabel.textColor = UIColor.secondaryLabelColor;
    metaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [group addSubview:metaLabel];

    UIView *amountPill = [[UIView alloc] init];
    amountPill.translatesAutoresizingMaskIntoConstraints = NO;
    amountPill.backgroundColor = [accent colorWithAlphaComponent:0.08];
    amountPill.layer.cornerRadius = 15.0;
    amountPill.layer.masksToBounds = YES;
    amountPill.layer.borderWidth = 1.0;
    [amountPill pp_setBorderColor:[accent colorWithAlphaComponent:0.12]];
    [group addSubview:amountPill];

    UILabel *amountLabel = [[UILabel alloc] init];
    amountLabel.text = [NSString stringWithFormat:@"%@ %.0f", fo.currency, fo.providerNet];
    amountLabel.font = [GM boldFontWithSize:PPFontCallout];
    amountLabel.textColor = UIColor.labelColor;
    amountLabel.textAlignment = NSTextAlignmentCenter;
    amountLabel.adjustsFontSizeToFitWidth = YES;
    amountLabel.minimumScaleFactor = 0.78;
    amountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [amountPill addSubview:amountLabel];

    [NSLayoutConstraint activateConstraints:@[
        [ownerLabel.leadingAnchor constraintEqualToAnchor:group.leadingAnchor constant:PPSpaceMD],
        [ownerLabel.topAnchor constraintEqualToAnchor:group.topAnchor constant:PPSpaceMD],
        [statusBadge.trailingAnchor constraintEqualToAnchor:group.trailingAnchor constant:-PPSpaceMD],
        [statusBadge.centerYAnchor constraintEqualToAnchor:ownerLabel.centerYAnchor],
        [metaLabel.leadingAnchor constraintEqualToAnchor:ownerLabel.leadingAnchor],
        [metaLabel.topAnchor constraintEqualToAnchor:ownerLabel.bottomAnchor constant:4.0],
        [amountPill.trailingAnchor constraintEqualToAnchor:group.trailingAnchor constant:-PPSpaceMD],
        [amountPill.topAnchor constraintEqualToAnchor:statusBadge.bottomAnchor constant:8.0],
        [amountPill.bottomAnchor constraintLessThanOrEqualToAnchor:group.bottomAnchor constant:-PPSpaceMD],
        [amountPill.leadingAnchor constraintGreaterThanOrEqualToAnchor:metaLabel.trailingAnchor constant:PPSpaceSM],
        [amountLabel.topAnchor constraintEqualToAnchor:amountPill.topAnchor constant:6.0],
        [amountLabel.leadingAnchor constraintEqualToAnchor:amountPill.leadingAnchor constant:12.0],
        [amountLabel.trailingAnchor constraintEqualToAnchor:amountPill.trailingAnchor constant:-12.0],
        [amountLabel.bottomAnchor constraintEqualToAnchor:amountPill.bottomAnchor constant:-6.0],
        [metaLabel.bottomAnchor constraintEqualToAnchor:group.bottomAnchor constant:-PPSpaceMD],
    ]];
    return group;
}

- (NSString *)fulfillmentStatusDisplayName:(NSString *)status
{
    static NSDictionary *map = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = @{
            @"new_request":        kLang(@"fulfillment_status_new_request"),
            @"accepted":           kLang(@"fulfillment_status_accepted"),
            @"rejected":           kLang(@"fulfillment_status_rejected"),
            @"preparing":          kLang(@"fulfillment_status_preparing"),
            @"ready_for_pickup":   kLang(@"fulfillment_status_ready_for_pickup"),
            @"delivery_requested": kLang(@"fulfillment_status_delivery_requested"),
            @"awaiting_handover":  kLang(@"fulfillment_status_awaiting_handover"),
            @"handed_over":        kLang(@"fulfillment_status_handed_over"),
            @"completed":          kLang(@"fulfillment_status_completed"),
            @"cancelled":          kLang(@"fulfillment_status_cancelled"),
            @"failed":             kLang(@"fulfillment_status_failed"),
            @"returned":           kLang(@"fulfillment_status_returned"),
        };
    });
    NSString *name = map[status];
    return name.length > 0 ? name : kLang(@"fulfillment_status_unknown");
}

- (UIColor *)fulfillmentStatusColor:(NSString *)status
{
    NSString *s = status;
    if ([s isEqualToString:@"accepted"] || [s isEqualToString:@"completed"] || [s isEqualToString:@"ready_for_pickup"]) return UIColor.systemGreenColor;
    if ([s isEqualToString:@"new_request"] || [s isEqualToString:@"preparing"] || [s isEqualToString:@"delivery_requested"] || [s isEqualToString:@"awaiting_handover"]) return UIColor.systemOrangeColor;
    if ([s isEqualToString:@"rejected"] || [s isEqualToString:@"cancelled"] || [s isEqualToString:@"failed"] || [s isEqualToString:@"returned"]) return UIColor.systemRedColor;
    return UIColor.systemGrayColor;
}

@end
