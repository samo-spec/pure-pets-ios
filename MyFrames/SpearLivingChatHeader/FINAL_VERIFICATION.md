# SPEar Living Chat Header — Final Verification Ledger

## Closed review blockers

- Both confirmed missing-return compiler defects were repaired.
- Active-call state and its End Call action are now one typed value.
- End Call remains available in ready, loading, and unavailable header states.
- Offline presence stores a real timestamp; fixed text is locale-derived.
- Response speed is typed instead of caller-authored presence text.
- Non-finite order progress is rejected and finite progress is clamped to `0...1`.
- Metrics are deduplicated by nonempty stable ID before the three-item cap.
- Repeated visual trust detail is hidden from VoiceOver because the identity element already announces it.
- Context symbol motion is disabled under Reduce Motion.
- Expanded metrics and actions use fit-driven compact layouts at large text sizes.
- The release script filters to iOS simulators, runs Debug tests, and performs a warning-as-error Release build.

## Fresh checks executed in this environment

| Check | Result |
|---|---|
| Strict `swift-format` lint | Pass |
| Swift syntax parse for all production and test files | Pass |
| Foundation source type-check with warnings as errors | Pass |
| Foundation executable regression contract | 7/7 pass |
| Source engineering guardrails | 20/20 pass |
| Swift package manifest dump and describe | Pass |
| Release-script Bash syntax | Pass |
| Source-contract Python syntax | Pass |

## Apple-platform certification

`Scripts/verify_release.sh` completed its first five stages and then stopped with exit status `2` because this environment does not provide `xcodebuild`.

Run on macOS with Xcode 16 or newer:

```bash
./Scripts/verify_release.sh
```

Then complete `RELEASE_QA.md` on physical devices. A literal 100/100 release certification requires those rendered, assistive-technology, and Instruments gates to pass in the integrating application.
