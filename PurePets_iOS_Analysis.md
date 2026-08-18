# Pure Pets iOS — Complete File Tree & Analysis

**Platform:** iOS 15.0+
**Language:** Objective-C (~90%) + Swift (~10%)
**Pattern:** MVC + Coordinator
**Firebase Project:** `pure-pets-49199`
**Primary Language:** Arabic (RTL) · Secondary: English (LTR)

---

## 1. File Tree

```
Pure Pets IOS/
├── .claude/settings.local.json
├── .gitignore
├── CLAUDE.md
├── Podfile                            # CocoaPods (iOS 15.0+)
├── Podfile.lock
├── README.md
├── fix_*.sh                           # Shell fix scripts (6)
├── clearGlassButtonConfiguration-locations.md
├── tmp_order.m / tmp_order_prev.m     # Temporary order patches
│
├── Pure Pets.xcodeproj/
│   ├── project.pbxproj
│   ├── project.xcworkspace/
│   └── xcshareddata/xcschemes/Pure Pets.xcscheme
│
├── Pure Pets.xcworkspace/
│   ├── contents.xcworkspacedata
│   ├── xcshareddata/
│   └── xcuserdata/
│
├── Pure Pets/                         # ★ MAIN APP SOURCE
│   ├── AppDelegate.h/.m               # App lifecycle, Firebase, push, App Check
│   ├── SceneDelegate.h/.m             # Window root, auth routing, deep links
│   ├── AppManager.h/.m                # Global singleton (AppMgr) — Firestore, session, cache
│   ├── GM.h/.m                        # Stateless utilities (3000+ lines) — images, fonts, colors
│   ├── EnumValues.h                   # Global enums, constants, feature flags
│   ├── PrefixHeader.pch               # Global precompiled header (756 lines)
│   ├── Pure Pets-Bridging-Header.h    # ObjC→Swift bridge
│   ├── main.m                         # UIApplicationMain entry
│   ├── ClassesHeader.h                # Legacy model imports
│   ├── importantFiles.h               # Legacy pod imports
│   │
│   ├── Info.plist                     # Bundle: com.PB.Pure-Bird
│   ├── GoogleService-Info.plist       # Firebase config
│   ├── Pure Pets.entitlements         # APS, App Attest, Apple Sign-In
│   ├── PrivacyInfo.xcprivacy          # Privacy manifest
│   │
│   ├── ar.lproj/Localizable.strings   # Arabic strings (primary)
│   ├── en.lproj/Localizable.strings   # English strings (secondary)
│   │
│   ├── Assets.xcassets/               # 62 image sets (icons, logos, UI, tabs)
│   ├── ColorsAssets.xcassets/         # 30+ color tokens (APP/, White, OffWhite)
│   ├── Resources/                     # Fonts, Lottie JSON, sound, city data
│   │   ├── Beiruti-{Regular,Medium,Bold,Black}.ttf
│   │   ├── cities.json
│   │   ├── map_dark_style.json
│   │   ├── {NoResult,NovaLoader,NovaTyping,payment_checkout,thinking}.json
│   │   ├── Profile.lottie / SearchingLottile.lottie
│   │   └── water-bubble.mp3
│   │
│   ├── MianData_Files/                # Legacy root files
│   │   ├── SplashViewController.h/.m
│   │   ├── Main.storyboard            # Only storyboard (splash entry)
│   │   ├── LBHamburgerButton.h/.m
│   │   ├── NullSafe.m
│   │   └── {Arch,Buyer,Cards}Cell.h/.m/.xib
│   │
│   ├── BirdsCards/                    # ★ Bird-specific listing module
│   │   ├── MainControllerFiles/
│   │   │   ├── MainController.h/.m
│   │   │   ├── MainControllerHelper.h/.m
│   │   │   └── MainController_Func.h/.m
│   │   ├── NewCardForm.h/.m           # XLForm-based card creation
│   │   ├── ArchiveManagerVC.h/.m
│   │   ├── SalesVCViewController.h/.m
│   │   ├── buyerDataVC.h/.m
│   │   ├── viewDataVC.h/.m
│   │   ├── FullscreenImageViewController.h/.m
│   │   ├── FullScreenVideoViewController.h/.m
│   │   ├── DoneStepViewController.h/.m
│   │   ├── selectTableViewController.h/.m
│   │   ├── Helpers/
│   │   │   ├── selectArchiveVC.h/.m
│   │   │   └── selectUserVC.h/.m
│   │   ├── CoubleFiles/
│   │   │   ├── FirstEggVC.h/.m
│   │   │   ├── NewCageVC.h/.m
│   │   │   ├── PickerSheetViewController.h/.m
│   │   │   └── selectChildViewController.h/.m
│   │   ├── Cells/
│   │   │   ├── 15+ cell types (archiveCell, KBSwipeCell, JPCell, VideoCollectionViewCell, etc.)
│   │   │   ├── ABMenuTableViewCell/   # Swipeable menu cells
│   │   │   └── ProdectionCells/       # PPBirdSummaryCollectionCell
│   │   └── PPMainCells/
│   │       ├── PPBirdCardView.h/.m
│   │       ├── PPCageCell.h/.m
│   │       ├── PPChildCell.h/.m
│   │       ├── SalesCell.h/.m
│   │       └── TrashCollectionViewCell.h/.m
│   │
│   ├── Bridges/                       # ★ Swift/ObjC interop
│   │   ├── PPCoreBridge.swift
│   │   ├── HXPHPickerBridge/
│   │   │   ├── PPPickerBridge.swift
│   │   │   ├── PPPhotoBrowserBridge.swift
│   │   │   └── PPEditorBridge.swift
│   │   └── UnifiedBlurHash/
│   │       ├── PPBlurHashBridge.swift (ObjC-callable)
│   │       ├── PPBlurHashGenerator.swift
│   │       ├── UnifiedBlurHash.swift
│   │       ├── UnifiedImage.swift + {Decode,Encode,Scale}.swift
│   │       ├── Math.swift
│   │       ├── SwiftUI.Image+BlurHash.swift
│   │       └── Resources/
│   │
│   ├── DataClasses/                   # ★ Models & Managers
│   │   ├── BasicDataClassess/
│   │   │   ├── CountryCodeModel.h/.m
│   │   │   ├── ItemModel.h/.m (NSSecureCoding)
│   │   │   ├── MainKindsArrayManager.h/.m (MKM singleton)
│   │   │   ├── MainKindsModel.h/.m
│   │   │   ├── SubKindModel.h/.m
│   │   │   ├── subKindItemsModel.h/.m
│   │   │   └── subSubKindModel.h/.m
│   │   ├── BirdsCardsDataClassess/
│   │   │   ├── {Archive,Card,Cage,Child,Buyer,File,Image}Model.h/.m
│   │   │   ├── ArchivesManager.h/.m
│   │   │   ├── ChildsDataManager.h/.m
│   │   │   ├── ReminderManager.h/.m
│   │   │   └── PPReminderNotificationManager.h/.m
│   │   ├── HelperClassess/
│   │   │   ├── BarcodeGenerator.h/.m
│   │   │   ├── FileUploadManager.h/.m (Firebase Storage)
│   │   │   ├── PPAuditLogger.h/.m
│   │   │   ├── PPSoundEffectPlayer.h/.m
│   │   │   └── Watermark.h/.m
│   │   └── YYKit/                     # Bundled library (Cache, Image, Text, Model, Utility)
│   │
│   ├── DesignFiles/                   # ★ Reusable UI library (no business logic)
│   │   ├── Helpers/                   # 10+ utilities (Language, ISO8601, EmptyState, etc.)
│   │   ├── MostUsed/
│   │   │   ├── Language/Language.h/.m # RTL/LTR manager
│   │   │   └── XLForm/                # Full XLForm framework (Cells, Controllers, Descriptors)
│   │   ├── PhotosAnControllers/       # ImagePicker, Introduction, JPVideoPlayer, TQImageViewer, ZXQRScan
│   │   ├── PP/                        # Pure Pets Design System
│   │   │   ├── PPComponent/           # DiscountBadge, ProductCard, RatingView, PPSearchFilterView
│   │   │   ├── PPFormEngine/          # Dynamic form engine
│   │   │   ├── PPImagePicker+Viewer/  # QB-style image picker
│   │   │   ├── PPNAV/                 # PPBottomBar, PPNavBar, PPBottomSurface
│   │   │   ├── PPSelectOptionViewController/
│   │   │   ├── PPStyles/              # PPDesignTokens, AlertHelper, ColorUtils, HUD, Gradients
│   │   │   ├── ScaledCenterCarousel/
│   │   │   ├── Vet Location/          # Map preview, vet cells
│   │   │   └── ZYCircleProgressView/
│   │   └── UIFieldsAndPicker/         # 25+ bundled UI libraries
│   │       ├── JGProgressHUD, FCAlertView, PYSearch, PGDatePicker
│   │       ├── KafkaRefresh, TTGSnackbar, PulsingHalo
│   │       └── AAMultiSelectController, LUNSegmentedControl, etc.
│   │
│   ├── FireData/                      # ★ Firestore listeners & data managers
│   │   ├── AppDataListenerManager.h/.m    # Centralized listener lifecycle (AppData macro)
│   │   ├── CagesManager.h/.m              # Cage + child CRUD
│   │   ├── TrashManager.h/.m / TrashModel.h/.m
│   │   └── PPSalesPDFGenerator.h/.m
│   │
│   └── MainApp/                       # ★ ALL feature view controllers
│       ├── ModrenAppVC/               # Home & tab bar (core navigation)
│       │   ├── PPRootTabBarController.h/.m
│       │   ├── PPHomeViewController.h/.m       # Main home feed
│       │   ├── PPIntroViewController.h/.m
│       │   ├── PPOverlayCoordinator.h/.m
│       │   ├── PPProviderSubscriptionManagementVC.h/.m
│       │   ├── Helpers/ (PPHomeFunc, PPHomeHelper, PPHomeItem, PPImageLoaderManager, etc.)
│       │   ├── HomeCells/ (20+ cell types: Hero, Banner, Category, Service, Order, Premium, Ultra)
│       │   │   └── Stories/
│       │   │       ├── PPStoriesManager/VC/Model/Cell/Player (5 files)
│       │   ├── PetCare/
│       │   │   ├── PPPetCareViewController/ViewerVC.h/.m
│       │   │   ├── PPPetCareMedicineCell/VetCell/VetViewrVC.h/.m
│       │   │   └── PetCareHelpers.h
│       │   ├── PPCarsoul/
│       │   │   ├── PPCarouselView/CollectionCell/ContainerCell/Item.h/.m
│       │   ├── PPDataView/
│       │   │   ├── PPDataViewVC/VM/Input.h/.m
│       │   │   ├── PPFilterSheetVC/FilterModels.h/.m
│       │   │   └── BBDataViewFullDetailsCell/Layout.h/.m
│       │   ├── Search/
│       │   │   ├── PPSearchViewController.h/.m
│       │   │   ├── PPImageSearchService.h/.m
│       │   │   ├── Helpers/ (ArabicNormalizer, PPSearchHelper, SearchCacheManager)
│       │   │   └── SearchUI/ (BBNavigationBar, PPFloatingSearchAccessoryView, PPSPinnerView)
│       │   └── SmartSuggest/
│       │       └── PPBrowseHistoryManager.h/.m
│       │
│       ├── AdsViewer Files/
│       │   ├── ViewerVC.h/.m                  # Pet listing detail viewer
│       │   ├── PPInfoPillsView.h/.m
│       │   ├── PPPetsTitleView.h/.m
│       │   └── PPSimilarAdsView.h/.m
│       │
│       ├── PetsAdsFiles/
│       │   ├── PetAd.h/.m / PetAdManager.h/.m / PetImageItem.h/.m
│       │   ├── CreateAdCoordinator.h/.m
│       │   ├── AdsBrowser/ (PPAdsBrowser, PPCenteredSelectorCell/View)
│       │   ├── New Ad/ (AddNewAd, PPAdSharingHelper, PPAdSubmitCoordinator)
│       │   └── PetsAdvertiseImagesAndCells/ (PPUniversalCell, PPPinterestLayout, etc.)
│       │
│       ├── Banners/
│       │   ├── MainBannerModel.h/.m
│       │   ├── PPBannersManager/Collection/Cell/View/ViewModel.h/.m
│       │   └── Banners.h
│       │
│       ├── NewChats/                           # ★ Real-time chat module
│       │   ├── ChManager.h/.m                  # Chat lifecycle + Firestore
│       │   ├── ChMessagingController.h/.m      # Chat UI
│       │   ├── ChatMessageModel.h/.m / ChatThreadModel.h/.m
│       │   ├── ChatBubbleView.h/.m
│       │   ├── UserChatsViewController.h/.m
│       │   ├── ChCells/ (ChatMessageCell, ChatImage/Audio/VideoMessageCell, BubbleLayer)
│       │   ├── helpers/
│       │   │   ├── ChMessagingController+{helper,Image,Record,Video}.h/.m
│       │   │   ├── PPChatHeaderView, PPFullscreenVideoController, PPMediaPreviewController
│       │   │   └── SubHelpers/
│       │   │       ├── ChatPresenceManager, ChNotificationRouter, ChTypingController
│       │   │       ├── PPChatInputBarView, PPChatFeedbackManager, PPRecordingBarView
│       │   │       ├── PPInAppChatNotificationPresenter, PPVoicePreviewBubbleView
│       │   │       └── WAVE/ (PPWaveformView, PPPlaybackWaveformView, PPRecordingWaveformView)
│       │
│       ├── GEMENI/                             # ★ Nova AI Agent (21 files)
│       │   ├── PPNovaChatViewController.h/.m   # Main Nova chat UI
│       │   ├── PPNovaGenkitService.h/.m        # Non-streaming Genkit callable
│       │   ├── PPNovaStreamingService.swift    # Streaming Firebase callable
│       │   ├── PPNovaLocalChatMemory.h/.m      # Disk-persisted chat history
│       │   ├── PPAgentClient.h/.m              # ADK HTTP agent client
│       │   ├── PPAgentMessage.h/.m / PPAgentResponseParser.h/.m
│       │   ├── PPNovaAmbientAssistantChatBridge.h/.m
│       │   ├── PPNovaMessageBubbleCell/ProductMessageCell/ReviewMessageCell.h/.m
│       │   ├── PPNovaFloatingInputBarView.h/.m
│       │   ├── NovaAmbientAssistantCoordinator/View.swift
│       │   ├── NovaConfirmationCell.h/.m
│       │   ├── GeminiChatViewController.h/.m   # Legacy Gemini
│       │   ├── ChatBarView.swift / AttachmentButton.swift
│       │   ├── PPNovaSwiftUIChatBarViewController.swift
│       │   └── PPVoiceMessageHelper.swift
│       │
│       ├── PAYMENTS/                           # ★ Cart, checkout, orders, payments
│       │   ├── CartAndOrdersFiles/
│       │   │   ├── CartItem.h/.m / CartViewController.h/.m / PPCartTableCell.h/.m
│       │   │   ├── OrderModel.h/.m / OrderCell.h/.m / OrderItemCell.h/.m
│       │   │   ├── OrderDetailsViewController.h/.m
│       │   │   ├── OrderHistoryViewController.h/.m
│       │   │   └── PurchasedItemsViewController.h/.m
│       │   ├── Checkout/
│       │   │   └── PPCheckoutCoordinator.h/.m  # 1291-line core coordinator
│       │   ├── Manager/
│       │   │   ├── Cart/CartManager.h/.m + PPCartCalculator.h/.m
│       │   │   ├── Order/PPOrderManager.h/.m
│       │   │   └── Payment/PPPaymentManager.h/.m + PPCommerceFeedbackManager.h/.m
│       │   ├── Models/
│       │   │   └── Orders/PPOrder.h/.m + PPFulfillmentOrder.h/.m
│       │   └── PPPaymentsFiles/
│       │       ├── PaymentMethod/UserPaymentInstrument Manager.h/.m
│       │       ├── PPSelectPaymentVC+Helper.h/.m
│       │       ├── PPPaymentFormViewController.h/.m
│       │       ├── PPPaymentMethodCell.h/.m
│       │       ├── PPAddressPickerView.h/.m
│       │       └── PPPaymentBasicsSettingsViewController.h/.m
│       │
│       ├── UserFiles/
│       │   ├── ProfileVC.h/.m, SettingVC.h/.m, PPUserMenuViewController.h/.m
│       │   ├── MyItemsViewController.h/.m, LeaveFeedbackViewController.h/.m
│       │   ├── Adressess/ (AddressFormVC, PPAddressesManager, PPAddressModel, CitiesManager, etc.)
│       │   ├── PetsProfiles/
│       │   │   ├── PPPetProfile/Reminder/Vaccination models
│       │   │   ├── PPPetProfilesViewController/PPPetProfileEditorViewController
│       │   │   └── PPPetRemindersViewController/PPReminderEditorViewController
│       │   ├── SignIn Files/
│       │   │   ├── PPUserSigningController/Manager.h/.m
│       │   │   ├── PPCompleteProfileVC/PPVerificationCodeViewController.h/.m
│       │   │   ├── PPAuthScaffoldView/PPAuthStepIndicatorView.h/.m
│       │   │   └── XLFormPhoneCodeCell/Item.h/.m
│       │   └── UsesHelpers/
│       │       ├── UserManager.h/.m (UsrMgr singleton)
│       │       ├── UserModel.h/.m (50+ properties)
│       │       ├── PPUserPermissionsManager / PPRolePermission
│       │       ├── PPAnalytics, PPUserModelCache, PPModernAvatarRenderer
│       │       └── ProfileCells/ (7 cell types)
│       │
│       ├── VeterinarianFiles/
│       │   ├── VetManager/Model.h/.m
│       │   ├── AddVetViewController.h/.m
│       │   ├── VetViewerViewController.h/.m
│       │   └── VetCollectionViewCell.h/.m
│       │
│       ├── PetsServices/
│       │   ├── ServicesManager/ServiceModel.h/.m
│       │   ├── AddPetServiceOfferViewController.h/.m
│       │   ├── ServiceViewerViewController.h/.m
│       │   ├── MyServicesViewController.h/.m
│       │   ├── CategoryModel.h/.m
│       │   └── ServiceCollectionViewCell.h/.m
│       │
│       ├── Accessories/AccessFiles/
│       │   ├── PetAccessory/Manager.h/.m
│       │   ├── AddNewAccessory/ViewerVC.h/.m
│       │   ├── PPProviderCompanyCell/PremiumCardCell.h/.m
│       │   ├── ProviderCompaniesListVC / ProviderStorefrontProductsVC
│       │   ├── SellerProfileVC.h/.m
│       │   └── PPMarketplaceHeroCardStyle / PPPremiumImageSelectorRail (style-only)
│       │
│       ├── AdoptPet/
│       │   ├── AdoptPetManager/Model.h/.m
│       │   ├── AdoptPetsViewController/DetailsViewController.h/.m
│       │   ├── AddAdoptPetViewController.h/.m
│       │   └── AdoptPetCell/PetAdoptCollectionViewCell/TitleSubtitleCell.h/.m
│       │
│       ├── Search Controllers/
│       │   ├── SearchManager.h/.m / AppSearchHelper.h/.m
│       │   ├── AppSearchResultsVC.h/.m
│       │   └── SearchResultCell/Item.h/.m
│       │
│       ├── Helpers/
│       │   ├── DeepLinkRouter.h/.m              # Universal deep link routing
│       │   ├── PPFirebaseSessionBridge.h/.m     # Firebase session bridge
│       │   ├── PPOfflineBannerView.h/.m         # Singleton offline banner
│       │   ├── PPNetworkRetryHelper.h/.m
│       │   ├── PPFirestoreErrorNotifier.h/.m
│       │   ├── PPImageUploadValidator.h/.m
│       │   ├── PPEmptyStateHelper.h/.m
│       │   ├── AppClasses.h/.m, EmptyStateView.h/.m, DonePopupView.h/.m
│       │   ├── CompanyLocationVC.h/.m, LocationPickerViewController.h/.m
│       │   ├── FloatingQuantityButton.h/.m, SegmentedControlHelper.h/.m
│       │   └── OptionsView/ (BottomOptionsViewController, OptionModel, OptionTableViewCell)
│       │
│       └── AppAssets.xcassets/                 # Feature-specific images
│           ├── Payment icons (A0, A1, AICONS, APayments)
│           ├── Animal category images (camels, Cats, Deer, falcons, fish, horses_s, Parrots, sheep)
│           ├── Icons/ (fast-delivery, male, female, weight, zoom-in, etc.)
│           └── Other/
│
├── Pure PetsTests/
│   └── Pure_PetsTests.m
│
├── Pure PetsUITests/
│   ├── Pure_PetsUITests.m
│   └── Pure_PetsUITestsLaunchTests.m
│
├── MyFrames/                           # ★ Bundled frameworks
│   ├── QIBPayment.framework/           # Qatar Islamic Bank SDK (device-only arm64)
│   ├── lame.framework/                 # MP3 encoding
│   └── HXPhotoPicker-master/           # Full HXPhotoPicker library source
│
├── Design Artifacts/
├── build/
├── Pods/                               # CocoaPods dependencies
└── reviews/
    └── review-qib-empty-page.md
```

