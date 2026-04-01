//
//  viewDataVC.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 22/07/2024.
//


#import "ImageModel.h"

 #import <SDWebImage/SDWebImage.h>
#import <SDWebImage/UIImageView+WebCache.h>
#import "NewCardForm.h"
#import "TQImageViewer.h"
#import "ImageViewerController.h"
#import "Language.h"
#import "JPVideoPlayerKit.h"
#import "PetImageGalleryView.h"
NS_ASSUME_NONNULL_BEGIN


@interface viewDataVC : XLFormViewController
@property (strong, nonatomic)PetImageGalleryView *imageGallery;
@property (strong, nonatomic) UIButton *returnBTN;
 @property (weak, nonatomic) NSString  *birdId;
 @property (strong, nonatomic) CardModel  *cardModel;
@property (nonatomic, assign) BOOL presentFade;
@property (nonatomic,strong) NSArray<CardModel *>     *CardsdataSource;
@property (nonatomic,strong) CardModel     *FatherCard;
@property (nonatomic,strong) CardModel     *MotherCard;
 @property (nonatomic,strong) NSString  *cardTitle;
@end

NS_ASSUME_NONNULL_END



