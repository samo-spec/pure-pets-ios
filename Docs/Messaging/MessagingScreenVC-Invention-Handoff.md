# MessagingScreenVC — conversation page and sticker stage

Date: 2026-10-05

Implementation is integrated in the consumer iOS source. Native compilation,
rendered appearance, device interaction, accessibility and performance are
**UNVERIFIED**. No Xcode build, simulator, deployment or production write was run.
The workspace requires explicit build authorization and the connected iPhone
13 Pro Max workflow with default DerivedData.

## Intent and selected direction

The request authorized a new SwiftUI messaging presentation named
`MessagingScreenVC`, including a reinvented sticker sheet, while retaining data,
backend contracts, navigation and workflows. The existing screen was already
hosted in SwiftUI; this change replaces its presentation owner without creating
another UIKit route, message store or transport.

Three topologies were considered internally:

1. A spatial field with orbiting message objects: expressive selection, but poor
   chronological reading, large-text reflow and long-conversation performance.
2. A two-column correspondence spread: clear ownership on a wide canvas, but
   loses too much reading width on an iPhone and at accessibility text sizes.
3. A continuous conversation page with open passages and an expandable writing
   edge: selected because it gives chronology and writing the dominant space,
   retains familiar ownership cues, and reserves spatial interaction for the
   deliberate act of choosing and sending a sticker.

This is an implementation decision, not an independently certified visual score.
No current baseline screenshot or candidate native capture was available during
the initial implementation. Source inspection found bubble shells, a capsule
composer and a tiled immediate-send sticker picker; that was a structural
observation. The later user screenshots and spacing correction are recorded below.

## Source and ownership

| Owner | Responsibility after this change |
| --- | --- |
| `Pure Pets/MainApp/NewChats/SwiftUI/MessagingScreenVC.swift` | New root SwiftUI screen; transcript, scroll continuity, page states, typing line, reading-position control and composer integration |
| `Pure Pets/MainApp/NewChats/SwiftUI/PPMessagingScreen.swift` | Existing Objective-C compatible host, state, relay, message adapter, media viewer and redesigned identity/context header |
| `MyFrames/PurePetsMessaging/Sources/PurePetsMessagingUI/Components/ConversationPassageRow.swift` | New bubble-free passage presentation using the existing payload renderers and delivery states |
| `Pure Pets/MainApp/GEMENI/ChatBarView.swift` | Messaging-only writing edge, multiline input, tool stage, reply preview, microphone/send continuity; existing recorder remains the single owner |
| `Pure Pets/MainApp/GEMENI/PPStickerKit.swift` | `PPMessageStickerStage`; existing `PPChatSticker`, store, cache and download identity preserved |
| `MyFrames/PurePetsMessaging/Sources/PurePetsMessagingUI/Renderers/VoiceMessageView.swift` | Optional width input and compact stacking; existing callers retain the default layout |
| `Pure Pets/{ar,en}.lproj/Localizable.strings` | Paired new product and accessibility copy |
| `Pure Pets.xcodeproj/project.pbxproj` | Explicit source membership for `MessagingScreenVC.swift` |

`PPMessagingSwiftUIHostController` now instantiates
`UIHostingController<MessagingScreenVC>`. Its Objective-C name, delegates and
configuration selectors remain intact. The new source file requires a few
previously file-private presentation types to be module-internal; no additional
Objective-C API was exported.

The shared `SmartMessageCell` stays available to its other consumers. The Nova
composer and its existing sticker picker keep their own presentation path.

## Behavior ledger

