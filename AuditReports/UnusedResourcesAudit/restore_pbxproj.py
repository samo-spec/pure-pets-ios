#!/usr/bin/env python3
"""Restore PBXFileReference, PBXBuildFile, PBXGroup children, and PBXSourcesBuildPhase
entries for 9 files that were incorrectly deleted."""

import re
import sys

PBXPROJ = "/Users/mohammedahmed/Desktop/PurePets/PurePetsProjects/Pure Pets IOS/Pure Pets.xcodeproj/project.pbxproj"

def read_pbxproj(path):
    with open(path, 'r') as f:
        return f.read()

def write_pbxproj(path, content):
    with open(path, 'w') as f:
        f.write(content)

# --- Entries to restore ---

file_refs = [
    # PPHomeHeroCell
    '\t\tF2F465F02F3B8C8200E5FB60 /* PPHomeHeroCell.h */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.h; path = PPHomeHeroCell.h; sourceTree = "<group>"; };',
    '\t\tF2F465F12F3B8CAB00E5FB60 /* PPHomeHeroCell.m */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.objc; path = PPHomeHeroCell.m; sourceTree = "<group>"; };',
    # PPModernHomeActionCell
    '\t\tF2D5A7C02F95C0A1009B6001 /* PPModernHomeActionCell.h */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.h; path = PPModernHomeActionCell.h; sourceTree = "<group>"; };',
    '\t\tF2D5A7C12F95C0A1009B6001 /* PPModernHomeActionCell.m */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.objc; path = PPModernHomeActionCell.m; sourceTree = "<group>"; };',
    # PPHomePremiumCareCell
    '\t\tF28476842FA240AA009AE4CE /* PPHomePremiumCareCell.h */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.h; path = PPHomePremiumCareCell.h; sourceTree = "<group>"; };',
    '\t\tF28476852FA240B8009AE4CE /* PPHomePremiumCareCell.m */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.objc; path = PPHomePremiumCareCell.m; sourceTree = "<group>"; };',
    # PPHomePremiumSearchCell
    '\t\tF2A9E80C2FB3570200B2729F /* PPHomePremiumSearchCell.h */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.h; path = PPHomePremiumSearchCell.h; sourceTree = "<group>"; };',
    '\t\tF2A9E80D2FB3570200B2729F /* PPHomePremiumSearchCell.m */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.objc; path = PPHomePremiumSearchCell.m; sourceTree = "<group>"; };',
    # PPHomeUltraPremuimProviderCategoryPillCell
    '\t\tA11CE2302FEB200000000001 /* PPHomeUltraPremuimProviderCategoryPillCell.h */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.h; path = PPHomeUltraPremuimProviderCategoryPillCell.h; sourceTree = "<group>"; };',
    '\t\tA11CE2302FEB200000000002 /* PPHomeUltraPremuimProviderCategoryPillCell.m */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.objc; path = PPHomeUltraPremuimProviderCategoryPillCell.m; sourceTree = "<group>"; };',
    # PPCategoryCardCell
    '\t\tF253FA6B2F082EF800323CB4 /* PPCategoryCardCell.h */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.h; path = PPCategoryCardCell.h; sourceTree = "<group>"; };',
    '\t\tF253FA6C2F082F1900323CB4 /* PPCategoryCardCell.m */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.objc; path = PPCategoryCardCell.m; sourceTree = "<group>"; };',
    # PetAdoptCollectionViewCell
    '\t\tF2EB74312E4903E000A31008 /* PetAdoptCollectionViewCell.h */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.h; path = PetAdoptCollectionViewCell.h; sourceTree = "<group>"; };',
    '\t\tF2EB74322E4903EA00A31008 /* PetAdoptCollectionViewCell.m */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.objc; path = PetAdoptCollectionViewCell.m; sourceTree = "<group>"; };',
    # PPBrowseHistoryManager
    '\t\tF282C1152F0EC788001C110A /* PPBrowseHistoryManager.h */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.h; path = PPBrowseHistoryManager.h; sourceTree = "<group>"; };',
    '\t\tF282C1162F0EC788001C110A /* PPBrowseHistoryManager.m */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.objc; path = PPBrowseHistoryManager.m; sourceTree = "<group>"; };',
    # PPHomeLayoutManager
    '\t\tF253FA672F07708100323CB4 /* PPHomeLayoutManager.h */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.h; path = PPHomeLayoutManager.h; sourceTree = "<group>"; };',
    '\t\tF253FA682F07708A00323CB4 /* PPHomeLayoutManager.m */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.objc; path = PPHomeLayoutManager.m; sourceTree = "<group>"; };',
]

