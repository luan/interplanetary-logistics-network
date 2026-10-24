"""Industrial surfacing and functional details for the rounded ILN models."""
import bpy
import math
import ast
import random
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parent
TAU=math.tau
# Reuse the modelling helpers without re-running scene creation.
tree=ast.parse((ROOT/'build_models.py').read_text())
for node in tree.body:
    if isinstance(node,ast.FunctionDef):
        exec(compile(ast.Module(body=[node],type_ignores=[]),'build_models.py','exec'),globals())
M={
 'titanium':bpy.data.materials['ILN / Graphite titanium'],
 'recess':bpy.data.materials['ILN / Deep recesses'],
 'steel':bpy.data.materials['ILN / Machined silver edges'],
 'copper':bpy.data.materials['ILN / Copper windings'],
 'rubber':bpy.data.materials['ILN / Dark seals'],
 'cyan':bpy.data.materials['ILN / Coolant conduit'],
 'glass':bpy.data.materials['ILN / Coolant sleeve'],
 'red':bpy.data.materials['ILN / Provider oxide enamel'],
 'green':bpy.data.materials['ILN / Requester olive enamel'],
 'amber':bpy.data.materials['ILN / Provider amber emitters'],
 'lime':bpy.data.materials['ILN / Requester lime emitters'],
}
if bpy.data.materials.get('ILN / Stencil ink'):
    raise RuntimeError('Refinement already exists; do not duplicate details.')
M['ink']=material('Stencil ink','d9d9b9',.1,.65)
M['yellow']=material('Service hazard yellow','ceab39',.25,.53,wear=True)

for key in ['red','green','titanium','steel']:
    mat=M[key]
    nodes=mat.node_tree.nodes
    links=mat.node_tree.links
    p=nodes.get('Principled BSDF')
    for n in nodes:
        if n.type=='BUMP':
            n.inputs['Strength'].default_value=.09
            n.inputs['Distance'].default_value=.003
    base='ae3b29' if key=='red' else '718036' if key=='green' else '343e46' if key=='titanium' else 'a4abad'
    basecolor=color(base)
    noise=nodes.new('ShaderNodeTexNoise')
    noise.name='Broad worn paint mottling'
    noise.inputs['Scale'].default_value=8
    noise.inputs['Detail'].default_value=3
    ramp=nodes.new('ShaderNodeValToRGB')
    ramp.name='Paint and exposed metal chips'
    ramp.color_ramp.elements[0].position=.15
    ramp.color_ramp.elements[0].color=tuple(c*.40 for c in basecolor[:3])+(1,)
    ramp.color_ramp.elements[1].position=.70
    ramp.color_ramp.elements[1].color=basecolor
    if key in ['red','green']:
        e=ramp.color_ramp.elements.new(.76)
        e.color=color('7d8586')
        e=ramp.color_ramp.elements.new(.78)
        e.color=color('a2a6a2')
    links.new(noise.outputs['Fac'],ramp.inputs[0])
    links.new(ramp.outputs['Color'],p.inputs['Base Color'])
    rough=nodes.new('ShaderNodeMapRange')
    rough.inputs['From Min'].default_value=0
    rough.inputs['From Max'].default_value=1
    rough.inputs['To Min'].default_value=.26
    rough.inputs['To Max'].default_value=.55
    links.new(noise.outputs['Fac'],rough.inputs['Value'])
    links.new(rough.outputs['Result'],p.inputs['Roughness'])

for mat in bpy.data.materials:
    if not mat.name.startswith('ILN /') or not mat.use_nodes:continue
    nodes=mat.node_tree.nodes
    ramp=nodes.get('Paint and exposed metal chips')
    if ramp:
        c=ramp.color_ramp.elements[1].color
        ramp.color_ramp.elements[0].color=tuple(v*.78 for v in c[:3])+(1,)
        ramp.color_ramp.elements[0].position=.08
    p=nodes.get('Principled BSDF')
    if p and 'transfer field' in mat.name:
        p.inputs['Emission Strength'].default_value=2.0
        p.inputs['Emission Color'].default_value=(1,.17,.006,1) if 'Provider' in mat.name else (.22,1,.015,1)
    elif p and 'emitters' in mat.name:
        p.inputs['Emission Strength'].default_value=1.5

