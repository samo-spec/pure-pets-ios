//
//  HXPhotoEditTransition.m
//  HXPhotoPickerExample
//
//  Created by Silence on 2019/1/20.
//  Copyright © 2019年 Silence. All rights reserved.
//

#import "HXPhotoEditTransition.h"
#import "HXPhotoViewController.h"
#import "HXPhotoPreviewViewController.h"
#import "HXPhotoEditViewController.h"
#import "HXVideoEditViewController.h"
#import "HXPhotoPreviewBottomView.h"
#import "HX_PhotoEditViewController.h"
#import "HXCustomCameraViewController.h"

@interface HXPhotoEditTransition ()
@property (assign, nonatomic) HXPhotoEditTransitionType type;
@property (strong, nonatomic) HXPhotoModel *model;
@end

@implementation HXPhotoEditTransition
+ (instancetype)transitionWithType:(HXPhotoEditTransitionType)type model:(nonnull HXPhotoModel *)model {
    return [[self alloc] initWithTransitionType:type model:model];
}

- (instancetype)initWithTransitionType:(HXPhotoEditTransitionType)type model:(nonnull HXPhotoModel *)model  {
    self = [super init];
    if (self) {
        self.type = type;
        self.model = model;
    }
    return self;
}
- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext{
    if (self.type == HXPhotoEditTransitionTypePresent) {
        return 0.25f;
    }
    return 0.45f;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext{
    switch (self.type) {
        case HXPhotoEditTransitionTypePresent:
            [self presentAnimation:transitionContext];
            break;
            
        case HXPhotoEditTransitionTypeDismiss:
            [self dismissAnimation:transitionContext];
            break;
    }
}
- (void)presentAnimation:(id<UIViewControllerContextTransitioning>)transitionContext {
    UIViewController *toVC = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    UIViewController *fromVC = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];

    UIView *containerView = [transitionContext containerView];

    // 1) Get target frame from editor
    CGRect toFrame = CGRectZero;
    if ([toVC isKindOfClass:[HXPhotoEditViewController class]]) {
        toFrame = [(HXPhotoEditViewController *)toVC getImageFrame];
    } else if ([toVC isKindOfClass:[HXVideoEditViewController class]]) {
        toFrame = [(HXVideoEditViewController *)toVC getVideoRect];
    } else if ([toVC isKindOfClass:[HX_PhotoEditViewController class]]) {
        toFrame = [(HX_PhotoEditViewController *)toVC getImageFrame];
    }

    UIView *tempBgView = [[UIView alloc] initWithFrame:containerView.bounds];
    tempBgView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0];

    UIImageView *tempView = [[UIImageView alloc] init];
    tempView.clipsToBounds = YES;
    tempView.contentMode = UIViewContentModeScaleAspectFill;

    UICollectionViewCell *fromCell = nil;

    if ([fromVC isKindOfClass:[UINavigationController class]]) {
        fromVC = ((UINavigationController *)fromVC).topViewController;
    }

    // 2) Build tempView image + start frame
    if ([fromVC isKindOfClass:[HXPhotoViewController class]]) {
        HXPhotoViewCell *cell = [(HXPhotoViewController *)fromVC currentPreviewCell:self.model];
        tempView.image = cell.imageView.image;
        if (cell) {
            tempView.frame = [cell.imageView convertRect:cell.imageView.bounds toView:containerView];
        }
        fromCell = cell;
        [fromVC.navigationController setNavigationBarHidden:YES];
    } else if ([fromVC isKindOfClass:[HXPhotoPreviewViewController class]]) {
        HXPhotoPreviewViewCell *cell = [(HXPhotoPreviewViewController *)fromVC currentPreviewCell:self.model];
        [cell cancelRequest];
        tempView.image = cell.previewContentView.image;
        if (cell) {
            tempView.frame = [cell.previewContentView convertRect:cell.previewContentView.bounds toView:containerView];
        }
        fromCell = cell;
        if ([(HXPhotoPreviewViewController *)fromVC bottomView].alpha != 0) {
            [(HXPhotoPreviewViewController *)fromVC setSubviewAlphaAnimate:YES duration:0.15f];
            [fromVC.navigationController setNavigationBarHidden:YES];
        }
    } else if ([fromVC isKindOfClass:[HXCustomCameraViewController class]]) {
        tempView.image = [(HXCustomCameraViewController *)fromVC jumpImage];
        tempView.frame = [(HXCustomCameraViewController *)fromVC jumpRect];
        if ([toVC isKindOfClass:[HXVideoEditViewController class]]) {
            [(HXCustomCameraViewController *)fromVC hidePlayerView];
        }
        fromCell = [UICollectionViewCell new];
    }

    // 3) Fallback if we don't have a cell or image from the above
    if (!fromCell) {
        tempView.alpha = 0;

        UIImage *fallbackImage = nil;
        if (self.model.photoEdit.editPreviewImage) {
            fallbackImage = self.model.photoEdit.editPreviewImage;
        } else if (self.model.previewPhoto) {
            fallbackImage = self.model.previewPhoto;
        } else if (self.model.thumbPhoto) {
            fallbackImage = self.model.thumbPhoto;
        }

        tempView.image = fallbackImage;

        if (fallbackImage && fallbackImage.size.width > 0.f && fallbackImage.size.height > 0.f) {
            CGSize imgSize = fallbackImage.size;
            CGFloat maxW = containerView.hx_w * 0.9;
            CGFloat maxH = containerView.hx_h * 0.9;
            CGFloat scale = MIN(maxW / imgSize.width, maxH / imgSize.height);
            CGSize drawSize = CGSizeMake(imgSize.width * scale, imgSize.height * scale);
            tempView.frame = CGRectMake((containerView.hx_w - drawSize.width) / 2.0,
                                        (containerView.hx_h - drawSize.height) / 2.0,
                                        drawSize.width,
                                        drawSize.height);
        } else {
            // No valid image → just fade the editor in without geometry-based animation
            tempView.frame = containerView.bounds;
        }
    }

    // Safety: if still no image, avoid NaN by falling back to simple fade transition
    BOOL hasImage = (tempView.image != nil &&
                     tempView.image.size.width > 0.f &&
                     tempView.image.size.height > 0.f);

    fromCell.hidden = YES;
    [tempBgView addSubview:tempView];

    if (fromCell) {
        if ([fromVC isKindOfClass:[HXCustomCameraViewController class]]) {
            [containerView addSubview:tempBgView];
        } else {
            [fromVC.view insertSubview:tempBgView atIndex:1];
        }
        [containerView addSubview:toVC.view];
    } else {
        [containerView addSubview:tempBgView];
        [containerView addSubview:toVC.view];
    }

    toVC.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0];

    // 4) Validate toFrame (avoid NaN / zero size)
    CGRect safeToFrame = toFrame;

    BOOL invalidToFrame =
        CGRectIsEmpty(safeToFrame) ||
        isnan(safeToFrame.origin.x) || isnan(safeToFrame.origin.y) ||
        isnan(safeToFrame.size.width) || isnan(safeToFrame.size.height) ||
        safeToFrame.size.width <= 0.f || safeToFrame.size.height <= 0.f;

    if (invalidToFrame && hasImage) {
        CGSize imgSize = tempView.image.size;
        CGFloat maxW = containerView.hx_w;
        CGFloat maxH = containerView.hx_h;
        CGFloat scale = MIN(maxW / imgSize.width, maxH / imgSize.height);
        CGSize drawSize = CGSizeMake(imgSize.width * scale, imgSize.height * scale);
        safeToFrame = CGRectMake((containerView.hx_w - drawSize.width) / 2.0,
                                 (containerView.hx_h - drawSize.height) / 2.0,
                                 drawSize.width,
                                 drawSize.height);
    } else if (invalidToFrame) {
        // No image / no valid frame → just cover the screen
        safeToFrame = containerView.bounds;
    }

    [UIView animateWithDuration:[self transitionDuration:transitionContext]
                          delay:0.f
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{

        if (hasImage) {
            tempView.frame = safeToFrame;
            tempView.alpha = 1.0;
        } else {
            tempView.alpha = 0.0;
        }

        if ([toVC isKindOfClass:[HXPhotoEditViewController class]]) {
            [(HXPhotoEditViewController *)toVC showBottomView];
        } else if ([toVC isKindOfClass:[HXVideoEditViewController class]]) {
            [(HXVideoEditViewController *)toVC showBottomView];
        } else if ([toVC isKindOfClass:[HX_PhotoEditViewController class]]) {
            [(HX_PhotoEditViewController *)toVC showTopBottomView];
        }

        if ([fromVC isKindOfClass:[HXPhotoViewController class]]) {
            [(HXPhotoViewController *)fromVC bottomView].alpha = 0;
        }

        tempBgView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:1.0];
    }
                     completion:^(BOOL finished) {
        fromCell.hidden = NO;

        if ([toVC isKindOfClass:[HXPhotoEditViewController class]]) {
            [(HXPhotoEditViewController *)toVC completeTransition:tempView.image];
        } else if ([toVC isKindOfClass:[HXVideoEditViewController class]]) {
            HXVideoEditViewController *videoEditVC = (HXVideoEditViewController *)toVC;
            videoEditVC.bgImageView = [[UIImageView alloc] initWithImage:tempView.image];
            videoEditVC.bgImageView.frame = safeToFrame;
            [videoEditVC.view addSubview:videoEditVC.bgImageView];
            [videoEditVC completeTransition];
        } else if ([toVC isKindOfClass:[HX_PhotoEditViewController class]]) {
            [(HX_PhotoEditViewController *)toVC completeTransition:tempView.image];
        }

        [tempBgView removeFromSuperview];
        toVC.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:1.0];

        if ([fromVC isKindOfClass:[HXPhotoViewController class]]) {
            [(HXPhotoViewController *)fromVC bottomView].alpha = 1;
            [fromVC.navigationController setNavigationBarHidden:NO];
        } else if ([fromVC isKindOfClass:[HXCustomCameraViewController class]] &&
                   [toVC isKindOfClass:[HXVideoEditViewController class]]) {
            [(HXCustomCameraViewController *)fromVC showPlayerView];
        }

        [transitionContext completeTransition:YES];
    }];
}