build_file_entries = [
    '\t\tF2F465F22F3B8CCB00E5FB60 /* PPHomeHeroCell.m in Sources */ = {isa = PBXBuildFile; fileRef = F2F465F12F3B8CAB00E5FB60 /* PPHomeHeroCell.m */; };',
    '\t\tF2D5A7C22F95C0A1009B6001 /* PPModernHomeActionCell.m in Sources */ = {isa = PBXBuildFile; fileRef = F2D5A7C12F95C0A1009B6001 /* PPModernHomeActionCell.m */; };',
    '\t\tF28476862FA240B8009AE4CE /* PPHomePremiumCareCell.m in Sources */ = {isa = PBXBuildFile; fileRef = F28476852FA240B8009AE4CE /* PPHomePremiumCareCell.m */; };',
    '\t\tF2A9E80E2FB3570200B2729F /* PPHomePremiumSearchCell.m in Sources */ = {isa = PBXBuildFile; fileRef = F2A9E80D2FB3570200B2729F /* PPHomePremiumSearchCell.m */; };',
    '\t\tA11CE2302FEB200000000003 /* PPHomeUltraPremuimProviderCategoryPillCell.m in Sources */ = {isa = PBXBuildFile; fileRef = A11CE2302FEB200000000002 /* PPHomeUltraPremuimProviderCategoryPillCell.m */; };',
    '\t\tF253FA6D2F082F2F00323CB4 /* PPCategoryCardCell.m in Sources */ = {isa = PBXBuildFile; fileRef = F253FA6C2F082F1900323CB4 /* PPCategoryCardCell.m */; };',
    '\t\tF2EB74332E4903EA00A31008 /* PetAdoptCollectionViewCell.m in Sources */ = {isa = PBXBuildFile; fileRef = F2EB74322E4903EA00A31008 /* PetAdoptCollectionViewCell.m */; };',
    '\t\tF282C1172F0EC788001C110A /* PPBrowseHistoryManager.m in Sources */ = {isa = PBXBuildFile; fileRef = F282C1162F0EC788001C110A /* PPBrowseHistoryManager.m */; };',
    '\t\tF253FA692F07708A00323CB4 /* PPHomeLayoutManager.m in Sources */ = {isa = PBXBuildFile; fileRef = F253FA682F07708A00323CB4 /* PPHomeLayoutManager.m */; };',
]

