//
//  PPChildCell 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 21/12/2025.
//


//
//  PPChildCell.m
//  Pure Pets
//

#import "PPChildCell.h"
 
@interface PPChildCell ()

@property (nonatomic, strong) UIView *cardView;

@property (nonatomic, strong) UIImageView *childImageView;
@property (nonatomic, strong) UILabel *ringIDLabel;
@property (nonatomic, strong) UILabel *birthDateLabel;
@property (nonatomic, strong) UIButton *optionsButton;

@property (nonatomic, strong) ChildModel *child;
@property (nonatomic, copy) NSString *currentImageURLString;

@property NSString *showCardTitle;
@property NSString *deleteCardTitle;
@property NSString *archiveCardTitle;
@property NSString *transferTitle;
@property NSString *sellTitle;
@property TTGSnackbar *snakBar;
@end

@implementation PPChildCell

#pragma mark - Init

+ (NSString *)reuseIdentifier
{
    return @"PPChildCell";
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupUI];
    }
    return self;
}

#pragma mark - UI

- (void)setupUI
{
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = AppClearClr;
    
    self.showCardTitle    = kLang(@"menu_showCard");
    self.deleteCardTitle  = kLang(@"menu_deleteChick");
    self.archiveCardTitle = kLang(@"menu_archiveChick");
    self.transferTitle    = kLang(@"menu_transferChick");
    self.sellTitle        = kLang(@"menu_sellChick");
    
    // Card container
    self.cardView = [[UIView alloc] init];
    self.cardView.translatesAutoresizingMaskIntoConstraints = NO;
    self.cardView.backgroundColor = AppForgroundColr;
    self.cardView.layer.cornerRadius = 26;
    self.cardView.layer.shadowColor = AppShadowClr.CGColor;
    self.cardView.layer.shadowOpacity = 0.12;
    self.cardView.layer.shadowRadius = 8;
    self.cardView.layer.shadowOffset = CGSizeMake(0, 2);

    [self.contentView addSubview:self.cardView];

    // Image
    self.childImageView = [[UIImageView alloc] init];
    self.childImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.childImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.childImageView.layer.cornerRadius = 22;
    self.childImageView.clipsToBounds = YES;
    self.childImageView.image = [UIImage imageNamed:@"placeholder3"];

    // Labels
    self.ringIDLabel = [[UILabel alloc] init];
    self.ringIDLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.ringIDLabel.font = [GM boldFontWithSize:16];
    self.ringIDLabel.textColor = AppPrimaryTextClr;

    self.birthDateLabel = [[UILabel alloc] init];
    self.birthDateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.birthDateLabel.font = [GM MidFontWithSize:13];
    self.birthDateLabel.textColor = UIColor.secondaryLabelColor;

    // Options button
    UIButtonConfiguration *cfg;
    if (@available(iOS 26.0, *)) {
        cfg = [UIButtonConfiguration glassButtonConfiguration];
    } else {
        cfg = [UIButtonConfiguration plainButtonConfiguration];
    }

    cfg.image = [UIImage systemImageNamed:@"ellipsis"];
    cfg.baseForegroundColor = AppPrimaryTextClr;

    
    self.optionsButton = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    self.optionsButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.optionsButton addTarget:self
                           action:@selector(showOptions)
                 forControlEvents:UIControlEventTouchUpInside];

    // Add subviews
    [self.cardView addSubview:self.childImageView];
    [self.cardView addSubview:self.ringIDLabel];
    [self.cardView addSubview:self.birthDateLabel];
    [self.cardView addSubview:self.optionsButton];

    [self setupConstraints];
}

