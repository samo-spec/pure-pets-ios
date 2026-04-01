//
//  HXPhotosFormCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 13/08/2025.
//

NS_ASSUME_NONNULL_BEGIN

// Use this row type when creating the row.
extern NSString * const XLFormRowDescriptorTypeHXPhotos;

// Forward declarations from HXPhotoPicker

@class HXPhotoModel;

/// Wrapper that lives in `rowDescriptor.value`
@interface HXPhotosValue : NSObject
@property (nonatomic, copy)   NSArray<HXPhotoModel *> *selected;
@property (nonatomic, assign) CGFloat height;   // dynamic cell height
@end

/// XLForm custom cell that embeds HXPhotoView
@interface HXPhotosFormCell : XLFormBaseCell
@end

NS_ASSUME_NONNULL_END
