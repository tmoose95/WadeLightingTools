# Verification — initial release

## Completed

- 11 core checks: SHA-256 reference vectors, numeric versions, path rejection, base64 bytes, catalog and complete payload integrity, malformed/corrupt catalog handling, XML identity matching, HTTP response parsing.
- 19 mocked MA runtime scenarios: startup scan ordering, offline installs, all update modes, multiple target drives, pool slots, downgrade protection, drive removal, checksum failures, backup failures, import failures, verification of the resulting version, changed local files, destination collisions, MA version checks, incomplete local packages, newest selected source and preserved drive folders.
- ZIP integrity, every release manifest and per-file checksum, original package copy fidelity, 12 website pages and their relative links, embedded updater image dimensions, RGB format and 1024-byte XML image blocks.
- Lua syntax checks for source modules and the bundled updater.
- 12 updater UI scenarios: all scripted callbacks, initial scan before window creation, selection, three modes, drive and DataPool choices, review/cancel, error handling, busy cancellation, display movement and close.
- 21 Hippo Remote v1.3.0 scenarios: every scripted callback, three OSC trigger/reset commands, session and type filtering, grey device faces, confirmed actions, retained display-move selection, settings compatibility, target changes, partial send/reset failures and busy guards.
- Browser visual review of the static site and Hippo Remote download page.
- Public GitHub Pages deployment from main/docs, all 11 approved plugin pages, and online catalog verified.
- All 119 project files matched the published GitHub blob hashes before this verification note was updated; no missing or different package files.
- Hippo Remote 1.3.0 and Wade Plugin Updater 1.0.0 downloaded through the public website and their SHA-256 hashes matched the tested release archives.

## Not yet verified

- Native MA3 2.5.1 object import/export, touch controls, screen movement and platform HTTPS clients: no console is connected.
- Hippotizer receipt and execution of OSC commands: no server is connected.


## First console check

Use a copy of the show. Launch with two drives attached and confirm the drive scan completes before the main window appears. Select one plugin and Download Only to one USB drive, then Install Only into an empty test DataPool. Verify its version, pool image and operation. Next update an existing test slot and check the exported backup. Disconnect internet and confirm local copies remain available. Remove a selected drive before confirming an update and confirm the updater reports that the drive changed.

## Plugin Updator 1.0.1

- Updated display name and title, plus the 300 x 300 RGB pool image with Wade LT centered at the top.
- New versioned image and appearance references avoid binding to the previous icon.
- Stable catalog ID and plugin folder preserved for existing installations.
- All 63 existing automated scenarios passed, including startup drive scanning.
- Package XML metadata, embedded image bytes, and release checksums validated.

## WLT Plugin Updator 1.0.2

- Reproduced the reported line 76 compile failure using official Lua 5.5.0.
- Corrected assignments to read-only loop variables in catalog parsing and Windows UTF-16 encoding.
- The earlier interpreter-only checks were insufficient for MA3 2.5; validation now requires Lua 5.5 and loads the actual Lua file extracted from the release ZIP.
- Actual bundled entry point opens after scanning two mocked drives, supports offline startup, binds its appearance and closes.
- All 63 previous scenarios passed under Lua 5.5; two additional checks cover renamed folders/legacy identity and space-encoded Unix/Windows URLs.
- Name, archive, import XML, Lua, PNG and install folder use WLT Plugin Updator. The icon now uses green circular update arrows, retaining the Wade LT header, download arrow, border and bottom label.
- Physical console testing remains outstanding.
