//
//  selectChildCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 26/07/2024.
//

#import "selectChildCell.h"



@interface selectChildCell ()
@property NSString *showCardTitle;
@property NSString *deleteCardTitle;
@property NSString *archiveCardTitle;
@property NSString *transferTitle;
@property NSString *sellTitle;
@property TTGSnackbar *snakBar;
@end
@implementation selectChildCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
    
    self.showCardTitle    = kLang(@"menu_showCard");
    self.deleteCardTitle  = kLang(@"menu_deleteChick");
    self.archiveCardTitle = kLang(@"menu_archiveChick");
    self.transferTitle    = kLang(@"menu_transferChick");
    self.sellTitle        = kLang(@"menu_sellChick");
    
    
    self.RingID.font = [GM MidFontWithSize:16];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (IBAction)showCardBTN:(id)sender {
    [self showCard];
}

-(void)showCard
{
    if(self.isFound == 0)
    {
        
        __weak typeof(self) weakSelf = self;

        NSString *title = kLang(@"child_no_card_title");
        NSString *subtitle = [NSString stringWithFormat:
                              kLang(@"child_no_card_message_fmt"),
                              self.BirdRingID];

        [PPAlertHelper showConfirmationIn:AppMgr.topViewController
                                    title:title
                                 subtitle:subtitle
                            confirmButton:kLang(@"yes")
                             cancelButton:kLang(@"no")
                                     icon:nil
                             confirmBlock:^(NSString * _Nullable text, BOOL didConfirm)
        {
            if (!didConfirm) return;

            [weakSelf.delegate goToNewCard:weakSelf.BirdRingID
                                    fromVC:@"selectChildViewController"
                                   isFound:weakSelf.isFound
                                 ImagesArr:weakSelf.ImagesArr
                                    cardID:weakSelf.cardID];
        }
                             cancelBlock:^{
                                 // no-op
                             }];
    }
    else {
        [self.delegate goToNewCard:self.BirdRingID fromVC:@"selectChildViewController" isFound:self.isFound ImagesArr:self.ImagesArr cardID:self.cardID];
    }
}

- (IBAction)delChildBTN:(id)sender {
    [self deleteChild];
}






-(void)deleteChild
{
    __weak typeof(self) weakself = self;

    NSString *title = kLang(@"delete_child_title");
    NSString *subtitle = [NSString stringWithFormat:kLang(@"delete_child_message_fmt"), self.BirdRingID];

    [PPAlertHelper showConfirmationIn:AppMgr.topViewController
                                title:title
                             subtitle:subtitle
                        confirmButton:kLang(@"yes")
                         cancelButton:kLang(@"no")
                                 icon:nil
                         confirmBlock:^(NSString * _Nullable text, BOOL didConfirm)
    {
        if (!didConfirm) return;

        [weakself.delegate DeleteChild:weakself.childModel FromCageWithID:weakself.CageID];

        /*
         
         [weakSelf.delegate goToNewCard:weakSelf.BirdRingID
                                 fromVC:@"selectChildViewController"
                                isFound:weakSelf.isFound
                              ImagesArr:weakSelf.ImagesArr
                                 cardID:weakSelf.cardID];
         */
    }
                         cancelBlock:^{
                             // intentionally empty
                         }];
}

