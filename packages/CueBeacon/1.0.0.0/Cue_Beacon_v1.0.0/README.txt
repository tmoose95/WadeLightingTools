Cue Beacon v1.0.0 — grandMA3 2.4

Install:
Copy the Cue_Beacon_v1.0.0 folder into gma3_library/datapools/plugins on a USB drive, then import Cue_Beacon.xml.

Components:
1 Setup       - choose start cue, stop mode/cue, page and executor
2 Runtime     - called automatically by the cue commands
3 Release All - emergency release of executor appearance overrides

The setup component preserves existing cue commands and appends Cue Beacon commands.
Reserved appearances: 9997 = Cue Beacon RED, 9998 = Cue Beacon DIM.

v1.0.0 validates the cue-command and per-executor appearance workflow first. Physical key LED pulsing is intentionally not enabled in this build because SetLED requires hardware-module/LED index resolution per console/wing; that will be added after validating the executor appearance behavior on the target desk.
