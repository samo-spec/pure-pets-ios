//
//  PPEmptyStateConfig.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 13/08/2025.
//


// PPEmptyStateHelper.h
#import <UIKit/UIKit.h>

@class EmptyStateView;

@interface PPEmptyStateConfig : NSObject
@property (nonatomic, copy) NSString *animationName;   // e.g. @"Emptyred.json"
@property (nonatomic, copy) NSString *title;         // e.g. kLang(@"nodata")
@property (nonatomic, copy) NSString *subTitle;         // e.g. kLang(@"nodata")
@property (nonatomic, copy) NSString *buttonTitle;     // e.g. kLang(@"tryanotherfilter")
@property (nonatomic, weak) id target;                 // button target (can be nil)
@property (nonatomic) SEL action;                      // selector (can be NULL)
@property (nonatomic, assign) BOOL isNetworkFile;      // Lottie from network?
@end

@interface PPEmptyStateHelper : NSObject
/// Works for UITableView or UICollectionView (or any view).
+ (void)updateEmptyStateForListView:(UICollectionView *)listView
                          dataCount:(NSInteger)count
                             config:(PPEmptyStateConfig *)config;

/// Force-remove the empty state (if any).
+ (void)removeEmptyStateFromListView:(UIView *)listView;
@end
