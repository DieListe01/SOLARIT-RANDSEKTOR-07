"""Author the seven non-collector SOLARIT combat/recon vehicle assets.

Run with Blender 4.5+:
  blender --background --python tools/create_vehicle_assets.py

The eight vehicle roles (including the separately rigged collector) use distinct
silhouettes and purpose-built hardware. This source deliberately keeps the GLB
contract small: forward is -Z, the floor is Y=0, team ID hardware is named
TeamColor, and the root can be rotated by the existing Godot cache painter.
"""
from __future__ import annotations

import math
import os
import importlib.util
import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "models", "vehicles")
SOURCE = os.path.join(ROOT, "assets", "models", "source")
TEXTURES = os.path.join(ROOT, "assets", "models", "textures", "industrial")
VEHICLE_SOURCE = os.path.join(SOURCE, "vehicles")
os.makedirs(OUT, exist_ok=True)
os.makedirs(SOURCE, exist_ok=True)
os.makedirs(VEHICLE_SOURCE, exist_ok=True)

COLORS = {
    "armor": (.66, .57, .39, 1), "armor_light": (.82, .73, .51, 1),
    "dark": (.052, .071, .067, 1), "steel": (.25, .30, .27, 1),
    "rubber": (.018, .027, .025, 1), "track": (.12, .15, .14, 1),
    "glass": (.018, .14, .15, 1), "team": (.02, .88, .73, 1),
    "amber": (1, .28, .025, 1), "hazard": (.91, .57, .13, 1),
    "energy": (.02, .80, .69, 1), "red": (.58, .17, .10, 1),
}
M = {}

def material(key):
    if key in M: return M[key]
    name = "TeamColor · vehicle identification" if key == "team" else "Vehicle / " + key
    m = bpy.data.materials.new(name)
    m.diffuse_color = COLORS[key]
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = COLORS[key]
    p.inputs["Metallic"].default_value = .72 if key in {"steel", "track", "dark", "hazard"} else .28
    p.inputs["Roughness"].default_value = .34 if key in {"glass", "energy", "team"} else .53
    if key in {"team", "energy", "amber"}:
        p.inputs["Emission Color"].default_value = COLORS[key]
        p.inputs["Emission Strength"].default_value = 1.15 if key == "team" else .7
    texture_key={"armor":"ceramic","armor_light":"ceramic","dark":"graphite","steel":"steel","rubber":"rubber","track":"steel","team":"enamel","energy":"enamel","amber":"safety","hazard":"safety","red":"safety"}.get(key)
    if texture_key and os.path.isdir(TEXTURES):
        nodes=m.node_tree.nodes; links=m.node_tree.links
        for suffix,space,socket in [("albedo","sRGB","Base Color"),("roughness","Non-Color","Roughness")]:
            image_path=os.path.join(TEXTURES,texture_key+"_"+suffix+".png")
            if not os.path.isfile(image_path): continue
            image=bpy.data.images.load(image_path,check_existing=True); image.colorspace_settings.name=space
            texture=nodes.new("ShaderNodeTexImage"); texture.name="SOLARIT shared "+suffix+" · "+texture_key; texture.image=image
            links.new(texture.outputs["Color"],p.inputs[socket])
        normal_path=os.path.join(TEXTURES,texture_key+"_normal.png")
        if os.path.isfile(normal_path):
            image=bpy.data.images.load(normal_path,check_existing=True); image.colorspace_settings.name="Non-Color"
            texture=nodes.new("ShaderNodeTexImage"); texture.name="SOLARIT shared PBR normal · "+texture_key; texture.image=image
            normal=nodes.new("ShaderNodeNormalMap"); normal.inputs["Strength"].default_value=.12
            links.new(texture.outputs["Color"],normal.inputs["Color"]); links.new(normal.outputs["Normal"],p.inputs["Normal"])
    M[key] = m
    return m

def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

def finish_obj(o, key, name=None, bevel_width=0):
    o.name = name or o.name
    o.data.materials.append(material(key))
    if bevel_width:
        b=o.modifiers.new("Forged edge radii", "BEVEL"); b.width=bevel_width; b.segments=2
        n=o.modifiers.new("Weighted face normals", "WEIGHTED_NORMAL"); n.keep_sharp=True
    return o

