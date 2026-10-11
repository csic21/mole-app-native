#!/usr/bin/env python3
"""Fail closed on existing releases or tag races; never replace a tag or asset."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
from urllib.error import HTTPError
from urllib.parse import quote
from urllib.request import Request, urlopen

from release_request import ReleaseError, validate_sha, validate_version


class GitHub:
    def __init__(self, repository, token):
        if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository):
            raise ReleaseError("invalid repository")
        self.repository = repository
        self.base = "https://api.github.com/repos/" + repository
        self.token = token

    def api(self, path, method="GET", data=None, optional=False):
        request = Request(self.base + path,
                          data=None if data is None else json.dumps(data).encode(),
                          method=method, headers={"Authorization": "Bearer " + self.token,
                          "Accept": "application/vnd.github+json", "Content-Type": "application/json",
                          "X-GitHub-Api-Version": "2022-11-28"})
        try:
            with urlopen(request, timeout=60) as response:
                return json.load(response)
        except HTTPError as error:
            if optional and error.code == 404:
                return None
            raise ReleaseError(f"GitHub {method} {path} failed (HTTP {error.code}); no overwrite attempted") from error


    def upload(self, release_id, path, content_type):
        if type(release_id) is not int or release_id <= 0:
            raise ReleaseError("invalid new release id")
        url = (f"https://uploads.github.com/repos/{self.repository}/releases/{release_id}/assets"
               f"?name={quote(path.name, safe='')}")
        request = Request(url, data=path.read_bytes(), method="POST", headers={
            "Authorization": "Bearer " + self.token, "Content-Type": content_type,
            "Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"})
        try:
            with urlopen(request, timeout=300) as response:
                return json.load(response)
        except HTTPError as error:
            raise ReleaseError(f"asset upload failed (HTTP {error.code}); draft retained, no overwrite attempted") from error


def ensure_no_release(api, tag):
    if api.api("/releases/tags/" + tag, optional=True) is not None:
        raise ReleaseError("release already exists; refusing to overwrite it")
    # Listing with the write token also covers drafts, including partial prior runs.
    for page in range(1, 101):
        releases = api.api(f"/releases?per_page=100&page={page}")
        if any(release.get("tag_name") == tag for release in releases):
            raise ReleaseError("release already exists (including draft); refusing to overwrite it")
        if len(releases) < 100:
            return
    raise ReleaseError("could not exhaust release history; refusing to publish")


def tag_commit(api, tag):
    ref = api.api("/git/ref/tags/" + tag, optional=True)
    if ref is None:
        return None
    obj = ref["object"]
    # Accept lightweight and annotated tags, but fail closed on malformed cycles.
    for _ in range(8):
        if obj.get("type") == "commit":
            return validate_sha(obj["sha"])
        if obj.get("type") != "tag":
            break
        obj = api.api("/git/tags/" + validate_sha(obj["sha"]))["object"]
    raise ReleaseError("tag does not resolve to a commit")


def preflight(api, version, source, mode):
    validate_version(version)
    validate_sha(source)
    if mode not in {"request", "manual", "tag"}:
        raise ReleaseError("unknown release mode")
    tag = "v" + version
    ensure_no_release(api, tag)
    existing = tag_commit(api, tag)
    if mode == "tag":
        if existing != source:
            raise ReleaseError("triggering tag no longer matches the vetted source")
    elif existing is not None:
        raise ReleaseError("tag already exists; refusing to reuse or overwrite it")


def create_release(api, version, source, mode, notes):
    preflight(api, version, source, mode)
    tag = "v" + version
    if mode != "tag":
        # GitHub's create-ref API is atomic: an existing/racing ref returns an error.
        ref = api.api("/git/refs", method="POST", data={"ref": "refs/tags/" + tag, "sha": source})
        if ref.get("ref") != "refs/tags/" + tag or ref.get("object", {}).get("sha") != source:
            raise ReleaseError("created tag response did not match the vetted source")
    if tag_commit(api, tag) != source:
        raise ReleaseError("tag changed before release creation")
    generated = api.api("/releases/generate-notes", method="POST",
                        data={"tag_name": tag, "target_commitish": source})
    return api.api("/releases", method="POST", data={
        "tag_name": tag, "target_commitish": source, "name": tag, "draft": True,
        "prerelease": "-" in version.split("+", 1)[0],
        "body": notes + "\n\n" + generated.get("body", "")})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--dist", default="dist")
    parser.add_argument("--preflight", action="store_true")
    args = parser.parse_args()
    manifest = json.loads(Path(args.manifest).read_text())
    version, source, mode = manifest["version"], manifest["source_sha"], manifest["mode"]
    repository = os.environ["GITHUB_REPOSITORY"]
    api = GitHub(repository, os.environ["GH_TOKEN"])
    if args.preflight:
        preflight(api, version, source, mode)
        return
    dist = Path(args.dist).resolve()
    archive = dist / f"Qili-{validate_version(version)}.zip"
    checksum = archive.with_name(archive.name + ".sha256")
    expected = f"{hashlib.sha256(archive.read_bytes()).hexdigest()}  {archive.name}\n"
    if checksum.read_text() != expected:
        raise ReleaseError("ZIP changed after artifact verification")
    release = create_release(api, version, source, mode, (dist / "release-notes.md").read_text())
    if release.get("tag_name") != "v" + version or release.get("draft") is not True:
        raise ReleaseError("new draft response did not match the intended release")
    # Upload by our newly created release id, never by an ambiguous tag lookup.
    # POST refuses duplicate names; there is deliberately no delete/overwrite path.
    api.upload(release["id"], archive, "application/zip")
    api.upload(release["id"], checksum, "text/plain")
    assets = api.api("/releases/" + str(release["id"]) + "/assets")
    expected_sizes = {archive.name: archive.stat().st_size, checksum.name: checksum.stat().st_size}
    if ({item["name"]: item["size"] for item in assets} != expected_sizes
            or any(item.get("state") != "uploaded" for item in assets)):
        raise ReleaseError("uploaded release assets do not match the verified package")
    if tag_commit(api, "v" + version) != source:
        raise ReleaseError("tag changed during upload; leaving the release as a draft")
    published = api.api("/releases/" + str(release["id"]), method="PATCH", data={"draft": False})
    if published.get("draft") or published.get("tag_name") != "v" + version:
        raise ReleaseError("could not verify release publication")
    # Draft asset URLs can contain an unpublished tag placeholder. Refresh after
    # publication so the public verifier receives GitHub's final canonical URLs.
    assets = api.api("/releases/" + str(release["id"]) + "/assets")
    if (len(assets) != len(expected_sizes)
            or {item["name"]: item["size"] for item in assets} != expected_sizes
            or any(item.get("state") != "uploaded" for item in assets)):
        raise ReleaseError("published release assets changed; release was left unchanged")
    (dist / "release-publication.json").write_text(json.dumps({
        "release_id": release["id"], "html_url": published["html_url"],
        "tag": "v" + version, "version": version, "source_sha": source,
        "repository": repository,
        "assets": [{key: asset[key] for key in ["name", "size", "browser_download_url"]}
                   for asset in assets],
    }, indent=2) + "\n")
    print(published["html_url"])


if __name__ == "__main__":
    main()
