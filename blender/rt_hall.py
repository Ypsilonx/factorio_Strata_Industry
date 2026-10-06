"""Procedurální model radnice: hustě zastavěný areál 15×15 dlaždic (1 m = 1 dlaždice, osa Y = sever).

Rozvržení je organické: kulaté náměstí se studnou, kolem něj prstenec domů a chýší natočených čelem
k náměstí, vzadu badatelna s kulatou věží, vepředu brána a ulice, v rozích háje a zahrady. Domy generuje
house / roundhouse z náhodného generátoru se stálým seedem – každý je jiný, ale při každém buildu stejný.
Díly se staví v místních souřadnicích stavby (čelo = jižní stěna, y = −hloubka/2) a Builder.at je natočí.
Vzhled se mění parametrem variant (1 = osada … 5 = město vědy); zatím je hotový vzhled 1.
Otočný díl věže (lucerna se stříškou) je samostatný objekt RT_Hall_Rotor – připravený pro pozdější animaci.
"""

import math
import random
from contextlib import contextmanager

import bmesh
import bpy
from mathutils import Matrix, Vector

import rt_trees

#: Polovina půdorysu radnice (dlaždice).
HALF = 7.5
#: Střed a poloměr kulatého náměstí.
SQUARE = (0.0, -0.9)
SQUARE_R = 2.6
#: Háje a zahrady (x, y) v místech mezi prstencem a okrajem.
GROVES = [(-6.4, 6.4), (6.6, 6.5), (-6.5, -6.5), (6.4, -6.4), (4.6, 2.6), (-4.7, 2.4)]

ROOFS = [("thatch", 0.5), ("shingle", 0.35), ("slate", 0.15)]
PLASTERS = ["plaster", "plaster_ochre", "plaster_grey", "plaster_pink"]


def pick(rng, weighted):
    """Vážený výběr z [(hodnota, váha)]."""
    total = sum(w for _, w in weighted)
    r = rng.random() * total
    for value, weight in weighted:
        r -= weight
        if r <= 0:
            return value
    return weighted[-1][0]


