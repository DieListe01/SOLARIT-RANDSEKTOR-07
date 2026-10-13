"""Create independent Wanderpakt and Prisma building families in Blender.

Run with Blender 5.x: blender --background --python tools/create_faction_building_assets.py
Each faction/role is an editable .blend source plus a game-ready GLB. The Kobalt
assets remain the existing authored industrial family.
"""
from __future__ import annotations
import math, os
from pathlib import Path
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"assets/models/buildings/factions"
SRC=ROOT/"assets/models/source/buildings/factions"
OUT.mkdir(parents=True,exist_ok=True); SRC.mkdir(parents=True,exist_ok=True)
FOOT={"core":(3,3),"power":(2,2),"refinery":(3,2),"factory":(3,3),"tower":(1,1),"radar":(2,2),"repair":(2,2),"armory":(2,2)}
PALETTES={
 "drift":{"armor":(.31,.20,.12,1),"light":(.62,.37,.17,1),"dark":(.045,.048,.042,1),"steel":(.26,.23,.18,1),"glass":(.025,.10,.10,1),"energy":(.10,.43,.37,1),"amber":(.98,.31,.045,1),"team":(.02,.88,.73,1),"ceramic":(.47,.30,.16,1)},
 "lumen":{"armor":(.12,.17,.28,1),"light":(.38,.42,.58,1),"dark":(.025,.035,.075,1),"steel":(.20,.27,.43,1),"glass":(.035,.14,.38,1),"energy":(.34,.18,.96,1),"amber":(.40,.74,1,1),"team":(.02,.88,.73,1),"ceramic":(.30,.36,.52,1)},
}
M={}
TEXTURES=ROOT/"assets"/"models"/"textures"/"industrial"

def surface_texture(key):
    """Map structural finishes to the shared, authored industrial PBR set."""
    return {"armor":"ceramic", "light":"ceramic", "ceramic":"ceramic",
            "dark":"graphite", "steel":"steel"}.get(key)

def faction_albedo_name(key, texture_key):
    role={"armor":"armor", "light":"armor_light", "ceramic":"armor",
          "dark":"dark", "steel":"steel"}.get(key)
    finish={"ceramic":"ceramic", "graphite":"graphite", "steel":"steel"}.get(texture_key)
    return "factions_%s_%s_%s_albedo.png"%(_FACTION,role,finish) if role and finish else ""

def clear():
    bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete(use_global=False)
    for m in list(bpy.data.materials):
        if m.users==0: bpy.data.materials.remove(m)

def material(key):
    if key in M: return M[key]
    c=PALETTES[_FACTION][key]; m=bpy.data.materials.new(_FACTION.title()+" / "+key); m.diffuse_color=c; m.use_nodes=True
    nodes=m.node_tree.nodes; links=m.node_tree.links
    p=nodes.get("Principled BSDF"); p.inputs["Base Color"].default_value=c
    p.inputs["Metallic"].default_value=.68 if key in {"dark","steel","energy"} else .24
    p.inputs["Roughness"].default_value=.30 if key in {"glass","energy"} else .48
    if key in {"team","energy","amber"}:
        p.inputs["Emission Color"].default_value=c; p.inputs["Emission Strength"].default_value=.85 if key!="team" else .45
    # The original building family used flat Principled colors even though the
    # project already ships tileable, authored panel/grit/fastener PBR maps.
    # Use the already-authored faction-tinted albedo maps from the vehicle PBR
    # set, then share the neutral roughness and normal maps. Keeping albedo as a
    # direct texture also makes the full material portable through glTF.
    texture_key=surface_texture(key)
    if texture_key:
        def image_node(suffix, colorspace):
            filename=texture_key+"_"+suffix+".png"
            if suffix=="albedo":
                faction_path=TEXTURES/"factions"/_FACTION/faction_albedo_name(key,texture_key)
                if faction_path.is_file(): filename=faction_path.name
            path=(TEXTURES/"factions"/_FACTION/filename if filename.startswith("factions_") else TEXTURES/filename)
            if not path.is_file(): return None
            img=bpy.data.images.load(str(path),check_existing=True)
            img.colorspace_settings.name=colorspace
            node=nodes.new("ShaderNodeTexImage")
            node.name="SOLARIT shared PBR · "+texture_key+" "+suffix
            node.image=img
            return node

        albedo=image_node("albedo","sRGB")
        if albedo:
            p.inputs["Base Color"].default_value=(1,1,1,1)
            links.new(albedo.outputs["Color"],p.inputs["Base Color"])
        roughness=image_node("roughness","Non-Color")
        if roughness: links.new(roughness.outputs["Color"],p.inputs["Roughness"])
        normal_image=image_node("normal","Non-Color")
        if normal_image:
            normal=nodes.new("ShaderNodeNormalMap"); normal.name="Shallow panel normal · "+texture_key
            normal.inputs["Strength"].default_value=.16
            links.new(normal_image.outputs["Color"],normal.inputs["Color"])
            links.new(normal.outputs["Normal"],p.inputs["Normal"])
    M[key]=m; return m

