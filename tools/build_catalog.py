#!/usr/bin/env python3
"""Build the public catalog, immutable payloads and static GitHub Pages site.

Usage: python3 tools/build_catalog.py [--add /path/to/Plugin_vX.Y.Z.zip ...]
All input archives remain byte-for-byte unchanged in releases/.
"""
import argparse, base64, hashlib, html, json, re, shutil, zipfile
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
OWNER, REPO = 'tmoose95', 'WadeLightingTools'
RAW = f'https://raw.githubusercontent.com/{OWNER}/{REPO}/main/'
REGISTRY = ROOT / 'registry.json'
VERSION = '1.1.3'
UPDATER_NAME = 'WLT Plugin Updator'
UPDATER_FOLDER = UPDATER_NAME

def sha(data): return hashlib.sha256(data).hexdigest()
def version(s):
    assert re.fullmatch(r'\d+\.\d+\.\d+(?:\.\d+)?', s), f'Invalid version: {s}'
    return tuple(map(int, s.split('.'))) + (0,) * (4 - len(s.split('.')))
def safe_path(s):
    return (re.fullmatch(r'[A-Za-z0-9_./ -]+', s) and not s.startswith('/') and
            all(x not in ('', '.', '..') and x==x.strip() for x in s.split('/')))
def metadata(z):
    found = []
    for name in z.namelist():
        if name.endswith('.xml'):
            root = ET.fromstring(z.read(name))
            for user in root.iter('UserPlugin'):
                found.append((name, user, root))
    assert len(found) == 1, 'An archive must contain exactly one plugin XML'
    return found[0]
def register(path, rows):
    with zipfile.ZipFile(path) as z:
        name, user, root = metadata(z)
        p = user.attrib
        assert 'aaron wade' in p.get('Author', '').lower(), f'Unrecognized author: {p.get("Author")}'
        folder = p['Path'].lstrip('/')
        assert safe_path(folder) and '/' not in folder
        identifier = folder.split('_v')[0].replace('_', '')
        if folder == 'Cue_Beacon_v1.0.0': identifier = 'CueBeacon'
        if folder in ('WadePluginUpdater', UPDATER_FOLDER): identifier = 'WadePluginUpdater'
        existing = next((r for r in rows if r['id'] == identifier), None)
        if existing:
            assert version(p['Version']) >= version(existing['version']), 'Cannot replace catalog with an older release'
            rows.remove(existing)
        entry = dict(id=identifier, name=p['Name'], version=p['Version'], folder=folder,
                     archive=path.name, minimum='2.5.1.0', note=p.get('Note', ''))
        rows.append(entry)
    target = ROOT / 'releases' / path.name
    if path.resolve() != target.resolve():
        if target.exists(): assert target.read_bytes() == path.read_bytes(), 'A release filename is immutable'
        else: shutil.copyfile(path, target)

def payload(entry):
    archive = ROOT / 'releases' / entry['archive']
    with zipfile.ZipFile(archive) as z:
        xmlpath, user, root = metadata(z)
        prefix = xmlpath.rsplit('/', 1)[0] + '/'
        assert prefix.rstrip('/') == entry['folder'], 'Plugin XML must be in its stable folder'
        files = {}
        for name in z.namelist():
            if name.endswith('/') or name.startswith('__MACOSX/'): continue
            assert name.startswith(prefix), f'File outside plugin folder: {name}'
            relative = name[len(prefix):]
            assert safe_path(relative), f'Unsafe archive filename: {relative}'
            assert z.getinfo(name).file_size <= 33554432
            files[relative] = z.read(name)
        for component in user.findall('ComponentLua'):
            if component.get('FileName'): assert component.get('FileName') in files, 'Missing Lua component'
        xml = xmlpath[len(prefix):]
        dest = ROOT / 'packages' / entry['id'] / entry['version'] / entry['folder']
        dest.mkdir(parents=True, exist_ok=True)
        lines = ['\t'.join(['WLT-RELEASE', '1', entry['id'], entry['version'], entry['folder'], xml])]
        for name, content in sorted(files.items()):
            file = dest / name; file.parent.mkdir(parents=True, exist_ok=True)
            if file.exists(): assert file.read_bytes() == content, f'Release payload changed: {file}'
            else: file.write_bytes(content)
            lines.append('\t'.join(['FILE', name, file.relative_to(ROOT).as_posix(), str(len(content)), sha(content)]))
        raw = archive.read_bytes()
        lines.append('\t'.join(['ZIP', archive.name, archive.relative_to(ROOT).as_posix(), str(len(raw)), sha(raw)]))
        manifest = '\n'.join(lines) + '\n'
        path = dest.parent / 'manifest.tsv'
        if path.exists(): assert path.read_text() == manifest, 'An existing release manifest cannot be changed'
        else: path.write_text(manifest)
        entry.update(manifest=path.relative_to(ROOT).as_posix(), digest=sha(manifest.encode()), xml=xml,
                     bytes=len(raw), zip_sha256=sha(raw))
        images = list(user.iter('UserImage'))
        if images:
            image = images[0]; chunks = image.findall('./FileContent/Block')
            if chunks:
                png = b''.join(base64.b64decode(b.attrib['Base64']) for b in chunks)
                if png.startswith(b'\x89PNG'):
                    (ROOT / 'docs/assets' / (entry['id'] + '.png')).write_bytes(png)
                    entry['image'] = entry['id'] + '.png'
    return entry