class Builder:
    """Skládá díly modelu do kolekce pod společný kořen (natažení osy Y v rt_render.root).
    matrix = aktuální transformace místních souřadnic stavby (Builder.at)."""

    def __init__(self, collection, parent, mats, variant=1):
        self.collection = collection
        self.parent = parent
        self.mats = mats
        #: Vzhled 1 (osada) … 5 (město vědy) – díly podle něj mění materiály a vybavení.
        self.variant = variant
        self.count = 0
        self.matrix = Matrix.Identity(4)

    @contextmanager
    def at(self, x, y, angle=0.0):
        """Díly uvnitř bloku se staví v místních souřadnicích stavby posunuté do (x, y) a natočené o angle."""
        previous = self.matrix
        self.matrix = previous @ Matrix.Translation((x, y, 0)) @ Matrix.Rotation(angle, 4, "Z")
        try:
            yield
        finally:
            self.matrix = previous

    def _object(self, name, bm, mat, bevel, smooth=False):
        """Z bmesh vytvoří objekt (v aktuální transformaci) s materiálem a zaoblením hran."""
        self.count += 1
        bmesh.ops.transform(bm, matrix=self.matrix, verts=bm.verts)
        if smooth:
            for face in bm.faces:
                face.smooth = True
        mesh = bpy.data.meshes.new(f"{name}_{self.count}")
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(self.mats[mat])
        obj = bpy.data.objects.new(f"{name}_{self.count}", mesh)
        obj.parent = self.parent
        self.collection.objects.link(obj)
        if bevel:
            mod = obj.modifiers.new("Bevel", "BEVEL")
            mod.width = bevel
            mod.segments = 3
            mod.limit_method = "ANGLE"
            mod.harden_normals = False
        return obj

    def box(self, name, center, size, mat, bevel=0.05, rotation=None):
        """Kvádr: center = (x, y, z podstavy), size = (x, y, z), rotation = (osa, úhel) kolem středu."""
        bm = bmesh.new()
        x, y, z = center
        sx, sy, sz = size
        matrix = Matrix.Translation((x, y, z + sz / 2))
        if rotation:
            matrix = matrix @ Matrix.Rotation(rotation[1], 4, rotation[0])
        matrix = matrix @ Matrix.Diagonal((sx, sy, sz, 1.0))
        bmesh.ops.create_cube(bm, size=1.0, matrix=matrix)
        return self._object(name, bm, mat, min(bevel, sx / 3, sy / 3, sz / 3))

    def beam(self, name, p0, p1, thickness, mat):
        """Trám mezi dvěma body (hrázdění, vzpěry)."""
        a, b = Vector(p0), Vector(p1)
        direction = b - a
        rot = direction.to_track_quat("Z", "Y").to_matrix().to_4x4()
        matrix = Matrix.Translation((a + b) / 2) @ rot @ Matrix.Diagonal((thickness, thickness, direction.length, 1))
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0, matrix=matrix)
        return self._object(name, bm, mat, 0.01)

    def gable(self, name, center, size, height, mat, ridge="x", overhang=0.25, hip=0.0):
        """Sedlová (hip > 0 valbová) střecha: center = (x, y, z okapu), size = půdorys, ridge = osa hřebene.
        Doškové střechy mají silně zaoblený hřeben a okraje."""
        x, y, z = center
        sx, sy = size[0] + 2 * overhang, size[1] + 2 * overhang
        bm = bmesh.new()
        if ridge == "x":
            inset = min(hip, sx / 2 - 0.05)
            pts = [(-sx / 2, -sy / 2, 0), (sx / 2, -sy / 2, 0), (sx / 2, sy / 2, 0), (-sx / 2, sy / 2, 0),
                   (-sx / 2 + inset, 0, height), (sx / 2 - inset, 0, height)]
            faces = [(0, 1, 5, 4), (2, 3, 4, 5), (0, 4, 3), (1, 2, 5), (0, 3, 2, 1)]
        else:
            inset = min(hip, sy / 2 - 0.05)
            pts = [(-sx / 2, -sy / 2, 0), (sx / 2, -sy / 2, 0), (sx / 2, sy / 2, 0), (-sx / 2, sy / 2, 0),
                   (0, -sy / 2 + inset, height), (0, sy / 2 - inset, height)]
            faces = [(1, 2, 5, 4), (3, 0, 4, 5), (0, 1, 4), (2, 3, 5), (0, 3, 2, 1)]
        verts = [bm.verts.new((x + px, y + py, z + pz)) for px, py, pz in pts]
        for face in faces:
            bm.faces.new([verts[i] for i in face])
        thick = 0.22 if mat == "thatch" else 0.12
        bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=thick)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        return self._object(name, bm, mat, 0.1 if mat == "thatch" else 0.03)

    def cylinder(self, name, center, radius, height, mat, top_radius=None, segments=24, bevel=0.03):
        """Válec nebo kužel (top_radius) s podstavou v center = (x, y, z); hladce stínovaný."""
        x, y, z = center
        bm = bmesh.new()
        top = radius if top_radius is None else top_radius
        bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=top, depth=height,
                              matrix=Matrix.Translation((x, y, z + height / 2)))
        return self._object(name, bm, mat, bevel, smooth=segments >= 12)

    def dome(self, name, center, radius, height, mat, segments=24):
        """Zaoblená kupole / doškový klobouk: polokoule zploštělá na height."""
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=12, radius=1.0)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.01], context="VERTS")
        bmesh.ops.scale(bm, vec=(radius, radius, height), verts=bm.verts)
        bmesh.ops.translate(bm, vec=center, verts=bm.verts)
        return self._object(name, bm, mat, 0, smooth=True)

    def blob(self, name, center, radius, mat, rng, squash=1.0):
        """Nepravidelná koule (koruna stromu, keř, kupka sena) – icosféra s náhodně posunutými vrcholy."""
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=3, radius=radius,
                                   matrix=Matrix.Translation(center) @ Matrix.Diagonal((1, 1, squash, 1)))
        for v in bm.verts:
            v.co += (v.co - Vector(center)).normalized() * rng.uniform(-0.1, 0.1) * radius
        return self._object(name, bm, mat, 0, smooth=True)


# ---------------------------------------------------------------------------------------------------- detaily


