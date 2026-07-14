//
//  PPOrderSupportRequestListViewController 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 7/14/26.
//

#import "PPOrderSupportRequestListViewController.h"
#import "PPOrder.h"
#import "PPOrderManager.h"
#import "OrderSupportFunc.h"
#import "PPOrderSupportRequestDetailsViewController.h"
#import "OrderSupportFunc.h"

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
    self.tableView.backgroundColor = AppClearClr;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 78.0;
    self.tableView.sectionHeaderHeight = PPSpaceSM;
    self.tableView.sectionFooterHeight = PPSpaceSM;
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
        cell.backgroundColor = UIColor.clearColor;
        cell.contentView.backgroundColor = PPOrderDetailsSurfaceColor();
        PPApplyContinuousCorners(cell.contentView, PPCornerMedium);
        cell.contentView.layer.borderWidth = 1.0;
        [cell.contentView pp_setBorderColor:[[UIColor labelColor] colorWithAlphaComponent:0.055]];
        cell.layoutMargins = UIEdgeInsetsMake(PPSpaceMD, PPSpaceLG, PPSpaceMD, PPSpaceLG);
        cell.separatorInset = UIEdgeInsetsMake(0, CGFLOAT_MAX, 0, 0);
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
