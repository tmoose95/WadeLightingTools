MA SEARCH v0.3.9
Aaron Wade - Crossfade Design

Universal show-object search and safe navigation prototype for grandMA3 2.4.

CURRENT BUILD
- v0.3.9 replaces post-selection native ScreenContent manipulation with a
  clean, self-contained Lua result browser modeled after MA's Pool/Sheet
  workflow. POOL shows the object's real parent pool as numbered tiles; SHEET
  shows number, name and full address as a readable table. Both views open on
  the selected object's page and highlight it without calling or applying it.
  The obsolete native-screen selector is replaced with a simple POOL + SHEET
  result-browser label because this view never changes console ScreenContent.
- v0.3.8 keeps the closed filter button compact as ALL DATA POOLS, uses MA's
  documented plain-string PopupInput list plus an index fallback so selecting
  a named Data Pool actually applies the filter, and validates candidates by
  true DataPool class. Child objects can no longer become false pools such as
  DP128 merely because their full address contains a DataPool parent. Every
  result row now has persistent left/right SCROLL controls that move one item
  at a time, independently of the other object-type rows. Added vertical and
  horizontal tile margins clearly separate categories and individual results.
- v0.3.7 discovers Data Pools dynamically from the live ShowData tree. It
  combines command-line range results, known collection properties, current-
  pool ancestry, and numeric collection slots because some console builds
  return only the selected pool from Children(). Pool numbers and names are
  always read from the show; none are hard-coded. New pools automatically
  appear after REFRESH INDEX.
- v0.3.6 removes individual DataPool address probing. Missing addresses caused
  grandMA3 to print dozens of red "Could not resolve object address" messages
  whenever the plugin opened. Discovery now uses MA's returned DataPool range
  and actual DataPool collection children, so nonexistent pools are never
  queried individually and plugin startup remains clean.
- The ALL DATA POOLS index no longer prefixes a DataPool address that MA may
  silently ignore. MA Search now selects each discovered Data Pool as the real
  command context, verifies CurrentDataPool() changed to that exact DP, indexes
  its unqualified pools, and restores the user's original Data Pool. A result
  is labeled DP# only from that verified active context, preventing DP2 objects
  from being repeated and mislabeled as other pools (or vice versa).
- v0.3.5 restores the native MA pool-window workflow from v0.3.3. It now
  selects the result's Data Pool before opening the correct native pool, scans
  the opened screen for MA's exposed pool grid, scrolls the calculated object
  cell into view with GridScrollCellIntoView, and draws a five-second pointer
  over the located tile without touching/calling it. RETURN restores both the
  previous workspace and previous Data Pool.
- v0.3.4 replaces the broken Data Pool cycle with a selectable filter built
  from DP numbers actually found in indexed objects. It also removes the unsafe
  native Add Window experiment from Locate. Locate now jumps directly to the
  correct 60-slot page, highlights the exact object index, and provides working
  PREVIOUS 60 / NEXT 60 pool navigation without changing ScreenContent.
- v0.3.3 adds a NATIVE VIEW SCREEN selector that cycles through the displays
  exposed on the current station. Snapshot, native Add Window interaction,
  return control and recovery all follow the selected display.
- Native window creation now uses MA's TouchObj and GetUIObjectAtPosition APIs
  instead of relying only on calculated mouse coordinates. Each Add Window
  stage is verified and automatically restores the snapshot if MA rejects it.
- v0.3.2 fixes Data Pool discovery on consoles that expose individual pools as
  derived DataPool classes. It enumerates the current pool's sibling collection
  plus several supported command-line forms, rejects only collection objects,
  and shows the discovered DP numbers directly in the ALL DATA POOLS label.
- v0.3.1 adds direct command-line pool enumeration as a deduplicated fallback
  when a console exposes DataPool collections without traversable Lua children.
  Presets, sequences, groups, macros, timecodes, pages, layouts and executors
  are queried per Data Pool, preventing a valid show from indexing as zero.
- v0.3.0 snapshots the active screen into an automatically selected unused
  View slot from 9000-9999, opens MA's own Add Window interface, and creates
  the requested genuine native pool window. A small return control restores
  the exact previous workspace and deletes the temporary View by handle.
- User Views are never overwritten, renamed, or permanently created. If no
  empty temporary slot is available or MA does not expose the requested window,
  the recovery path restores the original screen and reports the problem.
