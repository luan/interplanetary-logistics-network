"""The guide is a fixed tile reference, independent of visible sprite bounds."""
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'graphics/source/rounded-transfer-v1'
sys.path.insert(0,str(SOURCE))
import preview_grounding as preview

class PreviewGuides(unittest.TestCase):
    def test_fixed_three_tile_guides(self):
        for role in ['provider','requester']:
            for before in [True,False]:
                with self.subTest(role=role,before=before):
                    tile=preview.composite(role,before)
                    yellow=[(x,y) for y in range(tile.height) for x in range(tile.width) if tile.getpixel((x,y))==(224,189,101)]
                    self.assertTrue(yellow,'Missing placement footprint')
                    actual=(min(x for x,y in yellow),min(y for x,y in yellow),max(x for x,y in yellow),max(y for x,y in yellow))
                    self.assertEqual(actual,(100,87,196,183),'Guide must remain centered on the entity and span exactly three tiles')
                    self.assertEqual(tile.getpixel((148,135)),(224,189,101),'Missing placement origin')
                    self.assertEqual(tile.getpixel((100,40)),(100,112,102),'Grid edges must align with footprint edges')

if __name__=='__main__':unittest.main()
