//
//  archiveCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 18/09/2024.
//

#import "archiveCell.h"

#import "FTPopOverMenu.h"
@implementation archiveCell



- (void)awakeFromNib {
    [super awakeFromNib];
    
    _childRingID.font = [GM MidFontWithSize:15];
    _archiveDate.font = [GM MidFontWithSize:13];
    _archiveCount.font = [GM MidFontWithSize:13];
    
}

- (IBAction)DelBTN:(id)sender {
    
    
    FTPopOverMenuConfiguration *configuration = [FTPopOverMenuConfiguration defaultConfiguration];
    configuration.menuRowHeight = 30;
    configuration.backgroundColor =[GM appPrimaryColor];
    configuration.menuWidth = 120;
    configuration.textColor = [UIColor whiteColor];
    configuration.textFont =[GM MidFontWithSize:14];
    configuration.borderColor = [UIColor blackColor];
    configuration.borderWidth = 0.1;
    configuration.textAlignment = NSTextAlignmentCenter;
    configuration.ignoreImageOriginalColor = YES;// set 'ignoreImageOriginalColor' to YES, images color will be same as textColor
    configuration.allowRoundedArrow = YES;


//@[[UIImage imageNamed:@"eye"],[UIImage imageNamed:@"giving"],[UIImage imageNamed:@"bribery"]]
[FTPopOverMenu showForSender:sender
               withMenuArray:@[@"تعديل اسم الارشيف", @"حذف الارشيف"]
                  imageArray:nil
               configuration:configuration
                   doneBlock:^(NSInteger selectedIndex) {
                       // // NSLog(@"done block. do something. selectedIndex : %ld", (long)selectedIndex);
  
    [self.delegate deleteEditArchiveOptions:selectedIndex ArchiveData:self.archiveData cellView:self.contentView cellIndexPath:self.cellIndexPath];
                   } dismissBlock:^{
                       
                       // // NSLog(@"user canceled. do nothing.");
                       
//                           FTPopOverMenuConfiguration *configuration = [FTPopOverMenuConfiguration defaultConfiguration];
//                           configuration.allowRoundedArrow = !configuration.allowRoundedArrow;
                       
                   }];
    
    
    
}

- (IBAction)delChildBTN:(id)sender {
    [self.delegate RestoreChild:_CageID ChildRingID:_ChildRingIDD childIndexPath:_childIndexPath childID:_ID];
}

@end
