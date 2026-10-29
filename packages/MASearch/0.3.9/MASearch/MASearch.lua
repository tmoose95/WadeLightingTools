-- MA Search v0.3.9
-- Author: Aaron Wade - Crossfade Design
-- Universal show-object search and safe navigation prototype for grandMA3 2.4.

local signalTable,my_handle=select(3,...),select(4,...)
local APP="MASearchUI"
local ui={root=nil,body=nil,status=nil,display=nil,results={},lastQuery=nil,mode="results",rowOffsets={},categoryRows={},poolChoice=1,poolFilterNumber=nil,pools={},poolButton=nil,screenButton=nil,targetScreen=nil,colorCleanup=nil,presetColors={},recovery=nil,returnOverlay=nil,currentPoolItem=nil,poolPageFirst=nil,locationMode="pool"}
local indexCache=nil

local function safe(fn,fallback) local ok,v=pcall(fn); if ok then return v end return fallback end
local function prop(o,n) return safe(function() return o:Get(n) end,safe(function() return o[n] end,nil)) end
local function children(o)
  local v=safe(function() return o:Children() end,nil)
  if type(v)=="table" then return v end
  v=safe(function() return o:CmdlineChildren() end,nil)
  return type(v)=="table" and v or {}
end
local function lower(v) return tostring(v or ""):lower() end
local function class(o) return lower(safe(function() return o:GetClass() end,safe(function() return o:GetClassName() end,""))) end
local function address(o) return tostring(safe(function() return ToAddr(o,true,true) end,safe(function() return o:AddrNative() end,"")) or "") end
local function quoted(s) return '"'..tostring(s or ""):gsub('"','\\"')..'"' end
local function objectIndex(o) return tonumber(safe(function() return Obj.Index(o) end,nil)) end
local function allChildren(o)
  local out,seen={},{}
  local function add(v)
    if not v then return end
    local id=safe(function() return HandleToInt(v) end,nil) or tostring(v)
    if not seen[id] then seen[id]=true; out[#out+1]=v end
  end
  for _,v in ipairs(children(o)) do add(v) end
  -- On some grandMA3 console builds Children() exposes only the currently
  -- selected DataPool. Numeric collection access still exposes every slot.
  local count=tonumber(safe(function() return Count(o) end,safe(function() return o:Count() end,0))) or 0
  for i=1,count do add(safe(function() return o[i] end,nil)) end
  return out
end
local function dataPoolNumber(o)
  local a=tostring(safe(function() return ToAddr(o,false,true) end,address(o)) or "")
  return tonumber(a:match("[Dd]ata[Pp]ool%s+(%d+)")) or objectIndex(o)
end

local function dataPools()
  local current=safe(function() return CurrentDataPool() end,safe(function() return DataPool() end,nil))
  local pools,seen={},{ }
  local function add(candidate)
    if not candidate then return end
    local c=class(candidate):gsub("[^%w]","")
    -- Console builds vary between DataPool and derived DataPoolData classes.
    -- A child's address contains its parent DataPool address too, so address
    -- text cannot identify a pool (it produced a false DP128). Require MA's
    -- actual DataPool class or a derived DataPool class instead.
    local isPool=safe(function() return IsClass(candidate,"DataPool") end,false)
    if (not isPool and not c:find("datapool",1,true)) or c:find("collect",1,true) then return end
    local id=safe(function() return HandleToInt(candidate) end,nil) or tostring(candidate)
    if not seen[id] then seen[id]=true; pools[#pools+1]=candidate end
  end
  local poolQueries={'DataPool Thru','DataPool *','DataPool 1 Thru 9999'}
  for _,query in ipairs(poolQueries) do
    for _,candidate in ipairs(safe(function() return ObjectList(query) end,{}) or {}) do add(candidate) end
  end
  local currentParent=current and safe(function() return current:Parent() end,nil)
  local collections={
    safe(function() return Root().ShowData.DataPools end,nil),
    safe(function() return Root().ShowData.DataPoolCollect end,nil),
    currentParent
  }
  for _,collection in ipairs(collections) do
    for _,candidate in ipairs(allChildren(collection)) do add(candidate) end
  end
  -- Property names for the DataPool collection vary between software builds.
  -- Discover it from the ShowData tree instead of depending on one property.
  local showData=safe(function() return Root().ShowData end,safe(function() return ShowData() end,nil))
  for _,level1 in ipairs(allChildren(showData)) do
    local c1=class(level1):gsub("[^%w]","")
    local a1=lower(address(level1)):gsub("[^%w]","")
    if c1:find("datapool",1,true) or a1:find("datapool",1,true) then
      for _,candidate in ipairs(allChildren(level1)) do add(candidate) end
    end
  end
  if #pools==0 and current then add(current) end
  table.sort(pools,function(a,b) return (dataPoolNumber(a) or 9999)<(dataPoolNumber(b) or 9999) end)
  return pools,current
end

local function setupPresetColors()
  local ct=safe(function() return Root().ColorTheme end,nil)
  local defs=ct and safe(function() return ct.ColorDefCollect.Global end,nil)
  local groups=ct and safe(function() return ct.ColorGroups end,nil)
  if not defs or not groups then return end
  local createdDefs,createdRefs,createdGroup={},{},false
  local group=safe(function() return groups.MASearchPresetPools end,nil)
  if not group then group=safe(function() return groups:Acquire() end,nil); if group then group.Name="MASearchPresetPools"; createdGroup=true end end
  local palette={DIMMER="BFC3C7FF",POSITION="D8B23EFF",GOBO="D88928FF",COLOR="32A9C7FF",BEAM="65B96EFF",FOCUS="8B69C6FF",CONTROL="D65B5BFF",SHAPERS="B45FC9FF",VIDEO="4B86D9FF",SELECTION="68A7D7FF",PHASER="61B66AFF",MATRICKS="B98D56FF",DEFAULT="A6A6A6FF"}
  for name,rgba in pairs(palette) do
    local defName="MASearchPreset"..name
    local d=safe(function() return defs[defName] end,nil)
    if not d then d=safe(function() return defs:Acquire() end,nil); if d then d.Name=defName; createdDefs[#createdDefs+1]=d end end
    if d then safe(function() d:Set("rgba",rgba) end) end
    local ref=group and safe(function() return group[name] end,nil)
    if group and not ref then ref=safe(function() return group:Acquire() end,nil); if ref then ref.Name=name; createdRefs[#createdRefs+1]=ref end end
    if ref and d then safe(function() ref:Set("ColorDefRef",HandleToStr(d)) end) end
    ui.presetColors[name]=ref
  end
  ui.colorCleanup=function()
    if createdGroup and group then safe(function() group:Parent():Delete(group:Index()) end)
    else for n=#createdRefs,1,-1 do local o=createdRefs[n]; safe(function() o:Parent():Delete(o:Index()) end) end end
    for n=#createdDefs,1,-1 do local o=createdDefs[n]; safe(function() o:Parent():Delete(o:Index()) end) end
  end
end

local function presetInfo(item)
  if not item or item.kind~="PRESET" then return nil end
  local pool=safe(function() return item.object:Parent() end,nil)
  local poolNumber,presetNumber=objectIndex(pool),objectIndex(item.object)
  local poolName=tostring(prop(pool,"Name") or "Preset"):upper()
  local key=poolName:gsub("[^A-Z]",""); local ref=ui.presetColors[key]
  if not ref then for name,candidate in pairs(ui.presetColors) do if name~="DEFAULT" and key:find(name,1,true) then ref=candidate break end end end
  return {number=(poolNumber and presetNumber) and (poolNumber.."."..presetNumber) or item.address,pool=poolName,color=ref or ui.presetColors.DEFAULT}
end

local function ensureUtilityTag()
  local tagName="Utility Plugins"
  local tag=nil
  for _,candidate in ipairs(safe(function() return ObjectList('Tag Thru') end,{}) or {}) do
    if lower(prop(candidate,"Name"))==lower(tagName) then tag=candidate break end
  end
  if not tag then safe(function() Cmd('Store Tag '..quoted(tagName)..' /NoConfirmation') end) end
  tag=tag or safe(function()
    for _,candidate in ipairs(ObjectList('Tag Thru') or {}) do if lower(prop(candidate,"Name"))==lower(tagName) then return candidate end end
  end,nil)
  local plugin=safe(function() return my_handle:Parent() end,nil)
  local ti=tag and safe(function() return Obj.Index(tag) end,nil)
  local pi=plugin and safe(function() return Obj.Index(plugin) end,nil)
  if not ti or not pi then return end
  local pluginHandle=safe(function() return HandleToInt(plugin) end,nil)
  local references=tag and (safe(function() return tag:GetReferences() end,{}) or {}) or {}
  for _,reference in pairs(references) do
    if reference==plugin then return end
    if pluginHandle and safe(function() return HandleToInt(reference) end,nil)==pluginHandle then return end
  end
  -- Assign only when this plugin is not already referenced by Utility Plugins.
  safe(function() Cmd('Assign Tag '..ti..' At Plugin '..pi..' Property "Tags" /NoConfirmation') end)
end

local function display()
  local d=safe(function() return GetFocusDisplay() end,nil)
  if not d or (tonumber(safe(function() return Obj.Index(d) end,1)) or 1)>7 then d=safe(function() return GetDisplayByIndex(1) end,d) end
  return d
end

local function toast(message,bad)
  local d=ui.display or display(); if not d then return end
  local ov=safe(function() return d.ScreenOverlay end,nil); if not ov then return end
  local old=safe(function() return ov:Find(APP.."Notifier","UIObject") end,nil)
  if old then safe(function() old:Parent():Delete(old:Index()) end) end
  local t=safe(function() return ov:Append("UIObject") end,nil); if not t then return end
  t.Name=APP.."Notifier"; t.W=540; t.H=116
  t.X=math.max(0,(tonumber(prop(d,"W")) or 1920)-568); t.Y=28
  t.Texture="corner15"; t.Text=(bad and "CLIPPY  !  " or "CLIPPY  •  ")..tostring(message)
  safe(function() t.TextalignmentH="Centre"; t.TextalignmentV="Centre" end)
  -- Timer callbacks run on MA's non-UI Lua thread and must never mutate UI.
  -- Yield back through the UI scheduler before the temporary object is removed.
  coroutine.yield({ui=1})
  coroutine.yield(3.2)
  coroutine.yield({ui=1})
  safe(function() t:Parent():Delete(t:Index()) end)
end

local TYPES={
  {key="recipe",label="RECIPE",plural="RECIPES"},
  {key="executor",label="EXECUTOR",plural="EXECUTORS"},
  {key="timecode",label="TIMECODE",plural="TIMECODES"},
  {key="preset",label="PRESET",plural="PRESETS"},
  {key="sequence",label="SEQUENCE",plural="SEQUENCES"},
  {key="cue",label="CUE",plural="CUES"},
  {key="group",label="GROUP",plural="GROUPS"},
  {key="macro",label="MACRO",plural="MACROS"},
  {key="plugin",label="PLUGIN",plural="PLUGINS"},
  {key="view",label="VIEW",plural="VIEWS"},
  {key="layout",label="LAYOUT",plural="LAYOUTS"},
  {key="page",label="PAGE",plural="PAGES"}
}
local CLASS_KIND={
  recipe="RECIPE",executor="EXECUTOR",timecode="TIMECODE",preset="PRESET",
  sequence="SEQUENCE",cue="CUE",group="GROUP",macro="MACRO",plugin="PLUGIN",
  view="VIEW",layout="LAYOUT",page="PAGE"
}
local PLURAL={}
for _,t in ipairs(TYPES) do PLURAL[t.label]=t.plural end
local function kindFor(o)
  -- Only index the object's own class. Never inherit a parent collection's
  -- type: LayoutElement, TimecodeMarker, CuePart, etc. are not Layouts,
  -- Timecodes or Cues themselves.
  local c=class(o):gsub("[^%w]","")
  return CLASS_KIND[c]
end

local function buildIndex()
  local out,seen={},{}
  local function addObject(o,pool)
    if not o then return false end
    local id=safe(function() return HandleToInt(o) end,tostring(o))
    if seen[id] then return false end
    seen[id]=true
    local n=tostring(prop(o,"Name") or "")
    local k=kindFor(o); local a=address(o)
    local poolName=pool and tostring(prop(pool,"Name") or "") or ""
    local poolIndex=pool and dataPoolNumber(pool) or nil
    if k and n~="" and a~="" then
      out[#out+1]={object=o,name=n,kind=k,address=a,dataPool=poolName,dataPoolIndex=poolIndex,hay=lower(n.." "..a.." "..k.." "..poolName)}
    end
    return true
  end
  local function addTree(root,hint,depth,maxDepth,pool)
    if not root or depth>maxDepth then return end
    for _,o in ipairs(children(root)) do
      if addObject(o,pool) then
        addTree(o,hint,depth+1,maxDepth,pool)
      end
    end
  end
  local function addDirect(query,pool)
    for _,o in ipairs(safe(function() return ObjectList(query) end,{}) or {}) do
      if addObject(o,pool) then addTree(o,"",1,5,pool) end
    end
  end
  local current
  ui.pools,current=dataPools()
  -- Always build the complete discoverable index. Filtering is applied after
  -- indexing by DP number, so it still works when MA hides DataPool handles.
  local selected=nil
  for _,dp in ipairs(ui.pools) do addTree(dp,"",1,7,dp) end
  if #ui.pools==0 and current then addTree(current,"",1,7,current) end

  -- Some console builds expose DataPool collections without traversable Lua
  -- children. Query every searchable command-line pool directly as a second,
  -- deduplicated path so indexing cannot silently collapse to zero.
  local directPools={}
  if selected then directPools={selected}
  elseif #ui.pools>0 then directPools=ui.pools
  elseif current then directPools={current} end
  local directKinds={"Preset Thru","Sequence Thru","Group Thru","Macro Thru","Timecode Thru","Page Thru","Layout Thru","Executor Thru"}
  local originalPool=current and dataPoolNumber(current) or nil
  if #directPools>0 then
    for _,dp in ipairs(directPools) do
      local number=dataPoolNumber(dp)
      -- ObjectList ignores a prefixed DataPool address on some consoles. Make
      -- that DP the real query context, verify MA actually switched, read the
      -- unqualified pools, then restore. Never attach a requested DP label to
      -- objects when the console silently kept another Data Pool selected.
      if number then safe(function() Cmd('Select DataPool '..number) end) end
      local active=safe(function() return CurrentDataPool() end,safe(function() return DataPool() end,nil))
      local activeNumber=active and dataPoolNumber(active) or nil
      if number and activeNumber==number then
        for _,suffix in ipairs(directKinds) do addDirect(suffix,active) end
      end
    end
    if originalPool then safe(function() Cmd('Select DataPool '..originalPool) end) end
  else
    for _,suffix in ipairs(directKinds) do addDirect(suffix,nil) end
  end
  local sd=safe(function() return ShowData() end,nil)
  if sd then
    addTree(safe(function() return sd.Plugins end,nil),"plugin",1,2)
    addTree(safe(function() return sd.Macros end,nil),"macro",1,2)
  end
  local profile=safe(function() return CurrentProfile() end,nil)
  if profile then addTree(safe(function() return profile.Views end,nil),"view",1,2) end
  indexCache=out
  return out
end

local function poolChoiceLabel()
  if not ui.poolFilterNumber then
    return "ALL DATA POOLS"
  end
  local name=""
  for _,p in ipairs(ui.pools) do if dataPoolNumber(p)==ui.poolFilterNumber then name=tostring(prop(p,"Name") or "") break end end
  return "DATA POOL "..tostring(ui.poolFilterNumber)..(name~="" and ("  •  "..name) or "")
end

local function availablePoolNumbers()
  local numbers,seen={},{}
  for _,p in ipairs(ui.pools or {}) do local n=dataPoolNumber(p); if n and not seen[n] then seen[n]=true; numbers[#numbers+1]=n end end
  for _,item in ipairs(indexCache or {}) do local n=tonumber(item.dataPoolIndex); if n and not seen[n] then seen[n]=true; numbers[#numbers+1]=n end end
  table.sort(numbers); return numbers
end
local function poolFilterLabel(number)
  local name=""
  for _,p in ipairs(ui.pools or {}) do
    if dataPoolNumber(p)==number then name=tostring(prop(p,"Name") or ""); break end
  end
  return "DATA POOL "..tostring(number)..(name~="" and ("  •  "..name) or "")
end

local function score(item,query)
  local q=lower(query); local n=lower(item.name); local a=lower(item.address)
  if n==q then return 1000 end
  if a==q then return 950 end
  if n:sub(1,#q)==q then return 800-#n end
  local p=n:find(q,1,true); if p then return 650-p end
  p=item.hay:find(q,1,true); if p then return 400-p end
  local total,last=0,1
  for token in q:gmatch("%S+") do local x=item.hay:find(token,last,true); if not x then return 0 end; total=total+40; last=x+#token end
  return total
end

local function search(query)
  local found={}
  for _,item in ipairs(indexCache or buildIndex()) do
    if not ui.poolFilterNumber or tonumber(item.dataPoolIndex)==ui.poolFilterNumber or not item.dataPoolIndex then
      local s=score(item,query); if s>0 then item.score=s; found[#found+1]=item end
    end
  end
  table.sort(found,function(a,b) if a.score==b.score then return a.address<b.address end return a.score>b.score end)
  return found
end

local function clearBody()
  if ui.body then safe(function() ui.body:ClearUIChildren() end) end
end

local function styleText(o,left)
  safe(function()
    o.TextAutoAdjust="Yes"; o.TextalignmentV="Centre"; o.TextalignmentH=left and "Left" or "Centre"
    if left then o.Padding={left=12,right=8,top=4,bottom=4} end
  end)
end

local renderResults
local function activeScreenNumber()
  return tonumber(safe(function() return Obj.Index(ui.display or display()) end,1)) or 1
end

local function availableScreens()
  local out={}
  for i=1,7 do if safe(function() return GetDisplayByIndex(i) end,nil) then out[#out+1]=i end end
  if #out==0 then out[1]=activeScreenNumber() end
  return out
end

local function screenLabel()
  return "NATIVE VIEW SCREEN  •  DISPLAY "..tostring(ui.targetScreen or activeScreenNumber())
end

local WINDOW_NAME={RECIPE="Recipes",EXECUTOR="Playbacks",TIMECODE="Timecodes",SEQUENCE="Sequences",CUE="Sequences",GROUP="Groups",MACRO="Macros",PLUGIN="Plugins",VIEW="Views",LAYOUT="Layouts",PAGE="Pages"}

local function viewsPool()
  local p=safe(function() return CurrentProfile() end,nil)
  return p and safe(function() return p.Views end,nil)
end

local function freeViewIndex()
  local used={}
  for _,v in ipairs(children(viewsPool())) do local i=objectIndex(v); if i then used[i]=true end end
  for i=9999,9000,-1 do if not used[i] then return i end end
end

local function absoluteXY(o)
  local x,y=0,0; local guard=0
  while o and guard<20 do
    x=x+(tonumber(prop(o,"X")) or 0); y=y+(tonumber(prop(o,"Y")) or 0)
    o=safe(function() return o:Parent() end,nil); guard=guard+1
  end
  return x,y
end

local function clickObject(o,screen)
  if not o then return false end
  local touched=safe(function() TouchObj(o); return true end,false)
  if touched then return true end
  local x,y=absoluteXY(o); x=x+math.max(4,(tonumber(prop(o,"W")) or 8)/2); y=y+math.max(4,(tonumber(prop(o,"H")) or 8)/2)
  safe(function() Mouse(screen,"move",math.floor(x),math.floor(y)) end)
  safe(function() Mouse(screen,"press","Left") end); safe(function() Mouse(screen,"release","Left") end)
  return true
end

local function findText(root,wanted)
  wanted=lower(wanted)
  local found=nil
  local function scan(o,depth)
    if not o or found or depth>12 then return end
    local text=lower(prop(o,"Text") or prop(o,"Name"))
    if text==wanted then found=o return end
    for _,c in ipairs(children(o)) do scan(c,depth+1) end
  end
  scan(root,0); return found
end

local function nativeWindowName(item)
  if item.kind=="PRESET" then
    local parent=safe(function() return item.object:Parent() end,nil)
    return tostring(prop(parent,"Name") or "Dynamic")
  end
  return WINDOW_NAME[item.kind]
end

function signalTable.ReturnWorkspace()
  local recovery=ui.recovery
  if not recovery then return end
  -- Clear first so deleting the overlay cannot recursively run this callback.
  ui.recovery=nil
  if ui.returnOverlay then safe(function() ui.returnOverlay:Parent():Delete(ui.returnOverlay:Index()) end); ui.returnOverlay=nil end
  safe(function() Cmd(string.format('Call View %d /Screen "%d"',recovery.index,recovery.screen)) end)
  if recovery.dataPoolBefore then safe(function() Cmd('Select DataPool '..tostring(recovery.dataPoolBefore)) end) end
  coroutine.yield({ui=1}); coroutine.yield(0.1)
  if recovery.handle then safe(function() recovery.handle:Parent():Delete(recovery.handle:Index()) end) end
end

local function uiChildren(o)
  local list=safe(function() return UIChildren(o) end,nil)
  return type(list)=="table" and list or children(o)
end

local function locateNativeGrid(item,screen)
  local d=safe(function() return GetDisplayByIndex(screen) end,nil); if not d then return false end
  local wanted=lower(item.name); local wantedIndex=objectIndex(item.object) or 1
  local best=nil
  local function consider(grid)
    local dimensions=safe(function() return GridGetDimensions(grid) end,nil)
    if type(dimensions)~="table" then return end
    local cols=tonumber(dimensions.c or dimensions[2]); if not cols or cols<2 then return end
    local zero={r=math.floor((wantedIndex-1)/cols),c=(wantedIndex-1)%cols}
    local cells={zero,{r=zero.r+1,c=zero.c+1}}
    for _,cell in ipairs(cells) do
      if safe(function() return GridCellExists(grid,cell) end,false) then
        local data=safe(function() return GridGetCellData(grid,cell) end,nil)
        local text=type(data)=="table" and lower(data.text) or ""
        local score=(text~="" and text:find(wanted,1,true)) and 100 or 10
        if not best or score>best.score then best={grid=grid,cell=cell,score=score} end
      end
    end
  end
  local function scan(o,depth)
    if not o or depth>16 then return end
    consider(o)
    for _,child in ipairs(uiChildren(o)) do scan(child,depth+1) end
  end
  scan(d,0)
  if not best then return false end
  safe(function() GridScrollCellIntoView(best.grid,best.cell) end)
  coroutine.yield({ui=1}); coroutine.yield(0.2)
  local rect=safe(function() return GridGetCellDimensions(best.grid,best.cell) end,nil)
  if type(rect)=="table" then
    local gx,gy=absoluteXY(best.grid)
    local x=gx+(tonumber(rect.x) or 0)+(tonumber(rect.w) or 0)/2
    local y=gy+(tonumber(rect.y) or 0)+(tonumber(rect.h) or 0)/2
    safe(function() DrawPointer(screen,{x=math.floor(x),y=math.floor(y)},5000) end)
  end
  return true
end

local function addReturnOverlay(item)
  local screen=ui.recovery and ui.recovery.screen or ui.targetScreen or activeScreenNumber()
  local d=safe(function() return GetDisplayByIndex(screen) end,nil) or ui.display or display(); local ov=d and d.ScreenOverlay; if not ov then return end
  local r=ov:Append("BaseInput"); ui.returnOverlay=r; r.Name=APP.."Return"; r.W=620; r.H=82; r.X=28; r.Y=28; r.Columns=2; r.Rows=1
  r.AutoClose="No"; r.CloseOnEscape="Yes"; r.PluginComponent=my_handle; r.CanCoexistWithModal="Yes"
  safe(function() OverlaySetCloseCallback(r,"ReturnWorkspace") end)
  local b=r:Append("Button"); b.Anchors="0,0"; b.Text="‹  RETURN TO PREVIOUS WORKSPACE"; b.Texture="corner15"; b.PluginComponent=my_handle; b.Clicked="ReturnWorkspace"
  local label=r:Append("UIObject"); label.Anchors="1,0"; label.Text="LOCATED  •  "..item.address.."\n"..item.name; styleText(label,false)
end

local function openNativePool(item)
  local windowName=nativeWindowName(item)
  if not windowName then toast("This object type has no mapped native MA window yet",true); return end
  local slot=freeViewIndex(); if not slot then toast("No unused temporary View slot was available",true); return end
  local screen=ui.targetScreen or activeScreenNumber()
  safe(function() Cmd(string.format('Store View %d "__MASearch_Recovery_S%d__" /Screen "%d" /NoConfirmation',slot,screen,screen)) end)
  local handle=(safe(function() return ObjectList("View "..slot) end,{}) or {})[1]
  if not handle then toast("Could not create the temporary recovery View",true); return end
  local beforePool=safe(function() return CurrentDataPool() end,safe(function() return DataPool() end,nil))
  local beforeNumber=beforePool and dataPoolNumber(beforePool) or nil
  ui.recovery={index=slot,screen=screen,handle=handle,dataPoolBefore=beforeNumber}
  if item.dataPoolIndex then safe(function() Cmd('Select DataPool '..tostring(item.dataPoolIndex)) end); coroutine.yield({ui=1}); coroutine.yield(0.1) end
  if ui.root then safe(function() ui.root:Parent():Delete(ui.root:Index()) end); ui.root=nil end
  safe(function() Cmd(string.format('Delete ScreenContent Default %d /NoConfirmation',screen)) end)
  coroutine.yield({ui=1}); coroutine.yield(0.12)
  local d=safe(function() return GetDisplayByIndex(screen) end,nil) or ui.display or display(); local w=tonumber(prop(d,"W")) or 1920; local h=tonumber(prop(d,"H")) or 1080
  local point={x=math.floor(w/2),y=math.floor(h*0.38)}
  local empty=safe(function() return GetUIObjectAtPosition(screen,point) end,nil)
  if not (empty and safe(function() TouchObj(empty); return true end,false)) then
    safe(function() Mouse(screen,"move",point.x,point.y) end)
    safe(function() Mouse(screen,"press","Left") end); safe(function() Mouse(screen,"release","Left") end)
  end
  coroutine.yield({ui=1}); coroutine.yield(0.15)
  local top=safe(function() return GetTopOverlay(screen) end,nil)
  local all=findText(top,"All"); if all then clickObject(all,screen); coroutine.yield({ui=1}); coroutine.yield(0.1); top=safe(function() return GetTopOverlay(screen) end,top) end
  local target=findText(top,windowName)
  if not target then
    signalTable.ReturnWorkspace(); toast("MA Add Window did not expose "..windowName,true); return
  end
  clickObject(target,screen); coroutine.yield({ui=1}); coroutine.yield(0.35)
  local positioned=locateNativeGrid(item,screen)
  addReturnOverlay(item)
  if not positioned then toast("Native pool opened, but MA did not expose a scrollable grid for "..item.address,true) end
end

local function restoreOrphanRecovery()
  local pool=viewsPool(); if not pool then return false end
  for _,view in ipairs(children(pool)) do
    local name=tostring(prop(view,"Name") or "")
    local screen=tonumber(name:match("^__MASearch_Recovery_S(%d+)__$"))
    if screen then
      local index=objectIndex(view)
      if index then
        safe(function() Cmd(string.format('Call View %d /Screen "%d"',index,screen)) end)
        coroutine.yield({ui=1}); coroutine.yield(0.1)
        safe(function() view:Parent():Delete(view:Index()) end)
        return true
      end
    end
  end
  return false
end

local function renderPool(item,requestedFirst,requestedMode)
  if not item or not item.object then return end
  clearBody(); ui.mode="location"; ui.currentPoolItem=item; ui.locationMode=requestedMode or ui.locationMode or "pool"
  local g=ui.body; g.Columns=1; g.Rows=3
  safe(function() g[1][1].SizePolicy="Fixed"; g[1][1].Size="74"; g[1][2].SizePolicy="Fixed"; g[1][2].Size="54"; g[1][3].SizePolicy="Stretch" end)
  local top=g:Append("UILayoutGrid"); top.Anchors="0,0"; top.Columns=5; top.Rows=1
  local back=top:Append("Button"); back.Anchors="0,0"; back.Text="‹  BACK TO RESULTS"; back.Texture="corner15"; back.PluginComponent=my_handle; back.Clicked="BackResults"; styleText(back,false)
  local previous=top:Append("Button"); previous.Anchors="1,0"; previous.Text="‹  PREVIOUS PAGE"; previous.Texture="corner15"; previous.PluginComponent=my_handle; previous.Clicked="PoolPrev"; styleText(previous,false)
  local title=top:Append("UIObject"); title.Anchors="2,0"; title.Text=(PLURAL[item.kind] or item.kind).."  •  "..string.upper(ui.locationMode); styleText(title,false)
  local nextPage=top:Append("Button"); nextPage.Anchors="3,0"; nextPage.Text="NEXT PAGE  ›"; nextPage.Texture="corner15"; nextPage.PluginComponent=my_handle; nextPage.Clicked="PoolNext"; styleText(nextPage,false)
  local again=top:Append("Button"); again.Anchors="4,0"; again.Text="NEW SEARCH"; again.Texture="corner15"; again.PluginComponent=my_handle; again.Clicked="Search"; styleText(again,false)
  local parent=safe(function() return item.object:Parent() end,nil)
  local parentAddress=parent and address(parent) or "Unknown container"
  local info=g:Append("UIObject"); info.Anchors="0,1"
  local dpText=item.dataPoolIndex and ("DATA POOL "..tostring(item.dataPoolIndex)..(item.dataPool and item.dataPool~="" and ("  •  "..item.dataPool) or "")) or "GLOBAL / PROFILE OBJECT"
  info.Text=dpText.."  •  SELECTED: "..item.address.."  •  "..item.name.."\nPARENT: "..parentAddress
  styleText(info,false)

  local targetIndex=tonumber(safe(function() return Obj.Index(item.object) end,nil)) or 1
  local cols,rows=10,6
  local pageSize=ui.locationMode=="sheet" and 12 or cols*rows
  local targetFirst=math.floor((math.max(1,targetIndex)-1)/pageSize)*pageSize+1
  local first=math.max(1,requestedFirst or targetFirst); ui.poolPageFirst=first
  local byIndex={}
  if parent then
    for _,sibling in ipairs(allChildren(parent)) do
      local idx=tonumber(safe(function() return Obj.Index(sibling) end,nil))
      if idx then byIndex[idx]=sibling end
    end
  end
  local shell=g:Append("UILayoutGrid"); shell.Anchors="0,2"; shell.Columns=2; shell.Rows=1
  safe(function() shell[1][1].SizePolicy="Fixed"; shell[1][1].Size="150"; shell[1][2].SizePolicy="Stretch" end)
  local tabs=shell:Append("UILayoutGrid"); tabs.Anchors="0,0"; tabs.Columns=1; tabs.Rows=3
  local poolTab=tabs:Append("Button"); poolTab.Anchors="0,0"; poolTab.Text="POOL"; poolTab.Texture="corner15"; poolTab.PluginComponent=my_handle; poolTab.Clicked="ShowPool"; styleText(poolTab,false)
  local sheetTab=tabs:Append("Button"); sheetTab.Anchors="0,1"; sheetTab.Text="SHEET"; sheetTab.Texture="corner15"; sheetTab.PluginComponent=my_handle; sheetTab.Clicked="ShowSheet"; styleText(sheetTab,false)
  local marker=tabs:Append("UIObject"); marker.Anchors="0,2"; marker.Text="SELECTED\n"..tostring(targetIndex); marker.Texture="corner15"; styleText(marker,false)
  safe(function()
    local active=Root().ColorTheme.ColorGroups.Button.BackgroundPlease
    local normal=Root().ColorTheme.ColorGroups.Button.BackgroundNormal
    poolTab.BackColor=ui.locationMode=="pool" and active or normal
    sheetTab.BackColor=ui.locationMode=="sheet" and active or normal
    marker.BackColor=active
  end)

  if ui.locationMode=="sheet" then
    local sheet=shell:Append("UILayoutGrid"); sheet.Anchors="1,0"; sheet.Columns=3; sheet.Rows=13
    local headers={"#","NAME","OBJECT ADDRESS"}
    for c=0,2 do local h=sheet:Append("UIObject"); h.Anchors=c..",0"; h.Text=headers[c+1]; h.Texture="corner15"; h.Margin={left=3,right=3,top=3,bottom=3}; styleText(h,false); safe(function() h.BackColor=Root().ColorTheme.ColorGroups.Button.BackgroundPlease end) end
    for offset=0,pageSize-1 do
      local idx=first+offset; local sibling=byIndex[idx]; local row=offset+1
      local values={tostring(idx),sibling and tostring(prop(sibling,"Name") or "") or "",sibling and address(sibling) or ""}
      for c=0,2 do
        local cell=sheet:Append("UIObject"); cell.Anchors=c..","..row; cell.Text=values[c+1]; cell.Texture="corner15"; cell.Margin={left=3,right=3,top=2,bottom=2}; styleText(cell,c>0)
        safe(function() cell.BackColor=idx==targetIndex and Root().ColorTheme.ColorGroups.Button.BackgroundPlease or Root().ColorTheme.ColorGroups.Button.BackgroundNormal end)
      end
    end
  else
    local pool=shell:Append("UILayoutGrid"); pool.Anchors="1,0"; pool.Columns=cols; pool.Rows=rows
    for offset=0,pageSize-1 do
      local idx=first+offset; local sibling=byIndex[idx]
      local tile=pool:Append("UIObject"); tile.Anchors=tostring(offset%cols)..","..tostring(math.floor(offset/cols)); tile.Texture="corner15"; tile.Margin={left=3,right=3,top=3,bottom=3}
      local n=sibling and tostring(prop(sibling,"Name") or "") or ""
      tile.Text=tostring(idx)..(n~="" and ("\n"..n) or "")
      styleText(tile,false)
      if sibling then local appearance=prop(sibling,"Appearance"); if appearance then safe(function() tile.Appearance=appearance end) end end
      safe(function() tile.BackColor=idx==targetIndex and Root().ColorTheme.ColorGroups.Button.BackgroundPlease or Root().ColorTheme.ColorGroups.Button.BackgroundNormal end)
    end
  end
  if ui.status then ui.status.Text="SAFE "..string.upper(ui.locationMode).." VIEW  •  SHOWING "..first.."–"..(first+pageSize-1).."  •  OBJECT "..targetIndex.." IS HIGHLIGHTED  •  NOTHING WAS CALLED" end
end

local function openLocation(item)
  if not item then return end
  ui.locationMode="pool"
  renderPool(item,nil,"pool")
end

renderResults=function(query)
  clearBody(); ui.mode="results"
  if query~=ui.lastQuery then ui.rowOffsets={} end
  ui.lastQuery=query; ui.results={}; ui.categoryRows={}
  local all=search(query); local grouped={}
  for _,item in ipairs(all) do grouped[item.kind]=grouped[item.kind] or {}; grouped[item.kind][#grouped[item.kind]+1]=item end
  local categories={}
  for _,t in ipairs(TYPES) do if grouped[t.label] and #grouped[t.label]>0 then categories[#categories+1]=t end end
  local maxCategories=10
  while #categories>maxCategories do table.remove(categories) end
  local g=ui.body
  if #categories==0 then
    g.Columns=1; g.Rows=2
    local head=g:Append("UIObject"); head.Anchors="0,0"; head.Text='NO RESULTS FOR  "'..query..'"'; styleText(head,false)
    local x=g:Append("UIObject"); x.Anchors="0,1"; x.Text="Try a shorter name, object number, or press REFRESH INDEX."; styleText(x,false)
  else
    -- Use one flat grid. Nested UILayoutGrids caused MA to collapse text and
    -- ignore portions of the paging geometry on console hardware.
    g.Columns=8; g.Rows=math.max(8,#categories)
    for categoryRow,t in ipairs(categories) do
      local list=grouped[t.label]; local pageSize=5
      local rowMargin={left=3,right=3,top=5,bottom=5}
      local offset=math.max(0,math.min(ui.rowOffsets[t.label] or 0,math.max(0,#list-1)))
      ui.rowOffsets[t.label]=offset; ui.categoryRows[categoryRow]=t.label
      local y=categoryRow-1
      local header=g:Append("UIObject"); header.Anchors="0,"..y; header.Text=t.plural.." ("..#list..")"; header.Texture="corner15"; header.Margin=rowMargin; styleText(header,false)
      safe(function()
        header.BackColor=Root().ColorTheme.ColorGroups.Button.BackgroundPlease
        header.TextColor=Root().ColorTheme.ColorGroups.Button.TextNormal
      end)
      local previous=g:Append("Button"); previous.Anchors="1,"..y; previous.Texture="corner15"; previous.Margin=rowMargin; previous.Text=offset>0 and ("◀  SCROLL\n"..offset.." / "..#list) or "◀  SCROLL"
      if offset>0 then previous.PluginComponent=my_handle; previous.Clicked="RowPrev"..categoryRow else safe(function() previous.BackColor=Root().ColorTheme.ColorGroups.Button.BackgroundDisabled end) end
      styleText(previous,false)
      for slot=1,pageSize do
        local item=list[offset+slot]
        if item then
          ui.results[#ui.results+1]=item; local resultIndex=#ui.results
          local anchor=tostring(slot+1)..","..y
          local pi=presetInfo(item)
          if pi and pi.color then
            local edge=g:Append("UIObject"); edge.Anchors=anchor; edge.Texture="corner15"; edge.Margin={left=3,right=3,top=5,bottom=5}; edge.BackColor=pi.color
          end
          local b=g:Append("Button"); b.Anchors=anchor; b.Texture="corner15"; b.Margin=rowMargin
          local dpPrefix=(not ui.poolFilterNumber and item.dataPoolIndex) and ("DP"..item.dataPoolIndex.."  •  ") or ""
          if pi then b.Margin={left=8,right=8,top=10,bottom=10}; b.Text=dpPrefix..pi.number.."  •  "..pi.pool.."\n"..item.name
          elseif dpPrefix~="" then b.Text=dpPrefix.."\n"..item.name else b.Text=item.name end
          b.PluginComponent=my_handle; b.Clicked="Locate"..resultIndex; styleText(b,false)
          safe(function() b.TextColor=Root().ColorTheme.ColorGroups.Button.TextNormal end)
        else
          local blank=g:Append("UIObject"); blank.Anchors=tostring(slot+1)..","..y; blank.Text=""; blank.Texture="corner15"; blank.Margin=rowMargin
          safe(function() blank.BackColor=Root().ColorTheme.ColorGroups.Button.BackgroundDisabled end)
        end
      end
      local hasNext=offset+pageSize<#list
      local nextButton=g:Append("Button"); nextButton.Anchors="7,"..y; nextButton.Texture="corner15"; nextButton.Margin=rowMargin; nextButton.Text=hasNext and ("SCROLL  ▶\n"..math.min(offset+2,#list).." / "..#list) or "SCROLL  ▶"
      if hasNext then nextButton.PluginComponent=my_handle; nextButton.Clicked="RowNext"..categoryRow else safe(function() nextButton.BackColor=Root().ColorTheme.ColorGroups.Button.BackgroundDisabled end) end
      styleText(nextButton,false)
    end
  end
  if ui.status then ui.status.Text=#all.." matching object(s)  •  "..poolChoiceLabel().."  •  Select a tile to open its MA-style pool overlay" end
end

function signalTable.Close() if ui.root then safe(function() ui.root:Parent():Delete(ui.root:Index()) end) end; ui.root=nil; if ui.colorCleanup then ui.colorCleanup(); ui.colorCleanup=nil end end
function signalTable.Search()
  local q=TextInput("MA SEARCH","Search presets, recipes, executors, sequences, timecodes, cues, macros...")
  if q and tostring(q):match("%S") then renderResults(tostring(q)) end
end
function signalTable.Refresh() indexCache=nil; buildIndex(); toast("Search index refreshed",false); if ui.status then ui.status.Text="Index refreshed  •  "..#indexCache.." named objects" end end
function signalTable.ChoosePool()
  -- Plain string items match MA's documented PopupInput form and return the
  -- selected label consistently on console. Keep the returned index as a
  -- fallback for builds that do not return the label in the second value.
  local items={'ALL DATA POOLS'}
  for _,number in ipairs(availablePoolNumbers()) do items[#items+1]=poolFilterLabel(number) end
  local selected=ui.poolFilterNumber and poolFilterLabel(ui.poolFilterNumber) or 'ALL DATA POOLS'
  local a,b=PopupInput({title="MA Search Data Pool Filter",caller=GetFocusDisplay(),items=items,selectedValue=selected})
  local picked=type(b)=="string" and b or (type(a)=="string" and a or nil)
  local parsed=picked and tonumber(picked:match("DATA POOL%s+(%d+)")) or nil
  if not picked or (picked~='ALL DATA POOLS' and not parsed) then
    local index=tonumber(a)
    if index then picked=items[index] or items[index+1] end
  end
  if not picked then return end
  ui.poolFilterNumber=tonumber(picked:match("DATA POOL%s+(%d+)"))
  if ui.poolButton then ui.poolButton.Text=poolChoiceLabel() end
  ui.rowOffsets={}
  if ui.lastQuery then renderResults(ui.lastQuery) elseif ui.status then ui.status.Text="Ready  •  "..#(indexCache or {}).." named objects  •  "..poolChoiceLabel() end
end
function signalTable.PoolPrev() if ui.currentPoolItem then local step=ui.locationMode=="sheet" and 12 or 60; renderPool(ui.currentPoolItem,math.max(1,(ui.poolPageFirst or 1)-step),ui.locationMode) end end
function signalTable.PoolNext() if ui.currentPoolItem then local step=ui.locationMode=="sheet" and 12 or 60; renderPool(ui.currentPoolItem,(ui.poolPageFirst or 1)+step,ui.locationMode) end end
function signalTable.ShowPool() if ui.currentPoolItem then ui.locationMode="pool"; renderPool(ui.currentPoolItem,nil,"pool") end end
function signalTable.ShowSheet() if ui.currentPoolItem then ui.locationMode="sheet"; renderPool(ui.currentPoolItem,nil,"sheet") end end
function signalTable.CycleScreen()
  local screens=availableScreens(); local current=ui.targetScreen or activeScreenNumber(); local at=1
  for i,value in ipairs(screens) do if value==current then at=i break end end
  ui.targetScreen=screens[(at%#screens)+1]
  if ui.screenButton then ui.screenButton.Text=screenLabel() end
end
function signalTable.BackResults() if ui.lastQuery then renderResults(ui.lastQuery) end end
for i=1,10 do
  local n=i
  signalTable["RowPrev"..i]=function()
    local kind=ui.categoryRows[n]; if not kind then return end
    ui.rowOffsets[kind]=math.max(0,(ui.rowOffsets[kind] or 0)-1); renderResults(ui.lastQuery)
  end
  signalTable["RowNext"..i]=function()
    local kind=ui.categoryRows[n]; if not kind then return end
    ui.rowOffsets[kind]=(ui.rowOffsets[kind] or 0)+1; renderResults(ui.lastQuery)
  end
end
for i=1,64 do
  local n=i
  signalTable["Locate"..i]=function()
    local ok,problem=xpcall(function() openLocation(ui.results[n]) end,debug.traceback)
    if not ok then
      if ui.recovery then signalTable.ReturnWorkspace() end
      ErrPrintf("MA Search navigation: %s",tostring(problem))
    end
  end
end

local function open()
  restoreOrphanRecovery()
  ensureUtilityTag(); ui.display=display(); local d=ui.display; if not d then error("No usable display") end
  ui.targetScreen=ui.targetScreen or activeScreenNumber()
  setupPresetColors()
  safe(function() local p=my_handle:Parent(); local a=Root().ShowData.Appearances.MASearch; if p and a then p.Appearance=a end end)
  local ov=d.ScreenOverlay; local old=ov:Find(APP,"BaseInput"); if old then old:Parent():Delete(old:Index()) end
  local r=ov:Append("BaseInput"); ui.root=r; r.Name=APP; r.W=1660; r.H=760; r.AlignmentH="Center"; r.AlignmentV="Center"
  r.Columns=1; r.Rows=4; r.AutoClose="No"; r.CloseOnEscape="Yes"; r.PluginComponent=my_handle; r.CanCoexistWithModal="Yes"
  safe(function() r[1][1].SizePolicy="Fixed"; r[1][1].Size="50"; r[1][2].SizePolicy="Fixed"; r[1][2].Size="54"; r[1][3].SizePolicy="Stretch"; r[1][4].SizePolicy="Fixed"; r[1][4].Size="38" end)
  local bar=r:Append("TitleBar"); bar.Anchors="0,0"; bar.Columns=2; bar.Rows=1; bar.Texture="corner2"
  local title=bar:Append("TitleButton"); title.Anchors="0,0"; title.Text="MA SEARCH  •  GRANDMA3 NAVIGATOR"; title.Texture="corner1"
  local close=bar:Append("Button"); close.Anchors="1,0"; close.Text="CLOSE"; close.Texture="corner2"; close.PluginComponent=my_handle; close.Clicked="Close"
  local tools=r:Append("UILayoutGrid"); tools.Anchors="0,1"; tools.Columns=5; tools.Rows=1
  local prompt=tools:Append("Button"); prompt.Anchors="0,0"; prompt.Text="SEARCH..."; prompt.Texture="corner15"; prompt.PluginComponent=my_handle; prompt.Clicked="Search"
  local pool=tools:Append("Button"); pool.Anchors="1,0"; pool.Text="ALL DATA POOLS"; pool.Texture="corner15"; pool.PluginComponent=my_handle; pool.Clicked="ChoosePool"; ui.poolButton=pool
  local resultMode=tools:Append("UIObject"); resultMode.Anchors="2,0"; resultMode.Text="RESULT BROWSER  •  POOL + SHEET"; resultMode.Texture="corner15"; styleText(resultMode,false)
  local refresh=tools:Append("Button"); refresh.Anchors="3,0"; refresh.Text="REFRESH INDEX"; refresh.Texture="corner15"; refresh.PluginComponent=my_handle; refresh.Clicked="Refresh"
  local safety=tools:Append("UIObject"); safety.Anchors="4,0"; safety.Text="SAFE NAVIGATION  •  NEVER CALLS OBJECTS"; styleText(safety,false)
  ui.body=r:Append("UILayoutGrid"); ui.body.Anchors="0,2"
  ui.status=r:Append("UIObject"); ui.status.Anchors="0,3"; ui.status.Text="Building search index..."
  buildIndex(); if ui.poolButton then ui.poolButton.Text=poolChoiceLabel() end
  ui.status.Text="Ready  •  "..#indexCache.." named objects indexed  •  "..poolChoiceLabel().."  •  grandMA3 "..tostring(Version())
  safe(function() r:WaitInit(2) end)
  signalTable.Search()
end

return function() local ok,e=pcall(open); if not ok then if ui.colorCleanup then ui.colorCleanup(); ui.colorCleanup=nil end; ErrPrintf("MA Search: %s",tostring(e)) end end
