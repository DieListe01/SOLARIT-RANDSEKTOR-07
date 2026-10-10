"""Author the first Blender-built SOLARIT industrial building set.

Run with Blender 4.5+ from the repository root:
  blender --background --python tools/create_building_assets.py

The scene is saved as an editable source file and each authored building is
exported separately as GLB. These models plug into the existing building cache
SubViewport through scripts/building_cache_painter.gd.
"""
from __future__ import annotations

import os
import math
import shutil
import subprocess
import sys
import importlib.util
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "models", "buildings")
SOURCE = os.path.join(ROOT, "assets", "models", "source")
os.makedirs(OUT, exist_ok=True)
os.makedirs(SOURCE, exist_ok=True)
TEXTURES = os.path.join(ROOT, "assets", "models", "textures", "industrial")
TEXTURE_AUTHOR = os.path.join(ROOT, "tools", "create_industrial_textures.py")

def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

def mat(name, color, metallic=0.0, rough=0.5, emission=0.0, texture_key=""):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    if texture_key:
        albedo_path = os.path.join(TEXTURES, texture_key + "_albedo.png")
        roughness_path = os.path.join(TEXTURES, texture_key + "_roughness.png")
        normal_path = os.path.join(TEXTURES, texture_key + "_normal.png")
        if not os.path.exists(albedo_path):
            python = shutil.which("python") or sys.executable
            subprocess.check_call([python, TEXTURE_AUTHOR])
        albedo = bpy.data.images.load(albedo_path, check_existing=True)
        albedo.colorspace_settings.name = "sRGB"
        color_node = m.node_tree.nodes.new("ShaderNodeTexImage")
        color_node.name = "SOLARIT UV albedo · panel seams and abrasion"
        color_node.image = albedo
        color_node.interpolation = "Linear"
        m.node_tree.links.new(color_node.outputs["Color"], bsdf.inputs["Base Color"])
        roughness = bpy.data.images.load(roughness_path, check_existing=True)
        roughness.colorspace_settings.name = "Non-Color"
        rough_node = m.node_tree.nodes.new("ShaderNodeTexImage")
        rough_node.name = "SOLARIT UV roughness"
        rough_node.image = roughness
        rough_node.interpolation = "Linear"
        m.node_tree.links.new(rough_node.outputs["Color"], bsdf.inputs["Roughness"])
        normal = bpy.data.images.load(normal_path, check_existing=True)
        normal.colorspace_settings.name = "Non-Color"
        normal_node = m.node_tree.nodes.new("ShaderNodeTexImage")
        normal_node.name = "SOLARIT UV micro-normal"
        normal_node.image = normal
        normal_node.interpolation = "Linear"
        normal_map = m.node_tree.nodes.new("ShaderNodeNormalMap")
        normal_map.inputs["Strength"].default_value = .22
        m.node_tree.links.new(normal_node.outputs["Color"], normal_map.inputs["Color"])
        m.node_tree.links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*color, 1)
        bsdf.inputs["Emission Strength"].default_value = emission
    return m

M = {
    "armor": mat("Ceramic armor · weathered field enamel", (.50,.43,.31), .42,.56,0,"ceramic"),
    "dark": mat("Graphite structural steel", (.075,.09,.078), .68,.48,0,"graphite"),
    "steel": mat("Machined steel", (.29,.33,.29), .78,.38,0,"steel"),
    "team": mat("TeamColor · faction enamel", (.035,.82,.71), .25,.34,.85,"enamel"),
    "amber": mat("Amber work lights", (1,.30,.035), .12,.24,1.4),
    "glass": mat("Smoked sensor glass", (.035,.17,.17), .45,.18,.18),
    "rubber": mat("Conduit insulation", (.018,.025,.023), .05,.72,0,"rubber"),
    "hazard": mat("Safety ochre", (.93,.60,.14), .2,.54,0,"safety"),
}

def bevel(obj, amount=.06, segments=2):
    mod = obj.modifiers.new("Forged edge radii", "BEVEL")
    mod.width = amount
    mod.segments = segments
    mod = obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
    mod.keep_sharp = True
    return obj

def game_to_blender(point):
    """Convert the asset kit's documented X/Y-up/Z-depth coordinates to Blender Z-up."""
    return (point[0], point[2], point[1])

def cube(name, loc, size, material, radius=.04, rotation=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.name = name
    o.location = game_to_blender(loc)
    o.dimensions = (size[0], size[2], size[1])
    o.rotation_euler.z = rotation
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material)
    if radius:
        bevel(o, radius)
    return o

def cyl(name, loc, radius, depth, material, vertices=16, axis="Y"):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=game_to_blender(loc))
    o = bpy.context.object
    o.name = name
    # The primitive's Blender Z axis maps to the kit's vertical Y axis.
    if axis == "Z": o.rotation_euler.x = 1.5708
    if axis == "X": o.rotation_euler.y = 1.5708
    o.data.materials.append(material)
    bevel(o, .025, 2)
    return o

def pipe(name, points, radius, material):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 12
    curve.bevel_depth = radius
    curve.bevel_resolution = 3
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points)-1)
    for p, co in zip(spline.bezier_points, points):
        p.co = game_to_blender(co)
        p.handle_left_type = p.handle_right_type = "AUTO"
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    return obj

def prism(name, outline, y0, y1, material, radius=.035):
    """A purpose-shaped X/Z footprint extruded on the game's vertical Y axis."""
    count=len(outline)
    vertices=[game_to_blender((x,y0,z)) for x,z in outline]
    vertices += [game_to_blender((x,y1,z)) for x,z in outline]
    faces=[tuple(reversed(range(count))),tuple(range(count,2*count))]
    for i in range(count):
        j=(i+1)%count
        faces.append((i,j,count+j,count+i))
    mesh=bpy.data.meshes.new(name+" forged profile")
    mesh.from_pydata(vertices,[],faces)
    mesh.materials.append(material)
    mesh.update()
    obj=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    if radius: bevel(obj,radius,3)
    return obj

