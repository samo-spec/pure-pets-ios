# iOS Unused Files and Resources Audit

**Generated:** 2026-07-18T21:11:50Z  
**Repository:** /Users/mohammedahmed/Desktop/PurePets/PurePetsProjects/Pure Pets IOS

## 1. Executive Summary

| Metric | Count |
|--------|-------|
| Files scanned | 1659 |
| Xcode projects inspected | 2 |
| Targets inspected | 3 |
| Asset catalogs | 4 |
| Asset sets scanned | 106 |
| Storyboards | 4 |
| XIB/NIB files | 6 |
| Localization files | 11 |
| Confirmed project issues | 0 |
| High-confidence unused | 93 |
| Probable unused | 1 |
| Manual review required | 47 |
| Protected resources | 732 |
| Repository hygiene | 15 |
| Files outside Xcode project | 172 |
| Duplicate groups | 4 |

## 2. Audit Scope

### Projects
- Podfile
- Pure Pets.xcodeproj
### Workspaces
- Pure Pets.xcworkspace
### Targets
- "Pure Pets"
- "Pure PetsTests"
- "Pure PetsUITests"
### Excluded
- `.build/`
- `.git/`
- `Carthage/`
- `DerivedData/`
- `Pods/`
- `SourcePackages/`
- `build/`
- `xcuserdata/`

### Languages
- Objective-C (primary)
- Swift
- UIKit (code-only)
- CocoaPods
- SPM

## 3. Confirmed Project Issues

None found.

## 4. High-Confidence Unused Candidates

| # | Path | Type | Target | Confidence | Reason |
|---|------|------|--------|------------|--------|
| 1 | Pure Pets/Bridges/UnifiedBlurHash/UnifiedImage.swift | source | Pure Pets | High | Compiled but no static references to its declarations |
| 2 | Pure Pets/Bridges/UnifiedBlurHash/UnifiedImage+Encode.swift | source | Pure Pets | High | Compiled but no static references to its declarations |
| 3 | Pure Pets/Bridges/UnifiedBlurHash/UnifiedImage+Scale.swift | source | Pure Pets | High | Compiled but no static references to its declarations |
| 4 | Pure Pets/Bridges/UnifiedBlurHash/UnifiedImage+Decode.swift | source | Pure Pets | High | Compiled but no static references to its declarations |
| 5 | Pure Pets/Bridges/UnifiedBlurHash/SwiftUI.Image+BlurHash.swift | source | Pure Pets | High | Compiled but no static references to its declarations |
| 6 | Pure Pets/MainApp/PAYMENTS/PPPaymentsFiles/PPPaymentBasicsSettingsViewController.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 7 | Pure Pets/MainApp/Accessories/AccessFiles/AccessoryCollectionViewCell.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 8 | Pure Pets/MainApp/NewChats/helpers/PPMediaPreviewController.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 9 | Pure Pets/MainApp/NewChats/helpers/SubHelpers/PPVoicePreviewBubbleView.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 10 | Pure Pets/MainApp/NewChats/helpers/SubHelpers/WAVE/PPRecordingWaveformView.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 11 | Pure Pets/MainApp/PetsServices/AddPetServiceOfferViewController.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 12 | Pure Pets/MainApp/Banners/PPBannerCell.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 13 | Pure Pets/MainApp/PetsAdsFiles/CreateAdCoordinator.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 14 | Pure Pets/MainApp/PetsAdsFiles/PetsAdvertiseImagesAndCells/PPUniversalCellFlags.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 15 | Pure Pets/MainApp/PetsAdsFiles/AdsBrowser/PPCenteredSelectorCell.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 16 | Pure Pets/MainApp/PetsAdsFiles/New Ad/PPAdSubmitCoordinator.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 17 | Pure Pets/MainApp/VeterinarianFiles/AddVetViewController.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 18 | Pure Pets/MainApp/VeterinarianFiles/VetCollectionViewCell.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 19 | Pure Pets/MainApp/AdoptPet/PetAdoptCollectionViewCell.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 20 | Pure Pets/MainApp/AdoptPet/TitleSubtitleCell.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 21 | Pure Pets/MainApp/ModrenAppVC/PPHomeViewController.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 22 | Pure Pets/MainApp/ModrenAppVC/HomeCells/PPHomeActionCell.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 23 | Pure Pets/MainApp/ModrenAppVC/HomeCells/PPModernHomeActionCell.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 24 | Pure Pets/MainApp/ModrenAppVC/HomeCells/PPAdsNearByCarouselCell.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 25 | Pure Pets/MainApp/ModrenAppVC/HomeCells/PPHomeMarketplaceHeroCell.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 26 | Pure Pets/MainApp/ModrenAppVC/HomeCells/PPHomeHeroCell.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 27 | Pure Pets/MainApp/ModrenAppVC/HomeCells/PetAdoptView.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 28 | Pure Pets/MainApp/ModrenAppVC/HomeCells/PPHomeBannerContainerCell.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 29 | Pure Pets/MainApp/ModrenAppVC/HomeCells/PPHomePremiumCareCell.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 30 | Pure Pets/MainApp/ModrenAppVC/HomeCells/PPCategoryCardCell.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 31 | Pure Pets/MainApp/ModrenAppVC/HomeCells/PPHomeUltraPremuimPetCareCell.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 32 | Pure Pets/MainApp/ModrenAppVC/HomeCells/PPHomeServicesCell.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 33 | Pure Pets/MainApp/ModrenAppVC/HomeCells/PPHomePremiumSearchCell.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 34 | Pure Pets/MainApp/ModrenAppVC/HomeCells/PPHomeUltraPremuimProviderCategoryPillCell.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 35 | Pure Pets/MainApp/ModrenAppVC/Search/SearchUI/PPFloatingSearchAccessoryView.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 36 | Pure Pets/MainApp/ModrenAppVC/PetCare/PPPetCareMedicineCell.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 37 | Pure Pets/MainApp/ModrenAppVC/SmartSuggest/PPBrowseHistoryManager.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 38 | Pure Pets/MainApp/ModrenAppVC/Helpers/PPHomeLayoutManager.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 39 | Pure Pets/MainApp/ModrenAppVC/Helpers/PPHomeItem.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 40 | Pure Pets/MainApp/GEMENI/GeminiChatViewController.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 41 | Pure Pets/MainApp/UserFiles/SignIn Files/XLFormPhoneCodeCell.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 42 | Pure Pets/MainApp/UserFiles/Adressess/PPDefaultLocationView.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 43 | Pure Pets/MainApp/Helpers/SegmentedControlHelper.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 44 | Pure Pets/MainApp/Helpers/DonePopupView.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 45 | Pure Pets/MainApp/Helpers/FloatingQuantityButton.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 46 | Pure Pets/DesignFiles/PP/MatchedTransitions/MatchedHostingController.swift | source | Pure Pets | High | Compiled but no static references to its declarations |
| 47 | Pure Pets/DesignFiles/PP/MatchedTransitions/MatchedGeometryModifier.swift | source | Pure Pets | High | Compiled but no static references to its declarations |
| 48 | Pure Pets/DesignFiles/PP/PPFormEngine/PPFormEngineUsageExample.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 49 | Pure Pets/DesignFiles/PP/PPComponent/PPProductCard.m | source | Pure Pets | High | Compiled but no static references to its declarations |
| 50 | Pure Pets/DesignFiles/PP/PPComponent/PPSectionHeader.m | source | Pure Pets | High | Compiled but no static references to its declarations |

