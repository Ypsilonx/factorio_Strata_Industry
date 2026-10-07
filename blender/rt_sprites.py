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
    "wooden-chest": [("wooden-chest/wooden-chest.png", 62, 72, 0.5, -2)],
    "storage-tank": [("storage-tank/storage-tank.png", 219, 235, -0.25, -1.25)],
    "radar": [("radar/radar.png", 196, 254, 1, -16)],
    "roboport": [("roboport/roboport-base.png", 228, 277, 2, -2.25),
                 ("roboport/roboport-door-up.png", 97, 38, -0.25, -39.5),
                 ("roboport/roboport-door-down.png", 97, 41, -0.25, -19.75)],
    "solar-panel": [("solar-panel/solar-panel.png", 230, 224, -3, 3.5)],
    "accumulator": [("accumulator/accumulator.png", 130, 189, 0, -11)],
    "chemical-plant": [("chemical-plant/chemical-plant.png", 220, 292, 0.5, -9)],
    "small-lamp": [("small-lamp/lamp.png", 83, 70, 0.25, 3)],
}
#: Stíny strojů (draw_as_shadow ve hře): jméno → (soubor, šířka, výška, posun x, y) – z base/prototypes/entity.
SHADOWS = {
    "small-pole": ("small-electric-pole/small-electric-pole-shadow.png", 256, 52, 51, 3),
    "boiler": ("boiler/boiler-N-shadow.png", 274, 164, 20.5, 9),
    "steam-engine": ("steam-engine/steam-engine-H-shadow.png", 508, 160, 48, 24),
    "assembler-1": ("assembling-machine-1/assembling-machine-1-shadow.png", 190, 165, 8.5, 5),
    "iron-chest": ("iron-chest/iron-chest-shadow.png", 110, 50, 10.5, 6),
    "wooden-chest": ("wooden-chest/wooden-chest-shadow.png", 104, 40, 10, 6.5),
    "storage-tank": ("storage-tank/storage-tank-shadow.png", 291, 153, 29.75, 22.25),
    "radar": ("radar/radar-shadow.png", 336, 170, 39, 6),
    "roboport": ("roboport/roboport-shadow.png", 294, 201, 28.5, 9.25),
    "solar-panel": ("solar-panel/solar-panel-shadow.png", 220, 180, 9.5, 6),
    "accumulator": ("accumulator/accumulator-shadow.png", 234, 106, 29, 6),
    "chemical-plant": ("chemical-plant/chemical-plant-shadow.png", 312, 222, 27, 6),
    "small-lamp": ("small-lamp/lamp-shadow.png", 76, 47, 4, 4.75),
}
#: Světla strojů (rozsvícená lampa – jen ve světelné vrstvě): jméno → (soubor, šířka, výška, posun x, y).
GLOWS = {
    "small-lamp": ("small-lamp/lamp-light.png", 90, 78, 0, -7),
}
#: Síla stínu ze hry v renderu (krytí černé), aby ladil se stíny modelu.
SHADOW_ALPHA = 0.6
#: Výška spodní hrany svislé plochy spritu nad zemí – nad nádvořím, aby ho nezakrylo (viz card).
CARD_LIFT = 0.12

#: Výška horního úchytu drátu nad zemí (dlaždice ve světě) pro sloupy – podle vrcholu spritu.
POLE_TOP = {"small-pole": 4.1, "medium-pole": 4.6}

