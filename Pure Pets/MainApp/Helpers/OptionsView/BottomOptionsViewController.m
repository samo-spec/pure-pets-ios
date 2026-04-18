//
//  BottomOptionsViewController 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 10/07/2025.
//



#import "BottomOptionsViewController.h"

@interface BottomOptionsViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UIButton *emptyCard;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIButton *addOption;
@property (nonatomic, assign) UITableViewStyle tableStyle;
@property (nonatomic, strong, readwrite) UITableView *tableView;
@end


@implementation BottomOptionsViewController


- (instancetype)init {
    if (self = [super init]) {
       _tableStyle = UITableViewStyleInsetGrouped;
    }
    return self;
}

- (instancetype)initWithTableStyle:(UITableViewStyle)style {
    if (self = [super init]) {
        _tableStyle = style;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
  
    self.view.backgroundColor=UIColor.clearColor;
    self.view.backgroundColor=UIColor.clearColor;

    self.emptyCard = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.view addSubview:self.emptyCard];
    
    float pad = 0;

    //if (@available(iOS 26.0, *)) emptyCardHeight = 80;
    // Set constraints for the empty card view to position it in the view
    [NSLayoutConstraint activateConstraints:@[
        [self.emptyCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:pad],
        [self.emptyCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-pad],
        [self.emptyCard.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:0],
        [self.emptyCard.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-0],
    ]];
     self.emptyCard.backgroundColor=UIColor.clearColor;

    
    // --- Modern blur on iOS 18+, gradient fallback below ---
    if (@available(iOS 26.0, *)) {
        
    }
    else if (@available(iOS 18.0, *)) {
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterialDark]; //UIBlurEffectStyleLight //UIBlurEffectStyleSystemThinMaterial
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        blurView.translatesAutoresizingMaskIntoConstraints = NO;
       // blurView.alpha = 0.99;
        [self.emptyCard addSubview:blurView];
        [NSLayoutConstraint activateConstraints:@[
            [blurView.topAnchor constraintEqualToAnchor:self.emptyCard.topAnchor],
            [blurView.bottomAnchor constraintEqualToAnchor:self.emptyCard.bottomAnchor],
            [blurView.leadingAnchor constraintEqualToAnchor:self.emptyCard.leadingAnchor],
            [blurView.trailingAnchor constraintEqualToAnchor:self.emptyCard.trailingAnchor]
        ]];
 
    } else {
        self.emptyCard.backgroundColor = AppBackgroundClrLigter;
    }
 
    ///self.emptyCard.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    
    self.emptyCard.layer.shadowOpacity = 0.3;
    self.emptyCard.layer.shadowOffset = CGSizeMake(0, 0);
    self.emptyCard.layer.shadowRadius = 6;
    self.emptyCard.layer.cornerRadius = PPCorners + 10;
    
    self.view.layer.cornerRadius = 35; // keep square edges
    //self.view.clipsToBounds = NO;     // must be NO for shadow to show

    // Apply a shadow that only shows above (top shadow)
    [self.view pp_setShadowColor:[UIColor blackColor]];
    self.view.layer.shadowOpacity = 0.6; // adjust darkness
    self.view.layer.shadowRadius = 8.0;  // blur
    self.view.layer.shadowOffset = CGSizeMake(0, -8); // vertical offset up

    // Optional: improve performance by giving shadowPath
    UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRect:
        CGRectMake(0, -8, self.view.bounds.size.width, 8)];
    self.view.layer.shadowPath = shadowPath.CGPath;

     self.emptyCard.hidden =  NO;

        //[self setupHeader];
        [self setupLabels];
        [self setupTableView];
    
 if(self.optionsType == PPOptionsTypeAddressTitles)
     self.addOption.hidden = NO;
    
    
    
}

- (NSArray<NSLayoutConstraint *> *)headerConstraintsForView:(UIView *)v
                                                        top:(CGFloat)top
                                                      width:(CGFloat)w
                                                     height:(CGFloat)h {
    v.translatesAutoresizingMaskIntoConstraints = NO;

    BOOL isLTR = ([Language languageVal] == 0);
    NSMutableArray<NSLayoutConstraint *> *cs = [NSMutableArray arrayWithCapacity:4];

    [cs addObject:[v.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:top]];
    [cs addObject:[v.widthAnchor constraintEqualToConstant:w]];
    [cs addObject:[v.heightAnchor constraintEqualToConstant:h]];

    // LTR → pin to top-right, RTL → pin to top-left
    if (isLTR) {
        [cs addObject:[v.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-26]];
    } else {
        [cs addObject:[v.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:26]];
    }

    return cs.copy;
}

