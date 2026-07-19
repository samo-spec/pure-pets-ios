//
//  PPFloatingSearchAccessoryView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 06/01/2026.
//


@interface PPFloatingSearchAccessoryView : UIView

@property (nonatomic, strong, readonly) UITextField *textField;
@property (nonatomic, copy) void (^onCancel)(void);

@end