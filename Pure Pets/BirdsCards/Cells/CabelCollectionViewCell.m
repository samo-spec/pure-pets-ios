//
//  CabelCollectionViewCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 05/08/2024.
//

#import "CabelCollectionViewCell.h"

#import "FTPopOverMenu.h"

@interface CabelCollectionViewCell()
{
    NSString *tipString;
    NSInteger gardAded;
}
@end


@implementation CabelCollectionViewCell
- (IBAction)showChildsBTN:(id)sender {
    [self.delegate showChildsForCage:self.CageData];
}

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
    NSLog(@"showParentData awakeFromNib ");
    [self.fatherImageView setUserInteractionEnabled:YES];
    UITapGestureRecognizer *pickImageTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showFatherData)];
        [self.fatherImageView addGestureRecognizer:pickImageTapGesture];
    
    [self.motherImageView setUserInteractionEnabled:YES];
    UITapGestureRecognizer *MotherPanGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showMotherData)];
    [_motherImageView addGestureRecognizer:MotherPanGesture];
    
    _showChildBTN.backgroundColor = [GM appPrimaryColor];
    
    self.FatherRingID.font            = [GM MidFontWithSize:13];
    self.MotherRingID.font            = [GM MidFontWithSize:13];
    self.CageName.font                = [GM boldFontWithSize:15];
    self.ChildsCount.font             = [GM MidFontWithSize:14];
    self.showChildBTN.titleLabel.font = [GM MidFontWithSize:14];
    self.addChildsBTN.titleLabel.font = [GM MidFontWithSize:14];
    self.remainDaysFirstEgg.font = [GM MidFontWithSize:13];
    //self.remainDaysFirstEgg.textColor = [GM appPrimaryColor];
    self.motherMovedLabel.font = [GM MidFontWithSize:14];
    self.fatherMovedLabel.font = [GM MidFontWithSize:14];
    
    self.remainDaysFirstEgg.layer.cornerRadius = 15;
    self.remainDaysFirstEgg.clipsToBounds = YES;
    self.remainDaysFirstEgg.layer.masksToBounds = YES;
    [self.remainDaysFirstEgg.layer setMaskedCorners:kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner];
    UITapGestureRecognizer *singleTapChats = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showEggsDates)];
    singleTapChats.numberOfTapsRequired = 1;
    
    [self.remainDaysFirstEgg addGestureRecognizer:singleTapChats];
    
    [self.editDatesBTN.layer setShadowColor:[UIColor darkGrayColor].CGColor];
    [self.editDatesBTN.layer setShadowOffset:CGSizeMake(1, 1)];
    [self.editDatesBTN.layer setShadowOpacity:0.5];
    [self.editDatesBTN.layer setShadowRadius:2];
    
    UITapGestureRecognizer *singleTapDeletedView = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showDeletedTip)];
    singleTapDeletedView.numberOfTapsRequired = 1;
    [self.deletedView addGestureRecognizer:singleTapDeletedView];
    self.deletedLabel.font = [GM MidFontWithSize:13];
    self.deletedView.layer.cornerRadius = 15;
    self.deletedView.clipsToBounds = YES;
    [self.deletedView.layer setMaskedCorners:kCALayerMaxXMaxYCorner];
    
    UITapGestureRecognizer *singleTapDeletedViewFather = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showDeletedTipFather)];
    singleTapDeletedViewFather.numberOfTapsRequired = 1;
    [self.deletedViewFather addGestureRecognizer:singleTapDeletedViewFather];
    self.deletedLabelFather.font = [GM MidFontWithSize:13];
    self.deletedViewFather.layer.cornerRadius = 15;
    self.deletedViewFather.clipsToBounds = YES;
    [self.deletedViewFather.layer setMaskedCorners:kCALayerMaxXMaxYCorner];
}

