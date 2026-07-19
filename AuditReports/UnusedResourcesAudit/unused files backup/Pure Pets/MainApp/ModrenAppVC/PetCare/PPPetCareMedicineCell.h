//
//  PPPetCareMedicineCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/26/26.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

static NSString * const PPPetCareMedicineCellID = @"PPPetCareMedicineCellID";





@interface PPPetCareMedicineCell : UICollectionViewCell
@property (nonatomic, copy, nullable) void (^onDetailsTap)(void);
+ (NSString *)reuseIdentifier;
- (void)configureWithMedicine:(VetMedicineModel *)medicine mainKindName:(NSString *)mainKindName;
@end

NS_ASSUME_NONNULL_END
