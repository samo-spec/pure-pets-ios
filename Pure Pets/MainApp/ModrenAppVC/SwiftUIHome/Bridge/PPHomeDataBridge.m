#import "PPHomeDataBridge.h"

#import <FirebaseAuth/FirebaseAuth.h>
#import <FirebaseFirestore/FirebaseFirestore.h>
@import FirebaseAuth;
#import <float.h>
#import <math.h>

#import "AppManager.h"
#import "AppClasses.h"
#import "GM.h"
#import "Language.h"
#import "MainKindsArrayManager.h"
#import "MainKindsModel.h"
#import "PetAccessory.h"
#import "PetAccessoryManager.h"
#import "PetAd.h"
#import "PetAdManager.h"
#import "PPBannersManager.h"
#import "PPOrder.h"
#import "PPPetProfile.h"
#import "PPPetProfileManager.h"
#import "PPPetReminder.h"
#import "PPUniversalCellViewModel.h"
#import "ServiceModel.h"
#import "ServicesManager.h"
#import "UserManager.h"

static NSError *PPHomeMissingSignalCategoryError(void) {
    return [NSError errorWithDomain:@"PPHomeMarketplaceSignals"
                               code:-1001
                           userInfo:@{
        NSLocalizedDescriptionKey: @"A selected main category is required for this count."
    }];
}

@interface PPHomeHeroAnimationView ()

@property (nonatomic, strong) LOTAnimationView *animationView;
@property (nonatomic, strong) UIImageView *fallbackImageView;
@property (nonatomic, strong) LOTColorValueCallback *colorValueCallback;
@property (nonatomic, copy) NSString *animationName;
@property (nonatomic, assign) BOOL loadsFromFirebase;
@property (nonatomic, assign) BOOL animationLoaded;
@property (nonatomic, assign) BOOL animationLoading;

- (BOOL)pp_usesExactStoragePathForAnimationName;
- (void)pp_loadExactStorageAnimation;
- (void)pp_applyCustomTintIfNeeded;

@end

@implementation PPHomeHeroAnimationView

- (instancetype)initWithFrame:(CGRect)frame
{
    return [self initWithAnimationName:@"Shop2.json"
                     loadsFromFirebase:NO];
}

- (instancetype)initWithAnimationName:(NSString *)animationName
                    loadsFromFirebase:(BOOL)loadsFromFirebase
{
    self = [super initWithFrame:CGRectZero];
    if (!self) {
        return nil;
    }
    _animationName = [animationName copy] ?: @"";
    _loadsFromFirebase = loadsFromFirebase;
    [self pp_buildMarketplaceAnimation];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (!self) {
        return nil;
    }
    _animationName = @"Shop2.json";
    _loadsFromFirebase = NO;
    [self pp_buildMarketplaceAnimation];
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.animationView stop];
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window) {
        [self pp_loadMarketplaceAnimationIfNeeded];
    }
    [self pp_updateMarketplacePlayback];
}

- (void)setPlaybackEnabled:(BOOL)playbackEnabled
{
    if (_playbackEnabled == playbackEnabled) {
        return;
    }
    _playbackEnabled = playbackEnabled;
    [self pp_updateMarketplacePlayback];
}

- (void)setCustomTintColor:(UIColor *)customTintColor
{
    _customTintColor = customTintColor;
    if (customTintColor) {
        self.animationView.tintColor = customTintColor;
        self.fallbackImageView.tintColor = customTintColor;
        [self pp_applyCustomTintIfNeeded];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        BOOL colorAppearanceChanged =
            [self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection];
        if (colorAppearanceChanged) {
            [self pp_applyCustomTintIfNeeded];
        }
    }
}

- (void)pp_buildMarketplaceAnimation
{
    self.backgroundColor = UIColor.clearColor;
    self.userInteractionEnabled = NO;
    self.isAccessibilityElement = NO;
    self.accessibilityElementsHidden = YES;
    _playbackEnabled = YES;

    UIImageSymbolConfiguration *configuration =
        [UIImageSymbolConfiguration configurationWithPointSize:42.0
                                                        weight:UIImageSymbolWeightSemibold];
    NSString *fallbackSymbol = @"storefront.fill";
    if ([self.animationName isEqualToString:@"HomePetPulse"]) {
        fallbackSymbol = @"pawprint.fill";
    } else if ([self.animationName isEqualToString:@"HomeCareReminder"] ||
               [self.animationName isEqualToString:@"Caretiming"]) {
        fallbackSymbol = @"bell.fill";
    } else if ([self.animationName isEqualToString:@"HomePromotionSpark"]) {
        fallbackSymbol = @"gift.fill";
    } else if ([self.animationName isEqualToString:@"Profile.lottie"]) {
        fallbackSymbol = @"person.crop.circle.fill";
    } else if ([self.animationName isEqualToString:@"PetMedicine"]) {
        fallbackSymbol = @"pills.fill";
    } else if ([self.animationName containsString:@"cart"] ||
               [self.animationName containsString:@"shop"] ||
               [self pp_isMarketplaceAnimationName]) {
        fallbackSymbol = @"bag.fill";
    }
    
    
    
    UIImage *fallbackImage =
        [UIImage systemImageNamed:fallbackSymbol
                withConfiguration:configuration];
    UIImageView *fallback = [[UIImageView alloc] initWithImage:fallbackImage];
    fallback.translatesAutoresizingMaskIntoConstraints = NO;
    fallback.contentMode = UIViewContentModeScaleAspectFit;
    fallback.tintColor = AppPrimaryClr ?: [GM appPrimaryColor] ?: UIColor.systemPinkColor;
    [self addSubview:fallback];
    self.fallbackImageView = fallback;

    LOTAnimationView *animation = [[LOTAnimationView alloc] init];
    animation.translatesAutoresizingMaskIntoConstraints = NO;
    animation.backgroundColor = UIColor.clearColor;
    animation.contentMode = UIViewContentModeScaleAspectFit;
    animation.loopAnimation = YES;
    animation.hidden = YES;
    [self addSubview:animation];
    self.animationView = animation;

    CGFloat inset = ([self.animationName isEqualToString:@"petstore"] || [self pp_isMarketplaceAnimationName]) ? 9.0 : -2.0;
    [NSLayoutConstraint activateConstraints:@[
        [fallback.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [fallback.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [fallback.widthAnchor constraintEqualToAnchor:self.widthAnchor multiplier:0.58],
        [fallback.heightAnchor constraintEqualToAnchor:self.heightAnchor multiplier:0.58],

        [animation.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:inset],
        [animation.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-inset],
        [animation.topAnchor constraintEqualToAnchor:self.topAnchor constant:inset],
        [animation.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-inset],
    ]];

    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserver:self
               selector:@selector(pp_marketplaceEnvironmentDidChange:)
                   name:UIApplicationDidBecomeActiveNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(pp_marketplaceEnvironmentDidChange:)
                   name:UIApplicationWillResignActiveNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(pp_marketplaceEnvironmentDidChange:)
                   name:UIAccessibilityReduceMotionStatusDidChangeNotification
                 object:nil];
}

- (void)pp_loadMarketplaceAnimationIfNeeded
{
    if (self.animationLoaded || self.animationLoading) {
        return;
    }

    self.animationLoading = YES;

    NSString *lowercaseExtension = self.animationName.pathExtension.lowercaseString;
    BOOL isDotLottieArchive = [lowercaseExtension isEqualToString:@"lottie"];
    LOTComposition *composition = nil;
    if (!isDotLottieArchive) {
        NSString *sansExt = [self.animationName stringByDeletingPathExtension];
        composition =
            [LOTComposition animationNamed:self.animationName inBundle:NSBundle.mainBundle] ?:
            [LOTComposition animationNamed:sansExt inBundle:NSBundle.mainBundle];
    }

    if (composition) {
        self.animationLoading = NO;
        self.animationLoaded = YES;
        [self.animationView setSceneModel:composition];
        [self pp_applyLoadedAnimationState];
        return;
    }

    NSString *storagePath = [self pp_usesExactStoragePathForAnimationName]
        ? self.animationName
        : [@"LottieAnimations" stringByAppendingPathComponent:[self.animationName stringByAppendingPathExtension:@"json"]];

    __weak typeof(self) weakSelf = self;
    [AppClasses fetchLottieJSONFromFirebasePath:storagePath
                                     completion:^(NSDictionary *jsonDict, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }

            strongSelf.animationLoading = NO;
            if (error || ![jsonDict isKindOfClass:NSDictionary.class]) {
                strongSelf.animationLoaded = NO;
                [strongSelf pp_applyLoadedAnimationState];
                return;
            }

            LOTComposition *loadedComp = [LOTComposition animationFromJSON:jsonDict];
            strongSelf.animationLoaded = loadedComp != nil;
            if (loadedComp) {
                [strongSelf.animationView setSceneModel:loadedComp];
            }
            [strongSelf pp_applyLoadedAnimationState];
        });
    }];
}

- (BOOL)pp_usesExactStoragePathForAnimationName
{
    NSString *safeName = self.animationName ?: @"";
    NSString *lowercaseName = safeName.lowercaseString;
    return [safeName containsString:@"/"] ||
        [lowercaseName hasSuffix:@".json"] ||
        [lowercaseName hasSuffix:@".lottie"];
}

- (void)pp_loadExactStorageAnimation
{
    [self pp_loadMarketplaceAnimationIfNeeded];
}

- (BOOL)pp_isMarketplaceAnimationName
{
    return [self.animationName.lastPathComponent.lowercaseString isEqualToString:@"shop2.json"];
}

- (BOOL)pp_isBagAnimationName
{
    return [self.animationName.lastPathComponent.lowercaseString isEqualToString:@"bag.json"];
}

