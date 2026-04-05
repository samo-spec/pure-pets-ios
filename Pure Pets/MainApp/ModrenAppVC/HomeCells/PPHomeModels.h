//
//  PPHomeQuickActionModel.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 26/12/2025.
//


#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, PPHomeQuickActionType) {
    PPHomeQuickActionTypeNearestVet,
    PPHomeQuickActionTypeSellPet,
    PPHomeQuickActionTypeAdopt,
    PPHomeQuickActionTypeAddAd,
    PPHomeQuickActionTypeRequestService
};

@interface PPHomeQuickActionModel : NSObject

@property (nonatomic, assign) PPHomeQuickActionType type;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *iconName;

+ (instancetype)modelWithType:(PPHomeQuickActionType)type
                         title:(NSString *)title
                      iconName:(NSString *)iconName;
+ (NSArray<PPHomeQuickActionModel *> *)defaultHomeQuickActions;

@end

typedef NS_ENUM(NSInteger, PPHomeGreetingPeriod) {
    PPHomeGreetingPeriodMorning = 0,
    PPHomeGreetingPeriodAfternoon,
    PPHomeGreetingPeriodEvening
};

@interface PPHomeGreetingModel : NSObject

@property (nonatomic, assign) PPHomeGreetingPeriod period;
@property (nonatomic, copy) NSString *headlineText;
@property (nonatomic, copy) NSString *baseGreetingText;
@property (nonatomic, copy, nullable) NSString *displayName;

@end

@interface PPHomeGreetingProvider : NSObject

+ (PPHomeGreetingModel *)modelForDate:(NSDate *)date
                          displayName:(nullable NSString *)displayName;
+ (NSString *)baseGreetingForDate:(NSDate *)date;
+ (nullable NSString *)firstNameFromDisplayName:(nullable NSString *)displayName;

@end
