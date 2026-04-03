//
//  FileUploadManager.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 18/01/2025.
//


#import "FileUploadManager.h"

#import <UserNotifications/UserNotifications.h>


@implementation FileUploadManager

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *backgroundConfig = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"GTMSessionFetcher-firebasestorage.googleapis.com"];
        backgroundConfig.allowsCellularAccess = YES; // Optional: Allow uploads over cellular
        backgroundConfig.HTTPMaximumConnectionsPerHost = 5;
        self.backgroundSession = [NSURLSession sessionWithConfiguration:backgroundConfig delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    }
    return self;
}

- (void)uploadFilesfromArray:(NSMutableArray<UIImage *> *)Files
                  completion:(void (^)(NSMutableArray<FileModel *> *filesArray, NSError *error))completion {
    
    __block NSMutableArray<FileModel *> *lastFilesArray = [[NSMutableArray<FileModel *> alloc] init];
    if (!Files || Files.count == 0) {
        if (completion) {
            completion(lastFilesArray, nil);
        }
        return;
    }
    
    __block NSError *uploadError = nil;
    dispatch_group_t uploadGroup = dispatch_group_create();
    
    NSString *userID = UserManager.sharedManager.currentUser.ID;
    
    for (NSInteger idx = 0; idx < Files.count; idx++) {
        UIImage *image = Files[idx];
        if (!image) {
            uploadError = [NSError errorWithDomain:@"com.app.error"
                                              code:1001
                                          userInfo:@{NSLocalizedDescriptionKey : @"Invalid image"}];
            continue;
        }
        
        dispatch_group_enter(uploadGroup);
        
        NSData *fileData = [GM compressImageToMaxSize:image maxSizeKB:500];
        if (!fileData) {
            uploadError = [NSError errorWithDomain:@"com.app.error"
                                              code:1002
                                          userInfo:@{NSLocalizedDescriptionKey : @"Failed to get image data"}];
            dispatch_group_leave(uploadGroup);
            continue;
        }
        
        NSString *contentType = @"image/jpeg";
        NSString *fileName = [NSString stringWithFormat:@"%@_%ld", [[NSUUID UUID] UUIDString], (long)idx];
        NSString *uniqueFileName = [NSString stringWithFormat:@"%@.jpg", fileName];
        
        FileModel *newFile = [FileModel new];
        newFile.ID = idx;
        newFile.FileName = uniqueFileName;
        newFile.FileType = 0;       // 0 = image
        newFile.videoDuration = 0;  // no video for UIImage
        [lastFilesArray addObject:newFile];
        
        NSString *storagePath = [NSString stringWithFormat:@"CardsImages/%@/%@", userID, uniqueFileName];
        FIRStorageReference *storageRef = [[FIRStorage storage] referenceWithPath:storagePath];
        
        FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] init];
        metadata.contentType = contentType;
        
        FIRStorageUploadTask *uploadTask =
        [storageRef putData:fileData
                   metadata:metadata
                 completion:^(FIRStorageMetadata * _Nullable metadata, NSError * _Nullable error) {
            if (error) {
                uploadError = error;
                dispatch_group_leave(uploadGroup);
                return;
            }
            
            [storageRef downloadURLWithCompletion:^(NSURL * _Nullable url, NSError * _Nullable error) {
                if (error) {
                    NSLog(@"Error getting download URL: %@", error);
                    uploadError = error;
                    dispatch_group_leave(uploadGroup);
                    return;
                }
                
                newFile.FileUrl = url.absoluteString;
                dispatch_group_leave(uploadGroup);
            }];
        }];
        
        [uploadTask observeStatus:FIRStorageTaskStatusProgress
                         handler:^(FIRStorageTaskSnapshot *snapshot) {
            double progress = 100.0 * (snapshot.progress.completedUnitCount) /
                              (snapshot.progress.totalUnitCount);
            NSLog(@"Upload Progress: %.2f%%", progress);
        }];
    }
    
    dispatch_group_notify(uploadGroup, dispatch_get_main_queue(), ^{
        NSLog(@"orderdArr %@", [lastFilesArray modelToJSONObject]);
        if (completion) {
            completion(lastFilesArray, uploadError);
        }
    });
}

// NOTE: Legacy HXPhotoModel upload method removed (HXPhotoPicker ObjC migrated to Swift).
// Use uploadFilesfromArray: (UIImage-based) instead.


