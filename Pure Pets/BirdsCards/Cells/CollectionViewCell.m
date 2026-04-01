//
//  CollectionViewCell.m
//  collevtionViewWithSearchBar
//
//  Created by Homam on 2015-01-02.
//  Copyright (c) 2015 Homam. All rights reserved.
//

#import "CollectionViewCell.h"
#import "../Cells/DetailsTableViewCell.h"
#import "AppDelegate.h"
#import "viewDataVC.h"

@implementation CollectionViewCell 

-(AppDelegate *)AppDelegate { return (AppDelegate*)[[UIApplication sharedApplication]delegate]; }

- (IBAction)playButtonDidClick:(id)sender {
    return;
    if (self.playDelegate && [self.playDelegate respondsToSelector:@selector(cellPlayButtonDidClick:)]) {
        [self.playDelegate cellPlayButtonDidClick:self];
    }
}
- (void)setIndexPath:(NSIndexPath *)indexPath{
    _indexPath = indexPath;
    
    _playButton.hx_centerY = self.videoPlayView.hx_centerY;
}

- (UIButton *)createFullScreenButton{
   UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
   [button setImage:[UIImage imageNamed:@"play22"] forState:UIControlStateNormal];
    [button setImage:[UIImage imageNamed:@"fullscreen_icon_selected"] forState:UIControlStateSelected];

   [button addTarget:self action:@selector(fullScreenTapped:) forControlEvents:UIControlEventTouchUpInside];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    return button;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    
    // Initialization code
    [self setTopGard:_loanView];
    
    _tableView.dataSource=self;
    _tableView.delegate = self;
       
    self.clipsToBounds=NO;
    
    [_currentArchiveBTN.titleLabel setFont:[[AppManager sharedInstance] fontSize:12]];
    _shareBtn.tintColor = GM.appPrimaryColor;
    _archiveBtn.tintColor = GM.appPrimaryColor;
    _CardTitle.font = [[AppManager sharedInstance] boldFontSize:16];
    _laName.font = [[AppManager sharedInstance] fontSize:14];
    _RingID.font = [[AppManager sharedInstance] fontSize:14];
    _CategoryLabel.font = [[AppManager sharedInstance] fontSize:14];
    _GenderLabel.font = [[AppManager sharedInstance] fontSize:14];
    _BirthDateLabel.font = [[AppManager sharedInstance] fontSize:14];
    _DescLabel.font = [[AppManager sharedInstance] fontSize:14];
    _ageLabel.font = [[AppManager sharedInstance] fontSize:12];
    _splitTXT.font = [[AppManager sharedInstance] fontSize:14];
    _garAdded = 0;
    _cellBottomView.hx_x = _mainImageView.hx_x;
    _cellBottomView.hx_w = _mainImageView.hx_w;
    
    [self resetVideoFrame];
    
    [_shareBtn animateOnPress:YES];
    [_archiveBtn animateOnPress:YES];
    [_currentArchiveBTN animateOnPress:YES];
    
    
    NSString *ST = [NSString stringWithFormat:@"%@", self.CardData.splitID];
    if([ST isEqualToString:@"no_value"] || [ST isEqualToString:@""])
    {
        self.splitTXT.alpha = 0;
        self.DescLabel.hx_y = self.BirthDateLabel.hx_maxy;
    }
    else
    {
        self.splitTXT.alpha = 1;
        self.DescLabel.hx_y = self.splitTXT.hx_maxy;
    }
    
    [self.playButton.layer setShadowColor:[GM appPrimaryColor].CGColor];
    [self.playButton.layer setShadowOffset:CGSizeMake(1, 1)];
    [self.playButton.layer setShadowOpacity:0.7];
    [self.playButton.layer setShadowRadius:2];
    
            self.playerLayer = [[AVPlayerLayer alloc] init];
            self.playerLayer.frame = self.contentView.bounds;
            self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
            [self.contentView.layer addSublayer:self.playerLayer];
    
    self.originalSuperview = self.videoContainerView.superview;
    self.originalConstraints = [NSMutableArray arrayWithArray:self.videoContainerView.constraints];
    
    
    UIButton *button =  [self createFullScreenButton];
    [self.videoContainerView addSubview:button];
    
    [button.trailingAnchor constraintEqualToAnchor:self.videoContainerView.trailingAnchor constant: -10].active = YES;
    [button.bottomAnchor constraintEqualToAnchor:self.videoContainerView.bottomAnchor constant:-10].active = YES;
    [button.widthAnchor constraintEqualToConstant:30].active = YES;
    [button.heightAnchor constraintEqualToConstant:30].active = YES;
    button.alpha =0;
}



