//
//  BottomOptionsViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 10/07/2025.
//


#import <UIKit/UIKit.h>
#import "OptionModel.h"
#import "OptionTableViewCell.h"

typedef NS_ENUM(NSInteger, PPOptionsType)
{
    PPOptionsTypeNormal = 1,
    PPOptionsTypeAddressTitles = 2
};


@class OptionModel;

typedef void (^BottomOptionSelectionHandler)(OptionModel *selectedOption);
typedef void (^AddressTitleSelectionHandler)(OptionModel *selectedAddressTitle);

@interface BottomOptionsViewController : UIViewController

- (instancetype)initWithTableStyle:(UITableViewStyle)style; // NEW

@property (nonatomic, strong, readonly) UITableView *tableView;
@property (nonatomic, copy)   NSString *jsonAnimationName;
@property (nonatomic, copy)   NSString *sheetTitle;
@property (nonatomic, copy)   NSString *sheetSubtitle;
@property (nonatomic, copy)   NSArray<OptionModel *> *options;

// New property for header animation
@property (nonatomic, strong) LOTAnimationView *headerAnimation;
@property (nonatomic, strong) UIImageView *headerImageView;

@property (nonatomic, copy) void (^selectionHandler)(OptionModel *selectedOption);
@property (nonatomic, copy) void (^AddressTitleSelectionHandler)(PPAddressModel *selectedAddress);

@property (nonatomic, strong) UIView *containerView;      // the sheet card
@property (nonatomic, strong) UIView *grabber;
@property (nonatomic, strong) UIPanGestureRecognizer *pan;
@property (nonatomic, strong) NSLayoutConstraint *containerBottomC;
@property (nonatomic, strong) NSLayoutConstraint *containerH;

@property (nonatomic, copy)   NSArray<PPAddressModel *> *AddressessArray;

@property (nonatomic, assign) PPOptionsType optionsType;
@end
