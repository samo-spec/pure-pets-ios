# HomeOrderCard NextGen V6 Handoff

Last updated: 2026-08-16

## Current Status

- Target: `HomeOrderCard` in the SwiftUI Home current-order module
- Platform: iOS 15+, SwiftUI hosted from the production UIKit Home shell
- Mode: `redesign`
- Selected direction: Journey Spine
- Current phase: source verification complete, native runtime blocked
- Certification: `BLOCKED/UNVERIFIED`
- Backend and API changes: none authorized
- Build authority: connected physical iPhone 13 Pro Max only, default DerivedData path, no simulator and no command-line `xcodebuild`

## Frozen Scope

- Redesign the production current-order card and its private visual helpers in `HomeComponents.swift`.
- Preserve the `.livePriorityOrder` module, `HomeViewState.featuredOrder`, `HomeStore` ownership, Firebase listener, parent `Orders` schema, active-order selection, status normalization, progress stages, localization, and direct details route.
- Preserve `PPOrderStatusAppearance` as the only status-color and symbol authority.
- Keep Cloud Functions, Firestore rules and indexes, Firebase queries, APIs, persistence, analytics, checkout, fulfillment, and order-details behavior untouched.
- Keep Arabic RTL as the primary composition and English LTR as the secondary composition.
- Do not introduce a second card owner, a child `FulfillmentOrders` listener, a context sheet, or new analytics.
- Do not modify or revert the unrelated payment redesign already present in the worktree.

## Authority Map

- Production card owner: `Pure Pets/MainApp/ModrenAppVC/SwiftUIHome/Views/HomeComponents.swift:2992-3495`
- Module reachability and tap closure: `Pure Pets/MainApp/ModrenAppVC/SwiftUIHome/Views/HomeView.swift:342-380`
- State and model owner: `Pure Pets/MainApp/ModrenAppVC/SwiftUIHome/State/HomeViewState.swift:236-248,342-387`
- Store and listener-state owner: `Pure Pets/MainApp/ModrenAppVC/SwiftUIHome/State/HomeStore.swift:632-722,1203-1268`
- Model adapter: `Pure Pets/MainApp/ModrenAppVC/SwiftUIHome/Data/HomeModelAdapter.swift:97-119`
- Active-order and presentation bridge: `Pure Pets/MainApp/ModrenAppVC/SwiftUIHome/Bridge/PPHomeDataBridge.m:1890-1943,2013-2088`
- Status normalization: `Pure Pets/MainApp/PAYMENTS/Models/Orders/PPOrder.m:303-324,407-540`
- Shared status appearance: `Pure Pets/MainApp/PAYMENTS/CartAndOrdersFiles/PPOrderStatusAppearance.h:56-94,111-180,232-290,321-337`
- Swift route owner: `Pure Pets/MainApp/ModrenAppVC/SwiftUIHome/Routing/HomeRouter.swift:9-42,68-75`
- Objective-C route bridge: `Pure Pets/MainApp/ModrenAppVC/PPHomeViewController.m:354-375`
- Details route authority: `Pure Pets/MainApp/PAYMENTS/CartAndOrdersFiles/PPOrderDetailsRouter.m:16-49`
- Brand authority: `Pure Pets/DesignFiles/PP/PPStyles/PurePets-DesignSystem.swift`
- Layout token authority: `Pure Pets/DesignFiles/PP/PPStyles/PPDesignTokens.h`
- Localization authority: `Pure Pets/ar.lproj/Localizable.strings` and `Pure Pets/en.lproj/Localizable.strings`
- Backend contract authority: `Pure Pets Infra/firestore.rules`, `Pure Pets Infra/firestore/indexes.json`, and `Pure Pets Infra/functions/fulfillmentOrders.js`

## Phase Log

### Phase 1: Intake And Limits

Status: complete

- Resolved the user target to the production SwiftUI `HomeOrderCard` shown by `.livePriorityOrder`.
- Froze `redesign` mode and a frontend-only boundary.
- Confirmed the whole card remains one button whose action is `store.openOrder(order)`.
- Confirmed the required device is a connected iPhone 13 Pro Max with CoreDevice identifier `4A693B80-A35D-51F8-BE4B-027200738B05`.
- Recorded that the installed app could not previously launch while the device was locked, so no honest baseline render is available yet.

### Phase 2: Source And Behavior Inspection

Status: complete

