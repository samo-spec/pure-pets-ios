//
//  viewDataVC.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 22/07/2024.
//

#import "viewDataVC.h"
#import "AppDelegate.h"
#import "PPHomeCartNavButton.h"
#import "CartManager.h"


typedef enum : NSUInteger {
    ShowDataForDna = 0,
    ShowDataForFather = 1,
    ShowDataForMother = 2,
} ShowData;


@interface viewDataVC ()<UINavigationControllerDelegate,UIViewControllerTransitioningDelegate>
{
    long _currentIndex;
    NSInteger currentIndex;
    NSArray<SubKindModel *> *SubKindsArrayLocal;
     FIRStorage *firStorage;
    NSInteger *currnetIndex;
}
@property float globalInset;
@property (nonatomic, strong) UIView *emptyCard;
@property NSInteger isAutoPlaySet;
@property NSUserDefaults *prefs ;
@property (nonatomic, strong) NSIndexPath *currentlyPlayingIndexPath;
@property (nonatomic, strong) UIView *bottomActionsContainer;
@property (nonatomic, strong) PPQuickActionsView *actionsView;
@property (nonatomic, strong) ZMJTipView *tipView;
@property (nonatomic, assign) BOOL didSetupTableConstraints;
@property (nonatomic, assign) CGSize lastEmptyCardGradientSize;
@property (nonatomic, assign) CGSize lastBottomActionsGradientSize;
@property (nonatomic, strong) PPHomeCartNavButton *cartNavButton;
@property (nonatomic, strong) PPHomeCartNavButton *dismissNavButton;

 @end

@implementation viewDataVC
-(AppDelegate *)AppDelegate { return (AppDelegate*)[[UIApplication sharedApplication]delegate]; }

- (void)applyCustomFontToAlert:(UIAlertController *)alert
                     titleFont:(UIFont *)titleFont
                   messageFont:(UIFont *)messageFont
                    titleColor:(UIColor *)titleColor
                  messageColor:(UIColor *)messageColor
                 textAlignment:(NSTextAlignment)alignment {
    
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.alignment = alignment;
    
    if (alert.title.length > 0) {
        NSDictionary *titleAttrs = @{
            NSFontAttributeName: titleFont ?: [UIFont boldSystemFontOfSize:18],
            NSForegroundColorAttributeName: titleColor ?: UIColor.labelColor,
            NSParagraphStyleAttributeName: paragraph
        };
        NSAttributedString *attrTitle = [[NSAttributedString alloc] initWithString:alert.title attributes:titleAttrs];
        // KVC hack removed to prevent App Store rejection
    }
    
    if (alert.message.length > 0) {
        NSDictionary *messageAttrs = @{
            NSFontAttributeName: messageFont ?: [UIFont systemFontOfSize:15],
            NSForegroundColorAttributeName: messageColor ?: UIColor.secondaryLabelColor,
            NSParagraphStyleAttributeName: paragraph
        };
        NSAttributedString *attrMsg = [[NSAttributedString alloc] initWithString:alert.message attributes:messageAttrs];
        [alert setValue:attrMsg forKey:@"attributedMessage"];
    }
}



#pragma mark - Programmatic Return Button Setup

- (void)setupReturnButton {
    _returnBTN = [UIButton buttonWithType:UIButtonTypeSystem];
    [_returnBTN setTitle:kLang(@"return") forState:UIControlStateNormal];
    [_returnBTN.titleLabel setFont:[GM MidFontWithSize:15]];
    _returnBTN.clipsToBounds = YES;
    _returnBTN.alpha = 0;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    currnetIndex = 0;
    _globalInset = 12;
    
    [self addBottomActionsView];
    firStorage = [FIRStorage storage];

    SubKindsArrayLocal  =  [MKM getSubKindArray:1];
    self.prefs = [NSUserDefaults standardUserDefaults];
    _currentIndex = 0;
    self.isAutoPlaySet = [self.prefs integerForKey:@"isAutoPlaySet"];
    NSLog(@"isAutoPlaySetisAutoPlaySetisAutoPlaySetisAutoPlaySetisAutoPlaySetisAutoPlaySet  %ld",_isAutoPlaySet);
    
    if(_cardModel.FilesArray.count == 0) {
        FileModel *file = [[FileModel alloc] init];
        file.FileUrl = @"https://firebasestorage.googleapis.com/v0/b/pure-pets-49199.firebasestorage.app/o/Placers%2FbirdPlace.png?alt=media&token=5dca1e6a-1e6f-4771-b4be-759f322447fa";
        file.FileType = 0;
        _cardModel.FilesArray = @[file].mutableCopy;
       // [_photos addObject:file.FileUrl];
    }

  
    
    
    currentIndex = 0;
    [self LoadData];
    
    [self setupReturnButton];
    [self BKbuttonInit];
     
    self.imageGallery = [[PetImageGalleryView alloc] initWithFrame:CGRectZero
                                                       imageItems:self.cardModel.imageItems
                                                      galleryType:PetImageGalleryTypeCardsViewer
                                                       itemHeight:self.view.hx_h * 0.6
                                                         parentVC:self
                                                              obj:self.cardModel];
    
    
    
    self.imageGallery.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view insertSubview:self.imageGallery atIndex:0];
    
    _imageGallery.layer.cornerRadius = 0;
    _imageGallery.clipsToBounds = YES;
    _imageGallery.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner ;
    // Setup imageGallery constraints
     CGFloat statusBarHeight = [UIApplication sharedApplication].statusBarFrame.size.height  ;
    [NSLayoutConstraint activateConstraints:@[
        [self.imageGallery.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:- statusBarHeight],
        [self.imageGallery.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.imageGallery.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.imageGallery.heightAnchor constraintEqualToConstant:self.view.hx_h * 0.6]
    ]];
    [self addActionsView];
    
    
    [self initializeForm];
        
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_cartDidUpdate)
                                                 name:kCartUpdatedNotification
                                               object:nil];

    self.tableView.layer.cornerRadius = 0;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 25, 0, 25);
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;

    if (!self.didSetupTableConstraints) {
        [NSLayoutConstraint activateConstraints:@[
            [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:0],
            [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:0],
            [self.tableView.topAnchor constraintEqualToAnchor:self.emptyCard.bottomAnchor constant:0],
            [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:0],
        ]];
        self.didSetupTableConstraints = YES;
    }
}


