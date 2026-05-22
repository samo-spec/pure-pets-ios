//
//  ViewerVC.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/05/2025.
//

#import "XLFormViewController.h"
 
NS_ASSUME_NONNULL_BEGIN

@protocol CartQuantityFromViewerDelegate <NSObject>
-(void)updateCartAndReloadCollection;
@end

@interface AccessViewerVC : UIViewController
@property (nonatomic, strong) PetAccessory *accessAds;
//@property (weak, nonatomic) IBOutlet UILabel *adTitleLabel;
//@property (weak, nonatomic) IBOutlet UIButton *favoriteButton;

//@property ( nonatomic) UILabel *priceLabel;
@property ( nonatomic) UILabel *mayLikeLabel;
@property (nonatomic, strong) UIViewController *ParentVC;
//@property(nonatomic, strong) PKYStepper *plainStepper;
//@property (nonatomic, weak) id <StepperDelegate> delegate;
@property (nonatomic, weak) id <CartQuantityFromViewerDelegate> QtyDelegate;

@end

NS_ASSUME_NONNULL_END














@class PetAccessory;

NS_ASSUME_NONNULL_BEGIN

@interface PPAccessoryDescriptionView : UIView

/// Set this to show the accessory description.
@property (nonatomic, strong, nullable) PetAccessory *accessory;

/// Readonly UITextView for advanced customization.
@property (nonatomic, strong, readonly) UITextView *textView;

/// Optional text if you’re not binding to a model.
@property (nonatomic, copy, nullable) NSString *descriptionText;

/// Host scroll view — used to keep scroll position stable when expanding/collapsing.
@property (nonatomic, weak, nullable) UIScrollView *hostScrollView;

- (void)handleShareAction;

@end

NS_ASSUME_NONNULL_END
