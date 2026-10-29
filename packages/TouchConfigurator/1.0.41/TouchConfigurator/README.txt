TOUCH CONFIGURATOR
Author: Aaron Wade - Crossfade Design
Tag: Utility Plugins

Identifies connected large touch displays and exchanges their complete screen layouts.

SIZING MODE
- SIZE: ORIGINAL preserves the source layout geometry exactly. When the destination
  display has a larger user-defined grid, the layout remains at its original size and
  leaves additional usable room around it, matching the reference behavior.
- SIZE: FIT SCREEN proportionally expands or shrinks the transferred layout so the
  windows fill the destination display's configured user-defined grid.
- The sizing button is in the Touch Configurator title bar and can be changed before
  each CHANGE LAYOUT operation. Original Size is the default for compatibility with
  previous revisions.

TRANSFER BEHAVIOR
- Touch Screens 1-3 are the verified built-in 1920x1080 displays.
- Additional connected displays larger than 800x480 appear as DP Touch Screens.
- Internal 800x480 fader/control surfaces are excluded.
- IDENTIFY displays a compact TOUCH SCREEN X notifier only on the selected display.
- The UI always shows five permanent screen slots. Connected screens are active;
  disconnected Screens 4/5 remain visible as stored offline slots.
- Every row shows its current Active Display or Stored Display mapping.
- CHANGE LAYOUT captures both live screens, recalls each screen to the opposite
  destination, transfers the matching ViewButton assignments, and updates stored Views
  in the current User Profile so future recalls follow the new physical-screen mapping.
- Stored View remapping remains transactional. If a stored View or ViewButton operation
  fails, completed changes are rolled back and the original live screens are recalled.
- Temporary capture Views are deleted directly after commit or rollback.

FIT SCREEN DETAILS
- grandMA3 ScreenContent uses the display grid configured by Configure Display Width
  and Height. ViewWidget X/Y/W/H positions use the corresponding 2x sub-grid.
- Fit Screen reads the source ScreenContent RequestedW/RequestedH and the destination
  display grid, then proportionally rescales live ViewWidget X/Y/W/H values.
- Stored ViewWidget geometry is rescaled at the same time as its Display assignment,
  so later View recalls retain the fitted arrangement.
- When a stored View resolves to one common destination grid size, its RequestedW and
  RequestedH are advanced with the geometry so later transfers can scale cleanly in
  either direction.
- Window-specific child settings inside ViewWidgets are not rewritten.

GENERAL
- Large shows are processed in paced batches to reduce redraw and object-change load.
- The Utility Plugins tag is created only when missing and assigned to the plugin.
- The plugin appearance/image dependency remains embedded in the XML under the stable
  TouchConfigurator identity so updates do not create revisioned duplicate images.
- The ZIP and XML filenames contain the revision; the plugin name and folder do not.

Target: grandMA3 2.4.x. The Fit Screen implementation uses the 2.4 display-grid and
ScreenContent structures and safely falls back rather than writing geometry if the
required destination grid cannot be resolved.
