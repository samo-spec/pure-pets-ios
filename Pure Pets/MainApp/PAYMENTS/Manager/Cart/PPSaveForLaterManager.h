#import <Foundation/Foundation.h>
#import "CartItem.h"

NS_ASSUME_NONNULL_BEGIN

@class PPUniversalCellViewModel;

@interface PPSaveForLaterManager : NSObject

+ (instancetype)sharedManager;

- (NSArray<CartItem *> *)savedItems;
- (void)saveItemForLater:(CartItem *)item;
- (void)saveViewModelForLater:(PPUniversalCellViewModel *)viewModel;
- (void)removeItem:(CartItem *)item;
- (BOOL)isItemSaved:(NSString *)itemID;
- (void)clearAll;

- (void)startListeningToSavedForLaterChanges;
- (void)stopListeningToSavedForLaterChanges;

@end

NS_ASSUME_NONNULL_END
