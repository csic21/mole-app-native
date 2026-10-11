#!/usr/bin/env python3
"""Download public release assets without credentials and verify the delivered app."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import time
from urllib.error import HTTPError, URLError
from urllib.parse import unquote, urlparse
from urllib.request import Request, urlopen

from release_request import ReleaseError, validate_sha, validate_version
from verify_release_artifact import verify


TRANSIENT_HTTP = {404, 429, 500, 502, 503, 504}


def validate_asset_url(url, repository, tag, filename):
    parsed = urlparse(url)
    expected_path = f"/{repository}/releases/download/{tag}/{filename}"
    if (parsed.scheme != "https" or parsed.netloc != "github.com"
            or unquote(parsed.path) != expected_path or parsed.query or parsed.fragment):
        raise ReleaseError("public asset URL does not match the intended repository/tag/name")
    return url


def download_public_asset(url, destination, expected_size, opener=urlopen, sleep=time.sleep):
    """Only retry transient availability/network errors, never a content mismatch."""
    if type(expected_size) is not int or expected_size <= 0:
        raise ReleaseError("invalid expected public asset size")
    for attempt in range(6):
        try:
            # Deliberately no Authorization header or token. Redirects are public too.
            request = Request(url, headers={"Accept": "application/octet-stream",
                                            "User-Agent": "Qili-public-release-verification"})
            with opener(request, timeout=60) as response, destination.open("wb") as output:
                size = 0
                while chunk := response.read(1024 * 1024):
                    size += len(chunk)
                    if size > expected_size:
                        raise ReleaseError("public asset exceeds its verified size")
                    output.write(chunk)
                if size != expected_size:
                    raise ReleaseError("public asset size differs from the verified original")
            return
        except (HTTPError, URLError, TimeoutError, ConnectionError) as error:
            transient = (isinstance(error, HTTPError) and error.code in TRANSIENT_HTTP)
            if not isinstance(error, HTTPError):
                reason = error.reason if isinstance(error, URLError) else error
                transient = isinstance(reason, (TimeoutError, ConnectionError))
            if not transient or attempt == 5:
                raise ReleaseError("public download failed; published release was not changed") from error
            sleep(2 ** (attempt + 1))


def verify_public(dist, expected_arch):
    receipt = json.loads((dist / "release-publication.json").read_text())
    version = validate_version(receipt["version"])
    source = validate_sha(receipt["source_sha"])
    tag = "v" + version
    if receipt["tag"] != tag:
        raise ReleaseError("publication receipt tag mismatch")
    archive_name = f"Qili-{version}.zip"
    checksum_name = archive_name + ".sha256"
    assets = receipt["assets"]
    if len(assets) != 2 or {item["name"] for item in assets} != {archive_name, checksum_name}:
        raise ReleaseError("publication receipt does not contain the two expected assets")
    output = dist / "public-verification"
    output.mkdir(parents=True, exist_ok=True)
    report = {"status": "started", "release_url": receipt["html_url"],
              "release_id": receipt["release_id"], "tag": tag, "source_sha": source,
              "architecture": expected_arch, "authentication_sent": False,
              "started_at": datetime.now(timezone.utc).isoformat(), "assets": []}
    report_path = output / "provenance.json"
    try:
        for asset in assets:
            filename = asset["name"]
            local = dist / filename
            if local.stat().st_size != asset["size"]:
                raise ReleaseError("local asset changed after publication")
            url = validate_asset_url(asset["browser_download_url"], receipt["repository"], tag, filename)
            downloaded = output / filename
            download_public_asset(url, downloaded, asset["size"])
            original_hash = hashlib.sha256(local.read_bytes()).hexdigest()
            public_hash = hashlib.sha256(downloaded.read_bytes()).hexdigest()
            if original_hash != public_hash:
                raise ReleaseError("public asset bytes differ from the locally verified original")
            report["assets"].append({"name": filename, "url": url, "size": asset["size"],
                                     "sha256": public_hash, "matches_original": True})
        digest = verify(output / archive_name, version, expected_arch)
        if (output / checksum_name).read_text() != f"{digest}  {archive_name}\n":
            raise ReleaseError("downloaded SHA-256 sidecar does not match downloaded ZIP")
        report.update(status="verified", app_version=version,
                      bundle_identifier="com.csic21.moleapp", signature="ad-hoc", notarized=False,
                      completed_at=datetime.now(timezone.utc).isoformat())
    except Exception as error:
        report.update(status="failed_after_publication", error=str(error),
                      completed_at=datetime.now(timezone.utc).isoformat())
        raise ReleaseError("post-publication download/app verification failed; release was left unchanged") from error
    finally:
        report_path.write_text(json.dumps(report, indent=2) + "\n")
    print(f"Verified public {tag} ZIP, SHA-256, bundle/resources, Mach-O and ad-hoc signature")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dist", default="dist")
    parser.add_argument("--arch", required=True, choices=["arm64", "x86_64"])
    args = parser.parse_args()
    verify_public(Path(args.dist).resolve(), args.arch)


if __name__ == "__main__":
    main()
