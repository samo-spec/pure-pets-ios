#!/usr/bin/env bash
set -euo pipefail
export TERM="${TERM:-dumb}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

FOUNDATION_SOURCES=(
  Sources/SpearLivingChatHeader/SpearChatHeaderActions.swift
  Sources/SpearLivingChatHeader/SpearChatHeaderModels.swift
  Sources/SpearLivingChatHeader/SpearChatHeaderCopy.swift
  Sources/SpearLivingChatHeader/SpearConversationContext.swift
)

CONTRACT_BINARY="$(mktemp -t spear-foundation-contract.XXXXXX)"
DERIVED_DATA="$(mktemp -d -t spear-derived-data.XXXXXX)"
trap 'rm -f "$CONTRACT_BINARY"; rm -rf "$DERIVED_DATA"' EXIT

echo "[1/8] Source contract"
python3 Scripts/verify_source_contract.py

echo "[2/8] Swift formatting"
swift-format lint --strict --recursive Sources Tests Package.swift Scripts/FoundationContractMain.swift

echo "[3/8] Swift parser"
swiftc -parse Sources/SpearLivingChatHeader/*.swift Tests/SpearLivingChatHeaderTests/*.swift

echo "[4/8] Foundation type-check and runtime contracts"
swiftc -typecheck "${FOUNDATION_SOURCES[@]}"
swiftc "${FOUNDATION_SOURCES[@]}" Scripts/FoundationContractMain.swift -o "$CONTRACT_BINARY"
"$CONTRACT_BINARY"

echo "[5/8] Package manifest"
swift package dump-package >/dev/null
swift package describe >/dev/null

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "ERROR: xcodebuild is required for the Apple-platform release gate. Run this script on a Mac with Xcode 16 or newer." >&2
  exit 2
fi

if ! command -v xcrun >/dev/null 2>&1; then
  echo "ERROR: xcrun is unavailable." >&2
  exit 2
fi

echo "[6/8] Resolve an available iOS Simulator"
SIMULATOR_ID="$(
  xcrun simctl list devices available --json \
    | python3 -c '
import json, sys
payload = json.load(sys.stdin)
preferred = ("iPhone 16 Pro", "iPhone 16", "iPhone 15 Pro", "iPhone 15")
devices = []
for runtime, group in payload.get("devices", {}).items():
    if ".iOS-" not in runtime:
        continue
    devices.extend(device for device in group if device.get("isAvailable"))
for name in preferred:
    match = next((device for device in devices if device.get("name") == name), None)
    if match:
        print(match["udid"])
        raise SystemExit
if devices:
    print(devices[0]["udid"])
'
)"

if [[ -z "$SIMULATOR_ID" ]]; then
  echo "ERROR: no available iOS Simulator was found." >&2
  exit 2
fi

echo "[7/8] Debug iOS Simulator build and tests"
xcodebuild \
  -scheme SpearLivingChatHeader \
  -destination "platform=iOS Simulator,id=${SIMULATOR_ID}" \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA" \
  -skipPackagePluginValidation \
  test \
  CODE_SIGNING_ALLOWED=NO \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES

echo "[8/8] Release iOS Simulator build"
xcodebuild \
  -scheme SpearLivingChatHeader \
  -destination "platform=iOS Simulator,id=${SIMULATOR_ID}" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  -skipPackagePluginValidation \
  build \
  CODE_SIGNING_ALLOWED=NO \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES

echo "Automated release gate passed. Complete the physical-device, accessibility, visual, and Instruments matrix in RELEASE_QA.md."
