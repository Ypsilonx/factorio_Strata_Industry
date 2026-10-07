"""Procedurální modely překladišť a tabule ve stylu města (1 m = 1 dlaždice, osa Y = sever, kamera z jihu).

Body ve hře (okénko kapaliny, dráty a kontrolka tabule) se počítají ze stejných souřadnic jako model – viz
SCREEN a screen(): bod (x, y, z) modelu leží na obrazovce v dlaždicích (x, −y − z·cos 45°) od středu entity.
"""

import math
import random

import rt_sprites
from rt_hall import Builder, barrel, crate, place_sprite, window

#: Výška → posun na obrazovce (ortho kamera pod 45°).
SCREEN = math.cos(math.radians(45.0))

#: Průzor nádrže (x, y čela, z od–do) – průhled s hladinou kapaliny ve hře (window_bounding_box). Leží na plášti
#: nádrže TANK (střed x, y, poloměr, výška).
TANK = (0.35, 0.3, 1.0, 1.7)
GAUGE = (0.75, -0.6, 0.35, 1.4)
#: Úchyt drátů a lucerna (kontrolka) tabule.
BOARD_WIRE = (-0.34, 0.0, 1.4)
BOARD_LAMP = (0.34, 0.0, 1.35)
#: Úchyt měděného drátu městské rozvodny (střed ráhna sloupu nad izolátory) a délka stínu drátu na obrazovce
#: na jednotku výšky (podle vanilla rozvodny: drát 86 px nad zemí, stín 136 px vpravo).
POWER_WIRE = (0.8, 0.6, 2.2)
WIRE_SHADOW_PER_HEIGHT = 1.58
#: Zmenšení ikon předmětů ze hry na paletách a v regálech (ikona 64 px = 1 dlaždice).
ITEM_SCALE = 0.4
#: Zboží ve skladu (ikony ze hry) na paletách před skladem: pozice palet a předměty na nich.
PALLETS = [(-0.45, -0.2), (0.25, -0.25), (-0.1, -0.75)]
PALLET_ITEMS = [("iron-plate", "copper-plate"), ("wood", "stone-brick"), ("iron-gear-wheel", "copper-cable")]


def screen(x, y, z):
    """Bod modelu → posun na obrazovce v dlaždicích od středu entity (y dolů)."""
    return x, -y - z * SCREEN


def goods(b):
    """Překladiště zboží 2×2: sklad s kamennou zadní stěnou a pultovou plechovou stříškou nad zadní částí
    (bedny a železné bedny ze hry), před ním palety se zbožím ze hry, dřevěná bedna ze hry, sud a modrá
    cedulka města."""
    rng = random.Random(41)
    b.box("RT_Plaza", (0, 0, 0), (1.95, 1.95, 0.04), "cobble", bevel=0.02)
    b.box("RT_BackWall", (0, 0.78, 0.04), (1.85, 0.2, 1.3), "stone_wall")
    for x in (-0.86, 0.86):
        b.box("RT_SideWall", (x, 0.5, 0.04), (0.12, 0.45, 1.15), "planks", bevel=0.01)
        b.box("RT_Post", (x, 0.25, 0.04), (0.1, 0.1, 1.05), "wood_beam", bevel=0.01)
    b.box("RT_Roof", (0, 0.5, 1.12), (2.0, 0.75, 0.05), "corrugated", bevel=0.005, rotation=("X", 0.3))
    for x in (-0.55, -0.15):
        crate(b, x, 0.5, rng)
    crate(b, -0.35, 0.5, rng, z=0.36)
    for x in (0.3, 0.65):
        place_sprite(b, x, 0.45, rt_sprites.machine("iron-chest"), "RT_Chest", scale=0.45)
    for (px, py), items in zip(PALLETS, PALLET_ITEMS):
        b.box("RT_Pallet", (px, py, 0.04), (0.5, 0.42, 0.08), "planks", bevel=0.01)
        for k, name in enumerate(items):
            place_sprite(b, px - 0.1 + k * 0.2, py + 0.08 - k * 0.12, rt_sprites.item(name), "RT_Item",
                         scale=ITEM_SCALE, z=0.12)
    place_sprite(b, 0.78, -0.82, rt_sprites.machine("wooden-chest"), "RT_Chest", scale=0.45)
    barrel(b, -0.85, -0.8, rng)
    b.box("RT_Tag", (0.0, 0.67, 0.75), (0.3, 0.02, 0.2), "cloth_blue", bevel=0.005)
    return b.count


