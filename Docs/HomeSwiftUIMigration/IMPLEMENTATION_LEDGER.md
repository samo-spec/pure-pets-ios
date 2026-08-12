# Pure Pets Pulse — SwiftUI Home Migration Ledger

Date: 2026-07-29
Production entry point: `PPHomeViewController`
SwiftUI owner: `PPHomeHostingController` → `HomeStore` → `HomeView`

## Product DNA

- Arabic-first pet command center, not a generic marketplace feed.
- One signature anchor: the Pet Pulse hero answers what matters now.
- Brand authority comes from semantic Pure Pets tokens, especially `Color.ppPrimary`.
- The hierarchy is command bar → Pulse hero → pet context → priority actions → relevance-first feed.
- Materials are restrained: one elevated hero, quiet cards, and semantic state surfaces.
- Real pet, reminder, order, inventory, service, location, promotion, and Console configuration data only.

## Selected concept

Three structures were evaluated:

| Concept | Design-selection score | Decision |
|---|---:|---|
| Marketplace Spotlight | 74/100 | Strong commerce focus, but it underweights pet ownership and care continuity. |
| Pet Daybook | 82/100 | Strong care focus, but it narrows marketplace and provider reach. |
| Pure Pets Pulse | 93/100 | Selected because it unifies genuine pet context, current orders, care, and marketplace actions without fabricating personalization. |

These are comparative concept-selection scores, not release-readiness scores.

The hero treatment was re-evaluated for the 2026-07-30 server-driven registry
pass:

| Hero treatment | Product DNA | Five-second clarity | Arabic / RTL | Accessibility | Motion restraint | Performance | Migration safety | Total | Decision |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Restrained semantic gradient + Home floating plate | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 35/35 | Selected; it keeps the signature content plate while removing decorative blur and ambient sweep work. |
| Pro provider glass field + Home floating plate | 4 | 5 | 5 | 4 | 3 | 3 | 5 | 29/35 | Rejected for Home; visually rich, but its continuously animated blur/sweep field adds cost without communicating state. |
| Plain elevated surface + context route | 4 | 4 | 5 | 5 | 5 | 5 | 5 | 33/35 | Rejected; disciplined, but loses useful visual separation between context pages. |

The selected field resolves through the existing Pure Pets semantic surface and
accent tokens. Consumer Home state, analytics, navigation, hero timing, and
data ownership remain independent.

## Symbol ledger

| Contract | Legacy shape | Production decision |
|---|---|---|
| Runtime class | `PPHomeViewController` | Retained as the exact Objective-C runtime class. |
| Public factory | `-buildDataViewVCForTarget:mainKind:source:` | Retained with the same selector and route input contract. |
| Layout property | `mainKindsLayoutMode` | Retained for binary/source compatibility; SwiftUI uses an adaptive rail. |
| Initial category | `initialSelectedMainKindID` | Retained and forwarded into `HomeStore`. |
| Universal-card delegate | `PPUniversalCellDelegate` selectors | Retained on the shell and forwarded to existing cart/detail/share/save behavior. |
| Generated Swift bridge | `Pure_Pets-Swift.h` | Used only by the shell to instantiate the Swift host. |
| Language change | `LanguageDidChangeNotification` | Observed once by the Swift repository; locale and direction are republished atomically. |
| Cart change | `kCartUpdatedNotification` / `CartUpdated` | Observed once by `HomeStore`; the authoritative count remains `CartManager`. |
| User/session changes | UserManager sync/sign-out/access notifications | Observed once and used to refresh authenticated sections and permissions. |
| Main-kind changes | `PPMainKindsUpdatedNotification` | Adapted by `PPHomeDataBridge`; stable category IDs are preserved. |
| Console Home control | `AppConfigCol/HomeConfig` | Listener, sanitization, visibility, order, and cache keys remain authoritative. |
| Current orders | `Orders` query by authenticated `userId` | One owned listener in `PPHomeDataBridge`; parsed through `PPOrder`. |

## Call-site ledger

| Caller / behavior | Evidence | Preserved contract |
|---|---|---|
| Root tab creation | `PPRootTabBarController` creates `PPHomeViewController` | Unchanged entry point and navigation-controller wrapper. |
| Legacy root creation | `NewAppVC` resolves the Home tab through `PPHomeViewController` | Only the Home tab creates the Home shell; unrelated placeholder tabs use a plain `UIViewController`, preventing duplicate Home listeners. |
| Runtime location return | `LocationPickerViewController` resolves `NSClassFromString(@"PPHomeViewController")` | Exact class name retained. |
| Order return-to-home | `OrderDetailsViewController` tests `isKindOfClass:PPHomeViewController.class` | Exact class identity retained. |
| Card Home presentation | `PPUniversalCellSwiftUI` tests the delegate's Home class | Shell remains the card delegate. |
| Root adapter | `PPRootObjCAdapter` recognizes the class name | Exact class name retained. |
| Menu routing | `PPMenuHelper` recognizes the class symbol | Exact class name retained. |
| Home tab reselection | Root tab delegate | Forwarded to `PPHomeHostingController` for scroll-to-top and deduplicated refresh. |

## Behavioral parity ledger

