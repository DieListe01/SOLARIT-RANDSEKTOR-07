"""Author the Drift and Lumen 3D vehicle families as separate Blender assets.

The silhouettes use independent chassis, running gear and role assemblies. Team
ID surfaces remain neutral and are recolored by the normal Godot asset seam.
Run from the project with Blender 5.x:
  blender --background --python tools/create_faction_vehicle_assets.py
"""
from __future__ import annotations

import importlib.util
import math
import os
import shutil
from array import array
from pathlib import Path

import bpy
from mathutils import Vector

ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),".."))
OUT=os.path.join(ROOT,"assets","models","vehicles","factions")
SOURCES=os.path.join(ROOT,"assets","models","source","vehicles","factions")
os.makedirs(OUT,exist_ok=True); os.makedirs(SOURCES,exist_ok=True)

spec=importlib.util.spec_from_file_location("vehicle_authoring",os.path.join(ROOT,"tools","create_vehicle_assets.py"))
author=importlib.util.module_from_spec(spec); assert spec and spec.loader; spec.loader.exec_module(author)
BASE_MATERIAL=author.material
TEXTURE_SOURCE=author.TEXTURES
PALETTE_TEXTURES_READY=set()

ROLE={
 "scout":(1.20,2.35,.88),"tank":(1.72,3.20,1.40),"siege":(2.00,3.65,1.56),
 "raider":(1.42,2.75,1.03),"lancer":(1.72,3.10,1.29),"scorcher":(1.62,2.90,1.28),
 "bulwark":(2.20,3.95,1.62),"harvester":(2.28,3.75,1.70),
}

def set_palette(faction:str)->None:
    author.M.clear()
    if faction=="drift":
        palette={"armor":(.39,.31,.23,1),"armor_light":(.62,.47,.29,1),"dark":(.064,.072,.064,1),"steel":(.30,.31,.27,1),"rubber":(.025,.027,.025,1),"track":(.18,.17,.13,1),"glass":(.018,.095,.105,1),"team":(.02,.88,.73,1),"amber":(1,.29,.04,1),"hazard":(.80,.39,.12,1),"energy":(.28,.62,.55,1),"red":(.53,.16,.09,1)}
    else:
        palette={"armor":(.22,.26,.35,1),"armor_light":(.48,.50,.63,1),"dark":(.045,.055,.09,1),"steel":(.32,.37,.50,1),"rubber":(.018,.022,.038,1),"track":(.12,.15,.23,1),"glass":(.025,.12,.24,1),"team":(.02,.88,.73,1),"amber":(.90,.50,.20,1),"hazard":(.68,.57,.92,1),"energy":(.32,.23,.95,1),"red":(.38,.20,.72,1)}
    author.COLORS.update(palette)
    texture_root=os.path.join(TEXTURE_SOURCE,"factions",faction)
    if faction not in PALETTE_TEXTURES_READY:
        os.makedirs(texture_root,exist_ok=True)
        for source in Path(TEXTURE_SOURCE).glob("*.png"):
            target=Path(texture_root)/source.name
            if source.stem=="ceramic_albedo":
                src=bpy.data.images.load(str(source),check_existing=True)
                values=array("f",[0.0])*len(src.pixels); src.pixels.foreach_get(values)
                tint=palette["armor"]
                for idx in range(0,len(values),4):
                    values[idx]*=tint[0]; values[idx+1]*=tint[1]; values[idx+2]*=tint[2]
                baked=bpy.data.images.new("%s faction ceramic albedo"%faction,width=src.size[0],height=src.size[1],alpha=True)
                baked.pixels.foreach_set(values); baked.filepath_raw=str(target); baked.file_format="PNG"; baked.save()
                bpy.data.images.remove(baked)
                if src.name.startswith("ceramic_albedo"): bpy.data.images.remove(src)
            else:
                shutil.copy2(source,target)
        PALETTE_TEXTURES_READY.add(faction)
    author.TEXTURES=texture_root
    author.material=BASE_MATERIAL

def mat(key:str): return author.material(key)

def keep_world_parent(obj,parent):
    world=obj.matrix_world.copy(); obj.parent=parent; obj.matrix_parent_inverse=parent.matrix_world.inverted(); obj.matrix_world=world

def box(name,center,size,key="armor",bevel=.035,rotation=0.0,parent=None):
    obj=author.box(name,center,size,key,bevel,rotation)
    if parent is not None: keep_world_parent(obj,parent)
    return obj

