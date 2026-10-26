"""Make labelled visual-bounds previews directly from the exported PNGs."""
from pathlib import Path
from PIL import Image,ImageChops,ImageDraw

ROOT=Path(__file__).resolve().parent
DEST=ROOT.parent.parent/'entities/rounded-v1'

def draw_visual_guide(draw,sprite,offset):
    box=sprite.getchannel('A').point(lambda a:255 if a>=16 else 0).getbbox()
    if box:
        x,y=offset
        draw.rectangle((x+box[0]-2,y+box[1]-2,x+box[2]+1,y+box[3]+1),outline='#e0bd65')

def write_previews():
    roles=['provider','requester']
    states=['idle','active']
    sheets={(r,s,k):Image.open(DEST/f'{r}_{k}_sheet_{s}.png').convert('RGBA') for r in roles for s in states for k in ['animation','emission']}
    shadows={r:Image.open(DEST/f'{r}_shadow.png').convert('RGBA').resize((240,160),Image.Resampling.LANCZOS) for r in roles}
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
            frame=frame.resize((120,160),Image.Resampling.LANCZOS)
            tile=Image.new('RGBA',(192,256),'#555e58')
            grid=ImageDraw.Draw(tile)
            for x in range(0,192,32):grid.line((x,0,x,256),fill='#647066')
            for y in range(12,256,32):grid.line((0,y,192,y),fill='#647066')
            tile.alpha_composite(shadows[role],(-24,60))
            tile.alpha_composite(frame,(36,60))
            draw_visual_guide(ImageDraw.Draw(tile),frame,(36,60))
            page.paste(tile.convert('RGB'),(col*192,0))
            labels.text((col*192+12,266),role.upper()+' / '+state.upper(),fill='#d9dcd8')
        labels.text((12,287),'Yellow: visible machine bounds. Shadows excluded. Offline PNG composition.',fill='#d9dcd8')
        previews.append(page)
    previews[0].save(ROOT/'native-sprite-preview.png')
    previews[0].save(ROOT/'animation-preview.gif',save_all=True,append_images=previews[1:],duration=30,loop=0,disposal=2)

if __name__=='__main__':write_previews()