- (void)pp_applyLoadedAnimationState
{
    self.animationView.hidden = !self.animationLoaded;
    self.fallbackImageView.hidden = self.animationLoaded;
    if (self.animationLoaded) {
        self.animationView.loopAnimation = YES;
        BOOL profileAnimation =
            [self.animationName isEqualToString:@"Profile.lottie"];
        BOOL marketplaceAnimation = [self pp_isMarketplaceAnimationName];
        BOOL bagAnimation = [self pp_isBagAnimationName];
        if (marketplaceAnimation) {
            self.animationView.animationSpeed = 0.60;
        } else if (profileAnimation || bagAnimation) {
            self.animationView.animationSpeed = 0.85;
        } else {
            self.animationView.animationSpeed =
                self.loadsFromFirebase ? 0.3 : 0.8;
        }
        self.animationView.animationProgress =
            (profileAnimation || marketplaceAnimation || bagAnimation)
                ? 0.0
                : 0.32;
        if (self.customTintColor) {
            self.animationView.tintColor = self.customTintColor;
            [self pp_applyCustomTintIfNeeded];
        }
    }
    [self pp_updateMarketplacePlayback];
}

- (void)pp_applyCustomTintIfNeeded
{
    BOOL isMarketplaceAnimation = [self pp_isMarketplaceAnimationName];
    if (!isMarketplaceAnimation ||
        !self.animationLoaded ||
        !self.customTintColor) {
        return;
    }

    UIColor *resolvedTint = self.customTintColor;
    if (@available(iOS 13.0, *)) {
        resolvedTint = [self.customTintColor resolvedColorWithTraitCollection:self.traitCollection];
    }
    self.animationView.tintColor = resolvedTint;

    LOTColorValueCallback *callback =
        [LOTColorValueCallback withCGColor:resolvedTint.CGColor];
    LOTKeypath *strokeColorKeypath =
        [LOTKeypath keypathWithString:@"**.Stroke 1.Color"];
    self.colorValueCallback = callback;
    [self.animationView setValueDelegate:callback
                              forKeypath:strokeColorKeypath];
}

- (void)pp_marketplaceEnvironmentDidChange:(NSNotification *)notification
{
    (void)notification;
    [self pp_updateMarketplacePlayback];
}

- (void)pp_updateMarketplacePlayback
{
    if (!self.animationLoaded) {
        return;
    }

    BOOL applicationActive =
        UIApplication.sharedApplication.applicationState ==
        UIApplicationStateActive;
    BOOL shouldPlay =
        self.playbackEnabled &&
        self.window != nil &&
        applicationActive &&
        !UIAccessibilityIsReduceMotionEnabled();

    if (shouldPlay) {
        if (!self.animationView.isAnimationPlaying) {
            [self.animationView play];
        }
    } else {
        [self.animationView stop];
        if (UIAccessibilityIsReduceMotionEnabled()) {
            self.animationView.animationProgress = 0.32;
        }
    }
}

@end

static NSString * const PPHomeBridgeConfigCacheKey = @"PPHomeConfig.cache.v1";
static NSString * const PPHomeBridgeConfigSectionsKey = @"sections";
static NSString * const PPHomeBridgeConfigTitleModeKey = @"titleViewMode";
static NSString * const PPHomeBridgeConfigPremiumCareVisibleKey = @"premiumCareVisible";
static NSString * const PPHomeBridgeConfigNovaFloatingVisibleKey = @"novaFloatingVisible";
static NSString * const PPHomeBridgeConfigBackgroundGlowsFadedKey = @"backgroundGlowsFaded";
static NSString * const PPHomeBridgeConfigNovaUseGenkitKey = @"novaUseGenkit";

static NSString * const PPHomeBridgeLatitudeKey = @"pp.home.nearby.latitude";
static NSString * const PPHomeBridgeLongitudeKey = @"pp.home.nearby.longitude";
static NSString * const PPHomeBridgeAreaNameKey = @"pp.home.nearby.areaName";
static NSString * const PPHomeBridgeManualSelectionKey = @"pp.home.nearby.manualSelection.v2";

static NSTimeInterval const PPHomeBridgeMinimumRefreshInterval = 1.2;
static CLLocationDistance const PPHomeBridgeLocationDistanceFilter = 75.0;
static CLLocationDistance const PPHomeBridgeNearbyRadiusKM = 8.0;
static NSInteger const PPHomeBridgeNearbyLimit = 30;
static NSInteger const PPHomeBridgeOrderLimit = 12;

static BOOL PPHomeBridgeBoolValue(id _Nullable value, BOOL fallback)
{
    if ([value isKindOfClass:NSNumber.class]) {
        return [(NSNumber *)value boolValue];
    }
    if (![value isKindOfClass:NSString.class]) {
        return fallback;
    }

    NSString *normalized =
        [[(NSString *)value
            stringByTrimmingCharactersInSet:
                NSCharacterSet.whitespaceAndNewlineCharacterSet]
            lowercaseString];
    if ([normalized isEqualToString:@"true"] ||
        [normalized isEqualToString:@"yes"] ||
        [normalized isEqualToString:@"1"]) {
        return YES;
    }
    if ([normalized isEqualToString:@"false"] ||
        [normalized isEqualToString:@"no"] ||
        [normalized isEqualToString:@"0"]) {
        return NO;
    }
    return fallback;
}

/// HomeConfig rows may grow new payload or styling fields before this client is
/// updated. Preserve every property-list-safe value so cached configuration does
/// not erase forward-compatible metadata while still keeping NSUserDefaults safe.
static id _Nullable PPHomeBridgeConfigValue(id _Nullable value)
{
    if (!value || [value isKindOfClass:NSNull.class]) {
        return nil;
    }
    if ([value isKindOfClass:NSString.class] ||
        [value isKindOfClass:NSNumber.class] ||
        [value isKindOfClass:NSDate.class] ||
        [value isKindOfClass:NSData.class]) {
        return value;
    }
    if ([value isKindOfClass:NSArray.class]) {
        NSMutableArray *array = [NSMutableArray array];
        for (id child in (NSArray *)value) {
            id sanitizedChild = PPHomeBridgeConfigValue(child);
            if (sanitizedChild) {
                [array addObject:sanitizedChild];
            }
        }
        return array.copy;
    }
    if ([value isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        [(NSDictionary *)value enumerateKeysAndObjectsUsingBlock:^(id key, id child, BOOL *stop) {
            (void)stop;
            if (![key isKindOfClass:NSString.class]) {
                return;
            }
            id sanitizedChild = PPHomeBridgeConfigValue(child);
            if (sanitizedChild) {
                dictionary[key] = sanitizedChild;
            }
        }];
        return dictionary.copy;
    }
    return nil;
}

@interface PPHomeDataBridge ()

@property (nonatomic, assign, readwrite) PPHomeBridgeLocationState locationState;
@property (nonatomic, copy, readwrite) NSString *selectedAreaName;
@property (nonatomic, assign, readwrite) CLLocationCoordinate2D selectedCoordinate;
@property (nonatomic, assign, readwrite) BOOL hasSelectedCoordinate;
@property (nonatomic, assign, readwrite) BOOL usesManualLocation;

@property (nonatomic, assign) BOOL started;
@property (nonatomic, assign) BOOL requestedAuthorization;
@property (nonatomic, assign) NSInteger refreshGeneration;
@property (nonatomic, assign) NSInteger nearbyGeneration;
@property (nonatomic, strong, nullable) NSDate *lastRefreshDate;
@property (nonatomic, strong) NSMutableArray<id> *notificationTokens;
@property (nonatomic, strong, nullable) CLLocationManager *locationManager;
@property (nonatomic, strong, nullable) CLGeocoder *geocoder;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> homeConfigListener;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> ordersListener;
@property (nonatomic, copy) NSString *ordersListenerUserID;
@property (nonatomic, assign) BOOL receivedServerHomeConfig;

@end

@implementation PPHomeDataBridge

- (instancetype)init
{
    self = [super init];
    if (!self) {
        return nil;
    }

    _notificationTokens = [NSMutableArray array];
    _selectedAreaName = @"";
    _selectedCoordinate = kCLLocationCoordinate2DInvalid;
    _locationState = PPHomeBridgeLocationStateNotDetermined;
    _ordersListenerUserID = @"";
    return self;
}

- (void)dealloc
{
    [self stop];
}

#pragma mark - Generation synchronization

- (NSInteger)advanceRefreshGeneration
{
    @synchronized (self) {
        self.refreshGeneration += 1;
        return self.refreshGeneration;
    }
}

- (BOOL)isRefreshGenerationCurrent:(NSInteger)generation
{
    @synchronized (self) {
        return generation == self.refreshGeneration;
    }
}

- (NSInteger)advanceNearbyGeneration
{
    @synchronized (self) {
        self.nearbyGeneration += 1;
        return self.nearbyGeneration;
    }
}

- (BOOL)isNearbyGenerationCurrent:(NSInteger)generation
{
    @synchronized (self) {
        return generation == self.nearbyGeneration;
    }
}

#pragma mark - Lifecycle

- (void)start
{
    if (self.started) {
        return;
    }
    self.started = YES;

    [self installObservers];
    [self restorePersistedLocation];
    [self configureLocationManager];
    [self publishCurrentMainKinds];
    [self publishCachedHomeConfigOrDefaults];
    [self startHomeConfigListener];
    [self startPromotionListener];
    [self refresh];
}

- (BOOL)refresh
{
    if (!self.started) {
        [self start];
        return YES;
    }

    NSDate *now = [NSDate date];
    if (self.lastRefreshDate &&
        [now timeIntervalSinceDate:self.lastRefreshDate] < PPHomeBridgeMinimumRefreshInterval) {
        return NO;
    }
    self.lastRefreshDate = now;
    NSInteger generation = [self advanceRefreshGeneration];

    [self publishCurrentMainKinds];
    [self refreshAccessoriesForGeneration:generation];
    [self refreshFoodForGeneration:generation];
    [self refreshAdvertisementsForGeneration:generation];
    [self refreshServicesForGeneration:generation];
    [self refreshPetContextForGeneration:generation];
    [self refreshOrdersListenerIfNeededForce:NO];
    [self refreshNearbyAdvertisements];
    return YES;
}

- (void)stop
{
    if (!self.started &&
        self.notificationTokens.count == 0 &&
        !self.homeConfigListener &&
        !self.ordersListener) {
        return;
    }

    self.started = NO;
    [self advanceRefreshGeneration];
    [self advanceNearbyGeneration];
    self.lastRefreshDate = nil;
    self.receivedServerHomeConfig = NO;
    self.requestedAuthorization = NO;

    for (id token in self.notificationTokens.copy) {
        [[NSNotificationCenter defaultCenter] removeObserver:token];
    }
    [self.notificationTokens removeAllObjects];

    [self.homeConfigListener remove];
    self.homeConfigListener = nil;
    [self.ordersListener remove];
    self.ordersListener = nil;
    self.ordersListenerUserID = @"";

    [[PPHomePromoCarouselManager sharedManager] stopListening];
    [self.locationManager stopUpdatingLocation];
    self.locationManager.delegate = nil;
    self.locationManager = nil;
    [self.geocoder cancelGeocode];
    self.geocoder = nil;
}

#pragma mark - Notifications

- (void)installObservers
{
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    __weak typeof(self) weakSelf = self;

    NSArray<NSString *> *refreshNotifications = @[
        PPMainKindsUpdatedNotification,
        @"PPAdDidFinishUploadNotification",
        @"PPUserManagerDidSyncCurrentUserNotification",
        @"PPUserManagerDidUpdateUserAccessNotification",
        @"PPSaveForLaterUpdatedNotification",
        @"LanguageDidChangeNotification",
    ];

    for (NSString *name in refreshNotifications) {
        id token =
            [center addObserverForName:name
                               object:nil
                                queue:NSOperationQueue.mainQueue
                           usingBlock:^(__unused NSNotification *notification) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || !self.started) {
                return;
            }
            if ([name isEqualToString:PPMainKindsUpdatedNotification]) {
                [self publishCurrentMainKinds];
                return;
            }
            if ([name isEqualToString:@"PPUserManagerDidSyncCurrentUserNotification"] ||
                [name isEqualToString:@"PPUserManagerDidUpdateUserAccessNotification"]) {
                [self refreshOrdersListenerIfNeededForce:YES];
            }
            [self refresh];
        }];
        [self.notificationTokens addObject:token];
    }

    id signOutToken =
        [center addObserverForName:@"PPUserManagerDidSignOutNotification"
                           object:nil
                            queue:NSOperationQueue.mainQueue
                       usingBlock:^(__unused NSNotification *notification) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        [self.ordersListener remove];
        self.ordersListener = nil;
        self.ordersListenerUserID = @"";
        if (self.ordersDidChange) {
            self.ordersDidChange(@[]);
        }
        if (self.petProfilesDidChange) {
            self.petProfilesDidChange(@[]);
        }
        if (self.petRemindersDidChange) {
            self.petRemindersDidChange(@[]);
        }
    }];
    [self.notificationTokens addObject:signOutToken];
}

