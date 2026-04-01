//
//  PPHomeQuickActionModel.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 26/12/2025.
//


#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, PPHomeQuickActionType) {
    PPHomeQuickActionTypeNearestVet,
    PPHomeQuickActionTypeAccessories,
    PPHomeQuickActionTypeFood
};

@interface PPHomeQuickActionModel : NSObject

@property (nonatomic, assign) PPHomeQuickActionType type;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *iconName;

+ (instancetype)modelWithType:(PPHomeQuickActionType)type
                         title:(NSString *)title
                      iconName:(NSString *)iconName;

@end
