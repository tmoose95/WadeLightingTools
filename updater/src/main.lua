-- UI entry point. Core, Transport, Runtime, button and display helpers are bundled above.
local VERSION='1.0.3'
local ui={selected={},busy=false}
local R
local build
local function valid(h) return h and safe(function()return IsObjectValid(h)end,false) end
local function notify(text)
 if valid(ui.status) then ui.status.Text=text end
 if ui.progress then safe(function()SetProgressText(ui.progress,text)end) end
end
local function remove(h) if valid(h) then safe(function()Obj.Delete(h:Parent(),Obj.Index(h))end) end end
local function close()
 if ui.busy then if R then R.cancel=true end;notify('Cancelling after the current operation');return end
 remove(ui.chooser);remove(ui.base);ui.chooser=nil;ui.base=nil
 if _G.__WadeLightingToolsWindow==ui then _G.__WadeLightingToolsWindow=nil end
end
local function errorbox(err) MessageBox({title='WLT Plugin Updator',message=tostring(err),commands={{value=1,name='OK'}}}) end
local function guarded(fn)
 if ui.busy then return end
 local ok,err=pcall(fn);if not ok then ui.busy=false;errorbox(err) end
end
local function available_display(i)
 local d=safe(function()return GetDisplayByIndex(i)end,nil)
 return valid(d) and valid(d.ScreenOverlay) and tonumber(d.W)>0 and tonumber(d.H)>0
end
local function label(parent,col,row,text,font)
 local o=parent:Append('UIObject');o.Anchors={left=col,right=col,top=row,bottom=row}
 o.Text=text;o.Font=font or 'Regular16';o.TextalignmentH='Left'
 o.Padding={left=8,right=4,top=4,bottom=4};o.BackColor=Root().ColorTheme.ColorGroups.Global.Transparent
 return o
end
local function grid(parent,name,cols,rows,anchor)
 local o=parent:Append('UILayoutGrid');o.Name=name;o.Columns=cols;o.Rows=rows;o.Anchors=anchor;return o
end
local function redraw() build(ui.display) end
local function scan(connect)
 ui.busy=true
 ui.progress=StartProgress('WadeLightingTools | Scanning drives')
 local ok,err=pcall(function()R.scan(connect)end)
 StopProgress(ui.progress);ui.progress=nil;ui.busy=false
 if not ok then errorbox(err) end
 redraw()
