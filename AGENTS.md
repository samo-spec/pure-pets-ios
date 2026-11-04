# Pure Pets Project Brain Satellite — Consumer iOS

This repository is a core Pure Pets platform repository. These instructions make the Project Brain active when Consumer iOS is opened independently.

## Brain Boot Contract

1. For cross-repository work, locate the sibling `PurePetsProjects` checkout when available and read the umbrella bootloader, governance, affected feature-map entry and security map when applicable.
2. If unavailable, use current iOS source as local truth and do not invent backend or cross-platform contracts.
3. `pure-pets-infra` is authoritative for Firebase schema, security, Cloud Functions and backend lifecycle.
4. Pure Pets iOS is the default consumer UX/behavior parity reference for all other clients.
5. Do not recursively inspect every Pure Pets repository by default.

Machine pointer: `project-brain.json`.

## Local Authority

Consumer iOS owns the consumer experience: Objective-C/Swift UIKit architecture, layout, motion, design tokens, and local cache/presentation.

## Architecture Invariants

- **Code-only UIKit** — no Storyboards/XIBs except the legacy `Main.storyboard` splash entry point.
- Do NOT convert to SwiftUI unless explicitly requested.
- Objective-C primary with Swift bridges (`Pure Pets-Bridging-Header.h`, `@objc` required for Swift callable from ObjC).
- Always use `kLang(@"key")` for user-facing strings — never hardcode. Add entries to `ar.lproj/Localizable.strings` and `en.lproj/Localizable.strings`.
- Use leading/trailing Auto Layout anchors — never left/right (RTL safety).
- `AppManager` (`AppMgr` macro) is the global singleton — owns Firestore ref (`dF`), user session.
- `GM` is the stateless utility class — fonts, colors, image loading, shadows.
- Design tokens in `PPDesignTokens.h` — use macros (`PPSpaceBase`, `PPCornerCard`, `AppPrimaryClr`, etc.), never magic numbers.
- `QIBPayment.framework` is **device-only** — the simulator cannot link it.

## Security & Approval

- UI permission visibility is not server authorization.
- Never ingest `.env`, Firebase credentials, API keys, private keys, signing material or auth tokens into memory.
- Canonical/historical memory never grants current deployment, production or destructive approval.

## Execution Boundary

Builds are strictly allowed ONLY on the connected physical device (**iPhone 13 Pro Max**), strictly using default DerivedData path `/Users/mohammedahmed/Library/Developer/Xcode/`. Never use simulator SDK. Code review is sufficient for Obj-C / Swift verification.

## Freshness

When the umbrella brain is available, compare this repository HEAD with the recorded iOS snapshot and inspect only task-relevant changed ranges on mismatch.
