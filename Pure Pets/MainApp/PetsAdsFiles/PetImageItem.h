//
//  PetImageItem.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 14/01/2026.
//


#import <Foundation/Foundation.h>



NS_ASSUME_NONNULL_BEGIN

@interface PetImageItem : NSObject<NSSecureCoding>

@property (nonatomic, copy, readonly) NSString *url;
@property (nonatomic, assign, readonly) CGFloat width;
@property (nonatomic, assign, readonly) CGFloat height;

// Derived / cached
@property (nonatomic, assign, readonly) CGFloat ratio;

// Visual placeholder
@property (nonatomic, copy, readonly, nullable) NSString *blurHash;
@property (nonatomic, copy, readonly) NSString *mediaType;
@property (nonatomic, copy, readonly, nullable) NSString *videoURL;
@property (nonatomic, copy, readonly, nullable) NSDictionary *mediaMetadata;
@property (nonatomic, assign, readonly, getter=isVideoMedia) BOOL videoMedia;

// Initializers
+ (instancetype)itemWithURL:(NSString *)url
                      width:(CGFloat)width
                     height:(CGFloat)height
                   blurHash:(nullable NSString *)blurHash;

- (instancetype)initWithURL:(NSString *)url
                      width:(CGFloat)width
                     height:(CGFloat)height
                   blurHash:(nullable NSString *)blurHash;

+ (instancetype)itemWithMediaMetadata:(NSDictionary *)metadata;

// Serialization
- (NSDictionary *)toDictionary;
+ (instancetype)itemFromDictionary:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
