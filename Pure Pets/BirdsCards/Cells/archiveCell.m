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
    NSArray *titles = @[kLang(@"editarchive"), kLang(@"deletearchive"), kLang(@"craeteQrCode")];
    NSArray *icons = @[
        [UIImage systemImageNamed:@"pencil"] ?: [UIImage new],
        [UIImage systemImageNamed:@"trash"] ?: [UIImage new],
        [UIImage systemImageNamed:@"barcode.viewfinder"] ?: [UIImage new]
    ];
    NSIndexSet *destructive = [NSIndexSet indexSetWithIndex:1];

    UIButton *btn = [sender isKindOfClass:[UIButton class]] ? (UIButton *)sender : self.delBTN;
    [PPMenuHelper presentMenuFromButton:btn
                                 titles:titles
                                 images:icons
                           destructive:destructive
                               handler:^(NSInteger index, NSString *title) {
        [self.delegate deleteEditArchiveOptions:index ArchiveData:self.archiveData cellView:self.contentView cellIndexPath:self.cellIndexPath];
    }];
}

- (IBAction)delChildBTN:(id)sender {
    [self.delegate RestoreChild:_CageID ChildRingID:_ChildRingIDD childIndexPath:_childIndexPath childID:_ID];
}

@end
