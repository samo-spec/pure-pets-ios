//
//  SearchResultItem.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 12/08/2025.
//


// SearchResultItem.m
#import "SearchResultItem.h"

@implementation SearchResultItem
+ (instancetype)itemWithType:(SearchResultType)type
                       title:(NSString *)title
                    subtitle:(NSString *)subtitle
                     imageURL:(NSString *)imageURL
                    rawObject:(id)obj {
    SearchResultItem *i = [SearchResultItem new];
    i.type = type;
    i.titleText = title ?: @"";
    i.subtitleText = subtitle ?: @"";
    i.imageURLString = imageURL ?: @"";
    i.rawObject = obj;
    return i;
}
@end
