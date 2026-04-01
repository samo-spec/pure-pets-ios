//
//  UITabBarItem+PPFactory.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 22/12/2025.
//

#import "UITabBarItem+PPFactory.h"

@implementation UITabBarItem (PPFactory)

+ (instancetype)pp_itemWithConfig:(NSDictionary *)config
{
    NSString *icon  = config[@"icon"];
    NSString *title = config[@"title"];
    NSNumber *tag   = config[@"tag"];

    UIImage *image =
    [[UIImage imageNamed:icon] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

    UITabBarItem *item =
    [[UITabBarItem alloc] initWithTitle:title
                                  image:image
                                    tag:tag.integerValue];

    return item;
}

@end
