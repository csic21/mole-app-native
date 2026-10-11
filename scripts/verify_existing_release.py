#!/usr/bin/env python3
"""Read-only recovery verification of an already-published, hash-pinned release."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
from urllib.parse import quote
from urllib.request import Request, urlopen

from release_request import ReleaseError, _unique_keys, validate_sha, validate_version, verify_source
from verify_published_release import download_public_asset, validate_asset_url
from verify_release_artifact import verify


def parse_verification_request(raw):
    if len(raw.encode('utf-8')) > 4096:
        raise ReleaseError('verification request exceeds 4096 bytes')
    try:
        data = json.loads(raw, object_pairs_hook=_unique_keys)
    except json.JSONDecodeError as error:
        raise ReleaseError('invalid verification request JSON') from error
    if not isinstance(data, dict) or set(data) != {'version', 'source_sha', 'architecture', 'assets'}:
        raise ReleaseError('unexpected verification request keys')
    version = validate_version(data['version'])
    validate_sha(data['source_sha'])
    if data['architecture'] not in ('arm64', 'x86_64'):
        raise ReleaseError('unsupported architecture')
    names = {f'Qili-{version}.zip', f'Qili-{version}.zip.sha256'}
    assets = data['assets']
    if not isinstance(assets, list) or len(assets) != 2:
        raise ReleaseError('exactly two pinned assets are required')
    for asset in assets:
        if not isinstance(asset, dict) or set(asset) != {'name', 'size', 'sha256'}:
            raise ReleaseError('unexpected asset keys')
        if (type(asset['size']) is not int or not 0 < asset['size'] <= 128 * 1024 * 1024
                or not isinstance(asset['sha256'], str)
                or not re.fullmatch(r'[0-9a-f]{64}', asset['sha256'])
                or not isinstance(asset['name'], str)):
            raise ReleaseError('invalid pinned asset name, size, or SHA-256')
    if {asset['name'] for asset in assets} != names:
        raise ReleaseError('pinned asset names do not match the version')
    return data


def public_json(url):
    # This recovery path has no authenticated or write-capable API client.
    request = Request(url, headers={'Accept': 'application/vnd.github+json',
                                   'User-Agent': 'Qili-public-release-verification'})
    with urlopen(request, timeout=60) as response:
        return json.load(response)


def verify_existing(request, repository, output):
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repository):
        raise ReleaseError('invalid repository')
    # Validate even when called directly by another script.
    request = parse_verification_request(json.dumps(request))
    version, source = request['version'], request['source_sha']
    verify_source(version, source)
    tag = 'v' + version
    base = 'https://api.github.com/repos/' + repository
    ref = public_json(base + '/git/ref/tags/' + quote(tag, safe=''))
    if ref.get('object') != {'sha': source, 'type': 'commit',
                             'url': base + '/git/commits/' + source}:
        raise ReleaseError('published tag does not identify the exact vetted commit')
    release = public_json(base + '/releases/tags/' + quote(tag, safe=''))
    if (release.get('draft') is not False or release.get('tag_name') != tag
            or release.get('target_commitish') != source or not release.get('published_at')
            or release.get('html_url') != f'https://github.com/{repository}/releases/tag/{tag}'):
        raise ReleaseError('public release identity does not match the vetted source')
    assets = release.get('assets', [])
    if len(assets) != 2 or {a.get('name') for a in assets} != {a['name'] for a in request['assets']}:
        raise ReleaseError('public release does not contain exactly the two pinned assets')
    output.mkdir(parents=True, exist_ok=True)
    report = {'status': 'started', 'mode': 'read_only_recovery', 'source_sha': source,
              'tag': tag, 'release_url': release['html_url'], 'release_id': release['id'],
              'authentication_sent': False, 'architecture': request['architecture'],
              'started_at': datetime.now(timezone.utc).isoformat(), 'assets': []}
    try:
        for expected in request['assets']:
            asset = next(a for a in assets if a['name'] == expected['name'])
            if (asset.get('size') != expected['size'] or asset.get('state') != 'uploaded'
                    or asset.get('digest') != 'sha256:' + expected['sha256']):
                raise ReleaseError('public asset metadata differs from the original packaged asset')
            url = validate_asset_url(asset['browser_download_url'], repository, tag, expected['name'])
            downloaded = output / expected['name']
            download_public_asset(url, downloaded, expected['size'])
            digest = hashlib.sha256(downloaded.read_bytes()).hexdigest()
            if digest != expected['sha256']:
                raise ReleaseError('public asset bytes differ from the original packaged SHA-256')
            report['assets'].append({**expected, 'url': url, 'matches_packaged_sha256': True})
        name = f'Qili-{version}.zip'
        digest = verify(output / name, version, request['architecture'])
        if (output / (name + '.sha256')).read_text() != f'{digest}  {name}\n':
            raise ReleaseError('public checksum sidecar does not match the downloaded ZIP')
        report.update(status='verified', app_version=version, bundle_identifier='com.csic21.moleapp',
                      signature='ad-hoc', notarized=False)
    except Exception as error:
        report.update(status='failed_verification', error=str(error))
        raise
    finally:
        report['completed_at'] = datetime.now(timezone.utc).isoformat()
        (output / 'provenance.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'Verified existing public {tag}: exact source, original hashes, resources, architecture, and signature')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--request', default='.github/release-verification.json')
    parser.add_argument('--output', default='dist/public-verification')
    args = parser.parse_args()
    request = parse_verification_request(Path(args.request).read_text())
    verify_existing(request, os.environ['GITHUB_REPOSITORY'], Path(args.output))


if __name__ == '__main__':
    main()
