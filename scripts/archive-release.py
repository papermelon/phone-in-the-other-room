#!/usr/bin/env python3
"""Reserve a unique local build, regenerate XcodeGen, archive, and verify bundles."""
import argparse
from contextlib import contextmanager
from datetime import datetime
import fcntl
import json
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
APP_ID = 'com.ngawangchime.countingsheep'
BUILD = re.compile(r'^(\s*CURRENT_PROJECT_VERSION:\s*)(\d+)(\s*)$', re.MULTILINE)


def positive(value):
    if not str(value).isdigit() or int(value) < 1:
        raise ValueError('Build numbers must be positive integers.')
    return int(value)


def archive_numbers(directory):
    numbers = []
    for path in directory.glob('*/*.xcarchive/Info.plist'):
        info = plistlib.loads(path.read_bytes()).get('ApplicationProperties', {})
        if info.get('CFBundleIdentifier') == APP_ID:
            numbers.append(positive(info['CFBundleVersion']))
    return numbers


def reserve(project, state, archives, latest, dry_run=False):
    source = project.read_text()
    matches = list(BUILD.finditer(source))
    if len(matches) != 1:
        raise ValueError('Expected exactly one integer CURRENT_PROJECT_VERSION in project.yml.')
    previous = json.loads(state.read_text())['last_reserved'] if state.exists() else 0
    number = max([positive(matches[0][2]), positive(latest), int(previous)] + archive_numbers(archives)) + 1
    if not dry_run:
        # Persist the reservation first: a crash or failed build must never reuse it.
        temporary = state.with_suffix('.tmp')
        temporary.write_text(json.dumps({'last_reserved': number}) + '\n')
        temporary.replace(state)
        updated = source[:matches[0].start(2)] + str(number) + source[matches[0].end(2):]
        project.write_text(updated)
    return number


@contextmanager
def reservation_lock(path):
    with path.open('a') as handle:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError('Another release command is running on this Mac.') from None
        yield


def verify(archive, number, project):
    source = project.read_text()
    expected = set(re.findall(r'PRODUCT_BUNDLE_IDENTIFIER:\s*(\S+)', source))
    expected.discard(APP_ID + '.tests')
    marketing = re.search(r'^\s*MARKETING_VERSION:\s*(\S+)', source, re.MULTILINE).group(1)
    apps = list((archive / 'Products/Applications').glob('*.app'))
    if len(apps) != 1:
        raise ValueError('Archive must contain exactly one top-level app.')
    bundles = [apps[0]] + sorted(p for p in apps[0].rglob('*') if p.suffix in ('.app', '.appex') and p.is_dir())
    found = set()
    for bundle in bundles:
        info = plistlib.loads((bundle / 'Info.plist').read_bytes())
        identifier = info['CFBundleIdentifier']
        if identifier in found:
            raise ValueError(f'Duplicate bundle: {identifier}')
        found.add(identifier)
        if str(info['CFBundleVersion']) != str(number) or str(info['CFBundleShortVersionString']) != marketing:
            raise ValueError(f'Version mismatch in {identifier}')
    if found != expected:
        raise ValueError(f'Bundle mismatch: missing {sorted(expected-found)}, unexpected {sorted(found-expected)}')
    metadata = plistlib.loads((archive / 'Info.plist').read_bytes())['ApplicationProperties']
    if metadata['CFBundleIdentifier'] != APP_ID or str(metadata['CFBundleVersion']) != str(number):
        raise ValueError('Organizer archive metadata does not match the app.')
    return sorted(found)


def run(command):
    print('+ ' + ' '.join(map(str, command)), flush=True)
    subprocess.run(command, cwd=ROOT, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--latest-uploaded', required=True, type=int,
                        help='Highest build currently uploaded to TestFlight/App Store Connect (check before running).')
    parser.add_argument('--dry-run', action='store_true', help='Show next number without reserving, changing project, or building.')
    args = parser.parse_args()
    positive(args.latest_uploaded)
    archives = Path.home() / 'Library/Developer/Xcode/Archives'
    state_dir = Path.home() / 'Library/Application Support/Counting Sheep Release'
    state_dir.mkdir(parents=True, exist_ok=True)
    with reservation_lock(state_dir / 'archive.lock'):
        if not args.dry_run:
            for tool in ('xcodegen', 'xcodebuild'):
                if not shutil.which(tool):
                    raise RuntimeError(f'{tool} is required.')
        number = reserve(ROOT / 'project.yml', state_dir / 'build-number.json', archives,
                         args.latest_uploaded, args.dry_run)
        print(f'{"Next" if args.dry_run else "Reserved"} build: {number}', flush=True)
        if args.dry_run:
            return
        now = datetime.now()
        archive = archives / now.strftime('%Y-%m-%d') / f'Counting Sheep {number} {now:%H-%M-%S}.xcarchive'
        if archive.exists():
            raise RuntimeError(f'Archive already exists: {archive}')
        archive.parent.mkdir(parents=True, exist_ok=True)
        run(['xcodegen', 'generate'])
        run(['xcodebuild', 'archive', '-project', 'PhoneInTheOtherRoom.xcodeproj',
             '-scheme', 'PhoneInTheOtherRoom', '-configuration', 'Release',
             '-destination', 'generic/platform=iOS', '-archivePath', str(archive),
             f'CURRENT_PROJECT_VERSION={number}'])
        identifiers = verify(archive, number, ROOT / 'project.yml')
        print(f'Verified build {number} across {len(identifiers)} bundles.\nArchive: {archive}\nNo upload performed.')
        print('Use this archive in Organizer. Disable upload-time version management to retain this number.')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, RuntimeError, OSError, KeyError, subprocess.CalledProcessError) as error:
        print(f'Archive failed: {error}\nAny reserved number remains consumed. Run again for a fresh archive.', file=sys.stderr)
        sys.exit(1)
