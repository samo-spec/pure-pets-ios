//
//  CardsCell.m
//  collevtionViewWithSearchBar
//
//  Created by Homam on 2015-01-02.
//  Copyright (c) 2015 Homam. All rights reserved.
//

#import "CardsCell.h"
#import "AppDelegate.h"
#import "viewDataVC.h"

@implementation CardsCell

-(AppDelegate *)AppDelegate { return (AppDelegate*)[[UIApplication sharedApplication]delegate]; }

- (IBAction)playButtonDidClick:(id)sender {
  
}
- (void)setIndexPath:(NSIndexPath *)indexPath{
    _indexPath = indexPath;
    
    _playButton.hx_centerY = self.videoPlayView.hx_centerY;
}


- (void)awakeFromNib {
    [super awakeFromNib];
   
    self.clipsToBounds=NO;
    
    [_currentArchiveBTN.titleLabel setFont:[GM MidFontWithSize:12]];
    _shareBtn.tintColor = GM.appPrimaryColor;
    _archiveBtn.tintColor = GM.appPrimaryColor;
    _CardTitle.font = [GM boldFontWithSize:16];
    _laName.font = [GM MidFontWithSize:14];
    _RingID.font = [GM MidFontWithSize:14];
    _CategoryLabel.font = [GM MidFontWithSize:14];
    _GenderLabel.font = [GM MidFontWithSize:14];
    _BirthDateLabel.font = [GM MidFontWithSize:14];
    _DescLabel.font = [GM MidFontWithSize:14];
    _ageLabel.font = [GM MidFontWithSize:12];
    _splitTXT.font = [GM MidFontWithSize:14];
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
    
    [self.playButton.layer setShadowColor:[GM AppShadowColor].CGColor];
    [self.playButton.layer setShadowOffset:CGSizeMake(1, 1)];
    [self.playButton.layer setShadowOpacity:0.7];
    [self.playButton.layer setShadowRadius:2];
    
    self.playerLayer = [[AVPlayerLayer alloc] init];
    self.playerLayer.frame = self.contentView.bounds;
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.contentView.layer addSublayer:self.playerLayer];
    
    self.originalSuperview = self.videoContainerView.superview;
    self.originalConstraints = [NSMutableArray arrayWithArray:self.videoContainerView.constraints];
    
    _currentArchiveBTN.layer.cornerRadius = _currentArchiveBTN.hx_h / 2;
    _saleBirdBTN.layer.cornerRadius = 5;
    _saleBirdBTN.backgroundColor = [GM appPrimaryColor];
    _saleBirdBTN.titleLabel.text = kLang(@"sale");
    [_saleBirdBTN.titleLabel setFont:[GM MidFontWithSize:14]];
    [GM setShadow:_saleBirdBTN sh_Color:[GM AppShadowColor] cGSize:CGSizeMake(1, 2) sh_Opacity:0.5 radius:2];
    _saleBirdBTN.semanticContentAttribute =
    UISemanticContentAttributeForceRightToLeft;
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



-(void)prepareForReuse
{
    [super prepareForReuse];
    //NSLog(@"super prepareForReuse");
    NSString *archieTXT =[NSString stringWithFormat:@"%@: ",kLang(@"Archive")];
    
    
    self.currentArchiveBTN.backgroundColor = AppBackgroundClr;
    self.currentArchiveBTN.tintColor = [UIColor colorWithHexString:@"#555555"];
    [self.currentArchiveBTN.titleLabel setTextColor:[UIColor colorWithHexString:@"#000000"]];
    [self.currentArchiveBTN setTitle:[NSString stringWithFormat:@"%@ %@",archieTXT,kLang(@"unDefind")] forState:UIControlStateNormal];
    [_currentArchiveBTN.titleLabel setFont:[GM MidFontWithSize:13]];

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
    [[AppManager sharedInstance] setCornerRadius:22 withOpacity:0.02 shadowOffset:3 shadowRadius:5 onView:self  color:[GM AppShadowColor]];
    _playButton.hx_centerY = self.videoPlayView.hx_centerY;
}

   

