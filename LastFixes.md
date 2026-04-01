# 🛡 LastFixes — Production Safety Audit

**Date:** March 27, 2026  
**Scope:** `BirdsCards/`, `MianData_Files/`, `MainApp/`, `DesignFiles/`  
**Commit:** `1310290`  
**Files Changed:** 77 | **Insertions:** 1,743 | **Deletions:** 1,129

---

## Summary

| Severity | Count | Description |
|----------|-------|-------------|
| 🔴 CRITICAL | 29 | Array out-of-bounds, nil crashes, iPad popover, retain cycles |
| 🟠 HIGH | 18 | Retain cycles, underflow guards, keyWindow nil, snapshot nil |
| 🟡 MEDIUM | 7 | Nil coalescing, delegate checks, address line guards |
| **Total** | **54** | |

---

## 🔴 CRITICAL Fixes (29)

### MainController.m
| Fix | Description |
|-----|-------------|
| `mc-tabbar-bounds` | Unsafe `tabItems[0..4]` — added count check before accessing tab bar items |
| `mc-array-bounds` | 8+ unsafe array subscripts — added bounds checks on all `UserArchivesDocs`, bird arrays |
| `mc-archive-bounds` | Unsafe `UserArchivesDocs` access — added nil + count guards |
| `mc-retain-cycle` | *(also HIGH)* Search animation block retain cycle — added `__weak`/`__strong` |

### ChMessagingController.m
| Fix | Description |
|-----|-------------|
| `chat-msg-bounds` | `messages[indexPath.row]` no bounds check + `[row-1]` crash at row=0 — added bounds guards |

### selectArchiveVC.m (6 fixes)
| Fix | Description |
|-----|-------------|
| `sa-bounds-853` | `archiveDetails[selectedIndexPath.row]` no bounds check |
| `sa-bounds-855` | `archiveArray[indexPath.row]` no bounds check |
| `sa-bounds-866` | `archiveDetails[selectedIndexPath.row]` reuse of stale index |
| `sa-bounds-878` | `removeObjectAtIndex:selectedIndexPath.row` no bounds check |
| `sa-bounds-897` | `archiveDetails[indexPath.row]` no bounds in delete |
| `sa-bounds-961` | `removeObjectAtIndex` after async — stale index guard |

### selectChildViewController.m (3 fixes)
| Fix | Description |
|-----|-------------|
| `sc-bounds-396` | `ChildsdataSource[indexPath.row]` no bounds in `cellForRow` |
| `sc-bounds-575` | `removeObjectAtIndex` missing upper bound check |
| `sc-bounds-844` | `removeObjectAtIndex` after async missing upper bound |

### OrderDetailsViewController.m
| Fix | Description |
|-----|-------------|
| `od-nil-dict` | `selectedReason` nil dict subscript crash — added nil guard |
| `od-nav-nil` | Nil `navigationController` in async block — added nil check |

### SalesVCViewController.m
| Fix | Description |
|-----|-------------|
| `sales-buyer-bounds` | `BuyerArray[indexPath.row]` no bounds check in `cellForRow` |
| `sales-files-bounds` | `FilesArray[0]`/`[1]` no count check — added `count >= 2` guard |

### FirstEggVC.m
| Fix | Description |
|-----|-------------|
| `egg-remove-bounds` | `childsArray removeObjectAtIndex:rowIndex` no bounds — added range check |

### OTPViewController.m
| Fix | Description |
|-----|-------------|
| `otp-uid-nil` | `FIRAuth currentUser.uid` nil crash in `profileRef` — added early return |
| `otp-insert-uid` | `user.uid` nil in `insertUserData` — added nil guard |

### ImagePicker.m
| Fix | Description |
|-----|-------------|
| `img-ipad-popover` | iPad crash: `UIImagePickerController` no popover config — added `sourceView`/`sourceRect` + fixed `self.view` → `self.presentingViewController.view` (NSObject subclass) |

### PPRootTabBarController.m
| Fix | Description |
|-----|-------------|
| `tabbar-bounds` | `viewControllers[3]` no bounds check — added `count > 3` guard (2 sites) |

### PPHomeViewController.m
| Fix | Description |
|-----|-------------|
| `home-snapshot-bounds` | `sectionIdentifiers[section]` no bounds check — added guard |

### PPSalesPDFGenerator.m
| Fix | Description |
|-----|-------------|
| `pdf-nil-params` | Nil `buyer`/`card` params cause crash — added early return with error log |

### PPSelectPaymentVC.m
| Fix | Description |
|-----|-------------|
| `pay-checkout-retain` | Retain cycle: `self→coordinator→block→self` — added `__weak`/`__strong` |

### MyServicesViewController.m
| Fix | Description |
|-----|-------------|
| `svc-indexpath-nil` | `indexPathForCell` returns nil → crash in 3 delegate methods — added nil checks |

