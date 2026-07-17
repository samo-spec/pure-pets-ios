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
#import "PPOrderProgressTimelineView.h"
#import "PPOrderStatusStepperView.h"
#import "PPOrderStatusAppearance.h"
#import "PPOrderSupportComposerViewController.h"
#import "PPOrderSupportRequestDetailsViewController.h"
#import "PPOrderSupportRequestListViewController.h"
#import "PPOrderTimelineViewController.h"
#import "AddressFormVC.h"
#import "OrderSupportFunc.h"
#import "AppClasses.h"
#import "PPAlertHelper.h"
#import "PPBackgroundView.h"
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

CGFloat const kOrderDetailsScreenMargin = 16.0;



UIColor *PPOrderDetailsSurfaceColor(void)
{
    CGFloat alpha = UIAccessibilityIsReduceTransparencyEnabled() ? 1.0 : (PPIOS26() ? 0.58 : 0.84);
    return [AppForgroundColr colorWithAlphaComponent:alpha];
}

UIColor *PPOrderDetailsSubsurfaceColor(void)
{
    CGFloat alpha = UIAccessibilityIsReduceTransparencyEnabled() ? 1.0 : (PPIOS26() ? 0.68 : 0.84);
    return [[UIColor secondarySystemBackgroundColor] colorWithAlphaComponent:alpha];
}

void PPOrderDetailsApplySurface(UIView *view, CGFloat cornerRadius, BOOL elevated)
{
    if (!view) return;
    view.backgroundColor = PPOrderDetailsSurfaceColor();
    view.opaque = NO;
    PPApplyContinuousCorners(view, cornerRadius);
    view.layer.masksToBounds = NO;
    view.layer.borderWidth = 0.75;
    [view pp_setBorderColor:[[UIColor labelColor] colorWithAlphaComponent:0.055]];
    if (elevated) {
        PPApplyCardShadow(view);
    } else {
        view.layer.shadowOpacity = 0.0;
    }
}

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
    if ([normalized isEqualToString:@"pending"]) return kLang(@"order_placed_title");
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
    if ([normalized isEqualToString:@"pending"]) return kLang(@"order_delivery_hint_waiting_acceptance");
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

NSString *PPOrderStepperSymbolForTitle(NSString *title, NSInteger index)
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

UIImage *PPOrderStepperImage(NSString *name)
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



UIColor *PPOrderRequestStatusColor(NSString *status)
{
    NSString *normalized = PPOrderStepperNormalizedKey(status);
    if ([normalized isEqualToString:@"approved"]) {
        return PPOrderStatusAccentColorForKey(@"paid");
    }
    if ([normalized isEqualToString:@"completed"]) {
        return PPOrderStatusAccentColorForKey(@"completed");
    }
    if ([normalized isEqualToString:@"refunded"] ||
        [normalized isEqualToString:@"partially_refunded"]) {
        return PPOrderStatusAccentColorForKey(@"returned");
    }
    if ([normalized isEqualToString:@"rejected"] ||
        [normalized isEqualToString:@"cancelled"] ||
        [normalized isEqualToString:@"closed"]) {
        return PPOrderStatusAccentColorForKey(@"delivery_cancelled");
    }
    return PPOrderStatusAccentColorForKey(normalized.length > 0 ? normalized : @"pending");
}

NSString *PPOrderTimelineTitle(PPOrderTimelineEvent *event)
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

NSString *PPOrderTimelineSubtitle(PPOrderTimelineEvent *event)
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
@property (nonatomic, strong) PPBackgroundView *heroGlassBackground;
@property (nonatomic, strong) UIView *ambientDotsContainerView;
@property (nonatomic, strong) UIView *ambientDot1;
@property (nonatomic, strong) UIView *ambientDot2;
@property (nonatomic, strong) UIView *ambientDot3;
@property (nonatomic, assign) CGSize ambientDotsLayoutSize;
@property (nonatomic, assign) BOOL ambientDotsLayoutRTL;
@property (nonatomic, strong) UILabel *statusSummarySubtitleLabel;
@property (nonatomic, strong) UIView *statusProgressChip;
@property (nonatomic, strong) CAGradientLayer *statusProgressChipGradientLayer;
@property (nonatomic, strong) UIImageView *statusProgressChipIconView;
@property (nonatomic, strong) UILabel *statusProgressChipLabel;
@property (nonatomic, strong) UIView *statusEtaChip;
@property (nonatomic, strong) CAGradientLayer *statusEtaChipGradientLayer;
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
@property (nonatomic, strong) CAGradientLayer *statusBadgeGradientLayer;
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
@property (nonatomic, strong) UIView *loadingSurface;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) UILabel *loadingLabel;
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
@property (nonatomic, assign) BOOL didPreparePremiumEntrance;
@property (nonatomic, assign) BOOL didRunPremiumEntrance;

- (void)pp_playCheckoutSuccessConfettiIfNeeded;
- (void)pp_stopCheckoutSuccessConfetti;
- (void)pp_removeCheckoutSuccessConfettiAnimated:(BOOL)animated;
- (void)pp_installLiveBackgroundGlowLayersIfNeeded;
- (void)pp_updateLiveBackgroundGlowFrames;
- (void)pp_refreshLiveBackgroundGlowColors;
- (void)pp_startLiveBackgroundGlowsIfNeeded;
- (void)pp_stopLiveBackgroundGlows;
- (void)pp_updateLiveBackgroundGlowsForScrollOffset:(CGFloat)contentOffsetY;
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
- (void)pp_layoutAmbientHeroDotsForSize:(CGSize)size isRTL:(BOOL)isRTL;
- (void)pp_startAmbientHeroDotsMotionIfNeeded;
- (void)pp_stopAmbientHeroDotsMotion;
- (void)pp_refreshCurrentStatusSummaryMotionColors;
- (void)pp_startCurrentStatusSummaryMotionIfNeeded;
- (void)pp_stopCurrentStatusSummaryMotion;
- (void)pp_playCurrentStatusChangeFeedback;
- (void)pp_handleReduceMotionStatusDidChange:(NSNotification *)notification;
- (void)pp_preparePremiumEntranceIfNeeded;
- (void)pp_runPremiumEntranceIfNeeded;
- (void)pp_actionButtonTouchDown:(UIButton *)sender;
- (void)pp_actionButtonTouchUp:(UIButton *)sender;

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
    [self pp_preparePremiumEntranceIfNeeded];
    [self startRealtimeObservers];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self setupNavigationBar];
    [self pp_preparePremiumEntranceIfNeeded];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.isOrderDetailsScreenVisible = YES;
    [self pp_runPremiumEntranceIfNeeded];
    [self showEntryPresentationIfNeeded];
    //[self.heroGlassBackground startAnimations];
    [self pp_updateLiveBackgroundGlowsForScrollOffset:self.tableView.contentOffset.y];
    [self pp_startLiveBackgroundGlowsIfNeeded];
    [self pp_startCurrentStatusSummaryMotionIfNeeded];
    [self.progressTimelineView refreshCurrentStatusMotion];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    self.isOrderDetailsScreenVisible = NO;
    //[self.heroGlassBackground stopAnimations];
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