- (IBAction)delBTN:(id)sender {
    
    
    FTPopOverMenuModel *archive = [[FTPopOverMenuModel alloc] init];
    archive.title = kLang(@"archive");
    // No submenu for item1
    
    FTPopOverMenuModel *sale = [[FTPopOverMenuModel alloc] init];
    sale.title = kLang(@"sale");
    // No submenu for item1
    
    
    FTPopOverMenuModel *editCard = [[FTPopOverMenuModel alloc] init];
    editCard.title = kLang(@"editCard");
    // No submenu for item1

    FTPopOverMenuModel *deleteCard = [[FTPopOverMenuModel alloc] init];
    deleteCard.title = kLang(@"deleteCard");
    // No submenu for item1
    
    
    FTPopOverMenuModel *craeteQrCode = [[FTPopOverMenuModel alloc] init];
    craeteQrCode.title = kLang(@"craeteQrCode");
    // No submenu for item1
    
    NSArray *menuArray = @[archive,editCard,deleteCard,craeteQrCode];
    
    
    
    FTPopOverMenuConfiguration *configuration = [FTPopOverMenuConfiguration defaultConfiguration];
    configuration.menuRowHeight = 30;
    configuration.backgroundColor = [GM appPrimaryColor];
    configuration.menuWidth = 100;
    configuration.textColor = [UIColor whiteColor];
    configuration.textFont = [GM MidFontWithSize:12];
    configuration.borderColor = [UIColor blackColor];
    configuration.borderWidth = 0.1;
    configuration.textAlignment = NSTextAlignmentCenter;
    configuration.ignoreImageOriginalColor = YES;// set 'ignoreImageOriginalColor' to YES, images color will be same as textColor
    configuration.allowRoundedArrow = YES;
    //@[[UIImage imageNamed:@"eye"],[UIImage imageNamed:@"giving"],[UIImage imageNamed:@"bribery"]]
    [FTPopOverMenu showForSender:sender
               withMenuArray:menuArray
                  imageArray:nil
                  configuration:configuration
                  doneBlock:^(NSInteger selectedIndex) {
  
        switch (selectedIndex) {
            case 0:
                [self.delegate archiveCardData:self.CardData cellIndexPath:self.cellIndexPath];
                break;
                
            case 1:
                [self.delegate deleteEditOptions:self->_cellRowIndex index:0 CardData:self.CardData cellView:self.contentView cellIndexPath:self.cellIndexPath];
                break;
                
                
            case 2:
                [self.delegate deleteEditOptions:self->_cellRowIndex index:1 CardData:self.CardData cellView:self.contentView cellIndexPath:self.cellIndexPath];
                break;
                
                
            case 3:
                [self.delegate deleteEditOptions:self->_cellRowIndex index:2 CardData:self.CardData cellView:self.contentView cellIndexPath:self.cellIndexPath];
                break;
                
            default:
                break;
        }
        
        
    
                   } dismissBlock:^{
                       
                       // // NSLog(@"user canceled. do nothing.");
                       
//                           FTPopOverMenuConfiguration *configuration = [FTPopOverMenuConfiguration defaultConfiguration];
//                           configuration.allowRoundedArrow = !configuration.allowRoundedArrow;
                       
                   }];
    
}

