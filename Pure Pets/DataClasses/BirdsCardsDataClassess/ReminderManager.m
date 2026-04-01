//
//  ReminderManager.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 07/04/2025.
//


// ReminderManager.m
#import "ReminderManager.h"
#import <UserNotifications/UserNotifications.h>

@implementation ReminderManager

+ (instancetype)sharedManager {
    static ReminderManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (void)startMonitoringReminders {
    NSLog(@"REMINDER ---- >>>>>> scheduleDailyCheck : %@", [NSDate date]);
    [self checkReminders];
    // Schedule a daily check
    NSTimer *dailyTimer = [NSTimer scheduledTimerWithTimeInterval:86400
                                                           target:self
                                                         selector:@selector(checkReminders)
                                                         userInfo:nil
                                                          repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:dailyTimer forMode:NSRunLoopCommonModes];
}

- (void)checkReminders {
    FIRFirestore *db = [FIRFirestore firestore];
    [[db collectionWithPath:@"CagesCol"] getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {
        if (error != nil) {
            NSLog(@"Error getting documents: %@", error);
        } else {
            for (FIRDocumentSnapshot *document in snapshot.documents) {
                NSDictionary *data = document.data;
                NSDate *reminderDate;
                
                FIRTimestamp *timestamp = data[@"ReminderDate"];
                if([timestamp.dateValue isKindOfClass:[NSDate class]])
                     reminderDate = timestamp.dateValue;
                
                
                //NSLog(@"REMINDER ---- >>>>>> checkReminders : %@", reminderDate);
                if ([self isToday:reminderDate]) {
                    [self scheduleLocalNotificationForCage:data[@"CageName"]];
                }
            }
        }
    }];
}

- (BOOL)isToday:(NSDate *)date {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    return [calendar isDateInToday:date];
}

- (void)scheduleLocalNotificationForCage:(NSString *)cageName {
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.title = kLang(@"Reminder");
    content.body = [NSString stringWithFormat:@"%@ %@",kLang(@"timeToCheck") , cageName];
    content.sound = [UNNotificationSound defaultSound];

    UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:1 repeats:NO];

    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:cageName content:content trigger:trigger];

    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"Error adding notification: %@", error);
        }
    }];
}

@end