... and 43 more items.

## 5. Probable Unused Candidates

| # | Path | Type | Target | Confidence | Reason |
|---|------|------|--------|------------|--------|
| 1 | Pure Pets/DesignFiles/PP/PPBackground/PPBackgroundView.m | source | N/A | Medium | In project but not in Compile Sources phase |

## 6. Manual Review Required

| # | Path | Type | Target | Confidence | Reason |
|---|------|------|--------|------------|--------|
| 1 | README.md | resource | Pure Pets | Medium | Resource in Copy Bundle Resources |
| 2 | Pure Pets/Resources/Profile.lottie | resource | Pure Pets | Medium | Resource in Copy Bundle Resources |
| 3 | Pure Pets/Resources/SearchingLottile.lottie | resource | Pure Pets | Medium | Resource in Copy Bundle Resources |
| 4 | Pure Pets/Resources/NoResult.json | resource | Pure Pets | Medium | Resource in Copy Bundle Resources |
| 5 | Pure Pets/Resources/NovaTyping.json | resource | Pure Pets | Medium | Resource in Copy Bundle Resources |
| 6 | Pure Pets/Resources/map_dark_style.json | resource | Pure Pets | Medium | Resource in Copy Bundle Resources |
| 7 | Pure Pets/Resources/cities.json | resource | Pure Pets | Medium | Resource in Copy Bundle Resources |
| 8 | Pure Pets/Resources/payment_checkout.json | resource | Pure Pets | Medium | Resource in Copy Bundle Resources |
| 9 | Pure Pets/Bridges/UnifiedBlurHash/Resources/sunflower.jpg | resource | Pure Pets | Low | Image in Resources - check [UIImage imageNamed:] |
| 10 | Pure Pets/MainApp/Search Controllers/AppSearchHelper.m | source | Pure Pets | Low | No static refs, but contains dynamic patterns |
| 11 | Pure Pets/MainApp/PetsServices/MyServicesViewController.m | source | Pure Pets | Low | No static refs, but contains dynamic patterns |
| 12 | Pure Pets/MainApp/VeterinarianFiles/VetViewerViewController.m | source | Pure Pets | Low | No static refs, but contains dynamic patterns |
| 13 | Pure Pets/DesignFiles/PP/PPFormEngine/README.md | resource | Pure Pets | Medium | Resource in Copy Bundle Resources |
| 14 | Pure Pets/DesignFiles/PP/Vet Location/PPVetLocator.m | source | Pure Pets | Low | No static refs, but contains dynamic patterns |
| 15 | Pure Pets/DesignFiles/PP/PPImagePicker+Viewer/QBImagePicker.storyboard | resource | Pure Pets | Medium | Resource in Copy Bundle Resources |
| 16 | Pure Pets/DesignFiles/PP/PPNAV/BBCheckoutSummaryView.m | source | Pure Pets | Low | No static refs, but contains dynamic patterns |
| 17 | Pure Pets/DesignFiles/UIFieldsAndPicker/ButtonsContainerView.m | source | Pure Pets | Low | No static refs, but contains dynamic patterns |
| 18 | Pure Pets/DesignFiles/UIFieldsAndPicker/AAMultiSelectController/Assets/AAicon_check@2x.png | resource | Pure Pets | Low | Image in Resources - check [UIImage imageNamed:] |
| 19 | Pure Pets/DesignFiles/UIFieldsAndPicker/AAMultiSelectController/Assets/AAicon_check@3x.png | resource | Pure Pets | Low | Image in Resources - check [UIImage imageNamed:] |
| 20 | Pure Pets/DesignFiles/UIFieldsAndPicker/FCAlertView/FCAlertView/Assets/alert-round.png | resource | Pure Pets | Low | Image in Resources - check [UIImage imageNamed:] |
| 21 | Pure Pets/DesignFiles/UIFieldsAndPicker/FCAlertView/FCAlertView/Assets/deletealert.png | resource | Pure Pets | Low | Image in Resources - check [UIImage imageNamed:] |
| 22 | Pure Pets/DesignFiles/UIFieldsAndPicker/FCAlertView/FCAlertView/Assets/heart.png | resource | Pure Pets | Low | Image in Resources - check [UIImage imageNamed:] |
| 23 | Pure Pets/DesignFiles/UIFieldsAndPicker/FCAlertView/FCAlertView/Assets/close-round.png | resource | Pure Pets | Low | Image in Resources - check [UIImage imageNamed:] |
| 24 | Pure Pets/DesignFiles/UIFieldsAndPicker/FCAlertView/FCAlertView/Assets/checkmark-round.png | resource | Pure Pets | Low | Image in Resources - check [UIImage imageNamed:] |
| 25 | Pure Pets/DesignFiles/UIFieldsAndPicker/FCAlertView/FCAlertView/Assets/star.png | resource | Pure Pets | Low | Image in Resources - check [UIImage imageNamed:] |
| 26 | Pure Pets/DesignFiles/UIFieldsAndPicker/FORScrollViewEmptyAssistant/Assets/blank_button@2x.png | resource | Pure Pets | Low | Image in Resources - check [UIImage imageNamed:] |
| 27 | Pure Pets/DesignFiles/UIFieldsAndPicker/FORScrollViewEmptyAssistant/Assets/blank_button@3x.png | resource | Pure Pets | Low | Image in Resources - check [UIImage imageNamed:] |
| 28 | Pure Pets/DesignFiles/UIFieldsAndPicker/CCActivityHUD/tick.png | resource | Pure Pets | Low | Image in Resources - check [UIImage imageNamed:] |
| 29 | Pure Pets/DesignFiles/UIFieldsAndPicker/CCActivityHUD/cross.png | resource | Pure Pets | Low | Image in Resources - check [UIImage imageNamed:] |
| 30 | Pure Pets/DesignFiles/UIFieldsAndPicker/QuickSecurityCode/README.md | resource | Pure Pets | Medium | Resource in Copy Bundle Resources |
| 31 | Pure Pets/DesignFiles/UIFieldsAndPicker/AKPickerView/AKPickerView.m | source | Pure Pets | Low | No static refs, but contains dynamic patterns |
| 32 | Pure Pets/DesignFiles/PhotosAnControllers/ZXQRScanViewController.xib | resource | Pure Pets | Medium | XIB in Copy Bundle Resources |
| 33 | Pure Pets/DesignFiles/PhotosAnControllers/Introduction/WelcomeView.m | source | Pure Pets | Low | No static refs, but contains dynamic patterns |
| 34 | Pure Pets/DesignFiles/Helpers/PPCollection.m | source | Pure Pets | Low | No static refs, but contains dynamic patterns |
| 35 | Pure Pets/DesignFiles/Helpers/DZNEmptyDataSet/placeholder_vesper.png | resource | Pure Pets | Low | Image in Resources - check [UIImage imageNamed:] |
| 36 | Pure Pets/DesignFiles/Helpers/DZNEmptyDataSet/button_background_icloud_normal@2x.png | resource | Pure Pets | Low | Image in Resources - check [UIImage imageNamed:] |
| 37 | Pure Pets/DesignFiles/Helpers/DZNEmptyDataSet/button_background_icloud_highlight.png | resource | Pure Pets | Low | Image in Resources - check [UIImage imageNamed:] |
| 38 | Pure Pets/DesignFiles/Helpers/DZNEmptyDataSet/button_background_icloud_normal.png | resource | Pure Pets | Low | Image in Resources - check [UIImage imageNamed:] |
| 39 | Pure Pets/DesignFiles/Helpers/DZNEmptyDataSet/button_background_icloud_highlight@2x.png | resource | Pure Pets | Low | Image in Resources - check [UIImage imageNamed:] |
| 40 | Pure Pets/DesignFiles/Helpers/DZNEmptyDataSet/placeholder_vesper@2x.png | resource | Pure Pets | Low | Image in Resources - check [UIImage imageNamed:] |
| 41 | Pure Pets/MianData_Files/BuyerCell.xib | resource | Pure Pets | Medium | XIB in Copy Bundle Resources |
| 42 | Pure Pets/MianData_Files/ArchCell.xib | resource | Pure Pets | Medium | XIB in Copy Bundle Resources |
| 43 | Pure Pets/MianData_Files/CardsCell.xib | resource | Pure Pets | Medium | XIB in Copy Bundle Resources |
| 44 | Pure Pets/BirdsCards/SalesVCViewController.m | source | Pure Pets | Low | No static refs, but contains dynamic patterns |
| 45 | Pure Pets/BirdsCards/Cells/JPCell.xib | resource | Pure Pets | Medium | XIB in Copy Bundle Resources |
| 46 | Pure Pets/BirdsCards/Cells/ABMenuTableViewCell/ABCellMailStyleMenuView.xib | resource | Pure Pets | Medium | XIB in Copy Bundle Resources |
| 47 | MyFrames/PurePetsLayoutKit/README.md | resource | Pure Pets | Medium | Resource in Copy Bundle Resources |