def catalog(rows):
    return 'WLT-CATALOG\t1\n' + ''.join('\t'.join(['PLUGIN',r['id'],r['name'],r['version'],r['minimum'],r['folder'],r['manifest'],r['digest']])+'\n' for r in rows)

def updater(bootstrap):
    source = ROOT / 'updater/src'
    preamble = '''-- WLT Plugin Updator v1.1.3 | Aaron Wade - Crossfade Design | grandMA3 2.5.1
local _,_,signalTable,myHandle=...
local function safe(fn,fallback) local ok,v=pcall(fn);if ok then return v end;return fallback end
local function button(parent,column,row,name,text,clicked,color)
 local b=parent:Append('Button');b.Name=name;b.Text=text;b.Anchors={left=column,right=column,top=row,bottom=row}
 b.Margin={left=3,right=3,top=3,bottom=3};b.Font='Regular16';b.TextalignmentH='Centre'
 b.PluginComponent=myHandle;b.Clicked=clicked;b.HasHover='Yes';if color then b.BackColor=color end;return b
end
'''
    content = preamble + "\nlocal TRUST_BUNDLE=[====[\n" + (ROOT/'updater/ca/cacert.pem').read_text() + "]====]\n"
    for module,filename in [('Core','core.lua'),('Transport','transport.lua'),('Runtime','runtime.lua')]:
        content += f'\nlocal {module}=(function()\n' + (source/filename).read_text() + '\nend)()\n'
    content += '\nlocal BOOTSTRAP=[====[\n' + bootstrap + ']====]\n'
    content += (source/'display.lua').read_text() + '\n' + (source/'main.lua').read_text()
    folder = ROOT/'updater'/UPDATER_FOLDER;folder.mkdir(exist_ok=True)
    (folder/(UPDATER_NAME+'.lua')).write_text(content)
    png=(ROOT/'docs/assets/WadePluginUpdater.png').read_bytes()
    root=ET.Element('GMA3',DataVersion='2.5.1.0')
    user=ET.SubElement(root,'UserPlugin',Index='1',Name=UPDATER_NAME,Path='/'+UPDATER_FOLDER,Version=VERSION,
        Author='Aaron Wade - Crossfade Design',Appearance=f'PluginUpdator_{VERSION.replace(chr(46), chr(95))}',
        Note='Three-tab updater with per-plugin actions, red/green version cells, all-DataPool destinations and console HTTPS with bundled Mozilla certificates. Utility Plugins.')
    dep=ET.SubElement(ET.SubElement(user,'DependencyExport',Size='1'),'Dependency',Address=f'ShowData.Appearances.PluginUpdator_{VERSION.replace(chr(46), chr(95))}')
    appearance=ET.SubElement(dep,'Appearance',Name=f'PluginUpdator_{VERSION.replace(chr(46), chr(95))}',MediaFileName='CUSTOM/'+UPDATER_NAME+'.png',
        BackR='0',BackG='0',BackB='0',BackAlpha='255',Color='1.0000000000,1.0000000000,1.0000000000,1.0000000000')
    idep=ET.SubElement(ET.SubElement(appearance,'DependencyExport',Size='1'),'Dependency',Address=f'ShowData.MediaPools.Images.PluginUpdator_{VERSION.replace(chr(46), chr(95))}')
    image=ET.SubElement(idep,'UserImage',Name=f'PluginUpdator_{VERSION.replace(chr(46), chr(95))}',AddAlpha='No',FileNAme=UPDATER_NAME+'.png')
    chunks=[png[i:i+1024] for i in range(0,len(png),1024)]
    fc=ET.SubElement(image,'FileContent',Size=str(len(chunks)))
    for chunk in chunks: ET.SubElement(fc,'Block',Base64=base64.b64encode(chunk).decode())
    ET.SubElement(user,'ComponentLua',Index='1',FileName=UPDATER_NAME+'.lua',Name='Main')
    ET.indent(root);ET.ElementTree(root).write(folder/f'{UPDATER_NAME}_v{VERSION}.xml',encoding='UTF-8',xml_declaration=True)
    (folder/(UPDATER_NAME+'.png')).write_bytes(png)
    shutil.copyfile(ROOT/'updater/README.txt',folder/'README.txt')
    shutil.copyfile(ROOT/'updater/ca/LICENSE',folder/'CA-LICENSE.txt')
    output=ROOT/'releases'/f'{UPDATER_NAME}_v{VERSION}.zip'
    with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED) as z:
        for name in [UPDATER_NAME+'.lua', UPDATER_NAME+'.png', 'README.txt', 'CA-LICENSE.txt', f'{UPDATER_NAME}_v{VERSION}.xml']:
            z.write(folder/name, f'{UPDATER_FOLDER}/{name}')
    return output

