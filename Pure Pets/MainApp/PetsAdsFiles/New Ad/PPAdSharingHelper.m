//
//  PPAdSharingHelper.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 15/01/2026.
//

#import "PPAdSharingHelper.h"

NS_ASSUME_NONNULL_BEGIN

@implementation PPAdSharingHelper



#pragma mark - Sharing (same as before)
// Refactored to require the presenting view controller
+ (void)showSharingOptionsForPetAd:(PetAd *)petAd fromViewController:(UIViewController *)vc {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"Share Options")
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"Share with Photo")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [PetAd sharePetAd:petAd fromViewController:vc];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"Copy Details")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [PetAd copyPetAdToClipboard:petAd];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"Save as Text File")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [PetAd exportPetAdAsTextFile:petAd fromViewController:vc];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"Cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    
    // iPad requires popover for action sheets
    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = vc.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(vc.view.bounds),
                                                                     CGRectGetMidY(vc.view.bounds),
                                                                     0, 0);
        alert.popoverPresentationController.permittedArrowDirections = 0;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [vc presentViewController:alert animated:YES completion:nil];
    });
}


+ (void)sharePetAd:(PetAd *)petAd fromViewController:(UIViewController *)vc {
    [self showSharingOptionsForPetAd:petAd fromViewController:vc];
}


+ (void)shareItem:(id)item fromViewController:(UIViewController *)viewController {
    NSString *deepLink = @"";
    NSString *message = @"";
    NSMutableArray *itemsToShare = [NSMutableArray array];
    
    if ([item isKindOfClass:[PetAd class]]) {
        PetAd *petAd = (PetAd *)item;
        
        // Construct deep link
        deepLink = [NSString stringWithFormat:@"purepets://petad/%@", petAd.adID];
        
        // Compose message
        message = [NSString stringWithFormat:
                   @"Check out this pet ad!\n\n%@: %@\n%@: %@\n%@: %@\n\nOpen in app: %@",
                   kLang(@"category"), [MainKindsModel kindNameForID:petAd.category],
                   kLang(@"subcategory"), [SubKindModel getSubKindName:(long)petAd.subcategory subKindsArrayLocal:[MKM getSubKindArray:petAd.category]],
                   kLang(@"price"), petAd.price,
                   deepLink];
        
        [itemsToShare addObject:message];
        
        PetImageItem *item = petAd.imageItems.firstObject;
        if (item.url.length > 0) {
            NSData *imageData =
            [NSData dataWithContentsOfURL:[NSURL URLWithString:item.url]];
            if (imageData) {
                UIImage *originalImage = [UIImage imageWithData:imageData];
                if (originalImage) {
                    UIImage *watermarkedImage = [self imageWithLogoWatermark:originalImage logo:[UIImage imageNamed:@"newlogo"]];
                    [itemsToShare addObject:watermarkedImage];
                }
            }
        }
        
    } else if ([item isKindOfClass:[PetAccessory class]]) {
        PetAccessory *accessory = (PetAccessory *)item;
        
        // Construct deep link
        deepLink = [NSString stringWithFormat:@"purepets://accessory/%@", accessory.accessoryID];
        
        // Compose message
        message = [NSString stringWithFormat:
                   @"Check out this pet accessory!\n\n%@: %@\n%@: %@\n\nOpen in app: %@",
                   kLang(@"name"), accessory.name ?: @"",
                   kLang(@"price"), accessory.price ?: @"",
                   deepLink];
        
        [itemsToShare addObject:message];
        
        if (accessory.imageURLsArray.count > 0) {
            NSString *imageURLString = accessory.imageURLsArray.firstObject;
            NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:imageURLString]];
            if (imageData) {
                UIImage *originalImage = [UIImage imageWithData:imageData];
                if (originalImage) {
                    //UIImage *watermarkedImage = [self imageWithWatermark:originalImage watermarkText:@"Pure Pets"];
                    UIImage *watermarkedImage = [self imageWithLogoWatermark:originalImage logo:[UIImage imageNamed:@"newlogo"]];
                    [itemsToShare addObject:watermarkedImage];
                }
            }
        }
        
    } else {
        NSLog(@"Unsupported item type for sharing.");
        return;
    }
    
    // Share sheet
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:itemsToShare applicationActivities:nil];
    activityVC.excludedActivityTypes = @[
        UIActivityTypeAssignToContact,
        UIActivityTypePrint,
        UIActivityTypeSaveToCameraRoll,
        UIActivityTypeAddToReadingList
    ];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = viewController.view;
        activityVC.popoverPresentationController.sourceRect = CGRectMake(viewController.view.bounds.size.width/2, viewController.view.bounds.size.height/2, 1, 1);
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [viewController presentViewController:activityVC animated:YES completion:nil];
    });
}


+ (UIImage *)imageWithLogoWatermark:(UIImage *)originalImage logo:(UIImage *)logoImage {
    CGSize imageSize = originalImage.size;
    UIGraphicsBeginImageContextWithOptions(imageSize, NO, originalImage.scale);
    
    // Draw the original image
    [originalImage drawInRect:CGRectMake(0, 0, imageSize.width, imageSize.height)];
    
    // Define logo size and position (bottom-right corner)
    CGFloat logoSize = imageSize.width * 0.25; // 15% of image width
    CGFloat margin = 10.0;
    CGRect logoRect = CGRectMake(imageSize.width - logoSize - margin,
                                 imageSize.height - logoSize,
                                 logoSize,
                                 logoSize);
    
    [logoImage drawInRect:logoRect blendMode:kCGBlendModeNormal alpha:0.85];
    
    UIImage *watermarkedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return watermarkedImage;
}

@end

NS_ASSUME_NONNULL_END
