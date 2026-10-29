-- Wing Configurator v1.0.28
-- Author: Aaron Wade
-- Safely swaps MA3 fader-module WingIDs without modifying executor assignments.

local signalTable, my_handle = select(3, ...), select(4, ...)
local APP = "WingConfiguratorUI"
local colors = {}

local function safe(fn, fallback) local ok,v=pcall(fn); if ok then return v end return fallback end
local function prop(o,n) return safe(function() return o:Get(n) end, safe(function() return o[n] end,nil)) end
local function q(s) return '"'..tostring(s):gsub('"','\\"')..'"' end

local function ensureUtilityTag()
  local tagName="Utility Plugins"
  local function findTag()
    local list=safe(function() return ObjectList('Tag Thru') end,{}) or {}
    for _,candidate in ipairs(list) do
      if tostring(prop(candidate,"Name") or ""):lower()==tagName:lower() then return candidate end
    end
    return nil
  end
  local tag=findTag()
  if not tag then
    safe(function() Cmd('Store Tag "'..tagName..'" /NoConfirmation') end)
    tag=findTag()
  end
  local plugin=safe(function() return my_handle:Parent() end)
  local tagIndex=tag and tonumber(safe(function() return Obj.Index(tag) end,nil)) or nil
  local pluginIndex=plugin and tonumber(safe(function() return Obj.Index(plugin) end,nil)) or nil
  if tagIndex and pluginIndex then
    local pluginHandle=safe(function() return HandleToInt(plugin) end,nil)
    local references=safe(function() return tag:GetReferences() end,{}) or {}
    for _,reference in pairs(references) do
      if reference==plugin or (pluginHandle and safe(function() return HandleToInt(reference) end,nil)==pluginHandle) then return end
    end
    safe(function() Cmd('Assign Tag '..tagIndex..' At Plugin '..pluginIndex..' Property "Tags" /NoConfirmation') end)
  end
end

local function themeInstall()
  -- Use the active console theme so controls retain the native grandMA3 look.
  local groups=safe(function() return Root().ColorTheme.ColorGroups end)
  colors.normal=safe(function() return groups.Button.BackgroundNormal end,"Global.Button")
  colors.grey=safe(function() return groups.Button.BackgroundClicked end,colors.normal)
  colors.green=safe(function() return groups.Button.BackgroundPlease end,"Global.Selected")
  colors.outline=colors.green
  colors.danger=safe(function() return groups.Button.BackgroundDelete end,"Global.AlertText")
end
local function themeRemove()
  -- No show-saved ColorTheme objects are created.
end

