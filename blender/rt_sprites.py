"""Vanilla sprity Factoria v renderu radnice: stromy a stroje z výzkumu (parní stroj, sloupy, nádrže, roboport…).

Vrstvy spritu (první snímek) se složí do jedné textury a vloží jako svislá plocha v místě paty entity,
natažená na výšku o 1/cos(elevace) – v projekci kamery vyjde přesně sprite hry a Blender správně řeší zákryt
s domy i stín podle tvaru. Město tak ukazuje stejné stroje, jaké hráč zkoumá a staví. Textury se skládají
při buildu do blender/renders/sprites (obrázky hry se do repozitáře nekopírují).
"""

import math
from pathlib import Path

import bpy
import numpy as np

FACTORIO_DATA = Path("C:/STEAM/steamapps/common/Factorio/data")
CACHE = Path(__file__).resolve().parent / "renders" / "sprites"
#: Pixely na dlaždici HR spritů (util.by_pixel počítá v 32 px na dlaždici → ×2).
PX = 64

#: Stroje z base/prototypes/entity/*.lua: jméno → [(soubor v base/graphics/entity, šířka, výška, posun x, y)].
#: Posuny v util.by_pixel (32 px na dlaždici); bere se levý horní snímek listu.
MACHINES = {
    "small-pole": [("small-electric-pole/small-electric-pole.png", 72, 220, 1.5, -42.5)],
    "medium-pole": [("medium-electric-pole/medium-electric-pole.png", 84, 252, 3.5, -44)],
    "boiler": [("boiler/boiler-N-idle.png", 269, 221, -1.25, 5.25)],
    "steam-engine": [("steam-engine/steam-engine-H.png", 352, 257, 1, -4.75)],
    "assembler-1": [("assembling-machine-1/assembling-machine-1.png", 214, 226, 0, 2)],
    "assembler-2": [("assembling-machine-2/assembling-machine-2.png", 214, 218, 0, 4)],
    "iron-chest": [("iron-chest/iron-chest.png", 66, 76, -0.5, -0.5)],
    "storage-tank": [("storage-tank/storage-tank.png", 219, 235, -0.25, -1.25)],
    "radar": [("radar/radar.png", 196, 254, 1, -16)],
    "roboport": [("roboport/roboport-base.png", 228, 277, 2, -2.25),
                 ("roboport/roboport-door-up.png", 97, 38, -0.25, -39.5),
                 ("roboport/roboport-door-down.png", 97, 41, -0.25, -19.75)],
    "solar-panel": [("solar-panel/solar-panel.png", 230, 224, -3, 3.5)],
    "accumulator": [("accumulator/accumulator.png", 130, 189, 0, -11)],
    "chemical-plant": [("chemical-plant/chemical-plant.png", 220, 292, 0.5, -9)],
}
#: Výška horního úchytu drátu nad zemí (dlaždice ve světě) pro sloupy – podle vrcholu spritu.
POLE_TOP = {"small-pole": 4.1, "medium-pole": 4.6}

#: Stromy: (typ, písmeno, kmen (š, v, posun), listí (š, v, posun)). Listnaté tree-02 převažují.
TREES = [
    ("02", "a", (162, 324, 1, -65), (184, 310, 0, -74)),
    ("02", "b", (150, 286, -3, -59), (184, 274, -2, -62)),
    ("02", "a", (162, 324, 1, -65), (184, 310, 0, -74)),
    ("01", "a", (140, 340, 2, -69), (184, 306, -1, -74)),
]
#: Odstíny listí (tint jako ve hře) z barev tree-02 a tree-01, ztlumené LEAF_DIM kvůli souladu s městem.
LEAF_COLORS = [(190, 215, 132), (150, 201, 111), (194, 208, 87), (118, 243, 152)]
LEAF_DIM = 0.75


def _load(path):
    """Načte PNG jako numpy pole (výška, šířka, 4) s řádky shora dolů."""
    img = bpy.data.images.load(str(path), check_existing=False)
    w, h = img.size
    pixels = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1]
    bpy.data.images.remove(img)
    return pixels


