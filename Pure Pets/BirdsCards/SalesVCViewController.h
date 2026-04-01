//
//  SalesVCViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 18/03/2025.
//

#import <UIKit/UIKit.h>
#import "BuyerCell.h"
#import "viewDataVC.h"

NS_ASSUME_NONNULL_BEGIN

@interface SalesVCViewController : UIViewController<UICollectionViewDelegate,UICollectionViewDataSource>
@property (strong, nonatomic) UICollectionView *collectionView;
@property (strong, nonatomic) UISearchBar *searchBar;
@property (strong, nonatomic) UIView *topView;
@property (strong, nonatomic) UILabel *titleLabel;
@property (strong, nonatomic) UIButton *dissmissButton;

@end

NS_ASSUME_NONNULL_END
