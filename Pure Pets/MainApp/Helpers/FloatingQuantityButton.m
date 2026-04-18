//
//  FloatingQuantityButton.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 30/06/2025.
//

//  FloatingQuantityButton.m
//  FloatingQuantityButton.m
#import "FloatingQuantityButton.h"
#import "AppManager.h"

@interface FloatingQuantityButton ()

@property (nonatomic, strong) UIView *stepperView;
@property (nonatomic, strong) UIButton *plusButton;
@property (nonatomic, strong) UIButton *minusButton;

@end

@implementation FloatingQuantityButton

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.quantity = 0;
        [self setupViews];
    }
    return self;
}

- (void)setupViews {
    UIColor *mainColor = GM.appPrimaryColor;
    UIColor *whiteColor = UIColor.whiteColor;
    
    float BTNHeight = self.bounds.size.height;
    
    // Single Button
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(12, 12, 12, 12);
        cfg.title = @"+";
        self.singleButton = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    } else {
        self.singleButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [self.singleButton setBackgroundColor:[[UIColor systemGrayColor]  colorWithAlphaComponent:0.5]];
         self.singleButton.layer.cornerRadius = 8;
        self.singleButton.clipsToBounds = YES;
         self.singleButton.layer.cornerRadius = BTNHeight/2;
        [self.singleButton pp_setShadowColor:GM.AppShadowColor];
        self.singleButton.layer.shadowOffset = CGSizeMake(0, 2);  // Horizontal & vertical offset
        self.singleButton.layer.shadowOpacity = 0.25;             // Opacity from 0 to 1
        self.singleButton.layer.shadowRadius = 2.0;
        [self.singleButton pp_setBorderColor:[GM.SecondaryTextColor colorWithAlphaComponent:0.2]];
        self.singleButton.layer.borderWidth = 1;
        
    }
    [self.singleButton addTarget:self action:@selector(showStepper) forControlEvents:UIControlEventTouchUpInside];
    self.singleButton.frame = CGRectMake(self.bounds.size.width - BTNHeight - 10, self.bounds.size.height - BTNHeight, BTNHeight, BTNHeight);
    [self.singleButton setTitle:@"+" forState:UIControlStateNormal];
    [self.singleButton setTitleColor:AppPrimaryTextClr forState:UIControlStateNormal];
    self.singleButton.titleLabel.font = [GM boldFontWithSize:18];;
    [self addSubview:self.singleButton];
    
    if(self.quantity == 0)
    {
        self.quantityLabel.text = [NSString stringWithFormat:@"+"];
     }
    else
    {
        self.quantityLabel.text = [NSString stringWithFormat:@"%ld", (long)self.quantity];
     }
        
  

    // Stepper View
    self.stepperView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, BTNHeight)];
    
    self.stepperView.alpha = 0;
    self.stepperView.transform = CGAffineTransformMakeScale(0.8, 0.8);
    self.stepperView.hidden = YES;
    [self addSubview:self.stepperView];

    // − Button
    // Single Button
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(12, 12, 12, 12);
        cfg.title = @"-";
        self.minusButton = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    } else {
        self.minusButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [self.minusButton setBackgroundColor:[UIColor systemGrayColor]];
         self.minusButton.layer.cornerRadius = 8;
        self.minusButton.clipsToBounds = YES;
        [self.minusButton setTitleColor:whiteColor forState:UIControlStateNormal];
    }
    self.minusButton.frame = CGRectMake(0, 0, BTNHeight, BTNHeight);
    [self.minusButton setTitle:@"−" forState:UIControlStateNormal];
    [self.minusButton addTarget:self action:@selector(decreaseQuantity) forControlEvents:UIControlEventTouchUpInside];
    [self.stepperView addSubview:self.minusButton];

    // Quantity Label
    self.quantityLabel = [[UILabel alloc] initWithFrame:CGRectMake(BTNHeight, 0, self.hx_w - (BTNHeight*2), BTNHeight)];
    self.quantityLabel.text = @"0";
    self.quantityLabel.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.8];
    self.quantityLabel.layer.cornerRadius = 12;
    self.quantityLabel.clipsToBounds = YES;
    self.quantityLabel.textColor = AppPrimaryTextClr;
    self.quantityLabel.textAlignment = NSTextAlignmentCenter;
    self.quantityLabel.font = [GM boldFontWithSize:16];
    [self.stepperView addSubview:self.quantityLabel];

    // + Button
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(8, 8, 8, 8);
        cfg.title = @"+";
        self.plusButton = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    } else {
        self.plusButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [self.plusButton setBackgroundColor:[UIColor systemGrayColor]];
         self.plusButton.layer.cornerRadius = 8;
        self.plusButton.clipsToBounds = YES;
         [self.plusButton setTitleColor:whiteColor forState:UIControlStateNormal];

    }
    
    self.plusButton.frame = CGRectMake(self.bounds.size.width - BTNHeight, 0, BTNHeight, BTNHeight);
    [self.plusButton setTitle:@"+" forState:UIControlStateNormal];
    [self.plusButton addTarget:self action:@selector(increaseQuantity) forControlEvents:UIControlEventTouchUpInside];
    [self.stepperView addSubview:self.plusButton];

    // Tap outside dismiss
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissStepper)];
    tap.cancelsTouchesInView = NO;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(registerTapDismiss:) name:@"FloatingQuantityButtonAddDismiss" object:nil];
    
}