---

## 2. Detailed File Analysis

### 2.1 Core App Entry

| File | Role | Key Details |
|------|------|-------------|
| `AppDelegate.h/.m` | App lifecycle + Firebase bootstrap | Firebase init, SDWebImage cache (300MB/200MB), App Check (AppAttest→DeviceCheck→Debug), push notifications, notification V2 registration with Cloud Function, Google Maps, deep link routing |
| `SceneDelegate.h/.m` | Window + auth routing | `reloadRootViewControllerForLanguageChange`, `pp_startUserScopedListenersIfPossible`, auth-state listener → splash/auth/main |
| `AppManager.h/.m` | **Global singleton (AppMgr)** | `dF` (FIRFirestore), `usersArray`, `localUsers`, listener mgmt, image URL cache, audio upload, snackbar, `loadUsersDocuments`, `setupAppConfiguration` |
| `GM.h/.m` | **Stateless utility (2991 lines)** | Image loading (SDWebImage wrapper), Firebase Storage upload/download, Beiruti font factory, color system, shadows, shimmer, haptics, price formatting, share-to-WhatsApp, chat navigation, QR/barcode, Lottie player |
| `EnumValues.h` | Global enums | `PPHomeItemType` (19), `PPHomeSection` (18), `PPDeepLinkTarget` (13), `ChatMessageType` (10), `PPAppTab`, feature flags, notification names |
| `PrefixHeader.pch` | Precompiled header (756 lines) | Macros: `AppPrimaryClr`, `AppMgr`, `PPCurrentUser`, `PPIsRTL`, `PPBarMgr`, chat colors, logging levels, inline helpers (`PPSafeString`, `PPApplyCardShadow`, `PPTapFeedbackDown/Up`). **Everything imported here** — all system frameworks, Firebase, pods, models, VCs, design files, YYKit. |

