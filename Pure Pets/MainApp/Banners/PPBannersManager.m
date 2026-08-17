//
//  PPBannersManager.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 09/09/2025.
//

#import "PPBannersManager.h"
#import "PPBannerViewModel.h"
#import "MainBannerModel.h"
#import "Language.h"
#import "PPFirebaseSessionBridge.h"

static NSString * const kCachedBannerGroupsKey = @"cachedBannerGroups";
@interface PPBannersManager ()
@property (nonatomic, strong) FIRFirestore *db;
@property (nonatomic, strong) id<FIRListenerRegistration> bannersListener;
@property (nonatomic, copy, readwrite) NSArray<MainBannerModel *> *bannerGroups;
@end

#pragma mark - Home Promo Carousel (V2 HTTP surface)

static NSString * const kPPHomePromoCarouselEndpoint =
    @"https://us-central1-pure-pets-49199.cloudfunctions.net/getMobileContentSurface/marketplace.promoRail";
static NSString * const kPPHomePromoCarouselCacheKey = @"cachedHomePromoCarouselCards";

static NSString *PPHomePromoSafeString(id value) {
    if ([value isKindOfClass:NSString.class]) {
        return (NSString *)value;
    }
    if ([value respondsToSelector:@selector(stringValue)]) {
        return [value stringValue] ?: @"";
    }
    return @"";
}

static BOOL PPHomePromoBoolValue(id value, BOOL defaultValue) {
    if ([value isKindOfClass:NSNull.class] || value == nil) {
        return defaultValue;
    }
    if ([value isKindOfClass:NSNumber.class]) {
        return [value boolValue];
    }
    if ([value isKindOfClass:NSString.class]) {
        NSString *s = [PPHomePromoSafeString(value) lowercaseString];
        if ([s isEqualToString:@"true"] || [s isEqualToString:@"yes"] || [s isEqualToString:@"1"]) return YES;
        if ([s isEqualToString:@"false"] || [s isEqualToString:@"no"] || [s isEqualToString:@"0"]) return NO;
    }
    return defaultValue;
}

static NSInteger PPHomePromoIntegerValue(id value, NSInteger defaultValue) {
    if ([value isKindOfClass:NSNumber.class]) return [value integerValue];
    if ([value isKindOfClass:NSString.class]) return [value integerValue];
    return defaultValue;
}

static PPBannerTextStyle PPHomePromoTextStyleValue(id value, PPBannerTextStyle defaultValue) {
    NSInteger raw = PPHomePromoIntegerValue(value, defaultValue);
    return (raw == PPBannerTextStyleBlack) ? PPBannerTextStyleBlack : PPBannerTextStyleWhite;
}

static NSURL * _Nullable PPHomePromoURLValue(id value) {
    NSString *raw = PPHomePromoSafeString(value);
    if (raw.length == 0) return nil;
    return [NSURL URLWithString:raw];
}

static PPBannerOnTapAction PPHomePromoTapActionValue(id value, PPBannerOnTapAction defaultValue) {
    if ([value isKindOfClass:NSNumber.class]) {
        return (PPBannerOnTapAction)[value integerValue];
    }
    if ([value isKindOfClass:NSString.class]) {
        NSString *s = [PPHomePromoSafeString(value) lowercaseString];
        if ([s isEqualToString:@"ppbannerontapviewaccessory"] || [s isEqualToString:@"viewaccessory"]) {
            return PPBannerOnTapViewAccessory;
        }
        if ([s isEqualToString:@"ppbannerontapviewad"] || [s isEqualToString:@"viewad"]) {
            return PPBannerOnTapViewAd;
        }
        if ([s isEqualToString:@"ppbannerontapopenurl"] || [s isEqualToString:@"openurl"]) {
            return PPBannerOnTapOpenUrl;
        }
        if ([s isEqualToString:@"ppbannerontapcallphonenumber"] || [s isEqualToString:@"callphone"] || [s isEqualToString:@"call"]) {
            return PPBannerOnTapCallPhoneNumber;
        }
        if ([s isEqualToString:@"ppbannerontapwhatsapp"] || [s isEqualToString:@"whatsapp"]) {
            return PPBannerOnTapWhatsApp;
        }
    }
    return defaultValue;
}

static NSString *PPHomePromoLocalizedString(NSString *en, NSString *ar) {
    BOOL prefersRTL = Language.isRTL;
    if (prefersRTL && ar.length > 0) return ar;
    if (!prefersRTL && en.length > 0) return en;
    return ar.length > 0 ? ar : en;
}

@implementation PPHomePromoCarouselCard

