//
//  PPStory.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 2/22/26.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <FirebaseFirestore/FirebaseFirestore.h>
#import <AVFoundation/AVFoundation.h>
@class PPStoryItem;

NS_ASSUME_NONNULL_BEGIN

extern const NSTimeInterval PPStoryExpiryInterval;

@interface PPStory : NSObject
@property (nonatomic, strong) NSString *userID;
@property (nonatomic, strong) NSString *userName;
@property (nonatomic, strong, nullable) NSURL *userImageURL;
@property (nonatomic, strong) NSArray<PPStoryItem *> *items;
@property (nonatomic, assign) BOOL isSeen;
@property (nonatomic, strong, nullable) NSDate *updatedAt;
@property (nonatomic, strong, nullable) NSDate *createdAt;
@property (nonatomic, strong) NSSet<NSString *> *viewedBy;
- (BOOL)isExpired;
- (BOOL)isSeenByUserID:(NSString *)userID;
@end


@interface PPStoryItem : NSObject
@property (nonatomic, strong) NSURL *mediaURL;
@property (nonatomic, assign) BOOL isVideo;
@property (nonatomic, assign) NSTimeInterval duration;
@end




NS_ASSUME_NONNULL_END
