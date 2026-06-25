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

static NSError *PPStoriesError(NSInteger code, NSString *message)
{
    return [NSError errorWithDomain:@"PPStories"
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @""}];
}

static void PPStoriesCompleteUpdate(PPStoriesUpdateCompletion completion,
                                    PPStoryItem * _Nullable item,
                                    NSError * _Nullable error)
{
    if (!completion) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(item, error);
    });
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
    [GM uploadImageToStories:image forUserID:currentUserID completion:^(NSURL * _Nullable url) {
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

- (void)updateStoryItemForCurrentUserWithStoryID:(NSString *)storyID
                                       itemIndex:(NSInteger)itemIndex
                                         caption:(NSString * _Nullable)caption
                                        newImage:(UIImage * _Nullable)newImage
                                      completion:(PPStoriesUpdateCompletion _Nullable)completion
{
    NSString *authUID = PPStoriesTrimmedString([FIRAuth auth].currentUser.uid);
    NSString *trimmedStoryID = PPStoriesTrimmedString(storyID);
    if (authUID.length == 0) {
        PPStoriesCompleteUpdate(completion, nil, PPStoriesError(1004, @"Current user is not authenticated."));
        return;
    }
    if (trimmedStoryID.length == 0 || ![trimmedStoryID isEqualToString:authUID]) {
        PPStoriesCompleteUpdate(completion, nil, PPStoriesError(1005, @"You can edit only your own stories."));
        return;
    }
    if (itemIndex < 0) {
        PPStoriesCompleteUpdate(completion, nil, PPStoriesError(1006, @"Story item is invalid."));
        return;
    }

    __weak typeof(self) weakSelf = self;
    void (^patchStory)(NSString * _Nullable) = ^(NSString * _Nullable mediaURLString) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        [self pp_patchStoryWithStoryID:trimmedStoryID
                              itemIndex:itemIndex
                                caption:caption
                         mediaURLString:mediaURLString
                             completion:completion];
    };

    if ([newImage isKindOfClass:UIImage.class]) {
        [GM uploadImageToStories:newImage forUserID:authUID completion:^(NSURL * _Nullable url) {
            if (![url isKindOfClass:NSURL.class] || url.absoluteString.length == 0) {
                PPStoriesCompleteUpdate(completion, nil, PPStoriesError(1007, @"Failed to upload story media."));
                return;
            }
            patchStory(url.absoluteString);
        }];
        return;
    }

    patchStory(nil);
}

- (void)deleteStoryItemForCurrentUserWithStoryID:(NSString *)storyID
                                       itemIndex:(NSInteger)itemIndex
                                      completion:(PPStoriesWriteCompletion _Nullable)completion
{
    NSString *authUID = PPStoriesTrimmedString([FIRAuth auth].currentUser.uid);
    NSString *trimmedStoryID = PPStoriesTrimmedString(storyID);
    if (authUID.length == 0) {
        if (completion) {
            completion(PPStoriesError(1013, @"Current user is not authenticated."));
        }
        return;
    }
    if (trimmedStoryID.length == 0 || ![trimmedStoryID isEqualToString:authUID]) {
        if (completion) {
            completion(PPStoriesError(1014, @"You can delete only your own stories."));
        }
        return;
    }
    if (itemIndex < 0) {
        if (completion) {
            completion(PPStoriesError(1015, @"Story item is invalid."));
        }
        return;
    }

    FIRDocumentReference *docRef = [[self.db collectionWithPath:@"stories"] documentWithPath:trimmedStoryID];
    [self.db runTransactionWithBlock:^id _Nullable(FIRTransaction * _Nonnull transaction, NSError * _Nullable __autoreleasing * _Nonnull errorPointer) {
        FIRDocumentSnapshot *snapshot = [transaction getDocument:docRef error:errorPointer];
        if (!snapshot || !snapshot.exists || *errorPointer) {
            return nil;
        }

        NSDictionary *data = [snapshot.data isKindOfClass:NSDictionary.class] ? snapshot.data : @{};
        NSArray *rawItems = [data[@"items"] isKindOfClass:NSArray.class] ? data[@"items"] : @[];
        if (itemIndex >= (NSInteger)rawItems.count) {
            if (errorPointer) {
                *errorPointer = PPStoriesError(1016, @"Story item was not found.");
            }
            return nil;
        }

        NSMutableArray *mutableItems = [rawItems mutableCopy] ?: [NSMutableArray array];
        [mutableItems removeObjectAtIndex:(NSUInteger)itemIndex];

        if (mutableItems.count == 0) {
            [transaction deleteDocument:docRef];
        } else {
            [transaction updateData:@{
                @"items": mutableItems,
                @"updatedAt": [FIRTimestamp timestampWithDate:[NSDate date]]
            } forDocument:docRef];
        }
        return nil;
    } completion:^(id  _Nullable result, NSError * _Nullable error) {
        (void)result;
        if (completion) {
            completion(error);
        }
    }];
}

- (void)pp_patchStoryWithStoryID:(NSString *)storyID
                        itemIndex:(NSInteger)itemIndex
                          caption:(NSString * _Nullable)caption
                   mediaURLString:(NSString * _Nullable)mediaURLString
                       completion:(PPStoriesUpdateCompletion _Nullable)completion
{
    NSString *encodedStoryID =
        [storyID stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet];
    NSURL *url = [NSURL URLWithString:
        [NSString stringWithFormat:@"https://us-central1-pure-pets-49199.cloudfunctions.net/stories/%@",
                                   encodedStoryID ?: @""]];
    if (!url) {
        PPStoriesCompleteUpdate(completion, nil, PPStoriesError(1008, @"Invalid story update URL."));
        return;
    }

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"itemIndex"] = @(itemIndex);
    payload[@"caption"] = PPStoriesTrimmedString(caption);
    if (PPStoriesTrimmedString(mediaURLString).length > 0) {
        payload[@"mediaUrl"] = PPStoriesTrimmedString(mediaURLString);
        payload[@"mediaType"] = @"image";
        payload[@"duration"] = @5;
    }

    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&jsonError];
    if (!jsonData || jsonError) {
        PPStoriesCompleteUpdate(completion, nil, jsonError ?: PPStoriesError(1009, @"Invalid story update payload."));
        return;
    }

    [[FIRAuth auth].currentUser getIDTokenWithCompletion:^(NSString * _Nullable idToken, NSError * _Nullable tokenError) {
        if (tokenError || idToken.length == 0) {
            PPStoriesCompleteUpdate(completion, nil, tokenError ?: PPStoriesError(1010, @"Missing auth token."));
            return;
        }

        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        request.HTTPMethod = @"PATCH";
        request.timeoutInterval = 24.0;
        request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        request.HTTPBody = jsonData;
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:[NSString stringWithFormat:@"Bearer %@", idToken] forHTTPHeaderField:@"Authorization"];

        NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
        NSURLSessionDataTask *task =
            [session dataTaskWithRequest:request
                        completionHandler:^(NSData * _Nullable data,
                                            NSURLResponse * _Nullable response,
                                            NSError * _Nullable error) {
            if (error) {
                PPStoriesCompleteUpdate(completion, nil, error);
                return;
            }

            NSHTTPURLResponse *http = [response isKindOfClass:NSHTTPURLResponse.class]
                ? (NSHTTPURLResponse *)response
                : nil;
            NSData *responseData = data ?: [NSData data];
            id resultObject = responseData.length > 0
                ? [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil]
                : nil;
            NSDictionary *result = [resultObject isKindOfClass:NSDictionary.class] ? resultObject : nil;

            if (http.statusCode >= 400) {
                NSString *message = [result isKindOfClass:NSDictionary.class]
                    ? (result[@"message"] ?: result[@"error"])
                    : nil;
                NSInteger statusCode = http ? http.statusCode : 1011;
                PPStoriesCompleteUpdate(completion, nil,
                                        PPStoriesError(statusCode,
                                                       message.length ? message : @"Failed to update story."));
                return;
            }

            NSDictionary *itemDict = [result[@"item"] isKindOfClass:NSDictionary.class] ? result[@"item"] : nil;
            PPStoryItem *updatedItem = [self pp_storyItemFromDictionary:itemDict];
            if (!updatedItem) {
                PPStoriesCompleteUpdate(completion, nil, PPStoriesError(1012, @"Story update response is invalid."));
                return;
            }
            PPStoriesCompleteUpdate(completion, updatedItem, nil);
        }];
        [task resume];
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
        PPStoryItem *item = [self pp_storyItemFromDictionary:itemDict];
        if (item) [items addObject:item];
    }
    story.items = items;
    return story;
}

