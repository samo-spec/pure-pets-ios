//
//  PPHomeOrderStatusCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/3/26.
//


@interface PPHomeOrderStatusCell : UICollectionViewCell
+ (NSString *)reuseIdentifier;
- (void)configurePlaceholderExpanded:(BOOL)expanded;
- (void)configureWithOrderReference:(NSString *)orderReference
                   orderKickerTitle:(NSString *)orderKickerTitle
                    previewImageURLs:(NSArray<NSString *> *)previewImageURLs
                               meta:(NSString *)meta
                        statusTitle:(NSString *)statusTitle
                         statusHint:(NSString *)statusHint
                          statusKey:(NSString *)statusKey
                           progress:(double)progress
                        footerText:(NSString *)footerText
                        statusColor:(UIColor *)statusColor
                     statusIconName:(NSString *)statusIconName
                        actionTitle:(NSString *)actionTitle
                           expanded:(BOOL)expanded;
- (void)setExpandedState:(BOOL)expanded animated:(BOOL)animated;
- (void)refreshDecorativeLayersForCurrentBounds;
@property (nonatomic, copy, nullable) void (^onTrackTap)(void);
@property (nonatomic, copy, nullable) void (^onHistoryTap)(void);
@property (nonatomic, copy, nullable) void (^onCollapseTap)(void);
@end
