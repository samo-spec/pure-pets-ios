//
//  CollectionViewCell.h
//  collevtionViewWithSearchBar
//
//  Created by Homam on 2015-01-02.
//  Copyright (c) 2015 Homam. All rights reserved.
//


#import "importantFiles.h"
#import <Pure_Pets-Swift.h>
#import "FTPopOverMenu.h"
#import "TQImageViewer.h"
#import "DetailsTableViewCell.h"
#import "CCActivityHUD.h"
#import "YIInnerShadowView.h"
#import "PressButton.h"
#import <AVFoundation/AVFoundation.h>
#import "YYAnimatedImageView.h"
@class CollectionViewCell;

@protocol JPCCellDelegate<NSObject>

@optional
- (void)cellPlayButtonDidClick:(CollectionViewCell *)cell;

@end


@protocol shareCardDelegate <NSObject>
-(void)shareCard:(long)rowIndex index:(long)index  cardImage:(UIImage *)cardImage  subKind:(NSString *)subKind cardID:(NSString *)cardID;
-(void)moreCardOptions:(long)rowIndex index:(long)index  CardData:(CardModel *)CardData cellView:(UIView *)cellView cellIndexPath:(NSIndexPath *)cellIndexPath;
-(void)showArchive:(NSIndexPath *)cellIndexPath archiveClass:(ArchiveModel *)archiveClass  haveArchive:(long)haveArchive CardData:(CardModel *)CardData;
-(void)deleteEditOptions:(long)rowIndex index:(long)index  CardData:(CardModel *)CardData cellView:(UIView *)cellView cellIndexPath:(NSIndexPath *)cellIndexPath;
@end

@interface CollectionViewCell : UICollectionViewCell<UITableViewDelegate,UITableViewDataSource,showParentData>

@property (nonatomic, strong) UIView *originalSuperview; // For returning the view back
@property (nonatomic, strong) NSMutableArray<NSLayoutConstraint *> *originalConstraints; // For restoring constraints
@property (strong, nonatomic) IBOutlet UIImageView *eggImage;

@property (strong, nonatomic) IBOutlet UIView *videoContainerView;
@property (strong, nonatomic)  UIImageView *warningImageView;
@property (weak, nonatomic) IBOutlet UIButton *playButton;
@property NSString *VidThum;
@property (weak, nonatomic) IBOutlet UIImageView *videoPlayView;
@property(nonatomic, weak) id<JPCCellDelegate> playDelegate;
@property(nonatomic, strong)NSIndexPath *indexPath;

@property (nonatomic, strong) NSURL *videoURL;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;

- (void)prepareForReuse; // Override
- (void)play;
- (void)pause;
-(void)resetVideoFrame;

@property  long haveArchive;
@property  ArchiveModel *archiveClass;

@property (nonatomic, weak) id <shareCardDelegate> delegate;
@property  long cellRowIndex;
@property  long cellhaveGard;
@property  long cellActive;
@property  int garAdded;
@property  NSIndexPath *cellIndexPath;
@property  NSString *subKind;

-(void)setButtonGardActive;
-(void)setButtonGardDisabled;
//@property  UIImage *cardImage;
@property (strong, nonatomic) IBOutlet UILabel *CardTitle;
@property (strong, nonatomic) IBOutlet UILabel *ageLabel;
@property (strong, nonatomic) CCActivityHUD *activityHUD;
@property (weak, nonatomic) IBOutlet UILabel *laName;
@property (weak, nonatomic) IBOutlet UILabel *RingID;
@property (weak, nonatomic) IBOutlet UILabel *CategoryLabel;
@property (weak, nonatomic) IBOutlet UILabel *GenderLabel;
@property (weak, nonatomic) IBOutlet UIView *cellBottomView;
@property (weak, nonatomic) IBOutlet UIImageView *mainImageView;
@property (weak, nonatomic) IBOutlet UIImageView *backgroundImage;
@property (weak, nonatomic) IBOutlet UILabel *BirthDateLabel;
@property (weak, nonatomic) IBOutlet UILabel *DescLabel;
@property (strong, nonatomic) IBOutlet UIView *topView;
@property (strong, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic,strong) UIViewController     *VC;
@property (strong, nonatomic) IBOutlet PressButton *currentArchiveBTN;
@property (strong, nonatomic) IBOutlet UILabel *splitTXT;

@property int layoutTypeFlag;
@property (nonatomic,strong) CardModel     *CardData;
@property (nonatomic,strong) NSArray<CardModel *>     *CardsdataSource;
@property (nonatomic,strong) CardModel     *FatherCard;
@property (nonatomic,strong) CardModel     *MotherCard;
-(void)LoadData;

@property (strong, nonatomic) IBOutlet PressButton *shareBtn;
@property (strong, nonatomic) IBOutlet PressButton *archiveBtn;
@property (strong, nonatomic) IBOutlet UIView *loanView;

@end
