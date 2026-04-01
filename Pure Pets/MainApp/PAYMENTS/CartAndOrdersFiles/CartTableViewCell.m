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
   
    _itemImageView = [[UIImageView alloc] initWithFrame:CGRectMake(10, 10, 80, 80)];
    _itemImageView.contentMode = UIViewContentModeScaleAspectFill;
    _itemImageView.layer.cornerRadius = 10;
    _itemImageView.clipsToBounds = YES;
    [self.contentView addSubview:_itemImageView];

    _nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(100, 0, self.contentView.frame.size.width - 110, 30)];
    _nameLabel.font =  [GM boldFontWithSize:16];
    [self.contentView addSubview:_nameLabel];

    _priceLabel = [[UILabel alloc] initWithFrame:CGRectMake(100, 50, self.contentView.frame.size.width - 110, 30)];
    _priceLabel.font =  [GM MidFontWithSize:16];
    [self.contentView addSubview:_priceLabel];
    
    
    self.qtyButton = [[FloatingQuantityButton alloc] initWithFrame:CGRectMake(10, _priceLabel.hx_maxy + 10, 170, 40)];
    self.qtyButton.onQuantityChanged = ^(NSInteger newQty) {
        NSLog(@"Qty updated to %ld", (long)newQty);
    };
    [self.contentView addSubview:self.qtyButton];
    
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}


- (void)layoutSubviews {
    [super layoutSubviews];

    BOOL isRTL = YES;
    if([Language languageVal] == 0)
        isRTL = NO;
    
    CGFloat imageSize = 80;
    CGFloat padding = 10;
    CGFloat contentWidth = self.contentView.frame.size.width;

    if (isRTL) {
        self.itemImageView.frame = CGRectMake(contentWidth - padding - imageSize, padding, imageSize, imageSize);
        self.nameLabel.frame = CGRectMake(padding, 0, contentWidth - imageSize - 3 * padding, 30);
        self.priceLabel.frame = CGRectMake(padding, CGRectGetMaxY(self.nameLabel.frame) , contentWidth - imageSize - 3 * padding, 20);
        
        self.priceLabel.textAlignment = NSTextAlignmentRight;
        self.nameLabel.textAlignment = NSTextAlignmentRight;
        
        self.qtyButton.frame = CGRectMake(contentWidth - padding - imageSize - 110, self.priceLabel.hx_maxy + 5, 80, 40);
        [self.qtyButton setAutoShowHide:0];
        [self.qtyButton showStepper];
 
        
    } else {
        self.itemImageView.frame = CGRectMake(padding, padding, imageSize, imageSize);
        self.nameLabel.frame = CGRectMake(imageSize + padding + padding, 0, contentWidth - imageSize - 3 * padding, 30);
        self.priceLabel.frame = CGRectMake(imageSize + padding + padding, CGRectGetMaxY(self.nameLabel.frame) , contentWidth - imageSize - 3 * padding, 20);
        
        self.priceLabel.textAlignment = NSTextAlignmentLeft;
        self.nameLabel.textAlignment = NSTextAlignmentLeft;
        
        self.qtyButton.frame = CGRectMake(imageSize + padding + padding, self.priceLabel.hx_maxy + 5, 120, 40);
        [self.qtyButton setAutoShowHide:0];
        [self.qtyButton showStepper];
    }
}

@end
