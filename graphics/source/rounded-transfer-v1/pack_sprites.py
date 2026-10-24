"""Pack Blender's RGBA renders into ILN's existing Factorio sprite contract.

Run with: uv run --with pillow python pack_sprites.py
Pillow only packs, downsamples, and makes review previews; Blender supplies all art.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageChops, ImageFilter, ImageDraw

ROOT=Path(__file__).resolve().parent
DEST=ROOT.parent.parent/'entities'/'rounded-v1'
DEST.mkdir(exist_ok=True)
CELL=(192,256)
reports={}
all_frames={}

def raw(role,kind,frame):
    folder=ROOT/'raw'/role
    matches=list(folder.glob(f'{kind}-*Image{frame:04d}.png'))
    if not matches:raise RuntimeError(f'Missing {role} {kind} frame {frame}')
    # A complete animation supersedes the earlier two-frame export preflight.
    return Image.open(max(matches,key=lambda p:p.stat().st_mtime_ns)).convert('RGBA')

for role in ['provider','requester']:
    combined=[Image.open(ROOT/'raw'/role/f'combined-{f:04d}.png').convert('RGBA') for f in range(1,129)]
    if any(im.size!=(384,512) for im in combined):raise RuntimeError('Unexpected render resolution')
    body=[]
    emission=[]
    boxes=[]
    for f,beauty in enumerate(combined,1):
        alpha=beauty.getchannel('A')
        b=raw(role,'body',f)
        # Restore straight coverage also for the initial Blender Set Alpha preflight.
        # Direct emission was subtracted in linear space inside Blender.
        b.putalpha(alpha)
        e=raw(role,'emission',f)
        e.putalpha(alpha)
        b=b.resize(CELL,Image.Resampling.LANCZOS)
        e=e.resize(CELL,Image.Resampling.LANCZOS)
        bbox=beauty.resize(CELL,Image.Resampling.LANCZOS).getbbox()
        if not bbox or bbox[0]<2 or bbox[1]<2 or bbox[2]>190 or bbox[3]>254:
            raise RuntimeError(f'Clipping or empty frame: {role} {f}: {bbox}')
        boxes.append(bbox)
        body.append(b)
        emission.append(e)
    for state,offset in [('idle',0),('active',64)]:
        for kind,frames in [('animation',body),('emission',emission)]:
            sheet=Image.new('RGBA',(1536,2048))
            for i in range(64):sheet.paste(frames[offset+i],((i%8)*192,(i//8)*256))
            sheet.save(DEST/f'{role}_{kind}_sheet_{state}.png',optimize=True)
    # Inventory presentation uses the actual idle render with a centered crop.
    first=combined[0]
    crop=first.crop(first.getbbox())
    crop.thumbnail((236,236),Image.Resampling.LANCZOS)
    icon=Image.new('RGBA',(256,256))
    icon.paste(crop,((256-crop.width)//2,(256-crop.height)//2))
    icon.save(DEST/f'{role}_idle_icon_big.png',optimize=True)
    icon.resize((64,64),Image.Resampling.LANCZOS).save(DEST/f'{role}_idle_icon.png',optimize=True)
    silhouette=Image.open(ROOT/'raw'/f'{role}-shadow.png').convert('RGBA').resize((384,256),Image.Resampling.LANCZOS)
    coverage=silhouette.getchannel('A').filter(ImageFilter.GaussianBlur(1.15)).point(lambda v:round(v*.38))
    shadow=Image.new('RGBA',(384,256))
    shadow.putalpha(coverage)
    shadow.save(DEST/f'{role}_shadow.png',optimize=True)
    all_frames[role]=[im.resize(CELL,Image.Resampling.LANCZOS) for im in combined]
    reports[role]={'frames':128,'unique_idle_frames':len({im.tobytes() for im in emission[:64]}),'unique_active_frames':len({im.tobytes() for im in emission[64:]}),'min_margin_px':min(min(a,b,192-c,256-d) for a,b,c,d in boxes),'body_bounds_union':[min(b[0] for b in boxes),min(b[1] for b in boxes),max(b[2] for b in boxes),max(b[3] for b in boxes)],'shadow_bbox':shadow.getbbox()}

labels=['PROVIDER / IDLE','PROVIDER / ACTIVE','REQUESTER / IDLE','REQUESTER / ACTIVE']
previews=[]
for f in range(64):
    page=Image.new('RGB',(768,288),'#252c34')
    draw=ImageDraw.Draw(page)
    for col,(role,offset) in enumerate([('provider',0),('provider',64),('requester',0),('requester',64)]):
        frame=all_frames[role][offset+f]
        page.paste(frame,(col*192,20),frame)
        draw.text((col*192+12,268),labels[col],fill='#d9dcd8')
    previews.append(page)
previews[0].save(ROOT/'native-sprite-preview.png')
previews[0].save(ROOT/'animation-preview.gif',save_all=True,append_images=previews[1:],duration=30,loop=0,disposal=2)
manifest={'blender_version':'5.2.3 LTS','source':'rounded-transfer-v1.blend','source_sha256':hashlib.sha256((ROOT/'rounded-transfer-v1.blend').read_bytes()).hexdigest(),'cell':[192,256],'grid':[8,8],'frames_per_state':64,'idle_animation_speed':.5,'active_animation_speed':1,'pixels_per_tile':51.2,'anchor':[96,156.9630937574],'factorio_scale':.625,'factorio_shift':[0,-.5656854249492381],'shadow_size':[384,256],'export_notes':'Blender-authored body with direct emission subtracted in linear space; separate additive emission; supersampled 2x and downsampled with alpha-aware Lanczos. Animation preview GIF is slowed for inspection. Not a captured in-game screenshot.','validation':reports,'files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(DEST.glob('*.png'))}}
(ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps({'files':len(manifest['files']),'output':str(DEST),'validation':reports},indent=2))