def box(name, center, size, key="armor", bevel_width=.025, rotation=0):
    x,y,z=center; sx,sy,sz=size
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x,z,y))
    o=bpy.context.object; o.dimensions=(sx,sz,sy); o.rotation_euler.z=rotation
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish_obj(o,key,name,bevel_width)

def cyl(name, center, radius, depth, key="steel", axis="Y", vertices=20):
    x,y,z=center
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=(x,z,y))
    o=bpy.context.object
    if axis=="X": o.rotation_euler.y=math.pi/2
    elif axis=="Z": o.rotation_euler.x=math.pi/2
    return finish_obj(o,key,name,.012)

def mesh(name, verts, faces, key, bevel_width=.015):
    # Mesh input is authored in game coordinates: X width, Y up, Z depth.
    data=bpy.data.meshes.new(name+" · mesh")
    data.from_pydata([(x,z,y) for x,y,z in verts],[],faces); data.materials.append(material(key)); data.validate(); data.update()
    o=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(o)
    if bevel_width:
        b=o.modifiers.new("Forged edge radii","BEVEL"); b.width=bevel_width; b.segments=2
        n=o.modifiers.new("Weighted face normals","WEIGHTED_NORMAL"); n.keep_sharp=True
    return o

def loft(name, stations, key="armor"):
    """Purpose-specific closed faceted hull. station=(z,width,bottom,deck,shoulder)."""
    v=[]
    for z,w,bottom,deck,shoulder in stations:
        v.extend([(-w,bottom,z),(w,bottom,z),(w,shoulder,z),(w*.76,deck,z),(-w*.76,deck,z),(-w,shoulder,z)])
    f=[(5,4,3,2,1,0)]
    for r in range(len(stations)-1):
        a=r*6; q=(r+1)*6
        for i in range(6): f.append((a+i,a+(i+1)%6,q+(i+1)%6,q+i))
    f.append(tuple((len(stations)-1)*6+i for i in range(6)))
    return mesh(name,v,f,key,.035)

def rod(name, a, b, radius, key="steel", vertices=12):
    av,bv=Vector(a),Vector(b); diff=bv-av
    o=cyl(name,tuple((av+bv)*.5),radius,diff.length,key,"Y",vertices)
    o.rotation_euler[0]=math.atan2(diff.x,diff.y)
    o.rotation_euler[2]=math.atan2(-diff.z,math.sqrt(diff.x*diff.x+diff.y*diff.y))
    return o

def wheel_pair(x, z, radius, count, spacing, key="rubber"):
    for i in range(count):
        zz=z+i*spacing
        cyl("Armored road wheel",(x,.39,zz),radius,.13,"dark","X",20)
        cyl("Machined road wheel hub",(x*1.035,.39,zz),radius*.53,.16,"steel","X",16)
        cyl("Hub fastener",(x*1.06,.39,zz),radius*.18,.17,"hazard","X",12)

def track(x, length=2.5, height=.50, width=.22):
    # A continuous belt plus visible grousers and five independent roller stacks.
    z0=-length*.47; z1=length*.47; bottom=.27; top=bottom+height
    radius=height*.48; mid=(top+bottom)*.5
    path=[]
    for i in range(13): path.append((x,top,z0+(z1-z0)*i/12))
    for i in range(1,13):
        a=math.pi/2-math.pi*i/12; path.append((x,mid+radius*math.sin(a),z1+radius*math.cos(a)))
    for i in range(1,13): path.append((x,bottom,z1-(z1-z0)*i/12))
    for i in range(1,13):
        a=-math.pi/2+math.pi*i/12; path.append((x,mid+radius*math.sin(a),z0-radius*math.cos(a)))
    verts=[]
    for px,py,pz in path: verts += [(px-width*.5,py,pz),(px+width*.5,py,pz)]
    faces=[(2*i,2*i+1,2*((i+1)%len(path))+1,2*((i+1)%len(path))) for i in range(len(path))]
    mesh("Continuous reinforced track belt",verts,faces,"rubber",0)
    for i in range(36):
        t=i/36; q=int(t*len(path)); px,py,pz=path[q]
        box("Replaceable articulated steel track shoe",(px,py,pz),(width*1.10,.095,.105),"track",.014,rotation=(math.pi/2 if 8<=q<20 or 26<=q<38 else 0))
        if i%2==0: box("Raised traction grouser",(px,py-.046,pz),(width*.58,.035,.045),"steel",.006)
    wheel_pair(x, z0+.18, radius*.75, 5, (z1-z0-.32)/4)
    for zz in (z0,z1):
        cyl("Track idler sprocket",(x,.51,zz),radius*.9,.15,"steel","X",24)
        cyl("Sprocket center cap",(x*1.04,.51,zz),radius*.45,.17,"hazard","X",20)

