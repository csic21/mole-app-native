#!/usr/bin/env python3
"""Resolve a release to one immutable, version-matched commit on main."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess


class ReleaseError(ValueError):
    pass


def validate_version(value):
    if not isinstance(value, str) or not re.fullmatch(
        r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"
        r"(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?"
        r"(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?", value
    ):
        raise ReleaseError("version must be strict SemVer without a v prefix")
    prerelease = value.split("+", 1)[0].partition("-")[2]
    if any(part.isdigit() and len(part) > 1 and part.startswith("0")
           for part in prerelease.split(".")):
        raise ReleaseError("numeric prerelease identifiers cannot have leading zeroes")
    return value


def validate_sha(value):
    if not isinstance(value, str) or not re.fullmatch(r"[0-9a-f]{40}", value):
        raise ReleaseError("source_sha must be a full 40-character lowercase commit SHA")
    return value


def _unique_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ReleaseError(f"duplicate request key: {key}")
        result[key] = value
    return result


def parse_request(raw):
    if len(raw.encode("utf-8")) > 4096:
        raise ReleaseError("release request exceeds 4096 bytes")
    try:
        data = json.loads(raw, object_pairs_hook=_unique_keys)
    except json.JSONDecodeError as error:
        raise ReleaseError("invalid release request JSON") from error
    if not isinstance(data, dict) or set(data) != {"version", "source_sha"}:
        raise ReleaseError("request must contain exactly version and source_sha")
    return validate_version(data["version"]), validate_sha(data["source_sha"])


def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()


def verify_source(version, source_sha):
    validate_version(version)
    validate_sha(source_sha)
    if git("rev-parse", "--verify", source_sha + "^{commit}") != source_sha:
        raise ReleaseError("source_sha must identify a commit, not a tag object")
    try:
        subprocess.run(["git", "merge-base", "--is-ancestor", source_sha,
                        "refs/remotes/origin/main"], check=True)
    except subprocess.CalledProcessError as error:
        raise ReleaseError("release source must be reachable from origin/main") from error
    content = git("show", source_sha + ":Sources/MoleApp/AppVersion.swift")
    matches = re.findall(r'^\s*static let development\s*=\s*"([^"\n]+)"\s*$',
                         content, re.MULTILINE)
    if matches != [version]:
        raise ReleaseError("requested version does not match AppVersion.swift at source_sha")
    subprocess.run(["git", "check-ref-format", "refs/tags/v" + version], check=True)


def resolve(event_name, event_ref, event_sha, version="", source_sha=""):
    validate_sha(event_sha)
    if event_name == "push" and event_ref == "refs/heads/main":
        version, source_sha = parse_request(git("show", event_sha + ":.github/release-request.json"))
        mode = "request"
    elif event_name == "push" and event_ref.startswith("refs/tags/v"):
        version = validate_version(event_ref.removeprefix("refs/tags/v"))
        source_sha = git("rev-parse", "--verify", event_ref + "^{commit}")
        if source_sha != event_sha:
            raise ReleaseError("tag target differs from the triggering commit")
        mode = "tag"
    elif event_name == "workflow_dispatch" and event_ref == "refs/heads/main":
        version, source_sha = validate_version(version), validate_sha(source_sha)
        mode = "manual"
    else:
        raise ReleaseError("only main requests, main manual runs, and v* tag pushes are supported")
    verify_source(version, source_sha)
    return {"version": version, "source_sha": source_sha, "tag": "v" + version, "mode": mode}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    result = resolve(os.environ["GITHUB_EVENT_NAME"], os.environ["GITHUB_REF"],
                     os.environ["GITHUB_SHA"], os.environ.get("RELEASE_VERSION", ""),
                     os.environ.get("RELEASE_SOURCE_SHA", ""))
    Path(args.output).write_text(json.dumps(result) + "\n")
    with open(os.environ["GITHUB_OUTPUT"], "a") as output:
        for key, value in result.items():
            output.write(f"{key}={value}\n")
    print(f"Validated {result['tag']} from {result['source_sha']} ({result['mode']})")


if __name__ == "__main__":
    main()
