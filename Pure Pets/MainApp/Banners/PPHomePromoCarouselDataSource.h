#import <Foundation/Foundation.h>
#import "PPBannersManager.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^PPHomePromoCarouselUpdateBlock)(NSArray<PPHomePromoCarouselCard *> * _Nullable cards,
                                               NSError * _Nullable error);

@interface PPHomePromoCarouselDataSource : NSObject

+ (instancetype)sharedSource NS_SWIFT_NAME(shared());

- (void)startWithUpdate:(PPHomePromoCarouselUpdateBlock)update
    NS_SWIFT_NAME(start(update:));

- (void)fetchOnceWithCompletion:(PPHomePromoCarouselUpdateBlock)completion
    NS_SWIFT_NAME(fetchOnce(completion:));

- (void)stop NS_SWIFT_NAME(stop());

@end

NS_ASSUME_NONNULL_END
