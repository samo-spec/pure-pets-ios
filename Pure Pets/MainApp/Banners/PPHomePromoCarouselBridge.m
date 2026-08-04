#import "PPHomePromoCarouselBridge.h"
#import "Pure_Pets-Swift.h"

@implementation PPHomePromoCarouselBridge

+ (UIViewController *)makeCarouselWithActionHandler:(id<PPHomePromoCarouselActionHandling>)handler
{
    PPHomePromoCarouselHostingController *controller = [[PPHomePromoCarouselHostingController alloc] init];
    controller.actionHandler = handler;
    return controller;
}

+ (CGFloat)recommendedHeightForWidth:(CGFloat)width
{
    CGFloat cardWidth = MIN(width * 0.82, width - 44.0);
    CGFloat cardHeight = cardWidth / 1.42;
    BOOL usesAccessibilityType = UIContentSizeCategoryIsAccessibilityCategory(UIApplication.sharedApplication.preferredContentSizeCategory);
    CGFloat accessibilityBoost = usesAccessibilityType ? 92.0 : 0.0;
    return ceil(cardHeight + accessibilityBoost + 48.0);
}

@end
