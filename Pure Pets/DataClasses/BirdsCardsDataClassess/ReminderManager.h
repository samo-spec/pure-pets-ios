//
//  ReminderManager.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 07/04/2025.
//


// ReminderManager.h
#import <Foundation/Foundation.h>

@interface ReminderManager : NSObject

+ (instancetype)sharedManager;
- (void)startMonitoringReminders;

@end