| Concern | Source authority / preserved contract | Verification boundary |
| --- | --- | --- |
| Navigation | Existing host configuration, dismissal, context routing and Objective-C delegates | Host section compared to pre-edit snapshot, allowing only the root view type binding |
| Text, stickers, photos, video and audio | Existing `send*ThroughExistingPipeline` methods and relay callbacks | Host transport bytes unchanged apart from root type binding |
| Server writes | `ChManager` uses `supportChatCommand` or `chatMessageCommand`, with the existing payload and identities | Read-only trace; no client/server contract changes |
| Sticker assets | Existing `PPChatSticker` IDs, storage paths, download URLs, manifest/cache and `stickers` enumeration | Model/store section compared byte-for-byte with pre-edit snapshot |
| Storage authorization | Infra `storage.rules`: thread membership for `Chats/{threadId}`; authenticated read/list and no client writes for curated `stickers` | Rules inspected, not edited or deployed |
| Reply, copy, retry, unsend | Same message IDs, existing actions and unsend eligibility policy; visible retry and semantic Reply/Copy/Unsend actions | Source review; runtime still unverified |
| Context and trust | Existing support, pet listing, accessory and order projections; original provider eligibility for verified-seller label | Source parity review; no invented trust or presence fields |
| Voice | Existing recording permission, preparation, hold/cancel/lock, pause, preview and audio handoff | Recorder implementation retained; native audio test unverified |
| Conversation lifecycle | Existing observers, auth, participants, blocked state and backend errors | Host section preserved; live authorization not re-tested |
| Scrolling | Stable message IDs, initial unread anchor, older-page anchor and explicit return-to-present control | Source review; new incoming messages preserve an older reading position |
| Keyboard | System safe area; latest scrolling only when already at latest; explicit accessibility dismissal action | Device keyboard and interactive dismissal unverified |
| Attachments | Existing photo/video/sticker actions; contact tool appears only when a handler exists | No inert contact control added to the default host |

## Interaction and motion

All new motion uses presentation state; none changes a message payload or marks a
send successful. Message delivery remains the server/transport's responsibility.

| Trigger | Presentation response | Cancellation / equivalent |
| --- | --- | --- |
| New outgoing message | Short upward settling into its passage, anchored near the writing edge | Stable ID; Reduce Motion shows the final state directly |
| Incoming message | Small arrival offset/opacity; scroll only if the reader is already at latest | Older reading position retained with an explicit return control |
| Reply drag | Existing bounded transcript recognizer drives passage displacement and reply glyph; one threshold haptic | Spring returns to rest; accessible Reply action; no displacement with Reduce Motion |
| Draft becomes nonempty | Microphone/send action uses complementary matched-geometry source ownership | Existing focus/draft preserved; spatial transition disabled with Reduce Motion |
| Tools opened | Photo/sticker/video tools unfold above the still-visible draft | Same button closes tools; compact large-text tools get a bounded scroll area |
| Real remote typing | An unfinished line grows at a capped 12 Hz schedule | Paused for inactive scene, Low Power Mode or Reduce Motion; localized typing text remains |
| Sticker selected | Original asset moves to a focused preview; selection scrolls the preview into view | Selection can change immediately; original cache key and storage identity retained |
| Sticker lifted | Small tilt and depth track input; progress arc and haptic identify the send threshold | Return below threshold cancels; Send button and accessibility Send remain available |
| Sticker sent | Immediate one-time handoff; short upward departure and dismissal | `didHandOff` prevents repeat submission; task cancels with view lifecycle; background dismisses the handed-off sheet |

The new sticker experience animates the real curated artwork through selection,
manipulation and sending. It does not create or alter sticker image files, claim
new GIF playback support, or invent sticker categories absent from the data.
Sticker filenames are presented without file extensions; payload values remain
unchanged.

Unsend eligibility refresh is one scene-bound, cancellable task rather than a
timer created during every body evaluation. Audio playback stops on screen
departure/inactivation. The messaging recording status uses a static dot because
the existing measured waveform already communicates live recording.

## Native UX, localization and brand

- Arabic and English strings are paired in the app's existing localization files.
- UI direction comes from `Language`; sender ownership remains physically
  outgoing-right/incoming-left, matching the existing product contract.
- Message, draft and quoted text resolve their own writing direction. The remote
  participant name in the typing sentence is isolated for mixed-script display.
