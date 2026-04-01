//
//  BBCheckoutSummaryView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 11/01/2026.
//

@class CartItem;
@interface BBCheckoutSummaryView : UIView
/// Total values
@property (nonatomic, assign) CGFloat itemsTotal;
@property (nonatomic, assign) CGFloat shippingFee;
@property (nonatomic, assign, readonly) CGFloat subtotal;
 /// Checkout button
@property (nonatomic, assign) BOOL showDetails;
/// Update displayed values (you can call this anytime)
- (void)updateTotalsWithItems:(CGFloat)itemsTotal
                     shipping:(CGFloat)shippingFee
                    showTitle:(BOOL)showTitle;
- (void)setShowDetails:(BOOL)showDetails ;
- (void)setShowsItemsPreview:(BOOL)showsItemsPreview;
- (void)updatePreviewItems:(NSArray<CartItem *> *_Nullable)items;
@property (nonatomic, copy, nullable) void (^onTapCheckOut)(void);
- (void)setCardBackgroundImage:(nullable UIImage *)image;
-(void)setCheckoutBTNTitle:(nullable NSString *)title image:(nullable UIImage *)image;
- (void)setCheckoutLoading:(BOOL)loading;


- (void)pp_stopTrustBannerShimmer;
- (void)pp_startTrustBannerShimmer;

@end
