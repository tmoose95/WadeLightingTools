-- Touch Configurator
-- Author: Aaron Wade - Crossfade Design
-- Exchanges complete ScreenContent and ViewButton assignments between large displays.

local signalTable,my_handle=select(3,...),select(4,...)
local APP="TouchConfiguratorUI"
local colors,assignment={},{}
local fitMode="original"
local ui={root=nil,body=nil,status=nil,surfaces={},identify={},change={},fit=nil}
for screen=1,5 do assignment[screen]=screen end

local function safe(fn,fallback) local ok,v=pcall(fn); if ok then return v end return fallback end
local function prop(o,n) return safe(function() return o:Get(n) end,safe(function() return o[n] end,nil)) end
local function className(o) return tostring(safe(function() return o:GetClass() end,safe(function() return o:GetClassName() end,"")) or "") end
local function objectChildren(o)
  local list=safe(function() return o:Children() end,nil)
  if type(list)=="table" then return list end
  list=safe(function() return o:CmdlineChildren() end,nil)
  return type(list)=="table" and list or {}
end
local function truth(v) v=tostring(v or ""):lower(); return v=="1" or v=="true" or v=="yes" or v=="connected" end
local function numberValue(v)
  if type(v)=="number" then return v end
  local direct=tonumber(v)
  if direct then return direct end
  local match=tostring(v or ""):match("[-+]?%d+%.?%d*")
  return match and tonumber(match) or nil
end
local function round(v) return math.floor((tonumber(v) or 0)+0.5) end

-- grandMA3 uses a logical display grid for ScreenContent. ViewWidget X/Y/W/H
-- coordinates are stored in a 2x sub-grid (half columns/rows), so fitting a
-- view to a different screen means scaling against the destination grid and
-- converting back to those half-grid units.
local function currentScreenContent(displayIndex)
  local config=safe(function() return CurrentScreenConfig() end,nil)
  if not config then return nil end
  local collection=safe(function() return config:Ptr(1) end,nil)
  local content=collection and safe(function() return collection:Ptr(displayIndex) end,nil) or nil
  if content then return content end
  local root=safe(function() return GetScreenContent(config) end,nil)
  if root then
    local child=safe(function() return root:Ptr(displayIndex) end,nil)
    return child or root
  end
  return nil
end

local function displayGridDimensions(displayIndex)
  local display=safe(function() return GetDisplayByIndex(displayIndex) end,nil)
  if not display then return nil end
  local screenSettings=safe(function() return FromAddr(display:Addr()..".5.3.1.5.1") end,nil)
  local w=screenSettings and numberValue(prop(screenSettings,"ViewW")) or nil
  local h=screenSettings and numberValue(prop(screenSettings,"ViewH")) or nil
  if not w or not h or w<=0 or h<=0 then
    -- Safe fallback: this will preserve the current size rather than risk
    -- writing invalid geometry if MA changes the internal display path.
    local content=currentScreenContent(displayIndex)
    w=content and numberValue(prop(content,"RequestedW")) or nil
    h=content and numberValue(prop(content,"RequestedH")) or nil
  end
  if not w or not h or w<=0 or h<=0 then return nil end
  return {w=round(w),h=round(h)}
end

local function scaledGeometry(x,y,w,h,sourceW,sourceH,targetW,targetH)
  if not x or not y or not w or not h or not sourceW or not sourceH or sourceW<=0 or sourceH<=0 then return nil end
  return {
    x=round((x/(sourceW*2))*targetW)*2,
    y=round((y/(sourceH*2))*targetH)*2,
    w=math.max(2,round((w/(sourceW*2))*targetW)*2),
    h=math.max(2,round((h/(sourceH*2))*targetH)*2),
  }
end

