//
//  PPDefaultLocationView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 01/11/2025.
//

#import <UIKit/UIKit.h>
#import "AddressFormVC.h"
@class PPAddressModel;
typedef NS_ENUM(NSInteger, PPLocatioViewKind) {
    PPLocatioViewKindLocation,
    PPLocatioViewKindLocationAndUserData,
    PPLocatioViewKindLocationUncollapseable,
};

NS_ASSUME_NONNULL_BEGIN

typedef void(^PPDefaultLocationChangeBlock)(void);

@interface PPDefaultLocationView : UIButton<AddressFormVCDelegate>
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *originalConstraints;

@property (nonatomic, assign) PPLocatioViewKind locatioViewKind;

/// The main label showing the current delivery location
@property (nonatomic, strong, readonly) UILabel *locationLabel;

/// Called when user taps the "change" area or button
@property (nonatomic, copy, nullable) PPDefaultLocationChangeBlock onChangeTapped;

/// Updates the displayed location text
- (void)setLocationText:(NSString *)text;

/// Convenience initializer with callback
- (instancetype)initWithPPLocatioViewKind:(PPLocatioViewKind)kind  width:(CGFloat)width ChangeHandler:(PPDefaultLocationChangeBlock)onChange;
@property (nonatomic, assign) CGFloat viewWidth;
@property (nonatomic, assign) BOOL showToUserRow;
@property (nonatomic, assign) BOOL isExpanded;
@property (nonatomic, strong) UILabel *userNameLabel;
@property (nonatomic, strong) UILabel *mobileNoLabel;
@property (nonatomic, strong) NSLayoutConstraint *buttonWidth;
- (void)setExpanded:(BOOL)expanded;
- (void)toggleExpandCollapse;
- (void)buildContent;
@property (nonatomic, strong) NSMutableArray <PPAddressModel * > *_Nullable addresses;
@end

NS_ASSUME_NONNULL_END
