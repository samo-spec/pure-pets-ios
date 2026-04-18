//
//  PPCageCell 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 20/12/2025.
//


#import "PPCageCell.h"
#import "CageModel.h"
#import "PPBirdCardView.h"


@interface PPCageCell () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) CageModel *cage;

/* Top */
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *editButton;
@property (nonatomic, strong) UIButton *barcodeButton;

@property (nonatomic, strong) UIStackView *parentsRow;

/* Parent cards */
@property (nonatomic, strong) PPBirdCardView *fatherView; 
@property (nonatomic, strong) PPBirdCardView *motherView;
@property (nonatomic, strong) UITapGestureRecognizer *fatherTapGesture;
@property (nonatomic, strong) UITapGestureRecognizer *motherTapGesture;

/* Chicks */
@property (nonatomic, strong) UIView *countElementContainer;
@property (nonatomic, strong) UILabel *chicksCountLabel;
@property (nonatomic, strong) UIButton *addChickButton;

/* Egg */
@property (nonatomic, strong) UILabel *eggDateLabel;
@property (nonatomic, strong) UIButton *setEggButton;

/* Container */
@property (nonatomic, strong) UIView *cardContainer;
@end

@implementation PPCageCell
+ (NSString *)reuseIdentifier { return @"PPCageCell"; }

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        LOG_EMOJI_INFO(@"PPCageCell init");
        [self buildUI];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    LOG_EMOJI_DEBUG(@"PPCageCell prepareForReuse");
    self.cage = nil;
    self.titleLabel.text = @"";
    self.chicksCountLabel.text = @"";
    self.eggDateLabel.text = kLang(@"first_egg_not_set");
    [self.fatherView configureWithCard:nil ringID:nil isFather:YES];
    [self.fatherView setStatus:PPBirdCardStatusNormal archiveName:nil];
    [self.motherView configureWithCard:nil ringID:nil isFather:NO];
    [self.motherView setStatus:PPBirdCardStatusNormal archiveName:nil];
}
#pragma mark - Configure

/*
 - (void)configureWithCage:(CageModel *)cage {
     self.cage = cage;
     LOG_EMOJI_INFO(@"Configure cage cell: %@", cage.CageName);

     self.titleLabel.text = cage.CageName ?: @"";

     // Parents
     [self.fatherView configureWithCard:cage.FatherCard
                                 ringID:cage.FatherCard.subKindString
                            isFather:YES];

     [self.motherView configureWithCard:cage.MotherCard
                                 ringID:cage.MotherCard.subKindString
                            isFather:NO];
     
  
     self.chicksCountLabel.text =
     [NSString stringWithFormat:@"%@: %ld",
      kLang(@"chicks_count"),
      (long)cage.childsCount];
     self.countElementContainer.backgroundColor = cage.childsCount > 0 ? [PPColorUtils pp_selectedCellColorFromPrimary] : AppBackgroundClr;
     NSString *btnTitle =
     cage.childsCount > 0
     ? kLang(@"add_more_chicks")
     : kLang(@"add_chick");

     if (@available(iOS 26.0, *)) {
         self.addChickButton.configuration.title = btnTitle;
     } else {
         [self.addChickButton setTitle:btnTitle forState:UIControlStateNormal];
     }
     
     
   
     // Egg date
     if (cage.FristEggDate) {
         NSDateFormatter *df = [NSDateFormatter new];
         df.dateStyle = NSDateFormatterMediumStyle;
         self.eggDateLabel.text =
         [NSString stringWithFormat:@"%@ %@",
          kLang(@"first_egg_date_title"),
          [df stringFromDate:cage.FristEggDate]];
     } else {
         self.eggDateLabel.text = kLang(@"first_egg_not_set");
     }
     
     [self configureParentMenus];
     
     
 }
 */