- (UIImage *)imageFromLocalURL:(NSURL *)fileURL {
    // Ensure the URL is a file URL
    if (![fileURL isFileURL]) {
        NSLog(@"The provided URL is not a file URL.");
        return nil;
    }
    
    // Get the file path from the URL
    NSString *filePath = [fileURL path];
    UIImage *image = [UIImage imageWithContentsOfFile:filePath];
    return image;
}

- (NSMutableArray<FileModel *> *)moveFileToIndex:(NSUInteger)toIndex inArray:(NSMutableArray<FileModel *> *)filesArray{
    
    NSInteger haveVideo = 0;
    NSInteger fromIndex = 0;
    for (int i = 0; i < filesArray.count; i++) {
        FileModel *file = filesArray[i];
        if (file.FileType == 1)
        {
            haveVideo = 1;
            fromIndex = i;
            break;
        }
    }
    
    NSLog(@"haveVideo:%ld \n  fromIndex:%ld \n  filesArray count:%ld \n toIndex:%ld \n  ",haveVideo,fromIndex,filesArray.count,toIndex);
    if (fromIndex >= filesArray.count || toIndex >= filesArray.count){
        NSLog(@"Invalid fromIndex or toIndex");
        return filesArray;
    }

    if (fromIndex == toIndex){
        NSLog(@"fromIndex and toIndex are the same no need to move");
        return filesArray;
    }

    if(haveVideo == 1)
    {
        FileModel *fileToMove = [filesArray objectAtIndex:fromIndex];
        NSMutableArray<FileModel *> *newArr = [filesArray mutableCopy];
        [newArr removeObjectAtIndex:fromIndex];
        [newArr insertObject:fileToMove atIndex:toIndex];
        
        for (int i = 0 ; i < newArr.count; i ++) {
            newArr[i].ID = i;
        }
        return newArr;
    } else  return filesArray;
    
}


- (BOOL)isFileName:(NSString *)fileName FoundInUrl:(NSURL *)fileURL {
    return [fileURL.absoluteString rangeOfString:fileName].location != NSNotFound;
}

- (BOOL)isFileAlreadyOnFirebaseStorage:(NSURL *)fileURL {
    NSString *substring = @"firebasestorage.googleapis.com";
    return [fileURL.absoluteString rangeOfString:substring].location != NSNotFound;
}










#pragma mark - NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        NSLog(@"Background upload task completed with error: %@", error);
        // Handle upload error (e.g., retry)
    } else {
        NSLog(@"Background upload task completed successfully");
       // Update firestore and notify user
       
    }
    
}

//This is an optional method that gets called if the background download session is terminated.
- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session {
    
    UIApplication *app = [UIApplication sharedApplication];
    // Check if all download tasks have finished
    
    [app beginBackgroundTaskWithExpirationHandler:^{
        //Handle if background task did not complete. This is important.
    }];
    
    
    if (session.configuration.identifier != nil) {
        [self performSelectorOnMainThread:@selector(completeBackgroundSession:) withObject:session waitUntilDone:YES];
      //  [self performSelectorOnMainThread:@selector(completeBackgroundSession:) withObject:session afterDelay:0.5];
    }
    
}

-(void) completeBackgroundSession:(NSURLSession *)session {
    
    //    Use the identifier to get the session.
    
    
    //    if session id match what has previously been saved, complete background session.
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^ {
        //Show notification for successful download.
        NSLog(@"Finished background session");
       // [self scheduleLocalNotification];
         
    }];
    
}


#pragma mark - Local Notification

- (void)scheduleLocalNotification {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    UNAuthorizationOptions options = UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge;
    [center requestAuthorizationWithOptions:options
                         completionHandler:^(BOOL granted, NSError * _Nullable error) {
        if(granted) {
            UNMutableNotificationContent* content = [[UNMutableNotificationContent alloc] init];
            content.title = @"Card Ready";
            content.body = @"Your card is ready to view.";
            content.sound = [UNNotificationSound defaultSound];
            
            UNTimeIntervalNotificationTrigger* trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:1 repeats:NO];
            UNNotificationRequest* request = [UNNotificationRequest requestWithIdentifier:@"CardReadyNotification" content:content trigger:trigger];
             [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
                if (error) {
                     NSLog(@"Error scheduling notification: %@", error);
                } else {
                     NSLog(@"Notification scheduled successfully");
                }
             }];
        }
    }];
}


@end