- (instancetype)init
{
    self = [super init];
    if (self) {
        _cardID = @"";
        _visible = YES;
        _sortOrder = 0;
        _badgeTextEn = @"";
        _badgeTextAr = @"";
        _titleTextEn = @"";
        _titleTextAr = @"";
        _subtitleTextEn = @"";
        _subtitleTextAr = @"";
        _primaryButtonTitleEn = @"";
        _primaryButtonTitleAr = @"";
        _secondaryButtonTitleEn = @"";
        _secondaryButtonTitleAr = @"";
        _hidePrimaryButton = NO;
        _hideSecondaryButton = YES;
        _startColorHex = @"#F6A43A";
        _endColorHex = @"#F08A2A";
        _accentColorHex = @"#FFD08A";
        _textStyle = PPBannerTextStyleWhite;
        _cardTapAction = PPBannerOnTapOpenUrl;
        _cardTapValue = @"";
        _primaryButtonTapAction = PPBannerOnTapOpenUrl;
        _primaryButtonTapValue = @"";
        _secondaryButtonTapAction = PPBannerOnTapOpenUrl;
        _secondaryButtonTapValue = @"";
        _autoScrollInterval = 4.8;
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict documentID:(NSString *)documentID
{
    self = [self init];
    if (!self) return nil;

    if (![dict isKindOfClass:NSDictionary.class]) {
        return self;
    }

    _cardID = [PPHomePromoSafeString(dict[@"id"]) copy];
    if (_cardID.length == 0) {
        _cardID = [PPHomePromoSafeString(dict[@"CardID"]) copy];
    }
    if (_cardID.length == 0) {
        _cardID = [PPHomePromoSafeString(dict[@"ChildsPannerID"] ?: dict[@"ChildBannerID"] ?: dict[@"bannerID"]) copy];
    }
    if (_cardID.length == 0) {
        _cardID = [PPHomePromoSafeString(documentID) copy];
    }

    _visible = PPHomePromoBoolValue(dict[@"visible"], YES);
    if (dict[@"isVisible"] != nil) {
        _visible = PPHomePromoBoolValue(dict[@"isVisible"], _visible);
    }

    _sortOrder = PPHomePromoIntegerValue(dict[@"sortOrder"], 0);
    if (dict[@"SortOrder"] != nil) {
        _sortOrder = PPHomePromoIntegerValue(dict[@"SortOrder"], _sortOrder);
    }

    _badgeTextEn = [PPHomePromoSafeString(dict[@"badgeTextEn"] ?: dict[@"tagTextEn"] ?: dict[@"badgeText"]) copy];
    _badgeTextAr = [PPHomePromoSafeString(dict[@"badgeTextAr"] ?: dict[@"tagTextAr"]) copy];

    _titleTextEn = [PPHomePromoSafeString(dict[@"titleTextEn"] ?: dict[@"titleEn"] ?: dict[@"title"]) copy];
    _titleTextAr = [PPHomePromoSafeString(dict[@"titleTextAr"] ?: dict[@"titleAr"]) copy];

    _subtitleTextEn = [PPHomePromoSafeString(dict[@"subtitleTextEn"] ?: dict[@"descTextEn"] ?: dict[@"subtitle"]) copy];
    _subtitleTextAr = [PPHomePromoSafeString(dict[@"subtitleTextAr"] ?: dict[@"descTextAr"]) copy];

    _primaryButtonTitleEn = [PPHomePromoSafeString(dict[@"primaryButtonTitleEn"] ?: dict[@"buttonTitleEn"] ?: dict[@"primaryButtonTitle"]) copy];
    _primaryButtonTitleAr = [PPHomePromoSafeString(dict[@"primaryButtonTitleAr"] ?: dict[@"buttonTitleAr"]) copy];
    _secondaryButtonTitleEn = [PPHomePromoSafeString(dict[@"secondaryButtonTitleEn"] ?: dict[@"secondaryTitleEn"] ?: dict[@"secondaryButtonTitle"]) copy];
    _secondaryButtonTitleAr = [PPHomePromoSafeString(dict[@"secondaryButtonTitleAr"] ?: dict[@"secondaryTitleAr"]) copy];

    _hidePrimaryButton = PPHomePromoBoolValue(dict[@"hidePrimaryButton"], NO);
    if (dict[@"showPrimaryButton"] != nil) {
        _hidePrimaryButton = !PPHomePromoBoolValue(dict[@"showPrimaryButton"], YES);
    }

    _hideSecondaryButton = PPHomePromoBoolValue(dict[@"hideSecondaryButton"], YES);
    if (dict[@"showSecondaryButton"] != nil) {
        _hideSecondaryButton = !PPHomePromoBoolValue(dict[@"showSecondaryButton"], NO);
    }

    NSURL *imageURL = PPHomePromoURLValue(dict[@"productImageURL"]);
    if (!imageURL) imageURL = PPHomePromoURLValue(dict[@"characterImageURL"]);
    if (!imageURL) imageURL = PPHomePromoURLValue(dict[@"foregroundImageURL"]);
    if (!imageURL) imageURL = PPHomePromoURLValue(dict[@"sampleImageURL"]);
    if (!imageURL) imageURL = PPHomePromoURLValue(dict[@"badgeImageURL"]);
    _characterImageURL = [imageURL copy];
    _backgroundImageURL = [PPHomePromoURLValue(dict[@"backgroundImageURL"]) copy];

    _startColorHex = PPHomePromoSafeString(dict[@"startColorHex"] ?: dict[@"backgroundStartColorHex"] ?: dict[@"gradientStartHex"]);
    if (_startColorHex.length == 0) _startColorHex = @"#F6A43A";
    _endColorHex = PPHomePromoSafeString(dict[@"endColorHex"] ?: dict[@"backgroundEndColorHex"] ?: dict[@"gradientEndHex"]);
    if (_endColorHex.length == 0) _endColorHex = @"#F08A2A";
    _accentColorHex = PPHomePromoSafeString(dict[@"accentColorHex"] ?: dict[@"shapeColorHex"]);
    if (_accentColorHex.length == 0) _accentColorHex = @"#75666B";
    _textStyle = PPHomePromoTextStyleValue(dict[@"pannerTextStyle"] ?: dict[@"textStyle"] ?: dict[@"bannerTextStyle"],
                                           _textStyle);

    _cardTapAction = PPHomePromoTapActionValue(dict[@"cardTapAction"], _cardTapAction);
    if (dict[@"pannerOnTapAction"] != nil) {
        _cardTapAction = PPHomePromoTapActionValue(dict[@"pannerOnTapAction"], _cardTapAction);
    }
    _cardTapValue = [PPHomePromoSafeString(dict[@"cardTapValue"] ?: dict[@"pannerOnTapValue"] ?: dict[@"onTapValue"]) copy];

    _primaryButtonTapAction = PPHomePromoTapActionValue(dict[@"primaryButtonTapAction"], _cardTapAction);
    _primaryButtonTapValue = [PPHomePromoSafeString(dict[@"primaryButtonTapValue"] ?: dict[@"buttonTapValue"]) copy];
    if (_primaryButtonTapValue.length == 0) {
        _primaryButtonTapValue = [_cardTapValue copy];
    }

    _secondaryButtonTapAction = PPHomePromoTapActionValue(dict[@"secondaryButtonTapAction"], _cardTapAction);
    _secondaryButtonTapValue = [PPHomePromoSafeString(dict[@"secondaryButtonTapValue"]) copy];
    if (_secondaryButtonTapValue.length == 0) {
        _secondaryButtonTapValue = [_cardTapValue copy];
    }

    // PPBannerOnTapViewAccessory requires a non-empty value (accessory ID).
    // If the value is empty, fall back to PPBannerOnTapOpenUrl so taps never
    // navigate to a non-existent accessory.
    if (_cardTapAction == PPBannerOnTapViewAccessory && _cardTapValue.length == 0) {
        _cardTapAction = PPBannerOnTapOpenUrl;
    }
    if (_primaryButtonTapAction == PPBannerOnTapViewAccessory && _primaryButtonTapValue.length == 0) {
        _primaryButtonTapAction = PPBannerOnTapOpenUrl;
    }
    if (_secondaryButtonTapAction == PPBannerOnTapViewAccessory && _secondaryButtonTapValue.length == 0) {
        _secondaryButtonTapAction = PPBannerOnTapOpenUrl;
    }

    if (dict[@"autoScrollInterval"] != nil) {
        id v = dict[@"autoScrollInterval"];
        if ([v respondsToSelector:@selector(doubleValue)]) {
            _autoScrollInterval = MAX(2.0, [v doubleValue]);
        }
    }
    if (_autoScrollInterval <= 0) {
        _autoScrollInterval = 4.8;
    }

    return self;
}

- (NSDictionary *)toDictionary
{
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"id"] = PPHomePromoSafeString(self.cardID);
    d[@"visible"] = @(self.visible);
    d[@"sortOrder"] = @(self.sortOrder);
    d[@"badgeTextEn"] = PPHomePromoSafeString(self.badgeTextEn);
    d[@"badgeTextAr"] = PPHomePromoSafeString(self.badgeTextAr);
    d[@"titleTextEn"] = PPHomePromoSafeString(self.titleTextEn);
    d[@"titleTextAr"] = PPHomePromoSafeString(self.titleTextAr);
    d[@"subtitleTextEn"] = PPHomePromoSafeString(self.subtitleTextEn);
    d[@"subtitleTextAr"] = PPHomePromoSafeString(self.subtitleTextAr);
    d[@"primaryButtonTitleEn"] = PPHomePromoSafeString(self.primaryButtonTitleEn);
    d[@"primaryButtonTitleAr"] = PPHomePromoSafeString(self.primaryButtonTitleAr);
    d[@"secondaryButtonTitleEn"] = PPHomePromoSafeString(self.secondaryButtonTitleEn);
    d[@"secondaryButtonTitleAr"] = PPHomePromoSafeString(self.secondaryButtonTitleAr);
    d[@"hidePrimaryButton"] = @(self.hidePrimaryButton);
    d[@"hideSecondaryButton"] = @(self.hideSecondaryButton);
    d[@"productImageURL"] = self.productImageURL.absoluteString ?: @"";
    d[@"characterImageURL"] = self.characterImageURL.absoluteString ?: @"";
    d[@"backgroundImageURL"] = self.backgroundImageURL.absoluteString ?: @"";
    d[@"startColorHex"] = PPHomePromoSafeString(self.startColorHex);
    d[@"endColorHex"] = PPHomePromoSafeString(self.endColorHex);
    d[@"accentColorHex"] = PPHomePromoSafeString(self.accentColorHex);
    d[@"pannerTextStyle"] = @(self.textStyle);
    d[@"cardTapAction"] = @(self.cardTapAction);
    d[@"cardTapValue"] = PPHomePromoSafeString(self.cardTapValue);
    d[@"primaryButtonTapAction"] = @(self.primaryButtonTapAction);
    d[@"primaryButtonTapValue"] = PPHomePromoSafeString(self.primaryButtonTapValue);
    d[@"secondaryButtonTapAction"] = @(self.secondaryButtonTapAction);
    d[@"secondaryButtonTapValue"] = PPHomePromoSafeString(self.secondaryButtonTapValue);
    d[@"autoScrollInterval"] = @(MAX(2.0, self.autoScrollInterval));
    return d;
}

- (NSURL *)productImageURL
{
    return self.characterImageURL;
}

- (void)setProductImageURL:(NSURL *)productImageURL
{
    self.characterImageURL = productImageURL;
}

- (NSString *)localizedBadgeText { return PPHomePromoLocalizedString(self.badgeTextEn, self.badgeTextAr); }
- (NSString *)localizedTitleText { return PPHomePromoLocalizedString(self.titleTextEn, self.titleTextAr); }
- (NSString *)localizedSubtitleText { return PPHomePromoLocalizedString(self.subtitleTextEn, self.subtitleTextAr); }
- (NSString *)localizedPrimaryButtonTitle { return PPHomePromoLocalizedString(self.primaryButtonTitleEn, self.primaryButtonTitleAr); }
- (NSString *)localizedSecondaryButtonTitle { return PPHomePromoLocalizedString(self.secondaryButtonTitleEn, self.secondaryButtonTitleAr); }

- (BOOL)showsPrimaryButton
{
    return !self.hidePrimaryButton && [self localizedPrimaryButtonTitle].length > 0;
}

- (BOOL)showsSecondaryButton
{
    return !self.hideSecondaryButton && [self localizedSecondaryButtonTitle].length > 0;
}

@end

static NSDictionary *PPHomePromoDictionaryValue(id value)
{
    return [value isKindOfClass:NSDictionary.class] ? value : @{};
}

static NSString *PPHomePromoLocalizedContentValue(NSDictionary *content,
                                                  NSString *locale,
                                                  NSString *key)
{
    NSDictionary *localized = PPHomePromoDictionaryValue(content[locale]);
    NSString *value = PPHomePromoSafeString(localized[key]);
    if (value.length > 0) {
        return value;
    }

    NSString *fallbackLocale = [locale isEqualToString:@"ar"] ? @"en" : @"ar";
    localized = PPHomePromoDictionaryValue(content[fallbackLocale]);
    return PPHomePromoSafeString(localized[key]);
}

static NSString *PPHomePromoAppVersion(void)
{
    NSString *version = PPHomePromoSafeString(
        [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]);
    if (version.length == 0) {
        version = PPHomePromoSafeString(
            [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]);
    }
    return version.length > 0 ? version : @"0.0.0";
}

static NSURL *PPHomePromoRequestURL(void)
{
    NSURLComponents *components =
        [NSURLComponents componentsWithString:kPPHomePromoCarouselEndpoint];
    if (!components) {
        return nil;
    }

    NSString *locale = Language.isRTL ? @"ar" : @"en";
    components.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"locale" value:locale],
        [NSURLQueryItem queryItemWithName:@"platform" value:@"ios"],
        [NSURLQueryItem queryItemWithName:@"appVersion" value:PPHomePromoAppVersion()],
    ];
    return components.URL;
}