- Traced the production path from the Home tab through `HomeStore`, `HomeRepository`, `PPHomeDataBridge`, `HomeModelAdapter`, `HomeView`, and `HomeOrderCard` to `PPOrderDetailsRouter`.
- Confirmed Home reads the newest active parent order from the newest twelve `Orders` documents; it does not listen to `FulfillmentOrders`.
- Confirmed terminal orders suppress the current-order card and the server-controlled section remains stable ID `2`.
- Confirmed an active order owns the single live-priority slot ahead of a care reminder.
- Confirmed the card receives localized status title and hint, reference, item count, amount, progress, preview URLs, and the raw `PPOrder`.
- Confirmed preview image URLs are populated but intentionally unused by the current card; using them is not required for parity.
- Confirmed no current-order impression or tap analytics exists. Adding analytics would be new behavior.
- Confirmed no checked-in production screenshot or direct card rendering test exists.

### Phase 3: Parity, Brand, Direction, And Native UX

Status: complete

- Froze the behavior and ownership invariants below with no authorized backend, API, listener, model, analytics, or route changes.
- Ran the V6 visual-validation planner with only host capabilities that are currently reachable. Input passed, but the result is `BLOCKED/UNVERIFIED` because baseline, physical-device capture, assistive-technology runtime, motion capture, and performance profiling are unavailable while the phone is locked.
- Retried `com.PB.Pure-Bird` on CoreDevice `4A693B80-A35D-51F8-BE4B-027200738B05`; CoreDevice again returned `RequestDenied` / `Locked`.
- Bound the brand to `ppPrimary`, `ppPressedAction`, `ppPremiumAccent`, `ppBackground`, `ppSurface`, `ppTextPrimary`, and `ppTextSecondary`. The V6 brand validator returned `valid: true` and `purePetsReady: true`.
- Confirmed no logo belongs in this card; no asset reconstruction or substitute mark is authorized.
- Considered exactly three structurally different concepts: Journey Spine, Parcel Window, and Dispatch Ledger.
- An independent source reviewer, `independent-home-order-concept-reviewer`, found Journey Spine eligible across all sixteen frozen source/spec dimensions.
- Rejected Parcel Window because optional image loading would displace order status, add mixed media states, and lack source-backed image descriptions.
- Rejected Dispatch Ledger because it would create an operations-style hierarchy and duplicate the canonical stage sequence in the view.
- Selected motion policy `reduce`: initial appearance is settled, only a real source-progress change retargets the fill and beacon, routing remains interactive, and Reduce Motion applies the new value immediately.
- The V6 motion validator returned `VALID_MOTION_CONTRACT` with no findings. Its proof boundary remains structural; canonical source resolution and device runtime are unverified.

### Phase 4: Implementation

Status: complete

- Replaced the private linear spring bar with `HomeOrderJourneyProgress`, a continuous origin-to-destination route driven only by the existing scalar `progress`.
- Kept initial appearance settled and limited motion to a 250 ms ease-out retarget when the authoritative value changes.
- Added live Reduce Motion handling that settles the route immediately without removing state meaning.
- Reorganized the card into status header, dominant journey, and quiet amount/item footer while preserving the external heading and reference.
- Reduced competing nested chrome by changing the 60-point rounded glyph plate to a 50-point semantic beacon and removing the circular disclosure backing.
- Preserved `PPOrderStatusAppearance` for accent, surface, border, and symbol selection.
- Added only approved SF Symbols for amount and item summary cues; both are decorative and hidden from accessibility.
- Preserved one native button, added an explicit localized accessibility identity containing the order reference, and kept the existing details hint.
- Kept accessibility-size status and summary reflow, semantic leading/trailing route direction, dark-mode dynamic colors, and increased-contrast borders.
- Added no remote images, strings, assets, models, APIs, listeners, routes, analytics, or backend changes.
- Passed `swiftc -frontend -parse` for `HomeComponents.swift` and passed scoped `git diff --check`.

### Phase 5: Independent Review

Status: complete

- CodeRabbit CLI was unavailable, so two separate read-only reviewers inspected SwiftUI correctness and native UX/accessibility.
- The first review found RTL double mirroring, misleading intermediate stage markers, Reduce Motion cancellation, and cross-order animation-state retention.
- Used the single permitted correction pass to switch to a continuous origin-to-destination route, anchor fill to semantic leading, recreate the rendered subtree when Reduce Motion is enabled, initialize from authoritative progress, and key journey identity by `order.id`.
- The correction also added the order reference to the button's explicit accessibility identity and strengthened Increased Contrast glyph, disclosure, route thickness, and inactive-track treatment.
- Post-correction review found no blocking source, compilation, routing, state, availability, layout, RTL, Reduce Motion, or performance-structure defect.
- Residual visual risk: source-only color estimates cannot prove every dark/increased-contrast route and beacon combination reaches the desired low-vision separation. Status title, hint, position, symbol, and shape retain non-color meaning.
- Residual accessibility risk: linear VoiceOver navigation may announce the external heading/reference and then repeat them inside the uniquely identified button label. Button-rotor identity is improved, but device speech remains unverified.
- Retained localization debt: the existing fixed item-count format does not provide complete English singular or Arabic plural categories. This predates the redesign and was not widened.
- No second visual correction pass was started; unresolved pixel questions remain `BLOCKED/UNVERIFIED`.