- (void)setupConstraints
{
    [NSLayoutConstraint activateConstraints:@[
        // Card
        [self.cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [self.cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [self.cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8],

        // Image
        [self.childImageView.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:12],
        [self.childImageView.centerYAnchor constraintEqualToAnchor:self.cardView.centerYAnchor],
        [self.childImageView.widthAnchor constraintEqualToConstant:44],
        [self.childImageView.heightAnchor constraintEqualToConstant:44],

        // Options
        [self.optionsButton.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-8],
        [self.optionsButton.centerYAnchor constraintEqualToAnchor:self.cardView.centerYAnchor],

        // Ring ID
        [self.ringIDLabel.leadingAnchor constraintEqualToAnchor:self.childImageView.trailingAnchor constant:12],
        [self.ringIDLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.optionsButton.leadingAnchor constant:-8],
        [self.ringIDLabel.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:14],

        // Birth date
        [self.birthDateLabel.leadingAnchor constraintEqualToAnchor:self.ringIDLabel.leadingAnchor],
        [self.birthDateLabel.topAnchor constraintEqualToAnchor:self.ringIDLabel.bottomAnchor constant:4],
        [self.birthDateLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.optionsButton.leadingAnchor constant:-8],
    ]];
}

#pragma mark - Configure

- (void)configureWithChild:(ChildModel *)child
{
    self.child = child;
    self.currentImageURLString = nil;

    self.ringIDLabel.text =
    [NSString stringWithFormat:@"%@ %@", kLang(@"child_ring_id"), child.ChildRingID ?: @"—"];

    if (child.BirthDate) {
        NSDateFormatter *df = [NSDateFormatter new];
        df.dateStyle = NSDateFormatterMediumStyle;
        self.birthDateLabel.text =
        [NSString stringWithFormat:@"%@ %@",
         kLang(@"child_birth_date"),
         [df stringFromDate:child.BirthDate]];
    } else {
        self.birthDateLabel.text = kLang(@"child_birth_date_unknown");
    }

    self.childImageView.image = [UIImage imageNamed:@"placeholder3"];

    NSString *imageURLString = child.card.imagesUrls.firstObject.absoluteString ?: @"";
    if (imageURLString.length > 0) {
        self.currentImageURLString = imageURLString;
        [GM setImageFromUrlString:imageURLString
                        imageView:self.childImageView
                          phImage:@"placeholder3"];
    }
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.child = nil;
    self.currentImageURLString = nil;
    self.ringIDLabel.text = @"";
    self.birthDateLabel.text = @"";
    self.childImageView.image = [UIImage imageNamed:@"placeholder3"];
}

#pragma mark - Actions
 
- (void)showOptions
{
    
   
    __weak typeof(self) weakSelf = self;

    NSArray<NSString *> *titles = @[
        self.showCardTitle,
        self.archiveCardTitle,
        self.deleteCardTitle,
        self.transferTitle,
        self.sellTitle
    ];
    
    NSArray<UIImage *> *titlesImages = @[
        [UIImage imageNamed:@"dogCus"],//dogCus
        [UIImage imageNamed:@"archiveCus"],
        [UIImage imageNamed:@"deleteCus"],
        [UIImage imageNamed:@"love-birdsCus"],
        [UIImage imageNamed:@"hotSaleee"]
    ];
    NSIndexSet *destructive = [NSIndexSet indexSetWithIndex:2];

    [PPMenuHelper presentMenuFromButton:self.optionsButton
                                 titles:titles
                                 images:titlesImages destructive:destructive handler:^(NSInteger index, NSString * _Nonnull title) {
        
        switch (index) {
            case 0:
                [weakSelf showCard];
                break;

            case 1:
                [weakSelf.delegate archiveCardData:weakSelf.child.card Child:weakSelf.child];
                 break;

            case 2:
                [weakSelf confirmDeleteChild:weakSelf.child];
                break;

            case 3:
                [weakSelf.delegate transferChild:weakSelf.child cardID:weakSelf.child.card];
                break;

            case 4:
                [weakSelf.delegate sellChild:weakSelf.child cardID:weakSelf.child.card];
                break;

            default:
                break;
        }
    }];
}


- (void)confirmDeleteChild:(ChildModel *)child
{
    __weak typeof(self) weakSelf = self;

    NSString *title = kLang(@"delete_child_title");
    NSString *subtitle =
    [NSString stringWithFormat:kLang(@"delete_child_message_fmt"),
     child.ChildRingID];

    [PPAlertHelper showConfirmationIn:AppMgr.topViewController
                                title:title
                             subtitle:subtitle
                        confirmButton:kLang(@"delete")
                         cancelButton:kLang(@"cancel")
                                 icon:nil
                         confirmBlock:^(NSString * _Nullable text, BOOL didConfirm)
    {
        if (!didConfirm) return;
        [weakSelf.delegate DeleteChild:weakSelf.child FromCageWithID:weakSelf.child.CageID];
    }cancelBlock:^{}];
}


-(void)showCard
{
   
 
        NSString *title = kLang(@"child_no_card_title");
        NSString *subtitle = [NSString stringWithFormat:
                              kLang(@"child_no_card_message_fmt"),
                              self.child.card.ID];

        [PPAlertHelper showConfirmationIn:AppMgr.topViewController
                                    title:title
                                 subtitle:subtitle
                            confirmButton:kLang(@"yes")
                             cancelButton:kLang(@"no")
                                     icon:nil
                             confirmBlock:^(NSString * _Nullable text, BOOL didConfirm)
        {
            if (!didConfirm) return;

           /* [weakSelf.delegate goToNewCard:weakSelf.BirdRingID
                                    fromVC:@"selectChildViewController"
                                   isFound:YES
                                 ImagesArr:weakSelf.ImagesArr
                                    cardID:weakSelf.cardID]; */
        }
                             cancelBlock:^{
                                 // no-op
                             }];

 
  //      [self.delegate goToNewCard:self.child.card fromVC:@"selectChildViewController" isFound:self.isFound ImagesArr:self.ImagesArr cardID:self.cardID];
  
}
@end