static BOOL PPHomePromoIsHTTPSURL(NSString *value)
{
    NSURL *url = [NSURL URLWithString:value];
    return url != nil &&
           [url.scheme.lowercaseString isEqualToString:@"https"] &&
           url.host.length > 0;
}

static BOOL PPHomePromoApplyResolvedAction(PPHomePromoCarouselCard *card,
                                            NSDictionary *action)
{
    NSString *type = [PPHomePromoSafeString(action[@"type"]) lowercaseString];
    NSString *value = @"";
    PPBannerOnTapAction legacyAction = PPBannerOnTapOpenUrl;
    BOOL supported = NO;

    if ([type isEqualToString:@"web"]) {
        value = PPHomePromoSafeString(action[@"url"]);
        supported = PPHomePromoIsHTTPSURL(value);
    } else if ([type isEqualToString:@"applink"]) {
        value = PPHomePromoSafeString(action[@"universalLink"]);
        if (!PPHomePromoIsHTTPSURL(value)) {
            value = PPHomePromoSafeString(action[@"fallbackUrl"]);
        }
        supported = PPHomePromoIsHTTPSURL(value);
    } else if ([type isEqualToString:@"whatsapp"]) {
        value = PPHomePromoSafeString(action[@"phoneNumber"]);
        legacyAction = PPBannerOnTapWhatsApp;
        supported = value.length > 0;
    } else if ([type isEqualToString:@"category"]) {
        NSString *targetID = PPHomePromoSafeString(action[@"targetId"]);
        NSInteger categoryID = targetID.integerValue;
        if (categoryID > 0 &&
            [targetID isEqualToString:[NSString stringWithFormat:@"%ld", (long)categoryID]]) {
            value = targetID;
            legacyAction = PPBannerOnTapViewAccessory;
            supported = YES;
        }
    }

    card.cardTapAction = supported ? legacyAction : PPBannerOnTapOpenUrl;
    card.cardTapValue = supported ? value : @"";
    card.primaryButtonTapAction = card.cardTapAction;
    card.primaryButtonTapValue = card.cardTapValue;
    card.hidePrimaryButton = !supported ||
        (card.localizedPrimaryButtonTitle.length == 0);
    card.secondaryButtonTapAction = PPBannerOnTapOpenUrl;
    card.secondaryButtonTapValue = @"";
    card.hideSecondaryButton = YES;
    return supported;
}