def page(title, body, depth=0):
    pre='../'*depth
    return f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(title)} · WadeLightingTools</title><meta name="description" content="grandMA3 plugins by Aaron Wade. Plugin downloads, installation instructions and release information.">
<link rel="icon" href="{pre}assets/mark.svg" type="image/svg+xml"><link rel="stylesheet" href="{pre}assets/site.css"></head><body>
<header><a class="brand" href="{pre}index.html"><img src="{pre}assets/mark.svg" alt=""><span>WADE<span class="muted">LIGHTING</span>TOOLS</span></a><nav><a href="{pre}index.html#plugins">Plugins</a><a href="{pre}WadePluginUpdater/">Updater</a><a href="https://github.com/{OWNER}/{REPO}">GitHub ↗</a></nav></header>
{body}<footer><span>WadeLightingTools · Aaron Wade</span><span>Independent tools for grandMA3. Not affiliated with MA Lighting or MATools.</span></footer></body></html>''' + '\n'

def website(rows):
    docs=ROOT/'docs';(docs/'downloads').mkdir(exist_ok=True)
    cards=[]
    for p in rows:
        shutil.copyfile(ROOT/'releases'/p['archive'],docs/'downloads'/p['archive'])
        image_url = p.get("image", "") + ("?v=" + p["version"] if p["id"] == "WadePluginUpdater" else "")
        icon=f'<img src="assets/{image_url}" alt="">' if p.get('image') else '<span class="fallback">'+html.escape(p['name'][:2].upper())+'</span>'
        cards.append(f'''<a class="plugin" href="{p['id']}/"><div class="plugin-top">{icon}<span class="revision">v{p['version']}</span></div><h3>{html.escape(p['name'])}</h3><p>{html.escape(p['summary'])}</p><span class="arrow">View plugin <span>↗</span></span></a>''')
        body=f'''<main><a class="back" href="../index.html#plugins">← All plugins</a><section class="plugin-hero"><div><p class="eyebrow">WADE LIGHTING TOOLS / GRANDMA3</p><h1>{html.escape(p['name'])}</h1><p class="lede">{html.escape(p['summary'])}</p><div class="meta"><span>Version {p['version']}</span><span>Catalog target: MA3 {p['minimum']}</span></div><a class="primary" href="../downloads/{p['archive']}" download>Download ZIP <span>↓</span></a></div><div class="icon-stage">{('<img src="../assets/'+image_url+'" alt="'+html.escape(p['name'])+' icon">') if p.get('image') else '<span>'+html.escape(p['name'])+'</span>'}</div></section>
