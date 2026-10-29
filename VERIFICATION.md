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

## WLT Plugin Updator 1.0.3

- Reproduced the console's GetPath wrong-parameter failure in the actual 1.0.2 release with strict API mocks and no PathType.UserPlugins enum.
- Resolves the running Plugin object's user-library path type using GetPathType(plugin, 1), with the folder-name overload as fallback. Passes a nonempty string to both GetPath and GetPathOverrideFor; no guessed enum index or OS-specific library path.
- The previous mocks ignored GetPath arguments and invented the missing enum. Path API mocks now check argument types, user content type, plugin handle, noncreating lookup and consistent USB path types.
- Tests cover the derived path type, absent/empty path-type lookup, unavailable internal path, unavailable USB path, and scan-before-window ordering for both drives.
- 73 automated checks passed under Lua 5.5: 4 actual-release startup cases, 13 core, 23 runtime, 12 updater UI and 21 unchanged Hippo Remote scenarios.
- All archive/manifests, XML references, embedded 300 x 300 RGB icon and website links validated.
- The green circular-update artwork is unchanged. Physical console operation still needs verification.
- API references: https://help2.malighting.com/grandMA3/2.5/HTML/lua_objectfree_getpathtype.html and https://help2.malighting.com/grandMA3/2.5/HTML/lua_objectfree_getpathoverridefor.html; provided API_Info_Report(2).json confirms the signatures.

## WLT Plugin Updator 1.1.0

- Replaces the blanket Internet unavailable label with Online catalog unavailable and the actual client/error in Connection Details. The photos do not expose a complete error, so the precise cause on the user's station remains unconfirmed.
- Console HTTPS no longer depends on a separate timeout executable. OpenSSL receives the request through an explicitly preserved file descriptor; a POSIX watchdog bounds the request. OpenSSL 3 EOF handling still requires complete HTTP framing. Certificate chain and hostname validation remain enabled.
- Embeds the Mozilla CA bundle dated 2026-10-20 from https://curl.se/ca/cacert.pem. Its SHA-256 is recorded in updater/ca/LICENSE. Curl can retry a failed system trust check with this bundle; OpenSSL uses it directly.
- Three native MA UI tabs follow the supplied table references: Showfile, USB Drives and More Plugins. Per-row actions, version selection, Info/Help, scroll box/bar, startup scan cancellation, all/individual DataPool selection, review and move-screen callbacks are covered.
- Versions are green only when a fetched online catalog confirms a match. Older/newer versions are red; unknown/unavailable versions stay grey. All-pool plans preserve existing slots and allocate empty slots for missing plugins.
- 88 checks passed: 4 bundled-release startup, 13 core, 30 mocked runtime, 16 mocked UI, 21 unchanged Hippo Remote, and 4 actual local TLS scenarios. TLS tests establish successful OpenSSL transfer without timeout, rejection of an untrusted certificate, rejection of a trusted wrong-host certificate, and HTTP 404 rejection.
- An additional read-only live test downloaded the public GitHub catalog, verified its updater manifest, downloaded the published 1.0.3 ZIP, and matched its SHA-256 using the revised transport's curl path.
- All 11 release archives, manifests and 12 website pages validate. The green 300 x 300 RGB icon is unchanged.
- Inspected the supplied grandMA3.app Info.plist: macOS 2.4.2.2. It cannot execute in the Linux build environment. No native grandMA3/onPC 2.5.1 execution is claimed. Console HTTPS, touch gestures, display changes and native imports still need station verification.
- No other plugin release is changed or added by this revision.

## WLT Plugin Updator 1.1.1

- The supplied console log shows successful catalog/file downloads followed by Library import warnings and failed slot verification. This revision changes that import route; it does not disable verification or label the warning as an internet failure.
- Uses MA's documented object Import(directory, filename) against the exact target plugin handle. Creates only a reviewed empty slot for new installs. Requires true return status, matching identity/version, and matching exported Lua components. Existing plugin backups remain available after failures. Native dependency/image import behavior remains an on-console verification item.
- Restricts DriveCollect to current internal Drive 1 and connected Removeable/Removable USBs. OldVersion and remote entries are excluded. With no USB, internal is the only scanned/selected destination. Duplicate library paths are deduplicated.
- Lists each root/catalog plugin folder once; parses each XML once; reuses metadata after the online catalog loads, adding only previously unseen folders. Discovery performs no SHA-256 pass. A selected local source is fingerprinted at review and checked before import.
- Does not recurse into shows, media, old software, backups, downloads or unrelated directories. The running show's plugin metadata is read in memory. Batch completion refreshes affected package entries and showfile metadata without rescanning drives.
- Regression with three physical drives and one catalog plugin: six folder listings, two XML reads/parses and zero discovery hashes despite the online catalog refresh. Additional tests cover internal-only startup, OldVersion/RemoteDrive exclusion, duplicate paths, catalog growth, post-update refresh, new-slot creation, stale-code rejection and the actual MA Search 0.3.9 payload into mocked slot 19.
- 98 automated checks passed with Lua 5.5: 4 actual bundled-release startup cases, 13 core, 40 mocked runtime, 16 mocked UI, 21 unchanged Hippo Remote and 4 actual local TLS cases. All 11 archive/manifests and 12 website pages validated. The 300 x 300 green logo is unchanged.
- These tests do not run the MA engine. Native console/onPC execution and measured console scan time are not claimed. The provided macOS 2.4.2.2 app cannot run on this Linux host.
- Official API reference: https://help.malighting.com/grandMA3/2.5/HTML/lua_object_import.html . Drive enumeration reference: https://help.malighting.com/grandMA3/2.5/HTML/lua_objectfree_getpathoverridefor.html .

