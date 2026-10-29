-- Uses a temporary filesystem and mocked MA objects. Never connects to hardware.
local C=dofile('updater/src/core.lua');local Runtime=dofile('updater/src/runtime.lua');local lfs=require('lfs')
local home=os.tmpname();os.remove(home);assert(lfs.mkdir(home))
local function mkdir(path)
 local part='';for s in path:gmatch('[^/]+')do part=part..'/'..s;if not lfs.attributes(part)then assert(lfs.mkdir(part))end end;return true
end
local function read(p) local f=io.open(p,'rb');if not f then return nil end;local s=f:read('*a');f:close();return s end
local function write(p,s)mkdir(p:match('^(.*)/[^/]+$'));local f=assert(io.open(p,'wb'));assert(f:write(s));assert(f:close())end
local function obj(properties,n)
 local o={props=properties or {},n=n,list={},alive=true};local names={};for k in pairs(o.props)do names[#names+1]=k end;table.sort(names)
 function o:PropertyCount()return #names end;function o:PropertyName(i)return names[i+1]end;function o:Get(k)return self.props[k]end
 function o:CmdlineIndex()return self.n end;function o:Children()return self.list end
 function o:Export(path,name)
  if self.failBackup then return false end
  if self.imported then
   write(path..'/'..name,self.imported.xml)
   for filename,data in pairs(self.imported.files) do write(path..'/'..filename,data) end
   return true
  end
  write(path..'/'..name,'<GMA3><UserPlugin Name="'..self.props.Name..'" Author="Aaron Wade" Version="'..self.props.Version..'" Path="'..self.props.Path..'"><ComponentLua FileName="original.lua" /></UserPlugin></GMA3>')
  if not self.missingBackup then write(path..'/original.lua',self.emptyBackup and '' or 'return function() end')end;return true
 end
 return o
end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS '..name)end
local catalogText=assert(read('catalog.tsv'))
local all=C.catalog(catalogText);local p;for _,v in ipairs(all)do if v.id=='ServerCommand'then p=v end end
local single='WLT-CATALOG\t1\n'..table.concat({'PLUGIN',p.id,p.name,p.version,p.minimum,p.folder,p.manifest,p.digest},'\t')..'\n'
local root,pool,drives,R,trace,mode,calls,imports,progress,repairs,timers,workerProgress
local Worker=dofile('updater/src/self_update.lua')
local function factory(job)return Worker.script(job,read('updater/src/core.lua'),read('updater/src/self_update.lua'))end
local function setup(options)
 options=options or {};local path=home..'/case'..(count+1);mkdir(path)
 trace={};calls={};imports={};progress={};repairs={};timers={};workerProgress={};mode=options
 local handles={};local handlesById={}
 function HandleToStr(h)if not handles[h]then local id='H#'..(#handlesById+1);handlesById[#handlesById+1]=h;handles[h]=id end;return handles[h]end
 function StrToHandle(id)return handlesById[tonumber(id:match('H#(%d+)'))]end
 function CmdIndirect()end
 function Timer(fn)if options.timerFail then error('Timer unavailable')end;timers[#timers+1]=fn end
 function StartProgress()return 42 end;function StopProgress()workerProgress.stopped=true end
 function SetProgressRange(_,lo,hi)assert(lo==0 and hi==1000)end
 function SetProgress(_,value)workerProgress[#workerProgress+1]=value end
 function SetProgressText()end
 local d1=obj({Name='Internal',Path=path..'/internal',DriveType='Harddisk'},1)
 local d2=obj({Name='USB A',Path=path..'/usb-a',DriveType='Removeable'},2)
 local d7=obj({Name='USB B',Path=path..'/usb-b',DriveType='Removable'},7)
 drives=options.noUSB and {d1} or {d1,d2,d7}
 if options.oldVersions then
  drives[#drives+1]=obj({Name='gma3_2.4.2',Path=path..'/gma3_2.4.2',DriveType='OldVersion'},8)
  drives[#drives+1]=obj({Name='Remote Station',Path=path..'/remote',DriveType='RemoteDrive'},9)
 end
 if options.duplicate then drives[#drives+1]=obj({Name='Duplicate',Path=d2.props.Path,DriveType='Removeable'},10) end
 for _,d in ipairs(drives)do mkdir(d.props.Path..'/plugins')end
 pool=obj({Name='Tour'},4);pool.Plugins=obj();pool.Plugins.list={}
 root={Temp={DriveCollect=obj()},ShowData={DataPools=obj()}};root.Temp.DriveCollect.list=drives;root.ShowData.DataPools.list={pool}
 function Root()return root end;function DataPool()return pool end
 Enums={PathType={}}
 local updater=obj({Name='WLT Plugin Updator'},12)
 local expectedType=options.customPathType or 'plugins'
 GetPathType=not options.missingPathType and function(handle,content)
  assert(handle==updater and content==1,'Wrong plugin handle or path content type')
  return expectedType
 end or nil
 function GetPath(kind,create)
  assert(kind==expectedType and create==false,'GetPath: wrong parameter #1')
  if options.missingRoot then return nil end
  return d1.props.Path..'/plugins'
 end
 function GetPathOverrideFor(kind,path,create)
  assert(kind==expectedType and type(path)=='string' and create==false,'GetPathOverrideFor: wrong parameter')
  if options.missingUSB and path==d2.props.Path then return '' end
  return path..'/plugins'
 end
 function IsObjectValid(o)return type(o)=='table' and o.alive==true end
 function CreateDirectoryRecursive(path)return mkdir(path)end
 function FileExists(path)return lfs.attributes(path,'mode')=='file'end
 function DirList(path,filter)
  trace[#trace+1]='scan:'..path;local a={};if lfs.attributes(path,'mode')~='directory'then return a end
  for name in lfs.dir(path)do if name~='.'and name~='..'and (filter=='*'or name:match('%.xml$'))then a[#a+1]={name=name}end end;return a
 end
 local clock=0;function Time()clock=clock+.2;return clock end
 function HostOS()return 'Linux'end;function Version()return options.oldRuntime and '2.4.0.0'or '2.5.1.1'end
 function Printf()end
 function MessageBox(box)repairs[#repairs+1]=box;return {success=true,result=options.repair and 1 or 0}end
 local function add(slot,ver,target)
  target=target or pool
  local h=obj({Name='Server Command',Version=ver or '2.3.14',Author='Aaron Wade',Path='/ServerCommand',Lock='No'},slot)
  function h:Import(folder,filename)
   imports[#imports+1]={handle=self,pool=target,slot=slot,folder=folder,filename=filename}
   assert(folder:sub(1,1)=='/' and not filename:find('/'),'Object Import requires directory and filename')
   if options.importFail then return false end
   local xml=assert(read(folder..'/'..filename));local m=assert(C.xml(xml))
   -- Reproduce the console's resource lookup: the native object import does
   -- not resolve external FileName beside this XML, even when that file exists.
   if #m.components>0 then self.resourceMissing=true;return true end
   if options.noReadback then return true end
   self.props.Name=m.Name;self.props.Version=m.Version;self.props.Path=m.Path;self.props.Author=m.Author
   if options.normalizedVersion then self.props.Version=m.Version..'.0' end
   self.imported={xml=xml,files={}}
   if options.staleCode then
    self.imported.xml=xml:gsub('(<ComponentLua[^>]*>).-</ComponentLua>',function(header)
     return header..'<FileContent Size="1"><Block Base64="b2xkIGNvZGU="/></FileContent></ComponentLua>'
    end,1)
   end
   self.imported.codes=C.luaContents(self.imported.xml,function()error('Unexpected external code lookup')end)
   return true
  end
  target.Plugins[slot]=h;target.Plugins.list[#target.Plugins.list+1]=h;return h
 end
 if options.installed then add(13,options.installed)end
 if options.two then add(26,options.installed)end
 if options.selfInstalled then updater=add(12,'1.1.4');updater.props.Name='WLT Plugin Updator';updater.props.Path='/WLT Plugin Updator' end
 function Cmd(command)
  calls[#calls+1]=command
  local n,slot=command:match('^Store DataPool (%d+) Plugin (%d+) /NoConfirmation$')
  local target;for _,candidate in ipairs(root.ShowData.DataPools.list)do if candidate.n==tonumber(n)then target=candidate end end
  assert(target,command);slot=tonumber(slot);assert(not target.Plugins[slot],'Store must only create an empty slot')
  add(slot,'0.0.0',target)
  return 'Ok'
 end
 local function transport()
  return {get=function(remote,limit,onProgress)
   trace[#trace+1]='http:'..remote
   if options.offline then error('offline')end
   if remote=='catalog.tsv'then return options.fullCatalog and catalogText or single end
   local result=assert(read(remote));if options.corrupt and remote:match('%.lua$')then result=result..'x'end
   if onProgress then onProgress(0);onProgress(math.floor(#result/2));onProgress(#result)end
   if options.cancelDownload and onProgress then R.cancel=true end
   return result
  end}
 end
 R=Runtime(C,transport,single,function(text,current,total,log)
  if current and total then progress[#progress+1]={text=text,value=current/total,log=log}end
 end,updater,nil,factory)
 if not options.noPackage then
  local folder=d1.props.Path..'/plugins/ServerCommand'
  write(folder..'/Server_Command_v2.3.14.xml','<GMA3><UserPlugin Name="Server Command" Version="2.3.14" Author="Aaron Wade" Path="/ServerCommand"><ComponentLua FileName="Server_Command.lua" /></UserPlugin></GMA3>')
  write(folder..'/Server_Command.lua','return function()end')
 end
 R.scan(true)
 progress={}
 return add
end
local function localPackage(d,version)
 local folder=d.props.Path..'/plugins/ServerCommand'
 write(folder..'/Server_Command_v'..version..'.xml','<GMA3><UserPlugin Name="Server Command" Version="'..version..'" Author="Aaron Wade" Path="/ServerCommand"><ComponentLua FileName="Server_Command.lua" /></UserPlugin></GMA3>')
 write(folder..'/Server_Command.lua','return function()end');return folder
end
test('Plugin-derived path type is used for internal and USB paths without an enum',function()
 setup({customPathType='plugin_library_from_object'});assert(#R.drives==3 and R.online)
 assert(Enums.PathType.UserPlugins==nil)
end)
test('Missing GetPathType uses the string folder overload',function()
 setup({missingPathType=true});assert(#R.drives==3 and R.online)
end)
test('Unresolved USB path is reported while remaining drives stay usable',function()
 setup({missingUSB=true});assert(#R.drives==2 and R.online)
 assert(#R.issues==1 and R.issues[1]:find('USB A',1,true) and R.issues[1]:find('drive skipped',1,true))
 assert(R.selectedDrives[drives[3].props.Path] and not R.selectedDrives[drives[2].props.Path])
end)
test('Unresolved internal path stops cleanly before scanning or downloading',function()
 local ok,why=pcall(setup,{missingRoot=true})
 assert(not ok and tostring(why):find('MA plugin library path is unavailable',1,true))
 assert(#trace==0 and #calls==0)
end)
test('Drive scans precede any internet access',function()
 setup();assert(#R.drives==3 and R.drives[3].number==7)
 local scanned={};for _,e in ipairs(trace)do if e:match('^http')then break end
  for _,d in ipairs(drives)do if e:find(d.props.Path,1,true)then scanned[d.n]=true end end
 end
 assert(scanned[1]and scanned[2]and scanned[7]);assert(R.selectedDrives[drives[2].props.Path]);assert(R.online)
end)
test('Download Only writes ZIP and files without importing show objects',function()
 setup();R.mode=2;R.selectedDrives[drives[3].props.Path]=true
 local result=R.run(R.plan({ServerCommand=true}));assert(result:match('^OK'),result);assert(#calls==0)
 for _,d in ipairs({drives[2],drives[3]})do assert(read(d.props.Path..'/plugins/ServerCommand/Server_Command_v2.3.15.xml'));assert(read(d.props.Path..'/plugins/WadeLightingToolsData/downloads/ServerCommand_v2.3.15.zip'))end
end)
test('Newer drive package protected',function()
 setup();localPackage(drives[2],'9.0.0');R.scan(false);R.mode=2;assert(not pcall(R.plan,{ServerCommand=true}))
end)
test('Drive removed after review stops writes and import',function()
 setup();local plan=R.plan({ServerCommand=true});drives[2].alive=false;local result=R.run(plan);assert(result:match('^FAILED'),result);assert(#calls==0)
end)
test('Checksum mismatch stops before drive mutation',function()
 setup({corrupt=true});local result=R.run(R.plan({ServerCommand=true}));assert(result:match('^FAILED'),result);assert(#calls==0);assert(not read(drives[2].props.Path..'/plugins/ServerCommand/Server_Command.lua'))
end)
test('Existing drive folder is preserved before promotion',function()
 setup();local folder=localPackage(drives[2],'2.3.14');write(folder..'/user-note.txt','keep me');R.scan(false);R.mode=2
 assert(R.run(R.plan({ServerCommand=true})):match('^OK'));local backup=drives[2].props.Path..'/plugins/WadeLightingToolsData/backups'
 local preserved=false;for stamp in lfs.dir(backup)do if stamp~='.'and stamp~='..'then preserved=preserved or read(backup..'/'..stamp..'/ServerCommand/user-note.txt')=='keep me'end end;assert(preserved)
end)
test('Mixed per-row actions use item mode and do not rely on global mode',function()
 setup();R.mode=3;local plan=R.plan({ServerCommand=2});assert(plan.items[1].mode==2)
 local result=R.run(plan);assert(result:match('^OK')and#calls==0,result)
end)
test('Old software/remote drives skipped while both connected USBs are scanned',function()
 setup({oldVersions=true});assert(#R.drives==3 and R.scanStats.skipped==2)
 for _,v in ipairs(trace) do assert(not v:find('gma3_2.4.2',1,true) and not v:find('/remote',1,true)) end
end)
test('Duplicate library paths are scanned once',function()
 setup({duplicate=true});assert(#R.drives==3)
 local seen={};for _,v in ipairs(trace) do if v:match('^scan:') then assert(not seen[v],v);seen[v]=true end end
end)
test('New online catalog entries add only previously unseen plugin folders',function()
 setup({fullCatalog=true});local seen={}
 for _,v in ipairs(trace) do if v:match('^scan:') then assert(not seen[v],v);seen[v]=true end end
 assert(#R.catalog==#all and R.scanStats.folders==3*(#all+1))
end)
test('Scan never descends into backups, shows, or unrelated directories',function()
 setup();local base=drives[2].props.Path
 write(base..'/plugins/WadeLightingToolsData/backups/old/plugin.xml','<GMA3/>')
 write(base..'/shared/shows/a.xml','<Show/>');write(base..'/plugins/Other/other.xml','<Other/>')
 trace={};R.scan(false)
 for _,v in ipairs(trace) do assert(not v:find('/backups',1,true) and not v:find('/shared',1,true) and not v:find('/Other',1,true)) end
 assert(R.scanStats.xml==1)
end)
local function progressCheck(complete)
 assert(progress[1].value==0)
 local last=0;local between=0
 for _,x in ipairs(progress)do
  assert(x.value>=last and x.value<=1,'Progress moved backwards/out of range')
  last=x.value;if last>0 and last<1 then between=between+1 end
 end
 assert(between>2,'No intermediate progress')
 assert(complete and last==1 or not complete and last<1,'Incorrect completion progress')
end
test('Download-only progress advances through bytes and both verified drives',function()
 setup();R.selectedDrives[drives[3].props.Path]=true
 assert(R.run(R.plan({ServerCommand=2})):match('^OK'));progressCheck(true)
 local partial=false;for _,x in ipairs(progress)do if x.log==false and x.text:find('Downloading',1,true) and x.value>0 and x.value<.6 then partial=true end end
 assert(partial,'Transfer callback did not advance progress')
end)
test('Both import modes are blocked for every catalog plugin before any writes',function()
 setup({fullCatalog=true});trace={};local before=#progress
 for _,entry in ipairs(R.catalog)do for _,action in ipairs({1,3})do
  local ok,why=pcall(R.plan,{[entry.id]=action})
  assert(not ok and tostring(why):find(R.importNotice,1,true),entry.id..': '..tostring(why))
 end end
 assert(#imports==0 and #calls==0 and #progress==before)
 for _,event in ipairs(trace)do assert(not event:match('^http:'))end
end)
test('A stale or forged mixed plan is rejected before its first download',function()
 setup();local plan=R.plan({ServerCommand=2});plan.items[#plan.items+1]={mode=3,plugin=p};trace={}
 local ok,why=pcall(R.run,plan)
 assert(not ok and tostring(why):find(R.importNotice,1,true))
 assert(#imports==0 and #calls==0 and #progress==0 and #trace==0)
end)
test('Default mode is download-only and preserves existing showfile plugin code',function()
 setup({installed='2.3.14'});assert(R.mode==2)
 local result,handoff=R.run(R.plan({ServerCommand=true}));assert(result:match('^OK'),result)
 assert(not handoff and #imports==0 and #calls==0 and pool.Plugins[13].props.Version=='2.3.14')
end)
test('Updater can be downloaded without queuing self replacement or a timer',function()
 setup({fullCatalog=true,selfInstalled=true})
 local result,handoff=R.run(R.plan({WadePluginUpdater=2}));assert(result:match('^OK'),result)
 assert(not handoff and #imports==0 and #calls==0 and #timers==0)
 assert(pool.Plugins[12].props.Version=='1.1.4')
 local updater;for _,entry in ipairs(R.catalog)do if entry.id=='WadePluginUpdater'then updater=entry end end
 assert(read(drives[2].props.Path..'/plugins/WLT Plugin Updator/WLT Plugin Updator_v'..updater.version..'.xml'))
end)
test('No USB downloads only to the internal current library',function()
 setup({noUSB=true,oldVersions=true});localPackage(drives[1],'2.3.14');R.scan(false);assert(#R.visible(2)>0,'Drives tab must include internal packages without USB');assert(#R.drives==1 and R.drives[1].number==1)
 assert(R.run(R.plan({ServerCommand=2})):match('^OK'))
 assert(read(drives[1].props.Path..'/plugins/ServerCommand/Server_Command_v2.3.15.xml'))
 assert(#imports==0 and #calls==0)
end)
test('Offline scans still show local packages but do not enable an import',function()
 setup({offline=true});localPackage(drives[2],'2.3.15');R.scan(false)
 assert(not R.online and R.localSource(p).version=='2.3.15')
 assert(not pcall(R.plan,{ServerCommand=3}) and not pcall(R.plan,{ServerCommand=2}))
 assert(#imports==0 and #calls==0)
end)
test('Showfile-only plugin cannot qualify for a download',function()
 setup({noPackage=true,installed='2.3.14'});trace={}
 assert(not R.canDownload(p) and not pcall(R.plan,{ServerCommand=2}))
 assert(#trace==0 and #imports==0 and #calls==0)
end)
test('A package on an unselected source drive qualifies for another destination',function()
 setup();assert(not R.selectedDrives[drives[1].props.Path])
 assert(R.canDownload(p,true));assert(R.run(R.plan({ServerCommand=2})):match('^OK'))
end)
test('Removed source or deleted component rejects a reviewed download before network activity',function()
 setup();local plan=R.plan({ServerCommand=2});trace={};drives[1].alive=false
 assert(not pcall(R.run,plan) and #trace==0 and #progress==0)
 drives[1].alive=true;os.remove(drives[1].props.Path..'/plugins/ServerCommand/Server_Command.lua')
 assert(not R.canDownload(p) and not pcall(R.run,plan) and #trace==0)
end)
test('Empty Lua and changed plugin identity cannot authorize an update',function()
 setup();local folder=drives[1].props.Path..'/plugins/ServerCommand'
 write(folder..'/Server_Command.lua','');assert(not pcall(R.plan,{ServerCommand=2}))
 write(folder..'/Server_Command.lua','return function()end')
 write(folder..'/Server_Command_v2.3.14.xml','<GMA3><UserPlugin Name="Something Else" Version="2.3.14" Author="Other" /></GMA3>')
 assert(not R.canDownload(p,true) and not pcall(R.plan,{ServerCommand=2}))
end)
test('Free updater downloads with no existing drive copy',function()
 setup({fullCatalog=true,noPackage=true})
 local updater;for _,entry in ipairs(R.catalog)do if entry.id=='WadePluginUpdater'then updater=entry end end
 assert(R.canDownload(updater,true));assert(R.run(R.plan({WadePluginUpdater=2})):match('^OK'))
 assert(#imports==0 and #calls==0)
end)
print(count..' runtime containment/download scenarios passed (mock MA environment)')
