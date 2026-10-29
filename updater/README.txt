WLT PLUGIN UPDATOR v1.1.6
Aaron Wade - Crossfade Design
Target: grandMA3 2.5.1.0 and later 2.5 releases

CONTAINMENT RELEASE - SHOWFILE IMPORTS PAUSED
The user reported that Import from Drive in v1.1.5 restarted the console for
all attempted plugin targets. The shared native import path is a suspect;
the exact crash cause has NOT been established. Automated tests of mocked MA
objects did not detect this native-console failure.

Both Update Drives + Showfile and Import from Drive are disabled in this
release, including updater self replacement. Download to Drives remains.
The runtime rejects both import modes before any batch operation. The released
Lua contains no native object Import call and no self-update LuaFile worker.
This contains the affected operation; it is not a native import repair.
Do not retry the affected import action on a production console.

INSTALL
Close v1.1.5. Extract this ZIP and copy its WLT Plugin Updator folder into
USB:/grandMA3/gma3_library/datapools/plugins/.
When programming can be interrupted, use MA3's normal plugin editor to import
WLT Plugin Updator_v1.1.6.xml into the updater slot. Do not use v1.1.5's import
actions to install this revision. The green 300 x 300 RGB icon is unchanged.

AVAILABLE WORKFLOW
- Startup scans the current internal plugin library and connected removable
  USB plugin libraries. Without USB, only the internal library is scanned.
  Old software/remote drives, show folders and unrelated files are skipped.
- Showfile, USB Drives and More Plugins tabs compare versions. Green matches
  the live catalog, red differs, grey is unknown or unavailable.
- Choose Download to Drives or Do Nothing for each row. The Action heading
  selects available downloads or clears the queue. Update reviews the drives
  and packages before downloading. No showfile plugin code is imported.
- Downloads verify HTTPS, SHA-256 and byte counts; staged files are read back
  before promotion. Existing drive folders remain in backups. ZIPs are kept
  under WadeLightingToolsData/downloads. Newer local packages are protected.
- The bar and percentage reflect bytes and completed download/write checks.
  The native System Monitor viewport remains; where unsupported, three labelled
  updater log lines are shown. Cancel stops further work.
- QR Code opens the plugin's own GitHub page in a native QR widget. Settings
  provides drives, rescan and connection details. Move-screen controls remain.
- The Showfile import paused control explains the temporary restriction.

DIAGNOSTICS - NO REPRODUCTION REQUIRED
Use ListCrashLog to list existing crash entries. CopyCrashLog copies existing
crash logs to USB; do not add /Remove. DumpLog exports current System Monitor
text. Preserve the failed import's time, console software version and target.
The native crash log may require MA support to decode it.
Official references:
https://help.malighting.com/grandMA3/2.5/HTML/keyword_copycrashlog.html
https://help.malighting.com/grandMA3/2.5/HTML/keyword_dumplog.html

VERIFICATION LIMIT
Automated tests verify import rejection, download behavior, startup/UI,
checksums, packaging and local TLS. They do not execute grandMA3.
The supplied grandMA3.app is macOS 2.4.2.2 and cannot run on this Linux host.
No successful native console/onPC import is claimed. The intended combined
showfile-and-drive workflow remains pending native diagnosis and validation.

Independent WLT implementation. No MATools code, account service or branding.
Certificate attribution is in CA-LICENSE.txt.
