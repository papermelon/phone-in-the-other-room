import importlib.util
import json
from pathlib import Path
import plistlib
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('archive_release', Path(__file__).parents[1] / 'archive-release.py')
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.project = self.root / 'project.yml'
        self.project.write_text('settings:\n  base:\n    CURRENT_PROJECT_VERSION: 41\n    MARKETING_VERSION: 1.0\n'
                                '    PRODUCT_BUNDLE_IDENTIFIER: com.ngawangchime.countingsheep\n'
                                '    PRODUCT_BUNDLE_IDENTIFIER: com.ngawangchime.countingsheep.watchkitapp\n'
                                '    PRODUCT_BUNDLE_IDENTIFIER: com.ngawangchime.countingsheep.liveactivity\n')
        self.state = self.root / 'state.json'
        self.archives = self.root / 'Archives'

    def plist(self, path, value):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(plistlib.dumps(value))

    def fixture(self, number=45):
        archive = self.archives / '2026-09-07' / 'test.xcarchive'
        app = archive / 'Products/Applications/Counting Sheep.app'
        for path, suffix in [(app, ''), (app/'Watch/Watch.app', '.watchkitapp'),
                             (app/'PlugIns/Live.appex', '.liveactivity')]:
            self.plist(path/'Info.plist', {'CFBundleIdentifier': release.APP_ID+suffix,
                                         'CFBundleVersion': str(number), 'CFBundleShortVersionString': '1.0'})
        self.plist(archive/'Info.plist', {'ApplicationProperties': {
            'CFBundleIdentifier': release.APP_ID, 'CFBundleVersion': str(number)}})
        return archive, app

    def test_number_exceeds_all_sources_and_failed_attempt_is_consumed(self):
        self.fixture(45)
        self.state.write_text(json.dumps({'last_reserved': 47}))
        self.assertEqual(release.reserve(self.project, self.state, self.archives, 49), 50)
        self.assertIn('CURRENT_PROJECT_VERSION: 50', self.project.read_text())
        self.assertEqual(release.reserve(self.project, self.state, self.archives, 49), 51)

    def test_dry_run_preserves_project_and_reservation(self):
        original = self.project.read_bytes()
        self.assertEqual(release.reserve(self.project, self.state, self.archives, 41, True), 42)
        self.assertEqual(self.project.read_bytes(), original)
        self.assertFalse(self.state.exists())

    def test_malformed_state_fails_without_changing_project(self):
        self.state.write_text('broken')
        original = self.project.read_bytes()
        with self.assertRaises(ValueError):
            release.reserve(self.project, self.state, self.archives, 41)
        self.assertEqual(self.project.read_bytes(), original)

    def test_ambiguous_project_setting_rejected(self):
        self.project.write_text(self.project.read_text()+'    CURRENT_PROJECT_VERSION: 42\n')
        with self.assertRaises(ValueError):
            release.reserve(self.project, self.state, self.archives, 41)

    def test_verify_all_embedded_bundles(self):
        archive, _ = self.fixture()
        self.assertEqual(len(release.verify(archive, 45, self.project)), 3)

    def test_missing_extension_rejected(self):
        archive, app = self.fixture()
        import shutil
        shutil.rmtree(app/'PlugIns')
        with self.assertRaisesRegex(ValueError, 'missing'):
            release.verify(archive, 45, self.project)

    def test_wrong_watch_version_rejected(self):
        archive, app = self.fixture()
        path = app/'Watch/Watch.app/Info.plist'
        info = plistlib.loads(path.read_bytes())
        info['CFBundleVersion'] = '44'
        self.plist(path, info)
        with self.assertRaisesRegex(ValueError, 'Version mismatch'):
            release.verify(archive, 45, self.project)

    def test_wrong_organizer_metadata_rejected(self):
        archive, _ = self.fixture()
        self.plist(archive/'Info.plist', {'ApplicationProperties': {
            'CFBundleIdentifier': release.APP_ID, 'CFBundleVersion': '44'}})
        with self.assertRaisesRegex(ValueError, 'metadata'):
            release.verify(archive, 45, self.project)

    def test_command_regenerates_then_archives_and_verifies(self):
        from unittest.mock import patch
        import shutil
        import sys
        archive, _ = self.fixture(46)
        commands = []
        def fake_run(command):
            commands.append(command)
            self.assertIn('CURRENT_PROJECT_VERSION: 46', self.project.read_text())
            if command[0] == 'xcodebuild':
                destination = Path(command[command.index('-archivePath') + 1])
                shutil.copytree(archive, destination)
        with patch.object(release, 'ROOT', self.root), patch.object(Path, 'home', return_value=self.root), \
             patch.object(release, 'run', side_effect=fake_run), \
             patch.object(release.shutil, 'which', return_value='/test/tool'), \
             patch.object(sys, 'argv', ['archive-release.py', '--latest-uploaded', '45']):
            release.main()
        self.assertEqual([command[0] for command in commands], ['xcodegen', 'xcodebuild'])
        self.assertIn('CURRENT_PROJECT_VERSION=46', commands[1])

    def test_generator_failure_stops_archive_and_keeps_reservation(self):
        from unittest.mock import patch
        import subprocess
        import sys
        with patch.object(release, 'ROOT', self.root), patch.object(Path, 'home', return_value=self.root), \
             patch.object(release, 'run', side_effect=subprocess.CalledProcessError(1, 'xcodegen')) as run, \
             patch.object(release.shutil, 'which', return_value='/test/tool'), \
             patch.object(sys, 'argv', ['archive-release.py', '--latest-uploaded', '45']):
            with self.assertRaises(subprocess.CalledProcessError):
                release.main()
        self.assertEqual(run.call_count, 1)
        self.assertIn('CURRENT_PROJECT_VERSION: 46', self.project.read_text())

    def test_concurrent_release_rejected(self):
        lock = self.root/'lock'
        with release.reservation_lock(lock):
            with self.assertRaisesRegex(RuntimeError, 'Another release'):
                with release.reservation_lock(lock):
                    self.fail('Second reservation obtained the lock')


if __name__ == '__main__':
    unittest.main()
