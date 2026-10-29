Tour Location v1.0.7 — grandMA3 2.4

INSTALL
Copy the extracted TourLocation folder to:
gma3_library/datapools/plugins/
Open Plugins, edit an empty slot, tap Import, select
TourLocation_v1.0.7.xml, and run it.

USE
The large persistent interface opens on North America, USA, and Dallas.
Use the continent tabs, country list, and scrollable city list. Review venue
information and the calculated UTC offset, then tap APPLY SELECTED CITY.
The plugin writes TIMEZONE, LONGITUDE, and LATITUDE, confirms the change, and
then closes the main window.
Each time the plugin is opened, it also sets Server Name to time.google.com and
sets Extern TimeSync Mode to NTP in Settings > Date and Time > Time Server.
Selections retain a visible indicator in each section. Applying a city shows a
confirmation and closes the main plugin window. USA touring coverage is the
priority dataset and includes major metros plus important shed municipalities.
Version 0.3.0 includes 110 USA city presets across all 50 states and Washington,
DC. It is a concert-touring catalog rather than a list of every incorporated
municipality; cities without a qualifying stadium, arena, or shed are omitted.

Version 0.3.1 uses an opaque black application background and updates controls
in place. Changing a selection no longer clears and redraws the full overlay.

Version 0.3.2 adds a dedicated full-window RGBA black backdrop, removes icons
that conflicted with data text, and gives venue names larger, separated lines.

Version 0.3.3 restores right-aligned amber icons with reserved spacing, uses
full-white card text, and adds an in-place city search field with Clear.

Version 0.3.4 adds Set as Default and Reset to Default. The chosen continent,
country, and city are stored in show user variables and restored on next open.
Daylight-saving handling is automatic and its active status is shown in the
location card.

Version 0.3.5 adds world-sphere branding. The window uses a globe header icon,
and the included TourLocationWorld.png is imported on first run and assigned as
the plugin-pool appearance when the console permits image-library import.

Version 0.3.6 increases the information-panel height and reserves more room for
venue and DST details. Venue names use compact, readable spacing so all three
touring venues remain visible without clipping.

Version 0.3.7 removes unsupported MA3 icon and font references, preventing the
red object-address warnings. Search now has a permanent label beside a blank
input field, so placeholder text never overlaps the operator's typed query.

Version 0.3.8 embeds the custom world-sphere PNG directly in the grandMA3 XML
as a UserImage dependency. Importing the XML creates TourLocation in the
image and appearance pools and assigns that appearance to the plugin itself.
The appearance is installed during XML import; running the plugin is not needed.

Version 0.3.9 stores the embedded image in independently encoded 1,024-byte
FileContent blocks, matching grandMA3's native export format. The artwork is a
stripped, single-frame 300 × 300 RGB PNG for reliable console decoding.

Version 0.3.10 replaces the unsupported Regular17 location-card font with the
native Regular18 font. All UI font references now use supported MA3 sizes.

Version 0.3.11 adds console-independent live search polling. The plugin checks
the search field every 0.1 seconds and filters the city list as text is entered,
even on MA3 builds where the LineEdit TextChanged callback is not continuous.

Version 0.3.12 stops the live-search poll immediately when the window closes,
preventing ClearUIChildren from being called on a released city-list handle.

Version 1.0.1 expands the catalog to 284 touring cities across 100 countries
and territories. It adds major stadium, arena, amphitheatre, festival-ground,
and convention touring markets throughout every continent filter while keeping
North America, USA, and the saved city as the default startup path. The search
field receives keyboard focus when the plugin opens and continues filtering at
0.1-second intervals while text is entered. Israel and Egypt receive dedicated
automatic daylight-saving calculations in addition to the existing rules.

Version 1.0.2 adds keyboard-only city selection. Begin typing immediately,
use the Up and Down arrow keys to move the highlighted filtered result, and
press Enter to apply it. If no row has been selected, Enter applies the first
filtered result. Escape continues to cancel and close the plugin.

Version 1.0.3 automatically configures the console Time Server whenever the
plugin opens. Server Name is set to time.google.com and Extern TimeSync Mode is
set to NTP, removing the extra setup step when moving between consoles.

Version 1.0.4 adds session-master protection. The location catalog remains
available for browsing on a connected backup, but Apply is blocked with a clear
notice when the local station is known not to be the GlobalMaster. NTP setup is
also skipped on that station so the plugin never reports a misleading success.

Version 1.0.5 reads the same station Status identifier shown in the Network tab.
GlobalMaster and standalone IdleMaster stations may configure NTP and apply a
location. A station whose status is Connected remains browse-only and receives
a GlobalMaster Required notice before any session-time write is attempted. NTP
success is verified by reading back both time.google.com and NTP mode.

Version 1.0.6 uses the permanent TourLocation Appearance and UserImage identity.
It also creates the shared Utility Plugins tag only when missing, or reuses and
assigns the existing tag without creating a duplicate.

Version 1.0.7 assigns Utility Plugins through the plugin object's native Tags
property using resolved tag and plugin addresses.

COVERAGE
This is a curated worldwide touring-market catalog, not an
exhaustive registry of every venue. Venue names and daylight-saving laws can
change. Verify unusual international rules before show-critical use.
