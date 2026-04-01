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

@interface PPStory : NSObject
@property (nonatomic, strong) NSString *userID;
@property (nonatomic, strong) NSString *userName;
@property (nonatomic, strong, nullable) NSURL *userImageURL;
@property (nonatomic, strong) NSArray<PPStoryItem *> *items;
@property (nonatomic, assign) BOOL isSeen;
@property (nonatomic, strong, nullable) NSDate *updatedAt;
@end


@interface PPStoryItem : NSObject
@property (nonatomic, strong) NSURL *mediaURL;
@property (nonatomic, assign) BOOL isVideo;
@property (nonatomic, assign) NSTimeInterval duration;
@end




NS_ASSUME_NONNULL_END
