"""Launch a graphical, isolated Factorio world and keep original screenshot files.

python3 tests/gallery/run.py /path/to/factorio
Uses the released ZIP in Downloads; never edits the packaged mod or player saves.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT=Path(__file__).resolve().parents[2]
binary=Path(sys.argv[1]).resolve()
data=next(p/'data' for p in binary.parents if (p/'data/server-settings.example.json').exists())
info=json.loads((ROOT/'info.json').read_text())
package=Path('/Users/luan/Downloads')/f"{info['name']}_{info['version']}.zip"
qa=Path(tempfile.mkdtemp(prefix='iln-game-gallery-',dir='/Users/luan/Library/Caches'))
mods=qa/'mods';mods.mkdir()
shutil.copy2(package,mods/package.name)
(mods/'mod-list.json').write_text(json.dumps({'mods':[{'name':n,'enabled':True} for n in ['base','quality','elevated-rails','recycler','space-age',info['name']]]}))
scenario=qa/'scenarios/iln-gallery';scenario.mkdir(parents=True)
shutil.copy2(Path(__file__).with_name('control.lua'),scenario/'control.lua')
config=qa/'config.ini'
config.write_text(f'[path]\nread-data={data}\nwrite-data={qa}\n[other]\ncheck-updates=false\nautosave-interval=0\n[graphics]\nfull-screen=false\n')
command=[str(binary),'--config',str(config),'--mod-directory',str(mods),'--load-scenario','iln-gallery','--window-size','1600x1000','--graphics-quality','high','--disable-audio','--nogamepad']
log=(qa/'launch.log').open('w')
process=subprocess.Popen(command,stdout=log,stderr=subprocess.STDOUT,env={**os.environ,'SteamAppId':'427520','SteamGameId':'427520'})
receipt={'qa':str(qa),'pid':process.pid,'binary':str(binary),'package':str(package),'package_sha1':hashlib.sha1(package.read_bytes()).hexdigest(),'command':command}
(qa/'launch.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt,indent=2),flush=True)
raise SystemExit(process.wait())