- (void)configureWithCage:(CageModel *)cage
{
    NSParameterAssert(cage);
    self.cage = cage;

    self.titleLabel.text = cage.CageName ?: @"";

    [self configureFatherWithCage:cage];
    [self configureMotherWithCage:cage];

    // Chicks
    self.chicksCountLabel.text =
    [NSString stringWithFormat:@"%@: %ld",
     kLang(@"chicks_count"),
     (long)cage.childsCount];

    NSString *btnTitle =
    cage.childsCount > 0
    ? kLang(@"add_more_chicks")
    : kLang(@"add_chick");

    if (@available(iOS 26.0, *)) {
        self.addChickButton.configuration.title = btnTitle;
    } else {
        [self.addChickButton setTitle:btnTitle forState:UIControlStateNormal];
        self.addChickButton.titleLabel.textColor = AppPrimaryClr;
    }

    // Egg date
    if (cage.FristEggDate) {
        NSDateFormatter *df = [NSDateFormatter new];
        df.dateStyle = NSDateFormatterMediumStyle;
        self.eggDateLabel.text =
        [NSString stringWithFormat:@"%@ %@",
         kLang(@"first_egg_date_title"),
         [df stringFromDate:cage.FristEggDate]];
    } else {
        self.eggDateLabel.text = kLang(@"first_egg_not_set");
    }

    [self configureParentMenus];
}
#pragma mark - UI

