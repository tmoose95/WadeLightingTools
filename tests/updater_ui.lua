-- Callback/UI wiring simulation, without a console or network client.
local nodes,dialogs,answers,events={},{},{},{}
local appendFailure
local function config()return setmetatable({},{__index=function(t,k)local c=config();rawset(t,k,c);return c end})end
local function object(parent,class)
 local o={_parent=parent,_class=class,_children={},_dimensions={}}
 setmetatable(o,{__newindex=function(t,k,v) if class=='BaseInput' and (k=='W' or k=='H')then t._dimensions[k]=tostring(v)..'px' else rawset(t,k,v)end end,__index=function(t,k)if t._dimensions[k]then return t._dimensions[k]end;if type(k)=='number'then local c=config();rawset(t,k,c);return c end end})
 function o:Append(kind)assert(kind~='SystemMonitorWindow','Unverified native monitor was instantiated');if appendFailure and kind=='TitleBar' and self.Name=='WLTUpdating'then error('Simulated popup setup failure')end;local c=object(self,kind);self._children[#self._children+1]=c;nodes[#nodes+1]=c;return c end
 function o:Parent()return self._parent end
 function o:ToAddr()return 'DataPool 1 Plugin 13'end
 return o
end
local function valid(o)return type(o)=='table'and not o._deleted end
local function delete(o)o._deleted=true;for _,c in ipairs(o._children or {})do delete(c)end end
local function control(name)
 for i=#nodes,1,-1 do if nodes[i].Name==name and valid(nodes[i])then return nodes[i]end end
 error('Missing '..name)
end
local displays={};for i=1,3 do local d=object(nil,'Display');d._index=i;d.W=1920;d.H=1080;d.ScreenOverlay=object(d,'Overlay');displays[i]=d end
local pools={{Name='Main',_index=1},{Name='Tour',_index=2}}
local root={ColorTheme={ColorGroups={Button={BackgroundNormal='grey',BackgroundPlease='green',TextPlease='yellow',TextDisabled='lightgrey'},Global={Transparent='clear',Text='white',AlertText='red'}}},ShowData={Appearances={PluginUpdator_1_1_8={}},DataPools=pools}}
local R={catalog={{id='ServerCommand',name='Server Command',version='2.3.15',minimum='2.5.1.0'},{id='HippoRemote',name='Hippo Remote',version='1.3.0',minimum='2.5.1.0'}},drives={{path='/usb',label='USB',external=true}},selectedDrives={['/usb']=true},pool=pools[1],online=true,issues={},mode=1,localChoice={},installed={},showInstalled={}}
R.importNotice='Showfile import is temporarily disabled after a reported console restart.'
local server=R.catalog[1];local hippo=R.catalog[2]
R.canDownload=function(p)return true end
R.installed.ServerCommand={{version='2.3.14',poolName='Main'}};R.showInstalled=R.installed
local source={version='2.3.14',drive=R.drives[1]};R.localFiles={ServerCommand={source},HippoRemote={source}}
R.children=function(h)return h end;R.pools=function()return pools end;R.index=function(h)return h._index end;R.prop=function(h,k)return h[k]or''end;R.pause=function()end
R.visible=function(tab)return tab==1 and {server}or(tab==2 and {server,hippo}or{hippo})end
R.scan=function(connect)events[#events+1]='scan';assert(control('WLTScan'));if #events==1 then assert(not pcall(control,'WadePluginUpdater'),'Main window opened before initial scan')end end
R.drivesSelected=function()return R.selectedDrives['/usb']and R.drives or{}end
R.localSource=function(p)return R.localChoice[p.id]or source end;R.installedText=function(p)return p==server and '2.3.14 (Main)'or'Not installed'end
R.installedState=function()return R.online and 'outdated'or'unknown'end
R.versionStateFor=function(p,v)
 if not R.online then return 'unknown'end
 local compare=dofile('updater/src/core.lua').compare(v,p.version)
 return compare==0 and 'current'or(compare==-1 and 'outdated'or'newer')
end
R.refreshInstalled=function()events[#events+1]='pool'end
local planned,ran=0,0
local notify,progressValues,progressStops
progressValues={};progressStops=0
R.plan=function(selected)
 local ids={};for id,mode in pairs(selected)do if mode>0 then ids[#ids+1]=id end end
 assert(#ids>0,'Choose an action for one or more plugins')
 planned=planned+1;return {drives=R.drivesSelected(),lines=ids}
end
R.run=function(plan)ran=ran+1;notify('Download',500,1000,true);notify('Complete',1000,1000,true);return 'Done'end
local sig={};local plugin=object(nil,'Plugin');local component={Parent=function()return plugin end}
local env=setmetatable({signalTable=sig,myHandle=component,Core={},Transport={},BOOTSTRAP='',Runtime=function(c,t,b,n)notify=n;return R end},{__index=_G});env._G=env
function env.safe(fn,fallback)local ok,v=pcall(fn);if ok then return v end;return fallback end
function env.button(parent,col,row,name,text,clicked,color)local b=parent:Append('Button');b.Name=name;b.Text=text;b.Clicked=clicked;b.BackColor=color;b.Anchors={left=col,right=col,top=row,bottom=row};return b end
env.Root=function()return root end;env.GetFocusDisplay=function()return displays[2]end;env.GetDisplayByIndex=function(i)return displays[i]end;env.IsObjectValid=valid
env.ClassExists=function(name)return (name=='QRCode' or name=='SystemMonitorWindow')end
env.Obj={Index=function(o)if o._index then return o._index end;for i,c in ipairs(o._parent._children)do if c==o then return i end end end,Delete=function(parent,i)delete(table.remove(parent._children,i))end}
env.MessageBox=function(d)dialogs[#dialogs+1]=d;return table.remove(answers,1)or{success=true,result=0}end
env.StartProgress=function()return 1 end;env.StopProgress=function()progressStops=progressStops+1 end;env.SetProgressRange=function(id,first,last)assert(first==0 and last==1000)end;env.SetProgress=function(id,value)progressValues[#progressValues+1]=value end;env.SetProgressText=function()end;env.ObjectList=function()return{}end;env.Cmd=function()return'OK'end
local function read(path)local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local launch=assert(load(read('updater/src/display.lua')..'\n'..read('updater/src/main.lua'),'updater-ui','t',env))()
local hits={};for name,fn in pairs(sig)do sig[name]=function(...)hits[name]=true;return fn(...)end end
local count=0;local function test(name,fn)fn();count=count+1;print('PASS '..name)end
local function click(name)local c=control(name);assert(sig[c.Clicked],c.Clicked or name);sig[c.Clicked](c)end
test('Startup scan dialog precedes main UI on caller display',function()launch();assert(events[1]=='scan');assert(plugin.Appearance==root.ShowData.Appearances.PluginUpdator_1_1_8);assert(control('WadePluginUpdater'):Parent()==displays[2].ScreenOverlay);assert(R.allPools)end)
test('Every button callback exists; table uses native ScrollBox and ScrollBarV',function()
 for _,c in ipairs(nodes)do if valid(c)and c.Clicked then assert(sig[c.Clicked],c.Clicked)end end
 assert(control('PluginScroll')._class=='ScrollBox');assert(control('PluginScrollbar').ScrollTarget==control('PluginScroll'))
end)
test('Version cells are red for non-current and green for latest',function()
 assert(control('Installed_ServerCommand').BackColor=='red');assert(control('USB_ServerCommand').BackColor=='red');assert(control('Online_ServerCommand').BackColor=='green')
end)
test('Tabs keep separate queues; Showfile never carries a drive-download action',function()
 click('Tab2');answers={{success=true,result=2}};click('Action_ServerCommand');assert(control('Update').Text=='Update Drives (1)')
 local scroll=control('PluginScroll');answers={{success=true,result=2}};click('Action_ServerCommand');assert(control('PluginScroll')==scroll,'Action changes must not reset scroll position')
 click('Tab1');assert(control('Update').Text=='Import paused' and control('Action_ServerCommand').Text:find('Do Nothing',1,true))
 click('Tab3');assert(control('Action_HippoRemote'));assert(not pcall(control,'Action_ServerCommand'));assert(control('Update').Text=='Update Drives (0)')
 click('Tab2');assert(control('Update').Text=='Update Drives (1)');click('Tab1')
end)
test('More Plugins offers QR pages for uninstalled plugins without changing row height',function()
 click('Tab3');assert(control('QR_HippoRemote').Text=='QR Code')
 assert(not pcall(control,'QR_ServerCommand'))
 assert(control('Headings').Columns==6 and control('PluginList')[1][1].Size=='54')
 click('Tab1');assert(not pcall(control,'QR_HippoRemote'))
end)
test('QR popup uses native widget, exact plugin URL and caller display offline',function()
 R.online=false;click('Tab3');click('QR_HippoRemote')
 local qr=control('PluginPageQR');local popup=control('WLTPluginPage')
 assert(qr._class=='QRCode' and qr.Text=='https://tmoose95.github.io/WadeLightingTools/HippoRemote/')
 assert(qr.Icon=='' and qr.ShowText=='No' and qr.W==qr.H and qr.W>=300)
 assert(popup:Parent()==displays[2].ScreenOverlay and popup.CloseOnEscape=='Yes')
 assert(control('PluginPageURL').Text:find(qr.Text,1,true))
 click('CloseQRTitle');assert(not pcall(control,'WLTPluginPage'))
 R.online=true;click('Tab1')
end)
test('Each catalog QR uses its own existing GitHub Pages path',function()
 local originalCatalog,originalVisible=R.catalog,R.visible
 R.catalog=dofile('updater/src/core.lua').catalog(read('catalog.tsv'))
 R.visible=function()return R.catalog end
 click('Tab3')
 for _,p in ipairs(R.catalog)do
  click('QR_'..p.id);assert(control('PluginPageQR').Text=='https://tmoose95.github.io/WadeLightingTools/'..p.id..'/')
  local page=io.open('docs/'..p.id..'/index.html','rb');assert(page);page:close()
  click('CloseQR');assert(not pcall(control,'WLTPluginPage'))
 end
 R.catalog,R.visible=originalCatalog,originalVisible;click('Tab1')
end)
test('QR popup is removed on rebuild and moves to the chosen display on reopen',function()
 click('Tab3');click('QR_HippoRemote');local old=control('WLTPluginPage')
 click('QR_HippoRemote');assert(old._deleted)
 click('Move');click('Display3');assert(not pcall(control,'WLTPluginPage'))
 click('QR_HippoRemote');assert(control('WLTPluginPage'):Parent()==displays[3].ScreenOverlay)
 click('CloseQR');click('Move');click('Display2');click('Tab1')
end)
test('Missing native QR class reports the usable URL without breaking the list',function()
 env.ClassExists=function()return false end;click('Tab3');click('QR_HippoRemote')
 assert(dialogs[#dialogs].message:find('https://tmoose95.github.io/WadeLightingTools/HippoRemote/',1,true))
 assert(not pcall(control,'WLTPluginPage') and control('WadePluginUpdater'))
 env.ClassExists=function(name)return (name=='QRCode' or name=='SystemMonitorWindow')end;click('Tab1')
end)
test('Unknown catalog versions never show green or red',function()
 R.online=false;click('Tab1');assert(control('Installed_ServerCommand').BackColor=='grey'and control('USB_ServerCommand').BackColor=='grey'and control('Online_ServerCommand').BackColor=='grey')
 assert(control('Online_ServerCommand').Text=='-');R.online=true;click('Tab1')
end)
test('Action header bulk-select and clear',function()
 click('Tab2')
 answers={{success=true,result=2}};click('Bulk');assert(control('Update').Text=='Update Drives (0)')
 answers={{success=true,result=1}};click('Bulk');assert(control('Update').Text=='Update Drives (1)')
 answers={{success=true,result=0}};click('Bulk');assert(control('Update').Text=='Update Drives (1)')
end)
test('Settings opens Drives; Apply and Cancel work',function()
 answers={{success=true,result=1},{success=true,result=1,states={USB=false}}};click('Settings');assert(not R.selectedDrives['/usb'])
 answers={{success=true,result=0,states={USB=true}}};click('Drives');assert(not R.selectedDrives['/usb'])
 answers={{success=true,result=1,states={USB=true}}};click('Drives');assert(R.selectedDrives['/usb'])
end)
test('Destination control explains the import pause instead of offering pool writes',function()
 click('Pool');assert(dialogs[#dialogs].title=='Showfile import paused')
 assert(control('Pool').Text=='Showfile import paused - Info')
end)
test('Drive version chooser selects actual package',function()
 answers={{success=true,result=1}};click('USB_ServerCommand');assert(R.localChoice.ServerCommand==source)
end)
test('Info, Help, Connection Details and Rescan work',function()
 click('Info_ServerCommand');assert(dialogs[#dialogs].message:find('2.3.15',1,true))
 click('Help_ServerCommand');assert(dialogs[#dialogs].message:find('Green = matches latest',1,true))
 R.connectionError='certificate verify failed';answers={{success=true,result=3}};click('Settings');assert(dialogs[#dialogs].message:find('certificate verify failed',1,true))
 answers={{success=true,result=2}};click('Settings');assert(events[#events]=='scan')
end)
test('No queued action and review cancellation do not update',function()
 answers={{success=true,result=2}};click('Bulk');click('Update');assert(ran==0 and dialogs[#dialogs].message:find('Choose an action',1,true))
 answers={{success=true,result=2}};click('Action_ServerCommand');answers={{success=true,result=0}};click('Update');assert(planned==1 and ran==0)
end)
test('Confirmed review refreshes showfile without scanning drives',function()
 local start=#events
 answers={{success=true,result=1},{success=true,result=1}};click('Update');assert(ran==1 and control('Update').Text=='Update Drives (0)')
 for i=start+1,#events do assert(events[i]~='scan','Update must not rescan drives') end
end)
test('Update opens progress with plain labels even if the native monitor class exists',function()
 local old=R.run;R.run=function()
  assert(control('WLTUpdating'):Parent()==displays[2].ScreenOverlay)
  assert(control('UpdatePercent').Text=='0%' and control('UpdateProgressFill').Visible=='No')
  assert(not pcall(control,'UpdateSystemMonitor'));assert(control('UpdateActivity1')._class=='UIObject')
  notify('Downloading',250,1000,true);local quarter=control('UpdateProgressFill').W
  assert(control('UpdatePercent').Text=='25%' and quarter>0)
  notify('Verifying',750,1000,true);assert(control('UpdateProgressFill').W==quarter*3)
  notify('Complete',1000,1000,true);assert(control('UpdatePercent').Text=='100%');return 'Done'
 end
 answers={{success=true,result=2}};click('Action_ServerCommand')
 local stops=progressStops;answers={{success=true,result=1},{success=true,result=1}};click('Update')
 assert(progressStops==stops+1 and not pcall(control,'WLTUpdating'));R.run=old
end)
test('Activity retains exactly the last three updater messages',function()
 env.ClassExists=function()return false end
 local old=R.run;R.run=function()
  assert(control('UpdateLogHeading').Text:find('Updater activity',1,true))
  for i=1,5 do notify('Message '..i,i,10,true)end
  notify('Transfer bytes',6,10,false)
  for i=1,3 do assert(control('UpdateActivity'..i).Text=='Message '..(i+2))end
  assert(not pcall(control,'UpdateActivity4'));return 'Done'
 end
 answers={{success=true,result=2}};click('Action_ServerCommand')
 answers={{success=true,result=1},{success=true,result=1}};click('Update')
 R.run=old;env.ClassExists=function(name)return name=='QRCode' or name=='SystemMonitorWindow'end
end)
test('Unexpected update error closes progress without forcing completion',function()
 local old=R.run;R.run=function()notify('Downloading',650,1000,true);error('Download failure')end
 answers={{success=true,result=2}};click('Action_ServerCommand')
 local stops=progressStops;answers={{success=true,result=1},{success=true,result=1}};click('Update')
 assert(progressValues[#progressValues]==650 and progressStops==stops+1)
 assert(not pcall(control,'WLTUpdating') and control('WadePluginUpdater'));R.run=old
end)
test('Progress popup setup failure clears busy state and partial window before any operation',function()
 answers={{success=true,result=2}};click('Action_ServerCommand')
 local before=ran;appendFailure=true
 answers={{success=true,result=1}};click('Update');appendFailure=false
 assert(ran==before and dialogs[#dialogs].message:find('Simulated popup setup failure',1,true))
 assert(not pcall(control,'WLTUpdating'));click('Tab3');assert(control('Tab3').State==1);click('Tab2')
end)
test('Showfile and drive action choices are separate for every plugin, including self',function()
 local oldVisible,oldCatalog=R.visible,R.catalog
 R.catalog=dofile('updater/src/core.lua').catalog(read('catalog.tsv'));R.visible=function()return R.catalog end
 local before=planned
 for tab=1,3 do
  click('Tab'..tab);answers={{success=true,result=2}};click('Bulk')
  for _,p in ipairs(R.catalog)do
   answers={{success=true,result=0}};click('Action_'..p.id)
   local expected=tab==1 and {[0]=true,[1]=true,[3]=true} or (tab==2 and {[0]=true,[2]=true} or {[0]=true,[1]=true,[2]=true})
   for _,cmd in ipairs(dialogs[#dialogs].commands)do assert(expected[cmd.value]);expected[cmd.value]=nil end
   assert(next(expected)==nil)
   if tab==1 then
    for _,mode in ipairs({1,3})do
     answers={{success=true,result=mode}};click('Action_'..p.id)
     assert(dialogs[#dialogs].title=='Showfile import paused' and planned==before)
     assert(control('Action_'..p.id).Text:find('Do Nothing',1,true))
    end
    answers={{success=true,result=2}};click('Action_'..p.id)
    assert(control('Action_'..p.id).Text:find('Do Nothing',1,true),'Showfile must reject injected drive-download choice')
   elseif tab==2 then
    answers={{success=true,result=3}};click('Action_'..p.id)
    assert(control('Action_'..p.id).Text:find('Do Nothing',1,true),'Drives must reject injected import choice')
   end
  end
 end
 R.catalog,R.visible=oldCatalog,oldVisible;click('Tab1')
end)
test('Bulk Showfile action explains pause and cannot stage a download',function()
 answers={{success=true,result=1}};click('Bulk')
 assert(dialogs[#dialogs].title=='Showfile import paused')
 assert(control('Action_ServerCommand').Text:find('Do Nothing',1,true))
 click('Update');assert(dialogs[#dialogs].title=='Showfile import paused')
 click('Tab2');answers={{success=true,result=1}};click('Bulk')
 assert(control('Action_ServerCommand').Text:find('Download from Internet',1,true))
end)
test('Offline menus keep paused Showfile imports and omit Internet drive downloads',function()
 R.online=false;click('Tab2');answers={{success=true,result=0}};click('Action_ServerCommand')
 assert(#dialogs[#dialogs].commands==1)
 click('Tab1');answers={{success=true,result=0}};click('Action_ServerCommand')
 assert(#dialogs[#dialogs].commands==3)
 R.online=true;click('Tab2')
end)
test('Unknown plugins have no download action; updater remains freely downloadable',function()
 local oldCheck,oldCatalog,oldVisible=R.canDownload,R.catalog,R.visible
 R.catalog=dofile('updater/src/core.lua').catalog(read('catalog.tsv'));R.visible=function()return R.catalog end
 R.canDownload=function(p)return p.id=='WadePluginUpdater'end
 click('Tab3');answers={{success=true,result=2}};click('Bulk')
 for _,p in ipairs(R.catalog)do
  answers={{success=true,result=0}};click('Action_'..p.id)
  local download=false;for _,cmd in ipairs(dialogs[#dialogs].commands)do if cmd.value==2 then download=true end end
  assert(download==(p.id=='WadePluginUpdater'))
  if p.id~='WadePluginUpdater'then
   answers={{success=true,result=2}};click('Action_'..p.id)
   assert(control('Action_'..p.id).Text:find('Do Nothing',1,true))
  end
 end
 R.canDownload,R.catalog,R.visible=oldCheck,oldCatalog,oldVisible;click('Tab2')
end)
test('Move screen preserves tab and actions; inactive screens disabled',function()
 answers={{success=true,result=2}};click('Bulk')
 click('Tab2');answers={{success=true,result=2}};click('Action_HippoRemote');click('Move');assert(control('Display4').Enabled=='No');click('CancelMove')
 click('Move');click('Display3');assert(control('WadePluginUpdater'):Parent()==displays[3].ScreenOverlay);assert(control('Tab2').State==1 and control('Update').Text=='Update Drives (1)')
end)
test('Busy guards and Cancel stop further work then close',function()
 local old=R.run;R.run=function()
  click('Tab3');assert(control('Tab2').State==1);click('CancelUpdate');assert(R.cancel);return 'Cancelled'
 end
 answers={{success=true,result=1},{success=true,result=1}};click('Update');R.run=old
 assert(not pcall(control,'WadePluginUpdater'));assert(env._G.__WadeLightingToolsWindow==nil)
end)
test('Cancel scan closes without creating main window',function()
 local old=R.scan;R.scan=function()click('CancelScan');assert(R.cancel);error('Cancelled')end
 launch();assert(not pcall(control,'WadePluginUpdater'));R.scan=old
end)
test('Close removes active window',function()launch();click('Close');assert(not pcall(control,'WadePluginUpdater'));assert(env._G.__WadeLightingToolsWindow==nil)end)
for name in pairs(sig)do assert(hits[name],'Untested callback '..name)end
print(count..' updater UI scenarios passed; every scripted callback exercised')
