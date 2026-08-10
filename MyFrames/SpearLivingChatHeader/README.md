# SPEar Living Chat Header

A release-candidate SwiftUI chat header for iOS 17+, designed for marketplace conversations, verified identities, active orders, support cases, and live communication states.

## What changed in the Conversation Compass redesign

- A single typed `SpearTrustState` now owns the badge, visible trust detail, and VoiceOver trust description.
- Semantic `SpearPresence` owns real presence data: typed response speed and an offline timestamp rather than caller-authored status text.
- Optional controls use explicit `enabled`, `disabled(reason:)`, or `hidden` capabilities. Back navigation is required.
- Loading preserves a real Back control instead of replacing navigation with a decorative skeleton.
- `ViewThatFits` and accessibility-size layouts adapt the header, metrics, actions, and context rail at compact widths.
- `SpearCallControl` owns both call phase and its action, making an active call impossible without an enabled End Call control.
- A motion arbiter permits only one continuous semantic animation: online presence, typing, or active call.
- The reusable component no longer owns remote image loading. The app injects its cached, authenticated, downsampled avatar view.
- VoiceOver identity output includes name, trust state, presence or call state, and expanded/collapsed state without repeating the visual trust detail.
- Reduce Motion, Reduce Transparency, Increased Contrast, RTL, Dynamic Type, hidden/disabled actions, loading, error, and retry are first-class states.
- Marketplace, order, and support context share one bounded conversation deck with expanded trust utilities; they never stack into competing cards.
- Trust and presence remain legible without badge-on-badge decoration or a redundant status pill.
- Production files are split by responsibility and remain below 300 lines.
- A Swift package, contract tests, source guardrail script, Xcode release script, and manual QA matrix are included.

## Package layout

```text
SpearLivingChatHeader/
├── Package.swift
├── Sources/SpearLivingChatHeader/
│   ├── SpearChatHeader.swift
│   ├── SpearReadyHeader.swift
│   ├── SpearChatHeaderModels.swift
│   ├── SpearConversationContext.swift
│   ├── SpearChatHeaderActions.swift
│   ├── SpearChatHeaderIdentity.swift
│   ├── SpearChatHeaderPresence.swift
│   ├── SpearChatHeaderExpansion.swift
│   ├── SpearChatHeaderContext.swift
│   ├── SpearChatHeaderDeck.swift
│   ├── SpearChatHeaderStates.swift
│   ├── SpearChatHeaderControls.swift
│   ├── SpearChatHeaderCopy.swift
│   ├── SpearChatHeaderStyle.swift
│   └── SpearChatHeaderPreviewLab.swift
├── Tests/SpearLivingChatHeaderTests/
├── Scripts/
└── RELEASE_QA.md
```

## Add to Xcode

Use **File → Add Package Dependencies… → Add Local…** and select this folder, or drag the production files from `Sources/SpearLivingChatHeader` into the app target.

Minimum deployment target: **iOS 17.0**.

## Basic integration

```swift
let model = SpearChatHeaderModel(
  id: user.id,
  name: user.displayName,
  avatarFallback: .initials(user.initials),
  trust: .verifiedSeller(
    role: String(localized: "Seller"),
    location: user.cityName
  ),
  presence: .online(responseSpeed: .fast),
  metrics: [
    .init(id: "rating", value: "4.9", label: String(localized: "Rating")),
    .init(id: "reply", value: "2 min", label: String(localized: "Reply time")),
    .init(id: "sales", value: "38", label: String(localized: "Sales")),
  ],
  context: .listing(
    SpearListingContext(
      id: listing.id,
      eyebrow: String(localized: "Discussing this listing"),
      title: listing.title,
      detail: listing.formattedPriceAndAvailability,
      actionTitle: String(localized: "View")
    )
  )
)

let actions = SpearChatHeaderActions(
  onBack: { router.dismissChat() },
  call: .start {
    callController.startCall()
  },
  more: .enabled { presentedSheet = .conversationActions },
  profile: .enabled { router.showProfile(userID: user.id) },
  safety: .enabled { presentedSheet = .safety },
  context: .enabled { context in router.open(context) },
  retry: .enabled { Task { await reloadHeader() } }
)

SpearChatHeader(
  state: .ready(model),
  style: .spear,
  copy: layoutDirection == .rightToLeft ? .arabic : .english,
  actions: actions
)
```


### Active-call integration

An active call owns its elapsed time and End Call action in one value:

```swift
let callControl: SpearCallControl = callSession.isActive
  ? .active(elapsedSeconds: callSession.elapsedSeconds) {
      callController.endCall()
    }
  : .start {
      callController.startCall()
    }
```

Because the end action is part of `.active`, loading and unavailable identity states still preserve a working End Call control.

### Presence integration

```swift
presence: user.isOnline
  ? .online(responseSpeed: user.isFastResponder ? .fast : .typical)
  : .offline(lastActiveAt: user.lastActiveAt)
```

The component formats relative offline time and call duration using the locale supplied by `SpearChatHeaderCopy`; callers cannot label an offline state as online.

## Use your production avatar pipeline

The header intentionally avoids `AsyncImage`. Inject the app’s existing cached and downsampled image view:

```swift
SpearChatHeader(
  state: .ready(model),
  style: .spear,
  copy: localizedHeaderCopy,
  actions: actions
) { model in
  CachedAvatarView(
    userID: model.id,
    targetPixelSize: 120,
    fallback: model.avatarFallback
  )
}
```

The supplied avatar content is clipped, framed, and decorated by the header.

## Capability examples

```swift
call: .unavailable(
  reason: String(localized: "Voice calls are unavailable for this account")
)
more: .hidden
safety: .enabled { presentedSheet = .safety }
```

A hidden capability renders no control. A disabled capability remains visible, cannot fire, and announces its reason to assistive technologies.

## Interactive preview

Open `SpearChatHeaderPreviewLab.swift` and run **Release Lab**. It includes:

- 320, 390, and 430-point widths
- standard, XXXL, and Accessibility 3 text
- LTR and Arabic RTL
- ready, loading, and unavailable states
- online, typing, viewing, offline, and active-call presence
- standard, verified seller, verified business, and restricted trust
- listing, order, support, and no-context modes

## Verification

Source-only checks available in any Swift environment include semantic type-checking and executable Foundation contracts:

```bash
python3 Scripts/verify_source_contract.py
swift-format lint --strict --recursive Sources Tests Package.swift
swiftc -parse Sources/SpearLivingChatHeader/*.swift Tests/SpearLivingChatHeaderTests/*.swift
swiftc \
  Sources/SpearLivingChatHeader/SpearChatHeaderActions.swift \
  Sources/SpearLivingChatHeader/SpearChatHeaderModels.swift \
  Sources/SpearLivingChatHeader/SpearChatHeaderCopy.swift \
  Sources/SpearLivingChatHeader/SpearConversationContext.swift \
  Scripts/FoundationContractMain.swift \
  -o /tmp/spear-contract && /tmp/spear-contract
swift package describe
```

Complete iOS Simulator build and package tests on a Mac with Xcode:

```bash
./Scripts/verify_release.sh
```

Then complete the rendered-device, accessibility, interaction, and performance matrix in [`RELEASE_QA.md`](RELEASE_QA.md).

## Final verification ledger

See [`FINAL_VERIFICATION.md`](FINAL_VERIFICATION.md) for the closed findings, fresh checks, and remaining Apple-platform certification gate.
