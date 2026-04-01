//
//  PPXLPhotoCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 02/12/2025.
//


#import "PPXLPhotoCell.h"

@implementation PPXLPhotoCell

+ (void)load {
    [[XLFormViewController cellClassesForRowDescriptorTypes] setObject:self forKey:@"PPXLPhotoRow"];
}

#pragma mark - Setup

- (void)configure {
    [super configure];

    self.selectionStyle = UITableViewCellSelectionStyleNone;

    // Manager
    self.photoManager = [[HXPhotoManager alloc] initWithType:HXPhotoManagerSelectedTypePhoto];
    self.photoManager.configuration.maxNum = 10;
     self.photoManager.configuration.hideOriginalBtn = YES;
    self.photoManager.configuration.allowPreviewDirectLoadOriginalImage = YES;

    // View
    self.photoView = [HXPhotoView photoManager:self.photoManager];
    self.photoView.lineCount = 4;
    self.photoView.spacing = 8;
    self.photoView.outerCamera = YES;
    self.photoView.delegate = (id)self;

    [self.contentView addSubview:self.photoView];

    self.photoView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [self.photoView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
        [self.photoView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.photoView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [self.photoView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12],
    ]];
}

#pragma mark - XLForm Sync

- (void)update {
    [super update];

    // Write selected images back to XLForm value
    // The value of the row becomes NSArray<UIImage *>
    self.rowDescriptor.value = self.photoManager.afterSelectedArray;
}

+ (CGFloat)formDescriptorCellHeightForRowDescriptor:(XLFormRowDescriptor *)row {
    // Dynamic height from HXPhotoView
    return 12 + 200 + 12;
}

#pragma mark - HXPhotoView Delegate

- (void)photoView:(HXPhotoView *)photoView updateFrame:(CGRect)frame {
    // Force XLForm to re-layout cell
    [self.formViewController reloadFormRow:self.rowDescriptor];
}

- (void)photoListViewControllerDidDone:(NSArray<HXPhotoModel *> *)allList
                             photoList:(NSArray<HXPhotoModel *> *)photoList
                             videoList:(NSArray<HXPhotoModel *> *)videoList
                            isOriginal:(BOOL)isOriginal {
    // Sync to XLForm
    self.rowDescriptor.value = photoList;
    [self.formViewController reloadFormRow:self.rowDescriptor];
}

@end