- (void)fullScreenTapped:(UIButton*)sender{
    sender.selected = !sender.selected;
    if(sender.selected){
        [self switchToFullScreenMode];

    }else{
        [self switchToNormalScreenMode];
    }

}

- (void)switchToFullScreenMode {
    //1. save original parameters
    self.originalSuperview = self.videoContainerView.superview;
    self.originalConstraints = [NSMutableArray arrayWithArray:self.videoContainerView.constraints];

     // 2. remove from original superview
    [self.videoContainerView removeFromSuperview];
    // 3. add to window
     UIWindow *window = [UIApplication sharedApplication].keyWindow;
    [window addSubview:self.videoContainerView];

    // 4. Disable autoresizing mask and set constraints to fullscreen
     self.videoContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    [[window.topAnchor constraintEqualToAnchor:self.videoContainerView.topAnchor] setActive:YES];
   [[window.bottomAnchor constraintEqualToAnchor:self.videoContainerView.bottomAnchor] setActive:YES];
     [[window.leadingAnchor constraintEqualToAnchor:self.videoContainerView.leadingAnchor] setActive:YES];
    [[window.trailingAnchor constraintEqualToAnchor:self.videoContainerView.trailingAnchor] setActive:YES];
     [window setNeedsUpdateConstraints];


    [[UIDevice currentDevice] setValue:[NSNumber numberWithInteger:UIInterfaceOrientationLandscapeRight] forKey:@"orientation"];
    [UIViewController attemptRotationToDeviceOrientation];

}

- (void)switchToNormalScreenMode {
    //1. Remove from full screen
    [self.videoContainerView removeFromSuperview];

    //2. add to super view
    [self.originalSuperview addSubview:self.videoContainerView];
    //3. re-add constraints
    self.videoContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint deactivateConstraints:self.videoContainerView.constraints];
    [NSLayoutConstraint activateConstraints:self.originalConstraints];
     [self.videoContainerView.superview setNeedsUpdateConstraints];
    [[UIDevice currentDevice] setValue:[NSNumber numberWithInteger:UIInterfaceOrientationPortrait] forKey:@"orientation"];
    [UIViewController attemptRotationToDeviceOrientation];

}

-(void)resetVideoFrame
{
    _videoContainerView.hx_x = _mainImageView.hx_x;
    _videoContainerView.hx_w = _mainImageView.hx_w;
    _videoContainerView.hx_y = _mainImageView.hx_y;
    _videoContainerView.hx_h = _mainImageView.hx_h;
    
    _cellBottomView.hx_x = _mainImageView.hx_x;
    _cellBottomView.hx_w = _mainImageView.hx_w;
    _cellBottomView.hx_y = _mainImageView.hx_y;
    
    _playButton.hx_x =  ( _videoContainerView.hx_w - _playButton.hx_w) / 2;
    
}




// // *************************************************************************************************************
-(void)setButtonGardDisabled
{
    CAGradientLayer *theViewGradient = [CAGradientLayer layer];
    theViewGradient.colors = [NSArray arrayWithObjects:(id)[UIColor colorWithRed:240.0/255.0 green:240.0/255.0 blue:240.0/255.0 alpha:1.0].CGColor, (id)[UIColor colorWithRed:221.0/255.0 green:221.0/255.0 blue:221.0/255.0 alpha:1.0].CGColor,  nil];
    theViewGradient.frame = self.currentArchiveBTN.bounds;
    theViewGradient.cornerRadius = 0.0;
    
    [self.currentArchiveBTN.layer insertSublayer:theViewGradient atIndex:0];
  
}

