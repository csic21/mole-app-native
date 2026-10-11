import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from release_request import ReleaseError, parse_request, resolve, validate_sha, validate_version, verify_source
from publish_release import create_release, preflight, tag_commit
from verify_release_artifact import inspect_zip

SHA = "a" * 40
OTHER = "b" * 40


class RequestValidationTests(unittest.TestCase):
    def test_valid_semver(self):
        for value in ["0.4.2", "1.2.3-rc.1", "1.2.3+build.01", "1.2.3-rc.2+sha.abc"]:
            self.assertEqual(validate_version(value), value)

    def test_invalid_semver(self):
        for value in [None, 42, "v0.4.2", "01.2.3", "1.2", "1.2.3-01", "1.2.3-rc.01",
                      "1.2.3\n", "1.2.3;echo hacked", "$(touch /tmp/oops)", "1.2.3/evil"]:
            with self.subTest(value=value), self.assertRaises(ReleaseError):
                validate_version(value)

    def test_full_canonical_sha_only(self):
        self.assertEqual(validate_sha(SHA), SHA)
        for value in ["main", "HEAD", "abc1234", "a" * 39, "a" * 41, "A" * 40, "g" * 40, None]:
            with self.subTest(value=value), self.assertRaises(ReleaseError):
                validate_sha(value)

    def test_request_schema(self):
        self.assertEqual(parse_request(json.dumps({"version": "0.4.2", "source_sha": SHA})), ("0.4.2", SHA))
        for raw in ['{}', '[]', '{"version":"0.4.2"}', '{"version":"0.4.2","version":"0.4.3","source_sha":"' + SHA + '"}',
                    json.dumps({"version": "0.4.2", "source_sha": SHA, "extra": True}), "{" * 4097, "not json"]:
            with self.subTest(raw=raw[:100]), self.assertRaises(ReleaseError):
                parse_request(raw)

    @patch("release_request.verify_source")
    @patch("release_request.git")
    def test_request_uses_declared_source_not_request_commit(self, git, verify):
        git.return_value = json.dumps({"version": "0.4.2", "source_sha": SHA})
        result = resolve("push", "refs/heads/main", OTHER)
        self.assertEqual(result["source_sha"], SHA)
        self.assertEqual(result["mode"], "request")
        git.assert_called_once_with("show", OTHER + ":.github/release-request.json")
        verify.assert_called_once_with("0.4.2", SHA)

    @patch("release_request.verify_source")
    def test_manual_requires_exact_source_on_main(self, verify):
        self.assertEqual(resolve("workflow_dispatch", "refs/heads/main", OTHER, "0.4.2", SHA)["source_sha"], SHA)
        with self.assertRaises(ReleaseError):
            resolve("workflow_dispatch", "refs/heads/topic", OTHER, "0.4.2", SHA)
        with self.assertRaises(ReleaseError):
            resolve("workflow_dispatch", "refs/heads/main", OTHER, "0.4.2", "main")

    @patch("release_request.verify_source")
    @patch("release_request.git", return_value=SHA)
    def test_tag_must_match_triggering_source(self, git, verify):
        self.assertEqual(resolve("push", "refs/tags/v0.4.2", SHA)["mode"], "tag")
        with self.assertRaises(ReleaseError):
            resolve("push", "refs/tags/v0.4.2", OTHER)


class RepositoryValidationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.previous = Path.cwd()
        os.chdir(self.temporary.name)
        self.git("init", "-q", "-b", "main")
        self.git("config", "user.name", "Release Test")
        self.git("config", "user.email", "release-test@example.invalid")
        path = Path("Sources/MoleApp/AppVersion.swift")
        path.parent.mkdir(parents=True)
        path.write_text('enum AppVersion {\n    static let development = "0.4.2"\n}\n')
        self.git("add", ".")
        self.git("commit", "-qm", "fixture")
        self.source = self.git("rev-parse", "HEAD")
        self.git("update-ref", "refs/remotes/origin/main", self.source)

    def tearDown(self):
        os.chdir(self.previous)
        self.temporary.cleanup()

    def git(self, *args):
        return subprocess.check_output(["git", *args], text=True).strip()

    def test_source_version_and_reachability(self):
        verify_source("0.4.2", self.source)
        with self.assertRaisesRegex(ReleaseError, "AppVersion"):
            verify_source("0.4.3", self.source)
        Path("unreviewed").write_text("not on main")
        self.git("add", ".")
        self.git("commit", "-qm", "unreviewed")
        with self.assertRaisesRegex(ReleaseError, "reachable"):
            verify_source("0.4.2", self.git("rev-parse", "HEAD"))

    def test_reject_annotated_tag_object_as_source(self):
        self.git("tag", "-am", "annotated", "v0.4.2")
        with self.assertRaisesRegex(ReleaseError, "commit, not a tag"):
            verify_source("0.4.2", self.git("rev-parse", "v0.4.2"))


class FakeGitHub:
    def __init__(self, tag=None, release=None, race=False):
        self.tag, self.release, self.race = tag, release, race
        self.calls = []

    def api(self, path, method="GET", data=None, optional=False):
        self.calls.append((method, path, data))
        if path.startswith("/releases/tags/"):
            return self.release
        if path.startswith("/releases?"):
            return []
        if path.startswith("/git/ref/tags/"):
            return None if self.tag is None else {"object": {"type": "commit", "sha": self.tag}}
        if path == "/git/refs":
            if self.race:
                raise ReleaseError("GitHub POST /git/refs failed (HTTP 422)")
            self.tag = data["sha"]
            return {"ref": data["ref"], "object": {"sha": self.tag}}
        if path == "/releases/generate-notes":
            return {"body": "Generated changelog"}
        if path == "/releases":
            self.release = {"id": 1, **data}
            return self.release
        raise AssertionError((method, path, data))


