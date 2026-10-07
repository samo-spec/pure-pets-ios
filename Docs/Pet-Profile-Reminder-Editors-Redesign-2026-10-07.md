# Pet profile and reminder editor redesign

Date: 2026-10-07

Status: source implementation complete; focused static checks pass. Integrated app build, native rendering, interaction, accessibility, and notification delivery remain **UNVERIFIED**. This is not release certification.

## Scope and direction

The task covers the two supplied consumer iOS screenshots: Add/Edit Pet Profile and Add/Edit Reminder. It preserves their existing route owners, models, persistence services, avatar destination, reminder types, repeat rules, and notification scheduler.

The composition was reconsidered around the act of creating a pet identity and recording a care commitment. A step-by-step wizard would add navigation to short tasks; a large summary hero would repeat the input and consume the first viewport. The implemented direction places the real editable content first:

- The pet portrait and editable name become one identity area, followed by compact details, the default-pet setting, and vaccination records.
- The reminder opens with its editable care note, then its type, pet, and a single schedule group with native date/time controls, repetition, and the active switch.
- Existing Pure Pets color tokens, Beiruti typography, native controls, and semantic direction are retained. Pink marks actions and selection. No ambient animation or decorative hero is added.

The pet editor was already hosted in SwiftUI through its Objective-C coordinator. This work preserves that integration. The reminder remains code-only UIKit/Objective-C.

## Owned changes

| File | Change owned by this task |
| --- | --- |
| `Pure Pets/MainApp/UserFiles/PetsProfiles/PPPetProfileEditorSwiftUI.swift` | Portrait-led editor, adaptive details/default rows, vaccination list and deletion confirmation, navigation/save states, keyboard completion, localized date formatting. |
| `Pure Pets/MainApp/UserFiles/PetsProfiles/PPPetProfileEditorViewController.m` | Isolated edit draft, photo import/upload failure recovery, Arabic/Persian/ASCII age validation, main-thread callbacks, save lifetime, account binding. |
| `Pure Pets/MainApp/UserFiles/PetsProfiles/PPPetProfilesSwiftUI.swift` | Only `PPPetLang` was changed by this task to use `Language.get`, so app-selected language governs editor text. Other profile-list edits in this shared file belong to concurrent work. |
| `Pure Pets/MainApp/UserFiles/PetsProfiles/PPReminderEditorViewController.m` | Native care-note composition and reachable loading, empty, retry, validation, notification-permission, save, and account-change states. |
| `Pure Pets/ar.lproj/Localizable.strings` | 45 source-referenced `pet_editor_*` / `reminder_editor_*` keys, paired with English. Other localization edits were preserved. |
| `Pure Pets/en.lproj/Localizable.strings` | Matching 45 English keys and format placeholders. |

The pre-existing dirty profile models, managers, Home/Lens work, and later profile-list/`pet_folio_*` edits were preserved. No new route, public API, model field, collection, rule, or project-file entry was introduced.

## Behavior and resilience

Pet profile:

- Name, breed/category selection, age in months, photo, default selection, and vaccination add/edit/delete remain available through the existing callbacks.
- The editor works on a copy. Cancelling does not mutate the caller's pet or vaccination records. The original is refreshed after successful persistence.
- Vaccination deletion resolves the stable record identity at confirmation time and only persists with the profile save.
- Age accepts ASCII, Arabic, and Persian digits. Invalid characters, fractions, signs, and integer overflow produce localized validation rather than being silently converted to zero.
- Import work is cancellable and request-scoped. A photo upload failure stops persistence, reports the failure, and retains the draft for retry.
- The save operation retains its data if the controller disappears. A late completion cannot pop another route.

Reminder:

- Existing vaccination/food/appointment type values and `""`, `daily`, `weekly`, `monthly`, `yearly` repeat values are unchanged.
- Pet loading, a real empty list, and a failed request have different presentation and actions. Empty state opens the existing pet editor and reloads pets on return. Retry preserves the reminder draft.
- An unavailable existing pet association is not silently replaced. A new reminder retains the existing first-pet default behavior.
- Native date/time controls edit one absolute draft date. A new reminder starts one hour ahead. Enabled reminders with a past time receive validation, matching the existing scheduler's future-date requirement.
- A first-time notification prompt and denied device notifications have different recovery actions. A reminder can still be saved without notification permission. The existing notification manager remains the scheduler.
- Save failure preserves the draft. Successful save updates the original model and schedules through the existing manager.

Both editor drafts capture the authenticated account that opened them. Before writes, after asynchronous operations, and before scheduling the reminder, the owner must still match the authenticated user. The pet upload-to-save boundary is guarded separately. A changed account produces localized recovery instead of continuing the old draft under a different user. This is a client-side stale-operation guard; server rules remain authoritative.

## Localization, layout, and accessibility

