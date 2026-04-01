//
//  PPInfoPill.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 15/01/2026.
//


#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPInfoPill : NSObject
@property (nonatomic, copy,nullable ) NSString *iconName;
@property (nonatomic, copy) NSString *text;

+ (instancetype)itemWithIcon:(nullable NSString *)icon
                         text:(NSString *)text;
@end

@interface PPInfoPillsView : UIView

- (instancetype)initWithItems:(NSArray<PPInfoPill *> *)items;

@end

NS_ASSUME_NONNULL_END
