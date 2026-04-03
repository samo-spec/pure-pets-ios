//
//  XLFormCustomCell.m
//  XLForm ( https://github.com/xmartlabs/XLForm )
//
//  Copyright (c) 2015 Xmartlabs ( http://xmartlabs.com )
//
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "XLFormCustomCell.h"
#import "UIView+XLFormAdditions.h"
#import "Language.h"
#pragma mark - Select picture Cell


 /// Form Cell, height of image
 #define Jh_OnePhotoViewWidth (Jh_ScreenWidth-Jh_ImageLeftMargin-Jh_ImageRightMargin-(Jh_ImageOneLineCount-1)*Jh_ImageMargin)
 /// Form Cell, height of image
 #define Jh_ImageHeight (Jh_OnePhotoViewWidth)/Jh_ImageOneLineCount

 /// Form Cell, select picture, left spacing, default 15
 UIKIT_EXTERN NSUInteger const Jh_ImageLeftMargin;
 /// Form Cell, select picture, right spacing, default 15
 UIKIT_EXTERN NSUInteger const Jh_ImageRightMargin;
 /// Form Cell, select picture, picture spacing, default 3
 UIKIT_EXTERN NSUInteger const Jh_ImageMargin;
 /// Form Cell, select pictures, several pictures in one line, default 4 pictures
 UIKIT_EXTERN NSUInteger const Jh_ImageOneLineCount;
 /// Form Cell, select picture, photo top and bottom spacing, default 10
UIKIT_EXTERN NSUInteger const Jh_OnePhotoViewTopMargin;

/// Form Cell, select the number of image attachments, the default is 8
 UIKIT_EXTERN NSUInteger const Jh_GlobalMaxImages;
 /// Form Cell, select picture and add icon
 UIKIT_EXTERN NSString *const Jh_AddIcon;

 ///// Form Cell, select image, failed to load placeholder image, not used
 //UIKIT_EXTERN NSString *const Jh_PlaceholderImage;
 ///// Form Cell, select picture, delete icon, not used
 //UIKIT_EXTERN NSString *const Jh_DeleteIcon;


@interface XLFormCustomCell()

#if kHasHXPhotoPicker
<HXPhotoViewDelegate>
{
    NSMutableArray * _dynamicCustomConstraints;
}
@property (strong, nonatomic) HXPhotoView *onePhotoView;
@property (strong, nonatomic) HXPhotoManager *oneManager;
#endif

@property (nonatomic, strong) NSMutableArray *mediaOutputArray;
/** Selected picture array */
 @property (nonatomic, strong) NSArray *selectImgArr;
 /** Picture background View */
 @property (nonatomic, strong) UIView *bottomImageBgView;

@property (nonatomic, assign) BOOL  isInit;

@property (assign, nonatomic) BOOL needDeleteItem;

@end


@implementation XLFormCustomCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
#if kHasHXPhotoPicker
        _dynamicCustomConstraints = [NSMutableArray array];
#endif
    }
    return self;
}

- (void)Jh_initUI {
    self.isInit = YES;
}

- (void)configure
{
    [super configure];
    //override
    self.isInit = YES;
   
    #if kHasHXPhotoPicker
   
    self.oneManager.type =  HXPhotoManagerSelectedTypePhotoAndVideo;
    
    if ( self.rowDescriptor.Jh_noShowAddImgBtn) {
      
    }
    if ( self.rowDescriptor.Jh_selectImageType == JhSelectImageTypeImage && self.isInit) {
        if ( self.rowDescriptor.Jh_imageArr.count) {
            NSLog(@"self.rowDescriptor.Jh_imageArr.count %ld",self.rowDescriptor.Jh_imageArr.count);
            [self.oneManager clearSelectedList];
            NSMutableArray *mUrlArr = @[].mutableCopy;
            for (id img in  self.rowDescriptor.Jh_imageArr) {
                HXPhotoModel *model ;
                if([img isKindOfClass:[UIImage class]]){
                    model = [HXPhotoModel photoModelWithImage:img];
                }
                if([img isKindOfClass:[NSString class]]){
                    model = [HXPhotoModel photoModelWithImageURL:[NSURL URLWithString:img]];
                }
                if([img isKindOfClass:[NSURL class]]){
                    model = [HXPhotoModel photoModelWithImageURL:img];
                }
                if ([img isKindOfClass:[HXPhotoModel class]]) {
                    model =img;
                }
                if(model){
                    [mUrlArr addObject:model];
                }
            }
            [self.onePhotoView refreshView];
            //self.isInit = NO;
        }
    }
    if (self.rowDescriptor.Jh_selectImageType != JhSelectImageTypeImage && self.isInit) {
        if(self.rowDescriptor.Jh_mixImageArr.count){
            NSLog(@"\n Myimage: (void)configure self.rowDescriptor.Jh_mixImageArr.count %luld",(unsigned long)self.rowDescriptor.Jh_mixImageArr.count);
            [self.oneManager clearSelectedList];
            [self.onePhotoView refreshView];
           
        }
    }
    
    if (self.rowDescriptor.Jh_isClearImage) {
        [self Jh_clearImage];
    }
    
   
  
    
#endif
    
#if kHasHXPhotoPicker
    [self.contentView addSubview:self.onePhotoView];
#endif
    [self.contentView setBackgroundColor:GM.AppForegroundColor];
    [self setBackgroundColor:GM.AppForegroundColor];
    

    if (self.rowDescriptor.Jh_imageSelectBlock) {
      // self.rowDescriptor.Jh_imageSelectBlock(self.rowDescriptor.Jh_imageAllList);
    }
    self.isInit = YES;

    self.tintColor = [UIColor blackColor];
}

