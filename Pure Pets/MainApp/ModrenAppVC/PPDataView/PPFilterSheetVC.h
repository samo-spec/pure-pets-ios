//
//  PPFilterSheetVC.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 31/12/2025.
//


#import <UIKit/UIKit.h>
#import "EnumValues.h"

NS_ASSUME_NONNULL_BEGIN

@interface PPFilterSheetVC : UIViewController

@property (nonatomic, assign) PPDataSection currentSection;
@property (nonatomic, assign) PPFilterAccessoryType accessoryFilter;
@property (nonatomic, assign) PPFilterServiceType serviceFilter;

@property (nonatomic, copy, nullable) void (^onApply)(
    PPFilterAccessoryType accessory,
    PPFilterServiceType service
);

@end

NS_ASSUME_NONNULL_END