#pragma mark - Main kinds

- (void)publishCurrentMainKinds
{
    NSArray<MainKindsModel *> *snapshot = PPMainKindsArray;
    if (snapshot.count == 0) {
        snapshot = [MainKindsArrayManager shared].MainKindsArray.copy ?: @[];
    }
    snapshot =
        [snapshot filteredArrayUsingPredicate:
            [NSPredicate predicateWithBlock:^BOOL(MainKindsModel *kind, __unused NSDictionary *bindings) {
                return [kind isKindOfClass:MainKindsModel.class] && kind.isVisibleInUserApp;
            }]];
    snapshot =
        [snapshot sortedArrayUsingComparator:^NSComparisonResult(MainKindsModel *lhs, MainKindsModel *rhs) {
            if (lhs.sortingKey != rhs.sortingKey) {
                return lhs.sortingKey < rhs.sortingKey ? NSOrderedAscending : NSOrderedDescending;
            }
            if (lhs.ID != rhs.ID) {
                return lhs.ID < rhs.ID ? NSOrderedAscending : NSOrderedDescending;
            }
            return [lhs.documentID ?: @"" compare:rhs.documentID ?: @""];
        }];

    if (self.mainKindsDidChange) {
        self.mainKindsDidChange(snapshot ?: @[]);
    }
}

#pragma mark - Promotions

- (void)startPromotionListener
{
    __weak typeof(self) weakSelf = self;
    [[PPHomePromoCarouselManager sharedManager]
        startListeningWithCompletion:^(NSArray<PPHomePromoCarouselCard *> * _Nullable cards,
                                       NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || !self.started) {
                return;
            }
            if (error) {
                [self publishError:error source:PPHomeBridgeSourcePromotions];
                return;
            }
            NSArray *visible =
                [(cards ?: @[]) filteredArrayUsingPredicate:
                    [NSPredicate predicateWithBlock:^BOOL(PPHomePromoCarouselCard *card,
                                                         __unused NSDictionary *bindings) {
                        return [card isKindOfClass:PPHomePromoCarouselCard.class] && card.visible;
                    }]];
            visible =
                [visible sortedArrayUsingComparator:^NSComparisonResult(PPHomePromoCarouselCard *lhs,
                                                                        PPHomePromoCarouselCard *rhs) {
                    if (lhs.sortOrder == rhs.sortOrder) {
                        return [lhs.cardID ?: @"" compare:rhs.cardID ?: @""];
                    }
                    return lhs.sortOrder < rhs.sortOrder ? NSOrderedAscending : NSOrderedDescending;
                }];
            if (self.promotionsDidChange) {
                self.promotionsDidChange(visible ?: @[]);
            }
        });
    }];
}

#pragma mark - Commerce and marketplace

- (void)refreshAccessoriesForGeneration:(NSInteger)generation
{
    __weak typeof(self) weakSelf = self;
    [[PetAccessoryManager sharedManager]
        fetchLatestAccessoriesWithLimit:50
                              completion:^(NSArray<PetAccessory *> *accessories,
                                           NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![self isRefreshGenerationCurrent:generation]) {
                return;
            }
            if (error) {
                [self publishError:error source:PPHomeBridgeSourceAccessories];
                return;
            }
            NSArray<PetAccessory *> *sorted =
                [(accessories ?: @[]) sortedArrayUsingComparator:^NSComparisonResult(PetAccessory *lhs,
                                                                                    PetAccessory *rhs) {
                    BOOL lhsOffer = lhs.hasOffer ||
                        lhs.discountPercent.doubleValue > 0.0 ||
                        lhs.discountAmount.doubleValue > 0.0;
                    BOOL rhsOffer = rhs.hasOffer ||
                        rhs.discountPercent.doubleValue > 0.0 ||
                        rhs.discountAmount.doubleValue > 0.0;
                    if (lhsOffer != rhsOffer) {
                        return lhsOffer ? NSOrderedAscending : NSOrderedDescending;
                    }
                    NSDate *lhsDate = lhs.createdAt ?: NSDate.distantPast;
                    NSDate *rhsDate = rhs.createdAt ?: NSDate.distantPast;
                    NSComparisonResult dateResult = [rhsDate compare:lhsDate];
                    if (dateResult != NSOrderedSame) {
                        return dateResult;
                    }
                    return [lhs.accessoryID ?: @"" compare:rhs.accessoryID ?: @""];
                }];
            if (self.accessoriesDidChange) {
                self.accessoriesDidChange(sorted ?: @[]);
            }
        });
    }];
}

- (void)refreshFoodForGeneration:(NSInteger)generation
{
    __weak typeof(self) weakSelf = self;
    [[PetAccessoryManager sharedManager]
        fetchFoodForAllMainKinds:^(NSArray<PetAccessory *> *foods) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        NSArray<PetAccessory *> *sorted =
            [[(foods ?: @[]) filteredArrayUsingPredicate:
                [NSPredicate predicateWithBlock:^BOOL(PetAccessory *item,
                                                     __unused NSDictionary *bindings) {
                    return [item isKindOfClass:PetAccessory.class] &&
                           item.accessKindType == AccessTypeFood &&
                           item.showInAppMarket &&
                           !item.isDeleted &&
                           !item.isBlocked &&
                           !item.isDisabled;
                }]]
             sortedArrayUsingComparator:^NSComparisonResult(PetAccessory *lhs, PetAccessory *rhs) {
                 NSDate *lhsDate = lhs.createdAt ?: NSDate.distantPast;
                 NSDate *rhsDate = rhs.createdAt ?: NSDate.distantPast;
                 NSComparisonResult dateResult = [rhsDate compare:lhsDate];
                 if (dateResult != NSOrderedSame) {
                     return dateResult;
                 }
                 return [lhs.accessoryID ?: @"" compare:rhs.accessoryID ?: @""];
             }];
        if (sorted.count > 16) {
            sorted = [sorted subarrayWithRange:NSMakeRange(0, 16)];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![self isRefreshGenerationCurrent:generation]) {
                return;
            }
            if (self.foodDidChange) {
                self.foodDidChange(sorted ?: @[]);
            }
        });
    }];
}

- (void)refreshAdvertisementsForGeneration:(NSInteger)generation
{
    __weak typeof(self) weakSelf = self;
    [[PetAdManager sharedManager]
        fetchLatestAdsWithLimit:36
                     completion:^(NSArray<PetAd *> *ads) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        NSArray<PetAd *> *valid =
            [(ads ?: @[]) filteredArrayUsingPredicate:
                [NSPredicate predicateWithBlock:^BOOL(PetAd *ad, __unused NSDictionary *bindings) {
                    return [ad isKindOfClass:PetAd.class] &&
                           ad.visibility == PetAdVisibilityPublic &&
                           !ad.isDeleted &&
                           !ad.isBlocked &&
                           !ad.isSold;
                }]];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![self isRefreshGenerationCurrent:generation]) {
                return;
            }
            if (self.advertisementsDidChange) {
                self.advertisementsDidChange(valid ?: @[]);
            }
        });
    }];
}

