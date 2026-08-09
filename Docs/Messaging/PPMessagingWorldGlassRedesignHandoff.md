# Pure Pets Messaging World-Glass Redesign Handoff

Date: 2026-08-06  
Implementation state: present in the current dirty working tree; source-parsed and statically audited on 2026-08-08, but not build-, simulator-, or device-verified.

## 2026-08-08 screenshot follow-up

- Replaced the header package's cool indigo/aqua field with the app-provided semantic `mainBackground` (`Color.ppBackground` in the consumer host). The package default matches light `#F8F8F9` and dark `#0E0B0C`; messaging contains no direct `quietLilac` or `#618CB8` dependency.
- Removed the host/package double background, large floating shadows, and perpetual online pulse. Identity, presence, actions, and support/listing/order context now form a shorter main-background canopy with state-scoped, sub-300 ms motion and Reduce Motion fallbacks.
- Added adaptive live/warning colors with calculated source contrast above 4.5:1 against the light and dark main backgrounds. Rendered contrast remains unverified.
- Increased text-bubble minimum height to 40 points and default vertical padding to 9 points while reducing continuation/end spacing to 3/7 points.
- Centralized all active chat routes through `PPOverlayCoordinator` as `UIModalPresentationFullScreen`. The notification/tab entry no longer pushes `PPMessagingSwiftUIHostController`; existing callers retain their source controller, optional pet-ad context, duplicate-presentation guard, and animated flag.
- Validation completed: Swift frontend parse for the header package, message cell, and messaging screen; 23/23 source contracts; strict SwiftyMax static audits; `git diff --check`; scoped route/color searches; CodeRabbit returned zero findings for the header, message-cell, and messaging-screen directories. A second header review attempt after contrast refinements was rate-limited and did not run.
- No Xcode build, simulator, physical-device run, VoiceOver/AX5 session, or rendered before/after capture was performed. No connected physical iPhone was available during the follow-up, so a 98/100 world-class release score remains `UNVERIFIED` rather than claimed.

## Request and scope

This pass redesigns the customer conversation surface as one premium, product-specific “world-glass” experience while preserving the existing message transport, Firebase models, UIKit/Objective-C bridge, navigation, and host-owned actions.

In scope:

- `Pure Pets/MainApp/NewChats/SwiftUI/PPMessagingScreen.swift`
- `MyFrames/PurePetsMessaging/Sources/PurePetsMessagingUI/**`
- `MyFrames/SpearLivingChatHeader/Sources/SpearLivingChatHeader/**`
- `Pure Pets/ar.lproj/Localizable.strings`
- `Pure Pets/en.lproj/Localizable.strings`

Out of scope: Firebase schema/rules/functions/indexes, new permissions, new provider or trust fields, transport rewrites, deployment, and implementation of pin/background behavior without an existing host contract.

## Live ownership chain

```text
Existing app launch/routing owners
  -> PPMessagingSwiftUIHostController (UIKit host and Objective-C contract)
    -> PPMessagingScreenState (observable presentation state)
      -> PPMessagingScreen (screen composition, scrolling, states, composer)
        -> SpearChatHeader (living identity/presence/context header)
        -> SmartMessageCell + PurePetsMessagingUI renderers (message surface)
        -> ChatBarView with .messaging presentation (existing composer)

ChatThreadModel / UserModel / ChManager / ChatPresenceManager
  -> existing messages, participant identity, presence, typing, mute/bin/report,
     send, retry, unsend, media, audio, pagination, and conversation context
```

`PPMessagingSwiftUIHostControllerDelegate` remains the compatibility seam for photo, video, contact, sticker, text, audio, seek, and generic action requests. SwiftUI renders state and emits intent; it does not become a second messaging backend.

## Screenshot diagnosis and root causes

- **Dead/repeated header:** identity, status, context, and controls read as stacked or repeated chrome instead of one living conversation hierarchy. The header is now one seamless surface whose identity expands inline and whose context remains subordinate.
- **Detached chevron:** expansion affordance was visually separated from the identity it controlled. The chevron now lives inside the full identity button and rotates with the same expanded state, tap target, and accessibility value.
- **Stale presence/typing:** static model snapshots were insufficient for a live header, and callbacks could outlive a participant/thread change. The host now owns presence and typing listeners, keys them by participant and thread, generation-guards callbacks, refreshes the observable state on the main thread, and tears listeners down when leaving or deinitializing.
- **Expansion scroll jump:** header height changes could move a user who was reading the latest messages. Expansion now reports through `onExpansionChanged`; the screen preserves the bottom only when the user was already at latest, performs layout-settled corrections, and gives an explicit vertical drag back to the user.
- **Fixed-width leading bubble lane:** short rows could collapse around content and leave a visually dominant blank leading lane. Rows and message columns now claim the transcript proposal, preserve physical incoming-left/outgoing-right lanes in both languages, and use content-aware adaptive width caps.
- **Oversized reply preview:** quoted content expanded to the parent maximum width. Reply references now use a compact minimum, grow only as needed within the bubble, limit preview text, and resolve local text direction.
- **Over-grouped replies:** sender/time-only grouping made quoted replies look like continuations of unrelated prose. Reply messages now form an isolated grouping family, while text, media, voice, and sticker runs retain appropriate grouping.
- **Blank-lane gestures:** a row-wide interaction surface allowed long press or swipe-to-reply to begin in empty transcript space. Each bubble publishes its actual shell bounds; the transcript pan recognizer begins only inside a published bubble region and only for a dominant, sender-correct horizontal gesture.
- **Generic alert menu:** the More action used generic alert presentation with weak hierarchy and poor state communication. It is now an adaptive SwiftUI page sheet with conversation identity, grouped settings/safety actions, localized state, disabled reasons, destructive treatment, and accessible controls.

