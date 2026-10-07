"""Ruina radnice: postavený model radnice (rt_hall.build) se „zničí“ – střechy a kopule zmizí, zdi se sníží
na pahýly, část dílů zuhelnatí, okna zhasnou, stroje ze hry zmizí a na jejich místě zůstanou sutiny.
Stromy (sprity ze hry) a nádvoří zůstanou. Náhoda je pevná, takže ruina vypadá pokaždé stejně.
"""

import random

import bpy
from mathutils import Vector

import rt_render as R

#: Díly, které při zničení zmizí (střechy, kopule, věžičky, okenice, lampy) – podle začátku jména.
GONE = ("RT_Roof", "RT_HallRoof", "RT_Saw", "RT_Hall_Rotor", "RT_GreatDome", "RT_DomeRing", "RT_GreatRing",
        "RT_Spire", "RT_Antenna", "RT_Telescope", "RT_RoundRoof", "RT_RoundCap", "RT_SmithyRoof", "RT_ShedRoof",
        "RT_WarehouseRoof", "RT_TowerRoof", "RT_GateRoof", "RT_StallRoof", "RT_Shutter", "RT_Lamp", "RT_Lantern",
        "RT_Awning", "RT_RoofGarden", "RT_RoofBush", "RT_Wire", "RT_Banner", "RT_Deck", "RT_DeckPost",
        "RT_DeckRail")
#: Díly, které zůstanou celé (nádvoří, cesty, trávník, pole).
KEEP = ("RT_Plaza", "RT_Lawn", "RT_Field", "RT_FieldRow", "RT_Path", "RT_Cobble", "RT_PlantYard", "RT_Pad")
#: Výška zbylých zdí (podíl původní výšky) a podíl zuhelnatělých dílů.
STUMP = (0.25, 0.65)
CHARRED = 0.55
#: Sutiny: počet hromad na zmizelý díl a jejich velikost.
RUBBLE_PER_PART = 5
RUBBLE_SIZE = (0.06, 0.18)
RUBBLE_MATERIALS = ("stone", "stone_wall", "wood_beam", "cobble", "slate")


def _base_name(obj):
    """Jméno dílu bez čísla (Builder přidává _<pořadí>, Blender .001)."""
    name = obj.name.split(".")[0]
    head, _, tail = name.rpartition("_")
    return head if head and tail.isdigit() else name


def _center(obj):
    """Střed dílu ve světě (Builder zapéká polohu do vrcholů, počátek objektu je v nule)."""
    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    return sum(corners, Vector()) / len(corners)


def charred_material():
    """Zuhelnatělé dřevo / ohořelý kámen: skoro černá s popelavými skvrnami."""
    mat = bpy.data.materials.get("RT_Charred") or bpy.data.materials.new("RT_Charred")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 8.0
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (0.012, 0.010, 0.009, 1.0)
    ramp.color_ramp.elements[1].color = (0.09, 0.085, 0.08, 1.0)
    ramp.color_ramp.elements[0].position = 0.45
    nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.95
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def ruin(collection, b, mats, seed=666):
    """Zničí postavený model v kolekci: smaže střechy a stroje, sníží zdi, část zuhelnatí, okna zhasnou
    a přidá sutiny (b = Builder pro sutiny). Vrátí počet zmizelých dílů."""
    rng = random.Random(seed)
    charred = charred_material()
    bpy.data.scenes[R.SCENE_NAME].view_layers[0].update()  # matrix_world nových objektů
    gone = []
    for obj in list(collection.objects):
        if obj.type != "MESH" or obj.name.startswith("RT_Ground"):
            continue
        name = _base_name(obj)
        if obj.get("rt_card"):
            # Stroje a bedny ze hry zmizí (shořely), stromy zůstanou.
            if not name.startswith("RT_Tree"):
                gone.append(_center(obj))
                bpy.data.objects.remove(obj, do_unlink=True)
            continue
        if name.endswith("_Light") or name == "RT_Decal":
            continue
        if name.startswith(GONE):
            gone.append(_center(obj))
            bpy.data.objects.remove(obj, do_unlink=True)
            continue
        if name.startswith(KEEP):
            continue
        obj.scale.z *= rng.uniform(*STUMP)
        materials = obj.data.materials
        for i, mat in enumerate(materials):
            if mat.get("rt_glow") or rng.random() < CHARRED:
                materials[i] = charred
        # Horní plochy pahýlů zuhelnatělé – vypálené nitro bez střechy, ne plochá střecha.
        if charred.name not in materials:
            materials.append(charred)
        top = list(materials).index(charred)
        for polygon in obj.data.polygons:
            if polygon.normal.z > 0.7:
                polygon.material_index = top
    # Stíny ze hry a světla zmizelých strojů pryč; stromy si svůj stín nechají.
    for obj in list(collection.objects):
        if obj.type != "MESH":
            continue
        name = _base_name(obj)
        mat = obj.data.materials[0] if obj.data.materials else None
        is_tree = mat is not None and "tree" in mat.name
        if (name == "RT_Decal" or name.endswith("_Light")) and not is_tree:
            bpy.data.objects.remove(obj, do_unlink=True)
    root_scale = b.parent.scale.y
    for position in gone:
        for _ in range(RUBBLE_PER_PART):
            x = position.x + rng.uniform(-0.6, 0.6)
            y = position.y / root_scale + rng.uniform(-0.6, 0.6)
            mat = rng.choice(RUBBLE_MATERIALS)
            b.blob("RT_Rubble", (x, y, 0.06), rng.uniform(*RUBBLE_SIZE), mat, rng, squash=0.35)
    return len(gone)