def octagon(w,d,cut=.24):
    return [(-w/2+cut,-d/2),(w/2-cut,-d/2),(w/2,-d/2+cut),(w/2,d/2-cut),
            (w/2-cut,d/2),(-w/2+cut,d/2),(-w/2,d/2-cut),(-w/2,-d/2+cut)]

def profiled_shell(name, outline, inset, y0, y_shoulder, y_top, material):
    """Faceted, sloped armor hull; its planes are custom, not a scaled box."""
    count=len(outline)
    upper=[(x*(1-inset),z*(1-inset)) for x,z in outline]
    verts=[game_to_blender((x,y0,z)) for x,z in outline]
    verts += [game_to_blender((x,y_shoulder,z)) for x,z in outline]
    verts += [game_to_blender((x,y_top,z)) for x,z in upper]
    faces=[tuple(reversed(range(count)))]
    for i in range(count):
        j=(i+1)%count
        faces.append((i,j,count+j,count+i))
        faces.append((count+i,count+j,2*count+j,2*count+i))
    faces.append(tuple(range(2*count,3*count)))
    mesh=bpy.data.meshes.new(name+" cast shell")
    mesh.from_pydata(verts,[],faces); mesh.materials.append(material); mesh.update()
    obj=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj)
    bevel(obj,.035,2)
    return obj

def axis_cylinder(name, loc, radius, depth, material, axis="y", vertices=20):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=game_to_blender(loc))
    obj=bpy.context.object; obj.name=name
    if axis=="x": obj.rotation_euler.y=math.pi/2
    elif axis=="z": obj.rotation_euler.x=math.pi/2
    obj.data.materials.append(material)
    bevel(obj,.018,2)
    return obj

def torus(name, loc, major, minor, material, rotation=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=major,minor_radius=minor,major_segments=32,minor_segments=8,location=game_to_blender(loc))
    obj=bpy.context.object; obj.name=name; obj.data.materials.append(material)
    if rotation is not None:
        obj.rotation_euler=rotation
    for face in obj.data.polygons: face.use_smooth=True
    return obj

def parent_preserving_world(child, parent):
    bpy.context.view_layer.update()
    if child.type=="CURVE":
        bpy.ops.object.select_all(action="DESELECT")
        child.select_set(True); bpy.context.view_layer.objects.active=child
        bpy.ops.object.convert(target="MESH")
    if child.type=="MESH":
        # Several authored profile/pipe helpers store their vertices directly
        # in kit coordinates while their object origin is still at (0,0,0).
        # Rebase such geometry before parenting so glTF doesn't apply the pivot
        # translation a second time to its world-space vertices.
        world=child.matrix_world.copy()
        points=[world @ vertex.co for vertex in child.data.vertices]
        if points:
            center=sum(points,Vector())/len(points)
            for vertex,point in zip(child.data.vertices,points): vertex.co=point-center
            child.data.update()
            world=Matrix.Translation(center)
    else:
        world=child.matrix_world.copy()
    child.parent=parent
    child.matrix_parent_inverse=Matrix.Identity(4)
    bpy.context.view_layer.update()
    child.matrix_basis=parent.matrix_world.inverted() @ world
    bpy.context.view_layer.update()

def pivot(name, location):
    obj=bpy.data.objects.new(name,None)
    bpy.context.collection.objects.link(obj)
    obj.empty_display_type="ARROWS"; obj.empty_display_size=.18
    obj.location=game_to_blender(location)
    return obj

def dish_surface(name, center, radius, depth, material):
    """A shallow parabolic mesh reflector, instead of a flat cylinder plate."""
    cx,cy,cz=center
    radial_steps=7; segments=32
    vertices=[game_to_blender((cx,cy,cz+depth))]
    for ring_index in range(1,radial_steps+1):
        r=ring_index/radial_steps
        for segment in range(segments):
            angle=math.tau*segment/segments
            vertices.append(game_to_blender((cx+math.cos(angle)*radius*r,cy+math.sin(angle)*radius*r,cz+depth*(1-r*r))))
    faces=[]
    for segment in range(segments): faces.append((0,1+segment,1+(segment+1)%segments))
    for ring_index in range(1,radial_steps):
        a0=1+(ring_index-1)*segments; b0=1+ring_index*segments
        for segment in range(segments):
            nxt=(segment+1)%segments
            faces.append((a0+segment,b0+segment,b0+nxt,a0+nxt))
    mesh=bpy.data.meshes.new(name+" paraboloid"); mesh.from_pydata(vertices,[],faces); mesh.materials.append(material); mesh.update()
    obj=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj)
    solid=obj.modifiers.new("Pressed reflector shell","SOLIDIFY"); solid.thickness=.035
    bevel(obj,.015,2)
    return obj

def ribbed_box(prefix, center, width, height, count, material, orientation="front"):
    x,y,z=center
    for i in range(count):
        px=x-width*.5+width*(i+.5)/count
        if orientation=="front":
            cube(prefix+" louver %02d"%i,(px,y,z), (width/count*.54,height,.035),material,.009,rotation=-.10)
        else:
            cube(prefix+" radiator fin %02d"%i,(px,y,z), (width/count*.44,.035,height),material,.009)

def cable_riser(name, points, material=M["steel"]):
    pipe(name,points,.035,material)

def brace(name, a, b, thickness, material):
    """Round structural tie between game-space points."""
    av=Vector(game_to_blender(a)); bv=Vector(game_to_blender(b)); delta=bv-av
    bpy.ops.mesh.primitive_cylinder_add(vertices=10,radius=thickness,depth=delta.length,location=(av+bv)*.5)
    obj=bpy.context.object; obj.name=name; obj.rotation_mode="QUATERNION"
    obj.rotation_quaternion=delta.to_track_quat("Z","Y")
    obj.data.materials.append(material); bevel(obj,.01,1)
    return obj