### Phase 6: Verification And Render Review

Status: `BLOCKED/UNVERIFIED`

- No baseline or candidate PNG exists for this target.
- Native runtime, VoiceOver, RTL, Dynamic Type, motion, interruption, and performance evidence require the connected physical device.
- The smallest unblock is to capture the already-launched installed app as the baseline, then build and launch the current source through the authorized Xcode physical-device path.
- Passed `xcrun swiftc -frontend -parse` for the changed Swift source.
- Passed repository-wide `git diff --check`.
- V6 brand validation returned `valid: true` and `purePetsReady: true`.
- Final V6 motion validation returned `VALID_MOTION_CONTRACT` with no findings and the explicit structural-only proof boundary.
- V6 Apple source audit returned only static hints outside the `HomeOrderJourneyProgress` / `HomeOrderCard` line range; it does not constitute compilation or runtime proof.
- Independent post-correction source review found no blocking target-local source finding.
- No `xcodebuild`, simulator build, or test target was run under repository policy.
- A later retry at 23:14:56 successfully launched the installed `com.PB.Pure-Bird` app after the device became available.
- The installed app is a potential pre-build baseline only; it is not provenance for the current changed source.
- Automated baseline capture remains blocked: `idevicescreenshot` could not start the legacy screenshot service, and `pymobiledevice3` requires a privileged iOS 26 tunnel that is not running.
- No screenshot artifact was created, so the visual gate remains blocked despite successful launch.
- Independent proof returned `certified: false`, `reviewUnlocked: false`, and `targetHashesCurrent: true`; no numeric score is authorized.
- Proof also requires current-source device build provenance, native runtime, accessibility, RTL, motion, performance, visual measurements, and externally bound reviewer artifacts.

## Product DNA

- Purpose: let a guardian understand the newest active order state at a glance and open its details directly.
- Primary outcome: the visible status, hint, progress, reference, amount, and item count all identify one stable order before navigation.
- Dominant action: activate the single whole-card button to open the existing order-details route.
- Context: a repeated Home-feed glance that may be brief, interrupted, one-handed, Arabic RTL, or English LTR.
- Emotional tone: calm operational reassurance rather than celebratory commerce, clinical severity, or admin logistics.
- Brand truth: Beiruti typography, Arabic-first composition, quiet warm surfaces, and semantic order-status color from current product sources.
- Information density: one current state, one journey, and one compact summary; no secondary actions or dashboard metrics.
- Signature opportunity: make the existing scalar order progress the card's memorable product object without inventing data or stage copy.
- Technical constraints: iOS 15+, one state owner, one route owner, one button, no new network work, no new localization, and no backend changes.

## Baseline Autopsy

Visual status: unavailable. No screenshot or target render is claimed.

Source inspection predicts, but does not visually prove, that the current section heading and status title compete at the same `title2` tier, while the 60-point glyph, circular disclosure, leading accent strip, gradient surface, progress bar, divider, and footer repeat a familiar icon-card grammar. The redesign response is to keep the heading, reduce nested chrome, move order progress into the dominant middle region, and retain a quiet summary footer. Pixel quality remains unverified until native captures exist.

## Concept Set

### 1. Journey Spine - selected

- Topology: status glyph and copy lead, a continuous origin-to-destination route becomes the dominant middle region, and amount/items form a calm footer.
- Interaction: the whole surface remains one button with direct details disclosure.
- Signature: one current beacon follows the existing scalar progress; the route exposes no invented intermediate stage markers, titles, or thresholds.
- Adaptation: horizontal route at compact and regular widths; copy and footer reflow vertically through AX5.
- State model: already-resolved retained content only; no image, retry, permission, or secondary loading state.
- Migration seam: private card layout and private progress helper only.

### 2. Parcel Window - rejected

- Topology: a first item image dominates a split media/status surface with overlapping extra previews.
- Interaction: one parent button with disabled nested image retry.
- Signature: purchased-item imagery reveals through the shared image pipeline.
- Rejection: media completion is unrelated to order-state progress, optional images lack descriptive metadata, and network states become the dominant hierarchy.

### 3. Dispatch Ledger - rejected

