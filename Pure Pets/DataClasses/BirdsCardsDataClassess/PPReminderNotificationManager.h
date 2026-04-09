//
//  PPReminderNotificationManager.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 08/04/2026.
//

#import <Foundation/Foundation.h>
@class PPPetReminder;

NS_ASSUME_NONNULL_BEGIN

/// Manages local notifications for PPPetReminder objects.
/// Uses UNCalendarNotificationTrigger for exact-time scheduling.
@interface PPReminderNotificationManager : NSObject

+ (instancetype)sharedManager;

/// Request notification authorization (call once at launch).
- (void)requestPermissionIfNeeded;

/// Schedule (or reschedule) a local notification for a reminder.
/// Cancels any existing notification for the same reminderID first.
/// Does nothing if fireDate is in the past or reminder is disabled.
- (void)scheduleNotificationForReminder:(PPPetReminder *)reminder;

/// Cancel a pending notification for the given reminder ID.
- (void)cancelNotificationForReminderID:(NSString *)reminderID;

/// Reschedule all enabled reminders (e.g. after app restore / timezone change).
- (void)rescheduleNotificationsForReminders:(NSArray<PPPetReminder *> *)reminders;

@end

NS_ASSUME_NONNULL_END