- (IBAction)moreBTN:(id)sender
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
        [UIImage imageNamed:@"dogCus.fill"],//dogCus
        [UIImage imageNamed:@"archiveCus.fill"],
        [UIImage imageNamed:@"deleteCus.fill"],
        [UIImage imageNamed:@"love-birdsCus.fill"],
        [UIImage imageNamed:@"hotSaleee.fill"]
    ];
    NSIndexSet *destructive = [NSIndexSet indexSetWithIndex:2];

    [PPMenuHelper presentMenuFromButton:sender
                                 titles:titles
                                 images:titlesImages destructive:destructive handler:^(NSInteger index, NSString * _Nonnull title) {
        
        switch (index) {
            case 0:
                [weakSelf showCard];
                break;

            case 1:
                [weakSelf.delegate archiveCardData:weakSelf.cardModel Child:weakSelf.childModel];
                 break;

            case 2:
                [weakSelf confirmDeleteChild:weakSelf.childModel];
                break;

            case 3:
                [weakSelf.delegate transferChild:weakSelf.childModel cardID:self.cardModel];
                break;

            case 4:
                [weakSelf.delegate sellChild:weakSelf.childModel cardID:self.cardModel];
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
        [weakSelf.delegate DeleteChild:weakSelf.childModel FromCageWithID:weakSelf.CageID];
    }cancelBlock:^{}];
}


//012
-(void)archiveCard {
    NSLog(@"ceLL INDEX row %ld ",self.childIndex);
    
    [self.delegate archiveCardData:self.cardModel Child:self.childModel];
    //[self.delegate archiveChild:self.childModel cellIndexPath:self.indexPath];

   // [self.delegate archiveCardData:self.cardModel cellIndexPath:self.indexPath];
   // [self.delegate cellClickArchive:self.childIndex];
}


- (IBAction)showChildBTN:(id)sender {
}
@end



