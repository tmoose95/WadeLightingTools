local PLUGIN = "Cue Beacon"
local PREF = PluginVars(PLUGIN)
local VAR_TRIGGER = "CueBeaconTrigger"
local ACTIVE = {}
local TIMER_STARTED = {}

local function mapval(id, field)
    return GetVar(PREF, "Map_"..id.."_"..field)
end

local function target(id)
    local p = tonumber(mapval(id,"Page") or 0)
    local e = tonumber(mapval(id,"Exec") or 0)
    if p == 0 or e == 0 then return nil, nil, nil end
    local list = ObjectList(string.format("Page %d.%d", p, e))
    return p, e, list and list[1] or nil
end

local function assign_app(page, exec, appearance)
    local result = Cmd(string.format('Assign Appearance %s At Page %d.%d', appearance, page, exec))
    return result == "Ok" or result == "OK" or result == nil
end

local function restore(id)
    local page, exec = target(id)
    if not page then return end
    local original = tostring(mapval(id,"OriginalAppearance") or "")
    if original ~= "" and original ~= "nil" then
        Cmd(string.format('Assign %s At Page %d.%d', original, page, exec))
    else
        Cmd(string.format('Assign Off Appearance At Page %d.%d', page, exec))
    end
end

local function pulse_tick(id)
    if not ACTIVE[id] then return end
    local page, exec, ex = target(id)
    if not page or not ex then
        ACTIVE[id] = false
        return
    end
    local phase = tonumber(GetVar(PREF, "PulsePhase_"..id) or 0) or 0
    if phase == 0 then
        assign_app(page, exec, '9997')
        SetVar(PREF, "PulsePhase_"..id, 1)
    else
        assign_app(page, exec, '9998')
        SetVar(PREF, "PulsePhase_"..id, 0)
    end
end

local function ensure_timer(id)
    if TIMER_STARTED[id] then return end
    TIMER_STARTED[id] = true
    Timer(function()
        pulse_tick(id)
    end, 0.35, 100000, function()
        TIMER_STARTED[id] = nil
    end)
end

return function()
    local trig = GetVar(UserVars(), VAR_TRIGGER)
    if trig == nil then return end
    local id, action = tostring(trig):match("^([^:]+):([^:]+)$")
    if not id then return end
    if action == "START" then
        ACTIVE[id] = true
        SetVar(PREF, "PulsePhase_"..id, 0)
        pulse_tick(id)
        ensure_timer(id)
    elseif action == "STOP" then
        ACTIVE[id] = false
        restore(id)
    end
end
