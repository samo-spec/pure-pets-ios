//
//  SearchResultItem.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 12/08/2025.
//


// SearchResultItem.h
// SearchResultItem.h
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class PetAd, PetAccessory, ServiceModel, VetModel;

typedef NS_ENUM(NSInteger, SearchResultType) {
    SearchResultTypePetAd,
    SearchResultTypeAccessory,
    SearchResultTypeService,
    SearchResultTypeVet,
    SearchResultTypeFood
};

@interface SearchResultItem : NSObject
@property (nonatomic, assign) SearchResultType type;
@property (nonatomic, copy) NSString *titleText;
@property (nonatomic, copy) NSString *subtitleText;
@property (nonatomic, copy) NSString *imageURLString;
@property (nonatomic, strong) id rawObject; // PetAd / PetAccessory / ServiceModel / VetModel
+ (instancetype)itemWithType:(SearchResultType)type
                       title:(NSString *)title
                    subtitle:(NSString *)subtitle
                     imageURL:(NSString *)imageURL
                    rawObject:(id)obj;
@end
