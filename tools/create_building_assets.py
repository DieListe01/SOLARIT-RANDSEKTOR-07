"""Author the first Blender-built SOLARIT industrial building set.

Run with Blender 4.5+ from the repository root:
  blender --background --python tools/create_building_assets.py

The scene is saved as an editable source file and each authored building is
exported separately as GLB. These models plug into the existing building cache
SubViewport through scripts/building_cache_painter.gd.
"""
from __future__ import annotations

import os
import bpy
from mathutils import Vector
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "models", "buildings")
SOURCE = os.path.join(ROOT, "assets", "models", "source")
os.makedirs(OUT, exist_ok=True)
os.makedirs(SOURCE, exist_ok=True)

def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

def mat(name, color, metallic=0.0, rough=0.5, emission=0.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*color, 1)
        bsdf.inputs["Emission Strength"].default_value = emission
    return m

M = {
    "armor": mat("Ceramic armor · warm ivory", (.69,.60,.41), .32,.42),
    "dark": mat("Graphite structural steel", (.075,.09,.078), .68,.38),
    "steel": mat("Machined steel", (.29,.33,.29), .78,.28),
    "team": mat("TeamColor · faction enamel", (.035,.82,.71), .25,.28,1.1),
    "amber": mat("Amber work lights", (1,.30,.035), .12,.24,1.4),
    "glass": mat("Smoked sensor glass", (.035,.17,.17), .45,.18,.18),
    "rubber": mat("Conduit insulation", (.018,.025,.023), .05,.72),
    "hazard": mat("Safety ochre", (.93,.60,.14), .2,.45),
}

def bevel(obj, amount=.06, segments=2):
    mod = obj.modifiers.new("Forged edge radii", "BEVEL")
    mod.width = amount
    mod.segments = segments
    mod = obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
    mod.keep_sharp = True
    return obj

def cube(name, loc, size, material, radius=.04, rotation=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.name = name
    o.dimensions = size
    o.rotation_euler.z = rotation
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material)
    if radius:
        bevel(o, radius)
    return o

def cyl(name, loc, radius, depth, material, vertices=16, axis="Z"):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc)
    o = bpy.context.object
    o.name = name
    if axis == "Y": o.rotation_euler.x = 1.5708
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
        p.co = co
        p.handle_left_type = p.handle_right_type = "AUTO"
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    return obj

