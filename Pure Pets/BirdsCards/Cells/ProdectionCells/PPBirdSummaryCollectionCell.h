// PPBirdSummaryCollectionCell.h
// Pure Pets

#import <UIKit/UIKit.h>
#import "PPHomeHelper.h"



NS_ASSUME_NONNULL_BEGIN


typedef void (^PPImageLoader)(UIImageView *imageView,
                              NSString * _Nullable urlString,
                              UIImage  * _Nullable placeholder,
                              UIView  * _Nullable card);




@interface PPBirdSummaryCellStyle : NSObject
@property (nonatomic, strong) UIColor *cardBackground;   // default systemBackground
@property (nonatomic, strong) UIColor *titleColor;       // default labelColor
@property (nonatomic, strong) UIColor *metaColor;        // default secondaryLabelColor
@property (nonatomic, strong) UIColor *brandColor;       // deep red ribbon
@property (nonatomic, assign) CGFloat cardCorner;        // default 22
@property (nonatomic, assign) CGFloat photoCorner;       // default 16


@end



@class CardModel, PPQuickActionsView, ZMJTipView;


@protocol PPBirdSummaryCollectionCellDelegate <NSObject>
@required
- (void)archiveCardData:(CardModel *)card cellIndexPath:(NSIndexPath *)indexPath;
- (void)deleteEditOptions:(NSInteger)option CardData:(CardModel *)card;
- (void)shareCard:(NSInteger)kind index:(NSInteger)idx cardImage:(UIImage *)image subKind:(NSString *)subKind cardID:(NSString *)cardID;
- (void)sellThisCard:(CardModel *)card lastLocation:(NSInteger)location cageIndex:(NSInteger)idx;
@end

@interface PPBirdSummaryCollectionCell : UICollectionViewCell
@property (nonatomic, strong) NSIndexPath *cellIndexPath;
@property (nonatomic, copy) void (^onTapGrid)(void);
@property (nonatomic, copy) void (^onTapShare)(void);
@property (nonatomic, weak) id<PPBirdSummaryCollectionCellDelegate> delegate;
@property (nonatomic, strong) PPQuickActionsView *actionsView;
@property (nonatomic, copy) NSString *currentImageURL;
// Configuration
+ (NSString *)reuseIdentifier;
- (void)configureWithCard:(CardModel *)cardData
              placeholder:(UIImage * _Nullable)placeholder
                      RTL:(BOOL)rtl
             imageLoader:(PPImageLoader)loader;


@property (nonatomic, strong) PPBirdSummaryCellStyle *style; // set before configure if you want
@property(nonatomic, assign) BOOL isActive;
@property (nonatomic, assign) BOOL haveArchive;
@property (nonatomic, strong) CardModel *cardModel;
@property (nonatomic, strong) ArchiveModel *archiveModel;
@property (nonatomic, copy) PPImageLoader loader;
@property (nonatomic, strong) ZMJTipView *tipView;

@end

NS_ASSUME_NONNULL_END




/*
 //
//  PPBirdSummaryCellStyle.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 08/10/2025.
//


//  PPBirdSummaryCollectionCell.h

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^PPImageLoader)(UIImageView *imageView, NSString *urlString, UIImage * _Nullable placeholder);
typedef void(^PPVoidBlock)(void);

@interface PPBirdSummaryCellStyle : NSObject
@property (nonatomic, strong) UIColor *cardBackground;   // default systemBackground
@property (nonatomic, strong) UIColor *titleColor;       // default labelColor
@property (nonatomic, strong) UIColor *metaColor;        // default secondaryLabelColor
@property (nonatomic, strong) UIColor *brandColor;       // deep red ribbon
@property (nonatomic, assign) CGFloat cardCorner;        // default 22
@property (nonatomic, assign) CGFloat photoCorner;       // default 16
@end


@protocol BirdCardDelegate <NSObject>
-(void)shareCard:(long)rowIndex index:(long)index  cardImage:(UIImage *)cardImage  subKind:(NSString *)subKind cardID:(NSString *)cardID;
-(void)moreCardOptions:(long)rowIndex index:(long)index  CardData:(CardModel *)CardData cellView:(UIView *)cellView cellIndexPath:(NSIndexPath *)cellIndexPath;
-(void)showArchive:(NSIndexPath *)cellIndexPath archiveClass:(ArchiveModel *)archiveClass  haveArchive:(long)haveArchive CardData:(CardModel *)CardData;
-(void)deleteEditOptions:(long)index CardData:(CardModel *)CardData;
-(void)archiveCardData:(CardModel *)CardData cellIndexPath:(NSIndexPath *)cellIndexPath;
-(void)sellThisCard:(CardModel *)cardToSell lastLocation:(CardSection)lastLocation cageIndex:(NSInteger)cageIndex;

@end

@interface PPBirdSummaryCollectionCell : UICollectionViewCell
@property (nonatomic, weak) id <BirdCardDelegate> delegate;

@property (nonatomic, strong, readonly) UIButton *gridButton;
@property (nonatomic, strong, readonly) UIButton *shareButton;
@property (nonatomic, strong) NSIndexPath *cellIndexPath;

+ (NSString *)reuseIdentifier;

- (void)configureWithCard:(CardModel *)cardData  placeholder:(UIImage * _Nullable)placeholder
                         RTL:(BOOL)rtl
                 imageLoader:(PPImageLoader)loader;

@property (nonatomic, copy) PPVoidBlock onTapGrid;
@property (nonatomic, copy) PPVoidBlock onTapShare;

@property (nonatomic, strong) PPBirdSummaryCellStyle *style; // set before configure if you want

@property(nonatomic, assign) BOOL isActive;
@property (nonatomic, assign) BOOL haveArchive;
@property (nonatomic, strong) CardModel *cardModel;
@property (nonatomic, strong) ArchiveModel *archiveModel;

@end

NS_ASSUME_NONNULL_END
*/
