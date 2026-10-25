"""Render actual ground-contact shadows with the body's sun and pixel density."""
import bpy
from pathlib import Path

ROOT=Path(__file__).resolve().parent
material=bpy.data.materials.get('ILN / Shadow caster') or bpy.data.materials.new('ILN / Shadow caster')
material.use_nodes=True
material.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.5,.5,.5,1)

counts={}
for role,label in [('provider','PROVIDER TX'),('requester','REQUESTER RX')]:
    source=bpy.data.scenes['ILN - '+role.title()]
    bpy.context.window.scene=source
    source.frame_set(1)
    source.view_layers[0].update()
    graph=bpy.context.evaluated_depsgraph_get()
    verts=[]
    faces=[]
    for obj in bpy.data.collections['ILN / '+label].all_objects:
        if obj.type not in {'MESH','CURVE','FONT'} or obj.hide_render or obj.hide_viewport:continue
        evaluated=obj.evaluated_get(graph)
        data=evaluated.to_mesh()
        if data is None:continue
        offset=len(verts)
        verts.extend(tuple(evaluated.matrix_world@v.co) for v in data.vertices)
        faces.extend(tuple(offset+i for i in p.vertices) for p in data.polygons)
        evaluated.to_mesh_clear()
    name='ILN - '+role.title()+' Shadow'
    previous=bpy.data.scenes.get(name)
    if previous:
        for obj in list(previous.objects):
            if len(obj.users_scene)==1:
                data=obj.data
                bpy.data.objects.remove(obj,do_unlink=True)
                if data and data.users==0 and isinstance(data,bpy.types.Mesh):bpy.data.meshes.remove(data)
        bpy.data.scenes.remove(previous)
    s=bpy.data.scenes.new(name)
    mesh=bpy.data.meshes.new('ILN / '+role+' shadow caster geometry')
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    mesh.materials.append(material)
    caster=bpy.data.objects.new('ILN / '+role+' shadow caster',mesh)
    caster.visible_camera=False
    s.collection.objects.link(caster)
    plane_mesh=bpy.data.meshes.new('ILN / '+role+' ground plane')
    plane_mesh.from_pydata([(-100,-100,0),(100,-100,0),(100,100,0),(-100,100,0)],[],[(0,1,2,3)])
    plane=bpy.data.objects.new('ILN / '+role+' shadow catcher',plane_mesh)
    plane.is_shadow_catcher=True
    plane_mesh.materials.append(material)
    s.collection.objects.link(plane)
    sun_source=next(o for o in source.objects if o.type=='LIGHT' and 'upper left key' in o.name)
    sun=sun_source.copy()
    sun.data=sun_source.data.copy()
    s.collection.objects.link(sun)
    cam=source.camera.copy()
    cam.data=source.camera.data.copy()
    # A wider canvas must retain the body's pixels per metre and ground anchor.
    cam.data.ortho_scale*=768/max(source.render.resolution_x,source.render.resolution_y)
    s.collection.objects.link(cam)
    s.camera=cam
    s.render.engine='CYCLES'
    s.cycles.samples=32
    s.cycles.use_denoising=True
    s.cycles.max_bounces=1
    s.cycles.diffuse_bounces=0
    s.world=bpy.data.worlds.new(name+' ambient')
    s.world.use_nodes=True
    s.world.node_tree.nodes['Background'].inputs['Color'].default_value=(1,1,1,1)
    s.world.node_tree.nodes['Background'].inputs['Strength'].default_value=0
    s.render.resolution_x=768
    s.render.resolution_y=512
    s.render.resolution_percentage=100
    s.render.film_transparent=True
    s.render.image_settings.file_format='PNG'
    s.render.image_settings.color_mode='RGBA'
    s.render.filepath=str(ROOT/'raw'/f'{role}-shadow.png')
    counts[role]=len(verts)
for role in ['Provider','Requester']:
    s=bpy.data.scenes['ILN - '+role+' Shadow']
    bpy.context.window.scene=s
    caster=next(o for o in s.objects if o.name.endswith('shadow caster'))
    path=s.render.filepath
    bpy.ops.render.render(write_still=True)
    caster.hide_render=True
    s.render.filepath=path.replace('-shadow.png','-shadow-clear.png')
    bpy.ops.render.render(write_still=True)
    caster.hide_render=False
    s.render.filepath=path
bpy.context.window.scene=bpy.data.scenes['ILN - Presentation']
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'rounded-transfer-v1.blend'))
result={'shadow_vertices':counts,'raw_size':[768,512],'final_size':[384,256],'method':'Cycles shadow catcher'}
