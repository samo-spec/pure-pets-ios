//
//  SplashViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 01/10/2025.
//

#import "SplashViewController.h"
#import <AVFoundation/AVFoundation.h>
 


@import FirebaseFirestore;

@interface SplashViewController ()
@property (nonatomic, assign) BOOL didShowMainVC;
- (nullable UIWindow *)pp_transitionWindow;
- (void)pp_swapRootViewController:(UIViewController *)rootViewController
                         onWindow:(UIWindow *)window;
@end

@implementation SplashViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"[Splash] viewDidLoad ✅");

    // Match LaunchScreen.storyboard background exactly (AppForegroundColor = white)
    self.view.backgroundColor = AppForgroundColr;

    // Background pattern (same as LaunchScreen: chat3 at 6% opacity)
    UIImage *patternImage = [[UIImage imageNamed:@"chat3"]
                             imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    if (patternImage) {
        UIImageView *patternView = [[UIImageView alloc] initWithImage:patternImage];
        patternView.contentMode = UIViewContentModeScaleToFill;
        patternView.tintColor = AppPrimaryClr;
        patternView.alpha = 0.06;
        patternView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addSubview:patternView];
        [NSLayoutConstraint activateConstraints:@[
            [patternView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
            [patternView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [patternView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
            [patternView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
        ]];
    }

    // Logo (same as LaunchScreen: newlogo, centered)
    UIImage *logoImage = [[UIImage imageNamed:@"newlogo"]
                          imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    if (logoImage) {
        UIImageView *logoView = [[UIImageView alloc] initWithImage:logoImage];
        logoView.contentMode = UIViewContentModeScaleAspectFit;
        logoView.tintColor = AppPrimaryClr;
        logoView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addSubview:logoView];
        [NSLayoutConstraint activateConstraints:@[
            [logoView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
            [logoView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:146],
            [logoView.widthAnchor constraintEqualToConstant:166],
            [logoView.heightAnchor constraintEqualToConstant:150]
        ]];
    }

    // Loading spinner below logo
    UIActivityIndicatorView *spinner;
    if (@available(iOS 13.0, *)) {
        spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        spinner.color = AppPrimaryClr;
    } else {
        spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    }
    spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:spinner];
    [NSLayoutConstraint activateConstraints:@[
        [spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [spinner.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:320]
    ]];
    [spinner startAnimating];

    // Copyright text (same as LaunchScreen)
    UILabel *copyrightLabel = [[UILabel alloc] init];
    copyrightLabel.text = @"Pure Pets © 2025 — All rights reserved.";
    copyrightLabel.textColor = [UIColor colorNamed:@"SecondaryTextColor"];
    copyrightLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    copyrightLabel.textAlignment = NSTextAlignmentCenter;
    copyrightLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:copyrightLabel];
    [NSLayoutConstraint activateConstraints:@[
        [copyrightLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [copyrightLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [copyrightLabel.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-34],
        [copyrightLabel.heightAnchor constraintEqualToConstant:45]
    ]];

    [PPHUD dismiss];
}
/*
 self.CardID = d[@"CardID"];
 self.UserID = d[@"UserID"];
 self.CageID = d[@"CageID"];
 */

- (void)normalizeArchivesIsDeleted
{
    FIRFirestore *db = [FIRFirestore firestore];

    NSLog(@"🚀 Starting ArchiveCol isDeleted normalization");

    [[db collectionWithPath:@"ArchiveCol"]
     getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot,
                                  NSError * _Nullable error)
    {
        if (error) {
            NSLog(@"❌ Failed to fetch ArchiveCol: %@", error);
            return;
        }

        NSArray<FIRDocumentSnapshot *> *docs = snapshot.documents;
        if (docs.count == 0) {
            NSLog(@"ℹ️ No archive documents found");
            return;
        }

        const NSInteger batchLimit = 450; // safe margin
        NSInteger totalUpdated = 0;

        for (NSInteger i = 0; i < docs.count; i += batchLimit) {

            FIRWriteBatch *batch = [db batch];
            NSRange range = NSMakeRange(i, MIN(batchLimit, docs.count - i));
            NSArray *chunk = [docs subarrayWithRange:range];

            for (FIRDocumentSnapshot *doc in chunk) {

                NSNumber *isDeleted = doc.data[@"isDeleted"];

                // Skip if already correct
                if ([isDeleted isKindOfClass:NSNumber.class] &&
                    isDeleted.integerValue == 0) {
                    continue;
                }

                FIRDocumentReference *ref =
                [[db collectionWithPath:@"ArchiveCol"]
                 documentWithPath:doc.documentID];

                [batch setData:@{ @"isDeleted": @0 }
                    forDocument:ref
                          merge:YES];

                totalUpdated++;
            }

            [batch commitWithCompletion:^(NSError * _Nullable error) {

                if (error) {
                    NSLog(@"❌ Batch commit failed: %@", error);
                } else {
                    NSLog(@"✅ Batch committed (%lu docs)",
                          (unsigned long)chunk.count);
                }
            }];
        }

        NSLog(@"🎯 ArchiveCol normalization completed. Updated: %ld",
              (long)totalUpdated);
    }];
}


- (void)migrateChildsArrayToSubcollectionOnce
{
    FIRFirestore *db = [FIRFirestore firestore];

    NSLog(@"🚀 Starting ChildsArray → ChildsCol migration");

    [[db collectionWithPath:@"CagesCol"]
     getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot,
                                  NSError * _Nullable error)
    {
        if (error) {
            NSLog(@"❌ Failed fetching cages: %@", error);
            return;
        }

        for (FIRDocumentSnapshot *cageDoc in snapshot.documents) {

            NSDictionary *cageData = cageDoc.data;
            NSArray *childsArray = cageData[@"ChildsArray"];

            if (![childsArray isKindOfClass:[NSArray class]] ||
                childsArray.count == 0) {
                continue;
            }

            FIRWriteBatch *batch = [db batch];
            NSInteger migratedCount = 0;

            for (NSDictionary *childDict in childsArray) {

                if (![childDict isKindOfClass:[NSDictionary class]]) continue;

                NSString *childID =
                childDict[@"ID"] ?: [[NSUUID UUID] UUIDString];

                FIRDocumentReference *childRef =
                [[[[db collectionWithPath:@"CagesCol"]
                   documentWithPath:cageDoc.documentID]
                  collectionWithPath:@"ChildsCol"]
                 documentWithPath:childID];

                NSMutableDictionary *safeData = [NSMutableDictionary dictionary];

                // Required
                safeData[@"ID"] = childID;
                safeData[@"CageID"] = childDict[@"CageID"] ?: cageDoc.documentID;
                safeData[@"CardID"] = childDict[@"CardID"] ?: @"";
                safeData[@"ChildRingID"] = childDict[@"ChildRingID"] ?: @"";
                safeData[@"UserID"] = cageData[@"UserID"] ?: @"";

                // Dates
                safeData[@"addingDate"] =
                childDict[@"addingDate"] ?: [NSDate date];

                safeData[@"lastUpdated"] =
                childDict[@"lastUpdated"] ?: [NSDate date];

                // Status
                safeData[@"isDeleted"] =
                childDict[@"isDeleted"] ?: @0;

                safeData[@"isSold"] =
                childDict[@"isSold"] ?: @0;

                // Archive (normalize)
                NSString *archiveID = childDict[@"archiveID"];
                safeData[@"archiveID"] =
                archiveID.length ? archiveID : @"";

                NSString *masterArchiveID = childDict[@"masterArchiveID"];
                safeData[@"masterArchiveID"] =
                masterArchiveID.length ? masterArchiveID : @"";

                // Movement defaults
                safeData[@"childBox"] =
                childDict[@"childBox"] ?: @(0);

                safeData[@"childBoxID"] =
                childDict[@"childBoxID"] ?: @"";

                safeData[@"cameFrom"] =
                childDict[@"cameFrom"] ?: @(0);

                // UPSERT (merge)
                [batch setData:safeData
                    forDocument:childRef
                          merge:YES];

                migratedCount++;
            }

            // Update childsCount ONLY from migrated data
            FIRDocumentReference *cageRef =
            [[db collectionWithPath:@"CagesCol"]
             documentWithPath:cageDoc.documentID];

            [batch updateData:@{
                @"childsCount": @(migratedCount)
            } forDocument:cageRef];

            // COMMIT PER CAGE
            [batch commitWithCompletion:^(NSError * _Nullable error) {

                if (error) {
                    NSLog(@"❌ Migration failed for cage %@: %@",
                          cageDoc.documentID, error);
                } else {
                    NSLog(@"✅ Cage %@ migrated (%ld childs)",
                          cageDoc.documentID, (long)migratedCount);
                }
            }];
        }
    }];
}


- (void)migrateArchiveDetails_Safe_NoDelete
{
    FIRFirestore *db = [FIRFirestore firestore];

    NSLog(@"🚨 STARTING SAFE ARCHIVE DETAILS MIGRATION (NO DELETE)");

    [[db collectionWithPath:@"ArchiveCol"]
     getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot,
                                  NSError * _Nullable error)
    {
        if (error) {
            NSLog(@"❌ Failed to fetch ArchiveCol: %@", error);
            return;
        }

        for (FIRDocumentSnapshot *archiveDoc in snapshot.documents)
        {
            NSDictionary *data = archiveDoc.data ?: @{};
            NSArray *oldDetails = data[@"archiveDetails"];

            if (![oldDetails isKindOfClass:[NSArray class]] || oldDetails.count == 0) {
                continue; // nothing to migrate
            }

            NSString *archiveID = archiveDoc.documentID;
            NSLog(@"🔄 Migrating archive (SAFE) %@", archiveID);

            FIRWriteBatch *batch = [db batch];
            NSInteger migratedCount = 0;

            for (NSDictionary *oldDetail in oldDetails)
            {
                if (![oldDetail isKindOfClass:[NSDictionary class]]) continue;

                NSString *detailID =
                oldDetail[@"ID"] ?: [NSUUID UUID].UUIDString;

                FIRDocumentReference *detailRef =
                [[archiveDoc.reference
                  collectionWithPath:@"ArchiveDetailsCol"]
                 documentWithPath:detailID];

                NSMutableDictionary *newDetail = [NSMutableDictionary dictionary];

                // ========= REQUIRED =========
                newDetail[@"ID"] = detailID;
                newDetail[@"masterArchiveID"] = archiveID;

                // ========= SAFE COPY =========
                if (oldDetail[@"CardID"])
                    newDetail[@"CardID"] = oldDetail[@"CardID"];

                if (oldDetail[@"UserID"])
                    newDetail[@"UserID"] = oldDetail[@"UserID"];

                if (oldDetail[@"CageID"])
                    newDetail[@"CageID"] = oldDetail[@"CageID"];

                // ========= FLAGS =========
                newDetail[@"CardInfo"] =
                oldDetail[@"CardInfo"] ?: @0;

                newDetail[@"isDeleted"] =
                oldDetail[@"isDeleted"] ?: @0;

                newDetail[@"isSold"] =
                oldDetail[@"isSold"] ?: @0;

                // ========= DATES =========
                NSDate *cardArchiveDate = nil;

                id oldDate = oldDetail[@"cardArchiveDate"];
                if ([oldDate isKindOfClass:[NSDate class]]) {
                    cardArchiveDate = oldDate;
                } else if ([oldDate isKindOfClass:[FIRTimestamp class]]) {
                    cardArchiveDate = [(FIRTimestamp *)oldDate dateValue];
                } else if ([data[@"archiveDate"] isKindOfClass:[NSDate class]]) {
                    cardArchiveDate = data[@"archiveDate"];
                } else {
                    cardArchiveDate = [NSDate date];
                }

                newDetail[@"cardArchiveDate"] =
                [FIRTimestamp timestampWithDate:cardArchiveDate];

                // lastUpdated — only add if missing
                newDetail[@"lastUpdated"] =
                [FIRTimestamp timestampWithDate:[NSDate date]];

                // ========= MERGE (CRITICAL) =========
                [batch setData:newDetail
                     forDocument:detailRef
                         merge:YES];

                migratedCount++;
            }

            // ========= UPDATE METADATA (NO DELETE) =========
            [batch updateData:@{
                @"detailsCount": @(migratedCount),
                @"lastUpdated": [FIRTimestamp timestampWithDate:[NSDate date]]
            } forDocument:archiveDoc.reference];

            // ========= COMMIT =========
            [batch commitWithCompletion:^(NSError * _Nullable error) {

                if (error) {
                    NSLog(@"❌ SAFE MIGRATION FAILED for %@: %@",
                          archiveID, error);
                } else {
                    NSLog(@"✅ SAFE MIGRATION DONE for %@ (%ld details)",
                          archiveID, (long)migratedCount);
                }
            }];
        }

        NSLog(@"🚨 SAFE MIGRATION LOOP FINISHED");
    }];
}

- (void)duplicateUserDocToCustomID {
    /*
    NSString *targetUID = @"wFiEt8lUWCQkcJE1K4DBHmUMZaD2";
    FIRFirestore *db = [FIRFirestore firestore];
    FIRCollectionReference *usersCol = [db collectionWithPath:@"UsersCol"];

    // 1️⃣ Find the existing document where uid == targetUID
    FIRQuery *query = [usersCol queryWhereField:@"uid" isEqualTo:targetUID];

    [query getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            NSLog(@"❌ Error fetching documents: %@", error.localizedDescription);
            return;
        }

        if (snapshot.documents.count == 0) {
            NSLog(@"⚠️ No document found for uid %@", targetUID);
            return;
        }

        NSLog(@"✅ Found %lu document(s) to duplicate", (unsigned long)snapshot.documents.count);

        // 2️⃣ Take the first document (assuming UID is unique)
        FIRDocumentSnapshot *sourceDoc = snapshot.documents.firstObject;
        NSDictionary *data = sourceDoc.data;

        // 3️⃣ Add or update a new document with custom ID = targetUID
        FIRDocumentReference *newDocRef = [usersCol documentWithPath:targetUID];
        [newDocRef setData:data completion:^(NSError * _Nullable err) {
            if (err) {
                NSLog(@"❌ Failed to create new document: %@", err.localizedDescription);
            } else {
                NSLog(@"🔥 Successfully created new document with ID %@", targetUID);
            }
        }];
    }]; */
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [PPHUD dismiss];
}

-(void)dealloc
{
    [PPHUD dismiss];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    NSLog(@"[Splash] viewDidAppear - start data loading");
    //[self duplicateUserDocToCustomID];
    [self startInitialDataLoad];
}

#pragma mark - 🔹 Data Loading Sequence

- (void)startInitialDataLoad {
    if (self.didShowMainVC) {
        NSLog(@"[Splash] ⚠️ Already transitioned once, skipping duplicate load.");
        return;
    }

    //[self showLoadingAnimation];

    dispatch_group_t group = dispatch_group_create();

    __block BOOL mainKindsLoaded = NO;
    __block BOOL bannersLoaded = NO;

    __block BOOL didLeaveKindsGroup = NO;
    dispatch_group_enter(group);
    [PPMainKindsManager loadMainDataCompletionHandler:^(int result) {
        if (didLeaveKindsGroup) return;
        didLeaveKindsGroup = YES;

        NSLog(@"[Splash] ✅ MainKinds loaded (result = %d)", result);
        mainKindsLoaded = YES;
        dispatch_group_leave(group);
    }];

    __block BOOL didLeaveBannerGroup = NO;
    
    dispatch_group_enter(group);
    
    if(PPBannersManager.sharedManager.bannerGroups.count > 0)
    {
        NSLog(@"[PPBannersManager] ✅ LOADED BEFORE");

        bannersLoaded = YES;
        dispatch_group_leave(group);
    }
    else
    {
        [[PPBannersManager sharedManager] fetchBannersOnceWithCompletion:^(NSArray<MainBannerModel *> * _Nullable bannerGroups, NSError * _Nullable error) {
            if (didLeaveBannerGroup) return; // 🚫 prevents double leave
            didLeaveBannerGroup = YES;
            
            if (error) {
                NSLog(@"[Splash] ⚠️ Error fetching banners: %@", error.localizedDescription);
            } else {
                NSLog(@"[Splash] ✅ Banners fetched: %lu items", (unsigned long)bannerGroups.count);
                bannersLoaded = YES;
            }
            dispatch_group_leave(group);
        }];
    }
    


    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        // ✅ Only transition once
        if (self.didShowMainVC) return;
        self.didShowMainVC = YES;

        NSLog(@"[Splash] 🎬 All data loaded (MainKinds=%@, Banners=%@)",
              mainKindsLoaded ? @"✅" : @"❌",
              bannersLoaded ? @"✅" : @"❌");

        [self transitionToMainApp];
    });
}