- (void)buildUI {

    self.contentView.backgroundColor = AppClearClr;

    /* Card container */
    self.cardContainer = [UIView new];
    self.cardContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.cardContainer.backgroundColor = AppForgroundColr;
    self.cardContainer.layer.cornerRadius = 26;
    [self.cardContainer pp_setShadowColor:UIColor.blackColor];
    self.cardContainer.layer.shadowOpacity = 0.08;
    self.cardContainer.layer.shadowRadius = 10;
    [self.contentView addSubview:self.cardContainer];

    /* Title */
    self.titleLabel = [UILabel new];
    self.titleLabel.font = [GM boldFontWithSize:17];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    UIImage *editImage =
    [UIImage pp_symbolNamed:@"pencil.line"
                  pointSize:16
                     weight:UIImageSymbolWeightSemibold
                      scale:UIImageSymbolScaleLarge
                    palette:@[AppPrimaryClr,UIColor.darkGrayColor]
                makeTemplate:YES];
    
    UIImage *addImage =
    [UIImage pp_symbolNamed:@"plus"
                  pointSize:16
                     weight:UIImageSymbolWeightSemibold
                      scale:UIImageSymbolScaleMedium
                    palette:@[AppPrimaryClr,UIColor.darkGrayColor]
                makeTemplate:YES];
        
    self.editButton = [self glassButton:editImage];
    
    UIImage *barcodeImage =
    [UIImage pp_symbolNamed:@"barcode.viewfinder"
                  pointSize:16
                     weight:UIImageSymbolWeightSemibold
                      scale:UIImageSymbolScaleLarge
                    palette:@[UIColor.darkGrayColor,AppPrimaryClr]
                makeTemplate:YES];

    self.barcodeButton.tintColor = AppPrimaryClr;
    self.barcodeButton = [self glassButton:barcodeImage];

    [self.editButton addTarget:self action:@selector(editTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.barcodeButton addTarget:self action:@selector(barcodeTapped) forControlEvents:UIControlEventTouchUpInside];
    
    

    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
        cfg.image = editImage; // or barcodeImage
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(2, 2,2, 2);
        self.editButton.configuration = cfg;
        
        
        UIButtonConfiguration *cfgbarcodeButton = [UIButtonConfiguration glassButtonConfiguration];
        cfgbarcodeButton.image = barcodeImage; // or barcodeImage
        cfgbarcodeButton.contentInsets = NSDirectionalEdgeInsetsMake(8, 8, 8, 8);
        cfgbarcodeButton.preferredSymbolConfigurationForImage = [UIImageSymbolConfiguration configurationPreferringMulticolor];
        self.barcodeButton.configuration = cfgbarcodeButton;
    } else {
        [self.editButton setImage:editImage forState:UIControlStateNormal];
        self.editButton.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.08];
        self.editButton.layer.cornerRadius = 18;
        self.editButton.clipsToBounds = YES;

        [self.barcodeButton setImage:barcodeImage forState:UIControlStateNormal];
        self.barcodeButton.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.08];
        self.barcodeButton.layer.cornerRadius = 18;
        self.barcodeButton.clipsToBounds = YES;
    }
    
    
    // Container
    self.countElementContainer = [[UIView alloc] init];
    self.countElementContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.countElementContainer.backgroundColor = AppBackgroundClr;
    self.countElementContainer.layer.cornerRadius = 23;
    self.countElementContainer.layer.masksToBounds = NO;

    // Shadow
    //self.countElementContainer.layer.shadowColor = AppShadowClr.CGColor;
    //self.countElementContainer.layer.shadowOpacity = 0.12;
    //self.countElementContainer.layer.shadowOffset = CGSizeMake(0, 3);
    //self.countElementContainer.layer.shadowRadius = 8;

    // Label
    self.chicksCountLabel = [[UILabel alloc] init];
    self.chicksCountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.chicksCountLabel.font = [GM boldFontWithSize:14];
    self.chicksCountLabel.textColor = UIColor.labelColor;
    self.chicksCountLabel.textAlignment = GM.setAligment;
    self.chicksCountLabel.numberOfLines = 1;

    // Button
    self.addChickButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.addChickButton.translatesAutoresizingMaskIntoConstraints = NO;

    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.title = kLang(@"add_chick");
        cfg.image = addImage;
        cfg.imagePadding = 8; // ✅ spacing between image & text
        cfg.baseForegroundColor = AppPrimaryClr;

        cfg.titleTextAttributesTransformer =
        ^NSDictionary<NSAttributedStringKey,id>*
        (NSDictionary<NSAttributedStringKey,id> *attrs) {
            NSMutableDictionary *m = attrs.mutableCopy;
            m[NSFontAttributeName] = [GM boldFontWithSize:14];
            return m;
        };

        cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 12, 6, 12);
        self.addChickButton.configuration = cfg;
    } else {
        [self.addChickButton setTitle:kLang(@"add_chick") forState:UIControlStateNormal];
        self.addChickButton.titleLabel.font = [GM MidFontWithSize:14];
        self.addChickButton.backgroundColor =
        [AppPrimaryClr colorWithAlphaComponent:0.08];
        self.addChickButton.layer.cornerRadius = 12;
        self.addChickButton.clipsToBounds = YES;
        self.addChickButton.titleLabel.textColor = AppPrimaryClr;
        self.addChickButton.titleEdgeInsets = UIEdgeInsetsMake(0, 8, 0, 8);
    }
    [self.addChickButton addTarget:self
                            action:@selector(addChickTapped)
                  forControlEvents:UIControlEventTouchUpInside];
    // Stack
    UIStackView *stack =
    [[UIStackView alloc] initWithArrangedSubviews:@[
        self.chicksCountLabel,
        self.addChickButton
    ]];

    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 10;
    stack.alignment = UIStackViewAlignmentFill;
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    [self.countElementContainer addSubview:stack];

    // Constraints inside container
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:self.countElementContainer.topAnchor constant:3],
        [stack.bottomAnchor constraintEqualToAnchor:self.countElementContainer.bottomAnchor constant:-3],
        [stack.leadingAnchor constraintEqualToAnchor:self.countElementContainer.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:self.countElementContainer.trailingAnchor constant:-3]
    ]];

    // 🔴 ADD TO self.parentsRow (IMPORTANT)
    [self.cardContainer addSubview:self.countElementContainer];

    UIStackView *titleRow =
    [[UIStackView alloc] initWithArrangedSubviews:@[
        self.titleLabel, self.editButton, self.barcodeButton
    ]];
    titleRow.axis = UILayoutConstraintAxisHorizontal;
    titleRow.spacing = 8;
    titleRow.translatesAutoresizingMaskIntoConstraints = NO;
    [self.cardContainer addSubview:titleRow];

    /* Parent cards */
    self.fatherView = [[PPBirdCardView alloc] initWithParentIs:ParentIsFather];
    self.motherView = [[PPBirdCardView alloc] initWithParentIs:ParentIsMother];

    //[self.fatherView showSoldState];
    //[self.motherView showDeletedState];
    
    
    _parentsRow =
    [[UIStackView alloc] initWithArrangedSubviews:@[
        self.fatherView, self.motherView
    ]];
    self.parentsRow.axis = UILayoutConstraintAxisHorizontal;
    self.parentsRow.spacing = 12;
    self.parentsRow.distribution = UIStackViewDistributionFillEqually;
    self.parentsRow.translatesAutoresizingMaskIntoConstraints = NO;
    
    
    [self.cardContainer addSubview:self.parentsRow];
    [self setupParentTapGestures];

    /* Egg row */
    self.eggDateLabel = [UILabel new];
    self.eggDateLabel.font = [GM boldFontWithSize:14];

    self.setEggButton = [self glassTextButton];
    [self.setEggButton setTitle:kLang(@"set_first_egg") forState:UIControlStateNormal];
    [self.setEggButton.titleLabel setFont:[GM boldFontWithSize:14]];
    
    self.setEggButton.configuration.titleTextAttributesTransformer =
    ^NSDictionary<NSAttributedStringKey,id> * (NSDictionary<NSAttributedStringKey,id> *attrs) {
        NSMutableDictionary *m = attrs.mutableCopy;
        m[NSFontAttributeName] = [GM MidFontWithSize:14];
        return m;
    };
    
    [self.setEggButton setFont:[GM boldFontWithSize:14]];
    self.setEggButton.titleLabel.font = [GM boldFontWithSize:14];
    [self.setEggButton addTarget:self action:@selector(setEggTapped) forControlEvents:UIControlEventTouchUpInside];

    if (@available(iOS 26.0, *)) {

        UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
        cfg.title = kLang(@"set_first_egg");
        cfg.baseForegroundColor = AppPrimaryClr;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 12, 6, 12);

        cfg.titleTextAttributesTransformer =
        ^NSDictionary<NSAttributedStringKey,id> * (NSDictionary<NSAttributedStringKey,id> *attrs) {

            NSMutableDictionary *m = attrs.mutableCopy;
            m[NSFontAttributeName] = [GM boldFontWithSize:14]; // ✅ THIS IS THE FONT
            return m;
        };

        self.setEggButton.configuration = cfg;
    } else {
        [self.setEggButton setTitle:kLang(@"set_first_egg") forState:UIControlStateNormal];
        [self.setEggButton setTitleColor:AppPrimaryClr forState:UIControlStateNormal];
        self.setEggButton.titleLabel.font = [GM boldFontWithSize:14];
        self.setEggButton.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.08];
        self.setEggButton.layer.cornerRadius = 12;
        self.setEggButton.clipsToBounds = YES;
        self.setEggButton.contentEdgeInsets = UIEdgeInsetsMake(6, 12, 6, 12);
    }
    
    
    UIStackView *eggRow =
    [[UIStackView alloc] initWithArrangedSubviews:@[
        self.eggDateLabel, self.setEggButton
    ]];
    eggRow.axis = UILayoutConstraintAxisHorizontal;
    eggRow.spacing = 8;
    eggRow.translatesAutoresizingMaskIntoConstraints = NO;
    [self.cardContainer addSubview:eggRow];

    /* Constraints */
    [NSLayoutConstraint activateConstraints:@[

        // Card container
        [self.cardContainer.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:0],
        [self.cardContainer.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-0],
        [self.cardContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
        [self.cardContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],

        // Title row
        [titleRow.topAnchor constraintEqualToAnchor:self.cardContainer.topAnchor constant:8],
        [titleRow.leadingAnchor constraintEqualToAnchor:self.cardContainer.leadingAnchor constant:16],
        [titleRow.trailingAnchor constraintEqualToAnchor:self.cardContainer.trailingAnchor constant:-16],
        [titleRow.heightAnchor constraintEqualToConstant:40],

        // Parents row
        [self.parentsRow.topAnchor constraintEqualToAnchor:titleRow.bottomAnchor constant:0],
        [self.parentsRow.leadingAnchor constraintEqualToAnchor:self.cardContainer.leadingAnchor constant:16],
        [self.parentsRow.trailingAnchor constraintEqualToAnchor:self.cardContainer.trailingAnchor constant:-16],

        // Count element container (AUTO HEIGHT)
        [self.countElementContainer.topAnchor constraintEqualToAnchor:self.parentsRow.bottomAnchor constant:8],
        [self.countElementContainer.leadingAnchor constraintEqualToAnchor:self.cardContainer.leadingAnchor constant:16],
        [self.countElementContainer.trailingAnchor constraintEqualToAnchor:self.cardContainer.trailingAnchor constant:-16],
        [self.countElementContainer.heightAnchor constraintEqualToConstant:48],

        // Egg row
        [eggRow.topAnchor constraintEqualToAnchor:self.countElementContainer.bottomAnchor constant:8],
        [eggRow.leadingAnchor constraintEqualToAnchor:self.cardContainer.leadingAnchor constant:20],
        [eggRow.trailingAnchor constraintEqualToAnchor:self.cardContainer.trailingAnchor constant:-16],
        [eggRow.heightAnchor constraintEqualToConstant:40],
        [eggRow.bottomAnchor constraintEqualToAnchor:self.cardContainer.bottomAnchor constant:-8],
    ]];
}