def wheels(x_values,z_values,radius):
    for x in x_values:
        for z in z_values:
            cyl("Independent all-terrain tire",(x,.30,z),radius,.16,"rubber","X",24)
            cyl("Forged wheel rim",(x*1.04,.30,z),radius*.55,.18,"hazard", "X",16)
            cyl("Axle locking hub",(x*1.07,.30,z),radius*.22,.19,"steel","X",12)

def panel_rivets(xside, zlist, y=.62):
    for z in zlist:
        cyl("Captive armor bolt",(xside,y,z),.025,.025,"hazard","X",8)

def lights(width, front=-1):
    for side in (-1,1):
        cyl("Armored headlamp socket",(side*width*.31,.63,-.47),.095,.045,"dark","X",16)
        cyl("Ceramic headlamp",(side*width*.31,.63,-.50),.065,.05,"team","X",16)
        box("Rear marker",(side*width*.30,.54,.44),(.09,.075,.06),"amber",.012)

def base_track_hull(kind):
    specs={
      "tank":(1.08,2.72,[( -.50,.22,.38,.60,.52),(-1.12,.84,.26,.87,.64),(-.88,1.00,.25,1.10,.80),(.64,1.00,.25,1.09,.82),(1.12,.88,.27,.90,.65),(1.32,.63,.35,.62,.49)]),
      "siege":(1.22,3.18,[(-.58,.25,.38,.63,.53),(-1.50,.90,.26,.92,.67),(-1.12,1.10,.25,1.12,.84),(.96,1.10,.25,1.12,.84),(1.52,.96,.27,.95,.70),(1.68,.72,.34,.67,.52)]),
      "scorcher":(.98,2.52,[(-.48,.22,.36,.57,.48),(-1.08,.78,.26,.83,.62),(-.78,.94,.25,1.0,.75),(.60,.94,.25,1.02,.76),(1.08,.79,.27,.85,.63),(1.30,.58,.34,.60,.48)]),
      "bulwark":(1.38,3.65,[(-.62,.28,.39,.72,.60),(-1.77,1.05,.26,1.02,.76),(-1.48,1.30,.25,1.22,.93),(1.10,1.30,.25,1.23,.93),(1.70,1.12,.27,1.04,.77),(1.82,.76,.36,.76,.61)]),
    }
    width,length,stations=specs[kind]
    loft(kind.title()+" · welded six-facet armored hull",stations,"armor")
    track(-width*.84,length*.79,.50,width*.36); track(width*.84,length*.79,.50,width*.36)
    # Layered side armor, segmented skirts, access plates and visible hardware.
    for side in (-1,1):
        box("Replaceable side armor skirt",(side*width*.88,.64,0),(.18,.35,length*.58),"armor_light",.045)
        for j,z in enumerate((-.78,-.39,0,.39,.78)):
            box("Skirt segment seam",(side*width*.985,.64,z),(.026,.26,.018),"dark",.005)
            if j%2==0: cyl("Skirt fastener",(side*width*1.005,.74,z),.027,.022,"steel","X",10)
        box("Engine ventilation intake",(side*width*.75,.93,.59),(.24,.10,.46),"dark",.02)
        for j in range(5): box("Cooling louver",(side*width*.88,.96,.41+j*.085),(.07,.04,.035),"steel",.006)
        panel_rivets(side*width*1.01,[-.72,-.25,.25,.72])
    for i in range(7): box("Engine deck heat louver",(-.48+i*.16,.98,.72),(.055,.035,.34),"dark",.005,rotation=.10)
    box("TeamColor",(0,.96,.98),(width*.36,.085,.055),"team",.015)
    box("Forward glacis team stripe",(0,.76,-.96),(width*.25,.05,.26),"team",.012,rotation=-.22)
    lights(width)
    # Rear cooling hardware and a protected tow assembly.
    for side in (-1,1):
        cyl("Exhaust armored elbow",(side*.42,.88,.99),.11,.30,"steel","Y",16)
        cyl("Blackened exhaust mouth",(side*.42,1.04,.99),.067,.025,"dark","Y",16)
        rod("Rear tow shackle",(side*.55,.35,1.48),(side*.55,.35,1.61),.055,"hazard")
    return width,length

