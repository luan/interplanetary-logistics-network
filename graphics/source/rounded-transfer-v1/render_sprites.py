"""Regenerate the Blender source, grounded shadows and complete sprite sequence.

blender --background rounded-transfer-v1.blend --python render_sprites.py
Then run pack_sprites.py with Pillow. Factorio is not started.
"""
from pathlib import Path
import bpy
import json

ROOT=Path(__file__).resolve().parent
for name in ['export_sprites.py','export_shadows.py']:
    path=ROOT/name
    exec(compile(path.read_text(),str(path),'exec'),{'__file__':str(path)})
path=ROOT.parents[2]/'tests/graphics_projection.py'
namespace={'__file__':str(path),'__name__':'projection_check'}
exec(compile(path.read_text(),str(path),'exec'),namespace)
(ROOT/'projection-check.json').write_text(json.dumps(namespace['check_projections'](),indent=2)+'\n')
for role in ['Provider','Requester']:
    scene=bpy.data.scenes['ILN - '+role]
    bpy.context.window.scene=scene
    bpy.ops.render.render(animation=True)
bpy.context.window.scene=bpy.data.scenes['ILN - Presentation']
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'rounded-transfer-v1.blend'))
