-- Deterministic background-transfer polling using real temp files, no internet.
local C=dofile('updater/src/core.lua');local Factory=dofile('updater/src/transport.lua')
local lfs=require('lfs');local home=os.tmpname();os.remove(home);assert(lfs.mkdir(home))
local function read(p,max)local f=io.open(p,'rb');if not f then return nil end;local s=f:read(max or '*a');f:close();return s end
local function write(p,s)local f=assert(io.open(p,'wb'));assert(f:write(s));f:close();return true end
local count=0;local function test(name,fn)fn();count=count+1;print('PASS '..name)end
local payload=string.rep('abcdef',1024)
local header='HTTP/1.0 200 OK\r\nContent-Length: '..#payload..'\r\n\r\n'
local T=Factory(C,{})
test('HTTP progress excludes headers and defers chunked framing',function()
 local p=home..'/probe';write(p,header..payload:sub(1,500))
 assert(T.received(p,'http')==500);assert(T.received(p,'body')==#header+500)
 write(p,'HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n4\r\ndata\r\n')
 assert(T.received(p,'http')==0)
end)
local runs=0
local function run(mode,fail,cancel)
 runs=runs+1;local work=home..'/case'..runs;assert(lfs.mkdir(work))
 local job,clock,steps;clock=0;steps=0;local values={}
 local env={work=work,windows=mode=='windows',read=read,write=write,
  mkdir=function(p)job=p;return lfs.mkdir(p)end,
  exists=function(p)return lfs.attributes(p,'mode')=='file'end,
  now=function()return clock end,cancelled=function()return cancel and steps==2 end}
 env.pause=function()
  steps=steps+1;clock=clock+.1
  if mode=='windows'then write(job..'/bytes',tostring(steps*1000))
  else write(job..'/payload',(mode=='http' and header or '')..payload:sub(1,steps*1000));write(job..'/kind',mode)end
  if steps==4 then
   write(job..'/payload',(mode=='http' and header or '')..payload)
   write(job..'/kind',mode=='http' and 'http' or 'body');write(job..'/done',fail and '1' or '0')
   if fail then write(job..'/error','Transfer failed')end
  end
 end
 local old=os.execute;os.execute=function()return true end
 local tr=Factory(C,env)
 local ok,result=pcall(tr.get,'catalog.tsv',#payload,function(n,total)values[#values+1]=n;assert(total==#payload)end)
 os.execute=old
 assert(values[1]==0 and #values>=(cancel and 2 or 3))
 for i=2,#values do assert(values[i]>=values[i-1] and values[i]<=#payload)end
 if fail or cancel then assert(not ok and values[#values]<#payload)
 else assert(ok and result==payload and values[#values]==#payload and values[2]>0 and values[2]<#payload)end
 return values
end
test('Plain body transfer emits partial bytes before completion',function()run('body')end)
test('OpenSSL HTTP transfer emits actual body bytes before completion',function()run('http')end)
test('Windows byte sidecar advances progress while payload is locked',function()run('windows')end)
test('Transport error and cancellation do not report completed transfer',function()run('http',true);run('body',false,true)end)
print(count..' transport progress scenarios passed')
