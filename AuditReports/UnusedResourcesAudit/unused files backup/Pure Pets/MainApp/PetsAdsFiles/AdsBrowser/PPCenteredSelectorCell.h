//
//  PPCenteredSelectorCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 08/12/2025.
//


//  PPCenteredSelectorCell.h

#import <UIKit/UIKit.h>

@interface PPCenteredSelectorCell : UICollectionViewCell

@property (nonatomic, strong) UIButton *button;
- (void)applyTitle:(NSString *)title selected:(BOOL)selected;

@end