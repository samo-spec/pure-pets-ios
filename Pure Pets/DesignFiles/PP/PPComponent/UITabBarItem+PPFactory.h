//
//  UITabBarItem+PPFactory.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 22/12/2025.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UITabBarItem (PPFactory)

+ (instancetype)pp_itemWithConfig:(NSDictionary *)config;

@end

NS_ASSUME_NONNULL_END