local function modules()
  local out,seen={},{}
  local pool=safe(function() return Root().UsbNotifier.MA3Modules end)
  if pool then
    for _,o in ipairs(pool:Children() or {}) do
      local typ=table.concat({tostring(prop(o,"Type") or ""),tostring(prop(o,"DeviceType") or ""),tostring(prop(o,"Name") or "")}," ")
      local wing=tostring(prop(o,"WingID") or "")
      local upper=typ:upper()
      local isFaderModule=(upper:find("MFE",1,true) or upper:find("MFX",1,true) or upper:find("MFC",1,true)
        or upper:find("FADER MODULE CONTROLLER",1,true) or upper:find("FADER MODULE ENCODER",1,true)
        or upper:find("FADER MODULE CROSSFADER",1,true))
      local excluded=(upper:find("MASTER MODULE",1,true) or upper:match("%(MM%)") or upper:find("DATA BOARD",1,true))
      if wing~="" and wing~="nil" and isFaderModule and not excluded then
        local key=tostring(HandleToInt(o)); seen[key]=true
        out[#out+1]={h=o,index=Obj.Index(o),name="",detail=typ,typ=typ,wing=wing,extension=false}
      end
    end
  end
  local function surfacePriority(m)
    local upper=tostring(m.typ or m.detail or ""):upper()
    if upper:find("MFX",1,true) or upper:find("CROSSFADER",1,true) then return 1 end
    if upper:find("MFE",1,true) or upper:find("ENCODER",1,true) then return 2 end
    if upper:find("MFC",1,true) then return 3 end
    return 9
  end
  -- Module enumeration order can differ between consoles. Hardware type is
  -- stable: MFX is Screen 1 and MFE is Screen 2 on a full-size console.
  table.sort(out,function(a,b)
    local pa,pb=surfacePriority(a),surfacePriority(b)
    if pa~=pb then return pa<pb end
    return a.index<b.index
  end)
  for i,m in ipairs(out) do m.name="Fader Screen "..i end
  local extensionNumber=0
  local function walk(o,depth)
    if not o or depth>4 then return end
    for _,c in ipairs(safe(function() return o:Children() end,{}) or {}) do
      local key=tostring(safe(function() return HandleToInt(c) end,""))
      local wing=tostring(prop(c,"WingID") or "")
      local typ=tostring(prop(c,"DeviceType") or prop(c,"Type") or prop(c,"Name") or "")
      local state=tostring(prop(c,"ConnectionState") or prop(c,"Connected") or prop(c,"Status") or ""):lower()
      local connected=(state=="yes" or state=="connected" or state=="true" or state=="1")
      local isExtension=typ:lower():find("extension",1,true) or typ:upper():find("MFE",1,true)
      if not seen[key] and wing~="" and wing~="nil" and connected and isExtension then
        extensionNumber=extensionNumber+1; seen[key]=true
        local ip=tostring(prop(c,"IP") or prop(c,"Ip") or "")
        out[#out+1]={h=c,index=Obj.Index(c),name="Extension Fader Screen "..extensionNumber,detail=(ip~="" and ip or typ),typ=typ,wing=wing,extension=true}
      end
      walk(c,depth+1)
    end
  end
  walk(safe(function() return DeviceConfiguration() end),0)
  return out
end

local function setWing(m,value)
  if not m or not value then return false end
  local address=safe(function() return m.h:ToAddr() end)
  if not address or address=="" then return false end
  local cmd='Set '..address..' Property "WingID" '..q(value)
  return safe(function() Cmd(cmd); return true end,false)
end

local ui={root=nil,body=nil,status=nil,mods={},identifyBtns={},changeBtns={}}
local function anchorValue(a)
  if type(a)~="table" then return a end
  return table.concat({a.left or 0,a.top or 0,a.right or a.left or 0,a.bottom or a.top or 0},",")
end
local function label(parent,anchor,text,size,color)
  local x=parent:Append("UIObject"); x.Anchors=anchorValue(anchor); x.Text=text or ""; return x
end
local function button(parent,anchor,text,click,style)
  local border=parent:Append("UIObject"); border.Anchors=anchorValue(anchor)
  safe(function() border.Texture="corner15" end)
  safe(function() border.Margin={left=4,right=4,top=4,bottom=4} end)
  safe(function() border.BackColor=colors.outline end)
  local b=parent:Append("Button"); b.Anchors=anchorValue(anchor); b.Text=text; b.Clicked=click
  b.PluginComponent=my_handle
  safe(function() b.HasHover="Yes" end)
  safe(function() b.Texture="corner15" end)
  safe(function() b.Margin={left=8,right=8,top=8,bottom=8} end)
  safe(function() b.BackColor=(style=="selected") and colors.green or colors.normal end)
  return b
end
local function bubble(parent,anchor,text,color)
  local border=parent:Append("UIObject"); border.Anchors=anchorValue(anchor)
  safe(function() border.Texture="corner15" end)
  safe(function() border.Margin={left=4,right=4,top=4,bottom=4} end)
  safe(function() border.BackColor=colors.outline end)
  local b=parent:Append("UIObject"); b.Anchors=anchorValue(anchor); b.Text=text
  safe(function() b.Texture="corner15" end)
  safe(function() b.Margin={left=8,right=8,top=8,bottom=8} end)
  safe(function() b.BackColor=color end)
  return b
end
local function status(text,bad) if ui.status then ui.status.Text=(bad and "ERROR: " or "")..text end end

local function clearBody() if ui.body then safe(function() ui.body:ClearUIChildren() end) end end
local function render()
  clearBody(); ui.mods=modules(); ui.identifyBtns={}; ui.changeBtns={}; local g=ui.body; g.Columns,g.Rows=1,7
  local section=label(g,"0,0","CONNECTED FADER SURFACES",18,"white")
  safe(function() section.TextalignmentH="Left"; section.Padding={left=18,right=0,top=0,bottom=0} end)
  for i=1,math.min(#ui.mods,4) do
    local m=ui.mods[i]; local r=i
    local card=g:Append("UILayoutGrid"); card.Anchors="0,"..r; card.Columns=4; card.Rows=1
    label(card,"0,0",m.name.."\n"..(m.extension and "CONNECTED EXTENSION" or "CONSOLE FADER SURFACE"),19,"white")
    ui.identifyBtns[i]=button(card,"1,0","IDENTIFY","IdentifyM"..i,false)
    bubble(card,"2,0","ACTIVE\n"..m.wing:gsub("Wing","WING "),colors.green)
    ui.changeBtns[i]=button(card,"3,0","CHANGE WING ID","ChangeM"..i,"normal")
  end
  if #ui.mods==0 then label(g,"0,2","No configurable executor-fader surface detected on this station.",20,"red") end
  local actions=g:Append("UILayoutGrid"); actions.Anchors="0,6"; actions.Columns=4; actions.Rows=1
  local console={}; for _,m in ipairs(ui.mods) do if not m.extension then console[#console+1]=m end end
  local selected
  if #console>=2 and console[1].wing=="Wing1" and console[2].wing=="Wing2" then selected="full"
  elseif #console>=2 and console[1].wing=="Wing2" and console[2].wing=="Wing1" then selected="fullReverse"
  elseif #console==1 and console[1].wing=="Wing1" then selected="light"
  elseif #console==1 and console[1].wing=="Wing2" then selected="lightReverse" end
  button(actions,"0,0","FULL SIZE","PresetFull",selected=="full" and "selected" or "normal")
  button(actions,"1,0","FULL SIZE\nREVERSED","PresetFullReversed",selected=="fullReverse" and "selected" or "normal")
  button(actions,"2,0","LIGHT","PresetLight",selected=="light" and "selected" or "normal")
  button(actions,"3,0","LIGHT\nREVERSED","PresetLightReversed",selected=="lightReverse" and "selected" or "normal")
end

function signalTable.Close() if ui.root then safe(function() ui.root:Parent():Delete(ui.root:Index()) end) end; ui.root=nil; themeRemove() end
function signalTable.SwapWings()
  local m=modules(); if #m<2 then status("Two configurable modules were not detected.",true); return end
  local a,b=m[1].wing,m[2].wing
  if a==b then status("Both modules already use "..a.."; choose distinct layouts first.",true); return end
  if setWing(m[1],b) and setWing(m[2],a) then status("Wing locations swapped successfully.",false); render() else status("The console rejected the WingID change.",true) end
end
local function setOne(i,w) local m=modules(); if not m[i] then status("Surface "..i.." is not available.",true); return end; setWing(m[i],w); render(); status(m[i].name.." set to "..w..".",false) end
local function chooseWing(i)
  local m=modules(); if not m[i] then status("Surface "..i.." is not available.",true); return end
  local chooser=ui.changeBtns[i]
  if chooser then safe(function() chooser.BackColor=colors.green end); coroutine.yield(0.05) end
  local choices={"Wing 1","Wing 2","Wing 3","Wing 4"}; local selected=m[i].wing:gsub("Wing","Wing ")
  local a,b=PopupInput({title="Select Wing ID for "..m[i].name,caller=GetFocusDisplay(),items=choices,selectedValue=selected})
  local picked=type(b)=="string" and b or (type(a)=="string" and a or nil)
  if chooser then safe(function() chooser.BackColor=colors.normal end) end
  if picked then local n=picked:match("(%d)"); if n then setOne(i,"Wing"..n) end end
end
local function makeChooser(i) return function() chooseWing(i) end end
for i=1,4 do signalTable["ChangeM"..i]=makeChooser(i) end
local function ledTable(mode,typ)
  local t={}; for i=1,1024 do t[i]=-1 end
  local upper=tostring(typ or ""):upper(); local first,last=161,205
  if upper:find("MFX",1,true) or upper:find("CROSSFADER",1,true) then first,last=168,212 end
  -- The official MA LED map lists each executor fader as R,G,B triplets.
  -- Assign every triplet explicitly: red + blue = purple; green = zero.
  for red=first,last,3 do
    if mode=="purple" then t[red]=255; t[red+1]=0; t[red+2]=255
    elseif mode=="off" then t[red]=0; t[red+1]=0; t[red+2]=0 end
  end
  return t
end
local function identify(i)
  local m=modules(); if not m[i] then status("Fader Screen "..i.." is not available.",true); return end
  status("Identifying "..m[i].name.."...",false)
  local identifyButton=ui.identifyBtns[i]
  if identifyButton then identifyButton.Text="IDENTIFYING..."; safe(function() identifyButton.BackColor=colors.green end) end
  local purple=ledTable("purple",m.typ); local off=ledTable("off",m.typ); local release=ledTable("release",m.typ)
  for flash=1,3 do
    local ok=safe(function() SetLED(m[i].h,purple); return true end,false)
    if not ok then
      if identifyButton then identifyButton.Text="IDENTIFY"; safe(function() identifyButton.BackColor=colors.normal end) end
      status("This connected surface does not expose LED identification.",true); return
    end
    coroutine.yield(0.36)
    safe(function() SetLED(m[i].h,off) end); coroutine.yield(0.22)
  end
  safe(function() SetLED(m[i].h,release) end)
  if identifyButton then identifyButton.Text="IDENTIFY"; safe(function() identifyButton.BackColor=colors.normal end) end
  status(m[i].name.." identified.",false)
end
local function makeIdentifier(i) return function() identify(i) end end
for i=1,4 do signalTable["IdentifyM"..i]=makeIdentifier(i) end
local function consoleModules()
  local found={}; for _,m in ipairs(modules()) do if not m.extension then found[#found+1]=m end end; return found
end
local function applyPreset(name,assignments)
  local m=consoleModules()
  if #m<#assignments then status(name.." requires "..#assignments.." console fader surfaces; only "..#m.." detected.",true); return end
  for i,wing in ipairs(assignments) do setWing(m[i],wing) end
  render(); status(name.." preset applied.",false)
end
function signalTable.PresetFull() applyPreset("Full Size",{"Wing1","Wing2"}) end
function signalTable.PresetFullReversed() applyPreset("Full Size Reversed",{"Wing2","Wing1"}) end
function signalTable.PresetLight() applyPreset("Light",{"Wing1"}) end
function signalTable.PresetLightReversed() applyPreset("Light Reversed",{"Wing2"}) end

local function open()
  ensureUtilityTag()
  themeInstall(); local d=GetFocusDisplay(); if Obj.Index(d)>5 then d=GetDisplayByIndex(1) end
  -- Rebind the imported appearance at runtime as a fallback for consoles that
  -- retain the old Plugin pool object's appearance while updating components.
  safe(function()
    local plugin=my_handle:Parent()
    local appearance=Root().ShowData.Appearances.WingConfigurator
    if plugin and appearance then plugin.Appearance=appearance end
  end)
  local ov=d.ScreenOverlay; local old=ov:Find(APP,"BaseInput"); if old then old:Parent():Delete(old:Index()) end
  local r=ov:Append("BaseInput"); ui.root=r; r.Name=APP; r.W=1120; r.H=760; r.AlignmentH="Center"; r.AlignmentV="Center"; r.Columns=1; r.Rows=5; r.AutoClose="No"; r.CloseOnEscape="Yes"; r.PluginComponent=my_handle; r.CanCoexistWithModal="Yes"
  safe(function() r[1][1].SizePolicy="Fixed"; r[1][1].Size="56"; r[1][2].SizePolicy="Fixed"; r[1][2].Size="68"; r[1][3].SizePolicy="Fixed"; r[1][3].Size="8"; r[1][4].SizePolicy="Stretch"; r[1][5].SizePolicy="Fixed"; r[1][5].Size="48" end)
  local tb=r:Append("TitleBar"); tb.Anchors="0,0"; tb.Columns=2; tb.Rows=1; tb.Texture="corner2"
  safe(function() tb[1][1].SizePolicy="Stretch"; tb[1][2].SizePolicy="Fixed"; tb[1][2].Size="132" end)
  local t=tb:Append("TitleButton"); t.Anchors="0,0"; t.Text="WING CONFIGURATOR"; t.Texture="corner1"
  local x=tb:Append("Button"); x.Anchors="1,0"; x.Text="CLOSE"; x.Texture="corner2"; x.PluginComponent=my_handle; x.Clicked="Close"; x.HasHover="Yes"
  local hero=r:Append("UIObject"); hero.Anchors="0,1"; hero.Text="IDENTIFY AND ASSIGN CONNECTED FADER WINGS"
  safe(function() hero.TextalignmentH="Centre" end)
  local divider=r:Append("UIObject"); divider.Anchors="0,2"; divider.Text=""
  ui.body=r:Append("UILayoutGrid"); ui.body.Anchors="0,3"
  ui.status=label(r,"0,4","Ready  •  grandMA3 "..tostring(Version()),17,"dim")
  render(); safe(function() r:WaitInit(2) end)
end

return function() local ok,e=pcall(open); if not ok then ErrPrintf("Wing Configurator: %s",tostring(e)); themeRemove() end end