### 2.2 Modules by Feature

#### Bird Cards (`BirdsCards/`)
Legacy bird-breeding management module. Uses XLForm for `NewCardForm`. Manages card lifecycle (create, archive, sell, view), cage tracking (`NewCageVC`, `CageModel`), egg tracking (`FirstEggVC`), child management (`ChildModel`, `selectChildViewController`), sales (`SalesVCViewController`), archives (`ArchiveManagerVC`). **This is the original core of the app before it expanded into a pet marketplace.**

**Key files:** `MainController`, `NewCardForm`, `ArchiveManagerVC`, `CardModel`, `CageModel`, `ChildModel`, `ArchivesManager`

#### Bridges (`Bridges/`)
Swift ↔ Objective-C interoperability layer. Bridges HXPhotoPicker (photo/video picker) and BlurHash encoding/decoding to ObjC-callable interfaces. `PPCoreBridge` handles RTL layout direction for the picker.

**Key files:** `PPPickerBridge.swift`, `PPBlurHashBridge.swift`, `PPCoreBridge.swift`

#### Design System (`DesignFiles/PP/PPStyles/`)
Centralized design tokens in `PPDesignTokens.h` — spacing (8pt grid), 11 typography sizes (Beiruti font), 4 corner radii, 4 shadow presets, animation constants, tap feedback macros. Colors defined in `ColorsAssets.xcassets` (~30 tokens).