| Responsibility | Authoritative owner after migration | Parity mechanism |
|---|---|---|
| Search and rotating prompts | `HomeStore` + existing `PPSearchViewController` | Stable search target; rotation pauses for interaction, background, navigation, Reduce Motion, and VoiceOver. |
| Selected category | `HomeStore` | Stable main-kind ID persisted under the existing `PPHome.lastSelectedMainKindID.v1` key. |
| Marketplace routing | Objective-C compatibility shell | Existing `PPDataViewInput`, deep-link target, source, and initial-section contracts. |
| Products / food | `PPHomeDataBridge` + existing managers | One-shot existing manager reads, mapped through `PPUniversalCellViewModel`. |
| Ads / nearby ads | `PPHomeDataBridge` + `PetAdManager` | Existing latest/nearby APIs; location-aware requests remain genuine. |
| Services | `PPHomeDataBridge` + `ServicesManager` | Existing public service query and model validation. |
| Pet profiles / reminders | `PPHomeDataBridge` + `PPPetProfileManager` | Default-pet selection and real enabled reminders only. |
| Current orders | `PPHomeDataBridge` | One Firestore listener, authenticated UID filter, stable order identity. |
| Buy again | `HomeModelAdapter` | Resolves genuine accessory IDs from order snapshots; no fabricated products. |
| Favorites | Existing universal-card favorite control | Existing Firebase-backed favorite implementation remains authoritative. |
| Cart / quantity / stock | `CartManager` through shell forwarding | Existing provider-switch confirmation, stock clamp, add/update/remove, notifications, and haptics. |
| Saved for later | `PPSaveForLaterManager` through shell forwarding | Existing item IDs and mutation notifications. |
| Promotions | `PPHomePromoCarouselManager` | One listener and server-driven tap actions. |
| Location | `PPHomeDataBridge` + existing picker | Automatic, denied, failed, and manual-area paths; no simulated production location. |
| Home Control | `PPHomeDataBridge` | Existing cache key and Console section order/visibility contract. |
| Detail routing | `PPOverlayCoordinator` | Existing viewer ownership and browse-history tracking. |
| Cart badge | `CartManager` | Command bar reads the real total item count. |
| First-render gate | `PPHomeHostingController` | Waits for a loaded, partial, empty, or failed SwiftUI presentation, lays it out, then removes the launch snapshot tagged `99182` with Reduce Motion respected. |
| Loading / partial / error / empty | `HomeViewState` | Global and per-section explicit render states with retry. |
| RTL / localization | `Language` + localized keys | Direction, alignment, copy, and formatter locale are republished together. |
| Accessibility | SwiftUI semantic hierarchy | Headings, contained interactive descendants, card summaries, explicit labels/hints, 44-point targets, and non-color state meaning. |
| Motion | SwiftUI motion grammar | Atomic hero transitions; Reduce Motion keeps meaning with concise crossfades. |

## Ownership ledger

| Responsibility | Previous owner | New active owner | Legacy outcome |
|---|---|---|---|
| Collection view and compositional layout | `PPHomeViewController` | `HomeView` lazy SwiftUI composition | Removed from production Home controller. |
| Visible loading and empty states | `PPHomeViewController` cells | `HomeViewState` + SwiftUI state surfaces | Removed from production Home controller. |
| Home data orchestration | `PPHomeViewController` | `HomeStore` / `HomeRepository` / `PPHomeDataBridge` | Removed from production Home controller. |
| Firestore listener lifecycle | `PPHomeViewController` | `PPHomeDataBridge` owned by `HomeRepository` | Exactly one owner per Home instance. |
| HomeConfig | `PPHomeViewController` | `PPHomeDataBridge` | Exact collection/document/cache contract retained. |
| Hero timing and state | UIKit cells/timers | `HomeStore` | One atomic state owner. |
| Section identity/order | Diffable UIKit snapshot | Stable raw integer IDs plus a semantic SwiftUI section kind | Console order is preserved and duplicate config rows retain their first occurrence. |
| Navigation | `PPHomeViewController` | Existing UIKit navigation through thin shell | Shell forwards only; no SwiftUI navigation fork. |
| Card mutations | Universal cell delegate on controller | Existing delegate selectors on thin shell | Business services remain unchanged. |
| Root dock | `PPRootTabBarController` | `PPRootTabBarController` | Never duplicated by Home. |

## 2026-07-30 server-driven registry pass

- `AppConfigCol/HomeConfig` now reaches SwiftUI as ordered
  `HomeConfigSection` values that retain raw integer identity, normalized type,
  visibility, and property-list-safe server metadata.
- All 19 Console-controlled Home IDs keep distinct identities, including
  carousel `4`, suggestions `6`, marketplace `17`, suggestion ads `18`, and
  suggestion accessories `19`. Unknown future IDs are retained by the
  model/cache boundary and ignored by the current renderer until a supported
  component exists.
- Hero, promotion carousel, and marketplace are separate configurable lanes.
  Their content no longer changes the identity of another configured row.
- `titleViewMode`, `premiumCareVisible`, `novaFloatingVisible`, and
  `backgroundGlowsFaded` are honored by the SwiftUI presentation. Invalid title
  modes safely fall back to the location command surface.
- The Home-specific semantic color aliases resolve through the existing
  `Color.pp*` design-system tokens; this pass does not introduce a parallel
  palette.
- Promotion content is listener-driven through the existing
  `HomePromoCarouselCollection` manager and uses server-provided rotation
  timing. No collection, permission, or analytics contract changed.
- Order-card taps forward the exact `HomeOrderModel` selected by the user.
- The iOS 15 universal-card compatibility renderer observes `CartUpdated` and
  re-reads the authoritative `CartManager` quantity, matching the iOS 16+
  external-cart synchronization contract.
- Pull-to-refresh returns after the first non-connectivity repository delivery,
  with the existing eight-second timeout retained when no source delivers.

## Migration and validation boundaries

- The app deployment target remains iOS 15.
- iOS 16+ uses the existing SwiftUI universal card renderer; iOS 15 receives a native SwiftUI compatibility card with the same routes and stock states.
- No backend schema, Firebase rule, permission, provider, inventory, or analytics collection contract is changed.
- No simulator is an accepted runtime proof target.
- Shell `xcodebuild` is prohibited by repository policy.
- Static parse, localization, config-contract, diff, and ownership audits precede the connected-device run.
- A successful app build, install, and launch proves the production target reaches the connected iPhone 13 Pro Max; visual fidelity, interaction flows, accessibility modes, and performance remain separate evidence requirements.

## Final Home visual alignment

- The pinned command surface honors server `titleViewMode`: location mode shows
  the real location control, compact search, and cart; search mode gives the
  real search control the semantic-leading lane up to the cart.
