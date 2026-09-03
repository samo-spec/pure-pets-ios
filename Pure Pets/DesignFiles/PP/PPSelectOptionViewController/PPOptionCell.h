//
//  PPOptionCell.h
//  PurePetsAdmin
//
//  Created by Mohammed Ahmed on 24/08/2025.
//


// PPOptionCell.h
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
//NS_ASSUME_NONNULL_END
@class UserModel;

@interface PPOptionCell : UITableViewCell
@property (nonatomic, strong) UIImageView * _Nullable circleImageView;
@property (nonatomic, strong) UILabel * _Nullable titleLabel;
@property (nonatomic, strong) UILabel * _Nullable subtitleLabel;
@property (nonatomic, assign) CGFloat preferredHorizontalInset;
@property (nonatomic, assign) BOOL premiumCardStyleEnabled;
@property (nonatomic, assign) BOOL isUserOption;

- (void)configureWithTitle:(NSString * _Nullable)title subtitle:(NSString * _Nullable)subtitle image:(UIImage * _Nullable)image;
- (void)configureWithTitle:(NSString * _Nullable)title subtitle:(NSString * _Nullable)subtitle imageUrl:(NSString * _Nullable)imageUrl;
- (void)configureWithTitle:(NSString *)title subtitle:(NSString *)subtitle imageNamed:(NSString *)imageNamed;
- (void)configureWithTitle:(NSString *)title subtitle:(NSString *)subtitle imageNamed:(NSString *)imageNamed useSmallIcon:(BOOL)useSmallIcon;
- (void)configureWithTitle:(NSString * _Nullable)title
                  subtitle:(NSString * _Nullable)subtitle
                imageNamed:(NSString * _Nullable)imageNamed
              useSmallIcon:(BOOL)useSmallIcon
               accentColor:(UIColor * _Nullable)accentColor
                  selected:(BOOL)selected;

/// NextGen V6 Action Portal (for action / creation sheets)
- (void)configureAsActionPortalWithTitle:(nullable NSString *)title
                                subtitle:(nullable NSString *)subtitle
                                actionID:(nullable NSString *)actionID
                              systemIcon:(nullable NSString *)systemIcon
                             accentColor:(nullable UIColor *)accentColor
                                selected:(BOOL)selected;

/// NextGen V6 User Dossier (for user selection / chat starter)
- (void)configureAsUserDossierWithUser:(UserModel *)user
                              selected:(BOOL)selected;

- (void)setOptionSelected:(BOOL)selected animated:(BOOL)animated;
@end

NS_ASSUME_NONNULL_END

