//
//  PPHomeSearchBarCell.h
//  Pure Pets
//
//  Premium minimal search bar — one surface, one icon, one statement.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPHomeSmartSearchTitleView : UIControl
@property (nonatomic, strong, readonly) UILabel *placeholderLabel;
@property (nonatomic, assign) BOOL showSmartPillBackground;
- (void)setQueryText:(NSString *)text animated:(BOOL)animated;
@end



NS_ASSUME_NONNULL_END
