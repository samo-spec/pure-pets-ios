//
//  PPStoriesManager.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 2/22/26.
//
#import "PPStoriesManager.h"
#import <math.h>
#import <FirebaseAuth/FirebaseAuth.h>
#import "UserManager.h"
#import "UserModel.h"
#import "GM.h"

static NSString * const PPStoriesCollectionPath = @"stories";
static NSString *PPStoriesTrimmedString(id value)
{
    if (![value isKindOfClass:NSString.class]) {
        return @"";
    }
    return [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

@implementation PPStoriesManager

+ (instancetype)shared {
    static PPStoriesManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[PPStoriesManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _db = [FIRFirestore firestore];
    }
    return self;
}

- (void)fetchStoriesWithCompletion:(PPStoriesFetchCompletion)completion {
    [[self pp_storiesQuery]
     getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {
        if (completion) {
            completion(error ? @[] : [self pp_storiesFromSnapshot:snapshot], error);
        }
    }];
}

- (void)fetchStoriesForUserID:(NSString *)userID
                    completion:(PPStoriesFetchCompletion)completion
{
    NSString *trimmedUserID =
        [userID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmedUserID.length == 0) {
        if (completion) completion(@[], nil);
        return;
    }

    [[[self.db collectionWithPath:PPStoriesCollectionPath]
        documentWithPath:trimmedUserID]
    getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
        if (error) {
            if (completion) completion(@[], error);
            return;
        }

        if (!snapshot.exists) {
            if (completion) completion(@[], nil);
            return;
        }

        PPStory *story = [self pp_storyFromDocument:snapshot];
        if (completion) completion((story && story.items.count > 0) ? @[story] : @[], nil);
    }];
}

- (id<FIRListenerRegistration>)observeStoriesWithCompletion:(PPStoriesFetchCompletion)completion
{
    if (!completion) {
        return nil;
    }

    // U4: Prevent retain cycle in stories observer
    __weak typeof(self) weakSelf = self;
    return [[self pp_storiesQuery]
            addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (error || !snapshot) {
            NSLog(@"⚠️ [Stories] Snapshot error: %@", error.localizedDescription);
            completion(@[], error);
            return;
        }
        completion([strongSelf pp_storiesFromSnapshot:snapshot], nil);
    }];
}

- (void)recordViewForStoryOwnerID:(NSString *)ownerID
                       completion:(void (^ _Nullable)(NSError * _Nullable error))completion
{
    NSString *trimmedOwnerID =
        [ownerID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmedOwnerID.length == 0) {
        if (completion) completion(nil);
        return;
    }

    NSString *currentUID = PPStoriesTrimmedString([FIRAuth auth].currentUser.uid);
    if (currentUID.length == 0) {
        if (completion) completion(nil);
        return;
    }

    if ([trimmedOwnerID isEqualToString:currentUID]) {
        if (completion) completion(nil);
        return;
    }

    FIRDocumentReference *docRef =
        [[self.db collectionWithPath:PPStoriesCollectionPath] documentWithPath:trimmedOwnerID];
    [docRef updateData:@{
        @"viewedBy": [FIRFieldValue fieldValueForArrayUnion:@[currentUID]]
    } completion:^(NSError * _Nullable error) {
        if (completion) {
            completion(error);
        }
    }];
}

- (void)addImageStoryItemForCurrentUser:(UIImage *)image
                              completion:(PPStoriesWriteCompletion _Nullable)completion
{
    if (![image isKindOfClass:UIImage.class]) {
        if (completion) {
            completion([NSError errorWithDomain:@"PPStories"
                                           code:1001
                                       userInfo:@{NSLocalizedDescriptionKey: @"Invalid story image."}]);
        }
        return;
    }

    NSString *authUID = PPStoriesTrimmedString([FIRAuth auth].currentUser.uid);
    NSString *currentUserID = authUID.length > 0
        ? authUID
        : PPStoriesTrimmedString([UserManager sharedManager].currentUser.ID);
    if (currentUserID.length == 0) {
        if (completion) {
            completion([NSError errorWithDomain:@"PPStories"
                                           code:1002
                                       userInfo:@{NSLocalizedDescriptionKey: @"Current user is not available."}]);
        }
        return;
    }

    __weak typeof(self) weakSelf = self;
    [GM uploadImageToStories:image completion:^(NSURL * _Nullable url) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        if (![url isKindOfClass:NSURL.class] || url.absoluteString.length == 0) {
            if (completion) {
                completion([NSError errorWithDomain:@"PPStories"
                                               code:1003
                                           userInfo:@{NSLocalizedDescriptionKey: @"Failed to upload story media."}]);
            }
            return;
        }

        FIRDocumentReference *docRef = [[self.db collectionWithPath:PPStoriesCollectionPath]
                                        documentWithPath:currentUserID];
        [docRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
            if (error) {
                if (completion) {
                    completion(error);
                }
                return;
            }

            UserModel *currentUser = [UserManager sharedManager].currentUser;
            NSString *bestName = PPStoriesTrimmedString([currentUser PPBestDisplayName]);
            NSString *fallbackName = PPStoriesTrimmedString([FIRAuth auth].currentUser.displayName);
            NSString *resolvedName = bestName.length > 0 ? bestName : fallbackName;
            if (resolvedName.length == 0) {
                resolvedName = @"You";
            }

            NSString *photoURLString = PPStoriesTrimmedString(currentUser.UserImageUrl.absoluteString);
            if (photoURLString.length == 0) {
                photoURLString = PPStoriesTrimmedString([FIRAuth auth].currentUser.photoURL.absoluteString);
            }

            NSMutableArray *items = [NSMutableArray array];
            NSArray *existingItems = [snapshot.data[@"items"] isKindOfClass:NSArray.class] ? snapshot.data[@"items"] : @[];
            for (id rawItem in existingItems) {
                if ([rawItem isKindOfClass:NSDictionary.class]) {
                    [items addObject:rawItem];
                }
            }
            [items addObject:@{
                @"mediaUrl": url.absoluteString ?: @"",
                @"mediaType": @"image",
                @"duration": @5
            }];

            NSMutableDictionary *payload = [NSMutableDictionary dictionary];
            payload[@"userName"] = resolvedName;
            payload[@"isSeen"] = @(NO);
            payload[@"updatedAt"] = [FIRTimestamp timestampWithDate:[NSDate date]];
            payload[@"items"] = items;
            payload[@"viewedBy"] = @[currentUserID];
            if (!snapshot.exists) {
                payload[@"createdAt"] = [FIRTimestamp timestampWithDate:[NSDate date]];
            }
            if (photoURLString.length > 0) {
                payload[@"userImageUrl"] = photoURLString;
            }

            [docRef setData:payload merge:YES completion:^(NSError * _Nullable writeError) {
                if (completion) {
                    completion(writeError);
                }
            }];
        }];
    }];
}

