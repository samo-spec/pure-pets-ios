//
//  AdoptPetManager.m
//  Pure Pets
//
//  Compatibility facade for the canonical Community backend. The legacy
//  public API is retained for Objective-C callers, but protected Community
//  records are read and mutated only through Cloud Functions.
//

#import "AdoptPetManager.h"
#import "AdoptPetModel.h"
#import "Language.h"

@import FirebaseAuth;
@import FirebaseFirestore;
@import FirebaseFunctions;

static NSString * const PPCommunityManagerErrorDomain = @"com.purepets.community";

@interface PPAdoptPetsRefreshToken : NSObject <FIRListenerRegistration>
@property (atomic, assign, getter=isCancelled) BOOL cancelled;
@end

@implementation PPAdoptPetsRefreshToken
- (void)remove { self.cancelled = YES; }
@end

@interface AdoptPetManager ()
@property (nonatomic, strong) FIRFunctions *functions;
@end

@implementation AdoptPetManager

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    static AdoptPetManager *manager = nil;
    dispatch_once(&onceToken, ^{
        manager = [[AdoptPetManager alloc] init];
    });
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _functions = [FIRFunctions functionsForRegion:@"us-central1"];
    }
    return self;
}

#pragma mark - Canonical reads

- (id<FIRListenerRegistration>)observeAllPetsWithUpdate:(AdoptPetListenerHandle)completion {
    PPAdoptPetsRefreshToken *token = [PPAdoptPetsRefreshToken new];
    [self pp_call:@"communityBrowse"
          payload:@{ @"action": @"adoption_discovery", @"limit": @50 }
       completion:^(NSDictionary * _Nullable data, NSError * _Nullable error) {
        if (token.isCancelled || !completion) return;
        completion(error ? @[] : [self pp_modelsFromItems:data[@"items"]], error);
    }];
    return token;
}

- (void)fetchPetsForUserID:(NSString *)userID completion:(AdoptPetArrayCompletion)completion {
    NSString *currentUID = FIRAuth.auth.currentUser.uid ?: @"";
    if (userID.length == 0 || ![userID isEqualToString:currentUID]) {
        if (completion) completion(@[], nil);
        return;
    }
    [self pp_call:@"communityBrowse"
          payload:@{ @"action": @"my_activity", @"limit": @50 }
       completion:^(NSDictionary * _Nullable data, NSError * _Nullable error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        NSDictionary *activity = [data[@"activity"] isKindOfClass:NSDictionary.class] ? data[@"activity"] : @{};
        if (completion) completion([self pp_modelsFromItems:activity[@"adoptionListings"]], nil);
    }];
}

- (void)fetchPetsWithIDs:(NSArray<NSString *> *)ids completion:(AdoptPetArrayCompletion)completion {
    NSMutableOrderedSet<NSString *> *orderedIDs = [NSMutableOrderedSet orderedSet];
    for (id raw in ids) {
        if ([raw isKindOfClass:NSString.class] && [raw length] > 0) [orderedIDs addObject:raw];
    }
    if (orderedIDs.count == 0) {
        if (completion) completion(@[], nil);
        return;
    }

    dispatch_group_t group = dispatch_group_create();
    NSMutableDictionary<NSString *, AdoptPetModel *> *models = [NSMutableDictionary dictionary];
    __block NSError *firstError = nil;
    for (NSString *identifier in orderedIDs.array) {
        dispatch_group_enter(group);
        [self pp_call:@"communityBrowse"
              payload:@{ @"action": @"adoption_detail", @"id": identifier }
           completion:^(NSDictionary * _Nullable data, NSError * _Nullable error) {
            if (error) {
                @synchronized (models) { if (!firstError) firstError = error; }
            } else if ([data[@"item"] isKindOfClass:NSDictionary.class]) {
                AdoptPetModel *model = [[AdoptPetModel alloc] initWithDictionary:data[@"item"] documentID:identifier];
                @synchronized (models) { models[identifier] = model; }
            }
            dispatch_group_leave(group);
        }];
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSMutableArray<AdoptPetModel *> *result = [NSMutableArray array];
        for (NSString *identifier in orderedIDs.array) {
            AdoptPetModel *model = models[identifier];
            if (model) [result addObject:model];
        }
        if (completion) completion(result.copy, result.count == 0 ? firstError : nil);
    });
}

#pragma mark - Server-owned transitions

- (void)deletePetWithID:(NSString *)documentID completion:(AdoptPetCompletion)completion {
    [self pp_transitionListing:documentID action:@"archive" visibility:nil completion:completion];
}

- (void)updatePetVisibilityWithID:(NSString *)documentID
                       visibility:(NSInteger)visibility
                       completion:(AdoptPetCompletion)completion {
    [self pp_transitionListing:documentID
                        action:(visibility == 0 ? @"resume" : @"pause")
                    visibility:@(visibility)
                    completion:completion];
}

