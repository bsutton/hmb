import sqlite3
import tempfile
import unittest
from pathlib import Path

from check_apk_components import missing_components
from upgrade_fixture import fixture


class ComponentsTest(unittest.TestCase):
    def test_missing_provider_and_alias_target(self):
        manifest = '''<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="dev.test">
        <application><provider android:name=".Provider"/><activity-alias android:name=".Alias" android:targetActivity=".Activity"/>
        <service android:name=".Metadata" android:enabled="false"/></application></manifest>'''
        self.assertEqual(missing_components(manifest, 'C d 1 1 1 dev.test.Activity'), [('provider', 'dev.test.Provider')])
        self.assertEqual(missing_components(manifest, 'C d 1 1 1 dev.test.Activity\nC d 1 1 1 dev.test.Provider'), [])

    def test_missing_application_component_factory(self):
        manifest = '<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="dev.test"><application android:appComponentFactory="dev.test.Factory"/></manifest>'
        self.assertEqual(missing_components(manifest, 'C d 1 1 1 dev.test.Other'),
                         [('appComponentFactory', 'dev.test.Factory')])

    def test_empty_dex_fails_closed(self):
        with self.assertRaises(ValueError):
            missing_components('<manifest/>', '')

    def test_upgrade_fixture_detects_data_loss(self):
        with tempfile.TemporaryDirectory() as temp:
            path = str(Path(temp) / 'handyman.db')
            with sqlite3.connect(path) as db:
                db.execute('CREATE TABLE customer (name, description, createdDate, modifiedDate, disbarred, customerType)')
            fixture('seed', path)
            fixture('verify', path)
            with sqlite3.connect(path) as db:
                db.execute('DELETE FROM customer')
            with self.assertRaises(ValueError):
                fixture('verify', path)


if __name__ == '__main__':
    unittest.main()
