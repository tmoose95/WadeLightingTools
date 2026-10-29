-- Optional read-only smoke test of the real published HTTPS catalog.
local C=dofile('updater/src/core.lua');local T=dofile('updater/src/transport.lua');local lfs=require('lfs')
local function read(p,n)local f=io.open(p,'rb');if not f then return end;local s=f:read((n or 33554432)+1);f:close();if#s<=(n or 33554432)then return s end end
local function write(p,s)local f=assert(io.open(p,'wb'));f:write(s);f:close();return true end
local function mkdir(p)local path='';for s in p:gmatch('[^/]+')do path=path..'/'..s;if not lfs.attributes(path)then assert(lfs.mkdir(path))end end;return true end
local path=os.tmpname();os.remove(path)
local transport=T(C,{work=path,mkdir=mkdir,write=write,read=read,exists=function(p)return lfs.attributes(p)~=nil end,now=os.time,pause=function()os.execute('sleep 0.1')end,cancelled=function()return false end},assert(read('updater/ca/cacert.pem')))
local catalog=C.catalog(transport.get('catalog.tsv',262144));assert(#catalog==11)
local updater;for _,p in ipairs(catalog)do if p.id=='WadePluginUpdater'then updater=p end end
local manifest=C.manifest(transport.get(updater.manifest,262144),updater)
local zip=transport.get(manifest.zip.remote,manifest.zip.bytes);assert(C.verify(zip,manifest.zip))
print('PASS live catalog, manifest SHA-256 and '..manifest.zip.path..' ZIP checksum via '..transport.client:gsub('%s+$',''))