def warning_band(name, x, y, z, width, depth, material=None):
    material=material or M["hazard"]
    for i in range(9):
        px=x-width*.5+(i+.5)*width/9
        if i%2==0: cube(name+" diagonal marker",(px,y,z),(width/9*.58,.025,depth),material,.004,rotation=-.42)

def parent_parts(prefix, location, objects):
    group=pivot(prefix,location)
    for obj in objects:
        if obj != group: parent_preserving_world(obj,group)
    return group

def _is_animated(obj):
    animated={"CommandSensorPivot","ReactorRotor","UnloadGate","ProductionCrane","AssemblyArmLeft","AssemblyArmRight","TurretPivot","RadarRotor","RepairArmLeft","RepairArmRight","OrdnanceLift","UpgradeStage2"}
    parent=obj
    while parent is not None:
        if parent.name in animated: return True
        parent=parent.parent
    return False

def _smart_uv(obj):
    if obj.type!="MESH" or len(obj.data.polygons)==0: return
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True); bpy.context.view_layer.objects.active=obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(island_margin=.018,area_weight=.18,correct_aspect=True,scale_to_bounds=True)
    bpy.ops.object.mode_set(mode="OBJECT")

def optimize_static_meshes(objects, kind):
    """Keep moving assemblies and hero silhouettes distinct; merge fixed trim by material."""
    signatures={
        "core":["Raised armored command citadel","Command roof wing left"],
        "power":["Primary reactor containment ring"],"refinery":["Ore conveyor belt"],
        "factory":["Overhead bridge crane","Hydraulic deployment ramp"],
        "tower":["Rotating gunhouse","Armored turret race"],"radar":["Signal dish core"],
        "repair":["Drive-through service door","Open repair pad"],"armory":["Sealed ammunition canister"],
    }
    signatures_for_asset=signatures[kind]
    buckets={}
    retained=[]
    for obj in list(objects):
        if obj.type=="CURVE" and not _is_animated(obj):
            bpy.ops.object.select_all(action="DESELECT"); obj.select_set(True); bpy.context.view_layer.objects.active=obj
            bpy.ops.object.convert(target="MESH")
        if obj.type!="MESH" or _is_animated(obj) or obj.name.startswith("TeamColor") or any(signature in obj.name for signature in signatures_for_asset):
            retained.append(obj)
            continue
        material=obj.data.materials[0] if obj.data.materials else None
        buckets.setdefault(material,[]).append(obj)
    merged=[]
    for material,parts in buckets.items():
        if len(parts)<2:
            merged.extend(parts)
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for part in parts: part.select_set(True)
        bpy.context.view_layer.objects.active=parts[0]
        bpy.ops.object.join()
        parts[0].name="%s · %s industrial detail"%(kind.title(),material.name if material else "unpainted")
        merged.append(parts[0])
    for obj in merged+retained:
        if obj.name in bpy.context.scene.objects and obj.type=="MESH": _smart_uv(obj)
    return merged+retained

def base(kind,w=2.8,d=2.8):
    contour=octagon(w,d,.30)
    if kind=="power": contour=[(-w*.5,-d*.28),(-w*.28,-d*.5),(w*.28,-d*.5),(w*.5,-d*.28),(w*.5,d*.28),(w*.28,d*.5),(-w*.28,d*.5),(-w*.5,d*.28)]
    elif kind=="refinery": contour=[(-w*.5,-d*.32),(-w*.35,-d*.5),(w*.40,-d*.5),(w*.5,-d*.32),(w*.5,d*.32),(w*.35,d*.5),(-w*.40,d*.5),(-w*.5,d*.32)]
    elif kind=="factory": contour=[(-w*.5,-d*.42),(-w*.34,-d*.5),(w*.34,-d*.5),(w*.5,-d*.42),(w*.5,d*.5),(w*.32,d*.5),(w*.32,d*.35),(-w*.32,d*.35),(-w*.32,d*.5),(-w*.5,d*.5)]
    elif kind=="tower": contour=octagon(w,d,.39)
    elif kind=="radar": contour=[(-w*.35,-d*.5),(w*.35,-d*.5),(w*.5,-d*.32),(w*.5,d*.32),(w*.35,d*.5),(-w*.35,d*.5),(-w*.5,d*.32),(-w*.5,-d*.32)]
    elif kind=="repair": contour=[(-w*.5,-d*.5),(w*.5,-d*.5),(w*.5,d*.5),(w*.32,d*.5),(w*.32,-d*.22),(-w*.32,-d*.22),(-w*.32,d*.5),(-w*.5,d*.5)]
    elif kind=="armory": contour=[(-w*.5,-d*.34),(-w*.34,-d*.5),(w*.34,-d*.5),(w*.5,-d*.34),(w*.5,d*.34),(w*.34,d*.5),(-w*.34,d*.5),(-w*.5,d*.34)]
    prism("Load-spreading cast foundation",contour,.02,.30,M["dark"],.045)
    inset=[(x*.92,z*.92) for x,z in contour]
    prism("Replaceable graphite service deck",inset,.30,.41,M["steel"],.025)
    for index,(x,z) in enumerate(contour):
        cube("Foundation shear key %02d"%index,(x*.94,.18,z*.94),(.14,.35,.14),M["steel"],.024)
    # Visible service rails break up the edge only where mechanics need it.
    if kind in ["factory","repair","refinery"]:
        for side in [-1,1]:
            for z in [-d*.33,d*.33]:
                if kind=="factory" and z>0: continue
                cube("Flush service rail",(side*w*.43,.34,z),(.10,.12,.25),M["hazard"],.02)
    # A broad owner enamel panel makes allegiance legible at RTS zoom rather
    # than relying on tiny lamps. It stays inside the footprint to avoid crop.
    badge_y=0.56 if kind not in ["tower","radar"] else 0.72
    cube("TeamColor faction identity shield",(0,badge_y,d*.465),(w*.30,.16,.055),M["team"],.022)

