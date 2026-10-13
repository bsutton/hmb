#!/usr/bin/env python3
"""Reject APKs whose enabled Android components are absent from their DEX.

Run after a release build and before installing it. Requires Android SDK's
apkanalyzer (on PATH, or supply --apkanalyzer). This catches packaging failures
that Flutter unit tests and debug bundles cannot exercise.
"""

import argparse
import subprocess
import sys
import xml.etree.ElementTree as ET

ANDROID = "{http://schemas.android.com/apk/res/android}"


def missing_components(manifest, dex_packages):
    root = ET.fromstring(manifest)
    # apkanalyzer: C d <methods> <fields> <bytes> <fully qualified class>
    classes = {
        line.split()[-1]
        for line in dex_packages.splitlines()
        if line.startswith("C d ")
    }
    if not classes:
        raise ValueError("apkanalyzer returned no defined DEX classes")
    package = root.attrib["package"]
    missing = []
    app = root.find("application")
    if app is None:
        raise ValueError("APK has no application element")
    for node in [app, *app]:
        if node.tag not in {"application", "activity", "service", "receiver", "provider"}:
            continue
        # Disabled metadata-only services (e.g. Play photo picker) need no class.
        if node.get(ANDROID + "enabled") == "false":
            continue
        name = node.get(ANDROID + "name")
        if not name:
            continue
        if name.startswith("."):
            name = package + name
        elif "." not in name:
            name = package + "." + name
        if not name.startswith("android.") and name not in classes:
            missing.append((node.tag, name))
    return missing


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk")
    parser.add_argument("--apkanalyzer", default="apkanalyzer")
    args = parser.parse_args()

    def analyze(*command):
        return subprocess.run(
            [args.apkanalyzer, *command, args.apk],
            check=True, capture_output=True, text=True,
        ).stdout

    try:
        missing = missing_components(
            analyze("manifest", "print"),
            analyze("dex", "packages", "--defined-only"),
        )
    except (OSError, subprocess.CalledProcessError, ValueError, ET.ParseError) as error:
        print(f"APK validation failed: {error}", file=sys.stderr)
        return 2
    for kind, name in missing:
        print(f"Missing {kind} class: {name}", file=sys.stderr)
    if missing:
        return 1
    print("PASS: all enabled manifest component classes are packaged")
    return 0


if __name__ == "__main__":
    sys.exit(main())
