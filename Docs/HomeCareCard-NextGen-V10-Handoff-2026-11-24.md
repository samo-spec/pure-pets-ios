# Home Care Card — NextGen V10 handoff

## Scope
Consumer iOS Home Care gateway only. Existing SwiftUI component: `Pure Pets/MainApp/ModrenAppVC/SwiftUIHome/Views/PPHomeZoneComponents.swift` (`PPHomePetCareCard`, `PPHomeCareOrbit`). No backend, router, localization file, dependency, or unrelated screen changes.

## Design decisions
- Replaced photo banner and separate tinted strip with a single existing deep-green Care field, readable title and explicit exploration affordance.
- Native heart-and-paw orbital illustration; decorative only, never a clinical signal. Bounded 350 ms reveal, no continuous timer or animation loop. Existing whole-card press feedback respects Reduce Motion.
- Service labels remain descriptive, not fake independent routes. Accessibility sizes use a localized service summary and release illustration space. Existing Beiruti typography, logical direction, spacing and card surface primitives are retained.
- Existing single open callback, accessibility identifier `home.petCare`, selected-category context, and `HomeView -> HomeStore.openProviderCategory("veterinarians") -> HomeRouter.openVeterinaryCare` remain unchanged.

## Verification evidence
- New `scripts/home_care_gateway_static_test.py`: baseline redesign check failed; after implementation both source-contract tests passed.
- `xcrun swiftc -frontend -parse` passed for the changed source; syntax only, not type-check/build proof.
- `git diff --check` passed for the tracked component.
- Existing Arabic and English keys for the summary, action and all three services verified.
- Source SHA-256: `29cf59a69fada37451ad3eb464b699b4fc63ee6198e46be4c162698dd530116d`.

## Outstanding gates
No physical-device build, runtime navigation check, visual capture, dark mode/RTL/AX5 runtime check or independent V10 tool certification was performed. The local V10 guidance was read, but its complete executable invention/proof pipeline was not run. Status: source implementation complete; runtime/visual certification unverified. No deployment, git push, or production writes.

## Rollback
Review and reverse only the care-card hunk plus the new test and this handoff if requested. Preserve unrelated working-tree changes.