-(void)showDeletedTip
{
    
    NSString *DeleteTXT = [NSString stringWithFormat:@"%@\n%@",@"تم حذف هذه البطاقه",self.motherDeleteReason];
    if(self.motherDeleteReason == nil || [self.motherDeleteReason isEqual:nil] || [self.motherDeleteReason isEqualToString:@"(null)"]  || [self.motherDeleteReason isEqualToString:@"(null)"])
        DeleteTXT = [NSString stringWithFormat:@"%@",@"تم حذف هذه البطاقه"];
    
    if(self.tipView)
        [self.tipView dismissWithCompletion:^{ }];
    ZMJPreferences *preferences = [ZMJPreferences new];
    preferences.drawing.backgroundColor =[UIColor whiteColor];
    preferences.drawing.foregroundColor = [GM appPrimaryColor];
    preferences.drawing.textAlignment = NSTextAlignmentCenter;
    preferences.drawing.font = [GM MidFontWithSize:13];
    preferences.drawing.cornerRadius = 15.00;
    preferences.drawing.arrowPosition = ZMJArrowPosition_top;
    preferences.drawing.shadowColor = UIColor.darkGrayColor;
    
    
    preferences.animating.dismissTransform = CGAffineTransformMakeTranslation(100, 0);
    preferences.animating.showInitialTransform =CGAffineTransformMakeTranslation(-100, 0);
    preferences.animating.showInitialAlpha = 0;
    preferences.animating.showDuration = 1.5;
    preferences.animating.dismissDuration = 1.5;
    
    self.tipView = [[ZMJTipView alloc] initWithText:DeleteTXT
                                            preferences:preferences
                                               delegate:nil];
    [self.tipView showAnimated:YES forView:self.deletedView withinSuperview:self.contentView];
    
    NSTimeInterval delayInSeconds = 5.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self.tipView dismissWithCompletion:^{}];
    });
    
    
}

-(void)gardToView:(UIView *)theView colorOne:(UIColor *)colorOne colorTwo:(UIColor *)colorTwo colorThree:(UIColor *)colorThree rds:(float )rds
{
    // Create the gradient
    CAGradientLayer *theViewGradient = [CAGradientLayer layer];
    theViewGradient.colors = [NSArray arrayWithObjects: (id)colorOne.CGColor, (id)colorTwo.CGColor,(id)colorThree.CGColor, nil];
    theViewGradient.frame = theView.bounds;
    theViewGradient.cornerRadius = rds;
    //[theViewGradient set]
    //Add gradient to view
    
    [theView.layer insertSublayer:theViewGradient atIndex:0];
}



- (void)showDeletedTipFather
{
    NSString *DeleteTXT = [NSString stringWithFormat:@"%@\n%@",@"تم حذف هذه البطاقه",self.fatherDeleteReason];
    if(self.fatherDeleteReason == nil || [self.fatherDeleteReason isEqual:nil] || [self.fatherDeleteReason isEqualToString:@"(null)"]  || [self.fatherDeleteReason isEqualToString:@"(null)"])
        DeleteTXT = [NSString stringWithFormat:@"%@",@"تم حذف هذه البطاقه"];
    
    if(self.tipView)
        [self.tipView dismissWithCompletion:^{}];
    ZMJPreferences *preferences = [ZMJPreferences new];
    preferences.drawing.backgroundColor =[UIColor whiteColor];
    preferences.drawing.foregroundColor = [GM appPrimaryColor];
    preferences.drawing.textAlignment = NSTextAlignmentCenter;
    preferences.drawing.font = [GM MidFontWithSize:13];
    preferences.drawing.cornerRadius = 10;
    preferences.drawing.arrowPosition = ZMJArrowPosition_top;
    preferences.drawing.shadowColor = UIColor.darkGrayColor;
    
    preferences.animating.dismissTransform = CGAffineTransformMakeTranslation(100, 0);
    preferences.animating.showInitialTransform =CGAffineTransformMakeTranslation(-100, 0);
    preferences.animating.showInitialAlpha = 0;
    preferences.animating.showDuration = 1.5;
    preferences.animating.dismissDuration = 1.5;
    
    self.tipView = [[ZMJTipView alloc] initWithText:DeleteTXT
                                            preferences:preferences
                                               delegate:nil];
    [self.tipView showAnimated:YES forView:self.deletedViewFather withinSuperview:self.contentView];
    
    NSTimeInterval delayInSeconds = 5.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self.tipView dismissWithCompletion:^{}];
    });
}


