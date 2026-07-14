//
//  PPOrderTimelineViewController 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 7/14/26.
//


#import "PPOrderTimelineViewController.h"

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
    self.view.backgroundColor = AppBackgroundClrLigter;
    self.title = kLang(@"order_tracking_title");
    [self pp_orderApplyChevronBackButton];
    self.dateFormatter = [NSDateFormatter new];
    self.dateFormatter.locale = [NSLocale currentLocale];
    [self.dateFormatter setLocalizedDateFormatFromTemplate:@"EEE d MMM h:mm a"];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = AppClearClr;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 76.0;
    self.tableView.sectionHeaderHeight = PPSpaceSM;
    self.tableView.sectionFooterHeight = PPSpaceSM;
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
        cell.backgroundColor = UIColor.clearColor;
        cell.contentView.backgroundColor = PPOrderDetailsSurfaceColor();
        PPApplyContinuousCorners(cell.contentView, PPCornerMedium);
        cell.contentView.layer.borderWidth = 1.0;
        [cell.contentView pp_setBorderColor:[[UIColor labelColor] colorWithAlphaComponent:0.055]];
        cell.layoutMargins = UIEdgeInsetsMake(PPSpaceMD, PPSpaceLG, PPSpaceMD, PPSpaceLG);
        cell.separatorInset = UIEdgeInsetsMake(0, CGFLOAT_MAX, 0, 0);
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
