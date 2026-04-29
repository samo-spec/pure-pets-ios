//
//  PPHomeViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 24/12/2025.
//


//
//  PPHomeViewController.h
//  PurePets
//
 #import <UIKit/UIKit.h>
#import "AdoptPetsViewController.h"
#import "PPHomeFunc.h"
#import "CartViewController.h"
#import "PPHomeHelper.h"
#import "PPDataViewVC.h"


// =========================
// Deep Link Target Enum
// =========================


NS_ASSUME_NONNULL_BEGIN

 

@interface PPHomeViewController : UIViewController

// Forward declaration for deep-link helper (clean)
- (PPDataViewVC *)buildDataViewVCForTarget:(PPDeepLinkTarget)target
                                  mainKind:(MainKindsModel *_Nullable)mainKind
                                    source:(PPInputSource)source;
@property (nonatomic) PPMainKindsLayoutMode mainKindsLayoutMode;
@end

NS_ASSUME_NONNULL_END
