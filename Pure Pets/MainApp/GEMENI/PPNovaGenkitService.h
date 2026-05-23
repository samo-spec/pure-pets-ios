//
//  PPNovaGenkitService.h
//  Pure Pets
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPNovaGenkitService : NSObject

+ (instancetype)sharedService;

- (void)sendMessage:(NSString *)message
          sessionId:(nullable NSString *)sessionId
           language:(NSString *)language
            context:(nullable NSDictionary *)context
         completion:(void(^)(NSString * _Nullable text, NSDictionary * _Nullable metadata, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
