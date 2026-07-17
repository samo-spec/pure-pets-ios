//
//  EnumValues.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 01/01/2026.
//

#ifndef EnumValues_h
#define EnumValues_h

#pragma mark - Chat Audio Colors (2026)

@class PPDefaultLocationView;
@class PPQuickActionsView;
@class PPS;
@class PPNewBottomBar;
@class UserModel;
@class ChatThreadModel;

// *****************************************************************************************************************************************************************

// Add a new enumeration value for pets before PPProfileSectionCount
typedef NS_ENUM(NSInteger, PPProfileSection) {
    PPProfileSectionDetails = 0,
    PPProfileSectionContact,
    PPProfileSectionAddresses,
    PPProfileSectionPets,
    PPProfileSectionLogout,
    PPProfileSectionCount
};

typedef NS_ENUM(NSInteger, PPProfileFieldKind) {
    PPProfileFieldKindUserName = 1,
    PPProfileFieldKindFirstName,
    PPProfileFieldKindLastName,
    PPProfileFieldKindMobile,
    PPProfileFieldKindEmail,
    PPProfileFieldKindAbout
};

typedef NS_ENUM(NSInteger, PPProfileDetailRow) {
    PPProfileDetailRowUserName = 0,
    PPProfileDetailRowFirstName,
    PPProfileDetailRowLastName,
    PPProfileDetailRowCount
};

typedef NS_ENUM(NSInteger, PPProfileContactRow) {
    PPProfileContactRowCountry = 0,
    PPProfileContactRowMobile,
    PPProfileContactRowEmail,
    PPProfileContactRowAbout,
    PPProfileContactRowCount
};

static const CGFloat kPPProfileCellHorizontalInset = 20.0;
static const CGFloat kPPProfileCellVerticalInset   = 10.0;

static inline UISemanticContentAttribute PPProfileCurrentSemanticAttribute(void) {
    return Language.isRTL
        ? UISemanticContentAttributeForceRightToLeft
        : UISemanticContentAttributeForceLeftToRight;
}

static inline NSString *PPProfileForwardChevronSymbolName(void) {
    return Language.isRTL ? @"chevron.left" : @"chevron.right";
}
// *****************************************************************************************************************************************************************

static NSString *const kSavedCartKey = @"savedCartItems";
static NSString *const kCartUpdatedNotification = @"CartUpdated";
static NSString *const kCartPricingConfigurationDidChangeNotification = @"CartPricingConfigurationDidChange";

// Firestore error notification (observed by PPFirestoreErrorNotifier global handler)
static NSString *const kPPFirestoreErrorOccurredNotification = @"PPFirestoreErrorOccurred";

// PPNotifications.m
static NSString * const PPAdDidFinishUploadNotification = @"PPAdDidFinishUploadNotification";

static NSString *const PPHomeHeaderKind = @"PPHomeSectionHeaderKind";
static NSString * const PPHomeSectionHeaderKind = @"PPHomeSectionHeaderKind";
static NSString * const kPPLayoutModeKey = @"PPUserPreferredLayoutMode";
static NSString * const kPPAllKindsSectionKey = @"pp.lastSection.allKinds";

// Global marketplace flag. Keep the requested name as the public switch:
// YES = preserve existing new + used accessory behavior.
// NO  = user-facing accessory browsing and creation surfaces use new accessories only.
#ifndef AllwedUsedAccessories
#define AllwedUsedAccessories NO
#endif

static inline BOOL PPAllwedUsedAccessoriesEnabled(void) {
    return (BOOL)AllwedUsedAccessories;
}

static NSString * const PPShowSystemTabBarNotification = @"PPShowSystemTabBarNotification";
static NSString * const PPHideSystemTabBarNotification = @"PPHideSystemTabBarNotification";

static NSString * const PPExpandSystemTabBarNotification = @"PPExpandSystemTabBarNotification";
static NSString * const PPCollapseSystemTabBarNotification = @"PPCollapseSystemTabBarNotification";

static NSString * const PPRouteToSearchAccessoriesNotificationKey = @"PPRouteToSearchAccessoriesNotification";

static NSString * const PPHomeSectionDividerKind = @"PPHomeSectionDividerKind";
static BOOL const PPUSE_LEGACY_BAR = NO;
static NSString * const kPPReusableVideoMediaFeatureFlagKey = @"PPReusableVideoMediaEnabled";

static inline BOOL PPReusableVideoMediaDefaultEnabled(void) {
#ifdef PP_REUSABLE_VIDEO_MEDIA_ENABLED
    return PP_REUSABLE_VIDEO_MEDIA_ENABLED;
#else
    return YES;
#endif
}

