# Integration Rollback Procedure

To roll back the SwiftUI Pet Ad Viewer migration and restore `ViewerVC`:

1. **Move files back to original production location:**
   ```bash
   cd "Pure Pets IOS"
   git mv "Legacy Files Backup/Pet Ad Viewer/ViewerVC.h" "Pure Pets/MainApp/AdsViewer Files/ViewerVC.h"
   git mv "Legacy Files Backup/Pet Ad Viewer/ViewerVC.m" "Pure Pets/MainApp/AdsViewer Files/ViewerVC.m"
   git mv "Legacy Files Backup/Pet Ad Viewer/PPSimilarAdsView.h" "Pure Pets/MainApp/AdsViewer Files/PPSimilarAdsView.h"
   git mv "Legacy Files Backup/Pet Ad Viewer/PPSimilarAdsView.m" "Pure Pets/MainApp/AdsViewer Files/PPSimilarAdsView.m"
   ```

2. **Re-add `ViewerVC.[h/m]` and `PPSimilarAdsView.[h/m]` to `Pure Pets.xcodeproj/project.pbxproj` PBXBuildFile and PBXFileReference sections for the `Pure Pets` app target.**

3. **Restore call sites:**
   - In `PrefixHeader.pch`: Replace `#import "PPPetAdViewerLegacyBridge.h"` with `#import "ViewerVC.h"`.
   - In `PPOverlayCoordinator.m`: Revert `PPPetAdViewerHostingController` allocation to `[ViewerVC new]`.
   - In `PPNovaChatViewController.m`: Revert `PPPetAdViewerHostingController` allocation to `[[ViewerVC alloc] init]`.

4. **Clean build and test on device.**
