# Complete Dependency Audit Report — PurePets SwiftUI Root Refactor

This report lists all existing project framework, class, singleton, and notification dependencies consumed by `PurePetsSwiftUIRefactor/Root/`.

---

## 1. Third-Party & External Framework Dependencies

> [!NOTE]
> **No New External Dependencies Added.** The refactor relies solely on CocoaPods and system frameworks already present in the PurePets iOS application.

1. **`lottie-ios_Oc` (CocoaPod):**
   - Consumed by: `PPLottieAnimationRepresentable.swift`, `PPRootNovaLottieView.swift`, `PPRootGuestProfileLottieView.swift`.
   - Legacy usage: `LOTAnimationView`, `AppClasses setAnimationNamed:ToView:withSpeed:completion:`.
   - Interop mechanism: Dynamic runtime instantiation (`NSClassFromString(@"LOTAnimationView")`) with static fallback view.

2. **`SDWebImage` (CocoaPod):**
   - Consumed by: `PPRootAvatarView.swift`.
   - Legacy usage: `SDImageCache sharedImageCache`.
   - Interop mechanism: Dynamic memory cache check via runtime selector invocation.

---

## 2. Core Project Class & Singleton Dependencies

1. **`PPRootTabBarController` (Objective-C):**
   - Owned by: Target host container for `PPRootSwiftCoordinator`.
   - Interop: Objective-C protocol adapter `PPRootObjCAdapter`.

2. **`PPModernAvatarRenderer` (Objective-C):**
   - Consumed by: `PPRootAvatarView.swift`.
   - Method: `avatarImageForName:size:style:`.
   - Interop: Dynamic selector invocation with `@convention(c)` function bridge.

3. **`AppManager` / `PPUserManager` (Objective-C):**
   - Consumed by: `PPRootObjCAdapter.swift` for session snapshots and user block states.

4. **`PPCartFloatingBarCoordinator` (Objective-C):**
   - Consumed by: `PPRootObjCAdapter.swift` for cart item count and amount snapshots.

---

## 3. System Framework Dependencies

- `UIKit` (Core UI components & hosting container)
- `SwiftUI` (Declarative views & layout engine)
- `Combine` (Reactive state binding & notifications)
- `Foundation` (User defaults, timers, notification center)
