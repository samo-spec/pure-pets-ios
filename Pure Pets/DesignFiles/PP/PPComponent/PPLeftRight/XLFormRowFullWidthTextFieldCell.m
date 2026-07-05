// TwoOptionRowCell.m

#import "XLFormRowFullWidthTextFieldCell.h"


 
NSString * const XLFormRowDescriptorTypeTwoOptions = @"TwoOptions";

@interface TwoOptionRowCell ()
@property (nonatomic, strong) UIButton *leftButton;
@property (nonatomic, strong) UIButton *rightButton;
@end

@implementation TwoOptionRowCell

+ (void)load {
    [XLFormViewController.cellClassesForRowDescriptorTypes
        setObject:[TwoOptionRowCell class]
        forKey:XLFormRowDescriptorTypeTwoOptions];
}

- (void)configure {
    [super configure];

    self.options = [@{@"left": @[], @"right": @[]} mutableCopy];

    self.selectionStyle = UITableViewCellSelectionStyleNone;

    self.leftButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.leftButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.leftButton addTarget:self action:@selector(leftTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.leftButton];

    self.rightButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.rightButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.rightButton addTarget:self action:@selector(rightTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.rightButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.leftButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12],
        [self.leftButton.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [self.leftButton.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8],
        [self.leftButton.trailingAnchor constraintEqualToAnchor:self.contentView.centerXAnchor constant:-6],

        [self.rightButton.leadingAnchor constraintEqualToAnchor:self.contentView.centerXAnchor constant:6],
        [self.rightButton.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [self.rightButton.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8],
        [self.rightButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
    ]];
}

- (void)update {
    [super update];
    [self reloadButtons];
}

- (void)reloadButtons {
    NSDictionary *value = self.rowDescriptor.value ?: @{};

    NSString *kind = value[@"kind"] ?: @"Select kind";
    NSString *ring = value[@"ringID"] ?: @"Select ring ID";

    [self.leftButton setTitle:kind forState:UIControlStateNormal];
    [self.rightButton setTitle:ring forState:UIControlStateNormal];
    NSArray *opts = self.options[@"right"];
    self.rightButton.enabled = @([opts count] > 0);
}

#pragma mark - Taps

- (void)leftTapped {
    NSArray *opts = self.options[@"left"];
    if (opts.count == 0) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"TwoOptionLeftRequest" object:self.rowDescriptor.tagM];
        return;
    }
    [self showPicker:opts title:@"Select kind" key:@"kind"];
}

- (void)rightTapped {
    NSArray *opts = self.options[@"right"];
    if (opts.count == 0) return;
    [self showPicker:opts title:@"Select ring ID" key:@"ringID"];
}

- (void)showPicker:(NSArray *)items title:(NSString *)title key:(NSString *)key {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSString *o in items) {
        [ac addAction:[UIAlertAction actionWithTitle:o style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSMutableDictionary *val = [self.rowDescriptor.value mutableCopy];
            if (!val) val = @{}.mutableCopy;
            val[key] = o;
            self.rowDescriptor.value = val;
            [self reloadButtons];

            // notify controller
            [[NSNotificationCenter defaultCenter] postNotificationName:@"TwoOptionValueChanged"
                                                                object:@{@"tag":self.rowDescriptor.tagM, @"key":key, @"value":o}];
        }]];
    }

    [ac addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    // iPad: actionSheet requires sourceView to avoid crash
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        ac.popoverPresentationController.sourceView = self;
        ac.popoverPresentationController.sourceRect = self.bounds;
    }
    [self.formViewController presentViewController:ac animated:YES completion:nil];
}

@end

// ParrotSelectorFormViewController.m














//
//  XLFormRowFullWidthTitleSubtitleAndImageCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 24/09/2025.
//
 
NSString * const XLFormRowFullWidthTitleSubtitleAndImage = @"XLFormRowFullWidthTitleSubtitleAndImageCell";

@implementation XLFormRowFullWidthTitleSubtitleAndImageCell