#pragma mark - Constraints

-(void)updateConstraints
{
#if kHasHXPhotoPicker
    if (_dynamicCustomConstraints){
        [self.contentView removeConstraints:_dynamicCustomConstraints];
        [_dynamicCustomConstraints removeAllObjects];
    }

    [self.onePhotoView refreshView];
#endif
    [super updateConstraints];
}


#if kHasHXPhotoPicker
- (HXPhotoManager *)oneManager {
    if (!_oneManager) {
        _oneManager = [[HXPhotoManager alloc] initWithType:HXPhotoManagerSelectedTypePhotoAndVideo];
        _oneManager.configuration.photoMaxNum = 10;
        _oneManager.configuration.videoMaxNum = 1;
        _oneManager.configuration.selectTogether = YES;
        _oneManager.configuration.maxNum = 11;
        _oneManager.configuration.cameraCellShowPreview = NO;
        _oneManager.configuration.openCamera =NO;
        _oneManager.configuration.videoCanEdit =YES;
        _oneManager.configuration.photoCanEdit =YES;
        _oneManager.configuration.saveSystemAblum = YES;
        //[HXPhotoCommon photoCommon].requestNetworkAfter= YES;
        _oneManager.configuration.reverseDate = YES;
       
    
       
    }
    return _oneManager;
}
- (HXPhotoView *)onePhotoView {
    if (!_onePhotoView) {
   
        _onePhotoView = [[HXPhotoView alloc] initWithFrame:CGRectMake(Jh_ImageLeftMargin, Jh_OnePhotoViewTopMargin, Jh_OnePhotoViewWidth, Jh_ImageHeight)];
        _onePhotoView.manager = self.oneManager;
        _onePhotoView.outerCamera = YES;
        _onePhotoView.lineCount = Jh_ImageOneLineCount;
        _onePhotoView.spacing = Jh_ImageMargin;
        _onePhotoView.delegate = self;
      
   
        
       // _onePhotoView.deleteImageName = Jh_DeleteIcon;
       // _onePhotoView.ima = Jh_DeleteIcon;
    }
    return _onePhotoView;
}

-(void)photoView:(HXPhotoView *)photoView changeComplete:(NSArray<HXPhotoModel *> *)allList photos:(NSArray<HXPhotoModel *> *)photos videos:(NSArray<HXPhotoModel *> *)videos original:(BOOL)isOriginal
{
   
    
   /*
    [allList hx_requestImageWithOriginal:YES completion:^(NSArray<UIImage *> * _Nullable imageArray, NSArray<HXPhotoModel *> * _Nullable errorArray) {
        self.rowDescriptor.value = imageArray;
    }];
    
    
    
    
    [allList hx_requestImageWithOriginal:YES completion:^(NSArray<UIImage *> * _Nullable imageArray ,NSArray<HXPhotoModel *> * _Nullable modelsArray, NSArray<HXPhotoModel *> * _Nullable errorArray) {
       // for (UIImage *im in imageArray) {
       //     NSLog(@"FRAMMMMMMME UPDATED");
       // }
        self.rowDescriptor.value = modelsArray;
    }];
     */
    
   
    
}

- (void)photoView:(HXPhotoView *)photoView updateFrame:(CGRect)frame {
    NSLog(@"FRAMMMMMMME UPDATED");
    //self.onePhotoView.frame = frame;
    __weak typeof(self) weakSelf = self;
   // self.rowDescriptor.value = image;
    self.rowDescriptor.height = CGRectGetHeight(self.onePhotoView.frame)+Jh_OnePhotoViewTopMargin*2;
    
    [UIView performWithoutAnimation:^{
       
    }];
    [UIView animateWithDuration:0.5 animations:^{
        [weakSelf.formViewController.tableView beginUpdates];
        [weakSelf.formViewController.tableView endUpdates];
    }];
    [self needsUpdateConstraints];

    
    [self.formViewController updateFormRow:self.rowDescriptor];
}


#endif





