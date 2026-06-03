//
//  PetImageItem.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 14/01/2026.
//


#import "PetImageItem.h"
#pragma mark - PetImageItem

static NSString *PPPetImageItemStringValue(id value)
{
    if ([value isKindOfClass:NSString.class]) {
        return (NSString *)value;
    }
    if ([value isKindOfClass:NSNumber.class]) {
        return [(NSNumber *)value stringValue];
    }
    return @"";
}


@implementation PetImageItem

+ (BOOL)supportsSecureCoding {
    return YES;
}

#pragma mark - NSSecureCoding

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.url forKey:@"url"];
    [coder encodeDouble:self.width forKey:@"width"];
    [coder encodeDouble:self.height forKey:@"height"];
    [coder encodeObject:self.blurHash forKey:@"blurHash"];
    [coder encodeObject:self.mediaType forKey:@"mediaType"];
    [coder encodeObject:self.videoURL forKey:@"videoURL"];
    [coder encodeObject:self.mediaMetadata forKey:@"mediaMetadata"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (self = [super init]) {

        _url = [coder decodeObjectOfClass:NSString.class forKey:@"url"];
        _width = [coder decodeDoubleForKey:@"width"];
        _height = [coder decodeDoubleForKey:@"height"];
        _blurHash = [coder decodeObjectOfClass:NSString.class forKey:@"blurHash"];
        _mediaType = [coder decodeObjectOfClass:NSString.class forKey:@"mediaType"] ?: @"image";
        _videoURL = [coder decodeObjectOfClass:NSString.class forKey:@"videoURL"];
        NSSet *classes = [NSSet setWithObjects:NSDictionary.class, NSArray.class, NSString.class, NSNumber.class, NSNull.class, nil];
        _mediaMetadata = [coder decodeObjectOfClasses:classes forKey:@"mediaMetadata"];
    }
    return self;
}
 
+ (instancetype)itemWithURL:(NSString *)url width:(CGFloat)width height:(CGFloat)height blurHash:(nullable NSString *)blurHash {
    return [[self alloc] initWithURL:url width:width height:height blurHash:blurHash];
}

- (instancetype)initWithURL:(NSString *)url width:(CGFloat)width height:(CGFloat)height blurHash:(nullable NSString *)blurHash{
    if (self = [super init]) {
        _url = [url copy] ?: @"";
        _width = width;
        _height = height;
        _blurHash = blurHash;
        _mediaType = @"image";
        _videoURL = nil;
        _mediaMetadata = nil;
    }
    return self;
}

- (CGFloat)ratio {
    return (_width > 0 ? _height / _width : 1.0);
}

- (BOOL)isVideoMedia
{
    return [self.mediaType.lowercaseString isEqualToString:@"video"] && self.videoURL.length > 0;
}

+ (instancetype)itemWithMediaMetadata:(NSDictionary *)metadata
{
    if (![metadata isKindOfClass:NSDictionary.class]) {
        return nil;
    }

    NSString *type = [PPPetImageItemStringValue(metadata[@"media_type"]) lowercaseString];
    BOOL isVideo = [type isEqualToString:@"video"];
    NSString *displayURL = isVideo ? PPPetImageItemStringValue(metadata[@"thumbnail_url"]) : PPPetImageItemStringValue(metadata[@"url"]);
    if (displayURL.length == 0) {
        displayURL = PPPetImageItemStringValue(metadata[@"url"]);
    }
    if (displayURL.length == 0) {
        return nil;
    }

    CGFloat width = isVideo && [metadata[@"thumbnail_width"] respondsToSelector:@selector(doubleValue)]
        ? [metadata[@"thumbnail_width"] doubleValue]
        : [metadata[@"width"] doubleValue];
    CGFloat height = isVideo && [metadata[@"thumbnail_height"] respondsToSelector:@selector(doubleValue)]
        ? [metadata[@"thumbnail_height"] doubleValue]
        : [metadata[@"height"] doubleValue];

    PetImageItem *item = [[self alloc] initWithURL:displayURL
                                             width:width
                                            height:height
                                          blurHash:metadata[@"blurHash"]];
    item->_mediaType = isVideo ? @"video" : @"image";
    item->_videoURL = isVideo ? PPPetImageItemStringValue(metadata[@"url"]) : nil;
    item->_mediaMetadata = [metadata copy];
    return item;
}


#pragma mark - Serialization

- (NSDictionary *)toDictionary
{
    if ([self.mediaMetadata isKindOfClass:NSDictionary.class] && self.mediaMetadata.count > 0) {
        return self.mediaMetadata;
    }

    NSMutableDictionary *dict = [NSMutableDictionary dictionary];

    dict[@"url"]    = self.url ?: @"";
    dict[@"width"]  = @(self.width);
    dict[@"height"] = @(self.height);
    dict[@"ratio"]  = @(self.ratio);

    if (self.blurHash.length > 0) {
        dict[@"blurHash"] = self.blurHash;
    }
    if (self.mediaType.length > 0 && ![self.mediaType isEqualToString:@"image"]) {
        dict[@"media_type"] = self.mediaType;
    }
    if (self.videoURL.length > 0) {
        dict[@"video_url"] = self.videoURL;
    }

    return dict;
}


+ (instancetype)itemFromDictionary:(NSDictionary *)dict
{
    if (![dict isKindOfClass:NSDictionary.class]) {
        return nil;
    }

    PetImageItem *mediaItem = [self itemWithMediaMetadata:dict];
    if (mediaItem) {
        return mediaItem;
    }

    NSString *url = PPPetImageItemStringValue(dict[@"url"]);
    if (url.length == 0) {
        return nil;
    }

    CGFloat width  = [dict[@"width"] doubleValue];
    CGFloat height = [dict[@"height"] doubleValue];
    NSString *blurHash = dict[@"blurHash"];

    return [[self alloc] initWithURL:url
                               width:width
                              height:height
                            blurHash:blurHash];
}

@end
