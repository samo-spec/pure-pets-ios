//
//  HXPhotosFormCell.m
//  Pure Pets
//
//  Migrated to use PPImageCollection (Swift HXPhotoPicker backend).
//  Matches Admin's PPImageCollectionRow pattern.
//

#import "HXPhotosFormCell.h"
#import <Photos/Photos.h>

@interface HXPhotosFormCell ()
@property (nonatomic, strong, readwrite) PPImageCollection *imageCollection;
@end

@implementation HXPhotosFormCell

+ (void)load {
    [XLFormViewController.cellClassesForRowDescriptorTypes
     setObject:HXPhotosFormCell.class
        forKey:XLFormRowDescriptorTypeHXPhotos];
}

- (void)configure {
    [super configure];
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    _maxImages = 6;

    _imageCollection = [[PPImageCollection alloc] initWithFrame:CGRectZero
                                                  maxImageCount:_maxImages
                                                      useArabic:[kLang(@"lang") isEqualToString:@"ar"]];
    _imageCollection.translatesAutoresizingMaskIntoConstraints = NO;
    _imageCollection.delegate = self;
    _imageCollection.allowsEditing = YES;
    _imageCollection.allowsReordering = YES;

    [self.contentView addSubview:_imageCollection];

    [NSLayoutConstraint activateConstraints:@[
        [_imageCollection.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [_imageCollection.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [_imageCollection.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [_imageCollection.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8],
        [_imageCollection.heightAnchor constraintGreaterThanOrEqualToConstant:110]
    ]];
}

- (void)update {
    [super update];
    _imageCollection.maxImageCount = _maxImages;
    _imageCollection.titleText = self.rowDescriptor.title ?: @"";

    // Sync value → collection (if value set externally).
    id val = self.rowDescriptor.value;
    if ([val isKindOfClass:[NSArray class]]) {
        NSArray *arr = (NSArray *)val;
        if (arr.count > 0 && [_imageCollection allImages].count == 0) {
            for (id img in arr) {
                if ([img isKindOfClass:[UIImage class]]) {
                    [_imageCollection addImage:img];
                }
            }
        }
    } else if ([val isKindOfClass:[UIImage class]] && [_imageCollection allImages].count == 0) {
        [_imageCollection addImage:(UIImage *)val];
    }
}

+ (CGFloat)formDescriptorCellHeightForRowDescriptor:(XLFormRowDescriptor *)rowDescriptor {
    return 126;
}

+ (BOOL)formDescriptorCellCanBecomeFirstResponder {
    return NO;
}

#pragma mark - Setters

- (void)setMaxImages:(NSInteger)maxImages {
    _maxImages = MAX(1, maxImages);
    _imageCollection.maxImageCount = _maxImages;
}

#pragma mark - PPImageCollectionDelegate

- (void)imageCollection:(PPImageCollection *)collection didUpdateImages:(NSArray<UIImage *> *)images {
    if (images.count == 0) {
        self.rowDescriptor.value = nil;
    } else if (_maxImages == 1) {
        self.rowDescriptor.value = images.firstObject;
    } else {
        self.rowDescriptor.value = [images copy];
    }
}

- (void)imageCollection:(PPImageCollection *)collection didSelectImage:(UIImage *)image AtIndex:(NSInteger)index {
    // Viewer handled internally by PPImageCollection.
}

- (void)imageCollectionDidRequestAddImage:(PPImageCollection *)collection {
    // Picker handled internally by PPImageCollection.
}

@end