#pragma mark - Buttons

- (UIButton *)glassButton:(UIImage *)symbol {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.translatesAutoresizingMaskIntoConstraints = NO;

    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
        cfg.image = symbol;
        cfg.baseForegroundColor = AppPrimaryClr;
        btn.configuration = cfg;
    } else {
        [btn setImage:symbol forState:UIControlStateNormal];
        btn.tintColor = AppPrimaryClr;
        btn.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.08];
        btn.layer.cornerRadius = 20;
        btn.clipsToBounds = YES;
    }

    [btn.widthAnchor constraintEqualToConstant:40].active = YES;
    [btn.heightAnchor constraintEqualToConstant:40].active = YES;
    return btn;
}

- (UIButton *)glassTextButton {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.translatesAutoresizingMaskIntoConstraints = NO;

    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
        cfg.baseForegroundColor = AppPrimaryClr;
        cfg.attributedTitle =
        [[NSAttributedString alloc] initWithString:@"" attributes:@{NSFontAttributeName:[GM boldFontWithSize:14]}];
        btn.configuration = cfg;
    } else {
        btn.tintColor = AppPrimaryClr;
        btn.titleLabel.font = [GM boldFontWithSize:14];
        btn.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.08];
        btn.layer.cornerRadius = 12;
        btn.clipsToBounds = YES;
    }

    return btn;
}

