"""Build the authored SOLARIT collector reference asset in Blender.

Run with Blender 4.5+:
  blender --background --python tools/create_high_end_harvester.py

The script saves an editable .blend source and exports the game GLB beside it.
Large forms are custom lofted / swept meshes; small repeated hardware is built
as detail geometry and static meshes are consolidated by material.
"""
from __future__ import annotations

import math
import os
import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT_DIR = os.path.join(ROOT, "assets", "models", "vehicles")
SOURCE_DIR = os.path.join(ROOT, "assets", "models", "source")
BLEND_PATH = os.path.join(SOURCE_DIR, "harvester.blend")
GLB_PATH = os.path.join(OUT_DIR, "harvester.glb")


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    # Materials are authored at module load and therefore already have zero
    # users here; retain them while clearing the startup scene.
    for datablocks in (bpy.data.meshes, bpy.data.curves):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)


def make_material(name, color, metallic=0.0, roughness=0.55, noise=0.0, emission=0.0):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1.0)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if "Emission Color" in bsdf.inputs and emission:
        bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    if noise:
        nodes = material.node_tree.nodes
        links = material.node_tree.links
        tex = nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = 38.0
        tex.inputs["Detail"].default_value = 2.0
        bump = nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = noise
        bump.inputs["Distance"].default_value = 0.025
        links.new(tex.outputs["Fac"], bump.inputs["Height"])
        links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return material


MAT = {
    "armor": make_material("01 · Veyra weathered field enamel", (0.48, 0.41, 0.29), 0.48, 0.48, 0.16),
    "shadow": make_material("02 · Graphite armor", (0.052, 0.068, 0.063), 0.66, 0.48, 0.20),
    "steel": make_material("03 · Brushed machine steel", (0.20, 0.25, 0.23), 0.82, 0.36, 0.22),
    "rubber": make_material("04 · Track elastomer", (0.032, 0.041, 0.039), 0.04, 0.82, 0.28),
    "track": make_material("05 · Track shoe manganese steel", (0.19, 0.22, 0.20), 0.75, 0.48, 0.24),
    "team": make_material("TeamColor · faction identification", (0.92, 0.95, 0.93), 0.24, 0.3, 0.05),
    "energy": make_material("06 · Solarit conduits", (0.035, 0.85, 0.72), 0.38, 0.23, 0.0, 1.5),
    "amber": make_material("07 · Industrial work lights", (1.0, 0.31, 0.035), 0.16, 0.28, 0.0, 1.1),
    "hazard": make_material("08 · Black yellow safety enamel", (0.92, 0.62, 0.17), 0.18, 0.52, 0.08),
    "glass": make_material("09 · Smoked optical glass", (0.027, 0.12, 0.12), 0.32, 0.18, 0.0, 0.16),
    "ore": make_material("10 · Raw Solarit in armored hopper", (0.05, 0.72, 0.61), 0.35, 0.25, 0.0, 0.8),
}

STATIC = {key: [] for key in MAT}
ANIMATED = []


