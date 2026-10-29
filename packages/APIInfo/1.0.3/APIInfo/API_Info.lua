-- API Info v1.0.3 | Aaron Wade - Crossfade Design | read-only grandMA3 diagnostic
local NAME, VERSION = "API Info", "1.0.3"

local PROPERTY_NAMES = {
    "Name", "Class", "IP", "Ip", "IPAddress", "IpAddress", "IPAddr",
    "DeviceType", "Type", "HostType", "HostSubType", "Model", "Manufacturer",
    "Status", "SessionStatus", "NetworkStatus", "Enabled", "NetworkEnabled",
    "InMySession", "MySession", "IsInSession", "InSession", "SessionMember",
    "Session", "SessionName", "SessionIndex", "SessionSlot", "Slot", "OnlineTime",
    "Connected", "Online", "StationID", "StationId", "Role", "Mode"
}

local function safe(fn, fallback)
    local ok, value = pcall(fn)
    if ok then return value end
    return fallback
end

local function clean(value, depth, seen)
    depth, seen = depth or 0, seen or {}
    local kind = type(value)
    if kind == "nil" or kind == "string" or kind == "number" or kind == "boolean" then return value end
    if kind ~= "table" then return tostring(value) end
    if depth > 8 or seen[value] then return "<recursive>" end
    seen[value] = true
    local result = {}
    for key, item in pairs(value) do result[tostring(key)] = clean(item, depth + 1, seen) end
    seen[value] = nil
    return result
end

local function describe(handle)
    local item = {
        handle = tostring(handle),
        class = safe(function() return tostring(handle:GetClass()) end, ""),
        index = safe(function() return Obj.Index(handle) end, nil),
        address = safe(function() return handle:AddrNative(nil, true) end, ""),
        properties = {}
    }
    for _, name in ipairs(PROPERTY_NAMES) do
        local value = safe(function() return handle:Get(name) end, nil)
        if value ~= nil and tostring(value) ~= "" then item.properties[name] = clean(value) end
    end
    return item
end

local function collect_tree(root, source, output, state, depth)
    if not root or state.count >= state.limit then return end
    depth = depth or 0
    local id = tostring(root)
    if state.seen[id] then return end
    state.seen[id], state.count = true, state.count + 1
    local item = describe(root)
    item.source, item.depth = source, depth
    output[#output + 1] = item
    if depth >= state.max_depth then return end
    local children = safe(function() return root:Children() end, {})
    if type(children) == "table" then
        for _, child in pairs(children) do collect_tree(child, source, output, state, depth + 1) end
    end
end

local function collect_query(query, output, state)
    local objects = safe(function() return ObjectList(query) end, {})
    if type(objects) == "table" then
        for _, handle in pairs(objects) do collect_tree(handle, query, output, state, 0) end
    end
end

local function first_external_drive()
    local drives = safe(function() return Root().Temp.DriveCollect end, nil)
    if not drives then return nil, nil end
    for drive_number, drive in ipairs(drives) do
        local drive_type = tostring(safe(function() return drive.drivetype end, "")):lower()
        if drive_type == "removeable" or drive_type == "removable" then
            local path = safe(function() return drive.path end, nil)
            if (not path or tostring(path) == "") then path = safe(function() return drive:Get("Path") end, nil) end
            if path and tostring(path) ~= "" then return drive_number, tostring(path) end
        end
    end
    return nil, nil
end

local function export_report(report)
    local separator = safe(GetPathSeparator, "/") or "/"
    local drive_number, drive_path = first_external_drive()
    if not drive_number then return false, "No removable/external drive was found. Insert the USB drive and run API Info again." end
    local selected = safe(function() return Cmd("Select Drive " .. drive_number) end, nil)
    if selected == nil then return false, "MA found the external drive but could not select Drive " .. drive_number .. "." end
    coroutine.yield(0.15)
    local library_path = safe(function() return GetPathOverrideFor(Enums.PathType.Library, drive_path) end, nil)
    if not library_path or library_path == "" then return false, "Could not resolve grandMA3/gma3_library on Drive " .. drive_number .. "." end
    local destination = library_path .. separator .. "datapools" .. separator .. "plugins" .. separator .. "APIInfo" .. separator .. "API_Info_Report.json"
    local called, result = pcall(ExportJson, destination, report)
    if not called or result == false then return false, "ExportJson failed for " .. destination .. ": " .. tostring(result) end
    return true, destination, drive_number
end

local function main()
    Printf("%s v%s: collecting read-only diagnostics for the first external drive...", NAME, VERSION)
    local report = {
        plugin = {name = NAME, version = VERSION, read_only = true, target = "first external drive"},
        generated = tostring(safe(Time, "unknown")),
        version = tostring(safe(Version, "unknown")),
        release_type = tostring(safe(ReleaseType, "unknown")),
        host = {
            os = tostring(safe(HostOS, "unknown")),
            type = tostring(safe(HostType, "unknown")),
            subtype = tostring(safe(HostSubType, "unknown"))
        },
        build_details = clean(safe(BuildDetails, {})),
        object_free_api = clean(safe(GetApiDescriptor, {})),
        object_api = clean(safe(GetObjApiDescriptor, {})),
        device_objects = {}
    }
    local state = {seen = {}, count = 0, limit = 2000, max_depth = 10}
    local configuration = safe(DeviceConfiguration, nil)
    if configuration then
        Printf("API Info: DeviceConfiguration dump follows")
        safe(function() configuration:Dump() end, nil)
        collect_tree(configuration, "DeviceConfiguration()", report.device_objects, state, 0)
    end
    for _, query in ipairs({"Station", "Console Thru", "onPC Thru", "NetworkNode Thru", "ProcessingUnit Thru", "Session Thru"}) do
        collect_query(query, report.device_objects, state)
    end
    report.device_object_count = state.count
    report.device_object_limit_reached = state.count >= state.limit

    local ok, detail, drive_number = export_report(report)
    if ok then
        Printf("API Info complete: %d objects captured", state.count)
        Printf("API Info report: %s", detail)
        MessageBox({
            title = "API INFO COMPLETE",
            message = "Captured " .. state.count .. " unique objects and both MA Lua API descriptors.\n\nThe first external drive was selected as DRIVE " .. drive_number .. ".\n\nSaved at:\ngrandMA3/gma3_library/datapools/plugins/APIInfo/API_Info_Report.json\n\nReturn that JSON file for analysis.",
            commands = {{value = 1, name = "OK"}}
        })
    else
        ErrPrintf("API Info export failed: %s", detail)
        MessageBox({title = "API INFO EXPORT FAILED", message = detail, commands = {{value = 1, name = "OK"}}})
    end
end

return main
