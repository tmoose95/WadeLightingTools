# Hippo Remote v1.3.0

Aaron Wade - Crossfade Design | Target: grandMA3 2.5.1

Hippo Remote now uses the Hippo interface and command workflow from Server Command v2.3.15. It opens directly to HIPPO SERVERS. The console and DMX tabs, startup-tab preferences and non-Hippo operations have been removed.

## Install

Extract the archive and copy the complete `HippoRemote` folder into `grandMA3/gma3_library/datapools/plugins/` on your drive. Edit your Hippo Remote plugin pool slot, choose Import and select `Hippo_Remote_v1.3.0.xml` in that folder. The Lua source, embedded image and metadata are included. The original 512 x 512 Hippo image is preserved byte-for-byte and embedded in 1024-byte XML blocks. The Utility Plugins tag is assigned on launch.

## Controls and appearance

- Opens on the display where it is called, with the same title bar, typography, spacing, action buttons and footer as Server Command's Hippo tab.
- Grey server rows with a thin connection outline; select one or more connected media servers, Select All, or Clear Selection.
- Native ScrollBox and vertical scrollbar for the server list.
- Refresh Devices updates session discovery and clears an armed command.
- Preferences configures the UDP port and three OSC paths, or restores their defaults. Existing HippoRemote settings remain compatible; Server Command settings are separate.
- The title-bar monitor icon opens the same display chooser as Server Command. Moving retains target selection and disarms a pending command so it must be confirmed again.
- Confirm Command and Cancel use the same inline confirmation bar. Selection changes, refresh and preference changes cancel a pending operation. Targets are rechecked immediately before sending.

## Current Hippo operations

| Command | Default OSC path |
| --- | --- |
| Shutdown Machine — power off Windows | `/hippo/shutdown/machine` |
| Restart Machine — full computer reboot | `/hippo/restart/machine` |
| Stop Engine Host — software only | `/hippo/shutdown/host` |

These operations use your Hippotizer Multicontroller OSC mappings on UDP port 7000 by default. See `Hippo_OSC_Setup.md`. The plugin sends integer 1 then integer 0. Both sends are checked; successful UDP transmission does not acknowledge that the server completed the action. A send failure leaves the window open with the error. A successful send closes it, matching Server Command.

Only eligible MediaServer nodes from the current MA session are offered. Console/onPC objects are read to identify that session; no console or DMX control commands are included.

## Verification

21 simulated MA scenarios passed, exercising every scripted button callback, three OSC operations and their exact trigger/reset bytes, target filtering, saved settings, cancellation, failure handling, busy guards, display selection and retained selections. XML references, version, image bytes and archive integrity were checked. No physical console or Hippotizer was connected; native rendering, touch gestures and actual server reception still require a console check.
