# SPEar Living Chat Header — Release QA Gate

A numerical 100/100 release score is valid only after the automated gate and this rendered-device matrix pass on the app that integrates the component.

## Automated gate

Run on macOS with Xcode 16 or newer:

```bash
./Scripts/verify_release.sh
```

The script validates source contracts, strict formatting, parsing, Foundation semantic type-checking and runtime regressions, the Swift package manifest, Debug iOS Simulator tests, and a warning-as-error Release iOS Simulator build.

## Required visual matrix

Render the **Release Lab** preview and the integrated chat screen at:

| Width | Text size | Direction | Appearance |
|---:|---|---|---|
| 320 pt | Large | LTR | Light and Dark |
| 320 pt | Accessibility 3 | RTL | Light and Dark |
| 390 pt | Extra Extra Extra Large | LTR | Light and Dark |
| 430 pt | Accessibility 5 | RTL | Light and Dark |

For every row, test ready, loading, unavailable, online, typing, viewing offer, offline, active call, standard user, verified seller, verified business, restricted account, listing, order, support, and no context.

## Accessibility gate

Use Accessibility Inspector and real assistive technologies:

- VoiceOver swipe order: Back → identity → Call → More → expanded profile/safety actions → context action.
- Collapsed identity announces name, trust state, presence, and collapsed state.
- Expanded identity announces the expanded state without duplicating child labels.
- Disabled actions announce their supplied reason.
- Voice Control can target Back, Call, More, View profile, Safety tools, context action, and Retry.
- Switch Control reaches every enabled control without entering decorative content.
- Reduce Motion leaves only static state indicators and removes continuous movement.
- Reduce Transparency replaces the material shell with the system background.
- Increased Contrast keeps boundaries and status distinctions legible.
- Bold Text does not clip the name, trust detail, status, metrics, or context.
- Grayscale preserves meaning without relying on color alone.

## Interaction gate

- Back works in loading, ready, and unavailable states.
- An active call keeps a working End Call control in loading, ready, and unavailable states.
- Hidden capabilities render no control.
- Disabled capabilities render a disabled control and announce the reason.
- No visible enabled control may have a no-op callback.
- Identity expands only when detail, metrics, profile, or safety content exists.
- Switching conversation identity collapses the previous expansion.
- Context changes do not reset the identity or trigger broad header animation.
- Active call shows one waveform animation only and always owns its End Call action.
- Typing shows typing animation only.
- Online presence shows one presence ripple only.
- Viewing, offline, listing, support, and order states have no continuous animation.

## Performance gate

Profile a Release build on the oldest supported physical device:

- SwiftUI Instruments: no broad invalidation on call timer updates.
- Time Profiler: header update work remains negligible during typing and calls.
- Animation Hitches: zero visible hitches while opening/closing the header and switching context.
- Energy Log: no elevated sustained energy impact while the chat remains idle.
- Memory Graph: no retained avatar-loading task or chat-header instance after leaving the conversation.

The component intentionally injects avatar content so the host app can use its existing cached, authenticated, downsampled image pipeline.

## UI-test identifiers

- `spear.chat.header`
- `spear.chat.header.back`
- `spear.chat.header.identity`
- `spear.chat.header.call`
- `spear.chat.header.more`
- `spear.chat.header.profile`
- `spear.chat.header.safety`
- `spear.chat.header.contextAction`
- `spear.chat.header.retry`
