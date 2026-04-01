//
//  CategoryModel.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 14/07/2025.
//


@interface CategoryModel : NSObject<XLFormOptionObject>

@property (nonatomic, copy) NSString *categoryID;
@property (nonatomic, copy) NSString *name;

- (instancetype)initWithID:(NSString *)categoryID name:(NSString *)name;
@end
