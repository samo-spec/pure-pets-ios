//
//  PPMenuHelper.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 12/12/2025.
//


//  PPMenuHelper.m
//  Pure Pets
//
//  Created by ChatGPT on __DATE__.
//

#import "PPMenuHelper.h"
#import <objc/runtime.h>

@interface UIAction (PPMenuHelperActionTitleFont)
+ (instancetype)pp_purepets_actionWithTitle:(NSString *)title
                                      image:(UIImage *)image
                                 identifier:(UIActionIdentifier)identifier
                                    handler:(void (^)(__kindof UIAction *action))handler;
@end

static BOOL PPMenuHelperShouldSkipAutoFontForCurrentMenuAction(void) {
    NSArray<NSString *> *symbols = [NSThread callStackSymbols];
    for (NSString *symbol in symbols) {
        if ([symbol containsString:@"PPHomeViewController"] &&
            [symbol containsString:@"pp_buildProfileMenuElements"]) {
            return YES;
        }
    }
    return NO;
}

static void PPMenuHelperApplyMenuActionTitleFont(UIAction *action) {
    if (!action) return;

    NSString *title = action.title ?: @"";
    if (title.length == 0) return;

    UIFont *font = MenuActionTitleFont ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
    NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:title
                                                                           attributes:@{
        NSFontAttributeName: font
    }];
    @try {
        [action setValue:attributedTitle forKey:@"attributedTitle"];
    } @catch (__unused NSException *exception) {
    }
}

static void PPMenuHelperApplyMenuActionStyle(UIAction *action, UIFont *font, UIColor *color) {
    if (!action) return;

    NSString *title = action.title ?: @"";
    if (title.length == 0) return;

    NSMutableDictionary<NSAttributedStringKey, id> *attributes = [NSMutableDictionary dictionary];
    attributes[NSFontAttributeName] = font ?: MenuActionTitleFont ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
    if (color) {
        attributes[NSForegroundColorAttributeName] = color;
    }

    NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:title
                                                                           attributes:attributes];
    @try {
        [action setValue:attributedTitle forKey:@"attributedTitle"];
    } @catch (__unused NSException *exception) {
    }
}

@implementation UIAction (PPMenuHelperActionTitleFont)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method originalMethod = class_getClassMethod(self, @selector(actionWithTitle:image:identifier:handler:));
        Method swizzledMethod = class_getClassMethod(self, @selector(pp_purepets_actionWithTitle:image:identifier:handler:));
        if (originalMethod && swizzledMethod) {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}

+ (instancetype)pp_purepets_actionWithTitle:(NSString *)title
                                      image:(UIImage *)image
                                 identifier:(UIActionIdentifier)identifier
                                    handler:(void (^)(__kindof UIAction *action))handler
{
    UIAction *action = [self pp_purepets_actionWithTitle:title
                                                   image:image
                                              identifier:identifier
                                                 handler:handler];
    if (!PPMenuHelperShouldSkipAutoFontForCurrentMenuAction()) {
        PPMenuHelperApplyMenuActionTitleFont(action);
    }
    return action;
}

@end

@implementation PPMenuHelper

#pragma mark - Helpers

+ (NSArray<UIAction *> *)makeActionsFromTitles:(NSArray<NSString *> *)titles
                                       images:(NSArray<UIImage *> * _Nullable)images
                                 destructive:(NSIndexSet * _Nullable)destructiveIndexes
                                     handler:(PPMenuHandler)handler
{
    NSMutableArray<UIAction *> *actions = [NSMutableArray arrayWithCapacity:titles.count];
    for (NSInteger i = 0; i < titles.count; i++) {
        NSString *t = titles[i];
        UIImage *img = (images && i < images.count) ? images[i] : nil;
        BOOL isDestructive = (destructiveIndexes && [destructiveIndexes containsIndex:i]);
        
        UIAction *action = [UIAction actionWithTitle:t
                                               image:img
                                          identifier:nil
                                             handler:^(__kindof UIAction * _Nonnull act) {
            if (handler) handler(i, t);
        }];

        if (isDestructive) {
            action.attributes = UIMenuElementAttributesDestructive;
        }

        [actions addObject:action];        
    }
    return actions;
}