## 7. Unused Image and Asset Candidates

No unreferenced asset sets identified.

## 8. Source-File Candidates

- **Pure Pets/Bridges/UnifiedBlurHash/UnifiedImage.swift** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/Bridges/UnifiedBlurHash/UnifiedImage+Encode.swift** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/Bridges/UnifiedBlurHash/UnifiedImage+Scale.swift** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/Bridges/UnifiedBlurHash/UnifiedImage+Decode.swift** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/Bridges/UnifiedBlurHash/SwiftUI.Image+BlurHash.swift** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/PAYMENTS/PPPaymentsFiles/PPPaymentBasicsSettingsViewController.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/Accessories/AccessFiles/AccessoryCollectionViewCell.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/NewChats/helpers/PPMediaPreviewController.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/NewChats/helpers/SubHelpers/PPVoicePreviewBubbleView.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/NewChats/helpers/SubHelpers/WAVE/PPRecordingWaveformView.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/PetsServices/AddPetServiceOfferViewController.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/Banners/PPBannerCell.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/PetsAdsFiles/CreateAdCoordinator.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/PetsAdsFiles/PetsAdvertiseImagesAndCells/PPUniversalCellFlags.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/PetsAdsFiles/AdsBrowser/PPCenteredSelectorCell.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/PetsAdsFiles/New Ad/PPAdSubmitCoordinator.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/VeterinarianFiles/AddVetViewController.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/VeterinarianFiles/VetCollectionViewCell.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/AdoptPet/PetAdoptCollectionViewCell.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/AdoptPet/TitleSubtitleCell.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/ModrenAppVC/PPHomeViewController.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/ModrenAppVC/HomeCells/PPHomeActionCell.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/ModrenAppVC/HomeCells/PPModernHomeActionCell.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/ModrenAppVC/HomeCells/PPAdsNearByCarouselCell.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/ModrenAppVC/HomeCells/PPHomeMarketplaceHeroCell.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/ModrenAppVC/HomeCells/PPHomeHeroCell.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/ModrenAppVC/HomeCells/PetAdoptView.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/ModrenAppVC/HomeCells/PPHomeBannerContainerCell.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/ModrenAppVC/HomeCells/PPHomePremiumCareCell.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/ModrenAppVC/HomeCells/PPCategoryCardCell.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/ModrenAppVC/HomeCells/PPHomeUltraPremuimPetCareCell.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/ModrenAppVC/HomeCells/PPHomeServicesCell.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/ModrenAppVC/HomeCells/PPHomePremiumSearchCell.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/ModrenAppVC/HomeCells/PPHomeUltraPremuimProviderCategoryPillCell.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/ModrenAppVC/Search/SearchUI/PPFloatingSearchAccessoryView.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/ModrenAppVC/PetCare/PPPetCareMedicineCell.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/ModrenAppVC/SmartSuggest/PPBrowseHistoryManager.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/ModrenAppVC/Helpers/PPHomeLayoutManager.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/ModrenAppVC/Helpers/PPHomeItem.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/GEMENI/GeminiChatViewController.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/UserFiles/SignIn Files/XLFormPhoneCodeCell.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/UserFiles/Adressess/PPDefaultLocationView.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/Helpers/SegmentedControlHelper.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/Helpers/DonePopupView.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/MainApp/Helpers/FloatingQuantityButton.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/DesignFiles/PP/MatchedTransitions/MatchedHostingController.swift** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/DesignFiles/PP/MatchedTransitions/MatchedGeometryModifier.swift** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/DesignFiles/PP/PPFormEngine/PPFormEngineUsageExample.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/DesignFiles/PP/PPComponent/PPProductCard.m** (Refs: 0, High) — Compiled but no static references to its declarations
- **Pure Pets/DesignFiles/PP/PPComponent/PPSectionHeader.m** (Refs: 0, High) — Compiled but no static references to its declarations

