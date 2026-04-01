//
//  trashChildCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 18/09/2024.
//

#import "trashChildCell.h"

@implementation trashChildCell


- (void)awakeFromNib {
    [super awakeFromNib];
    
    [_returnButton.titleLabel setFont:[GM MidFontWithSize:12]];
    [_showCardDetaildsBTN.titleLabel setFont:[GM MidFontWithSize:12]];
    _childRingID.font = [GM MidFontWithSize:14];
    _subKindLabel.font = [GM MidFontWithSize:13];
    
    _mainImaheView.layer.cornerRadius =25;
    _mainImaheView.clipsToBounds = YES;
    
    [_optionsButton.titleLabel setFont:[GM MidFontWithSize:13]];
    [_optionsButton setTitleColor:[GM appPrimaryColor] forState:UIControlStateNormal];
    _optionsButton.layer.cornerRadius = _optionsButton.hx_h/2;
    _optionsButton.clipsToBounds =YES;
    [_optionsButton.titleLabel setTextColor:[GM appPrimaryColor]];
   
    

    
}
- (IBAction)showCardDet:(id)sender {
    [self.delegate DetaildsFromTrash:_cardData];
}

- (IBAction)delChildBTN:(id)sender {
  
}

- (IBAction)optionsBTN:(id)sender {
    
    [self.delegate RestoreChild:self.CageID ChildRingID:self.ChildRingIDD childIndexPath:self.childIndexPath childID:self.ID cardData:self.cardData cameFrom:self.cameFrom];
    return;
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
               withMenuArray:@[ @"عرض التفاصيل",
                                @"إستعادة البطاقة"
                              ]
                  imageArray:nil
               configuration:configuration
                   doneBlock:^(NSInteger selectedIndex) {
                       // // NSLog(@"done block. do something. selectedIndex : %ld", (long)selectedIndex);
  
    if(selectedIndex == 0)
    {
        [self.delegate DetaildsFromTrash:self.cardData];
    }
    
    if(selectedIndex == 1)
    {
    }
    
                   } dismissBlock:^{
                       
                       // // NSLog(@"user canceled. do nothing.");
                       
//                           FTPopOverMenuConfiguration *configuration = [FTPopOverMenuConfiguration defaultConfiguration];
//                           configuration.allowRoundedArrow = !configuration.allowRoundedArrow;
                       
                   }];
    
}
@end

