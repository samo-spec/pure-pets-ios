#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class MainKindsModel;

typedef NS_ENUM(NSInteger, PPPetCareInitialSection) {
    PPPetCareInitialSectionMedicines = 0,
    PPPetCareInitialSectionVeterinarians = 1
};

@interface PPPetCareViewController : UIViewController

- (instancetype)initWithInitialSection:(PPPetCareInitialSection)section
                              mainKind:(nullable MainKindsModel *)mainKind NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil
                         bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