**Key files:** `PPDesignTokens.h`, `PPColorUtils`, `PPHUD`, `PPGradientView`, `PPFunc+Haptics`, `PurePets-DesignSystem.swift`

#### Home & Navigation (`ModrenAppVC/`)
`PPRootTabBarController` owns the custom tab bar (via `PPBottomBarManager`). `PPHomeViewController` is the main feed with ~20 section types: hero greeting, banners carousel, category cards, services grid, order status, premium/ultra care, marketplace hero, nearby ads, smart search, stories, etc.

**Key files:** `PPRootTabBarController`, `PPHomeViewController`, `PPHomeHelper`, `PPHomeLayoutManager`, `PPBottomBarManager`, `PPOverlayCoordinator`

#### Pet Ads (`PetsAdsFiles/`)
Full CRUD for pet marketplace listings. `PetAdManager` syncs with Firestore (`pet_ads` collection). `CreateAdCoordinator` orchestrates the multi-step creation flow. `PPAdsBrowser` lists ads with `PPPinterestLayout` waterfall grid. `PPUniversalCell` is the reusable listing cell.

**Key files:** `PetAdManager`, `CreateAdCoordinator`, `PPAdsBrowser`, `AddNewAd`, `PPUniversalCell`

#### Chat (`NewChats/`)
Real-time Firestore-based messaging. `ChManager` singleton handles message lifecycle (Pending→Sending→Sent→Delivered→Read), Firestore writes, and push notification sync. `ChMessagingController` is the chat UI with image/audio/video support, typing indicators, presence management, waveform visualization.