- Primary controls provide at least 44-point targets; reply, retry, sticker send
  and keyboard dismissal have semantic alternatives to gestures.
- Large text reflows the sticker sheet into one scrollable column and bounds
  composer tools. Voice content stacks when narrow. The sticker stage uses a
  split composition only when width permits.
- New page surfaces use the existing `ppBackground`, `ppSurface`,
  `ppSurfaceBorder`, `ppPrimary`, `ppTextPrimary` and `ppTextSecondary` tokens and
  Beiruti type. The existing approved `newlogo` support avatar is preserved.
- The V6 brand-brief validator returned valid. It is structural evidence only.
- Actual VoiceOver reading order/focus, AX5 fitting, RTL gestures, dark mode,
  increased contrast and Reduce Motion behavior still require device evidence.

## Verification and review

Source validation performed:

- Swift frontend syntax parsing for all six affected Swift files.
- `plutil -lint` for both localization files and the Xcode project.
- Scoped `git diff --check`.
- Localization-key coverage and paired-copy checks.
- Baseline comparisons for host transport, message state/adapter and sticker
  model/store identities.
- CodeRabbit source reviews of the screen/host, composer/sticker and messaging
  package. Review corrections cover provider badge parity, duplicate support
  context, timer lifetime, matched-geometry source ownership and compact voice
  layout. Raw review records are under the temporary evidence directory below.

All three follow-up review runs returned zero findings. The explicit keyboard
accessibility action and removal of sticker filename extensions were small local
refinements made during those runs; the final syntax, localization, contract and
hash checks cover their current source as well. Fourteen contract checks passed;
twenty new localization keys are paired in Arabic and English.

The V6 lexical analyzer is advisory. Its old `onChange` warnings are constrained
by the iOS 15 deployment floor. The new typing schedule explicitly pauses; it is
not an unscoped implicit animation. Its store-I/O finding points to the unchanged
cached-manifest reader and remains a pre-existing performance risk for device
profiling. Old Nova-only animation/material paths were not redesigned. Syntax and
source-review results are not a successful app build or runtime acceptance.

Evidence directory: `/tmp/pp-messaging-invention-20261005/`.
It contains the pre-edit scoped baseline, status snapshot, validation output,
source hashes and CodeRabbit output. Existing unrelated dirty changes were
preserved, including the already-edited support avatar in the host file.

An isolated review-copy command was rejected by the automatic approval hook as
a possible credential-file read. Review proceeded with CodeRabbit's directory
filters instead. No protected skill, configuration or credential file was edited.

## Screenshot correction: compact vertical layout

The user supplied two Arabic support-thread screenshots on 2026-10-05 showing a
large blank band inside the expanded header and a short transcript far above the
composer. The source cause was the expanded details `ScrollView` claiming its
148-point maximum even for one trust label, plus a top-aligned short transcript.

- `PPMessagingHeader` now measures the intrinsic details height and uses only
  that height, up to the existing 148-point / 180-point accessibility limit.
  Longer content remains scrollable; context, trust and profile actions remain.
- `MessagingScreenVC` places the fitted header above the transcript viewport.
  The transcript fills that actual viewport with bottom alignment, keeping short
  histories next to the composer while long histories retain scrolling.
- The final message no longer adds the 20-point inter-passage gap after itself.
- Existing header-height observation, initial/unread/pagination anchors, reply
  gestures, keyboard handlers, sender directions, localization and transport
  remain in place. No backend, permission or data changes were made.

Swift syntax parsing passed for both changed source files, and the scoped diff
passed whitespace validation. Six baseline comparisons confirmed the host/state/
adapter, context/trust routing, composer callbacks, scroll/reply handlers,
scroll lifecycle, and locale/motion lifecycle remain unchanged. CodeRabbit reviewed
both changed source files and returned zero findings. The comparison baseline and
scoped review evidence are in `/tmp/pp-messaging-spacing-20261005/`.
Candidate rendering, short/long-history keyboard interaction and AX5 fitting
still require authorized physical-device verification. The supplied screenshots
are baseline evidence, not proof of the corrected source on a device.

