#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPModrenSegmrntedItem : NSObject

@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, copy, nullable, readonly) NSString *iconName;
@property (nonatomic, copy, nullable, readonly) NSString *selectedIconName;

+ (instancetype)itemWithTitle:(NSString *)title
                     iconName:(nullable NSString *)iconName
             selectedIconName:(nullable NSString *)selectedIconName;

- (instancetype)initWithTitle:(NSString *)title
                     iconName:(nullable NSString *)iconName
             selectedIconName:(nullable NSString *)selectedIconName NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

@interface PPModrenSegmrnted : UIControl

@property (nonatomic, copy) NSArray<PPModrenSegmrntedItem *> *items;
@property (nonatomic, assign) NSInteger selectedIndex;
@property (nonatomic, assign, readonly) NSInteger numberOfSegments;
@property (nonatomic, strong) UIColor *containerBackgroundColor;
@property (nonatomic, strong) UIColor *selectedSegmentColor;
@property (nonatomic, strong) UIColor *normalTextColor;
@property (nonatomic, strong) UIColor *selectedTextColor;
@property (nonatomic, strong) UIFont *normalFont;
@property (nonatomic, strong) UIFont *selectedFont;

- (instancetype)initWithItems:(NSArray<PPModrenSegmrntedItem *> *)items;
- (void)setSelectedIndex:(NSInteger)selectedIndex animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
