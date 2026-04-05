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

+ (NSArray<PPHomeQuickActionModel *> *)defaultHomeQuickActions
{
    return @[
        [self modelWithType:PPHomeQuickActionTypeNearestVet
                      title:(kLang(@"home_quick_action_nearest_vet") ?: @"Nearest Vet")
                   iconName:@"cross.case.circle.fill"],
        [self modelWithType:PPHomeQuickActionTypeSellPet
                      title:(kLang(@"home_quick_action_sell_pet") ?: @"Sell a pet")
                   iconName:@"pawprint.circle.fill"],
        [self modelWithType:PPHomeQuickActionTypeAdopt
                      title:(kLang(@"home_quick_action_adopt") ?: @"Adopt")
                   iconName:@"heart.circle.fill"],
        [self modelWithType:PPHomeQuickActionTypeAddAd
                      title:(kLang(@"home_quick_action_add_ad") ?: @"Add ad")
                   iconName:@"plus.circle.fill"],
        [self modelWithType:PPHomeQuickActionTypeRequestService
                      title:(kLang(@"home_quick_action_request_service") ?: @"Request service")
                   iconName:@"sparkles"]
    ];
}

@end

@implementation PPHomeGreetingModel

@end

@implementation PPHomeGreetingProvider

+ (PPHomeGreetingModel *)modelForDate:(NSDate *)date
                          displayName:(nullable NSString *)displayName
{
    PPHomeGreetingModel *model = [PPHomeGreetingModel new];
    NSString *baseGreeting = [self baseGreetingForDate:date];
    NSString *firstName = [self firstNameFromDisplayName:displayName];
    NSDate *resolvedDate = date ?: NSDate.date;
    NSInteger hour = [[NSCalendar currentCalendar] component:NSCalendarUnitHour
                                                    fromDate:resolvedDate];

    if (hour < 12) {
        model.period = PPHomeGreetingPeriodMorning;
    } else if (hour < 17) {
        model.period = PPHomeGreetingPeriodAfternoon;
    } else {
        model.period = PPHomeGreetingPeriodEvening;
    }

    model.baseGreetingText = baseGreeting ?: @"";
    model.displayName = firstName;

    if (firstName.length > 0) {
        NSString *formatKey = Language.isRTL
            ? @"home_greeting_named_format_rtl"
            : @"home_greeting_named_format_ltr";
        NSString *fallback = Language.isRTL ? @"%@ يا %@ 🐾" : @"%@, %@ 🐾";
        NSString *format = kLang(formatKey) ?: fallback;
        model.headlineText = [NSString stringWithFormat:format,
                              baseGreeting ?: @"",
                              firstName];
    } else {
        model.headlineText = baseGreeting ?: @"";
    }

    return model;
}

+ (NSString *)baseGreetingForDate:(NSDate *)date
{
    NSInteger hour = [[NSCalendar currentCalendar] component:NSCalendarUnitHour
                                                    fromDate:(date ?: NSDate.date)];

    if (hour < 5 || hour >= 22) {
        return kLang(@"Good evening") ?: @"Good evening";
    }
    if (hour < 12) {
        return kLang(@"Good morning") ?: @"Good morning";
    }
    if (hour < 17) {
        return kLang(@"Good afternoon") ?: @"Good afternoon";
    }
    return kLang(@"Good evening") ?: @"Good evening";
}

+ (nullable NSString *)firstNameFromDisplayName:(nullable NSString *)displayName
{
    NSString *safeName = PPSafeString(displayName);
    if (safeName.length == 0) {
        return nil;
    }

    NSArray<NSString *> *parts =
        [safeName componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    for (NSString *candidate in parts) {
        NSString *trimmed =
            [candidate stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length > 0) {
            return trimmed;
        }
    }

    return nil;
}

@end