def text_decal(name,body,loc,size,coll,rotation=(0,0,0)):
    data=bpy.data.curves.new(name,'FONT')
    data.body=body
    data.align_x='CENTER'
    data.align_y='CENTER'
    data.size=size
    data.extrude=.0003
    obj=bpy.data.objects.new(name,data)
    coll.objects.link(obj)
    obj.location=loc
    obj.rotation_euler=rotation
    data.materials.append(M['ink'])
    return obj

rng=random.Random(42)
for role in ['provider','requester']:
    tx=role=='provider'
    name='PROVIDER TX' if tx else 'REQUESTER RX'
    coll=bpy.data.collections['ILN / '+name]
    paint=M['red' if tx else 'green']
    glow=M['amber' if tx else 'lime']
    # Layered rim and six replaceable inner coil shoes, with a clear dark gasket.
    torus(name+' deep inner silver rim',.657,.026,.465,coll,M['steel'])
    torus(name+' inner field emitter',.625,.023,.42,coll,glow)
    ring(name+' lens iris bezel',.13,.22,.30,.34,coll,M['steel'],.008)
    cylinder(name+' luminous cargo core',.127,.016,(0,0,.34),coll,glow,.005)
    for i in range(6):
        a=i*TAU/6+math.radians(4)
        center=a+math.radians(23.5)
        z=.81 if tx else .86
        # Wedge-shaped removable metallic covers interrupt the broad enamel surfaces.
        sector(name+f' removable coil shoe {i}',[(.81,.71),(.97,z),(.98,z+.025),(.82,.74)],center-.15,center+.15,coll,M['steel'],.013,steps=12)
        sector(name+f' coil shoe inset {i}',[(.825,.73),(.965,z+.018),(.965,z+.028),(.83,.75)],center-.105,center+.105,coll,M['titanium'],.008,steps=10)
        for j in range(4):
            aa=center-.075+j*.05
            path(name+' inset heat vent',[polar(.86,aa,.765),polar(.94,aa,z+.026)],.014,coll,M['recess'])
        # Large hex fasteners and sockets on each armored petal.
        for aa in [a+.17,a+.65]:
            cylinder(name+' petal recessed bolt socket',.043,.012,polar(1.05,aa,.877 if tx else .937),coll,M['recess'],.004,24)
            cylinder(name+' hex head',.026,.018,polar(1.05,aa,.89 if tx else .95),coll,M['steel'],.002,6)
        # Visible service ribs around the lower skirt.
        for j in range(3):
            aa=center-.12+j*.12
            sector(name+' skirt cooling gill',[(1.184,.28),(1.217,.29),(1.216,.39),(1.18,.40)],aa,aa+.035,coll,M['recess'],.006,steps=3)
        # Deliberate chips at exposed armor corners; not an all-over noise coating.
        for j in range(4):
            aa=a+.12+rng.random()*.60
            r=1.08+rng.random()*.03
            zz=(.874 if tx else .934)-.15*abs(r-1.08)
            sector(name+' small edge paint chip',[(r,zz),(r+.022,zz),(r+.02,zz+.002),(r,zz+.002)],aa,aa+.02+rng.random()*.035,coll,M['steel'],0,steps=2)
    # Hazard stripes on the two front inner lips, readable even at sprite size.
    for start in [math.radians(215),math.radians(305)]:
        for j in range(6):
            aa=start+j*.047
            sector(name+' alternating service caution',[(.765,.65),(.825,.71),(.825,.722),(.765,.662)],aa,aa+.038,coll,M['yellow'] if j%2==0 else M['recess'],.002,steps=3)
    # A copper bus and couplings rather than an uninterrupted smooth black sidewall.
    for a,b in [(math.radians(8),math.radians(72)),(math.radians(108),math.radians(172))]:
        arcpath(name+' external copper power bus',1.233,.53,a,b,.034,coll,M['copper'])
        for j in range(4):
            aa=a+(b-a)*j/3
            o=box(name+' power bus saddle',polar(1.24,aa,.53),(.13,.06,.11),coll,M['titanium'],.014,aa)
    for side in [-1,1]:
        # Transparent chamber contents made visible through three curved luminous windows.
        for j in [-1,0,1]:
            aa=-math.pi/2+j*.5
            x=side*1.12+.116*math.cos(aa)
            y=.02+.116*math.sin(aa)
            path(name+' coolant inspection window',[(x,y,.52),(x,y,.71),(x,y,.90)],.016,coll,M['cyan'])
        for z in [.56,.86]:
            torus(name+' coolant reinforcing band',.12,.013,z,coll,M['titanium'],(side*1.12,.02))
        # Braided-looking dark cables curve from the foot to the rear with real metal clips.
        pts=[(side*1.08,-.52,.26),(side*1.30,-.18,.30),(side*1.31,.45,.41),(side*.83,.91,.62)]
        path(name+' insulated auxiliary cable',pts,.027,coll,M['rubber'])
        path(name+' second auxiliary cable',[(x+side*.055,y,z+.025) for x,y,z in pts],.021,coll,M['copper'])
    # An asymmetric rear maintenance block gives each machine a service side.
    x=-.43 if tx else .43
    box(name+' rear radiator frame',(x,.94,.77 if tx else 1.18),(.48,.24,.25),coll,M['titanium'],.026)
    rz=.91 if tx else 1.32
    for j in range(8):
        box(name+' radiator cooling fin',(x-.20+j*.057,.94,rz),(.018,.25,.16),coll,M['steel'],.005)
    box(name+' rear terminal enclosure',(x+.43,.95,.78 if tx else 1.22),(.28,.22,.27),coll,paint,.032)
    for j in range(3):
        box(name+' terminal contact',(x+.35+j*.077,.82,.82 if tx else 1.26),(.035,.045,.07),coll,M['copper'],.006)
    # Painted role labels on the front cover, with a little asymmetric service annotation.
    text_decal(name+' role stencil','TX-01' if tx else 'RX-02',(.03,-.978,.847 if tx else .897),.09,coll)
    text_decal(name+' ILN stencil','ILN',(.57,-.86,.81 if tx else .86),.07,coll,rotation=(0,0,.55))
    if tx:
        for i in range(6):
            a=i*TAU/6+.045
            c=a+.44
            # Black vent cassette and exposed copper cooling slats on the raised crown.
            sector(name+' crown outer vent frame',[(1.077,1.49),(1.129,1.50),(1.129,1.60),(1.075,1.61)],c-.16,c+.16,coll,M['recess'],.012,steps=12)
            for j in range(5):
                aa=c-.11+j*.055
                sector(name+' crown copper fin',[(1.12,1.51),(1.145,1.52),(1.145,1.59),(1.12,1.60)],aa,aa+.02,coll,M['copper'],.004,steps=2)
            cylinder(name+' crown locking hex',.036,.024,polar(.95,a+.10,1.695),coll,M['titanium'],.003,6)
            for j in range(3):
                aa=a+.20+j*.13
                sector(name+' crown top scoring',[(.92,1.678),(.98,1.686),(.98,1.690),(.92,1.682)],aa,aa+.025,coll,M['steel'],0,steps=2)
    else:
        # Extra receive-side sensor and shielded power connector, visibly unlike TX.
        box(name+' receive sensor pedestal',(-.65,.75,1.14),(.20,.25,.25),coll,M['steel'],.025)
        box(name+' receive sensor glass',(-.65,.605,1.17),(.13,.045,.11),coll,M['recess'],.018)
        for j in range(3):
            box(name+' receive sensor lights',(-.69+j*.04,.577,1.17),(.018,.016,.05),coll,glow,.007)
        for i in range(4):
            a=math.radians(12+i*39+15)
            cylinder(name+' crescent locking socket',.045,.02,polar(1.08,a,1.216),coll,M['recess'],.004,24)
            cylinder(name+' crescent lock hex',.028,.027,polar(1.08,a,1.23),coll,M['steel'],.002,6)

for o in bpy.data.objects:
    if any(k in o.name for k in ['removable coil shoe','coil shoe inset']):o.location.z+=.052
    elif 'inset heat vent' in o.name:o.location.z+=.05

for s in [bpy.data.scenes['ILN - Provider'],bpy.data.scenes['ILN - Requester'],bpy.data.scenes['ILN - Presentation']]:
    s.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.25
    for o in s.objects:
        if o.type=='LIGHT':
            if 'upper left key' in o.name:o.data.energy=900
            elif 'cool fill' in o.name:o.data.energy=220
    s.eevee.taa_render_samples=64
show=bpy.data.scenes['ILN - Presentation']
bpy.context.window.scene=show
show.frame_set(89)
show.render.filepath=str(ROOT/'model-preview-v2.png')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'rounded-transfer-v1.blend'))
result={'file':bpy.data.filepath,'provider_objects':len(bpy.data.collections['ILN / PROVIDER TX'].objects),'requester_objects':len(bpy.data.collections['ILN / REQUESTER RX'].objects),'materials':len([m for m in bpy.data.materials if m.name.startswith('ILN /')])}