- (void)refreshServicesForGeneration:(NSInteger)generation
{
    __weak typeof(self) weakSelf = self;
    [[ServicesManager sharedInstance]
        fetchLatestServicesWithLimit:20
                         completion:^(NSArray<ServiceModel *> *services,
                                      NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![self isRefreshGenerationCurrent:generation]) {
                return;
            }
            if (error) {
                [self publishError:error source:PPHomeBridgeSourceServices];
                return;
            }
            NSArray<ServiceModel *> *live =
                [(services ?: @[]) filteredArrayUsingPredicate:
                    [NSPredicate predicateWithBlock:^BOOL(ServiceModel *service,
                                                         __unused NSDictionary *bindings) {
                        return [service isKindOfClass:ServiceModel.class] && service.isLive;
                    }]];
            if (self.servicesDidChange) {
                self.servicesDidChange(live ?: @[]);
            }
        });
    }];
}

#pragma mark - Pet context

- (void)refreshPetContextForGeneration:(NSInteger)generation
{
    NSString *uid = [self currentUserID];
    if (uid.length == 0) {
        if (self.petProfilesDidChange) {
            self.petProfilesDidChange(@[]);
        }
        if (self.petRemindersDidChange) {
            self.petRemindersDidChange(@[]);
        }
        return;
    }

    PPPetProfileManager *manager = [PPPetProfileManager sharedManager];
    manager.currentUserUID = uid;
    __weak typeof(self) weakSelf = self;
    [manager fetchPetProfilesForCurrentUserWithCompletion:
        ^(NSArray<PPPetProfile *> * _Nullable pets, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![self isRefreshGenerationCurrent:generation]) {
                return;
            }
            if (error) {
                [self publishError:error source:PPHomeBridgeSourcePetProfiles];
                return;
            }
            NSArray<PPPetProfile *> *ordered =
                [(pets ?: @[]) sortedArrayUsingComparator:^NSComparisonResult(PPPetProfile *lhs,
                                                                             PPPetProfile *rhs) {
                    if (lhs.isDefaultPet != rhs.isDefaultPet) {
                        return lhs.isDefaultPet ? NSOrderedAscending : NSOrderedDescending;
                    }
                    NSDate *lhsDate = lhs.createdAt ?: NSDate.distantPast;
                    NSDate *rhsDate = rhs.createdAt ?: NSDate.distantPast;
                    NSComparisonResult dateResult = [lhsDate compare:rhsDate];
                    if (dateResult != NSOrderedSame) {
                        return dateResult;
                    }
                    return [lhs.petID ?: @"" compare:rhs.petID ?: @""];
                }];
            if (self.petProfilesDidChange) {
                self.petProfilesDidChange(ordered ?: @[]);
            }
        });
    }];

    [manager fetchPetRemindersForCurrentUserWithCompletion:
        ^(NSArray<PPPetReminder *> * _Nullable reminders, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![self isRefreshGenerationCurrent:generation]) {
                return;
            }
            if (error) {
                [self publishError:error source:PPHomeBridgeSourcePetReminders];
                return;
            }
            NSArray<PPPetReminder *> *enabled =
                [(reminders ?: @[]) filteredArrayUsingPredicate:
                    [NSPredicate predicateWithBlock:^BOOL(PPPetReminder *reminder,
                                                         __unused NSDictionary *bindings) {
                        return [reminder isKindOfClass:PPPetReminder.class] && reminder.enabled;
                    }]];
            enabled =
                [enabled sortedArrayUsingComparator:^NSComparisonResult(PPPetReminder *lhs,
                                                                       PPPetReminder *rhs) {
                    NSDate *lhsDate = lhs.fireDate ?: NSDate.distantFuture;
                    NSDate *rhsDate = rhs.fireDate ?: NSDate.distantFuture;
                    NSComparisonResult dateResult = [lhsDate compare:rhsDate];
                    if (dateResult != NSOrderedSame) {
                        return dateResult;
                    }
                    return [lhs.reminderID ?: @"" compare:rhs.reminderID ?: @""];
                }];
            if (self.petRemindersDidChange) {
                self.petRemindersDidChange(enabled ?: @[]);
            }
        });
    }];
}

#pragma mark - Orders

- (NSString *)currentUserID
{
    NSString *userID = UserManager.sharedManager.currentUser.ID;
    if (![userID isKindOfClass:NSString.class]) {
        userID = @"";
    }
    userID = [userID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (userID.length == 0) {
        userID = FIRAuth.auth.currentUser.uid ?: @"";
    }
    return userID;
}

- (void)refreshOrdersListenerIfNeededForce:(BOOL)force
{
    NSString *uid = [self currentUserID];
    if (uid.length == 0) {
        [self.ordersListener remove];
        self.ordersListener = nil;
        self.ordersListenerUserID = @"";
        if (self.ordersDidChange) {
            self.ordersDidChange(@[]);
        }
        return;
    }
    if (!force &&
        self.ordersListener &&
        [self.ordersListenerUserID isEqualToString:uid]) {
        return;
    }

    [self.ordersListener remove];
    self.ordersListener = nil;
    self.ordersListenerUserID = uid;

    FIRFirestore *database = AppManager.sharedInstance.dF ?: FIRFirestore.firestore;
    FIRQuery *query =
        [[[database collectionWithPath:@"Orders"]
            queryWhereField:@"userId" isEqualTo:uid]
            queryOrderedByField:@"createdAt" descending:YES];
    query = [query queryLimitedTo:PPHomeBridgeOrderLimit];

    __weak typeof(self) weakSelf = self;
    self.ordersListener =
        [query addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot,
                                     NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self ||
                !self.started ||
                ![self.ordersListenerUserID isEqualToString:uid]) {
                return;
            }
            if (error) {
                [self publishError:error source:PPHomeBridgeSourceOrders];
                return;
            }
            NSMutableArray<PPOrder *> *orders = [NSMutableArray array];
            for (FIRDocumentSnapshot *document in snapshot.documents ?: @[]) {
                PPOrder *order = [PPOrder orderFromSnapshot:document];
                if ([order isKindOfClass:PPOrder.class]) {
                    [orders addObject:order];
                }
            }
            if (self.ordersDidChange) {
                self.ordersDidChange(orders.copy);
            }
        });
    }];
}

#pragma mark - Home configuration

- (NSArray<NSNumber *> *)defaultSectionOrder
{
    return @[
        @(PPHomeSectionPureLens),
        @(PPHomeSectionPremiumSearch),
        @(PPHomeSectionMarketplaceHero),
        @(PPHomeSectionProviderCategoryNav),
        @(PPHomeSectionHero),
        @(PPHomeSectionMainKinds),
        @(PPHomeSectionPremiumCare),
        @(PPHomeSectionQuickActions),
        @(PPHomeSectionCurrentOrders),
        @(PPHomeSectionAccessories),
        @(PPHomeSectionSuggestionAds),
        @(PPHomeSectionSuggestionAccessories),
        @(PPHomeSectionSuggestions),
        @(PPHomeSectionCarousel),
        @(PPHomeSectionLastFood),
        @(PPHomeSectionAdsNearBy),
        @(PPHomeSectionNearbyServices),
        @(PPHomeSectionAdopt),
        @(PPHomeSectionBuyAgain),
        @(PPHomeSectionPetProfile),
    ];
}

- (NSString *)defaultTypeForSectionID:(NSInteger)sectionID
{
    switch (sectionID) {
        case PPHomeSectionPureLens: return @"PPHomeSectionPureLens";
        case PPHomeSectionHero: return @"PPHomeSectionHero";
        case PPHomeSectionQuickActions: return @"PPHomeSectionQuickActions";
        case PPHomeSectionCurrentOrders: return @"PPHomeSectionCurrentOrders";
        case PPHomeSectionCarousel: return @"PPHomeSectionCarousel";
        case PPHomeSectionMainKinds: return @"PPHomeSectionMainKinds";
        case PPHomeSectionSuggestions: return @"PPHomeSectionSuggestions";
        case PPHomeSectionAccessories: return @"PPHomeSectionAccessories";
        case PPHomeSectionPetProfile: return @"PPHomeSectionPetProfile";
        case PPHomeSectionPremiumCare: return @"PPHomeSectionPremiumCare";
        case PPHomeSectionLastFood: return @"PPHomeSectionLastFood";
        case PPHomeSectionNearbyServices: return @"PPHomeSectionNearbyServices";
        case PPHomeSectionAdsNearBy: return @"PPHomeSectionAdsNearBy";
        case PPHomeSectionAdopt: return @"PPHomeSectionAdopt";
        case PPHomeSectionBuyAgain: return @"PPHomeSectionBuyAgain";
        case PPHomeSectionPremiumSearch: return @"PPHomeSectionPremiumSearch";
        case PPHomeSectionProviderCategoryNav: return @"PPHomeSectionProviderCategoryNav";
        case PPHomeSectionMarketplaceHero: return @"PPHomeSectionMarketplaceHero";
        case PPHomeSectionSuggestionAds: return @"PPHomeSectionSuggestionAds";
        case PPHomeSectionSuggestionAccessories: return @"PPHomeSectionSuggestionAccessories";
        default: return @"";
    }
}

- (BOOL)defaultVisibilityForSectionID:(NSInteger)sectionID
{
    return sectionID != PPHomeSectionMarketplaceHero &&
           sectionID != PPHomeSectionProviderCategoryNav;
}