-(void)setButtonGardActive
{
    CAGradientLayer *theViewGradient = [CAGradientLayer layer];
    theViewGradient.colors = [NSArray arrayWithObjects:(id)[GM appPrimaryColor].CGColor, (id)GM.AppPrimaryColorShainer.CGColor,  nil];
    theViewGradient.frame = self.currentArchiveBTN.bounds;
    theViewGradient.cornerRadius = 0.0;
    
    [self.currentArchiveBTN.layer insertSublayer:theViewGradient atIndex:0];
  
}

-(void)gardToView:(UIView *)theView colorOne:(UIColor *)colorOne colorTwo:(UIColor *)colorTwo colorThree:(UIColor *)colorThree rds:(float )rds
{
    // Create the gradient
    if(_garAdded == 1)
        return;
    _garAdded = 1;
    CAGradientLayer *theViewGradient = [CAGradientLayer layer];
    theViewGradient.colors = [NSArray arrayWithObjects: (id)colorOne.CGColor, (id)colorTwo.CGColor,(id)colorThree.CGColor, nil];
    theViewGradient.frame = theView.bounds;
    theViewGradient.cornerRadius = rds;
    
    [theView.layer insertSublayer:theViewGradient atIndex:0];
    
}
-(void)prepareForReuse
{
    [super prepareForReuse];
    //NSLog(@"super prepareForReuse");
    NSString *archieTXT =[NSString stringWithFormat:@"%@: ",kLang(@"Archive")];
    
    
    self.currentArchiveBTN.backgroundColor = [UIColor colorWithHexString:@"#F0F0F0"];
    self.currentArchiveBTN.tintColor = [UIColor colorWithHexString:@"#555555"];
    [self.currentArchiveBTN.titleLabel setTextColor:[UIColor colorWithHexString:@"#000000"]];
    [self.currentArchiveBTN setTitle:[NSString stringWithFormat:@"%@ %@",archieTXT,kLang(@"unDefind")] forState:UIControlStateNormal];
    [_currentArchiveBTN.titleLabel setFont:[[AppManager sharedInstance] fontSize:13]];

    self.haveArchive = 0;
    self.cellActive =0;
    NSString *ST = [NSString stringWithFormat:@"%@", self.CardData.splitID];
    if([ST isEqualToString:@"no_value"] || [ST isEqualToString:@""])
    {
        self.splitTXT.alpha = 0;
        self.DescLabel.hx_y = self.BirthDateLabel.hx_maxy;
    }
    else
    {
        self.splitTXT.alpha = 1;
        self.DescLabel.hx_y = self.splitTXT.hx_maxy;
    }
    
    _cellBottomView.hx_x = _mainImageView.hx_x;
    _cellBottomView.hx_w = _mainImageView.hx_w;
    
    _playButton.hx_centerY = self.videoPlayView.hx_centerY;
}

- (void)play {
    if (self.player) {
        [self.player play];
    }
}

- (void)pause {
    if (self.player) {
        [self.player pause];
    }
}


-(void)layoutSubviews
{
    [super layoutSubviews];
    
    [self gardToView:self.cellBottomView colorOne:[UIColor colorWithRed:0.0/255.0 green:0.0/255.0 blue:0.0/255.0 alpha:0.8] colorTwo:[UIColor colorWithRed:0.0/255.0 green:0.0/255.0 blue:0.0/255.0 alpha:0.4] colorThree:[UIColor clearColor] rds:0];
    
    [[AppManager sharedInstance] setCornerRadius:17.00 withOpacity:0.5 shadowOffset:4 shadowRadius:3 onView:self  color:[GM AppShadowColor]];
    
    //[[AppManager sharedInstance] setCornerRadius:25 withOpacity:0.4 shadowOffset:5 shadowRadius:3 //onView:self  color:[GM appPrimaryColor]Shadow];
    _playButton.hx_centerY = self.videoPlayView.hx_centerY;
}

   

