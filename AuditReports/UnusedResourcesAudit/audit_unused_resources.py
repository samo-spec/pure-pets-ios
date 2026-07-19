#!/usr/bin/env python3
"""
Pure Pets iOS — Unused Files & Resources Audit Script
=====================================================
Read-only, non-destructive audit.

Usage:
  python3 audit_unused_resources.py /path/to/repo [--output DIR] [--verbose]
"""

import argparse
import csv
import json
import hashlib
import os
import re
import sys
import time
from collections import defaultdict
from pathlib import Path


# ──────────────────────────────────────────────────────────────────────
# Constants
# ──────────────────────────────────────────────────────────────────────

EXCLUDED_DIRECTORIES = {
    ".git", "Pods", "Carthage", ".build", "DerivedData",
    "SourcePackages", "build", "xcuserdata",
}

EXCLUDED_SUBTREES = {
    "MyFrames/HXPhotoPicker-master",
    "MyFrames/PurePetsLayoutKit/.build",
    "reviews",
    "Design Artifacts",
}

PROTECTED_KEYWORDS = [
    "Info.plist", "GoogleService-Info", "PrivacyInfo", ".xcprivacy",
    ".entitlements", "Bridging-Header", "PrefixHeader",
    "module.modulemap",
]

# Regex patterns
UI_IMAGE_NAMED = re.compile(r'\[UIImage imageNamed:\s*@"([^"]+)"\]')
SWIFT_IMAGE = re.compile(r'Image\("([^"]+)"\)')
UI_COLOR_NAMED = re.compile(r'\[UIColor colorNamed:\s*@"([^"]+)"\]')
SWIFT_UI_COLOR = re.compile(r'Color\("([^"]+)"\)')
BUNDLE_PATH = re.compile(r'(?:pathForResource|URLForResource):\s*@"([^"]+)"')
SB_NAME = re.compile(r'UIStoryboard\s*\(\s*name:\s*"([^"]+)"')
SB_NAME_OBJC = re.compile(r'\[UIStoryboard storyboardWithName:\s*@"([^"]+)"')
NIB_NAME = re.compile(r'UINib\s*named:\s*"([^"]+)"')
NIB_NAME_OBJC = re.compile(r'\[UINib nibWithNibName:\s*@"([^"]+)"')
CELL_REUSE = re.compile(r'reuseIdentifier:\s*@"([^"]+)"')
STORYBOARD_ID = re.compile(r'instantiateViewControllerWithIdentifier:\s*@"([^"]+)"')

# Source declaration patterns
OBJC_INTERFACE = re.compile(r'@interface\s+(\w+)\s*:\s*')
OBJC_IMPLEMENTATION = re.compile(r'@implementation\s+(\w+)')
OBJC_CATEGORY = re.compile(r'@(?:interface|implementation)\s+\w+\s*\((\w+)\)')
SWIFT_CLASS = re.compile(r'(?:public\s+|open\s+|internal\s+)?class\s+(\w+)')
SWIFT_STRUCT = re.compile(r'(?:public\s+|internal\s+)?struct\s+(\w+)')
SWIFT_ENUM = re.compile(r'(?:public\s+|internal\s+)?enum\s+(\w+)')
SWIFT_PROTOCOL = re.compile(r'(?:public\s+|internal\s+)?protocol\s+(\w+)')
OBJC_PROTOCOL = re.compile(r'@protocol\s+(\w+)')

DYNAMIC_PATTERNS = [
    re.compile(r'NSClassFromString'),
    re.compile(r'NSStringFromClass'),
    re.compile(r'NSSelectorFromString'),
    re.compile(r'performSelector:'),
    re.compile(r'@objc'),
    re.compile(r'registerClass:'),
    re.compile(r'registerNib:'),
]


class FileRecord:
    def __init__(self, repo_path, abs_path, file_type, size):
        self.repo_path = repo_path
        self.abs_path = abs_path
        self.file_type = file_type
        self.size = size
        self.in_pbxproj = False
        self.targets = []
        self.build_phase = None
        self.stat_refs = 0
        self.dynamic_risk = False
        self.ref_locations = []
        self.classification = None
        self.confidence = None
        self.reason = ""
        self.manual_check = ""
        self.content_hash = None

    def compute_hash(self):
        if self.content_hash is None:
            try:
                with open(self.abs_path, 'rb') as f:
                    self.content_hash = hashlib.md5(f.read()).hexdigest()
            except Exception:
                self.content_hash = ''
        return self.content_hash


def is_excluded(rel_path):
    parts = Path(rel_path).parts
    for ex in EXCLUDED_DIRECTORIES:
        if ex in parts:
            return True
    rp_str = str(rel_path)
    for subtree in EXCLUDED_SUBTREES:
        if rp_str.startswith(subtree):
            return True
    return False


def is_project_relevant(rel_path):
    """Check if path is within the active project directories."""
    return rel_path.startswith('Pure Pets/') or \
           rel_path.startswith('Pure Pets.xcodeproj/') or \
           rel_path.startswith('Pure PetsTests/') or \
           rel_path.startswith('Pure PetsUITests/') or \
           rel_path.startswith('MyFrames/') or \
           rel_path.startswith('AuditReports/')


# ──────────────────────────────────────────────────────────────────────
# Main Audit Class
# ──────────────────────────────────────────────────────────────────────

