"""Compare shipped 0.4.5 and current PNG placement without starting Factorio.

Run with uv run --with pillow python preview_grounding.py.
Uses actual sprite scale/shift from each revision's data.lua, not Blender's
presentation camera. Yellow guides show the actual fixed placement footprint.
"""
from pathlib import Path
from io import BytesIO
import subprocess
from PIL import Image, ImageChops, ImageDraw
from preview_sprites import draw_footprint,sprite_params

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent

def read(path,before):
    if before:return subprocess.check_output(['git','show','v0.4.5:'+path],cwd=ROOT)
    return (ROOT/path).read_bytes()

def image(path,before):
    return Image.open(BytesIO(read(path,before))).convert('RGBA')

def params(filename,before):
    return sprite_params(filename,read('data.lua',before).decode())

def composite(role,before):
    tile=Image.new('RGBA',(320,256),'#555e58')
    draw=ImageDraw.Draw(tile)
    cx,cy=148,135
    for x in range((cx-48)%32,320,32):draw.line((x,0,x,256),fill='#647066')
    for y in range((cy-48)%32,256,32):draw.line((0,y,320,y),fill='#647066')
    prefix='graphics/entities/rounded-v1/'+role
    body=image(prefix+'_animation_sheet_idle.png',before).crop((0,0,192,256))
    emission=image(prefix+'_emission_sheet_idle.png',before).crop((0,0,192,256))
    combined=ImageChops.add(body.convert('RGB'),emission.convert('RGB'))
    combined.putalpha(body.getchannel('A'))
    shadow=image(prefix+'_shadow.png',before)
    for filename,layer in [(role+'_shadow.png',shadow),(role+'_animation_sheet_idle.png',combined)]:
        scale,shift=params(filename,before)
        size=tuple(round(n*scale) for n in layer.size)
        layer=layer.resize(size,Image.Resampling.LANCZOS)
        offset=(round(cx-size[0]/2+shift[0]),round(cy-size[1]/2+shift[1]))
        tile.alpha_composite(layer,offset)
    draw_footprint(ImageDraw.Draw(tile),role,read('data.lua',before).decode(),(cx,cy))
    ImageDraw.Draw(tile).text((12,12),role.upper()+(' / 0.4.5' if before else ' / RESTORED'),fill='white')
    return tile.convert('RGB')

if __name__=='__main__':
    page=Image.new('RGB',(640,540),'#343c3c')
    for row,role in enumerate(['provider','requester']):
        for col,before in enumerate([True,False]):page.paste(composite(role,before),(col*320,row*256))
    ImageDraw.Draw(page).text((12,521),'Yellow: fixed 3 x 3 tile footprint and placement origin. Offline PNG composition.',fill='#eeeeee')
    page.save(OUT/'grounding-preview.png')
    print(OUT/'grounding-preview.png')