-(void)layoutSubviews
{
    [super layoutSubviews];
}
- (void)registerTapDismiss:(NSNotification *)note {
    NSLog(@"Quantity: registerTapDismiss");
    UIView *parent = note.object;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissStepper)];
    tap.cancelsTouchesInView = NO;
    [parent addGestureRecognizer:tap];
}

- (void)showStepper {
    
    if(!UserManager.sharedManager.isUserLoggedIn) { [UserManager showPromptOnTopController]; return; }
    
    if (self.quantity == 0) {
        self.quantity = 1;
        self.quantityLabel.text = @"1";
        [self.singleButton setTitle:@"1" forState:UIControlStateNormal];
        if (self.onQuantityChanged) self.onQuantityChanged(self.quantity);
    }
    
    
    UIColor *mainColor = GM.appPrimaryColor;
    if(self.quantity > 0)
    {
        self.singleButton.backgroundColor = [mainColor colorWithAlphaComponent:0.5];
    }
    else
    {
        self.singleButton.backgroundColor = [GM.SecondaryTextColor colorWithAlphaComponent:0.5];
    }
        
    NSLog(@"Quantity: showStepper");
    self.singleButton.hidden = YES;
    self.stepperView.hidden = NO;
    self.stepperView.alpha = 0;
    self.stepperView.transform = CGAffineTransformMakeScale(0.8, 0.8);
    [UIView animateWithDuration:0.2 animations:^{
        self.stepperView.alpha = 1;
        self.stepperView.transform = CGAffineTransformIdentity;
    }];
    
    
}

- (void)dismissStepper {
    NSLog(@"Quantity: dismissStepper");
    [UIView animateWithDuration:0.2 animations:^{
        self.stepperView.alpha = 0;
        self.stepperView.transform = CGAffineTransformMakeScale(0.8, 0.8);
    } completion:^(BOOL finished) {
        self.stepperView.hidden = YES;
        self.singleButton.hidden = NO;
    }];
    
    UIColor *mainColor = GM.appPrimaryColor;
    if(self.quantity > 0)
    { self.singleButton.backgroundColor = [mainColor colorWithAlphaComponent:0.5]; }
    else
    { self.singleButton.backgroundColor = [GM.SecondaryTextColor colorWithAlphaComponent:0.5]; }
}

- (void)increaseQuantity {
    
    if(!UserManager.sharedManager.isUserLoggedIn) {  return; }
    
    NSLog(@"Quantity: increaseQuantity");
    self.quantity++;
    self.quantityLabel.text = [NSString stringWithFormat:@"%ld", (long)self.quantity];
    [self.singleButton setTitle:self.quantityLabel.text forState:UIControlStateNormal];
    if (self.onQuantityChanged) self.onQuantityChanged(self.quantity);
    
    if(_autoShowHide == 1)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // Code to execute after 1 second delay
        NSLog(@"This executes after 1 second");
        [self dismissStepper];
    });
    
    UIColor *mainColor = GM.appPrimaryColor;
    if(self.quantity > 0)
    { self.singleButton.backgroundColor = [mainColor colorWithAlphaComponent:0.5]; }
    else
    { self.singleButton.backgroundColor = [GM.SecondaryTextColor colorWithAlphaComponent:0.5]; }
}

- (void)decreaseQuantity {
    NSLog(@"Quantity: reset");
    if (self.quantity > 1) {
        self.quantity--;
        self.quantityLabel.text = [NSString stringWithFormat:@"%ld", (long)self.quantity];
        [self.singleButton setTitle:self.quantityLabel.text forState:UIControlStateNormal];
        if (self.onQuantityChanged) self.onQuantityChanged(self.quantity);
    }  else {
        self.quantity = 0;
        self.quantityLabel.text = @"+";
        [self.singleButton setTitle:@"+" forState:UIControlStateNormal];
        if (self.onQuantityChanged) self.onQuantityChanged(self.quantity);
        [self dismissStepper];
    }
    
    if(_autoShowHide == 1)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // Code to execute after 1 second delay
        NSLog(@"This executes after 1 second");
        [self dismissStepper];
    });
    
    UIColor *mainColor = GM.appPrimaryColor;
    if(self.quantity > 0)
    { self.singleButton.backgroundColor = [mainColor colorWithAlphaComponent:0.5]; }
    else
    { self.singleButton.backgroundColor = [GM.SecondaryTextColor colorWithAlphaComponent:0.5]; }
}

- (void)reset {
    NSLog(@"Quantity: reset");
    self.quantity = 0;
    self.quantityLabel.text = @"+";
    [self.singleButton setTitle:@"+" forState:UIControlStateNormal];
    [self dismissStepper];
}

@end

/*
i want to fix those points
* frist time press on + show stepper with "1" value
* when decrease to 0 dismiss Stepper and show "+" on single button

dont change anything else
*/
