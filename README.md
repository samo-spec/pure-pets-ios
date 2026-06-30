# Pure Pets iOS

![Platform](https://img.shields.io/badge/platform-iOS%2015.0+-blue) ![Language](https://img.shields.io/badge/language-ObjC%20%7C%20Swift-lightgrey) ![Firebase](https://img.shields.io/badge/Firebase-pure--pets--49199-orange) ![RTL](https://img.shields.io/badge/RTL-Arabic%20%7C%20English-green) ![Architecture](https://img.shields.io/badge/architecture-MVC%20%2B%20Coordinator-red)

## Overview

Pure Pets is a bilingual (Arabic/English, RTL-first) consumer iOS marketplace for pet birds, accessories, services, and adoption. Built on a UIKit code-only architecture with ~90% Objective-C and ~10% Swift, the app connects buyers with pet sellers, veterinarians, and service providers across Qatar. The backend is powered by Firebase (`pure-pets-49199`) with Firestore, Cloud Functions, Storage, and a custom Genkit AI agent (Nova).

## Features

| Module | Description |
|---|---|
| **Pet Ads** | Browse, search, create, and manage pet listings with status, visibility, geohash, and favorites |
| **Bird Cards** | Bird-specific listings with age info, location, section enums; cage parent/egg/child tracking |
| **Payments & Checkout** | Cart management, coordinator-pattern checkout, cash on delivery, QIB payment integration |
| **Chat** | Real-time messaging with status lifecycle (Pending → Sending → Sent → Delivered → Read) |
| **User Profiles** | Sign-up/sign-in, profile management, addresses, pet profiles, settings |
| **Veterinarians** | Vet listings and detail viewer |
| **Pet Services** | Service listings, viewer, and add-service flow |
| **Pet Accessories** | Accessories catalog and purchasing |
| **Adoption** | Pet adoption listing and request flow |
| **Search** | Global search with helper controller and results view |
| **Banners** | Promotional banner management and display |
| **Nova AI** | Streaming and non-streaming Genkit AI agent for assistance, product discovery, contextual suggestions |

## Architecture

**Core Pattern: MVC with Coordinators**

The app follows Apple's MVC pattern augmented with a Coordinator layer for complex flows (notably `PPCheckoutCoordinator` at ~1291 lines). View Controllers are heavy, model objects adopt `NSSecureCoding`, and utility logic resides in stateless helper classes.

**Key Singletons:**

| Singleton | Macro / Accessor | Role |
|---|---|---|
| `AppManager` | `AppMgr` | Firestore ref (`dF`), user session, cached user array (JSON), URL image cache, reminder scheduling |
| `GM` | — | ~100+ stateless utility methods: image loading, Firebase Storage upload, Beiruti font, colors, shadows, shimmer, haptics, price formatting, sharing, Lottie, Gemini prompts |
| `PPBottomBarManager` | — | Custom tab bar controller |
| `AppDataListenerManager` | — | Firestore listener lifecycle management |
| `CagesManager` / `TrashManager` | — | Cage data / soft-delete management |
| `MainKindsArrayManager` | — | Category hierarchy cache |

**Language & RTL:**
- `Language.setLanguage:`, `Language.isRTL`, `Language.semanticAttributeForCurrentLanguage`
- Leading/trailing Auto Layout anchors (never left/right)
- `kLang(@"key")` macro for all user-facing strings

**Design Tokens:** `PPDesignTokens.h` defines spacing (8pt grid), corner radii, typography (11 sizes, Beiruti font), color macros, shadow helpers, animation constants, and tap feedback.

## Folder Structure

```
Pure Pets IOS/
├── AGENTS.md                        # Agent mandates
├── CLAUDE.md                        # Additional context
├── Podfile                          # CocoaPods dependencies
├── Pure Pets.xcworkspace            # Workspace (always open this)
├── Pure Pets/
│   ├── AppDelegate/                 # AppDelegate, SceneDelegate, PPNovaMotionWindow
│   ├── MainApp/
│   │   ├── ModrenAppVC/             # PPHomeViewController, PPRootTabBarController, overlay coordinator
│   │   ├── AdsViewer Files/         # Pet ad viewer
│   │   ├── PetsAdsFiles/            # PetAd model, PetAdManager, ad browser/creation
│   │   ├── BirdsCards/              # Bird cards, sales, archive, cages
│   │   ├── PAYMENTS/                # Cart, PPCheckoutCoordinator, order manager, QIB, payment methods
│   │   ├── NewChats/                # Chat messaging, ChManager, ChatThreadModel
│   │   ├── UserFiles/               # PPUserSigningController, profile, settings, addresses, pet profiles
│   │   ├── VeterinarianFiles/       # Vet listings and viewer
│   │   ├── Accessories/             # Pet accessories
│   │   ├── PetsServices/            # Services listing, viewer, add-service
│   │   ├── AdoptPet/                # Adoption flow
│   │   ├── Search Controllers/      # AppSearchHelper, AppSearchResultsVC
│   │   └── Banners/                 # PPBannersManager, PPBannerCollectionCell
│   ├── Nova/                        # AI agent (streaming, Genkit, ADK, ambient, chat)
│   ├── CoreBridge/                  # PPCoreBridge.swift, HXPHPickerBridge/
│   ├── UnifiedBlurHash/             # 9 Swift blurhash files
│   ├── Models/                      # All NSSecureCoding models
│   ├── PrefixHeader.pch             # Global imports (AppMgr, GM, etc.)
│   ├── PPDesignTokens.h             # Design system tokens
│   ├── Pure Pets-Bridging-Header.h  # ObjC ↔ Swift bridge
│   ├── ColorsAssets.xcassets        # Color palette
│   ├── ar.lproj/                    # Arabic Localizable.strings
│   ├── en.lproj/                    # English Localizable.strings
│   └── Info.plist                   # Permissions, URL schemes, background modes
├── Frameworks/
│   └── QIBPayment.framework         # Device-only arm64, Swift 5.7
├── Pure PetsTests/                  # Unit tests
└── Pure PetsUITests/                # UI tests
```

## Technology Stack

| Layer | Technology |
|---|---|
| Language | Objective-C (~90%), Swift (~10%, 19 files) |
| UI Framework | UIKit (code-only, no storyboards except splash entry) |
| Architecture | MVC + Coordinator |
| Backend | Firebase (Auth, Firestore, Storage, Functions, Messaging, AppCheck) |
| AI Agent | Firebase Genkit streaming + ADK HTTP client (Nova) |
| Image Loading | SDWebImage (300MB disk / 200MB memory cache), YYWebImage |
| Animations | lottie-ios, UIKit spring/dynamic animations |
| Payments | QIBPayment.framework (device-only), Cash on Delivery |
| Chat | Firestore real-time listeners |
| Keyboard | IQKeyboardManager |
| Forms | XLForm |
| HUD | JGProgressHUD |
| Status Bar | JDStatusBarNotification |
| Image Picker | HXPhotoPicker (Swift) |
| Image Crop | TOCropViewController |
| Zip | SSZipArchive |
| Popups | PopupDialog |
| Mirroring | ShowTime (debug only) |
| Caching | YYKit (unmaintained), SDWebImage |
| Maps | Google Maps |

## Requirements

- iOS 15.0+
- Xcode 16+
- CocoaPods 1.15+
- Valid Firebase project (`pure-pets-49199`)
- Apple Developer account (for push notifications and App Check)

## Installation

```bash
# Clone the repository
git clone <repository-url>
cd "Pure Pets IOS"

# Install CocoaPods dependencies
pod install

# IMPORTANT: Always open the .xcworkspace, never the .xcodeproj
open "Pure Pets.xcworkspace"
```

## Configuration

1. **Firebase:** Place `GoogleService-Info.plist` in the project root (not tracked in repo).
2. **QIB Payment:** The `QIBPayment.framework` is device-only arm64. Simulator builds will fail to link QIB—comment out the import and related code for simulator testing.
3. **Google Maps:** Add your API key to `AppDelegate.m` (refer to the existing `GMSServices` configuration).
4. **App Check:** Configured for AppAttest → DeviceCheck → Debug provider chain. Debug provider is active in debug builds automatically.

## Build

**Device build (full):**
```bash
xcodebuild -workspace 'Pure Pets.xcworkspace' -scheme 'Pure Pets' \
  -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

**Simulator build (QIB excluded):**
```bash
xcodebuild -workspace 'Pure Pets.xcworkspace' -scheme 'Pure Pets' \
  -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' CODE_SIGNING_ALLOWED=NO build
```

> Note: `SWIFT_INSTALL_OBJC_HEADER = NO` may be required for Xcode 16+ to resolve FirebaseFirestore compilation issues.

## Running

Open `Pure Pets.xcworkspace` in Xcode, select a target device or simulator, and press Run. The app launches with a splash screen, transitions to auth (if unauthenticated), or proceeds directly to the main tab interface (`PPRootTabBarController`).

## Key Classes

| Class | File | Role |
|---|---|---|
| `AppDelegate` | `AppDelegate.m` | Firebase init, App Check, Google Maps, cache config |
| `SceneDelegate` | `SceneDelegate.m` | Window root, auth listener, notification routing |
| `AppManager` | `AppManager.h/m` | Global singleton - Firestore, session, cache |
| `GM` | `GM.h/m` | ~100+ stateless utilities |
| `PPHomeViewController` | `ModrenAppVC/` | Main home screen |
| `PPRootTabBarController` | `ModrenAppVC/` | Tab bar root |
| `PPCheckoutCoordinator` | `PAYMENTS/` | Checkout flow (coordinator pattern, 1291 lines) |
| `PPBottomBarManager` | — | Custom tab bar manager |
| `PPNovaStreamingService` | `Nova/` | Genkit streaming service (Swift) |
| `PPNovaGenkitService` | `Nova/` | Non-streaming Genkit service |
| `PPAgentClient` | `Nova/` | ADK HTTP agent client |
| `NovaAmbientAssistantCoordinator` | `Nova/` | Contextual Nova suggestions |
| `PPNovaChatViewController` | `Nova/` | Chat UI for Nova |
| `PPNovaLocalChatMemory` | `Nova/` | Disk-persisted chat history |

## Module Documentation

### Pet Ads (`PetsAdsFiles/`)
- `PetAd` model with status, visibility, geohash, favorites tracking
- `PetAdManager` handles CRUD and Firestore sync
- Ad browser with filters and ad creation flow

### Bird Cards (`BirdsCards/`)
- `CardModel` with `AgeInfo`, `Location`, `Section` enums
- `CageModel` tracks parents, eggs, and children
- `ChildModel` for cage offspring
- Dedicated sales, archive, and cage management screens

### Payments & Checkout (`PAYMENTS/`)
- `CartItem` model with price, discount, subtotals
- `PPCheckoutCoordinator` (1291 lines) — coordinator pattern with idempotency key, generation-based stale callback protection, offline pre-check, cart validation, live inventory validation, pending order resolution
- Two payment paths: Cash on Delivery (immediate) vs QIB payment (via `verifyQibPayment` Cloud Function)
- Real-time order snapshot listener for status transitions
- App resume checkpoint for bank app OTP completion
- 25-second resolution timeout, error classification, retryable errors
- `PaymentMethodType` enum: Card, Ooredoo, QNB, ApplePay, FawryQatar, Cash, QIB
- Analytics: `PPAnalytics.logBeginCheckoutWithCartItems` + `logPurchaseWithTransactionID`

### Chat (`NewChats/`)
- `ChMessagingController` — real-time chat UI
- `ChManager` — message lifecycle and Firestore orchestration
- `ChatThreadModel` — thread metadata
- `ChatMessageModel` — status lifecycle: Pending → Sending → Sent → Delivered → Read

### User (`UserFiles/`)
- `PPUserSigningController` — sign-up and sign-in flow
- Profile management, settings, address book, pet profiles
- `UserModel` with 50+ properties

### Nova AI (`Nova/`)
- **PPNovaStreamingService.swift** — Firebase Functions typed `Callable` with streaming, calls `novaGenkitChat`
- **PPNovaGenkitService.m** — Non-streaming HTTPSCallable fallback
- **PPAgentClient.h/m** — ADK agent client at `https://nova-646051621158.us-central1.run.app`, session creation, message POST `/run`, 45s timeout
- **NovaAmbientAssistantCoordinator.swift** — Contextual suggestions (homeIdle, searchFocus), max 3/session, shake-to-trigger via `PPNovaMotionWindow`
- **NovaAmbientAssistantView.swift** — Glass-morphism capsule with staggered spring animation
- **PPNovaLocalChatMemory** — Disk-persisted history, 30-day expiry, starred messages
- **PPNovaChatViewController** — Chat UI with bubble cells, product cards, review cells
- **PPNovaOutputPresentationChecklist.md** — Manual regression checklist

### Veterinarians (`VeterinarianFiles/`)
- Vet listing with detail viewer

### Pet Services (`PetsServices/`)
- Services listing grid, service detail viewer, add-service flow

### Accessories (`Accessories/`)
- Pet accessories catalog

### Adoption (`AdoptPet/`)
- Pet adoption listing and request flow

### Search (`Search Controllers/`)
- `AppSearchHelper` — global search logic
- `AppSearchResultsVC` — search results display

### Banners (`Banners/`)
- `PPBannersManager` — banner data management
- `PPBannerCollectionCell` — banner display cell

## Data Flow

```
User Action → ViewController → AppManager (Firestore ref dF)
  → Cloud Function (write path with audit logging)
  → Firestore (real-time listeners via AppDataListenerManager)
  → Model update (NSSecureCoding)
  → UI refresh
```

- Writes go through Cloud Functions (Firestore rules enforce server-side validation)
- Reads use Firestore snapshot listeners managed by `AppDataListenerManager` for lifecycle safety
- Image loading: SDWebImage (primary) with YYWebImage (legacy) — 300MB disk / 200MB memory cache
- Chat: real-time Firestore listeners with status lifecycle

## Firestore Collections

| Collection | Purpose |
|---|---|
| `UsersCol` | User accounts and profiles |
| `PublicUserProfiles` | Public-facing user data |
| `PermisstionsCol` | Role-based permissions (typo intentional, permanent) |
| `MainKindsCollection` | Category hierarchy |
| `pet_ads` | Pet listings |
| `petAccessories` | Accessories inventory (only stock collection) |
| `serviceOffers` | Service provider offerings |
| `adopt_pets` | Adoption listings |
| `Orders` | Customer orders |
| `cartItems` | Shopping cart items |
| `requests` | User requests |
| `events` | Platform events |
| `FulfillmentOrders` | Fulfillment child orders (Phase 21A) |

> Reference: `Pure Pets Infra/` for complete schema and security rules.

## Cloud Functions

| Function | Trigger | Purpose |
|---|---|---|
| `verifyQibPayment` | Callable | QIB payment verification |
| `novaGenkitChat` | Callable (streaming) | Genkit AI agent chat |
| `providerTransitionFulfillment` | Callable | Fulfillment provider status transitions |
| `adminOverrideFulfillment` | Callable | Admin fulfillment overrides |
| `syncParentOrderFromFulfillments` | Internal | Sync parent order status from fulfillments |

All write functions follow the chain: `validateAuth() → requirePermission("permission.key") → validate input → business logic → writeAuditLog({...})`.

## Authentication

- Firebase Auth with email/password
- Google Sign-In (URL scheme configured)
- Session managed by `AppManager` — `(window as any).__PUREPETS_SESSION__?.uid` (web parity)
- Auth state listener in `SceneDelegate` routes to auth or main UI
- App Check enforced (AppAttest → DeviceCheck → Debug provider)

## Notifications

- **Push:** Firebase Cloud Messaging (remote-notification background mode)
- **Local:** Reminder scheduling via `AppManager`
- **Routing:** `SceneDelegate` handles remote notification routing to relevant screens

## Background Tasks

- `remote-notification` background mode for push processing
- `fetch` background mode for content updates
- Not detected in current source: `BGTaskScheduler` usage

## Caching

- **SDWebImage:** 300MB disk cache, 200MB memory cache (configured in `AppDelegate`)
- **YYKit:** Legacy caching (unmaintained library, warning suppression needed)
- **AppManager:** Users array cached to JSON on disk
- **PPNovaLocalChatMemory:** Chat history persisted to disk with 30-day expiry

## Offline Support

- Firestore offline persistence enabled (cached reads when offline)
- Offline pre-check in `PPCheckoutCoordinator` before checkout initiation
- Pending order resolution on reconnect

## Permissions

| Plist Key | Purpose |
|---|---|
| `NSCameraUsageDescription` | Camera for pet photos (Arabic + English) |
| `NSPhotoLibraryUsageDescription` | Photo library access |
| `NSPhotoLibraryAddUsageDescription` | Save photos to library |

**Background Modes:** `remote-notification`, `fetch`

**URL Schemes:** `purepets`, Google Sign-In

## Error Handling

- **Checkout:** Error classification with retryable vs non-retryable errors, 25-second resolution timeout
- **Network:** Offline pre-checks, Firestore listener reconnection
- **QIB Payment:** Cloud Function callback verification, app resume checkpoint for bank app OTP
- **Nova:** 45-second ADK client timeout, streaming vs non-streaming fallback
- Not detected in current source: centralized error reporting service (Crashlytics)

## Logging

- `PPAnalytics` — checkout begin/purchase events
- Not detected in current source: structured logging framework (OSLog, CocoaLumberjack, etc.)

## Security

- **App Check:** Mandatory — AppAttest (device) → DeviceCheck → Debug provider chain
- **Firestore Rules:** Enforced via `Pure Pets Infra/`, all 3 layers must agree (rules + Cloud Functions + client UI)
- **Cloud Functions:** Every write function validates auth and permission, writes audit log
- **QIB:** Device-only framework (arm64), server-side payment verification
- **Secrets:** `GoogleService-Info.plist` excluded from version control
- **Data:** Models use `NSSecureCoding` for safe deserialization

## Performance

- **Image Cache:** 300MB disk / 200MB memory via SDWebImage
- **Image Loading:** Coil (Android parity), SDWebImage (iOS primary), YYWebImage (legacy)
- **Listener Management:** `AppDataListenerManager` prevents orphaned Firestore listeners
- **Animation Constants:** `PPAnimationDefaultDuration`, `PPAnimationSpringDamping` for consistent perf
- **Shimmer:** `GM` utility for loading skeletons
- Not detected in current source: specific image compression/resizing pipeline, lazy loading metrics

## Accessibility

- **RTL Support:** Leading/trailing Auto Layout anchors, `Language.semanticAttributeForCurrentLanguage`
- **Dynamic Type:** Beiruti font family used, 11 size tiers (PPFontLargeTitle 33 → PPCaption2 10)
- **VoiceOver:** Not detected in current source (relies on UIKit defaults)
- **Tap Targets:** `PPTapFeedbackDown/Up` provides tactile feedback
- **Haptics:** `GM` utility methods for haptic feedback

## UI / Design System

### Spacing (8pt Grid)
| Token | Value |
|---|---|
| `PPSpaceXXS` | 2pt |
| `PPSpaceXS` | 4pt |
| `PPSpaceSM` | 8pt |
| `PPSpaceBase` | 12pt |
| `PPSpaceMD` | 16pt |
| `PPSpaceLG` | 24pt |
| `PPSpaceXL` | 32pt |
| `PPSpace2XL` | 40pt |
| `PPSpace4XL` | 48pt |

### Corner Radii
| Token | Value |
|---|---|
| `PPCornerSmall` | 12pt |
| `PPCornerCard` | 22pt |
| `PPCornerHero` | 32pt |
| `PPCornerPill` | 9999pt |

### Typography
- **Font Family:** Beiruti (all weights)
- **11 Sizes:** 33 (LargeTitle) down to 10 (Caption2)

### Colors
| Macro | Usage |
|---|---|
| `AppPrimaryClr` | Primary brand |
| `AppBackgroundClr` | Screen backgrounds |
| `AppForgroundColr` | Foreground surfaces |
| `AppSurfColor` | Surface/card backgrounds |
| `AppPrimaryTextClr` | Primary text |
| `AppSecondaryTextClr` | Secondary text |

### Shadows & Effects
- `PPApplyCardShadow` — standard card shadow
- `PPApplyContinuousCorners` — smooth corner masking
- `PPTapFeedbackDown` / `PPTapFeedbackUp` — press animation
- Shimmer loading via `GM`

### Animation
- `PPAnimationDefaultDuration` — standard duration
- `PPAnimationSpringDamping` — spring animation constant
- Nova ambient assistant: staggered spring, glass-morphism capsule
- Lottie animations via `GM`

## Dependencies

Listed in `Podfile`:

| Pod | Version | Purpose |
|---|---|---|
| FirebaseAuth | — | Authentication |
| FirebaseFirestore | — | Database |
| FirebaseStorage | — | File storage |
| FirebaseFunctions | — | Cloud Functions |
| FirebaseMessaging | — | Push notifications |
| FirebaseAppCheck | — | App attestation |
| YYKit | — | Caching and image processing (unmaintained) |
| SDWebImage | — | Image loading and caching |
| lottie-ios | — | Vector animations |
| XLForm | — | Form creation |
| IQKeyboardManager | — | Keyboard handling |
| SSZipArchive | — | Zip file handling |
| PopupDialog | — | Modal popups |
| ShowTime | — | Screen recording/mirroring (debug) |
| JGProgressHUD | — | Progress HUD |
| JDStatusBarNotification | — | Status bar notifications |
| TOCropViewController | — | Image cropping |
| HXPhotoPicker | — | Photo picker (Swift) |

**Frameworks:**
- `QIBPayment.framework` — Device-only arm64, Swift 5.7 (not in Podfile, bundled)

## Testing

- **Unit Tests:** `Pure PetsTests/` target
- **UI Tests:** `Pure PetsUITests/` target
- **Manual Regression:** `PPNovaOutputPresentationChecklist.md` for Nova AI output validation
- Not detected in current source: CI/CD configuration, coverage targets, snapshot tests

## Known Limitations

1. **QIBPayment.framework is device-only arm64** — Simulator builds cannot link QIB. Comment out QIB import and related code for simulator testing.
2. **YYKit is unmaintained** — Warning suppression needed. Consider migrating to SDWebImage exclusively.
3. **FirebaseFirestore + Xcode 16+** — `SWIFT_INSTALL_OBJC_HEADER = NO` may be required to resolve compilation issues.
4. **arm64 simulator exclusion** — YYKit WebP binary excluded on simulator; WebP images may not render in simulator.
5. **No static SwiftUI migration** — Per architecture rules, do not convert existing UIKit screens to SwiftUI.
6. **`PermisstionsCol` typo** — Intentional and permanent. Do not rename.

## Future Improvements

Not detected in current source. Maintainers should track items in the project issue tracker.

## Troubleshooting

| Issue | Solution |
|---|---|
| `QIBPayment` linker error on simulator | Comment out `#import "QIBPayment/..."` and related code in checkout flow |
| Firebase `FIRESTORE` compilation error on Xcode 16+ | Set `SWIFT_INSTALL_OBJC_HEADER = NO` in build settings |
| `pod install` fails | Ensure CocoaPods is up to date (`gem update cocoapods`), run `pod repo update` |
| Google Maps blank | Verify `GoogleService-Info.plist` is present and Google Maps API key is configured |
| App Check blocking requests | Ensure App Check debug provider is enabled in debug builds (automatic) |
| Push notifications not arriving | Verify APNs key in Firebase Console and correct `.entitlements` configuration |

## FAQ

**Q: Why is the project code-only UIKit?**
A: Storyboards/XIBs are avoided except for the legacy `Main.storyboard` splash entry point. Code-only UIKit provides better merge resolution, RTL safety, and reviewability.

**Q: How do I switch languages?**
A: The app supports Arabic (primary, RTL) and English (secondary, LTR). Use `Language.setLanguage:` programmatically. All strings use `kLang(@"key")` macro.

**Q: Can I use SwiftUI?**
A: No. Existing UIKit screens must not be converted to SwiftUI. New screens should use UIKit unless explicitly directed otherwise by the architecture team.

**Q: How is the Nova AI agent different from a chatbot?**
A: Nova is a dynamic platform agent that uses real Firebase data and real tools. It does not use hardcoded answers — it learns its role, follows platform logic, and responds dynamically based on Firestore state and business rules.

**Q: Where is the backend infrastructure?**
A: In `Pure Pets Infra/` — Firestore rules, Cloud Functions, indexes, and Storage rules. The infra repo is the source of truth for all backend configuration.

## Changelog

Not available. Refer to git history for changelog information.

## License

Not detected in current source. All rights reserved unless otherwise specified by the project owner.