static PPHomePromoCarouselCard *PPHomePromoCardFromRemoteDictionary(NSDictionary *rawCard,
                                                                     NSDictionary *surface)
{
    NSDictionary *content = PPHomePromoDictionaryValue(rawCard[@"content"]);
    NSString *titleEn = PPHomePromoLocalizedContentValue(content, @"en", @"title");
    NSString *titleAr = PPHomePromoLocalizedContentValue(content, @"ar", @"title");
    if (titleEn.length == 0 && titleAr.length == 0) {
        return nil;
    }

    PPHomePromoCarouselCard *card = [PPHomePromoCarouselCard new];
    card.cardID = PPHomePromoSafeString(rawCard[@"id"]);
    card.visible = YES;
    card.sortOrder = MAX(0, [rawCard[@"position"] integerValue]);
    card.badgeTextEn = PPHomePromoLocalizedContentValue(content, @"en", @"eyebrow");
    card.badgeTextAr = PPHomePromoLocalizedContentValue(content, @"ar", @"eyebrow");
    card.titleTextEn = titleEn;
    card.titleTextAr = titleAr;
    card.subtitleTextEn = PPHomePromoLocalizedContentValue(content, @"en", @"subtitle");
    card.subtitleTextAr = PPHomePromoLocalizedContentValue(content, @"ar", @"subtitle");
    card.primaryButtonTitleEn = PPHomePromoLocalizedContentValue(content, @"en", @"cta");
    card.primaryButtonTitleAr = PPHomePromoLocalizedContentValue(content, @"ar", @"cta");

    NSDictionary *media = PPHomePromoDictionaryValue(rawCard[@"media"]);
    NSString *imageURLString = PPHomePromoSafeString(media[@"imageUrl"]);
    if (PPHomePromoIsHTTPSURL(imageURLString)) {
        card.characterImageURL = [NSURL URLWithString:imageURLString];
    }

    NSTimeInterval autoAdvance = [surface[@"autoAdvanceSeconds"] doubleValue];
    card.autoScrollInterval = MAX(2.0, autoAdvance > 0.0 ? autoAdvance : 6.0);
    PPHomePromoApplyResolvedAction(card,
                                   PPHomePromoDictionaryValue(rawCard[@"action"]));
    return card;
}

