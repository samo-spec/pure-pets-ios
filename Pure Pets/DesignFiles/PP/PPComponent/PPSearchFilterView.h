#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PPSearchFilterView;

@protocol PPSearchFilterViewDelegate <NSObject>
@optional
- (void)searchFilterView:(PPSearchFilterView *)view didSelectFilters:(NSDictionary<NSString *, id> *)filters;
- (void)searchFilterViewDidReset:(PPSearchFilterView *)view;
@end

@interface PPSearchFilterView : UIView
@property (nonatomic, weak) id<PPSearchFilterViewDelegate> delegate;
@property (nonatomic, assign, readonly) BOOL hasContent;

- (void)addSectionWithTitle:(NSString *)title items:(NSArray<NSDictionary *> *)items key:(NSString *)key allowMultiple:(BOOL)allowMultiple;
- (void)addResetButtonWithTitle:(NSString *)title;
- (NSDictionary<NSString *, id> *)activeFilters;
- (void)applySelectedFilters:(NSDictionary<NSString *, id> *)filters notify:(BOOL)notify;
- (void)resetAll;
- (void)removeAllSections;
@end

NS_ASSUME_NONNULL_END
