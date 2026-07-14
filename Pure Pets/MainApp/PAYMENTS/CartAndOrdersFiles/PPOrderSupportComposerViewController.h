//
//  PPOrderSupportComposerViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 7/14/26.
//
#import <UIKit/UIKit.h>
#import "OrderSupportFunc.h"

@class PPOrder;
@class PPOrderManager;

static NSString * const kOrderDetailsItemCellID = @"OrderItemCell";
static NSString * const kOrderDetailsPlaceholderCellID = @"OrderDetailsPlaceholderCell";
static CGFloat const kOrderDetailsHeaderCornerRadius = 22.0;
static CGFloat const kOrderDetailsButtonCornerRadius = 22.0;
static CGFloat const kOrderDetailsContentBottomInset = 132.0;

static CGFloat const kOrderDetailsSectionSpacing = 12.0;
static CGFloat const kOrderDetailsTopGlowRestingAlpha = 0.98;
static CGFloat const kOrderDetailsBottomGlowRestingAlpha = 0.96;
static NSString * const kOrderSupportPhoneNumber = @"+97459997720";
static NSInteger const kOrderSupportComposerMaxAttachments = 4;


static NSArray<NSDictionary *> *PPOrderSupportComposerItems(PPOrder *order)
{
    NSMutableArray<NSDictionary *> *items = [NSMutableArray array];
    for (id rawItem in order.items ?: @[]) {
        if ([rawItem isKindOfClass:NSString.class]) {
            NSString *itemID = [(NSString *)rawItem stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (itemID.length == 0) continue;
            [items addObject:@{
                @"id": itemID,
                @"name": itemID,
                @"quantity": @(1)
            }];
            continue;
        }
        if (![rawItem isKindOfClass:NSDictionary.class]) continue;
        NSDictionary *item = (NSDictionary *)rawItem;
        NSString *itemID = [item[@"id"] isKindOfClass:NSString.class] ? item[@"id"] : item[@"itemID"];
        if (![itemID isKindOfClass:NSString.class] || itemID.length == 0) continue;
        NSString *name = [item[@"name"] isKindOfClass:NSString.class] ? item[@"name"] : (item[@"title"] ?: itemID);
        NSInteger qty = [item[@"qty"] ?: item[@"quantity"] integerValue];
        [items addObject:@{
            @"id": itemID ?: @"",
            @"name": name ?: itemID ?: @"",
            @"quantity": @(MAX(1, qty))
        }];
    }
    return items.copy;
}


@interface PPOrderSupportComposerViewController : UIViewController
+ (instancetype)controllerWithOrder:(PPOrder *)order
                         actionType:(PPOrderCustomerActionType)actionType
                       orderManager:(PPOrderManager *)orderManager
                         onComplete:(dispatch_block_t)onComplete;
@end
