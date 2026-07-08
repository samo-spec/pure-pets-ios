//
//  PPEmptyStateConfig.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 13/08/2025.
//


// PPEmptyStateHelper.m
#import "PPEmptyStateHelper.h"
#import <objc/runtime.h>
#import "EmptyStateView.h"

static const void *kPPEmptyStateAssociatedKey = &kPPEmptyStateAssociatedKey;
static const void *kPPEmptyStateTokenKey = &kPPEmptyStateTokenKey;

@implementation PPEmptyStateConfig
@end

@implementation PPEmptyStateHelper



+ (void)updateEmptyStateForListView:(UICollectionView *)listView
                          dataCount:(NSInteger)count
                             config:(PPEmptyStateConfig *)config
{
    // 🔒 Invalidate previous pending updates immediately
    NSNumber *token = objc_getAssociatedObject(listView, kPPEmptyStateTokenKey);
    NSInteger newToken = token.integerValue + 1;

    objc_setAssociatedObject(listView,
                             kPPEmptyStateTokenKey,
                             @(newToken),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    void (^applyBlock)(void) = ^{
        // ❌ Cancel if a newer update exists
        NSNumber *currentToken =
        objc_getAssociatedObject(listView, kPPEmptyStateTokenKey);

        if (currentToken.integerValue != newToken) {
            return;
        }

        EmptyStateView *empty =
        objc_getAssociatedObject(listView, kPPEmptyStateAssociatedKey);

        if (count == 0) {

            if (!empty) {
                CGRect frame = listView.bounds;
                empty = [[EmptyStateView alloc] initWithFrame:frame
                                               animationNamed:config.animationName ?: @"404.json"
                                                        title:config.title ?: @""
                                                     subTitle:config.subTitle
                                                  buttonTitle:config.buttonTitle ?: @""
                                                       target:config.target
                                                isNetworkFile:config.isNetworkFile
                                                       action:config.action];

                empty.autoresizingMask =
                UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                empty.reloadButton.alpha = 1.0;

                objc_setAssociatedObject(listView,
                                         kPPEmptyStateAssociatedKey,
                                         empty,
                                         OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }

            // Refresh content in case config changed while remaining empty
            empty.titleLabel.text = config.title ?: @"";
            empty.subTitleLabel.text = config.subTitle ?: @"";
            BOOL hasSubtitle = (config.subTitle.length > 0);
            empty.subTitleLabel.hidden = !hasSubtitle;

            if (empty.reloadButton) {
                NSString *buttonTitle = config.buttonTitle ?: @"";
                [empty setReloadButtonTitle:buttonTitle];
                empty.reloadButton.hidden = (buttonTitle.length == 0);
                [empty.reloadButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
                if (buttonTitle.length > 0 && config.target && config.action) {
                    [empty.reloadButton addTarget:config.target
                                           action:config.action
                                 forControlEvents:UIControlEventTouchUpInside];
                }
            }

            if ([listView respondsToSelector:@selector(setBackgroundView:)]) {
                [(id)listView setBackgroundView:empty];
            } else {
                if (!empty.superview) { [listView addSubview:empty]; }
                empty.frame = listView.bounds;
            }

        } else {

            // ⚡ Immediate removal when data exists
            if ([listView respondsToSelector:@selector(setBackgroundView:)]) {
                [(id)listView setBackgroundView:nil];
            } else {
                [empty removeFromSuperview];
            }

            objc_setAssociatedObject(listView,
                                     kPPEmptyStateAssociatedKey,
                                     nil,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    };

    if (count == 0) {
        // ⏱ Delay ONLY when empty
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                     (int64_t)(1.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(),
                       applyBlock);
    } else {
        // ⚡ No delay when data exists
        dispatch_async(dispatch_get_main_queue(), applyBlock);
    }
}



+ (void)updateEmptyState:(UICollectionView *)listView
                          Count:(NSInteger)count
                             config:(PPEmptyStateConfig *)config empty:(EmptyStateView *)empty
{
    if (!empty) {
        CGRect frame = listView.bounds;
        empty = [[EmptyStateView alloc] initWithFrame:frame
                                       animationNamed:config.animationName ?: @"404Color.json"
                                                title:config.title ?: @""
                                             subTitle:config.subTitle
                                          buttonTitle:config.buttonTitle ?: @""
                                               target:config.target
                                        isNetworkFile:config.isNetworkFile
                                               action:config.action ];
        empty.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        empty.reloadButton.alpha = 0; // match your current behavior
        objc_setAssociatedObject(listView, kPPEmptyStateAssociatedKey, empty, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    if ([listView respondsToSelector:@selector(setBackgroundView:)]) {
        // UITableView / UICollectionView
        [(id)listView setBackgroundView:empty];
    } else {
        // Fallback for generic views
        if (!empty.superview) { [listView addSubview:empty]; }
        empty.frame = listView.bounds;
    }
}

+ (void)removeEmptyStateFromListView:(UIView *)listView
{
    // Synchronously increment token to invalidate any pending delayed show blocks immediately
    NSNumber *token = objc_getAssociatedObject(listView, kPPEmptyStateTokenKey);
    NSInteger newToken = token.integerValue + 1;
    objc_setAssociatedObject(listView,
                             kPPEmptyStateTokenKey,
                             @(newToken),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    dispatch_async(dispatch_get_main_queue(), ^{
        if ([listView respondsToSelector:@selector(setBackgroundView:)]) {
            [(id)listView setBackgroundView:nil];
        }
        EmptyStateView *empty = objc_getAssociatedObject(listView, kPPEmptyStateAssociatedKey);
        [empty removeFromSuperview];
        objc_setAssociatedObject(listView, kPPEmptyStateAssociatedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    });
}

@end
