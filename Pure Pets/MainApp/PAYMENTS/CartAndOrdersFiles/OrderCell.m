#import "OrderCell.h"
#import "OrderModel.h"
#import "GM.h"
#import "PPChatsFunc.h"

@implementation OrderCell {
    UIView *_cardView;

    UIStackView *_rowStack;   // horizontal: image + text
    UIStackView *_textStack;  // vertical: title + meta + date
    UIStackView *_metaRow;    // horizontal: qty + price

    NSLayoutConstraint *_cardMinHeightConstraint;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupViews];
    }
    return self;
}

// Modern Auto Layout, stack views, fonts/colors preserved
- (void)setupViews {
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.preservesSuperviewLayoutMargins = NO;
    self.contentView.preservesSuperviewLayoutMargins = NO;

    // Card container
    _cardView = [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleLarge configType:PPButtonConfigrationGlass];
    _cardView.translatesAutoresizingMaskIntoConstraints = NO;
    _cardView.backgroundColor = GM.AppForegroundColor;
 
    [_cardView pp_setShadowColor:GM.AppShadowColor];
    _cardView.layer.shadowOpacity = 0.06;
    _cardView.layer.shadowOffset = CGSizeMake(0, 1.0);
    _cardView.layer.shadowRadius = 5.0;
    _cardView.layer.masksToBounds = NO;
    _cardView.userInteractionEnabled=NO;
    [self.contentView addSubview:_cardView];

    // Image
    _itemImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _itemImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _itemImageView.contentMode = UIViewContentModeScaleAspectFill;
    _itemImageView.layer.cornerRadius = 16;
    _itemImageView.clipsToBounds = YES;
    _itemImageView.backgroundColor = AppBackgroundClr;
    [_cardView addSubview:_itemImageView];

    // Labels
    _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _nameLabel.font = [GM boldFontWithSize:16];
    _nameLabel.textColor = GM.PrimaryTextColor;
    _nameLabel.numberOfLines = 2;
    _nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    _quantityLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _quantityLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _quantityLabel.font = [GM MidFontWithSize:14];
    _quantityLabel.textColor = GM.SecondaryTextColor;
    _quantityLabel.numberOfLines = 1;

    _priceLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _priceLabel.font = [GM MidFontWithSize:14];
    _priceLabel.textColor = GM.SecondaryTextColor;
    _priceLabel.numberOfLines = 1;

    _dateLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _dateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _dateLabel.font = [GM MidFontWithSize:13];
    _dateLabel.textColor = GM.SecondaryTextColor;
    _dateLabel.numberOfLines = 1;

    [_dateLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];

    // Stack layout
    _metaRow = [[UIStackView alloc] initWithArrangedSubviews:@[_quantityLabel, _priceLabel]];
    _metaRow.translatesAutoresizingMaskIntoConstraints = NO;
    _metaRow.axis = UILayoutConstraintAxisHorizontal;
    _metaRow.alignment = UIStackViewAlignmentFirstBaseline;
    _metaRow.distribution = UIStackViewDistributionFill;
    _metaRow.spacing = 10;

    // Keep price tight
    [_priceLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_priceLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    _textStack = [[UIStackView alloc] initWithArrangedSubviews:@[_nameLabel, _metaRow, _dateLabel]];
    _textStack.translatesAutoresizingMaskIntoConstraints = NO;
    _textStack.axis = UILayoutConstraintAxisVertical;
    _textStack.alignment = UIStackViewAlignmentFill;
    _textStack.distribution = UIStackViewDistributionFill;
    _textStack.spacing = 6;

    // Horizontal row (image + text) — THIS is what fixes the RTL empty gap
    _rowStack = [[UIStackView alloc] initWithArrangedSubviews:@[_itemImageView, _textStack]];
    _rowStack.translatesAutoresizingMaskIntoConstraints = NO;
    _rowStack.axis = UILayoutConstraintAxisHorizontal;
    _rowStack.alignment = UIStackViewAlignmentCenter;
    _rowStack.distribution = UIStackViewDistributionFill;
    _rowStack.spacing = 12;
    [_cardView addSubview:_rowStack];

    // Modern RTL: use semantic flipping on the row stack
    _rowStack.semanticContentAttribute = UISemanticContentAttributeUnspecified;

    UIView *margins = self.contentView;

    CGFloat horizontalPadding = 12.0;
    CGFloat verticalPadding = 8.0;
    CGFloat innerPadding = 12.0;
 
    self.contentView.layoutMargins = UIEdgeInsetsMake(verticalPadding, horizontalPadding, verticalPadding, horizontalPadding);

    [NSLayoutConstraint activateConstraints:@[
        // Card
        [_cardView.leadingAnchor constraintEqualToAnchor:margins.leadingAnchor constant:horizontalPadding],
        [_cardView.trailingAnchor constraintEqualToAnchor:margins.trailingAnchor constant:-horizontalPadding],
        [_cardView.topAnchor constraintEqualToAnchor:margins.topAnchor constant:verticalPadding],
        [_cardView.bottomAnchor constraintEqualToAnchor:margins.bottomAnchor constant:-verticalPadding],

        // Row
        [_rowStack.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:innerPadding],
        [_rowStack.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-innerPadding],
        [_rowStack.centerYAnchor constraintEqualToAnchor:_cardView.centerYAnchor constant:0],
        //[_rowStack.bottomAnchor constraintLessThanOrEqualToAnchor:_cardView.bottomAnchor constant:-12],

        // Image size
        [_itemImageView.widthAnchor constraintEqualToAnchor:_cardView.heightAnchor constant:-16],
        [_itemImageView.heightAnchor constraintEqualToAnchor:_cardView.heightAnchor constant:-16],
    ]];

    // Min height (avoid huge empty space)
    _cardMinHeightConstraint = [_cardView.heightAnchor constraintGreaterThanOrEqualToConstant:120];
    _cardMinHeightConstraint.active = YES;

    // Modern polish
    _cardView.layer.cornerCurve = kCACornerCurveContinuous;
    _itemImageView.layer.cornerCurve = kCACornerCurveContinuous;
}

// Update RTL/LTR and shadow
- (void)layoutSubviews {
    [super layoutSubviews];

    BOOL isRTL = ([Language languageVal] == 1);

    // Flip the whole row (image <-> text) safely
    _rowStack.semanticContentAttribute = isRTL ? UISemanticContentAttributeForceRightToLeft : UISemanticContentAttributeForceLeftToRight;

    // Also flip meta row so price/qty look natural
    _metaRow.semanticContentAttribute = _rowStack.semanticContentAttribute;

    // Text alignments
    _nameLabel.textAlignment = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    _quantityLabel.textAlignment = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    _dateLabel.textAlignment = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    _priceLabel.textAlignment = isRTL ? NSTextAlignmentLeft : NSTextAlignmentRight;

    // Update shadowPath (smooth scrolling)
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:_cardView.bounds cornerRadius:_cardView.layer.cornerRadius];
    _cardView.layer.shadowPath = path.CGPath;
}

// Cell reuse cleanup
- (void)prepareForReuse {
    [super prepareForReuse];
    _itemImageView.image = [UIImage imageNamed:@"placeholder"];
    _nameLabel.text = @"";
    _quantityLabel.text = @"";
    _priceLabel.text = @"";
    _dateLabel.text = @"";
}

// Configure cell with item
- (void)configureWithItem:(CartItem *)item {
    _nameLabel.text = item.name ?: @"";

    _quantityLabel.text = [NSString stringWithFormat:@"%@: %ld", kLang(@"QuantityLabel"), (long)item.quantity];

    // Price formatting (keep your existing style)
    double total = item.price * item.quantity;
    _priceLabel.text = [PPChatsFunc formattedCurrency:MAX(0.0, total)];

    // If you later have a date on the item, set it here
    // _dateLabel.text = item.createdAtText ?: @"—";

    if (item.imageURL.length > 0) {
        [GM setImageFromUrlString:item.imageURL imageView:_itemImageView phImage:@"placeholder"];
    } else {
        _itemImageView.image = [UIImage imageNamed:@"placeholder"];
    }

    [self setNeedsLayout];
    [self layoutIfNeeded];
}

@end