def cyl(name,center,radius,depth,key="steel",axis="Y",vertices=20,parent=None):
    obj=author.cyl(name,center,radius,depth,key,axis,vertices)
    if parent is not None: keep_world_parent(obj,parent)
    return obj

def rod(name,a,b,radius,key="steel",parent=None):
    obj=author.rod(name,a,b,radius,key)
    if parent is not None: keep_world_parent(obj,parent)
    return obj

def prism(name,points,y0,y1,key="armor",bevel=.025):
    return author.mesh(name,[(x,y0,z) for x,z in points]+[(x,y1,z) for x,z in points],
      [tuple(reversed(range(len(points)))),tuple(range(len(points),2*len(points)))]+[(i,(i+1)%len(points),(i+1)%len(points)+len(points),i+len(points)) for i in range(len(points))],key,bevel)

def torus(name,center,major,minor,key):
    bpy.ops.mesh.primitive_torus_add(major_radius=major,minor_radius=minor,major_segments=24,minor_segments=8,location=Vector((center[0],center[2],center[1])))
    obj=bpy.context.object; obj.name=name; obj.data.materials.append(mat(key)); return obj

def root_empty(kind,faction):
    root=bpy.data.objects.new("SOLARIT · %s · %s"%(faction.title(),kind.title()),None); bpy.context.collection.objects.link(root)
    root["asset_role"]=kind; root["asset_faction"]=faction; root["forward_axis"]="-Z"; root["ground_plane"]="Y=0"
    return root

def drive_drift(kind,width,length):
    # Six/eight independent wheels, external suspension and a low split wedge.
    count=3 if kind in {"scout","raider","lancer"} else 4
    z_values=[-length*.36+i*(length*.72/max(1,count-1)) for i in range(count)]
    author.wheels((-width*.51,width*.51),z_values,.22 if count==3 else .26)
    for side in (-1,1):
        for z in z_values:
            rod("Exposed double-wishbone suspension",(side*width*.30,.28,z-.10),(side*width*.53,.42,z),.035,"steel")
            rod("Hydraulic shock strut",(side*width*.31,.28,z+.10),(side*width*.50,.53,z),.025,"hazard")
        box("External fender rail",(side*width*.58,.55,0),(.12,.11,length*.78),"dark",.025)

def drive_lumen(kind,width,length):
    # Three levitation rings per side and swept, load-bearing ceramic outriggers.
    for side in (-1,1):
        for z in (-length*.34,0,length*.34):
            torus("Annular gravitic lift coil",(side*width*.50,.22,z),.24 if kind in {"scout","raider"} else .31,.075,"energy")
            cyl("Inductor core",(side*width*.50,.22,z),.14 if kind in {"scout","raider"} else .19,.15,"dark","Y",16)
        wing=prism("Swept levitation outrigger",[(side*width*.36,-length*.46),(side*width*.86,-length*.31),(side*width*.78,length*.40),(side*width*.40,length*.47)],.31,.49,"dark",.045)
        for z in (-length*.28,length*.27):
            rod("Violet field brace",(side*width*.34,.55,z),(side*width*.76,.37,z-.12),.055,"energy")
    cyl("Ventral phase reactor",(0,.18,0),width*.24,.18,"energy","Y",32)

def turret_root(kind,width,height):
    pivot=bpy.data.objects.new("Turret",None); bpy.context.collection.objects.link(pivot); pivot.location=(0,0,height)
    cyl("Independent traverse race",(0,height,0),width*.42,.12,"dark","Y",32,pivot)
    cyl("Indexed azimuth bearing",(0,height+.07,0),width*.33,.055,"hazard","Y",32,pivot)
    return pivot

