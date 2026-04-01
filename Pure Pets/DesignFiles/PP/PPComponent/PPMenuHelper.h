//
//  PPMenuHelper.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 12/12/2025.
//


//  PPMenuHelper.h
//  Pure Pets
//
//  Created by ChatGPT on __DATE__.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^PPMenuHandler)(NSInteger index, NSString *title);

@interface PPMenuHelper : NSObject

/// Present UIMenu attached to a UIBarButtonItem. The menu will be shown automatically when the item is tapped.
/// If you need to present immediately, call this then programmatically trigger the item (or use the fallback).
+ (void)presentMenuFromBarButtonItem:(UIBarButtonItem *)barButtonItem
                              titles:(NSArray<NSString *> *)titles
                              images:(nullable NSArray<UIImage *> *)images
                        destructive:(nullable NSIndexSet *)destructiveIndexes
                            handler:(PPMenuHandler)handler;

/// Present UIMenu attached to a UIButton. This configures the button to show the menu as primary action.
/// If you want immediate show, the method sends a primary action event so the menu appears now.
+ (void)presentMenuFromButton:(UIButton *)button
                       titles:(NSArray<NSString *> *)titles
                       images:(nullable NSArray<UIImage *> *)images
                 destructive:(nullable NSIndexSet *)destructiveIndexes
                     handler:(PPMenuHandler)handler;

/// Present an action sheet anchored to a view (fallback). On iPad it uses popoverPresentationController.sourceView/sourceRect.
+ (void)presentActionSheetFromViewController:(UIViewController *)vc
                                   sourceView:(UIView *)sourceView
                                       titles:(NSArray<NSString *> *)titles
                                       images:(nullable NSArray<UIImage *> *)images
                                 destructive:(nullable NSIndexSet *)destructiveIndexes
                                     handler:(PPMenuHandler)handler;
/// Present a real UIMenu anchored to any source view.
/// Falls back to action sheet on iOS < 14.
+ (void)presentMenuFromViewController:(UIViewController *)vc
                            sourceView:(UIView *)sourceView
                                titles:(NSArray<NSString *> *)titles
                                images:(nullable NSArray<UIImage *> *)images
                          destructive:(nullable NSIndexSet *)destructiveIndexes
                              handler:(PPMenuHandler)handler;
+ (void)presentMenuFromButton:(UIButton *)button
                       Menu:(UIMenu *)menu
                 destructive:(NSIndexSet * _Nullable)destructiveIndexes
                      handler:(PPMenuHandler)handler;

+ (UIAction *)actionWithTitle:(NSString *)title
              systemImageName:(nullable NSString *)systemImageName
                         font:(nullable UIFont *)font
                        color:(nullable UIColor *)color
                      handler:(void (^)(UIAction *action))handler;
@end

NS_ASSUME_NONNULL_END