... and 53 more
## 9. Storyboard and XIB Candidates

- Pure Pets/DesignFiles/PP/PPImagePicker+Viewer/QBImagePicker.storyboard (Medium) — Resource in Copy Bundle Resources
- Pure Pets/DesignFiles/PhotosAnControllers/ZXQRScanViewController.xib (Medium) — XIB in Copy Bundle Resources
- Pure Pets/MianData_Files/BuyerCell.xib (Medium) — XIB in Copy Bundle Resources
- Pure Pets/MianData_Files/ArchCell.xib (Medium) — XIB in Copy Bundle Resources
- Pure Pets/MianData_Files/CardsCell.xib (Medium) — XIB in Copy Bundle Resources
- Pure Pets/BirdsCards/Cells/JPCell.xib (Medium) — XIB in Copy Bundle Resources
- Pure Pets/BirdsCards/Cells/ABMenuTableViewCell/ABCellMailStyleMenuView.xib (Medium) — XIB in Copy Bundle Resources
## 10. Bundled Resource Candidates

- README.md (Medium) — Resource in Copy Bundle Resources
- Pure Pets/Resources/Profile.lottie (Medium) — Resource in Copy Bundle Resources
- Pure Pets/Resources/SearchingLottile.lottie (Medium) — Resource in Copy Bundle Resources
- Pure Pets/Resources/NoResult.json (Medium) — Resource in Copy Bundle Resources
- Pure Pets/Resources/NovaTyping.json (Medium) — Resource in Copy Bundle Resources
- Pure Pets/Resources/map_dark_style.json (Medium) — Resource in Copy Bundle Resources
- Pure Pets/Resources/cities.json (Medium) — Resource in Copy Bundle Resources
- Pure Pets/Resources/payment_checkout.json (Medium) — Resource in Copy Bundle Resources
- Pure Pets/Bridges/UnifiedBlurHash/Resources/sunflower.jpg (Low) — Image in Resources - check [UIImage imageNamed:]
- Pure Pets/DesignFiles/PP/PPFormEngine/README.md (Medium) — Resource in Copy Bundle Resources
- Pure Pets/DesignFiles/UIFieldsAndPicker/AAMultiSelectController/Assets/AAicon_check@2x.png (Low) — Image in Resources - check [UIImage imageNamed:]
- Pure Pets/DesignFiles/UIFieldsAndPicker/AAMultiSelectController/Assets/AAicon_check@3x.png (Low) — Image in Resources - check [UIImage imageNamed:]
- Pure Pets/DesignFiles/UIFieldsAndPicker/FCAlertView/FCAlertView/Assets/alert-round.png (Low) — Image in Resources - check [UIImage imageNamed:]
- Pure Pets/DesignFiles/UIFieldsAndPicker/FCAlertView/FCAlertView/Assets/deletealert.png (Low) — Image in Resources - check [UIImage imageNamed:]
- Pure Pets/DesignFiles/UIFieldsAndPicker/FCAlertView/FCAlertView/Assets/heart.png (Low) — Image in Resources - check [UIImage imageNamed:]
- Pure Pets/DesignFiles/UIFieldsAndPicker/FCAlertView/FCAlertView/Assets/close-round.png (Low) — Image in Resources - check [UIImage imageNamed:]
- Pure Pets/DesignFiles/UIFieldsAndPicker/FCAlertView/FCAlertView/Assets/checkmark-round.png (Low) — Image in Resources - check [UIImage imageNamed:]
- Pure Pets/DesignFiles/UIFieldsAndPicker/FCAlertView/FCAlertView/Assets/star.png (Low) — Image in Resources - check [UIImage imageNamed:]
- Pure Pets/DesignFiles/UIFieldsAndPicker/FORScrollViewEmptyAssistant/Assets/blank_button@2x.png (Low) — Image in Resources - check [UIImage imageNamed:]
- Pure Pets/DesignFiles/UIFieldsAndPicker/FORScrollViewEmptyAssistant/Assets/blank_button@3x.png (Low) — Image in Resources - check [UIImage imageNamed:]
- Pure Pets/DesignFiles/UIFieldsAndPicker/CCActivityHUD/tick.png (Low) — Image in Resources - check [UIImage imageNamed:]
- Pure Pets/DesignFiles/UIFieldsAndPicker/CCActivityHUD/cross.png (Low) — Image in Resources - check [UIImage imageNamed:]
- Pure Pets/DesignFiles/UIFieldsAndPicker/QuickSecurityCode/README.md (Medium) — Resource in Copy Bundle Resources
- Pure Pets/DesignFiles/Helpers/DZNEmptyDataSet/placeholder_vesper.png (Low) — Image in Resources - check [UIImage imageNamed:]
- Pure Pets/DesignFiles/Helpers/DZNEmptyDataSet/button_background_icloud_normal@2x.png (Low) — Image in Resources - check [UIImage imageNamed:]
- Pure Pets/DesignFiles/Helpers/DZNEmptyDataSet/button_background_icloud_highlight.png (Low) — Image in Resources - check [UIImage imageNamed:]
- Pure Pets/DesignFiles/Helpers/DZNEmptyDataSet/button_background_icloud_normal.png (Low) — Image in Resources - check [UIImage imageNamed:]
- Pure Pets/DesignFiles/Helpers/DZNEmptyDataSet/button_background_icloud_highlight@2x.png (Low) — Image in Resources - check [UIImage imageNamed:]
- Pure Pets/DesignFiles/Helpers/DZNEmptyDataSet/placeholder_vesper@2x.png (Low) — Image in Resources - check [UIImage imageNamed:]
- MyFrames/PurePetsLayoutKit/README.md (Medium) — Resource in Copy Bundle Resources
## 11. Localization Findings

