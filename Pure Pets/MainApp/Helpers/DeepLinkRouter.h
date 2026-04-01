//
//  DeepLinkRouter.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 27/05/2025.
//


#import <Foundation/Foundation.h>

@interface DeepLinkRouter : NSObject

+ (instancetype)shared;
- (BOOL)handleURL:(NSURL *)url;

@end