end
signalTable.WLTClose=function() close() end
signalTable.WLTRescan=function()guarded(function()scan(true)end)end
signalTable.WLTItem=function(c)guarded(function()
 local id=c.Name:match('^Item_(.+)$');if not id then return end
 ui.selected[id]=not ui.selected[id];redraw()
end)end
signalTable.WLTClear=function()guarded(function()ui.selected={};redraw()end)end
signalTable.WLTAll=function()guarded(function()
 ui.selected={};for _,p in ipairs(R.catalog)do if R.status(p)=='Update available' then ui.selected[p.id]=true end end;redraw()
end)end
signalTable.WLTMode=function(c)guarded(function()
 R.mode=tonumber(c.Name:match('Mode(%d+)')) or 1;redraw()
end)end
signalTable.WLTDrives=function()guarded(function()
 local states={};for _,d in ipairs(R.drives)do states[#states+1]={name=d.label,state=R.selectedDrives[d.path] or false} end
 local answer=MessageBox({title='Drives',message='Downloads go to every selected drive. Install Only uses the newest complete package on the selected drives.',
  states=states,commands={{value=1,name='Apply'},{value=0,name='Cancel'}}})
 if answer and answer.success and answer.result==1 then
  R.selectedDrives={};for _,d in ipairs(R.drives)do if answer.states and answer.states[d.label] then R.selectedDrives[d.path]=true end end
  redraw()
 end
end)end
signalTable.WLTPool=function()guarded(function()
 local pools=R.children(Root().ShowData.DataPools);local commands={{value=0,name='Cancel'}};local lookup={}
 for _,p in pairs(pools)do local n=R.index(p);if n then commands[#commands+1]={value=n,name=n..' - '..R.prop(p,'Name')};lookup[n]=p end end
 local a=MessageBox({title='Destination DataPool',message='Existing matching plugins keep their pool slots. New plugins use empty slots.',commands=commands})
 if a and a.success and lookup[a.result]then R.pool=lookup[a.result];R.refreshInstalled();redraw()end
end)end
signalTable.WLTDetails=function()guarded(function()
 local lines={'Catalog: https://github.com/tmoose95/WadeLightingTools',
  'Drive scan: '..#R.drives..' connected drive(s).','Internet: '..(R.online and 'Catalog loaded' or 'Unavailable'),
  'Downloads use HTTPS certificate validation and SHA-256 checksums.',
  'The updater is installed manually after downloading its new revision.'}
 for _,x in ipairs(R.issues)do lines[#lines+1]=x end
 MessageBox({title='Updater details',message=table.concat(lines,'\n\n'),commands={{value=1,name='Close'}}})
end)end
signalTable.WLTUpdate=function()guarded(function()
 local plan=R.plan(ui.selected)
 local mode=({'Download & Install','Download Only','Install Only'})[plan.mode]
 local destinations={};for _,d in ipairs(plan.drives)do destinations[#destinations+1]=d.label end
 local answer=MessageBox({title='Review updates',message=mode..'\n'..table.concat(destinations,'\n')..'\n\n'..table.concat(plan.lines,'\n'),
  commands={{value=1,name='Update'},{value=0,name='Cancel'}}})
 if not answer or not answer.success or answer.result~=1 then return end
 ui.busy=true;R.cancel=false;ui.progress=StartProgress('WadeLightingTools | Updating')
 local ok,result=pcall(R.run,plan)
 StopProgress(ui.progress);ui.progress=nil;ui.busy=false
 MessageBox({title=ok and 'Update results' or 'Update stopped',message=tostring(result),commands={{value=1,name='Close'}}})
 ui.selected={};scan(false)
end)end
signalTable.WLTMove=function()guarded(function()
 if valid(ui.chooser)then return end
 ui.chooser=display_preference(ui.display.ScreenOverlay,ui.display,'WLTDisplay','WLTCancelMove',available_display)
end)end
signalTable.WLTCancelMove=function()remove(ui.chooser);ui.chooser=nil end
signalTable.WLTDisplay=function(c)guarded(function()
 local i=tonumber(c.Name:match('Display(%d+)'));if i and available_display(i)then
  remove(ui.chooser);ui.chooser=nil;build(GetDisplayByIndex(i))
 end
end)end
build=function(display)
 remove(ui.base)
 display=display or GetFocusDisplay() or GetDisplayByIndex(1);ui.display=display
 local theme=Root().ColorTheme.ColorGroups;local face=theme.Button.BackgroundNormal;local green=theme.Button.BackgroundPlease
 local base=display.ScreenOverlay:Append('BaseInput');ui.base=base
 base.Name='WadePluginUpdater';base.W=math.min(1180,display.W*.96);base.H=math.min(820,display.H*.94)
 base.Columns=1;base.Rows=2;base.AutoClose='No';base.CloseOnEscape='Yes'
 base.MaxSize=string.format('%s,%s',display.W*.97,display.H*.96)
 base[1][1].SizePolicy='Fixed';base[1][1].Size='54';base[1][2].SizePolicy='Stretch'
 local title=base:Append('TitleBar');title.Columns=3;title.Rows=1;title.Anchors='0,0'
 title[2][2].SizePolicy='Fixed';title[2][2].Size='54';title[2][3].SizePolicy='Fixed';title[2][3].Size='54'
 local name=title:Append('TitleButton');name.Anchors='0,0';name.Text='WLT PLUGIN UPDATOR  v'..VERSION;name.Texture='corner1';name.Font='Regular18'
 display_icon(button(title,1,0,'Move','','WLTMove'))
 local x=title:Append('CloseButton');x.Anchors='2,0';x.Texture='corner2';x.PluginComponent=myHandle;x.Clicked='WLTClose'
 local frame=base:Append('DialogFrame');frame.Columns=1;frame.Rows=6;frame.Anchors='0,1'
 for i,h in ipairs({52,40,34,0,58,54})do frame[1][i].SizePolicy=i==4 and 'Stretch' or 'Fixed';if i~=4 then frame[1][i].Size=tostring(h)end end
 local settings=grid(frame,'Settings',3,1,'0,0')
 button(settings,0,0,'Drives','DRIVES  ('..#R.drivesSelected()..' selected)','WLTDrives',face)
 button(settings,1,0,'Pool','DATAPOOL  '..tostring(R.index(R.pool))..'  '..R.prop(R.pool,'Name'),'WLTPool',face)
 button(settings,2,0,'Rescan','RESCAN DRIVES & INTERNET','WLTRescan',face)
 ui.status=label(frame,0,1,#R.drives..' drives scanned  |  '..(R.online and 'Internet catalog connected' or 'Internet unavailable - local installs available'),'Regular16')
 local headings=grid(frame,'Headings',5,1,'0,2')
 headings[2][1].SizePolicy='Stretch';headings[2][1].Size='3'
 for col,text in ipairs({'PLUGIN','INSTALLED','ON DRIVE','ONLINE','STATUS'})do label(headings,col-1,0,text)end
 local panel=grid(frame,'PluginListPanel',2,1,'0,3');panel[2][2].SizePolicy='Fixed';panel[2][2].Size='18'
 local scroll=panel:Append('ScrollBox');scroll.Name='PluginScroll';scroll.Anchors='0,0'
 local bar=panel:Append('ScrollBarV');bar.Anchors='1,0';bar.ScrollTarget=scroll
 local list=grid(scroll,'PluginList',5,math.max(1,#R.catalog),'0,0');list.W='100%';list.H=math.max(1,#R.catalog)*46
 list[2][1].SizePolicy='Stretch';list[2][1].Size='3'
 for row,p in ipairs(R.catalog)do
  list[1][row].SizePolicy='Fixed';list[1][row].Size='46'
  local edge=list:Append('UIObject');edge.Anchors={left=0,right=4,top=row-1,bottom=row-1};edge.Margin={left=2,right=2,top=2,bottom=2}
  edge.BackColor=ui.selected[p.id] and green or (safe(function()return theme.Button.TextDisabled end,theme.Global.Text))
  local inside=list:Append('UIObject');inside.Anchors=edge.Anchors;inside.Margin={left=4,right=4,top=4,bottom=4};inside.BackColor=face
  local b=button(list,0,row-1,'Item_'..p.id,(ui.selected[p.id] and '[x]  ' or '[ ]  ')..p.name,'WLTItem',face);b.Margin={left=6,right=4,top=5,bottom=5};b.Font='Regular16';b.TextalignmentH='Left'
  local localVersion=R.localBest(p,true)
  label(list,1,row-1,R.installedText(p));label(list,2,row-1,localVersion and localVersion.version or '-');label(list,3,row-1,R.online and p.version or '-');label(list,4,row-1,R.status(p))
 end
 local modes=grid(frame,'Modes',3,1,'0,4')
 for n,text in ipairs({'DOWNLOAD & INSTALL','DOWNLOAD ONLY','INSTALL ONLY'})do
  local b=button(modes,n-1,0,'Mode'..n,text,'WLTMode',face);b.State=R.mode==n and 1 or 0
  if R.mode==n then b.TextColor=theme.Button.TextPlease end
 end
 local footer=grid(frame,'Footer',5,1,'0,5')
 button(footer,0,0,'All','SELECT UPDATES','WLTAll',face)
 button(footer,1,0,'Clear','CLEAR','WLTClear',face)
 button(footer,2,0,'Details','DETAILS','WLTDetails',face)
 local count=0;for _,v in pairs(ui.selected)do if v then count=count+1 end end
 button(footer,3,0,'Update','UPDATE ('..count..')','WLTUpdate',green)
 button(footer,4,0,'Close','CLOSE','WLTClose',face)
 _G.__WadeLightingToolsWindow=ui
end
local function metadata()
 safe(function()
  local p=myHandle:Parent();local appearance=Root().ShowData.Appearances.PluginUpdator_1_0_3
  if appearance then p.Appearance=appearance end
  local tag
  for _,t in ipairs(ObjectList('Tag Thru') or {})do if R.prop(t,'Name')=='Utility Plugins' then tag=t;break end end
  if not tag then Cmd('Store Tag "Utility Plugins" /NoConfirmation') end
  for _,t in ipairs(ObjectList('Tag Thru') or {})do if R.prop(t,'Name')=='Utility Plugins'then tag=t;break end end
  if tag then Cmd('Assign Tag '..R.index(tag)..' At '..p:ToAddr()..' /NoConfirmation') end
 end)
end
return function()
 local old=_G.__WadeLightingToolsWindow
 if old and old.busy then errorbox('An update or scan is already running.');return end
 if old then remove(old.chooser);remove(old.base)end
 _G.__WadeLightingToolsWindow=ui;ui.busy=true
 local ok,why=pcall(function()
  R=Runtime(Core,Transport,BOOTSTRAP,notify,myHandle:Parent())
  ui.display=GetFocusDisplay() or GetDisplayByIndex(1)
  metadata()
  scan(true) -- Main window is created only after the connected-drive scan.
 end)
 if not ok then
  if ui.progress then StopProgress(ui.progress);ui.progress=nil end
  ui.busy=false;errorbox(why)
 end
end