def role_hardware(kind,width,length,height,faction):
    if kind=="harvester":
        # The independent collector profile has a front twin drum, central intake,
        # raised conveyor and a visibly open rear ore bin.
        box("Collector operator cab",(0,height*.72,-length*.22),(width*.58,.48,length*.28),"dark",.10)
        box("Panoramic mineral glass",(0,height*.84,-length*.34),(width*.40,.18,.045),"glass",.02)
        box("Deep open ore hopper floor",(0,height*.69,length*.24),(width*.62,.18,length*.38),"armor_light",.045)
        for side in (-1,1):
            box("Hopper armored sidewall",(side*width*.31,height*.91,length*.22),(.13,.40,length*.39),"armor",.035)
            rod("Elevated ore conveyor truss",(side*width*.23,height*.80,-length*.24),(side*width*.23,height*1.14,length*.16),.08,"steel")
            cyl("Powered cutter drum",(side*width*.31,.47,-length*.50),.23,width*.34,"hazard","X",24)
            for i in range(7): box("Replaceable cutter tooth",(side*width*.31,.48,-length*.57+i*length*.018),(.28,.11,.12),"steel",.015)
            rod("Cutter hydraulic ram",(side*width*.30,.57,-length*.39),(side*width*.30,.89,-length*.25),.055,"hazard")
        box("Conveyor belt cover",(0,height*.98,-length*.02),(width*.32,.12,length*.43),"dark",.025)
        for z in (-length*.16,-length*.04,length*.08,length*.20): cyl("Conveyor roller",(0,height*1.04,z),.075,width*.34,"steel","X",12)
        for side in (-1,1): cyl("Cyclone dust separator",(side*width*.34,height*.88,length*.33),.11,.45,"dark","Y",16)
        box("Collector owner marker",(0,height*1.10,length*.19),(width*.34,.09,.24),"team",.015)
        rotor=bpy.data.objects.new("CutterDrumRotor",None); bpy.context.collection.objects.link(rotor)
        rotor.location=(0,.47,-length*.50)
        for obj in list(bpy.context.scene.objects):
            if obj is not rotor and obj.type=="MESH" and ("Powered cutter drum" in obj.name or "Replaceable cutter tooth" in obj.name):
                keep_world_parent(obj,rotor)
        head=bpy.data.objects.new("HarvesterHead",None); bpy.context.collection.objects.link(head)
        for obj in list(bpy.context.scene.objects):
            if obj is not head and obj.type=="MESH" and ("Cutter hydraulic ram" in obj.name or "Elevated ore conveyor truss" in obj.name):
                keep_world_parent(obj,head)
        gate=bpy.data.objects.new("CargoGate",None); bpy.context.collection.objects.link(gate)
        gate.location=(0,height*.74,length*.44)
        hatch=box("Hinged mineral unloading gate",(0,height*.77,length*.49),(width*.54,.12,.10),"armor_light",.02)
        keep_world_parent(hatch,gate)
        beacon=bpy.data.objects.new("IdleBeaconRotor",None); bpy.context.collection.objects.link(beacon)
        beacon.location=(0,height*1.05,-length*.20)
        lamp=cyl("Survey idle beacon",(0,height*1.05,-length*.20),.09,.10,"energy","Y",16)
        keep_world_parent(lamp,beacon)
        for stage in range(1,9):
            cargo=bpy.data.objects.new("CargoStage%02d"%stage,None); bpy.context.collection.objects.link(cargo)
            lane=(stage-1)%4; row=(stage-1)//4
            cx=-width*.22+lane*width*.145; cz=length*.12+row*length*.12
            radius=.10+(stage%3)*.018
            verts=[(cx+math.cos(i*math.tau/6)*radius,height*.94+row*.09+math.sin(i*math.tau/6)*radius,cz+math.sin(i*math.tau/6)*radius) for i in range(6)]
            verts += [(cx,height*1.12+row*.09,cz),(cx+radius*.25,height*1.04+row*.09,cz-radius*.25)]
            faces=[(i,(i+1)%6,6 if i%2==0 else 7) for i in range(6)]+[(i,7,(i+1)%6) for i in range(6)]
            gem=author.mesh("Solarit ore cargo facet",verts,faces,"energy",.006); keep_world_parent(gem,cargo)
        for node_name,key in (("DamageLight","dark"),("DamageHeavy","hazard")):
            damage=bpy.data.objects.new(node_name,None); bpy.context.collection.objects.link(damage)
            for shard in range(3 if node_name=="DamageLight" else 5):
                x=(shard%2-.5)*width*.54; z=(-.2+shard*.12)*length*.8
                facet=box("Collector armor damage facet",(x,height*.91,z),(.13,.025,.19),key,.006)
                keep_world_parent(facet,damage)
        return
    if kind in {"scout","raider"}:
        mount=box("Remote weapon station",(0,height*.88,.10),(width*.48,.30,length*.24),"dark",.08)
    else:
        mount=box("Raised armored traversing turret",(0,height*.85,.12),(width*.62,.43,length*.31),"armor_light",.075)
    pivot=turret_root(kind,width,height*.75); keep_world_parent(mount,pivot)
    barrel_key="energy" if faction=="lumen" and kind=="lancer" else "steel"
    if kind in {"tank","bulwark"}:
        barrel_len=length*.48 if kind=="tank" else length*.40
        rod("Long-bore main cannon",(0,height*1.16,-.15),(0,height*1.18,-barrel_len),.13 if kind=="tank" else .17,barrel_key,pivot)
        cyl("Thermal muzzle brake",(0,height*1.18,-barrel_len),.18 if kind=="tank" else .22,.20,"dark","Z",24,pivot)
    elif kind=="siege":
        rod("Extended siege cannon",(0,height*1.22,-.18),(0,height*1.30,-length*.85),.17,"steel",pivot)
        for side in (-1,1):
            box("Recoil carriage rail",(side*width*.22,height*1.17,-length*.36),(.09,.12,length*.48),"hazard",.018,parent=pivot)
            rod("Elevating gun trunnion",(side*width*.31,height*1.13,.04),(side*width*.31,height*1.36,-.20),.09,"steel",pivot)
    elif kind=="raider":
        for side in (-1,1): cyl("Paired autocannon",(side*width*.13,height*1.12,-length*.25),.09,.60,"steel","Z",16,pivot)
    elif kind=="scout":
        rod("Tri-band target sensor",(0,height*1.05,.08),(0,height*1.70,.08),.035,"hazard",pivot)
        for y in (height*1.23,height*1.40,height*1.57): cyl("Recon scan ring",(0,y,.08),.16,.06,"team","Y",20,pivot)
        cyl("Forward laser range finder",(0,height*1.04,-.28),.08,.08,"glass","Z",16,pivot)
    elif kind=="lancer":
        for side in (-1,1):
            cyl("Twin photon lance",(side*width*.20,height*1.15,-length*.32),.09,.70,"energy","Z",20,pivot)
            cyl("Emitter aperture",(side*width*.20,height*1.15,-length*.54),.12,.10,"team","Z",20,pivot)
    elif kind=="scorcher":
        for side in (-1,1):
            cyl("Protected fuel pressure vessel",(side*width*.46,height*.84,.16),.22,length*.38,"red","Z",20)
            rod("Armored fuel feed",(side*width*.42,height*.86,-.02),(side*width*.19,height*1.12,-.25),.055,"hazard",pivot)
            cyl("Twin thermal lance",(side*width*.18,height*1.17,-length*.35),.12,.54,"steel","Z",20,pivot)
            cyl("Ceramic burner nozzle",(side*width*.18,height*1.17,-length*.54),.16,.10,"hazard","Z",20,pivot)
    if kind=="bulwark":
        for side in (-1,1):
            box("Armored assault sponson",(side*width*.52,height*.71,-.18),(.34,.45,.72),"dark",.07)
            cyl("Side rotary defense gun",(side*width*.60,height*.77,-.51),.10,.48,"steel","Z",16)