- (NSInteger)sectionIDFromValue:(id)value
{
    if ([value isKindOfClass:NSNumber.class]) {
        return [value integerValue];
    }
    if (![value isKindOfClass:NSString.class]) {
        return NSNotFound;
    }
    NSString *raw =
        [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (raw.length == 0) {
        return NSNotFound;
    }
    NSInteger numeric = raw.integerValue;
    if ([raw isEqualToString:@(numeric).stringValue]) {
        return numeric;
    }
    static NSDictionary<NSString *, NSNumber *> *nameMap;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        nameMap = @{
            @"PPHomeSectionPureLens" : @(PPHomeSectionPureLens),
            @"PPHomeSectionHero" : @(PPHomeSectionHero),
            @"PPHomeSectionQuickActions" : @(PPHomeSectionQuickActions),
            @"PPHomeSectionCurrentOrders" : @(PPHomeSectionCurrentOrders),
            @"PPHomeSectionCarousel" : @(PPHomeSectionCarousel),
            @"PPHomeSectionMainKinds" : @(PPHomeSectionMainKinds),
            @"PPHomeSectionSuggestions" : @(PPHomeSectionSuggestions),
            @"PPHomeSectionSuggestionAds" : @(PPHomeSectionSuggestionAds),
            @"PPHomeSectionSuggestionAccessories" : @(PPHomeSectionSuggestionAccessories),
            @"PPHomeSectionAccessories" : @(PPHomeSectionAccessories),
            @"PPHomeSectionPetProfile" : @(PPHomeSectionPetProfile),
            @"PPHomeSectionPremiumCare" : @(PPHomeSectionPremiumCare),
            @"PPHomeSectionLastFood" : @(PPHomeSectionLastFood),
            @"PPHomeSectionNearbyServices" : @(PPHomeSectionNearbyServices),
            @"PPHomeSectionAdsNearBy" : @(PPHomeSectionAdsNearBy),
            @"PPHomeSectionAdopt" : @(PPHomeSectionAdopt),
            @"PPHomeSectionBuyAgain" : @(PPHomeSectionBuyAgain),
            @"PPHomeSectionPremiumSearch" : @(PPHomeSectionPremiumSearch),
            @"PPHomeSectionProviderCategoryNav" : @(PPHomeSectionProviderCategoryNav),
            @"PPHomeSectionMarketplaceHero" : @(PPHomeSectionMarketplaceHero),
        };
    });
    NSNumber *resolved = nameMap[raw];
    return resolved ? resolved.integerValue : NSNotFound;
}

- (NSArray<NSDictionary *> *)sanitizedConfigSections:(id)rawSections
{
    if (![rawSections isKindOfClass:NSArray.class]) {
        return @[];
    }

    NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
    NSMutableSet<NSNumber *> *seen = [NSMutableSet set];
    for (id rawRow in (NSArray *)rawSections) {
        if (![rawRow isKindOfClass:NSDictionary.class]) {
            continue;
        }
        NSDictionary *row = (NSDictionary *)rawRow;
        NSInteger sectionID = [self sectionIDFromValue:row[@"id"]];
        if (sectionID == NSNotFound) {
            sectionID = [self sectionIDFromValue:row[@"type"]];
        }
        if (sectionID < 0 || sectionID == NSNotFound) {
            continue;
        }
        NSNumber *boxedID = @(sectionID);
        if ([seen containsObject:boxedID]) {
            continue;
        }
        [seen addObject:boxedID];
        NSMutableDictionary *preservedRow = [NSMutableDictionary dictionary];
        [row enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
            (void)stop;
            if (![key isKindOfClass:NSString.class]) {
                return;
            }
            id sanitizedValue = PPHomeBridgeConfigValue(value);
            if (sanitizedValue) {
                preservedRow[key] = sanitizedValue;
            }
        }];
        BOOL visible = PPHomeBridgeBoolValue(row[@"visible"], YES);
        NSString *type = [row[@"type"] isKindOfClass:NSString.class]
            ? row[@"type"]
            : [self defaultTypeForSectionID:sectionID];
        preservedRow[@"id"] = boxedID;
        preservedRow[@"visible"] = @(visible);
        preservedRow[@"type"] = type ?: @"";
        [result addObject:preservedRow.copy];
    }
    return result.copy;
}

- (NSArray<NSDictionary *> *)mergedConfigSections:(NSArray<NSDictionary *> *)stored
                              premiumCareVisible:(BOOL)premiumCareVisible
{
    NSArray<NSNumber *> *catalog = [self defaultSectionOrder];
    NSMutableArray<NSDictionary *> *merged = [NSMutableArray array];
    NSMutableSet<NSNumber *> *seen = [NSMutableSet set];

    for (NSDictionary *row in stored ?: @[]) {
        NSNumber *sectionID = row[@"id"];
        if (![sectionID isKindOfClass:NSNumber.class] || [seen containsObject:sectionID]) {
            continue;
        }
        BOOL visible = PPHomeBridgeBoolValue(row[@"visible"], YES);
        if (sectionID.integerValue == PPHomeSectionPremiumCare) {
            visible = visible && premiumCareVisible;
        }
        [seen addObject:sectionID];
        NSMutableDictionary *preservedRow = [row mutableCopy];
        preservedRow[@"id"] = sectionID;
        preservedRow[@"visible"] = @(visible);
        preservedRow[@"type"] = [row[@"type"] isKindOfClass:NSString.class]
            ? row[@"type"]
            : [self defaultTypeForSectionID:sectionID.integerValue];
        [merged addObject:preservedRow.copy];
    }

    for (NSNumber *sectionID in catalog) {
        if ([seen containsObject:sectionID]) {
            continue;
        }
        BOOL visible = [self defaultVisibilityForSectionID:sectionID.integerValue];
        if (sectionID.integerValue == PPHomeSectionPremiumCare) {
            visible = visible && premiumCareVisible;
        }
        [merged addObject:@{
            @"id" : sectionID,
            @"visible" : @(visible),
            @"type" : [self defaultTypeForSectionID:sectionID.integerValue],
        }];
    }
    return merged.copy;
}

- (void)publishCachedHomeConfigOrDefaults
{
    NSDictionary *payload =
        [NSUserDefaults.standardUserDefaults dictionaryForKey:PPHomeBridgeConfigCacheKey];
    NSArray<NSDictionary *> *sanitized =
        [self sanitizedConfigSections:payload[PPHomeBridgeConfigSectionsKey]];
    BOOL premiumCareVisible =
        PPHomeBridgeBoolValue(
            payload[PPHomeBridgeConfigPremiumCareVisibleKey],
            YES
        );
    BOOL novaVisible =
        PPHomeBridgeBoolValue(
            payload[PPHomeBridgeConfigNovaFloatingVisibleKey],
            YES
        );
    BOOL glowsFaded =
        PPHomeBridgeBoolValue(
            payload[PPHomeBridgeConfigBackgroundGlowsFadedKey],
            NO
        );
    BOOL pureLensVisible =
        PPHomeBridgeBoolValue(
            payload[@"pureLensVisible"],
            YES
        );
    BOOL novaUseGenkit =
        PPHomeBridgeBoolValue(
            payload[PPHomeBridgeConfigNovaUseGenkitKey],
            YES
        );
    NSString *titleMode = [payload[PPHomeBridgeConfigTitleModeKey] isKindOfClass:NSString.class]
        ? payload[PPHomeBridgeConfigTitleModeKey]
        : @"location";
    if (![titleMode isEqualToString:@"location"] &&
        ![titleMode isEqualToString:@"search"]) {
        titleMode = @"location";
    }

    NSArray *merged = [self mergedConfigSections:sanitized
                              premiumCareVisible:premiumCareVisible];
    [NSUserDefaults.standardUserDefaults setBool:novaVisible
                                          forKey:@"PPNovaFloatingVisible"];
    [NSUserDefaults.standardUserDefaults setBool:novaUseGenkit
                                          forKey:@"pp_nova_use_genkit"];
    if (self.homeConfigDidChange) {
        self.homeConfigDidChange(merged, titleMode, premiumCareVisible,
                                 novaVisible, glowsFaded, pureLensVisible, payload != nil);
    }
}

- (void)startHomeConfigListener
{
    [self.homeConfigListener remove];
    self.receivedServerHomeConfig = NO;

    FIRFirestore *database = AppManager.sharedInstance.dF ?: FIRFirestore.firestore;
    FIRDocumentReference *document =
        [[database collectionWithPath:@"AppConfigCol"] documentWithPath:@"HomeConfig"];
    __weak typeof(self) weakSelf = self;
    self.homeConfigListener =
        [document addSnapshotListenerWithIncludeMetadataChanges:YES
                                                       listener:^(FIRDocumentSnapshot * _Nullable snapshot,
                                                                  NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || !self.started) {
                return;
            }
            if (error) {
                [self publishError:error source:PPHomeBridgeSourceHomeConfig];
                return;
            }
            if (!snapshot.exists) {
                return;
            }
            BOOL fromCache = snapshot.metadata.isFromCache;
            if (fromCache && self.receivedServerHomeConfig) {
                return;
            }
            [self applyHomeConfigData:snapshot.data ?: @{} fromCache:fromCache];
            if (!fromCache) {
                self.receivedServerHomeConfig = YES;
            }
        });
    }];
}