#: Stromy: (typ, písmeno, kmen (š, v, posun), listí (š, v, posun), stín (š, v, posun)). Listnaté tree-02 převažují.
TREES = [
    ("02", "a", (162, 324, 1, -65), (184, 310, 0, -74), (384, 130, 92, -2)),
    ("02", "b", (150, 286, -3, -59), (184, 274, -2, -62), (372, 134, 86, 1)),
    ("02", "a", (162, 324, 1, -65), (184, 310, 0, -74), (384, 130, 92, -2)),
    ("01", "a", (140, 340, 2, -69), (184, 306, -1, -74), (324, 134, 61, -2)),
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


def _shadow(key, file, w, h, sx, sy):
    """Stín ze hry složený do cache (stejný formát jako sprite – viz compose)."""
    frame = _load(FACTORIO_DATA / "base/graphics/entity" / file)[:h, :w].copy()
    return compose(key + "-shadow", [(frame, sx * 2, sy * 2)])


def machine(name):
    """Složený sprite stroje z MACHINES, jeho stín a světlo ze hry (nebo None). Vrátí (sprite, stín, světlo)."""
    layers = []
    for file, w, h, sx, sy in MACHINES[name]:
        layers.append((_load(FACTORIO_DATA / "base/graphics/entity" / file)[:h, :w].copy(), sx * 2, sy * 2))
    shadow = _shadow(name, *SHADOWS[name]) if name in SHADOWS else None
    glow = None
    if name in GLOWS:
        file, w, h, sx, sy = GLOWS[name]
        frame = _load(FACTORIO_DATA / "base/graphics/entity" / file)[:h, :w].copy()
        glow = compose(name + "-glow", [(frame, sx * 2, sy * 2)])
    return compose(name, layers), shadow, glow


def tree(index, color_index):
    """Složený strom: kmen + listí obarvené tintem (plná koruna = první snímek) a stín. Vrátí (sprite, stín)."""
    kind, letter, trunk, leaves, shadow = TREES[index]
    layers = []
    for part, (w, h, sx, sy) in (("trunk", trunk), ("leaves", leaves)):
        frame = _load(FACTORIO_DATA / f"base/graphics/entity/tree/{kind}/tree-{kind}-{letter}-{part}.png")[:h, :w]
        frame = frame.copy()
        if part == "leaves":
            frame[..., :3] *= np.array(LEAF_COLORS[color_index], dtype=np.float32) / 255.0 * LEAF_DIM
        layers.append((frame, sx * 2, sy * 2))
    shadow = _shadow(f"tree-{kind}-{letter}", f"tree/{kind}/tree-{kind}-{letter}-shadow.png", *shadow)
    return compose(f"tree-{kind}-{letter}-{color_index}", layers), shadow


def item(name):
    """Ikona předmětu ze hry (64 px, první mipmapa) s patou ve spodní hraně – předmět ležící na zemi nebo na paletě
    se ve hře kreslí právě jako ikona čelem ke kameře. Vrátí (sprite, None) pro card."""
    frame = _load(FACTORIO_DATA / "base/graphics/icons" / f"{name}.png")[:64, :64].copy()
    return compose(f"item-{name}", [(frame, 0, -32)]), None


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


def _plane(collection, name, w, h, mat):
    """Obdélník w × h v rovině XY se středem v počátku a UV přes celý obrázek."""
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([(-w / 2, -h / 2, 0), (w / 2, -h / 2, 0), (w / 2, h / 2, 0), (-w / 2, h / 2, 0)], [],
                     [(0, 1, 2, 3)])
    mesh.uv_layers.new()
    for loop, uv in zip(mesh.uv_layers[0].data, ((0, 0), (1, 0), (1, 1), (0, 1))):
        loop.uv = uv
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    obj.visible_shadow = False
    collection.objects.link(obj)
    return obj


def shadow_material(path):
    """Neosvětlený stín ze hry: černá s krytím alfa × SHADOW_ALPHA (rt_unlit – ve světelné vrstvě nesvítí)."""
    name = "RT_Shadow_" + path.stem
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
    emission = nt.nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = (0.0, 0.0, 0.0, 1.0)
    transparent = nt.nodes.new("ShaderNodeBsdfTransparent")
    strength = nt.nodes.new("ShaderNodeMath")
    strength.operation = "MULTIPLY"
    strength.inputs[1].default_value = SHADOW_ALPHA
    nt.links.new(tex.outputs["Alpha"], strength.inputs[0])
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(strength.outputs["Value"], mix.inputs["Fac"])
    nt.links.new(transparent.outputs["BSDF"], mix.inputs[1])
    nt.links.new(emission.outputs["Emission"], mix.inputs[2])
    nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])
    mat["rt_unlit"] = True
    return mat


