-- Hippo Remote v1.3.0 | Hippo-only interface derived from Server Command v2.3.15 | Aaron Wade - Crossfade Design | grandMA3 2.5.1
local NAME, VERSION, AUTHOR = "Hippo Remote", "1.3.0", "Aaron Wade"
local _, _, signalTable, myHandle = ...

local DEF = {
    port = 7000,
    shutdown_machine = "/hippo/shutdown/machine",
    restart_machine = "/hippo/restart/machine",
    shutdown_host = "/hippo/shutdown/host"
}
local VAR = {
    port = "HippoRemoteOscPort",
    shutdown_machine = "HippoRemoteOscShutdownMachine",
    restart_machine = "HippoRemoteOscRestartMachine",
    shutdown_host = "HippoRemoteOscShutdownHost"
}
local osc = {}
local ui = { targets = {}, controls = {}, selected = {}, actions = {}, pending = nil, pendingTargets = nil}

local function safe(fn, fallback)
    local ok, value = pcall(fn)
    if ok then return value end
    return fallback
end

local function valid(handle)
    return handle ~= nil and safe(function() return IsObjectValid(handle) end, false)
end

local function prop(handle, name)
    if not handle then return "" end
    -- Only request properties the object actually exposes. Catching Get() with
    -- pcall alone does not prevent all unknown-property monitor messages.
    local count = safe(function() return handle:PropertyCount() end, nil)
    if type(count) ~= "number" then return "" end
    for index=0,count-1 do
        local candidate = safe(function() return handle:PropertyName(index) end, nil)
        if candidate and tostring(candidate):lower() == name:lower() then
            local value = safe(function() return handle:Get(candidate) end, nil)
            return value ~= nil and tostring(value) or ""
        end
    end
    return ""
end

local function children(handle)
    local result = safe(function() return handle:Children() end, {})
    return type(result) == "table" and result or {}
end

local function from(address)
    return safe(function() return FromAddr(address) end, nil)
end

local function ensure_utility_tag()
    local tag_name = "Utility Plugins"
    local function find_tag()
        local list = safe(function() return ObjectList('Tag Thru') end, {}) or {}
        for _, candidate in ipairs(list) do
            if prop(candidate, "Name"):lower() == tag_name:lower() then return candidate end
        end
        return nil
    end
    local tag = find_tag()
    if not tag then
        safe(function() Cmd('Store Tag "' .. tag_name .. '" /NoConfirmation') end, nil)
        tag = find_tag()
    end
    local plugin = safe(function() return myHandle:Parent() end, nil)
    local tag_index = tag and tonumber(safe(function() return Obj.Index(tag) end, nil)) or nil
    local plugin_index = plugin and tonumber(safe(function() return Obj.Index(plugin) end, nil)) or nil
    if tag_index and plugin_index then
        local plugin_handle = safe(function() return HandleToInt(plugin) end, nil)
        local references = safe(function() return tag:GetReferences() end, {}) or {}
        for _, reference in pairs(references) do
            if reference == plugin or (plugin_handle and
                safe(function() return HandleToInt(reference) end, nil) == plugin_handle) then return end
        end
        safe(function() Cmd('Assign Tag ' .. tag_index .. ' At ' .. plugin:ToAddr() .. ' /NoConfirmation') end, nil)
    end
end

local function bind_plugin_appearance()
    safe(function()
        local plugin = myHandle:Parent()
        local appearance = Root().ShowData.Appearances.HippoRemote_V4_130
        if plugin and appearance then plugin.Appearance = appearance end
    end, nil)
end

local function is_yes(value)
    local text = tostring(value or ""):lower()
    return text == "yes" or text == "true" or text == "1" or text == "on"
end

local function is_no(value)
    local text = tostring(value or ""):lower()
    return text == "no" or text == "false" or text == "0" or text == "off" or text == "disabled"
end

