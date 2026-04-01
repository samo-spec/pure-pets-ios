//
//  SalesCell 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 23/12/2025.
//


#import "SalesCell.h"
#import "importantFiles.h"
#import "PPMenuHelper.h"
#import "PPSalesPDFGenerator.h"

@interface SalesCell ()

@property (nonatomic, strong) BuyerModel *buyer;
@property (nonatomic, strong) CardModel *card;

// UI
@property (nonatomic, strong) UIImageView *birdImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *metaLabel;
@property (nonatomic, strong) UILabel *priceLabel;

@property (nonatomic, strong) UIView *buyerContainer;
@property (nonatomic, strong) UILabel *buyerNameLabel;
@property (nonatomic, strong) UILabel *buyerPhoneLabel;
@property (nonatomic, strong) UILabel *buyerLocationLabel;

@property (nonatomic, strong) UIButton *callButton;
@property (nonatomic, strong) UIButton *whatsAppButton;
@property (nonatomic, strong) UIButton *menuButton;

@end


@implementation SalesCell

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self buildUI];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.birdImageView.image = nil;
}

#pragma mark - Public

- (void)configureWithBuyer:(BuyerModel *)buyer card:(CardModel *)card {
    self.buyer = buyer;
    self.card  = card;

    self.titleLabel.text = card.CardTitle ?: @"—";
    self.metaLabel.text  =
    [NSString stringWithFormat:@"%@ • %@",
     card.RingID ?: @"",
     [GM formattedDate:buyer.sellDate]];

    self.priceLabel.text =
    [NSString stringWithFormat:@"%@ %@", buyer.buyerPrice ?: @"—", kLang(@"currency")];

    self.buyerNameLabel.text  = buyer.buyerName ?: @"—";
    self.buyerPhoneLabel.text = [PPFunc formattedPhoneNumber:buyer.buyerMobile];

    

    // Resolve city safely (buyer city OR country default)
    CityModel *city = buyer.resolvedCity;
   
    
    CountryModel *country = city.country ?: [CountryModel safeUserCountryModel];
    
    
    NSMutableArray *loc = [NSMutableArray array];
    if (country.name.length) [loc addObject:country.name];
    if (city.name.length)    [loc addObject:city.name];

    self.buyerLocationLabel.text =
    loc.count ? [loc componentsJoinedByString:@" · "] : @"—";

    // Image
    if (card.imagesUrls.firstObject) {
        
        [GM setImageFromUrlString:card.imagesUrls.firstObject.absoluteString imageView:self.birdImageView phImage:@"placeholder3" completion:^(UIImage * _Nullable image, NSError * _Nullable error) {
            if(!image)
            {
                NSLog(@"NO IMAGES Url %@", card.imagesUrls.firstObject.absoluteString);
                self.birdImageView.image = [UIImage imageNamed:@"placeholder3"];
                 dispatch_async(dispatch_get_main_queue(), ^{
                    [self setNeedsLayout];
                    [self layoutIfNeeded];
                });
            }
        }];
        
        
 
    }
}

#pragma mark - UI

- (void)buildUI {

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.whiteColor;
    self.contentView.layer.cornerRadius = 28;
    self.contentView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.contentView.layer.shadowOpacity = 0.08;
    self.contentView.layer.shadowRadius = 10;
    self.contentView.layer.shadowOffset = CGSizeMake(0, 4);

    // Bird image
    _birdImageView = [UIImageView new];
    _birdImageView.layer.cornerRadius = 20;
    _birdImageView.clipsToBounds = YES;
    _birdImageView.contentMode = UIViewContentModeScaleAspectFill;
    _birdImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_birdImageView];

    // Labels
    _titleLabel = [self label:[GM boldFontWithSize:17]];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_titleLabel];
    _metaLabel  = [self label:[GM MidFontWithSize:13]];
    _metaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_metaLabel];
    _priceLabel = [self label:[GM boldFontWithSize:18]];
    _priceLabel.textColor = AppPrimaryClr;
    _priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_priceLabel];
    // Buyer container
    _buyerContainer = [UIView new];
    _buyerContainer.backgroundColor = [UIColor colorWithWhite:0.97 alpha:1];
    _buyerContainer.layer.cornerRadius = 20;
    _buyerContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_buyerContainer];

    _buyerNameLabel     = [self label:[GM boldFontWithSize:14]];
    _buyerNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _buyerPhoneLabel    = [self label:[GM MidFontWithSize:13]];
    _buyerPhoneLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _buyerLocationLabel = [self label:[GM MidFontWithSize:12]];
    _buyerLocationLabel.textColor = UIColor.secondaryLabelColor;
    _buyerLocationLabel.translatesAutoresizingMaskIntoConstraints = NO;

    // Buttons
    _callButton = [self glassButton:@"phone.fill" action:@selector(callTapped)];
    _callButton.translatesAutoresizingMaskIntoConstraints = NO;
    _whatsAppButton = [self glassButton:@"message.fill" action:@selector(whatsAppTapped)];
    _whatsAppButton.translatesAutoresizingMaskIntoConstraints = NO;
    _menuButton = [self glassButton:@"ellipsis" action:@selector(showMenu)];
    _menuButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_menuButton];   // ✅ MISSING LINE
    // Add subviews to buyer container
    [_buyerContainer addSubview:_buyerNameLabel];
    [_buyerContainer addSubview:_buyerPhoneLabel];
    [_buyerContainer addSubview:_buyerLocationLabel];
    [_buyerContainer addSubview:_callButton];
    [_buyerContainer addSubview:_whatsAppButton];

    [self setupConstraints];
}

