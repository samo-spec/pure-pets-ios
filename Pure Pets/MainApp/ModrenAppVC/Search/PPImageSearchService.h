//
//  PPImageSearchService.h
//  Pure Pets
//
//  Direct search by photo service.
//  No Nova, no agent, no chat layer.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PPImageSearchMode) {
    PPImageSearchModeAuto = 0,
    PPImageSearchModeProducts,
    PPImageSearchModePets,
    PPImageSearchModeAdoption
};

@interface PPImageSearchService : NSObject

+ (instancetype)shared;

- (void)searchWithImage:(UIImage *)image
                   mode:(PPImageSearchMode)mode
                  limit:(NSNumber * _Nullable)limit
             completion:(void (^)(NSDictionary * _Nullable response,
                                   NSError * _Nullable error))completion;

/// Shared transport used by Search Controller and camera features that already
/// own a compressed representative frame. Existing UIImage callers continue
/// through this exact implementation after local resizing/compression.
- (void)searchWithImageData:(NSData *)imageData
                contentType:(NSString *)contentType
                       mode:(PPImageSearchMode)mode
                      limit:(NSNumber * _Nullable)limit
                 completion:(void (^)(NSDictionary * _Nullable response,
                                       NSError * _Nullable error))completion
    NS_SWIFT_NAME(search(imageData:contentType:mode:limit:completion:));

+ (NSString *)stringForMode:(PPImageSearchMode)mode;

@end

/// Host-app adapter for Pure Lens. It maps the detector's species to the
/// server-driven MainKinds taxonomy, keeps canonical model objects for routing,
/// and never creates or reads a PetProfile.
@interface PPPureLensDiscoveryBridge : NSObject

- (instancetype)initWithPresenter:(UIViewController *)presenter NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// Resolves a detector species against the current server-driven, user-visible
/// MainKinds taxonomy. `supported == NO` is authoritative only when `error` is nil.
- (void)validateSpecies:(NSString *)species
             completion:(void (^)(BOOL supported,
                                  NSError * _Nullable error))completion
    NS_SWIFT_NAME(validateSpecies(_:completion:));

- (void)searchImageData:(NSData *)imageData
             contentType:(NSString *)contentType
                 species:(NSString *)species
                   breed:(NSString * _Nullable)breed
                   limit:(NSInteger)limit
              completion:(void (^)(NSArray<NSDictionary *> * _Nullable items,
                                    NSError * _Nullable error))completion
    NS_SWIFT_NAME(searchImage(data:contentType:species:breed:limit:completion:));

- (void)searchMarketplaceCategory:(NSString *)category
                           species:(NSString *)species
                             breed:(NSString * _Nullable)breed
                             limit:(NSInteger)limit
                        completion:(void (^)(NSArray<NSDictionary *> * _Nullable items,
                                              NSError * _Nullable error))completion
    NS_SWIFT_NAME(searchMarketplace(category:species:breed:limit:completion:));

- (void)openItemWithIdentifier:(NSString *)identifier
                           kind:(NSString *)kind
                     completion:(void (^)(NSError * _Nullable error))completion
    NS_SWIFT_NAME(openItem(identifier:kind:completion:));

@end

NS_ASSUME_NONNULL_END
