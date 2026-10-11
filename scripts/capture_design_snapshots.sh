#!/bin/bash
# Capture real SwiftUI + AppKit views with inert fixtures. Never launches Qili.app.
# Usage: bash scripts/capture_design_snapshots.sh [output-directory]
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Native design snapshots require macOS 14+ and a graphical login session." >&2
    exit 1
fi
if ! command -v swift >/dev/null 2>&1; then
    echo "Swift is unavailable. Install/select Xcode or the Command Line Tools first." >&2
    exit 1
fi
if [[ "$(sw_vers -productVersion | cut -d. -f1)" -lt 14 ]]; then
    echo "Qili design snapshots require macOS 14 or newer." >&2
    exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="${1:-$ROOT/.build/design-snapshots}"
mkdir -p "$OUTPUT"
OUTPUT="$(cd "$OUTPUT" && pwd)"
cd "$ROOT"
RUN_ID="$(uuidgen)"

# DEBUG-only fixtures disable scans, Trash, Finder, network, login-item changes,
# maintenance commands, and system polling.
# The test hosts the production shell and all five pages, never ContentView or @main.
# The filter also runs fixture safety assertions; ordinary swift test skips PNG export.
QILI_CAPTURE_SNAPSHOTS=1 QILI_SNAPSHOT_DIRECTORY="$OUTPUT" QILI_SNAPSHOT_RUN_ID="$RUN_ID" \
    swift test --configuration debug --filter DesignSnapshotTests

if [[ ! -s "$OUTPUT/manifest.json" ]]; then
    echo "Snapshot test did not create manifest.json; no successful capture is claimed." >&2
    exit 1
fi
if [[ "$(plutil -extract runID raw -o - "$OUTPUT/manifest.json")" != "$RUN_ID" ]]; then
    echo "Manifest does not belong to this capture run; stale outputs cannot verify success." >&2
    exit 1
fi
if [[ "$(plutil -extract captureCount raw -o - "$OUTPUT/manifest.json")" != "44" ]]; then
    echo "Manifest does not contain the complete 44-capture, five-page matrix." >&2
    exit 1
fi
COUNT="$(find "$OUTPUT" -maxdepth 1 -name '*.png' -type f | wc -l | tr -d ' ')"
if [[ "$COUNT" -ne 44 ]]; then
    echo "Expected 44 PNGs, found $COUNT. Use a fresh output directory if old captures remain." >&2
    exit 1
fi
echo "Native captures: $OUTPUT ($COUNT PNGs; expected 44, including two process-table variants)"
echo "Review manifest.json for fixed dimensions, fixture states, and macOS version."
