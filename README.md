<div align="center">
  <br/>
  <h1>Pure Pets iOS</h1>
  <p><strong>Premium Pet Ecosystem — iOS Client</strong></p>
  <br/>
  <p>
    <img src="https://img.shields.io/badge/platform-iOS%2015.0+-000?style=flat-square&logo=apple&logoColor=white"/>
    <img src="https://img.shields.io/badge/lang-Objective--C%20%7C%20Swift-000?style=flat-square&logo=swift"/>
    <img src="https://img.shields.io/badge/UI%20only-UIKit-000?style=flat-square"/>
    <img src="https://img.shields.io/badge/RTL-Arabic%20primary-000?style=flat-square"/>
    <img src="https://img.shields.io/badge/Firebase-FFCA28?style=flat-square&logo=firebase&logoColor=000"/>
    <img src="https://img.shields.io/badge/CocoaPods-FB3A3A?style=flat-square&logo=cocoapods&logoColor=white"/>
  </p>
  <br/>
</div>

---

## Overview

**Pure Pets iOS** is the flagship consumer mobile app of the Pure Pets ecosystem — a premium marketplace connecting pet owners with breeders, veterinarians, pet stores, and service providers across the Middle East. Built with iOS 15+ in mind, the app delivers a fast, RTL-first experience with code-only UIKit and Firebase at its core.

| | |
|---|---|
| **Minimum Deployment** | iOS 15.0 |
| **Primary Languages** | Arabic (RTL) · English (LTR) |
| **Codebase** | Objective-C (core) + Swift (new features) |
| **UI Framework** | UIKit — code-only, no Storyboards |
| **Backend** | Firebase (Firestore, Auth, Storage, Functions) |
| **Dependencies** | CocoaPods |

---

## Features

- **Onboarding & Auth** — Firebase Authentication with Google Sign-In
- **Pet Listings** — Browse, search, and filter pets, accessories, and services
- **Breeder Cards** — Bird-specific marketplace with cage management and archives
- **Real-time Chat** — Direct messaging between users and providers
- **Secure Checkout** — Cart, order management, and QIB payment integration
- **Veterinary Services** — Find and book vet appointments
- **Pet Adoption** — Rehoming and adoption listings
- **Visual Search** — Camera/photo library search by image
- **Bilingual RTL** — Full Arabic primary / English secondary support

---

## Architecture

```
Pure Pets.xcworkspace
└── Pure Pets/
    ├── MainApp/          Feature view controllers & coordinators
    ├── FireData/         Firestore/RTDB listeners & sync
    ├── DataClasses/      Model objects & managers
    ├── DesignFiles/      Reusable UI components & design tokens
    ├── Bridges/          Objective-C ↔ Swift interop layer
    └── Resources/        Fonts, localization, assets, JSON
```

### Layer Rules

| Layer | Responsibility | Forbidden |
|---|---|---|
| `MainApp/` | Navigation, view controllers, feature logic | Firebase calls outside coordinator |
| `FireData/` | Firestore listeners, snapshot parsing | UI code of any kind |
| `DataClasses/` | Models, managers, file upload, audit logging | UIKit imports |
| `DesignFiles/` | Reusable views, design tokens, styling | Business logic, Firebase |

### Key Components

- **`AppManager`** (`AppMgr`) — Global singleton owning Firestore reference, user session, image cache, and snack-bar presentation
- **`GM`** — Stateless utility class for fonts, colors, images, Firebase Storage, compression, haptics, formatting
- **`PPDesignTokens.h`** — Design system macros (spacing, corners, colors, typography, shadows)
- **`PPBottomBar`** — Custom tab bar controller for app navigation
- **`PPCheckoutCoordinator`** — Coordinator pattern for the full checkout flow

---

## Setup

### Prerequisites

- Xcode 15+
- CocoaPods (`gem install cocoapods`)
- An Apple Developer account (for device builds)

### Install

```bash
git clone <repo>
cd "Pure Pets IOS"
pod install
```

### Build

Always open the **workspace**, never the `.xcodeproj`:

```bash
open "Pure Pets.xcworkspace"
```

**Device build** (QIBPayment.framework is device-only):
```bash
xcodebuild -workspace "Pure Pets.xcworkspace" \
  -scheme "Pure Pets" -configuration Debug \
  -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build
```

**Simulator build** (QIB payment path will not link):
```bash
xcodebuild -workspace "Pure Pets.xcworkspace" \
  -scheme "Pure Pets" -configuration Debug \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2" \
  CODE_SIGNING_ALLOWED=NO build
```

---

## Design System

All tokens are defined in `PPDesignTokens.h` and available globally via `PrefixHeader.pch`.

| Token | Value |
|---|---|
| `PPSpaceSM` | 8pt |
| `PPSpaceBase` | 16pt |
| `PPScreenMargin` | 20pt |
| `PPCornerCard` | 22pt |
| `PPCornerHero` | 32pt |
| `PPCornerPill` | 9999pt |
| `AppPrimaryClr` | Brand primary |
| `PPFontHeadline` | 17pt (+1pt internal boost) |

Always use these macros — no magic numbers.

---

## Localization

Arabic is the **primary** language (RTL), English is secondary (LTR).

- iOS strings: `ar.lproj/Localizable.strings` · `en.lproj/Localizable.strings`
- Access: `kLang(@"key_name")` — never hardcode user-facing strings
- Layout: Use leading/trailing Auto Layout anchors (never left/right)

---

## Firebase

| Service | Usage |
|---|---|
| **Firestore** | All data storage — accessed via `AppMgr.dF` |
| **Auth** | Email/password + Google Sign-In |
| **Storage** | Pet photos, user avatars, chat media |
| **Cloud Functions** | Payment processing, audit logging, permissions |
| **App Check** | Always enabled on all platforms |

---

## Project Context

Pure Pets iOS is the **reference implementation** for the entire Pure Pets ecosystem. Its UI/UX behavior and feature set define the standard that all other clients (Android, Web Console, Admin iOS) must match. The backend source of truth lives in `Pure Pets Infra/`.

---

## Contributing

- Follow the existing code style and layer separation
- All UI must be **code-only UIKit** — no new Storyboards
- Use `kLang(@"key")` for any new user-facing string (Arabic + English)
- Never hardcode design tokens — use `PPSpace*`, `PPCorner*`, `App*Clr` macros
- Add `@objc` and bridging header entries for Swift files callable from ObjC
- Every Firebase write must pass through the backend's permission + audit layer
- `QIBPayment.framework` is **device-only** — do not test the online payment path in the simulator

---

## License

Proprietary — Pure Pets. All rights reserved.

---

<div align="center">
  <small>Built with ❤️ for pets and their people</small>
</div>
