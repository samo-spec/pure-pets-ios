//
//  PPPetCareVetCell.h
//  Pure Pets
//
//  Reimagined from absolute first principles for NextGen V6 Flagship.
//  Category-defining clinical specialist card with live availability, verified credentials, and 1-tap contact.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

static NSString * const PPPetCareVetCellID = @"PPPetCareVetCellID";

@class VetModel;

@interface PPPetCareVetCell : UICollectionViewCell

@property (nonatomic, copy, nullable) void (^onDetailsTap)(void);
@property (nonatomic, copy, nullable) void (^onCallTap)(void);
@property (nonatomic, copy, nullable) void (^onWhatsAppTap)(void);

+ (NSString *)reuseIdentifier;

+ (CGFloat)preferredHeightForVet:(VetModel *)vet
                    mainKindName:(nullable NSString *)mainKindName
                           width:(CGFloat)width
                 traitCollection:(UITraitCollection *)traitCollection;

- (void)configureWithVet:(VetModel *)vet mainKindName:(nullable NSString *)mainKindName;

@end

NS_ASSUME_NONNULL_END
