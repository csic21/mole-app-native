from copy import deepcopy
import hashlib
from io import BytesIO
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import call, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from release_request import ReleaseError
from verify_existing_release import parse_verification_request, public_json, verify_existing

VERSION = "0.4.2"
SOURCE = "a" * 40
REPOSITORY = "owner/repo"
BASE = "https://api.github.com/repos/" + REPOSITORY
ARCHIVE = "Qili-0.4.2.zip"


def fixtures(sidecar=None):
    archive = b"fixture ZIP bytes"
    digest = hashlib.sha256(archive).hexdigest()
    files = {ARCHIVE: archive, ARCHIVE + ".sha256":
             sidecar if sidecar is not None else f"{digest}  {ARCHIVE}\n".encode()}
    request = {"version": VERSION, "source_sha": SOURCE, "architecture": "arm64", "assets": [
        {"name": name, "size": len(data), "sha256": hashlib.sha256(data).hexdigest()}
        for name, data in files.items()]}
    ref = {"ref": "refs/tags/v" + VERSION,
           "object": {"sha": SOURCE, "type": "commit", "url": BASE + "/git/commits/" + SOURCE}}
    release = {"id": 7, "draft": False, "tag_name": "v" + VERSION, "target_commitish": SOURCE,
               "published_at": "2026-10-11T08:00:00Z",
               "html_url": f"https://github.com/{REPOSITORY}/releases/tag/v{VERSION}",
               "assets": [{"name": asset["name"], "size": asset["size"], "state": "uploaded",
                           "digest": "sha256:" + asset["sha256"],
                           "browser_download_url": f"https://github.com/{REPOSITORY}/releases/download/v{VERSION}/" + asset["name"]}
                          for asset in request["assets"]]}
    return request, ref, release, files, digest


class ExistingRequestTests(unittest.TestCase):
    def test_valid_pinned_request(self):
        request, *_ = fixtures()
        self.assertEqual(parse_verification_request(json.dumps(request)), request)
        request["architecture"] = "x86_64"
        self.assertEqual(parse_verification_request(json.dumps(request)), request)

    def test_strict_schema_and_duplicate_keys(self):
        request, *_ = fixtures()
        invalid = ["not JSON", "[]", "{}", "{" * 4097,
                   json.dumps(request).replace('"version": "0.4.2"', '"version":"0.4.1","version":"0.4.2"')]
        extra = deepcopy(request)
        extra["extra"] = True
        invalid.append(json.dumps(extra))
        for raw in invalid:
            with self.subTest(raw=raw[:100]), self.assertRaises(ReleaseError):
                parse_verification_request(raw)

    def test_reject_version_source_architecture_and_asset_errors(self):
        request, *_ = fixtures()
        cases = []
        for key, value in [("version", "v0.4.2"), ("version", "0.04.2"),
                           ("source_sha", "main"), ("source_sha", "A" * 40),
                           ("architecture", "universal"), ("assets", []), ("assets", {})]:
            case = deepcopy(request)
            case[key] = value
            cases.append(case)
        for key, value in [("name", "../../escape.zip"), ("name", 1), ("size", True),
                           ("size", 0), ("size", -1), ("size", 128 * 1024 * 1024 + 1),
                           ("sha256", "a" * 63), ("sha256", "G" * 64), ("sha256", None)]:
            case = deepcopy(request)
            case["assets"][0][key] = value
            cases.append(case)
        duplicate = deepcopy(request)
        duplicate["assets"][1] = deepcopy(duplicate["assets"][0])
        cases.append(duplicate)
        extra = deepcopy(request)
        extra["assets"][0]["url"] = "https://evil.example/"
        cases.append(extra)
        for case in cases:
            with self.subTest(case=case), self.assertRaises(ReleaseError):
                parse_verification_request(json.dumps(case))


class PublicJSONTests(unittest.TestCase):
    @patch("verify_existing_release.urlopen")
    def test_metadata_request_is_get_only_and_anonymous(self, opener):
        opener.return_value = BytesIO(b'{"id":7}')
        url = BASE + "/releases/tags/v0.4.2"
        self.assertEqual(public_json(url), {"id": 7})
        request = opener.call_args.args[0]
        self.assertEqual(request.full_url, url)
        self.assertEqual(request.get_method(), "GET")
        self.assertIsNone(request.data)
        self.assertNotIn("authorization", {key.lower() for key in request.headers})
        self.assertNotIn("cookie", {key.lower() for key in request.headers})


