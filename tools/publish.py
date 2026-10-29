#!/usr/bin/env python3
"""Publish this prepared directory using the owner's locally authenticated GitHub CLI."""
import json, shutil, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
REPO='tmoose95/WadeLightingTools'
def run(*args, **kw):
    return subprocess.run(args,cwd=ROOT,check=True,text=True,**kw)
if not shutil.which('gh'):
    raise SystemExit('Install GitHub CLI from https://cli.github.com/ and run gh auth login, then rerun this script.')
login=run('gh','api','user','--jq','.login',capture_output=True).stdout.strip()
if login!='tmoose95': raise SystemExit('Sign in to GitHub CLI as tmoose95 before publishing.')
run('python3','tools/validate.py')
if not (ROOT/'.git').exists():
    run('git','init','-b','main')
run('git','add','.')
changed=subprocess.run(['git','diff','--cached','--quiet'],cwd=ROOT).returncode
if changed: run('git','commit','-m','Publish WadeLightingTools plugin catalog and updater')
exists=subprocess.run(['gh','repo','view',REPO,'--json','name'],cwd=ROOT,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode==0
if not exists:
    run('gh','repo','create',REPO,'--public','--description','grandMA3 plugins and updater by Aaron Wade','--source','.','--remote','origin','--push')
else:
    remotes=run('git','remote',capture_output=True).stdout.split()
    if 'origin' not in remotes: run('git','remote','add','origin','https://github.com/'+REPO+'.git')
    origin=run('git','remote','get-url','origin',capture_output=True).stdout.strip()
    if origin not in ('https://github.com/'+REPO+'.git','git@github.com:'+REPO+'.git'):
        raise SystemExit('origin points elsewhere. Nothing was pushed.')
    run('git','push','-u','origin','main')  # Never force push.
payload=json.dumps({'source':{'branch':'main','path':'/docs'}})
page=subprocess.run(['gh','api','repos/'+REPO+'/pages'],cwd=ROOT,capture_output=True,text=True)
if page.returncode:
    run('gh','api','--method','POST','repos/'+REPO+'/pages','--input','-',input=payload)
else:
    run('gh','api','--method','PUT','repos/'+REPO+'/pages','--input','-',input=payload)
print('Repository published: https://github.com/'+REPO)
print('Pages configured: https://tmoose95.github.io/WadeLightingTools/ (initial deployment can take several minutes)')
