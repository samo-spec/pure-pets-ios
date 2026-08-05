# Release scorecard

## Source-level gates

| Gate | Status | Evidence |
|---|---|---|
| Stable backend conversation identity | Pass | `PPConversationID`; no generated row IDs |
| Dedicated navigation/expansion gesture ownership | Pass | Separate semantic `Button` controls |
| Inline controls do not navigate | Pass | Composer and chips have independent actions |
| 44-point minimum targets | Pass | Central style floor and audited button labels |
| Localized English/Arabic copy | Pass | `PPChatCell.xcstrings` |
| Plural unread accessibility copy | Pass | String Catalog plural variations |
| Locale-aware timestamps | Pass | `Date` + `PPChatTimestampFormatter` |
| Product-safe errors | Pass | `PPQuickReplyFailure` mapping |
| Optimistic/success/failure/retry state | Pass | Tested `PPQuickReplyStateMachine` |
| Cached/downsampled avatars | Pass | `PPAvatarImagePipeline` with ImageIO and request coalescing |
| Resting material discipline | Pass | Opaque collapsed surface; material only when expanded |
| Modular architecture | Pass | Core/UI/support/demo/previews split into focused files |
| Dynamic Type and RTL source support | Pass | Adaptive layouts and Arabic preview |
| Accessibility preferences source support | Pass | Reduce Motion/Transparency, contrast, non-color presence |
| Portable tests | Pass | 9 tests, 0 failures |
| Placeholder/unsafe-pattern scan | Pass | `Scripts/verify.sh` |

## Environment-dependent release gates

These cannot be honestly certified without the complete app and Apple SDK/device environment:

- Xcode target compilation with the app's deployment settings and strict-concurrency mode.
- XCUITest execution against the real inbox and messaging controller.
- VoiceOver, Voice Control, Switch Control, and Arabic mixed-direction device QA.
- Instruments scrolling, memory, image decode, and animation traces using realistic production data.
- CodeRabbit CLI pass after installation/authentication in a Git repository.

The package is a 100/100 source-design target. Final production certification requires every environment-dependent gate above to pass.
