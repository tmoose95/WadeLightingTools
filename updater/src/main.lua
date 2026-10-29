-- Native MA3 table UI. Every action is staged for review before file/show changes.
local VERSION='1.1.4'
local ui={actions={},busy=false,tab=1,cells={},activity={}}
local R,build,scan
local function valid(h) return h and safe(function()return IsObjectValid(h)end,false) end
local function remove(h) if valid(h) then safe(function()Obj.Delete(h:Parent(),Obj.Index(h))end) end end
local function notify(text,current,total,log)
 if valid(ui.status) then ui.status.Text=text end
 if valid(ui.updateStatus) then ui.updateStatus.Text=text end
 if log then
  ui.activity[#ui.activity+1]=tostring(text):gsub('[\r\n]+',' ')
  while #ui.activity>3 do table.remove(ui.activity,1) end
  for i,o in ipairs(ui.activityLabels or {}) do if valid(o)then o.Text=ui.activity[i] or '' end end
 end
 if ui.progress then
  safe(function()SetProgressText(ui.progress,text)end)
  if current and total and total>0 then
   local value=math.floor(1000*math.max(0,math.min(1,current/total)))
   safe(function()SetProgressRange(ui.progress,0,1000);SetProgress(ui.progress,value)end)
   if valid(ui.percent) then ui.percent.Text=string.format('%d%%',math.floor(value/10)) end
   if valid(ui.fill)then ui.fill.Visible=value>0 and 'Yes' or 'No';ui.fill.W=ui.trackWidth*value/1000 end
  end
 end
end
local function close()
 if ui.busy then if R then R.cancel=true end;ui.exitAfterCancel=true;notify('Cancelling...');return end
 remove(ui.qrBase);remove(ui.chooser);remove(ui.scanBase);remove(ui.updateBase);remove(ui.base)
 ui.qrBase=nil;ui.chooser=nil;ui.scanBase=nil;ui.updateBase=nil;ui.base=nil
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
local function grid(parent,name,cols,rows,anchor)
 local o=parent:Append('UILayoutGrid');o.Name=name;o.Columns=cols;o.Rows=rows;o.Anchors=anchor;return o
end
local function label(parent,col,row,text,font,color)
 local o=parent:Append('UIObject');o.Anchors={left=col,right=col,top=row,bottom=row}
 o.Text=text;o.Font=font or 'Regular16';o.TextalignmentH='Left'
 o.Padding={left=10,right=6,top=4,bottom=4};o.Margin={left=1,right=1,top=1,bottom=1}
 o.BackColor=color or Root().ColorTheme.ColorGroups.Global.Transparent
 return o
end
local function colors()
 local t=Root().ColorTheme.ColorGroups
 local function named(name,rgba,fallback)
  return safe(function()
   local c=t.Global[name]
   if not c then c=t.Global:Acquire();c:Set('Name',name);c:Set('RGBA',rgba) end
   return c
  end,fallback)
 end
 return t.Button.BackgroundNormal,
  named('WLTCurrent','4C9839FF',t.Button.BackgroundPlease),
  named('WLTNotCurrent','A63E3EFF',safe(function()return t.Global.AlertText end,t.Button.BackgroundNormal))
end
local function versionColor(state,face,green,red)
 return state=='current' and green or ((state=='outdated' or state=='newer') and red or face)
end
local function findPlugin(name,prefix)
 local id=name:sub(#prefix+1)
 for _,p in ipairs(R.catalog)do if p.id==id then return p end end
end
local function pluginPage(p)
 return 'https://tmoose95.github.io/WadeLightingTools/'..p.id..'/'
end
local ACTIONS={[0]='Do Nothing',[1]='Import Online',[2]='Download to Drives',[3]='Import from Drive'}
local function updateActions()
 local count=0
 for id,mode in pairs(ui.actions)do if mode>0 then count=count+1 end end
 for id,c in pairs(ui.cells)do if valid(c.action)then
  local mode=ui.actions[id] or 0
  c.action.Text=(mode==0 and '×  ' or '↓  ')..ACTIONS[mode]..'  ▾'
  c.action.State=mode>0 and 1 or 0
 end end
 if valid(ui.update)then ui.update.Text='Update ('..count..')'end
end
local function drawScan()
 remove(ui.base);ui.base=nil;remove(ui.scanBase)
 local d=ui.display;local b=d.ScreenOverlay:Append('BaseInput');ui.scanBase=b
 b.Name='WLTScan';b.W=math.min(850,d.W*.9);b.H=340;b.Columns=1;b.Rows=3;b.AutoClose='No';b.CloseOnEscape='No'
 for i,h in ipairs({52,230,58})do b[1][i].SizePolicy='Fixed';b[1][i].Size=tostring(h)end
 local title=b:Append('TitleBar');title.Anchors='0,0';title.Columns=1;title.Rows=1
 local cap=title:Append('TitleButton');cap.Anchors='0,0';cap.Text='WLT Plugin Updator';cap.Texture='corner1'
 local body=grid(b,'ScanBody',1,2,'0,1')
 local message=label(body,0,0,'Checking plugin libraries and showfile versions.\nInternal storage and connected USB drives only.','Regular20');message.TextalignmentH='Centre'
 ui.status=label(body,0,1,'Starting scan...');ui.status.TextalignmentH='Centre'
 button(b,0,2,'CancelScan','Cancel & Exit','WLTClose')
end
local function drawUpdate()
 remove(ui.updateBase);ui.activity={};ui.activityLabels={}
 local d=ui.display;local face,green=colors()
 local b=d.ScreenOverlay:Append('BaseInput');ui.updateBase=b
 b.Name='WLTUpdating';b.W=math.min(1100,d.W*.94);b.H=350;b.Columns=1;b.Rows=6;b.AutoClose='No';b.CloseOnEscape='No'
 for i,h in ipairs({50,64,42,26,108,60})do b[1][i].SizePolicy='Fixed';b[1][i].Size=tostring(h)end
 local title=b:Append('TitleBar');title.Anchors='0,0';title.Columns=1;title.Rows=1
 local cap=title:Append('TitleButton');cap.Anchors='0,0';cap.Text='WLT Plugin Updator - Updating';cap.Texture='corner1'
 ui.updateStatus=label(b,0,1,'Starting update...','Regular18')
 local track=grid(b,'UpdateProgress',1,1,'0,2');track.BackColor=face;track.Margin={left=12,right=12,top=4,bottom=4}
 ui.trackWidth=b.W-24
 ui.fill=track:Append('UIObject');ui.fill.Name='UpdateProgressFill';ui.fill.Anchors='0,0';ui.fill.AlignmentH='Left';ui.fill.W=0;ui.fill.Visible='No';ui.fill.BackColor=green
 ui.percent=label(track,0,0,'0%','Regular18');ui.percent.Name='UpdatePercent';ui.percent.TextalignmentH='Centre'
 local heading=label(b,0,3,'System Monitor - latest messages','Regular16');heading.Name='UpdateLogHeading'
 local panel=grid(b,'UpdateLog',1,1,'0,4');panel.Margin={left=12,right=12,top=0,bottom=0}
 -- Native monitor follows MA messages, including import/export feedback from
 -- the engine. Its viewport is three lines high at the regular 24px line size.
 local monitor=safe(function()
  if not ClassExists('SystemMonitorWindow')then return end
  local o=panel:Append('SystemMonitorWindow');o.Name='UpdateSystemMonitor';o.Anchors='0,0';o.Font='Regular16';o.H=72;o.AlignmentV='Bottom';return o
 end,nil)
 if not valid(monitor)then
  heading.Text='Updater activity - last 3 messages (System Monitor view unavailable)'
  local lines=grid(panel,'UpdateActivity',1,3,'0,0')
  for i=1,3 do local o=label(lines,0,i-1,'','Regular16');o.Name='UpdateActivity'..i;ui.activityLabels[i]=o end
 end
 button(b,0,5,'CancelUpdate','Cancel & Exit','WLTClose')
end
scan=function(connect)
 ui.busy=true;ui.exitAfterCancel=false;drawScan()
 ui.progress=StartProgress('WLT Plugin Updator | Scanning drives and showfile')
 R.pause(.01)
 local ok,err=pcall(function()R.scan(connect)end)
 StopProgress(ui.progress);ui.progress=nil;ui.busy=false;remove(ui.scanBase);ui.scanBase=nil
 if ui.exitAfterCancel then close();return end
 if not ok then errorbox(err) end
 build(ui.display)
end
signalTable.WLTClose=function()close()end
signalTable.WLTRescan=function()guarded(function()scan(true)end)end
signalTable.WLTTab=function(c)guarded(function()
 ui.tab=tonumber(c.Name:match('Tab(%d+)')) or 1;build(ui.display)
end)end
signalTable.WLTAction=function(c)guarded(function()
 local p=findPlugin(c.Name,'Action_');if not p then return end
 local commands={{value=0,name='Do Nothing'}}
 if R.online then
  if p.id~='WadePluginUpdater' then commands[#commands+1]={value=1,name='Import Online'}end
  commands[#commands+1]={value=2,name='Download to Drives'}
 end
 if R.localSource(p) and p.id~='WadePluginUpdater' then commands[#commands+1]={value=3,name='Import from Drive'}end
 local a=MessageBox({title=p.name..' - Action',message='Choose an action. Press Update to review and apply the queued actions.',commands=commands})
 if a and a.success and ACTIONS[a.result]then ui.actions[p.id]=a.result;updateActions()end
end)end
signalTable.WLTBulk=function()guarded(function()
 local a=MessageBox({title='Actions',message='Apply to plugins shown in this tab.',commands={{value=1,name='Select Available Updates'},{value=2,name='Clear All Actions'},{value=0,name='Cancel'}}})
 if not a or not a.success then return end
 if a.result==2 then ui.actions={}end
 if a.result==1 then
  for _,p in ipairs(R.visible(ui.tab))do
   if R.online then
    local behind=false;for _,x in ipairs(R.installed[p.id] or {})do if R.versionStateFor(p,x.version)=='outdated'then behind=true end end
    local localCopy=R.localSource(p)
    if behind or (ui.tab==2 and localCopy and R.versionStateFor(p,localCopy.version)=='outdated')then
     ui.actions[p.id]=(p.id=='WadePluginUpdater' or ui.tab==2)and 2 or 1
    end
   end
  end
 end
 updateActions()
end)end
signalTable.WLTDrives=function()guarded(function()
 local states={};for _,d in ipairs(R.drives)do states[#states+1]={name=d.label,state=R.selectedDrives[d.path] or false}end
 local a=MessageBox({title='Download / source drives',message='Downloads go to every selected drive. Import from Drive uses the chosen complete package on a selected drive.',states=states,commands={{value=1,name='Apply'},{value=0,name='Cancel'}}})
 if a and a.success and a.result==1 then
  R.selectedDrives={};for _,d in ipairs(R.drives)do if a.states and a.states[d.label]then R.selectedDrives[d.path]=true end end
  build(ui.display)
 end
end)end
signalTable.WLTPool=function()guarded(function()
 local commands={{value=-1,name='All DataPools'},{value=0,name='Cancel'}};local lookup={}
 for _,p in ipairs(R.pools())do local n=R.index(p);commands[#commands+1]={value=n,name=n..' - '..R.prop(p,'Name')};lookup[n]=p end
 local a=MessageBox({title='Update Destination',message='Existing plugins retain their slots. A missing plugin uses an empty slot in each chosen DataPool. Review lists every target.',commands=commands})
 if a and a.success then
  if a.result==-1 then R.allPools=true elseif lookup[a.result]then R.allPools=false;R.pool=lookup[a.result]else return end
  R.refreshInstalled();build(ui.display)
 end
end)end
signalTable.WLTUSB=function(c)guarded(function()
 local p=findPlugin(c.Name,'USB_');if not p then return end
 local commands={{value=0,name='Cancel'}};local list={}
 for _,e in ipairs(R.localFiles[p.id] or {})do if R.selectedDrives[e.drive.path]then
  list[#list+1]=e;commands[#commands+1]={value=#list,name=e.version..' - '..e.drive.label}
 end end
 local a=MessageBox({title=p.name..' - Drive Version',message='Choose the copy for Import from Drive. Use Settings > Drives to include another source drive.',commands=commands})
 if a and a.success and list[a.result]then R.localChoice[p.id]=list[a.result];build(ui.display)end
end)end
signalTable.WLTInfo=function(c)guarded(function()
 local p=findPlugin(c.Name,'Info_');if not p then return end
 local copy=R.localSource(p)
 MessageBox({title=p.name,message='Latest online: '..(R.online and p.version or 'Not verified')..'\nShowfile:\n'..R.installedText(p,true)..'\nSelected drive copy: '..(copy and copy.version..' - '..copy.drive.label or 'None')..'\nRequires MA3 '..p.minimum..'\n\nhttps://tmoose95.github.io/WadeLightingTools/'..p.id..'/',commands={{value=1,name='Close'}}})
end)end
signalTable.WLTCloseQR=function()remove(ui.qrBase);ui.qrBase=nil end
signalTable.WLTQR=function(c)guarded(function()
 local p=findPlugin(c.Name,'QR_');if not p then return end
 local url=pluginPage(p)
 if not safe(function()return ClassExists('QRCode')end,false)then
  errorbox('QR display is unavailable on this station. Plugin page:\n'..url);return
 end
 remove(ui.qrBase)
 local display=ui.display;local base=display.ScreenOverlay:Append('BaseInput');ui.qrBase=base
 base.Name='WLTPluginPage';base.W=math.min(660,display.W*.94);base.H=math.min(560,display.H*.94)
 base.Columns=1;base.Rows=4;base.AutoClose='No';base.CloseOnEscape='Yes'
 for i,h in ipairs({50,0,76,50})do base[1][i].SizePolicy=i==2 and 'Stretch' or 'Fixed';if i~=2 then base[1][i].Size=tostring(h)end end
 local title=base:Append('TitleBar');title.Anchors='0,0';title.Columns=2;title.Rows=1
 title[2][2].SizePolicy='Fixed';title[2][2].Size='50'
 local cap=title:Append('TitleButton');cap.Anchors='0,0';cap.Text=p.name..' - Plugin Page';cap.Texture='corner1'
 local x=title:Append('CloseButton');x.Name='CloseQRTitle';x.Anchors='1,0';x.Texture='corner2';x.PluginComponent=myHandle;x.Clicked='WLTCloseQR'
 local qr=base:Append('QRCode');qr.Name='PluginPageQR';qr.Anchors='0,1';qr.Text=url
 qr.ShowText='No';qr.Title='';qr.Icon='';qr.Margin={left=22,right=22,top=16,bottom=16}
 -- Native QRCode renders a square, including its quiet zone, at this size.
 local size=math.max(72,math.min(340,base.W-44,base.H-208));qr.W=size;qr.H=size;qr.AlignmentH='Centre';qr.AlignmentV='Centre'
 local text=label(base,0,2,'Scan to open the plugin page on your phone.\n'..url,'Regular16');text.Name='PluginPageURL';text.TextalignmentH='Centre'
 button(base,0,3,'CloseQR','Close','WLTCloseQR')
end)end
signalTable.WLTHelp=function(c)guarded(function()
 local p=findPlugin(c.Name,'Help_');if not p then return end
 MessageBox({title=p.name..' - Help',message='Import Online downloads and imports the latest release. Download to Drives writes the package without changing show plugins. Import from Drive uses a complete local package.\n\nGreen = matches latest. Red = differs from latest. Grey = unknown or catalog unavailable. A newer installed version is never downgraded.\n\n'..(p.id=='WadePluginUpdater' and 'Close the updater before importing its downloaded XML manually.\n\n' or '')..'Plugin instructions: https://tmoose95.github.io/WadeLightingTools/'..p.id..'/',commands={{value=1,name='Close'}}})
end)end
signalTable.WLTDetails=function()guarded(function()
 local lines={'Online catalog: '..(R.online and 'Loaded' or 'Unavailable'),
  'HTTPS client: '..tostring(R.client or 'Not detected'),'Connected drives: '..#R.drives,
  'Catalog: https://raw.githubusercontent.com/tmoose95/WadeLightingTools/main/catalog.tsv'}
 if R.connectionError then lines[#lines+1]='Connection error:\n'..R.connectionError end
 for _,x in ipairs(R.issues)do if not x:find('Online catalog unavailable',1,true)then lines[#lines+1]=x end end
 MessageBox({title='Connection Details',message=table.concat(lines,'\n\n'),commands={{value=1,name='Close'}}})
end)end
signalTable.WLTSettings=function()guarded(function()
 local a=MessageBox({title='WLT Plugin Updator - Settings',message='Choose download drives, refresh versions, or inspect the catalog connection.',commands={{value=1,name='Drives'},{value=2,name='Rescan'},{value=3,name='Connection Details'},{value=0,name='Close'}}})
 if a and a.success then
  if a.result==1 then signalTable.WLTDrives()elseif a.result==2 then signalTable.WLTRescan()elseif a.result==3 then signalTable.WLTDetails()end
 end
end)end
signalTable.WLTUpdate=function()guarded(function()
 local plan=R.plan(ui.actions)
 local drives={};for _,d in ipairs(plan.drives)do drives[#drives+1]=d.label end
 local a=MessageBox({title='Review updates',message='Drives: '..table.concat(drives,', ')..'\n\n'..table.concat(plan.lines,'\n\n'),commands={{value=1,name='Update'},{value=0,name='Cancel'}}})
 if not a or not a.success or a.result~=1 then return end
 ui.busy=true;R.cancel=false;ui.exitAfterCancel=false;drawUpdate();ui.progress=StartProgress('WLT Plugin Updator | Updating')
 notify('Starting update',0,1000,true);R.pause(.01)
 local ok,result=pcall(R.run,plan)
 if not ok then notify(tostring(result),nil,nil,true) end
 StopProgress(ui.progress);ui.progress=nil;ui.busy=false;remove(ui.updateBase);ui.updateBase=nil
 MessageBox({title=ok and 'Update results' or 'Update stopped',message=tostring(result),commands={{value=1,name='Close'}}})
 ui.actions={}
 if ui.exitAfterCancel then close();return end
 R.refreshInstalled();build(ui.display)
end)end
signalTable.WLTMove=function()guarded(function()
 if valid(ui.chooser)then return end
 ui.chooser=display_preference(ui.display.ScreenOverlay,ui.display,'WLTDisplay','WLTCancelMove',available_display)
end)end
signalTable.WLTCancelMove=function()remove(ui.chooser);ui.chooser=nil end
signalTable.WLTDisplay=function(c)guarded(function()
 local i=tonumber(c.Name:match('Display(%d+)'));if i and available_display(i)then remove(ui.chooser);ui.chooser=nil;build(GetDisplayByIndex(i))end
end)end
local function columns(g,more)
 local weights=more and {3.6,2.6,1.5,1.3,0.7,0.7} or {3.2,2.4,2.6,1.8,1.8,0.7,0.7}
 for i,w in ipairs(weights)do g[2][i].SizePolicy='Stretch';g[2][i].Size=tostring(w)end
end
build=function(display)
 remove(ui.qrBase);ui.qrBase=nil;remove(ui.base);ui.cells={}
 display=display or GetFocusDisplay() or GetDisplayByIndex(1);ui.display=display
 local theme=Root().ColorTheme.ColorGroups;local face,green,red=colors()
 local base=display.ScreenOverlay:Append('BaseInput');ui.base=base
 base.Name='WadePluginUpdater';base.W=math.min(1320,display.W*.97);base.H=math.min(830,display.H*.94)
 base.Columns=1;base.Rows=2;base.AutoClose='No';base.CloseOnEscape='Yes';base.MaxSize=string.format('%s,%s',display.W*.97,display.H*.96)
 base[1][1].SizePolicy='Fixed';base[1][1].Size='54';base[1][2].SizePolicy='Stretch'
 local title=base:Append('TitleBar');title.Name='Title';title.Columns=4;title.Rows=1;title.Anchors='0,0'
 for i=2,4 do title[2][i].SizePolicy='Fixed';title[2][i].Size='54'end
 local name=title:Append('TitleButton');name.Anchors='0,0';name.Text='WLT Plugin Updator  v'..VERSION;name.Texture='corner1';name.Font='Regular18'
 button(title,1,0,'Settings','⚙','WLTSettings',face)
 display_icon(button(title,2,0,'Move','','WLTMove',face))
 local x=title:Append('CloseButton');x.Anchors='3,0';x.Texture='corner2';x.PluginComponent=myHandle;x.Clicked='WLTClose'
 local frame=base:Append('DialogFrame');frame.Columns=1;frame.Rows=6;frame.Anchors='0,1'
 for i,h in ipairs({66,54,40,0,54,58})do frame[1][i].SizePolicy=i==4 and 'Stretch' or 'Fixed';if i~=4 then frame[1][i].Size=tostring(h)end end
 local banner=grid(frame,'Banner',1,2,'0,0')
 local brand=label(banner,0,0,'WADE LT  |  Your plugins. Up to date.','Regular20');brand.TextalignmentH='Centre'
 ui.status=label(banner,0,1,#R.drives..' drives scanned  |  '..(R.online and 'Online catalog loaded' or 'Online catalog unavailable - see Settings > Connection Details'));ui.status.TextalignmentH='Centre'
 local tabs=grid(frame,'Tabs',3,1,'0,1')
 for i,text in ipairs({'Plugins in your Showfile','Plugins on your USB Drives','More Plugins'})do
  local b=button(tabs,i-1,0,'Tab'..i,text,'WLTTab',face);b.State=ui.tab==i and 1 or 0
  if ui.tab==i then b.TextColor=theme.Button.TextPlease end
 end
 local more=ui.tab==3;local n=more and 6 or 7
 local headpanel=grid(frame,'HeaderPanel',2,1,'0,2');headpanel[2][2].SizePolicy='Fixed';headpanel[2][2].Size='18'
 local headings=grid(headpanel,'Headings',n,1,'0,0');columns(headings,more)
 local texts=more and {'Plugin Name','Action  ▾','Version','Plugin Page','Info','Help'}or{'Plugin Name','Showfile','Action  ▾','USB / Drive','Online','Info','Help'}
 for col,text in ipairs(texts)do
  if text=='Action  ▾'then button(headings,col-1,0,'Bulk',text,'WLTBulk',face)else label(headings,col-1,0,text,'Regular16',face)end
 end
 local panel=grid(frame,'PluginListPanel',2,1,'0,3');panel.Margin={left=4,right=4,top=4,bottom=4};panel[2][2].SizePolicy='Fixed';panel[2][2].Size='18'
 local scroll=panel:Append('ScrollBox');scroll.Name='PluginScroll';scroll.Anchors='0,0'
 local bar=panel:Append('ScrollBarV');bar.Name='PluginScrollbar';bar.Anchors='1,0';bar.ScrollTarget=scroll
 local entries=R.visible(ui.tab);local heights,total={},0
 for i,p in ipairs(entries)do heights[i]=more and 54 or math.max(58,24*#(R.showInstalled[p.id]or{})+12);total=total+heights[i]end
 local list=grid(scroll,'PluginList',n,math.max(1,#entries),'0,0');list.W='100%';list.H=math.max(70,total);columns(list,more)
 if #entries==0 then
  local empty=label(list,0,0,ui.tab==2 and 'No WLT packages found on USB drives. Extract ZIPs into the plugin library, then Rescan.'or'No plugins in this tab.');empty.Anchors={left=0,right=n-1,top=0,bottom=0}
 end
 for row,p in ipairs(entries)do
  local y=row-1;list[1][row].SizePolicy='Fixed';list[1][row].Size=tostring(heights[row])
  label(list,0,y,p.name,'Regular16',face)
  local action=button(list,more and 1 or 2,y,'Action_'..p.id,'','WLTAction',face);action.Margin={left=1,right=1,top=1,bottom=1};ui.cells[p.id]={action=action}
  if not more then
   local installed=label(list,1,y,R.installedText(p,true),'Regular16',versionColor(R.installedState(p),face,green,red));installed.Name='Installed_'..p.id
   local source=R.localSource(p)
   local localText=source and source.version..'  ▾'or '-'
   if source and not source.drive.external then localText=source.version..' (Internal)  ▾'end
   local usb=button(list,3,y,'USB_'..p.id,localText,'WLTUSB',versionColor(source and R.versionStateFor(p,source.version)or'unknown',face,green,red));usb.Margin={left=1,right=1,top=1,bottom=1}
  end
  local online=label(list,more and 2 or 4,y,R.online and p.version or '-','Regular16',R.online and green or face);online.Name='Online_'..p.id
  if more then
   local qr=button(list,3,y,'QR_'..p.id,'QR Code','WLTQR',face);qr.Margin={left=1,right=1,top=1,bottom=1}
  end
  local info=button(list,n-2,y,'Info_'..p.id,'ⓘ','WLTInfo',face);info.Margin={left=1,right=1,top=1,bottom=1}
  local help=button(list,n-1,y,'Help_'..p.id,'?','WLTHelp',face);help.Margin={left=1,right=1,top=1,bottom=1}
 end
 local dest=grid(frame,'Destination',2,1,'0,4');dest[2][1].SizePolicy='Stretch';dest[2][1].Size='2';dest[2][2].SizePolicy='Stretch';dest[2][2].Size='5'
 button(dest,0,0,'Drives','Drives ('..#R.drivesSelected()..' selected)','WLTDrives',face)
 button(dest,1,0,'Pool','Update Destination:  '..(R.allPools and 'All DataPools' or R.prop(R.pool,'Name'))..'  ▾','WLTPool',face)
 local footer=grid(frame,'Footer',2,1,'0,5')
 button(footer,0,0,'Close','Close','WLTClose',face)
 ui.update=button(footer,1,0,'Update','Update','WLTUpdate',face)
 updateActions();_G.__WadeLightingToolsWindow=ui
end
local function metadata()
 safe(function()
  local p=myHandle:Parent();local appearance=Root().ShowData.Appearances.PluginUpdator_1_1_4
  if appearance then p.Appearance=appearance end
  local tag
  for _,t in ipairs(ObjectList('Tag Thru')or{})do if R.prop(t,'Name')=='Utility Plugins'then tag=t;break end end
  if not tag then Cmd('Store Tag "Utility Plugins" /NoConfirmation')end
  for _,t in ipairs(ObjectList('Tag Thru')or{})do if R.prop(t,'Name')=='Utility Plugins'then tag=t;break end end
  if tag then Cmd('Assign Tag '..R.index(tag)..' At '..p:ToAddr()..' /NoConfirmation')end
 end)
end
return function()
 local old=_G.__WadeLightingToolsWindow
 if old and old.busy then errorbox('An update or scan is already running.');return end
 if old then remove(old.qrBase);remove(old.chooser);remove(old.scanBase);remove(old.updateBase);remove(old.base)end
 _G.__WadeLightingToolsWindow=ui;ui.busy=true;ui.actions={}
 local ok,why=pcall(function()
  R=Runtime(Core,Transport,BOOTSTRAP,notify,myHandle:Parent(),TRUST_BUNDLE)
  R.allPools=true
  ui.display=GetFocusDisplay()or GetDisplayByIndex(1)
  metadata();scan(true)
 end)
 if not ok then
  if ui.progress then StopProgress(ui.progress);ui.progress=nil end
  remove(ui.scanBase);ui.scanBase=nil;ui.busy=false;errorbox(why)
 end
end
