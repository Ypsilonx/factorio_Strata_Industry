"""Procedurální model domu (entita rt-house, 3×3 dlaždice) v pěti vzhledech podle úrovně domu.

Stejné stavební díly jako radnice (rt_hall), takže domy ladí s městem: 1 hrázděná chalupa s došky,
2 cihlová chalupa s plechem a olejovou lampou, 3 dvoupatrový cihlový dům, 4 třípatrový činžák z omítnutého
betonu s potrubím, 5 čtyřpatrový činžák se zahradou na střeše. Kamera hledí z jihu (okna a dveře na jihu).
"""

import random

from rt_hall import Builder, bush, barrel, crate, lamp_post, house, tenement

#: Polovina půdorysu domu (dlaždice).
HALF = 1.5


class Rolls:
    """Pevná posloupnost „náhodných“ čísel pro vylepšení domu (rt_hall.house volá up.random()): vzhled 2
    má vždy cihly a plech, vzhled 1 původní materiály."""

    def __init__(self, values):
        self.values = list(values)

    def random(self):
        """Další hodnota (po vyčerpání 0.99 – bez vylepšení)."""
        return self.values.pop(0) if self.values else 0.99


def picket_fence(b, y, x0, x1):
    """Plot z kůlů s břevnem podél jižního okraje dvorku."""
    count = int((x1 - x0) / 0.28)
    for k in range(count + 1):
        b.box("RT_Picket", (x0 + k * (x1 - x0) / count, y, 0.06), (0.05, 0.05, 0.36), "wood", bevel=0.01)
    b.beam("RT_FenceRail", (x0, y, 0.28), (x1, y, 0.28), 0.04, "wood")


def build(collection, parent, mats, variant):
    """Postaví dům daného vzhledu. Vrátí počet dílů."""
    b = Builder(collection, parent, mats, variant)
    yard = {1: "earth", 2: "earth", 3: "cobble"}.get(variant, "concrete")
    b.box("RT_Plaza", (0, 0, 0), (2 * HALF - 0.05, 2 * HALF - 0.05, 0.06), yard, bevel=0.03)
    rng = random.Random(21)
    if variant <= 2:
        # Chalupa: tvar ze stálého seedu, ve vzhledu 2 cihly a plechová střecha.
        upgrades = Rolls([0.99]) if variant == 1 else Rolls([0.99, 0.1, 0.1, 0.1])
        with b.at(0, 0.3):
            house(b, random.Random(31), 2.3, 1.8, upgrades)
        picket_fence(b, -HALF + 0.1, -HALF + 0.1, -0.35)
        bush(b, 1.0, -1.05, rng)
        if variant == 1:
            barrel(b, -1.0, -1.0, rng)
            b.blob("RT_Hay", (1.05, 0.95, 0.2), 0.32, "hay", rng, squash=0.9)
        else:
            lamp_post(b, 0.55, -1.15)
            for i in range(2):
                barrel(b, -1.05 + i * 0.3, -1.0, rng)
    else:
        floors = {3: 2, 4: 3}.get(variant, 4)
        with b.at(0, 0.25):
            tenement(b, 2.4, 2.0, rng, floors=floors)
        lamp_post(b, 1.15, -1.15)
        bush(b, -1.1, -1.1, rng)
        if variant >= 4:
            # Potrubí po fasádě a skříň rozvodu u domu.
            b.beam("RT_Pipe", (-1.05, -0.8, 0.1), (-1.05, -0.8, 2.6), 0.08, "iron")
            b.box("RT_Cabinet", (0.6, -1.0, 0.06), (0.35, 0.2, 0.5), "iron", bevel=0.02)
        else:
            crate(b, 0.6, -1.05, rng)
    return b.count