def wall_panels(w,d,y=.85):
    for side in [-1,1]:
        for x in [-w*.32,0,w*.32]:
            cube("Recessed service hatch",(x,y,side*d*.47),(.38,.34,.055),M["dark"],.035)
            cube("Hatch inset",(x,y,side*(d*.47+.034)),(.25,.19,.025),M["steel"],.025)
            for dx in [-.13,.13]: cyl("Hatch fastener",(x+dx,y-.11,side*(d*.47+.055)),.025,.018,M["hazard"],8,"Y")
    for z in [-d*.32,d*.32]:
        for x in [-w*.42,w*.42]:
            cube("Structural corner rail",(x,.88,z),(.12,1.0,.14),M["steel"],.025)

def vents(w,d,y=1.12):
    for x in [-w*.30,-w*.18,-w*.06,.06*w,.18*w,.30*w]:
        cube("Louver channel",(x,y,d*.472),(.06,.38,.035),M["dark"],.015)
        cube("Louver blade",(x,y,d*.49),(.055,.035,.035),M["steel"],.012,rotation=-.16)

def markings(w,d):
    for x in [-w*.32,w*.32]:
        for z in [-d*.32,d*.32]:
            cube("TeamColor" if x<0 and z<0 else "TeamColor luminous column",(x,.74,z),(.085,.72,.075),M["team"],.025)
    for x in [-w*.35,-w*.17,w*.17,w*.35]:
        cyl("Amber perimeter lamp",(x,.48,d*.46),.035,.045,M["amber"],10,"Y")