def fluid(b):
    """Překladiště kapalin 3×3: nýtovaná ocelová nádrž s klenutým víkem na betonovém základu, žebřík a průzor
    s hladinou (okénko kapaliny ve hře), domek obsluhy (okno svítí, lampa nad dveřmi), rozvod potrubí
    s ventilovými koly a páky; potrubní nástavce v rozích (připojení potrubí)."""
    b.box("RT_Plaza", (0, 0, 0), (2.95, 2.95, 0.04), "concrete", bevel=0.03)
    tx, ty, tr, th = TANK
    b.cylinder("RT_Base", (tx, ty, 0.04), tr + 0.12, 0.15, "concrete", segments=32)
    b.cylinder("RT_Tank", (tx, ty, 0.19), tr, th, "tank", segments=32)
    for z in (0.35, 0.9, 1.45):
        b.cylinder("RT_Band", (tx, ty, z), tr + 0.02, 0.05, "iron", segments=32, bevel=0)
    b.dome("RT_Lid", (tx, ty, 0.19 + th), tr + 0.02, 0.35, "tank")
    b.cylinder("RT_Hatch", (tx, ty, 0.19 + th + 0.3), 0.15, 0.12, "iron", segments=12, bevel=0)
    # Zábradlí kolem víka a odvětrání.
    top = 0.19 + th
    for i in range(12):
        a = 2 * math.pi * i / 12
        b.box("RT_RailPost", (tx + math.cos(a) * (tr - 0.05), ty + math.sin(a) * (tr - 0.05), top), (0.04, 0.04, 0.3),
              "iron", bevel=0)
    b.cylinder("RT_Rail", (tx, ty, top + 0.28), tr - 0.03, 0.04, "iron", segments=32, bevel=0)
    b.cylinder("RT_Vent", (tx + 0.45, ty + 0.3, top + 0.1), 0.06, 0.4, "rust_pipe", segments=10, bevel=0)
    b.cylinder("RT_VentCap", (tx + 0.45, ty + 0.3, top + 0.5), 0.1, 0.06, "iron", top_radius=0.02, segments=10, bevel=0)
    x, y, z0, z1 = GAUGE
    b.box("RT_GaugeFrame", (x, y - 0.02, z0 - 0.05), (0.2, 0.06, z1 - z0 + 0.1), "iron", bevel=0.01)
    b.box("RT_Gauge", (x, y - 0.05, z0), (0.12, 0.03, z1 - z0), "glass", bevel=0)
    # Žebřík na plášti vlevo od průzoru.
    lx, ly = tx - 0.35, ty - tr * 0.94
    for z in (0.35, 0.65, 0.95, 1.25, 1.55, 1.85):
        b.box("RT_Rung", (lx, ly - 0.04, z), (0.28, 0.04, 0.04), "iron", bevel=0)
    for side in (-0.14, 0.14):
        b.box("RT_LadderRail", (lx + side, ly - 0.05, 0.04), (0.04, 0.04, 1.95), "iron", bevel=0)
    # Domek obsluhy vlevo vpředu.
    hx, hy = -0.85, -0.7
    b.box("RT_Hut", (hx, hy, 0.04), (0.9, 0.75, 0.95), "brick")
    b.gable("RT_HutRoof", (hx, hy, 0.99), (0.9, 0.75), 0.32, "shingle", ridge="x", overhang=0.08)
    b.box("RT_HutDoor", (hx + 0.2, hy - 0.39, 0.06), (0.28, 0.04, 0.62), "planks", bevel=0.005)
    b.box("RT_HutWindow", (hx - 0.2, hy - 0.39, 0.42), (0.22, 0.03, 0.22), "window", bevel=0)
    b.box("RT_Lamp", (hx + 0.2, hy - 0.42, 0.75), (0.08, 0.06, 0.1), "window", bevel=0.01)
    # Rozvod potrubí od domku k nádrži, ventily a páky.
    pz = 0.3
    b.beam("RT_Pipe", (hx + 0.45, hy - 0.15, pz), (tx + 0.1, hy - 0.15, pz), 0.09, "rust_pipe")
    b.beam("RT_Pipe", (tx + 0.1, hy - 0.15, pz), (tx + 0.1, ty - tr + 0.1, pz), 0.09, "rust_pipe")
    for vx in (hx + 0.75, tx - 0.25):
        b.cylinder("RT_ValveStem", (vx, hy - 0.15, pz), 0.025, 0.2, "iron", segments=6, bevel=0)
        b.cylinder("RT_ValveWheel", (vx, hy - 0.15, pz + 0.2), 0.11, 0.025, "cloth_red", segments=16, bevel=0)
    for k, angle in enumerate((0.35, -0.3)):
        px = hx - 0.15 + k * 0.25
        b.box("RT_LeverBox", (px, hy - 0.62, 0.04), (0.14, 0.1, 0.2), "iron", bevel=0.01)
        b.box("RT_Lever", (px, hy - 0.62, 0.22), (0.03, 0.03, 0.3), "iron", bevel=0, rotation=("X", angle))
        b.blob("RT_LeverKnob", (px, hy - 0.62 - 0.1 * angle, 0.5), 0.045, "cloth_red", random.Random(k), squash=1.0)
    for cx in (-1, 1):
        for cy in (-1, 1):
            b.cylinder("RT_Stub", (cx, cy, 0.04), 0.13, 0.45, "iron", segments=12)
            b.cylinder("RT_Flange", (cx, cy, 0.42), 0.17, 0.07, "iron", segments=12, bevel=0)
    return b.count


