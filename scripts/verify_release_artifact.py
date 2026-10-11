#!/usr/bin/env python3
"""Verify the distributable ZIP itself; write its checksum and release notes."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import platform
import plistlib
import stat
import subprocess
import tempfile
import zipfile

from release_request import ReleaseError, validate_sha, validate_version


def inspect_zip(archive, version):
    with zipfile.ZipFile(archive) as bundle:
        names = bundle.namelist()
        if len(names) != len(set(names)):
            raise ReleaseError("ZIP contains duplicate paths")
        for entry in bundle.infolist():
            path = PurePosixPath(entry.filename)
            mode = entry.external_attr >> 16
            if (path.is_absolute() or ".." in path.parts or not path.parts
                    or path.parts[0] != "Qili.app" or stat.S_ISLNK(mode)):
                raise ReleaseError("ZIP contains an unsafe or unexpected path")
        prefix = "Qili.app/Contents/"
        info = plistlib.loads(bundle.read(prefix + "Info.plist"))
        expected = {"CFBundleShortVersionString": version, "CFBundleVersion": version,
                    "CFBundleIdentifier": "com.csic21.moleapp", "CFBundleName": "Qili",
                    "CFBundleExecutable": "MoleApp", "CFBundlePackageType": "APPL",
                    "LSMinimumSystemVersion": "14.0"}
        if any(info.get(key) != value for key, value in expected.items()):
            raise ReleaseError("packaged app identity/version does not match release")
        for name in ["MacOS/MoleApp", "Resources/AppIcon.icns",
                     "_CodeSignature/CodeResources"]:
            if bundle.getinfo(prefix + name).file_size == 0:
                raise ReleaseError(f"empty required app resource: {name}")
        resource_root = prefix + "Resources/MoleApp_MoleApp.bundle/"
        resource_layouts = [resource_root, resource_root + "Contents/Resources/"]
        if not any(all(root + name in names and bundle.getinfo(root + name).file_size > 0
                       for name in ["QiliLogo.png", "AppIcon.icns"]) for root in resource_layouts):
            raise ReleaseError("SwiftPM resource bundle is missing its logo or app icon")
        executable = bundle.getinfo(prefix + "MacOS/MoleApp")
        if not ((executable.external_attr >> 16) & 0o111):
            raise ReleaseError("app binary is not executable in the ZIP")
        return bundle.read(prefix + "Info.plist")


def verify(archive, version, expected_arch):
    inspect_zip(archive, version)
    if platform.system() != "Darwin":
        raise ReleaseError("Mach-O and codesign verification requires macOS")
    # ditto preserves the ZIP's executable modes and bundle metadata for verification.
    with tempfile.TemporaryDirectory(prefix="qili-release-") as temporary:
        subprocess.run(["ditto", "-x", "-k", str(archive), temporary], check=True)
        app = Path(temporary) / "Qili.app"
        binary = app / "Contents/MacOS/MoleApp"
        architectures = subprocess.check_output(["lipo", "-archs", str(binary)], text=True).split()
        if set(architectures) != {expected_arch}:
            raise ReleaseError(f"unexpected Mach-O architectures: {architectures}")
        subprocess.run(["codesign", "--verify", "--deep", "--strict", "--verbose=2", str(app)], check=True)
        signature = subprocess.run(["codesign", "-d", "--verbose=4", str(app)],
                                   check=True, capture_output=True, text=True).stderr
        if "Signature=adhoc" not in signature:
            raise ReleaseError("expected the documented ad-hoc signature")
    return hashlib.sha256(archive.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--dist", default="dist")
    parser.add_argument("--arch", required=True, choices=["arm64", "x86_64"])
    args = parser.parse_args()
    manifest = json.loads(Path(args.manifest).read_text())
    version, source = validate_version(manifest["version"]), validate_sha(manifest["source_sha"])
    archive = Path(args.dist).resolve() / f"Qili-{version}.zip"
    digest = verify(archive, version, args.arch)
    (archive.parent / (archive.name + ".sha256")).write_text(f"{digest}  {archive.name}\n")
    (archive.parent / "release-notes.md").write_text(
        f"Qili {version}\n\nSource revision: `{source}`\n\n"
        f"macOS 14 or later. Architecture: `{args.arch}`.\n\n"
        "This app is ad-hoc signed and has not been notarized by Apple. "
        "macOS may require explicit approval before opening it.\n\n"
        f"SHA-256 (`{archive.name}`): `{digest}`\n"
    )
    print(f"Verified {archive.name}: {args.arch}, ad-hoc signature, SHA-256 {digest}")


if __name__ == "__main__":
    main()
