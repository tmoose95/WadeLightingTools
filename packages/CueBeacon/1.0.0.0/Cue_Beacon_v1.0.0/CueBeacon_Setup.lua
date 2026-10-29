local PLUGIN = "Cue Beacon"
local RUNTIME_COMPONENT = "Runtime"
local VAR_TRIGGER = "CueBeaconTrigger"
local PREF = PluginVars(PLUGIN)

local function safeget(h, p)
    if h == nil then return nil end
    local ok, v = pcall(function() return h:Get(p) end)
    if ok then return v end
    return nil
end

local function tostring_safe(v)
    if v == nil then return "" end
    return tostring(v)
end

local function cue_label(cue)
    local no = safeget(cue, "No") or safeget(cue, "Cue") or cue:CmdlineIndex()
    local name = safeget(cue, "Name") or ""
    if name ~= "" then return string.format("Cue %s — %s", tostring(no), tostring(name)) end
    return string.format("Cue %s", tostring(no))
end

local function append_command(cue, cmd)
    local old = safeget(cue, "Command") or ""
    old = tostring(old)
    if old:find("CueBeaconTrigger", 1, true) then
        return false, "This cue already contains a Cue Beacon command."
    end
    local newcmd = cmd
    if old ~= "" then newcmd = old .. "; " .. cmd end
    local ok, err = pcall(function() cue:Set("Command", newcmd) end)
    if not ok then return false, tostring(err) end
    return true
end

local function make_appearances()
    -- Reserved high appearance slots for this plugin. We intentionally use fixed slots
    -- so Runtime can operate without requiring the pool to be selected.
    Cmd('Store Appearance 9997 "Cue Beacon RED" /Overwrite')
    Cmd('Set Appearance 9997 Property "Color" "1.000000,0.000000,0.000000,1.000000" "BackR" "255" "BackG" "0" "BackB" "0" "BackAlpha" "255"')
    Cmd('Store Appearance 9998 "Cue Beacon DIM" /Overwrite')
    Cmd('Set Appearance 9998 Property "Color" "0.250000,0.000000,0.000000,1.000000" "BackR" "64" "BackG" "0" "BackB" "0" "BackAlpha" "255"')
end

