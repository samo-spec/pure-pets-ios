//
//  PopupPickerView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 06/02/2025.
//

@interface PopupPickerView : UIView <UIPickerViewDelegate, UIPickerViewDataSource>

@property (nonatomic, strong) UIPickerView *pickerView;
@property (nonatomic, strong) UIToolbar *toolbar;
@property (nonatomic, strong) NSArray *dataArray;
@property (nonatomic, copy) void (^completionBlock)(NSString *);

// Designated initializer
- (instancetype)initWithDataArray:(NSArray *)dataArray completion:(void (^)(NSString *selectedValue))completion;

// Method to show the popup
- (void)showInView:(UIView *)view;

// Method to dismiss the popup
- (void)dismissPopup;

@end
