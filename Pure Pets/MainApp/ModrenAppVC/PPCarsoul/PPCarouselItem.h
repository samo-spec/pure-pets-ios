//
//  PPCarouselItem.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 27/12/2025.
//


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface PPCarouselItem : NSObject

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, strong) NSString *imageURL;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *subtitle;
@property (nonatomic, strong) UIImage *placeholderImage;

// Init
+ (instancetype)itemWithIdentifier:(NSString *)identifier
                         imageURL:(NSString *)imageURL
                            title:(NSString *)title
                         subtitle:(NSString *)subtitle
                   placeholderImage:(UIImage *)placeholder;

@end