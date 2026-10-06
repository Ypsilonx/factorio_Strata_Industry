"""Procedurální modely překladišť a tabule ve stylu města (1 m = 1 dlaždice, osa Y = sever, kamera z jihu).

Body ve hře (okénko kapaliny, dráty a kontrolka tabule) se počítají ze stejných souřadnic jako model – viz
SCREEN a screen(): bod (x, y, z) modelu leží na obrazovce v dlaždicích (x, −y − z·cos 45°) od středu entity.
"""

import math
import random

from rt_hall import Builder, crate, window

#: Výška → posun na obrazovce (ortho kamera pod 45°).
SCREEN = math.cos(math.radians(45.0))

#: Průzor kádě (x, y čela, z od–do) – průhled s hladinou kapaliny ve hře (window_bounding_box).
GAUGE = (0.6, -1.25, 0.3, 1.2)
#: Úchyt drátů a lucerna (kontrolka) tabule.
BOARD_WIRE = (-0.34, 0.0, 1.4)
BOARD_LAMP = (0.34, 0.0, 1.35)


def screen(x, y, z):
    """Bod modelu → posun na obrazovce v dlaždicích od středu entity (y dolů)."""
    return x, -y - z * SCREEN


def goods(b):
    """Překladiště zboží: okovaná bedna se šindelovou stříškou, pytel a modrá cedulka města."""
    rng = random.Random(41)
    b.box("RT_Plaza", (0, 0, 0), (0.95, 0.95, 0.04), "cobble", bevel=0.02)
    b.box("RT_Crate", (0, 0.05, 0.04), (0.84, 0.72, 0.6), "planks", bevel=0.03)
    for x in (-0.41, 0.41):
        b.box("RT_Band", (x, 0.05, 0.04), (0.05, 0.74, 0.62), "iron", bevel=0.01)
    b.gable("RT_Lid", (0, 0.05, 0.64), (0.84, 0.72), 0.24, "shingle", ridge="x", overhang=0.05)
    b.box("RT_Tag", (0.15, -0.3, 0.2), (0.22, 0.02, 0.16), "cloth_blue", bevel=0.005)
    b.blob("RT_Sack", (-0.3, -0.32, 0.14), 0.13, "hay", rng, squash=0.9)
    crate(b, 0.33, -0.35, rng)
    return b.count


def fluid(b):
    """Překladiště kapalin: dřevěná káď s obručemi na kamenném podstavci, kuželová stříška, žebřík,
    průzor s hladinou (okénko kapaliny ve hře) a potrubní nástavce v rozích (připojení potrubí)."""
    b.box("RT_Plaza", (0, 0, 0), (2.95, 2.95, 0.04), "cobble", bevel=0.03)
    b.cylinder("RT_Base", (0, 0, 0.04), 1.38, 0.25, "stone", segments=32)
    b.cylinder("RT_Vat", (0, 0, 0.29), 1.25, 1.35, "wood", segments=32)
    for z in (0.45, 0.95, 1.45):
        b.cylinder("RT_Hoop", (0, 0, z), 1.27, 0.07, "iron", segments=32, bevel=0)
    b.cylinder("RT_Roof", (0, 0, 1.62), 1.38, 0.55, "shingle", top_radius=0.12, segments=32, bevel=0.04)
    b.cylinder("RT_Cap", (0, 0, 2.15), 0.14, 0.15, "iron", segments=12, bevel=0)
    x, y, z0, z1 = GAUGE
    b.box("RT_GaugeFrame", (x, y - 0.02, z0 - 0.05), (0.2, 0.06, z1 - z0 + 0.1), "iron", bevel=0.01)
    b.box("RT_Gauge", (x, y - 0.05, z0), (0.12, 0.03, z1 - z0), "glass", bevel=0)
    for z in (0.35, 0.65, 0.95, 1.25, 1.55):
        b.box("RT_Rung", (-0.7, -1.06, z), (0.32, 0.04, 0.04), "iron", bevel=0)
    for side in (-0.86, -0.54):
        b.box("RT_LadderRail", (side, -1.07, 0.04), (0.04, 0.04, 1.6), "iron", bevel=0)
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
    b.cylinder("RT_Pole", (0.8, 0.6, 0.04), 0.07, 2.2, "wood_beam", segments=8)
    b.box("RT_Crossarm", (0.8, 0.6, 2.0), (0.6, 0.08, 0.08), "wood_beam", bevel=0.01)
    for x in (0.55, 1.05):
        b.cylinder("RT_PoleInsulator", (x, 0.6, 2.08), 0.04, 0.12, "plaster", segments=8, bevel=0)
        b.beam("RT_Wire", (x, 0.6, 2.18), (x - 0.85, 0.35, 1.4), 0.02, "iron")
    return b.count


def board(b):
    """Městská tabule: vývěsní tabule na dvou sloupcích se stříškou, vyvěšené listy, lucerna (kontrolka)."""
    b.box("RT_Plaza", (0, 0, 0), (0.95, 0.95, 0.04), "cobble", bevel=0.02)
    for x in (BOARD_WIRE[0], BOARD_LAMP[0]):
        b.box("RT_Post", (x, 0.0, 0.04), (0.08, 0.08, 1.4), "wood_beam", bevel=0.01)
    b.box("RT_Panel", (0, 0.0, 0.5), (0.74, 0.05, 0.75), "planks", bevel=0.01)
    for px, pz in ((-0.2, 0.95), (0.06, 0.62), (0.2, 0.9), (-0.08, 0.68), (0.2, 0.58)):
        b.box("RT_Paper", (px, -0.03, pz), (0.17, 0.01, 0.2), "plaster", bevel=0)
    b.gable("RT_BoardRoof", (0, 0.0, 1.38), (0.8, 0.22), 0.18, "shingle", ridge="x", overhang=0.06)
    lx, ly, lz = BOARD_LAMP
    b.box("RT_Lamp", (lx, ly - 0.06, lz - 0.2), (0.09, 0.09, 0.13), "window", bevel=0.01)
    return b.count


#: Překladiště: jméno entity → (stavitel, půdorys, místo nad půdorysem, okraj) v dlaždicích.
DEPOTS = {
    "rt-goods-depot": (goods, 1, 1.0, 0.5),
    "rt-fluid-depot": (fluid, 3, 2.0, 0.5),
    "rt-power-depot": (power, 2, 2.0, 0.5),
    "rt-town-board": (board, 1, 1.5, 0.5),
}


def build(collection, parent, mats, name):
    """Postaví model překladiště podle jména entity. Vrátí počet dílů."""
    return DEPOTS[name][0](Builder(collection, parent, mats))
