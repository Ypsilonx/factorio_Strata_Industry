"""Grafika radnice Research Towns: procedurální model a render spritů pro Factorio.

Spuštění (headless, z kořene repozitáře):
    "C:/STEAM/steamapps/common/Blender/blender.exe" -b --factory-startup --python blender/build_hall.py -- --calibrate

Přepínače:
    --calibrate   zkušební deska 3×3 se sloupky přes vanilla laboratoř → blender/renders/calibration.png
    --variant N   vzhled radnice N (1–5): vrstvy a náhled blender/renders/preview-N.png
    --house N     vzhled domu N (1–5, = úroveň domu): vrstvy a náhled blender/renders/preview-house-N.png
    --draft       rychlý náhled (méně vzorků)
    --overview    všech 5 vzhledů z modu vedle sebe → blender/renders/preview-all.png
    --skywalk     textury visutých lávek (dřevěná, prosklená) → research-towns/graphics/entity/skywalk
    --thumbnail   náhled modu pro portál 144×144 (osada a město vědy úhlopříčně) → research-towns/thumbnail.png
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
import rt_house  # noqa: E402
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
    mats = rt_materials.library()
    base, light_px, shadow, center_up, parts = R.render_layers(
        f"hall-{variant}", lambda collection, parent: rt_hall.build(collection, parent, mats, variant),
        HALL_TILES, HALL_TOP, HALL_MARGIN, rt_materials.set_glow)
    print(f"RADNICE {variant}: {parts} dílů, {base.shape[1]}×{base.shape[0]} px, posun nahoru {center_up} dlaždic, "
          f"jas {R.luminance(base):.3f}")
    return base, light_px, shadow, center_up


#: Záběr domu: půdorys 3×3, nad ním 3,2 dlaždice na čtyřpatrový činžák, okraj 1 dlaždice na stín.
HOUSE_TILES, HOUSE_TOP, HOUSE_MARGIN = 3, 3.2, 1


def render_house(variant):
    """Vyrenderuje vrstvy domu daného vzhledu (= úrovně domu). Vrátí (base, light, shadow, center_up)."""
    mats = rt_materials.library()
    base, light_px, shadow, center_up, parts = R.render_layers(
        f"house-{variant}", lambda collection, parent: rt_house.build(collection, parent, mats, variant),
        HOUSE_TILES, HOUSE_TOP, HOUSE_MARGIN, rt_materials.set_glow)
    print(f"DŮM {variant}: {parts} dílů, {base.shape[1]}×{base.shape[0]} px, posun nahoru {center_up} dlaždic, "
          f"jas {R.luminance(base):.3f}")
    return base, light_px, shadow, center_up


def skywalk_model(b, kind):
    """Úsek visuté lávky dlouhý 1 dlaždici (osa x), široký 0,5: dřevěná (prkna, zábradlí) nebo prosklená
    (betonová podlaha, skleněné stěny a střecha s ocelovými žebry)."""
    if kind == "wood":
        b.box("RT_Deck", (0, 0, 0.0), (1.0, 0.5, 0.06), "planks", bevel=0.005)
        for x in (-0.25, 0.25):
            b.box("RT_Joist", (x, 0, -0.04), (0.06, 0.52, 0.05), "wood_beam", bevel=0.005)
        for y in (-0.24, 0.24):
            b.beam("RT_Rail", (-0.5, y, 0.32), (0.5, y, 0.32), 0.035, "wood_beam")
            for x in (-0.5, 0.0, 0.5):
                b.box("RT_Post", (x, y, 0.06), (0.04, 0.04, 0.27), "wood_beam", bevel=0.005)
    else:
        b.box("RT_Deck", (0, 0, 0.0), (1.0, 0.5, 0.06), "concrete", bevel=0.005)
        for y in (-0.23, 0.23):
            b.box("RT_GlassWall", (0, y, 0.06), (1.0, 0.03, 0.32), "glass", bevel=0)
        b.box("RT_GlassRoof", (0, 0, 0.38), (1.0, 0.5, 0.03), "glass", bevel=0)
        for x in (-0.5, 0.0, 0.5):
            b.beam("RT_Rib", (x, -0.26, 0.4), (x, 0.26, 0.4), 0.04, "iron")
        b.beam("RT_Spine", (-0.5, 0, 0.42), (0.5, 0, 0.42), 0.03, "iron")


def render_skywalk(kind):
    """Textura úseku lávky kolmo shora (64×64 px = 1 dlaždice) → graphics/entity/skywalk/skywalk-<kind>.png.
    Hra ji opakuje podél spojení a natáčí (rendering.draw_sprite), proto pohled shora bez perspektivy."""
    scene, collection = R.fresh_scene()
    R.setup_render(scene, 1, 1)
    data = bpy.data.cameras.new("RT_Camera")
    data.type = "ORTHO"
    data.ortho_scale = 1.0
    camera = bpy.data.objects.new("RT_Camera", data)
    camera.location = (0, 0, 10)
    collection.objects.link(camera)
    scene.camera = camera
    R.setup_lights(collection)
    parent = bpy.data.objects.new("RT_Root", None)
    collection.objects.link(parent)
    mats = rt_materials.library()
    rt_materials.set_glow(False)
    skywalk_model(rt_hall.Builder(collection, parent, mats), kind)
    pixels = R.downsample(R.render(scene, RENDERS / f"skywalk-{kind}-raw.png"))
    out = entity_dir("skywalk")
    out.mkdir(parents=True, exist_ok=True)
    R.save_pixels(pixels, out / f"skywalk-{kind}.png")
    print(f"LÁVKA {kind}: {pixels.shape[1]}×{pixels.shape[0]} px")


def vanilla_frame(path, width, height):
    """První snímek vanilla HR spritu (levý horní roh listu)."""
    return R.load_pixels(FACTORIO_DATA / path)[:height, :width]


def preview(label, base, light_px, shadow):
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
    R.save_pixels(canvas, RENDERS / f"preview-{label}.png")


MOD = ROOT / "research-towns"
ICON_DIR = MOD / "graphics" / "icons"
#: Názvy staveb (podle nich složka spritů graphics/entity/<druh> a modul prototypes/<druh>_sprites.lua).
KIND_NAMES = {"hall": "radnice", "house": "domu"}


def entity_dir(kind):
    """Složka spritů stavby v modu."""
    return MOD / "graphics" / "entity" / kind
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


def write_sprites_lua(kind, width, height, center_up):
    """Zapíše rozměry a posun spritů stavby pro data stage (prototypes/<druh>_sprites.lua; generováno)."""
    text = (
        f"--- Rozměry a posun spritů {KIND_NAMES[kind]} – GENEROVÁNO blender/build_hall.py (--install), neupravovat ručně.\n"
        "--- Sprity jsou v HR (64 px na dlaždici, ve hře scale 0.5); shift posouvá střed obrázku nad střed entity.\n"
        f"return {{ width = {width}, height = {height}, shift = {{ 0, {-center_up} }}, scale = 0.5 }}\n"
    )
    (MOD / "prototypes" / f"{kind}_sprites.lua").write_text(text, encoding="utf-8")


def install(kind, variant, base, light_px, shadow, center_up):
    """Zapíše vrstvy a ikonu vzhledu stavby do modu a rozměry do <druh>_sprites.lua."""
    entity_dir(kind).mkdir(parents=True, exist_ok=True)
    ICON_DIR.mkdir(parents=True, exist_ok=True)
    for name, pixels in (("base", base), ("light", light_px), ("shadow", shadow)):
        R.save_pixels(pixels, entity_dir(kind) / f"{kind}-{variant}-{name}.png")
    R.save_pixels(icon(base), ICON_DIR / f"{kind}-{variant}.png")
    write_sprites_lua(kind, base.shape[1], base.shape[0], center_up)


def fill_missing(kind, source):
    """Dočasně: vzhledy, které ještě nemají vlastní render, dostanou kopii vzhledu source."""
    for variant in range(1, VARIANTS + 1):
        if variant == source or (entity_dir(kind) / f"{kind}-{variant}-base.png").exists():
            continue
        for name in ("base", "light", "shadow"):
            shutil.copyfile(entity_dir(kind) / f"{kind}-{source}-{name}.png", entity_dir(kind) / f"{kind}-{variant}-{name}.png")
        shutil.copyfile(ICON_DIR / f"{kind}-{source}.png", ICON_DIR / f"{kind}-{variant}.png")
        print(f"{kind} {variant}: dočasně kopie vzhledu {source}")


def thumbnail(size=144):
    """Thumbnail pro portál (size×size): radnice na trávě rozdělená úhlopříčkou – vlevo nahoře osada (vzhled 1),
    vpravo dole město vědy (vzhled 5) – příběh modu v jednom obrázku → research-towns/thumbnail.png."""
    layers = []
    for variant in (1, VARIANTS):
        base = R.load_pixels(entity_dir("hall") / f"hall-{variant}-base.png")
        shadow = R.load_pixels(entity_dir("hall") / f"hall-{variant}-shadow.png")
        shadow[..., 3] *= 0.55
        tile = np.zeros_like(base)
        tile[...] = (0.30, 0.31, 0.19, 1.0)
        layers.append(R.over(R.over(tile, shadow), base))
    # Výřez kolem badatelny a náměstí (střed entity je 7,5 dlaždice nad spodním okrajem + okraj 1 dlaždice).
    h, w = layers[0].shape[:2]
    side, cx, cy = 768, w // 2, h - 64 - 480 - 160
    crop = [layer[cy - side // 2:cy + side // 2, cx - side // 2:cx + side // 2] for layer in layers]
    ys, xs = np.mgrid[0:side, 0:side]
    mixed = np.where(((xs + ys) < side)[..., None], crop[0], crop[1])
    factor = -(-side // size)
    canvas = np.zeros((size * factor, size * factor, 4), dtype=np.float32)
    canvas[...] = (0.30, 0.31, 0.19, 1.0)
    offset = (size * factor - side) // 2
    canvas[offset:offset + side, offset:offset + side] = mixed
    R.save_pixels(R.downsample(canvas, factor), MOD / "thumbnail.png")
    print(f"THUMBNAIL: {size}×{size}")


def overview():
    """Všech 5 vzhledů z modu vedle sebe na trávě (zmenšeno na polovinu) → blender/renders/preview-all.png."""
    tiles = []
    for variant in range(1, VARIANTS + 1):
        base = R.load_pixels(entity_dir("hall") / f"hall-{variant}-base.png")
        shadow = R.load_pixels(entity_dir("hall") / f"hall-{variant}-shadow.png")
        shadow[..., 3] *= 0.55
        tile = np.zeros_like(base)
        tile[...] = (0.30, 0.31, 0.19, 1.0)
        tiles.append(R.downsample(R.over(R.over(tile, shadow), base), 2))
    R.save_pixels(np.concatenate(tiles, axis=1), RENDERS / "preview-all.png")


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--calibrate" in args:
        calibrate()
    if "--thumbnail" in args:
        thumbnail()
    if "--overview" in args:
        overview()
    if "--draft" in args:
        # Rychlý náhled při ladění modelu: méně vzorků (šum odstraní denoiser).
        R.CONFIG["render"]["samples"] = 16
    if "--variant" in args:
        number = int(args[args.index("--variant") + 1])
        layers = render_hall(number)
        preview(number, *layers[:3])
        if "--install" in args:
            install("hall", number, *layers)
            fill_missing("hall", number)
    if "--house" in args:
        number = int(args[args.index("--house") + 1])
        layers = render_house(number)
        preview(f"house-{number}", *layers[:3])
        if "--install" in args:
            install("house", number, *layers)
            fill_missing("house", number)
    if "--skywalk" in args:
        for skywalk in ("wood", "glass"):
            render_skywalk(skywalk)
