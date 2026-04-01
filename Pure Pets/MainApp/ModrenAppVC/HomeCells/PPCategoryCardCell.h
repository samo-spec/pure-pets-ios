//
//  PPCategoryCardCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 02/01/2026.
//


#import <UIKit/UIKit.h>
@class MainKindsModel;

NS_ASSUME_NONNULL_BEGIN

@interface PPCategoryCardCell : UICollectionViewCell

+ (NSString *)reuseIdentifier;

- (void)configureWithMainKind:(nullable MainKindsModel *)kind
                        isAll:(BOOL)isAll
                     selected:(BOOL)selected;
@property (nonatomic, copy) void (^onSelect)(MainKindsModel *kind, BOOL isAll);
@end

NS_ASSUME_NONNULL_END
