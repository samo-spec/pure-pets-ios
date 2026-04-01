//
//  PPBrowseHistoryManager.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 07/01/2026.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


@interface PPBrowseEvent : NSObject
@property (nonatomic, assign) PPBrowseItemType type;
@property (nonatomic, assign) NSInteger mainKindID;
@property (nonatomic, strong) NSDate *date;
@end


@interface PPBrowseHistoryManager : NSObject
+ (instancetype)shared;

- (void)trackItemWithType:(PPBrowseItemType)type
               mainKindID:(NSInteger)mainKindID;

- (NSArray<NSNumber *> *)topMainKindsWithLimit:(NSInteger)limit;

- (NSDictionary *)latestEvent;

@end


NS_ASSUME_NONNULL_END
