"""Editable ILN concept models, authored in the connected Blender via MCP.

Run this text in Blender. Existing scenes and objects are preserved.
Frames 1..64 are idle; 65..128 are an active, seamless 64-frame cycle.
"""
import bpy
import math
from mathutils import Vector
from pathlib import Path

ROOT = Path(__file__).resolve().parent
TAU = math.tau
if bpy.data.scenes.get('ILN - Presentation'):
    raise RuntimeError('ILN model scenes already exist; preserve them rather than rebuilding over edits.')

def linear(v):
    return v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4

def color(hexcode):
    return tuple(linear(int(hexcode[i:i+2], 16) / 255) for i in (0, 2, 4)) + (1,)

def material(name, hexcode, metallic=.65, roughness=.32, emission=0, wear=False):
    m = bpy.data.materials.new('ILN / ' + name)
    m.diffuse_color = color(hexcode)
    m.use_nodes = True
    n = m.node_tree.nodes
    p = n.get('Principled BSDF')
    p.inputs['Base Color'].default_value = color(hexcode)
    p.inputs['Metallic'].default_value = metallic
    p.inputs['Roughness'].default_value = roughness
    if emission:
        p.inputs['Emission Color'].default_value = color(hexcode)
        p.inputs['Emission Strength'].default_value = emission
    if wear:
        noise = n.new('ShaderNodeTexNoise')
        noise.inputs['Scale'].default_value = 65
        noise.inputs['Detail'].default_value = 2
        bump = n.new('ShaderNodeBump')
        bump.inputs['Strength'].default_value = .16
        bump.inputs['Distance'].default_value = .018
        m.node_tree.links.new(noise.outputs['Fac'], bump.inputs['Height'])
        m.node_tree.links.new(bump.outputs['Normal'], p.inputs['Normal'])
        ramp = n.new('ShaderNodeValToRGB')
        ramp.color_ramp.elements[0].color = tuple(c * .78 for c in color(hexcode)[:3]) + (1,)
        ramp.color_ramp.elements[1].color = color(hexcode)
        m.node_tree.links.new(noise.outputs['Fac'], ramp.inputs[0])
        m.node_tree.links.new(ramp.outputs['Color'], p.inputs['Base Color'])
    return m

M = {
 'titanium': material('Graphite titanium', '303a42', .85, .36, wear=True),
 'recess': material('Deep recesses', '101923', .45, .48),
 'steel': material('Machined silver edges', 'aab2b6', .82, .28, wear=True),
 'copper': material('Copper windings', 'b96d39', .82, .3),
 'rubber': material('Dark seals', '131a1f', .05, .52),
 'cyan': material('Coolant conduit', '18c6eb', .25, .22, 2.4),
 'glass': material('Coolant sleeve', '165a78', .45, .21),
 'red': material('Provider oxide enamel', 'b94631', .52, .29, wear=True),
 'green': material('Requester olive enamel', '788b37', .52, .29, wear=True),
 'amber': material('Provider amber emitters', 'ff9b29', .15, .22, 3.2),
 'lime': material('Requester lime emitters', 'baff45', .15, .22, 3.2),
 'field_amber': material('Provider transfer field', 'ffae42', .0, .3, 5),
 'field_lime': material('Requester transfer field', 'c3ff62', .0, .3, 5),
}

def finish(obj, name, coll, mat, bevel=0, parent=None):
    obj.name = name
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    coll.objects.link(obj)
    if mat:
        obj.data.materials.append(mat)
    if parent:
        obj.parent = parent
    if obj.type == 'MESH':
        for p in obj.data.polygons:
            p.use_smooth = True
        if bevel:
            mod = obj.modifiers.new('Soft manufactured edge', 'BEVEL')
            mod.width = bevel
            mod.segments = 3
            mod.limit_method = 'ANGLE'
            mod = obj.modifiers.new('Weighted surface normals', 'WEIGHTED_NORMAL')
            mod.keep_sharp = True
    return obj

def mesh(name, verts, faces, coll, mat, bevel=0, parent=None):
    data = bpy.data.meshes.new(name + ' geometry')
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    coll.objects.link(obj)
    return finish(obj, name, coll, mat, bevel, parent)

