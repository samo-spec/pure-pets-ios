//
//  StepperFormCell 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 21/06/2025.
//


// StepperFormCell.m
#import "StepperFormCell.h"
#import "PKYStepper.h"
#import "StepperCell.h"

@interface StepperFormCell ()

@property (nonatomic, strong) UILabel *valueLabel;
@property(nonatomic, strong) PKYStepper *plainStepper;
@property (nonatomic, weak) id <StepperDelegate> delegate;


@end

@implementation StepperFormCell

#pragma mark - XLForm Life Cycle

- (void)configure {
    [super configure];
    
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    
    // Create and configure label
    self.valueLabel = [[UILabel alloc] init];
    self.valueLabel.font = [GM MidFontWithSize:16];
    [self.contentView addSubview:self.valueLabel];
    
    __weak typeof(self) weakSelf = self;

    self.plainStepper = [[PKYStepper alloc] init];
    [self.plainStepper setCornerRadius:20.0f];
    [self.plainStepper setBorderColor:[UIColor colorWithWhite:0.95 alpha:1.0]];
    // UIColor *plainStepperColor = [UIColor colorWithRed:0.91 green:0.55 blue:0.22 alpha:1.0];
    [self.plainStepper setLabelTextColor:GM.appPrimaryColor];
    [self.plainStepper setButtonTextColor:GM.appPrimaryColor forState:UIControlStateNormal];
    self.plainStepper.value = 21.0f;
    //self.plainStepper.countLabel.text = [NSString stringWithFormat:@"%@", @(21.0)];
    self.plainStepper.valueChangedCallback = ^(PKYStepper *stepper, float count) {
        stepper.countLabel.text = count == stepper.minimum ? @"None" : [NSString stringWithFormat:@"%@", @(count)];
        
        weakSelf.rowDescriptor.value = @(count);
        weakSelf.valueLabel.text = [NSString stringWithFormat:@"%@", weakSelf.rowDescriptor.title ?: @"Value"];
        [weakSelf.formViewController.tableView beginUpdates];
        [weakSelf.formViewController.tableView endUpdates];
    };
    NSNumber *value = self.rowDescriptor.value ?: @(1);
    self.plainStepper.value = value.floatValue;
    self.plainStepper.hx_h = 40;
    self.plainStepper.hx_w = 150;
    self.plainStepper.hx_y = 2;
    self.plainStepper.hx_x = Language.languageVal == 1 ? 10 : self.contentView.hx_w - 82;
    [self.plainStepper setLabelFont:[GM boldFontWithSize:18]];
    [self.plainStepper.incrementButton setTitleColor:GM.appPrimaryColor forState:UIControlStateNormal];
    [self.plainStepper.decrementButton setTitleColor:GM.appPrimaryColor forState:UIControlStateNormal];
    
    [self.contentView addSubview:self.plainStepper];
    
    
   

    // Layout
    self.valueLabel.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[
        [self.valueLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.valueLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],

    ]];
}

- (void)update {
    [super update];
    NSNumber *value = self.rowDescriptor.value ?: @(1);
    self.plainStepper.value = value.floatValue;
    self.valueLabel.text = [NSString stringWithFormat:@"%@", self.rowDescriptor.title ?: @"Value"];
}

- (void)stepperChanged:(UIStepper *)sender {
    self.rowDescriptor.value = @(sender.value);
    self.valueLabel.text = [NSString stringWithFormat:@"%@", self.rowDescriptor.title ?: @"Value"];
    [self.formViewController.tableView beginUpdates];
    [self.formViewController.tableView endUpdates];
}

@end