# Group children references: (group_uuid, child_entry_line)
group_children = [
    # HomeCells group
    ('F202A0722EFF15B30048D4C2', '\t\t\t\tF2F465F02F3B8C8200E5FB60 /* PPHomeHeroCell.h */,'),
    ('F202A0722EFF15B30048D4C2', '\t\t\t\tF2F465F12F3B8CAB00E5FB60 /* PPHomeHeroCell.m */,'),
    ('F202A0722EFF15B30048D4C2', '\t\t\t\tF2D5A7C02F95C0A1009B6001 /* PPModernHomeActionCell.h */,'),
    ('F202A0722EFF15B30048D4C2', '\t\t\t\tF2D5A7C12F95C0A1009B6001 /* PPModernHomeActionCell.m */,'),
    ('F202A0722EFF15B30048D4C2', '\t\t\t\tF28476842FA240AA009AE4CE /* PPHomePremiumCareCell.h */,'),
    ('F202A0722EFF15B30048D4C2', '\t\t\t\tF28476852FA240B8009AE4CE /* PPHomePremiumCareCell.m */,'),
    ('F202A0722EFF15B30048D4C2', '\t\t\t\tF2A9E80C2FB3570200B2729F /* PPHomePremiumSearchCell.h */,'),
    ('F202A0722EFF15B30048D4C2', '\t\t\t\tF2A9E80D2FB3570200B2729F /* PPHomePremiumSearchCell.m */,'),
    ('F202A0722EFF15B30048D4C2', '\t\t\t\tA11CE2302FEB200000000001 /* PPHomeUltraPremuimProviderCategoryPillCell.h */,'),
    ('F202A0722EFF15B30048D4C2', '\t\t\t\tA11CE2302FEB200000000002 /* PPHomeUltraPremuimProviderCategoryPillCell.m */,'),
    ('F202A0722EFF15B30048D4C2', '\t\t\t\tF253FA6B2F082EF800323CB4 /* PPCategoryCardCell.h */,'),
    ('F202A0722EFF15B30048D4C2', '\t\t\t\tF253FA6C2F082F1900323CB4 /* PPCategoryCardCell.m */,'),
    # AdoptPet group
    ('F28CB3792E4C56C0009DD547', '\t\t\t\tF2EB74312E4903E000A31008 /* PetAdoptCollectionViewCell.h */,'),
    ('F28CB3792E4C56C0009DD547', '\t\t\t\tF2EB74322E4903EA00A31008 /* PetAdoptCollectionViewCell.m */,'),
    # SmartSuggest group
    ('F282C1132F0EC700001C110A', '\t\t\t\tF282C1152F0EC788001C110A /* PPBrowseHistoryManager.h */,'),
    ('F282C1132F0EC700001C110A', '\t\t\t\tF282C1162F0EC788001C110A /* PPBrowseHistoryManager.m */,'),
    # Helpers group
    ('F25E7FF32EFF71FE0089F659', '\t\t\t\tF253FA672F07708100323CB4 /* PPHomeLayoutManager.h */,'),
    ('F25E7FF32EFF71FE0089F659', '\t\t\t\tF253FA682F07708A00323CB4 /* PPHomeLayoutManager.m */,'),
]

sources_build_phase_entries = [
    '\t\t\t\tF2F465F22F3B8CCB00E5FB60 /* PPHomeHeroCell.m in Sources */,',
    '\t\t\t\tF2D5A7C22F95C0A1009B6001 /* PPModernHomeActionCell.m in Sources */,',
    '\t\t\t\tF28476862FA240B8009AE4CE /* PPHomePremiumCareCell.m in Sources */,',
    '\t\t\t\tF2A9E80E2FB3570200B2729F /* PPHomePremiumSearchCell.m in Sources */,',
    '\t\t\t\tA11CE2302FEB200000000003 /* PPHomeUltraPremuimProviderCategoryPillCell.m in Sources */,',
    '\t\t\t\tF253FA6D2F082F2F00323CB4 /* PPCategoryCardCell.m in Sources */,',
    '\t\t\t\tF2EB74332E4903EA00A31008 /* PetAdoptCollectionViewCell.m in Sources */,',
    '\t\t\t\tF282C1172F0EC788001C110A /* PPBrowseHistoryManager.m in Sources */,',
    '\t\t\t\tF253FA692F07708A00323CB4 /* PPHomeLayoutManager.m in Sources */,',
]

