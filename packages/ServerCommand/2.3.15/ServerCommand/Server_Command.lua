-- Server Command v2.3.15 | Aaron Wade - Crossfade Design | grandMA3 2.5.1
local NAME, VERSION, AUTHOR = "Server Command", "2.3.15", "Aaron Wade"
local _, _, signalTable, myHandle = ...

local DEF = {
    port = 7000,
    shutdown_machine = "/hippo/shutdown/machine",
    restart_machine = "/hippo/restart/machine",
    shutdown_host = "/hippo/shutdown/host"
}
local VAR = {
    port = "ServerCommandOscPort",
    shutdown_machine = "ServerCommandOscShutdown",
    restart_machine = "ServerCommandOscRestart",
    shutdown_host = "ServerCommandOscHost"
}
local osc = {}
local ui = {tab = "hippo", targets = {}, controls = {}, selected = {}, actions = {}, pending = nil, pendingTargets = nil}

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

local function command_ok(feedback)
    return tostring(feedback or ""):match("^%s*[Oo][Kk]%s*[:%s]*$") ~= nil
end

local function children(handle)
    local result = safe(function() return handle:Children() end, {})
    return type(result) == "table" and result or {}
end

local function from(address)
    return safe(function() return FromAddr(address) end, nil)
end

local function quote(value)
    return '"' .. tostring(value):gsub('"', '\\"') .. '"'
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
        local appearance = Root().ShowData.Appearances.ServerCommand
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
    local tab = tostring(GetVar(vars, "ServerCommandStartTab") or "hippo")
    ui.tab = (tab == "console" or tab == "node") and tab or "hippo"
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
    if is_no(prop(station, "Enabled")) then return false end
    local status = prop(station, "Status")
    if status ~= "Connected" and status ~= "GlobalMaster" and status ~= "IdleMaster" then return false end
    local index = prop(station, "SessionIndex")
    local name = prop(station, "Session")
    if index == "" or index == "None" then return false end
    if session_index ~= "" and index ~= session_index then return false end
    if session_name ~= "" and name ~= "" and name ~= session_name then return false end
    return true
end

local function same_subnet(a, b)
    local a1, a2, a3 = tostring(a or ""):match("^(%d+)%.(%d+)%.(%d+)%.%d+$")
    local b1, b2, b3 = tostring(b or ""):match("^(%d+)%.(%d+)%.(%d+)%.%d+$")
    return a1 ~= nil and a1 == b1 and a2 == b2 and a3 == b3
end

local function visible_on_network(station)
    if not valid(station) or is_no(prop(station, "Enabled")) then return false end
    local status = prop(station, "Status")
    return status == "Connected" or status == "GlobalMaster" or status == "IdleMaster" or status == "Standalone"
end

local function target_from(station, kind, membership)
    local ip = prop(station, "IP")
    if ip == "" then ip = prop(station, "Ip") end
    if ip == "" then return nil end
    local command_index = tonumber(safe(function() return station:CmdlineIndex() end, nil))
    if not command_index or command_index < 1 or command_index ~= math.floor(command_index) then command_index = nil end
    return {
        handle = station,
        name = prop(station, "Name") ~= "" and prop(station, "Name") or "Unnamed Device",
        ip = ip,
        type = prop(station, "Type"),
        status = prop(station, "Status"),
        session = prop(station, "Session"),
        sessionIndex = prop(station, "SessionIndex"),
        kind = kind,
        commandType = safe(function() return prop(station:Parent(), "Name") end, "") == "onPC" and "onPC" or (kind == "console" and "Console" or "NetworkNode"),
        number = command_index,
        membership = membership or "active"
    }
end

