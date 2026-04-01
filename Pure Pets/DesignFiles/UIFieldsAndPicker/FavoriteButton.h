//
//  FavoriteButton.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/05/2025.
//


// FavoriteButton.h
#import <UIKit/UIKit.h>
@interface FavoriteFixedSizeButton : UIButton

@property (nonatomic, strong) UIViewController *ParentVC;
- (void)initValue;
@property (nonatomic, strong) NSString *adID;
@property (nonatomic, assign) BOOL isFavorite;
- (void)animateFavButtonGlow:(UIButton *)button;
@property (strong, nonatomic) NSString *collection;
@end



@interface FavoriteFloatingButton : UIButton

@property (nonatomic, strong) UIViewController *ParentVC;
- (void)initValue;
@property (nonatomic, strong) NSString *adID;
@property (nonatomic, assign) BOOL isFavorite;
- (void)toggleFavorite;
@property (strong, nonatomic) NSString *collection;
@end




@interface FavoriteButton : UIButton

@property (nonatomic, strong) UIViewController *ParentVC;

@property (nonatomic, strong) NSString *adID;
@property (nonatomic, assign) BOOL isFavorite;
- (void)favButtonTapped;
- (void)initValue;
- (void)refreshAppearance;
-(void)colosTintForViewer;
-(void)colosTint;
-(void)whiteColosTintForViewer;


-(void)colosTintForAds;
@property (strong, nonatomic) NSString *collection;
@end