## WLT Plugin Updator 1.1.2

- User confirmed Download to Drives succeeds while both Import Online and Import from Drive fail at the show-pool stage. Console evidence: LoadPluginContent cannot find Server_Command.lua under shared/resource/lib_plugins/ServerCommand, followed by metadata verification failure. Existing show backups were exported successfully.
- The previous mock incorrectly loaded external Lua next to the source XML. The revised mock reproduces the native resource-lookup failure for external filenames. Running the unchanged 1.1.1 runtime against it fails with Imported metadata was not verified.
- Both import actions now stage a self-contained temporary XML with ordered Lua components in FileContent/Base64 blocks of 1024 bytes, explicit empty FileName and Installed=No. The temporary copy removes the source pool Index and retains other plugin metadata and image/dependency XML. Original drive packages are not rewritten. Native object Import still targets the exact reviewed slot.
- Actual Lua syntax is checked before import. Numeric version verification treats 2.3.15 and 2.3.15.0 as equivalent. Native export readback verifies embedded or external component code and count, rejecting stale code even if metadata changed. Metadata failures include expected and actual identity/version plus the retained backup path.
- Tests cover online replacement of two existing slots, offline drive replacement of two existing slots, all-pool destinations, new empty slots, internal-only imports, normalized versions, invalid source Lua and stale imported code. Download-only and efficient scan regressions remain passing.
- Python independently parsed and decoded staged XML for all 11 current catalog payloads, comparing original Lua bytes and image dependencies. Includes the embedded AutoColorPicker and three-component CueBeacon packages. No plugin actions were executed.
- 116 automated checks passed: 4 bundled startup, 16 core, 44 mocked runtime, 16 mocked UI, 21 unchanged Hippo Remote, 11 independent XML/payload checks and 4 local TLS checks. All 11 archive/manifests and 12 website pages validated. The green 300 x 300 RGB icon is unchanged.
- Native grandMA3/onPC 2.5.1 testing remains unavailable: the supplied app is macOS 2.4.2.2 and the build host is Linux. This is a targeted patch for console confirmation, not a claim of successful native import. Use Download to Drives, close the updater, then manually import WLT Plugin Updator_v1.1.2.xml into its existing slot.
- MA documents embedded/base64 component exports in https://help.malighting.com/grandMA3/2.5/HTML/plugins.html . The embedded representation is also present in the supplied AutoColorPicker XML.

## WLT Plugin Updator 1.1.3

- Includes the 1.1.2 import patch. Adds a QR Code button in the More Plugins table for each plugin absent from all DataPools. Each opens a large native QRCode widget containing that plugin's own https://tmoose95.github.io/WadeLightingTools/{id}/ URL, with a visible URL label and Close controls. QR rendering is local; no external QR service or image-pool import is used.
- QRCode, ShowText and associated widget properties were identified in the supplied MA app binary. The native renderer handles code generation. The QR feature is guarded by ClassExists; if unavailable the exact URL is reported and the main window remains usable. Native visual rendering and phone scanning remain unverified.
- Added five UI scenarios: uninstalled-only QR controls with compact rows, offline exact-URL/native-widget/current-display wiring, correct page URLs for all 11 catalog entries, popup cleanup and move-screen reopening, and missing-class fallback. All callbacks are exercised, including both QR Close controls.
- 121 automated checks passed: 4 bundled startup, 16 core, 44 mocked runtime, 21 mocked UI, 21 unchanged Hippo Remote, 11 independent payload/XML checks and 4 local TLS scenarios. Archive/manifests, embedded green artwork and all 12 website pages validate.
- No native console execution is claimed. User will use Download to Drives and manually import WLT Plugin Updator_v1.1.3.xml, then confirm the pool-import patch and QR display on the console.
