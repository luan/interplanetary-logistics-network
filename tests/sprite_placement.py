"""Check actual exported machine pixels against the fixed placement rectangle."""
from pathlib import Path
import sys
import unittest
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'graphics/source/rounded-transfer-v1'))
from preview_sprites import footprint,sprite_params

class SpritePlacement(unittest.TestCase):
    def test_visible_machine_is_vertically_inside_rectangle(self):
        text=(ROOT/'data.lua').read_text()
        for role in ['provider','requester']:
            for state in ['idle','active']:
                with self.subTest(role=role,state=state):
                    name=f'{role}_animation_sheet_{state}.png'
                    scale,shift=sprite_params(name,text)
                    alpha=Image.open(ROOT/'graphics/entities/rounded-v1'/name).getchannel('A')
                    boxes=[]
                    for frame in range(64):
                        x,y=frame%8*192,frame//8*256
                        boxes.append(alpha.crop((x,y,x+192,y+256)).point(lambda a:255 if a>=16 else 0).getbbox())
                    top=(min(b[1] for b in boxes)-128)*scale+shift[1]
                    bottom=(max(b[3] for b in boxes)-128)*scale+shift[1]
                    _,north,_,south=footprint(role,text)
                    self.assertGreaterEqual(top,north,f'{role} {state}: artwork is {north-top:.2f}px north of the rectangle')
                    self.assertLessEqual(bottom,south,f'{role} {state}: artwork extends south of the rectangle')
                    self.assertLessEqual(abs((top+bottom)/2),3,'Visible machine must be vertically centered within 3px')

if __name__=='__main__':unittest.main()