## Code changes by area

### Screen, host, and orchestration

`PPMessagingScreen.swift` now owns the integrated world-glass composition:

- Lifecycle-safe live presence/typing observation and cleanup.
- A `SpearChatHeader` adapter for participant trust, availability, metrics, listing/order/support context, and existing host actions.
- Latest-message preservation during header expansion, stable pagination anchoring, unread positioning, keyboard-height correction, and user-owned scrolling.
- Adaptive bubble width selection by message kind and Dynamic Type.
- Reply-aware grouping, terminal metadata placement, reply-source navigation/highlight, and bubble-bounded swipe-to-reply.
- Product-specific loading, interrupted/offline, empty, transcript, typing, unread, media-viewer, and composer states.
- `WorldGlassBackground` plus restrained warm/cool atmospheric fields, optional subdued conversation wallpaper, and a bottom composer dissolve.
- A custom adaptive More sheet. Pin and background rows receive no action and render disabled when the host delegate cannot safely perform them.

### Living world-glass header

`MyFrames/SpearLivingChatHeader/Sources/SpearLivingChatHeader/**` was reshaped as one coherent header system:

- `SpearChatHeader.swift`: seamless glass/gradient field, high-contrast edge, and an opaque Reduce Transparency fallback.
- `SpearReadyHeader.swift` and `SpearChatHeaderIdentity.swift`: integrated back, identity, presence, expansion chevron, call/more area, compact layout, and accessibility ownership.
- `SpearChatHeaderExpansion.swift`: inline trust, provider metrics, profile, and safety utilities with Dynamic Type fallbacks.
- `SpearChatHeaderPresence.swift`: online/offline/typing/call visual state and motion-aware indicators.
- `SpearChatHeaderContext.swift` and `SpearConversationContext.swift`: listing, order, and support context rails backed by existing IDs/snapshots.
- Controls, copy, models, and the new brand button style provide localized labels, disabled reasons, stable identifiers, touch targets, press feedback, and Reduce Motion behavior.

### Message lanes, bubbles, replies, and metadata

`MyFrames/PurePetsMessaging/Sources/PurePetsMessagingUI/**` now provides the shared message presentation contract:

- `SmartMessageCell.swift`: full-width physical sender lanes, adaptive bubble caps, compact terminal metadata, bubble-only interaction anchors, scoped swipe feedback, local content direction, and grouped avatar/metadata behavior.
- `MessageBubbleShape.swift`: sender-aware joined/exposed/terminal corners instead of one repeated bubble silhouette.
- `ReplyReferenceView.swift`: compact quoted preview, two-line constraint, localized media fallbacks, and per-content direction.
- `PurePetsTheme.swift`: semantic light/dark bubble, stroke, avatar, signal, direction, duration, and Beiruti font helpers.
- `DeliveryStatusView.swift`, `MessageReactionsView.swift`, and the deleted/image/sticker/text/unsupported/video/voice renderers: localized copy, locale-aware counts/durations, improved accessibility labels/hints, consistent signal color, and tighter media/audio geometry.

### Localization

Arabic and English string tables include the new More-sheet, header state/context, message status, reply/media, reaction, unsupported-message, deleted-message, voice, and media-viewer accessibility copy. Arabic remains primary; the screen responds to the existing language-change notifications.

## Behavior preserved

- Existing routing, modal/back behavior, hidden navigation-bar handling, and bottom-navigation clearance.
- Existing `ChatThreadModel`, `UserModel`, `ChManager`, `ChatPresenceManager`, and `UserManager` ownership.
- Message observation, pagination, unread boundary, optimistic sends, retries, unsend eligibility, media, stickers, audio, typing, connection recovery, and composer callbacks.
- Existing photo/video/contact/sticker/audio/delegate selectors and Objective-C runtime names.
- Existing context IDs and presentation snapshots; the redesign does not create a competing context store.
- Physical outgoing-right/incoming-left lanes in Arabic and English, while message and reply text independently resolve RTL/LTR direction.
- Shared composer isolation through `PPChatComposerPresentation.messaging`; Nova/assistant presentation is not intentionally changed.

## Firebase and security boundary

