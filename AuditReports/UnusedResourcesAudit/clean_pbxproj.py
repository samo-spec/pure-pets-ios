"""
Clean up project.pbxproj references for the 78 deleted files.

Reads the file list from the backup directory structure, finds matching
PBXFileReference / PBXBuildFile entries in project.pbxproj, and removes them.
"""

import os
import re
import sys

BASE = "/Users/mohammedahmed/Desktop/PurePets/PurePetsProjects/Pure Pets IOS"
PBXPROJ = os.path.join(BASE, "Pure Pets.xcodeproj", "project.pbxproj")
BACKUP_FOLDERS = [
    os.path.join(BASE, "AuditReports/UnusedResourcesAudit/unused files backup/Pure Pets"),
    os.path.join(BASE, "AuditReports/UnusedResourcesAudit/unused files backup 2/Pure Pets"),
]

# ─── Gather deleted filenames (basename only) from backup structure ────────────

deleted_basenames = set()
for bk in BACKUP_FOLDERS:
    if os.path.isdir(bk):
        for root, dirs, files in os.walk(bk):
            for f in files:
                deleted_basenames.add(f)

# Files we've restored and must NOT remove from pbxproj
KEEP_BASENAMES = {
    'PPHomeHeroCell.h', 'PPHomeHeroCell.m',
    'PPModernHomeActionCell.h', 'PPModernHomeActionCell.m',
    'PPHomePremiumCareCell.h', 'PPHomePremiumCareCell.m',
    'PPHomePremiumSearchCell.h', 'PPHomePremiumSearchCell.m',
    'PPHomeUltraPremuimProviderCategoryPillCell.h', 'PPHomeUltraPremuimProviderCategoryPillCell.m',
    'PPCategoryCardCell.h', 'PPCategoryCardCell.m',
    'PetAdoptCollectionViewCell.h', 'PetAdoptCollectionViewCell.m',
    'PPBrowseHistoryManager.h', 'PPBrowseHistoryManager.m',
    'PPHomeLayoutManager.h', 'PPHomeLayoutManager.m',
    'UnifiedImage.swift', 'UnifiedImage+Encode.swift',
    'UnifiedImage+Scale.swift', 'UnifiedImage+Decode.swift',
}
deleted_basenames -= KEEP_BASENAMES
print(f"Excluding {len(KEEP_BASENAMES)} restored files from removal")

print(f"Found {len(deleted_basenames)} deleted filenames to remove from pbxproj")
for b in sorted(deleted_basenames):
    print(f"  {b}")

# ─── Parse the pbxproj into sections ──────────────────────────────────────────

with open(PBXPROJ, "r") as fh:
    content = fh.read()

# Split into sections on "/* Begin ... */" boundaries
# We'll use a regex to find section boundaries
section_pattern = re.compile(
    r'(/\* Begin (\S+) section \*/)\n(.*?)\n(/\* End \2 section \*/)',
    re.DOTALL
)

sections = {}
sections_raw = {}

for m in section_pattern.finditer(content):
    section_name = m.group(2)
    sections_raw[section_name] = m.group(0)
    sections[section_name] = m.group(3)

# ─── Parse PBXFileReference entries ──────────────────────────────────────────

# Match: UUID /* Name */ = {isa = PBXFileReference; ... path = "some/path"; ... };
file_ref_pattern = re.compile(
    r'(\w{24})\s+/\*\s+(.+?)\s+\*/\s+=\s+{(\s*isa\s*=\s*PBXFileReference[^}]+)};'
)

file_refs_by_uuid = {}   # uuid -> {name, path, raw_entry}
file_refs_by_basename = {}  # basename -> [uuid, ...]

for m in file_ref_pattern.finditer(sections.get("PBXFileReference", "")):
    uuid = m.group(1)
    name = m.group(2)
    attrs = m.group(3)
    
    # Extract path (quoted or bare)
    path_m = re.search(r'path\s*=\s*"(.+?)"', attrs)
    if not path_m:
        path_m = re.search(r'path\s*=\s*(\S+?);', attrs)
    path = path_m.group(1) if path_m else ""
    
    entry = {"name": name, "path": path}
    file_refs_by_uuid[uuid] = entry
    
    basename = os.path.basename(path) if path else name
    if basename not in file_refs_by_basename:
        file_refs_by_basename[basename] = []
    file_refs_by_basename[basename].append(uuid)

# ─── Find file ref UUIDs to remove ────────────────────────────────────────────

refs_to_remove = set()  # set of PBXFileReference UUIDs

for basename in deleted_basenames:
    uuids = file_refs_by_basename.get(basename, [])
    for uuid in uuids:
        refs_to_remove.add(uuid)
        entry = file_refs_by_uuid[uuid]
        print(f"  Queue removal: {uuid} -> {entry['path'] or entry['name']}")

print(f"\nFound {len(refs_to_remove)} PBXFileReference entries to remove")

# ─── Find PBXBuildFile entries referencing those fileRefs ────────────────────

build_file_pattern = re.compile(
    r'(\w{24})\s+/\*\s+(.+?)\s+\*/\s+=\s+{(\s*isa\s*=\s*PBXBuildFile[^}]+)};'
)

build_refs_to_remove = {}  # build_file_uuid -> fileRef_uuid
build_ref_uuids = set()

