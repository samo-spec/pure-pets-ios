//
//  AddAdoptPetViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 13/08/2025.
//

#import <UIKit/UIKit.h>
#import "AdoptPetModel.h"

NS_ASSUME_NONNULL_BEGIN
@interface AddAdoptPetViewController : UIViewController
@property (nonatomic, strong, nullable) AdoptPetModel *editingPet;
- (instancetype)initWithPet:(nullable AdoptPetModel *)pet;

@end

NS_ASSUME_NONNULL_END
