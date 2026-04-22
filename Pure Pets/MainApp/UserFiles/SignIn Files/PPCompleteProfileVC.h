//
//  PPCompleteProfileVC.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 18/11/2025.
//

#import <UIKit/UIKit.h>
#import <PhotosUI/PhotosUI.h>
#import <TOCropViewController/TOCropViewController.h>

@class CountryCodeModel;
@class UserModel;

@interface PPCompleteProfileVC : UIViewController
<
    UIImagePickerControllerDelegate,
    UINavigationControllerDelegate,
    PHPickerViewControllerDelegate,
    TOCropViewControllerDelegate
>

@property (nonatomic, strong) UserModel *editingUser;
@property (nonatomic, strong) CountryCodeModel *selectedCountry;
@property (nonatomic, strong) NSMutableArray<CountryCodeModel *> *contriesArray;

/// Called once user finishes profile.
@property (nonatomic, copy) void (^onProfileCompleted)(UserModel *);

/// Designated initializer.
- (instancetype)initWithUser:(UserModel *)user;

@end

@interface PPCameraPreviewController : UIViewController
@property (nonatomic, copy) void (^onCapture)(UIImage *capturedImage);
@end