-(void)setTopGard:(UIView *)theView
{
    CAGradientLayer *theViewGradient = [CAGradientLayer layer];
    if(theViewGradient.cornerRadius != 20)
    {
        UIColor *topColor =[UIColor colorWithHexString:@"#000000"];
        UIColor *bottomColor =[UIColor colorWithRed:0.0/255.0 green:0.0/255.0 blue:0.0/255.0 alpha:0];
        
        
        theViewGradient.colors = [NSArray arrayWithObjects:(id)topColor.CGColor, (id)bottomColor.CGColor,  nil];
        theViewGradient.frame = theView.bounds;
        theViewGradient.cornerRadius = 20;
        if (@available(iOS 11.0, *)) {
            [theViewGradient setMaskedCorners:kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner];
        } else {
            // Fallback on earlier versions
        }
        //Add gradient to view
        [theView.layer insertSublayer:theViewGradient atIndex:0];
    }
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    return 9;
}

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
    
    NSString *subKindName;
    NSArray<SubKindModel *> *SubKindsArrayLocal;
    SubKindsArrayLocal  =  [MKM getSubKindArray:1];
    NSMutableArray* SubKindsArray = [[NSMutableArray alloc] init];
    for (int i = 0; i < SubKindsArrayLocal.count; i++) {
        if([SubKindsArrayLocal objectAtIndex:i].ID == self.CardData.SubKind)
            subKindName = [SubKindsArrayLocal objectAtIndex:i].SubKindNameAr;
    }
    
    if(indexPath.row == 5 || indexPath.row == 6 || indexPath.row == 7)
        cell.detailsButton.alpha = 1;
    
    if(indexPath.row == 5)
    [cell.detailsButton setTitle:@"عرض DNA" forState:UIControlStateNormal];
    
    
   // NSInteger Sexual = [[self AppDelegate] getBirdSexualID:_Sexual.text];
   // NSInteger attribute = [[self AppDelegate] getBirdAttributeID:_attribute.text];
   // [[self AppDelegate] getBirdAttribute:self.CardData.attribute]
   // [[self AppDelegate] getBirdSexual:self.CardData.Sexual]
    if(indexPath.row == 0)
        cell.titleLablel.text = [NSString stringWithFormat:@" %@",self.CardData.RingID];
    else if(indexPath.row == 1)
        cell.titleLablel.text = [NSString stringWithFormat:@"النوع : %@",subKindName];
    else if(indexPath.row == 2)
        cell.titleLablel.text = [NSString stringWithFormat:@"الفئه اللونية :  %@",self.CardData.getBirdAttribute];
    else if(indexPath.row == 3)
        cell.titleLablel.text = [NSString stringWithFormat:@"الطفرة اللونية : %@",self.CardData.ClassificationString];
    else if(indexPath.row == 4)
        cell.titleLablel.text = [NSString stringWithFormat:@"تاريخ الانتاج :  %@",self.CardData.BirthDate];
    else if(indexPath.row == 5)
        cell.titleLablel.text = [NSString stringWithFormat:@"الجنس : %@",self.CardData.SexualTXT];
    else if(indexPath.row == 6)
        cell.titleLablel.text = [NSString stringWithFormat:@"رقم الاب :  %@",self.CardData.FatherRingID];
    else if(indexPath.row == 7)
        cell.titleLablel.text = [NSString stringWithFormat:@"رقم  الام : %@",self.CardData.MotherRingID];
    else if(indexPath.row == 8)
        cell.titleLablel.text = [NSString stringWithFormat:@"وصف الطير : %@",self.CardData.AdDescString];
    cell.cellRowIndex = indexPath.row;
    
    if(indexPath.row == 5)
    {
        if([self.CardData.Dna isEqual:@""])
            cell.detailsButton.enabled = false;
       // cell.titleLablel.text = [NSString stringWithFormat:@"وصف الطير : %"];
    }
    
    if(indexPath.row == 6)
    {
        if([self.CardData.FatherRingID isEqual:@""])
        {
            cell.detailsButton.enabled = false;
            cell.titleLablel.text = [NSString stringWithFormat:@"رقم الاب :  %@",@"لا يوجد"];
        }
    }
    
    if(indexPath.row == 7)
    {
        if([self.CardData.MotherRingID isEqual:@""])
        {
            cell.detailsButton.enabled = false;
            cell.titleLablel.text =  [NSString stringWithFormat:@"رقم  الام : %@",@"لا يوجد"];
        }
    }
    
   
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
   
}

