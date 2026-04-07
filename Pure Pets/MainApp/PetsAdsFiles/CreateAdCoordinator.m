//
//  CreateAdCoordinator.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 10/01/2026.
//


#import "CreateAdCoordinator.h"
#import "AddNewAd.h"
#import "PetAdManager.h"
#import "UserManager.h"
@import FirebaseAuth;


@interface CreateAdCoordinator ()

@property (nonatomic, strong) UINavigationController *navigationController;
@property (nonatomic, strong) AddNewAd *viewController;

@property (nonatomic, strong, readwrite) PetAd *ad;
@property (nonatomic, assign, readwrite) AdEditorMode mode;

@end

@implementation CreateAdCoordinator

- (NSString *)pp_authenticatedOwnerID
{
    NSString *authUID = [[FIRAuth auth].currentUser.uid ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (authUID.length > 0) {
        return authUID;
    }
    return [[UserManager.sharedManager.currentUser.ID ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
}

- (void)pp_rollbackCreatedAdAfterError:(NSError *)error
{
    if (self.ad.adID.length == 0) {
        [self finishWithError:error];
        return;
    }

    [[PetAdManager sharedManager] deletePetAd:self.ad completion:^(NSError *cleanupError) {
        if (cleanupError) {
            NSLog(@"⚠️ CreateAdCoordinator rollback failed for %@: %@",
                  self.ad.adID,
                  cleanupError.localizedDescription ?: @"Unknown cleanup error");
        }
        [self finishWithError:error];
    }];
}

#pragma mark - Init

- (instancetype)initForCreate {
    self = [super init];
    if (self) {
        _mode = AdEditorModeCreate;
        _ad = [PetAd new];
    }
    return self;
}

- (instancetype)initForEdit:(PetAd *)ad {
    self = [super init];
    if (self) {
        _mode = AdEditorModeEdit;
        _ad =
        [[PetAd alloc] initWithDictionary:[ad toFirestoreDictionary]
                                documentID:ad.adID];
    }
    return self;
}


#pragma mark - Start

- (UIViewController *)start {

    self.viewController =
    [[AddNewAd alloc] initWithCoordinator:self];

    self.viewController.mode = self.mode;
    self.viewController.initialAd = self.ad;

    self.navigationController =
    [[UINavigationController alloc]
     initWithRootViewController:self.viewController];

    return self.navigationController;
}

#pragma mark - Draft Updates (from VC)

- (void)updateDraft:(PetAd *)draft {
    if (!draft) return;
    self.ad = draft;
}

#pragma mark - Submit Flow (ENTRY POINT)

- (void)submitWithImages:(NSArray<UIImage *> *)images {

    // 1️⃣ Apply defaults for CREATE
    if (self.mode == AdEditorModeCreate) {
        [self applyCreateDefaults];
    }

    // 2️⃣ Prepare search metadata ONLY
    [self prepareSearchMetadataForAd:self.ad];

    if (self.mode == AdEditorModeCreate && images.count > 0) {
        self.ad.imageItems = @[];
        [[PetAdManager sharedManager] addPetAd:self.ad completion:^(NSError *error) {
            if (error) {
                [self finishWithError:error];
                return;
            }

            [self uploadImages:images completion:^(NSError *uploadError) {
                if (uploadError) {
                    [self pp_rollbackCreatedAdAfterError:uploadError];
                    return;
                }

                [[PetAdManager sharedManager] updatePetAd:self.ad completion:^(NSError *updateError) {
                    if (updateError) {
                        [self pp_rollbackCreatedAdAfterError:updateError];
                        return;
                    }
                    [self finishSuccessfully];
                }];
            }];
        }];
        return;
    }

    // 3️⃣ Upload images (if any), then persist
    if (images.count > 0) {
        [self uploadImages:images completion:^(NSError *error) {
            if (error) {
                [self finishWithError:error];
                return;
            }
            [self persistAd];
        }];
    } else {
        // No images → persist directly
        [self persistAd];
    }
}

#pragma mark - Defaults

- (void)applyCreateDefaults {

    self.ad.adID = NSUUID.UUID.UUIDString;
    self.ad.postedDate = NSDate.date;
    self.ad.ownerID = [self pp_authenticatedOwnerID];

    self.ad.status = PetAdStatusActive;
    self.ad.visibility = PetAdVisibilityPublic;

    self.ad.favoritesCount = @(0);
    self.ad.sharesCount = @(0);

    self.ad.rankScore = @(0);
    self.ad.priorityScore = @(0);

    self.ad.isMine = YES;
    self.ad.isFavorite = NO;
}

#pragma mark - Search Metadata

- (void)prepareSearchMetadataForAd:(PetAd *)ad {

    // Lowercase title index
    //ad.name_lowercase = ad.adTitle.lowercaseString ?: @"";

    NSMutableSet *keywords = [NSMutableSet set];

    if (ad.adTitle.length) {
        NSArray *parts =
        [ad.adTitle.lowercaseString
         componentsSeparatedByCharactersInSet:
         NSCharacterSet.whitespaceAndNewlineCharacterSet];

        for (NSString *p in parts) {
            if (p.length > 1) {
                [keywords addObject:p];
            }
        }
    }

    if (ad.category > 0) {
        [keywords addObject:@(ad.category).stringValue];
    }

    ad.keywords = keywords.allObjects;
}
 

#pragma mark - Image Upload
- (void)uploadImages:(NSArray<UIImage *> *)images
          completion:(void (^)(NSError *error))completion
{
    if (images.count == 0) {
        if (completion) completion(nil);
        return;
    }

    FIRStorageReference *rootRef =
    [FIRStorage storage].reference;

    dispatch_group_t group = dispatch_group_create();
    NSMutableArray<PetImageItem *> *items =
    [NSMutableArray arrayWithCapacity:images.count];

    for (NSInteger i = 0; i < images.count; i++) {
        [items addObject:(id)kCFNull];
    }

    [images enumerateObjectsUsingBlock:^(UIImage *img, NSUInteger idx, BOOL *stop) {

        dispatch_group_enter(group);

        NSData *data = UIImageJPEGRepresentation(img, 0.75);
        if (!data) {
            dispatch_group_leave(group);
            return;
        }

        NSString *fileName =
        [NSString stringWithFormat:@"pet_ads/%@_%lu.jpg",
         self.ad.adID, (unsigned long)idx];

        FIRStorageReference *ref = [rootRef child:fileName];

        [ref putData:data metadata:nil completion:^(FIRStorageMetadata *metadata, NSError *error) {

            if (error) {
                dispatch_group_leave(group);
                return;
            }

            [ref downloadURLWithCompletion:^(NSURL *url, NSError *error2) {

                if (!url) {
                    dispatch_group_leave(group);
                    return;
                }

                // 🔑 Generate blurHash ONCE (correct place)
                NSString *blurHash =
                [PPBlurHashGenerator generateFrom:img];

                PetImageItem *item =
                [PetImageItem itemWithURL:url.absoluteString
                                    width:img.size.width
                                   height:img.size.height
                                 blurHash:blurHash];

                items[idx] = item;
                dispatch_group_leave(group);
            }];
        }];
    }];

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{

        NSMutableArray<PetImageItem *> *finalItems = [NSMutableArray array];
        for (id obj in items) {
            if ([obj isKindOfClass:PetImageItem.class]) {
                [finalItems addObject:obj];
            }
        }

        // 🔑 SINGLE SOURCE OF TRUTH
        self.ad.imageItems = finalItems;

        if (completion) completion(nil);
    });
}
#pragma mark - Persist

- (void)persistAd {

    if (self.mode == AdEditorModeEdit) {

        [[PetAdManager sharedManager]
         updatePetAd:self.ad
         completion:^(NSError *error) {
            if (error) {
                [self finishWithError:error];
                return;
            }
            [self finishSuccessfully];
        }];

    } else {

        [[PetAdManager sharedManager]
         addPetAd:self.ad
         completion:^(NSError *error) {
            if (error) {
                [self finishWithError:error];
                return;
            }
            [self finishSuccessfully];
        }];
    }
}

#pragma mark - Finish

- (void)finishSuccessfully {

    if (self.onFinish) {
        self.onFinish(self.ad);
    }

    [self.navigationController
     dismissViewControllerAnimated:YES
     completion:nil];
}

- (void)finishWithError:(NSError *)error {

    NSLog(@"❌ CreateAdCoordinator error: %@", error.localizedDescription);

    if (self.onFinish) {
        self.onFinish(nil);
    }
}

@end