**Key files:** `ChManager`, `ChMessagingController`, `ChatMessageModel`, `ChatBubbleView`, `ChatPresenceManager`, `ChTypingController`, `PPChatInputBarView`, `PPRecordingWaveformView`

#### Nova AI Agent (`GEMENI/`)
On-device AI assistant backed by Firebase Cloud Functions (Genkit/ADK). Dual service architecture:
- `PPNovaGenkitService` — non-streaming HTTPSCallable
- `PPNovaStreamingService.swift` — streaming typed callable

Includes `PPAgentClient` (ADK HTTP), `PPNovaLocalChatMemory` (disk-persisted), `PPNovaChatViewController` (full chat UI with product cards, reviews, confirmations), and `NovaAmbientAssistantCoordinator` (contextual glass-morphism suggestions).

**Key files:** `PPNovaChatViewController`, `PPNovaGenkitService`, `PPNovaStreamingService.swift`, `PPNovaLocalChatMemory`, `PPAgentClient`

#### Payments & Orders (`PAYMENTS/`)
End-to-end commerce: `CartManager` (Firestore-backed), `PPCartCalculator`, `PPCheckoutCoordinator` (1291 lines — idempotency key, generation-based stale callback protection, offline pre-check, QIB payment, Cash on Delivery, 25s timeout), `PPOrderManager`, `PPPaymentManager` (QIB SDK integration). Supports fulfillment v1 (child `PPFulfillmentOrder` objects synced via Cloud Functions).

