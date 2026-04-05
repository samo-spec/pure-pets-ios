//
//  CartTableViewCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 30/06/2025.
//

#import "CartTableViewCell.h"

@implementation CartTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self awakeViews];
    }
    return self;
}


- (void)awakeViews {

    // RTL/LTR — leading/trailing anchors auto-flip with semantic attribute
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.contentView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    _itemImageView = [[UIImageView alloc] init];
    _itemImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _itemImageView.contentMode = UIViewContentModeScaleAspectFill;
    _itemImageView.layer.cornerRadius = 10;
    _itemImageView.clipsToBounds = YES;
    [self.contentView addSubview:_itemImageView];

    _nameLabel = [[UILabel alloc] init];
    _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _nameLabel.font = [GM boldFontWithSize:16];
    _nameLabel.textAlignment = NSTextAlignmentNatural;
    [self.contentView addSubview:_nameLabel];

    _priceLabel = [[UILabel alloc] init];
    _priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _priceLabel.font = [GM MidFontWithSize:16];
    _priceLabel.textAlignment = NSTextAlignmentNatural;
    [self.contentView addSubview:_priceLabel];

    // qtyButton stays frame-based (FloatingQuantityButton manages its own internal layout)
    self.qtyButton = [[FloatingQuantityButton alloc] initWithFrame:CGRectZero];
    self.qtyButton.onQuantityChanged = ^(NSInteger newQty) {
        NSLog(@"Qty updated to %ld", (long)newQty);
    };
    [self.contentView addSubview:self.qtyButton];

    // ── Accessibility: Cart item cell ──
    self.isAccessibilityElement = NO; // Allow children to be individually accessible
    _itemImageView.isAccessibilityElement = NO; // Decorative
    self.qtyButton.accessibilityLabel = NSLocalizedString(@"a11y_cart_qty_stepper", @"Item quantity");

    // ── Auto Layout (RTL-safe via leading/trailing — no manual branching) ──
    CGFloat padding = 10.0;
    CGFloat imageSize = 80.0;

    [NSLayoutConstraint activateConstraints:@[
        // Image: fixed size, leading edge
        [_itemImageView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:padding],
        [_itemImageView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:padding],
        [_itemImageView.widthAnchor constraintEqualToConstant:imageSize],
        [_itemImageView.heightAnchor constraintEqualToConstant:imageSize],

        // Name: after image, full trailing width
        [_nameLabel.leadingAnchor constraintEqualToAnchor:_itemImageView.trailingAnchor constant:padding],
        [_nameLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-padding],
        [_nameLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],

        // Price: below name, same horizontal span
        [_priceLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
        [_priceLabel.trailingAnchor constraintEqualToAnchor:_nameLabel.trailingAnchor],
        [_priceLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor],
    ]];

}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}


- (void)layoutSubviews {
    [super layoutSubviews];

    // Update layout direction for runtime language changes
    UISemanticContentAttribute attr = Language.semanticAttributeForCurrentLanguage;
    self.semanticContentAttribute = attr;
    self.contentView.semanticContentAttribute = attr;

    // Position qtyButton below priceLabel (frame-based for FloatingQuantityButton compatibility)
    // After Auto Layout pass, priceLabel.frame is resolved and safe to read.
    CGFloat qtyY = CGRectGetMaxY(self.priceLabel.frame) + 5;
    CGFloat qtyX = self.priceLabel.frame.origin.x;
    self.qtyButton.frame = CGRectMake(qtyX, qtyY, 120, 40);
    [self.qtyButton setAutoShowHide:0];
    [self.qtyButton showStepper];
}

@end
