# Pure Lens integration checklist

## Independence

- [ ] A user with zero Pet Profiles can open the camera and complete discovery.
- [ ] No scanner path creates, selects, persists, or requires a Pet Profile.
- [ ] Optional known-pet context does not change eligibility or API routing.

## Detection and camera

- [ ] Camera orientation and Vision orientation match in portrait and landscape.
- [ ] The analyzed aspect-fill region matches the visible preview and reticle.
- [ ] Confirmation requires the configured stable multi-frame spatial track.
- [ ] Uncertain breed produces a species-only context.
- [ ] A detected species absent from visible MainKinds pauses analysis before any frame capture or request.
- [ ] A MainKinds read failure is shown separately from an authoritative unsupported result.
- [ ] Non-animal labels and animal-word collisions never confirm (`hotdog`, `birdhouse`, `fishbowl`).
- [ ] Dog, cat, bird, rabbit, fish, reptile, small-mammal and configured livestock fixtures are exercised.
- [ ] Only one inference request is active; stale results cannot confirm.
- [ ] Autofocus, exposure, interruption, background and foreground paths recover.
- [ ] Repeated open, scan, dismiss cycles do not leak sessions or observers.

## Discovery

- [ ] One best representative frame enters the shared Search by Image pipeline.
- [ ] Accessories, Services, Medicine, and Products load progressively.
- [ ] Species compatibility is applied before breed, visual, and base ranking.
- [ ] One category failure leaves the others visible and actionable.
- [ ] All-empty state preserves successful detection and offers Scan Again.
- [ ] Medicine copy is catalog-only and never diagnostic.
- [ ] Taps open existing canonical detail screens.

## Experience

- [ ] Account has a standalone camera-to-recognition-to-discovery entry.
- [ ] The sheet remains over the camera and does not push a results screen.
- [ ] Scan Again clears context, frame, results and tasks, then reuses capture.
- [ ] Arabic RTL and English LTR use semantic layout.
- [ ] Pure Pets semantic colors and Beiruti typography render in light/dark and Dynamic Type sizes.
- [ ] VoiceOver, Dynamic Type, Reduce Motion and contrast are verified.
- [ ] iOS 26 native glass and older Material fallback are both verified.
- [ ] Denied/restricted camera, network errors and partial failures are verified.
