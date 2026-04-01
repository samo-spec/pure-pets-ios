//
//  PPSectionHeaderView 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 27/12/2025.
//

 
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPCollectionSectionHeader : UICollectionReusableView

- (void)configureWithTitle:(NSString *)title
                  subtitle:(nullable NSString *)subtitle
               actionTitle:(nullable NSString *)actionTitle
                    action:(nullable void (^)(void))action;

@end




@interface PPSectionHeaderView : UICollectionReusableView

@property (nullable, nonatomic, strong) UILabel *titleLabel;
@property (nullable, nonatomic, strong) UILabel *subtitleLabel;

@property (nonatomic, copy, nullable) void (^onTap)(void);
@property (nonatomic, copy, nullable) void (^onTapMenu)(PPHomeSection homeSection,MainKindsModel * _Nonnull mainKindModel);

- (void)hide;
- (void)configureWithTitle:(nullable NSString *)title
                  subtitle:(nullable NSString *)subtitle
               actionTitle:(nullable NSString *)actionTitle
                  iconName:(nullable NSString *)iconName
                      menu:(nullable UIMenu *)menu
             ppHomeSection:(PPHomeSection)ppHomeSection;

// Backward compatibility
- (void)configureWithTitle:(nullable NSString *)title
               actionTitle:(nullable NSString *)actionTitle
                  iconName:(nullable NSString *)iconName
                      menu:(nullable UIMenu *)menu
             ppHomeSection:(PPHomeSection)ppHomeSection;



@property (nullable,nonatomic, strong) UIButton *actionButton;;
@end

NS_ASSUME_NONNULL_END


