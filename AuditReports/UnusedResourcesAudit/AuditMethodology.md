# Audit Methodology

## Overview
Python-based read-only audit combining filesystem scanning, Xcode project parsing,
source cross-referencing, and asset catalog inspection.

## Steps
1. **Project Discovery** — locate xcodeproj, xcworkspace, Podfile, Package.swift
2. **PBXProj Parsing** — extract file references, build files, targets, build phases
3. **Filesystem Inventory** — walk repo, classify files, measure sizes
4. **Cross-Reference** — match disk files vs Xcode project membership
5. **Source Analysis** — extract declarations (ObjC @interface, Swift class/struct/enum/protocol),
   count cross-file references, detect dynamic patterns
6. **Classification** — assign each file to one of 6 categories
7. **Duplicate Detection** — MD5 content hashing
8. **Reporting** — Markdown, CSV, JSON, inventory CSV, methodology

## Classification

| Category | Meaning |
|---|---|
| CONFIRMED PROJECT ISSUE | Broken/missing Xcode ref |
| HIGH-CONFIDENCE UNUSED | No references found |
| PROBABLE UNUSED | In project but not compiled |
| MANUAL REVIEW REQUIRED | Dynamic usage possible |
| PROTECTED OR REQUIRED | Config/signing/sdk file |
| REPOSITORY HYGIENE | Temp/backup/build artifacts |

## Limitations
- Objective-C dynamic dispatch cannot be fully traced statically
- String-interpolated asset names appear unused
- CocoaPods/SPM largely excluded
- Feature-flag-gated code may appear unreferenced
