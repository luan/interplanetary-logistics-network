"""Render gallery artwork with the existing sprite cameras, without saving the model.

Run inside Blender with rounded-transfer-v1.blend loaded, then run
make_portal_gallery.py with Pillow. Does not start Factorio.
"""
from pathlib import Path
import hashlib
import json
import bpy

ROOT=Path(__file__).resolve().parent
OUT=ROOT/'raw/gallery'
OUT.mkdir(parents=True,exist_ok=True)
report={'source_sha256':hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest(),'scenes':{}}
for role in ['provider','requester']:
    scene=bpy.data.scenes['ILN - '+role.title()]
    bpy.context.window.scene=scene
    camera=[list(row) for row in scene.camera.matrix_world]
    scene.use_nodes=False
    scene.compositing_node_group=None
    scene.render.resolution_x=768
    scene.render.resolution_y=1024
    scene.render.resolution_percentage=100
    scene.render.film_transparent=True
    scene.render.image_settings.file_format='PNG'
    scene.render.image_settings.color_mode='RGBA'
    for state,frame in [('idle',1),('active',65)]:
        scene.frame_set(frame)
        scene.render.filepath=str(OUT/f'{role}-{state}.png')
        bpy.ops.render.render(write_still=True)
    assert camera==[list(row) for row in scene.camera.matrix_world]
    report['scenes'][role]={'camera_matrix':camera,'ortho_scale':scene.camera.data.ortho_scale,'frames':{'idle':1,'active':65}}
    shadow=bpy.data.scenes['ILN - '+role.title()+' Shadow']
    bpy.context.window.scene=shadow
    shadow.render.resolution_x=1536
    shadow.render.resolution_y=1024
    shadow.render.resolution_percentage=100
    shadow.render.filepath=str(OUT/f'{role}-shadow.png')
    bpy.ops.render.render(write_still=True)
    caster=next(o for o in shadow.objects if o.name.endswith('shadow caster'))
    caster.hide_render=True
    shadow.render.filepath=str(OUT/f'{role}-shadow-clear.png')
    bpy.ops.render.render(write_still=True)
    caster.hide_render=False
(OUT/'renders.json').write_text(json.dumps(report,indent=2)+'\n')
result={'output':str(OUT),'frames_per_role':2,'camera_changed':False,'model_saved':False}
