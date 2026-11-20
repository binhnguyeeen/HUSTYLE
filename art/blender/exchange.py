# Builds the HUSTYLE Stock Exchange title background and renders it.
# Look: Apple Maps 3D at night. Matte clay shapes, slate blue, warm key light.
# Run: blender -b -P art/blender/exchange.py -- [preview]
import math
import os
import random
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
PREVIEW = "preview" in sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else False
OUT = os.path.join(ROOT, "art", "renders", "exchange_preview.png" if PREVIEW else "exchange.png")
BLEND = os.path.join(HERE, "exchange.blend")

random.seed(7)

# ---------- scene reset ----------
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def lin(hex_str):
    """sRGB hex to linear RGBA."""
    h = hex_str.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (*out, 1.0)


def material(name, hex_str, rough=0.9, emit=None, emit_strength=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = lin(hex_str)
    bsdf.inputs["Roughness"].default_value = rough
    if emit:
        bsdf.inputs["Emission Color"].default_value = lin(emit)
        bsdf.inputs["Emission Strength"].default_value = emit_strength
    return m


M = {
    "stone": material("Stone", "#A7AEBF"),
    "stone_dark": material("StoneDark", "#7E879C"),
    "recess": material("Recess", "#26324A"),
    "glass": material("Glass", "#1C2638", rough=0.35, emit="#F3C77A", emit_strength=0.0),
    "glass_lit": material("GlassLit", "#2A2A2A", rough=0.5, emit="#F6CE84", emit_strength=1.1),
    "ground": material("Ground", "#3A4A63"),
    "street": material("Street", "#2C3A52"),
    "tower": material("Tower", "#8590A8"),
    "tower_win": material("TowerWin", "#2B3954"),
    "banner": material("Banner", "#EDC75B", rough=0.7),
    "leaf": material("Leaf", "#4C6B66"),
    "metal": material("Metal", "#2A3346", rough=0.6),
}


def box(name, x0, x1, y0, y1, z0, z1, mat, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.active_object
    o.name = name
    o.scale = (x1 - x0, y1 - y0, z1 - z0)
    o.location = ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
    bpy.ops.object.transform_apply(scale=True)
    if bevel > 0:
        b = o.modifiers.new("Bevel", "BEVEL")
        b.width = bevel
        b.segments = 2
    o.data.materials.append(mat)
    return o


def cyl(name, x, y, z0, z1, r, mat, verts=24, r_top=None):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r if r_top is None else r_top,
                                    depth=z1 - z0, location=(x, y, (z0 + z1) / 2))
    o = bpy.context.active_object
    o.name = name
    bpy.ops.object.shade_smooth()
    o.data.materials.append(mat)
    return o


def prism(name, verts2d, y0, y1, mat):
    """Extrude a polygon given in (x, z) along y."""
    me = bpy.data.meshes.new(name)
    n = len(verts2d)
    vs = [(x, y0, z) for x, z in verts2d] + [(x, y1, z) for x, z in verts2d]
    faces = [list(range(n))[::-1], list(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append([i, j, n + j, n + i])
    me.from_pydata(vs, [], faces)
    me.update()
    o = bpy.data.objects.new(name, me)
    scene.collection.objects.link(o)
    o.data.materials.append(mat)
    return o


# ---------- ground and street ----------
box("Ground", -200, 200, -120, 200, -0.2, 0.0, M["street"])
box("Sidewalk", -60, 60, -14, 0, 0.0, 0.25, M["ground"])

# ---------- main building ----------
W = 23.0  # half width of the facade
box("Body", -W, W, 0, 32, 0, 34, M["stone"])
# podium (ground floor) with arched doors as dark recesses
box("Podium", -W - 0.5, W + 0.5, -3.2, 0, 0, 8, M["stone"], bevel=0.05)
for i, x in enumerate([-17, -10.5, -3.5, 3.5, 10.5, 17]):
    box(f"Door{i}", x - 1.6, x + 1.6, -3.35, -3.0, 0.25, 4.6, M["recess"])
    # round top of the arched door: a thin disc facing the street
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=1.6, depth=0.35,
                                        location=(x, -3.18, 4.6), rotation=(math.radians(90), 0, 0))
    bpy.context.active_object.name = f"Arch{i}"
    bpy.context.active_object.data.materials.append(M["recess"])
# balustrade on podium
box("Rail", -W, W, -3.6, -2.6, 8, 8.35, M["stone"])
box("RailTop", -W, W, -3.7, -2.5, 9.6, 9.9, M["stone"])
for k in range(60):
    x = -W + 0.5 + k * (2 * W - 1) / 59
    cyl(f"Baluster{k}", x, -3.1, 8.35, 9.6, 0.18, M["stone_dark"], verts=10)

# corner piers
for s in (-1, 1):
    box(f"Pier{s}", s * W - (5 if s > 0 else 0), s * W + (0 if s > 0 else 5), -3.4, 0, 8, 24.5, M["stone"], bevel=0.05)

# recessed glass wall behind the columns, with mullions and a few lit panes
GX0, GX1, GZ0, GZ1 = -18, 18, 9.9, 23.6
box("GlassWall", GX0, GX1, -0.4, 0.0, GZ0, GZ1, M["glass"])
for k in range(13):
    x = GX0 + k * (GX1 - GX0) / 12
    box(f"MullionV{k}", x - 0.12, x + 0.12, -0.7, -0.4, GZ0, GZ1, M["metal"])
for k in range(7):
    z = GZ0 + k * (GZ1 - GZ0) / 6
    box(f"MullionH{k}", GX0, GX1, -0.7, -0.4, z - 0.08, z + 0.08, M["metal"])
for k in range(8):
    c = random.randint(0, 11)
    r = random.randint(0, 5)
    x0 = GX0 + c * 3 + 0.15
    z0 = GZ0 + r * (GZ1 - GZ0) / 6 + 0.12
    box(f"Lit{k}", x0, x0 + 2.7, -0.48, -0.42, z0, z0 + (GZ1 - GZ0) / 6 - 0.24, M["glass_lit"])

# six columns with bases and capitals
COLS = [-15, -9, -3, 3, 9, 15]
for i, x in enumerate(COLS):
    y = -1.6
    box(f"ColBase{i}", x - 1.5, x + 1.5, y - 1.5, y + 1.5, 9.9, 10.5, M["stone"], bevel=0.08)
    cyl(f"ColTorus{i}", x, y, 10.5, 10.9, 1.35, M["stone"])
    cyl(f"Col{i}", x, y, 10.9, 22.2, 1.1, M["stone"], verts=32, r_top=0.98)
    cyl(f"ColNeck{i}", x, y, 22.2, 22.6, 1.05, M["stone"], r_top=1.25)
    cyl(f"ColCap{i}", x, y, 22.6, 23.6, 1.25, M["stone"], verts=16, r_top=1.75)
    box(f"ColAbacus{i}", x - 1.85, x + 1.85, y - 1.85, y + 1.85, 23.6, 24.2, M["stone"], bevel=0.06)

# entablature, frieze text and cornice
box("Architrave", -W, W, -3.6, 1, 24.2, 25.4, M["stone"], bevel=0.05)
box("Frieze", -W, W, -3.3, 1, 25.4, 27.6, M["stone"])
box("Cornice", -W - 0.8, W + 0.8, -4.4, 1, 27.6, 28.5, M["stone"], bevel=0.08)
bpy.ops.object.text_add(location=(0, -3.36, 25.85), rotation=(math.radians(90), 0, 0))
t = bpy.context.active_object
t.name = "FriezeText"
t.data.body = "HUSTYLE  STOCK  EXCHANGE"
t.data.align_x = "CENTER"
t.data.size = 1.55
t.data.extrude = 0.08
t.data.space_character = 1.15
t.data.materials.append(M["stone_dark"])

# pediment with a recessed tympanum and blobby statues
PW, PH = 21.5, 7.5
prism("Pediment", [(-PW, 28.5), (PW, 28.5), (0, 28.5 + PH)], -4.2, 1, M["stone"])
prism("Tympanum", [(-PW + 2.6, 29.0), (PW - 2.6, 29.0), (0, 28.5 + PH - 1.4)], -4.35, -4.2, M["stone_dark"])
prism("RakeL", [(-PW - 0.9, 28.3), (-PW + 0.6, 28.3), (0.0, 28.5 + PH + 0.9), (0.0, 28.5 + PH - 0.4)], -4.8, 1, M["stone"])
prism("RakeR", [(PW - 0.6, 28.3), (PW + 0.9, 28.3), (0.0, 28.5 + PH - 0.4), (0.0, 28.5 + PH + 0.9)], -4.8, 1, M["stone"])
for k, x in enumerate([-14, -11, -8, -5.2, -2.6, 0, 2.6, 5.2, 8, 11, 14]):
    room = (PH - 2.0) * (1 - abs(x) / (PW - 2.6)) + 0.6
    # each figure is a lumpy body plus a smaller head, leaning a little
    lean = math.radians(random.uniform(-25, 25)) * (abs(x) / 14)
    body_h = room * random.uniform(0.55, 0.75)
    for part, (sz, zoff) in enumerate([((random.uniform(0.9, 1.4), 0.7, body_h / 2), body_h / 2),
                                        ((0.45, 0.45, 0.5), body_h + 0.35)]):
        if part == 1 and room < 2.2:
            continue
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, location=(x + math.sin(lean) * zoff, -4.5,
                                                                        29.0 + math.cos(lean) * zoff))
        o = bpy.context.active_object
        o.name = f"Statue{k}_{part}"
        o.scale = sz
        o.rotation_euler = (0, lean, 0)
        bpy.ops.object.shade_smooth()
        o.data.materials.append(M["stone_dark"])

# HUSTYLE banners on angled poles over the balustrade
for i, x in enumerate([-12, 0, 12]):
    pole_base = Vector((x, -3.4, 10.2))
    ang = math.radians(35)
    length = 6.5
    tip = pole_base + Vector((0, -math.sin(ang) * length, math.cos(ang) * length))
    mid = (pole_base + tip) / 2
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.09, depth=length, location=mid,
                                        rotation=(-ang, 0, 0))
    bpy.context.active_object.data.materials.append(M["metal"])
    # banner hangs straight down from the pole tip, facing the street
    bw, bh = 2.6, 4.2
    bpy.ops.mesh.primitive_plane_add(size=1, location=(x + bw / 2 + 0.1, tip.y, tip.z - bh / 2),
                                     rotation=(math.radians(90), 0, 0))
    f = bpy.context.active_object
    f.name = f"Banner{i}"
    f.scale = (bw, bh, 1)
    bpy.ops.object.transform_apply(scale=True)
    s = f.modifiers.new("Solid", "SOLIDIFY")
    s.thickness = 0.08
    f.data.materials.append(M["banner"])