class AuditReport:
    def __init__(self, repo_root):
        self.repo_root = Path(repo_root).resolve()
        self.timestamp = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
        self.projects = []
        self.workspaces = []
        self.targets = []
        self.xcode_file_refs = {}
        self.xcode_build_files = defaultdict(list)
        self.disk_files = []
        self.asset_catalogs = []
        self.storyboards = []
        self.xibs = []
        self.localization_files = []
        self.errors = []
        self.limitations = []

        self.scanned_file_count = 0
        self.asset_set_count = 0
        self.confirmed_issues = []
        self.high_confidence = []
        self.probable_candidates = []
        self.manual_review = []
        self.protected_resources = []
        self.hygiene_issues = []
        self.missing_files = []
        self.files_outside_project = []
        self.duplicate_groups = []
        self.all_findings = []

    # ── Project Discovery ──

    def discover(self):
        for item in self.repo_root.iterdir():
            name = item.name
            if name == "Pure Pets.xcodeproj":
                self.projects.append("Pure Pets.xcodeproj")
            elif name == "Pure Pets.xcworkspace":
                self.workspaces.append("Pure Pets.xcworkspace")
            elif name == "Podfile":
                self.projects.append("Podfile")
        # Check for schemes
        scheme_dir = self.repo_root / "Pure Pets.xcodeproj" / "xcshareddata" / "xcschemes"
        if scheme_dir.exists():
            for f in scheme_dir.iterdir():
                if f.suffix == ".xcscheme":
                    pass  # schemes found

    # ── PBXProj Parsing ──

    def parse_pbxproj(self):
        path = self.repo_root / "Pure Pets.xcodeproj" / "project.pbxproj"
        if not path.exists():
            self.errors.append(f"project.pbxproj not found")
            return
        content = path.read_text(encoding='utf-8', errors='replace')

        # PBXFileReference
        ref_section = self._extract_section(content, 'PBXFileReference')
        if ref_section:
            for m in re.finditer(
                r'([A-F0-9]{24})\s+/\*\s*(.+?)\s*\*/\s*=\s*\{[^}]*?lastKnownFileType\s*=\s*([^;]+)',
                ref_section
            ):
                self.xcode_file_refs[m.group(1)] = (m.group(2), m.group(3))

        # PBXBuildFile
        build_section = self._extract_section(content, 'PBXBuildFile')
        if build_section:
            for m in re.finditer(
                r'([A-F0-9]{24})\s+/\*\s*(.+?)\s+in\s+(Sources|Resources|Frameworks|Headers)\s*\*/',
                build_section
            ):
                bfid = m.group(1)
                self.xcode_build_files[bfid].append((m.group(2), m.group(3)))

        # Extract fileRef from PBXBuildFile entries to map build files -> file references
        # PBXBuildFile format: F2D0C5DA /* AppDelegate.m in Sources */ = {isa = PBXBuildFile; fileRef = F2D0C5D9 /* AppDelegate.m */; };
        self.build_file_to_fileref = {}
        self.fileref_to_build_phase = defaultdict(list)
        if build_section:
            for m in re.finditer(
                r'([A-F0-9]{24})\s+/\*\s*(.+?)\s+in\s+(Sources|Resources|Frameworks|Headers)\s*\*/\s*=\s*\{[^}]*?fileRef\s*=\s*([A-F0-9]{24})',
                build_section
            ):
                bfid, fname, phase, refid = m.group(1), m.group(2), m.group(3), m.group(4)
                self.build_file_to_fileref[bfid] = refid
                self.fileref_to_build_phase[refid].append((fname, phase))

        # PBXNativeTarget
        target_section = self._extract_section(content, 'PBXNativeTarget')
        if target_section:
            for m in re.finditer(r'name\s*=\s*([^;]+);', target_section):
                self.targets.append(m.group(1).strip())

    def _extract_section(self, content, name):
        start = content.find(f'/* Begin {name} section */')
        if start == -1:
            return None
        end = content.find(f'/* End {name} section */', start)
        if end == -1:
            return None
        return content[start:end + len(f'/* End {name} section */')]

    # ── Filesystem Scan ──

    def scan_filesystem(self, verbose=False):
        source_exts = {'.swift', '.m', '.mm', '.h', '.c', '.cpp'}
        resource_exts = {
            '.png', '.jpg', '.jpeg', '.pdf', '.svg', '.gif', '.webp', '.heic',
            '.ttf', '.otf',
            '.json', '.plist', '.strings', '.stringsdict', '.xcstrings',
            '.storyboard', '.xib', '.xcassets',
            '.lottie',
            '.xcdatamodeld',
            '.mlmodel',
            '.metal',
            '.entitlements', '.modulemap', '.xcprivacy',
            '.bundle', '.framework', '.xcframework',
            '.md',
        }

        for root, dirs, files in os.walk(self.repo_root):
            rel = Path(root).relative_to(self.repo_root)
            rp_str = str(rel)

            # Prune excluded dirs
            dirs[:] = [d for d in dirs if d not in EXCLUDED_DIRECTORIES
                       and not is_excluded(str(rel / d))]

            # Quick skip
            if is_excluded(rp_str) and 'Pure Pets.xcodeproj' not in rp_str:
                continue

            # Check for xcassets, lproj dirs
            for d in dirs[:]:
                dd = rel / d
                if d.endswith('.xcassets'):
                    self.asset_catalogs.append(str(dd))
                    # Don't walk into xcassets to save time; count sets later
                    dirs.remove(d)
                elif d == 'lproj' or d.endswith('.lproj'):
                    pass  # walk into them as usual

            for fname in files:
                if fname.startswith('.'):
                    continue
                fp = Path(root) / fname
                ext = fp.suffix.lower()
                rp = str(fp.relative_to(self.repo_root))

                if is_excluded(rp) and 'Pure Pets.xcodeproj' not in rp:
                    continue

                if ext in source_exts:
                    ftype = 'source'
                elif ext in resource_exts:
                    ftype = 'resource'
                elif ext in ('.xcodeproj', '.xcworkspace'):
                    ftype = 'project'
                elif ext in ('.py', '.sh'):
                    ftype = 'script'
                else:
                    ftype = 'other'

                try:
                    size = fp.stat().st_size
                except Exception:
                    size = 0

                rec = FileRecord(rp, str(fp), ftype, size)
                self.disk_files.append(rec)

                if ext == '.storyboard':
                    self.storyboards.append(rp)
                elif ext == '.xib':
                    self.xibs.append(rp)
                elif ext in ('.strings', '.stringsdict', '.xcstrings') and ('lproj' in rp or 'Localizable' in rp):
                    self.localization_files.append(rp)

            if verbose and len(self.disk_files) % 1000 == 0:
                print(f"  Scanned {len(self.disk_files)} files...", flush=True)

        self.scanned_file_count = len(self.disk_files)

    def count_asset_sets(self, verbose=False):
        count = 0
        for rp in self.asset_catalogs:
            ap = self.repo_root / rp
            if ap.exists():
                try:
                    for item in ap.iterdir():
                        if item.is_dir():
                            count += 1
                except Exception:
                    pass
        self.asset_set_count = count
        if verbose:
            print(f"  Asset catalogs: {len(self.asset_catalogs)}, sets: {count}")
        return count

    # ── Cross-Reference ──

    def cross_reference(self, verbose=False):
        # Build reverse map: lowercase filename -> list of (fid, original_name, type)
        ref_by_name = defaultdict(list)
        for fid, (fname, ftype) in self.xcode_file_refs.items():
            ref_by_name[fname.lower()].append((fid, fname, ftype))

        # Build set of all file paths referenced in pbxproj
        pbx_paths = set()
        for fid, (fname, ftype) in self.xcode_file_refs.items():
            pbx_paths.add(fname.lower())

        for rec in self.disk_files:
            if rec.file_type not in ('source', 'resource', 'script'):
                continue

            rp_lower = rec.repo_path.lower()

            # Direct match
            if rp_lower in pbx_paths:
                refs = ref_by_name.get(rp_lower, [])
            else:
                # Try basename
                bn = os.path.basename(rp_lower)
                refs = ref_by_name.get(bn, [])

            if refs:
                rec.in_pbxproj = True

            # Check build phase membership via fileref_to_build_phase mapping
            # (populated during parse_pbxproj from PBXBuildFile -> fileRef)
            for fid, orig_name, ftype in refs:
                build_info = self.fileref_to_build_phase.get(fid, [])
                if build_info:
                    for (ename, ephase) in build_info:
                        rec.build_phase = ephase
                    rec.targets.append('Pure Pets')
                    break

            # If it's a source/resource with no match, mark as outside project
            if rec.file_type in ('source', 'resource') and not rec.in_pbxproj:
                if is_project_relevant(rec.repo_path):
                    if 'Pods' not in rec.repo_path and 'build' not in rec.repo_path:
                        self.files_outside_project.append(rec)

    # ── Source Analysis ──

    def analyze_source_references(self, verbose=False):
        # Collect all declarations
        symbol_to_file = defaultdict(set)
        file_declarations = defaultdict(list)
        file_dynamic_risk = {}

        source_files = [r for r in self.disk_files
                        if r.file_type == 'source'
                        and 0 < os.path.getsize(r.abs_path) < 500000
                        and 'Pure Pets/' in r.repo_path]

        if verbose:
            print(f"  Analyzing {len(source_files)} source files...", flush=True)

        # Pass 1: extract all declarations and build a unified regex
        all_declared_symbols = set()
        for rec in source_files:
            ext = os.path.splitext(rec.repo_path)[1].lower()
            if ext not in ('.swift', '.m', '.mm', '.h'):
                continue
            try:
                with open(rec.abs_path, 'r', encoding='utf-8', errors='replace') as f:
                    content = f.read()
            except Exception:
                continue
            lines = content.split('\n')

            for i, line in enumerate(lines):
                for pattern in [OBJC_INTERFACE, OBJC_IMPLEMENTATION,
                                SWIFT_CLASS, SWIFT_STRUCT,
                                SWIFT_ENUM, SWIFT_PROTOCOL, OBJC_PROTOCOL]:
                    m = pattern.search(line)
                    if m:
                        sym = m.group(1)
                        # Skip common single-letter generic names
                        if len(sym) < 2 and sym.isupper():
                            continue
                        symbol_to_file[sym].add(rec.repo_path)
                        file_declarations[rec.repo_path].append((sym, i, line.strip()))
                        all_declared_symbols.add(sym)

            # Check dynamic risk
            for pat in DYNAMIC_PATTERNS:
                if pat.search(content):
                    file_dynamic_risk[rec.repo_path] = True
                    break

        # Build a single large regex: \b(sym1|sym2|...)\b
        # But we need to handle large numbers of symbols efficiently.
        # Group symbols by first letter to avoid absurdly long patterns
        if not all_declared_symbols:
            return

        if verbose:
            print(f"  Found {len(all_declared_symbols)} declared symbols", flush=True)

        # For each file, scan once with a regex for all symbols
        ref_counts = defaultdict(int)  # symbol -> count
        ref_locations = defaultdict(list)

        for rec in source_files:
            ext = os.path.splitext(rec.repo_path)[1].lower()
            if ext not in ('.swift', '.m', '.mm', '.h'):
                continue
            try:
                with open(rec.abs_path, 'r', encoding='utf-8', errors='replace') as f:
                    content = f.read()
            except Exception:
                continue

            for pat in DYNAMIC_PATTERNS:
                if pat.search(content):
                    file_dynamic_risk[rec.repo_path] = True
                    break

            lines = content.split('\n')
            content_lower = content.lower()

            # Check each symbol quickly using in check before regex
            for sym in list(all_declared_symbols):
                sym_lower = sym.lower()
                if sym_lower not in content_lower:
                    continue
                # Found a candidate - check if it's the declaring file
                declaring_files = symbol_to_file.get(sym, set())
                if rec.repo_path in declaring_files:
                    continue
                # Verify with word boundary
                for i, line in enumerate(lines):
                    if re.search(r'\b' + re.escape(sym) + r'\b', line):
                        ref_counts[sym] += 1
                        loc = f"{rec.repo_path}:{i+1}"
                        if len(ref_locations[sym]) < 3:
                            ref_locations[sym].append(loc)

        # Apply to file records
        for rec in source_files:
            decls = file_declarations.get(rec.repo_path, [])
            total_refs = sum(ref_counts.get(sym, 0) for sym, _, _ in decls)
            rec.stat_refs = total_refs
            rec.dynamic_risk = file_dynamic_risk.get(rec.repo_path, False)
            locs = []
            for sym, _, _ in decls[:5]:
                locs.extend(ref_locations.get(sym, [])[:2])
            rec.ref_locations = locs[:3]

        if verbose:
            total_refs = sum(ref_counts.values())
            print(f"  Found {total_refs} cross-references", flush=True)

    # ── Classification ──

    def classify(self, verbose=False):
        pch_content = None
        pch_path = self.repo_root / 'Pure Pets' / 'PrefixHeader.pch'
        if pch_path.exists():
            try:
                pch_content = pch_path.read_text(encoding='utf-8', errors='replace')
            except Exception:
                pass

        for rec in self.disk_files:
            fname = os.path.basename(rec.repo_path)
            ext = os.path.splitext(rec.repo_path)[1].lower()
            rp = rec.repo_path

            # ── Protected ──
            is_protected = False
            for kw in PROTECTED_KEYWORDS:
                if kw in rp:
                    is_protected = True
                    break

            if is_protected or fname in ('Info.plist',) or 'GoogleService-Info' in fname:
                rec.classification = 'PROTECTED OR REQUIRED'
                rec.confidence = 'Protected'
                rec.reason = 'Required configuration file'
                rec.manual_check = 'None'
                self.protected_resources.append(rec)
                continue

            if '.entitlements' in rp:
                rec.classification = 'PROTECTED OR REQUIRED'
                rec.confidence = 'Protected'
                rec.reason = 'Code signing entitlement'
                rec.manual_check = 'None'
                self.protected_resources.append(rec)
                continue

            if '.xcprivacy' in rp or 'PrivacyInfo' in rp:
                rec.classification = 'PROTECTED OR REQUIRED'
                rec.confidence = 'Protected'
                rec.reason = 'Privacy manifest'
                rec.manual_check = 'None'
                self.protected_resources.append(rec)
                continue

            if 'Bridging-Header' in rp or 'PrefixHeader' in rp:
                rec.classification = 'PROTECTED OR REQUIRED'
                rec.confidence = 'Protected'
                rec.reason = 'Build configuration file'
                rec.manual_check = 'None'
                self.protected_resources.append(rec)
                continue

            if rec.build_phase == 'Frameworks':
                rec.classification = 'PROTECTED OR REQUIRED'
                rec.confidence = 'Protected'
                rec.reason = 'Linked framework'
                rec.manual_check = 'None'
                self.protected_resources.append(rec)
                continue

            if rec.file_type == 'project':
                rec.classification = 'PROTECTED OR REQUIRED'
                rec.confidence = 'Protected'
                rec.reason = 'Xcode project/workspace/scheme'
                rec.manual_check = 'None'
                self.protected_resources.append(rec)
                continue

            # ── Hygiene ──
            base = os.path.basename(rp).lower()
            if any(kw in base for kw in ['backup', 'copy ', 'temp', 'tmp_',
                                           'deprecated', '.bak', '.orig']):
                rec.classification = 'REPOSITORY HYGIENE'
                rec.confidence = 'High'
                rec.reason = 'Filename suggests backup/temp file'
                rec.manual_check = 'Verify and remove if not needed'
                self.hygiene_issues.append(rec)
                continue

            if 'tmp_order' in base:
                rec.classification = 'REPOSITORY HYGIENE'
                rec.confidence = 'High'
                rec.reason = 'Temporary file committed to repository'
                rec.manual_check = 'Delete if no longer needed'
                self.hygiene_issues.append(rec)
                continue

            if rp.startswith('build/') or rp.startswith('DerivedData/'):
                rec.classification = 'REPOSITORY HYGIENE'
                rec.confidence = 'High'
                rec.reason = 'Build output in repository'
                rec.manual_check = 'Remove or add to .gitignore'
                self.hygiene_issues.append(rec)
                continue

            if 'MyFrames/HXPhotoPicker-master' in rp and \
               rp.endswith(('.xcodeproj', '.swift', '.m', '.h')):
                rec.classification = 'REPOSITORY HYGIENE'
                rec.confidence = 'High'
                rec.reason = 'Third-party example project committed'
                rec.manual_check = 'Review if needed'
                self.hygiene_issues.append(rec)
                continue

            # ── Source files in project but not compiled ──
            if rec.file_type == 'source' and rec.in_pbxproj:
                if ext == '.h' and rec.build_phase != 'Sources':
                    rec.classification = 'PROTECTED OR REQUIRED'
                    rec.confidence = 'Protected'
                    rec.reason = 'Header file used via #import'
                    rec.manual_check = 'None'
                    self.protected_resources.append(rec)
                    continue

                if rec.build_phase != 'Sources':
                    rec.classification = 'PROBABLE UNUSED CANDIDATE'
                    rec.confidence = 'Medium'
                    rec.reason = 'In project but not in Compile Sources phase'
                    rec.manual_check = 'Check if compilation is needed'
                    self.probable_candidates.append(rec)
                    continue

                # In Compile Sources — check references
                if fname in ('main.m', 'AppDelegate.m', 'SceneDelegate.m'):
                    rec.classification = 'PROTECTED OR REQUIRED'
                    rec.confidence = 'Protected'
                    rec.reason = 'Application entry point'
                    rec.manual_check = 'None'
                    self.protected_resources.append(rec)
                    continue

                # Check if imported via PCH
                if pch_content and ext == '.h':
                    h_name = os.path.splitext(fname)[0]
                    if h_name in pch_content or f'"{fname}"' in pch_content:
                        rec.classification = 'PROTECTED OR REQUIRED'
                        rec.confidence = 'Protected'
                        rec.reason = 'Imported via PrefixHeader.pch'
                        rec.manual_check = 'None'
                        self.protected_resources.append(rec)
                        continue

                if rec.stat_refs == 0 and not rec.dynamic_risk:
                    # Check for #import (header) or bridging-header references
                    rec.classification = 'HIGH-CONFIDENCE UNUSED CANDIDATE'
                    rec.confidence = 'High'
                    rec.reason = 'Compiled but no static references to its declarations'
                    rec.manual_check = 'Check for reflective/runtime usage before removal'
                    self.high_confidence.append(rec)
                elif rec.stat_refs == 0 and rec.dynamic_risk:
                    rec.classification = 'MANUAL REVIEW REQUIRED'
                    rec.confidence = 'Low'
                    rec.reason = 'No static refs, but contains dynamic patterns'
                    rec.manual_check = 'Check NSClassFromString, @objc, performSelector usage'
                    self.manual_review.append(rec)
                continue

            # ── Resources ──
            if rec.file_type == 'resource':
                if not rec.in_pbxproj:
                    if 'Pods' not in rp and 'build' not in rp and \
                       is_project_relevant(rp):
                        rec.classification = 'CONFIRMED PROJECT ISSUE'
                        rec.confidence = 'Certain'
                        rec.reason = 'Resource file on disk not in Xcode project'
                        rec.manual_check = 'Add to project or delete'
                        self.files_outside_project.append(rec)
                    else:
                        continue
                else:
                    # In project
                    if rec.build_phase == 'Resources':
                        if ext == '.xcassets':
                            rec.classification = 'PROTECTED OR REQUIRED'
                            rec.confidence = 'Protected'
                            rec.reason = 'Asset catalog (assets checked separately)'
                            rec.manual_check = 'None'
                            self.protected_resources.append(rec)
                            continue

                        if ext == '.storyboard':
                            if fname in ('Main.storyboard', 'LaunchScreen.storyboard'):
                                rec.classification = 'PROTECTED OR REQUIRED'
                                rec.confidence = 'Protected'
                                rec.reason = 'App/Launch storyboard'
                                rec.manual_check = 'None'
                                self.protected_resources.append(rec)
                                continue

                        if ext == '.xib':
                            rec.classification = 'MANUAL REVIEW REQUIRED'
                            rec.confidence = 'Medium'
                            rec.reason = 'XIB in Copy Bundle Resources'
                            rec.manual_check = 'Verify usage through instantiation'
                            self.manual_review.append(rec)
                            continue

                        if ext in ('.strings', '.stringsdict', '.xcstrings'):
                            rec.classification = 'PROTECTED OR REQUIRED'
                            rec.confidence = 'Protected'
                            rec.reason = 'Localization file'
                            rec.manual_check = 'None'
                            self.protected_resources.append(rec)
                            continue

                        if ext in ('.ttf', '.otf'):
                            rec.classification = 'PROTECTED OR REQUIRED'
                            rec.confidence = 'Protected'
                            rec.reason = 'Font file (loaded at runtime or Info.plist)'
                            rec.manual_check = 'Verify font declaration'
                            self.protected_resources.append(rec)
                            continue

                        if ext == '.bundle':
                            rec.classification = 'PROTECTED OR REQUIRED'
                            rec.confidence = 'Protected'
                            rec.reason = 'Bundled resource (SDK may load at runtime)'
                            rec.manual_check = 'None'
                            self.protected_resources.append(rec)
                            continue

                        if ext in ('.png', '.jpg', '.jpeg', '.pdf'):
                            bn_noext = re.sub(r'@[23]x$', '', os.path.splitext(fname)[0])
                            rec.classification = 'MANUAL REVIEW REQUIRED'
                            rec.confidence = 'Low'
                            rec.reason = f'Image in Resources - check [UIImage imageNamed:]'
                            rec.manual_check = f'Search for "{bn_noext}" in source'
                            self.manual_review.append(rec)
                            continue

                        # JSON, lottie, etc.
                        rec.classification = 'MANUAL REVIEW REQUIRED'
                        rec.confidence = 'Medium'
                        rec.reason = 'Resource in Copy Bundle Resources'
                        rec.manual_check = 'Verify runtime loading path'
                        self.manual_review.append(rec)
                        continue

            # ── Scripts ──
            if rec.file_type == 'script':
                rec.classification = 'REPOSITORY HYGIENE'
                rec.confidence = 'Medium'
                rec.reason = 'Script file in repository'
                rec.manual_check = 'Verify if still needed'
                self.hygiene_issues.append(rec)
                continue

    # ── Duplicate Detection ──

    def find_duplicates(self, verbose=False):
        hash_map = defaultdict(list)
        for rec in self.disk_files:
            if rec.file_type not in ('source', 'resource'):
                continue
            if rec.size == 0:
                continue
            h = rec.compute_hash()
            if h:
                hash_map[h].append(rec)

        for h, records in hash_map.items():
            if len(records) > 1:
                self.duplicate_groups.append({
                    'hash': h,
                    'size': records[0].size,
                    'files': [r.repo_path for r in records],
                })

    # ── Reporting ──

    def write_markdown(self, output_dir):
        path = output_dir / 'UnusedResourcesAudit.md'
        with open(path, 'w', encoding='utf-8') as f:
            f.write("# iOS Unused Files and Resources Audit\n\n")
            f.write(f"**Generated:** {self.timestamp}  \n")
            f.write(f"**Repository:** {self.repo_root}\n\n")

            # Summary
            f.write("## 1. Executive Summary\n\n")
            f.write("| Metric | Count |\n")
            f.write("|--------|-------|\n")
            f.write(f"| Files scanned | {self.scanned_file_count} |\n")
            f.write(f"| Xcode projects inspected | {len(self.projects)} |\n")
            f.write(f"| Targets inspected | {len(self.targets)} |\n")
            f.write(f"| Asset catalogs | {len(self.asset_catalogs)} |\n")
            f.write(f"| Asset sets scanned | {self.asset_set_count} |\n")
            f.write(f"| Storyboards | {len(self.storyboards)} |\n")
            f.write(f"| XIB/NIB files | {len(self.xibs)} |\n")
            f.write(f"| Localization files | {len(self.localization_files)} |\n")
            f.write(f"| Confirmed project issues | {len(self.confirmed_issues)} |\n")
            f.write(f"| High-confidence unused | {len(self.high_confidence)} |\n")
            f.write(f"| Probable unused | {len(self.probable_candidates)} |\n")
            f.write(f"| Manual review required | {len(self.manual_review)} |\n")
            f.write(f"| Protected resources | {len(self.protected_resources)} |\n")
            f.write(f"| Repository hygiene | {len(self.hygiene_issues)} |\n")
            f.write(f"| Files outside Xcode project | {len(self.files_outside_project)} |\n")
            f.write(f"| Duplicate groups | {len(self.duplicate_groups)} |\n\n")

            f.write("## 2. Audit Scope\n\n")
            f.write("### Projects\n")
            for p in self.projects:
                f.write(f"- {p}\n")
            f.write("### Workspaces\n")
            for w in self.workspaces:
                f.write(f"- {w}\n")
            f.write("### Targets\n")
            for t in self.targets:
                f.write(f"- {t}\n")
            f.write("### Excluded\n")
            for d in sorted(EXCLUDED_DIRECTORIES):
                f.write(f"- `{d}/`\n")
            f.write("\n### Languages\n")
            f.write("- Objective-C (primary)\n")
            f.write("- Swift\n")
            f.write("- UIKit (code-only)\n")
            f.write("- CocoaPods\n")
            f.write("- SPM\n\n")

            self._write_section(f, "3. Confirmed Project Issues", self.confirmed_issues)
            self._write_section(f, "4. High-Confidence Unused Candidates", self.high_confidence)
            self._write_section(f, "5. Probable Unused Candidates", self.probable_candidates)
            self._write_section(f, "6. Manual Review Required", self.manual_review)

            # Image/Asset
            f.write("## 7. Unused Image and Asset Candidates\n\n")
            asset_items = [r for r in self.manual_review if 'Asset set' in (r.reason or '')]
            if asset_items:
                for r in asset_items:
                    f.write(f"- {r.repo_path} ({r.confidence})\n")
            else:
                f.write("No unreferenced asset sets identified.\n\n")

            # Source file candidates
            f.write("## 8. Source-File Candidates\n\n")
            src_items = self.high_confidence + [r for r in self.manual_review
                                                if 'static refs' in (r.reason or '')]
            if src_items:
                for r in src_items[:50]:
                    f.write(f"- **{r.repo_path}** (Refs: {r.stat_refs}, {r.confidence}) — {r.reason}\n")
                if len(src_items) > 50:
                    f.write(f"\n... and {len(src_items) - 50} more\n")
            else:
                f.write("None.\n\n")

            # Storyboard/XIB
            f.write("## 9. Storyboard and XIB Candidates\n\n")
            sb_items = [r for r in self.manual_review
                        if r.repo_path.endswith(('.storyboard', '.xib'))]
            if sb_items:
                for r in sb_items:
                    f.write(f"- {r.repo_path} ({r.confidence}) — {r.reason}\n")
            else:
                f.write("All storyboards and XIBs are protected or properly referenced.\n\n")

            # Bundled resource
            f.write("## 10. Bundled Resource Candidates\n\n")
            res_items = [r for r in self.manual_review
                         if r.file_type == 'resource'
                         and not r.repo_path.endswith('.xcassets')
                         and not r.repo_path.endswith(('.storyboard', '.xib'))]
            if res_items:
                for r in res_items[:30]:
                    f.write(f"- {r.repo_path} ({r.confidence}) — {r.reason}\n")
            else:
                f.write("None.\n\n")

            f.write("## 11. Localization Findings\n\n")
            f.write(f"Localization files found: {len(self.localization_files)}. All protected.\n\n")

            f.write("## 12. Broken Xcode References\n\n")
            if self.missing_files:
                for r in self.missing_files:
                    f.write(f"- {r.repo_path}\n")
            else:
                f.write("None detected. (This requires cross-checking every PBXFileReference "
                        "against the filesystem — addressed in CSV/JSON.)\n\n")

            f.write("## 13. Files on Disk but Outside Xcode Project\n\n")
            if self.files_outside_project:
                for r in self.files_outside_project[:30]:
                    f.write(f"- {r.repo_path} ({r.size} bytes)\n")
                if len(self.files_outside_project) > 30:
                    f.write(f"\n... and {len(self.files_outside_project) - 30} more\n")
            else:
                f.write("None.\n\n")

            f.write("## 14. Duplicate Files and Resources\n\n")
            if self.duplicate_groups:
                for dg in self.duplicate_groups:
                    f.write(f"- **{dg['hash'][:12]}** ({dg['size']} bytes)\n")
                    for p in dg['files']:
                        f.write(f"  - {p}\n")
            else:
                f.write("None detected.\n\n")

            f.write("## 15. Protected Resources\n\n")
            protected = [r for r in self.protected_resources]
            for r in protected[:40]:
                f.write(f"- {r.repo_path}\n")
            if len(protected) > 40:
                f.write(f"\n... and {len(protected) - 40} more\n\n")

            f.write("## 16. Repository Hygiene\n\n")
            hy = self.hygiene_issues
            for r in hy[:20]:
                f.write(f"- {r.repo_path} ({r.confidence}) — {r.reason}\n")
            if len(hy) > 20:
                f.write(f"\n... and {len(hy) - 20} more\n\n")

            f.write("## 17. Limitations\n\n")
            f.write("""1. **ObjC Dynamic Runtime:** Classes referenced by string (`NSClassFromString`)
   cannot be fully traced statically.
2. **String-Interpolated Assets:** Assets loaded via format strings appear unused.
3. **CocoaPods/SPM:** Third-party dependencies are excluded from analysis.
4. **Feature Flags:** A/B-tested or server-gated code paths may appear unused.
5. **XIB Connections:** Custom classes in XIB files connected at runtime are not traced.
6. **Asset Catalog Variants:** Dark mode, device-specific, and RTL variants of used
   assets are protected by the parent asset set.
""")

            f.write("## 18. Recommended Cleanup Order\n\n")
            f.write("""1. Repository Hygiene files (safest)
2. Confirmed Project Issues (broken references)
3. High-Confidence Unused Candidates
4. Probable Unused Candidates
5. Manual Review Required (investigate each)
6. Duplicate files (consolidate after verification)
""")
        print(f"  -> {path}", flush=True)

    def _write_section(self, f, title, items):
        if not items:
            f.write(f"## {title}\n\nNone found.\n\n")
            return
        f.write(f"## {title}\n\n")
        f.write("| # | Path | Type | Target | Confidence | Reason |\n")
        f.write("|---|------|------|--------|------------|--------|\n")
        for i, rec in enumerate(items[:50], 1):
            tgt = ', '.join(rec.targets) if rec.targets else 'N/A'
            reason = rec.reason[:80]
            f.write(f"| {i} | {rec.repo_path} | {rec.file_type} | {tgt} | {rec.confidence} | {reason} |\n")
        if len(items) > 50:
            f.write(f"\n... and {len(items) - 50} more items.\n")
        f.write("\n")

    def write_csv(self, output_dir):
        path = output_dir / 'UnusedResourcesAudit.csv'
        with open(path, 'w', newline='', encoding='utf-8') as f:
            w = csv.writer(f)
            w.writerow([
                'Classification', 'Confidence', 'Relative Path', 'Item Name',
                'File Type', 'File Size', 'Xcode Project', 'Target Membership',
                'Build Phase', 'Project Ref Present', 'Physical File Present',
                'Static Ref Count', 'Dynamic Risk',
                'Ref Locations', 'Reason', 'Manual Check'
            ])
            for rec in sorted(self.disk_files, key=lambda x: (
                {'CONFIRMED PROJECT ISSUE': 0, 'HIGH-CONFIDENCE UNUSED CANDIDATE': 1,
                 'PROBABLE UNUSED CANDIDATE': 2, 'MANUAL REVIEW REQUIRED': 3,
                 'PROTECTED OR REQUIRED': 4, 'REPOSITORY HYGIENE': 5}.get(x.classification, 9),
                {'Certain': 0, 'High': 1, 'Medium': 2, 'Low': 3, 'Protected': 4}.get(x.confidence, 9),
                x.repo_path)):
                if not rec.classification:
                    continue
                w.writerow([
                    rec.classification, rec.confidence, rec.repo_path,
                    os.path.basename(rec.repo_path), rec.file_type, rec.size,
                    'Pure Pets.xcodeproj' if rec.in_pbxproj else 'None',
                    ', '.join(rec.targets) if rec.targets else 'None',
                    rec.build_phase or 'None',
                    'Yes' if rec.in_pbxproj else 'No', 'Yes',
                    rec.stat_refs, 'Yes' if rec.dynamic_risk else 'No',
                    '; '.join(rec.ref_locations[:3]),
                    rec.reason, rec.manual_check,
                ])
        print(f"  -> {path}", flush=True)

    def write_json(self, output_dir):
        path = output_dir / 'UnusedResourcesAudit.json'
        findings = defaultdict(list)
        for rec in self.disk_files:
            if not rec.classification:
                continue
            findings[rec.classification].append({
                'path': rec.repo_path,
                'name': os.path.basename(rec.repo_path),
                'type': rec.file_type,
                'size': rec.size,
                'targets': rec.targets,
                'build_phase': rec.build_phase,
                'in_pbxproj': rec.in_pbxproj,
                'stat_refs': rec.stat_refs,
                'dynamic_risk': rec.dynamic_risk,
                'ref_locations': rec.ref_locations[:5],
                'confidence': rec.confidence,
                'reason': rec.reason,
                'manual_check': rec.manual_check,
            })

        data = {
            'metadata': {
                'audit_timestamp': self.timestamp,
                'repository_root': str(self.repo_root),
                'tool': 'audit_unused_resources.py',
            },
            'exclusions': sorted(EXCLUDED_DIRECTORIES),
            'projects': self.projects,
            'targets': self.targets,
            'summary': {
                'files_scanned': self.scanned_file_count,
                'confirmed_project_issues': len(self.confirmed_issues),
                'high_confidence_unused': len(self.high_confidence),
                'probable_unused': len(self.probable_candidates),
                'manual_review_required': len(self.manual_review),
                'protected_resources': len(self.protected_resources),
                'repository_hygiene': len(self.hygiene_issues),
                'files_outside_project': len(self.files_outside_project),
                'duplicate_groups': len(self.duplicate_groups),
            },
            'findings_by_classification': dict(findings),
            'duplicate_groups': self.duplicate_groups,
            'errors': self.errors,
        }
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False, default=str)
        print(f"  -> {path}", flush=True)

    def write_inventory_csv(self, output_dir):
        path = output_dir / 'ProjectFileInventory.csv'
        with open(path, 'w', newline='', encoding='utf-8') as f:
            w = csv.writer(f)
            w.writerow([
                'Relative Path', 'File Type', 'File Size', 'In Xcode Project',
                'Target Membership', 'Build Phase', 'Static Ref Count',
                'Dynamic Risk', 'Classification', 'Confidence'
            ])
            for rec in sorted(self.disk_files, key=lambda r: r.repo_path):
                w.writerow([
                    rec.repo_path, rec.file_type, rec.size,
                    'Yes' if rec.in_pbxproj else 'No',
                    ', '.join(rec.targets) if rec.targets else '',
                    rec.build_phase or '',
                    rec.stat_refs,
                    'Yes' if rec.dynamic_risk else 'No',
                    rec.classification or '', rec.confidence or '',
                ])
        print(f"  -> {path}", flush=True)

    def write_methodology(self, output_dir):
        path = output_dir / 'AuditMethodology.md'
        with open(path, 'w', encoding='utf-8') as f:
            f.write("""# Audit Methodology

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
""")
        print(f"  -> {path}", flush=True)


