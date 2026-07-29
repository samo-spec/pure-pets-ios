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

The final hero treatment was evaluated separately after the live Pure Pets Pro
reference was opened:

| Hero treatment | Reference fidelity | Product DNA | Five-second clarity | Arabic / RTL | Accessibility | Motion restraint | Performance | Migration safety | Total | Decision |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Pro provider glass field + Home floating plate | 5 | 5 | 5 | 5 | 4 | 5 | 4 | 5 | 38/40 | Selected; it carries the exact Pro visual rhythm without copying Pro state or actions. |
| Semantic pet line-art field | 2 | 5 | 4 | 5 | 5 | 4 | 5 | 5 | 35/40 | Rejected; strong Pure Pets meaning, but weak fidelity to the requested live reference. |
| Plain elevated surface + context route | 2 | 4 | 5 | 5 | 5 | 5 | 5 | 5 | 36/40 | Rejected; disciplined, but loses the requested depth and animated middle-card signature. |

The selected field is adapted from
`PurePetsPro/AdminCore/Auth/PPProLoginSurfaceController.swift`:
`providerStrip(compact:)`, `providerCardBackground(compact:)`,
`providerLightSweep`, and `providerCardStroke`. Only presentation and motion
were copied. Consumer Home state, analytics, navigation, hero timing, and data
ownership remain independent.

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
| Legacy root creation | `NewAppVC` creates `PPHomeViewController` | Unchanged. |
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
| Section identity/order | Diffable UIKit snapshot | Stable SwiftUI `HomeSectionID` values | Console order is mapped and duplicates are consolidated. |
| Navigation | `PPHomeViewController` | Existing UIKit navigation through thin shell | Shell forwards only; no SwiftUI navigation fork. |
| Card mutations | Universal cell delegate on controller | Existing delegate selectors on thin shell | Business services remain unchanged. |
| Root dock | `PPRootTabBarController` | `PPRootTabBarController` | Never duplicated by Home. |

## Migration and validation boundaries

- The app deployment target remains iOS 15.
- iOS 16+ uses the existing SwiftUI universal card renderer; iOS 15 receives a native SwiftUI compatibility card with the same routes and stock states.
- No backend schema, Firebase rule, permission, provider, inventory, or analytics collection contract is changed.
- No simulator is an accepted runtime proof target.
- Shell `xcodebuild` is prohibited by repository policy.
- Static parse, localization, project-graph, diff, and ownership audits precede the connected-device run.
- A successful app build, install, and launch proves the production target reaches the connected iPhone 13 Pro Max; visual fidelity, interaction flows, accessibility modes, and performance remain separate evidence requirements.

## Final Home visual alignment

- The pinned command surface now contains only the real search and cart controls. Search occupies the full semantic-leading lane up to the cart; the location workflow remains wired but its pill is temporarily hidden behind `HomePresentationFlags.showsLocationContextPill`.
- `HomeTopFadeBackdrop` extends the command material through the top safe area and fades it out below the bar. It is noninteractive and accessibility-hidden.
- The Pet Pulse hero's normal baseline height is 296 points instead of 326. Pagination owns a reserved bottom strip, so it no longer overlaps either action.
- The primary hero action is content-fitting at normal Dynamic Type, keeps a full-width accessibility fallback, uses a 17-point continuous corner, and reserves deliberate label-to-arrow spacing without truncating the observed Arabic copy.
- Hero headlines use concise three-to-four-word Arabic and English copy in one equal 42-point title slot at standard text sizes. Dynamic promotion/reminder titles are presentation-clamped to four words while their complete value remains available to accessibility; Accessibility Dynamic Type receives a reserved two-line slot.
- The hero backdrop now uses the exact Pure Pets Pro provider-card composition: a three-stop elevated-surface/accent/elevated-surface field, two asymmetric blurred circles, and a narrow diagonal light sweep. The 5.8-second ambient cycle uses transforms and opacity only; Reduce Motion freezes the field and Increased Contrast removes the decorative sweep.
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
- iOS 16+ Home cards have one navigation owner. `HomeUniversalHostingCard` leaves the legacy `onTap` closure unset and routes the card through `PPUniversalCellDelegate`, preventing the previous closure-plus-delegate double push while preserving favorite, cart, quantity, save, video, report, and context actions. The iOS 15 compatibility card retains its SwiftUI closure fallback.
- Loaded Home content enters once per Home lifetime. The hero, pet selector, and priority actions use small 60/100/120-millisecond staging with one damped spring; refreshes do not replay the entrance. Reduce Motion removes travel and stagger and retains only a short fade. Search and pinned command controls never move.

## Validation record

- Final Swift and compatibility sources pass `swiftc -frontend -parse`, including the existing `PPMainKindsCell.swift` and focused Home migration tests.
- `project.pbxproj` and both localization files pass `plutil -lint`; the three generated Lottie JSON files and the existing `pawprint4` asset manifest pass `jq empty`; `git diff --check` is clean.
- The SwiftyUI-MAX package integrity gate passes all 26 required files. Its scoped static audit scans all 12 Home Swift/Objective-C sources with zero findings.
- Swift references 98 unique `home_pulse_*` keys; Arabic and English each define the same 98-key set.
- Xcode GUI previously built, installed, and launched the production `Pure Pets` scheme on the connected physical iPhone 13 Pro Max (`iPhone14,3`, iOS 26.5.2).
- The Arabic RTL Home was observed live after the first-render cover faded. The safe-area fade, hidden location pill, semantic-leading search geometry, compact non-clipping CTA, black `pawprint4`, cached Marketplace `petstore` Lottie, hero swiping, real `PPMainKindsCell` selection, horizontal universal-card scrolling, category route, and back navigation were exercised before the final Pro-field and 12%-peek refinement.
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