static inline BOOL PPReusableVideoMediaEnabled(void) {
    id overrideValue = [[NSUserDefaults standardUserDefaults] objectForKey:kPPReusableVideoMediaFeatureFlagKey];
    if ([overrideValue isKindOfClass:NSNumber.class]) {
        return [(NSNumber *)overrideValue boolValue];
    }
    return PPReusableVideoMediaDefaultEnabled();
}

static NSString * const kPetAdsCollection = @"pet_ads";
static NSString * const kUsersCollection  = @"UsersCol";

static NSString * const PPUpdateUnreadsOnTabbarNotification = @"PPUpdateUnreadsOnTabbarNotification";

typedef NS_ENUM(NSUInteger, ButtonKind) {
    ButtonKindText,
    ButtonKindImage
};

/// Actions


typedef NS_ENUM(NSInteger, BBPaymentState) {
    BBPaymentStateIdle = 0,          // ready to checkout
    BBPaymentStateValidating,        // validating cart / phone
    BBPaymentStateCreatingOrder,     // Firestore order creation
    BBPaymentStateStartingPayment,   // calling QIB session
    BBPaymentStateInProgress,        // QIB UI opened
    BBPaymentStateCompleted,         // success
    BBPaymentStateFailed             // error (retry allowed)
};


typedef void (^PPQuantityChangedHandler)(NSInteger qty);

typedef NS_ENUM(NSInteger, PPChatBubblePosition) {
    PPChatBubblePositionSingle,
    PPChatBubblePositionTop,
    PPChatBubblePositionMiddle,
    PPChatBubblePositionBottom
};

typedef NS_ENUM(NSUInteger, PPBubblePosition) {
    PPBubblePositionSingle,
    PPBubblePositionFirst,
    PPBubblePositionMiddle,
    PPBubblePositionLast
};

typedef NS_ENUM(NSUInteger, PPChatGroupPosition) {
    PPChatGroupPositionSingle,   // only one message
    PPChatGroupPositionFirst,      // first in group
    PPChatGroupPositionMiddle,   // middle of group
    PPChatGroupPositionLast    // last in group
};
typedef NS_ENUM(NSInteger, PPHomeItemType) {

    // =========================
    // Core Home Sections
    // =========================

    PPHomeItemTypeHero,            // Hero greeting + location card
    PPHomeItemTypeCarousel,        // Top banners / carousel
    PPHomeItemTypeServices,            // Services (vet, grooming, food…)
    PPHomeItemTypeCurrentOrder,        // Smart current order tracking card
    PPHomeItemTypeMainKinds,           // Main categories (grid / horizontal)
    PPHomeItemTypeAccessories,         // Accessories listing
    PPHomeItemTypePetProfile,          // Default pet / pet profiles feature card
    PPHomeItemTypePremiumCare,         // Pet medicines and veterinarians gateway
    PPHomeItemTypeAdopt,               // Adopt a pet (static card)

    PPHomeItemTypeAdsNearBy,            // Nearby ads
   

    // =========================
    // Optional / Future
    // =========================

    PPHomeItemTypeQuickActions,        // (currently disabled)
    PPHomeItemTypeEmpty,               // Fallback / safety
    PPHomeItemTypeBuyAgain,            // Repeat-purchase accessory rail
    PPHomeItemTypeLastFood,            // Last food added smart section
    PPHomeItemTypePremiumSearch,       // Premium in-feed search bar
    PPHomeItemTypeProviderCategoryNav, // Top provider marketplace navigation
    PPHomeItemTypeMarketplaceHero      // Provider-first marketplace hero
};


typedef NS_ENUM(NSInteger, PPSearchRank) {
    PPSearchRankExact        = 0,   // 🔥 highest priority
    PPSearchRankPrefix       = 1,
    PPSearchRankWordStart    = 2,
    PPSearchRankContains     = 3,
    PPSearchRankFuzzy        = 4,   // typo-tolerant (Levenshtein)
    PPSearchRankWeak         = 5    // lowest
};
typedef NS_ENUM(NSInteger, PPButtonStyle) {
    PPButtonStyleFilled,   // solid background
    PPButtonStyleTonal,    // subtle background
    PPButtonStylePlain     // transparent
};

typedef NS_ENUM(NSInteger, PPButtonTitleStyle) {
    PPButtonTitleStylePrimary,
    PPButtonTitleStyleSecondry,
    PPButtonTitleStyleGhost,
};



typedef NS_ENUM(NSInteger, PPVoiceRecordingState) {
    PPVoiceRecordingStateIdle,
    PPVoiceRecordingStateRecording,
    PPVoiceRecordingStateLocked,
    PPVoiceRecordingStateCancelling
};


