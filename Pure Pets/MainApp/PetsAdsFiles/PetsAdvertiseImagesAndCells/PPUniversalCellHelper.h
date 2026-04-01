//
//  PPUniversalCellHelper.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 20/10/2025.
//

#import <Foundation/Foundation.h>
 NS_ASSUME_NONNULL_BEGIN

@interface PPBottomOverlayBlur : UIView
- (instancetype)initWithHeight:(CGFloat)height
                  cornerRadius:(CGFloat)cornerRadius;
@end


@interface PPCornerBlurView : UIView
@property (nonatomic, copy) void (^layoutSubviewsBlock)(void);
@property (nonatomic, strong, nullable) UIVisualEffectView *blurView;
@end







@interface PPUniversalCell (PPUniversalCellHelper)
- (UIMenu *)ownerActionsArray;

- (void)applyViewModel:(PPUniversalCellViewModel *)vm
               context:(PPCellContext)context
            layoutMode:(PPManagerCellLayoutMode)layout
          discountMode:(PPDiscountStyle)discountStyle
           imageLoader:(PPImageLoader _Nullable)loader;


- (void)changeBlurStyleForOverlay:(PPCornerBlurView *)overlay
                             style:(UIBlurEffectStyle)newStyle
                         animated:(BOOL)animated ;
 


- (void)deactivateConstraints:(NSArray<NSLayoutConstraint *> *)constraints;

- (UIButton *)iconButton:(NSString *)systemName buttonKind:(ButtonKind)buttonKind ;
- (UIButton *)iconButton:(NSString *)systemName buttonKind:(ButtonKind)buttonKind size:(CGFloat)size;
- (UIButton *)iconButton:(NSString *)systemName buttonKind:(ButtonKind)buttonKind size:(CGFloat)size baseForground:(UIColor *)baseForground baseBackground:(UIColor *)baseBackground;

- (PPInsetLabel *)createDiscountValueLabel;
- (UILabel *)createTitleLabel;
- (UIView *)createCard;
- (UIImageView *)createImageView;
- (UILabel *)createSubtitleLabel;
- (UIStackView *)createTextStackWithElements:(NSArray *)elemnts;
- (UILabel *)createPriceLabel;
- (UILabel *)createDiscountLabel;
- (UIStackView *)createPriceStackWithSubviews:(NSArray *)elemnts;
//- (UIImageView *)create;
- (void)activateConstraintsForMode:(PPManagerCellLayoutMode)mode ;
- (UIMenu *)adActionsArray;
- (UIButton *)capsuleButtonWithTitle:(NSString *)title;
- (UILabel *)badgeWithText:(NSString *)text bg:(UIColor *)bg;
- (void)tapEdit;
// Add / Stepper
- (PPInsetLabel *)createStockQtyLabel;
- (UILabel *)createQtyLabel;
- (UIView *)createStepperView;

- (PPCornerBlurView *)createBottomBlurOnView:(UIView *)cardView
                                          tl:(CGFloat)tl
                                          tr:(CGFloat)tr
                                          bl:(CGFloat)bl
                                          br:(CGFloat)br
                                      height:(CGFloat)height;


- (void)applyCornerMaskToView:(UIView *)view
                           tl:(CGFloat)tl
                           tr:(CGFloat)tr
                           bl:(CGFloat)bl
                           br:(CGFloat)br;




-(void)setFavForCollection:(NSString *)collection andID:(NSString *)ID andButton:(FavoriteFloatingButton *)favButton;




@property (nonatomic, strong) UIButton *addButton;    // collapsed "+"
@property (nonatomic, strong) UIView *stepperView;    // expanded container
@property (nonatomic, strong) UIButton *minusBtn;
@property (nonatomic, strong) UILabel  *qtyLabel;
@property (nonatomic, strong) UIButton *plusBtn;
@property (nonatomic, strong) NSLayoutConstraint *stepperWidthConstraint;
@property (nonatomic, strong) NSTimer *stepperCollapseTimer;
@property (nonatomic, assign, readwrite) NSInteger quantity;
- (void)restartStepperCollapseTimer;
- (void)tapPlus;
- (void)tapAddCollapsed;
- (void)tapMinus;
- (void)autoCollapseStepper;


- (void)setPriceToLabel:(UILabel *)label
                  price:(NSNumber *)price
               currency:(NSString *)currency
             priceColor:(UIColor *)priceColor;

@property (nonatomic, copy, nullable) PPVoidHandler onTapCard;
@property (nonatomic, copy, nullable) PPVoidHandler onTapShare;
@property (nonatomic, copy, nullable) PPVoidHandler onTapFavorite;
@property (nonatomic, copy, nullable) PPVoidHandler onTapEdit;
@property (nonatomic, copy, nullable) PPVoidHandler onTapDelete;
@property (nonatomic, copy, nullable) PPVoidHandler onTapAdd; // "+" initial tap
@property (nonatomic, copy, nullable) PPQuantityChangedHandler onQuantityChanged;
- (void)addParallaxToView:(UIView *)view intensity:(CGFloat)intensity;
- (void)addLiquidGlassBorderToView:(UIView *)view ;
- (void)tapShare;
- (void)tapDelete;
 @end

NS_ASSUME_NONNULL_END

















@interface UIButton (Style)

/// Applies a frosted glass effect background to the button.
/// @param radius Corner radius for rounded edges.
/// @param style UIBlurEffectStyle (e.g. UIBlurEffectStyleSystemThinMaterial, UIBlurEffectStyleSystemMaterialLight, etc.)
/// @param tint Optional overlay tint (pass nil for none).
- (void)applyGlassStyleWithCornerRadius:(CGFloat)radius
                                  style:(UIBlurEffectStyle)style
                            tintOverlay:(nullable UIColor *)tint;

-(void)setTitleForAllState:(nullable NSString *)title textColor:(nullable UIColor *)textColor bgColor:(nullable UIColor *)bgColor font:(nullable UIFont *)font;

@end
