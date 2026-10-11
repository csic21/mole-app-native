# Releasing Qili

The release workflow uses only the existing repository `contents: write` token.
It never force-updates tags, replaces a release, or overwrites release assets.

## Preferred: request a vetted main commit

1. Update `Sources/MoleApp/AppVersion.swift` to the desired SemVer version in the
   normal development PR. Include the release tooling changes in that PR, but
   **do not add the request file yet**.
2. Merge the PR. Wait for the **Build workflow on the exact final main SHA** to
   pass, including Swift tests, native design captures, contrast checks, and app
   packaging. Inspect the native screenshot artifact before authorizing release.
3. In a separate main commit, create or update `.github/release-request.json`:

   ```json
   {
     "version": "0.4.2",
     "source_sha": "REPLACE_WITH_THE_FULL_40_CHARACTER_VETTED_SHA"
   }
   ```

   The placeholder deliberately fails validation. Substitute the exact lowercase
   commit SHA from step 2. These are the only permitted keys; duplicate keys,
   abbreviated SHAs, branch names, and non-SemVer versions are rejected.
4. The request commit triggers Release. It reads the request from the triggering
   commit, verifies that the source is on main and its version constant matches,
   then checks out **the requested source SHA**, not the request commit or a
   floating branch. It reruns tests and contrast checks and packages that source.
5. The workflow verifies the ZIP's version, bundle identity, icon, SwiftPM logo
   resources, executable mode, Mach-O architecture, and strict ad-hoc signature.
   It writes a SHA-256 sidecar, atomically creates the version tag, uploads the ZIP
   and checksum to a new draft release, checks asset names/sizes and tag identity,
   and finally publishes the release. Notes identify the source revision,
   architecture, checksum, and ad-hoc / not-notarized status.
6. After publication the workflow downloads both assets from their public GitHub
   `browser_download_url` **without an authorization header**. It compares their
   bytes and SHA-256 against the verified originals, checks the downloaded sidecar,
   and repeats ZIP, bundle/resource, Mach-O, and codesign verification on the public
   download. Only transient availability/network failures are retried, up to six
   attempts. A mismatch fails immediately and never republishes or rolls back.
7. The `Qili-release-verification` Actions artifact contains the actual public ZIP,
   checksum, and `provenance.json` with the source revision, URLs, observed hashes,
   architecture, and verification result. Check that artifact and the published
   tag before reporting publication complete. A post-publication check failure is
   explicitly recorded as `failed_after_publication`; the release remains intact.

The request does not grant permission to skip the main CI and visual review gate.
Only a subsequent change to the request path triggers this route again; unrelated
main pushes do not publish a release. Do not commit this example as a live request.

## Other supported entry points

- A pushed `v<SemVer>` tag must resolve to the triggering commit, be reachable
  from main, and match that commit's version constant. This path validates the
  existing tag and never recreates or moves it.
- A manual Release run must select `main` and supply both a version and a full
  vetted source SHA. Floating source refs are refused. It follows the same
  no-existing-tag rule as a request.
- Runs are serialized, and a newer run does not cancel an in-progress release.

## Failure handling

Validation, test, package, and signature failures happen before tag creation.
An existing release or tag is an error, even if its version or source looks right
(except for the explicitly triggered tag-push path). A racing tag creation fails
atomically without changing the winner. Nothing deletes or force-updates refs.

A failure after creating the tag may leave that tag and/or a draft release. Do
not blindly rerun the request or delete/reuse the version: inspect the tag,
workflow logs, and draft assets first. Recovery requires an explicit maintainer
choice; the automated path intentionally refuses to overwrite partial state.

Portable validation tests (no network calls or publishing):

```sh
python3 -m unittest discover -s scripts/tests -p 'test_release_*.py'
```

Mach-O and signature checks run on macOS; portable fixture ZIPs do not establish
that a production binary is signed or runnable. Public download verification is
intended for this public repository; private releases are not treated as publicly
verified through an authenticated fallback.

### Read-only verification recovery

If publication succeeded but post-publication verification failed, leave the tag,
release, and assets intact. The separate **Verify Published Release** workflow
has only `contents: read`; its Python client uses anonymous GET requests only.
It never publishes, replaces, deletes, or rolls back a release.

A reviewed `.github/release-verification.json` pins the original package's
version, vetted source SHA, architecture, and the names, sizes, and SHA-256 hashes
of both uploaded assets. Obtain these values from the successful packaging logs
and original publication metadata, not from an unverified replacement download.
The recovery check verifies source reachability/version, the public tag and
release identity, metadata hashes, then anonymously downloads both public assets
and repeats bundle, resource, architecture, and ad-hoc signature checks. Its
artifact contains the actual downloaded bytes and read-only recovery provenance.
PR and main changes to that request, verifier, or workflow run verification;
they do not activate the publishing workflow.

For v0.4.2, the original Release run published correctly but its final check
rejected stale draft-stage asset URLs in the local publication receipt. The
publisher now refreshes asset metadata after publishing. The separate recovery
request verifies the original v0.4.2 bytes without changing their vetted source
or overwriting the public release. A later tooling-only main commit is therefore
not a replacement source revision for v0.4.2.