- (void)pp_transitionListing:(NSString *)documentID
                       action:(NSString *)action
                   visibility:(NSNumber * _Nullable)visibility
                   completion:(AdoptPetCompletion)completion {
    if (documentID.length == 0) {
        if (completion) completion(NO, [self pp_errorWithCode:400 key:@"community_error_invalid_record"]);
        return;
    }
    [self pp_call:@"communityBrowse"
          payload:@{ @"action": @"adoption_detail", @"id": documentID }
       completion:^(NSDictionary * _Nullable data, NSError * _Nullable readError) {
        if (readError) {
            if (completion) completion(NO, readError);
            return;
        }
        NSDictionary *item = [data[@"item"] isKindOfClass:NSDictionary.class] ? data[@"item"] : @{};
        NSInteger version = [item[@"version"] respondsToSelector:@selector(integerValue)] ? [item[@"version"] integerValue] : 0;
        NSString *status = [item[@"status"] isKindOfClass:NSString.class] ? item[@"status"] : @"";
        if (visibility != nil) {
            if (visibility.integerValue == 0 && [status isEqualToString:@"published"]) {
                if (completion) completion(YES, nil);
                return;
            }
            if (visibility.integerValue != 0 && [status isEqualToString:@"paused"]) {
                if (completion) completion(YES, nil);
                return;
            }
        }
        if (version < 1 || action.length == 0) {
            if (completion) completion(NO, [self pp_errorWithCode:409 key:@"community_error_refresh_required"]);
            return;
        }
        [self pp_call:@"transitionAdoptionListing"
              payload:@{
                  @"commandId": [self pp_commandID:@"adoption-transition"],
                  @"listingId": documentID,
                  @"expectedVersion": @(version),
                  @"action": action
              }
           completion:^(__unused NSDictionary * _Nullable result, NSError * _Nullable transitionError) {
            if (completion) completion(transitionError == nil, transitionError);
        }];
    }];
}

#pragma mark - Retained legacy signatures

- (void)createPet:(AdoptPetModel *)model
           images:(NSArray<UIImage *> *)images
       completion:(AdoptPetCreateCompletion)completion {
    (void)model;
    (void)images;
    if (completion) {
        completion(NO, nil, [self pp_errorWithCode:426 key:@"community_error_secure_form_required"]);
    }
}

- (void)updatePetWithID:(NSString *)documentID
                   data:(NSDictionary *)data
             completion:(AdoptPetCompletion)completion {
    (void)documentID;
    (void)data;
    if (completion) completion(NO, [self pp_errorWithCode:426 key:@"community_error_secure_form_required"]);
}

- (void)updatePet:(AdoptPetModel *)model
           images:(NSArray<UIImage *> *)images
       completion:(AdoptPetCompletion)completion {
    (void)model;
    (void)images;
    if (completion) completion(NO, [self pp_errorWithCode:426 key:@"community_error_secure_form_required"]);
}

#pragma mark - Helpers

- (void)pp_call:(NSString *)name
         payload:(NSDictionary *)payload
      completion:(void (^)(NSDictionary * _Nullable data, NSError * _Nullable error))completion {
    FIRHTTPSCallable *callable = [self.functions HTTPSCallableWithName:name];
    callable.timeoutInterval = 45.0;
    [callable callWithObject:payload ?: @{} completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        NSDictionary *dictionary = [result.data isKindOfClass:NSDictionary.class] ? result.data : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *resolvedError = error ?: (dictionary ? nil : [self pp_errorWithCode:500 key:@"community_error_invalid_response"]);
            if (completion) completion(dictionary, resolvedError);
        });
    }];
}

- (NSArray<AdoptPetModel *> *)pp_modelsFromItems:(id)rawItems {
    NSArray *items = [rawItems isKindOfClass:NSArray.class] ? rawItems : @[];
    NSMutableArray<AdoptPetModel *> *models = [NSMutableArray arrayWithCapacity:items.count];
    for (id raw in items) {
        if (![raw isKindOfClass:NSDictionary.class]) continue;
        NSString *identifier = [raw[@"id"] isKindOfClass:NSString.class] ? raw[@"id"] : @"";
        AdoptPetModel *model = [[AdoptPetModel alloc] initWithDictionary:raw documentID:identifier];
        if (model.documentID.length > 0) [models addObject:model];
    }
    return models.copy;
}

- (NSString *)pp_commandID:(NSString *)prefix {
    return [NSString stringWithFormat:@"ios-%@-%@", prefix, NSUUID.UUID.UUIDString.lowercaseString];
}

- (NSError *)pp_errorWithCode:(NSInteger)code key:(NSString *)key {
    NSString *message = [Language get:key alter:key] ?: key;
    return [NSError errorWithDomain:PPCommunityManagerErrorDomain
                               code:code
                           userInfo:@{ NSLocalizedDescriptionKey: message }];
}

@end