#pragma mark - Registration

+ (void)load {
    [XLFormViewController.cellClassesForRowDescriptorTypes setObject:[self class] forKey:XLFormRowFullWidthTitleSubtitleAndImage];
}

#pragma mark - Lifecycle

- (void)configure {
    [super configure];
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.contentView.backgroundColor = UIColor.clearColor;
    
    [self setupUI];
}

#pragma mark - UI Setup

- (void)setupUI {
    // 🔹 Title label
    self.titlelabel = [[UILabel alloc] init];
    self.titlelabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titlelabel.font = [GM MidFontWithSize:16];
    self.titlelabel.textColor = AppPrimaryTextClr;
    self.titlelabel.numberOfLines = 1;
    self.titlelabel.textAlignment = GM.setAligment;
    
    // 🔹 Subtitle label
    self.subTitlelabel = [[UILabel alloc] init];
    self.subTitlelabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subTitlelabel.font = [GM fontWithSize:14];
    self.subTitlelabel.textColor = UIColor.secondaryLabelColor;
    self.subTitlelabel.numberOfLines = 1;
    self.subTitlelabel.textAlignment = GM.setAligment;
    
    // 🔹 Optional icon
    UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectZero];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleToFill;
    iconView.clipsToBounds = YES;
    
    // 🔹 StackView for title & subtitle
    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.titlelabel, self.subTitlelabel]];
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.alignment = UIStackViewAlignmentFill;
    textStack.spacing = 5.0;
    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 🔹 Holder for icon + text
    UIStackView *mainStack = [[UIStackView alloc] initWithArrangedSubviews:@[iconView, textStack]];
    mainStack.axis = UILayoutConstraintAxisHorizontal;
    mainStack.alignment = UIStackViewAlignmentCenter;
    mainStack.spacing = 26.0;
    mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.contentView addSubview:mainStack];
    
    [NSLayoutConstraint activateConstraints:@[
        [mainStack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
        [mainStack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-10],
        [mainStack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [mainStack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [iconView.widthAnchor constraintEqualToConstant:30],
        [iconView.heightAnchor constraintEqualToConstant:30]
    ]];
    
    // 🔹 Store for later updates
    self->_iconImage = iconView.image;
}

#pragma mark - Update

- (void)update {
    [super update];
    
    // Configure labels
    self.titlelabel.text = self.rowDescriptor.title ?: @"";
    
    if ([self.rowDescriptor.cellConfig objectForKey:@"subtitle"]) {
        self.subTitlelabel.text = self.rowDescriptor.cellConfig[@"subtitle"];
    } else {
        self.subTitlelabel.text = @"";
    }
    self.imageView.tintColor = AppPrimaryClr;
    if ([self.rowDescriptor.cellConfig objectForKey:@"icon"]) {
        NSString *iconName = PPSafeString(self.rowDescriptor.cellConfig[@"icon"]);
        
        if (iconName.length > 0) {
            
            UIImage *icon = [UIImage imageNamed:iconName];
            if(icon)
            {
                self.iconImage = icon;
                self.imageView.image = icon;
                NSLog(@"iconName imageNamed %@",iconName);
            }
            else
            {
                icon = [UIImage systemImageNamed:iconName];
                if(icon)
                {
                    NSLog(@"iconName systemImageNamed %@",iconName);
                    self.iconImage = icon;
                    self.imageView.image = icon;
                }
            }
             
        }
    }
   
    if ([self.rowDescriptor.cellConfig objectForKey:@"button"]) {
        [self setupAsButton];
    }
}

#pragma mark - Button Mode

- (void)setupAsButton {
    if (!self.button) {
        self.button = [PPButtonHelper iconButtonTitle:self.rowDescriptor.title
                                                Named:@"checkmark.circle.fill"
                                                 size:0
                                                 tint:AppPrimaryClr
                                      backgroundColor:[AppForgroundColr colorWithAlphaComponent:0.9]
                                                style:PPIconButtonStyleFilled
                                               target:self
                                               action:@selector(buttonSelector)
                                         accessibility:@""];
        
        [self.contentView addSubview:self.button];
        
        [NSLayoutConstraint activateConstraints:@[
            [self.button.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
            [self.button.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
            [self.button.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
            [self.button.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8]
        ]];
    }
}

#pragma mark - Button Action
- (void)buttonSelector {
    NSLog(@"✅ Button tapped for row: %@", self.rowDescriptor.tagM);
}

#pragma mark - Focus & Interaction

- (BOOL)formDescriptorCellCanBecomeFirstResponder {
    return YES;
}

- (BOOL)formDescriptorCellBecomeFirstResponder {
    return YES;
}

- (BOOL)becomeFirstResponder {
    return YES;
}

- (void)formDescriptorCellDidSelectedWithFormController:(XLFormViewController *)controller {
    [controller deselectFormRow:self.rowDescriptor];
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];
    self.contentView.layer.shadowOpacity = 0;
    self.button.layer.shadowOpacity = 0;
    
}

@end






#import "XLFormRowFullWidthTextFieldCell.h"
#import <objc/runtime.h>
static const void *kPPRowUserInfoKey = &kPPRowUserInfoKey;

@implementation XLFormRowDescriptor (PPUserInfoDict)
- (NSMutableDictionary *)pp_userInfo {
    NSMutableDictionary *dict = objc_getAssociatedObject(self, kPPRowUserInfoKey);
    if (!dict) {
        dict = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, kPPRowUserInfoKey, dict, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return dict;
}
@end








NSString * const XLFormRowDescriptorTypeFullWidthTextField = @"XLFormRowFullWidthTextFieldCell";

@implementation XLFormRowFullWidthTextFieldCell

+ (void)load {
    [XLFormViewController.cellClassesForRowDescriptorTypes setObject:[self class] forKey:XLFormRowDescriptorTypeFullWidthTextField];
}

#pragma mark - Configuration

- (void)configure {
    [super configure];
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    if (!self.textField) {
        self.textField = [[UITextField alloc] initWithFrame:CGRectZero];
        self.textField.translatesAutoresizingMaskIntoConstraints = NO;
        self.textField.delegate = self;
        self.textField.textAlignment = GM.setAligment;
        self.textField.adjustsFontSizeToFitWidth = YES;
        self.textField.minimumFontSize = 12;
        self.textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        self.textField.returnKeyType = UIReturnKeyDone;
        self.textField.font = [GM MidFontWithSize:15];
        self.textField.textColor = AppPrimaryClr;
        [self.contentView addSubview:self.textField];
        
        self.topField = [[UILabel alloc] initWithFrame:CGRectZero];
        self.topField.translatesAutoresizingMaskIntoConstraints = NO;
        self.topField.textAlignment = GM.setAligment;
        self.topField.adjustsFontSizeToFitWidth = YES;
        self.topField.minimumFontSize = 12;
        self.topField.font = [GM MidFontWithSize:15];
        
        [self.contentView addSubview:self.topField];
        
        
    }
}


- (void)buttonSelector {
    
    
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    self.button.layer.shadowOpacity = 0;
    [self.button pp_setShadowColor:nil];
    self.button.layer.shadowOffset = CGSizeZero;
    self.button.layer.shadowRadius = 0;
    
    self.contentView.layer.shadowOpacity = 0;
    [self.contentView pp_setShadowColor:nil];
    self.contentView.layer.shadowOffset = CGSizeZero;
    self.contentView.layer.shadowRadius = 0;
    
    
    [self.topField sizeToFit];
    [self.textField sizeToFit];
    self.textField.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
}





- (void)update {
    [super update];
    
    self.topField.text = self.rowDescriptor.title;
    self.topField.textColor = AppPrimaryTextClr;
    
    self.textField.text = self.rowDescriptor.value ?: @"";
    //self.textField.placeholder = @"";
    // Accessibility
    self.textField.accessibilityLabel = self.rowDescriptor.title ?: self.rowDescriptor.title;
    
    // Configure input traits
    XLFormFullWidthTextFieldType type = [self.rowDescriptor.cellConfig[@"inputType"] integerValue];
    [self applyInputType:type];
    
    if(self.rowDescriptor.cellConfig[@"TitlePos"])
    {
        self.TitlePos = [self.rowDescriptor.cellConfig[@"TitlePos"] integerValue];
    }
   
    [self applyTitlePos:self.TitlePos];
    
    
}
- (void)applyTitlePos:(XLFormFullWidthTextFieldTitlePos)titlePos {
    
    
    [self.topField sizeToFit];
    [self.textField sizeToFit];
    //self.topField.backgroundColor = UIColor.redColor;
    //self.textField.backgroundColor = UIColor.blueColor;
    [NSLayoutConstraint deactivateConstraints:self.contentView.constraints];
    self.textLabel.hidden = YES;
    
    
    if(titlePos == XLFormFullWidthTextFieldFull)
    {
        self.topField.hidden = YES;
        // Title on top, textfield below
        [NSLayoutConstraint activateConstraints:@[
           
            
            [self.textField.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor constant:-0],
            [self.textField.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
            [self.textField.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
            
        ]];
        self.textField.textAlignment = Language.alignmentForCurrentLanguage;
    }
    
    else
    {
        self.topField.hidden = NO;
        // Title on top, textfield below
        [NSLayoutConstraint activateConstraints:@[
            [self.topField.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12],
            [self.topField.widthAnchor constraintEqualToConstant:100],
            [self.topField.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor constant:-0],
            
            [self.textField.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor constant:-0],
            [self.textField.leadingAnchor constraintEqualToAnchor:self.topField.trailingAnchor constant:4],
            [self.textField.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
            
        ]];
        self.textField.textAlignment = NSTextAlignmentNatural;
    }
    
    
    
    
    
    

    
}
#pragma mark - Input Type

- (void)applyInputType:(XLFormFullWidthTextFieldType)type {
    self.textField.secureTextEntry = NO;
    self.textField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;

    switch (type) {
        case XLFormFullWidthTextFieldTypeEmail:
            self.textField.keyboardType = UIKeyboardTypeEmailAddress;
            self.textField.textContentType = UITextContentTypeEmailAddress;
            break;
        case XLFormFullWidthTextFieldTypeNumber:
            self.textField.keyboardType = UIKeyboardTypeASCIICapable;
            break;
        case XLFormFullWidthTextFieldTypePassword:
            self.textField.secureTextEntry = YES;
            self.textField.textContentType = UITextContentTypePassword;
            break;
        case XLFormFullWidthTextFieldTypePhone:
            self.textField.keyboardType = UIKeyboardTypePhonePad;
            self.textField.textContentType = UITextContentTypeTelephoneNumber;
            break;
        case XLFormFullWidthTextFieldTypeButton:
            self.button.hidden = NO;
         
           
        case XLFormFullWidthTextFieldTypeDefault:
        default:
            self.textField.keyboardType = UIKeyboardTypeDefault;
            self.textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
            break;
    }
}

#pragma mark - Row Taps

- (BOOL)formDescriptorCellCanBecomeFirstResponder {
    return YES;
}

-(BOOL)formDescriptorCellBecomeFirstResponder
{
    return YES;
}

- (BOOL)becomeFirstResponder {
    return [self.textField becomeFirstResponder];
}

- (void)formDescriptorCellDidSelectedWithFormController:(XLFormViewController *)controller {
    [self.textField becomeFirstResponder];
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidEndEditing:(UITextField *)textField {
    self.rowDescriptor.value = textField.text;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

@end

















 
NSString * const XLFormRowButtonKey = @"XLFormRowButton";

@implementation XLFormRowButton

+ (void)load {
    [XLFormViewController.cellClassesForRowDescriptorTypes setObject:[self class]
                                                              forKey:XLFormRowButtonKey];
}

#pragma mark - Configuration

-(void)layoutSubviews
{
    [super layoutSubviews];
    self.button.layer.shadowOpacity = 0;
    [self.button pp_setShadowColor:nil];
    self.button.layer.shadowOffset = CGSizeZero;
    self.button.layer.shadowRadius = 0;
    self.button.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentView.layer.shadowOpacity = 0;
    [self.contentView pp_setShadowColor:nil];
    self.contentView.layer.shadowOffset = CGSizeZero;
    self.contentView.layer.shadowRadius = 0;
    

}
- (void)configure {
    [super configure];
    self.selectionStyle = UITableViewCellSelectionStyleNone;

    if (!self.button) {
        self.button = [UIButton systemButtonWithPrimaryAction:nil];
        
        // Configure SF Symbol appearance (iOS 15+)
        if (@available(iOS 26.0, *)) {
            UIButtonConfiguration *cfg= [UIButtonConfiguration prominentGlassButtonConfiguration];
            cfg.baseForegroundColor = AppPrimaryClr;
            cfg.baseBackgroundColor = AppClearClr;
            cfg.background.backgroundColor = AppClearClr;
            cfg.preferredSymbolConfigurationForImage =
                [PPColorUtils imageConfig:18
                                   weight:UIImageSymbolWeightRegular
                                    scale:UIImageSymbolScaleMedium
                                  palette:@[AppPrimaryClr,AppForgroundColr]
                             fallbackTint:AppPrimaryClr
                           renderOriginal:YES];
            
                cfg.attributedTitle = [[NSAttributedString alloc] initWithString:kLang(@"Add New Address")
                                                                      attributes:@{
                    NSFontAttributeName: [GM boldFontWithSize:16],
                    NSForegroundColorAttributeName: PPIOS26() ? AppPrimaryClr : AppForgroundColr
                }];
             
            self.button.configuration = cfg;
            [self.button updateConfiguration];
        }
        else
        {
            [self.button.titleLabel setFont:[GM boldFontWithSize:16]];
            [self.button addTarget:self action:@selector(onButtonTap) forControlEvents:UIControlEventTouchUpInside];

        }
        [self.button addTarget:self action:@selector(onButtonTap) forControlEvents:UIControlEventTouchUpInside];

        
        self.button.layer.shadowOpacity = 0.0;
        [self.button pp_setShadowColor:AppClearClr];
        self.button.layer.shadowOffset = CGSizeMake(0, 0);
        self.button.layer.masksToBounds =YES;
        self.button.clipsToBounds = YES;
        [self.contentView addSubview:self.button];
        [self applyConstraints];
        self.contentView.backgroundColor = AppClearClr;
        
        
        
        
        self.contentView.layer.masksToBounds = NO;
        self.contentView.clipsToBounds = NO;
        self.contentView.layer.shadowOpacity = 0;
        [self.contentView pp_setShadowColor:nil];
        self.contentView.layer.shadowOffset = CGSizeZero;
        self.contentView.layer.shadowRadius = 0;
        
        self.contentView.backgroundColor = AppClearClr;
    }
}

#pragma mark - Layout

- (void)applyConstraints {
    self.button.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[
        [self.button.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [self.button.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
     ]];
    
    if(PPIOS26())
    {
        [NSLayoutConstraint activateConstraints:@[
            [self.button.heightAnchor constraintEqualToConstant:50],
            [self.button.widthAnchor constraintEqualToConstant:220],
        ]];
    }
    else
    {
        [NSLayoutConstraint activateConstraints:@[
            [self.button.heightAnchor constraintEqualToAnchor:self.contentView.heightAnchor],
            [self.button.widthAnchor constraintEqualToAnchor:self.contentView.widthAnchor]
        ]];
    }
}

#pragma mark - Button / Row Interaction

// ✅ Unified tap handler — triggers XLForm’s onChange/onAction logic
- (void)triggerXLFormAction {
    XLFormViewController *formVC = self.formViewController;
    if (!formVC || !self.rowDescriptor) return;

    // 1️⃣ Play tap animation
    [UIView animateWithDuration:0.08 animations:^{
        self.button.alpha = 0.6;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.15 animations:^{
            self.button.alpha = 1.0;
        }];
    }];

    // 2️⃣ Notify form controller of tap
    if (self.rowDescriptor.action.formBlock) {
        self.rowDescriptor.action.formBlock(self.rowDescriptor);
    } else if (self.rowDescriptor.action.formSelector) {
        SEL selector = self.rowDescriptor.action.formSelector;
        if ([formVC respondsToSelector:selector]) {
            ((void (*)(id, SEL, id))[formVC methodForSelector:selector])(formVC, selector, self.rowDescriptor);
        }
    }

    // 3️⃣ Optionally trigger valueChanged event (if needed)
    [formVC deselectFormRow:self.rowDescriptor];
}

// Button tap
- (void)onButtonTap {
    [self triggerXLFormAction];
}

// Row tap
- (void)formDescriptorCellDidSelectedWithFormController:(XLFormViewController *)controller {
    [self triggerXLFormAction];
}

#pragma mark - Misc Overrides

- (BOOL)formDescriptorCellCanBecomeFirstResponder { return YES; }
- (BOOL)formDescriptorCellBecomeFirstResponder { return YES; }
 

- (void)update {
    [super update];
    
    if (self.rowDescriptor.title.length > 0) {
        // Title
       
        
        // Get icon name from config
        NSString *imageName = self.rowDescriptor.cellConfig[@"icon"];
        NSLog(@"🔄 Updating icon to: %@  self.rowDescriptor.cellConfig[ ] %@", imageName,self.rowDescriptor.cellConfig[@"icon"]);
        
        // ✅ Get current config safely
        UIButtonConfiguration *config;
        
        if (@available(iOS 26.0, *)) {
            config = [UIButtonConfiguration glassButtonConfiguration];
            if (!config) config = [UIButtonConfiguration filledButtonConfiguration];
            
            // Apply the system image if available
            if (imageName.length > 0) {
                config.image = [UIImage systemImageNamed:imageName];
                config.preferredSymbolConfigurationForImage = [UIImageSymbolConfiguration configurationWithPaletteColors:@[AppButtonMixColorClr, [AppPrimaryClr colorWithAlphaComponent:1.1]]];
            } else {
                config.image = nil;
            }
            
            // Set title style
            config.attributedTitle = [[NSAttributedString alloc] initWithString:self.rowDescriptor.title
                                                                     attributes:@{
                NSFontAttributeName: [GM boldFontWithSize:16],
                NSForegroundColorAttributeName: AppPrimaryClr
            }];
            
            
            config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
            config.contentInsets = NSDirectionalEdgeInsetsMake(10, 16, 10, 16);
            config.imagePlacement = NSDirectionalRectEdgeTrailing; // ✅ image to the right of text
            config.imagePadding = 8;

            

            // Tinting fix
            config.preferredSymbolConfigurationForImage =
            [UIImageSymbolConfiguration configurationWithPaletteColors:@[AppButtonMixColorClr, AppPrimaryClr]];
            config.baseForegroundColor = AppPrimaryClr;
     
            
            // Update and apply back
            self.button.configuration = config;
            [self.button updateConfiguration];
            [self.button layoutIfNeeded];
        }
        
        else
        {
            [self.button setTitle:self.rowDescriptor.title forState:UIControlStateNormal];
            [self.button.titleLabel setFont:[GM boldFontWithSize:16]];
        }
        
            
        self.button.layer.masksToBounds =YES;
        self.button.clipsToBounds = YES;
        
        
        
        
        ///[self.button.imageView setImage:[UIImage systemImageNamed:imageName]];
    }
    
    self.backgroundColor = AppClearClr;
    self.contentView.backgroundColor = AppClearClr;
    
    if(!PPIOS26())
    {
        self.backgroundColor = AppForgroundColr;
        self.contentView.backgroundColor = AppForgroundColr;
        self.button.backgroundColor = AppForgroundColr;
    }
        
}

@end
 