- (void)setupHeader {
    // 1) Image view (behind the animation)
    if(_optionsType == PPOptionsTypeAddressTitles) return;
    self.headerImageView = [[UIImageView alloc] init];
    _headerImageView.alpha = 1;
    self.headerImageView.contentMode = UIViewContentModeScaleToFill;
    self.headerImageView.clipsToBounds = YES;
    self.headerImageView.backgroundColor = UIColor.clearColor;
    self.headerImageView.image = [UIImage imageNamed:@"peeking"]; // set if you have a default
    [self.view addSubview:self.headerImageView];
    [NSLayoutConstraint activateConstraints:
        [self headerConstraintsForView:self.headerImageView top:-117 width:150 height:120]
    ];
    [self.view bringSubviewToFront:self.headerImageView];
    // 2) Lottie animation (on top of image)
    if (self.jsonAnimationName) {
        self.headerAnimation = [[LOTAnimationView alloc] init];
        self.headerAnimation.loopAnimation = YES;
        self.headerAnimation.contentMode = UIViewContentModeScaleAspectFit;

        [self.view addSubview:self.headerAnimation];
        [NSLayoutConstraint activateConstraints:
            [self headerConstraintsForView:self.headerAnimation top:-150 width:150 height:150]
        ];

        [self.view bringSubviewToFront:self.headerAnimation];
    }
}



- (void)setupLabels {
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.text = self.sheetTitle;
    self.titleLabel.font = [GM MidFontWithSize:20];
    self.titleLabel.textAlignment = ([Language languageVal] == 0) ? NSTextAlignmentLeft : NSTextAlignmentRight;

    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.text = self.sheetSubtitle;
    self.subtitleLabel.font = [GM fontWithSize:14];
    self.subtitleLabel.textColor = GM.SecondaryTextColor;
    self.subtitleLabel.textAlignment = ([Language languageVal] == 0) ? NSTextAlignmentLeft : NSTextAlignmentRight;
    
    self.addOption = [self pp_ButtonWithSystemName:@"plus" action:@selector(showCustomTitleAlert)];

    [self.view addSubview:self.titleLabel];
    [self.view addSubview:self.addOption];
    [self.view addSubview:self.subtitleLabel];

    NSLayoutYAxisAnchor *titleTopAnchor;
    if (self.headerAnimation) {
        titleTopAnchor = self.headerAnimation.bottomAnchor;
    } else {
        titleTopAnchor = self.view.topAnchor;
    }
    
    titleTopAnchor = self.view.topAnchor;

    [NSLayoutConstraint activateConstraints:@[
        
        [self.titleLabel.topAnchor constraintEqualToAnchor:titleTopAnchor constant: 36],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:36],
        
        [self.addOption.centerYAnchor constraintEqualToAnchor:self.titleLabel.centerYAnchor],
        [self.addOption.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant: -26],
        
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.addOption.leadingAnchor constant:-26],
       
    
        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor]
    ]];
    
    self.addOption.hidden = YES;
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:_tableStyle];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 16, 0, 75);
    //self.tableView.separatorColor = [GM.backOffwhileColor colorWithAlphaComponent:0.3];
    
    self.tableView.estimatedRowHeight = _optionsType == PPOptionsTypeAddressTitles ? 50.0 : 70.0;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    [self.tableView registerClass:OptionTableViewCell.class forCellReuseIdentifier:@"OptionCell"];
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.subtitleLabel.bottomAnchor constant:16],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-16]
        
    ]];
    self.tableView.separatorColor = [GM.SecondaryTextColor  colorWithAlphaComponent:0.1];
    //self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.clipsToBounds = YES;
}


#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Each item (address or option) gets its own section
    return self.optionsType == PPOptionsTypeAddressTitles
        ? self.AddressessArray.count
        : self.options.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Each section has exactly one row
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    OptionTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"OptionCell" forIndexPath:indexPath];

    if (self.optionsType == PPOptionsTypeAddressTitles) {
        [cell configureWithAddressTitleModel:self.AddressessArray[indexPath.section]];
    } else {
        [cell configureWithOption:self.options[indexPath.section]];
    }
 
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.optionsType == PPOptionsTypeAddressTitles) {
        // Example: handle address selection later if needed
        // PPAddressModel *selected = self.AddressessArray[indexPath.section];
    } else {
        OptionModel *selected = self.options[indexPath.section];

        if ([selected.optID isEqualToString:@"new"]) {
            [self showCustomTitleAlert];
        } else {
            if (self.selectionHandler) {
                self.selectionHandler(selected);
            }
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    }
}