# ---------- towers behind ----------
def tower(name, x0, x1, y0, y1, h):
    box(name, x0, x1, y0, y1, 0, h, M["tower"], bevel=0.1)
    # window grid on the front face via arrays
    cols = int((x1 - x0 - 2) // 2.2)
    rows = int((h - 4) // 3.4)
    w = box(name + "Win", x0 + 1.2, x0 + 2.4, y0 - 0.12, y0 + 0.05, 3, 5, M["tower_win"])
    a = w.modifiers.new("Cols", "ARRAY")
    a.count = cols
    a.relative_offset_displace = (1.85, 0, 0)
    b = w.modifiers.new("Rows", "ARRAY")
    b.count = rows
    b.relative_offset_displace = (0, 0, 1.7)
    # a few lit windows so the city feels awake at night
    for _ in range(int(cols * rows * 0.07)):
        c = random.randint(0, cols - 1)
        r = random.randint(0, rows - 1)
        wx = x0 + 1.2 + c * 1.2 * 1.85
        wz = 3 + r * 2 * 1.7
        box(name + "Lit", wx, wx + 1.2, y0 - 0.16, y0 - 0.1, wz, wz + 2, M["glass_lit"])
    # setback crown
    box(name + "Crown", x0 + 2, x1 - 2, y0 + 2, y1 - 2, h, h + 6, M["tower"], bevel=0.1)


tower("TowerL", -62, -27, 4, 36, 92)
tower("TowerL2", -95, -64, 18, 50, 120)
tower("TowerR", 27, 60, 6, 38, 105)
tower("TowerR2", 64, 98, 22, 55, 80)
tower("TowerBack", -18, 20, 44, 70, 140)

# ---------- street props ----------
for k in range(-11, 12):
    x = k * 2.6
    cyl(f"Bollard{k}", x, -12.2, 0.25, 1.15, 0.22, M["metal"], verts=12)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=0.22, location=(x, -12.2, 1.15))
    bpy.ops.object.shade_smooth()
    bpy.context.active_object.data.materials.append(M["metal"])

# a blobby street tree on the left, Apple Maps style
cyl("Trunk", -19, -8.5, 0.25, 6.5, 0.28, M["metal"], verts=10)
for k in range(9):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=random.uniform(1.6, 2.4),
                                          location=(-19 + random.uniform(-2.2, 2.2), -8.5 + random.uniform(-1.5, 1.5),
                                                    7.5 + random.uniform(-1.2, 2.2)))
    bpy.ops.object.shade_smooth()
    bpy.context.active_object.data.materials.append(M["leaf"])

