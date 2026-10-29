return function(Core,Transport,bootstrap,notify)
 local R={catalog=Core.catalog(bootstrap),drives={},localFiles={},installed={},selectedDrives={},cancel=false,mode=1,online=false,issues={}}
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
  local s=f:read((max or 33554432)+1);f:close()
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
 local function pulse() if R.cancel then error('Cancelled') end;pause(.001) end
 local function join(a,b) return a:gsub('[/\\]+$','')..'/'..b end
 local function q(s) assert(not s:find('["\r\n]'),'Unsupported quote in path');return '"'..s..'"' end
 local function checked(command)
  local answer=Cmd(command)
  assert(tostring(answer or ''):match('^%s*[Oo][Kk]%s*[:%s]*$'),tostring(answer or 'No command feedback'))
 end
 local serial=0
 local function unique() serial=serial+1;return os.date('%Y%m%d_%H%M%S')..'_'..serial end
 local root=GetPath(Enums.PathType.UserPlugins)
 assert(type(root)=='string' and #root>0,'MA plugin folder is unavailable')
 local work=join(root,'WadeLightingToolsData/work')
 local transport=Transport(Core,{work=work,windows=tostring(HostOS()):lower():find('windows',1,true)~=nil,
  mkdir=mkdir,write=write,read=read,exists=exists,now=now,pause=pause,cancelled=function()return R.cancel end})
 R.prop,R.index,R.valid,R.children,R.pause=prop,index,valid,children,pause
 local function report(text) notify(text);Printf('WLT Plugin Updator | %s',text) end
 local function issue(text) R.issues[#R.issues+1]=text;report(text) end
 local function driveValid(d)
  return valid(d.handle) and index(d.handle)==d.number and prop(d.handle,'Path')==d.path
 end
 local function assertDrive(d) assert(driveValid(d),'Drive removed or changed: '..d.label) end
 local function pluginMeta(p) return {Name=prop(p,'Name'),Version=prop(p,'Version'),Author=prop(p,'Author'),Path=prop(p,'Path')} end
 function R.refreshInstalled()
  R.installed={}
  assert(valid(R.pool),'Destination DataPool is no longer available')
  for _,h in pairs(children(R.pool.Plugins)) do
   local m=pluginMeta(h)
   for _,p in ipairs(R.catalog) do
    if Core.matches(m,p) then
     local a=R.installed[p.id] or {};R.installed[p.id]=a
     a[#a+1]={handle=h,slot=index(h),version=m.Version,name=m.Name}
    end
   end
  end
 end
 local function addLocal(path,d,p)
  local data=read(path,16777216);local m=Core.xml(data)
  if not Core.matches(m,p) then return end
  local folder=path:match('^(.*)[/\\][^/\\]+$')
  local complete=true
  for _,f in ipairs(m.components) do if not exists(join(folder,f)) then complete=false end end
  if not complete then issue(d.label..': '..m.Name..' '..m.Version..' has missing Lua files');return end
  local entry={drive=d,path=path,folder=folder,xml=path:match('[^/\\]+$'),version=m.Version,meta=m,digest=Core.sha256(data,pulse)}
  local a=R.localFiles[p.id] or {};R.localFiles[p.id]=a;a[#a+1]=entry
 end
 local function scanFolders()
  R.localFiles={}
  for _,d in ipairs(R.drives) do
   if driveValid(d) then
    report('Scanning '..d.label)
    for _,p in ipairs(R.catalog) do
     for _,folder in ipairs({join(d.root,p.folder),d.root}) do
      for _,file in pairs(list(folder,'*.xml')) do
       local n=type(file)=='table' and file.name or nil
       if n and Core.path(n) and not n:find('/') and n:lower():match('%.xml$') then addLocal(join(folder,n),d,p) end
      end
     end
     pulse()
    end
   end
  end
  for _,a in pairs(R.localFiles) do table.sort(a,function(x,y)return (Core.compare(x.version,y.version) or 0)>0 end) end
 end
 function R.scan(connect)
  R.cancel=false;R.issues={};R.drives={}
  local old=R.selectedDrives;R.selectedDrives={}
  local collection=safe(function()return Root().Temp.DriveCollect end,nil)
  for _,h in pairs(children(collection)) do
   local n,path=index(h),prop(h,'Path');local kind=prop(h,'DriveType'):lower()
   if n and n>0 and n%1==0 and path~='' and valid(h) then
    local r=n==1 and root or safe(function()return GetPathOverrideFor(Enums.PathType.UserPlugins,path,false)end,nil)
    if type(r)=='string' and r~='' then
     local d={handle=h,number=n,path=path,root=r,label='Drive '..n..' - '..prop(h,'Name'),external=kind=='removeable' or kind=='removable'}
     R.drives[#R.drives+1]=d
     if old[path] then R.selectedDrives[path]=true end
    end
   end
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
    R.catalog=new;R.online=true;scanFolders()
   else R.online=false;issue('Internet catalog unavailable. Drive installs remain available. '..tostring(new)) end
  end
  R.refreshInstalled();report(#R.drives..' drive(s) scanned | '..(R.online and 'Online catalog loaded' or 'Local catalog'))
 end
 function R.localBest(p,selectedOnly)
  for _,e in ipairs(R.localFiles[p.id] or {}) do
   if (not selectedOnly or R.selectedDrives[e.drive.path]) and driveValid(e.drive) then return e end
  end
 end
 function R.installedText(p)
  local a=R.installed[p.id] or {};if #a==0 then return 'Not installed' end
  local versions={};for _,x in ipairs(a) do versions[x.version~='' and x.version or '?']=true end
  local t={};for v in pairs(versions) do t[#t+1]=v end;table.sort(t)
  return table.concat(t,', ')..(#a>1 and (' ('..#a..')') or '')
 end
 function R.status(p)
  local v=R.mode==3 and (R.localBest(p,true) or {}).version or (R.online and p.version or nil)
  if not v then return R.mode==3 and 'No selected-drive copy' or 'Internet unavailable' end
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
  local occupied={};for _,h in pairs(children(R.pool.Plugins)) do local n=index(h);if n then occupied[n]=true end end
  for _,p in ipairs(R.catalog) do if selected[p.id] then
   local source=R.mode==3 and R.localBest(p,true) or nil
   assert(R.mode==3 or R.online,'Online catalog is unavailable. Choose Install Only for a drive copy.')
   assert(R.mode~=3 or source,'No complete local package on a selected drive: '..p.name)
   local v=source and source.version or p.version
   if R.mode~=3 then
    for _,e in ipairs(R.localFiles[p.id] or {}) do
     if R.selectedDrives[e.drive.path] then
      assert((Core.compare(v,e.version) or -1)>=0,'A selected drive has a newer version of '..p.name..'; it was not replaced')
     end
    end
   end
   local installed=R.installed[p.id] or {}
   if R.mode~=2 then
    assert(p.id~='WadePluginUpdater','Download the updater, then import it manually after closing this window')
    local runtime=tostring(Version()):match('(%d+%.%d+%.%d+%.?%d*)')
    assert(runtime and (Core.compare(runtime,p.minimum) or -1)>=0,'This release requires MA3 '..p.minimum)
    for _,x in ipairs(installed) do
     local c=Core.compare(v,x.version);assert(c and c>=0,'Refusing to replace a newer or unknown version of '..p.name)
     assert(prop(x.handle,'Lock'):lower()~='yes','Plugin is locked: '..p.name)
    end
   end
   local slots={};for _,x in ipairs(installed) do assert(x.slot,'Invalid plugin slot');slots[#slots+1]=x end
   if #slots==0 and R.mode~=2 then
    local n=1;while occupied[n] do n=n+1 end;assert(n<=9999,'No free plugin slot');occupied[n]=true;slots={{slot=n}}
   end
   plan.items[#plan.items+1]={plugin=p,source=source,version=v,slots=slots}
   local target={};for _,x in ipairs(slots) do target[#target+1]=tostring(x.slot) end
   plan.lines[#plan.lines+1]=p.name..' '..v..(R.mode~=2 and (' -> DataPool '..poolNumber..' / Plugin '..table.concat(target,', ')) or ' -> selected drive(s)')
  end end
  assert(#plan.items>0,'Select one or more plugins');return plan
 end
 local function validateLocal(e,p)
  assertDrive(e.drive)
  local data=assert(read(e.path,16777216),'Local XML no longer exists')
  assert(Core.sha256(data,pulse)==e.digest,'Local XML changed after review; rescan')
  local m=Core.xml(data);assert(Core.matches(m,p) and m.Version==e.version,'Local package identity changed')
  for _,f in ipairs(m.components) do assert(exists(join(e.folder,f)),'Missing Lua component: '..f) end
 end
 local function release(p)
  local bytes=transport.get(p.manifest,262144);local m=Core.manifest(bytes,p)
  local data={}
  for _,f in ipairs(m.files) do
   report('Downloading '..p.name..' / '..f.path);pulse()
   local s=transport.get(f.remote,f.bytes);assert(Core.verify(s,f,pulse),'File checksum mismatch: '..f.path)
   data[f.path]=s
  end
  report('Downloading '..p.name..' ZIP')
  local zip=transport.get(m.zip.remote,m.zip.bytes);assert(Core.verify(zip,m.zip,pulse),'ZIP checksum mismatch')
  local meta=Core.xml(data[m.xml]);assert(Core.matches(meta,p) and meta.Version==p.version,'XML release identity mismatch')
  assert((meta.Path or ''):gsub('^/','')==p.folder,'XML folder does not match release folder')
  for _,f in ipairs(meta.components) do assert(data[f],'Release is missing a Lua component: '..f) end
  return m,data,zip
 end
 local function savePackage(d,p,m,data,zip)
  assertDrive(d)
  local staging=join(d.root,'WadeLightingToolsData/staging/'..unique()..'/'..p.folder)
  assert(mkdir(staging),'Drive is not writable: '..d.label)
  for _,f in ipairs(m.files) do
   local path=join(staging,f.path);local parent=path:match('^(.*)/[^/]+$');assert(mkdir(parent))
   assert(write(path,data[f.path]),'Write failed: '..f.path)
   assert(Core.verify(read(path,f.bytes),f,pulse),'Written-file verification failed: '..f.path)
  end
  local zipdir=join(d.root,'WadeLightingToolsData/downloads');assert(mkdir(zipdir))
  local zipname=join(zipdir,m.zip.path);local part=zipname..'.'..unique()..'.part'
  assert(write(part,zip),'ZIP write failed');assert(Core.verify(read(part,m.zip.bytes),m.zip,pulse),'ZIP readback failed')
  -- Existing version-named ZIP is retained unless it has the expected digest.
  if exists(zipname) then
   assert(Core.verify(read(zipname,m.zip.bytes),m.zip,pulse),'Existing ZIP has different contents: '..zipname);os.remove(part)
  else assert(os.rename(part,zipname),'Could not finish ZIP download') end
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
  report('Show plugin backup: '..path)
  slot.backup=path
 end
 local function install(item,source,plan)
  validateLocal(source,item.plugin)
  assert(valid(plan.pool) and index(plan.pool)==plan.poolNumber,'Destination DataPool changed')
  for _,slot in ipairs(item.slots) do
   local current=plan.pool.Plugins[slot.slot]
   if slot.handle then assert(current==slot.handle,'Plugin slot changed after review')
   else assert(not valid(current),'New plugin slot is now occupied') end
   if not slot.backup then backupSlot(item,slot) end
  end
  for _,slot in ipairs(item.slots) do
   pulse();assertDrive(source.drive)
   local relative=source.folder:sub(#source.drive.root+1):gsub('^[/\\]','')
   assert(source.folder:sub(1,#source.drive.root)==source.drive.root,'Import path is outside the plugin library')
   checked('Import Plugin Library '..q(source.xml)..' At DataPool '..plan.poolNumber..' Plugin '..slot.slot
    ..' If Drive '..source.drive.number..' /Path '..q(relative=='' and '.' or relative)..' /NoConfirmation')
   local untilTime=now()+3;local found
   repeat
    pause(.05);found=plan.pool.Plugins[slot.slot]
    if valid(found) and prop(found,'Version')==item.version then break end
   until now()>=untilTime
   assert(valid(found) and Core.matches(pluginMeta(found),item.plugin) and prop(found,'Version')==item.version,
    'Import was not verified at Plugin '..slot.slot..'. Backup: '..tostring(slot.backup or 'new slot'))
   report('Installed '..item.plugin.name..' '..item.version..' at Plugin '..slot.slot)
  end
 end
 function R.run(plan)
  R.cancel=false;local results={}
  for _,item in ipairs(plan.items) do
   if R.cancel then break end
   local ok,why=pcall(function()
    local source=item.source
    -- Preserve the original show code before replacing any library source folder.
    if plan.mode~=2 then for _,slot in ipairs(item.slots) do backupSlot(item,slot) end end
    if plan.mode~=3 then
     local m,data,zip=release(item.plugin);local sources={}
     for _,d in ipairs(plan.drives) do pulse();sources[#sources+1]=savePackage(d,item.plugin,m,data,zip) end
     source=sources[1]
    end
    if plan.mode~=2 then install(item,source,plan) end
   end)
   results[#results+1]=(ok and 'OK: ' or 'FAILED: ')..item.plugin.name..(ok and '' or (' - '..tostring(why)))
   if not ok then issue(results[#results]);break end -- Stop batch after first partial/failure.
  end
  return table.concat(results,'\n')
 end
 R.pool=DataPool()
 R.scanFolders=scanFolders
 return R
end