def make(kind, footprint):
    before=set(bpy.context.scene.objects)
    w,d = footprint
    base(kind,w,d)
    if kind == "core":
        cube("Command bunker lower hull",(0,.78,0),(w*.78,.82,d*.72),M["dark"],.13)
        profiled_shell("Angled ceramic armor shell",octagon(w*.84,d*.78,.24),.12,.92,1.28,1.57,M["armor"])
        prism("Raised armored command citadel",[(-w*.27,-d*.24),(w*.18,-d*.24),(w*.26,-d*.17),(w*.26,d*.16),(w*.17,d*.23),(-w*.27,d*.23)],1.43,2.10,M["dark"],.045)
        # A split, offset command roof makes the core read as a low bunker,
        # instead of another flat industrial roof at the battlefield camera.
        cube("Command roof wing left",(-w*.24,1.72,-.03),(w*.38,.18,d*.68),M["steel"],.07,rotation=-.12)
        cube("Command roof wing right",(w*.24,1.72,-.03),(w*.38,.18,d*.68),M["steel"],.07,rotation=.12)
        cube("Sensor bridge glazing",(0,1.90,d*.063),(w*.35,.20,.035),M["glass"],.025)
        cube("Roof command light",(0,2.21,-.16),(w*.3,.07,.13),M["team"],.025)
        # Narrow, deep-set view slits and the projecting blast-entry make it read
        # as a protected command bunker rather than an ordinary warehouse.
        for side in [-1,1]:
            cube("Protected observation slit",(side*w*.18,1.91,d*.234),(.22,.075,.025),M["glass"],.012)
            cube("Slit armored brow",(side*w*.18,1.98,d*.25),(.31,.075,.08),M["steel"],.018)
            cube("Bunker side cheek plate",(side*w*.395,.99,0),(.095,.47,d*.48),M["steel"],.026,rotation=side*.10)
        prism("Blast door vestibule",[(-.42,.94),(.42,.94),(.36,1.20),(-.36,1.20)],.42,.86,M["steel"],.018)
        for side in [-1,1]:
            pipe("Armored external cable",[(side*.76,.58,.9),(side*.81,1.0,.68),(side*.74,1.55,.55)],.035,M["team"])
            brace("Command bastion diagonal rib",(side*1.05,.52,-.78),(side*.90,1.18,-.72),.055,M["dark"])
        for x in [-.66,-.33,0,.33,.66]:
            cube("Command deck ventilation fin",(x,1.65,-d*.32),(.06,.22,.19),M["steel"],.012)
        sensor=pivot("CommandSensorPivot",(0,2.20,-.18))
        torus("Command sensor bearing",(0,2.22,-.18),.20,.025,M["hazard"])
        axis_cylinder("Protected sensor drum",(0,2.36,-.18),.105,.22,M["glass"])
        axis_cylinder("Sensor whisker",(0,2.54,-.18),.022,.26,M["team"])
        for obj in list(bpy.context.scene.objects):
            if obj not in before and obj.name.startswith(("Command sensor bearing","Protected sensor drum","Sensor whisker")):
                parent_preserving_world(obj,sensor)
        cube("Blast door with inset",(0,.58,d*.38),(w*.42,.43,.09),M["steel"],.055)
    elif kind == "power":
        profiled_shell("Reactor containment cathedral",octagon(w*.90,d*.90,.29),.16,.42,.89,1.18,M["dark"])
        prism("Primary reactor pressure vessel collar",octagon(.98,.98,.22),1.10,1.40,M["steel"],.035)
        axis_cylinder("Primary reactor containment ring",(0,1.44,-.08),.56,.30,M["steel"],"y",32)
        rotor=pivot("ReactorRotor",(0,1.58,-.08))
        induction=torus("Reactor induction ring lower",(0,1.58,-.08),.48,.065,M["team"])
        parent_preserving_world(induction,rotor)
        axis_cylinder("Ceramic reactor crown",(0,1.69,-.08),.37,.38,M["armor"],"y",32)
        axis_cylinder("Luminous reactor aperture",(0,1.90,-.08),.24,.055,M["team"],"y",32)
        torus("Containment pressure gasket",(0,1.45,-.08),.595,.026,M["hazard"])
        for i,(x,z,height_value) in enumerate([(-.67,-.36,.92),(.67,-.36,.92),(-.67,.46,.72),(.67,.46,.72)]):
            axis_cylinder("Thermal exchange vessel %02d"%i,(x,.67+height_value*.5,z),.18,height_value,M["armor"],"y",24)
            for y in [.78,1.08,1.38 if height_value>.8 else 1.17]:
                if y < .67+height_value:
                    torus("Vessel clamp and isolation ring",(x,y,z),.195,.035,M["team"] if y==.78 else M["steel"])
            ribbed_box("Radiator bank %02d"%i,(x+(.21 if x<0 else -.21),1.03,z),.25,.56,7,M["dark"],"side")
            axis_cylinder("Vented stack crown",(x,.68+height_value,z),.145,.10,M["dark"],"y",16)
        for x in [-.58,.58]:
            pipe("Primary coolant return",[(x,.53,-.61),(x,.82,-.61),(x,1.22,-.48),(x,1.44,-.25)],.045,M["team"])
            pipe("Secondary coolant feed",[(x,.52,.62),(x,.92,.62),(x,1.12,.42),(x,1.36,.34)],.033,M["steel"])
        for i in range(8):
            angle=i*math.tau/8
            brace("Reactor pressure tie",(math.cos(angle)*.51,.62,-.08+math.sin(angle)*.51),(math.cos(angle)*.36,1.60,-.08+math.sin(angle)*.36),.033,M["hazard"])
        prism("High-voltage distribution bus",[(-.78,.64),(.78,.64),(.70,.82),(-.70,.82)],.53,.68,M["team"],.025)
        for x in [-.55,-.18,.18,.55]:
            cube("Power output terminal",(x,.76,d*.42),(.12,.25,.12),M["steel"],.018)
            torus("Terminal insulating ring",(x,.88,d*.42),.075,.018,M["amber"])
        cube("Reactor operator console",(0,.78,-d*.44),(w*.40,.46,.18),M["dark"],.035)
        for i in range(5): cube("Reactor live telemetry",(-.28+i*.14,1.04,-d*.44),(.075,.06,.025),M["team"] if i<4 else M["amber"],.01)
    elif kind == "refinery":
        # Keep processing equipment squat and horizontal so it cannot be
        # mistaken for the power plant's vertical cooling stacks.
        profiled_shell("Ore separation hall",[(-1.18,-.55),(.52,-.55),(.96,-.20),(.96,.48),(.58,.70),(-1.18,.70)],.055,.42,.78,1.12,M["dark"])
        prism("Faceted process roof",[(-1.12,-.55),(.50,-.55),(.90,-.17),(.90,.49),(.50,.64),(-1.12,.64)],1.12,1.31,M["armor"],.04)
        for i,x in enumerate([-.72,-.10,.52]):
            axis_cylinder("Horizontal fractionation drum",(x,.96,-.34),.24,.78,M["steel"],"x",32)
            for end in [-.33,.33]: axis_cylinder("Drum end flange",(x+end,.96,-.34),.285,.065,M["armor"],"x",32)
            for ring_x in [-.20,0,.20]: axis_cylinder("Drum weld ring",(x+ring_x,.96,-.34),.255,.035,M["team"] if i==1 else M["dark"],"x",28)
            cube("Drum ID plate",(x,.97,-.04),(.22,.16,.04),M["amber"],.025)
            for fin in range(9): cube("Process-drum cooling vane",(x-.30+fin*.075,1.27,-.34),(.038,.16,.24),M["steel"],.008,rotation=-.12)
        # Long, sloped conveyor and a deep receiving throat define the refinery
        # in the high oblique game view; its moving belt is a separate mesh.
        prism("Ore receiving apron",[(-1.02,.40),(1.02,.40),(.91,.89),(-.91,.89)],.42,.60,M["steel"],.03)
        profiled_shell("Armored unload hopper",[(-.70,.35),(.70,.35),(.57,.94),(-.57,.94)],.23,.61,1.13,1.27,M["dark"])
        prism("Hopper throat",[(-.43,.78),(.43,.78),(.37,.92),(-.37,.92)],1.16,1.26,M["team"],.018)
        for x in [-.66,.66]: pipe("Hopper support brace",[(x,.4,d*.36),(x,.9,d*.36),(x,.9,d*.12)],.04,M["steel"])
        for i in range(7): axis_cylinder("Conveyor idler",(-.82+i*.28,.42,-d*.39),.052,.82,M["steel"],"x",12)
        cube("Ore conveyor belt",(.02,.49,-d*.39),(2.02,.075,.70),M["rubber"],.03,rotation=-.13)
        for i in range(7):
            cube("Conveyor cleat",(-.82+i*.28,.54,-d*.39),(.045,.055,.64),M["hazard"],.012,rotation=-.13)
            brace("Conveyor trestle",(-.82+i*.28,.36,-.83),(-.82+i*.28,.50,-.39),.018,M["steel"])
        for x in [-.62,.62]: pipe("Refinery feed pipe",[(x,.86,-.12),(x,1.40,-.20),(x,1.42,-.58)],.045,M["team"])
        gate=pivot("UnloadGate",(.12,.70,.68))
        shutter=cube("Collector docking shutter",(.12,.65,.91),(.90,.24,.10),M["steel"],.025)
        status_strip=cube("Docking status strip",(.12,.80,.94),(.56,.045,.03),M["team"],.009)
        parent_preserving_world(shutter,gate); parent_preserving_world(status_strip,gate)
        for side in [-1,1]:
            collar=torus("Dock transfer collar",(side*.56,.72,.80),.105,.025,M["hazard"],(math.pi/2,0,0))
            parent_preserving_world(collar,gate)
        cube("Refinery operator cab",(-1.02,.78,-.12),(.34,.58,.42),M["armor"],.035)
        cube("Refinery smoked control glazing",(-1.02,.91,.096),(.24,.16,.025),M["glass"],.01)
        for i in range(4): cube("Control console status %d"%i,(-1.12+i*.066,1.10,.085),(.038,.055,.018),M["team"] if i<3 else M["amber"],.006)
        for z in [-.70,-.43,-.16,.11]: pipe("Process manifold bypass",[(-.78,1.14,z),(-.64,1.46,z),(.63,1.46,z),(.86,1.22,z)],.022,M["steel"])
        for x in [-.72,.70]:
            cube("Refinery service catwalk",(x,1.15,.58),(.16,.06,.40),M["steel"],.012)
            for i in range(5): cube("Catwalk anti-slip tooth",(x-.06+i*.03,1.19,.58),(.016,.018,.34),M["hazard"],.003)
    elif kind == "factory":
        # An open-frame assembly hangar; roof is deliberately sparse so the
        # crane and vehicle-scale bay remain readable from above.
        prism("Welded hangar chassis",[(-1.05,-.95),(1.05,-.95),(1.25,-.67),(1.25,.58),(.94,.98),(-.94,.98),(-1.25,.58),(-1.25,-.67)],.42,.83,M["dark"],.04)
        profiled_shell("Left armored roof shoulder",[(-1.30,-.98),(-.54,-.98),(-.54,.88),(-1.18,.88)],.06,1.08,1.47,1.60,M["armor"])
        profiled_shell("Right armored roof shoulder",[(.54,-.98),(1.30,-.98),(1.18,.88),(.54,.88)],.06,1.08,1.47,1.60,M["armor"])
        cube("Dark vehicle bay recess",(0,.96,d*.385),(w*.60,1.02,.08),M["rubber"],.025)
        for x in [-w*.35,w*.35]:
            cube("Hangar load column",(x,.96,d*.4),(.17,1.27,.18),M["steel"],.035)
            for y in [.48,.72,.96,1.2]: cube("Column gusset",(x,y,d*.49),(.22,.055,.055),M["hazard"],.015)
        # Overhead travelling crane, rails and service umbilicals.
        for z in [-d*.29,d*.29]: cube("Crane runway",(0,1.85,z),(w*.76,.12,.11),M["steel"],.03)
        crane=pivot("ProductionCrane",(0,1.70,0))
        bridge=cube("Overhead bridge crane",(0,1.7,0),(w*.66,.16,.16),M["team"],.04)
        parent_preserving_world(bridge,crane)
        for x in [-.55,.55]:
            cable=pipe("Crane hoist cable",[(x,1.68,0),(x,1.35,0),(x,.96,0)],.025,M["steel"])
            hoist=cube("Powered chain hoist casing",(x,1.58,0),(.17,.22,.22),M["dark"],.025)
            parent_preserving_world(cable,crane); parent_preserving_world(hoist,crane)
        cube("Hydraulic deployment ramp",(0,.47,d*.61),(w*.72,.13,.72),M["steel"],.05)
        for x in [-.62,-.42,-.22,0,.22,.42,.62]: cube("Ramp traction tooth",(x,.55,d*.65),(.1,.045,.035),M["hazard"],.01)
        for side in [-1,1]:
            arm=pivot("AssemblyArmLeft" if side<0 else "AssemblyArmRight",(side*.90,1.05,-.18))
            upper=brace("Welding robot upper link",(side*.90,1.05,-.18),(side*.60,1.50,-.18),.070,M["steel"])
            lower=brace("Welding robot forearm",(side*.60,1.50,-.18),(side*.28,1.20,.12),.052,M["dark"])
            tool=cube("Welding torch head",(side*.28,1.20,.12),(.15,.12,.18),M["amber"],.022)
            for obj in [upper,lower,tool]: parent_preserving_world(obj,arm)
        cube("Assembly roller bed",(0,.49,-.10),(1.62,.12,1.46),M["steel"],.035)
        for i in range(8): axis_cylinder("Vehicle bay roller",(-.69+i*.197,.57,-.10),.065,1.40,M["dark"],"x",12)
        warning_band("Hangar threshold warning",0,.57,d*.25,1.62,.07)
        for side in [-1,1]:
            for y in [.88,1.20,1.52]:
                brace("Portal truss diagonal",(side*1.14,y,-.68),(side*.94,y+.23,-.47),.025,M["steel"])
        for x in [-.88,0,.88]:
            cube("Bay work light",(x,1.56,.44),(.16,.07,.045),M["amber"],.015)
            cube("Exhaust extractor plenum",(x,1.70,-.65),(.31,.10,.25),M["dark"],.02)
        for i in range(4): cube("Factory power umbilical anchor",(-.84+i*.56,.72,-.62),(.17,.19,.14),M["team"],.022)
    elif kind == "tower":
        prism("Bastion plinth",octagon(w*.96,d*.96,.28),.40,.82,M["dark"],.04)
        prism("Sloped gun emplacement",octagon(w*.78,d*.78,.30),.78,1.10,M["armor"],.025)
        torus("Armored turret race",(0,1.12,0),.42,.075,M["steel"])
        gun=pivot("TurretPivot",(0,1.15,0))
        turret_hull=prism("Rotating gunhouse",[(-.31,-.27),(.20,-.27),(.34,-.12),(.34,.27),(-.28,.27)],.98,1.43,M["armor"],.025)
        parent_preserving_world(turret_hull,gun)
        glacis=prism("Turret forward mantlet",[(-.32,.12),(.16,.12),(.12,.52),(-.26,.52)],1.18,1.55,M["steel"],.018)
        parent_preserving_world(glacis,gun)
        optic=cube("Optic array",(0,1.43,.31),(.25,.12,.06),M["glass"],.018)
        parent_preserving_world(optic,gun)
        barrel=axis_cylinder("Autocannon barrel",(0,1.35,.77),.074,.69,M["dark"],"z",16)
        parent_preserving_world(barrel,gun)
        muzzle=axis_cylinder("Muzzle shroud",(0,1.35,1.11),.12,.18,M["steel"],"z",20)
        parent_preserving_world(muzzle,gun)
        bore=axis_cylinder("Recessed barrel bore",(0,1.35,1.208),.055,.018,M["rubber"],"z",16)
        parent_preserving_world(bore,gun)
        recoil=torus("Recoil collar",(0,1.35,.48),.095,.022,M["hazard"],(math.pi/2,0,0))
        parent_preserving_world(recoil,gun)
        for side in [-1,1]:
            fin=cube("Barrel heat sink",(side*.14,1.36,.72),(.08,.18,.44),M["steel"],.016)
            parent_preserving_world(fin,gun)
            cylinder=axis_cylinder("Counterweight canister",(side*.30,1.28,.05),.07,.35,M["dark"],"y",12)
            parent_preserving_world(cylinder,gun)
        cube("Turret ammunition feed",(0,.92,-.20),(.35,.22,.42),M["dark"],.025)
        for i in range(4): cube("Ammunition feed indicator",(-.14+i*.09,1.04,-.22),(.04,.05,.025),M["amber"],.006)
        for i in range(5): cube("Bastion side heat louver",(-w*.44,.70,-.19+i*.09),(.04,.035,.065),M["steel"],.006)
    elif kind == "radar":
        profiled_shell("Signal operations block",octagon(w*.90,d*.86,.26),.12,.42,.86,1.12,M["dark"])
        prism("Sensor roof armor",octagon(w*.94,d*.91,.25),1.12,1.29,M["armor"],.025)
        for x in [-.5,-.25,0,.25,.5]: cube("Cooling fin",(x,1.43,-.12),(.08,.24,.46),M["steel"],.025)
        cube("Radar console fascia",(0,.83,d*.43),(w*.60,.24,.065),M["steel"],.018)
        for i in range(7): cube("Signal receiver window",(-.42+i*.14,.87,d*.47),(.075,.11,.018),M["team"] if i%2==0 else M["glass"],.007)
        for side in [-1,1]:
            axis_cylinder("Mast support foot",(side*.24,1.53,-.4),.075,.40,M["steel"],"y",12)
            brace("Dish mast guywire",(side*.34,1.16,-.25),(side*.09,2.05,-.4),.016,M["hazard"])
        mast=axis_cylinder("Antenna mast",(0,2.0,-.4),.045,.88,M["steel"],"y",16)
        radar=pivot("RadarRotor",(0,2.18,-.4))
        dish=dish_surface("Signal dish core",(0,2.31,-.40),.61,.23,M["team"])
        parent_preserving_world(dish,radar)
        ring=torus("Reflector lip",(0,2.31,-.4),.60,.025,M["steel"],(math.pi/2,0,0))
        parent_preserving_world(ring,radar)
        for i in range(12):
            angle=math.tau*i/12
            rib=brace("Parabolic dish radial spine",(0,2.31,-.17),(math.cos(angle)*.59,2.31+math.sin(angle)*.59,-.40),.014,M["steel"])
            parent_preserving_world(rib,radar)
        horn=axis_cylinder("Feed horn",(0,2.31,-.12),.065,.24,M["amber"],"z",12)
        parent_preserving_world(horn,radar)
        for x in [-.12,0,.12]:
            arm=brace("Dish tripod receiver brace",(x,2.20,-.40),(0,2.31,-.12),.018,M["hazard"])
            parent_preserving_world(arm,radar)
        cube("Radar battery cabinet",(.55,.70,-.20),(.32,.45,.42),M["steel"],.028)
        for i in range(5): cube("Radar status ladder",(.39,.60+i*.08,.02),(.11,.025,.02),M["team"] if i<4 else M["amber"],.005)
    elif kind == "repair":
        # The workshop is a drive-through gantry around an exposed repair pad,
        # not a closed warehouse box.
        prism("Workshop control pod",[(-.92,-.55),(-.30,-.55),(-.30,.45),(-.92,.45)],.42,.93,M["dark"],.035)
        prism("Open repair pad",[(-.73,-.92),(.73,-.92),(.82,.70),(.62,.86),(-.62,.86),(-.82,.70)],.36,.53,M["steel"],.025)
        for x in [-.58,.58]:
            for z in [-.54,.54]:
                cube("Hydraulic lift plate",(x,.56,z),(.26,.18,.26),M["team"],.04)
                axis_cylinder("Lift ram",(x,.69,z),.045,.30,M["steel"],"y",12)
        for x in [-w*.36,w*.36]:
            prism("Lift gantry pillar",[(x-.09,-.55),(x+.09,-.55),(x+.09,-.24),(x-.09,-.24)],.50,1.90,M["steel"],.02)
            cube("Gantry warning beacon",(x,2.0,-d*.3),(.21,.12,.21),M["amber"],.03)
            for z in [-.45,-.25,-.05,.15,.35]: cube("Gantry indexed rail",(x-.10,1.15,z),(.025,.55,.04),M["hazard"],.006)
        cube("Overhead service bridge",(0,1.92,-d*.3),(w*.8,.17,.2),M["team"],.045)
        for x in [-.55,-.28,0,.28,.55]: pipe("Suspended repair lead",[(x,1.82,-d*.3),(x,1.3,-d*.3),(x,.94,-d*.12)],.025,M["amber"])
        cube("Drive-through service door",(0,.74,d*.39),(w*.48,.72,.08),M["rubber"],.035)
        for side in [-1,1]:
            arm=pivot("RepairArmLeft" if side<0 else "RepairArmRight",(side*.68,1.38,-.18))
            upper=brace("Repair manipulator upper",(side*.68,1.38,-.18),(side*.40,1.02,.14),.06,M["steel"])
            lower=brace("Repair manipulator forearm",(side*.40,1.02,.14),(side*.28,.79,.40),.043,M["dark"])
            tool=cube("Repair welding torch",(side*.28,.79,.40),(.13,.12,.10),M["amber"],.018)
            clamp=cube("Repair clamp jaw",(side*.25,.71,.43),(.20,.045,.08),M["steel"],.012)
            for obj in [upper,lower,tool,clamp]: parent_preserving_world(obj,arm)
        for i in range(4):
            cabinet=cube("Sealed spare parts drawer %02d"%i,(-.77,.64+i*.13,.34),(.22,.10,.30),M["steel"],.014)
            cube("Drawer latch",(-.77,.64+i*.13,.50),(.06,.025,.022),M["hazard"],.004)
        cube("Diagnostic terminal",(-.75,1.21,.31),(.30,.22,.12),M["dark"],.02)
        for i in range(3): cube("Diagnostic readout",(-.83+i*.075,1.25,.378),(.052,.10,.012),M["team"] if i<2 else M["amber"],.006)
    elif kind == "armory":
        profiled_shell("Ordnance magazine",octagon(w*.88,d*.82,.25),.10,.43,.88,1.34,M["dark"])
        prism("Sloped ceramic magazine roof",[(-.80,-.70),(.80,-.70),(.88,-.48),(.61,.70),(-.61,.70),(-.88,-.48)],1.30,1.56,M["armor"],.03)
        for x in [-.62,-.32,.32,.62]:
            prism("External armored rack",[(x-.12,-.38),(x+.12,-.38),(x+.12,.39),(x-.12,.39)],.48,1.36,M["steel"],.018)
            for y in [.64,.88,1.12]:
                case=cube("Sealed ammunition canister",(x,y,.52),(.21,.18,.14),M["hazard"],.035)
                axis_cylinder("Canister locking collar",(x,y+.11,.52),.085,.035,M["dark"],"y",12)
        # A recessed loading trench and its traverse rail explain where weapons
        # and armour leave the building instead of presenting a blank facade.
        prism("Armament loading dock",[(-.52,.53),(.52,.53),(.43,.91),(-.43,.91)],.43,.62,M["dark"],.02)
        cube("Blast-lock entry",(0,.72,d*.42),(w*.36,.48,.09),M["rubber"],.03)
        for side in [-1,1]:
            rail=cube("Magazine transfer rail",(side*.50,1.72,-.05),(.075,.07,1.15),M["steel"],.015)
            brace("Magazine gantry stanchion",(side*.50,1.0,-.53),(side*.50,1.76,-.53),.025,M["steel"])
        crane=pivot("OrdnanceLift",(0,1.72,0))
        hoist=cube("Armament transfer trolley",(0,1.66,-.05),(.37,.14,.35),M["team"],.028)
        hook=axis_cylinder("Suspended ordnance hook",(0,1.37,-.05),.026,.48,M["steel"],"y",10)
        parent_preserving_world(hoist,crane); parent_preserving_world(hook,crane)
        for x in [-.49,-.16,.16,.49]:
            axis_cylinder("Rooftop extraction vent",(x,1.72,-.52),.09,.28,M["steel"],"y",16)
            torus("Blast vent cowl",(x,1.87,-.52),.095,.018,M["hazard"])
        # The second upgrade adds a distinct, visible prototype energy module.
        stage2=pivot("UpgradeStage2",(0,0,0))
        axis_cylinder("Prototype weapon capacitor",(0,1.95,-.38),.16,.35,M["team"],"y",20)
        torus("Prototype capacitor guard",(0,1.98,-.38),.24,.035,M["steel"])
        for side in [-1,1]: pipe("Capacitor feed",[(side*.20,1.8,-.38),(side*.36,1.63,-.38),(side*.48,1.52,-.38)],.028,M["team"])
    # Avoid applying the same wall panels and roof louvers to every structure:
    # the distinctive machinery above should control each building's read.
    markings(w,d)
    # Different foundation breaks echo each silhouette instead of repeating a
    # continuous rectangular outline on every asset.
    if kind in ["core","factory","armory"]:
        for x in [-w*.42,w*.42]: cube("Segmented side skid",(x,.36,0),(.12,.12,d*.56),M["steel"],.025)
    return [obj for obj in bpy.context.scene.objects if obj not in before]