- (IBAction)postAdBTN:(id)sender {
    
    FTPopOverMenuModel *share = [[FTPopOverMenuModel alloc] init];
    share.title = kLang(@"share");
    // No submenu for item1
    
    FTPopOverMenuModel *sale = [[FTPopOverMenuModel alloc] init];
    sale.title = kLang(@"sale");
    // No submenu for item1
    
    
    FTPopOverMenuModel *share_story = [[FTPopOverMenuModel alloc] init];
    share_story.title = kLang(@"share_story");
    // No submenu for item1

    
    NSArray *menuArray = @[share,share_story,sale];
    
    
    FTPopOverMenuConfiguration *configuration = [FTPopOverMenuConfiguration defaultConfiguration];
    configuration.menuRowHeight = 30;
    configuration.backgroundColor = [UIColor whiteColor];
    configuration.menuWidth = 100;
    configuration.textColor = [GM appPrimaryColor];
    configuration.textFont = [GM MidFontWithSize:12];
    configuration.borderColor = [UIColor blackColor];
        configuration.borderWidth = 0.1;
        configuration.textAlignment = NSTextAlignmentCenter;
        configuration.ignoreImageOriginalColor = YES;// set 'ignoreImageOriginalColor' to YES, images color will be same as textColor
        configuration.allowRoundedArrow = YES;
        [FTPopOverMenu showForSender:sender
                   withMenuArray:menuArray
                      imageArray:nil
                   configuration:configuration
                       doneBlock:^(NSInteger selectedIndex) {
                           // // NSLog(@"done block. do something. selectedIndex : %ld", (long)selectedIndex);
            switch (selectedIndex) {
                case 0:
                    [self.delegate shareCard:self->_cellRowIndex index:3 cardImage:self.mainImageView.image subKind:self->_subKind cardID:self.CardData.ID];
                    break;
                    
                case 1:
                    [self.delegate shareCard:self->_cellRowIndex index:4 cardImage:self.mainImageView.image subKind:self->_subKind cardID:self.CardData.ID];
                    break;
                    
                    
                case 2:
                    [self.delegate sellThisCard:self.CardData lastLocation:CardSectionCards cageIndex:0];
                    break;
                    
                 
                default:
                    break;
            }
            
            
            
                       } dismissBlock:^{
                           
                           // // NSLog(@"user canceled. do nothing.");
                           
//                           FTPopOverMenuConfiguration *configuration = [FTPopOverMenuConfiguration defaultConfiguration];
//                           configuration.allowRoundedArrow = !configuration.allowRoundedArrow;
                           
                       }];
    
    //
  //  return;
    
}



- (IBAction)moreBTN:(id)sender {
    
    FTPopOverMenuConfiguration *configuration = [FTPopOverMenuConfiguration defaultConfiguration];
    configuration.menuRowHeight = 30;
    configuration.backgroundColor =[GM appPrimaryColor];
    configuration.menuWidth = 70;
    configuration.textColor = [UIColor whiteColor];
    configuration.textFont =[GM MidFontWithSize:12];
    configuration.borderColor = [UIColor blackColor];
    configuration.borderWidth = 0.1;
    configuration.textAlignment = NSTextAlignmentCenter;
    configuration.ignoreImageOriginalColor = YES;// set 'ignoreImageOriginalColor' to YES, images color will be same as textColor
    configuration.allowRoundedArrow = YES;
    
    FTPopOverMenuModel *item1 = [[FTPopOverMenuModel alloc] init];
    item1.title = kLang(@"archive");
    // No submenu for item1

    FTPopOverMenuModel *item11 = [[FTPopOverMenuModel alloc] init];
    item11.title = kLang(@"sale");
    // No submenu for item1
    
    
    FTPopOverMenuModel *subItem1 = [[FTPopOverMenuModel alloc] init];
    subItem1.title = @"Sub Option 1";

    FTPopOverMenuModel *subItem2 = [[FTPopOverMenuModel alloc] init];
    subItem2.title = @"Sub Option 2";

    FTPopOverMenuModel *item2 = [[FTPopOverMenuModel alloc] init];
    item2.title = @"Option 2";
    // Add submenu items to item2
    item2.subMenuArray = @[subItem1, subItem2];

    NSArray *menuArray = @[item1,item11, item2];
    
    
    [FTPopOverMenu showForSender:sender
               withMenuArray:menuArray
                      imageArray:@[[UIImage imageNamed:@"icons_share"],[UIImage imageNamed:@"icons_share"],[UIImage imageNamed:@"icons_share"]]
               configuration:configuration
                   doneBlock:^(NSInteger selectedIndex) {
                       // // NSLog(@"done block. do something. selectedIndex : %ld", (long)selectedIndex);
        if(selectedIndex == 0)
            [self.delegate archiveCardData:self.CardData cellIndexPath:self.cellIndexPath];
        if(selectedIndex == 1)
            [self.delegate sellThisCard:self.CardData lastLocation:CardSectionCards cageIndex:0];
                   } dismissBlock:^{
                   }];
    
}


- (IBAction)showArchiveBTN:(id)sender {
    //if(self.haveArchive ==0)
    
    // // NSLog(@"self.archiveClass %@   self.archiveClass.archiveDetailsArray %ld",self.archiveClass,self.archiveClass.ArchiveDetArray.count);
   // [self.delegate showArchive:_cellIndexPath archiveClass:self.archiveClass haveArchive:self.haveArchive CardData:self.CardData];
}


@end
