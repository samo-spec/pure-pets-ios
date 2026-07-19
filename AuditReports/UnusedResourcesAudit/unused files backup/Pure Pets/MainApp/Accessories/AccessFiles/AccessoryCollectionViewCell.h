//
//  AccessoryCollectionViewCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/06/2025.
//


#import <UIKit/UIKit.h>
@class PetAccessory;

@interface AccessoryCollectionViewCell : UICollectionViewCell

- (void)configureWithAccessory:(PetAccessory *)accessory;
@property (nonatomic, strong) UIViewController *ParentVC;
@end
