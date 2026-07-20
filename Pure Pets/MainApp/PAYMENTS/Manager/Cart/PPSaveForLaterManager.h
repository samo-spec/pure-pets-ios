#import <Foundation/Foundation.h>
#import "CartItem.h"

NS_ASSUME_NONNULL_BEGIN

@class PPUniversalCellViewModel;
typedef void (^PPSaveForLaterRemoveCompletion)(NSError * _Nullable error);

@interface PPSaveForLaterManager : NSObject

+ (instancetype)sharedManager NS_SWIFT_NAME(shared());

- (NSArray<CartItem *> *)savedItems;
- (void)saveItemForLater:(CartItem *)item;
- (void)saveViewModelForLater:(PPUniversalCellViewModel *)viewModel;
- (void)removeItem:(CartItem *)item;
- (void)removeItem:(CartItem *)item completion:(PPSaveForLaterRemoveCompletion _Nullable)completion;
- (BOOL)isItemSaved:(NSString *)itemID;
- (void)clearAll;

- (void)startListeningToSavedForLaterChanges;
- (void)stopListeningToSavedForLaterChanges;

@end

NS_ASSUME_NONNULL_END
