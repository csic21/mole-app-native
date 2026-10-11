#!/usr/bin/env python3
"""Generate and verify the EdDSA-signed Sparkle appcast for the release DMG."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET

from release_request import ReleaseError, validate_sha, validate_version


SPARKLE_NAMESPACE = "http://www.andymatuschak.org/xml-namespaces/sparkle"
DOWNLOAD_PREFIX = "https://github.com/csic21/mole-app-native/releases/download"


def find_sparkle_tool(name):
    roots = [Path.cwd()]
    script = Path(__file__).resolve()
    if script.parent.name == "scripts":
        roots.append(script.parents[1])
    for root in roots:
        for path in sorted((root / ".build").rglob(name)):
            if path.is_file() and os.access(path, os.X_OK) and path.parent.name == "bin":
                return path
    raise ReleaseError(f"Sparkle tool not found: {name}")


def ed_signature(sign_update, dmg, private_key):
    """Return (signature, length). Ed25519 is deterministic, so re-signing doubles as verification."""
    result = subprocess.run([str(sign_update), "--ed-key-file", "-", str(dmg)],
                            input=private_key, capture_output=True, text=True)
    if result.returncode != 0:
        raise ReleaseError("sign_update failed")
    signature = re.search(r'sparkle:edSignature="([^"]+)"', result.stdout)
    length = re.search(r'length="([0-9]+)"', result.stdout)
    if not signature or not length:
        raise ReleaseError("sign_update did not return an EdDSA signature")
    return signature.group(1), int(length.group(1))


def verify_appcast(appcast, dmg, version, expected_signature, download_prefix=DOWNLOAD_PREFIX):
    root = ET.parse(appcast).getroot()
    items = root.findall("./channel/item")
    if len(items) != 1:
        raise ReleaseError("appcast must contain exactly one update item")
    item = items[0]
    if item.findtext(f"{{{SPARKLE_NAMESPACE}}}version") != version:
        raise ReleaseError("appcast version does not match the release")
    enclosure = item.find("enclosure")
    expected_url = f"{download_prefix}/v{version}/{dmg.name}"
    if enclosure is None or enclosure.get("url") != expected_url:
        raise ReleaseError("appcast enclosure URL does not match the release DMG")
    if int(enclosure.get("length", "0")) != dmg.stat().st_size:
        raise ReleaseError("appcast enclosure length does not match the DMG")
    signature = enclosure.get(f"{{{SPARKLE_NAMESPACE}}}edSignature")
    expected_value, expected_length = expected_signature
    if signature != expected_value or int(enclosure.get("length", "0")) != expected_length:
        raise ReleaseError("appcast EdDSA signature does not match the release DMG")
    return expected_url


def generate(version, dist, private_key, generate_appcast, sign_update):
    dmg = dist / f"Qili-{version}.dmg"
    if not dmg.is_file():
        raise ReleaseError("release DMG is missing")
    staging = dist / ".appcast-staging"
    shutil.rmtree(staging, ignore_errors=True)
    staging.mkdir()
    shutil.copy2(dmg, staging / dmg.name)
    notes = dist / "release-notes.md"
    if notes.is_file():
        shutil.copy2(notes, staging / f"Qili-{version}.md")
    result = subprocess.run([str(generate_appcast),
                             "--ed-key-file", "-",
                             "--download-url-prefix", f"{DOWNLOAD_PREFIX}/v{version}/",
                             "--embed-release-notes",
                             "-o", str(staging / "appcast.xml"),
                             str(staging)],
                            input=private_key, capture_output=True, text=True)
    if result.returncode != 0:
        raise ReleaseError(f"generate_appcast failed: {result.stderr.strip()[-500:]}")
    appcast = staging / "appcast.xml"
    if not appcast.is_file():
        raise ReleaseError("generate_appcast did not produce appcast.xml")
    verify_appcast(appcast, dmg, version, ed_signature(sign_update, dmg, private_key))
    (dist / "appcast.xml").write_text(appcast.read_text())
    shutil.rmtree(staging, ignore_errors=True)
    return dist / "appcast.xml"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--dist", default="dist")
    args = parser.parse_args()
    manifest = json.loads(Path(args.manifest).read_text())
    version, source = validate_version(manifest["version"]), validate_sha(manifest["source_sha"])
    private_key = os.environ.get("SPARKLE_PRIVATE_KEY", "").strip()
    if not private_key:
        raise ReleaseError("SPARKLE_PRIVATE_KEY is required to sign the appcast")
    tools = {name: find_sparkle_tool(name) for name in ("generate_appcast", "sign_update")}
    appcast = generate(version, Path(args.dist).resolve(), private_key,
                       tools["generate_appcast"], tools["sign_update"])
    print(f"Generated and verified signed appcast for {version}: {appcast} (source {source[:8]})")


if __name__ == "__main__":
    main()