- `HomeTopFadeBackdrop` extends the command material through the top safe area and fades it out below the bar. It is noninteractive and accessibility-hidden.
- The Pet Pulse hero's normal baseline height is 296 points instead of 326. Pagination owns a reserved bottom strip, so it no longer overlaps either action.
- The primary hero action is content-fitting at normal Dynamic Type, keeps a full-width accessibility fallback, uses a 17-point continuous corner, and reserves deliberate label-to-arrow spacing without truncating the observed Arabic copy.
- Hero headlines use concise three-to-four-word Arabic and English copy in one equal 42-point title slot at standard text sizes. Dynamic promotion/reminder titles are presentation-clamped to four words while their complete value remains available to accessibility; Accessibility Dynamic Type receives a reserved two-line slot.
- The hero backdrop uses a restrained three-stop semantic surface/accent field.
  It has no continuous blur or light-sweep animation; state changes remain in
  the keyed page transition, and Increased Contrast resolves through the
  semantic section surface.
- Hero page changes are atomic: title, supporting copy, floating plate, actions, and page control move as one keyed page. Standard motion uses a short damped spring with opacity, restrained vertical travel, and a 1% scale; Reduce Motion uses a 0.16-second crossfade.
- Every genuine hero state now uses the same trailing floating-plate composition:
  - pet → bundled `HomePetPulse.json`
  - reminder → bundled `HomeCareReminder.json`
  - promotion → bundled `HomePromotionSpark.json`
  - pet onboarding → existing asset-catalog image `pawprint4`
  - marketplace → the existing Firebase-backed `petstore` Lottie
- The three local animations are bundled resources and share the existing Objective-C Lottie runtime through `PPHomeHeroAnimationView`; no second animation dependency was introduced. Pet onboarding does not instantiate the Lottie bridge, and `pawprint4` is intentionally template-rendered in solid black. The Marketplace Lottie remains Firebase-backed and is clipped to the floating plate so its legacy glow cannot spill across the hero.
- “Explore by pet” embeds the production `PPMainKindsCell` through a focused `UIViewRepresentable` collection adapter. Its real images, accessibility identifiers, RTL semantics, and legacy main-kind route are retained; only the selected cell receives a restrained 3.5% scale.
- The main-kind rail uses 101 virtual cycles for touch exploration, centers the selected logical category, recenters invisibly near its virtual edges, and starts with the real “All” item centered when no category is selected. VoiceOver receives one finite logical set with centered edge insets instead of duplicate accessibility elements.
- Every Home section backed by `PPUniversalCellSwiftUI` is a lazy horizontal rail. At standard phone widths the live container resolves two complete cells, two inter-card gaps, and exactly 12% of the third cell. The initial state respects the semantic-leading screen inset; the terminal semantic-trailing edge is full-bleed with a zero inset. Compact widths and Accessibility Dynamic Type retain a readable one-card fallback.
- iOS 16+ Home cards have one navigation owner. `HomeUniversalDirectCard`
  leaves the legacy `onTap` closure unset and routes the card through
  `PPUniversalCellDelegate`, preventing the previous closure-plus-delegate
  double push while preserving favorite, cart, quantity, save, video, report,
  and context actions. The iOS 15 compatibility card retains its SwiftUI
  closure fallback.
- Loaded Home content enters once per Home lifetime. The hero, pet selector, and priority actions use small 60/100/120-millisecond staging with one damped spring; refreshes do not replay the entrance. Reduce Motion removes travel and stagger and retains only a short fade. Search and pinned command controls never move.

## Validation record

- The 2026-07-30 registry pass is covered by scoped source parsing,
  localization linting, diff checks, focused config-contract test sources, and
  the SwiftyUI-MAX static audit. These are source-level checks only; the tests
  were not executed.
- The connected-device build recorded earlier on 2026-07-30 was a pre-edit
  baseline. A post-edit build, install, launch, visual pass, interaction pass,
  accessibility pass, and performance pass remain `UNVERIFIED`.
- Final Swift and compatibility sources pass `swiftc -frontend -parse`, including the existing `PPMainKindsCell.swift` and focused Home migration tests.
- `project.pbxproj` and both localization files pass `plutil -lint`; the three generated Lottie JSON files and the existing `pawprint4` asset manifest pass `jq empty`; `git diff --check` is clean.
- The SwiftyUI-MAX package integrity gate passes all 26 required files. Its
  scoped static audit scans all 13 SwiftUI Home sources plus the two modified
  Objective-C entry/listener sources with zero findings.
- Every literal `HomeModelAdapter.localized` key referenced by SwiftUI Home
  resolves in both Arabic and English.
- Xcode GUI previously built, installed, and launched the production `Pure Pets` scheme on the connected physical iPhone 13 Pro Max (`iPhone14,3`, iOS 26.5.2).
- A historical 2026-07-29 Arabic RTL pass observed the previous command
  surface, hero, category rail, universal-card scrolling, category route, and
  back navigation. It predates the 2026-07-30 registry and command-surface
  changes and is not current runtime proof.
- After the CodeRabbit corrections, Xcode GUI `Product > Build` completed successfully for the production `Pure Pets` scheme with the selected physical iPhone destination at 10:05 on 2026-07-29. Xcode could not launch the app because the iPhone auto-locked. Final post-edit visual proof and live single-push interaction proof remain `UNVERIFIED` until the device is unlocked.
- The scoped final runtime console recorded zero `Publishing changes from within view updates` warnings during the hero and category interaction pass, and no fatal error.
- Device evidence:
  - Pure Pets Pro reference: `/Users/mohammedahmed/.codex/visualizations/2026/07/29/019fab7d-06e4-7992-ab54-759c6e70e164/pure-pets-pro-provider-card-reference.jpg`
  - `/Users/mohammedahmed/.codex/visualizations/2026/07/29/019fab7d-06e4-7992-ab54-759c6e70e164/pure-pets-home-final-onboarding-arabic.jpg`
  - `/Users/mohammedahmed/.codex/visualizations/2026/07/29/019fab7d-06e4-7992-ab54-759c6e70e164/pure-pets-home-final-marketplace-arabic.jpg`
  - `/Users/mohammedahmed/.codex/visualizations/2026/07/29/019fab7d-06e4-7992-ab54-759c6e70e164/pure-pets-home-final-main-kinds-arabic.jpg`