@interface PPHomePromoCarouselManager ()
@property (nonatomic, strong, nullable) NSURLSessionDataTask *contentTask;
@property (nonatomic, assign) NSUInteger requestGeneration;
@property (nonatomic, copy, nullable) NSString *etag;
@property (nonatomic, copy, readwrite) NSArray<PPHomePromoCarouselCard *> *cards;

- (NSArray<PPHomePromoCarouselCard *> *)cardsFromRemotePayload:(NSDictionary *)payload;
- (void)fetchRemoteCardsWithCompletion:(void (^)(NSArray<PPHomePromoCarouselCard *> * _Nullable cards,
                                                 NSError * _Nullable error))completion;
@end

@implementation PPHomePromoCarouselManager

+ (instancetype)sharedManager
{
    static PPHomePromoCarouselManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[PPHomePromoCarouselManager alloc] initPrivate];
    });
    return instance;
}

- (instancetype)initPrivate
{
    self = [super init];
    if (self) {
        _cards = @[];
        _requestGeneration = 0;
    }
    return self;
}

- (instancetype)init
{
    @throw [NSException exceptionWithName:@"Singleton"
                                   reason:@"Use +[PPHomePromoCarouselManager sharedManager]."
                                 userInfo:nil];
    return nil;
}

- (NSArray<PPHomePromoCarouselCard *> *)loadCardsFromCache
{
    NSArray *raw = [[NSUserDefaults standardUserDefaults] objectForKey:kPPHomePromoCarouselCacheKey];
    if (![raw isKindOfClass:NSArray.class]) return @[];

    NSMutableArray<PPHomePromoCarouselCard *> *out = [NSMutableArray arrayWithCapacity:raw.count];
    for (NSDictionary *dict in raw) {
        if (![dict isKindOfClass:NSDictionary.class]) continue;
        PPHomePromoCarouselCard *card = [[PPHomePromoCarouselCard alloc] initWithDictionary:dict documentID:nil];
        if (card) [out addObject:card];
    }
    return [self sortedVisibleCardsFromArray:out];
}

- (void)saveCardsToCache
{
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:self.cards.count];
    for (PPHomePromoCarouselCard *card in self.cards) {
        [arr addObject:[card toDictionary]];
    }
    [[NSUserDefaults standardUserDefaults] setObject:arr forKey:kPPHomePromoCarouselCacheKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSArray<PPHomePromoCarouselCard *> *)sortedVisibleCardsFromArray:(NSArray<PPHomePromoCarouselCard *> *)input
{
    NSPredicate *visiblePredicate = [NSPredicate predicateWithBlock:^BOOL(PPHomePromoCarouselCard *card, NSDictionary *bindings) {
        (void)bindings;
        return card.visible;
    }];
    NSArray<PPHomePromoCarouselCard *> *visible = [input filteredArrayUsingPredicate:visiblePredicate];
    return [visible sortedArrayUsingComparator:^NSComparisonResult(PPHomePromoCarouselCard *a, PPHomePromoCarouselCard *b) {
        if (a.sortOrder < b.sortOrder) return NSOrderedAscending;
        if (a.sortOrder > b.sortOrder) return NSOrderedDescending;
        return [a.cardID compare:b.cardID options:NSCaseInsensitiveSearch];
    }];
}