### DeepLinkRouter.m
| Fix | Description |
|-----|-------------|
| `dl-nav-crash` | Nil `window` + unsafe cast to `UINavigationController` — added nil + class check |

### AdoptPetsViewController.m
| Fix | Description |
|-----|-------------|
| `adopt-cells-bounds` | `items[indexPath.item]` no bounds check in `cellForItem` — added guard |

### AccessViewerVC.m
| Fix | Description |
|-----|-------------|
| `access-viewer-bounds` | `suggestedAccessories[indexPath.item]` no bounds check — added guard |

---

## 🟠 HIGH Fixes (18)

| File | Fix ID | Description |
|------|--------|-------------|
| ChMessagingController.m | `chat-snapshot-nil` | `snapshot.data` nil before key access — added nil check |
| DeepLinkRouter.m | `dl-path-bounds` | `pathComponents` nil check missing — added guard |
| FirstEggVC.m | `egg-image-nil` | `imagesNames.firstObject` nil creates bad URL — added nil check |
| MainController.m | `mc-retain-cycle` | Search animation block retain cycle — `__weak`/`__strong` |
| NewCardForm.m | `ncf-preload-retain` | Image preload completion retain cycle — `__weak`/`__strong` |
| NewCardForm.m | `ncf-upload-retain` | Upload flow retain cycles + unsafe ivar access — `__weak`/`__strong` |
| OrderDetailsViewController.m | `od-events-bounds` | `events[indexPath.row]` no bounds — added check |
| OrderDetailsViewController.m | `od-requests-bounds` | `requests[indexPath.row]` no bounds — added check |
| OrderDetailsViewController.m | `od-lines-bounds` | `lineItems[indexPath.row]` no bounds — added check |
| OrderHistoryViewController.m | `oh-orders-bounds` | `displayedOrders[indexPath.row]` no bounds — added check |
| PPHomeViewController.m | `home-prefetch-bounds` | `sections[]` prefetch bounds/cast issue — added guard |
| ProfileVC.m | `profile-window-nil` | `windows.firstObject` no nil check — added guard |
| SalesVCViewController.m | `sales-retain-cycles` | 5 completion blocks without `__weak` — added `__weak`/`__strong` |
| SplashViewController.m | `splash-window-nil` | Fallback `windows.firstObject` no nil check — added guard |
| VetModel.m | `vet-model-nil` | Dict subscript no type checking/nil coalescing — added safe defaults |
| ZXQRScanViewController.m | `qr-nil-device` | Nil `AVCaptureDevice` passed to `deviceInputWithDevice:` — added nil guard |
| viewDataVC.m | `viewdata-nil-ring` | `firstObject` nil → `RingID` access no nil check — added guard |
| AddNewAd.m | `ad-upload-nil-url` | Firebase upload nil URL not fully handled — added nil guard |

---

## 🟡 MEDIUM Fixes (7)

| File | Fix ID | Description |
|------|--------|-------------|
| ChMessagingController.m | `chat-cell-bounds` | `cellForRow messages[]` no bounds check — added guard |
| FirstEggVC.m | `egg-dict-nil` | Dict `objectForKey:` nil → `(null)` string propagation — added fallback |
| LocationPickerViewController.m | `location-lines-nil` | `address.lines` nil before `componentsJoinedByString` — added nil coalescing |
| OrderHistoryViewController.m | `oh-underflow` | `NSUInteger` underflow `count-3` when count < 3 — added `MAX(0, ...)` |
| PPSelectPaymentVC.m | `pay-dispatch-retain` | Strong `self` in `dispatch_async` — `__weak`/`__strong` |
| ProfileVC.m | `profile-form-err` | `errors.firstObject userInfo` nil crash — added nil check |
| selectArchiveVC.m | `sa-delegate-nil` | Delegate call no `respondsToSelector:` check — added guard |

---

## 🔧 Patterns Applied

### Array Bounds Check
```objc
if (indexPath.row >= array.count) return cell;     // cellForRow
if (indexPath.row >= array.count) return;           // didSelectRow
```

### Nil Guard with Early Return
```objc
if (!object) { NSLog(@"❌ object is nil"); return; }
```

### Retain Cycle Break
```objc
__weak typeof(self) weakSelf = self;
[someBlock:^{
    __strong typeof(weakSelf) strongSelf = weakSelf;
    if (!strongSelf) return;
    // use strongSelf
}];
```

### iPad Popover Safety
```objc
if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
    picker.modalPresentationStyle = UIModalPresentationPopover;
    picker.popoverPresentationController.sourceView = sourceView;
    picker.popoverPresentationController.sourceRect = sourceView.bounds;
}
```

### NSUInteger Underflow Guard
```objc
NSUInteger safeIndex = (count >= 3) ? (count - 3) : 0;
```