def identity_hardware(kind,width,length,height,faction):
    # Broad neutral ID plates are separate from the faction's fixed materials.
    box("TeamColor",(0,height*1.22,length*.17),(width*.40,.095,length*.17),"team",.02)
    for side in (-1,1):
        box("TeamColor flank plate",(side*width*.54,height*.61,.10),(.07,.24,length*.22),"team",.012)
    if faction=="drift":
        for side in (-1,1):
            box("Wanderpakt scarred side applique",(side*width*.48,height*.57,-length*.08),(.12,.31,length*.40),"armor_light",.045,rotation=side*.10)
            rod("External tow cable",(side*width*.45,.55,length*.18),(side*width*.49,.68,length*.39),.026,"hazard")
    else:
        for side in (-1,1):
            prism("Prisma faceted wing",[(side*width*.35,-length*.26),(side*width*.83,-length*.39),(side*width*.69,length*.24),(side*width*.39,length*.33)],height*.55,height*.67,"armor_light",.025)
            cyl("Surface flux lens",(side*width*.53,height*.71,-length*.10),.105,.04,"energy","Y",16)
    for side in (-1,1):
        cyl("Armored forward lamp",(side*width*.30,.60,-length*.47),.085,.06,"amber","X",12)
        cyl("Rear marker",(side*width*.28,.57,length*.46),.06,.05,"red","X",12)

