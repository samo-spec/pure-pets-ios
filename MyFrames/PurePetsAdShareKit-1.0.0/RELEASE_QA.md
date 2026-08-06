# Release QA

## Automated gates

Run:

```bash
./Scripts/verify.sh
```

The Linux-compatible stages validate source contracts, package structure, Foundation tests, parser compatibility, formatting when available, and whitespace. On macOS with Xcode, the script also runs warning-as-error Debug and Release iOS Simulator builds.

## Device matrix

- Minimum supported iOS 17 runtime
- Latest stable iOS runtime
- Compact iPhone width
- Current standard iPhone
- iPhone landscape
- iPad portrait and landscape
- iPad Split View

## Share destinations

Validate with current installed versions of:

- WhatsApp
- Messages
- Mail
- AirDrop
- Copy
- Save to Files

Confirm the destination receives an understandable image and caption. Destination behavior can change independently of this package.

## Functional states

- Cached `UIImage`
- Valid JPEG data
- Valid remote image
- Missing image
- Invalid URL
- HTTP error
- Oversized response
- Corrupt image
- Offline preparation
- User cancels the share sheet
- User completes sharing
- Repeated sharing of the same advertisement
- Two advertisements prepared sequentially

## Accessibility

- VoiceOver button name and hint
- Dynamic Type through Accessibility 5
- Arabic RTL
- English in an RTL test environment
- Reduce Motion
- Increased Contrast
- Bold Text
- Voice Control
- Switch Control
- Minimum target size

## Visual export

Inspect the saved JPEG for:

- exact 1080×1350 default dimensions;
- no clipping of long titles;
- correct Arabic direction;
- readable price and location;
- no private fields;
- correct logo and brand color;
- acceptable compression and file size;
- no image stretching.

## Web handoff

- Canonical URL opens the installed app
- Browser fallback works when the app is absent
- Open Graph title, image, description, and URL are correct
- Deleted or unavailable advertisements show a safe public state
- Reshared links do not expose internal IDs
