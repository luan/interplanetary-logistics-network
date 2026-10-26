"""Preview exported sprites against their fixed Factorio tile footprint."""
from pathlib import Path
import re
from PIL import Image,ImageChops,ImageDraw

ROOT=Path(__file__).resolve().parent
DEST=ROOT.parent.parent/'entities/rounded-v1'

def footprint(role,text):
    prototype=text.split(f'name = "interplanetary-{role}-chest",',1)[1]
    box=re.search(r'selection_box = \{ \{ ([^,]+), ([^}]+) \}, \{ ([^,]+), ([^}]+) \} \}',prototype)
    return tuple(float(v)*32 for v in box.groups())

def draw_footprint(draw,role,text,center):
    x,y=center
    x0,y0,x1,y1=footprint(role,text)
    draw.rectangle((x+x0,y+y0,x+x1,y+y1),outline='#e0bd65')
    draw.line((x-3,y,x+3,y),fill='#e0bd65')
    draw.line((x,y-3,x,y+3),fill='#e0bd65')

def sprite_params(filename,text):
    block=re.search(r'filename = "[^"]*/'+filename+r'",(.*?)(?=\n\s*},)',text,re.S)[1]
    scale=float(re.search(r'scale = ([\d.]+)',block)[1])
    shift=tuple(float(v)*32 for v in re.search(r'shift = \{\s*([^,]+),\s*([^}]+)\}',block).groups())
    return scale,shift

def write_previews():
    roles=['provider','requester']
    states=['idle','active']
    text=(ROOT.parents[2]/'data.lua').read_text()
    sheets={(r,s,k):Image.open(DEST/f'{r}_{k}_sheet_{s}.png').convert('RGBA') for r in roles for s in states for k in ['animation','emission']}
    shadows={r:Image.open(DEST/f'{r}_shadow.png').convert('RGBA') for r in roles}
    previews=[]
    for f in range(64):
        page=Image.new('RGB',(768,304),'#252c34')
        labels=ImageDraw.Draw(page)
        box=((f%8)*192,(f//8)*256,(f%8+1)*192,(f//8+1)*256)
        for col,(role,state) in enumerate((r,s) for r in roles for s in states):
            body=sheets[role,state,'animation'].crop(box)
            emission=sheets[role,state,'emission'].crop(box)
            frame=ImageChops.add(body.convert('RGB'),emission.convert('RGB'))
            frame.putalpha(body.getchannel('A'))
            tile=Image.new('RGBA',(192,256),'#555e58')
            grid=ImageDraw.Draw(tile)
            for x in range(16,192,32):grid.line((x,0,x,256),fill='#647066')
            for y in range(12,256,32):grid.line((0,y,192,y),fill='#647066')
            for filename,layer in [(role+'_shadow.png',shadows[role]),(role+'_animation_sheet_'+state+'.png',frame)]:
                scale,shift=sprite_params(filename,text)
                size=tuple(round(n*scale) for n in layer.size)
                layer=layer.resize(size,Image.Resampling.LANCZOS)
                tile.alpha_composite(layer,(round(96-size[0]/2+shift[0]),round(140-size[1]/2+shift[1])))
            draw_footprint(ImageDraw.Draw(tile),role,text,(96,140))
            page.paste(tile.convert('RGB'),(col*192,0))
            labels.text((col*192+12,266),role.upper()+' / '+state.upper(),fill='#d9dcd8')
        labels.text((12,287),'Yellow: fixed 3 x 3 tile footprint and placement origin. Offline PNG composition.',fill='#d9dcd8')
        previews.append(page)
    previews[0].save(ROOT/'native-sprite-preview.png')
    previews[0].save(ROOT/'animation-preview.gif',save_all=True,append_images=previews[1:],duration=30,loop=0,disposal=2)

if __name__=='__main__':write_previews()
