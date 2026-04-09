//
//  AddNewAccessory.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 09/05/2025.
//

 
 
#import "RelativeDateDescriptor.h"


NS_ASSUME_NONNULL_BEGIN

// AddNewAccessory.h

typedef NS_ENUM(NSInteger, AccessFormMode) {
    AccessFormModeCreate,
    AccessFormModeEdit
};

@interface AddNewAccessory : UIViewController

@property (nonatomic, copy)   NSString *FromVC;

@property (assign, nonatomic) AccessKindType  accessKindType; // you already have this
@property (assign, nonatomic) AccessFormMode  formMode;       // NEW: create vs edit

/// If non-nil, we are editing this item and will prefill form.
@property (nullable, nonatomic, strong) PetAccessory *editingAccessory;

/// Optional completion to notify caller after successful save
@property (nullable, nonatomic, copy) void (^onFinish)(PetAccessory *result, BOOL isEdit);

@end


NS_ASSUME_NONNULL_END
