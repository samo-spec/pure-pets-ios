# Veterinarian and clinic details — NextGen V7

> Superseded for composition and localization by [VetConsultationFolioV7.md](VetConsultationFolioV7.md), following the 10:33 screenshot. Validation below records the earlier iteration.

Date: 2026-10-19. Consumer iOS baseline HEAD: `7d3ad3c7419a107ed6320eb48e4562890eda7f93`.
Scope: both detail compositions in SwiftUI, the Doctors/Clinics partition, and their presentation/action boundaries. The user explicitly requested NextGen V7 and static-only validation. No build, type-check, link, XCTest execution, install, device launch, deployment, or production mutation was performed.

## Decision and integration

The selected direction is **Care Introduction**: identity first, then care scope, practical information, and contact. The veterinarian introduction pairs a portrait with the person's name; the clinic introduction presents a contained logo above the name on compact screens and beside it on wider screens. Continuous sections replace the former badge/bento composition. The alternative, a contact-first directory, was rejected because contact and fees competed with identity and weakened the person/place distinction.

The V7 portfolio, synthesis and implementation-plan checks returned `readyForImplementation: true`. This is advisory structural/design evidence, not rendered or runtime certification. An independent reviewer completed the two-concept comparison. Its subsequent implementation review failed because of a service usage limit; independent review of the final implementation remains **UNVERIFIED**. The implementing agent completed the source review and V7 lexical audit.

Existing ownership is retained:

- `PPPetCareViewController` owns directory reads, filters, search, navigation and recovery.
- `PPPetCareVetViewrVC` owns the selected model, close/back, phone, WhatsApp and sharing.
- `PPVetViewerPresentation` owns the immutable display snapshot.
- `PPVetViewerScreen` owns presentation and local biography disclosure only.
- `AppRemoteImage` remains the sole image/cache/retry/lifecycle owner.

No Firebase collection, rule, permission, query, function, dependency or provider write contract was added or changed. The previously inspected Infra veterinarian public-read contract remains authoritative. No paid membership is used as professional verification. Pending, rejected, disabled, blocked and deleted records retain the existing directory exclusion; detail actions also use the same allowed statuses and model moderation state.

## Root cause and correction

The Doctors projection still accepted every approved provider from the shared directory, so clinic records also appeared in Doctors. Doctors now requires `VetTypePersonal`; Clinics requires `VetTypeCompany`. Identity is a tab constraint, not a removable filter. Both tabs retain independent search and contact filters, shared animal filtering, the existing single directory loader, loading/error/retained-result recovery, and numeric/string legacy type normalization. Redundant Doctors/Clinics type-filter menu entries were removed. A contact-ready filter now requires a usable contact number rather than a readiness flag alone.

The former detail view also inferred free consultation from missing/zero fees, certification from approval/subscription, and instant response/24-hour emergency services without supporting fields. Those claims are removed. Positive finite fees use locale-aware QAR formatting; absent/zero/invalid fees ask the user to confirm with the provider. Availability is labeled as a date listed in the profile, not opening hours. Membership is explicitly a Pure Pets membership. Only an explicit `verified` status displays a verified-profile label.

## Native, language and interaction contract

- Arabic and English have 41 paired new keys; four existing Doctors strings were corrected. All new user-facing copy uses `Language`.
- Leading/trailing layout follows app language. Phone values are normalized from Arabic/Persian/ASCII decimal digits and rendered in a scoped LTR region. Shared phone copy includes directional isolates. Taxonomy-backed species names follow the current language; numeric IDs are never displayed as species.
- One-column compact layouts expand to a wider introduction and two content columns when space permits. Accessibility sizes and short viewports move contact actions inline in the scroll view. Standard layouts use measured safe-area insets instead of a fixed bottom spacer.
- Text scales with Dynamic Type, names and factual values wrap, biography can expand, and accessibility sizes show its full text. Navigation targets are 48 points and contact controls have at least 52-point content height.
- Semantic PP colors support light/dark appearance. Opaque action surfaces also work with Reduce Transparency. Press feedback is bounded, interruptible and non-blocking; Reduce Motion removes scale and animation. There are no ambient or repeating animations.
- The UIKit controller refreshes presentation after language/taxonomy notifications and on appearance, removes observers on deallocation, and keeps weak action callbacks.
- Existing image loading provides bounded retry and cancellation. Missing/invalid image URLs have an authored placeholder. Missing biography, species, fee and contact details have explicit copy. Unavailable profiles have a return-to-directory state with contact/share disabled.
- Phone and WhatsApp visibility use the same normalization helper as UIKit actions. WhatsApp removes `+`/`00`; local-only numbers stay callable, but never gain a guessed country code. Duplicate external launches are guarded; failure uses the existing localized alert helper. Phone values remain selectable for recovery. Sharing is localized and popover-safe.

## Files in this follow-up

- `Pure Pets/MainApp/ModrenAppVC/PetCare/PPVetViewerScreen.swift`: distinct layouts, truthful snapshot, adaptive states, semantic layout and motion.
- `Pure Pets/MainApp/ModrenAppVC/PetCare/PPVetViewerHostingController.swift`: additive content fields, shared Objective-C-visible contact routing, initial language semantics.
- `Pure Pets/MainApp/ModrenAppVC/PetCare/PPPetCareVetViewrVC.m`: taxonomy/localization refresh, contact failure handling and localized share.
- `Pure Pets/MainApp/ModrenAppVC/PetCare/PPPetCareViewController.m`: exclusive provider projections and contact filter/menu correction.
- Both `Localizable.strings` files: 41 new keys and four amended directory strings.
- `Pure PetsTests/PPVetViewerTests.swift`: nine new regression cases for contact parsing/routes, moderation, fees, verification, partial data and image URL validation.
- `Pure PetsTests/Pure_PetsTests.m`: existing clinic assertions updated; two regression cases added for legacy doctor encodings/moderation and valid contact filtering.
- `Pure Pets.xcodeproj/project.pbxproj`: four additive test membership lines only. Pre-existing version/build changes are unrelated and preserved.
- `AuditReports/PetCareClinicsIntegration.md`: original combined-directory statement superseded by the explicit follow-up request.

## Verification

- **PASS**: Swift frontend parse-only check of the screen, bridge and new Swift test file. This validates grammar, not SDK typing, Objective-C bridge generation, linking or behavior.
- **PASS**: `plutil -lint` on both localization files and the project file.
- **PASS**: `git diff --check`.
- **PASS**: 149 focused static assertions, including per-language key uniqueness and format parity, selector alignment, exclusive type projections, truthful data rendering, contact routing, locale/direction wiring, adaptive action branches, lifecycle cleanup and test membership.
- **REVIEWED, STATIC_HINT**: V7 source audit found no Objective-C hints and one SwiftUI hint for the single-argument `onChange`. The existing iOS 15-compatible signature is deliberately retained; the recommended replacement requires iOS 17. This is a deployment compatibility choice, not a known runtime defect.
- **UNVERIFIED**: the nine new Swift and two new Objective-C tests and updated clinic assertions; they were authored but not executed.
- **UNVERIFIED**: build/type checking, rendered Arabic/English, iPhone/iPad geometry, VoiceOver, AX5, focus, Reduce Motion, external app launches, live directory data/cache behavior and performance.

No critical/high-severity issue remains identified by the completed source review. This does not certify production readiness. The remaining acceptance evidence is the separately authorized physical iPhone 13 Pro Max workflow with Xcode default DerivedData, plus a completed independent implementation review. Static-only authorization does not permit alternate simulator/Mac/Catalyst/test builds.
