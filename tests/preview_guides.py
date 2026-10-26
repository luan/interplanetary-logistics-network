"""Verify the yellow preview guide frames the rendered machine, offline."""
from pathlib import Path
import sys
import unittest
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'graphics/source/rounded-transfer-v1'
sys.path.insert(0,str(SOURCE))
import preview_grounding as preview

class PreviewGuides(unittest.TestCase):
    def test_guides_enclose_visible_machine_without_empty_footprint_space(self):
        for role in ['provider','requester']:
            for before in [True,False]:
                with self.subTest(role=role,before=before):
                    tile=preview.composite(role,before)
                    yellow=[(x,y) for y in range(tile.height) for x in range(tile.width) if tile.getpixel((x,y))==(224,189,101)]
                    self.assertTrue(yellow,'Missing yellow visual-bounds guide')
                    actual=(min(x for x,y in yellow),min(y for x,y in yellow),max(x for x,y in yellow)+1,max(y for x,y in yellow)+1)
                    filename=role+'_animation_sheet_idle.png'
                    sprite=preview.image('graphics/entities/rounded-v1/'+filename,before).crop((0,0,192,256))
                    scale,shift=preview.params(filename,before)
                    size=tuple(round(n*scale) for n in sprite.size)
                    sprite=sprite.resize(size,Image.Resampling.LANCZOS)
                    visible=sprite.getchannel('A').point(lambda a:255 if a>=16 else 0).getbbox()
                    offset=(round(148-size[0]/2+shift[0]),round(135-size[1]/2+shift[1]))
                    expected=(visible[0]+offset[0],visible[1]+offset[1],visible[2]+offset[0],visible[3]+offset[1])
                    self.assertTrue(actual[0]<=expected[0] and actual[1]<=expected[1] and actual[2]>=expected[2] and actual[3]>=expected[3],f'{role}: yellow guide {actual} clips visible machine {expected}')
                    self.assertLessEqual(max(abs(a-b) for a,b in zip(actual,expected)),4,f'{role}: yellow guide includes empty footprint space')

if __name__=='__main__':unittest.main()