- (void)setupConstraints
{
    CGFloat pad = 14;

    // Bird image
    [NSLayoutConstraint activateConstraints:@[
        [self.birdImageView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:pad],
        [self.birdImageView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:pad],
        [self.birdImageView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-pad],
        [self.birdImageView.widthAnchor constraintEqualToAnchor:self.contentView.widthAnchor multiplier:0.33]
    ]];

    // Menu button
    [NSLayoutConstraint activateConstraints:@[
        [self.menuButton.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:pad],
        [self.menuButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-pad],
        [self.menuButton.widthAnchor constraintEqualToConstant:32],
        [self.menuButton.heightAnchor constraintEqualToConstant:32]
    ]];

    // Title
    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.birdImageView.trailingAnchor constant:pad],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.menuButton.leadingAnchor constant:-8],
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:pad]
    ]];

    // Meta
    [NSLayoutConstraint activateConstraints:@[
        [self.metaLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.metaLabel.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],
        [self.metaLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4]
    ]];

    // Price
    [NSLayoutConstraint activateConstraints:@[
        [self.priceLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.priceLabel.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],
        [self.priceLabel.topAnchor constraintEqualToAnchor:self.metaLabel.bottomAnchor constant:8]
    ]];

    // Buyer container
    [NSLayoutConstraint activateConstraints:@[
        [self.buyerContainer.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.buyerContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-pad],
        [self.buyerContainer.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-pad],
        [self.buyerContainer.heightAnchor constraintEqualToConstant:80]
    ]];

    // Buyer name
    [NSLayoutConstraint activateConstraints:@[
        [self.buyerNameLabel.leadingAnchor constraintEqualToAnchor:self.buyerContainer.leadingAnchor constant:14],
        [self.buyerNameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.callButton.leadingAnchor constant:-8],
        [self.buyerNameLabel.topAnchor constraintEqualToAnchor:self.buyerContainer.topAnchor constant:12]
    ]];

    // Buyer phone
    [NSLayoutConstraint activateConstraints:@[
        [self.buyerPhoneLabel.leadingAnchor constraintEqualToAnchor:self.buyerNameLabel.leadingAnchor],
        [self.buyerPhoneLabel.trailingAnchor constraintEqualToAnchor:self.buyerNameLabel.trailingAnchor],
        [self.buyerPhoneLabel.topAnchor constraintEqualToAnchor:self.buyerNameLabel.bottomAnchor constant:4]
    ]];

    // Buyer location
    [NSLayoutConstraint activateConstraints:@[
        [self.buyerLocationLabel.leadingAnchor constraintEqualToAnchor:self.buyerNameLabel.leadingAnchor],
        [self.buyerLocationLabel.trailingAnchor constraintEqualToAnchor:self.buyerNameLabel.trailingAnchor],
        [self.buyerLocationLabel.topAnchor constraintEqualToAnchor:self.buyerPhoneLabel.bottomAnchor constant:4]
    ]];

    // Call button
    [NSLayoutConstraint activateConstraints:@[
        [self.callButton.trailingAnchor constraintEqualToAnchor:self.buyerContainer.trailingAnchor constant:-52],
        [self.callButton.centerYAnchor constraintEqualToAnchor:self.buyerContainer.centerYAnchor],
        [self.callButton.widthAnchor constraintEqualToConstant:32],
        [self.callButton.heightAnchor constraintEqualToConstant:32]
    ]];

    // WhatsApp button
    [NSLayoutConstraint activateConstraints:@[
        [self.whatsAppButton.trailingAnchor constraintEqualToAnchor:self.buyerContainer.trailingAnchor constant:-14],
        [self.whatsAppButton.centerYAnchor constraintEqualToAnchor:self.buyerContainer.centerYAnchor],
        [self.whatsAppButton.widthAnchor constraintEqualToConstant:32],
        [self.whatsAppButton.heightAnchor constraintEqualToConstant:32]
    ]];
    
    
    [self showMenu];
}

#pragma mark - Actions

- (void)callTapped {
    [self.delegate Buyercall:self.buyer];
}

- (void)whatsAppTapped {
    [self.delegate BuyerWhatsAppMessage:self.buyer];
}

- (void)showMenu {

    NSArray *titles = @[
        kLang(@"Details"),
        kLang(@"printBill"),
        kLang(@"Return")
    ];

    NSArray *icons = @[
        [UIImage systemImageNamed:@"doc.text"],
        [UIImage systemImageNamed:@"printer"],
        [UIImage systemImageNamed:@"arrow.uturn.left"]
    ];

    NSIndexSet *destructive = [NSIndexSet indexSetWithIndex:2];

    [PPMenuHelper presentMenuFromButton:self.menuButton
                                 titles:titles
                                 images:icons
                           destructive:destructive
                               handler:^(NSInteger index, NSString *title) {

        switch (index) {
            case 0:
                [self.delegate showDetails:self.buyer cardModel:self.card];
                break;
            case 1:
                [self.delegate exportSalesBillForBuyer:self.buyer card:self.card sender:self.menuButton];
                break;
            case 2:
                [self.delegate returnCard:self.buyer buyerCell:self ];
                break;
        }
    }];
}

#pragma mark - Helpers

- (UILabel *)label:(UIFont *)font {
    UILabel *l = [UILabel new];
    l.font = font;
    l.textColor = AppPrimaryTextClr;

    return l;
}

- (UIButton *)glassButton:(NSString *)systemName action:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];

    if (@available(iOS 26.0, *)) {
        b.configuration = [UIButtonConfiguration glassButtonConfiguration];
    } else {
        UIButtonConfiguration *cfg = [UIButtonConfiguration filledButtonConfiguration];
        cfg.baseBackgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
        cfg.baseForegroundColor = AppPrimaryClr;
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        b.configuration = cfg;
        b.clipsToBounds = YES;
    }

    [b setImage:[UIImage systemImageNamed:systemName] forState:UIControlStateNormal];
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}

@end
