"""Pack Blender's RGBA renders into ILN's existing Factorio sprite contract.

Run with: uv run --with pillow python pack_sprites.py
Pillow only packs, downsamples, and makes review previews; Blender supplies all art.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image
from preview_sprites import write_previews

ROOT=Path(__file__).resolve().parent
DEST=ROOT.parent.parent/'entities'/'rounded-v1'
DEST.mkdir(exist_ok=True)
CELL=(192,256)
reports={}

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
    silhouette=Image.open(ROOT/'raw'/f'{role}-shadow.png').getchannel('A')
    clear=Image.open(ROOT/'raw'/f'{role}-shadow-clear.png').getchannel('A')
    # Remove the receiver's unoccluded matte. A one-step PNG rounding difference
    # is transparent; native sun penumbra supplies softness at actual contacts.
    coverage=Image.new('L',silhouette.size)
    coverage.putdata([0 if a-b<=1 or b==255 else round((a-b)*255/(255-b)) for a,b in zip(silhouette.tobytes(),clear.tobytes())])
    coverage=coverage.resize((384,256),Image.Resampling.LANCZOS).point(lambda v:round(v*.55))
    shadow=Image.new('RGBA',(384,256))
    shadow.putalpha(coverage)
    box=shadow.getbbox()
    if not box or box[0]<2 or box[1]<2 or box[2]>382 or box[3]>254:raise RuntimeError(f'Clipped or empty shadow: {role}: {box}')
    shadow.save(DEST/f'{role}_shadow.png',optimize=True)
    reports[role]={'frames':128,'unique_idle_frames':len({im.tobytes() for im in emission[:64]}),'unique_active_frames':len({im.tobytes() for im in emission[64:]}),'min_margin_px':min(min(a,b,192-c,256-d) for a,b,c,d in boxes),'body_bounds_union':[min(b[0] for b in boxes),min(b[1] for b in boxes),max(b[2] for b in boxes),max(b[3] for b in boxes)],'shadow_bbox':shadow.getbbox()}

write_previews()
manifest={'blender_version':'5.2.3 LTS','source':'rounded-transfer-v1.blend','source_sha256':hashlib.sha256((ROOT/'rounded-transfer-v1.blend').read_bytes()).hexdigest(),'cell':[192,256],'grid':[8,8],'frames_per_state':64,'idle_animation_speed':.5,'active_animation_speed':1,'pixels_per_tile':51.2,'anchor':[96,128],'factorio_scale':.625,'factorio_shift':[0,0],'shadow_size':[384,256],'shadow_method':'Cycles shadow catcher with matching body sun, ground datum and pixel density','export_notes':'Blender-authored body with direct emission subtracted in linear space; separate additive emission; supersampled 2x and downsampled with alpha-aware Lanczos. Animation preview GIF is slowed for inspection. Not a captured in-game screenshot.','validation':reports,'files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(DEST.glob('*.png'))}}
manifest.update({
    'projection_check':'projection-check.json',
    'placement_footprint_tiles':[3,3],
    'visual_review':'Offline composition of exported body, emission and shadow PNGs at the prototype scale and shift. Yellow is the fixed selection footprint and entity origin, independent of visible sprite bounds. No Factorio process launched.',
})
(ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps({'files':len(manifest['files']),'output':str(DEST),'validation':reports},indent=2))