def mesh_object(name, vertices, faces, material, animated_parent=None, bevel=0.0):
    mesh = bpy.data.meshes.new(name + " · mesh")
    # Author dimensions in game-space (X width, Y height, Z length/forward).
    # Blender is Z-up; map game-space into Blender so the GLTF exporter's
    # Z-up -> glTF-Y-up conversion restores Godot's X/Y/Z game-space exactly.
    blender_vertices=[(x,-z,y) for x,y,z in vertices]
    mesh.from_pydata(blender_vertices, [], faces)
    mesh.materials.append(MAT[material])
    mesh.validate(clean_customdata=False)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    if animated_parent is None:
        STATIC[material].append(obj)
    else:
        obj.parent = animated_parent
        ANIMATED.append(obj)
    if bevel:
        modifier = obj.modifiers.new("Fine machined edge radii", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        modifier.limit_method = "ANGLE"
    return obj


def empty(name, pivot=(0.0, 0.0, 0.0)):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    x,y,z=pivot
    obj.location = (x,-z,y)
    obj.empty_display_type = "PLAIN_AXES"
    obj.empty_display_size = 0.12
    return obj


def logical_origin(parent):
    """Return a node's Blender transform origin in authored game-space."""
    return (parent.location.x,parent.location.z,-parent.location.y)


def local_point(parent, point):
    origin=logical_origin(parent)
    return (origin[0]+point[0],origin[1]+point[1],origin[2]+point[2])


def local_box_mesh(name, center, size, material, bevel=0.0, parent=None, rotation_y=0.0):
    return box_mesh(name,local_point(parent,center),size,material,bevel,parent,rotation_y)


def local_cylinder_mesh(name, center, radius, depth, material, axis="Y", sides=16, parent=None, bevel=0.0):
    return cylinder_mesh(name,local_point(parent,center),radius,depth,material,axis,sides,parent,bevel)


def local_tube(name, points, radius, material, parent=None, sides=8):
    origin=logical_origin(parent)
    return tube(name,[(origin[0]+x,origin[1]+y,origin[2]+z) for x,y,z in points],radius,material,parent,sides)


def box_mesh(name, center, size, material, bevel=0.0, parent=None, rotation_y=0.0):
    x, y, z = center
    sx, sy, sz = (v / 2.0 for v in size)
    vertices = [(-sx,-sy,-sz),(sx,-sy,-sz),(sx,sy,-sz),(-sx,sy,-sz),
                (-sx,-sy,sz),(sx,-sy,sz),(sx,sy,sz),(-sx,sy,sz)]
    c, s = math.cos(rotation_y), math.sin(rotation_y)
    rotated = []
    for vx, vy, vz in vertices:
        px, pz = vx*c + vz*s, -vx*s + vz*c
        if parent:
            parent_game=(parent.location.x,parent.location.z,-parent.location.y)
            px += x-parent_game[0]
            py = vy+y-parent_game[1]
            pz += z-parent_game[2]
        else:
            px += x; py = vy+y; pz += z
        rotated.append((px,py,pz))
    return mesh_object(name, rotated, [(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(4,0,3,7)], material, parent, bevel)


def cylinder_mesh(name, center, radius, depth, material, axis="Y", sides=16, parent=None, bevel=0.0):
    cx, cy, cz = center
    verts = []
    for end in (-depth/2, depth/2):
        for i in range(sides):
            a = math.tau*i/sides
            u, v = radius*math.cos(a), radius*math.sin(a)
            if axis == "X": point=(cx+end,cy+u,cz+v)
            elif axis == "Z": point=(cx+u,cy+v,cz+end)
            else: point=(cx+u,cy+end,cz+v)
            if parent:
                parent_game=(parent.location.x,parent.location.z,-parent.location.y)
                point=(point[0]-parent_game[0],point[1]-parent_game[1],point[2]-parent_game[2])
            verts.append(point)
    faces=[]
    faces.append(tuple(range(sides-1,-1,-1)))
    faces.append(tuple(range(sides,sides*2)))
    for i in range(sides):
        j=(i+1)%sides
        faces.append((i,j,sides+j,sides+i))
    return mesh_object(name,verts,faces,material,parent,bevel)


def loft_hull(name, stations, material):
    """Watertight faceted armored hull from authored cross-section stations.

    Each station: z, half-width, bottom-y, upper-y, shoulder-y.
    The asymmetric shoulders create a genuine glacis and stepped armor profile.
    """
    verts=[]
    for z, w, bot, top, shoulder in stations:
        verts.extend([(-w,bot,z),(w,bot,z),(w,shoulder,z),(w*0.78,top,z),(-w*0.78,top,z),(-w,shoulder,z)])
    faces=[]
    faces.append((5,4,3,2,1,0))
    n=len(stations)
    for ring in range(n-1):
        a=ring*6; b=(ring+1)*6
        for i in range(6):
            j=(i+1)%6
            faces.append((a+i,a+j,b+j,b+i))
    faces.append(tuple((n-1)*6+i for i in range(6)))
    return mesh_object(name,verts,faces,material,None,0.035)


def tube(name, points, radius, material, parent=None, sides=8):
    verts=[]; faces=[]
    path=[Vector(p) for p in points]
    for idx,p in enumerate(path):
        tangent=(path[min(idx+1,len(path)-1)]-path[max(0,idx-1)]).normalized()
        ref=Vector((0,1,0)) if abs(tangent.dot(Vector((0,1,0))))<0.94 else Vector((1,0,0))
        u=tangent.cross(ref).normalized(); v=tangent.cross(u).normalized()
        for j in range(sides):
            a=math.tau*j/sides
            q=p+radius*(u*math.cos(a)+v*math.sin(a))
            verts.append(tuple(q))
    for i in range(len(path)-1):
        for j in range(sides):
            faces.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
    faces.extend([tuple(range(sides-1,-1,-1)),tuple((len(path)-1)*sides+j for j in range(sides))])
    if parent:
        parent_game=(parent.location.x,parent.location.z,-parent.location.y)
        verts=[(x-parent_game[0],y-parent_game[1],z-parent_game[2]) for x,y,z in verts]
    return mesh_object(name,verts,faces,material,parent)


def create_track_loop(side, x):
    """Swept, rounded rectangular belt loop; surface is real continuous mesh."""
    # Capsule centerline in the Y/Z plane. Front is -Z.
    radius=0.28; top_y=0.78; bottom_y=0.22; front_z=-1.42; rear_z=1.26
    centers=[]
    # top and bottom straight runs plus semicircular end caps
    for i in range(9): centers.append((x,top_y,front_z+(rear_z-front_z)*i/8))
    middle_y=(top_y+bottom_y)/2.0
    for i in range(1,13):
        a=math.pi/2 - math.pi*i/12
        centers.append((x,middle_y+radius*math.sin(a),rear_z+radius*math.cos(a)))
    for i in range(1,9): centers.append((x,bottom_y, rear_z-(rear_z-front_z)*i/8))
    for i in range(1,13):
        a=-math.pi/2 + math.pi*i/12
        centers.append((x,middle_y+radius*math.sin(a),front_z-radius*math.cos(a)))
    verts=[]
    for cx,y,z in centers:
        for dx in (-0.24,0.24): verts.append((cx+dx,y,z))
    faces=[]
    for i in range(len(centers)):
        j=(i+1)%len(centers)
        faces.append((i*2,i*2+1,j*2+1,j*2))
    mesh_object(f"{side} · seamless reinforced rubber belt",verts,faces,"rubber")
    # 36 articulated manganese shoes wrap the loop; alternating relief teeth
    # and inset fasteners produce a readable mechanical track at RTS scale.
    for i,(cx,y,z) in enumerate(centers[::2]):
        # Flat shoes follow the straight runs; round-end shoes are tangential.
        idx=i*2
        if idx < 8: ry=0.0
        elif idx < 20: ry=math.pi/2
        elif idx < 28: ry=0.0
        else: ry=-math.pi/2
        shoe=box_mesh(f"{side} · articulated track shoe {i:02d}",(cx,y,z),(0.505,0.10,0.205),"track",0.022,rotation_y=ry)
        # A raised grouser bar is modeled as its own narrow plate, then merged.
        box_mesh(f"{side} · traction grouser {i:02d}",(cx,y-0.045,z),(0.32,0.035,0.06),"steel",0.008,rotation_y=ry)
    # Individual running wheels / large end sprockets, with inset hub layers.
    for i,z in enumerate((-1.12,-0.53,0.08,0.68,1.06)):
        radius=0.285 if i in (0,4) else 0.205
        cylinder_mesh(f"{side} · road wheel {i+1}",(x,0.50,z),radius,0.12,"shadow","X",24,bevel=0.012)
        cylinder_mesh(f"{side} · machined wheel hub {i+1}",(x+(0.071 if x>0 else -0.071),0.50,z),radius*0.58,0.026,"hazard" if i in (0,4) else "steel","X",16,bevel=0.01)
        cylinder_mesh(f"{side} · hub fastener {i+1}",(x+(0.09 if x>0 else -0.09),0.50,z),0.044,0.03,"shadow","X",12)


def create_bucket():
    # Open, tapered ore hopper with thick rolled lip and a faceted inner basin.
    outer=[(-0.62,1.26,0.18),(0.62,1.26,0.18),(0.52,1.25,1.02),(-0.52,1.25,1.02),
           (-0.50,1.68,0.40),(0.50,1.68,0.40),(0.40,1.68,0.95),(-0.40,1.68,0.95)]
    faces=[(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(0,3,2,1)]
    mesh_object("Armored ore hopper · open tapered shell",outer,faces,"shadow",bevel=0.018)
    for side in (-1,1):
        tube("Hopper hydraulic brace",[(side*0.53,1.0,0.66),(side*0.67,1.25,0.68),(side*0.55,1.57,0.76)],0.045,"steel",sides=10)
        box_mesh("Hopper outer armor cheek",(side*0.61,1.37,0.55),(0.11,0.39,0.67),"armor",0.045)


def crystal_cluster_mesh(name, center, scale, parent):
    """Small individually faceted Solarit fragments for the cargo loadout."""
    cx,cy,cz=center
    ring=[]
    for i in range(6):
        a=math.tau*i/6
        ring.append((cx+math.cos(a)*scale*0.32,cy,cz+math.sin(a)*scale*0.32))
    vertices=ring+[(cx-scale*0.06,cy+scale,cz+scale*0.02),(cx+scale*0.04,cy+scale*0.48,cz-scale*0.07)]
    faces=[]
    for i in range(6):
        j=(i+1)%6
        faces.append((i,j,6 if i%2==0 else 7))
        faces.append((j,i,7))
    return mesh_object(name,vertices,faces,"ore",parent)


def create_cargo_and_damage(rig):
    # Each cargo stage adds two jagged facets within the hopper, so cache
    # variants at 0..8 units reflect the actual quantized simulation load.
    for stage in range(1,9):
        node=empty("CargoStage%02d"%stage,(0,0,0)); node.parent=rig
        base=stage-1
        lane=base%4
        row=base//4
        cx=-0.31+lane*0.20
        cz=0.46+row*0.20
        crystal_cluster_mesh("Solarit cargo shard %02dA"%stage,(cx,1.48+row*0.10,cz),0.22+(stage%3)*0.03,node)
        crystal_cluster_mesh("Solarit cargo shard %02dB"%stage,(cx+0.09,1.47+row*0.1,cz+0.04),0.16+(stage%2)*0.04,node)
    light=empty("DamageLight",(0,0,0)); light.parent=rig
    for i,(x,z) in enumerate(((-1.14,-0.54),(1.14,0.31),(0.52,-1.17))):
        vertices=[(x-0.10,1.31,z-0.17),(x+0.09,1.30,z-0.11),(x+0.04,1.30,z+0.15),(x-0.13,1.30,z+0.08),(x+0.01,1.37,z-0.01)]
        mesh_object("Light damage scorch facet %d"%i,vertices,[(0,1,4),(1,2,4),(2,3,4),(3,0,4)],"shadow",light)
    heavy=empty("DamageHeavy",(0,0,0)); heavy.parent=rig
    for i,(x,z) in enumerate(((-0.98,0.29),(0.97,-0.19),(-0.40,1.05),(0.31,-1.25))):
        vertices=[(x-0.16,1.26,z-0.16),(x+0.13,1.24,z-0.10),(x+0.08,1.27,z+0.18),(x-0.12,1.24,z+0.11),(x+0.02,1.14,z+0.01)]
        mesh_object("Heavy damage torn armor shard %d"%i,vertices,[(0,1,4),(1,2,4),(2,3,4),(3,0,4)],"hazard" if i%2==0 else "steel",heavy)


def create_cutter(rig):
    pivot=(0.0,0.52,-1.73)
    head=empty("HarvesterHead",pivot)
    rotor=empty("CutterDrumRotor",(0.0,0.0,0.0)); rotor.parent=head
    # In mesh-local coordinates, the cutter axis is X.
    local_center=(0.0,0.0,0.0)
    local_cylinder_mesh("Transverse rotary cutter drum",local_center,0.27,2.55,"steel","X",40,parent=rotor)
    local_cylinder_mesh("Cutter drum central solarit core",(0,0,0),0.15,2.58,"energy","X",24,parent=rotor)
    # Helical cutter flutes, segmented carbide teeth and guard fingers.
    for i in range(32):
        x=-1.20+i*0.077
        phase=(i%8)*math.tau/8
        y=0.34*math.cos(phase); z=0.34*math.sin(phase)
        local_box_mesh(f"Carbide cutter tooth {i+1:02d}",(x,y,z),(0.115,0.17,0.10),"hazard" if i%4==0 else "shadow",0.018,parent=rotor,rotation_y=phase)
    for i in range(11):
        x=-1.17+i*0.234
        local_cylinder_mesh(f"Drum retaining collar {i+1}",(x,0,0),0.292,0.045,"armor","X",32,parent=rotor)
    # Twin articulated outrigger arms connect the wide harvesting header.
    for side in (-1,1):
        local_box_mesh("Cutter outrigger forged arm",(side*0.95,-0.22,0.27),(0.22,0.19,0.62),"armor",0.035,parent=head,rotation_y=side*0.12)
        local_cylinder_mesh("Cutter arm joint pin",(side*0.95,-0.22,0.27),0.115,0.26,"hazard","X",20,parent=head)
        local_tube("Cutter hydraulic ram",[(side*0.79,-0.1,0.2),(side*0.77,0.04,0.08),(side*0.94,0.18,-0.10)],0.037,"steel",parent=head,sides=10)
        local_box_mesh("Header safety comb",(side*0.86,-0.05,0.50),(0.45,0.08,0.14),"shadow",0.022,parent=head)
    actuator=empty("CutterActuator",pivot)
    head.parent=actuator
    head.location=(0.0,0.0,0.0)
    actuator.parent=rig
    return head,actuator,rotor


def create_conveyor(rig):
    conveyor=empty("Conveyor",(0.0,0.0,0.0))
    # Sloped twin-railed conveyor from the cutter to the enclosed hopper.
    box_mesh("Ore conveyor armored bed",(0,1.05,-0.48),(1.12,0.12,1.72),"shadow",0.045,parent=conveyor,rotation_y=0.0)
    for side in (-1,1):
        tube("Conveyor raised steel rail",[(side*0.52,0.91,-1.24),(side*0.52,1.22,-0.55),(side*0.52,1.52,0.10)],0.055,"armor",parent=conveyor,sides=10)
        tube("Conveyor solarit conduit",[(side*0.45,0.94,-1.20),(side*0.45,1.23,-0.54),(side*0.45,1.47,0.08)],0.027,"energy",parent=conveyor,sides=8)
    # Six separated cleats can be phase shifted in the harvested clip.
    for i in range(6):
        z=-1.08+i*0.215
        y=0.96+(z+1.08)*0.26
        flight=empty(f"ConveyorFlight{i}",(0,0,0)); flight.parent=conveyor
        box_mesh(f"Conveyor flight {i+1}",(0,y,z),(0.80,0.075,0.085),"hazard" if i%3==0 else "steel",0.018,parent=flight)
    # Big access shield sides and roller ends make the conveyor read as a machine.
    for side in (-1,1):
        box_mesh("Conveyor side shield",(side*0.37,1.10,-0.55),(0.13,0.36,1.05),"armor",0.035,parent=conveyor,rotation_y=0.16)
        for z in (-1.10,0.02):
            cylinder_mesh("Conveyor idler roller",(side*0.31,1.1,z),0.095,0.66,"shadow","X",20,parent=conveyor)
    conveyor.parent=rig
    return conveyor


def add_hull_hardware():
    # Main silhouette: broad, tapered, stepped hull with a distinct front glacis.
    loft_hull("Primary armored chassis · faceted loft",[
        (-1.55,0.95,0.47,0.89,0.75),(-1.23,1.13,0.36,1.13,0.80),
        (-0.56,1.16,0.34,1.20,0.94),(0.64,1.12,0.34,1.25,0.96),
        (1.28,1.00,0.36,1.19,0.83),(1.52,0.82,0.43,0.97,0.74)],"shadow")
    loft_hull("Upper floating armor deck · chamfered",[
        (-1.11,0.83,0.92,1.32,1.17),(-0.75,0.98,0.95,1.52,1.25),
        (0.44,0.96,0.94,1.52,1.26),(1.12,0.82,0.92,1.37,1.18)],"armor")
    # Forward crew cabin and reinforced windshield give a clear direction cue.
    box_mesh("Forward armored operator cab",(0,1.42,-0.92),(1.18,0.62,0.48),"armor",0.09)
    box_mesh("Forward smoked armored viewport",(0,1.49,-1.167),(0.70,0.28,0.055),"glass",0.025,rotation_y=0)
    for x in (-0.55,0.55):
        tube("Cab rollover cage",[(x*0.78,1.18,-1.04),(x,1.78,-1.04),(x,1.75,-0.72)],0.045,"steel",sides=10)
    # Rear powerpack and protected processing bay distinguish it from a tank.
    box_mesh("Solarit separator processing chamber",(0,1.28,0.45),(1.55,0.65,1.04),"shadow",0.08)
    box_mesh("Processing chamber enamel armor",(0,1.66,0.45),(1.36,0.22,0.86),"armor",0.055)
    for x in (-0.57,0.57):
        box_mesh("Solarit chamber luminous status strip",(x,1.67,0.46),(0.075,0.045,0.62),"team",0.02)
        cylinder_mesh("Processing chamber pressure lock",(x*0.78,1.30,0.44),0.13,0.08,"steel","Z",20)
    # Hopper shell follows the processing chamber and stores collected ore.
    create_bucket()
    # Layered side armor, fasteners, service panels, vents, handholds.
    for side in (-1,1):
        x=side*1.035
        box_mesh("Replaceable side armor slab",(x,0.97,0.06),(0.20,0.48,1.37),"armor",0.055)
        box_mesh("Faction identification side plate",(side*1.148,1.06,0.05),(0.045,0.24,0.74),"team",0.018)
        for i,z in enumerate((-0.87,-0.49,-0.10,0.29,0.68,1.02)):
            cylinder_mesh("Armor captive bolt",(side*1.158,0.89,z),0.043,0.035,"steel","X",12)
        # Deep louvered radiator bank with raised vanes.
        box_mesh("Cooling intake recessed well",(side*0.82,1.34,0.84),(0.26,0.12,0.48),"shadow",0.025)
        for i in range(7):
            box_mesh("Cooling radiator fin",(side*(0.82+i*0.0),1.35,0.65+i*0.065),(0.25,0.035,0.027),"steel",0.006,rotation_y=side*0.10)
        tube("External hydraulic service loop",[(side*0.88,0.86,-0.95),(side*1.21,0.95,-0.84),(side*1.21,1.09,-0.45),(side*0.98,1.28,-0.31)],0.038,"hazard",sides=8)
        # Five knurled maintenance handles and two status lamps per side.
        for z in (-0.72,0.54):
            cylinder_mesh("Side status lamp socket",(side*1.15,1.49,z),0.085,0.045,"shadow","X",16)
            cylinder_mesh("Side status lamp",(side*1.19,1.49,z),0.05,0.04,"amber","X",16)
        for z in (-0.6,0.0,0.6):
            tube("External grab handle",[(side*1.12,1.42,z-0.10),(side*1.19,1.50,z-0.10),(side*1.19,1.50,z+0.10),(side*1.12,1.42,z+0.10)],0.022,"steel",sides=8)
    # Exhaust bank, air filters and cooling fans are visible from the isometric camera.
    for x in (-0.58,0.0,0.58):
        cylinder_mesh("Exhaust armored base",(x,1.60,1.05),0.15,0.13,"steel","Y",24)
        cylinder_mesh("Exhaust ceramic stack",(x,1.81,1.05),0.105,0.38,"armor","Y",24)
        cylinder_mesh("Exhaust dark throat",(x,2.01,1.05),0.061,0.018,"shadow","Y",20)
        for j in range(4):
            box_mesh("Exhaust heat fin",(x+(-0.14+j*0.09),1.60,1.21),(0.035,0.10,0.21),"steel",0.008)
    for x in (-0.72,0.72):
        cylinder_mesh("Powerpack fan guard ring",(x,1.40,0.88),0.22,0.075,"hazard","Y",32)
        cylinder_mesh("Powerpack fan hub",(x,1.44,0.88),0.075,0.085,"shadow","Y",20)
        for i in range(7):
            a=math.tau*i/7
            box_mesh("Cooling fan blade",(x+0.12*math.cos(a),1.45,0.88+0.12*math.sin(a)),(0.15,0.035,0.065),"steel",0.016,rotation_y=a)
    # Steps, rear towing points, warning bars, and front armor skid.
    for side in (-1,1):
        for i in range(3):
            box_mesh("Service access step",(side*(0.94+i*0.035),0.45,0.65-i*0.22),(0.20,0.075,0.15),"hazard",0.018)
        cylinder_mesh("Rear towing eye",(side*0.76,0.58,1.48),0.14,0.11,"steel","X",24)
        box_mesh("Front replaceable stone deflector",(side*0.67,0.48,-1.53),(0.48,0.22,0.18),"track",0.04,rotation_y=-side*0.12)
    for i in range(13):
        # High-contrast diagonal teeth on the cutter guard, above the ground.
        x=-0.93+i*0.155
        box_mesh("Cutter guard hazard tooth",(x,0.48,-1.56),(0.105,0.085,0.035),"hazard",0.006,rotation_y=0.65 if i%2 else -0.65)
    # Cab roof sensor mast and signal beacon.
    box_mesh("Sensor mast armored base",(0,1.80,-0.82),(0.32,0.12,0.28),"shadow",0.035)
    cylinder_mesh("Survey lidar rotating drum",(0,1.91,-0.82),0.12,0.17,"steel","Y",24)
    box_mesh("Survey lidar glass band",(0,1.93,-0.82),(0.255,0.055,0.12),"energy",0.018)
    for x in (-0.30,0.30):
        cylinder_mesh("Cab amber beacon",(x,1.84,-0.91),0.065,0.065,"amber","Y",16)


def create_animations(rig, head, cutter_actuator, cutter_rotor, conveyor):
    scene=bpy.context.scene
    scene.render.fps=30
    scene.frame_start=1
    scene.frame_end=40
    # Move drives the separated sprocket wheels; the continuous belt remains
    # visible, while the chassis response makes cached movement easy to read.
    sprockets=[]
    for side,x in (("L",-1.03),("R",1.03)):
        pivot=empty("Track%s"%side,(x,0.5,0.0)); pivot.parent=rig
        for z in (-1.12,1.06):
            wheel=empty("Track%sSprocket%s"%(side,"Front" if z<0 else "Rear"),(x,0.5,z)); wheel.parent=rig
            local_cylinder_mesh("Animated %s sprocket"%side,(0,0,0),0.235,0.14,"steel","X",28,parent=wheel)
            local_cylinder_mesh("Animated %s sprocket energy hub"%side,(0,0,0),0.10,0.17,"team","X",20,parent=wheel)
            sprockets.append(wheel)
    slats=[]
    # The conveyor flights are independently phased, so eight cached poses
    # visibly advance Solarit toward the hopper.
    for i in range(6):
        flight=bpy.data.objects.get("ConveyorFlight%d"%i)
        if flight is not None: slats.append(flight)
    door=empty("LoadingDoor",(0,1.23,1.22)); door.parent=rig
    box_mesh("Rear unloading hatch armored leaf",(0,1.25,1.22),(1.10,0.38,0.12),"armor",0.035,parent=door)
    for side in (-1,1):
        tube("Unloading hatch actuator",[(side*0.48,1.25,1.22),(side*0.66,1.15,1.38),(side*0.66,0.94,1.47)],0.04,"steel",parent=door,sides=10)
    # A side discharge flap stays readable from the fixed cache camera, so
    # unloading changes the silhouette without making the vehicle reverse.
    side_chute=empty("SideUnloadChute",(0.94,1.08,0.46)); side_chute.parent=rig
    local_box_mesh("Solarit side discharge armored flap",(0.10,0.0,0.0),(0.12,0.48,0.76),"energy",0.035,side_chute)
    local_box_mesh("Solarit side discharge chute rim",(0.15,-0.18,0.0),(0.16,0.08,0.80),"hazard",0.018,side_chute)
    local_cylinder_mesh("Side discharge hinge pin",(0.0,0.0,0.0),0.07,0.20,"steel","Y",20,side_chute)
    idle_signal=empty("IdleSignal",(0,1.85,-0.82)); idle_signal.parent=rig
    cylinder_mesh("Idle status beacon base",(0,1.85,-0.82),0.12,0.055,"shadow","Y",20,parent=idle_signal)
    cylinder_mesh("Idle status beacon lamp",(0,1.93,-0.82),0.075,0.06,"energy","Y",20,parent=idle_signal)

    def new_action(name):
        action=bpy.data.actions.new(name)
        action.use_fake_user=True
        action.layers.new("SOLARIT performance")
        action.layers[0].strips.new(type="KEYFRAME")
        return action

    def animate_rotation(action, obj, angles, axis_index=0):
        obj.animation_data_create(); obj.animation_data.action=action
        slot=action.slots.new("OBJECT",obj.name)
        obj.animation_data.action_slot=slot
        curve=action.fcurve_ensure_for_datablock(obj,"rotation_euler",index=axis_index,group_name=obj.name)
        for frame,angle in angles:
            key=curve.keyframe_points.insert(frame,angle,options={"FAST"})
            key.interpolation="LINEAR"
        curve.update()
        curve.modifiers.new("CYCLES")

    def animate_location(action,obj,offsets):
        obj.animation_data_create(); obj.animation_data.action=action
        slot=action.slots.new("OBJECT",obj.name)
        obj.animation_data.action_slot=slot
        curve=action.fcurve_ensure_for_datablock(obj,"location",index=1,group_name=obj.name)
        for frame,value in offsets:
            key=curve.keyframe_points.insert(frame,value,options={"FAST"})
            key.interpolation="LINEAR"
        curve.update()
        curve.modifiers.new("CYCLES")

    # Keep action datablocks for export. The GLTF exporter serializes clips by
    # action; the node tracks are validated after import by the Godot test.
    actions=[]
    idle=new_action("Idle")
    animate_rotation(idle,idle_signal,[(1,0.0),(21,0.025),(40,0.0)])
    actions.append(idle)
    move=new_action("Move")
    for wheel in sprockets:
        animate_rotation(move,wheel,[(1,0.0),(11,math.tau*0.25),(21,math.tau*0.5),(31,math.tau*0.75),(40,math.tau)])
    # Give the cached six-frame-per-second poses enough chassis response to read
    # at RTS scale while keeping the harvester's silhouette stable.
    animate_rotation(move,rig,[(1,0.0),(11,0.10),(21,0.0),(31,-0.10),(40,0.0)])
    animate_location(move,rig,[(1,0.0),(6,0.12),(11,0.0),(16,-0.08),(21,0.0),(26,0.12),(31,0.0),(36,-0.08),(40,0.0)])
    actions.append(move)
    harvest=new_action("Harvest")
    # Stronger work stroke and a steady powered drum make harvesting legible at
    # gameplay scale. The authored cache still samples the same eight frames.
    animate_rotation(harvest,cutter_actuator,[(1,0.0),(11,0.92),(21,0.0),(31,-0.92),(40,0.0)])
    animate_rotation(harvest,cutter_rotor,[(1,0.0),(11,math.pi*0.5),(21,math.pi),(31,math.pi*1.5),(40,math.tau)])
    for i,flight in enumerate(slats):
        animate_location(harvest,flight,[(1,-0.55+(i%2)*0.06),(11,-0.18+(i%2)*0.06),(21,0.18+(i%2)*0.06),(31,0.53+(i%2)*0.06),(40,-0.55+(i%2)*0.06)])
    actions.append(harvest)
    unload=new_action("Unload")
    animate_rotation(unload,door,[(1,0.0),(11,-0.2),(21,-0.62),(31,-0.34),(40,0.0)])
    animate_rotation(unload,head,[(1,0.0),(11,0.45),(21,0.9),(31,0.45),(40,0.0)])
    animate_rotation(unload,side_chute,[(1,0.0),(8,0.18),(16,0.72),(24,0.92),(32,0.48),(40,0.0)],axis_index=2)
    actions.append(unload)


def consolidate_static_meshes():
    # Apply bevels and merge the many small authored static parts by material.
    # Animated assemblies remain separate for GLB node animation.
    for material_key, objects in STATIC.items():
        if not objects:
            continue
        for obj in objects:
            bpy.context.view_layer.objects.active=obj
            obj.select_set(True)
            for modifier in list(obj.modifiers):
                bpy.ops.object.modifier_apply(modifier=modifier.name)
            obj.select_set(False)
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            if obj.name in bpy.data.objects:
                obj.select_set(True)
        if objects:
            bpy.context.view_layer.objects.active=objects[0]
            bpy.ops.object.join()
            merged=bpy.context.object
            merged.name="TeamColor" if material_key=="team" else "Static_%s"%material_key.title()
            merged.data.name=merged.name+" · consolidated mesh"
            # Keep a semantic material name for the Godot TeamColor hook.
            if material_key=="team":
                for slot in merged.material_slots:
                    slot.material.name="TeamColor · faction identification"


def consolidate_animated_meshes():
    # Merge siblings sharing a material under each animated controller. This
    # keeps moving parts addressable while limiting draw submissions.
    groups={}
    for obj in ANIMATED:
        if obj.name in bpy.data.objects and obj.type=="MESH" and obj.parent is not None:
            material_key=next((key for key,material in MAT.items() if obj.data.materials and obj.data.materials[0]==material),"")
            groups.setdefault((obj.parent,material_key),[]).append(obj)
    for (parent,material_key),objects in groups.items():
        if len(objects)<2: continue
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects: obj.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        bpy.ops.object.join()
        merged=bpy.context.object
        merged.name="%s_%s"%(parent.name,material_key.title())


def main():
    os.makedirs(OUT_DIR,exist_ok=True)
    os.makedirs(SOURCE_DIR,exist_ok=True)
    bpy.context.preferences.filepaths.save_version=0
    clear_scene()
    rig=empty("SOLARIT Harvester H09 Skimmer",(0,0,0))
    rig["asset_role"]="harvester"
    rig["forward_axis"]="-Z"
    rig["animation_contract"]="Idle,Move,Harvest,Unload"
    create_track_loop("TrackLeft",-1.03)
    create_track_loop("TrackRight",1.03)
    add_hull_hardware()
    create_cargo_and_damage(rig)
    head,cutter_actuator,cutter_rotor=create_cutter(rig)
    conveyor=create_conveyor(rig)
    create_animations(rig,head,cutter_actuator,cutter_rotor,conveyor)
    consolidate_static_meshes()
    consolidate_animated_meshes()
    # Save after static consolidation and export with clean identity transforms.
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True); bpy.context.view_layer.objects.active=rig
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type in {"MESH","EMPTY"}: obj.select_set(True)
    bpy.context.view_layer.objects.active=rig
    exporter=bpy.ops.export_scene.gltf
    allowed={p.identifier for p in exporter.get_rna_type().properties}
    options={"filepath":GLB_PATH,"export_format":"GLB","export_apply":True,
             "export_animations":True,"export_animation_mode":"ACTIONS",
             "export_force_sampling":True,"export_nla_strips":False,
             "export_yup":True,"export_extras":True,"export_materials":"EXPORT"}
    exporter(**{k:v for k,v in options.items() if k in allowed})
    print("SOLARIT HARVESTER ASSET DONE")
    print("BLEND:",BLEND_PATH)
    print("GLB:",GLB_PATH)
    print("Animation contract: Idle / Move / Harvest / Unload")
    print("Mesh nodes:",sum(1 for o in bpy.context.scene.objects if o.type=="MESH"))


if __name__=="__main__":
    main()