Localization files found: 11. All protected.

## 12. Broken Xcode References

None detected. (This requires cross-checking every PBXFileReference against the filesystem — addressed in CSV/JSON.)

## 13. Files on Disk but Outside Xcode Project

- Pure Pets/ar.lproj/Localizable.strings (214695 bytes)
- Pure Pets/en.lproj/Localizable.strings (171621 bytes)
- Pure Pets/Resources/NovaLoader.json (5684 bytes)
- Pure Pets/Resources/thinking.json (30842 bytes)
- Pure Pets/Bridges/PPUniversalCellViewModelAdapter.swift (1117 bytes)
- Pure Pets/MainApp/PAYMENTS/ORDER_CHECKOUT_AUDIT_README.md (11825 bytes)
- Pure Pets/MainApp/PAYMENTS/CartAndOrdersFiles/PPOrderStatusAppearance.h (16086 bytes)
- Pure Pets/MainApp/PAYMENTS/Manager/Cart/PPCartCalculator.h (1821 bytes)
- Pure Pets/MainApp/PAYMENTS/Manager/Cart/PPCartCalculator.m (3893 bytes)
- Pure Pets/MainApp/Accessories/AccessFiles/PPMarketplaceHeroCardStyle.h (11146 bytes)
- Pure Pets/MainApp/Accessories/AccessFiles/PPPremiumImageSelectorRail.h (2316 bytes)
- Pure Pets/MainApp/ModrenAppVC/PPProviderSubscriptionManagementVC.m (6521 bytes)
- Pure Pets/MainApp/ModrenAppVC/PPProviderSubscriptionManagementVC.h (250 bytes)
- Pure Pets/MainApp/GEMENI/PPNovaOutputPresentationChecklist.md (1515 bytes)
- Pure Pets/MainApp/GEMENI/PPNovaMessageBubbleCell.m (92691 bytes)
- Pure Pets/MainApp/GEMENI/PPNovaFloatingInputBarView.h (1410 bytes)
- Pure Pets/MainApp/GEMENI/PPNovaMessageBubbleCell.h (911 bytes)
- Pure Pets/MainApp/GEMENI/PPNovaFloatingInputBarView.m (37934 bytes)
- Pure Pets/MainApp/UserFiles/SignIn Files/PPAuthScaffoldView.m (11322 bytes)
- Pure Pets/MainApp/UserFiles/SignIn Files/PPAuthStepIndicatorView.h (486 bytes)
- Pure Pets/MainApp/UserFiles/SignIn Files/PPAuthScaffoldView.h (842 bytes)
- Pure Pets/MainApp/UserFiles/SignIn Files/PPAuthStepIndicatorView.m (23020 bytes)
- Pure Pets/MainApp/Helpers/PPLog.h (382 bytes)
- Pure Pets/DesignFiles/PP/PPSelectOptionViewController/PPSelectAddressVC.h (1593 bytes)
- Pure Pets/DesignFiles/PP/PPSelectOptionViewController/PPSelectOptionViewController.h (3509 bytes)
- Pure Pets/DesignFiles/PP/PPSelectOptionViewController/PPOptionCell.h (1529 bytes)
- Pure Pets/DesignFiles/PP/PPStyles/HXCompatibilityCategories.h (1416 bytes)
- Pure Pets/DesignFiles/PP/PPStyles/HXCompatibilityCategories.m (4298 bytes)
- Pure Pets/DesignFiles/UIFieldsAndPicker/KafkaRefresh/Resource/Image.bundle/arrow48.png (560 bytes)
- Pure Pets/DesignFiles/UIFieldsAndPicker/PYSearch/PYSearch.bundle/clearImage@2x.png (534 bytes)