def sector(name, profile, start, end, coll, mat, bevel=.018, parent=None, steps=36):
    verts = []
    for j in range(steps+1):
        a = start + (end-start)*j/steps
        for r,z in profile:
            verts.append((r*math.cos(a),r*math.sin(a),z))
    k = len(profile)
    faces = []
    for j in range(steps):
        for i in range(k):
            faces.append((j*k+i,j*k+(i+1)%k,(j+1)*k+(i+1)%k,(j+1)*k+i))
    faces += [tuple(range(k-1,-1,-1)),tuple(steps*k+i for i in range(k))]
    return mesh(name, verts, faces, coll, mat, bevel, parent)

def ring(name, inner, outer, bottom, top, coll, mat, bevel=.012, parent=None):
    return sector(name, [(inner,bottom),(outer,bottom),(outer,top),(inner,top)], 0,TAU,coll,mat,bevel,parent,96)

def cylinder(name, radius, depth, loc, coll, mat, bevel=.012, vertices=48):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc)
    return finish(bpy.context.object,name,coll,mat,bevel)

def box(name, loc, size, coll, mat, bevel=.035, angle=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.rotation_euler.z = angle
    return finish(o,name,coll,mat,bevel)

def path(name, points, thickness, coll, mat, cyclic=False, parent=None):
    data = bpy.data.curves.new(name + ' spline','CURVE')
    data.dimensions='3D'
    data.resolution_u=16
    data.bevel_depth=thickness
    data.bevel_resolution=3
    spline=data.splines.new('BEZIER')
    spline.bezier_points.add(len(points)-1)
    for p,co in zip(spline.bezier_points,points):
        p.co=co
        p.handle_left_type='AUTO'
        p.handle_right_type='AUTO'
    spline.use_cyclic_u=cyclic
    obj=bpy.data.objects.new(name,data)
    coll.objects.link(obj)
    data.materials.append(mat)
    if parent: obj.parent=parent
    return obj

def arcpath(name,r,z,a,b,thickness,coll,mat):
    return path(name,[(r*math.cos(a+(b-a)*i/24),r*math.sin(a+(b-a)*i/24),z) for i in range(25)],thickness,coll,mat)

def torus(name, radius, tube, z, coll, mat, locxy=(0,0), parent=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=radius,minor_radius=tube,major_segments=96,minor_segments=12,location=(*locxy,z))
    return finish(bpy.context.object,name,coll,mat,0,parent)

def driver(obj, prop, expression, index=None):
    f=obj.driver_add(prop) if index is None else obj.driver_add(prop,index)
    f.driver.expression=expression

def polar(r,a,z):
    return (r*math.cos(a),r*math.sin(a),z)

def leg(name,a,coll,paint,glow):
    sections=[(.87,.18,.22,.55),(1.1,.25,.15,.49),(1.4,.23,.06,.29),(1.59,.12,.035,.17)]
    verts=[]
    for r,w,lo,hi in sections:
        sweep=.18*(r-.87)
        for tangent,z in [(-w,lo),(w,lo),(w,hi),(-w,hi)]:
            verts.append((r*math.cos(a)-(tangent+sweep)*math.sin(a),r*math.sin(a)+(tangent+sweep)*math.cos(a),z))
    faces=[(3,2,1,0),(12,13,14,15)]
    for i in range(3):
        for k in range(4):faces.append((i*4+k,i*4+(k+1)%4,(i+1)*4+(k+1)%4,(i+1)*4+k))
    mesh(name+' swept armor',verts,faces,coll,paint,.045)
    pts=[]
    for r,w,lo,hi in sections:
        t=-w-.012+.18*(r-.87)
        pts.append((r*math.cos(a)-t*math.sin(a),r*math.sin(a)+t*math.cos(a),(hi+lo)*.5))
    path(name+' recessed running light',pts,.019,coll,glow)
    for r,z in [(1.42,.12),(1.54,.09)]:
        p=polar(r,a,z)
        o=box(name+' foot rail',p,(.28,.36,.09),coll,M['steel'],.04,a)
    cylinder(name+' anchor bolt',.047,.025,polar(1.45,a,.29),coll,M['steel'],.008,16)

def make_machine(role):
    is_tx=role=='provider'
    name='PROVIDER TX' if is_tx else 'REQUESTER RX'
    coll=bpy.data.collections.new('ILN / '+name)
    paint=M['red' if is_tx else 'green']
    glow=M['amber' if is_tx else 'lime']
    field=M['field_amber' if is_tx else 'field_lime']
    sector(name+' sculpted radial chassis',[(.54,.12),(1.04,.12),(1.18,.25),(1.19,.43),(1.04,.60),(.66,.54)],0,TAU,coll,M['titanium'],.025,steps=96)
    ring(name+' underside gasket',.88,1.09,.09,.17,coll,M['rubber'])
    torus(name+' machined lower rim',1.095,.027,.24,coll,M['steel'])
    torus(name+' waist conduit',1.16,.025,.39,coll,glow)
    ring(name+' recessed cargo well',.27,.66,.22,.47,coll,M['recess'])
    cylinder(name+' central transfer lens',.29,.04,(0,0,.27),coll,M['titanium'])
    torus(name+' lens aperture',.24,.018,.3,coll,glow)
    for i in range(6):
        a=i*TAU/6+math.radians(4)
        b=a+math.radians(47)
        sector(name+f' lower skirt {i+1}',[(1.03,.22),(1.18,.25),(1.19,.42),(1.08,.53),(1.02,.46)],a,b,coll,paint,.02)
        sector(name+f' skirt silver seam {i+1}',[(1.185,.27),(1.204,.28),(1.204,.40),(1.185,.42)],a,a+.055,coll,M['steel'],.009,steps=4)
        # Cargo iris plates stay recessed; the surrounding arms retain a circular silhouette.
        sector(name+f' cargo iris blade {i+1}',[(.265,.29),(.62,.32),(.65,.36),(.29,.34)],a,b+.10,coll,M['steel'],.012)
        sector(name+f' induction winding {i+1}',[(.70,.47),(.99,.48),(1.05,.65),(.82,.68)],a+.10,b-.10,coll,M['copper'],.012)
        for j in range(5):
            aa=a+.12+j*(b-a-.26)/4
            path(name+f' coil groove {i+1}.{j+1}',[polar(.77,aa,.55),polar(.89,aa,.64),polar(1.015,aa,.60)],.010,coll,M['recess'])
        profile=[(.72,.54),(1.10,.54),(1.18,.70),(1.10,.88),(.86,.78),(.73,.63)] if is_tx else [(.72,.50),(1.13,.55),(1.19,.78),(1.10,.94),(.88,.82),(.72,.62)]
        sector(name+f' swept catcher petal {i+1}',profile,a+.035,b-.035,coll,paint,.03)
        sector(name+f' petal edge {i+1}',[(.73,.58),(.77,.59),(.9,.81),(.88,.83),(.75,.64)],a+.05,a+.12,coll,M['steel'],.012,steps=6)
        arcpath(name+f' petal light {i+1}',.76,.61,a+.13,b-.12,.017,coll,glow)
        for aa in [a+.15,b-.15]:
            cylinder(name+' petal fastener',.028,.025,polar(1.065,aa,.88 if is_tx else .93),coll,M['steel'],.003,12)
    for i,a in enumerate([math.radians(210),math.radians(330),math.radians(90)]):
        leg(name+f' landing foot {i+1}',a,coll,paint,glow)
    # A curved front service cassette: deliberately integrated into the round skirt.
    sector(name+' service cassette',[(1.10,.16),(1.29,.19),(1.30,.49),(1.14,.57)],math.radians(251),math.radians(289),coll,M['steel'],.027,steps=16)
    box(name+' service face',(0,-1.264,.36),(.32,.06,.23),coll,M['recess'],.025)
    for x in [-.085,0,.085]:
        box(name+' status slit',(x,-1.300,.36),(.023,.025,.14),coll,glow,.01)
    for side in [-1,1]:
        x=side*1.12
        y=.02
        cylinder(name+' coolant chamber',.115,.48,(x,y,.71),coll,M['glass'],.02)
        cylinder(name+' coolant core',.065,.44,(x,y,.71),coll,M['cyan'],.015)
        for z in [.44,.48,.94,.98]:
            cylinder(name+' coolant cuff',.14,.055,(x,y,z),coll,M['steel'],.012)
        cylinder(name+' coolant cap',.087,.055,(x,y,1.025),coll,M['titanium'],.01)
        path(name+' cyan return hose',[(x,y,.46),(side*1.23,-.18,.43),(side*1.16,-.56,.38),(side*.94,-.78,.34)],.037,coll,M['cyan'])
        path(name+' copper return',[(x,.13,.95),(side*1.27,.22,.84),(side*1.28,.27,.53),(side*1.11,.57,.47)],.032,coll,M['copper'])
        for j in range(9):
            z=.52+j*.044
            o=torus(name+' conduit coupling',.045,.012,z,coll,M['copper'],(side*1.27,.255))
    if is_tx:
        # The raised annular focusing crown is supported by three swept mechanical ribs.
        for i,a in enumerate([math.radians(25),math.radians(155),math.radians(90)]):
            pts=[polar(1.04,a,.57),polar(1.14,a,.93),polar(1.10,a,1.35),polar(.96,a,1.58)]
            path(name+f' crown load rib {i+1}',pts,.068,coll,M['titanium'])
            path(name+f' crown silver rib {i+1}',[(x*1.015,y*1.015,z+.018) for x,y,z in pts],.026,coll,M['steel'])
        for i in range(6):
            a=i*TAU/6+.045
            b=(i+1)*TAU/6-.045
            sector(name+f' focusing crown armor {i+1}',[(.85,1.45),(1.075,1.45),(1.11,1.58),(1.04,1.68),(.85,1.63)],a,b,coll,paint,.027)
            arcpath(name+f' focusing crown light {i+1}',.866,1.51,a+.02,b-.02,.031,coll,glow)
            sector(name+f' crown machined strap {i+1}',[(.846,1.47),(1.105,1.49),(1.115,1.59),(1.04,1.70),(.846,1.65)],a+.02,a+.095,coll,M['steel'],.016,steps=5)
    else:
        for i in range(4):
            a=math.radians(12+i*39)
            b=a+math.radians(35)
            sector(name+f' rear crescent stabilizer {i+1}',[(.92,.82),(1.18,.81),(1.22,1.10),(1.11,1.21),(.93,1.16)],a,b,coll,paint,.025)
            arcpath(name+f' crescent silver rail {i+1}',.945,1.17,a+.025,b-.025,.025,coll,M['steel'])
            arcpath(name+f' crescent inner light {i+1}',.946,.96,a+.04,b-.04,.021,coll,glow)
        for i in range(3):
            a=math.radians(45+i*22)
            loc=polar(1.08,a,1.28)
            box(name+' rear capacitor',loc,(.17,.20,.28),coll,M['titanium'],.028,a)
            cylinder(name+' capacitor status',.032,.02,(loc[0],loc[1],1.43),coll,glow,.006,16)
    # A thin moving scanner inside the cargo well, separated from the armored body.
    scanner=bpy.data.objects.new(name+' iris scanner rotor',None)
    coll.objects.link(scanner)
    driver(scanner,'rotation_euler','(frame-1)*0.0981747704',2)
    for i in range(3):
        o=arcpath(name+' iris scanning arc',.51,.385,i*TAU/3,i*TAU/3+.55,.012,coll,glow)
        o.parent=scanner
    # Active transport rings travel out of TX and into RX; every channel loops at 64 frames.
    for i in range(5):
        o=torus(name+f' active field ring {i+1}',1,.013,0,coll,field)
        phase=f'(((frame-65)/64+{i/5})%1)'
        travel=phase if is_tx else '(1-'+phase+')'
        driver(o,'location','.36+1.06*'+travel,2)
        radius='(.16+.29*sin(3.14159265*'+travel+'))'
        driver(o,'scale',radius,0)
        driver(o,'scale',radius,1)
        driver(o,'hide_render','frame<65')
        driver(o,'hide_viewport','frame<65')
    pts=[]
    for i in range(129):
        t=i/128
        r=.13+.12*math.sin(math.pi*t)
        pts.append((r*math.cos(t*TAU*3),r*math.sin(t*TAU*3),.34+1.0*t))
    helix=path(name+' active transfer helix',pts,.008,coll,field)
    driver(helix,'rotation_euler',('' if is_tx else '-')+'(frame-65)*0.0981747704',2)
    driver(helix,'hide_render','frame<65')
    driver(helix,'hide_viewport','frame<65')
    coll['role']=role
    coll['footprint_tiles']=[3,3]
    return coll

def aim(obj, target):
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()

def camera(name,coll,loc,target,ortho):
    data=bpy.data.cameras.new(name)
    data.type='ORTHO'
    data.ortho_scale=ortho
    obj=bpy.data.objects.new(name,data)
    obj.location=loc
    aim(obj,target)
    coll.objects.link(obj)
    return obj

def light(name,coll,loc,target,power,size,color_value=(1,1,1)):
    data=bpy.data.lights.new(name,'AREA')
    data.energy=power
    data.shape='DISK'
    data.size=size
    data.color=color_value
    obj=bpy.data.objects.new(name,data)
    obj.location=loc
    aim(obj,target)
    coll.objects.link(obj)
    return obj

def setup_scene(name,coll,size=(768,1024)):
    scene=bpy.data.scenes.new(name)
    scene.collection.children.link(coll)
    scene.render.engine='BLENDER_EEVEE'
    scene.render.resolution_x=size[0]
    scene.render.resolution_y=size[1]
    scene.render.resolution_percentage=100
    scene.render.film_transparent=True
    scene.render.image_settings.file_format='PNG'
    scene.render.image_settings.color_mode='RGBA'
    scene.render.image_settings.color_depth='8'
    scene.render.fps=60
    scene.render.film_transparent=True
    scene.eevee.taa_render_samples=32
    scene.world=bpy.data.worlds.new(name+' ambient')
    scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.18,.22,.29,1)
    scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.45
    scene.view_settings.view_transform='AgX'
    scene.view_settings.look='AgX - Medium High Contrast'
    scene.frame_start=1
    scene.frame_end=128
    scene.timeline_markers.new('IDLE - 64 frames',frame=1)
    scene.timeline_markers.new('ACTIVE - 64 frames',frame=65)
    studio=bpy.data.collections.new(name+' lighting and camera')
    scene.collection.children.link(studio)
    light(name+' upper left key',studio,(-3,-4,7),(0,0,.5),650,4,(1,.88,.74))
    light(name+' cool fill',studio,(4,-1,4),(0,0,.6),420,3,(.64,.80,1))
    light(name+' rear rim',studio,(0,4,5),(0,0,.8),750,3,(.88,.94,1))
    scene.camera=camera(name+' orthographic camera',studio,(0,-6,6),(0,0,0),5)
    scene['sprite_cell']=[192,256]
    scene['sprite_grid']=[8,8]
    scene['factorio_scale']=.625
    scene['factorio_shift']=[0,0]
    return scene

