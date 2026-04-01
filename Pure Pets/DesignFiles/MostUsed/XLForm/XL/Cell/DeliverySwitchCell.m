//
//  DeliverySwitchCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 09/07/2025.
//


#import "DeliverySwitchCell.h"

@implementation DeliverySwitchCell

- (void)configure {
    [super configure];
    
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightRegular];
    [self.contentView addSubview:self.titleLabel];

    self.priceLabel = [[UILabel alloc] init];
    self.priceLabel.font = [UIFont systemFontOfSize:17];
    self.priceLabel.textColor = UIColor.grayColor;
    self.priceLabel.textAlignment = NSTextAlignmentRight;
    [self.contentView addSubview:self.priceLabel];

    self.toggleSwitch = [[UISwitch alloc] init];
    [self.toggleSwitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.contentView addSubview:self.toggleSwitch];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat padding = 16;
    CGFloat switchWidth = self.toggleSwitch.intrinsicContentSize.width;
    CGFloat switchHeight = self.toggleSwitch.intrinsicContentSize.height;
    
    self.toggleSwitch.frame = CGRectMake(self.contentView.frame.size.width - padding - switchWidth,
                                         (self.contentView.frame.size.height - switchHeight) / 2,
                                         switchWidth, switchHeight);

    self.priceLabel.frame = CGRectMake(self.toggleSwitch.frame.origin.x - 80,
                                       0,
                                       70,
                                       self.contentView.frame.size.height);
    
    self.titleLabel.frame = CGRectMake(padding,
                                       0,
                                       self.priceLabel.frame.origin.x - 2 * padding,
                                       self.contentView.frame.size.height);
}

- (void)update {
    [super update];
    self.titleLabel.text = self.rowDescriptor.title ?: @"التوصيل";
    self.priceLabel.text = @"22.00 ر.ق"; // Optional: use value from rowDescriptor.value if dynamic
    self.toggleSwitch.on = [self.rowDescriptor.value boolValue];
}

- (void)switchChanged:(UISwitch *)sender {
    self.rowDescriptor.value = @(sender.isOn);
    [self.formViewController.tableView beginUpdates];
    [self.formViewController.tableView endUpdates];
}

@end
