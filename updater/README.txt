WLT PLUGIN UPDATOR v1.0.2
Aaron Wade - Crossfade Design
Target: grandMA3 2.5.1.0 and later 2.5 releases

INSTALL
1. Extract this archive.
2. Copy WLT Plugin Updator to grandMA3/gma3_library/datapools/plugins/ on USB.
3. Edit an empty plugin pool slot, select your USB drive, and import
   WLT Plugin Updator_v1.0.2.xml from the WLT Plugin Updator folder.
4. Run the plugin. It scans connected drives BEFORE opening the main window.

WORKFLOW
- Installed: versions in the selected destination DataPool.
- On Drive: newest complete XML/Lua package on your selected drives.
- Online: latest published catalog version, when the catalog request succeeds.
- Select Updates selects newer versions of plugins already in that DataPool.
  Individual rows can also be selected to install new plugins.
- Drives selects one or more download destinations and local package sources.
- DataPool selects the destination. Existing matching plugins keep their slots;
  new plugins are placed only in empty slots. All matching copies in that
  DataPool are shown in the review and updated.
- Download & Install: verify downloads, write selected drives, then import.
- Download Only: update files on selected drives without importing into the show.
- Install Only: import the newest complete package on selected drives.
- Rescan repeats drive and internet checks.
- The monitor icon opens the display preference layout used in Server Command.

DRIVE SCANNING
Uses the drives recognized by this MA3 station, including internal and removable
storage. It reads the MA plugin library folders, not every file on the disk.
It recognizes the catalog's plugin subfolders and XML exports at the plugin
library root. Unpacked packages must have every external Lua component beside
the XML. A ZIP copied by itself must be extracted first. The updater downloads
both the original ZIP and its validated install files; no console unzip tool
is needed. Source XMLs are rechecked before import. Removed drives are rejected.

INTERNET
The fixed catalog is:
https://raw.githubusercontent.com/tmoose95/WadeLightingTools/main/catalog.tsv
Website:
https://tmoose95.github.io/WadeLightingTools/
HTTPS requires curl, or openssl plus timeout, on a Linux/macOS station.
Windows onPC uses Windows PowerShell/.NET HTTPS. Certificate checking stays on.
A missing client, bad certificate, unreachable host or timeout leaves Install
Only available. The updater never changes console network configuration.
Downloads run in bounded background jobs while the Lua UI yields.

PACKAGE PROTECTION
SHA-256 and byte counts are verified against the HTTPS catalog before any
release is installed. Drive files are staged and read back, then the folder is
promoted; an existing folder is moved into WadeLightingToolsData/backups.
Original ZIP downloads are kept in WadeLightingToolsData/downloads.
Existing show plugins are exported and checked before replacement. A missing
backup component stops installation. Newer or unknown installed versions are
not silently overwritten. The batch stops at the first failure and lists the
result; completed updates are not rolled back automatically.

The updater does not update its own running plugin in place. Use
Download Only for WLT Plugin Updator, close it, then import its new XML manually.
Utility Plugins is assigned at runtime; no incompatible XML Tags field is used.
The embedded pool image is 300 x 300 RGB PNG with 1024-byte image blocks.

VERIFICATION LIMIT
Automated source/package and mock-environment tests accompany the repository.
Actual 2.5.1 console import, drive filesystem permissions, HTTPS utilities,
scroll gestures and display movement must still be checked on the console.
This is an independent implementation of a batch updater workflow. It does not
use MATools code, licenses, account services or branding.

REVISION 1.0.2
Fixes Lua 5.5 compile failures caused by assigning to loop variables.
Plugin, folder and file names are WLT Plugin Updator. The pool artwork uses a green circular update symbol in the center.
Close the previous updater and import WLT Plugin Updator_v1.0.2.xml into its
existing plugin slot. The catalog ID is retained and previous updater names
and folders are recognized.
