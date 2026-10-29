local PLUGIN = "Cue Beacon"
local PREF = PluginVars(PLUGIN)

return function()
    local nextId = tonumber(GetVar(PREF, "NextID") or 1) or 1
    for n=1,nextId-1 do
        local id = tostring(n)
        local p = tonumber(GetVar(PREF, "Map_"..id.."_Page") or 0)
        local e = tonumber(GetVar(PREF, "Map_"..id.."_Exec") or 0)
        if p and e and p > 0 and e > 0 then
            local original = tostring(GetVar(PREF, "Map_"..id.."_OriginalAppearance") or "")
            if original ~= "" and original ~= "nil" then
                Cmd(string.format('Assign %s At Page %d.%d', original, p, e))
            else
                Cmd(string.format('Assign Off Appearance At Page %d.%d', p, e))
            end
        end
    end
    MessageBox({title=PLUGIN, message="All Cue Beacon executor appearances were released.", commands={{value=1,name="OK"}}})
end
