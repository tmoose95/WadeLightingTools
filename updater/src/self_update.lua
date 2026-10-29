-- A local, independent LuaFile continuation. No network requests or pool helper.
-- The old updater UI closes before this is queued through CmdIndirect.
local M={}
local function literal(value)
 local kind=type(value)
 if kind=='string' then return string.format('%q',value) end
 if kind=='number' or kind=='boolean' then return tostring(value) end
 if kind=='nil' then return 'nil' end
 assert(kind=='table','Unsupported handoff value')
 local out={'{'}
 for k,v in pairs(value) do out[#out+1]='['..literal(k)..']='..literal(v)..',' end
 out[#out+1]='}';return table.concat(out)
end
function M.script(job,coreSource,workerSource)
 assert(type(coreSource)=='string' and type(workerSource)=='string')
 return 'local Core=(function()\n'..coreSource..'\nend)()\nlocal Worker=(function()\n'..workerSource..'\nend)()\nWorker.run(Core,'..literal(job)..')\n'
end
function M.run(Core,job)
 local function read(path)
  local f=io.open(path,'rb');if not f then return nil end
  local s=f:read('*a');f:close();return s
 end
 local function write(path,s)
  local f=assert(io.open(path,'wb'));assert(f:write(s));assert(f:close())
 end
 local function valid(h)return h and IsObjectValid(h)end
 local function prop(h,name)
  for i=0,h:PropertyCount()-1 do local key=h:PropertyName(i)
   if tostring(key):lower()==name:lower()then return tostring(h:Get(key) or '')end
  end;return ''
 end
 local function resolve(slot)
  local pool=StrToHandle(slot.poolHandle)
  assert(valid(pool) and pool:CmdlineIndex()==slot.pool,'Destination DataPool changed')
  local inShow=false;for _,p in pairs(Root().ShowData.DataPools:Children())do if p==pool then inShow=true end end
  assert(inShow,'Destination DataPool is no longer in this show')
  assert(prop(pool,'Lock'):lower()~='yes','Destination DataPool is locked')
  local target=pool.Plugins[slot.slot]
  if slot.handle then
   assert(valid(target) and HandleToStr(target)==slot.handle,'Updater slot changed after review')
   for name,value in pairs(slot.meta)do assert(prop(target,name)==value,'Updater '..name..' changed after review')end
   assert(prop(target,'Lock'):lower()~='yes','Updater slot is locked')
  else assert(not valid(target),'New updater slot is now occupied')end
  return pool,target
 end
 local progress,finished,started
 local lines={};if job.previous~=''then lines[#lines+1]=job.previous end
 local function finish(ok,why)
  if finished then return end;finished=true
  if not ok then lines[#lines+1]='FAILED: WLT Plugin Updator - '..tostring(why)end
  if progress then if ok then SetProgress(progress,1000)end;StopProgress(progress)end
  local result=table.concat(lines,'\n')
  if started then pcall(write,job.folder..'/Result.txt',result)end
  Printf('WLT Plugin Updator | %s',result)
  MessageBox({title=ok and 'Update complete' or 'Update stopped',message=result..(ok and '\n\nReopen WLT Plugin Updator to use the updated version.' or ''),commands={{value=1,name='Close'}}})
 end
 local lastYield=Time()
 local function pulse()
  if Time()-lastYield>.1 then lastYield=Time();coroutine.yield()end
 end
 local function report(text,fraction)
  Printf('WLT Plugin Updator | %s',text);SetProgressText(progress,text)
  SetProgress(progress,math.floor(1000*math.min(.999,job.start+(1-job.start)*fraction)))
 end
 local co=coroutine.create(function()
  assert(not read(job.folder..'/Started.txt'),'This updater handoff has already run')
  write(job.folder..'/Started.txt','Started');started=true
  progress=StartProgress('WLT Plugin Updator | Finishing showfile update')
  SetProgressRange(progress,0,1000);SetProgress(progress,math.floor(job.start*1000))
  local xml=assert(read(job.folder..'/'..job.xml),'Prepared updater XML is missing')
  assert(Core.sha256(xml,pulse)==job.digest,'Prepared updater XML changed')
  local meta=Core.xml(xml)
  assert(Core.matches(meta,job.plugin) and Core.compare(meta.Version,job.version)==0,'Prepared updater identity differs')
  local expected=Core.luaContents(xml,function()error('Prepared updater contains external Lua')end)
  for _,code in ipairs(expected)do assert(load(code:gsub('^\239\187\191',''),'@updater replacement','t',{}),'Replacement Lua does not compile')end
  for _,slot in ipairs(job.slots)do resolve(slot)end
  for i,slot in ipairs(job.slots)do
   local where='DataPool '..slot.pool..' / Plugin '..slot.slot
   local recovery=' Backup: '..tostring(slot.backup or 'new slot')
   report('Importing updater into '..where,(i-1)/#job.slots);coroutine.yield()
   local pool,target=resolve(slot)
   if not slot.handle then
    local result=Cmd('Store DataPool '..slot.pool..' Plugin '..slot.slot..' /NoConfirmation')
    assert(tostring(result):lower():match('^%s*ok%s*[:%s]*$'),'Could not create updater target: '..tostring(result))
    target=pool.Plugins[slot.slot]
   end
   assert(valid(target) and target:Import(job.folder,job.xml),'Updater import failed at '..where..recovery)
   local untilTime=Time()+3;local found
   repeat
    coroutine.yield();found=pool.Plugins[slot.slot]
    if valid(found) and Core.compare(prop(found,'Version'),job.version)==0 then break end
   until Time()>=untilTime
   local actual=valid(found) and {Name=prop(found,'Name'),Version=prop(found,'Version'),Author=prop(found,'Author'),Path=prop(found,'Path')} or {}
   assert(Core.matches(actual,job.plugin) and Core.compare(actual.Version,job.version)==0,'Updater metadata verification failed at '..where..recovery)
   report('Verifying updater Lua at '..where,(i-.5)/#job.slots)
   local check=job.folder..'/verify_'..i;assert(CreateDirectoryRecursive(check),'Cannot create verification folder')
   assert(found:Export(check,'Plugin.xml'),'Cannot export updated updater for verification'..recovery)
   local exported=assert(read(check..'/Plugin.xml'));local em=assert(Core.xml(exported))
   local codes=Core.luaContents(exported,function(f)return read(check..'/'..f)or read(check..'/'..(em.Path or ''):gsub('^/','')..'/'..f)end)
   assert(#codes==#expected,'Updated updater component count differs'..recovery)
   local function normal(s)return s:gsub('\r\n','\n'):gsub('\n+$','')end
   for n,code in ipairs(codes)do assert(normal(code)==normal(expected[n]),'Updated updater Lua differs at '..where..recovery)end
   lines[#lines+1]='OK: WLT Plugin Updator '..job.version..' at '..where
   report('Verified updater at '..where,i/#job.slots)
  end
 end)
 local function tick()
  local ok,why=coroutine.resume(co)
  if not ok then finish(false,why)
  elseif coroutine.status(co)=='dead' then finish(true)
  else
   -- The timer is created from LuaFile, independently of the plugin component
   -- being replaced. One-shot scheduling stops when this coroutine completes.
   local scheduled,err=pcall(Timer,tick,1,1)
   if not scheduled then finish(false,err)end
  end
 end
 tick()
end
return M
