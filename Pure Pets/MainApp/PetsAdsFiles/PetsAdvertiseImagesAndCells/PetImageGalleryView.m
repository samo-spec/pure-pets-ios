//
//  PetImageGalleryView 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/05/2025.
//

#import <Vision/Vision.h>
#import "PetImageGalleryView.h"
#import "PPImageLoaderManager.h"
@interface PetImageGalleryView ()<UICollectionViewDelegateFlowLayout,EllipsePageControlDelegate>
@property (nonatomic, strong) ViewerController *photoViewer;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UIButton *containerB;
@property (nonatomic, strong) id currentModel;
@property (nonatomic,strong) EllipsePageControl *myPageControl1;

@property (nonatomic, strong) NSCache<NSNumber *, UIImage *> *imageCache;

@end

@implementation PetImageGalleryView

- (instancetype)initWithFrame:(CGRect)frame imageItems:(NSArray<PetImageItem *> *)items galleryType:(PetImageGalleryType)type itemHeight:(CGFloat)itemHeight parentVC:(UIViewController *)parentVC obj:(id)obj 
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    _imageCache = [[NSCache alloc] init];
    // Core state
    _currentPagr = 0;
    _currentModel = obj;
    _parentViewController = parentVC;
    _galleryType = type;
    _contentMode = UIViewContentModeScaleAspectFit;
    _itemHeight = itemHeight;

    // 🔑 SINGLE SOURCE OF TRUTH
    _imageItems = items ?: @[];

    // Layout helpers
    _imageSizes = [NSMutableDictionary dictionary];

    // UI
    self.backgroundColor = UIColor.clearColor;
    [self setupCollectionView];

    return self;
}


- (void)setupCollectionView {
    
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    //layout.itemSize = CGSizeMake(self.frame.size.width, 300);
    layout.minimumLineSpacing = 0;

    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    _collectionView.pagingEnabled = YES;
    _collectionView.delegate = self;
    _collectionView.dataSource = self;
    _collectionView.showsHorizontalScrollIndicator = NO;
    _collectionView.backgroundColor = AppBackgroundClr;
    _collectionView.layer.cornerRadius = 0;
    _collectionView.clipsToBounds = YES;
    _collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    //_collectionView.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner ;
    [_collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"ImageCell"];
    [self addSubview:_collectionView];
   
    
    // Set up imageGallery constraints
    self.collectionView .translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView .topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.collectionView .leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.collectionView .trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.collectionView .heightAnchor constraintEqualToAnchor:self.heightAnchor]
    ]];
    
    
    [self setupUI];
}

// layoutSubviews no longer manages myPageControl1 constraints


- (NSInteger)pageIndexForItemIndex:(NSInteger)itemIndex {
    
    UIUserInterfaceLayoutDirection dir = [UIView userInterfaceLayoutDirectionForSemanticContentAttribute:_myPageControl1.semanticContentAttribute];
    if (dir == UIUserInterfaceLayoutDirectionRightToLeft) {
        // Reverse: item 0 (first image) becomes last dot, etc.
        return self.imageItems.count - 1 - itemIndex;
    }
    return itemIndex;
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSValue *storedSize = self.imageSizes[indexPath];
        if (storedSize) {
            CGSize size = storedSize.CGSizeValue;
            return size; // dynamic height based on image ratio
        }

        // fallback default (e.g. placeholder height)
    return CGSizeMake(collectionView.bounds.size.width,
                      collectionView.bounds.size.height);
}
 
- (void)setupUI {
    
    self.containerB = [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleFixed configType:PPButtonConfigrationFilled];
    self.containerB.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.containerB];
    
   
    if(PPIOS26())
    {
        UIButtonConfiguration *config = self.containerB.configuration;
        config.background.cornerRadius = 0;
        self.containerB.configuration = config;
    }
    
 
    
    self.myPageControl1 = [[EllipsePageControl alloc] initWithFrame:CGRectMake(0, 10, 90, 30)];
   // self.myPageControl1.backgroundColor = UIColor.redColor;
    self.myPageControl1.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    //self.myPageControl1.translatesAutoresizingMaskIntoConstraints = NO;
    [self.containerB addSubview:_myPageControl1];
    // Center myPageControl1 inside containerB and size to containerB
    /*
     [NSLayoutConstraint activateConstraints:@[
         [self.myPageControl1.centerXAnchor constraintEqualToAnchor:self.containerB.centerXAnchor],
         [self.myPageControl1.centerYAnchor constraintEqualToAnchor:self.containerB.centerYAnchor],
         [self.myPageControl1.widthAnchor constraintEqualToAnchor:self.containerB.widthAnchor],
         [self.myPageControl1.heightAnchor constraintEqualToAnchor:self.containerB.heightAnchor]
     ]];
     */
    NSLayoutConstraint *bottomBtn;
    if(_galleryType == PetImageGalleryTypeCardsViewer)
    {
        bottomBtn =  [self.containerB .bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-10];
    }else if(_galleryType == PetImageGalleryTypePetAd)
    {
        bottomBtn =  [self.containerB .topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.topAnchor constant:5];
        //bottomBtn =  [self.containerB .bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-80];
    }
    else
    {
        bottomBtn =  [self.containerB .bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-80];
    }
    
    [NSLayoutConstraint activateConstraints:@[
        bottomBtn,
        [self.containerB .centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [self.containerB .widthAnchor constraintEqualToConstant:90],
        [self.containerB .heightAnchor constraintEqualToConstant:30]
    ]];
    
    
    self.myPageControl1.numberOfPages = self.imageItems.count;
    self.myPageControl1.delegate=self;
    
    [self layoutSubviews];
    self.myPageControl1.frame = CGRectMake(0, 10, 100, 30);
    
    self.containerB.layer.cornerRadius = 0;
    /*
     LCScaleColorPageStyle,
     LCSquirmPageStyle,
     LCDepthColorPageStyle,
     LCFillColorPageStyle,
     */}

