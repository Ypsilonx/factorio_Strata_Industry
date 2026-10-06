"""Grafika radnice Research Towns: procedurální model a render spritů pro Factorio.

Spuštění (headless, z kořene repozitáře):
    "C:/STEAM/steamapps/common/Blender/blender.exe" -b --factory-startup --python blender/build_hall.py -- --calibrate

Přepínače:
    --calibrate   zkušební deska 3×3 se sloupky přes vanilla laboratoř → blender/renders/calibration.png
    --variant N   vzhled radnice N (1–5): vrstvy a náhled blender/renders/preview-N.png
    --draft       rychlý náhled (méně vzorků)
    --install     vrstvy a ikonu zapsat do modu (research-towns/graphics, prototypes/hall_sprites.lua);
                  vzhledy bez vlastního renderu dočasně dostanou kopii

Moduly: rt_render.py (scéna, kamera, světla, pixely), camera.toml (laditelná projekce a světla).
"""

import shutil
import sys
from pathlib import Path

import bpy
import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
RENDERS = HERE / "renders"
FACTORIO_DATA = Path("C:/STEAM/steamapps/common/Factorio/data")

# Blender drží importované moduly v paměti – při opakovaném spuštění (MCP) načíst aktuální verze.
for _name in list(sys.modules):
    _file = getattr(sys.modules[_name], "__file__", None)
    if _file and Path(_file).resolve().parent == HERE:
        del sys.modules[_name]
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import rt_hall  # noqa: E402
import rt_materials  # noqa: E402
import rt_render as R  # noqa: E402


def material(name, color):
    """Jednoduchý matný materiál (kalibrace)."""
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.8
    return mat