def box(name,loc,size,key="armor",bevel=.035,rotation=0,parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=(loc[0],loc[2],loc[1])); o=bpy.context.object; o.name=name
    o.dimensions=(size[0],size[2],size[1]); o.rotation_euler.z=rotation
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); o.data.materials.append(material(key))
    if bevel:
        b=o.modifiers.new("Machined safety edge","BEVEL"); b.width=bevel; b.segments=2
        n=o.modifiers.new("Weighted panel normals","WEIGHTED_NORMAL"); n.keep_sharp=True
    if parent: parent_world(o,parent)
    return o

def cyl(name,loc,radius,depth,key="steel",axis="Y",verts=20,parent=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=radius,depth=depth,location=(loc[0],loc[2],loc[1])); o=bpy.context.object; o.name=name
    if axis=="X": o.rotation_euler.y=math.pi/2
    elif axis=="Z": o.rotation_euler.x=math.pi/2
    o.data.materials.append(material(key))
    if parent: parent_world(o,parent)
    return o

def parent_world(child,parent):
    world=child.matrix_world.copy(); child.parent=parent; child.matrix_parent_inverse=parent.matrix_world.inverted(); child.matrix_world=world

def pivot(name,loc):
    o=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(o); o.location=(loc[0],loc[2],loc[1]); return o

def rod(name,a,b,r,key="steel",parent=None):
    av=Vector((a[0],a[2],a[1])); bv=Vector((b[0],b[2],b[1])); delta=bv-av
    o=cyl(name,tuple((av+bv)*.5),r,delta.length,key,"Y",12,parent)
    o.rotation_euler[0]=math.atan2(delta.x,delta.y); o.rotation_euler[2]=math.atan2(-delta.z,math.sqrt(delta.x**2+delta.y**2)); return o

def torus(name,loc,major,minor,key="energy",parent=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=major,minor_radius=minor,major_segments=24,minor_segments=8,location=(loc[0],loc[2],loc[1]))
    o=bpy.context.object; o.name=name; o.rotation_euler[0]=math.pi/2; o.data.materials.append(material(key))
    if parent: parent_world(o,parent)
    return o

def plate(name,outline,y0,y1,key="armor"):
    verts=[(x,z,y) for y in (y0,y1) for x,z in outline]; n=len(outline)
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh=bpy.data.meshes.new(name+" · mesh"); mesh.from_pydata([(x,z,y) for x,y,z in verts],[],faces); mesh.materials.append(material(key))
    obj=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj); return obj

def crystal(name,x,z,base,height,width,key="energy"):
    n=6; verts=[]
    for y,r in ((base,width*.64),(base+height*.70,width),(base+height,width*.10)):
        for i in range(n):
            a=math.tau*i/n; verts.append((x+math.cos(a)*r,z+math.sin(a)*r,y))
    faces=[tuple(range(n))]
    for ring in range(2):
        for i in range(n): faces.append((ring*n+i,ring*n+(i+1)%n,(ring+1)*n+(i+1)%n,(ring+1)*n+i))
    faces.append(tuple(range(2*n,3*n)))
    mesh=bpy.data.meshes.new(name+" · facet mesh"); mesh.from_pydata([(a,c,b) for a,b,c in verts],[],faces); mesh.materials.append(material(key))
    obj=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj); return obj