def window(b, x, y_face, z, rng, w=0.32, h=0.42, shutters=True):
    """Okno na čelní stěně: rám, svítící sklo, případně okenice a truhlík s květinami."""
    b.box("RT_WinFrame", (x, y_face - 0.03, z - 0.05), (w + 0.1, 0.06, h + 0.1), "wood_beam", bevel=0.01)
    b.box("RT_Window", (x, y_face - 0.065, z), (w, 0.04, h), "window", bevel=0)
    if shutters and rng.random() < 0.6:
        for side in (-1, 1):
            b.box("RT_Shutter", (x + side * (w / 2 + 0.1), y_face - 0.05, z), (0.15, 0.04, h), "planks", bevel=0.005)
    if rng.random() < 0.35:
        b.box("RT_FlowerBox", (x, y_face - 0.12, z - 0.12), (w + 0.1, 0.16, 0.1), "wood", bevel=0.01)
        b.blob("RT_Flowers", (x, y_face - 0.13, z - 0.02), 0.12, "foliage_light", rng, squash=0.6)


def door(b, x, y_face, w=0.5, h=0.85):
    """Dřevěné dveře s obloukovým nadpražím na čelní stěně."""
    b.box("RT_DoorFrame", (x, y_face - 0.02, 0.06), (w + 0.12, 0.05, h + 0.06), "wood_beam", bevel=0.01)
    b.box("RT_Door", (x, y_face - 0.05, 0.06), (w, 0.06, h), "planks", bevel=0.01)
    b.cylinder("RT_DoorArch", (x, y_face - 0.02, h + 0.04), w / 2 + 0.06, 0.06, "wood_beam", segments=16, bevel=0)


def timber_frame(b, x0, x1, y_face, z0, z1, rng):
    """Hrázdění na čelní stěně: sloupky, paždík a šikmé vzpěry v krajních polích."""
    y = y_face - 0.04
    count = max(2, int((x1 - x0) / 0.55))
    xs = [x0 + (x1 - x0) * i / count for i in range(count + 1)]
    for xi in xs:
        b.beam("RT_Stud", (xi, y, z0), (xi, y, z1), 0.07, "wood_beam")
    b.beam("RT_Rail", (x0, y, (z0 + z1) / 2), (x1, y, (z0 + z1) / 2), 0.06, "wood_beam")
    b.beam("RT_Sill", (x0, y, z0), (x1, y, z0), 0.09, "wood_beam")
    if rng.random() < 0.8:
        b.beam("RT_Brace", (xs[0], y, z0), (xs[1], y, z1), 0.06, "wood_beam")
        b.beam("RT_Brace", (xs[-1], y, z0), (xs[-2], y, z1), 0.06, "wood_beam")


def barrel(b, x, y, rng):
    """Sud se dvěma obručemi."""
    r = rng.uniform(0.13, 0.17)
    b.cylinder("RT_Barrel", (x, y, 0.06), r, 0.4, "wood", segments=14)
    for z in (0.14, 0.34):
        b.cylinder("RT_Hoop", (x, y, z), r + 0.012, 0.03, "wood_beam", segments=14, bevel=0)


def crate(b, x, y, rng, z=0.06):
    """Bedna z prken."""
    s = rng.uniform(0.25, 0.35)
    b.box("RT_Crate", (x, y, z), (s, s, s * 0.85), "planks", bevel=0.03, rotation=("Z", rng.uniform(-0.3, 0.3)))


def tree(b, x, y, rng):
    """Vanilla strom Factoria (sprite na ploše ke kameře, viz rt_trees) s patou v místním bodě (x, y)."""
    p = b.matrix @ Vector((x, y, 0.0))
    rt_trees.billboard(b.collection, p.x, p.y * math.sqrt(2.0), rng)


def lamp_post(b, x, y):
    """Olejová lampa na železném sloupu (od vzhledu 2): sloup, rameno, svítící lucerna se stříškou."""
    b.cylinder("RT_LampBase", (x, y, 0.06), 0.1, 0.15, "stone", segments=10)
    b.cylinder("RT_LampPost", (x, y, 0.2), 0.04, 1.35, "iron", segments=8, bevel=0)
    b.box("RT_Lamp", (x, y, 1.45), (0.16, 0.16, 0.22), "window", bevel=0.01)
    b.cylinder("RT_LampCap", (x, y, 1.66), 0.13, 0.1, "iron", top_radius=0.02, segments=8, bevel=0)


def bush(b, x, y, rng):
    """Keř."""
    b.blob("RT_Bush", (x, y, 0.2), rng.uniform(0.22, 0.38), "foliage", rng, squash=0.7)


