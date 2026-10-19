#!/usr/bin/env python3
"""Read-only source/resource verification. --app validates an existing app, never builds it."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

REPO = Path(__file__).resolve().parents[1]
APP_SOURCE = REPO / 'Pure Pets'
CARE = APP_SOURCE / 'MainApp/ModrenAppVC/PetCare'
LANGUAGES = ('ar', 'en')


def read_plist(path):
    result = subprocess.run(['plutil', '-convert', 'json', '-o', '-', str(path)],
                            capture_output=True, text=True, check=True)
    return json.loads(result.stdout)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', type=Path, help='An already-built Pure Pets.app to inspect read-only')
    args = parser.parse_args()
    failures = []
    count = 0

    def require(condition, message):
        nonlocal count
        count += 1
        if not condition:
            failures.append(message)

    sources = '\n'.join((CARE / name).read_text() for name in (
        'PPVetViewerScreen.swift', 'PPVetViewerHostingController.swift', 'PPPetCareVetViewrVC.m',
        'PPVetCardView.swift', 'PPPetCareViewController.m'))
    keys = set(re.findall(r'"(vet_(?:detail|card)_[a-z0-9_]+)"', sources))
    tables = {}
    for language in LANGUAGES:
        path = APP_SOURCE / f'{language}.lproj/VetDetails.strings'
        tables[language] = read_plist(path)
        text = path.read_text()
        main_table = read_plist(APP_SOURCE / f'{language}.lproj/Localizable.strings')
        for key in keys:
            value = tables[language].get(key)
            require(isinstance(value, str) and bool(value.strip()) and value != key,
                    f'{language}: missing or unresolved {key}')
            require(len(re.findall(r'^"' + re.escape(key) + r'"\s*=', text, re.M)) == 1,
                    f'{language}: duplicate or missing declaration {key}')
        for fallback in set(re.findall(r'"vet_(?:detail|card)_[a-z0-9_]+": "([^"]+)"', sources)):
            require(bool(main_table.get(fallback)), f'{language}: legacy fallback {fallback} missing')
    require(set(tables['ar']) == set(tables['en']), 'Arabic/English feature key sets differ')
    for key in tables['ar']:
        require(re.findall(r'%(?:\d+\$)?(?:@|ld|d|f)', tables['ar'][key]) ==
                re.findall(r'%(?:\d+\$)?(?:@|ld|d|f)', tables['en'].get(key, '')),
                f'{key}: format arguments differ between languages')

    project = read_plist(REPO / 'Pure Pets.xcodeproj/project.pbxproj')['objects']
    variant = [(key, obj) for key, obj in project.items()
               if obj.get('isa') == 'PBXVariantGroup' and obj.get('name') == 'VetDetails.strings']
    require(len(variant) == 1, 'Feature table must have exactly one variant group')
    if len(variant) == 1:
        group_id, group = variant[0]
        paths = {project[child].get('path') for child in group['children']}
        require(paths == {f'{lang}.lproj/VetDetails.strings' for lang in LANGUAGES},
                'Feature variant group must reference the actual Arabic/English files')
        targets = [obj for obj in project.values()
                   if obj.get('isa') == 'PBXNativeTarget' and obj.get('name') == 'Pure Pets']
        require(len(targets) == 1, 'Expected application target is missing or ambiguous')
        if len(targets) == 1:
            resources = [project[phase] for phase in targets[0]['buildPhases']
                         if project[phase].get('isa') == 'PBXResourcesBuildPhase']
            resource_refs = [project[file_id].get('fileRef') for phase in resources for file_id in phase['files']]
            require(resource_refs.count(group_id) == 1, 'Feature table is not in the app Resources phase exactly once')
        require(any(group_id in obj.get('children', []) and obj.get('path') == 'Pure Pets'
                    for obj in project.values()), 'Feature table is not relative to the application source folder')

    require('Language.get(candidate, table: table, alter: nil)' in sources,
            'Feature copy must use the existing app language owner')
    require('value != candidate' in sources, 'Missing-key fallback must reject the raw identifier')
    require('[Language get:@"vet_detail_' not in sources,
            'A UIKit caller still bypasses the feature table')

    if args.app:
        for language in LANGUAGES:
            path = args.app / f'{language}.lproj/VetDetails.strings'
            require(path.is_file(), f'BUNDLE: {language}/VetDetails.strings is missing from {args.app.name}')
            if path.is_file():
                built = read_plist(path)
                for key, value in tables[language].items():
                    require(built.get(key) == value, f'BUNDLE: {language}/{key} is missing or stale')
    print(f'{"FAIL" if failures else "PASS"}: {count} resource checks; {len(keys)} referenced feature keys.')
    for failure in failures:
        print(' - ' + failure)
    if not args.app:
        print('App bundle freshness: UNVERIFIED (supply --app after an authorized build).')
    return 1 if failures else 0


if __name__ == '__main__':
    sys.exit(main())
