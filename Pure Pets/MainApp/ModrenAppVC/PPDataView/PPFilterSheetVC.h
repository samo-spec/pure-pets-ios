//
//  PPFilterSheetVC.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 31/12/2025.
//  Refactored: Data-driven filter sheet powered by PPFilterModels.
//

#import <UIKit/UIKit.h>
#import "PPFilterModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface PPFilterSheetVC : UIViewController

/// The filter state to display. Set before presentation.
@property (nonatomic, strong) PPFilterState *filterState;

/// Section label shown as subtitle.
@property (nonatomic, assign) PPDataSection currentSection;

/// Called when the user taps "Apply" — returns the modified PPFilterState.
@property (nonatomic, copy, nullable) void (^onApply)(PPFilterState *state);

@end

NS_ASSUME_NONNULL_END
