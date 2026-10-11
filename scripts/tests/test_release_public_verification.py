from io import BytesIO
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from release_request import ReleaseError
from verify_published_release import download_public_asset, validate_asset_url, verify_public


VERSION = "0.5.0"
TAG = "v" + VERSION
DMG_NAME = f"Qili-{VERSION}.dmg"


def appcast_xml(length):
    return f'''<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
    <channel>
        <item>
            <sparkle:version>{VERSION}</sparkle:version>
            <enclosure url="https://github.com/owner/repo/releases/download/{TAG}/{DMG_NAME}"
                       length="{length}" type="application/octet-stream"
                       sparkle:edSignature="c2lnbmF0dXJl"/>
        </item>
    </channel>
</rss>
'''


class PublicDownloadTests(unittest.TestCase):
    def test_only_expected_public_asset_url(self):
        url = f"https://github.com/owner/repo/releases/download/{TAG}/{DMG_NAME}"
        self.assertEqual(validate_asset_url(url, "owner/repo", TAG, DMG_NAME), url)
        for value in [url.replace("github.com", "evil.example"), url.replace("https:", "http:"),
                      url + "?token=secret", url.replace(TAG, "v0.4.9")]:
            with self.subTest(value=value), self.assertRaises(ReleaseError):
                validate_asset_url(value, "owner/repo", TAG, DMG_NAME)

    def test_download_sends_no_authentication(self):
        requests = []
        def opener(request, timeout):
            requests.append(request)
            return BytesIO(b"dmg")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "archive.dmg"
            download_public_asset("https://github.com/example", path, 3, opener=opener)
            self.assertEqual(path.read_bytes(), b"dmg")
        self.assertNotIn("Authorization", requests[0].headers)

    def test_transient_404_is_retried_but_authentication_failure_is_not(self):
        for code, expected_calls in [(404, 6), (403, 1)]:
            calls, waits = [], []
            def opener(request, timeout):
                calls.append(request)
                raise HTTPError(request.full_url, code, "fixture", {}, None)
            with tempfile.TemporaryDirectory() as directory, self.assertRaises(ReleaseError):
                download_public_asset("https://github.com/example", Path(directory) / "archive", 3,
                                      opener=opener, sleep=waits.append)
            self.assertEqual(len(calls), expected_calls)
            self.assertEqual(len(waits), expected_calls - 1)

    def test_content_size_mismatch_is_not_retried(self):
        calls = []
        def opener(request, timeout):
            calls.append(request)
            return BytesIO(b"unexpected bytes")
        with tempfile.TemporaryDirectory() as directory, self.assertRaises(ReleaseError):
            download_public_asset("https://github.com/example", Path(directory) / "archive", 3, opener=opener)
        self.assertEqual(len(calls), 1)

    def make_dist(self, directory, appcast_length_delta=0):
        dist = Path(directory)
        dmg = dist / DMG_NAME
        dmg.write_bytes(b"fixture DMG")
        digest = hashlib.sha256(dmg.read_bytes()).hexdigest()
        (dist / (DMG_NAME + ".sha256")).write_text(f"{digest}  {DMG_NAME}\n")
        (dist / "appcast.xml").write_text(appcast_xml(dmg.stat().st_size + appcast_length_delta))
        receipt = {"version": VERSION, "source_sha": "a" * 40, "tag": TAG,
                   "repository": "owner/repo", "release_id": 1,
                   "html_url": f"https://github.com/owner/repo/releases/tag/{TAG}",
                   "assets": [{"name": filename, "size": (dist / filename).stat().st_size,
                               "browser_download_url": f"https://github.com/owner/repo/releases/download/{TAG}/{filename}"}
                              for filename in [DMG_NAME, DMG_NAME + ".sha256", "appcast.xml"]]}
        (dist / "release-publication.json").write_text(json.dumps(receipt))
        return dist, dmg, digest

    @patch("verify_published_release.verify_dmg")
    @patch("verify_published_release.download_public_asset")
    def test_success_rechecks_downloaded_app_and_records_provenance(self, download, native_verify):
        with tempfile.TemporaryDirectory() as directory:
            dist, dmg, digest = self.make_dist(directory)
            download.side_effect = lambda url, path, size: path.write_bytes((dist / path.name).read_bytes())
            native_verify.return_value = digest
            verify_public(dist, "arm64")
            native_verify.assert_called_once_with(dist / "public-verification" / DMG_NAME, VERSION, "arm64")
            report = json.loads((dist / "public-verification/provenance.json").read_text())
            self.assertEqual(report["status"], "verified")
            self.assertFalse(report["authentication_sent"])
            self.assertEqual(report["assets"][0]["sha256"], digest)
            self.assertEqual(report["sparkle_appcast"], "verified")

    @patch("verify_published_release.verify_dmg")
    @patch("verify_published_release.download_public_asset")
    def test_appcast_binding_mismatch_is_recorded_without_changing_release(self, download, native_verify):
        with tempfile.TemporaryDirectory() as directory:
            dist, dmg, digest = self.make_dist(directory, appcast_length_delta=1)
            download.side_effect = lambda url, path, size: path.write_bytes((dist / path.name).read_bytes())
            native_verify.return_value = digest
            with self.assertRaisesRegex(ReleaseError, "release was left unchanged"):
                verify_public(dist, "arm64")
            report = json.loads((dist / "public-verification/provenance.json").read_text())
            self.assertEqual(report["status"], "failed_after_publication")

    @patch("verify_published_release.verify_dmg")
    @patch("verify_published_release.download_public_asset")
    def test_public_hash_mismatch_is_recorded_without_changing_release(self, download, native_verify):
        with tempfile.TemporaryDirectory() as directory:
            dist, _, _ = self.make_dist(directory)
            download.side_effect = lambda url, path, size: path.write_bytes(b"tampered")
            with self.assertRaisesRegex(ReleaseError, "release was left unchanged"):
                verify_public(dist, "arm64")
            report = json.loads((dist / "public-verification/provenance.json").read_text())
            self.assertEqual(report["status"], "failed_after_publication")
            native_verify.assert_not_called()


if __name__ == "__main__":
    unittest.main()