- No Firestore collection, document field, Storage path, rule, index, Cloud Function, role, permission, subscription, or audit-log contract was added or weakened.
- Header trust, reputation, restrictions, context, presence, and typing are display inputs from existing authenticated models/managers. The header is not an authorization boundary.
- Context snapshots are presentation hints. Any purchase, order mutation, or privileged operation must resolve and authorize against the canonical backend document.
- Mute, report, bin, send, retry, and unsend continue through existing host/manager paths and their existing server enforcement.
- Pin and conversation background are deliberately non-operational when no delegate/contract exists: the More sheet receives `nil`, renders the row disabled with an unavailable reason, and performs no local or speculative write. Implement these only after defining the authoritative host/backend contract and permission/audit path.

## Arabic, English, accessibility, and motion

- Screen locale/layout direction follows the existing `Language` owner and updates on both existing language notifications.
- Sender lanes remain physically stable; payload and reply content use first-strong-character direction.
- Header and message controls use semantic back/forward symbols, leading/trailing alignment, localized labels/hints/values, accessibility identifiers, and 44-point-or-larger primary controls.
- Dynamic Type uses `ViewThatFits`, vertical metric/action fallbacks, scalable Beiruti fonts, adaptive message widths, and scrollable empty/action surfaces.
- Reduce Motion removes or shortens header expansion, entry, press, typing, highlight, wallpaper, and scroll animation while preserving state meaning.
- Reduce Transparency has an explicit opaque header fallback; high-contrast tokens strengthen relevant strokes. Full rendered Reduce Transparency behavior for the canvas and sheet remains unverified.
- Dark mode, VoiceOver order, Voice Control, Switch Control, AX5 layout, Arabic runtime layout, and contrast require physical-device acceptance.

## Known remaining gaps

- Compilation, package integration, Objective-C bridge visibility, target membership, and runtime behavior are unverified.
- No post-change screenshot comparison has confirmed visual acceptance on a real device.
- Presence/typing teardown, expansion anchoring, keyboard interaction, pagination, bubble-only gestures, media/audio cells, and the adaptive sheet require runtime stress testing.
- Pin/background remain safely disabled without a delegate. They are not incomplete UI wiring to bypass locally; they require a real contract before enablement.
- Backend protection of trust/reputation/context data should be reconfirmed against Infra/emulator evidence before release; this UI pass did not change it.

## Validation status

The user explicitly requested that **all tests, builds, parsers, linters, static-audit commands, and device checks be skipped** for this task. None were run. No simulator was used. Runtime/device proof is **UNVERIFIED**. This handoff does not claim production verification, release readiness, a 100/100 score, or visual acceptance.

## Exact continuation steps

1. Preserve the dirty working tree and review only the scoped messaging diff plus any concurrent handoff/backend-contract documents; do not reset unrelated work.
2. When the user authorizes validation, run the package/source static audits and parsers for the changed Swift files, then fix every compile or audit failure without changing backend contracts.
3. Build `Pure Pets.xcworkspace` only on an authorized connected physical iPhone (prefer iPhone 13 Pro Max); do not substitute `.xcodeproj`, simulator, Mac, or Catalyst.
4. Exercise loading, empty, offline/retry, long history/pagination, unread boundary, new incoming/outgoing messages, typing/presence changes, keyboard expansion/dismissal, and return/background lifecycle.
5. Expand/collapse the header while at latest and while scrolled away; confirm the former stays bottom-anchored and the latter never auto-scrolls. Interrupt the transition with a vertical drag.
6. Test short/long text, Arabic/English/mixed text, reply, image, video, voice, sticker, deleted, unsupported, failed/uploading, reactions, unsend, reply-source jump, and long-press actions. Confirm swipe/long-press cannot start in blank lanes.
7. Test the More sheet at compact/large heights and confirm pin/background remain disabled without a delegate while existing mute/report/bin paths retain their authorization behavior.
8. Validate Arabic and English, LTR/RTL, light/dark, increased contrast, Reduce Motion, Reduce Transparency, Dynamic Type XS through AX5, VoiceOver, Voice Control, Switch Control, long names, and missing avatar/context data.
9. Reconfirm Infra rules/emulator coverage for trust/reputation/context ownership before enabling any new mutation. Add pin/background only through an approved host/backend permission and audit contract.
10. Capture real-device screenshots and runtime evidence, record exact failures/fixes, and update this handoff from `UNVERIFIED` only for checks that actually passed.

=== CHECKPOINT START ===
Checkpoint Name: Messaging World-Glass Redesign Production Handoff
Status: completed
What was finished:
- Documented the current redesign scope, ownership, screenshot root causes, implementation areas, preserved contracts, security boundary, localization/accessibility behavior, gaps, and continuation sequence.
Files created/updated:
- `Docs/Messaging/PPMessagingWorldGlassRedesignHandoff.md`
Routes / models / APIs added:
- None. This checkpoint is documentation-only and records that the redesign preserves existing contracts.
Known remaining work:
- All source/build/runtime/device/accessibility validation remains UNVERIFIED by explicit user request.
- Pin/background require an approved delegate/backend contract before enablement.
How to continue next:
- Begin at step 1 of “Exact continuation steps”; do not restart the redesign or overwrite concurrent work.
=== CHECKPOINT END ===
