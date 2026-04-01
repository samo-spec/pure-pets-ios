//
//  PPAdSubmitCoordinator.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 15/01/2026.
//


#import <Foundation/Foundation.h>
@class PetAd;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PPAdSubmitMode) {
    PPAdSubmitModeCreate,
    PPAdSubmitModeUpdate
};

@interface PPAdSubmitCoordinator : NSObject

- (instancetype)initWithAd:(PetAd *)ad
                      mode:(PPAdSubmitMode)mode
                    images:(NSArray<UIImage *> *)images;

/// Callbacks
@property (nonatomic, copy) void (^onStart)(void);
@property (nonatomic, copy) void (^onSuccess)(PetAd *finalAd);
@property (nonatomic, copy) void (^onFailure)(NSError *error);

/// Start flow
- (void)start;

@end

NS_ASSUME_NONNULL_END