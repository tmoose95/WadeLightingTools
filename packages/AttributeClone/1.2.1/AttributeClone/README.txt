Attribute Clone v1.2.1 for grandMA3 2.5.1

Installation
Copy the AttributeClone folder to gma3_library/datapools/plugins/ on the desired drive. In an empty Plugins pool slot, tap Import and select AttributeClone_v1.2.1.xml. The folder contains its Lua component and PNG; the XML also embeds the PNG with 1,024-byte blocks.

Attribute folders
Attributes now appear under collapsible folders taken from each attribute's actual Feature -> Feature Group relationship in the showfile. The folder number and label follow the showfile (1 Dimmer, 2 Position, etc.). Expand Dimmer to see Dimmer1, Dimmer2, or other Dimmer attributes present on the fixtures. Only attributes shared by all fixtures on that side are offered. Source and destination lists are independent, and either side may be empty.

Scrolling
All four columns use grandMA3 ScrollBox and ScrollBarV controls with fixed 36-unit rows. The previous MORE/page buttons have been removed. Native scroll controls handle touch scrolling and the scrollbar. Selecting an attribute changes the row in place, retaining the current scroll position.

Attribute pairing
Select source and destination attributes in the order you want them paired. Each selected attribute displays its pair number. Review shows the full attribute mapping before cloning. Fixture pairs follow selection order. Groups and layouts are excluded; only sequences, presets and worlds in the current data pool are targeted. Save a show backup first.

Move Screen
The title-bar control now opens a destination chooser, with the current display highlighted and unavailable display handles disabled. Choose a display to move the editor while retaining fixture lists, chosen attributes and expanded folders. Cancel or Escape leaves the editor in place. This chooser is built from MA UI controls. It does not invoke MA's internal Edit Display Preference menu; an identical implementation of that internal menu is not verified. The editor opens on the focused display when first called.

Select in Layout closes the window so the programmer selection can be changed; reopen the plugin to add that selection. Fixture lists persist in user variables. Attribute choices persist while moving the open editor, but not after closing it.

Verification
Lua syntax and simulated MA API tests passed for feature-group classification, 130-attribute scroll content, independent source rendering, fixed-height rows, selection without rebuilding the scroller, display choice/cancellation, and selected attribute mapping through a screen move. Package checks reconstruct and verify the embedded PNG and Lua reference. Actual two-finger touch behavior, scrollbar rendering and display placement require console/onPC 2.5.1 verification.

Display chooser appearance update: monitor icon beside Close; title Edit Display Preference; Clear and Close in title bar; External 5 / External 4 on top, Internal 3 / Internal 2 / Internal 1 in the middle, and Small 7 / Small 6 below. This is a custom MA-control panel matching the reference layout, not an invocation of MA's internal preference menu.