def card(collection, x, y, sprites, elevation_deg=45.0, name="RT_Card", z=0.0, scale=1.0):
    """Vloží sprite ze hry (výsledek machine/tree = (sprite, stín[, světlo])) s patou v bodě (x, y) světových
    souřadnic (už s natažením osy Y); z = výška paty nad zemí (střecha), scale = zmenšení (bedny v měřítku města).

    Sprite je svislá plocha natažená na výšku o 1/cos(elevace). Plocha se posune po paprsku ke kameře, až je
    její spodní hrana CARD_LIFT nad zemí – v projekci se nic nezmění, ale nádvoří už nezakryje spodek stroje.
    Plocha nevrhá stín; místo něj se na zem položí stín ze hry (vodorovná plocha). Světlo (rozsvícená lampa)
    je stejná plocha těsně před spritem, viditelná jen ve světelné vrstvě (glow_material)."""
    sprite, shadow, *extra = sprites
    e = math.radians(elevation_deg)
    obj, slide = _card_plane(collection, name, x, y, z, sprite, material(sprite[0]), e, scale, None)
    obj["rt_card"] = True  # maska spritů ze hry pro stín budov (rt_render.render_layers)
    if shadow:
        decal(collection, x, y, shadow, z, elevation_deg, scale)
    if extra and extra[0]:
        light, _ = _card_plane(collection, name + "_Light", x, y, z, extra[0], glow_material(extra[0][0]), e, scale,
                               slide + GLOW_IN_FRONT)
        light["rt_glow_light"] = True  # noční světlo ve hře (build_hall.night_lights)
    return obj


#: O kolik je plocha světla spritu blíž ke kameře než sprite (aby ho překryla).
GLOW_IN_FRONT = 0.02


def _card_plane(collection, name, x, y, z, sprite, mat, e, scale, slide):
    """Svislá plocha spritu s patou v (x, y, z), posunutá po paprsku ke kameře o slide (None = tak, aby spodní
    hrana byla CARD_LIFT nad patou). Vrátí (objekt, použitý posun)."""
    path, width, height, (cx, cy) = sprite
    w, h = width / PX * scale, height / PX / math.cos(e) * scale
    cx, cy = cx * scale, cy * scale
    obj = _plane(collection, name, w, h, mat)
    location = [x + cx, y, z - cy / math.cos(e)]
    if slide is None:
        bottom = location[2] - h / 2
        slide = max(0.0, (z + CARD_LIFT - bottom) / math.sin(e))
    location[1] -= slide * math.cos(e)
    location[2] += slide * math.sin(e)
    obj.location = location
    obj.rotation_euler = (math.pi / 2, 0.0, 0.0)
    return obj, slide


def glow_material(path):
    """Světlo ze hry (rozsvícená lampa): emise barvy obrázku, krytí = alfa × vypínač RT_Switch. V základní vrstvě
    vypnuté (průhledné), ve světelné zapnuté – přepíná rt_materials.set_glow (příznak rt_glow_card)."""
    name = "RT_Glow_" + path.stem
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
    emission = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(tex.outputs["Color"], emission.inputs["Color"])
    switch = nt.nodes.new("ShaderNodeValue")
    switch.name = "RT_Switch"
    switch.outputs[0].default_value = 0.0
    factor = nt.nodes.new("ShaderNodeMath")
    factor.operation = "MULTIPLY"
    nt.links.new(tex.outputs["Alpha"], factor.inputs[0])
    nt.links.new(switch.outputs[0], factor.inputs[1])
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(factor.outputs["Value"], mix.inputs["Fac"])
    nt.links.new(nt.nodes.new("ShaderNodeBsdfTransparent").outputs["BSDF"], mix.inputs[1])
    nt.links.new(emission.outputs["Emission"], mix.inputs[2])
    nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])
    mat["rt_glow_card"] = True
    return mat


#: Výška stínu ze hry nad zemí (nad nádvořím a cestami); posun v ose Y ji v projekci vyrovná.
DECAL_Z = 0.1


def decal(collection, x, y, shadow, z=0.0, elevation_deg=45.0, scale=1.0):
    """Položí stín ze hry na zem s patou entity v (x, y): vodorovná plocha, v projekci 64 px na dlaždici."""
    path, width, height, (cx, cy) = shadow
    e = math.radians(elevation_deg)
    cx, cy = cx * scale, cy * scale
    obj = _plane(collection, "RT_Decal", width / PX * scale, height / PX / math.sin(e) * scale, shadow_material(path))
    obj.location = (x + cx, y - cy / math.sin(e) - DECAL_Z, z + DECAL_Z)
    return obj
