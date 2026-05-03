//
//  PPHomeServiceItem.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 28/12/2025.
//


#import "PPHomeServiceItem.h"

@implementation PPHomeServiceItem

- (instancetype)initWithType:(PPHomeServiceType)type
                        title:(NSString *)title
               systemIconName:(NSString *)systemIconName {

    self = [super init];
    if (!self) return nil;

    _type = type;
    _title = [title copy];
    _systemIconName = [systemIconName copy];

    return self;
}

#pragma mark - Defaults

+ (NSArray<PPHomeServiceItem *> *)defaultHomeServices {

    return @[
        [[PPHomeServiceItem alloc]
         initWithType:PPHomeServiceTypeMainService
         title:kLang(@"services")
         systemIconName:@"sparkles"],

        [[PPHomeServiceItem alloc]
         initWithType:PPHomeServiceTypeVet
         title:kLang(@"Veterinary")
         systemIconName:@"veterinaryNewColor"],

        [[PPHomeServiceItem alloc]
         initWithType:PPHomeServiceTypeFood
         title:kLang(@"food")
         systemIconName:@"pet-food2"]
    ];
}

@end
