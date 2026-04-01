//
//  BarcodeGenerator.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 02/03/2025.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BarcodeGenerator : NSObject

+ (UIImage *)generateBarcode:(NSString *)data width:(CGFloat)width height:(CGFloat)height;

@end

NS_ASSUME_NONNULL_END
