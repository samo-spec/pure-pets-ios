//
//  ViewerVC.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/05/2025.
//

#import "XLFormViewController.h"
 
#import "PetImageGalleryView.h"
#import "UserContactView.h"



NS_ASSUME_NONNULL_BEGIN

@interface ViewerVC : UIViewController
@property (nonatomic, strong) PetAd *ad;


@end

NS_ASSUME_NONNULL_END

/*
 
 section = [XLFormSectionDescriptor formSection];
 [self.mform addFormSection:section];
 
 row = [XLFormRowDescriptor formRowDescriptorWithTag:@"catRow" rowType:XLFormRowDescriptorTypeText title:catRowPlace];
 [row.cellConfig setObject:GM.SecondaryTextColor forKey:@"textLabel.textColor"];
 row.value = [MainKindsModel kindNameForID:self.ad.category inArray:MKM.MainKindsArray];
 row.height = 50.0;
 [section addFormRow:row];
 
 row = [XLFormRowDescriptor formRowDescriptorWithTag:@"subCatRow" rowType:XLFormRowDescriptorTypeText title:subCatPlace];
 row.value = [SubKindModel getSubKindName:self.ad.subcategory subKindsArrayLocal:[MKM getSubKindArray:self.ad.category]];
 [row.cellConfig setObject:GM.SecondaryTextColor forKey:@"textLabel.textColor"];
 row.height = 50.0;
 [section addFormRow:row];
 
 */
