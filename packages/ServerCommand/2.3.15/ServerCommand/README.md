# Server Command v2.3.15

**Author:** Aaron Wade - Crossfade Design  
**Target environment:** grandMA3 2.5.1 and Hippotizer V4  
**Publishing name:** Server Command

## Installation

Copy the complete `ServerCommand` folder to `gma3_library/datapools/plugins/` on the import drive. In the plugin editor, import `Server_Command_v2.3.15.xml`. Reimport the XML to update the code stored in the show; replacing only a disk Lua file does not update that stored component.

The folder and `Server_Command.lua` remain unversioned. The ZIP and XML carry the release number. The original 300 x 300 PNG and its Appearance dependency are embedded in the XML using unchanged 1,024-byte blocks. A separate PNG copy is included. The Utility Plugins tag is created/reused and assigned by command on launch.

## Changes for grandMA3 2.5.1

- Updated the XML data version to 2.5.1.0; the component is Lua source rather than version-specific bytecode.
- Added the same custom Move Screen chooser as Attribute Clone v1.2.0. The current display is highlighted, unavailable display handles are disabled, Cancel/Escape leaves the window in place, and moving retains the active tab and selected IPs. An armed command is canceled on a move and must be chosen and confirmed again. The chooser uses MA UI controls; it does not invoke MA's internal Edit Display Preference menu.
- The device list now uses MA ScrollBox and ScrollBarV controls, keeping actions reachable when many devices are listed.
- Accepts both `OK` and `Ok` command responses consistently.
- Cancels an armed command when selection, Select All, Clear, Refresh, or Preferences changes the applicable state. Confirmation rechecks live target identity and membership before dispatch.
- Applies the busy guard to all actions, preventing repeated confirmation during OSC trigger/reset or command dispatch.
- Sends reset packets to every successfully triggered Hippo even if another target's trigger fails.
- Validates all OSC preferences before saving any of them, and preserves the current tab when changing/resetting OSC values.
- Reads only properties actually exposed by an object, avoiding unknown-property probes.
- Includes onPC hosts in the Consoles tab. Local-station name matching precedes the existing unique-subtype fallback; duplicate subtypes with no resolvable local name remain unverified rather than being picked by list order.
- Uses the device's command-line index and actual collection type for Network Speed Test, avoiding ambiguous duplicate names. The test is dispatched through CmdIndirectWait to MA's main task.
- Sends disruptive native actions to other selected stations before this station.

## Button and command mapping

| Tab | Button | Dispatch |
| --- | --- | --- |
| Hippo | Shutdown Machine | OSC `/hippo/shutdown/machine`, integer 1 then 0 |
| Hippo | Restart Machine | OSC `/hippo/restart/machine`, integer 1 then 0 |
| Hippo | Stop Engine Host | OSC `/hippo/shutdown/host`, integer 1 then 0 |
| Consoles / DMX Nodes | Invite to Session | `Invite IP <address>`; available targets only |
| Consoles / DMX Nodes | Restart Application | `Restart IP <address> /NoConfirmation` |
| Consoles / DMX Nodes | Reboot Device | `Reboot IP <address> /NoConfirmation` |
| Consoles / DMX Nodes | Shut Down | `ShutDown IP <address> /NoConfirmation` |
| Consoles / DMX Nodes | Network Speed Test | `NetworkSpeedTest <Console/onPC/NetworkNode> <number>`; excludes resolved local station |
| Consoles / DMX Nodes | Disconnect | `Disconnect IP <address>` |
| Consoles / DMX Nodes | Dismiss from Session | `Dismiss IP <address>` |
| Consoles | Save Show | Local `Cmd` or remote `RemoteCommand`: `SaveShow If Drive 1` |
| Consoles | Save to External Drives | Each selected station enumerates its own removable drives and runs `SaveShow If Drive <CmdlineIndex>` for each |
| Consoles | Lock Desk | Local `Cmd` or remote `RemoteCommand`: `Menu "DeskLock"` |

All non-invite actions target active members. Hippo OSC paths and UDP port retain the existing ServerCommand user variables; defaults are port 7000 and the paths above. Hippotizer Multicontroller mappings are still required; see `Hippo_OSC_Setup.md`. MA-native remote operations require the station/session to permit remote calls. OSC acceptance by UDP is not a Hippotizer execution acknowledgement.

## External drive saves

This release preserves the v2.3.12 save worker: it uses each drive's `CmdlineIndex()` rather than assuming the USB is Drive 2, rechecks drive identity, waits while ShowSaving, and reports per-station completion or failure. Remote worker invocations explicitly address this plugin's data pool and plugin number, even if another operator selected a different data pool. The plugin component must be streamed in the session.

Successful external saves close the window; missing drives, command failures, or missing replies leave a readable result. Native save completion means MA accepted the command and returned to a ready state; it is not an independent file-integrity check. If this station's return IP cannot be resolved, the remote request can still be sent, but its result is marked unverified. Existing available-station discovery uses the original matching IPv4 /24-prefix rule.

## Verification

See `Verification.txt`. All scripted button callbacks and 31 simulated scenarios passed, including every action family and the display chooser. XML/Lua references, version metadata, and embedded image bytes were checked. The workspace interpreter checked Lua syntax; no grandMA3 executable or physical endpoints were available. Console/onPC 2.5.1 rendering, native close/escape gestures, network permission handling, actual shutdown/restart results, Hippotizer reception, and written show files require live verification. No real network commands or console saves were executed by the tests.

## Official 2.5 command references

- https://help.malighting.com/grandMA3/2.5/HTML/keyword_networkspeedtest.html
- https://help.malighting.com/grandMA3/2.5/HTML/keyword_invite.html
- https://help.malighting.com/grandMA3/2.5/HTML/keyword_restart.html
- https://help.malighting.com/grandMA3/2.5/HTML/keyword_reboot.html
- https://help.malighting.com/grandMA3/2.5/HTML/keyword_shutdown.html
- https://help.malighting.com/grandMA3/2.5/HTML/keyword_disconnect.html
- https://help.malighting.com/grandMA3/2.5/HTML/keyword_dismiss.html
- https://help.malighting.com/grandMA3/2.5/HTML/keyword_drive.html
- https://help.malighting.com/grandMA3/2.5/HTML/keyword_saveshow.html
- https://help.malighting.com/grandMA3/2.5/HTML/keyword_remotecommand.html

Display chooser appearance update: monitor icon beside Close; title Edit Display Preference; Clear and Close in title bar; External 5 / External 4 on top, Internal 3 / Internal 2 / Internal 1 in the middle, and Small 7 / Small 6 below. This is a custom MA-control panel matching the reference layout, not an invocation of MA's internal preference menu.

Device rows now use a grey face inset inside a two-pixel membership outline: green for active members, light grey for available members. Checkbox selection and MY STATION text remain distinct indicators.
