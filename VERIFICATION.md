# Verification — initial release

## Completed

- 11 core checks: SHA-256 reference vectors, numeric versions, path rejection, base64 bytes, catalog and complete payload integrity, malformed/corrupt catalog handling, XML identity matching, HTTP response parsing.
- 19 mocked MA runtime scenarios: startup scan ordering, offline installs, all update modes, multiple target drives, pool slots, downgrade protection, drive removal, checksum failures, backup failures, import failures, verification of the resulting version, changed local files, destination collisions, MA version checks, incomplete local packages, newest selected source and preserved drive folders.
- ZIP integrity, every release manifest and per-file checksum, original package copy fidelity, 12 website pages and their relative links, embedded updater image dimensions, RGB format and 1024-byte XML image blocks.
- Lua syntax checks for source modules and the bundled updater.
- 12 updater UI scenarios: all scripted callbacks, initial scan before window creation, selection, three modes, drive and DataPool choices, review/cancel, error handling, busy cancellation, display movement and close.
- 21 Hippo Remote v1.3.0 scenarios: every scripted callback, three OSC trigger/reset commands, session and type filtering, grey device faces, confirmed actions, retained display-move selection, settings compatibility, target changes, partial send/reset failures and busy guards.
- Browser visual review of the static site and Hippo Remote download page.

## Not yet verified

- Public GitHub endpoints and Pages build: publication verification in progress.
- Native MA3 2.5.1 object import/export, touch controls, screen movement and platform HTTPS clients: no console is connected.


## First console check

Use a copy of the show. Launch with two drives attached and confirm the drive scan completes before the main window appears. Select one plugin and Download Only to one USB drive, then Install Only into an empty test DataPool. Verify its version, pool image and operation. Next update an existing test slot and check the exported backup. Disconnect internet and confirm local copies remain available. Remove a selected drive before confirming an update and confirm the updater reports that the drive changed.
