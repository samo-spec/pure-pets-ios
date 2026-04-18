#import "PPAuditLogger.h"
@import FirebaseFirestore;
@import FirebaseAuth;

@implementation PPAuditLogger

+ (void)writeAuditLogForAction:(NSString *)action
                    collection:(NSString *)collection
                    documentId:(nullable NSString *)docId
                          data:(nullable NSDictionary *)data {
    
    NSString *userId = [FIRAuth auth].currentUser.uid ?: @"anonymous";
    NSMutableDictionary *logData = [NSMutableDictionary dictionary];
    logData[@"action"] = action ?: @"unknown";
    logData[@"collection"] = collection ?: @"unknown";
    logData[@"documentId"] = docId ?: @"";
    logData[@"data"] = data ?: @{};
    logData[@"userId"] = userId;
    logData[@"timestamp"] = [FIRFieldValue fieldValueForServerTimestamp];
    logData[@"platform"] = @"ios";
    
    [[[FIRFirestore firestore] collectionWithPath:@"AuditLogs"] addDocumentWithData:logData completion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"[PPAuditLogger] Failed to write audit log: %@", error.localizedDescription);
        } else {
            NSLog(@"[PPAuditLogger] Audit log written for action: %@", action);
        }
    }];
}

@end