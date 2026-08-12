# SwiftyMax NextGen Category-Defining V4 Integration Requirements

**Phase:** Requirements only  
**Implementation status:** Not started  
**Integration target:** Pure Pets iOS workspace agent/tooling layer  
**Canonical package:** `/Users/mohammedahmed/plugins/swiftymax-nextgen-category-defining-v4`

## 1. Request and scope

Add the standalone `swiftymax-nextgen-category-defining-v4` package to the current workspace/project setup so its native Apple design, parity, brand, visual-review, studio, and proof capabilities can be invoked for future Pure Pets work. This phase records the integration contract only. It must not implement or alter application behavior, UI code, Xcode configuration, backend configuration, or package source.

The integration is a host/tooling concern. The V4 package is not an iOS framework, CocoaPod, Swift package, Firebase dependency, or runtime application asset.

## 2. Current gap

- The requested V4 package exists at the canonical external path, but no V4 registration is present in the current workspace.
- The workspace-local agent setup exposes V3-era SwiftyMax registrations under `.kiro/skills/` and `.agents/skills/`; no V4 skill registration was found.
- `.kiro/settings/lsp.json` configures language servers only. It is not a plugin registry and must not be used as one.
- No dedicated `requirements/` or `specs/` directory exists. Existing project governance is Markdown under `Docs/`, so this file is the requirements artifact for the integration.
- No evidence was found that V4 has been marketplace-registered, installed into a host cache, or discovered by a fresh task. Source presence alone is not installation or live-discovery proof.
- The V4 package contains a V3-named archive in its local `release/` directory. That artifact must not be treated as a V4 release or registered under the V4 identity.

## 3. Intended integration

The next implementation phase shall expose V4 through the host-supported plugin/skill registration path while retaining V3 as a separate, available package. The integration shall:

1. Treat `/Users/mohammedahmed/plugins/swiftymax-nextgen-category-defining-v4` as the canonical package source.
2. Consume the package identity from `.codex-plugin/plugin.json`, the MCP declaration from `.mcp.json`, the seven skills from `skills/`, and the built runtime from `dist/` generated from `src/`.
3. Register V4 under its exact distinct identity, `swiftymax-nextgen-category-defining-v4`, version `4.0.0`, without overwriting, renaming, removing, or silently falling back to `swiftymax-category-defining-v3`.
4. Use the host’s supported install/discovery mechanism rather than manually copying an installed cache or treating the Codex manifest as an iOS project configuration file.
5. If the current Kiro workspace requires a local adapter or mirror, use the accepted formats under `.kiro/skills/` and `.agents/skills/` only after verifying that adapter contract. Do not guess that a `.codex-plugin` manifest is automatically consumed by Kiro.
6. Keep all app/runtime behavior and existing Pure Pets source ownership unchanged. Future visual or native-target work must invoke the installed V4 capabilities against the actual target, not against package fixtures alone.

## 4. Required capabilities and identity

The registered package must expose these seven independently invocable skills:

- `swiftymax-nextgen-category-defining-v4` — orchestration and final handoff
- `swiftymax-nextgen-brand-steward-v4` — source-bound Pure Pets brand decisions
- `swiftymax-nextgen-creative-director-v4` — Product DNA, concepts, and art direction
- `swiftymax-nextgen-parity-v4` — behavior, ownership, and route parity
- `swiftymax-nextgen-proof-v4` — independent evidence and certification verdict
- `swiftymax-nextgen-studio-v4` — native implementation craft
- `swiftymax-nextgen-visual-lab-v4` — capability preflight and rendered review

The companion MCP server must remain named `swiftymax-nextgen-category-tools-v4`, start from the package root with `node ./dist/server.mjs`, and expose the package-declared fourteen read-only tools. The V4 default route is `redesign` when a visual request does not explicitly select another mode.

## 5. Affected paths and configuration

### Package-side inputs and generated outputs