def props(b, sx, face, door_x, rng):
    """Před domem: sudy, bedny, keř (v místních souřadnicích stavby)."""
    for _ in range(rng.randint(0, 2)):
        px = rng.uniform(-sx * 0.45, sx * 0.45)
        if abs(px - door_x) > 0.4:
            (barrel if rng.random() < 0.5 else crate)(b, px, face - rng.uniform(0.25, 0.4), rng)
    if rng.random() < 0.4:
        bush(b, rng.choice((-1, 1)) * sx * 0.45, face - 0.3, rng)


# ---------------------------------------------------------------------------------------------------- stavby


def upgraded_wall(b, mat, up):
    """Zeď podle vzhledu: od vzhledu 2 část omítnutých zdí nahradí cihly (up = generátor vylepšení domu –
    stejný pro všechny vzhledy, takže co jednou zcihlovatělo, zůstane cihlové)."""
    roll = up.random()
    if mat in PLASTERS and b.variant >= 2 and roll < 0.45:
        return "brick"
    return mat


def upgraded_roof(b, roof, up):
    """Střecha podle vzhledu: od vzhledu 2 část doškových střech nahradí vlnitý plech, část šindel."""
    roll = up.random()
    if roof == "thatch" and b.variant >= 2:
        if roll < 0.45:
            return "corrugated"
        if roll < 0.7:
            return "shingle"
    return roof


def house(b, rng, sx, sy, up):
    """Dům sx × sy se středem v počátku: 1–2 patra, kamenné, omítnuté nebo (od vzhledu 2) cihlové přízemí,
    hrázděné vyložené patro, střecha z došků, šindele, břidlice nebo plechu, okna s okenicemi, dveře, komín.
    rng = tvar domu (stejný ve všech vzhledech), up = vylepšení podle vzhledu."""
    two = rng.random() < 0.6
    floor_h = rng.uniform(1.25, 1.45)
    ground_base = "stone_wall" if rng.random() < 0.45 else rng.choice(PLASTERS)
    ground_mat = upgraded_wall(b, ground_base, up)
    b.box("RT_House", (0, 0, 0.04), (sx, sy, floor_h), ground_mat)
    face = -sy / 2
    top = 0.04 + floor_h
    jetty = 0.0
    if two:
        jetty = rng.uniform(0.1, 0.2)
        upper_h = rng.uniform(1.1, 1.3)
        upper_mat = upgraded_wall(b, rng.choice(PLASTERS), up)
        b.box("RT_Upper", (0, -jetty / 2, top), (sx, sy + jetty, upper_h), upper_mat)
        if upper_mat != "brick":
            timber_frame(b, -sx / 2 + 0.05, sx / 2 - 0.05, face - jetty, top, top + upper_h, rng)
        else:
            rng.random()  # stejná spotřeba náhody jako hrázdění – další detaily domu zůstanou jako u osady
        for wx in (-sx * 0.25, sx * 0.25):
            window(b, wx, face - jetty, top + 0.35, rng)
        top += upper_h
    elif ground_base in PLASTERS:
        if ground_mat in PLASTERS:
            timber_frame(b, -sx / 2 + 0.05, sx / 2 - 0.05, face, 0.1, top, rng)
        else:
            rng.random()  # viz výše
    door_x = rng.uniform(-sx * 0.25, sx * 0.25)
    door(b, door_x, face, w=rng.uniform(0.42, 0.55), h=rng.uniform(0.8, 0.95))
    for wx in (-sx * 0.33, sx * 0.33):
        if abs(wx - door_x) > 0.45:
            window(b, wx, face, 0.55, rng, w=0.28, h=0.36)
    # Zadní stěna: domy natočené čelem k náměstí ukazují kameře záda – i tam okna.
    with b.at(0, 0, math.pi):
        for wx in (-sx * 0.3, sx * 0.3):
            window(b, wx, -sy / 2 - (jetty if two else 0.0), 0.55, rng, w=0.26, h=0.34)
        if two:
            window(b, rng.uniform(-sx * 0.2, sx * 0.2), -sy / 2, top - 0.75, rng, w=0.28, h=0.38)
    roof = upgraded_roof(b, pick(rng, ROOFS), up)
    roof_h = sy * rng.uniform(0.4, 0.55)
    hip = rng.uniform(0.3, 0.8) if rng.random() < 0.35 else 0.0
    b.gable("RT_Roof", (0, -jetty / 2, top), (sx, sy + jetty), roof_h, roof, ridge="x", hip=hip,
            overhang=rng.uniform(0.15, 0.3))
    if rng.random() < 0.6:
        cx = rng.choice((-1, 1)) * sx * rng.uniform(0.2, 0.35)
        chimney = "stone" if rng.random() < 0.6 else "stone_wall"
        b.cylinder("RT_Chimney", (cx, sy * 0.15, top - 0.3), 0.18, roof_h + 0.7 + (0.4 if b.variant >= 2 else 0.0),
                   "brick" if b.variant >= 2 else chimney, segments=12)
    props(b, sx, face, door_x, rng)