#pragma mark - Bar Button Item
 
+ (void)presentMenuFromBarButtonItem:(UIBarButtonItem *)barButtonItem
                              titles:(NSArray<NSString *> *)titles
                              images:(NSArray<UIImage *> * _Nullable)images
                        destructive:(NSIndexSet * _Nullable)destructiveIndexes
                            handler:(PPMenuHandler)handler
{
    if (@available(iOS 14.0, *)) {
        NSArray<UIAction *> *actions = [self makeActionsFromTitles:titles images:images destructive:destructiveIndexes handler:handler];
        UIMenu *menu = [UIMenu menuWithTitle:@"" children:actions];
        barButtonItem.menu = menu;
        // The menu will be shown when the user taps the bar button item.
        // If you need to present immediately you must trigger the bar button's action in context of the app UI.
    } else {
        // Fallback: nothing to attach; present via alert on top controller
        UIViewController *top = [self topViewController];
        [self presentActionSheetFromViewController:top sourceView:top.view titles:titles images:images destructive:destructiveIndexes handler:handler];
    }
}

#pragma mark - UIButton

+ (void)presentMenuFromButton:(UIButton *)button
                       titles:(NSArray<NSString *> *)titles
                       images:(NSArray<UIImage *> * _Nullable)images
                 destructive:(NSIndexSet * _Nullable)destructiveIndexes
                     handler:(PPMenuHandler)handler
{
    if (@available(iOS 14.0, *)) {
        NSArray<UIAction *> *actions = [self makeActionsFromTitles:titles images:images destructive:destructiveIndexes handler:handler];
        UIMenu *menu = [UIMenu menuWithTitle:@"" children:actions];
        button.menu = menu;
        button.showsMenuAsPrimaryAction = YES;

        // Attempt to present immediately
        // Sending primary action should open the menu when called from main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [button sendActionsForControlEvents:UIControlEventPrimaryActionTriggered];
        });
    } else {
        UIViewController *top = [self topViewController];
        [self presentActionSheetFromViewController:top sourceView:button titles:titles images:images destructive:destructiveIndexes handler:handler];
    }
}

+ (UIAction *)actionWithTitle:(NSString *)title
              systemImageName:(nullable NSString *)systemImageName
                         font:(nullable UIFont *)font
                        color:(nullable UIColor *)color
                      handler:(void (^)(UIAction *action))handler
{
    UIImage *icon = systemImageName.length ? [UIImage systemImageNamed:systemImageName] : [UIImage systemImageNamed:systemImageName] ?:  nil;
    
    UIAction *action = [UIAction actionWithTitle:title
                                           image:icon
                                      identifier:nil
                                         handler:^(__kindof UIAction * _Nonnull act) {
        if (handler) handler(act);
    }];
    PPMenuHelperApplyMenuActionStyle(action, font ?: MenuActionTitleFont, color);
    
    return action;
}

+ (void)presentMenuFromButton:(UIButton *)button
                       Menu:(UIMenu *)menu
                 destructive:(NSIndexSet * _Nullable)destructiveIndexes
                     handler:(PPMenuHandler)handler
{
    if (@available(iOS 14.0, *)) {
        button.menu = menu;
        button.showsMenuAsPrimaryAction = YES;

        // Attempt to present immediately
        // Sending primary action should open the menu when called from main thread
        //dispatch_async(dispatch_get_main_queue(), ^{
          // [button sendActionsForControlEvents:UIControlEventPrimaryActionTriggered];
        //});
    }
}

#pragma mark - Action Sheet Fallback

