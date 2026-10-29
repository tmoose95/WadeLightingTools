#!/usr/bin/env python3
"""Exercise the generated POSIX HTTPS job against a local TLS server.
No MA objects, real fixture control, or unverified external connection.
"""
import http.server, os, pathlib, shutil, ssl, subprocess, tempfile, threading
ROOT=pathlib.Path(__file__).resolve().parents[1]
LUA=os.environ.get('WLT_LUA55','/tmp/lua-5.5.0/src/lua')
count=0
with tempfile.TemporaryDirectory(prefix='wlt-tls-') as tmp:
    d=pathlib.Path(tmp)
    for name,host in [('trusted','raw.githubusercontent.com'),('wrong','other.invalid')]:
        subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-days','1','-keyout',str(d/f'{name}.key'),'-out',str(d/f'{name}.pem'),'-subj',f'/CN={host}','-addext',f'subjectAltName=DNS:{host}'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    class Handler(http.server.BaseHTTPRequestHandler):
        code=200
        def do_GET(self):
            body=b'WLT-CATALOG\t1\n'
            self.send_response(self.code);self.send_header('Content-Length',str(len(body)));self.send_header('Connection','close');self.end_headers();self.wfile.write(body)
        def log_message(self,*a):pass
    def run(name,trust,code=200):
        global count
        Handler.code=code
        server=http.server.HTTPServer(('127.0.0.1',0),Handler)
        ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);ctx.load_cert_chain(str(d/f'{name}.pem'),str(d/f'{name}.key'))
        server.socket=ctx.wrap_socket(server.socket,server_side=True)
        thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        job=d/f'job{count}';job.mkdir()
        request=b'GET /catalog.tsv HTTP/1.0\r\nHost: raw.githubusercontent.com\r\nConnection: close\r\n\r\n';(job/'request').write_bytes(request)
        generator=d/'generate.lua';generator.write_text("local T=dofile('updater/src/transport.lua')({},{});io.write(T.unixJob(arg[1],'https://raw.githubusercontent.com/catalog.tsv','catalog.tsv',262144,arg[2]))")
        script=subprocess.check_output([LUA,str(generator),str(job),str(d/f'{trust}.pem')],cwd=ROOT,text=True)
        # Force the console/OpenSSL branch and route only the TCP connection to the local test server.
        script=script.replace('if command -v curl >/dev/null 2>&1; then','if false; then').replace('raw.githubusercontent.com:443',f'127.0.0.1:{server.server_port}')
        (job/'fetch.sh').write_text(script)
        subprocess.run(['sh',str(job/'fetch.sh')],check=True,timeout=45,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        server.shutdown();server.server_close();thread.join(timeout=2)
        rc=int((job/'done').read_text());body=(job/'payload').read_bytes();error=(job/'error').read_text()
        count+=1
        return rc,body,error,script
    rc,body,err,script=run('trusted','trusted')
    assert rc==0,(rc,err);assert body.endswith(b'WLT-CATALOG\t1\n')
    assert 'timeout 35' not in script and 'run_bounded openssl' in script
    print('PASS OpenSSL HTTPS succeeds with bundled trust without the timeout utility')
    rc,body,err,_=run('trusted','wrong');assert rc!=0 and b'WLT-CATALOG' not in body,(rc,err)
    print('PASS untrusted TLS certificate rejected before payload is accepted')
    rc,body,err,_=run('wrong','wrong');assert rc!=0 and b'WLT-CATALOG' not in body,(rc,err)
    print('PASS trusted certificate for the wrong hostname is rejected')
    rc,body,err,_=run('trusted','trusted',404);assert rc==0 and b'404' in body
    response=d/'404.http';response.write_bytes(body)
    check=d/'check.lua';check.write_text("local T=dofile('updater/src/transport.lua')({},{});local f=assert(io.open(arg[1],'rb'));assert(not pcall(T.response,f:read('*a'),262144))")
    subprocess.run([LUA,str(check),str(response)],cwd=ROOT,check=True)
    print('PASS HTTP 404 is reported as an endpoint error, never parsed as a catalog')
print(f'{count} real local TLS scenarios passed')