local function load_settings()
    local vars = UserVars()
    local port = tonumber(GetVar(vars, VAR.port) or "")
    osc.port = port and port >= 1 and port <= 65535 and math.floor(port) or DEF.port
    for _, key in ipairs({"shutdown_machine", "restart_machine", "shutdown_host"}) do
        local value = tostring(GetVar(vars, VAR[key]) or "")
        osc[key] = value:sub(1, 1) == "/" and value or DEF[key]
    end
end

local function local_output_station()
    -- InMySession is shared by every station in the session and cannot identify
    -- the physical station executing this plugin. HostSubType() is local to the
    -- running station, so match it against the live console network objects.
    local candidates = children(from("MAnetSocket.HostTypes.Console"))
    for _, station in ipairs(children(from("MAnetSocket.HostTypes.onPC"))) do candidates[#candidates+1]=station end
    local subtype = safe(function() return HostSubType() end, "")
    local function normalized(value)
        return tostring(value or ""):lower():gsub("[^%w]", "")
    end
    local matches = {}
    for _, station in pairs(candidates) do
        if normalized(prop(station, "Type")) == normalized(subtype) then
            matches[#matches + 1] = station
        end
    end

    -- Some station types can legitimately occur more than once. If MA exposes
    -- a local station name in this build, use it only as an exact tie-breaker.
    local variables = GlobalVars()
    for _, key in ipairs({"StationName", "HostName", "HOSTNAME"}) do
        local local_name = tostring(GetVar(variables, key) or "")
        if local_name ~= "" then
            for _, station in ipairs(matches) do
                if prop(station, "Name") == local_name then return station end
            end
        end
    end
    if #matches == 1 then return matches[1] end
    return nil
end

local function host_collection(name)
    local direct = from("MAnetSocket.HostTypes." .. name)
    if direct then return direct end
    local host_types = from("MAnetSocket.HostTypes")
    for _, collection in pairs(children(host_types)) do
        if prop(collection, "Name") == name then return collection end
    end
    return nil
end

local function active_session()
    local local_station = local_output_station()
    local local_ip = prop(local_station, "IP")
    if local_ip == "" then local_ip = prop(local_station, "Ip") end
    if local_station then
        return prop(local_station, "SessionIndex"), prop(local_station, "Session"), local_ip, local_station
    end
    local console_collection = host_collection("Console")
    for _, station in pairs(children(console_collection)) do
        local status = prop(station, "Status")
        if status == "GlobalMaster" then
            local ip = prop(station, "IP")
            if ip == "" then ip = prop(station, "Ip") end
            return prop(station, "SessionIndex"), prop(station, "Session"), local_ip, local_station
        end
    end
    return "", "", local_ip, local_station
end

local function connected_to_session(station, session_index, session_name)
    if not valid(station) then return false end
    if is_no(prop(station, "Enabled")) or is_no(prop(station, "InMySession")) then return false end
    local status = prop(station, "Status")
    if status ~= "Connected" and status ~= "GlobalMaster" and status ~= "IdleMaster" then return false end
    local index = prop(station, "SessionIndex")
    local name = prop(station, "Session")
    if index == "" or index == "None" then return false end
    if session_index ~= "" and index ~= session_index then return false end
    if session_name ~= "" and name ~= "" and name ~= session_name then return false end
    return true
end

local function visible_on_network(station)
    if not valid(station) or is_no(prop(station, "Enabled")) then return false end
    local status = prop(station, "Status")
    return status == "Connected" or status == "GlobalMaster" or status == "IdleMaster" or status == "Standalone"
end

local function target_from(station, membership)
    local ip = prop(station, "IP")
    if ip == "" then ip = prop(station, "Ip") end
    if ip == "" then return nil end
    return {
        handle = station,
        name = prop(station, "Name") ~= "" and prop(station, "Name") or "Unnamed Device",
        ip = ip,
        type = prop(station, "Type"),
        status = prop(station, "Status"),
        session = prop(station, "Session"),
        sessionIndex = prop(station, "SessionIndex"),
        membership = membership or "active"
    }
end

local function discover()
    local session_index, session_name, local_ip, local_station = active_session()
    local stations = children(host_collection("NetworkNode"))
    local result, seen = {}, {}
    for _, station in pairs(stations) do
        local station_type = prop(station, "Type")
        local include = station_type == "MediaServer"
        if include and visible_on_network(station) then
            local active = connected_to_session(station, session_index, session_name)
            local membership = active and "active" or "available"
            local target = target_from(station, membership)
            if target then
                target.isLocal = local_station ~= nil and tostring(station) == tostring(local_station)
                if not target.isLocal and local_ip ~= "" then target.isLocal = target.ip == local_ip end
            end
            local eligible = target and active
            if eligible and not seen[target.ip] then
                seen[target.ip] = true
                result[#result + 1] = target
            end
        end
    end
    table.sort(result, function(a, b)
        if a.membership ~= b.membership then return a.membership == "active" end
        if a.name:lower() == b.name:lower() then return a.ip < b.ip end
        return a.name:lower() < b.name:lower()
    end)
    return result, session_index, session_name
end

local function close_window()
    for _, object in ipairs({ui.screenChooser or false, ui.base or false}) do
        if object and valid(object) then
            safe(function() Obj.Delete(object:Parent(), Obj.Index(object)) end, nil)
        end
    end
    ui.base, ui.screenChooser = nil, nil
end

local function status(text)
    if valid(ui.status) then ui.status.Text = text end
end

local function chosen()
    local result = {}
    for name, entry in pairs(ui.controls) do
        if ui.selected[name] == 1 then result[#result + 1] = entry.target end
    end
    table.sort(result, function(a, b) return a.name:lower() < b.name:lower() end)
    return result
end

local function update_count()
    if valid(ui.selection) then ui.selection.Text = #chosen() .. " SELECTED" end
end

local function osc_pad(value)
    local amount = 4 - (#value % 4)
    if amount == 0 then amount = 4 end
    return value .. string.rep("\0", amount)
end

local function osc_packet(path, value)
    return osc_pad(path) .. osc_pad(",i") .. string.pack(">i4", value)
end

local function send_osc(action, targets)
    local available, socket = pcall(require, "socket")
    if not available or type(socket) ~= "table" then return false, "LuaSocket unavailable" end
    local udp, error_text = socket.udp()
    if not udp then return false, error_text end
    local failures, triggered = {}, {}
    local ran, detail = pcall(function()
        udp:settimeout(0)
        local trigger_on = osc_packet(osc[action.key], 1)
        local trigger_off = osc_packet(osc[action.key], 0)
        for _, target in ipairs(targets) do
            local sent, err = udp:sendto(trigger_on, target.ip, osc.port)
            if sent then triggered[#triggered+1] = target
            else failures[#failures+1] = target.name .. ": " .. tostring(err) end
        end
        if #triggered > 0 then coroutine.yield(0.20) end
        -- Always reset hosts whose trigger was sent, even if another host failed.
        for _, target in ipairs(triggered) do
            local sent, err = udp:sendto(trigger_off, target.ip, osc.port)
            if not sent then failures[#failures+1] = target.name .. " reset: " .. tostring(err) end
        end
    end)
    udp:close()
    if not ran then failures[#failures+1] = tostring(detail) end
    if #failures > 0 then return false, table.concat(failures,"; ") end
    return true
end

local HIPPO = {
    {key="shutdown_machine", label="SHUTDOWN MACHINE", text="SHUTDOWN MACHINE\nPower off Windows", warning="Powers off Windows and the selected Hippotizer."},
    {key="restart_machine", label="RESTART MACHINE", text="RESTART MACHINE\nFull computer reboot", warning="Restarts the selected Hippotizer computer."},
    {key="shutdown_host", label="STOP ENGINE HOST", text="STOP ENGINE HOST\nSoftware only", warning="Stops Engine Host without shutting down Windows."}
}
local function button(parent, column, row, name, text, clicked, color)
    local control = parent:Append("Button")
    control.Name = name
    control.Text = text
    control.Anchors = {left=column, right=column, top=row, bottom=row}
    control.Font = "Regular18"
    control.TextalignmentH = "Centre"
    control.HasHover = "Yes"
    control.PluginComponent = myHandle
    control.Clicked = clicked
    if color then control.BackColor = color end
    return control
end

-- Draw the action color as a restrained two-pixel frame instead of a solid fill.
-- The inset button keeps the controls distinct from the connected-device list.
local function outlined_button(parent, column, row, name, text, clicked, outline, face)
    local border = parent:Append("UIObject")
    border.Name = name .. "Border"
    border.Anchors = {left=column, right=column, top=row, bottom=row}
    border.Margin = {left=5,right=5,top=5,bottom=5}
    border.BackColor = outline

    local control = button(parent, column, row, name, text, clicked, face)
    control.Margin = {left=7,right=7,top=7,bottom=7}
    return control
end

-- Visual arrangement follows MA's Edit Display Preference panel.
local function display_icon(control)
    control.Text='▣'
    if type(FindTexture)=='function' then
        for _,name in ipairs({'display','screen','monitor','object_display'}) do
            local ok,texture=pcall(FindTexture,name)
            if ok and texture then control.Icon=name;control.Text='';break end
        end
    end
end
local function display_preference(overlay,display,moveCallback,cancelCallback,available)
    local theme=Root().ColorTheme.ColorGroups
    local chooser=overlay:Append('BaseInput')
    chooser.Name='EditDisplayPreference';chooser.W=600;chooser.H=660
    chooser.MaxSize=string.format('%s,%s',display.W*.94,display.H*.94)
    chooser.Columns,chooser.Rows=1,2;chooser.AutoClose='No';chooser.CloseOnEscape='Yes'
    chooser[1][1].SizePolicy='Fixed';chooser[1][1].Size='54';chooser[1][2].SizePolicy='Stretch'
    local top=chooser:Append('TitleBar');top.Anchors='0,0';top.Columns,top.Rows=3,1
    top[2][2].SizePolicy='Fixed';top[2][2].Size='105'
    top[2][3].SizePolicy='Fixed';top[2][3].Size='54'
    local caption=top:Append('TitleButton');caption.Anchors='0,0';caption.Text='Edit Display Preference';caption.Texture='corner1'
    button(top,1,0,'CancelMove','Clear',cancelCallback)
    local x=top:Append('CloseButton');x.Anchors='2,0';x.Texture='corner2'
    x.PluginComponent=myHandle;x.Clicked=cancelCallback
    local grid=chooser:Append('UILayoutGrid');grid.Anchors='0,1';grid.Columns,grid.Rows=3,3
    grid.Margin={left=8,right=8,top=6,bottom=8}
    local cells={{5,0,0,'External 5'},{4,2,0,'External 4'},{3,0,1,'Internal 3'},
        {2,1,1,'Internal 2'},{1,2,1,'Internal 1'},{7,1,2,'Small 7'},{6,2,2,'Small 6'}}
    for _,cell in ipairs(cells) do
        local index,col,row,label=table.unpack(cell)
        local b=button(grid,col,row,'Display'..index,label,moveCallback,theme.Button.BackgroundNormal)
        b.Margin={left=3,right=3,top=3,bottom=3}
        b.Enabled=available(index) and 'Yes' or 'No'
        if index==Obj.Index(display) then
            b.State=1
            local ok,color=pcall(function()return theme.Button.TextPlease end)
            if ok and color then b.TextColor=color end
        end
    end
    return chooser
end

local build

local function settings()
    local result = MessageBox({
        title="HIPPO REMOTE | PREFERENCES",
        message="Device addresses always come from the active MA session. Configure only the Hippo OSC port and action paths.",
        commands={{value=1,name="SAVE OSC"},{value=5,name="RESTORE OSC DEFAULTS"},{value=0,name="CANCEL"}},
        inputs={{name="UDP Port",value=tostring(osc.port),whiteFilter="0123456789"},{name="Shutdown Machine",value=osc.shutdown_machine},{name="Restart Machine",value=osc.restart_machine},{name="Stop Engine Host",value=osc.shutdown_host}}
    })
    if not result or not result.success or result.result == 0 then return end
    if result.result == 5 then
        for key, value in pairs(DEF) do SetVar(UserVars(), VAR[key], tostring(value)) end
        load_settings()
        status("Hippo OSC defaults restored.")
        return
    end
    if result.result == 1 then
        if type(result.inputs) ~= "table" then return end
        local port = tonumber(result.inputs["UDP Port"] or "")
        if not port or port < 1 or port > 65535 or port ~= math.floor(port) then status("UDP port must be 1-65535."); return end
        local labels = {shutdown_machine="Shutdown Machine", restart_machine="Restart Machine", shutdown_host="Stop Engine Host"}
        for key, label in pairs(labels) do
            local value = result.inputs[label] or ""
            if value:sub(1,1) ~= "/" or #value < 2 or value:find("[%s%c]") then status("OSC paths must begin with / and contain no spaces or control characters."); return end
        end
        for key, label in pairs(labels) do SetVar(UserVars(), VAR[key], result.inputs[label]) end
        SetVar(UserVars(), VAR.port, tostring(math.floor(port)))
        load_settings()
        status("OSC settings saved.")
    end
end

build = function(display, preserve_selection)
    local retained = {}
    if preserve_selection then for _, target in ipairs(chosen()) do retained[target.ip] = true end end
    close_window()
    display = display or GetFocusDisplay() or GetDisplayByIndex(1)
    ui.display = display
    ui.overlay = display.ScreenOverlay
    local session_index, session_name
    ui.targets, session_index, session_name = discover()
    ui.controls, ui.selected, ui.pending, ui.pendingTargets = {}, {}, nil, nil

    local theme = Root().ColorTheme.ColorGroups
    local accent = theme.Button.BackgroundPlease
    local danger = theme.Button.BackgroundDelete
    local normal = theme.Button.BackgroundNormal
    local warning = safe(function() return theme.Button.BackgroundWarning end, accent)
    local local_text = safe(function() return theme.Button.TextPlease end, nil)
    local transparent = theme.Global.Transparent
    local actions = HIPPO
    ui.actions = actions
    local rows = math.max(1, #ui.targets + 1)
    local action_columns = 3
    local action_rows = math.ceil(#actions / action_columns)
    local row_height, action_height = 44, 64
    local base = ui.overlay:Append("BaseInput")
    ui.base = base
    base.Name = "HippoRemoteWindow"
    base.W = math.min(940, display.W * .94)
    base.H = math.min(920, display.H * .94, 312 + rows * row_height + action_rows * action_height)
    base.MinSize = "780,500"
    base.MaxSize = string.format("%s,%s", display.W * .95, display.H * .95)
    base.Columns, base.Rows = 1, 2
    base[1][1].SizePolicy, base[1][1].Size = "Fixed", "64"
    base.AutoClose, base.CloseOnEscape = "No", "Yes"

    local title = base:Append("TitleBar")
    title.Columns, title.Rows, title.Anchors = 3, 1, "0,0"
    title[2][2].SizePolicy, title[2][2].Size = "Fixed", "58"
    title[2][3].SizePolicy, title[2][3].Size = "Fixed", "58"
    title.Texture = "corner2"
    local brand = title:Append("TitleButton")
    brand.Anchors, brand.Text, brand.Texture, brand.Icon = "0,0", "HIPPO REMOTE  •  v" .. VERSION, "corner1", "network"
    brand.Font = "Regular20"
    display_icon(button(title,1,0,"MoveScreen","","HRMove"))
    local close = title:Append("CloseButton")
    close.Anchors, close.Texture = "2,0", "corner2"
    close.PluginComponent, close.Clicked = myHandle, "HRClose"

    local frame = base:Append("DialogFrame")
    frame.Anchors = {left=0,right=0,top=1,bottom=1}
    frame.Columns, frame.Rows = 1, 6
    for index, size in ipairs({50,54,rows*row_height+10,18,action_rows*action_height+14,52}) do
        safe(function() frame[1][index].SizePolicy="Fixed"; frame[1][index].Size=tostring(size) end, nil)
    end

    frame[1][3].SizePolicy = "Stretch"

    local heading = frame:Append("UIObject")
    heading.Name, heading.Text = "HippoHeading", "HIPPO SERVERS"
    heading.Anchors = {left=0,right=0,top=0,bottom=0}
    heading.Margin = {left=16,right=16,top=4,bottom=4}
    heading.Font, heading.BackColor, heading.TextalignmentH = "Regular18", accent, "Centre"

    local status_object = frame:Append("UIObject")
    ui.status = status_object
    status_object.Anchors = {left=0,right=0,top=1,bottom=1}
    status_object.Padding = {left=18,right=18,top=8,bottom=4}
    status_object.Font, status_object.BackColor = "Regular18", transparent
    local session_text = session_name ~= "" and session_name or (session_index ~= "" and ("Session "..session_index) or "active session")
    status_object.Text = #ui.targets > 0 and (#ui.targets .. " CONNECTED IN " .. session_text .. "  •  Select targets, then choose an action.") or ("NO MATCHING DEVICES IN " .. session_text .. "  •  Confirm device type and session membership, then Refresh.")

    local list_panel = frame:Append("UILayoutGrid")
    list_panel.Anchors, list_panel.Columns, list_panel.Rows = "0,2", 2, 1
    list_panel[2][2].SizePolicy, list_panel[2][2].Size = "Fixed", "18"
    local scroll = list_panel:Append("ScrollBox")
    scroll.Name, scroll.Anchors = "HippoRemoteScroll", "0,0"
    local bar = list_panel:Append("ScrollBarV")
    bar.Anchors, bar.ScrollTarget = "1,0", scroll
    local list = scroll:Append("UILayoutGrid")
    list.W, list.H, list.Columns, list.Rows = "100%", rows*row_height+10, 1, rows
    list.Margin = {left=18,right=18,top=4,bottom=6}
    for row=1,rows do safe(function() list[1][row].SizePolicy="Fixed"; list[1][row].Size=tostring(row_height) end, nil) end
    local tools = list:Append("UILayoutGrid")
    tools.Anchors, tools.Columns, tools.Rows = {left=0,right=0,top=0,bottom=0}, 3, 1
    button(tools,0,0,"SelectAll","SELECT ALL","HRAll",accent)
    button(tools,1,0,"ClearAll","CLEAR SELECTION","HRClear")
    local online = tools:Append("UIObject")
    online.Anchors, online.Text, online.TextalignmentH, online.BackColor = {left=2,right=2,top=0,bottom=0}, #ui.targets .. " ONLINE", "Centre", transparent
    local row_index = 1
    for index, target in ipairs(ui.targets) do
        -- Two-pixel frame, with an inset grey face like the action buttons.
        local border = list:Append("UIObject")
        border.Name = "DeviceBorder" .. index
        border.Anchors = {left=0,right=0,top=row_index,bottom=row_index}
        border.Margin = {left=2,right=2,top=2,bottom=2}
        border.BackColor = target.membership == "active" and accent
            or (safe(function() return theme.Button.TextDisabled end, nil) or theme.Global.Text)
        local checkbox = list:Append("CheckBox")
        checkbox.Name = "Device" .. index
        checkbox.Text = target.name .. "   |   " .. target.ip .. "   |   " .. target.status .. (target.isLocal and "   |   MY STATION" or "")
        checkbox.Anchors = {left=0,right=0,top=row_index,bottom=row_index}
        checkbox.State, checkbox.Font, checkbox.TextalignmentH = retained[target.ip] and 1 or 0, "Regular18", "Left"
        checkbox.TextAutoAdjust, checkbox.ColorIndicator = "No", accent
        if target.isLocal and local_text then checkbox.TextColor = local_text end
        checkbox.PluginComponent, checkbox.Clicked = myHandle, "HRDevice"
        checkbox.BackColor = normal
        checkbox.Margin = {left=4,right=4,top=4,bottom=4}
        ui.controls[checkbox.Name] = {control=checkbox,target=target}
        ui.selected[checkbox.Name] = retained[target.ip] and 1 or 0
        row_index = row_index + 1
    end

    local separator = frame:Append("UIObject")
    separator.Anchors = {left=0,right=0,top=3,bottom=3}
    separator.Margin = {left=18,right=18,top=8,bottom=8}
    separator.BackColor = normal

    local action_grid = frame:Append("UILayoutGrid")
    action_grid.Anchors, action_grid.Columns, action_grid.Rows = {left=0,right=0,top=4,bottom=4}, action_columns, action_rows
    action_grid.Margin = {left=13,right=13,top=2,bottom=6}
    for row=1,action_rows do safe(function() action_grid[1][row].SizePolicy="Fixed"; action_grid[1][row].Size=tostring(action_height) end, nil) end
    for index, action in ipairs(actions) do
        local color = (action.key=="shutdown" or action.key=="shutdown_machine" or action.key=="dismiss") and danger
            or (action.key=="restart" or action.key=="restart_machine" or action.key=="reboot") and warning
            or accent
        outlined_button(action_grid,(index-1)%action_columns,math.floor((index-1)/action_columns),"Action"..index,action.text,"HRAction",color,normal)
    end

    local footer = frame:Append("UILayoutGrid")
    footer.Anchors, footer.Columns, footer.Rows = {left=0,right=0,top=5,bottom=5}, 4, 1
    footer.Margin = {left=18,right=18,top=3,bottom=6}
    ui.refresh = button(footer,0,0,"Refresh","REFRESH DEVICES","HRRefresh")
    ui.selection = footer:Append("UIObject")
    ui.selection.Anchors, ui.selection.Text, ui.selection.TextalignmentH, ui.selection.BackColor = {left=1,right=1,top=0,bottom=0}, "0 SELECTED", "Centre", transparent
    ui.settings = button(footer,2,0,"Settings","PREFERENCES","HRSettings")
    ui.closeButton = button(footer,3,0,"Close","CLOSE","HRClose")
    ui.confirm = button(footer,0,0,"Confirm","CONFIRM COMMAND","HRConfirm",accent)
    ui.confirm.Anchors, ui.confirm.Visible = {left=0,right=2,top=0,bottom=0}, "No"
    ui.cancel = button(footer,3,0,"Cancel","CANCEL","HRCancel")
    ui.cancel.Visible = "No"
    update_count()
end

signalTable.HRDevice = function(control)
    if ui.busy then return end
    if ui.pending then signalTable.HRCancel() end
    local state = ui.selected[control.Name] == 1 and 0 or 1
    ui.selected[control.Name], control.State = state, state
    update_count()
end
signalTable.HRAll = function()
    if ui.busy then return end
    if ui.pending then signalTable.HRCancel() end
    for name, entry in pairs(ui.controls) do ui.selected[name], entry.control.State = 1, 1 end
    update_count()
end
signalTable.HRClear = function()
    if ui.busy then return end
    if ui.pending then signalTable.HRCancel() end
    for name, entry in pairs(ui.controls) do ui.selected[name], entry.control.State = 0, 0 end
    update_count()
    status(#ui.targets .. " connected devices. Select targets and choose a command.")
end
signalTable.HRAction = function(control)
    if ui.busy then return end
    local action = ui.actions[tonumber(control.Name:match("%d+"))]
    if not action then return end
    if ui.pending then signalTable.HRCancel() end
    local selected, targets = chosen(), {}
    for _, target in ipairs(selected) do
        if target.membership == "active" then targets[#targets + 1] = target end
    end
    if #targets == 0 then status("SELECT TARGETS FIRST  •  No command has been armed."); return end
    ui.pending = action
    ui.pendingTargets = targets
    local names = {}
    for _, target in ipairs(targets) do names[#names + 1] = target.name .. " (" .. target.ip .. ")" end
    status("ARMED: " .. action.label .. "  •  " .. action.warning .. "  •  " .. table.concat(names, ", "))
    ui.refresh.Visible, ui.selection.Visible, ui.settings.Visible, ui.closeButton.Visible = "No", "No", "No", "No"
    ui.confirm.Visible, ui.confirm.State, ui.cancel.Visible = "Yes", 1, "Yes"
end
signalTable.HRCancel = function()
    if ui.busy then return end
    ui.pending, ui.pendingTargets = nil, nil
    ui.confirm.Visible, ui.confirm.State, ui.cancel.Visible = "No", 0, "No"
    ui.refresh.Visible, ui.selection.Visible, ui.settings.Visible, ui.closeButton.Visible = "Yes", "Yes", "Yes", "Yes"
    status("Command canceled. Select targets and choose another command.")
end
signalTable.HRConfirm = function()
    if ui.busy then return end
    local action, targets = ui.pending, ui.pendingTargets or {}
    if not action or #targets == 0 then signalTable.HRCancel(); return end
    local online = {}
    for _, target in ipairs(discover()) do online[target.ip] = target end
    for _, target in ipairs(targets) do
        local live = online[target.ip]
        if not live or live.membership ~= target.membership or live.name ~= target.name then
            signalTable.HRCancel()
            status("TARGET CHANGED  |  Refresh, select targets, and confirm again.")
            return
        end
        target.isLocal, target.handle = live.isLocal, live.handle
    end
    ui.busy = true
    ui.confirm.Enabled, ui.cancel.Enabled = "No", "No"
    local ran, ok, error_text = pcall(send_osc, action, targets)
    ui.busy = false
    if valid(ui.confirm) then ui.confirm.Enabled = "Yes" end
    if valid(ui.cancel) then ui.cancel.Enabled = "Yes" end
    if not ran then error_text, ok = tostring(ok), false end
    if ok then
        ui.pending, ui.pendingTargets = nil, nil
        status("OSC sent to " .. #targets .. " server(s); execution is not acknowledged by UDP.")
        coroutine.yield(.25)
        close_window()
    else
        if valid(ui.base) then signalTable.HRCancel() end
        status("COMMAND FAILED  •  " .. tostring(error_text))
    end
end
signalTable.HRRefresh = function() if not ui.busy then build(ui.display) end end
signalTable.HRSettings = function() if not ui.busy then if ui.pending then signalTable.HRCancel() end;settings() end end
signalTable.HRClose = function() if not ui.busy then close_window() end end

local function available_display(index)
    local display = safe(function() return GetDisplayByIndex(index) end, nil)
    if not display or not valid(safe(function() return display.ScreenOverlay end, nil)) then return nil end
    if (tonumber(display.W) or 0) <= 0 or (tonumber(display.H) or 0) <= 0 then return nil end
    return display
end

signalTable.HRMove = function()
    if ui.busy or valid(ui.screenChooser) then return end
    ui.screenChooser = display_preference(ui.overlay,ui.display,"HRDisplay","HRCancelMove",available_display)
end
signalTable.HRCancelMove = function()
    if valid(ui.screenChooser) then Obj.Delete(ui.screenChooser:Parent(),Obj.Index(ui.screenChooser)) end
    ui.screenChooser = nil
end
signalTable.HRDisplay = function(control)
    if ui.busy then return end
    local index = tonumber(control.Name:match("Display(%d+)"))
    local display = index and available_display(index)
    if not display then return end
    signalTable.HRCancelMove()
    if display ~= ui.display then
        local was_pending = ui.pending ~= nil
        build(display,true)
        status("MOVED TO DISPLAY "..index..(was_pending and "  |  Targets retained; choose and confirm the command again." or "  |  Target selection retained."))
    end
end

local function main(display)
    if ui.busy then return end
    ensure_utility_tag()
    bind_plugin_appearance()
    load_settings()
    Printf("%s v%s by %s", NAME, VERSION, AUTHOR)
    build(display)
end

return main