def angular_housing(name,center,width,height,depth,key="armor",profile=None):
    """Build a role-shaped hard-surface volume from designed cross-sections.

    This is deliberately not a scaled cube: the contour has clipped corners,
    faceted shoulders and a different section profile for each building role.
    Blender bevels and weighted normals keep the large planes readable at RTS
    cache resolution.
    """
    x0,y0,z0=center
    outline=[(-.30,-.50),(.30,-.50),(.48,-.31),(.50,.25),(.34,.50),(-.34,.50),(-.50,.25),(-.48,-.31)]
    if profile is None:
        profile=[(0.0,.72,.76,0.0,0.0),(.16,1.0,.96,0.0,0.0),(.76,1.0,1.0,0.0,0.0),(1.0,.78,.82,0.0,.02)]
    verts=[]
    for level,sx,sz,ox,oz in profile:
        for px,pz in outline:
            verts.append((x0+ox*width+px*width*sx,z0+oz*depth+pz*depth*sz,y0+level*height))
    ring_count=len(outline); faces=[tuple(reversed(range(ring_count))),tuple(range((len(profile)-1)*ring_count,len(profile)*ring_count))]
    for ring in range(len(profile)-1):
        for i in range(ring_count):
            a=ring*ring_count+i; b=ring*ring_count+(i+1)%ring_count
            faces.append((a,b,b+ring_count,a+ring_count))
    mesh=bpy.data.meshes.new(name+" · designed hard-surface mesh")
    mesh.from_pydata(verts,[],faces); mesh.materials.append(material(key)); mesh.validate(); mesh.update()
    obj=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj)
    bevel=obj.modifiers.new("Small machined edge highlights","BEVEL"); bevel.width=min(.035,width*.025,height*.03); bevel.segments=2
    normal=obj.modifiers.new("Planar surface normals","WEIGHTED_NORMAL"); normal.keep_sharp=True
    return obj

def foundation(root,kind,w,d):
    key="light" if _FACTION=="drift" else "dark"
    if _FACTION=="drift":
        for side in (-1,1):
            box("Replaceable skid rail",(side*w*.39,.16,0),(w*.11,.28,d*.82),"dark",.045)
            for z in (-d*.32,-d*.10,d*.12,d*.34): cyl("Skid hinge",(side*w*.40,.13,z),.085,.07,"amber","X",12)
        box("Modular pallet deck",(0,.34,0),(w*.84,.18,d*.77),"steel",.06)
        for z in (-d*.30,d*.30): box("Bolt-on edge rail",(0,.43,z),(w*.68,.07,.08),"light",.015)
    else:
        # Three floating ceramic pads and a faceted lower brace announce Prisma
        # architecture before the eye reaches the role-specific superstructure.
        plate("Geometric levitation plinth",[(-w*.48,-d*.25),(-w*.25,-d*.48),(w*.25,-d*.48),(w*.48,-d*.25),(w*.48,d*.25),(w*.25,d*.48),(-w*.25,d*.48),(-w*.48,d*.25)],.24,.43,"steel")
        for a in (0,math.tau/3,math.tau*2/3):
            x=math.cos(a)*w*.38; z=math.sin(a)*d*.38
            cyl("Flux suspension pad",(x,.20,z),.23,.10,"energy","Y",16)
            crystal("Faceted gravitic foot",x,z,.22,.27,.16,"light")
            rod("Triangular levitation strut",(x*.70,.40,z*.70),(x,.24,z),.045,"steel")
        box("Floating central armor slab",(0,.43,0),(w*.67,.12,d*.67),"dark",.025)
    # Every building has one bright ownership badge, but never uses it as the
    # main faction distinction.
    box("TeamColor",(0,.60,d*.44),(w*.25,.10,.07),"team",.012)

