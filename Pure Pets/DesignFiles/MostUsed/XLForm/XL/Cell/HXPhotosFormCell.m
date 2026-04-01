//
//  HXPhotosFormCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 13/08/2025.
//

#import "HXPhotosFormCell.h"
#import <Photos/Photos.h>

//NSString * const XLFormRowDescriptorTypeHXPhotos = @"XLFormRowDescriptorTypeHXPhotos";

@implementation HXPhotosValue
@end

@interface HXPhotosFormCell () <HXPhotoViewDelegate>
@property (nonatomic, strong) HXPhotoManager *manager;
@property (nonatomic, strong) HXPhotoView *photoView;
@property (nonatomic, strong) NSLayoutConstraint *heightConstraint;
@end

@implementation HXPhotosFormCell

+ (void)load {
    // Register our custom cell for this row type
    [XLFormViewController.cellClassesForRowDescriptorTypes setObject:HXPhotosFormCell.class
                                                              forKey:XLFormRowDescriptorTypeHXPhotos];
}

+ (CGFloat)formDescriptorCellHeightForRowDescriptor:(XLFormRowDescriptor *)rowDescriptor {
    // Height now comes from the wrapper stored in row.value
    HXPhotosValue *val = (HXPhotosValue *)rowDescriptor.value;
    return (val && val.height > 0) ? val.height : 180.f;
}

- (void)configure {
    [super configure];
    self.selectionStyle = UITableViewCellSelectionStyleNone;

    // Build/attach our wrapper in row.value (so the controller can read it later)
    HXPhotosValue *val = (HXPhotosValue *)self.rowDescriptor.value;
    if (![val isKindOfClass:HXPhotosValue.class] || !val) {
        val = [HXPhotosValue new];
        self.rowDescriptor.value = val;
    }

    // HXPhotoManager: photos only, up to 6
    self.manager = [[HXPhotoManager alloc] initWithType:HXPhotoManagerSelectedTypePhoto];
    self.manager.configuration.photoMaxNum = 6;
    self.manager.configuration.videoMaxNum = 0;
    self.manager.configuration.maxNum      = 6;
    self.manager.configuration.showDateSectionHeader = NO;
    

    // HXPhotoView grid
    self.photoView = [HXPhotoView photoManager:self.manager];
    self.photoView.delegate   = self;
    self.photoView.outerCamera = YES;
    self.photoView.spacing    = 6.0;
    self.photoView.lineCount  = 4;
    self.photoView.translatesAutoresizingMaskIntoConstraints = NO;

    [self.contentView addSubview:self.photoView];
    [NSLayoutConstraint activateConstraints:@[
        [self.photoView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [self.photoView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.photoView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
    ]];
    self.heightConstraint = [self.photoView.heightAnchor constraintEqualToConstant:164];
    self.heightConstraint.active = YES;

    [self.photoView refreshView];

    // Initialize default height in the wrapper so the first layout has a size
    val.height = CGRectGetHeight(self.photoView.bounds) > 0 ? CGRectGetHeight(self.photoView.bounds) : 180.f;
}

- (void)update {
    [super update];
    // nothing else needed
}

#pragma mark - HXPhotoViewDelegate

// Called when the grid's size changes (rows wrap, etc.)
- (void)photoView:(HXPhotoView *)photoView updateFrame:(CGRect)frame {
    self.heightConstraint.constant = CGRectGetHeight(frame);
    HXPhotosValue *val = (HXPhotosValue *)self.rowDescriptor.value;
    val.height = CGRectGetHeight(frame) + 16.0; // a little bottom padding
    [self.formViewController.tableView beginUpdates];
    [self.formViewController.tableView endUpdates];
}

// Called after selection changes
- (void)photoView:(HXPhotoView *)photoView
  changeComplete:(NSArray<HXPhotoModel *> *)allList
          photos:(NSArray<HXPhotoModel *> *)photos
          videos:(NSArray<HXPhotoModel *> *)videos
        original:(BOOL)isOriginal
{
    HXPhotosValue *val = (HXPhotosValue *)self.rowDescriptor.value;
    val.selected = photos ?: @[];
}

@end
