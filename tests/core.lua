local C=dofile('updater/src/core.lua')
local count=0
local function check(name,fn) fn();count=count+1;print('PASS '..name)end
check('SHA-256 empty',function()assert(C.sha256('')=='e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855')end)
check('SHA-256 abc',function()assert(C.sha256('abc')=='ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')end)
check('SHA-256 multi-block',function()assert(C.sha256(string.rep('a',1000000))=='cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0')end)
check('Numeric versions',function()assert(C.compare('1.2.10','1.2.9')==1);assert(C.compare('2.5.1','2.5.1.0')==0);assert(C.compare('1.9.9','2.0.0')==-1);assert(C.compare('unknown','1.0.0')==nil);assert(C.version('1.2.3.')==nil)end)
check('Path traversal rejected',function()for _,s in ipairs({'../x','x/../../file','/abs','a\\b','http://evil','x//y','a;cmd','a\nfile'})do assert(not C.path(s),s)end end)
check('Base64 byte fidelity',function()assert(C.base64('foo')=='Zm9v');assert(C.base64('f')=='Zg==');assert(C.base64('\0\255\128')=='AP+A')end)
local f=assert(io.open('catalog.tsv','rb'));local text=f:read('*a');f:close();local cat=C.catalog(text)
check('Every published manifest and file',function()
 for _,p in ipairs(cat)do
  local f=assert(io.open(p.manifest,'rb'));local s=f:read('*a');f:close();local m=C.manifest(s,p)
  for _,file in ipairs(m.files)do local h=assert(io.open(file.remote,'rb'));local b=h:read('*a');h:close();assert(C.verify(b,file),file.remote)end
  local h=assert(io.open(m.zip.remote,'rb'));local b=h:read('*a');h:close();assert(C.verify(b,m.zip))
 end
end)
check('Catalog parsing fails closed',function()
 assert(not pcall(C.catalog,'<html>Error</html>'))
 assert(not pcall(C.catalog,text..text:match('(PLUGIN[^\n]+)')..'\n'))
end)
check('Corrupt release rejected',function()
 local p=cat[1];local f=assert(io.open(p.manifest,'rb'));local s=f:read('*a');f:close()
 assert(not pcall(C.manifest,s..'x',p));assert(not C.verify('x',{bytes=2,sha=C.sha256('x')}))
end)
check('XML metadata + author matching',function()
 local m=C.xml('<GMA3><UserPlugin Name="Server Command" Version="2.3.15" Path="/ServerCommand" Author="Aaron Wade - Crossfade Design"><ComponentLua FileName="Server_Command.lua" /></UserPlugin></GMA3>')
 assert(m and #m.components==1);assert(C.matches(m,{name='Server Command',folder='ServerCommand'}));m.Author='Someone else';assert(not C.matches(m,{name='Server Command',folder='ServerCommand'}))
 assert(not C.xml('<!DOCTYPE GMA3><UserPlugin Name="x" Version="1.0.0"/>'))
end)
local T=dofile('updater/src/transport.lua')(C,{})
check('Renamed folders and prior updater identities',function()
 assert(C.path('packages/WadePluginUpdater/1.0.2/WLT Plugin Updator/WLT Plugin Updator.lua'))
 for _,s in ipairs({' leading','trailing ','x/ /y','x/../a','x/%20','a\tfile'})do assert(not C.path(s),s)end
 local p={id='WadePluginUpdater',name='WLT Plugin Updator',folder='WLT Plugin Updator'}
 assert(C.matches({Name='Wade Plugin Updater',Path='/WadePluginUpdater',Author='Aaron Wade'},p))
 assert(C.matches({Name='Plugin Updator',Path='/WadePluginUpdater',Author='Aaron Wade'},p))
 assert(C.matches({Name='WLT Plugin Updator',Path='/WLT Plugin Updator',Author='Aaron Wade'},p))
 assert(#C.catalog(text:gsub('\n','\r\n'))==#cat)
end)
check('Spaces are URL encoded on Unix and Windows downloads',function()
 local remote='packages/WadePluginUpdater/1.0.2/WLT Plugin Updator/WLT Plugin Updator.lua'
 local escaped=remote:gsub(' ','%%20')
 for _,windows in ipairs({false,true})do
  local writes,command={},nil
  local env={work='/mock/work',windows=windows,mkdir=function()return true end,
   write=function(p,s)writes[p]=s;return true end,exists=function()return true end,now=function()return 0 end,
   cancelled=function()return false end,pause=function()end,
   read=function(p)if p:match('/done$')then return'0'elseif p:match('/kind$')then return'body'else return'payload'end end}
  local execute,remove=os.execute,os.remove
  os.execute=function(s)command=s;return true end;os.remove=function()return true end
  local ok,result=pcall(function()return dofile('updater/src/transport.lua')(C,env).get(remote,100)end)
  os.execute,os.remove=execute,remove
  assert(ok,result);assert(result=='payload'and command)
  if windows then
   local encoded=assert(command:match('EncodedCommand ([A-Za-z0-9+/=]+)'))
   local alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
   local bits,n,bytes=0,0,{}
   for c in encoded:gmatch('.')do
    local digit=alphabet:find(c,1,true)
    if digit then bits=(bits<<6)|(digit-1);n=n+6;if n>=8 then n=n-8;bytes[#bytes+1]=string.char((bits>>n)&255)end end
   end
   local script=table.concat(bytes):gsub('\0','')
   assert(script:find(escaped,1,true),'Windows URL was not encoded')
  else
   local script,request
   for p,s in pairs(writes)do if p:match('/fetch.sh$')then script=s elseif p:match('/request$')then request=s end end
   assert(script:find(escaped,1,true)and request:find(escaped,1,true),'Unix URL was not encoded')
  end
 end
end)
check('OpenSSL HTTP response checks',function()
 assert(T.response('HTTP/1.1 200 OK\r\nContent-Length: 3\r\n\r\nabc',10)=='abc')
 assert(T.response('HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n3\r\nabc\r\n0\r\n\r\n',10)=='abc')
 assert(not pcall(T.response,'HTTP/1.1 404 Not Found\r\n\r\nx',10))
 assert(not pcall(T.response,'HTTP/1.1 200 OK\r\nContent-Length: 9\r\n\r\nx',10))
end)
print(count..' core checks passed')
