//
//  AppSearchResultsVC.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 12/08/2025.
//
//
//  AppSearchResultsVC.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 12/08/2025.
//

#import "AppSearchResultsVC.h"
#import "SearchResultCell.h"
#import "SearchResultItem.h"
#import "PPEmptyStateHelper.h"
static NSString * const kCellID = @"SearchResultCellID";

static inline NSString *SRTypeToString(SearchResultType t) {
    switch (t) {
        case SearchResultTypePetAd:     return @"PetAd";
        case SearchResultTypeAccessory: return @"Accessory";
        case SearchResultTypeFood:      return @"Food";
        case SearchResultTypeService:   return @"Service";
        case SearchResultTypeVet:       return @"Vet";
        default:                        return @"Unknown";
    }
}


@interface AppSearchResultsVC ()

@end

@implementation AppSearchResultsVC

// AppSearchResultsVC.m
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = PPBackgroundColorForIOS26(GM.backOffwhileColor);

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.tableView registerClass:SearchResultCell.class forCellReuseIdentifier:kCellID];
    self.tableView.rowHeight = 90;
    self.tableView.estimatedRowHeight = 90;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;

    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = GM.backOffwhileColor; // optional, to let card shadows sit on parent bg
    
    [self.view addSubview:self.tableView];
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:0],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor  constant:15],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:0],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:0],
    ]];
}

- (void)setResults:(NSArray<SearchResultItem *> *)results {
    _results = results;
    
    
    [self.tableView reloadData];
    [self updateEmptyState];
}

- (void)updateEmptyState {
  
    PPEmptyStateConfig *cfg = [PPEmptyStateConfig new];
    cfg.animationName = @"Emptyred.json";
    cfg.title      = kLang(@"SearchNoResultsGeneric");
    cfg.subTitle  = @"";
    cfg.buttonTitle  = kLang(@"SearchNoResultsCTA");
    cfg.target       = self;
    //cfg.action       = @selector(retrySegment);
    cfg.isNetworkFile = YES;

    [PPEmptyStateHelper updateEmptyStateForListView:self.tableView
                                          dataCount:self.results.count
                                             config:cfg];
}


/*
 
 */


- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    NSLog(@"[SearchResults] didAppear view=%@ frame=%@ table.frame=%@",
          self.view, NSStringFromCGRect(self.view.frame), NSStringFromCGRect(self.tableView.frame));
    
    
}



- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSUInteger count = self.results.count;
    NSLog(@"[SearchResults] numberOfRowsInSection:%ld -> %lu",
          (long)section, (unsigned long)count);
    return count;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{

    SearchResultCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellID forIndexPath:indexPath];

    if (indexPath.row < self.results.count) {
        SearchResultItem *item = self.results[indexPath.row];
        [cell configureWithItem:item];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

        NSLog(@"[SearchResults] cellForRow:%ld type=%@ title=\"%@\" subtitleLen=%lu",
              (long)indexPath.row,
              SRTypeToString(item.type),
              item.titleText ?: @"",
              (unsigned long)(item.subtitleText.length));
    } else {
        NSLog(@"[SearchResults][WARN] cellForRow:%ld requested beyond results bounds (%lu)",
              (long)indexPath.row, (unsigned long)self.results.count);
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tableView deselectRowAtIndexPath:ip animated:YES];

    BOOL hasCallback = (self.didSelectItem != nil);
    if (ip.row < self.results.count) {
        SearchResultItem *item = self.results[ip.row];
        NSLog(@"[SearchResults] didSelect row=%ld type=%@ title=\"%@\" hasCallback=%@",
              (long)ip.row,
              SRTypeToString(item.type),
              item.titleText ?: @"",
              hasCallback ? @"YES" : @"NO");

        if (self.didSelectItem) self.didSelectItem(item);
    } else {
        NSLog(@"[SearchResults][WARN] didSelect row=%ld out of range (count=%lu)",
              (long)ip.row, (unsigned long)self.results.count);
    }
}

- (void)dealloc {
    NSLog(@"[SearchResults] dealloc");
}


- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"[SearchResults] willDisplay row=%ld", (long)indexPath.row);
}

@end