def wander_role(root,kind,w,d):
    if kind=="core":
        plate("Low command bastion",[(-w*.38,-d*.29),(w*.18,-d*.40),(w*.39,-d*.17),(w*.33,d*.30),(-w*.36,d*.33)],.48,1.22,"armor")
        box("Field command bunker",(0,1.05,0),(w*.55,.52,d*.50),"dark",.12)
        for side in (-1,1):
            box("Detachable habitation pod",(side*w*.34,.75,-d*.22),(w*.25,.47,d*.25),"light",.06)
            rod("External salvage brace",(side*w*.37,.55,-d*.33),(side*w*.50,1.24,-d*.20),.036,"amber")
        box("Armored command canopy",(0,1.40,0),(w*.46,.13,d*.45),"steel",.05)
        sensor=pivot("CommandSensorPivot",(0,1.52,0)); cyl("Survey beacon",(0,1.57,0),.10,.16,"team","Y",16,sensor)
        rod("Patchwork antenna",(0,1.52,0),(0,2.1,0),.025,"amber",sensor)
    elif kind=="power":
        for side in (-1,1):
            cyl("Combustion generator can",(side*.43,.73,0),.31,.98,"light","Y",12)
            for y in (.42,.64,.86,1.08): torus("Generator reinforcing band",(side*.43,y,0),.32,.027,"dark")
            for z in (-.26,.26): box("Field radiator louver",(side*.43,1.22,z),(.40,.38,.08),"dark",.015)
        axis=pivot("ReactorRotor",(0,1.12,0)); cyl("Exposed impulse flywheel",(0,1.12,0),.30,.16,"amber","Y",24,axis)
        for i in range(8):
            a=i*math.tau/8; rod("Flywheel spoke",(math.cos(a)*.11,1.12,math.sin(a)*.11),(math.cos(a)*.29,1.12,math.sin(a)*.29),.025,"steel",axis)
        box("Bolted control panel",(0,.58,d*.39),(w*.45,.32,.09),"dark",.025)
    elif kind=="refinery":
        for side in (-1,1):
            cyl("Rough ore tumbler",(side*.43,.86,-.10),.29,.74,"steel","X",20)
            for x in (side*.14,side*.35,side*.57): torus("Tumbler retaining ring",(x,.86,-.10),.30,.035,"amber")
            for y in (.56,1.15): rod("Tumbler bearing support",(side*.43,y,-.10),(side*.43,.43,.20),.035,"dark")
        box("Open collection hopper",(0,.68,.43),(w*.64,.28,.42),"dark",.035)
        for side in (-1,1): plate("Hopper sloped wall",[(side*.22,.20),(side*.52,.20),(side*.44,.48),(side*.26,.48)],.74,1.08,"light")
        for i in range(7):
            x=-.85+i*.28; cyl("Conveyor roller",(x,.48,-d*.39),.065,.68,"steel","X",12)
            box("Replaceable conveyor cleat",(x,.56,-d*.39),(.10,.05,.62),"amber",.01)
        box("Ore transfer belt",(0,.47,-d*.39),(2.0,.06,.7),"dark",.025,rotation=-.18)
        gate=pivot("UnloadGate",(0,.74,d*.34)); box("Hinged receiving gate",(0,.72,d*.38),(w*.52,.13,.08),"team",.015,parent=gate)
    elif kind=="factory":
        # Open gantry rather than another solid factory box.
        for x in (-w*.40,w*.40):
            for z in (-d*.34,d*.34): box("Exposed gantry leg",(x,1.0,z),(.15,1.48,.15),"steel",.025)
        for z in (-d*.35,d*.35): rod("Diagonal tension cable",(-w*.40,.54,z),(w*.40,1.65,z),.025,"amber")
        for side in (-1,1): box("Canted armor shoulder",(side*.77,1.69,0),(.46,.22,d*.70),"light",.06,rotation=side*.12)
        crane=pivot("ProductionCrane",(0,1.86,0)); box("Overhead crane trolley",(0,1.78,0),(w*.48,.16,.20),"team",.035,parent=crane)
        for x in (-.46,.46): rod("Chain hoist",(x,1.78,0),(x,1.02,0),.025,"amber",crane)
        box("Vehicle assembly skid",(0,.52,-.05),(w*.70,.10,d*.53),"dark",.025)
        for i in range(8): cyl("Drive-in roller",(-.70+i*.20,.62,-.05),.07,1.12,"steel","X",12)
    elif kind=="tower":
        for side in (-1,1): rod("Splayed gun tripod",(side*.12,.43,0),(side*.48,1.21,.38),.11,"dark")
        for side in (-1,1): rod("Tripod tie cable",(side*.48,1.21,.38),(side*.48,.55,-.38),.025,"amber")
        pivot_gun=pivot("TurretPivot",(0,1.20,0)); box("Remote weapon cassette",(0,1.20,0),(.62,.36,.60),"light",.08,parent=pivot_gun)
        rod("High-pressure cannon",(0,1.24,-.08),(0,1.29,-.84),.085,"steel",pivot_gun)
        cyl("Recessed muzzle collar",(0,1.29,-.82),.13,.18,"amber","Z",16,pivot_gun)
        for x in (-.20,.20): cyl("Optical range sensor",(x,1.50,.09),.06,.10,"glass","Y",12,pivot_gun)
    elif kind=="radar":
        for side in (-1,1): rod("Antenna guy wire",(side*.40,.45,.35),(0,2.25,0),.018,"amber")
        mast=cyl("Salvaged telescoping mast",(0,1.42,0),.07,1.95,"steel","Y",12)
        rotor=pivot("RadarRotor",(0,2.32,0))
        for side in (-1,0,1):
            plate("Folded tri-sector sensor",[(side*.10,0),(side*.38,-.24),(side*.51,0),(side*.38,.24)],2.23,2.31,"light")
        torus("Sensor feed hoop",(0,2.32,0),.18,.025,"team")
        for x in (-.46,.46): box("Field battery pod",(x,.65,.25),(.28,.48,.36),"dark",.025)
    elif kind=="repair":
        for x in (-w*.36,w*.36):
            rod("Swing-arm repair gantry",(x,.5,-.38),(x,1.8,-.38),.12,"steel")
            box("Hydraulic lift claw",(x,1.2,0),(.28,.14,.78),"amber",.025)
            arm=pivot("RepairArmLeft" if x<0 else "RepairArmRight",(x,1.34,-.25))
            rod("Articulated service arm",(x,1.34,-.25),(x*.54,1.05,.32),.065,"light",arm)
            cyl("Welding torch head",(x*.54,1.05,.32),.10,.18,"energy","Y",16,arm)
        box("Open drive-through service pad",(0,.47,0),(w*.62,.10,d*.74),"dark",.02)
        for x in (-.52,.52): cyl("Lift ram",(x,.68,.26),.07,.37,"steel","Y",12)
    else: # armory
        for x in (-.54,0,.54):
            box("Bolt-down munitions locker",(x,.92,0),(.38,.92,.82),"dark",.06)
            for z in (-.28,0,.28):
                box("Impact-rated shell case",(x,1.02,z),(.30,.20,.22),"light",.035)
                box("Case latch",(x,1.02,z-.12),(.08,.10,.035),"amber",.008)
        hoist=pivot("OrdnanceLift",(0,1.63,0)); rod("Manual rack hoist",(0,1.63,0),(0,2.0,0),.035,"team",hoist)

