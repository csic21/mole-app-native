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


class PublicDownloadTests(unittest.TestCase):
    def test_only_expected_public_asset_url(self):
        url = "https://github.com/owner/repo/releases/download/v0.4.2/Qili-0.4.2.zip"
        self.assertEqual(validate_asset_url(url, "owner/repo", "v0.4.2", "Qili-0.4.2.zip"), url)
        for value in [url.replace("github.com", "evil.example"), url.replace("https:", "http:"),
                      url + "?token=secret", url.replace("v0.4.2", "v0.4.1")]:
            with self.subTest(value=value), self.assertRaises(ReleaseError):
                validate_asset_url(value, "owner/repo", "v0.4.2", "Qili-0.4.2.zip")

    def test_download_sends_no_authentication(self):
        requests = []
        def opener(request, timeout):
            requests.append(request)
            return BytesIO(b"zip")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "archive.zip"
            download_public_asset("https://github.com/example", path, 3, opener=opener)
            self.assertEqual(path.read_bytes(), b"zip")
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

    @patch("verify_published_release.verify")
    @patch("verify_published_release.download_public_asset")
    def test_success_rechecks_downloaded_app_and_records_provenance(self, download, native_verify):
        with tempfile.TemporaryDirectory() as directory:
            dist = Path(directory)
            name = "Qili-0.4.2.zip"
            data = b"fixture ZIP"
            digest = hashlib.sha256(data).hexdigest()
            (dist / name).write_bytes(data)
            (dist / (name + ".sha256")).write_text(f"{digest}  {name}\n")
            receipt = {"version": "0.4.2", "source_sha": "a" * 40, "tag": "v0.4.2",
                       "repository": "owner/repo", "release_id": 1,
                       "html_url": "https://github.com/owner/repo/releases/tag/v0.4.2",
                       "assets": [{"name": filename, "size": (dist / filename).stat().st_size,
                                   "browser_download_url": "https://github.com/owner/repo/releases/download/v0.4.2/" + filename}
                                  for filename in [name, name + ".sha256"]]}
            (dist / "release-publication.json").write_text(json.dumps(receipt))
            download.side_effect = lambda url, path, size: path.write_bytes((dist / path.name).read_bytes())
            native_verify.return_value = digest
            verify_public(dist, "arm64")
            native_verify.assert_called_once_with(dist / "public-verification" / name, "0.4.2", "arm64")
            report = json.loads((dist / "public-verification/provenance.json").read_text())
            self.assertEqual(report["status"], "verified")
            self.assertFalse(report["authentication_sent"])
            self.assertEqual(report["assets"][0]["sha256"], digest)

    @patch("verify_published_release.verify")
    @patch("verify_published_release.download_public_asset")
    def test_public_hash_mismatch_is_recorded_without_changing_release(self, download, native_verify):
        with tempfile.TemporaryDirectory() as directory:
            dist = Path(directory)
            name = "Qili-0.4.2.zip"
            (dist / name).write_bytes(b"original")
            (dist / (name + ".sha256")).write_bytes(b"checksum")
            receipt = {"version": "0.4.2", "source_sha": "a" * 40, "tag": "v0.4.2",
                       "repository": "owner/repo", "release_id": 1, "html_url": "https://github.com/owner/repo/releases/tag/v0.4.2",
                       "assets": [{"name": filename, "size": 8,
                                   "browser_download_url": "https://github.com/owner/repo/releases/download/v0.4.2/" + filename}
                                  for filename in [name, name + ".sha256"]]}
            (dist / "release-publication.json").write_text(json.dumps(receipt))
            download.side_effect = lambda url, path, size: path.write_bytes(b"tampered")
            with self.assertRaisesRegex(ReleaseError, "release was left unchanged"):
                verify_public(dist, "arm64")
            report = json.loads((dist / "public-verification/provenance.json").read_text())
            self.assertEqual(report["status"], "failed_after_publication")
            native_verify.assert_not_called()


if __name__ == "__main__":
    unittest.main()