... and 142 more
## 14. Duplicate Files and Resources

- **5fef2af156f8** (1515 bytes)
  - Pure Pets/MainApp/PetsAdsFiles/PetsAdvertiseImagesAndCells/PPPinterestLayout.h
  - MyFrames/PurePetsLayoutKit/Compatibility/PPPinterestLayout.h
- **98262c1e1055** (1606 bytes)
  - Pure Pets/DesignFiles/UIFieldsAndPicker/UISearchBar+FMAdd.m
  - Pure Pets/DesignFiles/Helpers/UISearchBar+FMAdd.m
- **a4aa07107908** (429 bytes)
  - Pure Pets/DesignFiles/UIFieldsAndPicker/UISearchBar+FMAdd.h
  - Pure Pets/DesignFiles/Helpers/UISearchBar+FMAdd.h
- **7f4ddd3e0b2c** (3820 bytes)
  - Pure Pets/DesignFiles/UIFieldsAndPicker/CCActivityHUD/tick.png
  - Pure Pets/DesignFiles/UIFieldsAndPicker/CCActivityHUD/cross.png
## 15. Protected Resources

- Pure Pets/AppManager.h
- Pure Pets/AppDelegate.h
- Pure Pets/SceneDelegate.m
- Pure Pets/GoogleService-Info.plist
- Pure Pets/GM.h
- Pure Pets/Pure Pets.entitlements
- Pure Pets/PrivacyInfo.xcprivacy
- Pure Pets/EnumValues.h
- Pure Pets/AppDelegate.m
- Pure Pets/Pure Pets-Bridging-Header.h
- Pure Pets/PrefixHeader.pch
- Pure Pets/Info.plist
- Pure Pets/SceneDelegate.h
- Pure Pets/Resources/Beiruti-Medium.ttf
- Pure Pets/Resources/Beiruti-Regular.ttf
- Pure Pets/Resources/Beiruti-Bold.ttf
- Pure Pets/Resources/Beiruti-Black.ttf
- Pure Pets/MainApp/Search Controllers/SearchManager.h
- Pure Pets/MainApp/Search Controllers/SearchResultItem.h
- Pure Pets/MainApp/Search Controllers/SearchResultCell.h
- Pure Pets/MainApp/Search Controllers/AppSearchHelper.h
- Pure Pets/MainApp/Search Controllers/AppSearchResultsVC.h
- Pure Pets/MainApp/PAYMENTS/Models/Orders/PPOrder.h
- Pure Pets/MainApp/PAYMENTS/Models/Orders/PPFulfillmentOrder.h
- Pure Pets/MainApp/PAYMENTS/CartAndOrdersFiles/PPOrderProgressTimelineRowView.h
- Pure Pets/MainApp/PAYMENTS/CartAndOrdersFiles/PPOrderSupportRequestDetailsViewController.h
- Pure Pets/MainApp/PAYMENTS/CartAndOrdersFiles/PurchasedItemsViewController.h
- Pure Pets/MainApp/PAYMENTS/CartAndOrdersFiles/PPOrderTimelineViewController.h
- Pure Pets/MainApp/PAYMENTS/CartAndOrdersFiles/PPOrderStatusStepperView.h
- Pure Pets/MainApp/PAYMENTS/CartAndOrdersFiles/OrderHistoryViewController.h
- Pure Pets/MainApp/PAYMENTS/CartAndOrdersFiles/OrderSupportFunc.h
- Pure Pets/MainApp/PAYMENTS/CartAndOrdersFiles/OrderCell.h
- Pure Pets/MainApp/PAYMENTS/CartAndOrdersFiles/OrderModel.h
- Pure Pets/MainApp/PAYMENTS/CartAndOrdersFiles/OrderItemCell.h
- Pure Pets/MainApp/PAYMENTS/CartAndOrdersFiles/PPOrderSupportRequestListViewController.h
- Pure Pets/MainApp/PAYMENTS/CartAndOrdersFiles/OrderDetailsViewController.h
- Pure Pets/MainApp/PAYMENTS/CartAndOrdersFiles/PPOrderProgressTimelineView.h
- Pure Pets/MainApp/PAYMENTS/CartAndOrdersFiles/PPCartTableCell.h
- Pure Pets/MainApp/PAYMENTS/CartAndOrdersFiles/CartItem.h
- Pure Pets/MainApp/PAYMENTS/CartAndOrdersFiles/PPOrderSupportComposerViewController.h

