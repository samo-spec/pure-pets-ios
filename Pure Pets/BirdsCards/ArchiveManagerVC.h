//
//  ArchiveManagerVC.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/12/2024.
//

#import <UIKit/UIKit.h>
#import "CardModel.h"
#import "ChildModel.h"
#import "ArchiveModel.h"

NS_ASSUME_NONNULL_BEGIN

@protocol RemoveChildDelegate <NSObject>
- (void)RemoveChild:(ChildModel *)child;
@end

@interface ArchiveManagerVC : UIViewController

@property (nonatomic, weak) id <RemoveChildDelegate> delegate;
@property (strong, nonatomic) CardModel *cardToArchive;
@property (strong, nonatomic) ChildModel *childToArchive;

// Legacy properties for compatibility
@property (nonatomic) float archiveHeight;
@property (nonatomic) NSInteger FromVC;

@end

NS_ASSUME_NONNULL_END
