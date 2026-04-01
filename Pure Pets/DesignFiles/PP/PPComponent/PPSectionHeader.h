//
//  PPSectionHeader.h
//  Pure Pets
//
//  Design System — Reusable section header with title + trailing "عرض الكل" link.
//  Supports RTL/LTR, bilingual, and design-system spacing.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPSectionHeader : UICollectionReusableView

+ (NSString *)reuseIdentifier;

/// Configure the header with a title and optional "see all" action.
/// @param title   Section title (e.g., "الأكثر طلباً")
/// @param showAll Whether to show the trailing action link
/// @param action  Block invoked when "عرض الكل" is tapped (ignored if showAll is NO)
- (void)configureWithTitle:(NSString *)title
                   showAll:(BOOL)showAll
                    action:(nullable void(^)(void))action;

@end

NS_ASSUME_NONNULL_END