#pragma  mark EllipsePageControlDelegat
#pragma mark - EllipsePageControlDelegate
- (void)ellipsePageControlClick:(EllipsePageControl *)pageControl index:(NSInteger)clickIndex {

    UIUserInterfaceLayoutDirection dir =
    [UIView userInterfaceLayoutDirectionForSemanticContentAttribute:_myPageControl1.semanticContentAttribute];

    NSInteger targetIndex = clickIndex;
    if (dir == UIUserInterfaceLayoutDirectionRightToLeft) {
        // Reverse mapping back: visual index → collection index
        targetIndex = self.imageItems.count - 1 - clickIndex;
    }

    if (targetIndex < 0 || targetIndex >= self.imageItems.count) {
        return;
    }

    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:targetIndex inSection:0];
    [_collectionView scrollToItemAtIndexPath:indexPath
                            atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                    animated:YES];
}

- (void)setImageItems:(NSArray<PetImageItem *> *)imageItems {
    _imageItems = imageItems;
    _myPageControl1.numberOfPages = (int)imageItems.count;
    [self.collectionView reloadData];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.imageItems.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                          cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell =
        [collectionView dequeueReusableCellWithReuseIdentifier:@"ImageCell"
                                                  forIndexPath:indexPath];

    UIImageView *imageView = [cell.contentView viewWithTag:100];

    if (!imageView) {
        imageView = [[UIImageView alloc] init];
        imageView.tag = 100; // FIXED TAG — DO NOT CHANGE LATER
        imageView.translatesAutoresizingMaskIntoConstraints = NO;
     
        imageView.clipsToBounds = YES;

        [cell.contentView addSubview:imageView];

        [NSLayoutConstraint activateConstraints:@[
            [imageView.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor],
            [imageView.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor],
            [imageView.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor],
            [imageView.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor],
        ]];
    }

 
    PetImageItem *item = self.imageItems[indexPath.item];

    // BlurHash placeholder (if available)
    UIImage *placeholder = nil;
    if (item.blurHash.length > 0) {
        placeholder =
        [PPBlurHashBridge imageFrom:item.blurHash syncSize:CGSizeMake(40, 40) punch:1.0];

    }
    
    
    [[PPImageLoaderManager shared]
     fetchImageWithURL:item.url
            completion:^(UIImage * _Nullable image) {

        if (!image) return;
        
        NSNumber *key = @(indexPath.item);
        [self.imageCache setObject:image forKey:key];

        // Apply immediately
        imageView.layer.contents = (__bridge id)image.CGImage;
        imageView.layer.contentsScale = image.scale;
        imageView.layer.masksToBounds = YES;
        imageView.image= image;
        [self pp_detectFaceAndApplyCropForImage:image
                                        onLayer:imageView.layer
                                       inBounds:imageView.bounds];

    }];

    // Visual reset (keep exactly as before)
    imageView.layer.cornerRadius = 0;
    imageView.layer.cornerCurve = kCACornerCurveContinuous;
    imageView.layer.borderWidth = 0;
    imageView.backgroundColor = UIColor.clearColor;
    
    
    return cell;
}


#pragma mark - Vision Face Detection