def box(collection, parent, name, center, size, mat):
    """Kvádr se středem podstavy v center (dlaždice), velikost size (x, y, z)."""
    cx, cy, cz = center
    sx, sy, sz = size
    verts = [(cx + dx * sx / 2, cy + dy * sy / 2, cz + z) for z in (0, sz) for dx, dy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    obj.parent = parent
    collection.objects.link(obj)
    return obj


def vanilla_lab_frame():
    """První snímek vanilla laboratoře (HR list 194×174, 11 snímků v řádku)."""
    pixels = R.load_pixels(FACTORIO_DATA / "base/graphics/entity/lab/lab.png")
    return pixels[:174, :194]


def calibrate():
    """Deska 3×3 (šachovnice dlaždic) se sloupky výšky 1 přes vanilla laboratoř: kontrola měřítka, obrysu a jasu."""
    tiles = 3
    width, height, center_up = R.frame(tiles, top=1)
    scene, collection = R.fresh_scene()
    parent = R.root(collection)
    R.setup_render(scene, width, height)
    R.setup_camera(scene, collection, width, height, center_up)
    R.setup_lights(collection)
    R.add_ground(collection, tiles, tiles)
    light, dark = material("RT_CalibLight", (0.55, 0.55, 0.55)), material("RT_CalibDark", (0.25, 0.25, 0.25))
    for ix in range(tiles):
        for iy in range(tiles):
            x, y = ix - 1, iy - 1
            box(collection, parent, f"RT_Tile_{ix}_{iy}", (x, y, 0), (1, 1, 0.02), light if (ix + iy) % 2 == 0 else dark)
    for x in (-1.45, 1.45):
        for y in (-1.45, 1.45):
            box(collection, parent, f"RT_Post_{x}_{y}", (x, y, 0), (0.1, 0.1, 1.0), dark)
    RENDERS.mkdir(exist_ok=True)
    ours = R.downsample(R.render(scene, RENDERS / "calib-raw.png"))
    lab = vanilla_lab_frame()
    h, w = ours.shape[:2]
    # Střed entity: uprostřed šířky, 1,5 dlaždice nad spodkem; laboratoř má shift (0, 1,5 px) → 3 px v HR.
    cx, cy = w // 2, h - int(1.5 * R.PX)
    lx, ly = cx - lab.shape[1] // 2, cy + 3 - lab.shape[0] // 2
    pad = 40
    canvas = np.zeros((h + 2 * pad, 3 * (w + 2 * pad), 4), dtype=np.float32)
    canvas[...] = (0.35, 0.42, 0.3, 1.0)
    canvas = R.over(canvas, ours, pad, pad)
    canvas = R.over(canvas, np.pad(lab, ((0, 0), (0, 0), (0, 0))), (w + 2 * pad) + pad + lx, pad + ly)
    half = lab.copy()
    half[..., 3] *= 0.5
    third = 2 * (w + 2 * pad) + pad
    canvas = R.over(canvas, ours, third, pad)
    canvas = R.over(canvas, half, third + lx, pad + ly)
    R.save_pixels(canvas, RENDERS / "calibration.png")
    print(f"KALIBRACE: render {w}×{h} px, laboratoř {lab.shape[1]}×{lab.shape[0]} px na ({lx}, {ly}), "
          f"jas naše deska {R.luminance(ours):.3f}, laboratoř {R.luminance(lab):.3f}")


#: Záběr radnice: půdorys 15×15, nad ním 4 dlaždice na věže a kopule, okraj 1 dlaždice na stín.
HALL_TILES, HALL_TOP, HALL_MARGIN = 15, 4, 1


def render_hall(variant):
    """Vyrenderuje vrstvy radnice daného vzhledu. Vrátí (base, light, shadow, center_up) – pixely v cílovém
    rozlišení (64 px/dlaždici)."""
    width, height, center_up = R.frame(HALL_TILES, top=HALL_TOP, bottom=HALL_MARGIN, side=HALL_MARGIN)
    scene, collection = R.fresh_scene()
    parent = R.root(collection)
    R.setup_render(scene, width, height)
    R.setup_camera(scene, collection, width, height, center_up)
    lights = R.setup_lights(collection)
    ground = R.add_ground(collection, width, height)
    mats = rt_materials.library()
    parts = rt_hall.build(collection, parent, mats, variant)
    model = [o for o in collection.objects if o.type == "MESH" and o is not ground]
    RENDERS.mkdir(exist_ok=True)
    world_strength = scene.world.node_tree.nodes["Background"].inputs["Strength"]
    default_world = world_strength.default_value

    # Základ: svítidla zhasnutá, bez podložky.
    rt_materials.set_glow(False)
    ground.hide_render = True
    base = R.downsample(R.render(scene, RENDERS / f"hall-{variant}-base-raw.png"))

    # Světla: jen emise (slunce a okolí zhasnuté), alfa z jasu – ve hře additive blend.
    rt_materials.set_glow(True)
    for light in lights:
        light.hide_render = True
    world_strength.default_value = 0.0
    light_px = R.downsample(R.render(scene, RENDERS / f"hall-{variant}-light-raw.png"))
    light_px[..., 3] = np.clip(light_px[..., :3].max(axis=-1) * 1.5, 0.0, 1.0) * light_px[..., 3]
    for light in lights:
        light.hide_render = False
    world_strength.default_value = default_world
    rt_materials.set_glow(False)

    # Stín: model neviditelný pro kameru, podložka zachytí stín; nádvoří stín nevrhá (zakrylo by podložku).
    ground.hide_render = False
    for obj in model:
        obj.visible_camera = False
        if obj.name.startswith("RT_Plaza"):
            obj.visible_shadow = False
    shadow_raw = R.downsample(R.render(scene, RENDERS / f"hall-{variant}-shadow-raw.png"))
    shadow = np.zeros_like(shadow_raw)
    shadow[..., 3] = shadow_raw[..., 3]
    print(f"RADNICE {variant}: {parts} dílů, {base.shape[1]}×{base.shape[0]} px, posun nahoru {center_up} dlaždic, "
          f"jas {R.luminance(base):.3f}")
    return base, light_px, shadow, center_up


def vanilla_frame(path, width, height):
    """První snímek vanilla HR spritu (levý horní roh listu)."""
    return R.load_pixels(FACTORIO_DATA / path)[:height, :width]


def preview(variant, base, light_px, shadow):
    """Náhled na trávě: den (stín + základ) a noc (ztmavený základ + světla) a vedle vanilla budovy
    pro porovnání barev a měřítka → blender/renders/preview-N.png."""
    h, w = base.shape[:2]
    refs = [vanilla_frame("base/graphics/entity/lab/lab.png", 194, 174),
            vanilla_frame("base/graphics/entity/assembling-machine-1/assembling-machine-1.png", 214, 226),
            vanilla_frame("base/graphics/entity/stone-furnace/stone-furnace.png", 151, 146)]
    refs_w = sum(r.shape[1] for r in refs) + 40 * len(refs)
    print("JAS vanilla (laboratoř, montážní stroj, pec): "
          + ", ".join(f"{R.luminance(r):.3f}" for r in refs) + f" | radnice {R.luminance(base):.3f}")
    canvas = np.zeros((2 * h, w + refs_w, 4), dtype=np.float32)
    canvas[...] = (0.30, 0.31, 0.19, 1.0)
    dark_shadow = shadow.copy()
    dark_shadow[..., 3] *= 0.55
    for row in (0, 1):
        y0 = row * h
        canvas = R.over(canvas, dark_shadow, 0, y0)
        canvas = R.over(canvas, base, 0, y0)
        x = w + 20
        for ref in refs:
            canvas = R.over(canvas, ref, x, y0 + h - ref.shape[0] - 80)
            x += ref.shape[1] + 40
    # Noc: spodní polovina ztmavená, světla přičtená.
    night = canvas[h:]
    night[..., :3] *= 0.22
    lit = light_px[..., :3] * light_px[..., 3:4]
    night[:, :w, :3] = np.clip(night[:, :w, :3] + lit, 0.0, 1.0)
    R.save_pixels(canvas, RENDERS / f"preview-{variant}.png")


MOD = ROOT / "research-towns"
ENTITY_DIR = MOD / "graphics" / "entity" / "hall"
ICON_DIR = MOD / "graphics" / "icons"
#: Počet vzhledů radnice (levels.VARIANTS v shared/levels.lua).
VARIANTS = 5


def icon(base, size=64):
    """Ikona: výřez neprůhledné části spritu, doplněný na čtverec a zmenšený průměrem bloků na size×size."""
    ys, xs = np.nonzero(base[..., 3] > 0.05)
    crop = base[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    side = max(crop.shape[:2])
    factor = -(-side // size)
    canvas = np.zeros((size * factor, size * factor, 4), dtype=np.float32)
    y0, x0 = (canvas.shape[0] - crop.shape[0]) // 2, (canvas.shape[1] - crop.shape[1]) // 2
    canvas[y0:y0 + crop.shape[0], x0:x0 + crop.shape[1]] = crop
    return R.downsample(canvas, factor)


def write_sprites_lua(width, height, center_up):
    """Zapíše rozměry a posun spritů radnice pro data stage (prototypes/hall_sprites.lua; generováno)."""
    text = (
        "--- Rozměry a posun spritů radnice – GENEROVÁNO blender/build_hall.py (--install), neupravovat ručně.\n"
        "--- Sprity jsou v HR (64 px na dlaždici, ve hře scale 0.5); shift posouvá střed obrázku nad střed entity.\n"
        f"return {{ width = {width}, height = {height}, shift = {{ 0, {-center_up} }}, scale = 0.5 }}\n"
    )
    (MOD / "prototypes" / "hall_sprites.lua").write_text(text, encoding="utf-8")


def install(variant, base, light_px, shadow, center_up):
    """Zapíše vrstvy a ikonu vzhledu do modu a rozměry do hall_sprites.lua."""
    ENTITY_DIR.mkdir(parents=True, exist_ok=True)
    ICON_DIR.mkdir(parents=True, exist_ok=True)
    for name, pixels in (("base", base), ("light", light_px), ("shadow", shadow)):
        R.save_pixels(pixels, ENTITY_DIR / f"hall-{variant}-{name}.png")
    R.save_pixels(icon(base), ICON_DIR / f"hall-{variant}.png")
    write_sprites_lua(base.shape[1], base.shape[0], center_up)


def fill_missing(source):
    """Dočasně: vzhledy, které ještě nemají vlastní render, dostanou kopii vzhledu source."""
    for variant in range(1, VARIANTS + 1):
        if variant == source or (ENTITY_DIR / f"hall-{variant}-base.png").exists():
            continue
        for name in ("base", "light", "shadow"):
            shutil.copyfile(ENTITY_DIR / f"hall-{source}-{name}.png", ENTITY_DIR / f"hall-{variant}-{name}.png")
        shutil.copyfile(ICON_DIR / f"hall-{source}.png", ICON_DIR / f"hall-{variant}.png")
        print(f"RADNICE {variant}: dočasně kopie vzhledu {source}")


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--calibrate" in args:
        calibrate()
    if "--draft" in args:
        # Rychlý náhled při ladění modelu: méně vzorků (šum odstraní denoiser).
        R.CONFIG["render"]["samples"] = 16
    if "--variant" in args:
        number = int(args[args.index("--variant") + 1])
        layers = render_hall(number)
        preview(number, *layers[:3])
        if "--install" in args:
            install(number, *layers)
            fill_missing(number)