def prisma_role(root,kind,w,d):
    if kind=="core":
        # A suspended command prism, not a bunker; its angular crystal stack is
        # visible in monochrome and protected by a rotating sensor crown.
        angular_housing("Command lattice · faceted levitation vault",(0,.43,0),w*.72,.82,d*.68,"dark",
            [(0,.56,.72,0,0),(.18,1,.92,0,0),(.58,.82,1,0,.02),(.78,.58,.74,0,.04),(1,.30,.48,0,.06)])
        for side in (-1,1):
            plate("Cut-in command armor cheek",[(side*.22,.02),(side*.48,-.12),(side*.40,.31),(side*.20,.44)],.86,1.18,"steel")
        crystal("Command keystone",0,0,.48,1.62,.70,"ceramic")
        for i in range(3):
            a=i*math.tau/3; x=math.cos(a)*.76; z=math.sin(a)*.76
            crystal("Orbiting command shard %d"%i,x,z,.49,.82,.30,"energy")
            rod("Ceramic magnetic spar",(x*.7,.6,z*.7),(0,1.55,0),.04,"light")
        sensor=pivot("CommandSensorPivot",(0,1.95,0)); torus("Prismatic scan ring",(0,1.95,0),.65,.05,"amber",sensor)
        for i in range(6): crystal("Ring sensor",math.cos(i*math.tau/6)*.65,math.sin(i*math.tau/6)*.65,1.9,.20,.10,"team")
    elif kind=="power":
        angular_housing("Bipolar flux reactor · split-waist housing",(0,.44,0),w*.78,.70,d*.72,"dark",
            [(0,.52,.70,0,0),(.14,1,.92,0,0),(.42,.68,.74,0,0),(.72,.92,.86,0,.03),(1,.48,.62,0,.04)])
        for side in (-1,1):
            plate("Reactor ceramic heat shield",[(side*.10,.10),(side*.34,.04),(side*.42,.34),(side*.18,.46)],.89,1.12,"ceramic")
        for i in range(6):
            a=i*math.tau/6; x=math.cos(a)*.67; z=math.sin(a)*.67
            crystal("Flux stabilizer %d"%i,x,z,.46,.78,.24,"light")
            rod("Containment tie",(x,.52,z),(0,1.50,0),.028,"energy")
        reactor=pivot("ReactorRotor",(0,1.28,0)); torus("Primary flux containment ring",(0,1.28,0),.55,.09,"energy",reactor)
        torus("Phase-locking outer band",(0,1.34,0),.74,.035,"amber",reactor)
        crystal("Central phase core",0,0,.58,.95,.35,"ceramic")
        for i in range(4): box("Vector distribution node",(-.48+i*.32,.62,d*.40),(.20,.32,.09),"glass",.02)
    elif kind=="refinery":
        angular_housing("Ore phase-separator · sloped process bed",(0,.40,-.08),w*.90,.52,d*.74,"steel",
            [(0,.62,.60,0,0),(.16,1,.92,0,0),(.52,.92,.78,0,-.04),(.78,.62,.55,0,-.08),(1,.42,.40,0,-.10)])
        for side in (-1,1):
            plate("Ore intake cheek",[(side*.18,.06),(side*.48,-.08),(side*.34,.32),(side*.16,.26)],.72,.96,"dark")
        for i in range(3):
            x=-.66+i*.66
            crystal("Solarit phase separator",x,-.1,.51,1.04,.32,"light")
            torus("Magnetic separator cradle",(x,.80,-.1),.38,.045,"energy")
            for side in (-1,1): rod("Field guide",(x+side*.32,.5,-.1),(x,.84,-.1),.026,"amber")
        plate("Angular ore intake",[(-.95,-.90),(.95,-.90),(.68,-.46),(-.68,-.46)],.48,.65,"steel")
        gate=pivot("UnloadGate",(0,.76,d*.34)); plate("Iris discharge shutter",[(-.4,-.1),(.4,-.1),(.30,.14),(-.30,.14)],.72,.82,"energy")
        for x in (-.68,-.34,0,.34,.68):
            cyl("Light-guided ore conveyor roller",(x,.46,-d*.40),.045,.65,"steel","X",12)
            box("Hexagonal conveyor flight",(x,.52,-d*.40),(.08,.045,.6),"amber",.01)
    elif kind=="factory":
        angular_housing("Fabrication keel · low segmented floor housing",(0,.42,.08),w*.56,.28,d*.62,"dark",
            [(0,.56,.66,0,0),(.18,1,.94,0,0),(.58,.88,.76,0,0),(1,.62,.54,0,.05)])
        for side in (-1,1):
            plate("Split assembly armor wing",[(side*.18,.08),(side*.46,-.18),(side*.40,.15),(side*.22,.28)],.73,1.01,"ceramic")
        # An unmistakable open production portal: four load-bearing columns,
        # twin gantry rails and a moving central manipulator replace the generic
        # orbital hoop silhouette used by the former blockout.
        for x in (-.88,.88):
            for z in (-.78,.78):
                angular_housing("Prismatic gantry column",(x,.46,z),.27,1.34,.30,"steel",
                    [(0,.56,.60,0,0),(.12,1,1,0,0),(.72,.74,.76,0,0),(1,.50,.60,0,.02)])
                plate("Column phase rail",[(x-.055,.14),(x+.055,.14),(x+.045,.38),(x-.045,.38)],.72,1.63,"energy")
        for z in (-.78,.78):
            angular_housing("Gantry crosshead",(0,1.72,z),1.78,.24,.25,"dark",
                [(0,.76,.72,0,0),(.16,1,1,0,0),(.82,.94,.88,0,0),(1,.68,.70,0,0)])
            rod("Phase-rail conductor",(-.84,1.68,z-.12),(.84,1.68,z-.12),.035,"energy")
        for x in (-.46,.46): rod("Production gantry guide rail",(x,1.66,-.69),(x,1.66,.69),.055,"light")
        crane=pivot("ProductionCrane",(0,1.82,0)); box("Prismatic assembly trolley",(0,1.76,0),(.54,.18,.40),"team",.035,parent=crane)
        for x in (-.25,.25): rod("Suspended manipulator",(x,1.70,0),(x,.83,0),.038,"amber",crane)
        crystal("Vehicle fabrication seed",0,0,.47,.42,.33,"energy")
    elif kind=="tower":
        angular_housing("Beam emitter · three-stage faceted pedestal",(0,.42,0),w*.68,.78,d*.68,"dark",
            [(0,.56,.58,0,0),(.14,1,1,0,0),(.42,.78,.82,0,0),(.67,.56,.62,0,.02),(1,.36,.38,0,.03)])
        for side in (-1,1):
            plate("Emitter ceramic shoulder",[(side*.08,.02),(side*.27,-.06),(side*.22,.22),(side*.09,.27)],.92,1.17,"ceramic")
        plate("Geometric defense dais",[(-.46,-.46),(.46,-.46),(.50,0),(.46,.46),(-.46,.46),(-.50,0)],.44,.74,"steel")
        for x,z in ((-.32,-.32),(.32,-.32),(.32,.32),(-.32,.32)):
            crystal("Tetrahedral lift strut",x,z,.48,.72,.16,"energy")
        gun=pivot("TurretPivot",(0,1.20,0)); crystal("Rotating beam projector",0,0,1.02,.48,.40,"light")
        for side in (-1,1): cyl("Twin coherent emitter",(side*.18,1.24,-.44),.09,.48,"energy","Z",16,gun)
        torus("Beam alignment bearing",(0,1.13,0),.42,.04,"amber",gun)
    elif kind=="radar":
        angular_housing("Sensor array · rising signal plinth",(0,.42,0),w*.72,.82,d*.70,"dark",
            [(0,.58,.72,0,0),(.16,1,.94,0,0),(.50,.78,.72,0,.02),(.80,.52,.52,0,.04),(1,.28,.42,0,.06)])
        for side in (-1,1):
            plate("Phased-array battery cheek",[(side*.10,-.06),(side*.34,-.18),(side*.27,.20),(side*.12,.28)],.80,1.08,"steel")
        crystal("Tall sensor monolith",0,0,.48,1.36,.37,"light")
        rotor=pivot("RadarRotor",(0,1.80,0))
        for i in range(3):
            a=i*math.tau/3; x=math.cos(a)*.56; z=math.sin(a)*.56
            plate("Triangular phased-array wing",[(0,0),(x*.55,z*.55),(x,z)],1.68,1.79,"energy")
            crystal("Wing lens",x,z,1.71,.22,.12,"amber")
        torus("Sensor induction ring",(0,1.80,0),.23,.045,"team",rotor)
    elif kind=="repair":
        angular_housing("Service cradle · open angular base",(0,.42,0),w*.86,.42,d*.82,"dark",
            [(0,.60,.62,0,0),(.22,1,1,0,0),(.55,.82,.80,0,0),(.78,.62,.62,0,.03),(1,.48,.46,0,.04)])
        for side in (-1,1):
            plate("Service cradle side shield",[(side*.16,-.12),(side*.42,-.28),(side*.36,.25),(side*.18,.33)],.67,.91,"ceramic")
        for a in (0,math.pi/2,math.pi,math.pi*1.5):
            x=math.cos(a)*.6; z=math.sin(a)*.6
            rod("Repair lattice upright",(x,.48,z),(x,1.68,z),.055,"light")
        for y in (.74,1.62):
            rod("Service gantry cross-member",(-.66,y,0),(.66,y,0),.06,"energy")
            for side in (-1,1): box("Cross-member clamp",(side*.66,y,0),(.12,.15,.28),"steel",.02)
        for side in (-1,1):
            arm=pivot("RepairArmLeft" if side<0 else "RepairArmRight",(side*.55,1.17,0))
            rod("Articulated laser service arm",(side*.55,1.17,0),(side*.21,.88,-.48),.045,"amber",arm)
            cyl("Precision weld emitter",(side*.21,.88,-.48),.10,.15,"team","Y",16,arm)
        plate("Suspended repair platform",[(-.62,-.7),(.62,-.7),(.52,.7),(-.52,.7)],.48,.61,"dark")
    else:
        angular_housing("Ammunition vault · stepped polygon magazine",(0,.42,0),w*.82,.78,d*.82,"dark",
            [(0,.58,.64,0,0),(.12,1,.92,0,0),(.46,.90,.82,0,0),(.66,.66,.68,0,.04),(1,.38,.44,0,.06)])
        for side in (-1,1):
            plate("Magazine blast cheek",[(side*.12,-.10),(side*.38,-.22),(side*.32,.24),(side*.13,.32)],.88,1.13,"steel")
        for i in range(4):
            a=math.tau*i/4+math.pi/4; x=math.cos(a)*.60; z=math.sin(a)*.60
            angular_housing("Vacuum-sealed ordnance magazine %02d"%i,(x,.48,z),.30,.82,.30,"ceramic",
                [(0,.68,.68,0,0),(.10,1,1,0,0),(.72,.88,.90,0,0),(1,.60,.58,0,.03)])
            plate("Magazine pressure window %02d"%i,[(x-.065,.08),(x+.065,.08),(x+.045,.31),(x-.045,.31)],.86,.90,"energy")
        lift=pivot("OrdnanceLift",(0,1.55,0));
        angular_housing("Automated ammunition elevator",(0,1.4,0),.48,.42,.48,"energy",
            [(0,.50,.54,0,0),(.2,1,1,0,0),(.72,.74,.76,0,0),(1,.42,.48,0,.04)])

