# SwiftUI Root Architecture — Manual Integration & Target Guide

This guide provides step-by-step instructions for target membership configuration, bridging header configuration, manual Xcode integration, and instant rollback for the generated `PurePetsSwiftUIRefactor/Root/` architecture.

---

## 1. Target Membership Allocation

When adding the refactored files into your Xcode Workspace (`Pure Pets.xcworkspace`):

### Production Files → App Target (`Pure Pets`)
- **Swift Core & Views (25 files):**
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
- **Objective-C Adapter Implementation (1 file):**
  - `Adapters/PPRootLegacyAdapter.m`

### Objective-C Adapter Header (Header Only)
- `Adapters/PPRootLegacyAdapter.h` (App Target / Project Visibility)

### Test Target Only (`Pure PetsTests`)
- `Tests/PPRootParityTests.swift`

### Markdown & Documentation (No Target Membership)
- `Documentation/*.md`
- `PPRootBuildReadinessReport.md`
- `PPRootDependencyReport.md`
- `PPRootIntegrationGuide.md`
- `PPRootLegacyParityMatrix.md`

---

## 2. Minimal Bridging-Header Requirement

To expose `PPRootLegacyAdapter` to Swift without introducing broad header dependencies, add only a single import line to `Pure Pets-Bridging-Header.h`:

```objc
#import "PPRootLegacyAdapter.h"
```

All actual internal Objective-C header dependencies (`UserManager.h`, `CartManager.h`, `ChManager.h`, `PPBottomSurfaceCoordinator.h`, `PPRootTabBarController.h`) are encapsulated completely inside `PPRootLegacyAdapter.m`.

---

## 3. Integration Steps (When Testing)

### Step 1: Add Swift Coordinator Property to `PPRootTabBarController.h`
In `PPRootTabBarController.h`, import `<Pure_Pets-Swift.h>` or forward declare `@class PPRootSwiftCoordinator;` and add property:

```objc
@class PPRootSwiftCoordinator;

@interface PPRootTabBarController : UITabBarController <UITabBarControllerDelegate>
@property (nonatomic, strong, nullable) PPRootSwiftCoordinator *swiftCoordinator;
@property (nonatomic, assign) BOOL useLegacyBar;
// ...
```

### Step 2: Instantiate & Start Coordinator in `viewDidLoad`
In `PPRootTabBarController.m` (`viewDidLoad`):

```objc
- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Check feature flag before enabling SwiftUI Root
    if (PPRootFeatureFlag.shared.isSwiftUIRootEnabled) {
        self.swiftCoordinator = [[PPRootSwiftCoordinator alloc] initWithHostController:self useLegacyBar:self.useLegacyBar];
        [self.swiftCoordinator start];
    } else {
        // Legacy Objective-C setup...
        [self pp_setupPremiumBottomNavigation];
    }
}
```

### Step 3: Forward Lifecycle Hooks to Coordinator
Forward container lifecycle methods from `PPRootTabBarController.m`:

```objc
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.swiftCoordinator viewWillAppearWithAnimated:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.swiftCoordinator viewDidAppearWithAnimated:animated];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self.swiftCoordinator viewDidLayoutSubviews];
}
```

---

## 4. Instant Rollback Procedure

If any issue arises during manual physical device testing, revert to legacy UIKit dock instantly via feature flag:

```objc
PPRootFeatureFlag.shared.isSwiftUIRootEnabled = NO;
```

When disabled, `PPRootSwiftCoordinator` is not initialized, and `PPRootTabBarController.m` executes its original Objective-C dock logic seamlessly.

---

## 5. Compilation Status Notice

> **Compilation Status:** **UNVERIFIED**
> Per workspace safety policies (`AGENTS.md`), command-line `xcodebuild` is prohibited. Final compilation status remains UNVERIFIED until a manual build is completed in Xcode on a physical connected iOS device.
