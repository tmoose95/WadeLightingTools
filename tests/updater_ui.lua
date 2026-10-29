-- Callback/UI wiring simulation, without a console or network client.
local nodes,dialogs,answers,events={},{},{},{}
local function config()return setmetatable({},{__index=function(t,k)local c=config();rawset(t,k,c);return c end})end
local function object(parent,class)
 local o={_parent=parent,_class=class,_children={}}
 setmetatable(o,{__index=function(t,k)if type(k)=='number'then local c=config();rawset(t,k,c);return c end end})
 function o:Append(kind)local c=object(self,kind);self._children[#self._children+1]=c;nodes[#nodes+1]=c;return c end
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
local root={ColorTheme={ColorGroups={Button={BackgroundNormal='grey',BackgroundPlease='green',TextPlease='yellow',TextDisabled='lightgrey'},Global={Transparent='clear',Text='white'}}},ShowData={Appearances={WadePluginUpdater={}},DataPools=pools}}
local R={catalog={{id='ServerCommand',name='Server Command',version='2.3.15'},{id='HippoRemote',name='Hippo Remote',version='1.3.0'}},drives={{path='/usb',label='USB'}},selectedDrives={['/usb']=true},pool=pools[1],online=true,issues={},mode=1}
R.children=function(h)return h end;R.index=function(h)return h._index end;R.prop=function(h,k)return h[k]or''end
R.status=function(p)return p.id=='ServerCommand'and'Update available'or'Not installed'end
R.scan=function(connect)events[#events+1]='scan';if #events==1 then assert(not pcall(control,'WadePluginUpdater'),'Window opened before initial scan')end end
R.drivesSelected=function()return R.selectedDrives['/usb']and R.drives or{}end
R.localBest=function()return {version='1.0.0'}end;R.installedText=function()return '1.0.0'end
R.refreshInstalled=function()events[#events+1]='pool'end
local planned,ran=0,0
R.plan=function(selected)
 local ids={};for id,on in pairs(selected)do if on then ids[#ids+1]=id end end
 assert(#ids>0,'Select at least one plugin')
 planned=planned+1;return {mode=R.mode,drives=R.drivesSelected(),lines=ids}
end
R.run=function(plan)ran=ran+1;return 'Done'end
local sig={};local plugin=object(nil,'Plugin');local component={Parent=function()return plugin end}
local env=setmetatable({signalTable=sig,myHandle=component,Core={},Transport={},BOOTSTRAP='',Runtime=function()return R end},{__index=_G});env._G=env
function env.safe(fn,fallback)local ok,v=pcall(fn);if ok then return v end;return fallback end
function env.button(parent,col,row,name,text,clicked,color)local b=parent:Append('Button');b.Name=name;b.Text=text;b.Clicked=clicked;b.BackColor=color;b.Anchors={left=col,right=col,top=row,bottom=row};return b end
env.Root=function()return root end;env.GetFocusDisplay=function()return displays[2]end;env.GetDisplayByIndex=function(i)return displays[i]end;env.IsObjectValid=valid
env.Obj={Index=function(o)if o._index then return o._index end;for i,c in ipairs(o._parent._children)do if c==o then return i end end end,Delete=function(parent,i)delete(table.remove(parent._children,i))end}
env.MessageBox=function(d)dialogs[#dialogs+1]=d;return table.remove(answers,1)or{success=true,result=0}end
env.StartProgress=function()return 1 end;env.StopProgress=function()end;env.SetProgressText=function()end;env.ObjectList=function()return{}end;env.Cmd=function()return'OK'end
local function read(path)local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local launch=assert(load(read('updater/src/display.lua')..'\n'..read('updater/src/main.lua'),'updater-ui','t',env))()
local hits={};for name,fn in pairs(sig)do sig[name]=function(...)hits[name]=true;return fn(...)end end
local count=0;local function test(name,fn)fn();count=count+1;print('PASS '..name)end
local function click(name)local c=control(name);assert(sig[c.Clicked],c.Clicked or name);sig[c.Clicked](c)end
test('Startup scans before UI and uses caller display',function()launch();assert(events[1]=='scan');assert(control('WadePluginUpdater'):Parent()==displays[2].ScreenOverlay)end)
test('All visible buttons bind to real callbacks and list uses scrolling',function()for _,c in ipairs(nodes)do if valid(c)and c.Clicked then assert(sig[c.Clicked],c.Clicked)end end;assert(control('PluginScroll')._class=='ScrollBox')end)
test('Select Updates selects updates only and Clear resets them',function()click('All');assert(control('Update').Text=='UPDATE (1)');assert(control('Item_ServerCommand').Text:find('[x]',1,true));assert(control('Item_HippoRemote').Text:find('[ ]',1,true));click('Clear');assert(control('Update').Text=='UPDATE (0)')end)
test('Both row selections toggle and mode buttons select all three modes',function()click('Item_HippoRemote');assert(control('Update').Text=='UPDATE (1)');click('Item_HippoRemote');assert(control('Update').Text=='UPDATE (0)');for i=1,3 do click('Mode'..i);assert(R.mode==i and control('Mode'..i).State==1)end end)
test('Drive selection Apply and Cancel',function()answers={{success=true,result=1,states={USB=false}}};click('Drives');assert(not R.selectedDrives['/usb']);answers={{success=true,result=0,states={USB=true}}};click('Drives');assert(not R.selectedDrives['/usb']);answers={{success=true,result=1,states={USB=true}}};click('Drives');assert(R.selectedDrives['/usb'])end)
test('Destination DataPool changes and refreshes installed versions',function()answers={{success=true,result=2}};click('Pool');assert(R.pool==pools[2]and events[#events]=='pool')end)
test('Details and Rescan operate',function()click('Details');assert(dialogs[#dialogs].title=='Updater details');click('Rescan');assert(events[#events]=='scan')end)
test('No selection reports error and review Cancel does not run',function()click('Clear');click('Update');assert(ran==0 and dialogs[#dialogs].message:find('Select at least one plugin'));click('All');answers={{success=true,result=0}};click('Update');assert(planned==1 and ran==0)end)
test('Review Apply runs requested mode then refreshes and clears',function()answers={{success=true,result=1},{success=true,result=1}};click('Update');assert(ran==1);assert(control('Update').Text=='UPDATE (0)'and events[#events]=='scan')end)
test('Display chooser disabled screens, Cancel and retained selection',function()click('All');click('Move');assert(control('Display4').Enabled=='No');click('CancelMove');click('Move');click('Display3');assert(control('WadePluginUpdater'):Parent()==displays[3].ScreenOverlay);assert(control('Update').Text=='UPDATE (1)')end)
test('Busy guards and Close requests safe cancellation',function()
 local old=R.run;R.run=function(plan)
  click('Clear');click('Mode1');click('Move');click('Close');assert(R.cancel==true);assert(control('Update').Text=='UPDATE (1)');assert(R.mode==3);return 'Cancelled'
 end
 answers={{success=true,result=1},{success=true,result=1}};click('Update');R.run=old;assert(control('WadePluginUpdater'))
end)
test('Close removes the active window',function()click('Close');assert(not pcall(control,'WadePluginUpdater'));assert(env._G.__WadeLightingToolsWindow==nil)end)
for name in pairs(sig)do assert(hits[name],'Untested callback '..name)end
print(count..' updater UI scenarios passed; every scripted callback exercised')