def build(faction,kind):
    global _FACTION,M
    _FACTION=faction; M={}; clear(); size=FOOT[kind]; w,d=size[0]*.92,size[1]*.92
    root=bpy.data.objects.new("SOLARIT · %s · %s"%(faction.title(),kind.title()),None); bpy.context.collection.objects.link(root)
    foundation(root,kind,w,d)
    if faction=="drift": wander_role(root,kind,w,d)
    else: prisma_role(root,kind,w,d)
    # Explicitly parent each finished assembly under one imported GLB root,
    # preserving world-space design and every cache-controlled animation pivot.
    for obj in list(bpy.context.scene.objects):
        if obj!=root and obj.parent is None: parent_world(obj,root)
    for obj in [o for o in bpy.context.scene.objects if o.type=="MESH"]:
        bpy.ops.object.select_all(action="DESELECT"); obj.select_set(True); bpy.context.view_layer.objects.active=obj
        bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(island_margin=.02,area_weight=.15,correct_aspect=True,scale_to_bounds=True); bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type in {"MESH","EMPTY"}: obj.select_set(True)
    bpy.context.view_layer.objects.active=root
    source=SRC/(faction+"_"+kind+".blend"); glb=OUT/(faction+"_"+kind+".glb")
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    bpy.ops.export_scene.gltf(filepath=str(glb),export_format="GLB",export_apply=True,export_yup=True,export_extras=True,export_materials="EXPORT")
    print("FACTION BUILDING",faction,kind,"meshes",sum(o.type=="MESH" for o in bpy.context.scene.objects))

def main():
    bpy.context.preferences.filepaths.save_version=0
    for faction in ("drift","lumen"):
        for kind in FOOT: build(faction,kind)

if __name__=="__main__": main()
