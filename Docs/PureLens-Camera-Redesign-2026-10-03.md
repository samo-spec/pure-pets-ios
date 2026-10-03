# Pure Lens camera redesign — 2026-10-03

Status: source implementation and focused static review complete. Native build, rendered appearance, runtime accessibility, camera interaction, and performance remain **UNVERIFIED**.

## Scope and authority

The user clarified that the pictured surface is the consumer iOS Pure Lens screen, not the Admin barcode scanner. Delivery uses the existing SwiftUI package under `MyFrames/PureLensPackage`, reached through `HomeRouter` → `PPPureLensHostPresenter` → `PureLensUIKit` → `PureLensView`. No new screen owner, navigation stack, service, dependency, backend operation, or persistence path was introduced. Unrelated payment and Admin changes were preserved.

The supplied screenshot is the observed baseline. It shows an unlabeled icon rail, a fixed central bracket frame, and a separate bottom prompt with nested privacy chrome. The redesign prioritizes the camera subject and makes the automatic scan sequence legible.

## Direction

Three composition options were considered: an open camera with a compact instruction area; a floating contextual card stack around the detected subject; and a shutter-centered capture composition. The open camera was selected because automatic stable detection already owns capture. Floating cards would compete with the animal; a shutter would imply a new manual workflow.

The implemented layout has a small product heading and close control, a labeled Frame / Identify / Discover rail, an unobstructed camera viewport, and one instruction/privacy panel. Compact windows place instructions below the camera. Windows with at least 700 points of available width place the panel at the semantic trailing edge. Accessibility text sizes use the stacked layout with bounded scrolling. This adapts to available window size, including iPad split windows and landscape phones.

`HomeRouter.appTheme` and `PureLensTheme` remain the token authority: graphite camera surfaces, white camera text, recognition green, warning/error semantics, brand primary for continuation, and existing Beiruti typography. No logo was invented. Motion is limited to genuine confirmation progress and press feedback; Reduce Motion keeps static state meaning.

## Files

- `Sources/PureLens/PureLensView.swift`: adaptive composition, labeled stage rail, close control, semantic direction, camera-only dark appearance.
- `Sources/PureLens/Components/LensCameraScene.swift`: viewport-relative bounds, physical aspect-fill coordinates, quieter brackets, non-intercepting overlays, camera caption, static Reduce Motion validation indicator.
- `Sources/PureLens/Components/LensBottomPrompt.swift`: readable status/title/detail hierarchy, natural-height bounded scrolling, candidate and terminal recovery actions, quiet privacy footer, isolated Latin scientific names.
- `Sources/PureLens/PureLensStore.swift`: shared asynchronous camera-authorization refresh on startup/activation with cancellation, request identity, foreground, and dismissal protection.
- `Sources/PureLens/Resources/ar.lproj/Localizable.strings` and `en.lproj/Localizable.strings`: paired stage/heading/recovery copy and device-neutral wording.

Source paths above are relative to `MyFrames/PureLensPackage`.

## Preserved behavior and recovery

- Existing automatic stabilization, frame association, consent alert, server-supported identity/category validation, discovery, result sheet, and dismissal callbacks remain authoritative.
- Unsupported, uncertain, not-animal, taxonomy-unavailable, and validation-failed states retain Scan again. Candidate selection and None of these stay distinct.
- Declining initial identification consent releases the frame. The prompt offers a fresh scan, without promising to resume a deleted frame. Later discovery consent can use the existing Continue analysis action when the animal context and retained frame exist.
- Returning from Settings refreshes camera authorization rather than relying on a cached denied value. A late callback cannot restart a dismissed session.
- Preview coordinates remain physical in RTL; text, controls, stage ordering, and side-panel placement use semantic leading/trailing. The existing preview owns tap-to-focus.
- No Firebase rules, permissions, App Check, callable payloads, selected-frame policy, or commerce authority changed.

## Validation evidence

Passed:

- Swift frontend syntax parsing of all four changed Swift files.
- `plutil -lint` for Arabic and English resources.
- Paired-resource audit: 175 keys per locale, no duplicates, matching format placeholders; all literal localization references in the three changed presentation files resolve.
- Scoped `git diff --check` for `MyFrames/PureLensPackage`.
- Independent focused source review: no concrete critical/high defect identified. The Reduce Motion consistency observation was addressed.

These checks do not prove compilation, final geometry, camera operation, or accessibility behavior. No app build, test build, simulator, deployment, or production mutation was run. Builds were not authorized for this task.

## Native acceptance still required

Use the workspace-approved physical-device workflow only when authorized. Capture Arabic RTL and English LTR in compact/regular layouts, portrait/landscape, split-window widths, and accessibility text sizes through AX5. Exercise all terminal states, long candidate names, consent decline/retry, permission denial → Settings → allow, interruption/background/foreground, focus taps, result dismissal, and close during pending permission. Verify VoiceOver order/actions, contrast settings, Reduce Transparency, Reduce Motion, status-bar appearance, and camera frame pacing.

iPad render evidence is also outstanding; an iPhone build or syntax pass cannot establish iPad acceptance. The final visual and production-quality verdict remains **UNVERIFIED** until those native gates are observed.

## Follow-up: searching without results and abrupt tracking

The user reported that scanning stays in searching while the frame moves, and that focus motion is abrupt. Source tracing established these concrete paths:

- Raw Vision observations down to confidence 0.35 could move the UI reticle even though the stabilizer requires 0.58. The reticle now follows only a stabilizer-backed candidate; weak observations retain the neutral aiming frame.
- A single missing/subthreshold frame discarded a pre-lock candidate immediately. Acquisition now retains its existing progress for the configured bounded missing-frame tolerance, while requiring the same number of accepted high-confidence observations of the same spatial subject. A miss does not add progress. Competing or ambiguous subjects cannot inherit the previous candidate's accepted frames. Post-lock replacement protections are preserved.
- The redesign removed the rectangle's geometry animation. A bounded, critically damped animation now follows its position and size, scoped only to the overlay and disabled for Reduce Motion/interruption. Compact instruction space is reserved so changing scan copy cannot repeatedly resize the live preview/crop.
- Canceling a SwiftUI startup waiter no longer cancels the store-owned authorization task shared with activation. Explicit store teardown remains the cancellation owner.

Regression fixtures were added for acquisition gaps and identity/ambiguity boundaries. Their execution requires an authorized Swift test build and is **NOT RUN**. Physical confirmation of the reported symptoms remains **UNVERIFIED**. These fixes do not lower confidence, bypass selected-frame consent, or change server category/commerce validation.