def base(w=2.8,d=2.8):
    cube("Layered armored foundation", (0,.16,0),(w,d,.32),M["dark"],.11)
    cube("Ceramic foundation cap", (0,.36,0),(w*.92,d*.9,.12),M["armor"],.045)
    for x in [-w*.42,w*.42]:
        for y in [-d*.4,d*.4]:
            cube("Corner cast foot",(x,.22,y),(.22,.36,.22),M["steel"],.04)

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
    base(w,d)
    if kind == "core":
        cube("Command bunker lower hull",(0,.78,0),(w*.78,.82,d*.72),M["dark"],.13)
        cube("Angled ceramic armor shell",(0,1.36,-.03),(w*.82,.58,d*.76),M["armor"],.12)
        cube("Raised armored command citadel",(0,1.87,-.16),(w*.48,.62,d*.42),M["dark"],.12)
        cube("Sensor bridge glazing",(0,1.94,d*.063),(w*.35,.24,.035),M["glass"],.025)
        cube("Roof command light",(0,2.21,-.16),(w*.3,.07,.13),M["team"],.025)
        for side in [-1,1]:
            pipe("Armored external cable",[(side*.76,.58,.9),(side*.81,1.0,.68),(side*.74,1.55,.55)],.035,M["team"])
        cube("Blast door with inset",(0,.58,d*.38),(w*.42,.43,.09),M["steel"],.055)
    elif kind == "power":
        cube("Reactor pressure vessel housing",(0,.87,0),(w*.7,.9,d*.7),M["dark"],.14)
        cube("Asymmetric armored reactor shroud",(0,1.43,-.02),(w*.75,.33,d*.75),M["armor"],.11)
        for x in [-w*.28,0,w*.28]:
            cyl("Ceramic heat exchanger",(x,1.48,-.12),.21,.88,M["armor"],20)
            cyl("Induction collar",(x,1.11,-.12),.245,.13,M["team"],20)
            cyl("Vented exchanger cap",(x,1.94,-.12),.15,.11,M["steel"],16)
            cyl("Cap aperture",(x,2.005,-.12),.07,.02,M["dark"],12)
        for x in [-.72,.72]:
            for z in [-.35,.35]: pipe("Reactor coolant loop",[(x,.8,z),(x,1.22,z),(x,1.55,z*.7)],.038,M["steel"])
        cube("High voltage busbar",(0,.72,d*.46),(w*.62,.15,.09),M["team"],.03)
    elif kind == "refinery":
        cube("Ore separation hall",(-.25,.85,-.12),(w*.62,.9,d*.72),M["dark"],.14)
        cube("Faceted ceramic process shell",(-.25,1.39,-.16),(w*.67,.32,d*.77),M["armor"],.1)
        # Three pressure columns, each with real flanges, weld rings and pipe returns.
        for i,x in enumerate([-.78,0,.78]):
            cyl("Fractionation pressure drum",(x,1.22,.36),.22,.91,M["armor"],24)
            for z in [.81,1.0,1.48,1.65]: cyl("Welded vessel ring",(x,z,.36),.236,.045,M["steel"],24)
            cyl("Dark vent crown",(x,1.71,.36),.14,.1,M["dark"],20)
            cyl("Pressure relief valve",(x,1.81,.36),.07,.09,M["amber"],12)
            pipe("Manifold return",[(x,1.15,.2),(x,1.88,.02),(x*.65,1.9,-.5)],.045,M["team"])
        cube("Ore receiving apron",(.12,.46,d*.44),(w*.68,.16,.48),M["steel"],.07)
        cube("Armored unload hopper",(.12,.79,d*.37),(w*.43,.54,.39),M["dark"],.1)
        # Tapered intake mouth, support trusses and segmented conveyor rollers.
        cube("Ore hopper lip",(.12,1.08,d*.46),(w*.48,.09,.16),M["team"],.04)
        for x in [-.6,.6]:
            pipe("Hopper support brace",[(x,.4,d*.39),(x,.9,d*.39),(x,.9,d*.13)],.04,M["steel"])
        for i in range(5): cyl("Conveyor idler",(-.62+i*.31,.45,-d*.37),.055,.78,M["steel"],12,"X")
        cube("Black belt and cleats",(0,.5,-d*.37),(1.55,.07,.66),M["rubber"],.03,rotation=-.1)
        for x in [-.62,.62]: pipe("Feed pipe",[(x,.9,-.15),(x,1.55,-.15),(x,1.65,.1)],.055,M["team"])
    elif kind == "factory":
        cube("Welded hangar chassis",(0,.88,0),(w*.82,1.12,d*.74),M["dark"],.15)
        # Tall open bay reads as a vehicle-scale opening, framed with load-bearing beams.
        cube("Upper armored roof block",(0,1.62,-.03),(w*.83,.43,d*.79),M["armor"],.10)
        cube("Dark vehicle bay recess",(0,.86,d*.385),(w*.62,.86,.08),M["rubber"],.025)
        for x in [-w*.35,w*.35]:
            cube("Hangar load column",(x,.96,d*.4),(.17,1.27,.18),M["steel"],.035)
            for y in [.48,.72,.96,1.2]: cube("Column gusset",(x,y,d*.49),(.22,.055,.055),M["hazard"],.015)
        # Overhead travelling crane, rails and service umbilicals.
        for z in [-d*.29,d*.29]: cube("Crane runway",(0,1.85,z),(w*.76,.12,.11),M["steel"],.03)
        cube("Overhead bridge crane",(0,1.7,0),(w*.66,.13,.13),M["team"],.04)
        for x in [-.55,.55]: pipe("Crane hoist cable",[(x,1.68,0),(x,1.35,0),(x,.96,0)],.025,M["steel"])
        cube("Hydraulic deployment ramp",(0,.47,d*.54),(w*.6,.13,.5),M["steel"],.05)
        for x in [-.62,-.42,-.22,0,.22,.42,.62]: cube("Ramp traction tooth",(x,.55,d*.65),(.1,.045,.035),M["hazard"],.01)
    elif kind == "tower":
        cube("Bastion plinth",(0,.56,0),(w*.8,.48,d*.8),M["dark"],.12)
        cyl("Armored turret race",(0,.95,0),.48,.18,M["steel"],32)
        cyl("Rotating gunhouse",(0,1.18,0),.39,.43,M["armor"],12)
        cube("Optic array",(0,1.29,.33),(.24,.14,.08),M["glass"],.025)
        cyl("Autocannon barrel",(0,1.17,.63),.095,.72,M["dark"],12,"Y")
        cyl("Muzzle shroud",(0,1.17,.96),.135,.18,M["steel"],12,"Y")
        for x in [-.25,.25]: cube("Barrel heat sink",(x,1.17,.61),(.07,.2,.44),M["steel"],.02)
    elif kind == "radar":
        cube("Signal operations block",(0,.82,0),(w*.78,.88,d*.74),M["dark"],.13)
        cube("Sensor roof armor",(0,1.32,0),(w*.84,.18,d*.81),M["armor"],.07)
        for x in [-.5,-.25,0,.25,.5]: cube("Cooling fin",(x,1.48,-.12),(.08,.24,.46),M["steel"],.025)
        cyl("Hardened mast base",(0,1.55,-.4),.19,.22,M["team"],20)
        cyl("Antenna mast",(0,2.0,-.4),.045,.88,M["steel"],12)
        # Open parabolic dish, with radial ribs instead of a flat plate.
        dish=cyl("Signal dish core",(0,2.38,-.4),.43,.10,M["team"],32)
        dish.rotation_euler.x=1.25
        for x in [-.28,0,.28]: pipe("Dish radial rib",[(x,2.18,-.4),(x*.8,2.42,-.4),(0,2.63,-.4)],.025,M["steel"])
        cyl("Feed horn",(0,2.56,-.4),.075,.22,M["amber"],12)
    elif kind == "repair":
        cube("Workshop armored core",(0,.77,0),(w*.74,.82,d*.7),M["dark"],.13)
        cube("Service roof deck",(0,1.26,0),(w*.82,.16,d*.8),M["armor"],.07)
        for x in [-w*.36,w*.36]:
            cube("Lift gantry pillar",(x,1.18,-d*.3),(.16,1.55,.16),M["steel"],.035)
            cube("Gantry warning beacon",(x,2.0,-d*.3),(.21,.12,.21),M["amber"],.03)
        cube("Overhead service bridge",(0,1.92,-d*.3),(w*.8,.17,.2),M["team"],.045)
        for x in [-.55,-.28,0,.28,.55]: pipe("Suspended repair lead",[(x,1.82,-d*.3),(x,1.3,-d*.3),(x,.94,-d*.12)],.025,M["amber"])
        cube("Drive-through service door",(0,.74,d*.39),(w*.48,.72,.08),M["rubber"],.035)
    elif kind == "armory":
        cube("Ordnance magazine",(0,.86,0),(w*.76,.98,d*.72),M["dark"],.13)
        cube("Sloped ceramic magazine roof",(0,1.47,-.02),(w*.82,.28,d*.78),M["armor"],.09)
        for x in [-.62,-.32,.32,.62]:
            cube("External armored rack",(x,.91,d*.38),(.14,.84,.16),M["steel"],.035)
            for y in [.62,.88,1.14]: cube("Sealed ammunition canister",(x,y,d*.46),(.21,.18,.14),M["hazard"],.035)
        for x in [-.45,-.15,.15,.45]: cyl("Roof vent",(x,1.68,-.45),.08,.25,M["steel"],12)
        cube("Blast-lock entry",(0,.62,d*.4),(w*.36,.48,.09),M["rubber"],.03)
    wall_panels(w,d)
    vents(w,d)
    markings(w,d)
    # Contact shadow and a low perimeter curb anchor the structures on terrain.
    for x in [-w*.47,w*.47]: cube("Continuous side skid",(x,.36,0),(.12,.12,d*.76),M["steel"],.025)
    return [obj for obj in bpy.context.scene.objects if obj not in before]

def main():
    clear()
    specs={"core":(2.8,2.8),"power":(1.85,1.85),"refinery":(2.8,1.85),"factory":(2.8,2.8),"tower":(1.0,1.0),"radar":(1.85,1.85),"repair":(1.85,1.85),"armory":(1.85,1.85)}
    exports=[]
    for kind, size in specs.items():
        created=make(kind,size)
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
        for obj in objects: obj.location+=offset
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE,"industrial_buildings.blend"))

if __name__ == "__main__":
    main()
