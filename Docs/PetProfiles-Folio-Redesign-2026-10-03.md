# Pet profiles folio — 2026-10-03

## Scope and authority

The user confirmed the pictured **consumer iOS pet-profiles screen** for iPhone and iPad. The Admin app is not the target. The existing SwiftUI list stays inside its UIKit controller; no architecture migration.

Owners:
- `PPPetProfilesSwiftUI.swift`: presentation, local browsing selection, responsive composition.
- `PPPetProfilesHostingControllers.swift`: existing Objective-C/SwiftUI bridge.
- `PPPetProfilesViewController.m`: existing navigation, fetching, mutation callbacks, and confirmations.
- `PurePets-DesignSystem.swift`: semantic colors; existing Beiruti type primitives retained.
- Infra `firestore.rules`, `UsersCol/{userID}/petProfiles/{petID}`: unchanged backend authority.

## Design decision

Baseline screenshot: a single oversized card repeated the screen title, identity, counters, and global actions. A single pet on iPad also left an unused neighboring roster column. The photo, pet identity, and actual care record are the useful content.

Three structurally different directions were considered:
1. Portrait gallery: strongest simultaneous photo browsing, weaker single-pet care and action hierarchy.
2. Continuous editorial list: direct editing for each pet, but repeats care/action blocks and provides no focused iPad workspace.
3. Selected pet folio: compact pet selector with one open identity/care record; selected for meaningful single-pet and multi-pet layouts.

The selected direction received an independent source/behavior review. This is a design decision and implementation review, not a rendered quality certification.

## Implemented behavior

- Local selected identity is separate from the server-backed default pet. Initial selection resolves to default/first, survives data and image updates, and falls back safely after deletion.
- iPhone uses a measured horizontal selector for multiple pets, portrait/identity, read-only vaccination preview, and an explicit Edit profile action.
- Accessibility text sizes stack identity and selectors vertically without fixed content heights.
- Available content width at least 820 points enables a 240-point pet sidebar when there are multiple pets. A single pet at width 860 or greater uses a full-width identity/care spread.
- Up to three saved vaccination records are previewed; remaining count leads users to the existing editor. Due dates are shown only when present; no health, overdue, or completion status is invented.
- Reminders are explicitly global. Add, edit, confirmed deletion, make-default, and back preserve existing controller routes.
- Visible menus retain refresh/default/delete access; actions do not depend on unsupported swipe behavior inside a ScrollView.
- Pull-to-refresh now awaits actual controller completion, including coalesced requests. Pending completions are cleared before invocation and released on departure or deallocation.
- Loading, empty/add, initial error/retry, and retained-content refresh failures preserve existing data behavior.

## Localization and accessibility

Paired Arabic and English folio copy uses the current app localization system. Root language, locale, and semantic direction follow `Language`; leading/trailing placement and multiline alignment follow that environment. Date display follows the root locale. Portraits are decorative within labeled buttons. Native selected traits distinguish browsing selection from the saved default badge. Menus have pet-specific labels, and editor entry points have explicit hints.

Controls use at least 48-point toolbar/menu targets, 54-point edit targets, and intrinsic content expansion. Semantic light/dark colors, stronger increased-contrast outlines, opaque content surfaces, and the existing Reduce Motion-aware press style are retained. No repeating ornamental motion, blur, or delayed entrance sequence was added to this list.

## Data issue observed in the screenshot

The displayed 643 years and 11 months is derived by the existing model directly from `ageInMonths` (7727 months would produce that text). This was not a calendar/layout defect. No production document was read or changed. Infra currently provides no applicable maximum age rule, so the redesign does not fabricate an age, hide the value, or introduce an arbitrary species limit. Correcting this record requires its actual age.

## Verification

Passed:
- Swift frontend syntax parsing for list, hosting controller, and existing shared editor.
- Both localization files pass `plutil -lint`.
- Folio-key coverage, duplicate detection, Arabic/English key parity, and format-placeholder parity.
- Scoped `git diff --check`.
- Independent source review of layout decisions, action preservation, local/default selection separation, and exactly-once refresh continuation ownership. No concrete blocking finding remained in that review.

UNVERIFIED:
- Native type checking/build; no build authorization was given.
- Actual iPhone/iPad renders in Arabic/English, dark/light, compact/split windows, and AX5.
- Runtime VoiceOver focus order, Reduce Motion behavior, scroll/refresh interruption, and frame pacing.

No Firebase rules, permissions, schema, live documents, deployments, or global navigation were changed. Unrelated dirty work, including payment localization additions and Pure Lens changes, was preserved.

## Next native acceptance pass

Use the approved physical-device workflow when authorized. Exercise one and several pets; select a non-default pet; change default; delete the selected pet with confirmation; refresh with success and failure; leave during refresh; verify cached images and details after returning from edit. Inspect Arabic/English, long mixed-script names, AX5, dark mode, and narrow/regular iPad widths. Source validation does not certify these runtime gates.
