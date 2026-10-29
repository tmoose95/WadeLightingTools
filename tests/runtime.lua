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
  write(path..'/'..name,'<GMA3><UserPlugin Name="'..self.props.Name..'" Author="Aaron Wade" Version="'..self.props.Version..'" Path="/ServerCommand"><ComponentLua FileName="original.lua" /></UserPlugin></GMA3>')
  if not self.missingBackup then write(path..'/original.lua','return function() end')end;return true
 end
 return o
end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS '..name)end
local catalogText=assert(read('catalog.tsv'))
local all=C.catalog(catalogText);local p;for _,v in ipairs(all)do if v.id=='ServerCommand'then p=v end end
local single='WLT-CATALOG\t1\n'..table.concat({'PLUGIN',p.id,p.name,p.version,p.minimum,p.folder,p.manifest,p.digest},'\t')..'\n'
local root,pool,drives,R,trace,mode,calls
local function setup(options)
 options=options or {};local path=home..'/case'..(count+1);mkdir(path)
 trace={};calls={};mode=options
 local d1=obj({Name='Internal',Path=path..'/internal',DriveType='Harddisk'},1)
 local d2=obj({Name='USB A',Path=path..'/usb-a',DriveType='Removeable'},2)
 local d7=obj({Name='USB B',Path=path..'/usb-b',DriveType='Removable'},7)
 drives={d1,d2,d7};for _,d in ipairs(drives)do mkdir(d.props.Path..'/plugins')end
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
 local function add(slot,ver)
  local h=obj({Name='Server Command',Version=ver or '2.3.14',Author='Aaron Wade',Path='/ServerCommand',Lock='No'},slot)
  pool.Plugins[slot]=h;pool.Plugins.list[#pool.Plugins.list+1]=h;return h
 end
 if options.installed then add(13,options.installed)end
 if options.two then add(26,options.installed)end
 function Cmd(command)
  calls[#calls+1]=command
  if options.importFail then return 'Failed'end
  local file,n,slot,dnum,relative=command:match('Import Plugin Library "([^"]+)" At DataPool (%d+) Plugin (%d+) If Drive (%d+) /Path "([^"]+)"')
  assert(file and tonumber(n)==4,command);slot=tonumber(slot)
  local drive;for _,d in ipairs(drives)do if d.n==tonumber(dnum)then drive=d end end
  local xml=assert(read(drive.props.Path..'/plugins/'..relative..'/'..file));local m=assert(C.xml(xml))
  if options.noReadback then return 'OK'end
  local h=pool.Plugins[slot] or add(slot,m.Version);h.props.Version=m.Version
  return 'Ok'
 end
 local function transport()
  return {get=function(remote)
   trace[#trace+1]='http:'..remote
   if options.offline then error('offline')end
   if remote=='catalog.tsv'then return single end
   local result=assert(read(remote));if options.corrupt and remote:match('%.lua$')then result=result..'x'end
   return result
  end}
 end
 R=Runtime(C,transport,single,function()end,updater)
 R.scan(true)
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
test('Download & Install retains existing slots and qualified DataPool',function()
 setup({installed='2.3.14',two=true});local result=R.run(R.plan({ServerCommand=true}));assert(result:match('^OK'),result)
 assert(#calls==2 and calls[1]:find('At DataPool 4 Plugin 13',1,true)and calls[2]:find('At DataPool 4 Plugin 26',1,true))
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
print(count..' runtime scenarios passed (mock MA environment)')
