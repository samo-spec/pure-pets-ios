//
//  PPHomeLocationSheetViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/11/26.
//

NS_ASSUME_NONNULL_BEGIN
@interface PPHomeLocationActionCard : UIControl
- (void)configureWithTitle:(NSString *)title
                  subtitle:(nullable NSString *)subtitle
                  iconName:(nullable NSString *)iconName
                 tintColor:(UIColor *)tintColor
               showsChevron:(BOOL)showsChevron;
@end

@interface PPHomeLocationSheetViewController : UIViewController

@property (nonatomic, copy) NSString *sheetTitleText;
@property (nonatomic, copy) NSString *sheetSubtitleText;
@property (nonatomic, copy) NSString *currentLocationTitle;
@property (nonatomic, copy) NSString *currentLocationSubtitle;
@property (nonatomic, assign) BOOL showsUseCurrentLocationAction;
@property (nonatomic, assign) BOOL showsOpenSettingsAction;
@property (nonatomic, copy) NSArray<NSDictionary *> *recentLocations;
@property (nonatomic, copy, nullable) dispatch_block_t onUseCurrentLocation;
@property (nonatomic, copy, nullable) dispatch_block_t onChangeArea;
@property (nonatomic, copy, nullable) dispatch_block_t onOpenSettings;
@property (nonatomic, copy, nullable) void (^onSelectRecentLocation)(NSDictionary *locationRecord);

@end
NS_ASSUME_NONNULL_END
