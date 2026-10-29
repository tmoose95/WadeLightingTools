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
    local adjusted=cp-65536;bytes[#bytes+1]=string.pack('<I2I2',0xd800+(adjusted>>10),0xdc00+(adjusted&1023))
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
  local requestPath=remote:gsub(' ','%%20')
  local url=PREFIX..requestPath
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
   assert(env.write(request,'GET /tmoose95/WadeLightingTools/main/'..requestPath..' HTTP/1.0\r\nHost: raw.githubusercontent.com\r\nUser-Agent: WadeLightingTools/1.0.0\r\nConnection: close\r\n\r\n'))
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