... and 692 more

## 16. Repository Hygiene

- tmp_order_prev.m (High) — Filename suggests backup/temp file
- tmp_order.m (High) — Filename suggests backup/temp file
- Pure Pets/MainApp/PAYMENTS/PPPaymentsFiles/PPPaymentFormViewController.m.xlform-backup (High) — Filename suggests backup/temp file
- Pure Pets/MainApp/NewChats/helpers/PPChatHeaderView.m.bak.20260411194808 (High) — Filename suggests backup/temp file
- Pure Pets/MainApp/NewChats/ChCells/ChCell.m.bak.20260411194808 (High) — Filename suggests backup/temp file
- Pure Pets/MainApp/Banners/PPBannerCollectionCell.m.bak.20260412-013337 (High) — Filename suggests backup/temp file
- Pure Pets/MainApp/ModrenAppVC/PPHomeViewController.m.bak.20260412-013337 (High) — Filename suggests backup/temp file
- Pure Pets/MainApp/ModrenAppVC/PPHomeViewController.m.bak.badgeimg-20260411233700 (High) — Filename suggests backup/temp file
- Pure Pets/MainApp/ModrenAppVC/HomeCells/Stories/PPStoryCollectionViewCell.m.bak.20260411194808 (High) — Filename suggests backup/temp file
- Pure Pets/DesignFiles/PP/PPNAV/UIViewController+PPNavBar.m.bak.20260412-013337 (High) — Filename suggests backup/temp file
- Pure Pets/DesignFiles/Helpers/UserContactView.m.bak.20260411194808 (High) — Filename suggests backup/temp file
- Pure Pets/MianData_Files/SplashViewController.m.bak.20260412-013337 (High) — Filename suggests backup/temp file
- Pure Pets/DataClasses/BasicDataClassess/MainKindsModel.m.bak.20260412-013337 (High) — Filename suggests backup/temp file
- MyFrames/PurePetsLayoutKit/Integration/PPUniversalCellViewModelAdapter.swift.template (High) — Filename suggests backup/temp file
- AuditReports/UnusedResourcesAudit/audit_unused_resources.py (Medium) — Script file in repository
## 17. Limitations

1. **ObjC Dynamic Runtime:** Classes referenced by string (`NSClassFromString`)
   cannot be fully traced statically.
2. **String-Interpolated Assets:** Assets loaded via format strings appear unused.
3. **CocoaPods/SPM:** Third-party dependencies are excluded from analysis.
4. **Feature Flags:** A/B-tested or server-gated code paths may appear unused.
5. **XIB Connections:** Custom classes in XIB files connected at runtime are not traced.
6. **Asset Catalog Variants:** Dark mode, device-specific, and RTL variants of used
   assets are protected by the parent asset set.
## 18. Recommended Cleanup Order

1. Repository Hygiene files (safest)
2. Confirmed Project Issues (broken references)
3. High-Confidence Unused Candidates
4. Probable Unused Candidates
5. Manual Review Required (investigate each)
6. Duplicate files (consolidate after verification)
