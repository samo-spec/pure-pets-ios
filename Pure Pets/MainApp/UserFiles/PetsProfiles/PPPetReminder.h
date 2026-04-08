//
//  PPPetReminder.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/7/26.
//


#import <Foundation/Foundation.h>
@import FirebaseFirestore;

typedef NS_ENUM(NSInteger, PPPetReminderType) {
    PPPetReminderTypeVaccination = 0,
    PPPetReminderTypeFood,
    PPPetReminderTypeAppointment
};

NS_ASSUME_NONNULL_BEGIN

@interface PPPetReminder : NSObject
@property (nonatomic, copy) NSString *reminderID;
@property (nonatomic, copy) NSString *petID;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, assign) PPPetReminderType type;
@property (nonatomic, strong, nullable) NSDate *fireDate;
@property (nonatomic, copy, nullable) NSString *repeatRule;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, strong, nullable) NSDate *createdAt;
@property (nonatomic, strong, nullable) NSDate *updatedAt;
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot;
- (NSDictionary *)toDictionary;
- (NSString *)typeLabelKey;
- (NSString *)displayTypeText;
@end

NS_ASSUME_NONNULL_END