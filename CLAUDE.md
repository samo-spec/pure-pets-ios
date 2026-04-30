# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Setup

```bash
# Install / update dependencies (run from repo root after any Podfile change)
pod install

# Always open the workspace, never the .xcodeproj
open "Pure Pets.xcworkspace"
```

Build targets:
- **Device build** (QIBPayment.framework is device-only — simulator link will fail for QIB):
  ```bash
  xcodebuild -workspace 'Pure Pets.xcworkspace' -scheme 'Pure Pets' -configuration Debug \
    -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
  ```
- **Simulator build** (QIB payment path will not link, everything else builds normally):
  ```bash
  xcodebuild -workspace 'Pure Pets.xcworkspace' -scheme 'Pure Pets' -configuration Debug \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' CODE_SIGNING_ALLOWED=NO build
  ```

Minimum deployment target: **iOS 15.0** (pods are pinned to 13.0 for compatibility).

## Architecture

### Language Split
The codebase is primarily **Objective-C** with targeted Swift additions bridged back via `Pure Pets-Bridging-Header.h`. Every Swift file that needs to be called from ObjC must use `@objc`. The bridging header currently only exposes `CartItem.h`.

### Global Singletons — AppManager & GM
- **`AppManager`** (`AppManager.h/.m`) — shared instance (`AppManager.sharedInstance` / `AppMgr` macro). Owns the Firestore reference (`dF`), user session, URL image cache, audio upload, and app-wide snack-bar presentation.
- **`GM`** — stateless utility class of `+` class methods for image loading, Firebase Storage, media compression, font access, color helpers, analytics, and miscellaneous UI helpers (shadows, shimmer, haptics, price formatting). All color accessors on `GM` mirror the named-color macros.

Both are imported globally via `PrefixHeader.pch` — they are available in every `.m` file without a local import.

### Layer Separation
```
Pure Pets/
├── MainApp/          ← Feature view controllers and feature-scoped helpers
├── FireData/         ← Firestore/RTDB listeners (AppDataListenerManager, CagesManager, TrashManager)
├── DataClasses/      ← Model objects and their managers
│   ├── BasicDataClassess/   ← MainKinds hierarchy (categories / sub-kinds)
│   ├── BirdsCardsDataClassess/  ← Card, Cage, Child, Buyer, Archive models
│   └── HelperClassess/      ← FileUploadManager, PPAuditLogger, BarcodeGenerator, Watermark
├── DesignFiles/      ← Reusable UI library (no business logic)
│   ├── PP/PPStyles/  ← Design tokens, Styling helpers, PPThemeRefresh, PPFunc
│   ├── PP/PPComponent/ ← Reusable components (PPProductCard, PPRatingView, PPTextField, PPS, etc.)
│   ├── PP/PPNAV/     ← Navigation chrome (PPBottomBar, PPNavigationController, UIViewController+PPNavBar)
│   └── MostUsed/     ← Language, XLForm, DZNEmptyDataSet, utility categories
├── Bridges/          ← Swift/ObjC interop (PPCoreBridge.swift, HXPHPickerBridge, UnifiedBlurHash)
└── Resources/        ← Beiruti font, JSON data, localization strings
```

Do **not** put business logic or Firebase calls inside `DesignFiles/`. Do **not** put UI code inside `FireData/`.

### Design System
All tokens live in `PPDesignTokens.h` (spacing 8pt grid, corner radii, typography, touch targets, shadows, animation durations). Macros are globally available via `PrefixHeader.pch`.

Key macros to use:
- Spacing: `PPSpaceSM` (8), `PPSpaceBase` (16), `PPScreenMargin` (20)
- Corners: `PPCornerCard` (22), `PPCornerHero` (32), `PPCornerPill` (9999)
- Colors: `AppPrimaryClr`, `AppBackgroundClr`, `AppForgroundColr`, `AppSurfColor`, `AppPrimaryTextClr`, `AppSecondaryTextClr`
- Apply shadow helpers: `PPApplyCardShadow(view)`, `PPApplyContinuousCorners(view, radius)`
- Tap animation: `PPTapFeedbackDown(view)` / `PPTapFeedbackUp(view)`
- Typography: `[GM boldFontWithSize:PPFontHeadline]` (adds +1pt internally)