def _save(pixels, path):
    """Uloží numpy pole jako PNG."""
    h, w = pixels.shape[:2]
    img = bpy.data.images.new("RT_sprite_tmp", width=w, height=h, alpha=True)
    img.pixels[:] = np.clip(pixels, 0.0, 1.0)[::-1].reshape(-1)
    img.filepath_raw = str(path)
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def compose(key, layers):
    """Složí vrstvy [(pixely snímku, posun x, y v HR px)] do PNG v cache. Vrátí (cesta, šířka, výška,
    posun středu obrázku od paty entity v dlaždicích (x, y; y kladné dolů))."""
    path = CACHE / f"{key}.png"
    left = min(cx - f.shape[1] / 2 for f, cx, _ in layers)
    top = min(cy - f.shape[0] / 2 for f, _, cy in layers)
    right = max(cx + f.shape[1] / 2 for f, cx, _ in layers)
    bottom = max(cy + f.shape[0] / 2 for f, _, cy in layers)
    width, height = int(math.ceil(right - left)), int(math.ceil(bottom - top))
    if not path.exists():
        canvas = np.zeros((height, width, 4), dtype=np.float32)
        for frame, cx, cy in layers:
            x0, y0 = int(round(cx - frame.shape[1] / 2 - left)), int(round(cy - frame.shape[0] / 2 - top))
            region = canvas[y0:y0 + frame.shape[0], x0:x0 + frame.shape[1]]
            f = frame[: region.shape[0], : region.shape[1]]
            a = f[..., 3:4]
            region[..., :3] = f[..., :3] * a + region[..., :3] * (1 - a)
            region[..., 3:4] = a + region[..., 3:4] * (1 - a)
        CACHE.mkdir(parents=True, exist_ok=True)
        _save(canvas, path)
    return path, width, height, ((left + right) / 2 / PX, (top + bottom) / 2 / PX)


def machine(name):
    """Složený sprite stroje z MACHINES."""
    layers = []
    for file, w, h, sx, sy in MACHINES[name]:
        layers.append((_load(FACTORIO_DATA / "base/graphics/entity" / file)[:h, :w].copy(), sx * 2, sy * 2))
    return compose(name, layers)


def tree(index, color_index):
    """Složený strom: kmen + listí obarvené tintem (plná koruna = první snímek)."""
    kind, letter, trunk, leaves = TREES[index]
    layers = []
    for part, (w, h, sx, sy) in (("trunk", trunk), ("leaves", leaves)):
        frame = _load(FACTORIO_DATA / f"base/graphics/entity/tree/{kind}/tree-{kind}-{letter}-{part}.png")[:h, :w]
        frame = frame.copy()
        if part == "leaves":
            frame[..., :3] *= np.array(LEAF_COLORS[color_index], dtype=np.float32) / 255.0 * LEAF_DIM
        layers.append((frame, sx * 2, sy * 2))
    return compose(f"tree-{kind}-{letter}-{color_index}", layers)


def material(path):
    """Neosvětlený materiál spritu: barvy přímo ze spritu (už osvětleného hrou), průhlednost z alfy.
    Ve světelné vrstvě se emise vypne (rt_unlit) – sprity samy nesvítí."""
    name = "RT_Sprite_" + path.stem
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(str(path), check_existing=True)
    tex.interpolation = "Closest"
    emission = nt.nodes.new("ShaderNodeEmission")
    emission.inputs["Strength"].default_value = 1.0
    transparent = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(tex.outputs["Color"], emission.inputs["Color"])
    nt.links.new(tex.outputs["Alpha"], mix.inputs["Fac"])
    nt.links.new(transparent.outputs["BSDF"], mix.inputs[1])
    nt.links.new(emission.outputs["Emission"], mix.inputs[2])
    nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])
    mat["rt_unlit"] = True
    return mat


def card(collection, x, y, sprite, elevation_deg=45.0, name="RT_Card", z=0.0):
    """Vloží složený sprite (výsledek machine/tree) s patou v bodě (x, y) světových souřadnic (už s natažením
    osy Y) jako svislou plochu natáhnutou na výšku o 1/cos(elevace); z = výška paty nad zemí (střecha)."""
    path, width, height, (cx, cy) = sprite
    e = math.radians(elevation_deg)
    w, h = width / PX, height / PX / math.cos(e)
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([(-w / 2, -h / 2, 0), (w / 2, -h / 2, 0), (w / 2, h / 2, 0), (-w / 2, h / 2, 0)], [],
                     [(0, 1, 2, 3)])
    mesh.uv_layers.new()
    for loop, uv in zip(mesh.uv_layers[0].data, ((0, 0), (1, 0), (1, 1), (0, 1))):
        loop.uv = uv
    mesh.materials.append(material(path))
    obj = bpy.data.objects.new(name, mesh)
    obj.location = (x + cx, y, z - cy / math.cos(e))
    obj.rotation_euler = (math.pi / 2, 0.0, 0.0)
    collection.objects.link(obj)
    return obj
