# API Info v1.0.3

**Publishing name:** API Info  
**Author:** Aaron Wade - Crossfade Design  
**Compatibility:** grandMA3 2.4+

API Info is a read-only diagnostic plugin. It exports the exact Lua API descriptors and network/session objects exposed by the console.

## Use

1. Copy the complete unversioned `APIInfo` folder into `grandMA3/gma3_library/datapools/plugins` on the external drive.
2. Import `API_Info_v1.0.3.xml` into an empty plugin pool object.
3. Keep the external drive connected and run **API Info** while the intended session and devices are online.
4. After **API INFO COMPLETE**, retrieve:

   `First external drive/grandMA3/gma3_library/datapools/plugins/APIInfo/API_Info_Report.json`

The plugin only reads and exports diagnostics. It does not modify show data or operate connected devices. The report excludes the console serial number.
