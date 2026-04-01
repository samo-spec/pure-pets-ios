//
//  PPCollection.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 30/09/2025.
//


//
//  PPCollection.h
//

#import <UIKit/UIKit.h>
@class MainKindsModel;

typedef NS_ENUM(NSInteger, PPCollectionOptionsPosition) {
    PPCollectionOptionsPositionTop,
    PPCollectionOptionsPositionBottom
};

@interface PPCollection : UIView

@property (nonatomic, strong) NSArray<MainKindsModel *> *optionsArray;
@property (nonatomic, strong) NSArray *allItems; // unfiltered items for collection
@property (nonatomic, strong) NSArray *filteredItems;

@property (nonatomic, assign) PPCollectionOptionsPosition optionsPosition;

/// Callbacks
@property (nonatomic, copy) void (^onSelectOption)(MainKindsModel *selectedOption, NSInteger index);
@property (nonatomic, copy) void (^onSelectCell)(id item, NSIndexPath *indexPath);

/// Factory initializer
- (instancetype)initWithOptions:(NSArray<MainKindsModel *> *)optionsArray
                      cellClass:(Class)cellClass
                 optionsPosition:(PPCollectionOptionsPosition)position;

/// Reload with new data
- (void)reloadWithItems:(NSArray *)items;

@end
