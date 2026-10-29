# WadeLightingTools

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

Only the current internal plugin library and connected removable USB plugin libraries are scanned before the main window opens. With no USB attached, only internal storage is scanned and selected. Older software-version and remote drives are excluded. The UI has Showfile, USB Drives and More Plugins tabs with per-plugin Import Online, Download to Drives and Import from Drive actions. Version cells are green for a live-catalog match, red for differing versions and grey for unknown/unavailable versions. A scan dialog supports Cancel & Exit. Choose All DataPools or one destination, then review every target before applying. Selected drive handles/paths and destination pool slots are rechecked before use. Downloads use certificate-validated HTTPS and per-file SHA-256/size verification. Existing drive folders and show plugins are preserved before replacement. A failed batch stops and reports the failure; completed updates are not silently rolled back.

The updater recognizes unpacked XML/Lua packages in their expected plugin folder or at the plugin-library root. ZIP-only copies must be extracted before local installation. The updater downloads the ZIP and the individual install files itself, avoiding an unzip dependency on the console. The updater's own next revision is downloaded and imported manually after closing its running window.

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
