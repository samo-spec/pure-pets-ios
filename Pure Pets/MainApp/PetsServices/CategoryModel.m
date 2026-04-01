//
//  CategoryModel.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 14/07/2025.
//

#import "CategoryModel.h"
@implementation CategoryModel

-(NSString *)formDisplayText
{
    return _name;
}

- (id)formValue
{
    return self;
}
- (instancetype)initWithID:(NSString *)categoryID name:(NSString *)name {
    self = [super init];
    if (self) {
        _categoryID = categoryID;
        _name = name;
    }
    return self;
}

- (NSString *)description {
    return self.name; // Used by XLForm to display the name
}
@end