def power(b):
    """Městská rozvodna: cihlový domek s plechovou střechou, izolátory, dřevěný sloup s dráty a cedule."""
    rng = random.Random(43)
    b.box("RT_Plaza", (0, 0, 0), (1.95, 1.95, 0.04), "cobble", bevel=0.03)
    b.box("RT_Hut", (-0.1, 0.15, 0.04), (1.35, 1.1, 1.0), "brick")
    b.gable("RT_HutRoof", (-0.1, 0.15, 1.04), (1.35, 1.1), 0.4, "corrugated", ridge="x", overhang=0.1)
    window(b, -0.4, -0.4, 0.45, rng, w=0.26, h=0.32, shutters=False)
    b.box("RT_Door", (0.25, -0.43, 0.06), (0.4, 0.05, 0.75), "iron", bevel=0.01)
    b.box("RT_Sign", (0.25, -0.47, 0.6), (0.2, 0.02, 0.16), "hay", bevel=0.005)
    for x in (-0.5, -0.1, 0.3):
        b.cylinder("RT_Insulator", (x, 0.35, 1.25), 0.07, 0.2, "plaster", segments=10, bevel=0.01)
    px, py, pz = POWER_WIRE
    b.cylinder("RT_Pole", (px, py, 0.04), 0.07, pz, "wood_beam", segments=8)
    b.box("RT_Crossarm", (px, py, pz - 0.2), (0.6, 0.08, 0.08), "wood_beam", bevel=0.01)
    for x in (px - 0.25, px + 0.25):
        b.cylinder("RT_PoleInsulator", (x, py, pz - 0.12), 0.04, 0.12, "plaster", segments=8, bevel=0)
        b.beam("RT_Wire", (x, py, pz - 0.02), (x - 0.85, 0.35, 1.4), 0.02, "iron")
    return b.count


def board(b):
    """Městská tabule: zeleně natřená vývěsní tabule v rámu na dvou sloupcích se stříškou, barevné vyvěšené
    listy, erb města na štítu a lucerna (kontrolka)."""
    b.box("RT_Plaza", (0, 0, 0), (0.95, 0.95, 0.04), "cobble", bevel=0.02)
    for x in (BOARD_WIRE[0], BOARD_LAMP[0]):
        b.box("RT_Post", (x, 0.0, 0.04), (0.08, 0.08, 1.4), "wood_beam", bevel=0.01)
    b.box("RT_Frame", (0, 0.01, 0.46), (0.8, 0.05, 0.83), "cloth_red", bevel=0.01)
    b.box("RT_Panel", (0, -0.01, 0.5), (0.7, 0.04, 0.75), "paint_green", bevel=0.005)
    papers = ("plaster", "hay", "cloth_blue", "plaster", "cloth_red")
    for (px, pz), mat in zip(((-0.2, 0.95), (0.06, 0.62), (0.2, 0.9), (-0.08, 0.68), (0.2, 0.58)), papers):
        b.box("RT_Paper", (px, -0.04, pz), (0.17, 0.01, 0.2), mat, bevel=0)
    b.gable("RT_BoardRoof", (0, 0.0, 1.38), (0.8, 0.22), 0.18, "shingle", ridge="x", overhang=0.06)
    b.cylinder("RT_Emblem", (0, -0.12, 1.47), 0.09, 0.03, "hay", segments=16, bevel=0)
    b.cylinder("RT_EmblemCore", (0, -0.13, 1.48), 0.06, 0.03, "cloth_blue", segments=16, bevel=0)
    lx, ly, lz = BOARD_LAMP
    b.box("RT_Lamp", (lx, ly - 0.06, lz - 0.2), (0.09, 0.09, 0.13), "window", bevel=0.01)
    return b.count


#: Překladiště: jméno entity → (stavitel, půdorys, místo nad půdorysem, okraj) v dlaždicích.
DEPOTS = {
    "rt-goods-depot": (goods, 2, 1.5, 0.5),
    "rt-fluid-depot": (fluid, 3, 2.0, 0.5),
    "rt-power-depot": (power, 2, 2.0, 0.5),
    "rt-town-board": (board, 1, 1.5, 0.5),
}


def build(collection, parent, mats, name):
    """Postaví model překladiště podle jména entity. Vrátí počet dílů."""
    return DEPOTS[name][0](Builder(collection, parent, mats))
