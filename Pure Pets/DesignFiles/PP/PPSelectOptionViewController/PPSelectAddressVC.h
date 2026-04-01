#import <UIKit/UIKit.h>
#import "PPSelectOptionViewController.h"

@class XLFormRowDescriptor;

NS_ASSUME_NONNULL_BEGIN

@interface PPSelectAddressVC : UITableViewController <UISearchBarDelegate>

@property (nonatomic, weak) UIViewController *parentForm;
@property (nonatomic, weak) XLFormRowDescriptor *rowDescriptor;
@property (nonatomic, assign) BOOL imageLoaded;

@property (nonatomic, copy) NSArray *allOptions;
@property (nonatomic, copy) NSArray *filteredOptions;
@property (nonatomic, strong, nullable) id selectedOption;

@property (nonatomic, assign) BOOL showSearchBar;
@property (nonatomic, assign) PPSelectOptionPresentationStyle presentationStyle;
@property (nonatomic, strong, nullable) UIView *searchContainer;

@property (nonatomic, copy, nullable) PPSelectOptionBlock onSelectOption;

- (instancetype)initWithCompletion:(PPSelectOptionBlock _Nullable)completion;
- (instancetype)initWithOptions:(NSArray *)options
                          title:(NSString *)title
                            row:(XLFormRowDescriptor *_Nullable)row
               presentationStyle:(PPSelectOptionPresentationStyle)style
                     completion:(PPSelectOptionBlock _Nullable)completion;
- (instancetype)initWithOptions:(NSArray *)options
                          title:(NSString *)title
                            row:(XLFormRowDescriptor *_Nullable)row
               presentationStyle:(PPSelectOptionPresentationStyle)style
                  showSearchBar:(BOOL)showSearchBar
                     completion:(PPSelectOptionBlock _Nullable)completion;

@end

NS_ASSUME_NONNULL_END
