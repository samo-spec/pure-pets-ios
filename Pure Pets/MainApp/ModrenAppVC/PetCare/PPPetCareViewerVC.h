//
//  PPPetCareViewerVC.h
//  Pure Pets
//
//  Created by Codex on 4/26/26.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class VetMedicineModel;

@interface PPPetCareViewerVC : UIViewController

- (instancetype)initWithMedicine:(VetMedicineModel *)medicine
                    mainKindName:(nullable NSString *)mainKindName NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil
                         bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
