//
//  SalesVCViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 18/03/2025.
//

#import "SalesVCViewController.h"
#import "UISearchBar+FMAdd.h"
@interface SalesVCViewController ()<BuyerCellDelegate>
{
    CGFloat topPadding;
    CGFloat bottomPadding;
    NSString *_currentLanguage;
}
@property NSMutableArray<BuyerModel *> * _Nullable LocalBuyerArray;
@property UITextField * _Nullable searchTextField;
@property (strong, nonatomic) CCActivityHUD                     *activityHUD;
@end

@implementation SalesVCViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"AppData.BuyerArray %@",AppData.BuyerArray);
    NSLog(@"AppData.BuyerArray.count %ld",AppData.BuyerArray.count);

    [self setupViews];
    [self setupConstraints];

    // Do any additional setup after loading the view.
    [self setActivityIndecator];
    [self.activityHUD show];
    [self setCollection];
    [self layoutSearchBar];
    
}

#pragma mark - Programmatic UI

- (void)setupViews {
    // --- Top bar ---
    self.topView = [[UIView alloc] initWithFrame:CGRectZero];
    self.topView.translatesAutoresizingMaskIntoConstraints = NO;
    self.topView.backgroundColor = AppPrimaryClr;

    // --- Title label ---
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.textColor = [UIColor whiteColor];

    // --- Dismiss button ---
    self.dissmissButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.dissmissButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.dissmissButton addTarget:self action:@selector(dissmiss:) forControlEvents:UIControlEventTouchUpInside];

    // --- Search bar ---
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;

    // --- Collection view ---
    UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
    flowLayout.scrollDirection = UICollectionViewScrollDirectionVertical;
    flowLayout.minimumLineSpacing = 10;
    flowLayout.minimumInteritemSpacing = 10;

    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:flowLayout];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.backgroundColor = [UIColor clearColor];

    // --- Add to hierarchy ---
    [self.topView addSubview:self.titleLabel];
    [self.topView addSubview:self.dissmissButton];
    [self.view addSubview:self.topView];
    [self.view addSubview:self.searchBar];
    [self.view addSubview:self.collectionView];
}

