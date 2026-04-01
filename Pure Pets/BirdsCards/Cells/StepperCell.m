//
//  StepperCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 14/12/2024.
//

#import "StepperCell.h"

@implementation StepperCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self commonInit];
}

- (void)commonInit {
    if (self.plainStepper) return;

    self.selectionStyle = UITableViewCellSelectionStyleNone;

    typeof(self) __weak weakself = self;
    self.plainStepper = [[PKYStepper alloc] initWithFrame:CGRectZero];
    self.plainStepper.translatesAutoresizingMaskIntoConstraints = NO;
    [self.plainStepper setCornerRadius:10.0f];
    [self.plainStepper setBorderColor:[UIColor colorWithWhite:0.95 alpha:1.0]];
    UIColor *plainStepperColor = [UIColor colorWithRed:0.91 green:0.55 blue:0.22 alpha:1.0];
    [self.plainStepper setLabelTextColor:plainStepperColor];
    [self.plainStepper setButtonTextColor:plainStepperColor forState:UIControlStateNormal];
    self.plainStepper.value = 21.0f;
    //self.plainStepper.countLabel.text = [NSString stringWithFormat:@"%@", @(21.0)];
    self.plainStepper.valueChangedCallback = ^(PKYStepper *stepper, float count) {
        stepper.countLabel.text = count == stepper.minimum ? @"None" : [NSString stringWithFormat:@"%@", @(count)];
        [weakself.delegate daysCount:count];
    };
    
    [self.contentView addSubview:self.plainStepper];

    [NSLayoutConstraint activateConstraints:@[
        [self.plainStepper.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.plainStepper.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12],
        [self.plainStepper.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-12],
        [self.plainStepper.heightAnchor constraintEqualToConstant:40],
        [self.plainStepper.widthAnchor constraintEqualToConstant:150]
    ]];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
