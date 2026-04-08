//
//  PPVaccinationEditorSheet.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/7/26.
//  Modern bottom-sheet editor for vaccination records.
//

#import <UIKit/UIKit.h>

@class PPPetVaccinationRecord;

NS_ASSUME_NONNULL_BEGIN

typedef void (^PPVaccinationEditorCompletion)(PPPetVaccinationRecord * _Nullable record, BOOL saved);

@interface PPVaccinationEditorSheet : UIViewController

/// Present for adding a new vaccination record.
- (instancetype)initForNewRecordWithCompletion:(PPVaccinationEditorCompletion)completion;

/// Present for editing an existing vaccination record.
- (instancetype)initWithRecord:(PPPetVaccinationRecord *)record
                    completion:(PPVaccinationEditorCompletion)completion;

/// Convenience: present the sheet from a parent view controller.
+ (void)presentFromViewController:(UIViewController *)parent
                       withRecord:(PPPetVaccinationRecord * _Nullable)record
                       completion:(PPVaccinationEditorCompletion)completion;

@end

NS_ASSUME_NONNULL_END