- Xcode `Product > Test` was attempted on the physical device. The test target failed before execution because its existing module search configuration cannot resolve `HXPhotoPicker`, `SDWebImage`, or `PurePetsSwiftUIRefactor`; the new focused Home tests therefore remain unexecuted.
- The scoped CodeRabbit review inspected all 12 SwiftUI Home source files and initially returned 12 findings. Eleven valid findings were fixed: listener lifecycle guards, restart cleanup, listener-driven HomeConfig delivery, robust boolean parsing, main-actor event forwarding, stable source identity, canonical main-kind IDs, and loading-state accessibility. The remaining tint suggestion was intentionally declined because the explicit accepted product requirement is a solid black paw. The post-fix scoped CodeRabbit rerun completed with zero findings.
- Live English, VoiceOver order, accessibility category 5, dark mode, increased contrast, Reduce Motion, detailed lower-feed scrolling, Instruments metrics, and leak checks remain `UNVERIFIED`.
- Launch logging still exposes existing Splash CoreGraphics `NaN` warnings, one unrelated local-Lottie “Animation Not Found” message, and transient network-path noise. Entering the existing `PPDataViewVC` category route also logs an existing conflicting 44-point/zero-height button constraint. None produced a crash, but all remain separate runtime-noise investigations.


---

# 2026-08-12 — Home zone architecture pass (supersedes the Pet Pulse presentation thesis)

Baseline commit: `18a74a63d50fcc52855bd5d46a75b830e88396ed` (branch `main`)
Production entry point: `PPHomeViewController` — **unchanged by this pass**
SwiftUI owner: `PPHomeHostingController` → `HomeStore` → `HomeView` — **preserved**

## Product-DNA supersession

The `Pet Pulse` **presentation thesis** recorded above is superseded. Its
technical, runtime-compatibility, parity, data-ownership, routing, listener,
backend, and migration-safety contracts are **not** superseded and are carried
forward unchanged.

New north star: Home is a **premium commercial and discovery surface with
intelligent personalization**. Pet context is a contextual signal, not a
territory. The giant `HomeMyPetProfileCard` territory and the pet-first
hierarchy are replaced by a compact pet-context strip inside Zone 5.

## Selected concept

Three structurally different Home architectures were scored on the twelve
required dimensions with a declared 0–5 scale (60 points maximum). No dimension
scored `0` for any concept, and the weights were fixed before scoring.

| Dimension (0–5) | A · Editorial Storefront | B · Command Console | C · Category Spine |
|---|---:|---:|---:|
| Five-second clarity | 5 | 3 | 4 |
| Marketing effectiveness | 5 | 2 | 3 |
| Commerce / discovery strength | 5 | 3 | 5 |
| Brand identity without the logo | 5 | 3 | 4 |
| Originality / anti-template | 4 | 2 | 4 |
| Native iOS behaviour | 5 | 4 | 4 |
| Arabic RTL resilience | 5 | 4 | 3 |
| AX5 / accessibility resilience | 5 | 3 | 3 |
| Dark-mode resilience | 5 | 4 | 4 |
| Performance feasibility | 4 | 4 | 3 |
| Migration safety | 5 | 3 | 3 |
| Partner ecosystem support | 5 | 2 | 3 |
| **Total** | **58/60** | **37/60** | **43/60** |

**Winner: A — Editorial Storefront.**

- Signature interaction: the Marketing Stage's keyed editorial page transition,
  where media, copy, and actions move as one page; second signature moment is
  the existing one-shot Home entrance stagger.
- Biggest risk: dependence on real campaign artwork quality. Mitigated by the
  split composition (media band above a token copy plate) plus a deterministic
  accent-field fallback for missing, low-resolution, or offline media.
- Why B lost: status-first topology reads as a dashboard, which the target
  explicitly rejects, and it demotes marketing below operational state.
- Why C lost: a permanently pinned category spine costs fixed screen height and
  subordinates the Marketing Stage to a filter, weakening commercial dominance.

Anti-template gates: five-second clarity, no-logo identity, content transplant,
grayscale hierarchy, long-Arabic and AX5 stress, one-hand reachability,
card-deletion, and novelty-tax were all applied to concept A during design.
Grayscale hierarchy and contrast are backed by the measured token audit below;
transplant resistance is structural (the stage, launcher, and gateway are
content-shaped, not decoration-shaped).

## New presentation engine

`Pure Pets/MainApp/ModrenAppVC/SwiftUIHome/Presentation/PPHomePresentationPlan.swift`

| Type | Responsibility |
|---|---|
| `PPHomeSectionRegistry` | The 20 persisted Console identifiers, declared once. |
| `PPHomePresentationLimits` | The presentation bounds (1 stage, 1 live priority, 5 launcher actions, 3 commerce rails, 1 partner feature). |
| `PPHomeZoneID` / `PPHomeZone` / `PPHomeModule` | Zone and module identity. `PPHomeModule.id == rawID`. |
| `PPHomeSuppressedModule` / `PPHomeSuppressedDestination` | Bounded-out modules mapped onto existing routes. |
| `PPHomePresentationPlan` | The complete deterministic output. |
| `PPHomePresentationResolver` | Pure `HomeViewState` → `PPHomePresentationPlan`. |

The resolver owns no fetching, listener, persistence, routing, analytics, or
business mutation. It is `Equatable`-comparable and unit-testable.

### Frozen resolver precedence

1. Hidden and unsupported modules are removed without changing raw identity.
2. Console order is preserved exactly **within** each zone; zone precedence is
   the product hierarchy (command surface → marketing → ecosystem → live
   priority → commerce/discovery).