typedef NS_ENUM(NSInteger, PPSearchMatchType) {
    PPSearchMatchNone = 0,
    PPSearchMatchExact,
    PPSearchMatchStartsWith,
    PPSearchMatchEndsWith,
    PPSearchMatchContains,
    PPSearchMatchFuzzy
};


typedef NS_ENUM(NSInteger, PPDeepLinkTarget) {
    PPDeepLinkTargetAds,
    PPDeepLinkTargetNewByAds,
    PPDeepLinkTargetAccessories,
    PPDeepLinkTargetFood,
    PPDeepLinkTargetVet,
    PPDeepLinkTargetServices,
    PPDeepLinkTargetGrooming,
    PPDeepLinkTargetTraning,
    PPDeepLinkTargetAdopt,
    PPDeepLinkTargetAllCategories,
    PPDeepLinkTargetNone
};

typedef NS_ENUM(NSInteger, PPMainKindsLayoutMode) {
    PPMainKindsLayoutModeCollapsed,
    PPMainKindsLayoutModeExpanded
};


typedef NS_ENUM(NSInteger, PPInputSource) {
    PPInputSourceHomeMainKindsSection,
    PPInputSourceHomeAccessoriesSection,
    PPInputSourceHomeServicesSection,
    PPInputSourceHomeNearBySection
};


typedef NS_ENUM(NSInteger, PPBrowseItemType) {
    PPBrowseItemTypeAd,
    PPBrowseItemTypeAccessory,
    PPBrowseItemTypeService
};



typedef NS_ENUM(NSInteger, PPCategoryItemKind) {
    PPCategoryItemKindOption,   // horizontal pills
    PPCategoryItemKindGridItem  // 2x2 grid items
};

/*
 [snapshot appendSectionsWithIdentifiers:@[
     @(PPHomeSectionHero),
     @(PPHomeSectionCurrentOrders),
     @(PPHomeSectionServices),
     @(PPHomeSectionCarousel),
     @(PPHomeSectionMainKinds),
     @(PPHomeSectionSuggestions),
     @(PPHomeSectionAccessories),
     @(PPHomeSectionAdsNearBy),
     @(PPHomeSectionAdopt),
     // PPHomeSectionBuyAgain — conditional, appended only when items exist
 ]];
 */

typedef NS_ENUM(NSInteger, PPHomeSection) {
    PPHomeSectionHero = 0,
    PPHomeSectionQuickActions = 1,
    PPHomeSectionCurrentOrders = 2,
    PPHomeSectionServices = 3,
    PPHomeSectionCarousel = 4,
    PPHomeSectionMainKinds = 5,
    PPHomeSectionSuggestions = 6,
    PPHomeSectionAccessories = 7,
    PPHomeSectionPetProfile = 8,
    PPHomeSectionPremiumCare = 9,
    PPHomeSectionLastFood = 10,
    PPHomeSectionNearbyServices = 11,
    PPHomeSectionAdsNearBy = 12,
    PPHomeSectionAdopt = 13, // legacy (not rendered on home in Pattern 1)
    PPHomeSectionBuyAgain = 14,
    PPHomeSectionPremiumSearch = 15,
    PPHomeSectionProviderCategoryNav = 16,
    PPHomeSectionMarketplaceHero = 17,
    PPHomeSectionSuggestionAds = 18,
    PPHomeSectionSuggestionAccessories = 19,
};

typedef NS_ENUM(NSInteger, PPDataSection) {
    PPDataSectionAds = 0,
    PPDataSectionAccessories,
    PPDataSectionFood,
   
    PPDataSectionServices,
    
}; // PPDataSectionVets,

typedef NS_ENUM(NSInteger, PPFilterAccessoryType) {
    PPFilterAccessoryAll = 0,
    PPFilterAccessoryNew,
    PPFilterAccessoryUsed
};

typedef NS_ENUM(NSInteger, PPFilterServiceType) {
    PPFilterServiceAll = 0,
    PPFilterServiceTraining,
    PPFilterServiceGrooming,
    PPFilterServiceWalking
};

typedef NS_ENUM(NSInteger, PPSection) {
    PPSectionAccess,
    PPSectionAds,
    PPSectionFood,
    PPSectionVets,
    PPSectionServices,
    PPSectionNearByAds
};

typedef NS_ENUM(NSInteger, CollectioCellSection) {
    CellSectionAds = 0,
    CellSectionAccessories,
    CellSectionFood,
    CellSectionVet,
    CellSectionServices
};

typedef NS_ENUM(NSInteger, PPCellContext) {
    
    PPCellForAds = 0,
    PPCellForMarket,
    PPCellForFood,
    PPCellForServices,
    PPCellForVets,
    PPCellForAdopt,
    PPCellForHomeAds,
    PPCellForContextAccessory,
};
 

