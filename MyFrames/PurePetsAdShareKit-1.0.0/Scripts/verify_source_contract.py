#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "Sources" / "PurePetsAdShareKit"
source_text = "\n".join(path.read_text(encoding="utf-8") for path in SOURCES.glob("*.swift"))
package_text = (ROOT / "Package.swift").read_text(encoding="utf-8")
formatter_text = (SOURCES / "PPAdShareMessageFormatter.swift").read_text(encoding="utf-8")
privacy_manifest = SOURCES / "Resources" / "PrivacyInfo.xcprivacy"
privacy_text = privacy_manifest.read_text(encoding="utf-8") if privacy_manifest.exists() else ""

checks = [
    ("minimum platform is iOS 17", ".iOS(.v17)" in package_text),
    ("package has no third-party dependencies", "\n  dependencies:" not in package_text),
    ("system share controller is used", "UIActivityViewController" in source_text),
    ("share card uses ImageRenderer", "ImageRenderer" in source_text),
    ("share preview uses LPLinkMetadata", "LPLinkMetadata" in source_text),
    ("remote image loading stops while streaming", "PPAdShareBoundedImageDownloader" in source_text and "remainingCapacity" in source_text),
    ("remote redirects are revalidated", "willPerformHTTPRedirection" in source_text and "ppIsSecurePublicURL" in source_text),
    ("local and private network URLs are rejected", "ppIsPrivateOrReservedIPAddress" in source_text and "ppIsLocalHostname" in source_text),
    ("remote images are downsampled", "CGImageSourceCreateThumbnailAtIndex" in source_text),
    ("temporary filenames are hashed", "fnv1a64" in source_text),
    ("caption appends canonical URL once", "lines.append(canonicalURL)" in formatter_text),
    ("private WhatsApp URL schemes are absent", "whatsapp://" not in source_text.lower()),
    ("Firebase paths are absent", "firestore" not in source_text.lower()),
    ("phone and email fields are absent", "selleremail" not in source_text.lower() and "phonenumber" not in source_text.lower()),
    ("default button has accessibility identifier", "purepets.adshare.button" in source_text),
    ("Reduce Motion is respected", "accessibilityReduceMotion" in source_text),
    ("preparation cancellation is explicit", "preparationTask" in source_text and "Task.checkCancellation" in source_text),
    ("locale selects copy independently", "forLocale" in source_text),
    ("privacy manifest is bundled", '.process("Resources")' in package_text and privacy_manifest.exists()),
    ("file timestamp reason is declared", "NSPrivacyAccessedAPICategoryFileTimestamp" in privacy_text and "C617.1" in privacy_text),
    ("package declares no tracking", "<key>NSPrivacyTracking</key>" in privacy_text and "<false/>" in privacy_text),
]

failed = []
for name, passed in checks:
    print(f"{'PASS' if passed else 'FAIL'}: {name}")
    if not passed:
        failed.append(name)

if failed:
    print(f"\n{len(failed)} source-contract checks failed.", file=sys.stderr)
    sys.exit(1)

print(f"\nAll {len(checks)} source-contract checks passed.")