/**
 *  实现dimiss动画
 */
- (void)dismissAnimation:(id<UIViewControllerContextTransitioning>)transitionContext {
    UIViewController *fromVC = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *toVC = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    
    if ([toVC isKindOfClass:[UINavigationController class]]) {
        toVC = [(UINavigationController *)toVC topViewController];
    }
    
    UIView *containerView = [transitionContext containerView];
    
    UIView *tempBgView = [[UIView alloc] initWithFrame:containerView.bounds];
    tempBgView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0];
    
    UIImageView *tempView = [[UIImageView alloc] init];
    tempView.clipsToBounds = YES;
    tempView.contentMode = UIViewContentModeScaleAspectFill;
    
    if ([fromVC isKindOfClass:[HXPhotoEditViewController class]]) {
        tempView.image = [(HXPhotoEditViewController *)fromVC getCurrentImage];
        tempView.frame = [(HXPhotoEditViewController *)fromVC getImageFrame];
        [(HXPhotoEditViewController *)fromVC hideImageView];
    }else if ([fromVC isKindOfClass:[HXVideoEditViewController class]]) {
        [tempView addSubview:[(HXVideoEditViewController *)fromVC videoView]];
        tempView.frame = [(HXVideoEditViewController *)fromVC getVideoRect];
        [(HXVideoEditViewController *)fromVC videoView].frame = tempView.bounds;
        [(HXVideoEditViewController *)fromVC playerLayer].frame = tempView.bounds; 
    }else if ([fromVC isKindOfClass:[HX_PhotoEditViewController class]]) {
        tempView.image = [(HX_PhotoEditViewController *)fromVC getCurrentImage];
        tempView.frame = [(HX_PhotoEditViewController *)fromVC getDismissImageFrame];
        [(HX_PhotoEditViewController *)fromVC hideImageView];
    }
    
    
    CGRect toFrame = CGRectZero;
    UICollectionViewCell *toCell;
    if ([toVC isKindOfClass:[HXPhotoViewController class]]) {
        HXPhotoViewCell *cell = [(HXPhotoViewController *)toVC currentPreviewCell:self.model];
        if (!cell) {
            [(HXPhotoViewController *)toVC scrollToModel:self.model];
            cell = [(HXPhotoViewController *)toVC currentPreviewCell:self.model];
        }
        toFrame = [cell.imageView convertRect:cell.imageView.bounds toView: containerView];
        if (cell) {
            [(HXPhotoViewController *)toVC scrollToPoint:cell rect:toFrame];
        }
        toFrame = [cell.imageView convertRect:cell.imageView.bounds toView: containerView];
        toCell = cell;
        [containerView addSubview:tempView];
        fromVC.view.backgroundColor =  [[UIColor blackColor] colorWithAlphaComponent:1];
#pragma clang diagnostic push
#pragma clang diagnostic ignored"-Wdeprecated-declarations"
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
#pragma clang diagnostic pop
    }else if ([toVC isKindOfClass:[HXPhotoPreviewViewController class]]) {
        HXPhotoPreviewViewCell *cell = [(HXPhotoPreviewViewController *)toVC currentPreviewCell:self.model];
        if (![(HXPhotoEditViewController *)fromVC isCancel]) {
            [cell resetScale:NO];
            [cell refreshImageSize];
        }
        toFrame = [cell.previewContentView convertRect:cell.previewContentView.bounds toView: containerView];
        toCell = cell;
        [tempBgView addSubview:tempView];
        [toVC.view insertSubview:tempBgView atIndex:1];
        if ([(HXPhotoPreviewViewController *)toVC bottomView].alpha == 0) {
            [(HXPhotoPreviewViewController *)toVC setSubviewAlphaAnimate:YES duration:0.15f];
            toVC.navigationController.navigationBar.alpha = 0;
            if (HX_IOS11_Later) {
                [toVC.navigationController.navigationBar.layer removeAllAnimations];
                if (toVC.navigationController.navigationBar.subviews.count > 2) {
                    UIView *navBarView = toVC.navigationController.navigationBar.subviews[2];
                    for (UIView *navBarViewSubView in navBarView.subviews) {
                        [navBarViewSubView.layer removeAllAnimations];
                        for (UIView *subView in navBarViewSubView.subviews) {
                            [subView.layer removeAllAnimations];
                            for (UIView *ssubView in subView.subviews) {
                                [ssubView.layer removeAllAnimations];
                            }
                        }
                    }
                }
            }
        }
        fromVC.view.backgroundColor =  [[UIColor blackColor] colorWithAlphaComponent:0];
#pragma clang diagnostic push
#pragma clang diagnostic ignored"-Wdeprecated-declarations"
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
#pragma clang diagnostic pop
    }else if ([toVC isKindOfClass:[HXCustomCameraViewController class]] &&
              [fromVC isKindOfClass:[HXVideoEditViewController class]]) {
        toFrame = [(HXCustomCameraViewController *)toVC jumpRect];
        [(HXCustomCameraViewController *)toVC hidePlayerView];
        [(HXCustomCameraViewController *)toVC hiddenTopBottomView];
        toCell = [UICollectionViewCell new];
        [containerView addSubview:tempView];
        fromVC.view.backgroundColor =  [[UIColor blackColor] colorWithAlphaComponent:1];
    }
    
    toCell.hidden = YES;
    if ([fromVC isKindOfClass:[HXPhotoEditViewController class]]) {
        if ([(HXPhotoEditViewController *)fromVC isCancel]) {
            CATransition *transition = [CATransition animation];
            transition.duration = 0.2f;
            transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            transition.type = kCATransitionFade;
            [tempView.layer addAnimation:transition forKey:nil];
            tempView.image = [(HXPhotoEditViewController *)fromVC originalImage];
        }
    }else if ([fromVC isKindOfClass:[HXVideoEditViewController class]]) {
        
    }else if ([fromVC isKindOfClass:[HX_PhotoEditViewController class]]) {
        if ([(HX_PhotoEditViewController *)fromVC isCancel]) {
            CATransition *transition = [CATransition animation];
            transition.duration = 0.2f;
            transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            transition.type = kCATransitionFade;
            [tempView.layer addAnimation:transition forKey:nil];
            tempView.image = [(HX_PhotoEditViewController *)fromVC getCurrentImage];
        }
    }
    [UIView animateWithDuration:[self transitionDuration:transitionContext] delay:0.0 usingSpringWithDamping:0.8 initialSpringVelocity:0.1 options:UIViewAnimationOptionCurveEaseOut animations:^{
        if (!toCell || CGRectEqualToRect(toFrame, CGRectZero)) {
            tempView.transform = CGAffineTransformMakeScale(0.3, 0.3);
            tempView.alpha = 0;
        }else {
            tempView.frame = toFrame;
            if ([fromVC isKindOfClass:[HXVideoEditViewController class]]) {
                [(HXVideoEditViewController *)fromVC videoView].frame = tempView.bounds;
                [(HXVideoEditViewController *)fromVC playerLayer].frame = tempView.bounds;
            }
        }
        fromVC.view.alpha = 0;
        tempBgView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0];
        toVC.navigationController.navigationBar.alpha = 1;
    } completion:^(BOOL finished) {
        if ([toCell isKindOfClass:[HXPhotoViewCell class]]) {
            [(HXPhotoViewCell *)toCell bottomViewPrepareAnimation];
            toCell.hidden = NO;
            [(HXPhotoViewCell *)toCell bottomViewStartAnimation];
        }else if ([toCell isKindOfClass:[HXPhotoPreviewViewCell class]]){
            [(HXPhotoPreviewViewCell *)toCell requestHDImage];
        }
        if ([toVC isKindOfClass:[HXCustomCameraViewController class]] &&
            [fromVC isKindOfClass:[HXVideoEditViewController class]]) {
            [(HXCustomCameraViewController *)toVC showPlayerView];
            [(HXCustomCameraViewController *)toVC showTopBottomView];
        }
        toCell.hidden = NO;
        
        [tempView removeFromSuperview];
        [tempBgView removeFromSuperview];
        
        [transitionContext completeTransition:YES];
    }];
}
@end
