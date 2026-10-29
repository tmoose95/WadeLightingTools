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

Connected MA3 drives are scanned before the main window opens. The UI compares installed, on-drive and online versions and supports Download & Install, Download Only, and Install Only. Selected drive handles/paths and destination pool slots are rechecked before use. Downloads use certificate-validated HTTPS and per-file SHA-256/size verification. Existing drive folders and show plugins are preserved before replacement. A failed batch stops and reports the failure; completed updates are not silently rolled back.

The updater recognizes unpacked XML/Lua packages in their expected plugin folder or at the plugin-library root. ZIP-only copies must be extracted before local installation. The updater downloads the ZIP and the individual install files itself, avoiding an unzip dependency on the console. The updater's own next revision is downloaded and imported manually after closing its running window.

## Testing scope

The repository includes source, manifest, page-link and simulated MA runtime checks. No physical grandMA3 console is connected to the development environment. Native import/export behavior, platform HTTPS availability, touch scrolling, actual screen movement and removed-drive behavior still require verification on the target console. Other catalog plugins retain their supplied release packages; catalog inclusion is not a new MA3 compatibility certification.

See `VERIFICATION.md` for the exact checks performed and the first console check.

Independent implementation. No MATools code, licensing system, or branding is included. Supplied plugin release ownership and attribution remain with their existing authors. This repository does not grant new licensing rights for those packages.

### Lua validation requirement

MA3 2.5 uses Lua 5.5. Set `WLT_LUA55` to a Lua 5.5 executable, with LuaFileSystem available, before running `python3 tools/validate.py`. The check compiles and launches the exact bundled updater against mocked MA objects, including startup drive scanning. Older Lua interpreters are rejected because they miss the loop-variable compile error corrected in 1.0.2.

The updater is named **WLT Plugin Updator**, including its folder and filenames. Its catalog ID remains stable so existing installations can be recognized.