class PublicationSafetyTests(unittest.TestCase):
    def test_request_creates_only_exact_ref_then_draft(self):
        api = FakeGitHub()
        release = create_release(api, "0.4.2", SHA, "request", "Checksum notes")
        self.assertEqual(api.tag, SHA)
        self.assertTrue(release["draft"])
        self.assertEqual(release["target_commitish"], SHA)
        self.assertIn(("POST", "/git/refs", {"ref": "refs/tags/v0.4.2", "sha": SHA}), api.calls)
        self.assertIn("Checksum notes", release["body"])

    def test_existing_release_always_fails_before_writes(self):
        api = FakeGitHub(tag=SHA, release={"id": 9})
        for mode in ["request", "manual", "tag"]:
            with self.subTest(mode=mode), self.assertRaisesRegex(ReleaseError, "release already exists"):
                preflight(api, "0.4.2", SHA, mode)
        self.assertTrue(all(call[0] == "GET" for call in api.calls))

    def test_existing_draft_is_rejected(self):
        class DraftGitHub(FakeGitHub):
            def api(self, path, **kwargs):
                if path.startswith("/releases?"):
                    return [{"tag_name": "v0.4.2", "draft": True}]
                return super().api(path, **kwargs)
        with self.assertRaisesRegex(ReleaseError, "including draft"):
            create_release(DraftGitHub(), "0.4.2", SHA, "request", "notes")

    def test_request_and_manual_refuse_any_existing_tag(self):
        for tag in [SHA, OTHER]:
            for mode in ["request", "manual"]:
                api = FakeGitHub(tag=tag)
                with self.subTest(tag=tag, mode=mode), self.assertRaisesRegex(ReleaseError, "tag already exists"):
                    create_release(api, "0.4.2", SHA, mode, "notes")
                self.assertTrue(all(call[0] == "GET" for call in api.calls))

    def test_atomic_ref_race_never_creates_release(self):
        api = FakeGitHub(race=True)
        with self.assertRaisesRegex(ReleaseError, "422"):
            create_release(api, "0.4.2", SHA, "request", "notes")
        self.assertFalse(any(path == "/releases" for _, path, _ in api.calls))

    def test_direct_tag_must_match_source_and_is_never_recreated(self):
        for tag in [None, OTHER]:
            with self.subTest(tag=tag), self.assertRaisesRegex(ReleaseError, "no longer matches"):
                create_release(FakeGitHub(tag=tag), "0.4.2", SHA, "tag", "notes")
        api = FakeGitHub(tag=SHA)
        create_release(api, "0.4.2", SHA, "tag", "notes")
        self.assertFalse(any(path == "/git/refs" for _, path, _ in api.calls))

    def test_annotated_tag_resolution(self):
        class Annotated:
            def api(self, path, **kwargs):
                return {"object": {"type": "tag", "sha": OTHER}} if path.startswith("/git/ref/") else {"object": {"type": "commit", "sha": SHA}}
        self.assertEqual(tag_commit(Annotated(), "v0.4.2"), SHA)


class ArtifactValidationTests(unittest.TestCase):
    def make_zip(self, path, version="0.4.2", logo="QiliLogo.png", extra=None):
        info = {"CFBundleShortVersionString": version, "CFBundleVersion": version,
                "CFBundleIdentifier": "com.csic21.moleapp", "CFBundleName": "Qili",
                "CFBundleExecutable": "MoleApp", "CFBundlePackageType": "APPL", "LSMinimumSystemVersion": "14.0"}
        with zipfile.ZipFile(path, "w") as archive:
            prefix = "Qili.app/Contents/"
            archive.writestr(prefix + "Info.plist", plistlib.dumps(info))
            binary = zipfile.ZipInfo(prefix + "MacOS/MoleApp")
            binary.external_attr = 0o100755 << 16
            archive.writestr(binary, b"fixture-only executable")
            for item in ["Resources/AppIcon.icns", "Resources/MoleApp_MoleApp.bundle/" + logo,
                         "Resources/MoleApp_MoleApp.bundle/" + logo.replace("QiliLogo.png", "AppIcon.icns"),
                         "_CodeSignature/CodeResources"]:
                archive.writestr(prefix + item, b"fixture")
            if extra:
                archive.writestr(extra, b"unsafe")

    def test_bundle_resources_in_both_swiftpm_layouts(self):
        with tempfile.TemporaryDirectory() as temporary:
            archive = Path(temporary) / "Qili.zip"
            for logo in ["QiliLogo.png", "Contents/Resources/QiliLogo.png"]:
                self.make_zip(archive, logo=logo)
                inspect_zip(archive, "0.4.2")

    def test_version_and_unsafe_paths_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            archive = Path(temporary) / "Qili.zip"
            self.make_zip(archive, version="0.4.1")
            with self.assertRaisesRegex(ReleaseError, "identity/version"):
                inspect_zip(archive, "0.4.2")
            self.make_zip(archive, extra="Qili.app/../../escape")
            with self.assertRaisesRegex(ReleaseError, "unsafe"):
                inspect_zip(archive, "0.4.2")


if __name__ == "__main__":
    unittest.main()