def turret(center_y=.92, width=.90, length=1.03, height=.48, style="tank"):
    # Beveled turntable and lofted asymmetrical turret, with a clear forward slope.
    made_before=set(bpy.context.scene.objects)
    cyl("Turret race ring",(0,center_y-.07,0),width*.55,.15,"dark","Y",32)
    cyl("Bearing teeth",(0,center_y-.02,0),width*.49,.06,"hazard","Y",32)
    loft(style.title()+" · faceted traversing gunhouse",[
      (-length*.50, width*.38,center_y,center_y+height*.56,center_y+height*.44),
      (-length*.37,width*.49,center_y,center_y+height*.90,center_y+height*.62),
      (length*.25,width*.50,center_y,center_y+height,center_y+height*.69),
      (length*.50,width*.36,center_y,center_y+height*.60,center_y+height*.43)],"armor")
    # The model loader rotates this pivot to follow the simulated turret angle.
    marker=bpy.data.objects.new("Turret",None); bpy.context.collection.objects.link(marker)
    marker.location=(0,0,center_y); marker.empty_display_type="PLAIN_AXES"; marker.empty_display_size=.01
    box("TeamColor",(0,center_y+height+.035,.12),(width*.30,.055,length*.25),"team",.012)
    cyl("Commander hatch",(-width*.22,center_y+height+.04,length*.19),width*.12,.07,"dark","Y",20)
    cyl("Targeting optic",(width*.30,center_y+height*.01,-length*.25),.09,.12,"glass","Y",20)
    for side in (-1,1):
        box("Turret cheek applique",(side*width*.49,center_y+height*.42,0),(.08,height*.42,length*.48),"armor_light",.02)
    bpy.context.view_layer.update()
    for obj in list(bpy.context.scene.objects):
        if obj not in made_before and obj != marker:
            world=obj.matrix_world.copy(); obj.parent=marker; obj.matrix_parent_inverse=marker.matrix_world.inverted(); obj.matrix_world=world
    return marker