- (void)pp_preparePremiumEntranceIfNeeded
{
    if (self.didRunPremiumEntrance || self.didPreparePremiumEntrance || !self.isViewLoaded) return;

    self.didPreparePremiumEntrance = YES;
    self.headerCard.alpha = 0.0;
    self.headerCard.transform = CGAffineTransformMakeTranslation(0.0, 14.0);
    self.tableView.alpha = 0.0;
    self.tableView.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
    self.footerContainer.alpha = 0.0;
    self.footerContainer.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
    self.backgroundTopGlowView.alpha = 0.0;
    self.backgroundTopGlowView.transform = CGAffineTransformMakeScale(0.92, 0.92);
    self.backgroundBottomGlowView.alpha = 0.0;
    self.backgroundBottomGlowView.transform = CGAffineTransformMakeScale(0.94, 0.94);
}

- (void)pp_runPremiumEntranceIfNeeded
{
    if (self.didRunPremiumEntrance || !self.didPreparePremiumEntrance) return;
    self.didRunPremiumEntrance = YES;
    [self.view layoutIfNeeded];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.headerCard.alpha = 1.0;
        self.headerCard.transform = CGAffineTransformIdentity;
        self.tableView.alpha = 1.0;
        self.tableView.transform = CGAffineTransformIdentity;
        self.footerContainer.alpha = 1.0;
        self.footerContainer.transform = CGAffineTransformIdentity;
        self.backgroundTopGlowView.alpha = kOrderDetailsTopGlowRestingAlpha;
        self.backgroundTopGlowView.transform = CGAffineTransformIdentity;
        self.backgroundBottomGlowView.alpha = kOrderDetailsBottomGlowRestingAlpha;
        self.backgroundBottomGlowView.transform = CGAffineTransformIdentity;
        return;
    }

    [UIView animateWithDuration:0.58
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.backgroundTopGlowView.alpha = kOrderDetailsTopGlowRestingAlpha;
        self.backgroundTopGlowView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.68
                          delay:0.06
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.backgroundBottomGlowView.alpha = kOrderDetailsBottomGlowRestingAlpha;
        self.backgroundBottomGlowView.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        if (!finished || !self.isOrderDetailsScreenVisible) return;
        [self pp_updateLiveBackgroundGlowsForScrollOffset:self.tableView.contentOffset.y];
    }];

    [UIView animateWithDuration:0.38
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.headerCard.alpha = 1.0;
        self.headerCard.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.34
                          delay:0.07
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.tableView.alpha = 1.0;
        self.tableView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.38
                          delay:0.13
         usingSpringWithDamping:0.92
          initialSpringVelocity:0.25
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.footerContainer.alpha = 1.0;
        self.footerContainer.transform = CGAffineTransformIdentity;
    } completion:nil];
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
    NSString *statusKey = self.order ? [self customerDisplayStatusKeyForOrder:self.order] : @"pending";
    UIColor *accent = PPOrderStatusResolvedColor([self statusAccentColorForStatusKey:statusKey], self.traitCollection);
    UIColor *shine = PPOrderStatusResolvedColor(PPOrderStatusShineColorForKey(statusKey), self.traitCollection);
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    UIColor *ink = isDark ? [UIColor colorWithRed:0.01 green:0.02 blue:0.018 alpha:1.0] : [UIColor colorWithRed:0.04 green:0.055 blue:0.048 alpha:1.0];
    UIColor *support = PPOrderStatusBlendColors(accent, shine, isDark ? 0.48 : 0.36, self.traitCollection);

    self.backgroundTopGlowLayer.colors = @[
        (__bridge id)[shine colorWithAlphaComponent:isDark ? 0.30 : 0.22].CGColor,
        (__bridge id)[accent colorWithAlphaComponent:isDark ? 0.21 : 0.16].CGColor,
        (__bridge id)[ink colorWithAlphaComponent:0.0].CGColor
    ];
    self.backgroundBottomGlowLayer.colors = @[
        (__bridge id)[support colorWithAlphaComponent:isDark ? 0.27 : 0.20].CGColor,
        (__bridge id)[accent colorWithAlphaComponent:isDark ? 0.18 : 0.14].CGColor,
        (__bridge id)[ink colorWithAlphaComponent:0.0].CGColor
    ];
}

- (void)pp_startLiveBackgroundGlowsIfNeeded
{
    [self pp_installLiveBackgroundGlowLayersIfNeeded];
    if (!self.isOrderDetailsScreenVisible ||
        !self.backgroundTopGlowView.window ||
        CGRectIsEmpty(self.backgroundTopGlowView.bounds) ||
        CGRectIsEmpty(self.backgroundBottomGlowView.bounds)) {
        return;
    }
    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self pp_stopLiveBackgroundGlows];
        return;
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.backgroundTopGlowLayer.opacity = 0.78;
    self.backgroundBottomGlowLayer.opacity = 0.68;
    [CATransaction commit];

    if (![self.backgroundTopGlowLayer animationForKey:@"pp_order_top_glow_breath"]) {
        CABasicAnimation *opacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
        opacity.fromValue = @0.60;
        opacity.toValue = @0.94;

        CABasicAnimation *origin = [CABasicAnimation animationWithKeyPath:@"startPoint"];
        origin.fromValue = [NSValue valueWithCGPoint:CGPointMake(0.10, 0.10)];
        origin.toValue = [NSValue valueWithCGPoint:CGPointMake(0.34, 0.28)];

        CABasicAnimation *edge = [CABasicAnimation animationWithKeyPath:@"endPoint"];
        edge.fromValue = [NSValue valueWithCGPoint:CGPointMake(0.82, 0.90)];
        edge.toValue = [NSValue valueWithCGPoint:CGPointMake(1.02, 0.72)];

        CAAnimationGroup *group = [CAAnimationGroup animation];
        group.animations = @[opacity, origin, edge];
        group.duration = 5.4;
        group.autoreverses = YES;
        group.repeatCount = HUGE_VALF;
        group.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        group.removedOnCompletion = YES;
        [self.backgroundTopGlowLayer addAnimation:group forKey:@"pp_order_top_glow_breath"];
    }

    if (![self.backgroundBottomGlowLayer animationForKey:@"pp_order_bottom_glow_breath"]) {
        CABasicAnimation *opacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
        opacity.fromValue = @0.52;
        opacity.toValue = @0.86;

        CABasicAnimation *origin = [CABasicAnimation animationWithKeyPath:@"startPoint"];
        origin.fromValue = [NSValue valueWithCGPoint:CGPointMake(0.20, 0.14)];
        origin.toValue = [NSValue valueWithCGPoint:CGPointMake(0.48, 0.34)];

        CABasicAnimation *edge = [CABasicAnimation animationWithKeyPath:@"endPoint"];
        edge.fromValue = [NSValue valueWithCGPoint:CGPointMake(0.78, 0.94)];
        edge.toValue = [NSValue valueWithCGPoint:CGPointMake(1.02, 0.74)];

        CAAnimationGroup *group = [CAAnimationGroup animation];
        group.animations = @[opacity, origin, edge];
        group.duration = 6.0;
        group.beginTime = CACurrentMediaTime() + 0.35;
        group.autoreverses = YES;
        group.repeatCount = HUGE_VALF;
        group.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        group.removedOnCompletion = YES;
        [self.backgroundBottomGlowLayer addAnimation:group forKey:@"pp_order_bottom_glow_breath"];
    }
}