class ExistingReleaseVerificationTests(unittest.TestCase):
    def setUp(self):
        self.request, self.ref, self.release, self.files, self.digest = fixtures()
        self.temporary = tempfile.TemporaryDirectory()
        self.output = Path(self.temporary.name) / "public-verification"
        self.source_patch = patch("verify_existing_release.verify_source")
        self.public_patch = patch("verify_existing_release.public_json")
        self.download_patch = patch("verify_existing_release.download_public_asset")
        self.native_patch = patch("verify_existing_release.verify")
        self.source = self.source_patch.start()
        self.public = self.public_patch.start()
        self.download = self.download_patch.start()
        self.native = self.native_patch.start()
        self.public.side_effect = lambda url: deepcopy(self.ref if "/git/ref/" in url else self.release)
        self.download.side_effect = lambda url, path, size: path.write_bytes(self.files[path.name])
        self.native.return_value = self.digest
        self.addCleanup(self.temporary.cleanup)
        for patcher in [self.source_patch, self.public_patch, self.download_patch, self.native_patch]:
            self.addCleanup(patcher.stop)

    def run_verification(self):
        return verify_existing(self.request, REPOSITORY, self.output)

    def test_fresh_canonical_assets_original_hashes_and_native_success(self):
        self.run_verification()
        self.source.assert_called_once_with(VERSION, SOURCE)
        self.assertEqual(self.public.call_args_list, [
            call(BASE + "/git/ref/tags/v0.4.2"), call(BASE + "/releases/tags/v0.4.2")])
        self.assertEqual(self.download.call_count, 2)
        for asset, download_call in zip(self.release["assets"], self.download.call_args_list):
            self.assertEqual(download_call, call(asset["browser_download_url"], self.output / asset["name"], asset["size"]))
        self.native.assert_called_once_with(self.output / ARCHIVE, VERSION, "arm64")
        report = json.loads((self.output / "provenance.json").read_text())
        self.assertEqual(report["status"], "verified")
        self.assertEqual(report["mode"], "read_only_recovery")
        self.assertEqual(report["source_sha"], SOURCE)
        self.assertFalse(report["authentication_sent"])
        self.assertTrue(all(asset["matches_packaged_sha256"] for asset in report["assets"]))
        self.assertEqual(report["assets"][0]["sha256"], self.digest)

    def test_source_mismatch_stops_before_network(self):
        self.source.side_effect = ReleaseError("version does not match source")
        with self.assertRaises(ReleaseError):
            self.run_verification()
        self.public.assert_not_called()
        self.download.assert_not_called()

    def test_tag_mismatch_stops_before_release_lookup(self):
        self.ref["object"]["sha"] = "b" * 40
        with self.assertRaisesRegex(ReleaseError, "exact vetted commit"):
            self.run_verification()
        self.assertEqual(self.public.call_count, 1)
        self.download.assert_not_called()

    def test_release_identity_mismatches_stop_before_download(self):
        original = deepcopy(self.release)
        for key, value in [("draft", True), ("target_commitish", "b" * 40),
                           ("tag_name", "v0.4.1"), ("published_at", None),
                           ("html_url", "https://github.com/other/repo/releases/tag/v0.4.2")]:
            self.release = deepcopy(original)
            self.release[key] = value
            with self.subTest(key=key), self.assertRaisesRegex(ReleaseError, "identity"):
                self.run_verification()
        self.download.assert_not_called()

    def test_asset_count_and_names_are_strict(self):
        self.release["assets"].append(deepcopy(self.release["assets"][0]))
        with self.assertRaisesRegex(ReleaseError, "exactly the two pinned"):
            self.run_verification()
        self.download.assert_not_called()

    def test_metadata_mismatch_fails_before_download(self):
        original = deepcopy(self.release)
        for key, value in [("size", 999), ("state", "starter"), ("digest", "sha256:" + "0" * 64)]:
            self.release = deepcopy(original)
            self.release["assets"][0][key] = value
            with self.subTest(key=key), self.assertRaisesRegex(ReleaseError, "metadata differs"):
                self.run_verification()
        self.download.assert_not_called()
        self.native.assert_not_called()
        self.assertEqual(json.loads((self.output / "provenance.json").read_text())["status"], "failed_verification")

    def test_draft_asset_url_is_still_rejected(self):
        self.release["assets"][0]["browser_download_url"] = self.release["assets"][0]["browser_download_url"].replace("/v0.4.2/", "/untagged-draft/")
        with self.assertRaisesRegex(ReleaseError, "public asset URL"):
            self.run_verification()
        self.download.assert_not_called()

    def test_downloaded_bytes_must_match_independently_pinned_original_hash(self):
        self.files[ARCHIVE] = b"different ZIP bytes"
        with self.assertRaisesRegex(ReleaseError, "original packaged SHA-256"):
            self.run_verification()
        self.assertEqual(self.download.call_count, 1)
        self.native.assert_not_called()

    def test_sidecar_must_match_downloaded_zip_even_when_its_own_pin_matches(self):
        self.request, self.ref, self.release, self.files, self.digest = fixtures(
            sidecar=("0" * 64 + f"  {ARCHIVE}\n").encode())
        with self.assertRaisesRegex(ReleaseError, "checksum sidecar"):
            self.run_verification()
        self.native.assert_called_once()

    def test_native_failure_is_recorded(self):
        self.native.side_effect = ReleaseError("signature mismatch")
        with self.assertRaisesRegex(ReleaseError, "signature mismatch"):
            self.run_verification()
        report = json.loads((self.output / "provenance.json").read_text())
        self.assertEqual(report["status"], "failed_verification")
        self.assertEqual(report["error"], "signature mismatch")

    def test_invalid_repository_stops_without_network(self):
        with self.assertRaisesRegex(ReleaseError, "invalid repository"):
            verify_existing(self.request, "owner/repo/../../evil", self.output)
        self.public.assert_not_called()


if __name__ == "__main__":
    unittest.main()
