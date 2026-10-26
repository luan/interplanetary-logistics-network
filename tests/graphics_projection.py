"""Check the actual Blender cameras against Factorio sprite placement, offline.

Execute in Blender with this mod's .blend loaded. No Factorio process is needed.
The test uses the prototype's real scale and shift, including the wider shadow
canvas, and measures rendered world points rather than inferring camera scale.
"""
import math
import re
from pathlib import Path
import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]

def sprite_parameters(filename):
    text=(ROOT/'data.lua').read_text()
    matches=[]
    for name,block in re.findall(r'filename = "([^"]+)",(.*?)(?=\n\s*},)',text,re.S):
        if not name.endswith('/'+filename):continue
        width=int(re.search(r'width = (\d+)',block)[1])
        height=int(re.search(r'height = (\d+)',block)[1])
        scale=float(re.search(r'scale = ([\d.]+)',block)[1])
        shift=tuple(map(float,re.search(r'shift = \{\s*([^,]+),\s*([^}]+)\}',block).groups()))
        matches.append((width,height,scale,shift))
    assert matches,filename+' has no prototype sprite'
    assert len(set(matches))==1,filename+' differs between its container and animation helpers'
    return matches[0]

def screen_point(scene,spec,point):
    width,height,scale,shift=spec
    p=world_to_camera_view(scene,scene.camera,Vector(point))
    return Vector(((p.x-.5)*width*scale+shift[0]*32,(.5-p.y)*height*scale+shift[1]*32))

def check_projections():
    failures=[]
    report={}
    # Factorio's square grid has physical Y spacing sqrt(2) at a 45-degree camera.
    # https://factorio.com/blog/post/fff-133
    points={'origin':(0,0,0),'east_tile':(1,0,0),'south_tile':(0,-math.sqrt(2),0)}
    expected={'origin':Vector((0,0)),'east_tile':Vector((32,0)),'south_tile':Vector((0,32))}
    for role,label in [('provider','PROVIDER TX'),('requester','REQUESTER RX')]:
        body=bpy.data.scenes['ILN - '+role.title()]
        shadow=bpy.data.scenes['ILN - '+role.title()+' Shadow']
        body_spec=sprite_parameters(role+'_animation_sheet_idle.png')
        shadow_spec=sprite_parameters(role+'_shadow.png')
        for tail in ['animation_sheet_active.png','emission_sheet_idle.png','emission_sheet_active.png']:
            if sprite_parameters(role+'_'+tail)!=body_spec:
                failures.append(role+' '+tail+' does not align with the idle body')
        report[role]={}
        for name,scene,spec in [('body',body,body_spec),('shadow',shadow,shadow_spec)]:
            scene.view_layers[0].update()
            observed={key:screen_point(scene,spec,point) for key,point in points.items()}
            report[role][name]={key:list(p) for key,p in observed.items()}
            for key,p in observed.items():
                if (p-expected[key]).length>.02:
                    failures.append(f'{role} {name} {key}: {tuple(round(v,3) for v in p)}, expected {tuple(expected[key])}')
        sun=next((o for o in shadow.objects if o.type=='LIGHT' and o.data.type=='SUN'),None)
        if sun is None:
            failures.append(role+' has no directional shadow light')
        else:
            ray=sun.matrix_world.to_quaternion()@Vector((0,0,-1))
            hit=Vector((-ray.x/ray.z,-ray.y/ray.z,0))
            cast=screen_point(shadow,shadow_spec,hit)-screen_point(shadow,shadow_spec,(0,0,0))
            report[role]['shadow_cast_screen_pixels']=list(cast)
            if cast.x<=0 or cast.y<=0:failures.append(role+' shadow must cast down and right on screen')
        bpy.context.window.scene=body
        body.frame_set(1)
        body.view_layers[0].update()
        graph=bpy.context.evaluated_depsgraph_get()
        floor_points=[]
        for obj in bpy.data.collections['ILN / '+label].all_objects:
            if obj.type not in {'MESH','CURVE','FONT'} or obj.hide_render:continue
            evaluated=obj.evaluated_get(graph)
            mesh=evaluated.to_mesh()
            if mesh is None:continue
            for vertex in mesh.vertices:
                point=evaluated.matrix_world@vertex.co
                floor_points.append(screen_point(body,body_spec,(point.x,point.y,0)))
            evaluated.to_mesh_clear()
        bounds=[min(p.x for p in floor_points),min(p.y for p in floor_points),max(p.x for p in floor_points),max(p.y for p in floor_points)]
        report[role]['model_floor_bounds_px']=bounds
        caster=next(o for o in shadow.objects if o.name.endswith('shadow caster'))
        shadow_floor=[]
        for vertex in caster.data.vertices:
            point=caster.matrix_world@vertex.co
            shadow_floor.append(screen_point(shadow,shadow_spec,(point.x,point.y,0)))
        shadow_bounds=[min(p.x for p in shadow_floor),min(p.y for p in shadow_floor),max(p.x for p in shadow_floor),max(p.y for p in shadow_floor)]
        report[role]['shadow_caster_floor_bounds_px']=shadow_bounds
        if max(abs(a-b) for a,b in zip(bounds,shadow_bounds))>.02:
            failures.append(role+' shadow caster does not match the fitted model base')
        # A centered base must fit the real collider in both tile axes. Height
        # projects above this floor box; it must not move the placement guide.
        prototype=(ROOT/'data.lua').read_text().split(f'name = "interplanetary-{role}-chest",',1)[1]
        box=re.search(r'collision_box = \{ \{ ([^,]+), ([^}]+) \}, \{ ([^,]+), ([^}]+) \} \}',prototype)
        collider=[float(v)*32 for v in box.groups()]
        for axis in range(2):
            lo,hi=bounds[axis],bounds[axis+2]
            if lo<collider[axis]-.1 or hi>collider[axis+2]+.1:
                failures.append(f'{role} base axis {axis}: {lo:.2f}..{hi:.2f}px exceeds collision footprint')
            if hi-lo<.9*(collider[axis+2]-collider[axis]):
                failures.append(f'{role} base axis {axis}: {hi-lo:.2f}px leaves more than 10% of collision footprint unused')
            if abs(lo+hi)>.5:
                failures.append(f'{role} base axis {axis}: center {(lo+hi)/2:.2f}px is offset from placement origin')
        contacts=[]
        for index in range(1,4):
            foot=next(o for o in bpy.data.collections['ILN / '+label].objects if o.name==label+f' landing foot {index} swept armor')
            evaluated=foot.evaluated_get(graph)
            mesh=evaluated.to_mesh()
            low=min((evaluated.matrix_world@v.co).z for v in mesh.vertices)
            evaluated.to_mesh_clear()
            contacts.append(low)
            if abs(low)>.002:failures.append(f'{role} foot {index}: contact height {low:.5f}, expected ground z=0')
        report[role]['foot_contact_heights']=contacts
    if failures:raise AssertionError('\n'.join(failures))
    return report

if __name__=='__main__':
    print(check_projections())
