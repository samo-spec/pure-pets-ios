//
//  HXPhotosFormCell.h
//  Pure Pets
//
//  Migrated to use PPImageCollection (Swift HXPhotoPicker backend).
//

#import "PPImageCollection.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString * const XLFormRowDescriptorTypeHXPhotos;

/// XLForm custom cell wrapping PPImageCollection.
/// Row value is NSArray<UIImage *> (multi) or UIImage (single).
@interface HXPhotosFormCell : XLFormBaseCell <PPImageCollectionDelegate>
@property (nonatomic, strong, readonly) PPImageCollection *imageCollection;
@property (nonatomic, assign) NSInteger maxImages;
@end

NS_ASSUME_NONNULL_END
