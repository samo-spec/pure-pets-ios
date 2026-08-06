#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "[1/7] Source contracts"
python3 Scripts/verify_source_contract.py

echo "[2/7] Package and privacy manifests"
swift package dump-package >/dev/null
swift package describe >/dev/null
python3 - <<'PYMANIFEST'
import plistlib
from pathlib import Path
path = Path("Sources/PurePetsAdShareKit/Resources/PrivacyInfo.xcprivacy")
with path.open("rb") as stream:
    manifest = plistlib.load(stream)
assert manifest["NSPrivacyTracking"] is False
assert manifest["NSPrivacyCollectedDataTypes"] == []
PYMANIFEST

echo "[3/7] Foundation tests"
swift test

echo "[4/7] Swift parser"
swiftc -parse Sources/PurePetsAdShareKit/*.swift Tests/PurePetsAdShareKitTests/*.swift Examples/*.swift

echo "[5/7] Formatting"
if command -v swift-format >/dev/null 2>&1; then
  swift-format lint --strict --recursive Sources Tests Examples Package.swift
else
  echo "swift-format not installed; skipping strict format lint."
fi

echo "[6/7] Repository whitespace"
git diff --check

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "[7/7] Apple SDK gate"
  echo "xcodebuild unavailable. Run this script on macOS with Xcode 16+ to execute the iOS builds."
  exit 2
fi

echo "[7/7] Apple SDK Debug and Release builds"
DERIVED_DATA="$(mktemp -d -t purepets-adshare-derived.XXXXXX)"
trap 'rm -rf "$DERIVED_DATA"' EXIT

xcodebuild \
  -scheme PurePetsAdShareKit \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA" \
  build \
  CODE_SIGNING_ALLOWED=NO \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES

xcodebuild \
  -scheme PurePetsAdShareKit \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  build \
  CODE_SIGNING_ALLOWED=NO \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES

echo "All automated release gates passed."
