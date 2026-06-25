//
//  ProviderStorefrontProductsVC.m
//  Pure Pets
//

#import "ProviderStorefrontProductsVC.h"

#import "PetAccessory.h"
#import "UserModel.h"

@implementation ProviderStorefrontProductsVC

- (instancetype)init
{
    return [self initWithSeller:nil items:@[] categoryIdentifier:nil];
}

- (instancetype)initWithSeller:(UserModel *)seller
                         items:(NSArray<PetAccessory *> *)items
            categoryIdentifier:(NSString *)categoryIdentifier
{
    self = [super init];
    if (self) {
        self.seller = seller;
        self.sellerItems = items ?: @[];
        self.providerCategoryIdentifier = [categoryIdentifier copy];
        self.title = [self pp_storefrontTitleForSeller:seller];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    if (self.title.length == 0) {
        self.title = [self pp_storefrontTitleForSeller:self.seller];
    }
}

- (NSString *)pp_storefrontTitleForSeller:(UserModel *)seller
{
    if (![seller isKindOfClass:UserModel.class]) {
        return @"";
    }

    if ([seller respondsToSelector:@selector(bestDisplayName)]) {
        NSString *bestName = [seller bestDisplayName];
        if (bestName.length > 0) {
            return bestName;
        }
    }

    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    if (seller.FirstName.length > 0) {
        [parts addObject:seller.FirstName];
    }
    if (seller.LastName.length > 0) {
        [parts addObject:seller.LastName];
    }
    if (parts.count > 0) {
        return [parts componentsJoinedByString:@" "];
    }

    if (seller.UserName.length > 0) {
        return seller.UserName;
    }

    return @"";
}

@end
