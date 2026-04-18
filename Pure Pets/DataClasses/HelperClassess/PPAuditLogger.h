#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPAuditLogger : NSObject

+ (void)writeAuditLogForAction:(NSString *)action
                    collection:(NSString *)collection
                    documentId:(nullable NSString *)docId
                          data:(nullable NSDictionary *)data;

@end

NS_ASSUME_NONNULL_END