-(void)showData:(NSString *)parentID rowIndex:(long)rowIndex
{
    if(rowIndex == 5)
    {
        NSMutableArray *photos = [NSMutableArray array];
        NSString *url = [NSString stringWithFormat:@"https://purepets.net/uploads/%@/%@",[GM CardsImagesRefStr],self.CardData.Dna];
        [ImageViewerManager configureDefaultSettings];
        //[ImageViewerManager sharedManager].delegate = self;
        [[ImageViewerManager sharedManager] presentWithImageURLs:@[url]
                                                  fromController:AppMgr.topViewController
                                                        currentIndex:0
                                                          sourceView:self
                                                    placeholderImage:[UIImage imageNamed:@"placeholder"]];
        return;
    }
    
    if(rowIndex == 6)
    {
        viewDataVC *add=[viewDataVC new];
        add.cardModel = _FatherCard;
        [self.VC presentViewController:add animated:YES completion:nil];
    }
    
    if(rowIndex == 7)
    {
        viewDataVC *add=[viewDataVC new];
        add.cardModel = _MotherCard;
        [self.VC presentViewController:add animated:YES completion:nil];
    }
    
   
    
    // // NSLog(@"parentID %@",parentID);
}

-(void)LoadData
{
   
    //NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    // getting an NSString
    __block NSString  *userID = UserManager.sharedManager.currentUser.ID;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *Strd = [NSString stringWithFormat:@"https://purepets.net/db.php?QureyType=GetParentDet&FatherRingID=%@&MotherRingID=%@&userID=%@",self.CardData.FatherRingID,self.CardData.MotherRingID,userID];
     NSURL *URLtyd = [NSURL URLWithString:Strd];
     NSData  *tDd = [NSData  dataWithContentsOfURL:URLtyd];
     NSError *Errod;
      NSMutableArray *json = [NSJSONSerialization JSONObjectWithData:tDd options:kNilOptions error:&Errod];
          // // NSLog(@"Cell CardsdataSourcejson :::::: %@",json);
       self.CardsdataSource = [NSArray<CardModel *> modelArrayWithClass:CardModel.class json:json];
        
        if(![self.CardData.FatherRingID isEqual:@""] && ![self.CardData.MotherRingID isEqual:@""])
        {
            self.FatherCard = [self.CardsdataSource objectAtIndex:0];
            self.MotherCard = [self.CardsdataSource objectAtIndex:1];
        }
        
        if(![self.CardData.FatherRingID isEqual:@""] && [self.CardData.MotherRingID isEqual:@""])
        {
            self.FatherCard = [self.CardsdataSource firstObject];
        }
        
        if([self.CardData.FatherRingID isEqual:@""] && ![self.CardData.MotherRingID isEqual:@""])
        {
            self.MotherCard = [self.CardsdataSource firstObject];
        }
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            
        }];
        
      });
}

