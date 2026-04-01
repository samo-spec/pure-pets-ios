//
//  CustomButtonCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 17/03/2025.
//

#import "CustomButtonCell.h"

@implementation CustomButtonCell

@synthesize customButton;

#pragma mark - XLFormDescriptorCell



- (void)configure
{
    [super configure];

    // Create the button if it doesn't exist
    if (!self.customButton) {
        self.customButton = [UIButton buttonWithType:UIButtonTypeSystem]; // Or UIButtonTypeCustom if you want more control
        [self.contentView addSubview:self.customButton];

        // Add constraints to position the button within the cell
        self.customButton.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-10-[_customButton]-10-|" options:0 metrics:nil views:@{@"_customButton": self.customButton}]];
        [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-10-[_customButton]-10-|" options:0 metrics:nil views:@{@"_customButton": self.customButton}]];

        // Add target/action for button tap
        [self.customButton addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
    }

    // Set default values (can be overridden in update)
    [self.customButton setTitle:kLang(@"save") forState:UIControlStateNormal];
    self.customButton.backgroundColor = [UIColor lightGrayColor];
    self.customButton.layer.cornerRadius = 8.0;
    self.customButton.clipsToBounds = YES;
    self.customButton.titleLabel.font = [UIFont systemFontOfSize:16.0]; // Default font
}

- (void)update
{
    [super update];

    // Disable selection
    self.selectionStyle = UITableViewCellSelectionStyleNone;

    // Set button title from row descriptor title
    if (self.rowDescriptor.title) {
        [self.customButton setTitle:self.rowDescriptor.title forState:UIControlStateNormal];
    }

    // Customize button appearance based on row descriptor value (if needed)
    if (self.rowDescriptor.value) {
        // Example:  If the row descriptor's value is a dictionary, use it to configure the button
        if ([self.rowDescriptor.value isKindOfClass:[NSDictionary class]]) {
            NSDictionary *buttonConfig = (NSDictionary *)self.rowDescriptor.value;

            // Background color
            UIColor *backgroundColor = buttonConfig[@"backgroundColor"];
            if (backgroundColor) {
                self.customButton.backgroundColor = backgroundColor;
            }

            // Corner radius
            NSNumber *cornerRadius = buttonConfig[@"cornerRadius"];
            if (cornerRadius) {
                self.customButton.layer.cornerRadius = cornerRadius.floatValue;
            }

            // Font
            UIFont *font = buttonConfig[@"font"];
            if (font) {
                self.customButton.titleLabel.font = font;
            }

            // Title Color
            UIColor *titleColor = buttonConfig[@"titleColor"];
            if (titleColor) {
                [self.customButton setTitleColor:titleColor forState:UIControlStateNormal];
            }
        }
    }

    // Disable the button if the row is disabled
    self.customButton.enabled = !self.rowDescriptor.isDisabled;
    self.customButton.alpha = self.rowDescriptor.isDisabled ? 0.6 : 1.0;
}

#pragma mark - Actions

- (void)buttonTapped:(UIButton *)sender
{
    // Call the row descriptor's action block
    if (self.rowDescriptor.action.formBlock) {
        self.rowDescriptor.action.formBlock(self.rowDescriptor);
    } else if (self.rowDescriptor.action.formSelector && [self.formViewController respondsToSelector:self.rowDescriptor.action.formSelector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.formViewController performSelector:self.rowDescriptor.action.formSelector withObject:self.rowDescriptor];
#pragma clang diagnostic pop
    }
}

@end