local function scaleCurrentScreenToFit(displayIndex,targetDims)
  local target=targetDims or displayGridDimensions(displayIndex)
  local content=currentScreenContent(displayIndex)
  if not target or not content then return false,0 end
  local sourceW=numberValue(prop(content,"RequestedW"))
  local sourceH=numberValue(prop(content,"RequestedH"))
  if not sourceW or not sourceH or sourceW<=0 or sourceH<=0 then return false,0 end
  if round(sourceW)==round(target.w) and round(sourceH)==round(target.h) then return true,0 end

  local widgets={}
  for index,widget in ipairs(objectChildren(content)) do
    local x=numberValue(prop(widget,"X")); local y=numberValue(prop(widget,"Y"))
    local w=numberValue(prop(widget,"W")); local h=numberValue(prop(widget,"H"))
    local scaled=scaledGeometry(x,y,w,h,sourceW,sourceH,target.w,target.h)
    if scaled then widgets[#widgets+1]={index=index,x=x or 0,y=y or 0,scaled=scaled} end
  end

  local scalingUp=(target.w>=sourceW)
  table.sort(widgets,function(a,b)
    if scalingUp then
      if a.x==b.x then return a.y>b.y end
      return a.x>b.x
    end
    if a.x==b.x then return a.y<b.y end
    return a.x<b.x
  end)

  for pass=1,2 do
    for _,widget in ipairs(widgets) do
      local g=widget.scaled
      local feedback=safe(function()
        return Cmd(string.format('Set ScreenContent %d.%d X=%d Y=%d W=%d H=%d',displayIndex,widget.index,g.x,g.y,g.w,g.h))
      end,nil)
      if not tostring(feedback or ""):lower():match("^ok") then return false,#widgets end
    end
  end
  safe(function() content:Set("RequestedW",tostring(target.w)) end)
  safe(function() content:Set("RequestedH",tostring(target.h)) end)
  return true,#widgets
end

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

local function theme()
  local g=safe(function() return Root().ColorTheme.ColorGroups end)
  colors.normal=safe(function() return g.Button.BackgroundNormal end,"Global.Button")
  colors.green=safe(function() return g.Button.BackgroundPlease end,"Global.Selected")
  colors.disabled=safe(function() return g.Button.BackgroundDisabled end,colors.normal)
  colors.disabledText=safe(function() return g.Button.TextDisabled end,safe(function() return g.Button.TextNormal end,nil))
  colors.outline=colors.green
end

local function notifierColors()
  local ct=safe(function() return Root().ColorTheme end)
  if not ct then return nil,nil,function() end end
  local defs=safe(function() return ct.ColorDefCollect.Global end)
  local groups=safe(function() return ct.ColorGroups end)
  if not defs or not groups then return nil,nil,function() end end
  local createdDefs,createdRefs={},{}
  local createdGroup=false
  local function ensureDef(name,rgba)
    local d=safe(function() return defs[name] end)
    if not d then d=safe(function() return defs:Acquire() end); if d then d.Name=name; createdDefs[#createdDefs+1]=d end end
    if d then safe(function() d:Set("rgba",rgba) end) end
    return d
  end
  local group=safe(function() return groups.TouchConfiguratorNotifier end)
  if not group then group=safe(function() return groups:Acquire() end); if group then group.Name="TouchConfiguratorNotifier"; createdGroup=true end end
  local function ensureRef(name,def)
    if not group or not def then return nil end
    local ref=safe(function() return group[name] end)
    if not ref then ref=safe(function() return group:Acquire() end); if ref then ref.Name=name; createdRefs[#createdRefs+1]=ref end end
    if ref then safe(function() ref:Set("ColorDefRef",HandleToStr(def)) end) end
    return ref
  end
  local bg=ensureRef("NoticeBackground",ensureDef("TouchConfiguratorNoticeBackground","000000FF"))
  local text=ensureRef("NoticeText",ensureDef("TouchConfiguratorNoticeText","FFD100FF"))
  local function cleanup()
    -- Remove only objects created for this notification. Existing identically
    -- named objects are reused and preserved.
    if createdGroup and group then safe(function() group:Parent():Delete(group:Index()) end)
    else for n=#createdRefs,1,-1 do local o=createdRefs[n]; safe(function() o:Parent():Delete(o:Index()) end) end end
    for n=#createdDefs,1,-1 do local o=createdDefs[n]; safe(function() o:Parent():Delete(o:Index()) end) end
  end
  return bg,text,cleanup
end

local function detectSurfaces()
  local out,seen={},{}
  local collect=safe(function() return GetDisplayCollect() end)
  if not collect then return out end
  for _,entry in ipairs(safe(function() return collect:Children() end,{}) or {}) do
    local index=tonumber(prop(entry,"INDEX") or prop(entry,"Index") or safe(function() return Obj.Index(entry) end))
    local display=index and safe(function() return GetDisplayByIndex(index) end) or nil
    local w=tonumber(prop(entry,"W") or prop(display,"W") or 0) or 0
    local h=tonumber(prop(entry,"H") or prop(display,"H") or 0) or 0
    local connected=prop(entry,"Connected")
    if connected==nil then connected=prop(display,"Connected") end
    local builtIn=index and index>=1 and index<=3
    local extra=index and index>3 and truth(connected) and w>800 and h>480
    if display and (builtIn or extra) and not seen[index] then
      seen[index]=true
      out[#out+1]={index=index,display=display,w=w,h=h}
    end
  end
  table.sort(out,function(a,b) return a.index<b.index end)
  local extension=0
  for i,s in ipairs(out) do
    if i<=3 then s.name="Touch Screen "..i else extension=extension+1; s.name="DP Touch Screen "..extension end
    assignment[s.index]=assignment[s.index] or s.index
  end
  return out
end

local function label(parent,anchor,text)
  local x=parent:Append("UIObject"); x.Anchors=anchor; x.Text=text or ""; return x
end
local function button(parent,anchor,text,clicked,selected)
  local edge=parent:Append("UIObject"); edge.Anchors=anchor
  safe(function() edge.Texture="corner15"; edge.Margin={left=4,right=4,top=4,bottom=4}; edge.BackColor=colors.outline end)
  local b=parent:Append("Button"); b.Anchors=anchor; b.Text=text
  if clicked then b.Clicked=clicked; b.PluginComponent=my_handle end
  safe(function() b.Texture="corner15"; b.Margin={left=8,right=8,top=8,bottom=8}; b.HasHover="Yes"; b.BackColor=selected and colors.green or colors.normal end)
  return b
end
local function bubble(parent,anchor,text)
  local edge=parent:Append("UIObject"); edge.Anchors=anchor
  safe(function() edge.Texture="corner15"; edge.Margin={left=4,right=4,top=4,bottom=4}; edge.BackColor=colors.outline end)
  local b=parent:Append("UIObject"); b.Anchors=anchor; b.Text=text
  safe(function() b.Texture="corner15"; b.Margin={left=8,right=8,top=8,bottom=8}; b.BackColor=colors.green end)
end
local function stateBubble(parent,anchor,text,connected)
  local b=parent:Append("UIObject"); b.Anchors=anchor; b.Text=text
  safe(function()
    b.Texture="corner15"; b.Margin={left=8,right=8,top=8,bottom=8}
    b.BackColor=connected and colors.green or colors.disabled
    if not connected and colors.disabledText then b.TextColor=colors.disabledText end
  end)
  return b
end
local function status(text,bad) if ui.status then ui.status.Text=(bad and "ERROR: " or "")..text end end

local function render()
  safe(function() ui.body:ClearUIChildren() end)
  local detected=detectSurfaces()
  local connected={}
  for _,surface in ipairs(detected) do connected[surface.index]=surface end
  ui.surfaces={}; ui.identify={}; ui.change={}
  for screen=1,5 do
    local s=connected[screen]
    if s then
      s.connected=true
    else
      s={index=screen,display=nil,w=0,h=0,connected=false}
    end
    s.name=screen<=3 and ("Touch Screen "..screen) or ("DP Touch Screen "..(screen-3))
    assignment[screen]=assignment[screen] or screen
    ui.surfaces[screen]=s
  end
  local g=ui.body; g.Columns=1; g.Rows=6
  local section=label(g,"0,0","TOUCH SCREEN SLOTS  •  CONNECTED + STORED")
  safe(function() section.TextalignmentH="Left"; section.Padding={left=18,right=0,top=0,bottom=0} end)
  for screen=1,5 do
    local s=ui.surfaces[screen]
    local row=g:Append("UILayoutGrid"); row.Anchors="0,"..screen; row.Columns=5; row.Rows=1
    local detail=s.connected and ("DISPLAY "..s.index.."  •  "..s.w.." x "..s.h) or ("DISPLAY "..s.index.."  •  STORED OFFLINE")
    local info=label(row,"0,0",s.name.."\n"..detail)
    if not s.connected and colors.disabledText then safe(function() info.TextColor=colors.disabledText end) end
    stateBubble(row,"1,0",s.connected and "CONNECTED" or "DISCONNECTED",s.connected)
    ui.identify[screen]=button(row,"2,0",s.connected and "IDENTIFY" or "OFFLINE",s.connected and ("Identify"..screen) or nil,false)
    if not s.connected then safe(function() ui.identify[screen].BackColor=colors.disabled; ui.identify[screen].TextColor=colors.disabledText end) end
    local mapping=(s.connected and "ACTIVE\nDISPLAY " or "STORED\nDISPLAY ")..tostring(assignment[screen])
    if s.connected then bubble(row,"3,0",mapping) else stateBubble(row,"3,0",mapping,false) end
    ui.change[screen]=button(row,"4,0",s.connected and "CHANGE DISPLAY" or "UNAVAILABLE",s.connected and ("Change"..screen) or nil,false)
    if not s.connected then safe(function() ui.change[screen].BackColor=colors.disabled; ui.change[screen].TextColor=colors.disabledText end) end
  end
end

function signalTable.Close()
  if ui.root then safe(function() ui.root:Parent():Delete(ui.root:Index()) end) end
  ui.root=nil
end

local function identify(i)
  local s=ui.surfaces[i]; if not s then return end
  if not s.connected or not s.display then status(s.name.." is disconnected; its stored display assignment remains available.",true); return end
  local btn=ui.identify[i]
  if btn then btn.Text="IDENTIFYING..."; safe(function() btn.BackColor=colors.green end) end
  local overlay=safe(function() return s.display.ScreenOverlay end)
  if not overlay then status("This display does not expose a notification overlay.",true); return end
  local noticeBackground,noticeText,cleanupColors=notifierColors()
  for flash=1,3 do
    local toast=safe(function() return overlay:Append("UIObject") end)
    if toast then
      toast.Name=APP.."Notifier"; toast.W=440; toast.H=108
      toast.X=math.max(0,(tonumber(prop(s.display,"W")) or s.w or 1920)-468); toast.Y=28
      toast.Texture="corner15"; toast.Text="TOUCH SCREEN "..tostring(s.index)
      if noticeBackground then toast.BackColor=noticeBackground end
      if noticeText then toast.TextColor=noticeText end
      safe(function() toast.TextalignmentH="Centre"; toast.TextalignmentV="Centre" end)
      coroutine.yield({ui=1})
      coroutine.yield(0.52)
      safe(function() toast:Parent():Delete(toast:Index()) end)
    end
    coroutine.yield(0.22)
  end
  cleanupColors()
  if btn then btn.Text="IDENTIFY"; safe(function() btn.BackColor=colors.normal end) end
  status(s.name.." identified.")
end

local function findViewsPool()
  local profile=safe(function() return CurrentProfile() end,nil)
  if not profile then return nil end
  local pool=safe(function() return profile.Views end,nil)
  if pool then return pool end
  pool=safe(function() return profile:Find("Views") end,nil)
  if pool then return pool end
  for _,child in ipairs(objectChildren(profile)) do
    local name=tostring(prop(child,"Name") or ""):lower()
    local class=className(child):lower()
    if name=="views" or class:find("viewpool",1,true) then return child end
  end
  return nil
end

local function collectStoredViewChanges(a,b,scaleToFit,gridDims)
  local pool=findViewsPool()
  if not pool then return nil,"The current User Profile does not expose its Views pool." end
  local changes,inspected={},0
  local stats={widgets=0,scaled=0,views=0}
  local maskA,maskB=1 << (a-1),1 << (b-1)
  local function remapMask(value)
    local mask=tonumber(value)
    if not mask then return nil end
    local hasA=(mask & maskA)~=0
    local hasB=(mask & maskB)~=0
    if hasA==hasB then return mask end
    local remapped=mask & (~(maskA | maskB))
    if hasA then remapped=remapped | maskB end
    if hasB then remapped=remapped | maskA end
    return remapped
  end
  local function addChange(object,property,old,new)
    if old==nil or new==nil then return end
    local oldNumber,newNumber=numberValue(old),numberValue(new)
    if oldNumber and newNumber and oldNumber==newNumber then return end
    if not oldNumber and not newNumber and tostring(old)==tostring(new) then return end
    changes[#changes+1]={object=object,property=property,old=old,new=new}
  end

  for viewIndex,view in ipairs(objectChildren(pool)) do
    local reqW=numberValue(prop(view,"RequestedW"))
    local reqH=numberValue(prop(view,"RequestedH"))
    local viewMoved=false
    local finalDimensions={}
    local finalDimensionCount=0

    local function remapNodeMask(node)
      local screenMask=tonumber(prop(node,"ScreenContentMask"))
      if screenMask then
        local remapped=remapMask(screenMask)
        if remapped and remapped~=screenMask then addChange(node,"ScreenContentMask",screenMask,remapped) end
      end
    end
    remapNodeMask(view)

    local function scan(node,depth)
      if depth>5 then return end
      for _,child in ipairs(objectChildren(node)) do
        inspected=inspected+1
        local display=tonumber(prop(child,"Display"))
        local class=className(child):lower()
        if display and class:find("viewwidget",1,true) then
          local targetDisplay=display
          if display==a then targetDisplay=b elseif display==b then targetDisplay=a end
          local dims=gridDims and gridDims[targetDisplay] or nil
          if dims then
            local key=tostring(dims.w).."x"..tostring(dims.h)
            if not finalDimensions[key] then finalDimensions[key]=dims; finalDimensionCount=finalDimensionCount+1 end
          end
          if targetDisplay~=display then
            viewMoved=true
            stats.widgets=stats.widgets+1
            addChange(child,"Display",display,targetDisplay)
            if scaleToFit and reqW and reqH and dims then
              local x=numberValue(prop(child,"X")); local y=numberValue(prop(child,"Y"))
              local w=numberValue(prop(child,"W")); local h=numberValue(prop(child,"H"))
              local scaled=scaledGeometry(x,y,w,h,reqW,reqH,dims.w,dims.h)
              if scaled then
                addChange(child,"X",x,scaled.x); addChange(child,"Y",y,scaled.y)
                addChange(child,"W",w,scaled.w); addChange(child,"H",h,scaled.h)
                stats.scaled=stats.scaled+1
              end
            end
          end
          -- Never enter a ViewWidget: its children are window-specific settings.
        else
          remapNodeMask(child)
          scan(child,depth+1)
        end
        if inspected%100==0 then coroutine.yield({ui=1}) end
      end
    end

    scan(view,1)
    if viewMoved then
      stats.views=stats.views+1
      -- RequestedW/H is the coordinate basis for a stored View. When every
      -- screen in this View ends up on the same logical grid size, advance the
      -- basis with the geometry so a later move can scale cleanly in reverse.
      if scaleToFit and finalDimensionCount==1 then
        for _,dims in pairs(finalDimensions) do
          if reqW then addChange(view,"RequestedW",reqW,dims.w) end
          if reqH then addChange(view,"RequestedH",reqH,dims.h) end
        end
      end
    end
    if viewIndex%10==0 then coroutine.yield({ui=1}); coroutine.yield(0.01) end
  end
  return changes,nil,stats
end

local function setStoredProperty(change,value)
  return safe(function()
    local property=change.property or "Display"
    change.object:Set(property,tostring(value))
    local current=prop(change.object,property)
    local currentNumber=numberValue(current)
    local expectedNumber=numberValue(value)
    if currentNumber~=nil and expectedNumber~=nil then
      return currentNumber==expectedNumber
    end
    return tostring(current or "")==tostring(value or "")
  end,false)
end

local function rollbackStoredViews(changes,count)
  for n=count,1,-1 do
    setStoredProperty(changes[n],changes[n].old)
    if n%20==0 then coroutine.yield({ui=1}) end
  end
end

local function applyDisplayChanges(changes)
  local applied=0
  for n,change in ipairs(changes) do
    if not setStoredProperty(change,change.new) then return false,applied end
    applied=n
    if n%20==0 then coroutine.yield({ui=1}); coroutine.yield(0.02) end
  end
  return true,applied
end

local function viewButtonMap(screen)
  local map={}
  local list=safe(function() return ObjectList("ViewButton "..screen..".*") end,{}) or {}
  for _,handle in ipairs(list) do
    local index=tonumber(safe(function() return Obj.Index(handle) end,nil))
    if index and index>0 then map[index]=true end
  end
  return map
end

local function viewButtonExists(screen,index)
  local list=safe(function() return ObjectList(string.format("ViewButton %d.%d",screen,index)) end,{}) or {}
  return list[1]~=nil
end

local function viewButtonHandle(screen,index)
  local list=safe(function() return ObjectList(string.format("ViewButton %d.%d",screen,index)) end,{}) or {}
  return list[1]
end

local function collectViewButtonOperations(a,b)
  local mapA,mapB=viewButtonMap(a),viewButtonMap(b)
  local seen,indices={},{ }
  for index in pairs(mapA) do seen[index]=true end
  for index in pairs(mapB) do seen[index]=true end
  for index in pairs(seen) do indices[#indices+1]=index end
  table.sort(indices)
  local operations={}
  for _,index in ipairs(indices) do
    if mapA[index] and mapB[index] then
      operations[#operations+1]={kind="exchange",from=a,to=b,first=index,last=index}
    elseif mapA[index] then
      operations[#operations+1]={kind="copy",from=a,to=b,first=index,last=index}
    else
      operations[#operations+1]={kind="copy",from=b,to=a,first=index,last=index}
    end
  end
  return operations
end

local function runViewButtonOperation(operation)
  local function address(screen,first,last)
    return string.format("ViewButton %d.%d",screen,first)
  end
  local source=address(operation.from,operation.first,operation.last)
  local destination=address(operation.to,operation.first,operation.last)
  local command
  if operation.kind=="exchange" then
    command="Exchange "..source.." At "..destination
  else
    -- ViewButton objects reject the Move keyword. Copy the assignment into the
    -- verified-empty destination, then remove only the original object directly.
    command="Copy "..source.." At "..destination.." /Overwrite /NoConfirmation"
  end
  local feedback=safe(function() return Cmd(command) end,nil)
  if not tostring(feedback or ""):match("^OK") then return false end
  if operation.kind=="copy" then
    for index=operation.first,operation.last do
      local original=viewButtonHandle(operation.from,index)
      if not original or not viewButtonExists(operation.to,index) then return false end
      safe(function() original:Parent():Delete(original:Index()) end)
    end
  end
  for index=operation.first,operation.last do
    if operation.kind=="exchange" then
      if not viewButtonExists(operation.from,index) or not viewButtonExists(operation.to,index) then return false end
    elseif viewButtonExists(operation.from,index) or not viewButtonExists(operation.to,index) then
      return false
    end
  end
  return true
end

local function applyViewButtonOperations(operations)
  local completed=0
  for index,operation in ipairs(operations) do
    if not runViewButtonOperation(operation) then return false,completed end
    completed=index
    coroutine.yield({ui=1})
  end
  return true,completed
end

local function rollbackViewButtonOperations(operations,count)
  for index=count,1,-1 do
    local operation=operations[index]
    if operation.kind=="exchange" then
      runViewButtonOperation(operation)
    else
      runViewButtonOperation({kind="copy",from=operation.to,to=operation.from,first=operation.first,last=operation.last})
    end
  end
end

local function captureLiveScreens(a,b)
  local pool=findViewsPool()
  if not pool then return nil end
  local used={}
  for _,view in ipairs(objectChildren(pool)) do
    local index=tonumber(safe(function() return Obj.Index(view) end,nil))
    if index then used[index]=true end
  end
  local available={}
  for index=9999,9000,-1 do
    if not used[index] then available[#available+1]=index end
    if #available==2 then break end
  end
  if #available<2 then return nil end
  local capture={a=a,b=b,viewA=available[1],viewB=available[2]}
  safe(function() Cmd(string.format('Store View %d "__TouchConfigurator_Live_A__" /Screen "%d" /NoConfirmation',capture.viewA,a)) end)
  safe(function() Cmd(string.format('Store View %d "__TouchConfigurator_Live_B__" /Screen "%d" /NoConfirmation',capture.viewB,b)) end)
  local storedA=safe(function() return ObjectList("View "..capture.viewA) end,{}) or {}
  local storedB=safe(function() return ObjectList("View "..capture.viewB) end,{}) or {}
  if not storedA[1] or not storedB[1] then
    if storedA[1] then safe(function() storedA[1]:Parent():Delete(storedA[1]:Index()) end) end
    if storedB[1] then safe(function() storedB[1]:Parent():Delete(storedB[1]:Index()) end) end
    return nil
  end
  capture.handleA=storedA[1]; capture.handleB=storedB[1]
  return capture
end

local function recallCapturedScreens(capture,swapped)
  if not capture then return false end
  local targetA=swapped and capture.b or capture.a
  local targetB=swapped and capture.a or capture.b
  safe(function() Cmd(string.format('Call View %d /Screen "%d"',capture.viewA,targetA)) end)
  safe(function() Cmd(string.format('Call View %d /Screen "%d"',capture.viewB,targetB)) end)
  coroutine.yield({ui=1}); coroutine.yield(0.08)
  return true
end

local function deleteCapturedScreens(capture)
  if not capture then return end
  if capture.handleA then safe(function() capture.handleA:Parent():Delete(capture.handleA:Index()) end) end
  if capture.handleB then safe(function() capture.handleB:Parent():Delete(capture.handleB:Index()) end) end
end

local function exchangeScreens(a,b,scaleToFit)
  if a==b then return true end
  local layoutA,layoutB=assignment[a] or a,assignment[b] or b
  local gridDims={[a]=displayGridDimensions(a),[b]=displayGridDimensions(b)}
  if scaleToFit and (not gridDims[a] or not gridDims[b]) then
    return false,"The console could not read the destination screen grid sizes required for Scale To Fit."
  end
  local storedChanges,problem,storedStats
  storedChanges,problem,storedStats=collectStoredViewChanges(a,b,scaleToFit,gridDims)
  if not storedChanges then return false,problem end
  -- Snapshot each currently visible screen independently before changing any
  -- live or stored objects. These snapshots drive the immediate two-way recall
  -- and remain available until the full transaction commits or rolls back.
  local liveCapture=captureLiveScreens(a,b)
  if not liveCapture then return false,"The console could not capture both active screens for a live swap." end
  -- Recall each pre-swap live snapshot onto the opposite local screen. Do not
  -- mutate the shared live screen-content object directly: that
  -- streams a forced window rebuild to backup stations and can trigger nil-state
  -- faults inside MA's built-in SequenceSheet and Timecode window plugins.
  if not recallCapturedScreens(liveCapture,true) then
    recallCapturedScreens(liveCapture,false)
    deleteCapturedScreens(liveCapture)
    return false,"The console could not refresh the remapped live screens; live content was rolled back."
  end
  if scaleToFit then
    local fitA=scaleCurrentScreenToFit(a,gridDims[a])
    local fitB=scaleCurrentScreenToFit(b,gridDims[b])
    if not fitA or not fitB then
      recallCapturedScreens(liveCapture,false)
      deleteCapturedScreens(liveCapture)
      return false,"Scale To Fit could not resize the live windows; live content was rolled back."
    end
  end
  -- Exchange matching ViewButtons and copy one-sided entries into empty slots,
  -- then remove only the original one-sided object through its handle.
  -- Exchange requires both destinations to exist and caused illegal-list errors
  -- when two screens exposed different button counts.
  local buttonOperations=collectViewButtonOperations(a,b)
  if #buttonOperations==0 then
    recallCapturedScreens(liveCapture,false)
    deleteCapturedScreens(liveCapture)
    return false,"No ViewButton assignments were found for the selected screens."
  end
  local second,buttonsCompleted=applyViewButtonOperations(buttonOperations)
  if not second then
    rollbackViewButtonOperations(buttonOperations,buttonsCompleted)
    recallCapturedScreens(liveCapture,false)
    deleteCapturedScreens(liveCapture)
    return false,"The console rejected the ViewButton exchange; live content was rolled back."
  end
  coroutine.yield({ui=1})
  coroutine.yield(0.08)
  local storedOK,storedApplied=applyDisplayChanges(storedChanges)
  if not storedOK then
    rollbackStoredViews(storedChanges,storedApplied)
    rollbackViewButtonOperations(buttonOperations,#buttonOperations)
    recallCapturedScreens(liveCapture,false)
    deleteCapturedScreens(liveCapture)
    return false,"A stored View rejected its Display remap; live content and completed View changes were rolled back."
  end
  -- The physical screens exchange what they currently hold. Swap their
  -- tracked layout identities directly so repeated exchanges remain accurate.
  assignment[a],assignment[b]=layoutB,layoutA
  deleteCapturedScreens(liveCapture)
  return true,nil,storedStats or {widgets=0,scaled=0,views=0}
end

local function choose(i)
  local s=ui.surfaces[i]; if not s then return end
  local btn=ui.change[i]
  if btn then safe(function() btn.BackColor=colors.green end) end
  local items={"Layout 1","Layout 2","Layout 3","Layout 4","Layout 5"}
  local a,b=PopupInput({title="Select layout for "..s.name,caller=GetFocusDisplay(),items=items,selectedValue="Layout "..tostring(assignment[s.index])})
  local picked=type(b)=="string" and b or (type(a)=="string" and a or nil)
  if btn then safe(function() btn.BackColor=colors.normal end) end
  local wanted=picked and tonumber(picked:match("(%d+)")) or nil
  if not wanted or wanted==assignment[s.index] then return end
  local other=nil
  for screen,value in pairs(assignment) do if value==wanted then other=screen break end end
  if not other and wanted>=1 and wanted<=5 then other=wanted end
  if not other then status("That layout is not available.",true); return end
  local scaleToFit=(fitMode=="scale")
  local exchanged,problem,stats=exchangeScreens(s.index,other,scaleToFit)
  if exchanged then
    render()
    if scaleToFit then
      status(s.name.." now uses Display "..wanted.."; remapped "..tostring((stats and stats.widgets) or 0).." stored View windows and scaled "..tostring((stats and stats.scaled) or 0).." to fit.")
    else
      status(s.name.." now uses Display "..wanted.."; remapped "..tostring((stats and stats.widgets) or 0).." stored View windows at original size.")
    end
  else
    status(problem or "The console rejected the exchange.",true)
  end
end

local function refreshFitButton()
  if not ui.fit then return end
  if fitMode=="scale" then
    ui.fit.Text="SIZE: FIT SCREEN"
    safe(function() ui.fit.BackColor=colors.green end)
  else
    ui.fit.Text="SIZE: ORIGINAL"
    safe(function() ui.fit.BackColor=colors.normal end)
  end
end

function signalTable.ToggleFitMode()
  fitMode=(fitMode=="scale") and "original" or "scale"
  refreshFitButton()
  if fitMode=="scale" then
    status("Scale To Fit enabled: moved layouts will expand or shrink to the destination screen grid.")
  else
    status("Original Size enabled: moved layouts keep their stored size, leaving extra room when the destination is larger.")
  end
end

for n=1,7 do
  local i=n
  signalTable["Identify"..i]=function() identify(i) end
  signalTable["Change"..i]=function() choose(i) end
end

local function open()
  ensureUtilityTag()
  theme()
  local d=GetFocusDisplay(); if Obj.Index(d)>5 then d=GetDisplayByIndex(1) end
  safe(function()
    local plugin=my_handle:Parent()
    -- Reuse the original imported appearance identity on every update.
    local appearance=Root().ShowData.Appearances.TouchConfigurator
    if plugin and appearance then plugin.Appearance=appearance end
  end)
  local ov=d.ScreenOverlay; local old=ov:Find(APP,"BaseInput")
  if old then old:Parent():Delete(old:Index()) end
  local r=ov:Append("BaseInput"); ui.root=r; r.Name=APP; r.W=1120; r.H=760
  r.AlignmentH="Center"; r.AlignmentV="Center"; r.Columns=1; r.Rows=5; r.AutoClose="No"
  r.CloseOnEscape="Yes"; r.PluginComponent=my_handle; r.CanCoexistWithModal="Yes"
  safe(function()
    r[1][1].SizePolicy="Fixed"; r[1][1].Size="56"; r[1][2].SizePolicy="Fixed"; r[1][2].Size="68"
    r[1][3].SizePolicy="Fixed"; r[1][3].Size="8"; r[1][4].SizePolicy="Stretch"; r[1][5].SizePolicy="Fixed"; r[1][5].Size="48"
  end)
  local tb=r:Append("TitleBar"); tb.Anchors="0,0"; tb.Columns=3; tb.Rows=1; tb.Texture="corner2"
  safe(function()
    tb[1][1].SizePolicy="Stretch"
    tb[1][2].SizePolicy="Fixed"; tb[1][2].Size="230"
    tb[1][3].SizePolicy="Fixed"; tb[1][3].Size="132"
  end)
  local title=tb:Append("TitleButton"); title.Anchors="0,0"; title.Text="TOUCH CONFIGURATOR"; title.Texture="corner1"
  local fitEdge=tb:Append("UIObject"); fitEdge.Anchors="1,0"
  safe(function() fitEdge.Texture="corner15"; fitEdge.Margin={left=3,right=3,top=3,bottom=3}; fitEdge.BackColor=colors.green end)
  ui.fit=tb:Append("Button"); ui.fit.Anchors="1,0"; ui.fit.Texture="corner15"; ui.fit.PluginComponent=my_handle; ui.fit.Clicked="ToggleFitMode"; ui.fit.HasHover="Yes"
  safe(function() ui.fit.Margin={left=8,right=8,top=8,bottom=8} end)
  refreshFitButton()
  local closeEdge=tb:Append("UIObject"); closeEdge.Anchors="2,0"
  safe(function() closeEdge.Texture="corner2"; closeEdge.Margin={left=2,right=2,top=2,bottom=2}; closeEdge.BackColor=colors.green end)
  local close=tb:Append("Button"); close.Anchors="2,0"; close.Text="CLOSE"; close.Texture="corner2"
  safe(function() close.Margin={left=7,right=7,top=7,bottom=7}; close.BackColor=colors.normal end)
  close.PluginComponent=my_handle; close.Clicked="Close"; close.HasHover="Yes"
  local hero=label(r,"0,1","IDENTIFY AND ASSIGN CONNECTED TOUCH SURFACES")
  safe(function() hero.TextalignmentH="Centre" end)
  label(r,"0,2","")
  ui.body=r:Append("UILayoutGrid"); ui.body.Anchors="0,3"
  ui.status=label(r,"0,4","Ready  •  grandMA3 "..tostring(Version()))
  render(); safe(function() r:WaitInit(2) end)
end

return function()
  local ok,e=pcall(open)
  if not ok then ErrPrintf("Touch Configurator: %s",tostring(e)) end
end
