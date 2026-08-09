# Pure Lens Home card redesign evidence

Captured on 2026-08-08 from the connected physical iPhone 13 Pro Max
(iOS 26.5.2) through Xcode 26.6 and iPhone Mirroring.

## Scope

- Production code change: `HomePureLensSection` and its private support views in
  `HomeComponents.swift` only.
- Existing section identity, server-driven ordering, full-card `Button` action,
  `HomeStore`, `HomeRouter`, and `PPPureLensHostPresenter` ownership were kept.
- No Firebase, persistence, permission, analytics, or backend contract changed.

## Verified

- `xcrun swiftc -frontend -parse HomeComponents.swift`: exit 0.
- `git diff --check -- HomeComponents.swift`: exit 0.
- SwiftyMax bounded SwiftUI audit: no findings; native control,
  accessibility, Dynamic Type, RTL, Reduce Motion, and availability signals
  detected. This lexical audit is not a runtime accessibility or performance
  certification.
- SwiftyMax behavior ledger: valid, 100% of 14 required contract fields.
- Xcode GUI, scheme `Pure Pets`, destination `iPhone`: build, provisioning,
  install, and launch completed; Xcode reported `Running Pure Pets on iPhone`.
- The rendered Arabic RTL card was observed at its existing server-driven Home
  position on the physical device.
- A full-card tap opened the existing Pure Lens camera surface; the surface was
  then closed back to Home.

## Captures

- `pure-lens-card-ar-rtl-iphone13promax.jpg`
  - SHA-256: `8ff2724a9aaf69801cd741cf211191ede8b597ce6b6961a0703009ee65e45ac7`
- `pure-lens-card-route-opened-iphone13promax.jpg`
  - SHA-256: `a397f88a747836a605476d1bef5c469692bacd826283990b2a7bb93228651cc9`
- `pure-lens-camera-route-iphone13promax.jpg`
  - SHA-256: `f40306d87e88789d93618a9f293db678439d4adec42a89f8749b61ba68025cb4`

All captures are 444 x 972 baseline JFIF JPEG files from the live physical
device mirror.

## Explicit runtime boundaries

- Arabic RTL in light appearance and the tap route are runtime verified.
- English LTR, dark appearance, Increased Contrast, VoiceOver navigation,
  every Dynamic Type size, Reduce Motion behavior, and performance profiling
  were reviewed in source but not individually exercised on-device.
- The repository-wide strict SwiftFormat run is not a usable regression gate
  for this file because it reports extensive pre-existing whole-file style
  findings.