- Arabic and English use the app's `Language` selection, semantic direction, and logical leading/trailing layout.
- SwiftUI receives matching layout-direction and locale environments; native labels and controls use the existing language helpers.
- Date presentation and native pickers use the selected Arabic/English locale. Age parsing accepts local digits.
- Long text wraps. Detail/date/type rows reflow at accessibility sizes; narrow layouts stack date rows. Main content has a bounded readable width.
- Native controls, explicit accessibility labels/hints, selected-state semantics, and minimum interaction sizes are present in source. Validation announcements are limited to a visible reminder editor.
- Keyboard layout guides/scrolling and the pet editor's keyboard completion control keep input usable. Motion is limited to native interaction and contextual scrolling; custom scrolling honors Reduce Motion.
- Existing semantic colors support light/dark appearance. Rendered contrast and accessibility behavior still require native verification.

## Contract and security boundary

Read-only tracing covered the existing `UserManager` facade, `PPPetProfileManager`, `PPReminderNotificationManager`, and the relevant Infra owner rules.

- Persistence still uses the existing user-scoped managers and merge/transaction behavior.
- Avatar destination remains `users/{uid}/pets/{petID}/avatar.jpg`.
- Pet IDs, reminder IDs, type values, repeat strings, timestamps, ownership, existing permission checks, and reminder audit behavior are preserved.
- No Firestore/Storage rules, permissions, App Check settings, backend functions, production documents, or deployment state changed.

## Validation evidence

| Check | Result and limit |
| --- | --- |
| `xcrun swiftc -frontend -parse` on editor, shared pet surfaces, and hosting controllers | PASS. Syntax parsing only; not type checking, linking, or a full app build. |
| Reminder Objective-C syntax check against installed iPhoneOS UIKit SDK with an iOS 15 target | PASS. `clang -fsyntax-only` used the current editor body and real model/UIKit headers. Stand-in declarations replaced UserManager/FIRUser, font, and generated color APIs. This is an isolated syntax/API check, not integrated app compilation. |
| `plutil -lint` on Arabic and English localization files | PASS. |
| Source-referenced editor localization keys | PASS: 45 keys, each present exactly once in each language; format placeholders match. |
| Scoped `git diff --check` | PASS. |
| Independent source review | Pet review reported no concrete issue in its reviewed snapshot. Reminder review identified two P2 hidden-stack Auto Layout conflicts; both were corrected by allowing the hidden chevron/surface constraints to yield. The independent reviewer could not complete a post-fix rereview due to its usage limit. The final owner-binding additions received primary-agent source review and the static checks above. |
| NextGen brand/source tools | Brand brief accepted; lexical checks assisted review. These do not establish native visual or runtime quality. |
| Native visual preflight | BLOCKED/UNVERIFIED: no candidate device capture, accessibility runtime, motion capture, or profiler evidence. User screenshots are baseline evidence only. |

Temporary verification artifacts are under `/tmp/pure-pets-editor-static-20261007/`. Owner-specific pre-edit source copies are under `/tmp/pure-pets-profile-editor-20261007-baseline/`. These temporary paths are not durable release artifacts.

No `xcodebuild`, test build, simulator execution, device installation, deploy, push, or production mutation ran. The user's explicit build restriction remains in effect.

## Remaining native acceptance gates

On the approved physical iPhone 13 Pro Max workflow, once build execution is explicitly authorized:

1. Build the integrated app using Xcode default DerivedData and verify add/edit routes for both editors.
2. Capture Arabic RTL and English LTR in light/dark mode, normal and AX5 text size; check names, long translations, date controls, keyboard reachability, safe areas, and tab-bar overlap.
3. Exercise VoiceOver ordering/labels, disabled states, Reduce Motion, vaccination confirmation, photo cancellation/failure/retry, and persistence failure/retry.
4. Exercise empty/failed/unavailable pet states, add-pet return, notification not-determined/denied/authorized states, repetition, disabling, and actual local notification delivery.
5. Exercise leaving during save, double save, sign-out/account change during pet upload and reminder save, and reopening the correct account. Verify persisted readback with the existing authorized workflow.

=== CHECKPOINT START ===
Checkpoint Name: Pet profile and reminder editors - source handoff
Status: completed
What was finished:
- Both requested screen compositions implemented in their existing native owners.
- Bilingual copy, directional layout, accessibility adaptations, draft isolation, failure recovery, and account-bound asynchronous operations.
- Focused source checks and exact validation boundary recorded.
Files created/updated:
- Four pet/reminder source files, paired Localizable.strings, and this handoff.
Routes / models / APIs added:
- None.
Known remaining work:
- Integrated build, rendered layouts, native interaction/accessibility/performance, and real notification/persistence checks are UNVERIFIED.
How to continue next:
- Preserve these source changes and unrelated dirty work. After explicit build authorization, run the approved physical-device acceptance gates above.
=== CHECKPOINT END ===
