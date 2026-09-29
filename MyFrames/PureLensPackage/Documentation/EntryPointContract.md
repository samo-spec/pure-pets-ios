# Pure Lens entry-point contract

Pure Lens is a placement-independent discovery feature. Home, Account,
Marketplace, or Pet Profile may launch it, but placement cannot change its
eligibility: the camera is available with zero Pet Profiles.

## Runtime invariants

1. Presenting Pure Lens creates one scanning-session store and one camera owner.
2. Camera permission and scanning never query, create, or select a Pet Profile.
3. `DetectedAnimalContext` is temporary and is cleared on Scan Again or close.
4. A candidate must remain stable across the configured temporal and spatial
   window before it becomes confirmed.
5. Species is required for success; breed is optional and confidence-gated.
6. The result sheet appears over the camera as soon as detection is confirmed.
7. Accessories, Services, Medicine, and Products populate independently.
8. Exactly one selected representative frame may enter Search by Image.
9. Search by Image failure does not block taxonomy results.
10. Result taps use existing canonical detail routes.

## Entry ownership

The app should compose one `PPPureLensHostPresenter` per owning screen and avoid
presenting a second scanner while one is already visible. Account uses a
dedicated discovery entry, not a settings row. Pet Profile entry points are
optional launch affordances only.

## Acceptance matrix

| Scenario | Required result |
|---|---|
| Zero Pet Profiles | Camera opens and discovery works normally. |
| No animal | Searching continues; no confirmation or sheet appears. |
| Uncertain breed | Species-only context and results. |
| Stable animal | Sheet appears and categories populate progressively. |
| Image search fails | Compatible taxonomy results remain visible. |
| One category fails | Other categories remain usable. |
| All categories empty | Successful detection/no-results state and Scan Again. |
| Permission denied | Intentional recovery state with Settings action. |
| Scan Again | Ephemeral state clears and the existing session resumes. |
| Dismiss/background | Inference and tasks stop safely. |