- (PPStoryItem * _Nullable)pp_storyItemFromDictionary:(NSDictionary *)itemDict
{
    if (![itemDict isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSString *mediaURLString = [itemDict[@"mediaUrl"] isKindOfClass:[NSString class]] ? itemDict[@"mediaUrl"] : @"";
    if (mediaURLString.length == 0) {
        return nil;
    }

    NSURL *mediaURL = [NSURL URLWithString:mediaURLString];
    if (!mediaURL) {
        return nil;
    }

    PPStoryItem *item = [PPStoryItem new];
    item.mediaURL = mediaURL;
    NSString *mediaType = [itemDict[@"mediaType"] isKindOfClass:[NSString class]] ? itemDict[@"mediaType"] : @"";
    item.isVideo = [mediaType.lowercaseString isEqualToString:@"video"];
    item.duration = [itemDict[@"duration"] respondsToSelector:@selector(doubleValue)] ? [itemDict[@"duration"] doubleValue] : 5.0;
    if (item.duration <= 0.0 || !isfinite(item.duration)) {
        item.duration = 5.0;
    }
    NSString *caption = [itemDict[@"caption"] isKindOfClass:NSString.class] ? itemDict[@"caption"] : @"";
    item.caption = PPStoriesTrimmedString(caption);
    return item;
}

@end
