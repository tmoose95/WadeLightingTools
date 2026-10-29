return function(Core,Transport,bootstrap,notify,plugin,trustBundle,selfUpdateFactory)
 local R={catalog=Core.catalog(bootstrap),drives={},localFiles={},installed={},selectedDrives={},cancel=false,mode=1,online=false,issues={},allPools=false,localChoice={},showInstalled={}}
 local function safe(fn,other) local ok,v=pcall(fn);if ok then return v end;return other end
 local function prop(h,n)
  if not h then return '' end
  for i=0,(safe(function()return h:PropertyCount()end,0) or 0)-1 do
   local p=safe(function()return h:PropertyName(i)end,'')
   if tostring(p):lower()==n:lower() then return tostring(safe(function()return h:Get(p)end,'') or '') end
  end;return ''
 end
 local function children(h) return safe(function()return h:Children()end,{}) or {} end
 local function index(h) return tonumber(safe(function()return h:CmdlineIndex()end,nil)) end
 local function valid(h) return h and safe(function()return IsObjectValid(h)end,false) end
 local function read(path,max)
  local f=io.open(path,'rb');if not f then return nil end
  local s=f:read((max or 33554432)+1)
  if s==nil and f:seek('end')==0 then s='' end
  f:close()
  if not s or #s>(max or 33554432) then return nil end;return s
 end
 local function write(path,s)
  local f,why=io.open(path,'wb');if not f then return nil,why end
  local ok,err=f:write(s);local closed=f:close();return ok and closed,err
 end
 local function exists(p) return safe(function()return FileExists(p)end,false) end
 local function mkdir(p) return safe(function()return CreateDirectoryRecursive(p)end,false) end
 local function list(p,filter) return safe(function()return DirList(p,filter or '*')end,{}) or {} end
 local function now() return safe(function()return Time()end,os.time()) end
 local function pause(t) if coroutine.isyieldable() then coroutine.yield(t or .001) end end
 local lastYield=0
 local function pulse()
  if R.cancel then error('Cancelled') end
  local t=now();if t-lastYield>=.02 then lastYield=t;pause(.001) end
 end
 local function join(a,b) return a:gsub('[/\\]+$','')..'/'..b end
 local function checked(command)
  local answer=Cmd(command)
  assert(tostring(answer or ''):match('^%s*[Oo][Kk]%s*[:%s]*$'),tostring(answer or 'No command feedback'))
 end
 local serial=0
 local function unique() serial=serial+1;return os.date('%Y%m%d_%H%M%S')..'_'..serial end
 -- Ask the running Plugin object for its user-library path type. Some MA3
 -- versions do not define PathType.UserPlugins; never pass that nil to the API.
 local pathType=valid(plugin) and safe(function()return GetPathType(plugin,1)end,nil) or nil
 if type(pathType)~='string' or pathType=='' then pathType='plugins' end
 local function pluginRoot(base)
  local value=safe(function()
   if base then return GetPathOverrideFor(pathType,base,false) end
   return GetPath(pathType,false)
  end,nil)
  if type(value)=='string' and value~='' then return value end
 end
 local root=pluginRoot()
 assert(root,'MA plugin library path is unavailable. No files were changed.')
 local work=join(root,'WadeLightingToolsData/work')
 local transport=Transport(Core,{work=work,windows=tostring(HostOS()):lower():find('windows',1,true)~=nil,
  mkdir=mkdir,write=write,read=read,exists=exists,now=now,pause=pause,cancelled=function()return R.cancel end},trustBundle)
 R.prop,R.index,R.valid,R.children,R.pause=prop,index,valid,children,pause
 local progress
 local function advance(fraction,text)
  if not progress then return end
  local value=((progress.item-1)+progress.start+progress.span*math.min(1,math.max(0,fraction)))/progress.count
  progress.value=math.max(progress.value,math.min(.999,value))
  if text then progress.text=text end
  notify(progress.text,math.floor(progress.value*1000),1000,false)
 end
 local function phase(start,finish,text)
  progress.start,progress.span=start,finish-start;advance(0,text)
 end
 local function report(text,current,total)
  if progress then progress.text=text;current,total=math.floor(progress.value*1000),1000 end
  Printf('WLT Plugin Updator | %s',text);notify(text,current,total,true)
 end
 local function issue(text) R.issues[#R.issues+1]=text;report(text) end
 local function driveValid(d)
  return valid(d.handle) and index(d.handle)==d.number and prop(d.handle,'Path')==d.path
 end
 local function assertDrive(d) assert(driveValid(d),'Drive removed or changed: '..d.label) end
 local function pluginMeta(p) return {Name=prop(p,'Name'),Version=prop(p,'Version'),Author=prop(p,'Author'),Path=prop(p,'Path')} end
 function R.pools()
  local a={};for _,p in pairs(children(Root().ShowData.DataPools)) do if valid(p) and index(p) then a[#a+1]=p end end
  table.sort(a,function(x,y)return index(x)<index(y)end);return a
 end
 function R.targetPools() return R.allPools and R.pools() or {R.pool} end
 function R.refreshInstalled()
  R.installed={};R.showInstalled={}
  assert(valid(R.pool),'Destination DataPool is no longer available')
  for _,pool in ipairs(R.pools()) do
   for _,h in pairs(children(pool.Plugins)) do
    local m=pluginMeta(h)
    for _,p in ipairs(R.catalog) do
     if Core.matches(m,p) then
      local x={handle=h,slot=index(h),version=m.Version,name=m.Name,pool=pool,poolNumber=index(pool),poolName=prop(pool,'Name')}
      local a=R.showInstalled[p.id] or {};R.showInstalled[p.id]=a;a[#a+1]=x
      if R.allPools or pool==R.pool then
       a=R.installed[p.id] or {};R.installed[p.id]=a;a[#a+1]=x
      end
     end
    end
   end
  end
 end
 local folderCache={}
 local function addLocal(record,d,p)
  local path,m=record.path,record.meta
  if not Core.matches(m,p) then return end
  local folder=path:match('^(.*)[/\\][^/\\]+$')
  local complete=true
  for _,f in ipairs(m.components) do if not exists(join(folder,f)) then complete=false end end
  if not complete then issue(d.label..': '..m.Name..' '..m.Version..' has missing Lua files');return end
  -- Discovery needs metadata only. Hash a local source when it is selected
  -- for review, never every embedded image/XML on every connected drive.
  local entry={drive=d,path=path,folder=folder,xml=path:match('[^/\\]+$'),version=m.Version,meta=m}
  local a=R.localFiles[p.id] or {};R.localFiles[p.id]=a;a[#a+1]=entry
 end
 local function scanFolders()
  R.localFiles={}
  local folders={''};local names={}
  for _,p in ipairs(R.catalog) do if not names[p.folder] then names[p.folder]=true;folders[#folders+1]=p.folder end end
  local done,total=0,#R.drives*#folders
  for _,d in ipairs(R.drives) do
   if driveValid(d) then
    for _,name in ipairs(folders) do
     local folder=name=='' and d.root or join(d.root,name)
     local records=folderCache[folder]
     if not records then
      records={};folderCache[folder]=records;R.scanStats.folders=R.scanStats.folders+1
      report('Reading plugin folders: '..d.label..(name=='' and ' / XML exports' or ' / '..name),done,total)
      for _,file in pairs(list(folder,'*.xml')) do
       local n=type(file)=='table' and file.name or nil
       if n and Core.path(n) and not n:find('/') and n:lower():match('%.xml$') then
        local path=join(folder,n);local meta=Core.xml(read(path,16777216))
        R.scanStats.xml=R.scanStats.xml+1
        if meta then records[#records+1]={path=path,meta=meta} end
        pulse()
       end
      end
     end
     for _,record in ipairs(records) do
      for _,p in ipairs(R.catalog) do if Core.matches(record.meta,p) then addLocal(record,d,p);break end end
     end
     done=done+1
     pulse()
    end
   end
  end
  for _,a in pairs(R.localFiles) do table.sort(a,function(x,y)return (Core.compare(x.version,y.version) or 0)>0 end) end
 end
 function R.scan(connect)
  R.cancel=false;R.issues={};R.drives={};R.localChoice={}
  folderCache={};R.scanStats={folders=0,xml=0,skipped=0}
  local old=R.selectedDrives;R.selectedDrives={}
  local seen={}
  local collection=safe(function()return Root().Temp.DriveCollect end,nil)
  for _,h in pairs(children(collection)) do
   local n,path=index(h),prop(h,'Path');local kind=prop(h,'DriveType'):lower()
   local external=kind=='removeable' or kind=='removable'
   -- DriveCollect includes virtual drives for older software and remote
   -- stations. Only the current internal library and attached USBs qualify.
   if n and (n==1 or external) and kind~='oldversion' and path~='' and valid(h) then
    local r=n==1 and root or pluginRoot(path)
    if type(r)=='string' and r~='' and not seen[r] then
     seen[r]=true
     local d={handle=h,number=n,path=path,root=r,label='Drive '..n..' - '..prop(h,'Name'),external=external}
     R.drives[#R.drives+1]=d
     if old[path] then R.selectedDrives[path]=true end
    elseif not r or r=='' then
     issue('Drive '..n..' - '..prop(h,'Name')..': plugin library path is unavailable; drive skipped')
    end
   else R.scanStats.skipped=R.scanStats.skipped+1 end
  end
  table.sort(R.drives,function(a,b)return a.number<b.number end)
  if next(R.selectedDrives)==nil then
   for _,d in ipairs(R.drives) do if d.external then R.selectedDrives[d.path]=true;break end end
   if next(R.selectedDrives)==nil and R.drives[1] then R.selectedDrives[R.drives[1].path]=true end
  end
  -- This scan completes before an online request or the main UI is constructed.
  scanFolders()
  if connect then
   report('Checking WadeLightingTools online catalog')
   local ok,new=pcall(function()
    assert(mkdir(work),'Cannot create updater workspace')
    return Core.catalog(transport.get('catalog.tsv',262144))
   end)
   if ok then
    R.catalog=new;R.online=true;R.connectionError=nil;R.client=transport.client
    -- Reclassify cached metadata; only newly published plugin folders incur IO.
    scanFolders()
   else
    if R.cancel then error('Cancelled') end
    R.online=false;R.connectionError=tostring(new);R.client=transport.client
    issue('Online catalog unavailable. Local packages remain available. '..R.connectionError)
   end
  end
  R.refreshInstalled();report(#R.drives..' plugin libraries / '..R.scanStats.xml..' XML files | '..(R.online and 'Online catalog loaded' or 'Local catalog'),1,1)
 end
 function R.localBest(p,selectedOnly)
  for _,e in ipairs(R.localFiles[p.id] or {}) do
   if (not selectedOnly or R.selectedDrives[e.drive.path]) and driveValid(e.drive) then return e end
  end
 end
 function R.localSource(p)
  local choice=R.localChoice[p.id]
  if choice and R.selectedDrives[choice.drive.path] and driveValid(choice.drive) then
   for _,e in ipairs(R.localFiles[p.id] or {}) do if e==choice then return choice end end
  end
  return R.localBest(p,true)
 end
 function R.installedText(p,all)
  local a=(all and R.showInstalled or R.installed)[p.id] or {};if #a==0 then return 'Not installed' end
  local t={};for _,x in ipairs(a) do t[#t+1]=(x.version~='' and x.version or '?')..' ('..x.poolName..')' end
  return table.concat(t,'\n')
 end
 -- Only a successfully fetched catalog can determine whether a version is current.
 function R.versionStateFor(p,version)
  if not R.online then return 'unknown' end
  local c=Core.compare(version,p.version)
  if c==nil then return 'unknown' end
  return c==0 and 'current' or (c<0 and 'outdated' or 'newer')
 end
 function R.installedState(p)
  local a=R.showInstalled[p.id] or {};if #a==0 or not R.online then return 'unknown' end
  local state='current'
  for _,x in ipairs(a) do
   local v=R.versionStateFor(p,x.version)
   if v=='outdated' or v=='newer' then return v end
   if v=='unknown' then state='unknown' end
  end
  return state
 end
 function R.visible(tab)
  local a={}
  for _,p in ipairs(R.catalog) do
   local installed=#(R.showInstalled[p.id] or {})>0
   local usb=false;for _,e in ipairs(R.localFiles[p.id] or {}) do if e.drive.external then usb=true;break end end
   if (tab==1 and installed) or (tab==2 and usb) or (tab==3 and not installed) then a[#a+1]=p end
  end
  return a
 end
 function R.status(p)
  local v=R.mode==3 and (R.localSource(p) or {}).version or (R.online and p.version or nil)
  if not v then return R.mode==3 and 'No selected-drive copy' or 'Online catalog unavailable' end
  local a=R.installed[p.id] or {};if #a==0 then return 'New install' end
  local newer,older,unknown=false,false,false
  for _,x in ipairs(a) do local c=Core.compare(v,x.version);newer=newer or c==1;older=older or c==-1;unknown=unknown or c==nil end
  if unknown then return 'Unknown installed version' end
  if older then return 'Installed version is newer' end
  return newer and 'Update available' or 'Up to date'
 end
 function R.drivesSelected()
  local out={};for _,d in ipairs(R.drives) do if R.selectedDrives[d.path] then out[#out+1]=d end end;return out
 end
 function R.plan(selected)
  assert(valid(R.pool),'Destination DataPool is unavailable')
  local poolNumber=index(R.pool);assert(poolNumber and poolNumber>0,'Invalid DataPool number')
  local plan={pool=R.pool,poolNumber=poolNumber,mode=R.mode,drives=R.drivesSelected(),items={},lines={}}
  assert(#plan.drives>0,'Select at least one drive')
  for _,d in ipairs(plan.drives) do assertDrive(d) end
  R.refreshInstalled()
  local occupied={}
  for _,pool in ipairs(R.targetPools()) do
   local n=index(pool);assert(n and n>0,'Invalid DataPool number')
   occupied[n]={};for _,h in pairs(children(pool.Plugins)) do local slot=index(h);if slot then occupied[n][slot]=true end end
  end
  for _,p in ipairs(R.catalog) do if selected[p.id] and selected[p.id]~=0 then
   local mode=type(selected[p.id])=='number' and selected[p.id] or R.mode
   assert(mode==1 or mode==2 or mode==3,'Unknown row action')
   local source=mode==3 and R.localSource(p) or nil
   assert(mode==3 or R.online,'Online catalog is unavailable. Choose Import from Drive for a local copy.')
   assert(mode~=3 or source,'No complete local package on a selected drive: '..p.name)
   if source then
    local data=assert(read(source.path,16777216),'Local XML no longer exists; rescan')
    local meta=Core.xml(data)
    assert(Core.matches(meta,p) and meta.Version==source.version,'Local package changed; rescan')
    -- Freeze the reviewed source, independent of the live table entry.
    local snapshot={};for k,v in pairs(source) do snapshot[k]=v end
    source=snapshot;source.digest=Core.sha256(data,pulse)
   end
   local v=source and source.version or p.version
   if mode~=3 then
    for _,e in ipairs(R.localFiles[p.id] or {}) do
     if R.selectedDrives[e.drive.path] then
      assert((Core.compare(v,e.version) or -1)>=0,'A selected drive has a newer version of '..p.name..'; it was not replaced')
     end
    end
   end
   local installed=R.installed[p.id] or {}
   if mode~=2 then
    if p.id=='WadePluginUpdater' then
     assert(type(selfUpdateFactory)=='function' and type(CmdIndirect)=='function' and type(Timer)=='function',
      'This station cannot start the updater handoff')
    end
    local runtime=tostring(Version()):match('(%d+%.%d+%.%d+%.?%d*)')
    assert(runtime and (Core.compare(runtime,p.minimum) or -1)>=0,'This release requires MA3 '..p.minimum)
    for _,x in ipairs(installed) do
     local c=Core.compare(v,x.version);assert(c and c>=0,'Refusing to replace a newer or unknown version of '..p.name)
     assert(prop(x.handle,'Lock'):lower()~='yes','Plugin is locked: '..p.name)
    end
   end
   local slots={}
   if mode~=2 then
    for _,pool in ipairs(R.targetPools()) do
     assert(prop(pool,'Lock'):lower()~='yes','DataPool is locked: '..prop(pool,'Name'))
     local n=index(pool);local found=false
     for _,x in ipairs(installed) do if x.pool==pool then
      assert(x.slot,'Invalid plugin slot');slots[#slots+1]=x;found=true
     end end
     if not found then
      local slot=1;while occupied[n][slot] do slot=slot+1 end;assert(slot<=9999,'No free plugin slot')
      occupied[n][slot]=true;slots[#slots+1]={slot=slot,pool=pool,poolNumber=n,poolName=prop(pool,'Name')}
     end
    end
   end
   plan.items[#plan.items+1]={plugin=p,source=source,version=v,slots=slots,mode=mode}
   local target={};for _,x in ipairs(slots) do target[#target+1]='DataPool '..x.poolNumber..' / Plugin '..x.slot end
   local action=mode==1 and 'Update Drives + Showfile' or (mode==2 and 'Download to Drives' or 'Import from Drive')
   plan.lines[#plan.lines+1]=p.name..' '..v..' - '..action..(mode~=2 and (' -> '..table.concat(target,', ')) or '')
   if p.id=='WadePluginUpdater' and mode~=2 then
    plan.lines[#plan.lines+1]='The updater will finish last and close its window while its showfile slots are updated automatically.'
   end
  end end
  -- Finish other reviewed actions before handing off the running updater.
  for i,item in ipairs(plan.items)do if item.plugin.id=='WadePluginUpdater' and item.mode~=2 then
   table.remove(plan.items,i);plan.items[#plan.items+1]=item;break
  end end
  assert(#plan.items>0,'Choose an action for one or more plugins');return plan
 end
 local function validateLocal(e,p)
  assertDrive(e.drive)
  local data=assert(read(e.path,16777216),'Local XML no longer exists')
  assert(Core.sha256(data,pulse)==e.digest,'Local XML changed after review; rescan')
  local m=Core.xml(data);assert(Core.matches(m,p) and m.Version==e.version,'Local package identity changed')
  for _,f in ipairs(m.components) do assert(exists(join(e.folder,f)),'Missing Lua component: '..f) end
 end
 local function release(p)
  report('Reading release manifest: '..p.name);pulse()
  local bytes=transport.get(p.manifest,262144);local m=Core.manifest(bytes,p)
  local data={};local total=m.zip.bytes;local received=0
  for _,f in ipairs(m.files) do total=total+f.bytes end
  advance(.02)
  local function transfer(f)
   local s=transport.get(f.remote,f.bytes,function(n)
    advance(.02+.96*(received+math.min(n,f.bytes)*.99)/total)
   end)
   report('Verifying '..p.name..' / '..f.path)
   assert(Core.verify(s,f,pulse),'File checksum mismatch: '..f.path)
   received=received+f.bytes;advance(.02+.96*received/total)
   return s
  end
  for _,f in ipairs(m.files) do
   report('Downloading '..p.name..' / '..f.path);pulse()
   data[f.path]=transfer(f)
  end
  report('Downloading '..p.name..' ZIP')
  local zip=transfer(m.zip)
  local meta=Core.xml(data[m.xml]);assert(Core.matches(meta,p) and meta.Version==p.version,'XML release identity mismatch')
  assert((meta.Path or ''):gsub('^/','')==p.folder,'XML folder does not match release folder')
  for _,f in ipairs(meta.components) do assert(data[f],'Release is missing a Lua component: '..f) end
  advance(1)
  return m,data,zip
 end
 local function savePackage(d,p,m,data,zip,step)
  assertDrive(d)
  local staging=join(d.root,'WadeLightingToolsData/staging/'..unique()..'/'..p.folder)
  assert(mkdir(staging),'Drive is not writable: '..d.label)
  for i,f in ipairs(m.files) do
   report('Writing '..d.label..' / '..p.name..' / '..f.path);pulse()
   local path=join(staging,f.path);local parent=path:match('^(.*)/[^/]+$');assert(mkdir(parent))
   assert(write(path,data[f.path]),'Write failed: '..f.path)
   assert(Core.verify(read(path,f.bytes),f,pulse),'Written-file verification failed: '..f.path)
   step(i/(#m.files+2))
  end
  local zipdir=join(d.root,'WadeLightingToolsData/downloads');assert(mkdir(zipdir))
  local zipname=join(zipdir,m.zip.path);local part=zipname..'.'..unique()..'.part'
  assert(write(part,zip),'ZIP write failed');assert(Core.verify(read(part,m.zip.bytes),m.zip,pulse),'ZIP readback failed')
  -- Existing version-named ZIP is retained unless it has the expected digest.
  if exists(zipname) then
   assert(Core.verify(read(zipname,m.zip.bytes),m.zip,pulse),'Existing ZIP has different contents: '..zipname);os.remove(part)
  else assert(os.rename(part,zipname),'Could not finish ZIP download') end
  step((#m.files+1)/(#m.files+2))
  assertDrive(d);pulse()
  local dest=join(d.root,p.folder)
  local present=exists(join(dest,m.xml)) or next(list(dest,'*'))~=nil
  local backup
  if present then
   backup=join(d.root,'WadeLightingToolsData/backups/'..unique()..'/'..p.folder)
   assert(mkdir(backup:match('^(.*)/[^/]+$')))
   assert(os.rename(dest,backup),'Could not preserve existing drive package; it was not replaced')
  end
  local ok,why=os.rename(staging,dest)
  if not ok then
   if backup then
    local restored=os.rename(backup,dest)
    if not restored then error('Package promotion failed; restore the preserved folder from '..backup) end
   end
   error('Could not finish package installation: '..tostring(why))
  end
  local xml=join(dest,m.xml)
  step(1);report('Drive package verified: '..d.label..' / '..p.name)
  return {drive=d,path=xml,folder=dest,xml=m.xml,version=p.version,meta=Core.xml(data[m.xml]),digest=Core.sha256(data[m.xml])}
 end
 local function backupSlot(item,slot)
  if not slot.handle then return end
  assert(valid(slot.handle) and prop(slot.handle,'Version')==slot.version,'Installed plugin changed after review')
  local path=join(root,'WadeLightingToolsData/backups/show_'..unique()..'/Plugin_'..slot.slot)
  assert(mkdir(path),'Cannot create plugin backup')
  local filename='Plugin_'..slot.slot..'.xml'
  assert(slot.handle:Export(path,filename),'Native plugin backup failed')
  local meta=Core.xml(read(join(path,filename),16777216));assert(meta,'Exported backup could not be verified')
  for _,f in ipairs(meta.components) do
   assert(exists(join(path,f)) or exists(join(join(path,(meta.Path or ''):gsub('^/','')),f)),
    'Backup is missing an external Lua component; original plugin was not replaced. '..path)
  end
  -- Embedded-only exports are valid backups too; verify their actual Lua.
  local backupXML=read(join(path,filename),16777216)
  local empty={}
  -- Preserve zero-byte files exactly. Older failed imports can leave an empty
  -- component; that existing damage must not make a verified repair impossible.
  Core.luaContents(backupXML,function(f)
   local s=read(join(path,f)) or read(join(join(path,(meta.Path or ''):gsub('^/','')),f))
   if s=='' then empty[#empty+1]=f;return '-- Empty component preserved in backup' end
   return s
  end)
  if #empty>0 then
   slot.incomplete=table.concat(empty,', ')
   assert(write(join(path,'INCOMPLETE-BACKUP.txt'),'Existing exported Lua was empty: '..slot.incomplete..'\nThis is a snapshot of the damaged slot, not a runnable recovery copy.\n'))
   report('Existing empty Lua component: '..slot.incomplete..' (snapshot preserved)')
  end
  report('Show plugin backup: '..path)
  slot.backup=path
 end
 local function install(item,source,plan,previousResults)
  validateLocal(source,item.plugin)
  local original=assert(read(source.path,16777216),'Import XML no longer exists')
  local embedded,expectedCodes=Core.embeddedPlugin(original,function(f)return read(join(source.folder,f))end,pulse)
  local importFolder=join(work,'import_'..unique())
  assert(mkdir(importFolder),'Cannot create self-contained import workspace')
  local importName='Plugin.xml'
  assert(write(join(importFolder,importName),embedded),'Could not write self-contained import XML')
  assert(read(join(importFolder,importName),16777216)==embedded,'Import XML readback differs')
  assert(valid(plan.pool) and index(plan.pool)==plan.poolNumber,'Destination DataPool changed')
  advance(.1,'Preparing verified import: '..item.plugin.name)
  local repairs={}
  for _,slot in ipairs(item.slots) do
   assert(valid(slot.pool) and index(slot.pool)==slot.poolNumber,'Destination DataPool changed')
   local current=slot.pool.Plugins[slot.slot]
   if slot.handle then assert(current==slot.handle,'Plugin slot changed after review')
   else assert(not valid(current),'New plugin slot is now occupied') end
   if not slot.backup then backupSlot(item,slot) end
   if slot.incomplete then repairs[#repairs+1]='DataPool '..slot.poolNumber..' / Plugin '..slot.slot..': '..slot.incomplete..'\nSnapshot: '..slot.backup end
  end
  if #repairs>0 then
   local choice=MessageBox({title='Repair empty plugin component',message=item.plugin.name..' has an empty Lua component in the existing showfile export. Its damaged state has been saved, but that snapshot cannot restore working code.\n\n'..table.concat(repairs,'\n\n')..'\n\nThe replacement package has been read and its Lua compiled. Repair these slots from version '..item.version..'?',commands={{value=1,name='Repair from verified package'},{value=0,name='Cancel'}}})
   assert(choice and choice.success and choice.result==1,'Repair cancelled; existing show slots were not changed')
  end
  if item.plugin.id=='WadePluginUpdater' then
   local job={folder=importFolder,xml=importName,digest=Core.sha256(embedded,pulse),version=item.version,
    plugin=item.plugin,slots={},previous=table.concat(previousResults or {},'\n'),start=progress.value}
   for _,slot in ipairs(item.slots) do
    job.slots[#job.slots+1]={pool=slot.poolNumber,poolHandle=HandleToStr(slot.pool),slot=slot.slot,
     handle=slot.handle and HandleToStr(slot.handle) or nil,meta=slot.handle and pluginMeta(slot.handle) or nil,backup=slot.backup}
   end
   local path=join(importFolder,'FinishUpdate.lua')
   assert(not path:find('["\r\n]'),'Unsupported characters in updater workspace path')
   local script=selfUpdateFactory(job)
   assert(load(script,'@FinishUpdate.lua','t',{}),'Updater handoff does not compile')
   assert(write(path,script) and read(path,16777216)==script,'Updater handoff write/readback failed')
   report('Drive files ready. Finishing updater showfile update...')
   return {command='LuaFile "'..path..'"',path=path}
  end
  for slotIndex,slot in ipairs(item.slots) do
   local function step(n) advance(.1+.9*((slotIndex-1)+n)/#item.slots) end
   pulse();assertDrive(source.drive)
   local target=slot.pool.Plugins[slot.slot]
   if not slot.handle then
    checked('Store DataPool '..slot.poolNumber..' Plugin '..slot.slot..' /NoConfirmation')
    target=slot.pool.Plugins[slot.slot]
   end
   local where='DataPool '..slot.poolNumber..' / Plugin '..slot.slot
   local recovery=' Backup: '..tostring(slot.backup or 'new slot')
   assert(valid(target),'Could not create import target at '..where..recovery)
   report('Importing '..item.plugin.name..' into '..where)
   -- The object API can resolve external FileName against lib_plugins instead
   -- of this USB/library folder. Import verified embedded FileContent instead.
   assert(target:Import(importFolder,importName),
    'Native object import failed at '..where..' from '..join(importFolder,importName)..recovery)
   step(.45)
   local untilTime=now()+3;local found
   repeat
    pause(.05);found=slot.pool.Plugins[slot.slot]
    if valid(found) and Core.compare(prop(found,'Version'),item.version)==0 then break end
   until now()>=untilTime
   local actual=pluginMeta(found)
   assert(valid(found) and Core.matches(actual,item.plugin) and Core.compare(actual.Version,item.version)==0,
    'Imported metadata differs at '..where..': expected '..item.plugin.name..' '..item.version..
    '; found '..actual.Name..' '..actual.Version..' / Author '..actual.Author..' / Path '..actual.Path..recovery)
   -- A version alone cannot prove that the Lua component was replaced.
   local check=join(work,'verify_'..unique())
   report('Checking imported Lua: '..item.plugin.name..' / '..where);step(.6)
   assert(mkdir(check),'Cannot create import verification folder'..recovery)
   assert(found:Export(check,'Plugin.xml'),'Cannot verify imported Lua at '..where..recovery)
   local exportedXML=read(join(check,'Plugin.xml'),16777216)
   local exported=assert(Core.xml(exportedXML),'Imported export could not be read'..recovery)
   local actualCodes=Core.luaContents(exportedXML,function(f)
    return read(join(check,f)) or read(join(join(check,(exported.Path or ''):gsub('^/','')),f))
   end)
   assert(#actualCodes==#expectedCodes,'Imported Lua component count differs at '..where..recovery)
   local function normal(s) return s and s:gsub('\r\n','\n'):gsub('\n+$','') end
   for i,expected in ipairs(expectedCodes) do
    assert(normal(actualCodes[i])==normal(expected),
     'Imported Lua did not match component '..i..' at '..where..recovery)
   end
   report('Installed '..item.plugin.name..' '..item.version..' at Plugin '..slot.slot)
   step(1)
  end
 end
 local function remember(p,entry)
  local a={}
  for _,e in ipairs(R.localFiles[p.id] or {}) do
   if e.folder~=entry.folder then a[#a+1]=e end
  end
  a[#a+1]=entry;table.sort(a,function(x,y)return (Core.compare(x.version,y.version) or 0)>0 end)
  R.localFiles[p.id]=a;R.localChoice[p.id]=nil
 end
 function R.run(plan)
  R.cancel=false;local results={};local completed=0;local handoff
  progress={item=1,count=#plan.items,start=0,span=0,value=0,text='Starting update'}
  report('Starting update',0,1000)
  for itemIndex,item in ipairs(plan.items) do
   if R.cancel then break end
   progress.item=itemIndex
   local ok,why=pcall(function()
    local source=item.source
    local downloadEnd=item.mode==2 and .65 or .55
    local saveEnd=item.mode==2 and 1 or .8
    -- Preserve the original show code before replacing any library source folder.
    if item.mode~=2 then
     phase(0,item.mode==3 and .2 or .1,'Backing up '..item.plugin.name)
     for i,slot in ipairs(item.slots) do pulse();backupSlot(item,slot);advance(i/#item.slots) end
    end
    if item.mode~=3 then
     phase(item.mode==2 and 0 or .1,downloadEnd,'Downloading '..item.plugin.name)
     local m,data,zip=release(item.plugin);local sources={}
     phase(downloadEnd,saveEnd,'Saving '..item.plugin.name)
     for i,d in ipairs(plan.drives) do
      pulse();local entry=savePackage(d,item.plugin,m,data,zip,function(n)advance(((i-1)+n)/#plan.drives)end)
      sources[#sources+1]=entry;remember(item.plugin,entry)
     end
     source=sources[1]
    end
    if item.mode~=2 then phase(item.mode==3 and .2 or .8,1,'Preparing import: '..item.plugin.name);handoff=install(item,source,plan,results) end
   end)
   results[#results+1]=(ok and (handoff and 'READY: ' or 'OK: ') or 'FAILED: ')..item.plugin.name..(ok and '' or (' - '..tostring(why)))
   if not ok then issue(results[#results]);break end -- Stop batch after first partial/failure.
   completed=completed+1
  end
  R.refreshInstalled()
  if completed==#plan.items and not R.cancel and not handoff then
   progress.value=1;report('Update complete - all selected actions verified')
  elseif R.cancel then handoff=nil;report('Update cancelled') end
  progress=nil
  return table.concat(results,'\n'),handoff
 end
 R.pool=DataPool()
 R.scanFolders=scanFolders
 return R
end
