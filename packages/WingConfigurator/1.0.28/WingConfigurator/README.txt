WING CONFIGURATOR v1.0.26
Author: Aaron Wade

INSTALL
1. Copy the WingConfigurator folder into gma3_library/datapools/plugins/ on a USB drive or station.
2. In an empty Plugin pool object, choose Import and select WingConfigurator_v1.0.26.xml.
3. Tap the imported plugin to run it.

SURFACE MOVER
Assigns Wing 1, Wing 2, Wing 3, or Wing 4 to any configurable MA3 hardware surface detected on the current station. Rotate Left, Reverse, and Rotate Right move the complete detected surface arrangement quickly. The plugin does not move, copy, delete, or rewrite executor objects.

The interface first filters for actual executor fader modules (MFC, MFE, and MFX), then labels only those valid modules as Fader Screen 1, Fader Screen 2, and so on. Master Modules, data-board entries, and non-fader encoder/channel modules are not shown or editable. Connected extensions appear as Extension Fader Screen 1, 2, and so on only while connected. These labels exist only inside the plugin and do not rename console hardware or network stations.

The plugin automatically orders full-size console surfaces by stable hardware identity instead of the order in which grandMA3 reports them: the MFX surface is Fader Screen 1 and the MFE surface is Fader Screen 2. Additional detected fader surfaces continue sequentially as 3 and 4. Tap Identify to flash that surface's executor-fader LEDs three times. The Identify button remains illuminated for the complete flash sequence, then returns to normal. This does not change show data or executor assignments.

Identify uses the documented executor-fader LED ranges. It does not access ScreenOverlay, ScreenContent, ViewButtons, letterbox displays, command displays, or ColorTheme data.

QUICK PRESETS
- Full Size: first console fader surface = Wing 1; second = Wing 2.
- Full Size Reversed: first console fader surface = Wing 2; second = Wing 1.
- Light: console fader surface = Wing 1.
- Light Reversed: console fader surface = Wing 2.

Quick presets do not change connected extension assignments. Extensions remain individually configurable from their own cards.
Every clickable control uses a visible rounded green outline with a dark face. Identify and Change Wing ID turn green during their active operations. The active Wing ID and matching quick preset remain green. The embedded close-up appearance is optimized for readability at Plugin pool size.

PLUGIN APPEARANCE
The black-and-yellow fader-wing image and its Appearance are embedded directly in the XML as a 300 x 300 opaque RGB PNG using the same DependencyExport format as Server Command. No separate image import is required.
The Appearance and UserImage use the permanent identifier WingConfigurator, with no revision suffix, so updates reuse the same dependency identity.

Designed for grandMA3 software 2.4.x.

The Utility Plugins tag is created only when missing, then assigned through the
plugin object's native Tags property using resolved object addresses.