- (void)pp_stopLiveBackgroundGlows
{
    [self.backgroundTopGlowView.layer removeAnimationForKey:@"pp_order_top_glow_drift"];
    [self.backgroundBottomGlowView.layer removeAnimationForKey:@"pp_order_bottom_glow_drift"];
    [self.backgroundTopGlowLayer removeAnimationForKey:@"pp_order_top_glow_breath"];
    [self.backgroundBottomGlowLayer removeAnimationForKey:@"pp_order_bottom_glow_breath"];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.backgroundTopGlowLayer.transform = CATransform3DIdentity;
    self.backgroundBottomGlowLayer.transform = CATransform3DIdentity;
    self.backgroundTopGlowLayer.opacity = 0.72;
    self.backgroundBottomGlowLayer.opacity = 0.62;
    [CATransaction commit];
}

- (void)pp_updateLiveBackgroundGlowsForScrollOffset:(CGFloat)contentOffsetY
{
    if (!self.backgroundTopGlowLayer || !self.backgroundBottomGlowLayer) return;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        self.backgroundTopGlowLayer.transform = CATransform3DIdentity;
        self.backgroundBottomGlowLayer.transform = CATransform3DIdentity;
        [CATransaction commit];
        return;
    }

    CGFloat adjustedTopInset = 0.0;
    if (@available(iOS 11.0, *)) {
        adjustedTopInset = self.tableView.adjustedContentInset.top;
    } else {
        adjustedTopInset = self.tableView.contentInset.top;
    }
    CGFloat travel = MAX(0.0, contentOffsetY + adjustedTopInset);
    CGFloat pullDistance = MAX(0.0, -(contentOffsetY + adjustedTopInset));
    CGFloat pullProgress = MIN(1.0, pullDistance / 120.0);
    CGFloat wave = sin(travel * 0.008);

    CGAffineTransform topTransform = CGAffineTransformMakeTranslation(wave * 5.0,
                                                                      -MIN(24.0, travel * 0.055));
    topTransform = CGAffineTransformScale(topTransform,
                                          1.0 + (pullProgress * 0.055),
                                          1.0 + (pullProgress * 0.055));

    CGAffineTransform bottomTransform = CGAffineTransformMakeTranslation(-wave * 6.0,
                                                                         MIN(20.0, travel * 0.040));
    bottomTransform = CGAffineTransformScale(bottomTransform,
                                             1.0 + (pullProgress * 0.035),
                                             1.0 + (pullProgress * 0.035));

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.backgroundTopGlowLayer.transform = CATransform3DMakeAffineTransform(topTransform);
    self.backgroundBottomGlowLayer.transform = CATransform3DMakeAffineTransform(bottomTransform);
    [CATransaction commit];
}

#pragma mark - Setup

- (void)setupDefaults
{
    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
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
    self.didPreparePremiumEntrance = NO;
    self.didRunPremiumEntrance = NO;

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

    UIBarButtonItem *supportItem =  [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"headphones.dots"] style:UIBarButtonItemStylePlain target:self action:@selector(contactSupportTapped)];
    UIBarButtonItem *shareItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"square.and.arrow.up"] style:UIBarButtonItemStylePlain target:self action:@selector(shareOrderTapped)];
    self.navigationItem.rightBarButtonItems = @[shareItem, supportItem];
}