#pragma mark - 🔹 Transition to Main App

- (void)transitionToMainApp {
    
    NSLog(@"[Splash] 🚀 Transitioning to main AppVC");
    LastBoot lastBoot = LastBootAppVC;
    if([[NSUserDefaults standardUserDefaults] integerForKey:@"lastBoot"])
    {
        lastBoot = [[NSUserDefaults standardUserDefaults] integerForKey:@"lastBoot"];
    }
    lastBoot = LastBootOneUI;
    [[NSUserDefaults standardUserDefaults] setInteger:LastBootOneUI forKey:@"lastBoot"];

    PPRootTabBarController *rootVC =  [[PPRootTabBarController alloc] init];
    rootVC.view.semanticContentAttribute = GM.setSemantic;

    UIWindow *window = [self pp_transitionWindow];
    if (!window) {
        NSLog(@"[Splash] ❌ Failed to locate the active window for root transition");
        return;
    }

    [self pp_swapRootViewController:rootVC onWindow:window];
}

- (nullable UIWindow *)pp_transitionWindow
{
    UIWindow *window = self.view.window;
    if (window) {
        return window;
    }

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) {
                continue;
            }

            UIWindowScene *windowScene = (UIWindowScene *)scene;
            if (windowScene.activationState != UISceneActivationStateForegroundActive &&
                windowScene.activationState != UISceneActivationStateForegroundInactive) {
                continue;
            }

            for (UIWindow *candidate in windowScene.windows) {
                if (candidate.isKeyWindow) {
                    return candidate;
                }
            }

            if (windowScene.windows.firstObject) {
                return windowScene.windows.firstObject;
            }
        }
    }

    for (UIWindow *candidate in UIApplication.sharedApplication.windows) {
        if (candidate.isKeyWindow) {
            return candidate;
        }
    }

    UIWindow *fallback = UIApplication.sharedApplication.windows.firstObject;
    if (!fallback) {
        NSLog(@"❌ SplashVC: no UIWindow available");
    }
    return fallback;
}

