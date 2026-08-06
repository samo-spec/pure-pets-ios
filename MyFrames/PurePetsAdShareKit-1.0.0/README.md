# PurePetsAdShareKit

A production-focused iOS 17+ Swift Package for sharing a Pure Pets advertisement as:

- a branded 1080×1350 JPEG attachment;
- a concise English or Arabic caption;
- one canonical public URL;
- a rich iOS share-sheet preview;
- a premium SwiftUI share button;
- privacy-safe completion analytics.

The package uses the system share sheet. WhatsApp appears when installed and when it accepts the supplied image and text items. The package deliberately avoids private WhatsApp URL schemes and does not promise third-party caption layout.

## Requirements

- iOS 17+
- Swift 5.9+
- Xcode 15+; Xcode 16+ recommended for release verification
- No third-party dependencies

## Add the package

### Local package

Copy this directory into your repository, for example:

```text
MyFrames/PurePetsAdShareKit
```

In Xcode, choose **File → Add Package Dependencies → Add Local** and select the package directory.

For another Swift package:

```swift
.package(path: "../PurePetsAdShareKit")
```

Then add:

```swift
.product(
    name: "PurePetsAdShareKit",
    package: "PurePetsAdShareKit"
)
```

## One-line SwiftUI integration

```swift
import PurePetsAdShareKit
import SwiftUI

struct AdDetailsView: View {
    let sharePayload: PPAdSharePayload

    var body: some View {
        PPAdShareButton(payload: sharePayload)
            .padding(.horizontal, 20)
    }
}
```

When `imageSource` is omitted, the package uses `sharePayload.imageURL`.

Create the payload from public backend values only:

```swift
let payload = try PPAdSharePayload(
    id: ad.publicID,
    title: ad.title,
    formattedPrice: ad.formattedPrice,
    location: ad.publicLocation,
    shortDescription: ad.publicSummary,
    attributes: [
        .init(id: "vaccinated", title: "Vaccinated"),
        .init(id: "gender", title: "Male"),
        .init(id: "age", title: "3 months")
    ],
    imageURL: ad.primaryImageURL,
    canonicalURL: ad.publicWebURL,
    sellerDisplayName: ad.publicSellerName
)
```

## Use an already cached image

This avoids another network request:

```swift
PPAdShareButton(
    payload: payload,
    imageSource: .image(cachedUIImage)
)
```

Other image sources:

```swift
.image(uiImage)
.data(jpegData)
.remote(imageURL)
```

## Custom premium label

```swift
PPAdShareButton(
    payload: payload,
    configuration: .purePets
) { phase, copy in
    Label(
        phase == .preparing ? copy.preparingTitle : copy.buttonTitle,
        systemImage: phase == .preparing
            ? "hourglass"
            : "square.and.arrow.up"
    )
    .font(.headline)
    .frame(maxWidth: .infinity, minHeight: 54)
}
```

## Brand customization

```swift
var configuration = PPAdShareConfiguration.purePets
configuration.brandName = "Pure Pets"
configuration.logoImage = UIImage(named: "AppLogo")
configuration.brandColor = Color(hex: 0xCB2654) // Use your own Color helper.
configuration.cleansTemporaryFileAfterSharing = true

PPAdShareButton(
    payload: payload,
    configuration: configuration
)
```

## Analytics

Events contain only the public advertisement ID, activity identifier, completion state, and error code. They never include captions, recipient data, seller contact details, or message content.

```swift
let analytics = PPClosureAdShareAnalytics { event in
    analyticsClient.track(event)
}

PPAdShareButton(
    payload: payload,
    analytics: analytics
)
```

## UIKit integration

```swift
let coordinator = PPAdShareCoordinator(configuration: .purePets)

Task { @MainActor in
    try await coordinator.present(
        payload: payload,
        imageSource: .image(cachedUIImage),
        copy: .forLocale(.current),
        from: viewController,
        sourceView: shareButton
    )
}
```

The coordinator configures the required iPad popover anchor.

## Package boundaries

The package does not:

- upload or modify advertisements;
- create public web pages;
- force WhatsApp as the selected destination;
- inspect recipients;
- share phone numbers or email addresses automatically;
- use Firebase document paths as public identifiers.

See `INTEGRATION.md`, `SECURITY.md`, and `RELEASE_QA.md` before shipping.
