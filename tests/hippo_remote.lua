local source=arg[1] or 'packages/HippoRemote/1.3.0/HippoRemote/Hippo_Remote.lua'
local controls,cmds,remote,packets,modalQueue,modalLog,indirect={},{},{},{},{},{},{}
local now=0;local feedback='Ok';local failRemote,failPacket,missingReply=false,nil,false
local function configuration()return setmetatable({},{__index=function(t,k)local v=configuration();rawset(t,k,v);return v end})end
local function ui(parent,class)
 local o={_parent=parent,_class=class,_children={}}
 setmetatable(o,{__index=function(t,k)if type(k)=='number' then local v=configuration();rawset(t,k,v);return v end end})
 function o:Parent()return self._parent end
 function o:Append(kind)local c=ui(self,kind);self._children[#self._children+1]=c;controls[#controls+1]=c;return c end
 return o
end
local function valid(o)return type(o)=='table' and not o._deleted end
local function markDeleted(o)o._deleted=true;for _,c in ipairs(o._children or {})do markDeleted(c)end end
local function node(props,parent,index)
 local names={};for k in pairs(props)do names[#names+1]=k end;table.sort(names)
 local o={_props=props,_parent=parent,_index=index}
 function o:PropertyCount()return #names end
 function o:PropertyName(i)return names[i+1]end
 function o:Get(name)assert(self._props[name]~=nil,'Unknown property probe: '..tostring(name));return self._props[name]end
 function o:Children()local list={};for _,c in ipairs(self._children or {})do list[#list+1]=c end;return list end
 function o:Parent()return self._parent end
 function o:Index()return self._index end
 function o:CmdlineIndex()return self._cmdIndex or self._index end
 function o:ToAddr()return self._addr or ('Object '..self._index)end
 return o
end
local all={}
for _,kind in ipairs({'Console','onPC','NetworkNode'})do all[kind]=node({Name=kind});all[kind]._children={}end
local function station(kind,name,ip,typ,status,session,index)
 local parent=all[kind]
 local o=node({Name=name,IP=ip,Type=typ,Status=status,SessionIndex=session,Session=session=='1' and 'TestShow' or 'Other',Enabled='Yes'},parent,index)
 parent._children[#parent._children+1]=o;return o
end
local localStation=station('Console','Main','10.0.0.1','FullSize','GlobalMaster','1',1)
local backup=station('Console','Backup','10.0.0.2','Light','Connected','1',2)
local available=station('Console','Available','10.0.0.3','Compact','Standalone','None',3)
local pc=station('onPC','Laptop','10.0.0.4','onPC','Connected','1',1)
station('Console','Far','10.5.0.2','Light','Standalone','None',4)
local nodeA=station('NetworkNode','Node A','10.0.0.11','Node','Connected','1',1)
local nodeB=station('NetworkNode','Node B','10.0.0.12','Node','Standalone','None',2)
local hippo=station('NetworkNode','Hippo Main','10.0.0.21','MediaServer','Connected','1',3)
local hippoB=station('NetworkNode','Hippo Backup','10.0.0.22','MediaServer','Connected','1',4)
station('NetworkNode','Other Session Hippo','10.0.0.23','MediaServer','Connected','2',5)
local displays={}
for i=1,3 do local d=ui(nil,'Display');d._index=i;d.W,d.H=1920,1080;d.ScreenOverlay=ui(d,'Overlay');displays[i]=d end
local theme={Button={BackgroundPlease='accent',BackgroundDelete='danger',BackgroundNormal='normal',BackgroundWarning='warning',TextPlease='yellow',TextDisabled='lightgrey'},Global={Transparent='transparent'}}
local pluginPool=node({Name='Plugins'},nil,1);local pool=node({Name='Default'},nil,2);pluginPool._parent=pool
local function drive(name,kind,number,path)
 local d=node({Name=name,DriveType=kind,Path=path},nil,number+100);d._cmdIndex=number;return d
end
local perEnvironment={}
local signals={};local env
local function getControl(name)
 for i=#controls,1,-1 do local c=controls[i];if c.Name==name and valid(c)then return c end end
 error('Missing control: '..name)
end
local function invoke(fn,...)
 local co=coroutine.create(fn);local ok,err=coroutine.resume(co,...);assert(ok,err)
 local iterations=0
 while coroutine.status(co)~='dead' do
  now=now+1;iterations=iterations+1;assert(iterations<2000,'Coroutine hung')
  ok,err=coroutine.resume(co);assert(ok,err)
 end
end
local function makeEnv(ip,name,subtype)
 local e=setmetatable({},{__index=_G});e._G=e;e.variables={};e.globals={StationName=name};e.busy=0
 e.plugin=node({Name='Hippo Remote'},pluginPool,13);e.plugin._addr='DataPool 2 Plugin 13'
 e.component={Parent=function()return e.plugin end}
 local tag=node({Name='Utility Plugins'},nil,5);function tag:GetReferences()return {e.plugin}end
 e.drives={drive('Internal','Internal',1,'/internal'),drive('USB A','Removeable',2,'/usb/a'),drive('USB B','Removable',7,'/usb/b')}
 e.root={ColorTheme={ColorGroups=theme},ShowData={Appearances={HippoRemote_V4_130={}}},Temp={DriveCollect={Children=function()return e.drives end}}}
 e.Root=function()return e.root end;e.UserVars=function()return e.variables end;e.GlobalVars=function()return e.globals end
 e.GetVar=function(t,k)return t[k]end;e.SetVar=function(t,k,v)t[k]=v;return true end
 e.IsObjectValid=valid
 e.Obj={Index=function(t)if t._index then return t._index end;for i,c in ipairs(t._parent._children)do if c==t then return i end end;error('No index')end,
 Delete=function(parent,index)local c=table.remove(parent._children,index);assert(c);markDeleted(c)end}
 e.HandleToInt=function(o)return tostring(o)end
 e.HostSubType=function()return subtype end
 e.FromAddr=function(addr)local kind=addr:match('^MAnetSocket%.HostTypes%.(.+)$');assert(kind and all[kind],addr);return all[kind]end
 e.ObjectList=function(q)assert(q=='Tag Thru',q);return {tag}end
 e.Time=function()return now end
 e.Printf=function()end;e.ErrPrintf=function(fmt,...)error(string.format(fmt,...))end
 e.GetFocusDisplay=function()return displays[1]end;e.GetDisplayByIndex=function(i)return displays[i]end
 e.GetShowFileStatus=function()if e.busy>0 then e.busy=e.busy-1;return 'ShowSaving' end;return 'ShowLoaded'end
 e.Cmd=function(cmd)
  cmds[#cmds+1]={ip=ip,cmd=cmd}
  if cmd:match('^SaveShow If Drive ')then e.busy=1 end
  return feedback
 end
 e.CmdIndirectWait=function(cmd,undo,display)indirect[#indirect+1]={cmd=cmd,display=display};assert(display==displays[1] or display==displays[3])end
 e.RemoteCommand=function(target,command)
  remote[#remote+1]={ip=target,cmd=command}
  if failRemote then return false end
  local targetEnv=perEnvironment[target]
  local lua=command:match('^Lua "(.*)"$')
  if lua then assert(targetEnv,'Reply origin unavailable');assert(load(lua,'reply','t',targetEnv))();return true end
  local dp,pi,arg=command:match('^Go%+ DataPool (%d+) Plugin (%d+) "(.*)"$')
  if arg then assert(dp=='2' and pi=='13','Remote worker address must be data-pool qualified');if not missingReply then invoke(targetEnv.main,nil,arg)end;return true end
  return true
 end
 e.MessageBox=function(def)modalLog[#modalLog+1]=def;return table.remove(modalQueue,1)or{success=true,result=1}end
 e.require=function(mod)
  assert(mod=='socket')
  return {udp=function()return {settimeout=function()end,sendto=function(_,packet,target,port)
   packets[#packets+1]={ip=target,port=port,packet=packet}
   if (failPacket==target and packet:sub(-4)==string.pack('>i4',1)) or (failPacket=='reset' and packet:sub(-4)==string.pack('>i4',0)) then return nil,'simulated UDP failure'end
   return #packet
  end,close=function()end}end}
 end
 local sig={};e.sig=sig
 e.main=assert(loadfile(source,'t',e))('Hippo Remote','Main',sig,e.component)
 perEnvironment[ip]=e;return e
end
env=makeEnv('10.0.0.1','Main','FullSize');local remoteEnv=makeEnv('10.0.0.2','Backup','Light');signals=env.sig
local callbackHits={}
for name,fn in pairs(signals)do local original=fn;signals[name]=function(...)callbackHits[name]=(callbackHits[name]or 0)+1;return original(...)end end
local function resetLogs()cmds,remote,packets,indirect,modalLog={},{},{},{},{}end
local function open(tab)
 env.variables.HippoRemoteStartTab=tab;env.main(displays[1]);resetLogs()
end
local function choose(ip)
 for i=#controls,1,-1 do local c=controls[i];if valid(c)and c._class=='CheckBox'and type(c.Text)=='string'and c.Text:find(ip,1,true)then signals.HRDevice(c);return c end end
 error('No selectable IP '..ip)
end
local function action(label)
 for i=#controls,1,-1 do local c=controls[i];if valid(c)and c.Clicked=='HRAction'and c.Text:match('^[^\n]+')==label then signals.HRAction(c);return end end
 error('No action '..label)
end
local results={}
local function test(name,fn)fn();results[#results+1]=name;print('PASS '..name)end
test('Hippo-only UI, source identity, inherited style, appearance and callbacks',function()
 open('hippo');assert(getControl('HippoHeading').Text=='HIPPO SERVERS')
 assert(env.plugin.Appearance==env.root.ShowData.Appearances.HippoRemote_V4_130)
 local devices,actions=0,0
 for _,c in ipairs(controls)do if valid(c)then
  assert(c.Name~='TabConsole'and c.Name~='TabNode'and c.Name~='TabHippo')
  if c.Clicked then assert(type(signals[c.Clicked])=='function',c.Clicked) end
  if c._class=='CheckBox'then devices=devices+1;assert(c.BackColor=='normal'and c.Margin.left==4)end
  if c.Clicked=='HRAction'then actions=actions+1;assert(c.BackColor=='normal'and c.Margin.left==7)end
 end end
 assert(devices==2 and actions==3);assert(getControl('DeviceBorder1').BackColor=='accent')
 assert(getControl('HippoRemoteScroll')._class=='ScrollBox')
end)
for _,pair in ipairs({{'SHUTDOWN MACHINE','/hippo/shutdown/machine'},{'RESTART MACHINE','/hippo/restart/machine'},{'STOP ENGINE HOST','/hippo/shutdown/host'}})do
 test(pair[1]..' trigger/reset bytes and destinations',function()
  open('hippo');choose('10.0.0.21');choose('10.0.0.22');action(pair[1]);assert(#packets==0);invoke(signals.HRConfirm)
  assert(#packets==4 and #cmds==0 and #remote==0)
  for i,p in ipairs(packets)do assert(p.port==7000);assert(p.packet:sub(1,#pair[2])==pair[2]);assert(#p.packet%4==0);assert(p.packet:sub(-4)==string.pack('>i4',i<=2 and 1 or 0));assert(p.ip=='10.0.0.21'or p.ip=='10.0.0.22')end
 end)
end
test('Select All, Clear, checkbox toggle, Cancel never send',function()
 open('hippo');action('SHUTDOWN MACHINE');invoke(signals.HRConfirm);assert(#packets==0)
 signals.HRAll();assert(getControl('Device1').State==1 and getControl('Device2').State==1);action('SHUTDOWN MACHINE');signals.HRClear();invoke(signals.HRConfirm);assert(#packets==0)
 choose('10.0.0.21');action('SHUTDOWN MACHINE');signals.HRCancel();invoke(signals.HRConfirm);assert(#packets==0)
 action('SHUTDOWN MACHINE');choose('10.0.0.22');invoke(signals.HRConfirm);assert(#packets==0)
end)
test('Refresh cancels pending action and clears target selection',function()
 open('hippo');signals.HRAll();action('RESTART MACHINE');signals.HRRefresh();invoke(signals.HRConfirm);assert(#packets==0);assert(getControl('Device1').State==0)
end)
test('Preferences preserves old Hippo variables without touching Server Command',function()
 env.variables.ServerCommandOscPort='8123';open('hippo')
 modalQueue={{success=true,result=1,inputs={['UDP Port']='9000',['Shutdown Machine']='/test/shutdown',['Restart Machine']='/test/restart',['Stop Engine Host']='/test/stop'}}}
 signals.HRSettings();assert(env.variables.HippoRemoteOscPort=='9000');assert(env.variables.HippoRemoteOscShutdownMachine=='/test/shutdown');assert(env.variables.ServerCommandOscPort=='8123')
 for _,command in ipairs(modalLog[#modalLog].commands)do assert(not command.name:find('START:')) end
 choose('10.0.0.21');action('SHUTDOWN MACHINE');invoke(signals.HRConfirm);assert(packets[1].port==9000 and packets[1].packet:sub(1,14)=='/test/shutdown')
end)
test('Invalid preferences are atomic, Cancel and Defaults work',function()
 open('hippo')
 for _,port in ipairs({'0','65536','123.5'})do
  modalQueue={{success=true,result=1,inputs={['UDP Port']=port,['Shutdown Machine']='/valid',['Restart Machine']='/valid',['Stop Engine Host']='/valid'}}};signals.HRSettings();assert(env.variables.HippoRemoteOscPort=='9000')
 end
 modalQueue={{success=true,result=1,inputs={['UDP Port']='9100',['Shutdown Machine']='/changed',['Restart Machine']='bad path',['Stop Engine Host']='/valid'}}};signals.HRSettings();assert(env.variables.HippoRemoteOscShutdownMachine=='/test/shutdown')
 modalQueue={{success=true,result=0}};signals.HRSettings();assert(env.variables.HippoRemoteOscPort=='9000')
 modalQueue={{success=true,result=5}};signals.HRSettings();assert(env.variables.HippoRemoteOscPort=='7000'and env.variables.HippoRemoteOscShutdownMachine=='/hippo/shutdown/machine')
end)
test('Preferences cancels any armed command',function()
 open('hippo');choose('10.0.0.21');action('RESTART MACHINE');modalQueue={{success=true,result=0}};signals.HRSettings();invoke(signals.HRConfirm);assert(#packets==0)
end)
test('Same display chooser layout, disabled screens, cancel and retained selection',function()
 open('hippo');choose('10.0.0.21');action('RESTART MACHINE');signals.HRMove()
 assert(getControl('Display1').State==1 and getControl('Display4').Enabled=='No')
 assert(getControl('Display5').Anchors.left==0 and getControl('Display5').Anchors.top==0)
 assert(getControl('Display7').Anchors.left==1 and getControl('Display7').Anchors.top==2)
 signals.HRCancelMove();signals.HRMove();signals.HRDisplay(getControl('Display3'))
 assert(getControl('HippoRemoteWindow'):Parent()==displays[3].ScreenOverlay)
 local selected=false;for _,c in ipairs(controls)do if valid(c)and c._class=='CheckBox'and c.Text:find('10.0.0.21',1,true)and c.State==1 then selected=true end end;assert(selected)
 invoke(signals.HRConfirm);assert(#packets==0,'Screen move must disarm the operation')
 action('RESTART MACHINE');invoke(signals.HRConfirm);assert(#packets==2)
end)
test('Launch uses focused screen, explicit screen and Close button',function()
 env.GetFocusDisplay=function()return displays[2]end;env.main();assert(getControl('HippoRemoteWindow'):Parent()==displays[2].ScreenOverlay)
 signals.HRClose();assert(not pcall(getControl,'HippoRemoteWindow'));env.GetFocusDisplay=function()return displays[1]end
 env.main(displays[3]);assert(getControl('HippoRemoteWindow'):Parent()==displays[3].ScreenOverlay);signals.HRClose()
end)
for _,change in ipairs({{'Status','Offline'},{'SessionIndex','2'},{'Name','Replacement'},{'Enabled','No'},{'Type','Node'}})do
 test('Revalidate target '..change[1]..' before sending',function()
  open('hippo');choose('10.0.0.21');action('SHUTDOWN MACHINE');local old=hippo._props[change[1]];hippo._props[change[1]]=change[2];invoke(signals.HRConfirm);hippo._props[change[1]]=old;assert(#packets==0)
 end)
end
test('Partial OSC failure resets hosts successfully triggered and leaves window open',function()
 open('hippo');signals.HRAll();action('SHUTDOWN MACHINE');failPacket='10.0.0.22';invoke(signals.HRConfirm);failPacket=nil
 assert(#packets==3);assert(packets[3].ip=='10.0.0.21'and packets[3].packet:sub(-4)==string.pack('>i4',0));assert(valid(getControl('HippoRemoteWindow')))
end)
test('UDP reset failure is reported and leaves window open',function()
 open('hippo');choose('10.0.0.21');action('RESTART MACHINE');failPacket='reset';invoke(signals.HRConfirm);failPacket=nil;assert(#packets==2);assert(valid(getControl('HippoRemoteWindow')))
end)
test('Missing LuaSocket does not execute alternate native commands',function()
 open('hippo');choose('10.0.0.21');action('RESTART MACHINE');local saved=env.require;env.require=function()error('unavailable')end;invoke(signals.HRConfirm);env.require=saved
 assert(#packets==0 and #cmds==0 and #remote==0);assert(valid(getControl('HippoRemoteWindow')))
end)
test('Busy guard blocks repeated confirmation, moves and selection changes',function()
 open('hippo');choose('10.0.0.21');action('RESTART MACHINE');local co=coroutine.create(signals.HRConfirm);local ok,err=coroutine.resume(co);assert(ok,err);assert(#packets==1)
 invoke(signals.HRConfirm);signals.HRMove();signals.HRClear();signals.HRClose();signals.HRRefresh();assert(#packets==1)
 while coroutine.status(co)~='dead'do ok,err=coroutine.resume(co);assert(ok,err)end
 assert(#packets==2)
end)
test('Empty discovery still builds a usable window',function()
 local old=all.NetworkNode._children;all.NetworkNode._children={};open('hippo');assert(getControl('HippoHeading'));signals.HRAll();action('SHUTDOWN MACHINE');invoke(signals.HRConfirm);assert(#packets==0);signals.HRClose();all.NetworkNode._children=old
end)
for name in pairs(signals)do assert(callbackHits[name]and callbackHits[name]>0,'Untested callback '..name)end
print('TOTAL '..#results..' Hippo Remote scenarios passed; every scripted button callback exercised; no real OSC sent')
