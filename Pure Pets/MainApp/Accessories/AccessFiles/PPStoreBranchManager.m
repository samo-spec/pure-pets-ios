//
//  PPStoreBranchManager.m
//  Pure Pets
//
//  Single source of truth for the active consumer store branch in Pure Pets iOS.
//

#import "PPStoreBranchManager.h"
#import <FirebaseFirestore/FirebaseFirestore.h>
#import "Language.h"

NSString * const PPStoreBranchDidChangeNotification = @"PPStoreBranchDidChangeNotification";

@interface PPStoreBranchManager ()

@property (nonatomic, copy, readwrite) NSString *currentBranchId;
@property (nonatomic, copy, readwrite) NSString *currentBranchNameAr;
@property (nonatomic, copy, readwrite) NSString *currentBranchNameEn;
@property (nonatomic, copy, readwrite) NSString *currentBranchCode;
@property (nonatomic, assign, readwrite) BOOL isConfigLoaded;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> configListener;

@end

@implementation PPStoreBranchManager

+ (instancetype)sharedManager {
    static PPStoreBranchManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[PPStoreBranchManager alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _currentBranchId = @"";
        _currentBranchNameAr = @"";
        _currentBranchNameEn = @"";
        _currentBranchCode = @"";
        _isConfigLoaded = NO;
        [self startObservingStoreBranch];
    }
    return self;
}

- (void)startObservingStoreBranch {
    if (self.configListener) return;

    FIRDocumentReference *docRef = [[[FIRFirestore firestore] collectionWithPath:@"AppConfigCol"] documentWithPath:@"ConsumerStockConfig"];
    __weak typeof(self) weakSelf = self;

    self.configListener = [docRef addSnapshotListener:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (error != nil) {
            NSLog(@"[PPStoreBranchManager] ConsumerStockConfig listen note: %@", error.localizedDescription);
            return;
        }

        if (snapshot && snapshot.exists) {
            NSDictionary *data = snapshot.data ?: @{};
            NSString *bId = data[@"branchId"] ?: data[@"activeConsumerBranchId"] ?: @"";
            NSString *nAr = data[@"nameAr"] ?: data[@"activeConsumerBranchNameAr"] ?: @"";
            NSString *nEn = data[@"nameEn"] ?: data[@"activeConsumerBranchNameEn"] ?: @"";
            NSString *bCode = data[@"branchCode"] ?: data[@"activeConsumerBranchCode"] ?: @"";

            BOOL branchChanged = ![strongSelf.currentBranchId isEqualToString:bId];

            strongSelf.currentBranchId = bId;
            strongSelf.currentBranchNameAr = nAr;
            strongSelf.currentBranchNameEn = nEn;
            strongSelf.currentBranchCode = bCode;
            strongSelf.isConfigLoaded = YES;

            if (branchChanged) {
                NSLog(@"[PPStoreBranchManager] Active store branch updated: %@ (%@)", nAr, bId);
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:PPStoreBranchDidChangeNotification
                                                                        object:strongSelf
                                                                      userInfo:@{@"branchId": bId, @"nameAr": nAr, @"nameEn": nEn}];
                });
            }
        }
    }];
}

- (void)stopObserving {
    if (self.configListener) {
        [self.configListener remove];
        self.configListener = nil;
    }
}

- (NSString *)localizedCurrentBranchName {
    if ([Language isRTL]) {
        return self.currentBranchNameAr.length ? self.currentBranchNameAr : (self.currentBranchNameEn.length ? self.currentBranchNameEn : self.currentBranchCode);
    } else {
        return self.currentBranchNameEn.length ? self.currentBranchNameEn : (self.currentBranchNameAr.length ? self.currentBranchNameAr : self.currentBranchCode);
    }
}

- (void)dealloc {
    [self stopObserving];
}

@end