- (void)initializeForm {
    XLFormDescriptor *form = [XLFormDescriptor formDescriptorWithTitle:kLang(@"birdDetails")];
    XLFormSectionDescriptor *section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    // 🪶 Basic Info
    /*
    [section addFormRow:[XLFormRowDescriptor formRowDescriptorWithTag:@"ringID"
                                                               rowType:XLFormRowDescriptorTypeInfo
                                                                 title:self.cardModel.RingID]];
     [section addFormRow:[XLFormRowDescriptor formRowDescriptorWithTag:@"kind"
                                                                rowType:XLFormRowDescriptorTypeInfo
                                                                  title:[NSString stringWithFormat:@"%@: %@", kLang(@"birdKind"), self.cardModel.subKindString]]];
     
     // ⚥ Sexual
     [section addFormRow:[XLFormRowDescriptor formRowDescriptorWithTag:@"sex"
                                                                rowType:XLFormRowDescriptorTypeInfo
                                                                  title:[NSString stringWithFormat:@"%@: %@", kLang(@"Sexual"), self.cardModel.SexualTXT]]];
     // 👨 Father
     NSString *fatherVal = kLang(@"notFound");
     if (![self.cardModel.FatherRingID isEqualToString:@"no_value"]) {
         NSString *FRingID = [[[self.CardsdataSource filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %@", self.cardModel.FatherRingID]] firstObject] RingID];
         if (FRingID.length > 0) fatherVal = FRingID;
     }
     [section addFormRow:[XLFormRowDescriptor formRowDescriptorWithTag:@"father"
                                                                rowType:XLFormRowDescriptorTypeInfo
                                                                  title:[NSString stringWithFormat:@"%@: %@", kLang(@"FatherRingID"), fatherVal]]];

     // 👩 Mother
     NSString *motherVal = kLang(@"notFound");
     if (![self.cardModel.MotherRingID isEqualToString:@"no_value"]) {
         NSString *MRingID = [[[self.CardsdataSource filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %@", self.cardModel.MotherRingID]] firstObject] RingID];
         if (MRingID.length > 0) motherVal = MRingID;
     }
     [section addFormRow:[XLFormRowDescriptor formRowDescriptorWithTag:@"mother"
                                                                rowType:XLFormRowDescriptorTypeInfo
                                                                  title:[NSString stringWithFormat:@"%@: %@", kLang(@"MotherRingID"), motherVal]]];
     // 📅 Birth Date
     [section addFormRow:[XLFormRowDescriptor formRowDescriptorWithTag:@"birthdate"
                                                                rowType:XLFormRowDescriptorTypeInfo
                                                                  title:[NSString stringWithFormat:@"%@: %@", kLang(@"BirthDate"), [self formatDateFromDate:self.cardModel.BirthDate]]]];
    */
   
    
    [section addFormRow:[XLFormRowDescriptor formRowDescriptorWithTag:@"attribute"
                                                               rowType:XLFormRowDescriptorTypeInfo
                                                                 title:[NSString stringWithFormat:@"%@: %@", kLang(@"Attribute"), self.cardModel.getBirdAttribute]]];
    
    [section addFormRow:[XLFormRowDescriptor formRowDescriptorWithTag:@"classification"
                                                               rowType:XLFormRowDescriptorTypeInfo
                                                                 title:[NSString stringWithFormat:@"%@: %@", kLang(@"Classification"), self.cardModel.ClassificationString]]];
     
    // 📝 Note
    [section addFormRow:[XLFormRowDescriptor formRowDescriptorWithTag:@"note"
                                                               rowType:XLFormRowDescriptorTypeInfo
                                                                 title:[NSString stringWithFormat:@"%@: %@", kLang(@"note"), self.cardModel.AdDescString]]];

    self.form = form;
}



#pragma mark - Quick actions header

