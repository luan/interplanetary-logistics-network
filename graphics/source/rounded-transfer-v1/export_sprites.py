"""Configure native Blender renders for ILN. Execute through Blender MCP.

Then select ILN - Provider or ILN - Requester and Render Animation.
Use pack_sprites.py after both sequences finish. No external Blender add-on is
needed to reopen or edit the models; MCP is the authoring/control transport.
"""
import bpy
import math
import re
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parent

for f in list(bpy.app.handlers.render_pre):
    if f.__name__=='render_names':bpy.app.handlers.render_pre.remove(f)

for role in ['provider','requester']:
    s=bpy.data.scenes['ILN - '+role.title()]
    bpy.context.window.scene=s
    s.frame_set(1)
    collection=bpy.data.collections['ILN / '+('PROVIDER TX' if role=='provider' else 'REQUESTER RX')]
    datum_name='ILN / '+role+' ground datum'
    datum=bpy.data.objects.get(datum_name)
    if datum is None:
        datum=bpy.data.objects.new(datum_name,None)
        collection.objects.link(datum)
    for obj in list(collection.objects):
        if obj is not datum and obj.parent is None:obj.parent=datum
    # Fit the authored base to the actual collider, in Factorio's dimetric
    # ground plane. One north/south tile is sqrt(2) Blender metres.
    datum.scale=(1,1,1)
    datum.location.x=0
    datum.location.y=0
    s.view_layers[0].update()
    graph=bpy.context.evaluated_depsgraph_get()
    points=[]
    for obj in collection.all_objects:
        if obj.type not in {'MESH','CURVE','FONT'} or obj.hide_render:continue
        evaluated=obj.evaluated_get(graph)
        mesh=evaluated.to_mesh()
        if mesh is None:continue
        points.extend(evaluated.matrix_world@v.co for v in mesh.vertices)
        evaluated.to_mesh_clear()
    low=[min(p[i] for p in points) for i in range(2)]
    high=[max(p[i] for p in points) for i in range(2)]
    prototype=(ROOT.parents[2]/'data.lua').read_text().split(f'name = "interplanetary-{role}-chest",',1)[1]
    box=re.search(r'collision_box = \{ \{ ([^,]+), ([^}]+) \}, \{ ([^,]+), ([^}]+) \} \}',prototype)
    x0,y0,x1,y1=map(float,box.groups())
    scale=[(x1-x0-.05)/(high[0]-low[0]),(y1-y0-.05)*math.sqrt(2)/(high[1]-low[1])]
    datum.scale=(scale[0],scale[1],1)
    datum.location.x=(x0+x1)/2-(low[0]+high[0])/2*scale[0]
    datum.location.y=-(y0+y1)/2*math.sqrt(2)-(low[1]+high[1])/2*scale[1]
    s.view_layers[0].update()
    graph=bpy.context.evaluated_depsgraph_get()
    contact=[]
    for obj in collection.objects:
        if 'swept armor' not in obj.name:continue
        evaluated=obj.evaluated_get(graph)
        mesh=evaluated.to_mesh()
        contact.extend((evaluated.matrix_world@v.co).z for v in mesh.vertices)
        evaluated.to_mesh_clear()
    datum.location.z-=min(contact)
    # The image center is the ground datum; prototypes use zero shift.
    s.camera.location=(0,-6,6)
    s.camera.rotation_euler=(Vector((0,0,0))-s.camera.location).to_track_quat('-Z','Y').to_euler()
    s.camera.data.ortho_scale=5
    key=next(o for o in s.objects if o.type=='LIGHT' and 'upper left key' in o.name)
    key.data.type='SUN'
    key.data.energy=2.5
    key.data.angle=.06
    key.location=(-3,4,7)
    key.rotation_euler=(Vector((0,0,.5))-key.location).to_track_quat('-Z','Y').to_euler()
    s.render.resolution_x=384
    s.render.resolution_y=512
    s.render.resolution_percentage=100
    s.render.film_transparent=True
    s.render.image_settings.file_format='PNG'
    s.render.image_settings.color_mode='RGBA'
    s.eevee.taa_render_samples=32
    s.frame_start=1
    s.frame_end=128
    s.frame_step=1
    s.render.filepath=str(ROOT/'raw'/role/'combined-')
    s.view_layers[0].use_pass_emit=True
    group=s.compositing_node_group
    if group is None:
        group=bpy.data.node_groups.new('ILN / '+role+' body and additive emission','CompositorNodeTree')
    s.compositing_node_group=group
    s.use_nodes=True
    nodes=group.nodes
    nodes.clear()
    links=group.links
    layer=nodes.new('CompositorNodeRLayers')
    layer.scene=s
    subtract=nodes.new('ShaderNodeMixRGB')
    subtract.name='Remove direct emission from body'
    subtract.blend_type='SUBTRACT'
    subtract.inputs[0].default_value=1
    subtract.use_clamp=True
    links.new(layer.outputs['Image'],subtract.inputs[1])
    links.new(layer.outputs['Emission'],subtract.inputs[2])
    alpha=nodes.new('CompositorNodeSetAlpha')
    alpha.inputs['Type'].default_value='Replace Alpha'
    links.new(subtract.outputs[0],alpha.inputs['Image'])
    links.new(layer.outputs['Alpha'],alpha.inputs['Alpha'])
    for label,source in [('body',alpha.outputs[0]),('emission',layer.outputs['Emission'])]:
        output=nodes.new('CompositorNodeOutputFile')
        output.name='ILN '+label
        output.directory=str(ROOT/'raw'/role)
        output.file_name=f'{label}-'
        output.format.media_type='IMAGE'
        output.format.file_format='PNG'
        output.format.color_mode='RGBA'
        output.format.color_depth='8'
        output.save_as_render=True
        output.file_output_items.new('RGBA','Image')
        links.new(source,output.inputs['Image'])
    if not any(item.name=='Image' and item.in_out=='OUTPUT' for item in group.interface.items_tree):
        group.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor')
    out=nodes.new('NodeGroupOutput')
    links.new(layer.outputs['Image'],out.inputs['Image'])
    s['pixels_per_tile']=51.2
    s['anchor_native_px']=[96,128]
    s['factorio_shift']=[0,0]
    s.frame_set(1)

bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'rounded-transfer-v1.blend'))
result={'configured':['provider','requester'],'frames_per_role':128,'raw_cell':[384,512],'final_cell':[192,256],'anchor':[96,128]}