def roundhouse(b, rng, r, up):
    """Kulatá chýše místních o poloměru zdi r: kamenná, omítnutá nebo (od vzhledu 2) cihlová válcová zeď,
    kuželová došková střecha se zaobleným vrcholem (místní tradice zůstává), dveře a okénka po obvodu."""
    wall_h = rng.uniform(1.0, 1.3)
    wall = upgraded_wall(b, "stone_wall" if rng.random() < 0.5 else rng.choice(PLASTERS), up)
    b.cylinder("RT_RoundWall", (0, 0, 0.04), r, wall_h, wall, segments=24)
    if wall != "stone_wall":
        b.cylinder("RT_RoundBase", (0, 0, 0.04), r + 0.03, 0.3, "stone_wall", segments=24)
    top = 0.04 + wall_h
    roof_r = r + rng.uniform(0.25, 0.4)
    roof_h = rng.uniform(1.1, 1.5)
    b.cylinder("RT_RoundRoof", (0, 0, top - 0.1), roof_r, roof_h * 0.75, "thatch", top_radius=roof_r * 0.3,
               segments=24, bevel=0.08)
    b.dome("RT_RoundCap", (0, 0, top - 0.1 + roof_h * 0.75), roof_r * 0.3, roof_h * 0.3, "thatch")
    door(b, 0.0, -r + 0.02, w=0.45, h=0.8)
    # Okénka po obvodu (chýše je vidět ze všech stran podle natočení).
    for angle in (55, 125, 180, 235, 305):
        if rng.random() < 0.7:
            with b.at(0, 0, math.radians(angle)):
                window(b, 0.0, -r + 0.02, 0.5, rng, w=0.22, h=0.3, shutters=False)
    props(b, r * 2, -r, 0.0, rng)


def smithy(b, rng):
    """Kovárna: kamenná dílna s otevřenou výhní (svítí), vysokým kulatým komínem a kovadlinou."""
    sx, sy = 2.6, 2.4
    b.box("RT_Smithy", (0, 0, 0.04), (sx, sy, 1.6), "stone_wall")
    face = -sy / 2
    dilny = b.variant >= 2
    b.gable("RT_SmithyRoof", (0, 0, 1.64), (sx, sy), 1.1, "corrugated" if dilny else "slate", ridge="x")
    b.cylinder("RT_Chimney", (0.6, 0.5, 1.0), 0.32, 3.6 if dilny else 2.8, "brick" if dilny else "stone",
               top_radius=0.26)
    if dilny:
        # Dílny: přístavek s plechovou stříškou a sudy oleje.
        b.box("RT_Shed", (-sx / 2 - 0.5, 0.2, 0.04), (0.9, 1.6, 1.0), "planks")
        b.gable("RT_ShedRoof", (-sx / 2 - 0.5, 0.2, 1.04), (0.9, 1.6), 0.3, "corrugated", ridge="y", overhang=0.1)
        for i in range(3):
            barrel(b, -sx / 2 - 0.4 + i * 0.32, -sy / 2 - 0.3, random.Random(77 + i))
    b.box("RT_Forge", (-0.3, face - 0.05, 0.3), (0.7, 0.08, 0.5), "fire", bevel=0)
    b.cylinder("RT_ForgeArch", (-0.3, face - 0.02, 0.78), 0.45, 0.1, "stone", segments=16, bevel=0)
    b.box("RT_Anvil", (0.6, face - 0.45, 0.06), (0.35, 0.18, 0.3), "slate", bevel=0.02)
    crate(b, -0.9, face - 0.4, rng)
    barrel(b, 1.0, face - 0.3, rng)