typedef NS_ENUM(NSInteger, PPDiscountStyle) {
    PPDiscountStyleBadge = 0,    // rounded badge (default)
    PPDiscountStylePlain         // plain text near price
};

typedef NS_ENUM(NSInteger, PPHomeQuickAction) {
    PPHomeQuickActionNearestVet,
    PPHomeQuickActionAccessories,
    PPHomeQuickActionFood
};


/// Defines where to place icons inside a view
typedef NS_ENUM(NSInteger, IconPostions) {
    IconPostionsTopLeft       = 1,
    IconPostionsTopRight      = 2,
    IconPostionsTopMiddle     = 3,
    IconPostionsBottomLeft    = 4,
    IconPostionsBottomRight   = 5,
    IconPostionsBottomMiddle  = 6,
    IconPostionsMiddleLeft    = 7,
    IconPostionsMiddleRight   = 8
};


typedef NS_ENUM(NSUInteger, PPSheetDetentStyle) {
    PPSheetDetentStyleMediumOnly,
    PPSheetDetentStyle35,
    PPSheetDetentStyle70,
    PPSheetDetentStyle80,
    PPSheetDetentStyleAdsView,
    PPSheetDetentStyle300,
    PPSheetDetentStyleLargeOnly,
    PPSheetDetentStyleMediumAndLarge,
    PPSheetDetentStyleSemiLargAndLarge,
    PPSheetDetentStyleProfile,
    PPSheetDetentStyleFull
};
 

typedef NS_ENUM(NSInteger, PPBannerOnTapAction) {
    PPBannerOnTapViewAccessory = 0,
    PPBannerOnTapViewAd,
    PPBannerOnTapOpenUrl,
    PPBannerOnTapCallPhoneNumber,
    PPBannerOnTapWhatsApp
};

typedef NS_ENUM(NSInteger, PPBannerTextStyle) {
    PPBannerTextStyleBlack = 1,
    PPBannerTextStyleWhite = 2
};


 typedef NS_ENUM(NSInteger, PPBannerPosition) {
     PPBannerPositionTop = 0,
     PPBannerPositionCenter,
     PPBannerPositionBottom
 };

 typedef NS_ENUM(NSInteger, PPBannerTransaction) {
     PPBannerTransactionScroll = 0,
     PPBannerTransactionFade,
     PPBannerTransactionReplace
 };


typedef NS_ENUM(NSInteger, PPIconAlignment) {
    PPIconAlignmentCenter,
    PPIconAlignmentLeading,
    PPIconAlignmentTrailing,
    PPIconAlignmentTop
};

typedef NS_ENUM(NSInteger, PPAppTab) {
    PPAppTabHome = 0,
    PPAppTabNotifications,
    PPAppTabAddNew,
    PPAppTabOrders,
    PPAppTabCart
};
 

/// Defines where to place icons inside a view
typedef NS_ENUM(NSInteger, PPTitleViewIconPostion) {
    PPTitleViewIconPostionLead       = 0,
    PPTitleViewIconPostionTrail      = 1,
    PPTitleViewIconPostionMiddle      = 2,
};

typedef NS_ENUM(NSInteger, PPTitleViewMode) {
    PPTitleViewModeMenu       = 0,
    PPTitleViewModeTitleLabel      = 1,
};

typedef NS_ENUM(NSInteger, PPDataViewNavBarButtonKind) {
    PPDataViewNavBarButtonKindMainKinds       = 0,
    PPDataViewNavBarButtonKindSections      = 1,
};


/* ****************************************************   CHATS   ********************************************************** */
 
typedef NS_ENUM(NSInteger, ChatMessageStatus) {
    //ChatMessageStatusPending = 0,   // Local only, not yet sent
    ChatMessageStatusSending,       // Uploading / Firestore write in progress
    ChatMessageStatusSent,           // Written to Firestore
    ChatMessageStatusDelivered,      // Other user received (listener hit)
    ChatMessageStatusRead            // Other user opened chat
};
typedef NS_ENUM(NSInteger, ChatMessageType) {
    ChatMessageTypeText = 0,
    ChatMessageTypeImage,
    ChatMessageTypeAudio,
    ChatMessageTypeVideo,
    ChatMessageTypeFile,
    ChatMessageTypeSystem,
    ChatMessageTypeNovaProduct,
    ChatMessageTypeNovaProductList,
    ChatMessageTypeNovaReview,
    ChatMessageTypeCartConfirmation,
    ChatMessageTypeSticker
};

typedef NS_ENUM(NSInteger, ChatBubbleContentType) {
    ChatBubbleContentTypeText = 0,
    ChatBubbleContentTypeAudio
};


#endif /* EnumValues_h */