- (void)applyHomeConfigData:(NSDictionary *)data fromCache:(BOOL)fromCache
{
    NSArray<NSDictionary *> *sanitized = [self sanitizedConfigSections:data[@"sections"]];
    BOOL premiumCareVisible =
        PPHomeBridgeBoolValue(data[@"premiumCareVisible"], YES);
    BOOL novaVisible =
        PPHomeBridgeBoolValue(data[@"novaFloatingVisible"], YES);
    BOOL glowsFaded =
        PPHomeBridgeBoolValue(data[@"backgroundGlowsFaded"], NO);
    BOOL pureLensVisible =
        PPHomeBridgeBoolValue(data[@"pureLensVisible"], YES);
    BOOL novaUseGenkit =
        PPHomeBridgeBoolValue(data[@"novaUseGenkit"], YES);
    NSString *titleMode = [data[@"titleViewMode"] isKindOfClass:NSString.class]
        ? data[@"titleViewMode"]
        : @"location";
    if (![titleMode isEqualToString:@"location"] &&
        ![titleMode isEqualToString:@"search"]) {
        titleMode = @"location";
    }
    NSArray<NSDictionary *> *merged =
        [self mergedConfigSections:sanitized premiumCareVisible:premiumCareVisible];

    if (!fromCache) {
        NSDictionary *cachePayload = @{
            PPHomeBridgeConfigSectionsKey : merged,
            PPHomeBridgeConfigTitleModeKey : titleMode,
            PPHomeBridgeConfigPremiumCareVisibleKey : @(premiumCareVisible),
            PPHomeBridgeConfigNovaFloatingVisibleKey : @(novaVisible),
            PPHomeBridgeConfigBackgroundGlowsFadedKey : @(glowsFaded),
            @"pureLensVisible" : @(pureLensVisible),
            PPHomeBridgeConfigNovaUseGenkitKey : @(novaUseGenkit),
        };
        [NSUserDefaults.standardUserDefaults setObject:cachePayload
                                                forKey:PPHomeBridgeConfigCacheKey];
    }
    [NSUserDefaults.standardUserDefaults setBool:novaVisible
                                          forKey:@"PPNovaFloatingVisible"];
    [NSUserDefaults.standardUserDefaults setBool:novaUseGenkit
                                          forKey:@"pp_nova_use_genkit"];

    if (self.homeConfigDidChange) {
        self.homeConfigDidChange(merged, titleMode, premiumCareVisible,
                                 novaVisible, glowsFaded, pureLensVisible, fromCache);
    }
}

#pragma mark - Location

- (void)restorePersistedLocation
{
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if (![defaults objectForKey:PPHomeBridgeLatitudeKey] ||
        ![defaults objectForKey:PPHomeBridgeLongitudeKey]) {
        return;
    }
    CLLocationCoordinate2D coordinate =
        CLLocationCoordinate2DMake([defaults doubleForKey:PPHomeBridgeLatitudeKey],
                                   [defaults doubleForKey:PPHomeBridgeLongitudeKey]);
    if (![self isValidCoordinate:coordinate]) {
        return;
    }
    self.selectedCoordinate = coordinate;
    self.hasSelectedCoordinate = YES;
    self.selectedAreaName = [defaults stringForKey:PPHomeBridgeAreaNameKey] ?: @"";
    self.usesManualLocation = [defaults boolForKey:PPHomeBridgeManualSelectionKey];
    self.locationState = PPHomeBridgeLocationStateReady;
    [self publishLocation];
}

- (void)configureLocationManager
{
    CLLocationManager *manager = [[CLLocationManager alloc] init];
    manager.delegate = self;
    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
    manager.distanceFilter = PPHomeBridgeLocationDistanceFilter;
    self.locationManager = manager;
    self.geocoder = [[CLGeocoder alloc] init];

    CLAuthorizationStatus status;
    if (@available(iOS 14.0, *)) {
        status = manager.authorizationStatus;
    } else {
        status = CLLocationManager.authorizationStatus;
    }
    [self applyAuthorizationStatus:status requestIfNeeded:NO];
}

- (void)requestLocationAuthorization
{
    if (!self.locationManager) {
        [self configureLocationManager];
    }
    CLAuthorizationStatus status;
    if (@available(iOS 14.0, *)) {
        status = self.locationManager.authorizationStatus;
    } else {
        status = CLLocationManager.authorizationStatus;
    }
    [self applyAuthorizationStatus:status requestIfNeeded:YES];
}

- (void)useAutomaticLocation
{
    self.usesManualLocation = NO;
    [NSUserDefaults.standardUserDefaults setBool:NO forKey:PPHomeBridgeManualSelectionKey];
    if (!self.locationManager) {
        [self configureLocationManager];
    }
    CLAuthorizationStatus status;
    if (@available(iOS 14.0, *)) {
        status = self.locationManager.authorizationStatus;
    } else {
        status = CLLocationManager.authorizationStatus;
    }
    [self applyAuthorizationStatus:status requestIfNeeded:YES];
}

- (void)setManualLocationLatitude:(CLLocationDegrees)latitude
                        longitude:(CLLocationDegrees)longitude
                             title:(NSString *)title
{
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(latitude, longitude);
    if (![self isValidCoordinate:coordinate]) {
        NSError *error =
            [NSError errorWithDomain:@"com.purepets.home.location"
                                code:1
                            userInfo:@{NSLocalizedDescriptionKey :
                                           kLang(@"SomethingWentWrong") ?: @"Invalid location"}];
        [self publishError:error source:PPHomeBridgeSourceLocation];
        return;
    }

    self.selectedCoordinate = coordinate;
    self.hasSelectedCoordinate = YES;
    self.usesManualLocation = YES;
    self.selectedAreaName =
        [title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    self.locationState = PPHomeBridgeLocationStateReady;
    [self persistLocation];
    [self publishLocation];
    [self refreshNearbyAdvertisements];
}

- (void)applyAuthorizationStatus:(CLAuthorizationStatus)status requestIfNeeded:(BOOL)requestIfNeeded
{
    switch (status) {
        case kCLAuthorizationStatusAuthorizedAlways:
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            if (self.usesManualLocation && self.hasSelectedCoordinate) {
                self.locationState = PPHomeBridgeLocationStateReady;
                [self publishLocation];
                return;
            }
            self.locationState = self.hasSelectedCoordinate
                ? PPHomeBridgeLocationStateReady
                : PPHomeBridgeLocationStateLoading;
            [self publishLocation];
            [self.locationManager requestLocation];
            break;

        case kCLAuthorizationStatusDenied:
            self.locationState = self.hasSelectedCoordinate
                ? PPHomeBridgeLocationStateReady
                : PPHomeBridgeLocationStateDenied;
            [self publishLocation];
            break;

        case kCLAuthorizationStatusRestricted:
            self.locationState = self.hasSelectedCoordinate
                ? PPHomeBridgeLocationStateReady
                : PPHomeBridgeLocationStateRestricted;
            [self publishLocation];
            break;

        case kCLAuthorizationStatusNotDetermined:
            self.locationState = self.hasSelectedCoordinate
                ? PPHomeBridgeLocationStateReady
                : PPHomeBridgeLocationStateNotDetermined;
            [self publishLocation];
            if (requestIfNeeded && !self.requestedAuthorization) {
                self.requestedAuthorization = YES;
                [self.locationManager requestWhenInUseAuthorization];
            }
            break;
    }
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager
{
    if (@available(iOS 14.0, *)) {
        [self applyAuthorizationStatus:manager.authorizationStatus requestIfNeeded:NO];
    }
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (void)locationManager:(CLLocationManager *)manager
didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    [self applyAuthorizationStatus:status requestIfNeeded:NO];
}
#pragma clang diagnostic pop

- (void)locationManager:(CLLocationManager *)manager
      didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    (void)manager;
    if (self.usesManualLocation) {
        return;
    }
    CLLocation *latest = locations.lastObject;
    if (!latest || ![self isValidCoordinate:latest.coordinate]) {
        return;
    }

    self.selectedCoordinate = latest.coordinate;
    self.hasSelectedCoordinate = YES;
    self.locationState = PPHomeBridgeLocationStateLoading;
    [self publishLocation];

    [self.geocoder cancelGeocode];
    __weak typeof(self) weakSelf = self;
    [self.geocoder reverseGeocodeLocation:latest
                       completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks,
                                           NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.usesManualLocation) {
            return;
        }
        CLPlacemark *placemark = placemarks.firstObject;
        NSString *area = @"";
        if (!error && placemark) {
            NSString *locality = placemark.locality ?: placemark.subLocality ?: @"";
            NSString *administrative = placemark.administrativeArea ?: @"";
            if (locality.length > 0 &&
                administrative.length > 0 &&
                ![locality isEqualToString:administrative]) {
                area = [NSString stringWithFormat:@"%@, %@", locality, administrative];
            } else {
                area = locality.length > 0 ? locality : administrative;
            }
        }
        if (area.length == 0) {
            area = self.selectedAreaName.length > 0
                ? self.selectedAreaName
                : (kLang(@"Select your location") ?: @"");
        }
        self.selectedAreaName = area;
        self.locationState = PPHomeBridgeLocationStateReady;
        [self persistLocation];
        [self publishLocation];
        [self refreshNearbyAdvertisements];
    }];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    (void)manager;
    self.locationState = self.hasSelectedCoordinate
        ? PPHomeBridgeLocationStateReady
        : PPHomeBridgeLocationStateFailed;
    [self publishLocation];
    [self publishError:error source:PPHomeBridgeSourceLocation];
}

- (BOOL)isValidCoordinate:(CLLocationCoordinate2D)coordinate
{
    return CLLocationCoordinate2DIsValid(coordinate) &&
           isfinite(coordinate.latitude) &&
           isfinite(coordinate.longitude) &&
           !(fabs(coordinate.latitude) < DBL_EPSILON &&
             fabs(coordinate.longitude) < DBL_EPSILON);
}

- (void)persistLocation
{
    if (!self.hasSelectedCoordinate || ![self isValidCoordinate:self.selectedCoordinate]) {
        return;
    }
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setDouble:self.selectedCoordinate.latitude forKey:PPHomeBridgeLatitudeKey];
    [defaults setDouble:self.selectedCoordinate.longitude forKey:PPHomeBridgeLongitudeKey];
    [defaults setObject:self.selectedAreaName ?: @"" forKey:PPHomeBridgeAreaNameKey];
    [defaults setBool:self.usesManualLocation forKey:PPHomeBridgeManualSelectionKey];
}

- (void)publishLocation
{
    if (self.locationDidChange) {
        self.locationDidChange(self.locationState,
                               self.selectedAreaName ?: @"",
                               self.selectedCoordinate,
                               self.hasSelectedCoordinate,
                               self.usesManualLocation);
    }
}

