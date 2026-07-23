# Legacy Pet Ad Viewer Backup

This directory contains the retired Objective-C implementation of the legacy `ViewerVC` and `PPSimilarAdsView` for the Pure Pets iOS application.

## Retirement Rationale
The legacy `ViewerVC` was a monolithic Objective-C `UIViewController` (~130KB) that handled pet ad presentation, layout math, media gallery, and deep links manually. It has been superseded by the modern, state-driven SwiftUI implementation (`PPPetAdViewerHostingController` / `PPPetAdViewerScreen`).

## Retired Files
- `ViewerVC.h` & `ViewerVC.m` → Replaced by `PPPetAdViewerHostingController` / `PPPetAdViewerScreen`
- `PPSimilarAdsView.h` & `PPSimilarAdsView.m` → Replaced by `PPPetAdRelatedSection`

## Intentionally Retained Shared Dependencies
The following files in `Pure Pets/MainApp/AdsViewer Files/` were **NOT** moved to this backup because they are shared by other production features:
- `PPPetsTitleView.h` & `PPPetsTitleView.m` (used by `AccessViewerVC.m`)
- `PPInfoPillsView.h` & `PPInfoPillsView.m` (used by `ServiceViewerViewController.m` and `PPPetsTitleView.m`)

## Target Membership
These backup files are kept in the Git repository for audit and rollback purposes but are **EXCLUDED** from all Xcode build targets (`project.pbxproj`).

## Restoration
To restore the legacy implementation, see `INTEGRATION_ROLLBACK.md`.