def main():
    clear()
    bpy.context.preferences.filepaths.save_version=0
    specs={"core":(2.8,2.8),"power":(1.85,1.85),"refinery":(2.8,1.85),"factory":(2.8,2.8),"tower":(1.0,1.0),"radar":(1.85,1.85),"repair":(1.85,1.85),"armory":(1.85,1.85)}
    exports=[]
    for kind, size in specs.items():
        created=make(kind,size)
        created=optimize_static_meshes(created,kind)
        team_obj=next((obj for obj in created if obj.name.startswith("TeamColor")),None)
        group=bpy.data.collections.new("Asset · "+kind)
        bpy.context.scene.collection.children.link(group)
        for obj in created:
            for collection in list(obj.users_collection): collection.objects.unlink(obj)
            group.objects.link(obj)
        exports.append((kind,created,group,team_obj))
    for index,(kind,objects,_group,team_obj) in enumerate(exports):
        original_team_name=team_obj.name if team_obj is not None else ""
        previous_team=next((obj for obj in bpy.context.scene.objects if obj!=team_obj and obj.name=="TeamColor"),None)
        if previous_team is not None: previous_team.name="TeamColor source backup"
        if team_obj is not None: team_obj.name="TeamColor"
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects: obj.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,kind+".glb"),export_format="GLB",use_selection=True,export_apply=True,export_yup=True)
        print("Exported authored building:",kind)
        if team_obj is not None: team_obj.name=original_team_name
        if previous_team is not None: previous_team.name="TeamColor"
        offset=Vector((index%4*4.2,0,index//4*4.2))
        # Move only each asset's roots. Moving both a parent pivot and its
        # children would double the transform and make parts float away.
        for obj in objects:
            if obj.parent is None: obj.location+=offset
    postprocess_path=os.path.join(ROOT,"tools","externalize_glb_textures.py")
    spec=importlib.util.spec_from_file_location("externalize_glb_textures",postprocess_path)
    texture_pipeline=importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(texture_pipeline)
    texture_pipeline.externalize_directory(__import__("pathlib").Path(OUT))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE,"industrial_buildings.blend"))

if __name__ == "__main__":
    main()