- `/Users/mohammedahmed/plugins/swiftymax-nextgen-category-defining-v4/.codex-plugin/plugin.json` — package identity, skill root, MCP root, interface metadata, and default prompts.
- `/Users/mohammedahmed/plugins/swiftymax-nextgen-category-defining-v4/.mcp.json` — V4 MCP server name and command.
- `/Users/mohammedahmed/plugins/swiftymax-nextgen-category-defining-v4/skills/` — seven skill packages and role references.
- `/Users/mohammedahmed/plugins/swiftymax-nextgen-category-defining-v4/src/` — canonical executable source; edits, if ever required, belong here rather than in `dist/`.
- `/Users/mohammedahmed/plugins/swiftymax-nextgen-category-defining-v4/dist/` — derived build output; never edit manually.
- `/Users/mohammedahmed/plugins/swiftymax-nextgen-category-defining-v4/package.json` and `package-lock.json` — pinned toolchain and validation commands.
- `/Users/mohammedahmed/plugins/swiftymax-nextgen-category-defining-v4/MIGRATION.md`, `PROVENANCE.md`, and `release-allowlist.json` — lifecycle, provenance, and release-safety constraints.

### Workspace-side integration and documentation

- `.kiro/skills/` — current Kiro-local skill registration surface; currently V3-only.
- `.agents/skills/` — mirrored local agent skill surface; currently V3-only plus unrelated untracked `code-review/` content.
- `Docs/SwiftyMaxNextGenCategoryDefiningV4IntegrationRequirements.md` — this requirements artifact.

### Explicitly out of scope for this integration

Do not modify or add entries to any of the following for plugin registration:

- `Pure Pets/` source, including Swift, Objective-C, localization, assets, or design tokens.
- `Pure Pets.xcodeproj`, `Pure Pets.xcworkspace`, `Podfile`, `Podfile.lock`, `Info.plist`, entitlements, or build settings.
- Firebase collections, rules, Cloud Functions, Storage, permissions, analytics, or backend schemas.
- CocoaPods, Swift Package Manager, QIB payment configuration, or device/runtime frameworks.
- Existing V3 package source or installed cache.

## 6. Functional requirements

**FR-1 — Distinct registration.** The host must identify V4 as `swiftymax-nextgen-category-defining-v4` at version `4.0.0`, with the visible label `SwiftyMax NextGen Category-Defining V4`. V3 remains independently addressable.

**FR-2 — Canonical source and reproducibility.** Registration and validation must use the requested absolute package path. Any installed artifact must be derived through the supported package/host flow, not from a hand-edited `dist/`, copied cache, or stale release archive.

**FR-3 — Complete skill surface.** All seven V4 skill names must be available to the host. Missing, renamed, V3-fallback, or silently substituted skills fail the integration.

**FR-4 — MCP surface.** The host must be able to start `swiftymax-nextgen-category-tools-v4` using the package’s declared Node command and discover the declared fourteen read-only tools. No hidden browser, renderer, physical device, Figma, image service, or external design-service dependency may be introduced.

**FR-5 — Lifecycle separation.** Package validation, marketplace/host registration, installed cache state, and live discovery are separate checkpoints. Passing one must not be reported as proof of the others.

**FR-6 — Capability truthfulness.** The integration must expose only capabilities actually reachable from the current host. V4 must report visual or native proof as blocked/unverified when the required renderer, image inspection, physical device, trust configuration, or independent attestation is unavailable.

**FR-7 — Target boundary.** Package and fixture validation may prove package architecture only. Native Pure Pets acceptance requires current target-bound evidence; a simulator or browser preview cannot substitute for physical iOS runtime proof under the V4 contract.

**FR-8 — No application coupling.** The plugin must not become a runtime dependency of the Pure Pets app and must not change routes, state ownership, Firebase behavior, localization contracts, analytics, or build targets.

**FR-9 — Dirty-tree safety.** The implementation must preserve unrelated current work. At requirements capture, the working tree already contains a modified `Pure Pets/MainApp/Accessories/AccessFiles/PPProviderCompanyPremiumCardCell.m`, untracked `PPProviderProfileHero.swift`, untracked `PPProviderProfileHeroStore.swift`, and untracked `.agents/skills/code-review/`. These files are not part of this integration and must not be reset, staged, rewritten, or deleted.

