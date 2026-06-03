//
//  PPImageSearchService.h
//  Pure Pets
//
//  Direct search by photo service.
//  No Nova, no agent, no chat layer.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PPImageSearchMode) {
    PPImageSearchModeAuto = 0,
    PPImageSearchModeProducts,
    PPImageSearchModePets,
    PPImageSearchModeAdoption
};

@interface PPImageSearchService : NSObject

+ (instancetype)shared;

- (void)searchWithImage:(UIImage *)image
                   mode:(PPImageSearchMode)mode
                  limit:(NSNumber * _Nullable)limit
             completion:(void (^)(NSDictionary * _Nullable response,
                                   NSError * _Nullable error))completion;

+ (NSString *)stringForMode:(PPImageSearchMode)mode;

@end

NS_ASSUME_NONNULL_END
