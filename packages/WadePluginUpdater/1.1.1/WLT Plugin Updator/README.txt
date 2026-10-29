WLT PLUGIN UPDATOR v1.1.1
Aaron Wade - Crossfade Design
Target: grandMA3 2.5.1.0 and later 2.5 releases

INSTALL
1. Close the previous updater and extract this ZIP.
2. Copy WLT Plugin Updator into grandMA3/gma3_library/datapools/plugins/ on USB.
3. Edit the existing updater pool slot (or an empty slot), choose your USB,
   and import WLT Plugin Updator_v1.1.1.xml from that folder.
4. Run it. A progress window scans connected drives and the showfile before
   opening the main table. Cancel & Exit stops the scan.

TABS AND VERSION COLOURS
- Plugins in your Showfile: recognized WLT plugins across all DataPools.
- Plugins on your USB Drives: recognized, complete packages on removable drives.
- More Plugins: catalog plugins not yet in the showfile.
- Showfile, USB / Drive and Online version cells compare to the live catalog.
  Green = matches latest. Red = different (older OR newer). Grey = unknown,
  no copy, or an unavailable online catalog. A newer installed version is never
  downgraded. Info shows the versions and DataPool names.
- A showfile cell containing several copies is red if any copy differs.
- USB / Drive displays the selected source package; an internal source is marked
  Internal. Tap it to choose another complete version on the selected drives.
- Scroll the table with the station's native scroll gestures or scrollbar.
  Selecting row actions preserves the scroll position.

ACTIONS
Tap each row's Action selector to queue one action:
- Do Nothing: no changes for that plugin.
- Import Online: download the latest files to the selected drives, then import.
- Download to Drives: download files and ZIP without changing the showfile.
- Import from Drive: import the chosen complete local package without internet.
The Action column header selects available updates or clears all queued actions.
Update opens a review listing every action, drive, DataPool and plugin slot.
Nothing is downloaded or installed just by selecting a row action.

DESTINATIONS
Drives selects download destinations and permitted local package sources.
Update Destination defaults to All DataPools; select an individual pool to
restrict imports. Existing matching plugins retain their slots. If a plugin is
missing, an empty slot is allocated in each chosen DataPool. The review lists
all targets. Multiple matching copies are preserved and updated in place.

Settings contains Drives, Rescan and Connection Details.
The monitor icon opens the display preference layout used in Server Command.
Tab and queued actions are retained when moving screens.

INTERNET / CONNECTION DETAILS
Catalog: https://raw.githubusercontent.com/tmoose95/WadeLightingTools/main/catalog.tsv
Website: https://tmoose95.github.io/WadeLightingTools/

Version 1.1.0 introduced fixes that remove the requirement for a separate timeout utility when using
OpenSSL on a console. The downloader uses a bounded background process while
Lua yields. A current Mozilla CA bundle is embedded in the Lua component, so
certificate checks also work on stations with an incomplete system CA store.
The USB does not need to stay connected just to provide the certificates.

Linux/macOS: curl, or OpenSSL with peer/hostname validation, or GNU Wget.
Windows onPC: Windows PowerShell/.NET HTTPS with the system trust store.
All connections retain certificate validation. No insecure HTTP fallback.
The updater never changes the console's network configuration.

An unavailable catalog is now labelled Online catalog unavailable. It is not a
claim that the whole station has no internet. Connection Details displays the
client and actual error (certificate, DNS, connection timeout, HTTP status, or
missing client). MA World Server and other updaters contact different services.
If TLS reports an expired or not-yet-valid certificate, verify station time.
Local packages remain usable while the catalog is unavailable.

WHAT CHANGED IN 1.1.1
- Uses MA's object Import(directory, filename) on the exact target plugin,
  bypassing the Library keyword/cache lookup that failed in the console log.
- Checks the import result, plugin version and exported Lua contents. Existing
  show-plugin backups are retained. A reported OK command alone is not success.
- Reads each plugin directory/XML once per scan, with no startup SHA-256 pass.
- Reuses scanned metadata after fetching the online catalog. Only newly listed
  plugin folders need an additional read. Updates refresh affected packages and
  showfile metadata without triggering a second full drive scan.

DRIVE SCANNING
Only the current internal plugin library (Drive 1) and connected removable USB
libraries are considered. Old-version and remote-station drives are excluded.
With no USB connected, only the current internal library is scanned and selected.
Reads catalog plugin folders and XML exports directly at the plugin-library root.
It never walks showfiles, media, backups, downloads or unrelated directories.
The current show's plugin metadata is checked in memory; no saved shows are read.

ZIP-only copies must be extracted first. Each local package needs its Lua files
beside the XML. Local-source checksums are taken when that package is selected
for review and checked again before import. Online file and ZIP checksums remain
mandatory. Settings > Rescan deliberately starts a fresh plugin-folder scan.
Removed drives are rejected before import.

PACKAGE PROTECTION
SHA-256 hashes and byte counts are checked against the HTTPS catalog.
Files are staged and read back before folder replacement. Existing drive folders
are preserved in WadeLightingToolsData/backups. Download ZIPs are retained in
WadeLightingToolsData/downloads. Existing show plugins are exported and checked
before replacement. A missing backup component stops installation. Newer or
unknown versions and locked plugins are not overwritten. The batch stops at
its first failure; completed updates are not rolled back automatically.

The running updater cannot replace itself. Choose Download to Drives, close
it, and manually import the new XML into its existing pool slot.
The catalog ID remains WadePluginUpdater for compatibility with prior names.
The green update-circle image remains 300 x 300 RGB PNG with 1024-byte blocks.
Utility Plugins is assigned at runtime rather than using an incompatible XML
Tags field. The two WLT version-cell colours are added to the UI colour theme;
existing theme colours are not modified.

VERIFICATION LIMIT
Lua 5.5 package/startup tests, mocked MA runtime/UI tests, actual local TLS
certificate/hostname rejection tests and a read-only live GitHub download test
accompany this revision. These do not replace native console testing.
The supplied grandMA3.app bundle is macOS 2.4.2.2. This Linux build environment
cannot execute it, so this release has NOT been run inside grandMA3 onPC.
Native 2.5.1 imports, touch gestures, screen movement and the desk's HTTPS client
still need confirmation on the station.

Independent WLT implementation, using the supplied screenshots as a workflow
reference. No MATools code, account services, advertising or branding included.
Certificate bundle attribution is in CA-LICENSE.txt.