#pragma mark - Actions

- (void)editTapped {
    LOG_EMOJI_ACTION(@"Edit cage");
    [self.delegate cageCellDidTapEdit:self.cage];
}

- (void)barcodeTapped {
    LOG_EMOJI_ACTION(@"Barcode tapped");
    [self.delegate cageCellDidTapBarcode:self.cage];
}

- (void)addChickTapped {
    LOG_EMOJI_ACTION(@"Add chick tapped cage %@ %@",self.cage.ID,self.cage.CageName);
    [self.delegate cageCellDidTapAddChick:self.cage];
}

- (void)setEggTapped {
    LOG_EMOJI_ACTION(@"Set egg date tapped");
    [self.delegate cageCellDidTapSetFirstEggDate:self.cage];
}

- (void)setupParentTapGestures
{
    self.fatherView.userInteractionEnabled = YES;
    self.motherView.userInteractionEnabled = YES;

    self.fatherTapGesture =
    [[UITapGestureRecognizer alloc] initWithTarget:self
                                            action:@selector(fatherCardTapped:)];
    self.fatherTapGesture.delegate = self;
    self.fatherTapGesture.cancelsTouchesInView = NO;
    [self.fatherView addGestureRecognizer:self.fatherTapGesture];

    self.motherTapGesture =
    [[UITapGestureRecognizer alloc] initWithTarget:self
                                            action:@selector(motherCardTapped:)];
    self.motherTapGesture.delegate = self;
    self.motherTapGesture.cancelsTouchesInView = NO;
    [self.motherView addGestureRecognizer:self.motherTapGesture];
}

- (void)fatherCardTapped:(UITapGestureRecognizer *)gesture
{
    if (gesture.state != UIGestureRecognizerStateEnded) return;

    CardModel *card = self.cage.FatherCard;
    if (!card) return;

    if ([self.delegate respondsToSelector:@selector(cageCellDidTapParentCard:fromCage:isFather:)]) {
        [self.delegate cageCellDidTapParentCard:card
                                       fromCage:self.cage
                                       isFather:YES];
    }
}

