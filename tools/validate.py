#!/usr/bin/env python3
"""Offline release, website-link and Lua source validation; no MA hardware actions."""
import base64, hashlib, json, os, re, shutil, subprocess, tempfile, zipfile
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import urlsplit, unquote
import xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
rows=json.loads((ROOT/'registry.json').read_text())
class Links(HTMLParser):
    def __init__(self):super().__init__();self.refs=[]
    def handle_starttag(self,tag,attrs):
        for k,v in attrs:
            if k in ('href','src') and v:self.refs.append(v)
count=0
for page in (ROOT/'docs').rglob('*.html'):
    parser=Links();parser.feed(page.read_text())
    archives=[u for u in parser.refs if urlsplit(u).path.lower().endswith('.zip')]
    assert not archives or page.parent.name=='WadePluginUpdater', 'Paid plugin page exposes a direct download'
    for ref in parser.refs:
        parsed=urlsplit(ref)
        if parsed.scheme or not parsed.path:continue
        file=(page.parent/unquote(parsed.path)).resolve()
        if file.is_dir():file=file/'index.html'
        assert file.is_file(),f'Broken page link {page}: {ref}'
    count+=1
for row in rows:
    archive=ROOT/'releases'/row['archive'];raw=archive.read_bytes()
    assert hashlib.sha256(raw).hexdigest()==row['zip_sha256']
    assert raw==(ROOT/'docs/downloads'/row['archive']).read_bytes()
    assert (ROOT/'docs'/row['id']/'index.html').is_file()
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
        for name in z.namelist():
            if name.endswith('.xml'):
                xml=ET.fromstring(z.read(name))
                for plugin in xml.iter('UserPlugin'):
                    assert plugin.get('Version')==row['version']
                    for comp in plugin.findall('ComponentLua'):
                        if comp.get('FileName'):
                            assert name.rsplit('/',1)[0]+'/'+comp.get('FileName') in z.namelist()
    manifest=(ROOT/row['manifest']).read_bytes()
    assert hashlib.sha256(manifest).hexdigest()==row['digest']
    for line in manifest.decode().splitlines()[1:]:
        kind,name,path,size,digest=line.split('\t');data=(ROOT/path).read_bytes()
        assert len(data)==int(size) and hashlib.sha256(data).hexdigest()==digest,path
up=next(r for r in rows if r['id']=='WadePluginUpdater')
with zipfile.ZipFile(ROOT/'releases'/up['archive']) as z:
    xml=ET.fromstring(z.read(up['folder']+'/'+up['xml']))
    plugin=xml.find('UserPlugin');assert 'Tags' not in plugin.attrib
    appearance=next(xml.iter('Appearance'));assert len(appearance.get('Color').split(','))==4
    image=next(xml.iter('UserImage'));fc=image.find('FileContent');blocks=[base64.b64decode(b.get('Base64')) for b in fc]
    assert len(blocks)==int(fc.get('Size')) and all(len(b)==1024 for b in blocks[:-1])
    png=b''.join(blocks);assert png==z.read(up['folder']+'/'+up['name']+'.png')
    assert int.from_bytes(png[16:20],'big')==300 and int.from_bytes(png[20:24],'big')==300
    assert png[25]==2,'Pool image must be RGB'
print(f'Validated {len(rows)} archives, release manifests, embedded updater image, and {count} website pages.')
lua=os.environ.get('WLT_LUA55') or shutil.which('lua5.5') or shutil.which('lua')
if not lua:raise SystemExit('Lua 5.5 is required. Set WLT_LUA55 to the Lua 5.5 executable.')
subprocess.run([lua,'-e','assert(_VERSION == "Lua 5.5", "MA3 2.5 validation requires Lua 5.5")'],check=True)
with tempfile.TemporaryDirectory(prefix='wlt-compile-') as directory:
    with zipfile.ZipFile(ROOT/'releases'/up['archive']) as z:
        main=z.read(up['folder']+'/'+up['name']+'.lua')
    assert b':Import(' not in main and b'Worker.run(' not in main and b'LuaFile ' not in main, 'Containment build includes an import/continuation route'
    assert b'SystemMonitorWindow' not in main, 'Unverified native monitor must not be embedded in updater popups'
    release=Path(directory)/'release.lua';release.write_bytes(main)
    for scenario in ('normal','missing-type','empty-type','missing-root'):
        subprocess.run([lua,'tests/release_startup.lua',str(release),scenario,up['version']],cwd=ROOT,check=True)
for test in ('tests/core.lua','tests/runtime.lua','tests/updater_ui.lua','tests/hippo_remote.lua','tests/transport_progress.lua'):
    subprocess.run([lua,test],cwd=ROOT,check=True)

subprocess.run(['python3','tests/embedded_payloads.py'],cwd=ROOT,check=True)
subprocess.run(['python3','tests/transport.py'],cwd=ROOT,check=True)