for m in build_file_pattern.finditer(sections.get("PBXBuildFile", "")):
    bf_uuid = m.group(1)
    bf_name = m.group(2)
    bf_attrs = m.group(3)
    
    fr_m = re.search(r'fileRef\s*=\s*(\w{24})', bf_attrs)
    if fr_m:
        fr_uuid = fr_m.group(1)
        if fr_uuid in refs_to_remove:
            build_refs_to_remove[bf_uuid] = fr_uuid
            build_ref_uuids.add(bf_uuid)
            print(f"  Queue build file: {bf_uuid} -> fileRef {fr_uuid} ({bf_name})")

print(f"Found {len(build_refs_to_remove)} PBXBuildFile entries to remove")

# ─── Remove from build phases ─────────────────────────────────────────────────

build_phase_sections = ["PBXSourcesBuildPhase", "PBXFrameworksBuildPhase", "PBXResourcesBuildPhase"]

for section_name in build_phase_sections:
    section_content = sections.get(section_name, "")
    if not section_content:
        continue
    
    # Each build phase contains: uuid /* comment */ = {isa = ...; buildActionMask = ...; files = ( ... ); };
    # We need to find the files array and remove our build file UUIDs
    
    # First, find each build phase block
    phase_blocks = re.finditer(
        r'(\w{24})\s+/\*\s+(.+?)\s+\*/\s*=\s*\{([^}]+?)\};',
        section_content
    )
    
    modified_phases = []
    for pm in phase_blocks:
        phase_uuid = pm.group(1)
        phase_comment = pm.group(2)
        phase_body = pm.group(3)
        
        # Extract the files array
        files_m = re.search(r'files\s*=\s*\(([^)]*)\)', phase_body)
        if not files_m:
            continue
        
        files_content = files_m.group(1)
        original_files = files_content
        
        # Remove any build file UUIDs that should be removed
        for bf_uuid in build_ref_uuids:
            pat = re.compile(r'\s*' + re.escape(bf_uuid) + r'\s+/\*[^*]*\*/\s*,?')
            files_content = pat.sub('', files_content)
        
        if files_content != original_files:
            # Rebuild body with cleaned files array
            new_body = phase_body[:files_m.start(1)] + files_content + phase_body[files_m.end(1):]
            old_block = f"{phase_uuid} /* {phase_comment} */ = {{{phase_body}}};"
            new_block = f"{phase_uuid} /* {phase_comment} */ = {{{new_body}}};"
            modified_phases.append((old_block, new_block))
            print(f"  Removed build files from phase {phase_uuid} ({phase_comment})")
    
    # Apply phase modifications
    for old, new in modified_phases:
        sections[section_name] = sections[section_name].replace(old, new)

# ─── Remove build file entries ────────────────────────────────────────────────

build_file_section = sections["PBXBuildFile"]
for bf_uuid in build_ref_uuids:
    pat = re.compile(r'\s*' + re.escape(bf_uuid) + r'\s+/\*.*?\*/\s*=\s*\{[^}]+?\};')
    build_file_section = pat.sub('', build_file_section)
sections["PBXBuildFile"] = build_file_section
print(f"Removed {len(build_ref_uuids)} PBXBuildFile entries")

# ─── Remove file references from groups ──────────────────────────────────────

def remove_from_groups(section_content, uuids_to_remove):
    """Remove child UUIDs from PBXGroup children arrays."""
    # Match each group block
    group_blocks = re.finditer(
        r'(\w{24})\s+/\*\s+(.+?)\s+\*/\s*=\s*\{([^}]+?)\};',
        section_content
    )
    
    replacements = []
    for gm in group_blocks:
        g_uuid = gm.group(1)
        g_comment = gm.group(2)
        g_body = gm.group(3)
        
        if 'children = ' not in g_body:
            continue
        
        children_m = re.search(r'children\s*=\s*\(([^)]*)\)', g_body)
        if not children_m:
            continue
        
        children_content = children_m.group(1)
        original = children_content
        
        for ruid in uuids_to_remove:
            pat = re.compile(r'\s*' + re.escape(ruid) + r'\s+/\*[^*]*\*/\s*,?')
            children_content = pat.sub('', children_content)
        
        if children_content != original:
            new_body = g_body[:children_m.start(1)] + children_content + g_body[children_m.end(1):]
            old_block = f"{g_uuid} /* {g_comment} */ = {{{g_body}}};"
            new_block = f"{g_uuid} /* {g_comment} */ = {{{new_body}}};"
            replacements.append((old_block, new_block))
            print(f"  Removed refs from group {g_uuid} ({g_comment})")
    
    for old, new in replacements:
        section_content = section_content.replace(old, new)
    return section_content

sections["PBXGroup"] = remove_from_groups(sections["PBXGroup"], refs_to_remove)

# ─── Remove PBXFileReference entries ─────────────────────────────────────────

file_ref_section = sections["PBXFileReference"]
for ruid in refs_to_remove:
    pat = re.compile(r'\s*' + re.escape(ruid) + r'\s+/\*.*?\*/\s*=\s*\{[^}]+?\};')
    file_ref_section = pat.sub('', file_ref_section)
sections["PBXFileReference"] = file_ref_section
print(f"Removed {len(refs_to_remove)} PBXFileReference entries")

# ─── Rebuild the project.pbxproj ─────────────────────────────────────────────

for section_name, new_content in sections.items():
    old_block = sections_raw[section_name]
    # Reconstruct: /* Begin section */ \n content \n /* End section */
    new_block = f"/* Begin {section_name} section */\n{new_content}\n/* End {section_name} section */"
    content = content.replace(old_block, new_block)

# Write
with open(PBXPROJ, "w") as fh:
    fh.write(content)

print(f"\n✓ Updated {PBXPROJ}")
