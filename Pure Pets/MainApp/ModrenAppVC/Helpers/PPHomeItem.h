//
//  PPHomeItem.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 01/01/2026.
//



@interface PPHomeItem : NSObject
/// Stable unique identifier for diffable datasource
@property (nonatomic, copy, readonly) NSString *identifier;
/// Type of item (used by Home VC)
@property (nonatomic, assign) PPHomeItemType type;
/// Raw payload (MainKindsModel, ServiceModel, PetAd, etc)
@property (nonatomic, strong) id payload;
/// Universal cell view model (optional)
@property (nonatomic, strong) PPUniversalCellViewModel *universalViewModel;
/// Designated initializer
- (instancetype)initWithType:(PPHomeItemType)type payload:(id)payload;
/// Convenience for universal cells
- (instancetype)initWithType:(PPHomeItemType)type universalModel:(PPUniversalCellViewModel *)viewModel;

@property (nonatomic, assign) PPCategoryItemKind categoryKind;

@end


/*
 @interface PPHomeItem : NSObject
 /// Stable unique identifier for diffable datasource
 @property (nonatomic, copy, readonly) NSString *identifier;
 /// Type of item (used by Home VC)
 @property (nonatomic, assign) PPHomeItemType type;
 /// Raw payload (MainKindsModel, ServiceModel, PetAd, etc)
 @property (nonatomic, strong) id payload;
 /// Universal cell view model (optional)
 @property (nonatomic, strong) PPUniversalCellViewModel *universalViewModel;
 /// Designated initializer
 - (instancetype)initWithType:(PPHomeItemType)type payload:(id)payload;
 /// Convenience for universal cells
 - (instancetype)initWithType:(PPHomeItemType)type universalModel:(PPUniversalCellViewModel *)viewModel;
 @end
 */