provider=make_machine('provider')
requester=make_machine('requester')
tx_scene=setup_scene('ILN - Provider',provider)
rx_scene=setup_scene('ILN - Requester',requester)

presentation=bpy.data.collections.new('ILN / Presentation instances')
show=setup_scene('ILN - Presentation',presentation,(1600,1000))
show.render.film_transparent=False
show.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.018,.024,.032,1)
show.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.6
for col,x in [(provider,-1.92),(requester,1.92)]:
    o=bpy.data.objects.new(col.name+' display',None)
    o.instance_type='COLLECTION'
    o.instance_collection=col
    o.location=(x,0,0)
    presentation.objects.link(o)
floor=material('Presentation ground','252c34',.35,.5)
box('ILN / presentation floor',(0,0,-.075),(200,200,.1),presentation,floor,.01)
show.camera.location=(4,-10,9)
aim(show.camera,(0,0,.6))
show.camera.data.ortho_scale=8.6
show.frame_set(89)
bpy.context.window.scene=show
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
            area.spaces.active.shading.type='MATERIAL'
reference=bpy.data.images.load(str(ROOT.parent.parent/'concepts'/'rounded-transfer-v1.png'),check_existing=True)
reference.pack()
reference['role']='Approved visual design reference; not used as model geometry or render output.'
notes=bpy.data.texts.new('README - ILN rounded machines')
notes.write('Two editable radial machines modelled from rounded-transfer-v1.png.\nProvider/Requester scenes hold the original named meshes; Presentation uses collection instances.\nFrames 1-64: idle. Frames 65-128: active. Parametric animation uses drivers, with no external handlers.\nAll geometry, procedural materials and the packed concept reference are self-contained.\nSprite cell 192x256, 8x8 sheet, scale .625, shift (0,0).\n')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'rounded-transfer-v1.blend'))
result={'file':bpy.data.filepath,'provider_objects':len(provider.objects),'requester_objects':len(requester.objects),'scenes':[tx_scene.name,rx_scene.name,show.name],'concept_packed':reference.packed_file is not None}