def create_harvester_animations(root):
    rotor=bpy.data.objects.get("CutterDrumRotor")
    head=bpy.data.objects.get("HarvesterHead")
    gate=bpy.data.objects.get("CargoGate")
    beacon=bpy.data.objects.get("IdleBeaconRotor")
    if rotor is None or head is None or gate is None or beacon is None: return
    scene=bpy.context.scene; scene.render.fps=30; scene.frame_start=1; scene.frame_end=24
    def action(name,obj,axis,values):
        clip=bpy.data.actions.new(name); clip.use_fake_user=True
        clip.layers.new("SOLARIT cached pose")
        clip.layers[0].strips.new(type="KEYFRAME")
        obj.animation_data_create(); obj.animation_data.action=clip
        slot=clip.slots.new("OBJECT",obj.name); obj.animation_data.action_slot=slot
        curve=clip.fcurve_ensure_for_datablock(obj,"rotation_euler",index=axis,group_name=obj.name)
        for frame,value in values:
            key=curve.keyframe_points.insert(frame,value,options={"FAST"}); key.interpolation="LINEAR"
        curve.update(); curve.modifiers.new("CYCLES")
        return clip
    action("Idle",beacon,1,[(1,0.0),(12,.35),(24,math.tau)])
    action("Move",head,0,[(1,0.0),(7,.055),(13,0.0),(19,-.055),(24,0.0)])
    action("Harvest",rotor,0,[(1,0.0),(7,math.pi*.55),(13,math.pi),(19,math.pi*1.55),(24,math.tau)])
    action("Unload",gate,0,[(1,0.0),(8,.18),(13,.55),(19,.30),(24,0.0)])

def consolidate_static_geometry(kind:str)->None:
    # Preserve animated pivots, owner-ID plates and the silhouette-defining
    # role mechanism; merge the smaller fixed fittings by material and parent.
    signature_terms={
        "scout":["Tri-band target sensor"],"raider":["Ramming prow"],
        "tank":["Long-bore main cannon"],"siege":["Extended siege cannon"],
        "harvester":["Powered cutter drum"],"lancer":["Twin photon lance"],
        "scorcher":["Protected fuel pressure vessel"],"bulwark":["Armored assault sponson"],
    }[kind]
    groups={}
    for obj in [item for item in bpy.context.scene.objects if item.type=="MESH"]:
        if obj.name=="TeamColor" or any(term in obj.name for term in signature_terms): continue
        material=obj.data.materials[0] if obj.data.materials else None
        if material is None: continue
        for modifier in list(obj.modifiers):
            bpy.ops.object.select_all(action="DESELECT"); obj.select_set(True); bpy.context.view_layer.objects.active=obj
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        groups.setdefault((obj.parent,material.name),[]).append(obj)
    for (parent,material_name),objects in groups.items():
        if len(objects)<2: continue
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects: obj.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        bpy.ops.object.join()
        merged=bpy.context.object
        merged.name="TeamColor flank details" if material_name.startswith("TeamColor") else "Faction detail · "+material_name
        merged.data.name=merged.name+" · consolidated geometry"

