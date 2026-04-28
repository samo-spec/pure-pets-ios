# Pure Pets IOS — Premium Mobile Experience

## Project Context
`Pure Pets IOS` is the cornerstone mobile application of the Pure Pets ecosystem. It is designed to deliver a god-level, premium minimalist user experience for iOS users, powered by a robust Firebase backend managed by `Pure Pets Infra`. It serves as the primary consumer of platform services, pioneering the design language and feature sets for the entire ecosystem.

## Role & Mission
The iOS application provides a seamless, high-performance interface for:
-   **User Onboarding & Identity**: Secure authentication via Firebase Auth.
-   **Pet Ecosystem Access**: Real-time browsing of pets, accessories, and services.
-   **Direct Interaction**: Real-time messaging between users and service providers.
-   **Secure Commerce**: Integrated payment workflows and order management.
-   **Asset-Rich Experience**: High-fidelity media handling with custom transitions.

## App Documentation

### 1. Architecture & Design
The project follows a hybrid architecture, meticulously blending Objective-C and Swift:
-   **`MainApp/`**: Core logic, navigation flows, and primary view controllers.
-   **`FireData/`**: A specialized data layer for Firestore/Realtime Database listeners and model parsing.
-   **`DataClasses/`**: Defines the platform's data models, ensuring consistency with the backend.
-   **`DesignFiles/`**: Centralized UI component library and theme definitions.
-   **`Bridges/`**: Crucial interoperability layers between Objective-C and Swift modules.

### 2. Technology Stack
-   **Languages**: Objective-C (Core/Legacy) and Swift (Modern Features).
-   **Dependency Management**: CocoaPods (`Podfile`).
-   **UI Framework**: UIKit with code-only construction for precise layout control.
-   **Media**: `lame.framework` for audio and `HXPhotoPicker` for advanced media selection.

### 3. Key Components
-   **`AppManager` / `GM`**: Global orchestrators handling application state, session persistence, and shared services.
-   **`BirdsCards`**: Specialized module for bird-specific platform features.
-   **`Resources/`**: Contains brand fonts (Beiruti), localization strings (`ar.lproj`, `en.lproj`), and asset catalogs.

## Full Project Tree
```text
.
├── Pure Pets/                   # Main Source Hub
│   ├── MainApp/                 # Feature-specific Controllers
│   ├── FireData/                # Firebase Sync & Persistence
│   ├── DataClasses/             # Model & Schema Definitions
│   ├── DesignFiles/             # UI Components & Themes
│   ├── Bridges/                 # Obj-C / Swift Interop
│   ├── Resources/               # Fonts, JSON Data, Locales
│   ├── Assets.xcassets          # Global Image Assets
│   ├── ColorsAssets.xcassets    # Semantic Color Definitions
│   ├── AppDelegate.m            # Lifecycle Management
│   ├── SceneDelegate.m          # Window & Scene Logic
│   └── Info.plist               # App Configuration
├── Pure Pets.xcworkspace        # Master Workspace (Required)
├── Pure Pets.xcodeproj          # Project Configuration
├── Podfile                      # Dependency Manifest
├── MyFrames/                    # Custom Frameworks (QIB, Lame, HX)
├── xcode-studio-mcp/            # Specialized MCP Tooling for IOS
└── functions/                   # Scoped helper scripts
```

## Build & Maintenance
-   **Local Setup**:
    1.  Ensure latest Xcode is installed.
    2.  Run `pod install` in the root directory.
-   **Building**: Always open `Pure Pets.xcworkspace`. Use `Cmd+B` to build.
-   **Standards**: Maintain Premium Minimalist UI. All data writes must adhere to the audit requirements of `Pure Pets Infra`.

---

# For Agents
**Role**: Senior Staff iOS Engineer & UIKit Expert.
**Directives**:
1.  **Architecture**: Maintain the separation between `FireData` (persistence) and `MainApp` (UI). Respect the `AppManager` and `GM` for global state.
2.  **UI standard**: Follow the God-level Premium Minimalism standard. Prioritize UIKit code-only layouts over Storyboards/XIBs.
3.  **Hybrid Handling**: Ensure all Swift additions are properly bridged to Objective-C using `@objc` and `Pure Pets-Bridging-Header.h`.
4.  **Firebase Sync**: Adhere strictly to the backend structures in `Pure Pets Infra/`. Use listeners efficiently to avoid memory leaks.
5.  **Lifecycle**: Watch for retain cycles in blocks and delegates. Use `weakSelf` in Objective-C.
6.  **Dependency**: Any new library must be approved for both performance and size. Use CocoaPods for all management.
7.  **Workflow**: Use `xcode-studio-mcp` for deeper integration when debugging simulator or build issues.
