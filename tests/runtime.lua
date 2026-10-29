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
test('Internet failure leaves local installation available',function()
 setup({offline=true});localPackage(drives[2],'2.3.15');R.scan(false);assert(not R.online);R.mode=3
 local plan=R.plan({ServerCommand=true});assert(plan.items[1].source.version=='2.3.15');local result=R.run(plan);assert(result:match('^OK'),result)
end)
test('Download Only writes ZIP and files without importing show objects',function()
 setup();R.mode=2;R.selectedDrives[drives[3].props.Path]=true
 local result=R.run(R.plan({ServerCommand=true}));assert(result:match('^OK'),result);assert(#calls==0)
 for _,d in ipairs({drives[2],drives[3]})do assert(read(d.props.Path..'/plugins/ServerCommand/Server_Command_v2.3.15.xml'));assert(read(d.props.Path..'/plugins/WadeLightingToolsData/downloads/ServerCommand_v2.3.15.zip'))end
end)
test('Online import embeds Lua and uses exact existing DataPool handles',function()
 setup({installed='2.3.14',two=true});local result=R.run(R.plan({ServerCommand=true}));assert(result:match('^OK'),result)
 assert(#calls==0 and #imports==2 and imports[1].pool==pool and imports[1].slot==13 and imports[2].slot==26)
 assert(imports[1].folder:find(drives[1].props.Path..'/plugins/WadeLightingToolsData/work/import_',1,true)==1)
 assert(imports[1].filename=='Plugin.xml' and not pool.Plugins[13].resourceMissing)
 assert(pool.Plugins[13].imported.codes[1]==read('packages/ServerCommand/2.3.15/ServerCommand/Server_Command.lua'))
 assert(pool.Plugins[13].props.Version=='2.3.15' and pool.Plugins[26].props.Version=='2.3.15')
end)
test('New plugins choose only an empty slot',function()
 local add=setup();add(1,'2.3.15').props.Author='Other';add(2,'2.3.15').props.Author='Other';R.refreshInstalled()
 local plan=R.plan({ServerCommand=true});assert(plan.items[1].slots[1].slot==3)
end)
test('Numeric downgrades and unknown installed versions rejected',function()
 setup({installed='2.3.16'});assert(not pcall(R.plan,{ServerCommand=true}));pool.Plugins[13].props.Version='modified';assert(not pcall(R.plan,{ServerCommand=true}))
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
test('Backup failure blocks replacement',function()
 setup({installed='2.3.14'});pool.Plugins[13].failBackup=true;local result=R.run(R.plan({ServerCommand=true}));assert(result:match('^FAILED'),result);assert(#calls==0)
end)
test('Missing backup Lua blocks replacement',function()
 setup({installed='2.3.14'});pool.Plugins[13].missingBackup=true;local result=R.run(R.plan({ServerCommand=true}));assert(result:match('^FAILED'),result);assert(#calls==0)
end)
test('Native import failure is reported',function()
 setup({importFail=true});local result=R.run(R.plan({ServerCommand=true}));assert(result:match('^FAILED'),result)
end)
test('False-positive native OK rejected by version readback',function()
 setup({noReadback=true});local result=R.run(R.plan({ServerCommand=true}));assert(result:match('^FAILED'),result)
end)
test('Local XML changed after review rejected',function()
 setup({offline=true});local folder=localPackage(drives[2],'2.3.15');R.scan(false);R.mode=3;local plan=R.plan({ServerCommand=true})
 write(folder..'/Server_Command_v2.3.15.xml','broken');assert(R.run(plan):match('^FAILED'));assert(#calls==0)
end)
test('Occupied destination after review rejected',function()
 local add=setup();localPackage(drives[2],'2.3.15');R.scan(false);R.mode=3;local plan=R.plan({ServerCommand=true});add(1,'9.0.0')
 assert(R.run(plan):match('^FAILED'));assert(#calls==0)
end)
test('Older MA software rejected before installation',function()
 setup({oldRuntime=true});assert(not pcall(R.plan,{ServerCommand=true}))
end)
test('Incomplete local XML/Lua package is not offered',function()
 setup({offline=true});local folder=localPackage(drives[2],'2.3.15');os.remove(folder..'/Server_Command.lua');R.scan(false);assert(not R.localBest(p,true))
end)
test('Install Only picks newest selected-drive version',function()
 setup();localPackage(drives[2],'2.3.14');localPackage(drives[3],'2.3.15');R.selectedDrives[drives[3].props.Path]=true;R.scan(false);R.mode=3
 assert(R.plan({ServerCommand=true}).items[1].source.drive.number==7)
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
test('All DataPools plans preserve each existing slot and import into each pool',function()
 local add=setup({installed='2.3.14'})
 local second=obj({Name='Main'},1);second.Plugins=obj();root.ShowData.DataPools.list[#root.ShowData.DataPools.list+1]=second
 add(7,'2.3.14',second);R.allPools=true;R.refreshInstalled()
 assert(#R.showInstalled.ServerCommand==2 and R.installedText(p,true):find('Main',1,true))
 local plan=R.plan({ServerCommand=1});assert(#plan.items[1].slots==2)
 local result=R.run(plan);assert(result:match('^OK'),result);assert(#imports==2 and #calls==0)
 assert(imports[1].pool.n==1 and imports[1].slot==7);assert(imports[2].pool.n==4 and imports[2].slot==13)
end)
test('All DataPools allocates a free slot where the plugin is missing',function()
 setup({installed='2.3.14'});local second=obj({Name='Empty'},2);second.Plugins=obj();root.ShowData.DataPools.list[#root.ShowData.DataPools.list+1]=second
 R.allPools=true;local plan=R.plan({ServerCommand=1});assert(plan.items[1].slots[1].poolNumber==2 and plan.items[1].slots[1].slot==1)
end)
test('Choosing one DataPool leaves other pools visible but out of plan',function()
 local add=setup({installed='2.3.14'});local second=obj({Name='Other'},2);second.Plugins=obj();root.ShowData.DataPools.list[#root.ShowData.DataPools.list+1]=second
 add(8,'2.3.14',second);R.refreshInstalled();assert(#R.showInstalled.ServerCommand==2 and#R.installed.ServerCommand==1)
 local plan=R.plan({ServerCommand=1});assert(#plan.items[1].slots==1 and plan.items[1].slots[1].poolNumber==4)
end)
test('Version states handle equal, outdated, newer, unknown and unavailable',function()
 setup({installed='2.3.14'});assert(R.versionStateFor(p,p.version)=='current')
 assert(R.versionStateFor(p,'1.0.0')=='outdated');assert(R.versionStateFor(p,'99.0.0')=='newer');assert(R.versionStateFor(p,'?')=='unknown')
 assert(R.installedState(p)=='outdated');R.online=false;assert(R.installedState(p)=='unknown'and R.versionStateFor(p,p.version)=='unknown')
end)
test('Drive source selection chooses the requested complete copy',function()
 setup();localPackage(drives[2],'2.3.14');localPackage(drives[3],'2.3.15');R.selectedDrives[drives[3].props.Path]=true;R.scan(false)
 assert(R.localSource(p).version=='2.3.15')
 for _,e in ipairs(R.localFiles[p.id])do if e.version=='2.3.14'then R.localChoice[p.id]=e end end
 assert(R.plan({ServerCommand=3}).items[1].source.version=='2.3.14')
end)
test('Three views distinguish showfile, USB packages and uninstalled catalog',function()
 setup({installed='2.3.14'});assert(#R.visible(1)==1 and#R.visible(2)==0 and#R.visible(3)==0)
 localPackage(drives[2],'2.3.15');R.scan(false);assert(#R.visible(2)==1)
end)
test('No USB uses only internal library and selects it for downloads/imports',function()
 setup({noUSB=true,oldVersions=true})
 assert(#R.drives==1 and R.drives[1].number==1 and R.selectedDrives[drives[1].props.Path])
 for _,v in ipairs(trace) do assert(not v:find('gma3_2.4.2',1,true) and not v:find('/remote',1,true)) end
 local result=R.run(R.plan({ServerCommand=1}));assert(result:match('^OK'),result)
 assert(#imports==1 and imports[1].folder:find(drives[1].props.Path..'/plugins/WadeLightingToolsData/work/import_',1,true)==1)
end)
test('Old software/remote drives skipped while both connected USBs are scanned',function()
 setup({oldVersions=true});assert(#R.drives==3 and R.scanStats.skipped==2)
 for _,v in ipairs(trace) do assert(not v:find('gma3_2.4.2',1,true) and not v:find('/remote',1,true)) end
end)
test('Duplicate library paths are scanned once',function()
 setup({duplicate=true});assert(#R.drives==3)
 local seen={};for _,v in ipairs(trace) do if v:match('^scan:') then assert(not seen[v],v);seen[v]=true end end
end)
test('Online catalog reuses folder metadata and reads each XML only once',function()
 setup();localPackage(drives[2],'2.3.15')
 write(drives[2].props.Path..'/plugins/unrelated.xml','<Macro />')
 local hashes,parses=0,0;local hash,xml=C.sha256,C.xml
 C.sha256=function(...)hashes=hashes+1;return hash(...)end
 C.xml=function(...)parses=parses+1;return xml(...)end
 trace={};R.scan(true);C.sha256,C.xml=hash,xml
 local seen={};for _,v in ipairs(trace) do if v:match('^scan:') then assert(not seen[v],v);seen[v]=true end end
 assert(R.scanStats.folders==6 and R.scanStats.xml==2 and parses==2 and hashes==0)
 assert(#R.localFiles.ServerCommand==1 and R.localFiles.ServerCommand[1].digest==nil)
 local plan=R.plan({ServerCommand=3});assert(#plan.items[1].source.digest==64)
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
 assert(R.scanStats.xml==0)
end)
test('Finished updates refresh only memory/showfile, with no second drive scan',function()
 setup({installed='2.3.14'});local plan=R.plan({ServerCommand=1});trace={}
 assert(R.run(plan):match('^OK'));assert(R.installed.ServerCommand[1].version=='2.3.15')
 assert(R.localSource(p).version=='2.3.15')
 for _,v in ipairs(trace) do if v:match('^scan:') then assert(v=='scan:'..drives[2].props.Path..'/plugins/ServerCommand',v) end end
end)
test('A new slot is stored before its exact object handle receives Import',function()
 setup();local result=R.run(R.plan({ServerCommand=1}));assert(result:match('^OK'),result)
 assert(#calls==1 and calls[1]=='Store DataPool 4 Plugin 1 /NoConfirmation')
 assert(#imports==1 and imports[1].handle==pool.Plugins[1])
end)
test('A successful import/version with stale Lua code is rejected',function()
 setup({installed='2.3.14',staleCode=true});local result=R.run(R.plan({ServerCommand=1}))
 assert(result:match('^FAILED') and result:find('Imported Lua did not match',1,true),result)
end)
test('Actual MA Search package updates slot 19 using direct import and Lua readback',function()
 local add=setup({fullCatalog=true});local h=add(19,'0.3.8')
 h.props.Name='MA Search';h.props.Path='/MASearch'
 local result=R.run(R.plan({MASearch=1}));assert(result:match('^OK'),result)
 assert(#calls==0 and #imports==1 and imports[1].handle==h and imports[1].slot==19)
 assert(imports[1].filename=='Plugin.xml' and h.props.Version=='0.3.9')
 assert(h.imported.codes[1]==read('packages/MASearch/0.3.9/MASearch/MASearch.lua'))
end)
test('Drive import replaces two existing pool slots with embedded code offline',function()
 setup({offline=true,installed='2.3.14',two=true})
 local folder=localPackage(drives[2],'2.3.15');R.scan(false)
 local before=read(folder..'/Server_Command_v2.3.15.xml')
 local result=R.run(R.plan({ServerCommand=3}));assert(result:match('^OK'),result)
 assert(#imports==2 and #calls==0)
 for _,slot in ipairs({13,26}) do
  local h=pool.Plugins[slot];assert(h.props.Version=='2.3.15' and not h.resourceMissing)
  assert(h.imported.codes[1]=='return function()end')
  assert(h.imported.xml:find('FileName=""',1,true) and h.imported.xml:find('Installed="No"',1,true))
 end
 assert(read(folder..'/Server_Command_v2.3.15.xml')==before,'Source XML must not change')
end)
test('Equivalent three/four-part imported versions pass code verification',function()
 setup({installed='2.3.14',normalizedVersion=true})
 local result=R.run(R.plan({ServerCommand=1}));assert(result:match('^OK'),result)
 assert(pool.Plugins[13].props.Version=='2.3.15.0')
end)
test('Unchanged native metadata reports actual and expected values plus backup',function()
 setup({installed='2.3.14',noReadback=true})
 local result=R.run(R.plan({ServerCommand=1}))
 assert(result:match('^FAILED') and result:find('expected Server Command 2.3.15',1,true),result)
 assert(result:find('found Server Command 2.3.14',1,true) and result:find('Backup:',1,true),result)
end)
test('Invalid drive Lua stops before any pool object receives Import',function()
 setup({offline=true,installed='2.3.14'});local folder=localPackage(drives[2],'2.3.15');R.scan(false)
 write(folder..'/Server_Command.lua','return function( broken')
 local result=R.run(R.plan({ServerCommand=3}))
 assert(result:match('^FAILED') and result:find('Lua component does not compile',1,true),result)
 assert(#imports==0 and pool.Plugins[13].props.Version=='2.3.14')
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
test('Online import progress waits for imported code verification',function()
 setup({installed='2.3.14',two=true});assert(R.run(R.plan({ServerCommand=1})):match('^OK'));progressCheck(true)
 assert(progress[#progress].text=='Update complete - all selected actions verified')
end)
test('Offline drive import has progressive backup/preparation/per-slot verification',function()
 setup({offline=true,installed='2.3.14',two=true});localPackage(drives[2],'2.3.15');R.scan(false);progress={}
 assert(R.run(R.plan({ServerCommand=3})):match('^OK'));progressCheck(true)
end)
test('Failure and cancellation never announce 100 percent',function()
 setup({staleCode=true,installed='2.3.14'});assert(R.run(R.plan({ServerCommand=1})):match('^FAILED'));progressCheck(false)
 setup({cancelDownload=true});assert(R.run(R.plan({ServerCommand=2})):match('^FAILED'));progressCheck(false);assert(#imports==0)
end)
test('Zero-byte existing Lua can be repaired only after preserving it and confirming',function()
 setup({installed='2.3.14',repair=true});pool.Plugins[13].emptyBackup=true
 local plan=R.plan({ServerCommand=1});local result=R.run(plan);assert(result:match('^OK'),result)
 local backup=plan.items[1].slots[1].backup
 assert(read(backup..'/original.lua')=='');assert(read(backup..'/INCOMPLETE-BACKUP.txt'))
 assert(#repairs==1 and repairs[1].message:find('cannot restore working code',1,true))
 assert(#imports==1 and pool.Plugins[13].imported.codes[1]==read('packages/ServerCommand/2.3.15/ServerCommand/Server_Command.lua'))
end)
test('Declining empty-component repair preserves the existing slot and snapshot',function()
 setup({installed='2.3.14'});pool.Plugins[13].emptyBackup=true
 local plan=R.plan({ServerCommand=1});local result=R.run(plan)
 assert(result:match('^FAILED') and result:find('Repair cancelled',1,true),result)
 assert(#imports==0 and pool.Plugins[13].props.Version=='2.3.14')
 assert(read(plan.items[1].slots[1].backup..'/original.lua')=='');progressCheck(false)
end)
test('Invalid replacement never prompts repair or changes an empty slot',function()
 setup({offline=true,installed='2.3.14',repair=true});pool.Plugins[13].emptyBackup=true
 local folder=localPackage(drives[2],'2.3.15');R.scan(false);write(folder..'/Server_Command.lua','broken Lua (')
 assert(R.run(R.plan({ServerCommand=3})):match('^FAILED'));assert(#repairs==0 and #imports==0)
end)
local function executeHandoff(handoff)
 assert(handoff and handoff.command=='LuaFile "'..handoff.path..'"')
 assert(load(read(handoff.path),'@FinishUpdate.lua','t',_G))()
 local limit=10000
 while #timers>0 do limit=limit-1;assert(limit>0,'Worker did not finish');table.remove(timers,1)()end
 return read(handoff.path:gsub('FinishUpdate.lua$','Result.txt')) or ''
end
local function prepareSelf(options)
 options=options or {};options.fullCatalog=true;options.selfInstalled=true;setup(options)
 return R.plan({WadePluginUpdater=1})
end
test('Self update writes drives then queues independent worker without inline Import',function()
 local plan=prepareSelf();local result,handoff=R.run(plan)
 assert(result:match('^READY') and handoff,result);assert(#imports==0)
 assert(read(drives[2].props.Path..'/plugins/WLT Plugin Updator/WLT Plugin Updator.lua'))
 assert(read(plan.items[1].slots[1].backup..'/original.lua'));progressCheck(false)
 local out=executeHandoff(handoff);assert(out:match('^OK'),out)
 assert(#imports==1 and imports[1].slot==12 and pool.Plugins[12].props.Version=='1.1.5')
 assert(workerProgress.stopped and workerProgress[#workerProgress]==1000)
end)
test('Self download-only action never imports or creates a worker',function()
 prepareSelf();local result,handoff=R.run(R.plan({WadePluginUpdater=2}))
 assert(result:match('^OK') and not handoff and #imports==0);progressCheck(true)
end)
test('Self import from drive works offline with no network after review',function()
 prepareSelf();assert(R.run(R.plan({WadePluginUpdater=2})):match('^OK'))
 R.online=false;R.mode=3;trace={};local result,handoff=R.run(R.plan({WadePluginUpdater=3}))
 assert(result:match('^READY'),result);assert(executeHandoff(handoff):match('^OK'))
 for _,entry in ipairs(trace)do assert(not entry:match('^http:'))end
end)
test('Self continuation runs last after other plugins and retains earlier results',function()
 prepareSelf({installed='2.3.14'});local plan=R.plan({WadePluginUpdater=1,ServerCommand=1})
 assert(plan.items[#plan.items].plugin.id=='WadePluginUpdater')
 local result,handoff=R.run(plan);assert(#imports==1 and imports[1].slot==13,result)
 local out=executeHandoff(handoff);assert(out:find('OK: Server Command',1,true) and out:find('OK: WLT Plugin Updator',1,true),out)
end)
test('Self continuation supports multiple DataPools and an empty target',function()
 prepareSelf();local second=obj({Name='Empty'},2);second.Plugins=obj();root.ShowData.DataPools.list[#root.ShowData.DataPools.list+1]=second
 R.allPools=true;local result,handoff=R.run(R.plan({WadePluginUpdater=1}))
 assert(result:match('^READY'),result);local out=executeHandoff(handoff);assert(not out:find('FAILED',1,true),out)
 assert(#imports==2 and second.Plugins[1].props.Name=='WLT Plugin Updator' and pool.Plugins[12].props.Version=='1.1.5')
end)
test('Changed prepared self XML is rejected before pool import',function()
 local _,handoff=R.run(prepareSelf());local xml=handoff.path:gsub('FinishUpdate.lua$','Plugin.xml');write(xml,read(xml)..' ')
 local out=executeHandoff(handoff);assert(out:find('Prepared updater XML changed',1,true),out);assert(#imports==0 and workerProgress[#workerProgress]<1000)
end)
test('Changed target metadata after self review blocks replacement',function()
 local _,handoff=R.run(prepareSelf());pool.Plugins[12].props.Name='User changed name'
 local out=executeHandoff(handoff);assert(out:find('changed after review',1,true),out);assert(#imports==0)
end)
test('Lock set after self review blocks replacement',function()
 local _,handoff=R.run(prepareSelf());pool.Plugins[12].props.Lock='Yes'
 local out=executeHandoff(handoff);assert(out:find('Updater slot is locked',1,true),out);assert(#imports==0)
end)
test('Stale self Lua readback fails and never announces 100 percent',function()
 local _,handoff=R.run(prepareSelf({staleCode=true}));local out=executeHandoff(handoff)
 assert(out:find('Updated updater Lua differs',1,true),out);assert(workerProgress.stopped and workerProgress[#workerProgress]<1000)
end)
test('Self worker is one-shot and cannot accidentally reapply',function()
 local _,handoff=R.run(prepareSelf());assert(executeHandoff(handoff):match('^OK'))
 local before=#imports;executeHandoff(handoff);assert(#imports==before)
 assert(repairs[#repairs].message:find('already run',1,true))
end)
test('Self timer scheduling failure closes progress and leaves showfile untouched',function()
 local _,handoff=R.run(prepareSelf({timerFail=true}));local out=executeHandoff(handoff)
 assert(out:find('Timer unavailable',1,true),out);assert(#imports==0 and workerProgress.stopped and workerProgress[#workerProgress]<1000)
end)
print(count..' runtime scenarios passed (mock MA environment)')