- Escape, return-overlay closure, Add Window failures and Lua callback errors
  automatically recall the recovery View before deleting it. A hard console or
  process interruption may prevent Lua cleanup from running; in that case the
  next MA Search launch detects __MASearch_Recovery_S#__, restores its recorded
  screen automatically, and removes the orphaned temporary View.
- v0.2.9 keeps navigation inside MA Search's Lua overlay, preserving every
  window and View underneath it. Selecting a result opens a clean 10x6 pool
  page centered on the matching object; CLOSE immediately returns to work.
- Populated overlay tiles submit their real MA address through the active
  display's command line. Existing Store, Edit, At, Assign and other keywords
  therefore remain authoritative instead of MA Search choosing an action.
- v0.2.8 classifies results strictly from each object's own MA class. Child
  objects no longer inherit the type of a parent collection, so a layout
  element cannot appear as a Layout and a timecode marker cannot appear as a
  Timecode. Data pools are enumerated independently and DP# is attached only
  to objects discovered inside that exact data pool; global/profile results do
  not receive a DP label.
- v0.2.7 adds a data-pool filter. It opens on the current data pool; pressing
  the data-pool button cycles through every pool and ALL DATA POOLS. In the all
  view, result tiles include a compact DP# prefix.
- Preset results now show an unambiguous numerical address and pool type on the
  first line (for example, 3.12 • GOBO), with the preset name on line two.
  Their outlines use the preset feature-family color; custom/unknown pools use
  a neutral outline.
- v0.2.6 checks the Utility Plugins tag references before assigning. Once MA
  Search is tagged, later plugin calls do not issue another Assign command.
- v0.2.5 removes the nested row grids that grandMA3 was collapsing. All
  categories, paging controls and results now live in one flat 8-column grid.
  Eight visual rows keep tile heights compact, result tiles show names only for
  legibility, and full addresses remain available in the location map.
- v0.2.4 fixes compact-row geometry using explicit numeric row heights and
  fixed category/navigation widths. Category labels are now single-line and
  high-contrast, paging controls are compact, and every result tile occupies
  the same aligned row instead of stepping downward.
- v0.2.3 compacts the complete interface to 1660x800, reduces the title/tools,
  shrinks category labels, and dynamically sizes every result row between 56
  and 84 pixels so the categorized search stays inside the visible page.
- Preserves the confirmed-working v0.2.2 mascot image and 1024-byte embedding.
- v0.2.2 makes every category row independently scrollable in five-result
  pages. Exact and closest matches stay first; PREVIOUS/NEXT controls expose
  every additional result without disturbing the position of other rows.
- v0.2.1 replaces uneven result columns with clean horizontal category rows.
  It also uses the proven 1024-byte image block size from Touch Configurator so
  grandMA3 can reconstruct and decode the embedded mascot correctly.
- v0.2.0 redesigns results into readable object-type columns and replaces all
  Edit/Call/Go behavior with a non-destructive pool location map. Selecting a
  result displays its real parent container, native address, page of pool slots,
  and a highlighted exact index without issuing any object command.
- v0.1.3 removes the non-UI Timer callback and dismisses notifications through
  MA's UI coroutine scheduler, preventing the red non-UI-thread error.
- v0.1.2 normalizes the mascot to the same 8-bit RGB PNG format accepted by
  the working Touch Configurator appearance.
- v0.1.1 embeds the mascot in grandMA3-compatible 3072-byte image blocks.
- Opens on the station/display where the plugin is called.
- Indexes named presets, sequences, cues, groups, macros, plugins, views,
  layouts and pages exposed by the selected data pool or all data pools.
- Ranks exact, prefix, substring and multi-word matches.
- Selecting a result opens MA Search's read-only location map; it never calls,
  edits, goes, assigns or fires the result object.
- Reuses Touch Configurator's native top-right ScreenOverlay notification style.
- REFRESH INDEX discovers objects added or renamed after the plugin opened.

FIRST CONSOLE TEST
1. Import the XML and call MA Search.
2. Press REFRESH INDEX, choose ALL DATA POOLS, and search for objects known to
   exist in different Data Pools. Confirm each result has its true DP# and that
   the same DP2 objects are not repeated under every pool.
3. Open the Data Pool filter and confirm every discovered DP can be selected.
4. Select a known preset result. Confirm MA selects its DP, opens the native
   preset pool, scrolls the exact cell into view, and shows the safe pointer
   without calling or applying the preset.
5. Press RETURN TO WORK and confirm the prior workspace and Data Pool return.
