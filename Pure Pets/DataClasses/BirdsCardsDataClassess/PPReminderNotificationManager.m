//
//  PPReminderNotificationManager.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 08/04/2026.
//

#import "PPReminderNotificationManager.h"
#import "PPPetReminder.h"
#import <UserNotifications/UserNotifications.h>

static NSString *const kPPReminderNotifPrefix = @"pp.pet.reminder.";

@implementation PPReminderNotificationManager

#pragma mark - Singleton

+ (instancetype)sharedManager {
    static PPReminderNotificationManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

#pragma mark - Permission

- (void)requestPermissionIfNeeded {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
        if (settings.authorizationStatus == UNAuthorizationStatusNotDetermined) {
            [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert |
                                                     UNAuthorizationOptionSound |
                                                     UNAuthorizationOptionBadge)
                                  completionHandler:^(BOOL granted, NSError * _Nullable error) {
                if (error) {
                    NSLog(@"[PPReminderNotif] Permission error: %@", error.localizedDescription);
                }
                NSLog(@"[PPReminderNotif] Permission granted: %d", granted);
            }];
        }
    }];
}

#pragma mark - Schedule

- (void)scheduleNotificationForReminder:(PPPetReminder *)reminder {
    if (!reminder || reminder.reminderID.length == 0) return;

    NSString *identifier = [self pp_identifierForReminderID:reminder.reminderID];
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];

    // Always cancel existing first to prevent duplicates
    [center removePendingNotificationRequestsWithIdentifiers:@[identifier]];

    // Do not schedule if disabled
    if (!reminder.enabled) {
        NSLog(@"[PPReminderNotif] Skipped (disabled): %@", reminder.reminderID);
        return;
    }

    // Do not schedule if fireDate is nil or in the past
    NSDate *fireDate = reminder.fireDate;
    if (!fireDate) {
        NSLog(@"[PPReminderNotif] Skipped (no fireDate): %@", reminder.reminderID);
        return;
    }

    if ([fireDate compare:[NSDate date]] != NSOrderedDescending) {
        NSLog(@"[PPReminderNotif] Skipped (past date %@): %@", fireDate, reminder.reminderID);
        return;
    }

    // Build content
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.title = reminder.title ?: @"";
    content.body  = [self pp_bodyForReminder:reminder];
    content.sound = [UNNotificationSound defaultSound];
    content.userInfo = @{
        @"reminderID": reminder.reminderID ?: @"",
        @"petID":      reminder.petID ?: @"",
        @"type":       @(reminder.type)
    };

    // Calendar trigger — exact date components
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSString *repeatRule = reminder.repeatRule ?: @"";
    BOOL repeats = (repeatRule.length > 0);

    NSCalendarUnit units;
    if ([repeatRule isEqualToString:@"daily"]) {
        units = NSCalendarUnitHour | NSCalendarUnitMinute;
    } else if ([repeatRule isEqualToString:@"weekly"]) {
        units = NSCalendarUnitWeekday | NSCalendarUnitHour | NSCalendarUnitMinute;
    } else if ([repeatRule isEqualToString:@"monthly"]) {
        units = NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute;
    } else if ([repeatRule isEqualToString:@"yearly"]) {
        units = NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute;
    } else {
        units = (NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay |
                 NSCalendarUnitHour | NSCalendarUnitMinute);
        repeats = NO;
    }

    NSDateComponents *comps = [calendar components:units fromDate:fireDate];
    comps.timeZone = calendar.timeZone;

    UNCalendarNotificationTrigger *trigger = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:comps repeats:repeats];

    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier
                                                                          content:content
                                                                          trigger:trigger];

    [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"[PPReminderNotif] Schedule error for %@: %@", reminder.reminderID, error.localizedDescription);
        } else {
            NSLog(@"[PPReminderNotif] Scheduled '%@' at %@ (repeat=%@)", reminder.title, fireDate, repeats ? repeatRule : @"none");
        }
    }];
}

#pragma mark - Cancel

- (void)cancelNotificationForReminderID:(NSString *)reminderID {
    if (reminderID.length == 0) return;

    NSString *identifier = [self pp_identifierForReminderID:reminderID];
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center removePendingNotificationRequestsWithIdentifiers:@[identifier]];
    [center removeDeliveredNotificationsWithIdentifiers:@[identifier]];

    NSLog(@"[PPReminderNotif] Cancelled: %@", reminderID);
}

#pragma mark - Batch Reschedule

- (void)rescheduleNotificationsForReminders:(NSArray<PPPetReminder *> *)reminders {
    // Cancel all existing reminder notifications first
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> * _Nonnull requests) {
        NSMutableArray<NSString *> *toRemove = [NSMutableArray array];
        for (UNNotificationRequest *req in requests) {
            if ([req.identifier hasPrefix:kPPReminderNotifPrefix]) {
                [toRemove addObject:req.identifier];
            }
        }
        if (toRemove.count > 0) {
            [center removePendingNotificationRequestsWithIdentifiers:toRemove];
        }

        // Re-schedule each enabled reminder
        for (PPPetReminder *rem in reminders) {
            [self scheduleNotificationForReminder:rem];
        }
        NSLog(@"[PPReminderNotif] Rescheduled %lu reminders", (unsigned long)reminders.count);
    }];
}

#pragma mark - Helpers

- (NSString *)pp_identifierForReminderID:(NSString *)reminderID {
    return [kPPReminderNotifPrefix stringByAppendingString:reminderID];
}

- (NSString *)pp_bodyForReminder:(PPPetReminder *)reminder {
    NSString *typeLabel;
    switch (reminder.type) {
        case PPPetReminderTypeFood:
            typeLabel = kLang(@"pet_reminder_food") ?: @"Feeding";
            break;
        case PPPetReminderTypeAppointment:
            typeLabel = kLang(@"pet_reminder_appointment") ?: @"Appointment";
            break;
        default:
            typeLabel = kLang(@"pet_reminder_vaccination") ?: @"Vaccination";
            break;
    }
    return [NSString stringWithFormat:@"🐾 %@ — %@", typeLabel, reminder.title ?: @""];
}

@end