- (IBAction)motherDeleteAction:(id)sender {
    
}


- (IBAction)editDateBTN:(id)sender {
 
    [self.delegate showEggDateController:_CageData];
}

-(void)showEggsDates
{
    [self.delegate showEggDateController:_CageData];
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    
   
    
   // [self gardToView:self.deletedView colorOne:[UIColor colorWithRed:255.0/255.0 green:255.0/255.0 blue:255.0/255.0 alpha:1] colorTwo:[UIColor colorWithRed:255.0/255.0 green:255.0/255.0 blue:255.0/255.0 alpha:0.5] colorThree:[UIColor clearColor] rds:5];
    //[self.contentView bringSubviewToFront:_FatherRingID];
    //[self.contentView bringSubviewToFront:_fatherDeleteBTN];
    //self.fatherDeleteBTN.hx_x = self.motherImageView.hx_w  ;
    //self.deletedView.hx_w = self.motherImageView.width;
    
    [[AppManager sharedInstance] setCornerRadius:17.00 withOpacity:0.7 shadowOffset:2 shadowRadius:5 onView:self  color:[GM AppShadowColor]];
    
    _motherMovedView.frame = _motherImageView.frame;
    _motherMovedView.layer.cornerRadius = 15.00;
    _motherMovedView.clipsToBounds = YES;
    
    _fatherMovedView.frame = _fatherImageView.frame;
    _fatherMovedView.layer.cornerRadius = 15.00;
    _fatherMovedView.clipsToBounds = YES;
}


-(void)showFatherData
{
   
    [self.delegate showParentData:self.CageData.FatherRingID];
}

-(void)showMotherData
{
    
    [self.delegate showParentData:self.CageData.MotherRingID];
}
- (IBAction)AddChilds:(id)sender {
    [self.delegate showAddChild:_CageData rowIndex:_rowIndex ChildArr:_ChildsArray cardsArray:_cardsDataSource indexPath:_indexPath];
}


- (IBAction)delBTN:(id)sender {
    
    FTPopOverMenuConfiguration *configuration = [FTPopOverMenuConfiguration defaultConfiguration];
    configuration.menuRowHeight = 30;
    configuration.backgroundColor =[GM appPrimaryColor];
    configuration.menuWidth = 120;
    configuration.textColor = [UIColor whiteColor];
    configuration.textFont = [GM MidFontWithSize:14];
    configuration.borderColor = [UIColor blackColor];
    configuration.borderWidth = 0.1;
    configuration.textAlignment = NSTextAlignmentCenter;
    configuration.ignoreImageOriginalColor = YES;// set 'ignoreImageOriginalColor' to YES, images color will be same as textColor
    configuration.allowRoundedArrow = YES;


//@[[UIImage imageNamed:@"eye"],[UIImage imageNamed:@"giving"],[UIImage imageNamed:@"bribery"]]
[FTPopOverMenu showForSender:sender
               withMenuArray:@[@"تعديل الصندوق", @"حذف الصندوق"]
                  imageArray:nil
               configuration:configuration
                   doneBlock:^(NSInteger selectedIndex) {
                       // // NSLog(@"done block. do something. selectedIndex : %ld", (long)selectedIndex);
  
    [self.delegate deleteEditCageOptions:selectedIndex CageData:self.CageData cellView:self.contentView cellIndexPath:self.indexPath];
                   } dismissBlock:^{
                       
                       // // NSLog(@"user canceled. do nothing.");
                       
//                           FTPopOverMenuConfiguration *configuration = [FTPopOverMenuConfiguration defaultConfiguration];
//                           configuration.allowRoundedArrow = !configuration.allowRoundedArrow;
                       
                   }];
    
}


- (IBAction)deleteInfoBTN:(id)sender {
}
@end
