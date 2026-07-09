//
//  PetImageGalleryView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/05/2025.
//


#import <UIKit/UIKit.h>
 
#import "EllipsePageControl.h"
#import "PetImageItem.h"
@class PetImageItem;

typedef NS_ENUM(NSUInteger, PetImageGalleryType) {
    PetImageGalleryTypePetAd,
    PetImageGalleryTypeAccessory,
    PetImageGalleryTypeCardsViewer,
    PetImageGalleryTypeFullDetailsCell
};

@interface PetImageGalleryView : UIView <UICollectionViewDelegate, UICollectionViewDataSource>

@property (nonatomic, assign) PetImageGalleryType galleryType;
@property (nonatomic, strong) NSArray<PetImageItem *> *imageItems;
@property (nonatomic, weak) UIViewController *parentViewController;
@property (assign,  nonatomic) UIViewContentMode contentMode;
@property (assign,  nonatomic) CGFloat itemHeight;
@property (assign,  nonatomic) NSInteger currentPagr;
@property (assign,  nonatomic) PetAd *currentAd;
@property (nonatomic, strong) NSMutableDictionary<NSIndexPath *, NSValue *> *imageSizes;

/// Suppress the built-in page control pill (for custom thumbnail rails).
@property (nonatomic, assign) BOOL hidesPageControl;
/// Fires whenever the gallery settles on a new page (swipe or programmatic).
@property (nonatomic, copy) void (^onPageChanged)(NSInteger page);

- (instancetype)initWithFrame:(CGRect)frame
                   imageItems:(NSArray<PetImageItem *> *)items
                  galleryType:(PetImageGalleryType)type
                   itemHeight:(CGFloat)itemHeight
                     parentVC:(UIViewController *)parentVC
                          obj:(id)obj;
- (void)scrollToPage:(NSInteger)page animated:(BOOL)animated;

@end