- (void)pp_detectFaceAndApplyCropForImage:(UIImage *)image
                                onLayer:(CALayer *)layer
                               inBounds:(CGRect)bounds
{
    if (!image || bounds.size.width == 0 || bounds.size.height == 0) {
        return;
    }

    CGImageRef cgImage = image.CGImage;
    if (!cgImage) return;

    VNDetectFaceRectanglesRequest *request =
        [[VNDetectFaceRectanglesRequest alloc] initWithCompletionHandler:
         ^(VNRequest *req, NSError * _Nullable error) {

        dispatch_async(dispatch_get_main_queue(), ^{

            CGFloat imageRatio = image.size.height / image.size.width;
            CGFloat viewRatio  = bounds.size.height / bounds.size.width;

            // Default: TOP-BIAS
            CGRect contentsRect = CGRectMake(0, 0, 1, 1);

            if (imageRatio > viewRatio) {
                CGFloat visibleHeight = viewRatio / imageRatio;

                // 🧠 Clamp visibility (VERY IMPORTANT)
                CGFloat minVisibleHeight = 0.55; // 55% of image minimum

                if (visibleHeight < minVisibleHeight) {
                    visibleHeight = minVisibleHeight;
                }
                contentsRect = CGRectMake(0, 0, 1, visibleHeight);
            }

            // Try face-aware adjustment
            VNFaceObservation *face = req.results.firstObject;
            if (face) {
                // Vision coords are normalized & flipped
                CGFloat faceCenterY = 1.0 - CGRectGetMidY(face.boundingBox);

                CGFloat visibleHeight = contentsRect.size.height;
                CGFloat originY = faceCenterY - (visibleHeight * 0.5);

                // Clamp to valid range
                originY = MAX(0.0, MIN(originY, 1.0 - visibleHeight));

                contentsRect = CGRectMake(0, originY, 1.0, visibleHeight);
            }

            layer.contentsGravity = kCAGravityResizeAspectFill;
            layer.contentsRect = contentsRect;
        });
    }];

    VNImageRequestHandler *handler =
        [[VNImageRequestHandler alloc] initWithCGImage:cgImage
                                                options:@{}];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [handler performRequests:@[request] error:nil];
    });
}

- (void)collectionView:(UICollectionView *)collectionView
       willDisplayCell:(UICollectionViewCell *)cell
    forItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger page = [self pageIndexForItemIndex:indexPath.item];
    _myPageControl1.currentPage = page;
}



-(void)viewerControllerDidDismiss:(ViewerController *)viewer
{
    
}


-(void)viewerController:(ViewerController *)viewer didLongPressAtIndex:(NSInteger)index attribute:(id)attribute image:(UIImage *)image
{
    _currentPagr = index;
    if([_currentModel isKindOfClass:PetAccessory.class])
    {
        [PetAccessory sharePetAccessory:(PetAccessory *)_currentModel fromViewController:AppMgr.topViewController];
    }
    
}


-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    
    // Create viewer attributes from PetImageItem
    NSMutableArray<ViewerAttribute *> *attributes = [NSMutableArray array];

    for (NSInteger i = 0; i < self.imageItems.count; i++) {

        PetImageItem *item = self.imageItems[i];
        if (item.url.length == 0) continue;

        NSURL *url = [NSURL URLWithString:item.url];
        if (!url) continue;

        ViewerAttribute *attribute =
        [ViewerAttribute attributeWithImageURL:url sourceView:nil];

        // BlurHash placeholder (if available)
        if (item.blurHash.length > 0) {
            attribute.placeholderImage =
            [PPBlurHashBridge imageFrom:item.blurHash syncSize:CGSizeMake(40, 40) punch:1.0];
        }

        attribute.title =
        [NSString stringWithFormat:@"Image %ld", (long)(i + 1)];

        [attributes addObject:attribute];
    }
    
    
    // Create viewer
    self.photoViewer = [[ViewerController alloc] initWithAttributes:attributes];
    self.photoViewer.delegate = self;
    self.currentAd = (PetAd *)self.currentModel;
    // Configure
    self.photoViewer.loadingStyle = ViewerLoadingStyleSpin;
    self.photoViewer.pageLabelStyle = ViewerPageLabelStyleDot;
    self.photoViewer.bouncesAnimated = YES;
        
    // Customize
    [self.photoViewer setCloseButtonImage:[UIImage systemImageNamed:@"multiply"]
                                     forState:UIControlStateNormal];
    [self.photoViewer setShareButtonImage:[UIImage systemImageNamed:@"square.and.arrow.up"]
                                     forState:UIControlStateNormal];
        
    // Preload for smooth experience
    [self.photoViewer preloadImages];
        
    // Present
    [self.photoViewer presentFromViewController:AppMgr.topViewController
                                       currentIndex:indexPath.item
                              presentationStyle:ViewerPresentationStyleOverFullScreen
                                 animationStyle:ViewerAnimationStyleFade
                                         completion:nil];
    
   
   //  [PPPhotoBrowser showBrowserFrom:AppMgr.topViewController
       //            imageURLStrings:self.imageURLs
         //               startIndex:indexPath.item];
 
 
     
}



#pragma mark - TQImageViewerDelegate

-(void)imageViewerDismissed
{
    [self.parentViewController.navigationController.navigationBar setHidden:NO];
}

/*
- (void)imageViewer:(TQImageViewer *)imageViewer didLongPress:(UILongPressGestureRecognizer *)longPress attribute:(TQImageViewerAttribute *)attribute image:(UIImage *)image
{
    if(image)
    {
        UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[image] applicationActivities:nil];
        if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            activityViewController.popoverPresentationController.sourceView = longPress.view;
            CGPoint point = [longPress locationInView:longPress.view];
            activityViewController.popoverPresentationController.sourceRect = CGRectMake(point.x, point.y, 1, 1);
        }
        [_parentViewController presentViewController:activityViewController animated:YES completion:nil];
    }
    
}
*/




@end


