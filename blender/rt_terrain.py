"""Textury terénu Factoria (hlína, tráva, dlažba, beton, mech) pro nádvoří, cesty a střechy radnice a domů.

Hra má v souboru terénu řádek 16 variant o velikosti 4×4 dlaždice (128 px HR na dlaždici je 64 px; varianta
256 px), které na sebe navazují. Atlas složí náhodnou mozaiku variant (bez opakování v sousedství) do textury
ATLAS_BLOCKS × ATLAS_BLOCKS variant a uloží ji do blender/renders/sprites (obrázky hry se do repozitáře
nekopírují). Materiál ji mapuje ve světových souřadnicích, takže navazuje přes všechny díly a 1 dlaždice
textury = 1 dlaždice hry.
"""

import math
import random
from pathlib import Path

import bpy
import numpy as np

FACTORIO_TERRAIN = Path("C:/STEAM/steamapps/common/Factorio/data/base/graphics/terrain")
CACHE = Path(__file__).resolve().parent / "renders" / "sprites"
#: Terén: klíč → (soubor v base/graphics/terrain, řádek variant 4×4 v px).
TERRAINS = {
    "earth": ("dirt-5.png", 320),
    "dry": ("dirt-3.png", 320),
    "grass": ("grass-1.png", 320),
    "moss": ("grass-3.png", 320),
    "cobble": ("stone-path/stone-path-4.png", 0),
    "concrete": ("concrete/concrete.png", 0),
}
#: Velikost varianty v px a počet variant v řádku.
BLOCK, VARIANTS = 256, 16
#: Atlas = ATLAS_BLOCKS × ATLAS_BLOCKS variant (opakuje se po 4 × ATLAS_BLOCKS dlaždicích).
ATLAS_BLOCKS = 4


def _load(path):
    """Načte PNG jako numpy pole (výška, šířka, 4) s řádky shora dolů."""
    img = bpy.data.images.load(str(path), check_existing=False)
    w, h = img.size
    pixels = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1]
    bpy.data.images.remove(img)
    return pixels


def atlas(key):
    """Složí (jednou, do cache) mozaiku variant terénu key a vrátí cestu k PNG."""
    path = CACHE / f"terrain-{key}.png"
    if path.exists():
        return path
    file, row = TERRAINS[key]
    sheet = _load(FACTORIO_TERRAIN / file)
    rng = random.Random(key)
    size = BLOCK * ATLAS_BLOCKS
    canvas = np.ones((size, size, 4), dtype=np.float32)
    for by in range(ATLAS_BLOCKS):
        for bx in range(ATLAS_BLOCKS):
            v = rng.randrange(VARIANTS)
            block = sheet[row:row + BLOCK, v * BLOCK:(v + 1) * BLOCK, :3]
            canvas[by * BLOCK:(by + 1) * BLOCK, bx * BLOCK:(bx + 1) * BLOCK, :3] = block
    CACHE.mkdir(parents=True, exist_ok=True)
    img = bpy.data.images.new("RT_terrain_tmp", width=size, height=size, alpha=True)
    img.pixels[:] = canvas[::-1].reshape(-1)
    img.filepath_raw = str(path)
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    return path


def color(nt, key, scale=1.0):
    """Uzel barvy terénu key ve světových souřadnicích (dlaždice; osa Y modelu je natažená o √2).
    scale > 1 zjemní vzor (mech na střeše). Vrátí výstup barvy."""
    tiles = 4 * ATLAS_BLOCKS / scale
    geometry = nt.nodes.new("ShaderNodeNewGeometry")
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (1 / tiles, 1 / (tiles * math.sqrt(2.0)), 1 / tiles)
    nt.links.new(geometry.outputs["Position"], mapping.inputs["Vector"])
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(str(atlas(key)), check_existing=True)
    tex.extension = "REPEAT"
    nt.links.new(mapping.outputs["Vector"], tex.inputs["Vector"])
    return tex.outputs["Color"]
