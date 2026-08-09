//
//  PPPetCareVetCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/26/26.
//

NS_ASSUME_NONNULL_BEGIN
static NSString * const PPPetCareVetCellID = @"PPPetCareVetCellID";
@interface PPPetCareVetCell : UICollectionViewCell
@property (nonatomic, copy, nullable) void (^onDetailsTap)(void);
@property (nonatomic, copy, nullable) void (^onCallTap)(void);
+ (NSString *)reuseIdentifier;
+ (CGFloat)preferredHeightForVet:(VetModel *)vet
                    mainKindName:(nullable NSString *)mainKindName
                           width:(CGFloat)width
                 traitCollection:(UITraitCollection *)traitCollection;
- (void)configureWithVet:(VetModel *)vet mainKindName:(NSString *)mainKindName;
@end
NS_ASSUME_NONNULL_END
