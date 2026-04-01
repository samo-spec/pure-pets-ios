//
//  AdoptPetDetailsViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 13/08/2025.
//


#import <UIKit/UIKit.h>
@class AdoptPetModel;

@interface AdoptPetDetailsViewController : UIViewController
- (instancetype)initWithModel:(AdoptPetModel *)model;
- (instancetype)initWithModel:(AdoptPetModel *)model isOwner:(BOOL)isOwner;
@end