def research_hall(b, rng):
    """Badatelna: dvoupatrová kamenná budova s hrázděným patrem, vraty, prapory a kulatou věží
    s vyhlídkou, lucernou a kuželovou stříškou (rotor)."""
    sx, sy = 4.6, 3.4
    dilny = b.variant >= 2
    b.box("RT_HallStone", (0, 0, 0.04), (sx, sy, 1.6), "stone_wall")
    b.box("RT_HallUpper", (0, -0.1, 1.64), (sx, sy + 0.2, 1.3), "brick" if dilny else "plaster")
    face = -sy / 2
    if dilny:
        rng.random()  # stejná spotřeba náhody jako hrázdění
        b.box("RT_HallCornice", (0, -0.1, 2.9), (sx + 0.1, sy + 0.3, 0.12), "stone")
    else:
        timber_frame(b, -sx / 2 + 0.05, sx / 2 - 0.05, face - 0.2, 1.64, 2.94, rng)
    b.gable("RT_HallRoof", (0, -0.1, 2.94), (sx, sy + 0.2), 1.6, "slate", ridge="x", hip=0.7)
    if dilny:
        for cx in (-1.5, 0.9):
            b.box("RT_HallChimney", (cx, 0.4, 2.6), (0.35, 0.35, 2.2), "brick")
    door(b, -0.5, face, w=1.0, h=1.25)
    for wx in (-1.9, 0.6, 1.5):
        window(b, wx, face, 0.6, rng, w=0.32, h=0.5)
    for wx in (-1.7, -0.8, 0.1, 1.0, 1.8):
        window(b, wx, face - 0.2, 2.05, rng, w=0.3, h=0.45)
    for bx in (-1.25, 0.25):
        b.box("RT_Banner", (bx, face - 0.26, 1.75), (0.32, 0.03, 0.9), "cloth_blue", bevel=0.005)
    # Kulatá věž v rohu.
    tx, ty, tr = 2.3, 0.9, 0.95
    b.cylinder("RT_Tower", (tx, ty, 0.04), tr, 5.4, "stone", top_radius=tr * 0.9)
    window(b, tx, ty - tr * 0.9, 3.5, rng, w=0.26, h=0.55, shutters=False)
    window(b, tx, ty - tr * 0.88, 4.5, rng, w=0.26, h=0.4, shutters=False)
    b.cylinder("RT_Deck", (tx, ty, 5.44), tr + 0.35, 0.14, "planks", segments=24)
    for i in range(10):
        a = 2 * math.pi * i / 10
        b.box("RT_DeckPost", (tx + math.cos(a) * (tr + 0.25), ty + math.sin(a) * (tr + 0.25), 5.58),
              (0.08, 0.08, 0.7), "wood_beam", bevel=0.01)
    b.cylinder("RT_DeckRail", (tx, ty, 6.2), tr + 0.28, 0.07, "wood_beam", segments=24, bevel=0)
    b.cylinder("RT_Lantern", (tx, ty, 5.58), 0.32, 0.5, "window", segments=12, bevel=0.02)
    rotor = b.cylinder("RT_Hall_Rotor", (tx, ty, 6.25), tr + 0.55, 1.1, "corrugated" if dilny else "shingle",
                       top_radius=0.06, segments=24, bevel=0.04)
    rotor.name = "RT_Hall_Rotor"
    b.cylinder("RT_Spire", (tx, ty, 7.3), 0.05, 0.5, "wood_beam", segments=8, bevel=0)