def design(kind):
    clear(); root=bpy.data.objects.new("SOLARIT · "+kind.title(),None); bpy.context.collection.objects.link(root)
    root["asset_role"]=kind; root["forward_axis"]="-Z"; root["ground_plane"]="Y=0"
    if kind in {"tank","siege","scorcher","bulwark"}:
        width,length=base_track_hull(kind)
        if kind=="tank":
            t=turret(.97,1.02,1.20,.52,"Amboss MBT")
            rod("Long rifled cannon",(0,1.60,-.30),(0,1.61,-1.46),.105,"steel")
            cyl("Thermal muzzle brake",(0,1.61,-1.49),.15,.17,"dark","Z",20)
            box("Mantlet armored sleeve",(0,1.48,-.42),(.42,.35,.42),"dark",.06)
            for side in (-1,1): cyl("Smoke discharger",(side*.49,1.33,.28),.07,.15,"hazard","X",12)
        elif kind=="siege":
            turret(1.0,1.23,1.18,.60,"Echo siege")
            # Open trunnion cradle, long elevated barrel, recoil buffer and shell rack.
            box("Open artillery cradle",(0,1.72,-.10),(1.06,.20,.86),"dark",.035)
            for side in (-1,1):
                cyl("Elevation trunnion",(side*.58,1.75,-.12),.20,.12,"hazard","X",20)
                box("Recoil rail",(side*.28,1.83,-.72),(.08,.10,1.18),"steel",.02)
                box("Armored shell rack",(side*.92,1.15,.38),(.24,.52,.85),"dark",.045)
                for i in range(3): cyl("Capped artillery round",(side*.94,1.06+i*.15,.22),.095,.34,"hazard","Z",16)
                rod("Deployable firing leg",(side*.88,.48,.48),(side*1.58,.17,1.23),.095,"steel")
                box("Spade anchor foot",(side*1.58,.14,1.24),(.52,.16,.34),"dark",.04)
            rod("Long recoil barrel",(0,1.95,-.43),(0,2.17,-2.26),.14,"steel")
            cyl("Artillery muzzle shroud",(0,2.17,-2.25),.22,.32,"dark","Z",24)
            cyl("Muzzle aperture",(0,2.17,-2.43),.16,.025,"amber","Z",24)
            for i in range(6): box("Barrel thermal fin",(-.16+i*.064,1.99,-.92),(.025,.12,.68),"hazard",.008)
        elif kind=="scorcher":
            turret(.89,1.0,.93,.36,"Vulcan flame projector")
            for side in (-1,1):
                cyl("Protected propellant vessel",(side*.77,.84,.30),.24,.88,"red","Z",24)
                cyl("Vessel end cap",(side*.77,.84,-.17),.26,.10,"hazard","Z",24)
                for j in range(3): cyl("Fuel tank strap",(side*.77,.84,.12+j*.20),.255,.045,"steel","Z",20)
                rod("Fuel feed pressure pipe",(side*.66,.91,-.18),(side*.42,1.05,-.58),.055,"amber")
            # Two unmistakable burner lances, ceramic nozzles and heat shields.
            for side in (-1,1):
                box("Flame projector armored shroud",(side*.28,1.27,-.61),(.30,.33,.48),"dark",.06)
                cyl("Twin thermal lance",(side*.28,1.26,-.96),.105,.63,"steel","Z",20)
                cyl("Ceramic burner nozzle",(side*.28,1.26,-1.29),.16,.13,"hazard","Z",20)
                cyl("Amber combustion aperture",(side*.28,1.26,-1.36),.105,.018,"amber","Z",20)
            for i in range(7): box("Heat warning stripe",(-.55+i*.18,.51,-1.20),(.08,.06,.025),"hazard",.008,rotation=.45 if i%2 else -.45)
        elif kind=="bulwark":
            turret(1.05,1.40,1.26,.66,"Bulwark assault")
            # A broad shielded ram and side sponsons define the break-through silhouette.
            box("Full-width assault mantlet",(0,.73,-1.37),(2.16,.68,.36),"dark",.10,rotation=-.11)
            for side in (-1,1):
                box("Replaceable ram blade",(side*.82,.78,-1.55),(.54,.50,.28),"armor_light",.07,rotation=side*.12)
                box("Side assault sponson",(side*1.16,.83,-.34),(.28,.57,.68),"dark",.055)
                cyl("Sponson rotary cannon",(side*1.25,.88,-.77),.12,.61,"steel","Z",20)
                box("Reactive armor slab",(side*1.04,1.08,.40),(.16,.34,.72),"hazard",.035)
            rod("Heavy cannon",(0,1.91,-.27),(0,1.94,-1.86),.17,"steel")
            cyl("Heavy muzzle brake",(0,1.94,-1.89),.23,.25,"dark","Z",24)
    elif kind=="scout":
        # A fast six-wheel rover with a very high multi-band sensor head.
        loft("Needle scout · narrow faceted chassis",[
          (-.48,.18,.32,.55,.48),(-1.03,.48,.25,.70,.52),(-.72,.63,.25,.82,.61),
          (.58,.58,.25,.72,.52),(1.02,.48,.27,.64,.46),(1.22,.29,.34,.48,.40)],"armor")
        wheels((-.52,.52),(-.83,0,.83),.24)
        for side in (-1,1):
            box("Scout fender flare",(side*.56,.53,-.05),(.12,.16,1.40),"dark",.025)
            box("Sensor team panel",(side*.55,.76,-.05),(.035,.09,.40),"team",.01)
        box("Scout armored crew pod",(0,.76,.06),(.72,.30,.61),"dark",.09)
        box("Panoramic front optical glass",(0,.81,-.27),(.54,.15,.055),"glass",.025)
        for side in (-1,1): rod("Suspension wishbone",(side*.35,.28,.38),(side*.62,.40,.70),.035,"steel")
        box("Mast foot",(0,.92,.16),(.38,.14,.36),"steel",.035)
        rod("Tri-band recon mast",(0,.98,.16),(0,1.86,.16),.045,"hazard")
        for y in (1.28,1.48,1.68):
            cyl("Rotating scan band",(0,y,.16),.18,.07,"team","Y",24)
            cyl("Scanner dark lens",(0,y,.16),.12,.075,"glass","Y",24)
        box("Forward tow blade",(0,.40,-1.00),(1.12,.14,.15),"steel",.035)
        lights(.65)
    elif kind=="raider":
        # A three-axle high-speed wedge with exposed traction and ram nose.
        loft("Marauder raider · low arrowhead hull",[
          (-.26,.17,.30,.54,.47),(-1.30,.51,.25,.69,.49),(-.90,.80,.25,.82,.60),
          (.45,.75,.25,.86,.64),(1.12,.62,.27,.73,.55),(1.38,.36,.34,.53,.43)],"armor")
        wheels((-.72,.72),(-.89,-.12,.65),.29)
        for side in (-1,1):
            box("Sloped flank armor",(side*.76,.54,-.10),(.14,.35,1.48),"dark",.05,rotation=side*.12)
            box("Ram cleaver wing",(side*.78,.48,-.90),(.52,.19,.54),"hazard",.045,rotation=side*.20)
            rod("Suspension arm",(side*.42,.30,.48),(side*.74,.47,.66),.045,"steel")
            box("External turbine intake",(side*.47,.81,.43),(.25,.24,.32),"dark",.06)
            for i in range(4): box("Intake grille",(side*.60,.83,.32+i*.07),(.035,.15,.035),"steel",.006)
        box("Forward impact ram",(0,.48,-1.29),(1.24,.20,.28),"steel",.05)
        cyl("Ram center piston",(0,.55,-1.39),.13,.42,"team","Z",16)
        box("Compact remote weapon station",(0,.94,.13),(.76,.32,.62),"dark",.075)
        for side in (-1,1): cyl("Twin autocannon",(side*.20,1.02,-.44),.085,.90,"steel","Z",16)
        cyl("Turret optic",(0,1.20,.07),.105,.08,"glass","Y",16)
        box("TeamColor",(0,1.14,.36),(.40,.05,.22),"team",.01)
        lights(.78)
    elif kind=="lancer":
        # A six-point hover skimmer with bilateral capacitors and paired lances.
        loft("Prism lancer · swept hover skimmer",[
          (-.33,.20,.31,.57,.48),(-1.46,.47,.28,.73,.56),(-.98,.82,.28,.90,.70),
          (.66,.82,.28,.91,.72),(1.37,.65,.30,.77,.59),(1.58,.30,.37,.55,.44)],"armor")
        for side in (-1,1):
            box("Sculpted lift nacelle",(side*.92,.40,.16),(.36,.32,1.24),"dark",.10,rotation=side*.13)
            cyl("Ventral lift coil",(side*.91,.22,-.44),.24,.08,"energy","Y",24)
            cyl("Ventral lift coil",(side*.91,.22,.64),.24,.08,"energy","Y",24)
            box("Arcane wingtip",(side*1.15,.49,-.76),(.28,.14,.54),"team",.04,rotation=side*.23)
            cyl("Phase capacitor housing",(side*.55,.92,.28),.20,.74,"steel","Z",24)
            cyl("Exposed luminous capacitor",(side*.55,.94,.28),.125,.68,"energy","Z",20)
            box("Lance emitter gimbal",(side*.32,1.08,-.55),(.30,.27,.48),"dark",.05)
            cyl("Coherent beam lance",(side*.32,1.08,-.91),.075,.55,"steel","Z",16)
            cyl("Prism aperture",(side*.32,1.08,-1.20),.105,.10,"team","Z",20)
            box("Ceramic wing armor",(side*.65,.68,-.20),(.30,.12,.84),"armor_light",.035,rotation=side*.15)
        box("Raised prism command cockpit",(0,.97,.37),(.73,.38,.65),"dark",.11)
        box("Forward prism canopy",(0,1.07,.04),(.51,.21,.045),"glass",.018)
        box("TeamColor",(0,1.24,.33),(.35,.055,.22),"team",.012)
    else:
        raise ValueError("unknown vehicle kind: "+kind)
    # Universal plate work, directional markings, tie-downs, cables and damage relief.
    for side in (-1,1):
        for z in (-.72,.63):
            rod("External service conduit",(side*.40,.73,z),(side*.46,.89,z+.18),.025,"hazard")
        for i in range(3):
            box("Service panel hinge",(side*.43,.78,.28+i*.13),(.035,.035,.055),"steel",.006)
    # A shared, high-contrast owner plate makes friend/enemy identity readable
    # on every role, including the minimal recon rover and hover skimmer.
    box("TeamColor",(0,1.28,.57),(.66,.07,.30),"team",.018)
    # Side enamel plates remain visible when a unit is turned diagonally and
    # give the owner color enough area to distinguish allied and hostile hulls.
    side_mark_x={"scout":.55,"raider":.72,"tank":.91,"siege":.91,"lancer":.78,"scorcher":.78,"bulwark":1.02}[kind]
    for side in (-1,1):
        box("TeamColor flank identification plate",(side*side_mark_x,.77,.30),(.055,.20,.54),"team",.012)
    # Damage states are separate authored overlays. The existing cache toggles
    # these nodes from simulated hit points, so default renders remain pristine.
    for node_name, level, key in (("DamageLight",.035,"dark"),("DamageHeavy",-.03,"hazard")):
        node=bpy.data.objects.new(node_name,None); bpy.context.collection.objects.link(node)
        node.location=(.38,0,-.06); node.empty_display_type="PLAIN_AXES"; node.empty_display_size=.01
        for i in range(3 if node_name=="DamageLight" else 5):
            shard=box("Battle damage torn armor facet",(.38+(i%2)*.10,.93+i*.018,-.06+(i//2)*.09),(.18,.024,.07),key,.006,rotation=(i%2)*.28)
            world=shard.matrix_world.copy(); shard.parent=node; shard.matrix_parent_inverse=node.matrix_world.inverted(); shard.matrix_world=world
    # Consolidate static fittings by material and transform parent. The game
    # caches each rendered pose, but fewer imported meshes also keeps first-use
    # renders and cache invalidations inexpensive. Preserve role features,
    # damage overlays, and the separately traversing turret as named nodes.
    signatures={
      "scout":"Tri-band recon mast", "tank":"Long rifled cannon",
      "siege":"Deployable firing leg", "raider":"Forward impact ram",
      "lancer":"Coherent beam lance", "scorcher":"Protected propellant vessel",
      "bulwark":"Full-width assault mantlet",
    }
    grouped={}
    for obj in list(bpy.context.scene.objects):
        if obj.type!="MESH" or obj.name==signatures[kind]: continue
        for modifier in list(obj.modifiers):
            bpy.context.view_layer.objects.active=obj
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        mat_name=obj.data.materials[0].name if obj.data.materials else "None"
        grouped.setdefault((obj.parent,mat_name),[]).append(obj)
    for (parent,mat_name),objects in grouped.items():
        if len(objects)<2: continue
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects: obj.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        bpy.ops.object.join()
        merged=bpy.context.object
        if mat_name.startswith("TeamColor"):
            merged.name="TeamColor"
        elif parent is not None and parent.name in {"DamageLight","DamageHeavy"}:
            merged.name=parent.name+" overlay"
        else:
            merged.name="Static · "+mat_name
        merged.data.name=merged.name+" · consolidated mesh"
    # UV unwrap the consolidated static armor and animation pieces once during
    # authoring; runtime instances share these PBR maps through the GLB cache.
    for obj in [item for item in bpy.context.scene.objects if item.type=="MESH"]:
        bpy.ops.object.select_all(action="DESELECT"); obj.select_set(True); bpy.context.view_layer.objects.active=obj
        bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(island_margin=.018,area_weight=.18,correct_aspect=True,scale_to_bounds=True)
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(VEHICLE_SOURCE,kind+".blend"))
    # Export with transform-free object geometries and a root marker. Every GLB
    # remains independently editable in the bundled .blend source file.
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type in {"MESH","EMPTY"}: obj.select_set(True)
    bpy.context.view_layer.objects.active=root
    exporter=bpy.ops.export_scene.gltf
    allowed={p.identifier for p in exporter.get_rna_type().properties}
    kwargs={"filepath":os.path.join(OUT,kind+".glb"),"export_format":"GLB","export_apply":True,"export_yup":True,"export_extras":True,"export_materials":"EXPORT"}
    exporter(**{k:v for k,v in kwargs.items() if k in allowed})
    print("Exported detailed vehicle:",kind,"mesh objects",sum(1 for o in bpy.context.scene.objects if o.type=="MESH"))

def main():
    bpy.context.preferences.filepaths.save_version=0
    for kind in ("scout","tank","siege","raider","lancer","scorcher","bulwark"):
        design(kind)
    postprocess_path=os.path.join(ROOT,"tools","externalize_glb_textures.py")
    spec=importlib.util.spec_from_file_location("externalize_glb_textures",postprocess_path)
    texture_pipeline=importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(texture_pipeline)
    texture_pipeline.externalize_directory(__import__("pathlib").Path(OUT))
    print("Saved one editable Blender source scene per vehicle:",VEHICLE_SOURCE)

if __name__=="__main__": main()
