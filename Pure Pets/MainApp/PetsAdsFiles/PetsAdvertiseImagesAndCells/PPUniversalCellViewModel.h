//
//  PPUniversalCellViewModel.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 01/01/2026.
//

NS_ASSUME_NONNULL_BEGIN

/// Public view model for configuring the cell
@interface PPUniversalCellViewModel : NSObject
@property (nonatomic, copy,nullable)   NSString *ModelID;
@property (nonatomic, copy)   NSString *title;
@property (nonatomic, copy)   NSString *subtitle;          // optional
@property (nonatomic, copy)   NSString *priceText;         // e.g. "200 ﷼"
@property (nonatomic, copy)   NSString *discountText;      // e.g. "-35%" (show if length > 0)
@property (nonatomic, assign) BOOL isNew;                  // show NEW ribbon
@property (nonatomic, assign) BOOL hasOffer;               // show OFFER ribbon
@property (nonatomic, assign) BOOL isOwner;                // show edit/delete
@property (nonatomic, copy, nullable) NSString *imageURL;  // remote
@property (nonatomic, strong, nullable) UIImage *image;    // local
@property (nonatomic, strong, nullable) UIImage *placeholder;
@property (nonatomic, copy)   NSString *blurHash;
@property (nonatomic,strong)   id ModelObject;
@property (nonatomic, assign) PPCellContext modelContext;
@property (nonatomic, assign) CollectioCellSection cellSection;
@property (nonatomic, copy) NSString *modelType;
@property (nonatomic, assign) PPSection ppSection;
@property (nonatomic, strong) NSString *stockStatusText;
@property (nonatomic, strong) NSString *location;
@property (nonatomic, assign) NSIndexPath *indexPath;
@property (nonatomic, assign) CGSize imageSize;
@property (nonatomic, assign) NSInteger itemQuantitiy;
@property (nonatomic, strong, nullable) NSNumber *discountPercent;  // % discount (0–100)
@property (nonatomic, strong, nullable) NSNumber *discountAmount;   // Absolute discount (e.g. 15.0)
@property (nonatomic, strong) NSNumber *finalPrice;               // Auto-calculated final price
@property (nonatomic, strong) NSNumber *price;                     // Base/original price
@property (nonatomic, assign) CGFloat preferredAspectRatio;
- (instancetype)initWithModel:(id)model
                      context:(PPCellContext)context;
- (instancetype)initWithModel:(id)model ppDataSection:(PPDataSection)ppDataSection;
- (instancetype)initSkeleton;
@end
NS_ASSUME_NONNULL_END