def insert_into_file_refs(content, entries):
    """Insert entries into PBXFileReference section, maintaining UUID sort order."""
    pattern = r'(\/\* Begin PBXFileReference section \*\/\n)(.*?)(\n\/\* End PBXFileReference section \*\/)'
    match = re.search(pattern, content, re.DOTALL)
    if not match:
        print("ERROR: Could not find PBXFileReference section", file=sys.stderr)
        return content
    
    section_body = match.group(2)
    # Extract existing UUIDs and line positions
    lines = section_body.split('\n')
    
    # Parse existing UUIDs
    uuid_line_map = {}
    for i, line in enumerate(lines):
        line_stripped = line.strip()
        if line_stripped.startswith('/*') and line_stripped.endswith('*/'):
            continue
        m = re.match(r'^(\s+)([0-9A-F]{24}|[0-9A-Fa-f]{24})\s+', line)
        if m:
            uuid_line_map[m.group(2)] = i
    
    for entry in entries:
        m = re.match(r'^\s+([0-9A-F]{24}|[0-9A-Fa-f]{24})\s+', entry)
        if m:
            uuid = m.group(1)
            # Find where to insert: before the first existing UUID that is greater
            insert_idx = len(lines)
            for existing_uuid, line_idx in uuid_line_map.items():
                if uuid < existing_uuid and line_idx < insert_idx:
                    insert_idx = line_idx
            lines.insert(insert_idx, entry)
            # Update uuid_line_map for subsequent insertions
            uuid_line_map = {}
            for j, line in enumerate(lines):
                line_stripped = line.strip()
                if line_stripped.startswith('/*'):
                    continue
                m2 = re.match(r'^(\s+)([0-9A-F]{24}|[0-9A-Fa-f]{24})\s+', line)
                if m2:
                    uuid_line_map[m2.group(2)] = j
    
    new_body = '\n'.join(lines)
    new_content = content.replace(match.group(0), match.group(1) + new_body + match.group(3))
    return new_content


def insert_into_build_files(content, entries):
    """Insert entries into PBXBuildFile section (sorted by UUID)."""
    pattern = r'(\/\* Begin PBXBuildFile section \*\/\n)(.*?)(\n\/\* End PBXBuildFile section \*\/)'
    match = re.search(pattern, content, re.DOTALL)
    if not match:
        print("ERROR: Could not find PBXBuildFile section", file=sys.stderr)
        return content
    
    section_body = match.group(2)
    lines = section_body.split('\n')
    
    uuid_line_map = {}
    for i, line in enumerate(lines):
        line_stripped = line.strip()
        if line_stripped.startswith('/*'):
            continue
        m = re.match(r'^(\s+)([0-9A-F]{24}|[0-9A-Fa-f]{24})\s+', line)
        if m:
            uuid_line_map[m.group(2)] = i
    
    for entry in entries:
        m = re.match(r'^\s+([0-9A-F]{24}|[0-9A-Fa-f]{24})\s+', entry)
        if m:
            uuid = m.group(1)
            insert_idx = len(lines)
            for existing_uuid, line_idx in uuid_line_map.items():
                if uuid < existing_uuid and line_idx < insert_idx:
                    insert_idx = line_idx
            lines.insert(insert_idx, entry)
            uuid_line_map = {}
            for j, line in enumerate(lines):
                line_stripped = line.strip()
                if line_stripped.startswith('/*'):
                    continue
                m2 = re.match(r'^(\s+)([0-9A-F]{24}|[0-9A-Fa-f]{24})\s+', line)
                if m2:
                    uuid_line_map[m2.group(2)] = j
    
    new_body = '\n'.join(lines)
    new_content = content.replace(match.group(0), match.group(1) + new_body + match.group(3))
    return new_content