### Navigation
`PPBottomBar` / `PPBottomBarManager` owns the custom tab bar (`PPBar` macro). Nav bar chrome is applied through `UIViewController+PPNavBar` (imported in `PrefixHeader.pch`). Use `PPNavigationController` for push navigation.

`PPOverlayCoordinator` manages full-screen overlay transitions. `DeepLinkRouter` handles universal and in-app deep links.

### Feature Modules (MainApp/)
| Folder | Responsibility |
|---|---|
| `ModrenAppVC/` | Home feed (`PPHomeViewController`), root tab controller (`PPRootTabBarController`), overlay coordinator |
| `AdsViewer Files/` | Pet listing viewer (`ViewerVC`) with pills and title views |
| `PetsAdsFiles/` | Pet ad model/manager (`PetAd`, `PetAdManager`), ad browser, ad creation coordinator |
| `BirdsCards/` | Bird-specific listing flow (cards, sales, archive, cages) |
| `PAYMENTS/` | Cart, checkout (`PPCheckoutCoordinator`), order manager, QIB payment manager, payment method selection |
| `NewChats/` | Real-time messaging (`ChMessagingController`, `ChManager`, `ChatThreadModel`) |
| `UserFiles/` | Auth (`PPUserSigningController`), profile, settings, addresses, pet profiles |
| `VeterinarianFiles/` | Vet listings and viewer |
| `Accessories/` | Pet accessories listing |
| `PetsServices/` | Services listing, service viewer, add-service form |
| `AdoptPet/` | Pet adoption flow |
| `Search Controllers/` | Cross-entity search (`AppSearchHelper`, `AppSearchResultsVC`) |
| `Banners/` | Home banner carousel (`PPBannersManager`, `PPBannerCollectionCell`) |

### Payments / Checkout
The checkout flow uses a coordinator pattern (`PPCheckoutCoordinator`). All debug logs use the `[PPORDER]` prefix. `QIBPayment.framework` is device-only — never attempt to build/test the online payment path in the simulator. See `ORDER_CHECKOUT_AUDIT_README.md` inside `MainApp/PAYMENTS/` for the full flow contract.

### Localization
Strings live in `Pure Pets/ar.lproj/Localizable.strings` and `Pure Pets/en.lproj/Localizable.strings`. RTL/LTR is controlled globally by `Language.isRTL` and semantic-content macros (`PPSemanticAuto`, `PPSemanticRightToLeft`). All user-facing strings must have both Arabic and English entries.

### Firebase
- Firestore reference: `AppMgr.dF`
- Auth: `PPCurrentFIRAuthUser` (macro for `[FIRAuth auth].currentUser`)
- Current user model: `PPCurrentUser` (macro for `UserManager.sharedManager.currentUser`)
- All Firestore listeners must be retained and removed on `dealloc`/`viewDidDisappear` to avoid memory leaks.

### Logging
- Debug builds: `DLog(...)` and `PPShortNSLog(label, token, keepChars)` from `PrefixHeader.pch`.
- Payment flow: `[PPORDER]` prefix via `NSLog`.
- Structured levels: `LOG_DEBUG`, `LOG_INFO`, `LOG_WARN`, `LOG_ERROR` macros (also in `PrefixHeader.pch`).

### MCP Tooling
`xcode-studio-mcp/` provides an MCP server for deeper Xcode integration (simulator control, build diagnostics). Use it when debugging simulator or build-system issues.

## Key Conventions
- All layout is **code-only UIKit** — no Storyboards except the legacy `Main.storyboard` splash entry point.
- Use `weakSelf` patterns in all ObjC blocks to prevent retain cycles.
- New CocoaPods dependencies require explicit approval before adding to `Podfile`.
- Swift additions must be exposed with `@objc` and declared in the bridging header when called from ObjC.
- `PPDesignTokens.h` tokens take precedence over hardcoded values. Avoid magic numbers for spacing, corners, or typography.
