//
//  ViewerVC.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/05/2025.
//

#import <UIKit/UIKit.h>
 
NS_ASSUME_NONNULL_BEGIN

@class PetAccessory;

@protocol CartQuantityFromViewerDelegate <NSObject>
-(void)updateCartAndReloadCollection;
@end

@interface AccessViewerVC : UIViewController
@property (nonatomic, strong) PetAccessory *accessAds;
@property (nonatomic, strong) UIViewController *ParentVC;
@property (nonatomic, weak) id <CartQuantityFromViewerDelegate> QtyDelegate;

@end

NS_ASSUME_NONNULL_END
