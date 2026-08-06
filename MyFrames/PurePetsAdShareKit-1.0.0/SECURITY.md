# Security and Privacy Contract

## Public-data boundary

Only pass fields already approved for public advertisement sharing. The package does not know whether a backend field is private.

Never pass:

- seller phone number or email address;
- home address or precise private location;
- Firebase document paths;
- moderation notes or restriction reasons;
- unpublished pricing;
- authentication tokens;
- private image URLs requiring long-lived credentials;
- recipient information.

## Canonical links

Use HTTPS in production. Public advertisement IDs should be opaque and non-sequential. The public page must enforce its own authorization and availability rules; a share card is never an authorization token.

## Verification and seller identity

A displayed seller name must be a reviewed public display name. Verification badges and trust decisions belong to server-authoritative systems and are outside this package.

## Analytics

`PPAdShareAnalyticsEvent` intentionally excludes caption text, advertisement description, seller identity, image URL, canonical URL, and recipients. Preserve this property when adapting events to your analytics provider.

## Remote images

The default loader limits bytes and downsample size, but the backend should also:

- serve trusted image MIME types;
- strip metadata when appropriate;
- generate bounded share variants;
- use HTTPS and short cache-safe URLs;
- prevent SVG/script content from being returned as a raster listing image.

## Temporary storage

Files are written to the system temporary directory using a hash-derived name and are removed after completion by default. iOS may still retain shared content in destination applications or system caches; the package cannot revoke copies after sharing.


## Privacy manifest

The Swift Package bundles `PrivacyInfo.xcprivacy`. It declares no tracking and no collected data. The package declares `C617.1` for app-container file timestamps because stale temporary JPEG cleanup reads modification or creation dates inside the app's temporary container.

## Remote image network boundary

The default loader accepts HTTPS only, rejects credentials, loopback, localhost, private IPv4, link-local, reserved literal addresses, local hostname suffixes, and non-global IPv6 literals. Redirect targets are validated again before they are followed. Applications with a fixed CDN should additionally allowlist that CDN at their backend boundary before constructing `PPAdSharePayload`.
