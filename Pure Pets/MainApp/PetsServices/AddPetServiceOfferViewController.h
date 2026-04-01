//
//  AddPetServiceOfferViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 14/07/2025.
//


@class ServiceModel;
@interface AddPetServiceOfferViewController : XLFormViewController
@property (nonatomic, strong) ServiceModel *serviceToEdit;
@property (nonatomic, assign) NSInteger MainKindID;
@property (nonatomic, copy) void (^onAddedBlock)(ServiceModel *addedService);

@end