return function()
    local seq = SelectedSequence()
    if seq == nil then
        MessageBox({title=PLUGIN, message="No selected sequence was found. Select a sequence, then run Cue Beacon again.", commands={{value=1,name="OK"}}})
        return
    end

    local children = seq:Children() or {}
    local cues, labels = {}, {}
    for _, child in ipairs(children) do
        local class = child:GetClass()
        if class == "Cue" or class == "CuePart" then
            -- CueParts are children of cues on normal sequence structures, so direct children
            -- that are Cue objects are what we want. Ignore cue parts defensively.
            if class == "Cue" then
                cues[#cues+1] = child
                labels[#labels+1] = cue_label(child)
            end
        end
    end
    if #cues == 0 then
        -- Fallback for versions where direct child class naming differs.
        for _, child in ipairs(children) do
            local no = safeget(child, "No")
            if no ~= nil then
                cues[#cues+1] = child
                labels[#labels+1] = cue_label(child)
            end
        end
    end
    if #cues == 0 then
        MessageBox({title=PLUGIN, message="The selected sequence contains no cues I can enumerate.", commands={{value=1,name="OK"}}})
        return
    end

    local stopValues = {"Next Cue"}
    for i=1,#labels do stopValues[#stopValues+1] = labels[i] end

    local seqName = safeget(seq, "Name") or "Selected Sequence"
    local seqNo = safeget(seq, "No") or seq:CmdlineIndex()
    local res = MessageBox({
        title=PLUGIN .. " — New Mapping",
        message=string.format("Sequence %s — %s\nChoose the cue that starts the beacon, when it stops, and the target executor.", tostring(seqNo), tostring(seqName)),
        commands={{value=1,name="APPLY"},{value=0,name="CANCEL"}},
        inputs={
            {name="Page", value=tostring((CurrentExecPage() and (safeget(CurrentExecPage(),"No") or CurrentExecPage():CmdlineIndex())) or 1), blackFilter="0123456789", maxTextLength=4},
            {name="Executor", value="201", blackFilter="0123456789", maxTextLength=4}
        },
        selectors={
            {name="Start Cue", selectedValue=1, values=labels, type=0},
            {name="Stop", selectedValue=1, values=stopValues, type=0}
        }
    })
    if not res or not res.success or res.result ~= 1 then return end

    local startIndex = tonumber(res.selectors["Start Cue"]) or 1
    local stopPick = tonumber(res.selectors["Stop"]) or 1
    local page = tonumber(res.inputs.Page or "")
    local exec = tonumber(res.inputs.Executor or "")
    if not page or not exec then
        MessageBox({title=PLUGIN, message="Page and Executor must be valid numbers.", commands={{value=1,name="OK"}}})
        return
    end
    if startIndex < 1 or startIndex > #cues then return end

    local stopIndex
    if stopPick == 1 then
        stopIndex = startIndex + 1
        if stopIndex > #cues then
            MessageBox({title=PLUGIN, message="There is no next cue after the selected start cue. Choose a specific stop cue instead.", commands={{value=1,name="OK"}}})
            return
        end
    else
        stopIndex = stopPick - 1
    end
    if stopIndex < 1 or stopIndex > #cues then return end
    if stopIndex <= startIndex then
        MessageBox({title=PLUGIN, message="The stop cue must come after the start cue.", commands={{value=1,name="OK"}}})
        return
    end

    local exHandle = ObjectList(string.format("Page %d.%d", page, exec))
    if not exHandle or not exHandle[1] then
        MessageBox({title=PLUGIN, message=string.format("Page %d Executor %d could not be resolved.", page, exec), commands={{value=1,name="OK"}}})
        return
    end
    local ex = exHandle[1]
    local assigned = ex:GetAssignedObj()
    if assigned == nil then
        MessageBox({title=PLUGIN, message="That executor does not currently have an object assigned.", commands={{value=1,name="OK"}}})
        return
    end

    local nextId = tonumber(GetVar(PREF, "NextID") or 1) or 1
    local id = tostring(nextId)
    SetVar(PREF, "NextID", nextId + 1)
    SetVar(PREF, "Map_"..id.."_Page", page)
    SetVar(PREF, "Map_"..id.."_Exec", exec)
    SetVar(PREF, "Map_"..id.."_Seq", ToAddr(seq, false, true) or "")
    SetVar(PREF, "Map_"..id.."_Start", tostring_safe(safeget(cues[startIndex], "No") or cues[startIndex]:CmdlineIndex()))
    SetVar(PREF, "Map_"..id.."_Stop", tostring_safe(safeget(cues[stopIndex], "No") or cues[stopIndex]:CmdlineIndex()))

    local oldApp = safeget(ex, "Appearance")
    if type(oldApp) == "userdata" then oldApp = ToAddr(oldApp, false, true) end
    SetVar(PREF, "Map_"..id.."_OriginalAppearance", tostring_safe(oldApp))

    make_appearances()

    local startCmd = string.format('SetUserVariable "%s" "%s:START"; Plugin "%s"."%s"', VAR_TRIGGER, id, PLUGIN, RUNTIME_COMPONENT)
    local stopCmd  = string.format('SetUserVariable "%s" "%s:STOP"; Plugin "%s"."%s"', VAR_TRIGGER, id, PLUGIN, RUNTIME_COMPONENT)
    local ok1, err1 = append_command(cues[startIndex], startCmd)
    if not ok1 then
        MessageBox({title=PLUGIN, message="Could not write the start cue command:\n"..tostring(err1), commands={{value=1,name="OK"}}})
        return
    end
    local ok2, err2 = append_command(cues[stopIndex], stopCmd)
    if not ok2 then
        MessageBox({title=PLUGIN, message="The start cue was updated, but the stop cue could not be updated:\n"..tostring(err2), commands={{value=1,name="OK"}}})
        return
    end

    MessageBox({
        title=PLUGIN,
        message=string.format("Mapping %s created.\n\n%s\n→ pulses Page %d Executor %d\n→ stops at %s\n\nExisting cue commands were preserved.", id, labels[startIndex], page, exec, labels[stopIndex]),
        commands={{value=1,name="DONE"}}
    })
end
