//
//  SearchResultCell 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 12/08/2025.
//


// SearchResultCell.m
#import "SearchResultCell.h"
#import "SearchResultItem.h"
#import "GM.h"

@interface SearchResultCell ()
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIImageView *thumbView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) PPInsetLabel *badgeLabel;
@end

@implementation SearchResultCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {

        // Transparent backgrounds so the shadow shows
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        // ----- Card container with corner + shadow -----
        _cardView = [UIView new];
        _cardView.translatesAutoresizingMaskIntoConstraints = NO;
        _cardView.backgroundColor = GM.AppForegroundColor; // your foreground color
        _cardView.layer.cornerRadius = 16.0;
        _cardView.layer.masksToBounds = NO; // must be NO for shadow to appear
        [_cardView pp_setShadowColor:[UIColor colorWithWhite:0 alpha:0.25]];
        _cardView.layer.shadowOpacity = 0.18;
        _cardView.layer.shadowOffset = CGSizeMake(0, 4);
        _cardView.layer.shadowRadius = 10;
        _cardView.layer.shouldRasterize = YES; // perf
        _cardView.layer.rasterizationScale = UIScreen.mainScreen.scale;
        [self.contentView addSubview:_cardView];

        // ----- Subviews -----
        _thumbView = [UIImageView new];
        _thumbView.translatesAutoresizingMaskIntoConstraints = NO;
        _thumbView.contentMode = UIViewContentModeScaleAspectFill;
        _thumbView.clipsToBounds = YES;
        _thumbView.layer.cornerRadius = 16;

        _badgeLabel = [PPInsetLabel new];
        _badgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _badgeLabel.textInsets   = UIEdgeInsetsMake(3, 15, 3, 15); // ↑ inner padding
        _badgeLabel.numberOfLines = 1;
        _badgeLabel.layer.cornerRadius = 15;
        _badgeLabel.clipsToBounds = YES;
        _badgeLabel.backgroundColor = GM.backOffwhileColor; // your foreground color
        _badgeLabel.font = [GM fontWithSize:14];
        _badgeLabel.textColor = GM.appPrimaryColor;
        _badgeLabel.textAlignment = NSTextAlignmentCenter;
        _badgeLabel.layer.borderWidth = 1.0;
        [_badgeLabel pp_setBorderColor:GM.AppForegroundColor];
        // Make it hug content and expand as needed
        //[_badgeLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        //[_badgeLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];


        _titleLabel = [UILabel new];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [GM MidFontWithSize:16];
        _titleLabel.textColor = GM.PrimaryTextColor;
        _titleLabel.numberOfLines = 1;

        _subtitleLabel = [UILabel new];
        _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _subtitleLabel.font = [GM MidFontWithSize:14];
        _subtitleLabel.textColor = GM.SecondaryTextColor;
        _subtitleLabel.numberOfLines = 2;

        [_cardView addSubview:_thumbView];
        [_cardView addSubview:_titleLabel];
        [_cardView addSubview:_subtitleLabel];
        [_cardView addSubview:_badgeLabel];

        // ----- Constraints -----
        CGFloat outer = 3.0;   // padding around the card
        CGFloat inner = 3.0;  // padding inside the card

        [NSLayoutConstraint activateConstraints:@[
            // Card fills cell with outer insets (adds nice vertical spacing + no separators needed)
            [_cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:outer],
            [_cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-outer],
            [_cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:outer],
            [_cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-outer],

            // Thumb on the left inside the card
            [_thumbView.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:inner],
            [_thumbView.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:inner],
            [_thumbView.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor constant:-inner],
            [_thumbView.widthAnchor constraintEqualToConstant:90],
            [_thumbView.heightAnchor constraintGreaterThanOrEqualToConstant:56],

            
            [_badgeLabel.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor],
            [_badgeLabel.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:0],
            
            // Title (top-right)
            [_titleLabel.leadingAnchor constraintEqualToAnchor:_thumbView.trailingAnchor constant:15],
            [_titleLabel.topAnchor constraintEqualToAnchor:_thumbView.topAnchor constant:10],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-inner],

            // Subtitle (under title)
            [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_subtitleLabel.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-inner],
            [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4],

            // Badge (under subtitle)
            // Badge (under subtitle)
       
            // Let height come from font + insets; just keep a floor:
           // [_badgeLabel.heightAnchor constraintGreaterThanOrEqualToConstant:20],

                // Optional minimum width:
                // [_badgeLabel.widthAnchor constraintGreaterThanOrEqualToConstant:60],

            [_badgeLabel.bottomAnchor constraintLessThanOrEqualToAnchor:_cardView.bottomAnchor constant:-inner]
            
        ]];
        

        // Hugging/compression priorities
        [_badgeLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [_badgeLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [_titleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
        [_subtitleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
        [_badgeLabel.heightAnchor constraintEqualToConstant:30.0].active = YES;
        _badgeLabel.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMinYCorner;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    // Precise shadow path for better performance & correct rounded shadow
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:self.cardView.bounds cornerRadius:self.cardView.layer.cornerRadius];
    self.cardView.layer.shadowPath = path.CGPath;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.thumbView.image = nil;
    self.titleLabel.text = @"";
    self.subtitleLabel.text = @"";
    self.badgeLabel.text = @"";
    self.badgeLabel.backgroundColor = GM.backOffwhileColor;
}

/*
 "Veterinary" = "بيطري";
 "Accessories" = "إكسسوارات";
 "Ads" = "إعلانات";
 "services" = "خدمات";
 */


- (void)configureWithItem:(SearchResultItem *)item {
    NSString *badgeText;
    switch (item.type) {
        case SearchResultTypePetAd:     badgeText = kLang(@"Ads");         break;
        case SearchResultTypeAccessory: badgeText = kLang(@"Accessories"); break;
        case SearchResultTypeService:   badgeText = kLang(@"services");    break;
        case SearchResultTypeVet:       badgeText = kLang(@"Veterinary");  break;
        case SearchResultTypeFood:      badgeText = kLang(@"food");        break;
        default:                        badgeText = @"";
    }
    self.badgeLabel.text = badgeText ?: @"";
    self.titleLabel.text = item.titleText ?: @"";
    self.subtitleLabel.text = item.subtitleText ?: @"";

    if (item.imageURLString.length > 0) {
        [GM setImageFromUrlString:item.imageURLString imageView:self.thumbView phImage:@"placeholder"];
    } else {
        self.thumbView.image = [UIImage imageNamed:@"placeholder"];
    }
}



@end
