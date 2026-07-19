//
//  AddVetViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 15/07/2025.
//


#import "VetModel.h"

@interface AddVetViewController : XLFormViewController
@property (nonatomic, strong) UIImageView *logoImageView;
@property (nonatomic, strong) UIImage *selectedLogo;
@property (nonatomic, strong) VetModel *vetToEdit;
@property (nonatomic, assign) NSInteger MainKindID;
@end
