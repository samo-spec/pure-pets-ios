//
//  SearchResultCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 12/08/2025.
//


// SearchResultCell.h
#import <UIKit/UIKit.h>
@class SearchResultItem;

@interface SearchResultCell : UITableViewCell
- (void)configureWithItem:(SearchResultItem *)item;
@end
