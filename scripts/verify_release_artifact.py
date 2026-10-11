#!/usr/bin/env python3
"""Verify the distributable DMG itself; write its checksum and release notes.

The legacy ZIP verifier is retained for the read-only v0.4.2 recovery path;
new releases ship a DMG that carries the drag-install layout and the Sparkle
update payload.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import platform
import plistlib
import stat
import subprocess
import tempfile
import zipfile

from release_request import ReleaseError, validate_sha, validate_version


DEFAULT_FEED_URL = "https://github.com/csic21/qili/releases/latest/download/appcast.xml"

APP_IDENTITY = {"CFBundleIdentifier": "com.csic21.moleapp", "CFBundleName": "Qili",
                "CFBundleExecutable": "MoleApp", "CFBundlePackageType": "APPL",
                "LSMinimumSystemVersion": "14.0"}

SPARKLE_COMPONENTS = ["Versions/B/Sparkle", "Versions/B/Autoupdate", "Versions/B/Updater.app",
                      "Versions/B/XPCServices/Installer.xpc", "Versions/B/XPCServices/Downloader.xpc"]


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
        expected = {"CFBundleShortVersionString": version, "CFBundleVersion": version, **APP_IDENTITY}
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
    """Legacy ZIP verification, kept for the pinned v0.4.2 recovery path."""
    inspect_zip(archive, version)
    if platform.system() != "Darwin":
        raise ReleaseError("Mach-O and codesign verification requires macOS")
    # ditto preserves the ZIP's executable modes and bundle metadata for verification.
    with tempfile.TemporaryDirectory(prefix="qili-release-") as temporary:
        subprocess.run(["ditto", "-x", "-k", str(archive), temporary], check=True)
        app = Path(temporary) / "Qili.app"
        binary = app / "Contents/MacOS/MoleApp"
        verify_native(app, binary, expected_arch)
    return hashlib.sha256(archive.read_bytes()).hexdigest()


def verify_native(app, binary, expected_arch):
    if platform.system() != "Darwin":
        raise ReleaseError("Mach-O and codesign verification requires macOS")
    architectures = subprocess.check_output(["lipo", "-archs", str(binary)], text=True).split()
    if set(architectures) != {expected_arch}:
        raise ReleaseError(f"unexpected Mach-O architectures: {architectures}")
    subprocess.run(["codesign", "--verify", "--deep", "--strict", "--verbose=2", str(app)], check=True)
    signature = subprocess.run(["codesign", "-d", "--verbose=4", str(app)],
                               check=True, capture_output=True, text=True).stderr
    if "Signature=adhoc" not in signature:
        raise ReleaseError("expected the documented ad-hoc signature")


def inspect_app(app, version, feed_url):
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    expected = {"CFBundleShortVersionString": version, "CFBundleVersion": version,
                "SUFeedURL": feed_url, "SUEnableAutomaticChecks": True, **APP_IDENTITY}
    if any(info.get(key) != value for key, value in expected.items()):
        raise ReleaseError("packaged app identity/version/update settings do not match release")
    public_key = info.get("SUPublicEDKey")
    try:
        decoded = base64.b64decode(public_key, validate=True)
    except Exception as error:
        raise ReleaseError("SUPublicEDKey is not valid base64") from error
    if len(decoded) != 32:
        raise ReleaseError("SUPublicEDKey must be a 32-byte EdDSA public key")
    framework = app / "Contents/Frameworks/Sparkle.framework"
    missing = [name for name in SPARKLE_COMPONENTS if not (framework / name).exists()]
    if missing:
        raise ReleaseError(f"embedded Sparkle.framework is incomplete: {missing}")
    for name in ["MacOS/MoleApp", "Resources/AppIcon.icns", "_CodeSignature/CodeResources"]:
        path = app / "Contents" / name
        if not path.is_file() or path.stat().st_size == 0:
            raise ReleaseError(f"empty required app resource: {name}")
    resource_root = app / "Contents/Resources/MoleApp_MoleApp.bundle"
    layouts = [resource_root, resource_root / "Contents/Resources"]
    if not any((root / "QiliLogo.png").is_file() and (root / "AppIcon.icns").is_file()
               for root in layouts):
        raise ReleaseError("SwiftPM resource bundle is missing its logo or app icon")
    binary = app / "Contents/MacOS/MoleApp"
    if not binary.stat().st_mode & stat.S_IXUSR:
        raise ReleaseError("app binary is not executable in the DMG")
    return binary


def verify_dmg(dmg, version, expected_arch, feed_url=DEFAULT_FEED_URL):
    if platform.system() != "Darwin":
        raise ReleaseError("DMG verification requires macOS")
    with tempfile.TemporaryDirectory(prefix="qili-release-") as temporary:
        mount = Path(temporary) / "mount"
        mount.mkdir()
        subprocess.run(["hdiutil", "attach", "-nobrowse", "-readonly",
                        "-mountpoint", str(mount), str(dmg)],
                       check=True, capture_output=True, text=True)
        try:
            applications = mount / "Applications"
            if not applications.is_symlink() or os.readlink(applications) != "/Applications":
                raise ReleaseError("DMG must contain an /Applications symlink for drag installs")
            app = mount / "Qili.app"
            if not app.is_dir():
                raise ReleaseError("DMG does not contain Qili.app")
            binary = inspect_app(app, version, feed_url)
            verify_native(app, binary, expected_arch)
        finally:
            detached = subprocess.run(["hdiutil", "detach", str(mount)],
                                      capture_output=True, text=True)
            if detached.returncode != 0:
                subprocess.run(["hdiutil", "detach", "-force", str(mount)], capture_output=True)
    return hashlib.sha256(dmg.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--dist", default="dist")
    parser.add_argument("--arch", required=True, choices=["arm64", "x86_64"])
    parser.add_argument("--feed-url", default=DEFAULT_FEED_URL)
    args = parser.parse_args()
    manifest = json.loads(Path(args.manifest).read_text())
    version, source = validate_version(manifest["version"]), validate_sha(manifest["source_sha"])
    dmg = Path(args.dist).resolve() / f"Qili-{version}.dmg"
    digest = verify_dmg(dmg, version, args.arch, args.feed_url)
    (dmg.parent / (dmg.name + ".sha256")).write_text(f"{digest}  {dmg.name}\n")
    (dmg.parent / "release-notes.md").write_text(
        f"Qili {version}\n\nSource revision: `{source}`\n\n"
        f"macOS 14 or later. Architecture: `{args.arch}`.\n\n"
        "Open the DMG and drag Qili into Applications. This app is ad-hoc signed "
        "and has not been notarized by Apple; macOS may require explicit approval "
        "before opening it. After the first install, Qili updates itself in-app "
        "via Sparkle.\n\n"
        f"SHA-256 (`{dmg.name}`): `{digest}`\n"
    )
    print(f"Verified {dmg.name}: {args.arch}, embedded Sparkle, ad-hoc signature, SHA-256 {digest}")


if __name__ == "__main__":
    main()
