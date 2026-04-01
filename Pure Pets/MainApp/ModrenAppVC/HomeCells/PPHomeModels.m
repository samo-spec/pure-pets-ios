//
//  PPHomeQuickActionModel.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 26/12/2025.
//


#import "PPHomeModels.h"

@implementation PPHomeQuickActionModel

+ (instancetype)modelWithType:(PPHomeQuickActionType)type
                         title:(NSString *)title
                      iconName:(NSString *)iconName {

    PPHomeQuickActionModel *m = [PPHomeQuickActionModel new];
    m.type = type;
    m.title = title;
    m.iconName = iconName;
    return m;
}

@end
