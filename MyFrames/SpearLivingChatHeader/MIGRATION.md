# Migration from the original header

## Identity and trust

Before:

```swift
role: "Verified seller · Cairo"
isVerified: true
```

After:

```swift
trust: .verifiedSeller(role: "Seller", location: "Cairo")
```

The badge, detail line, tint, and accessibility output now come from the same state.

## Presence

Before:

```swift
SpearPresence(kind: .offline, text: "Online now")
```

After:

```swift
presence: .offline(lastActiveAt: user.lastActiveAt)
```

The enum owns the semantic state; fixed phrases come from `SpearChatHeaderCopy`.

## Conversation context

Before, callers supplied an arbitrary kind and symbol. After, use a typed case:

```swift
context: .order(
  SpearOrderContext(
    id: order.id,
    eyebrow: "Active order · SPEar protected",
    title: order.reference,
    detail: order.statusText,
    actionTitle: "Track",
    progress: order.progress
  )
)
```

The component chooses the semantic icon and clamps progress to `0...1`.

## Actions

Before, every closure defaulted to an enabled no-op. After, Back is required and all optional actions default to hidden:

```swift
SpearChatHeaderActions(
  onBack: { router.dismissChat() },
  call: .start { callController.startCall() },
  more: .hidden,
  profile: .disabled(reason: "Profile unavailable")
)
```

## Avatar loading

Before, the component used `AsyncImage`. After, provide a fallback in the model and optionally inject your production avatar view through the generic avatar closure.


## Call state

Active call state no longer lives inside `SpearPresence`. It is coupled to the required End Call action:

```swift
call: .active(elapsedSeconds: call.elapsedSeconds) {
  callController.endCall()
}
```

This prevents active-call UI without a usable way to end the call and preserves End Call during loading and unavailable header states.

## Response speed and offline time

Before:

```swift
.online(responseNote: "Replies fast")
.offline(lastSeen: "Last seen 12 minutes ago")
```

After:

```swift
.online(responseSpeed: .fast)
.offline(lastActiveAt: user.lastActiveAt)
```

Visible text and locale-specific digits are derived by `SpearChatHeaderCopy`.