def insert_into_group_children(content, group_uuid, entries):
    """Insert child references into a PBXGroup's children array."""
    # Find the group: /* group_uuid ... */
    pattern = rf'(\t+)({re.escape(group_uuid)})\s+\/\*.*?\*\/\s*=\s*\{{'
    # We need to find the group and insert within the children = (...) block
    # Find the group definition
    idx = content.find(f'/* {group_uuid} ')
    if idx == -1:
        idx = content.find(group_uuid)
    if idx == -1:
        print(f"ERROR: Could not find group {group_uuid}", file=sys.stderr)
        return content
    
    # Find the children = (...) section within this group
    # Look for 'children = (' after the group UUID
    sub_content = content[idx:]
    children_match = re.search(r'children\s*=\s*\(', sub_content)
    if not children_match:
        print(f"ERROR: Could not find children array in group {group_uuid}", file=sys.stderr)
        return content
    
    start_idx = idx + children_match.end()
    
    # Find the closing ')'
    paren_depth = 1
    pos = start_idx
    while pos < len(content) and paren_depth > 0:
        if content[pos] == '(':
            paren_depth += 1
        elif content[pos] == ')':
            paren_depth -= 1
        pos += 1
    
    end_idx = pos - 1  # position of ')'
    
    current_children = content[start_idx:end_idx]
    new_children = '\n'.join(entries)
    # Insert before the closing paren
    if current_children.strip():
        new_content = content[:end_idx] + '\n' + new_children + '\n' + content[end_idx:]
    else:
        new_content = content[:start_idx] + '\n' + new_children + '\n' + content[end_idx:]
    
    return new_content


def insert_into_sources_phase(content, entries):
    """Insert entries into the Sources build phase."""
    # Find the main Sources build phase: isa = PBXSourcesBuildPhase;
    # We look for the build phase that has "Sources" in its files
    # Actually, just find the PBXSourcesBuildPhase and insert within its `files = (...)` section.
    
    # Find all PBXSourcesBuildPhase sections
    pattern = r'(files\s*=\s*\()(.*?)(\s*\);)' 
    # Actually let me find the right one - there should be one main Sources build phase
    
    # Find "/* Sources */" in the build phase context
    # Let me find the main build phase by looking for PBXSourcesBuildPhase with children
    phase_start = content.find('isa = PBXSourcesBuildPhase;')
    if phase_start == -1:
        print("ERROR: Could not find PBXSourcesBuildPhase", file=sys.stderr)
        return content
    
    # Go backwards to find the beginning of this build phase's brace block
    sub_content = content[phase_start-200:]
    
    # Find files = ( ... )
    files_match = re.search(r'files\s*=\s*\(', sub_content)
    if not files_match:
        print("ERROR: Could not find files array in Sources build phase", file=sys.stderr)
        return content
    
    start_idx = phase_start - 200 + files_match.end()
    
    paren_depth = 1
    pos = start_idx
    while pos < len(content) and paren_depth > 0:
        if content[pos] == '(':
            paren_depth += 1
        elif content[pos] == ')':
            paren_depth -= 1
        pos += 1
    
    end_idx = pos - 1
    
    current_files = content[start_idx:end_idx]
    new_files = '\n'.join(entries)
    if current_files.strip():
        new_content = content[:end_idx] + '\n' + new_files + '\n' + content[end_idx:]
    else:
        new_content = content[:start_idx] + '\n' + new_files + '\n' + content[end_idx:]
    
    return new_content


# Group entries by group UUID
from collections import defaultdict
group_entries_map = defaultdict(list)
for group_uuid, entry in group_children:
    group_entries_map[group_uuid].append(entry)

def main():
    content = read_pbxproj(PBXPROJ)
    
    # Phase 1: Insert PBXFileReference entries
    content = insert_into_file_refs(content, file_refs)
    print("Phase 1/4: PBXFileReference entries inserted")
    
    # Phase 2: Insert PBXBuildFile entries
    content = insert_into_build_files(content, build_file_entries)
    print("Phase 2/4: PBXBuildFile entries inserted")
    
    # Phase 3: Insert PBXGroup children
    for group_uuid, entries in group_entries_map.items():
        content = insert_into_group_children(content, group_uuid, entries)
        print(f"Phase 3/4: Group {group_uuid} children inserted")
    
    # Phase 4: Insert Sources build phase entries
    content = insert_into_sources_phase(content, sources_build_phase_entries)
    print("Phase 4/4: Sources build phase entries inserted")
    
    write_pbxproj(PBXPROJ, content)
    print("Done! pbxproj updated.")

if __name__ == '__main__':
    main()
