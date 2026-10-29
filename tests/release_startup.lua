-- Compile and run the actual ZIP's Lua chunk with Lua 5.5 and MA object mocks.
-- No plugin import, show modification, filesystem write, or network request.
assert(_VERSION=='Lua 5.5','This regression requires Lua 5.5')
local scenario=arg[2] or 'normal'
local version=arg[3] or '1.1.7'
local appearance='PluginUpdator_'..version:gsub('%.','_')
for _,name in ipairs({'core','transport','runtime','display','main'})do
 assert(loadfile('updater/src/'..name..'.lua'))
end
local nodes,events,dialogs={},{},{}
local function config()return setmetatable({},{__index=function(t,k)local v=config();rawset(t,k,v);return v end})end
local function object(parent,class,properties,index)
 local o={_parent=parent,_class=class,_children={},_props=properties or {},_index=index}
 local keys={};for key in pairs(o._props)do keys[#keys+1]=key end
 setmetatable(o,{__index=function(t,k)if type(k)=='number'then local v=config();rawset(t,k,v);return v end end})
 function o:Append(c)
  if c=='BaseInput'then events[#events+1]='window'end
  local child=object(self,c);self._children[#self._children+1]=child;nodes[#nodes+1]=child;return child
 end
 function o:Parent()return self._parent end
 function o:Children()return self._children end
 function o:CmdlineIndex()return self._index end
 function o:PropertyCount()return #keys end
 function o:PropertyName(n)return keys[n+1]end
 function o:Get(k)return self._props[k]end
 function o:ToAddr()return 'DataPool 1 Plugin 12'end
 return o
end
local display=object(nil,'Display');display.W=1920;display.H=1080;display.ScreenOverlay=object(display,'Overlay')
local pool=object(nil,'DataPool',{Name='Main'},1);pool.Plugins=object(pool,'Plugins')
local drives=object(nil,'DriveCollect')
drives._children={object(drives,'Drive',{Name='Internal',Path='/mock/internal',DriveType='Harddisk'},1),
 object(drives,'Drive',{Name='USB',Path='/mock/usb',DriveType='Removeable'},2)}
local root={Temp={DriveCollect=drives},ShowData={DataPools=object(nil,'DataPools'),Appearances={[appearance]={}}},
 ColorTheme={ColorGroups={Button={BackgroundNormal='grey',BackgroundPlease='green',TextPlease='yellow',TextDisabled='lightgrey'},Global={Transparent='clear',Text='white'}}}}
root.ShowData.DataPools._children={pool}
local sig={};local plugin=object(nil,'Plugin');local component={Parent=function()return plugin end}
local env=setmetatable({},{__index=_G});env._G=env
env.Root=function()return root end;env.DataPool=function()return pool end
env.GetFocusDisplay=function()return display end;env.GetDisplayByIndex=function(i)if i==1 then return display end end
env.IsObjectValid=function(o)return type(o)=='table'and not o._deleted end
env.GetPath=function(kind,create)
 assert(type(kind)=='string' or math.type(kind)=='integer','GetPath: wrong parameter #1')
 assert(kind=='plugins' and create==false,'Unexpected plugin library path request')
 if scenario=='missing-root' then return nil end
 return '/mock/internal/plugins'
end
env.GetPathOverrideFor=function(kind,path,create)
 assert(kind=='plugins' and type(path)=='string' and create==false,'GetPathOverrideFor: wrong parameter')
 return path..'/plugins'
end
env.GetPathType=function(handle,content)
 assert(handle==plugin and content==1,'GetPathType must receive the plugin and User content type')
 if scenario=='empty-type' then return '' end
 return 'plugins'
end
if scenario=='missing-type' then env.GetPathType=false end
-- Match the console: there is no PathType.UserPlugins entry.
env.Enums={PathType={}}
env.DirList=function(path)events[#events+1]='scan:'..path;return{}end
env.FileExists=function()return false end
env.CreateDirectoryRecursive=function()events[#events+1]='offline';return false end
env.HostOS=function()return 'Linux'end;env.Version=function()return '2.5.1.1'end
env.Time=function()return 100 end;env.Printf=function()end
env.MessageBox=function(d)dialogs[#dialogs+1]=d;return{success=true,result=0}end
env.StartProgress=function()return 1 end;env.StopProgress=function()end;env.SetProgressText=function()end
env.ObjectList=function()return{}end;env.Cmd=function()return'OK'end
env.Obj={Index=function(o)for i,c in ipairs(o._parent._children)do if c==o then return i end end end,
 Delete=function(parent,i)local o=table.remove(parent._children,i);o._deleted=true end}
local chunk=assert(loadfile(assert(arg[1]),'t',env))
local entry=chunk('WLT Plugin Updator','Main',sig,component)
assert(type(entry)=='function','Release did not return its main function')
entry()
if scenario=='missing-root' then
 assert(#dialogs==1 and dialogs[1].message:find('MA plugin library path is unavailable',1,true))
 assert(#events==0,'Failed path lookup must stop before scanning, downloading, or opening a window')
 assert(env._G.__WadeLightingToolsWindow.busy==false)
 print('PASS actual release reports unavailable library path without an API argument error')
 return
end
assert(#dialogs==0,dialogs[1]and dialogs[1].message)
local window,scanned,offline,title,rows=false,false,false,false,0
local windows=0
local scannedDrives={}
for _,event in ipairs(events)do
 if event:find('scan:',1,true)==1 then
  assert(not window);scanned=true
  if event:find('/mock/internal/plugins',1,true) then scannedDrives.internal=true end
  if event:find('/mock/usb/plugins',1,true) then scannedDrives.usb=true end
 end
 if event=='offline'then assert(scanned);offline=true end
 if event=='window'then windows=windows+1;if windows==1 then assert(not scanned)else assert(scanned and offline);window=true end end
end
for _,o in ipairs(nodes)do
 if o._class=='TitleButton'and o.Text=='WLT Plugin Updator  v'..version then title=true end
 if o.Name=='PluginScroll'then rows=rows+1 end
end
assert(scannedDrives.internal and scannedDrives.usb,'Both internal and USB libraries must be scanned')
assert(window and title and rows==1,'Bundled release did not build the offline showfile tab')
assert(plugin.Appearance==root.ShowData.Appearances[appearance])
assert(type(sig.WLTClose)=='function');sig.WLTClose();assert(env._G.__WadeLightingToolsWindow==nil)
print('PASS ['..scenario..'] actual release compiles, returns main, scans two drives, opens offline, binds its image, and closes in Lua 5.5')