def square(b, rng):
    """Kulaté náměstí a ulice od brány: dlažba, studna, tržní stánky, vatra, strom a keře."""
    cx, cy = SQUARE
    b.cylinder("RT_Square", (cx, cy, 0.06), SQUARE_R, 0.03, "cobble", segments=48, bevel=0.02)
    b.box("RT_Street", (0.0, -5.6, 0.06), (1.8, 3.8, 0.03), "cobble", bevel=0.02)
    b.cylinder("RT_Well", (cx, cy, 0.06), 0.6, 0.5, "stone", segments=24)
    b.cylinder("RT_WellWater", (cx, cy, 0.4), 0.45, 0.17, "slate", segments=24, bevel=0)
    for side in (-1, 1):
        b.box("RT_WellPost", (cx + side * 0.5, cy, 0.06), (0.1, 0.1, 1.15), "wood_beam", bevel=0.01)
    b.gable("RT_WellRoof", (cx, cy, 1.2), (1.2, 0.9), 0.4, "shingle", ridge="x", overhang=0.1)
    if b.variant >= 2:
        # Dílny: železná ruční pumpa u studny a olejové lampy kolem náměstí a podél ulice.
        b.cylinder("RT_Pump", (cx + 0.75, cy + 0.2, 0.06), 0.09, 0.8, "iron", segments=10)
        b.box("RT_PumpArm", (cx + 0.75, cy + 0.05, 0.75), (0.06, 0.4, 0.06), "iron", bevel=0.01)
        for angle in (20, 100, 200, 280):
            a = math.radians(angle)
            lamp_post(b, cx + math.cos(a) * (SQUARE_R - 0.15), cy + math.sin(a) * (SQUARE_R - 0.15))
        for ly in (-4.4, -6.2):
            for lx in (-1.05, 1.05):
                lamp_post(b, lx, ly)
    for angle, cloth in ((150, "cloth_red"), (330, "cloth_blue")):
        a = math.radians(angle)
        with b.at(cx + math.cos(a) * 1.7, cy + math.sin(a) * 1.7, a + math.pi / 2):
            for dx in (-1, 1):
                for dy in (-1, 1):
                    b.box("RT_StallPost", (dx * 0.5, dy * 0.3, 0.06), (0.07, 0.07, 1.0), "wood_beam", 0.005)
            b.box("RT_StallTable", (0, 0, 0.45), (1.0, 0.55, 0.08), "planks", bevel=0.01)
            b.gable("RT_StallRoof", (0, 0, 1.06), (1.0, 0.6), 0.3, cloth, ridge="x", overhang=0.12)
            for i in range(3):
                crate(b, -0.3 + i * 0.3, 0, rng, z=0.53)
    b.cylinder("RT_FireRing", (cx + 1.6, cy - 1.3, 0.06), 0.38, 0.15, "stone", segments=16)
    b.cylinder("RT_Fire", (cx + 1.6, cy - 1.3, 0.12), 0.24, 0.4, "fire", top_radius=0.02, segments=10, bevel=0)
    tree(b, cx - 1.4, cy - 1.6, rng)
    for angle in (60, 250):
        a = math.radians(angle)
        bush(b, cx + math.cos(a) * 2.3, cy + math.sin(a) * 2.3, rng)


def grove(b, x, y, rng):
    """Háj nebo zahrada: trávník, strom, keře, kupka sena, záhon ohrazený plotem."""
    b.cylinder("RT_Lawn", (x, y, 0.06), rng.uniform(1.1, 1.4), 0.04, "grass", segments=20, bevel=0.03)
    tree(b, x + rng.uniform(-0.3, 0.3), y + rng.uniform(-0.2, 0.3), rng)
    for _ in range(rng.randint(1, 3)):
        a = rng.uniform(0, 2 * math.pi)
        bush(b, x + math.cos(a) * 1.0, y + math.sin(a) * 1.0, rng)
    if rng.random() < 0.5:
        b.blob("RT_Hay", (x + 0.8, y - 0.7, 0.25), 0.4, "hay", rng, squash=0.9)


def gate(b, rng):
    """Brána vepředu: kulaté kamenné patky, sloupy, překlad, šindelová stříška a lucerny."""
    y = -HALF + 0.3
    for side in (-1, 1):
        b.cylinder("RT_GateStone", (side * 1.2, y, 0.04), 0.33, 0.45, "stone")
        b.cylinder("RT_GatePost", (side * 1.2, y, 0.45), 0.18, 1.6, "wood_beam", segments=12)
        b.cylinder("RT_GateLamp", (side * 1.2, y - 0.25, 1.4), 0.09, 0.22, "window", segments=8, bevel=0.01)
    b.box("RT_GateLintel", (0, y, 1.95), (3.0, 0.32, 0.26), "wood_beam")
    b.gable("RT_GateRoof", (0, y, 2.2), (3.2, 0.6), 0.5, "shingle", ridge="x", overhang=0.15)