<section class="detail-grid"><article><p class="eyebrow">01 / INSTALL</p><h2>From download to pool.</h2><ol><li>Extract <strong>{p['archive']}</strong>.</li><li>Copy <strong>{p['folder']}</strong> into your drive’s <code>grandMA3/gma3_library/datapools/plugins/</code> folder.</li><li>Edit a plugin pool slot, choose Import, then select <strong>{p['xml']}</strong>.</li><li>Close the editor and run the plugin.</li></ol><p class="note">The archive includes the release’s original metadata and assets. Follow the included README for plugin-specific instructions.</p></article><article><p class="eyebrow">02 / RELEASE</p><h2>About this revision.</h2><p>{html.escape(p['note'])}</p><dl><dt>Package</dt><dd>{p['archive']}</dd><dt>Size</dt><dd>{p['bytes']:,} bytes</dd><dt>SHA-256</dt><dd class="hash">{p['zip_sha256']}</dd></dl><p class="note">These are the latest available project packages. The updater does not certify every plugin on every console configuration.</p></article></section></main>'''
        if p['id']=='WadePluginUpdater':
            body=body.replace('</main>', '''<section class="workflow"><p class="eyebrow">THE UPDATE WORKFLOW</p><h2>Scan. Compare. Update.</h2><div class="steps"><article><b>01</b><h3>Scan connected drives</h3><p>Only current internal and connected USB plugin libraries are scanned. With no USB attached, the scan stays internal. Old software drives are skipped.</p></article><article><b>02</b><h3>Choose your updates</h3><p>Showfile, USB Drives and More Plugins tabs. Green versions match the live catalog; red versions differ. Unknown versions stay grey.</p></article><article><b>03</b><h3>Choose how to install</h3><p>Choose Import Online, Download to Drives or Import from Drive for each plugin. Review the queued actions and target DataPools before applying.</p></article></div><p class="note">Version 1.1.3 adds a QR Code button for each uninstalled plugin under More Plugins, linking to its own page. It also corrects the shared show-pool import step for online and drive sources using self-contained XML, while retaining Lua readback verification and efficient plugin-only scanning. Console HTTPS includes a Mozilla certificate bundle. Connection Details reports the actual error if catalog access fails. The updater has automated test coverage; native console import, touch and transport behavior still require on-console testing.</p></section></main>''')
        directory=docs/p['id'];directory.mkdir(exist_ok=True);(directory/'index.html').write_text(page(p['name'],body,1))
    body=f'''<main><section class="hero"><div><p class="eyebrow"><span class="dot"></span> TOOLS FOR THE PROGRAMMER</p><h1>Less setup.<br><span>More show.</span></h1><p class="lede">A growing collection of grandMA3 plugins by Aaron Wade. Find the current revision, download it, and get back to programming.</p><div class="actions"><a class="primary" href="#plugins">Explore plugins <span>↓</span></a><a class="secondary" href="WadePluginUpdater/">Get the updater ↗</a></div></div><div class="console-art" aria-hidden="true"><div class="art-label">WADE / LIGHTING TOOLS <span>01 — {len(rows):02d}</span></div><div class="art-screen"><span>WLT</span><i></i><i></i><i></i><i></i></div><div class="art-faders"><i></i><i></i><i></i><i></i><i></i><i></i></div><div class="art-foot">BUILT AROUND YOUR WORKFLOW</div></div></section>
<section id="plugins"><div class="section-head"><div><p class="eyebrow">THE COLLECTION</p><h2>Your tools. One place.</h2></div><p>{len(rows)} plugins · Versioned downloads</p></div><div class="catalog">{''.join(cards)}</div></section>
<section class="updater-banner"><div><p class="eyebrow">WLT PLUGIN UPDATOR</p><h2>Keep your toolkit current.</h2><p>Scan connected drives, compare versions, and update selected plugins from one window.</p></div><a class="primary" href="WadePluginUpdater/">Meet the updater ↗</a></section></main>'''
    (docs/'index.html').write_text(page('grandMA3 plugins',body));(docs/'.nojekyll').touch()
    (docs/'catalog.json').write_text(json.dumps(rows,indent=2)+'\n')

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--add',nargs='*',default=[]);parser.add_argument('--rebuild-updater',action='store_true');args=parser.parse_args()
    rows=json.loads(REGISTRY.read_text()) if REGISTRY.exists() else []
    for path in args.add: register(Path(path),rows)
    rows.sort(key=lambda x:x['name'].lower())
    # Build only non-updater manifest hashes into its bootstrap: avoids self-hashing recursion.
    others=[payload(dict(r)) for r in rows if r['id']!='WadePluginUpdater']
    if args.rebuild_updater or not any(r['id']=='WadePluginUpdater' for r in rows):
        zip_path=updater(catalog(others))
        register(zip_path,rows)
    summary=json.loads((ROOT/'summaries.json').read_text())
    built=[payload(dict(r)) for r in sorted(rows,key=lambda x:x['name'].lower())]
    for r in built:r['summary']=summary.get(r['id'],r['note'].split('.')[0]+'.')
    (ROOT/'catalog.tsv').write_text(catalog(built));REGISTRY.write_text(json.dumps(built,indent=2)+'\n')
    website(built)
    print(f'Built {len(built)} plugin pages and validated release payloads.')
if __name__=='__main__':main()