3. Explicit backend priority metadata is **not** consulted. No `HomeConfig`
   field has a proven ranking meaning in source, and none was invented.
4. User/application state is used only for eligibility, never as a new ranking
   signal.
5. Each bounded slot takes the first eligible candidate in server order.
6. **5a.** The Live Priority slot prefers the operational order candidate over
   the care-reminder candidate; only the order is a transaction the user already
   committed to, and the reminder stays reachable through pet context.
7. Remaining eligible modules keep stable identity and original relative order.
8. Every bounded-out module is mapped to an existing reachable destination;
   anything unmappable is reported in `unmappedSuppressedModuleIDs` rather than
   silently discarded.

The partner slot adds one invariant-derived rule: when several demoted campaign
modules compete, a candidate with **no** alternative reachable destination wins,
because suppressing it would otherwise violate rule 8. Ties break by server
order. Pet context (`0`) is never presented as a partner treatment.

### Invariants held

- `isVisible == false` never renders.
- Every raw section ID and its server metadata survive at the model/config
  boundary (`HomeModelAdapter.config` is unchanged).
- Unknown future IDs land in `retainedUnknownModuleIDs`, are never rendered, and
  are never reinterpreted as another module.
- Identical input yields an identical plan (`Equatable`, asserted in tests).

## Zone map

| Zone | Modules | Component |
|---|---|---|
| 1 Command surface | pinned bar (always) + `15` | `HomeCommandBar` (unchanged) + `HomeDiscoveryPromptRow` |
| 2 Marketing stage | first eligible of `4` / `17` / `0` | `PPHomeMarketingStage` |
| 3 Ecosystem launcher | `1`, ≤ 5 actions | `PPHomeEcosystemLauncher` |
| 4 Live priority | `2`, else `0` reminder | `HomeOrderCard` (unchanged) / `PPHomeStatusCard` |
| 5 Commerce / discovery | `5`, ≤ 3 of `6·7·10·11·12·14·18·19`, demoted campaign, `20`, one of `9`/`16`, `13`, `8` | `HomeCategoryRail`, `HomeFeedSection`, `PPHomePartnerFeature`, `HomePureLensSection`, `PPHomeServiceGateway`, `HomeAdoptionSection`, `PPHomePetContextStrip` |
| 5 overflow | every suppressed module | `PPHomeExploreMoreRow` |

## Component family

New — `SwiftUIHome/Views/PPHomeZoneComponents.swift`:
`PPHomeSectionHeading`, `PPHomeMarketingStage`, `PPHomePartnerFeature`,
`PPHomeEcosystemLauncher`, `PPHomeStatusCard`, `PPHomeServiceGateway`,
`PPHomePetContextStrip`, `PPHomeExploreMoreRow`, plus `PPHomeDisclosureChip`,
`PPHomePrimaryAction`, `PPHomeQuietAction`, `PPHomePageControl`,
`PPHomeSurfacePressStyle`, `PPHomeZoneMetrics`, `PPHomeZoneTone`,
`PPHomeZoneCopy`.

Reused unchanged: `HomeCommandBar`, `HomeCategoryRail`, `HomeFeedSection`,
`HomeOrderCard`, `HomePetSwitcher`, `HomeStatusBanner`, `HomeInlineState`,
`HomeRemoteImage`, `HomeHeroField`, `HomePureLensSection`, `HomeAdoptionSection`,
`HomeUniversalCard` / `PPUniversalCardView`, and every Home motion modifier.

Removed duplicate presentations (destinations and features all preserved
elsewhere): `HomeSingleHeroSection`, `HomePromotionCarousel` and its
`PPPromoCard` adapter, `HomePremiumSearchSection` (+ button style),
`HomeProviderCategoryNavigation` (+ `HomeProviderCategory`),
`HomePremiumCareSection`. `HomeMyPetProfileCard` and `HomePriorityGrid` are no
longer rendered by Home; both remain in `HomeComponents.swift` untouched.

`HomeView.swift` went from 1878 to 1732 lines while gaining the zone engine.

## Visual system

No colour was introduced. Brand-coloured **text** now resolves through
`Color.ppAccentText` (the existing accent-text token) instead of the fill tokens
`Color.homeBrand` / `Color.homeBrandDeep`, which measured below `4.5:1` in dark
mode. `Color.homeBrand` remains a **fill** only. `Color.homeFocus` is restricted
to the status symbol, plate, and border (non-text). The page indicator uses
measured tokens and additionally encodes selection by width, so state never
depends on colour alone. Exactly one banded row exists (the care gateway), and
its eyebrow was dropped because brand text measured `4.45:1` on the dark band.

Measured token contrast, computed from the real `PPPaletteHex` values —
**26 pairs × light and dark = 52/52 pass** (text ≥ `4.5:1`, non-text ≥ `3:1`).
Lowest text pair: `4.85:1` (light band subtitle). Lowest non-text pair:
`3.58:1` (light veterinary symbol).

## Runtime and seam ledger

| Seam | Direction | Owner | Change |
|---|---|---|---|
| `PPHomeViewController` | ObjC runtime shell | itself | **Zero modifications in this pass.** Class name, `buildDataViewVCForTarget:mainKind:source:`, `mainKindsLayoutMode`, `initialSelectedMainKindID`, every `pp_home*` selector, and all `PPUniversalCellDelegate` selectors are byte-identical. |
| `PPHomeHostingController` | ObjC → SwiftUI | itself | Unchanged, including the `99182` splash-cover first-render gate. |
| `HomeStore` | SwiftUI state | itself | Unchanged. Still the only state owner, listener owner, hero-rotation owner, and observer owner. |
| `HomeRouter` | SwiftUI → UIKit | itself | Unchanged. Still the only route bridge, with its `performOnce` route-once guard. |
| `HomeRepository` / `PPHomeDataBridge` | data | themselves | Unchanged. No new listener, query, collection, or field. |
| `HomeView` | SwiftUI | itself | Presentation only: renders the plan instead of switching on raw IDs. |
| `PPHomeZoneComponents` | SwiftUI | new | Presentation only. No store, router, analytics, listener, or persistence ownership. |
| `PPHomePresentationResolver` | pure function | new | Presentation only. |

