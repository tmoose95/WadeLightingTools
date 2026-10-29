"""Independently decode staged MA XML for every current catalog payload.

Uses Python's XML/base64 implementations to avoid validating the Lua encoder
with only its own decoder. Does not execute any plugin or simulate the MA UI.
"""
import base64
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
LUA = os.environ.get('WLT_LUA55') or shutil.which('lua5.5') or shutil.which('lua')
ROWS = json.loads((ROOT / 'registry.json').read_text())

def codes(plugin, folder):
    result = []
    for component in plugin.findall('ComponentLua'):
        content = component.find('FileContent')
        if content is None:
            result.append((folder / component.attrib['FileName']).read_bytes())
        else:
            parts = [base64.b64decode(b.attrib['Base64'], validate=True) for b in content]
            assert len(parts) == int(content.attrib['Size'])
            result.append(b''.join(parts))
    return result

with tempfile.TemporaryDirectory(prefix='wlt-embedded-') as name:
    directory = Path(name)
    helper = directory / 'stage.lua'
    helper.write_text('''local C=dofile('updater/src/core.lua')
local function read(p)local f=assert(io.open(p,'rb'));local s=f:read('*a');f:close();return s end
local xml=C.embeddedPlugin(read(arg[1]),function(f)return read(arg[2]..'/'..f)end)
local out=assert(io.open(arg[3],'wb'));assert(out:write(xml));assert(out:close())
''')
    for row in ROWS:
        folder = ROOT / 'packages' / row['id'] / row['version'] / row['folder']
        source = folder / row['xml']
        destination = directory / (row['id'] + '.xml')
        subprocess.run([LUA, str(helper), str(source), str(folder), str(destination)], cwd=ROOT, check=True)
        before = ET.parse(source).find('UserPlugin')
        after = ET.parse(destination).find('UserPlugin')
        assert after.attrib == {k: v for k, v in before.attrib.items() if k != 'Index'}
        assert codes(before, folder) == codes(after, directory), row['id']
        original_dependencies = before.find('DependencyExport')
        staged_dependencies = after.find('DependencyExport')
        if original_dependencies is not None:
            assert ET.tostring(original_dependencies) == ET.tostring(staged_dependencies)
        for index, component in enumerate(after.findall('ComponentLua'), 1):
            assert component.get('FileName') == '' and component.get('Installed') == 'No'
            assert component.get('Index') == str(index)
            parts = [base64.b64decode(b.attrib['Base64'], validate=True) for b in component.find('FileContent')]
            assert all(len(part) == 1024 for part in parts[:-1]) and 0 < len(parts[-1]) <= 1024
        print('PASS independent embedded XML/code/image fidelity: ' + row['id'])
print(str(len(ROWS)) + ' catalog payloads checked independently (not native MA imports)')