- (void)setupViews
{
    self.backgroundTopGlowView = [[UIView alloc] initWithFrame:CGRectZero];
    self.backgroundTopGlowView.userInteractionEnabled = NO;
    self.backgroundTopGlowView.backgroundColor = UIColor.clearColor;
    self.backgroundTopGlowView.alpha = kOrderDetailsTopGlowRestingAlpha;
    [self.view addSubview:self.backgroundTopGlowView];

    self.backgroundBottomGlowView = [[UIView alloc] initWithFrame:CGRectZero];
    self.backgroundBottomGlowView.userInteractionEnabled = NO;
    self.backgroundBottomGlowView.backgroundColor = UIColor.clearColor;
    self.backgroundBottomGlowView.alpha = kOrderDetailsBottomGlowRestingAlpha;
    [self.view addSubview:self.backgroundBottomGlowView];
    [self pp_installLiveBackgroundGlowLayersIfNeeded];

    UITableViewStyle tableStyle = UITableViewStylePlain;
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:tableStyle];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = AppClearClr;
    self.tableView.backgroundView = nil;
    self.tableView.opaque = NO;
    self.tableView.rowHeight = 104.0;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.sectionFooterHeight = 0.01;
    self.tableView.contentInset = UIEdgeInsetsMake(PPSpaceSM, 0.0, kOrderDetailsContentBottomInset, 0.0);
    self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
    if (@available(iOS 11.0, *)) {
        self.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    }
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0.0;
    }
    [self.tableView registerClass:[OrderItemCell class] forCellReuseIdentifier:kOrderDetailsItemCellID];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kOrderDetailsPlaceholderCellID];
    [self.view addSubview:self.tableView];
    [self.view sendSubviewToBack:self.backgroundBottomGlowView];
    [self.view sendSubviewToBack:self.backgroundTopGlowView];

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
    PPOrderDetailsApplySurface(self.headerCard, PPCornerHero, YES);
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
    PPApplyContinuousCorners(self.statusSummaryCard, 0);
    self.statusSummaryCard.layer.masksToBounds = NO;
    [self.headerCard addSubview:self.statusSummaryCard];

    PPBackgroundView *glass = [PPBackgroundView new];
    glass.translatesAutoresizingMaskIntoConstraints = NO;
    [self.statusSummaryCard insertSubview:glass atIndex:0];
    self.heroGlassBackground = glass;
    [NSLayoutConstraint activateConstraints:@[
        [glass.topAnchor constraintEqualToAnchor:self.statusSummaryCard.topAnchor],
        [glass.leadingAnchor constraintEqualToAnchor:self.statusSummaryCard.leadingAnchor],
        [glass.trailingAnchor constraintEqualToAnchor:self.statusSummaryCard.trailingAnchor],
        [glass.bottomAnchor constraintEqualToAnchor:self.statusSummaryCard.bottomAnchor]
    ]];

    self.ambientDotsContainerView = [[UIView alloc] initWithFrame:CGRectZero];
    self.ambientDotsContainerView.backgroundColor = UIColor.clearColor;
    self.ambientDotsContainerView.userInteractionEnabled = NO;
    self.ambientDotsContainerView.isAccessibilityElement = NO;
    self.ambientDotsContainerView.accessibilityElementsHidden = YES;
    self.ambientDotsContainerView.clipsToBounds = YES;
    [self.statusSummaryCard addSubview:self.ambientDotsContainerView];

    self.ambientDot1 = [[UIView alloc] initWithFrame:CGRectZero];
    self.ambientDot1.userInteractionEnabled = NO;
    self.ambientDot1.isAccessibilityElement = NO;
    [self.ambientDotsContainerView addSubview:self.ambientDot1];

    self.ambientDot2 = [[UIView alloc] initWithFrame:CGRectZero];
    self.ambientDot2.userInteractionEnabled = NO;
    self.ambientDot2.isAccessibilityElement = NO;
    [self.ambientDotsContainerView addSubview:self.ambientDot2];

    self.ambientDot3 = [[UIView alloc] initWithFrame:CGRectZero];
    self.ambientDot3.userInteractionEnabled = NO;
    self.ambientDot3.isAccessibilityElement = NO;
    [self.ambientDotsContainerView addSubview:self.ambientDot3];

    self.statusBadgeHaloView = [[UIView alloc] initWithFrame:CGRectZero];
    self.statusBadgeHaloView.userInteractionEnabled = NO;
    self.statusBadgeHaloView.layer.masksToBounds = NO;
    self.statusBadgeHaloView.hidden = YES;
    [self.statusSummaryCard addSubview:self.statusBadgeHaloView];

    self.statusBadge = [[UIView alloc] initWithFrame:CGRectZero];
    self.statusBadge.layer.masksToBounds = YES;
    [self.statusSummaryCard addSubview:self.statusBadge];

    self.statusBadgeGradientLayer = [CAGradientLayer layer];
    self.statusBadgeGradientLayer.name = @"PPOrderStatusBadgeGradient";
    [self.statusBadge.layer insertSublayer:self.statusBadgeGradientLayer atIndex:0];

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

    self.statusProgressChipGradientLayer = [CAGradientLayer layer];
    self.statusProgressChipGradientLayer.name = @"PPOrderStatusProgressGradient";
    [self.statusProgressChip.layer insertSublayer:self.statusProgressChipGradientLayer atIndex:0];

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

    self.statusEtaChipGradientLayer = [CAGradientLayer layer];
    self.statusEtaChipGradientLayer.name = @"PPOrderStatusETAGradient";
    [self.statusEtaChip.layer insertSublayer:self.statusEtaChipGradientLayer atIndex:0];

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
    PPApplyContinuousCorners(self.progressTimelineToggleButton, PPCornerMedium);
    self.progressTimelineToggleButton.layer.masksToBounds = YES;
    self.progressTimelineToggleButton.accessibilityLabel = kLang(@"order_tracking_toggle_accessibility_label");
    self.progressTimelineToggleButton.accessibilityHint = kLang(@"order_tracking_toggle_accessibility_hint");
    self.progressTimelineToggleButton.accessibilityTraits = UIAccessibilityTraitButton;
    [self.progressTimelineToggleButton addTarget:self action:@selector(toggleProgressTimelineTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.progressTimelineToggleButton addTarget:self action:@selector(pp_actionButtonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [self.progressTimelineToggleButton addTarget:self action:@selector(pp_actionButtonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
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
    PPApplyContinuousCorners(self.summaryPanel, PPCornerCard);
    self.summaryPanel.layer.masksToBounds = YES;
    self.summaryPanel.backgroundColor = PPOrderDetailsSubsurfaceColor();
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
    PPOrderDetailsApplySurface(self.deliveryMapCard, PPCornerCard, YES);
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
    [self.openMapButton addTarget:self action:@selector(pp_actionButtonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [self.openMapButton addTarget:self action:@selector(pp_actionButtonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [self.deliveryMapCard addSubview:self.openMapButton];

    self.deliveryMapView = [[MKMapView alloc] initWithFrame:CGRectZero];
    self.deliveryMapView.delegate = self;
    PPApplyContinuousCorners(self.deliveryMapView, PPCornerMedium);
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
    PPApplyContinuousCorners(button, kOrderDetailsButtonCornerRadius);
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
    [button addTarget:self action:@selector(pp_actionButtonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(pp_actionButtonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
     return button;
}

- (void)setupLoadingOverlay
{
    self.loadingOverlay = [[UIView alloc] initWithFrame:CGRectZero];
    self.loadingOverlay.hidden = YES;
    self.loadingOverlay.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.12];
    [self.view addSubview:self.loadingOverlay];

    self.loadingSurface = [[UIView alloc] initWithFrame:CGRectZero];
    PPOrderDetailsApplySurface(self.loadingSurface, PPCornerCard, YES);
    [self.loadingOverlay addSubview:self.loadingSurface];

    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.loadingIndicator.hidesWhenStopped = YES;
    self.loadingIndicator.color = [GM appPrimaryColor];
    [self.loadingSurface addSubview:self.loadingIndicator];

    self.loadingLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.loadingLabel.font = [GM MidFontWithSize:PPFontSubheadline];
    self.loadingLabel.textColor = UIColor.secondaryLabelColor;
    self.loadingLabel.text = kLang(@"Loading");
    self.loadingLabel.textAlignment = NSTextAlignmentCenter;
    [self.loadingSurface addSubview:self.loadingLabel];
}

- (void)layoutViews
{
    CGFloat width = CGRectGetWidth(self.view.bounds);
    CGFloat height = CGRectGetHeight(self.view.bounds);
    self.tableView.frame = self.view.bounds;
    [self pp_applyPremiumBottomContentInset];
    self.loadingOverlay.frame = self.view.bounds;
    CGFloat loadingWidth = 148.0;
    CGFloat loadingHeight = 118.0;
    self.loadingSurface.frame = CGRectMake((width - loadingWidth) * 0.5,
                                           (height - loadingHeight) * 0.5,
                                           loadingWidth,
                                           loadingHeight);
    self.loadingIndicator.frame = CGRectMake((loadingWidth - 36.0) * 0.5, 24.0, 36.0, 36.0);
    self.loadingLabel.frame = CGRectMake(PPSpaceMD, CGRectGetMaxY(self.loadingIndicator.frame) + PPSpaceSM,
                                         loadingWidth - (PPSpaceMD * 2.0), 22.0);
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
    CGFloat cardX = kOrderDetailsScreenMargin;
    CGFloat cardWidth = MAX(0.0, width - (kOrderDetailsScreenMargin * 2.0));
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

    CGFloat padding = PPSpaceLG;
    CGFloat separatorWidth = MAX(0.0, cardWidth - (padding * 2.0));
    CGFloat gap = 10.0;
    CGFloat headerY = PPSpaceLG;

    self.orderIDLabel.frame = CGRectMake(padding, headerY, separatorWidth, 18.0);

    CGFloat statusCardY = CGRectGetMaxY(self.orderIDLabel.frame) + 12.0;
    self.statusSummaryCard.frame = CGRectMake(padding, statusCardY, separatorWidth, 1.0);

    CGFloat statusCardInset = PPSpaceLG;
    CGFloat badgeSize = 48.0;
    CGFloat badgeX = isRTL ? statusCardInset : (separatorWidth - statusCardInset - badgeSize);
    self.statusBadge.frame = CGRectMake(badgeX, statusCardInset, badgeSize, badgeSize);
    self.statusBadge.layer.cornerRadius = badgeSize * 0.5;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.statusBadgeGradientLayer.frame = self.statusBadge.bounds;
    self.statusBadgeGradientLayer.cornerRadius = self.statusBadge.layer.cornerRadius;
    [CATransaction commit];
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
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.statusProgressChipGradientLayer.frame = self.statusProgressChip.bounds;
    self.statusProgressChipGradientLayer.cornerRadius = self.statusProgressChip.layer.cornerRadius;
    self.statusEtaChipGradientLayer.frame = self.statusEtaChip.bounds;
    self.statusEtaChipGradientLayer.cornerRadius = self.statusEtaChip.layer.cornerRadius;
    [CATransaction commit];

    CGFloat statusSummaryBottom = MAX(CGRectGetMaxY(self.statusProgressChip.frame), CGRectGetMaxY(self.statusEtaChip.frame));
    CGFloat statusSummaryHeight = statusSummaryBottom + statusCardInset;
    self.statusSummaryCard.frame = CGRectMake(padding, statusCardY, separatorWidth, statusSummaryHeight);
    [self pp_layoutAmbientHeroDotsForSize:self.statusSummaryCard.bounds.size isRTL:isRTL];

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
    CGFloat summaryPadding = PPSpaceLG;
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

    CGFloat finalCardHeight = CGRectGetMaxY(self.summaryPanel.frame) + PPSpaceLG;
    self.headerCard.frame = CGRectMake(cardX, PPSpaceSM, cardWidth, finalCardHeight);
    self.headerContainer.frame = CGRectMake(0, 0, width, finalCardHeight + PPSpaceBase);
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

    NSString *statusKey = self.order ? [self customerDisplayStatusKeyForOrder:self.order] : @"pending";
    UIColor *accent = PPOrderStatusResolvedColor([self statusAccentColorForStatusKey:statusKey], self.traitCollection);
    UIColor *shine = PPOrderStatusResolvedColor(PPOrderStatusShineColorForKey(statusKey), self.traitCollection);
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
    if (!self.headerCard) return;
    [self pp_installHeaderHeroLiquidBorderIfNeeded];
    [self pp_stopHeaderHeroLiquidBorder];
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

- (void)pp_layoutAmbientHeroDotsForSize:(CGSize)size isRTL:(BOOL)isRTL
{
    if (!self.ambientDotsContainerView || size.width <= 0.0 || size.height <= 0.0) return;

    BOOL layoutChanged = (fabs(size.width - self.ambientDotsLayoutSize.width) > 0.5 ||
                          fabs(size.height - self.ambientDotsLayoutSize.height) > 0.5 ||
                          self.ambientDotsLayoutRTL != isRTL);
    if (layoutChanged) {
        [self pp_stopAmbientHeroDotsMotion];
    }

    self.ambientDotsLayoutSize = size;
    self.ambientDotsLayoutRTL = isRTL;
    self.ambientDotsContainerView.frame = (CGRect){CGPointZero, size};

    CGFloat compactScale = size.width < 330.0 ? 0.88 : 1.0;
    NSArray<UIView *> *dots = @[self.ambientDot1, self.ambientDot2, self.ambientDot3];
    NSArray<NSNumber *> *diameters = @[@(11.0 * compactScale), @(7.0 * compactScale), @(5.0 * compactScale)];
    NSArray<NSValue *> *normalizedCenters = @[
        [NSValue valueWithCGPoint:CGPointMake(0.88, 0.18)],
        [NSValue valueWithCGPoint:CGPointMake(0.08, 0.72)],
        [NSValue valueWithCGPoint:CGPointMake(0.72, 0.88)]
    ];

    for (NSInteger index = 0; index < dots.count; index++) {
        UIView *dot = dots[index];
        CGFloat diameter = diameters[index].doubleValue;
        CGPoint normalizedCenter = normalizedCenters[index].CGPointValue;
        if (isRTL) {
            normalizedCenter.x = 1.0 - normalizedCenter.x;
        }
        dot.bounds = CGRectMake(0.0, 0.0, diameter, diameter);
        dot.center = CGPointMake(round(size.width * normalizedCenter.x),
                                 round(size.height * normalizedCenter.y));
        dot.layer.cornerRadius = diameter * 0.5;
        dot.layer.shadowOffset = CGSizeZero;
        dot.layer.shadowRadius = MAX(3.0, diameter * 0.7);
        dot.layer.shadowOpacity = 0.34;
    }

    if (layoutChanged && [self pp_shouldRunCurrentStatusSummaryMotion]) {
        [self pp_startAmbientHeroDotsMotionIfNeeded];
    }
}

- (void)pp_addAmbientHeroDotMotionToView:(UIView *)dot
                                     key:(NSString *)key
                                  offset:(CGVector)offset
                                minScale:(CGFloat)minScale
                                maxScale:(CGFloat)maxScale
                              minOpacity:(CGFloat)minOpacity
                              maxOpacity:(CGFloat)maxOpacity
                                duration:(CFTimeInterval)duration
                                   phase:(CFTimeInterval)phase
{
    if (!dot || key.length == 0 || [dot.layer animationForKey:key]) return;

    CGPoint origin = dot.layer.position;
    CAKeyframeAnimation *drift = [CAKeyframeAnimation animationWithKeyPath:@"position"];
    drift.values = @[
        [NSValue valueWithCGPoint:origin],
        [NSValue valueWithCGPoint:CGPointMake(origin.x + (offset.dx * 0.48), origin.y - offset.dy)],
        [NSValue valueWithCGPoint:CGPointMake(origin.x + offset.dx, origin.y + (offset.dy * 0.18))],
        [NSValue valueWithCGPoint:CGPointMake(origin.x - (offset.dx * 0.42), origin.y + (offset.dy * 0.72))],
        [NSValue valueWithCGPoint:origin]
    ];
    drift.keyTimes = @[@0.0, @0.24, @0.52, @0.78, @1.0];

    CAKeyframeAnimation *breathe = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
    breathe.values = @[@(minScale), @(1.0), @(maxScale), @(0.98), @(minScale)];
    breathe.keyTimes = drift.keyTimes;

    CAKeyframeAnimation *luminance = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    luminance.values = @[@(minOpacity), @(maxOpacity * 0.78), @(maxOpacity), @(minOpacity * 1.16), @(minOpacity)];
    luminance.keyTimes = drift.keyTimes;

    CAAnimationGroup *motion = [CAAnimationGroup animation];
    motion.animations = @[drift, breathe, luminance];
    motion.duration = duration;
    motion.repeatCount = HUGE_VALF;
    motion.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    CFTimeInterval localNow = [dot.layer convertTime:CACurrentMediaTime() fromLayer:nil];
    motion.beginTime = localNow - fmod(MAX(0.0, phase), duration);
    [dot.layer addAnimation:motion forKey:key];
}

- (void)pp_startAmbientHeroDotsMotionIfNeeded
{
    if (![self pp_shouldRunCurrentStatusSummaryMotion] || CGRectIsEmpty(self.ambientDotsContainerView.bounds)) {
        [self pp_stopAmbientHeroDotsMotion];
        return;
    }

    CGFloat direction = self.ambientDotsLayoutRTL ? -1.0 : 1.0;
    [self pp_addAmbientHeroDotMotionToView:self.ambientDot1
                                      key:PPOrderSummaryAmbientDot1MotionKey
                                   offset:CGVectorMake(5.0 * direction, 4.0)
                                 minScale:0.92
                                 maxScale:1.16
                               minOpacity:0.18
                               maxOpacity:0.44
                                 duration:4.8
                                    phase:0.9];
    [self pp_addAmbientHeroDotMotionToView:self.ambientDot2
                                      key:PPOrderSummaryAmbientDot2MotionKey
                                   offset:CGVectorMake(4.0 * direction, 5.0)
                                 minScale:0.90
                                 maxScale:1.22
                               minOpacity:0.14
                               maxOpacity:0.36
                                 duration:5.6
                                    phase:2.1];
    [self pp_addAmbientHeroDotMotionToView:self.ambientDot3
                                      key:PPOrderSummaryAmbientDot3MotionKey
                                   offset:CGVectorMake(6.0 * direction, 3.0)
                                 minScale:0.94
                                 maxScale:1.28
                               minOpacity:0.20
                               maxOpacity:0.52
                                 duration:4.2
                                    phase:1.4];
}

- (void)pp_stopAmbientHeroDotsMotion
{
    [self.ambientDot1.layer removeAnimationForKey:PPOrderSummaryAmbientDot1MotionKey];
    [self.ambientDot2.layer removeAnimationForKey:PPOrderSummaryAmbientDot2MotionKey];
    [self.ambientDot3.layer removeAnimationForKey:PPOrderSummaryAmbientDot3MotionKey];
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
    UIColor *resolvedAccent = PPOrderStatusResolvedColor(accent, self.traitCollection);
    UIColor *glow = PPOrderStatusGlowColorForKey(statusKey, self.traitCollection);
    BOOL failure = [self isFailureStatusKey:statusKey];

    self.statusBadgeHaloView.backgroundColor = glow;
    self.statusBadgeHaloView.layer.borderWidth = 1.0;
    [self.statusBadgeHaloView pp_setBorderColor:[resolvedAccent colorWithAlphaComponent:failure ? 0.34 : 0.28]];
    self.statusBadgeHaloView.layer.shadowColor = resolvedAccent.CGColor;
    self.statusBadgeHaloView.layer.shadowOpacity = failure ? 0.12 : 0.14;
    self.statusBadgeHaloView.layer.shadowRadius = 12.0;
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

    [self pp_addSummaryScalePulseToLayer:self.statusBadgeHaloView.layer
                                     key:PPOrderSummaryStatusHaloScaleKey
                               fromScale:0.99
                                 toScale:1.08
                                duration:3.2
                              beginDelay:0.0];
    [self pp_addSummaryOpacityPulseToLayer:self.statusBadgeHaloView.layer
                                       key:PPOrderSummaryStatusHaloOpacityKey
                                      from:0.24
                                        to:0.48
                                  duration:3.2
                                beginDelay:0.0];

    [self pp_startAmbientHeroDotsMotionIfNeeded];
}

- (void)pp_stopCurrentStatusSummaryMotion
{
    [self pp_stopAmbientHeroDotsMotion];

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

    self.statusSummaryCard.alpha = 0.88;
    self.statusSummaryCard.transform = CGAffineTransformMakeScale(0.985, 0.985);
    [UIView animateWithDuration:0.24
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionAllowUserInteraction |
                                UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.statusSummaryCard.alpha = 1.0;
        self.statusSummaryCard.transform = CGAffineTransformIdentity;
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
    CGFloat contentX = kOrderDetailsScreenMargin;
    CGFloat contentWidth = MAX(0.0, width - (kOrderDetailsScreenMargin * 2.0));
    CGFloat mapHeight = (width < 360.0) ? 158.0 : 176.0;
    CGFloat mapCardPadding = 16.0;
    CGFloat mapHeaderY = 16.0;
    CGFloat topButtonSize = 46.0;
    BOOL isRTL = [Language isRTL];

    CGFloat nextSectionY = PPSpaceMD;
    if (self.fulfillmentSectionCard && !self.fulfillmentSectionCard.hidden) {
        CGRect fulfillmentFrame = self.fulfillmentSectionCard.frame;
        fulfillmentFrame.origin.x = contentX;
        fulfillmentFrame.origin.y = nextSectionY;
        fulfillmentFrame.size.width = contentWidth;
        self.fulfillmentSectionCard.frame = fulfillmentFrame;
        nextSectionY = CGRectGetMaxY(fulfillmentFrame) + kOrderDetailsSectionSpacing;
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
                                               CGRectGetMaxY(self.deliveryMapCard.frame) + kOrderDetailsSectionSpacing,
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
    NSString *statusKey = self.order ? [self customerDisplayStatusKeyForOrder:self.order] : @"pending";
    UIColor *accent = [self statusAccentColorForStatusKey:statusKey];
    UIColor *resolvedAccent = PPOrderStatusResolvedColor(accent, self.traitCollection);
    UIColor *surface = PPOrderStatusSurfaceColorForAccent(accent, self.traitCollection);
    UIColor *strongSurface = PPOrderStatusStrongSurfaceColorForAccent(accent, self.traitCollection);
    UIColor *border = PPOrderStatusBorderColorForAccent(accent, self.traitCollection);
    self.heroGlassBackground.accentStyle = PPHeroGlassAccentStyleCornerGlow;
    self.heroGlassBackground.accentColorOverride = accent;
    self.headerCard.backgroundColor = PPOrderDetailsSurfaceColor();
    self.deliveryMapCard.backgroundColor = PPOrderDetailsSurfaceColor();
    self.statusSummaryCard.backgroundColor = AppClearClr; //PPOrderDetailsSubsurfaceColor();
    
    self.ambientDot1.backgroundColor = resolvedAccent;
    self.ambientDot2.backgroundColor = resolvedAccent;
    self.ambientDot3.backgroundColor = resolvedAccent;
    self.ambientDot1.layer.opacity = 0.10;
    self.ambientDot2.layer.opacity = 0.07;
    self.ambientDot3.layer.opacity = 0.12;
    self.ambientDot1.layer.shadowColor = resolvedAccent.CGColor;
    self.ambientDot2.layer.shadowColor = resolvedAccent.CGColor;
    self.ambientDot3.layer.shadowColor = resolvedAccent.CGColor;
    
    self.statusSummaryCard.layer.borderWidth = 0.0;
    [self.statusSummaryCard pp_setBorderColor:[accent colorWithAlphaComponent:0.0]];
    
    self.summaryPanel.backgroundColor = PPOrderDetailsSurfaceColor();
    self.statusBadge.backgroundColor = strongSurface;
    self.statusBadge.layer.borderWidth = 1.0;
    self.statusBadge.layer.borderColor = border.CGColor;
    self.statusProgressChip.backgroundColor = surface;
    self.statusProgressChip.layer.borderWidth = 1.0;
    self.statusProgressChip.layer.borderColor = border.CGColor;
    self.statusEtaChip.backgroundColor = surface;
    self.statusEtaChip.layer.borderWidth = 1.0;
    self.statusEtaChip.layer.borderColor = border.CGColor;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    PPOrderStatusConfigureGradientLayer(self.statusBadgeGradientLayer,
                                        statusKey,
                                        accent,
                                        self.traitCollection,
                                        [Language isRTL]);
    PPOrderStatusConfigureGradientLayer(self.statusProgressChipGradientLayer,
                                        statusKey,
                                        accent,
                                        self.traitCollection,
                                        [Language isRTL]);
    PPOrderStatusConfigureGradientLayer(self.statusEtaChipGradientLayer,
                                        statusKey,
                                        accent,
                                        self.traitCollection,
                                        [Language isRTL]);
    [CATransaction commit];
    self.statusProgressChipIconView.tintColor = accent;
    self.statusEtaChipIconView.tintColor = accent;
    self.statusProgressChipLabel.textColor = UIColor.labelColor;
    self.statusEtaChipLabel.textColor = UIColor.labelColor;
    self.progressTimelineTitleLabel.textColor = UIColor.labelColor;
    self.progressTimelineProgressLabel.textColor = accent;
    self.progressTimelineToggleButton.backgroundColor = surface;
    self.progressTimelineToggleButton.tintColor = accent;
    self.progressTimelineToggleButton.layer.borderWidth = 1.0;
    [self.progressTimelineToggleButton pp_setBorderColor:border];
    self.progressTimelineToggleIconView.tintColor = accent;
    [self pp_refreshLiveBackgroundGlowColors];
    [self pp_refreshHeaderHeroLiquidBorderColors];
    self.openMapButton.backgroundColor = surface;
    self.openMapButton.tintColor = accent;
    [self.openMapButton pp_setBorderColor:border];
    [self.deliveryMapView pp_setBorderColor:[border colorWithAlphaComponent:0.72]];
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
    UIColor *surfaceBackground = PPOrderDetailsSurfaceColor();
    UIColor *surfaceBorder = [[UIColor labelColor] colorWithAlphaComponent:0.055];
    UIColor *primaryTint = [GM appPrimaryColor];

    [self applyVisualStyleToActionButton:self.trackOrderButton
                               tintColor:UIColor.whiteColor
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

- (void)pp_actionButtonTouchDown:(UIButton *)sender
{
    if (!sender.enabled) return;
    [UIView animateWithDuration:0.09
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        sender.transform = CGAffineTransformMakeScale(PPTapCardScaleDown, PPTapCardScaleDown);
        sender.alpha = 0.88;
    } completion:nil];
}

- (void)pp_actionButtonTouchUp:(UIButton *)sender
{
    [UIView animateWithDuration:0.18
                          delay:0.0
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.40
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        sender.transform = CGAffineTransformIdentity;
        sender.alpha = sender.enabled ? 1.0 : 0.72;
    } completion:nil];
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
    return PPOrderStatusAccentColorForKey(statusKey);
}

- (UIColor *)statusBadgeColorForStatusKey:(NSString *)statusKey
{
    return PPOrderStatusStrongSurfaceColorForAccent([self statusAccentColorForStatusKey:statusKey],
                                                     self.traitCollection);
}

- (NSString *)statusIconNameForStatusKey:(NSString *)statusKey
{
    return PPOrderStatusSymbolNameForKey(statusKey);
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
    self.progressTimelineToggleButton.accessibilityValue = self.isProgressTimelineExpanded
    ? kLang(@"order_tracking_toggle_expanded")
    : kLang(@"order_tracking_toggle_collapsed");

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
        [stepKeys addObject:@"pending"];
        [stepKeys addObject:statusKey.length > 0 ? statusKey : @"delivery_delayed"];
    } else {
        [stepKeys addObjectsFromArray:@[
            @"pending",
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
            @"icon": iconName ?: @"circle",
            @"tint": PPOrderStatusAccentColorForKey(resolvedKey)
        }];
        (void)stop;
    }];
    return descriptors.copy;
}

- (NSInteger)progressTimelineIndexForStatusKey:(NSString *)statusKey
{
    if ([statusKey isEqualToString:@"completed"]) return 6;
    if ([statusKey isEqualToString:@"delivered"]) return 5;
    if ([statusKey isEqualToString:@"on_the_way"]) return 4;
    if ([statusKey isEqualToString:@"delivery_partner_assigned"]) return 3;
    if ([statusKey isEqualToString:@"ready_for_delivery"]) return 2;
    if ([statusKey isEqualToString:@"preparing_for_shipment"]) return 1;
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
    if ([normalized isEqualToString:@"pending"]) {
        return order.createdAt;
    }
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
        CGFloat placeholderAlpha = UIAccessibilityIsReduceTransparencyEnabled() ? 1.0 : (PPIOS26() ? 0.72 : 0.94);
        cell.contentView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:placeholderAlpha];
        cell.contentView.opaque = NO;
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
    cell.accessibilityLabel = [NSString stringWithFormat:@"%@, %@, %@",
                               cell.nameLabel.text ?: @"",
                               cell.quantityLabel.text ?: @"",
                               cell.priceLabel.text ?: @""];
    cell.accessibilityHint = canOpenAccessoryViewer ? kLang(@"order_item_accessibility_hint") : nil;

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

    CGFloat horizontalInset = kOrderDetailsScreenMargin;
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
    countLabel.backgroundColor = [accent colorWithAlphaComponent:0.10];
    PPApplyContinuousCorners(countLabel, PPCornerPill);
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

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView != self.tableView || !self.isOrderDetailsScreenVisible) return;
    [self pp_updateLiveBackgroundGlowsForScrollOffset:scrollView.contentOffset.y];
}

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
    NSLog(@"[PP_CANCEL_FLOW] cancelOrderTapped. orderId=%@, rawStatus=%@, isEligible=%d, message=%@", self.order.orderId, self.order.rawStatus, decision.isEligible, decision.message);
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
        NSLog(@"[PP_CANCEL_FLOW] performCancelOrder aborted: missing order ID.");
        [self showErrorMessage:kLang(@"order_missing_id")];
        return;
    }

    [self startLoading];

    NSString *statusKey = [self normalizedStatusKeyForOrder:self.order];
    BOOL shouldCancelPendingCheckout =
        ![self.order isCashOnDelivery] &&
        ![self.order hasCapturedPayment] &&
        ([statusKey isEqualToString:@"pending"] || [statusKey isEqualToString:@"failed"]);

    NSLog(@"[PP_CANCEL_FLOW] performCancelOrder. orderId=%@, isCashOnDelivery=%d, hasCapturedPayment=%d, statusKey=%@, shouldCancelPendingCheckout=%d", self.order.orderId, [self.order isCashOnDelivery], [self.order hasCapturedPayment], statusKey, shouldCancelPendingCheckout);

    if (shouldCancelPendingCheckout) {
        __weak typeof(self) weakSelf = self;
        NSLog(@"[PP_CANCEL_FLOW] Routing to cancelPendingCheckoutOrder");
        [self.orderManager cancelPendingCheckoutOrder:self.order
                                           completion:^(BOOL success, BOOL alreadyCancelled, NSError * _Nullable error) {
            NSLog(@"[PP_CANCEL_FLOW] cancelPendingCheckoutOrder completed. success=%d, alreadyCancelled=%d, error=%@", success, alreadyCancelled, error);
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                [strongSelf stopLoading];
                if (!success || error) {
                    [strongSelf showErrorMessage:error.localizedDescription ?: kLang(@"order_cancel_checkout_failed")];
                    return;
                }

                [strongSelf showSuccessMessage:alreadyCancelled
                    ? kLang(@"order_action_cancel_unavailable_closed")
                    : kLang(@"OrderCanceled")];
            });
        }];
        return;
    }

    PPOrderSupportDraft *draft = [PPOrderSupportDraft new];
    draft.actionType = PPOrderCustomerActionTypeCancel;
    draft.reasonCode = @"cancelled_by_user";
    draft.reasonTitle = kLang(@"order_cancel_button");

    __weak typeof(self) weakSelf = self;
    NSLog(@"[PP_CANCEL_FLOW] Routing to submitSupportDraft");
    [self.orderManager submitSupportDraft:draft
                                 forOrder:self.order
                               completion:^(PPOrderSupportRequest * _Nullable request, BOOL deduplicated, NSError * _Nullable error) {
        NSLog(@"[PP_CANCEL_FLOW] submitSupportDraft completed. requestID=%@, deduplicated=%d, error=%@", request.requestId, deduplicated, error);
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
    button.enabled = visible && eligible;
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
    [self pp_stopCurrentStatusSummaryMotion];
    [self pp_stopCheckoutSuccessConfetti];
    //[self.heroGlassBackground stopAnimations];
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
    PPOrderDetailsApplySurface(card, PPCornerCard, NO);
    card.layer.masksToBounds = YES;
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
    group.backgroundColor = PPOrderDetailsSubsurfaceColor();
    group.opaque = NO;
    PPApplyContinuousCorners(group, PPCornerMedium);
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
    statusBadge.backgroundColor = PPOrderStatusSurfaceColorForAccent(sc, self.traitCollection);
    statusBadge.layer.cornerRadius = PPCornerSmall / 2.0;
    statusBadge.layer.borderWidth = 1.0;
    statusBadge.layer.borderColor = PPOrderStatusBorderColorForAccent(sc, self.traitCollection).CGColor;
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
            @"delivery_assigned":  kLang(@"fulfillment_status_delivery_assigned"),
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
    return PPOrderStatusAccentColorForKey(status);
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self updateStatusStyle];
            [self updateStatusStepperAnimated:NO];
            [self configureFulfillmentSection];
            [self pp_refreshLiveBackgroundGlowColors];
            if (self.isOrderDetailsScreenVisible) {
                [self pp_startLiveBackgroundGlowsIfNeeded];
            }
        }
    }
    //[self.heroGlassBackground stopAnimations];
    //[self.heroGlassBackground reapplyPalette];
   // [self.heroGlassBackground startAnimations];
}

@end