Route-once is unchanged: every navigation still flows through `HomeRouter`, and
card taps still reach `PPUniversalCellDelegate` on the shell. The only local
state the new presentation owns is `campaignIndex`, the promotion paging index,
which `HomeStore` does not publish.

Timer ownership: `HomeStore` keeps rotating its own pet-context hero pages, so
`PPHomeMarketingStage` is constructed with `autoAdvances: false` for that lane
and never starts a second timer. Promotion auto-advance is a `.task(id:)` keyed
on page, count, interaction, Reduce Motion, scene phase, and the auto-advance
flag, so it cancels on teardown and re-arms per page. Each tick additionally
re-checks VoiceOver, Switch Control, and Reduce Motion before advancing.

## Analytics

`HomeStore` contains no `Analytics.logEvent` call and no impression tracking;
the only analytics owner in Home is `HomeRouter`'s Pure Lens allow-list. This
pass adds no event, parameter, PII, consent state, or tracking field, so
analytics parity is structural: there is nothing to duplicate. The existing
`os_signpost` `home.reload` / `home.section.reload` telemetry and the
`sectionDataRevisions` mechanism are unchanged, and the renderer still feeds
`sectionDataRevision(for:)` per raw ID.

## Localization

Ten new keys were **appended** to both `ar.lproj` and `en.lproj`
(`home_marketing_promotion_disclosure`, `home_marketing_stage_page_a11y`,
`home_marketing_stage_next`, `home_marketing_stage_previous`,
`home_partner_feature_title`, `home_ecosystem_launcher_title`,
`home_ecosystem_launcher_subtitle`, `home_live_priority_title`,
`home_zone_explore_more_title`, `home_zone_explore_more_subtitle`). All 45
literal keys referenced by the new presentation resolve in both languages.

## Tests

`Pure PetsTests/PPHomePresentationResolverTests.swift` — 25 tests covering
determinism, raw-identity preservation, hidden IDs, duplicate IDs, unknown IDs,
empty config, stage arbitration and reordering, missing campaign, missing pet,
partner bound and reachability preference, live-priority bound and order
preference, missing order, launcher bound, missing rail, single care gateway,
Pure Lens visibility, no-pet, signed-out, the no-silent-discard invariant, the
command-surface prompt, and zone order stability.

**`BLOCKED` — the tests cannot be executed.** `build-for-testing` on the
connected device fails inside the pre-existing `Pure PetsTests` target:

```
PPRootParityTests.swift:11: error: unable to resolve module dependency: 'PurePetsSwiftUIRefactor'
error: compilation search paths unable to resolve module dependency: 'HXPhotoPicker'
error: unable to resolve module dependency: 'SDWebImage'
Pure Pets-Bridging-Header.h:16 -> PPCompleteProfileVC.h:10:
  fatal error: 'TOCropViewController/TOCropViewController.h' file not found
```

Root cause, confirmed in source: `Podfile` declares only `target 'Pure Pets'`,
so CocoaPods never generates a `Pure PetsTests` xcconfig and the test target has
no Pod search paths. No error references the new test file. The minimal repair is
a `Podfile` change plus `pod install`:

```ruby
target 'Pure PetsTests' do
  inherit! :search_paths
end
```

That is a workspace-wide dependency change outside this pass's scope and was not
performed.

## Verification record

| Gate | Command / method | Result |
|---|---|---|
| Syntax | `xcrun swiftc -frontend -parse` on all 4 changed/new Swift files | pass |
| Localization | `plutil -lint` on both `Localizable.strings` | OK |
| Key parity | 45 referenced keys resolved in `ar` + `en` | 45/45 |
| Project file | `plutil -lint "Pure Pets.xcodeproj/project.pbxproj"` | OK |
| Whitespace | `git diff --check` | clean |
| Device build | `xcodebuild -workspace "Pure Pets.xcworkspace" -scheme "Pure Pets" -configuration Debug -destination "id=4A693B80-A35D-51F8-BE4B-027200738B05" -allowProvisioningUpdates build` (default DerivedData) | `** BUILD SUCCEEDED **`, 0 errors |
| Install | `xcrun devicectl device install app` | installed, `com.PB.Pure-Bird` |
| Launch | `xcrun devicectl device process launch --terminate-existing` | launched |
| Launch stability | `xcrun devicectl device info processes` after 20 s | process alive, no launch crash |
| Contrast | computed WCAG ratios from real `PPPaletteHex` values | 52/52 pairs pass |
| Hit targets | source audit of every new interactive control | all ≥ 44 pt |

Device: iPhone 13 Pro Max, `iPhone14,3`, iOS 26.5.2, identifier
`4A693B80-A35D-51F8-BE4B-027200738B05`.
Products: `~/Library/Developer/Xcode/DerivedData/Pure_Pets-gfwbkroryubthqewjpxxbonnzisq/Build/Products/Debug-iphoneos/Pure Pets.app`.
App binary SHA-256: `f935aa44e57e368d0ab5f51cc75a6ef20a34c7a2558153850852c5256b1de47f`.
Build logs: `/tmp/pp_home_build1.log`, `/tmp/pp_home_build2.log`,
`/tmp/pp_home_build3.log`, `/tmp/pp_home_test_build.log`.

## `BLOCKED` / `UNVERIFIED`

