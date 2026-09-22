"""Static checks only; this does not validate an archive or App Store readiness."""

import pathlib
import plistlib
import unittest


class RunnerPlistTest(unittest.TestCase):
    def test_active_runner_permissions_and_links(self):
        root = pathlib.Path(__file__).resolve().parents[1]
        project = (root / "ios/Runner.xcodeproj/project.pbxproj").read_text()
        self.assertIn("INFOPLIST_FILE = Runner/Info.plist", project)
        with (root / "ios/Runner/Info.plist").open("rb") as source:
            config = plistlib.load(source)
        for key in ("NSCameraUsageDescription", "NSPhotoLibraryUsageDescription"):
            self.assertTrue(config[key].strip())
        self.assertTrue({"tel", "sms", "mailto"}.issubset(
            config["LSApplicationQueriesSchemes"]))
        schemes = {scheme for entry in config["CFBundleURLTypes"]
                   for scheme in entry["CFBundleURLSchemes"]}
        self.assertIn("dev.onepub.handyman", schemes)
        self.assertEqual(config["CFBundleIdentifier"], "$(PRODUCT_BUNDLE_IDENTIFIER)")
        self.assertNotIn("NSLocationAlwaysUsageDescription", config)


if __name__ == "__main__":
    unittest.main()
