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

@interface OrderItemCell ()
@property (nonatomic, strong) UIView *surfaceView;
@end

@implementation OrderItemCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) [self setupViews];
    return self;
}

- (void)setupViews
{
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.contentView.semanticContentAttribute = self.semanticContentAttribute;

    self.surfaceView = [[UIView alloc] initWithFrame:CGRectZero];
    self.surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    CGFloat surfaceAlpha = UIAccessibilityIsReduceTransparencyEnabled() ? 1.0 : (PPIOS26() ? 0.80 : 0.94);
    self.surfaceView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:surfaceAlpha];
    self.surfaceView.opaque = NO;
    PPApplyContinuousCorners(self.surfaceView, PPCornerCard);
    self.surfaceView.layer.borderWidth = 1.0;
    [self.surfaceView pp_setBorderColor:[[UIColor labelColor] colorWithAlphaComponent:0.055]];
    [self.contentView addSubview:self.surfaceView];

    _itemImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _itemImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _itemImageView.contentMode = UIViewContentModeScaleAspectFill;
    PPApplyContinuousCorners(_itemImageView, PPCornerMedium);
    _itemImageView.clipsToBounds = YES;
    _itemImageView.accessibilityElementsHidden = YES;
    [self.surfaceView addSubview:_itemImageView];

    _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _nameLabel.font = [GM boldFontWithSize:PPFontHeadline];
    _nameLabel.textColor = UIColor.labelColor;
    _nameLabel.textAlignment = NSTextAlignmentNatural;
    _nameLabel.numberOfLines = 2;
    _nameLabel.adjustsFontForContentSizeCategory = YES;
    [_nameLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [self.surfaceView addSubview:_nameLabel];

    _quantityLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _quantityLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _quantityLabel.font = [GM MidFontWithSize:PPFontFootnote];
    _quantityLabel.textColor = UIColor.secondaryLabelColor;
    _quantityLabel.textAlignment = NSTextAlignmentNatural;
    _quantityLabel.adjustsFontForContentSizeCategory = YES;
    [self.surfaceView addSubview:_quantityLabel];

    _priceLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _priceLabel.font = [GM boldFontWithSize:PPFontCallout];
    _priceLabel.textColor = [GM appPrimaryColor];
    _priceLabel.textAlignment = NSTextAlignmentNatural;
    _priceLabel.adjustsFontForContentSizeCategory = YES;
    [_priceLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_priceLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.surfaceView addSubview:_priceLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.surfaceView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPScreenMargin],
        [self.surfaceView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPScreenMargin],
        [self.surfaceView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:PPSpaceXS],
        [self.surfaceView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-PPSpaceXS],

        [_itemImageView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:PPSpaceMD],
        [_itemImageView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor constant:PPSpaceMD],
        [_itemImageView.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor constant:-PPSpaceMD],
        [_itemImageView.widthAnchor constraintEqualToConstant:68.0],
        [_itemImageView.heightAnchor constraintEqualToConstant:68.0],

        [_nameLabel.leadingAnchor constraintEqualToAnchor:_itemImageView.trailingAnchor constant:PPSpaceMD],
        [_nameLabel.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-PPSpaceMD],
        [_nameLabel.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor constant:14.0],

        [_quantityLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
        [_quantityLabel.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor constant:-16.0],
        [_quantityLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_priceLabel.leadingAnchor constant:-PPSpaceSM],

        [_priceLabel.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-PPSpaceMD],
        [_priceLabel.centerYAnchor constraintEqualToAnchor:_quantityLabel.centerYAnchor],
        [_nameLabel.bottomAnchor constraintLessThanOrEqualToAnchor:_quantityLabel.topAnchor constant:-PPSpaceSM]
    ]];
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.itemImageView.image = [UIImage imageNamed:@"placeholder"];
    self.nameLabel.text = nil;
    self.quantityLabel.text = nil;
    self.priceLabel.text = nil;
    self.accessibilityLabel = nil;
    self.surfaceView.transform = CGAffineTransformIdentity;
    self.surfaceView.alpha = 1.0;
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    if (self.selectionStyle == UITableViewCellSelectionStyleNone) return;
    void (^changes)(void) = ^{
        self.surfaceView.transform = highlighted ? CGAffineTransformMakeScale(PPTapCardScaleDown, PPTapCardScaleDown) : CGAffineTransformIdentity;
        self.surfaceView.alpha = highlighted ? 0.88 : 1.0;
    };
    if (animated) {
        [UIView animateWithDuration:highlighted ? 0.09 : 0.18
                              delay:0.0
             usingSpringWithDamping:0.86
              initialSpringVelocity:0.3
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    UISemanticContentAttribute attribute = Language.semanticAttributeForCurrentLanguage;
    self.semanticContentAttribute = attribute;
    self.contentView.semanticContentAttribute = attribute;
    self.surfaceView.semanticContentAttribute = attribute;
}

- (void)configureWithItem:(CartItem *)item
{
    _nameLabel.text = item.name;
    _quantityLabel.text = [NSString stringWithFormat:@"%@: %ld", kLang(@"QuantityLabel"), (long)item.quantity];
    _priceLabel.text = [PPChatsFunc formattedCurrency:MAX(0.0, (item.price * item.quantity))];
    self.accessibilityLabel = [NSString stringWithFormat:@"%@, %@, %@", _nameLabel.text ?: @"", _quantityLabel.text ?: @"", _priceLabel.text ?: @""];

    if (item.imageURL.length > 0) {
        [GM setImageFromUrlString:item.imageURL imageView:_itemImageView phImage:@"placeholder"];
    } else {
        _itemImageView.image = [UIImage imageNamed:@"placeholder"];
    }
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