| Gate | Status | Reason |
|---|---|---|
| Executed resolver / routing / lifecycle tests | `BLOCKED` | Pre-existing `Pure PetsTests` target has no CocoaPods search paths (see above). |
| Rendered visual matrix (RTL/LTR × light/dark × normal/AX5 × compact/regular × populated/loading/partial/error/empty) | `UNVERIFIED` | No physical-device screenshot capability is reachable in this host: `devicectl` has no screenshot subcommand, `libimobiledevice`/`idevicescreenshot` is not installed, `simctl` is simulator-only and simulators are prohibited, and XCUITest capture depends on the blocked test target. Nothing was rendered, so nothing is claimed. |
| Baseline vs candidate visual comparison | `UNVERIFIED` | Same missing capability; no baseline capture was possible. |
| VoiceOver reading order, custom actions, announcements, focus restoration | `UNVERIFIED` | Requires a live assistive-technology session on device. The stage now carries the disclosure on a combined focusable element rather than a container label to reduce this risk, but that is construction, not proof. |
| Dynamic Type AX5, Bold Text, Button Shapes, Differentiate Without Color, Increased Contrast, Reduce Transparency runtime behaviour | `UNVERIFIED` | All are handled in source; none observed on device. |
| Performance baseline vs candidate (first meaningful Home content, hitching, CPU, memory peak, image/cache pressure, long SwiftUI updates, listeners, cancellation, teardown) | `UNVERIFIED` | No Instruments or XCTest-metrics run was performed; no threshold was declared before measurement, so no performance claim is made. |
| Live route-once proof (one tap → exactly one destination) | `UNVERIFIED` | `HomeRouter.performOnce` and single-owner routing are preserved by construction and by diff, but no runtime route spy was executed. |
| Genuine sponsored/partner attribution | `BLOCKED` | `PPHomePromoCarouselCard` has no `sponsored`, `advertiser`, or `partnerName` field, and `HomeConfig` metadata carries none. A sponsorship claim would be fabricated. The implemented disclosure is the factual, non-attributive `home_marketing_promotion_disclosure` ("عرض ترويجي" / "Promotion"). A true partner attribution requires an Infra field. |
| Contrast under Increased Contrast and against server-provided campaign accent hex | `UNVERIFIED` | Measured pairs cover the semantic tokens only. Server `accentColorHex` is arbitrary, so it is confined to fields, borders, and media backdrops and never carries text or state; the page indicator was moved off it for this reason. |

Historical device screenshots recorded earlier in this ledger predate this pass
and are not evidence for it.


## 2026-08-12 addendum — command surface consolidation and stage artwork

Three follow-up directives were applied on top of the zone pass.

### 1. The Home search section is gone; its design became the top search bar

Raw section `15` (`PPHomeSectionPremiumSearch`) no longer renders a separate Home
row. It now resolves to `PPHomeSearchProminence`, read off the plan through
`PPHomePresentationPlan.searchProminence`, and upgrades the pinned command
surface instead:

| Console state | Command surface |
|---|---|
| `15` visible, `titleViewMode == "location"` | Two lanes: location + cart, then the full-width search field + Nova |
| `15` visible, `titleViewMode == "search"` | One lane: search field + Nova + cart |
| `15` hidden | One lane: location + compact search + Nova + cart |

The Console visibility contract is therefore still honoured — a hidden module
still changes what renders — while Home no longer shows two search affordances.
`HomeDiscoveryPromptRow` was deleted. `PPHomeModuleKind.discoveryPrompt` is
retained so raw `15` stays accounted for by the resolver invariants and the
existing tests, and `moduleView` maps it to `EmptyView()` because the bar owns
it. The resolver's precedence, bounds, and suppression logic are unchanged.

### 2. One command-surface vocabulary

`HomeCommandBar` previously mixed a two-tone `searchGlyph` plate, a
gradient-stroked `searchSurface`, a plain circular magnifier, an inner-plate
location card, and a circular cart on a different surface token. All five now
share one vocabulary:

- Lanes (location, search): `PPCorner.card`, `Color.homeSurface`, one
  brand-tinted border rule, `resolvedSearchControlHeight`, an accent leading
  symbol, and a semantic-trailing chevron. The location lane uses the same
  pattern as search, with `chevron.down` because it opens a picker.
- Icon controls (compact search, Nova, cart): a single 52 pt `PPCorner.medium`
  squircle on `Color.homeSurface` with the same border rule.
- Press feedback: `HomeSearchButtonStyle` on every control, replacing the
  mixed `.plain` / styled usage.

Cart redesign: the glyph is deliberately neutral `Color.ppTextPrimary`, so brand
colour is spent only on the count badge — the one meaningful priority signal in
the bar. The badge keeps its `Color.ppPrimary` capsule and white label
(`5.32:1`) and is stroked against `Color.homeSurface`. `accessibilityLabel` and
`accessibilityValue` are unchanged, so the count is never conveyed by the badge
alone. `searchGlyph` and `searchSurface` were removed.

Nova moved into the command surface and adopted the same squircle, surface, and
border, keeping its existing sparkle motion and Reduce Motion behaviour. Its
visibility still follows `novaFloatingVisible` only, so hiding raw `15` does not
remove the Nova entry point.

Contrast: every new pair reuses tokens already measured in the audit above —
`ppAccentText` on `homeSurface` (`5.32:1` light / `5.24:1` dark),
`ppTextPrimary` on `homeSurface` (`16.20` / `17.70`), `ppTextSecondary` on
`homeSurface` (`5.43` / `9.29`), white on `ppPrimary` (`5.32`), and
`ppAdoptionAccent` on `homeSurface` (`4.58` / `6.14`, non-text). No new pair was
introduced.

### 3. Marketing Stage artwork uses the production hero Lottie assets

The stage's no-media placeholder was an SF Symbol. It is now
`PPHomeStageArtwork`, which renders the **same animation files** the production
`HomeHeroView` resolves, through the same existing `PPHomeHeroAnimationView`
Objective-C Lottie runtime, on the same accent→`ppSurfaceRaised` plate those
tints were authored against:

| Hero kind | Animation | Source |
|---|---|---|
| `pet` | `Profile.lottie` | Firebase-backed |
| `reminder` | `Caretiming` | Firebase-backed |
| `promotion` | `HomePromotionSpark` | bundled |
| `marketplace` | `Shop2.json` | bundled |
| `petOnboarding` | `LottieAnimations/Boy Giving Food To Rabbit New.json` | Firebase-backed |
| `pharmacy` | `PetMedicine` | bundled |

