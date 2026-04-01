//
//  PPXLPhotoCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 02/12/2025.
//


 
@class HXPhotoView;
@class HXPhotoManager;

#import "XLFormCustomCell.h"
#import "XLFormRowFullWidthTextFieldCell.h"


@interface PPXLPhotoCell : XLFormBaseCell

@property (nonatomic, strong) HXPhotoManager *photoManager;
@property (nonatomic, strong) HXPhotoView *photoView;

@end
