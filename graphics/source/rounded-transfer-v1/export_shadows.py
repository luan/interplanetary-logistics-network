"""Make ground-projected silhouettes from the evaluated model geometry."""
import bpy
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parent
shadow_material=bpy.data.materials.new('ILN / Ground shadow silhouette')
shadow_material.use_nodes=True
nodes=shadow_material.node_tree.nodes
nodes.clear()
shader=nodes.new('ShaderNodeEmission')
shader.inputs['Color'].default_value=(0,0,0,1)
output=nodes.new('ShaderNodeOutputMaterial')
shadow_material.node_tree.links.new(shader.outputs[0],output.inputs['Surface'])

counts={}
for role,label in [('provider','PROVIDER TX'),('requester','REQUESTER RX')]:
    source=bpy.data.scenes['ILN - '+role.title()]
    bpy.context.window.scene=source
    source.frame_set(1)
    bpy.context.view_layer.update()
    graph=bpy.context.evaluated_depsgraph_get()
    verts=[]
    faces=[]
    for obj in bpy.data.collections['ILN / '+label].all_objects:
        if obj.type not in {'MESH','CURVE','FONT'} or obj.hide_render or obj.hide_viewport:continue
        evaluated=obj.evaluated_get(graph)
        data=evaluated.to_mesh()
        if data is None:continue
        offset=len(verts)
        for v in data.vertices:
            p=evaluated.matrix_world@v.co
            # The upper-left key casts to the right and away on the ground plane.
            verts.append((p.x+.52*p.z,p.y+.38*p.z,.002))
        faces.extend(tuple(offset+i for i in p.vertices) for p in data.polygons)
        evaluated.to_mesh_clear()
    mesh=bpy.data.meshes.new('ILN / '+role+' projected shadow geometry')
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    mesh.materials.append(shadow_material)
    obj=bpy.data.objects.new('ILN / '+role+' ground shadow',mesh)
    s=bpy.data.scenes.new('ILN - '+role.title()+' Shadow')
    s.collection.objects.link(obj)
    cam=source.camera.copy()
    cam.data=source.camera.data.copy()
    s.collection.objects.link(cam)
    s.camera=cam
    s.render.engine='BLENDER_EEVEE'
    s.eevee.taa_render_samples=16
    s.render.resolution_x=768
    s.render.resolution_y=512
    s.render.resolution_percentage=100
    s.render.film_transparent=True
    s.render.image_settings.file_format='PNG'
    s.render.image_settings.color_mode='RGBA'
    s.render.filepath=str(ROOT/'raw'/f'{role}-shadow.png')
    counts[role]=len(verts)
bpy.context.window.scene=bpy.data.scenes['ILN - Presentation']
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'rounded-transfer-v1.blend'))
result={'shadow_vertices':counts,'raw_size':[768,512],'final_size':[384,256]}
