# GEMINI.md — Pure Pets Project Brain Satellite: Consumer iOS

This repository is the Consumer iOS reference implementation for Pure Pets (`pure-pets-49199`).

## Brain Boot Contract
1. For cross-repository context, locate sibling `PurePetsProjects` and read `AGENTS.md` and `docs/agent/INDEX.md`.
2. `pure-pets-infra` is authoritative for backend schema, rules, Cloud Functions, and lifecycle.
3. Pure Pets iOS is the default consumer UX/parity reference for all other clients.
4. Machine pointer: `project-brain.json`.

## Local Architecture Invariants
- Code-only UIKit (no Storyboards/XIBs except splash).
- Objective-C primary with Swift bridges (`Pure Pets-Bridging-Header.h`, `@objc`).
- Design tokens in `PPDesignTokens.h`.
- RTL leading/trailing layout, `kLang(@"key")` localization.
- `AppManager` (`AppMgr`) global singleton, `GM` stateless utility.
- Connected physical device only build policy (iPhone 13 Pro Max). Never simulator.