- (void)refreshNearbyAdvertisements
{
    NSInteger generation = [self advanceNearbyGeneration];
    if (!self.hasSelectedCoordinate || ![self isValidCoordinate:self.selectedCoordinate]) {
        if (self.nearbyAdvertisementsDidChange) {
            self.nearbyAdvertisementsDidChange(@[], NO);
        }
        return;
    }

    CLLocationCoordinate2D coordinate = self.selectedCoordinate;
    __weak typeof(self) weakSelf = self;
    [[PetAdManager sharedManager]
        fetchNearbyAdsAtCoordinate:coordinate
                          radiusKm:PPHomeBridgeNearbyRadiusKM
                             limit:PPHomeBridgeNearbyLimit
                          category:0
                        completion:^(NSArray<PetAd *> *ads) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || ![self isNearbyGenerationCurrent:generation]) {
            return;
        }

        NSMutableDictionary<NSString *, PetAd *> *uniqueByID = [NSMutableDictionary dictionary];
        for (PetAd *ad in ads ?: @[]) {
            if ([ad isKindOfClass:PetAd.class] &&
                ad.adID.length > 0 &&
                ad.visibility == PetAdVisibilityPublic &&
                !ad.isDeleted &&
                !ad.isBlocked &&
                !ad.isSold) {
                uniqueByID[ad.adID] = ad;
            }
        }
        NSArray<PetAd *> *nearby =
            [uniqueByID.allValues sortedArrayUsingComparator:^NSComparisonResult(PetAd *lhs,
                                                                                PetAd *rhs) {
                NSDate *lhsDate = lhs.createdAt ?: lhs.postedDate ?: NSDate.distantPast;
                NSDate *rhsDate = rhs.createdAt ?: rhs.postedDate ?: NSDate.distantPast;
                NSComparisonResult dateResult = [rhsDate compare:lhsDate];
                if (dateResult != NSOrderedSame) {
                    return dateResult;
                }
                return [lhs.adID ?: @"" compare:rhs.adID ?: @""];
            }];

        if (nearby.count >= 3) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (![self isNearbyGenerationCurrent:generation]) {
                    return;
                }
                if (self.nearbyAdvertisementsDidChange) {
                    self.nearbyAdvertisementsDidChange(nearby, NO);
                }
            });
            return;
        }

        [[PetAdManager sharedManager]
            fetchLatestAdsWithLimit:10
                         completion:^(NSArray<PetAd *> *latest) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (![self isNearbyGenerationCurrent:generation]) {
                    return;
                }
                if (self.nearbyAdvertisementsDidChange) {
                    NSMutableArray<PetAd *> *merged = [nearby mutableCopy];
                    NSMutableSet<NSString *> *seen = [NSMutableSet set];
                    for (PetAd *ad in nearby) {
                        if (ad.adID.length > 0) {
                            [seen addObject:ad.adID];
                        }
                    }
                    for (PetAd *ad in latest ?: @[]) {
                        if (![ad isKindOfClass:PetAd.class] ||
                            ad.adID.length == 0 ||
                            [seen containsObject:ad.adID] ||
                            ad.visibility != PetAdVisibilityPublic ||
                            ad.isDeleted ||
                            ad.isBlocked ||
                            ad.isSold) {
                            continue;
                        }
                        [seen addObject:ad.adID];
                        [merged addObject:ad];
                    }
                    self.nearbyAdvertisementsDidChange(merged.copy, YES);
                }
            });
        }];
    }];
}

#pragma mark - Mapping and errors

+ (PPUniversalCellViewModel *)viewModelForObject:(id)object
                                         context:(PPCellContext)context
{
    PPUniversalCellViewModel *viewModel =
        [[PPUniversalCellViewModel alloc] initWithModel:object context:context];
    viewModel.ModelObject = object;
    return viewModel;
}

- (void)fetchAccessoriesWithIDs:(NSArray<NSString *> *)itemIDs
                     completion:(void (^)(NSArray<PetAccessory *> *accessories))completion
{
    NSMutableOrderedSet<NSString *> *uniqueIDs = [NSMutableOrderedSet orderedSet];
    for (id rawID in itemIDs ?: @[]) {
        NSString *itemID = [rawID isKindOfClass:NSString.class]
            ? [(NSString *)rawID stringByTrimmingCharactersInSet:
                NSCharacterSet.whitespaceAndNewlineCharacterSet]
            : @"";
        if (itemID.length > 0) {
            [uniqueIDs addObject:itemID];
        }
    }
    if (uniqueIDs.count == 0) {
        if (completion) {
            completion(@[]);
        }
        return;
    }
    [PetAccessoryManager fetchAccessoriesWithIDs:uniqueIDs.array
                                      completion:^(NSArray<PetAccessory *> *accessories) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(accessories ?: @[]);
            }
        });
    }];
}

- (void)fetchAccessoriesForMainCategoryID:(NSInteger)mainCategoryID
                                completion:(void (^)(NSArray<PetAccessory *> *accessories))completion
{
    [[PetAccessoryManager sharedManager]
        fetchAccessoriesForMainCategoryID:mainCategoryID
                            subCategoryID:0
                                    limit:24
                               completion:^(NSArray<PetAccessory *> *accessories) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(accessories ?: @[]);
            }
        });
    }];
}

- (void)fetchMarketplaceItemCountForMainCategoryID:(NSInteger)mainCategoryID
                                         completion:(PPHomeExactCountCompletion)completion
{
    if (mainCategoryID <= 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(0, PPHomeMissingSignalCategoryError());
        });
        return;
    }
    [[PetAccessoryManager sharedManager]
        fetchPublicMarketplaceAccessoriesForMainCategoryID:mainCategoryID
        completion:^(NSArray<PetAccessory *> *accessories, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(accessories.count, error);
            });
        }];
}

- (void)fetchServiceCountForMainCategoryID:(NSInteger)mainCategoryID
                                 completion:(PPHomeExactCountCompletion)completion
{
    if (mainCategoryID <= 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(0, PPHomeMissingSignalCategoryError());
        });
        return;
    }
    [[ServicesManager sharedInstance]
        fetchServicesForPetMainKindID:mainCategoryID
        completion:^(NSArray<ServiceModel *> *services, NSError *error) {
            if (error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(0, error);
                });
                return;
            }

            NSUInteger liveCount =
                [(services ?: @[]) filteredArrayUsingPredicate:
                    [NSPredicate predicateWithBlock:^BOOL(ServiceModel *service,
                                                         __unused NSDictionary *bindings) {
                        return [service isKindOfClass:ServiceModel.class] && service.isLive;
                    }]].count;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion((NSInteger)liveCount, nil);
            });
        }];
}

- (void)fetchAdvertisementCountForMainCategoryID:(NSInteger)mainCategoryID
                                       completion:(PPHomeExactCountCompletion)completion
{
    if (mainCategoryID <= 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(0, PPHomeMissingSignalCategoryError());
        });
        return;
    }
    [[PetAdManager sharedManager]
        fetchPublicVisibleAdsForCategoryID:mainCategoryID
        completion:^(NSArray<PetAd *> *ads, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(ads.count, error);
            });
        }];
}

+ (BOOL)statusKey:(NSString *)statusKey matchesKeywords:(NSArray<NSString *> *)keywords
{
    NSString *normalized = [PPOrder normalizedStatusFromRawValue:statusKey];
    if (normalized.length == 0) {
        return NO;
    }
    NSString *wrapped = [NSString stringWithFormat:@"_%@_", normalized];
    for (NSString *keyword in keywords) {
        NSString *normalizedKeyword = [PPOrder normalizedStatusFromRawValue:keyword];
        if (normalizedKeyword.length > 0 &&
            [wrapped containsString:[NSString stringWithFormat:@"_%@_", normalizedKeyword]]) {
            return YES;
        }
    }
    return NO;
}

+ (NSString *)statusKeyForOrder:(PPOrder *)order
{
    NSString *key = [PPOrder normalizedStatusFromRawValue:[order customerVisibleStatusKey]];
    return key.length > 0 ? key : @"preparing_for_shipment";
}

+ (BOOL)isActiveOrder:(PPOrder *)order
{
    if (![order isKindOfClass:PPOrder.class]) {
        return NO;
    }
    NSString *key = [self statusKeyForOrder:order];
    if ([self statusKey:key
        matchesKeywords:@[@"delivery_cancelled", @"delivery_delayed", @"failed",
                          @"rejected", @"cancelled", @"canceled", @"expired",
                          @"voided", @"error", @"delivered", @"completed"]]) {
        return NO;
    }
    return [self statusKey:key
           matchesKeywords:@[@"pending", @"preparing_for_shipment",
                             @"ready_for_delivery", @"delivery_partner_assigned",
                             @"on_the_way"]];
}

+ (NSObject *)activeOrderFromOrders:(NSArray<NSObject *> *)orders
{
    for (NSObject *object in orders ?: @[]) {
        if (![object isKindOfClass:PPOrder.class]) {
            continue;
        }
        PPOrder *order = (PPOrder *)object;
        if ([self isActiveOrder:order]) {
            return order;
        }
    }
    return nil;
}

