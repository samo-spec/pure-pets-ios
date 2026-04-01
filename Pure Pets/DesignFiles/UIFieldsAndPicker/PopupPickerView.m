//
//  PopupPickerView.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 06/02/2025.
//


#import "PopupPickerView.h"

@interface PopupPickerView ()

@property (nonatomic, strong) UIView *containerView; // To hold picker and toolbar
@property (nonatomic, assign) CGRect originalFrame;

@end

@implementation PopupPickerView

#pragma mark - Initialization

- (instancetype)initWithDataArray:(NSArray *)dataArray completion:(void (^)(NSString *selectedValue))completion {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _dataArray = dataArray;
        _completionBlock = completion;
        [self setupUI];
    }
    return self;
}


#pragma mark - UI Setup

- (void)setupUI {
    // Set background to translucent
    self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    self.frame = [UIScreen mainScreen].bounds; // Cover the whole screen
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    // Create container view
    self.containerView = [[UIView alloc] init];
    self.containerView.backgroundColor = [UIColor whiteColor];
    self.containerView.layer.cornerRadius = 5.0;
    self.containerView.clipsToBounds = YES;
    [self addSubview:self.containerView];

    // Create toolbar
    self.toolbar = [[UIToolbar alloc] init];
    self.toolbar.barStyle = UIBarStyleDefault;
    self.toolbar.translucent = YES;
    [self.containerView addSubview:self.toolbar];

    // Create pickerView
    self.pickerView = [[UIPickerView alloc] init];
    self.pickerView.delegate = self;
    self.pickerView.dataSource = self;
    self.pickerView.showsSelectionIndicator = YES;
    [self.containerView addSubview:self.pickerView];


    // Add buttons to the toolbar
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                  target:self
                                                                                  action:@selector(cancelButtonPressed:)];
    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                                   target:nil
                                                                                   action:nil];
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                target:self
                                                                                action:@selector(doneButtonPressed:)];

    self.toolbar.items = @[cancelButton, flexibleSpace, doneButton];


    // Add tap gesture recognizer to dismiss when tapping outside
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    tapGesture.delegate = (id<UIGestureRecognizerDelegate>)self; // Add delegate
    [self addGestureRecognizer:tapGesture];

    [self updateConstraintsIfNeeded];
}



- (void)updateConstraintsIfNeeded {
    [self.containerView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.toolbar setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.pickerView setTranslatesAutoresizingMaskIntoConstraints:NO];

    NSDictionary *views = @{
        @"containerView": self.containerView,
        @"toolbar": self.toolbar,
        @"pickerView": self.pickerView
    };

    NSDictionary *metrics = @{
        @"toolbarHeight": @44,
        @"pickerHeight": @216
    };



    // Container View Constraints
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[containerView]-|" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[containerView(>=toolbarHeight+pickerHeight)]-|" options:0 metrics:metrics views:views]];


    // Toolbar Constraints
    [self.containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[toolbar]|" options:0 metrics:nil views:views]];
    [self.containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[toolbar(toolbarHeight)]" options:nil metrics:metrics views:views]];

    // Picker View Constraints
    [self.containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[pickerView]|" options:0 metrics:nil views:views]];
    [self.containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[toolbar][pickerView(pickerHeight)]|" options:0 metrics:metrics views:views]];
}


#pragma mark - Actions

- (void)cancelButtonPressed:(UIBarButtonItem *)sender {
    [self dismissPopup];
}

- (void)doneButtonPressed:(UIBarButtonItem *)sender {
    NSInteger selectedRow = [self.pickerView selectedRowInComponent:0];
    NSString *selectedValue = self.dataArray[selectedRow];

    if (self.completionBlock) {
        self.completionBlock(selectedValue);
    }

    [self dismissPopup];
}


- (void)handleTap:(UITapGestureRecognizer *)recognizer {
  // Dismiss popup only if tap is outside the containerView
  CGPoint tapLocation = [recognizer locationInView:self];
  if (!CGRectContainsPoint(self.containerView.frame, tapLocation)) {
    [self dismissPopup];
  }
}


#pragma mark - Picker View Delegate & Data Source

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return self.dataArray.count;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    return self.dataArray[row];
}


#pragma mark - Show / Hide Methods

- (void)showInView:(UIView *)view {
    self.alpha = 0.0; // Start invisible
    [view addSubview:self];

    // Store original frame
    self.originalFrame = self.containerView.frame;

    //Initial container position (offscreen)
    CGRect containerFrame = self.containerView.frame;
    containerFrame.origin.y = self.frame.size.height;
    self.containerView.frame = containerFrame;

    [UIView animateWithDuration:0.3
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         self.alpha = 1.0;
                         //Animate container up
                        self.containerView.frame = self.originalFrame;


                     }
                     completion:nil];


}

- (void)dismissPopup {
    [UIView animateWithDuration:0.3
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         self.alpha = 0.0;

                         //Animate container down offscreen
                         CGRect containerFrame = self.containerView.frame;
                         containerFrame.origin.y = self.frame.size.height;
                         self.containerView.frame = containerFrame;


                     }
                     completion:^(BOOL finished) {
                         [self removeFromSuperview];
                     }];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    // Prevent gesture recognizer from firing when touch is inside the containerView
    if ([touch.view isDescendantOfView:self.containerView]) {
        return NO;
    }
    return YES;
}


@end


// Example usage in a UIViewController:

//In your .h file
//@property (nonatomic, strong) PopupPickerView *popupPicker;

// In your .m file
// somewhere in your implementation

// Example data array:
//NSArray *pickerData = @[@"Option 1", @"Option 2", @"Option 3", @"Option 4"];

//Creating the picker:
//self.popupPicker = [[PopupPickerView alloc] initWithDataArray:pickerData completion:^(NSString *selectedValue) {
//  NSLog(@"Selected Value: %@", selectedValue);
//   // Do something with the selected value here.  Update a label, etc.
//}];

//Showing the picker:
//[self.popupPicker showInView:self... (The response was truncated because it has reached the token limit. Try to increase the token limit if you need a longer response.)