/*
 //
 //  selectChildCell.m
 //  Pure Pets
 //
 //  Created by Mohammed Ahmed on 26/07/2024.
 //

 #import "selectChildCell.h"



 @interface selectChildCell ()
 @property NSString *showCardTitle;
 @property NSString *deleteCardTitle;
 @property NSString *archiveCardTitle;
 @property NSString *transferTitle;
 @property NSString *sellTitle;
 @property TTGSnackbar *snakBar;
 @end
 @implementation selectChildCell

 - (void)awakeFromNib {
     [super awakeFromNib];
     // Initialization code
     
     self.showCardTitle =  @"عرض البطاقة";
     self.deleteCardTitle =  @"حذف الفرخ";
     self.archiveCardTitle =  @"ارشفة الفرخ";
     self.transferTitle =  @"نقل الفرخ";
     self.sellTitle = @"بيع الفرخ";
     
     
     
     
      
     self.RingID.font = [GM MidFontWithSize:14];
 }

 - (void)setSelected:(BOOL)selected animated:(BOOL)animated {
     [super setSelected:selected animated:animated];

     // Configure the view for the selected state
 }

 - (IBAction)showCardBTN:(id)sender {
     [self showCard];
 }

 -(void)showCard
 {
     if(self.isFound == 0)
     {
         
         typeof(self) __weak weakself = self;
         self.snakBar = [[TTGSnackbar alloc]initWithMessage:[NSString stringWithFormat:@"لم يتم انشاء بطاقة للفرخ %@ ، انشاء الان",self.BirdRingID] duration:2147483647];
         [self.snakBar setActionText:@"نعم"];
         [self.snakBar setSecondActionText:@"لا"];
         [self.snakBar setContentMode:UIViewContentModeCenter];
         [self.snakBar setCornerRadius:10];
         [self.snakBar setLargeContentTitle:@""];
         [self.snakBar setActionBlock:^(TTGSnackbar * _Nonnull snakeBar) {
             [weakself.delegate goToNewCard:weakself.BirdRingID fromVC:@"selectChildViewController" isFound:weakself.isFound ImagesArr:weakself.ImagesArr cardID:weakself.cardID];
             [weakself.snakBar dismiss];
         }];
         
         [self.snakBar setSecondActionBlock:^(TTGSnackbar * _Nonnull snakeBar) {
             [weakself.snakBar dismiss];
         }];
         [self.snakBar setAnimationType:TTGSnackbarAnimationTypeSlideFromTopBackToTop];
         [self.snakBar setIconTintColor:[UIColor whiteColor]];
         [self.snakBar setContainerView:self.superview];
         [self.snakBar show];
     }
     else {
         [self.delegate goToNewCard:self.BirdRingID fromVC:@"selectChildViewController" isFound:self.isFound ImagesArr:self.ImagesArr cardID:self.cardID];
     }
 }

 - (IBAction)delChildBTN:(id)sender {
     [self deleteChild];
 }

 -(void)deleteChild
 {
     typeof(self) __weak weakself = self;
     self.snakBar = [[TTGSnackbar alloc]initWithMessage:[NSString stringWithFormat:@"سيتم نقل الفرخ %@ الي سلة المهملات ، هل انت متأكد ؟",self.BirdRingID] duration:2147483647];
     [self.snakBar setActionText:@"نعم"];
     [self.snakBar setSecondActionText:@"لا"];
     [self.snakBar setContentMode:UIViewContentModeCenter];
     [self.snakBar setCornerRadius:10];BirdRingID
     [self.snakBar setLargeContentTitle:@""];
     [self.snakBar setActionBlock:^(TTGSnackbar * _Nonnull snakeBar) {
         [weakself.delegate DeleteChild:weakself.CageID ChildRingID:weakself.ChildRingID childIndex:weakself.childIndex childID:weakself.ID childModel:weakself.childModel];
         [weakself.snakBar dismiss];
     }];
     
     [self.snakBar setSecondActionBlock:^(TTGSnackbar * _Nonnull snakeBar) {
         [weakself.snakBar dismiss];
     }];
     [self.snakBar setAnimationType:TTGSnackbarAnimationTypeSlideFromTopBackToTop];
     [self.snakBar setIconTintColor:[UIColor whiteColor]];
     [self.snakBar setContainerView:self.superview];
     [self.snakBar show];
 }

 - (IBAction)moreBTN:(id)sender {
     
   
     FTPopOverMenuConfiguration *configuration = [FTPopOverMenuConfiguration defaultConfiguration];
     configuration.menuRowHeight = 32;
     configuration.backgroundColor = [UIColor colorWithHexString:@"#353535"];
     configuration.menuWidth = 100;
     configuration.textColor = [UIColor whiteColor];
     configuration.textFont = [GM MidFontWithSize:12];
     configuration.borderColor = [UIColor darkGrayColor];
     configuration.borderWidth = 0.1;
     configuration.textAlignment = NSTextAlignmentCenter;
     configuration.ignoreImageOriginalColor = YES;
     // set 'ignoreImageOriginalColor' to YES, images color will be same as textColor
     configuration.allowRoundedArrow = YES;
     
     [FTPopOverMenu showForSender:sender withMenuArray:@[self.showCardTitle,self.archiveCardTitle,self.deleteCardTitle,self.transferTitle,self.sellTitle] imageArray:nil configuration:configuration doneBlock:^(NSInteger selectedIndex) {
         
             if(selectedIndex == 0){
                 [self showCard];
             } else if(selectedIndex == 1){
                 [self archiveCard];
             } else if(selectedIndex == 2){
                 [self deleteChild];
             }else if(selectedIndex == 3){
                 [self.delegate cellClickTransfer:self.childIndex];
             }else if(selectedIndex == 4){
                 [self.delegate cellClickSell:self.childIndex childCard:self.cardModel];
             }
         
       
         
     } dismissBlock:^{  NSLog(@"user canceled. do nothing.");  }];
 }
 //012
 -(void)archiveCard {
     NSLog(@"ceLL INDEX row %ld ",self.childIndex);
     
     [self.delegate archiveCardData:self.cardModel Child:self.childModel cellIndexPath:self.indexPath];
     //[self.delegate archiveChild:self.childModel cellIndexPath:self.indexPath];

    // [self.delegate archiveCardData:self.cardModel cellIndexPath:self.indexPath];
    // [self.delegate cellClickArchive:self.childIndex];
 }


 - (IBAction)showChildBTN:(id)sender {
 }
 @end

 */
