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

    _itemImageView = [[UIImageView alloc] init];
    _itemImageView.contentMode = UIViewContentModeScaleAspectFill;
    _itemImageView.layer.cornerRadius = 8;
    _itemImageView.clipsToBounds = YES;
    [self.contentView addSubview:_itemImageView];

    _nameLabel = [[UILabel alloc] init];
    _nameLabel.font = [GM boldFontWithSize:16];
    _nameLabel.textColor = GM.PrimaryTextColor;
    [self.contentView addSubview:_nameLabel];

    _quantityLabel = [[UILabel alloc] init];
    _quantityLabel.font = [GM MidFontWithSize:14];
    _quantityLabel.textColor = GM.SecondaryTextColor;
    [self.contentView addSubview:_quantityLabel];

    _priceLabel = [[UILabel alloc] init];
    _priceLabel.font = [GM MidFontWithSize:14];
    _priceLabel.textColor = GM.SecondaryTextColor;
    [self.contentView addSubview:_priceLabel];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    BOOL isRTL = ([Language languageVal] == 1);
    
    CGFloat padding = 16;
    CGFloat imageSize =60;
    CGFloat contentWidth = self.contentView.frame.size.width;

    if (isRTL) {
        _itemImageView.frame = CGRectMake(contentWidth - padding - imageSize, 10, imageSize, imageSize);
        _nameLabel.frame = CGRectMake(padding, 10, contentWidth - imageSize - 3 * padding, 22);
        _quantityLabel.frame = CGRectMake(padding, CGRectGetMaxY(_nameLabel.frame), contentWidth - imageSize - 3 * padding, 20);
        _priceLabel.frame = CGRectMake(padding, CGRectGetMaxY(_quantityLabel.frame), contentWidth - imageSize - 3 * padding, 20);
        _nameLabel.textAlignment = NSTextAlignmentRight;
        _quantityLabel.textAlignment = NSTextAlignmentRight;
        _priceLabel.textAlignment = NSTextAlignmentRight;
    } else {
        _itemImageView.frame = CGRectMake(padding, 10, imageSize, imageSize);
        _nameLabel.frame = CGRectMake(padding + imageSize + padding, 10, contentWidth - imageSize - 3 * padding, 22);
        _quantityLabel.frame = CGRectMake(padding + imageSize + padding, 36, 150, 20);
        _priceLabel.frame = CGRectMake(contentWidth - padding - 100, 36, 90, 20);
        _nameLabel.textAlignment = NSTextAlignmentLeft;
        _quantityLabel.textAlignment = NSTextAlignmentLeft;
        _priceLabel.textAlignment = NSTextAlignmentRight;
    }
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
    _nameLabel.textColor = UIColor.blackColor;
    [self.contentView addSubview:_nameLabel];

    _quantityLabel = [[UILabel alloc] initWithFrame:CGRectMake(86, 36, 100, 20)];
    _quantityLabel.font = [UIFont systemFontOfSize:14];
    _quantityLabel.textColor = UIColor.grayColor;
    [self.contentView addSubview:_quantityLabel];

    _priceLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.contentView.frame.size.width - 100, 36, 90, 20)];
    _priceLabel.font = [UIFont systemFontOfSize:14];
    _priceLabel.textColor = UIColor.darkGrayColor;
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
