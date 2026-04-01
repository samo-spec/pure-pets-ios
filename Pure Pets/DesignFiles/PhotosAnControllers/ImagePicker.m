//
//  ImagePicker.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 23/02/2025.
//

#import "ImagePicker.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "PPPermissionHelper.h"

@implementation ImagePicker

- (instancetype)initWithPresentingViewController:(UIViewController *)viewController {
    self = [super init];
    if (self) {
        _presentingViewController = viewController;
    }
    return self;
}

- (void)showImageSourceSelection:(ImagePickerCompletionBlock)completion {
    self.completionBlock = completion;
   
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];

    UIAlertAction *takePhotoAction = [UIAlertAction actionWithTitle:kLang(@"cam")
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction * action) {
                                                                [self showImagePicker:YES completion:completion];
                                                            }];
    [alertController addAction:takePhotoAction];

    UIAlertAction *chooseFromLibraryAction = [UIAlertAction actionWithTitle:kLang(@"geralley")
                                                                      style:UIAlertActionStyleDefault
                                                                    handler:^(UIAlertAction * action) {
                                                                        [self showImagePicker:NO completion:completion];
                                                                    }];
    [alertController addAction:chooseFromLibraryAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:kLang(@"cancel")
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * action) {
                                                             if (self.completionBlock) {
                                                              /*   NSError *error = [NSError errorWithDomain:@"ImagePickerErrorDomain"
                                                                                                     code:1000
                                                                                                 userInfo:@{NSLocalizedDescriptionKey: @"Image selection cancelled."}];
                                                                 self.completionBlock(nil, error);
                                                                 self.completionBlock = nil; // Clear the completion block */
                                                             }
                                                         }];
    [alertController addAction:cancelAction];

    // For iPad, present the action sheet as a popover
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        alertController.popoverPresentationController.sourceView = self.presentingViewController.view;
        alertController.popoverPresentationController.sourceRect = CGRectMake(self.presentingViewController.view.bounds.size.width / 2.0, self.presentingViewController.view.bounds.size.height / 2.0, 0, 0); // Adjust as needed
        alertController.popoverPresentationController.permittedArrowDirections = 0; // Disable arrow
    }

    [self.presentingViewController presentViewController:alertController animated:YES completion:nil];
}


- (void)showImagePicker:(BOOL)useCamera completion:(ImagePickerCompletionBlock)completion {
    self.completionBlock = completion;
    __weak typeof(self) weakSelf = self;

    if (useCamera) {
        if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
            NSLog(@"Camera not available on this device.");
            if (self.completionBlock) {
                NSError *error = [NSError errorWithDomain:@"ImagePickerErrorDomain"
                                                     code:1001
                                                 userInfo:@{NSLocalizedDescriptionKey: @"Camera not available."}];
                self.completionBlock(nil, error);
            }
            return;
        }
        [PPPermissionHelper requestCameraPermissionFromViewController:self.presentingViewController
                                                           completion:^(BOOL granted) {
            if (!granted) return;
            [weakSelf pp_presentPickerWithSourceType:UIImagePickerControllerSourceTypeCamera];
        }];
    } else {
        [PPPermissionHelper requestPhotoLibraryPermissionFromViewController:self.presentingViewController
                                                                completion:^(BOOL granted) {
            if (!granted) return;
            [weakSelf pp_presentPickerWithSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
        }];
    }
}

- (void)pp_presentPickerWithSourceType:(UIImagePickerControllerSourceType)sourceType {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.allowsEditing = NO;
    picker.sourceType = sourceType;
    if (sourceType == UIImagePickerControllerSourceTypeCamera) {
        picker.cameraCaptureMode = UIImagePickerControllerCameraCaptureModePhoto;
    }
    picker.mediaTypes = @[(NSString *)kUTTypeImage];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        picker.modalPresentationStyle = UIModalPresentationPopover;
        UIPopoverPresentationController *popover = picker.popoverPresentationController;
        popover.sourceView = self.presentingViewController.view;
        popover.sourceRect = CGRectMake(CGRectGetMidX(popover.sourceView.bounds), CGRectGetMidY(popover.sourceView.bounds), 0, 0);
    }
    [self.presentingViewController presentViewController:picker animated:YES completion:nil];
}


#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    UIImage *chosenImage = info[UIImagePickerControllerEditedImage]; // Use edited image if available
    if (!chosenImage) {
        chosenImage = info[UIImagePickerControllerOriginalImage]; // Fallback to original image
    }

    [picker dismissViewControllerAnimated:YES completion:^{
        if (self.completionBlock) {
            self.completionBlock(chosenImage, nil);
            self.completionBlock = nil; // Clear the completion block to avoid potential issues
        }
    }];
}


- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:^{
        if (self.completionBlock) {
            NSError *error = [NSError errorWithDomain:@"ImagePickerErrorDomain"
                                                 code:1000
                                             userInfo:@{NSLocalizedDescriptionKey: @"Image selection cancelled."}];
            self.completionBlock(nil, error);
            self.completionBlock = nil; // Clear the completion block
        }
    }];
}


#pragma mark - UINavigationControllerDelegate (Required for UIImagePickerController)

// This delegate method is required to conform to the UINavigationControllerDelegate protocol.
// It's often empty, but its presence is necessary.
- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    // You can add custom logic here if needed, such as styling the navigation bar of the image picker.
}


@end