#pragma mark - Section Spacing (for visual separation)

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 8; // space between rows
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *spacer = [[UIView alloc] init];
    spacer.backgroundColor = UIColor.clearColor;
    return spacer;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return CGFLOAT_MIN; // remove default extra spacing
}




 



- (void)showCustomTitleAlert {
    UIAlertController *alert =
    [UIAlertController alertControllerWithTitle:kLang(@"customTitle")
                                        message:kLang(@"enterCustomTitle")
                                 preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = kLang(@"customTitlePlaceholder");
        textField.textAlignment = ([Language languageVal] == 0) ? NSTextAlignmentLeft : NSTextAlignmentRight;
    }];

    UIAlertAction *cancel =
    [UIAlertAction actionWithTitle:kLang(@"cancel")
                             style:UIAlertActionStyleCancel
                           handler:nil];

    UIAlertAction *confirm =
    [UIAlertAction actionWithTitle:kLang(@"confirm")
                             style:UIAlertActionStyleDefault
                           handler:^(UIAlertAction * _Nonnull action) {
        NSString *input = alert.textFields.firstObject.text;
        if (input.length > 0) {
            if(self.optionsType == PPOptionsTypeAddressTitles)
            {
                 
            }
            else
            {
                OptionModel *custom = [[OptionModel alloc] initWithID:OptionUUIDString() title:input];
                if (self.selectionHandler) {
                    self.selectionHandler(custom);
                }
                [self dismissViewControllerAnimated:YES completion:nil];
            }
            
        }
    }];

    [alert addAction:cancel];
    [alert addAction:confirm];
    [self presentViewController:alert animated:YES completion:nil];
}


NSString *OptionUUIDString(void) {
    NSUUID *uuid = [NSUUID UUID];
    return [uuid UUIDString];
}


-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return  _optionsType == PPOptionsTypeAddressTitles ? 50.0 : 70.0;
}


-(void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    
    // Load JSON then play
    __weak LOTAnimationView *weakAnim = self.headerAnimation;
    weakAnim.animationSpeed = 0.5;
    //weakAnim.backgroundColor = UIColor.redColor;
   /* [AppClasses fetchLottieJSONFromFirebasePath:[NSString stringWithFormat:@"LottieAnimations/%@",self.jsonAnimationName]
                                     completion:^(NSDictionary * _Nonnull jsonDict, NSError * _Nonnull error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LOTAnimationView *anim = weakAnim;
            if (!anim) return;

            if (error) {
                NSLog(@"Lottie ❌ %@", error.localizedDescription);
                return;
            }
            if (![jsonDict isKindOfClass:NSDictionary.class]) {
                NSLog(@"Lottie ❌ Invalid JSON");
                return;
            }

            LOTComposition *composition = [LOTComposition animationFromJSON:jsonDict];
            if (composition) {
                [anim setSceneModel:composition];
                [anim play];
            } else {
                NSLog(@"Lottie ❌ Failed to create composition");
            }
        });
    }];
    [NSLayoutConstraint activateConstraints:@[
        [self.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:10],
        [self.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-10],
        [self.view.heightAnchor constraintEqualToConstant:600],
        [self.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-100],
    ]];
    
    */
    
    self.tableView.backgroundColor = UIColor.clearColor;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath {
    return;
    if (@available(iOS 26.0, *)) return;
    NSInteger rows = [tableView numberOfRowsInSection:indexPath.section];
    BOOL isFirst = (indexPath.row == 0);
    BOOL isLast  = (indexPath.row == rows - 1);

    // Adjust the card corners on the background views (normal & selected)
    void (^roundCorners)(UIView *) = ^(UIView *v){
        if (!v) return;
        if (@available(iOS 11.0, *)) {
            CACornerMask mask = 0;
            if (isFirst) { mask |= kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner; }
            if (isLast)  { mask |= kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner; }
            if (rows == 1) { mask = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner; }
            v.layer.cornerRadius = 20.0;
            v.layer.maskedCorners = mask ?: 0; // middle rows get square corners
        } else {
            // iOS 10 fallback: keep uniform radius (good enough)
            v.layer.cornerRadius = (rows == 1 || isFirst || isLast) ? 12.0 : 0.0;
        }
        v.layer.masksToBounds = YES;
    };

    roundCorners(cell.backgroundView);
    roundCorners(cell.selectedBackgroundView);

    // Optional: provide a small vertical inset between rows
    cell.contentView.layoutMargins = UIEdgeInsetsMake(2, 0, 2, 0);
}

@end