+ (NSString *)stringValueForKeys:(NSArray<NSString *> *)keys dictionary:(NSDictionary *)dictionary
{
    for (NSString *key in keys) {
        id value = dictionary[key];
        if ([value isKindOfClass:NSString.class]) {
            NSString *string =
                [(NSString *)value stringByTrimmingCharactersInSet:
                    NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (string.length > 0) {
                return string;
            }
        } else if ([value respondsToSelector:@selector(stringValue)]) {
            NSString *string = [[value stringValue] stringByTrimmingCharactersInSet:
                NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (string.length > 0) {
                return string;
            }
        }
    }
    return @"";
}

+ (NSArray<NSString *> *)buyAgainAccessoryIDsFromOrders:(NSArray<NSObject *> *)orders
                                                   limit:(NSInteger)limit
{
    NSMutableOrderedSet<NSString *> *ordered = [NSMutableOrderedSet orderedSet];
    NSArray<NSString *> *keys =
        @[@"itemID", @"itemId", @"accessoryID", @"accessoryId", @"productID",
          @"productId", @"id"];
    for (NSObject *object in orders ?: @[]) {
        if (![object isKindOfClass:PPOrder.class]) {
            continue;
        }
        PPOrder *order = (PPOrder *)object;
        for (id rawItem in order.items ?: @[]) {
            NSString *itemID = @"";
            if ([rawItem isKindOfClass:NSString.class]) {
                itemID = [(NSString *)rawItem stringByTrimmingCharactersInSet:
                    NSCharacterSet.whitespaceAndNewlineCharacterSet];
            } else if ([rawItem isKindOfClass:NSDictionary.class]) {
                NSDictionary *dictionary = (NSDictionary *)rawItem;
                itemID = [self stringValueForKeys:keys dictionary:dictionary];
                if (itemID.length == 0) {
                    for (NSString *nestedKey in @[@"product", @"item", @"accessory", @"snapshot"]) {
                        NSDictionary *nested =
                            [dictionary[nestedKey] isKindOfClass:NSDictionary.class]
                                ? dictionary[nestedKey]
                                : nil;
                        if (nested) {
                            itemID = [self stringValueForKeys:keys dictionary:nested];
                            if (itemID.length > 0) {
                                break;
                            }
                        }
                    }
                }
            }
            if (itemID.length > 0) {
                [ordered addObject:itemID];
            }
            if (limit > 0 && ordered.count >= limit) {
                return ordered.array;
            }
        }
    }
    return ordered.array;
}

+ (NSDictionary<NSString *, id> *)presentationForOrder:(NSObject *)object
{
    if (![object isKindOfClass:PPOrder.class]) {
        return @{};
    }
    PPOrder *order = (PPOrder *)object;
    NSString *statusKey = [self statusKeyForOrder:order];
    NSString *titleKey = @"Preparing for Shipment";
    NSString *hintKey = @"Home_CurrentOrdersProcessingHint";
    NSString *symbol = @"shippingbox.fill";
    double progress = 0.28;

    if ([statusKey isEqualToString:@"pending"]) {
        titleKey = @"order_placed_title";
        hintKey = @"Home_CurrentOrdersPendingHint";
        symbol = @"clock.fill";
        progress = 0.16;
    } else if ([statusKey isEqualToString:@"ready_for_delivery"]) {
        titleKey = @"Ready for Delivery";
        hintKey = @"Home_CurrentOrdersReadyHint";
        symbol = @"shippingbox.fill";
        progress = 0.46;
    } else if ([statusKey isEqualToString:@"delivery_partner_assigned"]) {
        titleKey = @"Delivery Partner Assigned";
        hintKey = @"Home_CurrentOrdersAssignedHint";
        symbol = @"person.crop.circle.badge.checkmark";
        progress = 0.62;
    } else if ([statusKey isEqualToString:@"on_the_way"]) {
        titleKey = @"On the Way";
        hintKey = @"Home_CurrentOrdersShippedHint";
        symbol = @"box.truck.fill";
        progress = 0.86;
    }

    NSInteger itemCount = 0;
    NSMutableArray<NSString *> *images = [NSMutableArray array];
    for (id rawItem in order.items ?: @[]) {
        if ([rawItem isKindOfClass:NSDictionary.class]) {
            NSDictionary *item = (NSDictionary *)rawItem;
            id rawQuantity = item[@"qty"] ?: item[@"quantity"];
            NSInteger quantity =
                [rawQuantity respondsToSelector:@selector(integerValue)]
                    ? [rawQuantity integerValue]
                    : 1;
            itemCount += MAX(quantity, 1);
            NSString *imageURL =
                [self stringValueForKeys:@[@"imageURL", @"imageUrl", @"image", @"thumbnailURL",
                                           @"thumbnailUrl"]
                              dictionary:item];
            if (imageURL.length > 0 && images.count < 3) {
                [images addObject:imageURL];
            }
        } else {
            itemCount += 1;
        }
    }

    NSString *statusTitle = kLang(titleKey) ?: titleKey;
    NSString *statusHint = kLang(hintKey) ?: (kLang(@"order_action_track_hint") ?: @"");
    NSString *reference = [order displayOrderReference] ?: order.orderNumber ?: order.orderId ?: @"";
    NSString *amount =
        [GM formatPrice:@(order.totalAmount)
           currencyCode:(order.currency.length > 0 ? order.currency : @"QAR")] ?: @"";
    return @{
        @"id" : order.orderId ?: @"",
        @"reference" : reference,
        @"statusKey" : statusKey,
        @"statusTitle" : statusTitle,
        @"statusHint" : statusHint,
        @"symbol" : symbol,
        @"progress" : @(progress),
        @"itemCount" : @(MAX(itemCount, 0)),
        @"amount" : amount,
        @"images" : images.copy,
    };
}

+ (NSDictionary<NSString *, id> *)categoryPresentationForObject:(NSObject *)object
{
    if (![object isKindOfClass:MainKindsModel.class]) {
        return @{};
    }
    MainKindsModel *model = (MainKindsModel *)object;
    NSString *localizedName = model.KindName ?: @"";
    if (localizedName.length == 0) {
        localizedName = Language.isRTL
            ? (model.KindNameAr ?: model.KindNameEn ?: @"")
            : (model.KindNameEn ?: model.KindNameAr ?: @"");
    }
    UIImage *localImage = model.KindImageFile ?: model.image;
    UIColor *accent = model.kindColor ?: UIColor.ppPrimary;
    NSMutableDictionary<NSString *, id> *presentation = [@{
        @"id" : model.documentID ?: @"",
        @"numericID" : @(model.ID),
        @"title" : localizedName,
        @"imageURL" : model.KindImageUrl ?: @"",
        @"accent" : accent,
        @"colorHex" : model.PetColor ?: @"",
    } mutableCopy];
    if (localImage) {
        presentation[@"localImage"] = localImage;
    }
    return presentation.copy;
}

+ (NSDictionary<NSString *, id> *)petPresentationForObject:(NSObject *)object
{
    if (![object isKindOfClass:PPPetProfile.class]) {
        return @{};
    }
    PPPetProfile *profile = (PPPetProfile *)object;
    NSString *category = [profile.categoryName
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
    NSString *breed = [profile.breed
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
    return @{
        @"id" : profile.petID ?: @"",
        @"name" : profile.name ?: @"",
        @"context" : breed.length > 0 ? breed : category,
        @"age" : profile.displayAgeText ?: @"",
        @"imageURL" : profile.imageURL ?: @"",
        @"categoryID" : @(profile.categoryId),
        @"isDefault" : @(profile.isDefaultPet),
    };
}

+ (NSDictionary<NSString *, id> *)promotionPresentationForObject:(NSObject *)object
{
    if (![object isKindOfClass:PPHomePromoCarouselCard.class]) {
        return @{};
    }
    PPHomePromoCarouselCard *card = (PPHomePromoCarouselCard *)object;
    return @{
        @"id" : card.cardID ?: @"",
        @"badge" : card.localizedBadgeText ?: @"",
        @"title" : card.localizedTitleText ?: @"",
        @"subtitle" : card.localizedSubtitleText ?: @"",
        @"primaryTitle" : card.localizedPrimaryButtonTitle ?: @"",
        @"secondaryTitle" : card.localizedSecondaryButtonTitle ?: @"",
        @"showsPrimary" : @(card.showsPrimaryButton),
        @"showsSecondary" : @(card.showsSecondaryButton),
        @"imageURL" : card.characterImageURL.absoluteString ?: @"",
        @"accentHex" : card.accentColorHex ?: @"",
        @"autoScrollInterval" : @(MAX(2.0, card.autoScrollInterval)),
    };
}

+ (NSDictionary<NSString *, id> *)reminderPresentationForObject:(NSObject *)object
{
    if (![object isKindOfClass:PPPetReminder.class]) {
        return @{};
    }
    PPPetReminder *reminder = (PPPetReminder *)object;
    NSMutableDictionary<NSString *, id> *presentation = [@{
        @"id" : reminder.reminderID ?: @"",
        @"petID" : reminder.petID ?: @"",
        @"title" : reminder.title ?: @"",
        @"typeText" : reminder.displayTypeText ?: @"",
        @"enabled" : @(reminder.enabled),
    } mutableCopy];
    if (reminder.fireDate) {
        presentation[@"fireDate"] = reminder.fireDate;
    }
    return presentation.copy;
}

+ (NSInteger)currentCartItemCount
{
    Class cartManagerClass = NSClassFromString(@"CartManager");
    SEL sharedSelector = NSSelectorFromString(@"sharedManager");
    SEL totalSelector = NSSelectorFromString(@"totalItemsCount");
    if (!cartManagerClass ||
        ![cartManagerClass respondsToSelector:sharedSelector]) {
        return 0;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    id manager = [cartManagerClass performSelector:sharedSelector];
#pragma clang diagnostic pop
    if (!manager || ![manager respondsToSelector:totalSelector]) {
        return 0;
    }
    NSInteger (*totalIMP)(id, SEL) =
        (NSInteger (*)(id, SEL))[manager methodForSelector:totalSelector];
    return totalIMP ? MAX(0, totalIMP(manager, totalSelector)) : 0;
}

- (void)publishError:(NSError *)error source:(PPHomeBridgeSource)source
{
    if (!error) {
        return;
    }
    NSLog(@"[PurePetsPulse] source=%ld error=%@", (long)source,
          error.localizedDescription ?: @"Unknown");
    if (self.sourceDidFail) {
        self.sourceDidFail(source, error);
    }
}

@end