## Sticker selection hang follow-up — 2026-10-06

The user reported an app hang when selecting a sticker. The presentation path
was traced from `ChatBarView` through `PPMessageStickerStage`, `AppRemoteImage`,
the existing host relay and `ChManager` send command. The image loader already
uses asynchronous disk loading and display-size downsampling. No measured
main-thread stack was available: Xcode exposed no paused thread stack and
iPhone Mirroring was timed out. The exact on-device hang remains unverified.

The selection path had overlapping layout changes: a global animation removed
the selected grid artwork while introducing a matched-geometry preview, a
conditional send inset changed the viewport, and an animated scroll plus
VoiceOver focus ran during the same update. The source fix in `PPStickerKit.swift`:

- Keeps each grid thumbnail mounted and marks selection with a noninteractive
  outline; removes the cross-container matched-geometry transition.
- Reserves the send edge whenever the catalog is populated, with Send disabled
  until a sticker is selected. Selection no longer inserts a bottom inset.
- Scopes the selection spring/fade to the preview instead of the lazy grid.
- Moves preview scrolling into a cancellable selection task after yielding,
  disables animation for that scroll, and guards visibility, current selection,
  scene activity and handoff. VoiceOver focus follows only when VoiceOver runs.
- Preserves the tactile lift gesture, Reduce Motion behavior, one-shot send
  guard, original sticker payload, Arabic/English copy and existing transport.

Swift syntax parsing and scoped whitespace checks passed. CodeRabbit reviewed
the affected composer/sticker directory and returned zero findings. These are
source checks, not a native build or a reproduced-and-resolved hang. Cached
manifest I/O and whole-catalog prefetch are unchanged pre-existing profiling
risks; no evidence connected them to this specific selection report.

Evidence: `/tmp/pp-sticker-hang-admin-alerts-20261005/`. The separate report of
missing Admin support alerts was traced to server-side actor classification and
fixed in Infra; see `Pure Pets Infra/docs/SUPPORT_NOTIFICATION_ACTOR_FIX_2026-10-06.md`.
Neither iOS build nor backend deployment was authorized during this follow-up.

## Remaining acceptance gate

No build authorization was supplied. Native acceptance and production readiness
remain **BLOCKED/UNVERIFIED** until the authorized iPhone 13 Pro Max workflow checks:

1. Compile and open this actual screen through the existing user-chat route.
2. Send/receive/reply/retry/unsend; unread and pagination anchors; older reading
   position during new arrivals and keyboard changes.
3. Photo/video upload and media viewer; recording permission denial, hold/cancel,
   lock, pause, preview, interruption and audio playback.
4. Sticker loading, empty, failed, cached-offline, selection, preview scrolling,
   gesture cancellation, rapid repeated send, background and dismissal.
5. English/Arabic, mixed text, light/dark, AX5, VoiceOver, Reduce Motion, rotation
   and regular-width adaptation. Capture real screenshots and motion traces.
6. Frame pacing and memory with long transcripts and a large sticker manifest.

Do not restart discovery when resuming. Continue at these acceptance gates;
deployment, production mutation, simulator execution and custom DerivedData are
not authorized by this handoff.

```text
=== CHECKPOINT START ===
Checkpoint Name: MessagingScreenVC source delivery and review
Status: completed
What was finished:
- New screen, passage rows, composer and sticker stage are connected.
- Source reviews and scoped syntax/localization/contract checks are complete.
Files created/updated:
- Ten task-owned source, localization, project and handoff files listed above.
Routes / models / APIs added:
- No backend routes, models or APIs; existing UIKit host binds the new root view.
Known remaining work:
- Authorized native build and physical-device acceptance remain UNVERIFIED.
How to continue next:
- Use the six acceptance scenarios above on the connected iPhone 13 Pro Max.
=== CHECKPOINT END ===
```
