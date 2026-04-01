//
//  PPAdSharingHelper.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 15/01/2026.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPAdSharingHelper : NSObject
+ (void)sharePetAd:(PetAd *)petAd fromViewController:(UIViewController *)viewController;
+ (void)shareItem:(id)item fromViewController:(UIViewController *)viewController;
@end

NS_ASSUME_NONNULL_END
