//
//  PPPDFViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 19/12/2025.
//


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


NS_ASSUME_NONNULL_BEGIN
@class BuyerModel;
@class CardModel;
@interface PPSalesPDFGenerator : NSObject
 + (NSURL * _Nullable)generateSalesBillPDFWithBuyer:(BuyerModel *)buyer
                                    card:(CardModel *)card
                                autoShow:(BOOL)autoShow;
@end
 



@interface PPPDFViewController : UIViewController
@property (nonatomic, strong) NSURL *pdfURL;
@property (nonatomic, strong, nullable) CardModel *cardModel;
@end

NS_ASSUME_NONNULL_END
