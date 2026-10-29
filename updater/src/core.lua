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
