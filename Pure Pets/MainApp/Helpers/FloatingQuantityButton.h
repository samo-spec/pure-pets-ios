//
//  FloatingQuantityButton.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 30/06/2025.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, FromView)
{
    FromViewCart = 1,
    FromViewAdsCells = 2
};

NS_ASSUME_NONNULL_BEGIN

@interface FloatingQuantityButton : UIView
@property (nonatomic, strong) UIButton *singleButton;
@property (nonatomic, assign) NSInteger quantity;
@property (nonatomic, copy, nullable) void (^onQuantityChanged)(NSInteger newQuantity); // ✅ This is the key
@property (nonatomic, strong) UILabel *quantityLabel;
- (void)reset;
@property (nonatomic, assign) NSInteger autoShowHide;
- (void)showStepper;
- (void)dismissStepper;
@property (nonatomic, strong) UIViewController *ParentVC;
@property (nonatomic, assign) FromView fromView;
@end

NS_ASSUME_NONNULL_END
