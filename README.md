# WadeLightingTools

**Current updater: 1.1.8.** Automated showfile imports are paused after a reported console restart affecting every attempted plugin. Drive downloads remain available. The native crash cause is unconfirmed; earlier mock import results are not evidence of native stability.

grandMA3 plugins by Aaron Wade, with a static GitHub Pages catalog and an independent batch updater targeting MA3 2.5.1.

## Project layout

- `docs/`: website and a subpage named for each plugin.
- `releases/`: original latest revision ZIPs, plus WLT Plugin Updator.
- `packages/`: immutable unpacked release files and SHA-256 manifests.
- `catalog.tsv`: machine-readable internet update catalog.
- `registry.json`: release metadata used to build the site.
- `updater/src/`: editable Lua sources bundled into the installable updater.
- `tests/`: mocked MA environment and core integrity tests.

## Website and downloads

- Repository: https://github.com/tmoose95/WadeLightingTools
- Website: https://tmoose95.github.io/WadeLightingTools/
- Internet catalog: https://raw.githubusercontent.com/tmoose95/WadeLightingTools/main/catalog.tsv

GitHub Pages serves `main` / `docs`. Each approved plugin has its own page and original versioned ZIP download. Hippo Remote v1.3.0 uses Server Command's Hippo-only interface. The first catalog contains the 11 plugins approved by Aaron Wade.

## Publishing setup

For a fresh checkout, sign in as `tmoose95` with `gh auth login`, then run `python3 tools/publish.py`. The script validates the repository, creates the public repository if needed, pushes without force, and configures Pages to publish from `main` / `docs`. A failed push is not force-retried.

## Publish a future plugin revision

1. Put the complete, versioned ZIP on your computer. Its plugin folder must contain one XML and every referenced Lua file.
2. Run `python3 tools/build_catalog.py --add /path/to/Plugin_vX.Y.Z.zip`.
3. Run `python3 tools/validate.py`, review the changes, and push them to `main`.

The script reads the actual version/name/author from the XML, copies the original ZIP unchanged, generates checksums and the update catalog, and refreshes the plugin page. Existing release filenames and payload versions are immutable. Use a new version when files change. Historical ZIPs remain available in GitHub; the website points to the latest registered version.

The updater's internet catalog is served from raw.githubusercontent.com, so online update checks do not depend on a successful Pages build. The repository must be public for token-free console downloads.

## Updater behavior

The updater scans current internal and connected USB plugin libraries and compares showfile, drive and online versions. With no USB attached, only the internal library is scanned. Red/green version cells, QR pages, screen movement, download progress and HTTPS/checksum verification remain available.

In 1.1.8, the **Showfile** tab keeps **Import from Drive** and **Import from Internet** visible with a pause notice. They cannot execute until native testing resolves the reported restart. The **Drives** tab offers **Download from Internet**. Each tab has its own queue; downloads do not become Showfile actions. Internal packages are visible without a USB drive.

The unverified native System Monitor widget has been removed from the progress popup. Three ordinary labels now show the updater's last messages. The supplied crash log does not confirm that the import step was reached or identify the crash cause. No native crash fix is claimed. The packaged Lua still contains no native `:Import` call or self-replacement LuaFile continuation.

Close v1.1.5 before installing the containment revision through MA3's normal plugin editor when programming can be interrupted. Do not use the affected updater import action or repeat it to obtain diagnostics. Existing logs can be collected with `CopyCrashLog` and `DumpLog`.

## Testing scope

The repository includes source, manifest, page-link and simulated MA runtime checks. No physical grandMA3 console is connected to the development environment. Native import/export behavior, platform HTTPS availability, touch scrolling, actual screen movement and removed-drive behavior still require verification on the target console. Other catalog plugins retain their supplied release packages; catalog inclusion is not a new MA3 compatibility certification.

See `VERIFICATION.md` for the exact checks performed and the first console check.

Independent implementation. No MATools code, licensing system, or branding is included. Supplied plugin release ownership and attribution remain with their existing authors. This repository does not grant new licensing rights for those packages.

### Lua validation requirement

MA3 2.5 uses Lua 5.5. Set `WLT_LUA55` to a Lua 5.5 executable, with LuaFileSystem available, before running `python3 tools/validate.py`. The check compiles and launches the exact bundled updater against mocked MA objects, including startup drive scanning. Older Lua interpreters are rejected because they miss the loop-variable compile error corrected in 1.0.2.

The updater is named **WLT Plugin Updator**, including its folder and filenames. Its catalog ID remains stable so existing installations can be recognized.

Version 1.0.3 also corrects the startup GetPath parameter error. The bundled startup checks now validate MA path arguments with no PathType.UserPlugins enum and exercise both internal and removable-drive library resolution.

