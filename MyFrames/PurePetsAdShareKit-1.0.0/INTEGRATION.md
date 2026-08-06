# Integration Guide

## 1. Map the backend model

Create `PPAdSharePayload` at the feature boundary. Do not make the package depend directly on Firestore, your networking layer, or your advertisement database model.

Recommended public backend contract:

```text
publicID
publicTitle
formattedPrice
publicLocation
publicSummary
publicHighlights[0...3]
primaryImageURL
publicWebURL
publicSellerDisplayName (optional)
```

Use an opaque public ID. Do not expose a Firestore path, sequential internal key, moderation ID, seller email, or phone number.

## 2. Universal Link

Use a canonical public URL such as:

```text
https://purepets.app/ads/{publicID}
```

The installed app should route it to `AdDetailsView`; browsers should receive a responsive public listing page.

Example `apple-app-site-association` structure:

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["TEAM_ID.com.purepets.ios"],
        "components": [
          { "/": "/ads/*" }
        ]
      }
    ]
  }
}
```

## 3. Open Graph metadata

The public advertisement page should provide at least:

```html
<meta property="og:title" content="Golden Retriever Puppy">
<meta property="og:type" content="website">
<meta property="og:url" content="https://purepets.app/ads/GR-2048">
<meta property="og:image" content="https://cdn.purepets.app/share/GR-2048.jpg">
<meta property="og:description" content="Vaccinated puppy available in Cairo.">
<meta property="og:site_name" content="Pure Pets">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="1200">
<meta property="og:image:alt" content="Golden Retriever puppy listed on Pure Pets">
```

This metadata is separate from the local branded JPEG. It supports recipients who open or reshare the canonical URL.

## 4. Image strategy

Preferred order:

1. Pass the already cached full-quality listing `UIImage`.
2. Pass approved image `Data` already in memory.
3. Allow the package to download `payload.imageURL`.

The default loader:

- accepts secure public HTTPS URLs only;
- limits the response to 25 MB;
- requests image content;
- uses URL cache behavior;
- downsamples through ImageIO;
- rejects invalid responses and undecodable files.

## 5. Localization

The default button reads SwiftUI's `Locale` and chooses Arabic only for an Arabic locale. Layout direction is not used to infer language.

Override copy explicitly:

```swift
PPAdShareButton(
    payload: payload,
    copy: .arabic
)
```

Create custom `PPAdShareCopy` values when your String Catalog becomes the source of truth.

## 6. WhatsApp behavior

`UIActivityViewController` supplies two items:

1. the branded JPEG file URL;
2. a caption item source containing the canonical URL and rich link metadata.

Installed destination apps decide how to consume multiple items. Test the currently supported WhatsApp version on physical devices. Do not use undocumented activity identifiers to force WhatsApp or private URL schemes to attach media.

## 7. Temporary files

The package hashes advertisement IDs before creating filenames. By default, the rendered JPEG is removed after the activity controller completes. Call `coordinator.discard(session)` if your custom presentation abandons a prepared session.
