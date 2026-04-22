//
//  PPSectionHeaderView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 27/12/2025.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
 

/// Primary home-feed section header with expand/collapse, menus, and subtitle support.
@interface PPSectionHeaderView : UICollectionReusableView

@property (nullable, nonatomic, strong, readonly) UILabel *titleLabel;
@property (nullable, nonatomic, strong, readonly) UILabel *subtitleLabel;
@property (nullable, nonatomic, strong, readonly) UIButton *actionButton;

@property (nonatomic, copy, nullable) void (^onTap)(void);
@property (nonatomic, copy, nullable) void (^onTapMenu)(PPHomeSection homeSection, MainKindsModel * _Nonnull mainKindModel);

- (void)hide;

- (void)configureWithTitle:(nullable NSString *)title
                  subtitle:(nullable NSString *)subtitle
               actionTitle:(nullable NSString *)actionTitle
                  iconName:(nullable NSString *)iconName
                      menu:(nullable UIMenu *)menu
             ppHomeSection:(PPHomeSection)ppHomeSection;

- (void)configureWithTitle:(nullable NSString *)title
               actionTitle:(nullable NSString *)actionTitle
                  iconName:(nullable NSString *)iconName
                      menu:(nullable UIMenu *)menu
             ppHomeSection:(PPHomeSection)ppHomeSection;

@end

NS_ASSUME_NONNULL_END
