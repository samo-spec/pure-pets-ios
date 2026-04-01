//
//  TrashManager.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 14/12/2025.
//


@interface TrashManager : NSObject

+ (instancetype)shared;

- (void)restoreTrashItem:(TrashModel *)trash
              completion:(void(^)(NSError * _Nullable error))completion;
+ (void)repairAllTrashOnce;
@end
