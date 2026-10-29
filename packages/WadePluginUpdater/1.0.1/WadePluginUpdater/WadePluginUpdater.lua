-- Plugin Updator v1.0.1 | Aaron Wade - Crossfade Design | grandMA3 2.5.1
local _,_,signalTable,myHandle=...
local function safe(fn,fallback) local ok,v=pcall(fn);if ok then return v end;return fallback end
local function button(parent,column,row,name,text,clicked,color)
 local b=parent:Append('Button');b.Name=name;b.Text=text;b.Anchors={left=column,right=column,top=row,bottom=row}
 b.Margin={left=3,right=3,top=3,bottom=3};b.Font='Regular16';b.TextalignmentH='Centre'
 b.PluginComponent=myHandle;b.Clicked=clicked;b.HasHover='Yes';if color then b.BackColor=color end;return b
end

local Core=(function()
-- WadeLightingTools updater core. No MA API, filesystem writes or network effects.
local M = {}
local MASK = 0xffffffff
local function ror(x,n) return ((x >> n) | (x << (32-n))) & MASK end
local K={
 0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
 0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
 0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
 0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
 0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
 0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
 0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
 0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2}
function M.sha256(s, pulse)
 local h={0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19}
 local len=#s
 s=s..string.char(128)..string.rep('\0',(55-len)%64)..string.pack('>I8',len*8)
 for pos=1,#s,64 do
  local w={}
  for i=1,16 do w[i]=string.unpack('>I4',s,pos+(i-1)*4) end
  for i=17,64 do
   local x,y=w[i-15],w[i-2]
   w[i]=(w[i-16]+(ror(x,7)~ror(x,18)~(x>>3))+w[i-7]+(ror(y,17)~ror(y,19)~(y>>10)))&MASK
  end
  local a,b,c,d,e,f,g,z=table.unpack(h)
  for i=1,64 do
   local t1=(z+(ror(e,6)~ror(e,11)~ror(e,25))+((e&f)~((~e)&g))+K[i]+w[i])&MASK
   local t2=((ror(a,2)~ror(a,13)~ror(a,22))+((a&b)~(a&c)~(b&c)))&MASK
   z,g,f,e,d,c,b,a=g,f,e,(d+t1)&MASK,c,b,a,(t1+t2)&MASK
  end
  local v={a,b,c,d,e,f,g,z}
  for i=1,8 do h[i]=(h[i]+v[i])&MASK end
  if pulse and (pos-1)%65536==0 then pulse() end
 end
 for i=1,8 do h[i]=string.format('%08x',h[i]) end
 return table.concat(h)
end
function M.version(s)
 if type(s)~='string' or #s>32 or not (s:match('^%d+%.%d+%.%d+$') or s:match('^%d+%.%d+%.%d+%.%d+$')) then return nil end
 local v={};for n in s:gmatch('%d+') do v[#v+1]=tonumber(n) end
 if #v<3 or #v>4 then return nil end
 return v
end
function M.compare(a,b)
 local av,bv=M.version(a),M.version(b)
 if not av or not bv then return nil end
 for i=1,4 do
  local x,y=av[i] or 0,bv[i] or 0
  if x<y then return -1 elseif x>y then return 1 end
 end
 return 0
end
function M.key(s) return tostring(s or ''):lower():gsub('[^a-z0-9]','') end
function M.path(s)
 if type(s)~='string' or #s==0 or #s>240 or s:find('[^%w_./%-]') or s:sub(1,1)=='/' or s:find('//',1,true) then return false end
 for part in s:gmatch('[^/]+') do if part=='.' or part=='..' or #part>100 then return false end end
 return s:sub(-1)~='/'
end
function M.id(s) return type(s)=='string' and #s<=64 and s:match('^[A-Za-z][A-Za-z0-9_%-]*$')~=nil end
function M.fields(s)
 local r={};for f in (s..'\t'):gmatch('(.-)\t') do r[#r+1]=f end;return r
end
local function rows(text,limit)
 if type(text)~='string' or #text>limit or text:find('\0',1,true) then error('Invalid or oversized catalog') end
 local r={};for line in text:gmatch('[^\n]+') do
  line=line:gsub('\r$','')
  if #line>2048 then error('Catalog line too long') end
  r[#r+1]=M.fields(line)
 end;return r
end
function M.catalog(text)
 local r=rows(text,262144)
 assert(r[1] and r[1][1]=='WLT-CATALOG' and r[1][2]=='1','Unsupported catalog')
 local out,seen={},{}
 for i=2,#r do local f=r[i]
  assert(#f==8 and f[1]=='PLUGIN','Invalid plugin catalog row')
  assert(M.id(f[2]) and not seen[f[2]],'Invalid or duplicate plugin ID')
  assert(#f[3]>0 and #f[3]<90 and not f[3]:find('[%c]'),'Invalid plugin name')
  assert(M.version(f[4]) and M.version(f[5]),'Invalid version')
  assert(M.path(f[6]) and not f[6]:find('/') and M.path(f[7]),'Invalid plugin folder or release path')
  assert(#f[8]==64 and f[8]:match('^[a-f0-9]+$'),'Invalid release digest')
  seen[f[2]]=true
  out[#out+1]={id=f[2],name=f[3],version=f[4],minimum=f[5],folder=f[6],manifest=f[7],digest=f[8]}
  assert(#out<=100,'Catalog has too many plugins')
 end
 return out
end
function M.manifest(text,plugin)
 assert(M.sha256(text)==plugin.digest,'Release manifest checksum mismatch')
 local r=rows(text,262144);local head=r[1]
 assert(head and #head==6 and head[1]=='WLT-RELEASE' and head[2]=='1','Unsupported release manifest')
 assert(head[3]==plugin.id and head[4]==plugin.version and head[5]==plugin.folder,'Release identity mismatch')
 assert(M.path(head[6]) and head[6]:match('%.xml$') and not head[6]:find('/'),'Invalid import XML')
 local out={files={},xml=head[6],plugin=plugin};local names={};local total=0
 for i=2,#r do local f=r[i]
  assert(#f==5 and (f[1]=='FILE' or f[1]=='ZIP'),'Invalid release file')
  assert(M.path(f[2]) and M.path(f[3]),'Unsafe release path')
  local bytes=tonumber(f[4]);assert(bytes and bytes>=1 and bytes%1==0 and bytes<=33554432,'Invalid file size')
  assert(#f[5]==64 and f[5]:match('^[a-f0-9]+$'),'Invalid checksum')
  assert(not names[f[2]],'Duplicate release filename');names[f[2]]=true
  local file={path=f[2],remote=f[3],bytes=bytes,sha=f[5]}
  if f[1]=='ZIP' then assert(not out.zip,'Duplicate ZIP');out.zip=file else out.files[#out.files+1]=file end
  total=total+bytes;assert(total<=67108864 and #out.files<=150,'Release is too large')
 end
 assert(names[out.xml] and out.zip and #out.files>0,'Release has no XML or ZIP')
 return out
end
function M.verify(data,spec,pulse)
 return type(data)=='string' and #data==spec.bytes and M.sha256(data,pulse)==spec.sha
end
local entities={amp='&',quot='"',apos="'",lt='<',gt='>'}
local function unescape(s)
 return s:gsub('&([^;]+);',function(x) return entities[x] or ('&'..x..';') end)
end
function M.xml(text)
 if type(text)~='string' or #text>16777216 or text:find('<!DOCTYPE',1,true) then return nil,'Invalid plugin XML' end
 local attrs=text:match('<UserPlugin%s+([^>]+)>') or text:match('<UserPlugin%s+([^>]+)/>')
 if not attrs then return nil,'No UserPlugin metadata' end
 local meta={};for k,v in attrs:gmatch('([%w_]+)%s*=%s*"([^"]*)"') do meta[k]=unescape(v) end
 if not meta.Name or not M.version(meta.Version) then return nil,'Missing plugin name or version' end
 meta.components={}
 for block in text:gmatch('<ComponentLua%s+([^>]+)>') do
  local f=block:match('FileName%s*=%s*"([^"]+)"')
  if f then f=unescape(f);if not M.path(f) then return nil,'Unsafe Lua filename' end;meta.components[#meta.components+1]=f end
 end
 return meta
end
function M.matches(meta,plugin)
 if not meta then return false end
 local folder=(meta.Path or ''):gsub('^/',''):gsub('/$','')
 return (M.key(meta.Name)==M.key(plugin.name) or M.key(folder)==M.key(plugin.folder))
  and (meta.Author or ''):lower():find('aaron wade',1,true)~=nil
end
function M.base64(s)
 local alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
 local out={}
 for i=1,#s,3 do local a,b,c=s:byte(i,i+2);local n=(a<<16)|((b or 0)<<8)|(c or 0)
  out[#out+1]=alphabet:sub((n>>18)+1,(n>>18)+1)..alphabet:sub(((n>>12)&63)+1,((n>>12)&63)+1)
   ..(b and alphabet:sub(((n>>6)&63)+1,((n>>6)&63)+1) or '=')..(c and alphabet:sub((n&63)+1,(n&63)+1) or '=')
 end;return table.concat(out)
end
return M

end)()

local Transport=(function()
-- HTTPS downloader: bounded background jobs, native certificate validation.
-- This module never invokes downloaded code. All scripts below are local literals.
return function(Core, env)
 local T={};local serial=0
 local PREFIX='https://raw.githubusercontent.com/tmoose95/WadeLightingTools/main/'
 local function sh(s) return "'"..s:gsub("'","'\\''").."'" end
 local function ps(s) return "'"..s:gsub("'","''").."'" end
 local function encoded(s)
  -- Only command literals and quoted Unicode paths are encoded.
  local bytes={}
  for _,cp in utf8.codes(s) do
   if cp<=65535 then bytes[#bytes+1]=string.pack('<I2',cp) else
    cp=cp-65536;bytes[#bytes+1]=string.pack('<I2I2',0xd800+(cp>>10),0xdc00+(cp&1023))
   end
  end
  return Core.base64(table.concat(bytes))
 end
 local function response(raw,limit)
  local head,body=raw:match('^(.-)\r\n\r\n(.*)$')
  assert(head and head:match('^HTTP/1%.[01] 200[ %c]'),'HTTPS server did not return HTTP 200')
  local lower=head:lower()
  assert(not lower:find('\r\ncontent%-encoding:%s*[^\r\n]+'),'Unexpected HTTP encoding')
  if lower:find('\r\ntransfer%-encoding:%s*chunked') then
   local parts,total={},0
   while true do
    local line,rest=body:match('^([^\r\n]+)\r\n(.*)$');assert(line,'Invalid HTTP chunk')
    local hex=line:match('^([a-fA-F0-9]+)');local n=hex and tonumber(hex,16)
    assert(n and n<=limit,'Invalid HTTP chunk size')
    if n==0 then body=table.concat(parts);break end
    assert(#rest>=n+2 and rest:sub(n+1,n+2)=='\r\n','Incomplete HTTP chunk')
    total=total+n;assert(total<=limit,'Download too large')
    parts[#parts+1]=rest:sub(1,n);body=rest:sub(n+3)
   end
  else
   local length=tonumber(lower:match('\r\ncontent%-length:%s*(%d+)'))
   assert(not length or #body==length,'Incomplete HTTP response')
  end
  assert(#body<=limit,'Download too large');return body
 end
 function T.get(remote,limit)
  assert(Core.path(remote),'Unsafe download path')
  serial=serial+1
  local job=env.work..'/http_'..tostring(os.time())..'_'..serial
  assert(env.mkdir(job),'Could not create download workspace')
  local body,done,err,kind=job..'/payload',job..'/done',job..'/error',job..'/kind'
  local url=PREFIX..remote
  if env.windows then
   local script="$ErrorActionPreference='Stop';try{[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;"
    .."$r=[Net.HttpWebRequest]::Create("..ps(url)..");$r.Timeout=30000;$r.ReadWriteTimeout=30000;$r.AllowAutoRedirect=$false;"
    .."$r.UserAgent='WadeLightingTools/1.0.0';$p=$r.GetResponse();if([int]$p.StatusCode -ne 200){throw 'HTTP status'};"
    .."$s=$p.GetResponseStream();$f=[IO.File]::OpenWrite("..ps(body)..");try{$b=New-Object byte[] 32768;$n=0;"
    .."while(($k=$s.Read($b,0,$b.Length)) -gt 0){$n+=$k;if($n -gt "..limit.."){throw 'Download too large'};$f.Write($b,0,$k)}}"
    .."finally{$f.Dispose();$s.Dispose();$p.Dispose()};[IO.File]::WriteAllText("..ps(kind)..",'body');"
    .."[IO.File]::WriteAllText("..ps(done)..",'0')}catch{[IO.File]::WriteAllText("..ps(err)..",$_.Exception.Message);"
    .."[IO.File]::WriteAllText("..ps(done)..",'1')}"
   local result=os.execute('start "" /b powershell.exe -NoLogo -NoProfile -NonInteractive -EncodedCommand '..encoded(script)..' >NUL 2>&1')
   assert(result==true or result==0,'Could not start HTTPS downloader')
  else
   local request=job..'/request'
   assert(env.write(request,'GET /tmoose95/WadeLightingTools/main/'..remote..' HTTP/1.0\r\nHost: raw.githubusercontent.com\r\nUser-Agent: WadeLightingTools/1.0.0\r\nConnection: close\r\n\r\n'))
   local script='#!/bin/sh\n'..'ulimit -f '..math.ceil((limit+131072)/512)..' 2>/dev/null || true\n'
    ..'if command -v curl >/dev/null 2>&1; then\n'
    ..' curl --fail --silent --show-error --proto "=https" --connect-timeout 8 --max-time 30 --max-filesize '..limit..' --output '..sh(body)..' '..sh(url)..' 2>'..sh(err)..'\n rc=$?\n echo body >'..sh(kind)..'\n'
    ..'elif command -v openssl >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1; then\n'
    ..' timeout 35 openssl s_client -quiet -connect raw.githubusercontent.com:443 -servername raw.githubusercontent.com -verify_hostname raw.githubusercontent.com -verify_return_error <'..sh(request)..' >'..sh(body)..' 2>'..sh(err)..'\n rc=$?\n echo http >'..sh(kind)..'\n'
    ..'else\n rc=127\n echo "A certificate-validating HTTPS client (curl, or openssl with timeout) was not found." >'..sh(err)..'\nfi\n'
    ..'printf "%s" "$rc" >'..sh(done)..'\n'
   assert(env.write(job..'/fetch.sh',script))
   local result=os.execute('sh '..sh(job..'/fetch.sh')..' >/dev/null 2>&1 &')
   assert(result==true or result==0,'Could not start HTTPS downloader')
  end
  local started=env.now()
  while not env.exists(done) do
   if env.cancelled() then error('Cancelled; the bounded download job will finish without installation') end
   assert(env.now()-started<42,'HTTPS request timed out; no plugin was installed')
   env.pause(0.1)
  end
  local status=env.read(done,64)
  if not status or not status:match('^0%s*$') then
   local why=env.read(err,4096) or ('Downloader exit '..tostring(status))
   error(why:sub(1,500))
  end
  local data=assert(env.read(body,limit+65536),'Empty or oversized download')
  local mode=env.read(kind,64) or ''
  if mode:match('http') then data=response(data,limit) end
  assert(#data<=limit,'Download too large')
  for _,f in ipairs({'payload','done','error','kind','request','fetch.sh'}) do os.remove(job..'/'..f) end
  os.remove(job)
  return data
 end
 T.response=response
 return T
end

end)()

local Runtime=(function()
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
 local function report(text) notify(text);Printf('Plugin Updator | %s',text) end
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

end)()

local BOOTSTRAP=[====[
WLT-CATALOG	1
PLUGIN	APIInfo	API Info	1.0.3	2.5.1.0	APIInfo	packages/APIInfo/1.0.3/manifest.tsv	69c889264b925734834b389e84a2fa18fa011e13362da41e3a704f54d14ca3cf
PLUGIN	AttributeClone	Attribute Clone	1.2.1	2.5.1.0	AttributeClone	packages/AttributeClone/1.2.1/manifest.tsv	a62cd3a8e4b47bd191536b156d357594a01ef7192c5e3c088d5e31b5c1292872
PLUGIN	AutoColorPicker	Auto Color Picker	5.0.3.0	2.5.1.0	AutoColorPicker	packages/AutoColorPicker/5.0.3.0/manifest.tsv	fbeeaeefc5b85812bae315cd9b6fa5900b09d186feb3bd6c2f4ef53fdf18ead5
PLUGIN	CueBeacon	Cue Beacon	1.0.0.0	2.5.1.0	Cue_Beacon_v1.0.0	packages/CueBeacon/1.0.0.0/manifest.tsv	04b54f4671a37ac9b0a1d9c69a91a07d0055474424358e77e175219168ad1652
PLUGIN	HippoRemote	Hippo Remote	1.3.0	2.5.1.0	HippoRemote	packages/HippoRemote/1.3.0/manifest.tsv	a28fee7e9aba6de5a9bf091edd1c25c08a1d52ffec2f5673e0a5984a4141353b
PLUGIN	MASearch	MA Search	0.3.9	2.5.1.0	MASearch	packages/MASearch/0.3.9/manifest.tsv	bf64c4af263576c0e497488b92663f8f0c131dbc316d258ea7c94e08c47d804e
PLUGIN	ServerCommand	Server Command	2.3.15	2.5.1.0	ServerCommand	packages/ServerCommand/2.3.15/manifest.tsv	b633ba49882f330544d0c52219554b2f46d05ae19a3437e8313fec2977b86a84
PLUGIN	TouchConfigurator	Touch Configurator	1.0.41	2.5.1.0	TouchConfigurator	packages/TouchConfigurator/1.0.41/manifest.tsv	e86d264925104d9320e6f8b9dafe93c1913c9962f4bc6500b4ea9dc6f52d6f9d
PLUGIN	TourLocation	Tour Location	1.0.10	2.5.1.0	TourLocation	packages/TourLocation/1.0.10/manifest.tsv	791b17e25287f88facd6aa3406867da99baa38b95cbd891dd8429db01d4b7b36
PLUGIN	WingConfigurator	Wing Configurator	1.0.28	2.5.1.0	WingConfigurator	packages/WingConfigurator/1.0.28/manifest.tsv	a8b62d7140487372373248d141b4541c608801ad94b117c6b8f1b3b4b439814a
]====]
-- Visual arrangement follows MA's Edit Display Preference panel.
local function display_icon(control)
    control.Text='▣'
    if type(FindTexture)=='function' then
        for _,name in ipairs({'display','screen','monitor','object_display'}) do
            local ok,texture=pcall(FindTexture,name)
            if ok and texture then control.Icon=name;control.Text='';break end
        end
    end
end
local function display_preference(overlay,display,moveCallback,cancelCallback,available)
    local theme=Root().ColorTheme.ColorGroups
    local chooser=overlay:Append('BaseInput')
    chooser.Name='EditDisplayPreference';chooser.W=600;chooser.H=660
    chooser.MaxSize=string.format('%s,%s',display.W*.94,display.H*.94)
    chooser.Columns,chooser.Rows=1,2;chooser.AutoClose='No';chooser.CloseOnEscape='Yes'
    chooser[1][1].SizePolicy='Fixed';chooser[1][1].Size='54';chooser[1][2].SizePolicy='Stretch'
    local top=chooser:Append('TitleBar');top.Anchors='0,0';top.Columns,top.Rows=3,1
    top[2][2].SizePolicy='Fixed';top[2][2].Size='105'
    top[2][3].SizePolicy='Fixed';top[2][3].Size='54'
    local caption=top:Append('TitleButton');caption.Anchors='0,0';caption.Text='Edit Display Preference';caption.Texture='corner1'
    button(top,1,0,'CancelMove','Clear',cancelCallback)
    local x=top:Append('CloseButton');x.Anchors='2,0';x.Texture='corner2'
    local grid=chooser:Append('UILayoutGrid');grid.Anchors='0,1';grid.Columns,grid.Rows=3,3
    grid.Margin={left=8,right=8,top=6,bottom=8}
    local cells={{5,0,0,'External 5'},{4,2,0,'External 4'},{3,0,1,'Internal 3'},
        {2,1,1,'Internal 2'},{1,2,1,'Internal 1'},{7,1,2,'Small 7'},{6,2,2,'Small 6'}}
    for _,cell in ipairs(cells) do
        local index,col,row,label=table.unpack(cell)
        local b=button(grid,col,row,'Display'..index,label,moveCallback,theme.Button.BackgroundNormal)
        b.Margin={left=3,right=3,top=3,bottom=3}
        b.Enabled=available(index) and 'Yes' or 'No'
        if index==Obj.Index(display) then
            b.State=1
            local ok,color=pcall(function()return theme.Button.TextPlease end)
            if ok and color then b.TextColor=color end
        end
    end
    return chooser
end


-- UI entry point. Core, Transport, Runtime, button and display helpers are bundled above.
local VERSION='1.0.1'
local ui={selected={},busy=false}
local R
local build
local function valid(h) return h and safe(function()return IsObjectValid(h)end,false) end
local function notify(text)
 if valid(ui.status) then ui.status.Text=text end
 if ui.progress then safe(function()SetProgressText(ui.progress,text)end) end
end
local function remove(h) if valid(h) then safe(function()Obj.Delete(h:Parent(),Obj.Index(h))end) end end
local function close()
 if ui.busy then if R then R.cancel=true end;notify('Cancelling after the current operation');return end
 remove(ui.chooser);remove(ui.base);ui.chooser=nil;ui.base=nil
 if _G.__WadeLightingToolsWindow==ui then _G.__WadeLightingToolsWindow=nil end
end
local function errorbox(err) MessageBox({title='Plugin Updator',message=tostring(err),commands={{value=1,name='OK'}}}) end
local function guarded(fn)
 if ui.busy then return end
 local ok,err=pcall(fn);if not ok then ui.busy=false;errorbox(err) end
end
local function available_display(i)
 local d=safe(function()return GetDisplayByIndex(i)end,nil)
 return valid(d) and valid(d.ScreenOverlay) and tonumber(d.W)>0 and tonumber(d.H)>0
end
local function label(parent,col,row,text,font)
 local o=parent:Append('UIObject');o.Anchors={left=col,right=col,top=row,bottom=row}
 o.Text=text;o.Font=font or 'Regular16';o.TextalignmentH='Left'
 o.Padding={left=8,right=4,top=4,bottom=4};o.BackColor=Root().ColorTheme.ColorGroups.Global.Transparent
 return o
end
local function grid(parent,name,cols,rows,anchor)
 local o=parent:Append('UILayoutGrid');o.Name=name;o.Columns=cols;o.Rows=rows;o.Anchors=anchor;return o
end
local function redraw() build(ui.display) end
local function scan(connect)
 ui.busy=true
 ui.progress=StartProgress('WadeLightingTools | Scanning drives')
 local ok,err=pcall(function()R.scan(connect)end)
 StopProgress(ui.progress);ui.progress=nil;ui.busy=false
 if not ok then errorbox(err) end
 redraw()
end
signalTable.WLTClose=function() close() end
signalTable.WLTRescan=function()guarded(function()scan(true)end)end
signalTable.WLTItem=function(c)guarded(function()
 local id=c.Name:match('^Item_(.+)$');if not id then return end
 ui.selected[id]=not ui.selected[id];redraw()
end)end
signalTable.WLTClear=function()guarded(function()ui.selected={};redraw()end)end
signalTable.WLTAll=function()guarded(function()
 ui.selected={};for _,p in ipairs(R.catalog)do if R.status(p)=='Update available' then ui.selected[p.id]=true end end;redraw()
end)end
signalTable.WLTMode=function(c)guarded(function()
 R.mode=tonumber(c.Name:match('Mode(%d+)')) or 1;redraw()
end)end
signalTable.WLTDrives=function()guarded(function()
 local states={};for _,d in ipairs(R.drives)do states[#states+1]={name=d.label,state=R.selectedDrives[d.path] or false} end
 local answer=MessageBox({title='Drives',message='Downloads go to every selected drive. Install Only uses the newest complete package on the selected drives.',
  states=states,commands={{value=1,name='Apply'},{value=0,name='Cancel'}}})
 if answer and answer.success and answer.result==1 then
  R.selectedDrives={};for _,d in ipairs(R.drives)do if answer.states and answer.states[d.label] then R.selectedDrives[d.path]=true end end
  redraw()
 end
end)end
signalTable.WLTPool=function()guarded(function()
 local pools=R.children(Root().ShowData.DataPools);local commands={{value=0,name='Cancel'}};local lookup={}
 for _,p in pairs(pools)do local n=R.index(p);if n then commands[#commands+1]={value=n,name=n..' - '..R.prop(p,'Name')};lookup[n]=p end end
 local a=MessageBox({title='Destination DataPool',message='Existing matching plugins keep their pool slots. New plugins use empty slots.',commands=commands})
 if a and a.success and lookup[a.result]then R.pool=lookup[a.result];R.refreshInstalled();redraw()end
end)end
signalTable.WLTDetails=function()guarded(function()
 local lines={'Catalog: https://github.com/tmoose95/WadeLightingTools',
  'Drive scan: '..#R.drives..' connected drive(s).','Internet: '..(R.online and 'Catalog loaded' or 'Unavailable'),
  'Downloads use HTTPS certificate validation and SHA-256 checksums.',
  'The updater is installed manually after downloading its new revision.'}
 for _,x in ipairs(R.issues)do lines[#lines+1]=x end
 MessageBox({title='Updater details',message=table.concat(lines,'\n\n'),commands={{value=1,name='Close'}}})
end)end
signalTable.WLTUpdate=function()guarded(function()
 local plan=R.plan(ui.selected)
 local mode=({'Download & Install','Download Only','Install Only'})[plan.mode]
 local destinations={};for _,d in ipairs(plan.drives)do destinations[#destinations+1]=d.label end
 local answer=MessageBox({title='Review updates',message=mode..'\n'..table.concat(destinations,'\n')..'\n\n'..table.concat(plan.lines,'\n'),
  commands={{value=1,name='Update'},{value=0,name='Cancel'}}})
 if not answer or not answer.success or answer.result~=1 then return end
 ui.busy=true;R.cancel=false;ui.progress=StartProgress('WadeLightingTools | Updating')
 local ok,result=pcall(R.run,plan)
 StopProgress(ui.progress);ui.progress=nil;ui.busy=false
 MessageBox({title=ok and 'Update results' or 'Update stopped',message=tostring(result),commands={{value=1,name='Close'}}})
 ui.selected={};scan(false)
end)end
signalTable.WLTMove=function()guarded(function()
 if valid(ui.chooser)then return end
 ui.chooser=display_preference(ui.display.ScreenOverlay,ui.display,'WLTDisplay','WLTCancelMove',available_display)
end)end
signalTable.WLTCancelMove=function()remove(ui.chooser);ui.chooser=nil end
signalTable.WLTDisplay=function(c)guarded(function()
 local i=tonumber(c.Name:match('Display(%d+)'));if i and available_display(i)then
  remove(ui.chooser);ui.chooser=nil;build(GetDisplayByIndex(i))
 end
end)end
build=function(display)
 remove(ui.base)
 display=display or GetFocusDisplay() or GetDisplayByIndex(1);ui.display=display
 local theme=Root().ColorTheme.ColorGroups;local face=theme.Button.BackgroundNormal;local green=theme.Button.BackgroundPlease
 local base=display.ScreenOverlay:Append('BaseInput');ui.base=base
 base.Name='WadePluginUpdater';base.W=math.min(1180,display.W*.96);base.H=math.min(820,display.H*.94)
 base.Columns=1;base.Rows=2;base.AutoClose='No';base.CloseOnEscape='Yes'
 base.MaxSize=string.format('%s,%s',display.W*.97,display.H*.96)
 base[1][1].SizePolicy='Fixed';base[1][1].Size='54';base[1][2].SizePolicy='Stretch'
 local title=base:Append('TitleBar');title.Columns=3;title.Rows=1;title.Anchors='0,0'
 title[2][2].SizePolicy='Fixed';title[2][2].Size='54';title[2][3].SizePolicy='Fixed';title[2][3].Size='54'
 local name=title:Append('TitleButton');name.Anchors='0,0';name.Text='PLUGIN UPDATOR  v'..VERSION;name.Texture='corner1';name.Font='Regular18'
 display_icon(button(title,1,0,'Move','','WLTMove'))
 local x=title:Append('CloseButton');x.Anchors='2,0';x.Texture='corner2';x.PluginComponent=myHandle;x.Clicked='WLTClose'
 local frame=base:Append('DialogFrame');frame.Columns=1;frame.Rows=6;frame.Anchors='0,1'
 for i,h in ipairs({52,40,34,0,58,54})do frame[1][i].SizePolicy=i==4 and 'Stretch' or 'Fixed';if i~=4 then frame[1][i].Size=tostring(h)end end
 local settings=grid(frame,'Settings',3,1,'0,0')
 button(settings,0,0,'Drives','DRIVES  ('..#R.drivesSelected()..' selected)','WLTDrives',face)
 button(settings,1,0,'Pool','DATAPOOL  '..tostring(R.index(R.pool))..'  '..R.prop(R.pool,'Name'),'WLTPool',face)
 button(settings,2,0,'Rescan','RESCAN DRIVES & INTERNET','WLTRescan',face)
 ui.status=label(frame,0,1,#R.drives..' drives scanned  |  '..(R.online and 'Internet catalog connected' or 'Internet unavailable - local installs available'),'Regular16')
 local headings=grid(frame,'Headings',5,1,'0,2')
 headings[2][1].SizePolicy='Stretch';headings[2][1].Size='3'
 for col,text in ipairs({'PLUGIN','INSTALLED','ON DRIVE','ONLINE','STATUS'})do label(headings,col-1,0,text)end
 local panel=grid(frame,'PluginListPanel',2,1,'0,3');panel[2][2].SizePolicy='Fixed';panel[2][2].Size='18'
 local scroll=panel:Append('ScrollBox');scroll.Name='PluginScroll';scroll.Anchors='0,0'
 local bar=panel:Append('ScrollBarV');bar.Anchors='1,0';bar.ScrollTarget=scroll
 local list=grid(scroll,'PluginList',5,math.max(1,#R.catalog),'0,0');list.W='100%';list.H=math.max(1,#R.catalog)*46
 list[2][1].SizePolicy='Stretch';list[2][1].Size='3'
 for row,p in ipairs(R.catalog)do
  list[1][row].SizePolicy='Fixed';list[1][row].Size='46'
  local edge=list:Append('UIObject');edge.Anchors={left=0,right=4,top=row-1,bottom=row-1};edge.Margin={left=2,right=2,top=2,bottom=2}
  edge.BackColor=ui.selected[p.id] and green or (safe(function()return theme.Button.TextDisabled end,theme.Global.Text))
  local inside=list:Append('UIObject');inside.Anchors=edge.Anchors;inside.Margin={left=4,right=4,top=4,bottom=4};inside.BackColor=face
  local b=button(list,0,row-1,'Item_'..p.id,(ui.selected[p.id] and '[x]  ' or '[ ]  ')..p.name,'WLTItem',face);b.Margin={left=6,right=4,top=5,bottom=5};b.Font='Regular16';b.TextalignmentH='Left'
  local localVersion=R.localBest(p,true)
  label(list,1,row-1,R.installedText(p));label(list,2,row-1,localVersion and localVersion.version or '-');label(list,3,row-1,R.online and p.version or '-');label(list,4,row-1,R.status(p))
 end
 local modes=grid(frame,'Modes',3,1,'0,4')
 for n,text in ipairs({'DOWNLOAD & INSTALL','DOWNLOAD ONLY','INSTALL ONLY'})do
  local b=button(modes,n-1,0,'Mode'..n,text,'WLTMode',face);b.State=R.mode==n and 1 or 0
  if R.mode==n then b.TextColor=theme.Button.TextPlease end
 end
 local footer=grid(frame,'Footer',5,1,'0,5')
 button(footer,0,0,'All','SELECT UPDATES','WLTAll',face)
 button(footer,1,0,'Clear','CLEAR','WLTClear',face)
 button(footer,2,0,'Details','DETAILS','WLTDetails',face)
 local count=0;for _,v in pairs(ui.selected)do if v then count=count+1 end end
 button(footer,3,0,'Update','UPDATE ('..count..')','WLTUpdate',green)
 button(footer,4,0,'Close','CLOSE','WLTClose',face)
 _G.__WadeLightingToolsWindow=ui
end
local function metadata()
 safe(function()
  local p=myHandle:Parent();local appearance=Root().ShowData.Appearances.PluginUpdator_1_0_1
  if appearance then p.Appearance=appearance end
  local tag
  for _,t in ipairs(ObjectList('Tag Thru') or {})do if R.prop(t,'Name')=='Utility Plugins' then tag=t;break end end
  if not tag then Cmd('Store Tag "Utility Plugins" /NoConfirmation') end
  for _,t in ipairs(ObjectList('Tag Thru') or {})do if R.prop(t,'Name')=='Utility Plugins'then tag=t;break end end
  if tag then Cmd('Assign Tag '..R.index(tag)..' At '..p:ToAddr()..' /NoConfirmation') end
 end)
end
return function()
 local old=_G.__WadeLightingToolsWindow
 if old and old.busy then errorbox('An update or scan is already running.');return end
 if old then remove(old.chooser);remove(old.base)end
 _G.__WadeLightingToolsWindow=ui;ui.busy=true
 local ok,why=pcall(function()
  R=Runtime(Core,Transport,BOOTSTRAP,notify)
  ui.display=GetFocusDisplay() or GetDisplayByIndex(1)
  metadata()
  scan(true) -- Main window is created only after the connected-drive scan.
 end)
 if not ok then
  if ui.progress then StopProgress(ui.progress);ui.progress=nil end
  ui.busy=false;errorbox(why)
 end
end