- (void)pp_swapRootViewController:(UIViewController *)rootViewController
                         onWindow:(UIWindow *)window
{
    window.semanticContentAttribute = GM.setSemantic;

    [UIView transitionWithView:window
                      duration:0.35
                       options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowAnimatedContent
                    animations:^{
        BOOL previousAnimationState = [UIView areAnimationsEnabled];
        [UIView setAnimationsEnabled:NO];
        window.rootViewController = rootViewController;
        [window makeKeyAndVisible];
        [window layoutIfNeeded];
        [UIView setAnimationsEnabled:previousAnimationState];
    } completion:nil];
}

#pragma mark - 🔹 Optional: Video Background Setup
 

#pragma mark - 🔹 Optional: Loading Indicator

- (void)showLoadingAnimation {
    UILabel *loadingLabel = [[UILabel alloc] init];
    loadingLabel.text = @"Loading...";
    loadingLabel.textColor = UIColor.whiteColor;
    loadingLabel.font = [UIFont boldSystemFontOfSize:18];
    loadingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:loadingLabel];

    [NSLayoutConstraint activateConstraints:@[
        [loadingLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [loadingLabel.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-80]
    ]];

    loadingLabel.alpha = 0;
    [UIView animateWithDuration:0.5 delay:0 options:UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat animations:^{
        loadingLabel.alpha = 1.0;
    } completion:nil];
}

@end