- Topology: reference/status header, two metric cells, then a vertical five-row dispatch checklist.
- Interaction: one parent button with row changes driven by source state.
- Signature: the current checklist row advances into a checked row.
- Rejection: the dense admin-like ledger competes with consumer Home rhythm and would require a second UI-owned stage sequence.

Every concept pair differs in six structural fields: information topology, dominant region, signature interaction, motion model, state/recovery model, and adaptation model. Navigation/focus and direct disclosure remain deliberately identical for parity.

## Native UX Contract

- Task and risk: prioritize immediate status comprehension; a tap must open the same stable order and never mutate it.
- Navigation and restoration: `HomeRouter` remains the sole route owner; no sheet, custom dismissal, or unsaved state is introduced.
- State and async ownership: `HomeStore` and `HomeRepository` remain authoritative; the card starts no task, listener, or media request.
- Focus and input: one semantic `Button` owns touch, keyboard, Voice Control, and Switch Control activation; there is no keyboard input.
- Scroll continuity: the card adds no internal scrolling or selection and does not change Home scroll ownership.
- Ergonomics: the full-width card exceeds the 44-point target and adds no edge gesture.
- Adaptive layout: default content remains compact; accessibility sizes use vertical status and summary reflow while the journey stays full-width.
- Accessibility: localized status text and symbol carry meaning independently of color; route decoration is hidden; the localized details hint remains.
- RTL and mixed script: use semantic leading/trailing alignment; route growth starts from semantic leading; disclosure keeps its existing RTL behavior.
- Feedback and recovery: retain the existing 700 ms route guard; add no destructive, permission, retry, or write state.
- Native components and appearance: use SwiftUI `Button`, shapes, design tokens, shared status appearance, dark-mode dynamic colors, increased-contrast borders, and an opaque Reduce Transparency-safe surface.

Runtime focus restoration, VoiceOver phrasing, AX5 pixels, RTL pixels, and regular-width behavior remain unverified.

## Motion Contract

- Decision: `reduce`.
- Trigger: a mounted featured order receives a different resolved progress value; initial appearance does not replay a journey sweep.
- Owner: `HomeStore` owns source state and `HomeOrderJourneyProgress` owns the one rendered progress value.
- Phase: retarget fill width and beacon position from the current rendered value to the clamped source value.
- Mechanics: scoped SwiftUI `withAnimation`, 250 ms ease-out hypothesis, no spring, no loop, no continuous work, stable `HomeOrderModel.id` identity.
- Interruption: a newer value retargets from the current presentation; the whole card remains tappable.
- Lifecycle: no work after settlement; view disappearance or backgrounding ends the private animation state.
- Reduce Motion: apply the same final route, status, and summary immediately.
- Haptics and audio: none; neither carries order meaning.

## Behavior Ledger

| Contract | Status | Preserved requirement |
|---|---|---|
| Home module reachability | `PASS` | Keep server order, visibility, stable section ID `2`, and `.livePriorityOrder`. |
| State ownership | `PASS` | `HomeStore` remains the only Home state owner; the card remains presentational. |
| Firebase ownership | `PASS` | Keep the existing `Orders` listener and query unchanged; add no listener or write. |
| Active-order selection | `PASS` | Keep newest-active selection within the newest twelve parent orders. |
| Status semantics | `PASS` | Keep `PPOrder.customerVisibleStatusKey` and the five active stages unchanged. |
| Status appearance | `PASS` | Keep `PPOrderStatusAppearance` as color, surface, border, and symbol authority. |
| Order details route | `PASS` | Keep `HomeStore.openOrder` to `HomeRouter` to `pp_homeOpenOrder:` unchanged. |
| Duplicate-route protection | `PASS` | Keep the existing 700 ms in-flight route guard. |
| Localization | `PASS` | Keep existing Arabic and English status, hint, heading, item-count, and accessibility strings. |
| Accessibility | `PASS` | Keep one button, localized identity and hint, Dynamic Type reflow, non-color status meaning, and 44-point targets. |
| Motion | `PASS` | Keep progress state-driven and preserve the Reduce Motion equivalent. |
| Card analytics | `NOT_APPLICABLE` | No card analytics exists; do not add it in this redesign. |
| Physical-device behavior | `UNVERIFIED` | Requires a current-source physical-device build plus interaction evidence; the installed pre-build app launch is not candidate proof. |
| Visual quality | `UNVERIFIED` | Requires baseline and candidate PNG review in required locales, appearances, and sizes. |

## Active Status Stages