- (void)motherCardTapped:(UITapGestureRecognizer *)gesture
{
    if (gesture.state != UIGestureRecognizerStateEnded) return;

    CardModel *card = self.cage.MotherCard;
    if (!card) return;

    if ([self.delegate respondsToSelector:@selector(cageCellDidTapParentCard:fromCage:isFather:)]) {
        [self.delegate cageCellDidTapParentCard:card
                                       fromCage:self.cage
                                       isFather:NO];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
      shouldReceiveTouch:(UITouch *)touch
{
    UIView *touchedView = touch.view;
    if (!touchedView) return YES;

    if (self.fatherView.menuButton &&
        [touchedView isDescendantOfView:self.fatherView.menuButton]) {
        return NO;
    }

    if (self.motherView.menuButton &&
        [touchedView isDescendantOfView:self.motherView.menuButton]) {
        return NO;
    }

    return YES;
}

#pragma mark - Parent Menus

- (void)configureParentMenus
{
    __weak typeof(self) weakSelf = self;

    // Father menu
    self.fatherView.menuButton.menu =
    [UIMenu menuWithChildren:@[
        [UIAction actionWithTitle:kLang(@"archive")
                            image:[UIImage systemImageNamed:@"archivebox"]
                       identifier:nil
                          handler:^(__kindof UIAction * _Nonnull action) {
            if (!weakSelf.cage) return;
            [weakSelf.delegate cageCellDidArchiveParent:weakSelf.cage isFather:YES];
        }],

        [UIAction actionWithTitle:kLang(@"sale")
                            image:[UIImage systemImageNamed:@"tag"]
                       identifier:nil
                          handler:^(__kindof UIAction * _Nonnull action) {
            if (!weakSelf.cage) return;
            [weakSelf.delegate cageCellDidSellParent:weakSelf.cage isFather:YES];
        }]
    ]];

    self.fatherView.menuButton.showsMenuAsPrimaryAction = YES;

    // Mother menu
    self.motherView.menuButton.menu =
    [UIMenu menuWithChildren:@[
        [UIAction actionWithTitle:kLang(@"archive")
                            image:[UIImage systemImageNamed:@"archivebox"]
                       identifier:nil
                          handler:^(__kindof UIAction * _Nonnull action) {
            if (!weakSelf.cage) return;
            [weakSelf.delegate cageCellDidArchiveParent:weakSelf.cage isFather:NO];
        }],

        [UIAction actionWithTitle:kLang(@"sale")
                            image:[UIImage systemImageNamed:@"tag"]
                       identifier:nil
                          handler:^(__kindof UIAction * _Nonnull action) {
            if (!weakSelf.cage) return;
            [weakSelf.delegate cageCellDidSellParent:weakSelf.cage isFather:NO];
        }]
    ]];

    self.motherView.menuButton.showsMenuAsPrimaryAction = YES;
}


- (void)configureFatherWithCage:(CageModel *)cage
{
    NSParameterAssert(cage);

    CardModel *father = cage.FatherCard;
    PPBirdCardView *view = self.fatherView;

    if (!father || !view) {
        NSLog(@"⚠️ Father missing for cage %@", cage.ID);
        [view setStatus:PPBirdCardStatusNormal archiveName:nil];
        return;
    }

    // Base config
    [view configureWithCard:father
                     ringID:father.RingID ?: @""
                   isFather:YES];

    // Status resolution (ORDER IS IMPORTANT)
    if (father.isDeleted) {

        [view setStatus:PPBirdCardStatusDeleted archiveName:nil];

    } else if (father.isSold) {

        [view setStatus:PPBirdCardStatusSold archiveName:nil];

    } else if (father.masterArchiveID.length > 0) {

        ArchiveModel *archive =
        [ArchivesManager.shared archiveByID:father.masterArchiveID];

        [view setStatus:PPBirdCardStatusArchived
             archiveName:archive.archiveTitle ?: @""];

    } else {

        [view setStatus:PPBirdCardStatusNormal archiveName:nil];
    }

    //NSLog(@"👨 Father configured — cage %@ card %@", cage.ID, father.ID);
}

- (void)configureMotherWithCage:(CageModel *)cage
{
    NSParameterAssert(cage);

    CardModel *mother = cage.MotherCard;
    PPBirdCardView *view = self.motherView;

    if (!mother || !view) {
        NSLog(@"⚠️ Mother missing for cage %@", cage.ID);
        [view setStatus:PPBirdCardStatusNormal archiveName:nil];
        return;
    }

    // Base config
    [view configureWithCard:mother
                     ringID:mother.RingID ?: @""
                   isFather:NO];

    // Status resolution
    if (mother.isDeleted) {

        [view setStatus:PPBirdCardStatusDeleted archiveName:nil];

    } else if (mother.isSold) {

        [view setStatus:PPBirdCardStatusSold archiveName:nil];

    } else {

        [view setStatus:PPBirdCardStatusNormal archiveName:nil];
    }

    //NSLog(@"👩 Mother configured — cage %@ card %@", cage.ID, mother.ID);
}
@end
