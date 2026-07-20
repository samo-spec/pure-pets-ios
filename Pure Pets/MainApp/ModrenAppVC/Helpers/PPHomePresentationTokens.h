#ifndef PPHomePresentationTokens_h
#define PPHomePresentationTokens_h

#import <UIKit/UIKit.h>

static const CGFloat PPHomeScreenInset = 16.0;
static const CGFloat PPHomeSectionSpacing = 20.0;
static const CGFloat PPHomeInteritemSpacing = 12.0;
static const CGFloat PPHomeCardCornerRadius = 20.0;
static const CGFloat PPHomeHeroCornerRadius = 32.0;
static const CGFloat PPHomeControlCornerRadius = 14.0;
static const CGFloat PPHomeButtonHeight = 44.0;
static const CGFloat PPHomeCompactHeaderHeight = 52.0;
static const CGFloat PPHomeRegularHeaderHeight = 68.0;
static const CGFloat PPHomeSearchCollapseDistance = 72.0;
static const CGFloat PPHomeSearchOverscrollDistance = 64.0;
static const CGFloat PPHomeAnimationDurationFast = 0.16;
static const CGFloat PPHomeAnimationDurationNormal = 0.24;

static inline CGFloat PPHomeClamp(CGFloat value, CGFloat lower, CGFloat upper)
{
    return MIN(MAX(value, lower), upper);
}

static inline BOOL PPHomeUsesAccessibilityTextSize(UITraitCollection *traits)
{
    return UIContentSizeCategoryIsAccessibilityCategory(
        traits.preferredContentSizeCategory
    );
}

static inline BOOL PPHomeUsesAccessibilityText(void)
{
    return PPHomeUsesAccessibilityTextSize(UIScreen.mainScreen.traitCollection) ||
        UIContentSizeCategoryIsAccessibilityCategory(
            UIApplication.sharedApplication.preferredContentSizeCategory
        );
}

static inline CGFloat PPHomeProductCardWidthForContainer(CGFloat width)
{
    if (width >= 700.0) {
        return 220.0;
    }
    if (width >= 414.0) {
        return 178.0;
    }
    if (width >= 390.0) {
        return 168.0;
    }
    if (width >= 375.0) {
        return 162.0;
    }
    return 154.0;
}

static inline CGFloat PPHomeProductCardHeightForContainer(CGFloat width)
{
    if (PPHomeUsesAccessibilityText()) {
        return width >= 700.0 ? 424.0 : 416.0;
    }
    return width >= 700.0 ? 338.0 : 324.0;
}

static inline CGFloat PPHomeSectionHeaderHeight(BOOL includesSubtitle)
{
    if (PPHomeUsesAccessibilityText()) {
        return includesSubtitle ? 104.0 : 72.0;
    }
    return includesSubtitle ? PPHomeRegularHeaderHeight : PPHomeCompactHeaderHeight;
}

static inline UIColor *PPHomeSemanticCardSurfaceColor(void)
{
    UIColor *asset = [UIColor colorNamed:@"AppCardColor"];
    if (asset) {
        return asset;
    }
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark
            ? UIColor.secondarySystemBackgroundColor
            : UIColor.systemBackgroundColor;
    }];
}

static inline UIColor *PPHomeSemanticCanvasColor(void)
{
    return [UIColor colorNamed:@"AppBackgroundColor"] ?: UIColor.systemGroupedBackgroundColor;
}

static inline UIColor *PPHomeSemanticHairlineColor(void)
{
    return [UIColor.separatorColor colorWithAlphaComponent:0.24];
}

#endif
