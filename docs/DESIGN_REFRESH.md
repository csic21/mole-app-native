# Qili native design refresh

## Direction

An original, calm Mac utility: neutral charcoal surfaces, restrained green for
selection/action, readable metadata, and a clear sequence from measurement to review.
Qili's name, mascot, app icon, bundle identifier, and underlying tool capabilities stay
unchanged. The five pages share the same shell, controls, spacing and contrast palette.

Reference principles, not copied screens:

- [Things 3, Cultured Code](https://culturedcode.com/things/features/): clear hierarchy,
  grouped work and progressive detail.
- [Transmit 5, Panic](https://help.panic.com/transmit/transmit5/getting-started/): aligned
  file data and inspection close to the item being reviewed.
- [DaisyDisk's Collector](https://daisydiskapp.com/guide/4/en/DeletingFiles/): separate
  discovery, selection and action. Qili retains its own Trash-only behavior.
- [Apple sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars):
  concise navigation, familiar symbols and keyboard access.

## What changed

### Space cleanup

- Starts with an explicit “开始扫描” action instead of scanning on first appearance.
- Shows category progress and measured bytes while scanning. Category counts are not
  presented as a time estimate, and incomplete results remain visibly incomplete.
- Separates discovered size, selected size and moved size. No item is preselected.
- Expands each review item to its selectable full path and a Finder reveal action.
- Keeps selected count, size and the final confirmation outside the scroll area.
- Distinguishes complete, partial, failed and unchanged outcomes in words and symbols.
  Failures are visible without opening a disclosure.
- States clearly that files in Trash still consume disk space.

### Shared components and the other pages

- Metadata palette passes 4.5:1 for opaque card, hover and selection surfaces.
- Selection has a separate fill and outline; hover does not impersonate selection.
- Check controls have 28-point targets and an explicit keyboard focus ring. Main
  actions have 34-point targets. Native segmented controls select app subpages.
- File-map view and hidden-file preferences persist. Navigation resets scroll position
  without replacing page identity. The default is an aligned list; equal-size cards
  explicitly explain their layout and show numeric shares.
- Every distribution strip segment has a keyed size/share legend, including “other.”
  Filtering does not silently change the denominator.
- CPU/GPU history uses a fixed 0–100% range. Network rates retain labeled auto-scaling.
  Hardware context and missing metrics have clear text states.
- System startup controls are disabled as well as labeled read-only.

## Safety boundaries

The scan implementation, allowlisted roots, exclusions, physical file traversal,
Trash path/symlink revalidation, command execution and update/security mechanisms are
unchanged. The fixture hook guards scan/stop/Trash at the store entry points and exists
only in DEBUG constructors. Finder actions are inert for fixtures.

There is no empty-Trash action, app uninstall, file-map deletion, speculative metric,
or new network service. Maintenance retains the existing selections and authorization.
The test renderer never constructs the live ContentView or launches the app entry point.

## Verification

Portable checks:

```sh
python3 scripts/check_design_contrast.py
bash -n scripts/capture_design_snapshots.sh
git diff --check
```

Native checks, on macOS 14+ with Swift/Xcode selected:

```sh
swift test
swift build --configuration release
bash scripts/capture_design_snapshots.sh
```

Capture uses real production SwiftUI views inside NSHostingView/NSWindow and AppKit
bitmap capture, including native window controls. It does not use HTML mockups or
[ImageRenderer](https://developer.apple.com/documentation/swiftui/imagerenderer), which
can omit AppKit-backed controls. All data is synthetic, rooted under `/QiliPreview`,
and actions cannot perform live filesystem work. An explicit opt-in and output path
are required. Captures use fixed 1060×680 and 1220×820 window sizes, a Chinese locale,
dark Aqua, and two increased-contrast variants. Native progress indicators are paused
for captures; these are review images, not a claim of pixel consistency across OS releases.

The initial local implementation was made on a Linux executor with no Swift toolchain.
Only source/static checks ran there. Native compilation, the existing safety regressions,
new fixture/outcome tests and PNG export must pass on macOS before acceptance.
No native screenshots were produced or inspected at that stage.

The automatic capture matrix covers cleanup initial, scanning, results, selection, empty,
inaccessible, moving, complete, partial and failed states. Other pages still require
native interactive review; they are not represented by fabricated screenshots.

Manual acceptance checklist:

- Inspect all exported PNGs at both sizes, especially lowest visible text and the fixed
  selection bar. Check 1× text, long names, full paths, empty and incomplete results.
- Navigate with Command-1 through Command-5, Tab/Shift-Tab and Space. Check focus rings,
  screen-reader names, mixed category selection and disabled system startup controls.
- Stop and restart scanning; repeatedly change pages; confirm cancelled dialogs do
  nothing. Check that every cleanup path still requires explicit confirmation.
- Navigate folders in list and card modes, change hidden-file preferences, go back and
  rescan. Verify the preference survives navigation and filtering preserves the denominator.
- Review Apps, maintenance, file map and status at both window sizes. Check app search,
  update/startup subpages, native controls and unavailable hardware readings.
- Verify live operations only on disposable, explicitly authorized test fixtures. Do
  not use real cleanup, uninstall, update or maintenance operations for screenshot QA.
