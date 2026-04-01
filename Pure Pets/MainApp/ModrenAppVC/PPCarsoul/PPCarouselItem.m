//
//  PPCarouselItem.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 27/12/2025.
//


#import "PPCarouselItem.h"

@implementation PPCarouselItem

+ (instancetype)itemWithIdentifier:(NSString *)identifier
                         imageURL:(NSString *)imageURL
                            title:(NSString *)title
                         subtitle:(NSString *)subtitle
                   placeholderImage:(UIImage *)placeholder {
    PPCarouselItem *item = [PPCarouselItem new];
    item.identifier = identifier;
    item.imageURL = imageURL;
    item.title = title;
    item.subtitle = subtitle;
    item.placeholderImage = placeholder;
    return item;
}

@end