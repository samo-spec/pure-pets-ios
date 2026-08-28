# Pure Pets Project Brain Satellite — Consumer iOS

This repository is a core Pure Pets platform repository. These instructions make the Project Brain discoverable when Consumer iOS is opened independently.

## Brain Boot Contract

1. For cross-repository work, locate the sibling `PurePetsProjects` checkout when available and read `AGENTS.md`, `docs/agent/INDEX.md`, `docs/agent/governance/GOVERNANCE.md`, the affected feature-map entry, and the security map when applicable.
2. If the umbrella checkout is unavailable, use current iOS source plus this repository's approved architecture documentation as local truth; do not invent backend contracts.
3. Backend schema, rules, authorization and lifecycle conflicts are resolved by `pure-pets-infra`.
4. Do not recursively inspect every Pure Pets repository by default. Route through the affected domain and inspect only concrete dependencies.

Machine pointer: `project-brain.json`.

## Local Authority

Consumer iOS is the default consumer UX/behavior parity reference unless an explicit platform-specific decision differs. Current executable source outranks stale handoff/history documents for implementation truth.

## Architecture Invariants

- Primarily Objective-C UIKit with targeted Swift bridges; do not migrate to SwiftUI unless explicitly requested.
- Preserve `@objc`/bridging-header exposure for Swift called from Objective-C.
- `AppManager`/`AppMgr` owns global state/Firebase session responsibilities; `GM` remains the stateless utility layer.
- Keep Firebase/business logic out of reusable design-only layers.
- Use existing PP design tokens/primitives and localization mechanisms before inventing replacements.
- Preserve Arabic RTL and English LTR using logical leading/trailing layout behavior.
- QIB integration is physical-device constrained.

## Security & Approval

- Client visibility is not server authorization.
- Never bypass App Check, Authentication, ownership/scope, permission or callable boundaries.
- Never ingest secrets, `.env` content, signing material, API keys or auth tokens into memory.
- Historical/canonical memory never grants current production, deployment or destructive approval.

## Execution Boundary

The umbrella execution policy governs agent-run iOS verification when documentation contains conflicting `xcodebuild`/simulator examples. Do not infer permission to run a build merely because a README documents the command.

## Freshness

When the umbrella brain is available, compare this repository HEAD with the recorded iOS snapshot. If it differs, inspect the changed range relevant to the task and refresh only affected current-state/map entries.
