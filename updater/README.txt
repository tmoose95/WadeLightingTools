WLT PLUGIN UPDATOR v1.1.8
Aaron Wade - Crossfade Design
Target: grandMA3 2.5.1.0 and later 2.5 releases

TAB ACTIONS
Showfile: Import from Drive, Import from Internet, Do Nothing.
  Both import choices remain visible, labelled paused. Selecting one explains
  the temporary restriction and does not change a pool object.
Drives: Download from Internet, Do Nothing.
  Available only for other plugins found in a complete package on a scanned
  internal or connected USB drive. The source drive need not be selected as
  a download destination. Eligibility is checked again before any download.
  WLT Plugin Updator itself is free to download and open, with no drive-copy
  requirement. A showfile-only copy does not qualify another plugin.
More Plugins: plugin QR pages; Download from Internet appears only when a
  drive copy qualifies (or for the free updater). Showfile imports remain paused. Action queues are separate for each tab.

CONSOLE RESTART INVESTIGATION
A restart was reported when starting an import through v1.1.5. The supplied
log records a native memory-access fault but no updater Starting update or
import message immediately beforehand. It does not establish the cause.
The update popup previously embedded an unverified native System Monitor
window before running the update. That widget has been removed. This change
is a precaution, NOT a confirmed fix. The last three updater messages are
now shown as ordinary labels; this is not the full System Monitor stream.

Automated showfile imports and self replacement remain blocked. The released
Lua has no native object Import call and no self-update LuaFile worker.
Do not retry the affected updater import action on a production console.
Native MA3 testing is still needed before imports can be enabled again.

LICENSING
This revision checks drive presence only. It does not prove purchase or
register a drive. Purchase-key verification, registered-drive enforcement and
checkout are separate unfinished work. Existing catalog URLs are preserved
so the updater continues to work. The updater never requires a license key.

INSTALL
Close the old updater. Extract this ZIP and copy its WLT Plugin Updator folder
into USB:/grandMA3/gma3_library/datapools/plugins/.
When programming can be interrupted, use MA3's normal plugin editor to import
WLT Plugin Updator_v1.1.8.xml. Do not use an older updater's automated import
actions to install this revision. The green 300 x 300 RGB icon is unchanged.

AVAILABLE WORKFLOW
- Startup scans current internal and connected removable USB plugin libraries.
  With no USB, only the internal library is scanned. Old software/remote drives,
  show folders, backups and unrelated files are skipped.
- Drives lists packages on selected internal and USB drives.
- Green versions match the live catalog; red differs; grey means unavailable.
- Downloads verify HTTPS, SHA-256 and byte counts. Staged files are read back
  before promotion. Existing drive folders remain in backups. ZIPs are kept
  under WadeLightingToolsData/downloads. Newer local packages are protected.
- Bar and percentage follow downloaded bytes and completed write/verify steps.
  Three activity labels show recent updater messages. Cancel stops further work.
- QR Code links to the plugin's own GitHub page. Settings provides drives,
  rescan and connection details. Move-screen controls remain.

VERIFICATION LIMIT
Automated tests cover menu separation, import rejection, downloads, progress,
startup, checksums, packaging and local TLS. They do not execute grandMA3.
The supplied app is macOS 2.4.2.2 and cannot run on this Linux build host.
No native console/onPC stability or successful import is claimed.

Independent WLT implementation. No MATools code, account service or branding.
Certificate attribution is in CA-LICENSE.txt.