- (void)update
{
    [super update];
    [self needsUpdateConstraints];
    
    
    if ( self.rowDescriptor.Jh_imageArr.count && self.rowDescriptor.isStart) {
        self.rowDescriptor.isStart = NO;
#if kHasHXPhotoPicker
        [self.oneManager clearSelectedList];
#endif
        NSMutableArray *mUrlArr = @[].mutableCopy;
        /*for (FileModel *file in  self.rowDescriptor.Jh_imageArr) {
            HXPhotoModel *mdl ;
            if(file.FileType == 0)
            {
                mdl = [HXPhotoModel photoModelWithImage:file.imageFile];
                mdl.tempImage  = file.imageFile;
                mdl.previewPhoto  = file.imageFile;
                mdl.thumbPhoto  = file.imageFile;
                [mUrlArr addObject:mdl];
            }
            
            if(file.FileType == 1)
            {
                mdl = [HXPhotoModel photoModelWithVideoURL:[NSURL URLWithString:file.FileUrl]];
                [mUrlArr addObject:mdl];
            }
  
        }*/
        
       
        self.rowDescriptor.value = self.rowDescriptor.Jh_imageArr;
#if kHasHXPhotoPicker
        [self.onePhotoView refreshView];
#endif
       //[self.formViewController updateFormRow:self.rowDescriptor];
    }
     
    self.textLabel.hidden = YES;
    // override
    self.textLabel.text = @"";
    
    [self needsUpdateConstraints];
    
    NSLog(@"\n Myimage: FROM UPDATE %@",self.rowDescriptor.Jh_imageArr);

}

#pragma mark -- 清空所有图片、视频数据
- (void)Jh_clearImage {
#if kHasHXPhotoPicker
    [self.oneManager clearSelectedList];
#endif
    self.rowDescriptor.Jh_imageArr = @[];
    self.rowDescriptor.Jh_selectImageArr = @[];
    self.rowDescriptor.Jh_selectVideoArr = @[];
#if kHasHXPhotoPicker
    self.rowDescriptor.Jh_imageAllList = @[];
    self.rowDescriptor.Jh_mixImageArr = @[];
    [self.onePhotoView refreshView];
#endif
    [self update];
}

-(void)formDescriptorCellDidSelectedWithFormController:(XLFormViewController *)controller
{
    // custom code here
    // i.e new behaviour when cell has been selected
    self.textLabel.text =  @"";
    //self.rowDescriptor.value = self.textLabel.text;
    [self.formViewController.tableView selectRowAtIndexPath:nil animated:YES scrollPosition:UITableViewScrollPositionNone];
    
   
    //[self.contentView layoutConstraintSameHeightOf:self.onePhotoView];
    //[controller updateFormRow:self.rowDescriptor];
    //
}


 +(CGFloat)formDescriptorCellHeightForRowDescriptor:(XLFormRowDescriptor *)rowDescriptor
 {
     return Jh_ImageHeight+Jh_OnePhotoViewTopMargin*2;
 }



- (void)layoutSubviews {
    [super layoutSubviews];
   // self.contentView.frame = CGRectMake(0, 0,  self.contentView.width, CGRectGetHeight(self.onePhotoView.frame)+Jh_OnePhotoViewTopMargin*2);
   
    //[self needsUpdateConstraints];
    //[self.formViewController updateFormRow:self.rowDescriptor];
}



#if kHasHXPhotoPicker
- (void)photoView:(HXPhotoView *)photoView currentDeleteModel:(HXPhotoModel *)model currentIndex:(NSInteger)index {
    NSSLog(@"%@ --> index - %ld",model,index);
}
- (BOOL)photoView:(HXPhotoView *)photoView collectionViewShouldSelectItemAtIndexPath:(NSIndexPath *)indexPath model:(HXPhotoModel *)model {
    return YES;
}



- (BOOL)photoViewShouldDeleteCurrentMoveItem:(HXPhotoView *)photoView gestureRecognizer:(UILongPressGestureRecognizer *)longPgr indexPath:(NSIndexPath *)indexPath {
    return self.needDeleteItem;
}
- (void)photoView:(HXPhotoView *)photoView gestureRecognizerBegan:(UILongPressGestureRecognizer *)longPgr indexPath:(NSIndexPath *)indexPath {
    [UIView animateWithDuration:0.25 animations:^{
        //self.bottomView.alpha = 0.5;
    }];
    NSSLog(@"Long press gesture to start - %ld",indexPath.item);
}
- (void)photoView:(HXPhotoView *)photoView gestureRecognizerChange:(UILongPressGestureRecognizer *)longPgr indexPath:(NSIndexPath *)indexPath {
    CGPoint point = [longPgr locationInView:self.contentView];
    /* if (point.y >= self.bottomView.hx_y) {
     [UIView animateWithDuration:0.25 animations:^{
     //self.bottomView.alpha = 1;
     }];
     }else {
     [UIView animateWithDuration:0.25 animations:^{
     //self.bottomView.alpha = 0.5;
     }];
     } */
    NSSLog(@"Long press gesture changed %@ - %ld",NSStringFromCGPoint(point), indexPath.item);
}
- (void)photoView:(HXPhotoView *)photoView gestureRecognizerEnded:(UILongPressGestureRecognizer *)longPgr indexPath:(NSIndexPath *)indexPath {
    
}
#endif

@end