**Key files:** `PPCheckoutCoordinator`, `CartManager`, `PPOrderManager`, `PPPaymentManager`, `OrderModel`, `PPFulfillmentOrder`

#### User Management (`UserFiles/`)
`UserManager` singleton (`UsrMgr`) manages the current session. `UserModel` has 50+ properties. `PPUserPermissionsManager` checks role-based permissions against Firestore `PermisstionsCol`. Auth flow in `PPUserSigningController` with phone verification. Pet profiles (`PPPetProfilesViewController`), reminders, vaccinations.

**Key files:** `UserManager`, `UserModel`, `PPUserPermissionsManager`, `PPUserSigningController`, `PPPetProfilesViewController`

#### Adopt, Services, Accessories, Vets
Standard CRUD modules for adoption listings, pet service offers, pet accessories marketplace, and veterinary management — all backed by Firestore.

**Key files:** `AdoptPetManager`, `ServicesManager`, `PetAccessoryManager`, `VetManager`

---

## 3. Architecture Summary

### Pattern: MVC + Singleton Managers + Coordinator

```
User Action → ViewController → Manager (Firestore) → Cloud Function → Firestore
                                                          ↕
                                              AppDataListenerManager (snapshot)
                                                          ↕
                                                     UI Refresh
```

### Key Singletons
| Macro | Class | Responsibility |
|-------|-------|----------------|
| `AppMgr` | `AppManager` | Firestore ref, user session, image cache, audio |
| — | `GM` | 100+ stateless utilities (images, fonts, colors, haptics) |
| `PPBarMgr` | `PPBottomBarManager` | Custom tab bar state |
| `AppData` | `AppDataListenerManager` | Centralized Firestore listener lifecycle |
| `UsrMgr` | `UserManager` | User session & state |
| `MKM` | `MainKindsArrayManager` | Category hierarchy |
| — | `CartManager` | Cart + Firestore sync |
| — | `ChManager` | Chat message lifecycle |
| — | `PPCheckoutCoordinator` | Checkout flow (instance per checkout) |

### Tech Stack
- **Language:** Objective-C (~90%), Swift (~10%)
- **UI:** UIKit code-only (1 storyboard for splash), XLForm, custom components
- **Firebase:** Firestore, Auth, Storage, Cloud Functions, Messaging, App Check (AppAttest → DeviceCheck)
- **Pods:** SDWebImage, HXPhotoPicker, IQKeyboardManager, AFNetworking, Masonry, GoogleMaps, lottie-ios_Oc, SSZipArchive, TOCropViewController, RecaptchaEnterprise
- **Bundled:** QIBPayment.framework, lame.framework, YYKit, XLForm, PGDatePicker, JGProgressHUD, PYSearch, KafkaRefresh, JPVideoPlayer
- **Payments:** QIB (Qatar Islamic Bank) — device-only arm64 SDK
- **AI:** Google ADK/Genkit via Firebase Cloud Functions

### Localization
- Arabic (RTL) primary, English (LTR) secondary
- `kLang(@"key")` macro for all user-facing strings
- Leading/trailing Auto Layout anchors (never left/right)
- `Language` class manages RTL/LTR switching
