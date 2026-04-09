//
//  OrderItemCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 04/07/2025.
//


#import "OrderItemCell.h"
#import "OrderModel.h" // contains OrderItem
#import "GM.h" // assuming you use GM for image loading
#import "PPChatsFunc.h"

@implementation OrderItemCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupViews];
    }
    return self;
}

- (void)setupViews {
    self.selectionStyle = UITableViewCellSelectionStyleNone;

    // RTL/LTR — leading/trailing anchors auto-flip with semantic attribute
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.contentView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    _itemImageView = [[UIImageView alloc] init];
    _itemImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _itemImageView.contentMode = UIViewContentModeScaleAspectFill;
    _itemImageView.layer.cornerRadius = 8;
    _itemImageView.clipsToBounds = YES;
    [self.contentView addSubview:_itemImageView];

    _nameLabel = [[UILabel alloc] init];
    _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _nameLabel.font = [GM boldFontWithSize:16];
    _nameLabel.textColor = GM.PrimaryTextColor;
    _nameLabel.textAlignment = NSTextAlignmentNatural;
    [self.contentView addSubview:_nameLabel];

    _quantityLabel = [[UILabel alloc] init];
    _quantityLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _quantityLabel.font = [GM MidFontWithSize:14];
    _quantityLabel.textColor = GM.SecondaryTextColor;
    _quantityLabel.textAlignment = NSTextAlignmentNatural;
    [self.contentView addSubview:_quantityLabel];

    _priceLabel = [[UILabel alloc] init];
    _priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _priceLabel.font = [GM MidFontWithSize:14];
    _priceLabel.textColor = GM.SecondaryTextColor;
    [self.contentView addSubview:_priceLabel];

    // ── Auto Layout (RTL-safe via leading/trailing — no manual branching) ──
    CGFloat padding = 16.0;
    CGFloat imageSize = 60.0;

    [NSLayoutConstraint activateConstraints:@[
        // Image: fixed size, leading edge, vertically padded
        [_itemImageView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:padding],
        [_itemImageView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
        [_itemImageView.widthAnchor constraintEqualToConstant:imageSize],
        [_itemImageView.heightAnchor constraintEqualToConstant:imageSize],
        [_itemImageView.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-10],

        // Name: top row, spans from image trailing to cell trailing
        [_nameLabel.leadingAnchor constraintEqualToAnchor:_itemImageView.trailingAnchor constant:padding],
        [_nameLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-padding],
        [_nameLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],

        // Quantity: second row leading, below name
        [_quantityLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
        [_quantityLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:4],

        // Price: second row trailing, vertically centered with quantity
        // Uses >= spacing so labels never overlap on narrow screens (iPhone SE fix)
        [_priceLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-padding],
        [_priceLabel.centerYAnchor constraintEqualToAnchor:_quantityLabel.centerYAnchor],
        [_priceLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:_quantityLabel.trailingAnchor constant:8],
    ]];

    // Price must never truncate; quantity compresses gracefully on narrow screens
    [_priceLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_priceLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_quantityLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    // Update layout direction for runtime language changes
    UISemanticContentAttribute attr = Language.semanticAttributeForCurrentLanguage;
    self.semanticContentAttribute = attr;
    self.contentView.semanticContentAttribute = attr;
}


- (void)configureWithItem:(CartItem *)item {
    _nameLabel.text = item.name;
    _quantityLabel.text = [NSString stringWithFormat:@"%@: %ld", kLang(@"QuantityLabel"), (long)item.quantity];
    _priceLabel.text = [PPChatsFunc formattedCurrency:MAX(0.0, (item.price * item.quantity))];

    if (item.imageURL.length > 0) {
        [GM setImageFromUrlString:item.imageURL imageView:_itemImageView phImage:@"placeholder"];
    } else {
        _itemImageView.image = [UIImage imageNamed:@"placeholder"];
    }
    
    [self setNeedsLayout];
}


@end


/*
@implementation OrderItemCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupViews];
    }
    return self;
}

- (void)setupViews {
    self.selectionStyle = UITableViewCellSelectionStyleNone;

    _itemImageView = [[UIImageView alloc] initWithFrame:CGRectMake(16, 10, 60, 60)];
    _itemImageView.contentMode = UIViewContentModeScaleAspectFill;
    _itemImageView.layer.cornerRadius = 8;
    _itemImageView.clipsToBounds = YES;
    [self.contentView addSubview:_itemImageView];

    _nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(86, 10, self.contentView.frame.size.width - 100, 22)];
    _nameLabel.font = [UIFont boldSystemFontOfSize:16];
    _nameLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    [self.contentView addSubview:_nameLabel];

    _quantityLabel = [[UILabel alloc] initWithFrame:CGRectMake(86, 36, 100, 20)];
    _quantityLabel.font = [UIFont systemFontOfSize:14];
    _quantityLabel.textColor = UIColor.grayColor;
    [self.contentView addSubview:_quantityLabel];

    _priceLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.contentView.frame.size.width - 100, 36, 90, 20)];
    _priceLabel.font = [UIFont systemFontOfSize:14];
    _priceLabel.textColor = UIColor.secondaryLabelColor;
    _priceLabel.textAlignment = NSTextAlignmentRight;
    [self.contentView addSubview:_priceLabel];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    _nameLabel.frame = CGRectMake(86, 10, self.contentView.frame.size.width - 102, 22);
    _quantityLabel.frame = CGRectMake(86, 36, 100, 20);
    _priceLabel.frame = CGRectMake(self.contentView.frame.size.width - 100, 36, 90, 20);
}

- (void)configureWithItem:(CartItem *)item {
    _nameLabel.text = item.name;
    _quantityLabel.text = [NSString stringWithFormat:@"%@: %ld", kLang(@"QuantityLabel"), (long)item.quantity];
    _priceLabel.text = [PPChatsFunc formattedCurrency:MAX(0.0, (item.price * item.quantity))];

    if (item.imageURL.length > 0) {
        [GM setImageFromUrlString:item.imageURL imageView:_itemImageView phImage:@"placeholder"];
    } else {
        _itemImageView.image = [UIImage imageNamed:@"placeholder"];
    }
}

@end */