- (NSArray<PPHomePromoCarouselCard *> *)cardsFromRemotePayload:(NSDictionary *)payload
{
    NSArray *items = [payload[@"items"] isKindOfClass:NSArray.class]
        ? payload[@"items"]
        : @[];
    NSDictionary *surface = PPHomePromoDictionaryValue(payload[@"surface"]);
    NSMutableArray<PPHomePromoCarouselCard *> *cards =
        [NSMutableArray arrayWithCapacity:items.count];

    for (id rawItem in items) {
        if (![rawItem isKindOfClass:NSDictionary.class]) {
            continue;
        }
        PPHomePromoCarouselCard *card =
            PPHomePromoCardFromRemoteDictionary(rawItem, surface);
        if (card) {
            [cards addObject:card];
        }
    }
    return [self sortedVisibleCardsFromArray:cards];
}

- (void)fetchRemoteCardsWithCompletion:(void (^)(NSArray<PPHomePromoCarouselCard *> * _Nullable cards,
                                                 NSError * _Nullable error))completion
{
    NSURL *url = PPHomePromoRequestURL();
    if (!url) {
        NSError *error = [NSError errorWithDomain:@"PPHomePromoCarousel"
                                             code:-1
                                         userInfo:@{
            NSLocalizedDescriptionKey:
                [PPFirebaseSessionBridge publicMessageForText:nil
                                                  fallbackKey:@"SomethingWentWrong"]
        }];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return;
    }

    NSUInteger generation = self.requestGeneration;
    NSMutableURLRequest *request =
        [NSMutableURLRequest requestWithURL:url
                                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                            timeoutInterval:30.0];
    request.HTTPMethod = @"GET";
    if (self.etag.length > 0) {
        [request setValue:self.etag forHTTPHeaderField:@"If-None-Match"];
    }

    __weak typeof(self) weakSelf = self;
    [PPFirebaseSessionBridge authorizeRequest:request
                                      options:PPFirebaseSessionAuthorizationOptionRequireSignedIn |
                                              PPFirebaseSessionAuthorizationOptionIncludeAppCheck
                                    completion:^(NSError * _Nullable authError) {
        __strong typeof(weakSelf) self = weakSelf;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self || generation != self.requestGeneration) {
                return;
            }
            if (authError) {
                if (completion) {
                    completion(nil, authError);
                }
                return;
            }

            NSURLSessionDataTask *task =
                [NSURLSession.sharedSession
                    dataTaskWithRequest:request
                      completionHandler:^(NSData * _Nullable data,
                                          NSURLResponse * _Nullable response,
                                          NSError * _Nullable error) {
                __strong typeof(weakSelf) taskSelf = weakSelf;
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (!taskSelf || generation != taskSelf.requestGeneration) {
                        return;
                    }
                    taskSelf.contentTask = nil;

                    if (error) {
                        if (completion) {
                            completion(nil,
                                       [PPFirebaseSessionBridge
                                           publicErrorForError:error
                                                   fallbackKey:@"SomethingWentWrong"]);
                        }
                        return;
                    }

                    NSHTTPURLResponse *httpResponse =
                        [response isKindOfClass:NSHTTPURLResponse.class]
                            ? (NSHTTPURLResponse *)response
                            : nil;
                    NSInteger statusCode = httpResponse.statusCode;
                    NSString *responseETag =
                        [httpResponse valueForHTTPHeaderField:@"ETag"];
                    if (responseETag.length > 0) {
                        taskSelf.etag = responseETag;
                    }
                    if (statusCode == 304) {
                        if (completion) {
                            completion(taskSelf.cards ?: @[], nil);
                        }
                        return;
                    }
                    if (statusCode < 200 || statusCode >= 300) {
                        NSString *fallbackKey = statusCode == 401
                            ? @"pp_auth_session_refresh_failed"
                            : statusCode == 403
                                ? @"pp_app_check_unavailable"
                                : @"SomethingWentWrong";
                        NSError *statusError = [NSError
                            errorWithDomain:@"PPHomePromoCarousel"
                                        code:statusCode
                                    userInfo:@{
                            NSLocalizedDescriptionKey:
                                [PPFirebaseSessionBridge
                                    publicMessageForText:nil
                                             fallbackKey:fallbackKey]
                        }];
                        if (completion) {
                            completion(nil, statusError);
                        }
                        return;
                    }

                    NSError *jsonError = nil;
                    id object = data.length > 0
                        ? [NSJSONSerialization JSONObjectWithData:data
                                                           options:0
                                                             error:&jsonError]
                        : nil;
                    if (![object isKindOfClass:NSDictionary.class]) {
                        if (completion) {
                            completion(nil,
                                       [PPFirebaseSessionBridge
                                           publicErrorForError:jsonError
                                                   fallbackKey:@"SomethingWentWrong"]);
                        }
                        return;
                    }

                    if (completion) {
                        completion([taskSelf cardsFromRemotePayload:object], nil);
                    }
                });
            }];
            self.contentTask = task;
            [task resume];
        });
    }];
}

- (void)startListeningWithCompletion:(void (^)(NSArray<PPHomePromoCarouselCard *> * _Nullable cards,
                                               NSError * _Nullable error))completion
{
    [self stopListening];
    self.cards = [self loadCardsFromCache];
    NSArray<PPHomePromoCarouselCard *> *cachedCards = self.cards;
    if (cachedCards.count > 0 && completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(cachedCards, nil);
        });
    }

    __weak typeof(self) weakSelf = self;
    [self fetchRemoteCardsWithCompletion:^(NSArray<PPHomePromoCarouselCard *> * _Nullable cards,
                                           NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        if (cards) {
            self.cards = cards;
            [self saveCardsToCache];
            if (completion) {
                completion(self.cards, nil);
            }
        } else if (self.cards.count == 0 && completion) {
            // A cached surface is usable offline. Only surface an error when
            // there is no content that can be shown at all.
            completion(nil, error);
        }
    }];
}

