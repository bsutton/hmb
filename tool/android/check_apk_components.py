#!/usr/bin/env python3
"""Reject APKs whose enabled Android components are absent from their DEX.

Run after a release build and before installing it. Requires Android SDK's
apkanalyzer (on PATH, or supply --apkanalyzer). This catches packaging failures
that Flutter unit tests and debug bundles cannot exercise.
"""

import argparse
import subprocess
import sys
import zipfile
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
        if node.tag not in {"application", "activity", "service", "receiver", "provider", "activity-alias"}:
            continue
        # Disabled metadata-only services (e.g. Play photo picker) need no class.
        if node.get(ANDROID + "enabled") == "false":
            continue
        attributes = ["targetActivity"] if node.tag == "activity-alias" else ["name"]
        if node.tag == "application":
            attributes.append("appComponentFactory")
        for attribute in attributes:
            name = node.get(ANDROID + attribute)
            if not name:
                continue
            if name.startswith("."):
                name = package + name
            elif "." not in name:
                name = package + "." + name
            if not name.startswith("android.") and name not in classes:
                missing.append((node.tag if attribute == "name" else attribute, name))
    return missing


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", nargs="+")
    parser.add_argument("--apkanalyzer", default="apkanalyzer")
    args = parser.parse_args()

    def analyze(apk, *command):
        return subprocess.run(
            [args.apkanalyzer, *command, apk],
            check=True, capture_output=True, text=True,
        ).stdout

    try:
        manifests = [analyze(apk, "manifest", "print") for apk in args.apk]
        dex = []
        for apk in args.apk:
            with zipfile.ZipFile(apk) as archive:
                if any(name.startswith("classes") and name.endswith(".dex")
                       for name in archive.namelist()):
                    dex.append(analyze(apk, "dex", "packages", "--defined-only"))
        missing = sorted({component for manifest in manifests
                          for component in missing_components(manifest, "\n".join(dex))})
    except (OSError, subprocess.CalledProcessError, ValueError, ET.ParseError, zipfile.BadZipFile) as error:
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
