#import "PPHomePromoCarouselDataSource.h"

@implementation PPHomePromoCarouselDataSource

+ (instancetype)sharedSource
{
    static PPHomePromoCarouselDataSource *source;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        source = [[PPHomePromoCarouselDataSource alloc] init];
    });
    return source;
}

- (void)startWithUpdate:(PPHomePromoCarouselUpdateBlock)update
{
    [[PPHomePromoCarouselManager sharedManager] startListeningWithCompletion:update];
}

- (void)fetchOnceWithCompletion:(PPHomePromoCarouselUpdateBlock)completion
{
    [[PPHomePromoCarouselManager sharedManager] fetchOnceWithCompletion:completion];
}

- (void)stop
{
    [[PPHomePromoCarouselManager sharedManager] stopListening];
}

@end