- (void)fetchOnceWithCompletion:(void (^)(NSArray<PPHomePromoCarouselCard *> * _Nullable cards,
                                          NSError * _Nullable error))completion
{
    [self.contentTask cancel];
    self.contentTask = nil;
    self.requestGeneration += 1;

    __weak typeof(self) weakSelf = self;
    [self fetchRemoteCardsWithCompletion:^(NSArray<PPHomePromoCarouselCard *> * _Nullable cards,
                                           NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        if (cards) {
            self.cards = cards;
            [self saveCardsToCache];
        }
        if (completion) {
            completion(cards, error);
        }
    }];
}

- (void)stopListening
{
    self.requestGeneration += 1;
    [self.contentTask cancel];
    self.contentTask = nil;
}

@end

@implementation PPBannersManager

- (NSArray<MainBannerModel *> *)loadbannerGroupsFromCache {
    NSArray *raw = [[NSUserDefaults standardUserDefaults] objectForKey:kCachedBannerGroupsKey];
    if (![raw isKindOfClass:NSArray.class]) return @[];
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:raw.count];
    for (NSDictionary *mainKind in raw) {
        MainBannerModel *u = [[MainBannerModel alloc] initWithDictionary:mainKind];
        if (u) [out addObject:u];
    }
    NSLog(@"[Cache] 📥 Loaded %lu bannerGroups from cache.", (unsigned long)out.count);
    return out;
}

- (void)savebannerGroupsToCache {
    NSMutableArray *arr = [NSMutableArray array];
    for (MainBannerModel *mainKind in self.bannerGroups) {
        if ([mainKind respondsToSelector:@selector(toDictionary)]) {
            [arr addObject:[mainKind toDictionary]];
        }
    }
    [[NSUserDefaults standardUserDefaults] setObject:arr forKey:kCachedBannerGroupsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (instancetype)sharedManager {
    static PPBannersManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[PPBannersManager alloc] initPrivate];
    });
    return instance;
}

- (instancetype)initPrivate {
    if (self = [super init]) {
        _db = [FIRFirestore firestore];
        _bannerGroups = @[];
    }
    return self;
}

- (instancetype)init {
    @throw [NSException exceptionWithName:@"Singleton"
                                   reason:@"Use +[PPBannersManager sharedManager] to get the singleton instance."
                                 userInfo:nil];
    return nil;
}

- (void)startListeningForBannersWithCompletion:(void (^)(NSArray<MainBannerModel *> * _Nullable bannerGroups, NSError * _Nullable error))completion {
    self.bannerGroups = [self loadbannerGroupsFromCache].mutableCopy;
    if (!self.bannerGroups) {
        self.bannerGroups = [NSMutableArray array];
    }
    
    BOOL hasCache = (self.bannerGroups.count > 0);
    if (hasCache) {
        if (completion) {
            completion(self.bannerGroups, nil);
        }
    }
    
    [self stopListening];
    
    __weak typeof(self) weakSelf = self;
    self.bannersListener = [[_db collectionWithPath:@"MainBannersViewsCol"] 
        addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (error) {
                NSArray<MainBannerModel *> *cachedGroups = [strongSelf loadbannerGroupsFromCache];
                if (cachedGroups.count > 0) {
                    strongSelf.bannerGroups = cachedGroups;
                    if (completion) {
                        completion(strongSelf.bannerGroups, nil);
                    }
                    return;
                }
                if (completion) {
                    completion(nil, error);
                }
                return;
            }
            NSMutableArray<MainBannerModel *> *fetchedGroups = [NSMutableArray array];
            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                NSDictionary *data = doc.data;
                if (!data) continue;
                MainBannerModel *model = [[MainBannerModel alloc] initWithDictionary:doc.data];
                model.bannerViewID = doc.documentID;
                if (model.bannerViewVisible) {
                    [fetchedGroups addObject:model];
                }
            }
            strongSelf.bannerGroups = [fetchedGroups copy];
            [strongSelf savebannerGroupsToCache];
            if (completion) {
                completion(strongSelf.bannerGroups, nil);
            }
    }];
}

- (void)fetchBannersOnceWithCompletion:(void (^)(NSArray<MainBannerModel *> * _Nullable bannerGroups, NSError * _Nullable error))completion {
    FIRCollectionReference *collection = [self.db collectionWithPath:@"MainBannersViewsCol"];
    
    [collection getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            NSArray<MainBannerModel *> *cachedGroups = [self loadbannerGroupsFromCache];
            if (cachedGroups.count > 0) {
                self.bannerGroups = cachedGroups;
                if (completion) completion(self.bannerGroups, nil);
                return;
            }
            if (completion) completion(nil, error);
            return;
        }
        
        NSMutableArray<MainBannerModel *> *fetchedGroups = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            NSDictionary *data = doc.data;
            if (!data) continue;
            
            MainBannerModel *model = [[MainBannerModel alloc] initWithDictionary:data];
            model.bannerViewID = doc.documentID;
            if (model.bannerViewVisible) {
                [fetchedGroups addObject:model];
            }
        }
        
        self.bannerGroups = [fetchedGroups copy];
        [self savebannerGroupsToCache];
        
        if (completion) completion(self.bannerGroups, nil);
    }];
}