## 7. Toolchain and validation constraints

The V4 package declares Node `>=22.18.0 <23` and npm `>=10 <12`. From the canonical package directory, the package lifecycle must use its lockfile and the documented gates:

```text
npm ci --ignore-scripts --no-audit --no-fund
npm run build
npm test
npm run coverage
npm run verify:package
npm run verify:parity
npm run routing
npm run mcp:smoke
npm run verify
```

Release generation, when required, must use the package’s own release command and allowlist. It must not overwrite an existing artifact. Build and verification commands apply to the plugin package only; they do not authorize an app build or device run.

For later Pure Pets target work, the app’s existing constraints remain authoritative: iOS 15+, code-only UIKit/MVC-plus-coordinator architecture, Arabic-first/English-LTR behavior, semantic `PPDesignTokens` sources, and existing route/state/backend ownership. The V4 brand contract requires reading live Pure Pets tokens and approved assets; it rejects reconstructed logos and guessed palettes.

## 8. Assumptions

- The requested external directory is accessible to the host and is the intended canonical V4 source.
- The host/plugin CLI or an approved workspace adapter is available to the implementation phase; neither marketplace registration nor live discovery was verified during this requirements phase.
- Existing V3 registrations are intentional and should remain available during V4 adoption.
- The current request is for setup requirements only; no app code, package source, generated package output, or installed cache should change in this phase.
- Any host trust JSON, physical-device access, renderer, image-inspection path, and independent reviewer needed for future evidence will be supplied by the host at the time of target validation rather than bundled or inferred here.

## 9. Acceptance criteria

The integration is ready for implementation review when all of the following are true:

1. This requirements artifact is committed/retained under `Docs/` and clearly marks implementation as not started for this phase.
2. A supported host registration plan exists for the exact V4 identity and canonical package path; it does not overwrite or remove V3.
3. The implementation plan identifies the concrete workspace registration files, if any, without treating `.kiro/settings/lsp.json` or iOS project configuration as plugin registries.
4. Package validation passes from V4 `src/` through the documented build, test, coverage, package, parity, routing, MCP-smoke, and aggregate verification gates, or each unavailable gate is recorded as `BLOCKED/UNVERIFIED` with its exact reason.
5. Installation is performed through the supported plugin/host flow, not by manually editing an installed cache or registering the V3-named archive found under V4 `release/`.
6. A newly started host task discovers all seven V4 skills and `swiftymax-nextgen-category-tools-v4`; MCP initialization exposes the declared fourteen read-only tools.
7. The workspace diff shows no changes to Pure Pets app source, Xcode/CocoaPods/backend configuration, V3 package source, or unrelated dirty-tree files as a result of the integration.
8. A later target-specific validation record distinguishes package proof from native proof and does not claim a visual/runtime score without current physical-device, accessibility, RTL/LTR, motion, performance, media/hash, and independent-review evidence.

## 10. Out of scope and open verification items

This phase intentionally does not perform marketplace registration, package installation, MCP startup, skill discovery, package tests, app builds, device runs, or target visual review. Those are implementation/validation checkpoints. Their current status is `UNVERIFIED`, not passed.

No user decision is required to proceed from this requirements artifact. The next phase should implement the host-supported registration/install path, preserve the boundaries above, and update validation status only from evidence produced by the actual host and package.

## 11. Traceability

- V4 package identity and default prompts: `.codex-plugin/plugin.json`
- V4 MCP command and server identity: `.mcp.json`
- V4 lifecycle and V3 coexistence: `MIGRATION.md`
- V4 standalone/provenance boundary: `PROVENANCE.md` and `references/standalone-runtime.md`
- Capability and native-proof boundary: `references/tool-accessibility.md`
- V4 orchestration and fail-closed handoff: `skills/swiftymax-nextgen-category-defining-v4/SKILL.md`
- Existing workspace architecture and app constraints: `README.md`, `CLAUDE.md`, and `Docs/HomeSwiftUIMigration/IMPLEMENTATION_LEDGER.md`
