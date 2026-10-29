-- HTTPS downloader: bounded background jobs, native certificate validation.
-- This module never invokes downloaded code. All scripts below are local literals.
return function(Core, env, trustBundle)
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
   assert(length,'HTTPS response has no explicit content length')
   assert(#body==length,'Incomplete HTTP response')
  end
  assert(#body<=limit,'Download too large');return body
 end
 -- Emit a POSIX job instead of depending on GNU timeout (not present on all desks).
 local function unixJob(job,url,requestPath,limit,ca)
  local body,done,err,kind=job..'/payload',job..'/done',job..'/error',job..'/kind'
  local cert=ca and (' -CAfile '..sh(ca)) or ''
  local script={'#!/bin/sh',
   'PATH="$PATH:/usr/bin:/bin:/usr/sbin:/sbin"; export PATH',
   'ulimit -f '..math.ceil((limit+131072)/512)..' 2>/dev/null || true',
   'run_bounded() {',
   ' exec 9<&0; "$@" <&9 & child=$!; exec 9<&-',
   ' ( n=0; while kill -0 "$child" 2>/dev/null; do',
   '   if [ -f '..sh(job..'/cancel')..' ] || [ "$n" -ge 35 ]; then',
   '     echo "Request cancelled or exceeded 35 seconds" >&2; kill "$child" 2>/dev/null; break',
   '   fi; sleep 1; n=$((n+1)); done ) & timer=$!',
   ' wait "$child"; rc=$?; kill "$timer" 2>/dev/null; wait "$timer" 2>/dev/null; return "$rc"',
   '}',
   'rc=127',
   'if command -v curl >/dev/null 2>&1; then',
   ' echo "curl / system trust" >'..sh(job..'/client'),
   ' run_bounded curl --fail --silent --show-error --proto "=https" --connect-timeout 8 --max-time 30 --max-filesize '..limit..' --output '..sh(body)..' '..sh(url)..' 2>'..sh(err),
   ' rc=$?; echo body >'..sh(kind)}
  if ca then
   script[#script+1]=' if [ "$rc" -eq 60 ] || [ "$rc" -eq 77 ]; then'
   script[#script+1]='  echo "curl / bundled Mozilla trust" >'..sh(job..'/client')
   script[#script+1]='  run_bounded curl --fail --silent --show-error --proto "=https" --connect-timeout 8 --max-time 30 --cacert '..sh(ca)..' --max-filesize '..limit..' --output '..sh(body)..' '..sh(url)..' 2>>'..sh(err)
   script[#script+1]='  rc=$?; fi'
  end
  script[#script+1]='elif command -v openssl >/dev/null 2>&1; then'
  script[#script+1]=' eofOption=; case "$(openssl s_client -help 2>&1)" in *-ignore_unexpected_eof*) eofOption=-ignore_unexpected_eof;; esac'
  script[#script+1]=' echo "OpenSSL / bundled Mozilla trust" >'..sh(job..'/client')
  script[#script+1]=' run_bounded openssl s_client -quiet $eofOption -connect raw.githubusercontent.com:443 -servername raw.githubusercontent.com -verify_hostname raw.githubusercontent.com -verify_return_error'..cert..' <'..sh(job..'/request')..' >'..sh(body)..' 2>'..sh(err)
  script[#script+1]=' rc=$?; echo http >'..sh(kind)
  -- BusyBox wget builds may omit peer verification; only accept GNU Wget here.
  script[#script+1]='elif command -v wget >/dev/null 2>&1; then'
  script[#script+1]=' case "$(wget --version 2>/dev/null)" in *"GNU Wget"*)'
  script[#script+1]='  echo "GNU Wget / bundled Mozilla trust" >'..sh(job..'/client')
  script[#script+1]='  run_bounded wget --https-only --max-redirect=0 --timeout=30 --tries=1'..(ca and (' --ca-certificate='..sh(ca)) or '')..' -O '..sh(body)..' '..sh(url)..' 2>'..sh(err)
  script[#script+1]='  rc=$?; echo body >'..sh(kind)..';;'
  script[#script+1]='  *) echo "This wget build does not provide the required certificate checks; curl or OpenSSL is needed." >'..sh(err)..';; esac'
  script[#script+1]='else echo "No supported HTTPS client was found (curl, OpenSSL or GNU Wget). This does not mean the station has no internet." >'..sh(err)
  script[#script+1]='fi'
  script[#script+1]='printf "%s" "$rc" >'..sh(done)
  return table.concat(script,'\n')..'\n'
 end
 function T.get(remote,limit)
  assert(Core.path(remote),'Unsafe download path')
  assert(type(limit)=='number' and limit>0 and limit<=33554432,'Invalid download limit')
  serial=serial+1
  local job=env.work..'/http_'..tostring(os.time())..'_'..serial
  assert(env.mkdir(job),'Could not create download workspace')
  local body,done,err,kind=job..'/payload',job..'/done',job..'/error',job..'/kind'
  local requestPath=remote:gsub(' ','%%20')
  local url=PREFIX..requestPath
  if env.windows then
   local script="$ErrorActionPreference='Stop';try{[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;"
    .."$r=[Net.HttpWebRequest]::Create("..ps(url)..");$r.Timeout=30000;$r.ReadWriteTimeout=30000;$r.AllowAutoRedirect=$false;"
    .."$r.UserAgent='WadeLightingTools/1.1.0';$p=$r.GetResponse();if([int]$p.StatusCode -ne 200){throw 'HTTP status'};"
    .."$s=$p.GetResponseStream();$f=[IO.File]::OpenWrite("..ps(body)..");try{$b=New-Object byte[] 32768;$n=0;$timer=[Diagnostics.Stopwatch]::StartNew();"
    .."while(($k=$s.Read($b,0,$b.Length)) -gt 0){if($timer.Elapsed.TotalSeconds -gt 35){throw 'Request timed out'};"
    .."if([IO.File]::Exists("..ps(job..'/cancel')..")){throw 'Cancelled'};$n+=$k;if($n -gt "..limit.."){throw 'Download too large'};$f.Write($b,0,$k)}}"
    .."finally{$f.Dispose();$s.Dispose();$p.Dispose()};[IO.File]::WriteAllText("..ps(kind)..",'body');"
    .."[IO.File]::WriteAllText("..ps(done)..",'0')}catch{[IO.File]::WriteAllText("..ps(err)..",$_.Exception.Message);"
    .."[IO.File]::WriteAllText("..ps(done)..",'1')}"
   T.client='Windows HTTPS / system trust'
   local result=os.execute('start "" /b powershell.exe -NoLogo -NoProfile -NonInteractive -EncodedCommand '..encoded(script)..' >NUL 2>&1')
   assert(result==true or result==0,'Could not start HTTPS downloader')
  else
   local ca
   if trustBundle and trustBundle:find('-----BEGIN CERTIFICATE-----',1,true) then
    ca=job..'/ca.pem';assert(env.write(ca,trustBundle),'Cannot write HTTPS trust bundle')
   end
   assert(env.write(job..'/request','GET /tmoose95/WadeLightingTools/main/'..requestPath..' HTTP/1.0\r\nHost: raw.githubusercontent.com\r\nUser-Agent: WadeLightingTools/1.1.0\r\nConnection: close\r\n\r\n'))
   assert(env.write(job..'/fetch.sh',unixJob(job,url,requestPath,limit,ca)))
   local result=os.execute('sh '..sh(job..'/fetch.sh')..' >/dev/null 2>&1 &')
   assert(result==true or result==0,'Could not start HTTPS downloader')
  end
  local started=env.now()
  while not env.exists(done) do
   if env.cancelled() or env.now()-started>=75 then
    env.write(job..'/cancel','1')
    error(env.cancelled() and 'Cancelled' or 'Catalog server request timed out')
   end
   env.pause(0.1)
  end
  T.client=env.read(job..'/client',256) or T.client or 'No supported client'
  local status=env.read(done,64)
  if not status or not status:match('^0%s*$') then
   local why=env.read(err,16384) or ('Downloader exit '..tostring(status))
   -- Keep the end: certificate failures and HTTP status normally appear there.
   T.lastError=T.client:gsub('%s+$','')..' (exit '..tostring(status)..'): '..why:sub(-1600)
   error(T.lastError,0)
  end
  local data=assert(env.read(body,limit+65536),'Empty or oversized download')
  local mode=env.read(kind,64) or ''
  if mode:match('http') then data=response(data,limit) end
  assert(#data<=limit,'Download too large')
  for _,f in ipairs({'payload','done','error','kind','request','fetch.sh','client','ca.pem','cancel'}) do os.remove(job..'/'..f) end
  os.remove(job);T.lastError=nil
  return data
 end
 T.response=response
 T.unixJob=unixJob
 return T
end