- (void)stopListening {
    if (self.bannersListener) {
        [self.bannersListener remove];
        self.bannersListener = nil;
    }
}

- (void)addBannerGroup:(MainBannerModel *)bannerGroup completion:(void (^)(NSError * _Nullable))completion {
    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    data[@"BannerViewID"] = bannerGroup.bannerViewID;
    data[@"BannerViewVisible"] = @(bannerGroup.bannerViewVisible);
    data[@"BannerViewHolder"] = @(bannerGroup.bannerViewHolder);
    data[@"BannerViewPosition"] = @(bannerGroup.bannerViewPosition);
    data[@"BannerViewTransaction"] = @(bannerGroup.bannerViewTransaction);
    NSMutableArray *childDicts = [NSMutableArray array];
    for (PPBannerViewModel *banner in bannerGroup.childBanners) {
        NSMutableDictionary *childData = [NSMutableDictionary dictionary];
        childData[@"ChildsPannerID"] = banner.bannerID;
        childData[@"titleTextEn"] = banner.titleTextEn ?: @"";
        childData[@"titleTextAr"] = banner.titleTextAr ?: @"";
        childData[@"descTextEn"]  = banner.descTextEn ?: @"";
        childData[@"descTextAr"]  = banner.descTextAr ?: @"";
        childData[@"postDate"]    = banner.postDate ? @([banner.postDate timeIntervalSince1970]) : banner.postDateText;
        childData[@"backgroundImageURL"] = banner.backgroundImageURL.absoluteString ?: @"";
        childData[@"sampleImageURL"]     = banner.sampleImageURL.absoluteString ?: @"";
        childData[@"badgeImageURL"]      = banner.badgeImageURL.absoluteString ?: @"";
        childData[@"pannerOnTapAction"]  = @(banner.onTapAction);
        childData[@"pannerOnTapValue"]   = banner.onTapValue ?: @"";
        childData[@"pannerTapsCount"]    = @(banner.tapCount);
        childData[@"pannerTextStyle"]    = @(banner.textStyle);
        if (banner.expireInDateTime) {
            childData[@"expireInDateTime"] = @([banner.expireInDateTime timeIntervalSince1970]);
        }
        if (banner.pannerValidity) {
            NSMutableString *valStr = [NSMutableString string];
            if (banner.pannerValidity.day)   { [valStr appendFormat:@"%dd", (int)banner.pannerValidity.day]; }
            if (banner.pannerValidity.hour)  { [valStr appendFormat:@"%dh", (int)banner.pannerValidity.hour]; }
            if (banner.pannerValidity.minute){ [valStr appendFormat:@"%dm", (int)banner.pannerValidity.minute]; }
            childData[@"pannerpannerValidity"] = valStr;
        }
        
        [childDicts addObject:childData];
    }
    data[@"ChildsPannersModels"] = childDicts;
   
    FIRCollectionReference *collection = [_db collectionWithPath:@"MainBannersViewsCol"];
    if (bannerGroup.bannerViewID.length > 0) {
        FIRDocumentReference *docRef = [collection documentWithPath:bannerGroup.bannerViewID];
        [docRef setData:data completion:^(NSError * _Nullable error) {
            if (completion) completion(error);
        }];
    } else {
        __block FIRDocumentReference *ref =
        [collection addDocumentWithData:data completion:^(NSError * _Nullable error) {
            if (completion) completion(error);
        }];
    }
}

- (void)updateBannerGroup:(MainBannerModel *)bannerGroup completion:(void (^)(NSError * _Nullable))completion {
    NSMutableDictionary *updateData = [NSMutableDictionary dictionary];
    updateData[@"BannerViewVisible"] = @(bannerGroup.bannerViewVisible);
    updateData[@"BannerViewHolder"] = @(bannerGroup.bannerViewHolder);
    updateData[@"BannerViewPosition"] = @(bannerGroup.bannerViewPosition);
    updateData[@"BannerViewTransaction"] = @(bannerGroup.bannerViewTransaction);
    if (bannerGroup.childBanners && bannerGroup.childBanners.count > 0) {
        NSMutableArray *childDicts = [NSMutableArray array];
        for (PPBannerViewModel *child in bannerGroup.childBanners) {
            if ([child respondsToSelector:@selector(dictionaryRepresentation)]) {
                //[childDicts addObject:[child dictionaryRepresentation]];
            }
        }
        updateData[@"ChildsPannersModels"] = childDicts;
    }
    
    FIRDocumentReference *docRef = [[_db collectionWithPath:@"MainBannersViewsCol"] documentWithPath:bannerGroup.bannerViewID];
    [docRef setData:updateData merge:YES completion:^(NSError * _Nullable error) {
        if (completion) completion(error);
    }];
}

- (void)deleteBannerGroup:(MainBannerModel *)bannerGroup completion:(void (^)(NSError * _Nullable))completion {
    FIRDocumentReference *docRef = [[_db collectionWithPath:@"MainBannersViewsCol"] documentWithPath:bannerGroup.bannerViewID];
    [docRef deleteDocumentWithCompletion:^(NSError * _Nullable error) {
        if (completion) completion(error);
    }];
}

@end