Per-animation scale and tint follow the legacy `lottieScale` / `lottieTintColor`
rules verbatim. Reduce Motion keeps the artwork and sets
`playbackEnabled: false`, matching the legacy hero instead of substituting a
different image. No new asset, no second animation dependency, and no Firebase
path was introduced. The three bundled files plus `Profile.lottie` were
confirmed present in the built `Pure Pets.app`; `Caretiming` and the onboarding
animation resolve remotely exactly as they already do in the legacy hero.

Note: the ledger's earlier `HomePetPulse.json` / `HomeCareReminder.json` /
`petstore` description of the hero plate does not match current source. The
mapping above is what `HomeHeroView.heroArtworkAsset(for:)` actually returns.

### Addendum verification

| Gate | Result |
|---|---|
| `swiftc -frontend -parse` on 5 changed/new Swift files | pass |
| `plutil -lint` on both strings files and `project.pbxproj` | OK |
| `git diff --check` | clean |
| Device build | `** BUILD SUCCEEDED **`, 0 errors (`/tmp/pp_home_build7.log`) |
| Install + launch on iPhone 13 Pro Max | succeeded |
| Launch stability | process alive 22 s after launch |
| Bundled Lottie presence | `HomePromotionSpark.json`, `Shop2.json`, `PetMedicine.json`, `Profile.lottie` all present in the built app |

App binary SHA-256: `8d0f748f9d10527c72cb094f44a0c393e355ac0f30a2f8b952cf4c39042a1f7e`.

The visual, VoiceOver, Dynamic Type, performance, and executed-test gates listed
as `BLOCKED` / `UNVERIFIED` above remain unchanged — the addendum adds no
rendered, assistive-technology, or measured evidence. In particular the stacked
two-lane command surface (~104 pt pinned when raw `15` is visible) and the new
Lottie artwork have **not** been visually inspected on device.


## 2026-08-12 addendum 2 — reversible presentation switches

Three further directives were applied. All three are expressed as documented
booleans in one place, `PPHomePresentationFlags`, so each is a one-line revert
and none deletes a module, route, Console contract, or asset.

```swift
enum PPHomePresentationFlags {
    static let temporarilyHidesSearchLane = true
    static let hidesNovaInCommandSurface = true
    static let launcherExcludedActionIDs: Set<String> = ["pet"]
}
```

### Search lane hidden (temporary)

`PPHomePresentationPlan.searchProminence` is pinned to `.compact`, so the command
surface stays on its single lane and the dedicated search lane is not rendered.
Raw section `15` is still resolved and still satisfies the resolver invariants;
search remains reachable from the command bar's compact control. When
`titleViewMode == "search"` the search field is the title view itself, not a
section, so that server mode is unaffected.

### Nova hidden from the command surface

`HomeCommandBar.showsNova` now also requires
`!PPHomePresentationFlags.hidesNovaInCommandSurface`.

Nova itself is untouched, and this does **not** remove its only entry point:
`NovaAmbientAssistantCoordinator.openNovaChat()` (`MainApp/GEMENI/`) and the root
`PPRootObjCAdapter.handleOpenNovaChat()` path are both intact, and
`HomeRouter.openNova()` remains wired. The `novaFloatingVisible` Console flag is
still honoured and still gates Nova when the switch is turned back off.

### Ecosystem launcher: `my pet` removed, remaining four redesigned

`PPHomePresentationResolver.ecosystemLauncherActions` filters
`launcherExcludedActionIDs` before applying the bound, preserving configured
order for everything else. The pet destination stays reachable through raw
section `8` (`PPHomePetContextStrip` → pet profiles), through `HomePetSwitcher`'s
Edit action, and through the suppression map's `.petProfiles` entry — so the
exclusion is presentation only.

The launcher was redesigned for four items rather than five: a two-column grid of
horizontal cells, each rendering the action's **real `subtitle`**, which the
previous five-across row had no width to show. Icon plate 44 pt, cell minimum
72 pt, `PPCorner.card` on `Color.homeSurface` with one accent-tinted border rule;
one column at accessibility sizes. Density stays lighter than
`PPHomeServiceGateway` (horizontal, single surface) so the two components share a
vocabulary without reading as the same block twice.

Contrast introduces no new pair: title `ppTextPrimary` on `homeSurface`
(`16.20` / `17.70`), subtitle `ppTextSecondary` on `homeSurface` (`5.43` /
`9.29`), and the icon accents were already measured at `4.32`–`6.99` against the
3:1 non-text bar.

Tests: `testEcosystemLauncherNeverExceedsFiveActions` became
`testEcosystemLauncherNeverExceedsItsBound` and now derives its expectation from
the exclusion set instead of hardcoding `pet`. A new
`testLauncherExcludedDestinationsStayReachableElsewhere` asserts that every
excluded destination is absent from the launcher **and** that the pet context
module still presents it. Both remain unexecuted for the reason recorded above.

### Addendum 2 verification

| Gate | Result |
|---|---|
| `swiftc -frontend -parse` on all changed Swift files | pass |
| `plutil -lint` strings + `project.pbxproj` | OK |
| `git diff --check` | clean |
| Device build | `** BUILD SUCCEEDED **`, 0 errors (`/tmp/pp_home_build9.log`) |
| Install + launch on iPhone 13 Pro Max | succeeded |
| Launch stability | process alive 22 s after launch |

App binary SHA-256: `5ef8d9473dd2c83d7642680e1b4287c4b695a35a52e4f45bd2a8a7c760373a42`.

The redesigned launcher, the single-lane command surface, and the Nova removal
have **not** been visually inspected on device; the visual, VoiceOver, Dynamic
Type, performance, and executed-test gates remain `BLOCKED` / `UNVERIFIED` as
recorded above.
