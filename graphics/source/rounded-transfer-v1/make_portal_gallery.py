"""Lay out labelled gallery images from render_gallery.py's unchanged model views.

uv run --with pillow python make_portal_gallery.py
These are rendered artwork previews, not captured gameplay.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image,ImageDraw,ImageFont
from preview_sprites import sprite_params

ROOT=Path(__file__).resolve().parent
RAW=ROOT/'raw/gallery'
OUT=ROOT/'portal-gallery'
OUT.mkdir(exist_ok=True)
VERSION=json.loads((ROOT.parents[2]/'info.json').read_text())['version']
PROTOTYPES=(ROOT.parents[2]/'data.lua').read_text()
RENDERS=json.loads((RAW/'renders.json').read_text())
assert RENDERS['source_sha256']==hashlib.sha256((ROOT/'rounded-transfer-v1.blend').read_bytes()).hexdigest(),'Render the current model before composing the gallery'
FONT=Path('/System/Library/Fonts/Supplemental')
REGULAR=FONT/'Arial.ttf'
BOLD=FONT/'Arial Bold.ttf'
INK='#edf0e9'
MUTED='#a7b3b0'
ACCENT={'provider':'#e3835c','requester':'#b5cc73'}

def text(draw,position,value,size,fill=INK,bold=False,anchor=None):
    draw.text(position,value,font=ImageFont.truetype(str(BOLD if bold else REGULAR),size),fill=fill,anchor=anchor)

shadows={}
for role in ['provider','requester']:
    cast=Image.open(RAW/f'{role}-shadow.png').getchannel('A')
    clear=Image.open(RAW/f'{role}-shadow-clear.png').getchannel('A')
    coverage=Image.new('L',cast.size)
    coverage.putdata([0 if a-b<=1 or b==255 else round((a-b)*255/(255-b)*.55) for a,b in zip(cast.tobytes(),clear.tobytes())])
    shadow=Image.new('RGBA',cast.size)
    shadow.putalpha(coverage)
    shadows[role]=shadow

def machine(page,role,state,center):
    # Raw gallery renders are four times the exported sprite resolution.
    # Use the current prototype scale and shift, including shadow registration.
    zoom=5.2
    body=Image.open(RAW/f'{role}-{state}.png').convert('RGBA')
    for name,layer in [(role+'_shadow.png',shadows[role]),(role+'_animation_sheet_'+state+'.png',body)]:
        scale,shift=sprite_params(name,PROTOTYPES)
        factor=scale/4*zoom
        size=tuple(round(n*factor) for n in layer.size)
        layer=layer.resize(size,Image.Resampling.LANCZOS)
        page.alpha_composite(layer,(round(center[0]-size[0]/2+shift[0]*zoom),round(center[1]-size[1]/2+shift[1]*zoom)))

def poster(filename,title,subtitle,entries):
    page=Image.new('RGBA',(1600,1000),'#242c30')
    draw=ImageDraw.Draw(page)
    # A restrained neutral grid supplies a common floor without fake gameplay.
    for x in range(68,1600,166):draw.line((x,228,x,916),fill='#2e393d')
    for y in range(250,916,166):draw.line((64,y,1536,y),fill='#2e393d')
    draw.line((800,260,800,874),fill='#445052',width=1)
    text(draw,(80,58),title,62,bold=True)
    text(draw,(84,143),subtitle,28,fill=MUTED)
    for index,(role,state,label) in enumerate(entries):
        cx=400+index*800
        machine(page,role,state,(cx,528))
        draw=ImageDraw.Draw(page)
        draw.rounded_rectangle((cx-28,801,cx+28,806),radius=2,fill=ACCENT[role])
        text(draw,(cx,833),label,31,fill=ACCENT[role],bold=True,anchor='mt')
    draw.line((80,916,1520,916),fill='#4b5758')
    text(draw,(80,945),'RENDERED ARTWORK PREVIEW',20,fill=MUTED,bold=True)
    text(draw,(1520,945),'ILN '+VERSION+'  /  NOT AN IN-GAME CAPTURE',20,fill=MUTED,anchor='rt')
    page.convert('RGB').save(OUT/filename,optimize=True)

poster('01-machines.png','Interplanetary Logistics Network','Provider and requester machines',[
    ('provider','idle','PROVIDER  /  TX'),('requester','idle','REQUESTER  /  RX')])
poster('02-provider.png','Interplanetary Provider','Idle and active transfer states',[
    ('provider','idle','IDLE'),('provider','active','ACTIVE  /  SENDING')])
poster('03-requester.png','Interplanetary Requester','Idle and active transfer states',[
    ('requester','idle','IDLE'),('requester','active','ACTIVE  /  RECEIVING')])
manifest={'version':VERSION,'provenance':'Blender renders of the existing model with the existing sprite cameras and proportions. Only output resolution was increased. No model saved and no Factorio process started.','render_source':RENDERS,'images':{p.name:{'sha1':hashlib.sha1(p.read_bytes()).hexdigest(),'size':list(Image.open(p).size)} for p in sorted(OUT.glob('*.png'))}}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps({'output':str(OUT),'images':manifest['images']},indent=2))