+ (void)presentActionSheetFromViewController:(UIViewController *)vc
                                  sourceView:(UIView *)sourceView
                                      titles:(NSArray<NSString *> *)titles
                                      images:(NSArray<UIImage *> * _Nullable)images
                                destructive:(NSIndexSet * _Nullable)destructiveIndexes
                                    handler:(PPMenuHandler)handler
{
    if (!vc) vc = [self topViewController];
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSInteger i = 0; i < titles.count; i++) {
        NSString *t = titles[i];
        BOOL isDestructive = destructiveIndexes && [destructiveIndexes containsIndex:i];
        UIAlertActionStyle style = isDestructive ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault;

        UIAlertAction *action = [UIAlertAction actionWithTitle:t style:style handler:^(UIAlertAction * _Nonnull _action) {
            if (handler) handler(i, t);
        }];
        [ac addAction:action];
    }

    [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:nil]];

    // iPad popover anchoring
    UIPopoverPresentationController *pc = ac.popoverPresentationController;
    if (pc) {
        pc.sourceView = sourceView ?: vc.view;
        // Place popover at center of source view if possible
        CGRect r = sourceView.bounds;
        pc.sourceRect = r.size.width > 0 && r.size.height > 0 ? CGRectMake(CGRectGetMidX(r), CGRectGetMidY(r), 1, 1) : CGRectMake(vc.view.bounds.size.width/2.0, vc.view.bounds.size.height/2.0, 1, 1);
        pc.permittedArrowDirections = UIPopoverArrowDirectionAny;
    }

    [vc presentViewController:ac animated:YES completion:nil];
}

+ (void)presentMenuFromViewController:(UIViewController *)vc
                            sourceView:(UIView *)sourceView
                                titles:(NSArray<NSString *> *)titles
                                images:(NSArray<UIImage *> * _Nullable)images
                          destructive:(NSIndexSet * _Nullable)destructiveIndexes
                              handler:(PPMenuHandler)handler
{
    if (!vc && sourceView) {
        UIResponder *responder = sourceView;
        while (responder) {
            responder = responder.nextResponder;
            if ([responder isKindOfClass:[UIViewController class]]) {
                vc = (UIViewController *)responder;
                break;
            }
        }
    }
    if (!vc) vc = [self topViewController];
    if (!vc) return;

    if (@available(iOS 14.0, *)) {
        UIView *hostView = sourceView ?: vc.view;
        if (!hostView) {
            [self presentActionSheetFromViewController:vc
                                            sourceView:vc.view
                                                titles:titles
                                                images:images
                                          destructive:destructiveIndexes
                                              handler:handler];
            return;
        }

        CGRect sourceRect = hostView.bounds;
        if (CGRectIsEmpty(sourceRect)) sourceRect = CGRectMake(0, 0, 2, 2);

        UIButton *anchor = [UIButton buttonWithType:UIButtonTypeSystem];
        anchor.frame = sourceRect;
        if (anchor.frame.size.width < 2.0) anchor.frame = CGRectMake(anchor.frame.origin.x, anchor.frame.origin.y, 2.0, MAX(anchor.frame.size.height, 2.0));
        if (anchor.frame.size.height < 2.0) anchor.frame = CGRectMake(anchor.frame.origin.x, anchor.frame.origin.y, MAX(anchor.frame.size.width, 2.0), 2.0);
        anchor.alpha = 1.0;
        anchor.backgroundColor = UIColor.clearColor;
        anchor.showsMenuAsPrimaryAction = YES;
        anchor.menu = [UIMenu menuWithTitle:@""
                                    children:[self makeActionsFromTitles:titles
                                                                   images:images
                                                             destructive:destructiveIndexes
                                                                 handler:handler]];

        [hostView addSubview:anchor];

        dispatch_async(dispatch_get_main_queue(), ^{
            [anchor sendActionsForControlEvents:UIControlEventPrimaryActionTriggered];
            [anchor sendActionsForControlEvents:UIControlEventTouchUpInside];
        });

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [anchor removeFromSuperview];
        });
    } else {
        [self presentActionSheetFromViewController:vc
                                        sourceView:sourceView ?: vc.view
                                            titles:titles
                                            images:images
                                      destructive:destructiveIndexes
                                          handler:handler];
    }
}

#pragma mark - Utility

+ (UIViewController *)topViewController {
    UIApplication *app = UIApplication.sharedApplication;
    UIViewController *vc = app.keyWindow.rootViewController;
    // walk presented / nav / tab
    while (vc.presentedViewController) vc = vc.presentedViewController;
    if ([vc isKindOfClass:[UINavigationController class]]) {
        return ((UINavigationController *)vc).topViewController;
    }
    if ([vc isKindOfClass:[UITabBarController class]]) {
        return ((UITabBarController *)vc).selectedViewController;
    }
    return vc;
}

@end
