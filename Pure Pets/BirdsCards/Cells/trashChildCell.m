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
}
@end

