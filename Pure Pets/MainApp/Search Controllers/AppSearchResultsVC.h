//
//  AppSearchResultsVC.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 12/08/2025.
//
#import "SearchResultItem.h"
// AppSearchResultsVC.h
@interface AppSearchResultsVC : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) NSArray<SearchResultItem *> *results;
@property (nonatomic, copy) void (^didSelectItem)(SearchResultItem *item);
@property (nonatomic, strong) UITableView *tableView;
@end
