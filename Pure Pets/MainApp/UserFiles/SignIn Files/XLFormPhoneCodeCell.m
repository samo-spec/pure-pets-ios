//
//  XLFormPhoneCodeCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 01/12/2025.
//


#import "XLFormPhoneCodeCell.h"
#import "CountryCodeModel.h"

@interface XLFormPhoneCodeCell ()
@property (nonatomic, assign) BOOL didSetupViews;
@end

@implementation XLFormPhoneCodeCell

+ (void)load {
    [XLFormViewController.cellClassesForRowDescriptorTypes setObject:self
                                                               forKey:XLFormRowDescriptorTypePhoneCode];
}

#pragma mark - Cell lifecycle

- (void)configure {
    [super configure];
    BOOL hasPhone = [self currentUserHasPhoneProvider];
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    
    if (!self.didSetupViews) {
        self.didSetupViews = YES;

        self.countryButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.countryButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
        [self.countryButton setTitle:@"🇪🇬" forState:UIControlStateNormal];
        [self.countryButton addTarget:self action:@selector(selectCountry)
                     forControlEvents:UIControlEventTouchUpInside];
        self.countryButton.backgroundColor = AppBackgroundClr;
        self.countryButton.layer.cornerRadius = 8;

        NSString *MobileNoPalce = [NSString stringWithFormat:@"%@", kLang(@"MobileNo_Palce")];

        self.dialCodeLabel = [[UILabel alloc] init];
        self.dialCodeLabel.font = [GM MidFontWithSize:16];
        self.dialCodeLabel.text = @"+20";
        self.dialCodeLabel.textAlignment = NSTextAlignmentLeft;
        self.dialCodeLabel.userInteractionEnabled = NO;
    
    
        self.numberField = [[UITextField alloc] init];
        self.numberField.keyboardType = UIKeyboardTypeASCIICapableNumberPad;
        self.numberField.placeholder = MobileNoPalce;
        self.numberField.font = [GM MidFontWithSize:16];
        self.numberField.textAlignment = NSTextAlignmentLeft;
    
        [self.contentView addSubview:self.countryButton];
        [self.contentView addSubview:self.dialCodeLabel];
        [self.contentView addSubview:self.numberField];

        self.numberField.translatesAutoresizingMaskIntoConstraints = NO;
        self.countryButton.translatesAutoresizingMaskIntoConstraints = NO;
        self.dialCodeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.dialCodeLabel sizeToFit];
        [NSLayoutConstraint activateConstraints:@[
            // Country button left
            [self.countryButton.leftAnchor constraintEqualToAnchor:self.contentView.leftAnchor constant:16],
            [self.countryButton.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [self.countryButton.widthAnchor constraintEqualToConstant:40],

            // Dial code next to flag
            [self.dialCodeLabel.leftAnchor constraintEqualToAnchor:self.countryButton.rightAnchor constant:8],
            [self.dialCodeLabel.centerYAnchor constraintEqualToAnchor:self.countryButton.centerYAnchor],

            // Number field fills the rest
            [self.numberField.leftAnchor constraintEqualToAnchor:self.dialCodeLabel.rightAnchor constant:12],
            [self.numberField.rightAnchor constraintEqualToAnchor:self.contentView.rightAnchor constant:-16],
            [self.numberField.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [self.numberField.heightAnchor constraintEqualToConstant:44]
        ]];
    
        [Styling addLiquidGlassBorderToView:self.countryButton cornerRadius:20];
    }
    
    //[self applyPhoneLockState:hasPhone];
}

- (void)showPickerSheetWithData:(NSMutableArray *)data {
    UIViewController *vcTop = [self.formViewController presentingViewController] ?: self.formViewController;
   // __weak typeof(self) w = self;
    PPSelectOptionViewController *vc = [[PPSelectOptionViewController alloc] initWithOptions:data title:@"" row:nil presentationStyle:PPSelectOptionPresentationSheet completion:^(id  _Nullable selectedObject) {
        NSLog(@"✅ Selected : %@", selectedObject);
        if (![selectedObject isKindOfClass:[CountryCodeModel class]]) {
            return;
        }
        CountryCodeModel *selectedCountry = (CountryCodeModel *)selectedObject;
        self.dialCodeLabel.text = selectedCountry.phoneCode;
        [self.countryButton setTitle:selectedCountry.flag forState:UIControlStateNormal];

        XLFormPhoneCodeItem *item = (XLFormPhoneCodeItem *)self.rowDescriptor;
        item.dialCode = selectedCountry.phoneCode;
        
    }];
    [vcTop presentViewController:vc animated:YES completion:nil];
    
}

- (void)update {
    [super update];

    XLFormPhoneCodeItem *item = (XLFormPhoneCodeItem *)self.rowDescriptor;

    if (item.dialCode.length > 0) {
        self.dialCodeLabel.text = item.dialCode;
    }
    
    if (item.flag.length > 0) {
        [self.countryButton setTitle:item.flag forState:UIControlStateNormal];

    }

    // Set phone number into row value
    self.numberField.text = item.value ?: @"";
}

#pragma mark - Country Picker

- (void)selectCountry {
   
    [self showPickerSheetWithData:[GM getMiddleEastCountriesForLanguage:[Language currentLanguageCode]]];
}

#pragma mark - XLForm
- (BOOL)formDescriptorCellCanBecomeFirstResponder {
    return YES;
}

- (BOOL)becomeFirstResponder {
    return [self.numberField becomeFirstResponder];
}

- (BOOL)formDescriptorCellBecomeFirstResponder {
    return YES;
}

- (BOOL)currentUserHasPhoneProvider {
    for (id<FIRUserInfo> provider in [FIRAuth auth].currentUser.providerData) {
        if ([provider.providerID isEqualToString:@"phone"]) {
            return YES;
        }
    }
    return NO;
}

- (void)applyPhoneLockState:(BOOL)hasPhone {
    self.countryButton.userInteractionEnabled = !hasPhone;
    self.numberField.userInteractionEnabled = !hasPhone;
}

@end