- (IBAction)delBTN:(id)sender {
    
    FTPopOverMenuConfiguration *configuration = [FTPopOverMenuConfiguration defaultConfiguration];
    configuration.menuRowHeight = 30;
    configuration.backgroundColor =[GM appPrimaryColor];
    configuration.menuWidth = 120;
    configuration.textColor = [UIColor whiteColor];
    configuration.textFont = [[AppManager sharedInstance] fontSize:14];
    configuration.borderColor = [UIColor blackColor];
    configuration.borderWidth = 0.1;
    configuration.textAlignment = NSTextAlignmentCenter;
    configuration.ignoreImageOriginalColor = YES;// set 'ignoreImageOriginalColor' to YES, images color will be same as textColor
    configuration.allowRoundedArrow = YES;

    
     
//@[[UIImage imageNamed:@"eye"],[UIImage imageNamed:@"giving"],[UIImage imageNamed:@"bribery"]]
[FTPopOverMenu showForSender:sender
               withMenuArray:@[kLang(@"editCard")
                               , kLang(@"deleteCard")]
                  imageArray:nil
               configuration:configuration
                   doneBlock:^(NSInteger selectedIndex) {
                       // // NSLog(@"done block. do something. selectedIndex : %ld", (long)selectedIndex);
  
    [self.delegate deleteEditOptions:self->_cellRowIndex index:selectedIndex CardData:self.CardData cellView:self.contentView cellIndexPath:self.cellIndexPath];
                   } dismissBlock:^{
                       
                       // // NSLog(@"user canceled. do nothing.");
                       
//                           FTPopOverMenuConfiguration *configuration = [FTPopOverMenuConfiguration defaultConfiguration];
//                           configuration.allowRoundedArrow = !configuration.allowRoundedArrow;
                       
                   }];
    
}

- (IBAction)postAdBTN:(id)sender {
    
    // Do any of the following setting to set the style (Only set what you want to change)
   // return;
        FTPopOverMenuConfiguration *configuration = [FTPopOverMenuConfiguration defaultConfiguration];
        configuration.menuRowHeight = 30;
        configuration.backgroundColor =[GM appPrimaryColor];
        configuration.menuWidth = 120;
        configuration.textColor = [UIColor whiteColor];
    configuration.textFont = [[AppManager sharedInstance] fontSize:14];
        configuration.borderColor = [UIColor blackColor];
        configuration.borderWidth = 0.1;
        configuration.textAlignment = NSTextAlignmentCenter;
        configuration.ignoreImageOriginalColor = YES;// set 'ignoreImageOriginalColor' to YES, images color will be same as textColor
        configuration.allowRoundedArrow = YES;
    
  
    
    
//@[[UIImage imageNamed:@"eye"],[UIImage imageNamed:@"giving"],[UIImage imageNamed:@"bribery"]]
    [FTPopOverMenu showForSender:sender
                   withMenuArray:@[kLang(@"share_review"),
                                   kLang(@"share_loan"),
                                   kLang(@"share_sell")
                                   ,kLang(@"share_other")
                                   ,kLang(@"share_story")]
                      imageArray:nil
                   configuration:configuration
                       doneBlock:^(NSInteger selectedIndex) {
                           // // NSLog(@"done block. do something. selectedIndex : %ld", (long)selectedIndex);
        [self.delegate shareCard:self->_cellRowIndex index:selectedIndex cardImage:self.mainImageView.image subKind:self->_subKind cardID:self.CardData.ID];
                       } dismissBlock:^{
                           
                           // // NSLog(@"user canceled. do nothing.");
                           
//                           FTPopOverMenuConfiguration *configuration = [FTPopOverMenuConfiguration defaultConfiguration];
//                           configuration.allowRoundedArrow = !configuration.allowRoundedArrow;
                           
                       }];
    
    //
  //  return;
    
}



- (IBAction)moreBTN:(id)sender {
    
    // Do any of the following setting to set the style (Only set what you want to change)
    [self.delegate moreCardOptions:self.cellRowIndex index:0 CardData:self.CardData cellView:self.contentView cellIndexPath:self.cellIndexPath];
    
}


- (IBAction)showArchiveBTN:(id)sender {
    //if(self.haveArchive ==0)
    
    // // NSLog(@"self.archiveClass %@   self.archiveClass.archiveDetailsArray %ld",self.archiveClass,self.archiveClass.ArchiveDetArray.count);
    [self.delegate showArchive:_cellIndexPath archiveClass:self.archiveClass haveArchive:self.haveArchive CardData:self.CardData];
}


@end
