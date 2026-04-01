//
//  ImagePicker.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 23/02/2025.
//

typedef void (^ImagePickerCompletionBlock)(UIImage * _Nullable image, NSError * _Nullable error);

@interface ImagePicker : NSObject <UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, weak) UIViewController *presentingViewController;
@property (nonatomic, copy) ImagePickerCompletionBlock completionBlock;

// Designated initializer
- (instancetype)initWithPresentingViewController:(UIViewController *)viewController;

// Method to show the image picker (either camera or photo library)
- (void)showImagePicker:(BOOL)useCamera completion:(ImagePickerCompletionBlock)completion;

- (void)showImageSourceSelection:(ImagePickerCompletionBlock)completion;


@end