local function discover(kind)
    local session_index, session_name, local_ip, local_station = active_session()
    local collection_name = kind == "console" and "Console" or "NetworkNode"
    local stations = children(host_collection(collection_name))
    if kind == "console" then for _, station in ipairs(children(host_collection("onPC"))) do stations[#stations+1]=station end end
    local result, seen = {}, {}
    for _, station in pairs(stations) do
        local station_type = prop(station, "Type")
        local include = kind == "console"
            or (kind == "hippo" and station_type == "MediaServer")
            or (kind == "node" and station_type ~= "MediaServer")
        if include and visible_on_network(station) then
            local active = connected_to_session(station, session_index, session_name)
            local membership = active and "active" or "available"
            local target = target_from(station, kind, membership)
            if target then
                target.isLocal = local_station ~= nil and tostring(station) == tostring(local_station)
                if not target.isLocal and local_ip ~= "" then target.isLocal = target.ip == local_ip end
            end
            local eligible = target and (active or (kind ~= "hippo" and same_subnet(target.ip, local_ip)))
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

local function native_command(action, target)
    if action.key == "invite" then return "Invite IP " .. target.ip end
    if action.key == "restart" then return "Restart IP " .. target.ip .. " /NoConfirmation" end
    if action.key == "reboot" then return "Reboot IP " .. target.ip .. " /NoConfirmation" end
    if action.key == "shutdown" then return "ShutDown IP " .. target.ip .. " /NoConfirmation" end
    if action.key == "disconnect" then return "Disconnect IP " .. target.ip end
    if action.key == "dismiss" then return "Dismiss IP " .. target.ip end
    if action.key == "speed" then return "NetworkSpeedTest " .. target.commandType .. " " .. (target.number and tostring(target.number) or quote(target.name)) end
end

local function remote_console_command(target, command)
    -- Commands that must execute in the target console's local station context
    -- (for example, writing to that console's own internal/USB drive) use
    -- RemoteCommand. For MY STATION, execute locally so Cmd() can return direct
    -- command feedback instead of routing a command back to ourselves.
    if target.isLocal then
        local feedback = safe(function() return Cmd(command) end, nil)
        if feedback == nil then return false, "Local command failed" end
        if not command_ok(feedback) then
            return false, tostring(feedback)
        end
        return true
    end
    local ok, result = pcall(RemoteCommand, target.ip, command)
    if not ok then return false, tostring(result) end
    if result ~= true and result ~= 1 then return false, "RemoteCommand was not accepted by " .. target.ip end
    return true
end

local function lock_remote_desk(target)
    return remote_console_command(target, 'Menu "DeskLock"')
end

local function save_show_on_console(target)
    return remote_console_command(target, "SaveShow If Drive 1")
end

-- The worker is part of this streamed plugin. A remote invocation uses a
-- private argument and returns before any UI, appearance or tag setup.
-- Only the worker on the selected station inspects that station's DriveCollect.
local EXTERNAL_WORKER_ARGUMENT = "__SC_EXTERNAL_SAVE"
local SAVE_REPLY_KEY = "__ServerCommandSaveReplies"
local SAVE_BUSY_KEY = "__ServerCommandExternalSaveBusy"
local SAVE_TIMEOUT = 120

local function clock_now()
    return tonumber(safe(function() return Time() end, nil)) or os.clock()
end

local function hex_encode(value)
    return (tostring(value or ""):gsub(".", function(c) return string.format("%02x", c:byte()) end))
end

local function hex_decode(value)
    return (tostring(value or ""):gsub("%x%x", function(pair) return string.char(tonumber(pair, 16)) end))
end

local function is_external_drive(drive)
    -- MA's documented enum spelling is "Removeable". Do not infer external
    -- media from the raw collection index: it can include virtual entries.
    local kind = prop(drive, "DriveType"):lower():gsub("[%s_-]", "")
    return kind == "removeable" or kind == "removable"
end

local function drive_number(drive)
    -- CmdlineIndex, NOT Index, matches the number accepted by If Drive.
    local number = tonumber(safe(function() return drive:CmdlineIndex() end, nil))
    if number and number > 1 and number == math.floor(number) then return number end
    return nil
end

local function wait_for_show_ready()
    local deadline = clock_now() + SAVE_TIMEOUT
    repeat
        local state = safe(function() return GetShowFileStatus() end, nil)
        if state == "ShowLoaded" or state == "ShowDownloaded" then return true end
        if state ~= "ShowSaving" then
            return false, "Show is not ready to save (" .. tostring(state or "status unavailable") .. ")."
        end
        if clock_now() >= deadline then return false, "Show save is still busy; remaining drives were not started." end
        coroutine.yield(0.10)
    until false
end

local function external_save_worker(progress)
    local result = {total=0, completed=0, failed=0, issues={}}
    local function issue(message)
        result.failed = result.failed + 1
        result.issues[#result.issues + 1] = message
        Printf("Server Command | EXTERNAL SAVE | %s", message)
    end
    local lock = _G[SAVE_BUSY_KEY]
    if type(lock) == "table" and clock_now() < (lock.expires or 0) then
        issue("Another Server Command external save is already running on this station.")
        return result
    end
    local mine = {expires=clock_now() + 2*SAVE_TIMEOUT + 30}
    _G[SAVE_BUSY_KEY] = mine
    local ok, worker_error = pcall(function()
        local collection = safe(function() return Root().Temp.DriveCollect end, nil)
        if not collection then issue("The station's drive list is unavailable."); return end
        local read_ok, list = pcall(function() return collection:Children() end)
        if not read_ok or type(list) ~= "table" then issue("The station's drive list could not be read."); return end
        local drives, seen = {}, {}
        for _, drive in pairs(list) do
            if valid(drive) and is_external_drive(drive) then
                local path = prop(drive, "Path")
                local identity = path ~= "" and path or tostring(drive)
                if not seen[identity] then
                    seen[identity] = true
                    drives[#drives + 1] = {handle=drive, path=path, name=prop(drive, "Name"), number=drive_number(drive)}
                end
            end
        end
        table.sort(drives, function(a,b) return (a.number or math.huge) < (b.number or math.huge) end)
        result.total = #drives
        if progress then progress(result.total) end
        if #drives == 0 then
            issue("No external drives recognized by grandMA3 on this station. No external copy was made.")
            return
        end
        Printf("Server Command | EXTERNAL SAVE | %d external drive(s) detected.", #drives)
        for index, entry in ipairs(drives) do
            mine.expires = clock_now() + 2*SAVE_TIMEOUT + 30
            local ready, reason = wait_for_show_ready()
            if not ready then issue(reason); return end
            -- Recheck the original handle and path after every wait. Unplugging
            -- a drive must not redirect its save to another device at that index.
            local drive = entry.handle
            local number = valid(drive) and is_external_drive(drive) and drive_number(drive) or nil
            local name = entry.name ~= "" and entry.name or "Unnamed external drive"
            if not number then
                issue(name .. ": drive removed or its command-line number could not be resolved.")
            elseif entry.path ~= "" and prop(drive, "Path") ~= entry.path then
                issue(name .. ": drive identity changed; skipped.")
            else
                local description = "Drive " .. number .. " (" .. name .. ")"
                Printf("Server Command | EXTERNAL SAVE | %d/%d: %s", index, #drives, description)
                local executed, feedback = pcall(Cmd, "SaveShow If Drive " .. number)
                if not executed or not command_ok(feedback) then
                    issue(description .. ": " .. tostring(feedback or "no command feedback"))
                else
                    -- Allow an asynchronous native save to enter ShowSaving,
                    -- then wait before starting the next drive's save.
                    coroutine.yield(0.10)
                    local finished, finish_error = wait_for_show_ready()
                    if not finished then issue(description .. ": " .. finish_error); return end
                    result.completed = result.completed + 1
                    Printf("Server Command | EXTERNAL SAVE | %s: save command completed.", description)
                end
            end
        end
    end)
    if _G[SAVE_BUSY_KEY] == mine then _G[SAVE_BUSY_KEY] = nil end
    if not ok then issue("External-save worker stopped: " .. tostring(worker_error)) end
    return result
end

local function send_save_reply(origin, token, station_ip, phase, result)
    -- Only fixed field names, numbers and hex-encoded text cross the Lua
    -- command boundary. No station/drive label is interpolated as Lua code.
    if origin == "" then return false end
    local detail = table.concat(result.issues or {}, " | "):sub(1, 900)
    local code = "local t=_G." .. SAVE_REPLY_KEY .. "; if t and t['" .. token .. "'] then t['" .. token .. "']['" .. station_ip .. "']={phase='" .. phase
        .. "',total=" .. (result.total or 0) .. ",completed=" .. (result.completed or 0)
        .. ",failed=" .. (result.failed or 0) .. ",detail='" .. hex_encode(detail) .. "'} end"
    local ok, accepted = pcall(RemoteCommand, origin, 'Lua "' .. code .. '"')
    return ok and (accepted == true or accepted == 1)
end

local function run_external_worker_argument(argument)
    local token, origin, station_ip = argument:match("^" .. EXTERNAL_WORKER_ARGUMENT .. "|([%w_]+)|([%d%.]*)|([%d%.]+)$")
    if not token then return false end
    local result = external_save_worker(function(total)
        send_save_reply(origin, token, station_ip, "running", {total=total})
    end)
    local delivered = send_save_reply(origin, token, station_ip, "done", result)
    Printf("Server Command | %s | External save commands completed: %d/%d; issues: %d.", station_ip, result.completed, result.total, result.failed)
    -- No extra confirmation or success pop-up. If a result cannot return to
    -- the caller, show problems on this station instead of silently losing them.
    if result.failed > 0 and not delivered then
        safe(function() MessageBox({title="SERVER COMMAND | EXTERNAL SAVE", message=table.concat(result.issues, "\n"), commands={{value=1,name="OK"}}}) end, nil)
    end
    return true
end

local function own_plugin_command()
    local plugin = safe(function() return myHandle:Parent() end, nil)
    local pool = safe(function() return plugin:Parent():Parent() end, nil)
    local plugin_index = tonumber(safe(function() return plugin:Index() end, nil))
    local pool_index = tonumber(safe(function() return pool:Index() end, nil))
    if not plugin_index or not pool_index or plugin_index < 1 or pool_index < 1 then return nil end
    -- Explicit DataPool prevents running an unrelated plugin when a remote
    -- operator has selected a different data pool.
    return "Go+ DataPool " .. pool_index .. " Plugin " .. plugin_index
end

local function save_to_all_external_drives(targets)
    local _, _, origin_ip = active_session()
    origin_ip = tostring(origin_ip or "")
    if not origin_ip:match("^%d+%.%d+%.%d+%.%d+$") then origin_ip = "" end
    local token = "SC_" .. tostring({}):gsub("[^%w]", "") .. "_" .. math.floor(clock_now() * 1000)
    local replies = _G[SAVE_REPLY_KEY]
    if type(replies) ~= "table" then replies = {}; _G[SAVE_REPLY_KEY] = replies end
    local results = {}
    replies[token] = results
    local waiting, problems, unverified = {}, {}, {}
    local completed, total = 0, 0
    local command = own_plugin_command()
    local ok, error_text = pcall(function()
        -- Dispatch remote stations first; their own workers enumerate and save
        -- their local media while this station handles its own selected drives.
        for _, target in ipairs(targets) do
            if not target.isLocal then
                if not command then
                    problems[#problems + 1] = target.name .. ": could not resolve this plugin's data-pool address."
                else
                    local argument = EXTERNAL_WORKER_ARGUMENT .. "|" .. token .. "|" .. origin_ip .. "|" .. target.ip
                    local sent, send_error = remote_console_command(target, command .. " " .. quote(argument))
                    if not sent then
                        problems[#problems + 1] = target.name .. ": " .. tostring(send_error)
                    elseif origin_ip == "" then
                        unverified[#unverified + 1] = target.name
                    else
                        waiting[#waiting + 1] = {target=target, deadline=clock_now()+20}
                    end
                end
            end
        end
        for _, target in ipairs(targets) do
            if target.isLocal then
                status("SAVING TO EXTERNAL DRIVES  |  " .. target.name)
                local result = external_save_worker()
                results[target.ip] = {phase="done",total=result.total,completed=result.completed,failed=result.failed,detail=hex_encode(table.concat(result.issues," | "))}
            end
        end
        while #waiting > 0 do
            for index=#waiting,1,-1 do
                local entry = waiting[index]
                local reply = results[entry.target.ip]
                if reply and reply.phase == "running" and not entry.started then
                    entry.started = true
                    entry.deadline = clock_now() + math.max(1,reply.total or 0) * (SAVE_TIMEOUT+1) + 30
                end
                if reply and reply.phase == "done" then
                    table.remove(waiting,index)
                elseif clock_now() >= entry.deadline then
                    problems[#problems + 1] = entry.target.name .. ": result not received. The request may still be running; check that station's System Monitor before retrying."
                    table.remove(waiting,index)
                end
            end
            if #waiting > 0 then
                status("SAVING TO EXTERNAL DRIVES  |  Waiting for " .. #waiting .. " console(s)...")
                coroutine.yield(0.10)
            end
        end
        for _, target in ipairs(targets) do
            local reply = results[target.ip]
            if reply and reply.phase == "done" then
                completed, total = completed + (reply.completed or 0), total + (reply.total or 0)
                Printf("Server Command | %s (%s) | External save commands completed: %d/%d; issues: %d.", target.name, target.ip, reply.completed or 0, reply.total or 0, reply.failed or 0)
                if (reply.failed or 0) > 0 then
                    local detail = hex_decode(reply.detail)
                    Printf("Server Command | %s | %s", target.name, detail)
                    problems[#problems + 1] = target.name .. ": " .. detail
                end
            end
        end
    end)
    replies[token] = nil
    if not ok then problems[#problems + 1] = "Save controller stopped: " .. tostring(error_text) end
    if #problems > 0 then return false, table.concat(problems,"\n") end
    if #unverified > 0 then
        local detail = "Requests sent to " .. table.concat(unverified,", ") .. ". This station's return IP could not be resolved; check those stations' System Monitor for results."
        Printf("Server Command | %s", detail)
        return true, detail, true
    end
    return true, "External save commands completed for " .. completed .. "/" .. total .. " drive(s) across " .. #targets .. " console(s)."
end


local HIPPO = {
    {key="shutdown_machine", label="SHUTDOWN MACHINE", text="SHUTDOWN MACHINE\nPower off Windows", warning="Powers off Windows and the selected Hippotizer."},
    {key="restart_machine", label="RESTART MACHINE", text="RESTART MACHINE\nFull computer reboot", warning="Restarts the selected Hippotizer computer."},
    {key="shutdown_host", label="STOP ENGINE HOST", text="STOP ENGINE HOST\nSoftware only", warning="Stops Engine Host without shutting down Windows."}
}
local NATIVE = {
    {key="restart", label="RESTART APPLICATION", text="RESTART APPLICATION\nSoftware only", warning="Restarts grandMA3 software only."},
    {key="reboot", label="REBOOT DEVICE", text="REBOOT DEVICE\nOperating system", warning="Reboots the complete device."},
    {key="shutdown", label="SHUT DOWN", text="SHUT DOWN\nPower off device", warning="Powers down the selected device."},
    {key="speed", label="NETWORK SPEED TEST", text="NETWORK SPEED TEST\nCheck connection", warning="Runs the native MA3 network speed test."},
    {key="disconnect", label="DISCONNECT", text="DISCONNECT\nKeep session identity", warning="Disconnects the selected device."},
    {key="dismiss", label="DISMISS FROM SESSION", text="DISMISS FROM SESSION\nRemove membership", warning="Removes the selected device from this session."}
}
local LOCK = {key="lock", label="LOCK DESK", text="LOCK DESK\nRemote screen lock", warning="Opens native Desk Lock on the selected console."}
local SAVE_SHOW = {key="save_show", label="SAVE SHOW", text="SAVE SHOW\nInternal drive", warning="Saves the current show using its existing name to Drive 1 (Internal) on each selected console."}
local SAVE_USB = {key="save_usb", label="SAVE TO EXTERNAL DRIVES", text="SAVE TO EXTERNAL DRIVES\nAll detected external drives", warning="Detects and saves to every grandMA3-recognized external drive on each selected console, using the current show name. grandMA3 also saves internally."}
local INVITE = {key="invite", label="INVITE TO SESSION", text="INVITE TO SESSION\nAvailable stations only", warning="Invites the selected available station into this MA session.", scope="available"}

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
        title="SERVER COMMAND | PREFERENCES",
        message="Device addresses always come from the active MA session. Configure only the Hippo OSC port and action paths.",
        commands={{value=1,name="SAVE OSC"},{value=2,name="START: HIPPO"},{value=3,name="START: CONSOLES"},{value=4,name="START: DMX NODES"},{value=5,name="RESTORE OSC DEFAULTS"},{value=0,name="CANCEL"}},
        inputs={{name="UDP Port",value=tostring(osc.port),whiteFilter="0123456789"},{name="Shutdown Machine",value=osc.shutdown_machine},{name="Restart Machine",value=osc.restart_machine},{name="Stop Engine Host",value=osc.shutdown_host}}
    })
    if not result or not result.success or result.result == 0 then return end
    if result.result >= 2 and result.result <= 4 then
        local tab = ({[2]="hippo", [3]="console", [4]="node"})[result.result]
        SetVar(UserVars(), "ServerCommandStartTab", tab)
        ui.tab = tab
        build(ui.display)
        return
    end
    if result.result == 5 then
        local current_tab = ui.tab
        for key, value in pairs(DEF) do SetVar(UserVars(), VAR[key], tostring(value)) end
        load_settings()
        ui.tab = current_tab
        status("Hippo OSC defaults restored.")
        return
    end
    if result.result == 1 then
        local port = tonumber(result.inputs["UDP Port"] or "")
        if not port or port < 1 or port > 65535 then status("UDP port must be 1-65535."); return end
        local labels = {shutdown_machine="Shutdown Machine", restart_machine="Restart Machine", shutdown_host="Stop Engine Host"}
        for key, label in pairs(labels) do
            local value = result.inputs[label] or ""
            if value:sub(1,1) ~= "/" or #value < 2 or value:find("[%s%c]") then status("OSC paths must begin with / and contain no spaces or control characters."); return end
        end
        for key, label in pairs(labels) do SetVar(UserVars(), VAR[key], result.inputs[label]) end
        SetVar(UserVars(), VAR.port, tostring(math.floor(port)))
        local current_tab = ui.tab
        load_settings()
        ui.tab = current_tab
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
    ui.targets, session_index, session_name = discover(ui.tab)
    ui.controls, ui.selected, ui.pending, ui.pendingTargets = {}, {}, nil, nil

    local theme = Root().ColorTheme.ColorGroups
    local accent = theme.Button.BackgroundPlease
    local danger = theme.Button.BackgroundDelete
    local normal = theme.Button.BackgroundNormal
    local warning = safe(function() return theme.Button.BackgroundWarning end, accent)
    local local_text = safe(function() return theme.Button.TextPlease end, nil)
    local transparent = theme.Global.Transparent
    local actions = {}
    for _, action in ipairs(ui.tab == "hippo" and HIPPO or NATIVE) do actions[#actions + 1] = action end
    if ui.tab == "console" then
        table.insert(actions, 1, SAVE_USB)
        table.insert(actions, 1, SAVE_SHOW)
        actions[#actions + 1] = LOCK
    end
    if ui.tab ~= "hippo" then table.insert(actions, 1, INVITE) end
    ui.actions = actions

    local active_count, available_count = 0, 0
    for _, target in ipairs(ui.targets) do
        if target.membership == "active" then active_count = active_count + 1 else available_count = available_count + 1 end
    end
    local section_rows = ui.tab == "hippo" and 0 or 2
    local rows = math.max(1, #ui.targets + 1 + section_rows)
    local action_columns = ui.tab == "hippo" and 3 or 2
    local action_rows = math.ceil(#actions / action_columns)
    local row_height, action_height = 44, 64
    local base = ui.overlay:Append("BaseInput")
    ui.base = base
    base.Name = "ServerCommandWindow"
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
    brand.Anchors, brand.Text, brand.Texture, brand.Icon = "0,0", "SERVER COMMAND  •  v" .. VERSION, "corner1", "network"
    brand.Font = "Regular20"
    display_icon(button(title,1,0,"MoveScreen","","SCMove"))
    local close = title:Append("CloseButton")
    close.Anchors, close.Texture = "2,0", "corner2"

    local frame = base:Append("DialogFrame")
    frame.Anchors = {left=0,right=0,top=1,bottom=1}
    frame.Columns, frame.Rows = 1, 6
    for index, size in ipairs({50,54,rows*row_height+10,18,action_rows*action_height+14,52}) do
        safe(function() frame[1][index].SizePolicy="Fixed"; frame[1][index].Size=tostring(size) end, nil)
    end

    frame[1][3].SizePolicy = "Stretch"

    local tabs = frame:Append("UILayoutGrid")
    tabs.Anchors, tabs.Columns, tabs.Rows = {left=0,right=0,top=0,bottom=0}, 3, 1
    tabs.Margin = {left=16,right=16,top=4,bottom=4}
    button(tabs,0,0,"TabHippo","HIPPO SERVERS","SCTab",ui.tab=="hippo" and accent)
    button(tabs,1,0,"TabConsole","CONSOLES","SCTab",ui.tab=="console" and accent)
    button(tabs,2,0,"TabNode","DMX NETWORK NODES","SCTab",ui.tab=="node" and accent)

    local status_object = frame:Append("UIObject")
    ui.status = status_object
    status_object.Anchors = {left=0,right=0,top=1,bottom=1}
    status_object.Padding = {left=18,right=18,top=8,bottom=4}
    status_object.Font, status_object.BackColor = "Regular18", transparent
    local session_text = session_name ~= "" and session_name or (session_index ~= "" and ("Session "..session_index) or "active session")
    if ui.tab == "hippo" then
        status_object.Text = #ui.targets > 0 and (#ui.targets .. " CONNECTED IN " .. session_text .. "  •  Select targets, then choose an action.") or ("NO MATCHING DEVICES IN " .. session_text .. "  •  Confirm device type and session membership, then Refresh.")
    else
        status_object.Text = active_count .. " ACTIVE  •  " .. available_count .. " AVAILABLE TO INVITE  •  " .. session_text
    end

    local list_panel = frame:Append("UILayoutGrid")
    list_panel.Anchors, list_panel.Columns, list_panel.Rows = "0,2", 2, 1
    list_panel[2][2].SizePolicy, list_panel[2][2].Size = "Fixed", "18"
    local scroll = list_panel:Append("ScrollBox")
    scroll.Name, scroll.Anchors = "ServerCommandScroll", "0,0"
    local bar = list_panel:Append("ScrollBarV")
    bar.Anchors, bar.ScrollTarget = "1,0", scroll
    local list = scroll:Append("UILayoutGrid")
    list.W, list.H, list.Columns, list.Rows = "100%", rows*row_height+10, 1, rows
    list.Margin = {left=18,right=18,top=4,bottom=6}
    for row=1,rows do safe(function() list[1][row].SizePolicy="Fixed"; list[1][row].Size=tostring(row_height) end, nil) end
    local tools = list:Append("UILayoutGrid")
    tools.Anchors, tools.Columns, tools.Rows = {left=0,right=0,top=0,bottom=0}, 3, 1
    button(tools,0,0,"SelectAll","SELECT ALL","SCAll",accent)
    button(tools,1,0,"ClearAll","CLEAR SELECTION","SCClear")
    local online = tools:Append("UIObject")
    online.Anchors, online.Text, online.TextalignmentH, online.BackColor = {left=2,right=2,top=0,bottom=0}, #ui.targets .. " ONLINE", "Centre", transparent
    local row_index = 1
    local function section(text, count, color)
        local header = list:Append("UIObject")
        header.Anchors = {left=0,right=0,top=row_index,bottom=row_index}
        header.Text, header.Font, header.TextalignmentH = text .. "  •  " .. count, "Regular18", "Left"
        header.Padding, header.BackColor = {left=14,right=12,top=6,bottom=4}, color
        row_index = row_index + 1
    end
    if ui.tab ~= "hippo" then section("ACTIVE SESSION MEMBERS", active_count, accent) end
    for index, target in ipairs(ui.targets) do
        if ui.tab ~= "hippo" and target.membership == "available" and index == active_count + 1 then
            section("AVAILABLE TO INVITE", available_count, transparent)
        end
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
        checkbox.PluginComponent, checkbox.Clicked = myHandle, "SCDevice"
        checkbox.BackColor = normal
        checkbox.Margin = {left=4,right=4,top=4,bottom=4}
        ui.controls[checkbox.Name] = {control=checkbox,target=target}
        ui.selected[checkbox.Name] = retained[target.ip] and 1 or 0
        row_index = row_index + 1
    end
    if ui.tab ~= "hippo" and available_count == 0 then section("AVAILABLE TO INVITE", 0, transparent) end

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
        outlined_button(action_grid,(index-1)%action_columns,math.floor((index-1)/action_columns),"Action"..index,action.text,"SCAction",color,normal)
    end

    local footer = frame:Append("UILayoutGrid")
    footer.Anchors, footer.Columns, footer.Rows = {left=0,right=0,top=5,bottom=5}, 4, 1
    footer.Margin = {left=18,right=18,top=3,bottom=6}
    ui.refresh = button(footer,0,0,"Refresh","REFRESH DEVICES","SCRefresh")
    ui.selection = footer:Append("UIObject")
    ui.selection.Anchors, ui.selection.Text, ui.selection.TextalignmentH, ui.selection.BackColor = {left=1,right=1,top=0,bottom=0}, "0 SELECTED", "Centre", transparent
    ui.settings = button(footer,2,0,"Settings","PREFERENCES","SCSettings")
    ui.closeButton = button(footer,3,0,"Close","CLOSE","SCClose")
    ui.confirm = button(footer,0,0,"Confirm","CONFIRM COMMAND","SCConfirm",accent)
    ui.confirm.Anchors, ui.confirm.Visible = {left=0,right=2,top=0,bottom=0}, "No"
    ui.cancel = button(footer,3,0,"Cancel","CANCEL","SCCancel")
    ui.cancel.Visible = "No"
    update_count()
end

signalTable.SCTab = function(control)
    if ui.busy then return end
    ui.tab = control.Name == "TabHippo" and "hippo" or control.Name == "TabConsole" and "console" or "node"
    build(ui.display)
end
signalTable.SCDevice = function(control)
    if ui.busy then return end
    if ui.pending then signalTable.SCCancel() end
    local state = ui.selected[control.Name] == 1 and 0 or 1
    ui.selected[control.Name], control.State = state, state
    update_count()
end
signalTable.SCAll = function()
    if ui.busy then return end
    if ui.pending then signalTable.SCCancel() end
    for name, entry in pairs(ui.controls) do ui.selected[name], entry.control.State = 1, 1 end
    update_count()
end
signalTable.SCClear = function()
    if ui.busy then return end
    if ui.pending then signalTable.SCCancel() end
    for name, entry in pairs(ui.controls) do ui.selected[name], entry.control.State = 0, 0 end
    update_count()
    status(#ui.targets .. " connected devices. Select targets and choose a command.")
end
signalTable.SCAction = function(control)
    if ui.busy then return end
    local action = ui.actions[tonumber(control.Name:match("%d+"))]
    if not action then return end
    if ui.pending then signalTable.SCCancel() end
    local selected, targets = chosen(), {}
    local required = action.key == "invite" and "available" or "active"
    for _, target in ipairs(selected) do
        if target.membership == required then targets[#targets + 1] = target end
    end
    if #selected == 0 then status("SELECT TARGETS FIRST  •  No command has been armed."); return end
    if #targets == 0 then
        status(action.key == "invite" and "INVITE REQUIRES AN AVAILABLE STATION  •  Select a row under Available to Invite." or "COMMAND REQUIRES AN ACTIVE MEMBER  •  Select a green session-member row.")
        return
    end
    if action.key == "speed" then
        local testable = {}
        for _, target in ipairs(targets) do
            if not target.isLocal then testable[#testable + 1] = target end
        end
        targets = testable
        if #targets == 0 then
            status("NETWORK SPEED TEST REQUIRES ANOTHER DEVICE  •  Select the other console or a network node; this console cannot test itself.")
            return
        end
    end
    ui.pending = action
    ui.pendingTargets = targets
    local names = {}
    for _, target in ipairs(targets) do names[#names + 1] = target.name .. " (" .. target.ip .. ")" end
    status("ARMED: " .. action.label .. "  •  " .. action.warning .. "  •  " .. table.concat(names, ", "))
    ui.refresh.Visible, ui.selection.Visible, ui.settings.Visible, ui.closeButton.Visible = "No", "No", "No", "No"
    ui.confirm.Visible, ui.confirm.State, ui.cancel.Visible = "Yes", 1, "Yes"
end
signalTable.SCCancel = function()
    if ui.busy then return end
    ui.pending, ui.pendingTargets = nil, nil
    ui.confirm.Visible, ui.confirm.State, ui.cancel.Visible = "No", 0, "No"
    ui.refresh.Visible, ui.selection.Visible, ui.settings.Visible, ui.closeButton.Visible = "Yes", "Yes", "Yes", "Yes"
    status("Command canceled. Select targets and choose another command.")
end
signalTable.SCConfirm = function()
    if ui.busy then return end
    local action, targets = ui.pending, ui.pendingTargets or {}
    if not action or #targets == 0 then signalTable.SCCancel(); return end
    local online = {}
    for _, target in ipairs(discover(ui.tab)) do online[target.ip] = target end
    for _, target in ipairs(targets) do
        local live = online[target.ip]
        if not live or live.membership ~= target.membership or live.name ~= target.name then
            signalTable.SCCancel()
            status("TARGET CHANGED  |  Refresh, select targets, and confirm again.")
            return
        end
        target.isLocal, target.handle, target.number, target.commandType = live.isLocal, live.handle, live.number, live.commandType
    end
    if action.key == "save_usb" then
        ui.busy = true
        ui.pending, ui.pendingTargets = nil, nil
        ui.confirm.Text, ui.confirm.Enabled, ui.cancel.Enabled = "SAVING...", "No", "No"
        local executed, saved, detail, unverified = pcall(save_to_all_external_drives, targets)
        ui.busy = false
        if valid(ui.confirm) then ui.confirm.Text, ui.confirm.Enabled = "CONFIRM COMMAND", "Yes" end
        if valid(ui.cancel) then ui.cancel.Enabled = "Yes" end
        if not executed then detail, saved = tostring(saved), false end
        if saved and not unverified then
            status(detail)
            coroutine.yield(.25)
            close_window()
        else
            if valid(ui.base) then signalTable.SCCancel() end
            status((saved and "RESULT NOT VERIFIED  |  " or "EXTERNAL SAVE INCOMPLETE  |  ") .. tostring(detail))
            safe(function() MessageBox({title=saved and "SERVER COMMAND | CHECK RESULTS" or "SERVER COMMAND | EXTERNAL SAVE INCOMPLETE",
                message=tostring(detail), commands={{value=1,name="OK"}}}) end, nil)
        end
        return
    end
    ui.busy = true
    ui.confirm.Enabled, ui.cancel.Enabled = "No", "No"
    local ran, ok, error_text = pcall(function()
        if ui.tab == "hippo" then return send_osc(action, targets) end
        -- If an operation terminates this station, dispatch the other stations
        -- first so they still receive the command before the caller exits.
        table.sort(targets, function(a,b)
            if a.isLocal ~= b.isLocal then return not a.isLocal end
            return a.ip < b.ip
        end)
        for _, target in ipairs(targets) do
            local accepted, detail = true, nil
            if action.key == "lock" then
                accepted, detail = lock_remote_desk(target)
            elseif action.key == "save_show" then
                accepted, detail = save_show_on_console(target)
            else
                local command = native_command(action, target)
                if not command then return false, "No command for " .. tostring(action.key) end
                if action.key == "speed" then
                    -- Native speed-test UI must run on MA's main task.
                    CmdIndirectWait(command, nil, ui.display)
                else
                    local feedback = Cmd(command)
                    accepted, detail = command_ok(feedback), tostring(feedback)
                end
            end
            if not accepted then return false, target.name .. ": " .. tostring(detail) end
        end
        return true
    end)
    ui.busy = false
    if valid(ui.confirm) then ui.confirm.Enabled = "Yes" end
    if valid(ui.cancel) then ui.cancel.Enabled = "Yes" end
    if not ran then error_text, ok = tostring(ok), false end
    if ok then
        ui.pending, ui.pendingTargets = nil, nil
        status(action.label .. " sent to " .. #targets .. " device(s).")
        coroutine.yield(.25)
        close_window()
    else
        if valid(ui.base) then signalTable.SCCancel() end
        status("COMMAND FAILED  •  " .. tostring(error_text))
    end
end
signalTable.SCRefresh = function() if not ui.busy then build(ui.display) end end
signalTable.SCSettings = function() if not ui.busy then if ui.pending then signalTable.SCCancel() end;settings() end end
signalTable.SCClose = function() if not ui.busy then close_window() end end

local function available_display(index)
    local display = safe(function() return GetDisplayByIndex(index) end, nil)
    if not display or not valid(safe(function() return display.ScreenOverlay end, nil)) then return nil end
    if (tonumber(display.W) or 0) <= 0 or (tonumber(display.H) or 0) <= 0 then return nil end
    return display
end

signalTable.SCMove = function()
    if ui.busy or valid(ui.screenChooser) then return end
    ui.screenChooser = display_preference(ui.overlay,ui.display,"SCDisplay","SCCancelMove",available_display)
end
signalTable.SCCancelMove = function()
    if valid(ui.screenChooser) then Obj.Delete(ui.screenChooser:Parent(),Obj.Index(ui.screenChooser)) end
    ui.screenChooser = nil
end
signalTable.SCDisplay = function(control)
    if ui.busy then return end
    local index = tonumber(control.Name:match("Display(%d+)"))
    local display = index and available_display(index)
    if not display then return end
    signalTable.SCCancelMove()
    if display ~= ui.display then
        local was_pending = ui.pending ~= nil
        build(display,true)
        status("MOVED TO DISPLAY "..index..(was_pending and "  |  Targets retained; choose and confirm the command again." or "  |  Target selection retained."))
    end
end

local function main(display, argument)
    if type(argument) == "string" and argument:sub(1,#EXTERNAL_WORKER_ARGUMENT) == EXTERNAL_WORKER_ARGUMENT then
        run_external_worker_argument(argument)
        return
    end
    if ui.busy then return end
    ensure_utility_tag()
    bind_plugin_appearance()
    load_settings()
    Printf("%s v%s by %s", NAME, VERSION, AUTHOR)
    build(display)
end

return main