# ---------- light and world ----------
world = bpy.data.worlds.new("Night")
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bg.inputs["Color"].default_value = lin("#33466A")
bg.inputs["Strength"].default_value = 0.9

bpy.ops.object.light_add(type="SUN", rotation=(math.radians(52), math.radians(-28), math.radians(-30)))
sun = bpy.context.active_object
sun.data.color = lin("#F6DCBE")[:3]
sun.data.energy = 2.2
sun.data.angle = math.radians(6)

bpy.ops.object.light_add(type="AREA", location=(0, -30, 4), rotation=(math.radians(80), 0, 0))
fill = bpy.context.active_object
fill.data.color = lin("#8FA8D8")[:3]
fill.data.energy = 9000
fill.data.size = 40

# ---------- camera: low, looking up ----------
bpy.ops.object.camera_add(location=(-3.0, -40.0, 1.6), rotation=(math.radians(90 + 21), 0, math.radians(-4)))
cam = bpy.context.active_object
cam.data.lens = 17
scene.camera = cam

# ---------- render ----------
scene.render.engine = "CYCLES"
prefs = bpy.context.preferences.addons["cycles"].preferences
try:
    prefs.compute_device_type = "METAL"
    prefs.get_devices()
    for d in prefs.devices:
        d.use = True
    scene.cycles.device = "GPU"
except Exception:
    scene.cycles.device = "CPU"
scene.cycles.samples = 32 if PREVIEW else 160
scene.cycles.use_denoising = True
scene.render.resolution_x = 1920
scene.render.resolution_y = 1080
scene.render.resolution_percentage = 50 if PREVIEW else 100
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Medium High Contrast"
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = OUT

bpy.ops.wm.save_as_mainfile(filepath=BLEND)
bpy.ops.render.render(write_still=True)
print("RENDERED", OUT)