- (FIRQuery *)pp_storiesQuery
{
    FIRTimestamp *cutoff = [FIRTimestamp timestampWithDate:
        [[NSDate date] dateByAddingTimeInterval:-PPStoryExpiryInterval]];
    return [[[[self.db collectionWithPath:PPStoriesCollectionPath]
              queryWhereField:@"updatedAt" isGreaterThan:cutoff]
             queryOrderedByField:@"updatedAt"
             descending:YES] queryLimitedTo:200];
}

- (NSArray<PPStory *> *)pp_storiesFromSnapshot:(FIRQuerySnapshot *)snapshot
{
    NSMutableArray<PPStory *> *result = [NSMutableArray array];
    for (FIRDocumentSnapshot *doc in snapshot.documents) {
        PPStory *story = [self pp_storyFromDocument:doc];
        if (story && story.items.count > 0) {
            [result addObject:story];
        }
    }
    return result.copy;
}

- (PPStory *)pp_storyFromDocument:(FIRDocumentSnapshot *)doc
{
    if (![doc isKindOfClass:[FIRDocumentSnapshot class]] || !doc.exists) {
        return nil;
    }
    NSDictionary *data = doc.data;
    if (![data isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    PPStory *story = [PPStory new];
    story.userID = doc.documentID ?: @"";
    story.userName = [data[@"userName"] isKindOfClass:[NSString class]] ? data[@"userName"] : @"";

    NSString *urlStr = [data[@"userImageUrl"] isKindOfClass:[NSString class]] ? data[@"userImageUrl"] : @"";
    if (urlStr.length > 0) {
        story.userImageURL = [NSURL URLWithString:urlStr];
    }

    story.isSeen = [data[@"isSeen"] boolValue];
    id ts = data[@"updatedAt"];
    if ([ts isKindOfClass:[FIRTimestamp class]]) {
        story.updatedAt = [(FIRTimestamp *)ts dateValue];
    } else if ([ts isKindOfClass:[NSDate class]]) {
        story.updatedAt = (NSDate *)ts;
    }

    id createdTs = data[@"createdAt"];
    if ([createdTs isKindOfClass:[FIRTimestamp class]]) {
        story.createdAt = [(FIRTimestamp *)createdTs dateValue];
    }

    NSArray *viewedByRaw = [data[@"viewedBy"] isKindOfClass:NSArray.class] ? data[@"viewedBy"] : @[];
    NSMutableSet<NSString *> *viewedBySet = [NSMutableSet set];
    for (id uid in viewedByRaw) {
        if ([uid isKindOfClass:NSString.class] && [(NSString *)uid length] > 0) {
            [viewedBySet addObject:uid];
        }
    }
    story.viewedBy = [viewedBySet copy];

    NSString *currentUID = PPStoriesTrimmedString([FIRAuth auth].currentUser.uid);
    if (currentUID.length > 0 && story.viewedBy.count > 0) {
        story.isSeen = [story.viewedBy containsObject:currentUID];
    }

    NSMutableArray<PPStoryItem *> *items = [NSMutableArray array];
    NSArray *rawItems = [data[@"items"] isKindOfClass:[NSArray class]] ? data[@"items"] : @[];
    for (NSDictionary *itemDict in rawItems) {
        if (![itemDict isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSString *mediaURLString = [itemDict[@"mediaUrl"] isKindOfClass:[NSString class]] ? itemDict[@"mediaUrl"] : @"";
        if (mediaURLString.length == 0) {
            continue;
        }
        NSURL *mediaURL = [NSURL URLWithString:mediaURLString];
        if (!mediaURL) {
            continue;
        }
        PPStoryItem *item = [PPStoryItem new];
        item.mediaURL = mediaURL;
        NSString *mediaType = [itemDict[@"mediaType"] isKindOfClass:[NSString class]] ? itemDict[@"mediaType"] : @"";
        item.isVideo = [mediaType.lowercaseString isEqualToString:@"video"];
        item.duration = [itemDict[@"duration"] respondsToSelector:@selector(doubleValue)] ? [itemDict[@"duration"] doubleValue] : 5.0;
        if (item.duration <= 0.0 || !isfinite(item.duration)) {
            item.duration = 5.0;
        }
        [items addObject:item];
    }
    story.items = items;
    return story;
}

@end
