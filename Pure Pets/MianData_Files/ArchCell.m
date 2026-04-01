//
//  ArchCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 18/09/2024.
//

#import "ArchCell.h"


@implementation ArchCell



- (void)awakeFromNib {
    [super awakeFromNib];
    
    _childRingID.font  = [GM boldFontWithSize:17];
    _archiveDate.font  = [GM MidFontWithSize:15];
    _archiveCount.font = [GM boldFontWithSize:15];
    _archiveCount.layer.cornerRadius = 16;
    _archiveCount.clipsToBounds = YES;
}

- (IBAction)DelBTN:(id)sender {
    
    NSArray *titles = @[kLang(@"editarchive") ,kLang(@"deletearchive"),kLang(@"craeteQrCode")];
    NSArray *icons = @[[UIImage systemImageNamed:@"pencil"] ?: [UIImage new],
                       [UIImage systemImageNamed:@"square.and.arrow.up"] ?: [UIImage new],
                       [UIImage systemImageNamed:@"trash"] ?: [UIImage new]];
    NSIndexSet *destructive = [NSIndexSet indexSetWithIndex:2];

    [PPMenuHelper presentMenuFromButton:self.delBTN
                                        titles:titles
                                        images:icons
                                  destructive:destructive
                                      handler:^(NSInteger index, NSString *title) {
        
        [self.delegate deleteEditArchiveOptions:index ArchiveData:self.archiveData cellView:self.contentView cellIndexPath:self.cellIndexPath];
        /*
        switch (index) {
            case 0: [self editAction]c; break;
            case 1: [self shareAction]; break;
            case 2: [self deleteAction]; break;
        } */
    }];
     
    
    
}




-(void)setIsEmpty:(BOOL)isEmpty
{
    if(isEmpty)
    {
        _archiveCount.backgroundColor = [AppBackgroundClrLigter colorWithAlphaComponent:1.0];
        _archiveCount.textColor = [AppSecondaryTextClr colorWithAlphaComponent:1.0];
    }
    else{
        _archiveCount.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.03];
        _archiveCount.textColor = [AppPrimaryClr colorWithAlphaComponent:1.0];
    }
}

@end