def design(kind:str,faction:str):
    author.clear()
    # Blender datablocks outlive scene clearing; stale action datablocks would
    # export duplicated .001 clips from another faction's harvester.
    for stale_action in list(bpy.data.actions): bpy.data.actions.remove(stale_action)
    set_palette(faction); root=root_empty(kind,faction)
    width,length,height=ROLE[kind]
    width*=1.14 if faction=="drift" else 1.02
    height*=.88 if faction=="drift" else 1.08
    # Different closed faceted hull sections give each faction a distinct body,
    # rather than recoloring or mirroring the shared forge chassis.
    if faction=="drift":
        author.loft("Wanderpakt · low angular field chassis",[
          (-length*.52,width*.14,.22,.43,.37),(-length*.43,width*.48,.19,.65,.49),(-length*.28,width*.56,.19,.76,.59),
          (length*.22,width*.52,.20,.72,.55),(length*.44,width*.40,.24,.57,.43),(length*.51,width*.22,.30,.44,.37)],"armor")
        drive_drift(kind,width,length)
        for side in (-1,1):
            box("Exposed rear turbine housing",(side*width*.28,.78,length*.28),(width*.23,.30,length*.27),"dark",.055)
            for i in range(5): box("External cooling vane",(side*width*.42,.80,length*.17+i*length*.025),(.06,.12,.04),"steel",.006)
    else:
        prism("Prisma · swept faceted hover hull",[(-width*.28,-length*.53),(width*.28,-length*.53),(width*.50,-length*.36),(width*.47,length*.30),(width*.24,length*.51),(-width*.24,length*.51),(-width*.47,length*.30),(-width*.50,-length*.36)],.35,height*.58,"armor",.045)
        prism("Raised crystalline dorsal spine",[(-width*.21,-length*.30),(width*.21,-length*.30),(width*.28,length*.25),(0,length*.45),(-width*.28,length*.25)],height*.58,height*.78,"armor_light",.04)
        drive_lumen(kind,width,length)
        for side in (-1,1):
            cyl("Side-mounted phase capacitor",(side*width*.34,height*.71,length*.12),.18,.54,"energy","Z",24)
            box("Capacitor shielding rib",(side*width*.40,height*.71,length*.12),(.13,.42,.67),"dark",.04)
    # Role-specific front and rear silhouettes persist at normal RTS zoom.
    if kind in {"tank","siege","bulwark"}:
        box("Layered forward glacis",(0,.58,-length*.31),(width*.75,.24,length*.30),"armor_light",.055,rotation=-.12)
    elif kind=="raider":
        prism("Ramming prow",[(-width*.45,-length*.36),(width*.45,-length*.36),(width*.30,-length*.54),(0,-length*.60),(-width*.30,-length*.54)],.27,.56,"hazard",.035)
    elif kind=="harvester":
        box("Industrial rear counterweight",(0,.48,length*.43),(width*.78,.35,.20),"dark",.06)
    else:
        box("Forward aerodynamic splitter",(0,.36,-length*.49),(width*.84,.12,.15),"steel",.025)
    role_hardware(kind,width,length,height,faction)
    identity_hardware(kind,width,length,height,faction)
    if kind!="harvester":
        for node_name,key in (("DamageLight","dark"),("DamageHeavy","hazard")):
            damage=bpy.data.objects.new(node_name,None); bpy.context.collection.objects.link(damage)
            for shard in range(3 if node_name=="DamageLight" else 5):
                facet=box("Battle damage torn armor facet",(.38+(shard%2)*.10,.86+shard*.018,-.12+(shard//2)*.09),(.18,.024,.07),key,.006)
                keep_world_parent(facet,damage)
    if kind!="harvester":
        # Root is the GLB scene root. All role hardware is attached beneath it;
        # turret pieces remain under the named movable pivot.
        pivot=next((o for o in bpy.context.scene.objects if o.name=="Turret"),None)
        for obj in list(bpy.context.scene.objects):
            if obj in {root,pivot} or obj.parent is not None: continue
            keep_world_parent(obj,root)
        if pivot is not None: keep_world_parent(pivot,root)
    else:
        for obj in list(bpy.context.scene.objects):
            if obj is not root and obj.parent is None: keep_world_parent(obj,root)
    if kind=="harvester":
        create_harvester_animations(root)
    consolidate_static_geometry(kind)
    # UV unwrap authored surfaces and save every faction-role scene as editable .blend.
    for obj in [o for o in bpy.context.scene.objects if o.type=="MESH"]:
        bpy.ops.object.select_all(action="DESELECT"); obj.select_set(True); bpy.context.view_layer.objects.active=obj
        bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(island_margin=.018,area_weight=.16,correct_aspect=True,scale_to_bounds=True); bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCES,f"{faction}_{kind}.blend"))
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type in {"MESH","EMPTY"}: obj.select_set(True)
    bpy.context.view_layer.objects.active=root
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,f"{faction}_{kind}.glb"),export_format="GLB",export_apply=True,export_yup=True,export_extras=True,export_materials="EXPORT",export_animations=True,export_animation_mode="ACTIONS",export_force_sampling=True)
    print("FACTION VEHICLE",faction,kind,"meshes",sum(1 for o in bpy.context.scene.objects if o.type=="MESH"))

def main():
    bpy.context.preferences.filepaths.save_version=0
    for faction in ("drift","lumen"):
        for kind in ROLE: design(kind,faction)
    spec=importlib.util.spec_from_file_location("externalize",os.path.join(ROOT,"tools","externalize_glb_textures.py"))
    module=importlib.util.module_from_spec(spec); assert spec and spec.loader; spec.loader.exec_module(module)
    for faction in ("drift","lumen"):
        texture_root=Path(TEXTURE_SOURCE)/"factions"/faction
        for path in Path(OUT).glob(f"{faction}_*.glb"):
            module.externalize(path,texture_root=texture_root)

if __name__=="__main__": main()