---

## ✅ Build Status

- **Compile:** Zero errors — all source files compile cleanly
- **Linker:** Pre-existing `QIBPayment.framework` device-only error (not caused by these fixes)

---

## 📋 Earlier Fixes (Same Session, Already Committed)

| Commit | Description |
|--------|-------------|
| Apple 5.1.1 compliance | Created `PPPermissionHelper` — centralized camera/photo permission flows |
| NewCardForm back button | Removed duplicate white programmatic back button |
| iPad camera fix | `PPImageCollection.m` — popover + 0.35s timing delay for iPad |
| ArchiveManagerVC rewrite | Full modern UI refactor with compositional layout (259→612 lines) |

---

## 🔧 UIActivityViewController Crash + iPad Popover Safety (Commit `97b3cb3`)

**Root Cause:** `PPBirdSummaryCollectionCell` share action used `UIMenuElementAttributesKeepsMenuPresented`, keeping the context menu presented while the share handler tried to present `UIActivityViewController` on the same tab bar controller → crash.

### Fixes Applied (11 files)

| # | File | Fix |
|---|------|-----|
| 1 | `PPBirdSummaryCollectionCell.m` | Removed `UIMenuElementAttributesKeepsMenuPresented` so context menu auto-dismisses before share handler |
| 2 | `MainController.m` | Added safety dismiss of any existing presented VC before sharing (index==3) |
| 3 | `GM.m` (`shareToWhatsApp:sharingImage:inViewController:`) | Added iPad popover config + dismiss-before-present safety |
| 4 | `OrderDetailsViewController.m` | Added iPad popover for `shareOrderTapped` UIActivityViewController |
| 5 | `PetAccessory.m` | Added iPad popover for `exportAsPDF:fromViewController:` |
| 6 | `MyServicesViewController.m` | Added iPad popover with cell as sourceView |
| 7 | `ServiceViewerViewController.m` | Added iPad popover for `shareTapped` |
| 8 | `VetViewerViewController.m` | Added iPad popover for `shareTapped` |
| 9 | `AdoptPetsViewController.m` | Added iPad popover with cell as sourceView + fixed method separator |
| 10 | `PPSalesPDFGenerator.m` | Added missing `sourceRect` + `permittedArrowDirections` |
| 11 | `PPAdSharingHelper.m` | Added iPad popover for `UIAlertControllerStyleActionSheet` |

### iPad Popover Pattern Used

```objc
if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
    activityVC.popoverPresentationController.sourceView = self.view;
    activityVC.popoverPresentationController.sourceRect = CGRectMake(
        CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 0, 0);
    activityVC.popoverPresentationController.permittedArrowDirections = 0;
}
```

---

## Fix 8 — Lottie Header Animation Not Appearing (PPHomeHeroCell)

**Date:** 2025  
**Severity:** HIGH  
**File:** `PPHomeHeroCell.m`

### Problem

The Lottie animation in the home hero cell stopped appearing. The `lottieHeaderView` was created and configured but never rendered visually.

### Root Causes (5 issues found)

| # | Issue | Severity |
|---|-------|----------|
| 1 | `animationFinished` check in loop method permanently killed the animation loop if the first play was interrupted | CRITICAL |
| 2 | `loopAnimation = YES` set in init conflicted with the manual loop control method | HIGH |
| 3 | Lottie view extended 10pt outside `heroSurfaceView` bounds, clipped by `layer.mask` from `Styling.applyCornerMaskToView:` | HIGH |
| 4 | No retry after Firebase fetch failure — `currentLottiePath` was set but never cleared on error | MEDIUM |
| 5 | `prepareForReuse` didn't reset Lottie state — old scheduled loops from previous cell use could fire | MEDIUM |

### Fixes Applied

1. **Removed `if (!animationFinished) return;` bail-out** — replaced with 0.5s retry for interrupted plays, 2s delay for normal finish. Added `hidden = NO` and `alpha = 1.0` safety at start of each loop iteration.
2. **Removed `loopAnimation = YES`** from init. Changed `contentMode` from `UIViewContentModeScaleAspectFill` to `UIViewContentModeScaleAspectFit`.
3. **Zeroed constraints** — changed top from `-10` to `0` and bottom from `+10` to `0` so Lottie stays within `heroSurfaceView` bounds.
4. **Clear `currentLottiePath` on error** so `pp_updateLottieForCurrentTimeIfNeeded` can retry on next call.
5. **Reset Lottie state in `prepareForReuse`** — increment `lottieLoopToken`, stop animation, clear `currentLottiePath`.

### Additional Safety

- Added `bringSubviewToFront:` after `setSceneModel:` to ensure Lottie is above other subviews
- Added `setNeedsLayout` + `layoutIfNeeded` after loading to force render
- Added diagnostic `NSLog` for troubleshooting animation load issues
