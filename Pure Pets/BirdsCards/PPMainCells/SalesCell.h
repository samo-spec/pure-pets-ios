//
//  SalesCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 23/12/2025.
//


#import <UIKit/UIKit.h>

@class SalesCell;
@class BuyerModel;
@class CardModel;

@protocol SalesCellDelegate <NSObject>
/*
- (void)salesCellDidRequestDetails:(SalesCell *)cell
                             buyer:(BuyerModel *)buyer
                               card:(CardModel *)card;

- (void)salesCellDidRequestCall:(SalesCell *)cell
                          buyer:(BuyerModel *)buyer;

- (void)salesCellDidRequestWhatsApp:(SalesCell *)cell
                              buyer:(BuyerModel *)buyer;

- (void)salesCellDidRequestReturn:(SalesCell *)cell
                            buyer:(BuyerModel *)buyer;

- (void)salesCellDidRequestExportPDF:(SalesCell *)cell
                               buyer:(BuyerModel *)buyer
                                 card:(CardModel *)card
                               sender:(UIButton *)sender;
*/

-(void)BuyerWhatsAppMessage:(BuyerModel *)b_model;
-(void)Buyercall:(BuyerModel *)b_model;
-(void)returnCard:(BuyerModel *)b_model  buyerCell:(SalesCell *)buyerCell;
-(void)showDetails:(BuyerModel *)b_model cardModel:(CardModel *)cardModel;
- (void)exportSalesBillForBuyer:(BuyerModel *)buyer card:(CardModel *)card  sender:(UIButton *)sender;
-(void)shareCard:(CardModel *)card andImage:(UIImage *)image;


@end


@interface SalesCell : UICollectionViewCell

@property (nonatomic, weak) id<SalesCellDelegate> delegate;

- (void)configureWithBuyer:(BuyerModel *)buyer
                      card:(CardModel *)card;

@end
