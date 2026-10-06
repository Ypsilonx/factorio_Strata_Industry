"""Grafika radnice Research Towns: procedurální model a render spritů pro Factorio.

Spuštění (headless, z kořene repozitáře):
    "C:/STEAM/steamapps/common/Blender/blender.exe" -b --factory-startup --python blender/build_hall.py -- --calibrate

Přepínače:
    --calibrate   zkušební deska 3×3 se sloupky přes vanilla laboratoř → blender/renders/calibration.png

Moduly: rt_render.py (scéna, kamera, světla, pixely), camera.toml (laditelná projekce a světla).
"""

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
    tiles, extra_top = 3, 1
    scene, collection = R.fresh_scene()
    parent = R.root(collection)
    R.setup_render(scene, tiles, tiles, extra_top)
    R.setup_camera(scene, collection, tiles, tiles, extra_top)
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


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--calibrate" in args:
        calibrate()