- (void)setupConstraints {
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;

    [NSLayoutConstraint activateConstraints:@[
        // topView
        [self.topView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.topView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.topView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.topView.bottomAnchor constraintEqualToAnchor:safe.topAnchor constant:56],

        // titleLabel – centered in topView safe area
        [self.titleLabel.centerXAnchor constraintEqualToAnchor:self.topView.centerXAnchor],
        [self.titleLabel.bottomAnchor constraintEqualToAnchor:self.topView.bottomAnchor constant:-10],

        // dismissButton – trailing side, vertically aligned with title
        [self.dissmissButton.trailingAnchor constraintEqualToAnchor:self.topView.trailingAnchor constant:-16],
        [self.dissmissButton.centerYAnchor constraintEqualToAnchor:self.titleLabel.centerYAnchor],
        [self.dissmissButton.widthAnchor constraintEqualToConstant:32],
        [self.dissmissButton.heightAnchor constraintEqualToConstant:32],

        // searchBar
        [self.searchBar.topAnchor constraintEqualToAnchor:self.topView.bottomAnchor],
        [self.searchBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.searchBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        // collectionView
        [self.collectionView.topAnchor constraintEqualToAnchor:self.searchBar.bottomAnchor],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

// MARK: - Set Activity Indicator
- (void)setActivityIndecator {
    self.activityHUD = [CCActivityHUD new];
    self.activityHUD.isTheOnlyActiveView = YES;
    self.activityHUD.backColor = [UIColor clearColor];
    self.activityHUD.indicatorColor = [GM appPrimaryColor];
    self.activityHUD.overlayType = CCActivityHUDOverlayTypeShadow;
    [self.activityHUD setAppearAnimationType:CCActivityHUDAppearAnimationTypeZoomIn];
    [self.activityHUD setDisappearAnimationType:CCActivityHUDDisappearAnimationTypeZoomOut];
    [self.activityHUD setAppearAnimationType:2];
    [self.activityHUD show];
}

-(void)layoutSearchBar
{
    self.searchBar.backgroundImage = [[UIImage alloc] init];
    self.searchBar.barTintColor = [UIColor blackColor];
    self.searchBar.placeholder = kLang(@"searchField");

    self.searchTextField = [self.searchBar valueForKey:@"searchField"];

    if (self.searchTextField) {
        [ self.searchTextField setBackgroundColor:[UIColor whiteColor]];
        self.searchTextField.layer.borderColor = [UIColor colorWithRed:230 / 255.0 green:242 / 255.0 blue:235 / 255.0 alpha:1].CGColor;
        self.searchTextField.layer.borderWidth = 0;
        self.searchTextField.layer.masksToBounds = YES;
        self.searchTextField.layer.cornerRadius = self.searchTextField.hx_h/2;
        self.searchTextField.clipsToBounds = YES;

        self.searchTextField.borderStyle = UITextBorderStyleRoundedRect;
        [ self.searchTextField setClearButtonMode:UITextFieldViewModeNever];
        self.searchTextField.textAlignment = NSTextAlignmentCenter;

        if ([_currentLanguage isEqualToString:LanguageCode[0]]) {
            self.searchTextField.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
        } else if ([_currentLanguage isEqualToString:LanguageCode[1]]) {
            self.searchTextField.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
        }

        self.searchTextField.font = [GM MidFontWithSize:14];
    }

    if ([_currentLanguage isEqualToString:LanguageCode[0]]) {
        self.searchBar.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    } else if ([_currentLanguage isEqualToString:LanguageCode[1]]) {
        self.searchBar.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    }

    [self.searchBar fm_setCancelButtonTitle:kLang(@"cancel")];
    [self.searchBar fm_setCancelButtonFont:[GM MidFontWithSize:14]];
    [ self.searchTextField setTintColor:[UIColor blackColor]];

    [self.searchBar fm_setTextColor:[UIColor blackColor]];
    [self.searchBar fm_setTextFont:[GM MidFontWithSize:14]];

    //self.searchBar.delegate = self;

    [[UIBarButtonItem appearanceWhenContainedInInstancesOfClasses:@[[UISearchBar class]]]
     setTitleTextAttributes:@{ NSForegroundColorAttributeName: [UIColor redColor], NSFontAttributeName: [GM MidFontWithSize:14] }
     forState:UIControlStateNormal];

    [self.searchBar setNeedsLayout];
    [self.searchBar layoutIfNeeded];
}
-(void)setCollection
{
    self.view.layer.cornerRadius = 35;
    self.view.clipsToBounds = YES;
    
    //[self setTopGard:_topView];
    self.collectionView.layer.cornerRadius = 20;
    self.collectionView.clipsToBounds = YES;
    
    topPadding = 0.0;
    bottomPadding = 0.0;
    [self getSafeAreaInsets:&topPadding bottomPadding:&bottomPadding];
    
    _collectionView.frame = CGRectMake(0, _searchBar.hx_maxy - 1, self.view.hx_w, self.view.hx_h - _searchBar.hx_maxy - bottomPadding);
    [self.collectionView registerNib:[UINib nibWithNibName:@"BuyerCell" bundle:nil] forCellWithReuseIdentifier:@"BuyerCell"];
    _collectionView.dataSource = self;
    _collectionView.delegate = self;
    _titleLabel.font =  [GM boldFontWithSize:17];
    [self.collectionView reloadData];
    [self.activityHUD dismiss];

}



- (void)setTopGard:(UIView *)theView
{
    
    CAGradientLayer *theViewGradient = [CAGradientLayer layer];

    theViewGradient.colors = [NSArray arrayWithObjects:(id)UIColor.whiteColor.CGColor,(id)UIColor.whiteColor.CGColor,(id)UIColor.whiteColor.CGColor,(id)UIColor.whiteColor.CGColor, (id)[UIColor colorWithHexString:@"#EDEDED"].CGColor,  nil];
    theViewGradient.frame = theView.bounds;
    theViewGradient.cornerRadius = 0.0;

    [theView.layer insertSublayer:theViewGradient atIndex:0];
    
}

-(NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return AppData.BuyerArray.count;
}

-(__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
   
 
    BuyerCell *cell;
    NSString *cellIdentifier = @"BuyerCell";
    if (indexPath.row >= AppData.BuyerArray.count) {
        NSLog(@"❌ SalesVC: indexPath.row %ld out of bounds (BuyerArray.count=%lu)", (long)indexPath.row, (unsigned long)AppData.BuyerArray.count);
        return [collectionView dequeueReusableCellWithReuseIdentifier:@"BuyerCell" forIndexPath:indexPath];
    }
    BuyerModel *B_model = AppData.BuyerArray[indexPath.row];
    cell = [collectionView dequeueReusableCellWithReuseIdentifier:cellIdentifier forIndexPath:indexPath];
    CardModel *cardModel = [self cardDataForID:B_model.birdID];
    cell.cardTitleLabel.text = cardModel.CardTitle;
    cell.buyerNameLabel.text = [NSString stringWithFormat:@"%@:  %@",kLang(@"buyerName"),B_model.buyerName];
    cell.cellDateLabel.text = [NSString stringWithFormat:@"%@:  %@",kLang(@"sellDate"),[GM formatDateFromDate:B_model.sellDate]];
    cell.mobileNumberLabel.text = [NSString stringWithFormat:@"%@:  %@",kLang(@"buyerMobile"),B_model.buyerMobile];
    cell.RingIDLabel.text = [NSString stringWithFormat:@"%@:  %@",kLang(@"birdRingId"),cardModel.RingID];
    cell.cellAmountLabel.text = [NSString stringWithFormat:@"%@:  %@",kLang(@"buyer_price"),B_model.buyerPrice];
    
    
    cell.delegate = self;
    // 5. Get the image
    NSString *imageUrl;
    if (cardModel.imagesNames.count == 0) {
        imageUrl = @"https://firebasestorage.googleapis.com/v0/b/pure-pets-49199.firebasestorage.app/o/Placers%2FbirdPlace.png?alt=media&token=5dca1e6a-1e6f-4771-b4be-759f322447fa";
    }
    else
    {
        if (cardModel.FilesArray.count < 2) {
            NSLog(@"❌ SalesVC: FilesArray.count=%lu, need at least 2", (unsigned long)cardModel.FilesArray.count);
            imageUrl = cardModel.FilesArray.count > 0 ? cardModel.FilesArray[0].FileUrl : @"https://firebasestorage.googleapis.com/v0/b/pure-pets-49199.firebasestorage.app/o/Placers%2FbirdPlace.png?alt=media&token=5dca1e6a-1e6f-4771-b4be-759f322447fa";
        } else {
            imageUrl = cardModel.FilesArray[0].FileType == 0 ? cardModel.FilesArray[0].FileUrl : cardModel.FilesArray[1].FileUrl;
        }
    }
    [GM setImageFromUrlString:imageUrl imageView:cell.mainImageView phImage:@"placeholder"];
    // 6. Button Configurations and archive state
    cell.B_model = B_model;
    cell.cardModel = cardModel;
    return cell;
}

-(void)returnCard:(BuyerModel *)b_model buyerCell:(BuyerCell *)buyerCell
{
    
   // [buyerCell.uploadProgressView startAnimating];
   // return;
    FCAlertView *alert = [[FCAlertView alloc] init];

    [alert  showAlertInView:self
                  withTitle:kLang(@"returnCard")
               withSubtitle:kLang(@"returnSelledCard")
            withCustomImage:[UIImage imageNamed:@"Return"]
        withDoneButtonTitle:kLang(@"yes")
                 andButtons:nil];
    [alert addButton:kLang(@"no") withActionBlock:^{ }];
    __weak typeof(self) weakSelf = self;
    [alert doneActionBlock:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        [buyerCell.uploadProgressView startAnimating];
        // Up
        // Update Cards
        NSDictionary *updates = @{
            @"isSold": @(0),
        };
        CardModel *careToReturn = [CardModel getCardForID:b_model.birdID];
       
        if(!careToReturn){
            NSLog(@"Card Not Found");
            
            [BuyerModel deleteBuyerWithDocumentID:b_model.ID completion:^(NSError * _Nullable error) {
                [buyerCell.uploadProgressView stopAnimating];
                NSLog(@"Bird Returned successfully!");
            }];
            
            //buyerCell.uploadProgressView stopAnimating];
            //return;
        }
        [careToReturn updateCardWithID:careToReturn.ID updateDictionary:updates completion:^(NSError * _Nullable error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if(error) {
                NSLog(@"error %@", error);
            } else {
                
                NSLog(@"Card updated successfully!");
                [b_model updateCageIsSoldForCard:careToReturn withValue:0 completionHandler:^(int result) {
                    NSLog(@"Gage updated successfully!");
                }];
                
                [b_model updateArchiveIsSoldForCard:careToReturn withValue:0 completionHandler:^(int result) {
                    NSLog(@"Archive updated successfully!");
                }];
                
                [BuyerModel deleteBuyerWithDocumentID:b_model.ID completion:^(NSError * _Nullable error) {
                    NSLog(@"Bird Returned successfully!");
                }];
                                
                [buyerCell.uploadProgressView stopAnimating];
                if (strongSelf) {
                    [[AppManager sharedInstance] showSnakBar:kLang(@"Retutn_Compelete") withColor:[GM appPrimaryColor] andDuration:5 containerView:strongSelf.topView];
                }
            }
           
        }];
       
           
        
    }];
    [alert setColorScheme:[GM appPrimaryColor]];
}



-(void)showDetails:(BuyerModel *)b_model cardModel:(CardModel *)cardModel
{
    viewDataVC *add = [viewDataVC new];
    add.cardModel = cardModel;
    ///add.delegate = self;
    [self presentViewController:add animated:YES completion:nil];
}


- (void)DetaildsFromTrash:(CardModel *)cardData
{
    viewDataVC *add = [viewDataVC new];
    add.cardModel = cardData;
    //add.delegate = self;
    [self presentViewController:add animated:YES completion:nil];
}

- (void)makePhoneCallToNumber:(NSString *)phoneNumber {
    // Format phone number to remove spaces and special characters
    NSString *formattedNumber = [[phoneNumber componentsSeparatedByCharactersInSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]] componentsJoinedByString:@""];
    
    // Create tel URL
    NSString *phoneURLString = [NSString stringWithFormat:@"tel:%@", formattedNumber];
    NSURL *phoneURL = [NSURL URLWithString:phoneURLString];

    // Check if the device can make calls
    if ([[UIApplication sharedApplication] canOpenURL:phoneURL]) {
        [[UIApplication sharedApplication] openURL:phoneURL options:@{} completionHandler:nil];
    } else {
        NSLog(@"Phone call not supported on this device.");
    }
}

- (void)sendWhatsAppMessageToNumber:(NSString *)phoneNumber withMessage:(NSString *)message {
    // Ensure phone number is in international format (without + or special characters)
    NSString *formattedNumber = [phoneNumber stringByReplacingOccurrencesOfString:@"+" withString:@""];
    formattedNumber = [formattedNumber stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    // Encode message to be URL-safe
    NSString *encodedMessage = [message stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    
    // Create WhatsApp URL
    NSString *whatsappURLString = [NSString stringWithFormat:@"whatsapp://send?phone=%@&text=%@", formattedNumber, encodedMessage];
    NSURL *whatsappURL = [NSURL URLWithString:whatsappURLString];

    // Check if WhatsApp is installed
    if ([[UIApplication sharedApplication] canOpenURL:whatsappURL]) {
        [[UIApplication sharedApplication] openURL:whatsappURL options:@{} completionHandler:nil];
    } else {
        NSLog(@"WhatsApp is not installed on this device.");
    }
}

-(CardModel *)cardDataForID:(NSString *)cardID{
    return  [[AppData.AllCardsDocs filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID ==[c] %@",cardID]] firstObject];
}


// MARK: - Size For Item
- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    float cellWidth = self.view.hx_w - 30;
    return CGSizeMake(cellWidth,  240);
}


// MARK: - Update Padding Values
- (void)getSafeAreaInsets:(CGFloat *)topPadding bottomPadding:(CGFloat *)bottomPadding {
    if (@available(iOS 11.0, *)) {
        UIWindow *window = [[[UIApplication sharedApplication] windows] firstObject]; // Get the first window
        if (window) { // Ensure the window is valid
            UIEdgeInsets safeAreaInsets = window.safeAreaInsets;
            *topPadding = safeAreaInsets.top;
            *bottomPadding = safeAreaInsets.bottom;
        } else {
            // Fallback if window is nil (unlikely in most cases)
            *topPadding = 20.0;
            *bottomPadding = 0.0;
            NSLog(@"Warning: Key window is nil. Using default safe area insets.");
        }

    } else {
        *topPadding = 20.0;
        *bottomPadding = 0.0;
    }
}

- (void)dissmiss:(id)sender {
    [self dismissViewControllerAnimated:YES completion:^{
    }];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

-(void)shareCard:(CardModel *)card andImage:(UIImage *)image
{
    NSString *text = [NSString stringWithFormat:@"(%@) %@",card.RingID,card.CardTitle];
           UIImage *img = (UIImage *)UIImageJPEGRepresentation([GM setWatermarkImage:[UIImage imageNamed:@"logoImag"] toImage:image], 80) ;
           [GM shareToWhatsApp:text sharingImage:img inViewController:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [_dissmissButton setImage:PPSYSImage(@"multiply") forState:UIControlStateNormal];
    _dissmissButton.tintColor = AppButtonMixColorClr;
}
@end
