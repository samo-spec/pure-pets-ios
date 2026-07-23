# PurePets SwiftUI Root Refactor — Build Readiness & Target Allocation Report

This report presents the runtime risk assessment, target membership allocation, minimal bridging-header architecture, and manual Xcode integration steps for `PurePetsSwiftUIRefactor/Root/`.

---

## 1. Compilation Status

> **Compilation Status:** **UNVERIFIED**
> In accordance with project instructions (`AGENTS.md`), CLI `xcodebuild` commands are prohibited. Code structure and runtime safety patterns have been audited locally, but compilation status remains UNVERIFIED until a manual build is performed in Xcode targeting a physical device.

---

## 2. Runtime Risk & Mitigation Report

| Risk ID | Feature / Component | Code Strategy | Mitigation Status |
| :--- | :--- | :--- | :--- |
| **RCR-01** | Avatar Rendering | `PPModernAvatarRenderer` via reflection | Safe reflection check with default placeholder fallback. Zero pointer casting. |
| **RCR-02** | Lottie Linkage | Dynamic class check for `LOTAnimationView` | Checks `NSClassFromString(@"LOTAnimationView")` with SF Symbol fallback. No missing pod crash. |
| **RCR-03** | Navigation Proxying | `PPRootNavigationDelegateProxy` | Safe selector forwarding via `responds(to:)` and `forwardingTarget(for:)`. |
| **RCR-04** | Cart Collapse Timer | `PPRootStore` 6s timer | Main-thread scheduled timer with weak self capture and `stop()` cleanup. |
| **RCR-05** | Touch Pass-Through | `PPRootPassthroughHostingController` | Overrides `hitTest(_:with:)` to yield touches to underlying UIKit views. |

---

## 3. Minimal Bridging-Header Requirement

The bridge setup requires only a single header import:

```objc
#import "PPRootLegacyAdapter.h"
```

No direct imports of `UserManager.h`, `CartManager.h`, `ChManager.h`, `PPBottomSurfaceCoordinator.h`, or `PPRootTabBarController.h` are required in the bridging header. All internal dependencies are encapsulated in `PPRootLegacyAdapter.m`.

---

## 4. Target Membership Allocation

### App Target (`Pure Pets`):
- Production Swift Files (25 files):
  - `Adapters/PPRootNavigationDelegateProxy.swift`
  - `Adapters/PPRootObjCAdapter.swift`
  - `Coordinator/PPRootStore.swift`
  - `Coordinator/PPRootSwiftCoordinator.swift`
  - `FeatureFlag/PPRootFeatureFlag.swift`
  - `Models/PPBlockedAccountState.swift`
  - `Models/PPCartFloatingBarState.swift`
  - `Models/PPRootNovaState.swift`
  - `Models/PPRootSessionState.swift`
  - `Models/PPRootTab.swift`
  - `Protocols/PPRootActionHandling.swift`
  - `Utilities/PPHaptics.swift`
  - `Views/PPBlockedAccountOverlayView.swift`
  - `Views/PPCartFloatingBarView.swift`
  - `Views/PPLottieAnimationRepresentable.swift`
  - `Views/PPRootAvatarView.swift`
  - `Views/PPRootBottomOverlayView.swift`
  - `Views/PPRootDock.swift`
  - `Views/PPRootDockItem.swift`
  - `Views/PPRootGuestProfileLottieView.swift`
  - `Views/PPRootNovaButton.swift`
  - `Views/PPRootNovaLottieView.swift`
  - `Views/PPRootPassthroughHostingController.swift`
  - `Views/PPRootPassthroughView.swift`
- Objective-C Adapter Implementation (1 file):
  - `Adapters/PPRootLegacyAdapter.m`
- Objective-C Adapter Header (Header reference):
  - `Adapters/PPRootLegacyAdapter.h`

### Test Target (`Pure PetsTests`):
- `Tests/PPRootParityTests.swift`

### Markdown & Documentation (No Target):
- `Documentation/*.md`

---

## 5. Manual Xcode Integration Steps

1. Open `Pure Pets.xcworkspace` in Xcode.
2. Drag `PurePetsSwiftUIRefactor/Root/` files into Xcode project navigator under `Pure Pets/MainApp/ModrenAppVC/`.
3. Set **Target Membership** for the 25 production Swift files and `PPRootLegacyAdapter.m` to **`Pure Pets`**.
4. Set **Target Membership** for `Tests/PPRootParityTests.swift` to **`Pure PetsTests`** only.
5. In `Pure Pets-Bridging-Header.h`, add `#import "PPRootLegacyAdapter.h"`.
6. Build project (Cmd+B) on a connected physical iOS device.