def build(collection, parent, mats, variant=1):
    """Postaví celý areál radnice daného vzhledu. Vrátí počet dílů."""
    b = Builder(collection, parent, mats, variant)
    b.box("RT_Plaza", (0, 0, 0), (2 * HALF - 0.05, 2 * HALF - 0.05, 0.06), "earth", bevel=0.04)
    # Pevné seedy (ne podle vzhledu): město ve všech vzhledech stejně rozložené, mění se jen vybavení.
    rng = random.Random(1000)
    with b.at(-0.6, 4.6):
        research_hall(b, rng)
    with b.at(-4.4, 5.3, math.radians(-12)):
        smithy(b, rng)
    # Pevné stavby a volné plochy (x, y, poloměr): badatelna, věž, kovárna, náměstí, ulice, brána.
    cx, cy = SQUARE
    # (-0.6, 2.0) = volné prostranství před průčelím badatelny – stromy by ho zakryly.
    occupied = [(-0.6, 4.6, 2.6), (1.7, 5.5, 1.3), (-4.4, 5.3, 1.6), (cx, cy, SQUARE_R + 0.3), (-0.6, 2.0, 2.0),
                (0.0, -5.0, 1.0), (0.0, -6.6, 1.3)]
    houses = place_houses(b, variant, occupied)
    square(b, rng)
    for x, y in GROVES:
        if not any(math.hypot(x - ox, y - oy) < orad + 0.4 for ox, oy, orad in occupied):
            grove(b, x, y, rng)
            occupied.append((x, y, 1.2))
    fill_greenery(b, rng, occupied)
    gate(b, rng)
    print(f"RADNICE: {houses} domů a chýší")
    return b.count


#: Kolik domů a chýší se nejvýš postaví a kolik pokusů o místo.
MAX_HOUSES, PLACE_ATTEMPTS = 22, 600
#: O kolik se smí obrysy staveb překrývat (střechy přes sebe – hustá zástavba).
OVERLAP = 0.45


def place_houses(b, variant, occupied):
    """Zaplní areál domy a chýšemi: náhodná místa, stavba čelem k náměstí, jen kde je volno. Vrátí počet."""
    rng = random.Random(7919)
    cx, cy = SQUARE
    count = 0
    for _ in range(PLACE_ATTEMPTS):
        if count >= MAX_HOUSES:
            break
        round_hut = rng.random() < 0.35
        if round_hut:
            wall_r = rng.uniform(0.8, 1.1)
            radius = wall_r + 0.3
        else:
            sx, sy = rng.uniform(1.8, 2.6), rng.uniform(1.6, 2.2)
            radius = math.hypot(sx, sy) / 2
        x = rng.uniform(-HALF + radius * 0.75, HALF - radius * 0.75)
        y = rng.uniform(-HALF + radius * 0.75, HALF - radius * 0.75)
        if any(math.hypot(x - ox, y - oy) < radius + orad - OVERLAP for ox, oy, orad in occupied):
            continue
        local = random.Random(1001 + count)
        up = random.Random(5001 + count)
        # Čelo stavby k náměstí, s malou náhodnou odchylkou.
        facing = math.atan2(cy - y, cx - x) + math.pi / 2 + local.uniform(-0.25, 0.25)
        with b.at(x, y, facing):
            if round_hut:
                roundhouse(b, local, wall_r, up)
            else:
                house(b, local, sx, sy, up)
        if b.variant >= 2:
            cobbled_path(b, x, y, radius)
        occupied.append((x, y, radius))
        count += 1
    return count


def cobbled_path(b, x, y, radius):
    """Dlážděná cestička od domu (x, y) k okraji náměstí (od vzhledu 2)."""
    cx, cy = SQUARE
    dx, dy = cx - x, cy - y
    dist = math.hypot(dx, dy)
    start, end = radius * 0.55, dist - SQUARE_R + 0.15
    if end <= start:
        return
    mid = (start + end) / 2
    with b.at(x + dx / dist * mid, y + dy / dist * mid, math.atan2(dy, dx)):
        b.box("RT_Path", (0, 0, 0.06), (end - start, 0.55, 0.025), "cobble", bevel=0.01)


def fill_greenery(b, rng, occupied):
    """Do zbylých mezer stromy a keře."""
    trees = 0
    for _ in range(300):
        x, y = rng.uniform(-HALF + 0.6, HALF - 0.6), rng.uniform(-HALF + 0.6, HALF - 0.6)
        if any(math.hypot(x - ox, y - oy) < orad + 0.5 for ox, oy, orad in occupied):
            continue
        if trees < 6 and rng.random() < 0.5:
            tree(b, x, y, rng)
            occupied.append((x, y, 0.9))
            trees += 1
        else:
            bush(b, x, y, rng)
            occupied.append((x, y, 0.4))