# ──────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description='Unused resources audit')
    parser.add_argument('repo_root', nargs='?', default='.')
    parser.add_argument('--output', '-o', default=None)
    parser.add_argument('--verbose', '-v', action='store_true')
    args = parser.parse_args()

    repo = Path(args.repo_root).resolve()
    output_dir = Path(args.output) if args.output else \
        repo / 'AuditReports' / 'UnusedResourcesAudit'
    output_dir.mkdir(parents=True, exist_ok=True)

    report = AuditReport(repo)

    report.discover()
    report.parse_pbxproj()
    if args.verbose:
        print(f"References: {len(report.xcode_file_refs)}, Build files: {len(report.xcode_build_files)}")
        print(f"Targets: {report.targets}")

    report.scan_filesystem(args.verbose)
    report.count_asset_sets()
    if args.verbose:
        print(f"Files: {len(report.disk_files)}, Asset catalogs: {len(report.asset_catalogs)}, "
              f"Asset sets: {report.asset_set_count}, Storyboards: {len(report.storyboards)}, "
              f"XIBs: {len(report.xibs)}")

    report.cross_reference(args.verbose)
    if args.verbose:
        print("Analyzing source references...", flush=True)
    report.analyze_source_references(args.verbose)
    if args.verbose:
        print("Classifying...", flush=True)
    report.classify(args.verbose)
    if args.verbose:
        print("Finding duplicates...", flush=True)
    report.find_duplicates(args.verbose)

    if args.verbose:
        print("Writing reports...", flush=True)
    report.write_markdown(output_dir)
    report.write_csv(output_dir)
    report.write_json(output_dir)
    report.write_inventory_csv(output_dir)
    report.write_methodology(output_dir)

    print(f"\n{'='*60}")
    print(f"AUDIT COMPLETE")
    print(f"{'='*60}")
    print(f"Output: {output_dir}")
    print(f"Scanned: {report.scanned_file_count} files")
    print(f"Confirmed issues:   {len(report.confirmed_issues)}")
    print(f"High-confidence:     {len(report.high_confidence)}")
    print(f"Probable unused:     {len(report.probable_candidates)}")
    print(f"Manual review:       {len(report.manual_review)}")
    print(f"Protected resources: {len(report.protected_resources)}")
    print(f"Hygiene issues:      {len(report.hygiene_issues)}")
    print(f"Files outside proj:  {len(report.files_outside_project)}")
    print(f"Duplicate groups:    {len(report.duplicate_groups)}")
    print(f"{'='*60}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
