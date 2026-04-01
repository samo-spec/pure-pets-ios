//
//  PPHomeServiceItem.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 28/12/2025.
//


#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, PPHomeServiceType) {
    PPHomeServiceTypeVet,
    PPHomeServiceTypeGrooming,
    PPHomeServiceTypeTraining,
    PPHomeServiceTypeFood
};

NS_ASSUME_NONNULL_BEGIN

@interface PPHomeServiceItem : NSObject

@property (nonatomic, assign, readonly) PPHomeServiceType type;
@property (nonatomic, copy,   readonly) NSString *title;
@property (nonatomic, copy,   readonly) NSString *systemIconName;

/// Designated initializer
- (instancetype)initWithType:(PPHomeServiceType)type
                        title:(NSString *)title
               systemIconName:(NSString *)systemIconName NS_DESIGNATED_INITIALIZER;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

/// Factory helpers
+ (NSArray<PPHomeServiceItem *> *)defaultHomeServices;

@end

NS_ASSUME_NONNULL_END
