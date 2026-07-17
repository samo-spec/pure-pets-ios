#import <UIKit/UIKit.h>
#import "EnumValues.h"

NS_ASSUME_NONNULL_BEGIN

@interface PPUniversalCellViewModel : NSObject

@property (nonatomic, copy, nullable) NSString *ModelID;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *priceText;
@property (nonatomic, copy) NSString *discountText;
@property (nonatomic, assign) BOOL isNew;
@property (nonatomic, assign) BOOL hasOffer;
@property (nonatomic, assign) BOOL isOwner;
@property (nonatomic, assign, getter=isPubliclyVisible) BOOL publiclyVisible;
@property (nonatomic, copy, nullable) NSString *imageURL;
@property (nonatomic, strong, nullable) UIImage *image;
@property (nonatomic, strong, nullable) UIImage *placeholder;
@property (nonatomic, copy) NSString *blurHash;
@property (nonatomic, assign) BOOL isVideoMedia;
@property (nonatomic, copy, nullable) NSString *videoURL;
@property (nonatomic, copy, nullable) NSString *videoThumbnailURL;
@property (nonatomic, copy, nullable) NSDictionary *mediaMetadata;
@property (nonatomic, strong, nullable) id ModelObject;
@property (nonatomic, assign) PPCellContext modelContext;
@property (nonatomic, assign) CollectioCellSection cellSection;
@property (nonatomic, copy) NSString *modelType;
@property (nonatomic, assign) PPSection ppSection;
@property (nonatomic, copy) NSString *stockStatusText;
@property (nonatomic, copy) NSString *location;
@property (nonatomic, strong, nullable) NSIndexPath *indexPath;
@property (nonatomic, assign) CGSize imageSize;
@property (nonatomic, assign) NSInteger itemQuantitiy;
@property (nonatomic, strong, nullable) NSNumber *discountPercent;
@property (nonatomic, strong, nullable) NSNumber *discountAmount;
@property (nonatomic, strong, nullable) NSNumber *finalPrice;
@property (nonatomic, strong, nullable) NSNumber *price;
@property (nonatomic, assign) CGFloat preferredAspectRatio;
@property (nonatomic, copy, nullable) NSString *contextualReasonText;
@property (nonatomic, copy, nullable) NSString *contextualReasonIconName;
@property (nonatomic, copy) NSString *currencyCode;
@property (nonatomic, copy) NSString *availabilityText;
@property (nonatomic, copy) NSString *badgeText;
@property (nonatomic, assign, getter=isSkeleton) BOOL skeleton;

- (instancetype)initWithModel:(nullable id)model
                      context:(PPCellContext)context;
- (instancetype)initWithModel:(nullable id)model
                ppDataSection:(PPDataSection)ppDataSection;
- (instancetype)initSkeleton;
- (instancetype)initSkeletonForDataSection:(PPDataSection)section;

@end

NS_ASSUME_NONNULL_END