| Customer status | Progress | Shared symbol |
|---|---:|---|
| `pending` | 0.16 | `clock.fill` |
| `preparing_for_shipment` | 0.28 | `shippingbox.circle.fill` |
| `ready_for_delivery` | 0.46 | `shippingbox.fill` |
| `delivery_partner_assigned` | 0.62 | `person.crop.circle.fill` |
| `on_the_way` | 0.86 | `shippedtruck` |

Delivered, completed, cancelled, failed, and returned orders remain excluded from the current-order card.

## Known Risks Outside Redesign Scope

- Home and Order History can retain concurrent read listeners after visiting Orders.
- Status copy is duplicated across Home, Order History, legacy details, and mission control even though canonical status and appearance are shared.
- A delayed-status normalization gap can fall back to preparing.
- Legacy order documents without `userId` or `createdAt`, or active orders outside the latest twelve, do not appear.
- `HomeOrderContextSheet` is declared but not reachable from the production tap path.
- There is no Home-card rollback flag to a legacy implementation.

These findings are not authorized to widen this visual redesign.

## Source Evidence Snapshots

### Preimplementation

Observed: 2026-08-16T18:56:02Z

```text
b77292cee6d3f97176192614a4f1a4b72fff991df9df9a1d0dc877ef37215209  Pure Pets/MainApp/ModrenAppVC/SwiftUIHome/Views/HomeComponents.swift
43294e7f1a6fc99010eb5da24b2e579d26f4c8950e280c5529eaa560b0677832  Pure Pets/MainApp/ModrenAppVC/SwiftUIHome/Views/HomeView.swift
2c1a07a5ad7e8fadba2f04609fe6c831784a19d25217b67bdec64547e9a5b61b  Pure Pets/MainApp/ModrenAppVC/SwiftUIHome/State/HomeViewState.swift
1a3a613561e9794e84b7d63d612818a3add7e5f8ff2d7bb8da1c6f504b0d8849  Pure Pets/MainApp/ModrenAppVC/SwiftUIHome/Data/HomeModelAdapter.swift
c983945e03149dd8c4be83325df86ed11fb1d0ab0058668893e2aa121c8c81f7  Pure Pets/MainApp/ModrenAppVC/SwiftUIHome/Bridge/PPHomeDataBridge.m
252c4e8f14472c571632d42decb1e845cf94c94d29b2e76b4a5db971e2f2c314  Pure Pets/MainApp/ModrenAppVC/SwiftUIHome/State/HomeStore.swift
de60ce32a61408b561e5c7afe8099e81d1d8cbb2870b2e14b9f5c7a9128dcbc8  Pure Pets/MainApp/ModrenAppVC/SwiftUIHome/Routing/HomeRouter.swift
2dc563a2a809a91f3d529031ad913d539f9dc83e929128bb9117152d1827ff4a  Pure Pets/MainApp/ModrenAppVC/PPHomeViewController.m
1f93aaec387f3c2f19aad7717dc5cfebb3b9c09aa94c4a16057b493247878c02  Pure Pets/MainApp/PAYMENTS/CartAndOrdersFiles/PPOrderStatusAppearance.h
2b6220f72565bd1b7fd550b0287491e5719a1fb0718821d15d7ca3447557c3e8  Pure Pets/DesignFiles/PP/PPStyles/PurePets-DesignSystem.swift
ea00f3c96a225f46e834f2c269abb6d9ec701e15d8606b90b41e27487a2effe9  Pure Pets/DesignFiles/PP/PPStyles/PPDesignTokens.h
```

### Final Target Source

Observed after the single correction pass on 2026-08-16.

```text
33136367bd8c94d440373ce6d748c229eb21702106a805895dd96ea8d621599d  169969 bytes  Pure Pets/MainApp/ModrenAppVC/SwiftUIHome/Views/HomeComponents.swift
```

Final bounded source regions:

- `HomeOrderJourneyProgress`: `HomeComponents.swift:2992-3136`
- `HomeOrderCard`: `HomeComponents.swift:3138-3495`

## Changed Files

- `Pure Pets/MainApp/ModrenAppVC/SwiftUIHome/Views/HomeComponents.swift`
- `Docs/HomeOrderCard-NextGen-V6-Handoff.md`

No localization, model, state, repository, bridge, router, Firebase, API, analytics, asset, or backend file changed for this target. The payment and localization modifications already present in the worktree belong to the earlier payment redesign and were not altered or reverted here.

## Next Action

Capture the currently installed app as the pre-build baseline using an authorized physical-device screenshot path, then perform the repository-authorized Xcode device build for the current source. Capture and independently review Arabic RTL and English LTR in light, dark, Increased Contrast, default Dynamic Type, AX5, stable progress, a live progress update, Reduce Motion, and a featured-order replacement. Do not start another source redesign loop without that evidence.
