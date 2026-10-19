# Veterinarian and clinic discovery cells — NextGen V7

Date: 2026-10-19
Scope: Pure Pets consumer iOS, the cells inside the Doctors and Clinics directory tabs.
Execution: static validation only, as explicitly requested. No build, typecheck, install, device launch, deployment or XCTest execution was performed.

## Direction and preserved behavior

The supplied 12:58 screenshot is the baseline. The old shared cell combined a small image, unsupported accreditation copy, a pulse that suggested live availability, a fee capsule and nested action buttons. A fixed collection height constrained both provider types and accessibility text.

NextGen V7 compared two concepts with an independent reviewer:
- Selected: Practitioner note / Practice placard. Veterinarians prioritize the individual introduction and care scope; clinics prioritize the practice name, city, address and listed hours.
- Rejected: Photo atlas / Contact drawer. Unknown image quality would dominate the identity and essential contact/comparison facts would require extra disclosure.

The refined portfolio, synthesis and implementation-plan tools returned readyForImplementation=true. That is design-to-code readiness, not target certification.

The two compositions share factual primitives and contact actions, not their information layout. Provider images are contained because the source exposes a generic logoURL, without guaranteeing a portrait or exterior. Both compositions retain Details, Call and WhatsApp, and information-region taps still open details. UIKit selection/highlighting is disabled only for provider cells so it cannot also trigger Details from a contact tap. Medicine selection remains owned by its existing path.

## Implementation

- PPVetCardView.swift: separate PPVeterinarianDiscoveryCard and PPClinicDiscoveryCard; Beiruti typography, semantic PP colors, stable contained image slots, wrapping care scope, truthful fee display, independent contact controls, provider-specific accessibility labels and bounded press feedback.
- PPVetCardSnapshot reuses PPVetViewerSnapshot for fee, verification, image URL validation, moderation and contact eligibility. Existing city/address/hours/emergency/home-visit fields remain represented. A phone number or membership cannot produce an online/accredited claim; missing/invalid/zero fees remain an enquiry because the model cannot distinguish a confirmed free fee from absence.
- Species names resolve against the existing cached taxonomy, including Arabic numeric identifiers and supportedKindIDs. Unknown numeric IDs are omitted; missing translations safely fall back before Objective-C values bridge to Swift.
- PPVetCardBridge measures the actual composition at the exact width, content-size category and legibility weight. The bounded 128-entry cache includes the full localized snapshot. Measurement does not start image requests. Display and measurement use the same text and reflow rules.
- PPPetCareVetCell.m no longer recreates the host for each callback setter. Width/text/Bold Text changes rebind content; reuse clears the host. iOS 15 containment follows the actual didMoveToWindow lifecycle, including prefetch and offscreen detachment.
- PPPetCareViewController.m measures both provider types at every text size, reloads localized projections through PPLanguageDidChangeNotification on the main queue and invalidates for Bold Text. Contact actions use PPVetContactRouting and report failure through the existing PPAlertHelper.
- The Doctors and Clinics filters still require VetTypePersonal and VetTypeCompany respectively. No provider data source, backend write, Firebase rule, schema, permission or route was added.

## Localization and accessibility source coverage

Thirteen new card keys were added to both ar.lproj/VetDetails.strings and en.lproj/VetDetails.strings. Existing feature-table packaging and Language remain authoritative. New card keys participate in the same resource verifier and safe legacy fallback.

Logical alignment and layout direction follow Language. Mixed provider names in action accessibility labels are directionally isolated. Numeric fee and currency are separate text runs. At narrow widths, XXXL and accessibility categories, identity/actions stack. Names are fully exposed to VoiceOver, accessibility-size text is not truncated and controls have at least 48-point height. Bold Text chooses Beiruti-Bold using an iOS 15-compatible Font API. Reduce Motion removes animated spatial press feedback. Semantic surfaces support light/dark appearance and the enclosing border responds to increased contrast.

These are implementation properties, not rendered or assistive-technology proof.

## Focused review and verification

An independent read-only source review found and closed:
1. Bold Text was missing from measurement/environment/cache invalidation.
2. Language changes did not recreate frozen localized card snapshots.
3. The iOS 15 host used a one-shot attachment retry that could miss prefetched cells.
4. An interim root View.fontWeight modifier required iOS 16; it was replaced by an installed typography modifier using Font.custom.

After correction, the reviewer reported no known critical/high issue or remaining actionable source finding in the reviewed slice. A subsequent defensive taxonomy change handles missing legacy translation values and has a regression test.

Final checks:
- Swift frontend parse: PASS for the cell, hosting/localization bridge and test source.
- Resource checker: PASS — 411 checks, 70 referenced feature keys, Arabic/English parity, format arguments, safe fallbacks and Xcode resource membership.
- Focused git diff --check: PASS.
- NextGen V7 bounded source audit: one gesture-only-action lexical hint on the optional information-region tap. Source review confirms the same callback is also exposed by the always-visible, semantically labeled Details Button; the essential workflow is not gesture-only. This hint is not a compile/runtime finding.
- Added seven card projection regression tests; 21 total methods in PPVetViewerTests.swift. NOT EXECUTED under static-only authorization.

Build/typecheck, actual resource bundle freshness, device rendering, RTL/LTR pixels, touch behavior, VoiceOver traversal, real Dynamic Type/Bold Text changes, dark/increased contrast, image reuse and scrolling/motion performance are UNVERIFIED. The supplied screenshot is not candidate proof. Target certification is BLOCKED/UNVERIFIED until those native gates are authorized and observed.

## Files changed in this task

- Pure Pets/MainApp/ModrenAppVC/PetCare/PPVetCardView.swift
- Pure Pets/MainApp/ModrenAppVC/PetCare/PPPetCareVetCell.m
- Pure Pets/MainApp/ModrenAppVC/PetCare/PPPetCareViewController.m
- Pure Pets/MainApp/ModrenAppVC/PetCare/PPVetViewerHostingController.swift (new fallback entries only)
- Pure Pets/ar.lproj/VetDetails.strings
- Pure Pets/en.lproj/VetDetails.strings
- Pure PetsTests/PPVetViewerTests.swift
- Pure PetsTests/verify_vet_details_resources.py
- AuditReports/VetClinicCellsV7.md

A task-start copy of already-dirty touched files was retained at /tmp/pure-pets-vet-cells-v7-20261019-141456. Existing model, detail-screen, medicine, other UI and unrelated workspace changes were preserved. This task made no project.pbxproj edit.
