//
//  FileUploadManager.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 18/01/2025.
//



#import <UserNotifications/UserNotifications.h>

@interface FileUploadManager : NSObject
@property (nonatomic, strong) NSURLSession *backgroundSession;

- (void)uploadFilesfromArray:(NSMutableArray<UIImage *> *)Files
                  completion:(void (^)(NSMutableArray<FileModel *> *filesArray, NSError *error))completion;
@end
