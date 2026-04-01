//
//  PPCompleteProfileVC.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 18/11/2025.
//




#import "TOCropViewController.h"
#import <TOCropViewController/TOCropViewController.h>
#import <PhotosUI/PhotosUI.h>

//
//  PPCompleteProfileVC.h
//  Pure Pets
//

 #import <UIKit/UIKit.h>
@class UserModel;

@interface PPCompleteProfileVC : XLFormViewController
<
    UIImagePickerControllerDelegate,
    UINavigationControllerDelegate,
    PHPickerViewControllerDelegate,
    TOCropViewControllerDelegate
>

@property (nonatomic, strong) UserModel *editingUser;
@property (nonatomic, strong) CountryCodeModel *selectedCountry;
@property (nonatomic, strong) NSMutableArray<CountryCodeModel *> *contriesArray;

/// Called once user finishes profile
@property (nonatomic, copy) void (^onProfileCompleted)(UserModel *);

/// Designated initializer
- (instancetype)initWithUser:(UserModel *)user;

@end


 
@interface PPCameraPreviewController : UIViewController
@property (nonatomic, copy) void (^onCapture)(UIImage *capturedImage);
@end