Version 1.1.0 adds the table workflow above and corrects the overbroad connectivity label. Console OpenSSL does not require a timeout utility, and a Mozilla CA bundle travels inside the Lua component. Settings > Connection Details shows the actual HTTPS error. The certificate bundle source and attribution are in `updater/ca/`. `tests/transport.py` verifies real local TLS success, certificate rejection, hostname rejection and HTTP error handling; `tests/transport_live.lua` is an optional read-only live GitHub smoke test.

## Plugin Updator 1.1.1

Each plugin directory and XML is read once per scan. The online catalog reuses that metadata, reading only newly listed folders; SHA-256 checks are deferred to reviewed local sources. After updates, only affected package records and in-memory showfile metadata refresh. Shows, media, backups and unrelated folders are never traversed.

Imports use the documented object `Import(directory, filename)` on the exact target handle, bypassing Library keyword/cache resolution. New installs create only the planned empty slot. A successful result requires the requested metadata and matching exported Lua component contents; the existing plugin backup remains available after any failure. The native MA engine is not available in this Linux environment, so automated mock checks are not a claim of console verification.

## Plugin Updator 1.1.2

Both Import Online and Import from Drive now prepare a self-contained temporary XML containing the Lua components. This avoids the missing `shared/resource/lib_plugins/ServerCommand/Server_Command.lua` lookup reported by the console. Download to Drives continues to save original release files. The import copy retains metadata and image dependencies, clears external component associations, and preserves component order. Numeric version comparison accepts equivalent three/four-part versions; exported code still has to match before success is reported.

The revised tests model the resource lookup failure that the previous mock missed, and independently decode every catalog package's staged XML with Python. These checks do not execute the MA engine.

## Plugin Updator 1.1.3

Includes the 1.1.2 import corrections. In More Plugins, each uninstalled plugin has a QR Code button opening a large native MA QRCode widget with its own WadeLightingTools page URL. The popup works offline, opens on the current display, shows the exact URL, and uses no image pool slots. The 54-pixel rows and scrollable table remain compact.

## Plugin Updator 1.1.4

Updates display a progress bar and percentage driven by transfer bytes and completed backup, drive-write and import-verification steps. The compact native SystemMonitorWindow shows recent engine output. If that native class is unavailable, a clearly labelled fallback shows the last three updater messages sent to System Monitor. Progress reaches 100% only after all reviewed actions have passed verification.

An existing exported Lua component that is zero bytes no longer prevents recovery indefinitely. The updater preserves the damaged export and an INCOMPLETE-BACKUP.txt notice, validates and compiles the replacement, and asks whether to repair the exact affected slots. Cancel leaves the show slots unchanged. A failed/missing backup or invalid replacement still stops the update.

## Plugin Updator 1.1.5

Fixes the progress-window crash caused by subtracting from a text-valued MA BaseInput width. Popup dimensions now use local numbers; unexpected setup errors release the busy state.

Every plugin, including the updater, offers **Update Drives + Showfile**, **Download to Drives**, and **Import from Drive**. The first action downloads online files to the chosen drives and imports into reviewed DataPool slots. The offline action uses the selected local package.

Self replacement is deferred until the other plugins finish. The old UI closes and a locally generated LuaFile continuation checks the prepared XML checksum and target slots, imports, and verifies exported Lua before reporting success. No extra helper plugin slot is created. Reopen the updater after its completion message.

Install 1.1.5 manually once when upgrading from 1.1.4, whose progress popup fails before the update starts. Automated regression tests cover these paths; native MA3/onPC 2.5.1 execution is not claimed.

## Plugin Updator 1.1.6

Containment after the user reported that importing any plugin from a drive through v1.1.5 restarted the console. Both automated import modes and self replacement are blocked. Downloads, local discovery, version comparison and existing drive backups remain available. Root-cause investigation and the intended combined drive/showfile workflow remain pending native evidence. The following earlier revision notes describe historical behavior, not current support.


## Plugin Updator 1.1.7

Separate Showfile and Drives actions and queues; retain visibly paused import choices. The Drives tab includes selected internal packages. Removed the embedded native System Monitor window and retained three updater activity labels with the progress bar. Crash cause and native import validation remain unresolved. Earlier release notes describe historical behavior.


## Plugin Updator 1.1.8 — free updater, existing-drive updates

WLT Plugin Updator remains free to download and open. Other plugins can be downloaded through it only when a complete package exists on a currently connected scanned drive, including internal storage. A showfile-only copy does not qualify. The source drive need not be selected as a destination. Planning and whole-batch execution recheck drive availability, XML identity and readable, nonempty Lua before network downloads. UI/bulk actions also apply the rule.

Public product pages keep descriptions and the updater link, with direct package-download buttons only on the free updater page. Existing catalog/package URLs remain operational. **This is not a paywall or license enforcement:** the repository and existing file URLs are still public. Future registered-drive licensing requires a validated drive identity and entitlement service; do not market the current releases as purchase-protected. The import pause and native-testing limitations above still apply.
