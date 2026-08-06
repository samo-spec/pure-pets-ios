# Chat Header Backend Contract

The SPEar chat header displays only values supplied by authenticated Pure Pets models. It is a presentation layer, never an authorization boundary.

## Participant source

`UserModel` supplies:

- `ID` as the stable SwiftUI identity.
- display name and avatar URL.
- `isOnline` and `lastSeen`.
- `verified`, provided Firestore/security rules prevent client writes.
- `isEffectivelyBlocked` and `isChatEffectivelyBlocked`.
- `subscriptionPlan`.
- server-owned `providerRatingValue` and `providerReviewCount`.

The iOS client no longer includes `verified` in `UserModel.toDictionary`.

## Conversation context

`ChatThreadModel` reads these Firestore fields:

```text
contextType: "pet_listing" | "order" | another supported type
contextId: canonical backend document ID
contextSnapshot: map
```

Supported listing snapshot keys:

```text
title or displayTitle: String
detail or subtitle: String?
priceText: String?
availabilityText: String?
```

Supported order snapshot keys:

```text
title: String?
orderNumber: String?
detail or statusText: String?
progress: finite Number in 0...1
```

The snapshot is for fast presentation only. Tapping the context action must resolve the live canonical document using `contextId` before a purchase, order mutation, or privileged action.

## Trust requirements

The verified badge may be shown only when all of these are true:

1. The value came from an authenticated server/admin-controlled source.
2. Firestore rules reject user writes to `verified` and provider reputation fields.
3. The account is not blocked or chat-restricted.
4. The account is provider-like (`business`, `production`, `service_provider`, or `pro`) or has server review samples.

Official support is rendered as a verified business using the canonical support identity.

## Metrics

The header currently displays only:

- provider rating;
- review count.

Both are hidden when `providerReviewCount == 0`, the rating is non-finite, or the rating is not positive.

Reply time and completed-sales count remain hidden until backend-owned aggregates exist. Do not calculate them from a locally paginated message list.

## Presence

- Typing wins over online.
- Online wins over last-seen.
- A known `lastSeen` becomes offline relative time and refreshes every minute.
- Missing `lastSeen` becomes `Activity unavailable`; it is never replaced with `Date()`.

## Safety

`Safety tools` routes through the existing `.report` host action. The host remains responsible for presenting report/block/mute guidance and enforcing backend policy.

## Release checks

1. Run the SPEar package tests.
2. Build the app against iOS 17 and the latest supported SDK.
3. Confirm the Objective-C bridge imports `contextType`, `contextId`, and `contextSnapshot` correctly.
4. Test English and Arabic, VoiceOver, Dynamic Type, Reduce Motion, loading, unknown presence, verified provider, restricted user, listing, order, and support contexts.
5. Add Firestore Emulator tests proving ordinary users cannot write trust or reputation fields.