- (void)addActionsView {
    self.emptyCard = [PPFunc createEmptyModernCardView];
    [self.view addSubview:self.emptyCard];

    CGFloat pad = 12.0;
    CGFloat emptyCardHeight = 120 + _globalInset * 2;
    
    [NSLayoutConstraint activateConstraints:@[
        [self.emptyCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:0],
        [self.emptyCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-0],
        [self.emptyCard.topAnchor constraintEqualToAnchor:self.imageGallery.bottomAnchor  constant:-0],
        [self.emptyCard.heightAnchor constraintEqualToConstant:emptyCardHeight],
    ]];

    self.emptyCard.backgroundColor = AppClearClr;
    //self.emptyCard.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    self.emptyCard.layer.shadowOpacity = 0.0;
    self.emptyCard.layer.shadowOffset = CGSizeMake(0, 0);
    self.emptyCard.layer.shadowRadius = 0.0;
    self.emptyCard.layer.cornerRadius = 0;

    self.actionsView = [PPQuickActionsView new];
    self.actionsView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.emptyCard addSubview:self.actionsView];

    [NSLayoutConstraint activateConstraints:@[
        [self.actionsView.leadingAnchor constraintEqualToAnchor:self.emptyCard.leadingAnchor constant:pad],
        [self.actionsView.trailingAnchor constraintEqualToAnchor:self.emptyCard.trailingAnchor constant:-pad],
        [self.actionsView.topAnchor constraintEqualToAnchor:self.emptyCard.topAnchor constant:8],
        [self.actionsView.heightAnchor constraintEqualToConstant:96],
    ]];

    self.actionsView.alpha = 1;

   
    
    NSDictionary *info = [PPFunc ageInfoFromBirthday:self.cardModel.BirthDate adultHood:18];
    NSLog(@"Age: %@  | Ready: %@", info[@"ageString"], info[@"readyString"]);

    BOOL FatherViewEnabeld = NO;
    NSString *FatherValue = kLang(@"notFound");
    if (![self.cardModel.FatherRingID isEqualToString:@"no_value"]) {
        NSString *FRingID = [[[self.CardsdataSource filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %@", self.cardModel.FatherRingID]] firstObject] RingID];
        if (FRingID.length > 0)  { FatherValue = FRingID;  FatherViewEnabeld = YES; }
    }
    
    
    
    BOOL MotherViewEnabeld = NO;
    NSString *motherVal = kLang(@"notFound");
    if (![self.cardModel.MotherRingID isEqualToString:@"no_value"]) {
        NSString *MRingID = [[[self.CardsdataSource filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %@", self.cardModel.MotherRingID]] firstObject] RingID];
        if (MRingID.length > 0)  { motherVal = MRingID;  MotherViewEnabeld = YES; }
    }
    
    NSString *DnaImageName = nil; BOOL haveDnaImage = NO;
    if (self.cardModel.Dna.length > 0 && ![self.cardModel.Dna isEqualToString:@"no_value"])  { DnaImageName = self.cardModel.Dna;  haveDnaImage = YES; }
    [self.actionsView setActionsForCardViewr:@[
        [PPQuickActionItem itemWithTitleKey:kLang(@"Father")
                                subTitleKey:FatherValue
                                   iconName:@"ParrotFather"
                              iconNameOnTap:@"bird"
                                      width:0
                                  configFor:ConfigForCardCell
                                       menu:nil
                                    enabled:FatherViewEnabeld
                                    handler:^(UIView * _Nonnull sender) {
          
            NSLog(@"TAP ON Father"); [self showDataFor:ShowDataForFather];
        }],
        [PPQuickActionItem itemWithTitleKey:kLang(@"Mother")
                                subTitleKey:motherVal
                                   iconName:@"ParrotMother"
                              iconNameOnTap:@"bird"
                                      width:0
                                  configFor:ConfigForCardCell
                                       menu:nil
                                    enabled:MotherViewEnabeld
                                    handler:^(UIView * _Nonnull sender) {
            NSLog(@"TAP ON Mother"); [self showDataFor:ShowDataForMother];
        }],
        [PPQuickActionItem itemWithTitleKey:kLang(@"Sexual") //kLang(@"Sexual")
                                subTitleKey:self.cardModel.SexualTXT
                                   iconName:self.cardModel.Sexual == 1 ? @"maleNew" : @"female"
                              iconNameOnTap:@"deskclockg"
                                      width:0
                                  configFor:ConfigForCardCell
                                       menu:nil
                                    enabled:YES
                                    handler:^(UIView * _Nonnull sender) {
            if(haveDnaImage) { [self showDataFor:ShowDataForDna]; }
            else
            { [self showTip:PPSafeString(kLang(@"NoDnaImage")) OnView:sender]; }
            NSLog(@"TAP ON Sexual");
        }],
        [PPQuickActionItem itemWithTitleKey:kLang(@"BirthDate")
                                subTitleKey:info[@"ageString"]
                                   iconName:@"clock"
                              iconNameOnTap:@"clock"
                                      width:0
                                  configFor:ConfigForCardCell
                                       menu:nil
                                    enabled:YES
                                    handler:^(UIView * _Nonnull sender) {
 
            [self showTip:[NSString stringWithFormat:@"%@:   %@",kLang(@"BirthDate"),[self formatDateFromDate:self.cardModel.BirthDate]] OnView:sender];
            NSLog(@"TAP ON Age");   }]
    ]];
    
    
}

- (void)showTip:(NSString *)text OnView:(UIView *)targetView {
    // 1️⃣ Dismiss any currently visible tip
    if (self.tipView) {
        [self.tipView dismissWithCompletion:^{}];
        self.tipView = nil;
    }

    // 2️⃣ Validate message text
    NSString *message = text;
    if (message == nil ||
        [message isEqual:[NSNull null]] ||
        [message isEqualToString:@"(null)"] ||
        message.length == 0) {
        message = @"  "; // fallback Arabic text
    }

    // 3️⃣ Setup preferences
    ZMJPreferences *preferences = [ZMJPreferences new];
    preferences.drawing.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.9];
    preferences.drawing.foregroundColor = AppForgroundColr;
    preferences.drawing.textAlignment = NSTextAlignmentCenter;
    preferences.drawing.font = [GM MidFontWithSize:18];
    preferences.drawing.cornerRadius = 16;
    preferences.drawing.arrowPosition = ZMJArrowPosition_bottom;
    preferences.drawing.shadowColor = [AppPrimaryClr colorWithAlphaComponent:0.7];

  
    preferences.animating.showInitialAlpha = 0;
    preferences.animating.showDuration = 0.8;
    preferences.animating.dismissDuration = 0.8;
    //preferences.positioning =
    // 4️⃣ Create and show tip
    self.tipView = [[ZMJTipView alloc] initWithText:message
                                         preferences:preferences
                                            delegate:nil];

    [self.tipView showAnimated:YES
                       forView:targetView
               withinSuperview:self.view];

    // 5️⃣ Auto dismiss after 5 seconds
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self.tipView dismissWithCompletion:^{}];
        self.tipView = nil;
    });

    NSLog(@"💬 [showTip] Showing tooltip on view: %@ → %@", targetView, message);
}


/*
 
else if(indexPath.row == 3)
  cell.titleLablel.text = [NSString stringWithFormat:@"%@:   %@",kLang(@"Classification"),self.cardModel.ClassificationString];
else if(indexPath.row == 4)
  cell.titleLablel.text = [NSString stringWithFormat:@"%@:   %@",kLang(@"BirthDate"),[self formatDateFromDate:self.cardModel.BirthDate]];
else if(indexPath.row == 5){
  cell.titleLablel.text = [NSString stringWithFormat:@"%@:   %ld",kLang(@"Sexual"),self.cardModel.SexualTXT];
}
 
 */



-(void)BKbuttonInit
{
    if (!_returnBTN) return;

    if([_cardModel.loanForUser isEqualToString:UserManager.sharedManager.currentUser.ID])
    {
        if (_returnBTN.superview != self.view) {
            [self.view addSubview:_returnBTN];
        }
        _returnBTN.frame = CGRectMake(self.view.center.x - 100,
                                      (self.tableView.hx_y + self.tableView.hx_h) - 21,
                                      200 ,
                                      36);
        [_returnBTN setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [_returnBTN setBackgroundColor:[GM appPrimaryColor]];
        [_returnBTN setTintColor:UIColor.whiteColor];
        _returnBTN.layer.cornerRadius = _returnBTN.hx_h/2;
        _returnBTN.alpha = 1;
    }
    else
        _returnBTN.alpha = 0;
    
}
 

-(void)imageViewerDismissed
{
    
}

-(void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self BKbuttonInit];
}



-(void)loadViewData
{
    
    CardModel *ParentClass = [[AppData.AllCardsDocs filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %@",self.cardModel.ID]] firstObject];
 
    self.cardModel = ParentClass;
    NSLog(@"[_ImagesArr objectAtIndex:indexPath.item].ImageName loadViewData %@",ParentClass.imagesNames);
 
    
   
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed
{
    id<UIViewControllerAnimatedTransitioning> animationController;
    NSInteger IsNew = [self.prefs integerForKey:@"FromForm"];
    if(IsNew == 1){
       
    }
    
   
    NSLog(@"animationController ViewData");
    return animationController;
}

-(void)editTapped:(UIBarButtonItem *)button{


    NewCardForm *vc = [NewCardForm new];
    vc.serverCardClass =  self.cardModel;
     vc.FromVC =  @"ViewData";
     
     
    [self.navigationController  pushViewController:vc animated:YES];
    
    
    return;
    //NSLog(@"_ImagesArr.count %ld",_cardModel.imagesNames.count);
  
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    
    
}


-(void)updateViewDone
{
    NSLog(@"updateViewDoneupdateViewDoneupdateViewDoneupdateViewDoneupdateViewDone updateViewDone");
    [self dismissViewControllerAnimated:YES completion:^{
     
    }];
}


- (void)dismissBTN:(id)sender {
  
    [self dismissViewControllerAnimated:YES completion:^{
       
    }];
}


-(void)showDataFor:(ShowData)showDataFor
{
    if(showDataFor == ShowDataForDna)
    {
        
        NSString *DnaImageName = nil; BOOL haveDnaImage = NO;
        if (self.cardModel.Dna.length > 0 && ![self.cardModel.Dna isEqualToString:@"no_value"])  { DnaImageName = self.cardModel.Dna;  haveDnaImage = YES; }
        
        if(haveDnaImage)
        {
            NSMutableArray<NSString *> *photos = [NSMutableArray array];
        [GM fetchDownloadURLForPath:[NSString stringWithFormat:@"CardsImages/%@",PPCurrentUser.ID]
                                       imageName:self.cardModel.Dna
                                      completion:^(NSURL * _Nullable url, NSError * _Nullable error) {
            if (error) {
                NSLog(@"⚠️ Could not fetch URL: %@", error.localizedDescription);
                return;
            }
            
            [photos addObject:url.absoluteString];
            NSLog(@"🪶 Download URL: %@", url.absoluteString);
            NSLog(@"showDataFor %@",url.absoluteString);
            ImageViewerController *vc = [[ImageViewerController alloc] initWithImageURLs:photos];
            UINavigationController *navBar = [[UINavigationController alloc] initWithRootViewController:vc];
            
            //navBar.modalPresentationStyle = UIModalPresentationOverFullScreen;
            [self presentViewController:navBar animated:YES completion:nil];
        }];
        }
        else
        {
            UIColor *toastBackground = [UIColor systemBlueColor];
            //UIColor *toastTextColor = [UIColor whiteColor];
            
            [AppMgr showSnakBar:kLang(@"NoDnaImage") withColor:toastBackground andDuration:0.5 containerView:self.emptyCard];
        }
            

     
          return;
    }
    
    if(showDataFor == ShowDataForFather)
    {
        viewDataVC *add=[viewDataVC new];
        add.cardModel = _FatherCard;
        //add.delegate = self;
        PPNavigationController *nav = [[PPNavigationController alloc]initWithRootViewController:add];
        [self presentViewController:nav animated:YES completion:^{
            
        }];
    }
    
    if(showDataFor == ShowDataForMother)
    {
        viewDataVC *add=[viewDataVC new];
        add.cardModel = _MotherCard;
        PPNavigationController *nav = [[PPNavigationController alloc]initWithRootViewController:add];
        [self presentViewController:nav animated:YES completion:^{
            
        }];
    }
     
}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/
  
- (UIImage *)tintImage:(UIImage *)image withColor:(UIColor *)color {
    if (!image) {
        return nil;
    }

    UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();

    // Flip the image vertically (UIKit's coordinate system is different from Core Graphics)
    CGContextTranslateCTM(context, 0, image.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);

    CGContextSetBlendMode(context, kCGBlendModeNormal);
    CGRect rect = CGRectMake(0, 0, image.size.width, image.size.height);
    CGContextDrawImage(context, rect, image.CGImage);

    CGContextSetBlendMode(context, kCGBlendModeSourceIn);
    [color setFill];
    CGContextFillRect(context, rect);

    UIImage *tintedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return tintedImage;
}


- (UIImage *)watermarkImage:(UIImage *)baseImage withWatermark:(UIImage *)watermarkImage {

        // Calculate the desired dimensions and scaling of the watermark image
        CGFloat watermarkScale = 0.3; // watermark scaled to 30% of the base image width
        CGFloat watermarkWidth = baseImage.size.width * watermarkScale;
        CGFloat watermarkHeight = watermarkImage.size.height * (watermarkWidth / watermarkImage.size.width);

        // Positioning of the watermark, let's place on the bottom right corner with some margin
        CGFloat margin = 10;
        CGFloat x = baseImage.size.width - watermarkWidth - margin;
        CGFloat y = baseImage.size.height - watermarkHeight - margin;

        CGRect watermarkRect = CGRectMake(x, y, watermarkWidth, watermarkHeight);

        // Start drawing
        UIGraphicsBeginImageContext(baseImage.size);
        [baseImage drawInRect:CGRectMake(0, 0, baseImage.size.width, baseImage.size.height)];
        [watermarkImage drawInRect:watermarkRect blendMode:kCGBlendModeNormal alpha:0.7]; // you can change alpha value to make watermark more or less transparent.

        UIImage *resultImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        return resultImage;
}
 
#pragma mark - UICollectionViewDelegate

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
     //[self handleVideoPlayback];
}

 

-(void)LoadData
{
    self.CardsdataSource = AppData.AllCardsDocs;
        
        if(![self.cardModel.FatherRingID isEqual:@"no_value"] )
        {
              self.FatherCard = [[self.CardsdataSource filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %@",self.cardModel.FatherRingID]] firstObject];
        }
    
       if(![self.cardModel.MotherRingID isEqual:@"no_value"])
       {
             self.MotherCard = [[self.CardsdataSource filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %@",self.cardModel.MotherRingID]] firstObject];
       }
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{ }];
}


#pragma mark - UIViewControllerTransitioningDelegate

/*
 Called when presenting a view controller that has a transitioningDelegate
 */
- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented
                                                                  presentingController:(UIViewController *)presenting
                                                                      sourceController:(UIViewController *)source
{
    id<UIViewControllerAnimatedTransitioning> animationController;
    NSLog(@"animationController  VIEW DATA");
    return animationController;
}

-(NSString *)formatDateFromDate:(NSDate *)date
{
      NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
      [dateFormatter setDateFormat:@"dd-MM-yyyy"];
      [dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en"]];
      return [dateFormatter stringFromDate:date];
}

-(void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];

    
    self.tableView.sectionHeaderTopPadding = 0;
    self.tableView.sectionHeaderHeight = 0;
    self.tableView.sectionFooterHeight = 0;
    self.tableView.scrollEnabled = NO;
    
    // Rebuild expensive gradients only when the target view size changes.
    if (self.emptyCard && self.emptyCard.bounds.size.width > 0 && self.emptyCard.bounds.size.height > 0 &&
        !CGSizeEqualToSize(self.lastEmptyCardGradientSize, self.emptyCard.bounds.size)) {
        [PPFunc removeOldGradientsFromView:_emptyCard];
        CGRect frame = self.emptyCard.bounds;
        CAGradientLayer *gradient = [UIView gradientLayerWithFadeForColor:[AppBackgroundClr colorWithAlphaComponent:0.9]
                                                                direction:PPGradientDirectionTopToBottom
                                                                    frame:frame];
        gradient.cornerRadius = 0;
        gradient.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
        [self.emptyCard.layer insertSublayer:gradient atIndex:0];
        self.lastEmptyCardGradientSize = self.emptyCard.bounds.size;
    }

}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    UIButton *titleView = (UIButton *)[self pp_viewWithTitle:[NSString stringWithFormat:@"%@ (%@)",PPSafeString(self.cardModel.subKindString),PPSafeString(self.cardModel.RingID)] Subtitle:self.cardModel.CardTitle Image:nil showBackround:YES];
    [self addBlurToView:titleView style:UIBlurEffectStyleSystemChromeMaterial cornerRadius:22];
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title: _cardModel.CardTitle showBack:NO];
    
    // 1. Setup Cart Button
    self.cartNavButton = [[PPHomeCartNavButton alloc] init];
    [self.cartNavButton addTarget:self action:@selector(pp_openCart) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *cartItem = [[UIBarButtonItem alloc] initWithCustomView:self.cartNavButton];
    
    // 2. Setup Edit Button
    UIBarButtonItem *editBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"pencil.and.scribble"]  style:UIBarButtonItemStylePlain target:self action:@selector(editTapped:)];
    
    self.navigationItem.rightBarButtonItems = @[cartItem, editBarButtonItem];
    
    // 3. Setup Dismiss Button (using PPHomeCartNavButton for the "badge bellow" requirement)
    self.dismissNavButton = [[PPHomeCartNavButton alloc] init];
    [self.dismissNavButton setIconName:@"multiply"];
    [self.dismissNavButton addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *dismissItem = [[UIBarButtonItem alloc] initWithCustomView:self.dismissNavButton];
    self.navigationItem.leftBarButtonItem = dismissItem;
    
    [self pp_navBarSetTitleViewCentered:titleView];
    [self pp_cartDidUpdate];
}

- (void)pp_cartDidUpdate {
    NSInteger count = [[CartManager sharedManager] totalItemsCount];
    [self.cartNavButton updateCount:count animated:YES];
}

- (void)pp_openCart {
    // Open cart view controller
    UIViewController *cartVC = [[NSClassFromString(@"CartViewController") alloc] init];
    if (cartVC) {
        [self.navigationController pushViewController:cartVC animated:YES];
    }
}

-(void)dismiss
{
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}


- (UIVisualEffectView *)addBlurToView:(UIView *)view
                                 style:(UIBlurEffectStyle)style
                           cornerRadius:(CGFloat)cornerRadius
{
    // 1. Create the blur effect
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:style];

    // 2. Create the blur view
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;

    // 3. Create vibrancy effect for extra transparency
    UIVibrancyEffect *vibrancyEffect = [UIVibrancyEffect effectForBlurEffect:blurEffect];
    UIVisualEffectView *vibrancyView = [[UIVisualEffectView alloc] initWithEffect:vibrancyEffect];
    vibrancyView.translatesAutoresizingMaskIntoConstraints = NO;

    // Add vibrancy view to blur view's content
    [blurView.contentView addSubview:vibrancyView];

    // 4. Round the corners (optional)
    blurView.layer.cornerRadius = cornerRadius;
    blurView.layer.masksToBounds = YES;
    blurView.alpha = 0.3;
    // 5. Insert into your view hierarchy
    [view insertSubview:blurView atIndex:0];

    // 6. Pin blur view to edges
    [NSLayoutConstraint activateConstraints:@[
        [blurView.topAnchor constraintEqualToAnchor:view.topAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:view.bottomAnchor]
    ]];

    // 7. Pin vibrancy view to blur view's content
    [NSLayoutConstraint activateConstraints:@[
        [vibrancyView.topAnchor constraintEqualToAnchor:blurView.contentView.topAnchor],
        [vibrancyView.leadingAnchor constraintEqualToAnchor:blurView.contentView.leadingAnchor],
        [vibrancyView.trailingAnchor constraintEqualToAnchor:blurView.contentView.trailingAnchor],
        [vibrancyView.bottomAnchor constraintEqualToAnchor:blurView.contentView.bottomAnchor]
    ]];

    return blurView;
  
}



#pragma mark - Quick BottoM actions header

- (void)addBottomActionsView {
    self.bottomActionsContainer = [PPFunc createEmptyModernCardView];
    [self.view addSubview:self.bottomActionsContainer];

    CGFloat pad = 12.0;
    CGFloat bottomActionsContainerHeight = 44 + _globalInset * 2;

    [NSLayoutConstraint activateConstraints:@[
        [self.bottomActionsContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:5],
        [self.bottomActionsContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-5],
        [self.bottomActionsContainer.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-0],
        [self.bottomActionsContainer.heightAnchor constraintEqualToConstant:bottomActionsContainerHeight],
    ]];

    self.bottomActionsContainer.backgroundColor = AppClearClr;
    self.bottomActionsContainer.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    self.bottomActionsContainer.layer.shadowOpacity = 0.22;
    self.bottomActionsContainer.layer.shadowOffset = CGSizeMake(0, 4);
    self.bottomActionsContainer.layer.shadowRadius = 4.0;
    self.bottomActionsContainer.layer.cornerRadius = PPCorners + 10;

    self.actionsView = [PPQuickActionsView new];
    self.actionsView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.bottomActionsContainer addSubview:self.actionsView];

    [NSLayoutConstraint activateConstraints:@[
        [self.actionsView.leadingAnchor constraintEqualToAnchor:self.bottomActionsContainer.leadingAnchor constant:pad],
        [self.actionsView.trailingAnchor constraintEqualToAnchor:self.bottomActionsContainer.trailingAnchor constant:-pad],
        [self.actionsView.bottomAnchor constraintEqualToAnchor:self.bottomActionsContainer.bottomAnchor constant:-pad],
        [self.actionsView.heightAnchor constraintEqualToConstant:46],
    ]];

    self.actionsView.alpha = 0;

    [self.actionsView setActions:@[
        [PPQuickActionItem itemWithTitleKey:@"share"
                                   iconName:@"square.and.arrow.up.circle.fill"
                              iconNameOnTap:@"square.and.arrow.up.circle.fill"
                                      width:0
                                  configFor:ConfigForViewDataBottom
                                       menu:nil
                                    handler:^(UIView * _Nonnull sender) {
            
        }],
        [PPQuickActionItem itemWithTitleKey:kLang(@"sale")
                                   iconName:@"sellNew"
                              iconNameOnTap:@"sellNew"
                                      width:200
                                  configFor:ConfigForViewDataBottom
                                       menu:nil
                                    handler:^(UIView * _Nonnull sender) {
            
    }],
        [PPQuickActionItem itemWithTitleKey:kLang(@"delete")
                                   iconName:@"trash.circle.fill"
                              iconNameOnTap:@"trash.circle.fill"
                                      width:0
                                  configFor:ConfigForViewDataBottom
                                       menu:nil
                                    handler:^(UIView * _Nonnull sender) { [self viewDeleteAlert]; }]
    ]];
    

}

-(void)viewDeleteAlert
{
    //kLang(@"DeleteCardReason")
    [PPAlertHelper showTextFieldAlertIn:self title:kLang(@"DeleteCardAlert") subtitle:kLang(@"DeleteCardAlertDesc") placeholder:kLang(@"DeleteCardReason") initialText:nil confirmText:kLang(@"yes") cancelText:kLang(@"no") completion:^(NSString * _Nullable text, BOOL didConfirm) {
        
        if(!didConfirm) return;
        
        
        [PPHUD showLoading];
        FIRDocumentReference *CardRef = [[[AppManager sharedInstance].dF collectionWithPath:@"CardsCol"] documentWithPath:self.cardModel.ID];
        [CardRef updateData:@{@"isDeleted": @1,@"deleteReason": text} completion:^(NSError * _Nullable error) {
            if (error != nil) {
                NSLog(@"Error removing document: %@", error);
            } else {
                NSLog(@"Document successfully removed CardRef !");
                NSLog(@"RMV -->>> CardData.cardSection %ld == CardSectionNewChild",self.cardModel.cardSection);
                if(self.cardModel.cardSection == CardSectionNewChild)
                {
                    [PPHUD dismiss];
                    NSLog(@"RMV -->>> updateChildIsDeletedWithCardID: %@  CageID: %@",self.cardModel.ID,self.cardModel.CageID);
                    [ChildsDataManager updateChildWithCardID:self.cardModel.ID
                                                      cageID:self.cardModel.CageID
                                                        data:@{ @"isDeleted": @1 }
                                                   completion:^(NSError * _Nullable error) {
                        if (error) {
                            NSLog(@"❌ Failed to mark child deleted: %@", error);
                        }
                    }];                }
                else if (self.cardModel.cardSection == CardSectionArchive) {
                    [PPHUD dismiss];
                    NSString *targetArchiveDetID = self.cardModel.archiveID;
                    NSString *targetArchiveID = self.cardModel.masterArchiveID;
                    NSLog(@"RMV -->>> updateIsDeletedForArchiveID: %@  andArchiveDetailsID: %@",targetArchiveID,targetArchiveDetID);
                    //[self updateIsDeletedForArchiveID:targetArchiveID andArchiveDetailsID:targetArchiveDetID withNewValue:1 completion:nil];
                }
                
                [AppMgr showSnakBar:kLang(@"DeletedSuccess") withColor:[GM appPrimaryColor] andDuration:3 containerView:self.view];
                [PPHUD dismiss];
            }
        }];
        
    }];
    }

-(CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 0.00001;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 0.00001;
}

-(CGFloat)tableView:(UITableView *)tableView estimatedHeightForFooterInSection:(NSInteger)section
{
    return 0.00001;
}

-(CGFloat)tableView:(UITableView *)tableView estimatedHeightForHeaderInSection:(NSInteger)section
{
    return 0.00001;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end


/*
 
 
 - (UITableViewCell *)tableView:(UITableView *)tableView
          cellForRowAtIndexPath:(NSIndexPath *)indexPath {
     static NSString *TableIdentifier = @"DetailsTableViewCell";
     DetailsTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:
                              TableIdentifier];
     if (cell == nil) {
         cell = [[DetailsTableViewCell alloc]
                 initWithStyle:UITableViewCellStyleDefault
                 reuseIdentifier:TableIdentifier];
     }
     cell.delegate = self;
     
     
     
     if(indexPath.row == 5 || indexPath.row == 6 || indexPath.row == 7)
         cell.detailsButton.alpha = 1;
     
     
     
     
     
     if(indexPath.row == 5)
         [cell.detailsButton setTitle:@"DNA" forState:UIControlStateNormal];
     else
         [cell.detailsButton setTitle:kLang(@"showCard") forState:UIControlStateNormal];
     //NSString *attribute = [[self AppDelegate] getBirdSexual:[self.dataSourceForSearchResult[indexPath.row].attribute intValue]];
     // NSString *Sexual = [[self AppDelegate] getBirdSexual:[self.dataSourceForSearchResult[indexPath.row].Sexual intValue]] ;
    
    
     
     
     
     if(indexPath.row == 0)
         cell.titleLablel.text = [NSString stringWithFormat:@" %@",self.cardModel.RingID];
     else if(indexPath.row == 1)
         cell.titleLablel.text = [NSString stringWithFormat:@"%@:   %@",
                                  kLang(@"birdKind"),
                                  self.cardModel.subKindString];
     else if(indexPath.row == 2) {
         cell.titleLablel.text = [NSString stringWithFormat:@"%@:   %@",kLang(@"Attribute"),self.cardModel.getBirdAttribute];
     }
        
     else if(indexPath.row == 3)
         cell.titleLablel.text = [NSString stringWithFormat:@"%@:   %@",kLang(@"Classification"),self.cardModel.ClassificationString];
     else if(indexPath.row == 4)
         cell.titleLablel.text = [NSString stringWithFormat:@"%@:   %@",kLang(@"BirthDate"),[self formatDateFromDate:self.cardModel.BirthDate]];
     else if(indexPath.row == 5){
         cell.titleLablel.text = [NSString stringWithFormat:@"%@:   %ld",kLang(@"Sexual"),(long)self.cardModel.SexualTXT];
     }
         
     else if(indexPath.row == 6){
         
         if(![self.cardModel.FatherRingID isEqualToString:@"no_value"]){
             id fatherMatch = [[self.CardsdataSource filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %@",self.cardModel.FatherRingID]] firstObject];
             NSString *FRingID = fatherMatch ? [fatherMatch RingID] : nil;
             
             NSLog(@"FRingIDFRingIDFRingIDFRingIDFRingIDFRingID %@",FRingID);
             if([FRingID isEqualToString:@"(null)"] || FRingID == nil)
                 FRingID =  kLang(@"notFound");
             cell.titleLablel.text = [NSString stringWithFormat:@"%@:   %@",kLang(@"FatherRingID"),FRingID];
             
             if(_FatherCard.isDeleted == 1)
             {
                 cell.deleteInfoBTN.alpha = 1;
                 cell.deleteReason = _FatherCard.deleteReason;
                 cell.warningImageView.alpha = 1;
             }
             else{
                 cell.deleteInfoBTN.alpha = 0;
                 cell.warningImageView.alpha = 0;
             }
                 
             
         } else
         {
             cell.titleLablel.text = [NSString stringWithFormat:@"%@:   %@",kLang(@"FatherRingID"),self.cardModel.FatherRingIDString];
         }
     }
         
     else if(indexPath.row == 7){
         if(![self.cardModel.MotherRingID isEqualToString:@"no_value"]){
             id motherMatch = [[self.CardsdataSource filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %@",self.cardModel.MotherRingID]] firstObject];
             NSString *MRingID = motherMatch ? [motherMatch RingID] : nil;
             NSLog(@"FRingIDFRingIDFRingIDFRingIDFRingIDFRingID MRingID %@",MRingID);
             if([MRingID isEqualToString:@"(null)"] || MRingID == nil)
                 MRingID = kLang(@"notFound");
             cell.titleLablel.text = [NSString stringWithFormat:@"%@:   %@",kLang(@"MotherRingID"),MRingID];
             
             if(_MotherCard.isDeleted == 1)
             {
                 cell.deleteInfoBTN.alpha = 1;
                 cell.deleteReason = _MotherCard.deleteReason;
                 cell.warningImageView.alpha = 1;
             }
             else
             {
                 cell.warningImageView.alpha = 0;
                 cell.deleteInfoBTN.alpha = 0;
             }
                 
             
         } else
         {
             cell.titleLablel.text = [NSString stringWithFormat:@"%@:   %@",kLang(@"MotherRingID"),self.cardModel.MotherRingIDString];
         }
     }
     else if(indexPath.row == 8)
         cell.titleLablel.text = [NSString stringWithFormat:@"%@: %@",kLang(@"note"),self.cardModel.AdDescString];
     cell.cellRowIndex = indexPath.row;
     
     if(indexPath.row == 5)
     {
         if([self.cardModel.Dna isEqual:@"no_value"]){
             [cell setButtonEnabled:FALSE];
         } else {
             [cell setButtonEnabled:TRUE];
         }
             
        // cell.titleLablel.text = [NSString stringWithFormat:@"وصف الطير : %"];
     }
     
     if(indexPath.row == 6)
     {
         if([self.cardModel.FatherRingID isEqual:@"no_value"])
         {
             [cell setButtonEnabled:FALSE];
             cell.titleLablel.text = [NSString stringWithFormat:@"%@:   %@",kLang(@"FatherRingID"),kLang(@"notFound")];
         } else  [cell setButtonEnabled:TRUE];
     }
     
     if(indexPath.row == 7)
     {
         if([self.cardModel.MotherRingID isEqual:@"no_value"])
         {
             [cell setButtonEnabled:FALSE];
             cell.titleLablel.text =  [NSString stringWithFormat:@"%@:  %@",kLang(@"MotherRingID"),kLang(@"notFound")];
         } else [cell setButtonEnabled:TRUE];
     }
     
     cell.titleLablel.font = [GM MidFontWithSize:14];
     cell.detailsButton.titleLabel.font = [GM MidFontWithSize:12];
     
     if([Language languageVal] == 0)
     {
         cell.titleLablel.textAlignment = NSTextAlignmentLeft;
         cell.detailsButton.hx_x = self.tableView.hx_w - cell.detailsButton.hx_w - 10;
         cell.deleteInfoBTN.hx_x = cell.detailsButton.hx_x - cell.deleteInfoBTN.hx_w -  5;
     }
     else
     {
         cell.titleLablel.textAlignment = NSTextAlignmentRight;
         cell.detailsButton.hx_x = 10;
         cell.deleteInfoBTN.hx_x = cell.detailsButton.hx_maxx + 5;
     }
     return cell;
 }
 */
